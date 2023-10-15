const S = struct {
    fnPtr: fn () void,
};
fn bar() void {}
fn baz() void {}
var runtime: bool = true;
fn ifExpr() S {
    if (runtime) {
        return .{
            .fnPtr = bar,
        };
    } else {
        return .{
            .fnPtr = baz,
        };
    }
}
pub export fn entry1() void {
    _ = ifExpr();
}
fn switchExpr() S {
    switch (runtime) {
        true => return .{
            .fnPtr = bar,
        },
        false => return .{
            .fnPtr = baz,
        },
    }
}
pub export fn entry2() void {
    _ = switchExpr();
}

// error
// backend=stage2
// target=native
//
// :8:9: error: unable to resolve comptime value
// :8:9: note: condition in comptime branch must be comptime-known
// :7:13: note: expression is evaluated at comptime because the function returns a comptime-only type 'tmp.S'
// :2:12: note: struct requires comptime because of this field
// :2:12: note: use '*const fn () void' for a function pointer type
// :19:15: note: called from here
// :22:13: error: unable to resolve comptime value
// :22:13: note: condition in comptime switch must be comptime-known
// :21:17: note: expression is evaluated at comptime because the function returns a comptime-only type 'tmp.S'
// :2:12: note: struct requires comptime because of this field
// :2:12: note: use '*const fn () void' for a function pointer type
// :32:19: note: called from here
