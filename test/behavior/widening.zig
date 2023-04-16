const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;
const builtin = @import("builtin");
const has_f80_rt = @import("builtin").cpu.arch == .x86_64;

test "integer widening" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var a: u8 = 250;
    var b: u16 = a;
    var c: u32 = b;
    var d: u64 = c;
    var e: u64 = d;
    var f: u128 = e;
    try expect(f == a);
}

fn zero() u0 {
    return 0;
}
test "integer widening u0 to u8" {
    const a: u8 = zero();
    try expect(a == 0);
}

test "implicit unsigned integer to signed integer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var a: u8 = 250;
    var b: i16 = a;
    try expect(b == 250);
}

test "float widening" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    if (builtin.os.tag == .windows and builtin.cpu.arch == .aarch64 and
        builtin.zig_backend == .stage2_c)
    {
        // https://github.com/ziglang/zig/issues/13876
        return error.SkipZigTest;
    }

    if (builtin.os.tag == .macos and builtin.zig_backend == .stage2_c) {
        // TODO: test is failing
        return error.SkipZigTest;
    }

    var a: f16 = 12.34;
    var b: f32 = a;
    var c: f64 = b;
    var d: f128 = c;
    try expect(a == b);
    try expect(b == c);
    try expect(c == d);
    if (has_f80_rt) {
        var e: f80 = c;
        try expect(c == e);
    }
}

test "float widening f16 to f128" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    if (builtin.os.tag == .windows and builtin.cpu.arch == .aarch64 and
        builtin.zig_backend == .stage2_c)
    {
        // https://github.com/ziglang/zig/issues/13876
        return error.SkipZigTest;
    }

    if (builtin.os.tag == .macos and builtin.zig_backend == .stage2_c) {
        // TODO: test is failing
        return error.SkipZigTest;
    }

    var x: f16 = 12.34;
    var y: f128 = x;
    try expect(x == y);
}

test "cast small unsigned to larger signed" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(castSmallUnsignedToLargerSigned1(200) == @as(i16, 200));
    try expect(castSmallUnsignedToLargerSigned2(9999) == @as(i64, 9999));
}
fn castSmallUnsignedToLargerSigned1(x: u8) i16 {
    return x;
}
fn castSmallUnsignedToLargerSigned2(x: u16) i64 {
    return x;
}
