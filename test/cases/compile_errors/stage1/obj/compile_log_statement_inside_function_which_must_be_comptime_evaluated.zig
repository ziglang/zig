fn Foo(comptime T: type) type {
    @compileLog(@typeName(T));
    return T;
}
export fn entry() void {
    _ = Foo(i32);
    _ = @typeName(Foo(i32));
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: found compile log statement
