import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../../core/utils/contact_masker.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';

/// Un fil entre une famille et un professeur.
class ConversationItem {
  const ConversationItem({
    required this.id,
    required this.teacherId,
    required this.parentId,
    required this.institutionId,
    required this.otherName,
    required this.subtitle,
    required this.lastMessage,
    required this.lastAt,
    required this.unread,
  });

  final String id;
  final String teacherId;

  /// La famille, ou l'etablissement : exactement l'un des deux.
  final String? parentId;
  final String? institutionId;

  /// Le nom de l'autre partie, vue du lecteur : le parent voit le
  /// professeur, le professeur voit la famille.
  final String otherName;

  /// Ce dont il est question — la matière et l'enfant, quand on les sait.
  final String subtitle;

  final String? lastMessage;
  final DateTime? lastAt;
  final int unread;
}

/// Un message dans un fil.
class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.body,
    required this.sentAt,
    required this.masked,
  });

  final String id;
  final String senderId;
  final UserRole senderRole;
  final String body;
  final DateTime sentAt;

  /// Vrai quand le texte affiché n'est pas celui qui a été écrit.
  final bool masked;
}

/// Les conversations entre familles et professeurs (24/09).
///
/// Elles existent à part des espaces de recrutement : ceux-là portent une
/// candidature, une offre, un contrat et des étapes, qui n'ont pas de sens
/// entre un parent et un répétiteur. Les messages, eux, sont les mêmes —
/// même table, même masquage des coordonnées.
///
/// Le masquage est la raison pour laquelle les deux ne se séparent pas
/// complètement : deux implémentations du même filtre finiraient par ne plus
/// masquer la même chose, et c'est la seule règle du produit qu'on ne peut
/// pas se permettre d'appliquer à moitié.
class ConversationsRepository {
  ConversationsRepository(this._db, this._sync);

  final AppDatabase _db;
  final SyncEngine _sync;
  static const _uuid = Uuid();

  /// Ouvre le fil d'une demande de cours, ou rend celui qui existe déjà.
  ///
  /// Appelée quand un professeur accepte : c'est le moment où les deux
  /// parties ont quelque chose à se dire, et pas avant.
  Future<String> openForRequest(String requestId) async {
    final existing = await (_db.select(
      _db.conversations,
    )..where((t) => t.requestId.equals(requestId))).getSingleOrNull();
    if (existing != null) return existing.id;

    final row = await _db
        .customSelect(
          '''
      SELECT r.parent_id AS parent_id, sv.teacher_id AS teacher_id
        FROM tutoring_requests r
        JOIN tutoring_services sv ON sv.id = r.service_id
       WHERE r.id = ?1
      ''',
          variables: [Variable<String>(requestId)],
          readsFrom: {_db.tutoringRequests, _db.tutoringServices},
        )
        .getSingleOrNull();
    if (row == null) throw StateError('Demande introuvable');

    final id = _uuid.v4();
    await _db
        .into(_db.conversations)
        .insert(
          ConversationsCompanion.insert(
            id: id,
            teacherId: row.read<String>('teacher_id'),
            parentId: Value(row.read<String>('parent_id')),
            requestId: Value(requestId),
            dirty: const Value(true),
          ),
        );
    await _sync.enqueue(
      entity: 'conversation',
      entityId: id,
      operation: SyncOperation.create,
      payload: {'requestId': requestId},
    );
    return id;
  }

  /// Ouvre le fil direct entre un etablissement et un professeur.
  ///
  /// Sans offre d'emploi derriere : un directeur qui tombe sur une fiche veut
  /// ecrire, et il n'y a ni candidature ni espace de recrutement a ouvrir
  /// pour cela. L'ecran affichait jusqu'ici « la discussion directe arrive
  /// bientot », faute d'une table capable de ranger ce fil.
  ///
  /// Idempotente : un second appel rend le fil existant. Deux fils entre les
  /// memes parties couperaient la conversation en deux, et la moitie des
  /// messages deviendrait invisible.
  Future<String> openForInstitution({
    required String institutionId,
    required String teacherId,
  }) async {
    final existing =
        await (_db.select(_db.conversations)..where(
              (t) =>
                  t.institutionId.equals(institutionId) &
                  t.teacherId.equals(teacherId),
            ))
            .getSingleOrNull();
    if (existing != null) return existing.id;

    final id = _uuid.v4();
    await _db
        .into(_db.conversations)
        .insert(
          ConversationsCompanion.insert(
            id: id,
            teacherId: teacherId,
            institutionId: Value(institutionId),
            dirty: const Value(true),
          ),
        );
    await _sync.enqueue(
      entity: 'conversation',
      entityId: id,
      operation: SyncOperation.create,
      payload: {'institutionId': institutionId, 'teacherId': teacherId},
    );
    return id;
  }

  /// Les fils d'une personne, le plus récent en premier.
  Future<List<ConversationItem>> of({
    String? teacherId,
    String? parentId,
    String? institutionId,
    required String readerId,
  }) async {
    if (teacherId == null && parentId == null && institutionId == null) {
      return const [];
    }
    final pourLeProfesseur = teacherId != null;
    final filtreDemandeur = parentId != null
        ? 'c.parent_id'
        : 'c.institution_id';

    final rows = await _db
        .customSelect(
          '''
      SELECT c.id, c.teacher_id, c.parent_id, c.institution_id,
             tu.first_name  AS t_first, tu.last_name  AS t_last,
             pu.first_name  AS p_first, pu.last_name  AS p_last,
             i.name         AS institution_name,
             s.name         AS subject_name,
             ch.first_name  AS child_name,
             (SELECT body FROM messages m
               WHERE m.conversation_id = c.id
               ORDER BY m.sent_at DESC LIMIT 1)        AS last_body,
             (SELECT sent_at FROM messages m
               WHERE m.conversation_id = c.id
               ORDER BY m.sent_at DESC LIMIT 1)        AS last_at,
             (SELECT COUNT(*) FROM messages m
               WHERE m.conversation_id = c.id
                 AND m.read_at IS NULL
                 AND m.sender_id != ?2)                AS unread
        FROM conversations c
        JOIN teachers t  ON t.id = c.teacher_id
        JOIN users    tu ON tu.id = t.user_id
        LEFT JOIN parents      p  ON p.id = c.parent_id
        LEFT JOIN users        pu ON pu.id = p.user_id
        LEFT JOIN institutions i  ON i.id = c.institution_id
        LEFT JOIN tutoring_requests r  ON r.id = c.request_id
        LEFT JOIN children          ch ON ch.id = r.child_id
        LEFT JOIN tutoring_services sv ON sv.id = r.service_id
        LEFT JOIN subjects          s  ON s.id = sv.subject_id
       WHERE ${pourLeProfesseur ? 'c.teacher_id' : filtreDemandeur} = ?1
       ORDER BY COALESCE(last_at, c.created_at) DESC
      ''',
          variables: [
            Variable<String>(
              pourLeProfesseur ? teacherId : (parentId ?? institutionId!),
            ),
            Variable<String>(readerId),
          ],
          readsFrom: {
            _db.conversations,
            _db.messages,
            _db.teachers,
            _db.parents,
            _db.users,
            _db.tutoringRequests,
            _db.children,
            _db.tutoringServices,
            _db.subjects,
            _db.institutions,
          },
        )
        .get();

    String nom(String? prenom, String? nom) =>
        [prenom ?? '', nom ?? ''].join(' ').trim();

    return [
      for (final r in rows)
        ConversationItem(
          id: r.read<String>('id'),
          teacherId: r.read<String>('teacher_id'),
          parentId: r.read<String?>('parent_id'),
          institutionId: r.read<String?>('institution_id'),
          otherName: pourLeProfesseur
              // Vu du professeur, l'autre partie est la famille ou
              // l'etablissement — jamais les deux, jamais aucun.
              ? (r.read<String?>('institution_name') ??
                    nom(r.read<String?>('p_first'), r.read<String?>('p_last')))
              : nom(r.read<String?>('t_first'), r.read<String?>('t_last')),
          subtitle: [
            r.read<String?>('subject_name'),
            r.read<String?>('child_name'),
          ].whereType<String>().join(' · '),
          lastMessage: r.read<String?>('last_body'),
          lastAt: r.read<DateTime?>('last_at'),
          unread: r.read<int>('unread'),
        ),
    ];
  }

  /// Les messages d'un fil, dans l'ordre.
  Future<List<ConversationMessage>> messages(String conversationId) async {
    final rows =
        await (_db.select(_db.messages)
              ..where((t) => t.conversationId.equals(conversationId))
              ..orderBy([(t) => OrderingTerm.asc(t.sentAt)]))
            .get();

    return [
      for (final r in rows)
        ConversationMessage(
          id: r.id,
          senderId: r.senderId,
          senderRole: UserRole.fromCode(r.senderRole),
          // Le corps d'origine est conservé ; le masquage est une couche
          // d'affichage, appliquée à la lecture.
          // Le masquage reste actif tant que rien n'a ete conclu entre
          // les deux : une famille et un repetiteur n'ont pas de contrat
          // signe qui le leverait, contrairement au recrutement (§30).
          body: ContactMasker.mask(r.body, unlocked: false).text,
          sentAt: r.sentAt,
          masked: r.masked,
        ),
    ];
  }

  /// Envoie un message. Le filtre anti-contournement s'applique ici comme
  /// dans un espace de recrutement (§30).
  Future<String> send({
    required String conversationId,
    required String senderId,
    required UserRole senderRole,
    required String body,
  }) async {
    final texte = body.trim();
    if (texte.isEmpty) throw StateError('Message vide');

    final result = ContactMasker.mask(texte, unlocked: false);
    final id = _uuid.v4();
    await _db
        .into(_db.messages)
        .insert(
          MessagesCompanion.insert(
            id: id,
            conversationId: Value(conversationId),
            senderId: senderId,
            senderRole: senderRole.code,
            body: texte,
            masked: Value(result.masked),
            dirty: const Value(true),
          ),
        );

    await (_db.update(
      _db.conversations,
    )..where((t) => t.id.equals(conversationId))).write(
      ConversationsCompanion(
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );

    await _sync.enqueue(
      entity: 'message',
      entityId: id,
      operation: SyncOperation.create,
      payload: {'conversationId': conversationId, 'body': texte},
    );
    return id;
  }

  /// Marque comme lu ce que l'autre a écrit.
  Future<void> markRead(String conversationId, String readerId) =>
      (_db.update(_db.messages)..where(
            (t) =>
                t.conversationId.equals(conversationId) &
                t.senderId.equals(readerId).not() &
                t.readAt.isNull(),
          ))
          .write(MessagesCompanion(readAt: Value(DateTime.now())));
}
