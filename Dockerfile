# Dockerfile for Hellen AI - Phoenix 1.7 with Elixir Releases
# Multi-stage build optimized for production

# =============================================================================
# Stage 1: Build
# =============================================================================
ARG ELIXIR_VERSION=1.17.0
ARG OTP_VERSION=27.0
ARG DEBIAN_VERSION=bookworm-20240612-slim
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy application code
COPY priv priv
COPY lib lib
COPY assets assets

# Compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Copy runtime config
COPY config/runtime.exs config/

# Create release
COPY rel rel
RUN mix release

# =============================================================================
# Stage 2: Runner
# =============================================================================
FROM ${RUNNER_IMAGE}

# Install runtime dependencies (FFmpeg for audio extraction)
RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates ffmpeg \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

# Create a non-root user
RUN useradd --create-home app
RUN chown -R app:app /app
USER app

# Copy release from builder
COPY --from=builder --chown=app:app /app/_build/prod/rel/hellen ./

# Set runtime ENV
ENV MIX_ENV="prod"
ENV PHX_SERVER=true

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

# Start the Phoenix server
CMD ["bin/hellen", "start"]
