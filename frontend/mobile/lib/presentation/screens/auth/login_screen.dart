import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_enums.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/common.dart';
import '../../widgets/interactions.dart';
import '../../widgets/marque.dart';

/// Connexion, d'après les maquettes du 23/09.
///
/// Le haut porte la marque sur le dégradé ; la feuille blanche, remontée
/// par-dessus, porte le formulaire. Cette découpe dit où l'on est avant de
/// demander quoi que ce soit — c'est le seul écran atteint sans être déjà
/// passé par l'application.
///
/// Le mot de passe reste facultatif : les comptes ouverts par l'inscription
/// n'en ont pas — ils s'ouvrent par code. Laisser le champ vide envoie donc
/// un code, et le dire ici évite de faire deviner.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = ref.read(authRepositoryProvider);

      // Sans mot de passe, on entre par le numéro seul : c'est le seul
      // moyen dont disposent les comptes créés par l'inscription, qui n'en
      // ont jamais reçu. Le code de confirmation a été retiré le 25/09 — il
      // affichait le chiffre à recopier, donc il ne vérifiait rien.
      // Un champ vide n'ouvre plus rien. Jusqu'au 02/10, la connexion sur le
      // numero seul ouvrait la session : connaitre un numero suffisait pour
      // entrer dans le compte qui le porte. Le parcours demande desormais un
      // mot de passe a l'inscription, et les comptes anterieurs passent par
      // « Mot de passe oublie » pour en poser un.
      if (_password.text.isEmpty) {
        setState(() => _error = 'Entrez votre mot de passe.');
        return;
      }
      final session = await auth.login(_phone.text, _password.text);
      await ref.read(sessionProvider.notifier).setSession(session);
      if (!mounted) return;
      context.go(Routes.homeFor(session.role));
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ouvre un espace de démonstration déjà alimenté.
  Future<void> _demo(UserRole role) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      final session = switch (role) {
        UserRole.institution => await auth.loginAsDemoInstitution(),
        UserRole.parent => await auth.loginAsDemoParent(),
        _ => await auth.loginAsDemoTeacher(),
      };
      await ref.read(sessionProvider.notifier).setSession(session);
      if (!mounted) return;
      context.go(Routes.homeFor(role));
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.heroStart,
      body: Column(
        children: [
          const _Brand(),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Bienvenue',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Connectez-vous pour continuer',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Gap(AppSpacing.xl),

                      const _Label('Numéro de téléphone'),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: '620 00 00 00',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          prefixText: '${AppConstants.phonePrefix} ',
                        ),
                      ),
                      const Gap(AppSpacing.lg),

                      // Plus « facultatif » depuis le 02/10 : le parcours
                      // demande desormais un mot de passe, et laisser ce champ
                      // vide n'ouvre plus rien. Un compte cree avant cette
                      // date n'en a aucun — « Mot de passe oublie », juste en
                      // dessous, est le chemin pour en poser un.
                      const _Label('Mot de passe'),
                      TextField(
                        controller: _password,
                        obscureText: _hidden,
                        onSubmitted: (_) => _start(),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _hidden = !_hidden),
                            // Le nom suit l'action a venir, pas l'etat
                            // courant : « Afficher » quand c'est masque.
                            tooltip: _hidden
                                ? 'Afficher le mot de passe'
                                : 'Masquer le mot de passe',
                            icon: Icon(
                              _hidden
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                      if (_error != null) ...[
                        const Gap(AppSpacing.lg),
                        InfoBanner(
                          message: _error!,
                          tone: StatusTone.danger,
                          icon: Icons.error_outline,
                        ),
                      ],

                      const Gap(AppSpacing.xl),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: _busy ? null : _start,
                          style: FilledButton.styleFrom(
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // « Un bouton dit ce qui va se passer »,
                              // surtout quand il engage. « Commencer » ne dit
                              // rien ; ici il part un SMS, et l'on attend un
                              // code — autant l'annoncer.
                              Text(
                                _busy
                                    ? 'Un instant…'
                                    : 'Recevoir mon code par SMS',
                              ),
                              if (!_busy) ...[
                                const SizedBox(width: AppSpacing.sm),
                                const Icon(Icons.arrow_forward, size: 20),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const Gap(AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => context.push(Routes.signup),
                            child: const Text('Créer un compte'),
                          ),
                          Container(
                            width: 1,
                            height: 18,
                            color: AppColors.border,
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => context.push(Routes.passwordReset),
                            child: const Text('Mot de passe oublié'),
                          ),
                        ],
                      ),

                      // Accès de démonstration : un testeur ne peut pas
                      // ouvrir trois comptes pour voir trois espaces.
                      const Gap(AppSpacing.lg),
                      const Text(
                        'ACCÈS DÉMO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const Gap(AppSpacing.md),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final (role, label, icon) in [
                            (
                              UserRole.teacher,
                              'Professeur',
                              Icons.person_outline,
                            ),
                            (
                              UserRole.institution,
                              'École',
                              Icons.apartment_outlined,
                            ),
                            (UserRole.parent, 'Parent', Icons.people_outline),
                          ])
                            _DemoChip(
                              label: label,
                              icon: icon,
                              onTap: _busy ? null : () => _demo(role),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le haut de l'écran : la marque sur le dégradé.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    // Un aplat, pas un degrade : la charte n en laisse aucun, et la
        // violette de la marque se suffit.
        decoration: const BoxDecoration(color: AppColors.marqueViolette),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.espace4,
          AppSpacing.espace5,
          AppSpacing.espace4,
          AppSpacing.espace5,
        ),
        child: Column(
          children: [
            /*
             * Le nom, et rien d'autre.
             *
             * Une tuile blanche de 84 px portait le symbole juste au-dessus :
             * le Q etait donc dessine deux fois, une fois seul et une fois
             * dans le logotype. La charte tranche — « utiliser le symbole
             * seul sous 18 px de haut, ou quand le nom est deja present ».
             * Il l'est, une ligne plus bas.
             *
             * Cent pixels gagnes, et le premier champ passe au-dessus de la
             * ligne de flottaison sur un telephone de 640.
             */
            const AppLogo.wordmarkLight(width: 190),
            const Gap(AppSpacing.espace3),
            /*
             * La signature de la marque.
             *
             * Elle remplace « La plateforme educative de confiance », et la
             * charte dit pourquoi en une ligne : « la confiance ne s'annonce
             * pas, elle se prouve, et la preuve de presence s'en charge ».
             * Une phrase qui se reclame de la confiance en demande ; celle-ci
             * dit ce qui distingue le produit — un professeur en direct, a
             * heure fixe, et non une bibliotheque de videos.
             *
             * Le mot surligne est « est la » : c'est la difference.
             */
            const Affiche(
              avant: 'Le professeur ',
              surligne: 'est là.',
              // 19 px : la signature tient alors sur une seule ligne dans les
              // 320 px utiles d'un telephone de 360. A 22, elle passait a la
              // ligne et coutait une hauteur de texte entiere.
              style: TextStyle(
                fontFamily: AppTheme.fontTitre,
                fontSize: 19,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
              couleur: AppColors.marquePapier,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Le nom d'un champ, posé au-dessus de lui.
///
/// Au-dessus et non dedans : un libellé flottant disparaît dès qu'on tape,
/// et il faut alors se rappeler ce qu'on était en train de remplir.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
  );
}

/// Une pastille d'accès de démonstration.
class _DemoChip extends StatelessWidget {
  const _DemoChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap ?? () {},
    haptic: true,
    borderRadius: BorderRadius.circular(AppRadius.pill),
    child: Container(
      height: AppSpacing.touchTarget,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    ),
  );
}
