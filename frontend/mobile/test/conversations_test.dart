import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_enums.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/repositories/conversations_repository.dart';
import 'package:veriprof/data/repositories/tutoring_repository.dart';
import 'package:veriprof/data/sync/sync_engine.dart';
import 'package:veriprof/domain/usecases/tutoring_rules.dart';

/// La messagerie entre une famille et un professeur (24/09).
///
/// Elle naît à l'acceptation : avant, les deux n'ont rien à se dire ; après,
/// ils n'avaient aucun endroit pour le faire et devaient sortir de
/// l'application — ce qui fait sortir la transaction avec eux.
void main() {
  late AppDatabase db;
  late SyncEngine sync;
  late TutoringRepository tutoring;
  late ConversationsRepository fils;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sync = SyncEngine(
      database: db,
      network: NetworkStatusService(),
      api: SyncApi(Dio()),
      deviceId: 'test',
    );
    tutoring = TutoringRepository(db, sync);
    fils = ConversationsRepository(db, sync);

    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u_t',
            role: 'TEACHER',
            phone: '+224620000101',
            firstName: const Value('Mamadou'),
            lastName: const Value('Barry'),
          ),
        );
    await db
        .into(db.teachers)
        .insert(TeachersCompanion.insert(id: 't1', userId: 'u_t'));
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u_p',
            role: 'PARENT',
            phone: '+224600000002',
            firstName: const Value('Aïssatou'),
            lastName: const Value('Diallo'),
          ),
        );
    await db
        .into(db.parents)
        .insert(ParentsCompanion.insert(id: 'p1', userId: 'u_p'));
    await db
        .into(db.subjects)
        .insert(
          SubjectsCompanion.insert(id: 'sub_math', name: 'Maths', code: 'MATH'),
        );
    await db
        .into(db.levels)
        .insert(
          LevelsCompanion.insert(
            id: 'lvl_11',
            name: '11e année',
            code: 'AN11',
            category: 'SECONDARY',
          ),
        );
    await db
        .into(db.children)
        .insert(
          ChildrenCompanion.insert(
            id: 'c1',
            parentId: 'p1',
            firstName: 'Fatoumata',
          ),
        );
  });

  tearDown(() => db.close());

  /// Une demande envoyée, prête à être acceptée.
  Future<String> uneDemande() async {
    await tutoring.saveAvailability(
      teacherId: 't1',
      days: const {Weekday.monday, Weekday.wednesday, Weekday.friday},
      slots: const {DaySlot.evening},
    );
    final offerId = await tutoring.publishOffer(
      teacherId: 't1',
      subjectId: 'sub_math',
      levelIds: const ['lvl_11'],
      mode: TutoringMode.atStudent,
      hourlyRate: 60000,
      city: 'Conakry',
    );
    return tutoring.requestTutoring(
      parentId: 'p1',
      offerId: offerId,
      childId: 'c1',
    );
  }

  test('accepter ouvre le fil, refuser n’ouvre rien', () async {
    final acceptee = await uneDemande();
    await tutoring.setStatus(
      requestId: acceptee,
      actor: TutoringActor.teacher,
      to: TutoringStatus.accepted,
    );
    expect(await db.select(db.conversations).get(), hasLength(1));

    final refusee = await uneDemande();
    await tutoring.setStatus(
      requestId: refusee,
      actor: TutoringActor.teacher,
      to: TutoringStatus.declined,
    );
    // Toujours un seul : un refus ne crée pas de fil.
    expect(await db.select(db.conversations).get(), hasLength(1));
  });

  test('accepter deux fois n’ouvre pas deux fils', () async {
    final id = await uneDemande();
    await tutoring.setStatus(
      requestId: id,
      actor: TutoringActor.teacher,
      to: TutoringStatus.accepted,
    );
    final premier = await fils.openForRequest(id);
    final second = await fils.openForRequest(id);
    expect(premier, second);
    expect(await db.select(db.conversations).get(), hasLength(1));
  });

  test('chacun voit le nom de l’autre', () async {
    final id = await uneDemande();
    await tutoring.setStatus(
      requestId: id,
      actor: TutoringActor.teacher,
      to: TutoringStatus.accepted,
    );

    final vuDuParent = await fils.of(parentId: 'p1', readerId: 'u_p');
    expect(vuDuParent.single.otherName, 'Mamadou Barry');
    // La matière et l'enfant : de quoi reconnaître le fil sans l'ouvrir.
    expect(vuDuParent.single.subtitle, contains('Maths'));
    expect(vuDuParent.single.subtitle, contains('Fatoumata'));

    final vuDuProf = await fils.of(teacherId: 't1', readerId: 'u_t');
    expect(vuDuProf.single.otherName, 'Aïssatou Diallo');
  });

  test('les coordonnées restent masquées', () async {
    // C'est la règle §30, et c'est la seule raison pour laquelle ce fil
    // partage la table des messages du recrutement : deux implémentations du
    // même filtre finiraient par ne plus masquer la même chose.
    final id = await uneDemande();
    await tutoring.setStatus(
      requestId: id,
      actor: TutoringActor.teacher,
      to: TutoringStatus.accepted,
    );
    final filId = await fils.openForRequest(id);

    await fils.send(
      conversationId: filId,
      senderId: 'u_t',
      senderRole: UserRole.teacher,
      body: 'Appelez-moi au 620 00 01 02',
    );

    final lus = await fils.messages(filId);
    expect(lus.single.masked, isTrue);
    expect(lus.single.body, isNot(contains('620 00 01 02')));

    // Le texte d'origine est conservé : le masquage est une couche
    // d'affichage, pas une destruction.
    final brut = await db.select(db.messages).getSingle();
    expect(brut.body, contains('620 00 01 02'));
  });

  test('le compte de non-lus ignore ses propres messages', () async {
    final id = await uneDemande();
    await tutoring.setStatus(
      requestId: id,
      actor: TutoringActor.teacher,
      to: TutoringStatus.accepted,
    );
    final filId = await fils.openForRequest(id);

    await fils.send(
      conversationId: filId,
      senderId: 'u_t',
      senderRole: UserRole.teacher,
      body: 'Bonjour, on commence lundi ?',
    );

    expect((await fils.of(teacherId: 't1', readerId: 'u_t')).single.unread, 0);
    expect((await fils.of(parentId: 'p1', readerId: 'u_p')).single.unread, 1);

    await fils.markRead(filId, 'u_p');
    expect((await fils.of(parentId: 'p1', readerId: 'u_p')).single.unread, 0);
  });

  test('un message de recrutement n’apparaît pas dans un fil', () async {
    // Les deux partagent la table ; ils ne doivent pas partager les fils.
    // Un message sans `conversation_id` ne remonte jamais ici.
    final id = await uneDemande();
    await tutoring.setStatus(
      requestId: id,
      actor: TutoringActor.teacher,
      to: TutoringStatus.accepted,
    );
    final filId = await fils.openForRequest(id);

    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: 'm_orphelin',
            senderId: 'u_t',
            senderRole: 'TEACHER',
            body: 'Message d’un espace de recrutement',
          ),
        );

    expect(await fils.messages(filId), isEmpty);
  });
}
