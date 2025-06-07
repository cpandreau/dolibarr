# =================================================================
# DOLIBARR DOCKER - MAKEFILE
# =================================================================

.PHONY: help setup start stop restart logs status backup restore update clean

# Variables
DOCKER_COMPOSE = docker-compose
PROJECT_NAME = dolibarr

# Aide
help: ## Affiche cette aide
	@echo "Commandes disponibles pour Dolibarr Docker :"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""

# Installation et configuration
setup: ## Installation complète avec configuration
	@echo "🚀 Installation de Dolibarr..."
	@chmod +x setup.sh
	@./setup.sh

# Gestion des services
start: ## Démarre les services
	@echo "▶️  Démarrage de Dolibarr..."
	@$(DOCKER_COMPOSE) up -d
	@echo "✅ Services démarrés"

stop: ## Arrête les services
	@echo "⏹️  Arrêt de Dolibarr..."
	@$(DOCKER_COMPOSE) down
	@echo "✅ Services arrêtés"

restart: ## Redémarre les services
	@echo "🔄 Redémarrage de Dolibarr..."
	@$(DOCKER_COMPOSE) restart
	@echo "✅ Services redémarrés"

# Monitoring
logs: ## Affiche les logs en temps réel
	@$(DOCKER_COMPOSE) logs -f

status: ## Affiche le statut des conteneurs
	@$(DOCKER_COMPOSE) ps

health: ## Vérifie la santé des services
	@echo "🏥 Vérification de la santé des services..."
	@$(DOCKER_COMPOSE) ps
	@echo ""
	@curl -f http://localhost:8080/ > /dev/null 2>&1 && echo "✅ Dolibarr est accessible" || echo "❌ Dolibarr n'est pas accessible"

# Maintenance
backup: ## Crée une sauvegarde des données
	@echo "💾 Création d'une sauvegarde..."
	@mkdir -p backups
	@DATE=$$(date +%Y%m%d_%H%M%S) && \
	tar -czf "backups/backup_dolibarr_$$DATE.tar.gz" data/ && \
	echo "✅ Sauvegarde créée : backups/backup_dolibarr_$$DATE.tar.gz"

restore: ## Restaure à partir d'une sauvegarde (usage: make restore BACKUP=fichier.tar.gz)
	@if [ -z "$(BACKUP)" ]; then \
		echo "❌ Spécifiez le fichier de sauvegarde : make restore BACKUP=backup_file.tar.gz"; \
		exit 1; \
	fi
	@echo "🔄 Restauration de la sauvegarde $(BACKUP)..."
	@$(DOCKER_COMPOSE) down
	@rm -rf data/
	@tar -xzf "$(BACKUP)"
	@$(DOCKER_COMPOSE) up -d
	@echo "✅ Restauration terminée"

update: ## Met à jour Dolibarr vers la dernière version
	@echo "🔄 Mise à jour de Dolibarr..."
	@echo "1. Création d'une sauvegarde..."
	@make backup
	@echo "2. Suppression du verrou d'installation..."
	@$(DOCKER_COMPOSE) exec dolibarr rm -f /var/www/documents/install.lock || true
	@echo "3. Téléchargement de la nouvelle image..."
	@$(DOCKER_COMPOSE) pull
	@echo "4. Redémarrage des services..."
	@$(DOCKER_COMPOSE) up -d
	@echo "✅ Mise à jour terminée. Visitez http://localhost:8080/install pour finaliser"

# Utilitaires
shell: ## Ouvre un shell dans le conteneur Dolibarr
	@$(DOCKER_COMPOSE) exec dolibarr bash

config: ## Affiche la configuration active
	@echo "📋 Configuration Docker Compose :"
	@$(DOCKER_COMPOSE) config

env-check: ## Vérifie les variables d'environnement
	@echo "🔍 Vérification du fichier .env..."
	@if [ ! -f .env ]; then \
		echo "❌ Fichier .env manquant !"; \
		exit 1; \
	fi
	@echo "✅ Fichier .env présent"
	@echo ""
	@echo "Variables critiques :"
	@grep -E "^(DOLI_DB_PASSWORD|DOLI_ADMIN_PASSWORD|DOLI_URL_ROOT)" .env | sed 's/=.*/=***/' || echo "⚠️  Variables manquantes"

# Nettoyage
clean: ## Nettoie les ressources Docker inutilisées
	@echo "🧹 Nettoyage des ressources Docker..."
	@docker system prune -f
	@echo "✅ Nettoyage terminé"

clean-all: ## Nettoie tout (ATTENTION: supprime les données)
	@echo "⚠️  ATTENTION: Cette commande va supprimer TOUTES les données !"
	@read -p "Êtes-vous sûr ? (tapez 'yes' pour confirmer): " confirm && [ "$$confirm" = "yes" ] || exit 1
	@$(DOCKER_COMPOSE) down -v
	@docker system prune -af
	@rm -rf data/
	@echo "✅ Nettoyage complet terminé"

# Développement
dev-logs: ## Affiche les logs détaillés
	@$(DOCKER_COMPOSE) logs --tail=100 -f

dev-reset: ## Remet à zéro l'installation (développement)
	@echo "🔄 Remise à zéro de l'installation..."
	@$(DOCKER_COMPOSE) exec dolibarr rm -f /var/www/documents/install.lock || true
	@$(DOCKER_COMPOSE) restart
	@echo "✅ Installation remise à zéro. Visitez http://localhost:8080"

# Monitoring avancé
monitor: ## Lance un monitoring simple
	@echo "📊 Monitoring des ressources..."
	@watch -n 2 'docker stats --no-stream && echo "" && docker-compose ps'

# Tests
test: ## Lance des tests de base
	@echo "🧪 Tests de base..."
	@curl -f http://localhost:8080/ > /dev/null 2>&1 && echo "✅ Application accessible" || echo "❌ Application inaccessible"
	@$(DOCKER_COMPOSE) exec dolibarr php -v > /dev/null 2>&1 && echo "✅ PHP fonctionne" || echo "❌ PHP ne fonctionne pas"