/// Constantes applicatives et paramètres par defaut.
///
/// Les valeurs marquees « configurable » sont destinees a etre pilotees par le
/// back-office (§10.1, §12, §50) ; elles servent ici de valeurs par defaut
/// disponibles hors ligne.
abstract final class AppConstants {
  static const String appName = 'Eduquali';
  static const String appTagline =
      'Des professeurs vérifiés, près de chez vous';
  static const String currency = 'GNF';
  static const String defaultCountry = 'Guinée';
  static const String phonePrefix = '+224';

  // --- Assistance — configurable en back-office.
  //
  // À REMPLACER avant diffusion : ces trois valeurs sont des espaces
  // réservés, pas les coordonnées réelles d'Eduquali. Elles vivent ici pour
  // qu'une correction touche un fichier et non trois écrans, mais telles
  // quelles elles envoient les utilisateurs dans le vide.
  static const String supportPhone = '+224 000 00 00 00';
  static const String supportWhatsApp = '+224 000 00 00 00';
  static const String supportEmail = 'contact@eduquali.gn';

  /// Adresse de l'API, fixee a la compilation :
  ///
  /// ```
  /// flutter build apk --dart-define=ACALIA_API=https://…/api/v1
  /// ```
  ///
  /// **Vide par defaut, et c'est voulu.** Le serveur n'est pas deploye ; une
  /// adresse inventee ferait attendre l'application a chaque demarrage puis
  /// toutes les 45 secondes, pour un serveur qui n'existe pas. Vide,
  /// l'application travaille en local et ne sonde rien.
  static const String apiBaseUrl = String.fromEnvironment('ACALIA_API');

  /// Vrai quand un serveur a ete configure a la compilation.
  static bool get hasBackend => apiBaseUrl.isNotEmpty;

  /// Projet Supabase, fixe a la compilation :
  ///
  /// ```
  /// flutter build apk --release   ///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co   ///   --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
  /// ```
  ///
  /// Sert a l'identite seulement : le compte est le meme sur le site et sur le
  /// telephone. Les donnees metier continuent de vivre dans la base locale.
  ///
  /// **La cle anonyme dans l'APK ne pose pas de probleme** : elle est publique
  /// par construction — le site l'envoie a chaque visiteur dans son bundle — et
  /// ce n'est pas elle qui protege les donnees, c'est RLS. La regle « aucune
  /// cle dans l'APK » vise la cle Gemini et la cle `service_role`, qui donnent
  /// acces a tout.
  ///
  /// Vides par defaut : l'application reste entierement locale, comme avant.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Delai d'un appel reseau d'authentification.
  ///
  /// Dix secondes : sur une connexion guineenne, en dessous on refuse des
  /// connexions qui auraient abouti ; au-dela, l'ecran reste fige assez
  /// longtemps pour qu'on croie l'application bloquee.
  static const Duration networkTimeout = Duration(seconds: 10);

  static const String healthPath = '/health';

  // --- Tests de compétence (§10, §12) — configurable en back-office.
  static const int testQuestionCount = 60;
  static const int testDurationMinutes = 60;
  static const int testPassingScore = 70;

  /// Sauvegarde locale de la progression pendant le test (§10.3).
  static const Duration testAutosaveInterval = Duration(seconds: 5);

  /// Delai avant de pouvoir repasser un test échoué.
  static const Duration testRetryDelay = Duration(days: 30);

  // --- Synchronisation (§43, §44).
  static const Duration syncInterval = Duration(minutes: 5);
  static const int syncBatchSize = 25;
  static const int syncMaxRetries = 5;

  // --- Documents (§46).
  static const int documentMaxWidth = 1920;
  static const int documentQuality = 82;
  static const int documentMaxBytes = 8 * 1024 * 1024;

  // --- Contenu d'un cours video (02/10).
  /// Taille maximale d'une video de cours.
  ///
  /// Dix fois la limite documentaire, et ce n'est pas une generosite : une
  /// video de cours de vingt minutes ne tient pas dans 8 Mo. La borne existe
  /// quand meme parce que le fichier doit un jour monter au serveur depuis
  /// Conakry — au-dela, le professeur attendrait sans jamais voir la fin, et
  /// mieux vaut le lui dire au moment du choix.
  static const int courseVideoMaxBytes = 80 * 1024 * 1024;

  /// Taille maximale d'une ressource joint a un chapitre (PDF, image).
  ///
  /// Meme limite que les documents de verification : c'est le meme type de
  /// fichier, et le meme reseau.
  static const int courseResourceMaxBytes = documentMaxBytes;

  // --- Modèle economique (§35, §36).
  /// Frais de recrutement = 1 mois de salaire.
  static const double successFeeMonths = 1;
  static const List<int> visibilityBoostDays = [7, 30];

  /// Suivi après recrutement (§32) et garantie de remplacement (§34).
  static const List<int> followUpMilestones = [30, 60, 90];

  /// Ponderations du taux de completion du profil (§16) — total 100.
  static const Map<String, int> completionWeights = {
    'personal_info': 10,
    'photo': 5,
    'identity': 20,
    'diploma': 20,
    'subjects': 10,
    'levels': 10,
    'experience': 5,
    'availability': 5,
    'certification': 15,
  };

  /// Audience annoncee aux etablissements. Chiffre a tenir : l'ecrire ici
  /// evite qu'il derive d'un ecran a l'autre.
  static const int promotionReach = 3000;

  /// Commission retenue sur la vente d'un cours video (21/09).
  ///
  /// Elle se calcule sur le prix affiche, pas en plus : l'eleve paie ce
  /// qu'il voit, et le professeur sait ce qui lui revient.
  static const double videoCourseCommission = 0.20;

  /// Ce que touche le professeur sur un cours vendu.
  static int videoCourseNet(int price) =>
      (price * (1 - videoCourseCommission)).round();

  /// Bareme de mise en relation, fixe le 21/09 — total 100 points.
  ///
  /// La matiere et le niveau n'y figurent pas : ce ne sont pas des points,
  /// ce sont des conditions. Un professeur de francais ne se classe pas
  /// « un peu » sur un poste de mathematiques, il n'y a pas sa place. Une
  /// fois ce filtre passe, ce sont la disponibilite, le diplome et la ville
  /// qui departagent.
  static const Map<String, int> matchingPoints = {
    'availability': 30,
    'diploma': 30,
    'location': 30,
    'experience': 10,
  };

  /// Points par niveau de diplome (21/09).
  static const Map<String, int> diplomaPoints = {
    'DOCTORAT': 30,
    'MASTER': 30,
    'LICENCE': 10,
  };

  /// Ponderations historiques du moteur (§61) — total 1.0.
  ///
  /// Conservees le temps que les ecrans qui les lisent basculent sur
  /// [matchingPoints].
  static const Map<String, double> matchingWeights = {
    'subject': 0.30,
    'level': 0.20,
    'competency': 0.25,
    'experience': 0.10,
    'location': 0.10,
    'availability': 0.05,
  };

  /// Dimensions du Trust Score (§62) — total 100.
  static const Map<String, int> trustWeights = {
    'identity': 25,
    'diploma': 20,
    'competency': 25,
    'experience': 15,
    'reputation': 10,
    'history': 5,
  };

  /// Villes principales, utilisees pour les filtres (§21).
  static const List<String> cities = [
    'Conakry',
    'Kankan',
    'Kindia',
    'Labe',
    'Nzerekore',
    'Boke',
    'Mamou',
    'Faranah',
    'Siguiri',
    'Kissidougou',
  ];

  /// Longueur du code OTP (§5.1).
  static const int otpLength = 6;

  /// Code de vérification unique, accepté **uniquement hors ligne**.
  ///
  /// Sans serveur joignable, aucun SMS ne peut partir : sans ce code, un
  /// testeur de l'APK reste bloqué à l'inscription. Dès que le serveur répond,
  /// il est refusé et seul le vrai code envoyé par SMS ouvre la session.
  ///
  /// À désactiver pour toute version publiée :
  ///   flutter build apk --dart-define=OFFLINE_OTP=false
  static const bool offlineOtpEnabled = bool.fromEnvironment(
    'OFFLINE_OTP',
    defaultValue: true,
  );
  static const String offlineOtpCode = '123456';
  static const Duration otpValidity = Duration(minutes: 5);
  static const Duration otpResendDelay = Duration(seconds: 45);
}
