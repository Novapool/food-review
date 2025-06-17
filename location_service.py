"""
Location Service Script
Handles automatic location detection using various methods
"""

import httpx
import logging
from typing import Dict, Optional, Tuple
from pydantic import BaseModel
import os

logger = logging.getLogger(__name__)

class LocationData(BaseModel):
    latitude: float
    longitude: float
    accuracy: Optional[float] = None
    city: Optional[str] = None
    state: Optional[str] = None
    country: Optional[str] = None
    zip_code: Optional[str] = None
    source: str  # "ip", "user_provided", "geocoded_address"

class LocationService:
    def __init__(self):
        self.google_api_key = os.getenv("GOOGLE_PLACES_API_KEY")
        
    async def get_location_from_ip(self, ip_address: Optional[str] = None) -> Optional[LocationData]:
        """
        Get location from IP address using IP geolocation service
        Falls back to user's public IP if no IP provided
        """
        try:
            # Use ipapi.co for IP geolocation (free tier available)
            if ip_address:
                url = f"http://ipapi.co/{ip_address}/json/"
            else:
                url = "http://ipapi.co/json/"
            
            async with httpx.AsyncClient() as client:
                response = await client.get(url, timeout=10)
                response.raise_for_status()
                data = response.json()
                
                if data.get("error"):
                    logger.warning(f"IP geolocation error: {data.get('reason')}")
                    return None
                
                return LocationData(
                    latitude=float(data.get("latitude", 0)),
                    longitude=float(data.get("longitude", 0)),
                    city=data.get("city"),
                    state=data.get("region"),
                    country=data.get("country_name"),
                    zip_code=data.get("postal"),
                    source="ip"
                )
                
        except Exception as e:
            logger.error(f"Error getting location from IP: {e}")
            return None
    
    async def geocode_address(self, address: str) -> Optional[LocationData]:
        """
        Convert address to coordinates using Google Geocoding API
        """
        if not self.google_api_key:
            logger.error("Google API key not configured for geocoding")
            return None
            
        try:
            url = "https://maps.googleapis.com/maps/api/geocode/json"
            params = {
                "address": address,
                "key": self.google_api_key
            }
            
            async with httpx.AsyncClient() as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
                data = response.json()
                
                if data.get("status") != "OK":
                    logger.warning(f"Geocoding error: {data.get('status')}")
                    return None
                
                if not data.get("results"):
                    return None
                    
                result = data["results"][0]
                location = result["geometry"]["location"]
                
                # Extract address components
                components = result.get("address_components", [])
                city = state = country = zip_code = None
                
                for component in components:
                    types = component.get("types", [])
                    if "locality" in types:
                        city = component.get("long_name")
                    elif "administrative_area_level_1" in types:
                        state = component.get("short_name")
                    elif "country" in types:
                        country = component.get("long_name")
                    elif "postal_code" in types:
                        zip_code = component.get("long_name")
                
                return LocationData(
                    latitude=location["lat"],
                    longitude=location["lng"],
                    city=city,
                    state=state,
                    country=country,
                    zip_code=zip_code,
                    source="geocoded_address"
                )
                
        except Exception as e:
            logger.error(f"Error geocoding address: {e}")
            return None
    
    async def reverse_geocode(self, lat: float, lng: float) -> Optional[Dict[str, str]]:
        """
        Convert coordinates to human-readable address
        """
        if not self.google_api_key:
            return None
            
        try:
            url = "https://maps.googleapis.com/maps/api/geocode/json"
            params = {
                "latlng": f"{lat},{lng}",
                "key": self.google_api_key
            }
            
            async with httpx.AsyncClient() as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
                data = response.json()
                
                if data.get("status") != "OK" or not data.get("results"):
                    return None
                
                result = data["results"][0]
                return {
                    "formatted_address": result.get("formatted_address", ""),
                    "place_id": result.get("place_id", "")
                }
                
        except Exception as e:
            logger.error(f"Error reverse geocoding: {e}")
            return None
    
    async def get_user_location(
        self, 
        ip_address: Optional[str] = None,
        address: Optional[str] = None,
        lat: Optional[float] = None,
        lng: Optional[float] = None
    ) -> Optional[LocationData]:
        """
        Get user location using various methods in order of preference:
        1. Provided coordinates (most accurate)
        2. Geocoded address 
        3. IP-based location (least accurate)
        """
        
        # Method 1: Direct coordinates provided
        if lat is not None and lng is not None:
            # Optionally enhance with reverse geocoding
            address_info = await self.reverse_geocode(lat, lng)
            
            return LocationData(
                latitude=lat,
                longitude=lng,
                city=address_info.get("city") if address_info else None,
                source="user_provided"
            )
        
        # Method 2: Geocode provided address
        if address:
            location = await self.geocode_address(address)
            if location:
                return location
        
        # Method 3: Fallback to IP-based location
        location = await self.get_location_from_ip(ip_address)
        if location:
            return location
        
        logger.warning("Could not determine user location using any method")
        return None
    
    def validate_coordinates(self, lat: float, lng: float) -> bool:
        """
        Validate that coordinates are within valid ranges
        """
        return -90 <= lat <= 90 and -180 <= lng <= 180
    
    def calculate_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Calculate distance between two points in miles using Haversine formula
        """
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

# Example usage functions
async def get_location_auto(request_ip: str = None) -> Optional[LocationData]:
    """
    Simple function to automatically get user location
    """
    service = LocationService()
    return await service.get_user_location(ip_address=request_ip)

async def get_location_from_address(address: str) -> Optional[LocationData]:
    """
    Simple function to get location from address
    """
    service = LocationService()
    return await service.geocode_address(address)

# Test function
async def test_location_service():
    """
    Test the location service with various inputs
    """
    service = LocationService()
    
    print("Testing IP-based location...")
    ip_location = await service.get_location_from_ip()
    if ip_location:
        print(f"IP Location: {ip_location.city}, {ip_location.state} ({ip_location.latitude}, {ip_location.longitude})")
    
    print("\nTesting address geocoding...")
    address_location = await service.geocode_address("1600 Amphitheatre Parkway, Mountain View, CA")
    if address_location:
        print(f"Address Location: {address_location.city}, {address_location.state} ({address_location.latitude}, {address_location.longitude})")
    
    print("\nTesting reverse geocoding...")
    reverse_result = await service.reverse_geocode(37.4221, -122.0841)
    if reverse_result:
        print(f"Reverse Geocode: {reverse_result['formatted_address']}")

if __name__ == "__main__":
    import asyncio
    asyncio.run(test_location_service())