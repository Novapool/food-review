# Restaurant Finder API v2.0

A comprehensive MVP backend for finding restaurants with automatic location detection and AI-powered analysis.

## 🚀 New Features

- **Automatic Location Detection** - Uses IP geolocation and address geocoding
- **AI Restaurant Analysis** - Detailed analysis using OpenAI GPT
- **Area Restaurant Analysis** - Overview of dining scene in any area
- **Enhanced Review Integration** - Structured review data from Google Places

## Features

- Find restaurants within 10-mile radius of any location
- Automatic location detection via IP or address
- AI-powered restaurant analysis and recommendations
- Filter by minimum rating and limit results
- Get detailed restaurant information including photos and hours
- Sort results by distance and rating
- RESTful API with automatic documentation

## Setup Instructions

### 1. Get API Keys

#### Google Places API Key
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the following APIs:
   - Places API
   - Places API (New)
   - Geocoding API
4. Create credentials (API Key)
5. Restrict the API key to your server's IP (recommended for production)

#### OpenAI API Key
1. Go to [OpenAI Platform](https://platform.openai.com/)
2. Create an account or sign in
3. Navigate to API Keys section
4. Create a new API key
5. Note: This requires a paid OpenAI account for GPT-4 access

### 2. Install Dependencies

#### Option A: Using Poetry (Recommended)
```bash
# Install Poetry if you haven't already
curl -sSL https://install.python-poetry.org | python3 -

# Install dependencies
poetry install

# Activate virtual environment
poetry shell
```

#### Option B: Using pip
```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 3. Configure Environment

1. Copy `.env.example` to `.env`
2. Add your API keys:
   ```
   GOOGLE_PLACES_API_KEY=your_actual_google_key_here
   OPENAI_API_KEY=your_actual_openai_key_here
   ```

### 4. Project Structure

Make sure you have these files in your project directory:
```
restaurant-finder-api/
├── main.py                 # Main FastAPI application
├── location_service.py     # Location detection service
├── ai_analysis_service.py  # AI analysis service
├── .env                    # Environment variables (create this)
├── requirements.txt        # Dependencies
└── README.md              # This file
```

### 5. Run the Server

#### Development Mode
```bash
# With Poetry
poetry run uvicorn main:app --reload

# With pip
uvicorn main:app --reload
```

#### Production Mode
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

#### With Docker
```bash
# Build and run
docker-compose up --build

# Or run in background
docker-compose up -d
```

### 6. Test the API

The server will start on `http://localhost:8000`

- **API Documentation**: http://localhost:8000/docs
- **Alternative Docs**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/

#### Example API Calls

```bash
# Auto-detect location and find restaurants
curl "http://localhost:8000/restaurants/auto"

# Auto-detect with specific address
curl "http://localhost:8000/restaurants/auto?address=Times Square, NYC"

# Get AI analysis of a restaurant
curl "http://localhost:8000/restaurant/ChIJN1t_tDeuEmsRUsoyG83frY4/analysis"

# Get area restaurant analysis
curl "http://localhost:8000/restaurants/area-analysis?lat=40.7580&lng=-73.9855"

# Detect user location
curl "http://localhost:8000/location/detect"
```

## 🎯 API Endpoints

### Core Endpoints
- `GET /` - Health check
- `GET /restaurants` - Find restaurants by coordinates (original)
- `GET /restaurants/auto` - Find restaurants with auto location detection
- `GET /location/detect` - Detect user location

### Restaurant Details
- `GET /restaurant/{place_id}` - Get restaurant details
- `GET /restaurant/{place_id}/reviews` - Get reviews from multiple sources
- `GET /restaurant/{place_id}/analysis` - Get AI analysis of restaurant

### Area Analysis
- `GET /restaurants/area-analysis` - Get AI analysis of restaurant scene in area

## Cost Estimation

### Google Places API pricing (as of 2024):
- Nearby Search: $0.032 per request
- Place Details: $0.017 per request
- Geocoding: $0.005 per request
- Place Photos: $0.007 per request

### OpenAI API pricing:
- GPT-4: ~$0.03-0.06 per analysis
- GPT-3.5-turbo: ~$0.002 per analysis

### For 1000 users making 10 searches per month:
- Google APIs: ~$350-500/month
- OpenAI (GPT-4): ~$300-600/month
- **Total: ~$650-1100/month** (can be reduced by using GPT-3.5-turbo)

## Features in Detail

### Automatic Location Detection
- IP-based geolocation (least accurate)
- Address geocoding (most accurate)
- Manual coordinate input (fallback)

### AI Restaurant Analysis
- Overall rating and summary
- Food quality assessment
- Service quality evaluation
- Atmosphere analysis
- Value for money assessment
- Key highlights and concerns
- Recommendations for best use cases

### Area Analysis
- Overview of local dining scene
- Top restaurant recommendations
- Cuisine variety assessment
- Quality level indicators

## Next Steps

1. Add caching with Redis for better performance
2. Implement Yelp API integration for additional reviews
3. Add user authentication and favorites
4. Build mobile app frontend
5. Add more review sources (TripAdvisor, etc.)
6. Implement rate limiting and monitoring
7. Add restaurant recommendation algorithms

## Troubleshooting

### Common Issues

1. **"Google Places API key not configured"**
   - Make sure your `.env` file has the correct API key
   - Verify the API key has Places API enabled

2. **"OpenAI API key not configured"**
   - Add OPENAI_API_KEY to your `.env` file
   - Ensure you have a paid OpenAI account

3. **"Could not determine location"**
   - IP-based location detection may fail on localhost
   - Use the address parameter instead
   - Or provide coordinates manually

4. **AI analysis fails**
   - Check OpenAI API key and billing
   - Falls back to basic analysis if AI fails
   - Monitor API usage limits

### Development Tips

- Use the `/docs` endpoint to test API calls interactively
- Check logs for detailed error messages
- Use smaller radius for testing to reduce API costs
- Consider using GPT-3.5-turbo instead of GPT-4 for cost savings
- Test location detection with different addresses
