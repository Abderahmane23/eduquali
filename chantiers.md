# Chantiers EduQuali

Ce qui est demandé, dans l'ordre où cela doit être fait. Tenu à jour au fil
des échanges — un élément n'est coché que lorsqu'il est vérifié sur l'écran
ou par une épreuve, jamais parce que le code a été écrit.

---

## 1. La présentation (en cours)

Jeu de diapositives investisseurs — `EduQuali - Presentation.pdf`.

- [x] Cinq captures de plus dans le harnais Flutter (`test/captures_test.dart`) :
      accueil, catalogue, cours chapitres ouverts, réservation, assistant en
      conversation.
- [x] **Les trois captures qui échouent encore** : accueil, catalogue, cours.
- [x] Planche « réserver · direct · présence ».
- [x] Planche « cours · accueil ».
- [ ] Capture de la page principale sur la diapositive de couverture.
- [x] Remplacer « OÙ NOUS EN SOMMES / Le produit existe. » par deux
      diapositives : le chatbot en conversation, et un cours chapitres ouverts.
- [x] « LA PROJECTION / Trois ans. » : deux graphiques —
      adoption (élèves 100 → 200 → 2 500 ; professeurs 50 → 100 → 1 000 aux
      mêmes points) et revenu par phase (1, 2, 3).
- [x] Supprimer « Ce qui peut mal tourner ».
- [x] « QUESTIONS FRÉQUENTES / Ce qu'on nous demande. » — questions réécrites
      sur les **intentions cachées** : le parent veut l'assurance que son
      enfant réussira, le professeur veut gagner plus, l'élève veut apprendre
      sans souffrir et avec ses amis. Chaque réponse doit servir les deux
      parties à parts égales.

### Note sur les maquettes

Aucun lien vers le système de design ne nous est parvenu. Les exports
`EQ_screens_from_banani/` sont **antérieurs à la charte** : ancien violet,
dégradés et ombres — trois interdits de la charte EduQuali. Les captures
viennent donc de l'application réelle, rendue par le moteur Flutter avec le
vrai thème.

---

## 2. Les comptes et le parcours d'inscription

- [x] **Fusionner parent, élève et universitaire en un seul compte**, nommé
      « Élève ou étudiant ». La première page du parcours demande
      « Êtes-vous parent ? oui / non ».
      - oui → le nom des enfants, comme le parcours parent actuel ;
      - non → inscription en tant qu'élève.
- [x] Supprimer les **trois premiers écrans** du parcours (« des profils
      vérifiés », etc.) — pour les quatre profils.
- [ ] *(Demande incomplète : « rename » — à préciser.)*

---

## 3. L'assistant

- [x] Retirer **tout** le texte et les boutons superflus : « Devoirs / Autre »
      en haut, et « autres questions 1/100 aujourd'hui ».
- [x] La fenêtre de conversation prend **toute la hauteur** de l'écran.
- [x] Contenu très lisible ; réduire la taille du texte des messages si besoin.

---

## 4. Le direct

- [x] Retirer la carte « Les mêmes heures chaque semaine » (Lundi 18 h – 19 h 30
      · 20 h – 21 h 30, Mardi…).
- [x] Ne garder que « Pour réserver une place, ouvrez l'application » ;
      retirer le sous-texte et « La séance se suit dans… ».
- [x] **Publier un cours** : après la matière et le prix, deux boutons —
      1. *Démarrer le direct* → ouvre une vraie session LiveKit, propose
         d'inviter, et notifie dans l'application les élèves abonnés au
         professeur ;
      2. *Déposer une rediffusion*.

---

## 5. Abonnement et accès

Un module de règles existe déjà : `lib/domain/usecases/subscription_rules.dart`
(FREE / PRO 100 000 / MASTER 200 000, par fonction ouverte ou fermée). Ce qui
suit en est une **refonte** : des quotas par période, et une période d'essai.

- [ ] **7 jours d'essai**, toutes fonctions : rejoindre un direct, voir
      n'importe quel cours, télécharger sur l'application, assistant limité à
      3 messages par jour.
- [x] **Après 7 jours**, tout se ferme sauf : 3 messages d'assistant par jour,
      1 direct par quinzaine, 1 cours enregistré par mois.
- [x] **50 000 GNF** : jusqu'à 4 cours, et 2 directs par mois.
- [x] **200 000 GNF** : cours et directs sans limite, assistant Pro, questions
      pendant les directs, exercices corrigés par le professeur.

> **Bloquant** : `payments.configured: false` sur le Worker. Les deux
> formules peuvent être écrites et éprouvées, mais rien ne peut être encaissé
> tant que les secrets Djomy ne sont pas posés.

---

## 6. Les écoles, les professeurs et les élèves

- [ ] Une école ajoute **ses propres professeurs** et les gère.
- [ ] Une école ajoute des **élèves à un professeur**, par numéro et par nom.
- [ ] Un professeur peut lui aussi ajouter ses élèves.

---

## 7. Les cours du professeur

- [x] CRUD complet de ses cours.
- [x] Interrupteur : prévenir, **1 h avant le direct**, les élèves qui ont
      installé l'application — notification native.
- [x] Après 7 jours, une fenêtre sur le profil du professeur lui demande de
      terminer son inscription : carte d'identité et diplôme.

---

## 8. Le tableau de bord

- [x] En haut, un **carrousel « professeurs en direct »**.
- [x] Puis une section **« meilleurs cours »**.
- [x] Puis les boutons d'action.

---

## 9. Le catalogue et les essais

- [ ] Déposer une **vidéo d'exemple** dans le catalogue pour éprouver la
      diffusion.
- [ ] Créer un **direct** de bout en bout, pour voir.

---

## 10. La production — ce qui reste à poser

Mesuré par `node scripts/verifier-production.mjs`.

- [x] **Le Worker déployé est plus vieux que le dépôt** : `/schools/names`
      rend 404, et le correctif de l'annuaire n'est pas en ligne.
      `wrangler deploy` dans `backend/`.
- [x] **`payments` non configuré** → aucune famille ne peut régler quoi que
      ce soit.
- [ ] **`video` et `recording` non configurés** → aucun cours enregistré ne
      peut être déposé ni lu, aucune rediffusion.
- [ ] Les migrations `0032` et `0033` ne sont pas appliquées —
      `node scripts/migrations.mjs --baseline=0031` puis `--appliquer`.
