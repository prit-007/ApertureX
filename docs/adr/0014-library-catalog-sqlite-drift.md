# ADR 0014 — Local library catalog: SQLite via Drift

- **Status:** Accepted
- **Date:** 2026-10-17
- **Deciders:** Developer's Paradise
- **Consults:** ADR 0003 (Non-destructive recipe model), ADR 0004 (GPL-3 and F-Droid distribution), Issue #73, Issue #84, Issue #85

---

## 1. Context

The library catalog is the app's local index of open/editable items:
`entryId → CatalogEntry` (source asset id, kind, label/rating/flag, creation
time, and the item's `EditRecipe`). It started as a single `library.json` with
a versioned envelope and atomic publish (write to `library.json.tmp`, then
rename) — crash-safe, but with real costs as the library grew:

- **Every mutation rewrote the entire file** (O(n) per debounced flush), with
  no partial update or index.
- **No query story**: search, rating filters, kind filters, and the Edits
  gallery's listing (#85) would all become full-file scans in Dart.
- **No migration story**: schema changes meant versioned-envelope readers
  forever, with no `schemaVersion` + upgrade path.
- **Single-writer discipline** had to be enforced by convention around one
  shared file.

Constraints that any replacement must satisfy (ADR 0004, ADR 0010):
fully offline and app-private (no cloud, no sync), F-Droid build-from-source
clean, and preferably a pure-Dart dependency rather than more platform
channel surface.

## 2. Decision

Persist the catalog in **SQLite through Drift** (`drift` + `sqlite3_flutter_libs`,
code-gen via `drift_dev`) — file `catalog.sqlite` in the application documents
directory, `schemaVersion 1`, opened with Drift's `NativeDatabase`
(`app/lib/edit/catalog_db.dart`).

1. **Keep the store seam.** `LibraryCatalogStore` (`load() → Map`, `save(Map)`)
   stays the abstraction. `libraryCatalogStoreProvider` now resolves to
   `DriftLibraryCatalogStore` in production; `JsonLibraryCatalogStore` remains
   as a second implementation (tests, and a future one-time import of any
   pre-existing `library.json`). Only the bytes on disk change — the
   in-memory `LibraryCatalog` notifier, its 300 ms debounced write-through,
   and its hydrate-merge (memory wins) rules are untouched.
2. **Recipes travel as a JSON text column** (`recipeJson`), not as normalized
   relations. The recipe is a deeply nested document that already carries its
   own `schemaVersion` (ADR 0003) and evolves on its own cadence; the DB
   schema tracks catalog metadata only, so recipe changes never force a DB
   migration.
3. **Snapshot-save semantics are preserved.** `save()` deletes all rows and
   batch-inserts the map inside one transaction — exact behavioral parity
   with the JSON store, so both implementations satisfy the shared
   `LibraryCatalogStore` tests. Row-level delta writes are a future
   optimization, not a redesign.
4. **Gallery previews live in the same database.** The `EditPreviews` table
   (entryId → render path, dimensions, `recipeHash`, created) carries the
   Edits gallery's explicit-save renders (#85) transactionally alongside the
   catalog rows.
5. **One connection, owned by Riverpod.** `catalogDbProvider` is a singleton
   closed on dispose; corrupt rows are skipped on load, preserving the
   library-tolerance rule from the JSON era ("one bad row must not cost the
   whole library").

## 3. Alternatives considered

- **Keep `library.json`.** Simple, dependency-free, and crash-safe, but keeps
  the O(n) rewrite, offers no indexing, and has no schema-migration tooling.
  Retained as a store implementation for tests/legacy import; rejected as the
  primary store.
- **Hive (or similar key-value boxes).** Fast, but a binary key-value format
  with no relational queries, no SQL, and its own serialization story — the
  gallery/search work ahead would be rebuilt by hand.
- **Raw `sqflite`.** Real SQLite, but untyped string SQL with no codegen, no
  compile-time column safety, and no schema-diff tooling — strictly more
  hand-written surface for the same result.
- **Isar.** Promising API, but effectively stalled upstream and a non-SQLite
  storage engine with its own migration/serialization story; not worth the
  long-term maintenance risk for a project that must stay F-Droid-clean.

## 4. Consequences

**Positive**
- Transactional integrity and indexed, typed queries (search, rating, kind,
  gallery listing) become cheap; Drift's `MigrationStrategy` gives future
  schema versions an explicit upgrade path.
- Fully local, app-private file — F-Droid offline rules hold; both
  dependencies are MIT and already ledgered in `THIRD_PARTY.md`.
- One transactional store for catalog rows *and* gallery previews.
- The store seam keeps the JSON implementation testable and gives pre-release
  users a migration path if a `library.json` exists.

**Negative / risks**
- `save()` still rewrites all rows per flush — accepted for parity; delta
  writes if profiling ever shows the flush cost matters.
- Recipe blobs are opaque to SQL: recipe-level queries ("entries with crop")
  would need SQLite JSON functions or extracted columns later.
- `sqlite3_flutter_libs` bundles a native SQLite per platform — covered by
  the existing Android APK and unsigned iOS CI builds.
- Two store implementations can drift apart — the shared
  `LibraryCatalogStore` test suite must keep passing against both.

## 5. Follow-ups

- One-time import of any pre-existing `library.json` into SQLite before the
  JSON path is retired (the seam makes it possible; the wiring is not needed
  while the app is a single-user pre-release).
- Delta/partial writes if catalog flush cost shows up in traces.
- Search and filters over the indexed columns; `schemaVersion 2` migrations
  as the catalog grows (e.g. sidecar paths, XMP association).
