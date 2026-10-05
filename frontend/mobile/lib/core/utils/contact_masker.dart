/// Protection contre le contournement de la plateforme (§30).
///
/// Avant le recrutement, les coordonnées personnelles echangees dans la
/// messagerie sont masquees. La strategie ne repose pas uniquement sur ce
/// filtre : la plateforme reste utile pendant tout le recrutement.
class MaskResult {
  const MaskResult({required this.text, required this.masked});

  final String text;
  final bool masked;
}

abstract final class ContactMasker {
  /// Suites de chiffres pouvant constituer un numéro (avec separateurs).
  static final RegExp _phone = RegExp(r'(?:\+?\d[\s.\-]?){8,}');

  static final RegExp _email = RegExp(
    r'[\w.\-+]+\s*(?:@|\(at\)|\[at\])\s*[\w\-]+\s*(?:\.|\(dot\))\s*[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  static final RegExp _url = RegExp(
    r'(?:https?://|www\.)\S+',
    caseSensitive: false,
  );

  /// Mentions de messageries externes et invitations a sortir du canal.
  static final RegExp _externalApp = RegExp(
    r'\b(whatsapp|whats\s?app|telegram|viber|signal|imo|messenger|facebook|instagram|skype|zoom\s?id)\b',
    caseSensitive: false,
  );

  /// Chiffres écrits en toutes lettres, utilises pour contourner le filtre.
  static final RegExp _spelledDigits = RegExp(
    r'\b(?:(?:zéro|un|deux|trois|quatre|cinq|six|sept|huit|neuf)[\s\-]+){6,}',
    caseSensitive: false,
  );

  static const String _redaction = '[coordonnées masquees]';

  /// Masque les coordonnées d'un message tant que le recrutement n'est pas
  /// conclu. [unlocked] passe a `true` une fois le contrat signe (§30).
  static MaskResult mask(String input, {required bool unlocked}) {
    if (unlocked) return MaskResult(text: input, masked: false);

    var output = input;
    var masked = false;

    for (final pattern in [_email, _url, _phone, _spelledDigits]) {
      if (pattern.hasMatch(output)) {
        masked = true;
        output = output.replaceAll(pattern, _redaction);
      }
    }

    if (_externalApp.hasMatch(output)) {
      masked = true;
      output = output.replaceAll(_externalApp, '[application externe]');
    }

    return MaskResult(text: output, masked: masked);
  }

  /// Detecte une tentative de partage de coordonnées, sans transformer le
  /// texte — utile pour avertir l'auteur avant l'envoi.
  static bool containsContactDetails(String input) =>
      _email.hasMatch(input) ||
      _url.hasMatch(input) ||
      _phone.hasMatch(input) ||
      _externalApp.hasMatch(input) ||
      _spelledDigits.hasMatch(input);

  /// Masque un numéro pour un affichage partiel : « +224 6•• •• •• 07 ».
  static String maskPhone(String phone) {
    if (phone.length < 6) return '••••••';
    final visibleStart = phone.substring(0, phone.length >= 8 ? 6 : 3);
    final visibleEnd = phone.substring(phone.length - 2);
    return '$visibleStart•• •• $visibleEnd';
  }

  static String maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return '•••';
    return '${email[0]}•••${email.substring(at)}';
  }
}
