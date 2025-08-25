comptime {
    const spartan_count: u16 = 300;
    const byte: u8 = @intCast(spartan_count);
    _ = byte;
}

// test_error=type 'u8' cannot represent integer value '300'
