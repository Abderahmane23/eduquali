"""Construit l'APK de publication, branche au serveur, puis l'allege.

--- Pourquoi ce script existe --------------------------------------------

`flutter build apk --release` produit un APK parfaitement fonctionnel et
**entierement local** : `AppConstants.apiBaseUrl` vaut
`String.fromEnvironment('ACALIA_API')`, vide par defaut. Sans les trois
`--dart-define`, l'application ne joint ni le Worker ni Supabase — elle
travaille sur sa base SQLite, et rien a l'ecran ne le dit.

C'est arrive : les APK 1.13.0 et 1.14.0 du 04/10 ont ete construits sans
aucun define, livres, et annonces comme la version courante. Ils ne parlaient
a aucun serveur.

Le piege est qu'il n'y a **aucun symptome** : l'application s'ouvre, les
ecrans se remplissent avec les donnees semees localement, et seuls les comptes
partages, les groupes et les cours en direct manquent — ce qu'on met sur le
compte d'une base vide.

Ce script retire le choix : il lit les valeurs dans `backend/.env`, verifie
qu'elles sont la, et refuse de construire sinon.

--- Ce qu'il ne met jamais dans l'APK ------------------------------------

La cle `service_role` et la cle Gemini. La premiere passe outre RLS, la
seconde se facture. Un APK circule par Bluetooth et se decompile en quelques
minutes : seule la cle `anon` y entre, qui est publique par construction.

Usage :
    python tools/build_release.py           # construit et allege
    python tools/build_release.py --sans-repack
"""

from __future__ import annotations

import io
import os
import subprocess
import sys
from pathlib import Path

ICI = Path(__file__).resolve().parent
MOBILE = ICI.parent
DEPOT = MOBILE.parent.parent
ENV = DEPOT / 'backend' / '.env'

# L'adresse du Worker, prefixe `/api/v1` compris : Hono est monte dessus
# (`new Hono().basePath('/api/v1')`), et l'oublier donne un 404 sur chaque
# appel.
API = 'https://eduquali-api.abder4it.workers.dev/api/v1'

INTERDITES = ('SERVICE_ROLE', 'GEMINI', 'DJOMY', 'LIVEKIT_API_SECRET')


def lire_env(chemin: Path) -> dict[str, str]:
    if not chemin.exists():
        sys.exit(f'{chemin} est absent : impossible de brancher l APK.')
    valeurs: dict[str, str] = {}
    for ligne in io.open(chemin, encoding='utf-8'):
        if '=' in ligne and not ligne.strip().startswith('#'):
            cle, valeur = ligne.split('=', 1)
            valeurs[cle.strip()] = valeur.strip().strip('"').strip("'")
    return valeurs


def main(argv: list[str]) -> int:
    env = lire_env(ENV)
    url = env.get('SUPABASE_URL', '')
    anon = env.get('SUPABASE_ANON_KEY', '')

    if not url or not anon:
        sys.exit(
            'SUPABASE_URL ou SUPABASE_ANON_KEY manque dans backend/.env.\n'
            'Sans elles, l APK se construirait sans serveur — ce que ce '
            'script existe pour empecher.'
        )

    # Garde-fou : une erreur de copie qui mettrait la cle de service ici
    # livrerait un acces complet a la base dans un fichier qui circule par
    # Bluetooth.
    for interdite in INTERDITES:
        if interdite.lower() in anon.lower() or interdite.lower() in url.lower():
            sys.exit(f'La valeur ressemble a une cle « {interdite} ». Arret.')
    if len(anon) > 200:
        sys.exit('La cle anon est anormalement longue : verifier backend/.env.')

    outils = os.environ.copy()
    # Le JDK et le SDK vivent hors du depot sur cette machine ; sans eux
    # Gradle s arrete sur « set the JAVA_HOME variable ».
    outils.setdefault(
        'JAVA_HOME', r'C:\Users\HP\Desktop\App_Maison_Blanche\_toolchain\jdk'
    )
    outils.setdefault(
        'ANDROID_SDK_ROOT',
        r'C:\Users\HP\Desktop\App_Maison_Blanche\_toolchain\android-sdk',
    )

    commande = [
        'flutter',
        'build',
        'apk',
        '--release',
        # x86_64 retire a la demande : aucun telephone vise ne l utilise, et il
        # pesait un tiers du fichier.
        '--target-platform',
        'android-arm,android-arm64',
        f'--dart-define=ACALIA_API={API}',
        f'--dart-define=SUPABASE_URL={url}',
        f'--dart-define=SUPABASE_ANON_KEY={anon}',
    ]

    print('  API       :', API)
    print('  Supabase  :', url)
    print('  Cle anon  :', f'{anon[:12]}… ({len(anon)} caracteres)')
    print('  Gradle met de neuf a dix-huit minutes.\n')

    # `shell=True` sur Windows : `flutter` est un .bat.
    issue = subprocess.run(
        ' '.join(f'"{c}"' if ' ' in c else c for c in commande),
        cwd=str(MOBILE),
        env=outils,
        shell=True,
    )
    if issue.returncode != 0:
        print('\nLa compilation a echoue : rien a alleger.', file=sys.stderr)
        return issue.returncode

    if '--sans-repack' in argv:
        return 0

    print('\n  Allegement et signature…\n')
    return subprocess.run(
        [sys.executable, str(ICI / 'repack_apk.py')],
        cwd=str(MOBILE),
        env=outils,
    ).returncode


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
