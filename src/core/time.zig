//! # Database Date Time Module

const std = @import("std");
const Io  = std.Io;

/// # Returns Present Time (`Epoch`) in Seconds
pub fn timestamp(io: Io) i64 {
    return Io.Clock.now(.real, io).toSeconds();
}

/// # Returns Present Time (`Epoch`) in Milliseconds
pub fn msTimestamp(io: Io) i64 {
    return Io.Clock.now(.real, io).toMilliseconds();
}
