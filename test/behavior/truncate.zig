const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const expect = std.testing.expect;

test "truncate u0 to larger integer allowed and has comptime-known result" {
    var x: u0 = 0;
    _ = &x;
    const y = @as(u8, @truncate(x));
    comptime assert(y == 0);
}

test "truncate.u0.literal" {
    const z: u0 = @truncate(0);
    try expect(z == 0);
}

test "truncate.u0.const" {
    const c0: usize = 0;
    const z: u0 = @truncate(c0);
    try expect(z == 0);
}

test "truncate.u0.var" {
    var d: u8 = 2;
    _ = &d;
    const z: u0 = @truncate(d);
    try expect(z == 0);
}

test "truncate i0 to larger integer allowed and has comptime-known result" {
    var x: i0 = 0;
    _ = &x;
    const y: i8 = @truncate(x);
    comptime assert(y == 0);
}

test "truncate.i0.literal" {
    const z: i0 = @truncate(0);
    try expect(z == 0);
}

test "truncate.i0.const" {
    const c0: isize = 0;
    const z: i0 = @truncate(c0);
    try expect(z == 0);
}

test "truncate.i0.var" {
    var d: i8 = 2;
    _ = &d;
    const z: i0 = @truncate(d);
    try expect(z == 0);
}

test "truncate on comptime integer" {
    const x: u16 = @truncate(9999);
    try expect(x == 9999);
    const y: u16 = @truncate(-21555);
    try expect(y == 0xabcd);
    const z: i16 = @truncate(-65537);
    try expect(z == -1);
    const w: u1 = @truncate(1 << 100);
    try expect(w == 0);
}

test "truncate on vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var v1: @Vector(4, u16) = .{ 0xaabb, 0xccdd, 0xeeff, 0x1122 };
            _ = &v1;
            const v2: @Vector(4, u8) = @truncate(v1);
            try expect(std.mem.eql(u8, &@as([4]u8, v2), &[4]u8{ 0xbb, 0xdd, 0xff, 0x22 }));
        }
    };
    try comptime S.doTheTest();
    try S.doTheTest();
}
