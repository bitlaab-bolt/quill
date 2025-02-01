const std = @import("std");

const quill = @import("./core/quill.zig");


pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    try quill.init(.Serialized);


    var db = try quill.open(heap, "hello.txt");
    defer db.close();

    const sql =
    \\ SELECT name FROM users; SELECT name FROM client;
    ;

    const stmt = try db.prepare(sql);
    _ = stmt;

    // var result = try db.exec(sql);
    // defer result.destroy();

    // while (result.next()) |row| {
    //     var i: usize = 0;
    //     while (i < row.len) : (i += 1) {
    //         std.debug.print("{s}: {s}\n", .{row[i].name, row[i].data});
    //     }
    // }

    try quill.deinit();
}
