//! Cross-platform networking abstractions.

const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const net = @This();
const mem = std.mem;
const posix = std.posix;
const fs = std.fs;
const io = std.io;
const native_endian = builtin.target.cpu.arch.endian();
const native_os = builtin.os.tag;
const windows = std.os.windows;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const File = std.fs.File;

// Windows 10 added support for unix sockets in build 17063, redstone 4 is the
// first release to support them.
pub const has_unix_sockets = switch (native_os) {
    .windows => builtin.os.version_range.windows.isAtLeast(.win10_rs4) orelse false,
    else => true,
};

pub const IPParseError = error{
    Overflow,
    InvalidEnd,
    InvalidCharacter,
    Incomplete,
};

pub const IPv4ParseError = IPParseError || error{NonCanonical};

pub const IPv6ParseError = IPParseError || error{InvalidIpv4Mapping};
pub const IPv6InterfaceError = posix.SocketError || posix.IoCtl_SIOCGIFINDEX_Error || error{NameTooLong};
pub const IPv6ResolveError = IPv6ParseError || IPv6InterfaceError;

pub const Address = extern union {
    any: posix.sockaddr,
    in: Ip4Address,
    in6: Ip6Address,
    un: if (has_unix_sockets) posix.sockaddr.un else void,

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

    pub fn parseExpectingFamily(name: []const u8, family: posix.sa_family_t, port: u16) !Address {
        switch (family) {
            posix.AF.INET => return parseIp4(name, port),
            posix.AF.INET6 => return parseIp6(name, port),
            posix.AF.UNSPEC => return parseIp(name, port),
            else => unreachable,
        }
    }

    pub fn parseIp6(buf: []const u8, port: u16) IPv6ParseError!Address {
        return .{ .in6 = try Ip6Address.parse(buf, port) };
    }

    pub fn resolveIp6(buf: []const u8, port: u16) IPv6ResolveError!Address {
        return .{ .in6 = try Ip6Address.resolve(buf, port) };
    }

    pub fn parseIp4(buf: []const u8, port: u16) IPv4ParseError!Address {
        return .{ .in = try Ip4Address.parse(buf, port) };
    }

    pub fn initIp4(addr: [4]u8, port: u16) Address {
        return .{ .in = Ip4Address.init(addr, port) };
    }

    pub fn initIp6(addr: [16]u8, port: u16, flowinfo: u32, scope_id: u32) Address {
        return .{ .in6 = Ip6Address.init(addr, port, flowinfo, scope_id) };
    }

    pub fn initUnix(path: []const u8) !Address {
        var sock_addr = posix.sockaddr.un{
            .family = posix.AF.UNIX,
            .path = undefined,
        };

        // Add 1 to ensure a terminating 0 is present in the path array for maximum portability.
        if (path.len + 1 > sock_addr.path.len) return error.NameTooLong;

        @memset(&sock_addr.path, 0);
        @memcpy(sock_addr.path[0..path.len], path);

        return .{ .un = sock_addr };
    }

    /// Returns the port in native endian.
    /// Asserts that the address is ip4 or ip6.
    pub fn getPort(self: Address) u16 {
        return switch (self.any.family) {
            posix.AF.INET => self.in.getPort(),
            posix.AF.INET6 => self.in6.getPort(),
            else => unreachable,
        };
    }

    /// `port` is native-endian.
    /// Asserts that the address is ip4 or ip6.
    pub fn setPort(self: *Address, port: u16) void {
        switch (self.any.family) {
            posix.AF.INET => self.in.setPort(port),
            posix.AF.INET6 => self.in6.setPort(port),
            else => unreachable,
        }
    }

    /// Asserts that `addr` is an IP address.
    /// This function will read past the end of the pointer, with a size depending
    /// on the address family.
    pub fn initPosix(addr: *align(4) const posix.sockaddr) Address {
        switch (addr.family) {
            posix.AF.INET => return Address{ .in = Ip4Address{ .sa = @as(*const posix.sockaddr.in, @ptrCast(addr)).* } },
            posix.AF.INET6 => return Address{ .in6 = Ip6Address{ .sa = @as(*const posix.sockaddr.in6, @ptrCast(addr)).* } },
            else => unreachable,
        }
    }

    pub fn format(self: Address, w: *std.io.Writer) std.io.Writer.Error!void {
        switch (self.any.family) {
            posix.AF.INET => try self.in.format(w),
            posix.AF.INET6 => try self.in6.format(w),
            posix.AF.UNIX => {
                if (!has_unix_sockets) unreachable;
                try w.writeAll(std.mem.sliceTo(&self.un.path, 0));
            },
            else => unreachable,
        }
    }

    pub fn eql(a: Address, b: Address) bool {
        const a_bytes = @as([*]const u8, @ptrCast(&a.any))[0..a.getOsSockLen()];
        const b_bytes = @as([*]const u8, @ptrCast(&b.any))[0..b.getOsSockLen()];
        return mem.eql(u8, a_bytes, b_bytes);
    }

    pub fn getOsSockLen(self: Address) posix.socklen_t {
        switch (self.any.family) {
            posix.AF.INET => return self.in.getOsSockLen(),
            posix.AF.INET6 => return self.in6.getOsSockLen(),
            posix.AF.UNIX => {
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
                return @as(posix.socklen_t, @intCast(@sizeOf(posix.sockaddr.un)));
            },

            else => unreachable,
        }
    }

    pub const ListenError = posix.SocketError || posix.BindError || posix.ListenError ||
        posix.SetSockOptError || posix.GetSockNameError;

    pub const ListenOptions = struct {
        /// How many connections the kernel will accept on the application's behalf.
        /// If more than this many connections pool in the kernel, clients will start
        /// seeing "Connection refused".
        kernel_backlog: u31 = 128,
        /// Sets SO_REUSEADDR and SO_REUSEPORT on POSIX.
        /// Sets SO_REUSEADDR on Windows, which is roughly equivalent.
        reuse_address: bool = false,
        /// Deprecated. Does the same thing as reuse_address.
        reuse_port: bool = false,
        force_nonblocking: bool = false,
    };

    /// The returned `Server` has an open `stream`.
    pub fn listen(address: Address, options: ListenOptions) ListenError!Server {
        const nonblock: u32 = if (options.force_nonblocking) posix.SOCK.NONBLOCK else 0;
        const sock_flags = posix.SOCK.STREAM | posix.SOCK.CLOEXEC | nonblock;
        const proto: u32 = if (address.any.family == posix.AF.UNIX) 0 else posix.IPPROTO.TCP;

        const sockfd = try posix.socket(address.any.family, sock_flags, proto);
        var s: Server = .{
            .listen_address = undefined,
            .stream = .{ .handle = sockfd },
        };
        errdefer s.stream.close();

        if (options.reuse_address or options.reuse_port) {
            try posix.setsockopt(
                sockfd,
                posix.SOL.SOCKET,
                posix.SO.REUSEADDR,
                &mem.toBytes(@as(c_int, 1)),
            );
            if (@hasDecl(posix.SO, "REUSEPORT") and address.any.family != posix.AF.UNIX) {
                try posix.setsockopt(
                    sockfd,
                    posix.SOL.SOCKET,
                    posix.SO.REUSEPORT,
                    &mem.toBytes(@as(c_int, 1)),
                );
            }
        }

        var socklen = address.getOsSockLen();
        try posix.bind(sockfd, &address.any, socklen);
        try posix.listen(sockfd, options.kernel_backlog);
        try posix.getsockname(sockfd, &s.listen_address.any, &socklen);
        return s;
    }
};

pub const Ip4Address = extern struct {
    sa: posix.sockaddr.in,

    pub fn parse(buf: []const u8, port: u16) IPv4ParseError!Ip4Address {
        var result: Ip4Address = .{
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
            error.NonCanonical,
            => {},
        }
        return error.InvalidIPAddressFormat;
    }

    pub fn init(addr: [4]u8, port: u16) Ip4Address {
        return Ip4Address{
            .sa = posix.sockaddr.in{
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

    pub fn format(self: Ip4Address, w: *std.io.Writer) std.io.Writer.Error!void {
        const bytes: *const [4]u8 = @ptrCast(&self.sa.addr);
        try w.print("{d}.{d}.{d}.{d}:{d}", .{ bytes[0], bytes[1], bytes[2], bytes[3], self.getPort() });
    }

    pub fn getOsSockLen(self: Ip4Address) posix.socklen_t {
        _ = self;
        return @sizeOf(posix.sockaddr.in);
    }
};

pub const Ip6Address = extern struct {
    sa: posix.sockaddr.in6,

    /// Parse a given IPv6 address string into an Address.
    /// Assumes the Scope ID of the address is fully numeric.
    /// For non-numeric addresses, see `resolveIp6`.
    pub fn parse(buf: []const u8, port: u16) IPv6ParseError!Ip6Address {
        var result = Ip6Address{
            .sa = posix.sockaddr.in6{
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
        if (!abbrv and index < 14) {
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

    pub fn resolve(buf: []const u8, port: u16) IPv6ResolveError!Ip6Address {
        // TODO: Unify the implementations of resolveIp6 and parseIp6.
        var result = Ip6Address{
            .sa = posix.sockaddr.in6{
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
        var scope_id_value: [posix.IFNAMESIZE - 1]u8 = undefined;
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
            .sa = posix.sockaddr.in6{
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

    pub fn format(self: Ip6Address, w: *std.io.Writer) std.io.Writer.Error!void {
        const port = mem.bigToNative(u16, self.sa.port);
        if (mem.eql(u8, self.sa.addr[0..12], &[_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff })) {
            try w.print("[::ffff:{d}.{d}.{d}.{d}]:{d}", .{
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
            .big => big_endian_parts.*,
            .little => blk: {
                var buf: [8]u16 = undefined;
                for (big_endian_parts, 0..) |part, i| {
                    buf[i] = mem.bigToNative(u16, part);
                }
                break :blk buf;
            },
        };

        // Find the longest zero run
        var longest_start: usize = 8;
        var longest_len: usize = 0;
        var current_start: usize = 0;
        var current_len: usize = 0;

        for (native_endian_parts, 0..) |part, i| {
            if (part == 0) {
                if (current_len == 0) {
                    current_start = i;
                }
                current_len += 1;
                if (current_len > longest_len) {
                    longest_start = current_start;
                    longest_len = current_len;
                }
            } else {
                current_len = 0;
            }
        }

        // Only compress if the longest zero run is 2 or more
        if (longest_len < 2) {
            longest_start = 8;
            longest_len = 0;
        }

        try w.writeAll("[");
        var i: usize = 0;
        var abbrv = false;
        while (i < native_endian_parts.len) : (i += 1) {
            if (i == longest_start) {
                // Emit "::" for the longest zero run
                if (!abbrv) {
                    try w.writeAll(if (i == 0) "::" else ":");
                    abbrv = true;
                }
                i += longest_len - 1; // Skip the compressed range
                continue;
            }
            if (abbrv) {
                abbrv = false;
            }
            try w.print("{x}", .{native_endian_parts[i]});
            if (i != native_endian_parts.len - 1) {
                try w.writeAll(":");
            }
        }
        try w.print("]:{}", .{port});
    }

    pub fn getOsSockLen(self: Ip6Address) posix.socklen_t {
        _ = self;
        return @sizeOf(posix.sockaddr.in6);
    }
};

pub fn connectUnixSocket(path: []const u8) !Stream {
    const opt_non_block = 0;
    const sockfd = try posix.socket(
        posix.AF.UNIX,
        posix.SOCK.STREAM | posix.SOCK.CLOEXEC | opt_non_block,
        0,
    );
    errdefer Stream.close(.{ .handle = sockfd });

    var addr = try Address.initUnix(path);
    try posix.connect(sockfd, &addr.any, addr.getOsSockLen());

    return .{ .handle = sockfd };
}

fn if_nametoindex(name: []const u8) IPv6InterfaceError!u32 {
    if (native_os == .linux) {
        var ifr: posix.ifreq = undefined;
        const sockfd = try posix.socket(posix.AF.UNIX, posix.SOCK.DGRAM | posix.SOCK.CLOEXEC, 0);
        defer Stream.close(.{ .handle = sockfd });

        @memcpy(ifr.ifrn.name[0..name.len], name);
        ifr.ifrn.name[name.len] = 0;

        // TODO investigate if this needs to be integrated with evented I/O.
        try posix.ioctl_SIOCGIFINDEX(sockfd, &ifr);

        return @bitCast(ifr.ifru.ivalue);
    }

    if (native_os.isDarwin()) {
        if (name.len >= posix.IFNAMESIZE)
            return error.NameTooLong;

        var if_name: [posix.IFNAMESIZE:0]u8 = undefined;
        @memcpy(if_name[0..name.len], name);
        if_name[name.len] = 0;
        const if_slice = if_name[0..name.len :0];
        const index = std.c.if_nametoindex(if_slice);
        if (index == 0)
            return error.InterfaceNotFound;
        return @as(u32, @bitCast(index));
    }

    if (native_os == .windows) {
        if (name.len >= posix.IFNAMESIZE)
            return error.NameTooLong;

        var interface_name: [posix.IFNAMESIZE:0]u8 = undefined;
        @memcpy(interface_name[0..name.len], name);
        interface_name[name.len] = 0;
        const index = std.os.windows.ws2_32.if_nametoindex(@as([*:0]const u8, &interface_name));
        if (index == 0)
            return error.InterfaceNotFound;
        return index;
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
pub fn tcpConnectToHost(allocator: Allocator, name: []const u8, port: u16) TcpConnectToHostError!Stream {
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
    return posix.ConnectError.ConnectionRefused;
}

pub const TcpConnectToAddressError = posix.SocketError || posix.ConnectError;

pub fn tcpConnectToAddress(address: Address) TcpConnectToAddressError!Stream {
    const nonblock = 0;
    const sock_flags = posix.SOCK.STREAM | nonblock |
        (if (native_os == .windows) 0 else posix.SOCK.CLOEXEC);
    const sockfd = try posix.socket(address.any.family, sock_flags, posix.IPPROTO.TCP);
    errdefer Stream.close(.{ .handle = sockfd });

    try posix.connect(sockfd, &address.any, address.getOsSockLen());

    return Stream{ .handle = sockfd };
}

// TODO: Instead of having a massive error set, make the error set have categories, and then
// store the sub-error as a diagnostic value.
const GetAddressListError = Allocator.Error || File.OpenError || File.ReadError || posix.SocketError || posix.BindError || posix.SetSockOptError || error{
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
    ResolveConfParseFailed,
};

/// Call `AddressList.deinit` on the result.
pub fn getAddressList(gpa: Allocator, name: []const u8, port: u16) GetAddressListError!*AddressList {
    const result = blk: {
        var arena = std.heap.ArenaAllocator.init(gpa);
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

    if (native_os == .windows) {
        const name_c = try gpa.dupeZ(u8, name);
        defer gpa.free(name_c);

        const port_c = try std.fmt.allocPrintSentinel(gpa, "{}", .{port}, 0);
        defer gpa.free(port_c);

        const ws2_32 = windows.ws2_32;
        const hints: posix.addrinfo = .{
            .flags = .{ .NUMERICSERV = true },
            .family = posix.AF.UNSPEC,
            .socktype = posix.SOCK.STREAM,
            .protocol = posix.IPPROTO.TCP,
            .canonname = null,
            .addr = null,
            .addrlen = 0,
            .next = null,
        };
        var res: ?*posix.addrinfo = null;
        var first = true;
        while (true) {
            const rc = ws2_32.getaddrinfo(name_c.ptr, port_c.ptr, &hints, &res);
            switch (@as(windows.ws2_32.WinsockError, @enumFromInt(@as(u16, @intCast(rc))))) {
                @as(windows.ws2_32.WinsockError, @enumFromInt(0)) => break,
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
                    try windows.callWSAStartup();
                    continue;
                },
                else => |err| return windows.unexpectedWSAError(err),
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
        const name_c = try gpa.dupeZ(u8, name);
        defer gpa.free(name_c);

        const port_c = try std.fmt.allocPrintSentinel(gpa, "{d}", .{port}, 0);
        defer gpa.free(port_c);

        const hints: posix.addrinfo = .{
            .flags = .{ .NUMERICSERV = true },
            .family = posix.AF.UNSPEC,
            .socktype = posix.SOCK.STREAM,
            .protocol = posix.IPPROTO.TCP,
            .canonname = null,
            .addr = null,
            .addrlen = 0,
            .next = null,
        };
        var res: ?*posix.addrinfo = null;
        switch (posix.system.getaddrinfo(name_c.ptr, port_c.ptr, &hints, &res)) {
            @as(posix.system.EAI, @enumFromInt(0)) => {},
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
            .SYSTEM => switch (posix.errno(-1)) {
                else => |e| return posix.unexpectedErrno(e),
            },
            else => unreachable,
        }
        defer if (res) |some| posix.system.freeaddrinfo(some);

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

    if (native_os == .linux) {
        const family = posix.AF.UNSPEC;
        var lookup_addrs: ArrayList(LookupAddr) = .empty;
        defer lookup_addrs.deinit(gpa);

        var canon: ArrayList(u8) = .empty;
        defer canon.deinit(gpa);

        try linuxLookupName(gpa, &lookup_addrs, &canon, name, family, .{ .NUMERICSERV = true }, port);

        result.addrs = try arena.alloc(Address, lookup_addrs.items.len);
        if (canon.items.len != 0) {
            result.canon_name = try arena.dupe(u8, canon.items);
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
    gpa: Allocator,
    addrs: *ArrayList(LookupAddr),
    canon: *ArrayList(u8),
    opt_name: ?[]const u8,
    family: posix.sa_family_t,
    flags: posix.AI,
    port: u16,
) !void {
    if (opt_name) |name| {
        // reject empty name and check len so it fits into temp bufs
        canon.items.len = 0;
        try canon.appendSlice(gpa, name);
        if (Address.parseExpectingFamily(name, family, port)) |addr| {
            try addrs.append(gpa, .{ .addr = addr });
        } else |name_err| if (flags.NUMERICHOST) {
            return name_err;
        } else {
            try linuxLookupNameFromHosts(gpa, addrs, canon, name, family, port);
            if (addrs.items.len == 0) {
                // RFC 6761 Section 6.3.3
                // Name resolution APIs and libraries SHOULD recognize localhost
                // names as special and SHOULD always return the IP loopback address
                // for address queries and negative responses for all other query
                // types.

                // Check for equal to "localhost(.)" or ends in ".localhost(.)"
                const localhost = if (name[name.len - 1] == '.') "localhost." else "localhost";
                if (mem.endsWith(u8, name, localhost) and (name.len == localhost.len or name[name.len - localhost.len] == '.')) {
                    try addrs.append(gpa, .{ .addr = .{ .in = Ip4Address.parse("127.0.0.1", port) catch unreachable } });
                    try addrs.append(gpa, .{ .addr = .{ .in6 = Ip6Address.parse("::1", port) catch unreachable } });
                    return;
                }

                try linuxLookupNameFromDnsSearch(gpa, addrs, canon, name, family, port);
            }
        }
    } else {
        try canon.resize(gpa, 0);
        try addrs.ensureUnusedCapacity(gpa, 1);
        linuxLookupNameFromNull(addrs, family, flags, port);
    }
    if (addrs.items.len == 0) return error.UnknownHostName;

    // No further processing is needed if there are fewer than 2
    // results or if there are only IPv4 results.
    if (addrs.items.len == 1 or family == posix.AF.INET) return;
    const all_ip4 = for (addrs.items) |addr| {
        if (addr.addr.any.family != posix.AF.INET) break false;
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
        var sa6: posix.sockaddr.in6 = undefined;
        @memset(@as([*]u8, @ptrCast(&sa6))[0..@sizeOf(posix.sockaddr.in6)], 0);
        var da6 = posix.sockaddr.in6{
            .family = posix.AF.INET6,
            .scope_id = addr.addr.in6.sa.scope_id,
            .port = 65535,
            .flowinfo = 0,
            .addr = [1]u8{0} ** 16,
        };
        var sa4: posix.sockaddr.in = undefined;
        @memset(@as([*]u8, @ptrCast(&sa4))[0..@sizeOf(posix.sockaddr.in)], 0);
        var da4 = posix.sockaddr.in{
            .family = posix.AF.INET,
            .port = 65535,
            .addr = 0,
            .zero = [1]u8{0} ** 8,
        };
        var sa: *align(4) posix.sockaddr = undefined;
        var da: *align(4) posix.sockaddr = undefined;
        var salen: posix.socklen_t = undefined;
        var dalen: posix.socklen_t = undefined;
        if (addr.addr.any.family == posix.AF.INET6) {
            da6.addr = addr.addr.in6.sa.addr;
            da = @ptrCast(&da6);
            dalen = @sizeOf(posix.sockaddr.in6);
            sa = @ptrCast(&sa6);
            salen = @sizeOf(posix.sockaddr.in6);
        } else {
            sa6.addr[0..12].* = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff".*;
            da6.addr[0..12].* = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff".*;
            mem.writeInt(u32, da6.addr[12..], addr.addr.in.sa.addr, native_endian);
            da4.addr = addr.addr.in.sa.addr;
            da = @ptrCast(&da4);
            dalen = @sizeOf(posix.sockaddr.in);
            sa = @ptrCast(&sa4);
            salen = @sizeOf(posix.sockaddr.in);
        }
        const dpolicy = policyOf(da6.addr);
        const dscope: i32 = scopeOf(da6.addr);
        const dlabel = dpolicy.label;
        const dprec: i32 = dpolicy.prec;
        const MAXADDRS = 3;
        var prefixlen: i32 = 0;
        const sock_flags = posix.SOCK.DGRAM | posix.SOCK.CLOEXEC;
        if (posix.socket(addr.addr.any.family, sock_flags, posix.IPPROTO.UDP)) |fd| syscalls: {
            defer Stream.close(.{ .handle = fd });
            posix.connect(fd, da, dalen) catch break :syscalls;
            key |= DAS_USABLE;
            posix.getsockname(fd, sa, &salen) catch break :syscalls;
            if (addr.addr.any.family == posix.AF.INET) {
                mem.writeInt(u32, sa6.addr[12..16], sa4.addr, native_endian);
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
    addrs: *ArrayList(LookupAddr),
    family: posix.sa_family_t,
    flags: posix.AI,
    port: u16,
) void {
    if (flags.PASSIVE) {
        if (family != posix.AF.INET6) {
            addrs.appendAssumeCapacity(.{
                .addr = Address.initIp4([1]u8{0} ** 4, port),
            });
        }
        if (family != posix.AF.INET) {
            addrs.appendAssumeCapacity(.{
                .addr = Address.initIp6([1]u8{0} ** 16, port, 0, 0),
            });
        }
    } else {
        if (family != posix.AF.INET6) {
            addrs.appendAssumeCapacity(.{
                .addr = Address.initIp4([4]u8{ 127, 0, 0, 1 }, port),
            });
        }
        if (family != posix.AF.INET) {
            addrs.appendAssumeCapacity(.{
                .addr = Address.initIp6(([1]u8{0} ** 15) ++ [1]u8{1}, port, 0, 0),
            });
        }
    }
}

fn linuxLookupNameFromHosts(
    gpa: Allocator,
    addrs: *ArrayList(LookupAddr),
    canon: *ArrayList(u8),
    name: []const u8,
    family: posix.sa_family_t,
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

    var line_buf: [512]u8 = undefined;
    var file_reader = file.reader(&line_buf);
    return parseHosts(gpa, addrs, canon, name, family, port, &file_reader.interface) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.ReadFailed => return file_reader.err.?,
    };
}

fn parseHosts(
    gpa: Allocator,
    addrs: *ArrayList(LookupAddr),
    canon: *ArrayList(u8),
    name: []const u8,
    family: posix.sa_family_t,
    port: u16,
    br: *io.Reader,
) error{ OutOfMemory, ReadFailed }!void {
    while (true) {
        const line = br.takeDelimiterExclusive('\n') catch |err| switch (err) {
            error.StreamTooLong => {
                // Skip lines that are too long.
                br.discardDelimiterInclusive('\n') catch |e| switch (e) {
                    error.EndOfStream => break,
                    error.ReadFailed => return error.ReadFailed,
                };
                continue;
            },
            error.ReadFailed => return error.ReadFailed,
            error.EndOfStream => break,
        };
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
        try addrs.append(gpa, .{ .addr = addr });

        // first name is canonical name
        const name_text = first_name_text.?;
        if (isValidHostName(name_text)) {
            canon.items.len = 0;
            try canon.appendSlice(gpa, name_text);
        }
    }
}

pub fn isValidHostName(hostname: []const u8) bool {
    if (hostname.len >= 254) return false;
    if (!std.unicode.utf8ValidateSlice(hostname)) return false;
    for (hostname) |byte| {
        if (!std.ascii.isAscii(byte) or byte == '.' or byte == '-' or std.ascii.isAlphanumeric(byte)) {
            continue;
        }
        return false;
    }
    return true;
}

fn linuxLookupNameFromDnsSearch(
    gpa: Allocator,
    addrs: *ArrayList(LookupAddr),
    canon: *ArrayList(u8),
    name: []const u8,
    family: posix.sa_family_t,
    port: u16,
) !void {
    var rc: ResolvConf = undefined;
    rc.init(gpa) catch return error.ResolveConfParseFailed;
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
    try canon.resize(gpa, canon_name.len);
    @memcpy(canon.items, canon_name);
    try canon.append(gpa, '.');

    var tok_it = mem.tokenizeAny(u8, search, " \t");
    while (tok_it.next()) |tok| {
        canon.shrinkRetainingCapacity(canon_name.len + 1);
        try canon.appendSlice(gpa, tok);
        try linuxLookupNameFromDns(gpa, addrs, canon, canon.items, family, rc, port);
        if (addrs.items.len != 0) return;
    }

    canon.shrinkRetainingCapacity(canon_name.len);
    return linuxLookupNameFromDns(gpa, addrs, canon, name, family, rc, port);
}

const dpc_ctx = struct {
    gpa: Allocator,
    addrs: *ArrayList(LookupAddr),
    canon: *ArrayList(u8),
    port: u16,
};

fn linuxLookupNameFromDns(
    gpa: Allocator,
    addrs: *ArrayList(LookupAddr),
    canon: *ArrayList(u8),
    name: []const u8,
    family: posix.sa_family_t,
    rc: ResolvConf,
    port: u16,
) !void {
    const ctx: dpc_ctx = .{
        .gpa = gpa,
        .addrs = addrs,
        .canon = canon,
        .port = port,
    };
    const AfRr = struct {
        af: posix.sa_family_t,
        rr: u8,
    };
    const afrrs = [_]AfRr{
        .{ .af = posix.AF.INET6, .rr = posix.RR.A },
        .{ .af = posix.AF.INET, .rr = posix.RR.AAAA },
    };
    var qbuf: [2][280]u8 = undefined;
    var abuf: [2][512]u8 = undefined;
    var qp: [2][]const u8 = undefined;
    const apbuf = [2][]u8{ &abuf[0], &abuf[1] };
    var nq: usize = 0;

    for (afrrs) |afrr| {
        if (family != afrr.af) {
            const len = posix.res_mkquery(0, name, 1, afrr.rr, &[_]u8{}, null, &qbuf[nq]);
            qp[nq] = qbuf[nq][0..len];
            nq += 1;
        }
    }

    var ap = [2][]u8{ apbuf[0], apbuf[1] };
    ap[0].len = 0;
    ap[1].len = 0;

    try rc.resMSendRc(qp[0..nq], ap[0..nq], apbuf[0..nq]);

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
    gpa: Allocator,
    attempts: u32,
    ndots: u32,
    timeout: u32,
    search: ArrayList(u8),
    /// TODO there are actually only allowed to be maximum 3 nameservers, no need
    /// for an array list.
    ns: ArrayList(LookupAddr),

    /// Returns `error.StreamTooLong` if a line is longer than 512 bytes.
    /// TODO: https://github.com/ziglang/zig/issues/2765 and https://github.com/ziglang/zig/issues/2761
    fn init(rc: *ResolvConf, gpa: Allocator) !void {
        rc.* = .{
            .gpa = gpa,
            .ns = .empty,
            .search = .empty,
            .ndots = 1,
            .timeout = 5,
            .attempts = 2,
        };
        errdefer rc.deinit();

        const file = fs.openFileAbsoluteZ("/etc/resolv.conf", .{}) catch |err| switch (err) {
            error.FileNotFound,
            error.NotDir,
            error.AccessDenied,
            => return linuxLookupNameFromNumericUnspec(gpa, &rc.ns, "127.0.0.1", 53),
            else => |e| return e,
        };
        defer file.close();

        var line_buf: [512]u8 = undefined;
        var file_reader = file.reader(&line_buf);
        return parse(rc, &file_reader.interface) catch |err| switch (err) {
            error.ReadFailed => return file_reader.err.?,
            else => |e| return e,
        };
    }

    fn parse(rc: *ResolvConf, br: *io.Reader) !void {
        const gpa = rc.gpa;
        while (br.takeSentinel('\n')) |line_with_comment| {
            const line = line: {
                var split = mem.splitScalar(u8, line_with_comment, '#');
                break :line split.first();
            };
            var line_it = mem.tokenizeAny(u8, line, " \t");

            const token = line_it.next() orelse continue;
            if (mem.eql(u8, token, "options")) {
                while (line_it.next()) |sub_tok| {
                    var colon_it = mem.splitScalar(u8, sub_tok, ':');
                    const name = colon_it.first();
                    const value_txt = colon_it.next() orelse continue;
                    const value = std.fmt.parseInt(u8, value_txt, 10) catch |err| switch (err) {
                        error.Overflow => 255,
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
                try linuxLookupNameFromNumericUnspec(gpa, &rc.ns, ip_txt, 53);
            } else if (mem.eql(u8, token, "domain") or mem.eql(u8, token, "search")) {
                rc.search.items.len = 0;
                try rc.search.appendSlice(gpa, line_it.rest());
            }
        } else |err| return err;

        if (rc.ns.items.len == 0) {
            return linuxLookupNameFromNumericUnspec(gpa, &rc.ns, "127.0.0.1", 53);
        }
    }

    fn resMSendRc(
        rc: ResolvConf,
        queries: []const []const u8,
        answers: [][]u8,
        answer_bufs: []const []u8,
    ) !void {
        const gpa = rc.gpa;
        const timeout = 1000 * rc.timeout;
        const attempts = rc.attempts;

        var sl: posix.socklen_t = @sizeOf(posix.sockaddr.in);
        var family: posix.sa_family_t = posix.AF.INET;

        var ns_list: ArrayList(Address) = .empty;
        defer ns_list.deinit(gpa);

        try ns_list.resize(gpa, rc.ns.items.len);

        for (ns_list.items, rc.ns.items) |*ns, iplit| {
            ns.* = iplit.addr;
            assert(ns.getPort() == 53);
            if (iplit.addr.any.family != posix.AF.INET) {
                family = posix.AF.INET6;
            }
        }

        const flags = posix.SOCK.DGRAM | posix.SOCK.CLOEXEC | posix.SOCK.NONBLOCK;
        const fd = posix.socket(family, flags, 0) catch |err| switch (err) {
            error.AddressFamilyNotSupported => blk: {
                // Handle case where system lacks IPv6 support
                if (family == posix.AF.INET6) {
                    family = posix.AF.INET;
                    break :blk try posix.socket(posix.AF.INET, flags, 0);
                }
                return err;
            },
            else => |e| return e,
        };
        defer Stream.close(.{ .handle = fd });

        // Past this point, there are no errors. Each individual query will
        // yield either no reply (indicated by zero length) or an answer
        // packet which is up to the caller to interpret.

        // Convert any IPv4 addresses in a mixed environment to v4-mapped
        if (family == posix.AF.INET6) {
            try posix.setsockopt(
                fd,
                posix.SOL.IPV6,
                std.os.linux.IPV6.V6ONLY,
                &mem.toBytes(@as(c_int, 0)),
            );
            for (ns_list.items) |*ns| {
                if (ns.any.family != posix.AF.INET) continue;
                mem.writeInt(u32, ns.in6.sa.addr[12..], ns.in.sa.addr, native_endian);
                ns.in6.sa.addr[0..12].* = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff".*;
                ns.any.family = posix.AF.INET6;
                ns.in6.sa.flowinfo = 0;
                ns.in6.sa.scope_id = 0;
            }
            sl = @sizeOf(posix.sockaddr.in6);
        }

        // Get local address and open/bind a socket
        var sa: Address = undefined;
        @memset(@as([*]u8, @ptrCast(&sa))[0..@sizeOf(Address)], 0);
        sa.any.family = family;
        try posix.bind(fd, &sa.any, sl);

        var pfd = [1]posix.pollfd{posix.pollfd{
            .fd = fd,
            .events = posix.POLL.IN,
            .revents = undefined,
        }};
        const retry_interval = timeout / attempts;
        var next: u32 = 0;
        var t2: u64 = @bitCast(std.time.milliTimestamp());
        const t0 = t2;
        var t1 = t2 - retry_interval;

        var servfail_retry: usize = undefined;

        outer: while (t2 - t0 < timeout) : (t2 = @as(u64, @bitCast(std.time.milliTimestamp()))) {
            if (t2 - t1 >= retry_interval) {
                // Query all configured nameservers in parallel
                var i: usize = 0;
                while (i < queries.len) : (i += 1) {
                    if (answers[i].len == 0) {
                        for (ns_list.items) |*ns| {
                            _ = posix.sendto(fd, queries[i], posix.MSG.NOSIGNAL, &ns.any, sl) catch undefined;
                        }
                    }
                }
                t1 = t2;
                servfail_retry = 2 * queries.len;
            }

            // Wait for a response, or until time to retry
            const clamped_timeout = @min(@as(u31, std.math.maxInt(u31)), t1 + retry_interval - t2);
            const nevents = posix.poll(&pfd, clamped_timeout) catch 0;
            if (nevents == 0) continue;

            while (true) {
                var sl_copy = sl;
                const rlen = posix.recvfrom(fd, answer_bufs[next], 0, &sa.any, &sl_copy) catch break;

                // Ignore non-identifiable packets
                if (rlen < 4) continue;

                // Ignore replies from addresses we didn't send to
                const ns = for (ns_list.items) |*ns| {
                    if (ns.eql(sa)) break ns;
                } else continue;

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
                        _ = posix.sendto(fd, queries[i], posix.MSG.NOSIGNAL, &ns.any, sl) catch undefined;
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

    fn deinit(rc: *ResolvConf) void {
        const gpa = rc.gpa;
        rc.ns.deinit(gpa);
        rc.search.deinit(gpa);
        rc.* = undefined;
    }
};

fn linuxLookupNameFromNumericUnspec(
    gpa: Allocator,
    addrs: *ArrayList(LookupAddr),
    name: []const u8,
    port: u16,
) !void {
    const addr = try Address.resolveIp(name, port);
    try addrs.append(gpa, .{ .addr = addr });
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
    const gpa = ctx.gpa;
    switch (rr) {
        posix.RR.A => {
            if (data.len != 4) return error.InvalidDnsARecord;
            try ctx.addrs.append(gpa, .{
                .addr = Address.initIp4(data[0..4].*, ctx.port),
            });
        },
        posix.RR.AAAA => {
            if (data.len != 16) return error.InvalidDnsAAAARecord;
            try ctx.addrs.append(gpa, .{
                .addr = Address.initIp6(data[0..16].*, ctx.port, 0, 0),
            });
        },
        posix.RR.CNAME => {
            var tmp: [256]u8 = undefined;
            // Returns len of compressed name. strlen to get canon name.
            _ = try posix.dn_expand(packet, data, &tmp);
            const canon_name = mem.sliceTo(&tmp, 0);
            if (isValidHostName(canon_name)) {
                ctx.canon.items.len = 0;
                try ctx.canon.appendSlice(gpa, canon_name);
            }
        },
        else => return,
    }
}

pub const Stream = struct {
    /// Underlying platform-defined type which may or may not be
    /// interchangeable with a file system file descriptor.
    handle: Handle,

    pub const Handle = switch (native_os) {
        .windows => windows.ws2_32.SOCKET,
        else => posix.fd_t,
    };

    pub fn close(s: Stream) void {
        switch (native_os) {
            .windows => windows.closesocket(s.handle) catch unreachable,
            else => posix.close(s.handle),
        }
    }

    const ReadError = posix.ReadError;

    const WriteError = posix.SendMsgError || error{
        ConnectionResetByPeer,
        SocketNotBound,
        MessageTooBig,
        NetworkSubsystemFailed,
        SystemResources,
        SocketNotConnected,
        Unexpected,
    };

    pub const Reader = switch (native_os) {
        .windows => struct {
            /// Use `interface` to access portably.
            interface_state: io.Reader,
            /// Use `getStream` to access portably.
            net_stream: Stream,
            err: ?Error = null,

            pub const Error = ReadError;

            pub fn getStream(r: *const Reader) Stream {
                return r.stream;
            }

            pub fn interface(r: *Reader) *io.Reader {
                return &r.interface_state;
            }

            pub fn init(net_stream: Stream, buffer: []u8) Reader {
                return .{
                    .interface_state = .{
                        .context = undefined,
                        .vtable = &.{ .stream = stream },
                        .buffer = buffer,
                    },
                    .net_stream = net_stream,
                };
            }

            fn stream(io_r: *io.Reader, io_w: *io.Writer, limit: io.Limit) io.Reader.StreamError!usize {
                const r: *Reader = @fieldParentPtr("interface", io_r);
                var iovecs: [max_buffers_len]windows.WSABUF = undefined;
                const bufs = io_w.writableVectorWsa(&iovecs, limit);
                assert(bufs[0].len > 0);
                var n: u32 = undefined;
                var flags: u32 = 0;
                const rc = windows.ws2_32.WSARecvFrom(r.net_stream.handle, bufs.ptr, bufs.len, &n, &flags, null, null, null, null);
                if (rc != 0) switch (windows.ws2_32.WSAGetLastError()) {
                    .WSAECONNRESET => return error.ConnectionResetByPeer,
                    .WSAEFAULT => unreachable, // a pointer is not completely contained in user address space.
                    .WSAEINPROGRESS, .WSAEINTR => unreachable, // deprecated and removed in WSA 2.2
                    .WSAEINVAL => return error.SocketNotBound,
                    .WSAEMSGSIZE => return error.MessageTooBig,
                    .WSAENETDOWN => return error.NetworkSubsystemFailed,
                    .WSAENETRESET => return error.ConnectionResetByPeer,
                    .WSAENOTCONN => return error.SocketNotConnected,
                    .WSAEWOULDBLOCK => return error.WouldBlock,
                    .WSANOTINITIALISED => unreachable, // WSAStartup must be called before this function
                    .WSA_IO_PENDING => unreachable, // not using overlapped I/O
                    .WSA_OPERATION_ABORTED => unreachable, // not using overlapped I/O
                    else => |err| return windows.unexpectedWSAError(err),
                };
                if (n == 0) return error.EndOfStream;
                return n;
            }
        },
        else => struct {
            file_reader: File.Reader,

            pub const Error = ReadError;

            pub fn interface(r: *Reader) *io.Reader {
                return &r.file_reader.interface;
            }

            pub fn init(net_stream: Stream, buffer: []u8) Reader {
                return .{
                    .file_reader = .{
                        .interface = File.Reader.initInterface(buffer),
                        .file = .{ .handle = net_stream.handle },
                        .mode = .streaming,
                        .seek_err = error.Unseekable,
                    },
                };
            }

            pub fn getStream(r: *const Reader) Stream {
                return .{ .handle = r.file_reader.file.handle };
            }
        },
    };

    pub const Writer = switch (native_os) {
        .windows => struct {
            /// This field is present on all systems.
            interface: io.Writer,
            /// Use `getStream` for cross-platform support.
            stream: Stream,

            pub const Error = WriteError;

            pub fn init(stream: Stream, buffer: []u8) Writer {
                return .{
                    .stream = stream,
                    .interface = .{
                        .vtable = &.{ .drain = drain },
                        .buffer = buffer,
                    },
                };
            }

            pub fn getStream(w: *const Writer) Stream {
                return w.stream;
            }

            fn drain(io_w: *io.Writer, data: []const []const u8, splat: usize) io.Writer.Error!usize {
                const w: *Writer = @fieldParentPtr("interface", io_w);
                const buffered = io_w.buffered();
                comptime assert(native_os == .windows);
                var iovecs: [max_buffers_len]windows.WSABUF = undefined;
                var len: u32 = 0;
                if (buffered.len != 0) {
                    iovecs[len] = .{
                        .buf = buffered.ptr,
                        .len = buffered.len,
                    };
                    len += 1;
                }
                for (data) |bytes| {
                    if (bytes.len == 0) continue;
                    iovecs[len] = .{
                        .buf = bytes.ptr,
                        .len = bytes.len,
                    };
                    len += 1;
                    if (iovecs.len - len == 0) break;
                }
                if (len == 0) return 0;
                const pattern = data[data.len - 1];
                switch (splat) {
                    0 => if (iovecs[len - 1].buf == data[data.len - 1].ptr) {
                        len -= 1;
                    },
                    1 => {},
                    else => switch (pattern.len) {
                        0 => {},
                        1 => memset: {
                            // Replace the 1-byte buffer with a bigger one.
                            if (iovecs[len - 1].buf == data[data.len - 1].ptr) len -= 1;
                            if (iovecs.len - len == 0) break :memset;
                            const splat_buffer_candidate = io_w.buffer[io_w.end..];
                            var backup_buffer: [32]u8 = undefined;
                            const splat_buffer = if (splat_buffer_candidate.len >= backup_buffer.len)
                                splat_buffer_candidate
                            else
                                &backup_buffer;
                            const memset_len = @min(splat_buffer.len, splat);
                            const buf = splat_buffer[0..memset_len];
                            @memset(buf, pattern[0]);
                            iovecs[len] = .{ .buf = buf.ptr, .len = buf.len };
                            len += 1;
                            var remaining_splat = splat - buf.len;
                            while (remaining_splat > splat_buffer.len and len < iovecs.len) {
                                iovecs[len] = .{ .buf = splat_buffer.ptr, .len = splat_buffer.len };
                                remaining_splat -= splat_buffer.len;
                                len += 1;
                            }
                            if (remaining_splat > 0 and iovecs.len - len != 0) {
                                iovecs[len] = .{ .buf = splat_buffer.ptr, .len = remaining_splat };
                                len += 1;
                            }
                        },
                        else => for (0..splat - 1) |_| {
                            if (iovecs.len - len == 0) break;
                            iovecs[len] = .{
                                .buf = pattern.ptr,
                                .len = pattern.len,
                            };
                            len += 1;
                        },
                    },
                }
                var n: u32 = undefined;
                const rc = windows.ws2_32.WSASend(w.stream.handle, &iovecs, len, &n, 0, null, null);
                if (rc == windows.ws2_32.SOCKET_ERROR) switch (windows.ws2_32.WSAGetLastError()) {
                    .WSAECONNABORTED => return error.ConnectionResetByPeer,
                    .WSAECONNRESET => return error.ConnectionResetByPeer,
                    .WSAEFAULT => unreachable, // a pointer is not completely contained in user address space.
                    .WSAEINPROGRESS, .WSAEINTR => unreachable, // deprecated and removed in WSA 2.2
                    .WSAEINVAL => return error.SocketNotBound,
                    .WSAEMSGSIZE => return error.MessageTooBig,
                    .WSAENETDOWN => return error.NetworkSubsystemFailed,
                    .WSAENETRESET => return error.ConnectionResetByPeer,
                    .WSAENOBUFS => return error.SystemResources,
                    .WSAENOTCONN => return error.SocketNotConnected,
                    .WSAENOTSOCK => unreachable, // not a socket
                    .WSAEOPNOTSUPP => unreachable, // only for message-oriented sockets
                    .WSAESHUTDOWN => unreachable, // cannot send on a socket after write shutdown
                    .WSAEWOULDBLOCK => return error.WouldBlock,
                    .WSANOTINITIALISED => unreachable, // WSAStartup must be called before this function
                    .WSA_IO_PENDING => unreachable, // not using overlapped I/O
                    .WSA_OPERATION_ABORTED => unreachable, // not using overlapped I/O
                    else => |err| return windows.unexpectedWSAError(err),
                };
                return io_w.consume(n);
            }
        },
        else => struct {
            /// This field is present on all systems.
            interface: io.Writer,

            err: ?Error = null,
            file_writer: File.Writer,

            pub const Error = WriteError;

            pub fn init(stream: Stream, buffer: []u8) Writer {
                return .{
                    .interface = .{
                        .vtable = &.{
                            .drain = drain,
                            .sendFile = sendFile,
                        },
                        .buffer = buffer,
                    },
                    .file_writer = .initMode(.{ .handle = stream.handle }, &.{}, .streaming),
                };
            }

            pub fn getStream(w: *const Writer) Stream {
                return .{ .handle = w.file_writer.file.handle };
            }

            fn drain(io_w: *io.Writer, data: []const []const u8, splat: usize) io.Writer.Error!usize {
                const w: *Writer = @fieldParentPtr("interface", io_w);
                const buffered = io_w.buffered();
                var iovecs: [max_buffers_len]std.posix.iovec_const = undefined;
                var msg: posix.msghdr_const = msg: {
                    var i: usize = 0;
                    if (buffered.len != 0) {
                        iovecs[i] = .{
                            .base = buffered.ptr,
                            .len = buffered.len,
                        };
                        i += 1;
                    }
                    for (data) |bytes| {
                        // OS checks ptr addr before length so zero length vectors must be omitted.
                        if (bytes.len == 0) continue;
                        iovecs[i] = .{
                            .base = bytes.ptr,
                            .len = bytes.len,
                        };
                        i += 1;
                        if (iovecs.len - i == 0) break;
                    }
                    break :msg .{
                        .name = null,
                        .namelen = 0,
                        .iov = &iovecs,
                        .iovlen = i,
                        .control = null,
                        .controllen = 0,
                        .flags = 0,
                    };
                };
                if (msg.iovlen == 0) return 0;
                const pattern = data[data.len - 1];
                switch (splat) {
                    0 => if (iovecs[msg.iovlen - 1].base == data[data.len - 1].ptr) {
                        msg.iovlen -= 1;
                    },
                    1 => {},
                    else => switch (pattern.len) {
                        0 => {},
                        1 => memset: {
                            // Replace the 1-byte buffer with a bigger one.
                            if (iovecs[msg.iovlen - 1].base == data[data.len - 1].ptr) msg.iovlen -= 1;
                            if (iovecs.len - msg.iovlen == 0) break :memset;
                            const splat_buffer_candidate = io_w.buffer[io_w.end..];
                            var backup_buffer: [32]u8 = undefined;
                            const splat_buffer = if (splat_buffer_candidate.len >= backup_buffer.len)
                                splat_buffer_candidate
                            else
                                &backup_buffer;
                            if (splat_buffer.len == 0) break :memset;
                            const memset_len = @min(splat_buffer.len, splat);
                            const buf = splat_buffer[0..memset_len];
                            @memset(buf, pattern[0]);
                            iovecs[msg.iovlen] = .{ .base = buf.ptr, .len = buf.len };
                            msg.iovlen += 1;
                            var remaining_splat = splat - buf.len;
                            while (remaining_splat > splat_buffer.len and iovecs.len - msg.iovlen != 0) {
                                assert(buf.len == splat_buffer.len);
                                iovecs[msg.iovlen] = .{ .base = splat_buffer.ptr, .len = splat_buffer.len };
                                msg.iovlen += 1;
                                remaining_splat -= splat_buffer.len;
                            }
                            if (remaining_splat > 0 and iovecs.len - msg.iovlen != 0) {
                                iovecs[msg.iovlen] = .{ .base = splat_buffer.ptr, .len = remaining_splat };
                                msg.iovlen += 1;
                            }
                        },
                        else => for (0..splat - 1) |_| {
                            if (iovecs.len - msg.iovlen == 0) break;
                            iovecs[msg.iovlen] = .{
                                .base = pattern.ptr,
                                .len = pattern.len,
                            };
                            msg.iovlen += 1;
                        },
                    },
                }
                const flags = posix.MSG.NOSIGNAL;
                return io_w.consume(std.posix.sendmsg(w.file_writer.file.handle, &msg, flags) catch |err| {
                    w.err = err;
                    return error.WriteFailed;
                });
            }

            fn sendFile(io_w: *io.Writer, file_reader: *File.Reader, limit: io.Limit) io.Writer.FileError!usize {
                const w: *Writer = @fieldParentPtr("interface", io_w);
                const n = try w.file_writer.interface.sendFileHeader(io_w.buffered(), file_reader, limit);
                return io_w.consume(n);
            }
        },
    };

    pub fn reader(stream: Stream, buffer: []u8) Reader {
        return .init(stream, buffer);
    }

    pub fn writer(stream: Stream, buffer: []u8) Writer {
        return .init(stream, buffer);
    }

    const max_buffers_len = 8;
    const splat_buffer_len = 256;
};

pub const Server = struct {
    listen_address: Address,
    stream: Stream,

    pub const Connection = struct {
        stream: Stream,
        address: Address,
    };

    pub fn deinit(s: *Server) void {
        s.stream.close();
        s.* = undefined;
    }

    pub const AcceptError = posix.AcceptError;

    /// Blocks until a client connects to the server. The returned `Connection` has
    /// an open stream.
    pub fn accept(s: *Server) AcceptError!Connection {
        var accepted_addr: Address = undefined;
        var addr_len: posix.socklen_t = @sizeOf(Address);
        const fd = try posix.accept(s.stream.handle, &accepted_addr.any, &addr_len, posix.SOCK.CLOEXEC);
        return .{
            .stream = .{ .handle = fd },
            .address = accepted_addr,
        };
    }
};

test {
    if (builtin.os.tag != .wasi) {
        _ = Server;
        _ = Stream;
        _ = Address;
        _ = @import("net/test.zig");
    }
}
