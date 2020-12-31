// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
pub const pthread_mutex_t = extern struct {
    __pthread_mutex_flag1: u16 = 0,
    __pthread_mutex_flag2: u8 = 0,
    __pthread_mutex_ceiling: u8 = 0,
    __pthread_mutex_type: u16 = 0,
    __pthread_mutex_magic: u16 = 0x4d58,
    __pthread_mutex_lock: u64 = 0,
    __pthread_mutex_data: u64 = 0,
};
pub const pthread_cond_t = extern struct {
    __pthread_cond_flag: u32 = 0,
    __pthread_cond_type: u16 = 0,
    __pthread_cond_magic: u16 = 0x4356,
    __pthread_cond_data: u64 = 0,
};
