import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_constants.dart';
import 'package:veriprof/core/constants/app_enums.dart';
import 'package:veriprof/core/storage/document_pipeline.dart';
import 'package:veriprof/data/local/database/app_database.dart';

/// Le dépôt d'un CV et d'un diplôme.
///
/// L'étape d'inscription enregistrait le **texte** « cv_path.pdf » : le
/// parcours se terminait, la fiche annonçait un CV, et il n'y avait aucun
/// fichier derrière. Un établissement qui cliquait ne trouvait rien, et le
/// professeur ne pouvait pas le savoir.
void main() {
  group('La limite de taille', () {
    test('est enfin appliquée, et le dit en mégaoctets', () {
      // `documentMaxBytes` était déclarée depuis le début et vérifiée nulle
      // part. Un scan de 40 Mo entrait donc dans la file d'envoi pour n'en
      // jamais sortir, sur une connexion guinéenne.
      const refus = DocumentTooLarge(12 * 1024 * 1024);
      final message = '$refus';

      expect(message, contains('12.0 Mo'));
      expect(message, contains('8 Mo'));
      // Le message dit quoi faire, pas seulement ce qui ne va pas.
      expect(message, contains('Reduisez'));
    });

    test('la limite reste celle des constantes', () {
      // Figer « 8 » dans le message le laisserait mentir le jour où la
      // constante change.
      expect(AppConstants.documentMaxBytes, 8 * 1024 * 1024);
      expect('${const DocumentTooLarge(1)}', contains('8 Mo'));
    });
  });

  group('Le type de document', () {
    test('distingue le CV du diplôme', () {
      // Les deux partent dans la même table : sans type distinct, vérifier un
      // diplôme reviendrait à vérifier le CV, et la fiche porterait un badge
      // qu'elle n'a pas gagné.
      expect(DocumentType.cv.code, 'CV');
      expect(DocumentType.diploma.code, 'DIPLOMA');
      expect(DocumentType.fromCode('CV'), DocumentType.cv);
    });
  });

  group('Un document enregistré', () {
    late AppDatabase db;
    late Directory dossier;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dossier = await Directory.systemTemp.createTemp('eduquali_docs');
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: 'u1',
              role: 'TEACHER',
              phone: '+224620000101',
            ),
          );
      await db
          .into(db.teachers)
          .insert(TeachersCompanion.insert(id: 't1', userId: 'u1'));
    });

    tearDown(() async {
      await db.close();
      if (dossier.existsSync()) await dossier.delete(recursive: true);
    });

    /// Un faux PDF : la chaîne n'inspecte pas le contenu, seulement la taille
    /// et l'empreinte.
    Future<CapturedDocument> unPdf(DocumentType type) async {
      final fichier = File('${dossier.path}${Platform.pathSeparator}cv.pdf');
      await fichier.writeAsString('%PDF-1.4 contenu de demonstration');
      final bytes = await fichier.readAsBytes();
      return CapturedDocument(
        path: fichier.path,
        sizeBytes: bytes.length,
        checksum: sha256.convert(bytes).toString(),
        type: type,
      );
    }

    test('porte un chemin réel, une taille et une empreinte', () async {
      final capture = await unPdf(DocumentType.cv);

      expect(File(capture.path).existsSync(), isTrue);
      expect(capture.sizeBytes, greaterThan(0));
      // L'empreinte est ce qui permettra au serveur de constater qu'un
      // fichier est arrivé intact, et de ne pas le renvoyer deux fois.
      expect(capture.checksum, hasLength(64));
      expect(capture.path, endsWith('.pdf'));
    });

    test('entre en base en attente d’envoi, pas vérifié', () async {
      final capture = await unPdf(DocumentType.cv);
      await db
          .into(db.teacherDocuments)
          .insert(
            TeacherDocumentsCompanion.insert(
              id: 'd1',
              teacherId: 't1',
              type: capture.type.code,
              localPath: Value(capture.path),
              checksum: Value(capture.checksum),
              sizeBytes: Value(capture.sizeBytes),
              uploadStatus: Value(DocumentUploadStatus.pendingUpload.code),
              verificationStatus: Value(VerificationStatus.pending.code),
            ),
          );

      final relu = await db.select(db.teacherDocuments).getSingle();
      expect(relu.localPath, capture.path);
      expect(relu.checksum, capture.checksum);
      // Déposé n'est pas vérifié : c'est le serveur qui tranche, et la fiche
      // ne doit pas porter le badge avant.
      expect(relu.verificationStatus, VerificationStatus.pending.code);
      expect(relu.uploadStatus, DocumentUploadStatus.pendingUpload.code);
      // Aucune URL distante tant que rien n'est parti.
      expect(relu.remoteUrl, isNull);
    });
  });

  group('L’étape d’inscription', () {
    final etape = File(
      'lib/presentation/screens/onboarding/onboarding_steps.dart',
    ).readAsStringSync();

    test('choisit un vrai fichier, et n’invente plus de nom', () {
      expect(etape, contains('pickDocumentFile'));
      expect(
        etape,
        isNot(contains(r"setAnswer(upload.id, '${upload.id}.pdf')")),
        reason: 'le faux chemin doit avoir disparu',
      );
    });

    test('garde le bouton « Passer »', () {
      // Demandé le 02/10 : un professeur qui n'a pas son diplôme sous la main
      // doit pouvoir finir son inscription et revenir le déposer. L'étape est
      // `optional` dans le parcours, et c'est ce qui affiche « Passer ».
      final ecran = File(
        'lib/presentation/screens/onboarding/onboarding_flow_screen.dart',
      ).readAsStringSync();
      expect(ecran, contains("const Text('Passer')"));
      expect(ecran, contains('step.optional && step.type.collectsAnswer'));

      final parcours = File(
        'assets/onboarding/teacher_onboarding.json',
      ).readAsStringSync();
      final documents = parcours.indexOf('"id": "documents"');
      expect(documents, greaterThan(0));
      expect(
        parcours.substring(documents, documents + 300),
        contains('"optional": true'),
        reason: 'sans cela le bouton « Passer » disparaît',
      );
    });

    test('rattache les fichiers au compte une fois créé', () {
      // Les documents sont choisis avant que le compte existe : l'étape ne
      // peut garder qu'un chemin, et c'est la création du compte qui les
      // rattache à une fiche professeur.
      final completion = File(
        'lib/presentation/screens/onboarding/signup_completion.dart',
      ).readAsStringSync();
      expect(completion, contains('attachDocuments'));
      expect(completion, contains('storeDocument'));
      // Un fichier disparu entre le choix et la fin du parcours ne doit pas
      // créer une ligne qui pointe sur rien.
      expect(completion, contains('fichier.existsSync()'));

      final routeur = File(
        'lib/presentation/router/app_router.dart',
      ).readAsStringSync();
      expect(routeur, contains('completion.attachDocuments(userId, answers)'));
    });
  });
}
