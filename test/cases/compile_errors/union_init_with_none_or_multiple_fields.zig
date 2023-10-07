const U1 = union {
    a: u8,
    b: i8,
};
const U2 = union(enum) {
    a: u8,
    b: i8,
};
export fn u1z() void {
    const x: U1 = .{};
    _ = x;
}
export fn u1m() void {
    const x: U1 = .{ .a = 1, .b = 1 };
    _ = x;
}
export fn u2z() void {
    const x: U2 = U2{};
    _ = x;
}
export fn u2m() void {
    const x: U2 = .{ .a = 1, .b = 1 };
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :10:20: error: union initializer must initialize one field
// :14:20: error: cannot initialize multiple union fields at once; unions can only have one active field
// :14:31: note: additional initializer here
// :1:12: note: union declared here
// :18:21: error: union initializer must initialize one field
// :22:20: error: cannot initialize multiple union fields at once; unions can only have one active field
// :22:31: note: additional initializer here
// :5:12: note: union declared here
