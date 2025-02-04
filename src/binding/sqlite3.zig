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
    BindParameterNotFound,
    UnmetConstraint,
    Unknown,
};

pub const Database = ?*sqlite3.sqlite3;
pub const STMT = ?*sqlite3.sqlite3_stmt;

pub const OpenFlag = enum(c_int) {
    Create = sqlite3.SQLITE_OPEN_CREATE,
    ReadOnly = sqlite3.SQLITE_OPEN_READONLY,
    WriteWrite = sqlite3.SQLITE_OPEN_READWRITE,
};

pub const Option = enum(i32) {
    /// Disables mutexes (no thread safety, best for performance)
    SingleThreaded = sqlite3.SQLITE_CONFIG_SINGLETHREAD,
    /// Each connection is thread-safe but
    /// statements within a connection are not.
    MultiThreaded = sqlite3.SQLITE_CONFIG_MULTITHREAD,
    /// Full thread safety (lowest performance)
    Serialized = sqlite3.SQLITE_CONFIG_SERIALIZED
};

pub fn config(cfg: i32) !void {
    const rv = sqlite3.sqlite3_config(@intCast(cfg));
    if (rv != 0) return @"error"(rv);
}

pub fn initialize() !void {
    const rv = sqlite3.sqlite3_initialize();
    if (rv != 0) return @"error"(rv);
}

pub fn shutdown() !void {
    const rv = sqlite3.sqlite3_shutdown();
    if (rv != 0) return @"error"(rv);
}

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

//##############################################################################
//# EXEC RESULT INTERFACE -----------------------------------------------------#
//##############################################################################

/// # Retrieves SQL Execution Results
/// **WARNING:** You must call `destroy()`, when you are done with the result
pub const ExecResult = struct {
    const Column = struct { name: []const u8, data: []const u8 };

    heap: Allocator,
    offset: usize = 0,
    result: ArrayList([]ExecResult.Column),

    fn create(heap: Allocator) ExecResult {
        return .{
            .heap = heap,
            .result = ArrayList([]ExecResult.Column).init(heap)
        };
    }

    fn add(self: *ExecResult, columns: []ExecResult.Column) !void {
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
    pub fn next(self: *ExecResult) ?[]ExecResult.Column {
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
        var list = ArrayList(ExecResult.Column).init(result.heap);

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
    fn makeColumn(
        heap: Allocator,
        name: []const u8,
        data: []const u8
    ) !ExecResult.Column {
        const alloc_name = try heap.alloc(u8, name.len);
        mem.copyForwards(u8, alloc_name, name);

        const alloc_data = try heap.alloc(u8, data.len);
        mem.copyForwards(u8, alloc_data, data);

        return .{.name = alloc_name, .data = alloc_data };
    }
};

pub fn prepareV3(db: Database, sql: []const u8) !STMT {
    var stmt: STMT = undefined;

    var pz_tail: [*c]const u8 = undefined; // this must be long term
    const flag = sqlite3.SQLITE_PREPARE_PERSISTENT;
    const rv = sqlite3.sqlite3_prepare_v3(
        db, sql.ptr, @intCast(sql.len), flag, &stmt, &pz_tail
    );

    if (rv != 0) return @"error"(rv);
    return stmt;
}

//##############################################################################
//# STMT DATA BINDING ---------------------------------------------------------#
//##############################################################################

pub const Bind = struct {
    const DataType = enum { Static, Dynamic };

    const heap_ptr: ?*Allocator = null;

    stmt: STMT,

    /// # Creates a Bind Interface for a Given STMT
    /// - No resource clean up is required for this initiation
    pub fn init(heap: Allocator, stmt: STMT) Bind {
        Bind.heap_ptr.* = &heap;
        return .{.stmt = stmt};
    }

    pub fn parameterCount(self: *Bind) i32 {
        const count = sqlite3.sqlite3_bind_parameter_count(self.stmt);
        return @intCast(count);
    }

    pub fn parameterIndex(self: *Bind, name: []const u8) !i32 {
        const index = sqlite3.sqlite3_bind_parameter_index(self.stmt, name.ptr);
        return if (index == 0) Error.BindParameterNotFound
        else @intCast(index);
    }

    /// # Binds **NULL** to Column Data
    pub fn none(self: *Bind, index: i32) !void {
        const pos: c_int = @intCast(index);
        const rv = sqlite3.sqlite3_bind_null(self.stmt, pos);
        if (rv != 0) return @"error"(rv);
    }

    pub fn int(self: *Bind, index: i32, value: i32) !void {
        const pos: c_int = @intCast(index);
        const val: c_int = @intCast(value);
        const rv = sqlite3.sqlite3_bind_int(self.stmt, pos, val);
        if (rv != 0) return @"error"(rv);
    }

    pub fn int64(self: *Bind, index: i32, value: i64) !void {
        const pos: c_int = @intCast(index);
        const val: c_longlong = @intCast(value);
        const rv = sqlite3.sqlite3_bind_int64(self.stmt, pos, val);
        if (rv != 0) return @"error"(rv);
    }

    pub fn double(self: *Bind, index: i32, value: f64) !void {
        const pos: c_int = @intCast(index);
        const rv = sqlite3.sqlite3_bind_double(self.stmt, pos, value);
        if (rv != 0) return @"error"(rv);
    }

    /// **WARNING:**
    /// - Caller should not deallocate memory for **Dynamic** data
    /// - Callback function `free()` will be called automatically!
    pub fn text(
        self: *Bind,
        index: i32,
        data: []const u8,
        @"type": DataType
    ) !void {
        const pos: c_int = @intCast(index);
        const len: c_int = @intCast(data.len);
        const val: [*]const u8 = @ptrCast(data);
        const bindText = sqlite3.sqlite3_bind_text;

        switch (@"type") {
            .Static => {
                const static = sqlite3.SQLITE_STATIC;
                const rv = bindText(self.stmt, pos, val, len, static);
                if (rv != 0) return @"error"(rv);
            },
            .Dynamic => {
                const rv = bindText(self.stmt, index, val, len, Bind.free);
                if (rv != 0) return @"error"(rv);
            }
        }
    }

    /// **WARNING:**
    /// - Caller should not deallocate memory for **Dynamic** data
    /// - Callback function `free()` will be called automatically!
    pub fn blob(
        self: *Bind,
        index: i32,
        data: []const u8,
        @"type": DataType
    ) !void {
        const pos: c_int = @intCast(index);
        const len: c_int = @intCast(data.len);
        const val: *anyopaque = @ptrCast(data);
        const bindBlob = sqlite3.sqlite3_bind_blob;

        switch (@"type") {
            .Static => {
                const static = sqlite3.SQLITE_STATIC;
                const rv = bindBlob(self.stmt, pos, val, len, static);
                if (rv != 0) return @"error"(rv);
            },
            .Dynamic => {
                const rv = bindBlob(self.stmt, index, val, len, Bind.free);
                if (rv != 0) return @"error"(rv);
            }
        }
    }

    fn free(args: ?*anyopaque) callconv(.c) void {
        const data: []const u8 = @ptrCast(@alignCast(args));
        Bind.heap_ptr.?.free(data);
    }
};

const Result = enum { None, Row };

pub fn step(stmt: STMT) !Result {
    const rv = sqlite3.sqlite3_step(stmt);
    return switch (rv) {
        sqlite3.SQLITE_DONE => .None,
        sqlite3.SQLITE_ROW => .Row,
        else => return @"error"(rv)
    };
}

pub fn clearBinding(stmt: STMT) !void {
    const rv = sqlite3.sqlite3_clear_bindings(stmt);
    if (rv != 0) return @"error"(rv);
}

pub fn reset(stmt: STMT) !void {
    const rv = sqlite3.sqlite3_reset(stmt);
    if (rv != 0) return @"error"(rv);
}

pub fn finalize(stmt: STMT) !void {
    const rv = sqlite3.sqlite3_finalize(stmt);
    if (rv != 0) return @"error"(rv);
}

//##############################################################################
//# STMT DATA RETRIEVAL -------------------------------------------------------#
//##############################################################################

pub const Column = struct {
    heap: Allocator,
    stmt: STMT,

    pub const DataType = enum(i32) { Int, Float, Text, Blob, Null };

    /// # Creates a Column Interface for a Given STMT
    /// - No resource clean up is required for this initiation
    pub fn init(heap: Allocator, stmt: STMT) Column {
        return .{.heap = heap, .stmt = stmt};
    }

    pub fn count(self: Column) i32 {
        return @intCast(sqlite3.sqlite3_column_count(self.stmt));
    }

    pub fn name(self: Column, index: i32) []const u8 {
        const pos: c_int = @intCast(index);
        const col_name = sqlite3.sqlite3_column_name(self.stmt, pos);
        return mem.span(col_name);
    }

    pub fn dataType(self: Column, index: i32) DataType {
        const pos: c_int = @intCast(index);
        const result = sqlite3.sqlite3_column_type(self.stmt, pos);
        return switch(result) {
            sqlite3.SQLITE_INTEGER => .Int,
            sqlite3.SQLITE_FLOAT => .Float,
            sqlite3.SQLITE_TEXT => .Text,
            sqlite3.SQLITE_BLOB => .Blob,
            sqlite3.SQLITE_NULL => .Null,
            else => unreachable
        };
    }

    pub fn bytes(self: Column, index: i32) i32 {
        const pos: c_int = @intCast(index);
        return @intCast(sqlite3.sqlite3_column_bytes(self.stmt, pos));
    }

    pub fn int(self: Column, index: i32) i32 {
        const pos: c_int = @intCast(index);
        return @intCast(sqlite3.sqlite3_column_int(self.stmt, pos));
    }

    pub fn int64(self: Column, index: i32) i64 {
        const pos: c_int = @intCast(index);
        return @intCast(sqlite3.sqlite3_column_int64(self.stmt, pos));
    }

    pub fn double(self: Column, index: i32) f64 {
        const pos: c_int = @intCast(index);
        return sqlite3.sqlite3_column_double(self.stmt, pos);
    }

    /// - **WARNING:** Returned value must be freed by the caller
    pub fn text(self: Column, index: i32) !?[]const u8 {
        const pos: c_int = @intCast(index);
        const result = sqlite3.sqlite3_column_text(self.stmt, pos);

        if (result == null) return null;

        const tmp = mem.span(result);
        const data = try self.heap.alloc(u8, tmp.len);
        mem.copyForwards(u8, data, tmp);
        return data;
    }

    /// - **WARNING:** Returned value must be freed by the caller
    pub fn blob(self: Column, index: i32) !?[]const u8 {
        const pos: c_int = @intCast(index);
        const result = sqlite3.sqlite3_column_blob(self.stmt, pos);

        if (result == null) return null;

        const tmp_ptr: [*c]const u8 = @ptrCast(@alignCast(result));
        const tmp = mem.span(tmp_ptr);
        const data = try self.heap.alloc(u8, tmp.len);
        mem.copyForwards(u8, data, tmp);
        return data;
    }
};

/// # Converts Error Messages
fn @"error"(code: c_int) Error {
    return switch (code) {
        sqlite3.SQLITE_ERROR => Error.UnableToExecuteQuery,
        sqlite3.SQLITE_CANTOPEN => Error.UnableToOpen,
        sqlite3.SQLITE_MISUSE => Error.InterfaceMisuse,
        sqlite3.SQLITE_CONSTRAINT => Error.UnmetConstraint,
        else => {
            std.log.err("Encountered Code - {d}\n", .{code});
            return Error.Unknown;
        }
    };
}
