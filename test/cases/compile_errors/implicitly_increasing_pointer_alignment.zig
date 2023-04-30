const Foo = packed struct {
    a: u8,
    b: u32,
};

export fn entry() void {
    var foo = Foo{ .a = 1, .b = 10 };
    bar(&foo.b);
}

fn bar(x: *u32) void {
    x.* += 1;
}

// error
// backend=stage2
// target=native
//
// :8:9: error: expected type '*u32', found '*align(1) u32'
// :8:9: note: pointer alignment '1' cannot cast into pointer alignment '4'
// :11:11: note: parameter type declared here
