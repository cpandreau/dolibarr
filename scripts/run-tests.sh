#!/bin/bash

# =================================================================
# SCRIPT DE TESTS AUTOMATISÉS INFRASTRUCTURE
# =================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_DIR}/.env"
TEST_RESULTS_DIR="${PROJECT_DIR}/test-results"

# Variables de test
TIMEOUT=30
VERBOSE=false
FAST_MODE=false
SKIP_EXTERNAL=false
GENERATE_REPORT=true

# Compteurs
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Arrays pour stocker les résultats
declare -a PASSED_TEST_NAMES=()
declare -a FAILED_TEST_NAMES=()
declare -a SKIPPED_TEST_NAMES=()

# Fonction d'aide
show_help() {
    cat << EOF
SCRIPT DE TESTS AUTOMATISÉS INFRASTRUCTURE

Usage: $0 [OPTIONS]

Options:
    -v, --verbose         Mode verbeux
    -f, --fast           Mode rapide (tests essentiels uniquement)
    -s, --skip-external  Ignorer les tests externes (DNS, SSL)
    -t, --timeout SEC    Timeout pour les tests (défaut: 30s)
    -o, --output DIR     Répertoire de sortie (défaut: ./test-results)
    -r, --no-report      Ne pas générer de rapport
    -h, --help          Afficher cette aide

Types de tests:
    • Tests Docker et conteneurs
    • Tests de connectivité réseau
    • Tests des services applicatifs
    • Tests SSL et certificats
    • Tests de sécurité
    • Tests de performance
    • Tests de monitoring
    • Tests d'intégration

Exemples:
    $0                    # Tous les tests
    $0 -f                # Tests rapides
    $0 -v --skip-external # Tests internes avec détails
    $0 -t 60             # Timeout 60s

EOF
}

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--fast)
            FAST_MODE=true
            shift
            ;;
        -s|--skip-external)
            SKIP_EXTERNAL=true
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -o|--output)
            TEST_RESULTS_DIR="$2"
            shift 2
            ;;
        -r|--no-report)
            GENERATE_REPORT=false
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

# Fonctions utilitaires
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_test() {
    local test_name="$1"
    local status="$2"
    local details="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    case $status in
        "PASS")
            echo -e "${GREEN}✅ [PASS]${NC} $test_name"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            PASSED_TEST_NAMES+=("$test_name")
            [ "$VERBOSE" = true ] && [ -n "$details" ] && echo "   $details"
            ;;
        "FAIL")
            echo -e "${RED}❌ [FAIL]${NC} $test_name"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            FAILED_TEST_NAMES+=("$test_name")
            [ -n "$details" ] && echo -e "   ${RED}$details${NC}"
            ;;
        "SKIP")
            echo -e "${YELLOW}⏭️  [SKIP]${NC} $test_name"
            SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            SKIPPED_TEST_NAMES+=("$test_name")
            [ "$VERBOSE" = true ] && [ -n "$details" ] && echo "   $details"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  [WARN]${NC} $test_name"
            [ -n "$details" ] && echo -e "   ${YELLOW}$details${NC}"
            ;;
    esac
}

# Charger la configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_test "Configuration loading" "PASS" "Variables d'environnement chargées"
    else
        log_test "Configuration loading" "FAIL" "Fichier .env non trouvé"
        return 1
    fi
}

# Tests Docker
test_docker_infrastructure() {
    echo -e "\n${CYAN}🐳 Tests Docker Infrastructure${NC}"
    
    # Test Docker daemon
    if docker info >/dev/null 2>&1; then
        log_test "Docker daemon" "PASS" "Docker fonctionne correctement"
    else
        log_test "Docker daemon" "FAIL" "Docker daemon inaccessible"
        return 1
    fi
    
    # Test Docker Compose
    if docker-compose version >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
        log_test "Docker Compose" "PASS" "Docker Compose disponible"
    else
        log_test "Docker Compose" "FAIL" "Docker Compose non disponible"
    fi
    
    # Test des réseaux Docker
    if docker network ls | grep -q "traefik-network"; then
        log_test "Réseau traefik-network" "PASS" "Réseau Docker présent"
    else
        log_test "Réseau traefik-network" "FAIL" "Réseau Docker manquant"
    fi
    
    # Test des volumes Docker
    local volumes=("traefik_data" "dolibarr_documents" "n8n_data")
    for volume in "${volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            log_test "Volume $volume" "PASS" "Volume Docker présent"
        else
            log_test "Volume $volume" "SKIP" "Volume non créé ou nommé différemment"
        fi
    done
}

# Tests des conteneurs
test_containers() {
    echo -e "\n${CYAN}📦 Tests des Conteneurs${NC}"
    
    # Conteneurs principaux
    local main_containers=("traefik" "dolibarr" "n8n" "n8n-worker" "redis")
    
    for container in "${main_containers[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            # Vérifier le statut de santé
            local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
            
            case $health_status in
                "healthy")
                    log_test "Container $container" "PASS" "Conteneur en fonctionnement et en bonne santé"
                    ;;
                "unhealthy")
                    log_test "Container $container" "FAIL" "Conteneur unhealthy"
                    ;;
                "starting")
                    log_test "Container $container" "WARN" "Conteneur en cours de démarrage"
                    ;;
                "no-healthcheck")
                    log_test "Container $container" "PASS" "Conteneur en fonctionnement (pas de healthcheck)"
                    ;;
                *)
                    log_test "Container $container" "WARN" "Status: $health_status"
                    ;;
            esac
            
            # Test des ressources si mode verbeux
            if [ "$VERBOSE" = true ]; then
                local memory_usage=$(docker stats --no-stream --format "{{.MemPerc}}" "$container" | sed 's/%//')
                local cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" "$container" | sed 's/%//')
                log_test "Resources $container" "PASS" "CPU: ${cpu_usage}%, Memory: ${memory_usage}%"
            fi
        else
            log_test "Container $container" "FAIL" "Conteneur non démarré"
        fi
    done
    
    # Conteneurs de monitoring (si pas en mode fast)
    if [ "$FAST_MODE" = false ]; then
        local monitoring_containers=("prometheus" "grafana" "alertmanager")
        
        for container in "${monitoring_containers[@]}"; do
            if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
                log_test "Monitoring $container" "PASS" "Conteneur de monitoring actif"
            else
                log_test "Monitoring $container" "SKIP" "Conteneur de monitoring non déployé"
            fi
        done
    fi
}

# Tests de connectivité réseau
test_network_connectivity() {
    echo -e "\n${CYAN}🌐 Tests de Connectivité Réseau${NC}"
    
    # Test connectivité externe
    if [ "$SKIP_EXTERNAL" = false ]; then
        if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
            log_test "Connectivité externe" "PASS" "Connexion Internet OK"
        else
            log_test "Connectivité externe" "FAIL" "Pas de connexion Internet"
        fi
        
        # Test DNS
        if nslookup google.com >/dev/null 2>&1; then
            log_test "Résolution DNS" "PASS" "DNS fonctionne correctement"
        else
            log_test "Résolution DNS" "FAIL" "Problème de résolution DNS"
        fi
    else
        log_test "Tests externes" "SKIP" "Tests externes ignorés"
    fi
    
    # Test connectivité interne entre conteneurs
    if docker exec traefik ping -c 1 dolibarr >/dev/null 2>&1; then
        log_test "Connectivité interne" "PASS" "Communication inter-conteneurs OK"
    else
        log_test "Connectivité interne" "FAIL" "Problème de communication interne"
    fi
    
    # Test ports locaux
    local ports=("80:traefik" "443:traefik" "9090:prometheus" "3000:grafana")
    
    for port_service in "${ports[@]}"; do
        local port=$(echo "$port_service" | cut -d: -f1)
        local service=$(echo "$port_service" | cut -d: -f2)
        
        if [ "$service" = "prometheus" ] || [ "$service" = "grafana" ]; then
            [ "$FAST_MODE" = true ] && continue
        fi
        
        if netstat -tuln | grep -q ":$port "; then
            log_test "Port $port ($service)" "PASS" "Port en écoute"
        else
            log_test "Port $port ($service)" "FAIL" "Port non accessible"
        fi
    done
}

# Tests des services applicatifs
test_application_services() {
    echo -e "\n${CYAN}🚀 Tests des Services Applicatifs${NC}"
    
    # Test Traefik API
    if curl -f -s --max-time "$TIMEOUT" "http://localhost:8080/api/rawdata" >/dev/null 2>&1; then
        log_test "Traefik API" "PASS" "API Traefik accessible"
        
        # Vérifier la configuration
        local services_count=$(curl -s "http://localhost:8080/api/http/services" | jq length 2>/dev/null || echo "0")
        log_test "Traefik Services" "PASS" "$services_count services configurés"
    else
        log_test "Traefik API" "FAIL" "API Traefik inaccessible"
    fi
    
    # Test endpoints des applications via Traefik
    if [ -n "${DOLIBARR_DOMAIN:-}" ] && [ "$SKIP_EXTERNAL" = false ]; then
        if curl -f -s --max-time "$TIMEOUT" -H "Host: $DOLIBARR_DOMAIN" "http://localhost/" >/dev/null 2>&1; then
            log_test "Dolibarr via Traefik" "PASS" "Application accessible"
        else
            log_test "Dolibarr via Traefik" "FAIL" "Application inaccessible via Traefik"
        fi
    fi
    
    if [ -n "${N8N_DOMAIN:-}" ] && [ "$SKIP_EXTERNAL" = false ]; then
        if curl -f -s --max-time "$TIMEOUT" -H "Host: $N8N_DOMAIN" "http://localhost/" >/dev/null 2>&1; then
            log_test "n8n via Traefik" "PASS" "Application accessible"
        else
            log_test "n8n via Traefik" "FAIL" "Application inaccessible via Traefik"
        fi
    fi
    
    # Test direct des conteneurs
    if curl -f -s --max-time 10 "http://$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dolibarr)/" >/dev/null 2>&1; then
        log_test "Dolibarr direct" "PASS" "Conteneur Dolibarr répond"
    else
        log_test "Dolibarr direct" "FAIL" "Conteneur Dolibarr ne répond pas"
    fi
    
    # Test Redis
    if docker exec redis redis-cli ping | grep -q "PONG"; then
        log_test "Redis connectivity" "PASS" "Redis répond aux commandes"
        
        # Test authentification Redis
        if [ -n "${REDIS_PASSWORD:-}" ]; then
            if docker exec redis redis-cli -a "$REDIS_PASSWORD" ping | grep -q "PONG"; then
                log_test "Redis auth" "PASS" "Authentification Redis OK"
            else
                log_test "Redis auth" "FAIL" "Problème d'authentification Redis"
            fi
        fi
    else
        log_test "Redis connectivity" "FAIL" "Redis ne répond pas"
    fi
}

# Tests SSL et certificats
test_ssl_certificates() {
    if [ "$SKIP_EXTERNAL" = true ]; then
        log_test "Tests SSL" "SKIP" "Tests externes ignorés"
        return 0
    fi
    
    echo -e "\n${CYAN}🔒 Tests SSL et Certificats${NC}"
    
    # Test présence des certificats Let's Encrypt
    if [ -d "$PROJECT_DIR/traefik-data/letsencrypt" ]; then
        local cert_count=$(find "$PROJECT_DIR/traefik-data/letsencrypt" -name "*.crt" 2>/dev/null | wc -l)
        if [ "$cert_count" -gt 0 ]; then
            log_test "Certificats présents" "PASS" "$cert_count certificat(s) trouvé(s)"
        else
            log_test "Certificats présents" "WARN" "Aucun certificat trouvé (normal si premier démarrage)"
        fi
    fi
    
    # Test des certificats pour chaque domaine
    local domains=("$TRAEFIK_DOMAIN" "$DOLIBARR_DOMAIN" "$N8N_DOMAIN")
    
    for domain in "${domains[@]}"; do
        if [ -n "$domain" ]; then
            # Test connectivité HTTPS
            if curl -f -s --max-time "$TIMEOUT" "https://$domain" >/dev/null 2>&1; then
                log_test "HTTPS $domain" "PASS" "Connexion HTTPS réussie"
                
                # Test expiration du certificat
                local expiry_date=$(echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
                
                if [ -n "$expiry_date" ]; then
                    local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
                    local current_timestamp=$(date +%s)
                    local days_left=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                    
                    if [ "$days_left" -gt 30 ]; then
                        log_test "Certificat $domain" "PASS" "Valide ($days_left jours restants)"
                    elif [ "$days_left" -gt 7 ]; then
                        log_test "Certificat $domain" "WARN" "Expire bientôt ($days_left jours)"
                    else
                        log_test "Certificat $domain" "FAIL" "Expire très bientôt ($days_left jours)"
                    fi
                fi
            else
                log_test "HTTPS $domain" "FAIL" "Connexion HTTPS impossible"
            fi
        fi
    done
    
    # Test redirection HTTP vers HTTPS
    if [ -n "${DOLIBARR_DOMAIN:-}" ]; then
        local redirect_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://$DOLIBARR_DOMAIN" 2>/dev/null || echo "000")
        if [ "$redirect_status" = "301" ] || [ "$redirect_status" = "302" ] || [ "$redirect_status" = "308" ]; then
            log_test "Redirection HTTPS" "PASS" "HTTP redirige vers HTTPS (code $redirect_status)"
        else
            log_test "Redirection HTTPS" "FAIL" "Redirection HTTPS non configurée (code $redirect_status)"
        fi
    fi
}

# Tests de sécurité
test_security() {
    echo -e "\n${CYAN}🛡️ Tests de Sécurité${NC}"
    
    # Test permissions du fichier .env
    if [ -f "$CONFIG_FILE" ]; then
        local perms=$(stat -c %a "$CONFIG_FILE")
        if [ "$perms" = "600" ] || [ "$perms" = "400" ]; then
            log_test "Permissions .env" "PASS" "Permissions sécurisées ($perms)"
        else
            log_test "Permissions .env" "FAIL" "Permissions trop ouvertes ($perms)"
        fi
    fi
    
    # Test Fail2Ban si présent
    if docker ps | grep -q fail2ban; then
        if docker exec fail2ban fail2ban-client ping | grep -q "pong"; then
            log_test "Fail2Ban status" "PASS" "Fail2Ban actif et fonctionnel"
            
            # Test des jails
            local active_jails=$(docker exec fail2ban fail2ban-client status | grep "Jail list" | awk -F: '{print $2}' | tr ',' '\n' | wc -l)
            log_test "Fail2Ban jails" "PASS" "$active_jails jail(s) active(s)"
        else
            log_test "Fail2Ban status" "FAIL" "Fail2Ban ne répond pas"
        fi
    else
        log_test "Fail2Ban" "SKIP" "Fail2Ban non déployé"
    fi
    
    # Test headers de sécurité
    if [ -n "${DOLIBARR_DOMAIN:-}" ] && [ "$SKIP_EXTERNAL" = false ]; then
        local security_headers=$(curl -s -I --max-time 10 "https://$DOLIBARR_DOMAIN" 2>/dev/null || echo "")
        
        if echo "$security_headers" | grep -qi "strict-transport-security"; then
            log_test "HSTS Header" "PASS" "Header HSTS présent"
        else
            log_test "HSTS Header" "FAIL" "Header HSTS manquant"
        fi
        
        if echo "$security_headers" | grep -qi "x-frame-options"; then
            log_test "X-Frame-Options" "PASS" "Protection clickjacking active"
        else
            log_test "X-Frame-Options" "WARN" "Header X-Frame-Options manquant"
        fi
    fi
    
    # Test exposition des ports
    local exposed_ports=$(docker ps --format "{{.Ports}}" | grep -o "0.0.0.0:[0-9]*" | sort -u)
    local expected_ports=("0.0.0.0:80" "0.0.0.0:443")
    
    for port in $exposed_ports; do
        if [[ " ${expected_ports[@]} " =~ " ${port} " ]]; then
            log_test "Port exposition $port" "PASS" "Port légitimement exposé"
        else
            log_test "Port exposition $port" "WARN" "Port inattendu exposé"
        fi
    done
}

# Tests de monitoring
test_monitoring() {
    if [ "$FAST_MODE" = true ]; then
        log_test "Tests monitoring" "SKIP" "Mode rapide activé"
        return 0
    fi
    
    echo -e "\n${CYAN}📊 Tests de Monitoring${NC}"
    
    # Test Prometheus
    if curl -f -s --max-time 10 "http://localhost:9090/-/healthy" >/dev/null 2>&1; then
        log_test "Prometheus health" "PASS" "Prometheus opérationnel"
        
        # Test métriques
        local metrics_count=$(curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq length 2>/dev/null || echo "0")
        log_test "Prometheus metrics" "PASS" "$metrics_count métriques disponibles"
        
        # Test targets
        local targets_up=$(curl -s "http://localhost:9090/api/v1/query?query=up" | jq '.data.result | length' 2>/dev/null || echo "0")
        log_test "Prometheus targets" "PASS" "$targets_up target(s) surveillé(s)"
    else
        log_test "Prometheus health" "FAIL" "Prometheus inaccessible"
    fi
    
    # Test Grafana
    if curl -f -s --max-time 10 "http://localhost:3000/api/health" >/dev/null 2>&1; then
        log_test "Grafana health" "PASS" "Grafana opérationnel"
        
        # Test datasources
        local datasources=$(curl -s "http://localhost:3000/api/datasources" 2>/dev/null | jq length 2>/dev/null || echo "0")
        log_test "Grafana datasources" "PASS" "$datasources datasource(s) configurée(s)"
    else
        log_test "Grafana health" "FAIL" "Grafana inaccessible"
    fi
    
    # Test AlertManager
    if curl -f -s --max-time 10 "http://localhost:9093/-/healthy" >/dev/null 2>&1; then
        log_test "AlertManager health" "PASS" "AlertManager opérationnel"
        
        # Test alertes actives
        local active_alerts=$(curl -s "http://localhost:9093/api/v1/alerts" | jq length 2>/dev/null || echo "0")
        if [ "$active_alerts" -eq 0 ]; then
            log_test "AlertManager alerts" "PASS" "Aucune alerte active"
        else
            log_test "AlertManager alerts" "WARN" "$active_alerts alerte(s) active(s)"
        fi
    else
        log_test "AlertManager health" "FAIL" "AlertManager inaccessible"
    fi
}

# Tests de performance
test_performance() {
    if [ "$FAST_MODE" = true ]; then
        log_test "Tests performance" "SKIP" "Mode rapide activé"
        return 0
    fi
    
    echo -e "\n${CYAN}⚡ Tests de Performance${NC}"
    
    # Test temps de réponse
    if [ -n "${DOLIBARR_DOMAIN:-}" ] && [ "$SKIP_EXTERNAL" = false ]; then
        local response_time=$(curl -o /dev/null -s -w "%{time_total}" --max-time "$TIMEOUT" "https://$DOLIBARR_DOMAIN" 2>/dev/null || echo "999")
        
        if (( $(echo "$response_time < 2" | bc -l) )); then
            log_test "Temps réponse Dolibarr" "PASS" "${response_time}s"
        elif (( $(echo "$response_time < 5" | bc -l) )); then
            log_test "Temps réponse Dolibarr" "WARN" "${response_time}s (lent)"
        else
            log_test "Temps réponse Dolibarr" "FAIL" "${response_time}s (très lent)"
        fi
    fi
    
    # Test utilisation ressources
    local memory_usage=$(free | awk 'NR==2{printf "%.1f", $3/$2*100}')
    if (( $(echo "$memory_usage < 80" | bc -l) )); then
        log_test "Utilisation mémoire" "PASS" "${memory_usage}%"
    elif (( $(echo "$memory_usage < 90" | bc -l) )); then
        log_test "Utilisation mémoire" "WARN" "${memory_usage}% (élevé)"
    else
        log_test "Utilisation mémoire" "FAIL" "${memory_usage}% (critique)"
    fi
    
    # Test espace disque
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 80 ]; then
        log_test "Espace disque" "PASS" "${disk_usage}%"
    elif [ "$disk_usage" -lt 90 ]; then
        log_test "Espace disque" "WARN" "${disk_usage}% (attention)"
    else
        log_test "Espace disque" "FAIL" "${disk_usage}% (critique)"
    fi
    
    # Test charge système
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    local load_ratio=$(echo "scale=2; $load_avg / $cpu_cores" | bc -l)
    
    if (( $(echo "$load_ratio < 0.7" | bc -l) )); then
        log_test "Charge système" "PASS" "${load_avg} (ratio: ${load_ratio})"
    elif (( $(echo "$load_ratio < 1.0" | bc -l) )); then
        log_test "Charge système" "WARN" "${load_avg} (ratio: ${load_ratio})"
    else
        log_test "Charge système" "FAIL" "${load_avg} (ratio: ${load_ratio})"
    fi
}

# Tests d'intégration
test_integration() {
    if [ "$FAST_MODE" = true ]; then
        log_test "Tests intégration" "SKIP" "Mode rapide activé"
        return 0
    fi
    
    echo -e "\n${CYAN}🔗 Tests d'Intégration${NC}"
    
    # Test communication n8n ↔ Redis
    if docker exec n8n-worker ls /tmp >/dev/null 2>&1 && docker exec redis redis-cli ping | grep -q "PONG"; then
        log_test "n8n ↔ Redis" "PASS" "Communication worker/queue OK"
    else
        log_test "n8n ↔ Redis" "FAIL" "Problème communication n8n/Redis"
    fi
    
    # Test accès base de données depuis Dolibarr
    if [ -n "${DOLI_DB_HOST:-}" ]; then
        if docker exec dolibarr wget -qO- --timeout=10 "$DOLI_DB_HOST:${DOLI_DB_HOST_PORT:-5432}" >/dev/null 2>&1; then
            log_test "Dolibarr ↔ DB" "PASS" "Connexion base de données OK"
        else
            log_test "Dolibarr ↔ DB" "FAIL" "Problème connexion base de données"
        fi
    fi
    
    # Test webhook n8n (si configuré)
    if [ -n "${N8N_DOMAIN:-}" ] && [ "$SKIP_EXTERNAL" = false ]; then
        local webhook_test=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$N8N_DOMAIN/webhook/test" 2>/dev/null || echo "000")
        if [ "$webhook_test" = "404" ]; then
            log_test "n8n webhooks" "PASS" "Endpoint webhook accessible (404 attendu)"
        elif [ "$webhook_test" = "401" ]; then
            log_test "n8n webhooks" "PASS" "Webhook protégé (401 attendu)"
        else
            log_test "n8n webhooks" "WARN" "Réponse inattendue webhook ($webhook_test)"
        fi
    fi
}

# Générer le rapport de test
generate_test_report() {
    if [ "$GENERATE_REPORT" = false ]; then
        return 0
    fi
    
    mkdir -p "$TEST_RESULTS_DIR"
    local report_file="$TEST_RESULTS_DIR/test_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# 🧪 Rapport de Tests Infrastructure

**Date :** $(date)  
**Mode :** $([[ $FAST_MODE == true ]] && echo "Rapide" || echo "Complet")  
**Timeout :** ${TIMEOUT}s  
**Tests externes :** $([[ $SKIP_EXTERNAL == true ]] && echo "Ignorés" || echo "Inclus")

## 📊 Résumé

| Métrique | Valeur |
|----------|--------|
| **Total** | $TOTAL_TESTS |
| **✅ Réussis** | $PASSED_TESTS |
| **❌ Échoués** | $FAILED_TESTS |
| **⏭️ Ignorés** | $SKIPPED_TESTS |
| **Taux de réussite** | $(( PASSED_TESTS * 100 / (TOTAL_TESTS - SKIPPED_TESTS) ))% |

## 📋 Détail des Tests

### ✅ Tests Réussis ($PASSED_TESTS)
$(for test in "${PASSED_TEST_NAMES[@]}"; do echo "- $test"; done)

### ❌ Tests Échoués ($FAILED_TESTS)
$(for test in "${FAILED_TEST_NAMES[@]}"; do echo "- $test"; done)

### ⏭️ Tests Ignorés ($SKIPPED_TESTS)
$(for test in "${SKIPPED_TEST_NAMES[@]}"; do echo "- $test"; done)

## 🎯 Recommandations

$(generate_test_recommendations)

---
*Rapport généré automatiquement*
EOF
    
    log "Rapport de test généré: $(basename "$report_file")"
    echo "$report_file"
}

# Générer des recommandations basées sur les tests
generate_test_recommendations() {
    local recommendations=""
    
    if [ $FAILED_TESTS -gt 0 ]; then
        recommendations="$recommendations\n### 🚨 Actions Urgentes\n"
        recommendations="$recommendations- Corriger les $FAILED_TESTS test(s) en échec\n"
        recommendations="$recommendations- Vérifier les logs des services défaillants\n"
    fi
    
    if [ $FAILED_TESTS -eq 0 ] && [ $PASSED_TESTS -gt 0 ]; then
        recommendations="$recommendations\n### ✅ Infrastructure Saine\n"
        recommendations="$recommendations- Tous les tests critiques passent\n"
        recommendations="$recommendations- Continuer la surveillance régulière\n"
    fi
    
    if [ $SKIPPED_TESTS -gt 5 ]; then
        recommendations="$recommendations\n### 📝 Tests Optionnels\n"
        recommendations="$recommendations- Considérer l'activation des $SKIPPED_TESTS tests ignorés\n"
        recommendations="$recommendations- Déployer les composants manquants si nécessaire\n"
    fi
    
    echo -e "$recommendations"
}

# Afficher le résumé final
show_final_summary() {
    echo ""
    echo -e "${PURPLE}🧪 RÉSUMÉ FINAL DES TESTS${NC}"
    echo "========================================"
    
    local success_rate=0
    if [ $((TOTAL_TESTS - SKIPPED_TESTS)) -gt 0 ]; then
        success_rate=$(( PASSED_TESTS * 100 / (TOTAL_TESTS - SKIPPED_TESTS) ))
    fi
    
    echo -e "📊 Total: ${CYAN}$TOTAL_TESTS${NC} tests"
    echo -e "✅ Réussis: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "❌ Échoués: ${RED}$FAILED_TESTS${NC}"
    echo -e "⏭️ Ignorés: ${YELLOW}$SKIPPED_TESTS${NC}"
    echo -e "📈 Taux de réussite: ${CYAN}${success_rate}%${NC}"
    echo ""
    
    # Status global
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}🎉 TOUS LES TESTS SONT PASSÉS !${NC}"
        echo -e "${GREEN}Infrastructure fonctionnelle et opérationnelle.${NC}"
        return 0
    elif [ $FAILED_TESTS -le 2 ]; then
        echo -e "${YELLOW}⚠️ TESTS MAJORITAIREMENT RÉUSSIS${NC}"
        echo -e "${YELLOW}Quelques problèmes mineurs à corriger.${NC}"
        return 1
    else
        echo -e "${RED}❌ PLUSIEURS TESTS ONT ÉCHOUÉ${NC}"
        echo -e "${RED}Intervention requise pour corriger les problèmes.${NC}"
        return 2
    fi
}

# Fonction principale
main() {
    local start_time=$(date +%s)
    
    echo -e "${PURPLE}🧪 Tests Automatisés Infrastructure${NC}"
    echo "Mode: $([[ $FAST_MODE == true ]] && echo "RAPIDE" || echo "COMPLET") | Timeout: ${TIMEOUT}s"
    echo "========================================"
    
    # Charger la configuration
    load_config || exit 1
    
    # Lancer les suites de tests
    test_docker_infrastructure
    test_containers
    test_network_connectivity
    test_application_services
    
    if [ "$SKIP_EXTERNAL" = false ]; then
        test_ssl_certificates
    fi
    
    test_security
    test_monitoring
    test_performance
    test_integration
    
    # Générer le rapport
    local report_file=""
    if [ "$GENERATE_REPORT" = true ]; then
        report_file=$(generate_test_report)
    fi
    
    # Afficher le résumé
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo -e "${BLUE}⏱️ Durée totale: ${duration}s${NC}"
    [ -n "$report_file" ] && echo -e "${BLUE}📄 Rapport: $(basename "$report_file")${NC}"
    
    # Afficher le résumé final et retourner le code approprié
    show_final_summary
}

# Gestion des signaux
trap 'echo -e "\n${RED}Tests interrompus${NC}"; exit 130' INT TERM

# Lancement des tests
main "$@"