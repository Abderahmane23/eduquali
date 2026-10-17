import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'interactions.dart';

/// L'en-tete degrade des onglets principaux, d'apres les maquettes du 23/09.
///
/// Il repond a une question et une seule : « ou suis-je, et que puis-je
/// chercher ici ». Le titre, la recherche et les chiffres de tete y vivent ;
/// tout le reste appartient au contenu qui defile dessous.
///
/// Il ne couvre que les cinq onglets de chaque role et la connexion. Une page
/// de formulaire garde une barre compacte : deux cents pixels de degrade
/// au-dessus de « Ajouter un diplome » mangent l'ecran sans rien apprendre.
class GradientHero extends StatelessWidget {
  const GradientHero({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.search,
    this.bottom,
    this.onBack,
  });

  /// La ligne au-dessus du titre — « Bonjour », et le titre porte le nom.
  final String? eyebrow;

  final String title;
  final String? subtitle;

  /// Boutons ronds en haut a droite.
  final List<Widget> actions;

  /// Un [HeroSearchField], quand la page se cherche plus qu'elle ne se lit.
  final Widget? search;

  /// Ce qui ferme l'en-tete : un [HeroStatStrip], le plus souvent.
  final Widget? bottom;

  /// Le retour, sur les pages de detail. Nul sur les onglets, qui n'ont nulle
  /// part ou revenir.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final grand = eyebrow != null;

    return Container(
      width: double.infinity,
      // Un aplat, pas un degrade : la charte n en laisse aucun, et la
        // violette de la marque se suffit.
        decoration: const BoxDecoration(color: AppColors.marqueViolette),
      child: ClipRect(
        child: Stack(
          children: [
            // Deux cercles a peine visibles, debordant du cadre. Ils donnent
            // au degrade une profondeur que deux teintes seules n'ont pas,
            // sans rien ajouter a lire.
            const Positioned(right: -70, top: -90, child: _Halo(size: 260)),
            const Positioned(left: -60, bottom: -110, child: _Halo(size: 220)),

            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onBack != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: HeroIconButton(
                          icon: Icons.arrow_back,
                          tooltip: 'Revenir',
                          onPressed: onBack!,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (eyebrow != null)
                                Text(
                                  eyebrow!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.onHeroMuted,
                                  ),
                                ),
                              Text(
                                title,
                                style: TextStyle(
                                  fontFamily: AppTheme.headingFont,
                                  fontSize: grand ? 26 : 32,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  color: Colors.white,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.onHeroMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        for (final action in actions) ...[
                          const SizedBox(width: AppSpacing.sm),
                          action,
                        ],
                      ],
                    ),

                    if (search != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      search!,
                    ],
                    if (bottom != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      bottom!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      // La surface posee sur l'aplat de violette, declaree une fois
      // dans la palette plutot qu'ecrite a la main : trois ecrans
      // portaient trois transparences differentes.
      color: AppColors.onHeroSurface,
    ),
  );
}

/// Le champ de recherche pose dans l'en-tete.
///
/// Transparent plutot que blanc : un rectangle blanc sur le degrade ferait un
/// trou, et c'est le titre qu'on doit lire en premier.
class HeroSearchField extends StatelessWidget {
  const HeroSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  /// Vrai quand le champ n'est qu'un bouton menant a l'ecran de recherche.
  final bool readOnly;

  @override
  Widget build(BuildContext context) => Container(
    height: AppSpacing.touchTarget + 6,
    decoration: BoxDecoration(
      color: AppColors.onHeroSurface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: AppColors.onHeroBorder),
    ),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      onTap: onTap,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 16, color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        // Sans cela, le theme de l'application remplit le champ de blanc —
        // et le texte, blanc lui aussi, devient invisible alors qu'il est
        // bien saisi. Le fond du champ est deja dessine par le conteneur.
        filled: false,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 16, color: AppColors.onHeroMuted),
        prefixIcon: const Icon(
          Icons.search,
          color: AppColors.onHeroMuted,
          size: 22,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  );
}

/// Un bouton rond dans l'en-tete : la cloche, le crayon, la sortie.
class HeroIconButton extends StatelessWidget {
  const HeroIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = false,
  });

  final IconData icon;

  /// Obligatoire : sans lui, un lecteur d'ecran annonce « bouton » et rien
  /// d'autre.
  final String tooltip;

  final VoidCallback onPressed;

  /// La pastille rouge d'un element non lu.
  final bool badge;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: Pressable(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: AppSpacing.touchTarget,
              height: AppSpacing.touchTarget,
              decoration: BoxDecoration(
                color: AppColors.onHeroSurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.onHeroBorder),
              ),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
            if (badge)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 9,
                  height: 9,
                  // Rouge, et c'est un des rares endroits ou il est permis :
                  // la regle est « destructif ou urgent », et une echeance
                  // qui court est urgente. L'accent jaune, lui, ne remplit
                  // jamais une forme — il ne sert qu'a un mot de titre.
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.danger,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Le bandeau de chiffres qui ferme l'en-tete.
///
/// Trois ou quatre colonnes, pas davantage : la place est prise sur le
/// contenu, et un cinquieme chiffre rend les quatre autres illisibles.
class HeroStatStrip extends StatelessWidget {
  const HeroStatStrip({super.key, required this.items});

  final List<({String value, String label})> items;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.onHeroSurface,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.onHeroBorder),
    ),
    child: IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.onHeroBorder,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.xs,
                ),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        items[i].value,
                        maxLines: 1,
                        style: const TextStyle(
                          fontFamily: AppTheme.headingFont,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onHeroMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Un bouton en pastille dans l'en-tete : « + Creer ».
///
/// Quand l'action est la raison d'etre de la page, le mot vaut mieux que
/// l'icone seule : un « + » rond peut vouloir dire ajouter n'importe quoi.
class HeroPillButton extends StatelessWidget {
  const HeroPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Pressable(
      onTap: onPressed,
      haptic: true,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: AppSpacing.touchTarget,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.onHeroSurface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.onHeroBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
