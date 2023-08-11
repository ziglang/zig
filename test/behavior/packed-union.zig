const std = @import("std");
const builtin = @import("builtin");
const expectEqual = std.testing.expectEqual;

test "flags in packed union" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const FlagBits = packed struct(u8) {
        enable_1: bool = false,
        enable_2: bool = false,
        enable_3: bool = false,
        enable_4: bool = false,
        other_flags: packed union {
            flags: packed struct(u4) {
                enable_1: bool = true,
                enable_2: bool = false,
                enable_3: bool = false,
                enable_4: bool = false,
            },
            bits: u4,
        } = .{ .flags = .{} },
    };
    var test_bits: FlagBits = .{};

    try expectEqual(false, test_bits.enable_1);
    try expectEqual(true, test_bits.other_flags.flags.enable_1);

    test_bits.enable_1 = true;

    try expectEqual(true, test_bits.enable_1);
    try expectEqual(true, test_bits.other_flags.flags.enable_1);

    test_bits.other_flags.flags.enable_1 = false;

    try expectEqual(true, test_bits.enable_1);
    try expectEqual(false, test_bits.other_flags.flags.enable_1);
}
