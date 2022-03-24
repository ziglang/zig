test "enum" {
    const E = enum(u8) {A, B, _};
    _ = @tagName(@intToEnum(E, 5));
}

// @tagName on invalid value of non-exhaustive enum
//
// tmp.zig:3:18: error: no tag by value 5
