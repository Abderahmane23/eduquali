import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/domain/usecases/offer_visibility.dart';

/// Onglet Offres du professeur (§17) — demandé le 13/09.
///
/// Ni recherche, ni filtres : seulement les offres des matières du professeur.
void main() {
  // (identifiant d'offre, matière)
  const offers = [
    ('o1', 'sub_math'),
    ('o2', 'sub_phys'),
    ('o3', 'sub_math'),
    ('o4', 'sub_fran'),
  ];

  List<String> visible(Set<String> subjects) => [
    for (final o in offersInSubjects(
      offers,
      teacherSubjectIds: subjects,
      subjectOf: (offer) => offer.$2,
    ))
      o.$1,
  ];

  group('Offres montrées au professeur', () {
    test('seulement celles de ses matières', () {
      expect(visible({'sub_math'}), ['o1', 'o3']);
    });

    test('toutes ses matières, pas seulement la première', () {
      expect(visible({'sub_math', 'sub_fran'}), ['o1', 'o3', 'o4']);
    });

    test('aucune quand il n’a déclaré aucune matière', () {
      // L'écran invite alors à ajouter ses matières au lieu de tout montrer.
      expect(visible({}), isEmpty);
    });

    test('aucune quand aucune offre ne correspond', () {
      expect(visible({'sub_angl'}), isEmpty);
    });

    test('l’ordre reçu est conservé', () {
      // Le classement par compatibilité se fait ensuite : ce filtre ne doit
      // pas le défaire.
      expect(visible({'sub_math', 'sub_phys'}), ['o1', 'o2', 'o3']);
    });
  });

  group('La liste ne sort jamais des matières du professeur', () {
    // Le 16/09, recherche et filtres avaient été retirés parce qu'un filtre
    // mal réglé affichait un écran vide qu'on ne savait pas expliquer. La
    // maquette du 23/09 les fait revenir — mais posés sur une liste déjà
    // restreinte aux matières déclarées.
    //
    // Ce qui protégeait vraiment n'était donc pas l'absence de champ de
    // saisie : c'était la portée de la liste. C'est elle qu'on vérifie ici.
    final tab = File(
      'lib/presentation/screens/teacher/teacher_offers_tab.dart',
    ).readAsStringSync();

    test('elle vient du fournisseur restreint aux matières', () {
      expect(tab.contains('opportunitiesProvider'), isTrue);
    });

    test('aucun autre fournisseur d’offres n’est lu', () {
      // Un fournisseur non filtré ramènerait des postes de chimie à un
      // professeur de lettres, et le filtre ne pourrait plus rattraper.
      for (final large in [
        'allJobOffersProvider',
        'jobSearchProvider',
        'institutionJobsProvider',
      ]) {
        expect(tab.contains(large), isFalse, reason: '$large élargit la liste');
      }
    });

    test('un filtre qui ne rend rien propose de revenir', () {
      // C'est le vrai remède à l'écran vide de septembre : on dit pourquoi
      // il est vide, et on offre le geste qui le remplit.
      expect(tab.contains('Tout afficher'), isTrue);
    });

    test('l’ancien appareillage de filtres n’est pas revenu', () {
      final shell = File(
        'lib/presentation/screens/teacher/teacher_shell.dart',
      ).readAsStringSync();
      for (final gone in [
        '_FilterButton',
        '_JobFilterSheet',
        '_FilterDropdown',
      ]) {
        expect(shell.contains(gone), isFalse, reason: '$gone retiré le 16/09');
      }
    });

    test('le modèle de filtres n’existe plus', () {
      final models = File(
        'lib/domain/entities/job_models.dart',
      ).readAsStringSync();
      expect(models.contains('class JobSearchFilters'), isFalse);
    });
  });
}
