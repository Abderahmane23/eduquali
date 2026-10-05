import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/session_providers.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Mot de passe oublié : récupération par numéro **ou** par courriel.
///
/// Les deux, et pas seulement le numéro : une carte SIM se perd, se vole, se
/// change. Quelqu'un qui n'a plus son numéro n'aurait alors plus aucun moyen
/// de revenir sur son propre compte.
///
/// Dans les deux cas le chemin est le même — un code à usage unique, puis un
/// nouveau mot de passe. C'est déjà la mécanique de l'inscription : en
/// inventer une seconde multiplierait les portes d'entrée d'un compte.
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() => _ResetState();
}

/// Par quoi l'utilisateur se fait reconnaître.
enum ResetChannel {
  phone('Par numéro'),
  email('Par courriel');

  const ResetChannel(this.label);
  final String label;
}

class _ResetState extends ConsumerState<PasswordResetScreen> {
  final _value = TextEditingController();
  ResetChannel _channel = ResetChannel.phone;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      final userId = await auth.requestPasswordReset(
        phone: _channel == ResetChannel.phone ? _value.text : null,
        email: _channel == ResetChannel.email ? _value.text : null,
      );
      // Plus de code a saisir : il affichait le chiffre a recopier, donc il
      // ne verifiait personne. La session s'ouvre directement, exactement
      // comme le faisait l'ecran du code une fois le chiffre recopie.
      final session = await auth.openSessionFor(userId);
      await ref.read(sessionProvider.notifier).setSession(session);
      if (!mounted) return;
      context.go(Routes.homeFor(session.role));
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final byPhone = _channel == ResetChannel.phone;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Mot de passe oublié'),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            Text(
              'On vous envoie un code, puis vous choisissez un nouveau mot '
              'de passe.',
              style: text.bodyMedium,
            ),
            const Gap(AppSpacing.xl),

            SegmentedButton<ResetChannel>(
              segments: [
                for (final channel in ResetChannel.values)
                  ButtonSegment(value: channel, label: Text(channel.label)),
              ],
              selected: {_channel},
              onSelectionChanged: (s) => setState(() {
                _channel = s.first;
                _value.clear();
                _error = null;
              }),
            ),
            const Gap(AppSpacing.lg),

            TextField(
              controller: _value,
              // La clé change avec le canal, sinon le clavier resterait
              // numérique après être passé au courriel.
              key: ValueKey(_channel),
              keyboardType: byPhone
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: byPhone ? 'Numéro de téléphone' : 'Adresse e-mail',
                prefixText: byPhone ? '${AppConstants.phonePrefix} ' : null,
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
            FilledButton(
              onPressed: _busy || _value.text.trim().isEmpty ? null : _send,
              child: Text(_busy ? 'Envoi…' : 'Recevoir mon code'),
            ),
          ],
        ),
      ),
    );
  }
}
