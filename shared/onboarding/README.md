# Parcours d'inscription — source unique

Les écrans d'inscription des deux clients (site React, application Flutter)
sont décrits ici, et **seulement ici**.

Jusqu'à la v2, chaque client portait sa propre copie du fichier. Les deux
copies avaient déjà divergé : le web affichait une illustration que le mobile
ignorait. Une question ajoutée d'un côté manquait de l'autre.

```
shared/onboarding/            ← la source
├── intro.json                ← écrans communs + choix du profil
├── teacher_onboarding.json
├── institution_onboarding.json
└── student_onboarding.json

        │  node shared/onboarding/sync.mjs
        ▼
frontend/web/public/data/     ← copies générées, ne pas éditer
frontend/mobile/assets/onboarding/  ← copies générées, ne pas éditer
```

## Modifier un parcours

1. Éditer le fichier dans `shared/onboarding/`.
2. `node shared/onboarding/sync.mjs`
3. Rebâtir les clients.

Le script refuse de recopier un JSON invalide et signale toute étape dont le
type n'est pas connu des deux clients.

## Enchaînement

```
splash → intro.json ─ role_select ─┬→ teacher_onboarding.json
                                   ├→ institution_onboarding.json
                                   └→ student_onboarding.json
```

`intro.json` ne collecte qu'une réponse : `role`. Les écrans de découverte
qui la précèdent sont tous passables.

## Types d'étape

| `type` | Saisie | Rendu |
|---|---|---|
| `statement` | non | titre, illustration, texte, chiffres clés |
| `steps_preview` | non | liste numérotée |
| `carousel` | non | profils mis en avant |
| `role_select` | **oui** | boutons empilés, un par profil |
| `form` | oui | plusieurs champs |
| `single_choice` / `multi_choice` | oui | étiquettes |
| `boolean` | oui | oui / non |
| `range` | oui | curseur |
| `plan_select` | oui | formules, refus possible |

Ajouter un type demande de le déclarer **dans les deux clients** :
`frontend/web/src/onboarding/spec.ts` et
`frontend/mobile/lib/domain/entities/onboarding_spec.dart`.
