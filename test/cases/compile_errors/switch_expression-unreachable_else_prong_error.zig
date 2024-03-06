fn foo(x: u2) void {
    const y: Error!u2 = x;
    if (y) |_| {} else |e| switch (e) {
        error.Foo => {},
        error.Bar => {},
        error.Baz => {},
        else => {},
    }
}

fn bar(x: u2) void {
    const y: Error!u2 = x;
    y catch |e| switch (e) {
        error.Foo => {},
        error.Bar => {},
        error.Baz => {},
        else => {},
    };
}

const Error = error{ Foo, Bar, Baz };

export fn entry() usize {
    return @sizeOf(@TypeOf(&foo)) + @sizeOf(@TypeOf(&bar));
}

// error
// backend=stage2
// target=native
//
// :7:14: error: unreachable else prong; all cases already handled
// :17:14: error: unreachable else prong; all cases already handled
