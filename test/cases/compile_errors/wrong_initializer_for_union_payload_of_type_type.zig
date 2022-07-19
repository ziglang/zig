const U = union(enum) {
    A: type,
};
const S = struct {
    u: U,
};
export fn entry() void {
    comptime var v: S = undefined;
    v.u.A = U{ .A = i32 };
}

// error
// backend=stage2
// target=native
//
// :9:14: error: expected type 'type', found 'tmp.U'
// :1:11: note: union declared here
