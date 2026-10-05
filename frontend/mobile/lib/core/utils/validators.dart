/// Validation des saisies utilisateur.
abstract final class Validators {
  static final RegExp _digits = RegExp(r'[^0-9+]');
  static final RegExp _email = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[a-zA-Z]{2,}$');

  /// Numéro guineen : +224 suivi de 9 chiffres, ou 9 chiffres locaux.
  static String? phone(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Le numéro de téléphone est obligatoire';
    final cleaned = raw.replaceAll(_digits, '');
    final national = cleaned.startsWith('+224')
        ? cleaned.substring(4)
        : cleaned.startsWith('224') && cleaned.length > 9
        ? cleaned.substring(3)
        : cleaned;
    if (national.length != 9) {
      return 'Numéro invalide — 9 chiffres attendus (ex. 620 00 00 00)';
    }
    return null;
  }

  /// Met le numéro au format international guineen.
  static String normalizePhone(String value) {
    final cleaned = value.replaceAll(_digits, '');
    if (cleaned.startsWith('+224')) return cleaned;
    if (cleaned.startsWith('224') && cleaned.length > 9) return '+$cleaned';
    return '+224$cleaned';
  }

  static String? email(String? value, {bool required = false}) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return required ? 'L’adresse email est obligatoire' : null;
    if (!_email.hasMatch(raw)) return 'Adresse email invalide';
    return null;
  }

  static String? password(String? value) {
    final raw = value ?? '';
    if (raw.isEmpty) return 'Le mot de passe est obligatoire';
    if (raw.length < 8) return 'Au moins 8 caractères';
    if (!raw.contains(RegExp(r'[A-Za-z]')) || !raw.contains(RegExp(r'[0-9]'))) {
      return 'Doit contenir des lettres et des chiffres';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Confirmez le mot de passe';
    if (value != original) return 'Les mots de passe ne correspondent pas';
    return null;
  }

  static String? required(String? value, [String label = 'Ce champ']) {
    if ((value ?? '').trim().isEmpty) return '$label est obligatoire';
    return null;
  }

  static String? name(String? value, String label) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '$label est obligatoire';
    if (raw.length < 2) return '$label est trop court';
    return null;
  }

  static String? year(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'L’année est obligatoire';
    final parsed = int.tryParse(raw);
    final now = DateTime.now().year;
    if (parsed == null) return 'Année invalide';
    if (parsed < 1950 || parsed > now) {
      return 'Année comprise entre 1950 et $now';
    }
    return null;
  }

  static String? positiveAmount(String? value, {bool required = true}) {
    final raw = (value ?? '').trim().replaceAll(' ', '');
    if (raw.isEmpty) return required ? 'Montant obligatoire' : null;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) return 'Montant invalide';
    return null;
  }

  static String? otp(String? value, int length) {
    final raw = (value ?? '').trim();
    if (raw.length != length) return 'Code a $length chiffres';
    if (int.tryParse(raw) == null) return 'Code invalide';
    return null;
  }
}
