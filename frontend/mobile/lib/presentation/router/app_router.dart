import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_enums.dart';
import '../providers/core_providers.dart';
import '../providers/session_providers.dart';
import '../screens/auth/discover_screen.dart';
import '../screens/auth/landing_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/assistant/assistant_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/institution/institution_shell.dart';
import '../screens/kyc/kyc_flow_screen.dart';
import '../screens/onboarding/onboarding_flow_screen.dart';
import '../screens/messages/messages_screen.dart';
import '../screens/onboarding/presentation_screen.dart';
import '../screens/onboarding/signup_completion.dart';
import '../screens/onboarding/signup_flow_screen.dart';
import '../screens/parent/children_screen.dart';
import '../screens/parent/institution_detail_screen.dart';
import '../screens/contests/contests_page.dart';
import '../screens/contests/shop_page.dart';
import '../screens/parent/parent_shell.dart';
import '../screens/institution/job_applicants_screen.dart';
import '../screens/institution/publish_job_screen.dart';
import '../screens/institution/teacher_search_screen.dart';
import '../screens/recruitment/contract_screen.dart';
import '../screens/recruitment/recruitment_room_screen.dart';
import '../screens/recruitment/signature_screen.dart';
import '../screens/shared/notifications_screen.dart';
import '../screens/shared/sync_screen.dart';
import '../screens/shared/teacher_public_profile_screen.dart';
import '../screens/teacher/applications_screen.dart';
import '../screens/teacher/availability_screen.dart';
import '../screens/teacher/certifications_screen.dart';
import '../screens/teacher/diploma_form_screen.dart';
import '../screens/teacher/diplomas_screen.dart';
import '../screens/teacher/experience_screen.dart';
import '../screens/teacher/identity_screen.dart';
import '../screens/teacher/job_detail_screen.dart';
import '../screens/teacher/profile_completion_screen.dart';
import '../screens/teacher/profile_edit_screen.dart';
import '../screens/teacher/subjects_screen.dart';
import '../screens/teacher/teacher_levels_screen.dart';
import '../screens/teacher/teacher_offers_tab.dart';
import '../screens/teacher/teacher_shell.dart';
import '../screens/teacher/test_intro_screen.dart';
import '../screens/teacher/test_result_screen.dart';
import '../screens/teacher/test_review_screen.dart';
import '../screens/teacher/test_runner_screen.dart';
import '../screens/teacher/tests_screen.dart';
import '../screens/tutoring/teacher_tutoring_screen.dart';
import '../screens/auth/password_reset_screen.dart';
import '../screens/billing/payment_methods_page.dart';
import '../screens/shared/contact_screen.dart';
import '../screens/catalog/catalog_page.dart';
import '../screens/catalog/course_form_page.dart';
import '../screens/catalog/course_player_page.dart';
import '../screens/live/live_grid_page.dart';
import '../screens/live/live_room_page.dart';
import '../screens/chat/chat_groups_page.dart';
import '../screens/chat/chat_room_page.dart';
import '../screens/live/publish_course_page.dart';
import '../screens/live/presence_proof_page.dart';
import '../screens/live/session_replay_page.dart';
import '../screens/live/teacher_live_page.dart';
import '../screens/catalog/promotion_form_page.dart';
import '../screens/institution/home_teachers_screen.dart';
import '../screens/institution/institution_promotions_tab.dart';
import '../screens/dashboards/calendar_page.dart';
import '../screens/dashboards/contract_detail_screen.dart';
import '../screens/dashboards/contracts_screen.dart';
import '../screens/dashboards/institution_dashboard.dart';
import '../screens/dashboards/payments_screen.dart';
import '../screens/dashboards/teacher_dashboard.dart';
import '../screens/dashboards/teacher_profile_page.dart';
import '../screens/tutoring/tutoring_availability_screen.dart';
import '../screens/tutoring/tutoring_setup_screen.dart';
import '../screens/tutoring/tutoring_offer_form_screen.dart';

/// Routes de l'application (§55, §56).
abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const otp = '/otp';

  /// Écrans de présentation, après la création du compte.
  static const presentation = '/bienvenue';

  /// Écran du code pour un compte donné.
  ///
  /// Construit ici et nulle part ailleurs : écrire l'URL à la main a déjà
  /// produit un `\$userId` échappé, qui envoyait le texte « $userId » au lieu
  /// de l'identifiant — et chaque inscription finissait sur « Compte
  /// introuvable ».
  static String otpFor(String userId) =>
      Uri(path: otp, queryParameters: {'userId': userId}).toString();

  /// Accueil d'un profil connecté.
  ///
  /// Une seule table pour les trois écrans qui ouvrent une session (splash,
  /// connexion, code) : chacun la réécrivait, et deux sur trois oubliaient
  /// le parent, envoyé alors dans l'espace enseignant.
  static String homeFor(UserRole role) => switch (role) {
    UserRole.institution => institutionHome,
    // L'etudiant majeur partage l'espace du parent : meme scolarite suivie,
    // memes contrats, meme calendrier. Lui en construire un second ne
    // changerait que le mot « enfant ».
    UserRole.parent || UserRole.student => parentHome,
    _ => teacherHome,
  };

  static const teacherHome = '/teacher';
  static const teacherOffers = '/teacher/offers';
  static const teacherApplications = '/teacher/applications';
  static const teacherAssistant = '/teacher/assistant';
  static const teacherMessages = '/teacher/messages';
  static const teacherProfile = '/teacher/profile';
  static const teacherIdentityFlow = '/teacher/identity/flow';
  static const teacherProfileEdit = '/teacher/profile/edit';
  static const teacherCalendar = '/teacher/calendrier';
  static const teacherCatalog = '/teacher/catalogue';

  /// Les tests de competence. Ils vivaient au fond du profil ; un test passe
  /// est ce qui fait remonter une fiche, donc il se rejoint depuis le profil.
  static const teacherTests = '/teacher/tests';
  static const parentCatalog = '/parent/catalogue';

  /// Creation d'un cours video (note du 21/09).
  static const courseNew = '/cours/nouveau';

  /// La grille des cours en direct.
  ///
  /// Publique, comme sur le site : on consulte un emploi du temps avant
  /// d'ouvrir un compte. La rediffusion, elle, exige une place payee — le
  /// serveur refuse de signer l'adresse autrement.
  static const live = '/direct';

  /// La salle d'une séance. Le chemin était écrit en clair à chaque endroit
  /// qui l'ouvre ; une faute de frappe dans l'un n'aurait été vue qu'à
  /// l'exécution.
  static String liveRoom(String sessionId) => '/direct/$sessionId/salle';

  /// La rediffusion d'une séance. Rassemblée ici pour la même raison, et
  /// parce qu'un des trois appels partait vers `Navigator.pushReplacementNamed`
  /// — qui attend un *nom* de route, pas un chemin, et qu'aucune route d'ici
  /// ne porte. Le bouton « Voir la rediffusion » plantait donc à la fin de
  /// chaque séance.
  /// La preuve de presence d'une seance passee.
  ///
  /// « Votre enfant etait la. Vous le voyez. » Reservee a la famille qui
  /// detient la place et au professeur du cours : le serveur rend le meme
  /// 404 a tout autre compte qu'a une seance inexistante.
  static String presenceProof(String sessionId) =>
      '/direct/$sessionId/presence';

  static String sessionReplay(String sessionId) =>
      '/direct/$sessionId/rediffusion';

  /// Le cours en direct **côté professeur** : qui est attendu, qui est entré,
  /// et de quoi les faire venir. Distinct de [live], qui est la grille vue par
  /// le public.
  static const teacherLive = '/direct/animer';

  /// Le lecteur d'un cours : chapitres, videos, commentaires (02/10).
  static String coursePlayer(String id) => '/cours/$id';

  /// Configuration d'une promotion d'etablissement (note du 21/09).
  static const promotionNew = '/promotion/nouvelle';

  /// Moyens de paiement et factures, communs aux quatre profils (21/09).
  static const paymentMethods = '/paiement/moyens';

  /// Joindre Eduquali, commun aux quatre profils.
  static const contact = '/contact';

  /// Les groupes de discussion : un par cours en direct suivi.
  ///
  /// Un seul ecran pour les quatre profils : la liste ne montre que les
  /// groupes dont on est membre, et l'appartenance se deduit de la relation.
  static const chatGroups = '/discussions';

  /// Publier un cours en direct. Le parcours manquait entierement : sans lui,
  /// aucun cours n'existait, donc aucune seance, aucune place, aucun groupe.
  static const publishCourse = '/direct/publier';

  /// Un groupe ouvert.
  static String chatGroup(String id) => '/discussions/$id';

  /// La boite de messages d'un etablissement.
  ///
  /// Le professeur et la famille ont la leur dans un onglet ; l'etablissement
  /// en a cinq deja, et un sixieme rendrait la barre illisible. Elle se
  /// rejoint donc par une action rapide et par la cloche.
  static const institutionMessages = '/institution/messages';

  /// Les professeurs de cours a domicile, page separee (note du 21/09).
  static const institutionHomeTeachers = '/institution/repetiteurs';

  /// Creation du compte professeur, en une page (maquette du 21/09).

  /// Mot de passe oublie : recuperation par numero ou par courriel.
  static const passwordReset = '/mot-de-passe-oublie';
  static const parentCalendar = '/parent/calendrier';

  // --- Contrats et echeances (maquette du 21/09), partages par les trois
  // roles : chacun voit le meme contrat de son cote.
  static const contracts = '/contrats';
  static const payments = '/paiements';
  static String contract(String id) => '/contrats/$id';

  /// Inscription complete : decouverte, choix du profil, parcours du profil.
  static const signup = '/inscription';
  static const teacherOnboarding = '/onboarding/teacher';
  static const institutionOnboarding = '/onboarding/institution';

  /// L'ecran d'entree : on cherche d'abord, on ouvre un compte ensuite.
  static const notifications = '/notifications';

  static const landing = '/decouvrir';

  /// Les resultats, publics eux aussi. La requete voyage en parametre pour
  /// qu'un lien partage rouvre la meme recherche.
  static const discover = '/recherche';

  /// [home] vrai cherche des repetiteurs a domicile, faux des professeurs a
  /// recruter. Les deux listent des professeurs, mais pas pour la meme
  /// chose.
  static String discoverFor(String query, {bool home = true}) {
    final parametres = {
      if (query.isNotEmpty) 'q': query,
      'mode': home ? 'domicile' : 'embauche',
    };
    return Uri(path: discover, queryParameters: parametres).toString();
  }

  static const parentOnboarding = '/onboarding/parent';

  static const parentHome = '/parent';
  static const parentTeachers = '/parent/professeurs';
  static const parentProfile = '/parent/profil';
  static const parentChildren = '/parent/enfants';

  /// Concours hebdomadaires, classement et points de fidelite.
  ///
  /// Un seul ecran pour les deux : on y vient pour voir ou l'on se situe, et
  /// pour verifier ce qu'on a gagne. Deux routes separees auraient demande de
  /// deviner laquelle ouvrir depuis l'accueil.
  static const contests = '/concours';

  /// Ce que les points permettent d'obtenir.
  ///
  /// Separee des concours : on va voir la boutique pour se motiver, et le
  /// classement pour se situer. Les melanger noierait le solde entre deux
  /// podiums.
  static const shop = '/boutique';

  /// L'annuaire des etablissements. Il occupait un onglet ; il est devenu une
  /// action rapide, parce qu'un parent ouvre l'application pour savoir quand
  /// son enfant a cours, pas pour parcourir un annuaire.
  static const parentSchools = '/parent/ecoles';

  static const institutionHome = '/institution';
  static const institutionSearch = '/institution/search';
  static const institutionJobs = '/institution/jobs';

  /// Les chiffres de la mise en avant. Un onglet et non une page enfouie :
  /// ce qui est paye tous les mois se consulte tous les mois.
  static const institutionPromotions = '/institution/promotions';
  static const institutionProfile = '/institution/profile';
}

/// Le chemin appartient-il a l'espace d'un **autre** role ?
///
/// La comparaison porte sur des segments entiers, jamais sur un simple
/// prefixe de texte. `'/teachers/t_123'.startsWith('/teacher')` vaut vrai :
/// la fiche publique d'un professeur etait donc prise pour l'espace
/// enseignant, et un etablissement qui l'ouvrait depuis sa recherche se
/// retrouvait renvoye a son accueil, sans un mot d'explication.
/// Les ecrans qui s'ouvrent sans session.
///
/// On regarde avant d'ouvrir un compte : l'ecran d'entree et les resultats
/// de recherche n'en demandent pas. Ce qu'ils montrent est ce qu'un
/// professeur publie de lui-meme ; les coordonnees restent masquees jusqu'au
/// recrutement (§30).
///
/// Sortie de la fermeture du routeur pour etre lisible et testable : une
/// regle d'acces recopiee dans un test ne protege que la copie.
const publicPaths = {
  Routes.splash,
  Routes.landing,
  Routes.discover,
  Routes.login,
  Routes.signup,
  Routes.passwordReset,
  Routes.otp,
};

bool belongsToOtherSpace({required String path, required UserRole role}) {
  const spaces = {
    '/teacher': UserRole.teacher,
    '/institution': UserRole.institution,
    '/parent': UserRole.parent,
  };
  for (final entry in spaces.entries) {
    final inSpace = path == entry.key || path.startsWith('${entry.key}/');
    if (!inSpace) continue;
    // L'espace parent accueille aussi l'etudiant majeur : c'est le meme
    // espace, pas une tolerance.
    final allowed = entry.value == UserRole.parent
        ? role.followsAStudent
        : role == entry.value;
    if (!allowed) return true;
  }
  return false;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.landing, builder: (_, _) => const LandingScreen()),
      GoRoute(
        path: Routes.discover,
        builder: (_, state) => DiscoverScreen(
          query: state.uri.queryParameters['q'] ?? '',
          home: state.uri.queryParameters['mode'] != 'embauche',
        ),
      ),
      GoRoute(
        path: Routes.presentation,
        builder: (_, _) => const PresentationScreen(),
      ),
      GoRoute(
        path: Routes.otp,
        builder: (_, state) =>
            OtpScreen(userId: state.uri.queryParameters['userId'] ?? ''),
      ),

      // --- Espace enseignant (§55), navigation par onglets.
      ShellRoute(
        builder: (_, state, child) =>
            TeacherShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: Routes.teacherHome,
            builder: (_, _) => const TeacherDashboard(),
          ),
          GoRoute(
            path: Routes.teacherOffers,
            builder: (_, _) => const TeacherOffersTab(),
          ),
          GoRoute(
            path: Routes.teacherApplications,
            builder: (_, _) => const ApplicationsScreen(),
          ),
          GoRoute(
            path: Routes.teacherAssistant,
            builder: (_, _) => const AssistantScreen(),
          ),
          GoRoute(
            path: Routes.teacherMessages,
            // La page combinee : les groupes de cours **et** les fils a deux.
            // Pas un onglet de plus — la barre du professeur en compte six, et
            // l'etablissement cinq. Les deux formes de discussion vivent au
            // meme endroit, comme dans n'importe quelle messagerie.
            builder: (_, _) => const ChatGroupsPage(),
          ),
          GoRoute(
            path: Routes.teacherCatalog,
            builder: (_, _) => const CatalogPage(),
          ),
          GoRoute(
            path: Routes.teacherCalendar,
            builder: (_, _) => const CalendarPage(),
          ),
          GoRoute(
            path: Routes.teacherProfile,
            builder: (_, _) => const TeacherProfilePage(),
          ),
        ],
      ),

      // Parcours profil.
      GoRoute(
        path: '/teacher/profile/edit',
        builder: (_, _) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/teacher/completion',
        builder: (_, _) => const ProfileCompletionScreen(),
      ),
      GoRoute(
        path: '/teacher/identity',
        builder: (_, _) => const IdentityScreen(),
      ),
      GoRoute(
        path: Routes.teacherIdentityFlow,
        builder: (_, _) => const KycFlowScreen(),
      ),
      GoRoute(
        path: Routes.teacherOnboarding,
        builder: (_, _) => const TeacherOnboardingScreen(),
      ),
      GoRoute(
        path: Routes.institutionOnboarding,
        builder: (_, _) => const InstitutionOnboardingScreen(),
      ),
      GoRoute(
        path: Routes.parentOnboarding,
        builder: (_, _) => const ParentOnboardingScreen(),
      ),

      // Entree normale : la decouverte precede le choix du profil. Les trois
      // routes ci-dessus restent utilisables comme entrees directes.
      GoRoute(
        path: Routes.institutionHomeTeachers,
        builder: (_, _) => const HomeTeachersScreen(),
      ),
      GoRoute(
        path: Routes.paymentMethods,
        builder: (_, _) => const PaymentMethodsPage(),
      ),
      GoRoute(path: Routes.contact, builder: (_, _) => const ContactScreen()),
      // Les groupes. La liste avant le motif dynamique, pour la meme raison
      // que `/cours/nouveau` : go_router prend la premiere route qui
      // correspond.
      GoRoute(
        path: Routes.chatGroups,
        builder: (_, _) => const ChatGroupsPage(),
      ),
      GoRoute(
        path: '/discussions/:groupId',
        builder: (_, state) => ChatRoomPage(
          groupId: state.pathParameters['groupId']!,
          // Le nom voyage avec la navigation : l'en-tete s'affiche tout de
          // suite au lieu d'attendre une lecture du serveur pour se remplir.
          title: state.uri.queryParameters['nom'],
        ),
      ),
      // La boite de messages de l'etablissement.
      //
      // La constante existait avec sa justification ecrite, la tuile « Mes
      // messages » de son accueil la poussait, et **aucune route ne la
      // declarait** : depuis le 02/10, un etablissement pouvait ecrire a un
      // professeur et tombait sur l'ecran d'erreur de go_router en cherchant
      // la reponse. `MessagesPage` et `conversationsProvider` le servaient
      // pourtant deja tous les deux.
      GoRoute(
        path: Routes.institutionMessages,
        builder: (_, _) => const ChatGroupsPage(),
      ),
      GoRoute(
        path: Routes.promotionNew,
        builder: (_, _) => const PromotionFormPage(),
      ),
      GoRoute(
        path: Routes.courseNew,
        builder: (_, _) => const CourseFormPage(),
      ),
      // Apres `/cours/nouveau`, et non avant : go_router prend la
      // premiere route qui correspond, et un motif dynamique place en tete
      // aurait capture « nouveau » comme identifiant de cours.
      GoRoute(
        path: '/cours/:courseId',
        builder: (_, state) =>
            CoursePlayerPage(courseId: state.pathParameters['courseId']!),
      ),
      GoRoute(path: Routes.live, builder: (_, _) => const LiveGridPage()),
      // Avant les motifs dynamiques, pour la meme raison que
      // `/cours/nouveau` ci-dessus : go_router prend la premiere route qui
      // correspond, et « animer » n'est pas un identifiant de seance.
      GoRoute(
        path: Routes.teacherLive,
        builder: (_, _) => const TeacherLivePage(),
      ),
      GoRoute(
        path: Routes.publishCourse,
        builder: (_, _) => const PublishCoursePage(),
      ),
      // Apres `/direct`, pour la meme raison que `/cours/nouveau` ci-dessus :
      // go_router prend la premiere route qui correspond.
      GoRoute(
        path: '/direct/:sessionId/salle',
        builder: (_, state) =>
            LiveRoomPage(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: '/direct/:sessionId/rediffusion',
        builder: (_, state) =>
            SessionReplayPage(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: '/direct/:sessionId/presence',
        builder: (_, state) =>
            PresenceProofPage(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: Routes.passwordReset,
        builder: (_, _) => const PasswordResetScreen(),
      ),
      GoRoute(
        path: Routes.signup,
        builder: (_, state) => Consumer(
          builder: (context, ref, _) => SignupFlowScreen(
            presetRole: state.uri.queryParameters['role'],
            // Fin de parcours : les reponses deviennent un compte, et la
            // session s'ouvre.
            //
            // Le code de confirmation a ete retire le 25/09. Il ne
            // verifiait rien — aucun SMS ne part, et l'ecran affichait le
            // chiffre a recopier — et il tombait au pire moment : juste
            // apres onze reponses, devant quelqu'un qui vient de creer le
            // compte sur cet appareil meme.
            onCompleted: (role, answers) async {
              final completion = ref.read(signupCompletionProvider);
              final userId = await completion.create(role, answers);
              await completion.attachLearner(role, userId, answers);
              await completion.attachDocuments(userId, answers);
              // Ce que le parcours demandait et jetait (04/10). Chaque appel
              // ne fait rien pour les roles qui ne le concernent pas, et un
              // echec ici ne doit pas empecher le compte d'exister — c'est la
              // meme regle que pour l'apprenant et les documents.
              await completion.attachTeacherProfile(role, userId, answers);
              await completion.attachInstitutionNeeds(role, userId, answers);
              await completion.rememberPlanChoice(userId, answers);

              final auth = ref.read(authRepositoryProvider);
              final session = await auth.openSessionFor(userId);
              await ref.read(sessionProvider.notifier).setSession(session);
              if (context.mounted) {
                context.go(Routes.presentation);
              }
            },
          ),
        ),
      ),
      GoRoute(
        path: '/teacher/diplomas',
        builder: (_, _) => const DiplomasScreen(),
      ),
      GoRoute(
        path: '/teacher/diplomas/add',
        builder: (_, _) => const DiplomaFormScreen(),
      ),
      GoRoute(
        path: '/teacher/subjects',
        builder: (_, _) => const SubjectsScreen(),
      ),
      GoRoute(
        path: '/teacher/levels',
        builder: (_, state) => TeacherLevelsScreen(
          subjectId: state.uri.queryParameters['subjectId'],
        ),
      ),
      GoRoute(
        path: '/teacher/experience',
        builder: (_, _) => const ExperienceScreen(),
      ),
      GoRoute(
        path: '/teacher/availability',
        builder: (_, _) => const AvailabilityScreen(),
      ),

      // Compétences (§10 a §13).
      GoRoute(
        path: Routes.teacherTests,
        builder: (_, _) => const TestsScreen(),
      ),
      GoRoute(
        path: '/teacher/tests/:testId',
        builder: (_, state) =>
            TestIntroScreen(testId: state.pathParameters['testId']!),
      ),
      GoRoute(
        path: '/teacher/session/:sessionId',
        builder: (_, state) =>
            TestRunnerScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: '/teacher/result/:sessionId',
        builder: (_, state) =>
            TestResultScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: '/teacher/result/:sessionId/detail',
        builder: (_, state) =>
            TestReviewScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: '/teacher/certifications',
        builder: (_, _) => const CertificationsScreen(),
      ),

      // --- Cours à domicile.
      GoRoute(
        path: '/teacher/tutoring',
        builder: (_, _) => const TeacherTutoringScreen(),
      ),
      GoRoute(path: Routes.payments, builder: (_, _) => const PaymentsScreen()),
      GoRoute(
        path: Routes.contracts,
        builder: (_, _) => const ContractsScreen(),
      ),
      GoRoute(
        path: '/contrats/:contractId',
        builder: (_, state) => ContractDetailScreen(
          contractId: state.pathParameters['contractId']!,
        ),
      ),
      GoRoute(
        path: Routes.parentSchools,
        builder: (_, _) => const ParentSchoolsScreen(),
      ),
      GoRoute(
        path: Routes.parentChildren,
        builder: (_, _) => const ChildrenScreen(),
      ),
      GoRoute(
        // Mise en place guidee : jours, creneaux, matiere et classes,
        // conditions. Quatre etapes courtes plutot qu'un formulaire unique.
        path: '/teacher/tutoring/setup',
        builder: (_, _) => const TutoringSetupScreen(),
      ),
      GoRoute(
        path: '/teacher/tutoring/availability',
        builder: (_, _) => const TutoringAvailabilityScreen(),
      ),
      GoRoute(
        path: '/teacher/tutoring/new',
        builder: (_, _) => const TutoringOfferFormScreen(),
      ),

      // Emploi (§17, §18).
      GoRoute(
        path: '/teacher/jobs/:jobId',
        builder: (_, state) =>
            JobDetailScreen(jobId: state.pathParameters['jobId']!),
      ),

      // --- Espace établissement (§56).
      ShellRoute(
        builder: (_, state, child) =>
            InstitutionShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: Routes.institutionHome,
            builder: (_, _) => const InstitutionDashboard(),
          ),
          GoRoute(
            path: Routes.institutionSearch,
            builder: (_, _) => const TeacherSearchScreen(),
          ),
          GoRoute(
            path: Routes.institutionJobs,
            builder: (_, _) => const InstitutionJobsTab(),
          ),
          GoRoute(
            path: Routes.institutionPromotions,
            builder: (_, _) => const InstitutionPromotionsTab(),
          ),
          GoRoute(
            path: Routes.institutionProfile,
            builder: (_, _) => const InstitutionProfileTab(),
          ),
        ],
      ),
      GoRoute(
        path: '/institution/jobs/new',
        builder: (_, _) => const PublishJobScreen(),
      ),
      GoRoute(
        path: '/institution/jobs/:jobId/applicants',
        builder: (_, state) =>
            JobApplicantsScreen(jobId: state.pathParameters['jobId']!),
      ),
      GoRoute(
        path: '/teachers/:teacherId',
        builder: (_, state) => TeacherPublicProfileScreen(
          teacherId: state.pathParameters['teacherId']!,
          jobId: state.uri.queryParameters['jobId'],
        ),
      ),

      // --- Espace de recrutement, partage par les deux roles (§24).
      GoRoute(
        path: '/rooms/:roomId',
        builder: (_, state) =>
            RecruitmentRoomScreen(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/rooms/:roomId/contract',
        builder: (_, state) =>
            ContractScreen(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/rooms/:roomId/signature',
        builder: (_, state) =>
            SignatureScreen(roomId: state.pathParameters['roomId']!),
      ),

      // --- Transverse.
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      // --- Espace parent (§55-bis) ---------------------------------------
      GoRoute(
        path: Routes.parentHome,
        builder: (_, _) => const ParentShell(),
        routes: [
          GoRoute(
            path: 'etablissement/:id',
            builder: (_, state) => InstitutionDetailScreen(
              institutionId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.parentTeachers,
        builder: (_, _) => const ParentTeachersScreen(),
      ),
      GoRoute(path: Routes.contests, builder: (_, _) => const ContestsPage()),
      GoRoute(path: Routes.shop, builder: (_, _) => const ShopPage()),
      GoRoute(
        path: Routes.parentProfile,
        // Le profil est le dernier onglet : son indice a suivi l'ajout de
        // l'assistant.
        builder: (_, _) => const ParentShell(initialTab: 5),
      ),
      // Le catalogue cote famille : la meme page que celle du professeur,
      // qui se sert elle-meme selon le role. La constante existait depuis
      // le 21/09 sans route derriere — un lien vers elle renvoyait sur
      // l'accueil sans rien dire.
      GoRoute(
        path: Routes.parentCatalog,
        builder: (_, _) => const ParentShell(initialTab: 2),
      ),

      // Un fil se lit des deux cotes : il vit donc hors des espaces de role,
      // comme les salons de recrutement.
      GoRoute(
        path: '/messages/:id',
        builder: (_, state) =>
            ConversationScreen(conversationId: state.pathParameters['id']!),
      ),

      GoRoute(path: '/sync', builder: (_, _) => const SyncScreen()),
    ],

    // Redirection selon l'état de session (§39).
    redirect: (context, state) {
      final session = ref.read(currentSessionProvider);
      final path = state.uri.path;

      if (session == null) {
        return publicPaths.contains(path) ? null : Routes.splash;
      }

      // L'accueil de chaque role. Un parent tombait jusqu'ici dans l'espace
      // enseignant, faute d'avoir le sien.
      final home = session.isInstitution
          ? Routes.institutionHome
          : session.isParent
          ? Routes.parentHome
          : Routes.teacherHome;

      // Une session ouverte ne doit pas rester sur les ecrans d'accueil.
      // La recherche publique fait exception : un compte deja ouvert peut
      // tres bien vouloir parcourir la meme liste.
      if (publicPaths.contains(path) &&
          path != Routes.splash &&
          path != Routes.discover) {
        return home;
      }

      // Chaque role reste dans son espace.
      return belongsToOtherSpace(path: path, role: session.role) ? home : null;
    },

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page introuvable')),
      body: Center(child: Text('Aucun écran pour « ${state.uri} »')),
    ),
  );
});
