"""Fabrique les logos de l'application a partir des deux sources.

Deux images, deux emplois :

  Eduqualiflutter_app_logo.png  le Q a la toque, carre. Icone du telephone,
                                et marque dans l'application.
  logo_eduquali.png             le mot « EduQuali » en entier. Page de
                                connexion, et elle seule : c'est le seul
                                ecran ou l'on ne sait pas encore ou l'on est.

Les sources sont posees sur du blanc. Ce script les detoure — methode
« couleur vers alpha » : recomposee sur du blanc, l'image detouree redonne
exactement la source, et sur le blanc fume de l'application l'ecart reste
invisible. Sans cela le logo trainerait un rectangle blanc derriere lui.

Usage : python tools/make_logos.py
"""

from __future__ import annotations

import pathlib
import sys

try:
    from PIL import Image
    import numpy as np
except ImportError:  # pragma: no cover
    sys.exit('Il manque Pillow et numpy : pip install pillow numpy')

RACINE = pathlib.Path(__file__).resolve().parents[3]
MOBILE = pathlib.Path(__file__).resolve().parents[1]
ASSETS = MOBILE / 'assets' / 'img'
RES = MOBILE / 'android' / 'app' / 'src' / 'main' / 'res'

# En deca, c'est du bruit de compression dans le fond, pas du dessin.
PLANCHER = 8.0

# Les cinq densites d'Android, en multiples du point de base.
DENSITES = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
}


def detourer(im: Image.Image) -> Image.Image:
    """Retire le blanc du fond, en gardant les bords adoucis.

    Pour chaque pixel : alpha = (255 - canal le plus sombre) / 255, puis la
    couleur est « demelangee » du blanc. Les bords anticrenelees gardent donc
    leur degrade au lieu de devenir un escalier, et le contre-poinçon du Q
    laisse passer le fond comme il doit.
    """
    a = np.array(im.convert('RGBA')).astype(float)
    rgb, alpha_source = a[..., :3], a[..., 3:4] / 255.0

    alpha = (255.0 - rgb.min(axis=2, keepdims=True)) / 255.0
    sur = alpha > 1e-4
    couleur = np.where(sur, 255.0 + (rgb - 255.0) / np.where(sur, alpha, 1.0), 0.0)

    opacite = np.clip(alpha * alpha_source * 255.0, 0, 255)
    # Le fond des sources n'est pas tout a fait blanc — 254 par endroits, ce
    # qui laisse un alpha de 1/255 sur toute la surface. Sans ce plancher, le
    # rognage ne trouve aucune marge a couper et le logo garde son cadre.
    opacite[opacite < PLANCHER] = 0.0

    sortie = np.concatenate([np.clip(couleur, 0, 255), opacite], axis=2)
    return Image.fromarray(sortie.astype('uint8'), 'RGBA')


def rogner(im: Image.Image) -> Image.Image:
    """Coupe la marge transparente : la taille demandee devient la taille vue."""
    a = np.array(im)
    a[..., 3][a[..., 3] < PLANCHER] = 0
    im = Image.fromarray(a, 'RGBA')
    return im.crop(im.getbbox())


def poser(art: Image.Image, cote: int, part: float) -> Image.Image:
    """Centre `art` sur un carre transparent de `cote` px, occupant `part`."""
    cible = cote * part
    facteur = min(cible / art.width, cible / art.height)
    reduit = art.resize(
        (max(1, round(art.width * facteur)), max(1, round(art.height * facteur))),
        Image.LANCZOS,
    )
    toile = Image.new('RGBA', (cote, cote), (0, 0, 0, 0))
    toile.paste(
        reduit,
        ((cote - reduit.width) // 2, (cote - reduit.height) // 2),
        reduit,
    )
    return toile


def eclaircir(mot: Image.Image) -> Image.Image:
    """Le mot-symbole pour fond sombre : blanc a gauche, vert vif a droite.

    Sur le violet des en-tetes, le « Edu » marine tombe a 1,4:1 : il
    disparait. Tenter de n'eclaircir que le marine donnait un gris terne,
    parce que la source passe du marine au vert par un degrade continu et
    qu'aucun seuil ne separe proprement les deux.

    On garde donc la *forme* — le canal alpha — et on la remplit d'un degrade
    horizontal blanc vers vert, la bascule tombant sur le Q. C'est exactement
    ce que montre la maquette, et les deux teintes tiennent leur contraste
    sur le violet : 8,98:1 pour le blanc, 4,67:1 pour le vert.
    """
    a = np.array(mot.convert('RGBA'))
    alpha = a[..., 3:4].astype(float)

    largeur_px = a.shape[1]
    x = np.linspace(0.0, 1.0, largeur_px)[None, :, None]
    # Transition douce entre 45 % et 62 % de la largeur : le Q est la.
    t = np.clip((x - 0.45) / (0.62 - 0.45), 0.0, 1.0)
    t = t * t * (3.0 - 2.0 * t)

    blanc = np.array([255.0, 255.0, 255.0])
    vert = np.array([52.0, 211.0, 153.0])
    remplissage = blanc + (vert - blanc) * t

    return Image.fromarray(
        np.concatenate(
            [np.broadcast_to(remplissage, a[..., :3].shape), alpha], axis=2
        ).astype('uint8'),
        'RGBA',
    )


def largeur(art: Image.Image, px: int) -> Image.Image:
    return art.resize((px, round(art.height * px / art.width)), Image.LANCZOS)


def main() -> None:
    marque = rogner(detourer(Image.open(RACINE / 'Eduqualiflutter_app_logo.png')))
    mot = rogner(Image.open(RACINE / 'logo_eduquali.png').convert('RGBA'))

    ASSETS.mkdir(parents=True, exist_ok=True)

    # --- Dans l'application -------------------------------------------------
    # Trois fois la taille affichee : l'ecran d'un telephone est dense, et une
    # image juste a la bonne taille y parait floue.
    poser(marque, 288, 1.0).save(ASSETS / 'logo_mark.png')
    largeur(mot, 720).save(ASSETS / 'logo_wordmark.png')
    largeur(eclaircir(mot), 720).save(ASSETS / 'logo_wordmark_light.png')

    # --- Icone du telephone -------------------------------------------------
    # Le systeme decoupe l'icone adaptative dans un cercle, un carre arrondi ou
    # une goutte selon le telephone : l'art tient dans la zone sure, sinon la
    # toque du Q se fait rogner sur la moitie des appareils.
    for suffixe, facteur in DENSITES.items():
        dossier = RES / f'mipmap-{suffixe}'
        dossier.mkdir(parents=True, exist_ok=True)

        poser(marque, round(108 * facteur), 0.60).save(
            dossier / 'ic_launcher_foreground.png'
        )

        # L'icone d'avant Android 8, pour les telephones qui ignorent la
        # precedente : elle porte son propre fond, personne ne le lui donnera.
        cote = round(48 * facteur)
        ancienne = Image.new('RGBA', (cote, cote), (255, 255, 255, 255))
        ancienne.alpha_composite(poser(marque, cote, 0.74))
        ancienne.convert('RGB').save(dossier / 'ic_launcher.png')

    (RES / 'mipmap-anydpi-v26').mkdir(parents=True, exist_ok=True)
    (RES / 'mipmap-anydpi-v26' / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n',
        encoding='utf-8',
    )
    (RES / 'values' / 'ic_launcher_background.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <color name="ic_launcher_background">#FFFFFF</color>\n'
        '</resources>\n',
        encoding='utf-8',
    )

    print('marque  :', marque.size, '->', ASSETS / 'logo_mark.png')
    print('mot     :', mot.size, '->', ASSETS / 'logo_wordmark.png')
    print('mot clair:', mot.size, '->', ASSETS / 'logo_wordmark_light.png')
    print('icones  :', ', '.join(DENSITES))


if __name__ == '__main__':
    main()
