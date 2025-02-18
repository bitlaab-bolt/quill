//! # SQL Statement Builder
//! **Remarks:** For complex and computationally expensive queries such as
//! pattern matching on a large text field, use **Raw SQL Statement** instead.

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const debug = std.debug;
const testing = std.testing;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const types = @import("./types.zig");
const Dt = types.DataType;


/// # For Number Fields
pub const Op = Operator(i64);

/// # For Text Fields
pub const OpStr = Operator([]const u8);

const Container = struct {

};

/// # Generic Operator Type for Data Filtering
/// - Comparison is done in Lexicographical Order for text data
/// - Text Matching is case-insensitive and only supports `[]const u8`
pub fn Operator(comptime T: type) type {
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

                const res2 = try OpStr.genToken(heap, "name", OpStr {
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

                const res2 = try OpStr.genToken(heap, "name", OpStr {
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

                const res2 = try OpStr.genToken(heap, "name", OpStr {
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

                const res2 = try OpStr.genToken(heap, "name", OpStr {
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

                const res2 = try OpStr.genToken(heap, "name", OpStr {
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

                const res2 = try OpStr.genToken(heap, "name", OpStr {
                    .@"<=" = "John"
                });
                defer heap.free(res2);
                try testing.expect(mem.eql(u8, res2, "name <= 'John'"));
            }

            // Testing Pattern Matching
            {
                const res = try OpStr.genToken(heap, "name", OpStr {
                    .contains = "John"
                });
                defer heap.free(res);
                try testing.expect(mem.eql(u8, res, "name LIKE '%John%'"));
            }

            // Testing Pattern Matching
            {
                const res = try OpStr.genToken(heap, "name", OpStr {
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

                const res2 = try OpStr.genToken(heap, "name", OpStr {
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

                const res2 = try OpStr.genToken(heap, "name", OpStr {
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

                const res2 = try OpStr.genToken(heap, "name", OpStr {
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

                const res2 = try OpStr.genToken(heap, "name", OpStr {
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

pub const Record = struct {
    // SELECT column1, column2 FROM table_name
    // SELECT DISTINCT column1, column2 FROM table_name;
    pub fn find(heap: Allocator, record: anytype, from: []const u8) !Find {
        const info = @typeInfo(record);
        if (info != .@"struct") {
            @compileError("Type of `record` must be a struct");
        }

        var tokens = ArrayList(u8).init(heap);
        inline for (info.@"struct".fields) |field| {
            try tokens.appendSlice(field.name);
            try tokens.appendSlice(", ");
        }

        debug.assert(tokens.items.len != 0);
        debug.assert(tokens.orderedRemove(tokens.items.len - 2) == ',');
        const tok_str = try tokens.toOwnedSlice();
        defer heap.free(tok_str);

        const fmt_str = "SELECT {s}FROM {s} ";
        const sql = try fmt.allocPrint(heap, fmt_str, .{tok_str, from});
        return try Find.init(heap, sql);
    }

    const Find = struct {
        heap: Allocator,
        tokens: ArrayList([]const u8),
        statement: ?[]const u8 = null,

        const ChainOperator = enum { AND, OR };

        fn init(heap: Allocator, sql: []const u8) !Find {
            var clause = Find {
                .heap = heap,
                .tokens = ArrayList([]const u8).init(heap)
            };

            try clause.tokens.append(sql);
            return clause;
        }

        // call free at last to release the array list
        pub fn free() void {

        }

        /// # Removes Duplicate Records from Query Result
        /// **Remarks:** Do not call more then once per query builder
        pub fn unique(self: *Find) !void {
            const token = self.tokens.orderedRemove(0);
            defer self.heap.free(token);

            const fmt_str = "SELECT DISTINCT {s}";
            const sql = try fmt.allocPrint(self.heap, fmt_str, .{token[7..]});
            try self.tokens.insert(0, sql);
        }

        /// # Generates SQL Comparison Operator Token
        /// **WARNING:** Return value must be freed by the caller
        pub fn filter(
            self: *Find,
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
        /// **WARNING:** Return value must be freed by the caller
        pub fn chain(self: *Find, op: ChainOperator) ![]const u8 {
            const token = switch (op) {.AND => "AND", .OR => "OR"};
            const out = try self.heap.alloc(u8, token.len);
            mem.copyForwards(u8, out, token);
            return out;
        }

        /// # Combines Multiple Token as SQL Group
        /// **WARNING:** Return value must be freed by the caller
        pub fn group(self: *Find, tokens: []const []const u8) ![]const u8 {
            var sql = ArrayList(u8).init(self.heap);
            try sql.append('(');

            for (tokens) |token| {
                try sql.appendSlice(token);
                try sql.append(' ');
                self.heap.free(token);
            }

            try sql.append(')');
            const data = try sql.toOwnedSlice();
            return data;
        }

        /// # Generates SQL Clause form Given Tokens
        /// - Generates **WHERE** clause
        pub fn when(self: *Find, tokens: []const []const u8) !void {
            var sql = ArrayList(u8).init(self.heap);
            try sql.appendSlice("WHERE ");

            for (tokens) |token| {
                try sql.appendSlice(token);
                self.heap.free(token);
            }

            const token = try sql.toOwnedSlice();
            try self.tokens.append(token);
        }

        /// # Generates SQL Clause form Given Tokens
        /// - Generates **WHERE NOT** clause
        pub fn except(self: *Find, tokens: []const []const u8) !void {
            var sql = ArrayList(u8).init(self.heap);
            try sql.appendSlice("WHERE NOT ");

            for (tokens) |token| {
                try sql.appendSlice(token);
                self.heap.free(token);
            }

            const token = try sql.toOwnedSlice();
            try self.tokens.append(token);
        }

        pub fn build(self: *Find) ![]const u8 {
            if (self.statement) |sql| return sql
            else {
                var sql = ArrayList(u8).init(self.heap);
                for (self.tokens.items) |token| {
                    try sql.appendSlice(token);
                }

                try sql.append(';');
                self.statement = try sql.toOwnedSlice();
                return self.statement.?;
            }
        }
    };

    // 





    // pub fn count() CountRecord {

    // }

    // pub fn create() CreateRecord {

    // }

    // pub fn update() UpdateRecord {

    // }

    // pub fn remove() RemoveRecord {

    // }

    // pub fn build() []const u8 {

    // }
};







const RecordCount = struct {

};

const RecordCreate = struct {

};

const RecordUpdate = struct {

};

const RecordRemove = struct {

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