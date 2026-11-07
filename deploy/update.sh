#!/bin/sh
# Mise à jour d'ERP Agile : sauvegarde, nouvelles images, redémarrage.
# Identique au bouton « Mettre à jour ERP Agile » de l'écran Maintenance.
exec sh "$(dirname "$0")/erpagile.sh" update
