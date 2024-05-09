//! Parser for transfer-encoding: chunked.

state: State,
chunk_len: u64,

pub const init: ChunkParser = .{
    .state = .head_size,
    .chunk_len = 0,
};

pub const State = enum {
    head_size,
    head_ext,
    head_r,
    data,
    data_suffix,
    data_suffix_r,
    invalid,
};

/// Returns the number of bytes consumed by the chunk size. This is always
/// less than or equal to `bytes.len`.
///
/// After this function returns, `chunk_len` will contain the parsed chunk size
/// in bytes when `state` is `data`. Alternately, `state` may become `invalid`,
/// indicating a syntax error in the input stream.
///
/// If the amount returned is less than `bytes.len`, the parser is in the
/// `chunk_data` state and the first byte of the chunk is at `bytes[result]`.
///
/// Asserts `state` is neither `data` nor `invalid`.
pub fn feed(p: *ChunkParser, bytes: []const u8) usize {
    for (bytes, 0..) |c, i| switch (p.state) {
        .data_suffix => switch (c) {
            '\r' => p.state = .data_suffix_r,
            '\n' => p.state = .head_size,
            else => {
                p.state = .invalid;
                return i;
            },
        },
        .data_suffix_r => switch (c) {
            '\n' => p.state = .head_size,
            else => {
                p.state = .invalid;
                return i;
            },
        },
        .head_size => {
            const digit = switch (c) {
                '0'...'9' => |b| b - '0',
                'A'...'Z' => |b| b - 'A' + 10,
                'a'...'z' => |b| b - 'a' + 10,
                '\r' => {
                    p.state = .head_r;
                    continue;
                },
                '\n' => {
                    p.state = .data;
                    return i + 1;
                },
                else => {
                    p.state = .head_ext;
                    continue;
                },
            };

            const new_len = p.chunk_len *% 16 +% digit;
            if (new_len <= p.chunk_len and p.chunk_len != 0) {
                p.state = .invalid;
                return i;
            }

            p.chunk_len = new_len;
        },
        .head_ext => switch (c) {
            '\r' => p.state = .head_r,
            '\n' => {
                p.state = .data;
                return i + 1;
            },
            else => continue,
        },
        .head_r => switch (c) {
            '\n' => {
                p.state = .data;
                return i + 1;
            },
            else => {
                p.state = .invalid;
                return i;
            },
        },
        .data => unreachable,
        .invalid => unreachable,
    };
    return bytes.len;
}

const ChunkParser = @This();
const std = @import("std");

test feed {
    const testing = std.testing;

    const data = "Ff\r\nf0f000 ; ext\n0\r\nffffffffffffffffffffffffffffffffffffffff\r\n";

    var p = init;
    const first = p.feed(data[0..]);
    try testing.expectEqual(@as(u32, 4), first);
    try testing.expectEqual(@as(u64, 0xff), p.chunk_len);
    try testing.expectEqual(.data, p.state);

    p = init;
    const second = p.feed(data[first..]);
    try testing.expectEqual(@as(u32, 13), second);
    try testing.expectEqual(@as(u64, 0xf0f000), p.chunk_len);
    try testing.expectEqual(.data, p.state);

    p = init;
    const third = p.feed(data[first + second ..]);
    try testing.expectEqual(@as(u32, 3), third);
    try testing.expectEqual(@as(u64, 0), p.chunk_len);
    try testing.expectEqual(.data, p.state);

    p = init;
    const fourth = p.feed(data[first + second + third ..]);
    try testing.expectEqual(@as(u32, 16), fourth);
    try testing.expectEqual(@as(u64, 0xffffffffffffffff), p.chunk_len);
    try testing.expectEqual(.invalid, p.state);
}
