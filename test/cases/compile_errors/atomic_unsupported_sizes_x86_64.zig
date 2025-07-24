export fn rmw() void {
    var x: u128 = 0;
    _ = @atomicRmw(u128, &x, .Xchg, 1, .monotonic);
}
export fn cmpxchg() void {
    var x: u256 = 0;
    _ = @cmpxchgWeak(u256, &x, 0, 1, .monotonic, .monotonic);
}

// error
// target=x86_64-native:x86_64_v2
//
// ":7:16: error: {s} does not support @atomicRmw(.Xchg) on this type", .{arch}),
// ":7:16: note: size of type is 32, but Xchg on {s} requires a value of size 1, 2, 4, 8, or 16", .{arch}),
