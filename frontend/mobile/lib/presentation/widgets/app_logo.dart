import 'package:flutter/material.dart';

/// La marque, aux deux seules formes qu'elle prend dans l'application.
///
/// [AppLogo.mark] — le Q a la toque, partout ou l'on sait deja ou l'on est :
/// l'ecran d'ouverture, et l'icone du telephone qui en est tiree.
///
/// [AppLogo.wordmark] — le nom en entier, sur la page de connexion et elle
/// seule. C'est le seul ecran atteint sans etre passe par l'application, et
/// le seul ou lire « EduQuali » apprend quelque chose ; ailleurs, le nom
/// repete ne fait qu'occuper la place d'autre chose.
///
/// Les deux images sont detourees : aucun cadre blanc ne traine derriere
/// elles sur le fond fume des ecrans.
class AppLogo extends StatelessWidget {
  /// Le symbole seul, dans un carre de [size] points.
  const AppLogo.mark({super.key, this.size = 72})
    : _asset = 'assets/img/logo_mark.png',
      width = null;

  /// Le nom en entier, sur [width] points de large.
  const AppLogo.wordmark({super.key, this.width = 200})
    : _asset = 'assets/img/logo_wordmark.png',
      size = null;

  /// Le nom en entier, pour un fond sombre : blanc puis vert vif.
  ///
  /// Le marine du fichier d'origine tombe a 1,4:1 sur le violet des
  /// en-tetes. Ces deux teintes-la tiennent : 8,98:1 et 4,67:1.
  const AppLogo.wordmarkLight({super.key, this.width = 200})
    : _asset = 'assets/img/logo_wordmark_light.png',
      size = null;

  final String _asset;

  /// Largeur, pour le nom en entier.
  final double? width;

  /// Cote du carre, pour le symbole.
  final double? size;

  @override
  Widget build(BuildContext context) => Image.asset(
    _asset,
    width: width ?? size,
    height: size,
    fit: BoxFit.contain,
    // Le nom, pour qui ne voit pas l'image : sans lui, un lecteur d'ecran
    // annonce « image » sur le premier element de la page de connexion.
    semanticLabel: 'EduQuali',
  );
}
