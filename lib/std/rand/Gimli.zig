// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! CSPRNG

const std = @import("std");
const Random = std.rand.Random;
const mem = std.mem;
const Gimli = @This();

random: Random,
state: std.crypto.core.Gimli,

pub const secret_seed_length = 32;

/// The seed must be uniform, secret and `secret_seed_length` bytes long.
pub fn init(secret_seed: [secret_seed_length]u8) Gimli {
    var initial_state: [std.crypto.core.Gimli.BLOCKBYTES]u8 = undefined;
    mem.copy(u8, initial_state[0..secret_seed_length], &secret_seed);
    mem.set(u8, initial_state[secret_seed_length..], 0);
    var self = Gimli{
        .random = Random{ .fillFn = fill },
        .state = std.crypto.core.Gimli.init(initial_state),
    };
    return self;
}

fn fill(r: *Random, buf: []u8) void {
    const self = @fieldParentPtr(Gimli, "random", r);

    if (buf.len != 0) {
        self.state.squeeze(buf);
    } else {
        self.state.permute();
    }
    mem.set(u8, self.state.toSlice()[0..std.crypto.core.Gimli.RATE], 0);
}
