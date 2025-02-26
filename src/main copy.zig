const std = @import("std");

const quill = @import("./core/quill.zig");
const Dt = @import("./core/types.zig").DataType;

const QueryBuilder = quill.QueryBuilder;


const Gender = enum { Male, Female };

const Status = enum { Single, Married };

const Social = struct { fb: []const u8, yt: []const u8 };

pub const Data = struct {
    uuid: Dt.Slice,
    name: Dt.Slice,
    name_opt: ?Dt.Slice,
    balance: Dt.Float,
    balance_opt: ?Dt.Float,
    age: Dt.Int,
    age_opt: ?Dt.Int,
    adult: Dt.Bool,
    adult_opt: ?Dt.Bool,
    gender: Dt.Any(Gender),
    gender_opt: ?Dt.Any(Gender),
    status: Dt.Any(Status),
    status_opt: ?Dt.Any(Status),
    bio: Dt.Slice,
    bio_opt: ?Dt.Slice,
    social: Dt.Any([]const Social),
    social_opt: ?Dt.Any(Social)
};

pub const BindData = struct {
    uuid: Dt.CastInto(.Blob, []const u8),
    name: Dt.CastInto(.Text, []const u8),
    name_opt: ?Dt.CastInto(.Text, []const u8),
    balance: Dt.Float,
    balance_opt: ?Dt.Float,
    age: Dt.Int,
    age_opt: ?Dt.Int,
    adult: Dt.Bool,
    adult_opt: ?Dt.Bool,
    gender: Dt.CastInto(.Int, Gender),
    gender_opt: ?Dt.CastInto(.Int, Gender),
    status: Dt.CastInto(.Text, Status),
    status_opt: ?Dt.CastInto(.Text, Status),
    bio: Dt.CastInto(.Blob, []const u8),
    bio_opt: ?Dt.CastInto(.Blob, []const u8),
    social: Dt.CastInto(.Text, []const Social),
    social_opt: ?Dt.CastInto(.Text, Social)
};


pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    try quill.init(.Serialized);
    defer quill.deinit();

    var db = try quill.open(heap, "hello.db");
    defer db.close();

    try quill.Builtins.Pragma.setCache(&db, 1024 * 32);
    errdefer std.debug.print("Error: {s}\n", .{db.errMsg()});

    const c = try quill.Builtins.Record.count(&db, "users");
    std.debug.print("Total records: {}\n", .{c});

    try quill.Builtins.Pragma.checkIntegrity(&db);

    try quill.Builtins.Pragma.setReclaimMode(&db, .INCREMENTAL);
    _ = try quill.Builtins.Pragma.claimUnusedSpace(&db, 1000);

    const vacuum = try quill.Builtins.Pragma.reclaimStatus(&db);
    std.debug.print("Vaccum Mode: {any}\n", .{vacuum});


    // try quill.Builtins.removeIndex(&db, "idx_name");
    // try quill.Builtins.createIndex(&db, "idx_name", "users", "name", .Unique);

    const idx_list = try quill.Builtins.Index.getList(heap, &db, "users");
    defer quill.Builtins.Index.freeList(heap, idx_list);
    for (idx_list) |idx| {
        std.debug.print("IDX: {s}\n", .{idx.name});
        std.debug.print("Info: {any}\n", .{idx});
    }

    // Toggle following blocks to execute specific operations

    try createTableExecExample(&db);

    // try dropTableExecExample(&db);

    // try insertDataExecExample(&db);

    // try readOneExample(&db);

    // try readManyExample(&db);

    // try readUnknownExample(&db);

    // const static = "john";
    // const dyn = try heap.allocSentinel(u8, 4, 0);
    // // const dyn = try heap.alloc(u8, 4);
    // defer heap.free(dyn);

    // std.mem.copyForwards(u8, dyn, static);

    // var v = try db.exec("PRAGMA integrity_check;");
    // defer v.destroy();

    // while (v.next()) |res| {
    //     std.debug.print("{s}: {s}\n", .{res[0].name, res[0].data});
    // }


    // const static = "John Doe";
    // const name = try heap.alloc(u8, static.len);
    // defer heap.free(name);

    // const static2 = "John Doe";
    // const name2 = try heap.alloc(u8, static2.len);
    // defer heap.free(name2);

    // std.mem.copyForwards(u8, name, static);

    // // Auto UUID field generator
    // const id = quill.Uuid.new();
    // std.debug.print("UUID-v7: {any}\n", .{&id});
    // std.debug.print("UUID-v7: {s}\n", .{try quill.Uuid.toUrn(&id)});
    // std.debug.assert(
    //     std.mem.eql(u8, &id, &(try quill.Uuid.fromUrn(&(try quill.Uuid.toUrn(&id)))))
    // );

    // const data = BindData {
    //     .uuid = .{.blob = &id},
    //     .name = .{.text = name},
    //     .name_opt = null,
    //     .balance = 18.00,
    //     .balance_opt = null,
    //     .age = 5,
    //     .age_opt = null,
    //     .adult = true,
    //     .adult_opt = null,
    //     .gender = .{.int = .Male},
    //     .gender_opt = null,
    //     .status = .{.text = .Married},
    //     .status_opt = null,
    //     .bio = .{.blob = name2},
    //     .bio_opt = null,
    //     .social = .{.text = &.{
    //         .{.fb = "facebook1", .yt = "youtube1"},
    //         .{.fb = "facebook2", .yt = "youtube2"},
    //         .{.fb = "facebook3", .yt = "youtube3"},
    //     }},
    //     .social_opt = .{.text = .{.fb = "facebook", .yt = "youtube"}}
    // };

    // try insertDataExample(&db, data);

    // try readOneExample(&db);
}


fn createTableExecExample(db: *quill) !void {
    const sql =
    \\  CREATE TABLE IF NOT EXISTS users (
    \\      uuid BLOB PRIMARY KEY,
    \\      name TEXT NOT NULL,
    \\      name_opt TEXT,
    \\      balance REAL NOT NULL,
    \\      balance_opt REAL,
    \\      age INTEGER NOT NULL,
    \\      age_opt INTEGER,
    \\      adult INTEGER NOT NULL,
    \\      adult_opt INTEGER,
    \\      gender INTEGER NOT NULL,
    \\      gender_opt INTEGER,
    \\      status TEXT NOT NULL,
    \\      status_opt TEXT,
    \\      bio BLOB NOT NULL,
    \\      bio_opt BLOB,
    \\      social TEXT NOT NULL,
    \\      social_opt TEXT
    \\  ) STRICT, WITHOUT ROWID;
    ;

    var result = try db.exec(sql);
    result.destroy();
}

fn dropTableExecExample(db: *quill) !void {
    const sql = "DROP TABLE IF EXISTS users;";

    var result = try db.exec(sql);
    result.destroy();
}

fn insertDataExecExample(db: *quill) !void {
    const sql =
    \\  INSERT INTO users (uuid, name, balance, age, adult, gender, bio)
    \\  VALUES
    \\  (
    \\      X'00112233445566778899AABBCCDDEEFF',
    \\      'Alice',
    \\      1000.50,
    \\      30,
    \\      1,
    \\      1,
    \\      X'48656C6C6F'
    \\  ),
    \\  (
    \\      X'112233445566778899AABBCCDDEEFF00',
    \\      'Bob',
    \\      500.75,
    \\      25,
    \\      0,
    \\      0,
    \\      X'576F726C64'
    \\  ),
    \\  (
    \\      X'2233445566778899AABBCCDDEEFF0011',
    \\      'Charlie',
    \\      1200.00,
    \\      40,
    \\      1,
    \\      NULL,
    \\      NULL
    \\  );
    ;

    var result = try db.exec(sql);
    result.destroy();
}


fn readOneExample(db: *quill) !void {
    const sql = "SELECT * FROM users ORDER BY uuid DESC;";

    var crud = try db.prepare(sql);
    defer crud.destroy();

    const result = try crud.readOne(Data);
    defer crud.free(result);

    // std.debug.print("Result: {any}\n", .{result.?});

    std.debug.print("Result: {any}\n", .{result.?.social});

    const urn = try quill.Uuid.toUrn(result.?.uuid);
    std.debug.print("UUID-v7: {any}\n", .{result.?.uuid});
    std.debug.print("UUID-v7: {s}\n", .{&urn});
}

fn readManyExample(db: *quill) !void {
    const sql = "SELECT * FROM users;";

    var crud = try db.prepare(sql);
    defer crud.destroy();

    const results = try crud.readMany(Data);
    defer crud.free(results);

    std.debug.print("Found {} records\n", .{results.len});

    for (results) |result| {
        std.debug.print("Result: {any}\n", .{result});
    }
}

fn readUnknownExample(db: *quill) !void {
    const sql = "SELECT * FROM users;";

    var crud = try db.prepare(sql);
    defer crud.destroy();

    // Break out for early returns
    while (try crud.readOne(Data)) |result| {
        defer crud.free(result);

        std.debug.print("Result: {any}\n", .{result});
    }
}

fn insertDataExample(db: *quill, record: anytype) !void {
    const sql =
    \\  INSERT INTO users (
    \\      uuid, name, name_opt, balance, balance_opt, age, age_opt,
    \\      adult, adult_opt, gender, gender_opt, status, status_opt,
    \\      bio, bio_opt, social, social_opt
    \\  )
    \\  VALUES (
    \\      :uuid, :name, :name_opt, :balance, :balance_opt, :age, :age_opt,
    \\      :adult, :adult_opt, :gender, :gender_opt, :status, :status_opt,
    \\      :bio, :bio_opt, :social, :social_opt
    \\  );
    ;

    var crud = try db.prepare(sql);
    defer crud.destroy();

    try crud.exec(record, null);
}


// TODO:

// add new column
// ALTER TABLE users ADD COLUMN phone TEXT;
// ALTER TABLE users ADD COLUMN phone TEXT NOT NULL DEFAULT 'Unknown';

// rename a column
// ALTER TABLE users RENAME COLUMN age TO user_age;

// remove column
// this must be achieved with builder from utils module

// Suppose we have this table:
// CREATE TABLE users (
//     uuid BLOB PRIMARY KEY,
//     name TEXT NOT NULL,
//     balance REAL,
//     age INTEGER CHECK (age > 0),
//     bio BLOB
// );

// Since SQLite does not support DROP COLUMN, follow these steps:
// BEGIN TRANSACTION;

// -- Step 1: Create a new table without the "age" column
// CREATE TABLE users_new (
//     uuid BLOB PRIMARY KEY,
//     name TEXT NOT NULL,
//     balance REAL,
//     bio BLOB
// );

// -- Step 2: Copy data from the old table to the new table (excluding "age")
// INSERT INTO users_new (uuid, name, balance, bio)
// SELECT uuid, name, balance, bio FROM users;

// -- Step 3: Drop the old table
// DROP TABLE users;

// -- Step 4: Rename the new table to the original name
// ALTER TABLE users_new RENAME TO users;

// COMMIT;