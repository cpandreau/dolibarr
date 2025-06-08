#!/bin/bash

# =================================================================
# SCRIPT DE SAUVEGARDE AUTOMATISÉE AVANCÉE
# =================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"
CLOUD_BACKUP_DIR="${CLOUD_BACKUP_PATH:-}"
LOG_FILE="${PROJECT_DIR}/logs/backup.log"
CONFIG_FILE="${PROJECT_DIR}/.env"

# Configuration par défaut
DEFAULT_RETENTION_DAYS=30
DEFAULT_CLOUD_RETENTION_DAYS=90
DEFAULT_BACKUP_TYPE="full"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
SCRIPT DE SAUVEGARDE AUTOMATISÉE

Usage: $0 [OPTIONS]

Options:
    -t, --type TYPE         Type de sauvegarde (full|data|config|n8n|db)
    -r, --retention DAYS    Rétention locale en jours (défaut: 30)
    -c, --cloud             Envoyer vers le cloud
    -n, --no-compress       Ne pas compresser
    -s, --silent            Mode silencieux
    -e, --encrypt           Chiffrer la sauvegarde
    -h, --help             Afficher cette aide

Types de sauvegarde:
    full        Sauvegarde complète (défaut)
    data        Données applicatives uniquement
    config      Configuration uniquement
    n8n         Workflows n8n uniquement
    db          Métadonnées base de données
    logs        Logs récents

Exemples:
    $0                      # Sauvegarde complète standard
    $0 -t data -c           # Sauvegarde données + cloud
    $0 -t n8n -e            # Sauvegarde n8n chiffrée
    $0 -r 7 -s              # Rétention 7 jours, silencieux

EOF
}

# Parse des arguments
BACKUP_TYPE="$DEFAULT_BACKUP_TYPE"
RETENTION_DAYS="$DEFAULT_RETENTION_DAYS"
CLOUD_UPLOAD=false
COMPRESS=true
SILENT=false
ENCRYPT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -c|--cloud)
            CLOUD_UPLOAD=true
            shift
            ;;
        -n|--no-compress)
            COMPRESS=false
            shift
            ;;
        -s|--silent)
            SILENT=true
            shift
            ;;
        -e|--encrypt)
            ENCRYPT=true
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

# Vérifications préalables
check_prerequisites() {
    log "Vérification des prérequis..."
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker non installé"
        exit 1
    fi
    
    # Vérifier docker-compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose non installé"
        exit 1
    fi
    
    # Créer les répertoires nécessaires
    mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")"
    
    # Vérifier l'espace disque
    AVAILABLE_SPACE=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    REQUIRED_SPACE=1048576  # 1GB en KB
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        log_warning "Espace disque faible: ${AVAILABLE_SPACE}KB disponible"
    fi
    
    log_success "Prérequis vérifiés"
}

# Fonction de sauvegarde des données
backup_data() {
    log "Sauvegarde des données applicatives..."
    
    local backup_items=""
    
    case $BACKUP_TYPE in
        "full")
            backup_items="data/ traefik-data/ traefik-config/ n8n-logs/ .env docker-compose*.yml"
            ;;
        "data")
            backup_items="data/ traefik-data/"
            ;;
        "config")
            backup_items="traefik-config/ monitoring-config/ .env docker-compose*.yml"
            ;;
        "n8n")
            backup_items="n8n-logs/"
            # Export spécial des workflows n8n
            if docker ps | grep -q "n8n.*Up"; then
                log "Export des workflows n8n..."
                docker exec n8n n8n export:workflow --all --output=/tmp/workflows.json 2>/dev/null || log_warning "Impossible d'exporter les workflows"
                docker cp "$(docker ps -q -f name=n8n):/tmp/workflows.json" "$BACKUP_DIR/n8n-workflows-$(date +%Y%m%d_%H%M%S).json" 2>/dev/null || true
            fi
            ;;
        "db")
            # Sauvegarde des métadonnées de configuration DB
            if [ -f "$CONFIG_FILE" ]; then
                grep -E "^(DOLI_DB_|N8N_DB_|REDIS_|GRAFANA_DB_)" "$CONFIG_FILE" > "$BACKUP_DIR/db_config_$(date +%Y%m%d_%H%M%S).env" 2>/dev/null || true
            fi
            backup_items=".env"
            ;;
        "logs")
            backup_items="traefik-logs/ n8n-logs/ logs/"
            ;;
        *)
            log_error "Type de sauvegarde invalide: $BACKUP_TYPE"
            exit 1
            ;;
    esac
    
    # Nom du fichier de sauvegarde
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="backup_${BACKUP_TYPE}_${timestamp}"
    local backup_file="${BACKUP_DIR}/${backup_name}.tar"
    
    # Compression
    if [ "$COMPRESS" = true ]; then
        backup_file="${backup_file}.gz"
    fi
    
    # Création de l'archive
    log "Création de l'archive: $(basename "$backup_file")"
    
    cd "$PROJECT_DIR"
    
    if [ "$COMPRESS" = true ]; then
        tar -czf "$backup_file" $backup_items 2>/dev/null || {
            log_error "Échec de la création de l'archive"
            return 1
        }
    else
        tar -cf "$backup_file" $backup_items 2>/dev/null || {
            log_error "Échec de la création de l'archive"
            return 1
        }
    fi
    
    # Chiffrement si demandé
    if [ "$ENCRYPT" = true ]; then
        log "Chiffrement de la sauvegarde..."
        
        if command -v gpg &> /dev/null; then
            # Chiffrement avec GPG
            gpg --symmetric --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 --s2k-digest-algo SHA512 --s2k-count 65011712 --output "${backup_file}.gpg" "$backup_file"
            
            if [ $? -eq 0 ]; then
                rm "$backup_file"
                backup_file="${backup_file}.gpg"
                log_success "Sauvegarde chiffrée avec GPG"
            else
                log_warning "Échec du chiffrement GPG"
            fi
        elif command -v openssl &> /dev/null; then
            # Chiffrement avec OpenSSL
            openssl enc -aes-256-cbc -salt -in "$backup_file" -out "${backup_file}.enc" -pass pass:"${BACKUP_ENCRYPTION_KEY:-defaultkey}"
            
            if [ $? -eq 0 ]; then
                rm "$backup_file"
                backup_file="${backup_file}.enc"
                log_success "Sauvegarde chiffrée avec OpenSSL"
            else
                log_warning "Échec du chiffrement OpenSSL"
            fi
        else
            log_warning "Aucun outil de chiffrement disponible (gpg/openssl)"
        fi
    fi
    
    # Vérification de la sauvegarde
    if [ -f "$backup_file" ]; then
        local file_size=$(du -h "$backup_file" | cut -f1)
        log_success "Sauvegarde créée: $(basename "$backup_file") (${file_size})"
        
        # Sauvegarde vers le cloud si demandé
        if [ "$CLOUD_UPLOAD" = true ]; then
            upload_to_cloud "$backup_file"
        fi
        
        echo "$backup_file"  # Retourner le chemin pour utilisation ultérieure
    else
        log_error "Échec de la création de la sauvegarde"
        return 1
    fi
}

# Fonction d'upload vers le cloud
upload_to_cloud() {
    local backup_file="$1"
    
    log "Upload vers le cloud..."
    
    # Support de plusieurs fournisseurs cloud
    if [ -n "${AWS_S3_BUCKET:-}" ]; then
        upload_to_s3 "$backup_file"
    elif [ -n "${GOOGLE_CLOUD_BUCKET:-}" ]; then
        upload_to_gcs "$backup_file"
    elif [ -n "${AZURE_STORAGE_ACCOUNT:-}" ]; then
        upload_to_azure "$backup_file"
    elif [ -n "${FTP_HOST:-}" ]; then
        upload_to_ftp "$backup_file"
    elif [ -n "${RSYNC_HOST:-}" ]; then
        upload_to_rsync "$backup_file"
    else
        log_warning "Aucune configuration cloud trouvée"
        return 1
    fi
}

# Upload vers AWS S3
upload_to_s3() {
    local backup_file="$1"
    local filename=$(basename "$backup_file")
    
    if command -v aws &> /dev/null; then
        aws s3 cp "$backup_file" "s3://${AWS_S3_BUCKET}/backups/$filename" && \
        log_success "Upload S3 réussi: $filename" || \
        log_error "Échec upload S3"
    else
        log_warning "AWS CLI non installé"
    fi
}

# Upload vers Google Cloud Storage
upload_to_gcs() {
    local backup_file="$1"
    local filename=$(basename "$backup_file")
    
    if command -v gsutil &> /dev/null; then
        gsutil cp "$backup_file" "gs://${GOOGLE_CLOUD_BUCKET}/backups/$filename" && \
        log_success "Upload GCS réussi: $filename" || \
        log_error "Échec upload GCS"
    else
        log_warning "Google Cloud SDK non installé"
    fi
}

# Upload vers Azure Blob Storage
upload_to_azure() {
    local backup_file="$1"
    local filename=$(basename "$backup_file")
    
    if command -v az &> /dev/null; then
        az storage blob upload --file "$backup_file" --name "backups/$filename" --container-name backups --account-name "${AZURE_STORAGE_ACCOUNT}" && \
        log_success "Upload Azure réussi: $filename" || \
        log_error "Échec upload Azure"
    else
        log_warning "Azure CLI non installé"
    fi
}

# Upload vers FTP
upload_to_ftp() {
    local backup_file="$1"
    local filename=$(basename "$backup_file")
    
    if command -v ftp &> /dev/null; then
        ftp -n "${FTP_HOST}" << EOF
user ${FTP_USER} ${FTP_PASSWORD}
binary
cd ${FTP_PATH:-/backups}
put $backup_file $filename
quit
EOF
        log_success "Upload FTP réussi: $filename"
    else
        log_warning "Client FTP non installé"
    fi
}

# Upload via rsync
upload_to_rsync() {
    local backup_file="$1"
    local filename=$(basename "$backup_file")
    
    if command -v rsync &> /dev/null; then
        rsync -avz "$backup_file" "${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_PATH:-/backups}/$filename" && \
        log_success "Upload rsync réussi: $filename" || \
        log_error "Échec upload rsync"
    else
        log_warning "rsync non installé"
    fi
}

# Nettoyage des anciennes sauvegardes
cleanup_old_backups() {
    log "Nettoyage des anciennes sauvegardes (>${RETENTION_DAYS} jours)..."
    
    local deleted_count=0
    
    # Nettoyage local
    while IFS= read -r -d '' file; do
        rm "$file"
        deleted_count=$((deleted_count + 1))
        log "Supprimé: $(basename "$file")"
    done < <(find "$BACKUP_DIR" -name "backup_*.tar*" -type f -mtime +${RETENTION_DAYS} -print0)
    
    # Nettoyage cloud (si configuré)
    if [ "$CLOUD_UPLOAD" = true ] && [ -n "${CLOUD_RETENTION_DAYS:-}" ]; then
        cleanup_cloud_backups
    fi
    
    if [ $deleted_count -gt 0 ]; then
        log_success "Supprimé $deleted_count anciennes sauvegardes"
    else
        log "Aucune ancienne sauvegarde à supprimer"
    fi
}

# Nettoyage cloud
cleanup_cloud_backups() {
    log "Nettoyage des sauvegardes cloud (>${CLOUD_RETENTION_DAYS:-90} jours)..."
    
    # TODO: Implémenter le nettoyage pour chaque fournisseur cloud
    # Similaire aux fonctions d'upload mais avec suppression
}

# Vérification de l'intégrité
verify_backup() {
    local backup_file="$1"
    
    log "Vérification de l'intégrité: $(basename "$backup_file")"
    
    if [[ "$backup_file" == *.tar.gz ]]; then
        tar -tzf "$backup_file" >/dev/null 2>&1 && \
        log_success "Archive valide" || \
        log_error "Archive corrompue"
    elif [[ "$backup_file" == *.tar ]]; then
        tar -tf "$backup_file" >/dev/null 2>&1 && \
        log_success "Archive valide" || \
        log_error "Archive corrompue"
    fi
}

# Notification
send_notification() {
    local status="$1"
    local message="$2"
    
    # Slack
    if [ -n "${SLACK_WEBHOOK_BACKUP:-}" ]; then
        local color="good"
        [ "$status" != "success" ] && color="danger"
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🗄️ Backup Status: $message\", \"color\":\"$color\"}" \
            "${SLACK_WEBHOOK_BACKUP}" >/dev/null 2>&1
    fi
    
    # Email (si configuré)
    if [ -n "${BACKUP_EMAIL:-}" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "Backup Status: $status" "${BACKUP_EMAIL}"
    fi
    
    # Discord
    if [ -n "${DISCORD_WEBHOOK_BACKUP:-}" ]; then
        curl -H "Content-Type: application/json" \
            -d "{\"content\":\"🗄️ **Backup Status**: $message\"}" \
            "${DISCORD_WEBHOOK_BACKUP}" >/dev/null 2>&1
    fi
}

# Fonction principale
main() {
    local start_time=$(date +%s)
    
    if [ "$SILENT" = false ]; then
        echo "🗄️ Démarrage de la sauvegarde automatisée"
        echo "Type: $BACKUP_TYPE | Rétention: ${RETENTION_DAYS}j | Cloud: $CLOUD_UPLOAD"
        echo ""
    fi
    
    # Vérifications
    check_prerequisites
    
    # Sauvegarde
    local backup_file
    if backup_file=$(backup_data); then
        # Vérification
        verify_backup "$backup_file"
        
        # Nettoyage
        cleanup_old_backups
        
        # Calcul du temps d'exécution
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        local success_msg="Sauvegarde $BACKUP_TYPE réussie en ${duration}s: $(basename "$backup_file")"
        log_success "$success_msg"
        
        if [ "$SILENT" = false ]; then
            echo ""
            echo "✅ Sauvegarde terminée avec succès !"
            echo "   Fichier: $(basename "$backup_file")"
            echo "   Taille: $(du -h "$backup_file" | cut -f1)"
            echo "   Durée: ${duration}s"
        fi
        
        send_notification "success" "$success_msg"
    else
        local error_msg="Échec de la sauvegarde $BACKUP_TYPE"
        log_error "$error_msg"
        send_notification "error" "$error_msg"
        exit 1
    fi
}

# Gestion des signaux
trap 'log_error "Sauvegarde interrompue"; exit 1' INT TERM

# Lancement du script
main "$@"