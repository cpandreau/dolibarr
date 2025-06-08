#!/bin/bash

# =================================================================
# CONFIGURATION AUTOMATIQUE DES TÂCHES CRON
# =================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CRON_FILE="/tmp/infrastructure_crontab"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🕐 Configuration des tâches automatisées (Crontab)${NC}"
echo ""

# Créer le fichier crontab
cat > "$CRON_FILE" << EOF
# =================================================================
# TÂCHES AUTOMATISÉES INFRASTRUCTURE COMPLÈTE
# Généré automatiquement le $(date)
# =================================================================

# Variables d'environnement
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=admin@votre-domaine.com

# =================================================================
# SAUVEGARDES AUTOMATIQUES
# =================================================================

# Sauvegarde quotidienne complète (2h du matin)
0 2 * * * cd $PROJECT_DIR && ./scripts/backup-automated.sh -t full -c -s >> $PROJECT_DIR/logs/cron.log 2>&1

# Sauvegarde rapide des données (toutes les 6h)
0 */6 * * * cd $PROJECT_DIR && ./scripts/backup-automated.sh -t data -s >> $PROJECT_DIR/logs/cron.log 2>&1

# Sauvegarde workflows n8n (quotidienne à 3h)
0 3 * * * cd $PROJECT_DIR && ./scripts/backup-automated.sh -t n8n -s >> $PROJECT_DIR/logs/cron.log 2>&1

# Nettoyage des anciennes sauvegardes (hebdomadaire, dimanche 4h)
0 4 * * 0 cd $PROJECT_DIR && find ./backups -name "backup_*.tar.gz" -mtime +30 -delete >> $PROJECT_DIR/logs/cron.log 2>&1

# =================================================================
# MAINTENANCE SYSTÈME
# =================================================================

# Maintenance complète (hebdomadaire, dimanche 1h du matin)
0 1 * * 0 cd $PROJECT_DIR && ./scripts/maintenance-system.sh -a >> $PROJECT_DIR/logs/cron.log 2>&1

# Nettoyage Docker (quotidien, 1h30)
30 1 * * * cd $PROJECT_DIR && ./scripts/maintenance-system.sh -d >> $PROJECT_DIR/logs/cron.log 2>&1

# Rotation des logs (quotidienne, 23h)
0 23 * * * cd $PROJECT_DIR && ./scripts/maintenance-system.sh -l >> $PROJECT_DIR/logs/cron.log 2>&1

# Audit de sécurité (quotidien, 4h)
0 4 * * * cd $PROJECT_DIR && ./scripts/maintenance-system.sh -s >> $PROJECT_DIR/logs/cron.log 2>&1

# =================================================================
# MONITORING ET ALERTES
# =================================================================

# Vérification des services (toutes les 5 minutes)
*/5 * * * * cd $PROJECT_DIR && make health > /dev/null 2>&1 || echo "$(date): Health check failed" >> $PROJECT_DIR/logs/cron.log

# Vérification des certificats SSL (quotidienne, 6h)
0 6 * * * cd $PROJECT_DIR && ./scripts/maintenance-system.sh -c >> $PROJECT_DIR/logs/cron.log 2>&1

# Test de connectivité réseau (toutes les heures)
0 * * * * cd $PROJECT_DIR && ./scripts/maintenance-system.sh -n -s >> $PROJECT_DIR/logs/cron.log 2>&1

# Vérification du monitoring (toutes les 15 minutes)
*/15 * * * * cd $PROJECT_DIR && ./scripts/maintenance-system.sh -m -s >> $PROJECT_DIR/logs/cron.log 2>&1

# =================================================================
# MISES À JOUR
# =================================================================

# Vérification des mises à jour (quotidienne, 5h)
0 5 * * * cd $PROJECT_DIR && ./scripts/maintenance-system.sh -u >> $PROJECT_DIR/logs/cron.log 2>&1

# Mise à jour automatique des images Docker (hebdomadaire, samedi 2h)
# ATTENTION: Décommentez seulement si vous voulez les mises à jour automatiques
# 0 2 * * 6 cd $PROJECT_DIR && make update >> $PROJECT_DIR/logs/cron.log 2>&1

# =================================================================
# RAPPORTS AUTOMATIQUES
# =================================================================

# Rapport hebdomadaire (lundi 8h)
0 8 * * 1 cd $PROJECT_DIR && ./scripts/generate-weekly-report.sh >> $PROJECT_DIR/logs/cron.log 2>&1

# Rapport mensuel (1er du mois, 9h)
0 9 1 * * cd $PROJECT_DIR && ./scripts/generate-monthly-report.sh >> $PROJECT_DIR/logs/cron.log 2>&1

# =================================================================
# NETTOYAGE ET OPTIMISATION
# =================================================================

# Nettoyage des logs de cron (mensuel)
0 0 1 * * echo "" > $PROJECT_DIR/logs/cron.log

# Optimisation base de données (hebdomadaire, dimanche 3h)
0 3 * * 0 cd $PROJECT_DIR && docker exec dolibarr mysql -u\$DOLI_DB_USER -p\$DOLI_DB_PASSWORD -e "OPTIMIZE TABLE llx_actioncomm, llx_facture, llx_commande;" > /dev/null 2>&1 || true

# Redémarrage programmé des services (optionnel, dimanche 5h)
# ATTENTION: Décommentez seulement si nécessaire
# 0 5 * * 0 cd $PROJECT_DIR && ./scripts/maintenance-system.sh -r >> $PROJECT_DIR/logs/cron.log 2>&1

# =================================================================
# TÂCHES N8N SPÉCIFIQUES
# =================================================================

# Export des workflows n8n (quotidien, minuit)
0 0 * * * cd $PROJECT_DIR && docker exec n8n n8n export:workflow --all --output=/tmp/workflows_$(date +%Y%m%d).json >> $PROJECT_DIR/logs/cron.log 2>&1 || true

# Nettoyage des exécutions n8n anciennes (quotidien, 2h30)
30 2 * * * cd $PROJECT_DIR && docker exec n8n n8n db:revert --to=30 >> $PROJECT_DIR/logs/cron.log 2>&1 || true

# =================================================================
# MONITORING CUSTOM
# =================================================================

# Surveillance de l'espace disque
0 */2 * * * DISK_USAGE=\$(df / | awk 'NR==2 {print \$5}' | sed 's/%//'); if [ \$DISK_USAGE -gt 85 ]; then echo "$(date): WARNING - Disk usage at \${DISK_USAGE}%" >> $PROJECT_DIR/logs/cron.log; fi

# Surveillance de la mémoire
*/10 * * * * MEMORY_USAGE=\$(free | awk 'NR==2{printf "%.0f", \$3/\$2*100}'); if [ \$MEMORY_USAGE -gt 90 ]; then echo "$(date): WARNING - Memory usage at \${MEMORY_USAGE}%" >> $PROJECT_DIR/logs/cron.log; fi

# Surveillance des conteneurs arrêtés
*/5 * * * * STOPPED_CONTAINERS=\$(docker ps -a --filter "status=exited" --format "{{.Names}}" | wc -l); if [ \$STOPPED_CONTAINERS -gt 0 ]; then echo "$(date): WARNING - \$STOPPED_CONTAINERS stopped containers" >> $PROJECT_DIR/logs/cron.log; fi

# =================================================================
# NOTES ET INFORMATIONS
# =================================================================
# 
# Format des tâches cron:
# ┌───────────── minute (0 - 59)
# │ ┌───────────── hour (0 - 23)
# │ │ ┌───────────── day of the month (1 - 31)
# │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ ┌───────────── day of the week (0 - 6) (Sunday to Saturday)
# │ │ │ │ │
# * * * * * command to execute
#
# Exemples utiles:
# */15 * * * *   → Toutes les 15 minutes
# 0 */2 * * *    → Toutes les 2 heures
# 0 2 * * 0      → Dimanche à 2h
# 0 0 1 * *      → 1er de chaque mois à minuit
#
# Variables utiles:
# @reboot        → Au démarrage
# @yearly        → Une fois par an (0 0 1 1 *)
# @monthly       → Une fois par mois (0 0 1 * *)
# @weekly        → Une fois par semaine (0 0 * * 0)
# @daily         → Une fois par jour (0 0 * * *)
# @hourly        → Une fois par heure (0 * * * *)

EOF

echo -e "${YELLOW}📋 Fichier crontab généré avec les tâches suivantes :${NC}"
echo ""
echo "🔄 Sauvegardes automatiques :"
echo "  • Sauvegarde complète quotidienne (2h)"
echo "  • Sauvegarde rapide toutes les 6h"
echo "  • Export workflows n8n quotidien"
echo ""
echo "🔧 Maintenance système :"
echo "  • Maintenance complète hebdomadaire"
echo "  • Nettoyage Docker quotidien"
echo "  • Rotation des logs quotidienne"
echo "  • Audit de sécurité quotidien"
echo ""
echo "📊 Monitoring :"
echo "  • Vérification services (5 min)"
echo "  • Contrôle certificats SSL quotidien"
echo "  • Tests réseau horaires"
echo "  • Surveillance ressources"
echo ""
echo "📈 Rapports :"
echo "  • Rapport hebdomadaire (lundi)"
echo "  • Rapport mensuel (1er du mois)"
echo ""

# Demander confirmation avant installation
echo -e "${BLUE}Options d'installation :${NC}"
echo "1) Installer pour l'utilisateur actuel"
echo "2) Installer pour root (système)"
echo "3) Sauvegarder seulement (pas d'installation)"
echo "4) Personnaliser avant installation"
echo ""

read -p "Choisissez une option (1-4): " INSTALL_OPTION

case $INSTALL_OPTION in
    1)
        echo -e "${BLUE}Installation du crontab utilisateur...${NC}"
        crontab "$CRON_FILE"
        echo -e "${GREEN}✅ Crontab installé pour l'utilisateur $(whoami)${NC}"
        ;;
    2)
        echo -e "${BLUE}Installation du crontab système (root)...${NC}"
        sudo crontab "$CRON_FILE"
        echo -e "${GREEN}✅ Crontab installé pour root${NC}"
        ;;
    3)
        mv "$CRON_FILE" "$PROJECT_DIR/crontab-backup"
        echo -e "${GREEN}✅ Crontab sauvegardé dans $PROJECT_DIR/crontab-backup${NC}"
        echo "Pour l'installer plus tard : crontab $PROJECT_DIR/crontab-backup"
        ;;
    4)
        echo -e "${BLUE}Ouverture de l'éditeur pour personnalisation...${NC}"
        ${EDITOR:-nano} "$CRON_FILE"
        echo ""
        echo "Fichier personnalisé. Voulez-vous l'installer maintenant ?"
        read -p "Installer maintenant ? (y/N): " INSTALL_NOW
        if [[ $INSTALL_NOW == [yY] ]]; then
            crontab "$CRON_FILE"
            echo -e "${GREEN}✅ Crontab personnalisé installé${NC}"
        else
            mv "$CRON_FILE" "$PROJECT_DIR/crontab-custom"
            echo -e "${GREEN}✅ Crontab personnalisé sauvegardé dans $PROJECT_DIR/crontab-custom${NC}"
        fi
        ;;
    *)
        echo -e "${YELLOW}⚠️  Installation annulée${NC}"
        mv "$CRON_FILE" "$PROJECT_DIR/crontab-draft"
        echo "Fichier disponible dans : $PROJECT_DIR/crontab-draft"
        ;;
esac

# Créer le répertoire des logs si inexistant
mkdir -p "$PROJECT_DIR/logs"

# Afficher les tâches installées
if command -v crontab >/dev/null 2>&1; then
    echo ""
    echo -e "${BLUE}📅 Tâches cron actuellement installées :${NC}"
    crontab -l | grep -E "^[^#]" | head -10 || echo "Aucune tâche active visible"
fi

echo ""
echo -e "${GREEN}🎯 Configuration terminée !${NC}"
echo ""
echo -e "${YELLOW}📝 Prochaines étapes :${NC}"
echo "1. Vérifiez les logs dans $PROJECT_DIR/logs/cron.log"
echo "2. Testez une tâche manuellement : cd $PROJECT_DIR && make health"
echo "3. Surveillez l'exécution des premières tâches"
echo "4. Ajustez MAILTO dans le crontab si nécessaire"
echo ""
echo -e "${YELLOW}⚙️  Commandes utiles :${NC}"
echo "• Voir les tâches : crontab -l"
echo "• Éditer les tâches : crontab -e"
echo "• Logs système cron : sudo tail -f /var/log/cron"
echo "• Logs application : tail -f $PROJECT_DIR/logs/cron.log"

# Nettoyage
rm -f "$CRON_FILE" 2>/dev/null || true

echo ""
echo -e "${GREEN}✨ Automatisation configurée avec succès ! ✨${NC}"