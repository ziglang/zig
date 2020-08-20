// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const assert = std.debug.assert;

const State = enum {
    Start,
    Backslash,
};

pub const ParseError = error{
    OutOfMemory,

    /// When this is returned, index will be the position of the character.
    InvalidCharacter,
};

/// caller owns returned memory
pub fn parse(
    allocator: *std.mem.Allocator,
    bytes: []const u8,
    bad_index: *usize, // populated if error.InvalidCharacter is returned
) ParseError![]u8 {
    assert(bytes.len >= 2 and bytes[0] == '"' and bytes[bytes.len - 1] == '"');

    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();

    const slice = bytes[1..];
    try list.ensureCapacity(slice.len - 1);

    var state = State.Start;
    var index: usize = 0;
    while (index < slice.len) : (index += 1) {
        const b = slice[index];

        switch (state) {
            State.Start => switch (b) {
                '\\' => state = State.Backslash,
                '\n' => {
                    bad_index.* = index;
                    return error.InvalidCharacter;
                },
                '"' => return list.toOwnedSlice(),
                else => try list.append(b),
            },
            State.Backslash => switch (b) {
                'n' => {
                    try list.append('\n');
                    state = State.Start;
                },
                'r' => {
                    try list.append('\r');
                    state = State.Start;
                },
                '\\' => {
                    try list.append('\\');
                    state = State.Start;
                },
                't' => {
                    try list.append('\t');
                    state = State.Start;
                },
                '\'' => {
                    try list.append('\'');
                    state = State.Start;
                },
                '"' => {
                    try list.append('"');
                    state = State.Start;
                },
                'x' => {
                    // TODO: add more/better/broader tests for this.
                    const index_continue = index + 3;
                    if (slice.len >= index_continue)
                        if (std.fmt.parseUnsigned(u8, slice[index + 1 .. index_continue], 16)) |char| {
                            try list.append(char);
                            state = State.Start;
                            index = index_continue - 1; // loop-header increments again
                            continue;
                        } else |_| {};

                    bad_index.* = index;
                    return error.InvalidCharacter;
                },
                'u' => {
                    // TODO: add more/better/broader tests for this.
                    if (slice.len > index + 2 and slice[index + 1] == '{')
                        if (std.mem.indexOfScalarPos(u8, slice[0..std.math.min(index + 9, slice.len)], index + 3, '}')) |index_end| {
                            const hex_str = slice[index + 2 .. index_end];
                            if (std.fmt.parseUnsigned(u32, hex_str, 16)) |uint| {
                                if (uint <= 0x10ffff) {
                                    try list.appendSlice(std.mem.toBytes(uint)[0..]);
                                    state = State.Start;
                                    index = index_end; // loop-header increments
                                    continue;
                                }
                            } else |_| {}
                        };

                    bad_index.* = index;
                    return error.InvalidCharacter;
                },
                else => {
                    bad_index.* = index;
                    return error.InvalidCharacter;
                },
            },
        }
    }
    unreachable;
}

test "parse" {
    const expect = std.testing.expect;
    const eql = std.mem.eql;

    var fixed_buf_mem: [32]u8 = undefined;
    var fixed_buf_alloc = std.heap.FixedBufferAllocator.init(fixed_buf_mem[0..]);
    var alloc = &fixed_buf_alloc.allocator;
    var bad_index: usize = undefined;

    expect(eql(u8, "foo", try parse(alloc, "\"foo\"", &bad_index)));
    expect(eql(u8, "foo", try parse(alloc, "\"f\x6f\x6f\"", &bad_index)));
    expect(eql(u8, "f💯", try parse(alloc, "\"f\u{1f4af}\"", &bad_index)));
}

/// Writes a Zig-syntax escaped string literal to the stream. Includes the double quotes.
pub fn render(utf8: []const u8, out_stream: anytype) !void {
    try out_stream.writeByte('"');
    for (utf8) |byte| switch (byte) {
        '\n' => try out_stream.writeAll("\\n"),
        '\r' => try out_stream.writeAll("\\r"),
        '\t' => try out_stream.writeAll("\\t"),
        '\\' => try out_stream.writeAll("\\\\"),
        '"' => try out_stream.writeAll("\\\""),
        ' ', '!', '#'...'[', ']'...'~' => try out_stream.writeByte(byte),
        else => try out_stream.print("\\x{x:0>2}", .{byte}),
    };
    try out_stream.writeByte('"');
}

test "render" {
    const expect = std.testing.expect;
    const eql = std.mem.eql;

    var fixed_buf_mem: [32]u8 = undefined;

    {
        var fbs = std.io.fixedBufferStream(&fixed_buf_mem);
        try render(" \\ hi \x07 \x11 \" derp", fbs.outStream());
        expect(eql(u8,
            \\" \\ hi \x07 \x11 \" derp"
        , fbs.getWritten()));
    }
}
