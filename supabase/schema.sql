-- Schéma de base de données pour le système de tracking des campagnes email BlueGreen
-- Version: 1.0.0

-- Table des campagnes
CREATE TABLE campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id),
  status TEXT DEFAULT 'draft',
  notion_id TEXT UNIQUE,  -- ID de la campagne dans Notion
  tags TEXT[] DEFAULT '{}'
);

-- Table des séquences d'emails
CREATE TABLE email_sequences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
  sequence_name TEXT NOT NULL,
  sequence_step INTEGER NOT NULL, -- 0=principal, 1=relance1, 2=relance2
  delay_days INTEGER DEFAULT 0,  -- jours après l'étape précédente (0 pour l'email principal)
  subject TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table des contacts destinataires
CREATE TABLE contacts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT NOT NULL UNIQUE,
  first_name TEXT,
  last_name TEXT,
  notion_id TEXT,  -- ID du contact dans Notion
  company TEXT,
  company_notion_id TEXT,  -- ID de l'entreprise dans Notion
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table des emails envoyés
CREATE TABLE emails (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
  sequence_id UUID REFERENCES email_sequences(id) ON DELETE CASCADE,
  contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,
  sequence_step INTEGER NOT NULL, -- 0=principal, 1=relance1, 2=relance2
  tracking_id TEXT UNIQUE NOT NULL, -- Identifiant unique pour le tracking
  subject TEXT NOT NULL,
  sent_at TIMESTAMPTZ,
  status TEXT DEFAULT 'pending', -- pending, sent, bounced, etc.
  message_id TEXT, -- ID de l'email fourni par Gmail
  gmail_thread_id TEXT -- ID du thread Gmail
);

-- Table des événements de tracking
CREATE TABLE email_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email_id UUID REFERENCES emails(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- 'open', 'click', 'reply'
  occurred_at TIMESTAMPTZ DEFAULT NOW(),
  ip_address TEXT,
  user_agent TEXT,
  link_clicked TEXT, -- Si event_type = 'click'
  reply_content TEXT, -- Si event_type = 'reply'
  metadata JSONB DEFAULT '{}'
);

-- Table des statistiques agrégées par campagne
CREATE TABLE campaign_stats (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
  sequence_step INTEGER, -- NULL pour les stats globales de la campagne
  emails_sent INTEGER DEFAULT 0,
  emails_opened INTEGER DEFAULT 0,
  unique_opens INTEGER DEFAULT 0,
  emails_clicked INTEGER DEFAULT 0,
  unique_clicks INTEGER DEFAULT 0,
  replies INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes pour optimiser les performances
CREATE INDEX idx_emails_campaign_id ON emails(campaign_id);
CREATE INDEX idx_emails_contact_id ON emails(contact_id);
CREATE INDEX idx_emails_tracking_id ON emails(tracking_id);
CREATE INDEX idx_email_events_email_id ON email_events(email_id);
CREATE INDEX idx_email_events_type ON email_events(event_type);
CREATE INDEX idx_campaign_stats_campaign_id ON campaign_stats(campaign_id);

-- Vue pour obtenir les taux d'ouverture et de clic par campagne
CREATE VIEW campaign_performance AS
SELECT 
  c.id,
  c.title,
  c.notion_id,
  COUNT(DISTINCT e.id) AS emails_sent,
  COUNT(DISTINCT CASE WHEN eo.id IS NOT NULL THEN e.id END) AS emails_opened,
  ROUND((COUNT(DISTINCT CASE WHEN eo.id IS NOT NULL THEN e.id END)::NUMERIC / NULLIF(COUNT(DISTINCT e.id), 0) * 100), 2) AS open_rate,
  COUNT(DISTINCT CASE WHEN ec.id IS NOT NULL THEN e.id END) AS emails_clicked,
  ROUND((COUNT(DISTINCT CASE WHEN ec.id IS NOT NULL THEN e.id END)::NUMERIC / NULLIF(COUNT(DISTINCT e.id), 0) * 100), 2) AS click_rate,
  COUNT(DISTINCT CASE WHEN er.id IS NOT NULL THEN e.id END) AS emails_replied,
  ROUND((COUNT(DISTINCT CASE WHEN er.id IS NOT NULL THEN e.id END)::NUMERIC / NULLIF(COUNT(DISTINCT e.id), 0) * 100), 2) AS reply_rate
FROM campaigns c
LEFT JOIN emails e ON e.campaign_id = c.id AND e.status = 'sent'
LEFT JOIN email_events eo ON eo.email_id = e.id AND eo.event_type = 'open'
LEFT JOIN email_events ec ON ec.email_id = e.id AND ec.event_type = 'click'
LEFT JOIN email_events er ON er.email_id = e.id AND er.event_type = 'reply'
GROUP BY c.id, c.title, c.notion_id
ORDER BY c.created_at DESC;

-- Vue pour obtenir les statistiques par séquence
CREATE VIEW sequence_performance AS
SELECT 
  c.id AS campaign_id,
  c.title AS campaign_title,
  e.sequence_step,
  COUNT(DISTINCT e.id) AS emails_sent,
  COUNT(DISTINCT CASE WHEN eo.id IS NOT NULL THEN e.id END) AS emails_opened,
  ROUND((COUNT(DISTINCT CASE WHEN eo.id IS NOT NULL THEN e.id END)::NUMERIC / NULLIF(COUNT(DISTINCT e.id), 0) * 100), 2) AS open_rate,
  COUNT(DISTINCT CASE WHEN ec.id IS NOT NULL THEN e.id END) AS emails_clicked,
  ROUND((COUNT(DISTINCT CASE WHEN ec.id IS NOT NULL THEN e.id END)::NUMERIC / NULLIF(COUNT(DISTINCT e.id), 0) * 100), 2) AS click_rate,
  COUNT(DISTINCT CASE WHEN er.id IS NOT NULL THEN e.id END) AS emails_replied,
  ROUND((COUNT(DISTINCT CASE WHEN er.id IS NOT NULL THEN e.id END)::NUMERIC / NULLIF(COUNT(DISTINCT e.id), 0) * 100), 2) AS reply_rate
FROM campaigns c
LEFT JOIN emails e ON e.campaign_id = c.id AND e.status = 'sent'
LEFT JOIN email_events eo ON eo.email_id = e.id AND eo.event_type = 'open'
LEFT JOIN email_events ec ON ec.email_id = e.id AND ec.event_type = 'click'
LEFT JOIN email_events er ON er.email_id = e.id AND er.event_type = 'reply'
GROUP BY c.id, c.title, e.sequence_step
ORDER BY c.id, e.sequence_step;

-- Fonction pour mettre à jour les statistiques agrégées
CREATE OR REPLACE FUNCTION update_campaign_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Mise à jour des statistiques globales de la campagne
  INSERT INTO campaign_stats (campaign_id, sequence_step, emails_sent, emails_opened, unique_opens, emails_clicked, unique_clicks, replies)
  SELECT 
    e.campaign_id,
    NULL, -- Stats globales
    COUNT(DISTINCT e.id),
    COUNT(DISTINCT CASE WHEN eo.event_type = 'open' THEN eo.id END),
    COUNT(DISTINCT CASE WHEN eo.event_type = 'open' THEN e.id END),
    COUNT(DISTINCT CASE WHEN eo.event_type = 'click' THEN eo.id END),
    COUNT(DISTINCT CASE WHEN eo.event_type = 'click' THEN e.id END),
    COUNT(DISTINCT CASE WHEN eo.event_type = 'reply' THEN e.id END)
  FROM emails e
  LEFT JOIN email_events eo ON eo.email_id = e.id
  WHERE e.campaign_id = COALESCE(NEW.campaign_id, OLD.campaign_id)
  GROUP BY e.campaign_id
  ON CONFLICT (campaign_id) WHERE sequence_step IS NULL
  DO UPDATE SET
    emails_sent = EXCLUDED.emails_sent,
    emails_opened = EXCLUDED.emails_opened,
    unique_opens = EXCLUDED.unique_opens,
    emails_clicked = EXCLUDED.emails_clicked,
    unique_clicks = EXCLUDED.unique_clicks,
    replies = EXCLUDED.replies,
    updated_at = NOW();
    
  -- Mise à jour des statistiques par étape de séquence
  INSERT INTO campaign_stats (campaign_id, sequence_step, emails_sent, emails_opened, unique_opens, emails_clicked, unique_clicks, replies)
  SELECT 
    e.campaign_id,
    e.sequence_step,
    COUNT(DISTINCT e.id),
    COUNT(DISTINCT CASE WHEN eo.event_type = 'open' THEN eo.id END),
    COUNT(DISTINCT CASE WHEN eo.event_type = 'open' THEN e.id END),
    COUNT(DISTINCT CASE WHEN eo.event_type = 'click' THEN eo.id END),
    COUNT(DISTINCT CASE WHEN eo.event_type = 'click' THEN e.id END),
    COUNT(DISTINCT CASE WHEN eo.event_type = 'reply' THEN e.id END)
  FROM emails e
  LEFT JOIN email_events eo ON eo.email_id = e.id
  WHERE e.campaign_id = COALESCE(NEW.campaign_id, OLD.campaign_id)
  GROUP BY e.campaign_id, e.sequence_step
  ON CONFLICT (campaign_id, sequence_step) WHERE sequence_step IS NOT NULL
  DO UPDATE SET
    emails_sent = EXCLUDED.emails_sent,
    emails_opened = EXCLUDED.emails_opened,
    unique_opens = EXCLUDED.unique_opens,
    emails_clicked = EXCLUDED.emails_clicked,
    unique_clicks = EXCLUDED.unique_clicks,
    replies = EXCLUDED.replies,
    updated_at = NOW();
    
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Triggers pour mettre à jour les statistiques
CREATE TRIGGER trigger_update_stats_on_email_insert
AFTER INSERT ON emails
FOR EACH ROW
EXECUTE FUNCTION update_campaign_stats();

CREATE TRIGGER trigger_update_stats_on_event_change
AFTER INSERT OR UPDATE OR DELETE ON email_events
FOR EACH ROW
EXECUTE FUNCTION update_campaign_stats();
