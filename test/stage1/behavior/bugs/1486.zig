const assertOrPanic = @import("std").debug.assertOrPanic;

const ptr = &global;
var global: u64 = 123;

test "constant pointer to global variable causes runtime load" {
    global = 1234;
    assertOrPanic(&global == ptr);
    assertOrPanic(ptr.* == 1234);
}

