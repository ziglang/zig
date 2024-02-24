//! Finds the end of an HTTP head in a stream.

state: State = .start,

pub const State = enum {
    start,
    seen_n,
    seen_r,
    seen_rn,
    seen_rnr,
    finished,
};

/// Returns the number of bytes consumed by headers. This is always less
/// than or equal to `bytes.len`.
///
/// If the amount returned is less than `bytes.len`, the parser is in a
/// content state and the first byte of content is located at
/// `bytes[result]`.
pub fn feed(p: *HeadParser, bytes: []const u8) usize {
    const vector_len: comptime_int = @max(std.simd.suggestVectorLength(u8) orelse 1, 8);
    var index: usize = 0;

    while (true) {
        switch (p.state) {
            .finished => return index,
            .start => switch (bytes.len - index) {
                0 => return index,
                1 => {
                    switch (bytes[index]) {
                        '\r' => p.state = .seen_r,
                        '\n' => p.state = .seen_n,
                        else => {},
                    }

                    return index + 1;
                },
                2 => {
                    const b16 = int16(bytes[index..][0..2]);
                    const b8 = intShift(u8, b16);

                    switch (b8) {
                        '\r' => p.state = .seen_r,
                        '\n' => p.state = .seen_n,
                        else => {},
                    }

                    switch (b16) {
                        int16("\r\n") => p.state = .seen_rn,
                        int16("\n\n") => p.state = .finished,
                        else => {},
                    }

                    return index + 2;
                },
                3 => {
                    const b24 = int24(bytes[index..][0..3]);
                    const b16 = intShift(u16, b24);
                    const b8 = intShift(u8, b24);

                    switch (b8) {
                        '\r' => p.state = .seen_r,
                        '\n' => p.state = .seen_n,
                        else => {},
                    }

                    switch (b16) {
                        int16("\r\n") => p.state = .seen_rn,
                        int16("\n\n") => p.state = .finished,
                        else => {},
                    }

                    switch (b24) {
                        int24("\r\n\r") => p.state = .seen_rnr,
                        else => {},
                    }

                    return index + 3;
                },
                4...vector_len - 1 => {
                    const b32 = int32(bytes[index..][0..4]);
                    const b24 = intShift(u24, b32);
                    const b16 = intShift(u16, b32);
                    const b8 = intShift(u8, b32);

                    switch (b8) {
                        '\r' => p.state = .seen_r,
                        '\n' => p.state = .seen_n,
                        else => {},
                    }

                    switch (b16) {
                        int16("\r\n") => p.state = .seen_rn,
                        int16("\n\n") => p.state = .finished,
                        else => {},
                    }

                    switch (b24) {
                        int24("\r\n\r") => p.state = .seen_rnr,
                        else => {},
                    }

                    switch (b32) {
                        int32("\r\n\r\n") => p.state = .finished,
                        else => {},
                    }

                    index += 4;
                    continue;
                },
                else => {
                    const chunk = bytes[index..][0..vector_len];
                    const matches = if (use_vectors) matches: {
                        const Vector = @Vector(vector_len, u8);
                        // const BoolVector = @Vector(vector_len, bool);
                        const BitVector = @Vector(vector_len, u1);
                        const SizeVector = @Vector(vector_len, u8);

                        const v: Vector = chunk.*;
                        const matches_r: BitVector = @bitCast(v == @as(Vector, @splat('\r')));
                        const matches_n: BitVector = @bitCast(v == @as(Vector, @splat('\n')));
                        const matches_or: SizeVector = matches_r | matches_n;

                        break :matches @reduce(.Add, matches_or);
                    } else matches: {
                        var matches: u8 = 0;
                        for (chunk) |byte| switch (byte) {
                            '\r', '\n' => matches += 1,
                            else => {},
                        };
                        break :matches matches;
                    };
                    switch (matches) {
                        0 => {},
                        1 => switch (chunk[vector_len - 1]) {
                            '\r' => p.state = .seen_r,
                            '\n' => p.state = .seen_n,
                            else => {},
                        },
                        2 => {
                            const b16 = int16(chunk[vector_len - 2 ..][0..2]);
                            const b8 = intShift(u8, b16);

                            switch (b8) {
                                '\r' => p.state = .seen_r,
                                '\n' => p.state = .seen_n,
                                else => {},
                            }

                            switch (b16) {
                                int16("\r\n") => p.state = .seen_rn,
                                int16("\n\n") => p.state = .finished,
                                else => {},
                            }
                        },
                        3 => {
                            const b24 = int24(chunk[vector_len - 3 ..][0..3]);
                            const b16 = intShift(u16, b24);
                            const b8 = intShift(u8, b24);

                            switch (b8) {
                                '\r' => p.state = .seen_r,
                                '\n' => p.state = .seen_n,
                                else => {},
                            }

                            switch (b16) {
                                int16("\r\n") => p.state = .seen_rn,
                                int16("\n\n") => p.state = .finished,
                                else => {},
                            }

                            switch (b24) {
                                int24("\r\n\r") => p.state = .seen_rnr,
                                else => {},
                            }
                        },
                        4...vector_len => {
                            inline for (0..vector_len - 3) |i_usize| {
                                const i = @as(u32, @truncate(i_usize));

                                const b32 = int32(chunk[i..][0..4]);
                                const b16 = intShift(u16, b32);

                                if (b32 == int32("\r\n\r\n")) {
                                    p.state = .finished;
                                    return index + i + 4;
                                } else if (b16 == int16("\n\n")) {
                                    p.state = .finished;
                                    return index + i + 2;
                                }
                            }

                            const b24 = int24(chunk[vector_len - 3 ..][0..3]);
                            const b16 = intShift(u16, b24);
                            const b8 = intShift(u8, b24);

                            switch (b8) {
                                '\r' => p.state = .seen_r,
                                '\n' => p.state = .seen_n,
                                else => {},
                            }

                            switch (b16) {
                                int16("\r\n") => p.state = .seen_rn,
                                int16("\n\n") => p.state = .finished,
                                else => {},
                            }

                            switch (b24) {
                                int24("\r\n\r") => p.state = .seen_rnr,
                                else => {},
                            }
                        },
                        else => unreachable,
                    }

                    index += vector_len;
                    continue;
                },
            },
            .seen_n => switch (bytes.len - index) {
                0 => return index,
                else => {
                    switch (bytes[index]) {
                        '\n' => p.state = .finished,
                        else => p.state = .start,
                    }

                    index += 1;
                    continue;
                },
            },
            .seen_r => switch (bytes.len - index) {
                0 => return index,
                1 => {
                    switch (bytes[index]) {
                        '\n' => p.state = .seen_rn,
                        '\r' => p.state = .seen_r,
                        else => p.state = .start,
                    }

                    return index + 1;
                },
                2 => {
                    const b16 = int16(bytes[index..][0..2]);
                    const b8 = intShift(u8, b16);

                    switch (b8) {
                        '\r' => p.state = .seen_r,
                        '\n' => p.state = .seen_rn,
                        else => p.state = .start,
                    }

                    switch (b16) {
                        int16("\r\n") => p.state = .seen_rn,
                        int16("\n\r") => p.state = .seen_rnr,
                        int16("\n\n") => p.state = .finished,
                        else => {},
                    }

                    return index + 2;
                },
                else => {
                    const b24 = int24(bytes[index..][0..3]);
                    const b16 = intShift(u16, b24);
                    const b8 = intShift(u8, b24);

                    switch (b8) {
                        '\r' => p.state = .seen_r,
                        '\n' => p.state = .seen_n,
                        else => p.state = .start,
                    }

                    switch (b16) {
                        int16("\r\n") => p.state = .seen_rn,
                        int16("\n\n") => p.state = .finished,
                        else => {},
                    }

                    switch (b24) {
                        int24("\n\r\n") => p.state = .finished,
                        else => {},
                    }

                    index += 3;
                    continue;
                },
            },
            .seen_rn => switch (bytes.len - index) {
                0 => return index,
                1 => {
                    switch (bytes[index]) {
                        '\r' => p.state = .seen_rnr,
                        '\n' => p.state = .seen_n,
                        else => p.state = .start,
                    }

                    return index + 1;
                },
                else => {
                    const b16 = int16(bytes[index..][0..2]);
                    const b8 = intShift(u8, b16);

                    switch (b8) {
                        '\r' => p.state = .seen_rnr,
                        '\n' => p.state = .seen_n,
                        else => p.state = .start,
                    }

                    switch (b16) {
                        int16("\r\n") => p.state = .finished,
                        int16("\n\n") => p.state = .finished,
                        else => {},
                    }

                    index += 2;
                    continue;
                },
            },
            .seen_rnr => switch (bytes.len - index) {
                0 => return index,
                else => {
                    switch (bytes[index]) {
                        '\n' => p.state = .finished,
                        else => p.state = .start,
                    }

                    index += 1;
                    continue;
                },
            },
        }

        return index;
    }
}

inline fn int16(array: *const [2]u8) u16 {
    return @bitCast(array.*);
}

inline fn int24(array: *const [3]u8) u24 {
    return @bitCast(array.*);
}

inline fn int32(array: *const [4]u8) u32 {
    return @bitCast(array.*);
}

inline fn intShift(comptime T: type, x: anytype) T {
    switch (@import("builtin").cpu.arch.endian()) {
        .little => return @truncate(x >> (@bitSizeOf(@TypeOf(x)) - @bitSizeOf(T))),
        .big => return @truncate(x),
    }
}

const HeadParser = @This();
const std = @import("std");
const use_vectors = builtin.zig_backend != .stage2_x86_64;
const builtin = @import("builtin");

test feed {
    const data = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\nHello";

    for (0..36) |i| {
        var p: HeadParser = .{};
        try std.testing.expectEqual(i, p.feed(data[0..i]));
        try std.testing.expectEqual(35 - i, p.feed(data[i..]));
    }
}
