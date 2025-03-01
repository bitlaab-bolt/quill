const std = @import("std");
const quill = @import("quill");
const Dt = quill.Types;
const Qb = quill.QueryBuilder;
const Quill = quill.Quill;
const Uuid = quill.Uuid;

pub const Model = struct {
    uuid: Dt.CastInto(.Blob, Dt.Slice),
    // name: Dt.CastInto(.Text, Dt.Slice),
    balance: Dt.Float,
    // age: Dt.Int,
};

pub const View = struct {
    uuid: Dt.Slice,
    name: Dt.Slice,
    balance: Dt.Float,
    age: Dt.Int,
};

pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    try Quill.init(.Serialized);
    defer Quill.deinit();

    var db = try Quill.open(heap, "hello.db");
    defer db.close();

    const sql = comptime Qb.Container.create(Model, "account");
    // std.debug.print("{s}\n", .{sql});
    var result = try db.exec(sql);
    result.destroy();

    // // var result = try db.exec(sql);
    // // result.destroy();

    const insert_sql =
        \\  INSERT INTO account (uuid, name, balance, age)
        \\  VALUES (:uuid, :name, :balance, :age);
    ;

    std.debug.print("{s}\n", .{db.errMsg()});

    var crud = try db.prepare(insert_sql);
    defer crud.destroy();

    std.debug.print("{s}\n", .{db.errMsg()});

    const id = Uuid.new();

    const model = Model{
        .uuid = .{ .blob = &id },
        // .name = .{ .text = "sabbir" },
        // .age = 25,
        .balance = 200.0,
    };

    try crud.exec(model, null);
}
