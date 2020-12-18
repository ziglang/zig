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

const os_has_fork = switch (std.Target.current.os.tag) {
    .dragonfly,
    .freebsd,
    .ios,
    .kfreebsd,
    .linux,
    .macos,
    .netbsd,
    .openbsd,
    .solaris,
    .tvos,
    .watchos,
    => true,

    else => false,
};
const os_has_arc4random = std.builtin.link_libc and @hasDecl(std.c, "arc4random_buf");
const want_fork_safety = os_has_fork and !os_has_arc4random and
    (std.meta.globalOption("crypto_fork_safety", bool) orelse true);
const maybe_have_wipe_on_fork = std.Target.current.os.isAtLeast(.linux, .{
    .major = 4,
    .minor = 14,
}) orelse true;

const WipeMe = struct {
    init_state: enum { uninitialized, initialized, failed },
    gimli: std.crypto.core.Gimli,
};
const wipe_align = if (maybe_have_wipe_on_fork) mem.page_size else @alignOf(WipeMe);

threadlocal var wipe_me: WipeMe align(wipe_align) = .{
    .gimli = undefined,
    .init_state = .uninitialized,
};

fn tlsCsprngFill(_: *const std.rand.Random, buffer: []u8) void {
    if (std.builtin.link_libc and @hasDecl(std.c, "arc4random_buf")) {
        // arc4random is already a thread-local CSPRNG.
        return std.c.arc4random_buf(buffer.ptr, buffer.len);
    }
    // Allow applications to decide they would prefer to have every call to
    // std.crypto.random always make an OS syscall, rather than rely on an
    // application implementation of a CSPRNG.
    if (comptime std.meta.globalOption("crypto_always_getrandom", bool) orelse false) {
        return fillWithOsEntropy(buffer);
    }
    switch (wipe_me.init_state) {
        .uninitialized => {
            if (want_fork_safety) {
                if (maybe_have_wipe_on_fork) {
                    if (std.os.madvise(
                        @ptrCast([*]align(mem.page_size) u8, &wipe_me),
                        @sizeOf(@TypeOf(wipe_me)),
                        std.os.MADV_WIPEONFORK,
                    )) |_| {
                        return initAndFill(buffer);
                    } else |_| if (std.Thread.use_pthreads) {
                        return setupPthreadAtforkAndFill(buffer);
                    } else {
                        // Since we failed to set up fork safety, we fall back to always
                        // calling getrandom every time.
                        wipe_me.init_state = .failed;
                        return fillWithOsEntropy(buffer);
                    }
                } else if (std.Thread.use_pthreads) {
                    return setupPthreadAtforkAndFill(buffer);
                } else {
                    // We have no mechanism to provide fork safety, but we want fork safety,
                    // so we fall back to calling getrandom every time.
                    wipe_me.init_state = .failed;
                    return fillWithOsEntropy(buffer);
                }
            } else {
                return initAndFill(buffer);
            }
        },
        .initialized => {
            return fillWithCsprng(buffer);
        },
        .failed => {
            if (want_fork_safety) {
                return fillWithOsEntropy(buffer);
            } else {
                unreachable;
            }
        },
    }
}

fn setupPthreadAtforkAndFill(buffer: []u8) void {
    const failed = std.c.pthread_atfork(null, null, childAtForkHandler) != 0;
    if (failed) {
        wipe_me.init_state = .failed;
        return fillWithOsEntropy(buffer);
    } else {
        return initAndFill(buffer);
    }
}

fn childAtForkHandler() callconv(.C) void {
    const wipe_slice = @ptrCast([*]u8, &wipe_me)[0..@sizeOf(@TypeOf(wipe_me))];
    std.crypto.utils.secureZero(u8, wipe_slice);
}

fn fillWithCsprng(buffer: []u8) void {
    if (buffer.len != 0) {
        wipe_me.gimli.squeeze(buffer);
    } else {
        wipe_me.gimli.permute();
    }
    mem.set(u8, wipe_me.gimli.toSlice()[0..std.crypto.core.Gimli.RATE], 0);
}

fn fillWithOsEntropy(buffer: []u8) void {
    std.os.getrandom(buffer) catch @panic("getrandom() failed to provide entropy");
}

fn initAndFill(buffer: []u8) void {
    var seed: [std.crypto.core.Gimli.BLOCKBYTES]u8 = undefined;
    // Because we panic on getrandom() failing, we provide the opportunity
    // to override the default seed function. This also makes
    // `std.crypto.random` available on freestanding targets, provided that
    // the `cryptoRandomSeed` function is provided.
    if (@hasDecl(root, "cryptoRandomSeed")) {
        root.cryptoRandomSeed(&seed);
    } else {
        fillWithOsEntropy(&seed);
    }

    wipe_me.gimli = std.crypto.core.Gimli.init(seed);

    // This is at the end so that accidental recursive dependencies result
    // in stack overflows instead of invalid random data.
    wipe_me.init_state = .initialized;

    return fillWithCsprng(buffer);
}
