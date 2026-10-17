/// Les cours en direct, vus du téléphone (02/10).
///
/// --- Pourquoi ces objets ne vivent pas dans Drift -------------------------
///
/// Tout le reste de l'application tient en base locale et se synchronise : un
/// parent consulte les offres, ses enfants et ses contrats dans l'avion. Les
/// cours en direct, non, et ce n'est pas une paresse :
///
///   * une **place** est prise par une mise à jour conditionnelle côté serveur
///     (`claim_session_seat`). La prendre hors ligne reviendrait à promettre un
///     siège que quinze autres téléphones réclament au même instant ;
///   * un **jeton d'entrée** est signé par le serveur et expire ; en cache, il
///     ne vaut rien ;
///   * une **rediffusion** est une adresse signée valable quelques heures.
///
/// Les trois perdent leur sens en différé. Les écrans disent donc franchement
/// qu'ils ont besoin du réseau au lieu de montrer une grille périmée — ce qui
/// serait pire, parce qu'on s'y fierait.
library;

/// Une matière ou une classe, telle que le serveur la nomme.
class LiveRef {
  const LiveRef({required this.id, required this.name});

  final String id;
  final String name;

  factory LiveRef.fromJson(Map<String, dynamic> json) => LiveRef(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
  );
}

/// Une séance de la grille publique.
class LiveSessionSummary {
  const LiveSessionSummary({
    required this.id,
    required this.courseId,
    required this.slotId,
    required this.startsAt,
    required this.durationMinutes,
    required this.status,
    required this.seatsLeft,
    required this.seats,
    required this.price,
    required this.subject,
    required this.level,
    required this.teacherId,
    required this.teacherName,
    this.title,
  });

  final String id;
  final String courseId;
  final String slotId;
  final DateTime startsAt;
  final int durationMinutes;

  /// `PLANNED` | `LIVE` | `DONE` | `CANCELLED`.
  final String status;

  /// Ce qu'il reste de places. Zéro = complet.
  final int seatsLeft;
  final int seats;

  /// Prix payé par **chaque** élève pour **cette** séance.
  final int price;

  final LiveRef? subject;
  final LiveRef? level;
  final String teacherId;
  final String teacherName;
  final String? title;

  bool get isFull => seatsLeft <= 0;

  factory LiveSessionSummary.fromJson(Map<String, dynamic> json) =>
      LiveSessionSummary(
        id: (json['id'] ?? '').toString(),
        courseId: (json['courseId'] ?? '').toString(),
        slotId: (json['slotId'] ?? '').toString(),
        startsAt:
            DateTime.tryParse((json['startsAt'] ?? '').toString())?.toLocal() ??
            DateTime.now(),
        durationMinutes: _entier(json['durationMinutes'], 90),
        status: (json['status'] ?? 'PLANNED').toString(),
        seatsLeft: _entier(json['seatsLeft'], 0),
        seats: _entier(json['seats'], 0),
        price: _entier(json['price'], 0),
        subject: _ref(json['subject']),
        level: _ref(json['level']),
        teacherId: (json['teacherId'] ?? '').toString(),
        teacherName: (json['teacherName'] ?? '').toString(),
        title: _texte(json['title']),
      );
}

/// Une séance que la famille a réservée — passée comprise.
///
/// Distincte de [LiveSessionSummary], qui décrit la vitrine : s'y ajoutent
/// l'état du paiement, le prénom de l'enfant concerné et la disponibilité de la
/// rediffusion. Trois choses qu'un visiteur anonyme ne doit pas voir.
class MySession {
  const MySession({
    required this.enrolmentId,
    required this.enrolmentStatus,
    required this.sessionId,
    required this.startsAt,
    required this.durationMinutes,
    required this.status,
    required this.price,
    this.minutesAttended = 0,
    this.childName,
    this.replay,
    this.subject,
    this.level,
    this.title,
    this.holdsUntil,
  });

  final String enrolmentId;

  /// Combien de minutes l'eleve a suivies sur cette seance.
  ///
  /// Zero avant la seance, et c'est juste : il n'y a rien a montrer avant.
  /// L'ecran s'en sert pour n'afficher la preuve de presence que sur les
  /// seances passees.
  ///
  /// Compte par le serveur de visioconference, jamais declare par l'eleve :
  /// « compte par EduQuali, pas declare par l'eleve ». C'est ce qui separe ce
  /// chiffre d'une case a cocher.
  final int minutesAttended;

  /// `PENDING` | `CONFIRMED` | `CANCELLED`.
  final String enrolmentStatus;
  final String sessionId;
  final DateTime startsAt;
  final int durationMinutes;
  final String status;
  final int price;
  final String? childName;

  /// `RECORDING` | `TRANSFERRING` | `READY` | `FAILED`, ou nul s'il n'y en aura
  /// pas. **Jamais l'identifiant de la vidéo** : il ne se lit qu'accompagné
  /// d'une signature, et le transporter ici n'apporterait qu'une occasion de
  /// fuite.
  final String? replay;

  final LiveRef? subject;
  final LiveRef? level;
  final String? title;

  /// Fin de la réservation provisoire, quand le paiement n'est pas passé.
  final DateTime? holdsUntil;

  bool get isPaid => enrolmentStatus == 'CONFIRMED';

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  /// La fenêtre d'entrée, identique à celle du serveur.
  ///
  /// Recopiée ici volontairement : le serveur refusera de toute façon un jeton
  /// en dehors, et montrer un bouton qui échoue vaut moins que ne pas le
  /// montrer. Les deux valeurs sont les mêmes qu'à
  /// `/live/sessions/:id/token` — si elles changent là-bas, elles changent ici.
  bool canJoinAt(DateTime maintenant) =>
      maintenant.isAfter(startsAt.subtract(const Duration(minutes: 15))) &&
      maintenant.isBefore(endsAt.add(const Duration(minutes: 30)));

  bool isOverAt(DateTime maintenant) =>
      maintenant.isAfter(endsAt.add(const Duration(minutes: 30)));

  factory MySession.fromJson(Map<String, dynamic> json) => MySession(
    enrolmentId: (json['enrolmentId'] ?? '').toString(),
    enrolmentStatus: (json['enrolmentStatus'] ?? 'PENDING').toString(),
    sessionId: (json['sessionId'] ?? '').toString(),
    startsAt:
        DateTime.tryParse((json['startsAt'] ?? '').toString())?.toLocal() ??
        DateTime.now(),
    durationMinutes: _entier(json['durationMinutes'], 90),
    minutesAttended: _entier(json['minutesAttended'], 0),
    status: (json['status'] ?? 'PLANNED').toString(),
    price: _entier(json['price'], 0),
    childName: _texte(json['childName']),
    replay: _texte(json['replay']),
    subject: _ref(json['subject']),
    level: _ref(json['level']),
    title: _texte(json['title']),
    holdsUntil: DateTime.tryParse(
      (json['holdsUntil'] ?? '').toString(),
    )?.toLocal(),
  );
}

/// Un repère de module dans la rediffusion.
///
/// Des secondes, pas un fichier. Découper la vidéo en quatre aurait demandé un
/// ré-encodage, doublé le stockage facturé chez Cloudflare et multiplié par quatre
/// URL signées à tenir. Un `seekTo` répond à la même question — « où commence le
/// module que j'ai manqué ? » — sans rien de tout cela.
class ReplayChapter {
  const ReplayChapter({
    required this.index,
    required this.label,
    required this.startSeconds,
  });

  final int index;
  final String label;
  final int startSeconds;

  Duration get start => Duration(seconds: startSeconds);

  factory ReplayChapter.fromJson(Map<String, dynamic> json) => ReplayChapter(
    index: _entier(json['index'], 0),
    label: (json['label'] ?? '').toString(),
    startSeconds: _entier(json['startSeconds'], 0),
  );
}

/// L'état d'une rediffusion.
class SessionReplay {
  const SessionReplay({
    required this.status,
    required this.available,
    this.hls,
    this.title,
    this.startsAt,
    this.chapters = const [],
  });

  /// `NONE` | `RECORDING` | `TRANSFERRING` | `READY` | `FAILED`.
  final String status;
  final bool available;

  /// Le flux HLS signé. **Présent seulement quand [available] est vrai** : un
  /// champ toujours là mais parfois vide inviterait à le passer au lecteur, qui
  /// échouerait en silence.
  ///
  /// HLS et non le lecteur intégré de Cloudflare Stream : sur Android,
  /// `video_player` lit
  /// HLS nativement par ExoPlayer. Le site, lui, prend l'`iframe` parce que
  /// Chrome et Firefox ne lisent pas HLS sans bibliothèque.
  final String? hls;

  final String? title;
  final DateTime? startsAt;

  /// Vide quand la séance n'a eu aucun point de contrôle : on ne coupe pas au
  /// hasard. Mieux vaut pas de chapitres que des chapitres qui mentent.
  final List<ReplayChapter> chapters;

  factory SessionReplay.fromJson(Map<String, dynamic> json) => SessionReplay(
    status: (json['status'] ?? 'NONE').toString(),
    available: json['available'] == true,
    hls: _texte(json['hls']),
    title: _texte(json['title']),
    startsAt: DateTime.tryParse((json['startsAt'] ?? '').toString())?.toLocal(),
    chapters: switch (json['chapters']) {
      final List liste =>
        liste
            .whereType<Map<String, dynamic>>()
            .map(ReplayChapter.fromJson)
            .toList(growable: false),
      _ => const [],
    },
  );
}

/// Un enfant en cours, en ce moment.
///
/// **Rien qui touche à l'image.** Le serveur ne rend qu'un prénom, une matière
/// et des minutes : c'est une présence, pas une surveillance vidéo, et un parent
/// qui pourrait regarder son enfant pendant le cours changerait la nature de ce
/// qu'on vend.
class LivePresence {
  const LivePresence({
    required this.id,
    required this.sessionId,
    required this.minutes,
    this.childName,
    this.subjectName,
    this.courseTitle,
  });

  final String id;
  final String sessionId;

  /// Minutes écoulées, **comptées par le serveur**. L'horloge d'un téléphone
  /// guinéen n'est pas toujours juste, et c'est le chiffre sur lequel un parent
  /// juge si l'abonnement sert.
  final int minutes;

  final String? childName;
  final String? subjectName;
  final String? courseTitle;

  factory LivePresence.fromJson(Map<String, dynamic> json) => LivePresence(
    id: (json['id'] ?? '').toString(),
    sessionId: (json['sessionId'] ?? '').toString(),
    minutes: _entier(json['minutes'], 0),
    childName: _texte(json['childName']),
    subjectName: _texte(json['subjectName']),
    courseTitle: _texte(json['courseTitle']),
  );
}

/// Le temps de cours cumulé sur une période.
class StudySummary {
  const StudySummary({
    required this.totalMinutes,
    required this.sessions,
    required this.perChild,
    required this.perSubject,
  });

  final int totalMinutes;
  final int sessions;

  /// Une ligne par enfant, la plus longue d'abord.
  final List<StudyLine> perChild;
  final List<StudyLine> perSubject;

  bool get isEmpty => totalMinutes <= 0;

  static const StudySummary vide = StudySummary(
    totalMinutes: 0,
    sessions: 0,
    perChild: [],
    perSubject: [],
  );

  factory StudySummary.fromJson(Map<String, dynamic> json) => StudySummary(
    totalMinutes: _entier(json['totalMinutes'], 0),
    sessions: _entier(json['sessions'], 0),
    perChild: _lignes(json['perChild'], 'childName'),
    perSubject: _lignes(json['perSubject'], 'subjectName'),
  );
}

class StudyLine {
  const StudyLine({required this.label, required this.minutes});

  final String label;
  final int minutes;
}

/// Le jeton d'entrée dans une salle, tel que le serveur l'émet.
///
/// L'identité n'est pas le compte mais **la place payée** : LiveKit déconnecte
/// le premier participant quand un second arrive avec la même identité, et deux
/// enfants d'une même famille inscrits à la même séance se chasseraient l'un
/// l'autre. Le serveur s'en charge ; cet objet ne porte que ce que l'écran doit
/// savoir.
class RoomAccess {
  const RoomAccess({
    required this.token,
    required this.url,
    required this.room,
    required this.role,
    this.enrolmentId,
    this.recording,
  });

  final String token;
  final String url;
  final String room;

  /// `teacher` ou `student`. Décide des droits, que le jeton porte déjà : cet
  /// écran ne tente pas de publier pour un élève, parce qu'échouer afficherait
  /// une erreur de permission à quelqu'un qui n'a rien demandé.
  final String role;

  final String? enrolmentId;

  /// `RECORDING` quand la séance est enregistrée. **Affiché à tout le monde** :
  /// quinze élèves mineurs filmés pendant 90 minutes doivent le savoir, et
  /// l'information vient du serveur plutôt que d'une supposition de l'écran.
  final String? recording;

  factory RoomAccess.fromJson(Map<String, dynamic> json) => RoomAccess(
    token: (json['token'] ?? '').toString(),
    url: (json['url'] ?? '').toString(),
    room: (json['room'] ?? '').toString(),
    role: json['role'] == 'teacher' ? 'teacher' : 'student',
    enrolmentId: _texte(json['enrolmentId']),
    recording: _texte(json['recording']),
  );
}

/// Un point de contrôle de module.
///
/// `counts` et `summary` n'existent pas ici, et c'est voulu : le serveur ne les
/// rend qu'au professeur. Montrer « 11 sur 15 ont compris » à un élève lui
/// apprendrait aussi qu'il fait partie des quatre, ce qui le pousserait à
/// répondre « oui » au module suivant.
class Checkpoint {
  const Checkpoint({
    required this.id,
    required this.moduleIndex,
    this.closedAt,
    this.myAnswer,
  });

  final String id;
  final int moduleIndex;
  final DateTime? closedAt;

  /// `YES` | `PARTLY` | `NO`, pour savoir que la réponse est partie.
  final String? myAnswer;

  factory Checkpoint.fromJson(Map<String, dynamic> json) => Checkpoint(
    id: (json['id'] ?? '').toString(),
    moduleIndex: _entier(json['moduleIndex'], 0),
    closedAt: DateTime.tryParse((json['closedAt'] ?? '').toString())?.toLocal(),
    myAnswer: _texte(json['myAnswer']),
  );
}

/// L'état des points de contrôle d'une séance.
class CheckpointsView {
  const CheckpointsView({required this.role, required this.checkpoints});

  final String role;
  final List<Checkpoint> checkpoints;

  factory CheckpointsView.fromJson(Map<String, dynamic> json) =>
      CheckpointsView(
        role: json['role'] == 'teacher' ? 'teacher' : 'student',
        checkpoints: switch (json['checkpoints']) {
          final List liste =>
            liste
                .whereType<Map<String, dynamic>>()
                .map(Checkpoint.fromJson)
                .toList(growable: false),
          _ => const [],
        },
      );
}

/// Ce que rend l'ouverture ou la fermeture d'une salle.
class RoomState {
  const RoomState({required this.status, this.recording, this.alreadyOpen});

  final String status;
  final String? recording;
  final bool? alreadyOpen;

  factory RoomState.fromJson(Map<String, dynamic> json) => RoomState(
    status: (json['status'] ?? '').toString(),
    recording: _texte(json['recording']),
    alreadyOpen: json['alreadyOpen'] == true,
  );
}

/// Ce que rend une inscription : la place, et par où payer.
class EnrolmentOutcome {
  const EnrolmentOutcome({
    required this.enrolmentId,
    required this.status,
    this.payment,
    this.redirectUrl,
    this.paymentError,
    this.sandbox = false,
    this.holdsUntil,
  });

  final String enrolmentId;
  final String status;

  /// `none` | `awaiting_confirmation` | `redirect`.
  final String? payment;
  final String? redirectUrl;
  final String? paymentError;

  /// Vrai en bac à sable. **Porté jusqu'à l'écran** : une démonstration qui
  /// passe pour un encaissement réel ne se découvre qu'en cherchant l'argent.
  final bool sandbox;

  final DateTime? holdsUntil;

  factory EnrolmentOutcome.fromJson(Map<String, dynamic> json) =>
      EnrolmentOutcome(
        enrolmentId: (json['enrolmentId'] ?? json['id'] ?? '').toString(),
        status: (json['status'] ?? 'PENDING').toString(),
        payment: _texte(json['payment']),
        redirectUrl: _texte(json['redirectUrl']),
        paymentError: _texte(json['paymentError']),
        sandbox: json['sandbox'] == true,
        holdsUntil: DateTime.tryParse(
          (json['holdsUntil'] ?? '').toString(),
        )?.toLocal(),
      );
}

// --- Lecture défensive du JSON ---------------------------------------------
//
// Le serveur et ces objets évoluent séparément. Un champ absent ou d'un autre
// type doit donner une valeur par défaut, pas une exception au milieu d'une
// liste : un écran vide avec un message est récupérable, un écran rouge non.

int _entier(Object? valeur, int defaut) => switch (valeur) {
  final int i => i,
  final num n => n.round(),
  final String s => int.tryParse(s) ?? defaut,
  _ => defaut,
};

String? _texte(Object? valeur) {
  if (valeur is! String) return null;
  final propre = valeur.trim();
  return propre.isEmpty ? null : propre;
}

LiveRef? _ref(Object? valeur) =>
    valeur is Map<String, dynamic> ? LiveRef.fromJson(valeur) : null;

List<StudyLine> _lignes(Object? valeur, String cle) {
  if (valeur is! List) return const [];
  return valeur
      .whereType<Map<String, dynamic>>()
      .map(
        (ligne) => StudyLine(
          label: (ligne[cle] ?? '').toString(),
          minutes: _entier(ligne['minutes'], 0),
        ),
      )
      .where((ligne) => ligne.label.isNotEmpty)
      .toList(growable: false);
}


/// La preuve de presence d'une seance.
///
/// « Votre enfant etait la. Vous le voyez. » C'est la promesse faite au
/// parent, et la seule chose qu'il vient chercher apres une seance.
///
/// Les trois faits que la charte demande autour des minutes : l'heure
/// d'arrivee, les points de controle auxquels l'eleve a repondu, et ce qui a
/// ete travaille. Pas un de plus — « l'ecran ne montre ni note, ni
/// classement, ni comparaison avec les autres eleves ».
class PresenceProof {
  const PresenceProof({
    required this.sessionId,
    required this.startsAt,
    required this.durationMinutes,
    required this.minutesAttended,
    required this.checkpointsAnswered,
    required this.checkpointsTotal,
    this.childName,
    this.joinedAt,
    this.title,
    this.subject,
    this.level,
    this.replay,
  });

  factory PresenceProof.fromJson(Map<String, dynamic> json) => PresenceProof(
    sessionId: (json['sessionId'] ?? '').toString(),
    startsAt:
        DateTime.tryParse((json['startsAt'] ?? '').toString())?.toLocal() ??
        DateTime.now(),
    durationMinutes: _entier(json['durationMinutes'], 90),
    minutesAttended: _entier(json['minutesAttended'], 0),
    checkpointsAnswered: _entier(json['checkpointsAnswered'], 0),
    checkpointsTotal: _entier(json['checkpointsTotal'], 0),
    childName: json['childName']?.toString(),
    joinedAt: DateTime.tryParse((json['joinedAt'] ?? '').toString())?.toLocal(),
    title: json['title']?.toString(),
    subject: json['subject']?.toString(),
    level: json['level']?.toString(),
    replay: json['replay']?.toString(),
  );

  final String sessionId;
  final DateTime startsAt;
  final int durationMinutes;

  /// Compte par le serveur de visioconference, jamais declare par l'eleve.
  /// C'est ce qui separe ce chiffre d'une case a cocher.
  final int minutesAttended;

  final int checkpointsAnswered;
  final int checkpointsTotal;

  /// Le prenom de l'eleve. Nul pour un compte qui suit pour lui-meme.
  final String? childName;

  /// L'heure d'entree en salle. **Jamais un retard calcule** : « un retard se
  /// dit avec l'heure d'arrivee », et l'ecran ne la commente pas.
  final DateTime? joinedAt;

  final String? title;
  final String? subject;
  final String? level;

  /// `READY` | `TRANSFERRING` | `FAILED`, ou nul s'il n'y a pas
  /// d'enregistrement. C'est lui qui porte la phrase de rattrapage.
  final String? replay;

  /// A-t-il suivi la seance ?
  bool get etaitLa => minutesAttended > 0;

  /// Les minutes manquees. Zero quand il etait la du debut a la fin.
  int get minutesManquees =>
      (durationMinutes - minutesAttended).clamp(0, durationMinutes);

  /// Vaut-il la peine de proposer l'enregistrement ?
  ///
  /// Cinq minutes : en dessous, c'est une entree un peu tardive, et proposer
  /// de rattraper trois minutes ferait d'un detail un probleme.
  bool get aRattraper => minutesManquees >= 5;
}
