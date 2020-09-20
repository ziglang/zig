// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
pub extern "c" fn _errno() *c_int;

pub extern "c" fn _aligned_free(memblock: ?*c_void) void;
pub extern "c" fn _aligned_malloc(size: usize, alignment: usize) ?*c_void;
pub extern "c" fn _aligned_realloc(memblock: ?*c_void, size: usize, alignment: usize) ?*c_void;
