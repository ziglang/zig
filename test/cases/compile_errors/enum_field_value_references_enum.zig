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
// :1:5: error: dependency loop detected
