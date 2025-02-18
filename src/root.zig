//! # SQlite Library Binding
//! - See documentation at - https://bitlaabquill.web.app/

pub const Uuid = @import("./core/uuid.zig");
pub const Quill = @import("./core/quill.zig");
pub const DateTime = @import("./core/time.zig");
pub const Builtins = @import("./core/builtins.zig");
pub const QueryBuilder = @import("./core/builder.zig");
pub const Types = @import("./core/types.zig").DataType;

/// # API Bindings for Underlying Libraries
pub const Api = struct {
    pub const sqlite3 = @import("./binding/sqlite3.zig");
};