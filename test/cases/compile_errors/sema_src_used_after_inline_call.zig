inline fn bit_count(value: i32) i32 {
    var i = value;
    // Algo from : http://aggregate.ee.engr.uky.edu/MAGIC/#Population%20Count%20(ones%20Count)
    i -= ((i >> 1) & 0x55555555);
    i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
    i = (((i >> 4) + i) & 0x0F0F0F0F);
    i += (i >> 8);
    i += (i >> 16);
    return (i & 0x0000003F);
}

inline fn number_of_trailing_zeros(i: i32) u32 {
    return @as(u32, bit_count((i & -i) - 1));
}

export fn entry() void {
    _ = number_of_trailing_zeros(0);
}

// error
// backend=stage2
// target=native
//
// :13:30: error: expected type 'u32', found 'i32'
// :13:30: note: unsigned 32-bit int cannot represent all possible signed 32-bit values
// :17:33: note: called from here
