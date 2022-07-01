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
// backend=stage2
// target=native
//
// :7:19: error: union 'tmp.FloatInt' is untagged
// :1:25: note: union declared here
