export fn valid() void {
    var x: u128 = 0;
    _ = @atomicRmw(u128, &x, .Xchg, 1, .monotonic);
}
export fn invalid() void {
    var x: u256 = 0;
    _ = @atomicRmw(u256, &x, .Xchg, 1, .monotonic);
}

// error
// target=aarch64-native
//
// ":7:16: error: {s} does not support @atomicRmw(.Xchg) on this type", .{arch}),
// ":7:16: note: size of type is 32, but Xchg on {s} requires a value of size 1, 2, 4, 8, or 16", .{arch}),
