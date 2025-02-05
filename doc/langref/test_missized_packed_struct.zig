test "missized packed struct" {
    const S = packed struct(u32) { a: u16, b: u8 };
    _ = S{ .a = 4, .b = 2 };
}

// test_error=backing integer type 'u32' has bit size 32 but the struct fields have a total bit size of 24
