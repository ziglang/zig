const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

test "@abs integers" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try comptime testAbsIntegers();
    try testAbsIntegers();
}

fn testAbsIntegers() !void {
    {
        var x: i32 = -1000;
        _ = &x;
        try expect(@abs(x) == 1000);
    }
    {
        var x: i32 = 0;
        _ = &x;
        try expect(@abs(x) == 0);
    }
    {
        var x: i32 = 1000;
        _ = &x;
        try expect(@abs(x) == 1000);
    }
    {
        var x: i64 = std.math.minInt(i64);
        _ = &x;
        try expect(@abs(x) == @as(u64, -std.math.minInt(i64)));
    }
    {
        var x: i5 = -1;
        _ = &x;
        try expect(@abs(x) == 1);
    }
    {
        var x: i5 = -5;
        _ = &x;
        try expect(@abs(x) == 5);
    }
    comptime {
        try expect(@abs(@as(i2, -2)) == 2);
    }
}

test "@abs unsigned integers" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try comptime testAbsUnsignedIntegers();
    try testAbsUnsignedIntegers();
}

fn testAbsUnsignedIntegers() !void {
    {
        var x: u32 = 1000;
        _ = &x;
        try expect(@abs(x) == 1000);
    }
    {
        var x: u32 = 0;
        _ = &x;
        try expect(@abs(x) == 0);
    }
    {
        var x: u32 = 1000;
        _ = &x;
        try expect(@abs(x) == 1000);
    }
    {
        var x: u5 = 1;
        _ = &x;
        try expect(@abs(x) == 1);
    }
    {
        var x: u5 = 5;
        _ = &x;
        try expect(@abs(x) == 5);
    }
    comptime {
        try expect(@abs(@as(u2, 2)) == 2);
    }
}

test "@abs floats" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;

    try comptime testAbsFloats(f16);
    try testAbsFloats(f16);
    try comptime testAbsFloats(f32);
    try testAbsFloats(f32);
    try comptime testAbsFloats(f64);
    try testAbsFloats(f64);
    try comptime testAbsFloats(f80);
    if (builtin.zig_backend != .stage2_wasm and builtin.zig_backend != .stage2_spirv64) try testAbsFloats(f80);
    try comptime testAbsFloats(f128);
    if (builtin.zig_backend != .stage2_wasm and builtin.zig_backend != .stage2_spirv64) try testAbsFloats(f128);
}

fn testAbsFloats(comptime T: type) !void {
    {
        var x: T = -2.62;
        _ = &x;
        try expect(@abs(x) == 2.62);
    }
    {
        var x: T = 2.62;
        _ = &x;
        try expect(@abs(x) == 2.62);
    }
    {
        var x: T = 0.0;
        _ = &x;
        try expect(@abs(x) == 0.0);
    }
    {
        var x: T = -std.math.pi;
        _ = &x;
        try expect(@abs(x) == std.math.pi);
    }

    {
        var x: T = -std.math.inf(T);
        _ = &x;
        try expect(@abs(x) == std.math.inf(T));
    }
    {
        var x: T = std.math.inf(T);
        _ = &x;
        try expect(@abs(x) == std.math.inf(T));
    }
    comptime {
        try expect(@abs(@as(T, -std.math.e)) == std.math.e);
    }
}

test "@abs int vectors" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try comptime testAbsIntVectors(1);
    try testAbsIntVectors(1);
    try comptime testAbsIntVectors(2);
    try testAbsIntVectors(2);
    try comptime testAbsIntVectors(3);
    try testAbsIntVectors(3);
    try comptime testAbsIntVectors(4);
    try testAbsIntVectors(4);
    try comptime testAbsIntVectors(8);
    try testAbsIntVectors(8);
    try comptime testAbsIntVectors(16);
    try testAbsIntVectors(16);
    try comptime testAbsIntVectors(17);
    try testAbsIntVectors(17);
}

fn testAbsIntVectors(comptime len: comptime_int) !void {
    const I32 = @Vector(len, i32);
    const U32 = @Vector(len, u32);
    const I64 = @Vector(len, i64);
    const U64 = @Vector(len, u64);
    {
        var x: I32 = @splat(-10);
        var y: U32 = @splat(10);
        _ = .{ &x, &y };
        try expect(std.mem.eql(u32, &@as([len]u32, y), &@as([len]u32, @abs(x))));
    }
    {
        var x: I32 = @splat(10);
        var y: U32 = @splat(10);
        _ = .{ &x, &y };
        try expect(std.mem.eql(u32, &@as([len]u32, y), &@as([len]u32, @abs(x))));
    }
    {
        var x: I32 = @splat(0);
        var y: U32 = @splat(0);
        _ = .{ &x, &y };
        try expect(std.mem.eql(u32, &@as([len]u32, y), &@as([len]u32, @abs(x))));
    }
    {
        var x: I64 = @splat(-10);
        var y: U64 = @splat(10);
        _ = .{ &x, &y };
        try expect(std.mem.eql(u64, &@as([len]u64, y), &@as([len]u64, @abs(x))));
    }
    {
        var x: I64 = @splat(std.math.minInt(i64));
        var y: U64 = @splat(-std.math.minInt(i64));
        _ = .{ &x, &y };
        try expect(std.mem.eql(u64, &@as([len]u64, y), &@as([len]u64, @abs(x))));
    }
    {
        var x = std.simd.repeat(len, @Vector(4, i32){ -2, 5, std.math.minInt(i32), -7 });
        var y = std.simd.repeat(len, @Vector(4, u32){ 2, 5, -std.math.minInt(i32), 7 });
        _ = .{ &x, &y };
        try expect(std.mem.eql(u32, &@as([len]u32, y), &@as([len]u32, @abs(x))));
    }
}

test "@abs unsigned int vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try comptime testAbsUnsignedIntVectors(1);
    try testAbsUnsignedIntVectors(1);
    try comptime testAbsUnsignedIntVectors(2);
    try testAbsUnsignedIntVectors(2);
    try comptime testAbsUnsignedIntVectors(3);
    try testAbsUnsignedIntVectors(3);
    try comptime testAbsUnsignedIntVectors(4);
    try testAbsUnsignedIntVectors(4);
    try comptime testAbsUnsignedIntVectors(8);
    try testAbsUnsignedIntVectors(8);
    try comptime testAbsUnsignedIntVectors(16);
    try testAbsUnsignedIntVectors(16);
    try comptime testAbsUnsignedIntVectors(17);
    try testAbsUnsignedIntVectors(17);
}

fn testAbsUnsignedIntVectors(comptime len: comptime_int) !void {
    const U32 = @Vector(len, u32);
    const U64 = @Vector(len, u64);
    {
        var x: U32 = @splat(10);
        var y: U32 = @splat(10);
        _ = .{ &x, &y };
        try expect(std.mem.eql(u32, &@as([len]u32, y), &@as([len]u32, @abs(x))));
    }
    {
        var x: U32 = @splat(10);
        var y: U32 = @splat(10);
        _ = .{ &x, &y };
        try expect(std.mem.eql(u32, &@as([len]u32, y), &@as([len]u32, @abs(x))));
    }
    {
        var x: U32 = @splat(0);
        var y: U32 = @splat(0);
        _ = .{ &x, &y };
        try expect(std.mem.eql(u32, &@as([len]u32, y), &@as([len]u32, @abs(x))));
    }
    {
        var x: U64 = @splat(10);
        var y: U64 = @splat(10);
        _ = .{ &x, &y };
        try expect(std.mem.eql(u64, &@as([len]u64, y), &@as([len]u64, @abs(x))));
    }
    {
        var x = std.simd.repeat(len, @Vector(3, u32){ 2, 5, 7 });
        var y = std.simd.repeat(len, @Vector(3, u32){ 2, 5, 7 });
        _ = .{ &x, &y };
        try expect(std.mem.eql(u32, &@as([len]u32, y), &@as([len]u32, @abs(x))));
    }
}

test "@abs float vectors" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    // https://github.com/ziglang/zig/issues/12827
    if (builtin.zig_backend == .stage2_llvm and
        builtin.os.tag == .macos and
        builtin.target.cpu.arch == .x86_64) return error.SkipZigTest;

    @setEvalBranchQuota(2000);
    try comptime testAbsFloatVectors(f16, 1);
    try testAbsFloatVectors(f16, 1);
    try comptime testAbsFloatVectors(f16, 2);
    try testAbsFloatVectors(f16, 2);
    try comptime testAbsFloatVectors(f16, 3);
    try testAbsFloatVectors(f16, 3);
    try comptime testAbsFloatVectors(f16, 4);
    try testAbsFloatVectors(f16, 4);
    try comptime testAbsFloatVectors(f16, 8);
    try testAbsFloatVectors(f16, 8);
    try comptime testAbsFloatVectors(f16, 16);
    try testAbsFloatVectors(f16, 16);
    try comptime testAbsFloatVectors(f16, 17);

    try testAbsFloatVectors(f32, 1);
    try comptime testAbsFloatVectors(f32, 1);
    try testAbsFloatVectors(f32, 1);
    try comptime testAbsFloatVectors(f32, 2);
    try testAbsFloatVectors(f32, 2);
    try comptime testAbsFloatVectors(f32, 3);
    try testAbsFloatVectors(f32, 3);
    try comptime testAbsFloatVectors(f32, 4);
    try testAbsFloatVectors(f32, 4);
    try comptime testAbsFloatVectors(f32, 8);
    try testAbsFloatVectors(f32, 8);
    try comptime testAbsFloatVectors(f32, 16);
    try testAbsFloatVectors(f32, 16);
    try comptime testAbsFloatVectors(f32, 17);
    try testAbsFloatVectors(f32, 17);

    try comptime testAbsFloatVectors(f64, 1);
    try testAbsFloatVectors(f64, 1);
    try comptime testAbsFloatVectors(f64, 2);
    try testAbsFloatVectors(f64, 2);
    try comptime testAbsFloatVectors(f64, 3);
    try testAbsFloatVectors(f64, 3);
    try comptime testAbsFloatVectors(f64, 4);
    try testAbsFloatVectors(f64, 4);
    try comptime testAbsFloatVectors(f64, 8);
    try testAbsFloatVectors(f64, 8);
    try comptime testAbsFloatVectors(f64, 16);
    try testAbsFloatVectors(f64, 16);
    try comptime testAbsFloatVectors(f64, 17);
    try testAbsFloatVectors(f64, 17);

    try comptime testAbsFloatVectors(f80, 1);
    try testAbsFloatVectors(f80, 1);
    try comptime testAbsFloatVectors(f80, 2);
    try testAbsFloatVectors(f80, 2);
    try comptime testAbsFloatVectors(f80, 3);
    try testAbsFloatVectors(f80, 3);
    try comptime testAbsFloatVectors(f80, 4);
    try testAbsFloatVectors(f80, 4);
    try comptime testAbsFloatVectors(f80, 8);
    try testAbsFloatVectors(f80, 8);
    try comptime testAbsFloatVectors(f80, 16);
    try testAbsFloatVectors(f80, 16);
    try comptime testAbsFloatVectors(f80, 17);
    try testAbsFloatVectors(f80, 17);

    try comptime testAbsFloatVectors(f128, 1);
    try testAbsFloatVectors(f128, 1);
    try comptime testAbsFloatVectors(f128, 2);
    try testAbsFloatVectors(f128, 2);
    try comptime testAbsFloatVectors(f128, 3);
    try testAbsFloatVectors(f128, 3);
    try comptime testAbsFloatVectors(f128, 4);
    try testAbsFloatVectors(f128, 4);
    try comptime testAbsFloatVectors(f128, 8);
    try testAbsFloatVectors(f128, 8);
    try comptime testAbsFloatVectors(f128, 16);
    try testAbsFloatVectors(f128, 16);
    try comptime testAbsFloatVectors(f128, 17);
    try testAbsFloatVectors(f128, 17);
}

fn testAbsFloatVectors(comptime T: type, comptime len: comptime_int) !void {
    const V = @Vector(len, T);
    {
        var x: V = @splat(-7.5);
        var y: V = @splat(7.5);
        _ = .{ &x, &y };
        try expect(std.mem.eql(T, &@as([len]T, y), &@as([len]T, @abs(x))));
    }
    {
        var x: V = @splat(7.5);
        var y: V = @splat(7.5);
        _ = .{ &x, &y };
        try expect(std.mem.eql(T, &@as([len]T, y), &@as([len]T, @abs(x))));
    }
    {
        var x: V = @splat(0.0);
        var y: V = @splat(0.0);
        _ = .{ &x, &y };
        try expect(std.mem.eql(T, &@as([len]T, y), &@as([len]T, @abs(x))));
    }
    {
        var x: V = @splat(-std.math.pi);
        var y: V = @splat(std.math.pi);
        _ = .{ &x, &y };
        try expect(std.mem.eql(T, &@as([len]T, y), &@as([len]T, @abs(x))));
    }
    {
        var x: V = @splat(std.math.pi);
        var y: V = @splat(std.math.pi);
        _ = .{ &x, &y };
        try expect(std.mem.eql(T, &@as([len]T, y), &@as([len]T, @abs(x))));
    }
}
