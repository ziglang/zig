scheme: []const u8,
host: []const u8,
path: []const u8,
port: ?u16,

/// TODO: redo this implementation according to RFC 1738. This code is only a
/// placeholder for now.
pub fn parse(s: []const u8) !Url {
    var scheme_end: usize = 0;
    var host_start: usize = 0;
    var host_end: usize = 0;
    var path_start: usize = 0;
    var port_start: usize = 0;
    var port_end: usize = 0;
    var state: enum {
        scheme,
        scheme_slash1,
        scheme_slash2,
        host,
        port,
        path,
    } = .scheme;

    for (s) |b, i| switch (state) {
        .scheme => switch (b) {
            ':' => {
                state = .scheme_slash1;
                scheme_end = i;
            },
            else => {},
        },
        .scheme_slash1 => switch (b) {
            '/' => {
                state = .scheme_slash2;
            },
            else => return error.InvalidUrl,
        },
        .scheme_slash2 => switch (b) {
            '/' => {
                state = .host;
                host_start = i + 1;
            },
            else => return error.InvalidUrl,
        },
        .host => switch (b) {
            ':' => {
                state = .port;
                host_end = i;
                port_start = i + 1;
            },
            '/' => {
                state = .path;
                host_end = i;
                path_start = i;
            },
            else => {},
        },
        .port => switch (b) {
            '/' => {
                port_end = i;
                state = .path;
                path_start = i;
            },
            else => {},
        },
        .path => {},
    };

    const port_slice = s[port_start..port_end];
    const port = if (port_slice.len == 0) null else try std.fmt.parseInt(u16, port_slice, 10);

    return .{
        .scheme = s[0..scheme_end],
        .host = s[host_start..host_end],
        .path = s[path_start..],
        .port = port,
    };
}

const Url = @This();
const std = @import("std.zig");
const testing = std.testing;

test "basic" {
    const parsed = try parse("https://ziglang.org/download");
    try testing.expectEqualStrings("https", parsed.scheme);
    try testing.expectEqualStrings("ziglang.org", parsed.host);
    try testing.expectEqualStrings("/download", parsed.path);
    try testing.expectEqual(@as(?u16, null), parsed.port);
}

test "with port" {
    const parsed = try parse("http://example:1337/");
    try testing.expectEqualStrings("http", parsed.scheme);
    try testing.expectEqualStrings("example", parsed.host);
    try testing.expectEqualStrings("/", parsed.path);
    try testing.expectEqual(@as(?u16, 1337), parsed.port);
}
