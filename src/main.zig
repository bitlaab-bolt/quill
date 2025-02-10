const std = @import("std");

const quill = @import("./core/quill.zig");
const Dt = @import("./core/types.zig").DataType;

const uuid = @import("./core/uuid.zig");


const Gender = enum { Male, Female };

pub const Data = struct {
    uuid: Dt.Slice,
    name: Dt.Slice,
    balance: Dt.Float,
    age: Dt.Int,
    adult: Dt.Bool,
    gender: Dt.Any(Gender),
    bio: ?Dt.Slice
};

pub const BindData = struct {
    uuid: Dt.Uuid,
    name: Dt.CastInto(.Text, []const u8),
    balance: Dt.Float,
    age: Dt.Int,
    adult: Dt.Bool,
    gender: Dt.CastInto(.Int, Gender),
    bio: Dt.CastInto(.Blob, []const u8)
};



pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    try quill.init(.Serialized);
    defer quill.deinit();

    var db = try quill.open(heap, "hello.db");
    defer db.close();
    errdefer std.debug.print("Error: {s}\n", .{db.errMsg()});


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


    const static = "John Doe";
    const name = try heap.alloc(u8, static.len);
    defer heap.free(name);

    std.mem.copyForwards(u8, name, static);

    // Auto UUID field generator
    const id = uuid.new();
    std.debug.print("UUID-v7: {s}\n", .{uuid.toUrn(id)});
    std.debug.assert(
        std.mem.eql(u8, &id, &(try uuid.fromUrn(&uuid.toUrn(id))))
    );

    const data = BindData {
        .uuid = id,
        .name = .{.text = name},
        .balance = 18.00,
        .age = 5,
        .adult = true,
        .bio = .{.blob = "A brave soul!"},
        .gender = .{.int = .Male}
    };

    try insertDataExample(&db, data);

    try readOneExample(&db);
}


fn createTableExecExample(db: *quill) !void {
    const sql =
    \\  CREATE TABLE IF NOT EXISTS users (
    \\      uuid BLOB PRIMARY KEY,
    \\      name TEXT NOT NULL,
    \\      balance REAL,
    \\      age INTEGER,
    \\      adult INTEGER NOT NULL,
    \\      gender INTEGER,
    \\      bio BLOB
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
    const sql = "SELECT * FROM users ORDER BY uuid ASC;";

    var crud = try db.prepare(sql);
    defer crud.destroy();

    const result = try crud.readOne(Data);
    defer crud.free(result);

    std.debug.print("Result: {any}\n", .{result.?});
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
    \\  INSERT INTO users (uuid, name, balance, age, adult, gender, bio)
    \\  VALUES (:uuid, :name, :balance, :age, :adult, :gender, :bio);
    ;

    var crud = try db.prepare(sql);
    defer crud.destroy();

    try crud.bind(record);
}


// TODO:

// add new column
// ALTER TABLE users ADD COLUMN phone TEXT;

// rename a column
// ALTER TABLE users RENAME COLUMN age TO user_age;

// rename a table
// ALTER TABLE users RENAME TO customers;

// remove column

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