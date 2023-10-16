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

test "flags in packed union at offset" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const FlagBits = packed union {
        base_flags: packed union {
            flags: packed struct(u4) {
                enable_1: bool = true,
                enable_2: bool = false,
                enable_3: bool = false,
                enable_4: bool = false,
            },
            bits: u4,
        },
        adv_flags: packed struct(u12) {
            pad: u8 = 0,
            adv: packed union {
                flags: packed struct(u4) {
                    enable_1: bool = true,
                    enable_2: bool = false,
                    enable_3: bool = false,
                    enable_4: bool = false,
                },
                bits: u4,
            },
        },
    };
    var test_bits: FlagBits = .{ .adv_flags = .{ .adv = .{ .flags = .{} } } };

    try expectEqual(@as(u8, 0), test_bits.adv_flags.pad);
    try expectEqual(true, test_bits.adv_flags.adv.flags.enable_1);
    try expectEqual(false, test_bits.adv_flags.adv.flags.enable_2);

    test_bits.adv_flags.adv.flags.enable_1 = false;
    test_bits.adv_flags.adv.flags.enable_2 = true;
    try expectEqual(@as(u8, 0), test_bits.adv_flags.pad);
    try expectEqual(false, test_bits.adv_flags.adv.flags.enable_1);
    try expectEqual(true, test_bits.adv_flags.adv.flags.enable_2);

    test_bits.adv_flags.adv.bits = 12;
    try expectEqual(@as(u8, 0), test_bits.adv_flags.pad);
    try expectEqual(false, test_bits.adv_flags.adv.flags.enable_1);
    try expectEqual(false, test_bits.adv_flags.adv.flags.enable_2);
}

test "packed union in packed struct" {
    // Originally reported at https://github.com/ziglang/zig/issues/16581
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const ReadRequest = packed struct { key: i32 };
    const RequestType = enum {
        read,
        insert,
    };
    const RequestUnion = packed union {
        read: ReadRequest,
    };

    const Request = packed struct {
        active_type: RequestType,
        request: RequestUnion,
        const Self = @This();

        fn init(read: ReadRequest) Self {
            return .{
                .active_type = .read,
                .request = RequestUnion{ .read = read },
            };
        }
    };

    try std.testing.expectEqual(RequestType.read, Request.init(.{ .key = 3 }).active_type);
}
