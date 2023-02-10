//! CSPRNG

const std = @import("std");
const Random = std.rand.Random;
const min = std.math.min;
const mem = std.mem;
const Xoodoo = @This();

const State = std.crypto.core.Xoodoo;

state: State,

const rate = 16;
pub const secret_seed_length = 32;

/// The seed must be uniform, secret and `secret_seed_length` bytes long.
pub fn init(secret_seed: [secret_seed_length]u8) Xoodoo {
    var initial_state: [State.block_bytes]u8 = undefined;
    mem.copy(u8, initial_state[0..secret_seed_length], &secret_seed);
    mem.set(u8, initial_state[secret_seed_length..], 0);
    var state = State.init(initial_state);
    state.permute();
    return Xoodoo{ .state = state };
}

pub fn random(self: *Xoodoo) Random {
    return Random.init(self, fill);
}

pub fn fill(self: *Xoodoo, buf: []u8) void {
    var i: usize = 0;
    while (true) {
        const left = buf.len - i;
        const n = min(left, rate);
        self.state.extract(buf[i..][0..n]);
        if (left == 0) break;
        self.state.permute();
        i += n;
    }
    self.state.clear(0, rate);
    self.state.permute();
}
