# ──────────────────────────────────────────
# Base
# ──────────────────────────────────────────
# Use a Python image with uv pre-installed
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy

# Omit development dependencies
ENV UV_NO_DEV=1

# Disable Python downloads, because we want to use the system interpreter
# across both images. If using a managed Python version, it needs to be
# copied from the build image into the final image; see `standalone.Dockerfile`
# for an example.
ENV UV_PYTHON_DOWNLOADS=0

# Install the project into `/app`
WORKDIR /app
# Install the project's dependencies using the lockfile and settings
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project

# Then, add the rest of the project source code and install it
# Installing separately from its dependencies allows optimal layer caching
COPY ./src/ /app/src/
COPY pyproject.toml uv.lock /app/
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked

# ──────────────────────────────────────────
# Dev — hot reload via volume mount
# ──────────────────────────────────────────
FROM python:3.12-slim-bookworm AS runner

# Setup a non-root user
RUN groupadd --system --gid 999 nonroot \
 && useradd --system --gid 999 --uid 999 --create-home nonroot

# Copy the application from the builder
COPY --from=builder --chown=nonroot:nonroot /app /app

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONPATH="/app/"
ENV PYTHONUNBUFFERED=1

USER nonroot

WORKDIR /app

FROM runner AS dev
CMD ["fastapi", "dev", "/app/src/main.py", "--host", "0.0.0.0", "--port", "8000"] 

# ──────────────────────────────────────────
# Prod — no dev deps, no volume mount
# ──────────────────────────────────────────
FROM runner AS prod
CMD ["fastapi", "run", "/app/src/main.py", "--host", "0.0.0.0", "--port", "8000"]
