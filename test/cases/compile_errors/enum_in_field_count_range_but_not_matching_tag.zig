const Foo = enum(u32) {
    A = 10,
    B = 11,
};
export fn entry() void {
    var x: Foo = @enumFromInt(0);
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :6:18: error: enum 'tmp.Foo' has no tag with value '0'
// :1:13: note: enum declared here
