const Small = enum(f32) {
    One,
    Two,
    Three,
};

export fn entry() void {
    const x = Small.One;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :1:20: error: expected integer tag type, found 'f32'
