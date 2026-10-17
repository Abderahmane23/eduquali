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
import 'package:veriprof/presentation/screens/contests/shop_page.dart';
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
        home: RepaintBoundary(key: _cadre, child: ecran),
      ),
    ),
  );
  // Deux passes : la première monte l'écran, la seconde laisse les lectures
  // asynchrones se poser.
  await tester.pumpAndSettle();
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
