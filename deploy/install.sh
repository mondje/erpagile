#!/bin/sh
# Installation d'ERP Agile sur un serveur Linux (ou macOS), en quelques questions.
#
#   sh install.sh                      questions posées une à une
#   sh install.sh --domain=erp.client.ci --email=it@client.ci --yes
#   sh install.sh --local --yes        réseau local seulement (HTTP)
#
# Ce que fait le script :
#   1. vérifie Docker (et propose de l'installer sous Linux) ;
#   2. copie les fichiers d'installation dans le dossier choisi
#      (par défaut /opt/erpagile, ou ~/erpagile sans droits administrateur) ;
#   3. crée les secrets (.env) : mots de passe et clés tirés au hasard ;
#   4. télécharge les images et démarre ERP Agile ;
#   5. affiche l'adresse à ouvrir et un QR code pour les téléphones.
# Relancé sur une installation existante, il garde ses secrets et ses données.
#
# Options : --dir=… --domain=… --email=… --local --version=… --http-port=…
#           --https-port=… --registry=… --yes (aucune question)

set -eu

SRC="$(cd "$(dirname "$0")" && pwd)"
DIR=""; DOMAIN=""; EMAIL=""; LOCAL=0; VERSION="stable"; YES=0
HTTP_PORT=80; HTTPS_PORT=443; REGISTRY="ghcr.io/mondje/erpagile"

for arg in "$@"; do
  case "$arg" in
    --dir=*) DIR="${arg#*=}" ;;
    --domain=*) DOMAIN="${arg#*=}" ;;
    --email=*) EMAIL="${arg#*=}" ;;
    --local) LOCAL=1 ;;
    --version=*) VERSION="${arg#*=}" ;;
    --http-port=*) HTTP_PORT="${arg#*=}" ;;
    --https-port=*) HTTPS_PORT="${arg#*=}" ;;
    --registry=*) REGISTRY="${arg#*=}" ;;
    --yes|-y) YES=1 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $arg" >&2; exit 2 ;;
  esac
done

say() { printf '\n\033[1;32m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*" >&2; }
die() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }
ask() { # question, valeur par défaut → réponse
  if [ "$YES" = 1 ]; then printf '%s' "$2"; return; fi
  printf '%s [%s] : ' "$1" "$2" >&2
  read -r answer || answer=""
  printf '%s' "${answer:-$2}"
}
yes_no() { # question → 0 si oui
  [ "$YES" = 1 ] && return 0
  printf '%s [O/n] : ' "$1" >&2
  read -r answer || answer=""
  case "$answer" in n|N|non|no) return 1 ;; *) return 0 ;; esac
}
random() { # 64 caractères hexadécimaux
  if command -v openssl >/dev/null 2>&1; then openssl rand -hex 32
  else od -An -tx1 -N32 /dev/urandom | tr -d ' \n'; fi
}

say "ERP Agile — installation"

# 1. Docker -------------------------------------------------------------
SUDO=""
if [ "$(id -u)" != 0 ] && command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi
if ! command -v docker >/dev/null 2>&1; then
  if [ "$(uname -s)" = Linux ] && yes_no "Docker est absent. L'installer maintenant (script officiel get.docker.com) ?"; then
    curl -fsSL https://get.docker.com | $SUDO sh || die "Installation de Docker impossible."
  else
    die "Docker est nécessaire : https://docs.docker.com/get-docker/"
  fi
fi
DOCKER="docker"
if ! docker info >/dev/null 2>&1; then
  if [ -n "$SUDO" ] && $SUDO docker info >/dev/null 2>&1; then DOCKER="$SUDO docker"
  else die "Docker ne répond pas : démarrez-le (ou ajoutez votre compte au groupe docker)."; fi
fi
$DOCKER compose version >/dev/null 2>&1 || die "Docker Compose v2 est nécessaire (docker compose)."

# 2. Dossier -------------------------------------------------------------
if [ -z "$DIR" ]; then
  if [ "$(id -u)" = 0 ] || [ -w /opt ]; then DIR=/opt/erpagile; else DIR="$HOME/erpagile"; fi
  DIR="$(ask "Dossier d'installation" "$DIR")"
fi
$SUDO mkdir -p "$DIR/updater"
if [ "$SRC" != "$DIR" ]; then
  for f in compose.yaml erpagile.sh update.sh install.sh README.md; do
    [ -f "$SRC/$f" ] && $SUDO cp "$SRC/$f" "$DIR/$f"
  done
  $SUDO cp "$SRC/updater/updater.sh" "$DIR/updater/updater.sh"
fi
$SUDO chmod +x "$DIR/erpagile.sh" "$DIR/update.sh" "$DIR/install.sh" 2>/dev/null || true
cd "$DIR"

# 3. Réglages et secrets --------------------------------------------------
if [ -f .env ]; then
  say "Installation existante : réglages et secrets conservés ($DIR/.env)"
else
  if [ "$LOCAL" = 0 ] && [ -z "$DOMAIN" ]; then
    DOMAIN="$(ask "Nom de domaine du serveur (vide = réseau local seulement)" "")"
  fi
  if [ -n "$DOMAIN" ]; then
    [ -z "$EMAIL" ] && EMAIL="$(ask "Email de contact pour le certificat HTTPS" "admin@$DOMAIN")"
    SITE="$DOMAIN"; PUBLIC="https://$DOMAIN"
  else
    SITE=":80"
    IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
    PUBLIC="http://${IP:-localhost}"
    [ "$HTTP_PORT" != 80 ] && PUBLIC="$PUBLIC:$HTTP_PORT"
    warn "Sans nom de domaine, ERP Agile répond en HTTP sur le réseau local : la caméra des téléphones et l'application mobile demandent HTTPS."
  fi
  umask 077
  cat > .env <<ENV
# ERP Agile — réglages de cette installation (créé par install.sh).
# Ce fichier contient des secrets : ne le copiez pas sur une autre installation.
COMPOSE_PROJECT_NAME=erpagile
ERPAGILE_DIR=$DIR
ERP_VERSION=$VERSION
IMAGE_REGISTRY=$REGISTRY
SITE_ADDRESS=$SITE
PUBLIC_URL=$PUBLIC
HTTP_PORT=$HTTP_PORT
HTTPS_PORT=$HTTPS_PORT
# Conteneur de mise à jour (bouton « Mettre à jour ERP Agile » de l'écran Maintenance).
COMPOSE_PROFILES=updater
UPDATER_ENABLED=1
APP_SECRET=$(random)
POSTGRES_PASSWORD=$(random)
JWT_PASSPHRASE=$(random)
# Emails (mot de passe oublié, factures) : smtp://utilisateur:motdepasse@serveur:587
MAILER_DSN=null://null
MAILER_FROM=ERP Agile <no-reply@${DOMAIN:-localhost}>
# Marketplace (modules téléchargés, licences) : laissez vide pour le désactiver.
MARKETPLACE_URL=
MARKETPLACE_TOKEN=
MARKETPLACE_PUBLIC_KEYS=
ENV
  say "Réglages créés ($DIR/.env)"
fi

# 4. Démarrage ------------------------------------------------------------
say "Téléchargement des images (quelques minutes la première fois)"
$DOCKER compose pull
say "Démarrage d'ERP Agile"
$DOCKER compose up -d --remove-orphans

printf 'Préparation de la base'
i=0
until $DOCKER compose exec -T web wget -q -O /dev/null http://127.0.0.1/system/instance 2>/dev/null; do
  i=$((i + 1)); [ "$i" -ge 120 ] && { echo; die "ERP Agile ne répond pas : sh erpagile.sh logs"; }
  printf '.'; sleep 3
done
echo

# 5. Adresse ---------------------------------------------------------------
URL="$(sed -n 's/^PUBLIC_URL=//p' .env)"
say "ERP Agile est prêt : $URL"
echo "  Ouvrez cette adresse : l'assistant crée le compte administrateur et la société."
echo "  Entretien (mise à jour, sauvegarde, démonstration…) : sh $DIR/erpagile.sh"
if command -v qrencode >/dev/null 2>&1; then
  echo "  Téléphones : scannez ce code."
  qrencode -t ANSIUTF8 "$URL/connect"
fi
