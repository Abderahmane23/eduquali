import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/presentation/theme/app_theme.dart';
import 'package:veriprof/presentation/widgets/marque.dart';

/// La charte EduQuali, vérifiée contre sa source.
///
/// --- Pourquoi ces tests existent ----------------------------------------
///
/// La charte est un fichier — `design/charte/tokens.json` — et la palette
/// Flutter en est une transcription. Deux copies d'une même palette divergent
/// à la première retouche, et le symptôme est une application qui
/// *ressemble* à la marque sans en être : c'est précisément ce que
/// « Fondements » reproche à l'état précédent, trois violets différents, un
/// dans le logo, un à la connexion, un sur le profil.
///
/// Les interdits, surtout, ne lèvent aucune erreur quand on les enfreint. Un
/// dégradé s'affiche. Une ombre s'affiche. C'est pour cela qu'ils sont
/// testés et non seulement écrits.
void main() {
  final charte =
      jsonDecode(File('../../design/charte/tokens.json').readAsStringSync())
          as Map<String, dynamic>;

  /// Les fichiers Dart de l'application, hors fichiers générés.
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.endsWith('.g.dart'))
      .toList();

  group('La palette est celle de la charte, valeur par valeur', () {
    /// `Color(0xFFRRGGBB)` → la chaîne `#RRGGBB`.
    String hex(Color c) {
      final v =
          ((c.a * 255).round() << 24) |
          ((c.r * 255).round() << 16) |
          ((c.g * 255).round() << 8) |
          (c.b * 255).round();
      return '#${(v & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    }

    /// Ce que la charte déclare, par nom et par thème.
    final tokens = {
      for (final t in charte['color']['tokens'] as List)
        t['name'] as String: (t['value'] as Map).cast<String, String>(),
    };

    /// Ce que le code déclare, sous les noms de la charte.
    final cahier = <String, Color>{
      'papier': AppColors.papier,
      'feuille': AppColors.feuille,
      'encre': AppColors.encre,
      'crayon': AppColors.crayon,
      'ligne': AppColors.ligne,
      'violette': AppColors.violette,
      'sur-violette': AppColors.surViolette,
      'violette-pale': AppColors.violettePale,
      'surligneur': AppColors.surligneur,
      'sur-surligneur': AppColors.surSurligneur,
      'surligneur-pale': AppColors.surligneurPale,
      'vert-fonce': AppColors.vertFonce,
      'rouge': AppColors.rouge,
      'sur-rouge': AppColors.surRouge,
      'rouge-pale': AppColors.rougePale,
      'rouge-fonce': AppColors.rougeFonce,
      'bon-point': AppColors.bonPoint,
      'sur-bon-point': AppColors.surBonPoint,
      'bon-point-pale': AppColors.bonPointPale,
      'bon-point-fonce': AppColors.bonPointFonce,
      'marque-violette': AppColors.marqueViolette,
      'marque-surligneur': AppColors.marqueSurligneur,
      'marque-encre': AppColors.marqueEncre,
      'marque-papier': AppColors.marquePapier,
    };

    test('les 24 couleurs de la charte sont déclarées', () {
      // Le garde-fou sur le garde-fou : si la charte gagne une couleur, ce
      // test le dit au lieu de la laisser manquer en silence.
      expect(cahier.keys.toSet(), tokens.keys.toSet());
    });

    for (final nom in cahier.keys) {
      test('`$nom` vaut sa valeur de charte', () {
        expect(
          hex(cahier[nom]!),
          tokens[nom]!['cahier']!.toLowerCase(),
          reason: '$nom s’est écarté de design/charte/tokens.json',
        );
      });
    }

    test('le thème Tableau porte les valeurs du second thème', () {
      final tableau = <String, Color>{
        'papier': AppColors.tableauPapier,
        'feuille': AppColors.tableauFeuille,
        'encre': AppColors.tableauEncre,
        'crayon': AppColors.tableauCrayon,
        'ligne': AppColors.tableauLigne,
        'violette': AppColors.tableauViolette,
        'sur-violette': AppColors.tableauSurViolette,
        'violette-pale': AppColors.tableauViolettePale,
        'surligneur-pale': AppColors.tableauSurligneurPale,
        'vert-fonce': AppColors.tableauVertFonce,
        'rouge': AppColors.tableauRouge,
        'sur-rouge': AppColors.tableauSurRouge,
        'rouge-pale': AppColors.tableauRougePale,
        'rouge-fonce': AppColors.tableauRougeFonce,
        'bon-point-pale': AppColors.tableauBonPointPale,
        'bon-point-fonce': AppColors.tableauBonPointFonce,
      };
      for (final nom in tableau.keys) {
        expect(hex(tableau[nom]!), tokens[nom]!['tableau']!.toLowerCase());
      }
    });

    test('le surligneur et le bon point ne changent pas de thème', () {
      // Un surligneur reste un surligneur sur un tableau noir.
      for (final nom in ['surligneur', 'bon-point', 'sur-surligneur']) {
        expect(
          tokens[nom]!['cahier'],
          tokens[nom]!['tableau'],
          reason: '$nom change de thème dans la charte : le code doit suivre',
        );
      }
    });
  });

  group('Les interdits de la charte', () {
    /// Le code d'un fichier, commentaires retirés.
    ///
    /// Sans cela, un commentaire qui *explique* qu'un dégradé a été retiré
    /// fait échouer le test qui cherche le dégradé — et le dernier mot
    /// resterait à la prose.
    String codeDe(File f) => f
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
        .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
        .replaceAll(RegExp(r'///.*$', multiLine: true), '');

    test('aucun dégradé', () {
      /*
       * « Pas d'ombre, pas de dégradé, pas de carte à bord coloré. »
       *
       * Un aplat s'imprime, pèse moins et vieillit mieux ; le dégradé violet
       * est le décor par défaut de milliers d'applications, donc il ne
       * distingue rien. C'est l'interdit le plus visible et le plus facile à
       * réintroduire sans y penser.
       */
      final coupables = <String>[];
      for (final f in sources) {
        final code = codeDe(f);
        for (final m in RegExp(
          r'(Linear|Radial|Sweep)Gradient\((?:[^()]|\([^()]*\))*\)',
          dotAll: true,
        ).allMatches(code)) {
          /*
           * --- Ce qui est interdit, et ce qui ne l'est pas --------------
           *
           * La charte vise le decor : un degrade fait de couleurs de marque,
           * « le decor par defaut de milliers d'applications ». Il ne
           * distingue rien et il vieillit mal.
           *
           * Un voile noir transparent sur une video n'est pas de ce
           * registre. Il ne porte aucune couleur de marque et il ne decore
           * pas : sans lui, le fil de discussion en blanc devient illisible
           * des qu'une image claire passe derriere, et l'assombrir d'un
           * aplat uniforme couvrirait toute la video au lieu de la seule
           * bande ou le texte se pose.
           *
           * Le test porte donc sur les arrets : un degrade qui nomme
           * `AppColors` est du decor, et il tombe.
           */
          if (m.group(0)!.contains('AppColors.')) {
            final ou = f.path.replaceAll(r'\', '/').replaceFirst('lib/', '');
            coupables.add('$ou : ${m.group(1)}Gradient');
          }
        }
      }
      expect(
        coupables,
        isEmpty,
        reason:
            'un dégradé est revenu dans ${coupables.length} fichier(s) :\n'
            '${coupables.join('\n')}',
      );
    });

    test('aucune ombre', () {
      final coupables = <String>[];
      for (final f in sources) {
        final code = codeDe(f);
        // `AppShadows` est toléré : les trois listes sont vides, et les
        // emplois restants ne dessinent rien. Ce qui est interdit, c'est une
        // ombre écrite à la main ou une élévation Material.
        if (RegExp(r'BoxShadow\(').hasMatch(code) ||
            RegExp(r'elevation:\s*[1-9]').hasMatch(code)) {
          coupables.add(f.path.replaceAll(r'\', '/').replaceFirst('lib/', ''));
        }
      }
      expect(
        coupables,
        isEmpty,
        reason:
            'une ombre est revenue dans ${coupables.length} fichier(s) :\n'
            '${coupables.join('\n')}',
      );
    });

    test('le surligneur n’est jamais une couleur de texte', () {
      /*
       * « Jamais un bouton. Jamais du texte. » C'est ce qui garde au signe sa
       * valeur : s'il devient une couleur de bouton, il cesse de dire « voici
       * ce qui compte » et dit « appuyez ici ».
       *
       * Et c'est aussi une question de contraste : du vert clair sur du clair
       * ne passe aucun plancher, alors que du texte sombre sur un aplat de
       * surligneur atteint 11:1. Le widget [Surlignage] fait exactement ça.
       */
      final coupables = <String>[];
      for (final f in sources) {
        if (f.path.endsWith('app_colors.dart')) continue;
        if (f.path.endsWith('marque.dart')) continue;
        final code = codeDe(f);
        if (RegExp(
          r'color:\s*AppColors\.(surligneur|accent)\b(?!\s*,\s*//)',
        ).hasMatch(code)) {
          // `color:` d'une décoration est un fond, ce qui est permis. On ne
          // retient que ce qui est posé dans un `TextStyle`.
          for (final m in RegExp(
            r'TextStyle\([^)]*color:\s*AppColors\.(surligneur|accent)',
            dotAll: true,
          ).allMatches(code)) {
            coupables.add(
              '${f.path.replaceFirst('lib/', '')} : ${m.group(0)!.split('\n').last.trim()}',
            );
          }
        }
      }
      expect(
        coupables,
        isEmpty,
        reason: 'du texte en surligneur :\n${coupables.join('\n')}',
      );
    });

    test('pas d’orange : il reste au bouton Orange Money', () {
      // Orange Money possède cette couleur dans l'esprit d'un utilisateur
      // guinéen. L'employer ailleurs ferait croire à un paiement.
      final palette = File(
        'lib/core/theme/app_colors.dart',
      ).readAsStringSync().toLowerCase();
      expect(palette.contains('orange'), isFalse);
    });
  });

  group('Les trois polices', () {
    test('sont déclarées dans pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final famille in ['Gabarito', 'Lexend', 'Playwrite FR Moderne']) {
        expect(
          pubspec,
          contains('family: $famille'),
          reason: '$famille n’est pas embarquée',
        );
      }
    });

    test('les fichiers sont là, et en TTF', () {
      /*
       * Le système de design les publie en woff2 : c'est le format du web. Le
       * moteur Flutter ne lit que TTF, OTF et TTC sur Android — un woff2
       * déclaré dans `pubspec.yaml` ne lève aucune erreur, il ne s'affiche
       * simplement pas, et l'application retombe sur la police du système.
       *
       * C'est exactement le genre de panne silencieuse que ce projet
       * rencontre partout, d'où ce test.
       */
      for (final f in (charte['type']['fonts'] as List)) {
        final nom = (f['file'] as String).split('/').last.replaceAll(
          '.woff2',
          '.ttf',
        );
        expect(
          File('assets/fonts/$nom').existsSync(),
          isTrue,
          reason: 'assets/fonts/$nom manque',
        );
      }
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec.contains('.woff2'),
        isFalse,
        reason: 'un woff2 déclaré ne s’affichera pas sur Android',
      );
    });

    test('Poppins et Inter ont quitté le thème', () {
      // « Inter est la police de très nombreuses applications. Les deux
      // nouvelles ont été dessinées pour l'enseignement. »
      final theme = File(
        'lib/presentation/theme/app_theme.dart',
      ).readAsStringSync();
      expect(theme, contains("fontTitre = 'Gabarito'"));
      expect(theme, contains("fontTexte = 'Lexend'"));
      // La constante dépréciée reste, pour les emplois qui subsistent ; ce
      // qui ne doit plus exister, c'est la *valeur* Poppins.
      expect(theme.contains("'Poppins'"), isFalse);
    });
  });

  group('Les deux thèmes', () {
    /*
     * --- Pourquoi ce groupe existe -------------------------------------
     *
     * La charte tient deux thèmes, Cahier et Tableau. Les écrire tous les
     * deux à la main aurait donné trois cents lignes en double, et ce code a
     * déjà payé cette dérive : la palette vivait en deux exemplaires, les
     * corrections de contraste étaient appliquées à l'une pendant que
     * soixante fichiers affichaient l'autre, restée à 2,7:1.
     *
     * Les deux sont donc construits par la même fonction, à partir de deux
     * palettes. Ces tests vérifient que la fonction s'applique vraiment aux
     * deux — un `AppColors.X` oublié dans le corps du thème donnerait une
     * couleur claire sur le thème sombre, et ça s'affiche sans erreur.
     */
    test('les deux existent et ne sont pas le même', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(
        AppTheme.light.scaffoldBackgroundColor,
        isNot(AppTheme.dark.scaffoldBackgroundColor),
      );
    });

    test('chacun porte le papier de sa palette', () {
      expect(AppTheme.light.scaffoldBackgroundColor, AppColors.papier);
      expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.tableauPapier);
    });

    test('aucune couleur de Cahier ne traîne dans Tableau', () {
      /*
       * Le vrai piège. Le corps du thème nommait `AppColors.primary` ; s'il
       * en reste un seul, le thème sombre affiche la violette claire — et
       * personne ne le voit, parce que personne ne développe en mode sombre.
       *
       * On compare donc les couleurs qui doivent différer, une par une.
       */
      final sombre = AppTheme.dark;
      final clair = AppTheme.light;

      expect(sombre.colorScheme.primary, AppColors.tableauViolette);
      expect(clair.colorScheme.primary, AppColors.violette);
      expect(sombre.colorScheme.onSurface, AppColors.tableauEncre);
      expect(sombre.colorScheme.error, AppColors.tableauRouge);
      expect(sombre.dividerTheme.color, AppColors.tableauLigne);
      expect(sombre.cardTheme.color, AppColors.tableauFeuille);
    });

    test('le corps du thème ne nomme plus que la palette', () {
      // Les seize couleurs qui varient passent par `p.` ; celles qui ne
      // varient pas — surligneur, bon point, couleurs de marque — restent
      // nommées en dur, et c'est correct.
      final theme = File(
        'lib/presentation/theme/app_theme.dart',
      ).readAsStringSync();
      final corps = theme.substring(
        theme.indexOf('static ThemeData _construire('),
        theme.indexOf('static OutlineInputBorder _fieldBorder('),
      );
      final restes = RegExp(r'AppColors\.(\w+)')
          .allMatches(corps)
          .map((m) => m.group(1)!)
          .where(
            (n) =>
                !n.startsWith('marque') &&
                !n.startsWith('tableau') &&
                n != 'surligneur' &&
                n != 'surSurligneur' &&
                n != 'bonPoint' &&
                n != 'surBonPoint' &&
                n != 'onHeroMuted' &&
                n != 'onHeroSurface' &&
                n != 'onHeroBorder',
          )
          .toSet();
      expect(
        restes,
        isEmpty,
        reason:
            'ces couleurs ne suivront pas le thème Tableau : $restes',
      );
    });
  });

  group('Le logo', () {
    /*
     * --- Pourquoi ces tests ---------------------------------------------
     *
     * Un chemin d'asset faux ne leve rien a la compilation : il leve a
     * l'execution, sur l'ecran de connexion, chez l'usager. Et une variante
     * oubliee dans `pubspec.yaml` ne se voit qu'au moment ou quelqu'un ouvre
     * l'ecran qui l'emploie.
     */
    test('les six fichiers de la charte sont la', () {
      for (final nom in [
        'eduquali-logo.svg',
        'eduquali-logo-inverse.svg',
        'eduquali-logo-encre.svg',
        'eduquali-icone-app.svg',
        'eduquali-symbole.svg',
        'eduquali-symbole-inverse.svg',
      ]) {
        expect(
          File('assets/logos/$nom').existsSync(),
          isTrue,
          reason: 'assets/logos/$nom manque',
        );
      }
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('assets/logos/'),
        reason: 'le dossier des logos n’est pas embarque',
      );
    });

    test('chaque variante pointe vers un fichier qui existe', () {
      // Les chemins sont ecrits dans les constructeurs de `AppLogo`. On les
      // relit plutot que de les recopier : une faute de frappe dans le
      // widget passerait a cote d'une liste ecrite a la main ici.
      final source = File(
        'lib/presentation/widgets/app_logo.dart',
      ).readAsStringSync();
      final chemins = RegExp(r"'(assets/logos/[^']+)'")
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();
      expect(chemins.length, greaterThanOrEqualTo(6));
      for (final chemin in chemins) {
        expect(
          File(chemin).existsSync(),
          isTrue,
          reason: '$chemin est nomme par AppLogo et n’existe pas',
        );
      }
    });

    test('la toque de diplome a disparu', () {
      /*
       * « La toque est le signe de presque toutes les applications
       * scolaires. Elle parle du diplome, alors qu'EduQuali vend la
       * presence. » C'est l'un des quatre changements que « Fondements »
       * justifie un par un, et le plus facile a reintroduire sans y penser.
       */
      for (final nom in ['eduquali-symbole.svg', 'eduquali-icone-app.svg']) {
        final svg = File('assets/logos/$nom').readAsStringSync();
        // Le symbole est un anneau et un triangle : deux formes, pas
        // davantage. Une toque en ajouterait au moins une.
        final formes = RegExp(r'<(circle|rect|path|polygon)')
            .allMatches(svg)
            .length;
        expect(
          formes,
          lessThanOrEqualTo(3),
          reason: '$nom porte $formes formes : une toque est revenue ?',
        );
      }
    });

    test('les PNG detoures ne sont plus employes', () {
      // Trois PNG rasterises laissaient un halo blanc sur fond colore et
      // bavaient sur un ecran dense. Ils sont remplaces par les vectoriels.
      final source = File(
        'lib/presentation/widgets/app_logo.dart',
      ).readAsStringSync();
      expect(source.contains('logo_mark.png'), isFalse);
      expect(source.contains('logo_wordmark.png'), isFalse);
    });
  });

  group('Les formes', () {
    test('les cinq rayons', () {
      final attendu = {
        for (final r in charte['radius']['tokens'] as List)
          r['name'] as String: double.parse(
            (r['value'] as String).replaceAll('px', ''),
          ),
      };
      expect(AppRadius.rayonPlace, attendu['rayon-place']);
      expect(AppRadius.rayonChamp, attendu['rayon-champ']);
      expect(AppRadius.rayonBouton, attendu['rayon-bouton']);
      expect(AppRadius.rayonCarte, attendu['rayon-carte']);
      expect(AppRadius.rayonPastille, attendu['rayon-pastille']);
    });

    test('les deux traits', () {
      final attendu = {
        for (final t in charte['trait']['tokens'] as List)
          t['name'] as String: double.parse(
            (t['value'] as String).replaceAll('px', ''),
          ),
      };
      expect(AppTrait.fin, attendu['trait-fin']);
      expect(AppTrait.fort, attendu['trait-fort']);
    });

    test('les sept espaces et les deux cibles', () {
      final attendu = {
        for (final e in charte['spacing']['tokens'] as List)
          e['name'] as String: double.parse(
            (e['value'] as String).replaceAll('px', ''),
          ),
      };
      expect(AppSpacing.espace1, attendu['espace-1']);
      expect(AppSpacing.espace2, attendu['espace-2']);
      expect(AppSpacing.espace3, attendu['espace-3']);
      expect(AppSpacing.espace4, attendu['espace-4']);
      expect(AppSpacing.espace5, attendu['espace-5']);
      expect(AppSpacing.espace6, attendu['espace-6']);
      expect(AppSpacing.espace7, attendu['espace-7']);
      expect(AppSpacing.cible, attendu['cible']);
      expect(AppSpacing.ciblePrincipale, attendu['cible-principale']);
    });
  });

  group('La classe de quinze', () {
    testWidgets('quinze places, jamais plus, jamais moins', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Quinze(prises: 12, mienne: 12, libelle: '12 places sur 15'),
          ),
        ),
      );
      // Quinze places exactement, quel que soit le nombre de prises.
      expect(find.byType(DecoratedBox), findsNWidgets(15));
    });

    testWidgets('un nombre hors bornes ne casse pas les trois rangs', (
      tester,
    ) async {
      // Une séance de seize places n'existe pas. Si une donnée en annonce
      // dix-huit, le dessin reste à quinze plutôt que de déborder.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Quinze(prises: 18, libelle: 'complet')),
        ),
      );
      expect(find.byType(DecoratedBox), findsNWidgets(15));
      expect(tester.takeException(), isNull);
    });

    testWidgets('la phrase est toujours là, pour qui ne voit pas l’image', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Quinze(prises: 3, libelle: 'Il reste 12 places')),
        ),
      );
      expect(
        find.bySemanticsLabel('Il reste 12 places'),
        findsOneWidget,
        reason: 'un carré de couleur seul ne dit pas combien de places restent',
      );
    });
  });

  group('Le surlignage', () {
    testWidgets('le texte posé dessus est sombre, dans les deux thèmes', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Surlignage('est là'))),
      );
      final texte = tester.widget<Text>(find.text('est là'));
      expect(
        texte.style!.color,
        AppColors.surSurligneur,
        reason: 'l’encre s’éclaircit sur le thème Tableau et deviendrait '
            'illisible sur le vert',
      );
    });

    testWidgets('une affiche ne surligne qu’un passage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Affiche(
              avant: 'Trouvez le ',
              surligne: 'professeur',
              apres: ' qu’il vous faut',
            ),
          ),
        ),
      );
      expect(find.byType(Surlignage), findsOneWidget);
    });
  });

  group('La preuve de présence', () {
    /*
     * --- Ce que ces tests protègent -----------------------------------
     *
     * « Votre enfant était là. Vous le voyez. » C'est la promesse faite au
     * parent, et la seule chose qu'il vient chercher. Elle tient à trois
     * choses qui peuvent casser sans bruit : le chiffre doit venir du
     * serveur, il doit se dire en minutes et non en pourcentage, et ce qui
     * manque doit se dire avec le moyen de le rattraper.
     */
    /*
     * Les sources **sans leurs commentaires**.
     *
     * Un test qui cherche une tournure interdite la trouve dans le
     * commentaire qui explique pourquoi on ne l'emploie pas — c'est arrivé
     * trois fois dans cette journée, et chaque fois le dernier mot restait à
     * la prose plutôt qu'au code.
     */
    String codeDe(String chemin) => File(chemin)
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
        // `$` et non `\$` : dans une chaine brute Dart, `\$` vaut un dollar
        // litteral, et le motif exigeait alors un `$` en fin de ligne. Aucun
        // commentaire n'etait retire, et le test echouait sur sa propre
        // prose — la quatrieme fois aujourd'hui que ce piege se referme.
        .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
        .replaceAll(RegExp(r'///.*$', multiLine: true), '')
        /*
         * Les chaines collees bout a bout sont recollees.
         *
         * Dart concatene deux litteraux voisins : `'sont sur '` suivi de
         * `'l'enregistrement.'` forme une seule phrase a l'execution, mais
         * deux morceaux dans le fichier. Un test qui cherche la phrase
         * entiere ne la trouvait donc pas — et la seule facon de le faire
         * passer aurait ete de reecrire le code pour tenir sur une ligne,
         * c'est-a-dire de laisser le test commander la mise en forme.
         */
        .replaceAll(RegExp("'" + r'\s*\n\s*' + "'"), '');

    /*
     * --- Ou vit la preuve depuis le 14/10 -------------------------------
     *
     * La ligne du temps etait posee en entier sur la carte d'une seance.
     * Elle y tenait, mais la carte sert a retrouver un cours — l'heure, la
     * matiere, la rediffusion — et la charte veut un ecran entier pour la
     * preuve : « c'est le coeur de la promesse, il paie et il sait ».
     *
     * La carte garde la phrase et le chiffre, qui suffisent a savoir ; le
     * reste vit sur `/direct/<id>/presence`. Les deux fichiers sont donc
     * lus ensemble, et c'est ce que `famille` designe maintenant.
     */
    final carte = codeDe(
      'lib/presentation/screens/live/live_grid_page.dart',
    );
    final ecran = codeDe(
      'lib/presentation/screens/live/presence_proof_page.dart',
    );
    final famille = '$carte $ecran';
    final prof = codeDe(
      'lib/presentation/screens/live/teacher_live_page.dart',
    );

    test('la famille voit ses minutes, et la ligne du temps', () {
      expect(carte, contains('minutesAttended'));
      expect(ecran, contains('LigneDuTemps'));
      // « 52 minutes sur 60 », jamais « 87 % ».
      expect(famille, contains('minutes sur '));
    });

    test('l’ecran de preuve porte les trois faits de la charte', () {
      // L'heure d'arrivee, les points de controle, ce qui a ete travaille.
      // Trois, pas plus : « l'ecran ne montre ni note, ni classement, ni
      // comparaison avec les autres eleves ».
      expect(ecran, contains('joinedAt'));
      expect(ecran, contains('point'));
      expect(ecran, contains('checkpointsTotal'));
      // Et la mention qui fait tenir tout le reste.
      expect(ecran, contains('Compté par EduQuali, pas déclaré par l’élève'));
      // Jamais de note ni de classement.
      expect(ecran.contains('classement'), isFalse);
    });

    test('un seul bouton sur l’ecran de preuve', () {
      /*
       * « Un seul bouton : reserver la seance suivante. C'est le moment ou
       * le parent a confiance. » Ou, s'il manque des minutes, le rattrapage
       * passe devant — mais jamais les deux en bouton plein.
       */
      final pleins = RegExp(r'FilledButton\(').allMatches(ecran).length;
      expect(
        pleins,
        lessThanOrEqualTo(2),
        reason: 'un bouton principal par situation, pas davantage',
      );
    });

    test('rien ne s’affiche avant la séance', () {
      // Zéro minute sur une séance à venir n'est pas une absence : une ligne
      // vide se lirait comme un reproche avant même que le cours ait lieu.
      expect(famille, contains('seance.minutesAttended > 0'));
    });

    test('ce qui manque se dit avec le moyen de le rattraper', () {
      // « Vous étiez en retard » ne sert à rien ; « elles sont sur
      // l'enregistrement » si. C'est une règle explicite de la charte.
      expect(famille, contains('sur l’enregistrement'));
      expect(
        famille.contains('en retard'),
        isFalse,
        reason: 'un retard se dit avec l’heure d’arrivée, jamais en reproche',
      );
    });

    test('le professeur voit qui était là et qui ne l’était pas', () {
      expect(prof, contains('Qui était là'));
      expect(prof, contains('_Recapitulatif'));
      expect(prof, contains('LigneDuTemps'));
      // Les absents sont nommés : le professeur a besoin de savoir à qui
      // écrire, et la phrase propose la suite plutôt que de constater.
      expect(prof, contains('ne sont pas venus'));
      expect(prof, contains('L’enregistrement reste'));
    });

    test('aucun pourcentage de présence, nulle part', () {
      /*
       * « Aïssatou a suivi 52 minutes sur 60 », pas « taux d'assiduité
       * 87 % ». Le premier se vérifie et se raconte le soir ; le second
       * demande de croire un calcul.
       */
      for (final source in [famille, prof]) {
        expect(
          RegExp(r"(assiduité|taux de présence)").hasMatch(source),
          isFalse,
          reason: 'un taux a remplacé un chiffre de minutes',
        );
      }
    });
  });

  group('La ligne du temps', () {
    testWidgets('un point de contrôle tous les quarts d’heure, pas à la fin', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LigneDuTemps(minutesSuivies: 52, minutesTotales: 60),
          ),
        ),
      );
      // 15, 30 et 45 : celui de 60 n'existe pas, la séance s'arrête et il n'y
      // a rien à vérifier.
      expect(find.text('15 min'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('45 min'), findsOneWidget);
      expect(find.text('60 min'), findsNothing);
    });

    testWidgets('le chiffre part dans la description, pas un pourcentage', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LigneDuTemps(minutesSuivies: 52, minutesTotales: 60),
          ),
        ),
      );
      // « Aïssatou a suivi 52 minutes sur 60 », jamais « taux d'assiduité
      // 87 % ».
      expect(find.bySemanticsLabel('52 minutes sur 60'), findsOneWidget);
    });
  });
}
