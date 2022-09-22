const U1 = union {
    a: u8,
    b: i8,
};
const U2 = union(enum) {
    a: u8,
    b: i8,
};
fn u1z() void {
    const x: U1 = .{};
    _ = x;
}
fn u1m() void {
    const x: U1 = .{ .a = 1, .b = 1 };
    _ = x;
}
fn u2z() void {
    const x: U2 = .{};
    _ = x;
}
fn u2m() void {
    const x: U2 = .{ .a = 1, .b = 1 };
    _ = x;
}
export fn entry() void {u1z();u1m();u2z();u2m();}
// error
// backend=stage2
// target=native
//
// :9:1: error: cannot initialize none union fields, unions can only have one active field
// :14:20: error: cannot initialize multiple union fields at once, unions can only have one active field
// :14:31: note: additional initializer here
// :17:1: error: cannot initialize none union fields, unions can only have one active field
// :22:20: error: cannot initialize multiple union fields at once, unions can only have one active field
// :22:31: note: additional initializer here
// :1:12: note: union declared here
// :5:12: note: union declared here