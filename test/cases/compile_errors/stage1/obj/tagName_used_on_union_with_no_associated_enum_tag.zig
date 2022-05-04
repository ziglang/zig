const FloatInt = extern union {
    Float: f32,
    Int: i32,
};
export fn entry() void {
    var fi = FloatInt{.Float = 123.45};
    var tagName = @tagName(fi);
    _ = tagName;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:7:19: error: union has no associated enum
// tmp.zig:1:18: note: declared here
