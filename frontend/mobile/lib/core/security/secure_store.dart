import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage sécurisé des jetons et secrets (§51).
///
/// Les données issues des pieces d'identité ne transitent jamais par les logs
/// applicatifs (§51) : ce service ne journalise aucune valeur.
class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              encryptedSharedPreferences: true,
              // Sans ce drapeau, un magasin de clés abîmé lève une exception
              // à **chaque** lecture, définitivement. Et le magasin s'abîme
              // pour des raisons qui n'ont rien à voir avec nous : une
              // restauration de sauvegarde, une mise à jour du système, un
              // ROM constructeur qui gère mal AndroidX Security. C'est la
              // panne la mieux documentée de ce greffon.
              //
              // Elle explique exactement ce qui a été signalé le 25/09 :
              // l'application se lançait chez les uns et restait sur le logo
              // chez les autres. `main()` attendait cette lecture avant
              // `runApp`, sans rattrapage — une exception ici, et il n'y
              // avait plus d'application du tout.
              //
              // `resetOnError` efface le magasin et repart à zéro. On y perd
              // un identifiant d'appareil et un jeton de session, c'est-à-dire
              // une reconnexion ; sans lui on perd l'application entière.
              resetOnError: true,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kSessionUserId = 'session_user_id';
  static const _kDeviceId = 'device_id';
  static const _kPinHash = 'pin_hash';

  Future<String?> get accessToken => _storage.read(key: _kAccessToken);
  Future<String?> get refreshToken => _storage.read(key: _kRefreshToken);
  Future<String?> get sessionUserId => _storage.read(key: _kSessionUserId);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  Future<void> saveSessionUser(String userId) =>
      _storage.write(key: _kSessionUserId, value: userId);

  Future<void> clearSession() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kSessionUserId);
  }

  /// Identifiant d'appareil, utilise pour la résolution de conflits (§45).
  Future<String> deviceId() async {
    final existing = await _storage.read(key: _kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _randomId();
    await _storage.write(key: _kDeviceId, value: generated);
    return generated;
  }

  Future<void> savePin(String pin) =>
      _storage.write(key: _kPinHash, value: hashSecret(pin));

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _kPinHash);
    return stored != null && stored == hashSecret(pin);
  }

  Future<void> wipe() => _storage.deleteAll();

  /// Empreinte d'un secret. En production, l'authentification est deleguee au
  /// serveur ; ce condensat protege uniquement la copie locale.
  static String hashSecret(String value, {String salt = 'veriprof.v1'}) {
    final bytes = utf8.encode('$salt::$value');
    return sha256.convert(bytes).toString();
  }

  static String _randomId() {
    final seed = DateTime.now().microsecondsSinceEpoch.toString();
    return sha256.convert(utf8.encode(seed)).toString().substring(0, 32);
  }
}
