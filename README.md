<h1 align="center">
  <br>
  <img src=".github/assets/ai.png" alt="Hellen AI" width="200">
  <br>
  Hellen AI - Intelligent Lesson Analysis Platform
  <br>
</h1>

<p align="center">
  <strong>An AI-powered platform that transcribes recorded lessons and provides pedagogical feedback based on Brazilian education standards (BNCC) and anti-bullying law (Lei 13.185).</strong>
</p>

<p align="center">
  <a href="./README.pt-BR.md">Portugues</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Elixir-1.14+-4B275F?style=flat&logo=elixir" alt="Elixir" />
  <img src="https://img.shields.io/badge/Phoenix-1.7-FD4F00?style=flat&logo=phoenixframework" alt="Phoenix" />
  <img src="https://img.shields.io/badge/TimescaleDB-PostgreSQL_17-FDB515?style=flat&logo=timescale" alt="TimescaleDB" />
  <img src="https://img.shields.io/badge/Qdrant-Vector_DB-DC382D?style=flat&logo=qdrant" alt="Qdrant" />
  <img src="https://img.shields.io/badge/NVIDIA_NIM-AI_Powered-76B900?style=flat&logo=nvidia" alt="NVIDIA NIM" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat" alt="License" />
</p>

<br>

<p align="center">
  <a href="#sparkles-features">Features</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;
  <a href="#art-architecture">Architecture</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;
  <a href="#computer-technologies">Technologies</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;
  <a href="#package-installation">Installation</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;
  <a href="#rocket-usage">Usage</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;
  <a href="#memo-license">License</a>
</p>

<br>

## :sparkles: Features

### Intelligent Lesson Analysis

- **Audio Transcription** - Convert lesson recordings to text using NVIDIA Parakeet CTC
- **BNCC Alignment** - Automatic mapping to Brazilian National Common Curricular Base competencies
- **Bullying Detection** - Identify inappropriate behavior based on Lei 13.185
- **Multi-Agent AI** - Specialized agents for pedagogy, compliance, and engagement analysis

### Education Standards Compliance

- **BNCC Competencies** - Automatic identification of addressed competencies
- **Skill Mapping** - Track which skills are being developed in each lesson
- **Compliance Reports** - Detailed feedback on pedagogical alignment

### Credit System

- **Free Tier** - New users start with 2 free credits
- **Pay-per-Use** - 1 credit = 1 complete lesson analysis
- **Auto-Refund** - Failed analyses are automatically refunded
- **Never Expire** - Credits remain valid indefinitely

### Real-time Processing

- **WebSocket Updates** - Live progress notifications during analysis
- **Background Jobs** - Oban-powered job queue for reliable processing
- **Instant Feedback** - Results delivered via real-time channels

<br>

## :art: Architecture

### System Overview

```mermaid
graph TD
    User[Teacher / Admin]

    subgraph "Hellen AI Platform"
        LB[Phoenix Server]
        API[REST API]
        Workers[Oban Workers]
        Agents[AI Agents]
    end

    subgraph "Data Layer"
        DB[(TimescaleDB)]
        Redis[Redis Cache]
        Qdrant[Qdrant Vector DB]
    end

    subgraph "External Services"
        R2[Cloudflare R2]
        NVIDIA[NVIDIA NIM API]
    end

    User -->|HTTPS| LB
    LB --> API
    API --> Workers

    Workers --> DB
    Workers --> Redis
    Workers --> Qdrant
    Workers --> R2
    Workers --> NVIDIA
    Workers --> Agents
```

### Processing Pipeline

```mermaid
sequenceDiagram
    participant T as Teacher
    participant A as API
    participant R2 as Cloudflare R2
    participant TW as Transcription Worker
    participant N as NVIDIA NIM
    participant AW as Analysis Worker
    participant AG as AI Agents
    participant Q as Qdrant

    T->>A: Upload Lesson Recording
    A->>R2: Store Audio File
    A->>TW: Queue Transcription Job
    TW->>N: Parakeet CTC
    N-->>TW: Transcribed Text
    TW->>AW: Queue Analysis Job
    AW->>AG: Multi-Agent Analysis
    AG->>N: Qwen3/Nemotron Analysis
    N-->>AG: Pedagogical Feedback
    AG-->>AW: Combined Results
    AW->>Q: Store Embeddings
    AW-->>T: WebSocket Notification
```

<br>

## :computer: Technologies

### Core Framework

- **[Elixir](https://elixir-lang.org/)** 1.14+ - Functional programming for scalable applications
- **[Phoenix](https://phoenixframework.org/)** 1.7 - Real-time web framework
- **[Ecto](https://hexdocs.pm/ecto/)** 3.11 - Database wrapper and query generator

### Database & Storage

- **[TimescaleDB](https://www.timescale.com/)** - Time-series optimized PostgreSQL
- **[Redis](https://redis.io/)** - In-memory caching with Redix
- **[Qdrant](https://qdrant.tech/)** - Vector database for semantic search
- **[Cloudflare R2](https://www.cloudflare.com/products/r2/)** - Object storage for audio files

### AI & Machine Learning

- **[NVIDIA NIM](https://developer.nvidia.com/nim)** - AI inference microservices
  - Parakeet CTC for Portuguese audio transcription
  - NV-EmbedQA for text embeddings
  - Qwen3/Nemotron for pedagogical analysis

### Authentication & Background Jobs

- **[Guardian](https://github.com/ueberauth/guardian)** - JWT authentication
- **[Oban](https://getoban.pro/)** 2.17 - Job processing with persistence

<br>

## :package: Installation

### Prerequisites

- **[Elixir](https://elixir-lang.org/)** 1.14+
- **[Docker](https://www.docker.com/)** & Docker Compose
- **[NVIDIA API Key](https://developer.nvidia.com/)** for AI features

### Quick Start

1. **Clone the repository**

```bash
git clone https://github.com/gabrielmaialva33/hellen-ai.git
cd hellen-ai
```

2. **Start infrastructure**

```bash
docker-compose up -d
```

This starts TimescaleDB (5432), Redis (6379), and Qdrant (6333/6334).

3. **Install dependencies**

```bash
mix deps.get
```

4. **Configure environment**

```bash
cp .env.example .env
```

Fill in your credentials:
```env
DATABASE_URL=postgresql://hellen:hellen@localhost:5432/hellen_dev
REDIS_URL=redis://localhost:6379
GUARDIAN_SECRET_KEY=your-secret-key-min-32-chars
NVIDIA_API_KEY=your-nvidia-api-key
R2_ACCESS_KEY_ID=your-r2-access-key
R2_SECRET_ACCESS_KEY=your-r2-secret-key
```

5. **Setup database**

```bash
mix ecto.setup
```

6. **Start the server**

```bash
mix phx.server
```

7. **Access the API**

Navigate to [http://localhost:4000](http://localhost:4000)

<br>

## :rocket: Usage

### API Endpoints

#### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login and get JWT token
- `GET /api/auth/me` - Get current user info

#### Lessons
- `GET /api/lessons` - List user's lessons
- `POST /api/lessons` - Create new lesson with audio upload
- `GET /api/lessons/:id` - Get lesson details
- `POST /api/lessons/:id/analyze` - Start analysis (costs 1 credit)

#### Analysis
- `GET /api/lessons/:lesson_id/analyses` - List analyses for lesson
- `GET /api/analyses/:id` - Get analysis details with BNCC matches

#### Credits
- `GET /api/credits` - Get current credit balance
- `GET /api/credits/history` - Get transaction history

### WebSocket Channels

Subscribe to `lesson:#{lesson_id}` for real-time updates:
- `transcription_started` - Audio processing began
- `transcription_completed` - Text ready
- `analysis_started` - AI analysis began
- `analysis_completed` - Results ready
- `analysis_failed` - Error occurred

<br>

## :hammer_and_wrench: Commands

```bash
mix deps.get        # Install dependencies
mix ecto.setup      # Create, migrate, and seed database
mix phx.server      # Start development server
mix test            # Run test suite
mix test path:line  # Run specific test
mix format          # Format code
mix credo           # Check code quality
mix ecto.reset      # Reset database
```

<br>

## :memo: License

This project is under the **MIT** license. See [LICENSE](./LICENSE) for details.

<br>

## :handshake: Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<br>

## :busts_in_silhouette: Author

<p align="center">
  <img src="https://avatars.githubusercontent.com/u/26732067" alt="Maia" width="100" style="border-radius: 50%;">
</p>

<p align="center">
  Made with :heart: by <strong>Maia</strong>
</p>

<p align="center">
  <a href="mailto:gabrielmaialva33@gmail.com">gabrielmaialva33@gmail.com</a>
  &nbsp;|&nbsp;
  <a href="https://github.com/gabrielmaialva33">@gabrielmaialva33</a>
</p>

<br>

<p align="center">
  <img src="https://raw.githubusercontent.com/gabrielmaialva33/gabrielmaialva33/master/assets/gray0_ctp_on_line.svg?sanitize=true" />
</p>

<p align="center">
  <strong>Hellen AI - Transforming Education Through Intelligent Analysis</strong>
</p>

<p align="center">
  &copy; 2017-present <a href="https://github.com/gabrielmaialva33/" target="_blank">Maia</a>
</p>
