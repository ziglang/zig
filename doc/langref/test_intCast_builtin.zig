test "integer cast panic" {
    var a: u16 = 0xabcd; // runtime-known
    _ = &a;
    const b: u8 = @intCast(a);
    _ = b;
}

// test_error=cast to 'u8' from 'u16' truncated bits: 43981 above 'u8' maximum (255)
