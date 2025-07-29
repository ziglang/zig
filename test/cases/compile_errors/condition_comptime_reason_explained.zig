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
//
// :8:9: error: unable to resolve comptime value
// :19:15: note: called at comptime from here
// :19:15: note: call to function with comptime-only return type 'tmp.S' is evaluated at comptime
// :7:13: note: return type declared here
// :2:12: note: struct requires comptime because of this field
// :2:12: note: use '*const fn () void' for a function pointer type
// :22:13: error: unable to resolve comptime value
// :32:19: note: called at comptime from here
// :32:19: note: call to function with comptime-only return type 'tmp.S' is evaluated at comptime
// :21:17: note: return type declared here
// :2:12: note: struct requires comptime because of this field
// :2:12: note: use '*const fn () void' for a function pointer type
