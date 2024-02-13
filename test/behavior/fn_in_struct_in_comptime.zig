const builtin = @import("builtin");
const expect = @import("std").testing.expect;

fn get_foo() fn (*u8) usize {
    comptime {
        return struct {
            fn func(ptr: *u8) usize {
                return @intFromPtr(ptr);
            }
        }.func;
    }
}

test "define a function in an anonymous struct in comptime" {
    const foo = get_foo();
    try expect(foo(@as(*u8, @ptrFromInt(12345))) == 12345);
}
