import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// Message rendu quand aucun serveur n'est configuré.
///
/// L'application est conçue pour fonctionner sans serveur : les comptes, les
/// offres et les cours vivent dans la base locale. Ce message ne
/// doit donc apparaître que sur les rares actions qui exigent vraiment le
/// serveur — pas au démarrage, pas dans un écran de liste.
const String backendUnavailableMessage =
    'Cette action a besoin du serveur, qui n’est pas encore en ligne. '
    'Le reste de l’application fonctionne normalement.';

/// Levée avant tout appel réseau quand `ACALIA_API` n'a pas été fixé.
class BackendUnavailable implements Exception {
  const BackendUnavailable();

  @override
  String toString() => backendUnavailableMessage;
}

/// Le client HTTP de l'application, construit en un seul endroit.
///
/// Il existait deux copies de cette configuration — `main.dart` et les
/// providers — qui auraient fini par diverger sur un délai ou un en-tête.
///
/// [readToken] est appelé à chaque requête plutôt qu'une fois : le jeton
/// change à la connexion et à la déconnexion.
Dio buildApiClient(Future<String?> Function() readToken) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Sans serveur configuré, on refuse tout de suite plutôt que de
        // laisser Dio construire une adresse relative et échouer douze
        // secondes plus tard sur un message incompréhensible.
        if (!AppConstants.hasBackend) {
          return handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.unknown,
              error: const BackendUnavailable(),
              message: backendUnavailableMessage,
            ),
            true,
          );
        }

        // Jeton d'acces injecte a chaque requete (§51).
        final token = await readToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );
  return dio;
}
