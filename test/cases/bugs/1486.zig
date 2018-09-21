const assert = @import("std").debug.assert;

const ptr = &global;
var global: u64 = 123;

test "constant pointer to global variable causes runtime load" {
    global = 1234;
    assert(&global == ptr);
    assert(ptr.* == 1234);
}

