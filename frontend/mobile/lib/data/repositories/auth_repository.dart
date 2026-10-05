import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_enums.dart';
import '../../core/security/secure_store.dart';
import '../../core/utils/validators.dart';
import '../../domain/usecases/otp_check.dart';
import '../local/database/app_database.dart';
import '../sync/sync_engine.dart';
import '../remote/supabase_auth_api.dart';

/// Session authentifiee courante.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.role,
    required this.phone,
    this.teacherId,
    this.institutionId,
    this.parentId,
    this.firstName,
    this.lastName,
    this.plan = 'FREE',
    this.planRenewsAt,
  });

  final String userId;
  final UserRole role;
  final String phone;

  /// Formule d'abonnement — `FREE`, `PRO` ou `MASTER`.
  ///
  /// Le code brut plutot que l'enum : la session traverse la couche donnees,
  /// qui n'a pas a connaitre les regles de facturation. L'ecran convertit.
  final String plan;

  /// Fin du mois paye. Nulle tant que rien n'a ete souscrit.
  final DateTime? planRenewsAt;
  final String? teacherId;
  final String? institutionId;

  /// Fiche parent, presente pour un compte PARENT.
  final String? parentId;

  final String? firstName;
  final String? lastName;

  /// Le nom du titulaire, tel qu'on l'ecrit sur une facture. Retombe sur le
  /// numero quand le compte n'a pas encore de nom.
  String get displayName {
    final parts = [
      firstName ?? '',
      lastName ?? '',
    ].where((p) => p.trim().isNotEmpty);
    return parts.isEmpty ? phone : parts.join(' ');
  }

  bool get isTeacher => role == UserRole.teacher;
  bool get isInstitution => role == UserRole.institution;

  /// Vrai pour un parent **et** pour un etudiant majeur : les deux suivent
  /// une scolarite et partagent le meme espace.
  bool get isParent => role.followsAStudent;
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Inscription et connexion (§5.1).
///
/// L'authentification definitive est assuree par le serveur (§51) ; cette
/// implementation gere le compte localement afin que le parcours reste
/// utilisable hors ligne, et empile les operations pour synchronisation.
///
/// **Le code de confirmation a ete retire le 25/09.** Il ne verifiait rien :
/// sans serveur aucun SMS ne part, et l'ecran affichait « Saisissez le code
/// 123456 ». `_issueOtp`, `verifyOtp` et `resendOtp` restent ecrits — ils
/// reviendront tels quels le jour ou un fournisseur SMS sera branche — mais
/// aucun parcours ne les appelle aujourd'hui.
class AuthRepository {
  AuthRepository(
    this._db,
    this._store,
    this._sync, {
    bool Function()? isServerReachable,
    SupabaseAuthApi? identity,
    // Un parametre nomme ne peut pas commencer par un souligne en Dart : le
    // champ prive se remplit donc dans la liste d'initialisation, et la regle
    // `prefer_initializing_formals` ne s'applique pas ici.
    // ignore: prefer_initializing_formals
  }) : _identity = identity,
       _isServerReachable = isServerReachable ?? (() => false);

  final AppDatabase _db;
  final SecureStore _store;
  final SyncEngine _sync;

  /// L'autorite sur l'identite, quand un projet Supabase est configure.
  ///
  /// **Elle decide de l'identifiant du compte, et la base locale le recopie.**
  /// C'est ce qui fait qu'un compte cree sur le site se retrouve sur le
  /// telephone : les deux portent le meme `users.id`. Sans elle — aucune
  /// configuration a la compilation — l'application fonctionne exactement comme
  /// avant, entierement en local.
  final SupabaseAuthApi? _identity;

  /// Vrai quand l'identite est partagee avec le site.
  bool get sharesIdentity => _identity != null && SupabaseAuthApi.isConfigured;

  /// Le serveur répond-il ? Tant qu'il ne répond pas, aucun SMS ne peut
  /// partir et le code unique hors ligne est accepté.
  final bool Function() _isServerReachable;

  /// Vrai quand le code unique hors ligne ouvrira la session : l'écran le
  /// dit alors à l'utilisateur au lieu de le laisser attendre un SMS.
  bool get offlineOtpApplies =>
      AppConstants.offlineOtpEnabled && !_isServerReachable();
  static const _uuid = Uuid();
  static const _pendingOtpKey = 'pending_otp';
  static const _pendingUserKey = 'pending_otp_user';

  /// Restaure la session au demarrage.
  Future<AuthSession?> restore() async {
    final userId = await _store.sessionUserId;
    if (userId == null) return null;
    return _sessionFor(userId);
  }

  /// Session d'un compte donne, sans l'ouvrir.
  ///
  /// Utilisee juste apres une inscription, quand il faut lire les
  /// identifiants derives (fiche enseignant, etablissement ou parent) avant
  /// que l'utilisateur n'ait valide son code.
  Future<AuthSession?> sessionForUser(String userId) => _sessionFor(userId);

  Future<AuthSession?> _sessionFor(String userId) async {
    final user = await (_db.select(
      _db.users,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();
    if (user == null || user.suspended) return null;

    final teacher = await (_db.select(
      _db.teachers,
    )..where((t) => t.userId.equals(userId))).getSingleOrNull();
    final institution = await (_db.select(
      _db.institutions,
    )..where((t) => t.userId.equals(userId))).getSingleOrNull();
    final parent = await (_db.select(
      _db.parents,
    )..where((t) => t.userId.equals(userId))).getSingleOrNull();

    return AuthSession(
      userId: user.id,
      role: UserRole.fromCode(user.role),
      phone: user.phone,
      teacherId: teacher?.id,
      institutionId: institution?.id,
      parentId: parent?.id,
      firstName: user.firstName,
      lastName: user.lastName,
      plan: user.plan,
      planRenewsAt: user.planRenewsAt,
    );
  }

  /// Reserve l'identifiant d'un nouveau compte.
  ///
  /// Avec un projet configure, c'est Supabase qui le donne : le compte existe
  /// alors des deux cotes sous le meme identifiant, et la personne pourra se
  /// connecter depuis le site comme depuis le telephone.
  ///
  /// **Creer un compte demande du reseau, et c'est assume.** On pourrait
  /// l'ouvrir en local et le rattacher plus tard, mais il faudrait alors
  /// reconcilier deux identifiants pour la meme personne — et un conflit
  /// d'identite se decouvre le jour ou elle change d'appareil, c'est-a-dire au
  /// pire moment. Ouvrir un compte est un acte unique ; l'application
  /// fonctionne hors ligne ensuite.
  Future<String> _reserveAccountId(String phone, String password) async {
    final identity = _identity;
    if (identity == null || !SupabaseAuthApi.isConfigured) {
      // Aucun projet configure : le fonctionnement local d'avant.
      return _uuid.v4();
    }
    try {
      final compte = await identity.signUp(phone: phone, password: password);
      return compte.userId;
    } on RemoteAuthException catch (erreur) {
      throw AuthException(
        erreur.offline
            ? 'Creer un compte demande une connexion. Reessayez des que vous '
                  'avez du reseau — ensuite l\'application fonctionne hors ligne.'
            : erreur.message,
      );
    }
  }

  /// Inscription enseignant — cree le compte. La session s'ouvre ensuite
  /// sans code : la session s'ouvre par [openSessionFor], le compte venant
  /// d'etre cree sur cet appareil par la personne qui le tient.
  Future<String> registerTeacher({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    String? email,
    String? region,
    String? city,
    String? district,
  }) async {
    _checkPassword(password);
    final normalized = Validators.normalizePhone(phone);
    final existing = await (_db.select(
      _db.users,
    )..where((t) => t.phone.equals(normalized))).getSingleOrNull();
    if (existing != null) {
      throw const AuthException('Un compte existe déjà avec ce numéro.');
    }

    final userId = await _reserveAccountId(phone, password);
    final teacherId = _uuid.v4();

    await _db.transaction(() async {
      await _db
          .into(_db.users)
          .insert(
            UsersCompanion.insert(
              id: userId,
              role: UserRole.teacher.code,
              phone: normalized,
              email: Value(email),
              firstName: Value(firstName),
              lastName: Value(lastName),
              city: Value(city),
              passwordHash: Value(SecureStore.hashSecret(password)),
              dirty: const Value(true),
            ),
          );
      await _db
          .into(_db.teachers)
          .insert(
            TeachersCompanion.insert(
              id: teacherId,
              userId: userId,
              region: Value(region),
              city: Value(city),
              district: Value(district),
              dirty: const Value(true),
            ),
          );
    });

    await _sync.enqueue(
      entity: 'user',
      entityId: userId,
      operation: SyncOperation.create,
      payload: {
        'role': UserRole.teacher.code,
        'phone': normalized,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'region': region,
        'city': city,
        'district': district,
      },
    );

    return userId;
  }

  /// Inscription établissement (§19.1).
  Future<String> registerInstitution({
    required String name,
    required InstitutionType type,
    required String city,
    required String phone,
    required String password,
    required String managerName,
    String? email,
    String? region,
    String? district,
    String? address,
    String? description,
  }) async {
    _checkPassword(password);
    final normalized = Validators.normalizePhone(phone);
    final existing = await (_db.select(
      _db.users,
    )..where((t) => t.phone.equals(normalized))).getSingleOrNull();
    if (existing != null) {
      throw const AuthException('Un compte existe déjà avec ce numéro.');
    }

    final userId = await _reserveAccountId(phone, password);
    final institutionId = _uuid.v4();

    await _db.transaction(() async {
      await _db
          .into(_db.users)
          .insert(
            UsersCompanion.insert(
              id: userId,
              role: UserRole.institution.code,
              phone: normalized,
              email: Value(email),
              firstName: Value(managerName),
              city: Value(city),
              passwordHash: Value(SecureStore.hashSecret(password)),
              dirty: const Value(true),
            ),
          );
      await _db
          .into(_db.institutions)
          .insert(
            InstitutionsCompanion.insert(
              id: institutionId,
              userId: Value(userId),
              name: name,
              type: type.code,
              region: Value(region),
              city: city,
              district: Value(district),
              address: Value(address),
              phone: Value(normalized),
              email: Value(email),
              managerName: Value(managerName),
              description: Value(description),
              // Le compte est soumis a validation administrative (§19.1).
              verificationStatus: Value(VerificationStatus.pending.code),
              dirty: const Value(true),
            ),
          );
    });

    await _sync.enqueue(
      entity: 'institution',
      entityId: institutionId,
      operation: SyncOperation.create,
      payload: {
        'name': name,
        'type': type.code,
        'region': region,
        'city': city,
        'district': district,
        'phone': normalized,
        'managerName': managerName,
      },
    );

    return userId;
  }

  /// Inscription parent (§55-bis).
  ///
  /// Le compte appartient a l'adulte : un eleve de college ou de lycee est
  /// mineur, lui faire ouvrir un compte deplacerait le consentement sur un
  /// enfant. Les enfants sont declares sur la fiche du parent.
  /// Ouvre un compte qui suit une scolarité : un parent, ou un majeur pour
  /// lui-même.
  ///
  /// [role] décide de ce qui est **écrit** dans `users.role`. Il valait
  /// `PARENT` en dur, et un universitaire était donc enregistré comme parent :
  /// `UserRole.student` n'apparaissait dans aucune session, le libellé
  /// « Universitaire » ne s'affichait jamais, et les deux écrans qui s'adaptent
  /// au rôle — `parent_dashboard.dart` et `parent_shell.dart`, tous deux sur
  /// `role == UserRole.parent` — montraient « Mes enfants » à quelqu'un qui est
  /// lui-même l'élève. Du code de branchement correct, rendu mort par la ligne
  /// qui l'alimente.
  ///
  /// Les deux rôles partagent la même mécanique et la même table `parents` :
  /// quelqu'un qui suit une scolarité. Seul le rôle inscrit diffère.
  Future<String> registerParent({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    UserRole role = UserRole.parent,
    String? email,
    String? region,
    String? city,
    String? district,
  }) async {
    assert(
      role == UserRole.parent || role == UserRole.student,
      'registerParent n ouvre que des comptes parent ou universitaire ; '
      '« ${role.code} » passerait a cote de sa propre inscription.',
    );
    _checkPassword(password);
    final normalized = Validators.normalizePhone(phone);
    final existing = await (_db.select(
      _db.users,
    )..where((t) => t.phone.equals(normalized))).getSingleOrNull();
    if (existing != null) {
      throw const AuthException('Un compte existe deja avec ce numero.');
    }

    final userId = await _reserveAccountId(phone, password);
    final parentId = _uuid.v4();

    await _db.transaction(() async {
      await _db
          .into(_db.users)
          .insert(
            UsersCompanion.insert(
              id: userId,
              role: role.code,
              phone: normalized,
              email: Value(email),
              firstName: Value(firstName),
              lastName: Value(lastName),
              city: Value(city),
              // Absent jusqu'au 02/10 : un compte parent se creait sans
              // empreinte de mot de passe, et `login` comparait donc toujours
              // a `null`. Le compte existait et ne pouvait plus s'ouvrir.
              passwordHash: Value(SecureStore.hashSecret(password)),
              dirty: const Value(true),
            ),
          );
      await _db
          .into(_db.parents)
          .insert(
            ParentsCompanion.insert(
              id: parentId,
              userId: userId,
              region: Value(region),
              city: Value(city),
              district: Value(district),
              dirty: const Value(true),
            ),
          );
    });

    await _sync.enqueue(
      entity: 'parent',
      entityId: parentId,
      operation: SyncOperation.create,
      payload: {
        'firstName': firstName,
        'lastName': lastName,
        'phone': normalized,
        'region': region,
        'city': city,
      },
    );

    return userId;
  }

  /// Genere un code OTP a usage unique (§5.1).
  ///
  /// L'envoi du SMS releve du serveur ; en l'absence de connexion, le code est
  /// affiche a l'utilisateur pour ne pas bloquer le parcours de démonstration.
  Future<String> _issueOtp(String userId) async {
    final code = (Random.secure().nextInt(900000) + 100000).toString();
    await _db.writeMeta(_pendingOtpKey, code);
    await _db.writeMeta(_pendingUserKey, userId);
    await _db.writeMeta(
      '${_pendingOtpKey}_at',
      DateTime.now().toIso8601String(),
    );
    return code;
  }

  Future<String?> pendingOtp() => _db.readMeta(_pendingOtpKey);
  Future<String?> pendingOtpUser() => _db.readMeta(_pendingUserKey);

  Future<String> resendOtp(String userId) => _issueOtp(userId);

  /// Vérifié le code et ouvre la session.
  Future<AuthSession> verifyOtp(String userId, String code) async {
    // Le compte d'abord : un code juste pour un compte inexistant ne doit
    // pas passer pour une erreur de saisie.
    final exists = await (_db.select(
      _db.users,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();
    if (exists == null) {
      throw const AuthException(
        'Compte introuvable. Recommencez l’inscription.',
      );
    }

    final issuedRaw = await _db.readMeta('${_pendingOtpKey}_at');
    final pendingUser = await _db.readMeta(_pendingUserKey);
    final outcome = checkOtp(
      entered: code,
      // Un code émis pour un autre compte ne vaut pas pour celui-ci.
      expected: pendingUser == userId
          ? await _db.readMeta(_pendingOtpKey)
          : null,
      issuedAt: issuedRaw == null ? null : DateTime.tryParse(issuedRaw),
      now: DateTime.now(),
      validity: AppConstants.otpValidity,
      offlineCodeEnabled: AppConstants.offlineOtpEnabled,
      offlineCode: AppConstants.offlineOtpCode,
      serverReachable: _isServerReachable(),
    );

    switch (outcome) {
      case OtpOutcome.noPending:
        throw const AuthException('Aucun code en attente. Renvoyez un code.');
      case OtpOutcome.expired:
        throw const AuthException('Code expiré. Demandez un nouveau code.');
      case OtpOutcome.wrong:
        throw const AuthException('Code incorrect. Vérifiez et réessayez.');
      case OtpOutcome.accepted:
      case OtpOutcome.acceptedOffline:
        break;
    }

    await (_db.update(_db.users)..where((t) => t.id.equals(userId))).write(
      UsersCompanion(
        phoneVerified: const Value(true),
        lastLoginAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
    await _db.deleteMeta(_pendingOtpKey);
    await _db.deleteMeta(_pendingUserKey);

    final session = await _sessionFor(userId);
    if (session == null) throw const AuthException('Compte introuvable.');
    await _openSession(session);
    return session;
  }
  // --- Connexion sur le numero seul : retiree le 02/10 --------------------
  //
  // `signInWithPhone` ouvrait une session a qui presentait un numero existant,
  // sans rien verifier. Elle remplacait un code OTP qui s'affichait lui-meme a
  // l'ecran, donc elle ne perdait aucune securite — mais elle n'en offrait
  // aucune, et elle restait appelee par l'ecran de connexion.
  //
  // Elle n'est pas conservee « au cas ou » : une fonction qui ouvre une session
  // sur un numero se recable en une ligne, et c'est exactement ce qu'il ne faut
  // pas pouvoir faire sans le decider. Le jour ou un fournisseur SMS existe,
  // c'est `verifyOtp` qu'il faudra ecrire, pas celle-ci.

  /// Ouvre la session d'un compte déjà identifié.
  ///
  /// Sert à l'inscription — le compte vient d'être créé sur cet appareil,
  /// par la personne qui le tient — et à la récupération par courriel. Le
  /// code qui précédait ces deux chemins n'apprenait rien à personne : il
  /// affichait le chiffre à recopier.
  Future<AuthSession> openSessionFor(String userId) async {
    final session = await _sessionFor(userId);
    if (session == null) throw const AuthException('Compte introuvable.');
    await _openSession(session);
    return session;
  }

  /// Demande de reinitialisation du mot de passe, par numero ou par
  /// courriel.
  ///
  /// Les deux canaux menent au meme code a usage unique : une carte SIM se
  /// perd et se change, et quelqu'un qui n'a plus son numero doit pouvoir
  /// revenir sur son compte. En inventer un second mecanisme multiplierait
  /// les portes d'entree.
  ///
  /// Le message d'echec ne dit jamais si le compte existe : ce serait
  /// donner a un inconnu le moyen de savoir qui est inscrit.
  Future<String> requestPasswordReset({String? phone, String? email}) async {
    final byPhone = phone != null && phone.trim().isNotEmpty;
    if (!byPhone && (email == null || email.trim().isEmpty)) {
      throw const AuthException('Indiquez votre numero ou votre courriel.');
    }

    final query = _db.select(_db.users);
    if (byPhone) {
      final normalized = Validators.normalizePhone(phone);
      query.where((t) => t.phone.equals(normalized));
    } else {
      query.where((t) => t.email.equals(email!.trim().toLowerCase()));
    }
    final user = await query.getSingleOrNull();

    if (user == null || user.suspended) {
      throw const AuthException(
        'Si un compte correspond, un code vient de partir.',
      );
    }

    return user.id;
  }

  /// Longueur minimale d'un mot de passe.
  ///
  /// Huit, et non six : au-dessous, un numero de telephone guineen se devine en
  /// quelques essais. La meme valeur figure dans l'etape `credentials` du
  /// parcours partage et dans le client web — c'est le meme compte des deux
  /// cotes, il ne peut pas avoir deux regles.
  static const minPasswordLength = 8;

  /// Refuse un mot de passe trop court, avec le meme message partout.
  ///
  /// Verifie ici et pas seulement dans le parcours : trois fonctions
  /// d'inscription appellent cette regle, et un ecran qui oublierait de la
  /// poser creerait un compte qu'on ne peut plus proteger.
  static void _checkPassword(String password) {
    if (password.length < minPasswordLength) {
      throw const AuthException(
        'Choisissez un mot de passe de $minPasswordLength caracteres au moins.',
      );
    }
  }

  /// Fixe un nouveau mot de passe.
  Future<void> setPassword(String userId, String password) async {
    _checkPassword(password);
    await (_db.update(_db.users)..where((t) => t.id.equals(userId))).write(
      UsersCompanion(
        passwordHash: Value(SecureStore.hashSecret(password)),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Demande au serveur de valider le couple numero / mot de passe.
  ///
  /// Rend `null` quand il n'y a pas de serveur configure ou qu'il ne repond
  /// pas : l'appelant se replie alors sur l'empreinte locale. Un refus
  /// explicite du serveur, lui, leve — un mot de passe faux doit etre refuse
  /// meme si l'ancien tient encore en local.
  Future<RemoteAccount?> _loginRemotely(String phone, String password) async {
    final identity = _identity;
    if (identity == null || !SupabaseAuthApi.isConfigured) return null;
    try {
      return await identity.signIn(phone: phone, password: password);
    } on RemoteAuthException catch (erreur) {
      if (erreur.offline) return null;
      throw AuthException(erreur.message);
    }
  }

  /// Connexion par numéro et mot de passe.
  ///
  /// **Le serveur tranche quand il repond.** C'est ce qui permet de se
  /// connecter sur un telephone a un compte cree depuis le site : la base
  /// locale ne connait pas ce compte, le serveur si, et la fiche se
  /// reconstruira a la synchronisation.
  ///
  /// Quand le serveur ne repond pas, l'empreinte locale prend le relais : sans
  /// cela une coupure de reseau fermerait l'application a quelqu'un qui s'est
  /// deja connecte sur cet appareil, ce qui serait absurde pour un produit qui
  /// se revendique hors ligne. Un mot de passe change sur le site n'est alors
  /// pas encore connu ici — l'ancien ouvre la session locale jusqu'a la
  /// prochaine connexion reussie, et c'est le prix de pouvoir travailler sans
  /// reseau.
  Future<AuthSession> login(String phone, String password) async {
    final normalized = Validators.normalizePhone(phone);

    final distant = await _loginRemotely(normalized, password);

    var user = await (_db.select(
      _db.users,
    )..where((t) => t.phone.equals(normalized))).getSingleOrNull();

    // Le serveur a reconnu un compte que cet appareil ne connait pas : c'est le
    // cas d'une inscription faite sur le site. On aligne l'empreinte locale sur
    // le mot de passe qui vient d'etre accepte, pour que la prochaine ouverture
    // fonctionne hors ligne.
    if (distant != null && user != null && user.id == distant.userId) {
      await (_db.update(_db.users)..where((t) => t.id.equals(user!.id))).write(
        UsersCompanion(
          passwordHash: Value(SecureStore.hashSecret(password)),
          updatedAt: Value(DateTime.now()),
        ),
      );
      user = await (_db.select(
        _db.users,
      )..where((t) => t.id.equals(distant.userId))).getSingleOrNull();
    }

    if (user == null) {
      if (distant != null) {
        // Le compte existe, mais sa fiche n'est pas encore descendue sur cet
        // appareil. Le dire precisement vaut mieux que « numero inconnu », qui
        // enverrait creer un deuxieme compte sur le meme numero.
        throw const AuthException(
          'Ce compte existe mais ses donnees ne sont pas encore sur cet '
          'appareil. Lancez la synchronisation depuis un reseau, puis '
          'reessayez.',
        );
      }
      throw const AuthException('Aucun compte associé a ce numéro.');
    }
    if (user.suspended) {
      throw const AuthException('Ce compte est suspendu.');
    }
    // Fige la ligne : `user` est reassignable au-dessus — le compte peut venir
    // du serveur — et l'analyse de flot ne peut donc pas la supposer non nulle
    // a l'interieur des fermetures qui suivent.
    final compte = user;

    // Le serveur a deja tranche quand il a repondu : revoir l'empreinte locale
    // refuserait un mot de passe change sur le site.
    if (distant == null &&
        compte.passwordHash != SecureStore.hashSecret(password)) {
      throw const AuthException('Mot de passe incorrect.');
    }

    await (_db.update(_db.users)..where((t) => t.id.equals(compte.id))).write(
      UsersCompanion(lastLoginAt: Value(DateTime.now())),
    );

    final session = await _sessionFor(compte.id);
    if (session == null) throw const AuthException('Compte introuvable.');
    await _openSession(session);
    return session;
  }

  /// Connexion de démonstration sur un profil déjà alimente.
  Future<AuthSession> loginAsDemoTeacher() async {
    final user = await (_db.select(
      _db.users,
    )..where((t) => t.id.equals('user_tch_mamadou'))).getSingleOrNull();
    if (user == null) {
      throw const AuthException('Profil de démonstration indisponible.');
    }
    final session = await _sessionFor(user.id);
    if (session == null) throw const AuthException('Compte introuvable.');
    await _openSession(session);
    return session;
  }

  /// Ouvre une session établissement de démonstration (§56).
  Future<AuthSession> loginAsDemoInstitution() async {
    const institutionId = 'inst_gamal';
    const userId = 'user_$institutionId';

    final existing = await (_db.select(
      _db.users,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();

    if (existing == null) {
      final institution = await (_db.select(
        _db.institutions,
      )..where((t) => t.id.equals(institutionId))).getSingleOrNull();
      if (institution == null) {
        throw const AuthException('Établissement de démonstration absent.');
      }

      await _db.transaction(() async {
        await _db
            .into(_db.users)
            .insert(
              UsersCompanion.insert(
                id: userId,
                role: UserRole.institution.code,
                phone: '+224600000001',
                firstName: const Value('Direction'),
                lastName: const Value('des ressources humaines'),
                city: Value(institution.city),
                phoneVerified: const Value(true),
              ),
            );
        await (_db.update(_db.institutions)
              ..where((t) => t.id.equals(institutionId)))
            .write(const InstitutionsCompanion(userId: Value(userId)));
      });
    }

    final session = await _sessionFor(userId);
    if (session == null) throw const AuthException('Compte introuvable.');
    await _openSession(session);
    return session;
  }

  /// Ouvre une session parent de démonstration (§55-bis).
  ///
  /// Cree la fiche et un enfant au premier appel : un espace parent vide ne
  /// permet pas de juger l'ecran.
  Future<AuthSession> loginAsDemoParent() async {
    const userId = 'user_parent_demo';
    const parentId = 'parent_demo';

    final existing = await (_db.select(
      _db.users,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();

    if (existing == null) {
      await _db.transaction(() async {
        await _db
            .into(_db.users)
            .insert(
              UsersCompanion.insert(
                id: userId,
                role: UserRole.parent.code,
                phone: '+224600000002',
                firstName: const Value('Aïssatou'),
                lastName: const Value('Barry'),
                city: const Value('Conakry'),
                phoneVerified: const Value(true),
              ),
            );
        await _db
            .into(_db.parents)
            .insert(
              ParentsCompanion.insert(
                id: parentId,
                userId: userId,
                city: const Value('Conakry'),
                district: const Value('Ratoma'),
              ),
            );
        await _db
            .into(_db.children)
            .insert(
              ChildrenCompanion.insert(
                id: 'child_demo',
                parentId: parentId,
                firstName: 'Fatoumata',
                levelId: const Value('lvl_lycee'),
                schoolName: const Value('Lycée Kalou'),
              ),
            );
      });
    }

    final session = await _sessionFor(userId);
    if (session == null) throw const AuthException('Compte introuvable.');
    await _openSession(session);
    return session;
  }

  Future<void> _openSession(AuthSession session) async {
    await _store.saveSessionUser(session.userId);
    await _db.audit(
      action: 'LOGIN',
      actorId: session.userId,
      entity: 'user',
      entityId: session.userId,
      metadata: session.role.code,
    );
  }

  /// Retient la formule choisie à l'inscription, sans l'accorder.
  ///
  /// Voir `Users.pendingPlan` : l'écrire dans `plan` offrirait l'abonnement,
  /// puisque rien n'est encaissé à l'inscription.
  Future<void> rememberPlanChoice(String userId, String planCode) async {
    await (_db.update(_db.users)..where((t) => t.id.equals(userId))).write(
      UsersCompanion(
        pendingPlan: Value(planCode),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  /// Enregistre ce qu'un établissement cherche, tel qu'il l'a déclaré.
  ///
  /// Ces six réponses n'avaient aucune colonne : neuf des dix-sept questions
  /// du parcours établissement étaient jetées. Elles décrivent un besoin
  /// permanent — c'est ce qui préremplit la prochaine offre, et ce qui permet
  /// de classer les professeurs dès l'accueil.
  Future<void> setRecruitmentNeeds({
    required String institutionId,
    String? managerRole,
    List<String> neededSubjectIds = const [],
    List<String> priorities = const [],
    String? teacherLocation,
    List<String> workDays = const [],
    String? workStart,
    String? workEnd,
    String? maxDistance,
  }) async {
    await (_db.update(
      _db.institutions,
    )..where((t) => t.id.equals(institutionId))).write(
      InstitutionsCompanion(
        managerRole: Value(managerRole),
        neededSubjectIds: Value(neededSubjectIds.join(',')),
        priorities: Value(priorities.join(',')),
        teacherLocation: Value(teacherLocation),
        workDays: Value(workDays.join(',')),
        workStart: Value(workStart),
        workEnd: Value(workEnd),
        maxDistance: Value(maxDistance),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );

    // Pas de mise en file : `institution` est dans `REFUSED` côté serveur —
    // « une fiche d'établissement se modifie depuis son espace » — et la
    // pousser ici ne produirait qu'un refus dans le journal.
  }

  /// Souscrit une formule, ou la change.
  ///
  /// L'echeance est posee a un mois : le prelevement recurrent en mobile
  /// money demande un mandat que l'agregateur ne fournit pas encore, donc
  /// chaque mois se renouvelle a la main. Ecrire une date plutot qu'un
  /// booleen evite qu'un abonnement impaye reste ouvert indefiniment.
  Future<AuthSession?> subscribe(String userId, String planCode) async {
    final fin = DateTime.now();
    await (_db.update(_db.users)..where((t) => t.id.equals(userId))).write(
      UsersCompanion(
        plan: Value(planCode),
        planRenewsAt: Value(DateTime(fin.year, fin.month + 1, fin.day)),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
    await _db.audit(action: 'SUBSCRIBE', actorId: userId);
    return _sessionFor(userId);
  }

  Future<void> logout() async {
    final userId = await _store.sessionUserId;
    await _store.clearSession();
    if (userId != null) {
      await _db.audit(action: 'LOGOUT', actorId: userId);
    }
  }

  /// Suppression du compte local et de ses données (§52).
  Future<void> deleteLocalData() async {
    await _db.clearUserData();
    await _store.wipe();
  }
}
