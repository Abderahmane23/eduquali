import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_enums.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/local/seed/database_seeder.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/repositories/conversations_repository.dart';
import 'package:veriprof/data/repositories/notification_repository.dart';
import 'package:veriprof/data/repositories/teacher_repository.dart';
import 'package:veriprof/data/repositories/tutoring_repository.dart';
import 'package:veriprof/data/sync/sync_engine.dart';
import 'package:veriprof/domain/usecases/first_message.dart';

/// Réserver un professeur ouvre une conversation et y pose le premier
/// message.
///
/// Demandé le 02/10. Avant, le fil n'était ouvert qu'à l'acceptation : entre
/// la demande et la réponse, la famille n'avait ni trace de ce qu'elle avait
/// envoyé ni endroit pour poser une question, et le professeur recevait une
/// ligne dans une liste sans savoir qui la lui envoyait.
///
/// Le test travaille sur une vraie base semée : c'est la chaîne complète —
/// demande, fil, message, notification — et chacun de ses chaînons peut
/// échouer sans rien lever.
void main() {
  // Le semis lit des assets : sans la liaison de test, `rootBundle` n'existe
  // pas et la base reste vide.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TutoringRepository tutoring;
  late ConversationsRepository conversations;
  late NotificationRepository notifications;
  late TeacherRepository teachers;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await DatabaseSeeder(db).seedIfNeeded();
    final engine = SyncEngine(
      database: db,
      network: NetworkStatusService(),
      api: SyncApi(Dio()),
      deviceId: 'test',
    );
    tutoring = TutoringRepository(db, engine);
    conversations = ConversationsRepository(db, engine);
    notifications = NotificationRepository(db);
    teachers = TeacherRepository(db, engine);

    // Une famille, avec un enfant en Terminale.
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u_parent',
            role: 'PARENT',
            phone: '+224620000900',
            firstName: const Value('Ousmane'),
            lastName: const Value('Camara'),
          ),
        );
    await db
        .into(db.parents)
        .insert(ParentsCompanion.insert(id: 'p1', userId: 'u_parent'));
    await db
        .into(db.children)
        .insert(
          ChildrenCompanion.insert(
            id: 'c1',
            parentId: 'p1',
            firstName: 'Aissatou',
            levelId: const Value('lvl_terminale'),
          ),
        );
  });

  tearDown(() => db.close());

  /// La première offre de cours semée, et le professeur derrière.
  Future<TutoringOffer> uneOffre() async =>
      (await tutoring.allActiveOffers()).first;

  test('la demande ouvre un fil, qui porte le premier message', () async {
    final offre = await uneOffre();

    final requestId = await tutoring.requestTutoring(
      parentId: 'p1',
      offerId: offre.id,
      childId: 'c1',
    );
    final filId = await conversations.openForRequest(requestId);
    await conversations.send(
      conversationId: filId,
      senderId: 'u_parent',
      senderRole: UserRole.parent,
      body: composeFirstMessage(
        author: FirstMessageAuthor.parent,
        purpose: FirstMessagePurpose.homeCourse,
        teacherName: offre.teacherName,
        senderName: 'Ousmane Camara',
        subject: offre.subjectName,
        levelName: 'Terminale',
      ),
    );

    final messages = await conversations.messages(filId);
    expect(messages, hasLength(1));
    expect(messages.single.body, contains('Bonjour ${offre.teacherName},'));
    expect(messages.single.body, contains('Mon enfant est en Terminale.'));
    // Le premier message ne doit pas être caviardé : s'il l'était, la famille
    // ouvrirait le fil sur des points de suspension.
    expect(messages.single.masked, isFalse);
  });

  test('le fil se retrouve des deux côtés', () async {
    final offre = await uneOffre();
    final requestId = await tutoring.requestTutoring(
      parentId: 'p1',
      offerId: offre.id,
      childId: 'c1',
    );
    final filId = await conversations.openForRequest(requestId);

    final cotefamille = await conversations.of(
      parentId: 'p1',
      readerId: 'u_parent',
    );
    expect(cotefamille.map((c) => c.id), contains(filId));
    expect(cotefamille.first.otherName, offre.teacherName);

    final coteProf = await conversations.of(
      teacherId: offre.teacherId,
      readerId: 'u_prof_inconnu',
    );
    expect(coteProf.map((c) => c.id), contains(filId));
    expect(
      coteProf.first.otherName,
      'Ousmane Camara',
      reason: 'le professeur doit voir qui lui écrit',
    );
  });

  test('réserver deux fois ne crée pas deux fils', () async {
    // `openForRequest` est appelée à chaque réservation : si elle créait un
    // fil par appel, la conversation se dédoublerait et la moitié des
    // messages deviendrait invisible.
    final offre = await uneOffre();
    final requestId = await tutoring.requestTutoring(
      parentId: 'p1',
      offerId: offre.id,
      childId: 'c1',
    );

    final premier = await conversations.openForRequest(requestId);
    final second = await conversations.openForRequest(requestId);
    expect(second, premier);
    expect(await db.select(db.conversations).get(), hasLength(1));
  });

  test(
    'le professeur est averti, sur son compte et non sur sa fiche',
    () async {
      // `users.id` et `teachers.id` se ressemblent et ne désignent pas la même
      // chose. Pousser la notification sur l'identifiant de fiche ne lève rien
      // — elle n'apparaît simplement jamais.
      final offre = await uneOffre();
      final compte = await teachers.userIdOf(offre.teacherId);
      expect(compte, isNotNull);
      expect(
        compte,
        isNot(offre.teacherId),
        reason: 'si les deux étaient égaux, le test ne prouverait rien',
      );

      await notifications.push(
        userId: compte!,
        kind: NotificationKind.message,
        title: 'Nouvelle demande de cours',
        body: 'Ousmane Camara vous écrit au sujet de ${offre.subjectName}.',
        route: '/messages/fil',
      );

      final siennes = await notifications.watch(compte).first;
      expect(siennes, hasLength(1));
      expect(siennes.single.read, isFalse);
      expect(siennes.single.route, '/messages/fil');

      // Et personne d'autre ne la reçoit.
      expect(await notifications.watch('u_parent').first, isEmpty);
    },
  );

  test('l’écran de réservation emmène vers le fil', () {
    // La valeur rendue par la feuille est l'identifiant du fil : c'est elle
    // qui permet d'ouvrir la conversation au lieu d'annoncer qu'elle existe.
    final feuille = File(
      'lib/presentation/screens/tutoring/book_tutoring_sheet.dart',
    ).readAsStringSync();
    expect(feuille, contains('Future<String?> showBookTutoringSheet'));
    expect(feuille, contains('composeFirstMessage'));

    final fiche = File(
      'lib/presentation/screens/shared/teacher_public_profile_screen.dart',
    ).readAsStringSync();
    expect(fiche, contains("context.push('/messages/\$fil')"));
    expect(
      fiche,
      isNot(contains('Suivez la réponse dans')),
      reason: 'on ouvre le fil, on n’annonce plus son existence',
    );
  });
}
