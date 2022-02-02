const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

const ptr = &global;
var global: usize = 123;

test "constant pointer to global variable causes runtime load" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    global = 1234;
    try expect(&global == ptr);
    try expect(ptr.* == 1234);
}
