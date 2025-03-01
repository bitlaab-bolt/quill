const std = @import("std");
const quill = @import("quill");
const Dt = quill.Types;
const Qb = quill.QueryBuilder;
const Quill = quill.Quill;
const Uuid = quill.Uuid;

pub const Model = struct {
    uuid: Dt.CastInto(.Blob, Dt.Slice),
    name: Dt.CastInto(.Text, Dt.Slice),
    balance: Dt.Float,
    age: Dt.Int,
};

pub const View = struct {
    uuid: Dt.Slice,
    name: Dt.Slice,
    balance: Dt.Float,
    age: Dt.Int,
};

const FilterId = struct { uuid: Dt.Slice };

const FilterAge = struct { age: Dt.Int };

pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    try Quill.init(.Serialized);
    defer Quill.deinit();

    var db = try Quill.open(heap, "hello.db");
    defer db.close();

    // Creates users table
    const table_sql = comptime Qb.Container.create(Model, "users");
    var result = try db.exec(table_sql);
    result.destroy();

    const create_sql = comptime blk: {
        var sql = Qb.Record.create(View, "users", .Default);
        // sql.when(&.{
        //     sql.filter("uuid", .@"=", null),
        //     sql.chain(.AND)
        // });

        break :blk sql.statement();
    };

    var crud = try db.prepare(create_sql);
    defer crud.destroy();

    const model = Model{
        .uuid = .{ .blob = &Uuid.new() },
        .name = .{ .text = "John Doe" },
        .age = 20,
        .balance = 200.0,
    };

    try crud.exec(model, null);

    // Find users data
    const find_sql = comptime blk: {
        var sql = Qb.Record.find(View, FilterAge, "users");
        sql.when(&.{
            sql.filter("age", .@"=", null)
        });

        sql.sort(&.{.{.ASC = "age" }});

        break :blk sql.statement();
    };

    std.debug.print("{s}\n", .{find_sql});

    var crud2 = try db.prepare(find_sql);
    defer crud2.destroy();

    const filter = FilterAge { .age = 2 };

    const result2 = try crud2.readOne(View, filter);
    defer crud2.free(result2);
    std.debug.print("{any}\n", .{result2});
}
