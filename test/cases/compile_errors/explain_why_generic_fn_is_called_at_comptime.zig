fn S(comptime PtrTy: type) type {
    return struct {
        fnPtr: PtrTy,
        a: u8,
    };
}
fn bar() void {}

fn foo(a: u8, comptime PtrTy: type) S(PtrTy) {
    return .{ .fnPtr = bar, .a = a };
}
pub export fn entry() void {
    var a: u8 = 1;
    _ = &a;
    _ = foo(a, fn () void);
}
// error
//
// :15:13: error: unable to resolve comptime value
// :15:12: note: call to generic function instantiated with comptime-only return type 'tmp.S(fn () void)' is evaluated at comptime
// :9:38: note: return type declared here
// :3:16: note: struct requires comptime because of this field
// :3:16: note: use '*const fn () void' for a function pointer type
