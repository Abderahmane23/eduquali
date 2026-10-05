import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Base locale SQLite (§40).
///
/// Elle porte l'integralite des données necessaires au fonctionnement hors
/// ligne (§41) : profil, referentiel, offres telechargees, candidatures,
/// sessions de test, réponses, messages et file de synchronisation.
@DriftDatabase(
  tables: [
    Users,
    Teachers,
    Subjects,
    Levels,
    TeacherSubjects,
    TeacherLevels,
    TeacherDocuments,
    TeacherDiplomas,
    TeacherExperiences,
    TeacherCertifications,
    Institutions,
    Tests,
    TestQuestions,
    TestSessions,
    TestAnswers,
    Jobs,
    JobInvitations,
    Applications,
    RecruitmentRooms,
    Messages,
    // Les groupes : un cours en direct, un contrat. Les fils a deux restent
    // `Messages` ; le groupe s'ajoute a cote, il ne les remplace pas.
    ChatGroups,
    ChatMessages,
    Interviews,
    RecruitmentOffers,
    Contracts,
    Recruitments,
    TeacherReviews,
    RecruitmentEvents,
    Notifications,
    SyncQueue,
    AuditLogs,
    AppMeta,
    Parents,
    Children,
    TutoringServices,
    TutoringRequests,
    Favourites,
    CourseChapters,
    CourseItems,
    CourseComments,
    AiCourses,
    Filieres,
    TutoringSessions,
    WorkContracts,
    ContractPayments,
    VideoCourses,
    CoursePurchases,
    Promotions,
    PaymentMethods,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 25;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (m, from, to) async {
      // v2 — module parent/élève et cours a domicile.
      if (from < 2) {
        await m.createTable(parents);
        await m.createTable(children);
        await m.createTable(tutoringServices);
        await m.createTable(tutoringRequests);
      }
      // v3 — fiche detaillee d'un etablissement (§19). Colonnes ajoutees une
      // par une : `addColumn` est la seule operation sure sur une base qui
      // contient deja des donnees.
      if (from < 3) {
        for (final column in [
          institutions.phoneAlt,
          institutions.website,
          institutions.foundedYear,
          institutions.ownership,
          institutions.academicSystem,
          institutions.degrees,
          institutions.specialties,
          institutions.facilities,
        ]) {
          await m.addColumn(institutions, column);
        }
      }
      // v4 — assistant IA : crédits et cours construits. Tables nouvelles,
      // donc sans risque pour les données existantes.
      if (from < 4) {
        await m.createTable(aiCourses);
      }
      // v5 — cycles scolaires : ne proposer que les matières du niveau
      // enseigné. Colonnes additives, sans risque sur des données existantes.
      if (from < 5) {
        await m.addColumn(subjects, subjects.cycles);
        await m.addColumn(levels, levels.cycle);
      }
      // v6 — disponibilite pour les cours a domicile.
      if (from < 6) {
        await m.addColumn(teachers, teachers.tutoringDays);
        await m.addColumn(teachers, teachers.tutoringSlots);
      }
      // v7 — fiche enfant complete : nom et matieres a soutenir.
      if (from < 7) {
        await m.addColumn(children, children.lastName);
        await m.addColumn(children, children.subjectIds);
      }
      // v8 — export Word du cours, en plus de l'Excel deja enregistre.
      if (from < 8) {
        await m.addColumn(aiCourses, aiCourses.docxPath);
      }
      // v9 — localisation en cascade : region administrative et quartier.
      // La ville existante devient la prefecture (ou la commune a Conakry),
      // ce qui ne change rien aux donnees deja saisies.
      if (from < 9) {
        await m.addColumn(teachers, teachers.region);
        await m.addColumn(teachers, teachers.district);
        await m.addColumn(institutions, institutions.region);
        await m.addColumn(institutions, institutions.district);
        await m.addColumn(parents, parents.region);
      }
      // v10 — programme guineen : les en-tetes de cycle ne sont plus des
      // classes, et le lycee se decline en trois profils.
      if (from < 10) {
        await m.addColumn(levels, levels.grouping);
        await m.createTable(filieres);
        await m.addColumn(children, children.filiereId);
      }
      // v11 — seances de cours a domicile : l'accueil du parent montre la
      // derniere et les prochaines.
      if (from < 11) {
        await m.createTable(tutoringSessions);
      }
      // v12 — contrats et echeances : ce que chaque tableau de bord affiche.
      if (from < 12) {
        await m.createTable(workContracts);
        await m.createTable(contractPayments);
      }
      // v13 — catalogue de cours video et leurs achats.
      if (from < 13) {
        await m.createTable(videoCourses);
        await m.createTable(coursePurchases);
      }
      // v14 — promotions d'etablissement.
      if (from < 14) {
        await m.createTable(promotions);
      }
      // v15 — moyens de paiement enregistres, sans aucun secret.
      if (from < 15) {
        await m.createTable(paymentMethods);
      }
      // v16 — vues d'une fiche professeur, pour mesurer l'effet du boost.
      if (from < 16) {
        await m.addColumn(teachers, teachers.profileViews);
      }
      // v17 — conversations entre une famille et un professeur.
      //
      // `roomId` devient facultatif et `conversationId` apparait : un
      // message appartient desormais a l'un ou a l'autre. Rendre une colonne
      // facultative demande a SQLite de reecrire la table, ce que
      // `TableMigration` fait en conservant les lignes.
      if (from < 17) {
        await m.createTable(conversations);
        await m.alterTable(TableMigration(messages));
      }
      // v18 — l'abonnement mensuel. Il a remplace les credits en v20.
      if (from < 18) {
        await m.addColumn(users, users.plan);
        await m.addColumn(users, users.planRenewsAt);
      }
      // v19 — favoris. Table nouvelle, sans risque sur l'existant.
      if (from < 19) {
        await m.createTable(favourites);
      }
      // v20 — fin des credits (25/09).
      //
      // L'assistant, la mise en avant et la messagerie sont ouverts par
      // l'abonnement : il n'y a plus rien a decompter, donc plus rien a
      // tenir en grand livre. La table part, et avec elle la colonne de
      // cout sur les promotions.
      //
      // Retirer une colonne dans SQLite reecrit la table : `TableMigration`
      // le fait en conservant les lignes, ce qu'un `DROP` suivi d'un
      // `CREATE` ne ferait pas — les promotions deja en ligne doivent le
      // rester.
      //
      // Les deux operations sont du menage, et rien d'autre : le code ne
      // lit plus le grand livre, et `credit_cost` est `NOT NULL DEFAULT 0`,
      // donc une colonne qui resterait en place ne generait aucune
      // ecriture. Elles ne doivent donc jamais pouvoir couter un
      // demarrage — c'est exactement ce qu'on a vu le 25/09, un telephone
      // bloque sur le logo du lanceur. Le rattrapage est ici, au plus pres
      // de ce qu'on accepte de perdre.
      if (from < 20) {
        try {
          // La table n'existe plus dans le schema : on la nomme donc en SQL
          // plutot que par sa classe, qui a ete supprimee avec le reste.
          await customStatement('DROP TABLE IF EXISTS credit_ledger');
          await m.alterTable(TableMigration(promotions));
        } catch (_) {
          // Tant pis pour le menage : l'application s'ouvre.
        }
      }
      // v21 — de qui joindre pour verifier une experience (02/10).
      //
      // Deux colonnes facultatives, donc `addColumn` : aucune reecriture de
      // table, aucun risque sur les lignes existantes. C'est la seule
      // operation sure sur une base qui contient deja des donnees, et apres
      // la v20 je prefere ne pas toucher a une table en place.
      if (from < 21) {
        await m.addColumn(teacherExperiences, teacherExperiences.contactPhone);
        await m.addColumn(teacherExperiences, teacherExperiences.contactEmail);
      }
      // v22 — un etablissement peut ecrire a un professeur (02/10).
      //
      // `parentId` devient facultatif et `institutionId` apparait : un fil
      // appartient desormais a une famille **ou** a un etablissement. Rendre
      // une colonne facultative demande a SQLite de reecrire la table, ce que
      // `TableMigration` fait en conservant les lignes.
      //
      // Contrairement au menage de la v20, cette reecriture n'est pas
      // cosmetique : sans elle le code lit une colonne qui n'existe pas. Elle
      // n'est donc pas rattrapee — un echec ici doit se voir, et l'ecran de
      // demarrage le nommera.
      if (from < 22) {
        await m.alterTable(TableMigration(conversations));
      }
      // v23 — chapitres, elements et commentaires d'un cours (02/10).
      //
      // Trois tables nouvelles : aucune reecriture, aucun risque sur
      // l'existant. Les cours deja enregistres gardent leur liste plate de
      // chemins dans `video_paths` : le depot de contenu s'en sert pour leur
      // reconstruire un chapitre a la premiere ouverture, faute de quoi un
      // eleve qui a paye trouverait un ecran vide.
      if (from < 23) {
        await m.createTable(courseChapters);
        await m.createTable(courseItems);
        await m.createTable(courseComments);
      }
      // v24 — l'inscription cesse de jeter ce qu'elle demande (04/10).
      //
      // Le parcours professeur exploitait 7 reponses sur 15, celui de
      // l'etablissement 8 sur 17. Ces colonnes sont les destinations qui
      // manquaient. Toutes additives et toutes avec un defaut vide : les
      // comptes deja crees restent valides, simplement sans ces reponses —
      // qu'ils n'avaient de toute facon jamais pu enregistrer.
      if (from < 24) {
        await m.addColumn(teachers, teachers.tutoringHours);
        await m.addColumn(teachers, teachers.workHours);
        await m.addColumn(teachers, teachers.serviceTypes);
        await m.addColumn(teachers, teachers.mobility);
        await m.addColumn(institutions, institutions.managerRole);
        await m.addColumn(institutions, institutions.neededSubjectIds);
        await m.addColumn(institutions, institutions.priorities);
        await m.addColumn(institutions, institutions.teacherLocation);
        await m.addColumn(institutions, institutions.workDays);
        await m.addColumn(institutions, institutions.workStart);
        await m.addColumn(institutions, institutions.workEnd);
        await m.addColumn(institutions, institutions.maxDistance);
        await m.addColumn(users, users.pendingPlan);
      }
      // v25 — les groupes de discussion (04/10).
      //
      // Deux tables nouvelles : aucune reecriture, aucun risque sur
      // l'existant. Les fils a deux (`conversations`) restent intacts et
      // continuent de servir — le premier contact, une question qui ne
      // regarde qu'une famille. Le groupe s'ajoute a cote.
      if (from < 25) {
        await m.createTable(chatGroups);
        await m.createTable(chatMessages);
      }
      await _createIndexes();
    },
    beforeOpen: (details) async {
      // Les cles etrangeres ne sont pas actives par defaut dans SQLite.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Index alignes sur les filtres de recherche les plus frequents (§21).
  Future<void> _createIndexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_teacher_subjects_subject '
          'ON teacher_subjects (subject_id)',
      'CREATE INDEX IF NOT EXISTS idx_teacher_levels_lookup '
          'ON teacher_levels (subject_id, level_id)',
      'CREATE INDEX IF NOT EXISTS idx_certifications_lookup '
          'ON teacher_certifications (subject_id, level_id, score)',
      'CREATE INDEX IF NOT EXISTS idx_jobs_status '
          'ON jobs (status, published_at)',
      'CREATE INDEX IF NOT EXISTS idx_jobs_subject ON jobs (subject_id, city)',
      'CREATE INDEX IF NOT EXISTS idx_tutoring_lookup '
          'ON tutoring_services (active, subject_id, city)',
      'CREATE INDEX IF NOT EXISTS idx_tutoring_teacher '
          'ON tutoring_services (teacher_id)',
      'CREATE INDEX IF NOT EXISTS idx_applications_teacher '
          'ON applications (teacher_id, status)',
      'CREATE INDEX IF NOT EXISTS idx_applications_job '
          'ON applications (job_id, status)',
      'CREATE INDEX IF NOT EXISTS idx_messages_room ON messages (room_id, sent_at)',
      'CREATE INDEX IF NOT EXISTS idx_answers_session ON test_answers (session_id)',
      'CREATE INDEX IF NOT EXISTS idx_sync_status ON sync_queue (status, created_at)',
      'CREATE INDEX IF NOT EXISTS idx_notifications_user '
          'ON notifications (user_id, read, created_at)',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  // --- Metadonnees internes (curseur de synchronisation, version du seed).

  Future<String?> readMeta(String key) async {
    final row = await (select(
      appMeta,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> writeMeta(String key, String value) => into(
    appMeta,
  ).insertOnConflictUpdate(AppMetaCompanion.insert(key: key, value: value));

  Future<void> deleteMeta(String key) =>
      (delete(appMeta)..where((t) => t.key.equals(key))).go();

  /// Journalise une action sans donnée sensible (§51).
  Future<void> audit({
    required String action,
    String? actorId,
    String? entity,
    String? entityId,
    String? metadata,
  }) => into(auditLogs).insert(
    AuditLogsCompanion.insert(
      action: action,
      actorId: Value(actorId),
      entity: Value(entity),
      entityId: Value(entityId),
      metadata: Value(metadata),
    ),
  );

  /// Efface les données de session sans toucher au referentiel embarque.
  Future<void> clearUserData() async {
    // L'ordre suit les dependances de cles etrangeres : les tables filles
    // sont videes avant leurs parents.
    const statements = [
      'DELETE FROM test_answers',
      'DELETE FROM test_sessions',
      'DELETE FROM messages',
      'DELETE FROM interviews',
      'DELETE FROM contracts',
      'DELETE FROM recruitment_offers',
      'DELETE FROM teacher_reviews',
      'DELETE FROM recruitments',
      'DELETE FROM recruitment_events',
      'DELETE FROM recruitment_rooms',
      'DELETE FROM applications',
      'DELETE FROM job_invitations',
      'DELETE FROM notifications',
      'DELETE FROM teacher_certifications',
      'DELETE FROM teacher_experiences',
      'DELETE FROM teacher_diplomas',
      'DELETE FROM teacher_documents',
      'DELETE FROM teacher_levels',
      'DELETE FROM teacher_subjects',
      'DELETE FROM sync_queue',
    ];

    await transaction(() async {
      for (final statement in statements) {
        await customStatement(statement);
      }
    });
  }
}

QueryExecutor _open() => driftDatabase(name: 'veriprof');
