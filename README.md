# Dolibarr avec PostgreSQL Supabase - Configuration Docker

Cette configuration vous permet de déployer Dolibarr en production avec une base de données PostgreSQL hébergée sur Supabase.

## 🚀 Installation rapide

### 1. Prérequis

- Docker et Docker Compose installés
- Accès à une base de données PostgreSQL Supabase
- Port 8080 disponible (ou modifiez dans le .env)

### 2. Configuration

1. **Copiez les fichiers** dans votre répertoire de projet
2. **Configurez le fichier .env** avec vos paramètres :

```bash
# Modifiez ces valeurs obligatoirement :
DOLI_DB_PASSWORD=VOTRE_MOT_DE_PASSE_SUPABASE
DOLI_ADMIN_PASSWORD=MotDePasseTresFort123!
DOLI_URL_ROOT=https://votre-domaine.com
DOLI_COMPANY_NAME=Votre Société
```

3. **Lancez l'installation** :

```bash
chmod +x setup.sh
./setup.sh
```

## 🔧 Configuration manuelle

### Structure des fichiers

```
dolibarr/
├── docker-compose.yml
├── .env
├── setup.sh
├── README.md
└── data/
    ├── dolibarr_documents/
    └── dolibarr_custom/
```

### Variables d'environnement importantes

| Variable | Description | Exemple |
|----------|-------------|---------|
| `DOLI_DB_PASSWORD` | Mot de passe Supabase | `votre_password_supabase` |
| `DOLI_ADMIN_PASSWORD` | Mot de passe admin Dolibarr | `MotDePasseFort123!` |
| `DOLI_URL_ROOT` | URL de votre application | `https://erp.monsite.com` |
| `DOLI_INSTANCE_UNIQUE_ID` | Clé de chiffrement unique | `(générée automatiquement)` |
| `DOLI_COMPANY_NAME` | Nom de votre société | `Ma Société SARL` |

### Commandes Docker

```bash
# Démarrer les services
docker-compose up -d

# Voir les logs
docker-compose logs -f

# Arrêter les services
docker-compose down

# Redémarrer
docker-compose restart

# Mettre à jour Dolibarr
docker-compose pull
docker-compose up -d
```

## 🔒 Sécurité

### Configuration de production

1. **Changez tous les mots de passe par défaut**
2. **Configurez un reverse proxy** (Nginx, Traefik) avec SSL/TLS
3. **Limitez l'accès réseau** si possible
4. **Activez les sauvegardes automatiques**

### Reverse proxy avec Nginx

```nginx
server {
    listen 443 ssl;
    server_name votre-domaine.com;
    
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 📊 Gestion des données

### Sauvegardes

Les données importantes sont stockées dans :
- `./data/dolibarr_documents/` : Documents et fichiers
- `./data/dolibarr_custom/` : Modules personnalisés
- Base de données Supabase (sauvegardée automatiquement)

### Script de sauvegarde

```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf "backup_dolibarr_$DATE.tar.gz" data/
echo "Sauvegarde créée : backup_dolibarr_$DATE.tar.gz"
```

## 🔄 Mise à jour

### Procédure de mise à jour

1. **Sauvegardez vos données**
2. **Supprimez le fichier install.lock** :
   ```bash
   docker exec dolibarr_web rm -f /var/www/documents/install.lock
   ```
3. **Mettez à jour l'image** :
   ```bash
   docker-compose pull
   docker-compose up -d
   ```
4. **Suivez l'assistant de mise à jour** via l'interface web

## 🛠️ Dépannage

### Problèmes courants

**Erreur de connexion PostgreSQL :**
- Vérifiez vos paramètres Supabase dans le .env
- Vérifiez que votre IP est autorisée dans Supabase

**Permissions de fichiers :**
```bash
sudo chown -R 1000:1000 data/
chmod -R 755 data/
```

**Réinitialiser l'installation :**
```bash
docker exec dolibarr_web rm -f /var/www/documents/install.lock
docker-compose restart
```

### Logs utiles

```bash
# Logs du conteneur Dolibarr
docker-compose logs dolibarr

# Logs en temps réel
docker-compose logs -f

# Entrer dans le conteneur
docker exec -it dolibarr_web bash
```

## 📋 Fonctionnalités activées

- **Mode production** activé
- **Tâches cron** activées pour les automatisations
- **Support PostgreSQL** optimisé
- **Volumes persistants** pour les données
- **Configuration PHP** optimisée
- **Healthcheck** intégré

## 🌐 Modules Dolibarr

Modules activés par défaut (configurables dans .env) :
- `Societe` : Gestion des tiers
- `Facture` : Facturation
- `Stock` : Gestion des stocks

Modules disponibles :
- `Commande`, `Contrat`, `Projet`, `Comptabilite`, `HRM`, etc.

## 📞 Support

- [Documentation officielle Dolibarr](https://www.dolibarr.org/documentation)
- [Wiki Dolibarr](https://wiki.dolibarr.org/)
- [Forum communautaire](https://www.dolibarr.org/forum/)

## ⚖️ Licence

Cette configuration est fournie sous licence MIT. Dolibarr est distribué sous licence GPL v3.