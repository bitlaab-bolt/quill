//! # Type Declaration and Conversion Module

const std = @import("std");
const mem = std.mem;

const sqlite3 = @import("../binding/sqlite3.zig");
const Column = sqlite3.Column;


const Error = error {
    MismatchedType,
    MismatchedSize,
    MismatchedValue,
    UnexpectedNullValue,
};

/// # Supported Record's Field Data Types
/// - You must use following types for data binding and retrieval
/// - You can also use `enum` type and / or optional `enum` type as well
pub const DataType = struct {
    pub const Bool = bool;
    pub const Float = f64;
    pub const Integer = i64;
    pub const Slice = []const u8;
};

/// # Converts Columns Data into the Given Row Structure
pub fn convert(col: *Column, comptime T: type) !T {
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
                    DataType.Integer => {
                        try toInt(col, i, &row_struct, field.name);
                    },
                    ?DataType.Integer => {
                        if (col.dataType(i) == .Null) {
                            @field(row_struct, field.name) = null;
                        } else {
                            try toInt(col, i, &row_struct, field.name);
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
                        // Since enum is an user defined type
                        if (@typeInfo(field.type) == .@"enum") {
                            try toEnum(
                                field.type, col, i, &row_struct, field.name
                            );
                        } else if (@typeInfo(field.type) == .optional) {
                            try toOptEnum(
                                field.type, col, i, &row_struct, field.name
                            );
                        } else {
                            @compileError(
                                "Field types must be one of - quill.DataType"
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
    } else {
        return Error.MismatchedType;
    }
}

fn toOptEnum(
    comptime T: type,
    col: *Column,
    i: i32,
    row: anytype,
    comptime tag: []const u8
) !void {
    const u_type = @typeInfo(T).optional;
    if (@typeInfo(u_type.child) != .@"enum") return Error.MismatchedType;

    if (col.dataType(i) == .Null) @field(row, tag) = null
    else try toEnum(u_type.child, col, i, row, tag);
}
