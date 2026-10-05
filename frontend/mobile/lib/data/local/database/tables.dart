import 'package:drift/drift.dart';

// Tables de la base locale (§40, §48).
//
// Chaque entité synchronisable porte `updatedAt`, `version` et `deviceId`
// afin de permettre la detection de conflits (§45), ainsi qu'un drapeau
// `dirty` marquant une modification locale non encore poussee (§43).

/// Colonnes communes aux entités repliquees depuis le serveur.
mixin SyncableTable on Table {
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get deviceId => text().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
}

@DataClassName('UserRow')
class Users extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get role => text()();
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  TextColumn get firstName => text().nullable()();
  TextColumn get lastName => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get passwordHash => text().nullable()();
  BoolColumn get phoneVerified =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get suspended => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();

  /// Formule d'abonnement : `FREE`, `PRO` ou `MASTER` (24/09).
  ///
  /// Remplace le solde de credits : ce qui se paie est un mois, pas une
  /// action. Le code brut plutot qu'un entier — un jour ou l'on ajoute une
  /// formule, l'ordre des valeurs ne doit pas decider de ce qu'elle ouvre.
  TextColumn get plan => text().withDefault(const Constant('FREE'))();

  /// Fin du mois paye. Nul tant que rien n'a ete souscrit.
  DateTimeColumn get planRenewsAt => dateTime().nullable()();

  /// La formule choisie au dernier ecran de l'inscription, **pas encore
  /// payee** (04/10).
  ///
  /// Distincte de [plan] a dessein. Le parcours finit par un choix de
  /// formule dont la reponse n'etait lue par personne : on choisissait PRO et
  /// on obtenait un compte FREE, a rechoisir depuis la facturation.
  ///
  /// L'ecrire dans [plan] aurait offert la formule, puisque rien n'est
  /// encaisse a l'inscription. On garde donc l'intention : la page de
  /// facturation presente cette formule en premier et n'attend que le
  /// paiement, qui seul deplace la valeur vers [plan].
  TextColumn get pendingPlan => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TeacherRow')
class Teachers extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get headline => text().nullable()();
  TextColumn get bio => text().nullable()();

  /// Code de la region administrative (`CKY`, `LAB`…), tel que le donne
  /// `shared/geography/guinea.json`. Le code, pas le nom : les decoupages
  /// bougent, les codes non.
  TextColumn get region => text().nullable()();

  /// Prefecture, ou commune pour Conakry.
  TextColumn get city => text().nullable()();

  /// Quartier ou secteur — saisie libre, aucune liste fiable n'existe.
  TextColumn get district => text().nullable()();
  IntColumn get yearsExperience => integer().withDefault(const Constant(0))();
  TextColumn get availability =>
      text().withDefault(const Constant('AVAILABLE'))();
  DateTimeColumn get availableFrom => dateTime().nullable()();
  TextColumn get identityStatus => text().withDefault(const Constant('NONE'))();
  TextColumn get diplomaStatus => text().withDefault(const Constant('NONE'))();

  /// Types d'établissements souhaites, séparés par des virgules (§15).
  TextColumn get preferredInstitutionTypes =>
      text().withDefault(const Constant(''))();
  TextColumn get preferredContractTypes =>
      text().withDefault(const Constant(''))();

  /// Jours et moments où l'enseignant donne des cours à domicile, séparés
  /// par des virgules. Vides tant qu'il ne l'a pas configuré : une offre ne
  /// se publie pas sans, sinon une famille réserve à l'aveugle.
  ///
  /// Remplies depuis l'étape `home_availability` de l'inscription (04/10).
  /// Elles étaient mortes : créées en v6, écrites par rien et lues par rien,
  /// pendant que le parcours posait la question et jetait la réponse.
  TextColumn get tutoringDays => text().withDefault(const Constant(''))();
  TextColumn get tutoringSlots => text().withDefault(const Constant(''))();

  /// Les créneaux **par jour**, en JSON : `{"MON":["MORNING"],"SAT":[…]}`.
  ///
  /// --- Pourquoi du JSON et non deux listes de plus ------------------------
  ///
  /// [tutoringDays] et [tutoringSlots] sont deux ensembles à plat : « mardi,
  /// jeudi » d'un côté, « matin, soir » de l'autre. On ne peut pas en déduire
  /// si le professeur vient le mardi matin ou le mardi soir.
  ///
  /// C'est exactement le défaut que l'étape `day_hours` du parcours a été
  /// écrite pour corriger — elle remplace deux étapes qui « posaient la même
  /// question en deux fois, et rien ne reliait un jour à l'heure qui lui
  /// correspondait ». Ranger sa réponse dans les deux colonnes plates
  /// rejetterait la liaison qu'elle venait d'établir.
  ///
  /// Les deux colonnes plates restent remplies, dérivées de celle-ci :
  /// l'écran de disponibilité et les offres les lisent déjà.
  TextColumn get tutoringHours => text().withDefault(const Constant('{}'))();

  /// Les créneaux par jour pour un poste en établissement — l'étape
  /// `availability`. Même forme que [tutoringHours].
  ///
  /// Séparés des créneaux à domicile parce que le parcours pose bien deux
  /// questions : les disponibilités pour une classe et pour un élève seul ne
  /// sont pas les mêmes.
  TextColumn get workHours => text().withDefault(const Constant('{}'))();

  /// Ce qu'il cherche : `HOME`, `FULL_TIME`, ou les deux, séparés par une
  /// virgule — l'étape `service_types`.
  ///
  /// C'est la réponse qui oriente tout le reste de son expérience : une liste
  /// d'offres d'emploi n'intéresse pas qui ne veut que des cours à domicile.
  TextColumn get serviceTypes => text().withDefault(const Constant(''))();

  /// `STAY` (reste dans sa zone) ou `MOVE` (peut déménager) — l'étape
  /// `mobility`. Nul tant qu'il ne l'a pas dit.
  ///
  /// Le pendant exact de `institutions.teacherLocation` : un établissement
  /// qui accepte quelqu'un prêt à se rapprocher doit pouvoir le trouver.
  TextColumn get mobility => text().nullable()();

  /// Option Visibilité+ (§35) — date de fin de mise en avant.
  DateTimeColumn get boostedUntil => dateTime().nullable()();

  /// Combien de fois sa fiche a ete ouverte.
  ///
  /// C'est le seul chiffre qui dit a un professeur si son boost a servi.
  /// Sans lui, il l'achete a l'aveugle et ne le saura jamais.
  IntColumn get profileViews => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SubjectRow')
class Subjects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get code => text()();

  /// Cycles où la matière s'enseigne, séparés par des virgules :
  /// `PRIMAIRE`, `COLLEGE`, `LYCEE`, `SUPERIEUR`.
  ///
  /// Sert à ne proposer au professeur que les matières de son cycle — la
  /// liste complète mélange le droit et la lecture.
  TextColumn get cycles => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LevelRow')
class Levels extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get code => text()();

  /// PRIMARY, SECONDARY ou UNIVERSITY (§9).
  TextColumn get category => text()();

  /// Cycle scolaire : `PRIMAIRE`, `COLLEGE`, `LYCEE`, `SUPERIEUR`.
  /// Plus fin que [category], qui ne distingue pas collège et lycée.
  TextColumn get cycle => text().withDefault(const Constant(''))();

  /// En-tete de cycle (« Lycee »), pas une classe.
  ///
  /// Reste une cible valable pour une certification (« Mathematiques —
  /// Lycee ») ou une offre d'emploi, mais n'a rien a faire dans la liste des
  /// classes qu'on propose a un professeur : il choisit 11eme, 12eme ou
  /// Terminale, pas « Lycee ».
  BoolColumn get grouping => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Profil du second cycle : sciences mathematiques, sciences experimentales
/// ou sciences sociales.
///
/// La 11eme annee est commune ; le profil se choisit en 12eme et se garde en
/// Terminale. Il decide des matieres : l'economie ne se fait qu'en sciences
/// sociales, la geologie qu'en sciences experimentales.
@DataClassName('FiliereRow')
class Filieres extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get code => text()();

  /// Ce qui distingue le profil, en une phrase.
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get cycle => text().withDefault(const Constant('LYCEE'))();

  /// Classes concernees, separees par des virgules.
  TextColumn get levelIds => text().withDefault(const Constant(''))();

  /// Matieres majeures du profil, separees par des virgules.
  TextColumn get majorSubjectIds => text().withDefault(const Constant(''))();

  /// Toutes les matieres du profil, separees par des virgules.
  TextColumn get subjectIds => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TeacherSubjectRow')
class TeacherSubjects extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get subjectId => text().references(Subjects, #id)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {teacherId, subjectId},
  ];
}

/// Niveaux declares pour une matière donnée (§8 — une matière, plusieurs niveaux).
@DataClassName('TeacherLevelRow')
class TeacherLevels extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get subjectId => text().references(Subjects, #id)();
  TextColumn get levelId => text().references(Levels, #id)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {teacherId, subjectId, levelId},
  ];
}

@DataClassName('TeacherDocumentRow')
class TeacherDocuments extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get type => text()();
  TextColumn get localPath => text().nullable()();
  TextColumn get remoteUrl => text().nullable()();
  TextColumn get checksum => text().nullable()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get uploadStatus =>
      text().withDefault(const Constant('PENDING_UPLOAD'))();

  /// Octets déjà transmis — permet la reprise d'upload (§46).
  IntColumn get uploadedBytes => integer().withDefault(const Constant(0))();
  TextColumn get verificationStatus =>
      text().withDefault(const Constant('PENDING'))();
  TextColumn get rejectionReason => text().nullable()();

  /// Données extraites (OCR), chiffrees cote serveur — jamais journalisees (§51).
  TextColumn get extractedJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TeacherDiplomaRow')
class TeacherDiplomas extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get diplomaType => text()();
  TextColumn get institutionName => text()();
  TextColumn get field => text().nullable()();
  TextColumn get speciality => text().nullable()();
  IntColumn get graduationYear => integer()();
  TextColumn get academicLevelId => text().nullable()();
  TextColumn get documentId => text().nullable()();
  TextColumn get verificationStatus =>
      text().withDefault(const Constant('PENDING'))();
  TextColumn get rejectionReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TeacherExperienceRow')
class TeacherExperiences extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get institutionName => text()();
  TextColumn get position => text()();
  TextColumn get city => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get current => boolean().withDefault(const Constant(false))();
  TextColumn get description => text().nullable()();
  TextColumn get documentId => text().nullable()();

  /// De qui joindre pour verifier cette experience (02/10).
  ///
  /// Un justificatif se falsifie ; un appel a l'etablissement, non. C'est
  /// ce contact qui permet de passer une experience de « declaree » a
  /// « verifiee », et c'est la verification qui porte le badge que les
  /// ecoles regardent en premier.
  ///
  /// Facultatifs tous les deux, et c'est voulu : un professeur qui ne les a
  /// pas sous la main doit pouvoir enregistrer son experience quand meme,
  /// puis la completer. Exiger un contact ici ferait abandonner la fiche.
  TextColumn get contactPhone => text().nullable()();
  TextColumn get contactEmail => text().nullable()();

  TextColumn get verificationStatus =>
      text().withDefault(const Constant('PENDING'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Certification par matière et niveau (§13).
@DataClassName('TeacherCertificationRow')
class TeacherCertifications extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get subjectId => text().references(Subjects, #id)();
  TextColumn get levelId => text().references(Levels, #id)();
  IntColumn get score => integer()();
  TextColumn get sessionId => text().nullable()();
  TextColumn get domainScoresJson => text().nullable()();
  DateTimeColumn get issuedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expiresAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {teacherId, subjectId, levelId},
  ];
}

@DataClassName('InstitutionRow')
class Institutions extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get type => text()();

  /// Code de la region administrative (voir `Teachers.region`).
  TextColumn get region => text().nullable()();
  TextColumn get city => text()();
  TextColumn get district => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get managerName => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get logoPath => text().nullable()();
  TextColumn get verificationStatus =>
      text().withDefault(const Constant('PENDING'))();

  // --- Fiche detaillee (§19) ---------------------------------------------
  // Ce qu'un candidat ou un parent regarde avant de s'engager : depuis quand
  // l'etablissement existe, qui le tient, ce qu'on y etudie et ce qu'on y
  // trouve.

  /// Second numero : les etablissements en publient souvent deux.
  TextColumn get phoneAlt => text().nullable()();
  TextColumn get website => text().nullable()();
  IntColumn get foundedYear => integer().nullable()();

  /// PUBLIC ou PRIVATE.
  TextColumn get ownership => text().nullable()();

  /// Systeme d'etudes : « LMD » pour le superieur.
  TextColumn get academicSystem => text().nullable()();

  /// Diplomes delivres, separes par des virgules : BTS, LICENCE, MASTER,
  /// DOCTORAT. Une chaine plutot qu'une table : la liste est courte, figee,
  /// et n'est jamais interrogee autrement que pour l'affichage.
  TextColumn get degrees => text().withDefault(const Constant(''))();

  /// Filieres, separees par des virgules.
  TextColumn get specialties => text().withDefault(const Constant(''))();

  /// Equipements, separes par des virgules (« 40 salles de classe »).
  TextColumn get facilities => text().withDefault(const Constant(''))();

  // --- Ce que l'etablissement cherche (04/10) -----------------------------
  //
  // Le parcours d'inscription posait ces six questions et n'avait nulle part
  // pour ranger les reponses : neuf sur dix-sept etaient jetees. Resultat, a
  // chaque offre publiee le formulaire redemandait la matiere, les niveaux et
  // jusqu'a la ville — pourtant obligatoire et deja connue.
  //
  // Elles decrivent un besoin permanent, pas une offre : c'est ce qui prefixe
  // la prochaine offre, et ce qui permet de classer les professeurs par
  // pertinence des l'accueil.

  /// Fonction du responsable (`DIRECTOR`, `DEPUTY`…) — l'etape
  /// `manager_identity`. Le nom etait garde, la fonction perdue.
  TextColumn get managerRole => text().nullable()();

  /// Matieres cherchees, separees par des virgules.
  TextColumn get neededSubjectIds => text().withDefault(const Constant(''))();

  /// Ce qui compte pour lui — `FAST`, `CHOICE`, `CONTRACT`, `VERIFIED` —
  /// separes par des virgules.
  TextColumn get priorities => text().withDefault(const Constant(''))();

  /// `IN_TOWN` ou `CAN_MOVE` : accepte-t-il quelqu'un pret a se rapprocher.
  TextColumn get teacherLocation => text().nullable()();

  /// Jours travailles, separes par des virgules, et les heures de la journee.
  TextColumn get workDays => text().withDefault(const Constant(''))();
  TextColumn get workStart => text().nullable()();
  TextColumn get workEnd => text().nullable()();

  /// Distance acceptee : `1_5`, `5_10` ou `10_PLUS`.
  TextColumn get maxDistance => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TestRow')
class Tests extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text().references(Subjects, #id)();
  TextColumn get levelId => text().references(Levels, #id)();
  TextColumn get title => text()();
  IntColumn get questionCount => integer()();
  IntColumn get durationMinutes => integer()();
  IntColumn get passingScore => integer()();
  TextColumn get rules => text().nullable()();
  IntColumn get testVersion => integer().withDefault(const Constant(1))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TestQuestionRow')
class TestQuestions extends Table {
  TextColumn get id => text()();
  TextColumn get testId => text().references(Tests, #id)();
  TextColumn get statement => text()();

  /// Options serialisees : `[{"key":"A","text":"..."}]`.
  TextColumn get optionsJson => text()();
  TextColumn get correctKey => text()();
  TextColumn get domain => text()();
  IntColumn get position => integer()();
  IntColumn get difficulty => integer().withDefault(const Constant(2))();
  TextColumn get explanation => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Session de test — support du mode hors ligne (§11).
@DataClassName('TestSessionRow')
class TestSessions extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get testId => text().references(Tests, #id)();
  TextColumn get status => text().withDefault(const Constant('CREATED'))();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get submittedAt => dateTime().nullable()();

  /// Temps restant, sauvegarde regulierement pour survivre a une coupure.
  IntColumn get remainingSeconds => integer().withDefault(const Constant(0))();
  IntColumn get currentIndex => integer().withDefault(const Constant(0))();
  IntColumn get score => integer().nullable()();
  BoolColumn get passed => boolean().nullable()();
  TextColumn get domainScoresJson => text().nullable()();

  /// Ordre des questions propre a la session, fige au demarrage.
  TextColumn get questionOrder => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TestAnswerRow')
class TestAnswers extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(TestSessions, #id)();
  TextColumn get questionId => text().references(TestQuestions, #id)();
  TextColumn get answerKey => text().nullable()();
  IntColumn get elapsedSeconds => integer().withDefault(const Constant(0))();
  DateTimeColumn get answeredAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionId, questionId},
  ];
}

@DataClassName('JobRow')
class Jobs extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get institutionId => text().references(Institutions, #id)();
  TextColumn get title => text()();
  TextColumn get subjectId => text().references(Subjects, #id)();

  /// Identifiants de niveaux séparés par des virgules.
  TextColumn get levelIds => text().withDefault(const Constant(''))();
  TextColumn get city => text()();
  TextColumn get contractType => text()();
  TextColumn get description => text().nullable()();
  IntColumn get salaryMin => integer().nullable()();
  IntColumn get salaryMax => integer().nullable()();
  BoolColumn get salaryPublished =>
      boolean().withDefault(const Constant(false))();
  IntColumn get minExperience => integer().withDefault(const Constant(0))();
  BoolColumn get requiresCertification =>
      boolean().withDefault(const Constant(false))();
  TextColumn get visibility => text().withDefault(const Constant('PUBLIC'))();
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get closesAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Enseignants invites sur une offre privee (§29).
@DataClassName('JobInvitationRow')
class JobInvitations extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get jobId => text().references(Jobs, #id)();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get status => text().withDefault(const Constant('SENT'))();
  TextColumn get message => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {jobId, teacherId},
  ];
}

@DataClassName('ApplicationRow')
class Applications extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get jobId => text().references(Jobs, #id)();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get status => text().withDefault(const Constant('SENT'))();
  TextColumn get coverNote => text().nullable()();

  /// Score de compatibilite fige au moment de la candidature (§22).
  IntColumn get matchScore => integer().nullable()();
  TextColumn get matchFactorsJson => text().nullable()();
  DateTimeColumn get appliedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get statusChangedAt =>
      dateTime().withDefault(currentDateAndTime)();
  BoolColumn get shortlisted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {jobId, teacherId},
  ];
}

/// Espace de recrutement (§24).
@DataClassName('RecruitmentRoomRow')
class RecruitmentRooms extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get applicationId => text().references(Applications, #id)();
  TextColumn get jobId => text().references(Jobs, #id)();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get institutionId => text().references(Institutions, #id)();
  TextColumn get stage => text().withDefault(const Constant('APPLICATION'))();
  TextColumn get internalNotes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Une conversation entre une famille et un professeur (24/09).
///
/// Distincte d'un [RecruitmentRooms] : celui-la porte une candidature, une
/// offre, un contrat et des etapes de recrutement, qui n'existent pas entre
/// un parent et un repetiteur. Les deux partagent en revanche la table des
/// messages — deux tables de messages auraient diverge sur le masquage des
/// coordonnees, qui est la seule chose qu'on ne peut pas se permettre de
/// faire a moitie.
@DataClassName('ConversationRow')
class Conversations extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get teacherId => text().references(Teachers, #id)();

  /// La famille, quand c'est elle qui parle au professeur.
  ///
  /// Devenue facultative le 02/10 : un etablissement aussi ecrit a un
  /// professeur, et la table ne savait porter qu'une famille. « Contacter »
  /// depuis une fiche affichait donc un message d'attente, faute de pouvoir
  /// ranger la conversation quelque part.
  TextColumn get parentId => text().nullable().references(Parents, #id)();

  /// L'etablissement, quand c'est lui qui ecrit.
  ///
  /// Exactement l'un des deux est renseigne. La contrainte vit dans
  /// `ConversationsRepository`, pas en base : SQLite sait exprimer un
  /// `CHECK`, mais drift le reecrirait a chaque migration de la table, et un
  /// `CHECK` qu'on reecrit finit par ne plus verifier la meme chose.
  TextColumn get institutionId =>
      text().nullable().references(Institutions, #id)();

  /// La demande de cours qui l'a ouverte. Nulle si la conversation a ete
  /// ouverte autrement — par une fiche publique, par exemple.
  TextColumn get requestId =>
      text().nullable().references(TutoringRequests, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MessageRow')
class Messages extends Table with SyncableTable {
  TextColumn get id => text()();

  /// L'un des deux porte la conversation, jamais les deux.
  ///
  /// Un message appartient soit a un espace de recrutement, soit a une
  /// conversation avec une famille.
  TextColumn get roomId =>
      text().nullable().references(RecruitmentRooms, #id)();
  TextColumn get conversationId =>
      text().nullable().references(Conversations, #id)();
  TextColumn get senderId => text()();
  TextColumn get senderRole => text()();
  TextColumn get body => text()();
  TextColumn get attachmentPath => text().nullable()();
  TextColumn get attachmentName => text().nullable()();

  /// Le message a ete filtre par la protection anti-contournement (§30).
  BoolColumn get masked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get sentAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get readAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('InterviewRow')
class Interviews extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(RecruitmentRooms, #id)();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get mode => text().withDefault(const Constant('ON_SITE'))();
  TextColumn get status => text().withDefault(const Constant('PROPOSED'))();
  TextColumn get location => text().nullable()();
  TextColumn get meetingLink => text().nullable()();
  TextColumn get comment => text().nullable()();
  TextColumn get feedback => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Proposition officielle de recrutement (§26).
@DataClassName('RecruitmentOfferRow')
class RecruitmentOffers extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(RecruitmentRooms, #id)();
  TextColumn get position => text()();
  TextColumn get subjectId => text().nullable()();
  TextColumn get levelIds => text().withDefault(const Constant(''))();
  TextColumn get contractType => text()();
  IntColumn get monthlySalary => integer()();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get durationMonths => integer().nullable()();
  IntColumn get trialPeriodDays => integer().nullable()();
  TextColumn get schedule => text().nullable()();
  TextColumn get extraConditions => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();
  TextColumn get changeRequest => text().nullable()();
  DateTimeColumn get sentAt => dateTime().nullable()();
  DateTimeColumn get respondedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ContractRow')
class Contracts extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(RecruitmentRooms, #id)();
  TextColumn get offerId => text().references(RecruitmentOffers, #id)();
  TextColumn get reference => text()();
  TextColumn get bodyText => text()();
  TextColumn get pdfPath => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();
  TextColumn get teacherSignaturePath => text().nullable()();
  DateTimeColumn get teacherSignedAt => dateTime().nullable()();
  TextColumn get institutionSignaturePath => text().nullable()();
  DateTimeColumn get institutionSignedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Recrutement effectif et suivi (§32).
@DataClassName('RecruitmentRow')
class Recruitments extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(RecruitmentRooms, #id)();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get institutionId => text().references(Institutions, #id)();
  TextColumn get contractId => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get monthlySalary => integer()();
  IntColumn get trialPeriodDays => integer().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// Jalons de suivi realises : « 30,60,90 » (§32).
  TextColumn get completedMilestones =>
      text().withDefault(const Constant(''))();

  /// Frais de recrutement dus a la plateforme (§36).
  IntColumn get successFeeAmount => integer().withDefault(const Constant(0))();
  BoolColumn get feePaid => boolean().withDefault(const Constant(false))();
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TeacherReviewRow')
class TeacherReviews extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get recruitmentId => text().references(Recruitments, #id)();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get institutionId => text().references(Institutions, #id)();
  IntColumn get milestoneDays => integer()();
  IntColumn get punctuality => integer()();
  IntColumn get pedagogy => integer()();
  IntColumn get subjectMastery => integer()();
  IntColumn get professionalism => integer()();
  IntColumn get attendance => integer()();

  /// Satisfaction globale, exprimee sur 100.
  IntColumn get overall => integer()();
  TextColumn get comment => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Journal du workflow de recrutement (§28).
@DataClassName('RecruitmentEventRow')
class RecruitmentEvents extends Table {
  TextColumn get id => text()();
  TextColumn get roomId => text()();
  TextColumn get fromStage => text().nullable()();
  TextColumn get toStage => text()();
  TextColumn get note => text().nullable()();
  TextColumn get actorId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('NotificationRow')
class Notifications extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get route => text().nullable()();
  TextColumn get payload => text().nullable()();
  BoolColumn get read => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// File de synchronisation (§43).
@DataClassName('SyncQueueRow')
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Journal d'audit local (§51).
@DataClassName('AuditLogRow')
class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get actorId => text().nullable()();
  TextColumn get action => text()();
  TextColumn get entity => text().nullable()();
  TextColumn get entityId => text().nullable()();

  /// Metadonnees non sensibles uniquement — aucune donnée de piece
  /// d'identité ne doit y figurer (§51).
  TextColumn get metadata => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Cles/valeurs internes : curseur de synchronisation, version du seed, etc.
@DataClassName('AppMetaRow')
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// --- Module parent / élève et cours a domicile ---------------------------

/// Profil parent : coordonnées et adresse du domicile.
///
/// L'adresse sert a rapprocher le parent des enseignants intervenant dans son
/// secteur ; elle n'est jamais exposee publiquement, seul le quartier l'est.
@DataClassName('ParentRow')
class Parents extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();

  /// Code de la region administrative (voir `Teachers.region`).
  TextColumn get region => text().nullable()();
  TextColumn get city => text().nullable()();

  /// Quartier ou secteur — granularite affichee aux enseignants.
  TextColumn get district => text().nullable()();
  TextColumn get addressLine => text().nullable()();

  /// Repères d'acces, utiles en l'absence d'adressage normalise.
  TextColumn get landmark => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Enfant rattache a un parent, pour cibler le niveau demande.
@DataClassName('ChildRow')
class Children extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get parentId => text().references(Parents, #id)();
  TextColumn get firstName => text()();
  TextColumn get lastName => text().nullable()();
  TextColumn get levelId => text().nullable().references(Levels, #id)();

  /// Profil de lycee, a partir de la 12eme annee. Nul avant : la 11eme est
  /// commune aux trois profils.
  TextColumn get filiereId => text().nullable().references(Filieres, #id)();
  TextColumn get schoolName => text().nullable()();

  /// Matières où l'enfant a besoin d'aide, séparées par des virgules.
  /// Sert à proposer les bons professeurs, pas à remplir une fiche.
  TextColumn get subjectIds => text().withDefault(const Constant(''))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Offre de cours a domicile publiée par un enseignant.
///
/// Distincte des offres d'emploi (§17) : la relation est directe entre un
/// enseignant et une famille, sans établissement intermediaire.
@DataClassName('TutoringServiceRow')
class TutoringServices extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get subjectId => text().references(Subjects, #id)();

  /// Niveaux couverts, séparés par des virgules.
  TextColumn get levelIds => text().withDefault(const Constant(''))();

  /// Lieu du cours : domicile de l'élève, chez l'enseignant, ou en ligne.
  TextColumn get mode => text().withDefault(const Constant('AT_STUDENT'))();
  IntColumn get hourlyRate => integer().nullable()();
  TextColumn get city => text().nullable()();

  /// Quartiers desservis, séparés par des virgules.
  TextColumn get districts => text().withDefault(const Constant(''))();

  /// Creneaux indicatifs (« samedi matin, mercredi après-midi »).
  TextColumn get availabilityNote => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Un professeur mis de cote par une famille ou un etablissement (24/09).
///
/// Une table et non une liste dans les preferences : un favori se retrouve
/// sur un autre telephone, et se compte — savoir combien de fois une fiche
/// a ete mise en favori dit au professeur si son profil interesse.
@DataClassName('FavouriteRow')
class Favourites extends Table with SyncableTable {
  TextColumn get id => text()();

  /// Qui met en favori : le compte, quel que soit son role.
  TextColumn get ownerId => text().references(Users, #id)();
  TextColumn get teacherId => text().references(Teachers, #id)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    // On ne met pas deux fois le meme professeur en favori.
    {ownerId, teacherId},
  ];
}

/// Cours construit par l'assistant.
///
/// Le JSON du cours est la source ; le fichier Excel est refabriqué à chaque
/// version à partir de lui. Améliorer un cours crée une nouvelle ligne de
/// version, les précédentes restent téléchargeables.
@DataClassName('AiCourseRow')
class AiCourses extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text().references(Users, #id)();

  /// Même identifiant pour toutes les versions d'un cours.
  TextColumn get courseId => text()();
  IntColumn get version => integer()();
  TextColumn get title => text()();
  TextColumn get courseJson => text()();

  /// Word d'abord : c'est le fichier que le professeur rouvre et modifie.
  TextColumn get docxPath => text().nullable()();

  /// Excel en second, pour les tableaux d'exercices et le calendrier.
  TextColumn get xlsxPath => text().nullable()();

  /// Généré sans IA, en mode démonstration.
  BoolColumn get demo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Demande d'un parent auprès d'un enseignant pour des cours a domicile.
@DataClassName('TutoringRequestRow')
class TutoringRequests extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get parentId => text().references(Parents, #id)();
  TextColumn get serviceId => text().references(TutoringServices, #id)();
  TextColumn get childId => text().nullable().references(Children, #id)();
  TextColumn get status => text().withDefault(const Constant('SENT'))();
  TextColumn get message => text().nullable()();
  DateTimeColumn get preferredStart => dateTime().nullable()();
  DateTimeColumn get respondedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Une seance de cours a domicile, passee ou a venir.
///
/// La demande dit « ce parent veut ce professeur » ; la seance dit « mardi a
/// 16 h ». Sans cette distinction, l'accueil du parent ne peut montrer ni ce
/// qui vient de se passer, ni ce qui arrive — c'est pourtant la premiere
/// chose qu'il regarde en ouvrant l'application.
/// Un moyen de paiement enregistre par un compte.
///
/// En Guinee, c'est l'argent mobile qui circule : Orange Money et MTN MoMo
/// avant la carte bancaire. Les proposer dans cet ordre, c'est proposer ce
/// que les gens ont vraiment.
///
/// **Aucun secret n'est stocke ici** : ni code, ni numero complet de carte.
/// Seulement de quoi reconnaitre le moyen — l'operateur et les derniers
/// chiffres. L'encaissement reel passera par le serveur, qui parle au
/// fournisseur.
/// Un groupe de discussion : un cours en direct, ou un contrat.
///
/// --- L'appartenance ne se stocke pas -------------------------------------
///
/// Il n'y a pas de table de membres, ici ni sur le serveur. Un groupe existe
/// autour d'une relation — un cours en direct, un contrat — et ses membres
/// sont ceux que cette relation lie, recalculés à chaque fois. C'est la même
/// règle que pour le répertoire du professeur : **l'accès suit la relation**,
/// donc il expire avec elle sans que personne ait à retirer une ligne.
///
/// Pour un produit qui traite des mineurs, c'est la propriété qui décide.
@DataClassName('ChatGroupRow')
class ChatGroups extends Table with SyncableTable {
  TextColumn get id => text()();

  /// `COURSE` ou `CONTRACT`.
  TextColumn get kind => text()();

  /// Le cours ou le contrat dont ce groupe est la discussion.
  TextColumn get sourceId => text()();

  /// Recopié pour que la liste s'affiche sans joindre quatre tables.
  TextColumn get name => text()();

  /// Le dernier message, pour la liste — comme toute messagerie.
  TextColumn get lastBody => text().nullable()();
  DateTimeColumn get lastAt => dateTime().nullable()();

  /// Combien n'ont pas été lus par ce téléphone.
  IntColumn get unread => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Un message dans un groupe.
///
/// Conservé, contrairement au fil d'une séance en direct
/// (`live_chat_overlay.dart`) qui est éphémère à dessein. Les deux ne font pas
/// le même travail : l'un commente une vidéo pendant qu'elle passe, l'autre
/// porte la question posée le soir sur l'exercice 3 — et une question dont la
/// réponse a disparu le lendemain ne sert à personne.
@DataClassName('ChatMessageRow')
class ChatMessages extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(ChatGroups, #id)();

  /// Le compte, et non la fiche : un professeur et un parent écrivent dans le
  /// même groupe, et l'identifiant de compte est ce qu'ils ont en commun.
  TextColumn get authorId => text()();

  /// Recopiés pour afficher sans joindre : une liste de messages se dessine
  /// ligne par ligne, et une jointure par ligne sur un téléphone lent se voit.
  TextColumn get authorName => text().nullable()();

  /// Pour distinguer le professeur d'un coup d'œil, comme dans le fil du
  /// direct où son nom est en ambre : dans un groupe de quinze, sa consigne ne
  /// doit pas se perdre entre deux « bonjour ».
  TextColumn get authorRole => text().nullable()();

  TextColumn get body => text()();
  DateTimeColumn get sentAt => dateTime()();

  /// Faux tant que le serveur ne l'a pas confirmé : le message s'affiche
  /// quand même, en attente. Sans cela, écrire hors réseau ne montre rien et
  /// l'on réécrit le même message trois fois.
  BoolColumn get delivered => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PaymentMethodRow')
class PaymentMethods extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();

  /// ORANGE_MONEY, MTN_MOMO, CARD ou CASH.
  TextColumn get kind => text()();

  /// Nom du titulaire, tel qu'il figure chez l'operateur.
  TextColumn get holder => text().nullable()();

  /// Les quatre derniers chiffres, et rien de plus.
  TextColumn get last4 => text().withDefault(const Constant(''))();

  /// Le moyen propose par defaut au moment de payer.
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Une campagne de promotion achetee par un etablissement.
///
/// L'etablissement paie pour etre montre aux familles qui cherchent une
/// ecole. Le cout est fige a l'achat : changer le tarif plus tard ne doit
/// pas reecrire ce qu'un directeur a deja regle.
@DataClassName('PromotionRow')
class Promotions extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get institutionId => text().references(Institutions, #id)();
  TextColumn get title => text()();
  TextColumn get message => text().nullable()();

  /// Videos et images deposees, separees par des virgules.
  TextColumn get mediaPaths => text().withDefault(const Constant(''))();

  /// DRAFT, ACTIVE ou ENDED.
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();
  DateTimeColumn get startsAt => dateTime().nullable()();
  DateTimeColumn get endsAt => dateTime().nullable()();

  /// Nombre d'affichages. C'est ce que l'etablissement a achete.
  IntColumn get views => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Un cours video mis en vente par un professeur.
///
/// Distinct des cours a domicile : celui-ci se vend une fois et se regarde
/// autant de fois qu'on veut, sans que le professeur se deplace. C'est ce
/// qui permet a un professeur de Conakry d'atteindre un eleve de Nzerekore.
@DataClassName('VideoCourseRow')
class VideoCourses extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get subjectId => text().nullable().references(Subjects, #id)();

  /// Classes visees, separees par des virgules.
  TextColumn get levelIds => text().withDefault(const Constant(''))();

  /// Prix demande par le professeur, en francs guineens. C'est ce que paie
  /// l'eleve ; la commission se retient dessus.
  IntColumn get price => integer().withDefault(const Constant(0))();

  /// Chemins des videos deposees, separes par des virgules.
  TextColumn get videoPaths => text().withDefault(const Constant(''))();
  TextColumn get coverPath => text().nullable()();

  /// DRAFT (brouillon), PUBLISHED (en vente), HIDDEN (retire).
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();
  IntColumn get purchaseCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Un chapitre d'un cours video (02/10).
///
/// Un cours etait une liste plate de chemins de videos : six fichiers les uns
/// sous les autres, sans titre ni ordre explicite, et rien pour dire ce que
/// chacun traite. Un eleve qui reprend un cours la semaine suivante ne
/// retrouvait pas ou il s'etait arrete.
///
/// Le chapitre porte le decoupage : un titre, une description, un rang. Ce
/// qu'il contient — videos et documents — vit dans [CourseItems].
@DataClassName('CourseChapterRow')
class CourseChapters extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get courseId => text().references(VideoCourses, #id)();
  TextColumn get title => text()();

  /// Ce que le chapitre traite, affiche sous la video.
  TextColumn get description => text().nullable()();

  /// Rang d'affichage. Explicite, et non deduit de la date de creation : un
  /// professeur reordonne ses chapitres, et l'ordre de saisie n'est pas
  /// l'ordre d'apprentissage.
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Une video ou un document dans un chapitre.
///
/// Une seule table pour les deux : ils partagent le rang, le titre et le
/// chemin, et deux tables jumelles finiraient par ne plus se ressembler. Le
/// genre est porte par [kind].
@DataClassName('CourseItemRow')
class CourseItems extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get chapterId => text().references(CourseChapters, #id)();

  /// VIDEO, DOCUMENT ou LINK.
  TextColumn get kind => text().withDefault(const Constant('VIDEO'))();

  TextColumn get title => text()();

  /// Le fichier sur l'appareil, pour une video ou un document depose.
  TextColumn get localPath => text().nullable()();

  /// L'adresse distante, quand le fichier est parti au serveur — ou l'URL
  /// elle-meme pour un lien.
  TextColumn get remoteUrl => text().nullable()();

  /// Duree en secondes, pour une video. Nulle quand on ne la connait pas :
  /// afficher « 0 min » serait une information fausse.
  IntColumn get durationSeconds => integer().nullable()();

  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Un commentaire sous une video (02/10).
///
/// Rattache a l'element, pas au cours : une question porte sur la video qu'on
/// vient de regarder, et la rattacher au cours entier la rendrait
/// introuvable des que le cours compte dix videos.
@DataClassName('CourseCommentRow')
class CourseComments extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(CourseItems, #id)();

  /// Le compte qui ecrit — eleve, parent ou le professeur lui-meme.
  TextColumn get authorId => text().references(Users, #id)();

  TextColumn get body => text()();

  /// Le commentaire auquel celui-ci repond. Nul pour un commentaire de
  /// premier niveau.
  TextColumn get parentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// L'achat d'un cours video par une famille ou un etudiant.
@DataClassName('CoursePurchaseRow')
class CoursePurchases extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get courseId => text().references(VideoCourses, #id)();

  /// L'acheteur : un parent ou un etudiant majeur, qui partagent le meme
  /// espace.
  TextColumn get parentId => text().references(Parents, #id)();

  /// Montant paye, fige a l'achat : changer le prix du cours plus tard ne
  /// doit pas reecrire ce qu'un eleve a deja regle.
  IntColumn get amount => integer()();

  /// Part retenue par la plateforme, figee elle aussi.
  IntColumn get commission => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Un engagement entre un professeur et celui qui le paie.
///
/// A ne pas confondre avec `Contracts`, qui est le **document signe** d'un
/// recrutement — un PDF et deux signatures. Celui-ci est la **relation de
/// travail** elle-meme : qui travaille pour qui, combien, jusqu'a quand.
///
/// Deux formes, un seul objet : un etablissement qui embauche, ou une famille
/// qui prend un repetiteur. Les distinguer en deux tables obligerait chaque
/// ecran a poser deux fois la meme question — « qui me paie, et combien ».
///
/// [institutionId] et [parentId] s'excluent : l'un des deux porte le contrat.
@DataClassName('WorkContractRow')
class WorkContracts extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get teacherId => text().references(Teachers, #id)();

  /// Cote etablissement.
  TextColumn get institutionId =>
      text().nullable().references(Institutions, #id)();

  /// Cote famille. L'enfant precise pour qui, quand le parent en a plusieurs.
  TextColumn get parentId => text().nullable().references(Parents, #id)();
  TextColumn get childId => text().nullable().references(Children, #id)();

  TextColumn get subjectId => text().nullable().references(Subjects, #id)();

  /// Ce qui s'affiche dans la liste : « Lycee Excellence » ou « Aicha ».
  TextColumn get label => text()();

  /// PENDING (en attente), ACTIVE (commence), ENDED (resilie).
  TextColumn get status => text().withDefault(const Constant('PENDING'))();

  /// Montant mensuel en francs guineens.
  IntColumn get monthlyAmount => integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// Pourquoi le contrat s'est arrete. Une resiliation sans motif laisse les
  /// deux parties sans rien a se dire.
  TextColumn get endReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Une echeance de paiement rattachee a un contrat.
///
/// Le professeur veut savoir ce qui arrive ; le parent, ce qu'il doit. La
/// meme ligne repond aux deux, vue de chaque cote.
@DataClassName('ContractPaymentRow')
class ContractPayments extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get contractId => text().references(WorkContracts, #id)();
  DateTimeColumn get dueOn => dateTime()();
  IntColumn get amount => integer()();

  /// DUE (a venir), PAID (regle), LATE (en retard).
  TextColumn get status => text().withDefault(const Constant('DUE'))();
  DateTimeColumn get paidAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TutoringSessionRow')
class TutoringSessions extends Table with SyncableTable {
  TextColumn get id => text()();
  TextColumn get requestId => text().references(TutoringRequests, #id)();
  DateTimeColumn get startsAt => dateTime()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(90))();

  /// PLANNED, DONE ou CANCELLED.
  TextColumn get status => text().withDefault(const Constant('PLANNED'))();

  /// Ce qui a ete travaille. Rempli apres la seance.
  TextColumn get topic => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
