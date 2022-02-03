const std = @import("std");
const expect = std.testing.expect;

const ptr = &global;
var global: usize = 123;

test "constant pointer to global variable causes runtime load" {
    global = 1234;
    try expect(&global == ptr);
    try expect(ptr.* == 1234);
}
