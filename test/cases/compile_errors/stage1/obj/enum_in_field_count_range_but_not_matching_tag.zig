const Foo = enum(u32) {
    A = 10,
    B = 11,
};
export fn entry() void {
    var x = @intToEnum(Foo, 0);
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:13: error: enum 'Foo' has no tag matching integer value 0
// tmp.zig:1:13: note: 'Foo' declared here
