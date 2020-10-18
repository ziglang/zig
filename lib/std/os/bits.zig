// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//! Platform-dependent types and values that are used along with OS-specific APIs.
//! These are imported into `std.c`, `std.os`, and `std.os.linux`.
//! Root source files can define `os.bits` and these will additionally be added
//! to the namespace.

const std = @import("std");
const root = @import("root");

pub usingnamespace switch (std.Target.current.os.tag) {
    .macos, .ios, .tvos, .watchos => @import("bits/darwin.zig"),
    .dragonfly => @import("bits/dragonfly.zig"),
    .freebsd => @import("bits/freebsd.zig"),
    .linux => @import("bits/linux.zig"),
    .netbsd => @import("bits/netbsd.zig"),
    .openbsd => @import("bits/openbsd.zig"),
    .wasi => @import("bits/wasi.zig"),
    .windows => @import("bits/windows.zig"),
    else => struct {},
};

pub usingnamespace if (@hasDecl(root, "os") and @hasDecl(root.os, "bits")) root.os.bits else struct {};

pub const iovec = extern struct {
    iov_base: [*]u8,
    iov_len: usize,
};

pub const iovec_const = extern struct {
    iov_base: [*]const u8,
    iov_len: usize,
};
