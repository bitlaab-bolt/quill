//! # Type Declaration and Conversion Module

const std = @import("std");
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


const Error = error {
    MismatchedType,
    MismatchedSize,
    MismatchedValue,
    UnexpectedNullValue,
    UnexpectedTypeCasting
};

/// # Supported Data Types for a Record Field
/// - Only use the following types for data binding and retrieval
/// - All types can be combined as optional except the **Primary Key**
pub const DataType = struct {
    pub const Uuid = [16]u8;
    pub const Int = i64;
    pub const Bool = bool;
    pub const Float = f64;
    pub const Slice = []const u8;

    /// # TypeCast from SQlite `Integer`, `Text`, or `Blob` Data
    /// **WARNING:** Use this type function exclusively for data retrieval
    /// - `comptime T` - Given type must be an `enum` or a `struct`
    pub fn Any(comptime T: type) type {
        switch (@typeInfo(T)) {
            .@"enum", .@"struct" => return T,
            else => @compileError("Unsupported Data Type")
        }
    }

    const CastKind = enum { Int, Text, Blob };

    /// # TypeCast into SQlite `Integer`, `Text`, or `Blob` Data
    /// **WARNING:** Use this type function exclusively for data binding
    /// - `comptime T` - Given type must be an `enum` or a `struct`
    pub fn CastInto(kind: CastKind, comptime T: type) type {
        switch (kind) {
            .Int => {
                switch (@typeInfo(T)) {
                    .@"enum" => return struct { int: T },
                    else => @compileError("Unsupported Type Conversion")
                }
            },
            .Text => {
                switch (@typeInfo(T)) {
                    .@"enum", .@"struct" => return struct { text: T },
                    .pointer => |p| {
                        constSlice(p);
                        return struct { text: T };
                    },
                    else => @compileError("Unsupported Type Conversion")
                }
            },
            .Blob => {
                switch (@typeInfo(T)) {
                    .pointer => |p| {
                        constSlice(p);
                        return struct { blob: T };
                    },
                    else => @compileError("Unsupported Type Conversion")
                }
            }
        }
    }

    fn constSlice(ptr: Type.Pointer) void {
        if (!(ptr.is_const and ptr.size == .slice and ptr.child == u8)) {
            @compileError("Pointer type must be `[]const u8`");
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
    const struct_info = @typeInfo(@TypeOf(record)).@"struct";
    debug.assert(bind.parameterCount() == struct_info.fields.len);

    inline for (struct_info.fields) |field| {
        const pos = try bind.parameterIndex(":" ++ field.name);
        switch (field.type) {
            DataType.Uuid => {
                try bind.blob(pos, &@field(record, field.name));
            },
            DataType.Int => {
                try bind.int64(pos, @field(record, field.name));
            },
            ?DataType.Int => {
                if (@field(record, field.name) == null) try bind.none(pos)
                else try bind.int64(pos, @field(record, field.name));
            },
            DataType.Bool => {
                try fromBool(bind, pos, record, field.name);
            },
            ?DataType.Bool => {
                if (@field(record, field.name) == null) try bind.none(pos)
                else try fromBool(bind, pos, record, field.name);
            },
            DataType.Float => {
               try bind.double(pos, @field(record, field.name));
            },
            ?DataType.Float => {
                if (@field(record, field.name) == null) try bind.none(pos)
                else try bind.double(pos, @field(record, field.name));
            },
            else => {
                // Handles Automatic Type Casting
                if (@typeInfo(field.type) == .@"struct") {
                    try typeCast(
                        heap, bind, pos, record, field.name, field.type, list
                    );
                } else if (@typeInfo(field.type) == .optional) {
                    if (@field(record, field.name) == null) try bind.none(pos)
                    else {
                        const opt = @typeInfo(field.type).optional;
                        try typeCast(
                            heap, bind, pos, record, field.name, opt.child, list
                        );
                    }
                } else {
                    @compileError("Field type must be one of `quill.DataType`");
                }
            }
        }
    }
}

fn fromBool(bind: *Bind, i: i32, rec: anytype, comptime tag: []const u8) !void {
    switch (@field(rec, tag)) {
        true => try bind.int(i, 1),
        false => try bind.int(i, 0)
    }
}

/// # User Defined Type Casting
fn typeCast(
    heap: Allocator,
    bind: *Bind,
    i: i32,
    rec: anytype,
    comptime tag: []const u8,
    comptime T: type,
    list: *ArrayList([]const u8)
) !void {
    const target = @typeInfo(T).@"struct";
    comptime debug.assert(target.fields.len == 1);

    const child = @field(@field(rec, tag), target.fields[0].name);
    const info = @typeInfo(@TypeOf(child));

    switch (info) {
        .@"enum" => {
            if (@hasField(T, "int")) try bind.int(i, @intFromEnum(child))
            else if (@hasField(T, "text")) try bind.text(i, @tagName(child))
            else @compileError("Unexpected Field Name");
        },
        .@"struct" => {
            if (@hasField(T, "text")) {
                const out = try Json.stringify(heap, child);
                try bind.text(i, try list.append(out));
            } else @compileError("Unexpected Field Name");
        },
        .pointer => |p| {
            DataType.constSlice(p);

            if (@hasField(T, "text")) try bind.text(i, child)
            else if (@hasField(T, "blob")) try bind.blob(i, child)
            else @compileError("Unexpected Field Name");
        },
        else => @compileError("Unexpected Type Conversion")
    }
}

/// # Converts Field Data into the Given Record Structure
/// **Remarks:** Intended for internal use only
pub fn convertTo(heap: Allocator, col: *Column, comptime T: type) !T {
    var row_struct: T = undefined;
    const struct_info = @typeInfo(T).@"struct";

    for (0..@as(usize, @intCast(col.count()))) |index| {
        const i: i32 = @intCast(index);

        inline for (struct_info.fields) |field| {
            if (mem.eql(u8, col.name(i), field.name[0..])) {
                switch (field.type) {
                    DataType.Bool => {
                        try toBool(col, i, &row_struct, field.name);
                    },
                    ?DataType.Bool => {
                        if (col.dataType(i) == .Null) {
                            @field(row_struct, field.name) = null;
                        } else {
                            try toBool(col, i, &row_struct, field.name);
                        }
                    },
                    DataType.Int => {
                        try toInt(col, i, &row_struct, field.name);
                    },
                    ?DataType.Int => {
                        if (col.dataType(i) == .Null) {
                            @field(row_struct, field.name) = null;
                        } else {
                            try toInt(col, i, &row_struct, field.name);
                        }
                    },
                    DataType.Float => {
                        try toFloat(col, i, &row_struct, field.name);
                    },
                    ?DataType.Float => {
                        if (col.dataType(i) == .Null) {
                            @field(row_struct, field.name) = null;
                        } else {
                            try toFloat(col, i, &row_struct, field.name);
                        }
                    },
                    DataType.Slice => {
                        try toSlice(col, i, &row_struct, field.name);
                    },
                    ?DataType.Slice => {
                        if (col.dataType(i) == .Null) {
                            @field(row_struct, field.name) = null;
                        } else {
                            try toSlice(col, i, &row_struct, field.name);
                        }
                    },
                    else => {
                        // Handles (Any) Type Casting
                        if (@typeInfo(field.type) == .@"enum") {
                            try toEnum(heap, field.type, col, i, &row_struct, field.name);
                        } else if (@typeInfo(field.type) == .@"struct") {
                            try toStruct(heap, field.type, col, i, &row_struct, field.name);
                        } else if (@typeInfo(field.type) == .optional) {
                            try toOptAny(heap, field.type, col, i, &row_struct, field.name);
                        } else {
                            @compileError(
                                "Field type must be one of `quill.DataType`"
                            );
                        }
                    }
                }
            }
        }
    }

    return row_struct;
}

fn toBool(col: *Column, i: i32, row: anytype, comptime tag: []const u8) !void {
    if (col.dataType(i) == .Int) {
        if (col.bytes(i) != 1) return Error.MismatchedSize;

        switch (col.int(i)) {
            0 => @field(row, tag) = false,
            1 => @field(row, tag) = true,
            else => return Error.MismatchedValue
        }
    } else {
        return Error.MismatchedType;
    }
}

fn toFloat(col: *Column, i: i32, row: anytype, comptime tag: []const u8) !void {
    if (col.dataType(i) == .Float) @field(row, tag) = col.double(i)
    else return Error.MismatchedType;
}

fn toInt(col: *Column, i: i32, row: anytype, comptime tag: []const u8) !void {
    if (col.dataType(i) == .Int) {
        if (col.bytes(i) <= 4) @field(row, tag) = col.int(i)
        else @field(row, tag) = col.int64(i);
    } else {
        return Error.MismatchedType;
    }
}

fn toSlice(col: *Column, i: i32, row: anytype, comptime tag: []const u8) !void {
    if (col.dataType(i) == .Text) {
        if (try col.text(i)) |data| @field(row, tag) = data
        else return Error.UnexpectedNullValue;
    } else if (col.dataType(i) == .Blob) {
        if (try col.blob(i)) |data| @field(row, tag) = data
        else return Error.UnexpectedNullValue;
    } else {
        return Error.MismatchedType;
    }
}

fn toEnum(
    heap: Allocator,
    comptime T: type,
    col: *Column,
    i: i32,
    row: anytype,
    comptime tag: []const u8
) !void {
    if (col.dataType(i) == .Int) {
        const size = @sizeOf(@typeInfo(T).@"enum".tag_type);
        if (size > col.bytes(i)) return Error.MismatchedSize;
        @field(row, tag) = @enumFromInt(col.int(i));
    } else if (col.dataType(i) == .Text) {
        const variant = if (try col.text(i)) |data| data
        else return Error.UnexpectedNullValue;

        defer heap.free(variant);
        errdefer heap.free(variant);

        inline for (@typeInfo(T).@"enum".fields) |field| {
            if (mem.eql(u8, field.name, variant)) {
                @field(row, tag) = @field(T, field.name);
                return;
            }
        }
    } else {
        return Error.MismatchedType;
    }
}

fn toStruct(
    heap: Allocator,
    comptime T: type,
    col: *Column,
    i: i32,
    row: anytype,
    comptime tag: []const u8)
!void {
    if (col.dataType(i) == .Text) {
        const json_str = if (try col.text(i)) |data| data
        else return Error.UnexpectedNullValue;

        defer heap.free(json_str);
        errdefer heap.free(json_str);

        @field(row, tag) = try Json.parse(T, heap, json_str);
    } else {
        return Error.MismatchedType;
    }
}

fn toOptAny(
    heap: Allocator,
    comptime T: type,
    col: *Column,
    i: i32,
    row: anytype,
    comptime tag: []const u8
) !void {
    const u_type = @typeInfo(T).optional;
    if (@typeInfo(u_type.child) == .@"enum") {
        if (col.dataType(i) == .Null) @field(row, tag) = null
        else try toEnum(heap, u_type.child, col, i, row, tag);
    } else if (@typeInfo(u_type.child) == .@"struct") {
        if (col.dataType(i) == .Null) @field(row, tag) = null
        else try toStruct(heap, u_type.child, col, i, row, tag);
    } else {
        return Error.MismatchedType;
    }
}
