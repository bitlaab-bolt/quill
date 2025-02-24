const std = @import("std");

const quill = @import("quill");
const Dt = quill.Types;
const Qb = quill.QueryBuilder;


const BindUser = struct {
    uuid: Dt.CastInto(.Blob, []const u8),
    name: ?Dt.CastInto(.Text, []const u8),
    username: Dt.CastInto(.Text, []const u8),
    age: Dt.Int,
    bio: Dt.CastInto(.Blob, []const u8)
};

const User = struct { name: Dt.Slice, age: Dt.Int };

const UpdateUser = struct {
    name: Dt.CastInto(.Text, []const u8),
    age: Dt.Int
};

pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();
    _ = heap;

    const query = Qb.Container.create(BindUser, "users");
    std.debug.print("{s}\n", .{query});




    // var query = try Qb.Record.remove(heap, BindUser, "users", .Exact);
    // defer query.destroy();

    // try query.when(&.{
    //     try query.chain(.NOT),
    //     try query.group(&.{
    //         try query.filter("name", Qb.OpStr{.@"=" = "john"}),
    //         try query.chain(.AND),
    //         try query.filter("age", Qb.Op{.@"=" = 30}),
    //     })
    // });









    // var query = try Qb.Record.create(heap, BindUser, "users", .Replace);
    // defer query.destroy();

    // var query = try Qb.Record.count(heap, BindUser, "users");
    // defer query.destroy();

    // // inserts WHERE clause followed by the string
    // try query.when(&.{
    //     try query.chain(.NOT),
    //     try query.group(&.{
    //         try query.filter("name", Qb.OpStr{.@"=" = "john"}),
    //         try query.chain(.AND),
    //         try query.filter("age", Qb.Op{.@"=" = 30}),
    //     })
    // });

    // var query = try Qb.Record.find(heap, BindUser, User, "users");
    // defer query.destroy();

    // try query.unique();

    // // inserts WHERE clause followed by the string
    // try query.when(&.{
    //     try query.chain(.NOT),
    //     try query.group(&.{
    //         try query.filter("name", Qb.OpStr{.@"=" = "john"}),
    //         try query.chain(.AND),
    //         try query.filter("age", Qb.Op{.@"=" = 30}),
    //     })
    // });

    // try query.sort(&.{.{.asc = "name" }, .{.desc = "age" }});
    // try query.limit(10);
    // try query.skip(12);

    // inserts WHERE NOT clause followed by the string
    // query.except(&.{
    //     query.group(&.{
    //         query.filter(User.name, .{age}),
    //         query.opt(.AND),
    //         query.
    //     })
        
    // });

    // query.order()
    // query.limit()
    // query.ship()

    // const sql = try query.build();
    // std.log.warn("Generated:|{s}|\n", .{sql});
}
