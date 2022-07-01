const Foo = enum(u32) {
    A = 10,
    B = 11,
};
export fn entry() void {
    var x = @intToEnum(Foo, 0);
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :6:13: error: enum 'tmp.Foo' has no tag with value '0'
// :1:13: note: enum declared here
