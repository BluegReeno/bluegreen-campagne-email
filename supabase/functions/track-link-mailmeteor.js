// Supabase Edge Function pour le tracking des clics sur les liens
// Version: 1.0.0
// Format Mailmeteor

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.14.0'

// Création du client Supabase
const supabaseClient = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

serve(async (req) => {
  // Extraction des paramètres de l'URL
  const url = new URL(req.url)
  const trackingId = url.searchParams.get('tid')
  const destination = url.searchParams.get('url')
  
  if (!trackingId || !destination) {
    // Si des paramètres sont manquants, rediriger vers la page d'accueil de BlueGreen
    return new Response(null, {
      status: 302,
      headers: {
        'Location': 'https://bluegreen.ai'
      }
    })
  }

  try {
    // Récupérer le destinataire correspondant à l'ID de tracking
    const { data: recipientData, error: recipientError } = await supabaseClient
      .from('recipients')
      .select('id, campaign_id')
      .eq('tracking_id', trackingId)
      .single()

    if (recipientError || !recipientData) {
      console.error('Erreur de récupération du destinataire:', recipientError)
      // Rediriger quand même en cas d'erreur
      return new Response(null, {
        status: 302,
        headers: {
          'Location': destination
        }
      })
    }

    // Extraire des informations de la requête
    const userAgent = req.headers.get('user-agent') || ''
    const ipAddress = req.headers.get('x-forwarded-for') || req.headers.get('cf-connecting-ip') || ''

    // Enregistrer l'événement de clic dans tracking_events
    const { error: eventError } = await supabaseClient
      .from('tracking_events')
      .insert({
        recipient_id: recipientData.id,
        event_type: 'click',
        ip_address: ipAddress,
        user_agent: userAgent,
        link_clicked: destination,
        metadata: {
          headers: Object.fromEntries(req.headers.entries()),
          referrer: req.headers.get('referer') || ''
        }
      })

    if (eventError) {
      console.error('Erreur d\'enregistrement de l\'événement:', eventError)
    }

    // Mise à jour du statut du destinataire dans recipients
    const { error: updateError } = await supabaseClient
      .from('recipients')
      .update({
        campaign_status: 'EMAIL_CLICKED',
        clicked_at: new Date().toISOString()
      })
      .eq('id', recipientData.id)

    if (updateError) {
      console.error('Erreur de mise à jour du statut:', updateError)
    }

    // Rediriger vers la destination
    return new Response(null, {
      status: 302,
      headers: {
        'Location': destination,
        'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0'
      }
    })
  } catch (error) {
    console.error('Erreur inattendue:', error)
    
    // Toujours rediriger, même en cas d'erreur
    return new Response(null, {
      status: 302,
      headers: {
        'Location': destination
      }
    })
  }
})
