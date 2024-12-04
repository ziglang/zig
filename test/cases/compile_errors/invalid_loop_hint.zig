const globl = g: {
    @loopHint(.none);
    break :g {};
};

comptime {
    @loopHint(.none);
}

test {
    @loopHint(.none);
}

export fn foo() void {
    {
        @loopHint(.none);
    }
}

export fn bar() void {
    _ = (b: {
        @loopHint(.none);
        break :b true;
    }) or true;
}

export fn qux() void {
    (b: {
        @loopHint(.none);
        break :b @as(?void, {});
    }) orelse unreachable;
}

export fn x() void {
    for (0..3) |_| {} else {
        @loopHint(.none);
    }
}

export fn y() void {
    while (true) {} else {
        @loopHint(.none);
    }
}

export fn a(cond: u32) void {
    if (cond == 0) {
        @loopHint(.none);
    }
}

export fn b() void {
    for (0..3) |i| {
        _ = i;
        @loopHint(.none);
    }
}

export fn c() void {
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        i += 1;
        @loopHint(.none);
    }
}

export fn d() void {
    var i: usize = 0;
    while (i < 10) {
        i += 1;
        @loopHint(.none);
    }
}

export fn e() void {
    var i: usize = 0;
    while (i < 10) : ({
        @loopHint(.none);
        i += 1;
    }) {}
}

export fn f() void {
    while (true) {
        {
            @loopHint(.none);
        }
    }
}

export fn g() void {
    while (true) {
        @loopHint(.none);
        @loopHint(.none);
    }
}

// error
//
// :2:5: error: '@loopHint' outside function scope
// :7:5: error: '@loopHint' outside function scope
// :11:5: error: '@loopHint' must appear before non-hint statements in a loop body
// :16:9: error: '@loopHint' must appear before non-hint statements in a loop body
// :22:9: error: '@loopHint' must appear before non-hint statements in a loop body
// :29:9: error: '@loopHint' must appear before non-hint statements in a loop body
// :36:9: error: '@loopHint' must appear before non-hint statements in a loop body
// :42:9: error: '@loopHint' must appear before non-hint statements in a loop body
// :48:9: error: '@loopHint' must appear before non-hint statements in a loop body
// :55:9: error: '@loopHint' must appear before non-hint statements in a loop body
// :63:9: error: '@loopHint' must appear before non-hint statements in a loop body
// :71:9: error: '@loopHint' must appear before non-hint statements in a loop body
// :78:9: error: '@loopHint' must appear before non-hint statements in a loop body
// :86:13: error: '@loopHint' must appear before non-hint statements in a loop body
// :94:9: error: duplicate '@loopHint' call; only one is allowed per loop
