import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }

  try {
    // Only accept POST requests
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({
        success: false,
        error: 'Method not allowed. Use POST.'
      }), {
        status: 405,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }

    // Parse the request body
    const body = await req.json();

    // Validate required fields
    if (!body.latitude || !body.longitude) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Missing required fields: latitude and longitude'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }

    // Validate coordinate ranges
    if (body.latitude < -90 || body.latitude > 90) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Invalid latitude. Must be between -90 and 90.'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }

    if (body.longitude < -180 || body.longitude > 180) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Invalid longitude. Must be between -180 and 180.'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }

    // Log the received location (for debugging)
    console.log('Received location:', {
      latitude: body.latitude,
      longitude: body.longitude,
      accuracy: body.accuracy,
      timestamp: body.timestamp,
      user_id: body.user_id
    });

    // TODO: In the next step, we'll save this to the database
    // For now, just return success with the received data
    const response = {
      success: true,
      message: 'Location received successfully',
      location: {
        latitude: body.latitude,
        longitude: body.longitude,
        accuracy: body.accuracy,
        received_at: new Date().toISOString()
      }
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });

  } catch (error) {
    console.error('Error processing location:', error);
    return new Response(JSON.stringify({
      success: false,
      error: 'Internal server error'
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
