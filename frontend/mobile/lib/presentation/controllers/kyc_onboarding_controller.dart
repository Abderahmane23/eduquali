import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_enums.dart';
import '../../core/security/capture_analyzer.dart';
import '../../core/storage/document_pipeline.dart';
import '../providers/core_providers.dart';

/// Étapes du parcours de vérification d'identité (§6).
enum KycStep {
  consent('Consentement'),
  selfie('Selfie'),
  idFront('Recto'),
  idBack('Verso'),
  review('Recapitulatif');

  const KycStep(this.label);
  final String label;

  CaptureTarget? get target => switch (this) {
    KycStep.selfie => CaptureTarget.selfie,
    KycStep.idFront => CaptureTarget.idFront,
    KycStep.idBack => CaptureTarget.idBack,
    _ => null,
  };
}

/// Résultat d'une étape : capture reelle, ou étape passee volontairement.
class KycStepResult {
  const KycStepResult({this.document, this.skipped = false});

  final CapturedDocument? document;

  /// L'utilisateur a choisi de continuer sans fournir le document.
  final bool skipped;

  bool get hasDocument => document != null;
}

/// État du parcours de vérification.
class KycState {
  const KycState({
    this.step = KycStep.consent,
    this.results = const {},
    this.consentGiven = false,
    this.submitting = false,
    this.submitted = false,
  });

  final KycStep step;
  final Map<KycStep, KycStepResult> results;
  final bool consentGiven;
  final bool submitting;
  final bool submitted;

  KycStepResult? resultFor(KycStep step) => results[step];

  /// Étapes de capture effectivement documentees.
  int get capturedCount => results.values.where((r) => r.hasDocument).length;

  int get skippedCount => results.values.where((r) => r.skipped).length;

  /// Le dossier est complet lorsque selfie et recto sont fournis. Le verso
  /// n'est pas exige pour toutes les pieces (§6, étape 2).
  bool get isComplete =>
      (resultFor(KycStep.selfie)?.hasDocument ?? false) &&
      (resultFor(KycStep.idFront)?.hasDocument ?? false);

  double get progress {
    // Le recapitulatif n'est pas une étape de saisie.
    final total = KycStep.values.length - 1;
    return (step.index / total).clamp(0.0, 1.0);
  }

  KycState copyWith({
    KycStep? step,
    Map<KycStep, KycStepResult>? results,
    bool? consentGiven,
    bool? submitting,
    bool? submitted,
  }) => KycState(
    step: step ?? this.step,
    results: results ?? this.results,
    consentGiven: consentGiven ?? this.consentGiven,
    submitting: submitting ?? this.submitting,
    submitted: submitted ?? this.submitted,
  );
}

/// Pilote le parcours de vérification (§6).
///
/// Mode démonstration : aucune donnée n'est transmise et aucune API n'est
/// appelée. Les captures restent dans le stockage prive de l'appareil et
/// chaque étape peut etre franchie sans fournir de document, afin que le
/// parcours complet reste parcourable pendant la mise au point.
class KycOnboardingController extends StateNotifier<KycState> {
  KycOnboardingController(this._pipeline) : super(const KycState());

  final DocumentPipeline _pipeline;

  void giveConsent() {
    state = state.copyWith(consentGiven: true);
    next();
  }

  /// Enregistre une capture et avance.
  void captured(KycStep step, CapturedDocument document) {
    state = state.copyWith(
      results: {
        ...state.results,
        step: KycStepResult(document: document),
      },
    );
    next();
  }

  /// Franchit l'étape sans document — explicitement autorise en mode
  /// démonstration, et trace pour que le recapitulatif le signale.
  void skip(KycStep step) {
    state = state.copyWith(
      results: {...state.results, step: const KycStepResult(skipped: true)},
    );
    next();
  }

  void next() {
    final index = state.step.index;
    if (index >= KycStep.values.length - 1) return;
    state = state.copyWith(step: KycStep.values[index + 1]);
  }

  void back() {
    final index = state.step.index;
    if (index == 0) return;
    state = state.copyWith(step: KycStep.values[index - 1]);
  }

  void goTo(KycStep step) => state = state.copyWith(step: step);

  /// Reprend une étape : la capture precedente est effacee du dossier, le
  /// fichier local correspondant est supprime.
  Future<void> retake(KycStep step) async {
    final existing = state.resultFor(step);
    await _pipeline.deleteLocal(existing?.document?.path);
    final results = {...state.results}..remove(step);
    state = state.copyWith(results: results, step: step);
  }

  /// Simule la soumission du dossier — aucun appel réseau n'est effectue.
  ///
  /// Le branchement reel enverra sur `POST /onboarding/biometric` puis
  /// suivra le travail asynchrone via la file de synchronisation (§43).
  Future<void> simulateSubmission() async {
    state = state.copyWith(submitting: true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    state = state.copyWith(submitting: false, submitted: true);
    if (kDebugMode) {
      debugPrint(
        '[kyc] simulation : ${state.capturedCount} document(s) prets, '
        'aucune transmission effectuee',
      );
    }
  }

  /// Statut de vérification decoule de l'état du dossier. Tant que rien n'est
  /// transmis, l'identité ne peut pas etre consideree comme vérifiée (§6).
  VerificationStatus get resultingStatus =>
      state.isComplete ? VerificationStatus.pending : VerificationStatus.none;

  void reset() => state = const KycState();
}

final kycOnboardingProvider =
    StateNotifierProvider.autoDispose<KycOnboardingController, KycState>(
      (ref) => KycOnboardingController(ref.watch(documentPipelineProvider)),
    );

/// Analyseur de capture — simule pour l'instant, remplacable par une
/// implementation embarquee sans modifier les ecrans.
final captureAnalyzerProvider = Provider.autoDispose<CaptureAnalyzer>((ref) {
  final analyzer = SimulatedCaptureAnalyzer();
  ref.onDispose(analyzer.dispose);
  return analyzer;
});
