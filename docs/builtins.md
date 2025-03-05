# Builtin Modules

Builtin modules contains database agnostic utility for SQLite. Let's import builtins on your zig file.

```zig
const Builtins = quill.Builtins;
```

## Index

### Create

Creates an used defined index for a given container field.

```zig
try Builtins.Index.create(&db, "idx_name1", "users", "name1", .Default);

```

### Remove

Removes an existing used defined index.

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

Adds a new fields to an existing container with **NOT NULL** and default value:

```zig
try Builtins.Container.fieldAdd(
    &db, "users", "other2", .INTEGER, .{.NotNull = "'Some Default Value'"}
);
```

Adds a new fields to an existing container with **NULL** value:

```zig
try Builtins.Container.fieldAdd(
    &db, "users", "other2", .INTEGER, .Null
);
```

### Rename an Existing Field

Renames an existing field name. Be cautious about the existing code breakage.

```zig
try Builtins.Container.fieldRename(&db, "users", "other2", "another");
```

### Remove an Existing Field

Removing an existing field is tricky because SQLite doesn't support it. However the following function function uses a workaround for that. Be cautious about the existing code breakage.

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

### Set Cache

Sets database page cache limits in kilobytes.

```zig
try Builtins.Pragma.setCache(&db, 1024 * 8);
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
std.debug.print("Schema Version: {?d}\n", .{result});
```
