import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Le logo d'EduQuali : le nom en deux temps.
///
/// « Edu » est écrit à l'encre violette. « Quali » est passé au surligneur.
/// C'est le premier des cinq signes de la marque, et il applique l'idée à
/// lui-même : dans le nom, c'est la qualité qui est surlignée.
///
/// --- Ce qui a changé le 12/10 --------------------------------------------
///
/// Trois PNG détourés à la main laissent la place aux six fichiers vectoriels
/// de la charte. Quatre raisons, et la dernière est la plus concrète :
///
///   * **la toque de diplômé est partie.** Elle est « le signe de presque
///     toutes les applications scolaires. Elle parle du diplôme, alors
///     qu'EduQuali vend la présence ». À sa place, un Q dont la queue est un
///     coup de surligneur ;
///   * « Quali » était vert sans raison dite ; il est maintenant **passé au
///     surligneur**, et le vert prend un sens : ce qui compte, ce qui est là ;
///   * les lettres sont converties en tracés : aucune police n'est nécessaire
///     pour afficher le logo, et il ne dépend donc pas du chargement de
///     Gabarito ;
///   * un vectoriel reste net à toute taille. Les PNG étaient rendus à une
///     résolution fixe et bavaient sur un écran dense — précisément l'endroit
///     où un logo flou se remarque.
///
/// --- Les règles que ce widget fait respecter ---------------------------
///
/// Elles ne se devinent pas en lisant le code, d'où leur place ici :
///
///   * on utilise les fichiers, **jamais une recomposition avec une
///     police** ;
///   * le trait de surligneur et « Quali » ne changent jamais de couleur. Les
///     trois variantes du logotype ne changent que « Edu » ;
///   * sous 18 px de haut, on emploie le symbole seul ;
///   * un espace égal à la hauteur de la lettre « u » est laissé autour ;
///   * ne pas étirer, incliner, ombrer. Pas de dégradé. Pas de toque.
class AppLogo extends StatelessWidget {
  /// Le symbole seul : un Q dont la queue est un coup de surligneur.
  ///
  /// À employer sous 18 px de haut — le plancher du logotype — et partout où
  /// le nom est déjà présent à l'écran.
  const AppLogo.mark({super.key, this.size = 72})
    : _asset = 'assets/logos/eduquali-symbole.svg',
      width = null,
      _hauteurMini = 12;

  /// Le symbole seul, sur un fond sombre : anneau blanc, queue inchangée.
  const AppLogo.markLight({super.key, this.size = 72})
    : _asset = 'assets/logos/eduquali-symbole-inverse.svg',
      width = null,
      _hauteurMini = 12;

  /// Le nom en entier, sur fond clair : « Edu » en violette.
  const AppLogo.wordmark({super.key, this.width = 200})
    : _asset = 'assets/logos/eduquali-logo.svg',
      size = null,
      _hauteurMini = 18;

  /// Le nom en entier, sur la violette de la marque, sur l'encre ou sur une
  /// photo sombre : « Edu » en blanc.
  ///
  /// Le marine du fichier d'origine tombait à 1,4:1 sur le violet des
  /// en-têtes ; cette variante existe pour cela.
  const AppLogo.wordmarkLight({super.key, this.width = 200})
    : _asset = 'assets/logos/eduquali-logo-inverse.svg',
      size = null,
      _hauteurMini = 18;

  /// Le nom en entier, pour un reçu, une facture, un document sobre :
  /// « Edu » à l'encre.
  const AppLogo.wordmarkInk({super.key, this.width = 200})
    : _asset = 'assets/logos/eduquali-logo-encre.svg',
      size = null,
      _hauteurMini = 18;

  /// L'icône de l'application et l'avatar des réseaux : le symbole dans un
  /// carré de violette.
  ///
  /// Dans l'application, elle ne sert qu'aux endroits qui *montrent* l'icône —
  /// un écran « à propos », une capture. Ailleurs, le symbole seul suffit :
  /// le carré violet poserait un second fond sur un fond.
  const AppLogo.appIcon({super.key, this.size = 72})
    : _asset = 'assets/logos/eduquali-icone-app.svg',
      width = null,
      _hauteurMini = 16;

  final String _asset;

  /// Largeur, pour le nom en entier.
  final double? width;

  /// Côté du carré, pour le symbole et l'icône.
  final double? size;

  /// Le plancher de la charte pour cette variante, en points de hauteur.
  final double _hauteurMini;

  @override
  Widget build(BuildContext context) {
    /*
     * Le rapport du logotype, mesuré sur le fichier : 4172 sur 957, soit
     * 4,36. On s'en sert pour vérifier le plancher, pas pour dessiner — le
     * `SvgPicture` lit le `viewBox` lui-même.
     */
    const rapportLogotype = 4172 / 957;
    final hauteur = size ?? (width! / rapportLogotype);

    assert(
      hauteur >= _hauteurMini,
      'Logo trop petit : ${hauteur.toStringAsFixed(1)} points de haut, '
      'le plancher de la charte est $_hauteurMini. '
      'Sous 18 px, employer AppLogo.mark — le symbole seul.',
    );

    return SvgPicture.asset(
      _asset,
      width: width ?? size,
      height: size,
      /*
       * `semanticsLabel` et non un `Semantics` autour : le fichier porte déjà
       * son propre `<title>EduQuali</title>`, et deux descriptions
       * superposées se lisent deux fois.
       *
       * Vide sur le symbole quand le nom est déjà à l'écran — ce qui est le
       * cas partout où le symbole est employé seul. Le dire ici serait
       * bavard ; l'écran porte le nom.
       */
      semanticsLabel: width != null ? 'EduQuali' : '',
      /*
       * Un espace réservé de la bonne taille : sans lui, la mise en page
       * saute d'un cran au moment où le fichier finit de se lire. Sur un
       * téléphone modeste, ce saut est visible.
       */
      placeholderBuilder: (_) =>
          SizedBox(width: width ?? size, height: hauteur),
    );
  }
}
