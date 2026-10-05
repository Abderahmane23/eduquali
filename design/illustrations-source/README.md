# Illustrations — fichiers sources

Les PNG d'origine (1024–1536 px, 370–520 Ko pièce). Ils ne sont **pas**
servis : trop lourds pour un réseau guinéen, et affichés sur 200 px de haut.

Les versions publiées sont générées à partir d'ici :

```bash
python design/illustrations-source/build.py
node shared/onboarding/sync.mjs
```

`build.py` produit `frontend/web/public/img/<nom>.webp` (200 px de haut) et
`<nom>@2x.webp` (400 px), largeur libre — les cadrages diffèrent d'une image à
l'autre et aucune n'est recadrée. `sync.mjs` recopie ensuite le tout dans
`frontend/mobile/assets/img/`.

Poids obtenu : 171 Ko pour les 14 fichiers, contre 3,2 Mo de PNG.

`house_course.png` est remplacé par `home_course.png` ; conservé au cas où.
