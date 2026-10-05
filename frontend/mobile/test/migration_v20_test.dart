import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/data/local/database/app_database.dart';

import 'support/v19_database.dart' as support;

/// La migration v19 → v20 : la fin des crédits, sur une base déjà remplie.
///
/// Retirer une colonne oblige SQLite à réécrire la table. Une réécriture
/// ratée ne lève rien : elle rend une table vide, et les promotions déjà en
/// ligne disparaissent sans bruit des téléphones déjà installés — pas de
/// celui du développeur, qui réinstalle.
///
/// Le test part donc d'une base **de la forme v19**, et non d'une base
/// neuve : une base neuve n'exécute aucune migration, et un test qui en part
/// passerait quoi qu'il arrive.
void main() {
  late Directory dossier;
  late File fichier;

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('eduquali_v19');
    fichier = File('${dossier.path}${Platform.pathSeparator}app.sqlite');
  });

  tearDown(() async {
    if (dossier.existsSync()) await dossier.delete(recursive: true);
  });

  /// La base v19 commune, plus les lignes que ce test veut y trouver.
  ///
  /// La remise en forme vit dans `support/v19_database.dart` : elle était
  /// recopiée ici et dans `startup_test.dart`, et les deux copies avaient
  /// divergé — celle de `startup_test` ne défaisait pas les tables de la v23.
  Future<void> poserUneBaseV19() => support.poserUneBaseV19(
    fichier,
    donnees: (base) async {
      await base.customStatement(
        "INSERT INTO users (id, role, phone, plan) "
        "VALUES ('u_i', 'INSTITUTION', '+224610000001', 'MASTER')",
      );
      await base.customStatement(
        "INSERT INTO institutions (id, name, type, city, user_id) "
        "VALUES ('i1', 'Lycée Excellence', 'SCHOOL', 'Conakry', 'u_i')",
      );
      await base.customStatement(
        "INSERT INTO promotions (id, institution_id, title, media_paths, "
        "credit_cost, status, views) "
        "VALUES ('p1', 'i1', 'Inscriptions ouvertes', 'cour.jpg', 50, "
        "'ACTIVE', 17)",
      );
      await base.customStatement(
        "INSERT INTO credit_ledger (owner_id, kind, amount) "
        "VALUES ('u_i', 'PURCHASE', 300)",
      );
      await base.customStatement(
        "INSERT INTO users (id, role, phone) "
        "VALUES ('u_prof_v19', 'TEACHER', '+224620000099')",
      );
      await base.customStatement(
        "INSERT INTO teachers (id, user_id) VALUES ('t_v19', 'u_prof_v19')",
      );
      await base.customStatement(
        "INSERT INTO video_courses (id, teacher_id, title, price, video_paths, "
        "status) VALUES ('c_v19', 't_v19', 'Les fonctions affines', 50000, "
        "'/data/a.mp4,/data/b.mp4', 'PUBLISHED')",
      );
    },
  );

  test('la promotion en ligne survit à la réécriture', () async {
    await poserUneBaseV19();

    final db = AppDatabase.forTesting(NativeDatabase(fichier));
    addTearDown(db.close);

    final promo = await db.select(db.promotions).getSingle();
    expect(promo.id, 'p1');
    expect(promo.title, 'Inscriptions ouvertes');
    // Le compteur d'affichages est ce que l'établissement regarde : le
    // perdre en cours de route remettrait sa page à zéro.
    expect(promo.views, 17);
    expect(promo.status, 'ACTIVE');
    expect(promo.mediaPaths, 'cour.jpg');
  });

  test('le grand livre disparaît de la base', () async {
    await poserUneBaseV19();

    final db = AppDatabase.forTesting(NativeDatabase(fichier));
    addTearDown(db.close);
    // Une lecture force l'ouverture, donc la migration.
    await db.select(db.promotions).get();

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'credit_ledger'",
        )
        .get();
    expect(tables, isEmpty);
  });

  test('la colonne de coût disparaît des promotions', () async {
    await poserUneBaseV19();

    final db = AppDatabase.forTesting(NativeDatabase(fichier));
    addTearDown(db.close);
    await db.select(db.promotions).get();

    final colonnes = await db
        .customSelect('PRAGMA table_info(promotions)')
        .get();
    final noms = [for (final c in colonnes) c.read<String>('name')];
    expect(noms, isNot(contains('credit_cost')));
    expect(noms, contains('views'));
    expect(noms, contains('media_paths'));
  });

  test('un fil de famille survit à la réécriture de la v22', () async {
    // La v22 rend `parentId` facultatif et ajoute `institutionId` : SQLite
    // réécrit donc la table. Une réécriture ratée ne lève rien, elle rend une
    // table vide — et les conversations déjà ouvertes disparaîtraient des
    // téléphones déjà installés, pas de celui du développeur qui réinstalle.
    await poserUneBaseV19();

    final db = AppDatabase.forTesting(NativeDatabase(fichier));
    addTearDown(db.close);
    await db.select(db.promotions).get();

    // Un fil comme en produit : une famille, un professeur, un message.
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u_t',
            role: 'TEACHER',
            phone: '+224620000111',
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
            phone: '+224620000112',
          ),
        );
    await db
        .into(db.parents)
        .insert(ParentsCompanion.insert(id: 'p1', userId: 'u_p'));
    await db
        .into(db.conversations)
        .insert(
          ConversationsCompanion.insert(
            id: 'conv1',
            teacherId: 't1',
            parentId: const Value('p1'),
          ),
        );
    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: 'm1',
            conversationId: const Value('conv1'),
            senderId: 'u_p',
            senderRole: 'PARENT',
            body: 'Bonjour, cherchez-vous des eleves ?',
          ),
        );

    final fil = await db.select(db.conversations).getSingle();
    expect(fil.parentId, 'p1');
    expect(
      fil.institutionId,
      isNull,
      reason: 'un fil de famille n’appartient à aucun établissement',
    );
    final message = await db.select(db.messages).getSingle();
    expect(message.body, 'Bonjour, cherchez-vous des eleves ?');
  });

  test('un fil d’établissement se range sans famille', () async {
    // L'inverse du précédent : c'est ce que la v22 rend possible, et ce que
    // la contrainte non nulle interdisait.
    await poserUneBaseV19();

    final db = AppDatabase.forTesting(NativeDatabase(fichier));
    addTearDown(db.close);
    await db.select(db.promotions).get();

    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u_t',
            role: 'TEACHER',
            phone: '+224620000113',
          ),
        );
    await db
        .into(db.teachers)
        .insert(TeachersCompanion.insert(id: 't1', userId: 'u_t'));
    await db
        .into(db.institutions)
        .insert(
          InstitutionsCompanion.insert(
            id: 'i_donka',
            name: 'Lycée Donka',
            type: 'HIGH_SCHOOL',
            city: 'Conakry',
          ),
        );
    await db
        .into(db.conversations)
        .insert(
          ConversationsCompanion.insert(
            id: 'conv2',
            teacherId: 't1',
            institutionId: const Value('i_donka'),
          ),
        );

    final fil = await db.select(db.conversations).getSingle();
    expect(fil.institutionId, 'i_donka');
    expect(fil.parentId, isNull);
  });

  test('les tables de chapitres apparaissent à la v23', () async {
    await poserUneBaseV19();

    final db = AppDatabase.forTesting(NativeDatabase(fichier));
    addTearDown(db.close);

    // Trois tables nouvelles, donc aucune réécriture : le risque n'est pas la
    // perte de données mais l'absence — un écran qui interroge une table
    // inexistante plante à l'ouverture du cours.
    expect(await db.select(db.courseChapters).get(), isEmpty);
    expect(await db.select(db.courseItems).get(), isEmpty);
    expect(await db.select(db.courseComments).get(), isEmpty);

    // Le cours d'avant les chapitres est toujours là, avec ses chemins : ce
    // sont eux qui permettront de lui reconstruire un sommaire.
    final cours = await db.select(db.videoCourses).getSingle();
    expect(cours.id, 'c_v19');
    expect(cours.videoPaths, '/data/a.mp4,/data/b.mp4');

    // La chaîne de clés étrangères tient : commentaire → élément → chapitre →
    // cours. Créée table par table, elle pourrait pointer dans le vide.
    await db
        .into(db.courseChapters)
        .insert(
          CourseChaptersCompanion.insert(
            id: 'ch1',
            courseId: 'c_v19',
            title: 'Chapitre 1',
          ),
        );
    await db
        .into(db.courseItems)
        .insert(
          CourseItemsCompanion.insert(
            id: 'it1',
            chapterId: 'ch1',
            title: 'La droite',
            localPath: const Value('/data/a.mp4'),
          ),
        );
    await db
        .into(db.courseComments)
        .insert(
          CourseCommentsCompanion.insert(
            id: 'cm1',
            itemId: 'it1',
            authorId: 'u_prof_v19',
            body: 'Première question.',
          ),
        );

    expect(await db.select(db.courseComments).getSingle(), isNotNull);
    await expectLater(
      db
          .into(db.courseItems)
          .insert(
            CourseItemsCompanion.insert(
              id: 'it2',
              chapterId: 'chapitre_inconnu',
              title: 'Orpheline',
            ),
          ),
      throwsA(anything),
      reason: 'un élément sans chapitre n’apparaîtrait nulle part',
    );
  });

  test('la version du schéma avance avec la migration', () async {
    // Une suppression sans incrémenter la version ne s'exécute jamais sur un
    // téléphone déjà installé : la table reste, et le schéma diverge en
    // silence de ce que le code attend.
    await poserUneBaseV19();

    final db = AppDatabase.forTesting(NativeDatabase(fichier));
    addTearDown(db.close);
    await db.select(db.promotions).get();

    expect(db.schemaVersion, greaterThanOrEqualTo(20));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);
  });
}
