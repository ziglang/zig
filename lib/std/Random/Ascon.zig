//! CSPRNG based on the Reverie construction, a permutation-based PRNG
//! with forward security, instantiated with the Ascon(128,12,8) permutation.
//!
//! Compared to ChaCha, this PRNG has a much smaller state, and can be
//! a better choice for constrained environments.
//!
//! References:
//! - A Robust and Sponge-Like PRNG with Improved Efficiency https://eprint.iacr.org/2016/886.pdf
//! - Ascon https://ascon.iaik.tugraz.at/files/asconv12-nist.pdf

const std = @import("std");
const mem = std.mem;
const Self = @This();

const Ascon = std.crypto.core.Ascon(.little);

state: Ascon,

const rate = 16;
pub const secret_seed_length = 32;

/// The seed must be uniform, secret and `secret_seed_length` bytes long.
pub fn init(secret_seed: [secret_seed_length]u8) Self {
    var self = Self{ .state = Ascon.initXof() };
    self.addEntropy(&secret_seed);
    return self;
}

/// Inserts entropy to refresh the internal state.
pub fn addEntropy(self: *Self, bytes: []const u8) void {
    comptime std.debug.assert(secret_seed_length % rate == 0);
    var i: usize = 0;
    while (i + rate < bytes.len) : (i += rate) {
        self.state.addBytes(bytes[i..][0..rate]);
        self.state.permuteR(8);
    }
    if (i != bytes.len) self.state.addBytes(bytes[i..]);
    self.state.permute();
}

/// Returns a `std.Random` structure backed by the current RNG.
pub fn random(self: *Self) std.Random {
    return std.Random.init(self, fill);
}

/// Fills the buffer with random bytes.
pub fn fill(self: *Self, buf: []u8) void {
    var i: usize = 0;
    while (true) {
        const left = buf.len - i;
        const n = @min(left, rate);
        self.state.extractBytes(buf[i..][0..n]);
        if (left == 0) break;
        self.state.permuteR(8);
        i += n;
    }
    self.state.permuteRatchet(6, rate);
}
