import '../../core/curriculum/stages.dart';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/guinea_geography.dart';
import '../../domain/entities/onboarding_spec.dart';
import '../providers/core_providers.dart';

/// Parcours disponibles.
enum OnboardingAudience {
  /// Choix du profil. Ouvre l'inscription.
  intro('intro'),

  /// Écrans de présentation, montrés **après** la création du compte :
  /// on ouvre le compte, puis on explique. Conditionnés par le rôle, qui
  /// arrive en réponse initiale.
  presentation('presentation'),
  teacher('teacher_onboarding'),
  institution('institution_onboarding'),
  parent('parent_onboarding'),
  student('student_onboarding');

  const OnboardingAudience(this.asset);
  final String asset;

  String get path => 'assets/onboarding/$asset.json';

  /// Parcours correspondant au profil choisi dans `intro`.
  static OnboardingAudience? forRole(Object? role) => switch (role) {
    'TEACHER' => OnboardingAudience.teacher,
    'INSTITUTION' => OnboardingAudience.institution,
    'PARENT' => OnboardingAudience.parent,
    'STUDENT' => OnboardingAudience.student,
    _ => null,
  };

  /// Le profil reel, derriere la carte choisie.
  ///
  /// « Parent d'eleve » et « Universitaire » ont fusionne en une seule
  /// carte, `FAMILY`, suivie de la question « Etes-vous parent ? ». Ce code
  /// ne vit que le temps du choix : il n'est ecrit ni dans `profiles.role`
  /// ni nulle part ailleurs, parce que `PARENT` et `STUDENT` restent deux
  /// roles distincts dans les politiques RLS — un parent voit les seances
  /// de ses enfants, un etudiant majeur voit les siennes.
  ///
  /// **Jumelle de `roleReel` du client web** (`src/onboarding/Signup.tsx`).
  /// Sans elle, `forRole('FAMILY')` rendait `null`, l'ecran retournait en
  /// silence, et le bouton « Continuer » ne faisait rien.
  static String roleReel(Map<String, dynamic> reponses) {
    final choisi = reponses['role'];
    if (choisi != 'FAMILY') return choisi as String;
    return reponses['is_parent'] == 'yes' ? 'PARENT' : 'STUDENT';
  }
}

/// Decoupage administratif, charge une seule fois.
///
/// `keepAlive` : la liste sert a plusieurs champs du meme ecran et ne change
/// jamais pendant une session — la relire a chaque reconstruction ferait
/// clignoter les listes deroulantes.
final guineaGeographyProvider = FutureProvider<GuineaGeography>((ref) async {
  ref.keepAlive();
  final raw = await rootBundle.loadString(GuineaGeography.asset);
  return GuineaGeography.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});

/// Charge la description du parcours depuis l'asset partage.
final onboardingSpecProvider =
    FutureProvider.family<OnboardingFlowSpec, OnboardingAudience>((
      ref,
      audience,
    ) async {
      final raw = await rootBundle.loadString(audience.path);
      return OnboardingFlowSpec.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    });

/// Listes du referentiel utilisables par `optionsSource`.
///
/// Le JSON ne fige jamais une liste susceptible d'evoluer en back-office
/// (§9) : il y fait référence par un nom, resolu ici.
final onboardingOptionsProvider =
    FutureProvider.family<List<OnboardingOption>, String>((ref, source) async {
      final catalog = ref.watch(catalogRepositoryProvider);

      switch (source) {
        case 'subjects':
          final items = await catalog.subjects();
          // Chaque matiere porte ses cycles ET les profils de lycee qui la
          // contiennent. Les deux familles ne se confondent pas : filtrer
          // sur `LYCEE` ne retient jamais un profil, et filtrer sur
          // `fil_soc` ne retient jamais un cycle.
          final filieres = await catalog.filieres();
          final byFiliere = <String, Set<String>>{};
          for (final f in filieres) {
            for (final id in f.subjectIds.split(',')) {
              if (id.isEmpty) continue;
              byFiliere.putIfAbsent(id, () => {}).add(f.id);
            }
          }

          // Les classes couvertes par au moins un profil : a partir de la
          // 12eme, le programme depend du profil et non plus du seul cycle.
          final parProfil = <String, Set<String>>{};
          for (final f in filieres) {
            for (final niveau in f.levelIds.split(',')) {
              if (niveau.isEmpty) continue;
              for (final id in f.subjectIds.split(',')) {
                if (id.isEmpty) continue;
                parProfil.putIfAbsent(niveau, () => {}).add(id);
              }
            }
          }

          // La classe ou chaque matiere s'enseigne.
          //
          // Sans cela, un filtre pose sur `level_ids` ne retient rien : les
          // matieres ne portaient que leur cycle, et « lvl_11 » ne figure
          // dans aucun cycle. C'est ce qui bloquait l'inscription d'un
          // professeur a l'etape des matieres, le 24/09.
          //
          // `catalog.levels()` ecarte deja les en-tetes de cycle : « Lycee »
          // n'est pas une classe a cocher.
          final byLevel = <String, Set<String>>{};
          for (final niveau in await catalog.levels()) {
            final duProfil = parProfil[niveau.id];
            for (final s in items) {
              final enseignee = duProfil != null
                  ? duProfil.contains(s.id)
                  : s.cycles.any(niveau.cycles.contains);
              if (enseignee) {
                byLevel.putIfAbsent(s.id, () => {}).add(niveau.id);
              }
            }
          }

          return [
            for (final s in items)
              OnboardingOption(
                value: s.id,
                label: s.name,
                // Cycle, profil de lycee et classes : trois familles qui ne
                // se confondent pas. Filtrer sur « LYCEE » ne retient jamais
                // un profil, et filtrer sur « lvl_11 » jamais un cycle.
                groups: [...s.cycles, ...?byFiliere[s.id], ...?byLevel[s.id]],
              ),
          ];

        case 'stages':
          // Les cinq paliers. L'identifiant EST la valeur de `cycle` d'un
          // niveau, donc l'etape suivante les apparie sans correspondance a
          // tenir.
          final paliers = await loadStages();
          return [
            for (final p in paliers)
              OnboardingOption(value: p.id, label: p.name, description: p.note),
          ];

        case 'filieres':
          // Les trois profils du second cycle. `groups` porte les classes
          // concernees, pour ne proposer le profil qu'a partir de la 12eme.
          final items = await catalog.filieres();
          return [
            for (final f in items)
              OnboardingOption(
                value: f.id,
                label: f.name,
                description: f.note.isEmpty ? null : f.note,
                groups: f.levelIds
                    .split(',')
                    .where((s) => s.isNotEmpty)
                    .toList(),
              ),
          ];

        case 'levels':
          final items = await catalog.levels();
          return [
            for (final l in items)
              OnboardingOption(
                value: l.id,
                label: l.name,
                // Le cycle permet a `optionsFilter` de ne montrer que les
                // classes du cycle enseigne — college et lycee compris, ce
                // que la categorie ne distingue pas.
                groups: l.cycles,
              ),
          ];

        case 'institution_roles':
          // Qui inscrit l'etablissement : la responsabilite d'un compte
          // engage une personne, pas une adresse.
          return const [
            OnboardingOption(
              value: 'DIRECTOR',
              label: 'Directeur / Directrice',
            ),
            OnboardingOption(value: 'FOUNDER', label: 'Fondateur / Fondatrice'),
            OnboardingOption(
              value: 'PEDAGOGY',
              label: 'Responsable pédagogique',
            ),
            OnboardingOption(
              value: 'ADMIN',
              label: 'Responsable administratif',
            ),
            OnboardingOption(
              value: 'HR',
              label: 'Responsable des ressources humaines',
            ),
            OnboardingOption(value: 'OTHER', label: 'Autre fonction'),
          ];

        case 'regions':
          // Les 10 regions administratives. La valeur enregistree est le
          // code : les noms bougent moins que les decoupages, mais un code
          // ne bouge pas du tout.
          final geography = await ref.watch(guineaGeographyProvider.future);
          return [
            for (final region in geography.regions)
              OnboardingOption(
                value: region.code,
                label: region.name,
                description: region.isSpecial
                    ? 'Region speciale, decoupee en communes'
                    : null,
              ),
          ];

        case 'prefectures':
          // Prefectures, ou communes pour Conakry. `groups` porte le code de
          // la region : c'est lui que `optionsFilter` compare a la reponse
          // precedente pour ne montrer que les subdivisions de la region
          // choisie.
          final geography = await ref.watch(guineaGeographyProvider.future);
          return [
            for (final division in geography.divisions)
              OnboardingOption(
                value: division.name,
                label: division.name,
                description: division.recent ? 'Prefecture recente' : null,
                groups: [division.regionCode],
              ),
          ];

        case 'cities':
          final cities = await catalog.cities();
          return [for (final c in cities) OnboardingOption(value: c, label: c)];

        case 'countries':
          // La cible initiale est la Guinée (§1) ; la liste s'etendra avec le
          // deploiement regional.
          return const [
            OnboardingOption(value: 'GN', label: 'Guinée'),
            OnboardingOption(value: 'SN', label: 'Senegal'),
            OnboardingOption(value: 'ML', label: 'Mali'),
            OnboardingOption(value: 'CI', label: 'Cote d’Ivoire'),
          ];

        case 'institutions':
          final institutions = await catalog.institutions();
          return [
            for (final i in institutions)
              OnboardingOption(value: i.id, label: i.name),
          ];

        default:
          return const [];
      }
    });

/// État d'avancement du parcours.
class OnboardingFlowState {
  const OnboardingFlowState({
    required this.spec,
    this.index = 0,
    this.answers = const {},
  });

  final OnboardingFlowSpec spec;
  final int index;

  /// Réponses indexees par `fieldId` — même forme que celle attendue par le
  /// front React, afin qu'un parcours entame sur un support puisse etre
  /// repris sur l'autre.
  final Map<String, dynamic> answers;

  /// Les étapes réellement parcourues, conditions appliquées.
  List<OnboardingStep> get visible => spec.visibleSteps(answers);

  /// Une réponse peut retirer des étapes : on ne sort jamais de la liste.
  int get position {
    final last = visible.length - 1;
    return index > last ? (last < 0 ? 0 : last) : index;
  }

  OnboardingStep get step => visible[position];
  OnboardingSection get section => spec.sectionOfStep(step);

  int get total => visible.length;
  bool get isLast => position >= total - 1;
  bool get isFirst => position == 0;
  double get progress => total == 0 ? 0 : (position + 1) / total;

  /// La question courante est-elle satisfaite ?
  bool get canContinue {
    final current = step;
    if (!current.type.collectsAnswer || current.optional) return true;

    switch (current.type) {
      case StepType.form:
        for (final field in current.fields) {
          final value = answers[field.id];
          // La longueur minimale se verifie meme sur un champ facultatif :
          // rempli a moitie, il serait refuse apres la creation du compte.
          final minimum = field.minLength;
          if (minimum != null && value is String && value.isNotEmpty) {
            if (value.length < minimum) return false;
          }
          if (!field.required) continue;
          if (value == null || (value is String && value.trim().isEmpty)) {
            return false;
          }
        }
        return true;

      case StepType.multiChoice:
        final selected = answers[current.fieldId] as List<dynamic>? ?? const [];
        return selected.length >=
            (current.minSelected > 0
                ? current.minSelected
                : current.required
                ? 1
                : 0);

      case StepType.singleChoice:
      case StepType.boolean:
      // Sans profil choisi, le parcours suivant n'existe pas.
      case StepType.roleSelect:
        return !current.required || answers[current.fieldId] != null;

      // Le curseur porte toujours une valeur, et une formule peut etre refusée.
      case StepType.range:
      case StepType.planSelect:
        return true;

      // Le depot de documents se passe : c'est la seule etape ou « Passer »
      // subsiste, un candidat n'ayant pas toujours son diplome sous la main.
      case StepType.upload:
        return true;

      // Un jour coche sans heure ne dit rien a une famille : elle saurait
      // que le professeur vient le mardi, sans savoir quand.
      //
      // `minSelected` compte les *jours* renseignes, pas les creneaux : un
      // cours a domicile qui n'aurait qu'un seul jour possible ne trouve
      // presque personne, d'ou le plancher de trois jours sur ce pas-la.
      case StepType.dayHours:
        final slots = answers[current.fieldId] as Map<String, dynamic>?;
        final jours = slots == null
            ? 0
            : slots.values.where((h) => h is List && h.isNotEmpty).length;
        if (current.minSelected > 0) return jours >= current.minSelected;
        if (!current.required) return true;
        return jours >= 1;

      default:
        return true;
    }
  }

  OnboardingFlowState copyWith({int? index, Map<String, dynamic>? answers}) =>
      OnboardingFlowState(
        spec: spec,
        index: index ?? this.index,
        answers: answers ?? this.answers,
      );
}

/// Pilote un parcours décrit par un [OnboardingFlowSpec].
class OnboardingFlowController extends StateNotifier<OnboardingFlowState> {
  OnboardingFlowController(OnboardingFlowSpec spec)
    : super(OnboardingFlowState(spec: spec, answers: _defaults(spec)));

  /// Valeurs initiales declarees dans le JSON (`default`).
  static Map<String, dynamic> _defaults(OnboardingFlowSpec spec) {
    final values = <String, dynamic>{};
    for (final step in spec.steps) {
      if (step.defaultValue != null && step.fieldId != null) {
        values[step.fieldId!] = step.defaultValue;
      }
      for (final field in step.fields) {
        if (field.defaultValue != null) values[field.id] = field.defaultValue;
      }
    }
    return values;
  }

  /// Verse les réponses d'un parcours precedent sans ecraser celles deja
  /// saisies ici : la découverte alimente le parcours du profil.
  void seed(Map<String, dynamic> answers) {
    if (answers.isEmpty) return;
    state = state.copyWith(answers: {...answers, ...state.answers});
  }

  void setAnswer(String fieldId, dynamic value) {
    state = state.copyWith(answers: {...state.answers, fieldId: value});
  }

  /// Renseigne un champ et efface ceux qui en dependent.
  ///
  /// Sans cela, changer la region apres avoir choisi « Ratoma » garderait
  /// « Ratoma » dans les reponses : la liste ne l'affiche plus, mais c'est
  /// bien elle qui partirait en base. [dependents] sont les champs dont la
  /// liste est filtree par [fieldId].
  void setAnswerAndClear(
    String fieldId,
    dynamic value, {
    required Iterable<String> dependents,
  }) {
    final answers = {...state.answers, fieldId: value};
    for (final dependent in dependents) {
      answers.remove(dependent);
    }
    state = state.copyWith(answers: answers);
  }

  /// Bascule une valeur dans une selection multiple.
  void toggleMulti(String fieldId, String value, {String? allValue}) {
    final current = List<String>.from(
      (state.answers[fieldId] as List<dynamic>? ?? const []).cast<String>(),
    );

    // « Toutes les matières » et une selection nominative s'excluent.
    if (allValue != null) {
      if (value == allValue) {
        setAnswer(
          fieldId,
          current.contains(allValue) ? <String>[] : [allValue],
        );
        return;
      }
      current.remove(allValue);
    }

    if (current.contains(value)) {
      current.remove(value);
    } else {
      current.add(value);
    }
    setAnswer(fieldId, current);
  }

  bool isSelected(String fieldId, String value) {
    final answer = state.answers[fieldId];
    if (answer is List) return answer.contains(value);
    return answer == value;
  }

  void next() {
    if (state.isLast) return;
    state = state.copyWith(index: state.position + 1);
  }

  void back() {
    if (state.isFirst) return;
    state = state.copyWith(index: state.position - 1);
  }

  /// Réponses collectees, pretes a etre transmises ou converties en profil.
  Map<String, dynamic> get answers => Map.unmodifiable(state.answers);
}

final onboardingFlowProvider = StateNotifierProvider.autoDispose
    .family<OnboardingFlowController, OnboardingFlowState, OnboardingFlowSpec>(
      (ref, spec) => OnboardingFlowController(spec),
    );
