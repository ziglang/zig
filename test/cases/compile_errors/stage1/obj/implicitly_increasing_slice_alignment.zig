const Foo = packed struct {
    a: u8,
    b: u32,
};

export fn entry() void {
    var foo = Foo { .a = 1, .b = 10 };
    foo.b += 1;
    bar(@as(*[1]u32, &foo.b)[0..]);
}

fn bar(x: []u32) void {
    x[0] += 1;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:9:26: error: cast increases pointer alignment
// tmp.zig:9:26: note: '*align(1) u32' has alignment 1
// tmp.zig:9:26: note: '*[1]u32' has alignment 4
