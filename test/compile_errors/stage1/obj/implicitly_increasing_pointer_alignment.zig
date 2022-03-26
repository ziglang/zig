const Foo = packed struct {
    a: u8,
    b: u32,
};

export fn entry() void {
    var foo = Foo { .a = 1, .b = 10 };
    bar(&foo.b);
}

fn bar(x: *u32) void {
    x.* += 1;
}

// implicitly increasing pointer alignment
//
// tmp.zig:8:13: error: expected type '*u32', found '*align(1) u32'
