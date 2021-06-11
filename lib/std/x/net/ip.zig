// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");

const fmt = std.fmt;

const IPv4 = std.x.os.IPv4;
const IPv6 = std.x.os.IPv6;
const Socket = std.x.os.Socket;

/// A generic IP abstraction.
const ip = @This();

/// A union of all eligible types of IP addresses.
pub const Address = union(enum) {
    ipv4: IPv4.Address,
    ipv6: IPv6.Address,

    /// Instantiate a new address with a IPv4 host and port.
    pub fn initIPv4(host: IPv4, port: u16) Address {
        return .{ .ipv4 = .{ .host = host, .port = port } };
    }

    /// Instantiate a new address with a IPv6 host and port.
    pub fn initIPv6(host: IPv6, port: u16) Address {
        return .{ .ipv6 = .{ .host = host, .port = port } };
    }

    /// Re-interpret a generic socket address into an IP address.
    pub fn from(address: Socket.Address) ip.Address {
        return switch (address) {
            .ipv4 => |ipv4_address| .{ .ipv4 = ipv4_address },
            .ipv6 => |ipv6_address| .{ .ipv6 = ipv6_address },
        };
    }

    /// Re-interpret an IP address into a generic socket address.
    pub fn into(self: ip.Address) Socket.Address {
        return switch (self) {
            .ipv4 => |ipv4_address| .{ .ipv4 = ipv4_address },
            .ipv6 => |ipv6_address| .{ .ipv6 = ipv6_address },
        };
    }

    /// Implements the `std.fmt.format` API.
    pub fn format(
        self: ip.Address,
        comptime layout: []const u8,
        opts: fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .ipv4 => |address| try fmt.format(writer, "{}:{}", .{ address.host, address.port }),
            .ipv6 => |address| try fmt.format(writer, "{}:{}", .{ address.host, address.port }),
        }
    }
};
