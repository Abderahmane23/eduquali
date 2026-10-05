# Eduquali

Recrutement d'enseignants, cours à domicile et inscriptions scolaires, en
Guinée. Trois profils : **professeur**, **école ou université**, **parent
d'élève**.

| Où | Quoi |
|---|---|
| [`frontend/`](frontend) | Ce que voient les utilisateurs |
| [`backend/`](backend) | L'API et la base de données |
| [`documentation/`](documentation) | Feuille de route, décisions, déploiement |

Nouveau ici ? Commencez par
[documentation/ROADMAP.md](documentation/ROADMAP.md) : il dit ce qui reste à
faire, et seulement cela.

---

## L'arborescence

```
eduquali/
├── frontend/
│   ├── mobile/          application Flutter (Android) — le produit principal
│   └── web/             site React (Vite)
│
├── backend/
│   ├── api/             API REST (Hono, déployée en fonctions Vercel)
│   │   ├── [[...route]].ts    toutes les routes /api/v1
│   │   └── _lib/             db · domain · audit · ratelimit (+ tests)
│   └── supabase/        schéma Postgres, RLS, migrations, jeu de données
│
├── documentation/
│   ├── ROADMAP.md       ce qui reste à faire
│   ├── DECISIONS.md     ce qui a été décidé, et pourquoi
│   ├── AI_ASSISTANT.md  spécification de l'assistant IA et des crédits
│   └── DEPLOIEMENT.md   mise en ligne
│
├── shared/onboarding/   parcours d'inscription — source unique des 2 clients
├── shared/geography/    découpage administratif de la Guinée (10 régions)
└── design/              illustrations sources et script de génération
```

**Les règles métier vivent dans `backend/api/_lib/domain.ts`** : score de
compatibilité, correction des tests, indicateur de confiance. Elles ne doivent
jamais être recopiées dans un client — deux copies finissent toujours par
diverger, et un même candidat serait classé différemment selon le support.

**Les parcours d'inscription vivent dans `shared/onboarding/`** et sont recopiés
vers les deux clients par `node shared/onboarding/sync.mjs`. Les copies sont
générées : les modifier directement ne sert à rien. Le même script recopie
`shared/geography/guinea.json` — les 10 régions et leurs préfectures, lues par
les deux clients pour la cascade région → préfecture → quartier.

---

## Démarrer

```bash
# API
cd backend && npm install && npm test

# Site web
cd frontend/web && npm install && npm run dev      # http://localhost:5173

# Application mobile
cd frontend/mobile && flutter pub get && flutter test && flutter run
```

Sans variable `VITE_API_BASE_URL`, le site tourne sur un backend simulé et
reste entièrement parcourable. L'application mobile fonctionne hors ligne, avec
ses données embarquées.

## Ce qu'il faut savoir avant de juger l'état du projet

- **L'application mobile ne parle encore à aucun serveur.** Comptes, offres et
  candidatures vivent dans la base locale d'un seul téléphone. Deux personnes
  sur deux téléphones ne peuvent pas encore interagir.
- **L'assistant IA est en mode démonstration** : le contenu est fabriqué sur
  l'appareil, sans modèle et sans clé. Voir
  [documentation/AI_ASSISTANT.md](documentation/AI_ASSISTANT.md).
- **Aucun badge « vérifié » ne peut apparaître en production** : rien ne fait
  encore passer une identité ou un diplôme à l'état vérifié.

Ces trois points sont les premières lignes de la feuille de route.
