const B = enum(u1) {
    a,
    _,
    b,
};
const C = enum(u1) {
    a,
    b,
    _,
};
pub export fn entry() void {
    _ = B;
    _ = C;
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:3:5: error: '_' field of non-exhaustive enum must be last
// tmp.zig:6:11: error: non-exhaustive enum specifies every value
