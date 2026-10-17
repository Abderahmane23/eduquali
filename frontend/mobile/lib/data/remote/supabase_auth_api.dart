import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';

/// Un compte tel que Supabase le rend.
class RemoteAccount {
  const RemoteAccount({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });

  /// L'identifiant du compte, cote serveur.
  ///
  /// C'est **lui** que la base locale enregistre comme `users.id` : un compte
  /// doit porter le meme identifiant sur le telephone et sur le site, sinon
  /// « le meme compte » n'est qu'une facon de parler et rien ne se retrouve
  /// d'un cote a partir de l'autre.
  final String userId;

  final String accessToken;
  final String refreshToken;
}

/// Ce qui a empeche une operation d'aboutir.
class RemoteAuthException implements Exception {
  const RemoteAuthException(this.message, {this.offline = false});

  final String message;

  /// Vrai quand rien n'a pu partir. L'appelant peut alors se replier sur la
  /// base locale au lieu de refuser une connexion que le reseau seul empeche.
  final bool offline;

  @override
  String toString() => message;
}

/// Identite partagee avec le site : l'authentification de Supabase.
///
/// --- Pourquoi Dio et non `supabase_flutter` -------------------------------
///
/// `supabase_flutter` tire `app_links`, dont l'implementation Android est en
/// Kotlin. Ce projet compile avec AGP 9, et les greffons dont le `build.gradle`
/// n'applique le plugin Kotlin que sous AGP 8 ne compilent alors pas leurs
/// sources : le build echoue au bout de huit minutes sur un
/// `GeneratedPluginRegistrant` qui ne trouve pas une classe, sans nommer la
/// cause. C'est exactement ce qui est arrive avec `file_picker` 11, epingle en
/// 8.3.7 pour cette raison.
///
/// L'authentification est trois appels HTTP. Dio est deja une dependance, le
/// paquet n'ajoute rien a l'APK, et il n'y a aucun code natif a compiler.
///
/// --- Sur la cle anonyme dans l'APK ----------------------------------------
///
/// Elle y est, et c'est sans danger : **la cle anonyme est publique par
/// construction** — le site l'envoie dans son bundle a chaque visiteur. Ce
/// n'est pas elle qui protege les donnees, c'est RLS, table par table. La
/// regle « aucune cle dans l'APK » vise la cle Gemini et la cle
/// `service_role`, qui donnent acces a tout ; celles-la ne doivent jamais
/// quitter `backend/.env`.
class SupabaseAuthApi {
  SupabaseAuthApi(Dio dio) : _dio = dio;

  final Dio _dio;

  /// Vrai quand un projet a ete configure a la compilation.
  static bool get isConfigured =>
      AppConstants.supabaseUrl.isNotEmpty &&
      AppConstants.supabaseAnonKey.isNotEmpty;

  Map<String, String> get _headers => {
    'apikey': AppConstants.supabaseAnonKey,
    'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
    'Content-Type': 'application/json',
  };

  String get _base => '${AppConstants.supabaseUrl}/auth/v1';

  /// Le courriel deduit d'un numero.
  ///
  /// **Doit rester identique a `emailFor` du client web.** Il n'y a aucune
  /// boite derriere : c'est un identifiant stable tire du numero, parce que
  /// l'authentification par telephone de Supabase exige un fournisseur SMS que
  /// nous n'avons pas encore. Deux formules differentes feraient deux comptes
  /// pour la meme personne, et ce serait invisible jusqu'au jour ou elle
  /// changerait d'appareil.
  static String emailFor(String phone) {
    return '${numeroNational(phone)}@telephone.eduquali.gn';
  }

  /// Les neuf chiffres d'un numero guineen, quelle que soit la facon de le
  /// taper.
  ///
  /// **Jumelle de `numeroNational` du client web** (`src/api/numero.ts`), ou
  /// l'histoire du defaut est racontee en entier. En resume : on ne gardait
  /// que les chiffres, si bien que `620000101`, `+224620000101` et
  /// `0620000101` donnaient trois comptes pour une seule personne. A
  /// l'inscription, l'ecran disait « compte cree » et les cours, paiements et
  /// enfants de l'autre compte etaient ailleurs ; a la connexion, Supabase
  /// repondait 400 sur un numero dont la personne etait sure.
  ///
  /// On pele de l'exterieur vers l'interieur : code de sortie international,
  /// puis indicatif du pays, puis zero de tete. Chaque retrait exige qu'il
  /// reste **plus** de neuf chiffres, pour qu'un abonne dont les neuf
  /// chiffres commencent par 224 ou par 0 garde les siens.
  static String numeroNational(String saisi) {
    var chiffres = saisi.replaceAll(RegExp(r'\D'), '');
    if (chiffres.startsWith('00') && chiffres.length > 9) {
      chiffres = chiffres.substring(2);
    }
    if (chiffres.startsWith('224') && chiffres.length > 9) {
      chiffres = chiffres.substring(3);
    }
    if (chiffres.startsWith('0') && chiffres.length > 9) {
      chiffres = chiffres.substring(1);
    }
    return chiffres;
  }

  /// Cree le compte et rend son identifiant.
  Future<RemoteAccount> signUp({
    required String phone,
    required String password,
  }) async {
    final reponse = await _post('/signup', {
      'email': emailFor(phone),
      'password': password,
    });

    final userId = _idDe(reponse);
    if (userId == null) {
      throw const RemoteAuthException(
        'Le compte a ete cree mais le serveur ne l\'a pas confirme. '
        'Essayez de vous connecter.',
      );
    }

    // Quand la confirmation par courriel est active cote projet, l'inscription
    // ne rend aucun jeton. Le compte existe pourtant : on le dit plutot que de
    // laisser croire a un echec, et le reglage a corriger est nomme dans
    // `documentation/DEPLOIEMENT.md` (§1.5).
    return RemoteAccount(
      userId: userId,
      accessToken: reponse['access_token'] as String? ?? '',
      refreshToken: reponse['refresh_token'] as String? ?? '',
    );
  }

  /// Ouvre une session.
  Future<RemoteAccount> signIn({
    required String phone,
    required String password,
  }) async {
    final reponse = await _post('/token?grant_type=password', {
      'email': emailFor(phone),
      'password': password,
    });

    final userId = _idDe(reponse);
    final acces = reponse['access_token'] as String?;
    if (userId == null || acces == null) {
      throw const RemoteAuthException('Numero ou mot de passe incorrect.');
    }
    return RemoteAccount(
      userId: userId,
      accessToken: acces,
      refreshToken: reponse['refresh_token'] as String? ?? '',
    );
  }

  /// Renouvelle un jeton expire.
  Future<RemoteAccount> refresh(String refreshToken) async {
    final reponse = await _post('/token?grant_type=refresh_token', {
      'refresh_token': refreshToken,
    });
    final userId = _idDe(reponse);
    final acces = reponse['access_token'] as String?;
    if (userId == null || acces == null) {
      throw const RemoteAuthException('Session expiree.');
    }
    return RemoteAccount(
      userId: userId,
      accessToken: acces,
      refreshToken: reponse['refresh_token'] as String? ?? refreshToken,
    );
  }

  /// L'identifiant du compte, que la reponse le pose a la racine ou sous
  /// `user` selon l'operation.
  String? _idDe(Map<String, dynamic> reponse) {
    final direct = reponse['id'];
    if (direct is String && direct.isNotEmpty) return direct;
    final user = reponse['user'];
    if (user is Map && user['id'] is String) return user['id'] as String;
    return null;
  }

  Future<Map<String, dynamic>> _post(
    String chemin,
    Map<String, dynamic> corps,
  ) async {
    try {
      final reponse = await _dio.post<Map<String, dynamic>>(
        '$_base$chemin',
        data: corps,
        options: Options(
          headers: _headers,
          // Les erreurs sont lues ici : Dio ne doit pas lever avant qu'on ait
          // pu extraire le message du serveur, qui dit souvent exactement ce
          // qui manque.
          validateStatus: (_) => true,
          sendTimeout: AppConstants.networkTimeout,
          receiveTimeout: AppConstants.networkTimeout,
        ),
      );

      final donnees = reponse.data ?? const <String, dynamic>{};
      final code = reponse.statusCode ?? 0;
      if (code >= 200 && code < 300) return donnees;

      throw RemoteAuthException(_messageDe(donnees, code));
    } on DioException catch (erreur) {
      // Reseau coupe, serveur injoignable, projet Supabase en pause : rien
      // n'est parti. L'appelant peut se replier sur la base locale.
      if (erreur.type != DioExceptionType.badResponse) {
        throw const RemoteAuthException('Serveur injoignable.', offline: true);
      }
      throw RemoteAuthException(
        _messageDe(
          erreur.response?.data as Map<String, dynamic>? ?? const {},
          erreur.response?.statusCode ?? 0,
        ),
      );
    }
  }

  /// Traduit un refus du serveur, sans recopier son anglais.
  String _messageDe(Map<String, dynamic> donnees, int code) {
    final brut = [
      donnees['msg'],
      donnees['message'],
      donnees['error_description'],
      donnees['error'],
    ].whereType<String>().firstOrNull;

    final texte = (brut ?? '').toLowerCase();

    if (texte.contains('already registered') ||
        texte.contains('already exists') ||
        code == 422) {
      return 'Ce numero a deja un compte. Essayez de vous connecter.';
    }
    if (texte.contains('invalid login') || code == 400) {
      return 'Numero ou mot de passe incorrect.';
    }
    if (texte.contains('password')) {
      return 'Mot de passe trop court.';
    }
    if (code == 429) {
      return 'Trop de tentatives. Attendez une minute.';
    }
    // Faute de mieux, le message du serveur : il en dit plus qu'un « erreur
    // inconnue », meme en anglais.
    return brut ?? 'Le serveur a refuse la demande ($code).';
  }
}
