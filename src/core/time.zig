//! # Database Date Time Module

const std = @import("std");
const time = std.time;


/// # Returns Present Time (`Epoch`) in Seconds
pub fn timestamp() i64 { return time.timestamp(); }

/// # Returns Present Time (`Epoch`) in Milliseconds
pub fn msTimestamp() i64 { return time.milliTimestamp(); }
