# How to use

First, import Quill on your Zig source file.

```zig
const quill = @import("quill");
```

Now, import common quill modules to use through out the examples.

```zig
const Dt = quill.Types;
const Uuid = quill.Uuid;
const Quill = quill.Quill;
const Qb = quill.QueryBuilder;
```

Initialize the General Propose Allocator (GPA) within the `main` function.

```zig
var gpa_mem = std.heap.DebugAllocator(.{}).init;
defer std.debug.assert(gpa_mem.deinit() == .ok);
const heap = gpa_mem.allocator();
```

## Initial Setup

Let's Initialize an on disk database with global configuration.

```zig
try Quill.init(.Serialized);
defer Quill.deinit();

var db = try Quill.open(heap, "hello.db");
defer db.close();
```

## Schema Declaration

Now, declare some demo schema to use through out the examples.

```zig
const Gender = enum(u8) { Male = 1, Female = 2 };
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

pub const FilterUser = struct { name1: Dt.Slice, age1: Dt.Int };

pub const ModelProfile = struct {
    name2: ?Dt.CastInto(.Text, Dt.Slice),
    age2: ?Dt.Int,
};
```

## Container Operations

### Create a New Container

Following example will create a new container based on a given record `Model` structure.

```zig
const sql = comptime Qb.Container.create(Model, "users", .Uuid);
var result = try db.exec(sql);
result.destroy();
```

**Remarks:** For other container related operations please see - [Builtin Modules](/builtins)

## Record Operation

Let's declare a Callback function. Following function is used in case you want to capture `exec()` and `remove()` result for the `INSERT`, `UPDATE`, and `DELETE` SQL statement.

```zig
fn resultCallback(result: Quill.Result, affected: i64) void {
    const fmt_str = "Result: {any}\nAffected Records: {d}\n";
    std.debug.print(fmt_str, .{result, affected});
}
```

### Create a New Record

Following example will insert a new record on a given container.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.create(Model, "users", .Default);
    break :blk sql.statement();
};

// Preparing Record Data
// Mixing both static and dynamic data for memory leaks

const name = "John Doe";
const msg = "This is the story about " ++ name;
const about = try heap.alloc(u8, msg.len);
defer heap.free(about);

const soc_dyn = try heap.create(Social);
soc_dyn.* = Social {.website = "example.one", .username = name };
defer heap.destroy(soc_dyn);

const soc = Social { .website = "example.one", .username = name };

const record_data = Model {
    .uuid = .{.blob = &Uuid.new()},
    .name1 = .{.text = name},
    .name2 = null,
    .balance1 = 10.50,
    .balance2 = null,
    .age1 = 31,
    .age2 = 30,
    .verified1 = true,
    .verified2 = null,
    .gender1 = .{.int = .Male},
    .gender2 = null,
    .gender3 = .{.text = .Male},
    .gender4 = null,
    .about1 = .{.blob = about},
    .about2 = null,
    .social1 = .{.text = soc_dyn.*},
    .social2 = null,
    .social3 = .{.text = &.{soc, soc_dyn.*}},
    .social4 = null
};

var crud = try db.prepare(sql);
defer crud.destroy();

try crud.exec(record_data, null, resultCallback);
```

### Find Record

Following example will retrieve a single record from a given container.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.find(View, void, "users");
    break :blk sql.statement();
};

var crud = try db.prepare(sql);
defer crud.destroy();

const result = try crud.readOne(View, null);
defer crud.free(result);

if (result) |data| {
    std.debug.print("Find Result For: {s}\n", .{data.name1});
} else {
    std.debug.print("Found 0 Result!\n", .{});
}
```

Following example will retrieve a single record from a given container with filtered result.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.find(View, FilterUser, "users");

    sql.when(&.{
        sql.filter("name1", .@"=", null),
        sql.chain(.AND),
        sql.filter("age1", .@"!=", null)
    });

    break :blk sql.statement();
};

const filter = FilterUser {.name1 = "Jane Doe", .age1 = 20};

var crud = try db.prepare(sql);
defer crud.destroy();

const result = try crud.readOne(View, filter);
defer crud.free(result);

if (result) |data| {
    std.debug.print("Find Result For: {s}\n", .{data.name1});
} else {
    std.debug.print("Found 0 Result!\n", .{});
}
```

### Find Records

Following example will retrieve a multiple record from a given container.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.find(View, FilterUser, "users");
    break :blk sql.statement();
};

var crud = try db.prepare(sql);
defer crud.destroy();

const results = try crud.readMany(View, null);
defer crud.free(results);

std.debug.print("Found Records: {d}\n", .{results.len});

for (results) |result| {
    std.debug.print("Find Result For: {s}\n", .{result.name1});
}
```

Following example will retrieve multiple records from a given container with filtered result.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.find(View, FilterUser, "users");

    sql.when(&.{
        sql.filter("name1", .@"=", null),
        sql.chain(.OR),
        sql.filter("age1", .@"!=", null)
    });

    break :blk sql.statement();
};

const filter = FilterUser { .name1 = "Jane Doe", .age1 = 35 };

var crud = try db.prepare(sql);
defer crud.destroy();

const results = try crud.readMany(View, filter);
defer crud.free(results);

std.debug.print("Found Records: {d}\n", .{results.len});

for (results) |result| {
    std.debug.print("Find Result For: {s}\n", .{result.name1});
}
```

### Count Record

Following example will return matching records count from a given container.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.count(void, "users");
    break :blk sql.statement();
};

var crud = try db.prepare(sql);
defer crud.destroy();

const result = try crud.count(null);
std.debug.print("Record Count: {d}\n", .{result});
```

Following example will return matching records count from a given container with filtered result.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.count(FilterUser, "users");

    sql.when(&.{
        sql.filter("name1", .@"=", null),
        sql.chain(.OR),
        sql.filter("age1", .@"!=", null)
    });

    break :blk sql.statement();
};

const filter = FilterUser { .name1 = "Jane Doe", .age1 = 35 };

var crud = try db.prepare(sql);
defer crud.destroy();

const result = try crud.count(filter);
std.debug.print("Record Count: {d}\n", .{result});
```

### Update Record

Following example will update all records to a given container.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.update(ModelProfile, void, "users", .All);
    break :blk sql.statement();
};

const profile = ModelProfile {
    .name2 = .{.text = "Custom Name"},
    .age2 = 33
};

var crud = try db.prepare(sql);
defer crud.destroy();

try crud.exec(profile, null, resultCallback);
```

Following example will update all records to a given container based on filtered result.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.update(ModelProfile, FilterUser, "users", .Exact);

    sql.when(&.{
        sql.filter("name1", .@"=", null),
        sql.chain(.AND),
        sql.filter("age1", .@"=", null)
    });
    break :blk sql.statement();
};

const profile = ModelProfile {
    .name2 = .{.text = "Another Name"},
    .age2 = 23
};

const filter = FilterUser { .name1 = "John Doe", .age1 = 31 };

var crud = try db.prepare(sql);
defer crud.destroy();

try crud.exec(profile, filter, resultCallback);
```

### Remove Record

Following example will remove all records to a given container.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.remove(void, "users", .All);
    break :blk sql.statement();
};

var crud = try db.prepare(sql);
defer crud.destroy();

try crud.remove(null, resultCallback);
```


Following example will remove all records to a given container based on filtered result.

```zig
const sql = comptime blk: {
    var sql = Qb.Record.remove(FilterUser, "users", .Exact);

    sql.when(&.{
        sql.filter("name1", .@"=", null),
        sql.chain(.AND),
        sql.filter("age1", .@"=", null)
    });
    break :blk sql.statement();
};

const filter = FilterUser { .name1 = "John Doe", .age1 = 31 };

var crud = try db.prepare(sql);
defer crud.destroy();

try crud.remove(filter, resultCallback);
```

## ACID Session

ACID Session provides a SQLite transaction, to group one or more SQL statements into a single unit of work that is executed atomically — meaning all or nothing.

```zig
try Quill.AcidSession.start(&db, null);
errdefer Quill.AcidSession.end(&db, .Rollback, null) catch |err| {
    std.debug.print("{s}\n", .{@errorName(err)});
};

// Your multiple database operations here..

try Quill.AcidSession.end(&db, .Commit, null);
```

**Remarks:** `&db` argument is your database (`*Quill`) instance.

## Blob Stream

Provides a stream interface for progressive read, write on large Blob data.

### Read form Stream

Following example will progressively read blob data as a chunked buffer.

```zig
const BlobStream = Quill.BlobStream;

var buffer: [1024 * 8]u8 = undefined;
var blob = try BlobStream.open(&db, "users", "data", 1, .Read);
defer blob.close();

while(try blob.read(&buffer)) |data| {
    std.debug.print("Chunk: {s}\n", .{data});
}
```

### Write to Stream

Following example will write a chunked buffer data to the given offset position.

```zig
const BlobStream = Quill.BlobStream;

var blob = try BlobStream.open(&db, "users", "data", 1, .ReadWrite);
defer blob.close();

const data = "World!";
const offset = blob.size() - 6;
try blob.write(data, offset);
```

**Remarks:** Make sure the `.ReadWrite` permission is set on `open()`. 

## Miscellaneous

Quill has some additional utility modules for repeated codes. Import following module to use through out the examples.

```zig
const Uuid = quill.Uuid;
const DateTime = quill.DateTime;
```

### UUID

Provides an Universally Unique IDentifier module for managing primary keys.

Create a new slice of UUID v7.

```zig
const id = Uuid.new();
std.debug.print("{any}\n", .{id});
```

Create an URN (Uniform Resource Name) string from a given UUID slice.

```zig
const id = Uuid.new();
const id_urn = try Uuid.toUrn(&id);
std.debug.print("URN: {s}\n", .{id_urn});
```

Generate an UUID slice from a given URN string.

```zig
const urn_string = "01956633-4BAB-7BD9-9209-7365F2DB6F2E";
const id = try Uuid.fromUrn(urn_string);
std.debug.print("{any}\n", .{id});
```

### Timestamp

Provides an Epoch timestamp in millisecond. Needed for record's timekeeping.

```zig
const ts_ms = DateTime.timestamp();
std.debug.print("Current Timestamp: {d}\n", .{ts_ms});
```
