import '../../core/utils/formatters.dart';
import '../entities/job_models.dart';
import '../entities/recruitment_models.dart';
import '../entities/teacher_profile.dart';

/// Generation du contrat a partir d'un modèle (§27).
///
/// Le document reprend l'établissement, l'enseignant, le poste, la
/// rémunération, la durée, la date de début et les conditions applicables.
abstract final class ContractBuilder {
  /// Référence lisible et stable : VP-2026-0042.
  static String reference(DateTime date, String roomId) {
    final suffix = roomId.replaceAll(RegExp('[^0-9a-fA-F]'), '');
    final short = suffix.length >= 4
        ? suffix.substring(suffix.length - 4).toUpperCase()
        : suffix.toUpperCase().padLeft(4, '0');
    return 'VP-${date.year}-$short';
  }

  static String build({
    required String reference,
    required InstitutionSummary institution,
    required TeacherProfile teacher,
    required OfferItem offer,
    required JobOffer job,
    required DateTime issuedAt,
  }) {
    final buffer = StringBuffer()
      ..writeln('CONTRAT DE TRAVAIL')
      ..writeln('Référence : $reference')
      ..writeln('Etabli le ${Fmt.date(issuedAt)}')
      ..writeln()
      ..writeln('ENTRE LES SOUSSIGNES')
      ..writeln()
      ..writeln('L’établissement :')
      ..writeln('  ${institution.name}')
      ..writeln('  ${institution.type.label}')
      ..writeln(
        '  ${institution.address ?? institution.city}, ${institution.city}',
      )
      ..writeln('  ci-après denomme « l’Employeur »')
      ..writeln()
      ..writeln('ET')
      ..writeln()
      ..writeln('L’enseignant :')
      ..writeln('  ${teacher.fullName}')
      ..writeln('  ${teacher.city ?? "Guinée"}')
      ..writeln('  ci-après denomme « l’Enseignant »')
      ..writeln()
      ..writeln('IL A ETE CONVENU CE QUI SUIT')
      ..writeln()
      ..writeln('ARTICLE 1 — OBJET')
      ..writeln(
        'L’Employeur engage l’Enseignant en qualite de ${offer.position}, '
        'pour l’enseignement de la matière ${job.subject.name} '
        'au(x) niveau(x) ${job.levelLabel}.',
      )
      ..writeln()
      ..writeln('ARTICLE 2 — NATURE DU CONTRAT')
      ..writeln(
        'Le présent contrat est conclu sous la forme : ${offer.contractType.label}.',
      );

    if (offer.durationMonths != null) {
      buffer.writeln('Sa durée est fixee a ${offer.durationMonths} mois.');
    }

    buffer
      ..writeln()
      ..writeln('ARTICLE 3 — PRISE DE FONCTION')
      ..writeln(
        'L’Enseignant prendra ses fonctions le ${Fmt.date(offer.startDate)}.',
      );

    if (offer.trialPeriodDays != null) {
      buffer.writeln(
        'Une période d’essai de ${offer.trialPeriodDays} jours est prevue, '
        'durant laquelle chacune des parties peut mettre fin au contrat dans '
        'les conditions prevues par la reglementation applicable.',
      );
    }

    buffer
      ..writeln()
      ..writeln('ARTICLE 4 — REMUNERATION')
      ..writeln(
        'La rémunération mensuelle brute est fixee a '
        '${Fmt.money(offer.monthlySalary)}, payable selon les modalites en '
        'vigueur au sein de l’établissement.',
      )
      ..writeln()
      ..writeln('ARTICLE 5 — HORAIRES ET LIEU DE TRAVAIL');

    buffer.writeln(
      offer.schedule == null
          ? 'Les horaires sont fixes par l’Employeur selon les besoins '
                'pedagogiques de l’établissement.'
          : 'Horaires convenus : ${offer.schedule}.',
    );
    buffer.writeln('Le lieu principal d’exercice est situe a ${job.city}.');

    if (offer.extraConditions != null) {
      buffer
        ..writeln()
        ..writeln('ARTICLE 6 — CONDITIONS PARTICULIERES')
        ..writeln(offer.extraConditions!);
    }

    final nextArticle = offer.extraConditions != null ? 7 : 6;

    buffer
      ..writeln()
      ..writeln('ARTICLE $nextArticle — OBLIGATIONS DE L’ENSEIGNANT')
      ..writeln(
        'L’Enseignant s’engage a assurer les enseignements confies, a '
        'respecter le reglement interieur de l’établissement, ainsi qu’a '
        'participer aux activites pedagogiques associees a sa fonction '
        '(préparation, évaluation, jurys et reunions).',
      )
      ..writeln()
      ..writeln('ARTICLE ${nextArticle + 1} — QUALIFICATIONS VERIFIEES')
      ..writeln(
        'Les éléments suivants ont ete vérifiés par la plateforme '
        'prealablement a la signature :',
      );

    for (final badge in teacher.badges) {
      buffer.writeln('  - ${badge.label}');
    }
    for (final certification in teacher.certifications) {
      buffer.writeln(
        '  - Compétence évaluée : ${certification.title} — '
        '${certification.score} %',
      );
    }

    buffer
      ..writeln()
      ..writeln('ARTICLE ${nextArticle + 2} — DROIT APPLICABLE')
      ..writeln(
        'Le présent contrat est regi par la legislation du travail applicable '
        'en Republique de Guinée. Tout differend releve des juridictions '
        'competentes.',
      )
      ..writeln()
      ..writeln('SIGNATURES')
      ..writeln()
      ..writeln(
        'Pour l’Employeur : ${institution.managerName ?? institution.name}',
      )
      ..writeln('L’Enseignant : ${teacher.fullName}')
      ..writeln()
      ..writeln(
        'Document genere par la plateforme a partir des conditions acceptees '
        'par les deux parties. La valeur juridique de la signature '
        'electronique doit etre appreciee au regard du cadre applicable.',
      );

    return buffer.toString();
  }
}
