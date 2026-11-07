#!/bin/sh
# Conteneur de mise à jour d'ERP Agile.
#
# Il attend les demandes déposées par l'ERP dans /exchange/request.json
# (écran Administration › Maintenance) et ne connaît que deux actions :
#   update  : sauvegarde, version demandée notée dans .env, nouvelles images,
#             redémarrage (la mise à niveau de la base se fait au démarrage
#             du conteneur php), vérification que le serveur répond ;
#   restart : redémarrage des services de l'ERP.
# L'avancement est écrit dans /exchange/status.json, lu par l'écran.
#
# L'ERP ne parle jamais à Docker : seul ce conteneur le fait, sur demande.

set -u
DIR="${ERPAGILE_DIR:-/opt/erpagile}"
EXCHANGE=/exchange
REQUEST="$EXCHANGE/request.json"
STATUS="$EXCHANGE/status.json"
cd "$DIR" || exit 1
compose() { docker compose --project-directory "$DIR" -f "$DIR/compose.yaml" "$@"; }

# Valeur d'un champ texte de la demande (JSON simple écrit par l'ERP).
field() { sed -n "s/.*\"$1\": *\"\\([^\"]*\\)\".*/\\1/p" "$REQUEST.processing" | head -n 1; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' '; }

STEPS=""
write_status() { # état, message
  printf '{"id":"%s","action":"%s","version":"%s","state":"%s","message":"%s","steps":[%s],"updatedAt":"%s"}\n' \
    "$ID" "$ACTION" "$VERSION" "$1" "$(json_escape "${2:-}")" "$STEPS" "$(now)" > "$STATUS.tmp" && mv "$STATUS.tmp" "$STATUS"
}
add_step() { # code, état
  [ -n "$STEPS" ] && STEPS="$STEPS,"
  STEPS="$STEPS{\"code\":\"$1\",\"state\":\"$2\",\"at\":\"$(now)\"}"
}
run_step() { # code, commande…
  code="$1"; shift
  write_status running ""
  echo "[updater] $code"
  if "$@" >> "$EXCHANGE/updater.log" 2>&1; then add_step "$code" "done"; return 0; fi
  add_step "$code" failed; return 1
}

wait_ready() {
  i=0
  while [ "$i" -lt 90 ]; do
    if compose exec -T web wget -q -O /dev/null http://127.0.0.1/system/instance 2>/dev/null; then return 0; fi
    i=$((i + 1)); sleep 4
  done
  return 1
}

set_version() {
  [ -z "$VERSION" ] && return 0
  if grep -q '^ERP_VERSION=' .env; then
    sed -i "s/^ERP_VERSION=.*/ERP_VERSION=$VERSION/" .env
  else
    echo "ERP_VERSION=$VERSION" >> .env
  fi
}

echo "[updater] prêt ($DIR)"
while true; do
  if [ -f "$REQUEST" ]; then
    mv "$REQUEST" "$REQUEST.processing"
    ID=$(field id); ACTION=$(field action); VERSION=$(field version)
    STEPS=""
    : > "$EXCHANGE/updater.log"
    case "$VERSION" in ''|latest|stable|[0-9]*.[0-9]*.[0-9]*) ;; *) VERSION="" ;; esac
    case "$ACTION" in
      update)
        PREVIOUS=$(sed -n 's/^ERP_VERSION=//p' .env | head -n 1)
        if run_step backup compose exec -T php php bin/console erpagile:backup --keep=30 \
          && run_step version set_version \
          && run_step pull compose pull php worker web \
          && run_step restart compose up -d --remove-orphans php worker web caddy \
          && run_step check wait_ready; then
          write_status "done" ""
        else
          # Retour à la version précédente des images ; la sauvegarde reste dans var/backups.
          if [ -n "$VERSION" ] && [ -n "$PREVIOUS" ]; then
            sed -i "s/^ERP_VERSION=.*/ERP_VERSION=$PREVIOUS/" .env
            compose up -d php worker web >> "$EXCHANGE/updater.log" 2>&1
          fi
          write_status failed "$(tail -n 5 "$EXCHANGE/updater.log")"
        fi
        ;;
      restart)
        if run_step restart compose restart php worker web && run_step check wait_ready; then
          write_status "done" ""
        else
          write_status failed "$(tail -n 5 "$EXCHANGE/updater.log")"
        fi
        ;;
      *)
        write_status failed "unknown action"
        ;;
    esac
    rm -f "$REQUEST.processing"
  fi
  sleep 5
done
