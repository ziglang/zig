export fn a() void {
    var box = Box{ .field = 0 };
    _ = &box;
    box.*.field = 1;
}
export fn b() void {
    var box = Box{ .field = 0 };
    const box_ptr = &box;
    box_ptr.*.*.field = 1;
}
pub const Box = struct {
    field: i32,
};

// error
// backend=stage2
// target=native
//
// :4:8: error: cannot dereference non-pointer type 'tmp.Box'
// :11:17: note: struct declared here
// :9:14: error: cannot dereference non-pointer type 'tmp.Box'
// :11:17: note: struct declared here
