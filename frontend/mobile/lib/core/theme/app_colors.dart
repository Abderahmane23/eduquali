import 'package:flutter/material.dart';

/// Palette Eduquali — §54 Design UI/UX.
/// Fond majoritairement blanc, une seule couleur principale (violet/indigo
/// profond), peu de couleurs simultanees, aucun effet visuel inutile.
abstract final class AppColors {
  // Couleur principale.
  //
  // Bleu #1E40AF depuis le 24/09. L'application etait violette et le logo
  // marine et vert : ils n'ont jamais ete d'accord, et chaque retouche de
  // palette deplacait le probleme au lieu de le regler. Ce bleu-la vient du
  // marine du logo, en plus sature.
  //
  // 8,72:1 sur blanc, et le blanc pose dessus tient le meme rapport — un
  // bouton plein n'a pas besoin d'une seconde teinte pour son libelle.
  static const Color primary = Color(0xFF1E40AF);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B82F6);

  /// Fond des chips / encarts d'accent (bleu très clair).
  static const Color primarySurface = Color(0xFFDBEAFE);
  static const Color primarySurfaceStrong = Color(0xFFBFDBFE);

  /// Le dégradé des en-têtes, du haut-gauche au bas-droit.
  ///
  /// Deux pas seulement, et proches : un dégradé qui traverse la roue des
  /// teintes attire l'œil sur le fond, alors que l'en-tête est là pour
  /// porter un titre.
  static const Color heroStart = Color(0xFF1E40AF);
  static const Color heroEnd = Color(0xFF1D4ED8);

  /// Le mot mis en avant dans un titre, et rien d'autre.
  ///
  /// Jamais un fond, jamais un statut : c'est le seul procede qui fasse lire
  /// un titre de trois lignes en entier.
  ///
  /// 5,70:1 sur le bleu principal, 4,37:1 au bout clair du degrade, 10,4:1
  /// sur le marine. Au-dessus du plancher de 3:1 des grands titres partout,
  /// ce qui suffit : c'est le seul endroit ou il sert. En corps de texte sur
  /// le degrade il ne passerait pas, et un jaune employe comme surface
  /// redeviendrait illisible des qu'on poserait du texte dessus.
  static const Color accent = Color(0xFFFACC15);

  /// La seconde surface sombre : cartes marine posees sur du blanc.
  ///
  /// C'est le marine du logo. Il sert a marquer une section sans la teinter
  /// en bleu vif, qui se disputerait avec les boutons.
  static const Color surfaceDark = Color(0xFF0F1E4D);

  /// La bande de section, bleu tres pale.
  ///
  /// Elle alterne avec le blanc pour decouper une page longue sans tracer
  /// une seule ligne de separation.
  static const Color bandSoft = Color(0xFFEFF4FF);

  /// Les surfaces posées *sur* l'en-tête : panneau de chiffres, champ de
  /// recherche, pastilles d'action. Du blanc transparent, pas une teinte
  /// fixe — ainsi elles suivent le dégradé au lieu de le trancher.
  static const Color onHeroSurface = Color(0x26FFFFFF);
  static const Color onHeroBorder = Color(0x33FFFFFF);
  static const Color onHeroMuted = Color(0xCCFFFFFF);

  // Fonds.
  //
  // Le fond est un blanc legerement fume, les cartes restent d'un blanc
  // franc : c'est cet ecart qui les detache. Sur du blanc pur, une carte
  // blanche ne tient que par sa bordure — et une bordure d'un pixel
  // disparait en plein soleil, precisement la ou l'application sert.
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);

  /// Le fond des ecrans : #F6F5FB, un blanc legerement lavande.
  ///
  /// L'ecart avec le blanc des cartes est de 1,084:1 — assez pour que la
  /// carte se detache sans son trait de bordure, trop peu pour que la page
  /// paraisse grise.
  static const Color surfaceMuted = Color(0xFFF6F5FB);
  static const Color scaffoldAlt = Color(0xFFF6F5FB);

  // Texte.
  /// #0F1724 : 16,6:1 sur le fond de page. Un noir bleute plutot qu'un noir
  /// pur, qui vibre sur un ecran OLED.
  static const Color textPrimary = Color(0xFF0F1724);

  /// 5,9:1 sur blanc — au-dessus du plancher AA de 4,5:1.
  static const Color textSecondary = Color(0xFF4A4A5E);

  /// Était #8E8EA3, soit 3,1:1 : sous le plancher pour du texte.
  ///
  /// Assombri une seconde fois (#6E6E85 → #656579) le 23/09 : le fond des
  /// écrans étant passé au blanc fumé, cette teinte retombait à 4,45:1 —
  /// juste sous le plancher. Assombrir le texte plutôt qu'éclaircir le fond
  /// préserve le relief qu'on venait de gagner.
  static const Color textTertiary = Color(0xFF656579);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Bordures / separateurs.
  /// Bordure visible : 1,3:1 ne se voyait pas en plein soleil.
  static const Color border = Color(0xFFD5D5E2);
  static const Color borderStrong = Color(0xFFD3D3E0);

  // États semantiques (usage parcimonieux).
  static const Color success = Color(0xFF16A34A);
  static const Color successSurface = Color(0xFFE8F7EE);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSurface = Color(0xFFFEF3E2);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSurface = Color(0xFFFDECEC);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSurface = Color(0xFFE8F0FE);
  static const Color neutralSurface = Color(0xFFF1F1F5);

  /// La barre d'un score, au repos.
  ///
  /// **Une seule teinte, pas une par catégorie.** Ces barres portent une
  /// *même* mesure — le score — répétée sur plusieurs domaines. Le nom du
  /// domaine est déjà écrit à côté : lui donner en plus une couleur propre
  /// n'ajoute aucune information et fait entrer cinq teintes en
  /// concurrence pour l'attention.
  ///
  /// La règle : garder l'essentiel en gris neutre, et réserver l'accent au
  /// point qui mérite le regard.
  static const Color chartBar = Color(0xFF8E8EA8);

  /// La barre du domaine qui mérite le regard — le plus faible.
  ///
  /// L'information n'est pas portée par la couleur seule : le pourcentage
  /// est écrit en toutes lettres au bout de chaque barre.
  static const Color chartHighlight = primary;

  /// Couleurs des états réseau (§42).
  static const Color networkOffline = Color(0xFF8E8EA3);
  static const Color networkPartial = Color(0xFFD97706);
  static const Color networkOnline = Color(0xFF16A34A);
}
