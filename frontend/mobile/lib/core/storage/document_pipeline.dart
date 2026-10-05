import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../constants/app_enums.dart';

/// Résultat d'une capture : fichier local pret a etre televerse.
class CapturedDocument {
  const CapturedDocument({
    required this.path,
    required this.sizeBytes,
    required this.checksum,
    required this.type,
  });

  final String path;
  final int sizeBytes;
  final String checksum;
  final DocumentType type;
}

/// Leve quand le fichier choisi ne peut pas etre accepte.
///
/// Son message s'affiche tel quel : il dit ce qui bloque et ce qu'il faut
/// faire, parce qu'un refus muet se lit comme une panne.
class DocumentTooLarge implements Exception {
  const DocumentTooLarge(this.sizeBytes);

  final int sizeBytes;

  @override
  String toString() {
    final mo = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
    final max = AppConstants.documentMaxBytes ~/ (1024 * 1024);
    return 'Ce fichier pese $mo Mo, au-dela de la limite de $max Mo. '
        'Reduisez-le ou photographiez seulement la page utile.';
  }
}

/// Un fichier de cours choisi par le professeur : video ou ressource.
///
/// Distinct de [CapturedDocument], qui porte un [DocumentType] et une
/// empreinte destinee a la verification. Ici rien n'est verifie par un agent :
/// c'est le professeur qui publie son propre contenu, et ce qu'on a besoin de
/// savoir est le chemin, la taille et la duree.
class CapturedMedia {
  const CapturedMedia({
    required this.path,
    required this.sizeBytes,
    required this.name,
  });

  final String path;
  final int sizeBytes;

  /// Le nom du fichier d'origine, propose comme titre par defaut.
  ///
  /// « chapitre1_fonctions.mp4 » dit quelque chose ; le nom genere par la
  /// copie ne dit rien, et le professeur devrait tout retaper.
  final String name;
}

/// Leve quand un fichier de cours depasse la limite de son genre.
///
/// Porte la limite au lieu de la lire dans les constantes : une video et une
/// ressource n'ont pas la meme, et un message qui annonce la mauvaise borne
/// envoie le professeur reduire un fichier qui passait.
class MediaTooLarge implements Exception {
  const MediaTooLarge({required this.sizeBytes, required this.maxBytes});

  final int sizeBytes;
  final int maxBytes;

  @override
  String toString() {
    final mo = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
    final max = maxBytes ~/ (1024 * 1024);
    return 'Ce fichier pese $mo Mo, au-dela de la limite de $max Mo. '
        'Decoupez-le en plusieurs parties, ou reduisez sa qualite.';
  }
}

/// Pipeline documentaire (§46) :
/// Camera -> fichier temporaire -> compression -> stockage local sécurisé.
///
/// L'upload et la vérification serveur sont pris en charge par la file de
/// synchronisation une fois le document enregistre localement.
class DocumentPipeline {
  DocumentPipeline({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Capture depuis la camera (selfie, piece d'identité, diplôme).
  Future<CapturedDocument?> captureFromCamera(
    DocumentType type, {
    bool frontCamera = false,
  }) async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: frontCamera
          ? CameraDevice.front
          : CameraDevice.rear,
      maxWidth: AppConstants.documentMaxWidth.toDouble(),
      imageQuality: AppConstants.documentQuality,
    );
    if (file == null) return null;
    return _process(File(file.path), type);
  }

  /// Import depuis la galerie — utile pour un diplôme déjà numerise (§7).
  Future<CapturedDocument?> pickFromGallery(DocumentType type) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: AppConstants.documentMaxWidth.toDouble(),
      imageQuality: AppConstants.documentQuality,
    );
    if (file == null) return null;
    return _process(File(file.path), type);
  }

  /// Choix d'un fichier deja sur l'appareil — un CV, un diplome scanne.
  ///
  /// Distinct de [pickFromGallery] : un CV est presque toujours un PDF, et la
  /// galerie ne montre que des images. Le PDF est copie tel quel, sans
  /// compression — compresser un PDF le casse, et c'est le document que
  /// l'etablissement lira.
  ///
  /// Rend `null` si la personne ferme le selecteur sans choisir. Leve
  /// [DocumentTooLarge] au-dela de la limite : mieux vaut le dire au moment
  /// du choix qu'empiler dans la file d'envoi un fichier qui ne partira
  /// jamais sur une connexion guineenne.
  Future<CapturedDocument?> pickDocumentFile(DocumentType type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: false,
    );
    final chemin = result?.files.singleOrNull?.path;
    if (chemin == null) return null;

    final source = File(chemin);
    final taille = await source.length();
    if (taille > AppConstants.documentMaxBytes) {
      throw DocumentTooLarge(taille);
    }

    final extension = p.extension(chemin).toLowerCase();
    // Une image passe par la compression deja ecrite ; un PDF, non.
    if (extension != '.pdf') return _process(source, type);

    final dir = await _documentsDirectory();
    final nom =
        '${type.code.toLowerCase()}_'
        '${DateTime.now().millisecondsSinceEpoch}$extension';
    final stored = await source.copy(p.join(dir.path, nom));
    final bytes = await stored.readAsBytes();
    return CapturedDocument(
      path: stored.path,
      sizeBytes: bytes.length,
      checksum: sha256.convert(bytes).toString(),
      type: type,
    );
  }

  /// Choix d'une video de cours.
  ///
  /// Aucune compression : reencoder une video sur un telephone d'entree de
  /// gamme prend des minutes et degrade l'image que le professeur a tournee.
  /// Le fichier est copie tel quel dans l'espace prive de l'application —
  /// le cache du selecteur est vide par le systeme sans avertir, et un cours
  /// perdrait ses videos entre deux ouvertures.
  Future<CapturedMedia?> pickCourseVideo() => _pickCourseFile(
    extensions: const ['mp4', 'mov', 'm4v', '3gp', 'webm', 'mkv'],
    maxBytes: AppConstants.courseVideoMaxBytes,
  );

  /// Choix d'une ressource de chapitre : exercice, corrige, fiche.
  Future<CapturedMedia?> pickCourseResource() => _pickCourseFile(
    extensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    maxBytes: AppConstants.courseResourceMaxBytes,
  );

  Future<CapturedMedia?> _pickCourseFile({
    required List<String> extensions,
    required int maxBytes,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: false,
    );
    final choisi = result?.files.singleOrNull;
    final chemin = choisi?.path;
    if (chemin == null) return null;

    final source = File(chemin);
    final taille = await source.length();
    if (taille > maxBytes) {
      throw MediaTooLarge(sizeBytes: taille, maxBytes: maxBytes);
    }

    final dir = await _coursesDirectory();
    // L'horodatage prefixe le nom d'origine : deux « chapitre1.mp4 » venant
    // de deux dossiers ne s'ecrasent pas, et le nom reste lisible dans la
    // liste des fichiers.
    final nom =
        '${DateTime.now().millisecondsSinceEpoch}_'
        '${p.basename(chemin)}';
    final stored = await source.copy(p.join(dir.path, nom));
    return CapturedMedia(
      path: stored.path,
      sizeBytes: taille,
      name: choisi?.name ?? p.basename(chemin),
    );
  }

  /// Compression puis déplacement vers le stockage prive de l'application.
  Future<CapturedDocument> _process(File source, DocumentType type) async {
    final dir = await _documentsDirectory();
    final name =
        '${type.code.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final target = p.join(dir.path, name);

    File stored;
    try {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        target,
        quality: AppConstants.documentQuality,
        minWidth: 1080,
        minHeight: 1080,
        keepExif: false,
      );
      stored = compressed == null
          ? await source.copy(target)
          : File(compressed.path);
    } catch (error) {
      // La compression peut echouer selon le format : on conserve l'original.
      if (kDebugMode) debugPrint('[documents] compression ignoree: $error');
      stored = await source.copy(target);
    }

    final bytes = await stored.readAsBytes();
    return CapturedDocument(
      path: stored.path,
      sizeBytes: bytes.length,
      checksum: sha256.convert(bytes).toString(),
      type: type,
    );
  }

  /// Repertoire prive de l'application, hors espace public partage.
  Future<Directory> _documentsDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'documents'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Repertoire des fichiers de cours, separe des documents de verification.
  ///
  /// Un professeur qui retire un cours efface des videos ; il ne doit pas
  /// risquer d'emporter son diplome au passage.
  Future<Directory> _coursesDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'courses'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Suppression definitive d'un document local (§52 — droit a l'effacement).
  Future<void> deleteLocal(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Vérifié qu'un fichier référence existe toujours sur l'appareil.
  Future<bool> exists(String? path) async {
    if (path == null || path.isEmpty) return false;
    return File(path).exists();
  }
}
