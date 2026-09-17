# syntax=docker/dockerfile:1

# Comments are provided throughout this file to help you get started.
# If you need more help, visit the Dockerfile reference guide at
# https://docs.docker.com/go/dockerfile-reference/

# Want to help us make this template better? Share your feedback here: https://forms.gle/ybq9Krt8jtBL3iCk7

ARG PYTHON_VERSION=3.13
FROM python:${PYTHON_VERSION}-slim AS base

# Prevents Python from writing pyc files.
ENV PYTHONDONTWRITEBYTECODE=1

# Keeps Python from buffering stdout and stderr to avoid situations where
# the application crashes without emitting any logs due to buffering.
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies in a separate stage so uv stays out of the runtime image.
FROM base AS builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

# Compile dependencies for faster startup and copy files from the cache mount.
# Use the Python provided by the base image rather than downloading another one.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0

# Download dependencies as a separate step to take advantage of Docker's caching.
# Cache downloaded packages and bind mount the project metadata for this step.
# --locked rejects an outdated lockfile; --no-dev excludes development dependencies.
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    uv sync --locked --no-dev --no-install-project

# Copy the source and sync again to support projects that install themselves.
COPY . .
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev

FROM base AS final

# Use the virtual environment directly, without needing uv at runtime.
ENV PATH="/app/.venv/bin:$PATH"

# Create a non-privileged user that the app will run under.
# See https://docs.docker.com/go/dockerfile-user-best-practices/
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

# Switch to the non-privileged user to run the application.
USER appuser

# Copy the source code and virtual environment from the builder.
COPY --from=builder /app /app

# Expose the port that the application listens on.
EXPOSE 5002

# Run the application.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5002"]
