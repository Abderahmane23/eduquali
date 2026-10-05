import 'dart:io';

import 'package:drift/native.dart';
import 'package:veriprof/data/local/database/app_database.dart';

/// Pose une base **de la forme v19**, pour éprouver la montée de version.
///
/// --- Pourquoi partir du schéma courant -----------------------------------
///
/// Écrire les quarante-cinq tables de la v19 à la main serait faux dès la
/// migration suivante. On laisse donc Drift créer le schéma d'aujourd'hui,
/// puis on **défait** ce que les migrations postérieures à la v19 ont ajouté :
/// sans cela elles rejouent et échouent sur une colonne qui existe déjà.
///
/// --- Pourquoi un fichier à part ------------------------------------------
///
/// Ce code vivait en double, dans `migration_v20_test.dart` et
/// `startup_test.dart`, chacun affirmant dans son commentaire que le prix se
/// payait « ici, une fois ». Il se payait deux fois, et les deux copies
/// avaient déjà divergé : celle de `startup_test` ne défaisait pas les trois
/// tables de la v23, donc sa migration n'en créait aucune et le test passait
/// pour une raison plus faible qu'il ne le croyait.
///
/// L'ajout des colonnes de la v24 a rendu la divergence visible — les deux
/// fichiers ont échoué pour la même raison. Une seule liste, désormais : le
/// prochain ajout de colonne se déclare ici et nulle part ailleurs.
///
/// --- Ce qu'il faut faire en ajoutant une migration -----------------------
///
/// Ajouter ses colonnes à [_ajoutsApresV19] et ses tables à [_tablesApresV19].
/// Un oubli ne passe pas inaperçu : la migration lève
/// « duplicate column name » au prochain lancement des tests.
/// [donnees] reçoit la base **encore en forme v19**, pour y insérer les lignes
/// que le test veut voir traverser la migration. Tout se passe sur une seule
/// connexion : rouvrir la base après avoir abaissé `user_version` déclencherait
/// la migration avant les insertions, et le test n'éprouverait plus rien.
Future<void> poserUneBaseV19(
  File fichier, {
  Future<void> Function(AppDatabase base)? donnees,
}) async {
  final neuve = AppDatabase.forTesting(NativeDatabase(fichier));
  // Une lecture force la création du schéma courant.
  await neuve.select(neuve.promotions).get();

  // --- Ce que la v20 a retiré, et qu'une base v19 porte encore ------------
  await neuve.customStatement(
    'ALTER TABLE promotions ADD COLUMN credit_cost INTEGER NOT NULL DEFAULT 0',
  );
  await neuve.customStatement('''
    CREATE TABLE credit_ledger (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      owner_id TEXT NOT NULL REFERENCES users (id),
      kind TEXT NOT NULL,
      amount INTEGER NOT NULL,
      feature TEXT,
      reference TEXT,
      created_at INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL DEFAULT 0,
      version INTEGER NOT NULL DEFAULT 1,
      device_id TEXT,
      dirty INTEGER NOT NULL DEFAULT 0
    )
  ''');

  // --- Ce que les migrations postérieures ont ajouté ----------------------
  for (final (table, colonnes) in _ajoutsApresV19.entries.map(
    (e) => (e.key, e.value),
  )) {
    for (final colonne in colonnes) {
      await neuve.customStatement('ALTER TABLE $table DROP COLUMN $colonne');
    }
  }
  for (final table in _tablesApresV19) {
    await neuve.customStatement('DROP TABLE IF EXISTS $table');
  }

  // Les lignes du test, avant d'abaisser la version : la migration ne doit
  // pas s'être exécutée quand elles entrent.
  if (donnees != null) await donnees(neuve);

  await neuve.customStatement('PRAGMA user_version = 19');
  await neuve.close();
}

/// Les colonnes ajoutées après la v19, par table.
const _ajoutsApresV19 = <String, List<String>>{
  // v21 — joindre l'établissement qui a employé le professeur.
  'teacher_experiences': ['contact_phone', 'contact_email'],
  // v24 — les réponses d'inscription qui n'avaient pas de destination.
  'teachers': ['tutoring_hours', 'work_hours', 'service_types', 'mobility'],
  'institutions': [
    'manager_role',
    'needed_subject_ids',
    'priorities',
    'teacher_location',
    'work_days',
    'work_start',
    'work_end',
    'max_distance',
  ],
  'users': ['pending_plan'],
};

/// Les tables créées après la v19.
///
/// Les laisser en place ferait passer les tests qui vérifient que la migration
/// les crée, sans qu'elle ait rien créé.
const _tablesApresV19 = <String>[
  // v23 — un cours se construit en chapitres.
  'course_comments',
  'course_items',
  'course_chapters',
];
