//! # Database Agnostic Utility Module

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const debug = std.debug;
const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;

const quill = @import("./quill.zig");


const Error = error { FailedIntegrityChecks };

/// # Contains Record Related Functionalities
pub const Record = struct {
    /// # Returns Total Number of Records
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    pub fn count(db: *quill, comptime from: []const u8) !usize {
        var result = try db.exec("SELECT COUNT(*) FROM " ++ from ++ ";");
        defer result.destroy();

        const field = result.next().?[0];
        return try fmt.parseInt(usize, field.data, 10);
    }
};

/// # Contains Index Related Functionalities
pub const Index = struct {
    const Mode = enum { Default, Unique };

    const Info = struct {
        sn: u8,
        name: []const u8,
        unique: bool,
        origin: Origin,
        partial: bool
    };

    const Origin = enum { Created, UniqueConstraint, PrimaryKey };

    /// # Creating an User Defined Field Index
    /// **IMPORTANT:** Always use `idx_` prefix for your index name
    /// e.g., `idx_email`. Unique index enforces **Unique Constrain**.
    /// Removing an unique index also removes the constrain!!!
    ///
    /// - `idx` - Index name e.g., `idx_unique_email`
    /// - `in` - Container name e.g., `users`, `accounts` etc.
    /// - `@"for"` - Field name e.g., `email`, `phone` etc.
    /// - `mode` - When **Unique**, prevents duplicate field value entries
    pub fn create(
        db: *quill,
        comptime idx: []const u8,
        comptime in: []const u8,
        comptime @"for": []const u8,
        mode: Mode,
    ) !void {
        switch (mode) {
            .Default => {
                // e.g., CREATE INDEX idx_name ON users(first_name);
                var result = try db.exec("CREATE INDEX " ++ idx ++ " ON " ++ in ++ "(" ++ @"for" ++ ");");
                defer result.destroy();

                debug.assert(result.count() == 0);
            },
            .Unique => {
                // e.g., CREATE UNIQUE INDEX idx_name ON users(first_name);
                var result = try db.exec("CREATE UNIQUE INDEX " ++ idx ++ " ON " ++ in ++ "(" ++ @"for" ++ ");");
                defer result.destroy();

                debug.assert(result.count() == 0);
            }
        }
    }

    /// # Removes an Existing Index
    /// **Remarks:** You should only remove user defined indexes
    /// - `idx` - Index name e.g., `idx_unique_email`
    pub fn remove(db: *quill, comptime idx: []const u8,) !void {
        var result = try db.exec("DROP INDEX " ++ idx ++ ";");
        defer result.destroy();

        debug.assert(result.count() == 0);
    }

    /// # Returns All Associated Indexes in a Container
    /// **WARNING:** Returned value must be freed with `freeList()`
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    pub fn getList(
        heap: Allocator,
        db: *quill,
        comptime from: []const u8
    ) ![]Info {
        var result = try db.exec("PRAGMA index_list(" ++ from ++ ");");
        defer result.destroy();

        var list = ArrayList(Info).init(heap);
        errdefer list.deinit();

        while (result.next()) |record| {
            var index: Info = undefined;
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
    pub fn freeList(heap: Allocator, indexes: []Info) void {
        for (indexes) |idx| heap.free(idx.name);
        heap.free(indexes);
    }
};

/// # Contains Container Related Functionalities
pub const Container = struct {
    const Action = enum { Retain, Purge };

    /// # Renames a Container
    /// - `from` - Current container name e.g., `users`, `accounts` etc.
    /// - `to` - New container name e.g., `clients`, `customers` etc.
    pub fn rename(
        db: *quill,
        comptime from: []const u8,
        comptime to: []const u8
    ) !void {
        const sql = "ALTER TABLE " ++ from ++ " RENAME TO " ++ to ++ ";";
        var result = try db.exec(sql);
        defer result.destroy();

        debug.assert(result.count() == 0);
    }

    // TODO: when builder is competed
    pub fn fieldAdd(
        db: *quill,
        comptime name: []const u8,
        comptime from: []const u8,
        comptime to: []const u8
    ) !void {
        _ = db;
        _ = name;
        _ = from;
        _ = to;
    }

    /// # Renames a Field in a Given Container
    /// - `name` - Container name e.g., `users`, `accounts` etc.
    /// - `from` - Current field name e.g., `name`, `phone` etc.
    /// - `to` - New field name e.g., `fullname`, `phone_number` etc.
    pub fn fieldRename(
        db: *quill,
        comptime name: []const u8,
        comptime from: []const u8,
        comptime to: []const u8
    ) !void {
        const sql = "ALTER TABLE " ++ name ++ " RENAME COLUMN " ++ from ++ " TO " ++ to ++ ";";
        var result = try db.exec(sql);
        defer result.destroy();

        debug.assert(result.count() == 0);
    }

    // TODO: when builder is competed
    pub fn fieldRemove(
        db: *quill,
        comptime name: []const u8,
        comptime from: []const u8,
        comptime to: []const u8
    ) !void {
        _ = db;
        _ = name;
        _ = from;
        _ = to;
    }

    /// # Removes All Records from a Container
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    /// - `act` - When **Purge**, vacuums unused space in the database file
    pub fn clear(db: *quill, comptime from: []const u8, act: Action) !void {
        switch (act) {
            .Retain => {
                var result = try db.exec("DELETE FROM " ++ from ++ ";");
                defer result.destroy();

                debug.assert(result.count() == 0);
            },
            .Purge => {
                var result = try db.exec("DELETE FROM " ++ from ++ "; VACUUM;");
                defer result.destroy();

                debug.assert(result.count() == 0);
            }
        }
    }

    /// # Deletes an Entire Container
    /// - **CAUTION:** Once deleted, data will be lost permanently!
    /// - `name` - Container name e.g., `users`, `accounts` etc.
    pub fn delete(db: *quill, comptime name: []const u8, act: Action) !void {
        switch (act) {
            .Retain => {
                const sql = "DROP TABLE IF EXISTS " ++ name ++ ";";
                var result = try db.exec(sql);
                defer result.destroy();

                debug.assert(result.count() == 0);
            },
            .Purge => {
                const sql = "DROP TABLE IF EXISTS " ++ name ++ "; VACUUM;";
                var result = try db.exec(sql);
                defer result.destroy();

                debug.assert(result.count() == 0);
            }
        }
    }
};

/// # Contains Database Settings Related Functionalities
pub const Pragma = struct {
    const VacuumMode = enum { NONE, INCREMENTAL, FULL };

    /// # Returns Current Schema Version
    /// **Remarks:** Use this exclusively for database migration
    pub fn version(db: *quill) !u16 {
        var result = try db.exec("PRAGMA user_version;");
        defer result.destroy();

        const ver = result.next().?[0];
        return try fmt.parseInt(u16, ver.data, 10);
    }

    /// # Updates Current Schema Version
    /// **Remarks:** Use this exclusively for database migration
    /// - `num` - Version number for the current schema e.g., `1`, `2`, `3` etc.
    pub fn updateVersion(db: *quill, comptime num: u32) !void {
        const sql = fmt.comptimePrint("PRAGMA user_version = {d};", .{num});
        var result = try db.exec(sql);
        defer result.destroy();

        debug.assert(result.count() == 0);
    }

    /// # Sets Database Page Cache Size Limits
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

        const stat = result.next().?[0];
        if (!mem.eql(u8, stat.data, "ok")) return Error.FailedIntegrityChecks;
    }

    /// # Returns the Current Vacuum Mode
    pub fn reclaimStatus(db: *quill) !VacuumMode {
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
    pub fn setReclaimMode(db: *quill, comptime mode: VacuumMode) !void {
        const mode_name = @tagName(mode);
        var result = try db.exec("PRAGMA auto_vacuum = " ++ mode_name ++ ";");
        defer result.destroy();

        debug.assert(result.count() == 0);
    }

    /// # Vacuums the Database File
    /// **Remarks:** For **NONE** and **FULL** mode `pages` is ignored
    /// - `pages` - Number of pages to vacuum when on **INCREMENTAL** mode
    pub fn claimUnusedSpace(db: *quill, comptime pages: u16) !?u16 {
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

                if (result.count() > 0) {
                    const reclaimed = result.next().?[0];
                    return try fmt.parseInt(u16, reclaimed.data, 10);
                }
            }
        }

        return null;
    }
};
