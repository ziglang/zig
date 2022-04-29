pub const Foo = enum(c_int) {
    A = Foo.B,
    C = D,
};
export fn entry() void {
    var s: Foo = Foo.E;
    _ = s;
}
const D = 1;

// error
// backend=stage1
// target=native
//
// tmp.zig:1:17: error: enum 'Foo' depends on itself
