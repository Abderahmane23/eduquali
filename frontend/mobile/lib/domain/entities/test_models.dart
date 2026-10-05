import 'dart:convert';

import '../../core/constants/app_enums.dart';
import 'teacher_profile.dart';

/// Option de réponse d'une question a choix multiple.
class AnswerOption {
  const AnswerOption({required this.key, required this.text});

  final String key;
  final String text;

  factory AnswerOption.fromJson(Map<String, dynamic> json) =>
      AnswerOption(key: json['key'] as String, text: json['text'] as String);
}

/// Question de test (§10.1).
class TestQuestion {
  const TestQuestion({
    required this.id,
    required this.statement,
    required this.options,
    required this.correctKey,
    required this.domain,
    required this.position,
    this.difficulty = 2,
    this.explanation,
  });

  final String id;
  final String statement;
  final List<AnswerOption> options;
  final String correctKey;
  final String domain;
  final int position;
  final int difficulty;
  final String? explanation;

  static List<AnswerOption> parseOptions(String raw) => [
    for (final item in jsonDecode(raw) as List<dynamic>)
      AnswerOption.fromJson(item as Map<String, dynamic>),
  ];
}

/// Test disponible pour un couple matière + niveau (§10).
class TestSummary {
  const TestSummary({
    required this.id,
    required this.subject,
    required this.level,
    required this.title,
    required this.questionCount,
    required this.durationMinutes,
    required this.passingScore,
    this.rules,
    this.certification,
    this.activeSessionId,
  });

  final String id;
  final RefItem subject;
  final RefItem level;
  final String title;
  final int questionCount;
  final int durationMinutes;
  final int passingScore;
  final String? rules;

  /// Certification déjà obtenue pour ce couple, le cas echeant (§13).
  final CertificationItem? certification;

  /// Session interrompue a reprendre (§10.3).
  final String? activeSessionId;

  bool get isCertified => certification != null;
  bool get canResume => activeSessionId != null;
}

/// Session de test chargee en mémoire pendant le passage (§10.3, §11).
class TestSessionData {
  const TestSessionData({
    required this.sessionId,
    required this.test,
    required this.questions,
    required this.answers,
    required this.currentIndex,
    required this.remainingSeconds,
    required this.status,
    this.startedAt,
  });

  final String sessionId;
  final TestSummary test;
  final List<TestQuestion> questions;

  /// Réponses enregistrees, indexees par identifiant de question.
  final Map<String, String?> answers;
  final int currentIndex;
  final int remainingSeconds;
  final TestSessionStatus status;
  final DateTime? startedAt;

  TestQuestion get currentQuestion => questions[currentIndex];

  int get answeredCount =>
      answers.values.where((v) => v != null && v.isNotEmpty).length;

  bool get isLastQuestion => currentIndex >= questions.length - 1;

  double get progress =>
      questions.isEmpty ? 0 : (currentIndex + 1) / questions.length;

  TestSessionData copyWith({
    Map<String, String?>? answers,
    int? currentIndex,
    int? remainingSeconds,
    TestSessionStatus? status,
  }) => TestSessionData(
    sessionId: sessionId,
    test: test,
    questions: questions,
    answers: answers ?? this.answers,
    currentIndex: currentIndex ?? this.currentIndex,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    status: status ?? this.status,
    startedAt: startedAt,
  );
}
