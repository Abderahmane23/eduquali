// Enumerations métier, avec le code persiste en base et le libelle affiche.
//
// Le `code` est la valeur echangee avec l'API et stockee en SQLite ; il ne
// doit pas changer. Le `label` est destine a l'interface.

enum UserRole {
  teacher('TEACHER', 'Enseignant'),
  institution('INSTITUTION', 'Établissement'),
  parent('PARENT', 'Parent d’élève'),

  /// Majeur qui s'inscrit pour lui-meme — affiche « Universitaire ».
  ///
  /// Distinct du parent : un mineur passe par l'adulte qui consent pour lui,
  /// un majeur n'a personne a qui demander. Leur donner le meme compte
  /// forcerait un etudiant de 22 ans a se declarer « enfant » de quelqu'un.
  ///
  /// Le code reste `STUDENT` : il est ecrit dans SQLite, dans Postgres et dans
  /// les politiques RLS. Seul le libelle change — c'est precisement pourquoi
  /// cette enumeration separe les deux.
  student('STUDENT', 'Universitaire'),

  admin('ADMIN', 'Administrateur');

  const UserRole(this.code, this.label);
  final String code;
  final String label;

  /// Age minimum d'un compte etudiant. En dessous, le consentement revient
  /// a l'adulte : c'est le compte parent.
  static const int studentMinAge = 18;

  /// Les deux roles qui suivent un eleve, vus de l'application.
  bool get followsAStudent => this == parent || this == student;

  static UserRole fromCode(String? code) =>
      UserRole.values.firstWhere((e) => e.code == code, orElse: () => teacher);
}

/// États réseau progressifs (§42) — « Wi-Fi » ne vaut jamais « Internet ».
enum NetworkState {
  noNetwork('NO_NETWORK', 'Aucun réseau'),
  networkAvailable('NETWORK_AVAILABLE', 'Réseau sans Internet'),
  internetReachable('INTERNET_REACHABLE', 'Internet disponible'),
  serverAvailable('SERVER_AVAILABLE', 'Connecté');

  const NetworkState(this.code, this.label);
  final String code;
  final String label;

  /// Seul un serveur joignable autorise un cycle de synchronisation (§44).
  bool get canSync => this == NetworkState.serverAvailable;
  bool get isOffline => this != NetworkState.serverAvailable;
}

/// Statuts de vérification communs aux identités, diplômes et experiences (§7).
enum VerificationStatus {
  none('NONE', 'Non renseigne'),
  pending('PENDING', 'En attente'),
  inReview('IN_REVIEW', 'En cours de vérification'),
  verified('VERIFIED', 'Vérifié'),
  rejected('REJECTED', 'Rejete'),
  needsFix('NEEDS_FIX', 'A corriger');

  const VerificationStatus(this.code, this.label);
  final String code;
  final String label;

  bool get isVerified => this == VerificationStatus.verified;
  bool get isBlocking =>
      this == VerificationStatus.rejected ||
      this == VerificationStatus.needsFix;
  bool get isInProgress =>
      this == VerificationStatus.pending || this == VerificationStatus.inReview;

  static VerificationStatus fromCode(String? code) => VerificationStatus.values
      .firstWhere((e) => e.code == code, orElse: () => none);
}

/// Badges de confiance affiches sur le profil (§14).
enum TrustBadge {
  identity('IDENTITY', 'Identité vérifiée'),
  diploma('DIPLOMA', 'Diplôme vérifié'),
  competency('COMPETENCY', 'Compétence vérifiée'),
  experience('EXPERIENCE', 'Expérience vérifiée'),
  profile('PROFILE', 'Profil vérifié');

  const TrustBadge(this.code, this.label);
  final String code;
  final String label;
}

enum Availability {
  available('AVAILABLE', 'Disponible'),
  availableSoon('AVAILABLE_SOON', 'Bientôt disponible'),
  unavailable('UNAVAILABLE', 'Non disponible');

  const Availability(this.code, this.label);
  final String code;
  final String label;

  static Availability fromCode(String? code) => Availability.values.firstWhere(
    (e) => e.code == code,
    orElse: () => available,
  );
}

enum InstitutionType {
  school('SCHOOL', 'École'),
  highSchool('HIGH_SCHOOL', 'Lycée'),
  university('UNIVERSITY', 'Université'),
  institute('INSTITUTE', 'Institut'),
  trainingCenter('TRAINING_CENTER', 'Centre de formation'),
  other('OTHER', 'Autre établissement');

  const InstitutionType(this.code, this.label);
  final String code;
  final String label;

  static InstitutionType fromCode(String? code) => InstitutionType.values
      .firstWhere((e) => e.code == code, orElse: () => other);
}

enum ContractType {
  permanent('PERMANENT', 'Contrat permanent'),
  fixedTerm('FIXED_TERM', 'Contrat a durée determinee'),
  hourly('HOURLY', 'Vacation horaire'),
  internship('INTERNSHIP', 'Stage'),
  replacement('REPLACEMENT', 'Remplacement');

  const ContractType(this.code, this.label);
  final String code;
  final String label;

  /// Libelle court, pour les puces des cartes d'offre.
  String get shortLabel => switch (this) {
    permanent => 'Permanent',
    fixedTerm => 'CDD',
    hourly => 'Vacation',
    internship => 'Stage',
    replacement => 'Remplacement',
  };

  static ContractType fromCode(String? code) => ContractType.values.firstWhere(
    (e) => e.code == code,
    orElse: () => permanent,
  );
}

enum JobVisibility {
  public('PUBLIC', 'Offre publique'),
  private('PRIVATE', 'Offre privee');

  const JobVisibility(this.code, this.label);
  final String code;
  final String label;

  static JobVisibility fromCode(String? code) => JobVisibility.values
      .firstWhere((e) => e.code == code, orElse: () => public);
}

enum JobStatus {
  draft('DRAFT', 'Brouillon'),
  published('PUBLISHED', 'Publiée'),
  paused('PAUSED', 'Suspendue'),
  closed('CLOSED', 'Cloturee');

  const JobStatus(this.code, this.label);
  final String code;
  final String label;

  static JobStatus fromCode(String? code) =>
      JobStatus.values.firstWhere((e) => e.code == code, orElse: () => draft);
}

/// Statuts d'une candidature (§18).
enum ApplicationStatus {
  sent('SENT', 'Candidature envoyée', 0),
  viewed('VIEWED', 'Vue', 1),
  shortlisted('SHORTLISTED', 'Présélectionné', 2),
  interview('INTERVIEW', 'Entretien', 3),
  offerReceived('OFFER_RECEIVED', 'Offre reçue', 4),
  accepted('ACCEPTED', 'Acceptée', 5),
  rejected('REJECTED', 'Refusée', 6),
  hired('HIRED', 'Recruté', 7),
  withdrawn('WITHDRAWN', 'Retiree', 8);

  const ApplicationStatus(this.code, this.label, this.order);
  final String code;
  final String label;
  final int order;

  bool get isClosed =>
      this == ApplicationStatus.rejected || this == ApplicationStatus.withdrawn;

  static ApplicationStatus fromCode(String? code) => ApplicationStatus.values
      .firstWhere((e) => e.code == code, orElse: () => sent);
}

/// Workflow de recrutement (§28).
enum RecruitmentStage {
  application('APPLICATION', 'Candidature', 0),
  shortlisted('SHORTLISTED', 'Preselection', 1),
  interview('INTERVIEW', 'Entretien', 2),
  offerSent('OFFER_SENT', 'Offre envoyée', 3),
  offerAccepted('OFFER_ACCEPTED', 'Offre acceptée', 4),
  contractSigned('CONTRACT_SIGNED', 'Contrat signe', 5),
  startDate('START_DATE', 'Prise de poste', 6),
  hired('HIRED', 'Recruté', 7),
  followUp('FOLLOW_UP', 'Suivi', 8),
  completed('COMPLETED', 'Termine', 9);

  const RecruitmentStage(this.code, this.label, this.order);
  final String code;
  final String label;
  final int order;

  static RecruitmentStage fromCode(String? code) => RecruitmentStage.values
      .firstWhere((e) => e.code == code, orElse: () => application);

  RecruitmentStage? get next {
    final index = RecruitmentStage.values.indexOf(this);
    return index >= RecruitmentStage.values.length - 1
        ? null
        : RecruitmentStage.values[index + 1];
  }
}

enum InterviewMode {
  onSite('ON_SITE', 'Sur place'),
  video('VIDEO', 'Visioconference'),
  phone('PHONE', 'Appel telephonique');

  const InterviewMode(this.code, this.label);
  final String code;
  final String label;

  static InterviewMode fromCode(String? code) => InterviewMode.values
      .firstWhere((e) => e.code == code, orElse: () => onSite);
}

enum InterviewStatus {
  proposed('PROPOSED', 'Propose'),
  accepted('ACCEPTED', 'Accepte'),
  declined('DECLINED', 'Refuse'),
  completed('COMPLETED', 'Termine'),
  noShow('NO_SHOW', 'Absent');

  const InterviewStatus(this.code, this.label);
  final String code;
  final String label;

  static InterviewStatus fromCode(String? code) => InterviewStatus.values
      .firstWhere((e) => e.code == code, orElse: () => proposed);
}

/// Statuts d'une proposition de recrutement (§26).
enum OfferStatus {
  draft('DRAFT', 'Brouillon'),
  sent('SENT', 'Envoyée'),
  accepted('ACCEPTED', 'Acceptée'),
  changeRequested('CHANGE_REQUESTED', 'Modification demandee'),
  declined('DECLINED', 'Refusée'),
  withdrawn('WITHDRAWN', 'Retiree');

  const OfferStatus(this.code, this.label);
  final String code;
  final String label;

  static OfferStatus fromCode(String? code) =>
      OfferStatus.values.firstWhere((e) => e.code == code, orElse: () => draft);
}

enum ContractStatus {
  draft('DRAFT', 'Brouillon'),
  pendingSignature('PENDING_SIGNATURE', 'En attente de signature'),
  signed('SIGNED', 'Signe'),
  cancelled('CANCELLED', 'Annule');

  const ContractStatus(this.code, this.label);
  final String code;
  final String label;

  static ContractStatus fromCode(String? code) => ContractStatus.values
      .firstWhere((e) => e.code == code, orElse: () => draft);
}

/// Statuts d'une session de test (§10.3, §11).
enum TestSessionStatus {
  created('CREATED', 'Creee'),
  inProgress('IN_PROGRESS', 'En cours'),
  submitted('SUBMITTED', 'Soumise'),
  scored('SCORED', 'Corrigee'),
  expired('EXPIRED', 'Expiree'),
  abandoned('ABANDONED', 'Abandonnee');

  const TestSessionStatus(this.code, this.label);
  final String code;
  final String label;

  bool get isFinished =>
      this == TestSessionStatus.submitted ||
      this == TestSessionStatus.scored ||
      this == TestSessionStatus.expired;

  static TestSessionStatus fromCode(String? code) => TestSessionStatus.values
      .firstWhere((e) => e.code == code, orElse: () => created);
}

/// Types de documents televerses (§46).
enum DocumentType {
  selfie('SELFIE', 'Selfie'),
  idFront('ID_FRONT', 'Piece d’identité — recto'),
  idBack('ID_BACK', 'Piece d’identité — verso'),

  /// Le curriculum vitae, demande a l'inscription.
  cv('CV', 'CV'),
  diploma('DIPLOMA', 'Diplôme'),
  experienceProof('EXPERIENCE_PROOF', 'Justificatif d’experience'),
  institutionDoc('INSTITUTION_DOC', 'Document établissement'),
  contract('CONTRACT', 'Contrat'),
  other('OTHER', 'Autre document');

  const DocumentType(this.code, this.label);
  final String code;
  final String label;

  static DocumentType fromCode(String? code) => DocumentType.values.firstWhere(
    (e) => e.code == code,
    orElse: () => other,
  );
}

/// Cycle de vie d'un document (§46).
enum DocumentUploadStatus {
  pendingUpload('PENDING_UPLOAD', 'En attente d’envoi'),
  uploading('UPLOADING', 'Envoi en cours'),
  uploaded('UPLOADED', 'Envoyé'),
  serverProcessing('SERVER_PROCESSING', 'Traitement serveur'),
  verified('VERIFIED', 'Vérifié'),
  rejected('REJECTED', 'Rejete');

  const DocumentUploadStatus(this.code, this.label);
  final String code;
  final String label;

  static DocumentUploadStatus fromCode(String? code) => DocumentUploadStatus
      .values
      .firstWhere((e) => e.code == code, orElse: () => pendingUpload);
}

/// Operations de la file de synchronisation (§43).
enum SyncOperation {
  create('CREATE'),
  update('UPDATE'),
  delete('DELETE'),
  upload('UPLOAD');

  const SyncOperation(this.code);
  final String code;
}

enum SyncItemStatus {
  pending('PENDING'),
  inFlight('IN_FLIGHT'),
  done('DONE'),
  failed('FAILED'),
  conflict('CONFLICT');

  const SyncItemStatus(this.code);
  final String code;
}

/// Categories de notification (§53).
enum NotificationKind {
  profileIncomplete('PROFILE_INCOMPLETE', 'Profil incomplet'),
  documentVerified('DOCUMENT_VERIFIED', 'Document vérifié'),
  documentRejected('DOCUMENT_REJECTED', 'Document rejete'),
  testAvailable('TEST_AVAILABLE', 'Test disponible'),
  testPassed('TEST_PASSED', 'Test réussi'),
  newJob('NEW_JOB', 'Nouvelle offre'),
  applicationViewed('APPLICATION_VIEWED', 'Candidature consultée'),
  newApplication('NEW_APPLICATION', 'Nouvelle candidature'),
  interview('INTERVIEW', 'Entretien'),
  message('MESSAGE', 'Message'),
  offer('OFFER', 'Proposition'),
  contract('CONTRACT', 'Contrat'),
  recruitment('RECRUITMENT', 'Recrutement'),

  /// « Le cours commence, rejoignez la salle. » Écrite par le serveur quand
  /// le professeur appuie sur *Prévenir*.
  ///
  /// Déclarée ici parce que [fromCode] retombe sur [message] pour un code
  /// inconnu : sans cette ligne, l'appel du professeur arrivait sous le
  /// libellé « Message », à côté de la messagerie, au moment précis où il faut
  /// qu'il se distingue.
  liveStarting('LIVE_STARTING', 'Cours en direct');

  const NotificationKind(this.code, this.label);
  final String code;
  final String label;

  static NotificationKind fromCode(String? code) => NotificationKind.values
      .firstWhere((e) => e.code == code, orElse: () => message);
}
