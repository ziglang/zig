test "enum" {
    const E = enum(u8) {A, B, _};
    _ = @tagName(@intToEnum(E, 5));
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:3:18: error: no tag by value 5
