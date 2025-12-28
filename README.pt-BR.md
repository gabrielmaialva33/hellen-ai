<h1 align="center">
  <br>
  <img src=".github/assets/ai.png" alt="Hellen AI" width="200">
  <br>
  Hellen AI - Plataforma Inteligente de Analise de Aulas
  <br>
</h1>

<p align="center">
  <strong>Uma plataforma com IA que transcreve aulas gravadas e fornece feedback pedagogico baseado nos padroes educacionais brasileiros (BNCC) e na lei anti-bullying (Lei 13.185).</strong>
</p>

<p align="center">
  <a href="./README.md">English</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Elixir-1.14+-4B275F?style=flat&logo=elixir" alt="Elixir" />
  <img src="https://img.shields.io/badge/Phoenix-1.7-FD4F00?style=flat&logo=phoenixframework" alt="Phoenix" />
  <img src="https://img.shields.io/badge/TimescaleDB-PostgreSQL_17-FDB515?style=flat&logo=timescale" alt="TimescaleDB" />
  <img src="https://img.shields.io/badge/Qdrant-Vector_DB-DC382D?style=flat&logo=qdrant" alt="Qdrant" />
  <img src="https://img.shields.io/badge/NVIDIA_NIM-AI_Powered-76B900?style=flat&logo=nvidia" alt="NVIDIA NIM" />
  <img src="https://img.shields.io/badge/Licenca-MIT-green?style=flat" alt="Licenca" />
</p>

<br>

<p align="center">
  <a href="#sparkles-funcionalidades">Funcionalidades</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;
  <a href="#art-arquitetura">Arquitetura</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;
  <a href="#computer-tecnologias">Tecnologias</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;
  <a href="#package-instalacao">Instalacao</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;
  <a href="#rocket-uso">Uso</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;
  <a href="#memo-licenca">Licenca</a>
</p>

<br>

## :sparkles: Funcionalidades

### Analise Inteligente de Aulas

- **Transcricao de Audio** - Converte gravacoes de aulas em texto usando NVIDIA Parakeet CTC
- **Alinhamento BNCC** - Mapeamento automatico para competencias da Base Nacional Comum Curricular
- **Deteccao de Bullying** - Identifica comportamentos inadequados baseado na Lei 13.185
- **IA Multi-Agente** - Agentes especializados para analise pedagogica, compliance e engajamento

### Conformidade com Padroes Educacionais

- **Competencias BNCC** - Identificacao automatica das competencias abordadas
- **Mapeamento de Habilidades** - Acompanhe quais habilidades estao sendo desenvolvidas em cada aula
- **Relatorios de Conformidade** - Feedback detalhado sobre alinhamento pedagogico

### Sistema de Creditos

- **Nivel Gratuito** - Novos usuarios comecam com 2 creditos gratis
- **Pague por Uso** - 1 credito = 1 analise completa de aula
- **Reembolso Automatico** - Analises falhas sao reembolsadas automaticamente
- **Nunca Expiram** - Creditos permanecem validos indefinidamente

### Processamento em Tempo Real

- **Atualizacoes WebSocket** - Notificacoes de progresso em tempo real durante a analise
- **Jobs em Background** - Fila de jobs com Oban para processamento confiavel
- **Feedback Instantaneo** - Resultados entregues via canais em tempo real

<br>

## :art: Arquitetura

### Visao Geral do Sistema

```mermaid
graph TD
    User[Professor / Admin]

    subgraph "Plataforma Hellen AI"
        LB[Servidor Phoenix]
        API[REST API]
        Workers[Oban Workers]
        Agents[Agentes IA]
    end

    subgraph "Camada de Dados"
        DB[(TimescaleDB)]
        Redis[Redis Cache]
        Qdrant[Qdrant Vector DB]
    end

    subgraph "Servicos Externos"
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

### Pipeline de Processamento

```mermaid
sequenceDiagram
    participant P as Professor
    participant A as API
    participant R2 as Cloudflare R2
    participant TW as Worker Transcricao
    participant N as NVIDIA NIM
    participant AW as Worker Analise
    participant AG as Agentes IA
    participant Q as Qdrant

    P->>A: Upload Gravacao da Aula
    A->>R2: Armazenar Arquivo de Audio
    A->>TW: Enfileirar Job de Transcricao
    TW->>N: Parakeet CTC
    N-->>TW: Texto Transcrito
    TW->>AW: Enfileirar Job de Analise
    AW->>AG: Analise Multi-Agente
    AG->>N: Analise Qwen3/Nemotron
    N-->>AG: Feedback Pedagogico
    AG-->>AW: Resultados Combinados
    AW->>Q: Armazenar Embeddings
    AW-->>P: Notificacao WebSocket
```

<br>

## :computer: Tecnologias

### Framework Principal

- **[Elixir](https://elixir-lang.org/)** 1.14+ - Programacao funcional para aplicacoes escalaveis
- **[Phoenix](https://phoenixframework.org/)** 1.7 - Framework web em tempo real
- **[Ecto](https://hexdocs.pm/ecto/)** 3.11 - Wrapper de banco de dados e gerador de queries

### Banco de Dados & Armazenamento

- **[TimescaleDB](https://www.timescale.com/)** - PostgreSQL otimizado para series temporais
- **[Redis](https://redis.io/)** - Cache em memoria com Redix
- **[Qdrant](https://qdrant.tech/)** - Banco de dados vetorial para busca semantica
- **[Cloudflare R2](https://www.cloudflare.com/products/r2/)** - Armazenamento de objetos para arquivos de audio

### IA & Machine Learning

- **[NVIDIA NIM](https://developer.nvidia.com/nim)** - Microsservicos de inferencia IA
  - Parakeet CTC para transcricao de audio em portugues
  - NV-EmbedQA para embeddings de texto
  - Qwen3/Nemotron para analise pedagogica

### Autenticacao & Jobs em Background

- **[Guardian](https://github.com/ueberauth/guardian)** - Autenticacao JWT
- **[Oban](https://getoban.pro/)** 2.17 - Processamento de jobs com persistencia

<br>

## :package: Instalacao

### Pre-requisitos

- **[Elixir](https://elixir-lang.org/)** 1.14+
- **[Docker](https://www.docker.com/)** & Docker Compose
- **[Chave API NVIDIA](https://developer.nvidia.com/)** para recursos de IA

### Inicio Rapido

1. **Clone o repositorio**

```bash
git clone https://github.com/gabrielmaialva33/hellen-ai.git
cd hellen-ai
```

2. **Inicie a infraestrutura**

```bash
docker-compose up -d
```

Isso inicia TimescaleDB (5432), Redis (6379) e Qdrant (6333/6334).

3. **Instale as dependencias**

```bash
mix deps.get
```

4. **Configure o ambiente**

```bash
cp .env.example .env
```

Preencha suas credenciais:
```env
DATABASE_URL=postgresql://hellen:hellen@localhost:5432/hellen_dev
REDIS_URL=redis://localhost:6379
GUARDIAN_SECRET_KEY=sua-chave-secreta-min-32-chars
NVIDIA_API_KEY=sua-chave-api-nvidia
R2_ACCESS_KEY_ID=sua-chave-acesso-r2
R2_SECRET_ACCESS_KEY=sua-chave-secreta-r2
```

5. **Configure o banco de dados**

```bash
mix ecto.setup
```

6. **Inicie o servidor**

```bash
mix phx.server
```

7. **Acesse a API**

Navegue ate [http://localhost:4000](http://localhost:4000)

<br>

## :rocket: Uso

### Endpoints da API

#### Autenticacao
- `POST /api/auth/register` - Registrar novo usuario
- `POST /api/auth/login` - Login e obter token JWT
- `GET /api/auth/me` - Obter info do usuario atual

#### Aulas
- `GET /api/lessons` - Listar aulas do usuario
- `POST /api/lessons` - Criar nova aula com upload de audio
- `GET /api/lessons/:id` - Obter detalhes da aula
- `POST /api/lessons/:id/analyze` - Iniciar analise (custa 1 credito)

#### Analise
- `GET /api/lessons/:lesson_id/analyses` - Listar analises da aula
- `GET /api/analyses/:id` - Obter detalhes da analise com matches BNCC

#### Creditos
- `GET /api/credits` - Obter saldo de creditos atual
- `GET /api/credits/history` - Obter historico de transacoes

### Canais WebSocket

Inscreva-se em `lesson:#{lesson_id}` para atualizacoes em tempo real:
- `transcription_started` - Processamento de audio iniciado
- `transcription_completed` - Texto pronto
- `analysis_started` - Analise IA iniciada
- `analysis_completed` - Resultados prontos
- `analysis_failed` - Ocorreu erro

<br>

## :hammer_and_wrench: Comandos

```bash
mix deps.get        # Instalar dependencias
mix ecto.setup      # Criar, migrar e popular banco de dados
mix phx.server      # Iniciar servidor de desenvolvimento
mix test            # Executar suite de testes
mix test path:line  # Executar teste especifico
mix format          # Formatar codigo
mix credo           # Verificar qualidade do codigo
mix ecto.reset      # Resetar banco de dados
```

<br>

## :memo: Licenca

Este projeto esta sob a licenca **MIT**. Veja [LICENSE](./LICENSE) para detalhes.

<br>

## :handshake: Contribuindo

Contribuicoes sao bem-vindas! Sinta-se livre para enviar um Pull Request.

1. Fork o projeto
2. Crie sua branch de feature (`git checkout -b feature/RecursoIncrivel`)
3. Commit suas mudancas (`git commit -m 'Adiciona recurso incrivel'`)
4. Push para a branch (`git push origin feature/RecursoIncrivel`)
5. Abra um Pull Request

<br>

## :busts_in_silhouette: Autor

<p align="center">
  <img src="https://avatars.githubusercontent.com/u/26732067" alt="Maia" width="100" style="border-radius: 50%;">
</p>

<p align="center">
  Feito com :heart: por <strong>Maia</strong>
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
  <strong>Hellen AI - Transformando a Educacao Atraves de Analise Inteligente</strong>
</p>

<p align="center">
  &copy; 2017-presente <a href="https://github.com/gabrielmaialva33/" target="_blank">Maia</a>
</p>
