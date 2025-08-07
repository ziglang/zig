export fn f() usize {
    const a = comptime 0 <<| (1 << @bitSizeOf(usize));
    return a;
}

// error
// target=x86_64-linux
//
// :2:30: error: this implementation only supports comptime shift amounts of up to 2^64 - 1 bits
