export fn a() void {
    var box = Box{ .field = 0 };
    box.*.field = 1;
}
export fn b() void {
    var box = Box{ .field = 0 };
    var boxPtr = &box;
    boxPtr.*.*.field = 1;
}
pub const Box = struct {
    field: i32,
};

// error
// backend=stage1
// target=native
//
// tmp.zig:3:8: error: attempt to dereference non-pointer type 'Box'
// tmp.zig:8:13: error: attempt to dereference non-pointer type 'Box'
