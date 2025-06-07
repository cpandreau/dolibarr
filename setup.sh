#!/bin/bash

# =================================================================
# SCRIPT D'INSTALLATION DOLIBARR AVEC POSTGRESQL SUPABASE
# =================================================================

set -e

echo "🚀 Configuration de Dolibarr avec PostgreSQL Supabase..."

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage coloré
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

# Vérifications préalables
echo "🔍 Vérification des prérequis..."

if ! command -v docker &> /dev/null; then
    print_error "Docker n'est pas installé !"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose n'est pas installé !"
    exit 1
fi

print_status "Docker et Docker Compose sont disponibles"

# Création des répertoires de données
echo "📁 Création des répertoires de données..."

mkdir -p data/dolibarr_documents
mkdir -p data/dolibarr_custom
mkdir -p logs

print_status "Répertoires créés"

# Vérification du fichier .env
if [ ! -f ".env" ]; then
    print_error "Le fichier .env n'existe pas !"
    print_info "Copiez le fichier .env.example vers .env et configurez vos variables"
    exit 1
fi

# Vérification des variables critiques
print_warning "Vérifiez que vous avez configuré ces variables dans le .env :"
echo "  - DOLI_DB_PASSWORD (votre mot de passe Supabase)"
echo "  - DOLI_ADMIN_PASSWORD (mot de passe admin fort)"
echo "  - DOLI_INSTANCE_UNIQUE_ID (clé de 64 caractères)"
echo "  - DOLI_CRON_KEY (clé de sécurité cron)"
echo "  - DOLI_URL_ROOT (votre domaine)"

read -p "Avez-vous configuré toutes ces variables ? (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    print_warning "Configurez d'abord votre fichier .env"
    exit 1
fi

# Génération automatique de clés si nécessaire
if grep -q "CHANGEZ_MOI" .env; then
    print_warning "Génération automatique des clés de sécurité..."
    
    # Génération de DOLI_INSTANCE_UNIQUE_ID
    UNIQUE_ID=$(openssl rand -hex 32)
    sed -i "s/CHANGEZ_MOI_AVEC_UNE_CLE_SECURISEE_DE_64_CARACTERES/$UNIQUE_ID/g" .env
    
    print_status "Clé unique générée automatiquement"
fi

# Configuration des permissions
echo "🔐 Configuration des permissions..."
sudo chown -R 1000:1000 data/
chmod -R 755 data/

print_status "Permissions configurées"

# Démarrage des services
echo "🐳 Démarrage de Dolibarr..."

# Arrêt des conteneurs existants si ils existent
docker-compose down 2>/dev/null || true

# Téléchargement de l'image
print_info "Téléchargement de l'image Dolibarr..."
docker-compose pull

# Démarrage en arrière-plan
docker-compose up -d

print_status "Conteneurs démarrés"

# Attente que le service soit prêt
echo "⏳ Attente que Dolibarr soit prêt..."
sleep 10

# Vérification du statut
if docker-compose ps | grep -q "Up"; then
    print_status "Dolibarr est démarré !"
    
    # Récupération du port depuis .env
    PORT=$(grep DOLIBARR_PORT .env | cut -d'=' -f2)
    PORT=${PORT:-8080}
    
    echo ""
    print_info "🌐 Accès à votre installation Dolibarr :"
    echo "   URL: http://localhost:$PORT"
    echo ""
    print_info "📋 Informations de connexion :"
    ADMIN_LOGIN=$(grep DOLI_ADMIN_LOGIN .env | cut -d'=' -f2)
    echo "   Login: ${ADMIN_LOGIN:-admin_secure}"
    echo "   Mot de passe: (configuré dans le .env)"
    echo ""
    print_warning "🔒 IMPORTANT - Sécurité :"
    echo "   1. Changez immédiatement le mot de passe admin"
    echo "   2. Configurez un reverse proxy avec SSL/TLS"
    echo "   3. Limitez l'accès réseau si possible"
    echo "   4. Programmez des sauvegardes régulières"
    
else
    print_error "Erreur lors du démarrage !"
    echo "Consultez les logs avec: docker-compose logs"
    exit 1
fi

# Instructions post-installation pour PostgreSQL
echo ""
print_warning "📝 Note importante pour PostgreSQL :"
echo "   Comme vous utilisez PostgreSQL, la première installation"
echo "   doit être effectuée manuellement via l'interface web."
echo "   Suivez les instructions à l'écran lors de votre première connexion."

echo ""
print_status "🎉 Installation terminée avec succès !"