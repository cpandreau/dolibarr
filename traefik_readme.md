# 🚀 Traefik + Dolibarr - Infrastructure Sécurisée

Une solution complète et sécurisée pour déployer Dolibarr ERP/CRM avec Traefik reverse proxy, SSL automatique et PostgreSQL Supabase.

## ✨ Fonctionnalités

### 🔒 Sécurité avancée
- **SSL/TLS automatique** avec Let's Encrypt
- **Headers de sécurité** complets (HSTS, CSP, XSS protection)
- **Rate limiting** intelligent
- **Authentification** renforcée pour l'administration
- **Firewall applicatif** avec Fail2Ban (optionnel)

### 🌐 Reverse proxy intelligent
- **Auto-découverte** des services Docker
- **Load balancing** automatique
- **Redirections HTTP → HTTPS** automatiques
- **Dashboard de monitoring** en temps réel

### 📊 Monitoring et maintenance
- **Healthchecks** automatiques
- **Mises à jour automatiques** avec Watchtower
- **Logs centralisés** et rotation
- **Métriques Prometheus** intégrées

## 🚀 Installation rapide

### 1. Prérequis

- **Serveur Linux** avec Docker et Docker Compose
- **Nom de domaine** avec contrôle DNS
- **Base de données PostgreSQL** Supabase
- **Ports 80 et 443** ouverts

### 2. Installation automatique

```bash
# Cloner ou télécharger les fichiers
chmod +x setup-traefik.sh
./setup-traefik.sh
```

Le script vous guidera interactivement pour :
- Configurer vos domaines
- Paramétrer Let's Encrypt
- Connecter à Supabase
- Générer toutes les clés de sécurité

### 3. Configuration DNS

Pointez vos domaines vers votre serveur :

```
traefik.votre-domaine.com  A  IP_DE_VOTRE_SERVEUR
erp.votre-domaine.com      A  IP_DE_VOTRE_SERVEUR
```

## 📁 Structure du projet

```
traefik-dolibarr/
├── docker-compose.integrated.yml    # Configuration principale
├── .env                            # Variables d'environnement
├── setup-traefik.sh               # Script d'installation
├── traefik-config/
│   └── dynamic.yml                # Configuration Traefik avancée
├── traefik-data/
│   └── letsencrypt/               # Certificats SSL
├── traefik-logs/                  # Logs Traefik
├── data/
│   ├── dolibarr_documents/        # Documents Dolibarr
│   └── dolibarr_custom/           # Modules personnalisés
├── backups/                       # Sauvegardes
└── fail2ban-data/                 # Configuration Fail2Ban
```

## ⚙️ Configuration avancée

### Variables d'environnement principales

| Variable | Description | Exemple |
|----------|-------------|---------|
| `TRAEFIK_DOMAIN` | Domaine dashboard Traefik | `traefik.monsite.com` |
| `DOLIBARR_DOMAIN` | Domaine Dolibarr | `erp.monsite.com` |
| `ACME_EMAIL` | Email Let's Encrypt | `admin@monsite.com` |
| `DOLI_DB_PASSWORD` | Mot de passe Supabase | `votre_password` |

### Middlewares de sécurité

#### Headers de sécurité
```yaml
security-headers:
  headers:
    frameDeny: true
    browserXssFilter: true
    contentTypeNosniff: true
    forceSTSHeader: true
    stsIncludeSubdomains: true
    stsPreload: true
    stsSeconds: 31536000
```

#### Rate limiting
```yaml
global-rate-limit:
  rateLimit:
    average: 100      # Requêtes par minute
    period: "1m"
    burst: 50         # Pic autorisé
```

#### Protection IP
```yaml
ip-whitelist:
  ipWhiteList:
    sourceRange:
      - "YOUR_IP/32"   # Votre IP fixe
      - "10.0.0.0/8"   # Réseau local
```

## 🛠️ Gestion quotidienne

### Commandes Docker Compose

```bash
# Démarrer tous les services
docker-compose -f docker-compose.integrated.yml up -d

# Voir les logs en temps réel
docker-compose -f docker-compose.integrated.yml logs -f

# Redémarrer un service
docker-compose -f docker-compose.integrated.yml restart dolibarr

# Arrêter tous les services
docker-compose -f docker-compose.integrated.yml down

# Voir le statut
docker-compose -f docker-compose.integrated.yml ps
```

### Gestion des certificats SSL

```bash
# Forcer le renouvellement
docker-compose exec traefik traefik version

# Voir les certificats
sudo ls -la traefik-data/letsencrypt/

# Logs des certificats
docker-compose logs traefik | grep -i acme
```

### Sauvegardes

```bash
# Sauvegarde manuelle
tar -czf "backup_$(date +%Y%m%d_%H%M%S).tar.gz" \
  data/ traefik-data/ .env

# Restauration
tar -xzf backup_file.tar.gz
docker-compose -f docker-compose.integrated.yml up -d
```

## 🔧 Dépannage

### Problèmes courants

#### 1. Certificats SSL non générés

**Symptômes :** Erreur "Certificate not found"

**Solutions :**
```bash
# Vérifier les logs ACME
docker-compose logs traefik | grep -i acme

# Vérifier la configuration DNS
nslookup votre-domaine.com

# Redémarrer Traefik
docker-compose restart traefik
```

#### 2. Service non accessible

**Vérifications :**
```bash
# Status des conteneurs
docker-compose ps

# Santé des services
docker-compose exec dolibarr curl -f http://localhost/

# Configuration Traefik
docker-compose exec traefik traefik config
```

#### 3. Problèmes de base de données

```bash
# Logs Dolibarr
docker-compose logs dolibarr | grep -i database

# Test connexion PostgreSQL
docker-compose exec dolibarr pg_isready -h $DOLI_DB_HOST
```

### Logs importants

```bash
# Logs Traefik (accès et erreurs)
tail -f traefik-logs/access.log
tail -f traefik-logs/traefik.log

# Logs applicatifs
docker-compose logs dolibarr
docker-compose logs traefik
```

## 🔒 Sécurisation avancée

### 1. Fail2Ban (protection DDoS)

Activez Fail2Ban pour bloquer automatiquement les IPs malveillantes :

```bash
# Démarrer avec Fail2Ban
docker-compose --profile security up -d
```

### 2. Restriction d'accès par IP

Modifiez `traefik-config/dynamic.yml` :

```yaml
middlewares:
  admin-ip-filter:
    ipWhiteList:
      sourceRange:
        - "VOTRE_IP/32"
```

### 3. Authentification à deux facteurs

Pour Dolibarr, activez 2FA dans :
`Configuration → Sécurité → Authentification à deux facteurs`

### 4. Monitoring de sécurité

```bash
# Surveillance des logs
tail -f traefik-logs/access.log | grep -E "(40[0-9]|50[0-9])"

# Statistiques d'accès
awk '{print $1}' traefik-logs/access.log | sort | uniq -c | sort -nr
```

## 📊 Monitoring et métriques

### Dashboard Traefik

Accédez à `https://traefik.votre-domaine.com` pour :
- État des services en temps réel
- Métriques de performance
- Configuration active
- Historique des certificats

### Métriques Prometheus

Endpoint disponible : `http://localhost:8080/metrics`

Exemples de métriques :
- `traefik_requests_total`
- `traefik_request_duration_seconds`
- `traefik_config_reloads_total`

### Alertes recommandées

```yaml
# Exemple d'alertes Prometheus
- alert: TraefikDown
  expr: up{job="traefik"} == 0
  for: 1m
  
- alert: HighErrorRate
  expr: rate(traefik_requests_total{code=~"5.."}[5m]) > 0.1
  for: 2m
```

## 🔄 Mises à jour

### Mise à jour automatique (Watchtower)

Watchtower met à jour automatiquement vos conteneurs :
- **Heure :** 2h du matin quotidiennement
- **Nettoyage :** Anciennes images supprimées
- **Notifications :** Logs disponibles

### Mise à jour manuelle

```bash
# Sauvegarde préventive
./backup.sh

# Téléchargement des nouvelles images
docker-compose -f docker-compose.integrated.yml pull

# Redémarrage avec nouvelles images
docker-compose -f docker-compose.integrated.yml up -d

# Vérification
docker-compose -f docker-compose.integrated.yml ps
```

## 🌐 Ajout de nouveaux services

### Exemple : Ajouter Nextcloud

```yaml
nextcloud:
  image: nextcloud:latest
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.nextcloud.rule=Host(`cloud.votre-domaine.com`)"
    - "traefik.http.routers.nextcloud.entrypoints=websecure"
    - "traefik.http.routers.nextcloud.tls.certresolver=letsencrypt"
    - "traefik.http.routers.nextcloud.middlewares=web-secure@file"
  networks:
    - traefik-network
```

### Bonnes pratiques

1. **Utilisez toujours les middlewares de sécurité**
2. **Activez HTTPS uniquement** (pas de HTTP)
3. **Configurez les healthchecks**
4. **Isolez avec des réseaux Docker**
5. **Documentez vos ajouts**

## 🆘 Support et ressources

### Documentation officielle
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Dolibarr Documentation](https://www.dolibarr.org/documentation)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

### Communauté
- [Forum Dolibarr](https://www.dolibarr.org/forum/)
- [Discord Traefik](https://discord.gg/traefik)
- [Reddit r/selfhosted](https://www.reddit.com/r/selfhosted/)

### Outils utiles
- [SSL Labs Test](https://www.ssllabs.com/ssltest/) - Test de sécurité SSL
- [Security Headers](https://securityheaders.com/) - Test des headers de sécurité
- [GTmetrix](https://gtmetrix.com/) - Performance web

## 📝 Changelog

### Version 1.0.0 (2025-06-07)
- Configuration initiale Traefik + Dolibarr
- SSL automatique Let's Encrypt
- Sécurité renforcée avec middlewares
- Support PostgreSQL Supabase
- Documentation complète

## ⚖️ Licence

Cette configuration est fournie sous licence MIT.
- Traefik : Licence MIT
- Dolibarr : Licence GPL v3+

---

## 🎉 Félicitations !

Vous avez maintenant une infrastructure web professionnelle, sécurisée et automatisée. 

**Profitez de votre Dolibarr avec Traefik ! 🚀**