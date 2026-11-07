#!/bin/sh
# Entretien d'ERP Agile, sans connaître Docker : un menu, ou une commande.
#
#   sh erpagile.sh               menu
#   sh erpagile.sh update        mise à jour (sauvegarde d'abord)
#   sh erpagile.sh backup        sauvegarde maintenant
#   sh erpagile.sh status        état des services
#   sh erpagile.sh logs          journaux (Ctrl+C pour quitter)
#   sh erpagile.sh start | stop | restart
#   sh erpagile.sh upgrade       mise à niveau de la base et des modules
#   sh erpagile.sh sync          synchroniser les modules
#   sh erpagile.sh reseed <code> rejouer les écrans d'un module
#   sh erpagile.sh demo [pays]   charger la société de démonstration
#   sh erpagile.sh backups       sauvegardes présentes
#   sh erpagile.sh restore <archive>
#   sh erpagile.sh console <commande…>   commande Symfony (administrateurs)
#   sh erpagile.sh url           adresse et QR code des téléphones

set -eu
cd "$(dirname "$0")"
[ -f .env ] || { echo "Pas d'installation ici : lancez d'abord sh install.sh" >&2; exit 1; }

DOCKER="docker"
if ! docker info >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then DOCKER="sudo docker"; fi
compose() { $DOCKER compose "$@"; }
console() { compose exec -T php php bin/console --no-interaction "$@"; }
say() { printf '\n\033[1;32m▶ %s\033[0m\n' "$*"; }

wait_ready() {
  printf 'Attente du serveur'
  i=0
  until compose exec -T web wget -q -O /dev/null http://127.0.0.1/system/instance 2>/dev/null; do
    i=$((i + 1)); [ "$i" -ge 120 ] && { echo; echo "Le serveur ne répond pas : sh erpagile.sh logs" >&2; return 1; }
    printf '.'; sleep 3
  done
  echo " prêt."
}

action() {
  case "$1" in
    start) say "Démarrage"; compose up -d; wait_ready ;;
    stop) say "Arrêt"; compose stop ;;
    restart) say "Redémarrage"; compose restart php worker web; wait_ready ;;
    status) compose ps ;;
    logs) compose logs -f --tail=200 php worker web caddy ;;
    update)
      say "Sauvegarde avant mise à jour"; console erpagile:backup --keep=30
      say "Nouvelles images"; compose pull php worker web
      say "Redémarrage (la base est mise à niveau au démarrage)"; compose up -d --remove-orphans
      wait_ready ;;
    upgrade) say "Mise à niveau de la base et des modules"; console erpagile:upgrade ;;
    sync) console erpagile:modules:sync ;;
    migrate) console erpagile:upgrade ;;
    reseed)
      [ -n "${2:-}" ] || { echo "Code du module ? (exemple : sh erpagile.sh reseed payroll)" >&2; exit 2; }
      console erpagile:module:reseed-ui "$2" ;;
    demo) say "Société de démonstration"; console erpagile:demo:load --country="${2:-ci}" --users ;;
    backup) say "Sauvegarde"; console erpagile:backup --keep=30 ;;
    backups) console erpagile:backup --list ;;
    restore)
      [ -n "${2:-}" ] || { echo "Archive ? (sh erpagile.sh backups pour la liste)" >&2; exit 2; }
      say "Restauration de $2"; console erpagile:restore "$2" --force ;;
    console) shift; compose exec php php bin/console "$@" ;;
    url)
      URL="$(sed -n 's/^PUBLIC_URL=//p' .env)"; echo "$URL"
      command -v qrencode >/dev/null 2>&1 && qrencode -t ANSIUTF8 "$URL/connect" || true ;;
    *) echo "Action inconnue : $1 (sh erpagile.sh --help)" >&2; exit 2 ;;
  esac
}

if [ $# -gt 0 ]; then
  case "$1" in -h|--help) sed -n '2,19p' "$0"; exit 0 ;; esac
  action "$@"
  exit 0
fi

while true; do
  cat <<'MENU'

  ERP Agile — entretien
  ─────────────────────
   1  État des services          7  Charger la démonstration
   2  Mettre à jour              8  Synchroniser les modules
   3  Sauvegarder maintenant     9  Rejouer les écrans d'un module
   4  Sauvegardes présentes     10  Redémarrer
   5  Journaux                  11  Adresse et QR code
   6  Mettre à niveau la base    0  Quitter
MENU
  printf '  Votre choix : '
  read -r choice || exit 0
  case "$choice" in
    1) action status ;;
    2) action update ;;
    3) action backup ;;
    4) action backups ;;
    5) action logs || true ;;
    6) action upgrade ;;
    7) printf '  Pays (ci) : '; read -r c; action demo "${c:-ci}" ;;
    8) action sync ;;
    9) printf '  Code du module (ex. payroll) : '; read -r m; [ -n "$m" ] && action reseed "$m" ;;
    10) action restart ;;
    11) action url ;;
    0|q) exit 0 ;;
    *) echo "  Choix inconnu." ;;
  esac
done
