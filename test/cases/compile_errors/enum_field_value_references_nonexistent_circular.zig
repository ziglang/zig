pub const Foo = enum(c_int) {
    A = Foo.B,
    C = D,
};
export fn entry() void {
    const s: Foo = Foo.E;
    _ = s;
}
const D = 1;

// error
// backend=stage2
// target=native
//
// :2:13: error: enum 'tmp.Foo' has no member named 'B'
// :1:17: note: enum declared here
