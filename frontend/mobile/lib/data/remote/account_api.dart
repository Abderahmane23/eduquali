import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';

/// Déclare au serveur le compte qui vient de naître sur ce téléphone.
///
/// --- Le maillon qui manquait ---------------------------------------------
///
/// L'inscription créait l'identité chez Supabase (`/auth/v1/signup`) puis
/// écrivait tout le reste dans la base locale. Pour le serveur, elle mettait
/// l'entité `user` dans la file de synchronisation — que celle-ci refuse, avec
/// pour motif « un profil se modifie par la route de compte ».
///
/// **Cette route n'existait pas.** Un compte créé depuis le téléphone avait
/// donc une identité et **aucune ligne `profiles`** : le site ne voyait pas la
/// personne, toute politique appuyée sur `profiles` la rejetait, et sa fiche
/// `teachers` ou `parents` n'existait pas côté serveur — donc rien de ce qui
/// s'y rattache ne pouvait remonter.
///
/// C'est l'explication de « la synchro ne marche pas » : il n'y avait rien à
/// synchroniser, puisque le compte n'existait pas.
///
/// --- Pourquoi ce n'est pas une entité de synchronisation ----------------
///
/// `profiles` porte le **rôle**, et le rôle décide de tout le reste. Une
/// entité poussée par le client laisserait quelqu'un se déclarer `ADMIN`. La
/// route lit donc l'identité dans le jeton, jamais dans le corps.
class AccountApi {
  AccountApi(this._dio);

  final Dio _dio;

  static bool get isConfigured => AppConstants.hasBackend;

  /// Crée ou met à jour le profil et la fiche de rôle.
  ///
  /// [accessToken] est celui que l'inscription vient d'obtenir : à cet
  /// instant, aucune session n'est encore ouverte dans l'application.
  ///
  /// Rend l'identifiant de la fiche de rôle quand le serveur en a créé une.
  Future<String?> provision({
    required String accessToken,
    required String role,
    required String phone,
    String? firstName,
    String? lastName,
    String? city,
    String? region,
    String? district,
    String? institutionName,
    String? institutionType,
    String? pendingPlan,
    String? roleId,
  }) async {
    try {
      final reponse = await _dio.post<Map<String, dynamic>>(
        '/account',
        data: {
          'role': role,
          'phone': phone,
          if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
          if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
          if (city != null && city.isNotEmpty) 'city': city,
          if (region != null && region.isNotEmpty) 'region': region,
          if (district != null && district.isNotEmpty) 'district': district,
          if (institutionName != null && institutionName.isNotEmpty)
            'institutionName': institutionName,
          if (institutionType != null && institutionType.isNotEmpty)
            'institutionType': institutionType,
          if (pendingPlan != null && pendingPlan.isNotEmpty)
            'pendingPlan': pendingPlan,
          // Le même identifiant des deux côtés : les enfants d'une famille
          // sont poussés avec `parent_id`, et deux identifiants différents
          // feraient échouer la clé étrangère.
          if (roleId != null && roleId.isNotEmpty) 'roleId': roleId,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
          // Le compte local existe déjà quand on arrive ici : un échec se
          // reprend, il ne doit pas faire attendre devant un écran figé.
          sendTimeout: AppConstants.networkTimeout,
          receiveTimeout: AppConstants.networkTimeout,
        ),
      );
      return reponse.data?['roleId'] as String?;
    } on DioException catch (erreur) {
      throw AccountApiException(
        _decrire(erreur),
        offline:
            erreur.type == DioExceptionType.connectionError ||
            erreur.type == DioExceptionType.connectionTimeout ||
            erreur.type == DioExceptionType.receiveTimeout,
      );
    }
  }

  /// Remplace les matières et niveaux déclarés, d'un bloc.
  ///
  /// Une route et non une entité de synchronisation : ce sont des
  /// **ensembles**. « Voilà mes matières » veut dire en ajouter *et retirer
  /// celles qu'on a décochées*, ce qu'une écriture ligne par ligne ne sait pas
  /// exprimer. Le client poussait `{subjectIds: [...]}` vers une entité dont
  /// les colonnes sont `teacher_id` et `subject_id` : aucune clé ne
  /// correspondait, la charge était vidée, l'envoi refusé.
  ///
  /// [parMatiere] associe chaque matière aux niveaux où elle est enseignée —
  /// `teacher_levels` est clé par (professeur, matière, niveau), donc une
  /// liste plate ne suffit pas.
  Future<void> setCompetences(Map<String, List<String>> parMatiere) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/teacher/competences',
        data: {
          'subjects': [
            for (final entree in parMatiere.entries)
              {'subjectId': entree.key, 'levelIds': entree.value},
          ],
        },
      );
    } on DioException catch (erreur) {
      throw AccountApiException(
        _decrire(erreur),
        offline:
            erreur.type == DioExceptionType.connectionError ||
            erreur.type == DioExceptionType.connectionTimeout,
      );
    }
  }

  String _decrire(DioException erreur) {
    final corps = erreur.response?.data;
    if (corps is Map && corps['error'] is String) {
      return corps['error'] as String;
    }
    return switch (erreur.type) {
      DioExceptionType.connectionError =>
        'Serveur injoignable. Vérifiez votre connexion.',
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout => 'Délai dépassé.',
      _ => 'Le serveur n’a pas pu enregistrer le compte.',
    };
  }
}

class AccountApiException implements Exception {
  const AccountApiException(this.message, {this.offline = false});

  final String message;

  /// Vrai quand c'est le réseau : l'appel se reprend, et le compte local
  /// reste utilisable en attendant.
  final bool offline;

  @override
  String toString() => message;
}
