import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/theme/app_colors.dart';

/// Lisibilité des couleurs (WCAG 2.2 AA).
///
/// « Plus de contraste » est une demande qui se vérifie : on calcule le
/// rapport réel plutôt que de se fier à l'œil sur un écran de bureau, qui
/// pardonne tout ce qu'un téléphone en plein soleil refuse.
double _luminance(Color c) {
  double channel(double v) {
    v = v / 255;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.r * 255) +
      0.7152 * channel(c.g * 255) +
      0.0722 * channel(c.b * 255);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final light = math.max(la, lb);
  final dark = math.min(la, lb);
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  // Les écrans posent du texte sur le fond de page ou sur une carte blanche.
  const page = AppColors.surfaceMuted;
  const card = AppColors.background;

  group('Texte lisible — plancher AA 4,5:1', () {
    const cases = {
      'texte principal sur carte': (AppColors.textPrimary, card),
      'texte principal sur page': (AppColors.textPrimary, page),
      'texte secondaire sur carte': (AppColors.textSecondary, card),
      'texte secondaire sur page': (AppColors.textSecondary, page),
      'mention discrète sur carte': (AppColors.textTertiary, card),
      'mention discrète sur page': (AppColors.textTertiary, page),
    };

    cases.forEach((label, pair) {
      test(label, () {
        final ratio = contrast(pair.$1, pair.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$label : ${ratio.toStringAsFixed(2)}:1',
        );
      });
    });
  });

  group('Bordures et icônes — plancher AA 3:1', () {
    test('bordure sur carte blanche', () {
      final ratio = contrast(AppColors.border, card);
      expect(
        ratio,
        greaterThanOrEqualTo(1.4),
        reason: 'bordure : ${ratio.toStringAsFixed(2)}:1',
      );
    });

    test('couleur principale sur blanc', () {
      expect(contrast(AppColors.primary, card), greaterThanOrEqualTo(4.5));
    });

    test('blanc sur couleur principale — texte des boutons pleins', () {
      expect(
        contrast(Colors.white, AppColors.primary),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('Tout ce qui se touche est atteignable', () {
    final sources = [
      for (final f in Directory('lib/presentation').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart')) f,
    ];

    test('chaque bouton-icône porte un nom pour le lecteur d’écran', () {
      // Sans `tooltip`, TalkBack annonce « bouton » et rien d'autre : la
      // personne doit deviner ce qu'elle déclenche.
      // Le nom doit commencer la : `HeroIconButton(` contient la meme
      // chaine, et c'est un autre composant — celui-la exige son infobulle
      // dans sa signature, ce qui est plus sur que ce controle.
      bool motEntier(String source, int start) =>
          start == 0 || !RegExp(r'[A-Za-z0-9_]').hasMatch(source[start - 1]);

      final muets = <String>[];
      for (final file in sources) {
        final source = file.readAsStringSync();
        var from = 0;
        while (true) {
          final start = source.indexOf('IconButton(', from);
          if (start < 0) break;
          if (!motEntier(source, start)) {
            from = start + 1;
            continue;
          }
          // On lit jusqu'au prochain `IconButton` : le `tooltip` peut venir
          // après l'`icon:`, donc s'arrêter à la première parenthèse
          // fermante déclarerait des faux coupables.
          var next = source.indexOf('IconButton(', start + 1);
          while (next > 0 && !motEntier(source, next)) {
            next = source.indexOf('IconButton(', next + 1);
          }
          final bloc = source.substring(start, next < 0 ? source.length : next);
          if (!bloc.contains('tooltip:')) muets.add(file.path);
          from = start + 1;
        }
      }
      expect(muets, isEmpty, reason: 'boutons muets : $muets');
    });

    test('la cible tactile minimale est posée une fois', () {
      // Calculer la hauteur à partir des marges et du texte donne un
      // résultat qui bouge dès qu'on touche à la typographie.
      final theme = File(
        'lib/presentation/theme/app_theme.dart',
      ).readAsStringSync();
      final match = RegExp(r'touchTarget = (\d+)').firstMatch(theme);
      expect(match, isNotNull);
      expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(44));
    });

    test('aucune contrainte de 40 px ne traîne', () {
      // Le plancher d'accessibilité est 44 : deux boutons étaient à 40.
      for (final file in sources) {
        final source = file.readAsStringSync();
        expect(
          source.contains('minHeight: 40,'),
          isFalse,
          reason: '${file.path} garde une cible sous le plancher',
        );
      }
    });
  });

  group('Les barres de score', () {
    test('une seule mesure, une seule teinte', () {
      // Ces barres portent le *meme* score sur plusieurs domaines, et le nom
      // du domaine est deja ecrit a cote. Leur donner une couleur chacune
      // n'ajoute rien et fait entrer cinq teintes en concurrence.
      final sources = [
        'lib/presentation/screens/teacher/certifications_screen.dart',
        'lib/presentation/screens/teacher/test_result_screen.dart',
      ];
      for (final path in sources) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('AppColors.chart['),
          isFalse,
          reason: '$path repeint une serie unique en arc-en-ciel',
        );
        expect(source.contains('AppColors.chartBar'), isTrue);
      }
    });

    test('la barre au repos se voit sur une carte blanche', () {
      // Plancher de 3:1 pour un element d'interface non textuel.
      expect(contrast(AppColors.chartBar, card), greaterThanOrEqualTo(3));
    });

    test('l’accent se distingue nettement du repos', () {
      // Sinon la barre mise en avant ne se remarque pas, et l'accent ne
      // sert a rien.
      expect(
        contrast(AppColors.chartHighlight, AppColors.chartBar),
        greaterThanOrEqualTo(1.6),
      );
    });
  });

  group('L’accent ne sert qu’à un mot de titre', () {
    // Il vit sur les fonds colorés, jamais sur du blanc : sur une carte il
    // tomberait à 1,5:1. C'est pour cela qu'il n'est ni un fond ni un
    // statut — les deux finiraient par porter du texte.
    test('lisible sur le dégradé, d’un bout à l’autre', () {
      // Plancher de 3:1, celui des grands textes : l'accent ne vit que dans
      // un titre de 34 px en 800. Exiger 4,5 ici obligerait à un dégradé si
      // sombre qu'il n'en serait plus un — et personne n'écrira du corps de
      // texte en jaune, puisque la règle l'interdit ailleurs.
      for (final fond in [AppColors.heroStart, AppColors.heroEnd]) {
        final ratio = contrast(AppColors.accent, fond);
        expect(
          ratio,
          greaterThanOrEqualTo(3),
          reason: 'accent sur le dégradé : ${ratio.toStringAsFixed(2)}:1',
        );
      }
    });

    test('lisible sur la surface marine', () {
      expect(
        contrast(AppColors.accent, AppColors.surfaceDark),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('le blanc tient aussi sur la surface marine', () {
      expect(
        contrast(Colors.white, AppColors.surfaceDark),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('il n’est jamais employé comme fond', () {
      // Un aplat jaune ne supporte ni le blanc (1,1:1) ni l'encre par
      // defaut : le poser en surface revient a promettre un endroit ou l'on
      // ne pourra rien ecrire.
      final fichiers = [
        for (final f in Directory('lib/presentation').listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart')) f,
      ];
      final coupables = <String>[];
      for (final file in fichiers) {
        final source = file.readAsStringSync();
        // Un fond se reconnait a son voisinage : une decoration ou une
        // propriete de remplissage, jamais une couleur de texte.
        final enFond = RegExp(
          r'(backgroundColor|fillColor|barrierColor):\s*AppColors\.accent'
          r'|BoxDecoration\([^)]*color:\s*AppColors\.accent',
          dotAll: true,
        );
        if (enFond.hasMatch(source)) coupables.add(file.path);
      }
      expect(coupables, isEmpty, reason: 'accent posé en fond : $coupables');
    });

    test('la bande de section reste une bande, pas une carte', () {
      // Assez pale pour porter du texte encre, assez marquee pour decouper
      // une page longue sans tracer de ligne.
      expect(
        contrast(AppColors.textPrimary, AppColors.bandSoft),
        greaterThanOrEqualTo(4.5),
      );
      expect(contrast(AppColors.background, AppColors.bandSoft), lessThan(1.2));
    });
  });

  group('Une seule palette', () {
    test('AppColors n’est definie qu’une fois', () {
      // Elle l'a ete deux fois : `core/theme/app_colors.dart` et une copie
      // dans `presentation/theme/app_theme.dart`. Les deux ont diverge —
      // les corrections de contraste allaient dans la premiere pendant que
      // soixante fichiers affichaient la seconde, restee a `textTertiary`
      // #9A9AAB, soit 2,7:1 sur blanc. Ce test passait, l'ecran non.
      final definitions = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.readAsStringSync().contains('class AppColors {')) {
          definitions.add(file.path);
        }
      }
      expect(
        definitions,
        hasLength(1),
        reason: 'la palette est redefinie : $definitions',
      );
    });

    test('le theme la re-exporte au lieu de la recopier', () {
      final theme = File(
        'lib/presentation/theme/app_theme.dart',
      ).readAsStringSync();
      expect(
        theme.contains("export '../../core/theme/app_colors.dart'"),
        isTrue,
      );
    });
  });

  group('Le fond de page se distingue des cartes', () {
    test('la page est teintée, les cartes sont blanches', () {
      // Sinon la carte ne se voit que par sa bordure, et l'ombre ne porte
      // sur rien.
      expect(page, isNot(card));
    });

    test('l’écart se voit sur un écran bon marché', () {
      // Le fond était à #F7F7FA, soit 2 % d'écart avec le blanc : invisible
      // sur un écran d'entrée de gamme, et la carte perdait son relief.
      // On ne cherche pas un contraste de texte ici — juste une différence
      // que l'œil attrape.
      final ecart = contrast(card, page);
      expect(
        ecart,
        greaterThanOrEqualTo(1.04),
        reason:
            'la page et les cartes se confondent (${ecart.toStringAsFixed(3)}:1)',
      );
      // Trop d'écart ferait une page grise, pas une page blanche.
      expect(ecart, lessThan(1.25));
    });
  });

  group('Les ombres posent les éléments', () {
    final theme = File(
      'lib/presentation/theme/app_theme.dart',
    ).readAsStringSync();

    List<String> shadowsOf(String name) {
      // Chaine brute pour la partie echappee : dans une chaine ordinaire,
      // Dart avale le backslash et « \[ » devient une classe de caracteres.
      final block = RegExp(
        'List<BoxShadow> $name'
        r' = \[(.*?)\];',
        dotAll: true,
      ).firstMatch(theme);
      return RegExp(
        r'BoxShadow\(',
      ).allMatches(block?.group(1) ?? '').map((m) => m.group(0)!).toList();
    }

    for (final name in ['card', 'raised', 'overlay']) {
      test('« $name » porte deux couches', () {
        // Une seule couche large donne un halo flou qui grise le fond sans
        // poser l'élément. Une courte et dense au contact, une longue et
        // diffuse dessous : c'est ainsi que la lumière se comporte.
        expect(
          shadowsOf(name),
          hasLength(2),
          reason: '« $name » est retombée à une seule couche',
        );
      });
    }
  });

  group('Taille du texte de contenu', () {
    final theme = File(
      'lib/presentation/theme/app_theme.dart',
    ).readAsStringSync();

    double sizeOf(String style) {
      final match = RegExp(
        '$style: const TextStyle\\(\\s*fontSize: ([0-9.]+)',
      ).firstMatch(theme);
      return double.parse(match!.group(1)!);
    }

    test('le corps de texte atteint au moins 16 px', () {
      // Plancher courant pour du texte lu sur téléphone.
      expect(sizeOf('bodyMedium'), greaterThanOrEqualTo(16));
      expect(sizeOf('bodyLarge'), greaterThanOrEqualTo(16));
    });

    test('les mentions secondaires restent lisibles', () {
      expect(sizeOf('bodySmall'), greaterThanOrEqualTo(14));
    });
  });
}
