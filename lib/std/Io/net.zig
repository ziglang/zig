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
    pub fn parse(name: []const u8, port: u16) !IpAddress {
        if (Ip4Address.parse(name, port)) |ip4| {
            return .{ .ip4 = ip4 };
        } else |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            error.NonCanonical,
            => {},
        }

        if (Ip6Address.parse(name, port)) |ip6| {
            return .{ .ip6 = ip6 };
        } else |err| switch (err) {
            error.Overflow,
            error.InvalidEnd,
            error.InvalidCharacter,
            error.Incomplete,
            error.InvalidIpv4Mapping,
            => {},
        }

        return error.InvalidIpAddressFormat;
    }

    pub fn parseIp6(buffer: []const u8, port: u16) Ip6Address.ParseError!IpAddress {
        return .{ .ip6 = try Ip6Address.parse(buffer, port) };
    }

    pub fn parseIp4(buffer: []const u8, port: u16) Ip4Address.ParseError!IpAddress {
        return .{ .ip4 = try Ip4Address.parse(buffer, port) };
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

pub const Ip4Address = struct {
    bytes: [4]u8,
    port: u16,

    pub fn localhost(port: u16) Ip4Address {
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

pub const Ip6Address = struct {
    /// Native endian
    port: u16,
    /// Big endian
    bytes: [16]u8,
    flowinfo: u32 = 0,
    scope_id: u32 = 0,

    pub const ParseError = error{
        Overflow,
        InvalidCharacter,
        InvalidEnd,
        InvalidIpv4Mapping,
        Incomplete,
    };

    pub const Policy = struct {
        addr: [16]u8,
        len: u8,
        mask: u8,
        prec: u8,
        label: u8,
    };

    pub fn localhost(port: u16) Ip6Address {
        return .{
            .bytes = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
            .port = port,
        };
    }

    pub fn parse(buffer: []const u8, port: u16) ParseError!Ip6Address {
        var result: Ip6Address = .{
            .port = port,
            .bytes = undefined,
        };
        var ip_slice: *[16]u8 = &result.bytes;

        var tail: [16]u8 = undefined;

        var x: u16 = 0;
        var saw_any_digits = false;
        var index: u8 = 0;
        var scope_id = false;
        var abbrv = false;
        for (buffer, 0..) |c, i| {
            if (scope_id) {
                if (c >= '0' and c <= '9') {
                    const digit = c - '0';
                    {
                        const ov = @mulWithOverflow(result.scope_id, 10);
                        if (ov[1] != 0) return error.Overflow;
                        result.scope_id = ov[0];
                    }
                    {
                        const ov = @addWithOverflow(result.scope_id, digit);
                        if (ov[1] != 0) return error.Overflow;
                        result.scope_id = ov[0];
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
                const start_index = std.mem.lastIndexOfScalar(u8, buffer[0..i], ':').? + 1;
                const addr = (Ip4Address.parse(buffer[start_index..], 0) catch {
                    return error.InvalidIpv4Mapping;
                }).bytes;
                ip_slice = result.bytes[0..];
                ip_slice[10] = 0xff;
                ip_slice[11] = 0xff;

                ip_slice[12] = addr[0];
                ip_slice[13] = addr[1];
                ip_slice[14] = addr[2];
                ip_slice[15] = addr[3];
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
            @memcpy(result.bytes[16 - index ..][0..index], ip_slice[0..index]);
            return result;
        }
    }

    pub fn format(a: Ip6Address, w: *Io.Writer) Io.Writer.Error!void {
        const bytes = &a.bytes;
        if (std.mem.eql(u8, bytes[0..12], &[_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff })) {
            try w.print("[::ffff:{d}.{d}.{d}.{d}]:{d}", .{
                bytes[12], bytes[13], bytes[14], bytes[15], a.port,
            });
            return;
        }
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

        try w.writeAll("[");
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
        try w.print("]:{d}", .{a.port});
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

pub const Stream = struct {
    /// Underlying platform-defined type which may or may not be
    /// interchangeable with a file system file descriptor.
    handle: Handle,

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

pub const InterfaceIndexError = error{
    InterfaceNotFound,
    AccessDenied,
    SystemResources,
} || Io.UnexpectedError || Io.Cancelable;

/// Otherwise known as "if_nametoindex".
pub fn interfaceIndex(io: Io, name: []const u8) InterfaceIndexError!u32 {
    return io.vtable.netInterfaceIndex(io.userdata, name);
}

test {
    _ = HostName;
}
