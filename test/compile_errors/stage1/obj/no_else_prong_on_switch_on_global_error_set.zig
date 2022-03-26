export fn entry() void {
    foo(error.A);
}
fn foo(a: anyerror) void {
    switch (a) {
        error.A => {},
    }
}

// no else prong on switch on global error set
//
// tmp.zig:5:5: error: else prong required when switching on type 'anyerror'
