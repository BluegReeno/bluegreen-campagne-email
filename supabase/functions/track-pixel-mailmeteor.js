// Supabase Edge Function pour le tracking des ouvertures d'emails
// Version: 1.0.0
// Format Mailmeteor

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.14.0'

// Création du client Supabase
const supabaseClient = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

// Base64 d'un pixel transparent 1x1
const TRANSPARENT_PIXEL = 'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'

serve(async (req) => {
  // Extraction des paramètres de l'URL
  const url = new URL(req.url)
  const trackingId = url.searchParams.get('tid')
  
  if (!trackingId) {
    // Si aucun ID de tracking, retourner simplement le pixel
    return new Response(
      Uint8Array.from(atob(TRANSPARENT_PIXEL), c => c.charCodeAt(0)),
      {
        headers: {
          'Content-Type': 'image/gif',
          'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0'
        }
      }
    )
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
      // Retourner le pixel même en cas d'erreur
      return new Response(
        Uint8Array.from(atob(TRANSPARENT_PIXEL), c => c.charCodeAt(0)),
        {
          headers: {
            'Content-Type': 'image/gif',
            'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0'
          }
        }
      )
    }

    // Extraire des informations de la requête
    const userAgent = req.headers.get('user-agent') || ''
    const ipAddress = req.headers.get('x-forwarded-for') || req.headers.get('cf-connecting-ip') || ''

    // Enregistrer l'événement d'ouverture dans tracking_events
    const { error: eventError } = await supabaseClient
      .from('tracking_events')
      .insert({
        recipient_id: recipientData.id,
        event_type: 'open',
        ip_address: ipAddress,
        user_agent: userAgent,
        metadata: {
          headers: Object.fromEntries(req.headers.entries())
        }
      })

    if (eventError) {
      console.error('Erreur d\'enregistrement de l\'événement:', eventError)
    }

    // Mise à jour du statut du destinataire dans recipients
    // (Ne pas mettre à jour si le statut est déjà EMAIL_CLICKED)
    const { error: updateError } = await supabaseClient
      .from('recipients')
      .update({
        campaign_status: 'EMAIL_OPENED',
        opened_at: new Date().toISOString()
      })
      .eq('id', recipientData.id)
      .not('campaign_status', 'eq', 'EMAIL_CLICKED')

    if (updateError) {
      console.error('Erreur de mise à jour du statut:', updateError)
    }

    // Retourner le pixel transparent
    return new Response(
      Uint8Array.from(atob(TRANSPARENT_PIXEL), c => c.charCodeAt(0)),
      {
        headers: {
          'Content-Type': 'image/gif',
          'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0'
        }
      }
    )
  } catch (error) {
    console.error('Erreur inattendue:', error)
    
    // Toujours retourner le pixel, même en cas d'erreur
    return new Response(
      Uint8Array.from(atob(TRANSPARENT_PIXEL), c => c.charCodeAt(0)),
      {
        headers: {
          'Content-Type': 'image/gif',
          'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0'
        }
      }
    )
  }
})
