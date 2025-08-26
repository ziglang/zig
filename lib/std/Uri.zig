//! Uniform Resource Identifier (URI) parsing roughly adhering to <https://tools.ietf.org/html/rfc3986>.
//! Does not do perfect grammar and character class checking, but should be robust against URIs in the wild.

const std = @import("std.zig");
const testing = std.testing;
const Uri = @This();
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;

scheme: []const u8,
user: ?Component = null,
password: ?Component = null,
host: ?Component = null,
port: ?u16 = null,
path: Component = Component.empty,
query: ?Component = null,
fragment: ?Component = null,

pub const host_name_max = 255;

/// Returned value may point into `buffer` or be the original string.
///
/// Suggested buffer length: `host_name_max`.
///
/// See also:
/// * `getHostAlloc`
pub fn getHost(uri: Uri, buffer: []u8) error{ UriMissingHost, UriHostTooLong }![]const u8 {
    const component = uri.host orelse return error.UriMissingHost;
    return component.toRaw(buffer) catch |err| switch (err) {
        error.NoSpaceLeft => return error.UriHostTooLong,
    };
}

/// Returned value may point into `buffer` or be the original string.
///
/// See also:
/// * `getHost`
pub fn getHostAlloc(uri: Uri, arena: Allocator) error{ UriMissingHost, UriHostTooLong, OutOfMemory }![]const u8 {
    const component = uri.host orelse return error.UriMissingHost;
    const result = try component.toRawMaybeAlloc(arena);
    if (result.len > host_name_max) return error.UriHostTooLong;
    return result;
}

pub const Component = union(enum) {
    /// Invalid characters in this component must be percent encoded
    /// before being printed as part of a URI.
    raw: []const u8,
    /// This component is already percent-encoded, it can be printed
    /// directly as part of a URI.
    percent_encoded: []const u8,

    pub const empty: Component = .{ .percent_encoded = "" };

    pub fn isEmpty(component: Component) bool {
        return switch (component) {
            .raw, .percent_encoded => |string| string.len == 0,
        };
    }

    /// Returned value may point into `buffer` or be the original string.
    pub fn toRaw(component: Component, buffer: []u8) error{NoSpaceLeft}![]const u8 {
        return switch (component) {
            .raw => |raw| raw,
            .percent_encoded => |percent_encoded| if (std.mem.indexOfScalar(u8, percent_encoded, '%')) |_|
                try std.fmt.bufPrint(buffer, "{f}", .{std.fmt.alt(component, .formatRaw)})
            else
                percent_encoded,
        };
    }

    /// Allocates the result with `arena` only if needed, so the result should not be freed.
    pub fn toRawMaybeAlloc(component: Component, arena: Allocator) Allocator.Error![]const u8 {
        return switch (component) {
            .raw => |raw| raw,
            .percent_encoded => |percent_encoded| if (std.mem.indexOfScalar(u8, percent_encoded, '%')) |_|
                try std.fmt.allocPrint(arena, "{f}", .{std.fmt.alt(component, .formatRaw)})
            else
                percent_encoded,
        };
    }

    pub fn formatRaw(component: Component, w: *Writer) Writer.Error!void {
        switch (component) {
            .raw => |raw| try w.writeAll(raw),
            .percent_encoded => |percent_encoded| {
                var start: usize = 0;
                var index: usize = 0;
                while (std.mem.indexOfScalarPos(u8, percent_encoded, index, '%')) |percent| {
                    index = percent + 1;
                    if (percent_encoded.len - index < 2) continue;
                    const percent_encoded_char =
                        std.fmt.parseInt(u8, percent_encoded[index..][0..2], 16) catch continue;
                    try w.print("{s}{c}", .{
                        percent_encoded[start..percent],
                        percent_encoded_char,
                    });
                    start = percent + 3;
                    index = percent + 3;
                }
                try w.writeAll(percent_encoded[start..]);
            },
        }
    }

    pub fn formatEscaped(component: Component, w: *Writer) Writer.Error!void {
        switch (component) {
            .raw => |raw| try percentEncode(w, raw, isUnreserved),
            .percent_encoded => |percent_encoded| try w.writeAll(percent_encoded),
        }
    }

    pub fn formatUser(component: Component, w: *Writer) Writer.Error!void {
        switch (component) {
            .raw => |raw| try percentEncode(w, raw, isUserChar),
            .percent_encoded => |percent_encoded| try w.writeAll(percent_encoded),
        }
    }

    pub fn formatPassword(component: Component, w: *Writer) Writer.Error!void {
        switch (component) {
            .raw => |raw| try percentEncode(w, raw, isPasswordChar),
            .percent_encoded => |percent_encoded| try w.writeAll(percent_encoded),
        }
    }

    pub fn formatHost(component: Component, w: *Writer) Writer.Error!void {
        switch (component) {
            .raw => |raw| try percentEncode(w, raw, isHostChar),
            .percent_encoded => |percent_encoded| try w.writeAll(percent_encoded),
        }
    }

    pub fn formatPath(component: Component, w: *Writer) Writer.Error!void {
        switch (component) {
            .raw => |raw| try percentEncode(w, raw, isPathChar),
            .percent_encoded => |percent_encoded| try w.writeAll(percent_encoded),
        }
    }

    pub fn formatQuery(component: Component, w: *Writer) Writer.Error!void {
        switch (component) {
            .raw => |raw| try percentEncode(w, raw, isQueryChar),
            .percent_encoded => |percent_encoded| try w.writeAll(percent_encoded),
        }
    }

    pub fn formatFragment(component: Component, w: *Writer) Writer.Error!void {
        switch (component) {
            .raw => |raw| try percentEncode(w, raw, isFragmentChar),
            .percent_encoded => |percent_encoded| try w.writeAll(percent_encoded),
        }
    }

    pub fn percentEncode(w: *Writer, raw: []const u8, comptime isValidChar: fn (u8) bool) Writer.Error!void {
        var start: usize = 0;
        for (raw, 0..) |char, index| {
            if (isValidChar(char)) continue;
            try w.print("{s}%{X:0>2}", .{ raw[start..index], char });
            start = index + 1;
        }
        try w.writeAll(raw[start..]);
    }
};

/// Percent decodes all %XX where XX is a valid hex number.
/// `output` may alias `input` if `output.ptr <= input.ptr`.
/// Mutates and returns a subslice of `output`.
pub fn percentDecodeBackwards(output: []u8, input: []const u8) []u8 {
    var input_index = input.len;
    var output_index = output.len;
    while (input_index > 0) {
        if (input_index >= 3) {
            const maybe_percent_encoded = input[input_index - 3 ..][0..3];
            if (maybe_percent_encoded[0] == '%') {
                if (std.fmt.parseInt(u8, maybe_percent_encoded[1..], 16)) |percent_encoded_char| {
                    input_index -= maybe_percent_encoded.len;
                    output_index -= 1;
                    output[output_index] = percent_encoded_char;
                    continue;
                } else |_| {}
            }
        }
        input_index -= 1;
        output_index -= 1;
        output[output_index] = input[input_index];
    }
    return output[output_index..];
}

/// Percent decodes all %XX where XX is a valid hex number.
/// Mutates and returns a subslice of `buffer`.
pub fn percentDecodeInPlace(buffer: []u8) []u8 {
    return percentDecodeBackwards(buffer, buffer);
}

pub const ParseError = error{ UnexpectedCharacter, InvalidFormat, InvalidPort };

/// Parses the URI or returns an error. This function is not compliant, but is required to parse
/// some forms of URIs in the wild, such as HTTP Location headers.
/// The return value will contain strings pointing into the original `text`.
/// Each component that is provided, will be non-`null`.
pub fn parseAfterScheme(scheme: []const u8, text: []const u8) ParseError!Uri {
    var uri: Uri = .{ .scheme = scheme, .path = undefined };
    var i: usize = 0;

    if (std.mem.startsWith(u8, text, "//")) a: {
        i = std.mem.indexOfAnyPos(u8, text, 2, &authority_sep) orelse text.len;
        const authority = text[2..i];
        if (authority.len == 0) {
            if (!std.mem.startsWith(u8, text[2..], "/")) return error.InvalidFormat;
            break :a;
        }

        var start_of_host: usize = 0;
        if (std.mem.indexOf(u8, authority, "@")) |index| {
            start_of_host = index + 1;
            const user_info = authority[0..index];

            if (std.mem.indexOf(u8, user_info, ":")) |idx| {
                uri.user = .{ .percent_encoded = user_info[0..idx] };
                if (idx < user_info.len - 1) { // empty password is also "no password"
                    uri.password = .{ .percent_encoded = user_info[idx + 1 ..] };
                }
            } else {
                uri.user = .{ .percent_encoded = user_info };
                uri.password = null;
            }
        }

        // only possible if uri consists of only `userinfo@`
        if (start_of_host >= authority.len) break :a;

        var end_of_host: usize = authority.len;

        // if  we see `]` first without `@`
        if (authority[start_of_host] == ']') {
            return error.InvalidFormat;
        }

        if (authority.len > start_of_host and authority[start_of_host] == '[') { // IPv6
            end_of_host = std.mem.lastIndexOf(u8, authority, "]") orelse return error.InvalidFormat;
            end_of_host += 1;

            if (std.mem.lastIndexOf(u8, authority, ":")) |index| {
                if (index >= end_of_host) { // if not part of the V6 address field
                    end_of_host = @min(end_of_host, index);
                    uri.port = std.fmt.parseInt(u16, authority[index + 1 ..], 10) catch return error.InvalidPort;
                }
            }
        } else if (std.mem.lastIndexOf(u8, authority, ":")) |index| {
            if (index >= start_of_host) { // if not part of the userinfo field
                end_of_host = @min(end_of_host, index);
                uri.port = std.fmt.parseInt(u16, authority[index + 1 ..], 10) catch return error.InvalidPort;
            }
        }

        if (start_of_host >= end_of_host) return error.InvalidFormat;
        uri.host = .{ .percent_encoded = authority[start_of_host..end_of_host] };
    }

    const path_start = i;
    i = std.mem.indexOfAnyPos(u8, text, path_start, &path_sep) orelse text.len;
    uri.path = .{ .percent_encoded = text[path_start..i] };

    if (std.mem.startsWith(u8, text[i..], "?")) {
        const query_start = i + 1;
        i = std.mem.indexOfScalarPos(u8, text, query_start, '#') orelse text.len;
        uri.query = .{ .percent_encoded = text[query_start..i] };
    }

    if (std.mem.startsWith(u8, text[i..], "#")) {
        uri.fragment = .{ .percent_encoded = text[i + 1 ..] };
    }

    return uri;
}

pub fn format(uri: *const Uri, writer: *Writer) Writer.Error!void {
    return writeToStream(uri, writer, .all);
}

pub fn writeToStream(uri: *const Uri, writer: *Writer, flags: Format.Flags) Writer.Error!void {
    if (flags.scheme) {
        try writer.print("{s}:", .{uri.scheme});
        if (flags.authority and uri.host != null) {
            try writer.writeAll("//");
        }
    }
    if (flags.authority) {
        if (flags.authentication and uri.host != null) {
            if (uri.user) |user| {
                try user.formatUser(writer);
                if (uri.password) |password| {
                    try writer.writeByte(':');
                    try password.formatPassword(writer);
                }
                try writer.writeByte('@');
            }
        }
        if (uri.host) |host| {
            try host.formatHost(writer);
            if (flags.port) {
                if (uri.port) |port| try writer.print(":{d}", .{port});
            }
        }
    }
    if (flags.path) {
        const uri_path: Component = if (uri.path.isEmpty()) .{ .percent_encoded = "/" } else uri.path;
        try uri_path.formatPath(writer);
        if (flags.query) {
            if (uri.query) |query| {
                try writer.writeByte('?');
                try query.formatQuery(writer);
            }
        }
        if (flags.fragment) {
            if (uri.fragment) |fragment| {
                try writer.writeByte('#');
                try fragment.formatFragment(writer);
            }
        }
    }
}

pub const Format = struct {
    uri: *const Uri,
    flags: Flags = .{},

    pub const Flags = struct {
        /// When true, include the scheme part of the URI.
        scheme: bool = false,
        /// When true, include the user and password part of the URI. Ignored if `authority` is false.
        authentication: bool = false,
        /// When true, include the authority part of the URI.
        authority: bool = false,
        /// When true, include the path part of the URI.
        path: bool = false,
        /// When true, include the query part of the URI. Ignored when `path` is false.
        query: bool = false,
        /// When true, include the fragment part of the URI. Ignored when `path` is false.
        fragment: bool = false,
        /// When true, include the port part of the URI. Ignored when `port` is null.
        port: bool = true,

        pub const all: Flags = .{
            .scheme = true,
            .authentication = true,
            .authority = true,
            .path = true,
            .query = true,
            .fragment = true,
            .port = true,
        };
    };

    pub fn default(f: Format, writer: *Writer) Writer.Error!void {
        return writeToStream(f.uri, writer, f.flags);
    }
};

pub fn fmt(uri: *const Uri, flags: Format.Flags) std.fmt.Formatter(Format, Format.default) {
    return .{ .data = .{ .uri = uri, .flags = flags } };
}

/// The return value will contain strings pointing into the original `text`.
/// Each component that is provided will be non-`null`.
pub fn parse(text: []const u8) ParseError!Uri {
    const end = for (text, 0..) |byte, i| {
        if (!isSchemeChar(byte)) break i;
    } else text.len;
    // After the scheme, a ':' must appear.
    if (end >= text.len) return error.InvalidFormat;
    if (text[end] != ':') return error.UnexpectedCharacter;
    return parseAfterScheme(text[0..end], text[end + 1 ..]);
}

pub const ResolveInPlaceError = ParseError || error{NoSpaceLeft};

/// Resolves a URI against a base URI, conforming to
/// [RFC 3986, Section 5](https://www.rfc-editor.org/rfc/rfc3986#section-5)
///
/// Assumes new location is already copied to the beginning of `aux_buf.*`.
/// Parses that new location as a URI, and then resolves the path in place.
///
/// If a merge needs to take place, the newly constructed path will be stored
/// in `aux_buf.*` just after the copied location, and `aux_buf.*` will be
/// modified to only contain the remaining unused space.
pub fn resolveInPlace(base: Uri, new_len: usize, aux_buf: *[]u8) ResolveInPlaceError!Uri {
    const new = aux_buf.*[0..new_len];
    const new_parsed = parse(new) catch |err| (parseAfterScheme("", new) catch return err);
    aux_buf.* = aux_buf.*[new_len..];
    // As you can see above, `new` is not a const pointer.
    const new_path: []u8 = @constCast(new_parsed.path.percent_encoded);

    if (new_parsed.scheme.len > 0) return .{
        .scheme = new_parsed.scheme,
        .user = new_parsed.user,
        .password = new_parsed.password,
        .host = new_parsed.host,
        .port = new_parsed.port,
        .path = remove_dot_segments(new_path),
        .query = new_parsed.query,
        .fragment = new_parsed.fragment,
    };

    if (new_parsed.host) |host| return .{
        .scheme = base.scheme,
        .user = new_parsed.user,
        .password = new_parsed.password,
        .host = host,
        .port = new_parsed.port,
        .path = remove_dot_segments(new_path),
        .query = new_parsed.query,
        .fragment = new_parsed.fragment,
    };

    const path, const query = if (new_path.len == 0) .{
        base.path,
        new_parsed.query orelse base.query,
    } else if (new_path[0] == '/') .{
        remove_dot_segments(new_path),
        new_parsed.query,
    } else .{
        try merge_paths(base.path, new_path, aux_buf),
        new_parsed.query,
    };

    return .{
        .scheme = base.scheme,
        .user = base.user,
        .password = base.password,
        .host = base.host,
        .port = base.port,
        .path = path,
        .query = query,
        .fragment = new_parsed.fragment,
    };
}

/// In-place implementation of RFC 3986, Section 5.2.4.
fn remove_dot_segments(path: []u8) Component {
    var in_i: usize = 0;
    var out_i: usize = 0;
    while (in_i < path.len) {
        if (std.mem.startsWith(u8, path[in_i..], "./")) {
            in_i += 2;
        } else if (std.mem.startsWith(u8, path[in_i..], "../")) {
            in_i += 3;
        } else if (std.mem.startsWith(u8, path[in_i..], "/./")) {
            in_i += 2;
        } else if (std.mem.eql(u8, path[in_i..], "/.")) {
            in_i += 1;
            path[in_i] = '/';
        } else if (std.mem.startsWith(u8, path[in_i..], "/../")) {
            in_i += 3;
            while (out_i > 0) {
                out_i -= 1;
                if (path[out_i] == '/') break;
            }
        } else if (std.mem.eql(u8, path[in_i..], "/..")) {
            in_i += 2;
            path[in_i] = '/';
            while (out_i > 0) {
                out_i -= 1;
                if (path[out_i] == '/') break;
            }
        } else if (std.mem.eql(u8, path[in_i..], ".")) {
            in_i += 1;
        } else if (std.mem.eql(u8, path[in_i..], "..")) {
            in_i += 2;
        } else {
            while (true) {
                path[out_i] = path[in_i];
                out_i += 1;
                in_i += 1;
                if (in_i >= path.len or path[in_i] == '/') break;
            }
        }
    }
    return .{ .percent_encoded = path[0..out_i] };
}

test remove_dot_segments {
    {
        var buffer = "/a/b/c/./../../g".*;
        try std.testing.expectEqualStrings("/a/g", remove_dot_segments(&buffer).percent_encoded);
    }
}

/// 5.2.3. Merge Paths
fn merge_paths(base: Component, new: []u8, aux_buf: *[]u8) error{NoSpaceLeft}!Component {
    var aux: Writer = .fixed(aux_buf.*);
    if (!base.isEmpty()) {
        base.formatPath(&aux) catch return error.NoSpaceLeft;
        aux.end = std.mem.lastIndexOfScalar(u8, aux.buffered(), '/') orelse return remove_dot_segments(new);
    }
    aux.print("/{s}", .{new}) catch return error.NoSpaceLeft;
    const merged_path = remove_dot_segments(aux.buffered());
    aux_buf.* = aux_buf.*[merged_path.percent_encoded.len..];
    return merged_path;
}

/// scheme      = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
fn isSchemeChar(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '+', '-', '.' => true,
        else => false,
    };
}

/// sub-delims  = "!" / "$" / "&" / "'" / "(" / ")"
///             / "*" / "+" / "," / ";" / "="
fn isSubLimit(c: u8) bool {
    return switch (c) {
        '!', '$', '&', '\'', '(', ')', '*', '+', ',', ';', '=' => true,
        else => false,
    };
}

/// unreserved  = ALPHA / DIGIT / "-" / "." / "_" / "~"
fn isUnreserved(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '.', '_', '~' => true,
        else => false,
    };
}

fn isUserChar(c: u8) bool {
    return isUnreserved(c) or isSubLimit(c);
}

fn isPasswordChar(c: u8) bool {
    return isUserChar(c) or c == ':';
}

fn isHostChar(c: u8) bool {
    return isPasswordChar(c) or c == '[' or c == ']';
}

fn isPathChar(c: u8) bool {
    return isUserChar(c) or c == '/' or c == ':' or c == '@';
}

fn isQueryChar(c: u8) bool {
    return isPathChar(c) or c == '?';
}

const isFragmentChar = isQueryChar;

const authority_sep: [3]u8 = .{ '/', '?', '#' };
const path_sep: [2]u8 = .{ '?', '#' };

test "basic" {
    const parsed = try parse("https://ziglang.org/download");
    try testing.expectEqualStrings("https", parsed.scheme);
    try testing.expectEqualStrings("ziglang.org", parsed.host.?.percent_encoded);
    try testing.expectEqualStrings("/download", parsed.path.percent_encoded);
    try testing.expectEqual(@as(?u16, null), parsed.port);
}

test "with port" {
    const parsed = try parse("http://example:1337/");
    try testing.expectEqualStrings("http", parsed.scheme);
    try testing.expectEqualStrings("example", parsed.host.?.percent_encoded);
    try testing.expectEqualStrings("/", parsed.path.percent_encoded);
    try testing.expectEqual(@as(?u16, 1337), parsed.port);
}

test "should fail gracefully" {
    try std.testing.expectError(error.InvalidFormat, parse("foobar://"));
}

test "file" {
    const parsed = try parse("file:///");
    try std.testing.expectEqualStrings("file", parsed.scheme);
    try std.testing.expectEqual(@as(?Component, null), parsed.host);
    try std.testing.expectEqualStrings("/", parsed.path.percent_encoded);

    const parsed2 = try parse("file:///an/absolute/path/to/something");
    try std.testing.expectEqualStrings("file", parsed2.scheme);
    try std.testing.expectEqual(@as(?Component, null), parsed2.host);
    try std.testing.expectEqualStrings("/an/absolute/path/to/something", parsed2.path.percent_encoded);

    const parsed3 = try parse("file://localhost/an/absolute/path/to/another/thing/");
    try std.testing.expectEqualStrings("file", parsed3.scheme);
    try std.testing.expectEqualStrings("localhost", parsed3.host.?.percent_encoded);
    try std.testing.expectEqualStrings("/an/absolute/path/to/another/thing/", parsed3.path.percent_encoded);
}

test "scheme" {
    try std.testing.expectEqualStrings("http", (try parse("http:_")).scheme);
    try std.testing.expectEqualStrings("scheme-mee", (try parse("scheme-mee:_")).scheme);
    try std.testing.expectEqualStrings("a.b.c", (try parse("a.b.c:_")).scheme);
    try std.testing.expectEqualStrings("ab+", (try parse("ab+:_")).scheme);
    try std.testing.expectEqualStrings("X+++", (try parse("X+++:_")).scheme);
    try std.testing.expectEqualStrings("Y+-.", (try parse("Y+-.:_")).scheme);
}

test "authority" {
    try std.testing.expectEqualStrings("hostname", (try parse("scheme://hostname")).host.?.percent_encoded);

    try std.testing.expectEqualStrings("hostname", (try parse("scheme://userinfo@hostname")).host.?.percent_encoded);
    try std.testing.expectEqualStrings("userinfo", (try parse("scheme://userinfo@hostname")).user.?.percent_encoded);
    try std.testing.expectEqual(@as(?Component, null), (try parse("scheme://userinfo@hostname")).password);
    try std.testing.expectEqual(@as(?Component, null), (try parse("scheme://userinfo@")).host);

    try std.testing.expectEqualStrings("hostname", (try parse("scheme://user:password@hostname")).host.?.percent_encoded);
    try std.testing.expectEqualStrings("user", (try parse("scheme://user:password@hostname")).user.?.percent_encoded);
    try std.testing.expectEqualStrings("password", (try parse("scheme://user:password@hostname")).password.?.percent_encoded);

    try std.testing.expectEqualStrings("hostname", (try parse("scheme://hostname:0")).host.?.percent_encoded);
    try std.testing.expectEqual(@as(u16, 1234), (try parse("scheme://hostname:1234")).port.?);

    try std.testing.expectEqualStrings("hostname", (try parse("scheme://userinfo@hostname:1234")).host.?.percent_encoded);
    try std.testing.expectEqual(@as(u16, 1234), (try parse("scheme://userinfo@hostname:1234")).port.?);
    try std.testing.expectEqualStrings("userinfo", (try parse("scheme://userinfo@hostname:1234")).user.?.percent_encoded);
    try std.testing.expectEqual(@as(?Component, null), (try parse("scheme://userinfo@hostname:1234")).password);

    try std.testing.expectEqualStrings("hostname", (try parse("scheme://user:password@hostname:1234")).host.?.percent_encoded);
    try std.testing.expectEqual(@as(u16, 1234), (try parse("scheme://user:password@hostname:1234")).port.?);
    try std.testing.expectEqualStrings("user", (try parse("scheme://user:password@hostname:1234")).user.?.percent_encoded);
    try std.testing.expectEqualStrings("password", (try parse("scheme://user:password@hostname:1234")).password.?.percent_encoded);
}

test "authority.password" {
    try std.testing.expectEqualStrings("username", (try parse("scheme://username@a")).user.?.percent_encoded);
    try std.testing.expectEqual(@as(?Component, null), (try parse("scheme://username@a")).password);

    try std.testing.expectEqualStrings("username", (try parse("scheme://username:@a")).user.?.percent_encoded);
    try std.testing.expectEqual(@as(?Component, null), (try parse("scheme://username:@a")).password);

    try std.testing.expectEqualStrings("username", (try parse("scheme://username:password@a")).user.?.percent_encoded);
    try std.testing.expectEqualStrings("password", (try parse("scheme://username:password@a")).password.?.percent_encoded);

    try std.testing.expectEqualStrings("username", (try parse("scheme://username::@a")).user.?.percent_encoded);
    try std.testing.expectEqualStrings(":", (try parse("scheme://username::@a")).password.?.percent_encoded);
}

fn testAuthorityHost(comptime hostlist: anytype) !void {
    inline for (hostlist) |hostname| {
        try std.testing.expectEqualStrings(hostname, (try parse("scheme://" ++ hostname)).host.?.percent_encoded);
    }
}

test "authority.dns-names" {
    try testAuthorityHost(.{
        "a",
        "a.b",
        "example.com",
        "www.example.com",
        "example.org.",
        "www.example.org.",
        "xn--nw2a.xn--j6w193g", // internationalized URI: 見.香港
        "fe80--1ff-fe23-4567-890as3.ipv6-literal.net",
    });
}

test "authority.IPv4" {
    try testAuthorityHost(.{
        "127.0.0.1",
        "255.255.255.255",
        "0.0.0.0",
        "8.8.8.8",
        "1.2.3.4",
        "192.168.0.1",
        "10.42.0.0",
    });
}

test "authority.IPv6" {
    try testAuthorityHost(.{
        "[2001:db8:0:0:0:0:2:1]",
        "[2001:db8::2:1]",
        "[2001:db8:0000:1:1:1:1:1]",
        "[2001:db8:0:1:1:1:1:1]",
        "[0:0:0:0:0:0:0:0]",
        "[0:0:0:0:0:0:0:1]",
        "[::1]",
        "[::]",
        "[2001:db8:85a3:8d3:1319:8a2e:370:7348]",
        "[fe80::1ff:fe23:4567:890a%25eth2]",
        "[fe80::1ff:fe23:4567:890a]",
        "[fe80::1ff:fe23:4567:890a%253]",
        "[fe80:3::1ff:fe23:4567:890a]",
    });
}

test "RFC example 1" {
    const uri = "foo://example.com:8042/over/there?name=ferret#nose";
    try std.testing.expectEqual(Uri{
        .scheme = uri[0..3],
        .user = null,
        .password = null,
        .host = .{ .percent_encoded = uri[6..17] },
        .port = 8042,
        .path = .{ .percent_encoded = uri[22..33] },
        .query = .{ .percent_encoded = uri[34..45] },
        .fragment = .{ .percent_encoded = uri[46..50] },
    }, try parse(uri));
}

test "RFC example 2" {
    const uri = "urn:example:animal:ferret:nose";
    try std.testing.expectEqual(Uri{
        .scheme = uri[0..3],
        .user = null,
        .password = null,
        .host = null,
        .port = null,
        .path = .{ .percent_encoded = uri[4..] },
        .query = null,
        .fragment = null,
    }, try parse(uri));
}

// source:
// https://en.wikipedia.org/wiki/Uniform_Resource_Identifier#Examples
test "Examples from wikipedia" {
    const list = [_][]const u8{
        "https://john.doe@www.example.com:123/forum/questions/?tag=networking&order=newest#top",
        "ldap://[2001:db8::7]/c=GB?objectClass?one",
        "mailto:John.Doe@example.com",
        "news:comp.infosystems.www.servers.unix",
        "tel:+1-816-555-1212",
        "telnet://192.0.2.16:80/",
        "urn:oasis:names:specification:docbook:dtd:xml:4.1.2",
        "http://a/b/c/d;p?q",
    };
    for (list) |uri| {
        _ = try parse(uri);
    }
}

// source:
// https://tools.ietf.org/html/rfc3986#section-5.4.1
test "Examples from RFC3986" {
    const list = [_][]const u8{
        "http://a/b/c/g",
        "http://a/b/c/g",
        "http://a/b/c/g/",
        "http://a/g",
        "http://g",
        "http://a/b/c/d;p?y",
        "http://a/b/c/g?y",
        "http://a/b/c/d;p?q#s",
        "http://a/b/c/g#s",
        "http://a/b/c/g?y#s",
        "http://a/b/c/;x",
        "http://a/b/c/g;x",
        "http://a/b/c/g;x?y#s",
        "http://a/b/c/d;p?q",
        "http://a/b/c/",
        "http://a/b/c/",
        "http://a/b/",
        "http://a/b/",
        "http://a/b/g",
        "http://a/",
        "http://a/",
        "http://a/g",
    };
    for (list) |uri| {
        _ = try parse(uri);
    }
}

test "Special test" {
    // This is for all of you code readers ♥
    _ = try parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=youtu.be&t=0");
}

test "URI percent encoding" {
    try std.testing.expectFmt(
        "%5C%C3%B6%2F%20%C3%A4%C3%B6%C3%9F%20~~.adas-https%3A%2F%2Fcanvas%3A123%2F%23ads%26%26sad",
        "{f}",
        .{std.fmt.alt(
            @as(Component, .{ .raw = "\\ö/ äöß ~~.adas-https://canvas:123/#ads&&sad" }),
            .formatEscaped,
        )},
    );
}

test "URI percent decoding" {
    {
        const expected = "\\ö/ äöß ~~.adas-https://canvas:123/#ads&&sad";
        var input = "%5C%C3%B6%2F%20%C3%A4%C3%B6%C3%9F%20~~.adas-https%3A%2F%2Fcanvas%3A123%2F%23ads%26%26sad".*;

        try std.testing.expectFmt(expected, "{f}", .{std.fmt.alt(
            @as(Component, .{ .percent_encoded = &input }),
            .formatRaw,
        )});

        var output: [expected.len]u8 = undefined;
        try std.testing.expectEqualStrings(percentDecodeBackwards(&output, &input), expected);

        try std.testing.expectEqualStrings(expected, percentDecodeInPlace(&input));
    }

    {
        const expected = "/abc%";
        var input = expected.*;

        try std.testing.expectFmt(expected, "{f}", .{std.fmt.alt(
            @as(Component, .{ .percent_encoded = &input }),
            .formatRaw,
        )});

        var output: [expected.len]u8 = undefined;
        try std.testing.expectEqualStrings(percentDecodeBackwards(&output, &input), expected);

        try std.testing.expectEqualStrings(expected, percentDecodeInPlace(&input));
    }
}

test "URI query encoding" {
    const address = "https://objects.githubusercontent.com/?response-content-type=application%2Foctet-stream";
    const parsed = try Uri.parse(address);

    // format the URI to percent encode it
    try std.testing.expectFmt("/?response-content-type=application%2Foctet-stream", "{f}", .{
        parsed.fmt(.{ .path = true, .query = true }),
    });
}

test "format" {
    const uri: Uri = .{
        .scheme = "file",
        .user = null,
        .password = null,
        .host = null,
        .port = null,
        .path = .{ .raw = "/foo/bar/baz" },
        .query = null,
        .fragment = null,
    };
    try std.testing.expectFmt("file:/foo/bar/baz", "{f}", .{
        uri.fmt(.{ .scheme = true, .path = true, .query = true, .fragment = true }),
    });
}

test "URI malformed input" {
    try std.testing.expectError(error.InvalidFormat, std.Uri.parse("http://]["));
    try std.testing.expectError(error.InvalidFormat, std.Uri.parse("http://]@["));
    try std.testing.expectError(error.InvalidFormat, std.Uri.parse("http://lo]s\x85hc@[/8\x10?0Q"));
}
