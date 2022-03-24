const Empty = struct {
    val: void,
};
export fn foo() void {
    const fieldOffset = @offsetOf(Empty, "val",);
    _ = fieldOffset;
}

// taking byte offset of void field in struct
//
// tmp.zig:5:42: error: zero-bit field 'val' in struct 'Empty' has no offset
