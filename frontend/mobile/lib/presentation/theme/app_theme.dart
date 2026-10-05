import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

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

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 40;

  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: 20);
  static const EdgeInsets card = EdgeInsets.all(16);

  /// Hauteur minimale de tout ce qui se touche.
  ///
  /// Le plancher d'accessibilite est 44 px ; on prend 48, parce que calculer
  /// la hauteur a partir des marges et de la taille du texte donne un
  /// resultat qui bouge des qu'on touche a la typographie. Une contrainte
  /// explicite ne bouge pas.
  static const double touchTarget = 48;

  /// Ecart minimal entre deux cibles tactiles voisines.
  static const double touchGap = sm;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius field = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.background,
          onSurface: AppColors.textPrimary,
          error: AppColors.danger,
          outlineVariant: AppColors.border,
        );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surfaceMuted,
      textTheme: _textTheme(base.textTheme),
      // La barre des pages de detail et de formulaire.
      //
      // Violette, comme l'en-tete des onglets, mais sans degrade ni hauteur :
      // c'est la meme famille, en version compacte. Deux cents pixels de
      // degrade au-dessus de « Ajouter un diplome » mangeraient un tiers de
      // l'ecran sans rien apprendre — la couleur suffit a dire qu'on est
      // toujours dans la meme application.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
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
      tabBarTheme: const TabBarThemeData(
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
        color: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textTertiary,
          elevation: 2,
          shadowColor: const Color(0x331A1A2E),
          minimumSize: const Size.fromHeight(54),
          // En pastille : c'est la forme du bouton principal des maquettes,
          // et un bord entierement arrondi se distingue mieux d'un champ de
          // saisie, qui reste a coins doux.
          shape: const StadiumBorder(),
          // Majuscules espacees, comme les maquettes : a cote d'un titre en
          // 800, un libelle en casse normale se lit comme du texte et non
          // comme une action.
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _fieldBorder(AppColors.border),
        enabledBorder: _fieldBorder(AppColors.border),
        focusedBorder: _fieldBorder(AppColors.primary, width: 1.6),
        errorBorder: _fieldBorder(AppColors.danger),
        focusedErrorBorder: _fieldBorder(AppColors.danger, width: 1.6),
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 15),
        // L'unite collee au chiffre, dans le champ : « GNF » dans une
        // etiquette au-dessus se perd des qu'on regarde le montant.
        suffixStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 15,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        selectedColor: AppColors.primarySurface,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.border,
        circularTrackColor: AppColors.border,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.borderStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: AppColors.textSecondary,
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        // Coins plus larges que l'ancien 12, mais pas une pastille : le champ
        // doit rester visiblement different du bouton qui le suit.
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: color, width: width),
      );

  /// Le nom de la famille des titres.
  ///
  /// Poppins seulement au-dessus de 20 px : sa geometrie ronde porte un
  /// grand titre, mais sa hauteur d'x plus courte que celle d'Inter la rend
  /// moins lisible en petit. Le corps de texte reste sur la police du
  /// systeme, qui est deja sur l'appareil et dessinee pour ca.
  static const String headingFont = 'Poppins';

  /// Typographie large, forte hierarchie (§54).
  ///
  /// Titres montes a 36/30/26 en 800 le 24/09, d'apres les maquettes de
  /// reference : un titre qui ne pese pas plus que son sous-titre ne fait
  /// pas de hierarchie, il fait deux paragraphes.
  static TextTheme _textTheme(TextTheme base) => base.copyWith(
    displaySmall: const TextStyle(
      fontFamily: headingFont,
      fontSize: 36,
      height: 1.12,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
      letterSpacing: -0.8,
    ),
    headlineLarge: const TextStyle(
      fontFamily: headingFont,
      fontSize: 30,
      height: 1.15,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
      letterSpacing: -0.6,
    ),
    headlineMedium: const TextStyle(
      fontFamily: headingFont,
      fontSize: 26,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
      letterSpacing: -0.5,
    ),
    headlineSmall: const TextStyle(
      fontSize: 21,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      letterSpacing: -0.3,
    ),
    titleLarge: const TextStyle(
      fontSize: 18,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
      letterSpacing: -0.2,
    ),
    titleMedium: const TextStyle(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleSmall: const TextStyle(
      fontSize: 15,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    bodyLarge: const TextStyle(
      fontSize: 17,
      height: 1.5,
      color: AppColors.textPrimary,
    ),
    bodyMedium: const TextStyle(
      fontSize: 16,
      height: 1.5,
      color: AppColors.textSecondary,
    ),
    bodySmall: const TextStyle(
      fontSize: 14,
      height: 1.45,
      color: AppColors.textSecondary,
    ),
    labelLarge: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    labelMedium: const TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
    labelSmall: const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
      color: AppColors.textTertiary,
      letterSpacing: 0.2,
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
abstract final class AppShadows {
  /// Cartes et champs au repos.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A1A1A2E), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x141A1A2E), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Éléments qui appellent l'action.
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x0F1A1A2E), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x1F1A1A2E), blurRadius: 18, offset: Offset(0, 6)),
  ];

  /// Ce qui flotte au-dessus du reste : feuille du bas, menu.
  static const List<BoxShadow> overlay = [
    BoxShadow(color: Color(0x141A1A2E), blurRadius: 4, offset: Offset(0, -1)),
    BoxShadow(color: Color(0x291A1A2E), blurRadius: 28, offset: Offset(0, -8)),
  ];
}
