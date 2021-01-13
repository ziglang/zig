const std = @import("std");
const mem = std.mem;
const net = std.net;
const os = std.os;

const assert = std.debug.assert;

const Address = std.net.Address;
const Ip4Address = std.net.Ip4Address;
const Ip6Address = std.net.Ip6Address;

const DAS_USABLE = 0x40000000;
const DAS_MATCHINGSCOPE = 0x20000000;
const DAS_MATCHINGLABEL = 0x10000000;
const DAS_PREC_SHIFT = 20;
const DAS_SCOPE_SHIFT = 16;
const DAS_PREFIX_SHIFT = 8;
const DAS_ORDER_SHIFT = 0;

pub const LookupAddr = struct {
    addr: Address,
    sortkey: i32 = 0,
};

pub fn linuxLookupName(
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
        } else |name_err| if ((flags & std.c.AI_NUMERICHOST) != 0) {
            return name_err;
        } else {
            try linuxLookupNameFromHosts(addrs, canon, name, family, port);
            if (addrs.items.len == 0) {
                try linuxLookupNameFromDnsSearch(addrs, canon, name, family, port);
            }
            if (addrs.items.len == 0) {
                // RFC 6761 Section 6.3
                // Name resolution APIs and libraries SHOULD recognize localhost
                // names as special and SHOULD always return the IP loopback address
                // for address queries and negative responses for all other query
                // types.

                // Check for equal to "localhost" or ends in ".localhost"
                if (mem.endsWith(u8, name, "localhost") and (name.len == "localhost".len or name[name.len - "localhost".len] == '.')) {
                    try addrs.append(LookupAddr{ .addr = .{ .in = Ip4Address.parse("127.0.0.1", port) catch unreachable } });
                    try addrs.append(LookupAddr{ .addr = .{ .in6 = Ip6Address.parse("::1", port) catch unreachable } });
                    return;
                }
            }
        }
    } else {
        try canon.resize(0);
        try linuxLookupNameFromNull(addrs, family, flags, port);
    }
    if (addrs.items.len == 0) return error.UnknownHostName;

    // No further processing is needed if there are fewer than 2
    // results or if there are only IPv4 results.
    if (addrs.items.len == 1 or family == os.AF_INET) return;
    const all_ip4 = for (addrs.items) |addr| {
        if (addr.addr.any.family != os.AF_INET) break false;
    } else true;
    if (all_ip4) return;

    // The following implements a subset of RFC 3484/6724 destination
    // address selection by generating a single 31-bit sort key for
    // each address. Rules 3, 4, and 7 are omitted for having
    // excessive runtime and code size cost and dubious benefit.
    // So far the label/precedence table cannot be customized.
    // This implementation is ported from musl libc.
    // A more idiomatic "ziggy" implementation would be welcome.
    for (addrs.items) |*addr, i| {
        var key: i32 = 0;
        var sa6: os.sockaddr_in6 = undefined;
        @memset(@ptrCast([*]u8, &sa6), 0, @sizeOf(os.sockaddr_in6));
        var da6 = os.sockaddr_in6{
            .family = os.AF_INET6,
            .scope_id = addr.addr.in6.sa.scope_id,
            .port = 65535,
            .flowinfo = 0,
            .addr = [1]u8{0} ** 16,
        };
        var sa4: os.sockaddr_in = undefined;
        @memset(@ptrCast([*]u8, &sa4), 0, @sizeOf(os.sockaddr_in));
        var da4 = os.sockaddr_in{
            .family = os.AF_INET,
            .port = 65535,
            .addr = 0,
            .zero = [1]u8{0} ** 8,
        };
        var sa: *align(4) os.sockaddr = undefined;
        var da: *align(4) os.sockaddr = undefined;
        var salen: os.socklen_t = undefined;
        var dalen: os.socklen_t = undefined;
        if (addr.addr.any.family == os.AF_INET6) {
            mem.copy(u8, &da6.addr, &addr.addr.in6.sa.addr);
            da = @ptrCast(*os.sockaddr, &da6);
            dalen = @sizeOf(os.sockaddr_in6);
            sa = @ptrCast(*os.sockaddr, &sa6);
            salen = @sizeOf(os.sockaddr_in6);
        } else {
            mem.copy(u8, &sa6.addr, "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff");
            mem.copy(u8, &da6.addr, "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff");
            mem.writeIntNative(u32, da6.addr[12..], addr.addr.in.sa.addr);
            da4.addr = addr.addr.in.sa.addr;
            da = @ptrCast(*os.sockaddr, &da4);
            dalen = @sizeOf(os.sockaddr_in);
            sa = @ptrCast(*os.sockaddr, &sa4);
            salen = @sizeOf(os.sockaddr_in);
        }
        const dpolicy = policyOf(da6.addr);
        const dscope: i32 = scopeOf(da6.addr);
        const dlabel = dpolicy.label;
        const dprec: i32 = dpolicy.prec;
        const MAXADDRS = 3;
        var prefixlen: i32 = 0;
        const sock_flags = os.SOCK_DGRAM | os.SOCK_CLOEXEC;
        if (os.socket(addr.addr.any.family, sock_flags, os.IPPROTO_UDP)) |fd| syscalls: {
            defer os.closeSocket(fd);
            os.connect(fd, da, dalen) catch break :syscalls;
            key |= DAS_USABLE;
            os.getsockname(fd, sa, &salen) catch break :syscalls;
            if (addr.addr.any.family == os.AF_INET) {
                // TODO sa6.addr[12..16] should return *[4]u8, making this cast unnecessary.
                mem.writeIntNative(u32, @ptrCast(*[4]u8, &sa6.addr[12]), sa4.addr);
            }
            if (dscope == @as(i32, scopeOf(sa6.addr))) key |= DAS_MATCHINGSCOPE;
            if (dlabel == labelOf(sa6.addr)) key |= DAS_MATCHINGLABEL;
            prefixlen = prefixMatch(sa6.addr, da6.addr);
        } else |_| {}
        key |= dprec << DAS_PREC_SHIFT;
        key |= (15 - dscope) << DAS_SCOPE_SHIFT;
        key |= prefixlen << DAS_PREFIX_SHIFT;
        key |= (MAXADDRS - @intCast(i32, i)) << DAS_ORDER_SHIFT;
        addr.sortkey = key;
    }
    std.sort.sort(LookupAddr, addrs.items, {}, addrCmpLessThan);
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
    for (defined_policies) |*policy| {
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
    while (i < 128 and ((s[i / 8] ^ d[i / 8]) & (@as(u8, 128) >> @intCast(u3, i % 8))) == 0) : (i += 1) {}
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
    return a.sortkey < b.sortkey;
}

fn linuxLookupNameFromNull(
    addrs: *std.ArrayList(LookupAddr),
    family: os.sa_family_t,
    flags: u32,
    port: u16,
) !void {
    if ((flags & std.c.AI_PASSIVE) != 0) {
        if (family != os.AF_INET6) {
            (try addrs.addOne()).* = LookupAddr{
                .addr = Address.initIp4([1]u8{0} ** 4, port),
            };
        }
        if (family != os.AF_INET) {
            (try addrs.addOne()).* = LookupAddr{
                .addr = Address.initIp6([1]u8{0} ** 16, port, 0, 0),
            };
        }
    } else {
        if (family != os.AF_INET6) {
            (try addrs.addOne()).* = LookupAddr{
                .addr = Address.initIp4([4]u8{ 127, 0, 0, 1 }, port),
            };
        }
        if (family != os.AF_INET) {
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
    const file = std.fs.openFileAbsoluteZ("/etc/hosts", .{}) catch |err| switch (err) {
        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        => return,
        else => |e| return e,
    };
    defer file.close();

    const stream = std.io.bufferedReader(file.reader()).reader();
    var line_buf: [512]u8 = undefined;
    while (stream.readUntilDelimiterOrEof(&line_buf, '\n') catch |err| switch (err) {
        error.StreamTooLong => blk: {
            // Skip to the delimiter in the stream, to fix parsing
            try stream.skipUntilDelimiterOrEof('\n');
            // Use the truncated line. A truncated comment or hostname will be handled correctly.
            break :blk &line_buf;
        },
        else => |e| return e,
    }) |line| {
        const no_comment_line = mem.split(line, "#").next().?;

        var line_it = mem.tokenize(no_comment_line, " \t");
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

fn isValidHostName(hostname: []const u8) bool {
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
    mem.copy(u8, canon.items, canon_name);
    try canon.append('.');

    var tok_it = mem.tokenize(search, " \t");
    while (tok_it.next()) |tok| {
        canon.shrinkAndFree(canon_name.len + 1);
        try canon.appendSlice(tok);
        try linuxLookupNameFromDns(addrs, canon, canon.items, family, rc, port);
        if (addrs.items.len != 0) return;
    }

    canon.shrinkAndFree(canon_name.len);
    return linuxLookupNameFromDns(addrs, canon, name, family, rc, port);
}

fn res_mkquery(
    op: u4,
    dname: []const u8,
    class: u8,
    ty: u8,
    data: []const u8,
    newrr: ?[*]const u8,
    buf: []u8,
) usize {
    // This implementation is ported from musl libc.
    // A more idiomatic "ziggy" implementation would be welcome.
    var name = dname;
    if (mem.endsWith(u8, name, ".")) name.len -= 1;
    assert(name.len <= 253);
    const n = 17 + name.len + @boolToInt(name.len != 0);

    // Construct query template - ID will be filled later
    var q: [280]u8 = undefined;
    @memset(&q, 0, n);
    q[2] = @as(u8, op) * 8 + 1;
    q[5] = 1;
    mem.copy(u8, q[13..], name);
    var i: usize = 13;
    var j: usize = undefined;
    while (q[i] != 0) : (i = j + 1) {
        j = i;
        while (q[j] != 0 and q[j] != '.') : (j += 1) {}
        // TODO determine the circumstances for this and whether or
        // not this should be an error.
        if (j - i - 1 > 62) unreachable;
        q[i - 1] = @intCast(u8, j - i);
    }
    q[i + 1] = ty;
    q[i + 3] = class;

    // Make a reasonably unpredictable id
    var ts: os.timespec = undefined;
    os.clock_gettime(os.CLOCK_REALTIME, &ts) catch {};
    const UInt = std.meta.Int(.unsigned, std.meta.bitCount(@TypeOf(ts.tv_nsec)));
    const unsec = @bitCast(UInt, ts.tv_nsec);
    const id = @truncate(u32, unsec + unsec / 65536);
    q[0] = @truncate(u8, id / 256);
    q[1] = @truncate(u8, id);

    mem.copy(u8, buf, q[0..n]);
    return n;
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
            const len = res_mkquery(0, name, 1, afrr.rr, &[_]u8{}, null, &qbuf[nq]);
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
fn getResolvConf(allocator: *mem.Allocator, rc: *ResolvConf) !void {
    rc.* = ResolvConf{
        .ns = std.ArrayList(LookupAddr).init(allocator),
        .search = std.ArrayList(u8).init(allocator),
        .ndots = 1,
        .timeout = 5,
        .attempts = 2,
    };
    errdefer rc.deinit();

    const file = std.fs.openFileAbsoluteZ("/etc/resolv.conf", .{}) catch |err| switch (err) {
        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        => return linuxLookupNameFromNumericUnspec(&rc.ns, "127.0.0.1", 53),
        else => |e| return e,
    };
    defer file.close();

    const stream = std.io.bufferedReader(file.reader()).reader();
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
        const no_comment_line = mem.split(line, "#").next().?;
        var line_it = mem.tokenize(no_comment_line, " \t");

        const token = line_it.next() orelse continue;
        if (mem.eql(u8, token, "options")) {
            while (line_it.next()) |sub_tok| {
                var colon_it = mem.split(sub_tok, ":");
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

    var sl: os.socklen_t = @sizeOf(os.sockaddr_in);
    var family: os.sa_family_t = os.AF_INET;

    var ns_list = std.ArrayList(Address).init(rc.ns.allocator);
    defer ns_list.deinit();

    try ns_list.resize(rc.ns.items.len);
    const ns = ns_list.items;

    for (rc.ns.items) |iplit, i| {
        ns[i] = iplit.addr;
        assert(ns[i].getPort() == 53);
        if (iplit.addr.any.family != os.AF_INET) {
            sl = @sizeOf(os.sockaddr_in6);
            family = os.AF_INET6;
        }
    }

    // Get local address and open/bind a socket
    var sa: Address = undefined;
    @memset(@ptrCast([*]u8, &sa), 0, @sizeOf(Address));
    sa.any.family = family;
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
    defer os.closeSocket(fd);
    try os.bind(fd, &sa.any, sl);

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
    var t2: u64 = @bitCast(u64, std.time.milliTimestamp());
    var t0 = t2;
    var t1 = t2 - retry_interval;

    var servfail_retry: usize = undefined;

    outer: while (t2 - t0 < timeout) : (t2 = @bitCast(u64, std.time.milliTimestamp())) {
        if (t2 - t1 >= retry_interval) {
            // Query all configured nameservers in parallel
            var i: usize = 0;
            while (i < queries.len) : (i += 1) {
                if (answers[i].len == 0) {
                    var j: usize = 0;
                    while (j < ns.len) : (j += 1) {
                        if (std.io.is_async) {
                            _ = std.event.Loop.instance.?.sendto(fd, queries[i], os.MSG_NOSIGNAL, &ns[j].any, sl) catch undefined;
                        } else {
                            _ = os.sendto(fd, queries[i], os.MSG_NOSIGNAL, &ns[j].any, sl) catch undefined;
                        }
                    }
                }
            }
            t1 = t2;
            servfail_retry = 2 * queries.len;
        }

        // Wait for a response, or until time to retry
        const clamped_timeout = std.math.min(@as(u31, std.math.maxInt(u31)), t1 + retry_interval - t2);
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
                        _ = std.event.Loop.instance.?.sendto(fd, queries[i], os.MSG_NOSIGNAL, &ns[j].any, sl) catch undefined;
                    } else {
                        _ = os.sendto(fd, queries[i], os.MSG_NOSIGNAL, &ns[j].any, sl) catch undefined;
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
                mem.copy(u8, answer_bufs[i], answer_bufs[next][0..rlen]);
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
        while (@ptrToInt(p) - @ptrToInt(r.ptr) < r.len and p[0] -% 1 < 127) p += 1;
        if (p[0] > 193 or (p[0] == 193 and p[1] > 254) or @ptrToInt(p) > @ptrToInt(r.ptr) + r.len - 6)
            return error.InvalidDnsPacket;
        p += @as(usize, 5) + @boolToInt(p[0] != 0);
    }
    while (ancount != 0) {
        ancount -= 1;
        while (@ptrToInt(p) - @ptrToInt(r.ptr) < r.len and p[0] -% 1 < 127) p += 1;
        if (p[0] > 193 or (p[0] == 193 and p[1] > 254) or @ptrToInt(p) > @ptrToInt(r.ptr) + r.len - 6)
            return error.InvalidDnsPacket;
        p += @as(usize, 1) + @boolToInt(p[0] != 0);
        const len = p[8] * @as(usize, 256) + p[9];
        if (@ptrToInt(p) + len > @ptrToInt(r.ptr) + r.len) return error.InvalidDnsPacket;
        try callback(ctx, p[1], p[10 .. 10 + len], r);
        p += 10 + len;
    }
}

fn dnsParseCallback(ctx: dpc_ctx, rr: u8, data: []const u8, packet: []const u8) !void {
    switch (rr) {
        os.RR_A => {
            if (data.len != 4) return error.InvalidDnsARecord;
            const new_addr = try ctx.addrs.addOne();
            new_addr.* = LookupAddr{
                .addr = Address.initIp4(data[0..4].*, ctx.port),
            };
        },
        os.RR_AAAA => {
            if (data.len != 16) return error.InvalidDnsAAAARecord;
            const new_addr = try ctx.addrs.addOne();
            new_addr.* = LookupAddr{
                .addr = Address.initIp6(data[0..16].*, ctx.port, 0, 0),
            };
        },
        os.RR_CNAME => {
            var tmp: [256]u8 = undefined;
            // Returns len of compressed name. strlen to get canon name.
            _ = try os.dn_expand(packet, data, &tmp);
            const canon_name = mem.spanZ(std.meta.assumeSentinel(&tmp, 0));
            if (isValidHostName(canon_name)) {
                ctx.canon.items.len = 0;
                try ctx.canon.appendSlice(canon_name);
            }
        },
        else => return,
    }
}
