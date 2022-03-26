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

// wrong initializer for union payload of type 'type'
//
// tmp.zig:9:8: error: use of undefined value here causes undefined behavior
