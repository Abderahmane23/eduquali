import 'package:dio/dio.dart';

/// Operation locale poussee vers le serveur (§44).
class SyncPushItem {
  const SyncPushItem({
    required this.localId,
    required this.entity,
    required this.entityId,
    required this.operation,
    required this.payload,
  });

  final int localId;
  final String entity;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'clientRef': localId,
    'entity': entity,
    'entityId': entityId,
    'operation': operation,
    'payload': payload,
  };
}

enum SyncOutcome { applied, conflict, failed }

class SyncPushResult {
  const SyncPushResult({
    required this.localId,
    required this.entity,
    required this.entityId,
    required this.outcome,
    this.message,
  });

  final int localId;
  final String entity;
  final String entityId;
  final SyncOutcome outcome;
  final String? message;
}

class SyncPullResponse {
  const SyncPullResponse({required this.changes, this.cursor});

  final List<Map<String, dynamic>> changes;
  final String? cursor;
}

class SyncApiException implements Exception {
  const SyncApiException(this.message);
  final String message;

  @override
  String toString() => 'SyncApiException: $message';
}

/// Client des endpoints de synchronisation (§44) :
/// `POST /sync/push` et `GET /sync/pull?cursor=...`.
class SyncApi {
  SyncApi(this._dio);

  final Dio _dio;

  Future<List<SyncPushResult>> push(List<SyncPushItem> items) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sync/push',
        data: {
          'operations': [for (final item in items) item.toJson()],
        },
      );

      final results = (response.data?['results'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

      return [
        for (final raw in results)
          SyncPushResult(
            localId: raw['clientRef'] as int,
            entity: raw['entity'] as String? ?? '',
            entityId: raw['entityId'] as String? ?? '',
            outcome: _outcome(raw['status'] as String?),
            message: raw['message'] as String?,
          ),
      ];
    } on DioException catch (error) {
      throw SyncApiException(_describe(error));
    }
  }

  Future<SyncPullResponse> pull(String? cursor) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/sync/pull',
        queryParameters: {'cursor': ?cursor},
      );
      return SyncPullResponse(
        changes: (response.data?['changes'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>(),
        cursor: response.data?['cursor'] as String?,
      );
    } on DioException catch (error) {
      throw SyncApiException(_describe(error));
    }
  }

  SyncOutcome _outcome(String? status) => switch (status) {
    'APPLIED' => SyncOutcome.applied,
    'CONFLICT' => SyncOutcome.conflict,
    _ => SyncOutcome.failed,
  };

  String _describe(DioException error) => switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => 'Delai depasse',
    DioExceptionType.connectionError => 'Serveur injoignable',
    DioExceptionType.badResponse =>
      'Réponse serveur ${error.response?.statusCode}',
    _ => 'Synchronisation impossible',
  };
}
