const std = @import("std");

const quill = @import("./core/quill.zig");
const Dt = @import("./core/types.zig").DataType;



pub const Data = struct {
    uuid: Dt.Slice,
    name: Dt.Slice,
    balance: Dt.Float,
    age: Dt.Integer,
    adult: Dt.Integer,
    gender: ?Gender,
    bio: ?Dt.Slice,

};

const Gender = enum { Male, Female };




pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    // const v = en.Period;
    // const enum_info = @typeInfo(@TypeOf(v)).@"enum";
    // std.debug.print("{any}\n", .{enum_info.tag_type});
    // std.debug.print("{any}\n", .{@Type(v)});
    // inline for (enum_info.fields) |field| {
    //     std.debug.print("{s}\n", .{field.name});
    //     std.debug.print("{}\n", .{field.value});
    // }

    // const w = foo {.bar = 20, .in = .Cat };
    // const struct_info = @typeInfo(@TypeOf(w)).@"struct";
    // inline for (struct_info.fields) |field| {
    //     std.debug.print("{s}\n", .{@typeName(field.type)});
    //     std.debug.print("{}\n", .{@sizeOf(field.type)});
    // }

    try quill.init(.Serialized);
    defer quill.deinit();


    var db = try quill.open(heap, "hello.db");
    defer db.close();

    // # Drops the table
    // const sql = dropTable();
    // var result = try db.exec(sql);
    // defer result.destroy();

    // # Creates the table
    // const sql = createTable();
    // var result = try db.exec(sql);
    // defer result.destroy();

    // # Inserts data into the table
    // const sql2 = insertData();
    // var result2 = try db.exec(sql2);
    // defer result2.destroy();

    // # Retrieve data using RAW exec
    // const sql = \\ SELECT * FROM users;
    // ;

    // var result2 = try db.exec(sql);
    // defer result2.destroy();
    // std.debug.print("Count: {}\n", .{result2.count()});

    // while (result2.next()) |row| {
    //     var i: usize = 0;
    //     while (i < row.len) : (i += 1) {
    //         std.debug.print("{s}: {s}\n", .{row[i].name, row[i].data});
    //     }
    // }

    const sql = \\ SELECT * FROM users;
    ;

    var crud = try db.prepare(sql);
    defer crud.destroy();

    // # For single item retrieve
    // const result = try crud.readOne(Data);
    // defer crud.free(result);
    // std.debug.print("Result: {any}\n", .{result.?});

    // # For unknown number item retrieve
    while (try crud.readOne(Data)) |result| {
        defer crud.free(result);
        std.debug.print("Result: {any}\n", .{result});
    }

    // # For limited number item retrieve
    // const results = try crud.readMany(Data);
    // defer crud.free(results);

    // std.debug.print("results {}\n", .{results.len});

    // for (results) |result| {
    //     std.debug.print("uuid: {}\n", .{result.uuid.len});
    //     std.debug.print("name: {s}\n", .{result.name});
    //     std.debug.print("balance: {d}\n", .{result.balance});
    //     std.debug.print("age: {}\n", .{result.age});
    //     std.debug.print("adult: {}\n", .{result.adult});
    //     if (result.bio) |v| {
    //         std.debug.print("bio: {s}\n", .{v});
    //     } else {
    //         std.debug.print("bio: null\n", .{});
    //     }
    // }
}


fn createTable() []const u8 {
    const sql =
    \\  CREATE TABLE IF NOT EXISTS users (
    \\      uuid BLOB PRIMARY KEY,
    \\      name TEXT NOT NULL,
    \\      balance REAL,
    \\      age INTEGER NOT NULL,
    \\      adult INTEGER NOT NULL,
    \\      gender INTEGER,
    \\      bio BLOB
    \\  ) STRICT, WITHOUT ROWID;
    ;

    return sql;
}

fn dropTable() []const u8 {
    const sql =
    \\  DROP TABLE IF EXISTS users;
    ;

    return sql;
}

fn insertData() []const u8 {
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

    return sql;
}


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