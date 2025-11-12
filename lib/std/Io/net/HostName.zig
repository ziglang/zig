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

pub const ValidateError = error{
    NameTooLong,
    InvalidHostName,
};

pub fn validate(bytes: []const u8) ValidateError!void {
    if (bytes.len > max_len) return error.NameTooLong;
    if (!std.unicode.utf8ValidateSlice(bytes)) return error.InvalidHostName;
    for (bytes) |byte| {
        if (!std.ascii.isAscii(byte) or byte == '.' or byte == '-' or std.ascii.isAlphanumeric(byte)) {
            continue;
        }
        return error.InvalidHostName;
    }
}

pub fn init(bytes: []const u8) ValidateError!HostName {
    try validate(bytes);
    return .{ .bytes = bytes };
}

pub fn sameParentDomain(parent_host: HostName, child_host: HostName) bool {
    const parent_bytes = parent_host.bytes;
    const child_bytes = child_host.bytes;
    if (!std.ascii.endsWithIgnoreCase(child_bytes, parent_bytes)) return false;
    if (child_bytes.len == parent_bytes.len) return true;
    if (parent_bytes.len > child_bytes.len) return false;
    return child_bytes[child_bytes.len - parent_bytes.len - 1] == '.';
}

test sameParentDomain {
    try std.testing.expect(!sameParentDomain(try .init("foo.com"), try .init("bar.com")));
    try std.testing.expect(sameParentDomain(try .init("foo.com"), try .init("foo.com")));
    try std.testing.expect(sameParentDomain(try .init("foo.com"), try .init("bar.foo.com")));
    try std.testing.expect(!sameParentDomain(try .init("bar.foo.com"), try .init("foo.com")));
}

/// Domain names are case-insensitive (RFC 5890, Section 2.3.2.4)
pub fn eql(a: HostName, b: HostName) bool {
    return std.ascii.eqlIgnoreCase(a.bytes, b.bytes);
}

pub const LookupOptions = struct {
    port: u16,
    canonical_name_buffer: *[max_len]u8,
    /// `null` means either.
    family: ?IpAddress.Family = null,
};

pub const LookupError = error{
    UnknownHostName,
    ResolvConfParseFailed,
    InvalidDnsARecord,
    InvalidDnsAAAARecord,
    InvalidDnsCnameRecord,
    NameServerFailure,
    /// Failed to open or read "/etc/hosts" or "/etc/resolv.conf".
    DetectingNetworkConfigurationFailed,
} || Io.Clock.Error || IpAddress.BindError || Io.Cancelable;

pub const LookupResult = union(enum) {
    address: IpAddress,
    canonical_name: HostName,
    end: LookupError!void,
};

/// Adds any number of `IpAddress` into resolved, exactly one canonical_name,
/// and then always finishes by adding one `LookupResult.end` entry.
///
/// Guaranteed not to block if provided queue has capacity at least 16.
pub fn lookup(
    host_name: HostName,
    io: Io,
    resolved: *Io.Queue(LookupResult),
    options: LookupOptions,
) void {
    return io.vtable.netLookup(io.userdata, host_name, resolved, options);
}

pub const ExpandError = error{InvalidDnsPacket} || ValidateError;

/// Decompresses a DNS name.
///
/// Returns number of bytes consumed from `packet` starting at `i`,
/// along with the expanded `HostName`.
///
/// Asserts `buffer` is has length at least `max_len`.
pub fn expand(noalias packet: []const u8, start_i: usize, noalias dest_buffer: []u8) ExpandError!struct { usize, HostName } {
    const dest = dest_buffer[0..max_len];

    var i = start_i;
    var dest_i: usize = 0;
    var len: ?usize = null;

    // Detect reference loop using an iteration counter.
    for (0..packet.len / 2) |_| {
        if (i >= packet.len) return error.InvalidDnsPacket;

        const c = packet[i];
        if ((c & 0xc0) != 0) {
            if (i + 1 >= packet.len) return error.InvalidDnsPacket;
            const j: usize = (@as(usize, c & 0x3F) << 8) | packet[i + 1];
            if (j >= packet.len) return error.InvalidDnsPacket;
            if (len == null) len = (i + 2) - start_i;
            i = j;
        } else if (c != 0) {
            if (dest_i != 0) {
                dest[dest_i] = '.';
                dest_i += 1;
            }
            const label_len: usize = c;
            if (i + 1 + label_len > packet.len) return error.InvalidDnsPacket;
            if (dest_i + label_len + 1 > dest.len) return error.InvalidDnsPacket;
            @memcpy(dest[dest_i..][0..label_len], packet[i + 1 ..][0..label_len]);
            dest_i += label_len;
            i += 1 + label_len;
        } else {
            return .{
                len orelse i - start_i + 1,
                try .init(dest[0..dest_i]),
            };
        }
    }
    return error.InvalidDnsPacket;
}

pub const DnsRecord = enum(u8) {
    A = 1,
    CNAME = 5,
    AAAA = 28,
    _,
};

pub const DnsResponse = struct {
    bytes: []const u8,
    bytes_index: u32,
    answers_remaining: u16,

    pub const Answer = struct {
        rr: DnsRecord,
        packet: []const u8,
        data_off: u32,
        data_len: u16,
    };

    pub const Error = error{InvalidDnsPacket};

    pub fn init(r: []const u8) Error!DnsResponse {
        if (r.len < 12) return error.InvalidDnsPacket;
        if ((r[3] & 15) != 0) return .{ .bytes = r, .bytes_index = 3, .answers_remaining = 0 };
        var i: u32 = 12;
        var query_count = std.mem.readInt(u16, r[4..6], .big);
        while (query_count != 0) : (query_count -= 1) {
            while (i < r.len and r[i] -% 1 < 127) i += 1;
            if (r.len - i < 6) return error.InvalidDnsPacket;
            i = i + 5 + @intFromBool(r[i] != 0);
        }
        return .{
            .bytes = r,
            .bytes_index = i,
            .answers_remaining = std.mem.readInt(u16, r[6..8], .big),
        };
    }

    pub fn next(dr: *DnsResponse) Error!?Answer {
        if (dr.answers_remaining == 0) return null;
        dr.answers_remaining -= 1;
        const r = dr.bytes;
        var i = dr.bytes_index;
        while (i < r.len and r[i] -% 1 < 127) i += 1;
        if (r.len - i < 12) return error.InvalidDnsPacket;
        i = i + 1 + @intFromBool(r[i] != 0);
        const len = std.mem.readInt(u16, r[i + 8 ..][0..2], .big);
        if (i + 10 + len > r.len) return error.InvalidDnsPacket;
        defer dr.bytes_index = i + 10 + len;
        return .{
            .rr = @enumFromInt(r[i + 1]),
            .packet = r,
            .data_off = i + 10,
            .data_len = len,
        };
    }
};

pub const ConnectError = LookupError || IpAddress.ConnectError;

pub fn connect(
    host_name: HostName,
    io: Io,
    port: u16,
    options: IpAddress.ConnectOptions,
) ConnectError!Stream {
    var connect_many_buffer: [32]ConnectManyResult = undefined;
    var connect_many_queue: Io.Queue(ConnectManyResult) = .init(&connect_many_buffer);

    var connect_many = io.async(connectMany, .{ host_name, io, port, &connect_many_queue, options });
    var saw_end = false;
    defer {
        connect_many.cancel(io);
        if (!saw_end) while (true) switch (connect_many_queue.getOneUncancelable(io)) {
            .connection => |loser| if (loser) |s| s.close(io) else |_| continue,
            .end => break,
        };
    }

    var aggregate_error: ConnectError = error.UnknownHostName;

    while (connect_many_queue.getOne(io)) |result| switch (result) {
        .connection => |connection| if (connection) |stream| return stream else |err| switch (err) {
            error.SystemResources,
            error.OptionUnsupported,
            error.ProcessFdQuotaExceeded,
            error.SystemFdQuotaExceeded,
            error.Canceled,
            => |e| return e,

            error.WouldBlock => return error.Unexpected,

            else => |e| aggregate_error = e,
        },
        .end => |end| {
            saw_end = true;
            try end;
            return aggregate_error;
        },
    } else |err| switch (err) {
        error.Canceled => |e| return e,
    }
}

pub const ConnectManyResult = union(enum) {
    connection: IpAddress.ConnectError!Stream,
    end: ConnectError!void,
};

/// Asynchronously establishes a connection to all IP addresses associated with
/// a host name, adding them to a results queue upon completion.
pub fn connectMany(
    host_name: HostName,
    io: Io,
    port: u16,
    results: *Io.Queue(ConnectManyResult),
    options: IpAddress.ConnectOptions,
) void {
    var canonical_name_buffer: [max_len]u8 = undefined;
    var lookup_buffer: [32]HostName.LookupResult = undefined;
    var lookup_queue: Io.Queue(LookupResult) = .init(&lookup_buffer);
    var group: Io.Group = .init;
    defer group.cancel(io);

    group.async(io, lookup, .{ host_name, io, &lookup_queue, .{
        .port = port,
        .canonical_name_buffer = &canonical_name_buffer,
    } });

    while (lookup_queue.getOne(io)) |dns_result| switch (dns_result) {
        .address => |address| group.async(io, enqueueConnection, .{ address, io, results, options }),
        .canonical_name => continue,
        .end => |lookup_result| {
            group.wait(io);
            results.putOneUncancelable(io, .{ .end = lookup_result });
            return;
        },
    } else |err| switch (err) {
        error.Canceled => |e| {
            group.cancel(io);
            results.putOneUncancelable(io, .{ .end = e });
        },
    }
}

fn enqueueConnection(
    address: IpAddress,
    io: Io,
    queue: *Io.Queue(ConnectManyResult),
    options: IpAddress.ConnectOptions,
) void {
    queue.putOneUncancelable(io, .{ .connection = address.connect(io, options) });
}

pub const ResolvConf = struct {
    attempts: u32,
    ndots: u32,
    timeout_seconds: u32,
    nameservers_buffer: [max_nameservers]IpAddress,
    nameservers_len: usize,
    search_buffer: [max_len]u8,
    search_len: usize,

    /// According to resolv.conf(5) there is a maximum of 3 nameservers in this
    /// file.
    pub const max_nameservers = 3;

    /// Returns `error.StreamTooLong` if a line is longer than 512 bytes.
    pub fn init(io: Io) !ResolvConf {
        var rc: ResolvConf = .{
            .nameservers_buffer = undefined,
            .nameservers_len = 0,
            .search_buffer = undefined,
            .search_len = 0,
            .ndots = 1,
            .timeout_seconds = 5,
            .attempts = 2,
        };

        const file = Io.File.openAbsolute(io, "/etc/resolv.conf", .{}) catch |err| switch (err) {
            error.FileNotFound,
            error.NotDir,
            error.AccessDenied,
            => {
                try addNumeric(&rc, io, "127.0.0.1", 53);
                return rc;
            },

            else => |e| return e,
        };
        defer file.close(io);

        var line_buf: [512]u8 = undefined;
        var file_reader = file.reader(io, &line_buf);
        parse(&rc, io, &file_reader.interface) catch |err| switch (err) {
            error.ReadFailed => return file_reader.err.?,
            else => |e| return e,
        };
        return rc;
    }

    const Directive = enum { options, nameserver, domain, search };
    const Option = enum { ndots, attempts, timeout };

    pub fn parse(rc: *ResolvConf, io: Io, reader: *Io.Reader) !void {
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
                        .timeout => rc.timeout_seconds = @min(value, 60),
                    }
                },
                .nameserver => {
                    const ip_txt = line_it.next() orelse continue;
                    try addNumeric(rc, io, ip_txt, 53);
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
            try addNumeric(rc, io, "127.0.0.1", 53);
        }
    }

    fn addNumeric(rc: *ResolvConf, io: Io, name: []const u8, port: u16) !void {
        if (rc.nameservers_len < rc.nameservers_buffer.len) {
            rc.nameservers_buffer[rc.nameservers_len] = try .resolve(io, name, port);
            rc.nameservers_len += 1;
        }
    }

    pub fn nameservers(rc: *const ResolvConf) []const IpAddress {
        return rc.nameservers_buffer[0..rc.nameservers_len];
    }
};

test ResolvConf {
    const input =
        \\# Generated by resolvconf
        \\nameserver 1.0.0.1
        \\nameserver 1.1.1.1
        \\nameserver fe80::e0e:76ff:fed4:cf22
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
        .timeout_seconds = 5,
        .attempts = 2,
    };

    try rc.parse(std.testing.io, &reader);
    try std.testing.expectEqual(3, rc.nameservers().len);
}
