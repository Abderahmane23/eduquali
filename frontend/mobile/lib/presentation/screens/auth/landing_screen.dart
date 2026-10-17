import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/common.dart';
import '../../widgets/interactions.dart';
import '../../widgets/kit.dart';

/// Le premier écran : on cherche d'abord, on ouvre un compte ensuite.
///
/// Avant, la première chose demandée était un numéro de téléphone. Une
/// personne qui ne connaît pas encore l'application n'a aucune raison de le
/// donner — elle vient voir s'il existe un professeur de maths près de chez
/// elle, et c'est cette réponse-là qui vaut la peine d'un compte.
///
/// La recherche et les résultats sont donc publics. Ce qui demande un compte
/// est ce qui engage quelqu'un d'autre : contacter un professeur, réserver
/// une séance. Les coordonnées restent masquées jusque-là, comme partout
/// ailleurs dans l'application.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final _query = TextEditingController();

  /// 0 = cours a domicile, 1 = embauche.
  ///
  /// Les deux cherchent des professeurs, mais pas pour la meme chose : une
  /// famille cherche quelqu'un qui se deplace le soir, une ecole cherche
  /// quelqu'un a recruter. Melanger les deux listes donnait des resultats
  /// que ni l'un ni l'autre ne pouvait utiliser.
  int _mode = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search([String? preset]) {
    final q = (preset ?? _query.text).trim();
    context.push(Routes.discoverFor(q, home: _mode == 0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.heroStart,
      body: Container(
        // Un aplat, pas un degrade : la charte n en laisse aucun, et la
        // violette de la marque se suffit.
        decoration: const BoxDecoration(color: AppColors.marqueViolette),
        child: SafeArea(
          // La page occupe tout l'écran d'un seul bleu. Le bandeau gris du
          // bas coupait la page en deux à une hauteur qui ne correspondait à
          // rien, et laissait un vide sous la carte sur un grand téléphone.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              // Centré tant que le contenu tient, défilant dès que le
              // clavier s'ouvre. Une colonne simplement centrée serait
              // tronquée en haut et en bas quand le clavier monte.
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const AppLogo.wordmarkLight(width: 120),
                            const Spacer(),
                            // Une seule porte en haut, et c'est celle du
                            // professeur : la page entière parle à qui
                            // cherche un professeur, donc celui qui *est*
                            // professeur doit pouvoir sortir de ce discours
                            // tout de suite.
                            //
                            // Elle mène à la connexion, pas à l'inscription :
                            // un professeur qui appuie ici a presque toujours
                            // déjà un compte, et celui qui n'en a pas trouve
                            // « Créer un compte » sur l'écran d'arrivée.
                            _HeaderButton(
                              label: 'Espace professeur',
                              onTap: () => context.push(Routes.login),
                            ),
                          ],
                        ),

                        // Le titre et la boîte d'action au centre de ce qui
                        // reste : c'est la seule chose à faire ici.
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Gap(AppSpacing.xl),
                              // Le titre s'arrête sur « pour » : la phrase se
                              // termine dans la boîte juste en dessous, où
                              // l'on choisit entre « Cours à domicile » et
                              // « Embauche ». Le premier geste devient la
                              // fin de la phrase.
                              const TwoToneTitle(
                                before: 'Trouvez le ',
                                accented: 'professeur',
                                after: '\nqu’il vous faut pour',
                                size: 27,
                              ),
                              const Gap(AppSpacing.xl),
                              _ActionBox(
                                query: _query,
                                mode: _mode,
                                onMode: (i) => setState(() => _mode = i),
                                onSearch: _search,
                              ),
                            ],
                          ),
                        ),

                        // Les deux portes du compte, en bas, décollées du
                        // bord : sur le bleu elles se lisent comme des
                        // boutons, pas comme du texte posé sur le fond.
                        const Gap(AppSpacing.xl),
                        Row(
                          children: [
                            Expanded(
                              child: _AccountButton(
                                label: 'Connexion',
                                filled: true,
                                onTap: () => context.push(Routes.login),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _AccountButton(
                                label: 'Inscription',
                                filled: false,
                                onTap: () => context.push(Routes.signup),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La boîte de première action : ce qu'on peut faire sans compte.
class _ActionBox extends StatelessWidget {
  const _ActionBox({
    required this.query,
    required this.mode,
    required this.onMode,
    required this.onSearch,
  });

  final TextEditingController query;
  final int mode;
  final ValueChanged<int> onMode;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => KitCard(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedToggle(
          labels: const ['Cours à domicile', 'Embauche'],
          selected: mode,
          onSelected: onMode,
        ),
        const Gap(AppSpacing.lg),
        const FieldLabel('Quelle matière cherchez-vous ?'),
        TextField(
          controller: query,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSearch(),
          decoration: const InputDecoration(
            hintText: 'Maths, physique, anglais…',
            prefixIcon: Icon(Icons.search, size: 22),
          ),
        ),
        const Gap(AppSpacing.lg),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: onSearch,
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('CHERCHER'),
                SizedBox(width: AppSpacing.sm),
                Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Connexion et Inscription, posées sur le bleu.
///
/// Le plein est blanc, le contour est blanc : sur ce bleu, les deux passent
/// 8:1. Un bouton teinté dans le bleu de la page se serait lu comme un
/// élément de décor, et personne n'aurait su qu'il se touche.
class _AccountButton extends StatelessWidget {
  const _AccountButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    haptic: true,
    borderRadius: BorderRadius.circular(AppRadius.pill),
    child: Container(
      height: AppSpacing.touchTarget + 4,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white, width: filled ? 0 : 1.6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: filled ? AppColors.primary : Colors.white,
        ),
      ),
    ),
  );
}

/// Un bouton plein dans l'en-tete, sur le degrade.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.label, required this.onTap});

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
        color: AppColors.onHeroSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.onHeroBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );
}
