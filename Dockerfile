FROM python:3.12-slim AS build

LABEL org.opencontainers.image.source=https://github.com/ga4gh/anyvar
LABEL org.opencontainers.image.description="AnyVar container image"
LABEL org.opencontainers.image.licenses=Apache-2.0

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    curl \
    git \
    libpq-dev \
    python3-pip \
    python3-venv \
    rsync \
    zlib1g-dev \
    postgresql \
    ;

WORKDIR /app
RUN python3.12 -m venv /app/venv \
    && /app/venv/bin/pip install --upgrade 'pip>=25.1'
# Recreate the git-tracked tree at HEAD from .git, so the build uses only committed
# files and setuptools_scm sees a clean tree (exact tag version).
COPY .git /app/.git
RUN git reset --hard HEAD
ENV PATH=/app/venv/bin:$PATH
RUN pip install -e '.[queueing,postgres,projection]' --group dev --group test

FROM python:3.12-slim AS anyvar

RUN apt-get update && apt-get install -y libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/venv /app/venv
COPY --from=build /app/src /app/src
COPY --from=build /app/pyproject.toml /app/pyproject.toml
COPY --from=build /app/alembic.ini /app/alembic.ini
COPY --from=build /app/alembic /app/alembic

ENV PATH=/app/venv/bin:$PATH

EXPOSE 8000

CMD ["uvicorn", "--host=0.0.0.0", "anyvar.restapi.main:app"]
