const Empty = struct {
    val: void,
};
export fn foo() void {
    const fieldOffset = @bitOffsetOf(Empty, "val",);
    _ = fieldOffset;
}

// taking bit offset of void field in struct
//
// tmp.zig:5:45: error: zero-bit field 'val' in struct 'Empty' has no offset
