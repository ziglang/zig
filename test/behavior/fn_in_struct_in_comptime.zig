const builtin = @import("builtin");
const expect = @import("std").testing.expect;

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
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const foo = get_foo();
    try expect(foo(@intToPtr(*u8, 12345)) == 12345);
}
