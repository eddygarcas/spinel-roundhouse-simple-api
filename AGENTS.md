# Spinel / Roundhouse Simple API Guide

## Purpose

This public repository is a minimal proof of concept for compiling a Rails API
into a native executable. The application source is `simple-api/`, with
`GET /`, `GET /ping`, and `GET /health`.

```text
Rails source -> Roundhouse strict check -> emitted Spinel-compatible Ruby
             -> Spinel native build -> `blog` executable -> Docker image
```

Roundhouse analyzes and lowers a supported Rails/Ruby subset for Spinel. Do
not attempt to compile ordinary Rails source directly with Spinel, and do not
assume a normal Rails feature is supported just because it runs under MRI.

## Repository and public-data boundaries

- `simple-api/` is the source of truth.
- `docker/simple-api/Dockerfile` is the reproducible source-only build path.
- `scripts/run-simple-api-container.sh` builds and starts the container.
- `docs/compilation-pipeline.md` documents the architecture.
- `roundhouse/`, `spinel/`, and `artifacts/` are local clones/build output and
  are intentionally ignored. Never commit them.
- Never stage `.env*`, local credentials, API keys, databases, or
  `simple-api/config/master.key`. The encrypted Rails credentials file may be
  tracked; its master key may not.
- If Backoffice work resumes, use an external or ignored local clone. Do not
  add Backoffice source, configuration, or artifacts to this public project.

## Pinned toolchain

The Dockerfile and this guide must remain aligned:

| Tool | Revision |
| --- | --- |
| Roundhouse | `b5cc3fb12eb3434be7691ca429b8bdb43107197a` |
| Spinel | `d10ef3dd50618b30359c26ebb128c4a58a8f44f9` |

Do not update a pin incidentally. Rebuild and run every validation step after a
toolchain upgrade, then record any compatibility change.

## Current compatibility contract

These source details are deliberate workarounds for the pinned toolchain:

1. Keep the Rails root route: the generated router expects `RouteTable.root`.
2. Keep a non-empty schema. The internal `api_runtime_states` table gives the
   generated runtime typed schema statements; it is not part of the API.
3. Controllers inherit from `ActionController::Base`, not
   `ActionController::API`; generated request state currently depends on it.
4. Fixed JSON responses use pre-encoded `render plain:` plus
   `content_type: "application/json"`. Inline `render json: { ... }` is not
   supported by this Spinel target.
5. Never make a lasting fix in emitted files. Fix the Rails source, a
   documented transformation, or Roundhouse itself.

The strict checker must have zero errors, warnings, and survey gaps before
emission.

## Development and direct compilation

Use the Ruby version in `simple-api/.ruby-version`:

```bash
cd simple-api
bundle install
bundle exec rails test
bundle exec rails server
```

When local compiler clones exist, use an ignored output directory:

```bash
roundhouse/target/release/roundhouse-check simple-api
roundhouse/target/release/roundhouse --target spinel \
  -o artifacts/simple-api-spinel simple-api
cd artifacts/simple-api-spinel
PATH="$PWD/../../spinel/bin:$PATH" spin build
```

The expected executable is `artifacts/simple-api-spinel/build/bin/blog`.
Generated output is diagnostic/build material, never source to edit or commit.

## Docker build and deployment

The Docker builder clones the pinned compiler sources, strictly validates the
app, emits it, and compiles it. A clean checkout therefore needs no local
binary, Roundhouse checkout, or Spinel checkout.

```bash
docker build -t simple-api-binary -f docker/simple-api/Dockerfile .
docker run --rm -p 3000:3000 \
  -v simple-api-storage:/app/storage \
  simple-api-binary
```

Or run `./scripts/run-simple-api-container.sh`.

The final image runs the executable as non-root `app` and contains only the
binary, required shared libraries, static public files, optional `db/seed.sql`,
and the persistent `/app/storage` directory. `PORT` defaults to `3000` and
`BLOG_DB` defaults to `/app/storage/blog.db`.

Smoke-test the running service:

```bash
curl -i http://localhost:3000/ping
curl -i http://localhost:3000/health
```

Both endpoints must return HTTP 200 and JSON.

## Required validation and contribution rules

For meaningful source or toolchain changes, run the relevant checks:

```bash
cd simple-api && bundle exec rails test
cd ..
roundhouse/target/release/roundhouse-check simple-api
docker build -t simple-api-binary -f docker/simple-api/Dockerfile .
docker run --rm -d --name simple-api-smoke -p 3000:3000 simple-api-binary
curl -f http://localhost:3000/ping
curl -f http://localhost:3000/health
docker rm -f simple-api-smoke
```

If compiler clones are unavailable, the Docker build is the authoritative
compilation check. Keep `.gitignore` and `.dockerignore` consistent with the
public-source and secret-handling rules. Run `git diff --check` before commits.

The public repository is
`https://github.com/eddygarcas/spinel-roundhouse-simple-api`. Review staged
files for secrets before every push; do not rewrite published history without
explicit authorization.
