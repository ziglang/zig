const std = @import("std");
const other_file = @import("655_other_file.zig");

test "function with &const parameter with type dereferenced by namespace" {
    const x: other_file.Integer = 1234;
    comptime std.debug.assert(@typeOf(&x) == *const other_file.Integer);
    foo(x);
}

fn foo(x: *const other_file.Integer) void {
    std.debug.assert(x.* == 1234);
}
