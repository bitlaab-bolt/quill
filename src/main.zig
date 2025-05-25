const std = @import("std");

const quill = @import("quill");
const Quill = quill.Quill;
const builtins = quill.Builtins;

pub fn main() !void {
    std.debug.print("Hello, World!\n", .{});

    // Let's start from here...

    var gpa_mem = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa_mem.deinit() == .ok);
    const heap = gpa_mem.allocator();

    try Quill.init(.Serialized);
    defer Quill.deinit();

    var db = try Quill.open(heap, "hello.db", .All);
    defer db.close();

    const x = try builtins.Pragma.reclaimStatus(&db);
    std.debug.print("{any}\n", .{x});

    try builtins.Pragma.setReclaimMode(&db, .INCREMENTAL);
    const z = try builtins.Pragma.claimUnusedSpace(&db, 100);
    std.debug.print("Opps - {any}\n", .{z});

    const y = try builtins.Pragma.reclaimStatus(&db);
    std.debug.print("{any}\n", .{y});
    
}
