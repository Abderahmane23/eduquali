import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/curriculum/stages.dart';
import '../../../core/storage/document_pipeline.dart';
import '../../providers/core_providers.dart';

/// Traduit les réponses d'un parcours d'inscription en compte.
///
/// Le moteur de parcours ne connaît que des réponses indexées par `fieldId` ;
/// c'est ici, et seulement ici, que ces clés deviennent un compte. Les trois
/// profils partagent la même entrée, sinon chacun finirait par diverger sur
/// la façon de lire `phone` ou `city`.
///
/// Renvoie l'identifiant du compte créé : l'appelant enchaîne sur l'OTP.
class SignupCompletion {
  const SignupCompletion(this._ref);

  final Ref _ref;

  Future<String> create(String role, Map<String, dynamic> answers) {
    final auth = _ref.read(authRepositoryProvider);
    final text = _reader(answers);

    return switch (UserRole.fromCode(role)) {
      UserRole.institution => auth.registerInstitution(
        name: text('institution_name', fallback: 'Établissement'),
        type: _institutionType(answers),
        region: text('region', fallback: null),
        city: text('city'),
        district: text('district', fallback: null),
        phone: text('phone'),
        password: text('password'),
        managerName: text('manager_name', fallback: 'Direction'),
      ),
      // L'etudiant majeur ouvre un compte parent dont il est lui-meme
      // l'eleve : c'est la meme mecanique — quelqu'un qui suit une
      // scolarite — et lui creer une table a part dupliquerait enfants,
      // contrats et seances pour rien.
      UserRole.student || UserRole.parent => auth.registerParent(
        firstName: text('first_name'),
        lastName: text('last_name'),
        phone: text('phone'),
        password: text('password'),
        // Le rôle choisi, et non celui de la table : les deux partagent la
        // mécanique du parent, pas son libellé ni ses écrans.
        role: UserRole.fromCode(role),
        region: text('region', fallback: null),
        city: text('city'),
        district: text('district', fallback: null),
      ),
      _ => auth.registerTeacher(
        firstName: text('first_name'),
        lastName: text('last_name'),
        phone: text('phone'),
        password: text('password'),
        region: text('region', fallback: null),
        city: text('city'),
        district: text('district', fallback: null),
      ),
    };
  }

  /// Enregistre l'enfant déclaré pendant le parcours parent.
  ///
  /// Séparé de la création du compte : un échec ici ne doit pas empêcher le
  /// compte d'exister, l'enfant restant ajoutable depuis le profil.
  /// Rattache les fichiers deposes pendant le parcours au compte cree.
  ///
  /// Les documents sont choisis avant que le compte existe : l'etape ne peut
  /// donc garder que le chemin du fichier, deja copie dans le dossier prive
  /// de l'application. C'est ici qu'ils deviennent des lignes rattachees a
  /// une fiche professeur, et qu'ils entrent dans la file d'envoi.
  ///
  /// Silencieux quand rien n'a ete depose : l'etape porte un bouton
  /// « Passer », et un professeur qui n'a pas son diplome sous la main doit
  /// pouvoir finir son inscription puis revenir le deposer.
  Future<void> attachDocuments(
    String userId,
    Map<String, dynamic> answers,
  ) async {
    final session = await _ref
        .read(authRepositoryProvider)
        .sessionForUser(userId);
    final teacherId = session?.teacherId;
    if (teacherId == null) return;

    const champs = {
      'cv_path': DocumentType.cv,
      'diploma_path': DocumentType.diploma,
    };
    for (final (champ, type) in champs.entries.map((e) => (e.key, e.value))) {
      final chemin = answers[champ];
      if (chemin is! String || chemin.trim().isEmpty) continue;

      final fichier = File(chemin);
      // Le fichier peut avoir disparu entre le choix et la fin du parcours —
      // un nettoyage du telephone, une inscription reprise le lendemain.
      // Enregistrer une ligne qui pointe sur rien ferait afficher un
      // document inexistant sur la fiche.
      if (!fichier.existsSync()) continue;

      final bytes = await fichier.readAsBytes();
      await _ref
          .read(verificationRepositoryProvider)
          .storeDocument(
            teacherId: teacherId,
            captured: CapturedDocument(
              path: chemin,
              sizeBytes: bytes.length,
              checksum: sha256.convert(bytes).toString(),
              type: type,
            ),
          );
    }
  }

  /// Enregistre ce qu'un professeur a déclaré de son métier.
  ///
  /// Sept écrans du parcours n'étaient lus par personne : `service_types`,
  /// `cycles`, `level_ids`, `subject_ids`, `mobility`, `availability` et
  /// `home_availability`. Voir [TeacherRepository.setDeclaredProfile] pour ce
  /// que cette perte coûtait à l'intéressé.
  ///
  /// `cycles` n'est volontairement pas enregistré : c'est un entonnoir, il ne
  /// sert qu'à restreindre la liste des niveaux de l'étape suivante, et les
  /// cycles se relisent depuis les niveaux retenus.
  Future<void> attachTeacherProfile(
    String role,
    String userId,
    Map<String, dynamic> answers,
  ) async {
    if (UserRole.fromCode(role) != UserRole.teacher) return;

    final auth = _ref.read(authRepositoryProvider);
    final session = await auth.sessionForUser(userId);
    final teacherId = session?.teacherId;
    if (teacherId == null) return;

    await _ref
        .read(teacherRepositoryProvider)
        .setDeclaredProfile(
          teacherId: teacherId,
          subjectIds: _codes(answers['subject_ids']),
          levelIds: _codes(answers['level_ids']),
          serviceTypes: _codes(answers['service_types']),
          mobility: answers['mobility'] as String?,
          tutoringHours: _hours(answers['home_availability']),
          workHours: _hours(answers['availability']),
        );
  }

  /// Enregistre ce qu'un établissement cherche.
  ///
  /// Neuf réponses sur dix-sept étaient jetées, dont la totalité de ses
  /// critères de recrutement. Conséquence : à chaque offre publiée, le
  /// formulaire redemandait la matière, les niveaux et jusqu'à la ville —
  /// pourtant obligatoire et déjà connue.
  Future<void> attachInstitutionNeeds(
    String role,
    String userId,
    Map<String, dynamic> answers,
  ) async {
    if (UserRole.fromCode(role) != UserRole.institution) return;

    final auth = _ref.read(authRepositoryProvider);
    final session = await auth.sessionForUser(userId);
    final institutionId = session?.institutionId;
    if (institutionId == null) return;

    final jours = _workDays(answers);

    await _ref
        .read(authRepositoryProvider)
        .setRecruitmentNeeds(
          institutionId: institutionId,
          managerRole: answers['manager_role'] as String?,
          neededSubjectIds: _codes(answers['subject_ids']),
          priorities: _codes(answers['priorities']),
          teacherLocation: answers['teacher_location'] as String?,
          workDays: jours,
          workStart: answers['work_start'] as String?,
          workEnd: answers['work_end'] as String?,
          maxDistance: answers['max_distance'] as String?,
        );
  }

  /// Retient la formule choisie au dernier écran, sans l'offrir.
  ///
  /// La clé `subscription` n'était lue nulle part : on choisissait PRO et on
  /// obtenait un compte FREE, à rechoisir depuis la facturation. L'écrire dans
  /// `plan` offrirait la formule, puisque rien n'est encaissé à l'inscription ;
  /// on garde donc l'intention, que seul le paiement convertira.
  Future<void> rememberPlanChoice(
    String userId,
    Map<String, dynamic> answers,
  ) async {
    final choix = answers['subscription'];
    if (choix is! String || choix.trim().isEmpty) return;

    // Le refus est une réponse comme une autre, et il ne se garde pas : le
    // parcours porte `declineValue` sur cette étape.
    final code = choix.trim().toUpperCase();
    if (code == 'FREE' || code == 'NONE' || code == 'DECLINE') return;

    await _ref.read(authRepositoryProvider).rememberPlanChoice(userId, code);
  }

  /// Les jours travaillés, ramenés à une liste de codes de jours.
  ///
  /// Le parcours pose la question en deux temps : un **motif** de semaine
  /// (`MON_FRI`, `MON_SAT`) dans une liste déroulante, et la liste des jours
  /// un par un seulement si l'on a répondu `OTHER`. Garder le motif tel quel
  /// obligerait chaque lecteur à savoir le déplier — et à redemander la
  /// question le jour où un troisième motif apparaît.
  ///
  /// La colonne ne contient donc qu'une chose : des codes de jours.
  static List<String> _workDays(Map<String, dynamic> answers) {
    final motif = (answers['work_days'] ?? '').toString().trim().toUpperCase();
    if (motif == 'OTHER') return _codes(answers['work_days_custom']);

    const lundiVendredi = ['MON', 'TUE', 'WED', 'THU', 'FRI'];
    return switch (motif) {
      'MON_FRI' => lundiVendredi,
      'MON_SAT' => [...lundiVendredi, 'SAT'],
      // Un motif inconnu n'est pas inventé : mieux vaut une colonne vide
      // qu'une semaine fausse préremplie dans une offre d'emploi.
      _ => const [],
    };
  }

  /// Les codes d'une réponse de choix.
  ///
  /// Tolère la liste **et** la chaîne : un choix multiple rend une liste, mais
  /// une liste déroulante posée dans un écran `form` rend une chaîne unique.
  /// N'accepter que la liste faisait lever `attachInstitutionNeeds` sur
  /// `work_days`, qui est une déroulante.
  static List<String> _codes(Object? value) => switch (value) {
    final List<dynamic> liste => [
      for (final item in liste)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    ],
    final String texte when texte.trim().isNotEmpty => [
      for (final part in texte.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    ],
    _ => const [],
  };

  /// Une réponse `day_hours` : jour -> créneaux.
  static Map<String, dynamic> _hours(Object? value) =>
      value is Map<String, dynamic>
      ? {
          for (final entry in value.entries)
            if (entry.value is List && (entry.value as List).isNotEmpty)
              entry.key: entry.value,
        }
      : const {};

  /// Enregistre l'apprenant déclaré pendant le parcours.
  ///
  /// Séparé de la création du compte : un échec ici ne doit pas empêcher le
  /// compte d'exister, l'apprenant restant ajoutable depuis le profil.
  ///
  /// --- Deux parcours, une seule ligne --------------------------------------
  ///
  /// Un parent décrit son enfant, préfixé `child_`. Un universitaire décrit la
  /// personne qu'il est lui-même, sans préfixe. Les deux produisent la même
  /// ligne, parce que [create] ouvre déjà un compte parent dans les deux cas :
  /// quelqu'un qui suit une scolarité.
  ///
  /// --- Le défaut que ceci corrige -----------------------------------------
  ///
  /// Cette méthode s'appelait `attachChild` et ne lisait que des clés `child_`,
  /// en commençant par exiger `child_first_name`. Or le parcours universitaire
  /// ne décrit pas un tiers : il n'a pas cette clé. Il sortait donc **sans
  /// apprenant du tout**, et le palier, la classe et les matières qu'il venait
  /// de choisir étaient jetés — un compte qui ne connaît ni le niveau ni les
  /// matières de la personne ne peut plus lui proposer le bon professeur.
  ///
  /// Le parcours parent, lui, fonctionnait.
  ///
  /// Les clés viennent du `fieldId` de chaque étape, pas de son `id` : une étape
  /// de choix déclare elle-même sous quel nom sa réponse est rangée.
  /// `test/signup_answer_keys_test.dart` vérifie maintenant que chaque clé lue
  /// ici est écrite par au moins un parcours.
  Future<void> attachLearner(
    String role,
    String userId,
    Map<String, dynamic> answers,
  ) async {
    // Le parent décrit un tiers ; tout autre parcours qui arrive ici décrit la
    // personne elle-même.
    final prefixe = UserRole.fromCode(role) == UserRole.parent ? 'child_' : '';

    final firstName = answers['${prefixe}first_name'];
    if (firstName is! String || firstName.trim().isEmpty) return;

    final auth = _ref.read(authRepositoryProvider);
    final session = await auth.sessionForUser(userId);
    final parentId = session?.parentId;
    if (parentId == null) return;

    await _ref
        .read(childrenRepositoryProvider)
        .add(
          parentId: parentId,
          firstName: firstName.trim(),
          // Aucune étape ne demande le nom de l'enfant : il porte en général
          // celui du compte. Pour un universitaire, c'est son propre nom.
          lastName: answers['last_name'] as String?,
          levelId: await _levelId(answers, prefixe),
          filiereId: answers['${prefixe}filiere_id'] as String?,
          schoolName: answers['${prefixe}institution'] as String?,
          subjectIds: [
            for (final id
                in (answers['${prefixe}subject_ids'] as List<dynamic>? ??
                    const []))
              id.toString(),
          ],
        );
  }

  /// La classe choisie, ou l'en-tête du cycle quand aucune ne l'est.
  ///
  /// Le primaire et « diplômé » ne demandent pas de classe — le référentiel ne
  /// détaille pas les six années du primaire, et un diplômé n'est dans aucune
  /// classe. S'arrêter là laisserait ces deux paliers sans niveau, donc hors de
  /// tout filtre par cycle : un élève de CE2 se verrait proposer des
  /// professeurs d'université.
  Future<String?> _levelId(Map<String, dynamic> answers, String prefixe) async {
    final classe = answers['${prefixe}level_id'];
    if (classe is String && classe.trim().isNotEmpty) return classe.trim();

    final palier = answers['${prefixe}level_stage'];
    if (palier is! String || palier.trim().isEmpty) return null;

    final paliers = await loadStages();
    for (final stage in paliers) {
      if (stage.id == palier.trim()) return stage.groupingLevelId;
    }
    return null;
  }

  static String Function(String, {String? fallback}) _reader(
    Map<String, dynamic> answers,
  ) {
    return (String key, {String? fallback = ''}) {
      final value = answers[key];
      if (value == null) return fallback ?? '';
      final text = value.toString().trim();
      return text.isEmpty ? (fallback ?? '') : text;
    };
  }

  static InstitutionType _institutionType(Map<String, dynamic> answers) {
    // Cette clé était lue sans qu'aucune étape ne la demande : tout
    // établissement était donc créé `SCHOOL`, université comprise. Le parcours
    // pose désormais la question (`institution_type`), juste après le nom.
    //
    // Le repli reste : une version plus ancienne de l'application peut encore
    // envoyer des réponses sans cette clé, et mieux vaut le type le plus
    // courant qu'un refus d'inscription.
    final raw = answers['institution_type'];
    return raw is String && raw.trim().isNotEmpty
        ? InstitutionType.fromCode(raw.trim())
        : InstitutionType.school;
  }
}

final signupCompletionProvider = Provider(SignupCompletion.new);
