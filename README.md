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

## Run the included native binary

The repository includes a verified binary at
[`bin/simple-api-linux-x86_64`](bin/simple-api-linux-x86_64), so Linux x86_64
users can try the API without installing Ruby, Roundhouse, Spinel, or Docker.
It is a dynamically linked ELF binary built for GNU/Linux (kernel 4.4 or
newer), not a macOS, Windows, or ARM executable.

It requires the standard C/C++ runtime plus the SQLite, jemalloc, and crypt
shared libraries. On Debian/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y libsqlite3-0 libjemalloc2 libcrypt1 libstdc++6
```

Verify the committed checksum, then create a persistent local data directory
and start it:

```bash
(cd bin && sha256sum -c SHA256SUMS)
mkdir -p storage
PORT=3000 BLOG_DB="$PWD/storage/simple-api.sqlite3" \
  ./bin/simple-api-linux-x86_64
```

Use `Ctrl-C` to stop the server. In a second terminal, call `/ping` or
`/health` as shown below. Rebuild the binary through Docker after any source or
compiler change; do not edit or patch the committed executable.

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

## Compatibility and troubleshooting

Converting an existing Rails application is not a configuration switch.
Roundhouse supports a Rails/Ruby subset, lowers that source to a
Spinel-compatible program, and Spinel compiles the emitted program—not the
original Rails application.

Start with the strict checker and treat every error, warning, and survey gap as
a compatibility task. With local `roundhouse/` and `spinel/` checkouts, the
complete sequence from the repository root is:

```bash
roundhouse/target/release/roundhouse-check my-api
roundhouse/target/release/roundhouse --target spinel \
  -o artifacts/my-api-spinel my-api
cd artifacts/my-api-spinel
PATH="$(cd ../../spinel && pwd)/bin:$PATH" spin build
```

Do not run `spinel my-api` directly against a normal Rails project. Spinel
builds the output emitted by Roundhouse; `spin build` is therefore run only
after changing into `artifacts/my-api-spinel`.

The executable is normally `build/bin/blog`.

### Common changes needed in an existing project

- Isolate or replace highly dynamic Ruby: `eval`, runtime method definitions,
  extensive metaprogramming, reflection, and runtime constant lookup.
- Review gems that depend on native extensions, runtime code generation, Redis,
  background jobs, Action Cable, mailers, external HTTP clients, or cloud SDKs.
- Keep routes, controller behavior, database access, and schemas explicit so
  Roundhouse can analyze them. Test Active Record queries, associations,
  callbacks, and migrations individually rather than assuming all Rails
  patterns compile.
- Keep a root route and a non-empty schema. The current generated runtime
  requires both.
- Use `ActionController::Base` when the generated request runtime needs the
  normal controller state; this example cannot use `ActionController::API`.
- Replace unsupported inline JSON rendering with a fixed encoded response when
  appropriate:

  ```ruby
  render plain: '{"status":"ok"}', content_type: "application/json"
  ```

  instead of:

  ```ruby
  render json: { status: "ok" }
  ```

Never hand-edit emitted Spinel files as a permanent fix. Make the correction in
the Rails source, a documented transformation, or Roundhouse itself, then
regenerate.

### Recommended migration order

Start with one to three independent API endpoints, make only their dependency
paths compile-compatible, compile them, and compare the native binary with
Rails. Then expand endpoint by endpoint. Verify response status, headers and
body, authentication/authorization failures, validation errors, database
reads/writes, and environment configuration.

The initial Backoffice survey had dozens of unsupported items, which is normal
for a non-trivial Rails application: expect an incremental compatibility effort
rather than a one-command conversion.
