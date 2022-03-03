const builtin = @import("builtin");
const expect = @import("std").testing.expect;

test "@mulAdd" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime try testMulAdd();
    try testMulAdd();
}

fn testMulAdd() !void {
    if (builtin.zig_backend == .stage1) {
        const a: f16 = 5.5;
        const b: f16 = 2.5;
        const c: f16 = 6.25;
        try expect(@mulAdd(f16, a, b, c) == 20);
    }
    {
        const a: f32 = 5.5;
        const b: f32 = 2.5;
        const c: f32 = 6.25;
        try expect(@mulAdd(f32, a, b, c) == 20);
    }
    {
        const a: f64 = 5.5;
        const b: f64 = 2.5;
        const c: f64 = 6.25;
        try expect(@mulAdd(f64, a, b, c) == 20);
    }
}

test "@mulAdd f80" {
    if (true) {
        // https://github.com/ziglang/zig/issues/11030
        return error.SkipZigTest;
    }

    // TODO: missing f80 implementation of FMA in `std.math.fma` or compiler-rt
    // comptime try testMulAdd80();

    try testMulAdd80();
}

fn testMulAdd80() !void {
    var a: f16 = 5.5;
    var b: f80 = 2.5;
    var c: f80 = 6.25;
    try expect(@mulAdd(f80, a, b, c) == 20.0);
}

test "@mulAdd f128" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
        // https://github.com/ziglang/zig/issues/9900
        return error.SkipZigTest;
    }

    comptime try testMulAdd128();
    try testMulAdd128();
}

fn testMulAdd128() !void {
    const a: f16 = 5.5;
    const b: f128 = 2.5;
    const c: f128 = 6.25;
    try expect(@mulAdd(f128, a, b, c) == 20);
}
