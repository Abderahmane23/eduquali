import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/data/remote/points_api.dart';

/// Concours, classement et points de fidélité (phase D1 et D4).
///
/// Trois sortes de contrôles, et la première est celle qui compte le plus :
/// **les routes que ce client appelle existent-elles côté serveur ?** C'est
/// exactement le défaut de `/sync/push` — un client qui postait depuis des mois
/// vers une route que le Worker n'exposait pas, les deux côtés cohérents avec
/// eux-mêmes, et rien pour le remarquer.
void main() {
  group('Le client et le serveur parlent de la même chose', () {
    test('chaque route appelée existe dans le Worker', () {
      final client = File('lib/data/remote/points_api.dart').readAsStringSync();
      final worker = File(
        '../../backend/api/[[...route]].ts',
      ).readAsStringSync();

      // Les chemins littéraux du client, interpolation comprise : un
      // `/contests/$id/leaderboard` devient le motif `/contests/:id/leaderboard`
      // tel que Hono le déclare.
      final chemins = <String>{};
      for (final trouve in RegExp(
        r"""(?:_objet|_poster)\(\s*'([^']+)'|_dio\.\w+<.*?>\(\s*'([^']+)'""",
      ).allMatches(client)) {
        final brut = trouve.group(1) ?? trouve.group(2)!;
        chemins.add(brut.replaceAll(RegExp(r'\$\w+'), ':id'));
      }

      /*
       * Un plancher, pas seulement « non vide ».
       *
       * Le motif a déjà été aveugle une fois : `[^>]*` ne traversait pas
       * `Map<String, dynamic>`, donc les deux routes de favoris n'étaient pas
       * vérifiées — et le test passait, sur les sept autres. Un contrôle de
       * parité qui rate la moitié des chemins est pire qu'absent, puisqu'il
       * rassure.
       */
      expect(
        chemins.length,
        greaterThanOrEqualTo(8),
        reason:
            'seulement ${chemins.length} chemins détectés (${chemins.join(', ')}) : '
            'le motif de lecture ne voit plus tous les appels',
      );

      for (final chemin in chemins) {
        expect(
          worker.contains("'$chemin'"),
          isTrue,
          reason:
              'le téléphone appelle « $chemin » et le serveur ne l’expose pas. '
              'Sans cette vérification, l’écran resterait vide sans erreur, '
              'comme /sync/push pendant des mois.',
        );
      }
    });

    test('l’écran est atteignable', () {
      // Une route sans porte d'entrée est du code mort : un concours sans
      // public ne publie jamais son classement.
      final dashboard = File(
        'lib/presentation/screens/dashboards/parent_dashboard.dart',
      ).readAsStringSync();
      expect(dashboard.contains('Routes.contests'), isTrue);

      final router = File(
        'lib/presentation/router/app_router.dart',
      ).readAsStringSync();
      expect(router.contains('ContestsPage()'), isTrue);
    });
  });

  group('Le classement, tel que l’écran le lit', () {
    test('un podium fermé ne se laisse pas ouvrir par défaut', () {
      /*
       * Le contrôle le plus important de ce groupe.
       *
       * `published` manquant, nul, la chaîne « false », zéro : rien de tout
       * cela ne doit ouvrir le podium. Un podium ouvert par défaut annoncerait
       * un classement **national** sur trois copies — pas une approximation,
       * une affirmation fausse sur le pays.
       */
      for (final valeur in [null, 'false', 0, '', 'true']) {
        final vue = Leaderboard.fromJson({
          'published': ?valeur,
          'participants': 3,
          'missing': 7,
        });
        expect(
          vue.published,
          isFalse,
          reason: '« $valeur » ne doit pas publier le classement',
        );
      }

      // Seul le booléen vrai ouvre.
      expect(Leaderboard.fromJson({'published': true}).published, isTrue);
    });

    test('le rang personnel survit à un podium fermé', () {
      // C'est ce que l'élève vient chercher, et son rang est honnête quel que
      // soit le nombre de participants.
      final vue = Leaderboard.fromJson({
        'published': false,
        'participants': 4,
        'missing': 6,
        'me': {'rank': 2, 'score': 80},
        'podium': <dynamic>[],
      });
      expect(vue.myRank, 2);
      expect(vue.myScore, 80);
      expect(vue.podium, isEmpty);
      expect(vue.missing, 6);
    });

    test('un participant sans nom garde une place lisible', () {
      final vue = Leaderboard.fromJson({
        'published': true,
        'podium': [
          {'rank': 1, 'score': 95},
        ],
      });
      expect(vue.podium.single.firstName, 'Participant');
    });

    test('n’avoir pas participé n’est pas une erreur', () {
      final vue = Leaderboard.fromJson({'published': true, 'participants': 12});
      expect(vue.myRank, isNull);
    });
  });

  group('Les points', () {
    test('un compte neuf lit zéro, pas une erreur', () {
      // Aucune ligne au journal = aucun point encore gagné. C'est l'état de
      // tout compte neuf.
      final solde = PointsBalance.fromJson({});
      expect(solde.balance, 0);
      expect(solde.entries, 0);
    });

    test('chaque ligne porte sa raison en clair', () {
      final lignes = PointEntry.listFromJson({
        'entries': [
          {
            'id': 'pl-1',
            'delta': 60,
            'reason': 'Concours de maths — 2e place',
            'created_at': '2026-10-03T10:00:00.000Z',
          },
        ],
      });
      // « Un solde qui monte sans raison lisible ne motive pas » : la raison est
      // destinée à l'élève, et c'est elle que l'écran affiche en titre.
      expect(lignes.single.reason, 'Concours de maths — 2e place');
      expect(lignes.single.delta, 60);
    });

    test('une dépense se distingue d’un gain par le signe', () {
      final lignes = PointEntry.listFromJson({
        'entries': [
          {'id': 'a', 'delta': -20, 'reason': 'Correction : concours annulé'},
        ],
      });
      expect(lignes.single.delta, -20);
    });
  });

  group('Un concours', () {
    test('un état inconnu ne l’ouvre pas', () {
      // L'état vient du serveur et jamais des dates : l'horloge d'un téléphone
      // d'occasion est souvent fausse de plusieurs heures, et un concours
      // s'ouvrirait au mauvais moment selon l'appareil.
      for (final etat in [null, 'PEUT_ETRE', '']) {
        final concours = Contest.fromJson({
          'id': 'c1',
          'title': 'Concours',
          'state': ?etat,
        });
        expect(concours.isOpen, isFalse, reason: 'état « $etat »');
      }
      expect(Contest.fromJson({'state': 'OPEN'}).isOpen, isTrue);
    });
  });

  group('La boutique', () {
    test('chaque lot du référentiel a bien son illustration embarquée', () {
      /*
       * Le contrôle que l'épisode `assets/scheduling` a rendu obligatoire.
       *
       * Un fichier écrit dans `assets/` mais absent du bundle — ou nommé
       * autrement que ce que le code demande — ne se voit qu'à l'exécution, sur
       * l'écran de quelqu'un, sous la forme d'une image cassée. Ici le nom vient
       * du référentiel et le chemin du modèle : les deux doivent se rejoindre.
       */
      final catalogue =
          jsonDecode(File('assets/seed/catalog.json').readAsStringSync())
              as Map<String, dynamic>;
      final lots = (catalogue['shopItems'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

      expect(lots, isNotEmpty, reason: 'aucun lot dans le référentiel');

      var avecPhoto = 0;
      for (final lot in lots) {
        final item = ShopItem.fromJson({
          'id': lot['id'],
          'name': lot['name'],
          'image': lot['image'],
          'points_price': lot['pointsPrice'],
        });
        // Un lot sans photo est légitime — un forfait internet n'est pas un
        // objet. Ce qui ne l'est pas, c'est d'en déclarer une qui manque.
        if (!item.hasImage) continue;
        avecPhoto++;
        expect(
          File(item.assetPath).existsSync(),
          isTrue,
          reason:
              '« ${item.name} » demande ${item.assetPath}, qui n’existe pas. '
              'Relancer shared/onboarding/sync.mjs.',
        );
      }

      // Sans ce plancher, le jour où tous les lots perdraient leur `image` le
      // contrôle passerait en n'ayant rien vérifié du tout.
      expect(
        avecPhoto,
        greaterThanOrEqualTo(4),
        reason: 'aucune photo contrôlée : le référentiel en déclare-t-il ?',
      );
    });

    test('le dossier des illustrations est déclaré dans pubspec', () {
      // Les fichiers peuvent être là et ne pas être embarqués : c'est
      // exactement ce qui était arrivé à assets/scheduling/.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('assets/img/'), isTrue);
    });

    test('un lot inabordable ne se laisse pas échanger', () {
      // `affordable` vient du serveur et n'est jamais déduit du solde côté
      // client : le recalculer afficherait « Échanger » sur un lot que le
      // serveur refusera ensuite.
      final lot = ShopItem.fromJson({
        'id': 'x',
        'name': 'Lot',
        'image': 'lot-iphone-15',
        'points_price': 30000,
        'stock': 1,
      });
      expect(lot.affordable, isFalse, reason: 'absent = non abordable');
      expect(lot.inStock, isTrue);
    });

    test('un lot épuisé se distingue d’un lot trop cher', () {
      final epuise = ShopItem.fromJson({
        'id': 'x',
        'name': 'Lot',
        'image': 'i',
        'points_price': 10,
        'stock': 0,
        'affordable': true,
      });
      expect(epuise.affordable, isTrue);
      expect(epuise.inStock, isFalse);
    });

    test('la distance au lot suivant est lue, pas recalculée', () {
      final shop = Shop.fromJson({
        'balance': 5000,
        'nextId': 'lot_iphone_15',
        'missing': 25000,
        'items': [
          {
            'id': 'lot_iphone_15',
            'name': 'iPhone 15',
            'image': 'i',
            'points_price': 30000,
          },
        ],
      });
      expect(shop.balance, 5000);
      expect(shop.nextId, 'lot_iphone_15');
      expect(shop.missing, 25000);
    });

    test('une boutique vide ne casse pas l’écran', () {
      final shop = Shop.fromJson({});
      expect(shop.items, isEmpty);
      expect(shop.balance, 0);
      expect(shop.nextId, isNull);
    });
  });

  group('L’accueil universitaire', () {
    test('le rôle STUDENT ouvre son propre accueil', () {
      // `suitDesEnfants` masquait les sections « enfants » dans l'écran partagé.
      // Ce n'est plus la question : l'universitaire a désormais un accueil à
      // lui, et c'est la coquille qui choisit.
      final shell = File(
        'lib/presentation/screens/parent/parent_shell.dart',
      ).readAsStringSync();
      expect(shell.contains('UserRole.student'), isTrue);
      expect(shell.contains('StudentDashboard()'), isTrue);
    });

    test('les quatre sections sont dans l’ordre demandé', () {
      /*
       * L'ordre est une décision, pas une mise en page.
       *
       * Du plus utilisé au moins utilisé : on ouvre l'application pour
       * reprendre un cours, parfois pour écrire à un professeur, rarement pour
       * regarder un lot. Un test sur l'ordre empêche qu'une section ajoutée
       * plus tard se glisse en tête sans qu'on y pense.
       */
      final page = File(
        'lib/presentation/screens/dashboards/student_dashboard.dart',
      ).readAsStringSync();

      final ordre = ['_MesCours(', '_MesProfesseurs(', '_MesFavoris('];
      var precedent = -1;
      for (final section in ordre) {
        final place = page.indexOf(section);
        expect(place, greaterThan(precedent), reason: '$section mal placée');
        precedent = place;
      }
    });

    test('chaque section vide propose une porte de sortie', () {
      // Une liste vide sans bouton est un cul-de-sac : on referme
      // l'application.
      final page = File(
        'lib/presentation/screens/dashboards/student_dashboard.dart',
      ).readAsStringSync();
      expect('actionLabel:'.allMatches(page).length, greaterThanOrEqualTo(6));
    });

    test('le solde ne s’affiche pas avant d’être connu', () {
      // Montrer « 0 » en attendant le serveur ferait croire à un solde vide à
      // chaque ouverture — l'inverse de ce qu'une monnaie de fidélité doit
      // inspirer.
      final page = File(
        'lib/presentation/screens/dashboards/student_dashboard.dart',
      ).readAsStringSync();
      final pastille = page.substring(page.indexOf('class _SoldePastille'));
      expect(
        pastille.contains('if (solde == null) return const SizedBox.shrink()'),
        isTrue,
      );
    });
  });

  group('Le tirage au sort', () {
    test('un genre inconnu reste un achat direct, jamais un pari', () {
      // Le sens par défaut doit être le moins surprenant : on croit acheter
      // l'objet. Transformer un achat en mise par accident ferait perdre des
      // points à quelqu'un qui n'a rien demandé.
      for (final genre in [null, '', 'PEUT_ETRE']) {
        final lot = ShopItem.fromJson({
          'id': 'x',
          'name': 'Lot',
          'image': '',
          'points_price': 100,
          'kind': ?genre,
        });
        expect(lot.isRaffle, isFalse, reason: 'genre « $genre »');
      }
      expect(
        ShopItem.fromJson({'kind': 'RAFFLE', 'points_price': 1}).isRaffle,
        isTrue,
      );
    });

    test('les chances se lisent, elles ne se devinent pas', () {
      final lot = ShopItem.fromJson({
        'id': 'x',
        'name': 'Téléphone',
        'image': '',
        'points_price': 150,
        'kind': 'RAFFLE',
        'entries': 3,
        'draws_at': '2026-11-30T00:00:00.000Z',
      });
      expect(lot.entries, 3);
      expect(lot.drawsAt?.month, 11);
    });

    test('basculer un favori ne transforme pas un tirage en achat', () {
      // `withFavorite` reconstruit l'objet : oublier un champ changerait le
      // sens de la carte au moment où l'on touche le cœur.
      final tirage = ShopItem.fromJson({
        'id': 'x',
        'name': 'Téléphone',
        'image': '',
        'points_price': 150,
        'kind': 'RAFFLE',
        'entries': 2,
      });
      final apres = tirage.withFavorite(true);
      expect(apres.isRaffle, isTrue);
      expect(apres.entries, 2);
      expect(apres.favorite, isTrue);
    });

    test('la boutique annonce la dépense avant la mise, pas après', () {
      // Une mise perdue reste dépensée. L'apprendre après coup se vit comme un
      // vol, et c'est la plainte qu'on ne peut pas réparer.
      final page = File(
        'lib/presentation/screens/contests/shop_page.dart',
      ).readAsStringSync();
      final dialogue = page.substring(page.indexOf('Tenter ma chance ?'));
      expect(dialogue.contains('dépensés, que vous gagniez ou non'), isTrue);
    });
  });
}
