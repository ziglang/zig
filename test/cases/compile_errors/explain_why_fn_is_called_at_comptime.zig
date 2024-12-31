const S = struct {
    fnPtr: fn () void,
    a: u8,
};
fn bar() void {}

fn foo(a: *u8) S {
    return .{ .fnPtr = bar, .a = a.* };
}
pub export fn entry() void {
    var a: u8 = 1;
    _ = foo(&a);
}

// error
//
// :12:13: error: unable to resolve comptime value
// :7:16: note: function with comptime-only return type 'tmp.S' is evaluated at comptime
// :2:12: note: struct requires comptime because of this field
// :2:12: note: use '*const fn () void' for a function pointer type
