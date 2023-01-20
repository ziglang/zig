const expect = @import("std").testing.expect;

const A = struct {
    a: u32,
};

fn foo(comptime a: anytype) !void {
    try expect(a[0][0] == @sizeOf(A));
}

test {
    try foo(.{[_]usize{@sizeOf(A)}});
}
