import 'package:flutter/widgets.dart';

/// Les espaces et les formes de la charte EduQuali.
///
/// --- Le défaut que ce fichier corrige -----------------------------------
///
/// Il existait **deux** `AppSpacing`, celui-ci et celui de
/// `presentation/theme/app_theme.dart`, avec des valeurs différentes pour les
/// mêmes noms : `md` valait 16 ici et 12 là-bas, `lg` valait 20 ici et 16
/// là-bas. Dix-huit fichiers importaient l'un, soixante-dix l'autre, et
/// `AppSpacing.lg` ne désignait donc pas la même marge d'un écran à l'autre.
///
/// Rien ne le signalait : les deux compilent, et un écart de quatre pixels ne
/// se voit pas en regardant un écran — il se voit en les comparant, ce qu'on
/// ne fait jamais.
///
/// C'est exactement ce qui était arrivé à la palette, et le commentaire de
/// `app_theme.dart` le raconte : les corrections de contraste étaient
/// appliquées à un exemplaire pendant que soixante fichiers affichaient
/// l'autre. La réponse est la même : **une seule source**, ici, dans `core`,
/// et `app_theme.dart` la re-exporte.
///
/// --- Les valeurs -------------------------------------------------------
///
/// Les sept pas de `design/charte/tokens.json`, et rien d'autre. Le `20` de
/// l'ancienne échelle n'y est pas : la charte donne 16 pour « la marge
/// intérieure d'une carte, la gouttière d'un écran de téléphone », et un
/// huitième pas qui n'existe que chez nous se répandrait sans raison.
abstract final class AppSpacing {
  /// Entre une icône et son libellé dans une pastille.
  static const double espace1 = 4;

  /// Entre deux éléments d'un même groupe. Écart entre deux places de la
  /// classe de quinze.
  static const double espace2 = 8;

  /// Marge intérieure d'un champ ou d'une pastille.
  static const double espace3 = 12;

  /// Marge intérieure d'une carte, gouttière d'un écran de téléphone.
  static const double espace4 = 16;

  /// Entre deux cartes ou deux sections.
  static const double espace5 = 24;

  /// Entre deux blocs d'une page.
  static const double espace6 = 32;

  /// Marge d'une affiche ou d'une couverture.
  static const double espace7 = 48;

  /// Hauteur minimale de tout ce qui se touche.
  ///
  /// Le plancher du critère WCAG 2.5.5 est 44 px ; la charte prend 48, et
  /// c'est son choix. Une contrainte explicite ne bouge pas, là où une
  /// hauteur calculée à partir des marges et de la taille du texte change
  /// dès qu'on touche à la typographie.
  static const double cible = 48;

  /// Hauteur du bouton principal et des réponses au point de contrôle.
  ///
  /// La charte en fait un jeton à part : le bouton principal est le seul
  /// élément d'un écran qui engage — réserver, payer, entrer dans la salle —
  /// et huit pixels de plus suffisent à le distinguer d'un bouton second.
  static const double ciblePrincipale = 56;

  /// Écart minimal entre deux cibles tactiles voisines.
  static const double touchGap = espace2;

  // --- Les anciens noms ---------------------------------------------------
  //
  // Deux jeux cohabitaient. Ils pointent désormais tous vers les pas de la
  // charte, et deux d'entre eux **changent de valeur** :
  //
  //   `lg` passait de 20 à 16, et `screenH` avec lui. La charte donne 16 pour
  //   la gouttière d'un écran ; vingt pixels venaient d'une échelle qui n'est
  //   plus la nôtre.
  //
  // Les écrans concernés y gagnent quatre pixels de contenu en largeur, ce
  // qui est le sens du changement : sur un téléphone de 360 px, chaque
  // gouttière coûte cher.

  static const double xxs = espace1;
  static const double xs = espace2;
  static const double sm = espace3;
  static const double md = espace4;
  static const double lg = espace4;
  static const double xl = espace5;
  static const double xxl = espace6;
  static const double xxxl = espace7;
  static const double section = 40;

  /// Marge horizontale standard des écrans.
  static const double screenH = espace4;

  static const double touchTarget = cible;

  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: espace4);
  static const EdgeInsets card = EdgeInsets.all(espace4);
}

/// Les cinq rayons de la charte EduQuali.
///
/// Chacun porte une forme et une seule : « Boutons en `rayonBouton`, cartes
/// en `rayonCarte`, champs et tuiles en `rayonChamp`, places en `rayonPlace`,
/// pastilles en `rayonPastille`. »
///
/// Même histoire que les espaces : cette classe existait en double, et les
/// deux étaient d'accord — par chance, pas par construction.
abstract final class AppRadius {
  /// Places de la classe de quinze, cases à cocher.
  static const double rayonPlace = 8;

  /// Champs, tuiles de choix.
  static const double rayonChamp = 12;

  /// Boutons.
  static const double rayonBouton = 16;

  /// Cartes, feuilles, salle de cours.
  static const double rayonCarte = 20;

  /// Pastilles de statut, avatars.
  static const double rayonPastille = 999;

  // Les anciens noms.
  static const double sm = rayonPlace;
  static const double md = rayonChamp;
  static const double lg = rayonBouton;
  static const double xl = rayonCarte;
  static const double pill = rayonPastille;

  static const BorderRadius card = BorderRadius.all(
    Radius.circular(rayonCarte),
  );
  static const BorderRadius field = BorderRadius.all(
    Radius.circular(rayonChamp),
  );
  static const BorderRadius bouton = BorderRadius.all(
    Radius.circular(rayonBouton),
  );
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(rayonCarte),
  );
}
