export fn entry() void {
    var x: u128 = 0;
    @cmpxchgWeak(u128, &x, 1, 2, .monotonic, .monotonic);
}

// error
// target=x86_64-native:baseline
//
// :3:16: error: 16-byte @cmpxchgWeak on x86_64 requires the following missing CPU features: cx16
