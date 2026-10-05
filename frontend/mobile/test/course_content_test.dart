import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_constants.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/core/storage/document_pipeline.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/repositories/course_content_repository.dart';
import 'package:veriprof/data/repositories/video_courses_repository.dart';
import 'package:veriprof/data/sync/sync_engine.dart';

/// Le contenu d'un cours : chapitres, vidéos, ressources, commentaires.
///
/// Demandé le 02/10 : « le cours doit être sous forme de plusieurs
/// déroulants, chacun avec son titre, ses vidéos et ses ressources ». Avant,
/// un cours n'était qu'une liste plate de chemins, et le formulaire y écrivait
/// « video_1.mp4 » — un nom inventé, derrière lequel il n'y avait aucun
/// fichier.
void main() {
  late AppDatabase db;
  late CourseContentRepository contenu;
  late VideoCoursesRepository cours;

  /// Un professeur, un élève, et un cours à vendre.
  Future<String> unCours({String videoPaths = ''}) async {
    final id = 'cours_${videoPaths.hashCode}';
    await db
        .into(db.videoCourses)
        .insert(
          VideoCoursesCompanion.insert(
            id: id,
            teacherId: 't_prof',
            title: 'Les fonctions affines',
            price: const Value(50000),
            videoPaths: Value(videoPaths),
          ),
        );
    return id;
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final engine = SyncEngine(
      database: db,
      network: NetworkStatusService(),
      api: SyncApi(Dio()),
      deviceId: 'test',
    );
    contenu = CourseContentRepository(db, engine);
    cours = VideoCoursesRepository(db, engine);

    await db.batch((batch) {
      batch
        ..insertAll(db.users, [
          UsersCompanion.insert(
            id: 'u_prof',
            role: 'TEACHER',
            phone: '+224620000001',
            firstName: const Value('Mamadou'),
            lastName: const Value('Diallo'),
          ),
          UsersCompanion.insert(
            id: 'u_eleve',
            role: 'PARENT',
            phone: '+224620000002',
            firstName: const Value('Aissatou'),
            lastName: const Value('Bah'),
          ),
          UsersCompanion.insert(
            id: 'u_autre_prof',
            role: 'TEACHER',
            phone: '+224620000003',
            firstName: const Value('Fatoumata'),
            lastName: const Value('Camara'),
          ),
        ])
        ..insertAll(db.teachers, [
          TeachersCompanion.insert(id: 't_prof', userId: 'u_prof'),
          TeachersCompanion.insert(id: 't_autre', userId: 'u_autre_prof'),
        ]);
    });
  });

  tearDown(() => db.close());

  group('Le sommaire écrit par le formulaire', () {
    test('garde l’ordre des chapitres et de leur contenu', () async {
      final id = await unCours();
      await contenu.writeChapters(
        courseId: id,
        chapters: [
          ChapterDraft(
            title: 'Reconnaître une fonction affine',
            description: 'On part du graphique.',
            items: const [
              ItemDraft(
                kind: CourseItemKind.video,
                title: 'La droite',
                localPath: '/data/cours/droite.mp4',
              ),
              ItemDraft(
                kind: CourseItemKind.document,
                title: 'Exercices',
                localPath: '/data/cours/exos.pdf',
              ),
            ],
          ),
          const ChapterDraft(
            title: 'Le coefficient directeur',
            items: [
              ItemDraft(
                kind: CourseItemKind.video,
                title: 'Calculer la pente',
                localPath: '/data/cours/pente.mp4',
              ),
            ],
          ),
        ],
      );

      final chapitres = await contenu.chaptersOf(id);
      expect(chapitres, hasLength(2));
      // Le rang vient de l'ordre de la liste, celui que le professeur a sous
      // les yeux. Le déduire de la date de création rendrait l'ordre
      // dépendant de la vitesse d'écriture.
      expect(chapitres.first.position, 0);
      expect(chapitres.last.position, 1);
      expect(chapitres.first.title, 'Reconnaître une fonction affine');
      expect(chapitres.first.description, 'On part du graphique.');

      // Vidéos et ressources sont dans la même table, séparées par leur genre
      // à la lecture.
      expect(chapitres.first.videos, hasLength(1));
      expect(chapitres.first.resources, hasLength(1));
      expect(chapitres.first.resources.single.title, 'Exercices');
      expect(chapitres.first.items.first.position, 0);
      expect(chapitres.first.items.last.position, 1);
    });

    test('un chapitre sans description n’en invente pas une vide', () async {
      final id = await unCours();
      await contenu.writeChapters(
        courseId: id,
        chapters: const [
          ChapterDraft(
            title: 'Chapitre unique',
            // Le formulaire envoie le contenu du champ tel quel : vide, il
            // vaut « pas de description », pas une ligne blanche sous la
            // vidéo.
            description: '   ',
            items: [
              ItemDraft(
                kind: CourseItemKind.video,
                title: 'Introduction',
                localPath: '/data/cours/intro.mp4',
              ),
            ],
          ),
        ],
      );

      final chapitre = (await contenu.chaptersOf(id)).single;
      expect(chapitre.description, isNull);
    });

    test('un lien garde son adresse, pas un chemin local', () async {
      final id = await unCours();
      await contenu.writeChapters(
        courseId: id,
        chapters: const [
          ChapterDraft(
            title: 'Pour aller plus loin',
            items: [
              ItemDraft(
                kind: CourseItemKind.video,
                title: 'Le cours',
                localPath: '/data/cours/cours.mp4',
              ),
              ItemDraft(
                kind: CourseItemKind.link,
                title: 'Annales du baccalauréat',
                remoteUrl: 'https://exemple.gn/annales',
              ),
            ],
          ),
        ],
      );

      final lien = (await contenu.chaptersOf(id)).single.resources.single;
      expect(lien.kind, CourseItemKind.link);
      expect(lien.localPath, isNull);
      // `source` sert au lecteur : pour un lien, c'est l'adresse.
      expect(lien.source, 'https://exemple.gn/annales');
      expect(lien.isPlayable, isFalse);
    });

    test('rien n’est écrit si une partie échoue', () async {
      // Un cours à moitié écrit se vendrait quand même, et l'élève paierait
      // pour un sommaire troué. L'identifiant de cours est inconnu : la clé
      // étrangère refuse le premier chapitre, et la transaction doit tout
      // ramener en arrière — y compris les lignes de la file de
      // synchronisation.
      await expectLater(
        contenu.writeChapters(
          courseId: 'cours_qui_n_existe_pas',
          chapters: const [
            ChapterDraft(
              title: 'Chapitre 1',
              items: [ItemDraft(kind: CourseItemKind.video, title: 'Vidéo 1')],
            ),
          ],
        ),
        throwsA(anything),
      );

      expect(await db.select(db.courseChapters).get(), isEmpty);
      expect(await db.select(db.courseItems).get(), isEmpty);
      expect(await db.select(db.syncQueue).get(), isEmpty);
    });

    test('un fichier déposé part au serveur, pas seulement sa ligne', () async {
      final id = await unCours();
      await contenu.writeChapters(
        courseId: id,
        chapters: const [
          ChapterDraft(
            title: 'Chapitre 1',
            items: [
              ItemDraft(
                kind: CourseItemKind.video,
                title: 'La droite',
                localPath: '/data/cours/droite.mp4',
              ),
              ItemDraft(
                kind: CourseItemKind.link,
                title: 'Annales',
                remoteUrl: 'https://exemple.gn/annales',
              ),
            ],
          ),
        ],
      );

      final file = await db.select(db.syncQueue).get();
      final elements = file.where((o) => o.entity == 'course_item').toList();
      expect(elements, hasLength(2));
      // Sans `upload`, la ligne arrive au serveur en annonçant une vidéo que
      // personne ne pourra lire.
      expect(
        elements.where((o) => o.operation == 'UPLOAD'),
        hasLength(1),
        reason: 'la vidéo déposée doit être téléversée',
      );
      expect(
        elements.where((o) => o.operation == 'CREATE'),
        hasLength(1),
        reason: 'un lien n’a aucun fichier à envoyer',
      );
    });
  });

  group('Un cours d’avant les chapitres', () {
    test('retrouve un sommaire à partir de ses chemins', () async {
      // Les cours créés avant le 02/10 ne portent qu'une liste plate. Sans
      // reprise, l'élève qui a payé ouvre un écran vide alors que ses vidéos
      // sont là.
      final id = await unCours(
        videoPaths: '/data/cours/a.mp4,/data/cours/b.mp4',
      );

      final chapitres = await contenu.chaptersOf(id);
      expect(chapitres, hasLength(1));
      expect(chapitres.single.title, 'Les fonctions affines');
      expect(chapitres.single.videos, hasLength(2));
      expect(chapitres.single.videos.first.source, '/data/cours/a.mp4');
      expect(chapitres.single.videos.first.isPlayable, isTrue);
    });

    test('une adresse distante reste une adresse', () async {
      final id = await unCours(videoPaths: 'https://exemple.gn/a.mp4');
      final video = (await contenu.chaptersOf(id)).single.videos.single;
      expect(video.remoteUrl, 'https://exemple.gn/a.mp4');
      expect(video.localPath, isNull);
    });

    test('la reprise ne se rejoue pas à chaque ouverture', () async {
      final id = await unCours(videoPaths: '/data/cours/a.mp4');
      await contenu.chaptersOf(id);
      await contenu.chaptersOf(id);
      await contenu.chaptersOf(id);

      expect(await db.select(db.courseChapters).get(), hasLength(1));
      expect(await db.select(db.courseItems).get(), hasLength(1));
    });

    test('la reprise ne renvoie rien au serveur', () async {
      // Le serveur connaît déjà ces chemins : les lui repousser créerait un
      // doublon de son côté, et marquerait comme « à envoyer » des lignes
      // reconstruites localement.
      final id = await unCours(videoPaths: '/data/cours/a.mp4');
      await contenu.chaptersOf(id);

      expect(await db.select(db.syncQueue).get(), isEmpty);
      final chapitre = await db.select(db.courseChapters).getSingle();
      expect(chapitre.dirty, isFalse);
    });

    test('un cours sans aucune vidéo reste vide', () async {
      final id = await unCours();
      expect(await contenu.chaptersOf(id), isEmpty);
      expect(await db.select(db.courseChapters).get(), isEmpty);
    });
  });

  group('Les commentaires sous une vidéo', () {
    late String videoId;

    setUp(() async {
      final id = await unCours();
      await contenu.writeChapters(
        courseId: id,
        chapters: const [
          ChapterDraft(
            title: 'Chapitre 1',
            items: [
              ItemDraft(
                kind: CourseItemKind.video,
                title: 'La droite',
                localPath: '/data/cours/droite.mp4',
              ),
            ],
          ),
        ],
      );
      videoId = (await contenu.chaptersOf(id)).single.videos.single.id;
    });

    test('se lisent dans l’ordre de la conversation', () async {
      await contenu.comment(
        itemId: videoId,
        authorId: 'u_eleve',
        body: 'Je ne comprends pas la minute 3.',
      );
      await contenu.comment(
        itemId: videoId,
        authorId: 'u_prof',
        body: 'C’est le coefficient directeur, je reprends plus bas.',
      );

      final fil = await contenu.commentsOf(videoId);
      expect(fil, hasLength(2));
      // La question avant la réponse : trier du plus récent mettrait les
      // réponses avant ce qu'elles répondent.
      expect(fil.first.body, contains('minute 3'));
      expect(fil.first.authorName, 'Aissatou Bah');
    });

    test('distinguent le professeur du cours des autres', () async {
      await contenu.comment(
        itemId: videoId,
        authorId: 'u_prof',
        body: 'Bonne question.',
      );
      await contenu.comment(
        itemId: videoId,
        authorId: 'u_autre_prof',
        body: 'Moi aussi j’enseigne ça.',
      );
      await contenu.comment(
        itemId: videoId,
        authorId: 'u_eleve',
        body: 'Merci.',
      );

      final fil = await contenu.commentsOf(videoId);
      // Comparer les rôles ne suffirait pas : un autre professeur qui commente
      // reste un spectateur, et sa réponse n'a pas le poids de celle de
      // l'auteur du cours.
      expect(fil[0].fromTeacher, isTrue);
      expect(fil[1].fromTeacher, isFalse);
      expect(fil[2].fromTeacher, isFalse);
    });

    test('un commentaire vide est refusé', () async {
      await expectLater(
        contenu.comment(itemId: videoId, authorId: 'u_eleve', body: '   '),
        throwsA(isA<StateError>()),
      );
      expect(await contenu.commentsOf(videoId), isEmpty);
    });

    test('ne débordent pas d’une vidéo sur l’autre', () async {
      // Un commentaire porte sur la vidéo qu'on vient de regarder. Rattaché au
      // cours, il serait introuvable dès le dixième chapitre.
      final autre = await contenu.addChapter(
        courseId: await unCours(videoPaths: 'x'),
        title: 'Autre cours',
      );
      final autreVideo = await contenu.addItem(
        chapterId: autre,
        kind: CourseItemKind.video,
        title: 'Autre vidéo',
        localPath: '/data/cours/autre.mp4',
      );

      await contenu.comment(itemId: videoId, authorId: 'u_eleve', body: 'Ici.');
      expect(await contenu.commentsOf(autreVideo), isEmpty);
      expect(await contenu.commentsOf(videoId), hasLength(1));
    });
  });

  group('La vente reste cohérente avec le sommaire', () {
    test('un cours sans vidéo ne se publie pas', () async {
      // La règle existait avant les chapitres et doit survivre : publier un
      // cours vide ferait payer un élève pour une page blanche.
      await expectLater(
        cours.create(teacherId: 't_prof', title: 'Cours vide', price: 50000),
        throwsA(isA<VideoCourseException>()),
      );
    });
  });

  group('La limite de taille des vidéos', () {
    test('est plus haute que celle des documents, et le dit', () {
      // Une vidéo de vingt minutes ne tient pas dans 8 Mo ; la borne existe
      // quand même, parce que le fichier doit un jour monter depuis Conakry.
      expect(
        AppConstants.courseVideoMaxBytes,
        greaterThan(AppConstants.documentMaxBytes),
      );

      const refus = MediaTooLarge(
        sizeBytes: 120 * 1024 * 1024,
        maxBytes: AppConstants.courseVideoMaxBytes,
      );
      final message = '$refus';
      expect(message, contains('120.0 Mo'));
      expect(message, contains('80 Mo'));
      // Le message dit quoi faire, pas seulement ce qui ne va pas.
      expect(message, contains('Decoupez'));
    });

    test('une ressource garde la limite documentaire', () {
      expect(
        AppConstants.courseResourceMaxBytes,
        AppConstants.documentMaxBytes,
      );
      const refus = MediaTooLarge(
        sizeBytes: 9 * 1024 * 1024,
        maxBytes: AppConstants.courseResourceMaxBytes,
      );
      expect('$refus', contains('8 Mo'));
    });
  });

  group('Le formulaire de création', () {
    final formulaire = File(
      'lib/presentation/screens/catalog/course_form_page.dart',
    ).readAsStringSync();

    test('n’invente plus de nom de fichier', () {
      // Avant : `_videos.add('video_${_videos.length + 1}.mp4')`. Le cours
      // partait en vente avec trois noms et aucun fichier.
      expect(formulaire, isNot(contains("video_\${_videos.length")));
      expect(formulaire, contains('pickCourseVideo'));
      expect(formulaire, contains('pickCourseResource'));
    });

    test('collecte des chapitres, pas une liste plate', () {
      expect(formulaire, contains('ExpansionTile'));
      expect(formulaire, contains('ChapterDraft'));
      expect(formulaire, contains('ItemDraft'));
      expect(formulaire, contains('writeChapters'));
      // Titre, vidéos et ressources dans chaque déroulant.
      expect(formulaire, contains('Titre du chapitre'));
      expect(formulaire, contains("const Text('Vidéo')"));
      expect(formulaire, contains("const Text('Ressource')"));
      expect(formulaire, contains("const Text('Lien')"));
    });

    test('refuse de publier un chapitre vide ou sans titre', () {
      expect(formulaire, contains('Donnez un titre au chapitre'));
      expect(formulaire, contains('est vide'));
    });

    test('la description du chapitre est annoncée sous la vidéo', () {
      // C'est là qu'elle s'affiche dans le lecteur : le dire dans le
      // formulaire évite qu'on y écrive un résumé du cours entier.
      expect(formulaire, contains("helperText: 'Affiché sous la vidéo'"));
    });
  });

  group('Le lecteur', () {
    final lecteur = File(
      'lib/presentation/screens/catalog/course_player_page.dart',
    ).readAsStringSync();

    test('ouvre les ressources au lieu de les afficher sans suite', () {
      // Une ligne qui ne fait rien au clic se lit comme une panne.
      expect(lecteur, contains('onRessource'));
      expect(lecteur, contains('OpenFilex.open'));
      // Sans `url_launcher`, copier le lien reste le geste le plus court.
      expect(lecteur, contains('Clipboard.setData'));
    });

    test('rend l’orientation et les barres en quittant le plein écran', () {
      // Sortir de l'écran sans les rendre laisserait le reste de
      // l'application couché et sans barre d'état.
      expect(lecteur, contains('if (_pleinEcran) _quitterLePleinEcran'));
    });
  });
}
