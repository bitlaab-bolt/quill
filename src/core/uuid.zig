//! # UUID Version 7
//! **REMARKS:** UUID v7 is great for databases (ScyllaDB, SQLite, etc.),
//! it is optimized for performance, scalability, and ordering in databases,
//! making it superior to **UUID v4** and other versions for primary keys.
//!
//! - Compatible with Standard UUID Formats
//! - Ensuring uniqueness across multiple nodes
//! - Time-Ordered (Better Indexing & Query Performance)

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const time = std.time;
const crypto = std.crypto;
const testing = std.testing;


const Error = error { InvalidLength, MalformedUrnString, InvalidHexCharacter };

/// # Universally Unique IDentifier
/// - A UUID is 128 bits long, and unique across space and time (RFC4122)
const UUID = [16]u8;

/// # Uniform Resource Name
/// - Provides a standardized way to represent a UUID
/// - e.g., `urn:uuid:550e8400-e29b-41d4-a716-446655440000`
const URN = [36]u8;

//  0                   1                   2                   3
//  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// |                           unix_ts_ms                          |
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// |          unix_ts_ms           |  ver  |       rand_a          |
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// |var|                        rand_b                             |
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// |                            rand_b                             |
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// |0190163d-8694-739b-aea5-966c26f8ad91 |
// +└─timestamp─┘ │└─┤ │└───rand_b─────┘ +
// |             ver │var                |
// +              rand_a                 +
// |+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+|

/// # Creates a New UUID-v7
pub fn new() UUID {
    var uuid: UUID = undefined;

    // Fills the tailing 10 bytes
    crypto.random.bytes(uuid[6..]);

    // Gets timestamp in milliseconds since Epoch
    const timestamp: u48 = @intCast(time.milliTimestamp());

    // Ensures timestamp in Big-Endian format
    mem.writeInt(u48, uuid[0..6], timestamp, .big);

    // Sets the version and variant
    uuid[6] = (uuid[6] & 0x0F) | 0x70;
    uuid[8] = (uuid[8] & 0x3F) | 0x80;

    return uuid;
}

/// # Returns a String Representation of the Given UUID
/// - e.g., - `0194E5A9-DDDF-7D69-AE47-52193D232919`
pub fn toUrn(uuid: []const u8) Error!URN {
    if (uuid.len != 16) return Error.InvalidLength;

    var urn: URN = undefined;
    _ = fmt.bufPrint(&urn, "{X:0>2}{X:0>2}{X:0>2}{X:0>2}-{X:0>2}{X:0>2}-{X:0>2}{X:0>2}-{X:0>2}{X:0>2}-{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}",
    .{
        uuid[0], uuid[1], uuid[2], uuid[3],
        uuid[4], uuid[5], uuid[6], uuid[7],
        uuid[8], uuid[9], uuid[10], uuid[11],
        uuid[12], uuid[13], uuid[14], uuid[15]
    }) catch unreachable;

    return urn;
}

/// Generates UUID from the given URN
pub fn fromUrn(str: []const u8) Error!UUID {
    if (str.len != 36 or str[8] != '-' or str[13] != '-'
        or str[18] != '-' or str[23] != '-'
    ) return Error.MalformedUrnString;

    var uuid: UUID = undefined;
    var i: usize = 0;
    var j: usize = 0;

    while (i < str.len) {
        if (str[i] == '-') { i += 1; continue; }
        uuid[j] = (try hexToByte(str[i]) << 4) | try hexToByte(str[i + 1]);
        i += 2;
        j += 1;
    }

    return uuid;
}

fn hexToByte(char: u8) Error!u8 {
    return switch (char) {
        '0'...'9' => char - '0',
        'a'...'f' => char - 'a' + 10,
        'A'...'F' => char - 'A' + 10,
        else => Error.InvalidHexCharacter,
    };
}

test "uuid to urn" {
    const uuid: UUID = [_]u8{1, 148, 230, 23, 37, 15, 113, 145, 154, 165, 150, 179, 245, 6, 194, 11};

    const urn = try toUrn(&uuid);
    try testing.expectEqualSlices(
        u8, "0194E617-250F-7191-9AA5-96B3F506C20B", urn[0..]
    );
}

test "urn to uuid" {
    const urn = "0194E617-250F-7191-9AA5-96B3F506C20B";
    const uuid = try fromUrn(urn);
    try testing.expectEqual(
        uuid, [_]u8{1, 148, 230, 23, 37, 15, 113, 145, 154, 165, 150, 179, 245, 6, 194, 11}
    );
}

test "urn full circle" {
    const urn = "0194E617-250F-7191-9AA5-96B3F506C20B";
    const uuid = try fromUrn(urn);
    const urn_delta = try toUrn(&uuid);

    try std.testing.expectEqualStrings(urn, &urn_delta);
}
