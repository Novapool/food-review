"""
AI Analysis Service Script
Handles AI-powered analysis of restaurant data and reviews using OpenAI GPT
"""

from openai import AsyncOpenAI
import logging
from typing import Dict, List, Optional, Any
from pydantic import BaseModel
import os
import json
from datetime import datetime

logger = logging.getLogger(__name__)

class RestaurantAnalysis(BaseModel):
    overall_rating: str  # "Excellent", "Very Good", "Good", "Fair", "Poor"
    overall_summary: str
    food_quality: Dict[str, Any]  # score, highlights, concerns
    service_quality: Dict[str, Any]
    atmosphere: Dict[str, Any]
    value_for_money: Dict[str, Any]
    key_highlights: List[str]
    potential_concerns: List[str]
    recommendation: str
    best_for: List[str]  # "Date night", "Family dinner", "Business lunch", etc.
    price_range_assessment: str
    confidence_score: float  # 0-1 based on amount of data available

class AIAnalysisService:
    def __init__(self):
        self.openai_api_key = os.getenv("OPENAI_API_KEY")
        if not self.openai_api_key:
            logger.warning("OpenAI API key not configured")
            self.client = None
        else:
            self.client = AsyncOpenAI(api_key=self.openai_api_key)
    
    def _create_analysis_prompt(self, restaurant_data: Dict[str, Any]) -> str:
        """
        Create a comprehensive prompt for AI analysis
        """
        restaurant_name = restaurant_data.get("name", "Unknown Restaurant")
        rating = restaurant_data.get("rating", "No rating")
        total_ratings = restaurant_data.get("total_ratings", 0)
        price_level = restaurant_data.get("price_level", "Unknown")
        cuisine_types = restaurant_data.get("cuisine_types", [])
        
        # Extract reviews if available
        reviews_text = ""
        google_reviews = restaurant_data.get("reviews_by_source", {}).get("google", {}).get("reviews", [])
        
        if google_reviews:
            reviews_text = "\n\nRecent Google Reviews:\n"
            for i, review in enumerate(google_reviews[:10]):  # Limit to 10 reviews
                reviews_text += f"\nReview {i+1} (Rating: {review.get('rating', 'N/A')}/5):\n"
                reviews_text += f"Author: {review.get('author_name', 'Anonymous')}\n"
                reviews_text += f"Time: {review.get('relative_time_description', 'Unknown')}\n"
                reviews_text += f"Text: {review.get('text', 'No text')}\n"
                reviews_text += "-" * 40
        
        # Convert price level to description
        price_descriptions = {
            1: "Inexpensive ($)",
            2: "Moderate ($$)", 
            3: "Expensive ($$$)",
            4: "Very Expensive ($$$$)"
        }
        price_desc = price_descriptions.get(price_level, "Price level unknown")
        
        prompt = f"""
You are a professional restaurant critic and analyst. Please provide a comprehensive analysis of the following restaurant based on the available data:

RESTAURANT INFORMATION:
- Name: {restaurant_name}
- Overall Google Rating: {rating}/5 ({total_ratings} reviews)
- Price Level: {price_desc}
- Cuisine Types: {', '.join(cuisine_types) if cuisine_types else 'Not specified'}

{reviews_text}

Please analyze this restaurant and provide a structured response in the following JSON format:

{{
    "overall_rating": "[Excellent/Very Good/Good/Fair/Poor]",
    "overall_summary": "[2-3 sentence summary of the restaurant]",
    "food_quality": {{
        "score": "[1-10]",
        "highlights": "[What stands out about the food]",
        "concerns": "[Any food-related issues mentioned]"
    }},
    "service_quality": {{
        "score": "[1-10]", 
        "highlights": "[Service strengths]",
        "concerns": "[Service issues]"
    }},
    "atmosphere": {{
        "score": "[1-10]",
        "highlights": "[Ambiance positives]",
        "concerns": "[Ambiance issues]"
    }},
    "value_for_money": {{
        "score": "[1-10]",
        "assessment": "[Value assessment based on price vs quality]"
    }},
    "key_highlights": ["[Top 3-5 positive aspects]"],
    "potential_concerns": ["[Top 2-3 concerns or negatives]"],
    "recommendation": "[Who should visit this restaurant and why]",
    "best_for": ["[Occasion types - Date night, Family dinner, Business lunch, etc.]"],
    "price_range_assessment": "[Is pricing fair for what you get?]",
    "confidence_score": "[0.0-1.0 based on amount of review data available]"
}}

Base your analysis on the actual review content, ratings, and restaurant information provided. Be honest about both positives and negatives. If there's limited data, reflect that in your confidence score.
"""
        return prompt
    
    async def analyze_restaurant(self, restaurant_data: Dict[str, Any]) -> Optional[RestaurantAnalysis]:
        """
        Analyze restaurant using OpenAI GPT
        """
        if not self.client:
            logger.error("OpenAI API key not configured")
            return None
        
        try:
            prompt = self._create_analysis_prompt(restaurant_data)
            
            response = await self.client.chat.completions.create(
                model="gpt-4",  # Use gpt-3.5-turbo for cheaper alternative
                messages=[
                    {
                        "role": "system", 
                        "content": "You are a professional restaurant critic who provides detailed, honest, and helpful restaurant analyses. Always respond with valid JSON."
                    },
                    {
                        "role": "user", 
                        "content": prompt
                    }
                ],
                max_tokens=1500,
                temperature=0.3  # Lower temperature for more consistent analysis
            )
            
            # Extract the JSON response
            analysis_text = response.choices[0].message.content
            if not analysis_text:
                logger.error("Empty response from OpenAI")
                return None
            analysis_text = analysis_text.strip()
            
            # Try to parse as JSON
            try:
                analysis_dict = json.loads(analysis_text)
                return RestaurantAnalysis(**analysis_dict)
            except json.JSONDecodeError:
                # If JSON parsing fails, try to extract JSON from the response
                start_idx = analysis_text.find('{')
                end_idx = analysis_text.rfind('}') + 1
                if start_idx != -1 and end_idx != -1:
                    json_str = analysis_text[start_idx:end_idx]
                    analysis_dict = json.loads(json_str)
                    return RestaurantAnalysis(**analysis_dict)
                else:
                    logger.error("Could not extract valid JSON from AI response")
                    return None
            
        except Exception as e:
            logger.error(f"Error in AI analysis: {e}")
            return None
    
    def _create_summary_prompt(self, restaurants: List[Dict[str, Any]]) -> str:
        """
        Create prompt for analyzing multiple restaurants in an area
        """
        restaurant_summaries = []
        for restaurant in restaurants[:10]:  # Limit to top 10
            name = restaurant.get("name", "Unknown")
            rating = restaurant.get("rating", "N/A")
            distance = restaurant.get("distance_miles", "N/A")
            cuisine = restaurant.get("cuisine_types", [])
            
            restaurant_summaries.append(
                f"- {name}: {rating}/5 stars, {distance} miles away, Cuisine: {', '.join(cuisine[:2])}"
            )
        
        restaurants_text = "\n".join(restaurant_summaries)
        
        prompt = f"""
Based on the following restaurants in the area, provide a brief summary of the dining options:

RESTAURANTS IN AREA:
{restaurants_text}

Please provide:
1. A 2-3 sentence overview of the dining scene in this area
2. Top 3 restaurant recommendations with brief reasons
3. Cuisine variety assessment
4. Overall quality level of restaurants in the area

Keep the response concise and helpful for someone looking for dining options.
"""
        return prompt
    
    async def analyze_area_restaurants(self, restaurants: List[Dict[str, Any]]) -> str:
        """
        Provide an overview analysis of restaurants in an area
        """
        if not self.client:
            return "AI analysis not available - OpenAI API key not configured"
        
        if not restaurants:
            return "No restaurants found in this area."
        
        try:
            prompt = self._create_summary_prompt(restaurants)
            
            response = await self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {
                        "role": "system",
                        "content": "You are a local dining expert who provides helpful overviews of restaurant scenes in different areas."
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                max_tokens=500,
                temperature=0.4
            )
            
            content = response.choices[0].message.content
            return content.strip() if content else "No analysis generated"
            
        except Exception as e:
            logger.error(f"Error in area analysis: {e}")
            return f"Error generating area analysis: {str(e)}"
    
    def create_fallback_analysis(self, restaurant_data: Dict[str, Any]) -> RestaurantAnalysis:
        """
        Create a basic analysis when AI is not available
        """
        rating = restaurant_data.get("rating", 0)
        total_ratings = restaurant_data.get("total_ratings", 0)
        price_level = restaurant_data.get("price_level", 2)
        
        # Simple scoring based on Google rating
        if rating >= 4.5:
            overall_rating = "Excellent"
        elif rating >= 4.0:
            overall_rating = "Very Good"
        elif rating >= 3.5:
            overall_rating = "Good"
        elif rating >= 3.0:
            overall_rating = "Fair"
        else:
            overall_rating = "Poor"
        
        price_descriptions = {
            1: "budget-friendly",
            2: "moderately priced", 
            3: "upscale",
            4: "fine dining"
        }
        price_desc = price_descriptions.get(price_level, "moderately priced")
        
        return RestaurantAnalysis(
            overall_rating=overall_rating,
            overall_summary=f"This {price_desc} restaurant has a {rating}/5 star rating based on {total_ratings} reviews.",
            food_quality={"score": int(rating * 2), "highlights": "Based on customer ratings", "concerns": "Limited analysis available"},
            service_quality={"score": int(rating * 2), "highlights": "Based on overall ratings", "concerns": "No specific service data"},
            atmosphere={"score": int(rating * 2), "highlights": "Customer-rated experience", "concerns": "No detailed atmosphere data"},
            value_for_money={"score": 7, "assessment": f"Appears to offer good value in the {price_desc} category"},
            key_highlights=[f"{rating}/5 star rating", f"{total_ratings} customer reviews", f"{price_desc} pricing"],
            potential_concerns=["Limited analysis without detailed reviews"],
            recommendation=f"Consider visiting if you enjoy {price_desc} dining options",
            best_for=["General dining"],
            price_range_assessment=f"Pricing appears {price_desc} based on Google data",
            confidence_score=0.3  # Low confidence without detailed data
        )

# Convenience functions
async def analyze_single_restaurant(restaurant_data: Dict[str, Any]) -> RestaurantAnalysis:
    """
    Analyze a single restaurant with AI or fallback
    """
    service = AIAnalysisService()
    
    # Try AI analysis first
    analysis = await service.analyze_restaurant(restaurant_data)
    
    # Fallback to basic analysis if AI fails
    if not analysis:
        analysis = service.create_fallback_analysis(restaurant_data)
    
    return analysis

async def analyze_restaurant_area(restaurants: List[Dict[str, Any]]) -> str:
    """
    Analyze the restaurant scene in an area
    """
    service = AIAnalysisService()
    return await service.analyze_area_restaurants(restaurants)

# Test function
async def test_ai_analysis():
    """
    Test the AI analysis service
    """
    # Sample restaurant data
    test_data = {
        "name": "Test Restaurant",
        "rating": 4.3,
        "total_ratings": 150,
        "price_level": 2,
        "cuisine_types": ["restaurant", "italian", "food"],
        "reviews_by_source": {
            "google": {
                "reviews": [
                    {
                        "author_name": "John D.",
                        "rating": 5,
                        "text": "Amazing pasta! Great service and cozy atmosphere. Will definitely come back.",
                        "relative_time_description": "1 week ago"
                    },
                    {
                        "author_name": "Mary S.", 
                        "rating": 4,
                        "text": "Good food but service was a bit slow. Nice ambiance though.",
                        "relative_time_description": "2 weeks ago"
                    }
                ]
            }
        }
    }
    
    print("Testing AI restaurant analysis...")
    analysis = await analyze_single_restaurant(test_data)
    print(f"Overall Rating: {analysis.overall_rating}")
    print(f"Summary: {analysis.overall_summary}")
    print(f"Confidence: {analysis.confidence_score}")

if __name__ == "__main__":
    import asyncio
    asyncio.run(test_ai_analysis())
