// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
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
