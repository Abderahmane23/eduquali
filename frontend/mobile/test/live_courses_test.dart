import 'dart:convert';
import 'dart:io';

import 'package:veriprof/core/scheduling/slots.dart';
import 'package:veriprof/domain/entities/live_models.dart';
import 'package:veriprof/presentation/screens/live/live_presence_strip.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les cours en direct sur le téléphone (02/10).
///
/// Quatre règles portent cette fonction, et chacune se casse en silence :
///
///   1. le fichier de créneaux doit être **embarqué**, pas seulement présent sur
///      le disque du développeur ;
///   2. la fenêtre d'entrée doit être **la même que celle du serveur**, sinon
///      l'écran propose un bouton qui échoue ou cache une séance ouverte ;
///   3. le parent ne voit **aucune image** de son enfant ;
///   4. une lecture de JSON ne doit pas lever au milieu d'une liste — un écran
///      vide avec un message est récupérable, un écran rouge non.
void main() {
  // `rootBundle` n'existe pas sans liaison de test : les ressources declarees
  // dans pubspec.yaml ne sont servies qu'une fois celle-ci initialisee. Dans un
  // `test()` ordinaire — a la difference d'un `testWidgets()` — c'est a l'appelant
  // de le faire, et l'oublier fait echouer la lecture d'asset sans dire pourquoi.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('le fichier de créneaux est vraiment embarqué', () {
    test('assets/scheduling est déclaré dans pubspec.yaml', () {
      // Le défaut trouvé le 02/10 : `shared/onboarding/sync.mjs` recopiait
      // `slots.json` dans `assets/scheduling/` depuis des semaines, et le
      // dossier n'était PAS déclaré. Flutter n'embarque que ce qui est listé :
      // le fichier existait sur le disque et manquait dans l'APK, donc le
      // premier écran de cours en direct aurait levé chez l'usager.
      // Lu en texte plutot qu'avec un analyseur YAML : ajouter le paquet `yaml`
      // au projet pour verifier une ligne couterait plus que ce que ca
      // rapporte, et la ligne est exacte au caractere pres.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final declaration = RegExp(
        r'^\s*-\s*assets/scheduling/\s*$',
        multiLine: true,
      );
      expect(
        declaration.hasMatch(pubspec),
        isTrue,
        reason:
            'sans cette ligne, slots.json n’est pas dans l’APK et '
            'SlotGrid.load() lève à l’exécution',
      );
    });

    test('le fichier embarqué porte bien six créneaux de 90 minutes', () {
      // La durée est vérifiée par `sync.mjs` à la source ; ici on vérifie que
      // c'est bien ce fichier-là qui est arrivé dans les ressources.
      final brut = File('assets/scheduling/slots.json').readAsStringSync();
      final grille = SlotGrid.fromJson(
        jsonDecode(brut) as Map<String, dynamic>,
      );
      expect(grille.sessionMinutes, 90);
      expect(grille.slots, hasLength(6));
      // Deux créneaux par jour de semaine, quatre le samedi : 14 occurrences.
      final occurrences = grille.slots.fold<int>(
        0,
        (total, slot) => total + slot.days.length,
      );
      expect(occurrences, 14);
    });

    test('la grille se charge depuis les ressources', () async {
      SlotGrid.resetCacheForTests();
      final grille = await SlotGrid.load(bundle: rootBundle);
      expect(grille.labelOf('WD_18'), '18 h – 19 h 30');
      // Un créneau inconnu rend son identifiant plutôt que du vide : laid, mais
      // lisible. Masquer l'horaire serait pire.
      expect(grille.labelOf('INCONNU'), 'INCONNU');
      expect(grille.dayLabel('SAT'), 'Samedi');
    });

    test('les jours se déduisent de la date', () async {
      SlotGrid.resetCacheForTests();
      final grille = await SlotGrid.load(bundle: rootBundle);
      // 5 octobre 2026 est un lundi.
      expect(grille.dayOf(DateTime(2026, 10, 5)), 'MON');
      expect(grille.dayOf(DateTime(2026, 10, 10)), 'SAT');
      expect(grille.dayOf(DateTime(2026, 10, 11)), 'SUN');
      expect(grille.slotsOn('SAT'), hasLength(4));
      expect(grille.slotsOn('MON'), hasLength(2));
      // Dans l'ordre horaire : une grille qui commence à 20 h ne se lit pas.
      expect(grille.slotsOn('SAT').first.start, '10:00');
    });
  });

  group('la fenêtre d’entrée suit celle du serveur', () {
    MySession seance({required DateTime debut, String statut = 'CONFIRMED'}) =>
        MySession(
          enrolmentId: 'se-1',
          enrolmentStatus: statut,
          sessionId: 'ls-1',
          startsAt: debut,
          durationMinutes: 90,
          status: 'PLANNED',
          price: 45000,
        );

    test('ouvre quinze minutes avant et ferme trente après la fin', () {
      final debut = DateTime(2026, 10, 6, 18);
      final cours = seance(debut: debut);

      // Les deux bornes sont celles de `/live/sessions/:id/token`. Montrer un
      // bouton hors fenêtre donnerait une erreur à quelqu'un qui n'a rien fait
      // de mal ; le cacher dans la fenêtre ferait croire la place perdue.
      expect(
        cours.canJoinAt(debut.subtract(const Duration(minutes: 16))),
        isFalse,
      );
      expect(
        cours.canJoinAt(debut.subtract(const Duration(minutes: 14))),
        isTrue,
      );
      expect(cours.canJoinAt(debut.add(const Duration(minutes: 89))), isTrue);
      // 90 + 30 = 120 minutes après le début.
      expect(cours.canJoinAt(debut.add(const Duration(minutes: 119))), isTrue);
      expect(cours.canJoinAt(debut.add(const Duration(minutes: 121))), isFalse);
    });

    test('« passée » commence là où la fenêtre se ferme', () {
      // Les deux notions doivent coïncider : un trou entre elles afficherait
      // une séance ni rejoignable ni rediffusable.
      final debut = DateTime(2026, 10, 6, 18);
      final cours = seance(debut: debut);
      for (final minutes in [100, 119, 121, 200]) {
        final quand = debut.add(Duration(minutes: minutes));
        expect(
          cours.canJoinAt(quand) || cours.isOverAt(quand),
          isTrue,
          reason: 'à +$minutes min, la séance n’est ni ouverte ni passée',
        );
      }
    });

    test('une place non payée se distingue d’une place payée', () {
      final debut = DateTime(2026, 10, 6, 18);
      expect(seance(debut: debut).isPaid, isTrue);
      expect(seance(debut: debut, statut: 'PENDING').isPaid, isFalse);
    });
  });

  group('une présence n’est pas une surveillance', () {
    test('le modèle ne porte aucun champ d’image ni de salle', () {
      // Ce qui n'existe pas dans le type ne peut pas être affiché par
      // distraction. Le serveur ne rend qu'un prénom, une matière et des
      // minutes — ce test fige la forme côté client.
      final source = File(
        'lib/domain/entities/live_models.dart',
      ).readAsStringSync();
      final classe = source.substring(
        source.indexOf('class LivePresence'),
        source.indexOf('/// Le temps de cours cumulé'),
      );
      for (final interdit in ['token', 'room', 'track', 'videoId', 'camera']) {
        expect(
          classe.toLowerCase(),
          isNot(contains(interdit.toLowerCase())),
          reason: 'LivePresence ne doit rien porter qui touche à l’image',
        );
      }
    });

    test('le bandeau n’affiche pas de flux', () {
      final source = File(
        'lib/presentation/screens/live/live_presence_strip.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('VideoPlayer')));
      expect(source, isNot(contains('livekit')));
      // Et il se taît quand il n'y a rien à dire : un bandeau vide en tête du
      // tableau de bord serait du bruit permanent.
      expect(source, contains('if (_presences.isEmpty) return const SizedBox'));
      // La minuterie s'arrête : sinon elle consomme des données sur un écran
      // que personne ne regarde.
      expect(source, contains('_minuterie?.cancel()'));
    });

    test('la séance réservée ne transporte pas l’identifiant de la vidéo', () {
      // Il n'est lisible qu'accompagné d'une signature ; le faire circuler
      // n'apporterait qu'une occasion de fuite.
      final seance = MySession.fromJson({
        'enrolmentId': 'se-1',
        'sessionId': 'ls-1',
        'startsAt': '2026-10-06T18:00:00Z',
        'replay': 'READY',
      });
      expect(seance.replay, 'READY');
      final source = File(
        'lib/domain/entities/live_models.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('recordingVideoId')));
    });
  });

  group('la lecture du JSON ne lève jamais', () {
    test('un objet vide donne des valeurs par défaut', () {
      // Le serveur et ces types évoluent séparément. Une exception au milieu
      // d'une liste donnerait un écran rouge ; une valeur par défaut donne un
      // écran incomplet, qu'on peut lire.
      final seance = LiveSessionSummary.fromJson(const {});
      expect(seance.durationMinutes, 90);
      expect(seance.seatsLeft, 0);
      expect(seance.subject, isNull);

      final resume = StudySummary.fromJson(const {});
      expect(resume.totalMinutes, 0);
      expect(resume.isEmpty, isTrue);
      expect(resume.perChild, isEmpty);
    });

    test('un champ du mauvais type ne casse pas la lecture', () {
      final seance = LiveSessionSummary.fromJson(const {
        'durationMinutes': '45',
        'seatsLeft': 3.7,
        'price': null,
        'subject': 'Mathématiques',
        'title': '   ',
      });
      expect(seance.durationMinutes, 45);
      expect(seance.seatsLeft, 4);
      expect(seance.price, 0);
      // Une chaîne là où un objet est attendu : nul, pas une exception.
      expect(seance.subject, isNull);
      // Un titre fait d'espaces vaut un titre absent, sinon l'écran affiche un
      // blanc à la place du nom de la matière.
      expect(seance.title, isNull);
    });

    test('une ligne de temps sans libellé est écartée', () {
      final resume = StudySummary.fromJson(const {
        'totalMinutes': 180,
        'sessions': 2,
        'perChild': [
          {'childName': 'Fatoumata', 'minutes': 90},
          {'childName': '', 'minutes': 90},
          'pas un objet',
        ],
      });
      expect(resume.perChild, hasLength(1));
      expect(resume.perChild.first.label, 'Fatoumata');
    });

    test('la rediffusion n’expose son flux que lorsqu’elle est prête', () {
      final enCours = SessionReplay.fromJson(const {
        'status': 'TRANSFERRING',
        'available': false,
      });
      expect(enCours.available, isFalse);
      expect(enCours.hls, isNull);

      final prete = SessionReplay.fromJson(const {
        'status': 'READY',
        'available': true,
        'hls': 'https://vz.b-cdn.net/v/playlist.m3u8?token=abc',
      });
      expect(prete.available, isTrue);
      expect(prete.hls, isNotNull);
    });

    test('le bac à sable est porté jusqu’à l’écran', () {
      // Une démonstration en bac à sable qui passe pour un encaissement réel ne
      // se découvre qu'en cherchant l'argent.
      final resultat = EnrolmentOutcome.fromJson(const {
        'enrolmentId': 'se-9',
        'status': 'PENDING',
        'payment': 'awaiting_confirmation',
        'sandbox': true,
      });
      expect(resultat.sandbox, isTrue);
      expect(resultat.payment, 'awaiting_confirmation');
    });
  });

  group('les durées se lisent', () {
    test('minutes en dessous d’une heure, heures au-delà', () {
      expect(dureeLongue(0), '0 min');
      expect(dureeLongue(45), '45 min');
      expect(dureeLongue(60), '1 h');
      expect(dureeLongue(90), '1 h 30');
      // Deux chiffres pour les minutes : « 3 h 5 » se lit mal.
      expect(dureeLongue(185), '3 h 05');
    });
  });
}
