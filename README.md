# BlueGreen Campagne Email

Système automatisé de tracking et de gestion des campagnes email pour BlueGreen, utilisant n8n, Supabase et Notion.

## 📋 Présentation

Ce projet a pour objectif d'automatiser les campagnes email de BlueGreen tout en fournissant des métriques précises sur leur performance. Il permet de :

- Envoyer des emails personnalisés depuis Gmail
- Programmer des séquences avec des relances automatiques
- Suivre les taux d'ouverture et de clic
- Synchroniser les résultats avec la base CRM Notion existante

## 🏗️ Architecture

Le système s'appuie sur trois composants principaux :

1. **Supabase** : Base de données et backend pour le tracking des emails
2. **n8n** (hébergé sur Elestio) : Orchestration des workflows d'automatisation
3. **Notion** : Interface utilisateur et stockage des données CRM

![Schéma d'architecture](https://via.placeholder.com/800x400?text=Architecture+BlueGreen+Email)

## 🔧 Composants techniques

### Supabase (Base de données)

- Table `campaigns` : Informations sur les campagnes
- Table `emails` : Suivi des emails envoyés
- Table `email_events` : Événements de tracking (ouvertures, clics)
- Fonctions Edge pour le tracking des pixels et redirections

### Workflows n8n (5)

1. **Workflow d'envoi initial** : Envoie le premier email d'une campagne
2. **Workflow de gestion des relances** : Envoie les relances automatiques après un délai configuré
3. **Workflow de capture d'événements** : Traite les données de tracking
4. **Workflow de synchronisation des statistiques** : Met à jour les métriques dans Notion
5. **Workflow de tableau de bord** : Génère des rapports de performance

### Structure Notion

- Base "Campagnes Marketing" : Configuration des campagnes et séquences
- Base "Statistiques de Campagnes" : Métriques de performance

## 🚀 Installation et configuration

### Prérequis

- Compte Supabase (version gratuite suffisante pour commencer)
- Instance n8n fonctionnelle (déjà en place sur Elestio)
- Base Notion CRM existante
- Compte Gmail pour l'envoi des emails

### Étapes d'installation

1. **Configuration Supabase**
   - Créer un nouveau projet
   - Importer les schémas de base de données
   - Déployer les fonctions Edge

2. **Configuration n8n**
   - Établir les connexions avec Supabase, Notion et Gmail
   - Importer les workflows

3. **Configuration Notion**
   - Ajouter les champs nécessaires à la base "Campagnes Marketing"
   - Créer la base "Statistiques de Campagnes"

Pour les instructions détaillées, voir [INSTALLATION.md](INSTALLATION.md)

## 📊 Suivi des performances

Le système permet de suivre plusieurs métriques clés :

- Taux d'ouverture par campagne et par étape de séquence
- Taux de clic par campagne et par étape de séquence
- Performances comparées des différentes campagnes
- Engagement des contacts au fil du temps

Ces métriques sont visualisables directement dans Notion.

## 🛠️ Maintenance et évolution

### Sauvegarde

Les données critiques sont stockées dans :
- Supabase (événements bruts)
- Notion (configuration et résultats agrégés)

### Évolutions possibles

- Intégration d'un système A/B testing
- Segmentation avancée des contacts
- Interface dédiée pour la création de templates d'email

## 📝 Licence

Ce projet est la propriété exclusive de BlueGreen AI.

## 👥 Contact

Pour toute question ou suggestion concernant ce projet, contactez l'équipe technique de BlueGreen.