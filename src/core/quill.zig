const std = @import("std");
const Allocator = std.mem.Allocator;

const sqlite3 = @import("../binding/sqlite3.zig");
const Flag = sqlite3.OpenFlag;
const ExecResult = sqlite3.ExecResult;


heap: Allocator,
instance: sqlite3.Database,

const Self = @This();

/// # Creates a Database Instance
/// - `file_path` - When **null**, creates an in-memory database
pub fn init(heap: Allocator, filename: ?[]const u8) !Self {
    const flags = @intFromEnum(Flag.Create) | @intFromEnum(Flag.WriteWrite);

    const db = if (filename) |file| try sqlite3.openV2(file, flags)
    else try sqlite3.openV2(":memory:", flags);

    return .{.heap = heap, .instance = db};
}

/// # Closes the Database Instance
pub fn deinit(self: *Self) void { sqlite3.closeV2(self.instance); }

/// # Performs One-Step Query Execution
/// - Convenient wrapper around `prepare()`, `step()`, and `finalize()`
/// - Use only for non-repetitive SQL statements such as creating table etc.
/// - Avoid when parameter binding or retrieving complex results is required
///
/// **Remarks:**
/// - The callback function receives the results one row at a time
/// - All row data retrieve by the `exec()` is in string representation
/// - In a multiple statement execution, `exec()` does not explicitly tell the
///   callback which statement produced a particular row.
pub fn exec(self: *Self, sql: []const u8) !ExecResult {
    return try sqlite3.exec(self.heap, self.instance, sql);
}

