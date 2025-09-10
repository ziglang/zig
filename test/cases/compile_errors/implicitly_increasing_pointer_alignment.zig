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
//
// :8:9: error: expected type '*u32', found '*align(8:8:8) u32'
// :8:9: note: pointer host size '8' cannot cast into pointer host size '0'
// :8:9: note: pointer bit offset '8' cannot cast into pointer bit offset '0'
// :11:11: note: parameter type declared here
