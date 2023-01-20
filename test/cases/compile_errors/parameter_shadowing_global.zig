const Foo = struct {};
fn f(Foo: i32) void {}
export fn entry() void {
    f(1234);
}

// error
// backend=stage2
// target=native
//
// :2:6: error: function parameter shadows declaration of 'Foo'
// :1:1: note: declared here
