const Number = enum {
    a,
    b align(i32),
};
export fn entry1() void {
    var x: Number = undefined;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :3:7: error: expected ',' after field
