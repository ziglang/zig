const builtin = @import("builtin");
const native_os = builtin.os.tag;
const std = @import("../std.zig");
const Io = std.Io;
const assert = std.debug.assert;

pub const HostName = @import("net/HostName.zig");

/// Source of truth: Internet Assigned Numbers Authority (IANA)
pub const Protocol = enum(u32) {
    hopopts = 0,
    icmp = 1,
    igmp = 2,
    ipip = 4,
    tcp = 6,
    egp = 8,
    pup = 12,
    udp = 17,
    idp = 22,
    tp = 29,
    dccp = 33,
    ipv6 = 41,
    routing = 43,
    fragment = 44,
    rsvp = 46,
    gre = 47,
    esp = 50,
    ah = 51,
    icmpv6 = 58,
    none = 59,
    dstopts = 60,
    mtp = 92,
    beetph = 94,
    encap = 98,
    pim = 103,
    comp = 108,
    sctp = 132,
    mh = 135,
    udplite = 136,
    mpls = 137,
    ethernet = 143,
    raw = 255,
    mptcp = 262,
};

/// Windows 10 added support for unix sockets in build 17063, redstone 4 is the
/// first release to support them.
pub const has_unix_sockets = switch (native_os) {
    .windows => builtin.os.version_range.windows.isAtLeast(.win10_rs4) orelse false,
    .wasi => false,
    else => true,
};

pub const default_kernel_backlog = 128;

pub const IpAddress = union(enum) {
    ip4: Ip4Address,
    ip6: Ip6Address,

    pub const Family = @typeInfo(IpAddress).@"union".tag_type.?;

    pub const ParseLiteralError = error{ InvalidAddress, InvalidPort };

    /// Parse an IP address which may include a port.
    ///
    /// For IPv4, this is written `address:port`.
    ///
    /// For IPv6, RFC 3986 defines this as an "IP literal", and the port is
    /// differentiated from the address by surrounding the address part in
    /// brackets "[addr]:port". Even if the port is not given, the brackets are
    /// mandatory.
    pub fn parseLiteral(text: []const u8) ParseLiteralError!IpAddress {
        if (text.len == 0) return error.InvalidAddress;
        if (text[0] == '[') {
            const addr_end = std.mem.findScalar(u8, text, ']') orelse
                return error.InvalidAddress;
            const addr_text = text[1..addr_end];
            const port: u16 = p: {
                if (addr_end == text.len - 1) break :p 0;
                if (text[addr_end + 1] != ':') return error.InvalidAddress;
                break :p std.fmt.parseInt(u16, text[addr_end + 2 ..], 10) catch return error.InvalidPort;
            };
            return parseIp6(addr_text, port) catch error.InvalidAddress;
        }
        if (std.mem.findScalar(u8, text, ':')) |i| {
            const addr = Ip4Address.parse(text[0..i], 0) catch return error.InvalidAddress;
            return .{ .ip4 = .{
                .bytes = addr.bytes,
                .port = std.fmt.parseInt(u16, text[i + 1 ..], 10) catch return error.InvalidPort,
            } };
        }
        return parseIp4(text, 0) catch error.InvalidAddress;
    }

    /// Parse the given IP address string into an `IpAddress` value.
    ///
    /// This is a pure function but it cannot handle IPv6 addresses that have
    /// scope ids ("%foo" at the end). To also handle those, `resolve` must be
    /// called instead.
    pub fn parse(text: []const u8, port: u16) !IpAddress {
        if (parseIp4(text, port)) |ip4| return ip4 else |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            error.NonCanonical,
            => {},
        }

        return parseIp6(text, port);
    }

    pub fn parseIp4(text: []const u8, port: u16) Ip4Address.ParseError!IpAddress {
        return .{ .ip4 = try Ip4Address.parse(text, port) };
    }

    /// This is a pure function but it cannot handle IPv6 addresses that have
    /// scope ids ("%foo" at the end). To also handle those, `resolveIp6` must be
    /// called instead.
    pub fn parseIp6(text: []const u8, port: u16) Ip6Address.ParseError!IpAddress {
        return .{ .ip6 = try Ip6Address.parse(text, port) };
    }

    /// This function requires an `Io` parameter because it must query the operating
    /// system to convert interface name to index. For example, in
    /// "fe80::e0e:76ff:fed4:cf22%eno1", "eno1" must be resolved to an index by
    /// creating a socket and then using an `ioctl` syscall.
    ///
    /// For a pure function that cannot handle scopes, see `parse`.
    pub fn resolve(io: Io, text: []const u8, port: u16) !IpAddress {
        if (parseIp4(text, port)) |ip4| return ip4 else |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            error.NonCanonical,
            => {},
        }

        return resolveIp6(io, text, port);
    }

    pub fn resolveIp6(io: Io, text: []const u8, port: u16) Ip6Address.ResolveError!IpAddress {
        return .{ .ip6 = try Ip6Address.resolve(io, text, port) };
    }

    /// Returns the port in native endian.
    pub fn getPort(a: IpAddress) u16 {
        return switch (a) {
            inline .ip4, .ip6 => |x| x.port,
        };
    }

    /// `port` is native-endian.
    pub fn setPort(a: *IpAddress, port: u16) void {
        switch (a) {
            inline .ip4, .ip6 => |*x| x.port = port,
        }
    }

    /// Includes the optional scope ("%foo" at the end) in IPv6 addresses.
    ///
    /// See `format` for an alternative that omits scopes and does
    /// not require an `Io` parameter.
    pub fn formatResolved(a: IpAddress, io: Io, w: *Io.Writer) Ip6Address.FormatError!void {
        switch (a) {
            .ip4 => |x| return x.format(w),
            .ip6 => |x| return x.formatResolved(io, w),
        }
    }

    /// See `formatResolved` for an alternative that additionally prints the optional
    /// scope at the end of IPv6 addresses and requires an `Io` parameter.
    pub fn format(a: IpAddress, w: *Io.Writer) Io.Writer.Error!void {
        switch (a) {
            inline .ip4, .ip6 => |x| return x.format(w),
        }
    }

    pub fn eql(a: *const IpAddress, b: *const IpAddress) bool {
        return switch (a.*) {
            .ip4 => |a_ip4| switch (b.*) {
                .ip4 => |b_ip4| a_ip4.eql(b_ip4),
                else => false,
            },
            .ip6 => |a_ip6| switch (b.*) {
                .ip6 => |b_ip6| a_ip6.eql(b_ip6),
                else => false,
            },
        };
    }

    pub const ListenError = error{
        /// The address is already taken. Can occur when bound port is 0 but
        /// all ephemeral ports are already in use.
        AddressInUse,
        /// A nonexistent interface was requested or the requested address was not local.
        AddressUnavailable,
        /// The local network interface used to reach the destination is offline.
        NetworkDown,
        /// Insufficient memory or other resource internal to the operating system.
        SystemResources,
        /// Per-process limit on the number of open file descriptors has been reached.
        ProcessFdQuotaExceeded,
        /// System-wide limit on the total number of open files has been reached.
        SystemFdQuotaExceeded,
        /// The requested address family (IPv4 or IPv6) is not supported by the operating system.
        AddressFamilyUnsupported,
        ProtocolUnsupportedBySystem,
        ProtocolUnsupportedByAddressFamily,
        SocketModeUnsupported,
        /// One of the `ListenOptions` is not supported by the Io
        /// implementation.
        OptionUnsupported,
    } || Io.UnexpectedError || Io.Cancelable;

    pub const ListenOptions = struct {
        /// How many connections the kernel will accept on the application's behalf.
        /// If more than this many connections pool in the kernel, clients will start
        /// seeing "Connection refused".
        kernel_backlog: u31 = default_kernel_backlog,
        /// Sets SO_REUSEADDR and SO_REUSEPORT on POSIX.
        /// Sets SO_REUSEADDR on Windows, which is roughly equivalent.
        reuse_address: bool = false,
        /// Only connection-oriented modes may be used here, which includes:
        /// * `Socket.Mode.stream`
        /// * `Socket.Mode.seqpacket`
        mode: Socket.Mode = .stream,
        /// Only connection-oriented protocols may be used here, which includes:
        /// * `Protocol.tcp`
        /// * `Protocol.tp`
        /// * `Protocol.dccp`
        /// * `Protocol.sctp`
        protocol: Protocol = .tcp,
    };

    /// Waits for a TCP connection. When using this API, `bind` does not need
    /// to be called. The returned `Server` has an open `stream`.
    pub fn listen(address: IpAddress, io: Io, options: ListenOptions) ListenError!Server {
        return io.vtable.netListenIp(io.userdata, address, options);
    }

    pub const BindError = error{
        /// The address is already taken. Can occur when bound port is 0 but
        /// all ephemeral ports are already in use.
        AddressInUse,
        /// A nonexistent interface was requested or the requested address was not local.
        AddressUnavailable,
        /// The address is not valid for the address family of socket.
        AddressFamilyUnsupported,
        /// Insufficient memory or other resource internal to the operating system.
        SystemResources,
        /// The local network interface used to reach the destination is offline.
        NetworkDown,
        ProtocolUnsupportedBySystem,
        ProtocolUnsupportedByAddressFamily,
        /// Per-process limit on the number of open file descriptors has been reached.
        ProcessFdQuotaExceeded,
        /// System-wide limit on the total number of open files has been reached.
        SystemFdQuotaExceeded,
        SocketModeUnsupported,
        /// One of the `BindOptions` is not supported by the Io
        /// implementation.
        OptionUnsupported,
    } || Io.UnexpectedError || Io.Cancelable;

    pub const BindOptions = struct {
        /// The socket is restricted to sending and receiving IPv6 packets only.
        /// In this case, an IPv4 and an IPv6 application can bind to a single port
        /// at the same time.
        ip6_only: bool = false,
        mode: Socket.Mode,
        protocol: ?Protocol = null,
    };

    /// Associates an address with a `Socket` which can be used to receive UDP
    /// packets and other kinds of non-streaming messages. See `listen` for a
    /// streaming alternative.
    ///
    /// One bound `Socket` can be used to receive messages from multiple
    /// different addresses.
    pub fn bind(address: *const IpAddress, io: Io, options: BindOptions) BindError!Socket {
        return io.vtable.netBindIp(io.userdata, address, options);
    }

    pub const ConnectError = error{
        AddressUnavailable,
        AddressFamilyUnsupported,
        /// Insufficient memory or other resource internal to the operating system.
        SystemResources,
        ConnectionPending,
        ConnectionRefused,
        ConnectionResetByPeer,
        HostUnreachable,
        NetworkUnreachable,
        Timeout,
        /// One of the `ConnectOptions` is not supported by the Io
        /// implementation.
        OptionUnsupported,
        /// Per-process limit on the number of open file descriptors has been reached.
        ProcessFdQuotaExceeded,
        /// System-wide limit on the total number of open files has been reached.
        SystemFdQuotaExceeded,
        ProtocolUnsupportedBySystem,
        ProtocolUnsupportedByAddressFamily,
        SocketModeUnsupported,
        /// The user tried to connect to a broadcast address without having the socket broadcast flag enabled or
        /// the connection request failed because of a local firewall rule.
        AccessDenied,
        /// Non-blocking was requested and the operation cannot return immediately.
        WouldBlock,
        NetworkDown,
    } || Io.Timeout.Error || Io.UnexpectedError || Io.Cancelable;

    pub const ConnectOptions = struct {
        mode: Socket.Mode,
        protocol: ?Protocol = null,
        timeout: Io.Timeout = .none,
    };

    /// Initiates a connection-oriented network stream.
    pub fn connect(address: IpAddress, io: Io, options: ConnectOptions) ConnectError!Stream {
        return io.vtable.netConnectIp(io.userdata, &address, options);
    }
};

/// An IPv4 address in binary memory layout.
pub const Ip4Address = struct {
    bytes: [4]u8,
    port: u16,

    pub fn loopback(port: u16) Ip4Address {
        return .{
            .bytes = .{ 127, 0, 0, 1 },
            .port = port,
        };
    }

    pub fn unspecified(port: u16) Ip4Address {
        return .{
            .bytes = .{ 0, 0, 0, 0 },
            .port = port,
        };
    }

    pub const ParseError = error{
        Overflow,
        InvalidEnd,
        InvalidCharacter,
        Incomplete,
        NonCanonical,
    };

    pub fn parse(buffer: []const u8, port: u16) ParseError!Ip4Address {
        var bytes: [4]u8 = @splat(0);
        var index: u8 = 0;
        var saw_any_digits = false;
        var has_zero_prefix = false;
        for (buffer) |c| switch (c) {
            '.' => {
                if (!saw_any_digits) return error.InvalidCharacter;
                if (index == 3) return error.InvalidEnd;
                index += 1;
                saw_any_digits = false;
                has_zero_prefix = false;
            },
            '0'...'9' => {
                if (c == '0' and !saw_any_digits) {
                    has_zero_prefix = true;
                } else if (has_zero_prefix) {
                    return error.NonCanonical;
                }
                saw_any_digits = true;
                bytes[index] = try std.math.mul(u8, bytes[index], 10);
                bytes[index] = try std.math.add(u8, bytes[index], c - '0');
            },
            else => return error.InvalidCharacter,
        };
        if (index == 3 and saw_any_digits) return .{
            .bytes = bytes,
            .port = port,
        };
        return error.Incomplete;
    }

    pub fn format(a: Ip4Address, w: *Io.Writer) Io.Writer.Error!void {
        const bytes = &a.bytes;
        try w.print("{d}.{d}.{d}.{d}:{d}", .{ bytes[0], bytes[1], bytes[2], bytes[3], a.port });
    }

    pub fn eql(a: Ip4Address, b: Ip4Address) bool {
        const a_int: u32 = @bitCast(a.bytes);
        const b_int: u32 = @bitCast(b.bytes);
        return a.port == b.port and a_int == b_int;
    }
};

/// An IPv6 address in binary memory layout.
pub const Ip6Address = struct {
    /// Native endian
    port: u16,
    /// Big endian
    bytes: [16]u8,
    flow: u32 = 0,
    interface: Interface = .none,

    pub const Policy = struct {
        addr: [16]u8,
        len: u8,
        mask: u8,
        prec: u8,
        label: u8,
    };

    pub fn loopback(port: u16) Ip6Address {
        return .{
            .bytes = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
            .port = port,
        };
    }

    pub fn unspecified(port: u16) Ip6Address {
        return .{
            .bytes = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            .port = port,
        };
    }

    /// Constructs an IPv4-mapped IPv6 address.
    pub fn fromIp4(ip4: Ip4Address) Ip6Address {
        const b = &ip4.bytes;
        return .{
            .bytes = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff, b[0], b[1], b[2], b[3] },
            .port = ip4.port,
        };
    }

    /// Given an `IpAddress`, converts it to an `Ip6Address` directly, or via
    /// constructing an IPv4-mapped IPv6 address.
    pub fn fromAny(addr: IpAddress) Ip6Address {
        return switch (addr) {
            .ip4 => |ip4| fromIp4(ip4),
            .ip6 => |ip6| ip6,
        };
    }

    /// An IPv6 address but with `Interface` as a name rather than index.
    pub const Unresolved = struct {
        /// Big endian
        bytes: [16]u8,
        /// Has not been checked to be a valid native interface name.
        /// Externally managed memory.
        interface_name: ?[]const u8,

        pub const Parsed = union(enum) {
            success: Unresolved,
            invalid_byte: usize,
            incomplete,
            junk_after_end: usize,
            interface_name_oversized: usize,
            invalid_ip4_mapping: usize,
            overflow: usize,
        };

        pub fn parse(text: []const u8) Parsed {
            if (text.len < 2) return .incomplete;
            const ip4_prefix = "::ffff:";
            if (std.ascii.startsWithIgnoreCase(text, ip4_prefix)) {
                const parsed = Ip4Address.parse(text[ip4_prefix.len..], 0) catch
                    return .{ .invalid_ip4_mapping = ip4_prefix.len };
                const b = parsed.bytes;
                return .{ .success = .{
                    .bytes = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff, b[0], b[1], b[2], b[3] },
                    .interface_name = null,
                } };
            }
            // Has to be u16 elements to handle 3-digit hex numbers from compression.
            var parts: [8]u16 = @splat(0);
            var parts_i: u8 = 0;
            var text_i: u8 = 0;
            var digit_i: u8 = 0;
            var compress_start: ?u8 = null;
            var interface_name_text: ?[]const u8 = null;
            const State = union(enum) { digit, end };
            state: switch (State.digit) {
                .digit => c: switch (text[text_i]) {
                    'a'...'f' => |c| {
                        const digit = c - 'a' + 10;
                        parts[parts_i] = (std.math.mul(u16, parts[parts_i], 16) catch return .{
                            .overflow = text_i,
                        }) + digit;
                        if (digit_i == 4) return .{ .invalid_byte = text_i };
                        digit_i += 1;
                        text_i += 1;
                        if (text.len - text_i == 0) {
                            parts_i += 1;
                            continue :state .end;
                        }
                        continue :c text[text_i];
                    },
                    'A'...'F' => |c| continue :c c - 'A' + 'a',
                    '0'...'9' => |c| {
                        const digit = c - '0';
                        parts[parts_i] = (std.math.mul(u16, parts[parts_i], 16) catch return .{
                            .overflow = text_i,
                        }) + digit;
                        if (digit_i == 4) return .{ .invalid_byte = text_i };
                        digit_i += 1;
                        text_i += 1;
                        if (text.len - text_i == 0) {
                            parts_i += 1;
                            continue :state .end;
                        }
                        continue :c text[text_i];
                    },
                    ':' => {
                        if (digit_i == 0) {
                            if (compress_start != null) return .{ .invalid_byte = text_i };
                            if (text_i == 0) {
                                text_i += 1;
                                if (text[text_i] != ':') return .{ .invalid_byte = text_i };
                                assert(parts_i == 0);
                            }
                            compress_start = parts_i;
                            text_i += 1;
                            if (text.len - text_i == 0) continue :state .end;
                            continue :c text[text_i];
                        } else {
                            parts_i += 1;
                            if (parts.len - parts_i == 0) continue :state .end;
                            digit_i = 0;
                            text_i += 1;
                            if (text.len - text_i == 0) return .incomplete;
                            continue :c text[text_i];
                        }
                    },
                    '%' => {
                        if (digit_i == 0) return .{ .invalid_byte = text_i };
                        parts_i += 1;
                        text_i += 1;
                        const name = text[text_i..];
                        if (name.len == 0) return .incomplete;
                        interface_name_text = name;
                        text_i = @intCast(text.len);
                        continue :state .end;
                    },
                    else => return .{ .invalid_byte = text_i },
                },
                .end => {
                    if (text.len - text_i != 0) return .{ .junk_after_end = text_i };
                    const remaining = parts.len - parts_i;
                    if (compress_start) |s| {
                        const src = parts[s..parts_i];
                        @memmove(parts[parts.len - src.len ..], src);
                        @memset(parts[s..][0..remaining], 0);
                    } else {
                        if (remaining != 0) return .incomplete;
                    }

                    // Workaround that can be removed when this proposal is
                    // implemented https://github.com/ziglang/zig/issues/19755
                    if ((comptime @import("builtin").cpu.arch.endian()) != .big) {
                        for (&parts) |*part| part.* = @byteSwap(part.*);
                    }

                    return .{ .success = .{
                        .bytes = @bitCast(parts),
                        .interface_name = interface_name_text,
                    } };
                },
            }
        }

        pub const FromAddressError = Interface.NameError;

        pub fn fromAddress(a: *const Ip6Address, io: Io) FromAddressError!Unresolved {
            if (a.interface.isNone()) return .{
                .bytes = a.bytes,
                .interface_name = null,
            };
            return .{
                .bytes = a.bytes,
                .interface_name = try a.interface.name(io),
            };
        }

        pub fn format(u: *const Unresolved, w: *Io.Writer) Io.Writer.Error!void {
            const bytes = &u.bytes;
            if (std.mem.eql(u8, bytes[0..12], &[_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff })) {
                try w.print("::ffff:{d}.{d}.{d}.{d}", .{ bytes[12], bytes[13], bytes[14], bytes[15] });
            } else {
                const parts: [8]u16 = .{
                    std.mem.readInt(u16, bytes[0..2], .big),
                    std.mem.readInt(u16, bytes[2..4], .big),
                    std.mem.readInt(u16, bytes[4..6], .big),
                    std.mem.readInt(u16, bytes[6..8], .big),
                    std.mem.readInt(u16, bytes[8..10], .big),
                    std.mem.readInt(u16, bytes[10..12], .big),
                    std.mem.readInt(u16, bytes[12..14], .big),
                    std.mem.readInt(u16, bytes[14..16], .big),
                };

                // Find the longest zero run
                var longest_start: usize = 8;
                var longest_len: usize = 0;
                var current_start: usize = 0;
                var current_len: usize = 0;

                for (parts, 0..) |part, i| {
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

                var i: usize = 0;
                var abbrv = false;
                while (i < parts.len) : (i += 1) {
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
                    try w.print("{x}", .{parts[i]});
                    if (i != parts.len - 1) {
                        try w.writeAll(":");
                    }
                }
            }
            if (u.interface_name) |n| try w.print("%{s}", .{n});
        }
    };

    pub const ParseError = error{
        /// If this is returned, more detailed diagnostics can be obtained by
        /// calling `Ip6Address.Parsed.init`.
        ParseFailed,
        /// If this is returned, the IPv6 address had a scope id on it ("%foo"
        /// at the end) which requires calling `resolve`.
        UnresolvedScope,
    };

    /// This is a pure function but it cannot handle IPv6 addresses that have
    /// scope ids ("%foo" at the end). To also handle those, `resolve` must be
    /// called instead, or the lower level `Unresolved` API may be used.
    pub fn parse(buffer: []const u8, port: u16) ParseError!Ip6Address {
        switch (Unresolved.parse(buffer)) {
            .success => |p| return .{
                .bytes = p.bytes,
                .port = port,
                .interface = if (p.interface_name != null) return error.UnresolvedScope else .none,
            },
            else => return error.ParseFailed,
        }
        return .{ .ip6 = try Ip6Address.parse(buffer, port) };
    }

    pub const ResolveError = error{
        /// If this is returned, more detailed diagnostics can be obtained by
        /// calling the `Parsed.init` function.
        ParseFailed,
        /// The interface name is longer than the host operating system supports.
        NameTooLong,
    } || Interface.Name.ResolveError;

    /// This function requires an `Io` parameter because it must query the operating
    /// system to convert interface name to index. For example, in
    /// "fe80::e0e:76ff:fed4:cf22%eno1", "eno1" must be resolved to an index by
    /// creating a socket and then using an `ioctl` syscall.
    pub fn resolve(io: Io, buffer: []const u8, port: u16) ResolveError!Ip6Address {
        return switch (Unresolved.parse(buffer)) {
            .success => |p| return .{
                .bytes = p.bytes,
                .port = port,
                .interface = i: {
                    const text = p.interface_name orelse break :i .none;
                    const name: Interface.Name = try .fromSlice(text);
                    break :i try name.resolve(io);
                },
            },
            else => return error.ParseFailed,
        };
    }

    pub const FormatError = Io.Writer.Error || Unresolved.FromAddressError;

    /// Includes the optional scope ("%foo" at the end).
    ///
    /// See `format` for an alternative that omits scopes and does
    /// not require an `Io` parameter.
    pub fn formatResolved(a: Ip6Address, io: Io, w: *Io.Writer) FormatError!void {
        const u: Unresolved = try .fromAddress(io);
        try w.print("[{f}]:{d}", .{ u, a.port });
    }

    /// See `formatResolved` for an alternative that additionally prints the optional
    /// scope at the end of addresses and requires an `Io` parameter.
    pub fn format(a: Ip6Address, w: *Io.Writer) Io.Writer.Error!void {
        const u: Unresolved = .{
            .bytes = a.bytes,
            .interface_name = null,
        };
        try w.print("[{f}]:{d}", .{ u, a.port });
    }

    pub fn eql(a: Ip6Address, b: Ip6Address) bool {
        return a.port == b.port and std.mem.eql(u8, &a.bytes, &b.bytes);
    }

    pub fn isMultiCast(a: Ip6Address) bool {
        return a.bytes[0] == 0xff;
    }

    pub fn isLinkLocal(a: Ip6Address) bool {
        const b = &a.bytes;
        return b[0] == 0xfe and (b[1] & 0xc0) == 0x80;
    }

    pub fn isLoopBack(a: Ip6Address) bool {
        const b = &a.bytes;
        return b[0] == 0 and b[1] == 0 and
            b[2] == 0 and
            b[12] == 0 and b[13] == 0 and
            b[14] == 0 and b[15] == 1;
    }

    pub fn isSiteLocal(a: Ip6Address) bool {
        const b = &a.bytes;
        return b[0] == 0xfe and (b[1] & 0xc0) == 0xc0;
    }

    pub fn policy(a: Ip6Address) *const Policy {
        const b = &a.bytes;
        for (&defined_policies) |*p| {
            if (!std.mem.eql(u8, b[0..p.len], p.addr[0..p.len])) continue;
            if ((b[p.len] & p.mask) != p.addr[p.len]) continue;
            return p;
        }
        unreachable;
    }

    pub fn scope(a: Ip6Address) u8 {
        if (isMultiCast(a)) return a.bytes[1] & 15;
        if (isLinkLocal(a)) return 2;
        if (isLoopBack(a)) return 2;
        if (isSiteLocal(a)) return 5;
        return 14;
    }

    const defined_policies = [_]Policy{
        .{
            .addr = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01".*,
            .len = 15,
            .mask = 0xff,
            .prec = 50,
            .label = 0,
        },
        .{
            .addr = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\x00\x00\x00\x00".*,
            .len = 11,
            .mask = 0xff,
            .prec = 35,
            .label = 4,
        },
        .{
            .addr = "\x20\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
            .len = 1,
            .mask = 0xff,
            .prec = 30,
            .label = 2,
        },
        .{
            .addr = "\x20\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
            .len = 3,
            .mask = 0xff,
            .prec = 5,
            .label = 5,
        },
        .{
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
        .{
            .addr = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*,
            .len = 0,
            .mask = 0,
            .prec = 40,
            .label = 1,
        },
    };
};

pub const UnixAddress = struct {
    path: []const u8,

    pub const max_len = 108;

    pub const InitError = error{NameTooLong};

    pub fn init(p: []const u8) InitError!UnixAddress {
        if (p.len > max_len) return error.NameTooLong;
        return .{ .path = p };
    }

    pub const ListenError = error{
        AddressFamilyUnsupported,
        AddressInUse,
        NetworkDown,
        SystemResources,
        SymLinkLoop,
        FileNotFound,
        NotDir,
        ReadOnlyFileSystem,
        ProcessFdQuotaExceeded,
        SystemFdQuotaExceeded,
        AccessDenied,
        PermissionDenied,
        AddressUnavailable,
    } || Io.Cancelable || Io.UnexpectedError;

    pub const ListenOptions = struct {
        /// How many connections the kernel will accept on the application's behalf.
        /// If more than this many connections pool in the kernel, clients will start
        /// seeing "Connection refused".
        kernel_backlog: u31 = default_kernel_backlog,
    };

    pub fn listen(ua: *const UnixAddress, io: Io, options: ListenOptions) ListenError!Server {
        assert(ua.path.len <= max_len);
        return .{ .socket = .{
            .handle = try io.vtable.netListenUnix(io.userdata, ua, options),
            .address = .{ .ip4 = .loopback(0) },
        } };
    }

    pub const ConnectError = error{
        SystemResources,
        ProcessFdQuotaExceeded,
        SystemFdQuotaExceeded,
        AddressFamilyUnsupported,
        ProtocolUnsupportedBySystem,
        ProtocolUnsupportedByAddressFamily,
        SocketModeUnsupported,
        AccessDenied,
        PermissionDenied,
        SymLinkLoop,
        FileNotFound,
        NotDir,
        ReadOnlyFileSystem,
        WouldBlock,
        NetworkDown,
    } || Io.Cancelable || Io.UnexpectedError;

    pub fn connect(ua: *const UnixAddress, io: Io) ConnectError!Stream {
        assert(ua.path.len <= max_len);
        return .{ .socket = .{
            .handle = try io.vtable.netConnectUnix(io.userdata, ua),
            .address = .{ .ip4 = .loopback(0) },
        } };
    }
};

pub const ReceiveFlags = packed struct(u8) {
    oob: bool = false,
    peek: bool = false,
    trunc: bool = false,
    _: u5 = 0,
};

pub const IncomingMessage = struct {
    /// Populated by receive functions.
    from: IpAddress,
    /// Populated by receive functions, points into the caller-supplied buffer.
    data: []u8,
    /// Supplied by caller before calling receive functions; mutated by receive
    /// functions.
    control: []u8,
    /// Populated by receive functions.
    flags: Flags,

    /// Useful for initializing before calling `receiveManyTimeout`.
    pub const init: IncomingMessage = .{
        .from = undefined,
        .data = undefined,
        .control = &.{},
        .flags = undefined,
    };

    pub const Flags = packed struct(u8) {
        /// indicates end-of-record; the data returned completed a record
        /// (generally used with sockets of type SOCK_SEQPACKET).
        eor: bool,
        /// indicates that the trailing portion of a datagram was discarded
        /// because the datagram was larger than the buffer supplied.
        trunc: bool,
        /// indicates that some control data was discarded due to lack of
        /// space in the buffer for ancil‐ lary data.
        ctrunc: bool,
        /// indicates expedited or out-of-band data was received.
        oob: bool,
        /// indicates that no data was received but an extended error from the
        /// socket error queue.
        errqueue: bool,
        _: u3 = 0,
    };
};

pub const OutgoingMessage = struct {
    address: *const IpAddress,
    data_ptr: [*]const u8,
    /// Initialized with how many bytes of `data_ptr` to send. After sending
    /// succeeds, replaced with how many bytes were actually sent.
    data_len: usize,
    control: []const u8 = &.{},
};

pub const SendFlags = packed struct(u8) {
    confirm: bool = false,
    dont_route: bool = false,
    eor: bool = false,
    oob: bool = false,
    fastopen: bool = false,
    _: u3 = 0,
};

pub const Interface = struct {
    /// Value 0 indicates `none`.
    index: u32,

    pub const none: Interface = .{ .index = 0 };

    pub const Name = struct {
        bytes: [max_len:0]u8,

        pub const max_len = if (@TypeOf(std.posix.IFNAMESIZE) == void) 0 else std.posix.IFNAMESIZE - 1;

        pub fn toSlice(n: *const Name) []const u8 {
            return std.mem.sliceTo(&n.bytes, 0);
        }

        pub fn fromSlice(bytes: []const u8) error{NameTooLong}!Name {
            if (bytes.len > max_len) return error.NameTooLong;
            return .fromSliceUnchecked(bytes);
        }

        /// Asserts bytes.len fits in `max_len`.
        pub fn fromSliceUnchecked(bytes: []const u8) Name {
            assert(bytes.len <= max_len);
            var result: Name = undefined;
            @memcpy(result.bytes[0..bytes.len], bytes);
            result.bytes[bytes.len] = 0;
            return result;
        }

        pub const ResolveError = error{
            InterfaceNotFound,
            AccessDenied,
            SystemResources,
        } || Io.UnexpectedError || Io.Cancelable;

        /// Corresponds to "if_nametoindex" in libc.
        pub fn resolve(n: *const Name, io: Io) ResolveError!Interface {
            return io.vtable.netInterfaceNameResolve(io.userdata, n);
        }
    };

    pub const NameError = Io.UnexpectedError || Io.Cancelable;

    /// Asserts not `none`.
    ///
    /// Corresponds to "if_indextoname" in libc.
    pub fn name(i: Interface, io: Io) NameError!Name {
        assert(i.index != 0);
        return io.vtable.netInterfaceName(io.userdata, i);
    }

    pub fn isNone(i: Interface) bool {
        return i.index == 0;
    }
};

/// An open port with unspecified protocol.
pub const Socket = struct {
    handle: Handle,
    /// Contains the resolved ephemeral port number if requested.
    address: IpAddress,

    pub const Mode = enum {
        /// Provides sequenced, reliable, two-way, connection-based byte
        /// streams. An out-of-band data transmission mechanism may be
        /// supported.
        stream,
        /// Supports datagrams (connectionless, unreliable messages of a fixed
        /// maximum length).
        dgram,
        /// Provides  a  sequenced,  reliable,  two-way connection-based data
        /// transmission path for datagrams of fixed maximum length; a consumer
        /// is required to read an entire packet with each input system call.
        seqpacket,
        /// Provides raw network protocol access.
        raw,
        /// Provides a reliable datagram layer that does not guarantee ordering.
        rdm,
    };

    /// Underlying platform-defined type which may or may not be
    /// interchangeable with a file system file descriptor.
    pub const Handle = switch (native_os) {
        .windows => std.os.windows.ws2_32.SOCKET,
        else => std.posix.fd_t,
    };

    /// Leaves `address` in a valid state.
    pub fn close(s: *const Socket, io: Io) void {
        io.vtable.netClose(io.userdata, s.handle);
    }

    pub const SendError = error{
        /// The socket type requires that message be sent atomically, and the
        /// size of the message to be sent made this impossible. The message
        /// was not transmitted, or was partially transmitted.
        MessageOversize,
        /// The output queue for a network interface was full. This generally indicates that the
        /// interface has stopped sending, but may be caused by transient congestion. (Normally,
        /// this does not occur in Linux. Packets are just silently dropped when a device queue
        /// overflows.)
        ///
        /// This is also caused when there is not enough kernel memory available.
        SystemResources,
        /// No route to network.
        NetworkUnreachable,
        /// Network reached but no route to host.
        HostUnreachable,
        /// The local network interface used to reach the destination is offline.
        NetworkDown,
        /// The destination address is not listening. Can still occur for
        /// connectionless messages.
        ConnectionRefused,
        /// Operating system or protocol does not support the address family.
        AddressFamilyUnsupported,
        /// Another TCP Fast Open is already in progress.
        FastOpenAlreadyInProgress,
        /// Network session was unexpectedly closed by recipient.
        ConnectionResetByPeer,
        /// Local end has been shut down on a connection-oriented socket, or
        /// the socket was never connected.
        SocketUnconnected,
        /// An attempt was made to send to a network/broadcast address as
        /// though it was a unicast address.
        AccessDenied,
    } || Io.UnexpectedError || Io.Cancelable;

    /// Transfers `data` to `dest`, connectionless, in one packet.
    pub fn send(s: *const Socket, io: Io, dest: *const IpAddress, data: []const u8) SendError!void {
        var message: OutgoingMessage = .{ .address = dest, .data_ptr = data.ptr, .data_len = data.len };
        const err, const n = io.vtable.netSend(io.userdata, s.handle, (&message)[0..1], .{});
        if (n != 1) return err.?;
        if (message.data_len != data.len) return error.MessageOversize;
    }

    pub fn sendMany(s: *const Socket, io: Io, messages: []OutgoingMessage, flags: SendFlags) SendError!void {
        return io.vtable.netSend(io.userdata, s.handle, messages, flags);
    }

    pub const ReceiveError = error{
        /// Insufficient memory or other resource internal to the operating system.
        SystemResources,
        /// Per-process limit on the number of open file descriptors has been reached.
        ProcessFdQuotaExceeded,
        /// System-wide limit on the total number of open files has been reached.
        SystemFdQuotaExceeded,
        /// Local end has been shut down on a connection-oriented socket, or
        /// the socket was never connected.
        SocketUnconnected,
        /// The socket type requires that message be sent atomically, and the
        /// size of the message to be sent made this impossible. The message
        /// was not transmitted, or was partially transmitted.
        MessageOversize,
        /// Network connection was unexpectedly closed by sender.
        ConnectionResetByPeer,
        /// The local network interface used to reach the destination is offline.
        NetworkDown,
    } || Io.UnexpectedError || Io.Cancelable;

    /// Waits for data. Connectionless.
    ///
    /// See also:
    /// * `receiveTimeout`
    pub fn receive(s: *const Socket, io: Io, buffer: []u8) ReceiveError!IncomingMessage {
        var message: IncomingMessage = .init;
        const maybe_err, const count = io.vtable.netReceive(io.userdata, s.handle, (&message)[0..1], buffer, .{}, .none);
        if (maybe_err) |err| switch (err) {
            // No timeout is passed to `netReceieve`, so it must not return timeout related errors.
            error.Timeout, error.UnsupportedClock => unreachable,
            else => |e| return e,
        };
        assert(1 == count);
        return message;
    }

    pub const ReceiveTimeoutError = ReceiveError || Io.Timeout.Error;

    /// Waits for data. Connectionless.
    ///
    /// Returns `error.Timeout` if no message arrives early enough.
    ///
    /// See also:
    /// * `receive`
    /// * `receiveManyTimeout`
    pub fn receiveTimeout(
        s: *const Socket,
        io: Io,
        buffer: []u8,
        timeout: Io.Timeout,
    ) ReceiveTimeoutError!IncomingMessage {
        var message: IncomingMessage = .init;
        const maybe_err, const count = io.vtable.netReceive(io.userdata, s.handle, (&message)[0..1], buffer, .{}, timeout);
        if (maybe_err) |err| return err;
        assert(1 == count);
        return message;
    }

    /// Waits until at least one message is delivered, possibly returning more
    /// than one message. Connectionless.
    ///
    /// Returns number of messages received, or `error.Timeout` if no message
    /// arrives early enough.
    ///
    /// See also:
    /// * `receive`
    /// * `receiveTimeout`
    pub fn receiveManyTimeout(
        s: *const Socket,
        io: Io,
        /// Function assumes each element has initialized `control` field.
        /// Initializing with `IncomingMessage.init` may be helpful.
        message_buffer: []IncomingMessage,
        data_buffer: []u8,
        flags: ReceiveFlags,
        timeout: Io.Timeout,
    ) struct { ?ReceiveTimeoutError, usize } {
        return io.vtable.netReceive(io.userdata, s.handle, message_buffer, data_buffer, flags, timeout);
    }
};

/// An open socket connection with a network protocol that guarantees
/// sequencing, delivery, and prevents repetition. Typically TCP or UNIX domain
/// socket.
pub const Stream = struct {
    socket: Socket,

    const max_iovecs_len = 8;

    pub fn close(s: *const Stream, io: Io) void {
        io.vtable.netClose(io.userdata, s.socket.handle);
    }

    pub const Reader = struct {
        io: Io,
        interface: Io.Reader,
        stream: Stream,
        err: ?Error,

        pub const Error = error{
            SystemResources,
            ConnectionResetByPeer,
            Timeout,
            SocketUnconnected,
            /// The file descriptor does not hold the required rights to read
            /// from it.
            AccessDenied,
            NetworkDown,
        } || Io.Cancelable || Io.UnexpectedError;

        pub fn init(stream: Stream, io: Io, buffer: []u8) Reader {
            return .{
                .io = io,
                .interface = .{
                    .vtable = &.{
                        .stream = streamImpl,
                        .readVec = readVec,
                    },
                    .buffer = buffer,
                    .seek = 0,
                    .end = 0,
                },
                .stream = stream,
                .err = null,
            };
        }

        fn streamImpl(io_r: *Io.Reader, io_w: *Io.Writer, limit: Io.Limit) Io.Reader.StreamError!usize {
            const dest = limit.slice(try io_w.writableSliceGreedy(1));
            var data: [1][]u8 = .{dest};
            const n = try readVec(io_r, &data);
            io_w.advance(n);
            return n;
        }

        fn readVec(io_r: *Io.Reader, data: [][]u8) Io.Reader.Error!usize {
            const r: *Reader = @alignCast(@fieldParentPtr("interface", io_r));
            const io = r.io;
            var iovecs_buffer: [max_iovecs_len][]u8 = undefined;
            const dest_n, const data_size = try io_r.writableVector(&iovecs_buffer, data);
            const dest = iovecs_buffer[0..dest_n];
            assert(dest[0].len > 0);
            const n = io.vtable.netRead(io.userdata, r.stream.socket.handle, dest) catch |err| {
                r.err = err;
                return error.ReadFailed;
            };
            if (n == 0) {
                return error.EndOfStream;
            }
            if (n > data_size) {
                r.interface.end += n - data_size;
                return data_size;
            }
            return n;
        }
    };

    pub const Writer = struct {
        io: Io,
        interface: Io.Writer,
        stream: Stream,
        err: ?Error = null,

        pub const Error = error{
            /// Another TCP Fast Open is already in progress.
            FastOpenAlreadyInProgress,
            /// Network session was unexpectedly closed by recipient.
            ConnectionResetByPeer,
            /// The output queue for a network interface was full. This generally indicates that the
            /// interface has stopped sending, but may be caused by transient congestion. (Normally,
            /// this does not occur in Linux. Packets are just silently dropped when a device queue
            /// overflows.)
            ///
            /// This is also caused when there is not enough kernel memory available.
            SystemResources,
            /// No route to network.
            NetworkUnreachable,
            /// Network reached but no route to host.
            HostUnreachable,
            /// The local network interface used to reach the destination is down.
            NetworkDown,
            /// The destination address is not listening.
            ConnectionRefused,
            /// The passed address didn't have the correct address family in its sa_family field.
            AddressFamilyUnsupported,
            /// Local end has been shut down on a connection-oriented socket, or
            /// the socket was never connected.
            SocketUnconnected,
            SocketNotBound,
        } || Io.UnexpectedError || Io.Cancelable;

        pub fn init(stream: Stream, io: Io, buffer: []u8) Writer {
            return .{
                .io = io,
                .stream = stream,
                .interface = .{
                    .vtable = &.{ .drain = drain },
                    .buffer = buffer,
                },
            };
        }

        fn drain(io_w: *Io.Writer, data: []const []const u8, splat: usize) Io.Writer.Error!usize {
            const w: *Writer = @alignCast(@fieldParentPtr("interface", io_w));
            const io = w.io;
            const buffered = io_w.buffered();
            const handle = w.stream.socket.handle;
            const n = io.vtable.netWrite(io.userdata, handle, buffered, data, splat) catch |err| {
                w.err = err;
                return error.WriteFailed;
            };
            return io_w.consume(n);
        }
    };

    pub fn reader(stream: Stream, io: Io, buffer: []u8) Reader {
        return .init(stream, io, buffer);
    }

    pub fn writer(stream: Stream, io: Io, buffer: []u8) Writer {
        return .init(stream, io, buffer);
    }
};

pub const Server = struct {
    socket: Socket,

    pub fn deinit(s: *Server, io: Io) void {
        s.socket.close(io);
        s.* = undefined;
    }

    pub const AcceptError = error{
        /// The per-process limit on the number of open file descriptors has been reached.
        ProcessFdQuotaExceeded,
        /// The system-wide limit on the total number of open files has been reached.
        SystemFdQuotaExceeded,
        /// Not enough free memory. This often means that the memory allocation is limited
        /// by the socket buffer limits, not by the system memory.
        SystemResources,
        /// The network subsystem has failed.
        NetworkDown,
        /// No connection is already queued and ready to be accepted, and
        /// the socket is configured as non-blocking.
        WouldBlock,
        /// An incoming connection was indicated, but was subsequently terminated by the
        /// remote peer prior to accepting the call.
        ConnectionAborted,
        /// Firewall rules forbid connection.
        BlockedByFirewall,
        ProtocolFailure,
    } || Io.UnexpectedError || Io.Cancelable;

    /// Blocks until a client connects to the server.
    pub fn accept(s: *Server, io: Io) AcceptError!Stream {
        return io.vtable.netAccept(io.userdata, s.socket.handle);
    }
};

test "parsing IPv6 addresses" {
    try testIp6Parse("fe80::e0e:76ff:fed4:cf22%eno1");
    try testIp6Parse("2001:db8::1");
    try testIp6ParseTransform("2001:db8::1", "2001:0db8:0000:0000:0000:0000:0000:0001");
    try testIp6Parse("::1");
    try testIp6Parse("::");
    try testIp6Parse("fe80::1");
    try testIp6Parse("fe80::abcd:ef12%3");
    try testIp6Parse("ff02::");
    try testIp6Parse("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff");
}

fn testIp6Parse(input: []const u8) !void {
    return testIp6ParseTransform(input, input);
}

fn testIp6ParseTransform(expected: []const u8, input: []const u8) !void {
    const ua = switch (Ip6Address.Unresolved.parse(input)) {
        .success => |p| p,
        else => |x| {
            std.debug.print("failed to parse \"{s}\": {any}\n", .{ input, x });
            return error.TestFailed;
        },
    };
    var buffer: [100]u8 = undefined;
    const result = try std.fmt.bufPrint(&buffer, "{f}", .{ua});
    try std.testing.expectEqualStrings(expected, result);
}

test {
    _ = HostName;
    _ = @import("net/test.zig");
}
