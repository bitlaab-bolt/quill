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


## [v1.2.0] - 2026-10-10

Internal code refactoring, better documentation, and Zig-0.17.0 version support.

### Added
- Statement reuse interface on the `CRUD` module: `reset()` (backed by
  `sqlite3_reset()` and `sqlite3_clear_bindings()`) releases a compiled
  statement for re-execution without the `prepare()` recompilation cost
- Automatic statement reset before every CRUD operation, so a single
  `prepare()` call can be reused across repeated `exec`, `readOne`,
  `readMany`, `count` and `remove` calls
- `test` build step covering the unit tests

### Changed

- Removed type requirement from Record Create in `builder.zig`

## [v1.1.0] - 2026-02-22

Upgrading `Jsonic` to version 1.5.0 and Adding build flag for `SQLite JSON` manipulation.

## [v1.0.0] - 2025-09-15

Initial bare minimum implementation with CURD Interface, Compile-Time Query Builder, Blob Stream Interface, and some builtin helper functions.
