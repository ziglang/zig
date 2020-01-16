const std = @import("std");
const expect = std.testing.expect;

var new_stack_bytes: [1024]u8 align(16) = undefined;

test "calling a function with a new stack" {
    // TODO: https://github.com/ziglang/zig/issues/3268
    if (@import("builtin").arch == .aarch64) return error.SkipZigTest;
    if (@import("builtin").arch == .mipsel) return error.SkipZigTest;

    if (@import("builtin").arch == .riscv64) {
        // TODO: https://github.com/ziglang/zig/issues/3338
        return error.SkipZigTest;
    }
    if (comptime !std.Target.current.supportsNewStackCall()) {
        return error.SkipZigTest;
    }

    const arg = 1234;

    const a = @call(.{ .stack = new_stack_bytes[0..512] }, targetFunction, .{arg});
    const b = @call(.{ .stack = new_stack_bytes[512..] }, targetFunction, .{arg});
    _ = targetFunction(arg);

    expect(arg == 1234);
    expect(a < b);
}

fn targetFunction(x: i32) usize {
    expect(x == 1234);

    var local_variable: i32 = 42;
    const ptr = &local_variable;
    ptr.* += 1;

    expect(local_variable == 43);
    return @ptrToInt(ptr);
}
