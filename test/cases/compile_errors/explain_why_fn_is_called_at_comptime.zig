const S = struct {
    fnPtr: fn () void,
    a: u8,
};
fn bar() void {}

fn foo(comptime a: *u8) S {
    return .{ .fnPtr = bar, .a = a.* };
}
pub export fn entry() void {
    var a: u8 = 1;
    _ = foo(&a);
}

// error
// backend=stage2
// target=native
//
// :12:13: error: unable to resolve comptime value
// :12:13: note: argument to function being called at comptime must be comptime-known
// :7:25: note: expression is evaluated at comptime because the function returns a comptime-only type 'tmp.S'
// :2:12: note: struct requires comptime because of this field
// :2:12: note: use '*const fn () void' for a function pointer type
