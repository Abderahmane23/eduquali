import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_enums.dart';
import '../../domain/entities/teacher_profile.dart';
import '../../domain/entities/test_models.dart';
import '../../domain/usecases/test_scoring.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';

/// Tests de compétence et certifications (§10 a §13).
///
/// Le test doit fonctionner sans connexion (§11) : les questions sont déjà
/// presentes en base locale, la session et chaque réponse sont écrites
/// localement, et la synchronisation intervient plus tard. Le serveur reste
/// la source officielle du résultat.
class TestRepository {
  TestRepository(this._db, this._sync);

  final AppDatabase _db;
  final SyncEngine _sync;
  static const _uuid = Uuid();

  /// Tests disponibles pour les couples matière/niveau declares (§10.1).
  Future<List<TestSummary>> availableTests(String teacherId) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT DISTINCT t.*, s.name AS subject_name, s.code AS subject_code,
                 l.name AS level_name, l.code AS level_code,
                 tc.id AS cert_id, tc.score AS cert_score,
                 tc.issued_at AS cert_issued_at,
                 tc.domain_scores_json AS cert_domains,
                 (SELECT ts.id FROM test_sessions ts
                   WHERE ts.test_id = t.id AND ts.teacher_id = ?1
                     AND ts.status IN ('CREATED', 'IN_PROGRESS')
                   ORDER BY ts.created_at DESC LIMIT 1) AS active_session
          FROM teacher_levels tl
          JOIN tests t ON t.subject_id = tl.subject_id AND t.level_id = tl.level_id
          JOIN subjects s ON s.id = t.subject_id
          JOIN levels l ON l.id = t.level_id
          LEFT JOIN teacher_certifications tc
            ON tc.teacher_id = ?1 AND tc.subject_id = t.subject_id
           AND tc.level_id = t.level_id
          WHERE tl.teacher_id = ?1 AND t.active = 1
          ORDER BY s.sort_order, l.sort_order
          ''',
          variables: [Variable<String>(teacherId)],
          readsFrom: {
            _db.teacherLevels,
            _db.tests,
            _db.subjects,
            _db.levels,
            _db.teacherCertifications,
            _db.testSessions,
          },
        )
        .get();

    return [for (final row in rows) _mapSummary(row)];
  }

  Stream<List<TestSummary>> watchAvailableTests(String teacherId) => _db
      .customSelect(
        'SELECT COUNT(*) AS c FROM teacher_levels WHERE teacher_id = ?1',
        variables: [Variable<String>(teacherId)],
        readsFrom: {
          _db.teacherLevels,
          _db.teacherCertifications,
          _db.testSessions,
        },
      )
      .watch()
      .asyncMap((_) => availableTests(teacherId));

  TestSummary _mapSummary(QueryRow row) {
    final certId = row.read<String?>('cert_id');
    final subject = RefItem(
      id: row.read<String>('subject_id'),
      name: row.read<String>('subject_name'),
      code: row.read<String?>('subject_code'),
    );
    final level = RefItem(
      id: row.read<String>('level_id'),
      name: row.read<String>('level_name'),
      code: row.read<String?>('level_code'),
    );

    return TestSummary(
      id: row.read<String>('id'),
      subject: subject,
      level: level,
      title: row.read<String>('title'),
      questionCount: row.read<int>('question_count'),
      durationMinutes: row.read<int>('duration_minutes'),
      passingScore: row.read<int>('passing_score'),
      rules: row.read<String?>('rules'),
      certification: certId == null
          ? null
          : CertificationItem(
              id: certId,
              subject: subject,
              level: level,
              score: row.read<int>('cert_score'),
              issuedAt: row.read<DateTime>('cert_issued_at'),
              domainScoresJson: row.read<String?>('cert_domains'),
            ),
      activeSessionId: row.read<String?>('active_session'),
    );
  }

  Future<TestSummary?> test(String testId, String teacherId) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT t.*, s.name AS subject_name, s.code AS subject_code,
                 l.name AS level_name, l.code AS level_code,
                 tc.id AS cert_id, tc.score AS cert_score,
                 tc.issued_at AS cert_issued_at,
                 tc.domain_scores_json AS cert_domains,
                 (SELECT ts.id FROM test_sessions ts
                   WHERE ts.test_id = t.id AND ts.teacher_id = ?2
                     AND ts.status IN ('CREATED', 'IN_PROGRESS')
                   ORDER BY ts.created_at DESC LIMIT 1) AS active_session
          FROM tests t
          JOIN subjects s ON s.id = t.subject_id
          JOIN levels l ON l.id = t.level_id
          LEFT JOIN teacher_certifications tc
            ON tc.teacher_id = ?2 AND tc.subject_id = t.subject_id
           AND tc.level_id = t.level_id
          WHERE t.id = ?1
          ''',
          variables: [Variable<String>(testId), Variable<String>(teacherId)],
          readsFrom: {
            _db.tests,
            _db.subjects,
            _db.levels,
            _db.teacherCertifications,
            _db.testSessions,
          },
        )
        .get();
    return rows.isEmpty ? null : _mapSummary(rows.first);
  }

  /// Cree la session et prepare tout le contenu necessaire hors ligne (§11).
  Future<String> startSession({
    required String testId,
    required String teacherId,
  }) async {
    final summary = await test(testId, teacherId);
    if (summary == null) throw StateError('Test introuvable');

    // Une session interrompue est reprise plutot que recreee.
    if (summary.activeSessionId != null) return summary.activeSessionId!;

    final questions = await _questions(testId);
    final sessionId = _uuid.v4();

    await _db.transaction(() async {
      await _db
          .into(_db.testSessions)
          .insert(
            TestSessionsCompanion.insert(
              id: sessionId,
              teacherId: teacherId,
              testId: testId,
              status: Value(TestSessionStatus.inProgress.code),
              startedAt: Value(DateTime.now()),
              remainingSeconds: Value(summary.durationMinutes * 60),
              // L'ordre est fige au demarrage pour rester stable en reprise.
              questionOrder: Value(questions.map((q) => q.id).join(',')),
              dirty: const Value(true),
            ),
          );

      // Une ligne de réponse par question : la progression est ainsi
      // sauvegardee au fil de l'eau, même sans connexion.
      await _db.batch((batch) {
        batch.insertAll(_db.testAnswers, [
          for (final question in questions)
            TestAnswersCompanion.insert(
              id: '${sessionId}_${question.id}',
              sessionId: sessionId,
              questionId: question.id,
            ),
        ]);
      });
    });

    await _sync.enqueue(
      entity: 'test_session',
      entityId: sessionId,
      operation: SyncOperation.create,
      payload: {'testId': testId, 'teacherId': teacherId},
    );
    return sessionId;
  }

  Future<List<TestQuestion>> _questions(String testId) async {
    final rows =
        await (_db.select(_db.testQuestions)
              ..where((t) => t.testId.equals(testId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();

    return [
      for (final r in rows)
        TestQuestion(
          id: r.id,
          statement: r.statement,
          options: TestQuestion.parseOptions(r.optionsJson),
          correctKey: r.correctKey,
          domain: r.domain,
          position: r.position,
          difficulty: r.difficulty,
          explanation: r.explanation,
        ),
    ];
  }

  /// Charge une session complété pour l'écran de passage.
  Future<TestSessionData?> loadSession(String sessionId) async {
    final session = await (_db.select(
      _db.testSessions,
    )..where((t) => t.id.equals(sessionId))).getSingleOrNull();
    if (session == null) return null;

    final summary = await test(session.testId, session.teacherId);
    if (summary == null) return null;

    final all = await _questions(session.testId);
    final order = (session.questionOrder ?? '')
        .split(',')
        .where((e) => e.isNotEmpty)
        .toList();

    // L'ordre fige au demarrage prime ; sinon on retombe sur l'ordre naturel.
    final questions = order.isEmpty
        ? all
        : [for (final id in order) ?all.where((q) => q.id == id).firstOrNull];

    final answerRows = await (_db.select(
      _db.testAnswers,
    )..where((t) => t.sessionId.equals(sessionId))).get();

    return TestSessionData(
      sessionId: sessionId,
      test: summary,
      questions: questions,
      answers: {
        for (final q in questions)
          q.id: answerRows
              .where((a) => a.questionId == q.id)
              .firstOrNull
              ?.answerKey,
      },
      currentIndex: session.currentIndex.clamp(
        0,
        questions.isEmpty ? 0 : questions.length - 1,
      ),
      remainingSeconds: session.remainingSeconds,
      status: TestSessionStatus.fromCode(session.status),
      startedAt: session.startedAt,
    );
  }

  /// Enregistre une réponse — écriture locale immediate (§11).
  Future<void> saveAnswer({
    required String sessionId,
    required String questionId,
    required String? answerKey,
    int elapsedSeconds = 0,
  }) async {
    await _db
        .into(_db.testAnswers)
        .insertOnConflictUpdate(
          TestAnswersCompanion.insert(
            id: '${sessionId}_$questionId',
            sessionId: sessionId,
            questionId: questionId,
            answerKey: Value(answerKey),
            elapsedSeconds: Value(elapsedSeconds),
            answeredAt: Value(DateTime.now()),
            dirty: const Value(true),
          ),
        );
  }

  /// Sauvegarde périodique de la progression (§10.3).
  Future<void> saveProgress({
    required String sessionId,
    required int currentIndex,
    required int remainingSeconds,
  }) async {
    await (_db.update(
      _db.testSessions,
    )..where((t) => t.id.equals(sessionId))).write(
      TestSessionsCompanion(
        currentIndex: Value(currentIndex),
        remainingSeconds: Value(remainingSeconds),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Soumission definitive : correction locale puis certification (§12, §13).
  ///
  /// Les réponses ne sont plus modifiables après soumission (§10.3).
  Future<TestResult> submit(String sessionId) async {
    final session = await (_db.select(
      _db.testSessions,
    )..where((t) => t.id.equals(sessionId))).getSingleOrNull();
    if (session == null) throw StateError('Session introuvable');

    if (TestSessionStatus.fromCode(session.status).isFinished) {
      final existing = await result(sessionId);
      if (existing != null) return existing;
    }

    final questions = await _questions(session.testId);
    final answers = await (_db.select(
      _db.testAnswers,
    )..where((t) => t.sessionId.equals(sessionId))).get();

    final testRow = await (_db.select(
      _db.tests,
    )..where((t) => t.id.equals(session.testId))).getSingle();

    final scored = TestScoring.score(
      questions: [
        for (final q in questions)
          ScorableQuestion(
            id: q.id,
            correctKey: q.correctKey,
            domain: q.domain,
          ),
      ],
      answers: {for (final a in answers) a.questionId: a.answerKey},
      passingScore: testRow.passingScore,
    );

    await _db.transaction(() async {
      await (_db.update(
        _db.testSessions,
      )..where((t) => t.id.equals(sessionId))).write(
        TestSessionsCompanion(
          status: Value(TestSessionStatus.scored.code),
          submittedAt: Value(DateTime.now()),
          score: Value(scored.score),
          passed: Value(scored.passed),
          domainScoresJson: Value(scored.domainScoresJson),
          updatedAt: Value(DateTime.now()),
          dirty: const Value(true),
        ),
      );

      // La certification n'est delivree qu'au-dessus du seuil (§12, §13).
      if (scored.passed) {
        await _db
            .into(_db.teacherCertifications)
            .insertOnConflictUpdate(
              TeacherCertificationsCompanion.insert(
                id: '${session.teacherId}_${testRow.subjectId}_${testRow.levelId}',
                teacherId: session.teacherId,
                subjectId: testRow.subjectId,
                levelId: testRow.levelId,
                score: scored.score,
                sessionId: Value(sessionId),
                domainScoresJson: Value(scored.domainScoresJson),
                issuedAt: Value(DateTime.now()),
                dirty: const Value(true),
              ),
            );
      }
    });

    await _sync.enqueue(
      entity: 'test_session',
      entityId: sessionId,
      operation: SyncOperation.update,
      payload: {
        'status': TestSessionStatus.submitted.code,
        'answers': {for (final a in answers) a.questionId: a.answerKey},
        'clientScore': scored.score,
      },
    );

    return scored;
  }

  /// Résultat d'une session déjà corrigee.
  Future<TestResult?> result(String sessionId) async {
    final session = await (_db.select(
      _db.testSessions,
    )..where((t) => t.id.equals(sessionId))).getSingleOrNull();
    if (session == null || session.score == null) return null;

    final testRow = await (_db.select(
      _db.tests,
    )..where((t) => t.id.equals(session.testId))).getSingle();

    final answers = await (_db.select(
      _db.testAnswers,
    )..where((t) => t.sessionId.equals(sessionId))).get();

    final answered = answers
        .where((a) => a.answerKey != null && a.answerKey!.isNotEmpty)
        .length;
    final domains = TestResult.parseDomainScores(session.domainScoresJson);

    return TestResult(
      score: session.score!,
      correctCount: (session.score! * testRow.questionCount / 100).round(),
      totalQuestions: testRow.questionCount,
      answeredCount: answered,
      domainScores: domains,
      passed: session.passed ?? false,
      passingScore: testRow.passingScore,
    );
  }

  /// Detail des réponses, pour l'écran « Voir le detail ».
  Future<List<({TestQuestion question, String? given, bool correct})>>
  reviewAnswers(String sessionId) async {
    final session = await (_db.select(
      _db.testSessions,
    )..where((t) => t.id.equals(sessionId))).getSingleOrNull();
    if (session == null) return const [];

    final questions = await _questions(session.testId);
    final answers = await (_db.select(
      _db.testAnswers,
    )..where((t) => t.sessionId.equals(sessionId))).get();

    return [
      for (final q in questions)
        (
          question: q,
          given: answers
              .where((a) => a.questionId == q.id)
              .firstOrNull
              ?.answerKey,
          correct:
              answers
                  .where((a) => a.questionId == q.id)
                  .firstOrNull
                  ?.answerKey ==
              q.correctKey,
        ),
    ];
  }

  /// Abandon d'une session en cours.
  Future<void> abandon(String sessionId) async {
    await (_db.update(
      _db.testSessions,
    )..where((t) => t.id.equals(sessionId))).write(
      TestSessionsCompanion(
        status: Value(TestSessionStatus.abandoned.code),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Historique des sessions passees.
  Future<
    List<
      ({String sessionId, String title, int? score, bool passed, DateTime date})
    >
  >
  history(String teacherId) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT ts.id, ts.score, ts.passed, ts.submitted_at, ts.created_at,
                 t.title
          FROM test_sessions ts
          JOIN tests t ON t.id = ts.test_id
          WHERE ts.teacher_id = ?1 AND ts.status IN ('SCORED', 'SUBMITTED')
          ORDER BY ts.submitted_at DESC
          ''',
          variables: [Variable<String>(teacherId)],
          readsFrom: {_db.testSessions, _db.tests},
        )
        .get();

    return [
      for (final row in rows)
        (
          sessionId: row.read<String>('id'),
          title: row.read<String>('title'),
          score: row.read<int?>('score'),
          passed: row.read<bool?>('passed') ?? false,
          date:
              row.read<DateTime?>('submitted_at') ??
              row.read<DateTime>('created_at'),
        ),
    ];
  }
}
