const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const net = @This();
const mem = std.mem;
const os = std.os;
const fs = std.fs;
const io = std.io;
const native_endian = builtin.target.cpu.arch.endian();

// Windows 10 added support for unix sockets in build 17063, redstone 4 is the
// first release to support them.
pub const has_unix_sockets = @hasDecl(os.sockaddr, "un") and
    (builtin.target.os.tag != .windows or
    builtin.os.version_range.windows.isAtLeast(.win10_rs4) orelse false);

pub const Address = extern union {
    any: os.sockaddr,
    in: Ip4Address,
    in6: Ip6Address,
    un: if (has_unix_sockets) os.sockaddr.un else void,

    /// Parse the given IP address string into an Address value.
    /// It is recommended to use `resolveIp` instead, to handle
    /// IPv6 link-local unix addresses.
    pub fn parseIp(name: []const u8, port: u16) !Address {
        if (parseIp4(name, port)) |ip4| return ip4 else |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            error.NonCanonical,
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
            error.NonCanonical,
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
            os.AF.INET => return parseIp4(name, port),
            os.AF.INET6 => return parseIp6(name, port),
            os.AF.UNSPEC => return parseIp(name, port),
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
        var sock_addr = os.sockaddr.un{
            .family = os.AF.UNIX,
            .path = undefined,
        };

        // Add 1 to ensure a terminating 0 is present in the path array for maximum portability.
        if (path.len + 1 > sock_addr.path.len) return error.NameTooLong;

        @memset(&sock_addr.path, 0);
        @memcpy(sock_addr.path[0..path.len], path);

        return Address{ .un = sock_addr };
    }

    /// Returns the port in native endian.
    /// Asserts that the address is ip4 or ip6.
    pub fn getPort(self: Address) u16 {
        return switch (self.any.family) {
            os.AF.INET => self.in.getPort(),
            os.AF.INET6 => self.in6.getPort(),
            else => unreachable,
        };
    }

    /// `port` is native-endian.
    /// Asserts that the address is ip4 or ip6.
    pub fn setPort(self: *Address, port: u16) void {
        switch (self.any.family) {
            os.AF.INET => self.in.setPort(port),
            os.AF.INET6 => self.in6.setPort(port),
            else => unreachable,
        }
    }

    /// Asserts that `addr` is an IP address.
    /// This function will read past the end of the pointer, with a size depending
    /// on the address family.
    pub fn initPosix(addr: *align(4) const os.sockaddr) Address {
        switch (addr.family) {
            os.AF.INET => return Address{ .in = Ip4Address{ .sa = @as(*const os.sockaddr.in, @ptrCast(addr)).* } },
            os.AF.INET6 => return Address{ .in6 = Ip6Address{ .sa = @as(*const os.sockaddr.in6, @ptrCast(addr)).* } },
            else => unreachable,
        }
    }

    pub fn format(
        self: Address,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
        switch (self.any.family) {
            os.AF.INET => try self.in.format(fmt, options, out_stream),
            os.AF.INET6 => try self.in6.format(fmt, options, out_stream),
            os.AF.UNIX => {
                if (!has_unix_sockets) {
                    unreachable;
                }

                try std.fmt.format(out_stream, "{s}", .{std.mem.sliceTo(&self.un.path, 0)});
            },
            else => unreachable,
        }
    }

    pub fn eql(a: Address, b: Address) bool {
        const a_bytes = @as([*]const u8, @ptrCast(&a.any))[0..a.getOsSockLen()];
        const b_bytes = @as([*]const u8, @ptrCast(&b.any))[0..b.getOsSockLen()];
        return mem.eql(u8, a_bytes, b_bytes);
    }

    pub fn getOsSockLen(self: Address) os.socklen_t {
        switch (self.any.family) {
            os.AF.INET => return self.in.getOsSockLen(),
            os.AF.INET6 => return self.in6.getOsSockLen(),
            os.AF.UNIX => {
                if (!has_unix_sockets) {
                    unreachable;
                }

                // Using the full length of the structure here is more portable than returning
                // the number of bytes actually used by the currently stored path.
                // This also is correct regardless if we are passing a socket address to the kernel
                // (e.g. in bind, connect, sendto) since we ensure the path is 0 terminated in
                // initUnix() or if we are receiving a socket address from the kernel and must
                // provide the full buffer size (e.g. getsockname, getpeername, recvfrom, accept).
                //
                // To access the path, std.mem.sliceTo(&address.un.path, 0) should be used.
                return @as(os.socklen_t, @intCast(@sizeOf(os.sockaddr.un)));
            },

            else => unreachable,
        }
    }
};

pub const Ip4Address = extern struct {
    sa: os.sockaddr.in,

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
        var has_zero_prefix = false;
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
                has_zero_prefix = false;
            } else if (c >= '0' and c <= '9') {
                if (c == '0' and !saw_any_digits) {
                    has_zero_prefix = true;
                } else if (has_zero_prefix) {
                    return error.NonCanonical;
                }
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
            .sa = os.sockaddr.in{
                .port = mem.nativeToBig(u16, port),
                .addr = @as(*align(1) const u32, @ptrCast(&addr)).*,
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
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
        _ = options;
        const bytes = @as(*const [4]u8, @ptrCast(&self.sa.addr));
        try std.fmt.format(out_stream, "{}.{}.{}.{}:{}", .{
            bytes[0],
            bytes[1],
            bytes[2],
            bytes[3],
            self.getPort(),
        });
    }

    pub fn getOsSockLen(self: Ip4Address) os.socklen_t {
        _ = self;
        return @sizeOf(os.sockaddr.in);
    }
};

pub const Ip6Address = extern struct {
    sa: os.sockaddr.in6,

    /// Parse a given IPv6 address string into an Address.
    /// Assumes the Scope ID of the address is fully numeric.
    /// For non-numeric addresses, see `resolveIp6`.
    pub fn parse(buf: []const u8, port: u16) !Ip6Address {
        var result = Ip6Address{
            .sa = os.sockaddr.in6{
                .scope_id = 0,
                .port = mem.nativeToBig(u16, port),
                .flowinfo = 0,
                .addr = undefined,
            },
        };
        var ip_slice: *[16]u8 = result.sa.addr[0..];

        var tail: [16]u8 = undefined;

        var x: u16 = 0;
        var saw_any_digits = false;
        var index: u8 = 0;
        var scope_id = false;
        var abbrv = false;
        for (buf, 0..) |c, i| {
            if (scope_id) {
                if (c >= '0' and c <= '9') {
                    const digit = c - '0';
                    {
                        const ov = @mulWithOverflow(result.sa.scope_id, 10);
                        if (ov[1] != 0) return error.Overflow;
                        result.sa.scope_id = ov[0];
                    }
                    {
                        const ov = @addWithOverflow(result.sa.scope_id, digit);
                        if (ov[1] != 0) return error.Overflow;
                        result.sa.scope_id = ov[0];
                    }
                } else {
                    return error.InvalidCharacter;
                }
            } else if (c == ':') {
                if (!saw_any_digits) {
                    if (abbrv) return error.InvalidCharacter; // ':::'
                    if (i != 0) abbrv = true;
                    @memset(ip_slice[index..], 0);
                    ip_slice = tail[0..];
                    index = 0;
                    continue;
                }
                if (index == 14) {
                    return error.InvalidEnd;
                }
                ip_slice[index] = @as(u8, @truncate(x >> 8));
                index += 1;
                ip_slice[index] = @as(u8, @truncate(x));
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
                {
                    const ov = @mulWithOverflow(x, 16);
                    if (ov[1] != 0) return error.Overflow;
                    x = ov[0];
                }
                {
                    const ov = @addWithOverflow(x, digit);
                    if (ov[1] != 0) return error.Overflow;
                    x = ov[0];
                }
                saw_any_digits = true;
            }
        }

        if (!saw_any_digits and !abbrv) {
            return error.Incomplete;
        }

        if (index == 14) {
            ip_slice[14] = @as(u8, @truncate(x >> 8));
            ip_slice[15] = @as(u8, @truncate(x));
            return result;
        } else {
            ip_slice[index] = @as(u8, @truncate(x >> 8));
            index += 1;
            ip_slice[index] = @as(u8, @truncate(x));
            index += 1;
            @memcpy(result.sa.addr[16 - index ..][0..index], ip_slice[0..index]);
            return result;
        }
    }

    pub fn resolve(buf: []const u8, port: u16) !Ip6Address {
        // TODO: Unify the implementations of resolveIp6 and parseIp6.
        var result = Ip6Address{
            .sa = os.sockaddr.in6{
                .scope_id = 0,
                .port = mem.nativeToBig(u16, port),
                .flowinfo = 0,
                .addr = undefined,
            },
        };
        var ip_slice: *[16]u8 = result.sa.addr[0..];

        var tail: [16]u8 = undefined;

        var x: u16 = 0;
        var saw_any_digits = false;
        var index: u8 = 0;
        var abbrv = false;

        var scope_id = false;
        var scope_id_value: [os.IFNAMESIZE - 1]u8 = undefined;
        var scope_id_index: usize = 0;

        for (buf, 0..) |c, i| {
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
                    @memset(ip_slice[index..], 0);
                    ip_slice = tail[0..];
                    index = 0;
                    continue;
                }
                if (index == 14) {
                    return error.InvalidEnd;
                }
                ip_slice[index] = @as(u8, @truncate(x >> 8));
                index += 1;
                ip_slice[index] = @as(u8, @truncate(x));
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
                {
                    const ov = @mulWithOverflow(x, 16);
                    if (ov[1] != 0) return error.Overflow;
                    x = ov[0];
                }
                {
                    const ov = @addWithOverflow(x, digit);
                    if (ov[1] != 0) return error.Overflow;
                    x = ov[0];
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
            ip_slice[14] = @as(u8, @truncate(x >> 8));
            ip_slice[15] = @as(u8, @truncate(x));
            return result;
        } else {
            ip_slice[index] = @as(u8, @truncate(x >> 8));
            index += 1;
            ip_slice[index] = @as(u8, @truncate(x));
            index += 1;
            @memcpy(result.sa.addr[16 - index ..][0..index], ip_slice[0..index]);
            return result;
        }
    }

    pub fn init(addr: [16]u8, port: u16, flowinfo: u32, scope_id: u32) Ip6Address {
        return Ip6Address{
            .sa = os.sockaddr.in6{
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
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
        _ = options;
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
        const big_endian_parts = @as(*align(1) const [8]u16, @ptrCast(&self.sa.addr));
        const native_endian_parts = switch (native_endian) {
            .Big => big_endian_parts.*,
            .Little => blk: {
                var buf: [8]u16 = undefined;
                for (big_endian_parts, 0..) |part, i| {
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
        _ = self;
        return @sizeOf(os.sockaddr.in6);
    }
};

pub fn connectUnixSocket(path: []const u8) !Stream {
    const opt_non_block = if (std.io.is_async) os.SOCK.NONBLOCK else 0;
    const sockfd = try os.socket(
        os.AF.UNIX,
        os.SOCK.STREAM | os.SOCK.CLOEXEC | opt_non_block,
        0,
    );
    errdefer os.closeSocket(sockfd);

    var addr = try std.net.Address.initUnix(path);

    if (std.io.is_async) {
        const loop = std.event.Loop.instance orelse return error.WouldBlock;
        try loop.connect(sockfd, &addr.any, addr.getOsSockLen());
    } else {
        try os.connect(sockfd, &addr.any, addr.getOsSockLen());
    }

    return Stream{
        .handle = sockfd,
    };
}

fn if_nametoindex(name: []const u8) !u32 {
    if (builtin.target.os.tag == .linux) {
        var ifr: os.ifreq = undefined;
        var sockfd = try os.socket(os.AF.UNIX, os.SOCK.DGRAM | os.SOCK.CLOEXEC, 0);
        defer os.closeSocket(sockfd);

        @memcpy(ifr.ifrn.name[0..name.len], name);
        ifr.ifrn.name[name.len] = 0;

        // TODO investigate if this needs to be integrated with evented I/O.
        try os.ioctl_SIOCGIFINDEX(sockfd, &ifr);

        return @as(u32, @bitCast(ifr.ifru.ivalue));
    }

    if (comptime builtin.target.os.tag.isDarwin()) {
        if (name.len >= os.IFNAMESIZE)
            return error.NameTooLong;

        var if_name: [os.IFNAMESIZE:0]u8 = undefined;
        @memcpy(if_name[0..name.len], name);
        if_name[name.len] = 0;
        const if_slice = if_name[0..name.len :0];
        const index = os.system.if_nametoindex(if_slice);
        if (index == 0)
            return error.InterfaceNotFound;
        return @as(u32, @bitCast(index));
    }

    @compileError("std.net.if_nametoindex unimplemented for this OS");
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

pub const TcpConnectToHostError = GetAddressListError || TcpConnectToAddressError;

/// All memory allocated with `allocator` will be freed before this function returns.
pub fn tcpConnectToHost(allocator: mem.Allocator, name: []const u8, port: u16) TcpConnectToHostError!Stream {
    const list = try getAddressList(allocator, name, port);
    defer list.deinit();

    if (list.addrs.len == 0) return error.UnknownHostName;

    for (list.addrs) |addr| {
        return tcpConnectToAddress(addr) catch |err| switch (err) {
            error.ConnectionRefused => {
                continue;
            },
            else => return err,
        };
    }
    return std.os.ConnectError.ConnectionRefused;
}

pub const TcpConnectToAddressError = std.os.SocketError || std.os.ConnectError;

pub fn tcpConnectToAddress(address: Address) TcpConnectToAddressError!Stream {
    const nonblock = if (std.io.is_async) os.SOCK.NONBLOCK else 0;
    const sock_flags = os.SOCK.STREAM | nonblock |
        (if (builtin.target.os.tag == .windows) 0 else os.SOCK.CLOEXEC);
    const sockfd = try os.socket(address.any.family, sock_flags, os.IPPROTO.TCP);
    errdefer os.closeSocket(sockfd);

    if (std.io.is_async) {
        const loop = std.event.Loop.instance orelse return error.WouldBlock;
        try loop.connect(sockfd, &address.any, address.getOsSockLen());
    } else {
        try os.connect(sockfd, &address.any, address.getOsSockLen());
    }

    return Stream{ .handle = sockfd };
}

const GetAddressListError = std.mem.Allocator.Error || std.fs.File.OpenError || std.fs.File.ReadError || std.os.SocketError || std.os.BindError || std.os.SetSockOptError || error{
    // TODO: break this up into error sets from the various underlying functions

    TemporaryNameServerFailure,
    NameServerFailure,
    AddressFamilyNotSupported,
    UnknownHostName,
    ServiceUnavailable,
    Unexpected,

    HostLacksNetworkAddresses,

    InvalidCharacter,
    InvalidEnd,
    NonCanonical,
    Overflow,
    Incomplete,
    InvalidIpv4Mapping,
    InvalidIPAddressFormat,

    InterfaceNotFound,
    FileSystem,
};

/// Call `AddressList.deinit` on the result.
pub fn getAddressList(allocator: mem.Allocator, name: []const u8, port: u16) GetAddressListError!*AddressList {
    const result = blk: {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        const result = try arena.allocator().create(AddressList);
        result.* = AddressList{
            .arena = arena,
            .addrs = undefined,
            .canon_name = null,
        };
        break :blk result;
    };
    const arena = result.arena.allocator();
    errdefer result.deinit();

    if (builtin.target.os.tag == .windows) {
        const name_c = try allocator.dupeZ(u8, name);
        defer allocator.free(name_c);

        const port_c = try std.fmt.allocPrintZ(allocator, "{}", .{port});
        defer allocator.free(port_c);

        const ws2_32 = os.windows.ws2_32;
        const hints = os.addrinfo{
            .flags = ws2_32.AI.NUMERICSERV,
            .family = os.AF.UNSPEC,
            .socktype = os.SOCK.STREAM,
            .protocol = os.IPPROTO.TCP,
            .canonname = null,
            .addr = null,
            .addrlen = 0,
            .next = null,
        };
        var res: ?*os.addrinfo = null;
        var first = true;
        while (true) {
            const rc = ws2_32.getaddrinfo(name_c.ptr, port_c.ptr, &hints, &res);
            switch (@as(os.windows.ws2_32.WinsockError, @enumFromInt(@as(u16, @intCast(rc))))) {
                @as(os.windows.ws2_32.WinsockError, @enumFromInt(0)) => break,
                .WSATRY_AGAIN => return error.TemporaryNameServerFailure,
                .WSANO_RECOVERY => return error.NameServerFailure,
                .WSAEAFNOSUPPORT => return error.AddressFamilyNotSupported,
                .WSA_NOT_ENOUGH_MEMORY => return error.OutOfMemory,
                .WSAHOST_NOT_FOUND => return error.UnknownHostName,
                .WSATYPE_NOT_FOUND => return error.ServiceUnavailable,
                .WSAEINVAL => unreachable,
                .WSAESOCKTNOSUPPORT => unreachable,
                .WSANOTINITIALISED => {
                    if (!first) return error.Unexpected;
                    first = false;
                    try os.windows.callWSAStartup();
                    continue;
                },
                else => |err| return os.windows.unexpectedWSAError(err),
            }
        }
        defer ws2_32.freeaddrinfo(res);

        const addr_count = blk: {
            var count: usize = 0;
            var it = res;
            while (it) |info| : (it = info.next) {
                if (info.addr != null) {
                    count += 1;
                }
            }
            break :blk count;
        };
        result.addrs = try arena.alloc(Address, addr_count);

        var it = res;
        var i: usize = 0;
        while (it) |info| : (it = info.next) {
            const addr = info.addr orelse continue;
            result.addrs[i] = Address.initPosix(@alignCast(addr));

            if (info.canonname) |n| {
                if (result.canon_name == null) {
                    result.canon_name = try arena.dupe(u8, mem.sliceTo(n, 0));
                }
            }
            i += 1;
        }

        return result;
    }

    if (builtin.link_libc) {
        const name_c = try allocator.dupeZ(u8, name);
        defer allocator.free(name_c);

        const port_c = try std.fmt.allocPrintZ(allocator, "{}", .{port});
        defer allocator.free(port_c);

        const sys = if (builtin.target.os.tag == .windows) os.windows.ws2_32 else os.system;
        const hints = os.addrinfo{
            .flags = sys.AI.NUMERICSERV,
            .family = os.AF.UNSPEC,
            .socktype = os.SOCK.STREAM,
            .protocol = os.IPPROTO.TCP,
            .canonname = null,
            .addr = null,
            .addrlen = 0,
            .next = null,
        };
        var res: ?*os.addrinfo = null;
        switch (sys.getaddrinfo(name_c.ptr, port_c.ptr, &hints, &res)) {
            @as(sys.EAI, @enumFromInt(0)) => {},
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
        defer if (res) |some| sys.freeaddrinfo(some);

        const addr_count = blk: {
            var count: usize = 0;
            var it = res;
            while (it) |info| : (it = info.next) {
                if (info.addr != null) {
                    count += 1;
                }
            }
            break :blk count;
        };
        result.addrs = try arena.alloc(Address, addr_count);

        var it = res;
        var i: usize = 0;
        while (it) |info| : (it = info.next) {
            const addr = info.addr orelse continue;
            result.addrs[i] = Address.initPosix(@alignCast(addr));

            if (info.canonname) |n| {
                if (result.canon_name == null) {
                    result.canon_name = try arena.dupe(u8, mem.sliceTo(n, 0));
                }
            }
            i += 1;
        }

        return result;
    }

    if (builtin.target.os.tag == .linux) {
        const flags = std.c.AI.NUMERICSERV;
        const family = os.AF.UNSPEC;
        var lookup_addrs = std.ArrayList(LookupAddr).init(allocator);
        defer lookup_addrs.deinit();

        var canon = std.ArrayList(u8).init(arena);
        defer canon.deinit();

        try linuxLookupName(&lookup_addrs, &canon, name, family, flags, port);

        result.addrs = try arena.alloc(Address, lookup_addrs.items.len);
        if (canon.items.len != 0) {
            result.canon_name = try canon.toOwnedSlice();
        }

        for (lookup_addrs.items, 0..) |lookup_addr, i| {
            result.addrs[i] = lookup_addr.addr;
            assert(result.addrs[i].getPort() == port);
        }

        return result;
    }
    @compileError("std.net.getAddressList unimplemented for this OS");
}

const LookupAddr = struct {
    addr: Address,
    sortkey: i32 = 0,
};

const DAS_USABLE = 0x40000000;
const DAS_MATCHINGSCOPE = 0x20000000;
const DAS_MATCHINGLABEL = 0x10000000;
const DAS_PREC_SHIFT = 20;
const DAS_SCOPE_SHIFT = 16;
const DAS_PREFIX_SHIFT = 8;
const DAS_ORDER_SHIFT = 0;

fn linuxLookupName(
    addrs: *std.ArrayList(LookupAddr),
    canon: *std.ArrayList(u8),
    opt_name: ?[]const u8,
    family: os.sa_family_t,
    flags: u32,
    port: u16,
) !void {
    if (opt_name) |name| {
        // reject empty name and check len so it fits into temp bufs
        canon.items.len = 0;
        try canon.appendSlice(name);
        if (Address.parseExpectingFamily(name, family, port)) |addr| {
            try addrs.append(LookupAddr{ .addr = addr });
        } else |name_err| if ((flags & std.c.AI.NUMERICHOST) != 0) {
            return name_err;
        } else {
            try linuxLookupNameFromHosts(addrs, canon, name, family, port);
            if (addrs.items.len == 0) {
                // RFC 6761 Section 6.3.3
                // Name resolution APIs and libraries SHOULD recognize localhost
                // names as special and SHOULD always return the IP loopback address
                // for address queries and negative responses for all other query
                // types.

                // Check for equal to "localhost(.)" or ends in ".localhost(.)"
                const localhost = if (name[name.len - 1] == '.') "localhost." else "localhost";
                if (mem.endsWith(u8, name, localhost) and (name.len == localhost.len or name[name.len - localhost.len] == '.')) {
                    try addrs.append(LookupAddr{ .addr = .{ .in = Ip4Address.parse("127.0.0.1", port) catch unreachable } });
                    try addrs.append(LookupAddr{ .addr = .{ .in6 = Ip6Address.parse("::1", port) catch unreachable } });
                    return;
                }

                try linuxLookupNameFromDnsSearch(addrs, canon, name, family, port);
            }
        }
    } else {
        try canon.resize(0);
        try linuxLookupNameFromNull(addrs, family, flags, port);
    }
    if (addrs.items.len == 0) return error.UnknownHostName;

    // No further processing is needed if there are fewer than 2
    // results or if there are only IPv4 results.
    if (addrs.items.len == 1 or family == os.AF.INET) return;
    const all_ip4 = for (addrs.items) |addr| {
        if (addr.addr.any.family != os.AF.INET) break false;
    } else true;
    if (all_ip4) return;

    // The following implements a subset of RFC 3484/6724 destination
    // address selection by generating a single 31-bit sort key for
    // each address. Rules 3, 4, and 7 are omitted for having
    // excessive runtime and code size cost and dubious benefit.
    // So far the label/precedence table cannot be customized.
    // This implementation is ported from musl libc.
    // A more idiomatic "ziggy" implementation would be welcome.
    for (addrs.items, 0..) |*addr, i| {
        var key: i32 = 0;
        var sa6: os.sockaddr.in6 = undefined;
        @memset(@as([*]u8, @ptrCast(&sa6))[0..@sizeOf(os.sockaddr.in6)], 0);
        var da6 = os.sockaddr.in6{
            .family = os.AF.INET6,
            .scope_id = addr.addr.in6.sa.scope_id,
            .port = 65535,
            .flowinfo = 0,
            .addr = [1]u8{0} ** 16,
        };
        var sa4: os.sockaddr.in = undefined;
        @memset(@as([*]u8, @ptrCast(&sa4))[0..@sizeOf(os.sockaddr.in)], 0);
        var da4 = os.sockaddr.in{
            .family = os.AF.INET,
            .port = 65535,
            .addr = 0,
            .zero = [1]u8{0} ** 8,
        };
        var sa: *align(4) os.sockaddr = undefined;
        var da: *align(4) os.sockaddr = undefined;
        var salen: os.socklen_t = undefined;
        var dalen: os.socklen_t = undefined;
        if (addr.addr.any.family == os.AF.INET6) {
            da6.addr = addr.addr.in6.sa.addr;
            da = @ptrCast(&da6);
            dalen = @sizeOf(os.sockaddr.in6);
            sa = @ptrCast(&sa6);
            salen = @sizeOf(os.sockaddr.in6);
        } else {
            sa6.addr[0..12].* = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff".*;
            da6.addr[0..12].* = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff".*;
            mem.writeIntNative(u32, da6.addr[12..], addr.addr.in.sa.addr);
            da4.addr = addr.addr.in.sa.addr;
            da = @ptrCast(&da4);
            dalen = @sizeOf(os.sockaddr.in);
            sa = @ptrCast(&sa4);
            salen = @sizeOf(os.sockaddr.in);
        }
        const dpolicy = policyOf(da6.addr);
        const dscope: i32 = scopeOf(da6.addr);
        const dlabel = dpolicy.label;
        const dprec: i32 = dpolicy.prec;
        const MAXADDRS = 3;
        var prefixlen: i32 = 0;
        const sock_flags = os.SOCK.DGRAM | os.SOCK.CLOEXEC;
        if (os.socket(addr.addr.any.family, sock_flags, os.IPPROTO.UDP)) |fd| syscalls: {
            defer os.closeSocket(fd);
            os.connect(fd, da, dalen) catch break :syscalls;
            key |= DAS_USABLE;
            os.getsockname(fd, sa, &salen) catch break :syscalls;
            if (addr.addr.any.family == os.AF.INET) {
                // TODO sa6.addr[12..16] should return *[4]u8, making this cast unnecessary.
                mem.writeIntNative(u32, @as(*[4]u8, @ptrCast(&sa6.addr[12])), sa4.addr);
            }
            if (dscope == @as(i32, scopeOf(sa6.addr))) key |= DAS_MATCHINGSCOPE;
            if (dlabel == labelOf(sa6.addr)) key |= DAS_MATCHINGLABEL;
            prefixlen = prefixMatch(sa6.addr, da6.addr);
        } else |_| {}
        key |= dprec << DAS_PREC_SHIFT;
        key |= (15 - dscope) << DAS_SCOPE_SHIFT;
        key |= prefixlen << DAS_PREFIX_SHIFT;
        key |= (MAXADDRS - @as(i32, @intCast(i))) << DAS_ORDER_SHIFT;
        addr.sortkey = key;
    }
    mem.sort(LookupAddr, addrs.items, {}, addrCmpLessThan);
}

const Policy = struct {
    addr: [16]u8,
    len: u8,
    mask: u8,
    prec: u8,
    label: u8,
};

const defined_policies = [_]Policy{
    Policy{
        .addr = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01".*,
        .len = 15,
        .mask = 0xff,
        .prec = 50,
        .label = 0,
    },
    Policy{
        .addr = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\x00\x00\x00\x00".*,
        .len = 11,
        .mask = 0xff,
        .prec = 35,
        .label = 4,
    },
    Policy{
        .addr = "\x20\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .len = 1,
        .mask = 0xff,
        .prec = 30,
        .label = 2,
    },
    Policy{
        .addr = "\x20\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .len = 3,
        .mask = 0xff,
        .prec = 5,
        .label = 5,
    },
    Policy{
        .addr = "\xfc\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .len = 0,
        .mask = 0xfe,
        .prec = 3,
        .label = 13,
    },
    //  These are deprecated and/or returned to the address
    //  pool, so despite the RFC, treating them as special
    //  is probably wrong.
    // { "", 11, 0xff, 1, 3 },
    // { "\xfe\xc0", 1, 0xc0, 1, 11 },
    // { "\x3f\xfe", 1, 0xff, 1, 12 },
    // Last rule must match all addresses to stop loop.
    Policy{
        .addr = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
        .len = 0,
        .mask = 0,
        .prec = 40,
        .label = 1,
    },
};

fn policyOf(a: [16]u8) *const Policy {
    for (&defined_policies) |*policy| {
        if (!mem.eql(u8, a[0..policy.len], policy.addr[0..policy.len])) continue;
        if ((a[policy.len] & policy.mask) != policy.addr[policy.len]) continue;
        return policy;
    }
    unreachable;
}

fn scopeOf(a: [16]u8) u8 {
    if (IN6_IS_ADDR_MULTICAST(a)) return a[1] & 15;
    if (IN6_IS_ADDR_LINKLOCAL(a)) return 2;
    if (IN6_IS_ADDR_LOOPBACK(a)) return 2;
    if (IN6_IS_ADDR_SITELOCAL(a)) return 5;
    return 14;
}

fn prefixMatch(s: [16]u8, d: [16]u8) u8 {
    // TODO: This FIXME inherited from porting from musl libc.
    // I don't want this to go into zig std lib 1.0.0.

    // FIXME: The common prefix length should be limited to no greater
    // than the nominal length of the prefix portion of the source
    // address. However the definition of the source prefix length is
    // not clear and thus this limiting is not yet implemented.
    var i: u8 = 0;
    while (i < 128 and ((s[i / 8] ^ d[i / 8]) & (@as(u8, 128) >> @as(u3, @intCast(i % 8)))) == 0) : (i += 1) {}
    return i;
}

fn labelOf(a: [16]u8) u8 {
    return policyOf(a).label;
}

fn IN6_IS_ADDR_MULTICAST(a: [16]u8) bool {
    return a[0] == 0xff;
}

fn IN6_IS_ADDR_LINKLOCAL(a: [16]u8) bool {
    return a[0] == 0xfe and (a[1] & 0xc0) == 0x80;
}

fn IN6_IS_ADDR_LOOPBACK(a: [16]u8) bool {
    return a[0] == 0 and a[1] == 0 and
        a[2] == 0 and
        a[12] == 0 and a[13] == 0 and
        a[14] == 0 and a[15] == 1;
}

fn IN6_IS_ADDR_SITELOCAL(a: [16]u8) bool {
    return a[0] == 0xfe and (a[1] & 0xc0) == 0xc0;
}

// Parameters `b` and `a` swapped to make this descending.
fn addrCmpLessThan(context: void, b: LookupAddr, a: LookupAddr) bool {
    _ = context;
    return a.sortkey < b.sortkey;
}

fn linuxLookupNameFromNull(
    addrs: *std.ArrayList(LookupAddr),
    family: os.sa_family_t,
    flags: u32,
    port: u16,
) !void {
    if ((flags & std.c.AI.PASSIVE) != 0) {
        if (family != os.AF.INET6) {
            (try addrs.addOne()).* = LookupAddr{
                .addr = Address.initIp4([1]u8{0} ** 4, port),
            };
        }
        if (family != os.AF.INET) {
            (try addrs.addOne()).* = LookupAddr{
                .addr = Address.initIp6([1]u8{0} ** 16, port, 0, 0),
            };
        }
    } else {
        if (family != os.AF.INET6) {
            (try addrs.addOne()).* = LookupAddr{
                .addr = Address.initIp4([4]u8{ 127, 0, 0, 1 }, port),
            };
        }
        if (family != os.AF.INET) {
            (try addrs.addOne()).* = LookupAddr{
                .addr = Address.initIp6(([1]u8{0} ** 15) ++ [1]u8{1}, port, 0, 0),
            };
        }
    }
}

fn linuxLookupNameFromHosts(
    addrs: *std.ArrayList(LookupAddr),
    canon: *std.ArrayList(u8),
    name: []const u8,
    family: os.sa_family_t,
    port: u16,
) !void {
    const file = fs.openFileAbsoluteZ("/etc/hosts", .{}) catch |err| switch (err) {
        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        => return,
        else => |e| return e,
    };
    defer file.close();

    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();
    var line_buf: [512]u8 = undefined;
    while (reader.readUntilDelimiterOrEof(&line_buf, '\n') catch |err| switch (err) {
        error.StreamTooLong => blk: {
            // Skip to the delimiter in the reader, to fix parsing
            try reader.skipUntilDelimiterOrEof('\n');
            // Use the truncated line. A truncated comment or hostname will be handled correctly.
            break :blk &line_buf;
        },
        else => |e| return e,
    }) |line| {
        var split_it = mem.splitScalar(u8, line, '#');
        const no_comment_line = split_it.first();

        var line_it = mem.tokenizeAny(u8, no_comment_line, " \t");
        const ip_text = line_it.next() orelse continue;
        var first_name_text: ?[]const u8 = null;
        while (line_it.next()) |name_text| {
            if (first_name_text == null) first_name_text = name_text;
            if (mem.eql(u8, name_text, name)) {
                break;
            }
        } else continue;

        const addr = Address.parseExpectingFamily(ip_text, family, port) catch |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            error.InvalidIPAddressFormat,
            error.InvalidIpv4Mapping,
            error.NonCanonical,
            => continue,
        };
        try addrs.append(LookupAddr{ .addr = addr });

        // first name is canonical name
        const name_text = first_name_text.?;
        if (isValidHostName(name_text)) {
            canon.items.len = 0;
            try canon.appendSlice(name_text);
        }
    }
}

pub fn isValidHostName(hostname: []const u8) bool {
    if (hostname.len >= 254) return false;
    if (!std.unicode.utf8ValidateSlice(hostname)) return false;
    for (hostname) |byte| {
        if (!std.ascii.isASCII(byte) or byte == '.' or byte == '-' or std.ascii.isAlphanumeric(byte)) {
            continue;
        }
        return false;
    }
    return true;
}

fn linuxLookupNameFromDnsSearch(
    addrs: *std.ArrayList(LookupAddr),
    canon: *std.ArrayList(u8),
    name: []const u8,
    family: os.sa_family_t,
    port: u16,
) !void {
    var rc: ResolvConf = undefined;
    try getResolvConf(addrs.allocator, &rc);
    defer rc.deinit();

    // Count dots, suppress search when >=ndots or name ends in
    // a dot, which is an explicit request for global scope.
    var dots: usize = 0;
    for (name) |byte| {
        if (byte == '.') dots += 1;
    }

    const search = if (dots >= rc.ndots or mem.endsWith(u8, name, "."))
        ""
    else
        rc.search.items;

    var canon_name = name;

    // Strip final dot for canon, fail if multiple trailing dots.
    if (mem.endsWith(u8, canon_name, ".")) canon_name.len -= 1;
    if (mem.endsWith(u8, canon_name, ".")) return error.UnknownHostName;

    // Name with search domain appended is setup in canon[]. This both
    // provides the desired default canonical name (if the requested
    // name is not a CNAME record) and serves as a buffer for passing
    // the full requested name to name_from_dns.
    try canon.resize(canon_name.len);
    @memcpy(canon.items, canon_name);
    try canon.append('.');

    var tok_it = mem.tokenizeAny(u8, search, " \t");
    while (tok_it.next()) |tok| {
        canon.shrinkRetainingCapacity(canon_name.len + 1);
        try canon.appendSlice(tok);
        try linuxLookupNameFromDns(addrs, canon, canon.items, family, rc, port);
        if (addrs.items.len != 0) return;
    }

    canon.shrinkRetainingCapacity(canon_name.len);
    return linuxLookupNameFromDns(addrs, canon, name, family, rc, port);
}

const dpc_ctx = struct {
    addrs: *std.ArrayList(LookupAddr),
    canon: *std.ArrayList(u8),
    port: u16,
};

fn linuxLookupNameFromDns(
    addrs: *std.ArrayList(LookupAddr),
    canon: *std.ArrayList(u8),
    name: []const u8,
    family: os.sa_family_t,
    rc: ResolvConf,
    port: u16,
) !void {
    var ctx = dpc_ctx{
        .addrs = addrs,
        .canon = canon,
        .port = port,
    };
    const AfRr = struct {
        af: os.sa_family_t,
        rr: u8,
    };
    const afrrs = [_]AfRr{
        AfRr{ .af = os.AF.INET6, .rr = os.RR.A },
        AfRr{ .af = os.AF.INET, .rr = os.RR.AAAA },
    };
    var qbuf: [2][280]u8 = undefined;
    var abuf: [2][512]u8 = undefined;
    var qp: [2][]const u8 = undefined;
    const apbuf = [2][]u8{ &abuf[0], &abuf[1] };
    var nq: usize = 0;

    for (afrrs) |afrr| {
        if (family != afrr.af) {
            const len = os.res_mkquery(0, name, 1, afrr.rr, &[_]u8{}, null, &qbuf[nq]);
            qp[nq] = qbuf[nq][0..len];
            nq += 1;
        }
    }

    var ap = [2][]u8{ apbuf[0], apbuf[1] };
    ap[0].len = 0;
    ap[1].len = 0;

    try resMSendRc(qp[0..nq], ap[0..nq], apbuf[0..nq], rc);

    var i: usize = 0;
    while (i < nq) : (i += 1) {
        dnsParse(ap[i], ctx, dnsParseCallback) catch {};
    }

    if (addrs.items.len != 0) return;
    if (ap[0].len < 4 or (ap[0][3] & 15) == 2) return error.TemporaryNameServerFailure;
    if ((ap[0][3] & 15) == 0) return error.UnknownHostName;
    if ((ap[0][3] & 15) == 3) return;
    return error.NameServerFailure;
}

const ResolvConf = struct {
    attempts: u32,
    ndots: u32,
    timeout: u32,
    search: std.ArrayList(u8),
    ns: std.ArrayList(LookupAddr),

    fn deinit(rc: *ResolvConf) void {
        rc.ns.deinit();
        rc.search.deinit();
        rc.* = undefined;
    }
};

/// Ignores lines longer than 512 bytes.
/// TODO: https://github.com/ziglang/zig/issues/2765 and https://github.com/ziglang/zig/issues/2761
fn getResolvConf(allocator: mem.Allocator, rc: *ResolvConf) !void {
    rc.* = ResolvConf{
        .ns = std.ArrayList(LookupAddr).init(allocator),
        .search = std.ArrayList(u8).init(allocator),
        .ndots = 1,
        .timeout = 5,
        .attempts = 2,
    };
    errdefer rc.deinit();

    const file = fs.openFileAbsoluteZ("/etc/resolv.conf", .{}) catch |err| switch (err) {
        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        => return linuxLookupNameFromNumericUnspec(&rc.ns, "127.0.0.1", 53),
        else => |e| return e,
    };
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const stream = buf_reader.reader();
    var line_buf: [512]u8 = undefined;
    while (stream.readUntilDelimiterOrEof(&line_buf, '\n') catch |err| switch (err) {
        error.StreamTooLong => blk: {
            // Skip to the delimiter in the stream, to fix parsing
            try stream.skipUntilDelimiterOrEof('\n');
            // Give an empty line to the while loop, which will be skipped.
            break :blk line_buf[0..0];
        },
        else => |e| return e,
    }) |line| {
        const no_comment_line = no_comment_line: {
            var split = mem.splitScalar(u8, line, '#');
            break :no_comment_line split.first();
        };
        var line_it = mem.tokenizeAny(u8, no_comment_line, " \t");

        const token = line_it.next() orelse continue;
        if (mem.eql(u8, token, "options")) {
            while (line_it.next()) |sub_tok| {
                var colon_it = mem.splitScalar(u8, sub_tok, ':');
                const name = colon_it.first();
                const value_txt = colon_it.next() orelse continue;
                const value = std.fmt.parseInt(u8, value_txt, 10) catch |err| switch (err) {
                    // TODO https://github.com/ziglang/zig/issues/11812
                    error.Overflow => @as(u8, 255),
                    error.InvalidCharacter => continue,
                };
                if (mem.eql(u8, name, "ndots")) {
                    rc.ndots = @min(value, 15);
                } else if (mem.eql(u8, name, "attempts")) {
                    rc.attempts = @min(value, 10);
                } else if (mem.eql(u8, name, "timeout")) {
                    rc.timeout = @min(value, 60);
                }
            }
        } else if (mem.eql(u8, token, "nameserver")) {
            const ip_txt = line_it.next() orelse continue;
            try linuxLookupNameFromNumericUnspec(&rc.ns, ip_txt, 53);
        } else if (mem.eql(u8, token, "domain") or mem.eql(u8, token, "search")) {
            rc.search.items.len = 0;
            try rc.search.appendSlice(line_it.rest());
        }
    }

    if (rc.ns.items.len == 0) {
        return linuxLookupNameFromNumericUnspec(&rc.ns, "127.0.0.1", 53);
    }
}

fn linuxLookupNameFromNumericUnspec(
    addrs: *std.ArrayList(LookupAddr),
    name: []const u8,
    port: u16,
) !void {
    const addr = try Address.resolveIp(name, port);
    (try addrs.addOne()).* = LookupAddr{ .addr = addr };
}

fn resMSendRc(
    queries: []const []const u8,
    answers: [][]u8,
    answer_bufs: []const []u8,
    rc: ResolvConf,
) !void {
    const timeout = 1000 * rc.timeout;
    const attempts = rc.attempts;

    var sl: os.socklen_t = @sizeOf(os.sockaddr.in);
    var family: os.sa_family_t = os.AF.INET;

    var ns_list = std.ArrayList(Address).init(rc.ns.allocator);
    defer ns_list.deinit();

    try ns_list.resize(rc.ns.items.len);
    const ns = ns_list.items;

    for (rc.ns.items, 0..) |iplit, i| {
        ns[i] = iplit.addr;
        assert(ns[i].getPort() == 53);
        if (iplit.addr.any.family != os.AF.INET) {
            family = os.AF.INET6;
        }
    }

    const flags = os.SOCK.DGRAM | os.SOCK.CLOEXEC | os.SOCK.NONBLOCK;
    const fd = os.socket(family, flags, 0) catch |err| switch (err) {
        error.AddressFamilyNotSupported => blk: {
            // Handle case where system lacks IPv6 support
            if (family == os.AF.INET6) {
                family = os.AF.INET;
                break :blk try os.socket(os.AF.INET, flags, 0);
            }
            return err;
        },
        else => |e| return e,
    };
    defer os.closeSocket(fd);

    // Past this point, there are no errors. Each individual query will
    // yield either no reply (indicated by zero length) or an answer
    // packet which is up to the caller to interpret.

    // Convert any IPv4 addresses in a mixed environment to v4-mapped
    if (family == os.AF.INET6) {
        try os.setsockopt(
            fd,
            os.SOL.IPV6,
            os.linux.IPV6.V6ONLY,
            &mem.toBytes(@as(c_int, 0)),
        );
        for (0..ns.len) |i| {
            if (ns[i].any.family != os.AF.INET) continue;
            mem.writeIntNative(u32, ns[i].in6.sa.addr[12..], ns[i].in.sa.addr);
            ns[i].in6.sa.addr[0..12].* = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff".*;
            ns[i].any.family = os.AF.INET6;
            ns[i].in6.sa.flowinfo = 0;
            ns[i].in6.sa.scope_id = 0;
        }
        sl = @sizeOf(os.sockaddr.in6);
    }

    // Get local address and open/bind a socket
    var sa: Address = undefined;
    @memset(@as([*]u8, @ptrCast(&sa))[0..@sizeOf(Address)], 0);
    sa.any.family = family;
    try os.bind(fd, &sa.any, sl);

    var pfd = [1]os.pollfd{os.pollfd{
        .fd = fd,
        .events = os.POLL.IN,
        .revents = undefined,
    }};
    const retry_interval = timeout / attempts;
    var next: u32 = 0;
    var t2: u64 = @as(u64, @bitCast(std.time.milliTimestamp()));
    var t0 = t2;
    var t1 = t2 - retry_interval;

    var servfail_retry: usize = undefined;

    outer: while (t2 - t0 < timeout) : (t2 = @as(u64, @bitCast(std.time.milliTimestamp()))) {
        if (t2 - t1 >= retry_interval) {
            // Query all configured nameservers in parallel
            var i: usize = 0;
            while (i < queries.len) : (i += 1) {
                if (answers[i].len == 0) {
                    var j: usize = 0;
                    while (j < ns.len) : (j += 1) {
                        if (std.io.is_async) {
                            _ = std.event.Loop.instance.?.sendto(fd, queries[i], os.MSG.NOSIGNAL, &ns[j].any, sl) catch undefined;
                        } else {
                            _ = os.sendto(fd, queries[i], os.MSG.NOSIGNAL, &ns[j].any, sl) catch undefined;
                        }
                    }
                }
            }
            t1 = t2;
            servfail_retry = 2 * queries.len;
        }

        // Wait for a response, or until time to retry
        const clamped_timeout = @min(@as(u31, std.math.maxInt(u31)), t1 + retry_interval - t2);
        const nevents = os.poll(&pfd, clamped_timeout) catch 0;
        if (nevents == 0) continue;

        while (true) {
            var sl_copy = sl;
            const rlen = if (std.io.is_async)
                std.event.Loop.instance.?.recvfrom(fd, answer_bufs[next], 0, &sa.any, &sl_copy) catch break
            else
                os.recvfrom(fd, answer_bufs[next], 0, &sa.any, &sl_copy) catch break;

            // Ignore non-identifiable packets
            if (rlen < 4) continue;

            // Ignore replies from addresses we didn't send to
            var j: usize = 0;
            while (j < ns.len and !ns[j].eql(sa)) : (j += 1) {}
            if (j == ns.len) continue;

            // Find which query this answer goes with, if any
            var i: usize = next;
            while (i < queries.len and (answer_bufs[next][0] != queries[i][0] or
                answer_bufs[next][1] != queries[i][1])) : (i += 1)
            {}

            if (i == queries.len) continue;
            if (answers[i].len != 0) continue;

            // Only accept positive or negative responses;
            // retry immediately on server failure, and ignore
            // all other codes such as refusal.
            switch (answer_bufs[next][3] & 15) {
                0, 3 => {},
                2 => if (servfail_retry != 0) {
                    servfail_retry -= 1;
                    if (std.io.is_async) {
                        _ = std.event.Loop.instance.?.sendto(fd, queries[i], os.MSG.NOSIGNAL, &ns[j].any, sl) catch undefined;
                    } else {
                        _ = os.sendto(fd, queries[i], os.MSG.NOSIGNAL, &ns[j].any, sl) catch undefined;
                    }
                },
                else => continue,
            }

            // Store answer in the right slot, or update next
            // available temp slot if it's already in place.
            answers[i].len = rlen;
            if (i == next) {
                while (next < queries.len and answers[next].len != 0) : (next += 1) {}
            } else {
                @memcpy(answer_bufs[i][0..rlen], answer_bufs[next][0..rlen]);
            }

            if (next == queries.len) break :outer;
        }
    }
}

fn dnsParse(
    r: []const u8,
    ctx: anytype,
    comptime callback: anytype,
) !void {
    // This implementation is ported from musl libc.
    // A more idiomatic "ziggy" implementation would be welcome.
    if (r.len < 12) return error.InvalidDnsPacket;
    if ((r[3] & 15) != 0) return;
    var p = r.ptr + 12;
    var qdcount = r[4] * @as(usize, 256) + r[5];
    var ancount = r[6] * @as(usize, 256) + r[7];
    if (qdcount + ancount > 64) return error.InvalidDnsPacket;
    while (qdcount != 0) {
        qdcount -= 1;
        while (@intFromPtr(p) - @intFromPtr(r.ptr) < r.len and p[0] -% 1 < 127) p += 1;
        if (p[0] > 193 or (p[0] == 193 and p[1] > 254) or @intFromPtr(p) > @intFromPtr(r.ptr) + r.len - 6)
            return error.InvalidDnsPacket;
        p += @as(usize, 5) + @intFromBool(p[0] != 0);
    }
    while (ancount != 0) {
        ancount -= 1;
        while (@intFromPtr(p) - @intFromPtr(r.ptr) < r.len and p[0] -% 1 < 127) p += 1;
        if (p[0] > 193 or (p[0] == 193 and p[1] > 254) or @intFromPtr(p) > @intFromPtr(r.ptr) + r.len - 6)
            return error.InvalidDnsPacket;
        p += @as(usize, 1) + @intFromBool(p[0] != 0);
        const len = p[8] * @as(usize, 256) + p[9];
        if (@intFromPtr(p) + len > @intFromPtr(r.ptr) + r.len) return error.InvalidDnsPacket;
        try callback(ctx, p[1], p[10..][0..len], r);
        p += 10 + len;
    }
}

fn dnsParseCallback(ctx: dpc_ctx, rr: u8, data: []const u8, packet: []const u8) !void {
    switch (rr) {
        os.RR.A => {
            if (data.len != 4) return error.InvalidDnsARecord;
            const new_addr = try ctx.addrs.addOne();
            new_addr.* = LookupAddr{
                .addr = Address.initIp4(data[0..4].*, ctx.port),
            };
        },
        os.RR.AAAA => {
            if (data.len != 16) return error.InvalidDnsAAAARecord;
            const new_addr = try ctx.addrs.addOne();
            new_addr.* = LookupAddr{
                .addr = Address.initIp6(data[0..16].*, ctx.port, 0, 0),
            };
        },
        os.RR.CNAME => {
            var tmp: [256]u8 = undefined;
            // Returns len of compressed name. strlen to get canon name.
            _ = try os.dn_expand(packet, data, &tmp);
            const canon_name = mem.sliceTo(&tmp, 0);
            if (isValidHostName(canon_name)) {
                ctx.canon.items.len = 0;
                try ctx.canon.appendSlice(canon_name);
            }
        },
        else => return,
    }
}

pub const Stream = struct {
    // Underlying socket descriptor.
    // Note that on some platforms this may not be interchangeable with a
    // regular files descriptor.
    handle: os.socket_t,

    pub fn close(self: Stream) void {
        os.closeSocket(self.handle);
    }

    pub const ReadError = os.ReadError;
    pub const WriteError = os.WriteError;

    pub const Reader = io.Reader(Stream, ReadError, read);
    pub const Writer = io.Writer(Stream, WriteError, write);

    pub fn reader(self: Stream) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: Stream) Writer {
        return .{ .context = self };
    }

    pub fn read(self: Stream, buffer: []u8) ReadError!usize {
        if (builtin.os.tag == .windows) {
            return os.windows.ReadFile(self.handle, buffer, null, io.default_mode);
        }

        if (std.io.is_async) {
            return std.event.Loop.instance.?.read(self.handle, buffer, false);
        } else {
            return os.read(self.handle, buffer);
        }
    }

    pub fn readv(s: Stream, iovecs: []const os.iovec) ReadError!usize {
        if (builtin.os.tag == .windows) {
            // TODO improve this to use ReadFileScatter
            if (iovecs.len == 0) return @as(usize, 0);
            const first = iovecs[0];
            return os.windows.ReadFile(s.handle, first.iov_base[0..first.iov_len], null, io.default_mode);
        }

        return os.readv(s.handle, iovecs);
    }

    /// Returns the number of bytes read. If the number read is smaller than
    /// `buffer.len`, it means the stream reached the end. Reaching the end of
    /// a stream is not an error condition.
    pub fn readAll(s: Stream, buffer: []u8) ReadError!usize {
        return readAtLeast(s, buffer, buffer.len);
    }

    /// Returns the number of bytes read, calling the underlying read function
    /// the minimal number of times until the buffer has at least `len` bytes
    /// filled. If the number read is less than `len` it means the stream
    /// reached the end. Reaching the end of the stream is not an error
    /// condition.
    pub fn readAtLeast(s: Stream, buffer: []u8, len: usize) ReadError!usize {
        assert(len <= buffer.len);
        var index: usize = 0;
        while (index < len) {
            const amt = try s.read(buffer[index..]);
            if (amt == 0) break;
            index += amt;
        }
        return index;
    }

    /// TODO in evented I/O mode, this implementation incorrectly uses the event loop's
    /// file system thread instead of non-blocking. It needs to be reworked to properly
    /// use non-blocking I/O.
    pub fn write(self: Stream, buffer: []const u8) WriteError!usize {
        if (builtin.os.tag == .windows) {
            return os.windows.WriteFile(self.handle, buffer, null, io.default_mode);
        }

        if (std.io.is_async) {
            return std.event.Loop.instance.?.write(self.handle, buffer, false);
        } else {
            return os.write(self.handle, buffer);
        }
    }

    pub fn writeAll(self: Stream, bytes: []const u8) WriteError!void {
        var index: usize = 0;
        while (index < bytes.len) {
            index += try self.write(bytes[index..]);
        }
    }

    /// See https://github.com/ziglang/zig/issues/7699
    /// See equivalent function: `std.fs.File.writev`.
    pub fn writev(self: Stream, iovecs: []const os.iovec_const) WriteError!usize {
        if (std.io.is_async) {
            // TODO improve to actually take advantage of writev syscall, if available.
            if (iovecs.len == 0) return 0;
            const first_buffer = iovecs[0].iov_base[0..iovecs[0].iov_len];
            try self.write(first_buffer);
            return first_buffer.len;
        } else {
            return os.writev(self.handle, iovecs);
        }
    }

    /// The `iovecs` parameter is mutable because this function needs to mutate the fields in
    /// order to handle partial writes from the underlying OS layer.
    /// See https://github.com/ziglang/zig/issues/7699
    /// See equivalent function: `std.fs.File.writevAll`.
    pub fn writevAll(self: Stream, iovecs: []os.iovec_const) WriteError!void {
        if (iovecs.len == 0) return;

        var i: usize = 0;
        while (true) {
            var amt = try self.writev(iovecs[i..]);
            while (amt >= iovecs[i].iov_len) {
                amt -= iovecs[i].iov_len;
                i += 1;
                if (i >= iovecs.len) return;
            }
            iovecs[i].iov_base += amt;
            iovecs[i].iov_len -= amt;
        }
    }
};

pub const StreamServer = struct {
    /// Copied from `Options` on `init`.
    kernel_backlog: u31,
    reuse_address: bool,
    reuse_port: bool,

    /// `undefined` until `listen` returns successfully.
    listen_address: Address,

    sockfd: ?os.socket_t,

    pub const Options = struct {
        /// How many connections the kernel will accept on the application's behalf.
        /// If more than this many connections pool in the kernel, clients will start
        /// seeing "Connection refused".
        kernel_backlog: u31 = 128,

        /// Enable SO.REUSEADDR on the socket.
        reuse_address: bool = false,

        /// Enable SO.REUSEPORT on the socket.
        reuse_port: bool = false,
    };

    /// After this call succeeds, resources have been acquired and must
    /// be released with `deinit`.
    pub fn init(options: Options) StreamServer {
        return StreamServer{
            .sockfd = null,
            .kernel_backlog = options.kernel_backlog,
            .reuse_address = options.reuse_address,
            .reuse_port = options.reuse_port,
            .listen_address = undefined,
        };
    }

    /// Release all resources. The `StreamServer` memory becomes `undefined`.
    pub fn deinit(self: *StreamServer) void {
        self.close();
        self.* = undefined;
    }

    pub fn listen(self: *StreamServer, address: Address) !void {
        const nonblock = if (std.io.is_async) os.SOCK.NONBLOCK else 0;
        const sock_flags = os.SOCK.STREAM | os.SOCK.CLOEXEC | nonblock;
        const proto = if (address.any.family == os.AF.UNIX) @as(u32, 0) else os.IPPROTO.TCP;

        const sockfd = try os.socket(address.any.family, sock_flags, proto);
        self.sockfd = sockfd;
        errdefer {
            os.closeSocket(sockfd);
            self.sockfd = null;
        }

        if (self.reuse_address) {
            try os.setsockopt(
                sockfd,
                os.SOL.SOCKET,
                os.SO.REUSEADDR,
                &mem.toBytes(@as(c_int, 1)),
            );
        }
        if (@hasDecl(os.SO, "REUSEPORT") and self.reuse_port) {
            try os.setsockopt(
                sockfd,
                os.SOL.SOCKET,
                os.SO.REUSEPORT,
                &mem.toBytes(@as(c_int, 1)),
            );
        }

        var socklen = address.getOsSockLen();
        try os.bind(sockfd, &address.any, socklen);
        try os.listen(sockfd, self.kernel_backlog);
        try os.getsockname(sockfd, &self.listen_address.any, &socklen);
    }

    /// Stop listening. It is still necessary to call `deinit` after stopping listening.
    /// Calling `deinit` will automatically call `close`. It is safe to call `close` when
    /// not listening.
    pub fn close(self: *StreamServer) void {
        if (self.sockfd) |fd| {
            os.closeSocket(fd);
            self.sockfd = null;
            self.listen_address = undefined;
        }
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
        stream: Stream,
        address: Address,
    };

    /// If this function succeeds, the returned `Connection` is a caller-managed resource.
    pub fn accept(self: *StreamServer) AcceptError!Connection {
        var accepted_addr: Address = undefined;
        var adr_len: os.socklen_t = @sizeOf(Address);
        const accept_result = blk: {
            if (std.io.is_async) {
                const loop = std.event.Loop.instance orelse return error.UnexpectedError;
                break :blk loop.accept(self.sockfd.?, &accepted_addr.any, &adr_len, os.SOCK.CLOEXEC);
            } else {
                break :blk os.accept(self.sockfd.?, &accepted_addr.any, &adr_len, os.SOCK.CLOEXEC);
            }
        };

        if (accept_result) |fd| {
            return Connection{
                .stream = Stream{ .handle = fd },
                .address = accepted_addr,
            };
        } else |err| switch (err) {
            error.WouldBlock => unreachable,
            else => |e| return e,
        }
    }
};

test {
    _ = @import("net/test.zig");
}
