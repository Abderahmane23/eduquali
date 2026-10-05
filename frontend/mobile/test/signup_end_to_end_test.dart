import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/core/security/secure_store.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/local/seed/database_seeder.dart';
import 'package:veriprof/core/network/api_client.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/sync/sync_engine.dart';
import 'package:veriprof/domain/entities/onboarding_spec.dart';
import 'package:veriprof/presentation/controllers/onboarding_flow_controller.dart';
import 'package:veriprof/presentation/providers/core_providers.dart';
import 'package:veriprof/presentation/screens/onboarding/signup_completion.dart';

/// L'inscription, de bout en bout, comme sur l'APK.
///
/// Le testeur du 20/09 rapporte « l'inscription ne marche pas du tout ». Les
/// tests existants vérifiaient les morceaux ; celui-ci refait le trajet
/// complet — parcourir le JSON, répondre à chaque question obligatoire,
/// créer le compte — sur la base réellement semée.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await DatabaseSeeder(db).seedIfNeeded();

    final network = NetworkStatusService();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureStoreProvider.overrideWithValue(SecureStore()),
        networkServiceProvider.overrideWithValue(network),
        syncEngineProvider.overrideWithValue(
          SyncEngine(
            database: db,
            network: network,
            api: SyncApi(buildApiClient(() async => null)),
            deviceId: 'test',
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  OnboardingFlowSpec load(String name) => OnboardingFlowSpec.fromJson(
    jsonDecode(File('assets/onboarding/$name.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  void answerSteps(
    List<OnboardingStep> steps,
    Map<String, dynamic> answers,
    List<Map<String, dynamic>> regions,
    List<LevelRow> levels,
    List<SubjectRow> subjects,
    List<FiliereRow> filieres,
  ) {
    /*
     * Une vraie classe, et le palier qui va avec.
     *
     * Le palier était répondu « OUI » — la branche par défaut, faute de savoir
     * quoi faire d'`optionsSource: 'stages'`. Or l'étape « En quelle classe ? »
     * ne s'affiche que si le palier vaut COLLEGE, LYCEE ou SUPERIEUR : elle
     * restait donc invisible, la classe n'était jamais répondue, et le parcours
     * passait quand même puisqu'une étape cachée n'a rien à valider.
     *
     * Les deux réponses doivent s'accorder, sinon `optionsFilter` ne propose
     * aucune classe du palier choisi.
     */
    final classe = levels.firstWhere(
      (l) => !l.grouping && l.cycle.isNotEmpty,
      orElse: () => levels.first,
    );

    for (final step in steps) {
      switch (step.type) {
        case StepType.form:
          for (final field in step.fields) {
            if (!field.required) continue;
            // Un champ qui porte ses propres options est une liste
            // déroulante : y écrire « Valeur work_days » n'est pas une
            // réponse qu'on puisse donner à l'écran, et le code qui la relit
            // a raison de la refuser. On choisit donc la première option,
            // comme le ferait un doigt.
            if (field.options.isNotEmpty) {
              answers[field.id] = field.options.first.value;
              continue;
            }
            answers[field.id] = switch (field.id) {
              'region' => regions.first['code'],
              'city' => (regions.first['divisions'] as List).first['name'],
              'country' => 'GN',
              'phone' => '620000001',
              // Les heures sont lues telles quelles : un texte quelconque
              // passerait, mais ne ressemblerait pas à ce qui sera stocké.
              'work_start' => '08:00',
              'work_end' => '17:00',
              _ => 'Valeur ${field.id}',
            };
          }
        case StepType.singleChoice:
          answers[step.fieldId!] = switch (step.optionsSource) {
            'stages' => classe.cycle,
            'levels' => classe.id,
            'subjects' => subjects.first.id,
            'filieres' => filieres.first.id,
            _ => step.options.isNotEmpty ? step.options.first.value : 'OUI',
          };
        case StepType.multiChoice:
          answers[step.fieldId!] = switch (step.optionsSource) {
            'levels' => [levels.first.id],
            'subjects' => [subjects.first.id],
            _ => [
              if (step.options.isNotEmpty)
                step.options.first.value
              else
                'LYCEE',
            ],
          };
        case StepType.boolean:
          answers[step.fieldId!] = true;
        case StepType.range:
          answers[step.fieldId!] = step.min;
        case StepType.upload:
          // Depot facultatif : on depose quand meme, pour que le parcours
          // soit parcouru tel qu'un professeur equipe le vivrait.
          for (final upload in step.uploads) {
            answers[upload.id] = '${upload.id}.pdf';
          }
        case StepType.dayHours:
          // Trois jours, un creneau chacun : le minimum qu'exige la regle
          // des cours a domicile.
          answers[step.fieldId!] = {
            'MON': ['EVENING'],
            'WED': ['EVENING'],
            'FRI': ['EVENING'],
          };
        default:
          break;
      }
    }
  }

  /// Les réponses qu'un utilisateur donnerait en parcourant l'écran.
  ///
  /// On ne devine pas : chaque valeur vient du référentiel réellement semé,
  /// comme la liste déroulante l'aurait proposée.
  Future<Map<String, dynamic>> answerEverything(
    OnboardingFlowSpec spec, {
    Map<String, dynamic> seed = const {},
  }) async {
    final answers = <String, dynamic>{...seed};
    final geography =
        jsonDecode(File('assets/geography/guinea.json').readAsStringSync())
            as Map<String, dynamic>;
    final regions = (geography['regions'] as List).cast<Map<String, dynamic>>();

    final levels = await db.select(db.levels).get();
    final subjects = await db.select(db.subjects).get();
    final filieres = await db.select(db.filieres).get();

    // Repondre fait apparaitre de nouvelles etapes : « Dans quel
    // etablissement ? » n'existe qu'une fois « il a deja une ecole » coche.
    // On recommence donc tant que la liste bouge.
    var seen = <String>{};
    for (var tour = 0; tour < 10; tour++) {
      final steps = spec.visibleSteps(answers);
      final ids = steps.map((s) => s.id).toSet();
      if (ids.difference(seen).isEmpty) break;
      seen = ids;
      answerSteps(steps, answers, regions, levels, subjects, filieres);
    }
    return answers;
  }

  // STUDENT manquait à cette liste, et c'est ce qui a laissé passer tout le
  // reste : son parcours n'était jamais joué de bout en bout.
  for (final role in ['TEACHER', 'INSTITUTION', 'PARENT', 'STUDENT']) {
    final asset = switch (role) {
      'TEACHER' => 'teacher_onboarding',
      'INSTITUTION' => 'institution_onboarding',
      'STUDENT' => 'student_onboarding',
      _ => 'parent_onboarding',
    };

    test('$role : chaque question obligatoire est répondable', () async {
      final spec = load(asset);
      final answers = await answerEverything(spec);

      // `canContinue` est ce qui active le bouton « Continuer ». Si une
      // question reste bloquée, l'inscription s'arrête là, sans message.
      for (var i = 0; i < spec.visibleSteps(answers).length; i++) {
        final state = OnboardingFlowState(
          spec: spec,
          index: i,
          answers: answers,
        );
        expect(
          state.canContinue,
          isTrue,
          reason:
              '« ${state.step.title} » (${state.step.id}) refuse de '
              'continuer alors que tout est répondu',
        );
      }
    });

    test('$role : le compte se crée vraiment', () async {
      final spec = load(asset);
      final answers = await answerEverything(spec);

      final userId = await SignupCompletion(
        container.read(refProvider),
      ).create(role, answers);

      final user = await (db.select(
        db.users,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();
      expect(user, isNotNull, reason: 'aucun compte créé pour $role');
      expect(user!.role, role);
      expect(user.phone, startsWith('+224'));
    });
  }

  /// L'apprenant enregistré porte-t-il ce qu'on vient de demander ?
  ///
  /// L'ancienne version ne vérifiait que `firstName.isNotEmpty`, et c'est pour
  /// cela qu'elle ne disait rien : le niveau, le profil et les matières
  /// pouvaient tous être nuls, la ligne existait quand même. Un contrôle qui
  /// passe pour une raison plus faible que celle qu'on croit.
  for (final (role, asset) in [
    ('PARENT', 'parent_onboarding'),
    ('STUDENT', 'student_onboarding'),
  ]) {
    test(
      '$role : l’apprenant déclaré porte son niveau et ses matières',
      () async {
        final spec = load(asset);
        final answers = await answerEverything(spec);

        final completion = SignupCompletion(container.read(refProvider));
        final userId = await completion.create(role, answers);
        await completion.attachLearner(role, userId, answers);

        final learners = await db.select(db.children).get();
        expect(
          learners,
          hasLength(1),
          reason: role == 'STUDENT'
              // Le défaut d'origine : `attachChild` exigeait `child_first_name`,
              // que le parcours universitaire ne produit pas. Le compte sortait
              // sans aucun apprenant, donc sans niveau et sans matière.
              ? 'un universitaire est lui-même l’élève : il lui faut sa ligne'
              : 'l’enfant déclaré n’a pas été enregistré',
        );

        final learner = learners.single;
        expect(learner.firstName, isNotEmpty);
        expect(
          learner.levelId,
          isNotNull,
          reason:
              'sans niveau, aucun écran ne peut filtrer les professeurs par '
              'cycle — c’est ce qui fait proposer un professeur d’université à '
              'un élève de 7ème',
        );
        expect(
          learner.subjectIds,
          isNotEmpty,
          reason: 'les matières choisies décident des professeurs proposés',
        );
      },
    );
  }

  /// Le professeur garde-t-il ce qu'il vient de déclarer ?
  ///
  /// --- Pourquoi ce contrôle manquait ---------------------------------------
  ///
  /// Le bloc ci-dessus vérifie l'apprenant — le chemin parent/universitaire,
  /// qui fonctionnait. **Rien n'examinait le chemin professeur**, et c'est ce
  /// qui a laissé passer le défaut relevé le 04/10 : `registerTeacher` ne
  /// retenait que l'identité et l'adresse, et sept écrans du parcours
  /// n'étaient lus par personne.
  ///
  /// Le professeur arrivait sur un compte qui ne connaissait ni ses matières
  /// ni ses niveaux. Sa fiche s'affichait sans aucune matière dans la liste
  /// des familles, et il devait ressaisir les mêmes faits dans deux autres
  /// écrans puis dans son offre.
  test('TEACHER : les matières et niveaux déclarés sont enregistrés', () async {
    final spec = load('teacher_onboarding');
    final answers = await answerEverything(spec);

    final completion = SignupCompletion(container.read(refProvider));
    final userId = await completion.create('TEACHER', answers);
    await completion.attachTeacherProfile('TEACHER', userId, answers);

    // La base semée porte déjà des professeurs de démonstration : on ne
    // regarde que la fiche qu'on vient de créer.
    final teacher = (await db.select(db.teachers).get())
        .where((t) => t.userId == userId)
        .single;

    final subjects = await (db.select(
      db.teacherSubjects,
    )..where((t) => t.teacherId.equals(teacher.id))).get();
    expect(
      subjects,
      isNotEmpty,
      reason:
          'sans matière, sa fiche s’affiche avec une ligne de matières vide '
          'dans la liste des familles',
    );

    final levels = await (db.select(
      db.teacherLevels,
    )..where((t) => t.teacherId.equals(teacher.id))).get();
    expect(
      levels,
      isNotEmpty,
      reason:
          'sans niveau déclaré, le filtre par palier le laisse passer pour '
          'tout le monde : il est proposé à un CE2 comme à un étudiant',
    );
    // Les niveaux se déclarent par matière : chacune doit porter les siens.
    expect(
      levels.map((l) => l.subjectId).toSet(),
      subjects.map((s) => s.subjectId).toSet(),
    );

    expect(
      teacher.serviceTypes,
      isNotEmpty,
      reason:
          'ce qu’il cherche — cours à domicile ou poste — oriente tout le '
          'reste de son expérience',
    );
    expect(
      teacher.tutoringHours,
      isNot('{}'),
      reason:
          'l’étape `day_hours` relie un jour à ses créneaux ; c’est pour cela '
          'qu’elle a remplacé deux étapes séparées',
    );
    expect(
      teacher.tutoringDays,
      isNotEmpty,
      reason: 'les colonnes à plat restent dérivées : les offres les lisent',
    );
  });

  /// L'établissement garde-t-il ses critères de recrutement ?
  ///
  /// Neuf de ses dix-sept réponses étaient jetées, dont la totalité de ses
  /// critères. Conséquence : à chaque offre publiée, le formulaire redemandait
  /// la matière, les niveaux et jusqu'à la ville — pourtant obligatoire et
  /// déjà connue.
  test('INSTITUTION : les critères de recrutement sont enregistrés', () async {
    final spec = load('institution_onboarding');
    final answers = await answerEverything(spec);

    final completion = SignupCompletion(container.read(refProvider));
    final userId = await completion.create('INSTITUTION', answers);
    await completion.attachInstitutionNeeds('INSTITUTION', userId, answers);

    final institution = (await db.select(db.institutions).get())
        .where((i) => i.userId == userId)
        .single;

    expect(
      institution.neededSubjectIds,
      isNotEmpty,
      reason: 'les matières cherchées préremplissent la prochaine offre',
    );
    expect(institution.priorities, isNotEmpty);
    expect(
      institution.teacherLocation,
      isNotNull,
      reason:
          'accepter quelqu’un prêt à se rapprocher est la moitié du '
          'rapprochement avec `teachers.mobility`',
    );
    expect(institution.workDays, isNotEmpty);
    expect(institution.maxDistance, isNotNull);
  });

  /// La formule choisie au dernier écran survit-elle à l'inscription ?
  ///
  /// Elle était rangée sous `subscription`, une clé que personne ne lisait :
  /// on choisissait PRO et on obtenait un compte FREE, à rechoisir depuis la
  /// facturation.
  test('la formule choisie est retenue, mais pas accordée', () async {
    final spec = load('teacher_onboarding');
    final answers = await answerEverything(spec);
    answers['subscription'] = 'PRO';

    final completion = SignupCompletion(container.read(refProvider));
    final userId = await completion.create('TEACHER', answers);
    await completion.rememberPlanChoice(userId, answers);

    final user = await (db.select(
      db.users,
    )..where((t) => t.id.equals(userId))).getSingle();

    expect(user.pendingPlan, 'PRO', reason: 'le choix ne doit pas se perdre');
    expect(
      user.plan,
      'FREE',
      reason:
          'rien n’est encaissé à l’inscription : l’écrire dans `plan` '
          'offrirait l’abonnement',
    );
  });
}

/// Un `Ref` utilisable depuis un test.
final refProvider = Provider<Ref>((ref) => ref);
