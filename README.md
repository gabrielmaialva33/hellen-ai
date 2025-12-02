# Hellen AI

AI-powered lesson analysis platform. Transcribes recorded lessons and provides pedagogical feedback based on BNCC and Lei 13.185 (Anti-bullying).

## Features

- **Automatic Transcription**: Uses NVIDIA Whisper/Parakeet for accurate Portuguese transcription
- **Pedagogical Analysis**: AI-powered analysis based on BNCC competencies
- **Bullying Detection**: Identifies inappropriate behavior based on Lei 13.185
- **Credit System**: Free users start with 2 credits, 1 credit = 1 lesson analysis
- **Real-time Progress**: WebSocket updates during processing

## Tech Stack

- **Backend**: Elixir/Phoenix 1.7
- **Database**: TimescaleDB (PostgreSQL with time-series extensions)
- **Cache**: Redis
- **Vector DB**: Qdrant (for semantic search)
- **AI**: NVIDIA NIM (Whisper, Qwen3)
- **Job Queue**: Oban

## Getting Started

### Prerequisites

- Elixir 1.14+
- Docker and Docker Compose
- NVIDIA API key

### Setup

1. Clone and setup:
```bash
cd hellen
cp .env.example .env
# Edit .env with your NVIDIA_API_KEY
```

2. Start infrastructure:
```bash
docker-compose up -d
```

3. Install dependencies and setup database:
```bash
mix deps.get
mix ecto.setup
```

4. Start the server:
```bash
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) to see the API.

## API Endpoints

### Auth
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Get current user

### Lessons
- `GET /api/lessons` - List user's lessons
- `POST /api/lessons` - Create new lesson
- `GET /api/lessons/:id` - Get lesson details
- `POST /api/lessons/:id/analyze` - Start analysis (uses 1 credit)

### Analysis
- `GET /api/lessons/:lesson_id/analyses` - List analyses for lesson
- `GET /api/analyses/:id` - Get analysis details

### Credits
- `GET /api/credits` - Get credit balance
- `GET /api/credits/history` - Get transaction history

## Credit System

- Free users start with **2 credits**
- Each lesson analysis costs **1 credit**
- Credits never expire
- Failed analyses are automatically refunded

## Development

```bash
# Run tests
mix test

# Format code
mix format

# Check code quality
mix credo
```

## License

MIT
