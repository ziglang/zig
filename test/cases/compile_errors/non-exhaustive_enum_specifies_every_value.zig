const C = enum(u1) {
    a,
    b,
    _,
};
pub export fn entry() void {
    _ = C;
}

// error
// backend=stage2
// target=native
//
// :1:11: error: non-exhaustive enum specifies every value
