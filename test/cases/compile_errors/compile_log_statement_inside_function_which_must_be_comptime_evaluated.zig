fn Foo(comptime T: type) type {
    @compileLog(@typeName(T));
    return T;
}
export fn entry() void {
    _ = Foo(i32);
    _ = @typeName(Foo(i32));
}

// error
// backend=stage2
// target=native
//
// :2:5: error: found compile log statement
//
// Compile Log Output:
// @as(*const [3:0]u8, "i32")
