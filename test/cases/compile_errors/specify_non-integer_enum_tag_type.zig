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
// backend=stage2
// target=native
//
// :1:21: error: expected integer tag type, found 'f32'
