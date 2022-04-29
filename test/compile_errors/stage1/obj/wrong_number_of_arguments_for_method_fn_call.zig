const Foo = struct {
    fn method(self: *const Foo, a: i32) void {_ = self; _ = a;}
};
fn f(foo: *const Foo) void {

    foo.method(1, 2);
}
export fn entry() usize { return @sizeOf(@TypeOf(f)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:6:15: error: expected 2 argument(s), found 3
