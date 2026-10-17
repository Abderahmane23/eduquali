#!/usr/bin/env bash
#
# Met le site en ligne sur Cloudflare Pages.
#
# --- Pourquoi ce fichier existe -------------------------------------------
#
# Constat du 17/10 : `git push` partait bien sur GitHub, mais eduquali.pages.dev
# servait encore une version d'avant la charte EduQuali — son `index.html`
# annonçait « Acalia », le nom de deux renommages en arrière. Autrement dit :
# le projet Pages ne se reconstruit pas depuis le dépôt. Soit il a été créé en
# « dépôt direct » (direct upload), soit sa liaison Git est cassée.
#
# Dans les deux cas, pousser ne suffit pas : il faut **envoyer `dist/`**.
# Ce script fait exactement cela, en une commande, pour qu'une mise en ligne
# ne dépende plus de ce qu'on se rappelle avoir cliqué.
#
# --- Le secret ne vit pas dans le dépôt -----------------------------------
#
# Le jeton Cloudflare est lu dans ~/.eduquali/cloudflare.env, au même endroit
# que le keystore Android — hors du dépôt, donc hors de tout `git push` et de
# tout APK. Le fichier contient deux lignes :
#
#   CLOUDFLARE_ACCOUNT_ID=...
#   CLOUDFLARE_API_TOKEN=...
#
# Le jeton se crée dans le tableau de bord : Mon profil > Jetons d'API >
# Créer un jeton > permission « Compte › Cloudflare Pages › Modifier ».
# C'est la seule permission nécessaire : un jeton plus large est un jeton
# qu'on regrette.
#
# --- Ce que le script ne fait pas -----------------------------------------
#
# Il ne touche pas aux variables de construction. `VITE_SUPABASE_URL` et
# `VITE_SUPABASE_ANON_KEY` sont lues **au moment du build**, ici, depuis
# `frontend/web/.env.production` — qui est ignoré par git. Un build lancé par
# Cloudflare depuis GitHub ne les verrait donc pas, et retomberait
# silencieusement sur le backend simulé : le site s'afficherait, avec des
# données de démonstration et aucune inscription possible. Construire ici et
# envoyer le résultat évite ce piège.

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="$RACINE/frontend/web"
PROJET="${CLOUDFLARE_PAGES_PROJECT:-eduquali}"
SECRETS="${CLOUDFLARE_ENV_FILE:-$HOME/.eduquali/cloudflare.env}"

if [ ! -f "$SECRETS" ]; then
  echo "Jeton absent : $SECRETS" >&2
  echo >&2
  echo "Créez ce fichier avec deux lignes :" >&2
  echo "  CLOUDFLARE_ACCOUNT_ID=..." >&2
  echo "  CLOUDFLARE_API_TOKEN=...   (permission Pages > Modifier)" >&2
  echo >&2
  echo "Sinon, déposez à la main le dossier $SITE/dist" >&2
  echo "dans le tableau de bord Pages (Créer un déploiement)." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$SECRETS"
set +a

: "${CLOUDFLARE_ACCOUNT_ID:?manque dans $SECRETS}"
: "${CLOUDFLARE_API_TOKEN:?manque dans $SECRETS}"

if [ ! -f "$SITE/.env.production" ]; then
  echo "frontend/web/.env.production manquant : le build retomberait sur le" >&2
  echo "backend simulé. Copiez .env.example et renseignez les trois valeurs." >&2
  exit 1
fi

echo "== Vérification =="
cd "$SITE"
npx vitest run --reporter=dot

echo
echo "== Construction =="
rm -rf dist
npm run build

# Un build muet est un build qu'on déploie sans le regarder. Ces deux lignes
# disent le nom et la couleur de la charte : si elles manquent, le mauvais
# `index.html` est parti.
echo
echo "== Ce qui part en ligne =="
grep -o '<title>[^<]*' dist/index.html
grep -o 'theme-color" content="#[0-9A-Fa-f]*' dist/index.html | head -1
grep -o 'assets/index-[A-Za-z0-9_-]*\.js' dist/index.html

echo
echo "== Envoi vers Pages ($PROJET) =="
npx --yes wrangler@4 pages deploy dist \
  --project-name "$PROJET" \
  --branch main \
  --commit-dirty=true

echo
echo "== Contrôle sur le site en ligne =="
# Le contrôle porte sur le site, pas sur la sortie de la commande : une mise
# en ligne « réussie » sur un autre projet ou une autre branche ne change rien
# à ce que voit une famille.
sleep 5
EN_LIGNE="$(curl -s "https://$PROJET.pages.dev/?v=$RANDOM" | grep -o '<title>[^<]*' || true)"
echo "titre servi : $EN_LIGNE"
case "$EN_LIGNE" in
  *EduQuali*) echo "OK : la version en ligne porte le bon nom." ;;
  *) echo "ATTENTION : le site en ligne ne correspond pas au build." >&2
     echo "Le domaine pointe peut-être sur un autre projet ou une autre" >&2
     echo "branche de production. À vérifier dans le tableau de bord." >&2
     exit 1 ;;
esac
