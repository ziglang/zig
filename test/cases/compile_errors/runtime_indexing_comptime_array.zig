fn foo() void {}
fn bar() void {}

pub export fn entry1() void {
    const TestFn = fn () void;
    const test_fns = [_]TestFn{ foo, bar };
    for (test_fns) |testFn| {
        testFn();
    }
}
pub export fn entry2() void {
    const TestFn = fn () void;
    const test_fns = [_]TestFn{ foo, bar };
    var i: usize = 0;
    _ = test_fns[i];
}
pub export fn entry3() void {
    const TestFn = fn () void;
    const test_fns = [_]TestFn{ foo, bar };
    var i: usize = 0;
    _ = &test_fns[i];
}
// error
// target=native
// backend=stage2
//
// :6:5: error: values of type '[2]fn() void' must be comptime known, but index value is runtime known
// :6:5: note: use '*const fn() void' for a function pointer type
// :13:5: error: values of type '[2]fn() void' must be comptime known, but index value is runtime known
// :13:5: note: use '*const fn() void' for a function pointer type
// :19:5: error: values of type '[2]fn() void' must be comptime known, but index value is runtime known
// :19:5: note: use '*const fn() void' for a function pointer type
