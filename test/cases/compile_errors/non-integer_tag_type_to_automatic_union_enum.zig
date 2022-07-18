const Foo = union(enum(f32)) {
    A: i32,
};
export fn entry() void {
    const x = @typeInfo(Foo).Union.tag_type.?;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :1:24: error: expected integer tag type, found 'f32'
