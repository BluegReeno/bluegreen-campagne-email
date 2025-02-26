-- Schéma optimisé pour le système de tracking des campagnes email BlueGreen
-- Version: 1.0.0
-- Basé sur l'exemple de données fourni

-- Table des campagnes
CREATE TABLE campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT,
  status TEXT DEFAULT 'draft', -- draft, active, completed
  notion_campaign_id TEXT UNIQUE -- ID de la campagne dans Notion
);

-- Table des destinataires/contacts (similaire à un Google Sheet)
CREATE TABLE recipients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
  
  -- Données de contact (comme dans votre exemple)
  first_name TEXT,
  last_name TEXT,
  company TEXT,
  email TEXT NOT NULL,
  question TEXT, -- La question/personnalisation (ex: "N'attendez")
  
  -- Données Notion
  notion_contact_id TEXT,
  notion_company_id TEXT,
  
  -- Statut de l'email (exactement comme dans votre exemple)
  campaign_status TEXT DEFAULT 'PENDING', -- PENDING, EMAIL_SENT, EMAIL_OPENED, EMAIL_CLICKED
  
  -- Données techniques pour le tracking
  tracking_id TEXT UNIQUE,
  sequence_step INTEGER DEFAULT 0, -- 0=principal, 1=relance1, 2=relance2
  
  -- Horodatages des événements
  sent_at TIMESTAMPTZ,
  opened_at TIMESTAMPTZ,
  clicked_at TIMESTAMPTZ,
  
  -- Données techniques pour Gmail
  message_id TEXT,
  gmail_thread_id TEXT,
  
  -- Données supplémentaires
  custom_fields JSONB DEFAULT '{}'
);

-- Table des événements de tracking (pour analyse détaillée)
CREATE TABLE tracking_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipient_id UUID REFERENCES recipients(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- 'send', 'open', 'click'
  occurred_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Métadonnées de l'événement
  ip_address TEXT,
  user_agent TEXT,
  link_clicked TEXT, -- Si event_type = 'click'
  metadata JSONB DEFAULT '{}'
);

-- Vue pour les statistiques de campagne
CREATE VIEW campaign_stats AS
SELECT 
  c.id,
  c.name,
  COUNT(r.id) AS total_recipients,
  COUNT(CASE WHEN r.campaign_status = 'EMAIL_SENT' THEN 1 END) AS sent_count,
  COUNT(CASE WHEN r.campaign_status = 'EMAIL_OPENED' THEN 1 END) AS opened_count,
  COUNT(CASE WHEN r.campaign_status = 'EMAIL_CLICKED' THEN 1 END) AS clicked_count,
  
  -- Calcul des taux
  ROUND((COUNT(CASE WHEN r.campaign_status IN ('EMAIL_SENT', 'EMAIL_OPENED', 'EMAIL_CLICKED') THEN 1 END)::NUMERIC / 
         NULLIF(COUNT(r.id), 0) * 100), 2) AS delivery_rate,
  
  ROUND((COUNT(CASE WHEN r.campaign_status IN ('EMAIL_OPENED', 'EMAIL_CLICKED') THEN 1 END)::NUMERIC / 
         NULLIF(COUNT(CASE WHEN r.campaign_status IN ('EMAIL_SENT', 'EMAIL_OPENED', 'EMAIL_CLICKED') THEN 1 END), 0) * 100), 2) AS open_rate,
  
  ROUND((COUNT(CASE WHEN r.campaign_status = 'EMAIL_CLICKED' THEN 1 END)::NUMERIC / 
         NULLIF(COUNT(CASE WHEN r.campaign_status IN ('EMAIL_OPENED', 'EMAIL_CLICKED') THEN 1 END), 0) * 100), 2) AS click_to_open_rate
FROM campaigns c
LEFT JOIN recipients r ON r.campaign_id = c.id
GROUP BY c.id, c.name;

-- Vue pour les statistiques par étape de séquence
CREATE VIEW sequence_stats AS
SELECT 
  c.id AS campaign_id,
  c.name AS campaign_name,
  r.sequence_step,
  COUNT(r.id) AS total_recipients,
  COUNT(CASE WHEN r.campaign_status = 'EMAIL_SENT' THEN 1 END) AS sent_count,
  COUNT(CASE WHEN r.campaign_status = 'EMAIL_OPENED' THEN 1 END) AS opened_count,
  COUNT(CASE WHEN r.campaign_status = 'EMAIL_CLICKED' THEN 1 END) AS clicked_count,
  
  -- Calcul des taux
  ROUND((COUNT(CASE WHEN r.campaign_status IN ('EMAIL_SENT', 'EMAIL_OPENED', 'EMAIL_CLICKED') THEN 1 END)::NUMERIC / 
         NULLIF(COUNT(r.id), 0) * 100), 2) AS delivery_rate,
  
  ROUND((COUNT(CASE WHEN r.campaign_status IN ('EMAIL_OPENED', 'EMAIL_CLICKED') THEN 1 END)::NUMERIC / 
         NULLIF(COUNT(CASE WHEN r.campaign_status IN ('EMAIL_SENT', 'EMAIL_OPENED', 'EMAIL_CLICKED') THEN 1 END), 0) * 100), 2) AS open_rate,
  
  ROUND((COUNT(CASE WHEN r.campaign_status = 'EMAIL_CLICKED' THEN 1 END)::NUMERIC / 
         NULLIF(COUNT(CASE WHEN r.campaign_status IN ('EMAIL_OPENED', 'EMAIL_CLICKED') THEN 1 END), 0) * 100), 2) AS click_to_open_rate
FROM campaigns c
LEFT JOIN recipients r ON r.campaign_id = c.id
GROUP BY c.id, c.name, r.sequence_step
ORDER BY c.id, r.sequence_step;

-- Fonction pour mettre à jour le statut d'un destinataire en fonction d'un événement
CREATE OR REPLACE FUNCTION update_recipient_status()
RETURNS TRIGGER AS $$
BEGIN
  -- Mise à jour du statut en fonction du type d'événement
  IF NEW.event_type = 'send' THEN
    UPDATE recipients
    SET campaign_status = 'EMAIL_SENT',
        sent_at = NEW.occurred_at
    WHERE id = NEW.recipient_id AND (campaign_status IS NULL OR campaign_status = 'PENDING');
    
  ELSIF NEW.event_type = 'open' THEN
    UPDATE recipients
    SET campaign_status = 
          CASE 
            WHEN campaign_status = 'EMAIL_CLICKED' THEN 'EMAIL_CLICKED' -- Conserver le statut click si déjà cliqué
            ELSE 'EMAIL_OPENED'
          END,
        opened_at = COALESCE(opened_at, NEW.occurred_at)
    WHERE id = NEW.recipient_id AND campaign_status != 'PENDING';
    
  ELSIF NEW.event_type = 'click' THEN
    UPDATE recipients
    SET campaign_status = 'EMAIL_CLICKED',
        clicked_at = COALESCE(clicked_at, NEW.occurred_at)
    WHERE id = NEW.recipient_id AND campaign_status != 'PENDING';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour mettre à jour automatiquement le statut des destinataires
CREATE TRIGGER trigger_update_recipient_status
AFTER INSERT ON tracking_events
FOR EACH ROW
EXECUTE FUNCTION update_recipient_status();

-- Indexes pour optimiser les performances
CREATE INDEX idx_recipients_campaign_id ON recipients(campaign_id);
CREATE INDEX idx_recipients_tracking_id ON recipients(tracking_id);
CREATE INDEX idx_recipients_status ON recipients(campaign_status);
CREATE INDEX idx_tracking_events_recipient_id ON tracking_events(recipient_id);
CREATE INDEX idx_tracking_events_type ON tracking_events(event_type);
