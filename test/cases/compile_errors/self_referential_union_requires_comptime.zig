const U = union {
    a: fn () void,
    b: *U,
};
pub export fn entry() void {
    var u: U = undefined;
    _ = &u;
}

// error
// backend=stage2
// target=native
//
// :6:12: error: variable of type 'tmp.U' must be const or comptime
// :2:8: note: union requires comptime because of this field
// :2:8: note: use '*const fn () void' for a function pointer type
// :3:8: note: union requires comptime because of this field
