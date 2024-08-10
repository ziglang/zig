//! Thread-local cryptographically secure pseudo-random number generator.
//! This file has public declarations that are intended to be used internally
//! by the standard library; this namespace is not intended to be exposed
//! directly to standard library users.

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const native_os = builtin.os.tag;
const posix = std.posix;

/// We use this as a layer of indirection because global const pointers cannot
/// point to thread-local variables.
pub const interface: std.Random = .{
    .ptr = undefined,
    .fillFn = tlsCsprngFill,
};

const os_has_fork = @TypeOf(posix.fork) != void;
const os_has_arc4random = builtin.link_libc and (@TypeOf(std.c.arc4random_buf) != void);
const want_fork_safety = os_has_fork and !os_has_arc4random and std.options.crypto_fork_safety;
const maybe_have_wipe_on_fork = builtin.os.isAtLeast(.linux, .{
    .major = 4,
    .minor = 14,
    .patch = 0,
}) orelse true;

const Rng = std.Random.DefaultCsprng;

const Context = struct {
    init_state: enum(u8) { uninitialized = 0, initialized, failed },
    rng: Rng,
};

var install_atfork_handler = std.once(struct {
    // Install the global handler only once.
    // The same handler is shared among threads and is inherinted by fork()-ed
    // processes.
    fn do() void {
        const r = std.c.pthread_atfork(null, null, childAtForkHandler);
        std.debug.assert(r == 0);
    }
}.do);

threadlocal var wipe_mem: []align(mem.page_size) u8 = &[_]u8{};

fn tlsCsprngFill(_: *anyopaque, buffer: []u8) void {
    if (os_has_arc4random) {
        // arc4random is already a thread-local CSPRNG.
        return std.c.arc4random_buf(buffer.ptr, buffer.len);
    }
    // Allow applications to decide they would prefer to have every call to
    // std.crypto.random always make an OS syscall, rather than rely on an
    // application implementation of a CSPRNG.
    if (std.options.crypto_always_getrandom) {
        return defaultRandomSeed(buffer);
    }

    if (wipe_mem.len == 0) {
        // Not initialized yet.
        if (want_fork_safety and maybe_have_wipe_on_fork) {
            // Allocate a per-process page, madvise operates with page
            // granularity.
            wipe_mem = posix.mmap(
                null,
                @sizeOf(Context),
                posix.PROT.READ | posix.PROT.WRITE,
                .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
                -1,
                0,
            ) catch {
                // Could not allocate memory for the local state, fall back to
                // the OS syscall.
                return std.options.cryptoRandomSeed(buffer);
            };
            // The memory is already zero-initialized.
        } else {
            // Use a static thread-local buffer.
            const S = struct {
                threadlocal var buf: Context align(mem.page_size) = .{
                    .init_state = .uninitialized,
                    .rng = undefined,
                };
            };
            wipe_mem = mem.asBytes(&S.buf);
        }
    }
    const ctx = @as(*Context, @ptrCast(wipe_mem.ptr));

    switch (ctx.init_state) {
        .uninitialized => {
            if (!want_fork_safety) {
                return initAndFill(buffer);
            }

            if (maybe_have_wipe_on_fork) wof: {
                // Qemu user-mode emulation ignores any valid/invalid madvise
                // hint and returns success. Check if this is the case by
                // passing bogus parameters, we expect EINVAL as result.
                if (posix.madvise(wipe_mem.ptr, 0, 0xffffffff)) |_| {
                    break :wof;
                } else |_| {}

                if (posix.madvise(wipe_mem.ptr, wipe_mem.len, posix.MADV.WIPEONFORK)) |_| {
                    return initAndFill(buffer);
                } else |_| {}
            }

            if (std.Thread.use_pthreads) {
                return setupPthreadAtforkAndFill(buffer);
            }

            // Since we failed to set up fork safety, we fall back to always
            // calling getrandom every time.
            ctx.init_state = .failed;
            return std.options.cryptoRandomSeed(buffer);
        },
        .initialized => {
            return fillWithCsprng(buffer);
        },
        .failed => {
            if (want_fork_safety) {
                return std.options.cryptoRandomSeed(buffer);
            } else {
                unreachable;
            }
        },
    }
}

fn setupPthreadAtforkAndFill(buffer: []u8) void {
    install_atfork_handler.call();
    return initAndFill(buffer);
}

fn childAtForkHandler() callconv(.C) void {
    // The atfork handler is global, this function may be called after
    // fork()-ing threads that never initialized the CSPRNG context.
    if (wipe_mem.len == 0) return;
    std.crypto.secureZero(u8, wipe_mem);
}

fn fillWithCsprng(buffer: []u8) void {
    const ctx = @as(*Context, @ptrCast(wipe_mem.ptr));
    return ctx.rng.fill(buffer);
}

pub fn defaultRandomSeed(buffer: []u8) void {
    posix.getrandom(buffer) catch @panic("getrandom() failed to provide entropy");
}

fn initAndFill(buffer: []u8) void {
    var seed: [Rng.secret_seed_length]u8 = undefined;
    // Because we panic on getrandom() failing, we provide the opportunity
    // to override the default seed function. This also makes
    // `std.crypto.random` available on freestanding targets, provided that
    // the `std.options.cryptoRandomSeed` function is provided.
    std.options.cryptoRandomSeed(&seed);

    const ctx = @as(*Context, @ptrCast(wipe_mem.ptr));
    ctx.rng = Rng.init(seed);
    std.crypto.secureZero(u8, &seed);

    // This is at the end so that accidental recursive dependencies result
    // in stack overflows instead of invalid random data.
    ctx.init_state = .initialized;

    return fillWithCsprng(buffer);
}
