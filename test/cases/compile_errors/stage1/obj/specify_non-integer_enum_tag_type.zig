const Small = enum (f32) {
    One,
    Two,
    Three,
};

export fn entry() void {
    var x = Small.One;
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:21: error: expected integer, found 'f32'
