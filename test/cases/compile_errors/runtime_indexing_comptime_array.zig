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
// backend=stage2,llvm
//
// :6:33: error: values of type '[2]fn() callconv(.C) void' must be comptime known, but index value is runtime known
// :6:33: note: use '*const fn() callconv(.C) void' for a function pointer type
// :13:33: error: values of type '[2]fn() callconv(.C) void' must be comptime known, but index value is runtime known
// :13:33: note: use '*const fn() callconv(.C) void' for a function pointer type
// :19:33: error: values of type '[2]fn() callconv(.C) void' must be comptime known, but index value is runtime known
// :19:33: note: use '*const fn() callconv(.C) void' for a function pointer type
