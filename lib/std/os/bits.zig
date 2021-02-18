// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
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

// syslog

/// system is unusable
pub const LOG_EMERG = 0;
/// action must be taken immediately
pub const LOG_ALERT = 1;
/// critical conditions
pub const LOG_CRIT = 2;
/// error conditions
pub const LOG_ERR = 3;
/// warning conditions
pub const LOG_WARNING = 4;
/// normal but significant condition
pub const LOG_NOTICE = 5;
/// informational
pub const LOG_INFO = 6;
/// debug-level messages
pub const LOG_DEBUG = 7;

// `ar` archive file format definitions

pub usingnamespace if (std.Target.current.os.tag == .windows) struct {} else struct {
    // Archive files start with the ARMAG identifying string.  Then follows a
    // `struct ar_hdr', and as many bytes of member file data as its `ar_size'
    // member indicates, for each member file.
    /// String that begins an archive file.
    pub const ARMAG: *const [SARMAG:0]u8 = "!<arch>\n";

    /// Size of that string.
    pub const SARMAG: u4 = 8;

    /// String in ar_fmag at the end of each header.
    pub const ARFMAG: *const [2:0]u8 = "`\n";

    pub const ar_hdr = extern struct {
        /// Member file name, sometimes / terminated.
        ar_name: [16]u8,

        /// File date, decimal seconds since Epoch.
        ar_date: [12]u8,

        /// User ID, in ASCII format.
        ar_uid: [6]u8,

        /// Group ID, in ASCII format.
        ar_gid: [6]u8,

        /// File mode, in ASCII octal.
        ar_mode: [8]u8,

        /// File size, in ASCII decimal.
        ar_size: [10]u8,

        /// Always contains ARFMAG.
        ar_fmag: [2]u8,
    };
};
