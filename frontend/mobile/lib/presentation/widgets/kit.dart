import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common.dart';
import 'interactions.dart';
import 'marque.dart';

/// Les pieces du dessin du 23/09, communes aux trois roles.
///
/// Elles existent pour qu'une carte de cours, une offre d'emploi et une
/// echeance de paiement se ressemblent sans se recopier : soixante-huit
/// ecrans redessines un par un auraient diverge avant la fin.

/// Les deux couleurs d'un ton : le fond de la pastille, et ce qu'on pose
/// dessus.
({Color surface, Color ink}) tonePair(StatusTone tone) => switch (tone) {
  StatusTone.primary => (
    surface: AppColors.primarySurface,
    ink: AppColors.primary,
  ),
  StatusTone.success => (
    surface: AppColors.successSurface,
    ink: AppColors.success,
  ),
  StatusTone.warning => (
    surface: AppColors.warningSurface,
    ink: AppColors.warning,
  ),
  StatusTone.danger => (
    surface: AppColors.dangerSurface,
    ink: AppColors.danger,
  ),
  StatusTone.info => (surface: AppColors.infoSurface, ink: AppColors.info),
  StatusTone.neutral => (
    surface: AppColors.neutralSurface,
    ink: AppColors.textSecondary,
  ),
};

/// Le carre arrondi teinte qui porte une icone.
///
/// C'est lui qui donne son rythme aux listes : l'œil descend la colonne des
/// pastilles et trouve chaque ligne sans relire les titres.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.tone = StatusTone.primary,
    this.size = 44,
  });

  final IconData icon;
  final StatusTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (:surface, :ink) = tonePair(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: ink, size: size * 0.47),
    );
  }
}

/// Les initiales d'un etablissement, a la place d'un logo qu'on n'a pas.
///
/// Une pastille vide ferait une colonne de trous ; deux lettres suffisent a
/// distinguer le Lycee Donka de l'Universite Nongo d'un coup d'œil.
class InitialsTile extends StatelessWidget {
  const InitialsTile({
    super.key,
    required this.name,
    this.tone = StatusTone.primary,
    this.size = 44,
  });

  final String name;
  final StatusTone tone;
  final double size;

  /// Deux lettres tirees des deux premiers mots, ou des deux premieres
  /// lettres quand il n'y a qu'un mot.
  static String initialsOf(String name) {
    final mots = [
      for (final m in name.trim().split(RegExp(r'[\s-]+')))
        if (m.isNotEmpty) m,
    ];
    if (mots.isEmpty) return '?';
    if (mots.length == 1) {
      final seul = mots.first;
      return (seul.length == 1 ? seul : seul.substring(0, 2)).toUpperCase();
    }
    return '${mots[0][0]}${mots[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final (:surface, :ink) = tonePair(tone);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
    );
  }
}

/// Le titre d'une section : un point, un titre, parfois un lien a droite.
///
/// Le point n'est pas une decoration : il marque le debut d'un bloc dans une
/// page qui n'a plus de barres de separation.
class KitSectionTitle extends StatelessWidget {
  const KitSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(right: AppSpacing.sm),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, AppSpacing.touchTarget),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: Text(actionLabel!),
          ),
      ],
    ),
  );
}

/// La carte blanche du nouveau dessin : coins larges, ombre douce, pas de
/// bordure.
///
/// L'ancienne [AppCard] gardait un trait : c'etait ce qui la detachait d'un
/// fond blanc. Le fond de page est desormais lavande, l'ombre suffit, et
/// retirer le trait rend la page nettement plus calme.
class KitCard extends StatelessWidget {
  const KitCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final contenu = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );

    if (onTap == null) return contenu;
    return Pressable(
      onTap: onTap,
      haptic: true,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: contenu,
    );
  }
}

/// Une ligne de liste : pastille, titre, sous-titre, etiquettes, et une
/// barre de precisions sous un filet.
///
/// C'est la carte des offres d'emploi et du catalogue. Le filet separe ce
/// qu'on lit — le poste, l'ecole — de ce qu'on compare — la ville, le
/// salaire : on descend la colonne des montants sans relire les titres.
class ListItemCard extends StatelessWidget {
  const ListItemCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.chips = const [],
    this.meta = const [],
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final List<Widget> chips;

  /// Ce qui vit sous le filet. Le dernier element est pousse a droite : c'est
  /// la place du montant.
  final List<Widget> meta;

  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: KitCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs + 2,
                        runSpacing: AppSpacing.xs,
                        children: chips,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (var i = 0; i < meta.length; i++) ...[
                  if (i == meta.length - 1 && meta.length > 1) const Spacer(),
                  if (i > 0 && i < meta.length - 1)
                    const SizedBox(width: AppSpacing.lg),
                  meta[i],
                ],
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

/// Une precision sous le filet : « Conakry », « Il y a 2 h », « 4 h 30 ».
class MetaText extends StatelessWidget {
  const MetaText(this.label, {super.key, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.xs),
      ],
      /*
       * `Flexible`, et une coupure propre.
       *
       * Le texte etait pose nu dans la rangee : une precision un peu longue
       * — « soir · 10e annee · M. Camara » sur un telephone de 390 points —
       * la faisait deborder. Flutter rogne alors le texte et peint des
       * hachures jaunes, visibles en debogage seulement : dans l'APK, la
       * precision se coupait en silence au milieu d'un mot.
       */
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
    ],
  );
}

/// Un montant, a droite d'une ligne. C'est ce qu'on compare.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.suffix,
    this.tone = StatusTone.primary,
  });

  final String amount;

  /// « /mois », « GNF/mois » — plus petit, car il se repete a chaque ligne.
  final String? suffix;

  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (surface: _, :ink) = tonePair(tone);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          /*
           * Les deux familles sont nommees, et il le faut.
           *
           * `RichText` ne descend pas du `DefaultTextStyle` : il construit
           * son arbre de styles a partir de rien. Un `TextSpan` sans
           * `fontFamily` tombe donc sur la police du systeme, quoi que dise
           * le theme — et **tous les prix de l'application** etaient en
           * Roboto, la seule police que la charte ne contient pas.
           *
           * Le defaut ne se voyait nulle part : Roboto et Gabarito sont
           * toutes deux des lineales, et la difference ne saute aux yeux que
           * posees cote a cote.
           */
          TextSpan(
            text: amount,
            style: TextStyle(
              fontFamily: AppTheme.fontTitre,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          if (suffix != null)
            TextSpan(
              text: suffix,
              style: const TextStyle(
                fontFamily: AppTheme.fontTexte,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Une action rapide : pastille, titre, sous-titre, parfois un compte.
///
/// Le trait de couleur en bas a gauche rattache la carte a son ton sans
/// teinter toute la surface — une carte entierement coloree se lit moins
/// bien, et quatre d'entre elles se disputent l'attention.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.count,
    this.tone = StatusTone.primary,
    this.compact = false,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// « 12 offres », « 5 demandes ».
  final String? count;

  final StatusTone tone;

  /// Version basse : pastille et titre sur une ligne.
  ///
  /// Deux cartes hautes en tete d'accueil repoussaient sous la ligne de
  /// flottaison ce qu'on vient vraiment voir — ses seances, ses paiements.
  /// Une action rapide doit se toucher, pas se contempler.
  final bool compact;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (:surface, :ink) = tonePair(tone);

    if (compact) {
      return KitCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            IconTile(icon: icon, tone: tone, size: 36),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return KitCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(icon: icon, tone: tone, size: 46),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (count != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      count!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            height: 4,
            width: 54,
            decoration: BoxDecoration(
              color: ink,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(AppRadius.lg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un chiffre du bloc « Statistiques » : pastille, ecart, valeur, libelle.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.delta,
    this.tone = StatusTone.primary,
    this.compact = false,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;

  /// L'ecart depuis la periode precedente : « +3 », « -1 ». Absent quand on
  /// n'a pas de periode precedente — inventer « +0 » ferait croire a une
  /// stagnation mesuree.
  final String? delta;

  final StatusTone tone;

  /// Version basse. Quatre tuiles pleine taille prennent un ecran entier
  /// pour quatre nombres a deux chiffres ; ce qui compte ici est de les
  /// voir ensemble, pas de les voir gros.
  final bool compact;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final baisse = delta != null && delta!.startsWith('-');
    return KitCard(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: icon, tone: tone, size: compact ? 32 : 40),
              const Spacer(),
              if (delta != null)
                Text(
                  delta!,
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: baisse ? AppColors.danger : AppColors.success,
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppTheme.headingFont,
                fontSize: compact ? 22 : 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une grille de deux colonnes qui accepte un nombre impair d'elements.
///
/// `GridView` reclame une hauteur bornee et refuse donc de vivre dans une
/// liste ; et un `Row` en `stretch` y recevrait une hauteur infinie — c'est
/// exactement ce qui avait fait disparaitre les tableaux de bord le 23/09.
class KitGrid extends StatelessWidget {
  const KitGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rangees = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final droite = i + 1 < children.length ? children[i + 1] : null;
      rangees.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: AppSpacing.md),
                // Une case vide plutot qu'une carte etiree : seule, elle
                // ferait deux fois la largeur de ses voisines.
                Expanded(child: droite ?? const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rangees);
  }
}

/// La carte violette qui pousse vers une action : « Creer un cours ».
///
/// Une par page au plus. Deux se neutralisent, et le contenu en dessous
/// passe pour du remplissage.
class PromoCard extends StatelessWidget {
  const PromoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Pressable(
      onTap: onTap,
      haptic: true,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          // Un aplat, pas un degrade.
          color: AppColors.marqueViolette,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.onHeroSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.onHeroMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.onHeroSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// La rangee de filtres, qui defile horizontalement.
///
/// Le filtre choisi est plein, les autres sont blancs : deux etats, pas
/// trois. Un troisieme niveau de gris ferait hesiter sur ce qui est actif.
class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<({String label, IconData? icon})> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppSpacing.touchTarget,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
      itemBuilder: (context, i) {
        final actif = i == selected;
        return Pressable(
          onTap: () => onSelected(i),
          haptic: true,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: actif ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (items[i].icon != null) ...[
                  Icon(
                    items[i].icon,
                    size: 17,
                    color: actif ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                ],
                Text(
                  items[i].label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: actif ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// L'etat vide d'un bloc : un rond, une phrase, un bouton.
///
/// Dans la carte du bloc, pas a la place de la page : le titre de section
/// reste lisible, et on voit que le bloc existe et qu'il est simplement vide.
class KitEmpty extends StatelessWidget {
  const KitEmpty({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => KitCard(
    padding: const EdgeInsets.symmetric(
      vertical: AppSpacing.xl,
      horizontal: AppSpacing.lg,
    ),
    child: Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primarySurface,
          ),
          child: Icon(icon, color: AppColors.primary, size: 27),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSpacing.md),
          Pressable(
            onTap: onAction!,
            haptic: true,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              height: AppSpacing.touchTarget,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              // Le libelle est `Flexible` : sans cela, la rangee prend sa
              // largeur naturelle et deborde des que le texte est long.
              // Constate en rendant l'accueil pour la presentation — 64
              // pixels a droite, soit la barre rayee jaune et noir sur un
              // telephone de 390 points. Une action d'etat vide porte
              // souvent une phrase (« Trouver un professeur a domicile »)
              // et non un mot.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Flexible(
                    child: Text(
                      actionLabel!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Le petit bouton « + Ajouter » a droite d'un titre de section.
class AddPill extends StatelessWidget {
  const AddPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    haptic: true,
    borderRadius: BorderRadius.circular(AppRadius.pill),
    child: Container(
      height: AppSpacing.touchTarget - 8,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, size: 17, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// La barre du bas, commune aux trois espaces.
///
/// Un seul exemplaire pour les trois roles : trois barres recopiees avaient
/// deja diverge — le professeur en `BottomNavigationBar`, le parent en
/// `NavigationBar`, deux hauteurs et deux facons de marquer l'onglet actif.
///
/// L'onglet actif porte un trait au-dessus de lui *et* la couleur : la
/// couleur seule ne se voit pas sur un ecran en plein soleil, et pas du tout
/// pour qui distingue mal le violet du gris.
class KitBottomNav extends StatelessWidget {
  const KitBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<({IconData icon, IconData active, String label})> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == currentIndex,
                  button: true,
                  label: items[i].label,
                  child: Pressable(
                    onTap: () => onTap(i),
                    haptic: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Le trait de l'onglet actif, colle en haut.
                        Container(
                          height: 3,
                          width: 26,
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: i == currentIndex
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Icon(
                          i == currentIndex ? items[i].active : items[i].icon,
                          size: 23,
                          color: i == currentIndex
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: i == currentIndex
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == currentIndex
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Ce que les pages de detail et les formulaires reclamaient.
// ---------------------------------------------------------------------------

/// Le bouton principal, colle en bas de l'ecran.
///
/// Sur « Publier une offre », il fallait derouler tout le formulaire pour le
/// trouver — et donc pour savoir qu'il existait. Ici il ne bouge pas, et son
/// filet de separation dit qu'il y a du contenu derriere lui.
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
    this.note,
  });

  final String label;

  /// Nul desactive le bouton : un bouton grise qui reste visible vaut mieux
  /// qu'un bouton qui disparait, car on comprend ce qu'il faudra remplir.
  final VoidCallback? onPressed;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;

  /// Une ligne au-dessus du bouton : le prix, une condition, un rappel.
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (note != null) ...[
              Text(
                note!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                if (secondaryLabel != null && onSecondary != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: busy ? null : onPressed,
                    // Majuscules ici et non dans chaque appel : c'est le
                    // bouton principal de la page, et il doit se lire comme
                    // une action a cote d'un titre en 800.
                    child: Text(busy ? 'UN INSTANT…' : label.toUpperCase()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Un groupe de champs, titre, dans une carte.
///
/// Un formulaire long sans groupes est une colonne indifferenciee : on ne
/// sait pas ou l'on en est ni ce qu'il reste. Trois a cinq champs par groupe,
/// pas davantage.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.children,
  });

  final String title;

  /// Pourquoi on demande ces champs-la. Une ligne, quand ce n'est pas evident.
  final String? subtitle;

  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: KitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                IconTile(icon: icon!, size: 38),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    ),
  );
}

/// Le nom d'un champ, pose au-dessus de lui.
///
/// Au-dessus et non dedans : un libelle flottant disparait des qu'on tape, et
/// il faut alors se rappeler ce qu'on etait en train de remplir.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.optional = false});

  final String text;

  /// Le dire quand ce n'est pas obligatoire evite de faire chercher.
  final bool optional;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'facultatif',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ],
    ),
  );
}

/// « Etape 2 sur 4 », avec sa barre.
///
/// Sur un parcours long, savoir combien il reste change la decision de
/// continuer. Sans ce reperage, chaque ecran peut etre l'avant-dernier.
class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    this.subtitle,
  });

  final int step;
  final int total;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Étape $step sur $total',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : step / total,
            minHeight: 6,
            backgroundColor: AppColors.primarySurface,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    ),
  );
}

/// L'en-tete d'une feuille qui monte du bas : titre, sous-titre, fermeture.
///
/// Les quatre feuilles de l'application avaient chacune la sienne, et donc
/// quatre hauteurs de titre et deux facons de fermer.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Fermer',
          icon: const Icon(Icons.close, size: 22),
        ),
      ],
    ),
  );
}

/// Deux ou trois choix exclusifs, sur une ligne.
///
/// Remplace une liste de boutons radio, qui prend quatre fois la place pour
/// dire la meme chose — et qui, empilee, se lit comme une liste de reglages
/// plutot que comme un choix unique.
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.neutralSurface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              selected: i == selected,
              button: true,
              child: Pressable(
                onTap: () => onSelected(i),
                haptic: true,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  height: AppSpacing.touchTarget - 8,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected
                        ? AppColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: i == selected ? AppShadows.card : null,
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: i == selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Quelqu'un, dans une liste : photo, nom, role, et une action.
///
/// La meme ligne dans la salle de recrutement, les candidatures et la
/// recherche de professeurs — trois ecrans qui montraient la meme personne
/// de trois facons.
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.name,
    this.subtitle,
    this.photoPath,
    this.chips = const [],
    this.meta = const [],
    this.trailing,
    this.onTap,
  });

  final String name;
  final String? subtitle;
  final String? photoPath;
  final List<Widget> chips;
  final List<Widget> meta;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mots = name.trim().split(RegExp(r'\s+'));
    return ListItemCard(
      onTap: onTap,
      leading: ProfileAvatar(
        firstName: mots.isEmpty ? '' : mots.first,
        lastName: mots.length > 1 ? mots.last : '',
        photoPath: photoPath,
        size: 48,
      ),
      title: name,
      subtitle: subtitle,
      chips: chips,
      meta: meta,
      trailing: trailing,
    );
  }
}

/// Un titre dont un mot porte l'accent.
///
/// Le procede le plus efficace des maquettes de reference : sur un titre de
/// trois lignes, l'œil attrape le mot colore et lit le reste autour. Un seul
/// segment accentue — deux se neutralisent.
class TwoToneTitle extends StatelessWidget {
  const TwoToneTitle({
    super.key,
    required this.before,
    required this.accented,
    this.after = '',
    this.size = 34,
    this.onDark = true,
  });

  final String before;
  final String accented;
  final String after;
  final double size;

  /// Sur fond sombre le texte courant est blanc ; sur fond clair, il est
  /// encre. L'accent, lui, ne change pas.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: AppTheme.headingFont,
      fontSize: size,
      fontWeight: FontWeight.w800,
      height: 1.12,
      color: onDark ? Colors.white : AppColors.textPrimary,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: before, style: base),
          /*
           * --- Ce qui a change avec la charte EduQuali ----------------
           *
           * Le mot accentue etait pose en couleur de texte : violette sur
           * fond clair, surligneur sur fond sombre. La charte l'interdit —
           * « le surligneur : jamais un bouton, jamais du texte » — et pour
           * une raison lisible : du vert clair en corps de texte ne passe
           * aucun plancher de contraste, alors que du texte sombre sur un
           * aplat de surligneur atteint 11:1.
           *
           * C'est donc le surlignage lui-meme, avec son biseau, et c'est le
           * quatrieme signe de la marque : « dans un cahier, on surligne ce
           * qu'il faut retenir ».
           *
           * Un `WidgetSpan` et non deux `Text` cote a cote : la phrase doit
           * pouvoir se couper n'importe ou, y compris au milieu du passage
           * surligne, et seul un `RichText` sait le faire.
           */
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Surlignage(accented, style: base),
          ),
          TextSpan(text: after, style: base),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ce que les maquettes de reference font, et que nous ne faisions pas.
// ---------------------------------------------------------------------------

/// Le fond d'une bande de section.
enum BandTone {
  /// Blanc franc. Le defaut d'une page de contenu.
  plain,

  /// Bleu tres pale. Detache une section sans la separer d'un trait.
  soft,

  /// Marine. Une section par page au plus, sinon elle cesse de se detacher.
  dark,
}

/// Une bande pleine largeur, d'un bord a l'autre.
///
/// C'est le decoupage des maquettes de reference : une page longue s'ordonne
/// par alternance de fonds, pas par lignes de separation. Une bande porte
/// une idee ; deux idees dans une bande, et l'alternance ne dit plus rien.
///
/// La bande sombre inverse ses textes elle-meme — laisser chaque enfant
/// decider de sa couleur finit toujours par produire du gris sur marine.
class Band extends StatelessWidget {
  const Band({
    super.key,
    this.tone = BandTone.plain,
    this.title,
    this.accented,
    this.trailingLabel,
    this.onTrailing,
    required this.children,
  });

  final BandTone tone;

  /// Le titre de la bande. [accented] en porte le mot colore.
  final String? title;
  final String? accented;

  final String? trailingLabel;
  final VoidCallback? onTrailing;

  final List<Widget> children;

  bool get _sombre => tone == BandTone.dark;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    /*
     * --- Ce qui a change avec la charte EduQuali -------------------------
     *
     * `soft` tirait sur `bandSoft`, un bleu tres pale. La charte n'a pas de
     * couleur de bande : elle a `papier`, le fond des ecrans, et `feuille`,
     * la surface des cartes posees dessus. L'ecart entre les deux — 1,08:1 —
     * est exactement ce qu'il faut pour decouper une page longue sans tracer
     * une seule ligne de separation.
     *
     * `violette-pale` n'etait pas le bon choix : elle a un role, « fond de ce
     * qui est choisi ou en attente », et une bande de section n'est ni l'un
     * ni l'autre. Elle s'y serait lue comme un bloc selectionne.
     */
    color: switch (tone) {
      BandTone.plain => AppColors.feuille,
      BandTone.soft => AppColors.papier,
      BandTone.dark => AppColors.marqueEncre,
    },
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.xl,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              Expanded(
                child: accented == null
                    ? Text(
                        title!,
                        style: TextStyle(
                          fontFamily: AppTheme.headingFont,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: _sombre ? Colors.white : AppColors.textPrimary,
                        ),
                      )
                    : TwoToneTitle(
                        before: title!,
                        accented: accented!,
                        size: 24,
                        onDark: _sombre,
                      ),
              ),
              if (trailingLabel != null && onTrailing != null)
                TextButton(
                  onPressed: onTrailing,
                  style: TextButton.styleFrom(
                    // Sur une bande sombre, la violette du theme Tableau :
                    // c'est la meme couleur de marque, eclaircie pour tenir
                    // sur du marine. Le surligneur y etait employe comme
                    // couleur de texte, ce que la charte interdit.
                    foregroundColor: _sombre
                        ? AppColors.tableauViolette
                        : AppColors.violette,
                  ),
                  child: Text(trailingLabel!),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        ...children,
      ],
    ),
  );
}

/// Un champ avec son unite posee a droite, dans le champ.
///
/// Le procede des maquettes de reference : le montant et sa devise, la note
/// et son bareme, l'heure et son fuseau. L'unite dans une etiquette au-dessus
/// se perd des qu'on regarde le chiffre ; collee a lui, elle se lit avec.
class UnitField extends StatelessWidget {
  const UnitField({
    super.key,
    required this.unit,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.onChanged,
  });

  /// « GNF », « ans », « /mois ». Deux ou trois caracteres, pas une phrase.
  final String unit;

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      suffixIcon: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              unit,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    ),
  );
}

/// Ce que quelqu'un dit du produit, avec son nom.
///
/// Une seule par page, et elle nomme la personne. Un temoignage anonyme
/// n'est pas une preuve : c'est une phrase que n'importe qui a pu ecrire.
/// Sans temoignage reel, ce composant ne s'affiche pas — on ne le remplit
/// pas d'un exemple.
class TestimonialCard extends StatelessWidget {
  const TestimonialCard({
    super.key,
    required this.quote,
    required this.name,
    this.role,
    this.photoPath,
  });

  final String quote;
  final String name;
  final String? role;
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final mots = name.trim().split(RegExp(r'\s+'));
    return KitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote, size: 30, color: AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            quote,
            style: const TextStyle(
              fontSize: 17,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              ProfileAvatar(
                firstName: mots.isEmpty ? '' : mots.first,
                lastName: mots.length > 1 ? mots.last : '',
                photoPath: photoPath,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (role != null)
                      Text(
                        role!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Une rangée de cartes qui défile, sous un titre de section.
///
/// Pour ce qu'on parcourt du regard sans chercher : cinq professeurs mis en
/// avant, cinq écoles. Au-delà de cinq, personne ne fait défiler jusqu'au
/// bout — une liste verticale sert mieux.
///
/// Les cartes ont toutes la même largeur, et la suivante dépasse du bord :
/// c'est ce dépassement qui dit qu'il y en a d'autres. Une rangée qui finit
/// pile au bord de l'écran passe pour une rangée complète.
class KitCarousel extends StatelessWidget {
  const KitCarousel({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    required this.children,
    this.height = 150,
    this.itemWidth = 230,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Widget> children;
  final double height;
  final double itemWidth;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: KitSectionTitle(
            title: title,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, i) =>
                SizedBox(width: itemWidth, child: children[i]),
          ),
        ),
      ],
    );
  }
}

/// La carte d'un professeur dans un carrousel.
class TeacherMiniCard extends StatelessWidget {
  const TeacherMiniCard({
    super.key,
    required this.name,
    required this.subtitle,
    this.city,
    this.photoPath,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final String? city;
  final String? photoPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mots = name.trim().split(RegExp(r'\s+'));
    return KitCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(
            firstName: mots.isEmpty ? '' : mots.first,
            lastName: mots.length > 1 ? mots.last : '',
            photoPath: photoPath,
            size: 44,
          ),
          const Spacer(),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            subtitle.isEmpty ? 'Matières non déclarées' : subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (city != null) ...[
            const SizedBox(height: AppSpacing.xs),
            MetaText(city!, icon: Icons.place_outlined),
          ],
        ],
      ),
    );
  }
}
