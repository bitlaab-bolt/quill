const std = @import("std");

const quill = @import("quill");
const Dt = quill.Types;
const Qb = quill.QueryBuilder;


const BindUser = struct { name: Dt.CastInto(.Text, []const u8), age: Dt.Int };

const User = struct { name: Dt.Slice, age: Dt.Int };

pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    var query = try Qb.Record.find(heap, BindUser, User, "users");
    defer query.destroy();

    try query.unique();

    // inserts WHERE clause followed by the string
    try query.except(&.{
        try query.group(&.{
            try query.filter("name", Qb.OpStr{.@"=" = "john"}),
            try query.chain(.AND),
            try query.filter("age", Qb.Op{.@"=" = 30}),
        })
    });

    try query.sort(&.{.{.asc = "name" }, .{.desc = "age" }});
    try query.limit(10);
    try query.skip(12);

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

    const sql = try query.build();
    std.log.warn("Generated:|{s}|\n", .{sql});
}
