import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Le rappel d'une séance, une heure avant.
///
/// --- Pourquoi une notification locale, et non un envoi depuis le serveur -
///
/// Un envoi depuis le serveur demande Firebase : un compte, une clé dans
/// l'APK, et un appareil joignable. Rien de tout cela n'existe ici, et l'APK
/// circule par Bluetooth — une clé qui s'y trouverait se lirait en quelques
/// minutes.
///
/// Une notification **locale** est programmée sur le téléphone de l'élève au
/// moment où il s'inscrit à la séance. Elle part à l'heure dite même sans
/// réseau, ce qui est exactement le cas qu'on veut couvrir : la coupure de
/// la veille au soir ne doit pas faire manquer le cours du lendemain.
///
/// Ce que cela ne fait pas : prévenir quelqu'un qui n'a pas l'application,
/// ou qui ne s'est pas encore inscrit. Pour cela il faudra un envoi serveur,
/// et c'est une infrastructure à part — `payments` et `video` attendent déjà
/// leurs secrets, on n'en ajoute pas un troisième en silence.
///
/// --- Pourquoi une heure ---------------------------------------------------
///
/// C'est le délai qui laisse le temps de rentrer, de brancher le téléphone et
/// de trouver un coin calme. Un rappel au moment du début arrive trop tard
/// pour agir ; un rappel la veille est oublié.
class RappelSeance {
  RappelSeance(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _canal = AndroidNotificationChannel(
    'seances',
    'Cours en direct',
    description: 'Le rappel d’un cours, une heure avant qu’il commence.',
    importance: Importance.high,
  );

  /// Une heure avant, et c'est la seule valeur du fichier.
  static const avance = Duration(hours: 1);

  bool _pret = false;

  /// Prépare le plugin. Idempotent : appelable à chaque démarrage.
  Future<void> preparer() async {
    if (_pret) return;
    try {
      tz.initializeTimeZones();

      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_canal);

      _pret = true;
    } catch (erreur) {
      /*
       * Un rappel qui ne se programme pas ne doit pas empecher d'ouvrir
       * l'application.
       *
       * Sur un telephone sans services Google, ou quand l'utilisateur a
       * refuse les notifications, l'initialisation leve. C'est ennuyeux ;
       * ce n'est pas une raison pour un ecran noir au demarrage.
       */
      debugPrint('Rappels indisponibles : $erreur');
      _pret = false;
    }
  }

  /// Demande l'autorisation, et dit si elle est accordée.
  ///
  /// Android 13 et au-delà l'exigent. On la demande au moment où elle sert —
  /// à la première inscription — et non au premier lancement, où personne ne
  /// sait encore pourquoi on la réclame.
  Future<bool> demanderLAutorisation() async {
    if (!_pret) await preparer();
    if (!_pret) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    } catch (erreur) {
      debugPrint('Autorisation refusee ou indisponible : $erreur');
      return false;
    }
  }

  /// L'identifiant de notification d'une séance.
  ///
  /// Déduit de l'identifiant de la séance et non tiré au hasard : reprogrammer
  /// le même rappel doit **remplacer** le précédent, pas en empiler un second.
  /// Une famille qui change d'avis deux fois recevrait sinon trois rappels.
  static int idPour(String sessionId) => sessionId.hashCode & 0x7fffffff;

  /// Programme le rappel d'une séance.
  ///
  /// Ne fait rien si l'heure du rappel est déjà passée : programmer dans le
  /// passé déclenche immédiatement sur certains téléphones, et recevoir
  /// « votre cours commence dans une heure » pour un cours d'hier use la
  /// confiance qu'on met dans les rappels suivants.
  Future<bool> programmer({
    required String sessionId,
    required String titre,
    required DateTime debut,
    DateTime? maintenant,
  }) async {
    if (!_pret) await preparer();
    if (!_pret) return false;

    final quand = debut.subtract(avance);
    final reference = maintenant ?? DateTime.now();
    if (!quand.isAfter(reference)) return false;

    try {
      await _plugin.zonedSchedule(
        idPour(sessionId),
        'Votre cours commence dans une heure',
        titre,
        tz.TZDateTime.from(quand, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'seances',
            'Cours en direct',
            channelDescription:
                'Le rappel d’un cours, une heure avant qu’il commence.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Le rappel est une heure absolue, pas une heure du mur : un vol
        // vers un autre fuseau ne doit pas le decaler.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (erreur) {
      debugPrint('Rappel non programme pour $sessionId : $erreur');
      return false;
    }
  }

  /// Retire le rappel d'une séance — annulation, désinscription.
  Future<void> annuler(String sessionId) async {
    if (!_pret) return;
    try {
      await _plugin.cancel(idPour(sessionId));
    } catch (erreur) {
      debugPrint('Rappel non annule pour $sessionId : $erreur');
    }
  }
}
