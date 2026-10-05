import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/utils/text_search.dart';
import 'package:veriprof/domain/entities/onboarding_spec.dart';
import 'package:veriprof/presentation/widgets/picker_sheet.dart';
import 'package:veriprof/presentation/widgets/type_ahead.dart';

/// Le champ de saisie assistée qui remplace les nappes d'étiquettes.
///
/// Demandé le 24/09 : « à chaque fois que toutes les matières sont affichées
/// en étiquettes, remplacer par un champ à taper avec autocomplétion ; si
/// plusieurs peuvent être choisies, ajouter l'étiquette en bas et laisser
/// écrire la suivante ».
///
/// Ce qui est testé ici est ce qui casse en silence : une liste qui ne se
/// réduit pas, un champ qui ne se vide pas, une étiquette qu'on ne peut plus
/// retirer. Rien de tout cela ne lève d'exception — l'inscription se bloque,
/// et personne ne le voit avant un rapport d'utilisateur.
void main() {
  const matieres = [
    PickerOption(value: 'sub_math', label: 'Mathématiques'),
    PickerOption(value: 'sub_phy', label: 'Physique'),
    PickerOption(value: 'sub_fr', label: 'Français'),
    PickerOption(value: 'sub_svt', label: 'Sciences de la vie'),
  ];

  /// Le champ, branché sur une sélection qui vit dans le test — comme dans
  /// l'application, où elle vit dans le contrôleur.
  Future<List<String>> monter(
    WidgetTester tester, {
    List<String> initial = const [],
    int maxVisible = 6,
  }) async {
    final selection = <String>[...initial];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TypeAheadTags(
              options: matieres,
              selected: selection,
              maxVisible: maxVisible,
              hint: 'Tapez une matière…',
              emptyMessage: 'Aucune matière ne correspond',
              onToggle: (value) => setState(() {
                if (!selection.remove(value)) selection.add(value);
              }),
            ),
          ),
        ),
      ),
    );
    return selection;
  }

  group('Le champ', () {
    testWidgets('ne montre la liste qu’une fois le champ touché', (
      tester,
    ) async {
      await monter(tester);
      // Au repos, la page reste courte : c'est tout l'intérêt du champ.
      expect(find.text('Mathématiques'), findsNothing);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(find.text('Mathématiques'), findsOneWidget);
    });

    testWidgets('réduit la liste à ce qui est tapé', (tester) async {
      await monter(tester);
      await tester.enterText(find.byType(TextField), 'phy');
      await tester.pump();

      expect(find.text('Physique'), findsOneWidget);
      expect(find.text('Mathématiques'), findsNothing);
      expect(find.text('Français'), findsNothing);
    });

    testWidgets('trouve « Français » sans l’accent ni la cédille', (
      tester,
    ) async {
      // Personne ne tape « Français » avec sa cédille sur un téléphone.
      await monter(tester);
      await tester.enterText(find.byType(TextField), 'franc');
      await tester.pump();
      expect(find.text('Français'), findsOneWidget);
    });

    testWidgets('au repos, ne propose que les premières', (tester) async {
      await monter(tester, maxVisible: 2);
      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(find.text('Mathématiques'), findsOneWidget);
      expect(find.text('Physique'), findsOneWidget);
      expect(find.text('Français'), findsNothing);
    });

    testWidgets('le dit quand rien ne correspond', (tester) async {
      await monter(tester);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Aucune matière ne correspond'), findsOneWidget);
    });
  });

  group('Ce qui est retenu', () {
    testWidgets('descend en étiquette, et le champ se vide', (tester) async {
      final selection = await monter(tester);
      await tester.enterText(find.byType(TextField), 'phy');
      await tester.pump();
      await tester.tap(find.text('Physique'));
      await tester.pump();

      expect(selection, ['sub_phy']);
      // Le champ vidé est ce qui permet d'enchaîner la matière suivante
      // sans quitter le clavier.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      // L'étiquette est en bas, avec sa croix — et la ligne de suggestion a
      // disparu. La croix du champ, elle, s'en va avec la saisie : ce seul
      // Icons.close est donc bien celui de l'étiquette.
      expect(find.text('Physique'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.north_west), findsNWidgets(3));
    });

    testWidgets('n’est plus proposé une seconde fois', (tester) async {
      await monter(tester, initial: ['sub_phy']);
      await tester.enterText(find.byType(TextField), 'phy');
      await tester.pump();

      // « Physique » n'apparaît qu'une fois : l'étiquette, reconnaissable à
      // sa croix. La reproposer inviterait au double appui, qui la
      // retirerait.
      expect(find.text('Physique'), findsOneWidget);
      expect(find.byIcon(Icons.north_west), findsNothing);
      expect(find.text('Aucune matière ne correspond'), findsOneWidget);
    });

    testWidgets('se retire en appuyant dessus', (tester) async {
      final selection = await monter(tester, initial: ['sub_phy']);
      await tester.tap(find.text('Physique'));
      await tester.pump();
      expect(selection, isEmpty);
    });

    testWidgets('en accepte plusieurs, l’une après l’autre', (tester) async {
      final selection = await monter(tester);
      for (final (saisie, libelle) in [
        ('math', 'Mathématiques'),
        ('phy', 'Physique'),
        ('vie', 'Sciences de la vie'),
      ]) {
        await tester.enterText(find.byType(TextField), saisie);
        await tester.pump();
        await tester.tap(find.text(libelle));
        await tester.pump();
      }
      expect(selection, ['sub_math', 'sub_phy', 'sub_svt']);
    });
  });

  group('Dans la page', () {
    /// Le champ tel qu'il vit vraiment : dans la colonne non etiree d'un
    /// `SingleChildScrollView`, ou la hauteur disponible est infinie.
    ///
    /// C'est la meme configuration qui avait fait disparaitre les tableaux
    /// de bord du 23/09 : une hauteur infinie ne leve pas d'exception, elle
    /// dessine hors de l'ecran.
    Future<void> dansLaPage(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quelles matières enseignez-vous ?'),
                TypeAheadTags(
                  options: matieres,
                  selected: const ['sub_math', 'sub_phy'],
                  onToggle: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    testWidgets('garde une hauteur finie et tient dans l’écran', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await dansLaPage(tester);
      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final taille = tester.getSize(find.byType(TypeAheadTags));
      expect(taille.height.isFinite, isTrue);
      expect(taille.height, lessThan(720));
      // Le champ prend toute la largeur utile : dans une colonne non
      // etiree, un champ qui se replie sur sa largeur intrinseque devient
      // une fente de quelques pixels.
      expect(tester.getSize(find.byType(TextField)).width, 360 - 48);
    });
  });

  group('Saisie libre', () {
    testWidgets('propose d’ajouter ce qui n’existe pas', (tester) async {
      final ajoutes = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TypeAheadTags(
              options: matieres,
              selected: const [],
              allowCustom: true,
              onCustom: ajoutes.add,
              onToggle: (_) {},
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Arabe');
      await tester.pump();
      await tester.tap(find.text('Ajouter « Arabe »'));
      await tester.pump();

      expect(ajoutes, ['Arabe']);
    });

    testWidgets('ne propose pas d’ajouter un doublon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TypeAheadTags(
              options: matieres,
              selected: const [],
              allowCustom: true,
              onToggle: (_) {},
            ),
          ),
        ),
      );
      // Écrit sans accent : c'est bien la même matière, et l'ajouter
      // créerait deux « Français » dans le référentiel.
      await tester.enterText(find.byType(TextField), 'francais');
      await tester.pump();
      expect(find.textContaining('Ajouter'), findsNothing);
    });
  });

  group('Les parcours', () {
    OnboardingFlowSpec load(String name) => OnboardingFlowSpec.fromJson(
      jsonDecode(File('assets/onboarding/$name.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    test('demandent la saisie assistée sur les matières', () {
      // Le drapeau vit dans le JSON partagé avec le web : une resynchro qui
      // le perdrait ramènerait le mur d'étiquettes sans rien casser.
      for (final (flow, step) in [
        ('teacher_onboarding', 'subjects'),
        ('student_onboarding', 'subjects'),
        ('institution_onboarding', 'subjects'),
        ('parent_onboarding', 'child_subjects'),
      ]) {
        final etape = load(
          flow,
        ).sections.expand((s) => s.steps).firstWhere((s) => s.id == step);
        expect(etape.searchable, isTrue, reason: '$flow / $step');
        expect(etape.searchHint, isNotNull, reason: '$flow / $step');
      }
    });

    test('laissent les listes courtes en étiquettes', () {
      // Quatre cycles se lisent d'un coup d'œil ; un champ à taper y serait
      // un geste de plus pour rien.
      final cycles = load(
        'teacher_onboarding',
      ).sections.expand((s) => s.steps).firstWhere((s) => s.id == 'cycles');
      expect(cycles.searchable, isFalse);
    });
  });

  group('Comparaison de texte', () {
    test('ignore accents, casse et espaces en trop', () {
      expect(foldText('  Nzérékoré '), 'nzerekore');
      expect(foldText('FRANÇAIS'), 'francais');
      expect(matchesSearch('Sciences de la vie', 'VIE'), isTrue);
      expect(matchesSearch('Physique', 'chimie'), isFalse);
    });

    test('une recherche vide laisse tout passer', () {
      expect(matchesSearch('Physique', '  '), isTrue);
    });
  });
}
