// Supabase Edge Function pour le tracking des ouvertures d'emails
// Version: 1.0.0

// Cette fonction retourne un pixel transparent 1x1 et enregistre un événement d'ouverture
// dans la base de données lorsqu'un email est ouvert.

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
    // Récupérer l'email correspondant à l'ID de tracking
    const { data: emailData, error: emailError } = await supabaseClient
      .from('emails')
      .select('id, campaign_id, contact_id')
      .eq('tracking_id', trackingId)
      .single()

    if (emailError || !emailData) {
      console.error('Erreur de récupération de l\'email:', emailError)
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

    // Enregistrer l'événement d'ouverture
    const { error: eventError } = await supabaseClient
      .from('email_events')
      .insert({
        email_id: emailData.id,
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
