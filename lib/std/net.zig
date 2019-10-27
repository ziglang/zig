const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const net = @This();
const mem = std.mem;
const os = std.os;

pub const TmpWinAddr = struct {
    family: u8,
    data: [14]u8,
};

pub const OsAddress = switch (builtin.os) {
    .windows => TmpWinAddr,
    else => os.sockaddr,
};

/// This data structure is a "view". The underlying data might have references
/// to owned memory which must live longer than this struct.
pub const Address = struct {
    os_addr: OsAddress,

    pub fn initIp4(ip4: u32, _port: u16) Address {
        return Address{
            .os_addr = os.sockaddr{
                .in = os.sockaddr_in{
                    .family = os.AF_INET,
                    .port = mem.nativeToBig(u16, _port),
                    .addr = ip4,
                    .zero = [_]u8{0} ** 8,
                },
            },
        };
    }

    pub fn initIp6(ip6: Ip6Addr, _port: u16) Address {
        return Address{
            .os_addr = os.sockaddr{
                .in6 = os.sockaddr_in6{
                    .family = os.AF_INET6,
                    .port = mem.nativeToBig(u16, _port),
                    .flowinfo = 0,
                    .addr = ip6.addr,
                    .scope_id = ip6.scope_id,
                },
            },
        };
    }

    pub fn port(self: Address) u16 {
        return mem.bigToNative(u16, self.os_addr.in.port);
    }

    pub fn initPosix(addr: os.sockaddr) Address {
        return Address{ .os_addr = addr };
    }

    pub fn format(
        self: Address,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        context: var,
        comptime Errors: type,
        output: fn (@typeOf(context), []const u8) Errors!void,
    ) !void {
        switch (self.os_addr.in.family) {
            os.AF_INET => {
                const native_endian_port = mem.bigToNative(u16, self.os_addr.in.port);
                const bytes = @ptrCast(*const [4]u8, &self.os_addr.in.addr);
                try std.fmt.format(
                    context,
                    Errors,
                    output,
                    "{}.{}.{}.{}:{}",
                    bytes[0],
                    bytes[1],
                    bytes[2],
                    bytes[3],
                    native_endian_port,
                );
            },
            os.AF_INET6 => {
                const ZeroRun = struct {
                    index: usize,
                    count: usize,
                };
                const native_endian_port = mem.bigToNative(u16, self.os_addr.in6.port);
                const big_endian_parts = @ptrCast(*align(1) const [8]u16, &self.os_addr.in6.addr);
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

                var longest_zero_run: ?ZeroRun = null;
                var this_zero_run: ?ZeroRun = null;
                for (native_endian_parts) |part, i| {
                    if (part == 0) {
                        if (this_zero_run) |*zr| {
                            zr.count += 1;
                        } else {
                            this_zero_run = ZeroRun{
                                .index = i,
                                .count = 1,
                            };
                        }
                    } else if (this_zero_run) |zr| {
                        if (longest_zero_run) |lzr| {
                            if (zr.count > lzr.count and zr.count > 1) {
                                longest_zero_run = zr;
                            }
                        } else {
                            longest_zero_run = zr;
                        }
                    }
                }
                try output(context, "[");
                var i: usize = 0;
                while (i < native_endian_parts.len) {
                    if (i != 0) try output(context, ":");

                    if (longest_zero_run) |lzr| {
                        if (lzr.index == i) {
                            i += lzr.count;
                            continue;
                        }
                    }

                    const part = native_endian_parts[i];
                    try std.fmt.format(context, Errors, output, "{x}", part);
                    i += 1;
                }
                try std.fmt.format(context, Errors, output, "]:{}", native_endian_port);
            },
            else => return output(context, "(unrecognized address family)"),
        }
    }
};

pub fn parseIp4(buf: []const u8) !u32 {
    var result: u32 = undefined;
    const out_ptr = @sliceToBytes((*[1]u32)(&result)[0..]);

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

pub const Ip6Addr = struct {
    scope_id: u32,
    addr: [16]u8,
};

pub fn parseIp6(buf: []const u8) !Ip6Addr {
    var result: Ip6Addr = undefined;
    result.scope_id = 0;
    const ip_slice = result.addr[0..];

    var x: u16 = 0;
    var saw_any_digits = false;
    var index: u8 = 0;
    var scope_id = false;
    for (buf) |c| {
        if (scope_id) {
            if (c >= '0' and c <= '9') {
                const digit = c - '0';
                if (@mulWithOverflow(u32, result.scope_id, 10, &result.scope_id)) {
                    return error.Overflow;
                }
                if (@addWithOverflow(u32, result.scope_id, digit, &result.scope_id)) {
                    return error.Overflow;
                }
            } else {
                return error.InvalidCharacter;
            }
        } else if (c == ':') {
            if (!saw_any_digits) {
                return error.InvalidCharacter;
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
            if (index == 14) {
                ip_slice[index] = @truncate(u8, x >> 8);
                index += 1;
                ip_slice[index] = @truncate(u8, x);
                index += 1;
            }
            scope_id = true;
            saw_any_digits = false;
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

    if (!saw_any_digits) {
        return error.Incomplete;
    }

    if (scope_id) {
        return result;
    }

    if (index == 14) {
        ip_slice[14] = @truncate(u8, x >> 8);
        ip_slice[15] = @truncate(u8, x);
        return result;
    }

    return error.Incomplete;
}

test "std.net.parseIp4" {
    assert((try parseIp4("127.0.0.1")) == mem.bigToNative(u32, 0x7f000001));

    testParseIp4Fail("256.0.0.1", error.Overflow);
    testParseIp4Fail("x.0.0.1", error.InvalidCharacter);
    testParseIp4Fail("127.0.0.1.1", error.InvalidEnd);
    testParseIp4Fail("127.0.0.", error.Incomplete);
    testParseIp4Fail("100..0.1", error.InvalidCharacter);
}

fn testParseIp4Fail(buf: []const u8, expected_err: anyerror) void {
    if (parseIp4(buf)) |_| {
        @panic("expected error");
    } else |e| {
        assert(e == expected_err);
    }
}

test "std.net.parseIp6" {
    const ip6 = try parseIp6("FF01:0:0:0:0:0:0:FB");
    const addr = Address.initIp6(ip6, 80);
    var buf: [100]u8 = undefined;
    const printed = try std.fmt.bufPrint(&buf, "{}", addr);
    std.testing.expect(mem.eql(u8, "[ff01::fb]:80", printed));
}

pub fn connectUnixSocket(path: []const u8) !std.fs.File {
    const opt_non_block = if (std.event.Loop.instance != null) os.SOCK_NONBLOCK else 0;
    const sockfd = try os.socket(
        os.AF_UNIX,
        os.SOCK_STREAM | os.SOCK_CLOEXEC | opt_non_block,
        0,
    );
    errdefer os.close(sockfd);

    var sock_addr = os.sockaddr{
        .un = os.sockaddr_un{
            .family = os.AF_UNIX,
            .path = undefined,
        },
    };

    if (path.len > @typeOf(sock_addr.un.path).len) return error.NameTooLong;
    mem.copy(u8, sock_addr.un.path[0..], path);
    const size = @intCast(u32, @sizeOf(os.sa_family_t) + path.len);
    if (std.event.Loop.instance) |loop| {
        try os.connect_async(sockfd, &sock_addr, size);
        try loop.linuxWaitFd(sockfd, os.EPOLLIN | os.EPOLLOUT | os.EPOLLET);
        try os.getsockoptError(sockfd);
    } else {
        try os.connect(sockfd, &sock_addr, size);
    }

    return std.fs.File.openHandle(sockfd);
}

pub const AddressList = struct {
    arena: std.heap.ArenaAllocator,
    addrs: []Address,
    canon_name: ?[]u8,

    fn deinit(self: *AddressList) void {
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

    if (builtin.link_libc) {
        const name_c = try std.cstr.addNullByte(allocator, name);
        defer allocator.free(name_c);

        const port_c = try std.fmt.allocPrint(allocator, "{}\x00", port);
        defer allocator.free(port_c);

        const hints = os.addrinfo{
            .flags = os.AI_NUMERICSERV,
            .family = os.AF_UNSPEC,
            .socktype = os.SOCK_STREAM,
            .protocol = os.IPPROTO_TCP,
            .canonname = null,
            .addr = null,
            .addrlen = 0,
            .next = null,
        };
        var res: *os.addrinfo = undefined;
        switch (os.system.getaddrinfo(name_c.ptr, port_c.ptr, &hints, &res)) {
            0 => {},
            os.EAI_ADDRFAMILY => return error.HostLacksNetworkAddresses,
            os.EAI_AGAIN => return error.TemporaryNameServerFailure,
            os.EAI_BADFLAGS => unreachable, // Invalid hints
            os.EAI_FAIL => return error.NameServerFailure,
            os.EAI_FAMILY => return error.AddressFamilyNotSupported,
            os.EAI_MEMORY => return error.OutOfMemory,
            os.EAI_NODATA => return error.HostLacksNetworkAddresses,
            os.EAI_NONAME => return error.UnknownName,
            os.EAI_SERVICE => return error.ServiceUnavailable,
            os.EAI_SOCKTYPE => unreachable, // Invalid socket type requested in hints
            os.EAI_SYSTEM => switch (os.errno(-1)) {
                else => |e| return os.unexpectedErrno(e),
            },
            else => unreachable,
        }
        defer os.system.freeaddrinfo(res);

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
            result.addrs[i] = Address.initPosix(addr.*);

            if (info.canonname) |n| {
                if (result.canon_name == null) {
                    result.canon_name = try mem.dupe(arena, u8, mem.toSliceConst(u8, n));
                }
            }
            i += 1;
        }

        return result;
    }
    if (builtin.os == .linux) {
        const flags = os.AI_NUMERICSERV;
        const family = os.AF_INET; //TODO os.AF_UNSPEC;
        // The limit of 48 results is a non-sharp bound on the number of addresses
        // that can fit in one 512-byte DNS packet full of v4 results and a second
        // packet full of v6 results. Due to headers, the actual limit is lower.
        var buf: [48]LookupAddr = undefined;
        var canon_buf: [256]u8 = undefined;
        var canon_len: usize = 0;
        const cnt = try linuxLookupName(buf[0..], &canon_buf, &canon_len, name, family, flags);

        result.addrs = try arena.alloc(Address, cnt);

        if (canon_len != 0) {
            result.canon_name = try mem.dupe(arena, u8, canon_buf[0..canon_len]);
        }

        var i: usize = 0;
        while (i < cnt) : (i += 1) {
            const os_addr = if (buf[i].family == os.AF_INET6)
                os.sockaddr{
                    .in6 = os.sockaddr_in6{
                        .family = buf[i].family,
                        .port = mem.nativeToBig(u16, port),
                        .flowinfo = 0,
                        .addr = buf[i].addr,
                        .scope_id = buf[i].scope_id,
                    },
                }
            else
                os.sockaddr{
                    .in = os.sockaddr_in{
                        .family = buf[i].family,
                        .port = mem.nativeToBig(u16, port),
                        .addr = @ptrCast(*align(1) u32, &buf[i].addr).*,
                        .zero = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
                    },
                };
            result.addrs[i] = Address.initPosix(os_addr);
        }

        return result;
    }
    @compileError("std.net.getAddresses unimplemented for this OS");
}

const LookupAddr = struct {
    family: os.sa_family_t,
    scope_id: u32 = 0,
    addr: [16]u8, // could be IPv4 or IPv6
    sortkey: i32 = 0,
};

fn linuxLookupName(
    buf: []LookupAddr,
    canon_buf: []u8,
    canon_len: *usize,
    opt_name: ?[]const u8,
    family: i32,
    flags: u32,
) !usize {
    var cnt: usize = 0;
    if (opt_name) |name| {
        // reject empty name and check len so it fits into temp bufs
        if (name.len >= 254) return error.UnknownName;
        mem.copy(u8, canon_buf, name);
        canon_len.* = name.len;

        cnt = (linuxLookupNameFromNumeric(buf, name, family) catch |err| switch (err) {
            error.ExpectedIPv6ButFoundIPv4 => unreachable,
            error.ExpectedIPv4ButFoundIPv6 => unreachable,
        });
        if (cnt == 0 and (flags & os.AI_NUMERICHOST) == 0) {
            cnt = try linuxLookupNameFromHosts(buf, canon_buf, canon_len, name, family);
        }
    } else {
        canon_len.* = 0;
        cnt = linuxLookupNameFromNull(buf, family, flags);
    }
    if (cnt == 0) return error.UnknownName;

    // No further processing is needed if there are fewer than 2
    // results or if there are only IPv4 results.
    if (cnt == 1 or family == os.AF_INET) return cnt;

    @panic("port the RFC 3484/6724 destination address selection from musl libc");
}

fn linuxLookupNameFromNumeric(buf: []LookupAddr, name: []const u8, family: i32) !usize {
    if (parseIp4(name)) |ip4| {
        if (family == os.AF_INET6) return error.ExpectedIPv6ButFoundIPv4;
        // TODO [0..4] should return *[4]u8, making this pointer cast unnecessary
        mem.writeIntNative(u32, @ptrCast(*[4]u8, &buf[0].addr), ip4);
        buf[0].family = os.AF_INET;
        buf[0].scope_id = 0;
        return 1;
    } else |err| switch (err) {
        error.Overflow,
        error.InvalidEnd,
        error.InvalidCharacter,
        error.Incomplete,
        => {},
    }

    if (parseIp6(name)) |ip6| {
        if (family == os.AF_INET) return error.ExpectedIPv4ButFoundIPv6;
        @memcpy(&buf[0].addr, &ip6.addr, 16);
        buf[0].family = os.AF_INET6;
        buf[0].scope_id = ip6.scope_id;
        return 1;
    } else |err| switch (err) {
        error.Overflow,
        error.InvalidEnd,
        error.InvalidCharacter,
        error.Incomplete,
        => {},
    }

    return 0;
}

fn linuxLookupNameFromNull(buf: []LookupAddr, family: i32, flags: u32) usize {
    var cnt: usize = 0;
    if ((flags & os.AI_PASSIVE) != 0) {
        if (family != os.AF_INET6) {
            buf[cnt] = LookupAddr{
                .family = os.AF_INET,
                .addr = [1]u8{0} ** 16,
            };
            cnt += 1;
        }
        if (family != os.AF_INET) {
            buf[cnt] = LookupAddr{
                .family = os.AF_INET6,
                .addr = [1]u8{0} ** 16,
            };
            cnt += 1;
        }
    } else {
        if (family != os.AF_INET6) {
            buf[cnt] = LookupAddr{
                .family = os.AF_INET,
                .addr = [4]u8{ 127, 0, 0, 1 } ++ ([1]u8{0} ** 12),
            };
            cnt += 1;
        }
        if (family != os.AF_INET) {
            buf[cnt] = LookupAddr{
                .family = os.AF_INET6,
                .addr = ([1]u8{0} ** 15) ++ [1]u8{1},
            };
            cnt += 1;
        }
    }
    return cnt;
}

fn linuxLookupNameFromHosts(
    buf: []LookupAddr,
    canon_buf: []u8,
    canon_len: *usize,
    name: []const u8,
    family: i32,
) !usize {
    const file = std.fs.File.openReadC(c"/etc/hosts") catch |err| switch (err) {
        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        => return 0,
        else => |e| return e,
    };
    defer file.close();

    var cnt: usize = 0;
    const stream = &std.io.BufferedInStream(std.fs.File.ReadError).init(&file.inStream().stream).stream;
    var line_buf: [512]u8 = undefined;
    while (stream.readUntilDelimiterOrEof(&line_buf, '\n') catch |err| switch (err) {
        error.StreamTooLong => blk: {
            // Skip to the delimiter in the stream, to fix parsing
            try stream.skipUntilDelimiterOrEof('\n');
            // Use the truncated line. A truncated comment or hostname will be handled correctly.
            break :blk line_buf[0..];
        },
        else => |e| return e,
    }) |line| {
        const no_comment_line = mem.separate(line, "#").next().?;

        var line_it = mem.tokenize(no_comment_line, " \t");
        const ip_text = line_it.next() orelse continue;
        var first_name_text: ?[]const u8 = null;
        while (line_it.next()) |name_text| {
            if (first_name_text == null) first_name_text = name_text;
            if (mem.eql(u8, name_text, name)) {
                break;
            }
        } else continue;

        switch (linuxLookupNameFromNumeric(buf[cnt..], ip_text, family) catch |err| switch (err) {
            error.ExpectedIPv6ButFoundIPv4 => continue,
            error.ExpectedIPv4ButFoundIPv6 => continue,
        }) {
            0 => continue,
            1 => {
                // first name is canonical name
                const name_text = first_name_text.?;
                if (isValidHostName(name_text)) {
                    mem.copy(u8, canon_buf, name_text);
                    canon_len.* = name_text.len;
                }

                cnt += 1;
                if (cnt == buf.len) break;
            },
            else => unreachable,
        }
    }
    return cnt;
}

pub fn isValidHostName(hostname: []const u8) bool {
    if (hostname.len >= 254) return false;
    if (!std.unicode.utf8ValidateSlice(hostname)) return false;
    for (hostname) |byte| {
        if (byte >= 0x80 or byte == '.' or byte == '-' or std.ascii.isAlNum(byte)) {
            continue;
        }
        return false;
    }
    return true;
}
