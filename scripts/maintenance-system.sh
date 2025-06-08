#!/bin/bash

# =================================================================
# SCRIPT DE MAINTENANCE SYSTÈME AUTOMATISÉE
# =================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_DIR}/logs/maintenance.log"
CONFIG_FILE="${PROJECT_DIR}/.env"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fonctions utilitaires
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

# Fonction d'aide
show_help() {
    cat << EOF
SCRIPT DE MAINTENANCE SYSTÈME

Usage: $0 [OPTIONS]

Options:
    -a, --all              Maintenance complète
    -d, --docker           Nettoyage Docker
    -l, --logs             Rotation des logs
    -s, --security         Audit de sécurité
    -p, --performance      Optimisation performances
    -u, --updates          Vérification des mises à jour
    -m, --monitoring       Vérification monitoring
    -b, --backup           Sauvegarde avant maintenance
    -r, --restart          Redémarrage des services
    -c, --certificates     Vérification certificats SSL
    -f, --filesystem       Nettoyage filesystem
    -n, --network          Tests réseau
    -h, --help            Afficher cette aide

Exemples:
    $0 -a                 # Maintenance complète
    $0 -d -l              # Nettoyage Docker + logs
    $0 -s -c              # Audit sécurité + certificats
    $0 -u -r              # Mises à jour + redémarrage

EOF
}

# Parse des arguments
MAINTENANCE_ALL=false
MAINTENANCE_DOCKER=false
MAINTENANCE_LOGS=false
MAINTENANCE_SECURITY=false
MAINTENANCE_PERFORMANCE=false
MAINTENANCE_UPDATES=false
MAINTENANCE_MONITORING=false
MAINTENANCE_BACKUP=false
MAINTENANCE_RESTART=false
MAINTENANCE_CERTIFICATES=false
MAINTENANCE_FILESYSTEM=false
MAINTENANCE_NETWORK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            MAINTENANCE_ALL=true
            shift
            ;;
        -d|--docker)
            MAINTENANCE_DOCKER=true
            shift
            ;;
        -l|--logs)
            MAINTENANCE_LOGS=true
            shift
            ;;
        -s|--security)
            MAINTENANCE_SECURITY=true
            shift
            ;;
        -p|--performance)
            MAINTENANCE_PERFORMANCE=true
            shift
            ;;
        -u|--updates)
            MAINTENANCE_UPDATES=true
            shift
            ;;
        -m|--monitoring)
            MAINTENANCE_MONITORING=true
            shift
            ;;
        -b|--backup)
            MAINTENANCE_BACKUP=true
            shift
            ;;
        -r|--restart)
            MAINTENANCE_RESTART=true
            shift
            ;;
        -c|--certificates)
            MAINTENANCE_CERTIFICATES=true
            shift
            ;;
        -f|--filesystem)
            MAINTENANCE_FILESYSTEM=true
            shift
            ;;
        -n|--network)
            MAINTENANCE_NETWORK=true
            shift
            ;;
        -h|--help)
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

# Si --all est spécifié, activer toutes les maintenances
if [ "$MAINTENANCE_ALL" = true ]; then
    MAINTENANCE_DOCKER=true
    MAINTENANCE_LOGS=true
    MAINTENANCE_SECURITY=true
    MAINTENANCE_PERFORMANCE=true
    MAINTENANCE_UPDATES=true
    MAINTENANCE_MONITORING=true
    MAINTENANCE_BACKUP=true
    MAINTENANCE_CERTIFICATES=true
    MAINTENANCE_FILESYSTEM=true
    MAINTENANCE_NETWORK=true
fi

# Vérifications préalables
check_prerequisites() {
    log "Vérification des prérequis..."
    
    # Créer le répertoire de logs
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Vérifier les permissions
    if [ "$EUID" -eq 0 ]; then
        log_warning "Exécution en tant que root"
    fi
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker non disponible"
        exit 1
    fi
    
    log_success "Prérequis vérifiés"
}

# Sauvegarde préventive
backup_before_maintenance() {
    if [ "$MAINTENANCE_BACKUP" = true ]; then
        log "Sauvegarde préventive avant maintenance..."
        
        if [ -f "$SCRIPT_DIR/backup-automated.sh" ]; then
            "$SCRIPT_DIR/backup-automated.sh" -t data -s
            log_success "Sauvegarde préventive terminée"
        else
            log_warning "Script de sauvegarde non trouvé"
        fi
    fi
}

# Nettoyage Docker
maintenance_docker() {
    if [ "$MAINTENANCE_DOCKER" = true ]; then
        log "🐳 Maintenance Docker..."
        
        # Arrêter les conteneurs inutilisés
        log "Arrêt des conteneurs inutilisés..."
        STOPPED_CONTAINERS=$(docker container prune -f --filter "until=24h" 2>/dev/null | grep "Total" | awk '{print $4}' || echo "0")
        log_success "Conteneurs supprimés: $STOPPED_CONTAINERS"
        
        # Supprimer les images inutilisées
        log "Suppression des images inutilisées..."
        REMOVED_IMAGES=$(docker image prune -a -f --filter "until=72h" 2>/dev/null | grep "Total" | awk '{print $4}' || echo "0")
        log_success "Images supprimées: $REMOVED_IMAGES"
        
        # Nettoyer les volumes inutilisés
        log "Nettoyage des volumes inutilisés..."
        REMOVED_VOLUMES=$(docker volume prune -f 2>/dev/null | grep "Total" | awk '{print $4}' || echo "0")
        log_success "Volumes supprimés: $REMOVED_VOLUMES"
        
        # Nettoyer les réseaux inutilisés
        log "Nettoyage des réseaux inutilisés..."
        REMOVED_NETWORKS=$(docker network prune -f 2>/dev/null | grep "Total" | awk '{print $4}' || echo "0")
        log_success "Réseaux supprimés: $REMOVED_NETWORKS"
        
        # Nettoyage global système Docker
        log "Nettoyage global Docker..."
        docker system df
        docker system prune -f >/dev/null 2>&1
        
        # Statistiques après nettoyage
        DISK_RECLAIMED=$(docker system df 2>/dev/null | grep "Build Cache" | awk '{print $4}' || echo "0B")
        log_success "Espace disque libéré: $DISK_RECLAIMED"
    fi
}

# Rotation et nettoyage des logs
maintenance_logs() {
    if [ "$MAINTENANCE_LOGS" = true ]; then
        log "📜 Maintenance des logs..."
        
        # Nettoyer les logs anciens de l'infrastructure
        find "$PROJECT_DIR/traefik-logs" -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true
        find "$PROJECT_DIR/n8n-logs" -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true
        find "$PROJECT_DIR/logs" -name "*.log" -type f -mtime +90 -delete 2>/dev/null || true
        
        # Rotation des logs Docker
        log "Rotation des logs Docker..."
        for container in $(docker ps -q); do
            CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container" | sed 's/^.//')
            LOG_SIZE=$(docker logs --details "$container" 2>/dev/null | wc -c || echo 0)
            
            # Si le log fait plus de 100MB, le tronquer
            if [ "$LOG_SIZE" -gt 104857600 ]; then
                log "Rotation logs container: $CONTAINER_NAME (${LOG_SIZE} bytes)"
                docker exec "$container" sh -c 'echo "" > /proc/1/fd/1' 2>/dev/null || true
                docker exec "$container" sh -c 'echo "" > /proc/1/fd/2' 2>/dev/null || true
            fi
        done
        
        # Nettoyer les logs système anciens
        if [ -w /var/log ]; then
            find /var/log -name "*.log.*.gz" -type f -mtime +30 -delete 2>/dev/null || true
            find /var/log -name "*.log.*" -type f -mtime +7 -delete 2>/dev/null || true
        fi
        
        # Compresser les gros logs
        find "$PROJECT_DIR" -name "*.log" -size +10M -type f -exec gzip {} \; 2>/dev/null || true
        
        log_success "Nettoyage des logs terminé"
    fi
}

# Audit de sécurité
maintenance_security() {
    if [ "$MAINTENANCE_SECURITY" = true ]; then
        log "🛡️  Audit de sécurité..."
        
        # Vérifier les permissions des fichiers sensibles
        log "Vérification des permissions..."
        if [ -f "$CONFIG_FILE" ]; then
            PERMS=$(stat -c %a "$CONFIG_FILE")
            if [ "$PERMS" != "600" ]; then
                log_warning "Permissions .env incorrectes: $PERMS (recommandé: 600)"
                chmod 600 "$CONFIG_FILE" 2>/dev/null || true
            fi
        fi
        
        # Vérifier les conteneurs en cours
        log "Audit des conteneurs..."
        RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")
        echo "$RUNNING_CONTAINERS" >> "$LOG_FILE"
        
        # Vérifier les ports exposés
        log "Vérification des ports exposés..."
        EXPOSED_PORTS=$(docker ps --format "{{.Ports}}" | grep -o "0.0.0.0:[0-9]*" | sort -u || true)
        if [ -n "$EXPOSED_PORTS" ]; then
            log_warning "Ports exposés détectés:"
            echo "$EXPOSED_PORTS" | while read -r port; do
                log "  - $port"
            done
        fi
        
        # Vérifier Fail2Ban si activé
        if docker ps | grep -q fail2ban; then
            log "Vérification Fail2Ban..."
            BANNED_IPS=$(docker exec fail2ban fail2ban-client status 2>/dev/null | grep "Banned IP list" | wc -l || echo "0")
            log_success "IPs bannies actuellement: $BANNED_IPS"
        fi
        
        # Vérifier les mises à jour de sécurité système
        if command -v apt &> /dev/null; then
            log "Vérification des mises à jour de sécurité..."
            SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l || echo "0")
            if [ "$SECURITY_UPDATES" -gt 0 ]; then
                log_warning "$SECURITY_UPDATES mises à jour de sécurité disponibles"
            fi
        fi
        
        log_success "Audit de sécurité terminé"
    fi
}

# Optimisation des performances
maintenance_performance() {
    if [ "$MAINTENANCE_PERFORMANCE" = true ]; then
        log "⚡ Optimisation des performances..."
        
        # Vérifier l'utilisation des ressources
        log "Analyse de l'utilisation des ressources..."
        
        # CPU
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "0")
        log "Utilisation CPU: ${CPU_USAGE}%"
        
        # Mémoire
        MEMORY_INFO=$(free -h | grep "Mem:")
        MEMORY_USED=$(echo "$MEMORY_INFO" | awk '{print $3}')
        MEMORY_TOTAL=$(echo "$MEMORY_INFO" | awk '{print $2}')
        log "Mémoire utilisée: $MEMORY_USED / $MEMORY_TOTAL"
        
        # Disque
        DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
        log "Utilisation disque: ${DISK_USAGE}%"
        
        # Alerte si utilisation élevée
        if [ "$DISK_USAGE" -gt 80 ]; then
            log_warning "Utilisation disque élevée: ${DISK_USAGE}%"
        fi
        
        # Optimiser les conteneurs
        log "Optimisation des conteneurs..."
        
        # Redémarrer les conteneurs avec utilisation mémoire élevée
        for container in $(docker ps --format "{{.Names}}"); do
            MEMORY_USAGE=$(docker stats --no-stream --format "{{.MemPerc}}" "$container" | sed 's/%//' || echo "0")
            if (( $(echo "$MEMORY_USAGE > 80" | bc -l) )); then
                log_warning "Container $container utilise ${MEMORY_USAGE}% de mémoire"
                # Optionnel: redémarrage automatique
                # docker restart "$container"
            fi
        done
        
        # Optimiser les volumes Docker
        log "Optimisation des volumes..."
        docker volume ls -qf dangling=true | xargs -r docker volume rm 2>/dev/null || true
        
        # Défragmentation (si ext4)
        if command -v e4defrag &> /dev/null; then
            log "Défragmentation des fichiers volumineux..."
            find "$PROJECT_DIR" -size +100M -type f -exec e4defrag {} \; 2>/dev/null || true
        fi
        
        log_success "Optimisation des performances terminée"
    fi
}

# Vérification des mises à jour
maintenance_updates() {
    if [ "$MAINTENANCE_UPDATES" = true ]; then
        log "🔄 Vérification des mises à jour..."
        
        # Mises à jour des images Docker
        log "Vérification des mises à jour Docker..."
        SERVICES=("traefik" "dolibarr/dolibarr" "docker.n8n.io/n8nio/n8n" "redis" "prom/prometheus" "grafana/grafana")
        
        for service in "${SERVICES[@]}"; do
            log "Vérification: $service"
            
            # Récupérer la version locale
            LOCAL_VERSION=$(docker images --format "{{.Tag}}" "$service" | head -1 || echo "unknown")
            log "Version locale: $LOCAL_VERSION"
            
            # Essayer de récupérer la dernière version (limité)
            docker pull "$service:latest" >/dev/null 2>&1 || true
        done
        
        # Mises à jour système
        if command -v apt &> /dev/null; then
            log "Vérification des mises à jour système..."
            apt update >/dev/null 2>&1 || true
            UPDATES_COUNT=$(apt list --upgradable 2>/dev/null | wc -l || echo "0")
            log "Mises à jour système disponibles: $UPDATES_COUNT"
        fi
        
        log_success "Vérification des mises à jour terminée"
    fi
}

# Vérification du monitoring
maintenance_monitoring() {
    if [ "$MAINTENANCE_MONITORING" = true ]; then
        log "📊 Vérification du monitoring..."
        
        # Vérifier Prometheus
        if docker ps | grep -q prometheus; then
            log "Test de Prometheus..."
            if curl -f -s "http://localhost:9090/-/healthy" >/dev/null 2>&1; then
                log_success "Prometheus opérationnel"
            else
                log_warning "Prometheus non accessible"
            fi
        fi
        
        # Vérifier Grafana
        if docker ps | grep -q grafana; then
            log "Test de Grafana..."
            if curl -f -s "http://localhost:3000/api/health" >/dev/null 2>&1; then
                log_success "Grafana opérationnel"
            else
                log_warning "Grafana non accessible"
            fi
        fi
        
        # Vérifier AlertManager
        if docker ps | grep -q alertmanager; then
            log "Test d'AlertManager..."
            if curl -f -s "http://localhost:9093/-/healthy" >/dev/null 2>&1; then
                log_success "AlertManager opérationnel"
            else
                log_warning "AlertManager non accessible"
            fi
        fi
        
        # Vérifier les métriques importantes
        log "Vérification des métriques..."
        
        # Nombre d'alertes actives
        ACTIVE_ALERTS=$(curl -s "http://localhost:9093/api/v1/alerts" 2>/dev/null | jq length 2>/dev/null || echo "0")
        log "Alertes actives: $ACTIVE_ALERTS"
        
        log_success "Vérification du monitoring terminée"
    fi
}

# Vérification des certificats SSL
maintenance_certificates() {
    if [ "$MAINTENANCE_CERTIFICATES" = true ]; then
        log "🔒 Vérification des certificats SSL..."
        
        if [ -f "$CONFIG_FILE" ]; then
            source "$CONFIG_FILE"
            
            # Vérifier les certificats pour chaque domaine
            for domain in "$TRAEFIK_DOMAIN" "$DOLIBARR_DOMAIN" "$N8N_DOMAIN"; do
                if [ -n "$domain" ]; then
                    log "Vérification certificat: $domain"
                    
                    # Vérifier l'expiration
                    EXPIRY_DATE=$(echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
                    
                    if [ -n "$EXPIRY_DATE" ]; then
                        EXPIRY_TIMESTAMP=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || echo "0")
                        CURRENT_TIMESTAMP=$(date +%s)
                        DAYS_LEFT=$(( (EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))
                        
                        if [ "$DAYS_LEFT" -lt 30 ]; then
                            log_warning "Certificat $domain expire dans $DAYS_LEFT jours"
                        else
                            log_success "Certificat $domain valide ($DAYS_LEFT jours restants)"
                        fi
                    else
                        log_warning "Impossible de vérifier le certificat pour $domain"
                    fi
                fi
            done
        fi
        
        # Vérifier l'espace dans le répertoire Let's Encrypt
        if [ -d "$PROJECT_DIR/traefik-data/letsencrypt" ]; then
            CERT_COUNT=$(find "$PROJECT_DIR/traefik-data/letsencrypt" -name "*.crt" | wc -l)
            log "Certificats stockés: $CERT_COUNT"
        fi
        
        log_success "Vérification des certificats terminée"
    fi
}

# Nettoyage du filesystem
maintenance_filesystem() {
    if [ "$MAINTENANCE_FILESYSTEM" = true ]; then
        log "💾 Nettoyage du filesystem..."
        
        # Nettoyer les fichiers temporaires
        log "Nettoyage des fichiers temporaires..."
        find /tmp -type f -atime +7 -delete 2>/dev/null || true
        find "$PROJECT_DIR" -name "*.tmp" -type f -delete 2>/dev/null || true
        
        # Nettoyer les sauvegardes anciennes
        log "Nettoyage des anciennes sauvegardes..."
        find "$PROJECT_DIR/backups" -name "backup_*.tar.gz" -type f -mtime +90 -delete 2>/dev/null || true
        
        # Nettoyer les cores dumps
        find / -name "core.*" -type f -delete 2>/dev/null || true
        
        # Optimiser les databases si SQLite présent
        find "$PROJECT_DIR" -name "*.db" -type f -exec sqlite3 {} "VACUUM;" \; 2>/dev/null || true
        
        log_success "Nettoyage du filesystem terminé"
    fi
}

# Tests réseau
maintenance_network() {
    if [ "$MAINTENANCE_NETWORK" = true ]; then
        log "🌐 Tests réseau..."
        
        # Tester la connectivité externe
        log "Test de connectivité externe..."
        if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            log_success "Connectivité externe OK"
        else
            log_warning "Problème de connectivité externe"
        fi
        
        # Tester la résolution DNS
        log "Test de résolution DNS..."
        if nslookup google.com >/dev/null 2>&1; then
            log_success "Résolution DNS OK"
        else
            log_warning "Problème de résolution DNS"
        fi
        
        # Tester les services internes
        if [ -f "$CONFIG_FILE" ]; then
            source "$CONFIG_FILE"
            
            for domain in "$TRAEFIK_DOMAIN" "$DOLIBARR_DOMAIN" "$N8N_DOMAIN"; do
                if [ -n "$domain" ]; then
                    log "Test de connectivité: $domain"
                    if curl -f -s --max-time 10 "https://$domain" >/dev/null 2>&1; then
                        log_success "$domain accessible"
                    else
                        log_warning "$domain non accessible"
                    fi
                fi
            done
        fi
        
        # Vérifier les réseaux Docker
        log "Vérification des réseaux Docker..."
        docker network ls
        
        log_success "Tests réseau terminés"
    fi
}

# Redémarrage des services
maintenance_restart() {
    if [ "$MAINTENANCE_RESTART" = true ]; then
        log "🔄 Redémarrage des services..."
        
        # Redémarrage progressif pour éviter l'interruption de service
        SERVICES=("redis" "dolibarr" "n8n-worker" "n8n" "traefik")
        
        for service in "${SERVICES[@]}"; do
            if docker ps | grep -q "$service"; then
                log "Redémarrage de $service..."
                docker restart "$service" >/dev/null 2>&1
                sleep 10  # Attendre que le service se stabilise
                log_success "$service redémarré"
            fi
        done
        
        # Vérifier que tous les services sont up
        sleep 30
        FAILED_SERVICES=""
        for service in "${SERVICES[@]}"; do
            if ! docker ps | grep -q "$service.*Up"; then
                FAILED_SERVICES="$FAILED_SERVICES $service"
            fi
        done
        
        if [ -n "$FAILED_SERVICES" ]; then
            log_error "Services en échec après redémarrage:$FAILED_SERVICES"
        else
            log_success "Tous les services redémarrés avec succès"
        fi
    fi
}

# Rapport de maintenance
generate_maintenance_report() {
    log "📋 Génération du rapport de maintenance..."
    
    REPORT_FILE="${PROJECT_DIR}/reports/maintenance_report_$(date +%Y%m%d_%H%M%S).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# Rapport de Maintenance Système

**Date :** $(date)  
**Durée :** $(($(date +%s) - START_TIME))s

## Résumé des actions

$([ "$MAINTENANCE_DOCKER" = true ] && echo "- ✅ Nettoyage Docker")
$([ "$MAINTENANCE_LOGS" = true ] && echo "- ✅ Rotation des logs")
$([ "$MAINTENANCE_SECURITY" = true ] && echo "- ✅ Audit de sécurité")
$([ "$MAINTENANCE_PERFORMANCE" = true ] && echo "- ✅ Optimisation performances")
$([ "$MAINTENANCE_UPDATES" = true ] && echo "- ✅ Vérification mises à jour")
$([ "$MAINTENANCE_MONITORING" = true ] && echo "- ✅ Vérification monitoring")
$([ "$MAINTENANCE_CERTIFICATES" = true ] && echo "- ✅ Vérification certificats")
$([ "$MAINTENANCE_FILESYSTEM" = true ] && echo "- ✅ Nettoyage filesystem")
$([ "$MAINTENANCE_NETWORK" = true ] && echo "- ✅ Tests réseau")
$([ "$MAINTENANCE_RESTART" = true ] && echo "- ✅ Redémarrage services")

## État du système

### Utilisation des ressources
\`\`\`
$(df -h)
\`\`\`

### Services Docker
\`\`\`
$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")
\`\`\`

### Logs de maintenance
Consultez \`$LOG_FILE\` pour les détails complets.

---
*Rapport généré automatiquement*
EOF

    log_success "Rapport généré: $REPORT_FILE"
}

# Fonction principale
main() {
    START_TIME=$(date +%s)
    
    echo "🔧 Démarrage de la maintenance système"
    echo "Actions planifiées:"
    [ "$MAINTENANCE_DOCKER" = true ] && echo "  - Nettoyage Docker"
    [ "$MAINTENANCE_LOGS" = true ] && echo "  - Rotation des logs"
    [ "$MAINTENANCE_SECURITY" = true ] && echo "  - Audit de sécurité"
    [ "$MAINTENANCE_PERFORMANCE" = true ] && echo "  - Optimisation performances"
    [ "$MAINTENANCE_UPDATES" = true ] && echo "  - Vérification mises à jour"
    [ "$MAINTENANCE_MONITORING" = true ] && echo "  - Vérification monitoring"
    [ "$MAINTENANCE_CERTIFICATES" = true ] && echo "  - Vérification certificats"
    [ "$MAINTENANCE_FILESYSTEM" = true ] && echo "  - Nettoyage filesystem"
    [ "$MAINTENANCE_NETWORK" = true ] && echo "  - Tests réseau"
    [ "$MAINTENANCE_RESTART" = true ] && echo "  - Redémarrage services"
    echo ""
    
    # Exécution des maintenances
    check_prerequisites
    backup_before_maintenance
    maintenance_docker
    maintenance_logs
    maintenance_security
    maintenance_performance
    maintenance_updates
    maintenance_monitoring
    maintenance_certificates
    maintenance_filesystem
    maintenance_network
    maintenance_restart
    
    # Rapport final
    generate_maintenance_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    echo ""
    echo "✅ Maintenance terminée avec succès !"
    echo "   Durée: ${duration}s"
    echo "   Log: $LOG_FILE"
}

# Gestion des signaux
trap 'log_error "Maintenance interrompue"; exit 1' INT TERM

# Lancement du script
main "$@"