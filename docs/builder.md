# Statement Builder

Quill's statement builder allows us to build SQL statement at Compile-Time. Thus, well optimized for STMT caching and evaluates only once at build time.

For more details on this, see - [API Reference](/reference).

## Prerequisites

Let's import and declare common data types for the examples.

```zig
const quill = @import("quill");
const Dt = quill.Types;
const Qb = quill.QueryBuilder;

const Gender = enum { Male, Female };
const Social = struct { website: []const u8, username: [] const u8 };

pub const Model = struct {
    uuid: Dt.CastInto(.Blob, Dt.Slice),
    name1: Dt.CastInto(.Text, Dt.Slice),
    name2: ?Dt.CastInto(.Text, Dt.Slice),
    balance1: Dt.Float,
    balance2: ?Dt.Float,
    age1: Dt.Int,
    age2: ?Dt.Int,
    verified1: Dt.Bool,
    verified2: ?Dt.Bool,
    gender1: Dt.CastInto(.Int, Gender),
    gender2: ?Dt.CastInto(.Int, Gender),
    gender3: Dt.CastInto(.Text, Gender),
    gender4: ?Dt.CastInto(.Text, Gender),
    about1: Dt.CastInto(.Blob, Dt.Slice),
    about2: ?Dt.CastInto(.Blob, Dt.Slice),
    social1: Dt.CastInto(.Text, Social),
    social2: ?Dt.CastInto(.Text, Social),
    social3: Dt.CastInto(.Text, []const Social),
    social4: ?Dt.CastInto(.Text, []const Social)
};

pub const View = struct {
    uuid: Dt.Slice,
    name1: Dt.Slice,
    name2: ?Dt.Slice,
    balance1: Dt.Float,
    balance2: ?Dt.Float,
    age1: Dt.Int,
    age2: ?Dt.Int,
    verified1: Dt.Bool,
    verified2: ?Dt.Bool,
    gender1: Dt.Any(Gender),
    gender2: ?Dt.Any(Gender),
    gender3: Dt.Any(Gender),
    gender4: ?Dt.Any(Gender),
    about1: Dt.Slice,
    about2: ?Dt.Slice,
    social1: Dt.Any(Social),
    social2: ?Dt.Any(Social),
    social3: Dt.Any([]const Social),
    social4: ?Dt.Any([]const Social)
};

pub const FilterId = struct { uuid: Dt.Slice };

pub const FilterProfile = struct {
    uuid: Dt.Slice,
    name1: Dt.Slice,
    age1: Dt.Int
};

pub const ModelProfile = struct {
    name1: Dt.CastInto(.Text, Dt.Slice),
    age1: Dt.Int,
    verified1: Dt.Bool,
    about1: Dt.CastInto(.Blob, Dt.Slice),
};
```

## Container

To build SQL Statement for a record container, copy and run:

```zig
const sql = comptime Qb.Container.create(Model, "users", .Uuid);
std.debug.print("{s}\n", .{sql});
```

The above example will generate a **CREATE TABLE** SQL statement **WITHOUT ROWID** from the given Model.

To build SQL Statement for a record container with implicit **RowID**, copy and run:

```zig
const sql = comptime Qb.Container.create(Model, "users", .RowId);
std.debug.print("{s}\n", .{sql});
```

To build SQL Statement for a record container where Primary Key is an UUID string, copy and run:

```zig
const sql = comptime Qb.Container.create(Model, "users", .UuidStr);
std.debug.print("{s}\n", .{sql});
```

Checkout the [source](/zig-docs/index.html#src/root/core/builder.zig) for more details.

**Remarks:** Containers with implicit **RowId** will automatically generate a primary key field named `rowid`. Thus, make sure to add this field in your View structure if `rowid` is required. Only create such container when you are intending to use this for **BlobStream**.

## Record

### Find

**Example 01:** Generate **SELECT** SQL statement for all records.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.find(View, FilterProfile, "users");
    break :blk sql.statement();
};

std.debug.print("{s}\n", .{sql});
```

**Example 02:** Generate **SELECT** SQL statement for only filtered records.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.find(View, FilterProfile, "users");
    sql.when(&.{
        sql.filter("uuid", .@"=", null),
        sql.chain(.OR),
        sql.group(&.{
            sql.filter("name1", .contains, null),
            sql.chain(.OR),
            sql.filter("age1", .@"!=", null)
        })
    });

    sql.sort(&.{.{.desc = "age1"}});
    sql.limit(25);
    sql.skip(10);

    break :blk sql.statement();
};

std.debug.print("{s}\n", .{sql});
```

### Count

**Example 01:** Generate **COUNT(*)** SQL statement for all records.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.count(Model, "users");
    break :blk sql.statement();
};

std.debug.print("{s}\n", .{sql});
```

**Example 02:** Generate **COUNT(*)** SQL statement for only filtered records.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.count(FilterId, "users");
    sql.when(&.{
        sql.filter("uuid", .@"=", null)
    });

    break :blk sql.statement();
};

std.debug.print("{s}\n", .{sql});
```

### Create

**Example 01:** Generate **INSERT INTO** SQL statement from a Model structure.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.create(Model, "users", .Default);
    break :blk sql.statement();
};

std.debug.print("{s}\n", .{sql});
```

### Update

**Example 01:** Generate **UPDATE** SQL statement for all records.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.update(ModelProfile, FilterId, "users", .All);
    break :blk sql.statement();
};

std.debug.print("{s}\n", .{sql});
```

**Example 02:** Generate **UPDATE** SQL statement for only filtered records.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.update(ModelProfile, FilterId, "users", .Exact);
    sql.when(&.{
        sql.filter("uuid", .@"=", null),
    });

    break :blk sql.statement();
};

std.debug.print("{s}\n", .{sql});
```
### Remove

**Example 01:** Generate **DELETE** SQL statement for all records.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.remove(FilterId, "users", .All);
    break :blk sql.statement();
};

std.debug.print("{s}\n", .{sql});
```

**Example 02:** Generates **DELETE** SQL statement for only filtered records.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.remove(FilterId, "users", .Exact);
    sql.when(&.{
        sql.filter("uuid", .@"=", null),
    });

    break :blk sql.statement();
};

std.debug.print("{s}\n", .{sql});
```
