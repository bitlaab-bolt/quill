//! # SQlite Library Binding
//! - See documentation at - https://bitlaabquill.web.app/

pub const Quill = @import("./core/quill.zig");
pub const Types = @import("./core/types.zig");
pub const Uuid = @import("./core/types.zig");


/// # API Bindings for Underlying Libraries
pub const Api = struct {
    pub const sqlite3 = @import("./binding/sqlite3.zig");
};