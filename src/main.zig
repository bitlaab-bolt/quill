const std = @import("std");

const quill = @import("quill");
const Uuid = quill.Uuid;
const Quill = quill.Quill;
const Dt = quill.Types;
const Qb = quill.QueryBuilder;

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


pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    try Quill.init(.Serialized);
    defer Quill.deinit();

    var db = try Quill.open(heap, "hello.db");
    defer db.close();


    const sql = comptime blk: {
        var sql = Qb.Record.remove(void, "users", .All);
        break :blk sql.statement();
    };
    std.debug.print("{s}\n", .{sql});

    var crud = try db.prepare(sql);
    defer crud.destroy();

    try crud.remove(null, null);
}
