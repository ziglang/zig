// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const assert = std.debug.assert;

pub const ParseError = error{
    OutOfMemory,
    InvalidStringLiteral,
};

pub const Result = union(enum) {
    success,
    /// Found an invalid character at this index.
    invalid_character: usize,
    /// Expected hex digits at this index.
    expected_hex_digits: usize,
    /// Invalid hex digits at this index.
    invalid_hex_escape: usize,
    /// Invalid unicode escape at this index.
    invalid_unicode_escape: usize,
    /// The left brace at this index is missing a matching right brace.
    missing_matching_rbrace: usize,
    /// Expected unicode digits at this index.
    expected_unicode_digits: usize,
};

/// Parses `bytes` as a Zig string literal and appends the result to `buf`.
/// Asserts `bytes` has '"' at beginning and end.
pub fn parseAppend(buf: *std.ArrayList(u8), bytes: []const u8) error{OutOfMemory}!Result {
    assert(bytes.len >= 2 and bytes[0] == '"' and bytes[bytes.len - 1] == '"');
    const slice = bytes[1..];

    const prev_len = buf.items.len;
    try buf.ensureCapacity(prev_len + slice.len - 1);
    errdefer buf.shrinkRetainingCapacity(prev_len);

    const State = enum {
        Start,
        Backslash,
    };

    var state = State.Start;
    var index: usize = 0;
    while (true) : (index += 1) {
        const b = slice[index];

        switch (state) {
            State.Start => switch (b) {
                '\\' => state = State.Backslash,
                '\n' => {
                    return Result{ .invalid_character = index };
                },
                '"' => return Result.success,
                else => try buf.append(b),
            },
            State.Backslash => switch (b) {
                'n' => {
                    try buf.append('\n');
                    state = State.Start;
                },
                'r' => {
                    try buf.append('\r');
                    state = State.Start;
                },
                '\\' => {
                    try buf.append('\\');
                    state = State.Start;
                },
                't' => {
                    try buf.append('\t');
                    state = State.Start;
                },
                '\'' => {
                    try buf.append('\'');
                    state = State.Start;
                },
                '"' => {
                    try buf.append('"');
                    state = State.Start;
                },
                'x' => {
                    // TODO: add more/better/broader tests for this.
                    const index_continue = index + 3;
                    if (slice.len < index_continue) {
                        return Result{ .expected_hex_digits = index };
                    }
                    if (std.fmt.parseUnsigned(u8, slice[index + 1 .. index_continue], 16)) |byte| {
                        try buf.append(byte);
                        state = State.Start;
                        index = index_continue - 1; // loop-header increments again
                    } else |err| switch (err) {
                        error.Overflow => unreachable, // 2 digits base 16 fits in a u8.
                        error.InvalidCharacter => {
                            return Result{ .invalid_hex_escape = index + 1 };
                        },
                    }
                },
                'u' => {
                    // TODO: add more/better/broader tests for this.
                    // TODO: we are already inside a nice, clean state machine... use it
                    // instead of this hacky code.
                    if (slice.len > index + 2 and slice[index + 1] == '{') {
                        if (std.mem.indexOfScalarPos(u8, slice[0..std.math.min(index + 9, slice.len)], index + 3, '}')) |index_end| {
                            const hex_str = slice[index + 2 .. index_end];
                            if (std.fmt.parseUnsigned(u32, hex_str, 16)) |uint| {
                                if (uint <= 0x10ffff) {
                                    try buf.appendSlice(std.mem.toBytes(uint)[0..]);
                                    state = State.Start;
                                    index = index_end; // loop-header increments
                                    continue;
                                }
                            } else |err| switch (err) {
                                error.Overflow => unreachable,
                                error.InvalidCharacter => {
                                    return Result{ .invalid_unicode_escape = index + 1 };
                                },
                            }
                        } else {
                            return Result{ .missing_matching_rbrace = index + 1 };
                        }
                    } else {
                        return Result{ .expected_unicode_digits = index };
                    }
                },
                else => {
                    return Result{ .invalid_character = index };
                },
            },
        }
    } else unreachable; // TODO should not need else unreachable on while(true)
}

/// Higher level API. Does not return extra info about parse errors.
/// Caller owns returned memory.
pub fn parseAlloc(allocator: *std.mem.Allocator, bytes: []const u8) ParseError![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    switch (try parseAppend(&buf, bytes)) {
        .success => return buf.toOwnedSlice(),
        else => return error.InvalidStringLiteral,
    }
}

test "parse" {
    const expect = std.testing.expect;
    const eql = std.mem.eql;

    var fixed_buf_mem: [32]u8 = undefined;
    var fixed_buf_alloc = std.heap.FixedBufferAllocator.init(fixed_buf_mem[0..]);
    var alloc = &fixed_buf_alloc.allocator;

    expect(eql(u8, "foo", try parseAlloc(alloc, "\"foo\"")));
    expect(eql(u8, "foo", try parseAlloc(alloc, "\"f\x6f\x6f\"")));
    expect(eql(u8, "f💯", try parseAlloc(alloc, "\"f\u{1f4af}\"")));
}
