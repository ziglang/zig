comptime {
    const x = @shrExact(@as(u8, 0b10101010), 2);
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:15: error: exact shift shifted out 1 bits
