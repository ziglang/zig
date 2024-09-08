const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "@shuffle int" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and
        !comptime std.Target.x86.featureSetHas(builtin.cpu.features, .ssse3)) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var v: @Vector(4, i32) = [4]i32{ 2147483647, -2, 30, 40 };
            _ = &v;
            var x: @Vector(4, i32) = [4]i32{ 1, 2147483647, 3, 4 };
            _ = &x;
            const mask = [4]i32{ 0, ~@as(i32, 2), 3, ~@as(i32, 3) };
            var res = @shuffle(i32, v, x, mask);
            try expect(mem.eql(i32, &@as([4]i32, res), &[4]i32{ 2147483647, 3, 40, 4 }));

            // Implicit cast from array (of mask)
            res = @shuffle(i32, v, x, [4]i32{ 0, ~@as(i32, 2), 3, ~@as(i32, 3) });
            try expect(mem.eql(i32, &@as([4]i32, res), &[4]i32{ 2147483647, 3, 40, 4 }));

            // Undefined
            const mask2 = [4]i32{ 3, 1, 2, 0 };
            res = @shuffle(i32, v, undefined, mask2);
            try expect(mem.eql(i32, &@as([4]i32, res), &[4]i32{ 40, -2, 30, 2147483647 }));

            // Upcasting of b
            var v2: @Vector(2, i32) = [2]i32{ 2147483647, undefined };
            _ = &v2;
            const mask3 = [4]i32{ ~@as(i32, 0), 2, ~@as(i32, 0), 3 };
            res = @shuffle(i32, x, v2, mask3);
            try expect(mem.eql(i32, &@as([4]i32, res), &[4]i32{ 2147483647, 3, 2147483647, 4 }));

            // Upcasting of a
            var v3: @Vector(2, i32) = [2]i32{ 2147483647, -2 };
            _ = &v3;
            const mask4 = [4]i32{ 0, ~@as(i32, 2), 1, ~@as(i32, 3) };
            res = @shuffle(i32, v3, x, mask4);
            try expect(mem.eql(i32, &@as([4]i32, res), &[4]i32{ 2147483647, 3, -2, 4 }));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@shuffle int strange sizes" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try comptime testShuffle(2, 2, 2);
    try testShuffle(2, 2, 2);
    try comptime testShuffle(4, 4, 4);
    try testShuffle(4, 4, 4);
    try comptime testShuffle(7, 4, 4);
    try testShuffle(7, 4, 4);
    try comptime testShuffle(8, 6, 4);
    try testShuffle(8, 6, 4);
    try comptime testShuffle(2, 7, 5);
    try testShuffle(2, 7, 5);
    try comptime testShuffle(13, 16, 12);
    try testShuffle(13, 16, 12);
    try comptime testShuffle(19, 3, 17);
    try testShuffle(19, 3, 17);
    try comptime testShuffle(1, 10, 1);
    try testShuffle(1, 10, 1);
}

fn testShuffle(
    comptime x_len: comptime_int,
    comptime a_len: comptime_int,
    comptime b_len: comptime_int,
) !void {
    const T = i32;
    const XT = @Vector(x_len, T);
    const AT = @Vector(a_len, T);
    const BT = @Vector(b_len, T);

    const a_elems = comptime blk: {
        var elems: [a_len]T = undefined;
        for (&elems, 0..) |*elem, i| elem.* = @intCast(100 + i);
        break :blk elems;
    };
    var a: AT = a_elems;
    _ = &a;

    const b_elems = comptime blk: {
        var elems: [b_len]T = undefined;
        for (&elems, 0..) |*elem, i| elem.* = @intCast(1000 + i);
        break :blk elems;
    };
    var b: BT = b_elems;
    _ = &b;

    const mask_seed: []const i32 = &.{ -14, -31, 23, 1, 21, 13, 17, -21, -10, -27, -16, -5, 15, 14, -2, 26, 2, -31, -24, -16 };

    const mask = comptime blk: {
        var elems: [x_len]i32 = undefined;
        for (&elems, 0..) |*elem, i| {
            const mask_val = mask_seed[i];
            if (mask_val >= 0) {
                elem.* = @mod(mask_val, a_len);
            } else {
                elem.* = @mod(mask_val, -b_len);
            }
        }

        break :blk elems;
    };

    const x: XT = @shuffle(T, a, b, mask);

    const x_elems: [x_len]T = x;
    for (mask, x_elems) |m, x_elem| {
        if (m >= 0) {
            // Element from A
            try expectEqual(x_elem, a_elems[@intCast(m)]);
        } else {
            // Element from B
            try expectEqual(x_elem, b_elems[@intCast(~m)]);
        }
    }
}

test "@shuffle bool 1" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and
        builtin.cpu.arch == .aarch64 and builtin.os.tag == .windows)
    {
        // https://github.com/ziglang/zig/issues/19824
        return error.SkipZigTest;
    }

    const S = struct {
        fn doTheTest() !void {
            var x: @Vector(4, bool) = [4]bool{ false, true, false, true };
            _ = &x;
            var v: @Vector(2, bool) = [2]bool{ true, false };
            _ = &v;
            const mask = [4]i32{ 0, ~@as(i32, 1), 1, 2 };
            const res = @shuffle(bool, x, v, mask);
            try expect(mem.eql(bool, &@as([4]bool, res), &[4]bool{ false, false, true, false }));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "@shuffle bool 2" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var x: @Vector(3, bool) = [3]bool{ false, true, false };
            _ = &x;
            var v: @Vector(2, bool) = [2]bool{ true, false };
            _ = &v;
            const mask = [4]i32{ 0, ~@as(i32, 1), 1, 2 };
            const res = @shuffle(bool, x, v, mask);
            try expect(mem.eql(bool, &@as([4]bool, res), &[4]bool{ false, false, true, false }));
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}
