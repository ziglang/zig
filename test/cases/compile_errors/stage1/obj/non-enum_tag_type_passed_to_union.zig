const Foo = union(u32) {
    A: i32,
};
export fn entry() void {
    const x = @typeInfo(Foo).Union.tag_type.?;
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:19: error: expected enum tag type, found 'u32'
