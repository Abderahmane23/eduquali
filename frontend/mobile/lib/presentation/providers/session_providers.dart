import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../domain/usecases/subscription_rules.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/entities/job_models.dart';
import '../../domain/entities/teacher_profile.dart';
import 'core_providers.dart';

/// Session utilisateur courante (§39).
class SessionController extends StateNotifier<AsyncValue<AuthSession?>> {
  SessionController(this._auth) : super(const AsyncValue.loading()) {
    _restore();
  }

  final AuthRepository _auth;

  Future<void> _restore() async {
    state = await AsyncValue.guard(_auth.restore);
  }

  Future<void> setSession(AuthSession session) async {
    state = AsyncValue.data(session);
  }

  Future<void> login(String phone, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _auth.login(phone, password));
  }

  Future<void> loginAsDemoTeacher() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_auth.loginAsDemoTeacher);
  }

  Future<void> loginAsDemoInstitution() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_auth.loginAsDemoInstitution);
  }

  Future<void> loginAsDemoParent() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_auth.loginAsDemoParent);
  }

  /// Souscrit une formule et rafraichit la session.
  ///
  /// La session porte la formule : sans ce rafraichissement, l'ecran
  /// continuerait de refuser la fonction qu'on vient de payer.
  Future<void> subscribe(SubscriptionPlan plan) async {
    final userId = state.valueOrNull?.userId;
    if (userId == null) return;
    final session = await _auth.subscribe(userId, plan.code);
    // Une session nulle voudrait dire que le compte a disparu pendant
    // l'operation : on ne remplace pas l'etat courant par du vide.
    if (session != null) state = AsyncValue.data(session);
  }

  Future<void> logout() async {
    await _auth.logout();
    state = const AsyncValue.data(null);
  }
}

final sessionProvider =
    StateNotifierProvider<SessionController, AsyncValue<AuthSession?>>(
      (ref) => SessionController(ref.watch(authRepositoryProvider)),
    );

/// Session resolue, ou `null` si l'utilisateur n'est pas connecté.
final currentSessionProvider = Provider<AuthSession?>(
  (ref) => ref.watch(sessionProvider).valueOrNull,
);

/// Identifiant enseignant de la session — pratique pour les ecrans dedies.
final currentTeacherIdProvider = Provider<String?>(
  (ref) => ref.watch(currentSessionProvider)?.teacherId,
);

final currentInstitutionIdProvider = Provider<String?>(
  (ref) => ref.watch(currentSessionProvider)?.institutionId,
);

/// Profil enseignant connecté, reactualise a chaque écriture locale.
final currentTeacherProfileProvider = StreamProvider<TeacherProfile?>((ref) {
  final teacherId = ref.watch(currentTeacherIdProvider);
  if (teacherId == null) return Stream.value(null);
  return ref.watch(teacherRepositoryProvider).watchProfile(teacherId);
});

/// Statistiques du tableau de bord établissement (§20).
final institutionStatsProvider = StreamProvider<Map<String, int>>((ref) {
  final institutionId = ref.watch(currentInstitutionIdProvider);
  if (institutionId == null) return Stream.value(const {});
  return ref
      .watch(recruitmentRepositoryProvider)
      .watchInstitutionStats(institutionId);
});

/// Offres publiées par l'établissement connecté.
final institutionJobsProvider = StreamProvider<List<JobOffer>>((ref) {
  final institutionId = ref.watch(currentInstitutionIdProvider);
  if (institutionId == null) return Stream.value(const []);
  return ref.watch(jobRepositoryProvider).watchInstitutionJobs(institutionId);
});

/// Notifications de l'utilisateur connecté (§53).
final notificationsProvider = StreamProvider<List<NotificationItem>>((ref) {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watch(session.userId);
});

/// Nombre de notifications non lues, pour la pastille de la barre d'onglets.
final unreadNotificationsProvider = Provider<int>((ref) {
  final items = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return items.where((n) => !n.read).length;
});
