const Foo = packed struct {
    a: u8,
    b: u32,
};

export fn entry() void {
    var foo = Foo{ .a = 1, .b = 10 };
    foo.b += 1;
    bar(@as(*[1]u32, &foo.b)[0..]);
}

fn bar(x: []u32) void {
    x[0] += 1;
}

// error
// backend=stage2
// target=native
//
// :9:22: error: expected type '*[1]u32', found '*align(1) u32'
// :9:22: note: pointer alignment '1' cannot cast into pointer alignment '4'
