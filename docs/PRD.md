# TableFlip — Product Requirements Document

| Field | Value |
| --- | --- |
| Product | TableFlip (working title — see §20) |
| Platform | macOS (Apple Silicon and Intel) |
| Document type | Product Requirements Document |
| Status | Draft for implementation |
| Version | 0.1 |
| Last updated | 8 September 2026 |
| Related | [README](../README.md) |

---

## 1. Summary

TableFlip (working title; an existing Mac CSV/Markdown app already uses this name — see §20) is a free, native Mac app for opening local databases, browsing tables, searching records, and updating rows. It should feel as fast and familiar as TablePlus, without a paid licence, tab limits, or a cluttered Java/Electron UI.

The first release is a **local-first table browser**, not a full database IDE. A developer, designer, or data-curious teammate should be able to open a SQLite file (or a local Postgres/MySQL database), click a table, find a row, change a cell, and save — in under a minute, without writing SQL.

TablePlus remains the reference for interaction design: sidebar of objects, spreadsheet-like grid, column filters, staged edits with Commit / Discard, Open Anything, and a query editor for people who want SQL. TableFlip’s differentiator is that this core loop is complete, unrestricted, and free.

---

## 2. Problem

Mac developers already have options, and none of them hit the combination TableFlip is aiming for:

| Tool | Why it falls short for this job |
| --- | --- |
| **TablePlus** | Best daily driver on Mac, but the free tier is gutted (few tabs, limited connections, limited filters). Full licence is paid. |
| **DBeaver** | Free and powerful, but Java/Eclipse: slow to start, heavy RAM, non-native Mac UI. |
| **DataGrip** | Excellent SQL IDE; subscription, overkill for browsing and editing rows. |
| **Sequel Ace** | Free and native, but MySQL/MariaDB only, and development has slowed. |
| **Beekeeper Studio** | Solid and partly free, but Electron, and paid features sit on the happy path. |
| **DB Browser for SQLite** | Fine for one SQLite file; not a multi-engine TablePlus-like client. |

People who just want to **open a local database, look at a table, search, and fix a row** are forced into either a paid native app or a slow, crowded free one.

---

## 3. Vision

> Open a local database like a spreadsheet. Search like Spotlight. Save like a document. Stay as safe as a GUI should be with production-shaped data.

TableFlip is the Mac app you keep in the Dock next to your editor. It is not trying to replace `psql`, DataGrip, or an admin console. It is trying to make the 90% daily loop — open, browse, find, edit, save — feel obvious.

---

## 4. Goals and non-goals

### 4.1 Goals (v1)

1. Open a local SQLite file in one gesture (Open, drag-and-drop, or double-click).
2. Connect to Postgres, MySQL, and MariaDB running on localhost.
3. List databases, schemas, tables, and views, and open any of them quickly.
4. View table data in a fast, native grid with paging, sort, and column visibility.
5. Search and filter records without writing SQL.
6. Insert, duplicate, update, and delete rows with **staged commits** (nothing hits the database until the user commits).
7. Run ad-hoc SQL in a simple query editor and see results in the same grid.
8. Ship as a **free** app with no artificial limits on tabs, connections, or filters.
9. Feel native: AppKit/SwiftUI, macOS conventions, keyboard-first, light and dark mode.

### 4.2 Non-goals (explicitly out of v1)

- Remote / production ops as a first-class workflow (SSH tunnels, SSL client certs, cloud warehouses).
- NoSQL (Redis, MongoDB, Cassandra, DynamoDB).
- Schema design suite (visual ER diagrams, migrations, schema diff/sync).
- Team features (shared connections, licence servers, AI query generation).
- Windows, Linux, or iOS.
- Plugin marketplace.
- Dashboards / metrics boards.
- Replacing `mysqldump` / backup products.

These may appear later. They must not delay the browse–search–edit loop.

---

## 5. Target users

| Persona | Job to be done | Frequency |
| --- | --- | --- |
| **App developer** | Inspect local SQLite / Postgres while building a feature; fix a fixture row; check a migration actually landed. | Daily |
| **Indie / full-stack** | Peek at the local DB without leaving the Mac, without paying for TablePlus. | Daily |
| **QA / support** | Confirm a record exists, search by email or ID, update a flag. | Several times a week |
| **Designer / PM (technical)** | Open a dump or SQLite file and see real content without learning SQL. | Occasional |

Primary: developers on macOS with local databases.  
Secondary: anyone handed a `.sqlite` / `.db` file who just wants to look inside.

---

## 6. Positioning

**Category:** Native Mac database GUI (table browser + light SQL).

**Category entry point:** “TablePlus, but free, and local-first.”

**Promise:** The TablePlus daily loop — open database, open table, filter, edit cells, commit — with no paywall.

**Not competing on:** enterprise driver coverage, query refactoring, or DBA tooling.

---

## 7. Product principles

1. **Local-first.** Opening a file is the happy path. Connection forms exist, but a SQLite file should never require filling in host/port/user.
2. **Spreadsheet, not IDE.** The grid is the product. SQL is an escape hatch.
3. **Nothing writes until Commit.** GUI edits are staged, previewable, and discardable. This is a safety feature, not a power-user extra.
4. **Native and quiet.** No Java splash screens, no Electron chrome, no 40-icon toolbars. Follow macOS Human Interface Guidelines.
5. **Free means complete.** No tab caps, no “advanced filter” paywall, no nag screens. If a feature is in the app, it works.
6. **Keyboard-first.** Every frequent action has a shortcut. Open Anything is a first-class command.
7. **Honest about danger.** Destructive SQL and bulk deletes are obvious. Safe mode is one click, not buried in prefs.
8. **Fast on large tables.** Never load an entire table into memory. Page, stream, and keep the UI responsive.

---

## 8. Release plan

### 8.1 MVP (must ship)

The smallest product that is genuinely useful and feels like TablePlus for local work.

- SQLite file open (Open dialog, drag-and-drop, Recent files, “Open with”).
- Sidebar of tables and views.
- Data grid with paging, sort, column resize/reorder, type-aware rendering.
- Filter bar (column + operator + value; multiple filters ANDed).
- Cell search within the current result set.
- Staged insert / update / delete; Commit, Discard, Preview SQL.
- Query editor: syntax highlighting, run current / run all, results grid.
- Light and dark appearance; standard Mac window/tab behaviour.

### 8.2 v1 (complete local client)

Everything in MVP, plus:

- Local Postgres, MySQL, MariaDB connections (saved in Keychain).
- Multiple windows and tabs per connection.
- Open Anything (`⌘P`).
- Structure view (columns, types, nullability, defaults, PK/FK — read-only in v1 if needed).
- Copy rows as CSV / JSON / SQL INSERT.
- Export current table or current result set.
- Import CSV into the current table (staged, then commit).
- NULL vs empty-string distinction; JSON pretty preview; dates/booleans rendered clearly.
- Safe mode (warn before write queries).
- Query history.

### 8.3 Later (explicitly not blocking v1)

- SSH tunnel, TLS, Unix sockets beyond defaults.
- Remote hosts with a clear “this is not local” warning.
- Create / alter / drop table from the GUI.
- DuckDB, SQL Server, CockroachDB.
- SQL autocomplete from schema.
- Foreign-key jump (click FK → open referenced row).
- macOS Quick Look plugin; Spotlight importer.
- iCloud of saved connections (credentials stay in Keychain).

---

## 9. User journeys

### 9.1 Open a SQLite file and fix a row (north-star)

1. User double-clicks `app.sqlite` or chooses **File → Open**.
2. TableFlip opens a window. Sidebar lists tables. The first table (or last-used table) is selected.
3. Grid shows the first page of rows immediately.
4. User types in the search field or adds a filter `email contains @example.com`.
5. User double-clicks a cell, changes a value. The row highlights as dirty.
6. User presses `⌘S`. A compact review sheet lists the pending `UPDATE`. User confirms.
7. Grid refreshes that row. No toast spam; the dirty highlight clears.

**Success:** first useful edit in under a minute, zero SQL required.

### 9.2 Connect to local Postgres

1. Welcome screen: **Open File…** and **New Connection**.
2. User picks PostgreSQL. Host defaults to `127.0.0.1`, port `5432`.
3. User enters database name and role. Password stored in Keychain.
4. Connection appears on the welcome grid with a colour and engine badge.
5. Same browse / filter / edit loop as SQLite.

### 9.3 Ad-hoc query

1. From a connection window, `⌘E` opens the SQL editor (split or tab).
2. User writes `SELECT * FROM orders WHERE status = 'failed' LIMIT 50`.
3. `⌘↩` runs the statement under the cursor.
4. Results appear in the grid. Cells are editable if the result is a simple updatable select (best-effort); otherwise the grid is read-only and the UI says so.

### 9.4 “I almost wrecked the table”

1. User selects 200 rows and presses Delete. Rows mark as pending delete (not gone).
2. Preview shows `DELETE FROM … WHERE id IN (…)`.
3. User presses Discard. Grid returns to the previous state.
4. If they had Safe mode on, Commit would have required an extra confirm.

---

## 10. Information architecture

### 10.1 Welcome window

- Recents: files and saved connections, with engine, path/host, last opened.
- Actions: **Open Database File…**, **New Connection**, **New SQLite Database**.
- Context menu: Remove from recents, Reveal in Finder (files), Duplicate connection.
- Empty state copy: “Open a SQLite file, or connect to Postgres or MySQL on this Mac.”

### 10.2 Connection window (workspace)

Three regions, resizable, persist layout per connection:

```
┌─────────────┬──────────────────────────────────────────────┐
│ Sidebar     │ Toolbar: Commit · Discard · Preview · Safe   │
│ Tables      │          Open Anything · Query · Refresh    │
│ Views       │─────────────────────────────────────────────│
│ (Schemas)   │ Data grid  /  Structure  /  Query results  │
│             │                                              │
│             ├──────────────────────────────────────────────┤
│             │ Filter bar  ·  Status (rows, page, time)    │
└─────────────┴──────────────────────────────────────────────┘
```

Optional right inspector (`Space`): current row as a form, one field per column. Useful for wide tables.

### 10.3 Tabs and windows

- Multiple connection windows.
- Tabs inside a window: tables, query editors, result sets.
- `⌘T` new tab, `⌘W` close tab, `⌘N` new window.
- No artificial cap on tabs or windows.

---

## 11. Functional requirements

Priorities: **P0** = MVP, **P1** = v1, **P2** = later.

Acceptance criteria are written so they can be automated or used as manual test scripts (TDD for the product).

### 11.1 Opening databases

| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| **O-1** | Open SQLite via File → Open | P0 | Choosing a `.sqlite`, `.db`, `.sqlite3` file opens a workspace. Invalid files show a clear error, not a crash. |
| **O-2** | Drag-and-drop onto Dock icon or welcome window | P0 | Dropping a SQLite file opens it. Multiple files open multiple windows. |
| **O-3** | Open With / file association | P0 | TableFlip can be set as the default app for `.sqlite` / `.db`. Double-click in Finder opens the file. |
| **O-4** | Recents | P0 | Last 20 files/connections on the welcome screen. Missing files show as unavailable, not a crash. |
| **O-5** | New blank SQLite database | P0 | User picks a path; an empty database is created and opened. |
| **O-6** | Read-only files | P0 | If the file is locked or permissions deny write, the grid is read-only and Commit is disabled with an explanation. |
| **O-7** | Local Postgres connection | P1 | Host, port, user, password, database, optional SSL off by default. Test Connection before save. |
| **O-8** | Local MySQL / MariaDB connection | P1 | Same as O-7 with engine-appropriate defaults (`3306`, user `root`). |
| **O-9** | Saved connections | P1 | Saved locally; passwords in macOS Keychain only. Never written to disk in plaintext. |
| **O-10** | Connection URL paste | P1 | `postgresql://`, `mysql://`, `sqlite:///` paste into New Connection fills the form. |
| **O-11** | Unix socket (local) | P2 | Optional socket path for local MySQL/Postgres. |

### 11.2 Sidebar and navigation

| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| **N-1** | List tables and views | P0 | Sidebar lists user tables and views for the current database, alphabetically, with a type icon. |
| **N-2** | Open table on click | P0 | Clicking a table loads the first page of data. Keyboard up/down + Return also works. |
| **N-3** | Filter sidebar | P0 | Typing in the sidebar search filters the object list. |
| **N-4** | Schema grouping | P1 | For Postgres, objects group by schema (`public` first). |
| **N-5** | Open Anything | P1 | `⌘P` fuzzy-finds tables, views, and (later) functions. Return opens the object. |
| **N-6** | Remember last table | P1 | Reopening a file/connection restores the last table and scroll/page offset when practical. |
| **N-7** | Refresh schema | P1 | `⌘R` reloads objects and current grid without dropping staged edits (warn if dirty). |

### 11.3 Data grid (view)

| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| **G-1** | Paged rows | P0 | Default page size 100 (user-adjustable: 50 / 100 / 300 / 1000). Offset control or prev/next. Never `SELECT *` the whole table. |
| **G-2** | Column headers | P0 | Show name and a subtle type hint. Resize, reorder. Double-click divider to auto-size. |
| **G-3** | Sort | P0 | Click header: desc → asc → unsorted. Indicator in the header. Sort is server-side for the current filter. |
| **N.B.** | Multi-column sort | P2 | Shift-click additional columns. |
| **G-4** | Type-aware cells | P0 | NULL is a distinct token (e.g. `NULL` in muted style). Booleans as checkboxes or `true`/`false`. Numbers right-aligned. Dates in ISO-like local display. JSON truncated with `{…}`. |
| **G-5** | Wide tables | P0 | Horizontal scroll; column freeze of primary key column optional in v1. Inspector (`Space`) shows the full row. |
| **G-6** | Selection | P0 | Cell, row, and multi-row selection. `⌘A` selects all **loaded** rows, not the entire table, and the status bar says so. |
| **G-7** | Copy | P0 | `⌘C` copies selected cells as TSV (Excel/Numbers-friendly). |
| **G-8** | Copy as… | P1 | Copy as CSV, JSON, Markdown table, SQL INSERT (selected rows). |
| **G-9** | Quick Look for large values | P1 | `Space` on a cell (or row inspector) pretty-prints JSON, shows long text, and offers “Save blob…”. |
| **G-10** | Row count | P1 | Status bar shows “showing 1–100 of ~N” using an estimate or exact count; expensive counts must not block the grid. |
| **G-11** | Virtualised rendering | P0 | Scrolling 1000 loaded rows stays smooth (≥60 fps on a recent MacBook for typical cell sizes). |
| **G-12** | Column visibility | P1 | Column picker (`⌥⌘F`) show/hide columns. State remembered per table. |

### 11.4 Search and filters

| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| **F-1** | Filter bar | P0 | `⌘F` focuses/toggles filters. Each filter is **column · operator · value**. |
| **F-2** | Operators | P0 | `=` `≠` `>` `≥` `<` `≤` `contains` `starts with` `is null` `is not null`. Numeric/date columns get numeric/date operators; text gets contains. |
| **F-3** | Multiple filters | P0 | Multiple filters combine with AND. Apply on Return. Unset restores unfiltered first page. |
| **F-4** | Generated SQL | P1 | A control shows the `WHERE` clause TableFlip will run. Read-only in MVP is fine. |
| **F-5** | Quick filter from header | P1 | Right-click column header → Filter… pre-fills that column. |
| **F-6** | In-grid find | P0 | `⌘G` / find bar highlights matches **in the loaded page** and can optionally “search all rows” which applies a contains filter on a chosen column or all text columns. |
| **F-7** | Raw SQL where | P2 | Power-user row: a single raw `WHERE` fragment. |

**Product decision:** “Search” in the toolbar is a simple contains-across-visible-columns on the current page, plus a one-click “search this column in the whole table” that becomes a filter. Do not pretend to grep a 10-million-row table in-memory.

### 11.5 Editing rows

This is the heart of the product. Behaviour must match TablePlus’s staged-edit model.

| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| **E-1** | Inline edit | P0 | Double-click (or Return) on a cell enters edit. Escape cancels the cell edit. Tab commits the cell to the **staging area** and moves right. |
| **E-2** | Staging | P0 | Edited cells/rows are visually marked (e.g. fill colour). The database is unchanged until Commit. Multiple cells and rows may be staged together. |
| **E-3** | Commit | P0 | `⌘S` or Commit. Opens a review of generated SQL (one statement per change, in a transaction). Confirm runs it. Success clears marks; failure rolls back the transaction and keeps staging, with the error shown. |
| **E-4** | Discard | P0 | Discard (or `⌘.`) drops all staged changes for the workspace after a confirm if more than one change. |
| **E-5** | Preview | P0 | Preview shows the exact SQL that Commit would run, copyable. |
| **E-6** | Insert row | P0 | `⌘I` or “+ Row” appends a pending insert. Defaults and nullable columns respected. Required columns without values block Commit with a field-level error. |
| **E-7** | Duplicate row | P1 | `⌘D` duplicates selected rows as pending inserts (primary key cleared or marked to be regenerated). |
| **E-8** | Delete row | P0 | Delete key marks selected rows as pending deletes (strikethrough). Commit runs `DELETE` in a transaction. |
| **E-9** | NULL editing | P0 | A control or `⌥⌫` sets NULL rather than empty string. Empty string is a distinct value for text columns. |
| **E-10** | Boolean / enum | P1 | Booleans toggle. Enum/check constraints appear as a dropdown when the engine exposes them. |
| **E-11** | Unsaved warning | P0 | Closing a tab/window with staged changes prompts Save / Discard / Cancel. |
| **E-12** | No primary key | P0 | Tables without a primary key: updates/deletes are allowed only if the user confirms a `WHERE` that uses all original column values, **or** editing is disabled with a clear explanation. Prefer the latter in MVP if ambiguous. |
| **E-13** | Row inspector edit | P1 | Inspector fields write into the same staging area as the grid. |
| **E-14** | Query-result edits | P1 | Editable only when TableFlip can identify a single base table and key. Otherwise read-only banner: “This result can’t be edited in the grid. Use SQL.” |

### 11.6 Query editor

| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| **Q-1** | Open editor | P0 | `⌘E` opens SQL editor for the current connection. |
| **Q-2** | Highlighting | P0 | SQL syntax highlighting. Monospaced font. |
| **Q-3** | Run | P0 | `⌘↩` runs the current statement (under cursor). Run All is available. Multiple result sets as tabs. |
| **Q-4** | Errors | P0 | Engine errors shown with message and position when available. The grid is not left in a mysterious empty state. |
| **Q-5** | Limit safety | P0 | Bare `SELECT * FROM huge` should not freeze the app. Stream/page results; default cap (e.g. 1000) with “Load more”. |
| **Q-6** | Write statements | P0 | `INSERT`/`UPDATE`/`DELETE`/`DDL` from the editor execute immediately (not via the staging area) but respect Safe mode (Q-8). |
| **Q-7** | History | P1 | Last N successful statements, searchable, re-runnable. |
| **Q-8** | Autocomplete | P2 | Table and column names from the current schema. |
| **Q-9** | Format SQL | P2 | One-shot pretty print. |

### 11.7 Safety

| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| **S-1** | Staged GUI writes | P0 | As E-2–E-5. This is the default safety net. |
| **S-2** | Safe mode | P1 | Toolbar lock. On: confirm before any write (GUI commit or editor write). SELECT/EXPLAIN do not prompt. |
| **S-3** | Transaction | P0 | A Commit of many GUI changes is one transaction. Failure = nothing applied. |
| **S-4** | No silent overwrite | P0 | If a row changed on disk since load (SQLite file mtime, or optional `xmin`/row version later), warn on Commit. MVP: warn if file mtime changed for SQLite. |
| **S-5** | Local-only banner for v1 connections | P1 | If host is not localhost / `127.0.0.1` / `::1` / a Unix socket, show a persistent “Remote host” badge. v1 may still allow it, but must not pretend it is local. |

### 11.8 Structure, import, export

| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| **T-1** | Structure tab | P1 | Columns: name, type, nullable, default, PK. Read-only is acceptable for MVP/v1. |
| **T-2** | Export table | P1 | Export full table or current filtered result as CSV, JSON, or SQL INSERT. Progress for large exports. |
| **T-3** | Import CSV | P1 | Map columns, first-row headers, staged rows then Commit. Errors per row, not a silent partial import. |
| **T-4** | Create / drop table GUI | P2 | Out of v1 unless cheap to add for SQLite only. |

### 11.9 App chrome and settings

| ID | Requirement | Priority | Acceptance criteria |
| --- | --- | --- | --- |
| **A-1** | Appearance | P0 | Follows system light/dark; optional in-app override. |
| **A-2** | Preferences | P1 | Page size, font size for grid and editor, “confirm on commit” default, file associations. |
| **A-3** | About / licence | P0 | Free. Open-source licence stated (recommendation: MIT). No account. |
| **A-4** | Updates | P1 | Sparkle or equivalent; optional check. No dark patterns. |
| **A-5** | Accessibility | P1 | VoiceOver labels on toolbar and grid; Dynamic Type where reasonable; colour not the only dirty-state signal (icon or “edited” mark too). |
| **A-6** | Privacy | P0 | No telemetry that includes query text, row data, or file paths. If anonymous usage stats exist later, they are opt-in. |

---

## 12. UX specification

### 12.1 Look and feel

- Native macOS window, toolbar, and sidebar (think TablePlus / Things / Finder, not DBeaver).
- Content-first: the grid uses the full remaining space.
- One accent colour for pending changes (e.g. amber for dirty, red for pending delete, green for pending insert). Must also work in colour-blind palettes (shape/icon).
- Welcome window is a single screen, not a wizard.

### 12.2 Empty and error states

| State | Copy direction |
| --- | --- |
| No recents | “Open a SQLite file to get started.” + button |
| Empty table | “This table has no rows.” + “Add row” |
| Filter matches nothing | “No rows match these filters.” + Unset |
| Cannot connect | Human error (wrong port, server down) with the engine message underneath |
| Corrupt SQLite | “This file isn’t a readable SQLite database.” |

### 12.3 Keyboard shortcuts (v1)

| Action | Shortcut |
| --- | --- |
| Open file | `⌘O` |
| New connection window | `⌘N` |
| New tab | `⌘T` |
| Close tab | `⌘W` |
| Open Anything | `⌘P` |
| Filter | `⌘F` |
| Query editor | `⌘E` |
| Run current statement | `⌘↩` |
| Commit | `⌘S` |
| Discard | `⌘.` or toolbar |
| Insert row | `⌘I` |
| Duplicate row | `⌘D` |
| Reload | `⌘R` |
| Toggle inspector | `Space` (when a row is selected and not editing) |
| Preferences | `⌘,` |

Shortcuts must be listed under the menus so users can discover them.

### 12.4 First-run

No account, no tutorial overlay. First launch = welcome window. Optional one-time note in the data view: “Changes are not saved until you press Commit (⌘S).” Dismiss forever.

---

## 13. Data types and engine notes

### 13.1 SQLite (P0)

- Support typical affinity: INTEGER, REAL, TEXT, BLOB, NUMERIC, and declared types (`BOOLEAN`, `DATETIME`, `JSON` as text).
- WAL files: open the main database file; do not confuse users with `-wal` / `-shm`.
- Attached databases: P2.
- Display `rowid` when there is no INTEGER PRIMARY KEY alias, for update identity.

### 13.2 PostgreSQL (P1)

- Default database list from the connection; switch database without a new window if cheap, else a connection setting is enough.
- Types: `int`, `bigint`, `numeric`, `text`, `varchar`, `bool`, `timestamptz`, `json`/`jsonb`, `uuid`, arrays (render as text, edit as text in v1).
- Schemas other than `public`.

### 13.3 MySQL / MariaDB (P1)

- Database (schema) switcher.
- Common types including `json`. Strict SQL mode errors must surface in Commit.

---

## 14. Non-functional requirements

| ID | Area | Requirement |
| --- | --- | --- |
| **NF-1** | Startup | Cold start to welcome window &lt; 1.5s on a recent M-series Mac. |
| **NF-2** | Open SQLite | First page of a 1M-row table visible &lt; 500ms after file open (local SSD, simple schema). |
| **NF-3** | Memory | Idle workspace &lt; 150 MB; browsing a large table must not grow unboundedly (page, don’t cache all rows). |
| **NF-4** | Architecture | Native Mac app (Swift + AppKit and/or SwiftUI). Not Electron, not JVM. |
| **NF-5** | OS | macOS 14+ (adjust only if there is a strong reason). Universal binary. |
| **NF-6** | Sandbox | Prefer a Developer ID / notarised app. App Store sandbox is optional; file access via Open panel and security-scoped bookmarks for recents. |
| **NF-7** | Offline | Fully offline. No network required to open a file. |
| **NF-8** | Crash safety | SQLite writes only via transactions. A crash during Commit must not half-apply GUI batches. |
| **NF-9** | Localisation | English (UK copy in product UI as default) for v1; architecture should allow later locales. |
| **NF-10** | Distribution | Free download; source public. Licence: MIT recommended. |

---

## 15. Technical recommendations (non-binding)

These are guidance for engineering, not product constraints except where they protect NFRs.

- **UI:** SwiftUI for welcome and inspector; AppKit `NSTableView` (or a proven virtualised grid) for the data table. Do not use a WebView grid.
- **SQLite:** `SQLite.swift` or GRDB, or thin `libsqlite3` wrapper. Read-only connection for the grid plus a write connection for Commit, or a single connection with explicit transactions.
- **Postgres:** `PostgresNIO` or `libpq`. **MySQL:** `mysql-nio` or libmysqlclient. Keep a small `DatabaseEngine` protocol: list objects, page rows, apply a batch of mutations, run SQL.
- **Identity for updates:** Prefer primary key. Fallback to `rowid` on SQLite. Refuse unsafe updates on keyless MySQL/Postgres tables (E-12).
- **Bookmarks:** Store security-scoped bookmarks for SQLite recents so reopening works after relaunch.
- **Testing:** See §17. Logic (SQL generation, filter encoding, staging diff) must be unit-tested without UI.

---

## 16. Success metrics

No row content or SQL text is collected. If metrics exist, they are opt-in.

**Launch (qualitative + local analytics only):**

- A new user can complete journey 9.1 without a manual.
- Commit of a single cell round-trips correctly on SQLite, Postgres, and MySQL fixtures.
- Zero “unlimited” features locked.

**Product-market fit signals (once distributed):**

- GitHub stars / Homebrew installs as a proxy for “I actually use this”.
- Issues tagged `table-browser` vs `sql-editor` — if the editor dominates, the grid is not good enough.
- Repeat open of Recents (if opt-in telemetry): people come back.

**Quality bar:**

- No data-loss bugs in the staging/commit path. Any such bug is P0, stop-ship.

---

## 17. Testing strategy (TDD)

Product rule: **behaviour is specified as tests first**, especially around SQL generation and staging.

### 17.1 Unit tests (mandatory before UI polish)

| Area | Examples |
| --- | --- |
| Filter → SQL | `contains` on text → `column LIKE '%' || ? || '%'` with bound parameters (never string-concat user values). |
| Staging diff | Edit cell → `UPDATE t SET c = ? WHERE pk = ?`. Insert → `INSERT`. Delete → `DELETE WHERE pk = ?`. |
| NULL vs `""` | Setting NULL emits `NULL`, not empty string. |
| Pagination | `LIMIT/OFFSET` (or keyset) matches page size. |
| Engine dialect | Identifiers quoted correctly for SQLite / Postgres / MySQL. |

### 17.2 Integration tests

- Temp SQLite files: open, page, filter, commit, reopen, assert bytes/rows.
- Docker or local Postgres/MySQL in CI for P1 engines.
- File permission / read-only path.

### 17.3 UI tests (smoke)

- Open fixture `users.sqlite`, filter `email contains a`, edit a cell, commit, relaunch, value persists.
- Discard restores original values.
- Query editor `SELECT` shows rows; `UPDATE` with Safe mode requires confirm.

### 17.4 Fixtures

Ship small fixtures in-repo: empty DB, wide table (80 columns), 10k-row table, table without PK, JSON column, NULL-heavy table.

---

## 18. Competitive comparison (v1 scope)

| Capability | TableFlip v1 | TablePlus | DBeaver CE | Sequel Ace |
| --- | --- | --- | --- | --- |
| Native Mac | Yes | Yes | No | Yes |
| Free, unlimited tabs | Yes | No | Yes | Yes |
| SQLite file open | Yes (primary) | Yes | Yes | No |
| Local Postgres / MySQL | Yes | Yes | Yes | MySQL only |
| Staged cell edits | Yes | Yes | Limited | Partial |
| Query editor | Yes (simple) | Yes | Yes | Yes |
| SSH / remote | Later | Yes | Yes | Yes |
| ER diagrams | No | No | Yes | No |

---

## 19. Risks

| Risk | Mitigation |
| --- | --- |
| Grid performance on huge tables | Pagination + virtualisation; never full-table load. |
| Unsafe updates without PK | Disable or require full-row WHERE; never update-by-display-index. |
| SQL injection via filters | Bound parameters only. |
| Users think TableFlip is TablePlus | Distinct name, icon, and copy. Do not clone trademarks or assets. |
| Scope creep into “full DBA tool” | Non-goals in §4.2; new engines only after the SQLite loop is excellent. |
| App Store sandbox vs sockets | If App Store is desired later, document entitlements; Developer ID first. |
| Legal: “like TablePlus” | Independent implementation. No TablePlus code, icons, or docs copied into the product. |

---

## 20. Open questions

1. **App Store vs direct download first?** Recommendation: Developer ID + Homebrew Cask first; App Store once entitlements are proven.
2. **Should v1 allow non-localhost TCP at all?** Safer default: allow but badge heavily (S-5). Alternatively, block remote until SSH exists.
3. **Editable query results:** How hard to do well? If not reliable, ship read-only results in MVP without shame.
4. **Default page size 100 vs 300?** 100 is snappier; power users will raise it. Start at 100.
5. **Licence:** MIT vs GPL. Recommendation: MIT to maximise adoption.
6. **Name confirmation:** The repo currently uses **TableFlip**. That name is already taken by a shipping Mac App Store product ([tableflipapp.com](https://tableflipapp.com/)) — a Markdown/CSV table editor. Same platform, adjacent “tables on a Mac” category, so it is a real collision (search, App Store listing, and word of mouth). Treat **TableFlip as a working title only**. Pick a distinct name before public launch (examples of direction, not decisions: TableLite, OpenTable, DockDB, LocalBase). Do not ship under TableFlip without legal clearance.

---

## 21. MVP checklist (definition of done)

A build can be called MVP when all of the following are true:

1. User can open a SQLite file from Finder, the Open dialog, and drag-and-drop.
2. User can see tables, open one, scroll a page of rows, sort a column, and filter with at least `=` and `contains`.
3. User can edit a cell, insert a row, delete a row, Preview SQL, Commit, and Discard — with tests covering SQL generation.
4. User can run a `SELECT` in the query editor and see results.
5. Dirty close prompts to save or discard.
6. Light and dark mode both usable.
7. No crash on corrupt file, empty database, or table with zero columns/rows.
8. Documented as free, with no feature flags that look like a trial.

v1 additionally requires local Postgres and MySQL, Open Anything, copy/export, Safe mode, and Keychain-backed saved connections.

---

## 22. Appendix A — Suggested screen inventory

1. Welcome / recents  
2. New Connection sheet (engine-specific)  
3. Workspace — data  
4. Workspace — structure  
5. Workspace — query editor  
6. Filter bar (attached to data)  
7. Commit review sheet  
8. Inspector (right sidebar)  
9. Preferences  
10. Save / Discard on close (system alert)

---

## 23. Appendix B — What “like TablePlus” means here

Copy these interaction ideas (not assets):

- Sidebar of tables; click to browse.
- Spreadsheet grid; double-click to edit.
- Filters as column + operator + value, not a search-only box.
- Changes stay local until Commit (`⌘S`); Discard is always available.
- Open Anything (`⌘P`).
- Query editor beside the grid, not a separate application.
- Safe mode for write confirmation.

Do **not** copy:

- TablePlus branding, icons, marketing copy, or documentation text.
- Paid-tier paywalls.
- Metrics boards, plugin marketplace, or iOS companion as part of v1.

---

## 24. Glossary

| Term | Meaning |
| --- | --- |
| **Workspace** | A window bound to one open file or connection. |
| **Staging** | In-memory pending inserts/updates/deletes not yet sent to the engine. |
| **Commit** | Apply the staging area in a single transaction. |
| **Local database** | A SQLite file on disk, or a server on localhost / Unix socket. |
| **Open Anything** | Fuzzy command palette for database objects. |
