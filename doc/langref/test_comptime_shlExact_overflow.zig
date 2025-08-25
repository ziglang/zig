comptime {
    const x = @shlExact(@as(u8, 0b01010101), 2);
    _ = x;
}

// test_error=overflow of integer type 'u8' with value '340'
