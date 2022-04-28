const Number = enum {
    a,
    b align(i32),
};
export fn entry1() void {
    var x: Number = undefined;
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:7: error: expected ',' after field
