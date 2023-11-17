const std = @import("std");

test {
    try foo(@typeInfo(@TypeOf(someFn)));
}

fn someFn(arg: ?*c_int) f64 {
    _ = arg;
    return 8;
}
fn foo(comptime info: std.builtin.Type) !void {
    try std.testing.expect(info.Fn.params[0].type.? == ?*c_int);
}

// run
// is_test=true
// backend=llvm
//
