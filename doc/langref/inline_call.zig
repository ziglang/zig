const std = @import("std");

test "inline function call" {
    if (foo(1200, 34) != 1234) {
        @compileError("bad");
    }
}

inline fn foo(a: i32, b: i32) i32 {
    std.debug.print("runtime a = {} b = {}", .{ a, b });
    return a + b;
}

// test
