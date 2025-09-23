const builtin = @import("builtin");
const native_os = builtin.os.tag;
const std = @import("../std.zig");
const Io = std.Io;
const assert = std.debug.assert;

pub const HostName = @import("net/HostName.zig");

pub const ListenError = std.net.Address.ListenError || Io.Cancelable;

pub const ListenOptions = struct {
    /// How many connections the kernel will accept on the application's behalf.
    /// If more than this many connections pool in the kernel, clients will start
    /// seeing "Connection refused".
    kernel_backlog: u31 = 128,
    /// Sets SO_REUSEADDR and SO_REUSEPORT on POSIX.
    /// Sets SO_REUSEADDR on Windows, which is roughly equivalent.
    reuse_address: bool = false,
    force_nonblocking: bool = false,
};

pub const IpAddress = union(enum) {
    ip4: Ip4Address,
    ip6: Ip6Address,

    pub const Family = @typeInfo(IpAddress).@"union".tag_type.?;

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

    pub fn eql(a: IpAddress, b: IpAddress) bool {
        return switch (a) {
            .ip4 => |a_ip4| switch (b) {
                .ip4 => |b_ip4| a_ip4.eql(b_ip4),
                else => false,
            },
            .ip6 => |a_ip6| switch (b) {
                .ip6 => |b_ip6| a_ip6.eql(b_ip6),
                else => false,
            },
        };
    }

    /// The returned `Server` has an open `stream`.
    pub fn listen(address: IpAddress, io: Io, options: ListenOptions) ListenError!Server {
        return io.vtable.listen(io.userdata, address, options);
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

    /// An IPv6 address but with `Interface` as a name rather than index.
    pub const Unresolved = struct {
        /// Big endian
        bytes: [16]u8,
        interface_name: ?Interface.Name,

        pub const Parsed = union(enum) {
            success: Unresolved,
            invalid_byte: usize,
            unexpected_end,
            junk_after_end: usize,
            interface_name_oversized: usize,
        };

        pub fn parse(text: []const u8) Parsed {
            if (text.len < 2) return .unexpected_end;
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
                        parts[parts_i] = parts[parts_i] * 16 + digit;
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
                        parts[parts_i] = parts[parts_i] * 16 + digit;
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
                            if (text.len - text_i == 0) return .unexpected_end;
                            continue :c text[text_i];
                        }
                    },
                    '%' => {
                        if (digit_i == 0) return .{ .invalid_byte = text_i };
                        parts_i += 1;
                        text_i += 1;
                        const name = text[text_i..];
                        if (name.len > Interface.Name.max_len) return .{ .interface_name_oversized = text_i };
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
                        if (remaining != 0) return .unexpected_end;
                    }

                    // Workaround that can be removed when this proposal is
                    // implemented https://github.com/ziglang/zig/issues/19755
                    if ((comptime @import("builtin").cpu.arch.endian()) != .big) {
                        for (&parts) |*part| part.* = @byteSwap(part.*);
                    }

                    return .{ .success = .{
                        .bytes = @bitCast(parts),
                        .interface_name = if (interface_name_text) |t| .fromSliceUnchecked(t) else null,
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
            if (u.interface_name) |n| try w.print("%{s}", .{n.toSlice()});
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
    /// called instead.
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
                .interface = if (p.interface_name) |n| try n.resolve(io) else .none,
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

pub const Interface = struct {
    /// Value 0 indicates `none`.
    index: u32,

    pub const none: Interface = .{ .index = 0 };

    pub const Name = struct {
        bytes: [max_len:0]u8,

        pub const max_len = std.posix.IFNAMESIZE - 1;

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

/// An open socket connection with a network protocol that guarantees
/// sequencing, delivery, and prevents repetition. Typically TCP or UNIX domain
/// socket.
pub const Stream = struct {
    handle: Handle,

    /// Underlying platform-defined type which may or may not be
    /// interchangeable with a file system file descriptor.
    pub const Handle = switch (native_os) {
        .windows => std.windows.ws2_32.SOCKET,
        else => std.posix.fd_t,
    };

    pub fn close(s: Stream, io: Io) void {
        return io.vtable.close(io.userdata, s);
    }

    pub const Reader = struct {
        io: Io,
        interface: Io.Reader,
        stream: Stream,
        err: ?Error,

        pub const Error = std.net.Stream.ReadError || Io.Cancelable || Io.Writer.Error || error{EndOfStream};

        pub fn init(stream: Stream, buffer: []u8) Reader {
            return .{
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

        fn readVec(io_r: *Reader, data: [][]u8) Io.Reader.Error!usize {
            const r: *Reader = @alignCast(@fieldParentPtr("interface", io_r));
            const io = r.io;
            return io.vtable.netReadVec(io.vtable.userdata, r.stream, io_r, data);
        }
    };

    pub const Writer = struct {
        io: Io,
        interface: Io.Writer,
        stream: Stream,
        err: ?Error = null,

        pub const Error = std.net.Stream.WriteError || Io.Cancelable;

        pub fn init(stream: Stream, buffer: []u8) Writer {
            return .{
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
            const n = try io.vtable.netWrite(io.vtable.userdata, w.stream, buffered, data, splat);
            return io_w.consume(n);
        }
    };

    pub fn reader(stream: Stream, buffer: []u8) Reader {
        return .init(stream, buffer);
    }

    pub fn writer(stream: Stream, buffer: []u8) Writer {
        return .init(stream, buffer);
    }
};

pub const Server = struct {
    listen_address: IpAddress,
    stream: Stream,

    pub const Connection = struct {
        stream: Stream,
        address: IpAddress,
    };

    pub fn deinit(s: *Server, io: Io) void {
        s.stream.close(io);
        s.* = undefined;
    }

    pub const AcceptError = std.posix.AcceptError || Io.Cancelable;

    /// Blocks until a client connects to the server. The returned `Connection` has
    /// an open stream.
    pub fn accept(s: *Server, io: Io) AcceptError!Connection {
        return io.vtable.accept(io, s);
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
}
