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
// backend=stage2
// target=native
//
// :3:8: error: cannot dereference non-pointer type 'tmp.Box'
// :8:13: error: cannot dereference non-pointer type 'tmp.Box'
