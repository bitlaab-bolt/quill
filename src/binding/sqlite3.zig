const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const sqlite3 = @cImport({
    @cInclude("sqlite3.h");
    @cInclude("sqlite3ext.h");
});


const Error = error {
    UnableToOpen,
    InterfaceMisuse,
    UnableToExecuteQuery,
    Unknown,
};

pub const Database = ?*sqlite3.sqlite3;

pub const OpenFlag = enum(c_int) {
    Create = sqlite3.SQLITE_OPEN_CREATE,
    ReadOnly = sqlite3.SQLITE_OPEN_READONLY,
    WriteWrite = sqlite3.SQLITE_OPEN_READWRITE,
};

pub fn openV2(filename: []const u8, flags: i32) !Database {
    var db: Database = undefined;
    const rv = sqlite3.sqlite3_open_v2(filename.ptr, &db, flags, null);
    if (rv != 0) return @"error"(rv);
    return db;
}

pub fn closeV2(db: Database) void {
    const rv = sqlite3.sqlite3_close_v2(db);
    if (rv != 0) std.log.err("{s}\n", .{@errorName(@"error"(rv))});
}

pub fn free(any: ?*anyopaque) void { sqlite3.sqlite3_free(any); }

pub fn exec(heap: Allocator, db: Database, sql: []const u8) !ExecResult {
    var result = ExecResult.create(heap);
    errdefer result.destroy();

    var err_msg: [*c]u8 = undefined;
    const rv = sqlite3.sqlite3_exec(
        db, sql.ptr, ExecResult.callback, @as(*anyopaque, &result), &err_msg
    );

    if (err_msg != null) {
        const data: []const u8 = std.mem.span(err_msg);
        std.debug.print("{s}\n", .{data});
        free(@ptrCast(err_msg));
    }

    return if (rv != 0) @"error"(rv) else result;
}

/// # Retrieves SQL Execution Results
/// **WARNING:** You must call `destroy()`, when you are done with the result
pub const ExecResult = struct {
    const Column = struct { name: []const u8, data: []const u8 };

    heap: Allocator,
    offset: usize = 0,
    result: ArrayList([]Column),

    fn create(heap: Allocator) ExecResult {
        return .{
            .heap = heap,
            .result = ArrayList([]Column).init(heap)
        };
    }

    fn add(self: *ExecResult, columns: []Column) !void {
        try self.result.append(columns);
    }

    /// # Releases Allocated Memories
    pub fn destroy(self: *ExecResult) void {
        for (self.result.items) |item| {
            var i: usize = 0;
            while (i < item.len) : (i += 1) {
                const column = item[i];
                self.heap.free(column.name);
                self.heap.free(column.data);
            }

            self.heap.free(item);
        }

        self.result.deinit();
    }

    /// # Counts Number of Retrieved Rows
    pub fn count(self: *const ExecResult) usize {
        return self.result.items.len;
    }

    /// # Iterates the Retrieved Rows
    pub fn next(self: *ExecResult) ?[]Column {
        if (self.offset < self.result.items.len) {
            defer self.offset += 1;
            return self.result.items[self.offset];
        } else return null;
    }

    fn callback (
        args: ?*anyopaque,
        columns: c_int,
        column_texts: [*c][*c]u8,
        column_names: [*c][*c]u8
    ) callconv(.c) c_int {
        _ = columns; // Shows retrieved column counts

        const result: *ExecResult = @ptrCast(@alignCast(args));
        callbackZ(result, column_texts, column_names) catch |err| {
            std.log.err("{s}\n", .{@errorName(err)});
            return -1;
        };

        return 0;
    }

    fn callbackZ(result: *ExecResult, ct: [*c][*c]u8, cn: [*c][*c]u8) !void {
        // List will never be empty
        // `exec()` only invokes callback when a row is retrieved
        var list = ArrayList(Column).init(result.heap);

        var i: usize = 0;
        while (ct[i] != null) : (i += 1) {
            const name: []const u8 = std.mem.span(cn[i]);
            const data: []const u8 = std.mem.span(ct[i]);
            try list.append(try makeColumn(result.heap, name, data));

        }

        try result.add(try list.toOwnedSlice());
    }

    /// # Makes a Heap Allocated Column
    /// **WARNING:** Allocated memory must be freed by the caller
    fn makeColumn(heap: Allocator, name: []const u8, data: []const u8) !Column {
        const alloc_name = try heap.alloc(u8, name.len);
        mem.copyForwards(u8, alloc_name, name);

        const alloc_data = try heap.alloc(u8, data.len);
        mem.copyForwards(u8, alloc_data, data);

        return .{.name = alloc_name, .data = alloc_data };
    }
};

/// # Converts Error Messages
fn @"error"(code: c_int) Error {
    return switch (code) {
        sqlite3.SQLITE_ERROR => Error.UnableToExecuteQuery,
        sqlite3.SQLITE_CANTOPEN => Error.UnableToOpen,
        sqlite3.SQLITE_MISUSE => Error.InterfaceMisuse,
        else => {
            std.log.err("Encountered: {d}\n", .{code});
            return Error.Unknown;
        }
    };
}
