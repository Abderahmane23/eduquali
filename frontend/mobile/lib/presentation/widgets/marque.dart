import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common.dart';

/// Les signes de la marque EduQuali.
///
/// « Une marque se reconnaît à quelques signes répétés pendant des années.
/// EduQuali en a cinq. Ne pas en ajouter. »
///
///   1. le nom en deux temps — dans les fichiers du logo ;
///   2. le Q à la queue surlignée — idem ;
///   3. le couple violette et surligneur — dans la palette ;
///   4. **le surlignage en biseau** — [Surlignage] et [Affiche] ;
///   5. **la classe de quinze** — [Quinze].
///
/// Plus ce qui en découle : [Annotation], [Statut], [EnDirect] et
/// [LigneDuTemps].
///
/// --- Pourquoi un fichier à part ----------------------------------------
///
/// `kit.dart` fait 1 600 lignes et porte les primitives — carte, bouton,
/// champ. Ces widgets-ci ne sont pas des primitives : ce sont les gestes de
/// la marque, et chacun porte une règle qu'on ne peut pas deviner en lisant
/// son code. « Un seul passage surligné par écran » ne se compile pas.

/// Le surlignage : deux ou trois mots, ceux qu'il faut retenir.
///
/// **Un seul passage par phrase, un seul par écran.** Ne pas surligner un
/// bouton, un titre entier, un paragraphe, un prix : un surlignage partout ne
/// dit plus rien.
///
/// Le texte posé dessus est toujours [AppColors.surSurligneur], dans les deux
/// thèmes — l'encre s'éclaircit sur le thème Tableau et deviendrait illisible
/// sur le vert.
class Surlignage extends StatelessWidget {
  const Surlignage(this.texte, {super.key, this.style});

  final String texte;

  /// Le style du texte autour, pour que le mot surligné garde sa taille.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const ShapeDecoration(
        color: AppColors.surligneur,
        shape: _BiseauBorder(),
      ),
      child: Text(
        texte,
        style: base.copyWith(color: AppColors.surSurligneur),
      ),
    );
  }
}

/// Le biseau du surligneur : la trace d'une pointe tenue de travers.
///
/// Un `ShapeBorder` plutôt qu'un `ClipPath` : la forme suit la taille du
/// texte sans qu'on la lui donne, et elle se peint en une passe.
class _BiseauBorder extends ShapeBorder {
  const _BiseauBorder();

  /// La largeur du biais, en points. Proportionnelle à la hauteur : sur un
  /// mot en 44 px, un biais de 3 px ne se verrait pas.
  static const double _part = 0.18;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final biais = rect.height * _part;
    return Path()
      ..moveTo(rect.left + biais, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right - biais, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => const _BiseauBorder();
}

/// Une affiche : une phrase courte dont un mot est surligné.
///
/// Le titre de l'écran d'accueil, d'une couverture, d'une page de compte. Le
/// mot surligné est celui que le produit promet — « Trouvez le *professeur*
/// qu'il vous faut », « Le professeur *est là* ».
class Affiche extends StatelessWidget {
  const Affiche({
    super.key,
    this.avant,
    required this.surligne,
    this.apres,
    this.style,
    this.couleur,
  });

  final String? avant;
  final String surligne;
  final String? apres;
  final TextStyle? style;

  /// La couleur du texte non surligné. [AppColors.encre] par défaut ;
  /// [AppColors.marquePapier] sur un aplat de violette.
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? Theme.of(context).textTheme.displaySmall!).copyWith(
      color: couleur ?? AppColors.encre,
    );

    /*
     * Un `WidgetSpan` pour le mot surligné, et non deux `Text` côte à côte :
     * la phrase doit pouvoir se couper n'importe où, y compris au milieu du
     * passage surligné, et seul un `RichText` sait le faire.
     *
     * `alignment: baseline` : sans elle, le fond vert se cale sur le haut de
     * la ligne et le mot flotte au-dessus des autres.
     */
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          if (avant != null) TextSpan(text: avant),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Surlignage(surligne, style: base),
          ),
          if (apres != null) TextSpan(text: apres),
        ],
      ),
    );
  }
}

/// L'annotation du cahier : un mot ou deux.
///
/// « Présent ! », « Vu », « Bravo ». **Jamais une phrase, jamais un bouton,
/// une seule fois par écran.** Légèrement penchée, comme une note dans la
/// marge, en violette ou en rouge.
class Annotation extends StatelessWidget {
  const Annotation(this.mot, {super.key, this.rouge = false});

  final String mot;
  final bool rouge;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.052, // ≈ 3 degrés
    child: Text(
      mot,
      style: TextStyle(
        fontFamily: AppTheme.fontAnnotation,
        fontSize: 22,
        height: 1.3,
        fontWeight: FontWeight.w400,
        color: rouge ? AppColors.rouge : AppColors.violette,
      ),
    ),
  );
}

/// La classe de quinze.
///
/// Quinze places, trois rangs de cinq. **Jamais plus, jamais moins** — c'est
/// le nombre que le produit promet, et le dessin le dit avant la phrase.
///
/// [libelle] n'est pas facultatif : la charte exige une phrase à côté, et un
/// carré de couleur seul ne dit pas combien de places restent. Il sert aussi
/// de description pour qui ne voit pas l'image.
class Quinze extends StatelessWidget {
  const Quinze({
    super.key,
    required this.prises,
    required this.libelle,
    this.mienne,
    this.mini = false,
  });

  /// Combien de places sont prises, de 0 à 15.
  final int prises;

  /// Le rang de votre place, de 1 à 15, si vous en avez une.
  final int? mienne;

  /// « Il reste 3 places », « 14 présents sur 15 ».
  final String libelle;

  /// La version qui tient à côté d'une phrase, sur une carte de cours.
  final bool mini;

  @override
  Widget build(BuildContext context) {
    // Borné : une séance de seize places n'existe pas, et un tableau de seize
    // carrés casserait les trois rangs de cinq.
    final n = prises.clamp(0, 15);
    final ecart = mini ? 3.0 : AppSpacing.espace2;
    final rayon = mini ? 4.0 : AppRadius.rayonPlace;

    return Semantics(
      label: libelle,
      image: true,
      // Son propre noeud, pour la meme raison que la ligne du temps : un
      // `Semantics` sans `container` fusionne avec son parent, et le jour ou
      // l'on posera un chiffre dans une place, le libelle disparaitrait sans
      // bruit.
      container: true,
      child: SizedBox(
        width: mini ? 86 : null,
        child: GridView.count(
          crossAxisCount: 5,
          mainAxisSpacing: ecart,
          crossAxisSpacing: ecart,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            for (var rang = 1; rang <= 15; rang++)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(rayon),
                  color: rang == mienne
                      ? AppColors.surligneur
                      : rang <= n
                      ? AppColors.violette
                      : null,
                  border: Border.all(
                    color: rang == mienne
                        ? AppColors.encre
                        : rang <= n
                        ? AppColors.violette
                        : AppColors.ligne,
                    width: AppTrait.fin,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Le ton d'une pastille de statut.
enum TonStatut {
  /// Présent, Payé, Disponible.
  ok,

  /// Absent, erreur.
  ko,

  /// En attente, arrivé en retard.
  attente,

  /// Les points et les récompenses, et rien d'autre.
  point,
}

/// Une pastille de statut : une couleur, une forme et **un mot**.
///
/// La couleur seule ne suffit jamais. C'est la règle de la charte, et c'est
/// aussi celle de l'accessibilité : un écran en plein soleil, un daltonien,
/// un téléphone passé en noir et blanc pour économiser la batterie.
class Statut extends StatelessWidget {
  const Statut(this.mot, {super.key, this.ton = TonStatut.attente, this.icone});

  final String mot;
  final TonStatut ton;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final (fond, encre) = switch (ton) {
      TonStatut.ok => (AppColors.surligneurPale, AppColors.vertFonce),
      TonStatut.ko => (AppColors.rougePale, AppColors.rougeFonce),
      TonStatut.attente => (AppColors.violettePale, AppColors.encre),
      TonStatut.point => (AppColors.bonPoint, AppColors.surBonPoint),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(AppRadius.rayonPastille),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 18, color: encre),
            const Gap(AppSpacing.espace1),
          ],
          Text(
            mot,
            style: TextStyle(
              fontFamily: AppTheme.fontTexte,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: encre,
            ),
          ),
        ],
      ),
    );
  }
}

/// « En direct ».
///
/// Le seul emploi de [AppColors.rouge] en aplat. S'il est à l'écran, la
/// caméra tourne — **il ne décore jamais.**
class EnDirect extends StatelessWidget {
  const EnDirect({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.rouge,
      borderRadius: BorderRadius.circular(AppRadius.rayonPastille),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.surRouge,
            shape: BoxShape.circle,
          ),
        ),
        const Gap(AppSpacing.espace1),
        Text(
          'EN DIRECT',
          style: TextStyle(
            fontFamily: AppTheme.fontTexte,
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.07 * 12,
            color: AppColors.surRouge,
          ),
        ),
      ],
    ),
  );
}

/// La ligne du temps d'une séance.
///
/// Les minutes où l'élève était là, surlignées sur l'heure entière, avec un
/// trait toutes les quinze minutes : ce sont les points de contrôle.
///
/// C'est le signe le plus utile du produit : il répond à la seule question
/// qu'un parent se pose, et il y répond avec un chiffre — « 52 minutes sur
/// 60 » — plutôt qu'avec un pourcentage.
class LigneDuTemps extends StatelessWidget {
  const LigneDuTemps({
    super.key,
    required this.minutesSuivies,
    required this.minutesTotales,
    this.debutALaMinute = 0,
  });

  /// Combien de minutes l'élève a suivies.
  final int minutesSuivies;

  /// La durée de la séance.
  final int minutesTotales;

  /// À quelle minute il est entré. Un retard se dit avec l'heure d'arrivée,
  /// jamais avec un reproche.
  final int debutALaMinute;

  @override
  Widget build(BuildContext context) {
    final total = minutesTotales <= 0 ? 1 : minutesTotales;
    final debut = (debutALaMinute / total).clamp(0.0, 1.0);
    final part = (minutesSuivies / total).clamp(0.0, 1.0 - debut);

    // Un point de contrôle tous les quarts d'heure, et pas celui de la fin :
    // la séance s'arrête, il n'y a rien à vérifier.
    final controles = <double>[
      for (var m = 15; m < total; m += 15) m / total,
    ];

    /*
     * `container: true` et `excludeSemantics: true`, et les deux comptent.
     *
     * Sans `container`, ce `Semantics` fusionne avec son parent au lieu de
     * creer son propre noeud : le libelle existe dans le code et n'arrive
     * jamais au lecteur d'ecran. C'est le genre de panne qui ne se voit pas —
     * l'ecran s'affiche, et seule la personne qui en depend s'en apercoit.
     *
     * `excludeSemantics` retire les « 15 min », « 30 min », « 45 min » : ce
     * sont des reperes pour l'oeil. Lus a la suite, ils donnent « 52 minutes
     * sur 60, 15 min, 30 min, 45 min », ou l'information se perd dans les
     * reperes.
     */
    return Semantics(
      label: '$minutesSuivies minutes sur $minutesTotales',
      image: true,
      container: true,
      excludeSemantics: true,
      child: SizedBox(
        height: 44,
        child: LayoutBuilder(
          builder: (context, bornes) {
            final largeur = bornes.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // L'heure entière, en creux.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 11,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.ligne.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                // Les minutes suivies, surlignées.
                Positioned(
                  left: debut * largeur,
                  width: part * largeur,
                  top: 4,
                  height: 20,
                  child: const DecoratedBox(
                    decoration: ShapeDecoration(
                      color: AppColors.surligneur,
                      shape: _BiseauBorder(),
                    ),
                  ),
                ),
                for (final c in controles)
                  Positioned(
                    left: c * largeur - 1,
                    top: 0,
                    width: 2,
                    height: 28,
                    child: const ColoredBox(color: AppColors.encre),
                  ),
                for (final c in controles)
                  Positioned(
                    // Cinquante-deux points, et une seule ligne.
                    //
                    // La boite faisait quarante : « 30 min » en Lexend 12 en
                    // demande quarante-deux, et le reperage passait sur deux
                    // lignes. Il allait alors toucher le fait suivant, et la
                    // ligne du temps cessait d'etre une ligne.
                    left: c * largeur - 26,
                    top: 30,
                    width: 52,
                    child: Text(
                      '${(c * total).round()} min',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontTexte,
                        fontSize: 12,
                        height: 1,
                        color: AppColors.crayon,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
