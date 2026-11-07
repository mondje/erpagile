#!/bin/sh
# Installation d'ERP Agile en une ligne, sur un serveur Linux (ou macOS) :
#
#   curl -fsSL https://raw.githubusercontent.com/mondje/erpagile/main/get.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/mondje/erpagile/main/get.sh | sh -s -- --domain=erp.societe.ci --email=it@societe.ci --yes
#
# Le script télécharge les fichiers d'installation (dossier deploy/ de ce
# dépôt, à la version demandée) puis lance deploy/install.sh avec les mêmes
# options. Options utiles : --version=X.Y.Z (sinon la dernière version),
# --domain=… --email=… --local --dir=… --yes ; `sh install.sh --help` les liste.
#
# Auteur : N'guessan N'cho N'tamon Stéphane <lazapap2018@gmail.com>

set -eu

REPO="mondje/erpagile"
REF="heads/main"
for arg in "$@"; do
  case "$arg" in
    --version=stable|--version=latest) ;;
    --version=*) REF="tags/v${arg#*=}" ;;
  esac
done

die() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }
command -v tar >/dev/null 2>&1 || die "La commande tar est nécessaire."

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t erpagile)"
trap 'rm -rf "$WORK"' EXIT INT TERM
URL="https://github.com/$REPO/archive/refs/$REF.tar.gz"

printf '\033[1;32m▶ Téléchargement des fichiers d'\''installation d'\''ERP Agile\033[0m\n'
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" -o "$WORK/erpagile.tar.gz" || die "Téléchargement impossible : $URL"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$WORK/erpagile.tar.gz" "$URL" || die "Téléchargement impossible : $URL"
else
  die "curl ou wget est nécessaire."
fi
tar -xzf "$WORK/erpagile.tar.gz" -C "$WORK"
DEPLOY="$(find "$WORK" -mindepth 2 -maxdepth 2 -type d -name deploy | head -n 1)"
[ -n "$DEPLOY" ] && [ -f "$DEPLOY/install.sh" ] || die "Fichiers d'installation introuvables dans l'archive."

# Lancé par « curl … | sh », le script lit ses commandes sur l'entrée standard :
# les questions de l'installation se posent alors au terminal.
if [ ! -t 0 ] && [ -r /dev/tty ] && (: </dev/tty) 2>/dev/null; then
  sh "$DEPLOY/install.sh" "$@" </dev/tty
else
  sh "$DEPLOY/install.sh" "$@"
fi
