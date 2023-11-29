const S1 = struct {
    a: S2,
};
const S2 = struct {
    b: fn () void,
};
pub export fn entry() void {
    var s: S1 = undefined;
    _ = &s;
}

// error
// backend=stage2
// target=native
//
// :8:12: error: variable of type 'tmp.S1' must be const or comptime
// :2:8: note: struct requires comptime because of this field
// :5:8: note: struct requires comptime because of this field
// :5:8: note: use '*const fn () void' for a function pointer type
