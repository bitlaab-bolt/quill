# How to use

First import Quill on your zig file.

```zig
const quill = @import("quill");
```

Import common quill types to use through out the examples.

```zig
const Dt = quill.Types;
const Uuid = quill.Uuid;
const Quill = quill.Quill;
const Qb = quill.QueryBuilder;
```

Initiate a General Propose Allocator (GPA) on main function.

```zig
var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
defer debug.assert(gpa_mem.deinit() == .ok);
const heap = gpa_mem.allocator();
```

## Initial Setup

Let's initiate an on disk database with global configuration.

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

Following example will create a new container based on the `Model` structure.

```zig
const sql = comptime Qb.Container.create(Model, "users");
var result = try db.exec(sql);
result.destroy();
```

### Remove a Container

Following example will delete an entire database container.

WIP:

```zig

```

### Reset a Container

Following example will remove all records from a given database container.

WIP:

```zig

```

## Record Operation

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
    .uuid = .{.blob = &Uuid.new() },
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
    .social1 = .{.text = soc_dyn.* },
    .social2 = null,
    .social3 = .{.text = &.{soc, soc_dyn.*}},
    .social4 = null
};

var crud = try db.prepare(sql);
defer crud.destroy();

try crud.exec(record_data, null, null);
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

try crud.exec(profile, null, null);
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

try crud.exec(profile, filter, null);
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

try crud.remove(null, null);
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

try crud.remove(filter, null);
```

