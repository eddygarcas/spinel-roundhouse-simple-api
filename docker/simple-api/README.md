# Simple API container

Build from the workspace root. The Dockerfile downloads Roundhouse and Spinel
at pinned revisions, verifies the Rails source, emits the Spinel target, and
compiles the binary in Linux. No local `artifacts/`, `roundhouse/`, or
`spinel/` folders are needed.

```bash
docker build -t simple-api-binary -f docker/simple-api/Dockerfile .
docker run --rm -p 3000:3000 -v simple-api-storage:/app/storage simple-api-binary
```

Then verify it from another terminal:

```bash
curl http://127.0.0.1:3000/ping
curl http://127.0.0.1:3000/health
```

`/app/storage` is a Docker volume so the SQLite database survives container
replacement. Override its location with `-e BLOG_DB=/app/storage/custom.sqlite3`
or the port with `-e PORT=8080 -p 8080:8080`.

The build's strict Roundhouse check is a gate: if a source change leaves the
supported subset, the image build fails before producing a deployable binary.
