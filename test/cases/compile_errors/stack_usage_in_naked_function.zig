export fn a() callconv(.Naked) noreturn {
    var x: u32 = 10;
    _ = &x;

    const y: u32 = x + 10;
    _ = y;
}

export fn b() callconv(.Naked) noreturn {
    var x = @as(u32, 10);
    _ = &x;

    const y = x;
    var z = y;
    _ = &z;
}

export fn c() callconv(.Naked) noreturn {
    const Foo = struct {
        y: u32,
    };

    var x: Foo = .{ .y = 10 };
    _ = &x;
}

export fn d() callconv(.Naked) noreturn {
    const Foo = struct {
        inline fn bar() void {
            var x: u32 = 10;
            _ = &x;
        }
    };

    Foo.bar();
}

// error
// backend=stage2
//
// :2:5: error: local variable in naked function
// :10:5: error: local variable in naked function
// :23:5: error: local variable in naked function
// :30:13: error: local variable in naked function
// :35:12: note: called from here
