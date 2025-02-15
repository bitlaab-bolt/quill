//! # Database Agnostic Utility Module

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const debug = std.debug;
const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;

const quill = @import("./quill.zig");


const Error = error { FailedIntegrityChecks };

/// # Returns Total Number of Records
/// - `name` - Container name e.g., `users`, `accounts` etc.
pub fn recordCount(db: *quill, comptime name: []const u8) !usize {
    var result = try db.exec("SELECT COUNT(*) FROM " ++ name ++ ";");
    defer result.destroy();

    const count = result.next().?[0];
    return try fmt.parseInt(usize, count.data, 10);
}

const IndexMode = enum { Default, Unique };

/// # Creating an User Defined Field Index
/// **IMPORTANT:** Always use `idx_` prefix for your index name
/// e.g., `idx_email`. Unique index enforces **Unique Constrain**.
/// Removing an unique index also removes the constrain!!!
///
/// - `mode` - When **Unique**, prevents duplicate field value entries
pub fn createIndex(
    db: *quill,
    comptime idx: []const u8,
    comptime container: []const u8,
    comptime field: []const u8,
    mode: IndexMode,
) !void {
    switch (mode) {
        .Default => {
            // e.g., CREATE INDEX idx_name ON users(first_name);
            var result = try db.exec("CREATE INDEX " ++ idx ++ " ON " ++ container ++ "(" ++ field ++ ");");
            defer result.destroy();

            debug.assert(result.count() == 0);
        },
        .Unique => {
            // e.g., CREATE UNIQUE INDEX idx_name ON users(first_name);
            var result = try db.exec("CREATE UNIQUE INDEX " ++ idx ++ " ON " ++ container ++ "(" ++ field ++ ");");
            defer result.destroy();

            debug.assert(result.count() == 0);
        }
    }
}

/// # Removes an Existing Index
/// **Remarks:** You should only remove user defined indexes
pub fn removeIndex(db: *quill, comptime idx: []const u8,) !void {
    var result = try db.exec("DROP INDEX " ++ idx ++ ";");
    defer result.destroy();

    debug.assert(result.count() == 0);
}

const IndexInfo = struct {
    sn: u8,
    name: []const u8,
    unique: bool,
    origin: IndexOrigin,
    partial: bool
};

const IndexOrigin = enum { Created, UniqueConstraint, PrimaryKey };

/// # Returns All Associated Indexes
/// **WARNING:** Returned value must be freed with `indexListFree()`
/// - `name` - Container name e.g., `users`, `accounts` etc.
pub fn indexList(
    heap: Allocator,
    db: *quill,
    comptime name: []const u8
) ![]IndexInfo {
    var result = try db.exec("PRAGMA index_list(" ++ name ++ ");");
    defer result.destroy();

    var list = ArrayList(IndexInfo).init(heap);
    errdefer list.deinit();

    while (result.next()) |record| {
        var index: IndexInfo = undefined;
        for (record) |field| {
            if (mem.eql(u8, field.name, "seq")) {
                index.sn = try fmt.parseInt(u8, field.data, 10);
            } else if (mem.eql(u8, field.name, "name")) {
                const idx_name = try heap.alloc(u8, field.data.len);
                mem.copyForwards(u8, idx_name, field.data);
                index.name = idx_name;
            } else if (mem.eql(u8, field.name, "unique")) {
                index.unique = if (mem.eql(u8, field.data, "1")) true
                else false;
            } else if (mem.eql(u8, field.name, "origin"))  {
                std.debug.print("{s}\n", .{field.data});
                index.origin = if (mem.eql(u8, field.data, "c")) .Created
                else if (mem.eql(u8, field.data, "u")) .UniqueConstraint
                else if (mem.eql(u8, field.data, "pk")) .PrimaryKey
                else unreachable;
            } else if (mem.eql(u8, field.name, "partial")) {
                index.partial = if (mem.eql(u8, field.data, "1")) true
                else false;
            } else unreachable;
        }

        try list.append(index);
    }

    return try list.toOwnedSlice();
}

/// # Frees Up Heap Allocated Memories
pub fn indexListFree(heap: Allocator, indexes: []IndexInfo) void {
    for (indexes) |idx| heap.free(idx.name);
    heap.free(indexes);
}

/// # Sets Database Page Cache Limits
/// - `size` - Cache size in kilobytes
pub fn setCache(db: *quill, comptime size: u32) !void {
    const sql = fmt.comptimePrint("PRAGMA cache_size = {d};", .{size});
    var result = try db.exec(sql);
    defer result.destroy();

    debug.assert(result.count() == 0);
}

/// # Checks Internal Consistency of the Database File
pub fn checkIntegrity(db: *quill) !void {
    var result = try db.exec("PRAGMA integrity_check;");
    defer result.destroy();

    const integrity = result.next().?[0];
    if (!mem.eql(u8, integrity.data, "ok")) return Error.FailedIntegrityChecks;
}

const ReclaimMode = enum { NONE, INCREMENTAL, FULL };

/// # Returns the Current Vacuum Mode
pub fn reclaimStatus(db: *quill) !ReclaimMode {
    var result = try db.exec("PRAGMA auto_vacuum;");
    defer result.destroy();

    const vacuum = result.next().?[0];
    const mode = try fmt.parseInt(usize, vacuum.data, 10);
    return switch (mode) {
        0 => .NONE,
        1 => .FULL,
        2 => .INCREMENTAL,
        else => unreachable
    };
}

/// # Sets the Vacuum Mode
/// **Remarks:** Call `reclaimUnusedSpace()` for the change to take effect
pub fn setReclaimMode(db: *quill, comptime mode: ReclaimMode) !void {
    var result = try db.exec("PRAGMA auto_vacuum = " ++ @tagName(mode) ++ ";");
    defer result.destroy();

    debug.assert(result.count() == 0);
}

/// # Vacuums the Database File
/// **Remarks:** For **NONE** and **FULL** mode `pages` is ignored
/// - `pages` - Number of pages to vacuum when on **INCREMENTAL** mode
pub fn reclaimUnusedSpace(db: *quill, comptime pages: u16) !?u16 {
    switch (try reclaimStatus(db)) {
        .NONE, .FULL => {
            var result = try db.exec("VACUUM;");
            defer result.destroy();
            debug.assert(result.count() == 0);
        },
        .INCREMENTAL => {
            const sql = fmt.comptimePrint(
                "PRAGMA incremental_vacuum({d});", .{pages}
            );
            var result = try db.exec(sql);
            defer result.destroy();

            std.debug.print("LENNNNN {}\n", .{result.count()});

            if (result.count() > 0) {
                const reclaimed = result.next().?[0];
                return try fmt.parseInt(u16, reclaimed.data, 10);
            }
        }
    }

    return null;
}