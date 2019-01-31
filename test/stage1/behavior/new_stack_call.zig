const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;

var new_stack_bytes: [1024]u8 = undefined;

test "calling a function with a new stack" {
    const arg = 1234;

    const a = @newStackCall(new_stack_bytes[0..512], targetFunction, arg);
    const b = @newStackCall(new_stack_bytes[512..], targetFunction, arg);
    _ = targetFunction(arg);

    assertOrPanic(arg == 1234);
    assertOrPanic(a < b);
}

fn targetFunction(x: i32) usize {
    assertOrPanic(x == 1234);

    var local_variable: i32 = 42;
    const ptr = &local_variable;
    ptr.* += 1;

    assertOrPanic(local_variable == 43);
    return @ptrToInt(ptr);
}
