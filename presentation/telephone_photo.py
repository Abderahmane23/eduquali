# -*- coding: utf-8 -*-
"""Un telephone qui tient une vraie capture de l'application.

--- Pourquoi des captures et non des dessins ---------------------------

Les ecrans de ce carrousel etaient traces a la main, aux couleurs de la
charte : fideles, mais dessines. Ces images-ci sortent du **vrai arbre de
widgets**, rendu par le moteur Flutter avec les polices du projet
(`frontend/mobile/test/captures_test.dart`, 3x). Ce qu'on montre est donc
l'application, et non une idee de l'application.

Le rendu a d'ailleurs trouve cinq defauts que personne n'avait vus : tous les
prix en Roboto, les libelles de boutons aussi, « 17:08 » au lieu de
« 17 h 08 », une date en « 17/10 », et une rangee qui debordait de huit
points sur un telephone de 390.
"""

from __future__ import annotations

import os

import fitz

from carrousel import ENCRE, Page

CAPTURES = os.path.join(
    r'C:\Users\HP\Desktop\VERIPROF', 'design', 'captures'
)


def telephone(page: Page, nom, x, y, largeur_ecran=300):
    """Pose une capture dans un chassis de telephone.

    Le chassis est un trait d'encre, pas une ombre : la charte n'en laisse
    aucune, et un cadre au trait se lit aussi bien.
    """
    chemin = os.path.join(CAPTURES, f'{nom}.png')
    image = fitz.Pixmap(chemin)
    hauteur = largeur_ecran * image.height / image.width

    # Le chassis.
    page.page.draw_rect(
        fitz.Rect(x - 10, y - 10, x + largeur_ecran + 10, y + hauteur + 10),
        color=ENCRE, fill=ENCRE, width=0, radius=0.05,
    )
    # L'ecran.
    page.page.insert_image(
        fitz.Rect(x, y, x + largeur_ecran, y + hauteur), filename=chemin,
    )
    return hauteur


def hauteur_de(nom, largeur_ecran=300):
    """La hauteur qu'occupera la capture, pour placer le reste."""
    image = fitz.Pixmap(os.path.join(CAPTURES, f'{nom}.png'))
    return largeur_ecran * image.height / image.width
