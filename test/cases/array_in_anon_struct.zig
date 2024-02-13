const std = @import("std");

noinline fn outer() u32 {
    var a: u32 = 42;
    _ = &a;
    return inner(.{
        .unused = a,
        .value = [1]u32{0},
    });
}

noinline fn inner(args: anytype) u32 {
    return args.value[0];
}

pub fn main() !void {
    try std.testing.expect(outer() == 0);
}

// run
// backend=llvm
// target=native
