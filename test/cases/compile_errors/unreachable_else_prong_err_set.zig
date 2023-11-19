pub export fn complex() void {
    var a: error{ Foo, Bar } = error.Foo;
    _ = &a;
    switch (a) {
        error.Foo => unreachable,
        error.Bar => unreachable,
        else => {
            @compileError("<something complex here>");
        },
    }
}

pub export fn simple() void {
    var a: error{ Foo, Bar } = error.Foo;
    _ = &a;
    switch (a) {
        error.Foo => unreachable,
        error.Bar => unreachable,
        else => |e| return e,
    }
}

// error
// backend=llvm
// target=native
//
// :7:14: error: unreachable else prong; all cases already handled
