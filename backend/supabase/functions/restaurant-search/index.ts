import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";

interface RestaurantSearchRequest {
  latitude: number;
  longitude: number;
  radius?: number; // in meters, default 16093 (10 miles)
  type?: string; // default 'restaurant'
  minRating?: number;
  priceLevel?: number[];
  keyword?: string;
}

interface GooglePlacesResponse {
  results: GooglePlace[];
  status: string;
  next_page_token?: string;
  error_message?: string;
}

interface GooglePlace {
  place_id: string;
  name: string;
  formatted_address: string;
  geometry: {
    location: {
      lat: number;
      lng: number;
    };
  };
  rating?: number;
  user_ratings_total?: number;
  price_level?: number;
  types: string[];
  photos?: Array<{
    photo_reference: string;
    height: number;
    width: number;
  }>;
  opening_hours?: {
    open_now: boolean;
  };
  business_status?: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({
        success: false,
        error: 'Method not allowed. Use POST.'
      }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const body: RestaurantSearchRequest = await req.json();

    // Validate required fields
    if (!body.latitude || !body.longitude) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Missing required fields: latitude and longitude'
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Validate coordinate ranges
    if (body.latitude < -90 || body.latitude > 90 || body.longitude < -180 || body.longitude > 180) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180.'
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Get Google Places API key from environment variables
    const googleApiKey = Deno.env.get('GOOGLE_PLACES_API_KEY');
    
    if (!googleApiKey) {
      console.error('Google Places API key not found in environment variables');
      return new Response(JSON.stringify({
        success: false,
        error: 'API configuration error - Google Places API key not available'
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Build Google Places Nearby Search URL
    const radius = body.radius || 16093; // 10 miles in meters
    const type = body.type || 'restaurant';
    
    let googleUrl = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?` +
      `location=${body.latitude},${body.longitude}&` +
      `radius=${radius}&` +
      `type=${type}&` +
      `key=${googleApiKey}`;

    // Add optional parameters
    if (body.minRating) {
      googleUrl += `&minprice=${Math.floor(body.minRating)}`;
    }

    if (body.keyword) {
      googleUrl += `&keyword=${encodeURIComponent(body.keyword)}`;
    }

    console.log('Fetching from Google Places API for location:', body.latitude, body.longitude);

    // Call Google Places API
    const googleResponse = await fetch(googleUrl);
    
    if (!googleResponse.ok) {
      console.error('Google Places API HTTP error:', googleResponse.status);
      return new Response(JSON.stringify({
        success: false,
        error: 'API not working - Google Places service unavailable'
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const googleData: GooglePlacesResponse = await googleResponse.json();

    // API Key verification and error handling
    if (googleData.status === 'REQUEST_DENIED') {
      console.error('Google Places API key verification failed:', googleData.error_message);
      return new Response(JSON.stringify({
        success: false,
        error: 'API not working - Invalid API key or permissions'
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    if (googleData.status !== 'OK' && googleData.status !== 'ZERO_RESULTS') {
      console.error('Google Places API error:', googleData.status, googleData.error_message);
      return new Response(JSON.stringify({
        success: false,
        error: `API not working - Google Places error: ${googleData.status}`
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Handle zero results
    if (googleData.status === 'ZERO_RESULTS' || !googleData.results || googleData.results.length === 0) {
      console.log('No restaurants found for location:', body.latitude, body.longitude);
      return new Response(JSON.stringify({
        success: true,
        restaurants: [],
        total_found: 0,
        search_location: {
          lat: body.latitude,
          lng: body.longitude
        },
        radius_miles: Math.round(radius * 0.000621371 * 100) / 100,
        timestamp: new Date().toISOString(),
        message: 'No restaurants found in this area'
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Transform Google Places data to our format
    const restaurants = googleData.results
      .filter(place => place.business_status !== 'CLOSED_PERMANENTLY')
      .map(place => {
        // Calculate distance
        const distance = calculateDistance(
          body.latitude, body.longitude,
          place.geometry.location.lat, place.geometry.location.lng
        );

        // Extract cuisine types from Google types
        const cuisineTypes = extractCuisineTypes(place.types);

        return {
          place_id: place.place_id,
          name: place.name,
          address: place.formatted_address,
          latitude: place.geometry.location.lat,
          longitude: place.geometry.location.lng,
          rating: place.rating,
          total_ratings: place.user_ratings_total,
          price_level: place.price_level,
          cuisine_types: cuisineTypes,
          distance_miles: Math.round(distance * 100) / 100,
          photos: place.photos?.map(photo => 
            `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${photo.photo_reference}&key=${googleApiKey}`
          ) || [],
          is_open: place.opening_hours?.open_now
        };
      })
      .slice(0, 20); // Limit to 20 results for MVP

    const response = {
      success: true,
      restaurants,
      total_found: restaurants.length,
      search_location: {
        lat: body.latitude,
        lng: body.longitude
      },
      radius_miles: Math.round(radius * 0.000621371 * 100) / 100, // Convert meters to miles
      timestamp: new Date().toISOString()
    };

    console.log(`✅ Successfully found ${restaurants.length} restaurants`);
    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Error in restaurant search:', error);
    return new Response(JSON.stringify({
      success: false,
      error: 'API not working - Internal server error'
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});

// Helper function to calculate distance between two points
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 3959; // Earth's radius in miles
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRadians(degrees: number): number {
  return degrees * (Math.PI / 180);
}

// Helper function to extract cuisine types from Google Place types
function extractCuisineTypes(types: string[]): string[] {
  const cuisineMap: Record<string, string> = {
    'bakery': 'Bakery',
    'bar': 'Bar',
    'cafe': 'Cafe',
    'meal_delivery': 'Delivery',
    'meal_takeaway': 'Takeaway',
    'restaurant': 'Restaurant',
    'food': 'Food',
    'pizza_restaurant': 'Pizza',
    'chinese_restaurant': 'Chinese',
    'italian_restaurant': 'Italian',
    'japanese_restaurant': 'Japanese',
    'mexican_restaurant': 'Mexican',
    'indian_restaurant': 'Indian',
    'thai_restaurant': 'Thai',
    'american_restaurant': 'American',
    'seafood_restaurant': 'Seafood',
    'steakhouse': 'Steakhouse',
    'sushi_restaurant': 'Sushi',
    'fast_food_restaurant': 'Fast Food',
    'hamburger_restaurant': 'Burgers',
    'sandwich_shop': 'Sandwiches'
  };

  const cuisines = types
    .map(type => cuisineMap[type])
    .filter(cuisine => cuisine !== undefined);

  // If no specific cuisine types found, default to 'Restaurant'
  return cuisines.length > 0 ? cuisines : ['Restaurant'];
}
