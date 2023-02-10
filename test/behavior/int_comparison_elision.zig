const std = @import("std");
const minInt = std.math.minInt;
const maxInt = std.math.maxInt;
const builtin = @import("builtin");

test "int comparison elision" {
    testIntEdges(u0);
    testIntEdges(i0);
    testIntEdges(u1);
    testIntEdges(i1);
    testIntEdges(u4);
    testIntEdges(i4);

    // TODO: support int types > 128 bits wide in other backends
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    // TODO: panic: integer overflow with int types > 65528 bits wide
    // TODO: LLVM generates too many parameters for wasmtime when splitting up int > 64000 bits wide
    testIntEdges(u64000);
    testIntEdges(i64000);
}

// All comparisons in this test have a guaranteed result,
// so one branch of each 'if' should never be analyzed.
fn testIntEdges(comptime T: type) void {
    const min = minInt(T);
    const max = maxInt(T);

    var runtime_val: T = undefined;

    if (min > runtime_val) @compileError("analyzed impossible branch");
    if (min <= runtime_val) {} else @compileError("analyzed impossible branch");
    if (runtime_val < min) @compileError("analyzed impossible branch");
    if (runtime_val >= min) {} else @compileError("analyzed impossible branch");

    if (min - 1 > runtime_val) @compileError("analyzed impossible branch");
    if (min - 1 >= runtime_val) @compileError("analyzed impossible branch");
    if (min - 1 < runtime_val) {} else @compileError("analyzed impossible branch");
    if (min - 1 <= runtime_val) {} else @compileError("analyzed impossible branch");
    if (min - 1 == runtime_val) @compileError("analyzed impossible branch");
    if (min - 1 != runtime_val) {} else @compileError("analyzed impossible branch");
    if (runtime_val < min - 1) @compileError("analyzed impossible branch");
    if (runtime_val <= min - 1) @compileError("analyzed impossible branch");
    if (runtime_val > min - 1) {} else @compileError("analyzed impossible branch");
    if (runtime_val >= min - 1) {} else @compileError("analyzed impossible branch");
    if (runtime_val == min - 1) @compileError("analyzed impossible branch");
    if (runtime_val != min - 1) {} else @compileError("analyzed impossible branch");

    if (max >= runtime_val) {} else @compileError("analyzed impossible branch");
    if (max < runtime_val) @compileError("analyzed impossible branch");
    if (runtime_val <= max) {} else @compileError("analyzed impossible branch");
    if (runtime_val > max) @compileError("analyzed impossible branch");

    if (max + 1 > runtime_val) {} else @compileError("analyzed impossible branch");
    if (max + 1 >= runtime_val) {} else @compileError("analyzed impossible branch");
    if (max + 1 < runtime_val) @compileError("analyzed impossible branch");
    if (max + 1 <= runtime_val) @compileError("analyzed impossible branch");
    if (max + 1 == runtime_val) @compileError("analyzed impossible branch");
    if (max + 1 != runtime_val) {} else @compileError("analyzed impossible branch");
    if (runtime_val < max + 1) {} else @compileError("analyzed impossible branch");
    if (runtime_val <= max + 1) {} else @compileError("analyzed impossible branch");
    if (runtime_val > max + 1) @compileError("analyzed impossible branch");
    if (runtime_val >= max + 1) @compileError("analyzed impossible branch");
    if (runtime_val == max + 1) @compileError("analyzed impossible branch");
    if (runtime_val != max + 1) {} else @compileError("analyzed impossible branch");

    const undef_const: T = undefined;

    if (min > undef_const) @compileError("analyzed impossible branch");
    if (min <= undef_const) {} else @compileError("analyzed impossible branch");
    if (undef_const < min) @compileError("analyzed impossible branch");
    if (undef_const >= min) {} else @compileError("analyzed impossible branch");

    if (min - 1 > undef_const) @compileError("analyzed impossible branch");
    if (min - 1 >= undef_const) @compileError("analyzed impossible branch");
    if (min - 1 < undef_const) {} else @compileError("analyzed impossible branch");
    if (min - 1 <= undef_const) {} else @compileError("analyzed impossible branch");
    if (min - 1 == undef_const) @compileError("analyzed impossible branch");
    if (min - 1 != undef_const) {} else @compileError("analyzed impossible branch");
    if (undef_const < min - 1) @compileError("analyzed impossible branch");
    if (undef_const <= min - 1) @compileError("analyzed impossible branch");
    if (undef_const > min - 1) {} else @compileError("analyzed impossible branch");
    if (undef_const >= min - 1) {} else @compileError("analyzed impossible branch");
    if (undef_const == min - 1) @compileError("analyzed impossible branch");
    if (undef_const != min - 1) {} else @compileError("analyzed impossible branch");

    if (max >= undef_const) {} else @compileError("analyzed impossible branch");
    if (max < undef_const) @compileError("analyzed impossible branch");
    if (undef_const <= max) {} else @compileError("analyzed impossible branch");
    if (undef_const > max) @compileError("analyzed impossible branch");

    if (max + 1 > undef_const) {} else @compileError("analyzed impossible branch");
    if (max + 1 >= undef_const) {} else @compileError("analyzed impossible branch");
    if (max + 1 < undef_const) @compileError("analyzed impossible branch");
    if (max + 1 <= undef_const) @compileError("analyzed impossible branch");
    if (max + 1 == undef_const) @compileError("analyzed impossible branch");
    if (max + 1 != undef_const) {} else @compileError("analyzed impossible branch");
    if (undef_const < max + 1) {} else @compileError("analyzed impossible branch");
    if (undef_const <= max + 1) {} else @compileError("analyzed impossible branch");
    if (undef_const > max + 1) @compileError("analyzed impossible branch");
    if (undef_const >= max + 1) @compileError("analyzed impossible branch");
    if (undef_const == max + 1) @compileError("analyzed impossible branch");
    if (undef_const != max + 1) {} else @compileError("analyzed impossible branch");
}
