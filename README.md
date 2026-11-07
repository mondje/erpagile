# ERP Agile

Gestion commerciale, comptabilité, stock, RH et paie, caisse, hôtel, restaurant, point de vente, billetterie, pharmacie : une seule application pour toute la société, installée sur **votre** serveur.

Ce dépôt est le point de téléchargement d'ERP Agile : application de bureau, fichiers d'installation du serveur et notes de version. Le serveur lui-même est livré en images Docker prêtes à l'emploi (`ghcr.io/mondje/erpagile/php` et `ghcr.io/mondje/erpagile/web`) : rien n'est compilé chez vous.

**[⬇ Télécharger la dernière version](https://github.com/mondje/erpagile/releases/latest)**

---

## 1. Installer le serveur

Le serveur est l'ordinateur qui garde les données de la société : un PC du bureau allumé en permanence, une machine dans une salle serveur, ou un serveur loué sur Internet (VPS). Il lui faut Docker ; l'installation s'en occupe sous Linux.

### Sans aucune commande : l'application ERP Agile

1. Téléchargez l'application pour votre système dans la [dernière version](https://github.com/mondje/erpagile/releases/latest) :
   - Windows : `ERP.Agile_…_x64-setup.exe` (ou `.msi`) ;
   - macOS : `ERP.Agile_…_universal.dmg` ;
   - Linux : `.deb` (Ubuntu, Debian) ou `.AppImage`.
2. Ouvrez-la, puis **Installer ou gérer un serveur** :
   - **Sur ce poste** : l'application vérifie Docker (Docker Desktop sous Windows et macOS), vous demande si ERP Agile servira seulement au bureau ou aussi sur Internet, et installe tout ;
   - **Serveur distant (SSH)** : adresse du serveur, compte, mot de passe ou clé ; l'application y envoie les fichiers et installe ERP Agile pour vous.
3. Le journal défile pendant l'installation. À la fin, **Ouvrir ERP Agile**.

La même application sert ensuite à démarrer, arrêter, sauvegarder et mettre à jour le serveur.

### En une ligne, sur un serveur Linux

```sh
curl -fsSL https://raw.githubusercontent.com/mondje/erpagile/main/get.sh | sh
```

Le script pose deux questions (nom de domaine, email), propose d'installer Docker s'il manque, crée les mots de passe au hasard, télécharge les images et démarre ERP Agile. Sans question :

```sh
# accessible sur Internet, HTTPS automatique (le nom doit pointer vers ce serveur)
curl -fsSL https://raw.githubusercontent.com/mondje/erpagile/main/get.sh | sh -s -- --domain=erp.societe.ci --email=it@societe.ci --yes

# réseau du bureau seulement
curl -fsSL https://raw.githubusercontent.com/mondje/erpagile/main/get.sh | sh -s -- --local --yes
```

Vous préférez lire le script avant de le lancer ? Téléchargez `erpagile-deploy.zip` dans la [dernière version](https://github.com/mondje/erpagile/releases/latest), décompressez-le sur le serveur, puis `sh install.sh`.

### Nom de domaine ou réseau local ?

| | Nom de domaine (`erp.societe.ci`) | Réseau local seulement |
|---|---|---|
| Adresse | `https://erp.societe.ci` | `http://192.168.1.20` |
| Téléphones hors du bureau | oui | non |
| Caméra (codes-barres, billets) et application mobile | oui (HTTPS) | non : elles exigent HTTPS |
| Prérequis | le nom pointe vers le serveur, ports 80 et 443 ouverts | aucun |

## 2. Premier lancement

Ouvrez l'adresse affichée à la fin de l'installation : l'assistant crée le compte administrateur et la société, puis propose les modules à installer. Pour découvrir l'application, **Administration › Maintenance › Charger la société de démonstration** remplit une société fictive complète.

## 3. Relier les postes et les téléphones

Dans ERP Agile : **Administration › Connecter un appareil**. Un QR code s'affiche (un par utilisateur si vous le souhaitez, avec son email déjà rempli).

- **Téléphone :** l'appareil photo lit le QR code et ouvre ERP Agile ; menu du navigateur › « Ajouter à l'écran d'accueil » en fait une application, qui continue de marcher quand le réseau coupe (caisse, contrôle des billets…).
- **Poste de travail :** installez l'application ERP Agile ; au premier lancement, saisissez l'adresse du serveur ou scannez le QR code. Le navigateur fonctionne aussi, sans rien installer.

## 4. Entretenir le serveur

Tout se fait avec des boutons, dans **Administration › Maintenance** : mise à jour d'ERP Agile, sauvegarde (et téléchargement des sauvegardes), mise à niveau de la base, modules, démonstration. Chaque opération affiche son journal.

Sur le serveur, sans rien connaître de Docker :

```sh
cd /opt/erpagile        # dossier d'installation (ou ~/erpagile)
sh erpagile.sh          # menu
sh erpagile.sh update   # mise à jour
sh erpagile.sh backup   # sauvegarde
sh erpagile.sh url      # adresse et QR code
```

Une mise à jour remplace les programmes, jamais les données ; une sauvegarde est faite juste avant.

## Versions

Chaque [version](https://github.com/mondje/erpagile/releases) contient l'application de bureau (Windows, macOS, Linux) et `erpagile-deploy.zip`. Les serveurs installés suivent l'étiquette `stable` ; pour rester sur une version précise : `--version=1.0.0` à l'installation (`ERP_VERSION` dans le fichier `.env` ensuite).

---

## English

ERP Agile is a modular business suite (sales, accounting, inventory, HR and payroll, point of sale, hotel, restaurant, ticketing, pharmacy) installed on your own server. This repository hosts the downloads: desktop app, server installation files and release notes.

- **Desktop app** (Windows, macOS, Linux): from the [latest release](https://github.com/mondje/erpagile/releases/latest). Its *Install or manage a server* screen installs ERP Agile on the same computer (Docker) or on a remote Linux server over SSH, with no command line.
- **Linux server, one line:** `curl -fsSL https://raw.githubusercontent.com/mondje/erpagile/main/get.sh | sh` (add `-s -- --domain=erp.example.com --email=it@example.com --yes` to skip the questions).
- Then open the address shown, create the administrator and the company, and link phones and computers from **Administration › Connect a device** (QR code). Updates and backups: **Administration › Maintenance**, or `sh erpagile.sh` on the server.
