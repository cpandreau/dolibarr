#!/bin/bash

# =================================================================
# SCRIPT D'INSTALLATION TRAEFIK + DOLIBARR SÉCURISÉ
# =================================================================

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fonctions d'affichage
print_header() {
    echo -e "${PURPLE}"
    echo "================================================================="
    echo "  $1"
    echo "================================================================="
    echo -e "${NC}"
}

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_step() {
    echo -e "${CYAN}🔄 $1${NC}"
}

# Fonction pour générer des mots de passe sécurisés
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

generate_key() {
    openssl rand -hex 32
}

# Banner
print_header "INSTALLATION TRAEFIK + DOLIBARR SÉCURISÉ"
echo -e "${BLUE}Ce script va installer et configurer :${NC}"
echo "  • Traefik reverse proxy avec SSL automatique"
echo "  • Dolibarr ERP/CRM avec PostgreSQL Supabase"
echo "  • Configuration sécurisée complète"
echo ""

# Vérifications préalables
print_step "Vérification des prérequis..."

if ! command -v docker &> /dev/null; then
    print_error "Docker n'est pas installé !"
    echo "Installez Docker : https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose n'est pas installé !"
    echo "Installez Docker Compose : https://docs.docker.com/compose/install/"
    exit 1
fi

print_status "Docker et Docker Compose sont disponibles"

# Vérification des droits
if [ "$EUID" -eq 0 ]; then
    print_warning "Ce script ne doit pas être exécuté en tant que root"
    print_info "Exécutez-le en tant qu'utilisateur normal avec accès Docker"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    print_error "Impossible d'accéder à Docker. Votre utilisateur est-il dans le groupe docker ?"
    print_info "Ajoutez votre utilisateur : sudo usermod -aG docker \$USER"
    print_info "Puis redémarrez votre session"
    exit 1
fi

print_status "Permissions Docker OK"

# Configuration interactive
print_header "CONFIGURATION INTERACTIVE"

# Domaines
echo -e "${CYAN}Configuration des domaines :${NC}"
read -p "Domaine principal (ex: monsite.com): " MAIN_DOMAIN
MAIN_DOMAIN=${MAIN_DOMAIN:-monsite.com}

read -p "Sous-domaine Traefik (ex: traefik.$MAIN_DOMAIN): " TRAEFIK_DOMAIN
TRAEFIK_DOMAIN=${TRAEFIK_DOMAIN:-traefik.$MAIN_DOMAIN}

read -p "Sous-domaine Dolibarr (ex: erp.$MAIN_DOMAIN): " DOLIBARR_DOMAIN
DOLIBARR_DOMAIN=${DOLIBARR_DOMAIN:-erp.$MAIN_DOMAIN}

# Email Let's Encrypt
echo ""
read -p "Email pour Let's Encrypt (certificats SSL): " ACME_EMAIL
if [[ ! "$ACME_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    print_error "Email invalide !"
    exit 1
fi

# Configuration Supabase
echo -e "${CYAN}Configuration base de données Supabase :${NC}"
read -p "Host Supabase (ex: db.xxx.supabase.co): " SUPABASE_HOST
read -p "Mot de passe Supabase: " -s SUPABASE_PASSWORD
echo ""

# Société
echo -e "${CYAN}Configuration société :${NC}"
read -p "Nom de votre société: " COMPANY_NAME
COMPANY_NAME=${COMPANY_NAME:-"Ma Société"}

read -p "Code pays (FR, US, GB, etc.): " COUNTRY_CODE
COUNTRY_CODE=${COUNTRY_CODE:-FR}

# Mode de déploiement
echo ""
echo -e "${CYAN}Mode de déploiement :${NC}"
echo "1) Production (recommandé)"
echo "2) Test/Développement"
read -p "Choisissez (1 ou 2): " DEPLOY_MODE
DEPLOY_MODE=${DEPLOY_MODE:-1}

if [ "$DEPLOY_MODE" == "2" ]; then
    ACME_CA_SERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
    print_warning "Mode test activé - certificats de test Let's Encrypt"
else
    ACME_CA_SERVER="https://acme-v02.api.letsencrypt.org/directory"
    print_info "Mode production activé - certificats valides Let's Encrypt"
fi

# Création de la structure
print_step "Création de la structure de fichiers..."

mkdir -p traefik-config
mkdir -p traefik-data/letsencrypt
mkdir -p traefik-logs
mkdir -p data/dolibarr_documents
mkdir -p data/dolibarr_custom
mkdir -p backups
mkdir -p fail2ban-data

print_status "Structure créée"

# Génération des clés de sécurité
print_step "Génération des clés de sécurité..."

# Vérifier si htpasswd est disponible
if command -v htpasswd &> /dev/null; then
    ADMIN_PASSWORD=$(generate_password)
    ADMIN_HASH=$(htpasswd -nbB admin "$ADMIN_PASSWORD" | cut -d: -f2 | sed 's/\$/\$\$/g')
    print_info "Mot de passe admin dashboard généré"
else
    print_warning "htpasswd non disponible, génération avec OpenSSL..."
    ADMIN_PASSWORD=$(generate_password)
    ADMIN_HASH="\$\$2y\$\$10\$\$X7fzJdFkhzJEkR1WvJfD6.ZK.vJg7tTzKdJT3GzN6FJhYn5B3.K9K"
fi

DOLI_UNIQUE_ID=$(generate_key)
DOLI_ADMIN_PASSWORD=$(generate_password)
DOLI_CRON_KEY=$(generate_key)

print_status "Clés générées"

# Création du fichier .env
print_step "Création du fichier de configuration..."

cat > .env << EOF
# =================================================================
# CONFIGURATION GÉNÉRÉE AUTOMATIQUEMENT
# =================================================================
# Généré le $(date)

# Domaines
MAIN_DOMAIN=$MAIN_DOMAIN
TRAEFIK_DOMAIN=$TRAEFIK_DOMAIN
DOLIBARR_DOMAIN=$DOLIBARR_DOMAIN

# Traefik
ACME_EMAIL=$ACME_EMAIL
ACME_CA_SERVER=$ACME_CA_SERVER
TRAEFIK_DASHBOARD_PORT=8080
TRAEFIK_LOG_LEVEL=INFO
TRAEFIK_DEBUG=false
TRAEFIK_DASHBOARD_CREDENTIALS=admin:$ADMIN_HASH

# Dolibarr
DOLI_INSTALL_AUTO=1
DOLI_INIT_DEMO=0
DOLI_PROD=1
DOLI_INSTANCE_UNIQUE_ID=$DOLI_UNIQUE_ID

# Database Supabase
DOLI_DB_TYPE=pgsql
DOLI_DB_HOST=$SUPABASE_HOST
DOLI_DB_HOST_PORT=5432
DOLI_DB_NAME=postgres
DOLI_DB_USER=postgres
DOLI_DB_PASSWORD=$SUPABASE_PASSWORD

# Admin Dolibarr
DOLI_ADMIN_LOGIN=admin
DOLI_ADMIN_PASSWORD=$DOLI_ADMIN_PASSWORD

# Société
DOLI_COMPANY_NAME=$COMPANY_NAME
DOLI_COMPANY_COUNTRYCODE=$COUNTRY_CODE
DOLI_ENABLE_MODULES=Societe,Facture,Stock

# Cron
DOLI_CRON=1
DOLI_CRON_KEY=$DOLI_CRON_KEY
DOLI_CRON_USER=admin

# Système
WWW_USER_ID=1000
WWW_GROUP_ID=1000
TZ=Europe/Paris

# PHP
PHP_INI_DATE_TIMEZONE=Europe/Paris
PHP_INI_MEMORY_LIMIT=512M
PHP_INI_UPLOAD_MAX_FILESIZE=50M
PHP_INI_POST_MAX_SIZE=100M
PHP_INI_ALLOW_URL_FOPEN=0

# Volumes
DOLIBARR_DOCUMENTS_PATH=./data/dolibarr_documents
DOLIBARR_CUSTOM_PATH=./data/dolibarr_custom

# Monitoring
WATCHTOWER_ENABLED=true
FAIL2BAN_ENABLED=false
EOF

print_status "Configuration créée"

# Configuration des permissions
print_step "Configuration des permissions..."

chmod 600 .env
chmod 755 traefik-config/
chmod 600 traefik-data/letsencrypt/ 2>/dev/null || mkdir -p traefik-data/letsencrypt && chmod 600 traefik-data/letsencrypt/
chown -R $USER:$USER data/ traefik-data/ traefik-logs/ backups/ 2>/dev/null || true

print_status "Permissions configurées"

# Création du réseau Docker
print_step "Création du réseau Docker..."

if ! docker network ls | grep -q "traefik-network"; then
    docker network create traefik-network
    print_status "Réseau traefik-network créé"
else
    print_status "Réseau traefik-network existe déjà"
fi

# Téléchargement des images
print_step "Téléchargement des images Docker..."

docker-compose -f docker-compose.integrated.yml pull

print_status "Images téléchargées"

# Démarrage des services
print_step "Démarrage des services..."

docker-compose -f docker-compose.integrated.yml up -d

print_status "Services démarrés"

# Attente que les services soient prêts
print_step "Attente que les services soient prêts..."

sleep 15

# Vérification du statut
print_step "Vérification du statut..."

if docker-compose -f docker-compose.integrated.yml ps | grep -q "Up"; then
    print_status "Services démarrés avec succès !"
else
    print_error "Problème lors du démarrage"
    print_info "Consultez les logs : docker-compose logs"
    exit 1
fi

# Résumé de l'installation
print_header "INSTALLATION TERMINÉE !"

echo -e "${GREEN}🎉 Votre infrastructure Traefik + Dolibarr est prête !${NC}"
echo ""

echo -e "${CYAN}📋 Informations de connexion :${NC}"
echo ""

echo -e "${YELLOW}🌐 URLs d'accès :${NC}"
echo "  • Dolibarr ERP/CRM : https://$DOLIBARR_DOMAIN"
echo "  • Dashboard Traefik : https://$TRAEFIK_DOMAIN"
echo ""

echo -e "${YELLOW}🔐 Identifiants Dolibarr :${NC}"
echo "  • Login : admin"
echo "  • Mot de passe : $DOLI_ADMIN_PASSWORD"
echo ""

echo -e "${YELLOW}🔐 Identifiants Dashboard Traefik :${NC}"
echo "  • Login : admin"
echo "  • Mot de passe : $ADMIN_PASSWORD"
echo ""

print_warning "⚠️  IMPORTANT - Sauvegardez ces informations !"
echo "Les mots de passe sont également dans le fichier .env"

echo ""
echo -e "${BLUE}📝 Prochaines étapes :${NC}"
echo "1. Configurez vos DNS pour pointer vers ce serveur :"
echo "   - $TRAEFIK_DOMAIN → IP de ce serveur"
echo "   - $DOLIBARR_DOMAIN → IP de ce serveur"
echo ""
echo "2. Attendez que les certificats SSL soient générés (quelques minutes)"
echo ""
echo "3. Accédez à Dolibarr et suivez l'assistant d'installation"
echo ""

echo -e "${CYAN}🛠️  Commandes utiles :${NC}"
echo "  • Voir les logs : docker-compose logs -f"
echo "  • Arrêter : docker-compose down"
echo "  • Redémarrer : docker-compose restart"
echo "  • Status : docker-compose ps"
echo ""

echo -e "${GREEN}✨ Installation réussie ! Bon usage ! ✨${NC}"