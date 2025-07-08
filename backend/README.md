# Tastewise Backend

TypeScript backend for the Tastewise food review app using Supabase Edge Functions.

## Architecture

This backend uses Supabase Edge Functions powered by Deno runtime for serverless TypeScript execution.

### Directory Structure

```
backend/
├── supabase/
│   ├── functions/
│   │   └── handle-location/
│   │       └── index.ts          # Location handling endpoint
│   └── _shared/
│       └── cors.ts               # CORS configuration
├── deno.json                     # Deno configuration
├── package.json                  # Project metadata and scripts
└── README.md                     # This file
```

## Functions

### handle-location

Handles location data from the iOS app.

- **Endpoint**: `POST /functions/v1/handle-location`
- **Purpose**: Receives and validates location coordinates from the mobile app
- **Validation**: Ensures latitude/longitude are within valid ranges
- **Response**: Returns success status and processed location data

## Development

### Prerequisites

- [Deno](https://deno.land/) >= 1.30.0
- [Supabase CLI](https://supabase.com/docs/guides/cli)

### Local Development

1. Start the function locally:
```bash
cd backend
deno task dev
```

2. Test the function:
```bash
curl -X POST http://localhost:54321/functions/v1/handle-location \
  -H "Content-Type: application/json" \
  -d '{"latitude": 37.7749, "longitude": -122.4194, "accuracy": 10.0}'
```

### Deployment

Deploy all functions:
```bash
npm run deploy
```

Deploy specific function:
```bash
npm run deploy:location
```

View logs:
```bash
npm run logs:location
```

## Environment Variables

No environment variables are currently required for the location handler.

## API Documentation

### POST /functions/v1/handle-location

Receives location data from the mobile app.

**Request Body:**
```json
{
  "latitude": 37.7749,
  "longitude": -122.4194,
  "accuracy": 10.0,
  "timestamp": "2025-01-05T12:00:00Z",
  "user_id": "optional-user-id"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Location received successfully",
  "location": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "accuracy": 10.0,
    "received_at": "2025-01-05T12:00:00.000Z"
  }
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "Invalid latitude. Must be between -90 and 90."
}
```

## Migration from Python

This backend was migrated from a Python/FastAPI implementation to TypeScript/Deno for better integration with Supabase Edge Functions and improved performance.

### Key Changes

- **Runtime**: Python → Deno (TypeScript)
- **Framework**: FastAPI → Supabase Edge Functions
- **Deployment**: Docker → Serverless Edge Functions
- **Dependencies**: pip → Deno imports

## Future Enhancements

- [ ] Add database integration for location storage
- [ ] Implement restaurant search functionality
- [ ] Add user authentication
- [ ] Implement caching for improved performance
