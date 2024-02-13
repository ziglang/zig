export fn foo() void {
    var ptr = &[_]u8{ 0, 0, 0, 0 };
    ptr[1] = 2;
}
export fn bar() void {
    var ptr = &@as(u32, 2);
    ptr.* = 2;
    _ = &ptr;
}
export fn baz() void {
    var ptr = &true;
    ptr.* = false;
    _ = &ptr;
}
export fn qux() void {
    const S = struct {
        x: usize,
        y: usize,
    };
    var ptr = &S{ .x = 1, .y = 2 };
    ptr.x = 2;
}
export fn quux() void {
    var x = &@returnAddress();
    x.* = 6;
    _ = &x;
}

// error
// backend=stage2
// target=native
//
// :3:8: error: cannot assign to constant
// :7:8: error: cannot assign to constant
// :12:8: error: cannot assign to constant
// :21:8: error: cannot assign to constant
// :25:6: error: cannot assign to constant
