const std = @import("std");

const quill = @import("quill");
const Dt = quill.Types;
const Qb = quill.QueryBuilder;


const Gender = enum { Male, Female };

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


const BindUser = struct {
    uuid: Dt.CastInto(.Blob, []const u8),
    name: ?Dt.CastInto(.Text, []const u8),
    username: Dt.CastInto(.Text, []const u8),
    age: Dt.Int,
    bio: Dt.CastInto(.Blob, []const u8)
};

const User = struct { name: Dt.Slice, age: Dt.Int };

const FilterUser = struct { name: Dt.Slice, age: Dt.Int };

const UpdateUser = struct {
    name: Dt.CastInto(.Text, []const u8),
    age: Dt.Int
};

pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();
    _ = heap;


    const sql1 = comptime blk: {
        var sql = Qb.Record.find(User, FilterUser, "users");

        sql.dist();
        sql.when(&.{
            @TypeOf(sql).group(&.{
                @TypeOf(sql).group(&.{
                    @TypeOf(sql).filter("name", .@"!=", null),
                    @TypeOf(sql).chain(.AND),
                    @TypeOf(sql).filter("age", .@"!in", 10)
                }),
                @TypeOf(sql).chain(.AND),
                @TypeOf(sql).group(&.{
                    @TypeOf(sql).filter("name", .@"!=", null),
                    @TypeOf(sql).chain(.AND),
                    @TypeOf(sql).filter("age", .@"!=", null)
                })
            })
        });

        sql.sort(&.{.{.asc = "name" }, .{.desc = "age" }});
        sql.limit(10);
        sql.skip(12);

        break :blk sql.statement();
    };

    std.debug.print("{s}\n", .{sql1});

    const sql2 = comptime blk: {
        var sql = Qb.Record.count(FilterUser, "users");

        sql.when(&.{
            @TypeOf(sql).group(&.{
                @TypeOf(sql).group(&.{
                    @TypeOf(sql).filter("name", .@"!=", null),
                    @TypeOf(sql).chain(.AND),
                    @TypeOf(sql).filter("age", .@"!in", 10)
                }),
                @TypeOf(sql).chain(.AND),
                @TypeOf(sql).group(&.{
                    @TypeOf(sql).filter("name", .@"!=", null),
                    @TypeOf(sql).chain(.AND),
                    @TypeOf(sql).filter("age", .@"!=", null)
                })
            })
        });

        break :blk sql.statement();
    };

    std.debug.print("{s}\n", .{sql2});

    const sql3 = comptime blk: {
        var sql = Qb.Record.create(BindUser, "users", .Default);
        break :blk sql.statement();
    };

    std.debug.print("{s}\n", .{sql3});

    const sql4 = comptime blk: {
        var sql = Qb.Record.update(BindUser, FilterUser, "users", .Exact);
        sql.when(&.{
            @TypeOf(sql).group(&.{
                @TypeOf(sql).group(&.{
                    @TypeOf(sql).filter("name", .@"!=", null),
                    @TypeOf(sql).chain(.AND),
                    @TypeOf(sql).filter("age", .@"!in", 10)
                }),
                @TypeOf(sql).chain(.AND),
                @TypeOf(sql).group(&.{
                    @TypeOf(sql).filter("name", .@"!=", null),
                    @TypeOf(sql).chain(.AND),
                    @TypeOf(sql).filter("age", .@"!=", null)
                })
            })
        });

        break :blk sql.statement();
    };

    std.debug.print("{s}\n", .{sql4});

    const sql5 = comptime blk: {
        var sql = Qb.Record.remove(FilterUser, "users", .Exact);
        sql.when(&.{
            @TypeOf(sql).group(&.{
                @TypeOf(sql).group(&.{
                    @TypeOf(sql).filter("name", .@"!=", null),
                    @TypeOf(sql).chain(.AND),
                    @TypeOf(sql).filter("age", .@"!in", 10)
                }),
                @TypeOf(sql).chain(.AND),
                @TypeOf(sql).group(&.{
                    @TypeOf(sql).filter("name", .@"!=", null),
                    @TypeOf(sql).chain(.AND),
                    @TypeOf(sql).filter("age", .@"!=", null)
                })
            })
        });

        break :blk sql.statement();
    };

    std.debug.print("{s}\n", .{sql5});
}
