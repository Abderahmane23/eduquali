import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../domain/entities/live_models.dart';

/// Le seul endroit où l'application parle des cours en direct au serveur.
///
/// --- Pourquoi tout passe par le serveur ----------------------------------
///
/// Les autres fonctions du téléphone lisent la base locale et se synchronisent.
/// Celle-ci ne peut pas, et chaque route le justifie :
///
///   * prendre une **place** est une mise à jour conditionnelle que seul le
///     serveur peut rendre atomique — quinze téléphones réclament le même siège ;
///   * le **jeton d'entrée** est signé avec un secret qui ne quitte pas le
///     serveur ;
///   * l'adresse d'une **rediffusion** n'est signée qu'après vérification du
///     paiement ;
///   * le **temps de cours** est compté par le serveur de visioconférence. Le
///     laisser calculer au client serait laisser mentir le compteur que le
///     parent paie pour lire.
///
/// Point de sortie unique : si une route change de forme, un seul fichier bouge.
class LiveApi {
  LiveApi(this._dio);

  final Dio _dio;

  /// La grille publique. Lisible sans compte, comme sur le site.
  Future<List<LiveSessionSummary>> sessions({
    String? subjectId,
    String? levelId,
    int? days,
  }) async {
    final data = await _liste(
      '/live/sessions',
      query: {
        if (subjectId != null && subjectId.isNotEmpty) 'subjectId': subjectId,
        if (levelId != null && levelId.isNotEmpty) 'levelId': levelId,
        // Marqueur null-aware : la cle disparait quand la valeur est nulle.
        'days': ?days,
      },
    );
    return data.map(LiveSessionSummary.fromJson).toList(growable: false);
  }

  /// Les séances réservées par la famille connectée, passées comprises.
  ///
  /// Sans cette liste, une séance payée disparaît dès le lendemain : ni
  /// rediffusion, ni trace de l'achat.
  Future<List<MySession>> mySessions() async {
    final data = await _liste('/live/my-sessions');
    return data.map(MySession.fromJson).toList(growable: false);
  }

  /// S'inscrit et lance le paiement.
  ///
  /// `childId` indique **qui** suit le cours. Il décide du prénom affiché au
  /// professeur dans la salle et du nom sous lequel le temps de cours est
  /// compté : une famille à deux enfants inscrits sur la même séance a deux
  /// places distinctes, et les confondre fausserait les deux compteurs.
  Future<EnrolmentOutcome> enrol({
    required String sessionId,
    String? childId,
    String? method,
    String? payerPhone,
  }) async {
    final reponse = await _appel<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/live/enrol',
        data: {
          'sessionId': sessionId,
          if (childId != null && childId.isNotEmpty) 'childId': childId,
          if (method != null && method.isNotEmpty) 'method': method,
          if (payerPhone != null && payerPhone.isNotEmpty)
            'payerPhone': payerPhone,
        },
      ),
    );
    return EnrolmentOutcome.fromJson(reponse);
  }

  /// Le jeton d'entrée dans la salle.
  ///
  /// Émis par le serveur, qui vérifie l'inscription payée et la fenêtre horaire :
  /// LiveKit n'a pas de notion de compte et fait confiance à ce jeton. Le secret
  /// qui le signe ne quitte jamais le serveur.
  Future<RoomAccess> roomToken(String sessionId, {String? enrolmentId}) async {
    final reponse = await _appel<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/live/sessions/${Uri.encodeComponent(sessionId)}/token',
        data: {
          if (enrolmentId != null && enrolmentId.isNotEmpty)
            'enrolmentId': enrolmentId,
        },
      ),
    );
    return RoomAccess.fromJson(reponse);
  }

  /// Le professeur ouvre la salle. Rejouable : recliquer ne relance pas un
  /// second enregistrement.
  Future<RoomState> openRoom(String sessionId) async {
    final reponse = await _appel<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/live/sessions/${Uri.encodeComponent(sessionId)}/open',
        data: const {},
      ),
    );
    return RoomState.fromJson(reponse);
  }

  /// Le professeur ferme la salle : l'egress s'arrête, puis tout le monde sort.
  Future<RoomState> closeRoom(String sessionId) async {
    final reponse = await _appel<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/live/sessions/${Uri.encodeComponent(sessionId)}/close',
        data: const {},
      ),
    );
    return RoomState.fromJson(reponse);
  }

  /// Les points de contrôle d'une séance.
  Future<CheckpointsView> checkpoints(String sessionId) async {
    final reponse = await _appel<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>(
        '/live/sessions/${Uri.encodeComponent(sessionId)}/checkpoints',
      ),
    );
    return CheckpointsView.fromJson(reponse);
  }

  /// Un élève répond à un point de contrôle.
  Future<void> answerCheckpoint(
    String checkpointId,
    String answer, {
    String? enrolmentId,
  }) async {
    await _appel<Map<String, dynamic>>(
      () => _dio.post<Map<String, dynamic>>(
        '/live/checkpoints/${Uri.encodeComponent(checkpointId)}/answer',
        data: {
          'answer': answer,
          if (enrolmentId != null && enrolmentId.isNotEmpty)
            'enrolmentId': enrolmentId,
        },
      ),
    );
  }

  /// L'état de la rediffusion d'une séance, et son flux signé si elle est prête.
  Future<SessionReplay> replay(String sessionId) async {
    final reponse = await _appel<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>(
        '/live/sessions/${Uri.encodeComponent(sessionId)}/replay',
      ),
    );
    return SessionReplay.fromJson(reponse);
  }

  /// Qui, parmi les siens, suit un cours en ce moment.
  Future<List<LivePresence>> presence() async {
    final data = await _liste('/live/presence');
    return data.map(LivePresence.fromJson).toList(growable: false);
  }

  /// Le temps de cours cumulé, par défaut depuis lundi.
  Future<StudySummary> studyMinutes({DateTime? since}) async {
    final reponse = await _appel<Map<String, dynamic>>(
      () => _dio.get<Map<String, dynamic>>(
        '/live/study-minutes',
        queryParameters: {
          if (since != null) 'since': since.toUtc().toIso8601String(),
        },
      ),
    );
    return StudySummary.fromJson(reponse);
  }

  // --- Plomberie ----------------------------------------------------------

  Future<List<Map<String, dynamic>>> _liste(
    String chemin, {
    Map<String, Object?> query = const {},
  }) async {
    final reponse = await _appel<List<dynamic>>(
      () => _dio.get<List<dynamic>>(chemin, queryParameters: query),
    );
    return reponse.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  /// Exécute un appel et traduit l'échec en message lisible.
  ///
  // --- Cote professeur ------------------------------------------------------

  /// Mes seances : celle en cours, et les suivantes.
  Future<List<TeacherSession>> teacherSessions() async {
    final corps = await _appel(
      () => _dio.get<Map<String, dynamic>>('/live/teacher/sessions'),
    );
    return [
      for (final ligne
          in (corps['sessions'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>())
        TeacherSession.fromJson(ligne),
    ];
  }

  /// Qui est attendu, et qui est entre.
  Future<Roster> roster(String sessionId) async {
    final corps = await _appel(
      () => _dio.get<Map<String, dynamic>>(
        '/live/sessions/${Uri.encodeComponent(sessionId)}/roster',
      ),
    );
    return Roster.fromJson(corps);
  }

  /// Prevenir une place, ou toutes.
  ///
  /// Rend le nombre de comptes prevenus — pas de places : deux enfants d'une
  /// meme famille ne font qu'une notification.
  Future<int> notifySession(
    String sessionId, {
    List<String>? enrolmentIds,
    bool all = false,
  }) async {
    final corps = await _appel(
      () => _dio.post<Map<String, dynamic>>(
        '/live/sessions/${Uri.encodeComponent(sessionId)}/notify',
        data: {
          if (all) 'all': true,
          if (!all && enrolmentIds != null) 'enrolmentIds': enrolmentIds,
        },
      ),
    );
    return (corps['notified'] as num?)?.toInt() ?? 0;
  }

  /// Le repertoire : les familles que je connais deja.
  Future<List<TeacherContact>> teacherContacts() async {
    final corps = await _appel(
      () => _dio.get<Map<String, dynamic>>('/live/teacher/contacts'),
    );
    return [
      for (final ligne
          in (corps['contacts'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>())
        TeacherContact.fromJson(ligne),
    ];
  }

  /// Les messages du serveur sont déjà écrits pour l'usager (« Votre place
  /// n'est pas encore payée », « La salle ouvre quinze minutes avant le
  /// début ») : on les relaie tels quels plutôt que de les remplacer par une
  /// phrase générique, qui obligerait la personne à deviner.
  Future<T> _appel<T>(Future<Response<T>> Function() requete) async {
    try {
      final reponse = await requete();
      final corps = reponse.data;
      if (corps == null) {
        throw const LiveApiException('Le serveur a répondu sans contenu.');
      }
      return corps;
    } on DioException catch (erreur) {
      if (erreur.error is BackendUnavailable) {
        throw const LiveApiException(
          'Les cours en direct ont besoin du serveur, qui n’est pas encore en '
          'ligne.',
          offline: true,
        );
      }
      throw LiveApiException(_describe(erreur), offline: _estHorsLigne(erreur));
    }
  }

  bool _estHorsLigne(DioException erreur) =>
      erreur.type == DioExceptionType.connectionError ||
      erreur.type == DioExceptionType.connectionTimeout ||
      erreur.type == DioExceptionType.receiveTimeout;

  String _describe(DioException erreur) {
    final corps = erreur.response?.data;
    if (corps is Map && corps['error'] is String) {
      return corps['error'] as String;
    }
    return switch (erreur.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'Délai dépassé. Réessayez.',
      DioExceptionType.connectionError =>
        'Serveur injoignable. Vérifiez votre connexion.',
      _ => 'Le serveur n’a pas pu traiter la demande.',
    };
  }
}

class LiveApiException implements Exception {
  const LiveApiException(this.message, {this.offline = false});

  final String message;

  /// Vrai quand c'est le réseau et non le serveur. L'écran propose alors de
  /// réessayer plutôt que d'expliquer un refus.
  final bool offline;

  @override
  String toString() => message;
}

/// Une séance vue par son professeur.
class TeacherSession {
  const TeacherSession({
    required this.id,
    required this.startsAt,
    required this.durationMinutes,
    required this.status,
    required this.seatsTaken,
    required this.seats,
    this.title,
    this.subject,
  });

  factory TeacherSession.fromJson(Map<String, dynamic> json) => TeacherSession(
    id: (json['id'] ?? '').toString(),
    startsAt:
        DateTime.tryParse((json['startsAt'] ?? '').toString()) ??
        DateTime.now(),
    durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 90,
    status: (json['status'] ?? 'PLANNED').toString(),
    seatsTaken: (json['seatsTaken'] as num?)?.toInt() ?? 0,
    seats: (json['seats'] as num?)?.toInt() ?? 0,
    title: json['title']?.toString(),
    subject: json['subject']?.toString(),
  );

  final String id;
  final DateTime startsAt;
  final int durationMinutes;
  final String status;
  final int seatsTaken;
  final int seats;
  final String? title;
  final String? subject;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  String get label => title ?? subject ?? 'Cours en direct';

  /// La même fenêtre que celle du serveur : quinze minutes avant, trente après.
  /// Recopiée ici pour ne pas proposer un bouton qui échouerait.
  bool canOpenAt(DateTime maintenant) =>
      maintenant.isAfter(startsAt.subtract(const Duration(minutes: 15))) &&
      maintenant.isBefore(endsAt.add(const Duration(minutes: 30)));
}

/// Un élève attendu, et s'il est entré.
class RosterEntry {
  const RosterEntry({
    required this.enrolmentId,
    required this.name,
    required this.present,
    required this.minutes,
  });

  factory RosterEntry.fromJson(Map<String, dynamic> json) => RosterEntry(
    enrolmentId: (json['enrolmentId'] ?? '').toString(),
    name: (json['name'] ?? 'Élève').toString(),
    present: json['present'] == true,
    minutes: (json['minutes'] as num?)?.toInt() ?? 0,
  );

  final String enrolmentId;
  final String name;
  final bool present;
  final int minutes;
}

/// La classe d'une séance : combien sont attendus, combien sont là.
class Roster {
  const Roster({
    required this.expected,
    required this.present,
    required this.entries,
  });

  factory Roster.fromJson(Map<String, dynamic> json) => Roster(
    expected: (json['expected'] as num?)?.toInt() ?? 0,
    present: (json['present'] as num?)?.toInt() ?? 0,
    entries: [
      for (final ligne
          in (json['roster'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>())
        RosterEntry.fromJson(ligne),
    ],
  );

  final int expected;
  final int present;
  final List<RosterEntry> entries;

  /// Ceux qu'il reste à faire venir — la seule liste sur laquelle on agit.
  List<RosterEntry> get absents => [
    for (final e in entries)
      if (!e.present) e,
  ];
}

/// Une famille du répertoire, et d'où le professeur la connaît.
class TeacherContact {
  const TeacherContact({
    required this.parentId,
    required this.name,
    required this.sources,
  });

  factory TeacherContact.fromJson(Map<String, dynamic> json) => TeacherContact(
    parentId: (json['parentId'] ?? '').toString(),
    name: (json['name'] ?? 'Famille').toString(),
    sources: [
      for (final s in (json['sources'] as List<dynamic>? ?? const []))
        s.toString(),
    ],
  );

  final String parentId;
  final String name;

  /// `SESSION` : a suivi une de mes séances. `CONTRACT` : sous contrat.
  final List<String> sources;

  String get origin => sources.contains('CONTRACT')
      ? 'Sous contrat avec vous'
      : 'A suivi vos séances';
}
