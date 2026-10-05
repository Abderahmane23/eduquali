import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/repositories/children_repository.dart';
import 'package:veriprof/data/repositories/tutoring_repository.dart';
import 'package:veriprof/data/sync/sync_engine.dart';
import 'package:veriprof/domain/usecases/tutoring_rules.dart';

/// Les enfants d'un parent — ajout, correction, retrait.
void main() {
  late AppDatabase db;
  late SyncEngine sync;
  late ChildrenRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sync = SyncEngine(
      database: db,
      network: NetworkStatusService(),
      api: SyncApi(Dio()),
      deviceId: 'test',
    );
    repo = ChildrenRepository(db, sync);

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
        .into(db.levels)
        .insert(
          LevelsCompanion.insert(
            id: 'lvl_11',
            name: '11e année',
            code: 'AN11',
            category: 'SECONDARY',
          ),
        );
  });

  tearDown(() => db.close());

  test('un parent peut enregistrer plusieurs enfants', () async {
    await repo.add(parentId: 'p1', firstName: 'Fatoumata');
    await repo.add(parentId: 'p1', firstName: 'Ibrahima');

    final children = await repo.of('p1');
    expect(children, hasLength(2));
    // Triés par prénom : une liste stable se relit sans surprise.
    expect(children.map((c) => c.firstName), ['Fatoumata', 'Ibrahima']);
  });

  test('la fiche garde tout ce qui a été saisi', () async {
    await repo.add(
      parentId: 'p1',
      firstName: 'Fatoumata',
      lastName: 'Barry',
      levelId: 'lvl_11',
      schoolName: 'Lycée Kalou',
      subjectIds: ['sub_math', 'sub_phys'],
    );

    final child = (await repo.of('p1')).single;
    expect(child.lastName, 'Barry');
    expect(child.levelId, 'lvl_11');
    expect(child.schoolName, 'Lycée Kalou');
    expect(ChildrenRepository.split(child.subjectIds), [
      'sub_math',
      'sub_phys',
    ]);
  });

  test('un prénom vide est refusé', () async {
    expect(
      () => repo.add(parentId: 'p1', firstName: '   '),
      throwsA(isA<ChildException>()),
    );
  });

  test('corriger une fiche remplace les matières, sans en accumuler', () async {
    final id = await repo.add(
      parentId: 'p1',
      firstName: 'Fatoumata',
      subjectIds: ['sub_math'],
    );
    await repo.update(
      childId: id,
      firstName: 'Fatoumata',
      lastName: 'Barry',
      subjectIds: ['sub_fran'],
    );

    final child = (await repo.of('p1')).single;
    expect(child.lastName, 'Barry');
    expect(ChildrenRepository.split(child.subjectIds), ['sub_fran']);
  });

  test('un enfant sans demande se retire', () async {
    final id = await repo.add(parentId: 'p1', firstName: 'Fatoumata');
    await repo.remove(id);
    expect(await repo.of('p1'), isEmpty);
  });

  test('un enfant avec une demande en cours ne se retire pas', () async {
    // Sinon le professeur verrait une demande pointant vers un enfant
    // disparu.
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u_t',
            role: 'TEACHER',
            phone: '+224620000101',
          ),
        );
    await db
        .into(db.teachers)
        .insert(TeachersCompanion.insert(id: 't1', userId: 'u_t'));
    await db
        .into(db.subjects)
        .insert(
          SubjectsCompanion.insert(id: 'sub_math', name: 'Maths', code: 'MATH'),
        );

    final tutoring = TutoringRepository(db, sync);
    await tutoring.saveAvailability(
      teacherId: 't1',
      days: {Weekday.monday, Weekday.wednesday, Weekday.friday},
      slots: {DaySlot.evening},
    );
    final offerId = await tutoring.publishOffer(
      teacherId: 't1',
      subjectId: 'sub_math',
      levelIds: ['lvl_11'],
      mode: TutoringMode.atStudent,
      hourlyRate: 50000,
      city: 'Conakry',
    );

    final childId = await repo.add(parentId: 'p1', firstName: 'Fatoumata');
    await tutoring.requestTutoring(
      parentId: 'p1',
      offerId: offerId,
      childId: childId,
    );

    expect(() => repo.remove(childId), throwsA(isA<ChildException>()));
    expect(await repo.of('p1'), hasLength(1));
  });

  group('Retirer, puis se raviser', () {
    test('la fiche revient telle quelle, avec le même identifiant', () async {
      final id = await repo.add(
        parentId: 'p1',
        firstName: 'Fatoumata',
        lastName: 'Camara',
        levelId: 'lvl_11',
        schoolName: 'Lycée Donka',
        subjectIds: ['sub_math', 'sub_pc'],
      );

      final removed = await repo.remove(id);
      expect(await repo.of('p1'), isEmpty);

      await repo.restore(removed);
      final back = await repo.of('p1');
      expect(back, hasLength(1));
      // Le même identifiant : les demandes passées le désignent par celui-ci,
      // une fiche recréée à la main les laisserait pointer dans le vide.
      expect(back.single.id, id);
      expect(back.single.firstName, 'Fatoumata');
      expect(back.single.lastName, 'Camara');
      expect(back.single.levelId, 'lvl_11');
      expect(back.single.schoolName, 'Lycée Donka');
      expect(back.single.subjectIds, 'sub_math,sub_pc');
    });

    test('le serveur apprend le retrait puis le retour', () async {
      final id = await repo.add(parentId: 'p1', firstName: 'Fatoumata');
      await repo.restore(await repo.remove(id));

      final queued = await db.select(db.syncQueue).get();
      final operations = [
        for (final q in queued)
          if (q.entity == 'child' && q.entityId == id) q.operation,
      ];
      // Dans cet ordre : une suppression qui arriverait après la recréation
      // effacerait côté serveur une fiche que l'écran affiche encore.
      expect(operations, ['CREATE', 'DELETE', 'CREATE']);
    });
  });

  test('chaque écriture part dans la file de synchronisation', () async {
    final id = await repo.add(parentId: 'p1', firstName: 'Fatoumata');
    await repo.update(childId: id, firstName: 'Fatou');
    await repo.remove(id);

    final queued = await db.select(db.syncQueue).get();
    final operations = queued
        .where((q) => q.entity == 'child')
        .map((q) => q.operation);
    expect(operations, containsAll(['CREATE', 'UPDATE', 'DELETE']));
  });
}
