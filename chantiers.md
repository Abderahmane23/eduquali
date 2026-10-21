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

---

# Chantier mobile — lot du 21/10

Priorité annoncée : **l'application**. Vingt-trois demandes, regroupées par
ce qu'elles touchent plutôt que par l'ordre où elles sont arrivées.

Trois d'entre elles attendent une précision avant d'être écrites : elles
portent un **?** et sont rassemblées en fin de section.

## A. Le thème — bloquant, et probablement une seule cause

- [ ] **Les champs de saisie ont un fond noir et un texte noir dessus** : on
      tape sans voir ce qu'on écrit. Signalé sur la première page de l'APK.
- [ ] **Le même défaut sur tous les écrans et tous les champs.**
- [ ] **Le fond des pages est noir** là où il doit être blanc, texte noir.

> Ces trois lignes décrivent très probablement **un seul défaut** : un thème
> sombre appliqué là où la charte demande le papier. À chercher d'abord dans
> `AppTheme`, pas écran par écran — corriger trente écrans un à un laisserait
> le trente-et-unième.

## B. Le parcours d'inscription

- [ ] **Primaire : les classes de 1ère à 6ème année ne s'affichent pas**
      pendant la création de compte.
- [ ] **Lycée : après le choix de la classe**, un écran de sélection de la
      série — sciences sociales, sciences mathématiques, sciences
      expérimentales. Vu par l'élève, le parent et le professeur. Le
      professeur peut en choisir **jusqu'à trois**.
- [ ] **« Quels jours donnez-vous des cours ? »** : afficher directement
      tous les jours de la semaine, avec des champs libres pour les heures
      et une option « 8 h – 18 h ». **Supprimer la seconde page** « quels
      jours, exactement ? ».
- [ ] **Établissements : un intervalle de prix par heure**, au lieu d'un
      prix unique.
- [ ] **« Je suis en direct lundi, mardi… »** et le nombre de séances par
      semaine.

## C. Les mots

- [ ] « Cours à domicile » → **« Cours à domicile et vidéo »**.
- [ ] « Embauche » → **« Recruter »**.
- [ ] Dans les établissements, « Ajouter un professeur » → **« Recruter un
      professeur »**.

## D. Les cours du professeur

- [ ] **La création demande : le nom, les chapitres, les classes.**
- [ ] **Retirer « lien de l'exercice »** une fois le cours ajouté.
- [ ] **Seuls les professeurs vérifiés lancent un cours vidéo.** Un clic sur
      « Lancer un cours » sans dossier complet ouvre la fenêtre de dépôt des
      pièces.
- [ ] **Le direct, puis la rediffusion privée.** Le cours est visible de
      tous au lancement (15 min au plus), suivable seulement par les
      inscrits. Il est ensuite enregistré en privé, réservé aux inscrits.
- [ ] **Un contrat clair, accepté ou refusé**, quand le professeur rend une
      vidéo publique. *(Voir la question 2 : le prix n'est pas tranché.)*
- [ ] **La bande-annonce automatique** à partir de la première vidéo
      déposée. *(Voir la question 1 : on ne sait pas où couper.)*

## D bis. L'écran d'un cours vidéo

- [ ] **L'en-tête annonce le cours, pas le fichier.** Aujourd'hui le nom du
      fichier déposé s'affiche. Il faut : le **titre du cours**, puis sa
      **durée** — puis la description, puis les ressources.
- [ ] **Les ressources se consultent, elles ne se téléchargent pas.**
      *(Voir la question 4 : ce qu'on peut garantir, et ce qu'on ne peut
      pas.)*

## D quater. L'accueil du professeur, réordonné

Constaté dans `teacher_dashboard.dart` : le bandeau du haut porte
aujourd'hui **cours donnés, élèves actifs, vues du profil, revenu du mois**,
et « Offres pour vous » arrive juste en dessous.

- [ ] **Retirer le bandeau de statistiques du haut.**
- [ ] **Mettre les chiffres des cours à sa place** — ventes de vidéos,
      cours donnés : ce que le professeur produit, et non ce qu'on pense de
      lui.
- [ ] **Descendre « Offres pour vous » en bas de page.**

> Les vues du profil et le revenu du mois ouvraient la journée sur un
> jugement. Les chiffres des cours ouvrent sur le travail — et les offres
> d'emploi, qui regardent ailleurs, attendent la fin de la page.

## D ter. Les messages quittent l'écran du cours

- [ ] **Un message écrit depuis un cours part dans l'onglet Messages**, dans
      la conversation avec ce professeur ou cet élève — et **disparaît du bas
      de l'écran du cours**.

> Deux endroits où lire la même conversation, c'est un endroit de trop : on
> répond dans l'un, l'autre garde une trace morte, et personne ne sait lequel
> fait foi. Le cours garde le geste — écrire — et la conversation vit dans
> Messages.

## E. Le catalogue

- [ ] **Deux listes déroulantes** : la classe et la matière.
- [ ] **Dix résultats par page**, et une pagination en bas.

## F. Les établissements, et le chat

- [ ] **Un établissement ajoute un de ses professeurs** — un bouton, une
      page. Le professeur reçoit ses identifiants **par courriel**.
- [ ] **Ce professeur invite ses élèves** par SMS (gabarit, non branché) ou
      par courriel.
- [ ] **Un groupe de discussion se crée tout seul** entre le professeur et
      les élèves qu'il a ajoutés.

## G. Un compte super-administrateur

- [ ] **Les totaux par catégorie** : élèves, professeurs, établissements.
- [ ] **Les liens** vers les groupes et les vidéos qui s'y rattachent.

## H. À éprouver sur l'appareil

- [ ] Un **cours vidéo** de bout en bout.
- [ ] La **lecture d'un cours enregistré**.
- [ ] Les **groupes de discussion**.

## I. Deux pannes à élucider

- [ ] **« Publier un cours » annonce que le serveur n'est pas en ligne.**
      Le Worker répond pourtant (`/health` : `status: ok`). À reproduire sur
      l'appareil : l'APK livré est peut-être construit sans l'adresse de
      l'API, auquel cas il parle au backend simulé.
- [ ] **Les créneaux sont annoncés « en cours de lecture »** et n'arrivent
      jamais.

## Les trois questions

1. **La bande-annonce : couper où ?** La demande dit « coupe 15 secondes en
   début au lieu et à la fin ». Les deux lectures donnent deux produits
   différents — les quinze premières secondes, ou les quinze dernières. Et
   « au lieu » laisse penser qu'une troisième idée s'est perdue en route.

2. **Rendre une vidéo publique coûte quoi ?** Deux prix sont donnés pour le
   même geste :
   - « 30 % de commission » dans le contrat à accepter ;
   - « paiement unique de 100 000 GNF » plus loin.

   Une commission se prélève sur chaque vente, un paiement unique se règle
   une fois : ce ne sont pas deux formulations d'une même règle, et l'écran
   ne peut pas annoncer les deux.

4. **« Consultable mais pas téléchargeable » : jusqu'où ?** On peut
   retirer le bouton de téléchargement, servir le document par une adresse
   signée qui expire en quelques minutes, et ouvrir une visionneuse sans
   impression ni enregistrement. Cela arrête la copie **facile**, qui est la
   plus fréquente.

   Ce qu'on ne peut pas promettre : un document affiché est un document
   rendu, donc photographiable, et récupérable par qui sait lire le trafic
   de son propre téléphone. Aucune application au monde n'y échappe.

   Dites-moi si c'est l'effet recherché — décourager — ou si la ressource
   est sensible au point de ne pas devoir être affichée du tout, auquel cas
   la réponse est ailleurs : on n'en montre qu'un extrait, ou on ne la met
   pas en ligne.

3. **Le super-administrateur voit-il les comptes, ou seulement les
   nombres ?** « Le lien élèves professeur établissements » peut se lire
   « le nombre de liens entre eux » ou « un lien vers la liste ». La seconde
   lecture ouvre des données personnelles d'enfants à un écran de plus, ce
   qui demande d'être voulu explicitement.
