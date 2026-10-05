import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../onboarding/presentation_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Écran 5 — Validation par OTP (§5.1).
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  Timer? _timer;
  int _secondsLeft = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = AppConstants.otpResendDelay.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (_controller.text.length != AppConstants.otpLength) {
      setState(
        () => _error = 'Saisissez les ${AppConstants.otpLength} chiffres.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .verifyOtp(widget.userId, _controller.text);
      await ref.read(sessionProvider.notifier).setSession(session);
      // Un compte tout neuf voit d'abord la présentation ; un retour après
      // déconnexion va droit à son espace.
      final seen = await PresentationScreen.alreadySeen(ref, session.userId);
      if (!mounted) return;
      context.go(seen ? Routes.homeFor(session.role) : Routes.presentation);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    await ref.read(authRepositoryProvider).resendOtp(widget.userId);
    if (!mounted) return;
    setState(() => _error = null);
    _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vérification\ndu numéro', style: text.headlineMedium),
              const Gap(AppSpacing.sm),
              Text(
                'Un code a ${AppConstants.otpLength} chiffres vous a ete envoyé '
                'par SMS. Il est valable ${AppConstants.otpValidity.inMinutes} minutes.',
                style: text.bodyMedium,
              ),
              const Gap(AppSpacing.section),

              _OtpField(
                controller: _controller,
                focusNode: _focus,
                length: AppConstants.otpLength,
                hasError: _error != null,
                onCompleted: (_) => _verify(),
              ),

              // Hors ligne, aucun SMS ne peut partir : on donne le code
              // unique plutôt que de laisser attendre un message qui
              // n'arrivera pas (§42 — mode dégradé).
              if (ref.read(authRepositoryProvider).offlineOtpApplies) ...[
                const Gap(AppSpacing.xl),
                const InfoBanner(
                  title: 'Pas de réseau, pas de SMS',
                  message:
                      'Saisissez le code ${AppConstants.offlineOtpCode} '
                      'pour continuer.',
                  tone: StatusTone.info,
                  icon: Icons.sms_outlined,
                ),
              ],

              if (_error != null) ...[
                const Gap(AppSpacing.lg),
                InfoBanner(
                  message: _error!,
                  tone: StatusTone.danger,
                  icon: Icons.error_outline,
                ),
              ],

              const Gap(AppSpacing.xl),
              FilledButton(
                onPressed: _busy ? null : _verify,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Vérifier'),
              ),
              const Gap(AppSpacing.lg),

              Center(
                child: _secondsLeft > 0
                    ? Text(
                        'Renvoyer le code dans $_secondsLeft s',
                        style: text.bodySmall,
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text('Renvoyer le code'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Champ de saisie du code, decoupe en cases.
class _OtpField extends StatelessWidget {
  const _OtpField({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.onCompleted,
    this.hasError = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final ValueChanged<String> onCompleted;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Le champ reel est invisible : les cases ci-dessous le refletent.
        Opacity(
          opacity: 0,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            maxLength: length,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              if (value.length == length) onCompleted(value);
            },
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            onTap: focusNode.requestFocus,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => Row(
                children: [
                  for (var i = 0; i < length; i++) ...[
                    Expanded(
                      child: _OtpBox(
                        char: i < value.text.length ? value.text[i] : '',
                        active: i == value.text.length && focusNode.hasFocus,
                        hasError: hasError,
                      ),
                    ),
                    if (i < length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.char,
    required this.active,
    required this.hasError,
  });

  final String char;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final border = hasError
        ? AppColors.danger
        : active
        ? AppColors.primary
        : AppColors.border;

    return Container(
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border, width: active ? 1.6 : 1),
      ),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
