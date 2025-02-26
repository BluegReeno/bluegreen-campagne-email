-- Schéma simplifié pour le système de tracking des campagnes email BlueGreen
-- Version: 1.0.0
-- Inspiré par l'approche de Mailmeteor

-- Table des campagnes
CREATE TABLE campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT,
  status TEXT DEFAULT 'draft', -- draft, active, completed
  notion_campaign_id TEXT -- ID de la campagne dans Notion
);

-- Table principale pour les emails (similaire à une feuille Google Sheets)
CREATE TABLE emails (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
  
  -- Informations sur le destinataire (colonnes de base)
  email TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  company TEXT,
  
  -- Champs Notion
  notion_contact_id TEXT,
  notion_company_id TEXT,
  
  -- Données de séquence
  sequence_step INTEGER DEFAULT 0, -- 0=principal, 1=relance1, 2=relance2
  
  -- Statut d'envoi (similaire à "Merge status" de Mailmeteor)
  status TEXT DEFAULT 'pending', -- pending, sent, error, bounced
  
  -- Données de tracking
  is_opened BOOLEAN DEFAULT FALSE,
  opened_at TIMESTAMPTZ,
  opened_count INTEGER DEFAULT 0,
  
  is_clicked BOOLEAN DEFAULT FALSE,
  clicked_at TIMESTAMPTZ,
  clicked_count INTEGER DEFAULT 0,
  clicked_links TEXT[],
  
  has_replied BOOLEAN DEFAULT FALSE,
  replied_at TIMESTAMPTZ,
  
  -- Métadonnées d'envoi
  sent_at TIMESTAMPTZ,
  scheduled_at TIMESTAMPTZ,
  tracking_id TEXT UNIQUE, -- Identifiant unique pour le tracking
  message_id TEXT, -- ID de l'email fourni par Gmail
  gmail_thread_id TEXT, -- ID du thread Gmail
  
  -- Champs personnalisés (peuvent être étendus selon les besoins)
  custom_fields JSONB DEFAULT '{}'
);

-- Table détaillée des événements (pour une analyse plus fine)
CREATE TABLE email_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email_id UUID REFERENCES emails(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- 'open', 'click', 'reply'
  occurred_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Métadonnées de l'événement
  ip_address TEXT,
  user_agent TEXT,
  link_clicked TEXT, -- Si event_type = 'click'
  metadata JSONB DEFAULT '{}'
);

-- Vues pour les statistiques de campagne
CREATE VIEW campaign_stats AS
SELECT 
  c.id,
  c.name,
  COUNT(e.id) AS emails_count,
  COUNT(CASE WHEN e.status = 'sent' THEN 1 END) AS sent_count,
  COUNT(CASE WHEN e.is_opened THEN 1 END) AS opened_count,
  ROUND((COUNT(CASE WHEN e.is_opened THEN 1 END)::NUMERIC / NULLIF(COUNT(CASE WHEN e.status = 'sent' THEN 1 END), 0) * 100), 2) AS open_rate,
  COUNT(CASE WHEN e.is_clicked THEN 1 END) AS clicked_count,
  ROUND((COUNT(CASE WHEN e.is_clicked THEN 1 END)::NUMERIC / NULLIF(COUNT(CASE WHEN e.status = 'sent' THEN 1 END), 0) * 100), 2) AS click_rate,
  COUNT(CASE WHEN e.has_replied THEN 1 END) AS replied_count,
  ROUND((COUNT(CASE WHEN e.has_replied THEN 1 END)::NUMERIC / NULLIF(COUNT(CASE WHEN e.status = 'sent' THEN 1 END), 0) * 100), 2) AS reply_rate
FROM campaigns c
LEFT JOIN emails e ON e.campaign_id = c.id
GROUP BY c.id, c.name;

-- Vue des séquences pour chaque campagne
CREATE VIEW sequence_stats AS
SELECT 
  c.id AS campaign_id,
  c.name AS campaign_name,
  e.sequence_step,
  COUNT(e.id) AS emails_count,
  COUNT(CASE WHEN e.status = 'sent' THEN 1 END) AS sent_count,
  COUNT(CASE WHEN e.is_opened THEN 1 END) AS opened_count,
  ROUND((COUNT(CASE WHEN e.is_opened THEN 1 END)::NUMERIC / NULLIF(COUNT(CASE WHEN e.status = 'sent' THEN 1 END), 0) * 100), 2) AS open_rate,
  COUNT(CASE WHEN e.is_clicked THEN 1 END) AS clicked_count,
  ROUND((COUNT(CASE WHEN e.is_clicked THEN 1 END)::NUMERIC / NULLIF(COUNT(CASE WHEN e.status = 'sent' THEN 1 END), 0) * 100), 2) AS click_rate,
  COUNT(CASE WHEN e.has_replied THEN 1 END) AS replied_count,
  ROUND((COUNT(CASE WHEN e.has_replied THEN 1 END)::NUMERIC / NULLIF(COUNT(CASE WHEN e.status = 'sent' THEN 1 END), 0) * 100), 2) AS reply_rate
FROM campaigns c
LEFT JOIN emails e ON e.campaign_id = c.id
GROUP BY c.id, c.name, e.sequence_step
ORDER BY c.id, e.sequence_step;

-- Fonction pour mettre à jour les statistiques d'email lors d'un événement
CREATE OR REPLACE FUNCTION update_email_stats()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.event_type = 'open' THEN
    UPDATE emails
    SET is_opened = TRUE,
        opened_at = COALESCE(opened_at, NEW.occurred_at),
        opened_count = opened_count + 1
    WHERE id = NEW.email_id;
  ELSIF NEW.event_type = 'click' THEN
    UPDATE emails
    SET is_clicked = TRUE,
        clicked_at = COALESCE(clicked_at, NEW.occurred_at),
        clicked_count = clicked_count + 1,
        clicked_links = array_append(clicked_links, NEW.link_clicked)
    WHERE id = NEW.email_id;
  ELSIF NEW.event_type = 'reply' THEN
    UPDATE emails
    SET has_replied = TRUE,
        replied_at = COALESCE(replied_at, NEW.occurred_at)
    WHERE id = NEW.email_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour mettre à jour automatiquement les statistiques
CREATE TRIGGER trigger_update_email_stats
AFTER INSERT ON email_events
FOR EACH ROW
EXECUTE FUNCTION update_email_stats();

-- Indexes pour optimiser les performances
CREATE INDEX idx_emails_campaign_id ON emails(campaign_id);
CREATE INDEX idx_emails_tracking_id ON emails(tracking_id);
CREATE INDEX idx_email_events_email_id ON email_events(email_id);
CREATE INDEX idx_email_events_type ON email_events(event_type);
