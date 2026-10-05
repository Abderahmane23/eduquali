import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

/// Le seul endroit où l'application parle des groupes au serveur.
///
/// --- Pourquoi les groupes ne passent pas par la synchronisation ----------
///
/// Le reste de l'application est « local d'abord » : on écrit dans SQLite et
/// la file d'envoi rattrape. Un groupe ne peut pas fonctionner ainsi, et pour
/// deux raisons :
///
///   * **l'appartenance est calculée par la base**, pas par le téléphone
///     (`est_membre_groupe`). Un client qui déciderait lui-même de ce qu'il
///     peut lire déciderait d'entrer dans un groupe d'enfants ;
///   * un message doit arriver aux **autres**. Une file qui rattrape dans une
///     heure fait répondre à une question que tout le monde a oubliée.
///
/// Les messages sont tout de même rangés en local après lecture, pour que la
/// discussion se relise hors réseau — c'est ce que fait n'importe quelle
/// messagerie, et c'est indispensable ici.
class ChatApi {
  ChatApi(this._dio);

  final Dio _dio;

  /// Les groupes de la personne. Le serveur ne rend que les siens : c'est la
  /// politique de lecture qui filtre, pas un paramètre qu'on pourrait oublier.
  Future<List<ChatGroup>> groups() async {
    final data = await _appel(
      () => _dio.get<Map<String, dynamic>>('/chat/groups'),
    );
    return [
      for (final ligne
          in (data['groups'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>())
        ChatGroup.fromJson(ligne),
    ];
  }

  /// Les cinquante derniers messages, du plus ancien au plus récent.
  ///
  /// [before] remonte dans le passé : une discussion se lit par le bas.
  Future<List<ChatMessage>> messages(String groupId, {DateTime? before}) async {
    final data = await _appel(
      () => _dio.get<Map<String, dynamic>>(
        '/chat/groups/$groupId/messages',
        queryParameters: {
          if (before != null) 'before': before.toUtc().toIso8601String(),
        },
      ),
    );
    return [
      for (final ligne
          in (data['messages'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>())
        ChatMessage.fromJson(ligne),
    ];
  }

  /// Envoie un message. L'auteur vient du jeton, jamais d'ici.
  Future<({String id, DateTime sentAt})> send(
    String groupId,
    String body,
  ) async {
    final data = await _appel(
      () => _dio.post<Map<String, dynamic>>(
        '/chat/groups/$groupId/messages',
        data: {'body': body},
      ),
    );
    return (
      id: (data['id'] ?? '').toString(),
      sentAt:
          DateTime.tryParse((data['sentAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Future<T> _appel<T>(Future<Response<T>> Function() requete) async {
    try {
      final reponse = await requete();
      final corps = reponse.data;
      if (corps == null) {
        throw const ChatApiException('Le serveur a répondu sans contenu.');
      }
      return corps;
    } on DioException catch (erreur) {
      if (erreur.error is BackendUnavailable) {
        throw const ChatApiException(
          'Les groupes ont besoin du serveur, qui n’est pas encore en ligne.',
          offline: true,
        );
      }
      throw ChatApiException(_describe(erreur), offline: _estHorsLigne(erreur));
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

/// Un groupe, tel que la liste l'affiche.
class ChatGroup {
  const ChatGroup({
    required this.id,
    required this.kind,
    required this.sourceId,
    required this.name,
    this.lastBody,
    this.lastAt,
  });

  factory ChatGroup.fromJson(Map<String, dynamic> json) => ChatGroup(
    id: (json['id'] ?? '').toString(),
    kind: (json['kind'] ?? 'COURSE').toString(),
    sourceId: (json['sourceId'] ?? '').toString(),
    name: (json['name'] ?? 'Groupe').toString(),
    lastBody: json['lastBody']?.toString(),
    lastAt: DateTime.tryParse((json['lastAt'] ?? '').toString()),
  );

  final String id;

  /// `COURSE` ou `CONTRACT`.
  final String kind;
  final String sourceId;
  final String name;
  final String? lastBody;
  final DateTime? lastAt;

  /// Ce que la liste écrit sous le nom quand rien n'a encore été dit.
  String get apercu => lastBody ?? 'Pas encore de message';
}

/// Un message dans un groupe.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.body,
    required this.sentAt,
    this.pending = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: (json['id'] ?? '').toString(),
    groupId: (json['groupId'] ?? '').toString(),
    authorId: (json['authorId'] ?? '').toString(),
    authorName: (json['authorName'] ?? 'Quelqu’un').toString(),
    authorRole: (json['authorRole'] ?? 'PARENT').toString(),
    body: (json['body'] ?? '').toString(),
    sentAt:
        DateTime.tryParse((json['sentAt'] ?? '').toString()) ?? DateTime.now(),
  );

  final String id;
  final String groupId;
  final String authorId;
  final String authorName;

  /// Le rôle du compte, pour distinguer le professeur d'un coup d'œil.
  final String authorRole;
  final String body;
  final DateTime sentAt;

  /// Posé localement, pas encore confirmé par le serveur. Le message s'affiche
  /// quand même, en attente : sans cela, écrire sur une connexion lente ne
  /// montre rien et l'on réécrit trois fois le même message.
  final bool pending;

  bool get fromTeacher => authorRole == 'TEACHER';

  ChatMessage withId(String nouveau, DateTime quand) => ChatMessage(
    id: nouveau,
    groupId: groupId,
    authorId: authorId,
    authorName: authorName,
    authorRole: authorRole,
    body: body,
    sentAt: quand,
  );
}

class ChatApiException implements Exception {
  const ChatApiException(this.message, {this.offline = false});

  final String message;

  /// Vrai quand c'est le réseau et non le serveur : l'écran propose alors de
  /// réessayer plutôt que d'expliquer un refus.
  final bool offline;

  @override
  String toString() => message;
}
