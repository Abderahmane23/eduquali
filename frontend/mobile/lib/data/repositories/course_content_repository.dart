import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';

/// Le genre d'un élément de chapitre.
enum CourseItemKind {
  video('VIDEO', 'Vidéo'),
  document('DOCUMENT', 'Document'),
  link('LINK', 'Lien');

  const CourseItemKind(this.code, this.label);

  final String code;
  final String label;

  static CourseItemKind fromCode(String? code) => CourseItemKind.values
      .firstWhere((k) => k.code == code, orElse: () => CourseItemKind.video);
}

/// Une vidéo ou une ressource, prête à afficher.
class CourseItem {
  const CourseItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.position,
    this.localPath,
    this.remoteUrl,
    this.durationSeconds,
  });

  final String id;
  final CourseItemKind kind;
  final String title;
  final int position;
  final String? localPath;
  final String? remoteUrl;
  final int? durationSeconds;

  /// Ce qu'on donne au lecteur : le fichier local d'abord.
  ///
  /// Un fichier déjà sur l'appareil se lit sans réseau, et c'est la règle de
  /// toute l'application. L'adresse distante ne sert que si le fichier n'est
  /// pas là — après une réinstallation, par exemple.
  String? get source => localPath ?? remoteUrl;

  bool get isPlayable => kind == CourseItemKind.video && source != null;
}

/// Un chapitre avec ce qu'il contient.
class CourseChapter {
  const CourseChapter({
    required this.id,
    required this.title,
    required this.position,
    required this.items,
    this.description,
  });

  final String id;
  final String title;
  final String? description;
  final int position;
  final List<CourseItem> items;

  List<CourseItem> get videos => [
    for (final i in items)
      if (i.kind == CourseItemKind.video) i,
  ];

  List<CourseItem> get resources => [
    for (final i in items)
      if (i.kind != CourseItemKind.video) i,
  ];
}

/// Un commentaire, avec le nom de celui qui l'a écrit.
class CourseComment {
  const CourseComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    required this.fromTeacher,
    this.parentId,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  /// Vrai quand c'est le professeur du cours qui répond : sa réponse n'a pas
  /// le même poids qu'un commentaire d'élève, et l'écran la distingue.
  final bool fromTeacher;

  final String? parentId;
}

/// Une vidéo ou une ressource telle que le formulaire la décrit, avant
/// écriture.
///
/// Un brouillon n'a pas d'identifiant : il n'existe qu'entre le moment où le
/// professeur choisit un fichier et celui où il publie. Lui donner un `id`
/// laisserait croire qu'il est en base.
class ItemDraft {
  const ItemDraft({
    required this.kind,
    required this.title,
    this.localPath,
    this.remoteUrl,
  });

  final CourseItemKind kind;
  final String title;
  final String? localPath;
  final String? remoteUrl;
}

/// Un chapitre tel que le formulaire le décrit, avant écriture.
class ChapterDraft {
  const ChapterDraft({
    required this.title,
    required this.items,
    this.description,
  });

  final String title;
  final String? description;
  final List<ItemDraft> items;

  int get videoCount =>
      items.where((i) => i.kind == CourseItemKind.video).length;
}

/// Le contenu d'un cours vidéo : chapitres, éléments, commentaires.
///
/// Séparé de `VideoCoursesRepository`, qui gère le cours comme objet de vente
/// — prix, publication, achats. Ici c'est la matière : ce qu'on regarde et ce
/// qu'on en dit.
class CourseContentRepository {
  CourseContentRepository(this._db, this._sync);

  final AppDatabase _db;
  final SyncEngine _sync;
  static const _uuid = Uuid();

  /// Les chapitres d'un cours, dans l'ordre, avec leurs éléments.
  ///
  /// Deux requêtes et un regroupement en mémoire, plutôt qu'une requête par
  /// chapitre : un cours de dix chapitres ferait onze allers-retours, et
  /// l'écran s'ouvre sur un cours entier.
  Future<List<CourseChapter>> chaptersOf(String courseId) async {
    var chapitres =
        await (_db.select(_db.courseChapters)
              ..where((t) => t.courseId.equals(courseId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();

    if (chapitres.isEmpty) {
      // Les cours créés avant les chapitres ne portent qu'une liste de
      // chemins dans `video_courses.video_paths`. Sans reprise, un élève qui
      // a payé ouvrirait un écran vide alors que ses vidéos sont là.
      await _materialiserLesAnciensChemins(courseId);
      chapitres =
          await (_db.select(_db.courseChapters)
                ..where((t) => t.courseId.equals(courseId))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();
    }
    if (chapitres.isEmpty) return const [];

    final elements =
        await (_db.select(_db.courseItems)
              ..where((t) => t.chapterId.isIn(chapitres.map((c) => c.id)))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();

    final parChapitre = <String, List<CourseItem>>{};
    for (final e in elements) {
      parChapitre
          .putIfAbsent(e.chapterId, () => [])
          .add(
            CourseItem(
              id: e.id,
              kind: CourseItemKind.fromCode(e.kind),
              title: e.title,
              position: e.position,
              localPath: e.localPath,
              remoteUrl: e.remoteUrl,
              durationSeconds: e.durationSeconds,
            ),
          );
    }

    return [
      for (final c in chapitres)
        CourseChapter(
          id: c.id,
          title: c.title,
          description: c.description,
          position: c.position,
          items: parChapitre[c.id] ?? const [],
        ),
    ];
  }

  /// Ajoute un chapitre et rend son identifiant.
  ///
  /// Le rang est calculé ici, à la suite des existants : le laisser à
  /// l'appelant produirait deux chapitres de rang 2 dès qu'un écran oublie de
  /// le passer, et l'ordre deviendrait celui du hasard.
  Future<String> addChapter({
    required String courseId,
    required String title,
    String? description,
  }) async {
    final existants = await (_db.select(
      _db.courseChapters,
    )..where((t) => t.courseId.equals(courseId))).get();

    final id = _uuid.v4();
    await _db
        .into(_db.courseChapters)
        .insert(
          CourseChaptersCompanion.insert(
            id: id,
            courseId: courseId,
            title: title.trim(),
            description: Value(
              description == null || description.trim().isEmpty
                  ? null
                  : description.trim(),
            ),
            position: Value(existants.length),
            dirty: const Value(true),
          ),
        );
    await _sync.enqueue(
      entity: 'course_chapter',
      entityId: id,
      operation: SyncOperation.create,
      payload: {'courseId': courseId, 'title': title.trim()},
    );
    return id;
  }

  /// Ajoute une vidéo ou une ressource dans un chapitre.
  Future<String> addItem({
    required String chapterId,
    required CourseItemKind kind,
    required String title,
    String? localPath,
    String? remoteUrl,
    int? durationSeconds,
  }) async {
    final existants = await (_db.select(
      _db.courseItems,
    )..where((t) => t.chapterId.equals(chapterId))).get();

    final id = _uuid.v4();
    await _db
        .into(_db.courseItems)
        .insert(
          CourseItemsCompanion.insert(
            id: id,
            chapterId: chapterId,
            kind: Value(kind.code),
            title: title.trim(),
            localPath: Value(localPath),
            remoteUrl: Value(remoteUrl),
            durationSeconds: Value(durationSeconds),
            position: Value(existants.length),
            dirty: const Value(true),
          ),
        );
    await _sync.enqueue(
      entity: 'course_item',
      entityId: id,
      // Une vidéo deposee doit partir au serveur, pas seulement sa ligne.
      operation: localPath == null
          ? SyncOperation.create
          : SyncOperation.upload,
      payload: {
        'chapterId': chapterId,
        'kind': kind.code,
        'title': title.trim(),
        'localPath': localPath,
      },
    );
    return id;
  }

  /// Écrit d'un coup les chapitres d'un cours qu'on vient de créer.
  ///
  /// En une transaction : un cours à moitié écrit — trois chapitres sur cinq,
  /// un chapitre sans ses vidéos — se vendrait quand même, et l'élève paierait
  /// pour un trou. Soit tout le sommaire entre, soit rien.
  ///
  /// Le rang vient de l'ordre de la liste, qui est celui que le professeur a
  /// sous les yeux dans le formulaire.
  Future<void> writeChapters({
    required String courseId,
    required List<ChapterDraft> chapters,
  }) async {
    if (chapters.isEmpty) return;

    await _db.transaction(() async {
      for (var rang = 0; rang < chapters.length; rang++) {
        final brouillon = chapters[rang];
        final chapitreId = _uuid.v4();
        await _db
            .into(_db.courseChapters)
            .insert(
              CourseChaptersCompanion.insert(
                id: chapitreId,
                courseId: courseId,
                title: brouillon.title.trim(),
                description: Value(_ouRien(brouillon.description)),
                position: Value(rang),
                dirty: const Value(true),
              ),
            );
        await _sync.enqueue(
          entity: 'course_chapter',
          entityId: chapitreId,
          operation: SyncOperation.create,
          payload: {
            'courseId': courseId,
            'title': brouillon.title.trim(),
            'position': rang,
          },
        );

        for (var i = 0; i < brouillon.items.length; i++) {
          final element = brouillon.items[i];
          final elementId = _uuid.v4();
          await _db
              .into(_db.courseItems)
              .insert(
                CourseItemsCompanion.insert(
                  id: elementId,
                  chapterId: chapitreId,
                  kind: Value(element.kind.code),
                  title: element.title.trim(),
                  localPath: Value(element.localPath),
                  remoteUrl: Value(element.remoteUrl),
                  position: Value(i),
                  dirty: const Value(true),
                ),
              );
          await _sync.enqueue(
            entity: 'course_item',
            entityId: elementId,
            // Un fichier déposé doit partir au serveur, pas seulement sa
            // ligne : sans cela l'élève n'a rien à regarder.
            operation: element.localPath == null
                ? SyncOperation.create
                : SyncOperation.upload,
            payload: {
              'chapterId': chapitreId,
              'kind': element.kind.code,
              'title': element.title.trim(),
              'localPath': element.localPath,
              'remoteUrl': element.remoteUrl,
            },
          );
        }
      }
    });
  }

  /// Reconstruit un sommaire à partir de `video_courses.video_paths`.
  ///
  /// Écrire pendant une lecture n'est pas l'habitude de ce dépôt, et c'est
  /// assumé : les chemins existent déjà, les chapitres non, et un identifiant
  /// réel est nécessaire pour qu'un commentaire s'y rattache — la clé
  /// étrangère de `course_comments` pointe sur `course_items`. Les lignes ne
  /// sont donc **pas** marquées `dirty` : le serveur connaît déjà ces chemins,
  /// les renvoyer créerait un doublon de son côté.
  ///
  /// Idempotent : l'appel suivant trouve le chapitre et ne fait rien.
  Future<void> _materialiserLesAnciensChemins(String courseId) async {
    final cours = await (_db.select(
      _db.videoCourses,
    )..where((t) => t.id.equals(courseId))).getSingleOrNull();
    if (cours == null) return;

    final chemins = [
      for (final c in cours.videoPaths.split(','))
        if (c.trim().isNotEmpty) c.trim(),
    ];
    if (chemins.isEmpty) return;

    await _db.transaction(() async {
      final chapitreId = _uuid.v4();
      await _db
          .into(_db.courseChapters)
          .insert(
            CourseChaptersCompanion.insert(
              id: chapitreId,
              courseId: courseId,
              title: cours.title,
              position: const Value(0),
            ),
          );
      for (var i = 0; i < chemins.length; i++) {
        final chemin = chemins[i];
        final distant = chemin.startsWith('http');
        await _db
            .into(_db.courseItems)
            .insert(
              CourseItemsCompanion.insert(
                id: _uuid.v4(),
                chapterId: chapitreId,
                kind: Value(CourseItemKind.video.code),
                title: 'Vidéo ${i + 1}',
                localPath: Value(distant ? null : chemin),
                remoteUrl: Value(distant ? chemin : null),
                position: Value(i),
              ),
            );
      }
    });
  }

  String? _ouRien(String? valeur) {
    final propre = valeur?.trim();
    return propre == null || propre.isEmpty ? null : propre;
  }

  Future<void> removeChapter(String chapterId) async {
    // Les éléments partent avec le chapitre : une vidéo orpheline
    // n'apparaîtrait nulle part et occuperait la place pour toujours.
    await (_db.delete(
      _db.courseItems,
    )..where((t) => t.chapterId.equals(chapterId))).go();
    await (_db.delete(
      _db.courseChapters,
    )..where((t) => t.id.equals(chapterId))).go();
    await _sync.enqueue(
      entity: 'course_chapter',
      entityId: chapterId,
      operation: SyncOperation.delete,
      payload: const {},
    );
  }

  // --- Commentaires -------------------------------------------------------

  /// Les commentaires d'une vidéo, du plus ancien au plus récent.
  ///
  /// L'ordre est celui d'une conversation : on lit la question avant la
  /// réponse. Trier du plus récent mettrait les réponses avant ce qu'elles
  /// répondent.
  Future<List<CourseComment>> commentsOf(String itemId) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT cc.id, cc.author_id, cc.body, cc.parent_id, cc.created_at,
             u.first_name, u.last_name, u.role,
             vc.teacher_id AS course_teacher,
             t.user_id     AS teacher_user
        FROM course_comments cc
        JOIN users u ON u.id = cc.author_id
        JOIN course_items ci   ON ci.id = cc.item_id
        JOIN course_chapters ch ON ch.id = ci.chapter_id
        JOIN video_courses vc  ON vc.id = ch.course_id
        LEFT JOIN teachers t   ON t.id = vc.teacher_id
       WHERE cc.item_id = ?1
       ORDER BY cc.created_at ASC
      ''',
          variables: [Variable<String>(itemId)],
          readsFrom: {
            _db.courseComments,
            _db.users,
            _db.courseItems,
            _db.courseChapters,
            _db.videoCourses,
            _db.teachers,
          },
        )
        .get();

    return [
      for (final r in rows)
        CourseComment(
          id: r.read<String>('id'),
          authorId: r.read<String>('author_id'),
          authorName: [
            r.read<String?>('first_name') ?? '',
            r.read<String?>('last_name') ?? '',
          ].join(' ').trim(),
          body: r.read<String>('body'),
          createdAt: r.read<DateTime>('created_at'),
          // L'auteur est-il le professeur de ce cours ? Comparer les rôles ne
          // suffirait pas : un autre professeur qui commente reste un
          // spectateur.
          fromTeacher:
              r.read<String?>('teacher_user') == r.read<String>('author_id'),
          parentId: r.read<String?>('parent_id'),
        ),
    ];
  }

  Future<String> comment({
    required String itemId,
    required String authorId,
    required String body,
    String? parentId,
  }) async {
    final texte = body.trim();
    if (texte.isEmpty) throw StateError('Commentaire vide');

    final id = _uuid.v4();
    await _db
        .into(_db.courseComments)
        .insert(
          CourseCommentsCompanion.insert(
            id: id,
            itemId: itemId,
            authorId: authorId,
            body: texte,
            parentId: Value(parentId),
            dirty: const Value(true),
          ),
        );
    await _sync.enqueue(
      entity: 'course_comment',
      entityId: id,
      operation: SyncOperation.create,
      payload: {'itemId': itemId, 'body': texte, 'parentId': parentId},
    );
    return id;
  }

  Future<void> removeComment(String commentId) async {
    await (_db.delete(
      _db.courseComments,
    )..where((t) => t.id.equals(commentId))).go();
    await _sync.enqueue(
      entity: 'course_comment',
      entityId: commentId,
      operation: SyncOperation.delete,
      payload: const {},
    );
  }
}
