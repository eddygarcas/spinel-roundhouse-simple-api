# Compile the source Rails API with pinned Roundhouse and Spinel revisions.
FROM rust:1.98-bookworm AS build

ARG ROUNDHOUSE_REV=b5cc3fb12eb3434be7691ca429b8bdb43107197a
ARG SPINEL_REV=d10ef3dd50618b30359c26ebb128c4a58a8f44f9

RUN apt-get update -qq \
  && apt-get install --no-install-recommends -y clang libclang-dev curl git make libsqlite3-dev libjemalloc-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone https://github.com/rubys/roundhouse.git /src/roundhouse \
  && git -C /src/roundhouse checkout "$ROUNDHOUSE_REV" \
  && git clone https://github.com/matz/spinel.git /src/spinel \
  && git -C /src/spinel checkout "$SPINEL_REV" \
  && make -C /src/spinel deps \
  && make -C /src/spinel -j2 \
  && cargo build --manifest-path /src/roundhouse/Cargo.toml --release --bin roundhouse-check --bin roundhouse

COPY simple-api /src/simple-api
WORKDIR /src/simple-api
RUN /src/roundhouse/target/release/roundhouse-check . \
  && /src/roundhouse/target/release/roundhouse --target spinel -o /src/emitted .
WORKDIR /src/emitted
RUN PATH=/src/spinel/bin:$PATH CC=clang spin build

FROM debian:trixie-slim

RUN apt-get update -qq \
  && apt-get install --no-install-recommends -y libsqlite3-0 libjemalloc2 libstdc++6 libcrypt1 \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd --system app \
  && useradd --system --gid app --home-dir /app --create-home app

WORKDIR /app
COPY --from=build --chown=app:app /src/emitted/build/bin/blog /app/blog
COPY --from=build --chown=app:app /src/emitted/public /app/public
COPY --from=build --chown=app:app /src/emitted/db/seed.sql /app/db/seed.sql
RUN mkdir -p /app/storage && chown app:app /app/storage

USER app
ENV PORT=3000
ENV BLOG_DB=/app/storage/development.sqlite3
EXPOSE 3000
VOLUME ["/app/storage"]

ENTRYPOINT ["/app/blog"]
