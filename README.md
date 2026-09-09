# TableFlip

A free, native Mac app for opening local databases, browsing tables, searching records, and updating rows. TablePlus-like in daily use; unrestricted and easy to pick up.

See the [product requirements document](docs/PRD.md) for problem, scope, user journeys, and acceptance criteria.

## What works today

The product is a Swift package: **TableFlipCore** (tested on Linux and macOS) plus a **SwiftUI macOS app** under `Apps/TableFlip`.

- Open SQLite files, including drag-and-drop and Recents
- Browse tables and views, page, sort, and filter (`=`, `contains`, and the rest of the PRD operators)
- Stage inserts, updates, and deletes; Preview SQL; Commit in a transaction; Discard
- Query editor with a safety cap on unbounded `SELECT`s and Safe mode for writes
- Copy as TSV / CSV / JSON / Markdown / SQL INSERT; CSV import (staged then Commit)
- Saved connections store passwords in Keychain on Mac, never in the JSON file
- MIT licensed, no account, no feature flags

Open the package in Xcode on macOS 14+ and run the `TableFlip` executable target. File → Open, or drop a `.sqlite` file onto the welcome window.

## Tests

```bash
swift test
```

That runs unit tests for SQL generation, staging, the SQLite workspace, stores, and the north-star e2e journeys (open → filter → edit → commit → reopen).

Fixture databases live in `Fixtures/` (regenerate with `bash Scripts/make-fixtures.sh`).

## Architecture

- `Sources/TableFlipCore` — engines, filters, staging, workspace session. This is the product loop the UI drives.
- `Apps/TableFlip` — SwiftUI + AppKit Mac UI (welcome, workspace, grid, filters, query, commit review).
- GUI edits never write until Commit. Query-editor writes run immediately but honour Safe mode.

Postgres and MySQL **connection URLs, locality badges, Keychain, and a TCP probe** are in v1. A full remote query engine still uses the same `Workspace` contract; SQLite is the supported engine in this build.
