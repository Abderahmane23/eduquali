import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Formatage des dates, montants et durees — localise en francais.
abstract final class Fmt {
  static final NumberFormat _amount = NumberFormat.decimalPattern('fr');
  static final DateFormat _date = DateFormat('d MMMM yyyy', 'fr');
  static final DateFormat _dateShort = DateFormat('dd/MM/yyyy', 'fr');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm', 'fr');
  /// « 17 h 08 ».
  ///
  /// Le francais ecrit l'heure avec un « h » entoure d'espaces, et c'est la
  /// forme que porte la charte (« AUJOURD'HUI · 17 H 00 »). Le motif etait
  /// `HH:mm` : le site affichait « 17 h 00 » et l'application « 17:00 » pour
  /// la meme seance, et deux ecritures d'une meme heure se lisent comme deux
  /// heures.
  static final DateFormat _time = DateFormat("HH 'h' mm", 'fr');

  /// « 3 000 000 GNF »
  static String money(num value, {bool withCurrency = true}) {
    final formatted = _amount.format(value);
    return withCurrency ? '$formatted ${AppConstants.currency}' : formatted;
  }

  /// Fourchette de rémunération ; renvoie `null` si rien n'est publiable.
  static String? salaryRange(int? min, int? max, {required bool published}) {
    if (!published || (min == null && max == null)) return null;
    if (min != null && max != null && min != max) {
      return '${_amount.format(min)} – ${money(max)}';
    }
    return money(min ?? max!);
  }

  static String date(DateTime d) => _date.format(d);
  static String dateShort(DateTime d) => _dateShort.format(d);

  /// « Lun », « Mar » — l'axe d'un graphique de sept jours.
  static String weekdayShort(DateTime d) =>
      const ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'][d.weekday - 1];

  /// « 320k », « 1,2 M » — un montant qui doit tenir dans une colonne de
  /// bandeau. En dessous de dix mille, le chiffre exact tient déjà.
  static String compactMoney(num value) {
    if (value.abs() >= 1000000) {
      final millions = value / 1000000;
      final texte = millions
          .toStringAsFixed(millions.abs() >= 10 ? 0 : 1)
          .replaceAll('.', ',');
      return '${texte}M';
    }
    if (value.abs() >= 10000) return '${(value / 1000).round()}k';
    return money(value, withCurrency: false);
  }

  static String dateTime(DateTime d) => _dateTime.format(d);
  static String time(DateTime d) => _time.format(d);

  /// « Publié le 20 mai 2025 »
  static String publishedOn(DateTime d) => 'Publié le ${_date.format(d)}';

  /// Durée relative compacte : « il y a 3 j », « a l'instant ».
  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'a l’instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 30) return 'il y a ${diff.inDays} j';
    if (diff.inDays < 365) return 'il y a ${(diff.inDays / 30).floor()} mois';
    return 'il y a ${(diff.inDays / 365).floor()} an(s)';
  }

  /// Chronomètre du test : « 45:30 » ou « 1:05:30 ».
  static String clock(int totalSeconds) {
    final s = totalSeconds.clamp(0, 359999);
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// « 5 ans d'experience »
  static String experience(int years) {
    if (years <= 0) return 'Débutant';
    return years == 1 ? '1 an d’experience' : '$years ans d’experience';
  }

  /// Période d'une experience professionnelle.
  static String period(DateTime start, DateTime? end) {
    final from = DateFormat('MMM yyyy', 'fr').format(start);
    final to = end == null
        ? 'aujourd’hui'
        : DateFormat('MMM yyyy', 'fr').format(end);
    return '$from – $to';
  }

  /// Initiales pour l'avatar par defaut.
  static String initials(String firstName, String lastName) {
    final a = firstName.trim().isEmpty ? '' : firstName.trim()[0];
    final b = lastName.trim().isEmpty ? '' : lastName.trim()[0];
    final res = '$a$b'.toUpperCase();
    return res.isEmpty ? '?' : res;
  }

  static String fullName(String firstName, String lastName) =>
      '$firstName $lastName'.trim();

  /// Taille de fichier lisible.
  static String bytes(int value) {
    if (value < 1024) return '$value o';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(0)} Ko';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  /// Frais de recrutement = 1 mois de salaire (§36).
  static String successFee(int monthlySalary) =>
      money((monthlySalary * AppConstants.successFeeMonths).round());
}
