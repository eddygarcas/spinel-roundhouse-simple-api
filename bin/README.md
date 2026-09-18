# Included native binary

`simple-api-linux-x86_64` is the verified native executable compiled from the
current `simple-api/` source with the Roundhouse and Spinel revisions recorded
in the repository root's `AGENTS.md`.

It is an x86_64 GNU/Linux ELF executable, dynamically linked against libc,
libstdc++, libcrypt, libjemalloc, and SQLite. It is not portable to macOS,
Windows, or ARM Linux hosts. Use the Docker image when those runtime libraries
or this architecture are not appropriate.

Verify it before running:

```bash
cd bin
sha256sum -c SHA256SUMS
```

From the repository root, run it with a persistent SQLite location:

```bash
mkdir -p storage
PORT=3000 BLOG_DB="$PWD/storage/simple-api.sqlite3" \
  ./bin/simple-api-linux-x86_64
```

The root README contains dependency-installation and Docker instructions.
