import 'dart:convert';

/// Résultat par domaine de compétence (§12).
class DomainScore {
  const DomainScore({
    required this.domain,
    required this.correct,
    required this.total,
  });

  final String domain;
  final int correct;
  final int total;

  /// Pourcentage de réussite du domaine, arrondi.
  int get percentage => total == 0 ? 0 : ((correct / total) * 100).round();

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'correct': correct,
    'total': total,
    'percentage': percentage,
  };

  factory DomainScore.fromJson(Map<String, dynamic> json) => DomainScore(
    domain: json['domain'] as String,
    correct: json['correct'] as int,
    total: json['total'] as int,
  );
}

/// Résultat complet d'une session de test.
class TestResult {
  const TestResult({
    required this.score,
    required this.correctCount,
    required this.totalQuestions,
    required this.answeredCount,
    required this.domainScores,
    required this.passed,
    required this.passingScore,
  });

  /// Score global sur 100 (§12).
  final int score;
  final int correctCount;
  final int totalQuestions;
  final int answeredCount;
  final List<DomainScore> domainScores;
  final bool passed;
  final int passingScore;

  int get unansweredCount => totalQuestions - answeredCount;

  String get domainScoresJson =>
      jsonEncode([for (final d in domainScores) d.toJson()]);

  static List<DomainScore> parseDomainScores(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in decoded)
        DomainScore.fromJson(item as Map<String, dynamic>),
    ];
  }
}

/// Question telle qu'utilisee par le moteur de correction.
class ScorableQuestion {
  const ScorableQuestion({
    required this.id,
    required this.correctKey,
    required this.domain,
  });

  final String id;
  final String correctKey;
  final String domain;
}

/// Correction d'une session (§12).
///
/// Le calcul est réalise localement pour un affichage immediat hors ligne ;
/// le serveur reste la source officielle du résultat après synchronisation
/// (§11).
abstract final class TestScoring {
  static TestResult score({
    required List<ScorableQuestion> questions,
    required Map<String, String?> answers,
    required int passingScore,
  }) {
    final byDomain = <String, ({int correct, int total})>{};
    var correctCount = 0;
    var answeredCount = 0;

    for (final question in questions) {
      final given = answers[question.id];
      final isAnswered = given != null && given.isNotEmpty;
      final isCorrect = isAnswered && given == question.correctKey;

      if (isAnswered) answeredCount++;
      if (isCorrect) correctCount++;

      final current = byDomain[question.domain] ?? (correct: 0, total: 0);
      byDomain[question.domain] = (
        correct: current.correct + (isCorrect ? 1 : 0),
        total: current.total + 1,
      );
    }

    final total = questions.length;
    // Une question sans réponse est comptee comme incorrecte.
    final globalScore = total == 0 ? 0 : ((correctCount / total) * 100).round();

    final domainScores =
        byDomain.entries
            .map(
              (e) => DomainScore(
                domain: e.key,
                correct: e.value.correct,
                total: e.value.total,
              ),
            )
            .toList()
          ..sort((a, b) => a.domain.compareTo(b.domain));

    return TestResult(
      score: globalScore,
      correctCount: correctCount,
      totalQuestions: total,
      answeredCount: answeredCount,
      domainScores: domainScores,
      passed: globalScore >= passingScore,
      passingScore: passingScore,
    );
  }
}
