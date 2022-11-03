const std = @import("std");
const debug = std.debug;

fn f(a: anytype) void {
    _ = a;
}

test {
    debug.assert(@typeInfo(@TypeOf(f)).Fn.return_type == void);
}
