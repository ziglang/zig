const Foo = struct {
    fn method(self: *const Foo, a: i32) void {
        _ = self;
        _ = a;
    }
};
fn f(foo: *const Foo) void {
    foo.method(1, 2);
}
export fn entry() usize {
    return @sizeOf(@TypeOf(&f));
}

// error
// backend=stage2
// target=native
//
// :8:8: error: member function expected 1 argument(s), found 2
// :2:5: note: function declared here
