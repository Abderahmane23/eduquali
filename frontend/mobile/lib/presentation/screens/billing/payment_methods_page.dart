import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:veriprof/core/constants/app_enums.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../data/billing/invoice_pdf.dart';
import '../../../data/repositories/payment_methods_repository.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dashboard.dart';
import '../../widgets/interactions.dart';

/// Moyens de paiement et factures (note du 21/09).
///
/// Le même écran pour les quatre profils : tout le monde paie ou encaisse, et
/// quatre écrans auraient fini par ne plus proposer les mêmes moyens.
class PaymentMethodsPage extends ConsumerWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Paiement'),
      ),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          DashboardCard(
            title: 'Mes moyens de paiement',
            emptyMessage:
                'Aucun moyen enregistré. Ajoutez-en un pour régler sans '
                'ressaisir votre numéro à chaque fois.',
            addLabel: 'ajouter un moyen de paiement',
            onAdd: () => _add(context, ref),
            rows: [
              for (final method in methods)
                DashboardRow(
                  label: method.display,
                  columns: [method.isDefault ? 'Par défaut' : ''],
                  onTap: () => _manage(context, ref, method),
                ),
            ],
          ),

          const Gap(AppSpacing.sm),
          DashboardActions(
            title: 'Factures',
            items: [
              (
                label: 'Télécharger mes factures en PDF',
                onTap: () => _download(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentSessionProvider)?.userId;
    if (userId == null) return;

    final result = await showModalBottomSheet<_NewMethod>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddSheet(),
    );
    if (result == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(paymentMethodsRepositoryProvider)
          .add(
            userId: userId,
            kind: result.kind,
            holder: result.holder,
            reference: result.reference,
          );
      ref.invalidate(paymentMethodsProvider);
    } on PaymentMethodException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _manage(
    BuildContext context,
    WidgetRef ref,
    PaymentMethodItem method,
  ) async {
    final userId = ref.read(currentSessionProvider)?.userId;
    if (userId == null) return;

    final action = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(method.display),
        content: Text(
          method.isDefault
              ? 'C’est le moyen proposé au moment de payer.'
              : 'Voulez-vous en faire votre moyen par défaut ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, 'remove'),
            child: const Text('Retirer'),
          ),
          if (!method.isDefault)
            FilledButton(
              onPressed: () => Navigator.pop(dialog, 'default'),
              child: const Text('Par défaut'),
            ),
        ],
      ),
    );
    if (action == null) return;

    final repo = ref.read(paymentMethodsRepositoryProvider);
    if (action == 'remove') {
      await repo.remove(userId: userId, methodId: method.id);
    } else {
      await repo.makeDefault(userId: userId, methodId: method.id);
    }
    ref.invalidate(paymentMethodsProvider);
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    final messenger = ScaffoldMessenger.of(context);
    // Le professeur encaisse, la famille règle : la même liasse, vue de
    // chaque côté.
    final payments = session.role == UserRole.teacher
        ? await ref.read(teacherPaymentsProvider.future)
        : await ref.read(parentPaymentsProvider.future);

    final bytes = await InvoicePdf.build(
      accountName: session.displayName,
      subtitle: session.role.label,
      lines: [for (final p in payments) InvoiceLine.fromPayment(p)],
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      '${InvoicePdf.fileName(DateTime.now())}',
    );
    await file.writeAsBytes(bytes);

    final opened = await OpenFilex.open(file.path);
    if (opened.type == ResultType.done) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Facture enregistrée : ${file.path}')),
    );
  }
}

/// Ce que la feuille d'ajout rend.
class _NewMethod {
  const _NewMethod({required this.kind, required this.reference, this.holder});

  final PaymentKind kind;
  final String reference;
  final String? holder;
}

class _AddSheet extends StatefulWidget {
  const _AddSheet();

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  /// Un seul moyen proposé, et il ne se choisit donc pas.
  ///
  /// Voir [PaymentKind.offered] : l'inscription ne demande qu'un numéro Orange
  /// Money, et cet écran doit dire la même chose. Un sélecteur à une seule
  /// entrée se lit comme un bug, pas comme une décision — d'où la phrase qui
  /// l'explique plutôt qu'une liste à un élément.
  static const _kind = PaymentKind.orangeMoney;

  final _reference = TextEditingController();
  final _holder = TextEditingController();

  @override
  void dispose() {
    _reference.dispose();
    _holder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final numero = _reference.text.trim();
    final valide = Validators.phone(numero) == null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_kind.label, style: text.titleLarge),
              const Gap(AppSpacing.xs),
              Text(
                'C’est le seul moyen de paiement accepté pour le moment. Rien '
                'n’est débité maintenant : vous confirmerez sur votre téléphone '
                'au moment de l’achat.',
                style: text.bodyMedium,
              ),
              const Gap(AppSpacing.lg),

              TextField(
                controller: _reference,
                autofocus: true,
                keyboardType: TextInputType.phone,
                maxLength: 9,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Numéro Orange Money',
                  // Le meme prefixe visible qu'a l'inscription. Sans lui, on
                  // tape un indicatif que la validation retire ensuite, ou on
                  // se demande s'il faut le mettre.
                  prefixText: '${AppConstants.phonePrefix} ',
                  counterText: '',
                  helperText: 'Seuls les 4 derniers chiffres sont conservés.',
                  suffixIcon: ValidatedSuffix(
                    valid: valide,
                    visible: numero.isNotEmpty,
                  ),
                ),
              ),
              const Gap(AppSpacing.md),
              TextField(
                controller: _holder,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom du titulaire (facultatif)',
                ),
              ),

              const Gap(AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // Neuf chiffres exigés ici, comme à l'inscription : un numéro
                  // trop court partait avant, et l'erreur revenait du dépôt
                  // sous forme de bandeau rouge une fois la feuille refermée.
                  onPressed: valide
                      ? () => Navigator.pop(
                          context,
                          _NewMethod(
                            kind: _kind,
                            reference: _reference.text,
                            holder: _holder.text,
                          ),
                        )
                      : null,
                  child: const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
