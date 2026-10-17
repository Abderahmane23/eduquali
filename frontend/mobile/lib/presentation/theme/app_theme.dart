import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Direction artistique (§54) : minimaliste, professionnel, premium.
///
/// **La palette ne vit pas ici.** Elle vivait ici *aussi*, en copie, et les
/// deux ont diverge : les corrections de contraste etaient appliquees a
/// `core/theme/app_colors.dart` pendant que soixante fichiers affichaient
/// cette copie restee a `textTertiary` #9A9AAB, soit 2,7:1 sur blanc. Le
/// test WCAG passait, l'ecran non.
///
/// Ce fichier la re-exporte desormais : un seul endroit ou changer une
/// couleur, et le test protege ce qui s'affiche vraiment.
export '../../core/theme/app_colors.dart' show AppColors;

/// Les espaces et les formes ne vivent pas ici non plus.
///
/// Meme histoire que la palette, et meme reponse : ils existaient en double —
/// ici et dans `core/theme/app_spacing.dart` — avec des valeurs differentes
/// pour les memes noms. `md` valait 12 d'un cote et 16 de l'autre, `lg` 16 et
/// 20. Dix-huit fichiers lisaient l'un, soixante-dix l'autre.
///
/// Une seule source, dans `core`, et ce fichier la re-exporte.
export '../../core/theme/app_spacing.dart' show AppSpacing, AppRadius;

/// Les deux epaisseurs de contour de la charte.
///
/// **Pas d'ombre, pas de degrade.** C'est le trait qui pose un element, et il
/// se voit en plein soleil la ou une ombre de 12 px disparait — precisement
/// la condition dans laquelle ce produit sert.
abstract final class AppTrait {
  /// Contour des cartes, des champs, des places libres.
  static const double fin = 1.5;

  /// Contour de la carte du prochain cours, d'un choix selectionne, anneau
  /// de focus.
  static const double fort = 2.5;

  /// Le contour au repos.
  static const BorderSide repos = BorderSide(
    color: AppColors.ligne,
    width: fin,
  );

  /// Le contour de ce qui compte : la carte du prochain cours, le point de
  /// controle, un choix selectionne.
  static const BorderSide marque = BorderSide(
    color: AppColors.encre,
    width: fort,
  );
}

/// Les seize couleurs qui changent entre les deux themes de la charte.
///
/// --- Pourquoi un objet plutot que deux themes ecrits a la main ----------
///
/// La charte tient deux themes : Cahier, clair, par defaut ; Tableau, sombre,
/// au choix de l'utilisateur. Les ecrire tous les deux donnerait trois cents
/// lignes en double, et ce code a deja paye cette derive : la palette vivait
/// en deux exemplaires, et les corrections de contraste etaient appliquees a
/// l'une pendant que soixante fichiers affichaient l'autre.
///
/// Ce qui n'est **pas** ici ne change pas de theme, et c'est leur definition :
/// le `surligneur`, le `bonPoint` et les quatre couleurs `marque*`. Un
/// surligneur reste un surligneur sur un tableau noir.
class Palette {
  const Palette({
    required this.papier,
    required this.feuille,
    required this.encre,
    required this.crayon,
    required this.ligne,
    required this.violette,
    required this.surViolette,
    required this.violettePale,
    required this.violetteAppuyee,
    required this.surligneurPale,
    required this.vertFonce,
    required this.rouge,
    required this.surRouge,
    required this.rougePale,
    required this.rougeFonce,
    required this.bonPointPale,
    required this.bonPointFonce,
  });

  final Color papier;
  final Color feuille;
  final Color encre;
  final Color crayon;
  final Color ligne;
  final Color violette;
  final Color surViolette;
  final Color violettePale;
  final Color violetteAppuyee;
  final Color surligneurPale;
  final Color vertFonce;
  final Color rouge;
  final Color surRouge;
  final Color rougePale;
  final Color rougeFonce;
  final Color bonPointPale;
  final Color bonPointFonce;

  /// Cahier : le theme par defaut.
  static const Palette cahier = Palette(
    papier: AppColors.papier,
    feuille: AppColors.feuille,
    encre: AppColors.encre,
    crayon: AppColors.crayon,
    ligne: AppColors.ligne,
    violette: AppColors.violette,
    surViolette: AppColors.surViolette,
    violettePale: AppColors.violettePale,
    violetteAppuyee: AppColors.violetteAppuyee,
    surligneurPale: AppColors.surligneurPale,
    vertFonce: AppColors.vertFonce,
    rouge: AppColors.rouge,
    surRouge: AppColors.surRouge,
    rougePale: AppColors.rougePale,
    rougeFonce: AppColors.rougeFonce,
    bonPointPale: AppColors.bonPointPale,
    bonPointFonce: AppColors.bonPointFonce,
  );

  /// Tableau : le theme sombre, au choix de l'utilisateur.
  static const Palette tableau = Palette(
    papier: AppColors.tableauPapier,
    feuille: AppColors.tableauFeuille,
    encre: AppColors.tableauEncre,
    crayon: AppColors.tableauCrayon,
    ligne: AppColors.tableauLigne,
    violette: AppColors.tableauViolette,
    surViolette: AppColors.tableauSurViolette,
    violettePale: AppColors.tableauViolettePale,
    violetteAppuyee: AppColors.tableauVioletteAppuyee,
    surligneurPale: AppColors.tableauSurligneurPale,
    vertFonce: AppColors.tableauVertFonce,
    rouge: AppColors.tableauRouge,
    surRouge: AppColors.tableauSurRouge,
    rougePale: AppColors.tableauRougePale,
    rougeFonce: AppColors.tableauRougeFonce,
    bonPointPale: AppColors.tableauBonPointPale,
    bonPointFonce: AppColors.tableauBonPointFonce,
  );
}

abstract final class AppTheme {
  /// Le theme Cahier, clair : celui par defaut.
  static ThemeData get light => _construire(Palette.cahier, Brightness.light);

  /// Le theme Tableau, sombre : le second de la charte.
  ///
  /// Il suit le reglage du telephone. La charte le donne « au choix de
  /// l'utilisateur » : le reglage systeme **est** ce choix tant qu'il n'y a
  /// pas de selecteur dans l'application, et c'est le comportement que les
  /// gens attendent d'un telephone.
  static ThemeData get dark => _construire(Palette.tableau, Brightness.dark);

  /// Un theme, a partir d'une palette.
  ///
  /// Une seule fonction pour les deux : c'est ce qui garantit qu'ils ne
  /// divergent pas. Ajouter un composant au theme le dote des deux themes
  /// d'un coup, et il n'y a pas d'endroit ou l'oublier.
  static ThemeData _construire(Palette p, Brightness brightness) {

    /*
     * La police par defaut, et pourquoi elle manquait.
     *
     * `ThemeData` n'en declarait aucune : tout texte dont le style ne nomme
     * pas sa famille tombait donc sur la police du systeme — Roboto sur
     * Android. Les **libelles de boutons** en faisaient partie : le bouton
     * principal de chaque ecran, celui qu'on regarde avant de taper, etait
     * dans une quatrieme police que la charte ne contient pas.
     *
     * Rien ne le signalait. Roboto et Lexend sont toutes deux des linéales
     * sans empattement, et la difference ne saute aux yeux que posees cote a
     * cote — ce qu'une capture de l'ecran a fini par faire.
     */
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontTexte,
    );
    final scheme =
        ColorScheme.fromSeed(
          seedColor: p.violette,
          brightness: brightness,
        ).copyWith(
          primary: p.violette,
          onPrimary: Colors.white,
          surface: p.feuille,
          onSurface: p.encre,
          error: p.rouge,
          outlineVariant: p.ligne,
        );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: p.papier,
      textTheme: _textTheme(base.textTheme),
      // La barre des pages de detail et de formulaire.
      //
      // Violette, comme l'en-tete des onglets, mais sans degrade ni hauteur :
      // c'est la meme famille, en version compacte. Deux cents pixels de
      // degrade au-dessus de « Ajouter un diplome » mangeraient un tiers de
      // l'ecran sans rien apprendre — la couleur suffit a dire qu'on est
      // toujours dans la meme application.
      appBarTheme: AppBarTheme(
        backgroundColor: p.violette,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: headingFont,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          // Icones claires : la barre est desormais sombre.
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      // Les onglets vivent sous la barre de titre, qui est violette : leurs
      // libelles sont donc blancs. Pose ici et non ecran par ecran, sinon la
      // prochaine `TabBar` ajoutee naitra illisible.
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.onHeroMuted,
        indicatorColor: Colors.white,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.feuille,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.rayonCarte),
          side: AppTrait.repos,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.ligne,
        thickness: AppTrait.fin,
        space: AppTrait.fin,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.violette,
          foregroundColor: Colors.white,
          disabledBackgroundColor: p.ligne,
          disabledForegroundColor: p.crayon,
          // Zero : la charte ne laisse aucune ombre, et un bouton plein
          // en violette sur du papier n'en a pas besoin pour se voir.
          elevation: 0,
          minimumSize: const Size.fromHeight(AppSpacing.ciblePrincipale),
          // En pastille : c'est la forme du bouton principal des maquettes,
          // et un bord entierement arrondi se distingue mieux d'un champ de
          // saisie, qui reste a coins doux.
          shape: const StadiumBorder(),
          // Majuscules espacees, comme les maquettes : a cote d'un titre en
          // 800, un libelle en casse normale se lit comme du texte et non
          // comme une action.
          textStyle: TextStyle(
            // Gabarito, nommee : le 800 n'existe que dans cette famille, et
            // sans la nommer le libelle retombait sur la police du systeme.
            fontFamily: fontTitre,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.encre,
          minimumSize: const Size.fromHeight(AppSpacing.cible),
          // Cerne d'encre, pas de gris : c'est le bouton second de la charte,
          // et un contour gris sur du papier gris ne se voit pas.
          side: AppTrait.marque,
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontFamily: fontTitre,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.violette,
          textStyle: TextStyle(
            fontFamily: fontTexte,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.feuille,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _fieldBorder(p.ligne, width: AppTrait.fin),
        enabledBorder: _fieldBorder(p.ligne, width: AppTrait.fin),
        focusedBorder: _fieldBorder(p.violette, width: AppTrait.fort),
        errorBorder: _fieldBorder(p.rouge, width: AppTrait.fin),
        focusedErrorBorder: _fieldBorder(p.rouge, width: AppTrait.fort),
        hintStyle: TextStyle(color: p.crayon, fontSize: 15),
        // L'unite collee au chiffre, dans le champ : « GNF » dans une
        // etiquette au-dessus se perd des qu'on regarde le montant.
        suffixStyle: TextStyle(
          color: p.crayon,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        labelStyle: TextStyle(
          color: p.crayon,
          fontSize: 15,
        ),
        floatingLabelStyle: TextStyle(
          color: p.violette,
          fontWeight: FontWeight.w600,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.papier,
        selectedColor: p.violettePale,
        side: BorderSide(color: p.ligne),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: p.encre,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.feuille,
        selectedItemColor: p.violette,
        unselectedItemColor: p.crayon,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.feuille,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.feuille,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.rayonCarte),
          side: AppTrait.repos,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.encre,
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.violette,
        linearTrackColor: p.ligne,
        circularTrackColor: p.ligne,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.violette
              : p.ligne,
        ),
        trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: p.crayon,
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        // Le rayon de champ de la charte, 12 : il doit rester visiblement
        // different du bouton qui le suit, qui est en pastille.
        borderRadius: BorderRadius.circular(AppRadius.rayonChamp),
        borderSide: BorderSide(color: color, width: width),
      );

  /// Le nom de la famille des titres.
  ///
  /// Titres, chiffres et prix.
  ///
  /// Gabarito, dessinee par Naipe Foundry pour une plateforme bresilienne de
  /// cours en ligne — son nom designe, en portugais du Bresil, la grille de
  /// reponses d'un examen. Ronde, ferme, et ses chiffres se lisent de loin,
  /// ce qui compte pour un montant et pour un decompte de minutes.
  ///
  /// Remplace Poppins, « la police de tres nombreuses applications ».
  static const String fontTitre = 'Gabarito';

  /// Tout le reste : textes, boutons, libelles.
  ///
  /// Lexend, concue par Bonnie Shaver-Troup, therapeute de l'education, pour
  /// rendre la lecture plus facile : des lettres larges, bien espacees. Elle
  /// remplace Inter et la police du systeme.
  static const String fontTexte = 'Lexend';

  /// Un mot ou deux, comme une annotation dans la marge.
  ///
  /// Playwrite FR Moderne, de TypeTogether, reprend l'ecriture enseignee a
  /// l'ecole primaire en France. « Present ! », « Vu », « Bravo » — jamais
  /// une phrase, jamais un bouton, une seule fois par ecran.
  static const String fontAnnotation = 'Playwrite FR Moderne';

  @Deprecated('Charte EduQuali : utiliser `fontTitre`.')
  static const String headingFont = fontTitre;

  /// L'echelle de la charte EduQuali.
  ///
  /// Deux groupes et une exception. Les titres, les chiffres et les prix sont
  /// en Gabarito ; tout le reste est en Lexend ; un mot par ecran peut passer
  /// en Playwrite, et il se pose a la main par le widget `Annotation`.
  ///
  /// **Le texte courant ne descend jamais sous 16 px, le secondaire sous
  /// 14.** C'est la regle de la charte, et c'est la raison d'etre de Lexend :
  /// des lettres larges et bien espacees ne servent a rien a 12 px.
  ///
  /// Les noms Material sont conserves — `displaySmall`, `bodyMedium` — parce
  /// que `Theme.of(context).textTheme` les nomme dans 163 endroits. Le
  /// commentaire de chacun donne son nom de charte.
  static TextTheme _textTheme(TextTheme base) => base.copyWith(
    // `affiche` — affiches, couvertures, ecran d'accueil. Une phrase courte,
    // un seul mot surligne.
    displaySmall: const TextStyle(
      fontFamily: fontTitre,
      fontSize: 44,
      height: 1.05,
      fontWeight: FontWeight.w800,
      color: AppColors.encre,
      letterSpacing: -0.01 * 44,
    ),
    // `chiffre` — le nombre que l'on lit d'abord : minutes de presence,
    // revenu du mois.
    displayMedium: const TextStyle(
      fontFamily: fontTitre,
      fontSize: 56,
      height: 1,
      fontWeight: FontWeight.w800,
      color: AppColors.encre,
    ),
    // `prix` — toujours avec « GNF » et une espace entre les milliers.
    headlineLarge: const TextStyle(
      fontFamily: fontTitre,
      fontSize: 28,
      height: 1.1,
      fontWeight: FontWeight.w700,
      color: AppColors.encre,
    ),
    // `titre-ecran`
    headlineMedium: const TextStyle(
      fontFamily: fontTitre,
      fontSize: 26,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: AppColors.encre,
    ),
    // `titre-carte` — titre d'un cours, d'une carte, d'une section.
    headlineSmall: const TextStyle(
      fontFamily: fontTitre,
      fontSize: 20,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: AppColors.encre,
    ),
    titleLarge: const TextStyle(
      fontFamily: fontTitre,
      fontSize: 20,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: AppColors.encre,
    ),
    // `corps-fort` — libelle d'une ligne, matiere et classe, mot cle.
    titleMedium: const TextStyle(
      fontFamily: fontTexte,
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: AppColors.encre,
    ),
    titleSmall: const TextStyle(
      fontFamily: fontTexte,
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: AppColors.encre,
    ),
    // `corps` — texte courant. Jamais sous 16 px.
    bodyLarge: const TextStyle(
      fontFamily: fontTexte,
      fontSize: 16,
      height: 1.5,
      color: AppColors.encre,
    ),
    bodyMedium: const TextStyle(
      fontFamily: fontTexte,
      fontSize: 16,
      height: 1.5,
      color: AppColors.crayon,
    ),
    // `secondaire` — dates, precisions, legendes. Jamais plus petit.
    bodySmall: const TextStyle(
      fontFamily: fontTexte,
      fontSize: 14,
      height: 1.45,
      color: AppColors.crayon,
    ),
    // `bouton` — un verbe, puis l'objet.
    labelLarge: const TextStyle(
      fontFamily: fontTexte,
      fontSize: 17,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.encre,
    ),
    labelMedium: const TextStyle(
      fontFamily: fontTexte,
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w500,
      color: AppColors.crayon,
    ),
    // `etiquette` — sur-titre en capitales, quatre mots au plus. Le seul
    // style autorise sous 14 px, et le seul en capitales continues.
    labelSmall: const TextStyle(
      fontFamily: fontTexte,
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppColors.crayon,
      letterSpacing: 0.07 * 12,
    ),
  );
}

/// Ombres portées.
///
/// Discrètes et jamais décoratives : elles servent à détacher un élément de
/// son fond. Sur un écran de téléphone en plein soleil, une bordure fine ne
/// suffit pas à dire où commence une carte.
/// Les ombres, en deux couches.
///
/// Une seule couche large donne un halo flou qui grise le fond sans poser
/// l'element. Deux couches — une courte et dense au contact, une longue et
/// diffuse dessous — donnent une vraie assise : c'est ainsi que la lumiere
/// se comporte.
/// Les ombres de la charte : il n'y en a pas.
///
/// --- Pourquoi la classe reste ------------------------------------------
///
/// « Pas d'ombre, pas de degrade, pas de carte a bord colore. » Le relief
/// vient du contour : [AppTrait.fin] en `ligne`, [AppTrait.fort] en `encre`.
/// Un trait se voit en plein soleil la ou une ombre de 12 px disparait, et
/// c'est precisement la condition dans laquelle ce produit sert.
///
/// Les trois listes sont donc **vides**, et non retirees. Huit fichiers les
/// nomment ; les supprimer d'un coup aurait casse la compilation de huit
/// ecrans en meme temps que le changement de palette, et l'on n'aurait plus
/// su laquelle des deux choses avait casse quoi. Vides, elles ne dessinent
/// rien et l'avertissement dit ou les retirer.
abstract final class AppShadows {
  @Deprecated('Charte EduQuali : pas d ombre. Utiliser AppTrait.repos.')
  static const List<BoxShadow> card = [];

  @Deprecated('Charte EduQuali : pas d ombre. Utiliser AppTrait.marque.')
  static const List<BoxShadow> raised = [];

  @Deprecated('Charte EduQuali : pas d ombre. Un trait en haut de la barre.')
  static const List<BoxShadow> overlay = [];
}
