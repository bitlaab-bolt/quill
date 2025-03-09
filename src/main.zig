const std = @import("std");

const quill = @import("quill");
const Quill = quill.Quill;


pub fn main() !void {
    var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    try Quill.init(.Serialized);
    defer Quill.deinit();

    var db = try Quill.open(heap, "hello.db");
    defer db.close();

    std.debug.print("Hello, World!\n", .{});

}
