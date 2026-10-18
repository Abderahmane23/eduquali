# -*- coding: utf-8 -*-
"""Les pages ajoutees pour un jeu de dix-huit.

--- L'ordre, et d'ou il vient --------------------------------------------

L'enchainement suit celui qu'attendent un jury et un investisseur : le
probleme, la solution, le produit, la demonstration, les benefices, puis
l'argent, puis la preuve que cela existe, puis les doutes — et seulement
ensuite l'equipe et la demande.

Ce qui change par rapport a un jeu de dix pages n'est pas la quantite : ce
sont les trois pages que personne n'ose mettre et que tout jury reclame —
**ou nous en sommes aujourd'hui**, **les risques**, **les questions
frequentes**. Une presentation qui n'a que des bonnes nouvelles se lit comme
une brochure.

--- Les chiffres, et leur source ----------------------------------------

Tous les montants viennent de `strategy.md`, section 5, marquee « arretee » :
40 000 a 50 000 GNF par eleve et par seance, 40 % plateforme / 60 %
professeur, dix eleves reguliers a quatre seances par semaine. Le calcul du
revenu est pose en entier sur la page : un investisseur refait l'arithmetique,
et une ligne qu'il ne peut pas refaire est une ligne qu'il ecarte.

Ce que je n'ai pas est entre crochets. Il n'y a pas de chiffre de resultat
scolaire — l'application n'a pas encore tourne une annee — et la page des
risques le dit au lieu d'en inventer un.
"""

from __future__ import annotations

import fitz

from carrousel import (
    BLANC, COTE, CRAYON, ENCRE, FEUILLE, LIGNE, MARGE, SURLIGNEUR, VIOLETTE,
    Page, icone, largeur,
)
from telephone_photo import hauteur_de, telephone


# =========================================================================
# Dans l'application — trois captures
# =========================================================================

def page_captures(doc):
    """Trois ecrans, cote a cote.

    Ce sont de vraies captures : le meme arbre de widgets que l'APK, rendu
    par le moteur Flutter avec les polices du projet. Les montrer vaut mieux
    que les decrire, et un jury le verifie en demandant le telephone.
    """
    p = Page(doc, fond=ENCRE)
    p.etiquette(MARGE, 130, 'Dans l’application', couleur=(0.62, 0.61, 0.78))

    y = 200
    p.texte(MARGE, y, 'Ce que l’on voit,', 'titre', 48, BLANC)
    p.texte(MARGE, y + 62, 'aujourd’hui.', 'titre', 48, BLANC)

    # Trois telephones, de la reservation a la recompense.
    #
    # Les legendes sont alignees sur **la plus haute** des trois captures,
    # et non chacune sous la sienne : les ecrans n'ont pas le meme nombre de
    # pixels en hauteur, et trois legendes a trois hauteurs differentes se
    # lisent comme un defaut d'alignement.
    ecrans = [
        ('direct', 'Réserver sa place'),
        ('preuve', 'Vérifier la présence'),
        ('boutique', 'Dépenser ses points'),
    ]
    largeur_ecran = 228
    ecart = 38
    haut = 330
    total = 3 * largeur_ecran + 2 * ecart
    x0 = (COTE - total) / 2

    plus_haut = max(hauteur_de(nom, largeur_ecran) for nom, _ in ecrans)
    for i, (nom, legende) in enumerate(ecrans):
        x = x0 + i * (largeur_ecran + ecart)
        telephone(p, nom, x, haut, largeur_ecran=largeur_ecran)
        lg = largeur(legende, 'fort', 19)
        p.texte(x + (largeur_ecran - lg) / 2, haut + plus_haut + 46, legende,
                'fort', 19, BLANC)

    p.texte(
        MARGE, 962,
        'Captures de l’application Android, version 1.17. Rien n’est simulé.',
        'texte', 18, (0.62, 0.61, 0.78),
    )
    return p


# =========================================================================
# La securite du parent
# =========================================================================

def page_securite(doc):
    """Ce qu'un parent controle, et ce que nous ne gardons pas.

    Un parent guineen confie a une application le telephone de son enfant,
    son argent mobile et des photos de devoirs. Les trois inquietudes sont
    concretes ; la page y repond par ce que le produit fait, et par ce qu'il
    refuse de stocker.
    """
    p = Page(doc)
    p.etiquette(MARGE, 140, 'Pour le parent')

    y = 220
    p.texte(MARGE, y, 'La tranquillité', 'titre', 52, ENCRE)
    p.texte(MARGE, y + 66, 'd’abord, la', 'titre', 52, ENCRE)
    x = MARGE + largeur('d’abord, la ', 'titre', 52)
    p.surlignage(x, y + 66, 'réussite', 'titre', 52)
    p.texte(MARGE, y + 132, 'ensuite.', 'titre', 52, ENCRE)

    y = 470
    points = [
        ('presence', 'Il voit la séance en direct',
         'Un bandeau dit « Aïssatou suit Mathématiques, depuis 23 minutes ». '
         'Pas un rapport le soir : maintenant.'),
        ('parent', 'Il ne paie pas à l’aveugle',
         'Orange Money, puis MTN MoMo. Aucune carte bancaire, et nous ne '
         'gardons que les quatre derniers chiffres.'),
        ('eleve', 'Son enfant reste dans sa classe',
         'Quinze élèves, un professeur guinéen, le programme national. '
         'Ni réseau social, ni fil public, ni inconnu.'),
    ]
    for ico, titre, texte in points:
        p.carte(fitz.Rect(MARGE, y, COTE - MARGE, y + 150))
        icone(p, ico, MARGE + 30, y + 32, 50)
        p.texte(MARGE + 110, y + 56, titre, 'titre7', 28, ENCRE)
        p.paragraphe(
            MARGE + 110, y + 92, texte, 'texte', 20, CRAYON,
            largeur_max=COTE - 2 * MARGE - 142, interligne=1.4,
        )
        y += 170

    return p


# =========================================================================
# Le revenu du professeur — le calcul, pose en entier
# =========================================================================

def page_revenu(doc):
    """Ce que gagne un professeur, et l'arithmetique qui le donne.

    C'est la page qui decide du recrutement des professeurs, donc de
    l'existence de l'offre. Elle est ecrite comme un calcul qu'on refait :
    quatre lignes, un total, et la duree de travail en face.
    """
    p = Page(doc)
    p.etiquette(MARGE, 140, 'Pour le professeur')

    y = 220
    p.texte(MARGE, y, 'Un revenu', 'titre', 54, ENCRE)
    p.texte(MARGE, y + 68, 'régulier,', 'titre', 54, ENCRE)
    x = MARGE + largeur('régulier, ', 'titre', 54)
    p.surlignage(x, y + 68, 'calculable.', 'titre', 54)

    # Le calcul, ligne par ligne.
    y = 420
    lignes = [
        ('Prix payé par élève, par séance', '40 000 à 50 000 GNF'),
        ('Part du professeur', '60 %'),
        ('Élèves réguliers', '10'),
        ('Séances par semaine', '4'),
    ]
    for quoi, combien in lignes:
        p.texte(MARGE, y, quoi, 'texte', 23, CRAYON)
        lv = largeur(combien, 'fort', 23)
        p.texte(COTE - MARGE - lv, y, combien, 'fort', 23, ENCRE)
        p.filet(y + 18)
        y += 58

    # Le total, en grand.
    y += 26
    p.carte(fitz.Rect(MARGE, y, COTE - MARGE, y + 190), fond=FEUILLE,
            contour=ENCRE, epaisseur=2.5)
    p.texte(MARGE + 36, y + 52, 'CE QU’IL ENCAISSE PAR MOIS', 'fort', 17,
            CRAYON)
    p.texte(MARGE + 36, y + 128, '4 800 000', 'titre', 76, ENCRE)
    lg = largeur('4 800 000 ', 'titre', 76)
    p.texte(MARGE + 36 + lg, y + 128, 'GNF', 'fort', 30, ENCRE)

    droite = COTE - MARGE - 36
    for i, (val, lib) in enumerate([
        ('12 h', 'd’enseignement par semaine'),
        ('8 000 000 GNF', 'encaissés, dont 40 % à EduQuali'),
    ]):
        lv = largeur(val, 'fort', 22)
        p.texte(droite - lv, y + 92 + i * 56, val, 'fort', 22, VIOLETTE)
        ll = largeur(lib, 'texte', 16)
        p.texte(droite - ll, y + 114 + i * 56, lib, 'texte', 16, CRAYON)

    p.texte(
        MARGE, 952,
        'Sans trajet, sans salle, sans avance : l’élève paie avant la séance.',
        'texte', 21, CRAYON,
    )
    return p


# =========================================================================
# La correction — le probleme pris a la source
# =========================================================================

def page_correction(doc):
    """L'avis ecrit du professeur, et ce qu'il declenche.

    C'est la fonction la moins visible et la plus difficile a copier : le
    professeur ne rend pas une note, il rend une phrase — « il confond les
    deux identites remarquables » — et cette phrase oriente la seance
    suivante. C'est aussi la matiere premiere de la page sur la donnee.
    """
    p = Page(doc, fond=VIOLETTE)
    p.etiquette(MARGE, 130, 'La correction', couleur=(0.78, 0.76, 1.0))

    y = 210
    p.texte(MARGE, y, 'Le problème,', 'titre', 50, BLANC)
    p.texte(MARGE, y + 64, 'pris à', 'titre', 50, BLANC)
    x = MARGE + largeur('pris à ', 'titre', 50)
    p.surlignage(x, y + 64, 'la source.', 'titre', 50)

    p.paragraphe(
        MARGE, 400,
        'L’élève envoie son exercice en photo. Le professeur corrige une '
        'fois par semaine — et il doit écrire un avis, pas seulement une '
        'note. C’est une obligation du produit, pas une bonne pratique.',
        'texte', 23, (0.88, 0.87, 1.0), largeur_max=520, interligne=1.5,
    )

    # Les trois temps, en colonne.
    y = 640
    for i, (titre, sous) in enumerate([
        ('1. La photo', 'L’exercice part du téléphone de l’élève.'),
        ('2. L’avis écrit', '« Il confond les deux identités remarquables. »'),
        ('3. La séance suivante', 'Le professeur reprend ce point, pour tous.'),
    ]):
        yy = y + i * 92
        p.page.draw_circle(
            fitz.Point(MARGE + 7, yy - 8), 7, color=None, fill=SURLIGNEUR,
            width=0,
        )
        p.texte(MARGE + 30, yy, titre, 'fort', 23, BLANC)
        p.texte(MARGE + 30, yy + 30, sous, 'texte', 19, (0.80, 0.79, 0.97))

    # La citation, a droite : c'est elle qu'un parent lit.
    carte = fitz.Rect(640, 420, COTE - MARGE, 760)
    p.page.draw_rect(carte, color=None, fill=(0.16, 0.13, 0.52), width=0,
                     radius=0.05)
    p.texte(664, 474, 'L’AVIS DU PROFESSEUR', 'fort', 15, (0.70, 0.69, 0.92))
    p.paragraphe(
        664, 530,
        '« Aïssatou pose bien les équations, mais elle confond les deux '
        'identités remarquables. Je reprends ce point lundi. »',
        'texte', 21, BLANC, largeur_max=272, interligne=1.5,
    )
    p.texte(664, 712, 'M. Diallo · Mathématiques', 'texte', 17,
            (0.70, 0.69, 0.92))

    # Ce qui est construit, et ce qui ne l'est pas.
    #
    # La page decrit la correction au present. Elle est specifiee — l'avis
    # ecrit obligatoire vient du document de strategie — et **elle n'est pas
    # encore construite**. Une page qui l'annonce au present, suivie trois
    # diapositives plus loin d'un etat des lieux qui ne la mentionne pas,
    # laisse un jury conclure qu'elle tourne. Elle est donc datee ici.
    p.texte(
        MARGE, 946,
        'Une note classe. Une phrase corrige. Le produit exige la phrase.',
        'texte', 21, (0.78, 0.76, 1.0),
    )
    p.texte(
        MARGE, 982,
        'Spécifié et arrêté ; la construction est prévue au premier '
        'trimestre.',
        'texte', 18, (0.62, 0.61, 0.85),
    )
    return p


# =========================================================================
# Les ecoles — annoncer et recruter
# =========================================================================

def page_ecoles(doc):
    """La deuxieme demande : les etablissements.

    Les ecoles sont deja dans le produit, et elles ne paient pas la meme
    chose que les familles : elles achetent de la visibilite a la rentree et
    des professeurs verifies. C'est une recette qui ne depend pas du nombre
    d'eleves inscrits, et un jury le remarque.
    """
    p = Page(doc)
    p.etiquette(MARGE, 140, 'Les établissements')

    y = 220
    p.texte(MARGE, y, 'Une seconde', 'titre', 54, ENCRE)
    p.texte(MARGE, y + 68, 'demande,', 'titre', 54, ENCRE)
    x = MARGE + largeur('demande, ', 'titre', 54)
    p.surlignage(x, y + 68, 'qui paie.', 'titre', 54)

    y = 430
    larg = (COTE - 2 * MARGE - 28) / 2
    blocs = [
        ('professeur', 'Annoncer à la rentrée',
         'Une école publie sa promotion dans l’application. Les vues sont '
         'comptées, école par école : elle sait ce qu’elle a acheté.'),
        ('eleve', 'Recruter un professeur',
         'Elle publie une offre, reçoit des candidatures, fait passer un '
         'test de compétence dans l’application et lit les notes laissées '
         'après chaque séance.'),
    ]
    for i, (ico, titre, texte) in enumerate(blocs):
        x = MARGE + i * (larg + 28)
        p.carte(fitz.Rect(x, y, x + larg, y + 300))
        icone(p, ico, x + 32, y + 32, 52)
        p.texte(x + 32, y + 130, titre, 'titre7', 27, ENCRE)
        p.paragraphe(
            x + 32, y + 172, texte, 'texte', 20, CRAYON,
            largeur_max=larg - 64, interligne=1.4,
        )

    # Ce qui existe deja, dit en clair.
    p.filet(800)
    p.paragraphe(
        MARGE, 846,
        'Les deux fonctions sont construites : promotions avec compteur de '
        'vues, offres, candidatures, tests de compétence notés par le '
        'serveur, avis après chaque séance.',
        'texte', 22, CRAYON, interligne=1.45,
    )
    return p


# =========================================================================
# La donnee qui s'accumule
# =========================================================================

def page_donnee(doc):
    """Ce qui s'accumule, et pourquoi cela vaut plus chaque annee.

    La page que reclame un investisseur apres le modele : qu'est-ce qui rend
    l'annee 3 plus difficile a attaquer que l'annee 1 ? Ici, ce n'est pas la
    taille — c'est un jeu de donnees que personne d'autre ne possede sur le
    programme guineen.
    """
    p = Page(doc)
    p.etiquette(MARGE, 140, 'La donnée')

    y = 220
    p.texte(MARGE, y, 'Ce qui', 'titre', 54, ENCRE)
    x = MARGE + largeur('Ce qui ', 'titre', 54)
    p.surlignage(x, y, 's’accumule.', 'titre', 54)

    p.paragraphe(
        MARGE, 340,
        'Chaque séance laisse des traces structurées, et aucune n’est '
        'déclarative. Au bout d’une année scolaire, elles disent où les '
        'élèves guinéens décrochent, chapitre par chapitre.',
        'texte', 25, CRAYON, interligne=1.5,
    )

    y = 490
    lignes = [
        ('Les minutes suivies', 'Comptées par le serveur de visioconférence.'),
        ('Les réponses aux points de contrôle',
         'Quatre par séance : où l’attention lâche.'),
        ('Les avis écrits des professeurs',
         'Obligatoires à chaque correction.'),
        ('Les tests de compétence', 'Corrigés par le serveur, pas déclarés.'),
        ('Le programme officiel', '348 chapitres, manuels et annales.'),
    ]
    for quoi, sous in lignes:
        p.page.draw_circle(
            fitz.Point(MARGE + 6, y - 7), 6, color=None, fill=VIOLETTE,
            width=0,
        )
        p.texte(MARGE + 28, y, quoi, 'fort', 23, ENCRE)
        lq = largeur(quoi, 'fort', 23)
        p.texte(MARGE + 28, y + 28, sous, 'texte', 19, CRAYON)
        y += 76

    p.carte(fitz.Rect(MARGE, 890, COTE - MARGE, 1000), fond=FEUILLE,
            contour=ENCRE, epaisseur=2.5)
    p.paragraphe(
        MARGE + 32, 934,
        'Un concurrent peut copier les écrans en un trimestre. Il ne peut '
        'pas copier une année de réponses d’élèves guinéens.',
        'texte', 22, ENCRE, largeur_max=COTE - 2 * MARGE - 64, interligne=1.4,
    )
    return p


# =========================================================================
# Ou nous en sommes
# =========================================================================

def page_etat(doc):
    """Ce qui tourne aujourd'hui, et ce qui ne tourne pas encore.

    La page qui leve le doute principal d'un jury : « est-ce une idee ou un
    produit ? ». Elle donne des chiffres verifiables, et elle dit aussi ce
    qui manque — une liste sans manque n'est pas lue comme une liste.
    """
    p = Page(doc)
    p.etiquette(MARGE, 140, 'Où nous en sommes')

    y = 220
    p.texte(MARGE, y, 'Le produit', 'titre', 54, ENCRE)
    x = MARGE + largeur('Le produit ', 'titre', 54)
    p.surlignage(x, y, 'existe.', 'titre', 54)

    # Quatre chiffres, en bandeau.
    y = 380
    chiffres = [
        ('91', 'écrans dans\nl’application'),
        ('89', 'routes sur\nle serveur'),
        # 293 (site) + 685 (application) + 189 (serveur). Le chiffre
        # precedent oubliait le serveur : sur une page qui promet des
        # chiffres verifiables, un chiffre faux coute plus qu'il ne rapporte.
        ('1 167', 'tests qui passent,\nserveur compris'),
        ('1.17', 'APK signé,\n77,8 Mo'),
    ]
    larg = (COTE - 2 * MARGE - 3 * 20) / 4
    for i, (chiffre, legende) in enumerate(chiffres):
        x = MARGE + i * (larg + 20)
        p.carte(fitz.Rect(x, y, x + larg, y + 180))
        p.texte(x + 24, y + 76, chiffre, 'titre', 48, VIOLETTE)
        for n, ligne in enumerate(legende.split('\n')):
            p.texte(x + 24, y + 116 + n * 26, ligne, 'texte', 18, CRAYON)

    # Ce qui tourne.
    y = 620
    p.texte(MARGE, y, 'Ce qui tourne', 'titre7', 26, ENCRE)
    for i, ligne in enumerate([
        'Application Android signée, distribuée directement.',
        'Site web : neuf écrans, inscription, paiement, salle de cours.',
        'Cours en direct, présence comptée, points de contrôle, rediffusion.',
        'Paiement Orange Money en bac à sable, prêt pour la production.',
    ]):
        p.texte(MARGE, y + 44 + i * 36, '· ' + ligne, 'texte', 20, CRAYON)

    # Ce qui ne tourne pas. On le dit.
    y = 826
    p.texte(MARGE, y, 'Ce qui ne tourne pas encore', 'titre7', 26, ENCRE)
    for i, ligne in enumerate([
        'Aucun professeur n’enseigne le primaire : le catalogue s’arrête au '
        'secondaire.',
        'La correction des exercices en photo est spécifiée, pas construite.',
        'Aucune modération sur les discussions de groupe.',
    ]):
        p.paragraphe(
            MARGE, y + 44 + i * 36, '· ' + ligne, 'texte', 20, CRAYON,
            interligne=1.3,
        )
    return p


# =========================================================================
# Les risques
# =========================================================================

def page_risques(doc):
    """Quatre doutes, et ce que nous en faisons.

    Un jury pose ces questions de toute facon. Les poser soi-meme change le
    rapport : on cesse d'etre defendu, on explique. Chaque reponse est une
    decision deja prise, pas une intention.
    """
    p = Page(doc, fond=ENCRE)
    p.etiquette(MARGE, 140, 'Les risques', couleur=(0.62, 0.61, 0.78))

    y = 220
    p.texte(MARGE, y, 'Ce qui peut', 'titre', 54, BLANC)
    p.texte(MARGE, y + 68, 'mal tourner.', 'titre', 54, BLANC)

    y = 420
    risques = [
        ('La connexion',
         'Une séance en direct sur un réseau guinéen peut couper. Chaque '
         'séance est enregistrée : les minutes manquées se rattrapent, et '
         'l’écran le dit au lieu de s’excuser.'),
        ('Le paiement',
         'Orange Money d’abord, MTN MoMo ensuite. Le serveur relit le prix '
         'et prend la place de façon atomique : une place payée deux fois '
         'n’existe pas.'),
        ('Le recrutement des professeurs',
         'C’est la condition de départ. L’argument est un chiffre : '
         '4 800 000 GNF par mois pour douze heures, sans trajet.'),
        ('La concurrence',
         'Les écrans se copient. Une année de réponses d’élèves sur le '
         'programme guinéen, non.'),
    ]
    for titre, texte in risques:
        p.page.draw_rect(
            fitz.Rect(MARGE, y, COTE - MARGE, y + 128),
            color=(0.28, 0.26, 0.45), fill=(0.13, 0.11, 0.30), width=1.5,
            radius=0.05,
        )
        p.texte(MARGE + 28, y + 42, titre, 'titre7', 25, SURLIGNEUR)
        p.paragraphe(
            MARGE + 28, y + 76, texte, 'texte', 19, (0.82, 0.81, 0.93),
            largeur_max=COTE - 2 * MARGE - 56, interligne=1.35,
        )
        y += 144

    return p


# =========================================================================
# Les questions frequentes
# =========================================================================

def page_faq(doc):
    """Les six questions qu'on nous pose, et ce qu'elles cachent.

    Chaque question est posee dans les mots qu'on emploie vraiment, et non
    dans ceux d'une objection de produit : un parent ne demande pas « mon
    enfant va-t-il reussir ? », il demande « comment je sais que ca marche ».

    Et chaque reponse montre le mecanisme qui sert les deux cotes a la fois.
    C'est ce qui fait tenir une place de marche : si une seule partie y
    gagne, l'autre s'en va, et un jury le sait.
    """
    p = Page(doc)
    p.etiquette(MARGE, 140, 'Questions fréquentes')

    y = 220
    p.texte(MARGE, y, 'Ce qu’on nous', 'titre', 52, ENCRE)
    p.texte(MARGE, y + 66, 'demande.', 'titre', 52, ENCRE)

    y = 392
    questions = [
        (
            'Comment je sais que ça marche, pour mon enfant\xa0?',
            'Vous voyez ses minutes suivies et ses points de contrôle répondus, séance par séance. Comptés par EduQuali, pas déclarés par l’élève. Le professeur lit la même chose, et bâtit la séance suivante sur ce qui a manqué.',
        ),
        (
            'Un professeur gagne-t-il assez pour rester\xa0?',
            '4\xa0800\xa0000\xa0GNF par mois pour douze heures de cours par semaine, sa part étant de 60\xa0%. Il reste parce qu’il gagne — et la famille garde le même professeur toute l’année.',
        ),
        (
            'Un élève qui n’ose pas parler, il fait quoi\xa0?',
            'Il écrit au professeur pendant la séance, sans lever la main devant les autres. À quinze, le professeur voit qui décroche\xa0; à trente, il ne le voit plus. Et des amis d’une même classe prennent la même séance.',
        ),
        (
            'Les notes montent-elles vraiment\xa0?',
            'Nous n’en savons rien, et personne ne peut le dire après quelques mois. Ce que nous mesurons aujourd’hui\xa0: présence, points de contrôle, séances rattrapées. Les résultats de la première promotion seront publiés, bons ou mauvais.',
        ),
        (
            'Comment une famille paie-t-elle moins pendant que le professeur gagne plus\xa0?',
            'Parce qu’ils sont quinze à payer l’heure, au lieu d’un seul chez lui. Le répétiteur à domicile coûte plus cher à la famille et rapporte moins au professeur\xa0: c’est le même argent, réparti autrement.',
        ),
        (
            'Qu’est-ce qui les empêche de continuer sans vous\xa0?',
            'Rien, et c’est sain. Ce qui les ramène\xa0: la preuve de présence pour le parent, le rattrapage pour l’élève, le paiement sans espèces, et les cours enregistrés qui paient le professeur quand il ne donne pas cours.',
        ),
    ]
    larg = (COTE - 2 * MARGE - 28) / 2
    for i, (q, r) in enumerate(questions):
        col, lig = i % 2, i // 2
        x = MARGE + col * (larg + 28)
        yy = y + lig * 204
        p.paragraphe(x, yy, q, 'fort', 22, ENCRE, largeur_max=larg,
                     interligne=1.3)
        p.paragraphe(x, yy + 66, r, 'texte', 18, CRAYON, largeur_max=larg,
                     interligne=1.42)
    return p

def page_planche_seance(doc):
    """Reserver, suivre, prouver — les trois ecrans d'une seance."""
    p = Page(doc)
    p.etiquette(MARGE, 140, 'Une seance, de bout en bout')

    p.texte(MARGE, 220, 'R\u00e9server, suivre,', 'titre', 50, ENCRE)
    x = MARGE + largeur('R\u00e9server, suivre, ', 'titre', 50)
    p.surlignage(x, 220, 'prouver.', 'titre', 50)

    # Trois telephones de front : c'est la suite des gestes, pas un
    # catalogue d'ecrans. On les lit de gauche a droite comme une phrase.
    ecrans = [
        ('reserver', 'On choisit', 'le professeur, l\u2019heure, le lieu'),
        ('direct', 'On suit', 'quinze places, pas une de plus'),
        ('preuve', 'On v\u00e9rifie', '52 minutes sur 60, compt\u00e9es'),
    ]
    # Les trois ecrans sont cales sur leur HAUTEUR, pas sur leur largeur.
    #
    # Calibres par la largeur, trois captures de proportions differentes
    # descendaient a trois hauteurs differentes, et la legende posee a une
    # ordonnee fixe tombait sur l'image. La legende passe d'ailleurs
    # au-dessus du telephone : en dessous, sa place depend du plus long des
    # trois, ce qui est une dependance de trop.
    haut = 466.0
    larges = [haut / hauteur_de(nom, 1) for nom, _, _ in ecrans]
    ecart = 40.0
    x = (COTE - sum(larges) - 2 * ecart) / 2

    for (nom, titre, sous), larg in zip(ecrans, larges):
        lt = largeur(titre, 'fort', 24)
        p.texte(x + (larg - lt) / 2, 350, titre, 'fort', 24, ENCRE)
        p.paragraphe(x, 376, sous, 'texte', 18, CRAYON,
                     largeur_max=larg, interligne=1.3)
        telephone(p, nom, x, 438.0, largeur_ecran=larg)
        x += larg + ecart

    p.filet(922)
    p.texte(
        MARGE, 954,
        'Le parent ne demande pas si son enfant \u00e9tait l\u00e0 : il le voit.',
        'texte', 21, CRAYON,
    )
    return p


def page_planche_cours(doc):
    """Le catalogue, et l'accueil d'un eleve."""
    p = Page(doc)
    p.etiquette(MARGE, 140, 'Entre deux s\u00e9ances')

    p.texte(MARGE, 220, 'Le programme', 'titre', 50, ENCRE)
    x = MARGE + largeur('Le programme ', 'titre', 50)
    p.surlignage(x, 220, 'reste ouvert.', 'titre', 50)

    p.paragraphe(
        MARGE, 300,
        'Un \u00e9l\u00e8ve en retard reprend le chapitre quand il veut, et '
        'r\u00e9vise les sujets des ann\u00e9es pass\u00e9es. Le professeur, lui, '
        'vend le m\u00eame cours autant de fois qu\u2019il se regarde.',
        'texte', 24, CRAYON, interligne=1.45,
    )

    ecrans = [('catalogue', 'Le catalogue'), ('accueil', 'Son accueil')]
    haut = 470.0
    larges = [haut / hauteur_de(nom, 1) for nom, _ in ecrans]
    ecart = 80.0
    x = (COTE - sum(larges) - ecart) / 2

    for (nom, titre), larg in zip(ecrans, larges):
        lt = largeur(titre, 'fort', 24)
        p.texte(x + (larg - lt) / 2, 450, titre, 'fort', 24, ENCRE)
        telephone(p, nom, x, 486.0, largeur_ecran=larg)
        x += larg + ecart

    return p


def page_assistant(doc):
    """L'assistant, pris en pleine conversation."""
    p = Page(doc)
    p.etiquette(MARGE, 140, 'L\u2019assistant')

    p.texte(MARGE, 220, 'Une question', 'titre', 50, ENCRE)
    p.texte(MARGE, 284, '\u00e0 toute heure.', 'titre', 50, ENCRE)

    p.paragraphe(
        MARGE, 380,
        'Le cours est pass\u00e9, le professeur dort, et l\u2019exercice est pour '
        'demain. L\u2019assistant ne donne pas la r\u00e9ponse : il montre comment '
        'y arriver, sur le programme guin\u00e9en, et renvoie vers le direct '
        'o\u00f9 le chapitre sera repris.',
        'texte', 23, CRAYON, largeur_max=430, interligne=1.5,
    )

    p.texte(MARGE, 700, 'Ce qu\u2019il co\u00fbte \u00e0 l\u2019\u00e9l\u00e8ve', 'fort', 20, ENCRE)
    p.paragraphe(
        MARGE, 740,
        'Rien de plus que son abonnement. La cl\u00e9 du mod\u00e8le ne descend '
        'jamais dans le t\u00e9l\u00e9phone : elle vit sur le serveur, qui compte '
        'les questions et tient le budget.',
        'texte', 20, CRAYON, largeur_max=430, interligne=1.45,
    )

    # Cale en hauteur : a largeur fixe, une capture longue descendait
    # sous le bord de la page et passait sous le numero.
    haut = 700.0
    larg = haut / hauteur_de('assistant', 1)
    telephone(p, 'assistant', COTE - MARGE - larg, 270.0,
              largeur_ecran=larg)
    return p


def page_dans_le_cours(doc):
    """Un cours ouvert, son sommaire deplie."""
    p = Page(doc)
    p.etiquette(MARGE, 140, 'Dans un cours')

    p.texte(MARGE, 220, 'On voit ce', 'titre', 50, ENCRE)
    x = MARGE + largeur('On voit ce ', 'titre', 50)
    p.surlignage(x, 220, 'qu\u2019on ach\u00e8te.', 'titre', 50)

    p.paragraphe(
        MARGE, 320,
        'Le sommaire est ouvert avant le paiement : chapitres, titres des '
        'vid\u00e9os, dur\u00e9es, ressources. Un cours de 75 000 GNF ne se vend '
        'pas sur un titre.',
        'texte', 23, CRAYON, largeur_max=420, interligne=1.5,
    )

    lignes = [
        ('3 chapitres', 'd\u00e9pli\u00e9s d\u00e8s l\u2019ouverture'),
        ('6 vid\u00e9os', 'avec leur dur\u00e9e exacte'),
        ('1 h 02', 'de cours, annonc\u00e9e avant l\u2019achat'),
    ]
    y = 560
    for valeur, quoi in lignes:
        p.texte(MARGE, y, valeur, 'titre', 30, ENCRE)
        p.texte(MARGE + largeur(valeur + '  ', 'titre', 30), y, quoi,
                'texte', 20, CRAYON)
        p.filet(y + 20)
        y += 76

    haut = 700.0
    larg = haut / hauteur_de('cours', 1)
    telephone(p, 'cours', COTE - MARGE - larg, 270.0,
              largeur_ecran=larg)
    return p
