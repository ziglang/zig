// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const net = @This();
const mem = std.mem;
const os = std.os;
const fs = std.fs;
const io = std.io;

const windows = os.windows;
const ws2_32 = os.windows.ws2_32;

const dns = @import("net/dns.zig");

const is_windows = builtin.os.tag == .windows;

// Windows 10 added support for unix sockets in build 17063, redstone 4 is the
// first release to support them.
pub const has_unix_sockets = @hasDecl(os, "sockaddr_un") and
    (builtin.os.tag != .windows or
    std.Target.current.os.version_range.windows.isAtLeast(.win10_rs4) orelse false);

// Platform-independent socket descriptor.
// Note that on some platforms this may not be interchangeable with a regular
// files descriptor.
pub const Socket = extern struct {
    handle: os.socket_t,
};

fn setSocketNonBlocking(handle: os.socket_t, nonblocking: bool) !void {
    if (is_windows) {
        var mode: c_ulong = @boolToInt(nonblocking);
        if (ws2_32.ioctlsocket(handle, ws2_32.FIONBIO, &mode) == ws2_32.SOCKET_ERROR)
            return windows.unexpectedWSAError(ws2_32.WSAGetLastError());
        return;
    }

    var fl_flags = os.fcntl(handle, os.F_GETFL, 0) catch |err| switch (err) {
        error.FileBusy => unreachable,
        error.Locked => unreachable,
        error.PermissionDenied => unreachable,
        error.ProcessFdQuotaExceeded => unreachable,
        else => |e| return e,
    };
    if (nonblocking) {
        fl_flags |= os.O_NONBLOCK;
    } else {
        fl_flags &= ~@as(u32, os.O_NONBLOCK);
    }
    _ = os.fcntl(handle, os.F_SETFL, fl_flags) catch |err| switch (err) {
        error.FileBusy => unreachable,
        error.Locked => unreachable,
        error.PermissionDenied => unreachable,
        error.ProcessFdQuotaExceeded => unreachable,
        else => |e| return e,
    };
}

pub const Address = extern union {
    any: os.sockaddr,
    in: Ip4Address,
    in6: Ip6Address,
    un: if (has_unix_sockets) os.sockaddr_un else void,

    /// Parse the given IP address string into an Address value.
    /// It is recommended to use `resolveIp` instead, to handle
    /// IPv6 link-local unix addresses.
    pub fn parseIp(name: []const u8, port: u16) !Address {
        if (parseIp4(name, port)) |ip4| return ip4 else |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            => {},
        }

        if (parseIp6(name, port)) |ip6| return ip6 else |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            error.InvalidIpv4Mapping,
            => {},
        }

        return error.InvalidIPAddressFormat;
    }

    pub fn resolveIp(name: []const u8, port: u16) !Address {
        if (parseIp4(name, port)) |ip4| return ip4 else |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            => {},
        }

        if (resolveIp6(name, port)) |ip6| return ip6 else |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            error.InvalidIpv4Mapping,
            => {},
            else => return err,
        }

        return error.InvalidIPAddressFormat;
    }

    pub fn parseExpectingFamily(name: []const u8, family: os.sa_family_t, port: u16) !Address {
        switch (family) {
            os.AF_INET => return parseIp4(name, port),
            os.AF_INET6 => return parseIp6(name, port),
            os.AF_UNSPEC => return parseIp(name, port),
            else => unreachable,
        }
    }

    pub fn parseIp6(buf: []const u8, port: u16) !Address {
        return Address{ .in6 = try Ip6Address.parse(buf, port) };
    }

    pub fn resolveIp6(buf: []const u8, port: u16) !Address {
        return Address{ .in6 = try Ip6Address.resolve(buf, port) };
    }

    pub fn parseIp4(buf: []const u8, port: u16) !Address {
        return Address{ .in = try Ip4Address.parse(buf, port) };
    }

    pub fn initIp4(addr: [4]u8, port: u16) Address {
        return Address{ .in = Ip4Address.init(addr, port) };
    }

    pub fn initIp6(addr: [16]u8, port: u16, flowinfo: u32, scope_id: u32) Address {
        return Address{ .in6 = Ip6Address.init(addr, port, flowinfo, scope_id) };
    }

    pub fn initUnix(path: []const u8) !Address {
        var sock_addr = os.sockaddr_un{
            .family = os.AF_UNIX,
            .path = undefined,
        };

        // this enables us to have the proper length of the socket in getOsSockLen
        mem.set(u8, &sock_addr.path, 0);

        if (path.len > sock_addr.path.len) return error.NameTooLong;
        mem.copy(u8, &sock_addr.path, path);

        return Address{ .un = sock_addr };
    }

    /// Returns the port in native endian.
    /// Asserts that the address is ip4 or ip6.
    pub fn getPort(self: Address) u16 {
        return switch (self.any.family) {
            os.AF_INET => self.in.getPort(),
            os.AF_INET6 => self.in6.getPort(),
            else => unreachable,
        };
    }

    /// `port` is native-endian.
    /// Asserts that the address is ip4 or ip6.
    pub fn setPort(self: *Address, port: u16) void {
        switch (self.any.family) {
            os.AF_INET => self.in.setPort(port),
            os.AF_INET6 => self.in6.setPort(port),
            else => unreachable,
        }
    }

    /// Asserts that `addr` is an IP address.
    /// This function will read past the end of the pointer, with a size depending
    /// on the address family.
    pub fn initPosix(addr: *align(4) const os.sockaddr) Address {
        switch (addr.family) {
            os.AF_INET => return Address{ .in = Ip4Address{ .sa = @ptrCast(*const os.sockaddr_in, addr).* } },
            os.AF_INET6 => return Address{ .in6 = Ip6Address{ .sa = @ptrCast(*const os.sockaddr_in6, addr).* } },
            else => unreachable,
        }
    }

    pub fn format(
        self: Address,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        switch (self.any.family) {
            os.AF_INET => try self.in.format(fmt, options, out_stream),
            os.AF_INET6 => try self.in6.format(fmt, options, out_stream),
            os.AF_UNIX => {
                if (!has_unix_sockets) {
                    unreachable;
                }

                try std.fmt.format(out_stream, "{s}", .{&self.un.path});
            },
            else => unreachable,
        }
    }

    pub fn eql(a: Address, b: Address) bool {
        const a_bytes = @ptrCast([*]const u8, &a.any)[0..a.getOsSockLen()];
        const b_bytes = @ptrCast([*]const u8, &b.any)[0..b.getOsSockLen()];
        return mem.eql(u8, a_bytes, b_bytes);
    }

    pub fn getOsSockLen(self: Address) os.socklen_t {
        switch (self.any.family) {
            os.AF_INET => return self.in.getOsSockLen(),
            os.AF_INET6 => return self.in6.getOsSockLen(),
            os.AF_UNIX => {
                if (!has_unix_sockets) {
                    unreachable;
                }

                const path_len = std.mem.len(std.meta.assumeSentinel(&self.un.path, 0));
                return @intCast(os.socklen_t, @sizeOf(os.sockaddr_un) - self.un.path.len + path_len);
            },
            else => unreachable,
        }
    }
};

pub const Ip4Address = extern struct {
    sa: os.sockaddr_in,

    pub fn parse(buf: []const u8, port: u16) !Ip4Address {
        var result = Ip4Address{
            .sa = .{
                .port = mem.nativeToBig(u16, port),
                .addr = undefined,
            },
        };
        const out_ptr = mem.asBytes(&result.sa.addr);

        var x: u8 = 0;
        var index: u8 = 0;
        var saw_any_digits = false;
        for (buf) |c| {
            if (c == '.') {
                if (!saw_any_digits) {
                    return error.InvalidCharacter;
                }
                if (index == 3) {
                    return error.InvalidEnd;
                }
                out_ptr[index] = x;
                index += 1;
                x = 0;
                saw_any_digits = false;
            } else if (c >= '0' and c <= '9') {
                saw_any_digits = true;
                x = try std.math.mul(u8, x, 10);
                x = try std.math.add(u8, x, c - '0');
            } else {
                return error.InvalidCharacter;
            }
        }
        if (index == 3 and saw_any_digits) {
            out_ptr[index] = x;
            return result;
        }

        return error.Incomplete;
    }

    pub fn resolveIp(name: []const u8, port: u16) !Ip4Address {
        if (parse(name, port)) |ip4| return ip4 else |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            => {},
        }
        return error.InvalidIPAddressFormat;
    }

    pub fn init(addr: [4]u8, port: u16) Ip4Address {
        return Ip4Address{
            .sa = os.sockaddr_in{
                .port = mem.nativeToBig(u16, port),
                .addr = @ptrCast(*align(1) const u32, &addr).*,
            },
        };
    }

    /// Returns the port in native endian.
    /// Asserts that the address is ip4 or ip6.
    pub fn getPort(self: Ip4Address) u16 {
        return mem.bigToNative(u16, self.sa.port);
    }

    /// `port` is native-endian.
    /// Asserts that the address is ip4 or ip6.
    pub fn setPort(self: *Ip4Address, port: u16) void {
        self.sa.port = mem.nativeToBig(u16, port);
    }

    pub fn format(
        self: Ip4Address,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        const bytes = @ptrCast(*const [4]u8, &self.sa.addr);
        try std.fmt.format(out_stream, "{}.{}.{}.{}:{}", .{
            bytes[0],
            bytes[1],
            bytes[2],
            bytes[3],
            self.getPort(),
        });
    }

    pub fn getOsSockLen(self: Ip4Address) os.socklen_t {
        return @sizeOf(os.sockaddr_in);
    }
};

pub const Ip6Address = extern struct {
    sa: os.sockaddr_in6,

    /// Parse a given IPv6 address string into an Address.
    /// Assumes the Scope ID of the address is fully numeric.
    /// For non-numeric addresses, see `resolveIp6`.
    pub fn parse(buf: []const u8, port: u16) !Ip6Address {
        var result = Ip6Address{
            .sa = os.sockaddr_in6{
                .scope_id = 0,
                .port = mem.nativeToBig(u16, port),
                .flowinfo = 0,
                .addr = undefined,
            },
        };
        var ip_slice = result.sa.addr[0..];

        var tail: [16]u8 = undefined;

        var x: u16 = 0;
        var saw_any_digits = false;
        var index: u8 = 0;
        var scope_id = false;
        var abbrv = false;
        for (buf) |c, i| {
            if (scope_id) {
                if (c >= '0' and c <= '9') {
                    const digit = c - '0';
                    if (@mulWithOverflow(u32, result.sa.scope_id, 10, &result.sa.scope_id)) {
                        return error.Overflow;
                    }
                    if (@addWithOverflow(u32, result.sa.scope_id, digit, &result.sa.scope_id)) {
                        return error.Overflow;
                    }
                } else {
                    return error.InvalidCharacter;
                }
            } else if (c == ':') {
                if (!saw_any_digits) {
                    if (abbrv) return error.InvalidCharacter; // ':::'
                    if (i != 0) abbrv = true;
                    mem.set(u8, ip_slice[index..], 0);
                    ip_slice = tail[0..];
                    index = 0;
                    continue;
                }
                if (index == 14) {
                    return error.InvalidEnd;
                }
                ip_slice[index] = @truncate(u8, x >> 8);
                index += 1;
                ip_slice[index] = @truncate(u8, x);
                index += 1;

                x = 0;
                saw_any_digits = false;
            } else if (c == '%') {
                if (!saw_any_digits) {
                    return error.InvalidCharacter;
                }
                scope_id = true;
                saw_any_digits = false;
            } else if (c == '.') {
                if (!abbrv or ip_slice[0] != 0xff or ip_slice[1] != 0xff) {
                    // must start with '::ffff:'
                    return error.InvalidIpv4Mapping;
                }
                const start_index = mem.lastIndexOfScalar(u8, buf[0..i], ':').? + 1;
                const addr = (Ip4Address.parse(buf[start_index..], 0) catch {
                    return error.InvalidIpv4Mapping;
                }).sa.addr;
                ip_slice = result.sa.addr[0..];
                ip_slice[10] = 0xff;
                ip_slice[11] = 0xff;

                const ptr = mem.sliceAsBytes(@as(*const [1]u32, &addr)[0..]);

                ip_slice[12] = ptr[0];
                ip_slice[13] = ptr[1];
                ip_slice[14] = ptr[2];
                ip_slice[15] = ptr[3];
                return result;
            } else {
                const digit = try std.fmt.charToDigit(c, 16);
                if (@mulWithOverflow(u16, x, 16, &x)) {
                    return error.Overflow;
                }
                if (@addWithOverflow(u16, x, digit, &x)) {
                    return error.Overflow;
                }
                saw_any_digits = true;
            }
        }

        if (!saw_any_digits and !abbrv) {
            return error.Incomplete;
        }

        if (index == 14) {
            ip_slice[14] = @truncate(u8, x >> 8);
            ip_slice[15] = @truncate(u8, x);
            return result;
        } else {
            ip_slice[index] = @truncate(u8, x >> 8);
            index += 1;
            ip_slice[index] = @truncate(u8, x);
            index += 1;
            mem.copy(u8, result.sa.addr[16 - index ..], ip_slice[0..index]);
            return result;
        }
    }

    pub fn resolve(buf: []const u8, port: u16) !Ip6Address {
        // TODO: Unify the implementations of resolveIp6 and parseIp6.
        var result = Ip6Address{
            .sa = os.sockaddr_in6{
                .scope_id = 0,
                .port = mem.nativeToBig(u16, port),
                .flowinfo = 0,
                .addr = undefined,
            },
        };
        var ip_slice = result.sa.addr[0..];

        var tail: [16]u8 = undefined;

        var x: u16 = 0;
        var saw_any_digits = false;
        var index: u8 = 0;
        var abbrv = false;

        var scope_id = false;
        var scope_id_value: [os.IFNAMESIZE - 1]u8 = undefined;
        var scope_id_index: usize = 0;

        for (buf) |c, i| {
            if (scope_id) {
                // Handling of percent-encoding should be for an URI library.
                if ((c >= '0' and c <= '9') or
                    (c >= 'A' and c <= 'Z') or
                    (c >= 'a' and c <= 'z') or
                    (c == '-') or (c == '.') or (c == '_') or (c == '~'))
                {
                    if (scope_id_index >= scope_id_value.len) {
                        return error.Overflow;
                    }

                    scope_id_value[scope_id_index] = c;
                    scope_id_index += 1;
                } else {
                    return error.InvalidCharacter;
                }
            } else if (c == ':') {
                if (!saw_any_digits) {
                    if (abbrv) return error.InvalidCharacter; // ':::'
                    if (i != 0) abbrv = true;
                    mem.set(u8, ip_slice[index..], 0);
                    ip_slice = tail[0..];
                    index = 0;
                    continue;
                }
                if (index == 14) {
                    return error.InvalidEnd;
                }
                ip_slice[index] = @truncate(u8, x >> 8);
                index += 1;
                ip_slice[index] = @truncate(u8, x);
                index += 1;

                x = 0;
                saw_any_digits = false;
            } else if (c == '%') {
                if (!saw_any_digits) {
                    return error.InvalidCharacter;
                }
                scope_id = true;
                saw_any_digits = false;
            } else if (c == '.') {
                if (!abbrv or ip_slice[0] != 0xff or ip_slice[1] != 0xff) {
                    // must start with '::ffff:'
                    return error.InvalidIpv4Mapping;
                }
                const start_index = mem.lastIndexOfScalar(u8, buf[0..i], ':').? + 1;
                const addr = (Ip4Address.parse(buf[start_index..], 0) catch {
                    return error.InvalidIpv4Mapping;
                }).sa.addr;
                ip_slice = result.sa.addr[0..];
                ip_slice[10] = 0xff;
                ip_slice[11] = 0xff;

                const ptr = mem.sliceAsBytes(@as(*const [1]u32, &addr)[0..]);

                ip_slice[12] = ptr[0];
                ip_slice[13] = ptr[1];
                ip_slice[14] = ptr[2];
                ip_slice[15] = ptr[3];
                return result;
            } else {
                const digit = try std.fmt.charToDigit(c, 16);
                if (@mulWithOverflow(u16, x, 16, &x)) {
                    return error.Overflow;
                }
                if (@addWithOverflow(u16, x, digit, &x)) {
                    return error.Overflow;
                }
                saw_any_digits = true;
            }
        }

        if (!saw_any_digits and !abbrv) {
            return error.Incomplete;
        }

        if (scope_id and scope_id_index == 0) {
            return error.Incomplete;
        }

        var resolved_scope_id: u32 = 0;
        if (scope_id_index > 0) {
            const scope_id_str = scope_id_value[0..scope_id_index];
            resolved_scope_id = std.fmt.parseInt(u32, scope_id_str, 10) catch |err| blk: {
                if (err != error.InvalidCharacter) return err;
                break :blk try if_nametoindex(scope_id_str);
            };
        }

        result.sa.scope_id = resolved_scope_id;

        if (index == 14) {
            ip_slice[14] = @truncate(u8, x >> 8);
            ip_slice[15] = @truncate(u8, x);
            return result;
        } else {
            ip_slice[index] = @truncate(u8, x >> 8);
            index += 1;
            ip_slice[index] = @truncate(u8, x);
            index += 1;
            mem.copy(u8, result.sa.addr[16 - index ..], ip_slice[0..index]);
            return result;
        }
    }

    pub fn init(addr: [16]u8, port: u16, flowinfo: u32, scope_id: u32) Ip6Address {
        return Ip6Address{
            .sa = os.sockaddr_in6{
                .addr = addr,
                .port = mem.nativeToBig(u16, port),
                .flowinfo = flowinfo,
                .scope_id = scope_id,
            },
        };
    }

    /// Returns the port in native endian.
    /// Asserts that the address is ip4 or ip6.
    pub fn getPort(self: Ip6Address) u16 {
        return mem.bigToNative(u16, self.sa.port);
    }

    /// `port` is native-endian.
    /// Asserts that the address is ip4 or ip6.
    pub fn setPort(self: *Ip6Address, port: u16) void {
        self.sa.port = mem.nativeToBig(u16, port);
    }

    pub fn format(
        self: Ip6Address,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        const port = mem.bigToNative(u16, self.sa.port);
        if (mem.eql(u8, self.sa.addr[0..12], &[_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff })) {
            try std.fmt.format(out_stream, "[::ffff:{}.{}.{}.{}]:{}", .{
                self.sa.addr[12],
                self.sa.addr[13],
                self.sa.addr[14],
                self.sa.addr[15],
                port,
            });
            return;
        }
        const big_endian_parts = @ptrCast(*align(1) const [8]u16, &self.sa.addr);
        const native_endian_parts = switch (builtin.endian) {
            .Big => big_endian_parts.*,
            .Little => blk: {
                var buf: [8]u16 = undefined;
                for (big_endian_parts) |part, i| {
                    buf[i] = mem.bigToNative(u16, part);
                }
                break :blk buf;
            },
        };
        try out_stream.writeAll("[");
        var i: usize = 0;
        var abbrv = false;
        while (i < native_endian_parts.len) : (i += 1) {
            if (native_endian_parts[i] == 0) {
                if (!abbrv) {
                    try out_stream.writeAll(if (i == 0) "::" else ":");
                    abbrv = true;
                }
                continue;
            }
            try std.fmt.format(out_stream, "{x}", .{native_endian_parts[i]});
            if (i != native_endian_parts.len - 1) {
                try out_stream.writeAll(":");
            }
        }
        try std.fmt.format(out_stream, "]:{}", .{port});
    }

    pub fn getOsSockLen(self: Ip6Address) os.socklen_t {
        return @sizeOf(os.sockaddr_in6);
    }
};

fn if_nametoindex(name: []const u8) !u32 {
    var ifr: os.ifreq = undefined;
    var sockfd = try os.socket(os.AF_UNIX, os.SOCK_DGRAM | os.SOCK_CLOEXEC, 0);
    defer os.closeSocket(sockfd);

    std.mem.copy(u8, &ifr.ifrn.name, name);
    ifr.ifrn.name[name.len] = 0;

    // TODO investigate if this needs to be integrated with evented I/O.
    try os.ioctl_SIOCGIFINDEX(sockfd, &ifr);

    return @bitCast(u32, ifr.ifru.ivalue);
}

pub const AddressList = struct {
    arena: std.heap.ArenaAllocator,
    addrs: []Address,
    canon_name: ?[]u8,

    pub fn deinit(self: *AddressList) void {
        // Here we copy the arena allocator into stack memory, because
        // otherwise it would destroy itself while it was still working.
        var arena = self.arena;
        arena.deinit();
        // self is destroyed
    }
};

/// Call `AddressList.deinit` on the result.
pub fn getAddressList(allocator: *mem.Allocator, name: []const u8, port: u16) !*AddressList {
    const result = blk: {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        const result = try arena.allocator.create(AddressList);
        result.* = AddressList{
            .arena = arena,
            .addrs = undefined,
            .canon_name = null,
        };
        break :blk result;
    };
    const arena = &result.arena.allocator;
    errdefer result.arena.deinit();

    if (is_windows or builtin.link_libc) {
        const name_c = try std.cstr.addNullByte(allocator, name);
        defer allocator.free(name_c);

        const port_c = try std.fmt.allocPrint(allocator, "{}\x00", .{port});
        defer allocator.free(port_c);

        const sys = if (is_windows) os.windows.ws2_32 else os.system;
        const hints = os.addrinfo{
            .flags = sys.AI_NUMERICSERV,
            .family = os.AF_UNSPEC,
            .socktype = os.SOCK_STREAM,
            .protocol = os.IPPROTO_TCP,
            .canonname = null,
            .addr = null,
            .addrlen = 0,
            .next = null,
        };
        var res: *os.addrinfo = undefined;
        const rc = sys.getaddrinfo(name_c.ptr, std.meta.assumeSentinel(port_c.ptr, 0), &hints, &res);
        if (is_windows) switch (@intToEnum(os.windows.ws2_32.WinsockError, @intCast(u16, rc))) {
            @intToEnum(os.windows.ws2_32.WinsockError, 0) => {},
            .WSATRY_AGAIN => return error.TemporaryNameServerFailure,
            .WSANO_RECOVERY => return error.NameServerFailure,
            .WSAEAFNOSUPPORT => return error.AddressFamilyNotSupported,
            .WSA_NOT_ENOUGH_MEMORY => return error.OutOfMemory,
            .WSAHOST_NOT_FOUND => return error.UnknownHostName,
            .WSATYPE_NOT_FOUND => return error.ServiceUnavailable,
            .WSAEINVAL => unreachable,
            .WSAESOCKTNOSUPPORT => unreachable,
            else => |err| return os.windows.unexpectedWSAError(err),
        } else switch (rc) {
            @intToEnum(sys.EAI, 0) => {},
            .ADDRFAMILY => return error.HostLacksNetworkAddresses,
            .AGAIN => return error.TemporaryNameServerFailure,
            .BADFLAGS => unreachable, // Invalid hints
            .FAIL => return error.NameServerFailure,
            .FAMILY => return error.AddressFamilyNotSupported,
            .MEMORY => return error.OutOfMemory,
            .NODATA => return error.HostLacksNetworkAddresses,
            .NONAME => return error.UnknownHostName,
            .SERVICE => return error.ServiceUnavailable,
            .SOCKTYPE => unreachable, // Invalid socket type requested in hints
            .SYSTEM => switch (os.errno(-1)) {
                else => |e| return os.unexpectedErrno(e),
            },
            else => unreachable,
        }
        defer sys.freeaddrinfo(res);

        const addr_count = blk: {
            var count: usize = 0;
            var it: ?*os.addrinfo = res;
            while (it) |info| : (it = info.next) {
                if (info.addr != null) {
                    count += 1;
                }
            }
            break :blk count;
        };
        result.addrs = try arena.alloc(Address, addr_count);

        var it: ?*os.addrinfo = res;
        var i: usize = 0;
        while (it) |info| : (it = info.next) {
            const addr = info.addr orelse continue;
            result.addrs[i] = Address.initPosix(@alignCast(4, addr));

            if (info.canonname) |n| {
                if (result.canon_name == null) {
                    result.canon_name = try arena.dupe(u8, mem.spanZ(n));
                }
            }
            i += 1;
        }

        return result;
    }
    if (builtin.os.tag == .linux) {
        const flags = std.c.AI_NUMERICSERV;
        const family = os.AF_UNSPEC;
        var lookup_addrs = std.ArrayList(dns.LookupAddr).init(allocator);
        defer lookup_addrs.deinit();

        var canon = std.ArrayList(u8).init(arena);
        defer canon.deinit();

        try dns.linuxLookupName(&lookup_addrs, &canon, name, family, flags, port);

        result.addrs = try arena.alloc(Address, lookup_addrs.items.len);
        if (canon.items.len != 0) {
            result.canon_name = canon.toOwnedSlice();
        }

        for (lookup_addrs.items) |lookup_addr, i| {
            result.addrs[i] = lookup_addr.addr;
            assert(result.addrs[i].getPort() == port);
        }

        return result;
    }
    @compileError("std.net.getAddresses unimplemented for this OS");
}

pub const TcpClient = struct {
    socket: Socket,

    pub const ReadError = os.RecvFromError;
    pub const WriteError = os.SendError;

    pub const Reader = io.Reader(TcpClient, ReadError, read);
    pub const Writer = io.Writer(TcpClient, WriteError, write);

    pub const ConnectOptions = struct {
        /// Enable SO_REUSEPORT on the socket.
        /// This parameter is ignored on some platforms.
        reuse_port: bool = false,

        /// Enable SO_REUSEADDR on the socket.
        /// This parameter is ignored on some platforms.
        reuse_address: bool = false,

        /// Timeout in ms for a successful connection.
        /// If null the connection operation waits forever.
        timeout: ?u32 = null,
    };

    pub fn connectToHost(
        allocator: *mem.Allocator,
        name: []const u8,
        port: u16,
        options: ConnectOptions,
    ) !TcpClient {
        const list = try getAddressList(allocator, name, port);
        defer list.deinit();

        if (list.addrs.len == 0) return error.UnknownHostName;

        for (list.addrs) |addr| {
            return connectToAddress(addr) catch |err| switch (err) {
                error.ConnectionRefused => {
                    continue;
                },
                else => return err,
            };
        }

        return os.ConnectError.ConnectionRefused;
    }
    pub fn connectToAddress(
        allocator: *mem.Allocator,
        address: Address, // XXX: Accept a []Address instead?
        options: ConnectOptions,
    ) !TcpClient {
        const sock_flags = os.SOCK_STREAM |
            (if (is_windows) 0 else os.SOCK_CLOEXEC);
        const sockfd = try os.socket(address.any.family, sock_flags, os.IPPROTO_TCP);
        errdefer os.closeSocket(sockfd);

        if (comptime std.Target.current.isDarwin()) {
            // Darwin doesn't support the MSG_NOSIGNAL flag.
            try os.setsockopt(
                sockfd,
                os.SOL_SOCKET,
                os.SO_NOSIGPIPE,
                &mem.toBytes(@as(i32, 1)),
            );
        }

        if (std.io.is_async) {
            @panic("implement me");
        } else if (options.timeout) |timeout_ms| {
            try setSocketNonBlocking(sockfd, true);

            os.connect(sockfd, &address.any, address.getOsSockLen()) catch |err| switch (err) {
                error.WouldBlock => {},
                else => |e| return e,
            };
            var poll_fd = os.pollfd{
                .fd = sockfd,
                .events = os.POLLOUT | os.POLLERR,
                .revents = undefined,
            };

            const events = try os.poll(&.{poll_fd}, @bitCast(i32, timeout_ms));
            // No events are available, the connect() call timed out.
            if (events == 0)
                return error.ConnectionTimedOut;
            try setSocketNonBlocking(sockfd, false);
        } else {
            try os.connect(sockfd, &address.any, address.getOsSockLen());
        }

        return TcpClient{ .socket = .{ .handle = sockfd } };
    }

    pub fn read(self: TcpClient, buffer: []u8) ReadError!usize {
        if (std.io.is_async) {
            @panic("implement me");
        } else {
            const flags: u32 = if (@hasDecl(os, "MSG_NOSIGNAL")) os.MSG_NOSIGNAL else 0;
            return os.recv(self.socket.handle, buffer, flags);
        }
    }
    pub fn write(self: TcpClient, buffer: []const u8) WriteError!usize {
        if (std.io.is_async) {
            @panic("implement me");
        } else {
            const flags: u32 = if (@hasDecl(os, "MSG_NOSIGNAL")) os.MSG_NOSIGNAL else 0;
            return os.send(self.socket.handle, buffer, flags);
        }
    }

    pub fn shutdown(self: TcpClient, endpoint: os.ShutdownHow) !void {
        return os.shutdown(self.socket.handle, endpoint);
    }
    pub fn close(self: *TcpClient) void {
        os.closeSocket(self.socket.handle);
    }

    pub fn reader(self: TcpClient) Reader {
        return .{ .context = self };
    }
    pub fn writer(self: TcpClient) Writer {
        return .{ .context = self };
    }

    pub fn setNodelay(self: TcpClient, nodelay: bool) !void {
        try os.setsockopt(
            self.socket.handle,
            os.SOL_SOCKET,
            if (is_windows) os.TCP_NODELAY else os.SO_NODELAY,
            &mem.toBytes(@as(i32, @boolToInt(nodelay))),
        );
    }
    pub fn getNodelay(self: TcpClient) !bool {
        var value: u32 = undefined;
        _ = try os.getsockopt(
            self.socket.handle,
            os.SOL_SOCKET,
            if (is_windows) os.TCP_NODELAY else os.SO_NODELAY,
            mem.asBytes(&value),
        );
        return value != 0;
    }

    pub fn setKeepalive(self: TcpClient, keepalive: bool) !void {
        try os.setsockopt(
            self.socket.handle,
            os.SOL_SOCKET,
            os.SO_KEEPALIVE,
            &mem.toBytes(@as(i32, @boolToInt(keepalive))),
        );
    }
    pub fn getKeepalive(self: TcpClient) !bool {
        var value: u32 = undefined;
        _ = try os.getsockopt(
            self.socket.handle,
            os.SOL_SOCKET,
            os.SO_KEEPALIVE,
            mem.asBytes(&value),
        );
        return value != 0;
    }

    pub fn setReadTimeout(self: TcpClient, timeout_ms: u32) !void {
        try os.setsockopt(
            self.socket.handle,
            os.SOL_SOCKET,
            os.SO_RCVTIMEO,
            &mem.toBytes(@bitCast(i32, timeout_ms)),
        );
    }
    pub fn getReadTimeout(self: TcpClient) !u32 {
        if (is_windows) return error.Unsupported;

        var value: u32 = undefined;
        _ = try os.getsockopt(
            self.socket.handle,
            os.SOL_SOCKET,
            os.SO_RCVTIMEO,
            mem.asBytes(&value),
        );
        return value;
    }

    pub fn setWriteTimeout(self: TcpClient, timeout_ms: u32) !void {
        try os.setsockopt(
            self.socket.handle,
            os.SOL_SOCKET,
            os.SO_SNDTIMEO,
            &mem.toBytes(@bitCast(i32, timeout_ms)),
        );
    }
    pub fn getWriteTimeout(self: TcpClient) !u32 {
        if (is_windows) return error.Unsupported;

        var value: u32 = undefined;
        _ = try os.getsockopt(
            self.socket.handle,
            os.SOL_SOCKET,
            os.SO_SNDTIMEO,
            mem.asBytes(&value),
        );
        return value;
    }
};

pub const UnixClient = struct {
    socket: Socket,

    pub const ReadError = os.RecvFromError;
    pub const WriteError = os.SendError;

    pub const Reader = io.Reader(UnixClient, ReadError, read);
    pub const Writer = io.Writer(UnixClient, WriteError, write);

    pub const ConnectOptions = struct {
        //
    };

    pub fn connectToPath(
        allocator: *mem.Allocator,
        path: []const u8,
        options: ConnectOptions,
    ) !UnixClient {
        return connectToAddress(allocator, try Address.initUnix(path), options);
    }
    pub fn connectToAddress(
        allocator: *mem.Allocator,
        address: Address, // XXX: Accept a []Address instead?
        options: ConnectOptions,
    ) !UnixClient {
        const sock_flags = os.SOCK_STREAM |
            (if (is_windows) 0 else os.SOCK_CLOEXEC);
        const sockfd = try os.socket(os.AF_UNIX, sock_flags, 0);
        errdefer os.closeSocket(sockfd);

        if (comptime std.Target.current.isDarwin()) {
            // Darwin doesn't support the MSG_NOSIGNAL flag.
            try os.setsockopt(
                sockfd,
                os.SOL_SOCKET,
                os.SO_NOSIGPIPE,
                &mem.toBytes(@as(i32, 1)),
            );
        }

        if (std.io.is_async) {
            @panic("implement me");
        } else {
            try os.connect(sockfd, &address.any, address.getOsSockLen());
        }

        return UnixClient{ .socket = .{ .handle = sockfd } };
    }

    pub fn read(self: UnixClient, buffer: []u8) ReadError!usize {
        if (std.io.is_async) {
            @panic("implement me");
        } else {
            const flags: u32 = if (@hasDecl(os, "MSG_NOSIGNAL")) os.MSG_NOSIGNAL else 0;
            return os.recv(self.socket.handle, buffer, flags);
        }
    }
    pub fn write(self: UnixClient, buffer: []const u8) WriteError!usize {
        if (std.io.is_async) {
            @panic("implement me");
        } else {
            const flags: u32 = if (@hasDecl(os, "MSG_NOSIGNAL")) os.MSG_NOSIGNAL else 0;
            return os.send(self.socket.handle, buffer, flags);
        }
    }

    pub fn close(self: *UnixClient) void {
        os.closeSocket(self.socket.handle);
    }

    pub fn reader(self: UnixClient) Reader {
        return .{ .context = self };
    }
    pub fn writer(self: UnixClient) Writer {
        return .{ .context = self };
    }
};

pub const UdpClient = struct {
    socket: Socket,
    is_bound: bool,

    pub const ConnectOptions = struct {
        //
    };

    pub fn connectToHost(
        allocator: *mem.Allocator,
        name: []const u8,
        port: u16,
        options: ConnectOptions,
    ) !UdpClient {
        const list = try getAddressList(allocator, name, port);
        defer list.deinit();

        if (list.addrs.len == 0) return error.UnknownHostName;

        for (list.addrs) |addr| {
            return connectToAddress(addr) catch |err| switch (err) {
                error.ConnectionRefused => {
                    continue;
                },
                else => return err,
            };
        }

        return os.ConnectError.ConnectionRefused;
    }
    pub fn connectToAddress(
        allocator: *mem.Allocator,
        address: Address, // XXX: Accept a []Address instead?
        options: ConnectOptions,
    ) !UdpClient {
        const nonblock = if (std.io.is_async) os.SOCK_NONBLOCK else 0;
        const sock_flags = os.SOCK_DGRAM | nonblock |
            (if (is_windows) 0 else os.SOCK_CLOEXEC);
        const sockfd = try os.socket(address.any.family, sock_flags, os.IPPROTO_UDP);
        errdefer os.closeSocket(sockfd);

        if (comptime std.Target.current.isDarwin()) {
            // Darwin doesn't support the MSG_NOSIGNAL flag.
            try os.setsockopt(
                sockfd,
                os.SOL_SOCKET,
                os.SO_NOSIGPIPE,
                &mem.toBytes(@as(u32, 1)),
            );
        }

        if (std.io.is_async) {
            const loop = std.event.Loop.instance orelse return error.WouldBlock;
            try loop.connect(sockfd, &address.any, address.getOsSockLen());
        } else {
            try os.connect(sockfd, &address.any, address.getOsSockLen());
        }

        return UdpClient{
            .socket = .{ .handle = sockfd },
            .is_bound = true,
        };
    }

    pub fn bindToHost(allocator: *mem.Allocator, name: []const u8, port: u16) !UdpClient {
        const list = try getAddressList(allocator, name, port);
        defer list.deinit();

        if (list.addrs.len == 0) return error.UnknownHostName;

        for (list.addrs) |addr| {
            return bindToAddress(addr) catch |err| switch (err) {
                error.ConnectionRefused => {
                    continue;
                },
                else => return err,
            };
        }

        return os.ConnectError.ConnectionRefused;
    }
    pub fn bindToAddress(allocator: *mem.Allocator, address: Address) !UdpClient {
        const nonblock = if (std.io.is_async) os.SOCK_NONBLOCK else 0;
        const sock_flags = os.SOCK_DGRAM | nonblock |
            (if (is_windows) 0 else os.SOCK_CLOEXEC);
        const sockfd = try os.socket(address.any.family, sock_flags, os.IPPROTO_UDP);
        errdefer os.closeSocket(sockfd);

        if (comptime std.Target.current.isDarwin()) {
            // Darwin doesn't support the MSG_NOSIGNAL flag.
            try os.setsockopt(
                sockfd,
                os.SOL_SOCKET,
                os.SO_NOSIGPIPE,
                &mem.toBytes(@as(u32, 1)),
            );
        }

        if (std.io.is_async) {
            @panic("implement me");
        } else {
            try os.bind(sockfd, &address.any, address.getOsSockLen());
        }

        return UdpClient{
            .socket = .{ .handle = sockfd },
            .is_bound = false,
        };
    }

    pub fn receive(self: UdpClient, buffer: []u8) os.RecvFromError!usize {
        if (std.io.is_async) {
            @panic("implement me");
        } else {
            assert(self.is_bound);
            const flags: u32 = if (@hasDecl(os, "MSG_NOSIGNAL")) os.MSG_NOSIGNAL else 0;
            return os.recvfrom(self.socket.handle, buffer, flags, null, null);
        }
    }
    pub fn send(self: UdpClient, buffer: []const u8) os.SendToError!usize {
        if (std.io.is_async) {
            @panic("implement me");
        } else {
            const flags: u32 = if (@hasDecl(os, "MSG_NOSIGNAL")) os.MSG_NOSIGNAL else 0;
            assert(self.is_bound);
            return os.sendto(self.socket.handle, buffer, flags, null, null);
        }
    }

    pub const ReceiveFromResult = std.meta.Tuple(&[_]type{ usize, Address });

    pub fn receiveFrom(self: UdpClient, buffer: []u8) os.RecvFromError!ReceiveFromResult {
        if (std.io.is_async) {
            @panic("implement me");
        } else {
            const flags: u32 = if (@hasDecl(os, "MSG_NOSIGNAL")) os.MSG_NOSIGNAL else 0;
            var source_address: Address = undefined;
            var source_address_size: os.socklen_t = @sizeOf(Address);
            const bytes_read = try os.recvfrom(
                self.socket.handle,
                buffer,
                flags,
                &source_address.any,
                &source_address_size,
            );
            return @as(ReceiveFromResult, .{ bytes_read, source_address });
        }
    }
    pub fn sendTo(self: UdpClient, buffer: []const u8, target: Address) os.SendToError!usize {
        if (std.io.is_async) {
            @panic("implement me");
        } else {
            const flags: u32 = if (@hasDecl(os, "MSG_NOSIGNAL")) os.MSG_NOSIGNAL else 0;
            return os.sendto(
                self.socket.handle,
                buffer,
                flags,
                &target.any,
                target.getOsSockLen(),
            );
        }
    }

    pub fn close(self: *UdpClient) void {
        os.closeSocket(self.socket.handle);
    }
};

pub const UnixListener = struct {
    socket: Socket,
    listen_address: Address,

    pub const ListenOptions = struct {
        /// How many connections the kernel will accept on the application's behalf.
        /// If more than this many connections pool in the kernel, clients will start
        /// seeing "Connection refused".
        kernel_backlog: u31 = 128,
    };

    pub fn listen(address: Address, options: ListenOptions) !UnixListener {
        const sock_flags = os.SOCK_STREAM |
            (if (is_windows) 0 else os.SOCK_CLOEXEC);
        const sockfd = try os.socket(address.any.family, sock_flags, 0);
        errdefer os.closeSocket(sockfd);

        var socklen = address.getOsSockLen();
        try os.bind(sockfd, &address.any, socklen);
        try os.listen(sockfd, options.kernel_backlog);

        var listener = UnixListener{
            .socket = .{ .handle = sockfd },
            .listen_address = undefined,
        };

        try os.getsockname(sockfd, &listener.listen_address.any, &socklen);

        return listener;
    }

    pub fn close(self: *UnixListener) void {
        os.closeSocket(self.socket.handle);
    }

    pub const AcceptError = error{
        ConnectionAborted,

        /// The per-process limit on the number of open file descriptors has been reached.
        ProcessFdQuotaExceeded,

        /// The system-wide limit on the total number of open files has been reached.
        SystemFdQuotaExceeded,

        /// Not enough free memory.  This often means that the memory allocation  is  limited
        /// by the socket buffer limits, not by the system memory.
        SystemResources,

        /// Socket is not listening for new connections.
        SocketNotListening,

        ProtocolFailure,

        /// Firewall rules forbid connection.
        BlockedByFirewall,

        FileDescriptorNotASocket,

        ConnectionResetByPeer,

        NetworkSubsystemFailed,

        OperationNotSupported,
    } || os.UnexpectedError;

    pub const Connection = struct {
        client: UnixClient,
        address: Address,
    };

    /// If this function succeeds, the returned `Connection` is a caller-managed resource.
    pub fn accept(self: *UnixListener) AcceptError!Connection {
        var accepted_addr: Address = undefined;
        var adr_len: os.socklen_t = @sizeOf(Address);
        const accept_result = blk: {
            if (std.io.is_async) {
                @panic("implement me");
            } else {
                break :blk os.accept(
                    self.socket.handle,
                    &accepted_addr.any,
                    &adr_len,
                    os.SOCK_CLOEXEC,
                );
            }
        };

        if (accept_result) |fd| {
            return Connection{
                .client = UnixClient{ .socket = .{ .handle = fd } },
                .address = accepted_addr,
            };
        } else |err| switch (err) {
            error.WouldBlock => unreachable,
            else => |e| return e,
        }
    }
};

pub const TcpListener = struct {
    socket: Socket,
    listen_address: Address,

    pub const ListenOptions = struct {
        /// How many connections the kernel will accept on the application's behalf.
        /// If more than this many connections pool in the kernel, clients will start
        /// seeing "Connection refused".
        kernel_backlog: u31 = 128,

        /// Enable SO_REUSEADDR on the socket.
        reuse_address: bool = false,
    };

    pub fn listen(address: Address, options: ListenOptions) !TcpListener {
        const sock_flags = os.SOCK_STREAM |
            (if (is_windows) 0 else os.SOCK_CLOEXEC);
        const sockfd = try os.socket(address.any.family, sock_flags, os.IPPROTO_TCP);
        errdefer os.closeSocket(sockfd);

        if (options.reuse_address) {
            try os.setsockopt(
                sockfd,
                os.SOL_SOCKET,
                os.SO_REUSEADDR,
                &mem.toBytes(@as(i32, 1)),
            );
        }

        var socklen = address.getOsSockLen();
        try os.bind(sockfd, &address.any, socklen);
        try os.listen(sockfd, options.kernel_backlog);

        var listener = TcpListener{
            .socket = .{ .handle = sockfd },
            .listen_address = undefined,
        };

        try os.getsockname(sockfd, &listener.listen_address.any, &socklen);

        return listener;
    }

    pub fn close(self: *TcpListener) void {
        os.closeSocket(self.socket.handle);
    }

    pub const AcceptError = error{
        ConnectionAborted,

        /// The per-process limit on the number of open file descriptors has been reached.
        ProcessFdQuotaExceeded,

        /// The system-wide limit on the total number of open files has been reached.
        SystemFdQuotaExceeded,

        /// Not enough free memory.  This often means that the memory allocation  is  limited
        /// by the socket buffer limits, not by the system memory.
        SystemResources,

        /// Socket is not listening for new connections.
        SocketNotListening,

        ProtocolFailure,

        /// Firewall rules forbid connection.
        BlockedByFirewall,

        FileDescriptorNotASocket,

        ConnectionResetByPeer,

        NetworkSubsystemFailed,

        OperationNotSupported,
    } || os.UnexpectedError;

    pub const Connection = struct {
        client: TcpClient,
        address: Address,
    };

    /// If this function succeeds, the returned `Connection` is a caller-managed resource.
    pub fn accept(self: *TcpListener) AcceptError!Connection {
        var accepted_addr: Address = undefined;
        var adr_len: os.socklen_t = @sizeOf(Address);
        const accept_result = blk: {
            if (std.io.is_async) {
                @panic("implement me");
            } else {
                break :blk os.accept(
                    self.socket.handle,
                    &accepted_addr.any,
                    &adr_len,
                    os.SOCK_CLOEXEC,
                );
            }
        };

        if (accept_result) |fd| {
            return Connection{
                .client = TcpClient{ .socket = .{ .handle = fd } },
                .address = accepted_addr,
            };
        } else |err| switch (err) {
            error.WouldBlock => unreachable,
            else => |e| return e,
        }
    }
};

test "" {
    _ = @import("net/test.zig");
}
