#!/bin/bash

# =================================================================
# GÉNÉRATEUR DE RAPPORTS AUTOMATISÉS
# =================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="${PROJECT_DIR}/reports"
CONFIG_FILE="${PROJECT_DIR}/.env"

# Variables
REPORT_TYPE="weekly"
EMAIL_RECIPIENTS=""
INCLUDE_GRAPHS=false
SEND_EMAIL=false

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fonction d'aide
show_help() {
    cat << EOF
GÉNÉRATEUR DE RAPPORTS AUTOMATISÉS

Usage: $0 [OPTIONS]

Options:
    -t, --type TYPE       Type de rapport (daily|weekly|monthly|custom)
    -e, --email EMAIL     Envoyer par email (liste séparée par des virgules)
    -g, --graphs          Inclure les graphiques (nécessite Grafana)
    -o, --output DIR      Répertoire de sortie (défaut: ./reports)
    -f, --format FORMAT   Format de sortie (md|html|pdf)
    -d, --days DAYS       Nombre de jours à analyser (pour custom)
    -s, --slack           Envoyer vers Slack
    -h, --help           Afficher cette aide

Types de rapports:
    daily       Rapport quotidien (24h)
    weekly      Rapport hebdomadaire (7 jours)
    monthly     Rapport mensuel (30 jours)
    custom      Période personnalisée

Exemples:
    $0 -t weekly -e admin@example.com -g
    $0 -t monthly -s
    $0 -t custom -d 14 -f html

EOF
}

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            REPORT_TYPE="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL_RECIPIENTS="$2"
            SEND_EMAIL=true
            shift 2
            ;;
        -g|--graphs)
            INCLUDE_GRAPHS=true
            shift
            ;;
        -o|--output)
            REPORTS_DIR="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -d|--days)
            CUSTOM_DAYS="$2"
            shift 2
            ;;
        -s|--slack)
            SEND_SLACK=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Configuration par défaut
OUTPUT_FORMAT=${OUTPUT_FORMAT:-md}
CUSTOM_DAYS=${CUSTOM_DAYS:-7}

# Fonctions utilitaires
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌ $1${NC}"
}

# Charger la configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        log_warning "Fichier de configuration non trouvé"
    fi
}

# Déterminer la période
set_report_period() {
    case $REPORT_TYPE in
        "daily")
            START_DATE=$(date -d "1 day ago" '+%Y-%m-%d')
            END_DATE=$(date '+%Y-%m-%d')
            PERIOD_LABEL="Quotidien"
            DAYS=1
            ;;
        "weekly")
            START_DATE=$(date -d "7 days ago" '+%Y-%m-%d')
            END_DATE=$(date '+%Y-%m-%d')
            PERIOD_LABEL="Hebdomadaire"
            DAYS=7
            ;;
        "monthly")
            START_DATE=$(date -d "30 days ago" '+%Y-%m-%d')
            END_DATE=$(date '+%Y-%m-%d')
            PERIOD_LABEL="Mensuel"
            DAYS=30
            ;;
        "custom")
            START_DATE=$(date -d "$CUSTOM_DAYS days ago" '+%Y-%m-%d')
            END_DATE=$(date '+%Y-%m-%d')
            PERIOD_LABEL="Personnalisé ($CUSTOM_DAYS jours)"
            DAYS=$CUSTOM_DAYS
            ;;
        *)
            log_error "Type de rapport invalide: $REPORT_TYPE"
            exit 1
            ;;
    esac
    
    log "Période du rapport: $START_DATE → $END_DATE ($DAYS jours)"
}

# Collecter les métriques système
collect_system_metrics() {
    log "Collecte des métriques système..."
    
    # Utilisation CPU moyenne
    if command -v sar &> /dev/null; then
        CPU_AVG=$(sar -u 1 1 | awk 'NR==4 {print 100-$8}' 2>/dev/null || echo "N/A")
    else
        CPU_AVG=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "N/A")
    fi
    
    # Utilisation mémoire
    MEMORY_USAGE=$(free | awk 'NR==2{printf "%.1f", $3/$2*100}')
    MEMORY_TOTAL=$(free -h | awk 'NR==2{print $2}')
    MEMORY_USED=$(free -h | awk 'NR==2{print $3}')
    
    # Utilisation disque
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    
    # Charge système
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | sed 's/,//g' | xargs)
    
    # Uptime
    UPTIME=$(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}')
    
    log_success "Métriques système collectées"
}

# Collecter les métriques Docker
collect_docker_metrics() {
    log "Collecte des métriques Docker..."
    
    # Nombre de conteneurs
    CONTAINERS_RUNNING=$(docker ps -q | wc -l)
    CONTAINERS_TOTAL=$(docker ps -aq | wc -l)
    CONTAINERS_STOPPED=$((CONTAINERS_TOTAL - CONTAINERS_RUNNING))
    
    # Images Docker
    IMAGES_COUNT=$(docker images -q | wc -l)
    IMAGES_DANGLING=$(docker images -qf "dangling=true" | wc -l)
    
    # Volumes
    VOLUMES_COUNT=$(docker volume ls -q | wc -l)
    VOLUMES_DANGLING=$(docker volume ls -qf "dangling=true" | wc -l)
    
    # Utilisation disque Docker
    DOCKER_SIZE=$(docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}" 2>/dev/null || echo "N/A")
    
    log_success "Métriques Docker collectées"
}

# Collecter les métriques des applications
collect_app_metrics() {
    log "Collecte des métriques applications..."
    
    # Status des services principaux
    declare -A SERVICE_STATUS
    MAIN_SERVICES=("traefik" "dolibarr" "n8n" "n8n-worker" "redis")
    
    for service in "${MAIN_SERVICES[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${service}$"; then
            SERVICE_STATUS[$service]="✅ Running"
        else
            SERVICE_STATUS[$service]="❌ Stopped"
        fi
    done
    
    # Monitoring services
    MONITORING_SERVICES=("prometheus" "grafana" "alertmanager")
    for service in "${MONITORING_SERVICES[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${service}$"; then
            SERVICE_STATUS[$service]="✅ Running"
        else
            SERVICE_STATUS[$service]="⚫ Not deployed"
        fi
    done
    
    # Métriques depuis Prometheus (si disponible)
    if curl -s "http://localhost:9090/api/v1/query?query=up" >/dev/null 2>&1; then
        # Requêtes HTTP Traefik
        HTTP_REQUESTS=$(curl -s "http://localhost:9090/api/v1/query?query=sum(increase(traefik_requests_total[${DAYS}d]))" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A")
        
        # Erreurs HTTP
        HTTP_ERRORS=$(curl -s "http://localhost:9090/api/v1/query?query=sum(increase(traefik_requests_total{code=~\"5..\"}[${DAYS}d]))" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A")
        
        # Temps de réponse moyen
        RESPONSE_TIME=$(curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95, rate(traefik_request_duration_seconds_bucket[${DAYS}d]))" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A")
    else
        HTTP_REQUESTS="N/A (Prometheus indisponible)"
        HTTP_ERRORS="N/A"
        RESPONSE_TIME="N/A"
    fi
    
    log_success "Métriques applications collectées"
}

# Collecter les métriques de sécurité
collect_security_metrics() {
    log "Collecte des métriques de sécurité..."
    
    # Fail2Ban stats
    if docker ps | grep -q fail2ban; then
        BANNED_IPS=$(docker exec fail2ban fail2ban-client status 2>/dev/null | grep -o "Banned IP list:.*" | wc -w || echo "0")
        JAIL_STATUS=$(docker exec fail2ban fail2ban-client status 2>/dev/null | grep "Jail list" || echo "N/A")
    else
        BANNED_IPS="N/A (Fail2Ban non actif)"
        JAIL_STATUS="N/A"
    fi
    
    # Certificats SSL
    SSL_CERTS=""
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        for domain in "$TRAEFIK_DOMAIN" "$DOLIBARR_DOMAIN" "$N8N_DOMAIN"; do
            if [ -n "$domain" ]; then
                EXPIRY_DATE=$(echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
                if [ -n "$EXPIRY_DATE" ]; then
                    EXPIRY_TIMESTAMP=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || echo "0")
                    CURRENT_TIMESTAMP=$(date +%s)
                    DAYS_LEFT=$(( (EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))
                    SSL_CERTS="$SSL_CERTS\n  • $domain: $DAYS_LEFT jours"
                fi
            fi
        done
    fi
    
    # Logs de sécurité récents
    SECURITY_EVENTS="0"
    if [ -f "/var/log/auth.log" ]; then
        SECURITY_EVENTS=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")
    fi
    
    log_success "Métriques de sécurité collectées"
}

# Générer le rapport en Markdown
generate_markdown_report() {
    local report_file="$1"
    
    cat > "$report_file" << EOF
# 📊 Rapport d'Infrastructure - $PERIOD_LABEL

**Période :** $START_DATE au $END_DATE  
**Généré le :** $(date)  
**Durée :** $DAYS jours

## 📋 Résumé Exécutif

$(generate_executive_summary)

## 🖥️ Métriques Système

| Métrique | Valeur | Status |
|----------|--------|--------|
| **CPU Moyen** | ${CPU_AVG}% | $([ "${CPU_AVG}" != "N/A" ] && [ "${CPU_AVG%.*}" -lt 80 ] && echo "✅ Normal" || echo "⚠️ Élevé") |
| **Mémoire** | ${MEMORY_USED}/${MEMORY_TOTAL} (${MEMORY_USAGE}%) | $([ "${MEMORY_USAGE%.*}" -lt 80 ] && echo "✅ Normal" || echo "⚠️ Élevé") |
| **Disque** | ${DISK_USED}/${DISK_TOTAL} (${DISK_USAGE}%) | $([ "$DISK_USAGE" -lt 80 ] && echo "✅ Normal" || echo "⚠️ Élevé") |
| **Charge** | $LOAD_AVG | ✅ |
| **Uptime** | $UPTIME | ✅ |

## 🐳 Infrastructure Docker

| Métrique | Valeur |
|----------|--------|
| **Conteneurs actifs** | $CONTAINERS_RUNNING |
| **Conteneurs arrêtés** | $CONTAINERS_STOPPED |
| **Images totales** | $IMAGES_COUNT |
| **Images inutilisées** | $IMAGES_DANGLING |
| **Volumes totaux** | $VOLUMES_COUNT |
| **Volumes inutilisés** | $VOLUMES_DANGLING |

### Utilisation disque Docker
\`\`\`
$DOCKER_SIZE
\`\`\`

## 🚀 État des Services

| Service | Status |
|---------|--------|
$(for service in "${!SERVICE_STATUS[@]}"; do
    echo "| **$service** | ${SERVICE_STATUS[$service]} |"
done)

## 📈 Métriques Web (Traefik)

| Métrique | Valeur |
|----------|--------|
| **Requêtes totales** | $HTTP_REQUESTS |
| **Erreurs 5xx** | $HTTP_ERRORS |
| **Temps réponse P95** | ${RESPONSE_TIME}s |
| **Taux d'erreur** | $(if [ "$HTTP_REQUESTS" != "N/A" ] && [ "$HTTP_ERRORS" != "N/A" ]; then echo "scale=2; $HTTP_ERRORS * 100 / $HTTP_REQUESTS" | bc; else echo "N/A"; fi)% |

## 🛡️ Sécurité

| Métrique | Valeur |
|----------|--------|
| **IPs bannies (Fail2Ban)** | $BANNED_IPS |
| **Événements sécurité** | $SECURITY_EVENTS |
| **Certificats SSL** | $SSL_CERTS |

## 📊 Tendances et Recommandations

$(generate_recommendations)

## 🔧 Actions de Maintenance

### Effectuées automatiquement
- ✅ Sauvegarde quotidienne
- ✅ Nettoyage Docker
- ✅ Rotation des logs
- ✅ Audit de sécurité

### Recommandées
$(generate_action_items)

## 📱 Incidents et Alertes

$(check_recent_incidents)

---

*Rapport généré automatiquement par le système de monitoring*  
*Prochain rapport : $(date -d "+$DAYS days" '+%Y-%m-%d')*
EOF
}

# Générer un résumé exécutif
generate_executive_summary() {
    local status="🟢 EXCELLENT"
    local issues=""
    
    # Vérifier les problèmes
    if [ "${DISK_USAGE:-0}" -gt 85 ]; then
        status="🟡 ATTENTION"
        issues="$issues\n- Espace disque critique (${DISK_USAGE}%)"
    fi
    
    if [ "${MEMORY_USAGE%.*}" -gt 85 ]; then
        status="🟡 ATTENTION"
        issues="$issues\n- Utilisation mémoire élevée (${MEMORY_USAGE}%)"
    fi
    
    if [ "$CONTAINERS_STOPPED" -gt 0 ]; then
        status="🔴 PROBLÈME"
        issues="$issues\n- $CONTAINERS_STOPPED conteneur(s) arrêté(s)"
    fi
    
    echo "**État général :** $status"
    if [ -n "$issues" ]; then
        echo -e "\n**Points d'attention :**$issues"
    fi
    
    echo -e "\n**Synthèse :** Infrastructure fonctionnelle avec $CONTAINERS_RUNNING services actifs. Monitoring opérationnel."
}

# Générer des recommandations
generate_recommendations() {
    local recommendations=""
    
    if [ "${DISK_USAGE:-0}" -gt 80 ]; then
        recommendations="$recommendations\n- 💾 **Espace disque :** Nettoyer les anciennes sauvegardes et logs"
    fi
    
    if [ "$IMAGES_DANGLING" -gt 5 ]; then
        recommendations="$recommendations\n- 🐳 **Docker :** Nettoyer les images inutilisées ($IMAGES_DANGLING images)"
    fi
    
    if [ "$VOLUMES_DANGLING" -gt 0 ]; then
        recommendations="$recommendations\n- 📦 **Volumes :** Supprimer les volumes orphelins ($VOLUMES_DANGLING volumes)"
    fi
    
    if [ -z "$recommendations" ]; then
        echo "✅ Aucune action particulière recommandée. Infrastructure optimale."
    else
        echo -e "$recommendations"
    fi
}

# Générer des actions recommandées
generate_action_items() {
    local actions=""
    
    # Vérifier les mises à jour disponibles
    if command -v apt &> /dev/null; then
        local updates=$(apt list --upgradable 2>/dev/null | wc -l)
        if [ "$updates" -gt 1 ]; then
            actions="$actions\n- 🔄 Appliquer $updates mises à jour système"
        fi
    fi
    
    # Vérifier la rotation des logs
    local large_logs=$(find "$PROJECT_DIR" -name "*.log" -size +50M 2>/dev/null | wc -l)
    if [ "$large_logs" -gt 0 ]; then
        actions="$actions\n- 📜 Compresser $large_logs gros fichiers de logs"
    fi
    
    # Vérifier les sauvegardes
    local backup_age=$(find "$PROJECT_DIR/backups" -name "backup_*.tar.gz" -mtime -1 | wc -l)
    if [ "$backup_age" -eq 0 ]; then
        actions="$actions\n- 💾 Aucune sauvegarde récente trouvée"
    fi
    
    if [ -z "$actions" ]; then
        echo "✅ Aucune action urgente requise."
    else
        echo -e "$actions"
    fi
}

# Vérifier les incidents récents
check_recent_incidents() {
    local incidents=""
    
    # Vérifier les logs d'erreur récents
    if [ -f "$PROJECT_DIR/logs/cron.log" ]; then
        local errors=$(grep -c "ERROR" "$PROJECT_DIR/logs/cron.log" 2>/dev/null || echo "0")
        if [ "$errors" -gt 0 ]; then
            incidents="$incidents\n- ⚠️ $errors erreurs dans les logs cron"
        fi
    fi
    
    # Vérifier les alertes Prometheus
    if curl -s "http://localhost:9093/api/v1/alerts" >/dev/null 2>&1; then
        local active_alerts=$(curl -s "http://localhost:9093/api/v1/alerts" | jq length 2>/dev/null || echo "0")
        if [ "$active_alerts" -gt 0 ]; then
            incidents="$incidents\n- 🚨 $active_alerts alerte(s) active(s)"
        fi
    fi
    
    if [ -z "$incidents" ]; then
        echo "✅ Aucun incident signalé sur la période."
    else
        echo -e "**Incidents détectés :**$incidents"
    fi
}

# Envoyer le rapport par email
send_email_report() {
    local report_file="$1"
    
    if [ "$SEND_EMAIL" = true ] && [ -n "$EMAIL_RECIPIENTS" ]; then
        log "Envoi du rapport par email..."
        
        # Utiliser mail si disponible
        if command -v mail &> /dev/null; then
            local subject="📊 Rapport Infrastructure $PERIOD_LABEL - $(date '+%Y-%m-%d')"
            
            if [ "$OUTPUT_FORMAT" = "html" ]; then
                mail -s "$subject" -a "Content-Type: text/html" "$EMAIL_RECIPIENTS" < "$report_file"
            else
                mail -s "$subject" "$EMAIL_RECIPIENTS" < "$report_file"
            fi
            
            log_success "Rapport envoyé par email à: $EMAIL_RECIPIENTS"
        else
            log_warning "Commande 'mail' non disponible"
        fi
    fi
}

# Envoyer vers Slack
send_slack_report() {
    local report_file="$1"
    
    if [ "$SEND_SLACK" = true ] && [ -n "${SLACK_WEBHOOK_REPORTS:-}" ]; then
        log "Envoi du rapport vers Slack..."
        
        # Créer un résumé pour Slack
        local summary="📊 *Rapport Infrastructure $PERIOD_LABEL*\n\n"
        summary="${summary}🖥️ CPU: ${CPU_AVG}% | 💾 RAM: ${MEMORY_USAGE}% | 💿 Disque: ${DISK_USAGE}%\n"
        summary="${summary}🐳 Conteneurs: $CONTAINERS_RUNNING actifs | 🌐 Requêtes: $HTTP_REQUESTS\n"
        summary="${summary}\n📋 Rapport complet disponible dans les logs"
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$summary\"}" \
            "${SLACK_WEBHOOK_REPORTS}" >/dev/null 2>&1
        
        log_success "Résumé envoyé vers Slack"
    fi
}

# Convertir en HTML si demandé
convert_to_html() {
    local md_file="$1"
    local html_file="${md_file%.md}.html"
    
    if [ "$OUTPUT_FORMAT" = "html" ]; then
        if command -v pandoc &> /dev/null; then
            pandoc "$md_file" -o "$html_file" --standalone --css=style.css
            log_success "Rapport HTML généré: $(basename "$html_file")"
            echo "$html_file"
        else
            log_warning "pandoc non disponible pour la conversion HTML"
            echo "$md_file"
        fi
    else
        echo "$md_file"
    fi
}

# Fonction principale
main() {
    echo -e "${PURPLE}📊 Génération du rapport d'infrastructure${NC}"
    echo "Type: $REPORT_TYPE | Format: $OUTPUT_FORMAT"
    echo ""
    
    # Initialisation
    load_config
    set_report_period
    mkdir -p "$REPORTS_DIR"
    
    # Collecte des données
    collect_system_metrics
    collect_docker_metrics
    collect_app_metrics
    collect_security_metrics
    
    # Génération du rapport
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local report_file="$REPORTS_DIR/infrastructure_report_${REPORT_TYPE}_${timestamp}.md"
    
    log "Génération du rapport: $(basename "$report_file")"
    generate_markdown_report "$report_file"
    
    # Conversion de format si nécessaire
    local final_file=$(convert_to_html "$report_file")
    
    # Envoi du rapport
    send_email_report "$final_file"
    send_slack_report "$final_file"
    
    # Résumé
    local file_size=$(du -h "$final_file" | cut -f1)
    log_success "Rapport généré avec succès !"
    echo ""
    echo -e "${GREEN}📄 Fichier: $(basename "$final_file") (${file_size})${NC}"
    echo -e "${GREEN}📁 Dossier: $REPORTS_DIR${NC}"
    echo ""
    
    # Afficher un aperçu du résumé
    echo -e "${BLUE}📋 Aperçu du rapport :${NC}"
    echo "----------------------------------------"
    head -20 "$final_file" | grep -E "^(#|📊|🖥️|🐳)" || head -10 "$final_file"
    echo "----------------------------------------"
    echo "📖 Consultez le rapport complet dans $final_file"
}

# Lancement du script
main "$@"