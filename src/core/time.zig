//! # Database Date Time Module

const std = @import("std");


/// # Returns Present Time (`Epoch`) in Seconds
pub fn timestamp() i64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    return std.Io.Clock.now(.real, io).toSeconds();
}

/// # Returns Present Time (`Epoch`) in Milliseconds
pub fn msTimestamp() i64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    return std.Io.Clock.now(.real, io).toMilliseconds();
}
