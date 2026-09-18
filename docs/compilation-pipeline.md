# Backoffice compilation pipeline

```mermaid
flowchart LR
    source["Backoffice Rails source"] --> analysis["Roundhouse ingest and type analysis"]
    schema["Schema, routes, models, views and Gemfile.lock"] --> analysis
    analysis --> gate{"Zero errors and zero coverage gaps?"}

    gate -->|"No"| report["Compatibility report and logs"]
    report --> fixes["Fix source or extend Roundhouse"]
    fixes --> analysis

    gate -->|"Yes"| emit["Roundhouse spinel target"]
    emit --> lowered["Lowered Ruby app and SQLite runtime"]
    lowered --> spinel["Spinel whole-program type inference"]
    spinel --> ccode["Generated C"]
    ccode --> linker["C compiler with SQLite and jemalloc"]
    linker --> binary["Native HTTP server binary"]

    binary --> verify["Route, auth, database and response parity tests"]
    source --> verify

    analysis -. "Survey mode only" .-> survey["Emission with unsupported stubs"]
    survey -. "Not deployable" .-> report
```

The normal path is deliberately strict: Roundhouse must understand the source
before it emits code that Spinel can compile. The survey branch is useful for
seeing the full error inventory, but it may contain generated stubs and must
never be deployed or used as evidence of behavioural parity.
