const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expect = std.testing.expect;

test "@maskedScatter int" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest(random: std.rand.Random) !void {
            @setEvalBranchQuota(100_000);
            inline for (0..8) |i| {
                try doTheTestInternal(u8, i, random);
                try doTheTestInternal(u16, i, random);
                try doTheTestInternal(u32, i, random);
                try doTheTestInternal(i8, i, random);
                try doTheTestInternal(i16, i, random);
                try doTheTestInternal(i32, i, random);
                try doTheTestInternal(f32, i, random);
                try doTheTestInternal(bool, i, random);
            }
        }

        fn nextValue(comptime T: type, random: std.rand.Random) T {
            return switch (@typeInfo(T)) {
                .Int => return random.int(T),
                .Float => return random.float(T),
                .Bool => return random.boolean(),
                else => unreachable,
            };
        }

        fn doTheTestInternal(comptime T: type, comptime len: u16, random: std.rand.Random) !void {
            var dest: [len]T = undefined;
            for (&dest) |*v| v.* = nextValue(T, random);
            var source: [len]T = undefined;
            for (&source) |*v| v.* = nextValue(T, random);
            var mask: [len]bool = undefined;
            for (&mask) |*v| v.* = nextValue(bool, random);

            var expected: [len]T = undefined;
            for (&expected, &dest, &source, &mask) |*exp, des, src, msk| {
                exp.* = if (msk) src else des;
            }

            var ptrs: [len]*T = undefined;
            for (&ptrs, &dest) |*ptr, *dst| {
                ptr.* = dst;
            }

            @maskedScatter(T, ptrs, source, mask);

            try std.testing.expectEqual(expected, dest);
        }
    };

    var runtime_pcg = std.rand.Pcg.init(0);
    try S.doTheTest(runtime_pcg.random());

    comptime {
        var comptime_pcg = std.rand.Pcg.init(0);
        try S.doTheTest(comptime_pcg.random());
    }
}
