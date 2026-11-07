# Installer ERP Agile sur un serveur

Trois façons, de la plus simple à la plus manuelle :

1. **Application « ERP Agile Serveur »** (Windows, macOS, Linux) : un assistant installe ERP Agile sur ce poste, ou sur un serveur distant par SSH, sans aucune commande. Elle sert ensuite à démarrer, arrêter, sauvegarder et mettre à jour.
2. **Script** (serveur Linux) : copiez ce dossier sur le serveur, puis :
   ```sh
   sh install.sh
   ```
   Le script vérifie Docker (et propose de l'installer), pose deux questions (nom de domaine, email), crée les secrets, télécharge les images et démarre ERP Agile. Sans question : `sh install.sh --domain=erp.client.ci --email=it@client.ci --yes`.
3. **À la main** : `compose.yaml` et un `.env` (voir `install.sh` pour les variables).

Ensuite, ouvrez l'adresse affichée : l'assistant crée le compte administrateur et la société.

## Au quotidien

Tout se fait depuis l'ERP, menu **Administration › Maintenance** : mise à jour, sauvegarde (et téléchargement des sauvegardes), mise à niveau de la base, écrans des modules, démonstration.

Sur le serveur, le même entretien sans connaître Docker :

```sh
sh erpagile.sh            # menu
sh erpagile.sh update     # mise à jour
sh erpagile.sh backup     # sauvegarde
```

## Contenu

| Fichier | Rôle |
|---|---|
| `compose.yaml` | services : Caddy (HTTPS automatique avec un nom de domaine), interface, API, tâches de fond, PostgreSQL, Redis, conteneur de mise à jour |
| `install.sh` | installation guidée |
| `erpagile.sh` | entretien (menu ou commandes) |
| `update.sh` | mise à jour en une commande |
| `updater/updater.sh` | conteneur de mise à jour : exécute les demandes de l'écran Maintenance |

Données (volumes Docker) : base, fichiers déposés, clés, modules téléchargés, sauvegardes. Une mise à jour remplace les images, jamais les données.
