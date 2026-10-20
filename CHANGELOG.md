# Change Log

All notable changes to this project will be documented in this file.
This project adheres to the [Semantic Version](https://semver.org/) guideline.

## [Version] - yyyy-mm-dd

Here we write upgrading notes and make them as straightforward as possible.

### Added
- A short description for added item 1
- A short description for added item 2
- A short description for added item n

### Changed
- A short description for changed item 1
- A short description for changed item 2
- A short description for changed item n

### Fixed
- A short description for fixed item 1
- A short description for fixed item 2
- A short description for fixed item n


## [v1.2.0] - 2026-10-20

Internal code refactoring, better documentation, and Zig-0.17.0 version support.

### Added
- Statement reuse interface on the `CRUD` module: `reset()` (backed by
  `sqlite3_reset()` and `sqlite3_clear_bindings()`) releases a compiled
  statement for re-execution without the `prepare()` recompilation cost
- Automatic statement reset before every CRUD execution, so a single
  `prepare()` call can be reused across repeated `exec`, `readOne`,
  `readMany`, `count` and `remove` calls. Mid-scan statements are left
  untouched, preserving progressive `readOne()` retrieval loops
- `test` build step covering the unit tests

### Changed

- Removed type requirement from Record Create in `builder.zig`
- Empty Model/View structures and empty `group()`, `when()` or `sort()`
  token lists now fail with a clear compile-time error instead of an
  integer underflow panic
- `in` / `!in` placeholder counts below `1` now fail with a clear
  compile-time error

### Fixed
- Filtered `readOne()`, `readMany()`, `count()` and `exec()` now always
  `reset()` the statement before binding — SQLite refuses to bind parameters
  to a mid-scan statement (`SQLITE_MISUSE`), so back-to-back filtered reads on
  a reused statement failed on every call after the first. Unfiltered reads
  keep their progressive cursor state
- `BlobStream.write()` now rejects read-only streams with `error.Locked`
  before touching SQLite, matching the documented contract. Previously the
  call reached SQLite, came back as an unmapped `SQLITE_READONLY`
  (`error.UnknownError` plus an error log), and left the blob handle aborted —
  making the subsequent `blob_close()` fail as well
- The error converter now maps `SQLITE_READONLY` to `Error.Locked` instead of
  logging and returning `error.UnknownError`
- Test suite fixes: `root.zig` now collects the tests (the suite previously
  ran zero tests), the statement-reuse test table uses `INTEGER PRIMARY KEY`
  so the view does not read `NULL` ids, and the progressive scan test dupes
  row strings before the row memory is freed
- `Record.find().skip()` now requires a preceding `limit()` clause at
  compile-time — SQLite rejects `OFFSET` without `LIMIT`
- `convertTo()` now returns `error.MismatchedFields` when the retrieved
  columns don't cover every field of the given View structure, instead of
  silently leaving unmatched fields `undefined`
- `Container.fieldRemove()` no longer leaks the internal `exec()` results
- `readMany()` no longer leaks partially converted records when row
  conversion fails mid-scan
- `typeCast()` no longer leaks JSON-serialized values when the parameter
  list append fails
- `BlobStream.write()` returns `error.InvalidOffset` for out-of-bounds
  offsets instead of panicking on a debug assertion
- Documentation: fixed the `Dt.slice` typo in the Filter schema example

## [v1.1.0] - 2026-02-22

Upgrading `Jsonic` to version 1.5.0 and Adding build flag for `SQLite JSON` manipulation.

## [v1.0.0] - 2025-09-15

Initial bare minimum implementation with CURD Interface, Compile-Time Query Builder, Blob Stream Interface, and some builtin helper functions.
