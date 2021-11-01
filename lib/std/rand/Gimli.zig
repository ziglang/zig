//! CSPRNG

const std = @import("std");
const Random = std.rand.Random;
const mem = std.mem;
const Gimli = @This();

state: std.crypto.core.Gimli,

pub const secret_seed_length = 32;

/// The seed must be uniform, secret and `secret_seed_length` bytes long.
pub fn init(secret_seed: [secret_seed_length]u8) Gimli {
    var initial_state: [std.crypto.core.Gimli.BLOCKBYTES]u8 = undefined;
    mem.copy(u8, initial_state[0..secret_seed_length], &secret_seed);
    mem.set(u8, initial_state[secret_seed_length..], 0);
    var self = Gimli{
        .state = std.crypto.core.Gimli.init(initial_state),
    };
    return self;
}

pub fn random(self: *Gimli) Random {
    return Random.init(self, fill);
}

pub fn fill(self: *Gimli, buf: []u8) void {
    if (buf.len != 0) {
        self.state.squeeze(buf);
    } else {
        self.state.permute();
    }
    mem.set(u8, self.state.toSlice()[0..std.crypto.core.Gimli.RATE], 0);
}
