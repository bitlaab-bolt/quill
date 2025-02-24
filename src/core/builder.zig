//! # SQL Statement Builder
//! **Remarks:** For complex and computationally expensive queries such as
//! pattern matching on a large text field, use **Raw SQL Statement** instead.
//! TODO: Statically generate builder string at compile time for performance!!!

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const debug = std.debug;
const testing = std.testing;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const Dt = @import("./types.zig").DataType;


const Error = error {
    MismatchedConstraint,
    InvalidFunctionChain,
    InvalidNamingConvention
};

/// # Operator Type for Number Fields
pub const Op = Operator(i64);

/// # Operator Type for Text Fields
pub const OpText = Operator([]const u8);

pub const Container = struct {
    /// # Generates `CREATE TABLE` SQL Statement
    /// - `T` - Record Model structure
    /// - `name` - Container name e.g., `users`, `accounts` etc.
    pub fn create(comptime T: type, comptime name: []const u8) []const u8 {
        const info = @typeInfo(T);
        if (info != .@"struct") {
            @compileError("Type of `T` must be a valid Model Structure");
        }

        if (!@hasField(T, "uuid")) {
            @compileError("Model Structure has no `uuid` field");
        }

        comptime var fields: []const u8 = "";
        inline for (info.@"struct".fields) |field| {
            switch (@typeInfo(field.type)) {
                .optional => |o| {
                    fields = fields ++ comptime genToken(o.child, field.name, true);
                },
                else => {
                    fields = fields ++ comptime genToken(field.type, field.name, false);
                }
            }
        }

        const sql_head = "CREATE TABLE IF NOT EXISTS " ++ name ++ " (\n";
        const sql_tail = "\n) STRICT, WITHOUT ROWID;";
        const data = fields[0..fields.len - 2];

        return fmt.comptimePrint("{s} {s} {s}", .{sql_head, data, sql_tail});
    }

    /// # Generates SQL Clause for a Given Field
    /// **Remarks:** Compile time function e.g., `comptime getToken()`
    fn genToken(T: type, field: []const u8, opt: bool) []const u8 {
        switch (@typeInfo(T)) {
            .bool, .int => {
                if (!opt) {
                    const fmt_str = "\t{s} INTEGER NOT NULL,\n";
                    return fmt.comptimePrint(fmt_str, .{field});
                } else {
                    const fmt_str = "\t{s} INTEGER,\n";
                    return fmt.comptimePrint(fmt_str, .{field});
                }
            },
            .float => {
                if (!opt) {
                    const fmt_str = "\t{s} REAL NOT NULL,\n";
                    return fmt.comptimePrint(fmt_str, .{field});
                } else {
                    const fmt_str = "\t{s} REAL,\n";
                    return fmt.comptimePrint(fmt_str, .{field});
                }
            },
            .@"struct" => {
                // const child = sf.type;
                if (@hasField(T, "int")) {
                    if (!opt) {
                        const fmt_str = "\t{s} INTEGER NOT NULL,\n";
                        return fmt.comptimePrint(fmt_str, .{field});
                    } else {
                        const fmt_str = "\t{s} INTEGER,\n";
                        return fmt.comptimePrint(fmt_str, .{field});
                    }
                } else if (@hasField(T, "text")) {
                    if (!opt) {
                        const fmt_str = "\t{s} TEXT NOT NULL,\n";
                        return fmt.comptimePrint(fmt_str, .{field});
                    } else {
                        const fmt_str = "\t{s} TEXT,\n";
                        return fmt.comptimePrint(fmt_str, .{field});
                    }
                } else if (@hasField(T, "blob")) {
                    if (mem.eql(u8, field, "uuid")) {
                        if (!opt) {
                            const fmt_str = "\t{s} BLOB PRIMARY KEY,\n";
                            return fmt.comptimePrint(fmt_str, .{field});
                        } else {
                            @compileError("UUID Can't Be Optional");
                        }
                    } else {
                        if (!opt) {
                            const fmt_str = "\t{s} BLOB NOT NULL,\n";
                            return fmt.comptimePrint(fmt_str, .{field});
                        } else {
                            const fmt_str = "\t{s} BLOB,\n";
                            return fmt.comptimePrint(fmt_str, .{field});
                        }
                    }
                } else {
                    @compileError("Unknown Field Name");
                }
            },
            else => {
                @compileError("Malformed Model Data Type");
            }
        }
    }
};

/// # Generic Operator Type for Data Filtering
/// - Comparison is done in Lexicographical Order for text data
/// - Text Matching is case-insensitive and only supports `[]const u8`
fn Operator(comptime T: type) type {
    return union(enum) {
        /// Checks - Equality
        @"=": T,
        /// Checks - Inequality
        @"!=": T,
        /// Checks - Greater Than
        @">": T,
        /// Checks - Less Than
        @"<": T,
        /// Checks - Greater Than or Equal To
        @">=": T,
        /// Checks - Less Than or Equal To
        @"<=": T,
        /// Checks - Pattern Matching
        contains: []const u8,
        /// Checks - Pattern Matching
        @"!contains": []const u8,
        /// Checks - Between Values
        between: [2]T,
        /// Checks - In List of Values
        in: []const T,
        /// Checks - Not In List of Values
        @"!in": []const T,
        /// Checks - NULL Values
        none: bool,

        /// # Generates Operator Token
        /// **WARNING:** Return value must be freed by the caller
        fn genToken(
            heap: Allocator,
            field: []const u8,
            op: Operator(T)
        ) ![]const u8 {
            switch (op) {
                .@"=" => |v| {
                    if (@TypeOf(op) == Operator(i64)) {
                        return try fmt.allocPrint(
                            heap, "{s} = {d}", .{field, v}
                        );
                    } else {
                        return try fmt.allocPrint(
                            heap, "{s} = '{s}'", .{field, v}
                        );
                    }
                },
                .@"!=" => |v| {
                    if (@TypeOf(op) == Operator(i64)) {
                        return try fmt.allocPrint(
                            heap, "{s} != {d}", .{field, v}
                        );
                    } else {
                        return try fmt.allocPrint(
                            heap, "{s} != '{s}'", .{field, v}
                        );
                    }
                },
                .@">" => |v| {
                    if (@TypeOf(op) == Operator(i64)) {
                        return try fmt.allocPrint(
                            heap, "{s} > {d}", .{field, v}
                        );
                    } else {
                        return try fmt.allocPrint(
                            heap, "{s} > '{s}'", .{field, v}
                        );
                    }
                },
                .@"<" => |v| {
                    if (@TypeOf(op) == Operator(i64)) {
                        return try fmt.allocPrint(
                            heap, "{s} < {d}", .{field, v}
                        );
                    } else {
                        return try fmt.allocPrint(
                            heap, "{s} < '{s}'", .{field, v}
                        );
                    }
                },
                .@">=" => |v| {
                    if (@TypeOf(op) == Operator(i64)) {
                        return try fmt.allocPrint(
                            heap, "{s} >= {d}", .{field, v}
                        );
                    } else {
                        return try fmt.allocPrint(
                            heap, "{s} >= '{s}'", .{field, v}
                        );
                    }
                },
                .@"<=" => |v| {
                    if (@TypeOf(op) == Operator(i64)) {
                        return try fmt.allocPrint(
                            heap, "{s} <= {d}", .{field, v}
                        );
                    } else {
                        return try fmt.allocPrint(
                            heap, "{s} <= '{s}'", .{field, v}
                        );
                    }
                },
                .contains => |v| {
                    return try fmt.allocPrint(
                        heap, "{s} LIKE '%{s}%'", .{field, v}
                    );
                },
                .@"!contains" => |v| {
                    return try fmt.allocPrint(
                        heap, "{s} NOT LIKE '%{s}%'", .{field, v}
                    );
                },
                .between => |v| {
                    if (@TypeOf(op) == Operator(i64)) {
                        const fmt_str = "{s} BETWEEN {d} AND {d}";
                        return try fmt.allocPrint(
                            heap, fmt_str, .{field, v[0], v[1]}
                        );
                    } else {
                        const fmt_str = "{s} BETWEEN '{s}' AND '{s}'";
                        return try fmt.allocPrint(
                            heap, fmt_str, .{field, v[0], v[1]}
                        );
                    }
                },
                .in => |v| {
                    var list = ArrayList(u8).init(heap);
                    try list.appendSlice(field);
                    try list.appendSlice(" IN (");

                    if (@TypeOf(op) == Operator(i64)) try inList(v, &list)
                    else try inList(v, &list);

                    debug.assert(list.orderedRemove(list.items.len - 1) == ' ');
                    debug.assert(list.orderedRemove(list.items.len - 1) == ',');
                    try list.appendSlice(")");
                    return list.toOwnedSlice();
                },
                .@"!in" => |v| {
                    var list = ArrayList(u8).init(heap);
                    try list.appendSlice(field);
                    try list.appendSlice(" NOT IN (");

                    if (@TypeOf(op) == Operator(i64)) try inList(v, &list)
                    else try inList(v, &list);

                    debug.assert(list.orderedRemove(list.items.len - 1) == ' ');
                    debug.assert(list.orderedRemove(list.items.len - 1) == ',');
                    try list.appendSlice(")");
                    return list.toOwnedSlice();
                },
                .none => |v| {
                    if (v) {
                        return try fmt.allocPrint(
                            heap, "{s} IS NULL", .{field}
                        );
                    } else {
                        return try fmt.allocPrint(
                            heap, "{s} IS NOT NULL", .{field}
                        );
                    }
                }
            }
        }

        test genToken {
            const heap = testing.allocator;

            // Testing Equality
            {
                const res = try Op.genToken(heap, "age", Op {
                    .@"=" = 30
                });
                defer heap.free(res);
                try testing.expect(mem.eql(u8, res, "age = 30"));

                const res2 = try OpText.genToken(heap, "name", OpText {
                    .@"=" = "John"
                });
                defer heap.free(res2);
                try testing.expect(mem.eql(u8, res2, "name = 'John'"));
            }

            // Testing Inequality
            {
                const res = try Op.genToken(heap, "age", Op {
                    .@"!=" = 30
                });
                defer heap.free(res);
                try testing.expect(mem.eql(u8, res, "age != 30"));

                const res2 = try OpText.genToken(heap, "name", OpText {
                    .@"!=" = "John"
                });
                defer heap.free(res2);
                try testing.expect(mem.eql(u8, res2, "name != 'John'"));
            }

            // Testing Greater Than
            {
                const res = try Op.genToken(heap, "age", Op {
                    .@">" = 30
                });
                defer heap.free(res);
                try testing.expect(mem.eql(u8, res, "age > 30"));

                const res2 = try OpText.genToken(heap, "name", OpText {
                    .@">" = "John"
                });
                defer heap.free(res2);
                try testing.expect(mem.eql(u8, res2, "name > 'John'"));
            }

            // Testing Less Than
            {
                const res = try Op.genToken(heap, "age", Op {
                    .@"<" = 30
                });
                defer heap.free(res);
                try testing.expect(mem.eql(u8, res, "age < 30"));

                const res2 = try OpText.genToken(heap, "name", OpText {
                    .@"<" = "John"
                });
                defer heap.free(res2);
                try testing.expect(mem.eql(u8, res2, "name < 'John'"));
            }

            // Testing Greater Than or Equal To
            {
                const res = try Op.genToken(heap, "age", Op {
                    .@">=" = 30
                });
                defer heap.free(res);
                try testing.expect(mem.eql(u8, res, "age >= 30"));

                const res2 = try OpText.genToken(heap, "name", OpText {
                    .@">=" = "John"
                });
                defer heap.free(res2);
                try testing.expect(mem.eql(u8, res2, "name >= 'John'"));
            }

            // Testing Less Than or Equal To
            {
                const res = try Op.genToken(heap, "age", Op {
                    .@"<=" = 30
                });
                defer heap.free(res);
                try testing.expect(mem.eql(u8, res, "age <= 30"));

                const res2 = try OpText.genToken(heap, "name", OpText {
                    .@"<=" = "John"
                });
                defer heap.free(res2);
                try testing.expect(mem.eql(u8, res2, "name <= 'John'"));
            }

            // Testing Pattern Matching
            {
                const res = try OpText.genToken(heap, "name", OpText {
                    .contains = "John"
                });
                defer heap.free(res);
                try testing.expect(mem.eql(u8, res, "name LIKE '%John%'"));
            }

            // Testing Pattern Matching
            {
                const res = try OpText.genToken(heap, "name", OpText {
                    .@"!contains" = "John"
                });
                defer heap.free(res);
                try testing.expect(mem.eql(u8, res, "name NOT LIKE '%John%'"));
            }

            // Testing Between Values
            {
                const res = try Op.genToken(heap, "age", Op {
                    .between = .{30, 50}
                });
                defer heap.free(res);
                try testing.expect(
                    mem.eql(u8, res, "age BETWEEN 30 AND 50")
                );

                const res2 = try OpText.genToken(heap, "name", OpText {
                    .between = .{"John", "Jane"}
                });
                defer heap.free(res2);
                try testing.expect(
                    mem.eql(u8, res2, "name BETWEEN 'John' AND 'Jane'")
                );
            }

            // Testing In List of Values
            {
                const res = try Op.genToken(heap, "age", Op {
                    .in = &.{30, 50, 70}
                });
                defer heap.free(res);
                try testing.expect(
                    mem.eql(u8, res, "age IN (30, 50, 70)")
                );

                const res2 = try OpText.genToken(heap, "name", OpText {
                    .in = &.{"John", "Jane"}
                });
                defer heap.free(res2);
                try testing.expect(
                    mem.eql(u8, res2, "name IN ('John', 'Jane')")
                );
            }

            // Testing Not In List of Values
            {
                const res = try Op.genToken(heap, "age", Op {
                    .@"!in" = &.{30, 50, 70}
                });
                defer heap.free(res);
                try testing.expect(
                    mem.eql(u8, res, "age NOT IN (30, 50, 70)")
                );

                const res2 = try OpText.genToken(heap, "name", OpText {
                    .@"!in" = &.{"John", "Jane"}
                });
                defer heap.free(res2);
                try testing.expect(
                    mem.eql(u8, res2, "name NOT IN ('John', 'Jane')")
                );
            }

            // Testing NULL Values
            {
                const res = try Op.genToken(heap, "age", Op {
                    .none = true
                });
                defer heap.free(res);
                try testing.expect(mem.eql(u8, res, "age IS NULL"));

                const res2 = try OpText.genToken(heap, "name", OpText {
                    .none = false
                });
                defer heap.free(res2);
                try testing.expect(mem.eql(u8, res2, "name IS NOT NULL"));
            }
        }

        /// **WARNING:** Maximum buffer size is 256 bytes
        fn inList(v: anytype, items: *ArrayList(u8)) !void {
            if (@TypeOf(v) == []const i64) {
                for (v) |item| {
                    var buff: [256]u8 = undefined;
                    const val = try fmt.bufPrint(&buff, "{d}, ", .{item});
                    try items.appendSlice(val);
                }
            } else {
                for (v) |item| {
                    var buff: [256]u8 = undefined;
                    const val = try fmt.bufPrint(&buff, "'{s}', ", .{item});
                    try items.appendSlice(val);
                }
            }
        }
    };
}

const ChainOperator = enum { AND, OR, NOT };

pub const Record = struct {
    const Constraint = enum { Exact, All };
    const Action = enum { Default, Replace, Ignore };

    /// # Generates `SELECT` SQL Statement
    /// **Remarks:** Return value must be freed by the `destroy()`
    /// - `comptime T` - Record bind structure
    /// - `comptime U` - Record retrieval structure
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    pub fn find(
        heap: Allocator,
        comptime T: type,
        comptime U: type,
        from: []const u8
    ) !Find(T, U) {
        // Both T and U must be a struct
        const info = @typeInfo(U);
        if (info != .@"struct") {
            @compileError("Type of `U` must be a valid Read Structure");
        }

        var tokens = ArrayList(u8).init(heap);
        inline for (info.@"struct".fields) |field| {
            try tokens.appendSlice(field.name);
            try tokens.appendSlice(", ");
        }

        debug.assert(tokens.items.len > 0);
        debug.assert(tokens.orderedRemove(tokens.items.len - 1) == ' ');
        debug.assert(tokens.orderedRemove(tokens.items.len - 1) == ',');
        const tok_str = try tokens.toOwnedSlice();
        defer heap.free(tok_str);

        const fmt_str = "SELECT {s} FROM {s}";
        const sql = try fmt.allocPrint(heap, fmt_str, .{tok_str, from});
        return try Find(T, U).create(heap, sql);
    }

    /// - `comptime T` - Record bind structure
    /// - `comptime U` - Record retrieval structure
    fn Find(comptime T: type, comptime U: type) type {
        return struct {
            const OrderBy = union(enum) {
                /// Ascending e.g., `A -> Z`, `1-100` etc.
                asc: []const u8,
                /// Descending e.g., `Z -> A`, `100-1` etc.
                desc: []const u8
            };

            const bind_struct: T = mem.zeroes(T);
            const read_struct: U = mem.zeroes(U);

            heap: Allocator,
            tokens: ArrayList([]const u8),
            statement: ?[]const u8 = null,

            const Self = @This();

            /// # Creates Find Query Builder
            /// **Remarks:** Intended for internal use only
            fn create(heap: Allocator, token: []const u8) !Self {
                return try Common.create(heap, Self, token);
            }

            /// # Destroys Find Query Builder
            pub fn destroy(self: *Self) void { Common.destroy(self); }

            /// # Generates SQL Clause
            /// - Combines **DISTINCT** clause
            pub fn unique(self: *Self) !void {
                if (self.tokens.items.len != 1) {
                    return Error.InvalidFunctionChain;
                }

                const token = self.tokens.orderedRemove(0);
                defer self.heap.free(token);

                const fmt_str = "SELECT DISTINCT {s}";
                const sql = try fmt.allocPrint(self.heap, fmt_str, .{token[7..]});
                try self.tokens.insert(0, sql);
            }

            /// # Generates SQL Comparison Operator Token
            /// **WARNING:** Return value must be freed by the caller
            pub fn filter(
                self: *Self,
                comptime field: []const u8,
                operator: anytype
            ) ![]const u8 {
                const bind_T = @TypeOf(Self.bind_struct);
                return try Common.filter(self, bind_T, field, operator);
            }

            /// # Generates SQL Logical Operator Token
            /// **WARNING:** Return value must be freed by the caller
            pub fn chain(self: *Self, op: ChainOperator) ![]const u8 {
                return try Common.chain(self, op);
            }

            /// # Combines Multiple Token as SQL Group
            /// **WARNING:** Return value must be freed by the caller
            pub fn group(self: *Self, tokens: []const []const u8) ![]const u8 {
                return try Common.group(self, tokens);
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **WHERE** clause
            pub fn when(self: *Self, tokens: []const []const u8) !void {
                return try Common.when(self, tokens);
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **ORDER BY** clause
            pub fn sort(self: *Self, comptime order:[]const OrderBy) !void {
                if (self.tokens.items.len != 2) {
                    return Error.InvalidFunctionChain;
                }

                comptime debug.assert(order.len > 0);
                var sql = ArrayList(u8).init(self.heap);
                try sql.appendSlice("ORDER BY ");

                const read_T = @TypeOf(Self.read_struct);

                inline for (order) |field| {
                    switch (field) {
                        .asc => |v| {
                            if (@hasField(read_T, v)) {
                                try sql.appendSlice(v);
                                try sql.appendSlice(" ASC, ");
                            } else {
                                @compileError("Mismatched Filter Field");
                            }
                        },
                        .desc => |v| {
                            if (@hasField(read_T, v)) {
                                try sql.appendSlice(v);
                                try sql.appendSlice(" DESC, ");
                            } else {
                                @compileError("Mismatched Filter Field");
                            }
                        }
                    }
                }

                debug.assert(sql.orderedRemove(sql.items.len - 1) == ' ');
                debug.assert(sql.orderedRemove(sql.items.len - 1) == ',');
                const token = try sql.toOwnedSlice();
                try self.tokens.append(token);
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **LIMIT** clause
            pub fn limit(self: *Self, comptime v: u32) !void {
                if (self.tokens.items.len != 3) {
                    return Error.InvalidFunctionChain;
                }

                comptime debug.assert(v > 0);
                const token = try fmt.allocPrint(self.heap, "LIMIT {d}", .{v});
                try self.tokens.append(token);
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **OFFSET** clause
            pub fn skip(self: *Self, comptime v: u32) !void {
                if (self.tokens.items.len != 4) {
                    return Error.InvalidFunctionChain;
                }

                comptime debug.assert(v > 0);
                const token = try fmt.allocPrint(self.heap, "OFFSET {d}", .{v});
                try self.tokens.append(token);
            }

            /// # Generates a Complete SQL Statement
            /// **Remarks:** Statement is evaluated only once
            pub fn build(self: *Self) ![]const u8 {
                return try Common.build(self);
            }
        };
    }

    /// # Generates `SELECT COUNT(*)` SQL Statement
    /// **Remarks:** Return value must be freed by the `destroy()`
    /// - `comptime T` - Record bind structure
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    pub fn count(
        heap: Allocator,
        comptime T: type,
        from: []const u8
    ) !Count(T) {
        const fmt_str = "SELECT COUNT(*) FROM {s}";
        const sql = try fmt.allocPrint(heap, fmt_str, .{from});
        return try Count(T).create(heap, sql);
    }

    /// - `comptime T` - Record bind structure
    fn Count(comptime T: type) type {
        return struct {
            const bind_struct: T = mem.zeroes(T);

            heap: Allocator,
            tokens: ArrayList([]const u8),
            statement: ?[]const u8 = null,

            const Self = @This();

            /// # Creates Count Query Builder
            /// **Remarks:** Intended for internal use only
            fn create(heap: Allocator, token: []const u8) !Self {
                return try Common.create(heap, Self, token);
            }

            /// # Destroys Count Query Builder
            pub fn destroy(self: *Self) void { Common.destroy(self); }

            /// # Generates SQL Comparison Operator Token
            /// **WARNING:** Return value must be freed by the caller
            pub fn filter(
                self: *Self,
                comptime field: []const u8,
                operator: anytype
            ) ![]const u8 {
                const bind_T = @TypeOf(Self.bind_struct);
                return try Common.filter(self, bind_T, field, operator);
            }

            /// # Generates SQL Logical Operator Token
            /// **WARNING:** Return value must be freed by the caller
            pub fn chain(self: *Self, op: ChainOperator) ![]const u8 {
                return try Common.chain(self, op);
            }

            /// # Combines Multiple Token as SQL Group
            /// **WARNING:** Return value must be freed by the caller
            pub fn group(self: *Self, tokens: []const []const u8) ![]const u8 {
                return try Common.group(self, tokens);
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **WHERE** clause
            pub fn when(self: *Self, tokens: []const []const u8) !void {
                return try Common.when(self, tokens);
            }

            /// # Generates a Complete SQL Statement
            /// **Remarks:** Statement is evaluated only once
            pub fn build(self: *Self) ![]const u8 {
                return try Common.build(self);
            }
        };
    }

    /// # Generates `INSERT` SQL Statement
    /// **Remarks:** Return value must be freed by the `destroy()`
    /// - `comptime T` - Record bind structure
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    pub fn create(
        heap: Allocator,
        comptime T: type,
        from: []const u8,
        act: Action
    ) !Create(T) {
        const info = @typeInfo(T);
        if (info != .@"struct") {
            @compileError("Type of `T` must be a struct");
        }

        var tags = ArrayList(u8).init(heap);
        inline for (info.@"struct".fields) |field| {
            try tags.appendSlice(field.name);
            try tags.appendSlice(", ");
        }
        debug.assert(tags.orderedRemove(tags.items.len - 1) == ' ');
        debug.assert(tags.orderedRemove(tags.items.len - 1) == ',');
        const tag_str = try tags.toOwnedSlice();
        defer heap.free(tag_str);

        var values = ArrayList(u8).init(heap);
        inline for (info.@"struct".fields) |field| {
            try values.append(':');
            try values.appendSlice(field.name);
            try values.appendSlice(", ");
        }

        debug.assert(values.orderedRemove(values.items.len - 1) == ' ');
        debug.assert(values.orderedRemove(values.items.len - 1) == ',');
        const value_str = try values.toOwnedSlice();
        defer heap.free(value_str);

        const fmt_str = switch(act) {
            .Default => try fmt.allocPrint(
                heap, "INSERT INTO {s}", .{from}
            ),
            .Replace => try fmt.allocPrint(
                heap, "INSERT OR REPLACE INTO {s}", .{from}
            ),
            .Ignore => try fmt.allocPrint(
                heap, "INSERT OR IGNORE INTO {s}", .{from}
            )
        };
        defer heap.free(fmt_str);

        const sql = try fmt.allocPrint(
            heap, "{s} ({s}) VALUES ({s})", .{fmt_str, tag_str, value_str}
        );
        return try Create(T).create(heap, sql);
    }

    /// - `comptime T` - Record bind structure
    fn Create(comptime T: type) type {
        return struct {
            const bind_struct: T = mem.zeroes(T);

            heap: Allocator,
            tokens: ArrayList([]const u8),
            statement: ?[]const u8 = null,

            const Self = @This();

            /// # Creates Count Query Builder
            /// **Remarks:** Intended for internal use only
            fn create(heap: Allocator, token: []const u8) !Self {
                return try Common.create(heap, Self, token);
            }

            /// # Destroys Count Query Builder
            pub fn destroy(self: *Self) void { Common.destroy(self); }

            /// # Generates a Complete SQL Statement
            /// **Remarks:** Statement is evaluated only once
            pub fn build(self: *Self) ![]const u8 {
                return try Common.build(self);
            }
        };
    }

    /// # Generates `UPDATE` SQL Statement
    /// **Remarks:** Return value must be freed by the `destroy()`
    /// - `comptime T` - Record bind structure
    /// - `comptime U` - Record Update structure
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    /// - `opt` - Record update option, Use `All` with **CAUTION**
    pub fn update(
        heap: Allocator,
        comptime T: type,
        comptime U: type,
        from: []const u8,
        opt: Constraint
    ) !Update(T, U) {
        const info = @typeInfo(U);
        if (info != .@"struct") {
            @compileError("Type of `U` must be a struct");
        }

        var value = ArrayList(u8).init(heap);
        inline for (info.@"struct".fields) |field| {
            try value.appendSlice(field.name);
            try value.appendSlice(" = :");
            try value.appendSlice(field.name);
            try value.appendSlice(", ");
        }

        debug.assert(value.items.len > 0);
        debug.assert(value.orderedRemove(value.items.len - 1) == ' ');
        debug.assert(value.orderedRemove(value.items.len - 1) == ',');
        const value_str = try value.toOwnedSlice();
        defer heap.free(value_str);

        const fmt_str = "UPDATE {s} SET {s}";
        const sql = try fmt.allocPrint(heap, fmt_str, .{from, value_str});
        return try Update(T, U).create(heap, sql, opt);
    }

    /// - `comptime T` - Record bind structure
    /// - `comptime U` - Record update structure
    fn Update(comptime T: type, comptime U: type) type {
        return struct {
            const bind_struct: T = mem.zeroes(T);
            const update_struct: U = mem.zeroes(U);

            heap: Allocator,
            option: Constraint = undefined,
            tokens: ArrayList([]const u8),
            statement: ?[]const u8 = null,

            const Self = @This();

            /// # Creates Update Query Builder
            /// **Remarks:** Intended for internal use only
            fn create(
                heap: Allocator,
                token: []const u8,
                opt: Constraint
            ) !Self {
                var str = try Common.create(heap, Self, token);
                str.option = opt;
                return str;
            }

            /// # Destroys Update Query Builder
            pub fn destroy(self: *Self) void { Common.destroy(self); }

            /// # Generates SQL Comparison Operator Token
            /// **WARNING:** Return value must be freed by the caller
            pub fn filter(
                self: *Self,
                comptime field: []const u8,
                operator: anytype
            ) ![]const u8 {
                const bind_T = @TypeOf(Self.bind_struct);
                return try Common.filter(self, bind_T, field, operator);
            }

            /// # Generates SQL Logical Operator Token
            /// **WARNING:** Return value must be freed by the caller
            pub fn chain(self: *Self, op: ChainOperator) ![]const u8 {
                return try Common.chain(self, op);
            }

            /// # Combines Multiple Token as SQL Group
            /// **WARNING:** Return value must be freed by the caller
            pub fn group(self: *Self, tokens: []const []const u8) ![]const u8 {
                return try Common.group(self, tokens);
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **WHERE** clause
            pub fn when(self: *Self, tokens: []const []const u8) !void {
                return try Common.when(self, tokens);
            }

            /// # Generates a Complete SQL Statement
            /// **Remarks:** Statement is evaluated only once
            pub fn build(self: *Self) ![]const u8 {
                switch (self.option) {
                    .Exact => {
                        if (self.tokens.items.len != 2) {
                            return Error.MismatchedConstraint;
                        }
                    },
                    .All => {
                        if (self.tokens.items.len != 1) {
                            return Error.MismatchedConstraint;
                        }
                    }
                }

                return try Common.build(self);
            }
        };
    }

    /// # Generates `DELETE` SQL Statement
    /// **Remarks:** Return value must be freed by the `destroy()`
    /// - `comptime T` - Record bind structure
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    /// - `opt` - Record delete option, Use `All` with **CAUTION**
    pub fn remove(
        heap: Allocator,
        comptime T: type,
        from: []const u8,
        opt: Constraint
    ) !Remove(T) {
        const fmt_str = "DELETE FROM {s}";
        const sql = try fmt.allocPrint(heap, fmt_str, .{from});
        return try Remove(T).create(heap, sql, opt);
    }

    /// - `comptime T` - Record bind structure
    fn Remove(comptime T: type) type {
        return struct {
            const bind_struct: T = mem.zeroes(T);

            heap: Allocator,
            option: Constraint = undefined,
            tokens: ArrayList([]const u8),
            statement: ?[]const u8 = null,

            const Self = @This();

            /// # Creates Remove Query Builder
            /// **Remarks:** Intended for internal use only
            fn create(
                heap: Allocator,
                token: []const u8,
                opt: Constraint
            ) !Self {
                var str = try Common.create(heap, Self, token);
                str.option = opt;
                return str;
            }

            /// # Destroys Remove Query Builder
            pub fn destroy(self: *Self) void { Common.destroy(self); }

            /// # Generates SQL Comparison Operator Token
            /// **WARNING:** Return value must be freed by the caller
            pub fn filter(
                self: *Self,
                comptime field: []const u8,
                operator: anytype
            ) ![]const u8 {
                const bind_T = @TypeOf(Self.bind_struct);
                return try Common.filter(self, bind_T, field, operator);
            }

            /// # Generates SQL Logical Operator Token
            /// **WARNING:** Return value must be freed by the caller
            pub fn chain(self: *Self, op: ChainOperator) ![]const u8 {
                return try Common.chain(self, op);
            }

            /// # Combines Multiple Token as SQL Group
            /// **WARNING:** Return value must be freed by the caller
            pub fn group(self: *Self, tokens: []const []const u8) ![]const u8 {
                return try Common.group(self, tokens);
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **WHERE** clause
            pub fn when(self: *Self, tokens: []const []const u8) !void {
                return try Common.when(self, tokens);
            }

            /// # Generates a Complete SQL Statement
            /// **Remarks:** Statement is evaluated only once
            pub fn build(self: *Self) ![]const u8 {
                switch (self.option) {
                    .Exact => {
                        if (self.tokens.items.len != 2) {
                            return Error.MismatchedConstraint;
                        }
                    },
                    .All => {
                        if (self.tokens.items.len != 1) {
                            return Error.MismatchedConstraint;
                        }
                    }
                }

                return try Common.build(self);
            }
        };
    }
};

/// # Contains Generic Functionality
const Common = struct {
    /// # Creates a Generic Query Builder
    fn create(heap: Allocator, comptime T: type, token: []const u8) !T {
        var clause = T {
            .heap = heap,
            .tokens = ArrayList([]const u8).init(heap)
        };

        try clause.tokens.append(token);
        return clause;
    }

    /// # Destroys Generic Query Builder
    pub fn destroy(self: anytype) void {
        if (self.statement) |v| self.heap.free(v);
        for (self.tokens.items) |item| self.heap.free(item);
        self.tokens.deinit();
    }

    /// # Generates SQL Comparison Operator Token
    /// **Remarks:** Generic filter function implementation
    ///
    /// **WARNING:** Return value must be freed by the caller
    pub fn filter(
        self: anytype,
        comptime T: type,
        comptime field: []const u8,
        operator: anytype
    ) ![]const u8 {
        if (!@hasField(T, field)) @compileError("Mismatched Filter Field");

        switch (@typeInfo(@FieldType(T, field))) {
            .optional => |o| typeCheck(o.child, operator),
            else => typeCheck(@FieldType(T, field), operator)
        }

        return try @TypeOf(operator).genToken(self.heap, field, operator);
    }

    /// # Generates SQL Logical Operator Token
    /// **Remarks:** Generic chain function implementation
    ///
    /// **WARNING:** Return value must be freed by the caller
    pub fn chain(self: anytype, op: ChainOperator) ![]const u8 {
        const token = switch (op) { .AND => "AND", .OR => "OR", .NOT => "NOT" };
        const out = try self.heap.alloc(u8, token.len);
        mem.copyForwards(u8, out, token);
        return out;
    }

    /// # Combines Multiple Token as SQL Group
    /// **Remarks:** Generic group function implementation
    ///
    /// **WARNING:** Return value must be freed by the caller
    pub fn group(self: anytype, tokens: []const []const u8) ![]const u8 {
        var sql = ArrayList(u8).init(self.heap);
        try sql.append('(');

        for (tokens) |token| {
            try sql.appendSlice(token);
            try sql.append(' ');
            self.heap.free(token);
        }

        debug.assert(sql.orderedRemove(sql.items.len - 1) == ' ');
        try sql.append(')');
        const data = try sql.toOwnedSlice();
        return data;
    }

    /// # Generates SQL Clause form Given Tokens
    /// **Remarks:** Generic when function implementation
    ///
    /// - Generates **WHERE** clause
    pub fn when(self: anytype, tokens: []const []const u8) !void {
        if (self.tokens.items.len != 1) {
            return Error.InvalidFunctionChain;
        }

        var sql = ArrayList(u8).init(self.heap);
        try sql.appendSlice("WHERE ");

        for (tokens) |token| {
            try sql.appendSlice(token);
            try sql.append(' ');
            self.heap.free(token);
        }

        debug.assert(sql.orderedRemove(sql.items.len - 1) == ' ');
        const token = try sql.toOwnedSlice();
        try self.tokens.append(token);
    }

    /// # Generates a Complete SQL Statement
    /// **Remarks:** Generic build function implementation
    ///
    /// **Remarks:** Statement is evaluated only once
    pub fn build(self: anytype) ![]const u8 {
        if (self.statement) |sql| return sql
        else {
            var sql = ArrayList(u8).init(self.heap);
            for (self.tokens.items) |token| {
                try sql.appendSlice(token);
                try sql.append(' ');
            }

            debug.assert(sql.orderedRemove(sql.items.len - 1) == ' ');
            try sql.append(';');
            self.statement = try sql.toOwnedSlice();
            return self.statement.?;
        }
    }
};

/// # Checks Field and Operator Type Compatibility
fn typeCheck(comptime T: type, op: anytype) void {
    switch (@typeInfo(T)) {
        .bool, .int, .float, => {
            if (@TypeOf(op) != Operator(i64)
                and op != .contains
                and op != .@"!contains"
                and op != .none)
            {
                @compileError("Mismatched Filter Type");
            }
        },
        .@"struct" => {
            if (@hasField(T, "int")) {
                if (@TypeOf(op) != Operator(i64)
                    and op != .contains
                    and op != .@"!contains"
                    and op != .none)
                {
                    @compileError("Mismatched Filter Type");
                }
            } else if (@hasField(T, "text")) {
                if (@TypeOf(op) != Operator([]const u8)) {
                    @compileError("Mismatched Filter Type");
                }
            } else if (@hasField(T, "blob")) {
                @compileError("Not Permitted on `blob` Data");
            } else {
                @compileError("Unsupported Type Conversion");
            }
        },
        else => {
            @compileError("Unsupported Type Conversion");
        }
    }
}

test { testing.refAllDecls(@This()); }
