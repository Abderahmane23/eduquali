import 'package:drift/drift.dart';

import '../../core/constants/app_enums.dart';
import '../../domain/entities/job_models.dart';
import '../../domain/entities/teacher_profile.dart';
import '../local/database/app_database.dart';

/// Referentiel matières et niveaux (§8, §9).
///
/// Le referentiel est configurable depuis le back-office ; il est replique
/// localement pour rester consultable hors ligne (§41).
class CatalogRepository {
  CatalogRepository(this._db);

  final AppDatabase _db;

  Future<List<RefItem>> subjects() async {
    final rows =
        await (_db.select(_db.subjects)
              ..where((t) => t.active.equals(true))
              ..orderBy([
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.name),
              ]))
            .get();
    return [
      for (final r in rows)
        RefItem(id: r.id, name: r.name, code: r.code, cycles: _split(r.cycles)),
    ];
  }

  /// Les classes proposees a la saisie.
  ///
  /// Les en-tetes de cycle (« Lycee », « College ») en sont exclus par
  /// defaut : ce ne sont pas des classes, et un professeur de lycee qui voit
  /// « Lycee » a cote de « 11eme annee » ne sait pas lequel cocher. Ils
  /// restent accessibles avec [includeGroupings] pour les certifications et
  /// les offres d'emploi, qui visent bien un cycle entier.
  Future<List<RefItem>> levels({
    String? category,
    bool includeGroupings = false,
  }) async {
    final query = _db.select(_db.levels)
      ..where((t) => t.active.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    if (category != null) {
      query.where((t) => t.category.equals(category));
    }
    if (!includeGroupings) {
      query.where((t) => t.grouping.equals(false));
    }
    final rows = await query.get();
    return [
      for (final r in rows)
        RefItem(
          id: r.id,
          name: r.name,
          code: r.code,
          category: r.category,
          cycles: _split(r.cycle),
        ),
    ];
  }

  /// Niveaux groupes par categorie, pour l'affichage en sections (§9).
  Future<Map<String, List<RefItem>>> levelsByCategory() async {
    // Meme regle que [levels] : les en-tetes de cycle ne sont pas des
    // classes a cocher.
    final rows =
        await (_db.select(_db.levels)
              ..where((t) => t.active.equals(true) & t.grouping.equals(false))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();

    final grouped = <String, List<RefItem>>{};
    for (final r in rows) {
      grouped
          .putIfAbsent(r.category, () => [])
          .add(
            RefItem(
              id: r.id,
              name: r.name,
              code: r.code,
              cycles: _split(r.cycle),
            ),
          );
    }
    return grouped;
  }

  Future<RefItem?> subject(String id) async {
    final row = await (_db.select(
      _db.subjects,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null
        ? null
        : RefItem(id: row.id, name: row.name, code: row.code);
  }

  Future<RefItem?> level(String id) async {
    final row = await (_db.select(
      _db.levels,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null
        ? null
        : RefItem(id: row.id, name: row.name, code: row.code);
  }

  /// Résolution par lot — evite les requetes repetees lors du rendu de listes.
  Future<Map<String, RefItem>> subjectMap() async {
    final rows = await _db.select(_db.subjects).get();
    return {
      for (final r in rows) r.id: RefItem(id: r.id, name: r.name, code: r.code),
    };
  }

  Future<Map<String, RefItem>> levelMap() async {
    final rows = await _db.select(_db.levels).get();
    return {
      for (final r in rows) r.id: RefItem(id: r.id, name: r.name, code: r.code),
    };
  }

  /// Villes reellement presentes dans les offres et les profils.
  Future<List<String>> cities() async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT city FROM jobs WHERE city IS NOT NULL '
          'UNION SELECT DISTINCT city FROM teachers WHERE city IS NOT NULL '
          'ORDER BY city',
        )
        .get();
    return [for (final row in rows) ?row.read<String?>('city')];
  }

  /// Les trois profils du second cycle, dans l'ordre du programme.
  Future<List<FiliereRow>> filieres() => (_db.select(
    _db.filieres,
  )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  /// Établissements connus, pour les listes de saisie assistee.
  ///
  /// Sert notamment a rattacher une experience passee a un établissement déjà
  /// référence plutot qu'a une saisie libre (§15).
  Future<List<RefItem>> institutions() async {
    final rows = await (_db.select(
      _db.institutions,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
    return [for (final row in rows) RefItem(id: row.id, name: row.name)];
  }

  /// Fiches completes des etablissements, pour la consultation (§19).
  Future<List<InstitutionSummary>> institutionProfiles({
    String? city,
    InstitutionType? type,
  }) async {
    final query = _db.select(_db.institutions)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (city != null) query.where((t) => t.city.equals(city));
    if (type != null) query.where((t) => t.type.equals(type.code));
    final rows = await query.get();
    return [for (final row in rows) _toSummary(row)];
  }

  Future<InstitutionSummary?> institutionById(String id) async {
    final row = await (_db.select(
      _db.institutions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toSummary(row);
  }

  InstitutionSummary _toSummary(InstitutionRow row) => InstitutionSummary(
    id: row.id,
    name: row.name,
    type: InstitutionType.fromCode(row.type),
    city: row.city,
    logoPath: row.logoPath,
    description: row.description,
    address: row.address,
    managerName: row.managerName,
    verificationStatus: VerificationStatus.fromCode(row.verificationStatus),
    phone: row.phone,
    phoneAlt: row.phoneAlt,
    email: row.email,
    website: row.website,
    foundedYear: row.foundedYear,
    ownership: row.ownership,
    academicSystem: row.academicSystem,
    degrees: InstitutionSummary.splitList(row.degrees),
    specialties: InstitutionSummary.splitList(row.specialties),
    facilities: InstitutionSummary.splitList(row.facilities),
  );

  /// Categories de niveaux, dans l'ordre d'affichage.
  static const categoryLabels = {
    'PRIMARY': 'Primaire',
    'SECONDARY': 'Scolaire',
    'UNIVERSITY': 'Universitaire',
  };

  /// Liste stockée en colonne unique, séparée par des virgules.
  static List<String> _split(String raw) => [
    for (final part in raw.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}
