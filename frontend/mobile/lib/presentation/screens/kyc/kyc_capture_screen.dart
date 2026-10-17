import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/security/capture_analyzer.dart';
import '../../controllers/kyc_onboarding_controller.dart';
import '../../providers/core_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/capture_widgets.dart';
import '../../widgets/common.dart';

/// Étape de capture guidee (§6).
///
/// Les controles s'affichent avant la prise de vue : l'utilisateur voit ce qui
/// manque plutot que de decouvrir un rejet après coup. Tant que la detection
/// embarquee n'est pas branchee, la progression est simulee — l'écran et son
/// rythme restent identiques.
class KycCaptureScreen extends ConsumerStatefulWidget {
  const KycCaptureScreen({super.key, required this.step});

  final KycStep step;

  @override
  ConsumerState<KycCaptureScreen> createState() => _KycCaptureScreenState();
}

class _KycCaptureScreenState extends ConsumerState<KycCaptureScreen> {
  StreamSubscription<CaptureReadiness>? _subscription;
  CaptureReadiness? _readiness;
  bool _busy = false;

  CaptureTarget get _target => widget.step.target!;

  @override
  void initState() {
    super.initState();
    // L'analyse demarre a l'ouverture de l'écran, comme le ferait un flux
    // camera reel.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnalysis());
  }

  void _startAnalysis() {
    _subscription?.cancel();
    final analyzer = ref.read(captureAnalyzerProvider);
    _subscription = analyzer.watch(_target).listen((readiness) {
      if (mounted) setState(() => _readiness = readiness);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _capture({required bool fromGallery}) async {
    setState(() => _busy = true);
    try {
      final pipeline = ref.read(documentPipelineProvider);
      final type = switch (_target) {
        CaptureTarget.selfie => DocumentType.selfie,
        CaptureTarget.idFront => DocumentType.idFront,
        CaptureTarget.idBack => DocumentType.idBack,
        CaptureTarget.diploma => DocumentType.diploma,
      };

      final captured = fromGallery
          ? await pipeline.pickFromGallery(type)
          : await pipeline.captureFromCamera(
              type,
              frontCamera: _target.requiresLiveness,
            );

      if (!mounted || captured == null) return;
      ref.read(kycOnboardingProvider.notifier).captured(widget.step, captured);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Capture impossible : $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(kycOnboardingProvider.notifier);
    final state = ref.watch(kycOnboardingProvider);
    final text = Theme.of(context).textTheme;
    final readiness = _readiness;
    final ready = readiness?.ready ?? false;
    final existing = state.resultFor(widget.step)?.document;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepIndicator(
          current: widget.step.index + 1,
          total: 4,
          label: _target.title,
        ),
        const Gap(AppSpacing.xl),
        Text(_target.title, style: text.headlineSmall),
        const Gap(AppSpacing.sm),
        Text(
          _target.instruction,
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const Gap(AppSpacing.xl),

        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: CaptureFrame(
              target: _target,
              ready: ready,
              previewPath: existing?.path,
            ),
          ),
        ),
        const Gap(AppSpacing.lg),

        if (readiness != null) ...[
          CaptureHint(readiness: readiness),
          const Gap(AppSpacing.lg),
          AppCard(child: CaptureChecklist(readiness: readiness)),
        ],
        const Gap(AppSpacing.xl),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            // La capture reste possible avant que tous les controles soient
            // au vert : ils guident sans bloquer.
            onPressed: _busy ? null : () => _capture(fromGallery: false),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(
              ready ? 'Prendre la photo' : 'Prendre la photo malgre tout',
            ),
          ),
        ),
        const Gap(AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _capture(fromGallery: true),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Importer'),
              ),
            ),
            const Gap(AppSpacing.md),
            Expanded(
              child: TextButton(
                onPressed: () => controller.skip(widget.step),
                child: const Text('Continuer sans'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
