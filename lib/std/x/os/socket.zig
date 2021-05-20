// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const net = @import("net.zig");

const os = std.os;
const fmt = std.fmt;
const mem = std.mem;
const time = std.time;
const builtin = std.builtin;

/// A generic, cross-platform socket abstraction.
pub const Socket = struct {
    /// A socket-address pair.
    pub const Connection = struct {
        socket: Socket,
        address: Socket.Address,

        /// Enclose a socket and address into a socket-address pair.
        pub fn from(socket: Socket, address: Socket.Address) Socket.Connection {
            return .{ .socket = socket, .address = address };
        }
    };

    /// A generic socket address abstraction. It is safe to directly access and modify
    /// the fields of a `Socket.Address`.
    pub const Address = union(enum) {
        ipv4: net.IPv4.Address,
        ipv6: net.IPv6.Address,

        /// Instantiate a new address with a IPv4 host and port.
        pub fn initIPv4(host: net.IPv4, port: u16) Socket.Address {
            return .{ .ipv4 = .{ .host = host, .port = port } };
        }

        /// Instantiate a new address with a IPv6 host and port.
        pub fn initIPv6(host: net.IPv6, port: u16) Socket.Address {
            return .{ .ipv6 = .{ .host = host, .port = port } };
        }

        /// Parses a `sockaddr` into a generic socket address.
        pub fn fromNative(address: *align(4) const os.sockaddr) Socket.Address {
            switch (address.family) {
                os.AF_INET => {
                    const info = @ptrCast(*const os.sockaddr_in, address);
                    const host = net.IPv4{ .octets = @bitCast([4]u8, info.addr) };
                    const port = mem.bigToNative(u16, info.port);
                    return Socket.Address.initIPv4(host, port);
                },
                os.AF_INET6 => {
                    const info = @ptrCast(*const os.sockaddr_in6, address);
                    const host = net.IPv6{ .octets = info.addr, .scope_id = info.scope_id };
                    const port = mem.bigToNative(u16, info.port);
                    return Socket.Address.initIPv6(host, port);
                },
                else => unreachable,
            }
        }

        /// Encodes a generic socket address into an extern union that may be reliably
        /// casted into a `sockaddr` which may be passed into socket syscalls.
        pub fn toNative(self: Socket.Address) extern union {
            ipv4: os.sockaddr_in,
            ipv6: os.sockaddr_in6,
        } {
            return switch (self) {
                .ipv4 => |address| .{
                    .ipv4 = .{
                        .addr = @bitCast(u32, address.host.octets),
                        .port = mem.nativeToBig(u16, address.port),
                    },
                },
                .ipv6 => |address| .{
                    .ipv6 = .{
                        .addr = address.host.octets,
                        .port = mem.nativeToBig(u16, address.port),
                        .scope_id = address.host.scope_id,
                        .flowinfo = 0,
                    },
                },
            };
        }

        /// Returns the number of bytes that make up the `sockaddr` equivalent to the address. 
        pub fn getNativeSize(self: Socket.Address) u32 {
            return switch (self) {
                .ipv4 => @sizeOf(os.sockaddr_in),
                .ipv6 => @sizeOf(os.sockaddr_in6),
            };
        }

        /// Implements the `std.fmt.format` API.
        pub fn format(
            self: Socket.Address,
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

    /// The underlying handle of a socket.
    fd: os.socket_t,

    /// Enclose a socket abstraction over an existing socket file descriptor.
    pub fn from(fd: os.socket_t) Socket {
        return Socket{ .fd = fd };
    }

    /// Mix in socket syscalls depending on the platform we are compiling against.
    pub usingnamespace switch (builtin.os.tag) {
        .windows => @import("socket_windows.zig"),
        else => @import("socket_posix.zig"),
    }.Mixin(Socket);
};
