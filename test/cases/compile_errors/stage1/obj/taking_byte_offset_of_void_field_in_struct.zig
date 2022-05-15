const Empty = struct {
    val: void,
};
export fn foo() void {
    const fieldOffset = @offsetOf(Empty, "val",);
    _ = fieldOffset;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:42: error: zero-bit field 'val' in struct 'Empty' has no offset
