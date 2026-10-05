import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/ai/ai_gateway.dart';
import '../../../domain/entities/course_models.dart';
import '../../providers/feature_providers.dart';
import 'assistant_messages.dart';

/// État de la conversation.
class AssistantState {
  const AssistantState({this.messages = const [], this.busy = false});

  final List<AssistantMessage> messages;
  final bool busy;

  bool get isEmpty => messages.isEmpty;

  AssistantState copyWith({List<AssistantMessage>? messages, bool? busy}) =>
      AssistantState(
        messages: messages ?? this.messages,
        busy: busy ?? this.busy,
      );
}

/// Pilote la conversation de l'assistant.
///
/// Ne connaît que `AiGateway` : le jour où les réponses viennent du serveur,
/// cet écran ne change pas.
class AssistantController extends StateNotifier<AssistantState> {
  AssistantController(this._ai) : super(const AssistantState());

  final AiGateway? _ai;

  void _add(AssistantMessage message) =>
      state = state.copyWith(messages: [...state.messages, message]);

  void _replacePending(AssistantMessage message) {
    final without = [
      for (final m in state.messages)
        if (m is! PendingMessage) m,
    ];
    state = state.copyWith(messages: [...without, message], busy: false);
  }

  /// Message libre.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _ai == null || state.busy) return;

    _add(UserMessage(trimmed));
    state = state.copyWith(busy: true);
    _add(const PendingMessage('L’assistant réfléchit…'));

    try {
      _replacePending(AssistantText(await _ai.chat(trimmed)));
    } on AiException catch (error) {
      _replacePending(AssistantText(error.message, isError: true));
    }
  }

  /// Demande un plan de cours à partir du formulaire.
  Future<void> requestOutline(CourseBrief brief) async {
    if (_ai == null || state.busy) return;

    _add(UserMessage('Crée un cours : ${brief.title} · ${brief.audience}'));
    state = state.copyWith(busy: true);
    _add(const PendingMessage('Préparation du plan…'));

    try {
      final outline = await _ai.outline(brief);
      _replacePending(OutlineMessage(brief: brief, outline: outline));
    } on AiException catch (error) {
      _replacePending(AssistantText(error.message, isError: true));
    }
  }

  /// Construit le cours proposé par un plan.
  Future<void> build(CourseBrief brief, CourseOutline outline) async {
    if (_ai == null || state.busy) return;

    state = state.copyWith(busy: true);
    _add(const PendingMessage('Construction du cours…'));

    try {
      _replacePending(CourseMessage(await _ai.buildCourse(brief, outline)));
    } on AiException catch (error) {
      _replacePending(AssistantText(error.message, isError: true));
    }
  }

  /// Nouvelle version d'un cours existant.
  Future<void> improve(String courseId, String instruction) async {
    if (_ai == null || state.busy) return;

    _add(UserMessage(instruction));
    state = state.copyWith(busy: true);
    _add(const PendingMessage('Mise à jour du cours…'));

    try {
      _replacePending(
        CourseMessage(await _ai.improveCourse(courseId, instruction)),
      );
    } on AiException catch (error) {
      _replacePending(AssistantText(error.message, isError: true));
    }
  }
}

final assistantProvider =
    StateNotifierProvider<AssistantController, AssistantState>(
      (ref) => AssistantController(ref.watch(aiGatewayProvider)),
    );
