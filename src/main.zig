//! # Quill - Complete API Coverage Demo
//!
//! Exercises the full public API surface in one runnable example:
//! - Query Builder: container statements and record statements (CRUD with
//!   filters, logical chains, groups, sorting, limit, skip, distinct)
//! - CRUD interface: `exec()`, `readOne()`, `readMany()`, `count()`, `remove()`
//! - ACID Session, BlobStream, UUID and DateTime utilities
//! - Builtins: Index, Container and Pragma utilities

const std = @import("std");

const quill = @import("quill");
const Dt = quill.Types;
const Uuid = quill.Uuid;
const DateTime = quill.DateTime;
const Quill = quill.Quill;
const Qb = quill.QueryBuilder;
const Builtins = quill.Builtins;


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

// Filter for the `.in` / `.!in` comparison operators (list of text values)
pub const FilterList = struct { name1: []const Dt.Slice };

// Partial model for updating a subset of the container fields
pub const ModelProfile = struct {
    name2: ?Dt.CastInto(.Text, Dt.Slice),
    age2: ?Dt.Int,
};

// Dedicated container for the BlobStream example. Must use an implicit
// `rowid` primary key as required by `BlobStream.open()`.
pub const ModelBlob = struct {
    uuid: Dt.CastInto(.Blob, Dt.Slice),
    data: Dt.CastInto(.Blob, Dt.Slice)
};

// Small container used by the builtin container maintenance examples
pub const ModelMeta = struct {
    uuid: Dt.CastInto(.Blob, Dt.Slice),
    name: Dt.CastInto(.Text, Dt.Slice),
};

// Must reflect `meta` after the `fieldAdd()` and `fieldRename()` calls below.
// Omits the removable `spare` field for the `fieldRemove()` example.
pub const ModelMetaFull = struct {
    uuid: Dt.CastInto(.Blob, Dt.Slice),
    name: Dt.CastInto(.Text, Dt.Slice),
    notes: Dt.CastInto(.Text, Dt.Slice),
};

fn section(title: []const u8) void {
    std.debug.print("\n---------- {s} ----------\n", .{title});
}

fn resultCallback(result: Quill.Result, affected: i64) void {
    std.debug.print("Callback - Result: {any} | Affected Records: {d}\n", .{result, affected});
}

fn userRecord(
    uuid: []const u8, name: []const u8, age: i64,
    social: Social, socials: []const Social
) Model {
    // Fills every optional field to exercise optional value binding
    return Model {
        .uuid = .{.blob = uuid},
        .name1 = .{.text = name},
        .name2 = .{.text = "Nickname"},
        .balance1 = 12.75,
        .balance2 = 5.5,
        .age1 = age,
        .age2 = 24,
        .verified1 = false,
        .verified2 = false,
        .gender1 = .{.int = .Female},
        .gender2 = .{.int = .Female},
        .gender3 = .{.text = .Female},
        .gender4 = .{.text = .Female},
        .about1 = .{.blob = "Static blob data"},
        .about2 = .{.blob = "More static blob data"},
        .social1 = .{.text = social},
        .social2 = .{.text = social},
        .social3 = .{.text = socials},
        .social4 = .{.text = socials}
    };
}

pub fn main(init: std.process.Init) !void {
    @setEvalBranchQuota(200000);
    std.debug.print("Code coverage examples\n", .{});

    const heap = init.gpa;

    try Quill.init(.Serialized);
    defer Quill.deinit();

    var db = try Quill.open(heap, "hello.db", .All);
    defer db.close();

    const john_uuid = try Uuid.new(init.io);
    const blob_uuid = try Uuid.new(init.io);

    // Removes leftovers from a previous run, keeps the demo re-runnable
    {
        section("Cleanup");

        try Builtins.Container.delete(&db, "users", .Retain);
        try Builtins.Container.delete(&db, "blobs", .Retain);
        try Builtins.Container.delete(&db, "meta", .Retain);
        try Builtins.Container.delete(&db, "meta_new", .Retain);
    }

    // Pragma: configure and read back database settings
    {
        section("Pragma Settings");

        try Builtins.Pragma.setPageSize(&db, 4096);
        try Builtins.Pragma.setCache(&db, -1024 * 8);
        try Builtins.Pragma.setJournal(&db, .WAL);
        try Builtins.Pragma.setSynchronous(&db, .NORMAL);
        try Builtins.Pragma.setReclaimMode(&db, .INCREMENTAL);
        try Builtins.Pragma.updateVersion(&db, 1);

        std.debug.print("Schema Version: {d}\n", .{try Builtins.Pragma.version(&db)});
        std.debug.print("Journal Mode: {any}\n", .{try Builtins.Pragma.journal(&db)});
        std.debug.print("Synchronous Mode: {any}\n", .{try Builtins.Pragma.synchronous(&db)});
        std.debug.print("Cache Size: {d} KB\n", .{try Builtins.Pragma.cache(&db)});
        std.debug.print("Page Size: {d} bytes\n", .{try Builtins.Pragma.pageSize(&db)});
    }

    // Container: create new containers based on the Model structures
    {
        section("Create Containers");

        const users = comptime Qb.Container.create(Model, "users", .Uuid);
        var result = try db.exec(users);
        result.destroy();

        // Implicit `rowid` primary key as required by BlobStream
        const blobs_sql = comptime Qb.Container.create(ModelBlob, "blobs", .RowId);
        var blobs_result = try db.exec(blobs_sql);
        blobs_result.destroy();

        const meta_sql = comptime Qb.Container.create(ModelMeta, "meta", .Uuid);
        var meta_result = try db.exec(meta_sql);
        meta_result.destroy();
    }

    // Record: create with static and dynamic (heap) data mixed in
    {
        section("Create Records");

        const sql = comptime blk: {
            var sql = Qb.Record.create(Model, "users", .Default);
            break :blk sql.statement();
        };

        // Mixing static and dynamic data to check for memory leaks
        const name = "John Doe";
        const msg = "This is the story about " ++ name;
        const about = try heap.alloc(u8, msg.len);
        defer heap.free(about);
        @memcpy(about, msg);

        const soc_dyn = try heap.create(Social);
        soc_dyn.* = Social {.website = "example.one", .username = name};
        defer heap.destroy(soc_dyn);

        const soc = Social {.website = "example.one", .username = name};

        const record_data = Model {
            .uuid = .{.blob = &john_uuid},
            .name1 = .{.text = name},
            .name2 = null,
            .balance1 = 10.50,
            .balance2 = null,
            .age1 = 31,
            .age2 = null,
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
    }

    // Record: insert a second record from a helper built record
    {
        const sql = comptime blk: {
            var sql = Qb.Record.create(Model, "users", .Default);
            break :blk sql.statement();
        };

        const social = Social {
            .website = "example.two", .username = "Jane Doe"
        };
        const socials = [_]Social{social};
        const jane_uuid = try Uuid.new(init.io);

        const record_data = userRecord(&jane_uuid, "Jane Doe", 25, social, &socials);

        var crud = try db.prepare(sql);
        defer crud.destroy();

        try crud.exec(record_data, null, resultCallback);
    }

    // Record: insert a blob record for the BlobStream example
    {
        const sql = comptime blk: {
            var sql = Qb.Record.create(ModelBlob, "blobs", .Default);
            break :blk sql.statement();
        };

        var zeros: [64]u8 = undefined;
        @memset(&zeros, 0);
        const blob_data = ModelBlob {
            .uuid = .{.blob = &blob_uuid},
            .data = .{.blob = &zeros}
        };

        var crud = try db.prepare(sql);
        defer crud.destroy();

        try crud.exec(blob_data, null, null);
    }

    // ACID Session: groups multiple operations into an atomic unit
    {
        section("ACID Session");

        try Quill.AcidSession.start(&db, null);
        errdefer Quill.AcidSession.end(&db, .Rollback, null) catch |err| {
            std.debug.print("Rollback Failed: {s}\n", .{@errorName(err)});
        };

        // `Ignore` action: duplicate primary key insert is silently skipped
        const sql = comptime blk: {
            var sql = Qb.Record.create(Model, "users", .Ignore);
            break :blk sql.statement();
        };

        const social = Social {.website = "example.two", .username = "John Doe"};
        const socials = [_]Social{social};

        const duplicate = userRecord(&john_uuid, "John Doe", 31, social, &socials);

        var crud = try db.prepare(sql);
        defer crud.destroy();

        try crud.exec(duplicate, null, null);

        try Quill.AcidSession.end(&db, .Commit, null);
        std.debug.print("ACID Session Committed\n", .{});
    }

    // Find: a single record
    {
        section("Find Record");

        const sql = comptime blk: {
            var sql = Qb.Record.find(View, void, "users");
            break :blk sql.statement();
        };

        var crud = try db.prepare(sql);
        defer crud.destroy();

        const result = try crud.readOne(View, null);
        defer crud.free(result);

        if (result) |data| {
            std.debug.print("Find Result For: {s} (age {d})\n", .{data.name1, data.age1});
        } else {
            std.debug.print("Found 0 Result!\n", .{});
        }
    }

    // Find: filtered records with a list filter (`.in` operator)
    {
        section("Find Records (In List)");

        const sql = comptime blk: {
            var sql = Qb.Record.find(View, FilterList, "users");

            sql.when(&.{
                sql.filter("name1", .in, 2)
            });

            break :blk sql.statement();
        };

        const names = [_][]const u8{"John Doe", "Jane Doe"};
        const filter = FilterList {.name1 = &names};

        var crud = try db.prepare(sql);
        defer crud.destroy();

        const results = try crud.readMany(View, filter);
        defer crud.free(results);

        std.debug.print("Found Records: {d}\n", .{results.len});

        for (results) |result| {
            std.debug.print("Find Result For: {s}\n", .{result.name1});
        }
    }

    // Find: complex filter with groups, chains, sorting and pagination
    {
        section("Find Records (Complex Filter)");

        const sql = comptime blk: {
            var sql = Qb.Record.find(View, FilterUser, "users");

            sql.dist();

            const eq = sql.filter("name1", .@"=", null);
            const grp = sql.group(&.{
                sql.filter("age1", .@">=", null),
                sql.chain(.AND),
                sql.filter("age1", .@"!=", null)
            });

            sql.when(&.{grp, sql.chain(.OR), eq});

            sql.sort(&.{.{ .DESC = "age1"}, .{.ASC = "name1"}});
            sql.limit(25);
            sql.skip(0);

            break :blk sql.statement();
        };

        std.debug.print("Statement:\n{s}\n", .{sql});

        const filter = FilterUser {.name1 = "John Doe", .age1 = 20};

        var crud = try db.prepare(sql);
        defer crud.destroy();

        const results = try crud.readMany(View, filter);
        defer crud.free(results);

        std.debug.print("Found Records: {d}\n", .{results.len});

        for (results) |result| {
            std.debug.print("Find Result For: {s}\n", .{result.name1});
        }
    }

    // Find: no matching record
    {
        section("Find Records (No Match)");

        const sql = comptime blk: {
            var sql = Qb.Record.find(View, FilterUser, "users");

            sql.when(&.{
                sql.filter("name1", .@"=", null),
                sql.chain(.AND),
                sql.filter("age1", .@"=", null)
            });

            break :blk sql.statement();
        };

        const filter = FilterUser {.name1 = "Mystery Person", .age1 = 99};

        var crud = try db.prepare(sql);
        defer crud.destroy();

        const result = try crud.readOne(View, filter);
        defer crud.free(result);

        if (result) |data| {
            std.debug.print("Find Result For: {s}\n", .{data.name1});
        } else {
            std.debug.print("Found 0 Result!\n", .{});
        }
    }

    // Count: all records
    {
        section("Count Records");

        const sql = comptime blk: {
            var sql = Qb.Record.count(void, "users");
            break :blk sql.statement();
        };

        var crud = try db.prepare(sql);
        defer crud.destroy();

        const result = try crud.count(null);
        std.debug.print("Record Count: {d}\n", .{result});
    }

    // Count: filtered records
    {
        const sql = comptime blk: {
            var sql = Qb.Record.count(FilterUser, "users");

            sql.when(&.{
                sql.filter("name1", .@"=", null),
                sql.chain(.OR),
                sql.filter("age1", .@">", null)
            });

            break :blk sql.statement();
        };

        const filter = FilterUser {.name1 = "Jane Doe", .age1 = 20};

        var crud = try db.prepare(sql);
        defer crud.destroy();

        const result = try crud.count(filter);
        std.debug.print("Filtered Count: {d}\n", .{result});
    }

    // Update: all records
    {
        section("Update All Records");

        const sql = comptime blk: {
            var sql = Qb.Record.update(ModelProfile, void, "users", .All);
            break :blk sql.statement();
        };

        const profile = ModelProfile {
            .name2 = .{.text = "Updated Name"},
            .age2 = 33
        };

        var crud = try db.prepare(sql);
        defer crud.destroy();

        try crud.exec(profile, null, resultCallback);
    }

    // Update: filtered records
    {
        section("Update Filtered Records");

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

        const filter = FilterUser {.name1 = "John Doe", .age1 = 31};

        var crud = try db.prepare(sql);
        defer crud.destroy();

        try crud.exec(profile, filter, resultCallback);
    }

    // Remove: filtered record
    {
        section("Remove Filtered Record");

        const sql = comptime blk: {
            var sql = Qb.Record.remove(FilterUser, "users", .Exact);

            sql.when(&.{
                sql.filter("name1", .@"=", null),
                sql.chain(.AND),
                sql.filter("age1", .@"=", null)
            });

            break :blk sql.statement();
        };

        const filter = FilterUser {.name1 = "Jane Doe", .age1 = 25};

        var crud = try db.prepare(sql);
        defer crud.destroy();

        try crud.remove(filter, resultCallback);
    }

    // Remove: all records
    {
        section("Remove All Records");

        const sql = comptime blk: {
            var sql = Qb.Record.remove(void, "users", .All);
            break :blk sql.statement();
        };

        var crud = try db.prepare(sql);
        defer crud.destroy();

        try crud.remove(null, resultCallback);

        const counter = comptime blk: {
            var stmt = Qb.Record.count(void, "users");
            break :blk stmt.statement();
        };

        var crud2 = try db.prepare(counter);
        defer crud2.destroy();

        std.debug.print("Count After Remove: {d}\n", .{try crud2.count(null)});
    }

    // BlobStream: progressive read and write on large blob data
    {
        section("Blob Stream");
        const BlobStream = Quill.BlobStream;

        // Write chunked data at the blob tail
        {
            var blob = try BlobStream.open(&db, "blobs", "data", 1, .ReadWrite);
            defer blob.close();

            std.debug.print("Blob Size: {d} bytes\n", .{blob.size()});
            try blob.write("Quill!", blob.size() - 6);
        }

        // Read the blob back progressively as a chunked buffer
        {
            var blob = try BlobStream.open(&db, "blobs", "data", 1, .Read);
            defer blob.close();

            var buffer: [16]u8 = undefined;
            var total: usize = 0;

            while (try blob.read(&buffer)) |chunk| {
                total += chunk.len;
            }

            std.debug.print("Streamed Back: {d} of {d} bytes\n", .{total, blob.size()});
        }
    }

    // Builtins: index management
    {
        section("Index Builtins");

        try Builtins.Index.create(&db, "idx_users_name1", "users", "name1", .Default);
        try Builtins.Index.create(&db, "idx_users_age1", "users", "age1", .Unique);

        const idxs = try Builtins.Index.getList(heap, &db, "users");
        defer Builtins.Index.freeList(heap, idxs);

        for (idxs) |idx| {
            std.debug.print(
                "Index: {s} | SN: {d} | Origin: {any} | Unique: {} | Partial: {}\n",
                .{idx.name, idx.sn, idx.origin, idx.unique, idx.partial}
            );
        }

        try Builtins.Index.remove(&db, "idx_users_name1");

        const remaining = try Builtins.Index.getList(heap, &db, "users");
        defer Builtins.Index.freeList(heap, remaining);

        std.debug.print("Indexes Remaining: {d}\n", .{remaining.len});
    }

    // Builtins: container schema maintenance
    {
        section("Container Builtins");

        // Adds a text field with NOT NULL and a default value
        try Builtins.Container.fieldAdd(
            &db, "meta", "extra", .TEXT, .{.NotNull = "'Some Default Value'"}
        );

        // Adds an integer field with NULL values
        try Builtins.Container.fieldAdd(&db, "meta", "spare", .INTEGER, .Null);

        // Renames an existing field
        try Builtins.Container.fieldRename(&db, "meta", "extra", "notes");

        // Drops fields missing from the given Model structure (`spare` here)
        try Builtins.Container.fieldRemove(&db, ModelMetaFull, "meta");

        try Builtins.Container.rename(&db, "meta", "meta_archive");
        try Builtins.Container.delete(&db, "meta_archive", .Purge);

        std.debug.print("Container Maintenance Done\n", .{});
    }

    // Pragma: maintenance
    {
        section("Pragma Maintenance");

        const stat = try Builtins.Pragma.reclaimStatus(&db);
        std.debug.print("Reclaim Status: {any}\n", .{stat});

        const reclaimed = try Builtins.Pragma.claimUnusedSpace(&db, 10);
        std.debug.print("Reclaimed Pages: {?d}\n", .{reclaimed});

        try Builtins.Pragma.optimize(&db);
        try Builtins.Pragma.checkIntegrity(&db);
        std.debug.print("Integrity Check: OK\n", .{});

        std.debug.print("Page Count: {d}\n", .{try Builtins.Pragma.pageCount(&db)});
    }

    // Miscellaneous: UUID and DateTime utilities
    {
        section("Miscellaneous");

        const id = try Uuid.new(init.io);
        const urn = try Uuid.toUrn(&id);
        std.debug.print("UUID URN: {s}\n", .{urn});

        const roundtrip = try Uuid.fromUrn(&urn);
        std.debug.print("Roundtrip OK: {}\n", .{std.mem.eql(u8, &id, &roundtrip)});

        std.debug.print("Timestamp: {d} seconds\n", .{
            DateTime.timestamp(init.io)
        });

        std.debug.print("Timestamp: {d} ms\n", .{
            DateTime.msTimestamp(init.io)
        });
    }
}
