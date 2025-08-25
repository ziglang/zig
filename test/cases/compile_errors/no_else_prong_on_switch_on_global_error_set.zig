export fn entry() void {
    foo(error.A);
}
fn foo(a: anyerror) void {
    switch (a) {
        error.A => {},
    }
}

// error
// backend=stage2
// target=native
//
// :5:5: error: else prong required when switching on type 'anyerror'
