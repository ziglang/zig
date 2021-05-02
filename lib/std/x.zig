// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("std.zig");

pub const os = struct {
    pub const Socket = @import("x/os/Socket.zig");
    pub usingnamespace @import("x/os/net.zig");
};

pub const net = struct {
    pub const ip = @import("x/net/ip.zig");
    pub const tcp = @import("x/net/tcp.zig");
};

test {
    inline for (.{ os, net }) |module| {
        std.testing.refAllDecls(module);
    }
}
