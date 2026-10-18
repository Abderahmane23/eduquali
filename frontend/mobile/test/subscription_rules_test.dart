import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/domain/usecases/subscription_rules.dart';

/// L'abonnement mensuel, qui remplace les crédits (24/09).
///
/// Ce qui se paie décide de ce qu'on peut faire : une erreur ici ouvre une
/// fonction payante à tout le monde, ou ferme une fonction à quelqu'un qui
/// vient de payer. Ni l'un ni l'autre ne se voit à l'écran.
void main() {
  group('Les trois formules', () {
    test('les prix sont ceux annoncés, en francs guinéens', () {
      expect(SubscriptionPlan.free.monthlyPriceGnf, 0);
      // 100 000 GNF jusqu'au 18/10. Le prix et le nom viennent desormais
      // de `shared/formules/formules.json`, que lisent aussi le serveur et
      // ses epreuves : un ecran qui annonce un prix pendant que le serveur
      // en demande un autre est pire qu'un ecran sans prix.
      expect(SubscriptionPlan.pro.monthlyPriceGnf, 50000);
      expect(SubscriptionPlan.master.monthlyPriceGnf, 200000);
    });

    test('le même prix pour tous les profils', () {
      // Il n'existe volontairement aucune grille par rôle : une seule liste
      // de formules, donc rien à maintenir en parallèle.
      expect(SubscriptionPlan.values, hasLength(3));
    });

    test('un code inconnu retombe sur le gratuit', () {
      // Jamais sur une formule payante : un code corrompu ne doit pas
      // ouvrir ce qui n'a pas été payé.
      expect(SubscriptionPlan.fromCode(null), SubscriptionPlan.free);
      expect(SubscriptionPlan.fromCode('PLATINE'), SubscriptionPlan.free);
      expect(SubscriptionPlan.fromCode('PRO'), SubscriptionPlan.pro);
    });

    test('Master couvre Pro, l’inverse est faux', () {
      expect(SubscriptionPlan.master.covers(SubscriptionPlan.pro), isTrue);
      expect(SubscriptionPlan.pro.covers(SubscriptionPlan.master), isFalse);
      expect(SubscriptionPlan.pro.covers(SubscriptionPlan.pro), isTrue);
    });
  });

  group('Ce que chaque formule ouvre', () {
    test('le gratuit n’ouvre aucune fonction payante', () {
      for (final f in PaidFeature.values) {
        expect(
          allows(SubscriptionPlan.free, f),
          isFalse,
          reason: '${f.name} est ouverte sans abonnement',
        );
      }
    });

    test('Master ouvre tout', () {
      for (final f in PaidFeature.values) {
        expect(allows(SubscriptionPlan.master, f), isTrue, reason: f.name);
      }
    });

    test('Pro ouvre le contact, pas la promotion', () {
      // Le contact est ce que tout le monde vient faire ; la promotion est
      // ce qu'on achète en plus.
      expect(allows(SubscriptionPlan.pro, PaidFeature.contact), isTrue);
      expect(allows(SubscriptionPlan.pro, PaidFeature.favourites), isTrue);
      expect(allows(SubscriptionPlan.pro, PaidFeature.promotion), isFalse);
    });

    test('l’écran apprend quelle formule proposer', () {
      // Rendre la formule attendue, et non un simple refus : sinon l'écran
      // propose la liste entière et laisse choisir au hasard.
      expect(
        missingPlan(SubscriptionPlan.free, PaidFeature.contact),
        SubscriptionPlan.pro,
      );
      expect(
        missingPlan(SubscriptionPlan.pro, PaidFeature.promotion),
        SubscriptionPlan.master,
      );
      expect(
        missingPlan(SubscriptionPlan.master, PaidFeature.promotion),
        isNull,
      );
    });
  });

  group('Validité dans le temps', () {
    final aujourdhui = DateTime(2026, 9, 24, 14);

    test('le gratuit n’expire pas', () {
      expect(isActive(SubscriptionPlan.free, null, aujourdhui), isTrue);
    });

    test('un abonnement sans échéance n’est pas actif', () {
      // Le cas d'une donnée incomplète : on ferme, on n'ouvre pas.
      expect(isActive(SubscriptionPlan.pro, null, aujourdhui), isFalse);
    });

    test('le jour de l’échéance compte encore', () {
      // Couper à l'heure près punirait un décalage de fuseau ou un paiement
      // enregistré quelques minutes trop tard.
      expect(
        isActive(SubscriptionPlan.pro, DateTime(2026, 9, 24), aujourdhui),
        isTrue,
      );
      expect(
        isActive(SubscriptionPlan.pro, DateTime(2026, 9, 23), aujourdhui),
        isFalse,
      );
    });

    test('un abonnement expiré referme les fonctions payantes', () {
      final effectif = effectivePlan(
        SubscriptionPlan.master,
        DateTime(2026, 8, 24),
        aujourdhui,
      );
      expect(effectif, SubscriptionPlan.free);
      expect(allows(effectif, PaidFeature.contact), isFalse);
    });

    test('un abonnement en cours garde son niveau', () {
      expect(
        effectivePlan(
          SubscriptionPlan.master,
          DateTime(2026, 10, 24),
          aujourdhui,
        ),
        SubscriptionPlan.master,
      );
    });
  });
}
