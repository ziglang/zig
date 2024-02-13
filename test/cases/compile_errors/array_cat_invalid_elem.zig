const Foo = enum { a };
pub export fn entry1() void {
    const arr = [_]Foo{.a};
    _ = arr ++ .{.b};
}
pub export fn entry2() void {
    const b = .{.b};
    const arr = [_]Foo{.a};
    _ = arr ++ b;
}

// error
//
// :4:19: error: no field named 'b' in enum 'tmp.Foo'
// :1:13: note: enum declared here
// :9:16: error: no field named 'b' in enum 'tmp.Foo'
// :1:13: note: enum declared here
