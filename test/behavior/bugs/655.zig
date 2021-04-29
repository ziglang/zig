const std = @import("std");
const other_file = @import("655_other_file.zig");

test "function with *const parameter with type dereferenced by namespace" {
    const x: other_file.Integer = 1234;
    comptime std.testing.expect(@TypeOf(&x) == *const other_file.Integer);
    foo(&x);
}

fn foo(x: *const other_file.Integer) void {
    std.testing.expect(x.* == 1234);
}
