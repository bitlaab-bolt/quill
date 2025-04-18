# Builtin Modules

Builtin modules contains database agnostic utility for SQLite. Let's import builtins on your zig file.

```zig
const Builtins = quill.Builtins;
```

## Index

### Create

Creates an user defined index for a given container field.

```zig
try Builtins.Index.create(&db, "idx_name1", "users", "name1", .Default);

```

### Remove

Removes an existing user defined index.

```zig
try Builtins.Index.remove(&db, "idx_name1");
```

### Index List

Gets all available indices from a given container.

```zig
const idxs = try Builtins.Index.getList(heap, &db, "users");
defer Builtins.Index.freeList(heap, idxs);

for (idxs) |idx| {
    std.debug.print(
        "Name: {s}\nSN: {d}\nOrigin: {any}\nUnique: {}\nPartial: {}\n\n",
        .{idx.name, idx.sn, idx.origin, idx.unique, idx.partial}
    );
}
```

## Container

### Rename

Renames an existing container. Be cautious about the existing code breakage.

```zig
try Builtins.Container.rename(&db, "users", "customers");
```

### Reset

Removes all records from a given container.

```zig
try Builtins.Container.reset(&db, "users", .Retain);
```

### Delete

Permanently deletes a given container.

```zig
try Builtins.Container.delete(&db, "users", .Retain);
```

### Add a New Field

Adds a new text fields to an existing container with **NOT NULL** and default value:

```zig
try Builtins.Container.fieldAdd(
    &db, "users", "other1", .TEXT, .{.NotNull = "'Some Default Value'"}
);
```

Adds a new integer fields to an existing container with **NOT NULL** value:

```zig
try Builtins.Container.fieldAdd(
    &db, "users", "other2", .INTEGER, .{.NotNull = "120"}
);
```

Adds a new integer fields to an existing container with **NULL** value:

```zig
try Builtins.Container.fieldAdd(
    &db, "users", "other3", .INTEGER, .Null
);
```

### Rename an Existing Field

Renames an existing field name. Be cautious about the existing code breakage.

```zig
try Builtins.Container.fieldRename(&db, "users", "other2", "another");
```

### Remove an Existing Field

Removing an existing field is tricky because SQLite doesn't support it. However the following function uses a workaround for this. Be cautious about the existing code breakage.

**FYI:** This new `Model` schema should exclude the removable fields. For example, if the old model has a `last_name` field then the new model must exclude this `last_name` field to remove this from database.

```zig
try Builtins.Container.fieldRemove(&db, Model, "users");
```

## Pragma

### Schema Version

Returns current database schema version set by the user.

```zig
const ver = try Builtins.Pragma.version(&db);
std.debug.print("Schema Version: {d}\n", .{ver});
```

### Update Schema Version

Sets the version number for the current database schema.

```zig
try Builtins.Pragma.updateVersion(&db, 1);
```

### Cache

Returns database page cache.

```zig
try Builtins.Pragma.cache(&db);
```

### Set Cache

Sets database page cache limits in kilobytes.

```zig
try Builtins.Pragma.setCache(&db, 1024 * 8);
```

### Page Count

Return total number of pages.

```zig
try Builtins.Pragma.pageCount(&db);
```

### Page Size

Returns page size in bytes.

```zig
try Builtins.Pragma.pageSize(&db);
```

### Set Page Size

Sets page size in bytes. Size must be the power of 2 (e.g., `4096`, `8192`, etc.).

```zig
try Builtins.Pragma.setPageSize(&db, 1024 * 8);
```

### Optimize

Optimizes the database.

```zig
try Builtins.Pragma.optimize(&db);
```

### Journal

Returns current journal mode.

```zig
try Builtins.Pragma.journal(&db);
```

### Set Journal

Sets new journal mode.

```zig
try Builtins.Pragma.setJournal(&db, .WAL);
```

### Synchronous

Returns current synchronous mode.

```zig
try Builtins.Pragma.synchronous(&db);
```

### Set Synchronous

Sets new synchronous mode.

```zig
try Builtins.Pragma.setSynchronous(&db, .NORMAL);
```

### Database Integrity

Checks internal consistency of the database file.

```zig
try Builtins.Pragma.checkIntegrity(&db);
```

### Reclaim Status

Returns the currently configured vacuum mode.

```zig
const stat = try Builtins.Pragma.reclaimStatus(&db);
std.debug.print("Status: {any}\n", .{stat});
```

### Set Reclaim Mode

Available options are `NONE`, `INCREMENTAL`, and `FULL`.

```zig
try Builtins.Pragma.setReclaimMode(&db, .FULL);
```

### Claim Unused Space

Vacuums the database file for clean up any unused space.

```zig
const result = try Builtins.Pragma.claimUnusedSpace(&db, 100);
std.debug.print("Result: {?d}\n", .{result});
```
