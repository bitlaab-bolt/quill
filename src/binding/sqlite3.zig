//! # Underlying SQLite v3.48.0 API Bindings

const std = @import("std");
const log = std.log;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const sqlite3 = @cImport({
    @cInclude("sqlite3.h");
    @cInclude("sqlite3ext.h");
});


const Str = []const u8;
const StrZ = [:0]const u8;

const Error = error {
    Locked,
    UnableToOpen,
    InterfaceMisuse,
    ConnectionIsBusy,
    UnableToExecuteQuery,
    BindParameterNotFound,
    UnmetConstraint,
    UnknownError
};

pub const Database = ?*sqlite3.sqlite3;
pub const STMT = ?*sqlite3.sqlite3_stmt;
pub const Blob = ?*sqlite3.sqlite3_blob;

pub const OpenFlag = enum(c_int) {
    Create = sqlite3.SQLITE_OPEN_CREATE,
    ReadOnly = sqlite3.SQLITE_OPEN_READONLY,
    ReadWrite = sqlite3.SQLITE_OPEN_READWRITE,
    FileUri = sqlite3.SQLITE_OPEN_URI
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

pub fn openV2(filename: StrZ, flags: i32) !Database {
    var db: Database = undefined;
    const rv = sqlite3.sqlite3_open_v2(filename, &db, flags, null);
    if (rv != 0) {
        log.err("{s}", .{errMsg(db)});
        return @"error"(rv);
    }
    return db;
}

pub fn closeV2(db: Database) void {
    const rv = sqlite3.sqlite3_close_v2(db);
    if (rv != 0) log.err("{s}", .{@errorName(@"error"(rv))});
}

pub fn free(any: ?*anyopaque) void { sqlite3.sqlite3_free(any); }

pub fn exec(heap: Allocator, db: Database, sql: Str) !ExecResult {
    var result = ExecResult.create(heap);
    errdefer result.destroy();

    var err_msg: [*c]u8 = undefined;
    const rv = sqlite3.sqlite3_exec(
        db, sql.ptr, ExecResult.callback, @as(*anyopaque, &result), &err_msg
    );

    if (err_msg != null) {
        log.err("{s}", .{mem.span(err_msg)});
        free(@ptrCast(err_msg));
    }

    return if (rv != 0) @"error"(rv) else result;
}

//##############################################################################
//# EXEC RESULT INTERFACE -----------------------------------------------------#
//##############################################################################

/// # Retrieves SQL Execution Results
/// **WARNING:** You must call `ExecResult.destroy()` when done with the result.
pub const ExecResult = struct {
    const Column = struct { name: Str, data: Str };

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

    /// # Releases Allocated Resources
    pub fn destroy(self: *ExecResult) void {
        const heap = self.heap;

        for (self.result.items) |item| {
            var i: usize = 0;
            while (i < item.len) : (i += 1) {
                const column = item[i];
                heap.free(column.name);
                heap.free(column.data);
            }

            heap.free(item);
        }

        self.result.deinit();
    }

    /// # Counts Number of Retrieved Records
    pub fn count(self: *const ExecResult) usize {
        return self.result.items.len;
    }

    /// # Iterates the Retrieved Records
    pub fn next(self: *ExecResult) ?[]ExecResult.Column {
        if (self.offset < self.result.items.len) {
            defer self.offset += 1;
            return self.result.items[self.offset];
        } else {
            return null;
        }
    }

    fn callback (
        args: ?*anyopaque,
        columns: c_int,
        column_texts: [*c][*c]u8,
        column_names: [*c][*c]u8
    ) callconv(.c) c_int {
        _ = columns; // Contains retrieved column counts

        const result: *ExecResult = @ptrCast(@alignCast(args));
        callbackZ(result, column_texts, column_names) catch |err| {
            log.err("{s}", .{@errorName(err)});
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
            const name: Str = mem.span(cn[i]);
            const data: Str = mem.span(ct[i]);
            try list.append(try makeColumn(result.heap, name, data));

        }

        try result.add(try list.toOwnedSlice());
    }

    /// # Makes a Heap Allocated Column
    /// **WARNING:** Allocated memory must be freed by the caller
    fn makeColumn(heap: Allocator, name: Str, data: Str) !ExecResult.Column {
        const alloc_name = try heap.alloc(u8, name.len);
        mem.copyForwards(u8, alloc_name, name);

        const alloc_data = try heap.alloc(u8, data.len);
        mem.copyForwards(u8, alloc_data, data);

        return .{.name = alloc_name, .data = alloc_data };
    }
};

pub fn prepareV3(db: Database, sql: Str) !STMT {
    var stmt: STMT = undefined;

    // Contains the next statement for a multi-statement SQL
    // `pz_tail` must have a long term lifetime when implemented
    // Currently not being used due to single statement workflow
    // Will be needed on a single-shot transaction for bulk write
    var pz_tail: [*c]const u8 = undefined;
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
    heap: Allocator,
    stmt: STMT,

    /// # Creates a Bind Interface for a Given STMT
    /// - No resource clean up is required for this initiation
    pub fn init(heap: Allocator, stmt: STMT) Bind {
        return .{.heap = heap, .stmt = stmt};
    }

    pub fn parameterCount(self: *Bind) i32 {
        const count = sqlite3.sqlite3_bind_parameter_count(self.stmt);
        return @intCast(count);
    }

    pub fn parameterIndex(self: *Bind, name: StrZ) !i32 {
        const index = sqlite3.sqlite3_bind_parameter_index(self.stmt, name);
        if (index == 0) {
            log.warn("Missing Field Name `{s}`", .{name});
            return Error.BindParameterNotFound;
        } else {
            return @intCast(index);
        }
    }

    /// # **WARNING:** Return value must be freed by the caller
    pub fn parameterName(self: *Bind, index: i32) !?Str {
        const name = sqlite3.sqlite3_bind_parameter_name(self.stmt, index);

        if (name == null) return null;

        const tmp = mem.span(name);
        const data = try self.heap.alloc(u8, tmp.len);
        mem.copyForwards(u8, data, tmp);
        return data;
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

    pub fn text(self: *Bind, index: i32, data: Str) !void {
        const pos: c_int = @intCast(index);
        const len: c_int = @intCast(data.len);
        const bindText = sqlite3.sqlite3_bind_text;

        const static = sqlite3.SQLITE_STATIC;
        const rv = bindText(self.stmt, pos, data.ptr, len, static);
        if (rv != 0) return @"error"(rv);
    }

    pub fn blob(self: *Bind, index: i32, data: Str) !void {
        const pos: c_int = @intCast(index);
        const len: c_int = @intCast(data.len);
        const val = @as(?*const anyopaque, data.ptr);
        const bindBlob = sqlite3.sqlite3_bind_blob;

        const static = sqlite3.SQLITE_STATIC;
        const rv = bindBlob(self.stmt, pos, val, len, static);
        if (rv != 0) return @"error"(rv);
    }
};

pub const Result = enum { Done, Row };

pub fn step(stmt: STMT) Error!Result {
    const rv = sqlite3.sqlite3_step(stmt);
    return switch (rv) {
        sqlite3.SQLITE_ROW => .Row,
        sqlite3.SQLITE_DONE => .Done,
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

pub fn changes64(db: Database) i64 {
    return @as(i64, sqlite3.sqlite3_changes64(db));
}

pub fn errMsg(db: Database) Str {
    return mem.span(sqlite3.sqlite3_errmsg(db));
}

pub const BlobOption = enum { Read, ReadWrite };

pub fn blobOpen(
    db: Database,
    table: StrZ,
    column: StrZ,
    rowid: i64,
    opt: BlobOption
) !Blob {
    var blob: Blob  = null;
    const flag: c_int = @intFromEnum(opt);
    const rv = sqlite3.sqlite3_blob_open(
        db, "main", table, column, @intCast(rowid), flag, &blob
    );

    return if (rv != 0) @"error"(rv) else blob;
}

pub fn blobClose(blob: Blob) !void {
    const rv = sqlite3.sqlite3_blob_close(blob);
    if (rv != 0) return @"error"(rv);
}

pub fn blobBytes(blob: Blob) i32 {
    return @intCast(sqlite3.sqlite3_blob_bytes(blob));
}

pub fn blobRead(blob: Blob, buff: []u8, len: i32, offset: i32) !Str {
    const buff_ptr = @as(?*anyopaque, buff);
    const rv = sqlite3.sqlite3_blob_read(blob, buff_ptr, len, offset);
    return if (rv != 0) @"error"(rv)
    else buff[0..@intCast(len)];
}

pub fn blobWrite(blob: Blob, buff: Str, len: i32, offset: i32) !void {
    const buff_ptr = @as(?*const anyopaque, buff.ptr);
    const rv = sqlite3.sqlite3_blob_write(blob, buff_ptr, len, offset);
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

    pub fn name(self: Column, index: i32) Str {
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
    pub fn text(self: Column, index: i32) !?Str {
        const pos: c_int = @intCast(index);
        const result = sqlite3.sqlite3_column_text(self.stmt, pos);

        if (result == null) return null;

        const tmp = mem.span(result);
        const data = try self.heap.alloc(u8, tmp.len);
        mem.copyForwards(u8, data, tmp);
        return data;
    }

    /// - **WARNING:** Returned value must be freed by the caller
    pub fn blob(self: Column, index: i32) !?Str {
        const pos: c_int = @intCast(index);
        const result = sqlite3.sqlite3_column_blob(self.stmt, pos);
        const len = sqlite3.sqlite3_column_bytes(self.stmt, pos);

        if (result == null) return null;

        const tmp_ptr: [*]const u8 = @ptrCast(result);
        const tmp = tmp_ptr[0..@as(usize, @intCast(len))];
        const data = try self.heap.alloc(u8, tmp.len);
        mem.copyForwards(u8, data, tmp);
        return data;
    }
};

/// # Converts Error Messages
fn @"error"(code: c_int) Error {
    return switch (code) {
        sqlite3.SQLITE_LOCKED => Error.Locked,
        sqlite3.SQLITE_ERROR => Error.UnableToExecuteQuery,
        sqlite3.SQLITE_BUSY => Error.ConnectionIsBusy,
        sqlite3.SQLITE_CANTOPEN => Error.UnableToOpen,
        sqlite3.SQLITE_MISUSE => Error.InterfaceMisuse,
        sqlite3.SQLITE_CONSTRAINT => Error.UnmetConstraint,
        else => {
            log.err("Encountered Code - {d}", .{code});
            return Error.UnknownError;
        }
    };
}
