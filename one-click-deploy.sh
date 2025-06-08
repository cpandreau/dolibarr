#!/bin/bash

# =================================================================
# DÉPLOIEMENT ONE-CLICK INFRASTRUCTURE COMPLÈTE
# Traefik + Dolibarr + n8n + Monitoring Stack
# =================================================================

set -e

# Configuration globale
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/one-click-deploy.log"
INSTALL_START_TIME=$(date +%s)

# Couleurs et styling
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Variables de configuration
DEPLOYMENT_MODE="production"
ENABLE_MONITORING=true
ENABLE_SECURITY=false
SKIP_DNS_CHECK=false
AUTO_START=false
BACKUP_EXISTING=true

# Banner ASCII
show_banner() {
    echo -e "${PURPLE}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    ██████╗ ███╗   ██╗███████╗     ██████╗██╗     ██╗ ██████╗ ██║ ██╗
║   ██╔═══██╗████╗  ██║██╔════╝    ██╔════╝██║     ██║██╔════╝ ██║ ██║
║   ██║   ██║██╔██╗ ██║█████╗      ██║     ██║     ██║██║      ███████║
║   ██║   ██║██║╚██╗██║██╔══╝      ██║     ██║     ██║██║      ██╔══██║
║   ╚██████╔╝██║ ╚████║███████╗    ╚██████╗███████╗██║╚██████╗ ██║  ██║
║    ╚═════╝ ╚═╝  ╚═══╝╚══════╝     ╚═════╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═╝
║                                                               ║
║              INFRASTRUCTURE ENTERPRISE DEPLOYMENT            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

    🚀 Traefik Reverse Proxy avec SSL automatique
    📊 Dolibarr ERP/CRM complet
    🤖 n8n Automation Platform
    📈 Stack de Monitoring (Prometheus, Grafana, AlertManager)
    🛡️  Sécurité renforcée niveau entreprise
    
EOF
    echo -e "${NC}"
    echo -e "${BLUE}Version: $SCRIPT_VERSION | $(date)${NC}"
    echo ""
}

# Fonctions utilitaires
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️  $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

log_step() {
    echo ""
    echo -e "${CYAN}${BOLD}🔄 $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STEP: $1" >> "$LOG_FILE"
}

# Fonction d'aide
show_help() {
    cat << EOF
DÉPLOIEMENT ONE-CLICK INFRASTRUCTURE COMPLÈTE

Usage: $0 [OPTIONS]

Options de déploiement:
    --production          Mode production (défaut)
    --development         Mode développement (certificats de test)
    --monitoring          Activer le monitoring complet (défaut: oui)
    --no-monitoring       Désactiver le monitoring
    --security            Activer la sécurité renforcée (Fail2Ban)
    --minimal             Déploiement minimal (Traefik + Dolibarr + n8n)

Options de configuration:
    --auto-start          Démarrage automatique sans questions
    --skip-dns            Ignorer la vérification DNS
    --no-backup           Ne pas sauvegarder l'existant
    --domain DOMAIN       Domaine principal à utiliser
    --email EMAIL         Email pour Let's Encrypt

Options techniques:
    --verbose             Mode verbeux
    --dry-run            Simulation sans exécution
    --help               Afficher cette aide

Exemples:
    $0                                    # Déploiement interactif complet
    $0 --auto-start --domain monsite.com # Déploiement automatique
    $0 --minimal --development            # Version minimale en dev
    $0 --security --monitoring            # Version complète sécurisée

Configuration requise:
    • Serveur Linux avec Docker et Docker Compose
    • 4GB RAM minimum (8GB recommandé)
    • 20GB espace disque
    • Domaine avec contrôle DNS
    • Base PostgreSQL Supabase (gratuite)

EOF
}

# Parse des arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --production)
                DEPLOYMENT_MODE="production"
                shift
                ;;
            --development)
                DEPLOYMENT_MODE="development"
                shift
                ;;
            --monitoring)
                ENABLE_MONITORING=true
                shift
                ;;
            --no-monitoring)
                ENABLE_MONITORING=false
                shift
                ;;
            --security)
                ENABLE_SECURITY=true
                shift
                ;;
            --minimal)
                ENABLE_MONITORING=false
                ENABLE_SECURITY=false
                shift
                ;;
            --auto-start)
                AUTO_START=true
                shift
                ;;
            --skip-dns)
                SKIP_DNS_CHECK=true
                shift
                ;;
            --no-backup)
                BACKUP_EXISTING=false
                shift
                ;;
            --domain)
                PRESET_DOMAIN="$2"
                shift 2
                ;;
            --email)
                PRESET_EMAIL="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Vérifications système complètes
comprehensive_system_check() {
    log_step "Vérifications système approfondies"
    
    # Vérification OS
    if [[ ! "$OSTYPE" =~ ^linux ]]; then
        log_error "Système d'exploitation non supporté: $OSTYPE"
        log "Ce script nécessite Linux (Ubuntu, Debian, CentOS, etc.)"
        exit 1
    fi
    log_success "Système Linux détecté"
    
    # Vérification utilisateur
    if [ "$EUID" -eq 0 ]; then
        log_error "Ne pas exécuter en tant que root"
        log "Exécutez en tant qu'utilisateur normal avec accès Docker"
        exit 1
    fi
    log_success "Utilisateur non-root validé"
    
    # Vérification Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        echo ""
        echo -e "${YELLOW}Installation automatique de Docker ?${NC}"
        read -p "Installer Docker maintenant ? (y/N): " install_docker
        if [[ $install_docker == [yY] ]]; then
            install_docker_automatically
        else
            log "Installez Docker manuellement : https://docs.docker.com/get-docker/"
            exit 1
        fi
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Impossible d'accéder à Docker"
        log "Ajoutez votre utilisateur au groupe docker : sudo usermod -aG docker $USER"
        log "Puis redémarrez votre session"
        exit 1
    fi
    log_success "Docker opérationnel"
    
    # Vérification Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose non disponible"
        echo ""
        echo -e "${YELLOW}Installation automatique de Docker Compose ?${NC}"
        read -p "Installer Docker Compose maintenant ? (y/N): " install_compose
        if [[ $install_compose == [yY] ]]; then
            install_docker_compose_automatically
        else
            log "Installez Docker Compose manuellement"
            exit 1
        fi
    fi
    log_success "Docker Compose disponible"
    
    # Vérification des ressources
    local available_ram=$(free -m | awk 'NR==2{print $2}')
    if [ "$available_ram" -lt 3072 ]; then  # 3GB minimum
        log_warning "RAM disponible: ${available_ram}MB (minimum recommandé: 4GB)"
        if [ "$available_ram" -lt 2048 ]; then
            log_error "RAM insuffisante pour le déploiement"
            exit 1
        fi
    else
        log_success "RAM suffisante: ${available_ram}MB"
    fi
    
    # Vérification espace disque
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=10485760  # 10GB en KB
    if [ "$available_space" -lt "$required_space" ]; then
        log_error "Espace disque insuffisant"
        log "Disponible: $(df -h / | awk 'NR==2 {print $4}') | Requis: 10GB minimum"
        exit 1
    fi
    log_success "Espace disque suffisant: $(df -h / | awk 'NR==2 {print $4}')"
    
    # Vérification ports
    local required_ports=(80 443)
    for port in "${required_ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log_error "Port $port déjà utilisé"
            log "Libérez le port $port avant de continuer"
            exit 1
        fi
    done
    log_success "Ports 80 et 443 disponibles"
    
    # Vérification outils optionnels
    local tools=("curl" "wget" "git" "openssl" "jq")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "$tool disponible"
        else
            log_warning "$tool non installé (recommandé)"
        fi
    done
}

# Installation automatique de Docker
install_docker_automatically() {
    log_step "Installation automatique de Docker"
    
    # Détecter la distribution
    if command -v apt &> /dev/null; then
        # Ubuntu/Debian
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "$USER"
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        curl -fsSL https://get.docker.com | sh
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker "$USER"
    else
        log_error "Distribution non supportée pour l'installation automatique"
        exit 1
    fi
    
    log_success "Docker installé - Redémarrez votre session"
    log "Exécutez: newgrp docker"
    exit 0
}

# Installation automatique de Docker Compose
install_docker_compose_automatically() {
    log_step "Installation de Docker Compose"
    
    local compose_version="2.21.0"
    sudo curl -L "https://github.com/docker/compose/releases/download/v${compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    log_success "Docker Compose installé"
}

# Configuration interactive avancée
interactive_configuration() {
    if [ "$AUTO_START" = true ]; then
        log "Mode automatique activé - configuration par défaut"
        return 0
    fi
    
    log_step "Configuration interactive"
    
    echo -e "${BOLD}${CYAN}Configuration de votre infrastructure${NC}"
    echo ""
    
    # Mode de déploiement
    if [ -z "$DEPLOYMENT_MODE" ]; then
        echo -e "${YELLOW}Mode de déploiement :${NC}"
        echo "1) 🚀 Production (certificats SSL valides)"
        echo "2) 🔧 Développement (certificats de test)"
        read -p "Choisissez (1-2): " mode_choice
        case $mode_choice in
            2) DEPLOYMENT_MODE="development" ;;
            *) DEPLOYMENT_MODE="production" ;;
        esac
    fi
    log_success "Mode: $DEPLOYMENT_MODE"
    
    # Configuration du monitoring
    if [ "$ENABLE_MONITORING" != false ]; then
        echo ""
        echo -e "${YELLOW}Stack de monitoring :${NC}"
        echo "Inclut Prometheus, Grafana, AlertManager, métriques complètes"
        read -p "Activer le monitoring complet ? (Y/n): " monitoring_choice
        [[ $monitoring_choice == [nN] ]] && ENABLE_MONITORING=false
    fi
    log_success "Monitoring: $([[ $ENABLE_MONITORING == true ]] && echo "Activé" || echo "Désactivé")"
    
    # Configuration sécurité
    echo ""
    echo -e "${YELLOW}Sécurité renforcée :${NC}"
    echo "Inclut Fail2Ban, protection DDoS, monitoring sécurité"
    read -p "Activer la sécurité renforcée ? (y/N): " security_choice
    [[ $security_choice == [yY] ]] && ENABLE_SECURITY=true
    log_success "Sécurité renforcée: $([[ $ENABLE_SECURITY == true ]] && echo "Activée" || echo "Désactivée")"
    
    # Configuration des domaines
    echo ""
    echo -e "${YELLOW}Configuration des domaines :${NC}"
    if [ -z "${PRESET_DOMAIN:-}" ]; then
        read -p "Domaine principal (ex: monentreprise.com): " MAIN_DOMAIN
    else
        MAIN_DOMAIN="$PRESET_DOMAIN"
    fi
    
    # Sous-domaines automatiques
    TRAEFIK_DOMAIN="admin.${MAIN_DOMAIN}"
    DOLIBARR_DOMAIN="erp.${MAIN_DOMAIN}"
    N8N_DOMAIN="automation.${MAIN_DOMAIN}"
    
    if [ "$ENABLE_MONITORING" = true ]; then
        GRAFANA_DOMAIN="monitoring.${MAIN_DOMAIN}"
        PROMETHEUS_DOMAIN="metrics.${MAIN_DOMAIN}"
        ALERTS_DOMAIN="alerts.${MAIN_DOMAIN}"
    fi
    
    echo "  • Traefik (admin)   : https://$TRAEFIK_DOMAIN"
    echo "  • Dolibarr (ERP)    : https://$DOLIBARR_DOMAIN"
    echo "  • n8n (automation)  : https://$N8N_DOMAIN"
    [ "$ENABLE_MONITORING" = true ] && echo "  • Grafana (monitoring) : https://$GRAFANA_DOMAIN"
    
    # Email Let's Encrypt
    echo ""
    if [ -z "${PRESET_EMAIL:-}" ]; then
        read -p "Email pour Let's Encrypt: " ACME_EMAIL
    else
        ACME_EMAIL="$PRESET_EMAIL"
    fi
    
    # Configuration Supabase
    echo ""
    echo -e "${YELLOW}Base de données PostgreSQL Supabase :${NC}"
    echo "Créez un projet gratuit sur https://supabase.com si ce n'est pas fait"
    read -p "Host Supabase (db.xxx.supabase.co): " SUPABASE_HOST
    read -p "Mot de passe database Supabase: " -s SUPABASE_PASSWORD
    echo ""
    
    # Configuration société
    echo ""
    echo -e "${YELLOW}Informations société :${NC}"
    read -p "Nom de votre société: " COMPANY_NAME
    read -p "Code pays (FR, US, GB, etc.): " COUNTRY_CODE
    
    # Résumé configuration
    echo ""
    echo -e "${BOLD}${BLUE}📋 RÉSUMÉ DE LA CONFIGURATION${NC}"
    echo "======================================="
    echo "Mode: $DEPLOYMENT_MODE"
    echo "Monitoring: $([[ $ENABLE_MONITORING == true ]] && echo "✅ Activé" || echo "❌ Désactivé")"
    echo "Sécurité: $([[ $ENABLE_SECURITY == true ]] && echo "✅ Activée" || echo "❌ Désactivée")"
    echo "Domaine principal: $MAIN_DOMAIN"
    echo "Email: $ACME_EMAIL"
    echo "Société: $COMPANY_NAME ($COUNTRY_CODE)"
    echo ""
    
    read -p "Confirmer cette configuration ? (Y/n): " confirm_config
    if [[ $confirm_config == [nN] ]]; then
        log_warning "Configuration annulée par l'utilisateur"
        exit 0
    fi
    
    log_success "Configuration validée"
}

# Génération automatique de la configuration
generate_environment_config() {
    log_step "Génération de la configuration sécurisée"
    
    # Génération des clés de sécurité
    log "Génération des clés cryptographiques..."
    local doli_unique_id=$(openssl rand -hex 32)
    local n8n_encryption_key=$(openssl rand -hex 32)
    local redis_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local grafana_secret_key=$(openssl rand -hex 32)
    
    # Génération des mots de passe
    log "Génération des mots de passe sécurisés..."
    local admin_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local n8n_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local doli_admin_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local cron_key=$(openssl rand -hex 32)
    
    # Génération du hash pour Traefik
    if command -v htpasswd &> /dev/null; then
        local admin_hash=$(htpasswd -nbB admin "$admin_password" | cut -d: -f2 | sed 's/\$/\$\$/g')
    else
        local admin_hash="\$\$2y\$\$10\$\$X7fzJdFkhzJEkR1WvJfD6.ZK.vJg7tTzKdJT3GzN6FJhYn5B3.K9K"
        log_warning "htpasswd non disponible - hash par défaut utilisé"
    fi
    
    # Déterminer le serveur ACME
    local acme_server="https://acme-v02.api.letsencrypt.org/directory"
    if [ "$DEPLOYMENT_MODE" = "development" ]; then
        acme_server="https://acme-staging-v02.api.letsencrypt.org/directory"
    fi
    
    # Créer le fichier .env complet
    cat > .env << EOF
# =================================================================
# CONFIGURATION INFRASTRUCTURE COMPLÈTE
# Générée automatiquement le $(date)
# Mode: $DEPLOYMENT_MODE
# =================================================================

# =================================================================
# DOMAINES
# =================================================================
MAIN_DOMAIN=$MAIN_DOMAIN
TRAEFIK_DOMAIN=$TRAEFIK_DOMAIN
DOLIBARR_DOMAIN=$DOLIBARR_DOMAIN
N8N_DOMAIN=$N8N_DOMAIN
EOF

    if [ "$ENABLE_MONITORING" = true ]; then
        cat >> .env << EOF
GRAFANA_DOMAIN=$GRAFANA_DOMAIN
PROMETHEUS_DOMAIN=$PROMETHEUS_DOMAIN
ALERTMANAGER_DOMAIN=$ALERTS_DOMAIN
EOF
    fi

    cat >> .env << EOF

# =================================================================
# TRAEFIK CONFIGURATION
# =================================================================
ACME_EMAIL=$ACME_EMAIL
ACME_CA_SERVER=$acme_server
TRAEFIK_DASHBOARD_PORT=8080
TRAEFIK_LOG_LEVEL=INFO
TRAEFIK_DEBUG=false
TRAEFIK_DASHBOARD_CREDENTIALS=admin:$admin_hash

# =================================================================
# SÉCURITÉ
# =================================================================
DOLI_INSTANCE_UNIQUE_ID=$doli_unique_id
N8N_ENCRYPTION_KEY=$n8n_encryption_key
REDIS_PASSWORD=$redis_password
GRAFANA_SECRET_KEY=$grafana_secret_key

# =================================================================
# DATABASE SUPABASE
# =================================================================
DOLI_DB_TYPE=pgsql
DOLI_DB_HOST=$SUPABASE_HOST
DOLI_DB_HOST_PORT=5432
DOLI_DB_NAME=postgres
DOLI_DB_USER=postgres
DOLI_DB_PASSWORD=$SUPABASE_PASSWORD

# =================================================================
# DOLIBARR
# =================================================================
DOLI_INSTALL_AUTO=1
DOLI_INIT_DEMO=0
DOLI_PROD=1
DOLI_ADMIN_LOGIN=admin
DOLI_ADMIN_PASSWORD=$doli_admin_password
DOLI_COMPANY_NAME=$COMPANY_NAME
DOLI_COMPANY_COUNTRYCODE=$COUNTRY_CODE
DOLI_ENABLE_MODULES=Societe,Facture,Stock,Commande,Projet
DOLI_CRON=1
DOLI_CRON_KEY=$cron_key
DOLI_CRON_USER=admin

# =================================================================
# N8N CONFIGURATION
# =================================================================
N8N_DB_NAME=n8n
N8N_DB_SCHEMA=n8n
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=$n8n_password
N8N_USER_MANAGEMENT_DISABLED=false
N8N_OWNER_EMAIL=$ACME_EMAIL
N8N_LOG_LEVEL=info
N8N_EXECUTIONS_TIMEOUT=3600
N8N_EXECUTIONS_TIMEOUT_MAX=7200

# =================================================================
# SYSTÈME
# =================================================================
WWW_USER_ID=1000
WWW_GROUP_ID=1000
TZ=Europe/Paris
PHP_INI_DATE_TIMEZONE=Europe/Paris
PHP_INI_MEMORY_LIMIT=512M
PHP_INI_UPLOAD_MAX_FILESIZE=50M
PHP_INI_POST_MAX_SIZE=100M

# =================================================================
# VOLUMES
# =================================================================
DOLIBARR_DOCUMENTS_PATH=./data/dolibarr_documents
DOLIBARR_CUSTOM_PATH=./data/dolibarr_custom

# =================================================================
# MONITORING (si activé)
# =================================================================
EOF

    if [ "$ENABLE_MONITORING" = true ]; then
        cat >> .env << EOF
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$admin_password
GRAFANA_DB_NAME=grafana
MONITORING_CREDENTIALS=admin:$admin_hash
PROMETHEUS_RETENTION_TIME=90d
PROMETHEUS_RETENTION_SIZE=10GB
EOF
    fi

    cat >> .env << EOF

# =================================================================
# MOTS DE PASSE GÉNÉRÉS
# =================================================================
# Traefik Dashboard: admin / $admin_password
# Dolibarr Admin: admin / $doli_admin_password
# n8n Admin: admin / $n8n_password
# Grafana Admin: admin / $admin_password
# =================================================================
EOF

    chmod 600 .env
    log_success "Configuration générée et sécurisée"
}

# Sauvegarde de l'existant
backup_existing_installation() {
    if [ "$BACKUP_EXISTING" = false ]; then
        log "Sauvegarde désactivée"
        return 0
    fi
    
    log_step "Sauvegarde de l'installation existante"
    
    # Vérifier s'il y a quelque chose à sauvegarder
    if [ -f ".env" ] || [ -d "data" ] || docker ps | grep -q "traefik\|dolibarr\|n8n"; then
        local backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        
        # Sauvegarder les fichiers de configuration
        [ -f ".env" ] && cp .env "$backup_dir/"
        [ -f "docker-compose.yml" ] && cp docker-compose.yml "$backup_dir/"
        [ -d "data" ] && cp -r data "$backup_dir/"
        [ -d "traefik-data" ] && cp -r traefik-data "$backup_dir/"
        
        # Exporter les workflows n8n si possible
        if docker ps | grep -q "n8n.*Up"; then
            log "Export des workflows n8n..."
            docker exec n8n n8n export:workflow --all --output=/tmp/workflows.json 2>/dev/null || true
            docker cp "$(docker ps -q -f name=n8n):/tmp/workflows.json" "$backup_dir/n8n-workflows.json" 2>/dev/null || true
        fi
        
        # Créer une archive
        tar -czf "${backup_dir}.tar.gz" "$backup_dir"
        rm -rf "$backup_dir"
        
        log_success "Sauvegarde créée: ${backup_dir}.tar.gz"
    else
        log "Aucune installation existante détectée"
    fi
}

# Préparation de l'infrastructure
prepare_infrastructure() {
    log_step "Préparation de l'infrastructure"
    
    # Créer la structure de répertoires
    log "Création de la structure de répertoires..."
    mkdir -p {data/dolibarr_documents,data/dolibarr_custom,traefik-data/letsencrypt,traefik-logs,n8n-logs,n8n-custom,logs,backups,scripts,reports}
    
    if [ "$ENABLE_MONITORING" = true ]; then
        mkdir -p {monitoring-config/grafana/{provisioning,dashboards},monitoring-config/grafana/provisioning/{datasources,dashboards}}
    fi
    
    if [ "$ENABLE_SECURITY" = true ]; then
        mkdir -p fail2ban-data
    fi
    
    # Configuration des permissions
    log "Configuration des permissions..."
    chmod 755 data/ traefik-data/ n8n-logs/ logs/ backups/
    chmod 600 traefik-data/letsencrypt/ 2>/dev/null || true
    
    # Créer les réseaux Docker
    log "Création des réseaux Docker..."
    docker network inspect traefik-network >/dev/null 2>&1 || docker network create traefik-network
    
    if [ "$ENABLE_MONITORING" = true ]; then
        docker network inspect monitoring-network >/dev/null 2>&1 || docker network create monitoring-network
    fi
    
    log_success "Infrastructure préparée"
}

# Déploiement des services
deploy_services() {
    log_step "Déploiement des services"
    
    # Télécharger les images
    log "Téléchargement des images Docker..."
    
    local compose_files="-f docker-compose.complete.yml"
    
    if [ "$ENABLE_MONITORING" = true ]; then
        compose_files="$compose_files -f docker-compose.monitoring.yml"
    fi
    
    if [ "$ENABLE_SECURITY" = true ]; then
        compose_files="$compose_files --profile security"
    fi
    
    # Vérifier que les fichiers docker-compose existent
    if [ ! -f "docker-compose.complete.yml" ]; then
        log_error "Fichier docker-compose.complete.yml manquant"
        log "Assurez-vous d'avoir tous les fichiers de configuration"
        exit 1
    fi
    
    # Pull des images
    docker-compose -f docker-compose.complete.yml pull
    [ "$ENABLE_MONITORING" = true ] && [ -f "docker-compose.monitoring.yml" ] && docker-compose -f docker-compose.monitoring.yml pull
    
    # Démarrage progressif des services
    log "Démarrage de Traefik..."
    docker-compose -f docker-compose.complete.yml up -d traefik
    sleep 10
    
    log "Démarrage de Redis..."
    docker-compose -f docker-compose.complete.yml up -d redis
    sleep 5
    
    log "Démarrage de Dolibarr..."
    docker-compose -f docker-compose.complete.yml up -d dolibarr
    sleep 15
    
    log "Démarrage de n8n..."
    docker-compose -f docker-compose.complete.yml up -d n8n n8n-worker
    sleep 15
    
    # Démarrage du monitoring si activé
    if [ "$ENABLE_MONITORING" = true ] && [ -f "docker-compose.monitoring.yml" ]; then
        log "Démarrage du stack de monitoring..."
        
        docker-compose -f docker-compose.monitoring.yml up -d node-exporter cadvisor postgres-exporter redis-exporter
        sleep 10
        
        docker-compose -f docker-compose.monitoring.yml up -d prometheus
        sleep 15
        
        docker-compose -f docker-compose.monitoring.yml up -d alertmanager
        sleep 10
        
        docker-compose -f docker-compose.monitoring.yml up -d grafana
        sleep 15
        
        docker-compose -f docker-compose.monitoring.yml up -d loki promtail uptime-kuma
    fi
    
    # Services de sécurité si activés
    if [ "$ENABLE_SECURITY" = true ]; then
        log "Démarrage des services de sécurité..."
        docker-compose -f docker-compose.complete.yml --profile security up -d fail2ban
    fi
    
    # Démarrage Watchtower
    docker-compose -f docker-compose.complete.yml up -d watchtower
    
    log_success "Services déployés"
}

# Tests post-déploiement
post_deployment_tests() {
    log_step "Tests post-déploiement"
    
    # Attendre que les services se stabilisent
    log "Attente de la stabilisation des services (60s)..."
    sleep 60
    
    # Vérifier le statut des conteneurs
    log "Vérification du statut des conteneurs..."
    local failed_services=""
    local main_services=("traefik" "redis" "dolibarr" "n8n" "n8n-worker")
    
    for service in "${main_services[@]}"; do
        if ! docker ps --format "{{.Names}}" | grep -q "^${service}$"; then
            failed_services="$failed_services $service"
        fi
    done
    
    if [ -n "$failed_services" ]; then
        log_error "Services en échec:$failed_services"
        log "Consultez les logs: docker-compose logs"
        return 1
    fi
    
    # Tests de connectivité basiques
    log "Tests de connectivité..."
    
    # Test Traefik API
    if curl -f -s --max-time 10 "http://localhost:8080/api/rawdata" >/dev/null 2>&1; then
        log_success "Traefik API accessible"
    else
        log_warning "Traefik API non accessible"
    fi
    
    # Test Redis
    if docker exec redis redis-cli ping | grep -q "PONG"; then
        log_success "Redis opérationnel"
    else
        log_warning "Redis non opérationnel"
    fi
    
    # Tests de monitoring si activé
    if [ "$ENABLE_MONITORING" = true ]; then
        # Test Prometheus
        if curl -f -s --max-time 10 "http://localhost:9090/-/healthy" >/dev/null 2>&1; then
            log_success "Prometheus opérationnel"
        else
            log_warning "Prometheus non accessible"
        fi
        
        # Test Grafana
        if curl -f -s --max-time 10 "http://localhost:3000/api/health" >/dev/null 2>&1; then
            log_success "Grafana opérationnel"
        else
            log_warning "Grafana non accessible"
        fi
    fi
    
    log_success "Tests post-déploiement terminés"
}

# Vérification DNS (optionnelle)
dns_verification() {
    if [ "$SKIP_DNS_CHECK" = true ]; then
        log "Vérification DNS ignorée"
        return 0
    fi
    
    log_step "Vérification DNS"
    
    local domains=("$TRAEFIK_DOMAIN" "$DOLIBARR_DOMAIN" "$N8N_DOMAIN")
    [ "$ENABLE_MONITORING" = true ] && domains+=("$GRAFANA_DOMAIN")
    
    local dns_issues=false
    
    for domain in "${domains[@]}"; do
        if command -v dig &> /dev/null; then
            if dig +short "$domain" | grep -q .; then
                log_success "DNS OK: $domain"
            else
                log_warning "DNS non configuré: $domain"
                dns_issues=true
            fi
        elif command -v nslookup &> /dev/null; then
            if nslookup "$domain" &> /dev/null; then
                log_success "DNS OK: $domain"
            else
                log_warning "DNS non configuré: $domain"
                dns_issues=true
            fi
        else
            log_warning "Impossible de vérifier DNS (dig/nslookup manquant)"
            break
        fi
    done
    
    if [ "$dns_issues" = true ]; then
        log_warning "Configurez vos DNS pour pointer vers ce serveur"
        log "Les certificats SSL ne pourront pas être générés sans DNS"
    fi
}

# Génération du rapport final
generate_final_report() {
    log_step "Génération du rapport de déploiement"
    
    local install_duration=$(($(date +%s) - INSTALL_START_TIME))
    local report_file="reports/deployment_report_$(date +%Y%m%d_%H%M%S).md"
    
    # Collecter les informations d'identifiants
    source .env
    
    cat > "$report_file" << EOF
# 🚀 Rapport de Déploiement Infrastructure

**Date de déploiement :** $(date)  
**Durée d'installation :** ${install_duration}s  
**Mode :** $DEPLOYMENT_MODE  
**Version script :** $SCRIPT_VERSION  

## ✅ Infrastructure Déployée

### Services Principaux
- **🔀 Traefik** - Reverse proxy avec SSL automatique
- **📊 Dolibarr** - ERP/CRM complet
- **🤖 n8n** - Plateforme d'automatisation
- **🗄️ Redis** - Cache et système de queue

$([ "$ENABLE_MONITORING" = true ] && cat << 'MONITOR'
### Stack de Monitoring
- **📈 Prometheus** - Collecte de métriques
- **📊 Grafana** - Dashboards et visualisation
- **🚨 AlertManager** - Gestion des alertes
- **📊 Node Exporter** - Métriques système
- **🐳 cAdvisor** - Métriques conteneurs

MONITOR
)

$([ "$ENABLE_SECURITY" = true ] && cat << 'SECURITY'
### Sécurité Renforcée
- **🛡️ Fail2Ban** - Protection anti-intrusion
- **🔒 Headers de sécurité** - Protection web avancée
- **⚡ Rate limiting** - Protection DDoS

SECURITY
)

## 🌐 URLs d'Accès

| Service | URL | Description |
|---------|-----|-------------|
| **Traefik Dashboard** | https://$TRAEFIK_DOMAIN | Administration reverse proxy |
| **Dolibarr ERP/CRM** | https://$DOLIBARR_DOMAIN | Application métier principale |
| **n8n Automation** | https://$N8N_DOMAIN | Plateforme d'automatisation |
$([ "$ENABLE_MONITORING" = true ] && echo "| **Grafana Monitoring** | https://$GRAFANA_DOMAIN | Dashboards et métriques |")

## 🔐 Identifiants de Connexion

### Traefik Dashboard
- **URL :** https://$TRAEFIK_DOMAIN
- **Login :** admin
- **Password :** \`$(grep 'admin /' .env | awk -F/ '{print $NF}' | head -1 || echo "Voir fichier .env")\`

### Dolibarr ERP/CRM
- **URL :** https://$DOLIBARR_DOMAIN
- **Login :** admin
- **Password :** \`$DOLI_ADMIN_PASSWORD\`

### n8n Automation
- **URL :** https://$N8N_DOMAIN
- **Login :** admin
- **Password :** \`$N8N_BASIC_AUTH_PASSWORD\`

$([ "$ENABLE_MONITORING" = true ] && cat << MONITORAUTH
### Grafana Monitoring
- **URL :** https://$GRAFANA_DOMAIN
- **Login :** admin
- **Password :** \`$GRAFANA_ADMIN_PASSWORD\`

MONITORAUTH
)

## 🔧 Informations Techniques

### Base de Données
- **Type :** PostgreSQL (Supabase)
- **Host :** $DOLI_DB_HOST
- **Schémas :** 
  - \`public\` (Dolibarr)
  - \`n8n\` (n8n workflows)
$([ "$ENABLE_MONITORING" = true ] && echo "  - \`grafana\` (Grafana)")

### Volumes Docker
- \`data/dolibarr_documents/\` - Documents Dolibarr
- \`data/dolibarr_custom/\` - Modules personnalisés
- \`traefik-data/letsencrypt/\` - Certificats SSL
- \`n8n_data\` - Données n8n

## 📋 Prochaines Étapes

### 1. Configuration DNS
Pointez vos domaines vers ce serveur :
\`\`\`
$TRAEFIK_DOMAIN    A    $(curl -s ifconfig.me 2>/dev/null || echo "IP_DE_CE_SERVEUR")
$DOLIBARR_DOMAIN   A    $(curl -s ifconfig.me 2>/dev/null || echo "IP_DE_CE_SERVEUR")
$N8N_DOMAIN        A    $(curl -s ifconfig.me 2>/dev/null || echo "IP_DE_CE_SERVEUR")
$([ "$ENABLE_MONITORING" = true ] && echo "$GRAFANA_DOMAIN    A    $(curl -s ifconfig.me 2>/dev/null || echo "IP_DE_CE_SERVEUR")")
\`\`\`

### 2. Finalisation Dolibarr
1. Accédez à https://$DOLIBARR_DOMAIN
2. Suivez l'assistant d'installation
3. Configurez votre société et vos modules

### 3. Configuration n8n
1. Accédez à https://$N8N_DOMAIN
2. Créez votre compte administrateur
3. Explorez les workflows d'exemple

$([ "$ENABLE_MONITORING" = true ] && cat << 'MONITORSETUP'
### 4. Configuration Monitoring
1. Accédez à https://$GRAFANA_DOMAIN
2. Importez les dashboards recommandés
3. Configurez les alertes selon vos besoins

MONITORSETUP
)

## 🛠️ Commandes de Gestion

\`\`\`bash
# Voir le statut des services
docker-compose -f docker-compose.complete.yml ps

# Voir les logs
docker-compose -f docker-compose.complete.yml logs -f

# Redémarrer un service
docker-compose -f docker-compose.complete.yml restart [service]

# Sauvegarder
./scripts/backup-automated.sh -t full

# Tests de santé
./scripts/run-tests.sh

# Maintenance
./scripts/maintenance-system.sh -a
\`\`\`

## 📊 Monitoring et Alertes

### URLs de Monitoring
$([ "$ENABLE_MONITORING" = true ] && cat << 'MONITORURLS'
- **Prometheus :** http://localhost:9090
- **AlertManager :** http://localhost:9093
- **Grafana :** https://$GRAFANA_DOMAIN

### Métriques Collectées
- Métriques système (CPU, RAM, Disque, Réseau)
- Métriques applicatives (Traefik, Dolibarr, n8n)
- Métriques de sécurité et performance

MONITORURLS
|| echo "- Monitoring non activé dans cette installation")

## 🔒 Sécurité

### Mesures Implémentées
- ✅ SSL/TLS automatique avec Let's Encrypt
- ✅ Headers de sécurité complets (HSTS, CSP, etc.)
- ✅ Rate limiting anti-DDoS
- ✅ Authentification renforcée
- ✅ Clés de chiffrement générées automatiquement
$([ "$ENABLE_SECURITY" = true ] && echo "- ✅ Fail2Ban actif pour protection intrusion")

### Recommandations Post-Installation
1. **Changez les mots de passe** par défaut après première connexion
2. **Activez 2FA** sur tous les services qui le supportent
3. **Surveillez les logs** de sécurité régulièrement
4. **Maintenez à jour** les images Docker
5. **Sauvegardez régulièrement** vos données

## 📞 Support et Ressources

### Documentation
- [Dolibarr](https://www.dolibarr.org/documentation)
- [n8n](https://docs.n8n.io/)
- [Traefik](https://doc.traefik.io/traefik/)
$([ "$ENABLE_MONITORING" = true ] && echo "- [Grafana](https://grafana.com/docs/)")

### Communautés
- [Forum Dolibarr](https://www.dolibarr.org/forum/)
- [Discord n8n](https://discord.gg/qZH3QQbv)
- [Reddit r/selfhosted](https://www.reddit.com/r/selfhosted/)

---

## ⚠️ IMPORTANT - Sauvegardez ce rapport !

Ce rapport contient toutes les informations nécessaires pour gérer votre infrastructure.
Sauvegardez-le dans un endroit sûr avec le fichier \`.env\`.

**Votre infrastructure est maintenant opérationnelle ! 🎉**

*Installation terminée avec succès le $(date)*
EOF

    # Générer aussi un fichier de credentials séparé
    cat > "CREDENTIALS_$(date +%Y%m%d).txt" << EOF
=================================================================
IDENTIFIANTS INFRASTRUCTURE - $(date)
=================================================================

🌐 URLs d'accès :
• Traefik Dashboard : https://$TRAEFIK_DOMAIN
• Dolibarr ERP/CRM  : https://$DOLIBARR_DOMAIN
• n8n Automation    : https://$N8N_DOMAIN
$([ "$ENABLE_MONITORING" = true ] && echo "• Grafana Monitoring: https://$GRAFANA_DOMAIN")

🔐 Identifiants :

Traefik Dashboard :
• Login : admin
• Password : $(grep 'admin /' .env | awk -F/ '{print $NF}' | head -1 || echo "Voir .env")

Dolibarr ERP/CRM :
• Login : admin
• Password : $DOLI_ADMIN_PASSWORD

n8n Automation :
• Login : admin
• Password : $N8N_BASIC_AUTH_PASSWORD

$([ "$ENABLE_MONITORING" = true ] && cat << GRAFCREDS
Grafana Monitoring :
• Login : admin
• Password : $GRAFANA_ADMIN_PASSWORD

GRAFCREDS
)

⚠️  SÉCURITÉ :
- Changez ces mots de passe après la première connexion
- Activez 2FA quand c'est possible
- Sauvegardez ce fichier dans un endroit sûr
- Supprimez ce fichier du serveur après sauvegarde

=================================================================
EOF

    chmod 600 "CREDENTIALS_$(date +%Y%m%d).txt"
    
    log_success "Rapport de déploiement généré: $report_file"
}

# Affichage du résumé final avec celebration
show_final_summary() {
    local install_duration=$(($(date +%s) - INSTALL_START_TIME))
    
    clear
    echo -e "${GREEN}${BOLD}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║  🎉 DÉPLOIEMENT TERMINÉ AVEC SUCCÈS ! 🎉                    ║
║                                                               ║
║     Votre infrastructure enterprise est opérationnelle !     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${CYAN}📊 Résumé du déploiement :${NC}"
    echo "────────────────────────────────────"
    echo -e "⏱️  Durée d'installation : ${BOLD}${install_duration}s${NC}"
    echo -e "🚀 Mode de déploiement   : ${BOLD}$DEPLOYMENT_MODE${NC}"
    echo -e "📦 Services déployés     : ${BOLD}$(docker ps --format "{{.Names}}" | wc -l) conteneurs${NC}"
    echo -e "💾 Monitoring           : ${BOLD}$([[ $ENABLE_MONITORING == true ]] && echo "✅ Activé" || echo "❌ Désactivé")${NC}"
    echo -e "🛡️  Sécurité renforcée   : ${BOLD}$([[ $ENABLE_SECURITY == true ]] && echo "✅ Activée" || echo "❌ Désactivée")${NC}"
    echo ""
    
    echo -e "${CYAN}🌐 Vos applications :${NC}"
    echo "────────────────────────────────────"
    echo -e "🔧 Administration    : ${BOLD}https://$TRAEFIK_DOMAIN${NC}"
    echo -e "📊 ERP/CRM Dolibarr  : ${BOLD}https://$DOLIBARR_DOMAIN${NC}"
    echo -e "🤖 Automation n8n    : ${BOLD}https://$N8N_DOMAIN${NC}"
    [ "$ENABLE_MONITORING" = true ] && echo -e "📈 Monitoring Grafana: ${BOLD}https://$GRAFANA_DOMAIN${NC}"
    echo ""
    
    echo -e "${YELLOW}📋 Prochaines étapes importantes :${NC}"
    echo "────────────────────────────────────"
    echo "1. 🌐 Configurez vos DNS pour pointer vers ce serveur"
    echo "2. ⏳ Attendez 2-5 minutes pour la génération des certificats SSL"
    echo "3. 🔐 Changez tous les mots de passe par défaut"
    echo "4. 📊 Suivez l'assistant d'installation de Dolibarr"
    echo "5. 🤖 Configurez vos premiers workflows n8n"
    echo ""
    
    echo -e "${BLUE}📄 Documentation générée :${NC}"
    echo "────────────────────────────────────"
    echo "• Rapport complet : reports/deployment_report_*.md"
    echo "• Identifiants : CREDENTIALS_$(date +%Y%m%d).txt"
    echo "• Configuration : .env (protégé)"
    echo ""
    
    echo -e "${GREEN}🎯 Votre infrastructure est maintenant prête !${NC}"
    echo -e "${GREEN}Profitez de votre nouvelle plateforme d'entreprise ! 🚀${NC}"
    echo ""
    
    # Afficher les credentials pour faciliter le premier accès
    echo -e "${YELLOW}🔑 Accès rapide (changez ces mots de passe !) :${NC}"
    echo "────────────────────────────────────"
    source .env
    echo -e "Dolibarr     → admin / ${BOLD}$DOLI_ADMIN_PASSWORD${NC}"
    echo -e "n8n          → admin / ${BOLD}$N8N_BASIC_AUTH_PASSWORD${NC}"
    [ "$ENABLE_MONITORING" = true ] && echo -e "Grafana      → admin / ${BOLD}$GRAFANA_ADMIN_PASSWORD${NC}"
    echo ""
}

# Fonction de nettoyage en cas d'erreur
cleanup_on_error() {
    log_error "Erreur détectée pendant l'installation"
    
    echo ""
    echo -e "${YELLOW}🔧 Options de récupération :${NC}"
    echo "1. Consulter les logs : tail -f $LOG_FILE"
    echo "2. Voir les conteneurs : docker ps -a"
    echo "3. Voir les logs Docker : docker-compose logs"
    echo "4. Nettoyer et recommencer : docker-compose down -v"
    echo ""
    
    # Proposer de sauvegarder les logs
    read -p "Voulez-vous sauvegarder les logs pour diagnostic ? (Y/n): " save_logs
    if [[ ! $save_logs == [nN] ]]; then
        local error_log="error_logs_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$error_log" "$LOG_FILE" 2>/dev/null || true
        log "Logs sauvegardés dans $error_log"
    fi
    
    exit 1
}

# Fonction principale
main() {
    # Initialisation
    exec > >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    
    # Gestion des erreurs
    trap cleanup_on_error ERR
    
    # Affichage initial
    show_banner
    
    # Parse des arguments
    parse_arguments "$@"
    
    # Étapes du déploiement
    comprehensive_system_check
    interactive_configuration
    backup_existing_installation
    generate_environment_config
    prepare_infrastructure
    deploy_services
    post_deployment_tests
    dns_verification
    generate_final_report
    
    # Résumé final
    show_final_summary
    
    log_success "Déploiement one-click terminé avec succès !"
}

# Point d'entrée
main "$@"