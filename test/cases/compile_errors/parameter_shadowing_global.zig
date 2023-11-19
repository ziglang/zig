const Foo = struct {};
fn f(Foo: i32) void {}
export fn entry0() void {
    f(1234);
}

export fn entry1() void {
    const foo = 0;
    _ = fn(foo: u32) void;
}

export fn entry2() void {
    _ = fn(arg: u8, arg: u32) void;
}

// error
// backend=stage2
// target=native
//
// :2:6: error: function parameter shadows declaration of 'Foo'
// :1:1: note: declared here
// :9:12: error: function prototype parameter 'foo' shadows local constant from outer scope
// :8:11: note: previous declaration here
// :13:21: error: redeclaration of function prototype parameter 'arg'
// :13:12: note: previous declaration here
