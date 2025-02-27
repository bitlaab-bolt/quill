//! # SQL Statement Builder (Compile-Time)
//! **Remarks:** For complex and computationally expensive queries such as
//! pattern matching on a large text field, use **Raw SQL Statement** instead.

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const debug = std.debug;
const testing = std.testing;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const Dt = @import("./types.zig").DataType;


const Str = []const u8;
const ctPrint = fmt.comptimePrint;

pub const Container = struct {
    /// # Generates `CREATE TABLE` SQL Statement
    /// - `T` - Record Model structure
    /// - `name` - Container name e.g., `users`, `accounts` etc.
    pub fn create(comptime T: type, comptime name: Str) Str {
        const info = @typeInfo(T);
        if (info != .@"struct") {
            @compileError("Quill: Type of `T` must be a Model Structure");
        }

        if (!@hasField(T, "uuid")) {
            @compileError("Quill: Model Structure has no `uuid` field");
        }

        comptime var fields: Str = "";
        inline for (info.@"struct".fields) |field| {
            switch (@typeInfo(field.type)) {
                .optional => |o| {
                    fields = fields ++ comptime genToken(
                        o.child, field.name, true
                    );
                },
                else => {
                    fields = fields ++ comptime genToken(
                        field.type, field.name, false
                    );
                }
            }
        }

        const sql_head = "CREATE TABLE IF NOT EXISTS " ++ name ++ " (\n";
        const sql_tail = "\n) STRICT, WITHOUT ROWID;";
        const data = fields[0..fields.len - 2];

        return ctPrint("{s} {s} {s}", .{sql_head, data, sql_tail});
    }

    /// # Generates SQL Text for a Given Field
    /// **Remarks:** Compile time function e.g., `comptime getToken()`
    fn genToken(T: type, field: Str, opt: bool) Str {
        switch (@typeInfo(T)) {
            .bool, .int => {
                if (!opt) {
                    const fmt_str = "\t{s} INTEGER NOT NULL,\n";
                    return ctPrint(fmt_str, .{field});
                } else {
                    const fmt_str = "\t{s} INTEGER,\n";
                    return ctPrint(fmt_str, .{field});
                }
            },
            .float => {
                if (!opt) {
                    const fmt_str = "\t{s} REAL NOT NULL,\n";
                    return ctPrint(fmt_str, .{field});
                } else {
                    const fmt_str = "\t{s} REAL,\n";
                    return ctPrint(fmt_str, .{field});
                }
            },
            .@"struct" => {
                if (@hasField(T, "int")) {
                    if (!opt) {
                        const fmt_str = "\t{s} INTEGER NOT NULL,\n";
                        return ctPrint(fmt_str, .{field});
                    } else {
                        const fmt_str = "\t{s} INTEGER,\n";
                        return ctPrint(fmt_str, .{field});
                    }
                } else if (@hasField(T, "text")) {
                    if (!opt) {
                        const fmt_str = "\t{s} TEXT NOT NULL,\n";
                        return ctPrint(fmt_str, .{field});
                    } else {
                        const fmt_str = "\t{s} TEXT,\n";
                        return ctPrint(fmt_str, .{field});
                    }
                } else if (@hasField(T, "blob")) {
                    if (mem.eql(u8, field, "uuid")) {
                        if (!opt) {
                            const fmt_str = "\t{s} BLOB PRIMARY KEY,\n";
                            return ctPrint(fmt_str, .{field});
                        } else {
                            @compileError("Quill: UUID Can't Be Optional");
                        }
                    } else {
                        if (!opt) {
                            const fmt_str = "\t{s} BLOB NOT NULL,\n";
                            return ctPrint(fmt_str, .{field});
                        } else {
                            const fmt_str = "\t{s} BLOB,\n";
                            return ctPrint(fmt_str, .{field});
                        }
                    }
                } else {
                    @compileError("Quill: Unknown Field Name");
                }
            },
            else => {
                @compileError("Quill: Malformed Model Data Type");
            }
        }
    }
};

/// # Comparison Operators for Data Filtering
/// - Comparison is done in Lexicographical Order for text data
/// - Text Matching is case-insensitive and only supports `Str`
const Operator = enum {
    /// Checks - Equality
    @"=",
    /// Checks - Inequality
    @"!=",
    /// Checks - Greater Than
    @">",
    /// Checks - Less Than
    @"<",
    /// Checks - Greater Than or Equal To
    @">=",
    /// Checks - Less Than or Equal To
    @"<=",
    /// Checks - Pattern Matching
    contains,
    /// Checks - Pattern Matching
    @"!contains",
    /// Checks - Between Values
    between,
    /// Checks - In List of Values
    in,
    /// Checks - Not In List of Values
    @"!in",
    /// Checks - NULL Values
    @"null",
    /// Checks - Not NULL Value
    @"!null",

    /// # Generates SQL Text for a Given Field
    /// **Remarks:** Compile time function e.g., `comptime getToken()`
    /// - `len` - Number of parameter to be passed for `in` and `@"!in`
    fn genToken(field: Str, op: Operator, len: ?u8) Str {
        switch (op) {
            .@"=" => {
                return ctPrint("{s} = :_{s}", .{field} ** 2);
            },
            .@"!=" => {
                return ctPrint("{s} != :_{s}", .{field} ** 2);
            },
            .@">" => {
                return ctPrint("{s} > :_{s}", .{field} ** 2);
            },
            .@"<" => {
                return ctPrint("{s} < :_{s}", .{field} ** 2);
            },
            .@">=" => {
                return ctPrint("{s} >= :_{s}", .{field} ** 2);
            },
            .@"<=" => {
                return ctPrint("{s} <= :_{s}", .{field} ** 2);
            },
            .contains => {
                return ctPrint("{s} LIKE :_{s}", .{field} ** 2);
            },
            .@"!contains" => {
                return ctPrint("{s} NOT LIKE :_{s}", .{field} ** 2);
            },
            .between => {
                const fmt_str = "{s} BETWEEN :_{s}1 AND :_{s}2";
                return ctPrint(fmt_str, .{field} ** 3);
            },
            .in => {
                if (len == null) @compileError("Quill: `len` can't be null");

                comptime var params: Str = "";
                for (1..len.? + 1) |i| {
                    const parm = ctPrint(":_{s}{d}, ", .{field, i});
                    params = params ++ parm;
                }

                const fmt_str = "{s} IN ({s})";
                const data = params[0..params.len - 2];
                return ctPrint(fmt_str, .{field, data});
            },
            .@"!in" => {
                if (len == null) @compileError("Quill: `len` can't be null");

                comptime var params: Str = "";
                for (1..len.? + 1) |i| {
                    const parm = ctPrint(":_{s}{d}, ", .{field, i});
                    params = params ++ parm;
                }

                const fmt_str = "{s} NOT IN ({s})";
                const data = params[0..params.len - 2];
                return ctPrint(fmt_str, .{field, data});
            },
            .@"null" => {
                return ctPrint("{s} IS NULL", .{field});
            },
            .@"!null" => {
                return ctPrint("{s} IS NOT NULL", .{field});
            }
        }
    }

    test genToken {
        // Testing Equality
        {
            const token = comptime genToken("name", .@"=", null);
            try testing.expect(mem.eql(u8, token, "name = :_name"));
        }

        // Testing Inequality
        {
            const token = comptime genToken("name", .@"!=", null);
            try testing.expect(mem.eql(u8, token, "name != :_name"));
        }

        // Testing Greater Than
        {
            const token = comptime genToken("name", .@">", null);
            try testing.expect(mem.eql(u8, token, "name > :_name"));
        }

        // Testing Less Than
        {
            const token = comptime genToken("name", .@"<", null);
            try testing.expect(mem.eql(u8, token, "name < :_name"));
        }

        // Testing Greater Than or Equal To
        {
            const token = comptime genToken("name", .@">=", null);
            try testing.expect(mem.eql(u8, token, "name >= :_name"));
        }

        // Testing Less Than or Equal To
        {
            const token = comptime genToken("name", .@"<=", null);
            try testing.expect(mem.eql(u8, token, "name <= :_name"));
        }

        // Testing Contains (Pattern Matching)
        {
            const token = comptime genToken("name", .contains, null);
            try testing.expect(mem.eql(u8, token, "name LIKE :_name"));
        }

        // Testing Not Contains (Pattern Matching)
        {
            const token = comptime genToken("name", .@"!contains", null);
            try testing.expect(mem.eql(u8, token, "name NOT LIKE :_name"));
        }

        // Testing Between Values
        {
            const ok_str = "name BETWEEN :_name1 AND :_name2";
            const token = comptime genToken("name", .between, null);
            try testing.expect(mem.eql(u8, token, ok_str));
        }

        // Testing In List of Values
        {
            const ok_str = "name IN (:_name1, :_name2, :_name3)";
            const token = comptime genToken("name", .in, 3);
            try testing.expect(mem.eql(u8, token, ok_str));
        }

        // Testing Not In List of Values
        {
            const ok_str = "name NOT IN (:_name1, :_name2, :_name3)";
            const token = comptime genToken("name", .@"!in", 3);
            try testing.expect(mem.eql(u8, token, ok_str));
        }

        // Testing Null Value
        {
            const token = comptime genToken("name", .@"null", 3);
            try testing.expect(mem.eql(u8, token, "name IS NULL"));
        }

        // Testing Not Null Value
        {
            const token = comptime genToken("name", .@"!null", 3);
            try testing.expect(mem.eql(u8, token, "name IS NOT NULL"));
        }
    }
};

const ChainOperator = enum { AND, OR, NOT };

pub const Record = struct {
    const Constraint = enum { All, Exact };
    const Action = enum { Default, Replace, Ignore };

    /// # Generates `SELECT` SQL Statement
    /// - `T` - Record View structure
    /// - `U` - Record Filter structure
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    pub fn find(T: type, U: type, from: Str) Find(T, U) {
        if (@typeInfo(T) != .@"struct") {
            @compileError("Quill: Type of `T` must be a View Structure");
        }

        if (@typeInfo(U) != .void and @typeInfo(U) != .@"struct") {
            @compileError("Quill: Type of `U` must be a Filter Structure");
        }

        var tokens: Str = "";
        inline for (@typeInfo(T).@"struct".fields) |field| {
            tokens = tokens ++ ctPrint("{s}, ", .{field.name});
        }

        const data = tokens[0..tokens.len - 2];
        const sql = ctPrint("SELECT {s} FROM {s}", .{data, from});

        return Find(T, U).create(sql);
    }

    /// - `T` - Record View structure
    /// - `U` - Record Filter structure
    fn Find(T: type, U: type) type {
        return struct {
            const OrderBy = union(enum) {
                /// Ascending e.g., `A -> Z`, `1-100` etc.
                asc: Str,
                /// Descending e.g., `Z -> A`, `100-1` etc.
                desc: Str
            };

            const t_view: T = mem.zeroes(T);
            const t_filter: U = mem.zeroes(U);

            seq: u8 = 1,
            stmt: Str,

            const Self = @This();

            /// # Creates Find Query Builder
            /// **Remarks:** Intended for internal use only
            fn create(sql: Str) Self { return .{.stmt = sql}; }

            /// # Updates SQL Statement
            /// - Combines **DISTINCT** keyword to the existing statement
            pub fn dist(self: *Self) void {
                const sql = "SELECT DISTINCT";
                const eql = mem.eql(u8, self.stmt[0..15], sql);

                if (!eql and self.seq == 1) self.stmt = sql ++ self.stmt[6..]
                else @compileError("Quill: Invalid Function Chain");
            }

            /// # Generates SQL Comparison Operator Token
            pub fn filter(field: Str, op: Operator, len: ?u8) Str {
                const t = @TypeOf(Self.t_filter);
                return Common.filter(t, field, op, len);
            }

            /// # Generates SQL Logical Operator Token
            pub fn chain(op: ChainOperator) Str {
                return Common.chain(op);
            }

            /// # Combines Multiple Token as SQL Group
            pub fn group(tokens: []const Str) Str {
                return Common.group(tokens);
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **WHERE** clause
            pub fn when(self: *Self, tokens: []const Str) void {
                return Common.when(self, tokens);
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **ORDER BY** clause
            pub fn sort(self: *Self, order:[]const OrderBy) void {
                if (self.seq == 2) self.seq += 1
                else @compileError("Quill: Invalid Function Chain");

                const t = @TypeOf(Self.t_view);

                var clause: Str = "";
                for (order) |field| {
                    switch (field) {
                        .asc => |v| {
                            if (@hasField(t, v)) {
                                clause = clause ++ ctPrint(
                                    "{s} ASC, ", .{v}
                                );
                            } else {
                                @compileError("Mismatched Filter Field");
                            }
                        },
                        .desc => |v| {
                            if (@hasField(t, v)) {
                                clause = clause ++ ctPrint(
                                    "{s} DESC, ", .{v}
                                );
                            } else {
                                @compileError("Mismatched Filter Field");
                            }
                        }
                    }
                }

                const fmt_str = "\nORDER BY {s}";
                const sql = clause[0..clause.len - 2];
                self.stmt = self.stmt ++ ctPrint(fmt_str, .{sql});
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **LIMIT** clause
            pub fn limit(self: *Self, num: u32) void {
                if (self.seq == 3) self.seq += 1
                else @compileError("Quill: Invalid Function Chain");

                const fmt_str = "\nLIMIT {d}";
                self.stmt = self.stmt ++ ctPrint(fmt_str, .{num});
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **OFFSET** clause
            pub fn skip(self: *Self, num: u32) void {
                if (self.seq == 4) self.seq += 1
                else @compileError("Quill: Invalid Function Chain");

                const fmt_str = "\nOFFSET {d}";
                self.stmt = self.stmt ++ ctPrint(fmt_str, .{num});
            }

            /// # Returns Evaluated SQL Statement
            pub fn statement(self: *Self) Str { return Common.statement(self); }
        };
    }

    /// # Generates `SELECT COUNT(*)` SQL Statement
    /// - `T` - Record Filter structure
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    pub fn count(T: type, from: Str) Count(T) {
        if (@typeInfo(T) != .void and @typeInfo(T) != .@"struct") {
            @compileError("Quill: Type of `T` must be a Filter Structure");
        }

        const fmt_str = "SELECT COUNT(*) FROM {s}";
        const sql = ctPrint(fmt_str, .{from});
        return Count(T).create(sql);
    }

    /// - `T` - Record Filter structure
    fn Count(comptime T: type) type {
        return struct {
            const t_filter: T = mem.zeroes(T);

            seq: u8 = 1,
            stmt: Str,

            const Self = @This();

            /// # Creates Count Query Builder
            /// **Remarks:** Intended for internal use only
            fn create(sql: Str) Self { return .{.stmt = sql}; }

            /// # Generates SQL Comparison Operator Token
            pub fn filter(field: Str, op: Operator, len: ?u8) Str {
                const t = @TypeOf(Self.t_filter);
                return Common.filter(t, field, op, len);
            }

            /// # Generates SQL Logical Operator Token
            pub fn chain(op: ChainOperator) Str {
                return Common.chain(op);
            }

            /// # Combines Multiple Token as SQL Group
            pub fn group(tokens: []const Str) Str {
                return Common.group(tokens);
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **WHERE** clause
            pub fn when(self: *Self, tokens: []const Str) void {
                return Common.when(self, tokens);
            }

            /// # Returns Evaluated SQL Statement
            pub fn statement(self: *Self) Str { return Common.statement(self); }
        };
    }

    /// # Generates `INSERT` SQL Statement
    /// - `T` - Record Model structure
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    pub fn create(T: type, from: Str, act: Action) Create(T) {
        if (@typeInfo(T) != .@"struct") {
            @compileError("Quill: Type of `T` must be a Model Structure");
        }

        const token = switch(act) {
            .Default => ctPrint("INSERT INTO {s}", .{from}),
            .Replace => ctPrint("INSERT OR REPLACE INTO {s}", .{from}),
            .Ignore => ctPrint("INSERT OR IGNORE INTO {s}", .{from})
        };

        var fields: Str = "";
        var values: Str = "";
        inline for (@typeInfo(T).@"struct".fields) |field| {
            fields = fields ++ ctPrint("{s}, ", .{field.name});
            values = values ++ ctPrint(":{s}, ", .{field.name});
        }

        const f_data = fields[0..fields.len - 2];
        const v_data = values[0..values.len - 2];

        const fmt_str = "{s} ({s})\nVALUES ({s})";
        const sql = ctPrint(fmt_str, .{token, f_data, v_data});
        return Create(T).create(sql);
    }

    /// - `T` - Record Model structure
    fn Create(T: type) type {
        return struct {
            const t_model: T = mem.zeroes(T);

            stmt: Str,

            const Self = @This();

            /// # Creates Count Query Builder
            /// **Remarks:** Intended for internal use only
            fn create(sql: Str) Self { return .{.stmt = sql}; }

            /// # Returns Evaluated SQL Statement
            pub fn statement(self: *Self) Str { return Common.statement(self); }
        };
    }

    /// # Generates `UPDATE` SQL Statement
    /// - `T` - Record Model structure
    /// - `U` - Record Filter structure
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    /// - `opt` - Record update option, Use `All` with **CAUTION**
    pub fn update(T: type, U: type, from: Str, opt: Constraint) Update(T, U) {
        if (@typeInfo(T) != .@"struct") {
            @compileError("Quill: Type of `T` must be a Model Structure");
        }

        if (@typeInfo(U) != .void and @typeInfo(U) != .@"struct") {
            @compileError("Quill: Type of `U` must be a Filter Structure");
        }

        var tokens: Str = "";
        inline for (@typeInfo(T).@"struct".fields) |field| {
            tokens = tokens ++ ctPrint("{s} = :{s}, ", .{field.name} ** 2);
        }

        const data = tokens[0..tokens.len - 2];
        const sql = ctPrint("UPDATE {s}\nSET {s}", .{from, data});
        return Update(T, U).create(sql, opt);
    }

    /// - `T` - Record Model structure
    /// - `U` - Record Filter structure
    fn Update(T: type, U: type) type {
        return struct {
            const t_model: T = mem.zeroes(T);
            const t_filter: U = mem.zeroes(U);

            stmt: Str,
            seq: u8 = 1,
            option: Constraint = undefined,

            const Self = @This();

            /// # Creates Update Query Builder
            /// **Remarks:** Intended for internal use only
            fn create(sql: Str, opt: Constraint) Self {
                return .{.stmt = sql, .option = opt};
            }

            /// # Generates SQL Comparison Operator Token
            pub fn filter(field: Str, op: Operator, len: ?u8) Str {
                const t = @TypeOf(Self.t_filter);
                return Common.filter(t, field, op, len);
            }

            /// # Generates SQL Logical Operator Token
            pub fn chain(op: ChainOperator) Str { return Common.chain(op); }

            /// # Combines Multiple Token as SQL Group
            pub fn group(tokens: []const Str) Str {
                return Common.group(tokens);
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **WHERE** clause
            pub fn when(self: *Self, tokens: []const Str) void {
                return Common.when(self, tokens);
            }

            /// # Returns Evaluated SQL Statement
            pub fn statement(self: *Self) Str {
                const pass = switch (self.option) {
                    .All => if (self.seq == 1) true else false,
                    .Exact => if (self.seq == 2) true else false
                };

                if (!pass) @compileError("Quill: Failed Update Constraint");
                return Common.statement(self);
            }
        };
    }

    /// # Generates `DELETE` SQL Statement
    /// - `T` - Record Filter structure
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    /// - `opt` - Record delete option, Use `All` with **CAUTION**
    pub fn remove(T: type, from: Str, opt: Constraint) Remove(T) {
        const sql = ctPrint("DELETE FROM {s}", .{from});
        return Remove(T).create(sql, opt);
    }

    /// - `T` - Record Filter structure
    fn Remove(T: type) type {
        return struct {
            const t_filter: T = mem.zeroes(T);

            stmt: Str,
            seq: u8 = 1,
            option: Constraint = undefined,

            const Self = @This();

            /// # Creates Remove Query Builder
            /// **Remarks:** Intended for internal use only
            fn create(sql: Str, opt: Constraint) Self {
                return .{.stmt = sql, .option = opt};
            }

            /// # Generates SQL Comparison Operator Token
            pub fn filter(field: Str, op: Operator, len: ?u8) Str {
                const t = @TypeOf(Self.t_filter);
                return Common.filter(t, field, op, len);
            }

            /// # Generates SQL Logical Operator Token
            pub fn chain(op: ChainOperator) Str { return Common.chain(op); }

            /// # Combines Multiple Token as SQL Group
            pub fn group(tokens: []const Str) Str {
                return Common.group(tokens);
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **WHERE** clause
            pub fn when(self: *Self, tokens: []const Str) void {
                return Common.when(self, tokens);
            }

            /// # Returns Evaluated SQL Statement
            pub fn statement(self: *Self) Str {
                const pass = switch (self.option) {
                    .All => if (self.seq == 1) true else false,
                    .Exact => if (self.seq == 2) true else false
                };

                if (!pass) @compileError("Quill: Failed Remove Constraint");
                return Common.statement(self);
            }
        };
    }
};

/// # Contains Generic Functionality
const Common = struct {
    /// # Generates SQL Comparison Operator Token
    /// **Remarks:** Generic filter function implementation
    pub fn filter(T: type, field: Str, op: Operator, len: ?u8) Str {
        if (!@hasField(T, field)) {
            const fmt_str = "Quill: Field `{s}` doesn't exist on `{s}`";
            @compileError(ctPrint(fmt_str, .{field, T}));
        }

        return Operator.genToken(field, op, len);
    }

    /// # Generates SQL Logical Operator Token
    /// **Remarks:** Generic chain function implementation
    pub fn chain(op: ChainOperator) Str {
        return switch (op) { .AND => "AND", .OR => "OR", .NOT => "NOT" };
    }

    /// # Combines Multiple Token as SQL Group
    /// **Remarks:** Generic group function implementation
    pub fn group(tokens: []const Str) Str {
        var clause: Str = "";
        for (tokens) |token| clause = clause ++ token ++ " ";

        const sql = clause[0..clause.len - 1];
        return ctPrint("({s})", .{sql});
    }

    /// # Generates SQL `WHERE` Statement form Given Tokens
    /// **Remarks:** Generic when function implementation
    pub fn when(self: anytype, tokens: []const Str) void {
        if (self.seq == 1) self.seq += 1
        else @compileError("Quill: Invalid Function Chain");

        var clause: Str = "";
        for (tokens) |token| clause = clause ++ token ++ " ";

        const sql = clause[0..clause.len - 1];
        self.stmt = self.stmt ++ ctPrint("\nWHERE {s}", .{sql});
    }

    /// # Returns Evaluated SQL Statement
    /// **Remarks:** Generic statement function implementation
    pub fn statement(self: anytype) Str {
        if (!mem.endsWith(u8, self.stmt, ";")) self.stmt = self.stmt ++ ";"
        else @compileError("Quill: Invalid Function Chain");

        return self.stmt;
    }
};

test {
    // Reference for Private Declarations
    _ = Operator;

    // Runs all Public and Private ↑ tests in this module
    testing.refAllDecls(@This());
}
