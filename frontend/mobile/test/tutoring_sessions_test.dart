import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/repositories/tutoring_repository.dart';
import 'package:veriprof/data/repositories/tutoring_sessions_repository.dart';
import 'package:veriprof/data/sync/sync_engine.dart';
import 'package:veriprof/domain/usecases/tutoring_rules.dart';

/// Les séances de cours à domicile.
///
/// Demande du 20/09 : l'accueil du parent montre la dernière séance et les
/// suivantes. Encore faut-il que des séances existent — elles naissent au
/// moment où le professeur accepte, pas avant.
void main() {
  late AppDatabase db;
  late TutoringRepository tutoring;
  late TutoringSessionsRepository sessions;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final sync = SyncEngine(
      database: db,
      network: NetworkStatusService(),
      api: SyncApi(Dio()),
      deviceId: 'test',
    );
    tutoring = TutoringRepository(db, sync);
    sessions = TutoringSessionsRepository(db);

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
            name: '11ème année',
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

  /// Un professeur disponible, une offre, une demande envoyée.
  Future<String> uneDemande({
    Set<Weekday> days = const {
      Weekday.monday,
      Weekday.wednesday,
      Weekday.friday,
    },
    Set<DaySlot> slots = const {DaySlot.evening},
  }) async {
    await tutoring.saveAvailability(teacherId: 't1', days: days, slots: slots);
    final offerId = await tutoring.publishOffer(
      teacherId: 't1',
      subjectId: 'sub_math',
      levelIds: ['lvl_11'],
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

  test('une demande envoyée ne crée encore aucune séance', () async {
    // Tant que le professeur n'a pas dit oui, annoncer des horaires au
    // parent serait promettre à la place de quelqu'un d'autre.
    await uneDemande();
    expect(await sessions.ofParent('p1'), isEmpty);
  });

  test('accepter programme les prochaines séances', () async {
    final requestId = await uneDemande();
    await tutoring.setStatus(
      requestId: requestId,
      actor: TutoringActor.teacher,
      to: TutoringStatus.accepted,
    );

    final planned = await sessions.ofParent('p1');
    expect(planned, hasLength(4));
    expect(planned.first.teacherName, 'Mamadou Barry');
    expect(planned.first.subjectName, 'Maths');
    expect(planned.first.childName, 'Fatoumata');
  });

  test('les séances tombent sur les jours déclarés, jamais ailleurs', () async {
    final requestId = await uneDemande(
      days: {Weekday.tuesday, Weekday.thursday, Weekday.saturday},
    );
    await tutoring.setStatus(
      requestId: requestId,
      actor: TutoringActor.teacher,
      to: TutoringStatus.accepted,
    );

    const attendus = {DateTime.tuesday, DateTime.thursday, DateTime.saturday};
    for (final s in await sessions.ofParent('p1')) {
      expect(
        attendus,
        contains(s.startsAt.weekday),
        reason: 'séance un jour que le professeur n’a pas annoncé',
      );
    }
  });

  test('l’heure suit le créneau déclaré', () async {
    final requestId = await uneDemande(slots: {DaySlot.morning});
    await tutoring.setStatus(
      requestId: requestId,
      actor: TutoringActor.teacher,
      to: TutoringStatus.accepted,
    );
    expect((await sessions.ofParent('p1')).first.startsAt.hour, 9);
  });

  test('toutes les séances sont à venir', () async {
    final requestId = await uneDemande();
    await tutoring.setStatus(
      requestId: requestId,
      actor: TutoringActor.teacher,
      to: TutoringStatus.accepted,
    );
    final now = DateTime.now();
    for (final s in await sessions.ofParent('p1')) {
      expect(s.startsAt.isAfter(now), isTrue);
    }
  });

  test('accepter deux fois ne double pas les séances', () async {
    final requestId = await uneDemande();
    await tutoring.setStatus(
      requestId: requestId,
      actor: TutoringActor.teacher,
      to: TutoringStatus.accepted,
    );
    // Un second appel — reprise de synchronisation, double appui — ne doit
    // pas remplir l'agenda du parent deux fois.
    expect(await sessions.planFor(requestId), 0);
    expect(await sessions.ofParent('p1'), hasLength(4));
  });

  test('une séance se termine et se raconte', () async {
    final requestId = await uneDemande();
    await tutoring.setStatus(
      requestId: requestId,
      actor: TutoringActor.teacher,
      to: TutoringStatus.accepted,
    );
    final premiere = (await sessions.ofParent('p1')).first;
    await sessions.markDone(premiere.session.id, topic: 'Fonctions affines');

    final relue = (await sessions.ofParent(
      'p1',
    )).firstWhere((s) => s.session.id == premiere.session.id);
    expect(relue.isPast, isTrue);
    expect(relue.session.topic, 'Fonctions affines');
  });

  test('une séance annulée se distingue d’une séance passée', () async {
    final requestId = await uneDemande();
    await tutoring.setStatus(
      requestId: requestId,
      actor: TutoringActor.teacher,
      to: TutoringStatus.accepted,
    );
    final s = (await sessions.ofParent('p1')).first;
    await sessions.cancel(s.session.id);

    final relue = (await sessions.ofParent(
      'p1',
    )).firstWhere((x) => x.session.id == s.session.id);
    expect(relue.isCancelled, isTrue);
    expect(relue.isPast, isFalse);
  });

  group('Annuler, puis se raviser', () {
    /// Une séance acceptée, prête à être annulée.
    Future<String> uneSeance() async {
      final requestId = await uneDemande();
      await tutoring.setStatus(
        requestId: requestId,
        actor: TutoringActor.teacher,
        to: TutoringStatus.accepted,
      );
      return (await sessions.ofParent('p1')).first.session.id;
    }

    Future<TutoringSessionItem> relire(String id) async =>
        (await sessions.ofParent('p1')).firstWhere((x) => x.session.id == id);

    test('la séance revient à l’état où l’annulation l’a trouvée', () async {
      final id = await uneSeance();

      final before = await sessions.cancel(id);
      expect((await relire(id)).isCancelled, isTrue);

      await sessions.restore(id, before!);
      expect((await relire(id)).isCancelled, isFalse);
    });

    test('une séance déjà faite ne redevient pas « prévue »', () async {
      final id = await uneSeance();
      await sessions.markDone(id, topic: 'Fonctions affines');

      // C'est tout l'intérêt de rendre le statut plutôt que de le deviner :
      // l'heure se rattrape, pas le cours qui a eu lieu.
      final before = await sessions.cancel(id);
      expect(before, 'DONE');

      await sessions.restore(id, before!);
      final relue = await relire(id);
      expect(relue.isPast, isTrue);
      expect(relue.session.topic, 'Fonctions affines');
    });

    test('annuler une séance inconnue ne rend rien', () async {
      expect(await sessions.cancel('inexistante'), isNull);
    });
  });

  test('un refus ne programme rien', () async {
    final requestId = await uneDemande();
    await tutoring.setStatus(
      requestId: requestId,
      actor: TutoringActor.teacher,
      to: TutoringStatus.declined,
    );
    expect(await sessions.ofParent('p1'), isEmpty);
  });
}
