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
//
// :9:22: error: expected type '*[1]u32', found '*align(8:8:8) u32'
// :9:22: note: pointer host size '8' cannot cast into pointer host size '0'
// :9:22: note: pointer bit offset '8' cannot cast into pointer bit offset '0'
