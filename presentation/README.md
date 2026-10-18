# La présentation EduQuali

Le jeu de diapositives investisseurs — `EduQuali - Presentation.pdf`, à la
racine du dépôt — est **engendré**, pas dessiné. Ces fichiers le produisent.

```sh
cd presentation
python pages.py        # écrit le PDF à la racine
python voir.py 6 7 17  # rend ces pages en PNG, pour les regarder
```

## Les fichiers

| Fichier | Rôle |
|---|---|
| `carrousel.py` | la page, la charte, le surlignage biseauté, le pied |
| `pages.py` | l'ordre du jeu, et les pages 1 à 10 |
| `pages_plus.py` | les pages ajoutées ensuite |
| `telephone_photo.py` | le châssis qui tient une capture d'écran |
| `voir.py` | rend une page en image, pour la relire |

## Les captures

Elles viennent de `design/captures/`, alimenté par
`frontend/mobile/tool/captures/captures_test.dart` :

```sh
cd ../frontend/mobile
flutter test tool/captures/captures_test.dart --tags captures
cp test/captures/*.png ../../design/captures/
```

Ce sont de **vrais écrans**, rendus par le moteur Flutter avec les vraies
polices et le vrai thème — pas des maquettes. Les exports Banani de
`EQ_screens_from_banani/` sont antérieurs à la charte : ancien violet,
dégradés et ombres, trois interdits. Ils ne doivent pas entrer ici.

## Ce qui reste à renseigner

`page9` (l'équipe) et `page10` (le financement) portent encore des
marqueurs entre crochets : montant demandé, emploi des fonds, contact. Et
la page du problème cite « plus de la moitié des écoles n'arrivent pas au
bout du programme » sans source — à sourcer ou à retirer.
