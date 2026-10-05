import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../../domain/usecases/tutoring_rules.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';
import 'conversations_repository.dart';
import 'tutoring_sessions_repository.dart';

/// Offre de cours à domicile, prête à afficher.
class TutoringOffer {
  const TutoringOffer({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.subjectId,
    required this.subjectName,
    required this.levelNames,
    required this.mode,
    required this.active,
    this.hourlyRate,
    this.city,
    this.districts = const [],
    this.availabilityNote,
    this.description,
  });

  final String id;
  final String teacherId;
  final String teacherName;
  final String subjectId;
  final String subjectName;
  final List<String> levelNames;
  final TutoringMode mode;
  final bool active;
  final int? hourlyRate;
  final String? city;
  final List<String> districts;
  final String? availabilityNote;
  final String? description;
}

/// Demande de cours, vue par le parent ou par le professeur.
class TutoringRequestItem {
  const TutoringRequestItem({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.offer,
    required this.parentName,
    this.childName,
    this.childLevel,
    this.parentDistrict,
    this.message,
    this.preferredStart,
    this.respondedAt,
  });

  final String id;
  final TutoringStatus status;
  final DateTime createdAt;
  final TutoringOffer offer;
  final String parentName;
  final String? childName;
  final String? childLevel;
  final String? parentDistrict;
  final String? message;
  final DateTime? preferredStart;
  final DateTime? respondedAt;
}

class TutoringException implements Exception {
  const TutoringException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Cours à domicile : offres des professeurs, demandes des parents.
///
/// Seul point d'accès aux tables `tutoring_services` et `tutoring_requests`.
/// Chaque changement de statut passe par `canSetTutoringStatus` : aucun écran
/// ne peut faire accepter une demande par un parent, ni rouvrir un refus.
class TutoringRepository {
  TutoringRepository(this._db, this._sync);

  final AppDatabase _db;
  final SyncEngine _sync;
  static const _uuid = Uuid();

  // --- Disponibilité pour les cours à domicile --------------------------

  /// Jours et moments déclarés par l'enseignant.
  Future<({Set<Weekday> days, Set<DaySlot> slots})> availabilityOf(
    String teacherId,
  ) async {
    final row = await (_db.select(
      _db.teachers,
    )..where((t) => t.id.equals(teacherId))).getSingleOrNull();
    if (row == null) return (days: <Weekday>{}, slots: <DaySlot>{});

    return (
      days: {
        for (final code in _split(row.tutoringDays)) ?Weekday.fromCode(code),
      },
      slots: {
        for (final code in _split(row.tutoringSlots)) ?DaySlot.fromCode(code),
      },
    );
  }

  /// Enregistre la disponibilité. Refuse en dessous du minimum : une offre
  /// publiée sans créneaux ferait réserver une famille à l'aveugle.
  Future<void> saveAvailability({
    required String teacherId,
    required Set<Weekday> days,
    required Set<DaySlot> slots,
  }) async {
    final problem = tutoringAvailabilityProblem(days: days, slots: slots);
    if (problem != null) throw TutoringException(problem);

    await (_db.update(
      _db.teachers,
    )..where((t) => t.id.equals(teacherId))).write(
      TeachersCompanion(
        tutoringDays: Value([for (final d in days) d.code].join(',')),
        tutoringSlots: Value([for (final s in slots) s.code].join(',')),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );

    // Les clés sont celles des colonnes, en minuscules à souligné.
    //
    // Le serveur ne retient d'une charge utile que les clés qui **portent le
    // nom exact** d'une colonne autorisée (`planWrite`) ; tout le reste est
    // écarté, et une charge dont rien ne subsiste est refusée. Cet envoi
    // partait avec `days` et `slots` vers une entité
    // `teacher_tutoring_availability` dont la table n'a jamais été créée : il
    // échouait deux fois, d'abord sur les clés puis sur la relation absente.
    await _sync.enqueue(
      entity: 'teacher_availability',
      entityId: teacherId,
      operation: SyncOperation.update,
      payload: {
        'tutoring_days': [for (final d in days) d.code].join(','),
        'tutoring_slots': [for (final s in slots) s.code].join(','),
      },
    );
  }

  static List<String> _split(String raw) => [
    for (final part in raw.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  // --- Offres -----------------------------------------------------------

  /// Publie une offre de cours.
  Future<String> publishOffer({
    required String teacherId,
    required String subjectId,
    required List<String> levelIds,
    required TutoringMode mode,
    required int hourlyRate,
    required String city,
    List<String> districts = const [],
    String? availabilityNote,
    String? description,
  }) async {
    if (levelIds.isEmpty) {
      throw const TutoringException('Choisissez au moins une classe.');
    }
    if (hourlyRate <= 0) {
      throw const TutoringException('Indiquez un tarif horaire.');
    }

    // Sans disponibilité, l'offre serait invisible pour ce qui compte le
    // plus à une famille : quand le professeur peut venir.
    final availability = await availabilityOf(teacherId);
    final problem = tutoringAvailabilityProblem(
      days: availability.days,
      slots: availability.slots,
    );
    if (problem != null) {
      throw TutoringException('Indiquez d’abord vos disponibilités. $problem');
    }

    final id = _uuid.v4();
    await _db
        .into(_db.tutoringServices)
        .insert(
          TutoringServicesCompanion.insert(
            id: id,
            teacherId: teacherId,
            subjectId: subjectId,
            levelIds: Value(levelIds.join(',')),
            mode: Value(mode.code),
            hourlyRate: Value(hourlyRate),
            city: Value(city),
            districts: Value(districts.join(',')),
            availabilityNote: Value(_clean(availabilityNote)),
            description: Value(_clean(description)),
            dirty: const Value(true),
          ),
        );

    await _sync.enqueue(
      entity: 'tutoring_service',
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'teacherId': teacherId,
        'subjectId': subjectId,
        'levelIds': levelIds,
        'mode': mode.code,
        'hourlyRate': hourlyRate,
        'city': city,
        'districts': districts,
      },
    );
    return id;
  }

  /// Met une offre en pause ou la réactive.
  Future<void> setOfferActive(String offerId, {required bool active}) async {
    await (_db.update(
      _db.tutoringServices,
    )..where((t) => t.id.equals(offerId))).write(
      TutoringServicesCompanion(
        active: Value(active),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
    await _sync.enqueue(
      entity: 'tutoring_service',
      entityId: offerId,
      operation: SyncOperation.update,
      payload: {'active': active},
    );
  }

  /// Offres d'un professeur. `onlyActive` pour ce que voit un parent.
  Future<List<TutoringOffer>> offersOf(
    String teacherId, {
    bool onlyActive = false,
  }) => _offers(teacherId: teacherId, onlyActive: onlyActive);

  /// Toutes les offres en ligne, quel que soit le professeur.
  ///
  /// Sert a la page separee des repetiteurs (note du 21/09) : un
  /// etablissement ne cherche pas un repetiteur pour la meme raison qu'un
  /// enseignant a l'annee, et les melanger faisait passer des profils a
  /// cote des deux besoins.
  Future<List<TutoringOffer>> allActiveOffers() => _offers(onlyActive: true);

  Future<List<TutoringOffer>> _offers({
    String? teacherId,
    String? offerId,
    bool onlyActive = false,
  }) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT s.*, sub.name AS subject_name,
                 u.first_name AS t_first, u.last_name AS t_last
          FROM tutoring_services s
          JOIN subjects sub ON sub.id = s.subject_id
          JOIN teachers t ON t.id = s.teacher_id
          JOIN users u ON u.id = t.user_id
          WHERE (?1 IS NULL OR s.teacher_id = ?1)
            AND (?2 IS NULL OR s.id = ?2)
            AND (?3 = 0 OR s.active = 1)
          ORDER BY s.active DESC, sub.name
          ''',
          variables: [
            Variable<String>(teacherId),
            Variable<String>(offerId),
            Variable<int>(onlyActive ? 1 : 0),
          ],
          readsFrom: {
            _db.tutoringServices,
            _db.subjects,
            _db.teachers,
            _db.users,
          },
        )
        .get();

    final levels = await _levelNames();
    return [for (final row in rows) _mapOffer(row, levels)];
  }

  // --- Demandes ---------------------------------------------------------

  /// Le parent demande des cours pour un de ses enfants.
  Future<String> requestTutoring({
    required String parentId,
    required String offerId,
    required String childId,
    String? message,
    DateTime? preferredStart,
  }) async {
    final offer = (await _offers(offerId: offerId)).firstOrNull;
    if (offer == null || !offer.active) {
      throw const TutoringException('Cette offre n’est plus disponible.');
    }

    final existing =
        await (_db.select(_db.tutoringRequests)..where(
              (t) =>
                  t.parentId.equals(parentId) &
                  t.serviceId.equals(offerId) &
                  t.childId.equals(childId),
            ))
            .get();
    if (!canRequestTutoring(
      existing.map((r) => TutoringStatus.fromCode(r.status)),
    )) {
      throw const TutoringException(
        'Vous avez déjà une demande en cours pour cet enfant.',
      );
    }

    final id = _uuid.v4();
    await _db
        .into(_db.tutoringRequests)
        .insert(
          TutoringRequestsCompanion.insert(
            id: id,
            parentId: parentId,
            serviceId: offerId,
            childId: Value(childId),
            status: Value(TutoringStatus.sent.code),
            message: Value(_clean(message)),
            preferredStart: Value(preferredStart),
            dirty: const Value(true),
          ),
        );

    await _sync.enqueue(
      entity: 'tutoring_request',
      entityId: id,
      operation: SyncOperation.create,
      // Les noms des colonnes, en minuscules à souligné : le serveur écarte
      // toute clé qui n'est pas exactement une colonne autorisée, et refuse la
      // charge dont il ne reste rien. Aucune de ces quatre ne passait.
      payload: {
        'parent_id': parentId,
        'service_id': offerId,
        'child_id': childId,
        'preferred_start': preferredStart?.toIso8601String(),
      },
    );
    return id;
  }

  /// Change le statut d'une demande, si la règle l'autorise.
  Future<void> setStatus({
    required String requestId,
    required TutoringActor actor,
    required TutoringStatus to,
  }) async {
    final row = await (_db.select(
      _db.tutoringRequests,
    )..where((t) => t.id.equals(requestId))).getSingleOrNull();
    if (row == null) {
      throw const TutoringException('Demande introuvable.');
    }

    final from = TutoringStatus.fromCode(row.status);
    if (!canSetTutoringStatus(actor: actor, from: from, to: to)) {
      throw TutoringException(
        from.isFinal
            ? 'Cette demande est déjà close.'
            : 'Cette action n’est pas possible.',
      );
    }

    final now = DateTime.now();
    await (_db.update(
      _db.tutoringRequests,
    )..where((t) => t.id.equals(requestId))).write(
      TutoringRequestsCompanion(
        status: Value(to.code),
        respondedAt: actor == TutoringActor.teacher
            ? Value(now)
            : const Value.absent(),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );

    await _sync.enqueue(
      entity: 'tutoring_request',
      entityId: requestId,
      operation: SyncOperation.update,
      payload: {'status': to.code},
    );

    // Accepter, c'est s'engager sur des horaires. Sans seances, l'accueil du
    // parent resterait vide alors que le professeur a dit oui — et personne
    // ne saurait quand le premier cours a lieu.
    if (to == TutoringStatus.accepted) {
      await TutoringSessionsRepository(_db).planFor(requestId);
      // Et un fil de discussion : accepter, c'est le moment ou les deux ont
      // quelque chose a se dire — un horaire a decaler, une adresse a
      // preciser. Avant, ils n'avaient rien a se dire ; apres, ils n'avaient
      // aucun endroit pour le faire.
      await ConversationsRepository(_db, _sync).openForRequest(requestId);
    }
  }

  /// Demandes envoyées par un parent.
  Future<List<TutoringRequestItem>> requestsOfParent(String parentId) =>
      _requests(parentId: parentId);

  /// Demandes reçues par un professeur.
  Future<List<TutoringRequestItem>> requestsOfTeacher(String teacherId) =>
      _requests(teacherId: teacherId);

  Future<List<TutoringRequestItem>> _requests({
    String? parentId,
    String? teacherId,
  }) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT r.id AS r_id, r.status AS r_status, r.message AS r_message,
                 r.preferred_start AS r_start, r.responded_at AS r_responded,
                 r.created_at AS r_created,
                 s.*, sub.name AS subject_name,
                 tu.first_name AS t_first, tu.last_name AS t_last,
                 pu.first_name AS p_first, pu.last_name AS p_last,
                 p.district AS p_district,
                 c.first_name AS c_first, c.level_id AS c_level
          FROM tutoring_requests r
          JOIN tutoring_services s ON s.id = r.service_id
          JOIN subjects sub ON sub.id = s.subject_id
          JOIN teachers t ON t.id = s.teacher_id
          JOIN users tu ON tu.id = t.user_id
          JOIN parents p ON p.id = r.parent_id
          JOIN users pu ON pu.id = p.user_id
          LEFT JOIN children c ON c.id = r.child_id
          WHERE (?1 IS NULL OR r.parent_id = ?1)
            AND (?2 IS NULL OR s.teacher_id = ?2)
          ORDER BY
            CASE r.status WHEN 'SENT' THEN 0 WHEN 'ACCEPTED' THEN 1 ELSE 2 END,
            r.created_at DESC
          ''',
          variables: [Variable<String>(parentId), Variable<String>(teacherId)],
          readsFrom: {
            _db.tutoringRequests,
            _db.tutoringServices,
            _db.subjects,
            _db.teachers,
            _db.users,
            _db.parents,
            _db.children,
          },
        )
        .get();

    final levels = await _levelNames();
    return [
      for (final row in rows)
        TutoringRequestItem(
          id: row.read<String>('r_id'),
          status: TutoringStatus.fromCode(row.read<String>('r_status')),
          createdAt: row.read<DateTime>('r_created'),
          offer: _mapOffer(row, levels),
          parentName: _name(
            row.readNullable<String>('p_first'),
            row.readNullable<String>('p_last'),
          ),
          parentDistrict: row.readNullable<String>('p_district'),
          childName: row.readNullable<String>('c_first'),
          childLevel: levels[row.readNullable<String>('c_level')],
          message: row.readNullable<String>('r_message'),
          preferredStart: row.readNullable<DateTime>('r_start'),
          respondedAt: row.readNullable<DateTime>('r_responded'),
        ),
    ];
  }

  // --- Outils -----------------------------------------------------------

  TutoringOffer _mapOffer(QueryRow row, Map<String?, String> levels) {
    final levelIds = row.read<String>('level_ids');
    final districts = row.read<String>('districts');
    return TutoringOffer(
      id: row.read<String>('id'),
      teacherId: row.read<String>('teacher_id'),
      teacherName: _name(
        row.readNullable<String>('t_first'),
        row.readNullable<String>('t_last'),
      ),
      subjectId: row.read<String>('subject_id'),
      subjectName: row.read<String>('subject_name'),
      levelNames: [
        for (final id in levelIds.split(','))
          if (id.isNotEmpty && levels[id] != null) levels[id]!,
      ],
      mode: TutoringMode.fromCode(row.read<String>('mode')),
      active: row.read<bool>('active'),
      hourlyRate: row.readNullable<int>('hourly_rate'),
      city: row.readNullable<String>('city'),
      districts: [
        for (final d in districts.split(','))
          if (d.trim().isNotEmpty) d.trim(),
      ],
      availabilityNote: row.readNullable<String>('availability_note'),
      description: row.readNullable<String>('description'),
    );
  }

  Future<Map<String?, String>> _levelNames() async {
    final rows = await _db.select(_db.levels).get();
    return {for (final l in rows) l.id: l.name};
  }

  static String _name(String? first, String? last) =>
      [first, last].whereType<String>().where((s) => s.isNotEmpty).join(' ');

  static String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
