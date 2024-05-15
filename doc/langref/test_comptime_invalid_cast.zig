comptime {
    const value: i32 = -1;
    const unsigned: u32 = @intCast(value);
    _ = unsigned;
}

// test_error=type 'u32' cannot represent integer value '-1'
