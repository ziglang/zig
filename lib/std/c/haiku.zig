// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//
const std = @import("../std.zig");
const builtin = std.builtin;

usingnamespace std.c;

extern "c" fn _errnop() *c_int;
pub const _errno = _errnop;

// not supported in haiku
pub extern "c" fn getdents(fd: c_int, buf_ptr: [*]u8, nbytes: usize) usize;

pub const dl_iterate_phdr_callback = fn (info: *dl_phdr_info, size: usize, data: ?*c_void) callconv(.C) c_int;
//pub extern "c" fn dl_iterate_phdr(callback: dl_iterate_phdr_callback, data: ?*c_void) c_int;

//
pub const sem_t = extern struct {
    _magic: u32,
    _kern: extern struct {
        _count: u32,
        _flags: u32,
    },
    _padding: u32,
};

pub const pthread_mutex_t = extern struct {
    flags: u32 = 0,
    lock: i32 = 0,
    unused: i32 = -42,
    owner: i32 = -1,
    owner_count: i32 = 0,
};

pub const pthread_cond_t = extern struct {
    flags: u32 = 0,
    unused: i32 = -42,
    mutex: ?*c_void = null,
    waiter_count: i32 = 0,
    lock: i32 = 0,
};
pub const pthread_rwlock_t = extern struct {
    flags: u32 = 0,
    owner: i32 = -1,
    lock_sem: i32 = 0,
    lock_count: i32 = 0,
    reader_count: i32 = 0,
    writer_count: i32 = 0,
    waiters: [2]?*c_void = [_]?*c_void{ null, null },
};
