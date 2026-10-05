import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database/app_database.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_enums.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/ai/ai_gateway.dart';
import '../../data/ai/demo_ai_gateway.dart';
import '../../data/repositories/tutoring_repository.dart';
import '../../data/repositories/contracts_repository.dart';
import '../../data/repositories/course_content_repository.dart';
import '../../data/repositories/payment_methods_repository.dart';
import '../../data/repositories/promotions_repository.dart';
import '../../data/repositories/conversations_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../data/repositories/video_courses_repository.dart';
import '../../data/repositories/tutoring_sessions_repository.dart';
import '../../core/curriculum/stages.dart';
import '../../domain/usecases/course_relevance.dart';
import '../../domain/usecases/cycle_match.dart';
import '../../domain/usecases/tutoring_rules.dart';
import '../../data/repositories/verification_repository.dart';
import '../../domain/entities/job_models.dart';
import '../../domain/entities/recruitment_models.dart';
import '../../domain/entities/test_models.dart';
import '../../domain/usecases/test_scoring.dart';
import 'core_providers.dart';
import 'session_providers.dart';

// --- Assistant IA.

/// L'assistant disponible pour le compte connecté.
///
/// Une seule implémentation aujourd'hui : celle qui fabrique tout sur
/// l'appareil, sans modèle. La vraie passera par le serveur — la clé Gemini
/// n'a rien à faire dans l'APK (docs/AI_ASSISTANT.md, §3).
final aiGatewayProvider = Provider<AiGateway?>((ref) {
  final userId = ref.watch(currentSessionProvider)?.userId;
  if (userId == null) return null;
  return DemoAiGateway(
    database: ref.watch(databaseProvider),
    ownerId: userId,
    documentsDirectory: getApplicationDocumentsDirectory,
  );
});

/// Cours construits, dernière version de chacun.
final myCoursesProvider = FutureProvider<List<SavedCourse>>((ref) async {
  final ai = ref.watch(aiGatewayProvider);
  return ai == null ? const [] : ai.courses();
});

/// Après une construction ou une amélioration : la liste se recharge.
void refreshAi(WidgetRef ref) => ref.invalidate(myCoursesProvider);

// --- Cours à domicile.

/// Offres de cours du professeur connecté, actives ou en pause.
final myTutoringOffersProvider = FutureProvider<List<TutoringOffer>>((
  ref,
) async {
  final teacherId = ref.watch(currentTeacherIdProvider);
  if (teacherId == null) return const [];
  return ref.watch(tutoringRepositoryProvider).offersOf(teacherId);
});

/// Disponibilité du professeur connecté pour les cours à domicile.
final tutoringAvailabilityProvider =
    FutureProvider<({Set<Weekday> days, Set<DaySlot> slots})>((ref) async {
      final teacherId = ref.watch(currentTeacherIdProvider);
      if (teacherId == null) {
        return (days: <Weekday>{}, slots: <DaySlot>{});
      }
      return ref.watch(tutoringRepositoryProvider).availabilityOf(teacherId);
    });

/// Toutes les offres de cours a domicile en ligne.
final allTutoringOffersProvider = FutureProvider<List<TutoringOffer>>(
  (ref) async => ref.watch(tutoringRepositoryProvider).allActiveOffers(),
);

/// Offres actives d'un professeur, telles qu'un parent les voit.
final teacherTutoringOffersProvider =
    FutureProvider.family<List<TutoringOffer>, String>(
      (ref, teacherId) => ref
          .watch(tutoringRepositoryProvider)
          .offersOf(teacherId, onlyActive: true),
    );

/// Demandes reçues par le professeur connecté.
final teacherTutoringRequestsProvider =
    FutureProvider<List<TutoringRequestItem>>((ref) async {
      final teacherId = ref.watch(currentTeacherIdProvider);
      if (teacherId == null) return const [];
      return ref.watch(tutoringRepositoryProvider).requestsOfTeacher(teacherId);
    });

/// Demandes envoyées par le parent connecté.
// --- Chiffres des tableaux de bord.

final teacherMetricsProvider = FutureProvider<TeacherStats?>((ref) async {
  final id = ref.watch(currentTeacherIdProvider);
  if (id == null) return null;
  return ref.watch(statsRepositoryProvider).ofTeacher(id);
});

final institutionMetricsProvider = FutureProvider<InstitutionStats?>((
  ref,
) async {
  final id = ref.watch(currentSessionProvider)?.institutionId;
  if (id == null) return null;
  return ref.watch(statsRepositoryProvider).ofInstitution(id);
});

final familyMetricsProvider = FutureProvider<FamilyStats?>((ref) async {
  final id = ref.watch(currentSessionProvider)?.parentId;
  if (id == null) return null;
  return ref.watch(statsRepositoryProvider).ofParent(id);
});

/// Les chiffres derivent de tout le reste : ils se rafraichissent avec.
/// Les revenus du professeur, jour par jour, sur la semaine ecoulee.
final teacherWeeklyIncomeProvider = FutureProvider<List<DailyIncome>>((
  ref,
) async {
  final id = ref.watch(currentTeacherIdProvider);
  if (id == null) return const [];
  return ref.watch(statsRepositoryProvider).weeklyIncome(id);
});

/// Les fils de discussion de la personne connectee.
final conversationsProvider = FutureProvider<List<ConversationItem>>((
  ref,
) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return const [];
  return ref
      .watch(conversationsRepositoryProvider)
      .of(
        teacherId: session.role == UserRole.teacher ? session.teacherId : null,
        parentId: session.role.followsAStudent ? session.parentId : null,
        // Un etablissement aussi ecrit aux professeurs depuis le 02/10 :
        // sans cette ligne il ouvrait un fil puis ne le retrouvait plus.
        institutionId: session.isInstitution ? session.institutionId : null,
        readerId: session.userId,
      );
});

/// Les messages d'un fil.
final conversationMessagesProvider =
    FutureProvider.family<List<ConversationMessage>, String>(
      (ref, id) async =>
          ref.watch(conversationsRepositoryProvider).messages(id),
    );

/// Les professeurs mis de cote par le compte connecte.
final favouritesProvider = FutureProvider<Set<String>>((ref) async {
  final userId = ref.watch(currentSessionProvider)?.userId;
  if (userId == null) return const {};
  return ref.watch(favouritesRepositoryProvider).of(userId);
});

void refreshConversations(WidgetRef ref) {
  ref
    ..invalidate(conversationsProvider)
    ..invalidate(conversationMessagesProvider);
}

void refreshMetrics(WidgetRef ref) {
  ref
    ..invalidate(teacherMetricsProvider)
    ..invalidate(teacherWeeklyIncomeProvider)
    ..invalidate(institutionMetricsProvider)
    ..invalidate(familyMetricsProvider);
}

// --- Moyens de paiement (note du 21/09), communs aux quatre profils.

final paymentMethodsProvider = FutureProvider<List<PaymentMethodItem>>((
  ref,
) async {
  final userId = ref.watch(currentSessionProvider)?.userId;
  if (userId == null) return const [];
  return ref.watch(paymentMethodsRepositoryProvider).of(userId);
});

// --- Promotions d'etablissement (note du 21/09).

/// Les promotions de l'etablissement connecte.
final institutionPromotionsProvider = FutureProvider<List<PromotionItem>>((
  ref,
) async {
  final id = ref.watch(currentSessionProvider)?.institutionId;
  if (id == null) return const [];
  return ref.watch(promotionsRepositoryProvider).ofInstitution(id);
});

/// Les promotions en ligne, vues par les familles.
final activePromotionsProvider = FutureProvider<List<PromotionItem>>(
  (ref) async => ref.watch(promotionsRepositoryProvider).active(),
);

void refreshPromotions(WidgetRef ref) {
  ref
    ..invalidate(institutionPromotionsProvider)
    ..invalidate(activePromotionsProvider);
}

// --- Catalogue de cours video (note du 21/09).

/// Les cours du professeur connecte, brouillons compris — c'est son atelier.
final teacherVideoCoursesProvider = FutureProvider<List<VideoCourseItem>>((
  ref,
) async {
  final id = ref.watch(currentTeacherIdProvider);
  if (id == null) return const [];
  return ref.watch(videoCoursesRepositoryProvider).ofTeacher(id);
});

/// Le catalogue vu par une famille : uniquement ce qui est en vente.
/// Les chapitres d'un cours, avec leurs videos et leurs ressources.
final courseChaptersProvider =
    FutureProvider.family<List<CourseChapter>, String>(
      (ref, courseId) =>
          ref.watch(courseContentRepositoryProvider).chaptersOf(courseId),
    );

/// Les commentaires d'une video.
final courseCommentsProvider =
    FutureProvider.family<List<CourseComment>, String>(
      (ref, itemId) =>
          ref.watch(courseContentRepositoryProvider).commentsOf(itemId),
    );

/// Un cours, retrouve dans la liste deja chargee.
///
/// Le depot n'expose pas de lecture par identifiant, et en ajouter une pour
/// un titre d'en-tete ferait une requete de plus a chaque ouverture : le
/// catalogue est deja en memoire.
final videoCourseProvider = FutureProvider.family<VideoCourseItem?, String>((
  ref,
  courseId,
) async {
  for (final source in [teacherVideoCoursesProvider, videoCatalogProvider]) {
    final liste = await ref.watch(source.future);
    final trouve = liste.where((c) => c.id == courseId).firstOrNull;
    if (trouve != null) return trouve;
  }
  return null;
});

final videoCatalogProvider = FutureProvider<List<VideoCourseItem>>((ref) async {
  final parentId = ref.watch(currentSessionProvider)?.parentId;
  return ref
      .watch(videoCoursesRepositoryProvider)
      .published(parentId: parentId);
});

/// Ce que le professeur a gagne sur ses cours, commission deduite.
final teacherVideoEarningsProvider = FutureProvider<int>((ref) async {
  final id = ref.watch(currentTeacherIdProvider);
  if (id == null) return 0;
  return ref.watch(videoCoursesRepositoryProvider).earningsOf(id);
});

/// Apres toute ecriture : l'atelier et le catalogue lisent la meme table.
void refreshVideoCourses(WidgetRef ref) {
  ref
    ..invalidate(teacherVideoCoursesProvider)
    ..invalidate(videoCatalogProvider)
    ..invalidate(teacherVideoEarningsProvider);
}

// --- Contrats et echeances (maquette du 21/09).

/// Les contrats du professeur connecté.
final teacherContractsProvider = FutureProvider<List<WorkContractItem>>((
  ref,
) async {
  final id = ref.watch(currentTeacherIdProvider);
  if (id == null) return const [];
  return ref.watch(contractsRepositoryProvider).ofTeacher(id);
});

/// Les échéances qui tombent chez le professeur.
final teacherPaymentsProvider = FutureProvider<List<ContractPaymentItem>>((
  ref,
) async {
  final id = ref.watch(currentTeacherIdProvider);
  if (id == null) return const [];
  return ref.watch(contractsRepositoryProvider).paymentsOfTeacher(id);
});

/// Les professeurs sous contrat avec l'établissement connecté.
final institutionContractsProvider = FutureProvider<List<WorkContractItem>>((
  ref,
) async {
  final id = ref.watch(currentSessionProvider)?.institutionId;
  if (id == null) return const [];
  return ref.watch(contractsRepositoryProvider).ofInstitution(id);
});

/// Les contrats de la famille connectée.
final parentContractsProvider = FutureProvider<List<WorkContractItem>>((
  ref,
) async {
  final id = ref.watch(currentSessionProvider)?.parentId;
  if (id == null) return const [];
  return ref.watch(contractsRepositoryProvider).ofParent(id);
});

/// Les échéances dues par la famille connectée.
final parentPaymentsProvider = FutureProvider<List<ContractPaymentItem>>((
  ref,
) async {
  final id = ref.watch(currentSessionProvider)?.parentId;
  if (id == null) return const [];
  return ref.watch(contractsRepositoryProvider).paymentsOfParent(id);
});

/// La prochaine échéance du parent. C'est la seule qu'il regarde.
final parentNextPaymentProvider = FutureProvider<ContractPaymentItem?>((
  ref,
) async {
  final id = ref.watch(currentSessionProvider)?.parentId;
  if (id == null) return null;
  return ref.watch(contractsRepositoryProvider).nextPaymentOfParent(id);
});

/// Après toute écriture sur un contrat : les trois tableaux de bord lisent
/// la même table, ils doivent se rafraîchir ensemble.
void refreshContracts(WidgetRef ref) {
  ref
    ..invalidate(teacherContractsProvider)
    ..invalidate(teacherPaymentsProvider)
    ..invalidate(institutionContractsProvider)
    ..invalidate(parentContractsProvider)
    ..invalidate(parentPaymentsProvider)
    ..invalidate(parentNextPaymentProvider)
    ..invalidate(teacherMetricsProvider)
    ..invalidate(institutionMetricsProvider)
    ..invalidate(familyMetricsProvider);
}

/// Les séances de cours à domicile du professeur, la plus proche en premier.
final teacherSessionsProvider = FutureProvider<List<TutoringSessionItem>>((
  ref,
) async {
  final id = ref.watch(currentTeacherIdProvider);
  if (id == null) return const [];
  return ref.watch(tutoringSessionsRepositoryProvider).ofTeacher(id);
});

/// Les séances de cours à domicile du parent, la plus proche en premier.
final parentSessionsProvider = FutureProvider<List<TutoringSessionItem>>((
  ref,
) async {
  final parentId = ref.watch(currentSessionProvider)?.parentId;
  if (parentId == null) return const [];
  return ref.watch(tutoringSessionsRepositoryProvider).ofParent(parentId);
});

final parentTutoringRequestsProvider =
    FutureProvider<List<TutoringRequestItem>>((ref) async {
      final parentId = ref.watch(currentSessionProvider)?.parentId;
      if (parentId == null) return const [];
      return ref.watch(tutoringRepositoryProvider).requestsOfParent(parentId);
    });

/// Après toute écriture : les quatre listes se rechargent ensemble, sinon le
/// professeur accepte et le parent voit encore « en attente ».
void refreshTutoring(WidgetRef ref) {
  ref
    ..invalidate(myTutoringOffersProvider)
    ..invalidate(teacherTutoringOffersProvider)
    ..invalidate(teacherTutoringRequestsProvider)
    ..invalidate(parentTutoringRequestsProvider)
    ..invalidate(parentSessionsProvider)
    ..invalidate(teacherSessionsProvider)
    ..invalidate(tutoringAvailabilityProvider)
    // Une séance en plus ou en moins change les heures de la semaine du
    // professeur et le compte « faites / prévues » de la famille.
    ..invalidate(teacherMetricsProvider)
    ..invalidate(familyMetricsProvider);
}

// --- Offres et candidatures (§17, §18).

/// Offres des matières du professeur, sans filtre à régler : la sélection est
/// faite d'office (§17).
final opportunitiesProvider = FutureProvider<List<JobOffer>>((ref) async {
  final teacherId = ref.watch(currentTeacherIdProvider);
  if (teacherId == null) return const [];
  return ref.watch(jobRepositoryProvider).opportunities(teacherId: teacherId);
});

final jobDetailProvider = FutureProvider.family<JobOffer?, String>((
  ref,
  jobId,
) async {
  final teacherId = ref.watch(currentTeacherIdProvider);
  return ref.watch(jobRepositoryProvider).job(jobId, teacherId: teacherId);
});

final myApplicationsProvider = StreamProvider<List<ApplicationItem>>((ref) {
  final teacherId = ref.watch(currentTeacherIdProvider);
  if (teacherId == null) return Stream.value(const []);
  return ref.watch(jobRepositoryProvider).watchApplications(teacherId);
});

// --- Recherche d'enseignants cote établissement (§21).

final teacherSearchFiltersProvider = StateProvider<TeacherSearchFilters>(
  (ref) => const TeacherSearchFilters(),
);

final teacherSearchProvider = FutureProvider<List<RankedCandidate>>((
  ref,
) async {
  final filters = ref.watch(teacherSearchFiltersProvider);
  return ref.watch(jobRepositoryProvider).searchTeachers(filters);
});

final applicantsProvider = FutureProvider.family<List<RankedCandidate>, String>(
  (ref, jobId) async => ref.watch(jobRepositoryProvider).applicantsFor(jobId),
);

/// Fiche parent du compte courant.
final parentRecordProvider = FutureProvider((ref) async {
  final session = ref.watch(currentSessionProvider);
  final parentId = session?.parentId;
  if (parentId == null) return null;
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.parents,
  )..where((t) => t.id.equals(parentId))).getSingleOrNull();
});

/// La fiche de l'etablissement courant.
///
/// Elle porte sa ville — et, depuis le 04/10, ce qu'il cherche : matieres,
/// jours, distance acceptee. Deux ecrans en ont besoin : l'accueil, pour ne
/// pas lister les professeurs de toute la Guinee, et le formulaire d'offre,
/// qui redemandait la matiere, les niveaux et la ville deja connues.
final institutionRecordProvider = FutureProvider((ref) async {
  final id = ref.watch(currentSessionProvider)?.institutionId;
  if (id == null) return null;
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.institutions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
});

/// Enfants declares par le parent courant.
final parentChildrenProvider = FutureProvider((ref) async {
  final session = ref.watch(currentSessionProvider);
  final parentId = session?.parentId;
  if (parentId == null) return const <ChildRow>[];
  final db = ref.watch(databaseProvider);
  return (db.select(db.children)
        ..where((t) => t.parentId.equals(parentId))
        ..orderBy([(t) => OrderingTerm.asc(t.firstName)]))
      .get();
});

/// Professeurs disponibles, restreints a une ville.
///
/// Un parent cherche quelqu'un qui peut venir chez lui : proposer un
/// professeur de Kankan a une famille de Conakry ne sert personne. La ville
/// vient de la fiche parent ; sans ville renseignee, la liste reste large
/// plutot que vide.
final availableTeachersProvider = FutureProvider.family(
  (ref, String? city) async => ref
      .watch(jobRepositoryProvider)
      .searchTeachers(
        TeacherSearchFilters(city: city, availability: Availability.available),
      ),
);

/// Les professeurs qu'une famille peut reellement reserver.
///
/// [availableTeachersProvider] rend tous les professeurs disponibles, y
/// compris ceux qui ne cherchent qu'un poste en etablissement. Une famille
/// qui ouvre leur fiche n'y trouve aucune offre et aucun bouton : la liste
/// lui promettait quelque chose qu'elle ne pouvait pas obtenir.
///
/// Le filtre vit ici et non dans l'ecran : trois ecrans cote famille listent
/// des professeurs, et un filtre recopie trois fois diverge a la premiere
/// correction.
final homeTeachersProvider =
    FutureProvider.family<List<RankedCandidate>, String?>((ref, city) async {
      final teachers = await ref.watch(availableTeachersProvider(city).future);
      final offers = await ref.watch(allTutoringOffersProvider.future);
      final proposent = {for (final offer in offers) offer.teacherId};
      return [
        for (final candidate in teachers)
          if (proposent.contains(candidate.profile.teacherId)) candidate,
      ];
    });

// --- Le palier de l'apprenant, et ce qu'il filtre ------------------------
//
// « Pas de professeur d'universite pour un eleve de 7eme. » La regle elle-meme
// est pure et vit dans `domain/usecases/cycle_match.dart` ; ici on lui fournit
// le palier et on expose le resultat.

/// L'apprenant dont le niveau sert de filtre.
///
/// Nul = le premier de la liste. Un parent peut suivre plusieurs enfants a des
/// paliers differents, et le filtre n'a alors de sens que rapporte a l'un
/// d'eux ; l'ecran propose de changer des qu'il y en a deux.
final selectedLearnerIdProvider = StateProvider<String?>((ref) => null);

/// L'apprenant retenu : l'enfant choisi, ou l'universitaire lui-meme.
final selectedLearnerProvider = FutureProvider<ChildRow?>((ref) async {
  final apprenants = await ref.watch(parentChildrenProvider.future);
  if (apprenants.isEmpty) return null;
  final choisi = ref.watch(selectedLearnerIdProvider);
  return apprenants.firstWhere(
    (a) => a.id == choisi,
    orElse: () => apprenants.first,
  );
});

/// Ce qu'on sait de l'apprenant retenu, pour classer le catalogue.
///
/// La classe et les matieres sont demandees a l'inscription et n'etaient lues
/// par aucun ecran de contenu : le catalogue video ne filtrait que le statut,
/// donc un universitaire voyait celui d'un eleve de CE2. Les deux cotes de la
/// jointure existaient pourtant — `video_courses` porte `subject_id` et
/// `level_ids`.
final learnerTasteProvider = FutureProvider<LearnerTaste>((ref) async {
  final apprenant = await ref.watch(selectedLearnerProvider.future);
  if (apprenant == null) return const LearnerTaste();
  return LearnerTaste(
    levelId: apprenant.levelId,
    subjectIds: {
      for (final id in apprenant.subjectIds.split(','))
        if (id.trim().isNotEmpty) id.trim(),
    },
  );
});

/// Les cours a mettre en avant sur l'accueil — vides si rien ne correspond.
final recommendedCoursesProvider = FutureProvider<List<VideoCourseItem>>((
  ref,
) async {
  final taste = await ref.watch(learnerTasteProvider.future);
  if (taste.isEmpty) return const [];
  final catalogue = await ref.watch(videoCatalogProvider.future);
  return recommendedCourses(
    catalogue,
    taste: taste,
    subjectOf: (c) => c.row.subjectId,
    levelsOf: (c) => [
      for (final id in c.row.levelIds.split(','))
        if (id.trim().isNotEmpty) id.trim(),
    ],
  );
});

/// Le catalogue, ce qui parle a l'apprenant d'abord.
///
/// Un tri et non un filtre : un cours d'une autre classe sert a reviser
/// l'annee passee, et un catalogue qui retrecit en silence fait croire qu'il
/// n'y a que trois cours.
final sortedCatalogProvider = FutureProvider<List<VideoCourseItem>>((
  ref,
) async {
  final catalogue = await ref.watch(videoCatalogProvider.future);
  final taste = await ref.watch(learnerTasteProvider.future);
  return coursesByAffinity(
    catalogue,
    taste: taste,
    subjectOf: (c) => c.row.subjectId,
    levelsOf: (c) => [
      for (final id in c.row.levelIds.split(','))
        if (id.trim().isNotEmpty) id.trim(),
    ],
  );
});

/// Le cycle de l'apprenant retenu : `PRIMAIRE`, `COLLEGE`, `LYCEE`…
///
/// Nul quand aucun niveau n'est enregistre — et la regle ne filtre alors rien,
/// plutot que de rendre une liste vide.
final learnerCycleProvider = FutureProvider<String?>((ref) async {
  final apprenant = await ref.watch(selectedLearnerProvider.future);
  final levelId = apprenant?.levelId;
  if (levelId == null) return null;

  final db = ref.watch(databaseProvider);
  final niveau = await (db.select(
    db.levels,
  )..where((t) => t.id.equals(levelId))).getSingleOrNull();
  final cycle = niveau?.cycle ?? '';
  return cycle.isEmpty ? null : cycle;
});

/// Le filtre par palier est-il actif ?
///
/// Vrai par defaut : c'est ce qu'une famille veut dans la quasi-totalite des
/// cas. Mais un defaut, pas une prison — exactement comme la ville et comme le
/// « seulement a domicile » du site. Un parent peut chercher un professeur
/// d'universite pour son lyceen de Terminale, et il doit pouvoir.
final cycleFilterEnabledProvider = StateProvider<bool>((ref) => true);

/// Les cycles qu'un professeur declare enseigner.
///
/// Vide quand son profil ne declare aucun niveau : la regle garde alors le
/// professeur, voir `cycle_match.dart`.
Set<String> cyclesOfCandidate(RankedCandidate candidate) => {
  for (final capacite in candidate.profile.capabilities)
    for (final niveau in capacite.levels) ...niveau.cycles,
};

/// Les professeurs reservables ET qui enseignent au palier de l'apprenant.
///
/// Deux filtres empiles, et chacun repond a une phrase de la note du 02/10 :
/// « par defaut a domicile » ([homeTeachersProvider]) et « pas de prof
/// universitaire pour des eleves » (celui-ci).
final bookableTeachersProvider =
    FutureProvider.family<List<RankedCandidate>, String?>((ref, city) async {
      final professeurs = await ref.watch(homeTeachersProvider(city).future);
      if (!ref.watch(cycleFilterEnabledProvider)) return professeurs;

      final cycle = await ref.watch(learnerCycleProvider.future);
      return teachersForCycle(
        professeurs,
        learnerCycle: cycle,
        cyclesOf: cyclesOfCandidate,
      );
    });

/// Le nom affichable d'un cycle : `COLLEGE` -> « Collégien ».
///
/// Les paliers nomment la personne, pas le cycle : la phrase affichee est
/// « Niveau : Collegien », reponse a « ou en est votre enfant ».
final stageNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final paliers = await loadStages();
  return {for (final palier in paliers) palier.id: palier.name};
});

/// Le filtre par palier retire-t-il quelqu'un ?
///
/// Pour n'afficher l'indication que lorsqu'elle dit quelque chose.
final cycleFilterBitesProvider = FutureProvider.family<bool, String?>((
  ref,
  city,
) async {
  final professeurs = await ref.watch(homeTeachersProvider(city).future);
  final cycle = await ref.watch(learnerCycleProvider.future);
  return cycleFilterBites(
    professeurs,
    learnerCycle: cycle,
    cyclesOf: cyclesOfCandidate,
  );
});

/// Fiche complete d'un etablissement (§19).
final institutionByIdProvider = FutureProvider.family(
  (ref, String institutionId) async =>
      ref.watch(catalogRepositoryProvider).institutionById(institutionId),
);

/// Etablissements consultables, filtres par ville le cas echeant.
final institutionProfilesProvider = FutureProvider.family(
  (ref, String? city) async =>
      ref.watch(catalogRepositoryProvider).institutionProfiles(city: city),
);

final teacherProfileByIdProvider = FutureProvider.family(
  (ref, String teacherId) async =>
      ref.watch(teacherRepositoryProvider).profile(teacherId),
);

// --- Vérification (§6, §7).

final identityStateProvider = StreamProvider<IdentityVerificationState>((ref) {
  final teacherId = ref.watch(currentTeacherIdProvider);
  if (teacherId == null) {
    return Stream.value(
      const IdentityVerificationState(status: VerificationStatus.none),
    );
  }
  return ref
      .watch(verificationRepositoryProvider)
      .watchIdentityState(teacherId);
});

final documentsProvider = FutureProvider<List<DocumentItem>>((ref) async {
  final teacherId = ref.watch(currentTeacherIdProvider);
  if (teacherId == null) return const [];
  return ref.watch(verificationRepositoryProvider).documents(teacherId);
});

// --- Tests (§10 a §13).

final availableTestsProvider = StreamProvider<List<TestSummary>>((ref) {
  final teacherId = ref.watch(currentTeacherIdProvider);
  if (teacherId == null) return Stream.value(const []);
  return ref.watch(testRepositoryProvider).watchAvailableTests(teacherId);
});

final testSummaryProvider = FutureProvider.family<TestSummary?, String>((
  ref,
  testId,
) async {
  final teacherId = ref.watch(currentTeacherIdProvider);
  if (teacherId == null) return null;
  return ref.watch(testRepositoryProvider).test(testId, teacherId);
});

final testResultProvider = FutureProvider.family<TestResult?, String>(
  (ref, sessionId) async => ref.watch(testRepositoryProvider).result(sessionId),
);

final testReviewProvider = FutureProvider.family(
  (ref, String sessionId) async =>
      ref.watch(testRepositoryProvider).reviewAnswers(sessionId),
);

final testHistoryProvider = FutureProvider((ref) async {
  final teacherId = ref.watch(currentTeacherIdProvider);
  if (teacherId == null) return const [];
  return ref.watch(testRepositoryProvider).history(teacherId);
});

/// Session de test en cours — chronomètre, réponses et sauvegarde (§10.3, §11).
class TestSessionController
    extends StateNotifier<AsyncValue<TestSessionData?>> {
  TestSessionController(this._ref, this.sessionId)
    : super(const AsyncValue.loading()) {
    _load();
  }

  final Ref _ref;
  final String sessionId;
  Timer? _ticker;
  Timer? _autosave;
  int _questionElapsed = 0;

  Future<void> _load() async {
    state = await AsyncValue.guard(
      () => _ref.read(testRepositoryProvider).loadSession(sessionId),
    );
    final data = state.valueOrNull;
    if (data != null && data.status == TestSessionStatus.inProgress) {
      _startTimers();
    }
  }

  void _startTimers() {
    _ticker?.cancel();
    _autosave?.cancel();

    // Le chronomètre continue même sans connexion (§11).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final data = state.valueOrNull;
      if (data == null) return;

      final remaining = data.remainingSeconds - 1;
      _questionElapsed++;

      if (remaining <= 0) {
        state = AsyncValue.data(data.copyWith(remainingSeconds: 0));
        unawaited(submit());
        return;
      }
      state = AsyncValue.data(data.copyWith(remainingSeconds: remaining));
    });

    _autosave = Timer.periodic(AppConstants.testAutosaveInterval, (_) {
      unawaited(_persistProgress());
    });
  }

  Future<void> _persistProgress() async {
    final data = state.valueOrNull;
    if (data == null) return;
    await _ref
        .read(testRepositoryProvider)
        .saveProgress(
          sessionId: sessionId,
          currentIndex: data.currentIndex,
          remainingSeconds: data.remainingSeconds,
        );
  }

  /// Selectionne une réponse — écrite immediatement en base locale (§11).
  Future<void> answer(String questionId, String answerKey) async {
    final data = state.valueOrNull;
    if (data == null || data.status != TestSessionStatus.inProgress) return;

    state = AsyncValue.data(
      data.copyWith(answers: {...data.answers, questionId: answerKey}),
    );

    await _ref
        .read(testRepositoryProvider)
        .saveAnswer(
          sessionId: sessionId,
          questionId: questionId,
          answerKey: answerKey,
          elapsedSeconds: _questionElapsed,
        );
  }

  Future<void> next() async {
    final data = state.valueOrNull;
    if (data == null || data.isLastQuestion) return;
    _questionElapsed = 0;
    state = AsyncValue.data(data.copyWith(currentIndex: data.currentIndex + 1));
    await _persistProgress();
  }

  Future<void> previous() async {
    final data = state.valueOrNull;
    if (data == null || data.currentIndex == 0) return;
    _questionElapsed = 0;
    state = AsyncValue.data(data.copyWith(currentIndex: data.currentIndex - 1));
    await _persistProgress();
  }

  Future<void> goTo(int index) async {
    final data = state.valueOrNull;
    if (data == null) return;
    if (index < 0 || index >= data.questions.length) return;
    _questionElapsed = 0;
    state = AsyncValue.data(data.copyWith(currentIndex: index));
    await _persistProgress();
  }

  /// Soumission definitive — les réponses ne sont plus modifiables (§10.3).
  Future<TestResult?> submit() async {
    final data = state.valueOrNull;
    if (data == null) return null;

    _ticker?.cancel();
    _autosave?.cancel();
    await _persistProgress();

    final result = await _ref.read(testRepositoryProvider).submit(sessionId);
    state = AsyncValue.data(data.copyWith(status: TestSessionStatus.scored));
    // Le profil evolue : nouvelle certification, completion, trust score.
    _ref.invalidate(availableTestsProvider);
    return result;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _autosave?.cancel();
    // La progression est conservée pour permettre la reprise (§10.3).
    unawaited(_persistProgress());
    super.dispose();
  }
}

final testSessionProvider =
    StateNotifierProvider.family<
      TestSessionController,
      AsyncValue<TestSessionData?>,
      String
    >((ref, sessionId) => TestSessionController(ref, sessionId));

// --- Espaces de recrutement (§24).

final recruitmentRoomProvider =
    StreamProvider.family<RecruitmentRoomView?, String>(
      (ref, roomId) =>
          ref.watch(recruitmentRepositoryProvider).watchRoom(roomId),
    );

final teacherRoomsProvider = FutureProvider<List<RecruitmentRoomView>>((
  ref,
) async {
  final teacherId = ref.watch(currentTeacherIdProvider);
  if (teacherId == null) return const [];
  return ref.watch(recruitmentRepositoryProvider).rooms(teacherId: teacherId);
});

final institutionRoomsProvider = FutureProvider<List<RecruitmentRoomView>>((
  ref,
) async {
  final institutionId = ref.watch(currentInstitutionIdProvider);
  if (institutionId == null) return const [];
  return ref
      .watch(recruitmentRepositoryProvider)
      .rooms(institutionId: institutionId);
});

final teacherRecruitmentsProvider = FutureProvider((ref) async {
  final teacherId = ref.watch(currentTeacherIdProvider);
  if (teacherId == null) return const [];
  return ref
      .watch(recruitmentRepositoryProvider)
      .teacherRecruitments(teacherId);
});
