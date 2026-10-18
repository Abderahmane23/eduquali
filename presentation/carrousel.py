"""Le carrousel de presentation d'EduQuali, en PDF.

--- Le format -------------------------------------------------------------

Dix pages carrees de 1 080 points. Le carre est le format des carrousels —
LinkedIn, Facebook, TikTok — et le PDF est vectoriel : il reste net imprime
en A4 comme projete sur un mur.

--- La charte, suivie a la lettre ----------------------------------------

Les couleurs et les polices viennent de `design/charte/` ; le logo et les
icones sont les fichiers du systeme, poses en vectoriel et non redessines.
Les quatre interdits tiennent : pas d'ombre, pas de degrade, le surligneur
n'est jamais du texte ni un bouton, et il n'y a pas d'orange.

Une regle de plus, celle qui tient tout le reste : **un seul passage
surligne par page**. « Un surlignage partout ne dit plus rien. »
"""

from __future__ import annotations

import os
import re
import re as _re

import fitz

RACINE = r'C:\Users\HP\Desktop\VERIPROF'
CHARTE = os.path.join(RACINE, 'design', 'charte')
POLICES = os.path.join(RACINE, 'frontend', 'mobile', 'assets', 'fonts')
SORTIE = os.path.join(RACINE, 'EduQuali - Presentation.pdf')

# --- La trousse ----------------------------------------------------------
VIOLETTE = (0x3A / 255, 0x2F / 255, 0xC9 / 255)
SURLIGNEUR = (0x4F / 255, 0xE3 / 255, 0x9A / 255)

# Le vert de la charte, descendu au premier pas lisible.
#
# Le surligneur #4FE39A ne tient pas comme couleur de trait sur une page
# claire : clarte 0,819, hors de la bande lisible, et contraste 1,52 contre
# le papier la ou il en faut 3. Mesure, pas impression — une ligne de trois
# points dans ce vert disparait au videoprojecteur.
#
# #1E8F5E passe tous les controles face a la violette : ecart de teinte 27,7
# en deuteranopie, 33,0 en vision normale, contraste au-dessus de 3. Le
# surligneur reste un surlignage, ce qu'il est.
VERT_LISIBLE = (0x1E / 255, 0x8F / 255, 0x5E / 255)
ENCRE = (0x14 / 255, 0x10 / 255, 0x38 / 255)
CRAYON = (0x55 / 255, 0x53 / 255, 0x6F / 255)
PAPIER = (0xF6 / 255, 0xF5 / 255, 0xFB / 255)
FEUILLE = (1, 1, 1)
LIGNE = (0x8B / 255, 0x89 / 255, 0xA8 / 255)
BLANC = (1, 1, 1)

COTE = 1080.0
MARGE = 84.0

# Le nombre de pages, ecrit une fois : le pied le lit, et il changeait
# a la main a chaque ajout — « 5 / 10 » sur un jeu de dix-huit.
TOTAL = 20

# --- Les polices de la charte, embarquees --------------------------------
FICHIERS = {
    'titre': os.path.join(POLICES, 'Gabarito-800.ttf'),
    'titre7': os.path.join(POLICES, 'Gabarito-700.ttf'),
    'texte': os.path.join(POLICES, 'Lexend-400.ttf'),
    'fort': os.path.join(POLICES, 'Lexend-600.ttf'),
    # L'ecriture enseignee a l'ecole primaire, pour un mot ou deux :
    # « Present ! », « Vu », « Bravo ». Jamais une phrase.
    'cahier': os.path.join(POLICES, 'PlaywriteFRModerne-400.ttf'),
}
MESURES = {nom: fitz.Font(fontfile=chemin) for nom, chemin in FICHIERS.items()}


INSECABLE = ' '


def fr(texte: str) -> str:
    """La typographie francaise, posee une fois pour toutes.

    Espace insecable avant `:` `;` `!` `?` `%` et dans les guillemets. Ce
    n'est pas une coquetterie d'imprimeur : la fonction qui coupe les lignes
    ci-dessous decoupe sur l'espace ordinaire, et sans insecable elle
    renvoyait « 80 » en fin de ligne et « % » au debut de la suivante.

    --- Pourquoi une lambda et non une chaine de remplacement -------------

    La premiere version ecrivait le remplacement `INSECABLE + r'\\1'`. Un
    antislash s'est perdu en chemin, `'\\1'` est devenu `'\x01'` — et en
    Python une chaine de remplacement ne proteste pas : elle a pose le
    caractere de controle U+0001 a la place de chaque `%`. Le PDF affichait
    un carre vide, et le texte extrait s'arretait net.

    Une lambda n'a pas de chaine de remplacement a interpreter. Elle ne peut
    pas se tromper de la meme facon.
    """
    texte = _re.sub(
        r'(?<=\S) ([:;!?%])', lambda m: INSECABLE + m.group(1), texte
    )
    texte = texte.replace('\u00ab ', '\u00ab' + INSECABLE)
    texte = texte.replace(' \u00bb', INSECABLE + '\u00bb')
    return texte


def largeur(texte: str, police: str, taille: float) -> float:
    return MESURES[police].text_length(texte, fontsize=taille)


class Page:
    """Une page du carrousel, et les gestes de la charte."""

    def __init__(self, doc: fitz.Document, fond=PAPIER):
        self.page = doc.new_page(width=COTE, height=COTE)
        self.page.draw_rect(
            fitz.Rect(0, 0, COTE, COTE), color=None, fill=fond, width=0
        )
        self.fond = fond
        for nom, chemin in FICHIERS.items():
            self.page.insert_font(fontname=nom, fontfile=chemin)

    # -- Le texte ---------------------------------------------------------

    def texte(self, x, y, contenu, police='texte', taille=28, couleur=ENCRE):
        """Pose une ligne.

        L'insecable sert a decouper, pas a dessiner : les fichiers de police
        du systeme de design sont des sous-ensembles et n'ont pas le glyphe
        U+00A0. Il s'affichait en carre vide — « 10 ▯ % ».

        On coupe donc avec, et l'on dessine avec une espace ordinaire : la
        paire reste ensemble sur sa ligne, et le lecteur voit une espace.
        """
        self.page.insert_text(
            (x, y), fr(contenu).replace(INSECABLE, ' '), fontname=police,
            fontsize=taille, color=couleur,
        )
        return y

    def paragraphe(self, x, y, contenu, police='texte', taille=28,
                   couleur=ENCRE, largeur_max=None, interligne=1.5):
        """Un paragraphe coupe a la main : on maitrise chaque ligne."""
        largeur_max = largeur_max or (COTE - 2 * MARGE)
        # La coupe se fait sur l'espace ordinaire : l'insecable, posee par
        # `fr`, tient ensemble ce qui ne doit pas se separer.
        mots = fr(contenu).split(' ')
        ligne, lignes = '', []
        for mot in mots:
            essai = f'{ligne} {mot}'.strip()
            if largeur(essai, police, taille) > largeur_max and ligne:
                lignes.append(ligne)
                ligne = mot
            else:
                ligne = essai
        if ligne:
            lignes.append(ligne)

        pas = taille * interligne
        for n, l in enumerate(lignes):
            self.texte(x, y + n * pas, l, police, taille, couleur)
        return y + len(lignes) * pas

    def surlignage(self, x, y, mot, police='titre', taille=64,
                   couleur=ENCRE):
        """Le surligneur, en biseau. Un seul passage par page."""
        l = largeur(mot, police, taille)
        # Les bornes viennent des metriques de la police, pas d'un rapport
        # choisi a l'oeil : a 68 points, un coefficient approximatif coupait
        # le haut du « 9 » et les accents de « eleves ».
        police_mesure = MESURES[police]
        haut = y - police_mesure.ascender * taille
        bas = y - police_mesure.descender * taille
        # Un peu d'air au-dessus et en dessous : un surligneur passe large,
        # il n'epouse pas la lettre.
        haut -= taille * 0.04
        bas += taille * 0.08
        biais = (bas - haut) * 0.17
        # Le biseau penche la bande vers la droite : son coin haut-gauche
        # tombait donc **dans** le mot. Sur un mot long cela ne se voit pas,
        # la premiere lettre n'allant pas chercher le coin ; sur le « 9 » de
        # la couverture, large de deux biseaux, la bande coupait le chiffre
        # en deux. On elargit donc de la valeur du biais de chaque cote :
        # la bande deborde alors sur l'espace qui precede et celui qui suit,
        # ce que fait un vrai surligneur.
        debord = biais * 1.15
        self.page.draw_polyline(
            [
                (x - debord + biais, haut),
                (x + l + debord, haut),
                (x + l + debord - biais, bas),
                (x - debord, bas),
            ],
            color=None,
            fill=SURLIGNEUR,
            width=0,
            closePath=True,
        )
        # Le texte pose dessus est toujours sombre, dans les deux themes.
        self.texte(x, y, mot, police, taille, ENCRE)
        return l

    def etiquette(self, x, y, mot, couleur=CRAYON):
        """Le sur-titre en capitales : quatre mots au plus."""
        espace = ''
        for i, c in enumerate(mot.upper()):
            espace += c + (' ' if i < len(mot) - 1 else '')
        self.texte(x, y, espace, 'fort', 19, couleur)
        return y

    # -- Les formes -------------------------------------------------------

    def filet(self, y, x1=MARGE, x2=COTE - MARGE, couleur=LIGNE):
        self.page.draw_line(
            fitz.Point(x1, y), fitz.Point(x2, y), color=couleur, width=1.5
        )

    def carte(self, rect, fond=FEUILLE, contour=LIGNE, epaisseur=1.5):
        """Une feuille posee sur le papier. Au trait, jamais a l'ombre."""
        self.page.draw_rect(
            rect, color=contour, fill=fond, width=epaisseur, radius=0.07
        )

    def svg(self, chemin, rect):
        """Un fichier de la charte, pose en vectoriel."""
        doc = fitz.open(chemin)
        pdf = fitz.open('pdf', doc.convert_to_pdf())
        self.page.show_pdf_page(rect, pdf, 0)

    def quinze(self, x, y, cote_place, prises, mienne=None, ecart=10,
               vide_contour=LIGNE):
        """La classe de quinze : trois rangs de cinq, jamais plus."""
        for i in range(15):
            ligne, colonne = divmod(i, 5)
            r = fitz.Rect(
                x + colonne * (cote_place + ecart),
                y + ligne * (cote_place + ecart),
                x + colonne * (cote_place + ecart) + cote_place,
                y + ligne * (cote_place + ecart) + cote_place,
            )
            rang = i + 1
            if rang == mienne:
                self.page.draw_rect(
                    r, color=ENCRE, fill=SURLIGNEUR, width=3, radius=0.2
                )
            elif rang <= prises:
                self.page.draw_rect(
                    r, color=VIOLETTE, fill=VIOLETTE, width=1.5, radius=0.2
                )
            else:
                self.page.draw_rect(
                    r, color=vide_contour, fill=None, width=1.5, radius=0.2
                )

    def pied(self, numero, sombre=False):
        """Le symbole et le numero, en bas de chaque page sauf la premiere."""
        couleur = BLANC if sombre else CRAYON
        symbole = (
            'eduquali-symbole-inverse.svg' if sombre else 'eduquali-symbole.svg'
        )
        self.svg(
            os.path.join(CHARTE, 'logos', symbole),
            fitz.Rect(MARGE, COTE - MARGE - 26, MARGE + 30, COTE - MARGE + 4),
        )
        n = f'{numero} / {TOTAL}'
        self.texte(
            COTE - MARGE - largeur(n, 'texte', 20), COTE - MARGE - 4, n,
            'texte', 20, couleur,
        )


def icone(page: Page, nom, x, y, taille, sur_sombre=False):
    """Une icone de la charte, a la couleur du texte qui l'entoure."""
    chemin = os.path.join(CHARTE, 'icones', f'{nom}.svg')
    if sur_sombre:
        # « Sur un fond violette ou rouge, ou dans une pastille, retirer le
        # surlignage. » Deux gestes, et le second manquait : le trait passe
        # en blanc, **et la barre verte est retiree**. Sur de la violette,
        # elle se lisait comme une tache.
        brut = open(chemin, encoding='utf-8').read()
        brut = brut.replace('#141038', '#FFFFFF')
        brut = re.sub(r'<path fill="#4FE39A"[^>]*></path>', '', brut)
        brut = re.sub(r'<path fill="#4FE39A"[^>]*/>', '', brut)
        temporaire = os.path.join(
            os.environ['TEMP'], f'eq-{nom}-clair.svg'
        )
        open(temporaire, 'w', encoding='utf-8').write(brut)
        chemin = temporaire
    page.svg(chemin, fitz.Rect(x, y, x + taille, y + taille))
