/// Modèle declaratif des parcours d'inscription.
///
/// Le parcours est decrit dans `assets/onboarding/*.json` et non dans le code :
/// la même description alimente l'application Flutter et le futur front React.
/// Toute évolution du questionnaire se fait dans le JSON, sans recompilation
/// des deux clients, et les réponses produites ont la même forme des deux
/// cotes — un objet plat indexé par `fieldId`.
library;

/// Nature d'un écran. Chaque valeur correspond a un composant de rendu.
enum StepType {
  /// Écran d'accroche avec chiffres cles, sans saisie.
  statement,

  /// Enumeration des étapes du service, sans saisie.
  stepsPreview,

  /// Carrousel de profils mis en avant, sans saisie.
  carousel,

  /// Choix du profil : boutons empiles, une reponse obligatoire.
  roleSelect,

  /// Plusieurs champs regroupes sur un même écran.
  form,

  /// Selection unique parmi des etiquettes.
  singleChoice,

  /// Selection multiple parmi des etiquettes.
  multiChoice,

  /// Oui / Non.
  boolean,

  /// Curseur numérique avec estimation facultative.
  range,

  /// Choix d'une formule payante, refus possible.
  planSelect,

  /// Depot de fichiers (CV, diplome). Seule etape ou « Passer » survit :
  /// un candidat n'a pas toujours son diplome sous la main, et le lui
  /// reclamer avant de l'inscrire le ferait abandonner.
  upload,

  /// Les sept jours empiles ; toucher un jour ouvre ses heures.
  ///
  /// Remplace les deux etapes « jours » puis « moments » : elles posaient
  /// la meme question en deux fois, et rien ne reliait un jour a l'heure
  /// qui lui correspondait.
  dayHours;

  static StepType fromCode(String code) => switch (code) {
    'statement' => StepType.statement,
    'steps_preview' => StepType.stepsPreview,
    'carousel' => StepType.carousel,
    'role_select' => StepType.roleSelect,
    'form' => StepType.form,
    'single_choice' => StepType.singleChoice,
    'multi_choice' => StepType.multiChoice,
    'boolean' => StepType.boolean,
    'range' => StepType.range,
    'plan_select' => StepType.planSelect,
    'upload' => StepType.upload,
    'day_hours' => StepType.dayHours,
    _ => StepType.statement,
  };

  /// Un écran informatif n'attend aucune réponse.
  bool get collectsAnswer => switch (this) {
    StepType.statement || StepType.stepsPreview || StepType.carousel => false,
    _ => true,
  };
}

/// Un fichier attendu par une etape `upload`.
class OnboardingUpload {
  const OnboardingUpload({
    required this.id,
    required this.label,
    this.accept = 'pdf,image',
  });

  final String id;
  final String label;

  /// Types acceptes, separes par des virgules : `pdf`, `image`.
  final String accept;

  factory OnboardingUpload.fromJson(Map<String, dynamic> json) =>
      OnboardingUpload(
        id: json['id'] as String,
        label: json['label'] as String,
        accept: json['accept'] as String? ?? 'pdf,image',
      );
}

/// Nature d'un champ a l'interieur d'un écran `form`.
enum FieldType {
  text,
  phone,
  dropdown,
  combo,
  month,

  /// Saisi masque, avec un oeil pour reveler.
  ///
  /// Pose le 02/10. Sans SMS, le mot de passe est la seule chose qui distingue
  /// le proprietaire d'un numero de quelqu'un qui le connait : jusque-la le
  /// parcours enregistrait un secret local identique pour tout le monde, et un
  /// compte cree sur le telephone ne pouvait meme pas y revenir.
  password;

  static FieldType fromCode(String code) => switch (code) {
    'text' => FieldType.text,
    'phone' => FieldType.phone,
    'dropdown' => FieldType.dropdown,
    'combo' => FieldType.combo,
    'month' => FieldType.month,
    'password' => FieldType.password,
    _ => FieldType.text,
  };
}

/// Option d'une liste de choix.
class OnboardingOption {
  const OnboardingOption({
    required this.value,
    required this.label,
    this.description,
    this.groups = const [],
  });

  final String value;
  final String label;

  /// Ligne d'explication sous le libelle — utilisee par `role_select`.
  final String? description;

  /// Familles auxquelles l'option appartient — pour un niveau ou une
  /// matière, les cycles : `PRIMAIRE`, `COLLEGE`, `LYCEE`, `SUPERIEUR`.
  ///
  /// Une matière appartient souvent à plusieurs cycles (les mathématiques se
  /// font partout), d'où une liste et non une valeur unique. Liste vide =
  /// l'option reste toujours visible.
  final List<String> groups;

  factory OnboardingOption.fromJson(Map<String, dynamic> json) =>
      OnboardingOption(
        value: json['value'].toString(),
        label: json['label'] as String,
        description: json['description'] as String?,
        groups: [
          for (final g in (json['groups'] as List<dynamic>? ?? const []))
            g.toString(),
        ],
      );
}

/// Restreint une liste dynamique selon une réponse précédente.
///
/// Un professeur qui enseigne au collège n'a rien à faire devant les matières
/// du supérieur : lui montrer toute la liste est une charge inutile et une
/// source d'erreur.
///
/// Sans [map], les valeurs de la réponse servent directement de familles
/// autorisées — le cas quand la question porte déjà sur des cycles.
class OptionsFilter {
  const OptionsFilter({required this.fields, this.map});

  /// Un filtre a une seule question — la forme la plus courante.
  ///
  /// Pas `const` : une liste batie a partir d'un parametre ne peut pas
  /// l'etre.
  factory OptionsFilter.on(String field, {Map<String, List<String>>? map}) =>
      OptionsFilter(fields: [field], map: map);

  /// Les questions qui resserrent la liste, appliquées l'une après l'autre.
  ///
  /// Plusieurs, et non une seule, parce que la classe et le profil de lycée
  /// ne disent pas la même chose : la classe vaut pour tout le monde, le
  /// profil n'existe qu'à partir de la 12ᵉ. Filtrer sur la classe seule
  /// proposerait la philosophie à un élève de sciences mathématiques ;
  /// filtrer sur le profil seul ne filtrerait rien au collège.
  ///
  /// Une question sans réponse est ignorée : elle ne peut pas vider la liste.
  final List<String> fields;

  final Map<String, List<String>>? map;

  /// La première question du filtre. Gardée pour les appels qui n'en lisent
  /// qu'une.
  String get field => fields.first;

  factory OptionsFilter.fromJson(Map<String, dynamic> json) => OptionsFilter(
    fields: json['fields'] == null
        ? [json['field'] as String]
        : [for (final f in json['fields'] as List) f.toString()],
    map: json['map'] == null
        ? null
        : {
            for (final entry in (json['map'] as Map<String, dynamic>).entries)
              entry.key: [for (final v in entry.value as List) v.toString()],
          },
  );

  /// Les options retenues compte tenu des réponses déjà données.
  List<OnboardingOption> apply(
    List<OnboardingOption> options,
    Map<String, Object?> answers,
  ) {
    var retenues = options;
    for (final f in fields) {
      retenues = _applyOne(retenues, answers, f);
    }
    return retenues;
  }

  List<OnboardingOption> _applyOne(
    List<OnboardingOption> options,
    Map<String, Object?> answers,
    String field,
  ) {
    final given = answers[field];
    if (given == null) return options;

    final values = [
      for (final v in given is List ? given : [given]) v.toString(),
    ];
    if (values.isEmpty) return options;

    final allowed = map == null
        ? values
        : [for (final v in values) ...?map![v]];
    // Réponse non listée : mieux vaut tout montrer que rien.
    if (allowed.isEmpty) return options;

    return [
      for (final option in options)
        if (option.groups.isEmpty || option.groups.any(allowed.contains))
          option,
    ];
  }
}

/// Chiffre cle affiche sur un écran d'accroche.
class OnboardingHighlight {
  const OnboardingHighlight({required this.value, required this.label});

  final String value;
  final String label;

  factory OnboardingHighlight.fromJson(Map<String, dynamic> json) =>
      OnboardingHighlight(
        value: json['value'] as String,
        label: json['label'] as String,
      );
}

/// Formule proposee sur l'écran de paiement.
class OnboardingPlan {
  const OnboardingPlan({
    required this.value,
    required this.name,
    required this.price,
    required this.highlight,
    this.recommended = false,
  });

  final String value;
  final String name;
  final double price;
  final String highlight;
  final bool recommended;

  factory OnboardingPlan.fromJson(Map<String, dynamic> json) => OnboardingPlan(
    value: json['value'] as String,
    name: json['name'] as String,
    price: (json['price'] as num).toDouble(),
    highlight: json['highlight'] as String,
    recommended: json['recommended'] as bool? ?? false,
  );
}

/// Champ d'un écran `form`.
class OnboardingField {
  const OnboardingField({
    required this.id,
    required this.type,
    required this.label,
    this.required = false,
    this.autofocus = false,
    this.allowCustom = false,
    this.options = const [],
    this.optionsSource,
    this.optionsFilter,
    this.dependsOn,
    this.prefixSource,
    this.defaultValue,
    this.nullableLabel,
    this.hint,
    this.minLength,
  });

  final String id;
  final FieldType type;
  final String label;
  final bool required;
  final bool autofocus;

  /// Ligne d'aide sous le champ.
  final String? hint;

  /// Longueur minimale. Verifiee par le parcours, donc le bouton reste
  /// desactive tant qu'elle n'est pas atteinte — plutot qu'un refus apres
  /// l'envoi, quand le compte est deja cree.
  final int? minLength;

  /// Autorise une valeur libre en plus de la liste (établissement absent).
  final bool allowCustom;

  /// Référence vers une liste du referentiel : `subjects`, `levels`, `cities`…
  /// Options ecrites directement dans le parcours.
  ///
  /// Pour une liste courte et fixe — trois rythmes de semaine — qui n'a
  /// pas besoin d'une source nommee dans le code. Une source reste
  /// preferable des que la liste vient du referentiel.
  final List<OnboardingOption> options;

  final String? optionsSource;

  /// Restreint la liste en fonction d'une réponse déjà donnée — c'est ce
  /// qui fait la cascade région → préfecture : les communes de Conakry ne
  /// s'affichent pas pour un professeur de Labé.
  final OptionsFilter? optionsFilter;

  /// Champ dont depend la liste d'options (ville dependante du pays).
  final String? dependsOn;

  /// Champ fournissant l'indicatif telephonique.
  final String? prefixSource;

  final String? defaultValue;

  /// Libelle de la case « pas de valeur » (« En poste »).
  final String? nullableLabel;

  factory OnboardingField.fromJson(Map<String, dynamic> json) =>
      OnboardingField(
        id: json['id'] as String,
        type: FieldType.fromCode(json['type'] as String),
        label: json['label'] as String,
        required: json['required'] as bool? ?? false,
        autofocus: json['autofocus'] as bool? ?? false,
        allowCustom: json['allowCustom'] as bool? ?? false,
        options: [
          for (final o in (json['options'] as List? ?? const []))
            OnboardingOption.fromJson(o as Map<String, dynamic>),
        ],
        optionsSource: json['optionsSource'] as String?,
        optionsFilter: json['optionsFilter'] == null
            ? null
            : OptionsFilter.fromJson(
                json['optionsFilter'] as Map<String, dynamic>,
              ),
        dependsOn: json['dependsOn'] as String?,
        prefixSource: json['prefixSource'] as String?,
        defaultValue: json['default']?.toString(),
        nullableLabel: json['nullableLabel'] as String?,
        hint: json['hint'] as String?,
        minLength: json['minLength'] as int?,
      );
}

/// Estimation dérivée d'une valeur numérique (temps de trajet).
class RangeEstimate {
  const RangeEstimate({required this.kind, required this.minutesPerUnit});

  final String kind;
  final double minutesPerUnit;

  factory RangeEstimate.fromJson(Map<String, dynamic> json) => RangeEstimate(
    kind: json['kind'] as String,
    minutesPerUnit: (json['minutesPerUnit'] as num).toDouble(),
  );

  /// « environ 20 min » pour 5 km.
  String describe(double value) {
    final minutes = (value * minutesPerUnit).round();
    if (minutes <= 0) return 'sur place';
    if (minutes < 60) return 'environ $minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0
        ? 'environ ${hours}h'
        : 'environ ${hours}h${rest.toString().padLeft(2, '0')}';
  }
}

/// Illustration d'une étape.
///
/// [alt] n'est pas décoratif : c'est ce qu'un lecteur d'écran annonce à la
/// place de l'image (§7 du design_skill).
class OnboardingIllustration {
  const OnboardingIllustration({required this.name, required this.alt});

  final String name;
  final String alt;

  /// Chemin de l'asset. Les fichiers sont générés à la hauteur d'affichage
  /// par `shared/onboarding/sync.mjs`, en `@2x` pour les écrans denses.
  String get asset => 'assets/img/$name@2x.webp';

  factory OnboardingIllustration.fromJson(Map<String, dynamic> json) =>
      OnboardingIllustration(
        name: json['name'] as String,
        alt: json['alt'] as String? ?? '',
      );
}

/// Condition d'affichage d'une étape.
///
/// « Montre cet écran seulement si la réponse [field] vaut [equals] ». Sans
/// cela, un élève déjà scolarisé devait répondre aux questions de celui qui
/// cherche un établissement, et inversement.
class ShowIf {
  const ShowIf({required this.field, required this.values});

  final String field;
  final List<String> values;

  factory ShowIf.fromJson(Map<String, dynamic> json) {
    final raw = json['equals'];
    return ShowIf(
      field: json['field'] as String,
      values: raw is List
          ? [for (final v in raw) v.toString()]
          : [raw.toString()],
    );
  }

  /// La comparaison se fait sur la forme texte : un JSON partagé par deux
  /// clients ne garantit pas qu'un « oui » arrive en booléen des deux côtés.
  ///
  /// Une réponse multiple est vraie dès qu'un de ses éléments correspond.
  /// Sans cela, conditionner un écran sur « a choisi les cours à domicile »
  /// comparait la liste entière — `[HOME, FULL_TIME]` — à `HOME`, et l'écran
  /// ne s'affichait jamais. Rien ne le signalait : une étape absente ne lève
  /// pas d'erreur, elle manque.
  bool matches(Object? answer) {
    if (answer == null) return false;
    if (answer is List) {
      return answer.any((v) => values.contains(v.toString()));
    }
    return values.contains(answer.toString());
  }
}

/// Un écran du parcours.
class OnboardingStep {
  const OnboardingStep({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.image,
    this.showIf,
    this.fieldId,
    this.fields = const [],
    this.options = const [],
    this.highlights = const [],
    this.plans = const [],
    this.items = const [],
    this.optionsSource,
    this.optionsFilter,
    this.uploads = const [],
    this.itemsSource,
    this.allOption,
    this.searchable = false,
    this.searchHint,
    this.required = false,
    this.optional = false,
    this.minSelected = 0,
    this.min = 0,
    this.max = 100,
    this.stepSize = 1,
    this.defaultValue,
    this.unit,
    this.estimate,
    this.cta,
    this.declineLabel,
    this.declineValue,
  });

  final String id;
  final StepType type;
  final String title;

  /// Paragraphe d'explication sous le titre.
  final String? body;

  /// Illustration posée au-dessus du titre.
  final OnboardingIllustration? image;

  /// Étape conditionnelle : absente du parcours si la condition est fausse.
  final ShowIf? showIf;

  /// Cle sous laquelle la réponse est enregistree.
  final String? fieldId;

  final List<OnboardingField> fields;
  final List<OnboardingOption> options;
  final List<OnboardingHighlight> highlights;
  final List<OnboardingPlan> plans;
  final List<String> items;

  final String? optionsSource;

  /// Restreint [optionsSource] selon une réponse déjà donnée.
  final OptionsFilter? optionsFilter;

  final String? itemsSource;

  /// Les fichiers demandes par une etape `upload`.
  final List<OnboardingUpload> uploads;

  /// Les champs dont la liste dépend de [fieldId], de proche en proche :
  /// région → préfecture → (demain) quartier.
  ///
  /// Changer la région après avoir choisi « Ratoma » doit effacer
  /// « Ratoma » : la liste ne l'affiche plus, mais sans cela c'est bien elle
  /// qui partirait en base.
  Set<String> dependentFields(String fieldId) {
    final found = <String>{};
    var frontier = {fieldId};
    while (frontier.isNotEmpty) {
      final next = <String>{
        for (final field in fields)
          if (frontier.contains(field.optionsFilter?.field) &&
              !found.contains(field.id))
            field.id,
      };
      found.addAll(next);
      frontier = next;
    }
    return found;
  }

  /// Le libellé du champ dont [field] dépend — « Région » pour la
  /// préfecture. Sert à dire quoi faire quand la liste est encore vide.
  String? filterLabelFor(OnboardingField field) {
    final parent = field.optionsFilter?.field;
    if (parent == null) return null;
    return fields.where((f) => f.id == parent).map((f) => f.label).firstOrNull;
  }

  /// Option « tout selectionner » d'une liste multiple.
  final OnboardingOption? allOption;

  /// Affiche un champ de saisie assistee plutot que toutes les etiquettes.
  ///
  /// Porte par le parcours et non deduit du nombre d'options : les cycles
  /// sont quatre et doivent rester visibles d'un coup d'oeil, les matieres
  /// sont vingt-quatre et forment un mur. Un seuil automatique basculerait
  /// une liste le jour ou on lui ajoute une entree.
  final bool searchable;

  /// Ce qui est ecrit dans le champ vide — « Tapez une matiere… ».
  final String? searchHint;

  final bool required;
  final bool optional;
  final int minSelected;

  final double min;
  final double max;
  final double stepSize;
  final num? defaultValue;
  final String? unit;
  final RangeEstimate? estimate;

  final String? cta;
  final String? declineLabel;
  final String? declineValue;

  factory OnboardingStep.fromJson(Map<String, dynamic> json) => OnboardingStep(
    id: json['id'] as String,
    type: StepType.fromCode(json['type'] as String),
    title: json['title'] as String,
    body: json['body'] as String?,
    image: json['image'] == null
        ? null
        : OnboardingIllustration.fromJson(
            json['image'] as Map<String, dynamic>,
          ),
    showIf: json['showIf'] == null
        ? null
        : ShowIf.fromJson(json['showIf'] as Map<String, dynamic>),
    fieldId: json['fieldId'] as String?,
    fields: [
      for (final f in (json['fields'] as List<dynamic>? ?? const []))
        OnboardingField.fromJson(f as Map<String, dynamic>),
    ],
    options: [
      for (final o in (json['options'] as List<dynamic>? ?? const []))
        OnboardingOption.fromJson(o as Map<String, dynamic>),
    ],
    highlights: [
      for (final h in (json['highlights'] as List<dynamic>? ?? const []))
        OnboardingHighlight.fromJson(h as Map<String, dynamic>),
    ],
    plans: [
      for (final p in (json['plans'] as List<dynamic>? ?? const []))
        OnboardingPlan.fromJson(p as Map<String, dynamic>),
    ],
    items: [
      for (final i in (json['items'] as List<dynamic>? ?? const []))
        i as String,
    ],
    optionsSource: json['optionsSource'] as String?,
    uploads: [
      for (final u in (json['uploads'] as List<dynamic>? ?? const []))
        OnboardingUpload.fromJson(u as Map<String, dynamic>),
    ],
    optionsFilter: json['optionsFilter'] == null
        ? null
        : OptionsFilter.fromJson(json['optionsFilter'] as Map<String, dynamic>),
    itemsSource: json['itemsSource'] as String?,
    allOption: json['allOption'] == null
        ? null
        : OnboardingOption.fromJson(json['allOption'] as Map<String, dynamic>),
    searchable: json['searchable'] as bool? ?? false,
    searchHint: json['searchHint'] as String?,
    required: json['required'] as bool? ?? false,
    optional: json['optional'] as bool? ?? false,
    minSelected: json['minSelected'] as int? ?? 0,
    min: (json['min'] as num? ?? 0).toDouble(),
    max: (json['max'] as num? ?? 100).toDouble(),
    stepSize: (json['step'] as num? ?? 1).toDouble(),
    defaultValue: json['default'] as num?,
    unit: json['unit'] as String?,
    estimate: json['estimate'] == null
        ? null
        : RangeEstimate.fromJson(json['estimate'] as Map<String, dynamic>),
    cta: json['cta'] as String?,
    declineLabel: json['declineLabel'] as String?,
    declineValue: json['declineValue'] as String?,
  );
}

/// Regroupement d'ecrans, matérialise par la barre de progression.
class OnboardingSection {
  const OnboardingSection({
    required this.id,
    required this.label,
    required this.steps,
  });

  final String id;
  final String label;
  final List<OnboardingStep> steps;

  factory OnboardingSection.fromJson(Map<String, dynamic> json) =>
      OnboardingSection(
        id: json['id'] as String,
        label: json['label'] as String,
        steps: [
          for (final s in (json['steps'] as List<dynamic>))
            OnboardingStep.fromJson(s as Map<String, dynamic>),
        ],
      );
}

/// Parcours complet, tel que décrit par le JSON partage.
class OnboardingFlowSpec {
  const OnboardingFlowSpec({
    required this.id,
    required this.audience,
    required this.currency,
    required this.sections,
  });

  final String id;
  final String audience;
  final String currency;
  final List<OnboardingSection> sections;

  factory OnboardingFlowSpec.fromJson(Map<String, dynamic> json) =>
      OnboardingFlowSpec(
        id: json['id'] as String,
        audience: json['audience'] as String,
        currency: json['currency'] as String? ?? '',
        sections: [
          for (final s in (json['sections'] as List<dynamic>))
            OnboardingSection.fromJson(s as Map<String, dynamic>),
        ],
      );

  /// Tous les ecrans, a plat — l'ordre de parcours.
  List<OnboardingStep> get steps => [
    for (final section in sections) ...section.steps,
  ];

  /// Le parcours réellement parcouru, conditions appliquées.
  ///
  /// Recalculé à chaque réponse : répondre « je cherche un établissement »
  /// fait apparaître les écrans correspondants sans rechargement.
  List<OnboardingStep> visibleSteps(Map<String, Object?> answers) => [
    for (final step in steps)
      if (step.showIf == null ||
          step.showIf!.matches(answers[step.showIf!.field]))
        step,
  ];

  /// Section portant une étape donnée.
  ///
  /// Repère l'étape par son identité plutôt que par son rang : avec les
  /// étapes conditionnelles, le rang affiché ne correspond plus au rang dans
  /// le fichier.
  OnboardingSection sectionOfStep(OnboardingStep step) {
    for (final section in sections) {
      if (section.steps.any((s) => s.id == step.id)) return section;
    }
    return sections.first;
  }

  /// Section a laquelle appartient l'écran d'indice [index].
  OnboardingSection sectionOf(int index) {
    var cursor = 0;
    for (final section in sections) {
      if (index < cursor + section.steps.length) return section;
      cursor += section.steps.length;
    }
    return sections.last;
  }
}
