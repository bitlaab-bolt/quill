const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const jsonic = @import("jsonic");

const types = @import("./types.zig");

const sqlite3 = @import("../binding/sqlite3.zig");
const STMT = sqlite3.STMT;
const Flag = sqlite3.OpenFlag;
const Option = sqlite3.Option;
const Result = sqlite3.Result;
const ExecResult = sqlite3.ExecResult;

// For quick accessability
pub const Uuid = @import("./uuid.zig");
pub const Utils = @import("./utils.zig");
pub const DateTime = @import("./time.zig");


heap: Allocator,
instance: sqlite3.Database,

const Self = @This();

/// # Initializes SQLite with Global Configuration
pub fn init(opt: Option) !void {
    try sqlite3.config(@intFromEnum(opt));
    try sqlite3.initialize();
}

/// # Destroys SQLite Resources and Configurations
pub fn deinit() void {
    sqlite3.shutdown() catch |err| {
        std.log.err("{s}\n", .{@errorName(err)});
    };
}

/// # Open or Creates a Database Instance
/// - `file_path` - When **null**, creates an in-memory database
pub fn open(heap: Allocator, filename: ?[]const u8) !Self {
    const flags = @intFromEnum(Flag.Create) | @intFromEnum(Flag.WriteWrite);

    const db = if (filename) |file| try sqlite3.openV2(file, flags)
    else try sqlite3.openV2(":memory:", flags);

    return .{.heap = heap, .instance = db};
}

/// # Closes the Database Instance
pub fn close(self: *Self) void { sqlite3.closeV2(self.instance); }

/// # Performs One-Step Query Execution
/// - Convenient wrapper around `prepare()`, `step()`, and `finalize()`
/// - Use only for non-repetitive SQL statements such as creating a table
/// - Avoid when parameter binding or retrieving complex results is required
///
/// **Remarks:**
/// - The callback function receives the results one row at a time
/// - All row data retrieve by the `exec()` is in text representation
/// - In a multiple statement execution, `exec()` does not explicitly tell the
///   callback which statement produced a particular row.
pub fn exec(self: *Self, sql: []const u8) !ExecResult {
    return try sqlite3.exec(self.heap, self.instance, sql);
}

/// # Compiles SQL Text into Byte-Code
pub fn prepare(self: *Self, sql: []const u8) !CRUD {
    const stmt = try sqlite3.prepareV3(self.instance, sql);
    return CRUD.create(self.heap, stmt);
}

/// # Shows Human-Readable Error Message
/// - Most recent error that occurred on a given database connection
pub fn errMsg(self: *Self) []const u8 {
    return sqlite3.errMsg(self.instance);
}

/// # Provides Database Interactions
/// - Supports single statement query (first one)
/// - In a multi-statement query, other statements are discarded
///
/// **WARNING:** You must call `destroy()` at the end to release the STMT
pub const CRUD = struct {
    heap: Allocator,
    stmt: STMT,

    /// # Creates the Interface
    /// - **Remarks:** For internal use only, by the `Self.prepare()`
    fn create(heap: Allocator, stmt: STMT) CRUD {
        return .{.heap = heap, .stmt = stmt };
    }

    /// # Destroys the Interface
    pub fn destroy(self: *CRUD) void {
        sqlite3.finalize(self.stmt) catch |err| {
            std.log.err("{s}\n", .{@errorName(err)});
        };
    }

    /// # Frees Up Heap Allocated Memories
    /// - Retrieved by read operations - `readOne()` and `readMany()`
    pub fn free(self: *CRUD, result: anytype) void {
        const T = @TypeOf(result);
        switch (@typeInfo(T)) {
            .@"struct" => {
                release(self.heap, result);
            },
            .optional => |o| {
                if (@typeInfo(o.child) == .null) return;
                release(self.heap, result.?);
            },
            .pointer => |p| {
                if (!(p.is_const and p.size == .slice)) {
                    @compileError("Pointer type must be `[]const T`");
                }

                const items: T = result;
                for (0..items.len) |i| release(self.heap, items[i]);
                self.heap.free(items);
            },
            else => @compileError(
                "Result must be a struct of - `T`, `?T` or `[]const T`"
            )
        }
    }

    fn release(heap: Allocator, data: anytype) void {
        const info = @typeInfo(@TypeOf(data)).@"struct";
        inline for (info.fields) |field| {
            const value = @field(data, field.name);
            switch (@typeInfo(field.type)) {
                .@"struct" => try jsonic.free(heap, value),
                .optional => |o| {
                    switch(@typeInfo(o.child)) {
                        .@"struct" => if (value) |v| try jsonic.free(heap, v),
                        .pointer => |p| {
                            if (!(p.is_const and p.size == .slice)) {
                                @compileError(
                                    "Pointer type must be `[]const T`"
                                );
                            }

                            if (p.child == u8) { if (value) |v| heap.free(v); }
                            else { if (value) |v| try jsonic.free(heap, v); }
                        },
                        else => {} // NOP
                    }
                },
                .pointer => |p| {
                    if (!(p.is_const and p.size == .slice)) {
                        @compileError("Pointer type must be `[]const T`");
                    }

                    if (p.child == u8) heap.free(value)
                    else try jsonic.free(heap, value);
                },
                else => {} // NOP
            }
        }
    }

    /// # Retrieves a Single (Record) Query Result
    /// **Remarks:** For multiple records only the first one is retrieved
    /// - `T` - A structure that contains all record fields
    pub fn readOne(self: *CRUD, comptime T: type) !?T {
        if (try sqlite3.step(self.stmt) == .Done) return null;

        var column = sqlite3.Column.init(self.heap, self.stmt);
        return try types.convertTo(self.heap, &column, T);
    }

    /// # Retrieves Multiple (Records) Query Result
    /// **Remarks:** Use this when record limits are known. Use `readNext()`
    /// for progressive retrieval of unknown number of records.
    ///
    /// - `T` - A structure that contains all record fields
    ///
    /// **WARNING:** Return value must be freed by the caller
    pub fn readMany(self: *CRUD, comptime T: type) ![]const T {
        var records = ArrayList(T).init(self.heap);

        while (try sqlite3.step(self.stmt) == .Row) {
            var column = sqlite3.Column.init(self.heap, self.stmt);
            try records.append(try types.convertTo(self.heap, &column, T));
        }

        return try records.toOwnedSlice();
    }

    /// # Binds Params Data to a SQL Statement
    pub fn bind(self: *CRUD, record: anytype) !void {
        var list = ArrayList([]const u8).init(self.heap);
        defer {
            for (list.items) |item| self.heap.free(item);
            list.deinit();
        }

        var params = sqlite3.Bind.init(&self.heap, self.stmt);
        try types.convertFrom(self.heap, &list, &params, record);
    }

    const ExecCallback = *const fn(result: Result) void;

    /// # Binds Params Data and then Executes a SQL Statement
    /// `callback` - Captures execution result when not **NULL**
    pub fn exec(self: *CRUD, record: anytype, callback: ?ExecCallback) !void {
        var list = ArrayList([]const u8).init(self.heap);
        defer {
            for (list.items) |item| self.heap.free(item);
            list.deinit();
        }

        var params = sqlite3.Bind.init(&self.heap, self.stmt);
        try types.convertFrom(self.heap, &list, &params, record);

        const result = try sqlite3.step(self.stmt);
        if (callback) |cb| cb(result);
    }

    const AcidAction = enum { Commit, Rollback };
    const AcidCallback = *const fn(result: ExecResult) void;

    /// # Starts ACID Session for Multiple Transaction
    /// - `callback` - Captures execution result when not **NULL**
    pub fn acidSessionStart(self: *CRUD, callback: ?AcidCallback) !void {
        const db: *Self = @fieldParentPtr("heap", &self.heap);
        const result = try db.exec("BEGIN TRANSACTION;");
        if (callback) |cb| cb(result)
        else result.destroy();
    }

    /// # Ends ACID Session for Multiple Transaction
    /// - `callback` - Captures execution result when not **NULL**
    pub fn acidSessionEnd(
        self: *CRUD,
        action: AcidAction,
        callback: ?AcidCallback
    ) !void {
        const db: *Self = @fieldParentPtr("heap", &self.heap);

        const result = switch (action) {
            .Commit => try db.exec("COMMIT;"),
            .Rollback => try db.exec("ROLLBACK;")
        };

        if (callback) |cb| cb(result)
        else result.destroy();
    }
};


pub const QueryBuilder = struct {
    // TODO: build complete queries from scratch with step by step function call
    // TODO: Parse and build complete queries for intermediate JSON string
};


// TODO
// For streaming large binary object from database
pub const Stream = struct {

};