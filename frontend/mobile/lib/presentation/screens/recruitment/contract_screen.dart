import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_enums.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/recruitment_models.dart';
import '../../../domain/usecases/contract_builder.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Écran 30 — Contrat (§27).
///
/// Le contrat est genere a partir d'un modèle et des conditions acceptees,
/// puis conserve dans l'espace de recrutement.
class ContractScreen extends ConsumerStatefulWidget {
  const ContractScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<ContractScreen> createState() => _ContractScreenState();
}

class _ContractScreenState extends ConsumerState<ContractScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(recruitmentRoomProvider(widget.roomId));
    final session = ref.watch(currentSessionProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Contrat'), leading: const BackButton()),
      body: roomAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Contrat indisponible',
          message: '$error',
        ),
        data: (room) {
          if (room == null) return const SizedBox.shrink();

          if (room.offer?.status != OfferStatus.accepted) {
            return const EmptyState(
              icon: Icons.description_outlined,
              title: 'Aucun contrat a etablir',
              message:
                  'Le contrat est genere une fois la proposition de '
                  'recrutement acceptée par l’enseignant.',
            );
          }

          final contract = room.contract;
          if (contract == null) {
            return _GeneratePrompt(
              busy: _busy,
              onGenerate: () => _generate(room),
            );
          }

          final isTeacher = session?.isTeacher ?? false;
          final alreadySigned = isTeacher
              ? contract.signedByTeacher
              : contract.signedByInstitution;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(contract.reference, style: text.titleMedium),
                              const SizedBox(height: 2),
                              Text(
                                'Etabli le ${Fmt.date(contract.createdAt)}',
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        StatusPill(
                          label: contract.status.label,
                          tone: contract.fullySigned
                              ? StatusTone.success
                              : StatusTone.info,
                        ),
                      ],
                    ),

                    const Gap(AppSpacing.lg),

                    // État des signatures (§27).
                    AppCard(
                      child: Column(
                        children: [
                          _SignatureRow(
                            label: 'Établissement',
                            signed: contract.signedByInstitution,
                            signedAt: contract.institutionSignedAt,
                          ),
                          const Divider(height: 20),
                          _SignatureRow(
                            label: 'Enseignant',
                            signed: contract.signedByTeacher,
                            signedAt: contract.teacherSignedAt,
                          ),
                        ],
                      ),
                    ),

                    const Gap(AppSpacing.lg),

                    // Corps du contrat.
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: SelectableText(
                        contract.bodyText,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.6,
                          fontFamily: 'monospace',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),

                    const Gap(AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _exportPdf(room),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 19),
                      label: const Text('Exporter en PDF'),
                    ),

                    const Gap(AppSpacing.lg),
                    const InfoBanner(
                      message:
                          'La valeur juridique de la signature electronique '
                          'doit etre appreciee au regard du cadre applicable en '
                          'Guinée. Une validation juridique prealable est '
                          'requise avant mise en production.',
                      tone: StatusTone.neutral,
                      icon: Icons.gavel_outlined,
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: alreadySigned
                      ? const OutlinedButton(
                          onPressed: null,
                          child: Text('Vous avez signe ce contrat'),
                        )
                      : FilledButton.icon(
                          onPressed: () =>
                              context.push('/rooms/${widget.roomId}/signature'),
                          icon: const Icon(Icons.draw_outlined, size: 19),
                          label: const Text('Signer le contrat'),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Genere le contrat a partir du modèle et des conditions acceptees (§27).
  Future<void> _generate(RecruitmentRoomView room) async {
    final offer = room.offer;
    if (offer == null) return;

    setState(() => _busy = true);
    final now = DateTime.now();
    final reference = ContractBuilder.reference(now, room.id);

    final body = ContractBuilder.build(
      reference: reference,
      institution: room.job.institution,
      teacher: room.teacher,
      offer: offer,
      job: room.job,
      issuedAt: now,
    );

    await ref
        .read(recruitmentRepositoryProvider)
        .createContract(
          roomId: room.id,
          offerId: offer.id,
          reference: reference,
          bodyText: body,
        );

    if (mounted) setState(() => _busy = false);
  }

  /// Écrit le contrat sur l'appareil au format PDF.
  Future<void> _exportPdf(RecruitmentRoomView room) async {
    final contract = room.contract;
    if (contract == null) return;

    setState(() => _busy = true);
    try {
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (_) => [
            pw.Text(
              contract.bodyText,
              style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2.5),
            ),
            // Les signatures manuscrites sont annexees au document.
            if (contract.institutionSignaturePath != null ||
                contract.teacherSignaturePath != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 24),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfSignature(
                      'Pour l’Employeur',
                      contract.institutionSignaturePath,
                    ),
                    _pdfSignature(
                      'L’Enseignant',
                      contract.teacherSignaturePath,
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final file = File(p.join(directory.path, '${contract.reference}.pdf'));
      await file.writeAsBytes(await document.save());

      await ref
          .read(recruitmentRepositoryProvider)
          .attachContractPdf(contract.id, file.path);

      final result = await OpenFilex.open(file.path);
      if (!mounted) return;

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF enregistre : ${file.path}')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export impossible : $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  pw.Widget _pdfSignature(String label, String? path) {
    final hasImage = path != null && File(path).existsSync();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 6),
        if (hasImage)
          pw.Image(
            pw.MemoryImage(File(path).readAsBytesSync()),
            width: 140,
            height: 60,
            fit: pw.BoxFit.contain,
          )
        else
          pw.Container(width: 140, height: 60),
        pw.Container(width: 140, height: 0.8, color: PdfColors.grey600),
      ],
    );
  }
}

class _GeneratePrompt extends StatelessWidget {
  const _GeneratePrompt({required this.busy, required this.onGenerate});

  final bool busy;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const Gap(AppSpacing.lg),
          Text(
            'Generer le contrat',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(AppSpacing.sm),
          Text(
            'Le contrat sera etabli a partir du modèle de la plateforme et des '
            'conditions acceptees par les deux parties.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Gap(AppSpacing.xl),
          FilledButton(
            onPressed: busy ? null : onGenerate,
            style: FilledButton.styleFrom(minimumSize: const Size(220, 50)),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Generer le contrat'),
          ),
        ],
      ),
    ),
  );
}

class _SignatureRow extends StatelessWidget {
  const _SignatureRow({
    required this.label,
    required this.signed,
    this.signedAt,
  });

  final String label;
  final bool signed;
  final DateTime? signedAt;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(
          signed ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 19,
          color: signed ? AppColors.success : AppColors.borderStrong,
        ),
        const SizedBox(width: 11),
        Expanded(child: Text(label, style: text.titleSmall)),
        Text(
          signed && signedAt != null ? Fmt.dateShort(signedAt!) : 'En attente',
          style: text.labelSmall,
        ),
      ],
    );
  }
}
