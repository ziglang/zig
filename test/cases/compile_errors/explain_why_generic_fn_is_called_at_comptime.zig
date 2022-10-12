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
    _ = foo(a, fn () void);
}
// error
// backend=stage2
// target=native
//
// :14:13: error: unable to resolve comptime value
// :14:13: note: argument to function being called at comptime must be comptime-known
// :9:38: note: generic function is instantiated with a comptime-only return type
