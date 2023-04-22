const std = @import("std");
const builtin = @import("builtin");

const Holder = struct {
    array: []const u8,
};

const Test = struct {
    holders: []const Holder,
};

const Letter = enum(u8) {
    A = 0x41,
    B,
};

fn letter(e: Letter) u8 {
    return @enumToInt(e);
}

test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    const test_struct = Test{
        .holders = &.{
            Holder{
                .array = &.{
                    letter(.A),
                },
            },
        },
    };
    try std.testing.expectEqualStrings("A", test_struct.holders[0].array);
}
