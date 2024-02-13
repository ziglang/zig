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
    _ = &i;
}
pub export fn entry3() void {
    const TestFn = fn () void;
    const test_fns = [_]TestFn{ foo, bar };
    var i: usize = 0;
    _ = &test_fns[i];
    _ = &i;
}
// error
// target=native
// backend=stage2
//
// :7:10: error: values of type '[2]fn () void' must be comptime-known, but index value is runtime-known
// :7:10: note: use '*const fn () void' for a function pointer type
// :15:18: error: values of type '[2]fn () void' must be comptime-known, but index value is runtime-known
// :15:17: note: use '*const fn () void' for a function pointer type
// :22:19: error: values of type '[2]fn () void' must be comptime-known, but index value is runtime-known
// :22:18: note: use '*const fn () void' for a function pointer type
