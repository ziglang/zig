const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const net = @This();
const mem = std.mem;
const os = std.os;
const fs = std.fs;

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
        switch (builtin.os) {
            .macosx, .ios, .watchos, .tvos,
            .freebsd, .netbsd => return Address{
                .os_addr = os.sockaddr{
                    .in = os.sockaddr_in{
                        .len = @sizeOf(os.sockaddr_in),
                        .family = os.AF_INET,
                        .port = mem.nativeToBig(u16, _port),
                        .addr = ip4,
                        .zero = [_]u8{0} ** 8,
                    },
                },
            },
            .linux => return Address{
                .os_addr = os.sockaddr{
                    .in = os.sockaddr_in{
                        .family = os.AF_INET,
                        .port = mem.nativeToBig(u16, _port),
                        .addr = ip4,
                        .zero = [_]u8{0} ** 8,
                    },
                },
            },
            else => @compileError("Address.initIp4 not implemented for this platform"),
        }
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

fn testIp4s(ips: []const []const u8) void {
    var buffer : [18]u8 = undefined;
    for (ips) |ip| {
        var addr = Address.initIp4(parseIp4(ip) catch unreachable, 0);
        var newIp = std.fmt.bufPrint(buffer[0..], "{}", addr) catch unreachable;
        std.testing.expect(std.mem.eql(u8, ip, newIp[0..newIp.len - 2]));
    }
}

test "std.net.ip4s" {
    testIp4s(([_][]const u8 {
        "0.0.0.0" ,
        "255.255.255.255" ,
        "1.2.3.4",
        "123.255.0.91",
    })[0..]);
}
pub fn connectUnixSocket(path: []const u8) !fs.File {
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

    return fs.File.openHandle(sockfd);
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
        const c = std.c;
        const name_c = try std.cstr.addNullByte(allocator, name);
        defer allocator.free(name_c);

        const port_c = try std.fmt.allocPrint(allocator, "{}\x00", port);
        defer allocator.free(port_c);

        const hints = os.addrinfo{
            .flags = c.AI_NUMERICSERV,
            .family = os.AF_INET, // TODO os.AF_UNSPEC,
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
            c.EAI_ADDRFAMILY => return error.HostLacksNetworkAddresses,
            c.EAI_AGAIN => return error.TemporaryNameServerFailure,
            c.EAI_BADFLAGS => unreachable, // Invalid hints
            c.EAI_FAIL => return error.NameServerFailure,
            c.EAI_FAMILY => return error.AddressFamilyNotSupported,
            c.EAI_MEMORY => return error.OutOfMemory,
            c.EAI_NODATA => return error.HostLacksNetworkAddresses,
            c.EAI_NONAME => return error.UnknownName,
            c.EAI_SERVICE => return error.ServiceUnavailable,
            c.EAI_SOCKTYPE => unreachable, // Invalid socket type requested in hints
            c.EAI_SYSTEM => switch (os.errno(-1)) {
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
        const flags = std.c.AI_NUMERICSERV;
        const family = os.AF_INET; //TODO os.AF_UNSPEC;
        // The limit of 48 results is a non-sharp bound on the number of addresses
        // that can fit in one 512-byte DNS packet full of v4 results and a second
        // packet full of v6 results. Due to headers, the actual limit is lower.
        var addrs = std.ArrayList(LookupAddr).init(allocator);
        defer addrs.deinit();

        var canon = std.Buffer.initNull(allocator);
        defer canon.deinit();

        try linuxLookupName(&addrs, &canon, name, family, flags);

        result.addrs = try arena.alloc(Address, addrs.len);
        if (!canon.isNull()) {
            result.canon_name = canon.toOwnedSlice();
        }

        for (addrs.toSliceConst()) |addr, i| {
            const os_addr = if (addr.family == os.AF_INET6)
                os.sockaddr{
                    .in6 = os.sockaddr_in6{
                        .family = addr.family,
                        .port = mem.nativeToBig(u16, port),
                        .flowinfo = 0,
                        .addr = addr.addr,
                        .scope_id = addr.scope_id,
                    },
                }
            else
                os.sockaddr{
                    .in = os.sockaddr_in{
                        .family = addr.family,
                        .port = mem.nativeToBig(u16, port),
                        .addr = @ptrCast(*align(1) const u32, &addr.addr).*,
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
    addrs: *std.ArrayList(LookupAddr),
    canon: *std.Buffer,
    opt_name: ?[]const u8,
    family: i32,
    flags: u32,
) !void {
    if (opt_name) |name| {
        // reject empty name and check len so it fits into temp bufs
        try canon.replaceContents(name);
        try linuxLookupNameFromNumeric(addrs, name, family);
        if (addrs.len == 0 and (flags & std.c.AI_NUMERICHOST) == 0) {
            try linuxLookupNameFromHosts(addrs, canon, name, family);
            if (addrs.len == 0) {
                try linuxLookupNameFromDnsSearch(addrs, canon, name, family);
            }
        }
    } else {
        try canon.resize(0);
        try linuxLookupNameFromNull(addrs, family, flags);
    }
    if (addrs.len == 0) return error.UnknownName;

    // No further processing is needed if there are fewer than 2
    // results or if there are only IPv4 results.
    if (addrs.len == 1 or family == os.AF_INET) return;

    @panic("port the RFC 3484/6724 destination address selection from musl libc");
}

fn linuxLookupNameFromNumericUnspec(addrs: *std.ArrayList(LookupAddr), name: []const u8) !void {
    return linuxLookupNameFromNumeric(addrs, name, os.AF_UNSPEC) catch |err| switch (err) {
        error.ExpectedIPv6ButFoundIPv4 => unreachable,
        error.ExpectedIPv4ButFoundIPv6 => unreachable,
        else => |e| return e,
    };
}

fn linuxLookupNameFromNumeric(addrs: *std.ArrayList(LookupAddr), name: []const u8, family: i32) !void {
    if (parseIp4(name)) |ip4| {
        if (family == os.AF_INET6) return error.ExpectedIPv6ButFoundIPv4;
        const item = try addrs.addOne();
        // TODO [0..4] should return *[4]u8, making this pointer cast unnecessary
        mem.writeIntNative(u32, @ptrCast(*[4]u8, &item.addr), ip4);
        item.family = os.AF_INET;
        item.scope_id = 0;
        return;
    } else |err| switch (err) {
        error.Overflow,
        error.InvalidEnd,
        error.InvalidCharacter,
        error.Incomplete,
        => {},
    }

    if (parseIp6(name)) |ip6| {
        if (family == os.AF_INET) return error.ExpectedIPv4ButFoundIPv6;
        const item = try addrs.addOne();
        @memcpy(&item.addr, &ip6.addr, 16);
        item.family = os.AF_INET6;
        item.scope_id = ip6.scope_id;
        return;
    } else |err| switch (err) {
        error.Overflow,
        error.InvalidEnd,
        error.InvalidCharacter,
        error.Incomplete,
        => {},
    }
}

fn linuxLookupNameFromNull(addrs: *std.ArrayList(LookupAddr), family: i32, flags: u32) !void {
    if ((flags & std.c.AI_PASSIVE) != 0) {
        if (family != os.AF_INET6) {
            (try addrs.addOne()).* = LookupAddr{
                .family = os.AF_INET,
                .addr = [1]u8{0} ** 16,
            };
        }
        if (family != os.AF_INET) {
            (try addrs.addOne()).* = LookupAddr{
                .family = os.AF_INET6,
                .addr = [1]u8{0} ** 16,
            };
        }
    } else {
        if (family != os.AF_INET6) {
            (try addrs.addOne()).* = LookupAddr{
                .family = os.AF_INET,
                .addr = [4]u8{ 127, 0, 0, 1 } ++ ([1]u8{0} ** 12),
            };
        }
        if (family != os.AF_INET) {
            (try addrs.addOne()).* = LookupAddr{
                .family = os.AF_INET6,
                .addr = ([1]u8{0} ** 15) ++ [1]u8{1},
            };
        }
    }
}

fn linuxLookupNameFromHosts(
    addrs: *std.ArrayList(LookupAddr),
    canon: *std.Buffer,
    name: []const u8,
    family: i32,
) !void {
    const file = fs.File.openReadC(c"/etc/hosts") catch |err| switch (err) {
        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        => return,
        else => |e| return e,
    };
    defer file.close();

    const stream = &std.io.BufferedInStream(fs.File.ReadError).init(&file.inStream().stream).stream;
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

        const prev_len = addrs.len;
        linuxLookupNameFromNumeric(addrs, ip_text, family) catch |err| switch (err) {
            error.ExpectedIPv6ButFoundIPv4 => continue,
            error.ExpectedIPv4ButFoundIPv6 => continue,
            error.OutOfMemory => |e| return e,
        };
        if (addrs.len > prev_len) {
            // first name is canonical name
            const name_text = first_name_text.?;
            if (isValidHostName(name_text)) {
                try canon.replaceContents(name_text);
            }
        }
    }
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

fn linuxLookupNameFromDnsSearch(
    addrs: *std.ArrayList(LookupAddr),
    canon: *std.Buffer,
    name: []const u8,
    family: i32,
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

    const search = if (rc.search.isNull() or dots >= rc.ndots or mem.endsWith(u8, name, "."))
        [_]u8{}
    else
        rc.search.toSliceConst();

    var canon_name = name;

    // Strip final dot for canon, fail if multiple trailing dots.
    if (mem.endsWith(u8, canon_name, ".")) canon_name.len -= 1;
    if (mem.endsWith(u8, canon_name, ".")) return error.UnknownName;

    // Name with search domain appended is setup in canon[]. This both
    // provides the desired default canonical name (if the requested
    // name is not a CNAME record) and serves as a buffer for passing
    // the full requested name to name_from_dns.
    try canon.resize(canon_name.len);
    mem.copy(u8, canon.toSlice(), canon_name);
    try canon.appendByte('.');

    var tok_it = mem.tokenize(search, " \t");
    while (tok_it.next()) |tok| {
        canon.shrink(canon_name.len + 1);
        try canon.append(tok);
        try linuxLookupNameFromDns(addrs, canon, canon.toSliceConst(), family, rc);
        if (addrs.len != 0) return;
    }

    canon.shrink(canon_name.len);
    return linuxLookupNameFromDns(addrs, canon, name, family, rc);
}

const dpc_ctx = struct {
    addrs: *std.ArrayList(LookupAddr),
    canon: *std.Buffer,
};

fn linuxLookupNameFromDns(
    addrs: *std.ArrayList(LookupAddr),
    canon: *std.Buffer,
    name: []const u8,
    family: i32,
    rc: ResolvConf,
) !void {
    var ctx = dpc_ctx{
        .addrs = addrs,
        .canon = canon,
    };
    const AfRr = struct {
        af: i32,
        rr: u8,
    };
    const afrrs = [_]AfRr{
        AfRr{ .af = os.AF_INET6, .rr = os.RR_A },
        AfRr{ .af = os.AF_INET, .rr = os.RR_AAAA },
    };
    var qbuf: [2][280]u8 = undefined;
    var abuf: [2][512]u8 = undefined;
    var qp: [2][]const u8 = undefined;
    const apbuf = [2][]u8{ &abuf[0], &abuf[1] };
    var nq: usize = 0;

    for (afrrs) |afrr| {
        if (family != afrr.af) {
            const len = os.res_mkquery(0, name, 1, afrr.rr, [_]u8{}, null, &qbuf[nq]);
            qp[nq] = qbuf[nq][0..len];
            nq += 1;
        }
    }

    var ap = [2][]u8{ apbuf[0][0..0], apbuf[1][0..0] };
    try resMSendRc(qp[0..nq], ap[0..nq], apbuf[0..nq], rc);

    var i: usize = 0;
    while (i < nq) : (i += 1) {
        dnsParse(ap[i], ctx, dnsParseCallback) catch {};
    }

    if (addrs.len != 0) return;
    if (ap[0].len < 4 or (ap[0][3] & 15) == 2) return error.TemporaryNameServerFailure;
    if ((ap[0][3] & 15) == 0) return error.UnknownName;
    if ((ap[0][3] & 15) == 3) return;
    return error.NameServerFailure;
}

const ResolvConf = struct {
    attempts: u32,
    ndots: u32,
    timeout: u32,
    search: std.Buffer,
    ns: std.ArrayList(LookupAddr),

    fn deinit(rc: *ResolvConf) void {
        rc.ns.deinit();
        rc.search.deinit();
        rc.* = undefined;
    }
};

/// Ignores lines longer than 512 bytes.
/// TODO: https://github.com/ziglang/zig/issues/2765 and https://github.com/ziglang/zig/issues/2761
fn getResolvConf(allocator: *mem.Allocator, rc: *ResolvConf) !void {
    rc.* = ResolvConf{
        .ns = std.ArrayList(LookupAddr).init(allocator),
        .search = std.Buffer.initNull(allocator),
        .ndots = 1,
        .timeout = 5,
        .attempts = 2,
    };
    errdefer rc.deinit();

    const file = fs.File.openReadC(c"/etc/resolv.conf") catch |err| switch (err) {
        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        => return linuxLookupNameFromNumericUnspec(&rc.ns, "127.0.0.1"),
        else => |e| return e,
    };
    defer file.close();

    var cnt: usize = 0;
    const stream = &std.io.BufferedInStream(fs.File.ReadError).init(&file.inStream().stream).stream;
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
        const no_comment_line = mem.separate(line, "#").next().?;
        var line_it = mem.tokenize(no_comment_line, " \t");

        const token = line_it.next() orelse continue;
        if (mem.eql(u8, token, "options")) {
            while (line_it.next()) |sub_tok| {
                var colon_it = mem.separate(sub_tok, ":");
                const name = colon_it.next().?;
                const value_txt = colon_it.next() orelse continue;
                const value = std.fmt.parseInt(u8, value_txt, 10) catch |err| switch (err) {
                    error.Overflow => 255,
                    error.InvalidCharacter => continue,
                };
                if (mem.eql(u8, name, "ndots")) {
                    rc.ndots = std.math.min(value, 15);
                } else if (mem.eql(u8, name, "attempts")) {
                    rc.attempts = std.math.min(value, 10);
                } else if (mem.eql(u8, name, "timeout")) {
                    rc.timeout = std.math.min(value, 60);
                }
            }
        } else if (mem.eql(u8, token, "nameserver")) {
            const ip_txt = line_it.next() orelse continue;
            try linuxLookupNameFromNumericUnspec(&rc.ns, ip_txt);
        } else if (mem.eql(u8, token, "domain") or mem.eql(u8, token, "search")) {
            try rc.search.replaceContents(line_it.rest());
        }
    }

    if (rc.ns.len == 0) {
        return linuxLookupNameFromNumericUnspec(&rc.ns, "127.0.0.1");
    }
}

fn eqlSockAddr(a: *const os.sockaddr, b: *const os.sockaddr, len: usize) bool {
    const a_bytes = @ptrCast([*]const u8, a)[0..len];
    const b_bytes = @ptrCast([*]const u8, b)[0..len];
    return mem.eql(u8, a_bytes, b_bytes);
}

fn resMSendRc(
    queries: []const []const u8,
    answers: [][]u8,
    answer_bufs: []const []u8,
    rc: ResolvConf,
) !void {
    const timeout = 1000 * rc.timeout;
    const attempts = rc.attempts;

    var sl: os.socklen_t = @sizeOf(os.sockaddr_in);
    var family: os.sa_family_t = os.AF_INET;

    var ns_list = std.ArrayList(os.sockaddr).init(rc.ns.allocator);
    defer ns_list.deinit();

    try ns_list.resize(rc.ns.len);
    const ns = ns_list.toSlice();

    for (rc.ns.toSliceConst()) |iplit, i| {
        if (iplit.family == os.AF_INET) {
            ns[i] = os.sockaddr{
                .in = os.sockaddr_in{
                    .family = os.AF_INET,
                    .port = mem.nativeToBig(u16, 53),
                    .addr = mem.readIntNative(u32, @ptrCast(*const [4]u8, &iplit.addr)),
                    .zero = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
                },
            };
        } else {
            ns[i] = os.sockaddr{
                .in6 = os.sockaddr_in6{
                    .family = os.AF_INET6,
                    .port = mem.nativeToBig(u16, 53),
                    .flowinfo = 0,
                    .addr = iplit.addr,
                    .scope_id = iplit.scope_id,
                },
            };
            sl = @sizeOf(os.sockaddr_in6);
            family = os.AF_INET6;
        }
    }

    // Get local address and open/bind a socket
    var sa: os.sockaddr = undefined;
    @memset(@ptrCast([*]u8, &sa), 0, @sizeOf(os.sockaddr));
    sa.in.family = family;
    const flags = os.SOCK_DGRAM | os.SOCK_CLOEXEC | os.SOCK_NONBLOCK;
    const fd = os.socket(family, flags, 0) catch |err| switch (err) {
        error.AddressFamilyNotSupported => blk: {
            // Handle case where system lacks IPv6 support
            if (family == os.AF_INET6) {
                family = os.AF_INET;
                break :blk try os.socket(os.AF_INET, flags, 0);
            }
            return err;
        },
        else => |e| return e,
    };
    defer os.close(fd);
    try os.bind(fd, &sa, sl);

    // Past this point, there are no errors. Each individual query will
    // yield either no reply (indicated by zero length) or an answer
    // packet which is up to the caller to interpret.

    // Convert any IPv4 addresses in a mixed environment to v4-mapped
    // TODO
    //if (family == AF_INET6) {
    //    setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, &(int){0}, sizeof 0);
    //    for (i=0; i<nns; i++) {
    //        if (ns[i].sin.sin_family != AF_INET) continue;
    //        memcpy(ns[i].sin6.sin6_addr.s6_addr+12,
    //            &ns[i].sin.sin_addr, 4);
    //        memcpy(ns[i].sin6.sin6_addr.s6_addr,
    //            "\0\0\0\0\0\0\0\0\0\0\xff\xff", 12);
    //        ns[i].sin6.sin6_family = AF_INET6;
    //        ns[i].sin6.sin6_flowinfo = 0;
    //        ns[i].sin6.sin6_scope_id = 0;
    //    }
    //}

    var pfd = [1]os.pollfd{os.pollfd{
        .fd = fd,
        .events = os.POLLIN,
        .revents = undefined,
    }};
    const retry_interval = timeout / attempts;
    var next: u32 = 0;
    var t2: usize = std.time.milliTimestamp();
    var t0 = t2;
    var t1 = t2 - retry_interval;

    var servfail_retry: usize = undefined;

    outer: while (t2 - t0 < timeout) : (t2 = std.time.milliTimestamp()) {
        if (t2 - t1 >= retry_interval) {
            // Query all configured nameservers in parallel
            var i: usize = 0;
            while (i < queries.len) : (i += 1) {
                if (answers[i].len == 0) {
                    var j: usize = 0;
                    while (j < ns.len) : (j += 1) {
                        _ = os.sendto(fd, queries[i], os.MSG_NOSIGNAL, &ns[j], sl) catch undefined;
                    }
                }
            }
            t1 = t2;
            servfail_retry = 2 * queries.len;
        }

        // Wait for a response, or until time to retry
        const clamped_timeout = std.math.min(u31(std.math.maxInt(u31)), t1 + retry_interval - t2);
        const nevents = os.poll(&pfd, clamped_timeout) catch 0;
        if (nevents == 0) continue;

        while (true) {
            var sl_copy = sl;
            const rlen = os.recvfrom(fd, answer_bufs[next], 0, &sa, &sl_copy) catch break;

            // Ignore non-identifiable packets
            if (rlen < 4) continue;

            // Ignore replies from addresses we didn't send to
            var j: usize = 0;
            while (j < ns.len and !eqlSockAddr(&ns[j], &sa, sl)) : (j += 1) {}
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
                    _ = os.sendto(fd, queries[i], os.MSG_NOSIGNAL, &ns[j], sl) catch undefined;
                },
                else => continue,
            }

            // Store answer in the right slot, or update next
            // available temp slot if it's already in place.
            answers[i].len = rlen;
            if (i == next) {
                while (next < queries.len and answers[next].len != 0) : (next += 1) {}
            } else {
                mem.copy(u8, answer_bufs[i], answer_bufs[next][0..rlen]);
            }

            if (next == queries.len) break :outer;
        }
    }
}

fn dnsParse(
    r: []const u8,
    ctx: var,
    comptime callback: var,
) !void {
    if (r.len < 12) return error.InvalidDnsPacket;
    if ((r[3] & 15) != 0) return;
    var p = r.ptr + 12;
    var qdcount = r[4] * usize(256) + r[5];
    var ancount = r[6] * usize(256) + r[7];
    if (qdcount + ancount > 64) return error.InvalidDnsPacket;
    while (qdcount != 0) {
        qdcount -= 1;
        while (@ptrToInt(p) - @ptrToInt(r.ptr) < r.len and p[0] -% 1 < 127) p += 1;
        if (p[0] > 193 or (p[0] == 193 and p[1] > 254) or @ptrToInt(p) > @ptrToInt(r.ptr) + r.len - 6)
            return error.InvalidDnsPacket;
        p += usize(5) + @boolToInt(p[0] != 0);
    }
    while (ancount != 0) {
        ancount -= 1;
        while (@ptrToInt(p) - @ptrToInt(r.ptr) < r.len and p[0] -% 1 < 127) p += 1;
        if (p[0] > 193 or (p[0] == 193 and p[1] > 254) or @ptrToInt(p) > @ptrToInt(r.ptr) + r.len - 6)
            return error.InvalidDnsPacket;
        p += usize(1) + @boolToInt(p[0] != 0);
        const len = p[8] * usize(256) + p[9];
        if (@ptrToInt(p) + len > @ptrToInt(r.ptr) + r.len) return error.InvalidDnsPacket;
        try callback(ctx, p[1], p[10 .. 10 + len], r);
        p += 10 + len;
    }
}

fn dnsParseCallback(ctx: dpc_ctx, rr: u8, data: []const u8, packet: []const u8) !void {
    var tmp: [256]u8 = undefined;
    switch (rr) {
        os.RR_A => {
            if (data.len != 4) return error.InvalidDnsARecord;
            const new_addr = try ctx.addrs.addOne();
            new_addr.* = LookupAddr{
                .family = os.AF_INET,
                .addr = undefined,
            };
            mem.copy(u8, &new_addr.addr, data);
        },
        os.RR_AAAA => {
            if (data.len != 16) return error.InvalidDnsAAAARecord;
            const new_addr = try ctx.addrs.addOne();
            new_addr.* = LookupAddr{
                .family = os.AF_INET6,
                .addr = undefined,
            };
            mem.copy(u8, &new_addr.addr, data);
        },
        os.RR_CNAME => {
            @panic("TODO dn_expand");
            //if (__dn_expand(packet, (const unsigned char *)packet + 512,
            //    data, tmp, sizeof tmp) > 0 && is_valid_hostname(tmp))
            //    strcpy(ctx->canon, tmp);
        },
        else => return,
    }
}
