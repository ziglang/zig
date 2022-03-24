fn do_the_thing(func: fn (arg: i32) void) void { _ = func; }
fn bar(arg: bool) void { _ = arg; }
export fn entry() void {
    do_the_thing(bar);
}

// error note for function parameter incompatibility
//
// tmp.zig:4:18: error: expected type 'fn(i32) void', found 'fn(bool) void
// tmp.zig:4:18: note: parameter 0: 'bool' cannot cast into 'i32'
