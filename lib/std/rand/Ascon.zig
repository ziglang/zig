//! CSPRNG based on the Ascon XOFa construction

const std = @import("std");
const min = std.math.min;
const mem = std.mem;
const Random = std.rand.Random;
const Self = @This();

state: std.crypto.core.Ascon(.Little),

const rate = 8;
pub const secret_seed_length = 32;

/// The seed must be uniform, secret and `secret_seed_length` bytes long.
pub fn init(secret_seed: [secret_seed_length]u8) Self {
    var state = std.crypto.core.Ascon(.Little).initXofA();
    var i: usize = 0;
    while (i + rate <= secret_seed.len) : (i += rate) {
        state.addBytes(secret_seed[i..][0..rate]);
        state.permuteR(8);
    }
    const left = secret_seed.len - i;
    if (left > 0) state.addBytes(secret_seed[i..]);
    state.addByte(0x80, left);
    state.permute();
    return Self{ .state = state };
}

pub fn random(self: *Self) Random {
    return Random.init(self, fill);
}

pub fn fill(self: *Self, buf: []u8) void {
    var i: usize = 0;
    while (true) {
        const left = buf.len - i;
        const n = min(left, rate);
        self.state.extractBytes(buf[i..][0..n]);
        if (left == 0) break;
        self.state.permuteR(8);
        i += n;
    }
    self.state.clear(0, rate);
    self.state.permuteR(8);
}
