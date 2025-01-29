const std = @import("std");

const quill = @import("./core/quill.zig");


pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();


    var db = try quill.init(heap, "hello.txt");
    defer db.deinit();

    const sql =
    \\ SELECT name FROM users; SELECT name FROM client;
    ;

    var result = try db.exec(sql);
    defer result.destroy();

    while (result.next()) |row| {
        var i: usize = 0;
        while (i < row.len) : (i += 1) {
            std.debug.print("{s}: {s}\n", .{row[i].name, row[i].data});
        }
    }
}
