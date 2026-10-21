@Tags(['captures'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/presentation/theme/app_theme.dart';

/// Les deux thèmes, côte à côte, avec un champ de saisie dedans.
///
/// Signalé le 21/10 : « le champ de saisie a un fond noir et le texte écrit
/// dedans est invisible », et « le fond des pages est noir ».
///
/// `MaterialApp` reçoit `theme` **et** `darkTheme` sans `themeMode` : la
/// valeur par défaut est `ThemeMode.system`, donc un téléphone réglé en
/// sombre obtient `AppTheme.dark`. Toutes les captures de la présentation
/// passaient `AppTheme.light` explicitement — c'est pourquoi le défaut ne
/// s'y voyait pas.
///
/// Ce fichier rend le même écran sous les deux thèmes, pour savoir si le
/// sombre est seulement sombre, ou réellement illisible.
final _cadre = GlobalKey();

void main() {
  testWidgets('les deux thèmes, avec un champ', (tester) async {
    for (final entree in {
      'Gabarito': [
        'assets/fonts/Gabarito-600.ttf',
        'assets/fonts/Gabarito-700.ttf',
      ],
      'Lexend': [
        'assets/fonts/Lexend-400.ttf',
        'assets/fonts/Lexend-500.ttf',
      ],
    }.entries) {
      final chargeur = FontLoader(entree.key);
      for (final c in entree.value) {
        chargeur.addFont(
          Future<ByteData>.value(
            ByteData.view(File(c).readAsBytesSync().buffer),
          ),
        );
      }
      await chargeur.load();
    }

    for (final (nom, theme) in [
      ('clair', AppTheme.light),
      ('sombre', AppTheme.dark),
    ]) {
      tester.view.physicalSize = const Size(420, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        RepaintBoundary(
          key: _cadre,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thème $nom', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('Comment vous appelez-vous ?'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: 'Aissatou'),
                      decoration: const InputDecoration(
                        hintText: 'Votre nom',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Un paragraphe ordinaire, pour comparer.'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final f =
          _cadre.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      late final ui.Image image;
      await tester.runAsync(() async {
        image = await f.toImage(pixelRatio: 2);
      });
      final octets = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      File('test/captures/_theme-$nom.png')
          .writeAsBytesSync(octets!.buffer.asUint8List());
    }
  });
}
