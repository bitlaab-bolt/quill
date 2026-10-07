//! # SQL Statement Builder (Compile-Time)
//! **Remarks:** For complex and computationally expensive queries such as
//! pattern matching on a large text field, use **Raw SQL Statement** instead.

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const testing = std.testing;

const Dt = @import("./types.zig").DataType;


const Str = []const u8;
const ctPrint = fmt.comptimePrint;

/// # Verifies the Given Type is a Structure
/// **Remarks:** Intended for internal use only
fn requireStruct(T: type, comptime role: Str) void {
    if (@typeInfo(T) != .@"struct") {
        const err_str = "@quill: Type of `{s}` Must be a " ++ role ++ " Structure";
        @compileError(ctPrint(err_str, .{@typeName(T)}));
    }
}

/// # Verifies the Given Type is a Filter Structure
/// **Remarks:** Intended for internal use only
fn requireFilter(T: type) void {
    if (@typeInfo(T) != .void and @typeInfo(T) != .@"struct") {
        const err_str = "@quill: Type of `{s}` Must be a Filter Structure";
        @compileError(ctPrint(err_str, .{@typeName(T)}));
    }
}

/// # SQLite Database Table Statement Builder
pub const Container = struct {
    const PrimaryKey = enum { RowId, Uuid, UuidStr };

    /// # Generates `CREATE TABLE` SQL Statement
    /// - `T` - Record Model structure
    /// - `name` - Container name e.g., `users`, `accounts` etc.
    /// - `pk` - Primary Key type of the targeted container
    ///
    /// **Remarks:** `Uuid` prevents Primary Key Localization problem, but blob
    /// streaming requires `RowId`. When `pk` is set to `RowId` then uuid field
    /// of a Model structure (if any) enforces **UNIQUE** constraint. You don't
    /// have to provide a primary key in such cases but including an uuid field
    /// could prevent Primary Key Localization. Making best of the both worlds!
    pub fn create(T: type, name: Str, pk: PrimaryKey) Str {
        requireStruct(T, "Model");

        if (pk == .Uuid and !@hasField(T, "uuid")) {
            const err_str = "@quill: Model Structure `{s}` has no `uuid` Field";
            @compileError(ctPrint(err_str, .{@typeName(T)}));
        }

        comptime var fields: Str = "";
        inline for (@typeInfo(T).@"struct".field_names) |f_name| {
            const FT = @FieldType(T, f_name);
            switch (@typeInfo(FT)) {
                .optional => |o|
                    fields = fields ++ genToken(o.child, f_name, true, pk),
                else =>
                    fields = fields ++ genToken(FT, f_name, false, pk)
            }
        }

        const sql_head = "CREATE TABLE IF NOT EXISTS " ++ name ++ " (\n";
        const sql_tail = switch (pk) {
            .RowId => "\n) STRICT;", else => "\n) STRICT, WITHOUT ROWID;"
        };
        const data = fields[0..fields.len - 2];

        return ctPrint("{s} {s} {s}", .{sql_head, data, sql_tail});
    }

    /// # Generates SQL Text for a Given Field
    /// **Remarks:** Compile-Time function e.g., `comptime getToken()`
    fn genToken(T: type, field: Str, opt: bool, pk: PrimaryKey) Str {
        const err_str = "@quill: Malformed Type `{s}`";

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
            .@"struct" => |s| {
                if (s.field_names.len != 1) {
                    @compileError(ctPrint(err_str, .{@typeName(T)}));
                }

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
                            const fmt_str = switch (pk) {
                                .RowId => "\t{s} BLOB UNIQUE,\n",
                                .Uuid => "\t{s} BLOB PRIMARY KEY,\n",
                                .UuidStr => "\t{s} TEXT PRIMARY KEY,\n",
                            };
                            return ctPrint(fmt_str, .{field});
                        } else {
                            @compileError("@quill: UUID Can't be Optional");
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
                    const name = s.field_names[0];
                    const err_str2 = "@quill: Invalid Field `{s}` in `{s}`";
                    @compileError(ctPrint(err_str2, .{name, @typeName(T)}));
                }
            },
            else => {
                @compileError(ctPrint(err_str, .{@typeName(T)}));
            }
        }
    }
};

/// # Comparison Operators for Data Filtering
/// - Comparison is done in Lexicographical Order for text data
/// - Text Matching is case-insensitive and only supports `[]const u8`
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
    /// - You must include regex patter in your input data e.g., `%John Doe%`
    contains,
    /// Checks - Pattern Matching
    /// - You must include regex patter in your input data e.g., `%John Doe%`
    @"!contains",
    /// Checks - Between Values
    /// Your input data slice must be the length of 2. e.g., `&.{10, 20}`
    between,
    /// Checks - In List of Values
    /// Your input data slice length must be known at compile-time
    in,
    /// Checks - Not In List of Values
    /// Your input data slice length must be known at compile-time
    @"!in",
    /// Checks - NULL Values
    /// No filter structure field is required for this operation
    @"null",
    /// Checks - Not NULL Value
    /// No filter structure field is required for this operation
    @"!null",

    /// # Generates SQL Text for a Given Field
    /// **Remarks:** Compile-Time function e.g., `comptime getToken()`
    /// - `len` - **null**, or the number of parameters for `in` and `@"!in`
    fn genToken(field: Str, op: Operator, len: ?u8) Str {
        switch (op) {
            .@"=", .@"!=", .@">", .@"<", .@">=", .@"<=", .contains, .@"!contains" => {
                const sign: Str = switch (op) {
                    .@"=" => "=",
                    .@"!=" => "!=",
                    .@">" => ">",
                    .@"<" => "<",
                    .@">=" => ">=",
                    .@"<=" => "<=",
                    .contains => "LIKE",
                    .@"!contains" => "NOT LIKE",
                    else => unreachable
                };

                return ctPrint("{s} {s} :_{s}_", .{field, sign, field});
            },
            .between => {
                const fmt_str = "{s} BETWEEN :_{s}1_ AND :_{s}2_";
                return ctPrint(fmt_str, .{field, field, field});
            },
            .in, .@"!in" => {
                if (len == null) @compileError("@quill: `len` can't be `null`");

                comptime var params: Str = "";
                for (1..len.? + 1) |i| {
                    const parm = ctPrint(":_{s}{d}_, ", .{field, i});
                    params = params ++ parm;
                }

                const data = params[0..params.len - 2];
                const fmt_str = if (op == .in) "{s} IN ({s})"
                else "{s} NOT IN ({s})";
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
            try testing.expect(mem.eql(u8, token, "name = :_name_"));
        }

        // Testing Inequality
        {
            const token = comptime genToken("name", .@"!=", null);
            try testing.expect(mem.eql(u8, token, "name != :_name_"));
        }

        // Testing Greater Than
        {
            const token = comptime genToken("name", .@">", null);
            try testing.expect(mem.eql(u8, token, "name > :_name_"));
        }

        // Testing Less Than
        {
            const token = comptime genToken("name", .@"<", null);
            try testing.expect(mem.eql(u8, token, "name < :_name_"));
        }

        // Testing Greater Than or Equal To
        {
            const token = comptime genToken("name", .@">=", null);
            try testing.expect(mem.eql(u8, token, "name >= :_name_"));
        }

        // Testing Less Than or Equal To
        {
            const token = comptime genToken("name", .@"<=", null);
            try testing.expect(mem.eql(u8, token, "name <= :_name_"));
        }

        // Testing Contains (Pattern Matching)
        {
            const token = comptime genToken("name", .contains, null);
            try testing.expect(mem.eql(u8, token, "name LIKE :_name_"));
        }

        // Testing Not Contains (Pattern Matching)
        {
            const token = comptime genToken("name", .@"!contains", null);
            try testing.expect(mem.eql(u8, token, "name NOT LIKE :_name_"));
        }

        // Testing Between Values
        {
            const ok_str = "name BETWEEN :_name1_ AND :_name2_";
            const token = comptime genToken("name", .between, null);
            try testing.expect(mem.eql(u8, token, ok_str));
        }

        // Testing In List of Values
        {
            const ok_str = "name IN (:_name1_, :_name2_, :_name3_)";
            const token = comptime genToken("name", .in, 3);
            try testing.expect(mem.eql(u8, token, ok_str));
        }

        // Testing Not In List of Values
        {
            const ok_str = "name NOT IN (:_name1_, :_name2_, :_name3_)";
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

/// # Logical Operators for Data Filtering
const ChainOperator = enum { AND, OR, NOT };

/// # SQLite Database Row Statement Builder
pub const Record = struct {
    const Constraint = enum { All, Exact };
    const Action = enum { Default, Replace, Ignore };
    const ChainClause = enum { Distinct, Where, OrderedBy, Limit, Offset };

    const OrderBy = union(enum) {
        /// Ascending e.g., `A -> Z`, `1-100` etc.
        ASC: Str,
        /// Descending e.g., `Z -> A`, `100-1` etc.
        DESC: Str
    };

    /// # Ordered Function Execution for Query Chain
    fn FnChain(comptime T: type) type {
        if (@typeInfo(T) != .@"enum") {
            const err_str = "@quill: `{s}` Must be an `enum` Type";
            @compileError(ctPrint(err_str, .{@typeName(T)}));
        }

        return struct {
            cursor: u8,

            const Self = @This();
            const Error = error { InvalidOrder, DuplicateEntry };

            pub fn new() Self { return Self {.cursor = 0}; }

            fn add(self: *Self, variant: T) !void {
                const value = @intFromEnum(variant) + 1;
                if (!self.addable(variant)) {
                    return if (self.cursor == value) Error.DuplicateEntry
                    else Error.InvalidOrder;
                } else {
                    self.cursor = value;
                }
            }

            fn addable(self: *Self, variant: T) bool {
                const value = @intFromEnum(variant) + 1;
                return if (self.cursor >= value) false else true;
            }

            fn peek(self: *Self) ?T {
                return if (self.cursor == 0) null
                else @enumFromInt(self.cursor - 1);
            }
        };
    }

    //##########################################################################
    //# FIND INTERFACE --------------------------------------------------------#
    //##########################################################################

    /// # Generates `SELECT` SQL Statement
    /// - `T` - Record View structure
    /// - `U` - Record Filter structure
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    pub fn find(T: type, U: type, from: Str) Find(T, U) {
        requireStruct(T, "View");
        requireFilter(U);

        var fields: Str = "";
        inline for (@typeInfo(T).@"struct".field_names) |f_name| {
            fields = fields ++ ctPrint("{s}, ", .{f_name});
        }

        const data = fields[0..fields.len - 2];
        const sql = ctPrint("SELECT {s} FROM {s}", .{data, from});

        return Find(T, U).create(sql);
    }

    /// - `T` - Record View structure
    /// - `U` - Record Filter structure
    fn Find(T: type, U: type) type {
        return struct {
            stmt: Str,
            seq: FnChain(ChainClause) = FnChain(ChainClause).new(),

            const Self = @This();

            /// # Creates Find Query Builder
            /// **Remarks:** Intended for internal use only
            fn create(sql: Str) Self { return .{.stmt = sql}; }

            /// # Updates SQL Statement
            /// - Combines **DISTINCT** keyword to the existing statement
            pub fn dist(self: *Self) void {
                self.seq.add(.Distinct) catch |err| {
                    const err_str = "quill: Builder Function - {s}";
                    @compileError(ctPrint(err_str, .{@tagName(err)}));
                };

                const sql = "SELECT DISTINCT";
                self.stmt = sql ++ self.stmt[6..];
            }

            /// # Generates SQL Comparison Operator Token
            pub fn filter(
                self: *const Self,
                field: Str,
                op: Operator,
                len: ?u8
            ) Str {
                _ = self;
                return Common.filter(U, field, op, len);
            }

            /// # Generates SQL Logical Operator Token
            pub fn chain(self: *const Self, op: ChainOperator) Str {
                _ = self;
                return Common.chain(op);
            }

            /// # Combines Multiple Token as SQL Group
            pub fn group(self: *const Self, tokens: []const Str) Str {
                _ = self;
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
                self.seq.add(.OrderedBy) catch |err| {
                    const err_str = "@quill: Builder Function - {s}";
                    @compileError(ctPrint(err_str, .{@errorName(err)}));
                };

                const err_str = "Mismatched Filter Field Name `{s}`";

                var clause: Str = "";
                for (order) |field| {
                    switch (field) {
                        .ASC => |v| {
                            if (@hasField(T, v)) {
                                clause = clause ++ ctPrint("{s} ASC, ", .{v});
                            } else {
                                @compileError(ctPrint(err_str, .{v}));
                            }
                        },
                        .DESC => |v| {
                            if (@hasField(T, v)) {
                                clause = clause ++ ctPrint("{s} DESC, ", .{v});
                            } else {
                                @compileError(ctPrint(err_str, .{v}));
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
                self.seq.add(.Limit) catch |err| {
                    const err_str = "@quill: Builder Function - {s}";
                    @compileError(ctPrint(err_str, .{@errorName(err)}));
                };

                const fmt_str = "\nLIMIT {d}";
                self.stmt = self.stmt ++ ctPrint(fmt_str, .{num});
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **OFFSET** clause
            pub fn skip(self: *Self, num: u32) void {
                self.seq.add(.Offset) catch |err| {
                    const err_str = "@quill: Builder Function - {s}";
                    @compileError(ctPrint(err_str, .{@errorName(err)}));
                };

                const fmt_str = "\nOFFSET {d}";
                self.stmt = self.stmt ++ ctPrint(fmt_str, .{num});
            }

            /// # Returns Evaluated SQL Statement
            pub fn statement(self: *Self) Str { return Common.statement(self); }
        };
    }

    //##########################################################################
    //# COUNT INTERFACE -------------------------------------------------------#
    //##########################################################################

    /// # Generates `SELECT COUNT(*)` SQL Statement
    /// - `T` - Record Filter structure
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    pub fn count(T: type, from: Str) Count(T) {
        requireFilter(T);

        const fmt_str = "SELECT COUNT(*) FROM {s}";
        const sql = ctPrint(fmt_str, .{from});
        return Count(T).create(sql);
    }

    /// # Shared Builder for Filter Capable Statements
    /// - `U` - Record Filter structure (may be `void`)
    /// - `guard` - Enforces statement constraint when not **null**
    /// - `label` - Constraint violation message e.g., `Update`
    /// **Remarks:** Intended for internal use only
    fn Filtered(comptime U: type, comptime guard: ?Constraint, comptime label: Str) type {
        return struct {
            stmt: Str,
            seq: FnChain(ChainClause) = FnChain(ChainClause).new(),

            const Self = @This();

            /// # Creates Query Builder
            /// **Remarks:** Intended for internal use only
            fn create(sql: Str) Self { return .{.stmt = sql}; }

            /// # Generates SQL Comparison Operator Token
            pub fn filter(
                self: *const Self,
                field: Str,
                op: Operator,
                len: ?u8
            ) Str {
                _ = self;
                return Common.filter(U, field, op, len);
            }

            /// # Generates SQL Logical Operator Token
            pub fn chain(self: *const Self, op: ChainOperator) Str {
                _ = self;
                return Common.chain(op);
            }

            /// # Combines Multiple Token as SQL Group
            pub fn group(self: *const Self, tokens: []const Str) Str {
                _ = self;
                return Common.group(tokens);
            }

            /// # Generates SQL Clause form Given Tokens
            /// - Generates **WHERE** clause
            pub fn when(self: *Self, tokens: []const Str) void {
                return Common.when(self, tokens);
            }

            /// # Returns Evaluated SQL Statement
            pub fn statement(self: *Self) Str {
                if (guard) |opt| {
                    const fc = self.seq.peek();
                    const pass = switch (opt) {
                        .All => fc == null,
                        .Exact => fc != null and fc == .Where
                    };

                    if (!pass) @compileError(
                        "@quill: Failed " ++ label ++ " Constraint"
                    );
                }

                return Common.statement(self);
            }
        };
    }

    /// - `T` - Record Filter structure
    fn Count(comptime T: type) type {
        return Filtered(T, null, "Count");
    }

    //##########################################################################
    //# CREATE INTERFACE ------------------------------------------------------#
    //##########################################################################

    /// # Generates `INSERT` SQL Statement
    /// - `T` - Record Model structure
    /// - `to` - Container name e.g., `users`, `accounts` etc.
    pub fn create(T: type, to: Str, act: Action) Create() {
        requireStruct(T, "Model");

        const token = switch(act) {
            .Default => ctPrint("INSERT INTO {s}", .{to}),
            .Replace => ctPrint("INSERT OR REPLACE INTO {s}", .{to}),
            .Ignore => ctPrint("INSERT OR IGNORE INTO {s}", .{to})
        };

        var fields: Str = "";
        var values: Str = "";
        inline for (@typeInfo(T).@"struct".field_names) |f_name| {
            fields = fields ++ ctPrint("{s}, ", .{f_name});
            values = values ++ ctPrint(":{s}, ", .{f_name});
        }

        const f_data = fields[0..fields.len - 2];
        const v_data = values[0..values.len - 2];

        const fmt_str = "{s} ({s})\nVALUES ({s})";
        const sql = ctPrint(fmt_str, .{token, f_data, v_data});
        return Create().create(sql);
    }

    /// - Record Model structure
    fn Create() type {
        return struct {
            stmt: Str,

            const Self = @This();

            /// # Creates Create Query Builder
            /// **Remarks:** Intended for internal use only
            fn create(sql: Str) Self { return .{.stmt = sql}; }

            /// # Returns Evaluated SQL Statement
            pub fn statement(self: *Self) Str { return Common.statement(self); }
        };
    }

    //##########################################################################
    //# UPDATE INTERFACE ------------------------------------------------------#
    //##########################################################################

    /// # Generates `UPDATE` SQL Statement
    /// - `T` - Record Model structure
    /// - `U` - Record Filter structure
    /// - `to` - Container name e.g., `users`, `accounts` etc.
    /// - `opt` - Record update option, Use `All` with **CAUTION**
    /// # Generates `UPDATE` SQL Statement
    /// - `T` - Record Model structure
    /// - `U` - Record Filter structure
    /// - `to` - Container name e.g., `users`, `accounts` etc.
    /// - `opt` - Record update option, Use `All` with **CAUTION**
    pub fn update(
        T: type,
        U: type,
        to: Str,
        comptime opt: Constraint
    ) Update(U, opt) {
        requireStruct(T, "Model");
        requireFilter(U);

        var fields: Str = "";
        inline for (@typeInfo(T).@"struct".field_names) |f_name| {
            fields = fields ++ ctPrint("{s} = :{s}, ", .{f_name, f_name});
        }

        const data = fields[0..fields.len - 2];
        const sql = ctPrint("UPDATE {s}\nSET {s}", .{to, data});
        return Update(T, U, opt).create(sql);
    }

    /// - `T` - Record Filter structure
    fn Update(comptime T: type, comptime guard: Constraint) type {
        return Filtered(T, guard, "Update");
    }

    //##########################################################################
    //# REMOVE INTERFACE ------------------------------------------------------#
    //##########################################################################

    /// # Generates `DELETE` SQL Statement
    /// - `T` - Record Filter structure
    /// - `from` - Container name e.g., `users`, `accounts` etc.
    /// - `opt` - Record delete option, Use `All` with **CAUTION**
    pub fn remove(T: type, from: Str, comptime opt: Constraint) Remove(T, opt) {
        requireFilter(T);

        const sql = ctPrint("DELETE FROM {s}", .{from});
        return Remove(T, opt).create(sql);
    }

    /// - `T` - Record Filter structure
    fn Remove(comptime T: type, comptime guard: Constraint) type {
        return Filtered(T, guard, "Remove");
    }
};

//##############################################################################
//# GENERIC FUNCTIONALITY -----------------------------------------------------#
//##############################################################################

/// # Contains Generic Functionality
const Common = struct {
    /// # Generates SQL Comparison Operator Token
    /// **Remarks:** Generic filter function implementation
    pub fn filter(T: type, field: Str, op: Operator, len: ?u8) Str {
        if (@typeInfo(T) == .void) {
            const err_str = "@quill: Filter Structure can't be `void`";
            @compileError(ctPrint(err_str, .{}));
        }

        if (!@hasField(T, field)) {
            const err_str = "@quill: Field `{s}` doesn't Exists on `{s}`";
            @compileError(ctPrint(err_str, .{field, @typeName(T)}));
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
        self.seq.add(.Where) catch |err| {
            const err_str = "@quill: Builder Function - {s}";
            @compileError(ctPrint(err_str, .{@errorName(err)}));
        };

        var clause: Str = "";
        for (tokens) |token| clause = clause ++ token ++ " ";

        const sql = clause[0..clause.len - 1];
        self.stmt = self.stmt ++ ctPrint("\nWHERE {s}", .{sql});
    }

    /// # Returns Evaluated SQL Statement
    /// **Remarks:** Generic statement function implementation
    pub fn statement(self: anytype) Str {
        if (!mem.endsWith(u8, self.stmt, ";")) self.stmt = self.stmt ++ ";"
        else @compileError("@quill: Invalid Function Chain");

        return self.stmt;
    }
};

test "record statements" {
    const Model = struct { id: i64, name: []const u8, score: f64 };
    const Filter = struct { name: []const u8, score: i64 };

    // FIND with DISTINCT, WHERE, ORDER BY, LIMIT and OFFSET
    {
        const find_stmt = comptime blk: {
            var sql = Record.find(Model, Filter, "users");
            const eq = sql.filter("name", .@"=", null);
            const bt = sql.filter("score", .between, null);
            const in = sql.filter("score", .in, 2);
            const grp = sql.group(&.{ eq, "AND", "NOT", bt });
            sql.when(&.{ grp, "OR", in });
            sql.sort(&.{ .{ .ASC = "name" }, .{ .DESC = "score" } });
            sql.limit(10);
            sql.skip(5);
            break :blk sql.statement();
        };
        try testing.expectEqualStrings(
            "SELECT DISTINCT id, name, score FROM users\nWHERE (name = :_name_ AND NOT score BETWEEN :_score1_ AND :_score2_) OR score IN (:_score1_, :_score2_)\nORDER BY name ASC, score DESC\nLIMIT 10\nOFFSET 5;",
            find_stmt
        );
    }

    // COUNT with WHERE
    {
        const stmt = comptime blk: {
            var sql = Record.count(Filter, "users");
            const f = sql.filter("score", .@">", null);
            sql.when(&.{f});
            break :blk sql.statement();
        };
        try testing.expectEqualStrings(
            "SELECT COUNT(*) FROM users\nWHERE score > :_score_;",
            stmt
        );
    }

    // UPDATE with WHERE Constraint
    {
        const stmt = comptime blk: {
            var sql = Record.update(Model, Filter, "users", .Exact);
            const f = sql.filter("name", .contains, null);
            sql.when(&.{f});
            break :blk sql.statement();
        };
        try testing.expectEqualStrings(
            "UPDATE users\nSET id = :id, name = :name, score = :score\nWHERE name LIKE :_name_",
            stmt
        );
    }

    // REMOVE All and Exact
    {
        const stmt = comptime blk: {
            var sql = Record.remove(Filter, "users", .All);
            break :blk sql.statement();
        };
        try testing.expectEqualStrings("DELETE FROM users;", stmt);
    }

    {
        const stmt = comptime blk: {
            var sql = Record.remove(Filter, "users", .Exact);
            const f = sql.filter("name", .@"!=", null);
            sql.when(&.{f});
            break :blk sql.statement();
        };
        try testing.expectEqualStrings(
            "DELETE FROM users\nWHERE name != :_name_",
            stmt
        );
    }

    // CREATE with Action
    {
        const stmt = comptime Record.create(Model, "users", .Ignore).statement();
        try testing.expectEqualStrings(
            "INSERT OR IGNORE INTO users (id, name, score)\nVALUES (:id, :name, :score)",
            stmt
        );
    }
}

test {
    // Reference for Private Declarations
    _ = Operator;

    // Runs all Public and Private ↑ tests in this module
    testing.refAllDecls(@This());
}
