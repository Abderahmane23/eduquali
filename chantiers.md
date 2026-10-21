# Chantiers EduQuali

Ce qui reste à faire, en **cinq lots**. Un lot se tient : ses tâches touchent
le même code, se vérifient ensemble, et le suivant suppose le précédent fait.

Une tâche n'est cochée que lorsqu'elle est **vérifiée sur l'écran** ou par une
épreuve — jamais parce que le code a été écrit.

L'ordre des deux premiers lots n'est pas négociable : tant qu'on ne voit pas
ce qu'on tape, rien ne se teste ; et tant qu'on ne peut pas créer un compte,
rien ne s'essaie.

---

## Lot 1 — Voir ce qu'on tape, et parler au serveur

*Bloquant. Tout le reste se vérifie à travers ce lot.*

- [ ] **Le thème** : champs de saisie à fond noir, texte noir, fond de page
      noir. Les trois signalements décrivent très probablement **une seule
      cause** — un thème sombre appliqué là où la charte demande le papier.
      À corriger dans le thème, pas écran par écran : trente écrans repris un
      à un laisseraient le trente-et-unième.
- [ ] **« Publier un cours » annonce que le serveur n'est pas en ligne**,
      alors que le Worker répond (`status: ok`). Première piste : l'APK est
      construit sans l'adresse de l'API et parle au backend simulé — ce qui
      expliquerait aussi la ligne suivante.
- [ ] **Les créneaux restent « en cours de lecture »** et n'arrivent jamais.
- [ ] **Vérification** : sur l'appareil, taper dans un champ et le relire ;
      ouvrir « Publier un cours » et voir des créneaux.

## Lot 2 — S'inscrire jusqu'au bout

*Un seul passage par la source partagée, puis la synchronisation, puis les
deux clients. Les renommages voyagent avec, parce qu'ils vivent dans les
mêmes fichiers.*

- [ ] **Primaire : les classes de 1ère à 6ème année ne s'affichent pas.**
- [ ] **Lycée : l'écran des séries** après le choix de la classe — sciences
      sociales, mathématiques, expérimentales. Vu par l'élève, le parent et
      le professeur ; le professeur en choisit **jusqu'à trois**.
- [ ] **« Quels jours donnez-vous des cours ? »** : tous les jours affichés
      d'emblée, des champs libres pour les heures, une option « 8 h – 18 h ».
      **Supprimer la seconde page** « quels jours, exactement ? ».
- [ ] **« Je suis en direct lundi, mardi… »**, et le nombre de séances par
      semaine.
- [ ] **Établissements : un intervalle de prix par heure**, au lieu d'un
      prix unique.
- [ ] **Les mots** : « Cours à domicile » → « Cours à domicile et vidéo » ;
      « Embauche » → « Recruter » ; « Ajouter un professeur » → « Recruter un
      professeur ».
- [ ] **Vérification** : créer un compte élève en primaire, un en lycée, et
      un compte professeur — chacun de bout en bout.

## Lot 3 — La vie d'un cours

*De la création à la lecture. Le plus gros lot, et celui qui porte deux des
questions ouvertes.*

- [ ] **La création demande le nom, les chapitres, les classes.**
- [ ] **Retirer « lien de l'exercice »** une fois le cours ajouté.
- [ ] **Seuls les professeurs vérifiés lancent un cours vidéo.** Sans dossier
      complet, « Lancer un cours » ouvre le dépôt des pièces.
- [ ] **Direct public 15 min, puis rediffusion privée** réservée aux
      inscrits.
- [ ] **L'en-tête annonce le cours** — titre, puis durée — et non le nom du
      fichier. Puis la description, puis les ressources.
- [ ] **Les ressources se consultent sans se télécharger.** *(question 4)*
- [ ] **Les messages quittent l'écran du cours** pour l'onglet Messages, dans
      la conversation avec ce professeur ou cet élève.
- [ ] **Le contrat accepté ou refusé** pour rendre une vidéo publique.
      *(question 2 — le prix n'est pas tranché)*
- [ ] **La bande-annonce automatique** depuis la première vidéo.
      *(question 1 — on ne sait pas où couper)*
- [ ] **Vérification** : déposer une vidéo d'exemple, lancer un direct de
      bout en bout, relire l'enregistrement.

## Lot 4 — L'école, ses professeurs, ses élèves

*Une seule chaîne : l'école inscrit un professeur, qui inscrit ses élèves, et
le groupe de discussion naît de là.*

- [ ] **Une école ajoute un de ses professeurs** — un bouton, une page. Le
      professeur reçoit ses identifiants **par courriel**.
- [ ] **Une école ajoute des élèves à un professeur**, par numéro et par nom.
- [ ] **Un professeur ajoute aussi ses propres élèves.**
- [ ] **Il les invite** par SMS (gabarit, non branché) ou par courriel.
- [ ] **Le groupe de discussion se crée tout seul** entre le professeur et
      ses élèves.
- [ ] **Vérification** : une école crée un professeur, qui ajoute deux
      élèves ; le groupe existe, et les trois peuvent s'y écrire.

## Lot 5 — Parcourir, et surveiller

*Les écrans qui regardent l'ensemble.*

- [ ] **Le catalogue** : deux listes déroulantes (classe, matière), dix
      résultats par page, une pagination en bas.
- [ ] **L'accueil du professeur** : retirer le bandeau de statistiques du
      haut, y mettre les chiffres des cours, descendre « Offres pour vous »
      en bas de page.
- [ ] **Un compte super-administrateur** : les totaux par catégorie —
      élèves, professeurs, établissements — et les liens vers les groupes et
      les vidéos. *(question 3 — des nombres, ou des listes ?)*
- [ ] **Vérification** : filtrer le catalogue sur une classe et une matière,
      et voir la pagination tenir au-delà de dix cours.

---

## Les questions qui bloquent

Ni la bande-annonce ni l'écran de consentement ne peuvent s'écrire sans
réponse.

1. **La bande-annonce : couper où ?** « Coupe 15 secondes en début au lieu et
   à la fin » se lit de deux façons — les quinze premières secondes, ou les
   quinze dernières — et « au lieu » laisse penser qu'une troisième idée
   s'est perdue en route.

2. **Rendre une vidéo publique coûte quoi ?** Deux prix pour le même geste :
   « 30 % de commission » dans le contrat, « paiement unique de 100 000 GNF »
   plus loin. Une commission se prélève sur chaque vente, un paiement unique
   se règle une fois. L'écran ne peut pas annoncer les deux.

3. **Le super-administrateur voit-il des nombres, ou des listes ?** La
   seconde lecture ouvre des données personnelles d'enfants à un écran de
   plus : cela se décide, cela ne se déduit pas.

4. **« Consultable mais pas téléchargeable » : jusqu'où ?** On peut retirer
   le bouton, signer une adresse qui expire, ouvrir une visionneuse sans
   impression — ce qui arrête la copie facile. On ne peut pas empêcher la
   photographie d'un document affiché. Décourager suffit-il, ou la ressource
   est-elle sensible au point de ne pas devoir être affichée du tout ?

5. *(à préciser)* Un message du 18/10 disait « rename », sans dire quoi.

---

## Hors lot

Ce qui ne dépend pas de moi, ou ne concerne pas l'application.

- [ ] **`video` et `recording` n'ont pas leurs secrets sur le Worker** :
      aucun cours enregistré ne peut être déposé ni lu. C'est ce qui empêche
      la vérification du lot 3 — à poser avant d'y arriver.
- [ ] **`payments` non configuré** : aucune formule payante ne peut être
      encaissée. Les règles sont écrites et éprouvées ; rien ne transige.
- [ ] **La présentation** : capture de la page principale sur la couverture.

---

## Archive — ce qui est fait

Vérifié sur l'écran ou par une épreuve.

- [x] Cinq captures de plus dans le harnais Flutter (`test/captures_test.dart`) :
- [x] **Les trois captures qui échouent encore** : accueil, catalogue, cours.
- [x] Planche « réserver · direct · présence ».
- [x] Planche « cours · accueil ».
- [x] Remplacer « OÙ NOUS EN SOMMES / Le produit existe. » par deux
- [x] « LA PROJECTION / Trois ans. » : deux graphiques —
- [x] Supprimer « Ce qui peut mal tourner ».
- [x] « QUESTIONS FRÉQUENTES / Ce qu'on nous demande. » — questions réécrites
- [x] **Fusionner parent, élève et universitaire en un seul compte**, nommé
- [x] Supprimer les **trois premiers écrans** du parcours (« des profils
- [x] Retirer **tout** le texte et les boutons superflus : « Devoirs / Autre »
- [x] La fenêtre de conversation prend **toute la hauteur** de l'écran.
- [x] Contenu très lisible ; réduire la taille du texte des messages si besoin.
- [x] Retirer la carte « Les mêmes heures chaque semaine » (Lundi 18 h – 19 h 30
- [x] Ne garder que « Pour réserver une place, ouvrez l'application » ;
- [x] **Publier un cours** : après la matière et le prix, deux boutons —
- [x] **Après 7 jours**, tout se ferme sauf : 3 messages d'assistant par jour,
- [x] **50 000 GNF** : jusqu'à 4 cours, et 2 directs par mois.
- [x] **200 000 GNF** : cours et directs sans limite, assistant Pro, questions
- [x] CRUD complet de ses cours.
- [x] Interrupteur : prévenir, **1 h avant le direct**, les élèves qui ont
- [x] Après 7 jours, une fenêtre sur le profil du professeur lui demande de
- [x] En haut, un **carrousel « professeurs en direct »**.
- [x] Puis une section **« meilleurs cours »**.
- [x] Puis les boutons d'action.
- [x] **Le Worker déployé est plus vieux que le dépôt** : `/schools/names`
- [x] **`payments` non configuré** → aucune famille ne peut régler quoi que
