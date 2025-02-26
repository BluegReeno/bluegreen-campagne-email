# Fonctions Edge Supabase

Ce répertoire contient les fonctions Edge Supabase nécessaires au tracking des emails.

## Liste des fonctions

1. **track-pixel.js** - Fonction pour le tracking des ouvertures d'emails
   - Retourne un pixel transparent 1x1
   - Enregistre un événement d'ouverture dans la base de données

2. **track-link.js** - Fonction pour le tracking des clics sur les liens
   - Redirige vers l'URL de destination
   - Enregistre un événement de clic dans la base de données

## Installation

Pour déployer ces fonctions sur votre projet Supabase :

1. Accédez à la section "Edge Functions" dans le dashboard Supabase
2. Créez une nouvelle fonction pour chaque fichier .js
3. Copiez-collez le code correspondant
4. Déployez la fonction

## Utilisation

### Pixel de tracking

Pour intégrer le pixel de tracking dans vos emails :

```html
<img src="https://[votre-projet].supabase.co/functions/v1/track-pixel?tid=[tracking_id]" width="1" height="1" alt="" style="display:none">
```

### Liens trackés

Pour créer un lien tracké :

```html
<a href="https://[votre-projet].supabase.co/functions/v1/track-link?tid=[tracking_id]&url=[url_encodée]">Votre texte</a>
```

## Adaptation pour le format Mailmeteor

Les fonctions ont été optimisées pour utiliser le nouveau schéma de base de données qui suit le format Mailmeteor avec les statuts :

- PENDING
- EMAIL_SENT
- EMAIL_OPENED
- EMAIL_CLICKED

Les fonctions mettent automatiquement à jour ces statuts dans la table `recipients`.
