"""
Restaurant Finder MVP Backend Server
A simple FastAPI server that finds restaurants within a 10-mile radius using Google Places API
"""

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import os
import httpx
import asyncio
from datetime import datetime
import logging

# Import our new services
from location_service import LocationService, LocationData
from ai_analysis_service import AIAnalysisService, RestaurantAnalysis, analyze_single_restaurant, analyze_restaurant_area

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Restaurant Finder API",
    description="Find restaurants within a specified radius using Google Places API",
    version="1.0.0"
)

# Environment variables
GOOGLE_PLACES_API_KEY = os.getenv("GOOGLE_PLACES_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not GOOGLE_PLACES_API_KEY:
    logger.error("GOOGLE_PLACES_API_KEY environment variable not set")

# Initialize services
location_service = LocationService()
ai_service = AIAnalysisService()

# Constants
METERS_PER_MILE = 1609.34
MAX_RADIUS_MILES = 10
GOOGLE_PLACES_BASE_URL = "https://maps.googleapis.com/maps/api/place"

# Data Models
class Restaurant(BaseModel):
    place_id: str
    name: str
    address: str
    latitude: float
    longitude: float
    rating: Optional[float] = None
    total_ratings: Optional[int] = None
    price_level: Optional[int] = Field(None, description="1-4 scale, 1=cheap, 4=expensive")
    cuisine_types: List[str] = []
    phone: Optional[str] = None
    website: Optional[str] = None
    opening_hours: Optional[Dict[str, Any]] = None
    photos: List[str] = []
    distance_miles: Optional[float] = None

class RestaurantSearchResponse(BaseModel):
    restaurants: List[Restaurant]
    total_found: int
    search_location: Dict[str, float]
    radius_miles: float
    timestamp: datetime

class ErrorResponse(BaseModel):
    error: str
    message: str

# Helper Functions
def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two points in miles using Haversine formula"""
    import math
    
    R = 3959  # Earth's radius in miles
    
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)
    
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    
    a = math.sin(dlat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon/2)**2
    c = 2 * math.asin(math.sqrt(a))
    
    return R * c

def format_restaurant_data(place_data: Dict, user_lat: float, user_lng: float) -> Restaurant:
    """Convert Google Places API response to Restaurant model"""
    geometry = place_data.get("geometry", {})
    location = geometry.get("location", {})
    
    restaurant_lat = location.get("lat", 0)
    restaurant_lng = location.get("lng", 0)
    
    # Calculate distance from user location
    distance = calculate_distance(user_lat, user_lng, restaurant_lat, restaurant_lng)
    
    # Extract photos
    photos = []
    if "photos" in place_data:
        for photo in place_data["photos"][:3]:  # Limit to first 3 photos
            photo_ref = photo.get("photo_reference")
            if photo_ref:
                photo_url = f"{GOOGLE_PLACES_BASE_URL}/photo?maxwidth=400&photoreference={photo_ref}&key={GOOGLE_PLACES_API_KEY}"
                photos.append(photo_url)
    
    return Restaurant(
        place_id=place_data.get("place_id", ""),
        name=place_data.get("name", "Unknown"),
        address=place_data.get("vicinity", "Address not available"),
        latitude=restaurant_lat,
        longitude=restaurant_lng,
        rating=place_data.get("rating"),
        total_ratings=place_data.get("user_ratings_total"),
        price_level=place_data.get("price_level"),
        cuisine_types=place_data.get("types", []),
        photos=photos,
        distance_miles=round(distance, 2)
    )

async def get_place_details(place_id: str, include_reviews: bool = True) -> Dict[str, Any]:
    """Get detailed information for a specific place"""
    url = f"{GOOGLE_PLACES_BASE_URL}/details/json"
    
    # Base fields
    fields = ["name", "formatted_address", "formatted_phone_number", "website", "opening_hours", "photos", "rating", "user_ratings_total"]
    
    # Add reviews if requested
    if include_reviews:
        fields.append("reviews")
    
    params = {
        "place_id": place_id,
        "fields": ",".join(fields),
        "key": GOOGLE_PLACES_API_KEY
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            if data.get("status") == "OK":
                return data.get("result", {})
            else:
                logger.warning(f"Place details API error: {data.get('status')}")
                return {}
        except Exception as e:
            logger.error(f"Error fetching place details: {e}")
            return {}

# API Endpoints
@app.get("/", response_model=Dict[str, str])
async def root():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "message": "Restaurant Finder API is running",
        "version": "1.0.0"
    }

@app.get("/restaurants/auto", response_model=RestaurantSearchResponse)
async def find_restaurants_auto_location(
    request: Request,
    address: Optional[str] = Query(None, description="Address to search from (alternative to auto-detection)"),
    radius: float = Query(10, description="Search radius in miles", ge=0.1, le=MAX_RADIUS_MILES),
    min_rating: float = Query(0, description="Minimum rating filter", ge=0, le=5),
    max_results: int = Query(60, description="Maximum number of results", ge=1, le=60),
    include_ai_analysis: bool = Query(True, description="Include AI analysis of the area")
):
    """
    Find restaurants with automatic location detection
    
    - **address**: Optional address to search from instead of auto-detection
    - **radius**: Search radius in miles (max 10)
    - **min_rating**: Filter restaurants with rating >= this value
    - **max_results**: Maximum number of restaurants to return
    - **include_ai_analysis**: Whether to include AI analysis of restaurants
    """
    
    # Get client IP for location detection
    client_ip = request.client.host if request.client else None
    if client_ip == "127.0.0.1":
        client_ip = None  # Let the service detect public IP
    
    # Get user location
    location = await location_service.get_user_location(
        ip_address=client_ip,
        address=address
    )
    
    if not location:
        raise HTTPException(
            status_code=400, 
            detail="Could not determine your location. Please provide an address or coordinates manually."
        )
    
    # Use the detected location to find restaurants
    return await find_restaurants(
        lat=location.latitude,
        lng=location.longitude,
        radius=radius,
        min_rating=min_rating,
        max_results=max_results
    )

@app.get("/restaurants", response_model=RestaurantSearchResponse)
async def find_restaurants(
    lat: float = Query(..., description="Latitude of search location", ge=-90, le=90),
    lng: float = Query(..., description="Longitude of search location", ge=-180, le=180),
    radius: float = Query(10, description="Search radius in miles", ge=0.1, le=MAX_RADIUS_MILES),
    min_rating: float = Query(0, description="Minimum rating filter", ge=0, le=5),
    max_results: int = Query(60, description="Maximum number of results", ge=1, le=60)
):
    """
    Find restaurants within specified radius of given coordinates
    
    - **lat**: Latitude of search center
    - **lng**: Longitude of search center  
    - **radius**: Search radius in miles (max 10)
    - **min_rating**: Filter restaurants with rating >= this value
    - **max_results**: Maximum number of restaurants to return
    """
    
    if not GOOGLE_PLACES_API_KEY:
        raise HTTPException(status_code=500, detail="Google Places API key not configured")
    
    # Convert miles to meters for Google Places API
    radius_meters = int(radius * METERS_PER_MILE)
    
    url = f"{GOOGLE_PLACES_BASE_URL}/nearbysearch/json"
    params = {
        "location": f"{lat},{lng}",
        "radius": radius_meters,
        "type": "restaurant",
        "key": GOOGLE_PLACES_API_KEY
    }
    
    restaurants = []
    next_page_token = None
    
    async with httpx.AsyncClient() as client:
        try:
            # Make initial request
            response = await client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            if data.get("status") != "OK":
                raise HTTPException(
                    status_code=400, 
                    detail=f"Google Places API error: {data.get('status', 'Unknown error')}"
                )
            
            # Process first page of results
            for place in data.get("results", []):
                if len(restaurants) >= max_results:
                    break
                    
                # Apply rating filter
                if place.get("rating", 0) >= min_rating:
                    restaurant = format_restaurant_data(place, lat, lng)
                    restaurants.append(restaurant)
            
            # Get additional pages if needed and available
            next_page_token = data.get("next_page_token")
            while next_page_token and len(restaurants) < max_results:
                # Wait for next page token to become valid (required by Google)
                await asyncio.sleep(2)
                
                next_params = {
                    "pagetoken": next_page_token,
                    "key": GOOGLE_PLACES_API_KEY
                }
                
                response = await client.get(url, params=next_params)
                response.raise_for_status()
                data = response.json()
                
                if data.get("status") != "OK":
                    break
                
                for place in data.get("results", []):
                    if len(restaurants) >= max_results:
                        break
                    
                    if place.get("rating", 0) >= min_rating:
                        restaurant = format_restaurant_data(place, lat, lng)
                        restaurants.append(restaurant)
                
                next_page_token = data.get("next_page_token")
            
        except httpx.HTTPError as e:
            logger.error(f"HTTP error occurred: {e}")
            raise HTTPException(status_code=500, detail="Failed to fetch restaurant data")
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            raise HTTPException(status_code=500, detail="Internal server error")
    
    # Sort by distance and rating
    restaurants.sort(key=lambda r: (r.distance_miles or 999, -(r.rating or 0)))
    
    response = RestaurantSearchResponse(
        restaurants=restaurants,
        total_found=len(restaurants),
        search_location={"lat": lat, "lng": lng},
        radius_miles=radius,
        timestamp=datetime.now()
    )
    
    return response

@app.get("/restaurant/{place_id}", response_model=Dict[str, Any])
async def get_restaurant_details(
    place_id: str,
    include_reviews: bool = Query(True, description="Include Google reviews in response")
):
    """
    Get detailed information for a specific restaurant including reviews
    
    - **place_id**: Google Places ID for the restaurant
    - **include_reviews**: Whether to fetch Google reviews (costs extra API calls)
    """
    
    if not GOOGLE_PLACES_API_KEY:
        raise HTTPException(status_code=500, detail="Google Places API key not configured")
    
    details = await get_place_details(place_id, include_reviews)
    
    if not details:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    
    return {
        "place_id": place_id,
        "details": details,
        "timestamp": datetime.now()
    }

@app.get("/restaurant/{place_id}/analysis", response_model=Dict[str, Any])
async def get_restaurant_ai_analysis(place_id: str):
    """
    Get AI-powered analysis of a specific restaurant including reviews
    
    - **place_id**: Google Places ID for the restaurant
    """
    
    if not GOOGLE_PLACES_API_KEY:
        raise HTTPException(status_code=500, detail="Google Places API key not configured")
    
    # Get restaurant details with reviews
    details = await get_place_details(place_id, include_reviews=True)
    
    if not details:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    
    # Prepare data for AI analysis
    restaurant_data = {
        "name": details.get("name"),
        "rating": details.get("rating"),
        "total_ratings": details.get("user_ratings_total"),
        "price_level": details.get("price_level"),
        "cuisine_types": details.get("types", []),
        "reviews_by_source": {
            "google": {
                "reviews": details.get("reviews", [])
            }
        }
    }
    
    # Get AI analysis
    analysis = await analyze_single_restaurant(restaurant_data)
    
    return {
        "place_id": place_id,
        "restaurant_name": details.get("name"),
        "ai_analysis": analysis.dict(),
        "timestamp": datetime.now()
    }

@app.get("/location/detect", response_model=Dict[str, Any])
async def detect_user_location(
    request: Request,
    address: Optional[str] = Query(None, description="Address to geocode instead of IP detection")
):
    """
    Detect user location using IP or geocode an address
    
    - **address**: Optional address to geocode instead of IP-based detection
    """
    
    # Get client IP
    client_ip = request.client.host if request.client else None
    if client_ip == "127.0.0.1":
        client_ip = None
    
    # Get location
    location = await location_service.get_user_location(
        ip_address=client_ip,
        address=address
    )
    
    if not location:
        raise HTTPException(
            status_code=400,
            detail="Could not determine location from IP or address"
        )
    
    return {
        "location": location.dict(),
        "timestamp": datetime.now()
    }

@app.get("/restaurants/area-analysis")
async def get_area_restaurant_analysis(
    lat: float = Query(..., description="Latitude of search location", ge=-90, le=90),
    lng: float = Query(..., description="Longitude of search location", ge=-180, le=180),
    radius: float = Query(5, description="Search radius in miles", ge=0.1, le=MAX_RADIUS_MILES)
):
    """
    Get AI analysis of the restaurant scene in a specific area
    
    - **lat**: Latitude of search center
    - **lng**: Longitude of search center  
    - **radius**: Search radius in miles
    """
    
    # Get restaurants in the area (basic info only for analysis)
    restaurants_response = await find_restaurants(lat, lng, radius, max_results=20)
    
    # Convert to format suitable for AI analysis
    restaurants_for_analysis = []
    for restaurant in restaurants_response.restaurants:
        restaurants_for_analysis.append({
            "name": restaurant.name,
            "rating": restaurant.rating,
            "distance_miles": restaurant.distance_miles,
            "cuisine_types": restaurant.cuisine_types,
            "price_level": restaurant.price_level
        })
    
    # Get AI analysis of the area
    area_analysis = await analyze_restaurant_area(restaurants_for_analysis)
    
    return {
        "search_location": {"lat": lat, "lng": lng},
        "radius_miles": radius,
        "restaurants_analyzed": len(restaurants_for_analysis),
        "area_analysis": area_analysis,
        "timestamp": datetime.now()
    }

@app.get("/restaurant/{place_id}/reviews", response_model=Dict[str, Any])
async def get_restaurant_reviews(
    place_id: str,
    sources: List[str] = Query(["google"], description="Review sources: google, yelp"),
    limit: int = Query(10, description="Maximum reviews per source", ge=1, le=20)
):
    """
    Get reviews for a restaurant from multiple sources
    
    - **place_id**: Google Places ID for the restaurant
    - **sources**: Which review platforms to query (google, yelp)
    - **limit**: Maximum number of reviews per source
    """
    
    if not GOOGLE_PLACES_API_KEY:
        raise HTTPException(status_code=500, detail="Google Places API key not configured")
    
    all_reviews = {}
    
    # Get Google reviews if requested
    if "google" in sources:
        google_details = await get_place_details(place_id, include_reviews=True)
        google_reviews = google_details.get("reviews", [])
        
        # Format Google reviews
        formatted_google_reviews = []
        for review in google_reviews[:limit]:
            formatted_review = {
                "source": "google",
                "author_name": review.get("author_name", "Anonymous"),
                "rating": review.get("rating"),
                "text": review.get("text", ""),
                "time": review.get("time"),
                "relative_time_description": review.get("relative_time_description"),
                "profile_photo_url": review.get("profile_photo_url", "")
            }
            formatted_google_reviews.append(formatted_review)
        
        all_reviews["google"] = {
            "reviews": formatted_google_reviews,
            "total_count": len(formatted_google_reviews),
            "average_rating": google_details.get("rating"),
            "total_ratings": google_details.get("user_ratings_total")
        }
    
    # Get Yelp reviews if requested (would need Yelp API implementation)
    if "yelp" in sources:
        # Placeholder for Yelp integration
        all_reviews["yelp"] = {
            "reviews": [],
            "total_count": 0,
            "average_rating": None,
            "total_ratings": 0,
            "note": "Yelp integration not implemented yet"
        }
    
    return {
        "place_id": place_id,
        "reviews_by_source": all_reviews,
        "timestamp": datetime.now()
    }

@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=500,
        content={"error": "Internal server error", "message": str(exc)}
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
