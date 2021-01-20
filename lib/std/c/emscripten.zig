// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
pub const pthread_mutex_t = extern struct {
    size: [__SIZEOF_PTHREAD_MUTEX_T]u8 align(4) = [_]u8{0} ** __SIZEOF_PTHREAD_MUTEX_T,
};
pub const pthread_cond_t = extern struct {
    size: [__SIZEOF_PTHREAD_COND_T]u8 align(@alignOf(usize)) = [_]u8{0} ** __SIZEOF_PTHREAD_COND_T,
};
pub const pthread_rwlock_t = extern struct {
    size: [32]u8 align(4) = [_]u8{0} ** 32,
};
const __SIZEOF_PTHREAD_COND_T = 48;
const __SIZEOF_PTHREAD_MUTEX_T = 28;
