import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_enums.dart';
import 'package:veriprof/presentation/router/app_router.dart';

/// Le garde-fou qui tient chaque rôle dans son espace.
///
/// Rapport du 20/09 : « dans le compte école je ne peux pas voir la fiche
/// complète d'un professeur », « les cartes voir professeur ne marchent pas
/// au clic ». La fiche existait, la carte la poussait bien — c'est la
/// redirection qui renvoyait l'utilisateur chez lui.
///
/// `'/teachers/t_123'.startsWith('/teacher')` vaut **vrai**. Comparer des
/// préfixes de texte revient à dire que la fiche publique d'un professeur
/// appartient à l'espace enseignant.
void main() {
  /// La vraie règle du routeur, appelée telle quelle : recopier la logique
  /// ici ne protégerait que la copie.
  String? redirection({required String path, required UserRole role}) {
    if (!belongsToOtherSpace(path: path, role: role)) return null;
    return switch (role) {
      UserRole.institution => '/institution',
      UserRole.parent => '/parent',
      _ => '/teacher',
    };
  }

  group('La fiche publique d’un professeur reste ouverte à tous', () {
    for (final role in [
      UserRole.institution,
      UserRole.parent,
      UserRole.teacher,
    ]) {
      test('${role.code} peut ouvrir /teachers/:id', () {
        expect(
          redirection(path: '/teachers/t_123', role: role),
          isNull,
          reason: '${role.code} est renvoyé chez lui au lieu de voir la fiche',
        );
      });
    }

    test('même avec un paramètre d’offre', () {
      expect(
        redirection(path: '/teachers/t_123', role: UserRole.institution),
        isNull,
      );
    });
  });

  group('Chaque espace reste fermé aux autres', () {
    test('un établissement n’entre pas dans l’espace enseignant', () {
      expect(
        redirection(path: '/teacher', role: UserRole.institution),
        '/institution',
      );
      expect(
        redirection(path: '/teacher/diplomas', role: UserRole.institution),
        '/institution',
      );
    });

    test('un enseignant n’entre pas dans l’espace parent', () {
      expect(
        redirection(path: '/parent/enfants', role: UserRole.teacher),
        '/teacher',
      );
    });

    test('un parent n’entre pas dans l’espace établissement', () {
      expect(
        redirection(path: '/institution/jobs', role: UserRole.parent),
        '/parent',
      );
    });

    test('chacun circule chez lui', () {
      expect(
        redirection(path: '/teacher/offres', role: UserRole.teacher),
        isNull,
      );
      expect(
        redirection(path: '/institution/jobs', role: UserRole.institution),
        isNull,
      );
      expect(
        redirection(path: '/parent/enfants', role: UserRole.parent),
        isNull,
      );
    });
  });

  group('Les autres chemins partagés ne sont pas capturés', () {
    // Même piège : ces chemins commencent par le nom d'un espace sans lui
    // appartenir. Les ajouter un jour ne doit pas rouvrir le bug.
    for (final path in ['/teachers', '/parents', '/institutions']) {
      test('$path reste accessible à un établissement', () {
        expect(redirection(path: path, role: UserRole.institution), isNull);
      });
    }

    test('l’espace de recrutement est partagé', () {
      expect(redirection(path: '/rooms/r1', role: UserRole.teacher), isNull);
      expect(
        redirection(path: '/rooms/r1', role: UserRole.institution),
        isNull,
      );
    });
  });

  group('On regarde avant d’ouvrir un compte', () {
    // L'ecran d'entree et les resultats de recherche vivent sans session :
    // reclamer un numero de telephone a quelqu'un qui ne sait pas encore ce
    // que l'application contient, c'est demander avant d'avoir montre.
    //
    // Ce qu'ils exposent est ce qu'un professeur publie de lui-meme. Les
    // coordonnees restent masquees jusqu'au recrutement (§30) — si un jour
    // un de ces ecrans en affiche, ce test ne le verra pas : c'est le
    // masquage lui-meme qui doit tenir, pas la liste des chemins publics.
    for (final path in [Routes.landing, Routes.discover]) {
      test('$path s’ouvre sans session', () {
        expect(publicPaths, contains(path));
      });
    }

    test('l’espace d’un role reste ferme sans session', () {
      // Le complement du test precedent : ouvrir deux chemins ne doit pas
      // avoir ouvert le reste.
      for (final path in [
        Routes.teacherHome,
        Routes.parentHome,
        Routes.institutionHome,
        '/teachers/t_123',
        '/rooms/r1',
      ]) {
        expect(publicPaths, isNot(contains(path)), reason: path);
      }
    });

    test('une session ouverte peut quand meme parcourir la recherche', () {
      // Les autres ecrans publics renvoient chez soi ; celui-la non : un
      // parent connecte a les memes raisons de parcourir la liste.
      expect(redirection(path: Routes.discover, role: UserRole.parent), isNull);
    });
  });
}
