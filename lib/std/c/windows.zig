// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
pub extern "c" fn _errno() *c_int;

pub extern "c" fn _msize(memblock: ?*c_void) usize;
