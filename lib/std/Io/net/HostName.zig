//! An already-validated host name. A valid host name:
//! * Has length less than or equal to `max_len`.
//! * Is valid UTF-8.
//! * Lacks ASCII characters other than alphanumeric, '-', and '.'.
const HostName = @This();

const builtin = @import("builtin");
const native_os = builtin.os.tag;

const std = @import("../../std.zig");
const Io = std.Io;
const IpAddress = Io.net.IpAddress;
const Ip6Address = Io.net.Ip6Address;
const assert = std.debug.assert;
const Stream = Io.net.Stream;

/// Externally managed memory. Already checked to be valid.
bytes: []const u8,

pub const max_len = 255;

pub const InitError = error{
    NameTooLong,
    InvalidHostName,
};

pub fn init(bytes: []const u8) InitError!HostName {
    if (bytes.len > max_len) return error.NameTooLong;
    if (!std.unicode.utf8ValidateSlice(bytes)) return error.InvalidHostName;
    for (bytes) |byte| {
        if (!std.ascii.isAscii(byte) or byte == '.' or byte == '-' or std.ascii.isAlphanumeric(byte)) {
            continue;
        }
        return error.InvalidHostName;
    }
    return .{ .bytes = bytes };
}

/// TODO add a retry field here
pub const LookupOptions = struct {
    port: u16,
    /// Must have at least length 2.
    addresses_buffer: []IpAddress,
    canonical_name_buffer: *[max_len]u8,
    /// `null` means either.
    family: ?IpAddress.Family = null,
};

pub const LookupError = Io.Cancelable || Io.File.OpenError || Io.File.Reader.Error || error{
    UnknownHostName,
    ResolvConfParseFailed,
    // TODO remove from error set; retry a few times then report a different error
    TemporaryNameServerFailure,
    InvalidDnsARecord,
    InvalidDnsAAAARecord,
    NameServerFailure,
};

pub const LookupResult = struct {
    /// How many `LookupOptions.addresses_buffer` elements are populated.
    addresses_len: usize,
    canonical_name: HostName,

    pub const empty: LookupResult = .{
        .addresses_len = 0,
        .canonical_name = undefined,
    };
};

pub fn lookup(host_name: HostName, io: Io, options: LookupOptions) LookupError!LookupResult {
    const name = host_name.bytes;
    assert(name.len <= max_len);
    assert(options.addresses_buffer.len >= 2);

    if (native_os == .windows) @compileError("TODO");
    if (builtin.link_libc) @compileError("TODO");
    if (native_os == .linux) {
        if (options.family != .ip6) {
            if (IpAddress.parseIp4(name, options.port)) |addr| {
                options.addresses_buffer[0] = addr;
                return .{ .addresses_len = 1, .canonical_name = copyCanon(options.canonical_name_buffer, name) };
            } else |_| {}
        }
        if (options.family != .ip4) {
            if (IpAddress.parseIp6(name, options.port)) |addr| {
                options.addresses_buffer[0] = addr;
                return .{ .addresses_len = 1, .canonical_name = copyCanon(options.canonical_name_buffer, name) };
            } else |_| {}
        }
        {
            const result = try lookupHosts(host_name, io, options);
            if (result.addresses_len > 0) return sortLookupResults(options, result);
        }
        {
            // RFC 6761 Section 6.3.3
            // Name resolution APIs and libraries SHOULD recognize
            // localhost names as special and SHOULD always return the IP
            // loopback address for address queries and negative responses
            // for all other query types.

            // Check for equal to "localhost(.)" or ends in ".localhost(.)"
            const localhost = if (name[name.len - 1] == '.') "localhost." else "localhost";
            if (std.mem.endsWith(u8, name, localhost) and
                (name.len == localhost.len or name[name.len - localhost.len] == '.'))
            {
                var i: usize = 0;
                if (options.family != .ip6) {
                    options.addresses_buffer[i] = .{ .ip4 = .localhost(options.port) };
                    i += 1;
                }
                if (options.family != .ip4) {
                    options.addresses_buffer[i] = .{ .ip6 = .localhost(options.port) };
                    i += 1;
                }
                const canon_name = "localhost";
                const canon_name_dest = options.canonical_name_buffer[0..canon_name.len];
                canon_name_dest.* = canon_name.*;
                return sortLookupResults(options, .{
                    .addresses_len = i,
                    .canonical_name = .{ .bytes = canon_name_dest },
                });
            }
        }
        {
            const result = try lookupDnsSearch(host_name, io, options);
            if (result.addresses_len > 0) return sortLookupResults(options, result);
        }
        return error.UnknownHostName;
    }
    @compileError("unimplemented");
}

fn sortLookupResults(options: LookupOptions, result: LookupResult) !LookupResult {
    const addresses = options.addresses_buffer[0..result.addresses_len];
    // No further processing is needed if there are fewer than 2 results or
    // if there are only IPv4 results.
    if (addresses.len < 2) return result;
    const all_ip4 = for (addresses) |a| switch (a) {
        .ip4 => continue,
        .ip6 => break false,
    } else true;
    if (all_ip4) return result;

    // RFC 3484/6724 describes how destination address selection is
    // supposed to work. However, to implement it requires making a bunch
    // of networking syscalls, which is unnecessarily high latency,
    // especially if implemented serially. Furthermore, rules 3, 4, and 7
    // have excessive runtime and code size cost and dubious benefit.
    //
    // Therefore, this logic sorts only using values available without
    // doing any syscalls, relying on the calling code to have a
    // meta-strategy such as attempting connection to multiple results at
    // once and keeping the fastest response while canceling the others.

    const S = struct {
        pub fn lessThan(s: @This(), lhs: IpAddress, rhs: IpAddress) bool {
            return sortKey(s, lhs) < sortKey(s, rhs);
        }

        fn sortKey(s: @This(), a: IpAddress) i32 {
            _ = s;
            var da6: Ip6Address = .{
                .port = 65535,
                .bytes = undefined,
            };
            switch (a) {
                .ip6 => |ip6| {
                    da6.bytes = ip6.bytes;
                    da6.scope_id = ip6.scope_id;
                },
                .ip4 => |ip4| {
                    da6.bytes[0..12].* = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff".*;
                    da6.bytes[12..].* = ip4.bytes;
                },
            }
            const da6_scope: i32 = da6.scope();
            const da6_prec: i32 = da6.policy().prec;
            var key: i32 = 0;
            key |= da6_prec << 20;
            key |= (15 - da6_scope) << 16;
            return key;
        }
    };
    std.mem.sort(IpAddress, addresses, @as(S, .{}), S.lessThan);
    return result;
}

fn lookupDnsSearch(host_name: HostName, io: Io, options: LookupOptions) !LookupResult {
    const rc = ResolvConf.init(io) catch return error.ResolvConfParseFailed;

    // Count dots, suppress search when >=ndots or name ends in
    // a dot, which is an explicit request for global scope.
    const dots = std.mem.countScalar(u8, host_name.bytes, '.');
    const search_len = if (dots >= rc.ndots or std.mem.endsWith(u8, host_name.bytes, ".")) 0 else rc.search_len;
    const search = rc.search_buffer[0..search_len];

    var canon_name = host_name.bytes;

    // Strip final dot for canon, fail if multiple trailing dots.
    if (std.mem.endsWith(u8, canon_name, ".")) canon_name.len -= 1;
    if (std.mem.endsWith(u8, canon_name, ".")) return error.UnknownHostName;

    // Name with search domain appended is set up in `canon_name`. This
    // both provides the desired default canonical name (if the requested
    // name is not a CNAME record) and serves as a buffer for passing the
    // full requested name to `lookupDns`.
    @memcpy(options.canonical_name_buffer[0..canon_name.len], canon_name);
    options.canonical_name_buffer[canon_name.len] = '.';
    var it = std.mem.tokenizeAny(u8, search, " \t");
    while (it.next()) |token| {
        @memcpy(options.canonical_name_buffer[canon_name.len + 1 ..][0..token.len], token);
        const lookup_canon_name = options.canonical_name_buffer[0 .. canon_name.len + 1 + token.len];
        const result = try lookupDns(io, lookup_canon_name, &rc, options);
        if (result.addresses_len > 0) return sortLookupResults(options, result);
    }

    const lookup_canon_name = options.canonical_name_buffer[0..canon_name.len];
    return lookupDns(io, lookup_canon_name, &rc, options);
}

fn lookupDns(io: Io, lookup_canon_name: []const u8, rc: *const ResolvConf, options: LookupOptions) !LookupResult {
    const family_records: [2]struct { af: IpAddress.Family, rr: u8 } = .{
        .{ .af = .ip6, .rr = std.posix.RR.A },
        .{ .af = .ip4, .rr = std.posix.RR.AAAA },
    };
    var query_buffers: [2][280]u8 = undefined;
    var queries_buffer: [2][]const u8 = undefined;
    var answer_buffers: [2][512]u8 = undefined;
    var answers_buffer: [2][]u8 = .{ &answer_buffers[0], &answer_buffers[1] };
    var nq: usize = 0;

    for (family_records) |fr| {
        if (options.family != fr.af) {
            const len = writeResolutionQuery(&query_buffers[nq], 0, lookup_canon_name, 1, fr.rr);
            queries_buffer[nq] = query_buffers[nq][0..len];
            nq += 1;
        }
    }

    const queries = queries_buffer[0..nq];
    const replies = answers_buffer[0..nq];
    try rc.sendMessage(io, queries, replies);

    for (replies) |reply| {
        if (reply.len < 4 or (reply[3] & 15) == 2) return error.TemporaryNameServerFailure;
        if ((reply[3] & 15) == 3) return .empty;
        if ((reply[3] & 15) != 0) return error.UnknownHostName;
    }

    var addresses_len: usize = 0;
    var canonical_name: ?HostName = null;

    for (replies) |reply| {
        var it = DnsResponse.init(reply) catch {
            // TODO accept a diagnostics struct and append warnings
            continue;
        };
        while (it.next() catch {
            // TODO accept a diagnostics struct and append warnings
            continue;
        }) |answer| switch (answer.rr) {
            std.posix.RR.A => {
                if (answer.data.len != 4) return error.InvalidDnsARecord;
                options.addresses_buffer[addresses_len] = .{ .ip4 = .{
                    .bytes = answer.data[0..4].*,
                    .port = options.port,
                } };
                addresses_len += 1;
            },
            std.posix.RR.AAAA => {
                if (answer.data.len != 16) return error.InvalidDnsAAAARecord;
                options.addresses_buffer[addresses_len] = .{ .ip6 = .{
                    .bytes = answer.data[0..16].*,
                    .port = options.port,
                } };
                addresses_len += 1;
            },
            std.posix.RR.CNAME => {
                _ = &canonical_name;
                @panic("TODO");
                //var tmp: [256]u8 = undefined;
                //// Returns len of compressed name. strlen to get canon name.
                //_ = try posix.dn_expand(packet, answer.data, &tmp);
                //const canon_name = mem.sliceTo(&tmp, 0);
                //if (isValidHostName(canon_name)) {
                //    ctx.canon.items.len = 0;
                //    try ctx.canon.appendSlice(gpa, canon_name);
                //}
            },
            else => continue,
        };
    }

    if (addresses_len != 0) return .{
        .addresses_len = addresses_len,
        .canonical_name = canonical_name orelse .{ .bytes = lookup_canon_name },
    };

    return error.NameServerFailure;
}

fn lookupHosts(host_name: HostName, io: Io, options: LookupOptions) !LookupResult {
    const file = Io.File.openAbsolute(io, "/etc/hosts", .{}) catch |err| switch (err) {
        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        => return .empty,

        else => |e| return e,
    };
    defer file.close(io);

    var line_buf: [512]u8 = undefined;
    var file_reader = file.reader(io, &line_buf);
    return lookupHostsReader(host_name, options, &file_reader.interface) catch |err| switch (err) {
        error.ReadFailed => return file_reader.err.?,
    };
}

fn lookupHostsReader(host_name: HostName, options: LookupOptions, reader: *Io.Reader) error{ReadFailed}!LookupResult {
    var addresses_len: usize = 0;
    var canonical_name: ?HostName = null;
    while (true) {
        const line = reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
            error.StreamTooLong => {
                // Skip lines that are too long.
                _ = reader.discardDelimiterInclusive('\n') catch |e| switch (e) {
                    error.EndOfStream => break,
                    error.ReadFailed => return error.ReadFailed,
                };
                continue;
            },
            error.ReadFailed => return error.ReadFailed,
            error.EndOfStream => break,
        };
        var split_it = std.mem.splitScalar(u8, line, '#');
        const no_comment_line = split_it.first();

        var line_it = std.mem.tokenizeAny(u8, no_comment_line, " \t");
        const ip_text = line_it.next() orelse continue;
        var first_name_text: ?[]const u8 = null;
        while (line_it.next()) |name_text| {
            if (std.mem.eql(u8, name_text, host_name.bytes)) {
                if (first_name_text == null) first_name_text = name_text;
                break;
            }
        } else continue;

        if (canonical_name == null) {
            if (HostName.init(first_name_text.?)) |name_text| {
                if (name_text.bytes.len <= options.canonical_name_buffer.len) {
                    const canonical_name_dest = options.canonical_name_buffer[0..name_text.bytes.len];
                    @memcpy(canonical_name_dest, name_text.bytes);
                    canonical_name = .{ .bytes = canonical_name_dest };
                }
            } else |_| {}
        }

        if (options.family != .ip6) {
            if (IpAddress.parseIp4(ip_text, options.port)) |addr| {
                options.addresses_buffer[addresses_len] = addr;
                addresses_len += 1;
                if (options.addresses_buffer.len - addresses_len == 0) return .{
                    .addresses_len = addresses_len,
                    .canonical_name = canonical_name orelse copyCanon(options.canonical_name_buffer, ip_text),
                };
            } else |_| {}
        }
        if (options.family != .ip4) {
            if (IpAddress.parseIp6(ip_text, options.port)) |addr| {
                options.addresses_buffer[addresses_len] = addr;
                addresses_len += 1;
                if (options.addresses_buffer.len - addresses_len == 0) return .{
                    .addresses_len = addresses_len,
                    .canonical_name = canonical_name orelse copyCanon(options.canonical_name_buffer, ip_text),
                };
            } else |_| {}
        }
    }
    if (canonical_name == null) assert(addresses_len == 0);
    return .{
        .addresses_len = addresses_len,
        .canonical_name = canonical_name orelse undefined,
    };
}

fn copyCanon(canonical_name_buffer: *[max_len]u8, name: []const u8) HostName {
    const dest = canonical_name_buffer[0..name.len];
    @memcpy(dest, name);
    return .{ .bytes = dest };
}

/// Writes DNS resolution query packet data to `w`; at most 280 bytes.
fn writeResolutionQuery(q: *[280]u8, op: u4, dname: []const u8, class: u8, ty: u8) usize {
    // This implementation is ported from musl libc.
    // A more idiomatic "ziggy" implementation would be welcome.
    var name = dname;
    if (std.mem.endsWith(u8, name, ".")) name.len -= 1;
    assert(name.len <= 253);
    const n = 17 + name.len + @intFromBool(name.len != 0);

    // Construct query template - ID will be filled later
    @memset(q[0..n], 0);
    q[2] = @as(u8, op) * 8 + 1;
    q[5] = 1;
    @memcpy(q[13..][0..name.len], name);
    var i: usize = 13;
    var j: usize = undefined;
    while (q[i] != 0) : (i = j + 1) {
        j = i;
        while (q[j] != 0 and q[j] != '.') : (j += 1) {}
        // TODO determine the circumstances for this and whether or
        // not this should be an error.
        if (j - i - 1 > 62) unreachable;
        q[i - 1] = @intCast(j - i);
    }
    q[i + 1] = ty;
    q[i + 3] = class;

    std.crypto.random.bytes(q[0..2]);
    return n;
}

pub const ExpandDomainNameError = error{InvalidDnsPacket};

pub fn expandDomainName(
    msg: []const u8,
    comp_dn: []const u8,
    exp_dn: []u8,
) ExpandDomainNameError!usize {
    // This implementation is ported from musl libc.
    // A more idiomatic "ziggy" implementation would be welcome.
    var p = comp_dn.ptr;
    var len: usize = std.math.maxInt(usize);
    const end = msg.ptr + msg.len;
    if (p == end or exp_dn.len == 0) return error.InvalidDnsPacket;
    var dest = exp_dn.ptr;
    const dend = dest + @min(exp_dn.len, 254);
    // detect reference loop using an iteration counter
    var i: usize = 0;
    while (i < msg.len) : (i += 2) {
        // loop invariants: p<end, dest<dend
        if ((p[0] & 0xc0) != 0) {
            if (p + 1 == end) return error.InvalidDnsPacket;
            const j = @as(usize, p[0] & 0x3f) << 8 | p[1];
            if (len == std.math.maxInt(usize)) len = @intFromPtr(p) + 2 - @intFromPtr(comp_dn.ptr);
            if (j >= msg.len) return error.InvalidDnsPacket;
            p = msg.ptr + j;
        } else if (p[0] != 0) {
            if (dest != exp_dn.ptr) {
                dest[0] = '.';
                dest += 1;
            }
            var j = p[0];
            p += 1;
            if (j >= @intFromPtr(end) - @intFromPtr(p) or j >= @intFromPtr(dend) - @intFromPtr(dest)) {
                return error.InvalidDnsPacket;
            }
            while (j != 0) {
                j -= 1;
                dest[0] = p[0];
                dest += 1;
                p += 1;
            }
        } else {
            dest[0] = 0;
            if (len == std.math.maxInt(usize)) len = @intFromPtr(p) + 1 - @intFromPtr(comp_dn.ptr);
            return len;
        }
    }
    return error.InvalidDnsPacket;
}

pub const DnsResponse = struct {
    bytes: []const u8,

    pub const Answer = struct {
        rr: u8,
        data: []const u8,
        packet: []const u8,
    };

    pub const Error = error{InvalidDnsPacket};

    pub fn init(r: []const u8) Error!DnsResponse {
        if (r.len < 12) return error.InvalidDnsPacket;
        return .{ .bytes = r };
    }

    pub fn next(dr: *DnsResponse) Error!?Answer {
        _ = dr;
        @panic("TODO");
    }
};

pub const ConnectTcpError = LookupError || IpAddress.ConnectTcpError;

pub fn connectTcp(host_name: HostName, io: Io, port: u16) ConnectTcpError!Stream {
    var addresses_buffer: [32]IpAddress = undefined;

    const results = try lookup(host_name, .{
        .port = port,
        .addresses_buffer = &addresses_buffer,
        .canonical_name_buffer = &.{},
    });
    const addresses = addresses_buffer[0..results.addresses_len];

    if (addresses.len == 0) return error.UnknownHostName;

    for (addresses) |addr| {
        return addr.connectTcp(io) catch |err| switch (err) {
            error.ConnectionRefused => continue,
            else => |e| return e,
        };
    }
    return error.ConnectionRefused;
}

pub const ResolvConf = struct {
    attempts: u32,
    ndots: u32,
    timeout: u32,
    nameservers_buffer: [3]IpAddress,
    nameservers_len: usize,
    search_buffer: [max_len]u8,
    search_len: usize,

    /// Returns `error.StreamTooLong` if a line is longer than 512 bytes.
    fn init(io: Io) !ResolvConf {
        var rc: ResolvConf = .{
            .nameservers_buffer = undefined,
            .nameservers_len = 0,
            .search_buffer = undefined,
            .search_len = 0,
            .ndots = 1,
            .timeout = 5,
            .attempts = 2,
        };

        const file = Io.File.openAbsolute(io, "/etc/resolv.conf", .{}) catch |err| switch (err) {
            error.FileNotFound,
            error.NotDir,
            error.AccessDenied,
            => {
                try addNumeric(&rc, "127.0.0.1", 53);
                return rc;
            },

            else => |e| return e,
        };
        defer file.close(io);

        var line_buf: [512]u8 = undefined;
        var file_reader = file.reader(io, &line_buf);
        parse(&rc, &file_reader.interface) catch |err| switch (err) {
            error.ReadFailed => return file_reader.err.?,
            else => |e| return e,
        };
        return rc;
    }

    const Directive = enum { options, nameserver, domain, search };
    const Option = enum { ndots, attempts, timeout };

    fn parse(rc: *ResolvConf, reader: *Io.Reader) !void {
        while (reader.takeSentinel('\n')) |line_with_comment| {
            const line = line: {
                var split = std.mem.splitScalar(u8, line_with_comment, '#');
                break :line split.first();
            };
            var line_it = std.mem.tokenizeAny(u8, line, " \t");

            const token = line_it.next() orelse continue;
            switch (std.meta.stringToEnum(Directive, token) orelse continue) {
                .options => while (line_it.next()) |sub_tok| {
                    var colon_it = std.mem.splitScalar(u8, sub_tok, ':');
                    const name = colon_it.first();
                    const value_txt = colon_it.next() orelse continue;
                    const value = std.fmt.parseInt(u8, value_txt, 10) catch |err| switch (err) {
                        error.Overflow => 255,
                        error.InvalidCharacter => continue,
                    };
                    switch (std.meta.stringToEnum(Option, name) orelse continue) {
                        .ndots => rc.ndots = @min(value, 15),
                        .attempts => rc.attempts = @min(value, 10),
                        .timeout => rc.timeout = @min(value, 60),
                    }
                },
                .nameserver => {
                    const ip_txt = line_it.next() orelse continue;
                    try addNumeric(rc, ip_txt, 53);
                },
                .domain, .search => {
                    const rest = line_it.rest();
                    @memcpy(rc.search_buffer[0..rest.len], rest);
                    rc.search_len = rest.len;
                },
            }
        } else |err| switch (err) {
            error.EndOfStream => if (reader.bufferedLen() != 0) return error.EndOfStream,
            else => |e| return e,
        }

        if (rc.nameservers_len == 0) {
            try addNumeric(rc, "127.0.0.1", 53);
        }
    }

    fn addNumeric(rc: *ResolvConf, name: []const u8, port: u16) !void {
        assert(rc.nameservers_len < rc.nameservers_buffer.len);
        rc.nameservers_buffer[rc.nameservers_len] = try .parse(name, port);
        rc.nameservers_len += 1;
    }

    fn nameservers(rc: *const ResolvConf) []IpAddress {
        return rc.nameservers_buffer[0..rc.nameservers_len];
    }

    fn sendMessage(
        rc: *const ResolvConf,
        io: Io,
        queries: []const []const u8,
        answers: [][]u8,
    ) !void {
        _ = rc;
        _ = io;
        _ = queries;
        _ = answers;
        @panic("TODO");
    }
};

test ResolvConf {
    const input =
        \\# Generated by resolvconf
        \\nameserver 1.0.0.1
        \\nameserver 1.1.1.1
        \\nameserver fe80::e0e:76ff:fed4:cf22%eno1
        \\options edns0
        \\
    ;
    var reader: Io.Reader = .fixed(input);

    var rc: ResolvConf = .{
        .nameservers_buffer = undefined,
        .nameservers_len = 0,
        .search_buffer = undefined,
        .search_len = 0,
        .ndots = 1,
        .timeout = 5,
        .attempts = 2,
    };

    try rc.parse(&reader);
    try std.testing.expect(false);
}
