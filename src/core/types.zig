//! # Type Declaration and Conversion Module

const std = @import("std");
const fmt = std.fmt;
const log = std.log;
const mem = std.mem;
const debug = std.debug;
const Type = std.builtin.Type;
const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;

const jsonic = @import("jsonic");
const Json = jsonic.StaticJson;

const sqlite3 = @import("../binding/sqlite3.zig");
const Bind = sqlite3.Bind;
const Column = sqlite3.Column;


const ctPrint = fmt.comptimePrint;

const Error = error {
    MismatchedType,
    MismatchedSize,
    MismatchedValue,
    MismatchedFields,
    UnexpectedNullValue,
    UnexpectedTypeCasting
};

/// # Supported Data Types for a Record Field
/// - Only use the following types for data binding and retrieval
/// - All types can be combined as optional except the **Primary Key**
pub const DataType = struct {
    pub const Int = i64;
    pub const Bool = bool;
    pub const Float = f64;
    pub const Slice = []const u8;

    const err_str = "Quill: Unsupported TypeCast of Type `{s}`";
    const err_str2 = "Quill: Pointer Type of `{s}` Must be `[]const u8`";

    /// # TypeCasts from SQLite `Integer`, `Text`, or `Blob` Data
    /// **WARNING:** Use this type function exclusively for data retrieval
    /// - `T` - Given type must be an `enum`, `struct` or `[]const T`
    pub fn Any(comptime T: type) type {
        switch (@typeInfo(T)) {
            .@"enum", .@"struct", .pointer => return T,
            else => @compileError(ctPrint(err_str, .{@typeName(T)}))
        }
    }

    const CastKind = enum { Int, Text, Blob };

    /// # TypeCasts into SQlite `Integer`, `Text`, or `Blob` Data
    /// **WARNING:** Use this type function exclusively for data binding
    /// - `comptime T` - Given type must be an `enum` or a `struct`
    pub fn CastInto(kind: CastKind, comptime T: type) type {
        switch (kind) {
            .Int => {
                switch (@typeInfo(T)) {
                    .@"enum" => return struct { int: T },
                    else => @compileError(ctPrint(err_str, .{@typeName(T)}))
                }
            },
            .Text => {
                switch (@typeInfo(T)) {
                    .@"enum", .@"struct" => return struct { text: T },
                    .pointer => |p| {
                        constSlice(p);
                        return struct { text: T };
                    },
                    else => @compileError(ctPrint(err_str, .{@typeName(T)}))
                }
            },
            .Blob => {
                switch (@typeInfo(T)) {
                    .pointer => |p| {
                        constSlice(p);
                        if (p.child == u8) return struct { blob: T }
                        else @compileError(ctPrint(err_str2, .{T}));
                    },
                    else => @compileError(ctPrint(err_str, .{@typeName(T)}))
                }
            }
        }
    }

    fn constSlice(ptr: Type.Pointer) void {
        if (!(ptr.is_const and ptr.size == .slice)) {
            const fmt_str = "Quill: Pointer Type `{s}` Must be `[]const T`";
            @compileError(ctPrint(fmt_str, .{@typeName(ptr.child)}));
        }
    }
};

/// # Converts Field Data from the Given Record Structure
/// **Remarks:** Intended for internal use only
pub fn convertFrom(
    heap: Allocator,
    list: *ArrayList([]const u8),
    bind: *Bind,
    record: anytype
) !void {
    const info = @typeInfo(@TypeOf(record));
    if (info != .@"struct") {
        const fmt_str = "Quill: Type of `{s}` Must be a Struct";
        @compileError(ctPrint(fmt_str, .{@typeName(record)}));
    }

    const s_info = info.@"struct";
    const count = bind.parameterCount();

    if (count != s_info.fields.len) {
        const t_name = @typeName(@TypeOf(record));

        if (count < s_info.fields.len) {
            const err_str = "Missing `{s}` from `{s}` on SQL Statement";
            inline for (s_info.fields) |field| {
                _ = bind.parameterIndex(":" ++ field.name) catch {
                    log.warn(err_str, .{field.name, t_name});
                };
            }
        } else {
            const err_str = "Missing `{s}` on `{s}` from SQL Statement";
            for (0..@intCast(count)) |i| {
                const pos = @as(i32, @intCast(i)) + 1;
                const name = (try bind.parameterName(pos)).?;
                defer heap.free(name);

                var exist: bool = false;
                inline for (s_info.fields) |field| {
                    if (mem.eql(u8, name, ":" ++ field.name)) exist = true;
                }

                if (!exist) log.warn(err_str, .{name, t_name});
            }
        }

        return Error.MismatchedFields;
    }

    inline for (s_info.fields) |field| {
        const pos = try bind.parameterIndex(":" ++ field.name);
        const value = @field(record, field.name);

        switch (@typeInfo(field.type)) {
            .optional => |_| {
                if (value == null) try bind.none(pos)
                else try typeCast(heap, bind, pos, value.?, list);
            },
            else => try typeCast(heap, bind, pos, value, list)
        }
    }
}

/// # Casts Scaler and Complex (user defined) Types
fn typeCast(
    heap: Allocator,
    bind: *Bind,
    i: i32,
    value: anytype,
    list: *ArrayList([]const u8),
) !void {
    const T = @TypeOf(value);
    const err_str1 = "Quill: Unsupported Type Cast `{s}`";
    const err_str2 = "Quill: Unexpected Type Cast `{s}`";
    const err_str3 = "Quill: Field Type of `{s}` doesn't Exist on `DataType`";

    switch (@typeInfo(T)) {
        .@"struct" => |s| {
            comptime debug.assert(s.fields.len == 1);
            const child = @field(value, s.fields[0].name);
            const info = @typeInfo(@TypeOf(child));

            switch (info) {
                .@"enum" => {
                    if (@hasField(T, "int")) {
                        try bind.int(i, @intFromEnum(child));
                    } else if (@hasField(T, "text")) {
                        try bind.text(i, @tagName(child));
                    } else {
                        @compileError(ctPrint(err_str1, .{@typeName(T)}));
                    }
                },
                .@"struct" => {
                    if (@hasField(T, "text")) {
                        const out = try Json.stringify(heap, child);
                        try list.append(out);
                        try bind.text(i, out);
                    } else {
                        @compileError(ctPrint(err_str1, .{@typeName(T)}));
                    }
                },
                .pointer => |p| {
                    DataType.constSlice(p);

                    if (@hasField(T, "text")) {
                        if (p.child == u8) try bind.text(i, child)
                        else {
                            const out = try Json.stringify(heap, child);
                            try list.append(out);
                            try bind.text(i, out);
                        }
                    } else if (@hasField(T, "blob")) {
                        if (p.child == u8) try bind.blob(i, child)
                        else {
                            const t_name = @typeName(p.child);
                            @compileError(ctPrint(err_str2, .{t_name}));
                        }
                    }
                    else {
                        @compileError(ctPrint(err_str1, .{@typeName(T)}));
                    }
                },
                else => {
                    @compileError(ctPrint(err_str2, .{@typeName(T)}));
                }
            }
        },
        else => {
            switch (T) {
                DataType.Int => {
                    try bind.int64(i, value);
                },
                DataType.Bool => {
                    switch (value) {
                        true => try bind.int(i, 1),
                        false => try bind.int(i, 0)
                    }
                },
                DataType.Float => {
                    try bind.double(i, value);
                },
                else => {
                    @compileError(ctPrint(err_str3, .{@typeName(T)}));
                }
            }
        }
    }
}

/// # Converts Field Data into the Given Record Structure
/// **Remarks:** Intended for internal use only
pub fn convertTo(heap: Allocator, col: *Column, comptime T: type) !T {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        const fmt_str = "Quill: Type of `{s}` Must be a Struct";
        @compileError(ctPrint(fmt_str, .{@typeName(T)}));
    }

    var dest: T = undefined;
    const fields = info.@"struct".fields;
    if (!matchRecord(col, fields)) return Error.MismatchedFields;

    for (0..@as(usize, @intCast(col.count()))) |index| {
        const i: i32 = @intCast(index);
        inline for (fields) |field| {
            if (mem.eql(u8, col.name(i), field.name[0..])) {
                switch (@typeInfo(field.type)) {
                    .optional => |o| {
                        if (col.dataType(i) == .Null) {
                            @field(dest, field.name) = null;
                        } else {
                            try typeConversion(heap, col, i, &dest, o.child, field.name);
                        }
                    },
                    else => {
                        try typeConversion(heap, col, i, &dest, field.type, field.name);
                    }
                }
            }
        }
    }

    return dest;
}

/// # Cross Checks Column and Structure Fields
fn matchRecord(col: *Column, fields: []const Type.StructField) bool {
    // TODO: Show which field name is missing
    if (fields.len != col.count()) return false;

    var count: i32 = 0;
    for (0..@as(usize, @intCast(col.count()))) |index| {
        const i: i32 = @intCast(index);
        inline for (fields) |field| {
            if (mem.eql(u8, col.name(i), field.name[0..])) count += 1;
        }
    }

    return if (count == col.count()) true else false;
}

/// # Converts Scaler and Complex (user defined) Types
fn typeConversion(
    heap: Allocator,
    col: *Column,
    i: i32,
    rec: anytype,
    comptime T: type,
    comptime tag: []const u8
) !void {
    const err_str = "Quill: Field Type of `{s}` doesn't Exist on `DataType`";

    switch (@typeInfo(T)) {
        .pointer => |p| {
            DataType.constSlice(p);
            if (p.child == u8) {
                if (col.dataType(i) == .Text) {
                    if (try col.text(i)) |data| @field(rec, tag) = data
                    else return Error.UnexpectedNullValue;
                } else if (col.dataType(i) == .Blob) {
                    if (try col.blob(i)) |data| @field(rec, tag) = data
                    else return Error.UnexpectedNullValue;
                } else {
                    return Error.MismatchedType;
                }
            } else {
                if (col.dataType(i) == .Text) {
                    const json_str = if (try col.text(i)) |data| data
                    else return Error.UnexpectedNullValue;

                    defer heap.free(json_str);
                    errdefer heap.free(json_str);

                    const data_struct = try Json.parse(T, heap, json_str);
                    @field(rec, tag) = data_struct;
                } else {
                    return Error.MismatchedType;
                }
            }
        },
        .@"struct" => {
            if (col.dataType(i) == .Text) {
                const json_str = if (try col.text(i)) |data| data
                else return Error.UnexpectedNullValue;

                defer heap.free(json_str);
                errdefer heap.free(json_str);

                const data_struct = try Json.parse(T, heap, json_str);
                @field(rec, tag) = data_struct;
            } else {
                return Error.MismatchedType;
            }
        },
        .@"enum" => {
            if (col.dataType(i) == .Int) {
                const size = @sizeOf(@typeInfo(T).@"enum".tag_type);
                if (size > col.bytes(i)) return Error.MismatchedSize;
                @field(rec, tag) = @enumFromInt(col.int(i));
            } else if (col.dataType(i) == .Text) {
                const variant = if (try col.text(i)) |data| data
                else return Error.UnexpectedNullValue;

                defer heap.free(variant);
                errdefer heap.free(variant);

                inline for (@typeInfo(T).@"enum".fields) |field| {
                    if (mem.eql(u8, field.name, variant)) {
                        @field(rec, tag) = @field(T, field.name);
                        return;
                    }
                }
            } else {
                return Error.MismatchedType;
            }
        },
        else => {
            switch (T) {
                DataType.Bool => {
                    if (col.dataType(i) == .Int) {
                        if (col.bytes(i) != 1) return Error.MismatchedSize;
                        switch (col.int(i)) {
                            0 => @field(rec, tag) = false,
                            1 => @field(rec, tag) = true,
                            else => return Error.MismatchedValue
                        }
                    } else {
                        return Error.MismatchedType;
                    }
                },
                DataType.Int => {
                    if (col.dataType(i) == .Int) {
                        if (col.bytes(i) <= 4) @field(rec, tag) = col.int(i)
                        else @field(rec, tag) = col.int64(i);
                    } else {
                        return Error.MismatchedType;
                    }
                },
                DataType.Float => {
                    if (col.dataType(i) == .Float) {
                        @field(rec, tag) = col.double(i);
                    } else {
                        return Error.MismatchedType;
                    }
                },
                else => {
                    @compileError(ctPrint(err_str, .{@TypeOf(T)}));
                }
            }
        }
    }
}
