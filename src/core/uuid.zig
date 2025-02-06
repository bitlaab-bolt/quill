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
const rand = std.Random;
const crypto = std.crypto;
const testing = std.testing;


const Error = error { MalformedUrnString, InvalidHexCharacter };

/// # Universally Unique IDentifier
/// - A UUID is 128 bits long, and unique across space and time (RFC4122)
const UUID = u128;

/// # Uniform Resource Name
/// - Provides a standardized way to represent a UUID
/// - e.g., `urn:uuid:550e8400-e29b-41d4-a716-446655440000`
const URN = [36]u8;

//   0                   1                   2                   3
//   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
//  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
//  |                           unix_ts_ms                          |
//  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
//  |          unix_ts_ms           |  var  |       rand_a          |
//  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
//  |var|                        rand_b                             |
//  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
//  |                            rand_b                             |
//  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

/// # Creates a New UUID-v7
pub fn new() UUID {
    // Gets milliseconds since 1 Jan 1970 UTC
    const mt = time.milliTimestamp();
    const t_stamp = @as(u48, @intCast(mt & 0xffffffffffff));

    // Fills everything after the timestamp with random bytes
    var uuid: UUID = @as(UUID, @intCast(rand.int(crypto.random, u80))) << 48;

    // Encodes `t_stamp` in big endian and OR'ed it to the uuid
    uuid |= @as(UUID, @intCast(switchU48(t_stamp)));

    // Sets variant and version field
    // * variant - top two bits are 1, 0
    // * version - top four bits are 0, 1, 1, 1
    uuid &= 0xffffffffffffff3fff0fffffffffffff;
    uuid |= 0x00000000000000800070000000000000;

    return uuid;
}

/// # Returns a String Representation of the Given UUID
/// - e.g., - `550e8400-e29b-41d4-a716-446655440000`
pub fn toUrn(uuid: UUID) URN {
    var urn: URN = undefined;
    const fmt_str = "{x:0>8}-{x:0>4}-{x:0>4}-{x:0>2}{x:0>2}-{x:0>12}";
    _ = fmt.bufPrint(&urn, fmt_str, .{
        getTimeLow(uuid),
        getTimeMid(uuid),
        getTimeHiAndVersion(uuid),
        getClockSeqHiAndReserved(uuid),
        getClockSeqLow(uuid),
        getNode(uuid),
    }) catch unreachable;

    return urn;
}

/// Generates UUID from the given URN
pub fn fromUrn(str: []const u8) Error!UUID {
    if (str.len != 36
        or mem.count(u8, str, "-") != 4
        or str[8] != '-'
        or str[13] != '-'
        or str[18] != '-'
        or str[23] != '-')
    {
        return Error.MalformedUrnString;
    }

    var uuid: UUID = 0;
    var i: usize = 0;
    var j: u7 = 0;

    while (i <= 34) {
        if (str[i] == '-') { i += 1; continue; }

        const digit: u8 = (try hex2hw(str[i]) << 4) | try hex2hw(str[i + 1]);
        uuid |= @as(UUID, @intCast(digit)) << (j * 8);
        i += 2;
        j += 1;
    }

    return uuid;
}

/// # Switch Between Little and Big Endian
fn switchU48(v: u48) u48 {
    return ((v >> 40) & 0x0000000000ff)
    | ((v >> 24) & 0x00000000ff00)
    | ((v >> 8) & 0x000000ff0000)
    | ((v << 8) & 0x0000ff000000)
    | ((v << 24) & 0x00ff00000000)
    | ((v << 40) & 0xff0000000000);
}

/// Switch Between Little and Big Endian
fn switchU32(v: u32) u32 {
    return ((v >> 24) & 0x000000ff)
    | ((v >> 8) & 0x0000ff00)
    | ((v << 8) & 0x00ff0000)
    | ((v << 24) & 0xff000000);
}

/// Switch Between Little and Big Endian
fn switchU16(v: u16) u16 {
    return ((v >> 8) & 0x00ff)
    | ((v << 8) & 0xff00);
}

fn hex2hw(hex: u8) Error!u8 {
    return switch (hex) {
        48...57 => hex - 48,       // '0' - '9'
        65...70 => hex - 65 + 10,  // 'A' - 'F'
        97...102 => hex - 97 + 10, // 'a' - 'f'
        else => return Error.InvalidHexCharacter
    };
}

fn getTimeLow(uuid: UUID) u32 {
    return switchU32(@as(u32, @intCast(uuid & 0xffffffff)));
}

fn getTimeMid(uuid: UUID) u16 {
    return switchU16(@as(u16, @intCast((uuid >> 32) & 0xffff)));
}

fn getTimeHiAndVersion(uuid: UUID) u16 {
    return switchU16(@as(u16, @intCast((uuid >> 48) & 0xffff)));
}

fn getClockSeqHiAndReserved(uuid: UUID) u8 {
    return @as(u8, @intCast((uuid >> 64) & 0xff));
}

fn getClockSeqLow(uuid: UUID) u8 {
    return @as(u8, @intCast((uuid >> 72) & 0xff));
}

fn getNode(uuid: UUID) u48 {
    return switchU48(@as(u48, @intCast((uuid >> 80) & 0xffffffffffff)));
}

test "uuid to urn" {
    const uuid: UUID = 0xffeeddccbbaa99887766554433221100;
    const urn = toUrn(uuid);
    try testing.expectEqualSlices(
        u8, "00112233-4455-6677-8899-aabbccddeeff", urn[0..]
    );
}

test "urn to uuid" {
    const urn = "6ba7b811-9dad-11d1-80b4-00c04fd430c8";
    const uuid = try fromUrn(urn);
    try testing.expectEqual(
        @as(UUID, @intCast(0xc830d44fc000b480d111ad9d11b8a76b)), uuid
    );
}

test "urn full circle" {
    const urn = "6ba7b811-9dad-11d1-80b4-00c04fd430c8";
    const uuid = try fromUrn(urn);
    const urn_delta = toUrn(uuid);

    try std.testing.expectEqualStrings(urn, &urn_delta);
}
