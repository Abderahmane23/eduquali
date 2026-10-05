import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/domain/entities/onboarding_spec.dart';

/// Les trois règles ajoutées le 02/10.
///
/// Le catalogue de démonstration, le contact d'une expérience, et la cloche
/// de l'accueil. Les trois ont en commun de casser en silence : des données
/// qui divergent, une colonne qui manque, une pastille qui ne s'allume pas.
void main() {
  Map<String, dynamic> lire(String chemin) =>
      jsonDecode(File(chemin).readAsStringSync()) as Map<String, dynamic>;

  group('Le catalogue de démonstration', () {
    test('est le même pour les deux clients', () {
      // Il ne l'était pas : vérifié le 02/10, le web portait 13 matières sur
      // 24 — onze manquaient, dont la philosophie, l'EPS et toutes les
      // filières techniques. Deux copies à la main d'un fichier partagé
      // finissent toujours par différer, et une liste plus courte n'est pas
      // une erreur, donc rien ne le signalait.
      final mobile = File('assets/seed/catalog.json').readAsStringSync();
      final web = File('../web/public/data/catalog.json').readAsStringSync();
      final source = File('../../shared/seed/catalog.json').readAsStringSync();

      expect(mobile, source, reason: 'le mobile a divergé de la source');
      expect(web, source, reason: 'le web a divergé de la source');
    });

    test('porte trente professeurs, tous avec des cours à domicile', () {
      final catalogue = lire('assets/seed/catalog.json');
      final profs = catalogue['demoTeachers'] as List<dynamic>;
      final offres = catalogue['tutoringServices'] as List<dynamic>;

      expect(profs.length, greaterThanOrEqualTo(30));
      expect(
        catalogue['jobs'],
        hasLength(greaterThanOrEqualTo(17)),
        reason: 'dix offres d’emploi ont été ajoutées aux sept d’origine',
      );

      // La règle, pas le nombre : sans offre, un professeur est invisible du
      // côté famille — le filtre du 26/09 ne garde que ceux qui se déplacent.
      final avecOffre = {
        for (final o in offres) (o as Map<String, dynamic>)['teacherId'],
      };
      for (final prof in profs) {
        expect(
          avecOffre,
          contains((prof as Map<String, dynamic>)['id']),
          reason: '${prof['id']} ne propose aucun cours à domicile',
        );
      }
    });

    test('ne déclare que des classes du cycle de la matière', () {
      // Une classe hors cycle casse la liste des matières du professeur : le
      // filtre ne la retient pas, et la matière devient introuvable sur sa
      // propre fiche. C'est ce qui avait vidé l'étape « Quelles matières »
      // le 24/09.
      final catalogue = lire('assets/seed/catalog.json');
      final cycles = <String, Set<String>>{
        for (final s in catalogue['subjects'] as List<dynamic>)
          (s as Map<String, dynamic>)['id'] as String: {
            for (final c in s['cycles'] as List<dynamic>) c as String,
          },
      };
      final cycleDe = <String, String?>{
        for (final l in catalogue['levels'] as List<dynamic>)
          (l as Map<String, dynamic>)['id'] as String: l['cycle'] as String?,
      };

      for (final prof in catalogue['demoTeachers'] as List<dynamic>) {
        for (final paire
            in (prof as Map<String, dynamic>)['levels'] as List<dynamic>) {
          final couple = (paire as List<dynamic>).cast<String>();
          expect(
            cycles[couple[0]],
            contains(cycleDe[couple[1]]),
            reason: '${prof['id']} : ${couple[1]} hors cycle de ${couple[0]}',
          );
        }
      }
    });
  });

  group('Les matières du professeur', () {
    test('restent toutes atteignables, quelles que soient les classes', () {
      // Le filtre par classe restreignait : 6 matières sur 24 pour le
      // primaire, 15 pour le lycée. Sur un champ de saisie il ordonne
      // désormais — les matières des classes choisies viennent en tête, les
      // autres restent à une frappe.
      final ecran = File(
        'lib/presentation/screens/onboarding/onboarding_steps.dart',
      ).readAsStringSync();
      final position = ecran.indexOf('if (step.searchable)');
      expect(position, greaterThan(0));
      final bloc = ecran.substring(position, position + 1600);

      expect(
        bloc,
        contains('for (final option in autres)'),
        reason:
            'les matières hors des classes choisies doivent rester dans '
            'la liste',
      );
      expect(bloc, contains('Hors des classes choisies'));
    });

    test('le parcours professeur demande bien la saisie assistée', () {
      final spec = OnboardingFlowSpec.fromJson(
        lire('assets/onboarding/teacher_onboarding.json'),
      );
      final etape = spec.steps.firstWhere((s) => s.id == 'subjects');
      expect(etape.searchable, isTrue);
      expect(
        etape.optionsFilter,
        isNotNull,
        reason: 'le filtre sert à ordonner',
      );
    });
  });

  group('L’expérience déclarée', () {
    test('peut porter un contact à appeler', () async {
      // Un justificatif se falsifie ; un appel à l'établissement, non.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

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
      await db
          .into(db.teacherExperiences)
          .insert(
            TeacherExperiencesCompanion.insert(
              id: 'e1',
              teacherId: 't1',
              institutionName: 'Lycée Donka',
              position: 'Professeur de mathématiques',
              startDate: DateTime(2021, 9),
              contactPhone: const Value('+224622334455'),
              contactEmail: const Value('direction@lyceedonka.gn'),
            ),
          );

      final relu = await db.select(db.teacherExperiences).getSingle();
      expect(relu.contactPhone, '+224622334455');
      expect(relu.contactEmail, 'direction@lyceedonka.gn');
    });

    test('reste enregistrable sans contact', () async {
      // Exiger le contact ferait abandonner la fiche : un professeur ne l'a
      // pas toujours sous la main, et il doit pouvoir compléter plus tard.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

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
      await db
          .into(db.teacherExperiences)
          .insert(
            TeacherExperiencesCompanion.insert(
              id: 'e1',
              teacherId: 't1',
              institutionName: 'Lycée Donka',
              position: 'Professeur',
              startDate: DateTime(2021, 9),
            ),
          );

      final relu = await db.select(db.teacherExperiences).getSingle();
      expect(relu.contactPhone, isNull);
      expect(relu.contactEmail, isNull);
    });
  });

  group('La cloche de l’accueil', () {
    test('ouvre les notifications sur les trois accueils', () {
      // Celle du professeur ouvrait « Paiements » et sa pastille suivait les
      // sommes à venir : elle promettait des nouvelles et menait à une
      // facture.
      for (final chemin in [
        'lib/presentation/screens/dashboards/teacher_dashboard.dart',
        'lib/presentation/screens/dashboards/parent_dashboard.dart',
        'lib/presentation/screens/dashboards/institution_dashboard.dart',
      ]) {
        final source = File(chemin).readAsStringSync();
        final cloche = source.indexOf('Icons.notifications_none');
        expect(cloche, greaterThan(0), reason: chemin);

        // La fenetre couvre l'appel entier, commentaire compris.
        final bloc = source.substring(cloche, cloche + 800);
        expect(
          bloc,
          contains('Routes.notifications'),
          reason: '$chemin : la cloche doit ouvrir les notifications',
        );
        expect(
          bloc,
          contains('badge: nonLues > 0'),
          reason: '$chemin : la pastille doit suivre ce qui n’est pas lu',
        );
      }
    });
  });
}
