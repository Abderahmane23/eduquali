import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/storage/document_pipeline.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../providers/core_providers.dart';
import '../../providers/feature_providers.dart';
import '../../providers/session_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Ajout d'un diplôme (§7).
///
/// Le document peut etre photographie ou importe ; l'OCR serveur pre-remplira
/// les champs lors de la vérification.
class DiplomaFormScreen extends ConsumerStatefulWidget {
  const DiplomaFormScreen({super.key});

  @override
  ConsumerState<DiplomaFormScreen> createState() => _DiplomaFormScreenState();
}

class _DiplomaFormScreenState extends ConsumerState<DiplomaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _type = TextEditingController();
  final _institution = TextEditingController();
  final _field = TextEditingController();
  final _speciality = TextEditingController();
  final _year = TextEditingController();

  String? _academicLevelId;
  CapturedDocument? _document;
  bool _busy = false;

  static const _commonTypes = [
    'Licence',
    'Master',
    'Doctorat',
    'DUT / BTS',
    'Diplôme d’ingenieur',
    'Certificat d’aptitude pédagogique',
    'Baccalauréat',
  ];

  @override
  void dispose() {
    for (final controller in [
      _type,
      _institution,
      _field,
      _speciality,
      _year,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final levels = ref.watch(levelsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un diplôme'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Justificatif — pilote le statut de vérification.
                    _DocumentPicker(
                      document: _document,
                      busy: _busy,
                      onCapture: () => _pickDocument(fromCamera: true),
                      onImport: () => _pickDocument(fromCamera: false),
                      onRemove: () => setState(() => _document = null),
                    ),
                    const Gap(AppSpacing.xl),

                    Text('Informations du diplôme', style: text.titleMedium),
                    const Gap(AppSpacing.lg),

                    TextFormField(
                      controller: _type,
                      decoration: const InputDecoration(
                        labelText: 'Type de diplôme',
                        hintText: 'Licence, Master, Doctorat…',
                      ),
                      validator: (v) => Validators.required(v, 'Le type'),
                    ),
                    const Gap(AppSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final type in _commonTypes)
                          ActionChip(
                            label: Text(type),
                            onPressed: () => setState(() => _type.text = type),
                          ),
                      ],
                    ),
                    const Gap(AppSpacing.lg),

                    TextFormField(
                      controller: _institution,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Établissement d’obtention',
                      ),
                      validator: (v) =>
                          Validators.required(v, 'L’établissement'),
                    ),
                    const Gap(AppSpacing.lg),

                    TextFormField(
                      controller: _field,
                      decoration: const InputDecoration(
                        labelText: 'Domaine (facultatif)',
                        hintText: 'Sciences, Lettres, Droit…',
                      ),
                    ),
                    const Gap(AppSpacing.lg),

                    TextFormField(
                      controller: _speciality,
                      decoration: const InputDecoration(
                        labelText: 'Spécialité (facultatif)',
                        hintText: 'Mathématiques appliquées…',
                      ),
                    ),
                    const Gap(AppSpacing.lg),

                    TextFormField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Année d’obtention',
                      ),
                      validator: Validators.year,
                    ),
                    const Gap(AppSpacing.lg),

                    DropdownButtonFormField<String>(
                      initialValue: _academicLevelId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Niveau academique (facultatif)',
                      ),
                      items: [
                        for (final level in levels)
                          DropdownMenuItem(
                            value: level.id,
                            child: Text(level.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _academicLevelId = value),
                    ),

                    const Gap(AppSpacing.xl),
                    InfoBanner(
                      message: _document == null
                          ? 'Sans justificatif, le diplôme restera au statut '
                                '« A corriger » et ne pourra pas etre vérifié.'
                          : 'Le document sera televerse dès que le serveur sera '
                                'joignable, puis controle par notre equipe.',
                      tone: _document == null
                          ? StatusTone.warning
                          : StatusTone.info,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enregistrer ce diplôme'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDocument({required bool fromCamera}) async {
    setState(() => _busy = true);
    try {
      final pipeline = ref.read(documentPipelineProvider);
      // « Importer » passait par la galerie, qui ne montre que des images :
      // un diplome scanne est presque toujours un PDF, et il etait donc
      // impossible a deposer. Le selecteur de fichiers accepte les deux.
      final captured = fromCamera
          ? await pipeline.captureFromCamera(DocumentType.diploma)
          : await pipeline.pickDocumentFile(DocumentType.diploma);
      if (captured != null && mounted) {
        setState(() => _document = captured);
      }
    } on DocumentTooLarge catch (refus) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$refus')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Capture impossible : $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final teacherId = ref.read(currentTeacherIdProvider);
    if (teacherId == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(verificationRepositoryProvider)
          .addDiploma(
            teacherId: teacherId,
            diplomaType: _type.text.trim(),
            institutionName: _institution.text.trim(),
            graduationYear: int.parse(_year.text.trim()),
            field: _field.text.trim().isEmpty ? null : _field.text.trim(),
            speciality: _speciality.text.trim().isEmpty
                ? null
                : _speciality.text.trim(),
            academicLevelId: _academicLevelId,
            document: _document,
          );

      ref.invalidate(documentsProvider);
      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Zone de depot du justificatif.
class _DocumentPicker extends StatelessWidget {
  const _DocumentPicker({
    required this.document,
    required this.busy,
    required this.onCapture,
    required this.onImport,
    required this.onRemove,
  });

  final CapturedDocument? document;
  final bool busy;
  final VoidCallback onCapture;
  final VoidCallback onImport;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (document != null && File(document!.path).existsSync()) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.file(
                File(document!.path),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 17,
                  color: AppColors.success,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Justificatif ajouté · ${Fmt.bytes(document!.sizeBytes)}',
                    style: text.bodySmall,
                  ),
                ),
                TextButton(onPressed: onRemove, child: const Text('Retirer')),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 30,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text('Justificatif du diplôme', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Photographiez votre diplôme, ou importez-le en PDF',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onCapture,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Photo'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onImport,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('PDF ou image'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
