fn do_the_thing(func: *const fn (arg: i32) void) void {
    _ = func;
}
fn bar(arg: bool) void {
    _ = arg;
}
export fn entry() void {
    do_the_thing(bar);
}

// error
// backend=stage2
// target=native
//
// :8:18: error: expected type '*const fn (i32) void', found '*const fn (bool) void'
// :8:18: note: pointer type child 'fn (bool) void' cannot cast into pointer type child 'fn (i32) void'
// :8:18: note: parameter 0 'bool' cannot cast into 'i32'
