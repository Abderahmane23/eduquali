import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Le système demande-t-il moins de mouvement ?
///
/// Android expose ce réglage (Accessibilité → Supprimer les animations).
/// Les vertiges d'origine vestibulaire ne sont pas une préférence
/// esthétique : une mise à l'échelle qui bouge sous le doigt peut
/// réellement rendre quelqu'un malade.
///
/// On n'éteint pas tout pour autant. Le retour reste nécessaire — il passe
/// par l'opacité et l'haptique, que la WCAG ne compte pas comme du
/// mouvement.
bool prefersLessMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Un élément qui s'enfonce sous le doigt.
///
/// L'effet est court et faible — 3 % sur 90 ms. Sur un téléphone d'entrée de
/// gamme, une animation plus longue se voit saccader, et le retour tactile
/// devient le contraire de ce qu'il promet.
///
/// Le retour haptique accompagne la **sélection**, pas la navigation : faire
/// vibrer le téléphone à chaque ouverture d'écran fatigue au bout de dix
/// minutes, et nombre d'utilisateurs coupent alors le vibreur — perdant du
/// même coup les vibrations utiles.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.haptic = false,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Vrai quand le geste choisit quelque chose : une option, un jour, une
  /// ligne de liste.
  final bool haptic;

  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (widget.onTap == null || _down == value) return;
    setState(() => _down = value);
  }

  /// L'enfoncement, ou son remplacant quand le mouvement est ecarte.
  ///
  /// L'opacite n'est pas du mouvement au sens de la WCAG : elle reste donc
  /// disponible pour dire « c'est bien touche » a quelqu'un qui a coupe les
  /// animations.
  Widget _feedback(Widget child) {
    if (prefersLessMotion(context)) {
      return AnimatedOpacity(
        opacity: _down ? 0.65 : 1,
        duration: const Duration(milliseconds: 90),
        child: child,
      );
    }
    return AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!.call();
            },
      // `borderRadius` sert l'effet d'encre des appelants qui en posent
      // un ; la mise a l'echelle, elle, n'en a pas besoin.
      child: _feedback(
        widget.borderRadius == null
            ? widget.child
            : ClipRRect(
                borderRadius: widget.borderRadius!,
                child: widget.child,
              ),
      ),
    );
  }
}

/// Un rectangle gris qui respire, à la place d'un tourniquet.
///
/// Le tourniquet dit « ça charge » ; le squelette dit « ça charge, et voilà
/// à quoi ça ressemblera ». L'écran ne saute plus au moment où les données
/// arrivent, parce que la place était déjà prise.
///
/// Une pulsation plutôt qu'un balayage : le balayage repeint toute la
/// surface à chaque image, ce qui se paie cher sur les téléphones que vise
/// l'application.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Une pulsation sans fin est exactement la « decoration en boucle »
    // qu'on deconseille : coupee des que le systeme demande moins de
    // mouvement, elle laisse un rectangle fixe, qui dit la meme chose.
    if (prefersLessMotion(context)) {
      if (_pulse.isAnimating) _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.neutralSurface,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );

    if (prefersLessMotion(context)) {
      return Opacity(opacity: 0.8, child: box);
    }
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      child: box,
    );
  }
}

/// La coquille d'une carte, sans son contenu.
class _SkeletonShell extends StatelessWidget {
  const _SkeletonShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.zero,
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.border),
      boxShadow: AppShadows.card,
    ),
    child: child,
  );
}

/// L'attente d'un tableau de bord : un titre, puis des lignes.
///
/// Elle épouse la forme de `DashboardCard` — c'est la condition pour qu'un
/// squelette serve à quelque chose. Un modèle générique annonce une forme
/// qui n'arrivera pas, et l'écran saute au moment des données : autant
/// n'avoir rien montré.
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key, this.cards = const [3]});

  /// Le nombre de lignes de chaque carte, dans l'ordre de l'écran.
  final List<int> cards;

  @override
  Widget build(BuildContext context) => ListView(
    padding: AppSpacing.page,
    children: [
      for (final rows in cards) ...[
        const SkeletonBox(width: 140, height: 17),
        const SizedBox(height: AppSpacing.sm),
        _SkeletonShell(
          child: Column(
            children: [
              for (var i = 0; i < rows; i++) ...[
                if (i > 0) const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      SkeletonBox(width: 130),
                      Spacer(),
                      SkeletonBox(width: 60),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    ],
  );
}

/// L'attente du calendrier : les jours, la séance mise en avant, la suite.
class SkeletonCalendar extends StatelessWidget {
  const SkeletonCalendar({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: AppSpacing.page,
    children: [
      Row(
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: SkeletonBox(
                width: 66,
                height: AppSpacing.xxl,
                radius: AppRadius.lg,
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),
      const SkeletonBox(width: 150, height: 17),
      const SizedBox(height: AppSpacing.sm),
      const _SkeletonShell(
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 200, height: 16),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 240),
              SizedBox(height: AppSpacing.lg),
              Divider(height: 1),
              SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  SkeletonBox(width: 60),
                  Spacer(),
                  SkeletonBox(width: 60),
                  Spacer(),
                  SkeletonBox(width: 60),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Le champ dit lui-même qu'il est bon.
///
/// Une coche dans le champ au moment où la saisie devient valable évite
/// d'aller chercher le bouton pour découvrir qu'il est encore gris.
class ValidatedSuffix extends StatelessWidget {
  const ValidatedSuffix({super.key, required this.valid, this.visible = true});

  final bool valid;

  /// Faux tant que l'utilisateur n'a rien tapé : une croix rouge en face
  /// d'un champ vide accuse avant même qu'on ait commencé.
  final bool visible;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 160),
    child: !visible || !valid
        ? const SizedBox(width: 1, height: 1)
        : const Icon(
            Icons.check_circle,
            key: ValueKey('valide'),
            size: 20,
            color: AppColors.success,
          ),
  );
}

/// Ne montre le chargement que s'il dure, et assez longtemps pour se lire.
///
/// Sans cette garde, un écran qui lit la base locale — donc la plupart des
/// écrans — affiche son squelette et le retire dans le même souffle. Un
/// clignotement est pire qu'aucun indicateur : il donne l'impression que
/// quelque chose a raté.
///
/// Deux seuils :
/// * rien pendant les 300 premières millisecondes, parce qu'en dessous
///   l'utilisateur n'a pas eu le temps de se demander si ça marche ;
/// * une fois affiché, 400 ms au minimum, pour qu'il ne disparaisse pas
///   avant d'avoir été vu.
class LoadingGate extends StatefulWidget {
  const LoadingGate({
    super.key,
    required this.loading,
    required this.placeholder,
    required this.child,
    this.delay = const Duration(milliseconds: 300),
    this.minimum = const Duration(milliseconds: 400),
  });

  final bool loading;

  /// Ce qu'on montre pendant l'attente : un squelette à la forme de ce qui
  /// va venir.
  final Widget placeholder;

  /// Le contenu, une fois prêt.
  final Widget child;

  final Duration delay;
  final Duration minimum;

  @override
  State<LoadingGate> createState() => _LoadingGateState();
}

class _LoadingGateState extends State<LoadingGate> {
  bool _visible = false;
  DateTime? _shownAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.loading) _armDelay();
  }

  @override
  void didUpdateWidget(LoadingGate old) {
    super.didUpdateWidget(old);
    if (widget.loading == old.loading) return;
    widget.loading ? _armDelay() : _armRelease();
  }

  /// Le chargement commence : on attend avant de l'annoncer.
  void _armDelay() {
    _timer?.cancel();
    _timer = Timer(widget.delay, () {
      if (!mounted || !widget.loading) return;
      setState(() {
        _visible = true;
        _shownAt = DateTime.now();
      });
    });
  }

  /// Le contenu est prêt : on ne retire le squelette qu'une fois son temps
  /// de lecture écoulé.
  void _armRelease() {
    _timer?.cancel();
    if (!_visible) return;

    final shown = DateTime.now().difference(_shownAt ?? DateTime.now());
    final left = widget.minimum - shown;
    if (left <= Duration.zero) {
      setState(() => _visible = false);
      return;
    }
    _timer = Timer(left, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _visible ? widget.placeholder : widget.child;
}

/// Une valeur asynchrone, affichée sans clignoter.
///
/// Réunit `AsyncValue` et [LoadingGate] : c'est le motif qu'on répéterait
/// sinon sur chaque écran, avec le risque de l'écrire de travers une fois
/// sur cinq.
///
/// Pendant les 300 premières millisecondes, l'écran reste vide plutôt que de
/// montrer un squelette qui disparaîtra aussitôt — une lecture de la base
/// locale prend souvent moins que ça.
class AsyncGate<T> extends StatelessWidget {
  const AsyncGate({
    super.key,
    required this.value,
    required this.placeholder,
    required this.data,
    this.error,
  });

  final AsyncValue<T> value;

  /// Le squelette, à la forme de ce qui va arriver.
  final Widget placeholder;

  final Widget Function(T value) data;
  final Widget Function(Object error)? error;

  @override
  Widget build(BuildContext context) => LoadingGate(
    loading: value.isLoading,
    placeholder: placeholder,
    child: switch (value) {
      AsyncValue(hasError: true, :final error?) when this.error != null =>
        this.error!(error),
      AsyncValue(hasValue: true) => data(value.requireValue),
      // Les 300 premières millisecondes, et elles seules.
      _ => const SizedBox.shrink(),
    },
  );
}

/// Une action faite, et cinq secondes pour la défaire.
///
/// Elle remplace la boîte « Êtes-vous sûr ? » partout où le geste se rattrape.
/// La question arrive avant que la personne sache ce qu'elle perd, et elle la
/// pose à chaque fois, y compris les quatre-vingt-dix-neuf fois où la réponse
/// est oui ; l'annulation, elle, n'apparaît qu'après, une fois le résultat
/// sous les yeux, et ne coûte rien tant qu'on ne s'en sert pas.
///
/// Ce qui ne se rattrape pas garde sa confirmation : un contrat résilié
/// prévient l'autre partie, un cours retiré de la vente disparaît de tous les
/// catalogues. Cinq secondes ne rappellent pas un message parti.
void showUndo(
  BuildContext context, {
  required String message,
  required Future<void> Function() onUndo,
  String label = 'Annuler',
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: label, onPressed: () => onUndo()),
      ),
    );
}
