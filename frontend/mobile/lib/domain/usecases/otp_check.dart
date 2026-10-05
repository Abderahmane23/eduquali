/// Issue de la vérification d'un code OTP (§5.1).
enum OtpOutcome {
  /// Le code envoyé correspond et n'a pas expiré.
  accepted,

  /// Le code unique hors ligne a été accepté, faute de serveur joignable.
  acceptedOffline,

  /// Aucun code n'a été émis pour ce compte.
  noPending,

  /// Le code émis a dépassé sa durée de validité.
  expired,

  /// Le code saisi ne correspond pas.
  wrong;

  bool get opensSession => this == accepted || this == acceptedOffline;
}

/// Décide si un code saisi ouvre la session.
///
/// Fonction pure : elle ne lit ni base, ni réseau, ni horloge. C'est ce qui
/// permet de tester chaque cas — dont la règle la plus sensible, « le code
/// unique ne passe jamais quand le serveur répond » — sans infrastructure.
///
/// Ordre des contrôles : le code hors ligne est examiné en premier, parce
/// qu'hors ligne il doit passer même sans code en attente ou avec un code
/// expiré — c'est précisément la situation qui bloquait les testeurs.
OtpOutcome checkOtp({
  required String entered,
  required String? expected,
  required DateTime? issuedAt,
  required DateTime now,
  required Duration validity,
  required bool offlineCodeEnabled,
  required String offlineCode,
  required bool serverReachable,
}) {
  final code = entered.trim();

  // Le code unique n'existe que tant qu'aucun SMS ne peut partir. Serveur
  // joignable = vrai code obligatoire, même si le drapeau est resté actif.
  if (offlineCodeEnabled && !serverReachable && code == offlineCode) {
    return OtpOutcome.acceptedOffline;
  }

  if (expected == null || issuedAt == null) return OtpOutcome.noPending;
  if (now.difference(issuedAt) > validity) return OtpOutcome.expired;
  if (code != expected) return OtpOutcome.wrong;
  return OtpOutcome.accepted;
}
