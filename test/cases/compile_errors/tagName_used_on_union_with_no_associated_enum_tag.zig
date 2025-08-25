const FloatInt = extern union {
    Float: f32,
    Int: i32,
};
export fn entry() void {
    const fi: FloatInt = .{ .Float = 123.45 };
    _ = @tagName(fi);
}

// error
// backend=stage2
// target=native
//
// :7:9: error: union 'tmp.FloatInt' is untagged
// :1:25: note: union declared here
