const E = enum(u8) {
    a,
    b,
    _,
};
const U = union(E) {
    a,
    b,
};
export fn foo() void {
    var e = @intToEnum(E, 15);
    var u: U = e;
    _ = u;
}
export fn bar() void {
    const e = @intToEnum(E, 15);
    var u: U = e;
    _ = u;
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:12:16: error: runtime cast to union 'U' from non-exhaustive enum
// tmp.zig:17:16: error: no tag by value 15
