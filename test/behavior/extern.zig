const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

test "anyopaque extern symbol" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const a = @extern(*anyopaque, .{ .name = "a_mystery_symbol" });
    const b: *i32 = @alignCast(@ptrCast(a));
    try expect(b.* == 1234);
}

export var a_mystery_symbol: i32 = 1234;

test "function extern symbol" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const a = @extern(*const fn () callconv(.C) i32, .{ .name = "a_mystery_function" });
    try expect(a() == 4567);
}

export fn a_mystery_function() i32 {
    return 4567;
}

test "function extern symbol matches extern decl" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        extern fn another_mystery_function() u32;
        const same_thing = @extern(*const fn () callconv(.C) u32, .{ .name = "another_mystery_function" });
    };
    try expect(S.another_mystery_function() == 12345);
    try expect(S.same_thing() == 12345);
}

export fn another_mystery_function() u32 {
    return 12345;
}
