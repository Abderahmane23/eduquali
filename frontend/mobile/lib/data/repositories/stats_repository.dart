import 'package:drift/drift.dart';

import '../local/database/app_database.dart';

/// Un chiffre qui mérite sa place sur un tableau de bord.
///
/// Le critère : il change une décision. Tout le reste est de la décoration
/// qui coûte de l'attention.
class Stat {
  const Stat({required this.value, required this.label, this.hint});

  /// Ce qu'on lit de loin.
  final String value;

  /// Ce que c'est, en deux ou trois mots.
  final String label;

  /// Une précision courte, quand le chiffre seul se lit de travers.
  final String? hint;
}

/// Ce que le professeur regarde pour décider de sa charge de travail.
class TeacherStats {
  const TeacherStats({
    required this.monthlyIncome,
    required this.nextPaymentAmount,
    required this.nextPaymentOn,
    required this.hoursThisWeek,
    required this.profileViews,
    required this.lessonsGiven,
    required this.activeStudents,
    required this.videoSalesThisMonth,
    required this.videoSalesLastMonth,
    required this.lessonsThisMonth,
    required this.lessonsLastMonth,
    required this.pendingIncome,
  });

  /// Net encaissé ce mois : échéances réglées + ventes de cours, commission
  /// déduite.
  final int monthlyIncome;

  final int nextPaymentAmount;
  final DateTime? nextPaymentOn;

  /// Heures de cours à domicile prévues d'ici sept jours.
  final int hoursThisWeek;

  /// Combien de fois sa fiche a été ouverte. C'est ce qui dit si le boost
  /// a servi.
  final int profileViews;

  /// Séances effectivement faites, depuis toujours.
  final int lessonsGiven;

  /// Élèves distincts avec une demande acceptée en cours.
  ///
  /// Distincts : un enfant qui prend trois matières est un élève, pas trois.
  final int activeStudents;

  /// Cours vidéo vendus ce mois, et le mois d'avant.
  final int videoSalesThisMonth;
  final int videoSalesLastMonth;

  /// Séances faites ce mois, et le mois d'avant.
  final int lessonsThisMonth;
  final int lessonsLastMonth;

  /// Ce qui reste à encaisser : échéances dues et non réglées.
  final int pendingIncome;

  /// L'écart d'un mois sur l'autre, ou `null` quand il n'y a pas de mois
  /// précédent à comparer. « +0 » ferait croire à une stagnation mesurée.
  static String? delta(int now, int before) {
    if (now == before) return null;
    final ecart = now - before;
    return ecart > 0 ? '+$ecart' : '$ecart';
  }
}

/// Une journée de revenus, pour la barre d'un jour.
class DailyIncome {
  const DailyIncome({
    required this.day,
    required this.tutoring,
    required this.videos,
  });

  final DateTime day;

  /// Ce qui vient des cours à domicile, et ce qui vient des ventes vidéo.
  /// Deux sources, deux couleurs : elles ne se pilotent pas pareil.
  final int tutoring;
  final int videos;

  int get total => tutoring + videos;
}

/// Ce que l'établissement regarde pour décider de son recrutement.
class InstitutionStats {
  const InstitutionStats({
    required this.filled,
    required this.pending,
    required this.monthlyCost,
    required this.averageHiringDays,
    required this.promotionViews,
  });

  final int filled;
  final int pending;

  /// Ce que coûtent les contrats en cours, chaque mois.
  final int monthlyCost;

  /// Délai moyen entre la création d'un contrat et son démarrage.
  ///
  /// Personne ne le mesure, et c'est lui qui dit le plus : trente jours sans
  /// démarrage signifie que les exigences sont hors marché.
  final int? averageHiringDays;

  final int promotionViews;
}

/// Ce que la famille regarde pour décider de son budget.
class FamilyStats {
  const FamilyStats({
    required this.monthlyCost,
    required this.nextPaymentAmount,
    required this.nextPaymentOn,
    required this.sessionsDone,
    required this.sessionsPlanned,
  });

  /// Ce que coûtent tous les soutiens réunis, chaque mois.
  final int monthlyCost;

  final int nextPaymentAmount;
  final DateTime? nextPaymentOn;

  /// Séances réellement faites ce mois, et celles qui étaient prévues.
  ///
  /// Un parent qui paie 150 000 GNF veut savoir si le professeur est venu.
  final int sessionsDone;
  final int sessionsPlanned;
}

/// Les chiffres des trois tableaux de bord.
///
/// Tout se calcule en SQL sur la base locale : aucun serveur, donc aucun
/// écran qui attend un réseau pour afficher un nombre.
class StatsRepository {
  StatsRepository(this._db);

  final AppDatabase _db;

  static DateTime _monthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  Future<TeacherStats> ofTeacher(String teacherId) async {
    final start = _monthStart();

    final row = await _db
        .customSelect(
          '''
      SELECT
        (SELECT COALESCE(SUM(p.amount), 0)
           FROM contract_payments p
           JOIN work_contracts c ON c.id = p.contract_id
          WHERE c.teacher_id = ?1 AND p.status = 'PAID'
            AND p.paid_at >= ?2)                               AS encaisse,
        (SELECT COALESCE(SUM(cp.amount - cp.commission), 0)
           FROM course_purchases cp
           JOIN video_courses v ON v.id = cp.course_id
          WHERE v.teacher_id = ?1 AND cp.created_at >= ?2)     AS ventes,
        (SELECT COALESCE(SUM(s.duration_minutes), 0)
           FROM tutoring_sessions s
           JOIN tutoring_requests r ON r.id = s.request_id
           JOIN tutoring_services sv ON sv.id = r.service_id
          WHERE sv.teacher_id = ?1 AND s.status = 'PLANNED'
            AND s.starts_at BETWEEN ?3 AND ?4)                 AS minutes,
        (SELECT COALESCE(profile_views, 0) FROM teachers
          WHERE id = ?1)                                       AS vues,
        (SELECT COUNT(*)
           FROM tutoring_sessions s
           JOIN tutoring_requests r ON r.id = s.request_id
           JOIN tutoring_services sv ON sv.id = r.service_id
          WHERE sv.teacher_id = ?1 AND s.status = 'DONE')      AS donnes,
        (SELECT COUNT(DISTINCT r.child_id)
           FROM tutoring_requests r
           JOIN tutoring_services sv ON sv.id = r.service_id
          WHERE sv.teacher_id = ?1 AND r.status = 'ACCEPTED')  AS eleves,
        (SELECT COUNT(*)
           FROM course_purchases cp
           JOIN video_courses v ON v.id = cp.course_id
          WHERE v.teacher_id = ?1 AND cp.created_at >= ?2)     AS ventes_mois,
        (SELECT COUNT(*)
           FROM course_purchases cp
           JOIN video_courses v ON v.id = cp.course_id
          WHERE v.teacher_id = ?1 AND cp.created_at >= ?5
            AND cp.created_at < ?2)                            AS ventes_avant,
        (SELECT COUNT(*)
           FROM tutoring_sessions s
           JOIN tutoring_requests r ON r.id = s.request_id
           JOIN tutoring_services sv ON sv.id = r.service_id
          WHERE sv.teacher_id = ?1 AND s.status = 'DONE'
            AND s.starts_at >= ?2)                             AS faites_mois,
        (SELECT COUNT(*)
           FROM tutoring_sessions s
           JOIN tutoring_requests r ON r.id = s.request_id
           JOIN tutoring_services sv ON sv.id = r.service_id
          WHERE sv.teacher_id = ?1 AND s.status = 'DONE'
            AND s.starts_at >= ?5 AND s.starts_at < ?2)        AS faites_avant,
        (SELECT COALESCE(SUM(p.amount), 0)
           FROM contract_payments p
           JOIN work_contracts c ON c.id = p.contract_id
          WHERE c.teacher_id = ?1 AND p.status != 'PAID')      AS attendu
      ''',
          variables: [
            Variable<String>(teacherId),
            Variable<DateTime>(start),
            Variable<DateTime>(DateTime.now()),
            Variable<DateTime>(DateTime.now().add(const Duration(days: 7))),
            Variable<DateTime>(DateTime(start.year, start.month - 1)),
          ],
          readsFrom: {
            _db.contractPayments,
            _db.workContracts,
            _db.coursePurchases,
            _db.videoCourses,
            _db.tutoringSessions,
            _db.tutoringRequests,
            _db.tutoringServices,
            _db.teachers,
          },
        )
        .getSingle();

    final next = await _nextPayment('c.teacher_id = ?1', teacherId);

    return TeacherStats(
      monthlyIncome: row.read<int>('encaisse') + row.read<int>('ventes'),
      nextPaymentAmount: next?.$1 ?? 0,
      nextPaymentOn: next?.$2,
      // Arrondi à l'heure pleine : « 7 h » se lit, « 7,5 h » se calcule.
      hoursThisWeek: (row.read<int>('minutes') / 60).round(),
      profileViews: row.read<int>('vues'),
      lessonsGiven: row.read<int>('donnes'),
      activeStudents: row.read<int>('eleves'),
      videoSalesThisMonth: row.read<int>('ventes_mois'),
      videoSalesLastMonth: row.read<int>('ventes_avant'),
      lessonsThisMonth: row.read<int>('faites_mois'),
      lessonsLastMonth: row.read<int>('faites_avant'),
      pendingIncome: row.read<int>('attendu'),
    );
  }

  Future<InstitutionStats> ofInstitution(String institutionId) async {
    final row = await _db
        .customSelect(
          '''
      SELECT
        (SELECT COUNT(*) FROM work_contracts
          WHERE institution_id = ?1 AND status = 'ACTIVE')     AS pourvus,
        (SELECT COUNT(*) FROM work_contracts
          WHERE institution_id = ?1 AND status = 'PENDING')    AS attente,
        (SELECT COALESCE(SUM(monthly_amount), 0) FROM work_contracts
          WHERE institution_id = ?1 AND status = 'ACTIVE')     AS cout,
        (SELECT COALESCE(SUM(views), 0) FROM promotions
          WHERE institution_id = ?1)                           AS vues,
        (SELECT AVG(julianday(started_at) - julianday(created_at))
           FROM work_contracts
          WHERE institution_id = ?1 AND started_at IS NOT NULL) AS delai
      ''',
          variables: [Variable<String>(institutionId)],
          readsFrom: {_db.workContracts, _db.promotions},
        )
        .getSingle();

    final delai = row.read<double?>('delai');
    return InstitutionStats(
      filled: row.read<int>('pourvus'),
      pending: row.read<int>('attente'),
      monthlyCost: row.read<int>('cout'),
      averageHiringDays: delai?.round(),
      promotionViews: row.read<int>('vues'),
    );
  }

  Future<FamilyStats> ofParent(String parentId) async {
    final start = _monthStart();
    final end = DateTime(start.year, start.month + 1);

    final row = await _db
        .customSelect(
          '''
      SELECT
        (SELECT COALESCE(SUM(monthly_amount), 0) FROM work_contracts
          WHERE parent_id = ?1 AND status = 'ACTIVE')          AS cout,
        (SELECT COUNT(*)
           FROM tutoring_sessions s
           JOIN tutoring_requests r ON r.id = s.request_id
          WHERE r.parent_id = ?1 AND s.status = 'DONE'
            AND s.starts_at BETWEEN ?2 AND ?3)                 AS faites,
        (SELECT COUNT(*)
           FROM tutoring_sessions s
           JOIN tutoring_requests r ON r.id = s.request_id
          WHERE r.parent_id = ?1 AND s.status != 'CANCELLED'
            AND s.starts_at BETWEEN ?2 AND ?3)                 AS prevues
      ''',
          variables: [
            Variable<String>(parentId),
            Variable<DateTime>(start),
            Variable<DateTime>(end),
          ],
          readsFrom: {
            _db.workContracts,
            _db.tutoringSessions,
            _db.tutoringRequests,
          },
        )
        .getSingle();

    final next = await _nextPayment('c.parent_id = ?1', parentId);

    return FamilyStats(
      monthlyCost: row.read<int>('cout'),
      nextPaymentAmount: next?.$1 ?? 0,
      nextPaymentOn: next?.$2,
      sessionsDone: row.read<int>('faites'),
      sessionsPlanned: row.read<int>('prevues'),
    );
  }

  /// La prochaine échéance non réglée : montant et date.
  Future<(int, DateTime)?> _nextPayment(String where, String value) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT p.amount, p.due_on
      FROM contract_payments p
      JOIN work_contracts c ON c.id = p.contract_id
      WHERE $where AND p.status != 'PAID'
      ORDER BY p.due_on ASC LIMIT 1
      ''',
          variables: [Variable<String>(value)],
          readsFrom: {_db.contractPayments, _db.workContracts},
        )
        .get();

    if (rows.isEmpty) return null;
    return (
      rows.first.read<int>('amount'),
      rows.first.read<DateTime>('due_on'),
    );
  }

  /// Ce qui est rentré chaque jour, sur les sept derniers.
  ///
  /// Deux sources séparées — cours à domicile et ventes vidéo — parce qu'un
  /// professeur qui voit ses deux courbes décide autrement : l'une se
  /// remplit en se déplaçant, l'autre pendant qu'il dort.
  ///
  /// Les jours sans rien gardent leur barre à zéro : sauter un jour vide
  /// ferait croire à une semaine de six jours.
  Future<List<DailyIncome>> weeklyIncome(String teacherId) async {
    final today = DateTime.now();
    final from = DateTime(today.year, today.month, today.day - 6);

    final rows = await _db
        .customSelect(
          '''
      SELECT date(p.paid_at / 1000, 'unixepoch', 'localtime') AS jour,
             SUM(p.amount) AS montant, 'T' AS source
        FROM contract_payments p
        JOIN work_contracts c ON c.id = p.contract_id
       WHERE c.teacher_id = ?1 AND p.status = 'PAID' AND p.paid_at >= ?2
       GROUP BY jour
      UNION ALL
      SELECT date(cp.created_at / 1000, 'unixepoch', 'localtime') AS jour,
             SUM(cp.amount - cp.commission) AS montant, 'V' AS source
        FROM course_purchases cp
        JOIN video_courses v ON v.id = cp.course_id
       WHERE v.teacher_id = ?1 AND cp.created_at >= ?2
       GROUP BY jour
      ''',
          variables: [Variable<String>(teacherId), Variable<DateTime>(from)],
          readsFrom: {
            _db.contractPayments,
            _db.workContracts,
            _db.coursePurchases,
            _db.videoCourses,
          },
        )
        .get();

    final domicile = <String, int>{};
    final videos = <String, int>{};
    for (final row in rows) {
      final jour = row.read<String>('jour');
      final montant = row.read<int?>('montant') ?? 0;
      (row.read<String>('source') == 'T' ? domicile : videos)[jour] = montant;
    }

    String cle(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    return [
      for (var i = 0; i < 7; i++)
        if (DateTime(from.year, from.month, from.day + i) case final jour)
          DailyIncome(
            day: jour,
            tutoring: domicile[cle(jour)] ?? 0,
            videos: videos[cle(jour)] ?? 0,
          ),
    ];
  }

  /// Une fiche de plus consultée.
  ///
  /// Le professeur ne se compte pas lui-même : il ouvrirait sa propre fiche
  /// et croirait à l'effet de son boost.
  Future<void> countProfileView({
    required String teacherId,
    required String? byTeacherId,
  }) async {
    if (teacherId == byTeacherId) return;
    await _db.customStatement(
      'UPDATE teachers SET profile_views = profile_views + 1 WHERE id = ?1',
      [teacherId],
    );
  }
}
