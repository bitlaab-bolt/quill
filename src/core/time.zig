//! # Database Date Time Module

const std = @import("std");
const time = std.time;


/// # Returns Present Time (`Epoch`) in Milliseconds
pub fn timestamp() i64 { return time.timestamp(); }
