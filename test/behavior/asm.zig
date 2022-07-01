const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

const is_x86_64_linux = builtin.cpu.arch == .x86_64 and builtin.os.tag == .linux;

comptime {
    if (builtin.zig_backend != .stage2_arm and
        builtin.zig_backend != .stage2_aarch64 and
        is_x86_64_linux)
    {
        asm (
            \\.globl this_is_my_alias;
            \\.type this_is_my_alias, @function;
            \\.set this_is_my_alias, derp;
        );
    }
}

test "module level assembly" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    if (is_x86_64_linux) {
        try expect(this_is_my_alias() == 1234);
    }
}

test "output constraint modifiers" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    // This is only testing compilation.
    var a: u32 = 3;
    asm volatile (""
        : [_] "=m,r" (a),
        :
        : ""
    );
    asm volatile (""
        : [_] "=r,m" (a),
        :
        : ""
    );
}

test "alternative constraints" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    // Make sure we allow commas as a separator for alternative constraints.
    var a: u32 = 3;
    asm volatile (""
        : [_] "=r,m" (a),
        : [_] "r,m" (a),
        : ""
    );
}

test "sized integer/float in asm input" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    asm volatile (""
        :
        : [_] "m" (@as(usize, 3)),
        : ""
    );
    asm volatile (""
        :
        : [_] "m" (@as(i15, -3)),
        : ""
    );
    asm volatile (""
        :
        : [_] "m" (@as(u3, 3)),
        : ""
    );
    asm volatile (""
        :
        : [_] "m" (@as(i3, 3)),
        : ""
    );
    asm volatile (""
        :
        : [_] "m" (@as(u121, 3)),
        : ""
    );
    asm volatile (""
        :
        : [_] "m" (@as(i121, 3)),
        : ""
    );
    asm volatile (""
        :
        : [_] "m" (@as(f32, 3.17)),
        : ""
    );
    asm volatile (""
        :
        : [_] "m" (@as(f64, 3.17)),
        : ""
    );
}

test "struct/array/union types as input values" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    asm volatile (""
        :
        : [_] "m" (@as([1]u32, undefined)),
    ); // fails
    asm volatile (""
        :
        : [_] "m" (@as(struct { x: u32, y: u8 }, undefined)),
    ); // fails
    asm volatile (""
        :
        : [_] "m" (@as(union { x: u32, y: u8 }, undefined)),
    ); // fails
}

extern fn this_is_my_alias() i32;

export fn derp() i32 {
    return 1234;
}
