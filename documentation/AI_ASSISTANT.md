# Assistant IA et crédits — spécification

Purpose : définir exactement ce que voient et font les utilisateurs, et comment
le système le rend possible sans perdre d'argent.
Audience : responsable produit, développeurs.
Last updated : 16/09/2026 — Owner : équipe Eduquali.

Tâches à cocher : [ROADMAP.md, partie 5](ROADMAP.md).

---

## 1. En une phrase par utilisateur

| Qui | Vient chercher | Repart avec |
|---|---|---|
| **Professeur** | du temps de préparation | un cours complet en Excel, des copies corrigées |
| **Élève** (depuis le compte parent) | de l'aide sur ses devoirs | la méthode pour trouver la réponse lui-même |
| **Parent** | la réussite de son enfant | un suivi de ce que l'enfant a travaillé, un coût maîtrisé |

**Qui accède à l'assistant :** le professeur depuis son compte ; l'élève depuis le
compte de son parent (décision du 14/09 : un mineur n'a pas de compte). Voir la
décision ouverte n° 1 dans la feuille de route.

---

## 2. Les crédits

### 2.1 Barème

| Action | Coût |
|---|---|
| Un message dans le chat | **1 crédit** |
| Un plan de cours | **gratuit** — 5 par jour |
| Construire un cours complet | **8 crédits** |
| Améliorer un cours existant | **1 crédit** par demande |

À la création du compte : **5 crédits offerts**.

5 crédits ne suffisent pas à construire un cours (8). C'est voulu : le professeur
découvre la valeur avec un **plan gratuit à lire** avant de payer la construction.

### 2.2 Packs

| Pack | Prix | Par crédit | Soit |
|---|---|---|---|
| 30 crédits | 30 000 GNF / mois | 1 000 GNF | 0,113 $ |
| 100 crédits | 90 000 GNF / mois | 900 GNF | 0,102 $ |
| **300 crédits** | **200 000 GNF / mois** | **667 GNF** | **0,076 $** |

Taux : 1 USD = 8 830 GNF (septembre 2026). Toutes les marges ci-dessous sont
calculées sur le pack le moins cher par crédit — le cas défavorable. La
commission de l'agrégateur mobile money reste à déduire.

### 2.3 Ce que coûte réellement un crédit

Prix Gemini, offre payante, relevés sur la page officielle en septembre 2026.

> **Attention :** les prix des modèles `3.x Flash` sont **promotionnels jusqu'au
> 31/12/2026, puis doublent**. Tous les calculs ci-dessous utilisent le prix
> d'après promotion. Les identifiants de modèle changent vite : les
> reconfirmer au branchement.

**Un message de chat** — environ 4 000 jetons en entrée (consignes, historique,
question), 800 en sortie.

| Modèle | Coût | Marge sur 0,076 $ |
|---|---|---|
| `gemini-3.1-flash-lite` (0,25 $ / 1,50 $ par million) | 0,002 $ | 97 % |
| `gemini-2.5-flash` (0,30 $ / 2,50 $) | 0,003 $ | 96 % |
| `gemini-3.8-flash` après promo (1,50 $ / 7,50 $) | 0,012 $ | 84 % |

**Le chat est rentable avec n'importe quel modèle Flash.**

**Un cours complet** — environ 25 000 jetons produits (chapitres, définitions,
exercices, corrigés), générés chapitre par chapitre : environ 24 000 jetons en
entrée au total. Recette pour 8 crédits : **0,604 $**.

Les modèles « à réflexion » facturent leurs jetons de réflexion **comme de la
sortie**. Sans plafond, ils peuvent doubler la facture.

| Modèle | Réflexion plafonnée | Réflexion libre |
|---|---|---|
| `gemini-3.8-flash` après promo | 0,22 $ → **marge 63 %** | 0,41 $ → marge 32 % |
| `gemini-2.5-pro` (1,25 $ / 10 $) | 0,28 $ → marge 54 % | 0,53 $ → marge 12 % |
| `gemini-3.1-pro-preview` (2 $ / 12 $) | 0,35 $ → marge 42 % | 0,65 $ → **perte de 7 %** |

**Conclusion :** la construction de cours à 8 crédits tient **à deux conditions** —
un modèle de classe Flash, et un plafond de réflexion. Sur un modèle Pro sans
plafond, chaque cours acheté avec le pack 300 fait perdre de l'argent. Un modèle
en « preview » n'a de toute façon pas sa place en production.

---

## 3. L'architecture : un compte maître, une seule porte

C'est le modèle adopté par toutes les applications grand public qui revendent de
l'IA : **le téléphone ne parle jamais à Gemini**. Il parle au serveur Eduquali, qui
détient l'unique clé et décide qui a le droit de s'en servir.

```
 Téléphone (Flutter)
   │   jeton de session — jamais la clé Gemini
   ▼
 API Eduquali  /v1/ai/*
   │   1. Qui appelle ?             session valide, rôle
   │   2. En a-t-il le droit ?      limite du jour, fonction autorisée
   │   3. Plafond global atteint ?  oui → pause propre, aucun débit
   │   4. Réserver les crédits      solde insuffisant → 402
   ▼
 api/_lib/llm.ts   ← seul module du projet qui appelle Gemini
   │   GEMINI_API_KEY — un compte, offre payante
   ▼
 Gemini
   │
   ▼   réponse
   5. Confirmer le débit — ou rembourser si l'appel a échoué
   6. Journaliser : compte, fonction, modèle, jetons, coût en $, durée
```

### 3.1 Pourquoi pas la clé dans l'application

Un APK se décompile en quelques minutes. Une clé retrouvée dedans permet à
n'importe qui d'appeler Gemini **aux frais d'Eduquali, sans limite**. Et les
crédits ne vaudraient plus rien : le décompte doit se faire là où le client ne
peut pas mentir, c'est-à-dire sur le serveur.

### 3.2 Pourquoi l'offre payante, dès le premier jour

En offre gratuite, Google utilise les données envoyées pour améliorer ses
produits. Des photos de devoirs d'enfants ne peuvent pas partir dans ce cadre.
En offre payante, elles ne sont pas utilisées.

### 3.2-bis La clé, vérifiée le 19/09/2026

```
cd backend && npm run check:gemini
```

Le script lit `backend/.env`, liste les modèles accessibles, puis demande un
vrai plan de cours en JSON structuré. Il n'affiche jamais la clé : seulement sa
longueur et son préfixe, de quoi distinguer deux clés sans en divulguer une.

Ce qu'il a appris ce jour-là, et qui change le code :

| Constat | Conséquence |
|---|---|
| L'API attend l'en-tête **`x-goog-api-key`**. Un `Bearer` est refusé (401) : il n'accepte que les jetons OAuth. | La passerelle utilise l'en-tête, pas l'autorisation. |
| **`gemini-2.0-flash` a été retiré.** Google renvoie un 404 qui renvoie vers `gemini-3.6-flash`. | Les identifiants de modèle se vérifient à chaque déploiement, pas une fois pour toutes. |
| Un **503 « high demand »** est arrivé sur un appel, puis l'appel suivant est passé. | Les reprises ne sont pas un raffinement : sans elles, un professeur perd 8 crédits pour un incident de dix secondes. Reprendre sur 503 et 429, jamais sur 400. |
| Le JSON structuré (`responseSchema`) fonctionne, en français, sur le programme guinéen : 42 jetons en entrée, 82 en sortie, 5,4 s. | Le modèle rend des données ; c'est le serveur qui fabrique le `.docx`. Jamais l'inverse. |

**Ce que le script ne peut pas vérifier :** l'offre. L'API ne dit pas si une
clé relève du gratuit ou du payant. À confirmer sur `console.cloud.google.com`,
et c'est la seule chose qui sépare aujourd'hui les photos de devoirs d'enfants
d'un jeu d'entraînement Google.

### 3.3 Un modèle par fonction, dans un seul fichier

| Fonction | Modèle | Raison |
|---|---|---|
| Chat élève et professeur | `gemini-3.5-flash-lite` | 838 ms mesurées, le moins cher qui reste utilisable |
| Photo d'exercice, correction de copie | `gemini-3.6-flash` | meilleure lecture d'image |
| Plan de cours | `gemini-3.6-flash` | un seul message structuré |
| Construction du cours | `gemini-3.6-flash`, réflexion plafonnée | qualité avec marge tenue |

Ces quatre identifiants sont ceux vérifiés le 19/09/2026 par
`npm run check:gemini`, qui échoue si l'un d'eux disparaît du catalogue. La
liste de référence vit dans `backend/scripts/check-gemini.mjs` (`MODELS`).

Changer de modèle, de tarif ou de fournisseur modifie **un seul fichier**.
Commencer avec l'API Gemini Developer en offre payante ; passer à Vertex AI le jour
où des contrôles d'entreprise ou un hébergement régional des données deviennent
nécessaires.

### 3.4 Le débit en deux temps

```
réserver 8 crédits  →  appel Gemini  →  réussite : confirmer
                                    ↘  échec    : rembourser
```

Une réponse qui n'arrive pas n'est jamais facturée. Le solde est modifié en une
seule opération (`balance = balance - 8`), jamais lu puis réécrit : deux appuis
rapides sur « Construire » ne débitent pas deux fois.

### 3.5 Garde-fous

- **Plafond mensuel global** en dollars. Atteint, l'assistant affiche « Service
  momentanément indisponible » et ne débite personne.
- **Limite par compte** : 100 messages, 5 plans et 5 cours par jour.
- **Plafond de jetons** de sortie et de réflexion, par fonction.
- **Consignes système** versionnées dans `config/prompts/`, sous 1 500 jetons.
- **Réglages de sécurité** Gemini renforcés dès qu'un enfant est sélectionné.

---

## 4. Les écrans

### 4.1 Onglet « Assistant » — premier affichage

```
┌──────────────────────────────────┐
│ Assistant             ⚡ 5 crédits│
├──────────────────────────────────┤
│                                  │
│   Qu'est-ce qu'on fait           │
│   aujourd'hui ?                  │
│                                  │
│ ┌──────────────────────────────┐ │
│ │ 📘 Crée un cours complet     │ │  ← professeur
│ │    Plan offert, cours 8 cr.  │ │
│ └──────────────────────────────┘ │
│ ┌──────────────────────────────┐ │
│ │ ✏️ Corrige ce devoir          │ │
│ │    1 crédit par copie        │ │
│ └──────────────────────────────┘ │
│ ┌──────────────────────────────┐ │
│ │ 💬 Prépare une séance         │ │
│ └──────────────────────────────┘ │
│                                  │
├──────────────────────────────────┤
│ Écrivez votre question…  📎  ➤  │
└──────────────────────────────────┘
```

Version élève — l'enfant est choisi **avant** la première question :

```
┌──────────────────────────────────┐
│ Assistant  · Aïssatou ▾ ⚡ 12 cr. │
├──────────────────────────────────┤
│ ┌──────────────────────────────┐ │
│ │ 🧮 Aide-moi à faire mes       │ │
│ │    devoirs                   │ │
│ └──────────────────────────────┘ │
│ ┌──────────────────────────────┐ │
│ │ 📷 J'envoie une photo de      │ │
│ │    l'exercice                │ │
│ └──────────────────────────────┘ │
│ ┌──────────────────────────────┐ │
│ │ 📖 Explique-moi une leçon     │ │
│ └──────────────────────────────┘ │
```

**Règles :**
- Le coût est écrit **sous chaque bouton**, avant d'appuyer.
- Le solde reste visible en permanence ; un appui ouvre « Mes crédits ».
- Hors ligne : boutons grisés, bandeau « Pas de réseau — l'assistant revient
  dès la connexion », aucun débit.

### 4.2 Élève — aide aux devoirs

**Mode tuteur par défaut.** L'assistant ne donne pas la réponse finale d'emblée :
il demande où l'élève bloque, donne un indice, vérifie l'étape suivante. Après
deux essais infructueux, il montre la solution rédigée. C'est ce que les
familles et les écoles attendent d'un outil d'aide, et c'est ce qui le distingue
d'un simple recopiage.

```
 Élève  📷 [photo de l'exercice]
        Je comprends pas le 2

 Assistant
        On part de l'équation 3x + 5 = 20.
        Pour isoler x, qu'est-ce que tu enlèves
        d'abord des deux côtés ?

 Élève  le 5 ?

 Assistant
        Exactement. Ça donne 3x = 15.
        Et maintenant ?
```

- Photo prise ou choisie, compressée sur le téléphone avant envoi.
- L'historique est **séparé par enfant**.
- L'assistant ne demande jamais d'information personnelle à l'enfant.
- Le parent voit, dans le profil de l'enfant, les matières travaillées et les
  crédits utilisés — pas le détail des messages.

### 4.3 Professeur — « Corrige ce devoir »

1. Photo de la copie (une ou plusieurs pages).
2. Le professeur indique, en option, le barème ou le corrigé attendu.
3. L'assistant renvoie, question par question : juste ou faux, l'erreur commise,
   les points obtenus.
4. **Note proposée**, présentée comme une proposition — le professeur décide.

> La note totale est **calculée par le serveur** à partir des points de chaque
> question, jamais additionnée par le modèle : un modèle compte mal, et une note
> fausse sur une copie est inacceptable.

### 4.4 Professeur — « Crée un cours complet »

**Étape 1 — le formulaire**

```
┌──────────────────────────────────┐
│ ← Nouveau cours                  │
├──────────────────────────────────┤
│ Titre du cours                   │
│ [ Les fonctions affines        ] │
│                                  │
│ Pour quelles classes ?           │
│ [11e année] [12e année] [Tle]    │
│                                  │
│ Sur quelle période ?             │
│ (Trim. 1) (Trim. 2) (Trim. 3)    │
│ (Sem. 1)  (Sem. 2)  (Année)      │
│                                  │
│ Ce que les élèves doivent        │
│ apprendre                        │
│ ┌──────────────────────────────┐ │
│ │ Notions, figures et          │ │
│ │ personnages à connaître,     │ │
│ │ types d'exercices…           │ │
│ └──────────────────────────────┘ │
│                                  │
│ Exercices         [Oui ▾] [ 15 ] │
│ Définitions       [Oui ▾]        │
│ Chapitres         [Oui ▾] [  4 ] │
│ Dates à couvrir   [Oui ▾]        │
│   du [01/10/26]  au [15/12/26]   │
│                                  │
│ [   Voir le plan — gratuit     ] │
└──────────────────────────────────┘
```

Champs obligatoires : titre, au moins une classe, période, objectifs. Les nombres
n'apparaissent que si la réponse est « Oui ».

**Étape 2 — le plan (un message, gratuit)**

```
 Assistant
 ┌────────────────────────────────┐
 │ Les fonctions affines          │
 │ 11e · 12e · Trimestre 1        │
 │                                │
 │ 1. Définition et vocabulaire   │
 │    Image, antécédent, f(x)=ax+b│
 │ 2. Représentation graphique    │
 │    Coefficient directeur…      │
 │ 3. Sens de variation           │
 │ 4. Problèmes concrets          │
 │                                │
 │ 15 exercices recommandés       │
 │ 12 définitions                 │
 ├────────────────────────────────┤
 │ [ Construire le cours · 8 cr. ]│
 │   Modifier le plan             │
 └────────────────────────────────┘
```

Le professeur peut faire modifier le plan avant de construire : chaque
modification compte comme un nouveau plan, gratuit dans la limite de 5 par jour.
Un plan coûte environ 0,01 $ : la limite empêche seulement de s'en servir comme
d'un chat gratuit.

**Étape 3 — solde insuffisant**

```
┌──────────────────────────────────┐
│  Il vous faut 8 crédits          │
│  Vous en avez 5.                 │
│                                  │
│  [ Ajouter des crédits         ] │
│    À partir de 30 000 GNF        │
│                                  │
│    Regarder une vidéo · +1 crédit│
│    (2 restantes aujourd'hui)     │
│                                  │
│    Plus tard                     │
└──────────────────────────────────┘
```

Rien n'est débité tant que le professeur n'a pas les 8 crédits et n'a pas appuyé
sur « Construire ».

**Étape 4 — le cours est prêt**

```
 Assistant
 ┌────────────────────────────────┐
 │ ✅ Votre cours est prêt         │
 │ Les fonctions affines          │
 │ 4 chapitres · 15 exercices     │
 │ 12 définitions · corrigés      │
 ├────────────────────────────────┤
 │ [ Télécharger le cours (Excel) ]│
 │   Améliorer ce cours           │
 └────────────────────────────────┘
```

**Le fichier Excel**

| Feuille | Contenu |
|---|---|
| Cours | titre, classes, période, objectifs, sommaire |
| Chapitres | un chapitre par ligne : titre, contenu, durée conseillée |
| Définitions | terme, définition, chapitre |
| Exercices | énoncé, difficulté, chapitre |
| Corrigés | solution rédigée de chaque exercice |
| Calendrier | une séance par date, si une période a été donnée |

**Comment il est fabriqué :** le modèle renvoie du **JSON structuré** selon un
schéma imposé ; le serveur construit le fichier Excel à partir de ce JSON. On ne
demande jamais au modèle de produire un fichier. Le JSON est conservé comme
source : c'est lui qu'on modifie, le fichier est refabriqué à chaque version.

**Étape 5 — améliorer un cours**

Le cours reste dans « Mes cours ». Depuis le chat : « Ajoute 5 exercices au
chapitre 3 » ou « Simplifie les définitions pour la 11e ». Le serveur recharge
le JSON, demande la modification, crée **une nouvelle version** et refabrique le
fichier. Les versions précédentes restent téléchargeables. 1 crédit par demande.

### 4.5 « Mes crédits »

- Solde et date d'expiration du pack en cours.
- Historique : chaque écriture (achat, vidéo, message, cours, remboursement).
- Les trois packs, le pack 100 mis en avant comme « Le plus choisi ».
- Paiement : Orange Money, puis MTN MoMo.

---

## 5. Données

```
credit_wallets   owner_id · balance · pack_expires_at
credit_ledger    id · owner_id · kind · amount · reference · created_at
                 kind : GRANT | PURCHASE | AD_REWARD | RESERVE | COMMIT
                        | REFUND | EXPIRE
ai_usage         id · owner_id · child_id · feature · model
                 · tokens_in · tokens_out · tokens_thinking
                 · cost_usd · credits · duration_ms · status · created_at
ai_conversations id · owner_id · child_id · feature · created_at
ai_messages      id · conversation_id · role · content · attachment_path
courses          id · teacher_id · title · current_version · created_at
course_versions  id · course_id · version · json · xlsx_path · created_at
```

`credit_ledger` et `ai_usage` ne sont jamais modifiés, seulement complétés. Le
solde peut toujours être recalculé à partir du journal.

---

## 6. Points qui demandent une décision

1. **Compte étudiant pour les majeurs** (université) : utile, mais à décider.
2. **Google Play :** des crédits consommés dans l'application sont un bien
   numérique ; le Store impose normalement sa propre facturation. À vérifier
   avant toute publication sur le Store.
3. **Publicité et enfants :** les vidéos récompensées restent réservées au compte
   parent, jamais pendant une session de l'enfant.
4. **Premier cours offert ?** Offrir la première construction lèverait le frein
   pour un professeur qui n'a pas encore payé, pour environ 0,22 $ par professeur.
