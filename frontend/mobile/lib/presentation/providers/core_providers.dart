import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_enums.dart';
import '../../core/network/api_client.dart';
import '../../core/network/network_status_service.dart';
import '../../core/security/identity_checks.dart';
import '../../core/security/secure_store.dart';
import '../../core/storage/document_pipeline.dart';
import '../../data/local/database/app_database.dart';
import '../../data/remote/chat_api.dart';
import '../../data/remote/live_api.dart';
import '../../data/remote/points_api.dart';
import '../../data/remote/sync_api.dart';
import '../../data/remote/supabase_auth_api.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/contracts_repository.dart';
import '../../data/repositories/conversations_repository.dart';
import '../../data/repositories/favourites_repository.dart';
import '../../data/repositories/payment_methods_repository.dart';
import '../../data/repositories/promotions_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../data/repositories/video_courses_repository.dart';
import '../../data/repositories/tutoring_sessions_repository.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/repositories/children_repository.dart';
import '../../data/repositories/course_content_repository.dart';
import '../../data/repositories/job_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/recruitment_repository.dart';
import '../../data/repositories/teacher_repository.dart';
import '../../data/repositories/test_repository.dart';
import '../../data/repositories/tutoring_repository.dart';
import '../../data/repositories/verification_repository.dart';
import '../../data/sync/sync_engine.dart';

/// Injection des dependances (§38, §39).
///
/// Les services longue durée — base, réseau, synchronisation — sont
/// initialises une seule fois au demarrage puis injectes via `overrideWithValue`.

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider doit etre surcharge'),
);

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final networkServiceProvider = Provider<NetworkStatusService>(
  (ref) =>
      throw UnimplementedError('networkServiceProvider doit etre surcharge'),
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => throw UnimplementedError('syncEngineProvider doit etre surcharge'),
);

final dioProvider = Provider<Dio>(
  (ref) => buildApiClient(() => ref.read(secureStoreProvider).accessToken),
);

final syncApiProvider = Provider<SyncApi>(
  (ref) => SyncApi(ref.watch(dioProvider)),
);

/// Les cours en direct : grille, inscription, rediffusion, presence.
///
/// Le seul point de sortie vers le serveur pour cette fonction. Elle ne passe
/// pas par Drift et ne se synchronise pas : une place se prend au serveur, un
/// jeton de salle expire, et une adresse de rediffusion est signee pour
/// quelques heures. Les trois perdent leur sens en differe.
final liveApiProvider = Provider<LiveApi>(
  (ref) => LiveApi(ref.watch(dioProvider)),
);

/// Les groupes de discussion : un cours en direct, un contrat.
///
/// Serveur uniquement pour la lecture et l'envoi. L'appartenance est calculee
/// par Postgres (`est_membre_groupe`) et non par le telephone : un client qui
/// deciderait lui-meme de ce qu'il peut lire deciderait d'entrer dans un
/// groupe d'enfants. Et un message doit arriver aux autres — une file qui
/// rattrape dans une heure fait repondre a une question oubliee.
final chatApiProvider = Provider<ChatApi>(
  (ref) => ChatApi(ref.watch(dioProvider)),
);

/// Points de fidelite et concours.
///
/// Serveur uniquement, et pour une raison de fond : le solde est la somme d'un
/// journal que le serveur seul ecrit, et un rang se calcule sur les copies de
/// tous les autres. Les calculer ici donnerait deux chiffres pour la meme
/// question, et c'est celui du telephone qu'on croirait.
final pointsApiProvider = Provider<PointsApi>(
  (ref) => PointsApi(ref.watch(dioProvider)),
);

/// Le contenu d'un cours video : chapitres, elements, commentaires.
final courseContentRepositoryProvider = Provider<CourseContentRepository>(
  (ref) => CourseContentRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
  ),
);

final documentPipelineProvider = Provider<DocumentPipeline>(
  (ref) => DocumentPipeline(),
);

final identityCheckProvider = Provider<IdentityCheckService>(
  (ref) => const LocalIdentityCheckService(),
);

// --- Depots.

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(databaseProvider)),
);

final teacherRepositoryProvider = Provider<TeacherRepository>(
  (ref) => TeacherRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
  ),
);

final jobRepositoryProvider = Provider<JobRepository>(
  (ref) => JobRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
    ref.watch(teacherRepositoryProvider),
  ),
);

final childrenRepositoryProvider = Provider<ChildrenRepository>(
  (ref) => ChildrenRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
  ),
);

final tutoringRepositoryProvider = Provider<TutoringRepository>(
  (ref) => TutoringRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
  ),
);

final testRepositoryProvider = Provider<TestRepository>(
  (ref) => TestRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
  ),
);

final verificationRepositoryProvider = Provider<VerificationRepository>(
  (ref) => VerificationRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
    ref.watch(documentPipelineProvider),
    ref.watch(identityCheckProvider),
  ),
);

final recruitmentRepositoryProvider = Provider<RecruitmentRepository>(
  (ref) => RecruitmentRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
    ref.watch(jobRepositoryProvider),
    ref.watch(teacherRepositoryProvider),
  ),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(databaseProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final network = ref.watch(networkServiceProvider);
  return AuthRepository(
    ref.watch(databaseProvider),
    ref.watch(secureStoreProvider),
    ref.watch(syncEngineProvider),
    isServerReachable: () => network.state == NetworkState.serverAvailable,
    // L'identite partagee avec le site, quand un projet Supabase a ete
    // configure a la compilation. Sinon `null`, et l'application reste
    // entierement locale comme avant.
    identity: SupabaseAuthApi.isConfigured
        ? SupabaseAuthApi(ref.watch(dioProvider))
        : null,
  );
});

// --- États transverses.

/// État réseau courant (§42).
final networkStateProvider = StreamProvider<NetworkState>((ref) {
  final service = ref.watch(networkServiceProvider);
  return service.stream;
});

/// État de la synchronisation (§44).
final syncStateProvider = StreamProvider<SyncState>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.stream;
});

/// Vrai lorsque l'application fonctionne en mode degrade.
final isOfflineProvider = Provider<bool>((ref) {
  final state = ref.watch(networkStateProvider).valueOrNull;
  final service = ref.watch(networkServiceProvider);
  return (state ?? service.state).isOffline;
});

// --- Referentiel.

final subjectsProvider = FutureProvider(
  (ref) async => ref.watch(catalogRepositoryProvider).subjects(),
);

final levelsProvider = FutureProvider(
  (ref) async => ref.watch(catalogRepositoryProvider).levels(),
);

final levelsByCategoryProvider = FutureProvider(
  (ref) async => ref.watch(catalogRepositoryProvider).levelsByCategory(),
);

/// Les trois profils du second cycle (sciences mathématiques, sciences
/// expérimentales, sciences sociales).
final paymentMethodsRepositoryProvider = Provider(
  (ref) => PaymentMethodsRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
  ),
);

final promotionsRepositoryProvider = Provider(
  (ref) => PromotionsRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
  ),
);

final videoCoursesRepositoryProvider = Provider(
  (ref) => VideoCoursesRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
  ),
);

final favouritesRepositoryProvider = Provider(
  (ref) => FavouritesRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
  ),
);

final conversationsRepositoryProvider = Provider(
  (ref) => ConversationsRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
  ),
);

final statsRepositoryProvider = Provider(
  (ref) => StatsRepository(ref.watch(databaseProvider)),
);

final contractsRepositoryProvider = Provider(
  (ref) => ContractsRepository(
    ref.watch(databaseProvider),
    ref.watch(syncEngineProvider),
  ),
);

final tutoringSessionsRepositoryProvider = Provider(
  (ref) => TutoringSessionsRepository(ref.watch(databaseProvider)),
);

final filieresProvider = FutureProvider(
  (ref) async => ref.watch(catalogRepositoryProvider).filieres(),
);

final citiesProvider = FutureProvider<List<String>>((ref) async {
  final fromData = await ref.watch(catalogRepositoryProvider).cities();
  // Les villes de référence restent proposees même sans donnée locale.
  return {...AppConstants.cities, ...fromData}.toList()..sort();
});
