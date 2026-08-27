import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// ✅ En-têtes pour autoriser Chrome (Flutter Web) à parler à Supabase
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Répondre aux requêtes de vérification de Chrome
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { prompt, style } = await req.json()
    
    // Récupérer ta clé secrète
    const replicateToken = Deno.env.get('REPLICATE_API_TOKEN')
    if (!replicateToken) throw new Error("Clé API Replicate manquante dans Supabase")

    const fullPrompt = `${prompt}, ${style}, 4k, highly detailed, masterpiece`

    // ✅ Appel à Replicate avec un VRAI modèle (SDXL) qui fonctionne
    const response = await fetch("https://api.replicate.com/v1/predictions", {
      method: "POST",
      headers: {
        "Authorization": `Token ${replicateToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        version: "39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b", // Vrai modèle SDXL
        input: { 
          prompt: fullPrompt,
          width: 1024,
          height: 1024
        }
      })
    })

    if (!response.ok) {
      const errText = await response.text()
      throw new Error(`Erreur Replicate: ${errText}`)
    }

    const prediction = await response.json()

    // Attendre que l'IA finisse (max 60 secondes)
    let imageUrl = null
    for (let i = 0; i < 30; i++) {
      await new Promise(r => setTimeout(r, 2000)) // Attendre 2s
      
      const statusRes = await fetch(prediction.urls.get, {
        headers: { "Authorization": `Token ${replicateToken}` }
      })
      const statusData = await statusRes.json()
      
      if (statusData.status === "succeeded") {
        imageUrl = statusData.output[0] // SDXL retourne souvent une liste
        break
      } else if (statusData.status === "failed") {
        throw new Error(`L'IA a échoué: ${statusData.error}`)
      }
    }

    if (!imageUrl) throw new Error("Délai d'attente dépassé")

    // Renvoyer le succès à Flutter
    return new Response(
      JSON.stringify({ success: true, image_url: imageUrl }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    // Renvoyer l'erreur à Flutter
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})