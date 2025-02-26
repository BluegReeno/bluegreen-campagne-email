# Workflows n8n

Ce répertoire contient les workflows n8n nécessaires au fonctionnement du système de suivi des campagnes email de BlueGreen.

## Liste des workflows

1. **email-campaign-sender.json** : Workflow d'envoi initial de campagne
2. **email-sequence-manager.json** : Workflow de gestion des relances
3. **tracking-event-handler.json** : Workflow de capture d'événements (ouvertures, clics)
4. **stats-sync.json** : Workflow de synchronisation des statistiques avec Notion
5. **reporting-dashboard.json** : Workflow de génération de rapports

## Prérequis

- Instance n8n hébergée (Elestio)
- Accès à l'API Notion
- Accès à l'API Supabase
- Authentification Gmail configurée

## Installation

Pour installer ces workflows :

1. Accédez à votre instance n8n
2. Importez chaque fichier JSON via le menu "Workflows"
3. Configurez les credentials pour Notion, Supabase et Gmail
4. Activez les workflows selon vos besoins
