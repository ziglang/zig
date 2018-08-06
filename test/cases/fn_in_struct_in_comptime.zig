const assert = @import("std").debug.assert;

fn get_foo() fn (*u8) usize {
    comptime {
        return struct {
            fn func(ptr: *u8) usize {
                var u = @ptrToInt(ptr);
                return u;
            }
        }.func;
    }
}

test "define a function in an anonymous struct in comptime" {
    const foo = get_foo();
    assert(foo(@intToPtr(*u8, 12345)) == 12345);
}
