fn f1(x: bool) u32 {
    if (x) return 1;
}
fn f2() noreturn {}
pub export fn entry() void {
    _ = f1(true);
    _ = f2();
}

// error
// backend=stage2
// target=native
//
// :1:16: error: function with non-void return type 'u32' implicitly returns
// :3:1: note: control flow reaches end of body here
// :4:9: error: function declared 'noreturn' implicitly returns
// :4:19: note: control flow reaches end of body here
