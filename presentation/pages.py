"""Les dix pages du carrousel EduQuali.

--- Les regles de copie appliquees ---------------------------------------

Une page, une idee, une action. Le benefice avant la fonction. Un chiffre
plutot qu'un adjectif. Aucun superlatif sans preuve, aucun fait invente :
ce que je n'ai pas est ecrit entre crochets et demande a la fin.

Typographie francaise : espace insecable avant `:` `;` `!` `?` `%`, guillemets
« », capitales accentuees, « 150 000 GNF », « 17 h 00 ».
"""

from __future__ import annotations

import os
import fitz

from telephone_photo import telephone
from pages_plus import (
    page_assistant, page_captures, page_correction, page_dans_le_cours,
    page_donnee, page_ecoles, page_faq, page_planche_cours,
    page_planche_seance, page_revenu, page_securite,
)
from carrousel import (
    BLANC, COTE, CRAYON, ENCRE, FEUILLE, LIGNE, MARGE, PAPIER, SURLIGNEUR,
    VERT_LISIBLE,
    VIOLETTE, CHARTE, RACINE, SORTIE, Page, icone, largeur,
)

INS = ' '  # espace insecable


def page1(doc):
    """La couverture. Une question, et une famille qui y a deja repondu."""
    p = Page(doc, fond=ENCRE)

    # La photo occupe le haut : c'est elle qui arrete le pouce.
    image = os.path.join(RACINE, 'Fierté familiale au brevet 2025.png')
    p.page.insert_image(fitz.Rect(0, 0, COTE, 600), filename=image)

    # Le logo, pose sur la photo en haut a gauche, a 30 px de haut.
    p.svg(
        os.path.join(CHARTE, 'logos', 'eduquali-logo-inverse.svg'),
        fitz.Rect(MARGE, 56, MARGE + 230, 56 + 53),
    )

    y = 700
    # Le surligneur sur le « 9 », et sur rien d'autre.
    #
    # Il couvrait « 9 eleves sur 10 » — cinq mots. La charte en veut deux ou
    # trois, « ceux qu'il faut retenir » : ici c'en est un seul, et c'est le
    # chiffre qui porte la question. Plus le passage est court, plus il
    # frappe.
    p.texte(MARGE, y, 'Et si', 'titre', 68, BLANC)
    x = MARGE + largeur('Et si ', 'titre', 68)
    l9 = p.surlignage(x, y, '9', 'titre', 68)
    # `surlignage` rend la largeur du mot, pas celle de la bande : la bande
    # deborde des deux cotes, et l'ecart qui suit doit la laisser respirer.
    p.texte(x + l9 + 34, y, 'élèves sur 10', 'titre', 68, BLANC)

    p.texte(MARGE, y + 86, 'réussissaient cette année ?', 'titre', 68, BLANC)

    p.filet(y + 150, couleur=(0.35, 0.34, 0.45))

    # Le slogan, seul, et sur une seule ligne.
    #
    # Il partageait la ligne avec « Des cours en direct, a quinze, sur le
    # programme guineen » : l'ensemble passait sur deux lignes, et la
    # seconde tombait exactement sur le recit en trois temps. Un slogan qui
    # chevauche autre chose n'est plus un slogan. La phrase de produit est
    # dite par les trois temps juste dessous, et redite page 10.
    p.texte(
        MARGE, y + 198, 'Trouvez le professeur qu’il vous faut.',
        'texte', 30, (0.80, 0.80, 0.88),
    )

    # Le recit en trois temps, tout en bas.
    #
    # Le quart inferieur de la couverture etait vide. Ces trois phrases sont
    # la colonne vertebrale de la presentation — chaque page qui suit en
    # developpe une — et les poser ici donne le plan avant la premiere
    # diapositive.
    # Le premier temps disait « Le professeur est la. » — la signature que
    # le slogan remplace. Deux signatures sur la meme page s'annulent ; le
    # recit reprend donc le verbe du slogan.
    y = 980
    for i, mot in enumerate(
        ['Le professeur est trouvé.', 'L’élève était là.',
         'Le parent le voit.']
    ):
        x = MARGE + i * 310
        p.page.draw_circle(
            fitz.Point(x + 5, y - 7), 5, color=None, fill=SURLIGNEUR, width=0
        )
        p.texte(x + 22, y, mot, 'texte', 21, (0.72, 0.71, 0.82))
    return p


def page2(doc):
    """Le probleme. On nomme le fait, on ne fait pas peur."""
    p = Page(doc)
    p.etiquette(MARGE, 140, 'Le problème')

    y = 230
    p.texte(MARGE, y, 'Le programme n’est', 'titre', 60, ENCRE)
    p.texte(MARGE, y + 76, 'pas fini.', 'titre', 60, ENCRE)

    y = 400
    # Le marche existe deja, et il paie.
    #
    # La version precedente decrivait le probleme scolaire et s'arretait la.
    # Un investisseur n'achete pas un probleme : il achete une depense qui a
    # deja lieu et qui est mal servie. La derniere phrase est donc la plus
    # importante des quatre.
    p.paragraphe(
        MARGE, y,
        'Les absences, les grèves, les heures perdues : les chapitres '
        's’accumulent, et l’élève se présente à l’examen sur un programme '
        'qu’il n’a pas vu en entier. Les familles paient déjà un répétiteur '
        'pour rattraper. Elles paient sans savoir s’il est venu.',
        'texte', 29, CRAYON, interligne=1.55,
    )

    # Trois faits, en cartes, chacun avec son chiffre.
    y = 640
    faits = [
        ('348', 'chapitres au programme\ndu secondaire guinéen'),
        ('1 h', 'perdue en trajet par un\nrépétiteur, pour un élève'),
        # Le troisieme chiffre est le seul qui compte pour un investisseur :
        # c'est le manque que personne ne comble, donc la porte d'entree.
        ('0', 'moyen, pour un parent,\nde vérifier une présence'),
    ]
    larg = (COTE - 2 * MARGE - 2 * 24) / 3
    for i, (chiffre, legende) in enumerate(faits):
        x = MARGE + i * (larg + 24)
        p.carte(fitz.Rect(x, y, x + larg, y + 200))
        p.texte(x + 28, y + 86, chiffre, 'titre', 56, VIOLETTE)
        for n, ligne in enumerate(legende.split('\n')):
            p.texte(x + 28, y + 134 + n * 28, ligne, 'texte', 21, CRAYON)
    return p


def page3(doc):
    """La solution. Le mecanisme, et l'ecran qui le montre.

    Le texte decrit, l'ecran prouve. C'est la seule page ou l'on voit la
    classe de quinze en situation — avec la pastille « En direct », la ligne
    du temps et le point de controle — et c'est ce qui separe une promesse
    d'une capture.
    """
    p = Page(doc, fond=VIOLETTE)
    p.etiquette(MARGE, 130, 'La solution', couleur=(0.78, 0.76, 1.0))

    colonne = 520  # la colonne de texte ; le telephone prend la droite

    y = 210
    p.texte(MARGE, y, 'Un professeur', 'titre', 50, BLANC)
    p.texte(MARGE, y + 64, 'devant', 'titre', 50, BLANC)
    x = MARGE + largeur('devant ', 'titre', 50)
    p.surlignage(x, y + 64, 'quinze élèves.', 'titre', 50)

    # Le mecanisme, dit en coûts.
    #
    # « Un professeur guineen, quinze eleves au plus » decrivait la salle de
    # cours. C'est juste, et c'est ce que tout le monde promet. La phrase
    # qu'un investisseur attend est celle d'apres : ce que coute la place
    # suivante.
    p.paragraphe(
        MARGE, 380,
        'Quinze places à heure fixe, vendues avant la séance. Aucune salle '
        'à louer, aucun trajet, aucun stock : une place de plus coûte un '
        'flux vidéo.',
        'texte', 24, (0.88, 0.87, 1.0), largeur_max=colonne - MARGE,
        interligne=1.5,
    )

    y = 560
    etapes = [
        ('direct', 'Payée avant la séance', 'Orange Money, puis MTN MoMo.'),
        ('presence', 'Comptée par le serveur', 'Jamais déclarée par l’élève.'),
        ('eleve', 'Quinze élèves, pas seize', 'La rareté est dans le produit.'),
    ]
    for i, (ico, titre, sous) in enumerate(etapes):
        yy = y + i * 96
        icone(p, ico, MARGE, yy, 44, sur_sombre=True)
        p.texte(MARGE + 64, yy + 22, titre, 'fort', 22, BLANC)
        p.texte(MARGE + 64, yy + 48, sous, 'texte', 18, (0.80, 0.79, 0.97))

    # Une capture de l'application, et non un dessin.
    telephone(p, 'direct', 640, 190, largeur_ecran=300)
    return p


def page4(doc):
    """Les fonctions, et ce qu'elles rendent possible.

    --- Pourquoi cette page a ete ajoutee -------------------------------

    Le jeu passait du mecanisme (« quinze places ») aux benefices par role
    sans jamais dire ce que l'application **fait**. Un investisseur qui a
    compris le modele pose aussitot la question suivante : qu'est-ce qui
    empeche un concurrent de recopier cela en un trimestre ?

    La reponse tient en quatre fonctions. Aucune n'est disponible chez un
    repetiteur, et c'est le titre de la page qui le dit.
    """
    p = Page(doc)
    p.etiquette(MARGE, 140, 'Les fonctions')

    y = 220
    p.texte(MARGE, y, 'Quatre choses qu’un', 'titre', 52, ENCRE)
    p.texte(MARGE, y + 66, 'répétiteur', 'titre', 52, ENCRE)
    x = MARGE + largeur('répétiteur ', 'titre', 52)
    p.surlignage(x, y + 66, 'ne peut pas', 'titre', 52)
    p.texte(MARGE, y + 132, 'faire.', 'titre', 52, ENCRE)

    y = 460
    fonctions = [
        ('eleve', 'Rattraper tout le programme',
         'Les 348 chapitres sont là, du premier au dernier. Un élève en '
         'retard en février reprend au chapitre qu’il a sauté.'),
        ('presence', 'Revoir les années précédentes',
         'Les chapitres des classes passées restent ouverts. On ne révise '
         'pas la 10e année sans la 9e.'),
        ('direct', 'Poser sa question en direct',
         'L’élève lève la main pendant la séance. À quinze, le professeur '
         'a le temps de répondre et de réexpliquer.'),
        ('revenus', 'Vendre la séance une seconde fois',
         'Chaque séance est enregistrée. Le professeur la revend ensuite '
         'en cours vidéo, sans la redonner.'),
    ]

    larg = (COTE - 2 * MARGE - 28) / 2
    for i, (ico, titre, texte) in enumerate(fonctions):
        col, lig = i % 2, i // 2
        x = MARGE + col * (larg + 28)
        yy = y + lig * 232
        p.carte(fitz.Rect(x, yy, x + larg, yy + 208))
        icone(p, ico, x + 28, yy + 28, 48)
        p.texte(x + 28, yy + 118, titre, 'titre7', 25, ENCRE)
        p.paragraphe(
            x + 28, yy + 152, texte, 'texte', 19, CRAYON,
            largeur_max=larg - 56, interligne=1.35,
        )

    # La phrase qui ferme la page : les quatre tiennent par la meme chose.
    p.texte(
        MARGE, 952,
        'Les quatre tiennent à une seule cause : la séance est enregistrée '
        'et comptée.',
        'texte', 21, CRAYON,
    )
    return p


def page5(doc):
    """Les benefices. Un par role, et un chiffre a chaque fois."""
    p = Page(doc)
    p.etiquette(MARGE, 140, 'Ce que chacun y gagne')

    y = 220
    p.texte(MARGE, y, 'Trois personnes', 'titre', 56, ENCRE)
    p.texte(MARGE, y + 70, 'qui paient, ou pas.', 'titre', 56, ENCRE)

    y = 400
    # Chaque bloc commence par ce que la personne gagne, et finit par ce
    # qu'elle fait ensuite. C'est la raison de revenir, donc la recette.
    blocs = [
        ('eleve', 'L’élève rattrape',
         'Son chapitre du programme guinéen, et ceux qu’il a sautés les '
         'années d’avant. Il lève la main et obtient une réponse.'),
        ('parent', 'Le parent vérifie',
         'Une preuve après chaque séance : « Aïssatou a suivi 52 minutes '
         'sur 60. » C’est elle qui fait payer la suivante.'),
        ('professeur', 'Le professeur gagne deux fois',
         '60 % de chaque place en direct, 80 % à domicile — puis la même '
         'séance revendue en vidéo, sans la redonner.'),
    ]
    for ico, titre, texte in blocs:
        p.carte(fitz.Rect(MARGE, y, COTE - MARGE, y + 170))
        icone(p, ico, MARGE + 32, y + 36, 56)
        p.texte(MARGE + 118, y + 62, titre, 'titre7', 32, ENCRE)
        p.paragraphe(
            MARGE + 118, y + 100, texte, 'texte', 22, CRAYON,
            largeur_max=COTE - MARGE - MARGE - 150, interligne=1.4,
        )
        y += 194
    return p


def page6(doc):
    """Pourquoi cela compte. Le fait, puis ce qu'il change."""
    p = Page(doc)
    p.etiquette(MARGE, 140, 'Pourquoi cela compte')

    y = 220
    p.texte(MARGE, y, 'Ce qui se paie', 'titre', 50, ENCRE)
    p.texte(MARGE, y + 64, 'se', 'titre', 50, ENCRE)
    p.surlignage(
        MARGE + largeur('se ', 'titre', 50), y + 64, 'vérifie.', 'titre', 50
    )

    # La phrase qui porte la recette recurrente.
    #
    # Un investisseur lit cette page comme une reponse a « pourquoi
    # reviennent-ils le mois suivant ? ». La preuve n'est pas un argument
    # moral : c'est le declencheur du reachat, et la derniere phrase le dit
    # sans detour.
    p.paragraphe(
        MARGE, 400,
        'Un parent guinéen paie déjà un répétiteur, sans preuve qu’il est '
        'venu. EduQuali ajoute cette preuve — et c’est elle qui fait payer '
        'la séance suivante.',
        'texte', 23, CRAYON, largeur_max=460, interligne=1.5,
    )

    # La classe de quinze, sous le texte.
    y = 640
    p.quinze(MARGE, y, 44, prises=12, mienne=12, ecart=8)
    p.texte(MARGE, y + 196, '12 places prises sur 15.', 'titre7', 24, ENCRE)
    p.paragraphe(
        MARGE, y + 230,
        'Quinze, jamais plus. C’est ce qui est vendu, et ce qui permet au '
        'professeur de voir chacun.',
        'texte', 19, CRAYON, largeur_max=460, interligne=1.4,
    )

    # Et la preuve elle-meme, a droite : la capture de l'ecran qu'un parent
    # recoit apres chaque seance.
    telephone(p, 'preuve', 640, 215, largeur_ecran=300)
    return p


def page7(doc):
    """Le modele economique. Parler d'argent sans detour."""
    p = Page(doc)
    p.etiquette(MARGE, 140, 'Le modèle')

    y = 220
    p.texte(MARGE, y, 'Quatre lignes,', 'titre', 56, ENCRE)
    p.texte(MARGE, y + 70, 'une seule règle.', 'titre', 56, ENCRE)

    # La regle est dite du cote de celui qui lit.
    #
    # « Le professeur garde la plus grosse part » rassure un professeur. Un
    # investisseur, lui, cherche la colonne de droite : ce qui reste. On
    # donne donc les deux, et la part d'EduQuali est celle qui est nommee.
    p.paragraphe(
        MARGE, 370,
        'La part d’EduQuali est fixée avant la publication, et le '
        'professeur la voit. Rien n’est négocié après coup.',
        'texte', 26, CRAYON, interligne=1.4,
    )

    y = 450
    lignes = [
        ('Une place en cours en direct', 'Prix fixé par le professeur', '60 %'),
        ('Des cours à domicile', '500 000 à 900 000 GNF / mois', '80 %'),
        ('Un cours vidéo', 'Prix fixé par le professeur', '80 %'),
        ('Abonnement Pro ou Master', '100 000 ou 200 000 GNF / mois',
         '100 %'),
    ]
    for i, (quoi, prix, part) in enumerate(lignes):
        yy = y + i * 104
        p.carte(fitz.Rect(MARGE, yy, COTE - MARGE, yy + 88))
        p.texte(MARGE + 28, yy + 38, quoi, 'fort', 26, ENCRE)
        p.texte(MARGE + 28, yy + 68, prix, 'texte', 21, CRAYON)
        # La part d'EduQuali, sur la meme ligne que celle du professeur.
        #
        # Elle etait posee au-dessus du grand nombre et le chevauchait. Les
        # deux parts d'une meme ligne se lisent ensemble : on les ecrit donc
        # ensemble, sous le pourcentage.
        reste = ['40 % à EduQuali', '20 % à EduQuali',
                 '20 % à EduQuali', ''][i]
        etiq = (
            f'au professeur · {reste}' if i < 3 else 'pour EduQuali'
        )
        lp = largeur(part, 'titre', 36)
        p.texte(COTE - MARGE - 28 - lp, yy + 42, part, 'titre', 36, VIOLETTE)
        le = largeur(etiq, 'texte', 17)
        p.texte(COTE - MARGE - 28 - le, yy + 68, etiq, 'texte', 17, CRAYON)

    p.texte(
        MARGE, 900,
        'Paiement par Orange Money, puis MTN MoMo. Pas de carte bancaire.',
        'texte', 21, CRAYON,
    )
    return p


def page8(doc):
    """La projection : l'adoption, puis le revenu."""
    p = Page(doc)
    p.etiquette(MARGE, 140, 'La projection')
    p.texte(MARGE, 220, 'Trois ans.', 'titre', 56, ENCRE)

    # --- Premier graphique : qui rejoint, et quand ------------------------

    p.texte(MARGE, 320, 'Qui nous rejoint', 'titre', 28, ENCRE)

    jalons = ['Phase 1', 'Phase 2', 'Phase 3']
    eleves = [100, 200, 2500]
    professeurs = [50, 100, 1000]

    # Un seul axe, et la meme unite : des personnes. Deux echelles
    # superposees donneraient deux courbes qu'on peut faire se croiser ou
    # non en choisissant les graduations — c'est-a-dire rien.
    plafond = 2500.0
    g_haut, g_bas = 370.0, 640.0
    g_gauche = MARGE + 20
    g_droite = COTE - MARGE - 150
    pas = (g_droite - g_gauche) / 2

    def point(serie, i):
        x = g_gauche + i * pas
        y = g_bas - (serie[i] / plafond) * (g_bas - g_haut)
        return x, y

    # La ligne de base, discrete : elle situe, elle ne decore pas.
    p.page.draw_line(
        fitz.Point(g_gauche, g_bas), fitz.Point(g_droite, g_bas),
        color=LIGNE, width=1,
    )

    for serie, couleur, nom in (
        (eleves, VIOLETTE, 'Élèves'),
        (professeurs, VERT_LISIBLE, 'Professeurs'),
    ):
        for i in range(2):
            a, b = point(serie, i), point(serie, i + 1)
            p.page.draw_line(
                fitz.Point(*a), fitz.Point(*b), color=couleur, width=3,
            )
        for i in range(3):
            x, y = point(serie, i)
            # Un disque de 9 points : au-dessous, un lecteur au fond de la
            # salle ne distingue plus le point du trait.
            p.page.draw_circle(
                fitz.Point(x, y), 4.5, color=None, fill=couleur, width=0,
            )
        # Le nom au bout de sa courbe : l'identite ne tient jamais a la
        # seule couleur.
        x, y = point(serie, 2)
        p.texte(x + 16, y + 8, nom, 'texte', 21, CRAYON)
        valeur = f'{serie[2]:,}'.replace(',', ' ')
        p.texte(x + 16, y - 16, valeur, 'titre', 26, ENCRE)

    # Les points de depart, nommes eux aussi : sans eux, la pente n'a pas
    # d'origine et le lecteur ne sait pas d'ou l'on part.
    for serie in (eleves, professeurs):
        x, y = point(serie, 0)
        etiq = str(serie[0])
        p.texte(x - largeur(etiq, 'texte', 19) - 12, y + 6, etiq,
                'texte', 19, CRAYON)

    for i, nom in enumerate(jalons):
        x = g_gauche + i * pas
        ln = largeur(nom, 'texte', 20)
        p.texte(x - ln / 2, g_bas + 32, nom, 'texte', 20, CRAYON)

    # --- Second graphique : ce que cela rapporte --------------------------

    p.texte(MARGE, 730, 'Ce que cela rapporte', 'titre', 28, ENCRE)

    revenus = [('Phase 1', 102, '102 M'), ('Phase 2', 576, '576 M'),
               ('Phase 3', 1840, '1,84 Md')]
    base_y = 940.0
    hauteur_max = 150.0
    larg_barre = 150.0
    ecart = 90.0
    x0 = MARGE + 30

    for i, (nom, valeur, etiq) in enumerate(revenus):
        h = hauteur_max * (valeur / 1840)
        x = x0 + i * (larg_barre + ecart)
        # Meme teinte pour les trois : elles mesurent la meme chose. La
        # difference de taille est deja la difference.
        p.page.draw_rect(
            fitz.Rect(x, base_y - h, x + larg_barre, base_y),
            color=None, fill=VIOLETTE, width=0, radius=0.06,
        )
        le = largeur(etiq, 'titre', 30)
        p.texte(x + (larg_barre - le) / 2, base_y - h - 18, etiq, 'titre', 30,
                ENCRE)
        ln = largeur(nom, 'texte', 20)
        p.texte(x + (larg_barre - ln) / 2, base_y + 30, nom, 'texte', 20,
                CRAYON)

    p.filet(978)
    p.texte(
        MARGE, 1016,
        'Vingt-cinq fois plus d\u2019\u00e9l\u00e8ves, vingt fois plus de '
        'professeurs, dix-huit fois le revenu.',
        'texte', 21, CRAYON,
    )
    return p


def page9(doc):
    """L'equipe. En attente des noms."""
    p = Page(doc)
    p.etiquette(MARGE, 140, 'L’équipe')

    y = 220
    p.texte(MARGE, y, 'Qui porte', 'titre', 56, ENCRE)
    p.texte(MARGE, y + 70, 'le projet.', 'titre', 56, ENCRE)

    y = 400
    for i in range(3):
        yy = y + i * 150
        p.carte(fitz.Rect(MARGE, yy, COTE - MARGE, yy + 130))
        # Une pastille a la place du portrait, tant qu'il n'y en a pas.
        p.page.draw_circle(
            fitz.Point(MARGE + 70, yy + 65), 42,
            color=None, fill=PAPIER, width=0,
        )
        p.texte(MARGE + 150, yy + 56, '[Prénom Nom]', 'titre7', 30, LIGNE)
        p.texte(MARGE + 150, yy + 92, '[Rôle dans le projet]', 'texte', 23,
                LIGNE)

    p.texte(
        MARGE, 900,
        'À compléter : noms, rôles et photos de l’équipe.',
        'texte', 21, CRAYON,
    )
    return p


def page10(doc):
    """Le financement. En attente du montant et de l'emploi."""
    p = Page(doc, fond=VIOLETTE)
    p.etiquette(MARGE, 140, 'Le financement', couleur=(0.78, 0.76, 1.0))

    y = 230
    p.texte(MARGE, y, 'Ce que nous', 'titre', 60, BLANC)
    l = largeur('cherchons ', 'titre', 60)
    p.texte(MARGE, y + 76, 'cherchons', 'titre', 60, BLANC)

    y = 420
    p.page.draw_rect(
        fitz.Rect(MARGE, y, COTE - MARGE, y + 150),
        color=(0.55, 0.52, 0.92), fill=None, width=2, radius=0.06,
    )
    p.texte(MARGE + 36, y + 90, '[Montant recherché]', 'titre', 54,
            (0.72, 0.70, 1.0))

    y = 598
    emplois = [
        ('professeur', '[Recruter les premiers professeurs]', '[Part]'),
        ('direct', '[Tenir le direct : serveurs et vidéo]', '[Part]'),
        ('revenus', '[Aller chercher les familles]', '[Part]'),
    ]
    for i, (ico, quoi, part) in enumerate(emplois):
        yy = y + i * 76
        icone(p, ico, MARGE, yy, 40, sur_sombre=True)
        p.texte(MARGE + 66, yy + 30, quoi, 'fort', 24, (0.88, 0.87, 1.0))
        lp = largeur(part, 'titre7', 24)
        p.texte(COTE - MARGE - lp, yy + 30, part, 'titre7', 24,
                (0.88, 0.87, 1.0))

    # La cloture, sur la meme page.
    #
    # Le jeu finissait sur un « merci » seul. Une page de remerciement ne
    # porte rien : la derniere chose qu'on lit doit etre ce qu'on demande,
    # et comment nous joindre. Le slogan ferme, il ne commence pas.
    p.filet(856, couleur=(0.45, 0.42, 0.82))

    # La cloture s'arrete au-dessus du pied : le symbole et le numero
    # occupent les quatre-vingts derniers points de la page.
    y = 906
    p.texte(MARGE, y, 'Trouvez le', 'titre', 38, BLANC)
    x = MARGE + largeur('Trouvez le ', 'titre', 38)
    p.surlignage(x, y, 'professeur', 'titre', 38)
    lx = x + largeur('professeur', 'titre', 38)
    p.texte(lx + 22, y, 'qu’il vous faut.', 'titre', 38, BLANC)

    p.texte(MARGE, y + 46, '[Téléphone  ·  Courriel  ·  Site]',
            'texte', 19, (0.72, 0.70, 0.95))
    return p


def page11(doc):
    """Merci. Une phrase, et comment nous joindre."""
    p = Page(doc)

    p.svg(
        os.path.join(CHARTE, 'logos', 'eduquali-logo.svg'),
        fitz.Rect(MARGE, 300, MARGE + 330, 300 + 76),
    )

    # Le slogan.
    #
    # Il remplace « Le professeur est la. », que la charte donne comme
    # signature de marque. Les deux disent la meme chose d'un angle
    # different : la signature parle du produit, le slogan s'adresse a qui
    # cherche. C'est ce second ton qui convient a une derniere page.
    y = 470
    p.texte(MARGE, y, 'Trouvez le', 'titre', 58, ENCRE)
    x = MARGE + largeur('Trouvez le ', 'titre', 58)
    p.surlignage(x, y, 'professeur', 'titre', 58)
    p.texte(MARGE, y + 76, 'qu’il vous faut.', 'titre', 58, ENCRE)

    p.filet(y + 150)
    p.paragraphe(
        MARGE, y + 200,
        'Merci de votre attention. Des cours en direct, à quinze, sur le '
        'programme guinéen.',
        'texte', 26, CRAYON,
    )

    y = 840
    p.texte(MARGE, y, '[Contact]', 'fort', 24, LIGNE)
    p.texte(MARGE, y + 38, '[Téléphone  ·  Courriel  ·  Site]', 'texte', 22,
            LIGNE)
    return p


def construire():
    doc = fitz.open()
    # L'ordre d'un jeu qui se tient devant un jury.
    #
    #   1-2   la question, et le probleme
    #   3-5   la solution, les fonctions, l'application
    #   6-9   ce que chacun y gagne : eleve, parent, professeur, ecole
    #   10-12 la donnee, le modele, ou nous en sommes
    #   13-15 la projection, les risques, les questions
    #   16-18 l'equipe, le financement, merci
    # Dix-huit pages.
    #
    # Deux sont tombees en route. « Ce que chacun y gagne » resumait en trois
    # lignes ce que les quatre pages suivantes disent en entier — un resume
    # pose devant son propre developpement se lit deux fois. Et la page de
    # remerciement ne portait rien : la demande et le contact ferment mieux.
    pages = [
        page1,            # 1  la couverture
        page2,            # 2  le probleme
        page3,            # 3  la solution
        page4,            # 4  les fonctions
        page_captures,    # 5  dans l'application
        page_planche_seance,  # une seance, de bout en bout
        page_planche_cours,   # entre deux seances
        page_securite,    # 6  pour le parent
        page_revenu,      # 7  pour le professeur
        page_correction,  # 8  la correction a la source
        page_ecoles,      # 9  les etablissements
        page6,            # 10 pourquoi cela compte — la preuve
        page_donnee,      # 11 ce qui s'accumule
        page7,            # 12 le modele
        # « Ou nous en sommes / Le produit existe » est remplacee par deux
        # pages qui le montrent au lieu de l'affirmer : l'assistant en
        # pleine conversation, et un cours sommaire ouvert. Un jury croit
        # ce qu'il voit avant ce qu'on lui compte.
        page_assistant,   # 13 l'assistant, en conversation
        page_dans_le_cours,  # 14 dans un cours
        page8,            # 15 la projection
        # « Ce qui peut mal tourner » est retiree a la demande.
        page_faq,         # 16 les questions frequentes
        page9,            # 17 l'equipe
        page10,           # 18 le financement, et la cloture
    ]
    for n, fabriquer in enumerate(pages, 1):
        p = fabriquer(doc)
        if n > 1:
            sombre = p.fond in (VIOLETTE, ENCRE)
            p.pied(n, sombre=sombre)
    doc.set_metadata({
        'title': 'EduQuali — Présentation',
        'author': 'EduQuali',
        'subject': 'Des cours en direct, à quinze, sur le programme guinéen.',
    })
    doc.save(SORTIE, deflate=True)
    doc.close()
    taille = os.path.getsize(SORTIE)
    print(f'ecrit : {SORTIE} ({taille // 1024} Ko, {len(pages)} pages)')


if __name__ == '__main__':
    construire()
