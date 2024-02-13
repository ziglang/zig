//! Generator to extend 64-bit seed values into longer sequences.
//!
//! The number of cycles is thus limited to 64-bits regardless of the engine, but this
//! is still plenty for practical purposes.

const SplitMix64 = @This();

s: u64,

pub fn init(seed: u64) SplitMix64 {
    return SplitMix64{ .s = seed };
}

pub fn next(self: *SplitMix64) u64 {
    self.s +%= 0x9e3779b97f4a7c15;

    var z = self.s;
    z = (z ^ (z >> 30)) *% 0xbf58476d1ce4e5b9;
    z = (z ^ (z >> 27)) *% 0x94d049bb133111eb;
    return z ^ (z >> 31);
}
