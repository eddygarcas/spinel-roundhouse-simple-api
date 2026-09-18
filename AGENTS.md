# Binary API / Backoffice Compilation Guide

## Mission

This repository is the integration workspace for evaluating whether the
`rzilient-club/backoffice` Rails application can be transformed by
[Roundhouse](https://github.com/rubys/roundhouse) into a Spinel-backed native
binary. The intended deliverable is a reproducible build and an evidence-based
compatibility report; it is **not** a claim that an arbitrary Rails application
can be compiled unchanged.

Roundhouse is the Rails-aware source analyzer/transpiler. Spinel is the
Ruby-ahead-of-time compiler that turns the Ruby-shaped output of Roundhouse
into a standalone native executable. Do not try to compile the original Rails
application directly with `spinel`.

## Workspace layout

Keep source, tooling, generated output, and notes separate:

```text
backoffice/              # Git checkout of rzilient-club/backoffice
roundhouse/              # Pinned upstream Roundhouse checkout
spinel/                  # Pinned upstream Spinel checkout
artifacts/               # Generated source, logs, reports, and binaries
docs/                    # Decisions, compatibility inventory, runbooks
```

Never edit the upstream compiler checkouts except when explicitly working on an
upstream patch. Keep local integration scripts and project-specific adapters in
this repository. Generated files and cloned repositories must not be committed
unless a later task explicitly asks for a reproducible vendored snapshot.

## Working rules

1. Inspect the current working tree and existing instructions before changing
   anything. Preserve uncommitted user work.
2. Pin every clone/build to a recorded commit SHA. Record the operating system,
   compiler, Rust, Ruby, Bundler, Roundhouse, and Spinel versions in a dated
   report under `docs/` or `artifacts/`.
3. Treat `backoffice` as the behavioral source of truth. Do not “fix” source
   compatibility by silently removing endpoints, authorization, validations,
   jobs, or database behavior.
4. Never print, commit, or copy secrets from Rails credentials, `.env` files,
   database URLs, API keys, or production configuration. Use local disposable
   configuration for experiments.
5. Do not run database migrations, destructive tasks, seed resets, or network
   deployment commands without explicit user approval. Compilation work must
   use an isolated development/test database.
6. Prefer small, reproducible scripts over undocumented manual commands. Each
   script must fail clearly and write outputs below `artifacts/`.

## Required workflow

### 1. Baseline the Rails application

Before compilation work, document how to install dependencies, boot the app,
run its relevant tests, and exercise at least one representative HTML and/or
JSON endpoint. Resolve only setup blockers that are needed to establish this
baseline.

### 2. Analyze before attempting an emit

Build Roundhouse using its documented prerequisites (Rust plus `clang` and
`libclang` on Debian/Ubuntu), then run its checker against the Backoffice
checkout in continuation mode:

```bash
cargo run --release --bin roundhouse-check -- --continue /path/to/backoffice
```

Save the complete diagnostics and classify every item as one of:

- unsupported ingestion/lowering coverage in Roundhouse;
- a Ruby/Rails construct that needs a project-specific rewrite;
- external runtime dependency (database, Redis, Active Job, mailer, API);
- environment/setup failure; or
- confirmed application defect.

Do not describe a target as compilable until the relevant diagnostics are
resolved or have an explicit, user-approved scope exclusion.

### 3. Emit through Roundhouse, then compile with Spinel

Use Roundhouse's `spinel` target and its matching runtime/scaffold. Compile
only the emitted/lowered program with a pinned Spinel build. Keep the emitted
tree, compiler command, stderr, and resulting executable under a uniquely
named `artifacts/` directory. Do not hand-edit generated output; fix the
source, a documented transformation, or Roundhouse instead.

### 4. Verify behavior, not merely a successful compile

For each successful build, verify all applicable layers:

- the native executable starts with explicitly supplied non-secret test config;
- representative routes return the same status, headers, and canonical JSON or
  DOM as Rails;
- authentication/authorization failures remain failures;
- database reads/writes and validation errors behave equivalently in an
  isolated test database; and
- a repeat build from the recorded revisions produces the same result (or any
  non-determinism is documented).

Roundhouse's differential comparison tooling is preferred when it supports the
route. For uncovered behavior, add a focused black-box comparison rather than
relying on manual browser inspection.

## Reporting and completion criteria

Every meaningful attempt must leave a concise report stating:

- the exact source and tool revisions;
- commands run and their exit status;
- supported and unsupported Backoffice surfaces;
- binary location, checksum, size, and host platform when produced;
- behavioral test evidence; and
- the next smallest compatibility task, if any.

“Build succeeded” alone is not completion. The project reaches its initial
goal only when a reproducible binary can serve an agreed representative
Backoffice scope with documented parity against Rails, or when the remaining
compiler coverage gaps have been evidenced well enough to make a clear
go/no-go decision.
