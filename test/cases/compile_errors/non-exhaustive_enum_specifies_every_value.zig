const C = enum(u1) {
    a,
    b,
    _,
};
pub export fn entry() void {
    _ = C;
}

// error
//
// :1:11: error: non-exhaustive enum specifies every value
