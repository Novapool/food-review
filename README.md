# Tastewise - Food Review App

A comprehensive food review application with location-based restaurant discovery, featuring a native iOS app and TypeScript backend powered by Supabase Edge Functions.

## 🚀 Features

- **Native iOS App** - SwiftUI-based mobile application with Core Location integration
- **Location Services** - Real-time GPS location tracking and Supabase integration
- **TypeScript Backend** - Serverless Edge Functions using Deno runtime
- **Modern Architecture** - @Observable pattern for reactive UI updates

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

#### Backend (TypeScript/Deno)
```bash
# Install Deno
curl -fsSL https://deno.land/install.sh | sh

# Install Supabase CLI
npm install -g supabase
```

#### iOS App
```bash
# Open the Xcode project
open frontend/Tastewise/Tastewise.xcodeproj
```

### 3. Configure Supabase

1. Set up your Supabase project (if not already done)
2. Update the Supabase URL and API key in `frontend/Tastewise/Tastewise/SupabaseService.swift`
3. Deploy the Edge Function:
   ```bash
   cd backend
   supabase functions deploy handle-location
   ```

### 4. Project Structure

```
tastewise/
├── frontend/
│   └── Tastewise/          # iOS SwiftUI Application
│       ├── Tastewise/
│       │   ├── ContentView.swift
│       │   ├── LocationManager.swift
│       │   ├── SupabaseService.swift
│       │   ├── Restaurant.swift
│       │   └── Item.swift
│       └── Tastewise.xcodeproj
├── backend/
│   ├── supabase/
│   │   ├── functions/
│   │   │   └── handle-location/
│   │   │       └── index.ts    # Location handling endpoint
│   │   └── _shared/
│   │       └── cors.ts         # CORS configuration
│   ├── deno.json              # Deno configuration
│   ├── package.json           # Project metadata
│   └── README.md              # Backend documentation
└── README.md                  # This file
```

### 5. Run the Application

#### iOS App
```bash
# Open Xcode and run the app
open frontend/Tastewise/Tastewise.xcodeproj
# Then press Cmd+R to build and run
```

#### Backend Development
```bash
# Test the function locally
cd backend
deno task dev

# Or run Supabase locally
supabase start
supabase functions serve
```

### 6. Test the Backend

#### Test Location Function
```bash
# Test the location endpoint
curl -X POST https://wwvabzmpqhchtftesxsx.supabase.co/functions/v1/handle-location \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
  -d '{"latitude": 37.7749, "longitude": -122.4194, "accuracy": 10.0}'

# Local testing (if running supabase locally)
curl -X POST http://localhost:54321/functions/v1/handle-location \
  -H "Content-Type: application/json" \
  -d '{"latitude": 37.7749, "longitude": -122.4194, "accuracy": 10.0}'
```

## 🎯 Current API Endpoints

### Supabase Edge Functions
- `POST /functions/v1/handle-location` - Receive and validate location data from iOS app

### Planned Endpoints (Future Implementation)
- `POST /functions/v1/find-restaurants` - Find restaurants by coordinates
- `POST /functions/v1/restaurant-details` - Get detailed restaurant information
- `POST /functions/v1/restaurant-analysis` - Get AI analysis of restaurant

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
