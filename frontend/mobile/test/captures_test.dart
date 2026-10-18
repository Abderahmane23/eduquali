@Tags(['captures'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:veriprof/core/network/api_client.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/core/security/secure_store.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/local/seed/database_seeder.dart';
import 'package:veriprof/data/remote/live_api.dart';
import 'package:veriprof/data/remote/points_api.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/sync/sync_engine.dart';
import 'package:veriprof/domain/entities/live_models.dart';
import 'package:veriprof/presentation/providers/core_providers.dart';
import 'package:veriprof/core/constants/app_enums.dart';
import 'package:veriprof/data/repositories/auth_repository.dart';
import 'package:veriprof/data/repositories/tutoring_repository.dart';
import 'package:veriprof/domain/usecases/tutoring_rules.dart';
import 'package:veriprof/presentation/providers/session_providers.dart';
import 'package:veriprof/presentation/screens/assistant/assistant_controller.dart';
import 'package:veriprof/presentation/screens/assistant/assistant_messages.dart';
import 'package:veriprof/presentation/screens/assistant/assistant_screen.dart';
import 'package:veriprof/presentation/screens/catalog/catalog_page.dart';
import 'package:veriprof/presentation/screens/catalog/course_player_page.dart';
import 'package:veriprof/presentation/screens/contests/shop_page.dart';
import 'package:veriprof/presentation/screens/dashboards/student_dashboard.dart';
import 'package:veriprof/presentation/screens/tutoring/book_tutoring_sheet.dart';
import 'package:veriprof/presentation/screens/live/live_grid_page.dart';
import 'package:veriprof/presentation/screens/live/presence_proof_page.dart';
import 'package:veriprof/presentation/theme/app_theme.dart';

/// Les captures de l'application, pour la présentation.
///
/// --- Pourquoi des goldens et non un émulateur ---------------------------
///
/// Une capture d'écran prise sur un téléphone demande un émulateur, un compte
/// ouvert, une séance passée dans la base et la bonne heure à l'horloge.
/// Quatre conditions à réunir pour une image, et aucune reproductible.
///
/// Un golden rend **le même arbre de widgets, par le même moteur Flutter**,
/// avec les vraies polices du projet et le vrai thème. Ce n'est pas un dessin
/// qui ressemble à l'application : c'est l'application, rendue hors
/// téléphone. Et comme c'est un test, une image qui cesse de correspondre à
/// l'écran se voit au lieu de vieillir en silence dans un dossier.
///
/// --- Comment les produire -----------------------------------------------
///
///     flutter test test/captures_test.dart --update-goldens
///
/// Les images sortent dans `test/captures/`. Le `@Tags(['captures'])` les
/// tient hors de la suite ordinaire : ce fichier fabrique des images, il ne
/// vérifie rien.
void main() {
  late AppDatabase db;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await DatabaseSeeder(db).seedIfNeeded();
    // `Fmt.time` passe par `DateFormat` : hors application, les donnees de
    // locale ne sont pas chargees et l'ecran leve avant de se dessiner.
    await initializeDateFormatting('fr_FR');
    await _chargerPolices();
  });

  tearDownAll(() => db.close());

  /*
   * Les quatre surcharges que tout ecran exige.
   *
   * Hors application, aucune ne peut se construire : la base est un fichier,
   * le magasin securise parle au trousseau du systeme, et `networkService`
   * leve en toutes lettres « doit etre surcharge ». Elles sont ici une fois,
   * et chaque capture ajoute seulement ce qui la concerne.
   */
  List<Override> socle() {
    final reseau = NetworkStatusService();
    return [
      databaseProvider.overrideWithValue(db),
      secureStoreProvider.overrideWithValue(SecureStore()),
      networkServiceProvider.overrideWithValue(reseau),
      syncEngineProvider.overrideWithValue(
        SyncEngine(
          database: db,
          network: reseau,
          api: SyncApi(buildApiClient(() async => null)),
          deviceId: 'captures',
        ),
      ),
    ];
  }

  testWidgets('la preuve de présence', (tester) async {
    await _poser(
      tester,
      taille: const Size(390, 844),
      overrides: [
        ...socle(),
        liveApiProvider.overrideWithValue(
          _FauxLiveApi(
            PresenceProof(
              sessionId: 's1',
              startsAt: DateTime.utc(2026, 10, 15, 17),
              durationMinutes: 60,
              minutesAttended: 52,
              checkpointsAnswered: 3,
              checkpointsTotal: 3,
              childName: 'Aïssatou',
              joinedAt: DateTime.utc(2026, 10, 15, 17, 8),
              title: 'Le théorème de Thalès',
              subject: 'Mathématiques',
              level: '10e année',
              replay: 'READY',
            ),
          ),
        ),
      ],
      ecran: const PresenceProofPage(sessionId: 's1'),
    );

    await _enregistrer(tester, 'preuve.png');
  });

  testWidgets('la grille des cours en direct', (tester) async {
    await _poser(
      tester,
      taille: const Size(390, 900),
      overrides: [
        ...socle(),
        liveApiProvider.overrideWithValue(_FauxLiveApi.grille(_seances())),
      ],
      ecran: const LiveGridPage(),
    );

    await _enregistrer(tester, 'direct.png');
  });

  testWidgets('la boutique en points', (tester) async {
    await _poser(
      tester,
      taille: const Size(390, 900),
      overrides: [
        ...socle(),
        pointsApiProvider.overrideWithValue(_FauxPointsApi()),
      ],
      ecran: const ShopPage(),
    );

    await _enregistrer(tester, 'boutique.png');
  });

  /*
   * Les cinq ecrans demandes pour la presentation.
   *
   * Une session d'eleve est posee pour chacun : sans elle, ces ecrans
   * s'affichent dans leur etat « personne n'est connecte » — une invitation
   * a ouvrir un compte, ce qui ne montre rien du produit.
   */
  AuthSession eleve() => AuthSession(
    userId: 'u_captures',
    role: UserRole.student,
    phone: '620000101',
    firstName: 'Aissatou',
    lastName: 'Barry',
    plan: 'MASTER',
    planRenewsAt: DateTime(2027, 1, 31),
  );

  testWidgets('l’accueil', (tester) async {
    await _poser(
      tester,
      taille: const Size(390, 1100),
      overrides: [
        ...socle(),
        currentSessionProvider.overrideWithValue(eleve()),
      ],
      ecran: const StudentDashboard(),
    );

    await _enregistrer(tester, 'accueil.png');
  });

  testWidgets('le catalogue des cours', (tester) async {
    await _poser(
      tester,
      taille: const Size(390, 1100),
      overrides: [
        ...socle(),
        currentSessionProvider.overrideWithValue(eleve()),
      ],
      ecran: const CatalogPage(),
    );

    await _enregistrer(tester, 'catalogue.png');
  });

  testWidgets('un cours, chapitres ouverts', (tester) async {
    await _poser(
      tester,
      taille: const Size(390, 1200),
      overrides: [
        ...socle(),
        currentSessionProvider.overrideWithValue(eleve()),
      ],
      ecran: const CoursePlayerPage(courseId: 'vc_math_fonctions'),
    );

    /*
     * Les chapitres sont des `ExpansionTile` : seul celui qui porte la video
     * courante s'ouvre de lui-meme. La demande est « chapitres ouverts » —
     * c'est le sommaire qui dit ce qu'on achete, et replie il ne dit rien.
     */
    for (var tour = 0; tour < 6; tour++) {
      final replies = find.byType(ExpansionTile);
      if (replies.evaluate().length <= tour) break;
      await tester.tap(replies.at(tour), warnIfMissed: false);
      for (var passe = 0; passe < 3; passe++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await _enregistrer(tester, 'cours.png');
  });

  testWidgets('la reservation d’un cours a domicile', (tester) async {
    /*
     * La reservation est une feuille modale : elle n'existe qu'ouverte
     * au-dessus d'un ecran. On pose donc un bouton qui l'ouvre, et on
     * capture une fois qu'elle est montee.
     */
    await _poser(
      tester,
      taille: const Size(390, 900),
      overrides: [
        ...socle(),
        currentSessionProvider.overrideWithValue(eleve()),
      ],
      ecran: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showBookTutoringSheet(context, _offreDemo()),
              child: const Text('Reserver'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Reserver'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    for (var passe = 0; passe < 8; passe++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    await _enregistrer(tester, 'reserver.png');
  });

  testWidgets('l’assistant, en conversation', (tester) async {
    await _poser(
      tester,
      taille: const Size(390, 1000),
      overrides: [
        ...socle(),
        currentSessionProvider.overrideWithValue(eleve()),
        assistantProvider.overrideWith((ref) => _ConversationJouee()),
      ],
      ecran: const AssistantScreen(),
    );

    await _enregistrer(tester, 'assistant.png');
  });
}

/// Une offre de cours a domicile, pour la capture de la reservation.
TutoringOffer _offreDemo() => const TutoringOffer(
  id: 'to_demo',
  teacherId: 't_diallo',
  teacherName: 'Mamadou Diallo',
  subjectId: 'sub_math',
  subjectName: 'Mathematiques',
  levelNames: ['10e annee'],
  mode: TutoringMode.atStudent,
  active: true,
  hourlyRate: 50000,
  city: 'Conakry',
  districts: ['Matam', 'Ratoma'],
  availabilityNote: 'Mardi et jeudi, a partir de 17 h',
  description:
      'Remise a niveau en mathematiques, du calcul litteral a la geometrie.',
);

/// L'assistant, avec une conversation deja tenue.
///
/// La capture doit montrer **l'assistant en train de servir**, pas son ecran
/// vide. Un ecran d'accueil ne dit pas ce que l'outil fait ; un echange le
/// dit en trois lignes. Les reponses sont ecrites ici et n'appellent aucun
/// modele : une capture ne doit dependre ni du reseau, ni d'une cle, ni de
/// ce qu'un modele aura envie de repondre ce jour-la.
class _ConversationJouee extends AssistantController {
  _ConversationJouee() : super(null) {
    state = const AssistantState(
      messages: [
        UserMessage(
          'Je n’ai pas compris le theoreme de Thales, le prof est alle vite',
        ),
        AssistantText(
          'On le prend par le dessin, c’est plus simple.\n\n'
          'Trace deux droites qui se croisent en A. Pose B et C sur la '
          'premiere, D et E sur la seconde, de sorte que (BD) et (CE) soient '
          'paralleles.\n\n'
          'Thales dit alors que les trois rapports AB/AC, AD/AE et BD/CE sont '
          'egaux. Autrement dit : si une figure est l’agrandissement d’une '
          'autre, **tout** est agrandi dans la meme proportion.\n\n'
          'Un exemple du programme de 10e : AB = 3 cm, AC = 7,5 cm, '
          'AD = 4 cm. Combien vaut AE ?',
        ),
        UserMessage('10 cm ?'),
        AssistantText(
          'Exact — et la methode est la bonne.\n\n'
          'AB/AC = 3/7,5 = 0,4. Donc AD/AE = 0,4, et AE = 4 / 0,4 = 10 cm.\n\n'
          'Le piege habituel est d’inverser le rapport et d’ecrire '
          'AE = 4 x 0,4 = 1,6 cm — un segment plus court que celui qu’on '
          'agrandit. Quand le resultat sort plus petit, c’est le signe que le '
          'rapport est a l’envers.\n\n'
          'Votre professeur fait un direct sur ce chapitre jeudi a 17 h. '
          'Voulez-vous que je vous y inscrive ?',
        ),
      ],
    );
  }
}

/// Un `PointsApi` qui ne parle à personne.
///
/// La boutique est la boucle de retour du produit : les points se gagnent en
/// suivant des cours — un toutes les cinq minutes de présence, et un par
/// réponse à un point de contrôle — et rien de tout cela ne se déclare. On
/// ne peut donc pas en moissonner en cliquant.
class _FauxPointsApi extends PointsApi {
  _FauxPointsApi() : super(Dio());

  @override
  Future<Shop> shop() async => const Shop(
    balance: 860,
    missing: 140,
    nextId: 'l2',
    items: [
      ShopItem(
        id: 'l1',
        name: 'Forfait 1 Go',
        summary: 'Orange ou MTN, au choix.',
        image: '',
        pointsPrice: 250,
        valueGnf: 25000,
        stock: 40,
        affordable: true,
      ),
      ShopItem(
        id: 'l2',
        name: 'Casque audio',
        summary: 'Pour suivre les séances au calme.',
        image: '',
        pointsPrice: 1000,
        valueGnf: 180000,
        stock: 6,
        affordable: false,
      ),
      ShopItem(
        id: 'l3',
        name: 'Calculatrice scientifique',
        summary: 'Celle du programme de 11e et 12e.',
        image: '',
        pointsPrice: 600,
        valueGnf: 95000,
        stock: 12,
        affordable: true,
      ),
      ShopItem(
        id: 'l4',
        name: 'Téléphone Android',
        summary: 'Tirage parmi les participants.',
        image: '',
        pointsPrice: 300,
        valueGnf: 1200000,
        stock: 1,
        affordable: true,
        kind: 'DRAW',
        entries: 48,
      ),
    ],
  );

  @override
  Future<PointsBalance> balance() async =>
      const PointsBalance(balance: 860, entries: 34);

  @override
  Future<List<ShopItem>> favorites() async => const [];
}

/// Une semaine de seances, telle que le serveur les rend.
///
/// Des matieres et des niveaux du programme guineen, des prix en francs, et
/// des places qui restent : ce sont les trois choses qu'on lit sur cette
/// grille avant de reserver.
List<LiveSessionSummary> _seances() {
  final base = DateTime.utc(2026, 10, 17, 17);
  const cours = [
    ('Mathématiques', '10e année', 'M. Diallo', 25000, 3, 'Équations du premier degré'),
    ('Physique', '11e année', 'Mme Bah', 30000, 7, 'Les forces et le mouvement'),
    ('Français', '10e année', 'M. Camara', 20000, 0, 'Le commentaire composé'),
    ('Histoire', '12e année', 'Mme Sylla', 25000, 11, 'La Guinée coloniale'),
  ];

  return [
    for (final (i, c) in cours.indexed)
      LiveSessionSummary(
        id: 's$i',
        courseId: 'c$i',
        slotId: 'soir',
        startsAt: base.add(Duration(days: i)),
        durationMinutes: 60,
        status: 'PLANNED',
        seatsLeft: c.$5,
        seats: 15,
        price: c.$4,
        subject: LiveRef(id: 'm$i', name: c.$1),
        level: LiveRef(id: 'n$i', name: c.$2),
        teacherId: 't$i',
        teacherName: c.$3,
        title: c.$6,
      ),
  ];
}

/// Les vraies polices du projet.
///
/// Sans cela, un test rend tout en « Ahem » — des rectangles noirs. Le golden
/// serait techniquement juste et illisible.
Future<void> _chargerPolices() async {
  const familles = {
    'Gabarito': [
      'assets/fonts/Gabarito-600.ttf',
      'assets/fonts/Gabarito-700.ttf',
      'assets/fonts/Gabarito-800.ttf',
    ],
    'Lexend': [
      'assets/fonts/Lexend-400.ttf',
      'assets/fonts/Lexend-500.ttf',
      'assets/fonts/Lexend-600.ttf',
    ],
    'Playwrite FR Moderne': ['assets/fonts/PlaywriteFRModerne-400.ttf'],
  };

  // Les icones. Sans cette police, chaque `Icon` sort en carre vide : le
  // golden serait techniquement juste et donnerait une application cassee.
  final icones = _policeIcones();
  if (!icones.existsSync()) {
    throw StateError('Police d’icônes introuvable : ${icones.path}');
  }
  final chargeurIcones = FontLoader('MaterialIcons');
  chargeurIcones.addFont(
    Future<ByteData>.value(ByteData.view(icones.readAsBytesSync().buffer)),
  );
  await chargeurIcones.load();

  for (final entree in familles.entries) {
    final chargeur = FontLoader(entree.key);
    for (final chemin in entree.value) {
      final fichier = File(chemin);
      if (!fichier.existsSync()) {
        throw StateError('Police introuvable : $chemin');
      }
      chargeur.addFont(
        Future<ByteData>.value(
          ByteData.view(fichier.readAsBytesSync().buffer),
        ),
      );
    }
    await chargeur.load();
  }
}

/// Le fichier de la police d'icones, dans le cache du SDK.
///
/// `flutter test` pose `FLUTTER_ROOT` dans l'environnement ; c'est la source
/// la plus sure. Deduire la racine de `Platform.resolvedExecutable` donnait
/// `<flutter>/bin` — l'executable du lanceur de tests n'est pas celui du
/// SDK Dart, et le chemin doublait « bin ».
File _policeIcones() {
  final racine = Platform.environment['FLUTTER_ROOT'];
  if (racine == null) {
    throw StateError('FLUTTER_ROOT absent : lancez par `flutter test`.');
  }
  return File(
    '$racine/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
}

/// Un écran, à la taille d'un téléphone, dans le thème de la charte.
Future<void> _poser(
  WidgetTester tester, {
  required Size taille,
  required Widget ecran,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = taille * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr', 'FR'),
        /*
         * Les animations sont coupees, et c'est ce qui rend la capture
         * possible.
         *
         * `SkeletonBox` pulse sans fin tant qu'une lecture n'est pas posee.
         * `pumpAndSettle` attend que plus rien ne bouge : devant une
         * pulsation perpetuelle il tournait douze minutes avant d'abandonner,
         * et la capture ne sortait pas.
         *
         * `disableAnimations` est le drapeau que l'application ecoute deja,
         * par `prefersLessMotion` : le squelette s'arrete alors sur un
         * rectangle fixe. On ne desactive donc rien de special pour le test,
         * on emprunte le chemin prevu pour qui demande moins de mouvement.
         */
        builder: (context, enfant) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: enfant!,
        ),
        /*
         * L'ecran est pose sur un `Material`, et sans lui rien ne se lit.
         *
         * Plusieurs ecrans rendent une liste nue : `StudentDashboard` est un
         * `RefreshIndicator` sur un `ListView`, sans `Scaffold`. Dans
         * l'application ils vivent dans une coquille qui apporte le
         * `Material` ; poses directement en `home`, ils n'en ont aucun.
         *
         * Or c'est le `Material` qui installe le `DefaultTextStyle` du
         * theme. Sans lui, `DefaultTextStyle.fallback()` s'applique : aucune
         * famille de police, et le moteur de test dessine **un rectangle par
         * glyphe**. La capture sortait couverte de pavés gris, avec juste
         * assez de texte lisible — le titre de l'en-tete, le libelle d'un
         * bouton, qui portent leur propre style — pour avoir l'air d'un
         * ecran en cours de chargement.
         *
         * Trois pistes ont ete ecartees avant celle-ci, et chacune par une
         * mesure : les polices se chargent bien (les cinq graisses de Lexend
         * rendent des lettres), Poppins n'est plus reference nulle part, et
         * `runAsync` ne change rien. C'est le contenant qui manquait, pas le
         * contenu.
         */
        home: Material(
          color: AppTheme.light.scaffoldBackgroundColor,
          child: RepaintBoundary(key: _cadre, child: ecran),
        ),
      ),
    ),
  );
  /*
   * Des passes comptees, et non `pumpAndSettle`.
   *
   * `pumpAndSettle` attend que plus rien ne bouge — sans borne utile. Trois
   * des cinq ecrans l'ont fait tourner dix minutes avant d'abandonner, sans
   * produire d'image ni nommer ce qui bougeait encore. Une capture qui peut
   * ne jamais sortir n'est pas un outil.
   *
   * Huit passes de 300 ms laissent les lectures de la base se poser et les
   * ouvertures de chapitre s'achever. Ce qui n'a pas fini a ce moment-la se
   * voit sur l'image — ce qui est le but : une capture doit montrer l'ecran
   * tel qu'il arrive, pas tel qu'on l'espere.
   */
  /*
   * `runAsync` d'abord, les passes ensuite — et l'ordre n'est pas un detail.
   *
   * `pump` avance l'horloge **du test**. Il ne laisse pas la base de donnees
   * repondre : Drift travaille sur un vrai isolat, et une requete reelle
   * demande du temps reel. Sans ce `runAsync`, les lectures restaient en
   * vol et les ecrans se capturaient sur leurs squelettes de chargement —
   * des rectangles gris, a la place de tout le contenu.
   *
   * Et comme les squelettes ne clignotaient plus (les animations sont
   * coupees), l'image avait l'air d'un ecran fini. C'est la forme que
   * prennent les pannes de ce projet : rien ne proteste, et le resultat est
   * vide.
   */
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 900)),
  );
  for (var passe = 0; passe < 8; passe++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// La frontiere de repeinte qui enferme l'ecran capture.
final _cadre = GlobalKey();

/// Ecrit l'ecran dans un fichier, a trois fois sa taille logique.
///
/// --- Pourquoi pas `matchesGoldenFile` ----------------------------------
///
/// Un golden est rendu a un pixel par point logique : l'image sortait en
/// 390 x 844, et posee sur une diapositive de 1 080 points elle etait floue.
/// `toImage(pixelRatio: 3)` repeint le **meme** arbre dans une image trois
/// fois plus fine — c'est la densite d'un telephone courant, et de quoi
/// imprimer la presentation.
Future<void> _enregistrer(WidgetTester tester, String nom) async {
  final frontiere =
      _cadre.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  late final ui.Image image;
  await tester.runAsync(() async {
    image = await frontiere.toImage(pixelRatio: 3);
  });

  final octets = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  );

  final dossier = Directory('test/captures');
  if (!dossier.existsSync()) dossier.createSync(recursive: true);
  File('${dossier.path}/$nom').writeAsBytesSync(
    octets!.buffer.asUint8List(),
  );
}

/// Un `LiveApi` qui ne parle à personne.
class _FauxLiveApi extends LiveApi {
  _FauxLiveApi(this.preuve) : seances = const [], super(Dio());

  _FauxLiveApi.grille(this.seances) : preuve = null, super(Dio());

  final PresenceProof? preuve;
  final List<LiveSessionSummary> seances;

  @override
  Future<PresenceProof> presenceProof(String sessionId) async => preuve!;

  @override
  Future<List<LiveSessionSummary>> sessions({
    String? subjectId,
    String? levelId,
    int? days,
  }) async => seances;

  @override
  Future<List<MySession>> mySessions() async => const [];
}
