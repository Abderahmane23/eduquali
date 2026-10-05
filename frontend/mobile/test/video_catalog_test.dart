import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_constants.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/repositories/video_courses_repository.dart';
import 'package:veriprof/data/sync/sync_engine.dart';

/// Le catalogue de cours vidéo, demandé le 21/09.
///
/// Un cours se vend une fois et se regarde autant de fois qu'on veut. La
/// commission de 20 % est retenue sur le prix affiché — l'élève paie ce
/// qu'il voit.
void main() {
  late AppDatabase db;
  late VideoCoursesRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = VideoCoursesRepository(
      db,
      SyncEngine(
        database: db,
        network: NetworkStatusService(),
        api: SyncApi(Dio()),
        deviceId: 'test',
      ),
    );

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
  });

  tearDown(() => db.close());

  Future<String> unCours({int price = 50000}) => repo.create(
    teacherId: 't1',
    title: 'Les fonctions affines',
    price: price,
    subjectId: 'sub_math',
    videoPaths: ['chap1.mp4', 'chap2.mp4'],
  );

  group('La commission de 20 %', () {
    test('elle se retient sur le prix affiché, pas en plus', () {
      expect(AppConstants.videoCourseCommission, 0.20);
      // L'élève paie 50 000, le professeur touche 40 000.
      expect(AppConstants.videoCourseNet(50000), 40000);
    });

    test('le cours annonce ce qui revient au professeur', () async {
      await unCours();
      final course = (await repo.ofTeacher('t1')).single;
      expect(course.price, 50000);
      expect(course.net, 40000);
    });
  });

  group('Créer un cours', () {
    test('un cours créé part directement en vente', () async {
      await unCours();
      final course = (await repo.ofTeacher('t1')).single;
      expect(course.status, VideoCourseStatus.published);
      expect(course.videos, ['chap1.mp4', 'chap2.mp4']);
      expect(course.teacherName, 'Mamadou Barry');
      expect(course.subjectName, 'Maths');
    });

    test('sans vidéo, il est refusé', () async {
      // Publier un cours vide ferait payer un élève pour une page blanche.
      expect(
        () => repo.create(
          teacherId: 't1',
          title: 'Cours vide',
          price: 10000,
          videoPaths: const [],
        ),
        throwsA(isA<VideoCourseException>()),
      );
    });

    test('sans titre ni prix, il est refusé', () async {
      expect(
        () => repo.create(
          teacherId: 't1',
          title: '   ',
          price: 10000,
          videoPaths: ['a.mp4'],
        ),
        throwsA(isA<VideoCourseException>()),
      );
      expect(
        () => repo.create(
          teacherId: 't1',
          title: 'Sans prix',
          price: 0,
          videoPaths: ['a.mp4'],
        ),
        throwsA(isA<VideoCourseException>()),
      );
    });
  });

  group('Acheter un cours', () {
    test('l’achat fige le prix et la commission', () async {
      final id = await unCours();
      await repo.purchase(courseId: id, parentId: 'p1');

      final purchase = await db.select(db.coursePurchases).getSingle();
      expect(purchase.amount, 50000);
      expect(purchase.commission, 10000);
    });

    test('changer le prix ne réécrit pas ce qui a été réglé', () async {
      final id = await unCours();
      await repo.purchase(courseId: id, parentId: 'p1');

      await (db.update(db.videoCourses)..where((t) => t.id.equals(id))).write(
        const VideoCoursesCompanion(price: Value(90000)),
      );

      final purchase = await db.select(db.coursePurchases).getSingle();
      expect(purchase.amount, 50000, reason: 'un achat passé a été réécrit');
    });

    test('on n’achète pas deux fois le même cours', () async {
      final id = await unCours();
      await repo.purchase(courseId: id, parentId: 'p1');
      expect(
        () => repo.purchase(courseId: id, parentId: 'p1'),
        throwsA(isA<VideoCourseException>()),
      );
    });

    test('un cours retiré ne s’achète plus', () async {
      final id = await unCours();
      await repo.setStatus(id, VideoCourseStatus.hidden);
      expect(
        () => repo.purchase(courseId: id, parentId: 'p1'),
        throwsA(isA<VideoCourseException>()),
      );
    });

    test('le compteur de ventes suit', () async {
      final id = await unCours();
      await repo.purchase(courseId: id, parentId: 'p1');
      expect((await repo.ofTeacher('t1')).single.row.purchaseCount, 1);
    });
  });

  group('Le catalogue vu de chaque côté', () {
    test('la famille ne voit que ce qui est en vente', () async {
      final id = await unCours();
      expect(await repo.published(), hasLength(1));

      await repo.setStatus(id, VideoCourseStatus.hidden);
      expect(await repo.published(), isEmpty);
      // Le professeur, lui, garde son cours sous les yeux.
      expect(await repo.ofTeacher('t1'), hasLength(1));
    });

    test('un cours déjà acheté se distingue des autres', () async {
      final id = await unCours();
      expect((await repo.published(parentId: 'p1')).single.purchased, isFalse);

      await repo.purchase(courseId: id, parentId: 'p1');
      expect((await repo.published(parentId: 'p1')).single.purchased, isTrue);
      // Pour quelqu'un d'autre, il reste à acheter.
      expect((await repo.published(parentId: 'p2')).single.purchased, isFalse);
    });
  });

  group('Les gains du professeur', () {
    test('ils comptent le net, jamais le brut', () async {
      final id = await unCours();
      await repo.purchase(courseId: id, parentId: 'p1');
      expect(await repo.earningsOf('t1'), 40000);
    });

    test('sans vente, rien', () async {
      await unCours();
      expect(await repo.earningsOf('t1'), 0);
    });

    test('deux ventes s’additionnent', () async {
      final id = await unCours();
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: 'u_p2',
              role: 'PARENT',
              phone: '+224600000003',
            ),
          );
      await db
          .into(db.parents)
          .insert(ParentsCompanion.insert(id: 'p2', userId: 'u_p2'));

      await repo.purchase(courseId: id, parentId: 'p1');
      await repo.purchase(courseId: id, parentId: 'p2');
      expect(await repo.earningsOf('t1'), 80000);
    });
  });
}
