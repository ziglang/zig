const builtin = @import("builtin");
const expect = @import("std").testing.expect;

test "@mulAdd" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testMulAdd();
    try testMulAdd();
}

fn testMulAdd() !void {
    {
        var a: f32 = 5.5;
        var b: f32 = 2.5;
        var c: f32 = 6.25;
        try expect(@mulAdd(f32, a, b, c) == 20);
    }
    {
        var a: f64 = 5.5;
        var b: f64 = 2.5;
        var c: f64 = 6.25;
        try expect(@mulAdd(f64, a, b, c) == 20);
    }
}

test "@mulAdd f16" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testMulAdd16();
    try testMulAdd16();
}

fn testMulAdd16() !void {
    var a: f16 = 5.5;
    var b: f16 = 2.5;
    var c: f16 = 6.25;
    try expect(@mulAdd(f16, a, b, c) == 20);
}

test "@mulAdd f80" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try testMulAdd80();
    try testMulAdd80();
}

fn testMulAdd80() !void {
    var a: f16 = 5.5;
    var b: f80 = 2.5;
    var c: f80 = 6.25;
    try expect(@mulAdd(f80, a, b, c) == 20);
}

test "@mulAdd f128" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    if (builtin.os.tag == .windows and builtin.cpu.arch == .aarch64 and
        builtin.zig_backend == .stage2_c)
    {
        // https://github.com/ziglang/zig/issues/13876
        return error.SkipZigTest;
    }

    comptime try testMulAdd128();
    try testMulAdd128();
}

fn testMulAdd128() !void {
    var a: f16 = 5.5;
    var b: f128 = 2.5;
    var c: f128 = 6.25;
    try expect(@mulAdd(f128, a, b, c) == 20);
}

fn vector16() !void {
    var a = @Vector(4, f16){ 5.5, 5.5, 5.5, 5.5 };
    var b = @Vector(4, f16){ 2.5, 2.5, 2.5, 2.5 };
    var c = @Vector(4, f16){ 6.25, 6.25, 6.25, 6.25 };
    var x = @mulAdd(@Vector(4, f16), a, b, c);

    try expect(x[0] == 20);
    try expect(x[1] == 20);
    try expect(x[2] == 20);
    try expect(x[3] == 20);
}

test "vector f16" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try vector16();
    try vector16();
}

fn vector32() !void {
    var a = @Vector(4, f32){ 5.5, 5.5, 5.5, 5.5 };
    var b = @Vector(4, f32){ 2.5, 2.5, 2.5, 2.5 };
    var c = @Vector(4, f32){ 6.25, 6.25, 6.25, 6.25 };
    var x = @mulAdd(@Vector(4, f32), a, b, c);

    try expect(x[0] == 20);
    try expect(x[1] == 20);
    try expect(x[2] == 20);
    try expect(x[3] == 20);
}

test "vector f32" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try vector32();
    try vector32();
}

fn vector64() !void {
    var a = @Vector(4, f64){ 5.5, 5.5, 5.5, 5.5 };
    var b = @Vector(4, f64){ 2.5, 2.5, 2.5, 2.5 };
    var c = @Vector(4, f64){ 6.25, 6.25, 6.25, 6.25 };
    var x = @mulAdd(@Vector(4, f64), a, b, c);

    try expect(x[0] == 20);
    try expect(x[1] == 20);
    try expect(x[2] == 20);
    try expect(x[3] == 20);
}

test "vector f64" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try vector64();
    try vector64();
}

fn vector80() !void {
    var a = @Vector(4, f80){ 5.5, 5.5, 5.5, 5.5 };
    var b = @Vector(4, f80){ 2.5, 2.5, 2.5, 2.5 };
    var c = @Vector(4, f80){ 6.25, 6.25, 6.25, 6.25 };
    var x = @mulAdd(@Vector(4, f80), a, b, c);
    try expect(x[0] == 20);
    try expect(x[1] == 20);
    try expect(x[2] == 20);
    try expect(x[3] == 20);
}

test "vector f80" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime try vector80();
    try vector80();
}

fn vector128() !void {
    var a = @Vector(4, f128){ 5.5, 5.5, 5.5, 5.5 };
    var b = @Vector(4, f128){ 2.5, 2.5, 2.5, 2.5 };
    var c = @Vector(4, f128){ 6.25, 6.25, 6.25, 6.25 };
    var x = @mulAdd(@Vector(4, f128), a, b, c);

    try expect(x[0] == 20);
    try expect(x[1] == 20);
    try expect(x[2] == 20);
    try expect(x[3] == 20);
}

test "vector f128" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    if (builtin.os.tag == .windows and builtin.cpu.arch == .aarch64 and
        builtin.zig_backend == .stage2_c)
    {
        // https://github.com/ziglang/zig/issues/13876
        return error.SkipZigTest;
    }

    comptime try vector128();
    try vector128();
}
