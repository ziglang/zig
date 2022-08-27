pub export fn complex() void {
    var a: error{ Foo, Bar } = error.Foo;
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
// :6:14: error: unreachable else prong; all cases already handled
