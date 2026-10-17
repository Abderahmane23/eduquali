"""Fabrique l'icone du telephone a partir du symbole de la charte.

--- Ce qui a change le 12/10 -----------------------------------------------

Ce script detourait deux PNG poses sur du blanc : le Q a la toque et le mot
« EduQuali ». Les deux ont disparu de la charte EduQuali — « la toque est le
signe de presque toutes les applications scolaires ; elle parle du diplome,
alors qu'EduQuali vend la presence » — et le logo vit desormais en six
fichiers vectoriels, dans `assets/logos/`.

L'application les affiche directement, par `flutter_svg` : rien a fabriquer.

Reste **l'icone du lanceur Android**, qui exige des PNG a cinq resolutions.
C'est tout ce que fait ce script, et il les dessine a partir de la geometrie
exacte du fichier `eduquali-icone-app.svg` plutot que d'en rasteriser le
contenu : la forme est un carre arrondi, un anneau et un triangle, et trois
primitives dessinees a la bonne resolution valent mieux qu'une image
agrandie.

--- Les deux jeux de fichiers, et pourquoi ils ne se ressemblent pas -------

  `ic_launcher.png`              l'icone complete : fond violette, anneau
                                 blanc, queue surligneur. C'est elle que
                                 montrent les anciens telephones.

  `ic_launcher_foreground.png`   le symbole seul, transparent, sur une toile
                                 de 108 unites dont **les 72 du centre
                                 seulement** sont garanties visibles. Android
                                 8 et au-dela la recadre en cercle, en carre
                                 arrondi ou en goutte selon le lanceur, et
                                 anime le fond separement. Un symbole dessine
                                 jusqu'au bord se ferait donc rogner.

Le fond de l'icone adaptative passe du blanc a la violette, dans
`values/ic_launcher_background.xml` : c'est la charte, et un symbole blanc
sur un fond blanc ne se verrait pas.

Usage : python tools/make_logos.py
"""

from __future__ import annotations

import pathlib
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover
    sys.exit('Il manque Pillow : pip install pillow')

MOBILE = pathlib.Path(__file__).resolve().parents[1]
RES = MOBILE / 'android' / 'app' / 'src' / 'main' / 'res'

# --- Les couleurs de la charte, fixes dans les fichiers du logo -----------
VIOLETTE = (0x3A, 0x2F, 0xC9, 0xFF)
SURLIGNEUR = (0x4F, 0xE3, 0x9A, 0xFF)
BLANC = (0xFF, 0xFF, 0xFF, 0xFF)

# --- La geometrie, lue dans `eduquali-icone-app.svg` ----------------------
#
# Son `viewBox` est "-14 -16 128 128". Les coordonnees ci-dessous sont donc
# exprimees dans ce repere, et ramenees a [0,1] par `_normaliser`.
VUE = (-14.0, -16.0, 128.0, 128.0)

# L'anneau : le Q. `stroke-width` 24 autour d'un rayon de 26.
ANNEAU_CENTRE = (50.0, 47.0)
ANNEAU_RAYON = 26.0
ANNEAU_TRAIT = 24.0

# La queue : le coup de surligneur, en biseau.
QUEUE = [(39.0, 52.0), (69.0, 52.0), (107.0, 90.0), (77.0, 90.0)]

# Le rayon des coins du carre, dans le meme repere.
COIN = 29.0

# Les cinq densites d'Android, et la taille de chaque fichier.
DENSITES = {
    'mdpi': (48, 108),
    'hdpi': (72, 162),
    'xhdpi': (96, 216),
    'xxhdpi': (144, 324),
    'xxxhdpi': (192, 432),
}

# Le facteur de suréchantillonnage. On dessine en grand puis on reduit : les
# bords d'un cercle trace directement a 48 px sont crenelés, et une icone
# crenelée se voit sur l'ecran d'accueil, qui est le seul endroit ou elle
# apparait.
SURECH = 8


def _normaliser(x: float, y: float) -> tuple[float, float]:
    """Du repere du SVG vers [0,1]."""
    vx, vy, vw, vh = VUE
    return ((x - vx) / vw, (y - vy) / vh)


def _dessiner(cote: int, *, fond: bool, marge: float = 0.0) -> Image.Image:
    """Le symbole, sur un carre de `cote` points.

    `fond` pose le carre arrondi de violette. `marge` reduit le symbole vers
    le centre : c'est ce qui laisse a Android la place de recadrer.
    """
    grand = cote * SURECH
    toile = Image.new('RGBA', (grand, grand), (0, 0, 0, 0))
    dessin = ImageDraw.Draw(toile)

    def point(x: float, y: float) -> tuple[float, float]:
        nx, ny = _normaliser(x, y)
        # La marge recentre : 0,25 de marge laisse le symbole dans la moitie
        # centrale de la toile.
        nx = 0.5 + (nx - 0.5) * (1 - marge)
        ny = 0.5 + (ny - 0.5) * (1 - marge)
        return (nx * grand, ny * grand)

    if fond:
        _, _, vw, _ = VUE
        rayon = COIN / vw * grand
        dessin.rounded_rectangle(
            [(0, 0), (grand - 1, grand - 1)], radius=rayon, fill=VIOLETTE
        )

    # L'anneau. Pillow n'a pas de « cercle avec epaisseur » centre sur le
    # trace : on dessine donc une ellipse de contour, dont `width` croit vers
    # l'interieur ET l'exterieur a parts egales, comme le `stroke` du SVG.
    cx, cy = ANNEAU_CENTRE
    _, _, vw, _ = VUE
    echelle = grand / vw * (1 - marge)
    r = ANNEAU_RAYON * echelle
    trait = ANNEAU_TRAIT * echelle
    centre = point(cx, cy)
    #
    # L'anneau est **blanc dans les deux cas**, et c'est le point qui m'avait
    # echappe : le premier plan de l'icone adaptative se pose sur le fond
    # violette declare dans `ic_launcher_background.xml`. Un anneau violette
    # y serait invisible — c'est exactement ce que la premiere version
    # dessinait, et seule une planche de controle l'a montre.
    #
    # Le centre de l'anneau, lui, differe : sur l'icone complete il laisse
    # voir la violette du carre ; sur le premier plan il doit etre
    # **transparent**, pour que le fond d'Android s'y voie et que le lanceur
    # puisse l'animer separement.
    dessin.ellipse(
        [
            (centre[0] - r - trait / 2, centre[1] - r - trait / 2),
            (centre[0] + r + trait / 2, centre[1] + r + trait / 2),
        ],
        fill=BLANC,
    )
    dessin.ellipse(
        [
            (centre[0] - r + trait / 2, centre[1] - r + trait / 2),
            (centre[0] + r - trait / 2, centre[1] + r - trait / 2),
        ],
        fill=VIOLETTE if fond else (0, 0, 0, 0),
    )

    # La queue, par-dessus : c'est elle qui ferme le Q.
    #
    # Le fichier lui donne un lisere de violette de 5 unites, en
    # `paint-order="stroke"` — donc sous le remplissage. Il separe la queue
    # de l'anneau blanc qu'elle traverse ; sans lui, les deux formes se
    # touchent et le Q perd sa lecture a petite taille.
    coins = [point(x, y) for x, y in QUEUE]
    if fond:
        dessin.polygon(
            coins,
            fill=SURLIGNEUR,
            outline=VIOLETTE,
            width=max(1, round(5 * echelle)),
        )
    else:
        # Sur le premier plan, pas de lisere : il se poserait sur de la
        # transparence et dessinerait un trait violette dans le vide.
        dessin.polygon(coins, fill=SURLIGNEUR)

    return toile.resize((cote, cote), Image.LANCZOS)


def principal() -> int:
    if not RES.is_dir():
        print(f'Introuvable : {RES}', file=sys.stderr)
        return 1

    for densite, (complet, premier_plan) in DENSITES.items():
        dossier = RES / f'mipmap-{densite}'
        dossier.mkdir(parents=True, exist_ok=True)

        _dessiner(complet, fond=True).save(dossier / 'ic_launcher.png')

        # Le premier plan : pas de fond, et le symbole ramene dans les 72
        # unites centrales de la toile de 108 — soit un tiers de marge.
        _dessiner(premier_plan, fond=False, marge=1 / 3).save(
            dossier / 'ic_launcher_foreground.png'
        )

        print(f'  mipmap-{densite:8} {complet}px + {premier_plan}px')

    # Le fond de l'icone adaptative : la violette de la marque.
    fond = RES / 'values' / 'ic_launcher_background.xml'
    fond.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!--\n'
        '  Le fond de l icone adaptative.\n'
        '\n'
        '  La violette de la marque, et non du blanc : le symbole du premier\n'
        '  plan est blanc, et un symbole blanc sur un fond blanc ne se voit\n'
        '  pas. Ecrit par tools/make_logos.py.\n'
        '-->\n'
        '<resources>\n'
        '    <color name="ic_launcher_background">#3A2FC9</color>\n'
        '</resources>\n',
        encoding='utf-8',
    )
    print(f'  {fond.relative_to(MOBILE)} : fond violette')

    print(
        '\nL icone du lanceur est refaite. Le logo de l application, lui,\n'
        'vient des six fichiers de assets/logos/ : rien a fabriquer.'
    )
    return 0


if __name__ == '__main__':
    raise SystemExit(principal())
