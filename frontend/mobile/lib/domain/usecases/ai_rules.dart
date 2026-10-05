/// Assistant IA — quel modèle répond à quoi.
///
/// Ce fichier remplace `credit_rules.dart`, supprimé le 25/09 avec le
/// système de crédits : l'assistant, la mise en avant et la messagerie sont
/// désormais ouverts par l'abonnement (Basic, Pro, Master) et rien ne se
/// décompte pendant qu'on s'en sert. Ce qui reste ici n'est pas un tarif
/// facturé à l'utilisateur, c'est une décision technique : à qui on envoie
/// la requête.
///
/// Le coût réel par appel n'a pas disparu pour autant — il est porté par
/// l'abonnement au lieu d'être refacturé. C'est précisément pourquoi le
/// routage doit rester net : router une question simple vers le modèle de
/// raisonnement multiplie la facture sans que personne ne voie la
/// différence, et cette facture est maintenant la nôtre.
///
/// **Rien n'appelle encore ce fichier.** La passerelle de démonstration ne
/// contacte aucun modèle, donc elle n'a personne à router ; ces valeurs
/// seront lues quand la passerelle serveur existera, et c'est elle qui
/// nommera le modèle dans sa requête. Écrit ici plutôt que décidé plus tard
/// dans le serveur : le choix coûte de l'argent à chaque appel, et il se
/// relit mieux à côté des fonctions qu'il concerne. Le compilateur le
/// retire de l'APK tant qu'il n'est pas utilisé.
library;

/// Le modèle appelé pour une fonction.
enum AiModelTier {
  /// Rapide et bon marché : questions, vérifications, corrections courtes.
  fast('gemini-2.5-flash'),

  /// Raisonnement profond : plans de cours, examens, programmes entiers.
  deep('gemini-3.1-pro');

  const AiModelTier(this.model);

  /// L'identifiant envoyé à la passerelle. Le serveur reste seul à
  /// connaître la clé ; le client ne fait que nommer le besoin.
  final String model;
}

/// Ce que fait chaque fonction de l'assistant, et qui la traite.
enum AiFeature {
  /// Un message dans la discussion.
  chat('chat', AiModelTier.fast),

  /// Le plan d'un cours.
  outline('outline', AiModelTier.fast),

  /// Un cours complet de six semaines.
  build('course', AiModelTier.deep),

  /// Un examen imprimable de vingt questions.
  exam('exam', AiModelTier.deep),

  /// Une demande d'amélioration d'un cours existant.
  improve('improve', AiModelTier.fast);

  const AiFeature(this.code, this.tier);

  /// Le nom porté par le journal d'usage et par la requête au serveur.
  final String code;

  /// Le modèle à appeler.
  final AiModelTier tier;
}
