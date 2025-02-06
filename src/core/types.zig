//! # Type Declaration and Conversion Module

const std = @import("std");
const mem = std.mem;
const debug = std.debug;

const uuid = @import("./uuid.zig");

const sqlite3 = @import("../binding/sqlite3.zig");
const Bind = sqlite3.Bind;
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
    pub const UUID = [16]u8;
    pub const Bool = bool;
    pub const Float = f64;
    pub const Integer = i64;
    pub const Slice = []const u8;

    // Only use this type for data binding
    pub const Text = struct { data: []const u8 };
    pub const Blob = struct { data: []const u8 };
};

/// # Converts Columns Data from the Given Record Structure
/// **Remarks:** Intended for internal use only
pub fn convertFrom(bind: *Bind, record: anytype) !void {
    const struct_info = @typeInfo(@TypeOf(record)).@"struct";
    debug.assert(bind.parameterCount() == struct_info.fields.len);

    inline for (struct_info.fields) |field| {
        const pos = try bind.parameterIndex(":" ++ field.name);
        switch (field.type) {
            DataType.UUID => {
                try bind.blob(pos, &@field(record, field.name));
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
            DataType.Integer => {
                try bind.int64(pos, @field(record, field.name));
            },
            ?DataType.Integer => {
                if (@field(record, field.name) == null) try bind.none(pos)
                else try bind.int64(pos, @field(record, field.name));
            },
            DataType.Text => {
                try fromText(bind, pos, record, field.name);
            },
            ?DataType.Text => {
                if (@field(record, field.name) == null) try bind.none(pos)
                else try fromText(bind, pos, record, field.name);
            },
            DataType.Blob => {
                try fromBlob(bind, pos, record, field.name);
            },
            ?DataType.Blob => {
                if (@field(record, field.name) == null) try bind.none(pos)
                else try fromBlob(bind, pos, record, field.name);
            },
            else => {
                // Since enum is an user defined type
                if (@typeInfo(field.type) == .@"enum") {
                    const val = @intFromEnum(@field(record, field.name));
                    try bind.int(pos, val);
                } else if (@typeInfo(field.type) == .optional) {
                    if (@field(record, field.name) == null) try bind.none(pos)
                    else {
                        const val = @intFromEnum(@field(record, field.name).?);
                        try bind.int(pos, val);
                    }
                } else {
                    @compileError(
                        "Field types must be one of - quill.DataType"
                    );
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

fn fromText(bind: *Bind, i: i32, rec: anytype, comptime tag: []const u8) !void {
    const slice_struct = @field(rec, tag);
    try bind.text(i, @field(slice_struct, "data"));
}

fn fromBlob(bind: *Bind, i: i32, rec: anytype, comptime tag: []const u8) !void {
    const slice_struct = @field(rec, tag);
    try bind.blob(i, @field(slice_struct, "data"));
}

/// # Converts Columns Data into the Given Record Structure
/// **Remarks:** Intended for internal use only
pub fn convertTo(col: *Column, comptime T: type) !T {
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
