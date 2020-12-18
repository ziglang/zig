// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! Thread-local cryptographically secure pseudo-random number generator.
//! This file has public declarations that are intended to be used internally
//! by the standard library; this namespace is not intended to be exposed
//! directly to standard library users.

const std = @import("std");
const root = @import("root");
const mem = std.mem;

/// We use this as a layer of indirection because global const pointers cannot
/// point to thread-local variables.
pub var interface = std.rand.Random{ .fillFn = tlsCsprngFill };
pub threadlocal var csprng_state: std.crypto.core.Gimli = undefined;
pub threadlocal var csprng_state_initialized = false;
fn tlsCsprngFill(r: *std.rand.Random, buf: []u8) void {
    if (std.builtin.link_libc and @hasDecl(std.c, "arc4random_buf")) {
        // arc4random is already a thread-local CSPRNG.
        return std.c.arc4random_buf(buf.ptr, buf.len);
    }
    if (!csprng_state_initialized) {
        var seed: [seed_len]u8 = undefined;
        // Because we panic on getrandom() failing, we provide the opportunity
        // to override the default seed function. This also makes
        // `std.crypto.random` available on freestanding targets, provided that
        // the `cryptoRandomSeed` function is provided.
        if (@hasDecl(root, "cryptoRandomSeed")) {
            root.cryptoRandomSeed(&seed);
        } else {
            defaultSeed(&seed);
        }
        init(seed);
    }
    if (buf.len != 0) {
        csprng_state.squeeze(buf);
    } else {
        csprng_state.permute();
    }
    mem.set(u8, csprng_state.toSlice()[0..std.crypto.core.Gimli.RATE], 0);
}

fn defaultSeed(buffer: *[seed_len]u8) void {
    std.os.getrandom(buffer) catch @panic("getrandom() failed to seed thread-local CSPRNG");
}

pub const seed_len = 32;

pub fn init(seed: [seed_len]u8) void {
    var initial_state: [std.crypto.core.Gimli.BLOCKBYTES]u8 = undefined;
    mem.copy(u8, initial_state[0..seed_len], &seed);
    mem.set(u8, initial_state[seed_len..], 0);
    csprng_state = std.crypto.core.Gimli.init(initial_state);

    // This is at the end so that accidental recursive dependencies result
    // in stack overflows instead of invalid random data.
    csprng_state_initialized = true;
}
