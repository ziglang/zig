const FooType = opaque {};
fn generic(comptime T: type) !T {
    return undefined;
}
export fn bar() void {
    _ = generic(FooType);
}
export fn bav() void {
    _ = generic(@TypeOf(null));
}
export fn baz() void {
    _ = generic(@TypeOf(undefined));
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:16: error: call to generic function with Opaque return type 'FooType' not allowed
// tmp.zig:2:1: note: function declared here
// tmp.zig:1:1: note: type declared here
// tmp.zig:9:16: error: call to generic function with Null return type '@Type(.Null)' not allowed
// tmp.zig:2:1: note: function declared here
// tmp.zig:12:16: error: call to generic function with Undefined return type '@Type(.Undefined)' not allowed
// tmp.zig:2:1: note: function declared here
