import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/onboarding_spec.dart';
import '../../controllers/onboarding_flow_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/typeform_kit.dart';
import 'onboarding_steps.dart';

/// Rendu d'un parcours d'inscription décrit en JSON.
///
/// L'écran ne connait aucune question : il parcourt la description et delegue
/// le rendu au composant correspondant au type d'étape. Ajouter une question
/// se fait dans le JSON, sans toucher a ce fichier.
class OnboardingFlowScreen extends ConsumerWidget {
  const OnboardingFlowScreen({
    super.key,
    required this.audience,
    this.initialAnswers,
    this.onCompleted,
  });

  final OnboardingAudience audience;

  /// Réponses déjà collectées par un parcours précédent (la découverte).
  final Map<String, dynamic>? initialAnswers;

  /// Réponses collectees en fin de parcours.
  final void Function(Map<String, dynamic> answers)? onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specAsync = ref.watch(onboardingSpecProvider(audience));

    return specAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(
          child: EmptyState(
            icon: Icons.error_outline,
            title: 'Parcours indisponible',
            message: '$error',
          ),
        ),
      ),
      data: (spec) => _FlowBody(
        spec: spec,
        initialAnswers: initialAnswers,
        onCompleted: onCompleted,
      ),
    );
  }
}

class _FlowBody extends ConsumerStatefulWidget {
  const _FlowBody({required this.spec, this.initialAnswers, this.onCompleted});

  final OnboardingFlowSpec spec;
  final Map<String, dynamic>? initialAnswers;
  final void Function(Map<String, dynamic> answers)? onCompleted;

  @override
  ConsumerState<_FlowBody> createState() => _FlowBodyState();
}

class _FlowBodyState extends ConsumerState<_FlowBody> {
  @override
  void initState() {
    super.initState();
    // Les réponses de la découverte sont versées une seule fois, apres le
    // premier rendu : le contrôleur n'existe pas encore a la construction.
    final seed = widget.initialAnswers;
    if (seed == null || seed.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(onboardingFlowProvider(widget.spec).notifier).seed(seed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final onCompleted = widget.onCompleted;
    final state = ref.watch(onboardingFlowProvider(spec));
    final controller = ref.read(onboardingFlowProvider(spec).notifier);
    final step = state.step;

    void advance() {
      // L'etat est relu ici, et non pris a la construction.
      //
      // Un ecran qui repond puis avance dans le meme geste — le choix du
      // profil — ecrit sa reponse juste avant d'appeler `advance`. Le widget
      // n'a pas encore ete reconstruit : l'etat capture plus haut ignore
      // cette reponse, et avec elle les etapes qu'elle vient de rendre
      // visibles. Le parcours se croyait alors termine et se refermait.
      final courant = ref.read(onboardingFlowProvider(spec));
      if (!courant.isLast) {
        controller.next();
        return;
      }
      // Fin de parcours : c'est l'appelant qui decide de la suite, et lui
      // seul.
      onCompleted?.call(controller.answers);
    }

    return TypeformScaffold(
      title: step.title,
      body: step.body,
      illustration: step.image == null
          ? null
          : OnboardingIllustrationView(image: step.image!),
      progress: state.progress,
      sectionLabel: '${state.position + 1}/${state.total}',
      onBack: state.isFirst ? null : controller.back,
      onContinue: advance,
      canContinue: state.canContinue,
      continueLabel: _continueLabel(step, state),
      secondary: step.type == StepType.planSelect
          ? TextButton(
              onPressed: () {
                controller.setAnswer(step.fieldId!, step.declineValue);
                advance();
              },
              child: Text(step.declineLabel ?? 'Plus tard'),
            )
          : step.optional && step.type.collectsAnswer
          ? TextButton(onPressed: advance, child: const Text('Passer'))
          : null,
      child: OnboardingStepView(spec: spec, step: step, onAdvance: advance),
    );
  }

  String _continueLabel(OnboardingStep step, OnboardingFlowState state) {
    if (step.cta != null) return step.cta!;
    if (state.isLast) return 'Terminer';
    return 'Continuer';
  }
}

/// Aiguillage vers le composant correspondant au type d'étape.
class OnboardingStepView extends ConsumerWidget {
  const OnboardingStepView({
    super.key,
    required this.spec,
    required this.step,
    required this.onAdvance,
  });

  final OnboardingFlowSpec spec;
  final OnboardingStep step;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (step.type) {
      StepType.statement => StatementStepView(step: step),
      StepType.stepsPreview => StepsPreviewStepView(step: step),
      StepType.carousel => CarouselStepView(step: step),
      StepType.roleSelect => RoleSelectStepView(
        spec: spec,
        step: step,
        onAdvance: onAdvance,
      ),
      StepType.form => FormStepView(spec: spec, step: step),
      StepType.singleChoice => SingleChoiceStepView(
        spec: spec,
        step: step,
        onAdvance: onAdvance,
      ),
      StepType.multiChoice => MultiChoiceStepView(spec: spec, step: step),
      StepType.boolean => BooleanStepView(
        spec: spec,
        step: step,
        onAdvance: onAdvance,
      ),
      StepType.range => RangeStepView(spec: spec, step: step),
      StepType.planSelect => PlanStepView(spec: spec, step: step),
      StepType.upload => UploadStepView(spec: spec, step: step),
      StepType.dayHours => DayHoursStepView(spec: spec, step: step),
    };
  }
}

/// Point d'entree : lance le parcours enseignant.
class TeacherOnboardingScreen extends StatelessWidget {
  const TeacherOnboardingScreen({super.key, this.onCompleted});

  final void Function(Map<String, dynamic>)? onCompleted;

  @override
  Widget build(BuildContext context) => OnboardingFlowScreen(
    audience: OnboardingAudience.teacher,
    onCompleted: onCompleted,
  );
}

/// Point d'entree : lance le parcours établissement.
class InstitutionOnboardingScreen extends StatelessWidget {
  const InstitutionOnboardingScreen({super.key, this.onCompleted});

  final void Function(Map<String, dynamic>)? onCompleted;

  @override
  Widget build(BuildContext context) => OnboardingFlowScreen(
    audience: OnboardingAudience.institution,
    onCompleted: onCompleted,
  );
}

/// Point d'entree : lance le parcours parent.
class ParentOnboardingScreen extends StatelessWidget {
  const ParentOnboardingScreen({super.key, this.onCompleted});

  final void Function(Map<String, dynamic>)? onCompleted;

  @override
  Widget build(BuildContext context) => OnboardingFlowScreen(
    audience: OnboardingAudience.parent,
    onCompleted: onCompleted,
  );
}

/// Espacement standard entre le titre et les options.
const onboardingContentGap = Gap(AppSpacing.sm);
