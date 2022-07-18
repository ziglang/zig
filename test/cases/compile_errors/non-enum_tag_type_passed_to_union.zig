const Foo = union(u32) {
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
// :1:19: error: expected enum tag type, found 'u32'
