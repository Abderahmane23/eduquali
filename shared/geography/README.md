# Découpage administratif — source unique

`guinea.json` décrit les **10 régions** de Guinée et leurs subdivisions. Les
deux clients le lisent ; personne ne retape une liste de préfectures.

```
shared/geography/guinea.json     ← la source
        │  node shared/onboarding/sync.mjs
        ▼
frontend/web/public/data/geography/
frontend/mobile/assets/geography/     ← copies générées, ne pas éditer
```

## Ce que contient le fichier

| Clé | Sens |
|---|---|
| `code` | identifiant stable, c'est lui qu'on enregistre en base |
| `name` | libellé affiché |
| `kind` | `REGION` ou `SPECIALE` (Conakry) |
| `divisionKind` | `PREFECTURE`, ou `COMMUNE` pour Conakry |
| `recent` | préfecture récente — l'écran le signale |

Conakry est une région spéciale : elle se découpe en **communes**, pas en
préfectures. Siguiri et Beyla sont des régions récentes.

## Ce que le fichier ne contient pas

Les **quartiers**. Aucune liste fiable n'a été fournie, et en inventer une
reviendrait à proposer à un professeur de Ratoma un quartier qui n'existe pas.
Le quartier reste donc une saisie libre, facultative, jusqu'à ce qu'une liste
soit disponible.

La liste des préfectures de **Siguiri** est partielle : les quatre connues y
figurent, les autres viendront.

## Modifier

1. Éditer `guinea.json`.
2. `node shared/onboarding/sync.mjs`
3. Rebâtir les clients.

`geography_test.dart` refuse un fichier où un code est en double, où une
division n'a pas de nom, ou où une région n'a aucune division.
