import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/data/remote/chat_api.dart';
import 'package:veriprof/domain/usecases/chat_grouping.dart';

/// Les groupes de discussion (04/10).
///
/// Le contrôle qui compte le plus est le premier : **les routes que ce client
/// appelle existent-elles côté serveur ?** C'est le défaut de `/sync/push` —
/// un client qui postait depuis des mois vers une route absente, les deux
/// côtés cohérents avec eux-mêmes, et rien pour le remarquer.
void main() {
  group('Le client et le serveur parlent de la même chose', () {
    test('chaque route appelée existe dans le Worker', () {
      final client = File('lib/data/remote/chat_api.dart').readAsStringSync();
      final worker = File(
        '../../backend/api/[[...route]].ts',
      ).readAsStringSync();

      final chemins = <String>{};
      for (final trouve in RegExp(
        r"_dio\.\w+<.*?>\(\s*'([^']+)'",
      ).allMatches(client)) {
        // `/chat/groups/$groupId/messages` devient le motif que Hono déclare.
        chemins.add(trouve.group(1)!.replaceAll(RegExp(r'\$\w+'), ':id'));
      }

      // Un plancher : **deux** chemins distincts pour trois appels, parce que
      // lire et écrire un message partagent la même adresse et ne diffèrent
      // que par le verbe. Sans ce plancher, une expression de lecture cassée
      // ferait passer ce test sur un ensemble vide.
      expect(
        chemins.length,
        greaterThanOrEqualTo(2),
        reason:
            'seulement ${chemins.length} chemins détectés '
            '(${chemins.join(', ')}) : le motif ne voit plus tous les appels',
      );

      // Et les deux verbes du chemin partagé existent bien : un `app.get`
      // sans son `app.post` laisserait lire sans pouvoir répondre.
      for (final verbe in ['get', 'post']) {
        expect(
          worker.contains("app.$verbe('/chat/groups/:id/messages'"),
          isTrue,
          reason: 'le serveur n’expose pas $verbe sur les messages d’un groupe',
        );
      }

      for (final chemin in chemins) {
        expect(
          worker.contains("'$chemin'"),
          isTrue,
          reason:
              'le téléphone appelle « $chemin » et le serveur ne l’expose '
              'pas : l’écran resterait vide sans erreur',
        );
      }
    });

    test('l’écran est atteignable depuis les quatre profils', () {
      final router = File(
        'lib/presentation/router/app_router.dart',
      ).readAsStringSync();

      // La route existe, et la liste est bien avant le motif dynamique.
      expect(router.contains('ChatGroupsPage()'), isTrue);
      expect(router.contains('ChatRoomPage('), isTrue);
      expect(
        router.indexOf('Routes.chatGroups'),
        lessThan(router.indexOf("'/discussions/:groupId'")),
        reason:
            'go_router prend la première route qui correspond : le motif '
            'dynamique placé avant capturerait la liste',
      );

      /*
       * L'établissement est le cas qui a motivé ce contrôle.
       *
       * Sa tuile « Mes messages » poussait `Routes.institutionMessages` depuis
       * le 02/10 et **aucune route ne la déclarait** : il pouvait écrire à un
       * professeur et tombait sur l'écran d'erreur en cherchant la réponse.
       */
      expect(
        router.contains('path: Routes.institutionMessages'),
        isTrue,
        reason:
            'l’établissement pousse cette adresse depuis son accueil : sans '
            'route, c’est l’écran d’erreur de go_router',
      );
      expect(router.contains('path: Routes.teacherMessages'), isTrue);

      // La famille et l'universitaire passent par leur coquille.
      final famille = File(
        'lib/presentation/screens/parent/parent_shell.dart',
      ).readAsStringSync();
      expect(famille.contains('ChatGroupsPage()'), isTrue);
    });
  });

  group('Un groupe, tel que la liste le lit', () {
    test('un groupe sans message annonce qu’il est vide', () {
      const groupe = ChatGroup(
        id: 'g1',
        kind: 'COURSE',
        sourceId: 'lc1',
        name: 'Maths Terminale',
      );
      expect(groupe.apercu, 'Pas encore de message');
      expect(groupe.lastAt, isNull);
    });

    test('le dernier message sert d’aperçu', () {
      final groupe = ChatGroup(
        id: 'g1',
        kind: 'COURSE',
        sourceId: 'lc1',
        name: 'Maths Terminale',
        lastBody: 'on corrige l’exercice 3 demain',
        lastAt: DateTime(2026, 10, 4, 18, 2),
      );
      expect(groupe.apercu, contains('exercice 3'));
    });

    test('le professeur se distingue de la classe', () {
      ChatMessage de(String role) => ChatMessage(
        id: 'm',
        groupId: 'g1',
        authorId: 'u',
        authorName: 'Mamadou',
        authorRole: role,
        body: 'page 42',
        sentAt: DateTime(2026, 10, 4),
      );
      // Dans un groupe de quinze, sa consigne ne doit pas se perdre entre deux
      // « bonjour » : son nom s'affiche en ambre, avec une puce.
      expect(de('TEACHER').fromTeacher, isTrue);
      expect(de('PARENT').fromTeacher, isFalse);
      expect(de('STUDENT').fromTeacher, isFalse);
    });

    test('un message confirmé n’est plus en attente', () {
      final provisoire = ChatMessage(
        id: 'local-1',
        groupId: 'g1',
        authorId: 'u',
        authorName: 'Moi',
        authorRole: 'PARENT',
        body: 'bonjour',
        sentAt: DateTime(2026, 10, 4, 18),
        pending: true,
      );
      final confirme = provisoire.withId('srv-9', DateTime(2026, 10, 4, 18, 1));

      expect(provisoire.pending, isTrue);
      expect(confirme.pending, isFalse);
      expect(confirme.id, 'srv-9');
      expect(confirme.body, 'bonjour');
    });
  });

  group('Le regroupement des messages', () {
    final base = DateTime(2026, 10, 4, 18, 0);

    bool suite(String auteurAvant, DateTime avant, String auteur, DateTime q) =>
        prolongeLeBloc(
          precedentAuteur: auteurAvant,
          precedentEnvoi: avant,
          auteur: auteur,
          envoi: q,
        );

    test('le premier message ouvre toujours son bloc', () {
      expect(
        prolongeLeBloc(
          precedentAuteur: null,
          precedentEnvoi: null,
          auteur: 'a',
          envoi: base,
        ),
        isFalse,
      );
    });

    test('deux messages d’affilée du même auteur se regroupent', () {
      expect(
        suite('a', base, 'a', base.add(const Duration(minutes: 1))),
        isTrue,
      );
    });

    test('un autre auteur ouvre un bloc', () {
      expect(
        suite('a', base, 'b', base.add(const Duration(seconds: 10))),
        isFalse,
      );
    });

    test('au-delà de cinq minutes, c’est une nouvelle prise de parole', () {
      expect(
        suite('a', base, 'a', base.add(const Duration(minutes: 5))),
        isFalse,
      );
      expect(
        suite(
          'a',
          base,
          'a',
          base.add(const Duration(minutes: 4, seconds: 59)),
        ),
        isTrue,
      );
    });

    test('une horloge en avance ne cache pas un message', () {
      // Le téléphone d'en face peut être réglé devant : un message daté avant
      // son prédécesseur doit ouvrir son bloc plutôt que de disparaître dans
      // l'en-tête d'un autre.
      expect(
        suite('a', base, 'a', base.subtract(const Duration(minutes: 2))),
        isFalse,
      );
    });
  });
}
