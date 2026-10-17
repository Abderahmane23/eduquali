import 'package:flutter/material.dart';

/// La trousse d'EduQuali.
///
/// Source : le système de design EduQuali, version 1, versionné dans
/// `design/charte/tokens.json`. Les valeurs sont recopiées, pas
/// réinterprétées, et les noms sont les siens — `papier`, `encre`, `crayon`,
/// `violette`, `surligneur`, `rouge` pour le stylo rouge, `bonPoint` pour la
/// récompense.
///
/// **Chaque couleur garde un seul rôle**, écrit à côté d'elle. C'est la règle
/// qui a le plus de valeur ici : l'application portait trois violets
/// différents — un dans le logo, un à la connexion, un sur le profil — et
/// « une couleur de marque ne se reconnaît que si elle est la même partout ».
///
/// --- Ce qui change par rapport au 24/09 -----------------------------------
///
/// Le bleu #1E40AF devient `violette` #3A2FC9 ; le jaune de mise en avant
/// devient `surligneur`, un vert, qui ne sert plus qu'à **montrer** ; et il
/// n'y a plus ni dégradé ni ombre — le relief vient du contour.
///
/// --- Les anciens noms --------------------------------------------------
///
/// Ils sont conservés en bas du fichier, comme alias. 816 usages les
/// nomment ; les renommer d'un bloc ferait un diff illisible et ne dirait
/// rien de plus. Ils sont marqués `@Deprecated` : l'analyseur signale chaque
/// emploi, et le fichier se vide à mesure que les écrans sont reprise.
abstract final class AppColors {
  // =========================================================================
  // La trousse
  // =========================================================================

  /// Fond des écrans et des documents. Un blanc à peine violet, comme une
  /// page de cahier.
  static const Color papier = Color(0xFFF6F5FB);

  /// Surface des cartes, des champs et des feuilles posées sur [papier].
  static const Color feuille = Color(0xFFFFFFFF);

  /// Texte courant, titres et trait des icônes. Toujours sur [papier],
  /// [feuille] ou un fond pâle. 15,8:1 sur [papier].
  static const Color encre = Color(0xFF141038);

  /// Texte secondaire, couleur de crayon à papier : précisions, dates,
  /// légendes. **Jamais sous 14 px.**
  static const Color crayon = Color(0xFF55536F);

  /// Contour des cartes et des champs, places libres, fond de la ligne du
  /// temps. Au moins 3:1 sur [papier] et [feuille].
  static const Color ligne = Color(0xFF8B89A8);

  /// L'encre violette de la marque : bouton principal, lien, onglet actif,
  /// place prise. **Un seul bouton [violette] par écran.** 8:1 sur [papier].
  static const Color violette = Color(0xFF3A2FC9);

  /// Texte et icône posés sur [violette].
  static const Color surViolette = Color(0xFFFFFFFF);

  /// Fond de ce qui est choisi ou en attente : tuile sélectionnée, bloc
  /// d'information, statut « En attente ».
  static const Color violettePale = Color(0xFFE8E6FA);

  /// Le violet d'un bouton pressé.
  ///
  /// Il n'est pas dans la trousse : la charte en tient un seul, et interdit
  /// « trois violets différents d'un écran à l'autre ». Celui-ci n'est pas un
  /// second violet de marque — c'est le même, assombri de 12 %, et il
  /// n'apparaît que sous le doigt. Sans lui, un bouton ne répond pas au
  /// toucher, et l'on appuie deux fois.
  static const Color violetteAppuyee = Color(0xFF2E25A1);

  /// Le surligneur : ce qui compte. Minutes de présence, place à vous, mot
  /// clé d'une phrase, coup de surligneur des icônes.
  ///
  /// **Jamais un bouton. Jamais du texte.** S'il devient une couleur de
  /// bouton, il cesse de dire « voici ce qui compte » et dit « appuyez ici ».
  static const Color surligneur = Color(0xFF4FE39A);

  /// Texte posé sur [surligneur]. Fixe dans les deux thèmes : l'encre
  /// s'éclaircit sur le thème Tableau et deviendrait illisible sur le vert.
  static const Color surSurligneur = Color(0xFF141038);

  /// Fond des statuts favorables : « Présent », « Payé », « Disponible ».
  static const Color surligneurPale = Color(0xFFDBF8E8);

  /// Texte et icône des statuts favorables, sur [surligneurPale], [papier]
  /// ou [feuille].
  static const Color vertFonce = Color(0xFF0A6B3E);

  /// Le stylo rouge : pastille « En direct », erreur, absence.
  /// **Jamais décoratif.**
  static const Color rouge = Color(0xFFCE2D3B);
  static const Color surRouge = Color(0xFFFFFFFF);

  /// Fond des statuts « Absent » et des messages d'erreur.
  static const Color rougePale = Color(0xFFFBE1E3);

  /// Texte et icône sur [rougePale].
  static const Color rougeFonce = Color(0xFF93192A);

  /// Le bon point : points gagnés, récompenses, tirages. **Rien d'autre** —
  /// ce n'est pas une couleur d'alerte.
  static const Color bonPoint = Color(0xFFF5C61A);
  static const Color surBonPoint = Color(0xFF141038);
  static const Color bonPointPale = Color(0xFFFCF1C6);

  /// Texte et icône couleur bon point sur fond clair.
  static const Color bonPointFonce = Color(0xFF6B5000);

  // =========================================================================
  // Les couleurs fixes de la marque
  //
  // Logo, icône de l'application, affiches, supports imprimés. Elles ne
  // changent pas avec le thème : une affiche reste la même sur un tableau
  // noir, et un logo imprimé ne connaît pas le réglage du téléphone.
  // =========================================================================

  static const Color marqueViolette = Color(0xFF3A2FC9);
  static const Color marqueSurligneur = Color(0xFF4FE39A);
  static const Color marqueEncre = Color(0xFF141038);
  static const Color marquePapier = Color(0xFFF6F5FB);

  // =========================================================================
  // Le thème Tableau
  //
  // Le second thème de la charte, au choix de l'utilisateur. Cahier reste le
  // thème par défaut. Les quatre couleurs `marque*`, le [surligneur] et le
  // [bonPoint] n'y figurent pas : ils ne changent pas.
  // =========================================================================

  static const Color tableauPapier = Color(0xFF0F0D26);
  static const Color tableauFeuille = Color(0xFF1A1740);
  static const Color tableauEncre = Color(0xFFF3F2FB);
  static const Color tableauCrayon = Color(0xFFB7B5D2);
  static const Color tableauLigne = Color(0xFF74729B);
  static const Color tableauViolette = Color(0xFFB0AAFF);
  static const Color tableauSurViolette = Color(0xFF120E3A);
  static const Color tableauViolettePale = Color(0xFF2A2668);

  /// La violette d'un bouton presse, sur le theme Tableau.
  ///
  /// Eclaircie et non assombrie : assombrir une violette deja pale la ferait
  /// disparaitre dans le fond marine. Comme [violetteAppuyee], elle n'est pas
  /// un second violet de marque — c'est le meme, sous le doigt.
  static const Color tableauVioletteAppuyee = Color(0xFFC8C4FF);
  static const Color tableauSurligneurPale = Color(0xFF11392A);
  static const Color tableauVertFonce = Color(0xFF8FF0BF);
  static const Color tableauRouge = Color(0xFFFF6F78);
  static const Color tableauSurRouge = Color(0xFF2E0509);
  static const Color tableauRougePale = Color(0xFF4A141B);
  static const Color tableauRougeFonce = Color(0xFFFFB5BA);
  static const Color tableauBonPointPale = Color(0xFF3D3206);
  static const Color tableauBonPointFonce = Color(0xFFF8DD74);

  // =========================================================================
  // Les anciens noms
  //
  // 816 usages les nomment. Les garder en alias laisse les 90 écrans
  // compiler et s'afficher dans la nouvelle charte dès ce fichier-ci ; les
  // renommer d'un bloc aurait fait un diff de 816 lignes qui ne dit rien de
  // plus qu'un `sed`.
  //
  // Chacun pointe vers son équivalent de la charte. Deux n'en ont pas, et
  // c'est voulu :
  //
  //   * `heroStart` et `heroEnd` servaient aux dégradés d'en-tête. La charte
  //     n'en laisse aucun : les deux rendent la violette fixe, donc un
  //     dégradé qui les emploie encore est un aplat — visuellement correct,
  //     et l'avertissement dit où le retirer.
  //   * `accent` était le jaune de mise en avant. Il rend le [surligneur],
  //     mais **la règle a changé avec la valeur** : le surligneur est un fond
  //     avec du texte sombre dessus, jamais une couleur de texte. Un
  //     `color: AppColors.accent` qui compilait hier donne aujourd'hui du
  //     vert clair sur du clair. Ces emplois sont repris un par un.
  // =========================================================================

  @Deprecated('Charte EduQuali : utiliser `violette`.')
  static const Color primary = violette;

  @Deprecated('Charte EduQuali : utiliser `violetteAppuyee`.')
  static const Color primaryDark = violetteAppuyee;

  @Deprecated('Charte EduQuali : utiliser `violette`.')
  static const Color primaryLight = violette;

  @Deprecated('Charte EduQuali : utiliser `violettePale`.')
  static const Color primarySurface = violettePale;

  @Deprecated('Charte EduQuali : utiliser `violettePale`.')
  static const Color primarySurfaceStrong = violettePale;

  @Deprecated('Charte EduQuali : pas de degrade. Aplat `marqueViolette`.')
  static const Color heroStart = marqueViolette;

  @Deprecated('Charte EduQuali : pas de degrade. Aplat `marqueViolette`.')
  static const Color heroEnd = marqueViolette;

  @Deprecated(
    'Charte EduQuali : le surligneur est un FOND avec du texte sombre '
    'dessus, jamais une couleur de texte. Utiliser le widget Surlignage.',
  )
  static const Color accent = surligneur;

  @Deprecated('Charte EduQuali : utiliser `marqueEncre`.')
  static const Color surfaceDark = marqueEncre;

  @Deprecated('Charte EduQuali : utiliser `violettePale`.')
  static const Color bandSoft = violettePale;

  /// Les surfaces posées sur un en-tête. Du blanc transparent : elles
  /// suivaient le dégradé au lieu de le trancher, et elles suivent
  /// maintenant l'aplat.
  static const Color onHeroSurface = Color(0x24FFFFFF);
  static const Color onHeroBorder = Color(0x57FFFFFF);
  static const Color onHeroMuted = Color(0xD1FFFFFF);

  @Deprecated('Charte EduQuali : utiliser `feuille`.')
  static const Color background = feuille;

  @Deprecated('Charte EduQuali : utiliser `feuille`.')
  static const Color surface = feuille;

  @Deprecated('Charte EduQuali : utiliser `papier`.')
  static const Color surfaceMuted = papier;

  @Deprecated('Charte EduQuali : utiliser `papier`.')
  static const Color scaffoldAlt = papier;

  @Deprecated('Charte EduQuali : utiliser `encre`.')
  static const Color textPrimary = encre;

  @Deprecated('Charte EduQuali : utiliser `crayon`.')
  static const Color textSecondary = crayon;

  @Deprecated('Charte EduQuali : utiliser `crayon`.')
  static const Color textTertiary = crayon;

  @Deprecated('Charte EduQuali : utiliser `surViolette`.')
  static const Color textOnPrimary = surViolette;

  @Deprecated('Charte EduQuali : utiliser `ligne`.')
  static const Color border = ligne;

  @Deprecated('Charte EduQuali : utiliser `ligne`.')
  static const Color borderStrong = ligne;

  @Deprecated('Charte EduQuali : utiliser `vertFonce`.')
  static const Color success = vertFonce;

  @Deprecated('Charte EduQuali : utiliser `surligneurPale`.')
  static const Color successSurface = surligneurPale;

  @Deprecated('Charte EduQuali : utiliser `bonPointFonce`.')
  static const Color warning = bonPointFonce;

  @Deprecated('Charte EduQuali : utiliser `bonPointPale`.')
  static const Color warningSurface = bonPointPale;

  @Deprecated('Charte EduQuali : utiliser `rouge`.')
  static const Color danger = rouge;

  @Deprecated('Charte EduQuali : utiliser `rougePale`.')
  static const Color dangerSurface = rougePale;

  @Deprecated('Charte EduQuali : utiliser `violette`.')
  static const Color info = violette;

  @Deprecated('Charte EduQuali : utiliser `violettePale`.')
  static const Color infoSurface = violettePale;

  @Deprecated('Charte EduQuali : utiliser `papier`.')
  static const Color neutralSurface = papier;

  /// La barre d'un score, au repos.
  ///
  /// **Une seule teinte, pas une par catégorie.** Ces barres portent une
  /// *même* mesure — le score — répétée sur plusieurs domaines. Le nom du
  /// domaine est déjà écrit à côté : lui donner en plus une couleur propre
  /// n'ajoute aucune information et fait entrer cinq teintes en concurrence.
  static const Color chartBar = ligne;

  /// La barre du domaine qui mérite le regard — le plus faible.
  ///
  /// L'information n'est pas portée par la couleur seule : le pourcentage est
  /// écrit en toutes lettres au bout de chaque barre.
  static const Color chartHighlight = violette;

  /// Couleurs des états réseau (§42).
  static const Color networkOffline = crayon;
  static const Color networkPartial = bonPointFonce;
  static const Color networkOnline = vertFonce;
}
