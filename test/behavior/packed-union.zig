const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;

test "flags in packed union" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try testFlagsInPackedUnion();
    try comptime testFlagsInPackedUnion();
}

fn testFlagsInPackedUnion() !void {
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

    try testFlagsInPackedUnionAtOffset();
    try comptime testFlagsInPackedUnionAtOffset();
}

fn testFlagsInPackedUnionAtOffset() !void {
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

    try testPackedUnionInPackedStruct();
    try comptime testPackedUnionInPackedStruct();
}

fn testPackedUnionInPackedStruct() !void {
    const ReadRequest = packed struct { key: i32 };
    const RequestType = enum(u1) {
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

test "packed union initialized with a runtime value" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const Fields = packed struct {
        timestamp: u50,
        random_bits: u13,
    };
    const ID = packed union {
        value: u63,
        fields: Fields,

        fn value() i64 {
            return 1341;
        }
    };

    const timestamp: i64 = ID.value();
    const id = ID{ .fields = Fields{
        .timestamp = @as(u50, @intCast(timestamp)),
        .random_bits = 420,
    } };
    try std.testing.expect((ID{ .value = id.value }).fields.timestamp == timestamp);
}

test "assigning to non-active field at comptime" {
    comptime {
        const FlagBits = packed union {
            flags: packed struct {},
            bits: packed struct {},
        };

        var test_bits: FlagBits = .{ .flags = .{} };
        test_bits.bits = .{};
    }
}

test "comptime packed union of pointers" {
    const U = packed union {
        a: *const u32,
        b: *const [1]u32,
    };

    const x: u32 = 123;
    const u: U = .{ .a = &x };

    comptime assert(u.b[0] == 123);
}
