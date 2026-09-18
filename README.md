# Spinel / Roundhouse Simple Rails API

A small Rails API compiled into a native Linux executable with
[Roundhouse](https://github.com/rubys/roundhouse) and
[Spinel](https://github.com/matz/spinel).

The Docker build checks the Rails source, emits Spinel-compatible code,
compiles the `blog` executable, and packages only that executable and the
libraries it needs in the final image. A clean clone needs no prebuilt binary,
compiler checkout, or local artifact directory.

## Endpoints

| Endpoint | Response |
| --- | --- |
| `GET /` | `{"status":"ok"}` |
| `GET /ping` | `{"message":"pong"}` |
| `GET /health` | `{"status":"ok"}` |

## Run locally with Rails

You need Ruby `4.0.5` (see `simple-api/.ruby-version`) and Bundler.

```bash
git clone https://github.com/eddygarcas/spinel-roundhouse-simple-api.git
cd spinel-roundhouse-simple-api/simple-api
bundle install
bundle exec rails test
bundle exec rails server
```

The Rails development server listens on port `3000` by default. In another
terminal, verify it:

```bash
curl -i http://localhost:3000/ping
curl -i http://localhost:3000/health
```

## Build and run the compiled Docker image

Docker is the recommended way to compile and deploy this example. The first
build downloads Rust dependencies and the pinned compiler sources, so it can
take several minutes.

```bash
git clone https://github.com/eddygarcas/spinel-roundhouse-simple-api.git
cd spinel-roundhouse-simple-api
docker build -t simple-api-binary:latest -f docker/simple-api/Dockerfile .
docker run --rm --name simple-api \
  -p 3000:3000 \
  -v simple-api-storage:/app/storage \
  simple-api-binary:latest
```

Or use the helper script, which builds the image and starts it on port `3000`:

```bash
./scripts/run-simple-api-container.sh
```

The image build fails if Roundhouse finds unsupported Rails/Ruby code. That is
intentional: a successfully built image is the compilation gate.

## Deploy with Docker

Build and publish the image to a container registry that your server can pull
from. Replace `REGISTRY/USER` with your registry namespace:

```bash
docker build -t REGISTRY/USER/spinel-roundhouse-simple-api:latest \
  -f docker/simple-api/Dockerfile .
docker push REGISTRY/USER/spinel-roundhouse-simple-api:latest
```

On the server:

```bash
docker pull REGISTRY/USER/spinel-roundhouse-simple-api:latest
docker volume create simple-api-storage
docker run -d --restart unless-stopped \
  --name simple-api \
  -p 3000:3000 \
  -v simple-api-storage:/app/storage \
  REGISTRY/USER/spinel-roundhouse-simple-api:latest
```

For a different host port, configure `PORT` and map the same port:

```bash
docker run -d --restart unless-stopped \
  --name simple-api \
  -e PORT=8080 \
  -p 8080:8080 \
  -v simple-api-storage:/app/storage \
  REGISTRY/USER/spinel-roundhouse-simple-api:latest
```

The named volume preserves the SQLite database across container replacements.
Its default path is `/app/storage/development.sqlite3`; change it with
`BLOG_DB`, keeping it under the mounted `/app/storage` directory:

```bash
-e BLOG_DB=/app/storage/production.sqlite3
```

Verify a deployment:

```bash
curl -f http://SERVER_HOST:3000/ping
curl -f http://SERVER_HOST:3000/health
docker logs simple-api
```

For internet-facing use, place a TLS-terminating reverse proxy or load
balancer in front of the container. Do not expose a database file or commit a
Rails master key into the image or repository.

## Project layout

```text
simple-api/                           Rails API source and tests
docker/simple-api/Dockerfile          Pinned source-to-native Docker build
scripts/run-simple-api-container.sh   Local build/run helper
docs/compilation-pipeline.md          Build architecture
AGENTS.md                             Maintainer rules and constraints
```

See [AGENTS.md](AGENTS.md) for the pinned Roundhouse/Spinel revisions, known
source constraints, and the full validation workflow.
