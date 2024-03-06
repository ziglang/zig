//! Uniform Resource Identifier (URI) parsing roughly adhering to <https://tools.ietf.org/html/rfc3986>.
//! Does not do perfect grammar and character class checking, but should be robust against URIs in the wild.

const Uri = @This();
const std = @import("std.zig");
const testing = std.testing;
const Allocator = std.mem.Allocator;

scheme: []const u8,
user: ?[]const u8 = null,
password: ?[]const u8 = null,
host: ?[]const u8 = null,
port: ?u16 = null,
path: []const u8,
query: ?[]const u8 = null,
fragment: ?[]const u8 = null,

/// Applies URI encoding and replaces all reserved characters with their respective %XX code.
pub fn escapeString(allocator: Allocator, input: []const u8) error{OutOfMemory}![]u8 {
    return escapeStringWithFn(allocator, input, isUnreserved);
}

pub fn escapePath(allocator: Allocator, input: []const u8) error{OutOfMemory}![]u8 {
    return escapeStringWithFn(allocator, input, isPathChar);
}

pub fn escapeQuery(allocator: Allocator, input: []const u8) error{OutOfMemory}![]u8 {
    return escapeStringWithFn(allocator, input, isQueryChar);
}

pub fn writeEscapedString(writer: anytype, input: []const u8) !void {
    return writeEscapedStringWithFn(writer, input, isUnreserved);
}

pub fn writeEscapedPath(writer: anytype, input: []const u8) !void {
    return writeEscapedStringWithFn(writer, input, isPathChar);
}

pub fn writeEscapedQuery(writer: anytype, input: []const u8) !void {
    return writeEscapedStringWithFn(writer, input, isQueryChar);
}

pub fn escapeStringWithFn(allocator: Allocator, input: []const u8, comptime keepUnescaped: fn (c: u8) bool) Allocator.Error![]u8 {
    var outsize: usize = 0;
    for (input) |c| {
        outsize += if (keepUnescaped(c)) @as(usize, 1) else 3;
    }
    var output = try allocator.alloc(u8, outsize);
    var outptr: usize = 0;

    for (input) |c| {
        if (keepUnescaped(c)) {
            output[outptr] = c;
            outptr += 1;
        } else {
            var buf: [2]u8 = undefined;
            _ = std.fmt.bufPrint(&buf, "{X:0>2}", .{c}) catch unreachable;

            output[outptr + 0] = '%';
            output[outptr + 1] = buf[0];
            output[outptr + 2] = buf[1];
            outptr += 3;
        }
    }
    return output;
}

pub fn writeEscapedStringWithFn(writer: anytype, input: []const u8, comptime keepUnescaped: fn (c: u8) bool) @TypeOf(writer).Error!void {
    for (input) |c| {
        if (keepUnescaped(c)) {
            try writer.writeByte(c);
        } else {
            try writer.print("%{X:0>2}", .{c});
        }
    }
}

/// Parses a URI string and unescapes all %XX where XX is a valid hex number. Otherwise, verbatim copies
/// them to the output.
pub fn unescapeString(allocator: Allocator, input: []const u8) error{OutOfMemory}![]u8 {
    var outsize: usize = 0;
    var inptr: usize = 0;
    while (inptr < input.len) {
        if (input[inptr] == '%') {
            inptr += 1;
            if (inptr + 2 <= input.len) {
                _ = std.fmt.parseInt(u8, input[inptr..][0..2], 16) catch {
                    outsize += 3;
                    inptr += 2;
                    continue;
                };
                inptr += 2;
                outsize += 1;
            } else {
                outsize += 1;
            }
        } else {
            inptr += 1;
            outsize += 1;
        }
    }

    var output = try allocator.alloc(u8, outsize);
    var outptr: usize = 0;
    inptr = 0;
    while (inptr < input.len) {
        if (input[inptr] == '%') {
            inptr += 1;
            if (inptr + 2 <= input.len) {
                const value = std.fmt.parseInt(u8, input[inptr..][0..2], 16) catch {
                    output[outptr + 0] = input[inptr + 0];
                    output[outptr + 1] = input[inptr + 1];
                    inptr += 2;
                    outptr += 2;
                    continue;
                };

                output[outptr] = value;

                inptr += 2;
                outptr += 1;
            } else {
                output[outptr] = input[inptr - 1];
                outptr += 1;
            }
        } else {
            output[outptr] = input[inptr];
            inptr += 1;
            outptr += 1;
        }
    }
    return output;
}

pub const ParseError = error{ UnexpectedCharacter, InvalidFormat, InvalidPort };

/// Parses the URI or returns an error. This function is not compliant, but is required to parse
/// some forms of URIs in the wild, such as HTTP Location headers.
/// The return value will contain unescaped strings pointing into the
/// original `text`. Each component that is provided, will be non-`null`.
pub fn parseWithoutScheme(text: []const u8) ParseError!Uri {
    var reader = SliceReader{ .slice = text };

    var uri = Uri{
        .scheme = "",
        .user = null,
        .password = null,
        .host = null,
        .port = null,
        .path = "", // path is always set, but empty by default.
        .query = null,
        .fragment = null,
    };

    if (reader.peekPrefix("//")) a: { // authority part
        std.debug.assert(reader.get().? == '/');
        std.debug.assert(reader.get().? == '/');

        const authority = reader.readUntil(isAuthoritySeparator);
        if (authority.len == 0) {
            if (reader.peekPrefix("/")) break :a else return error.InvalidFormat;
        }

        var start_of_host: usize = 0;
        if (std.mem.indexOf(u8, authority, "@")) |index| {
            start_of_host = index + 1;
            const user_info = authority[0..index];

            if (std.mem.indexOf(u8, user_info, ":")) |idx| {
                uri.user = user_info[0..idx];
                if (idx < user_info.len - 1) { // empty password is also "no password"
                    uri.password = user_info[idx + 1 ..];
                }
            } else {
                uri.user = user_info;
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
        uri.host = authority[start_of_host..end_of_host];
    }

    uri.path = reader.readUntil(isPathSeparator);

    if ((reader.peek() orelse 0) == '?') { // query part
        std.debug.assert(reader.get().? == '?');
        uri.query = reader.readUntil(isQuerySeparator);
    }

    if ((reader.peek() orelse 0) == '#') { // fragment part
        std.debug.assert(reader.get().? == '#');
        uri.fragment = reader.readUntilEof();
    }

    return uri;
}

pub const WriteToStreamOptions = struct {
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

    /// When true, do not escape any part of the URI.
    raw: bool = false,
};

pub fn writeToStream(
    uri: Uri,
    options: WriteToStreamOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    if (options.scheme) {
        try writer.writeAll(uri.scheme);
        try writer.writeAll(":");

        if (options.authority and uri.host != null) {
            try writer.writeAll("//");
        }
    }

    if (options.authority) {
        if (options.authentication and uri.host != null) {
            if (uri.user) |user| {
                try writer.writeAll(user);
                if (uri.password) |password| {
                    try writer.writeAll(":");
                    try writer.writeAll(password);
                }
                try writer.writeAll("@");
            }
        }

        if (uri.host) |host| {
            try writer.writeAll(host);

            if (uri.port) |port| {
                try writer.writeAll(":");
                try std.fmt.formatInt(port, 10, .lower, .{}, writer);
            }
        }
    }

    if (options.path) {
        if (uri.path.len == 0) {
            try writer.writeAll("/");
        } else if (options.raw) {
            try writer.writeAll(uri.path);
        } else {
            try writeEscapedPath(writer, uri.path);
        }

        if (options.query) if (uri.query) |q| {
            try writer.writeAll("?");
            if (options.raw) {
                try writer.writeAll(q);
            } else {
                try writeEscapedQuery(writer, q);
            }
        };

        if (options.fragment) if (uri.fragment) |f| {
            try writer.writeAll("#");
            if (options.raw) {
                try writer.writeAll(f);
            } else {
                try writeEscapedQuery(writer, f);
            }
        };
    }
}

pub fn format(
    uri: Uri,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    _ = options;

    const scheme = comptime std.mem.indexOf(u8, fmt, ";") != null or fmt.len == 0;
    const authentication = comptime std.mem.indexOf(u8, fmt, "@") != null or fmt.len == 0;
    const authority = comptime std.mem.indexOf(u8, fmt, "+") != null or fmt.len == 0;
    const path = comptime std.mem.indexOf(u8, fmt, "/") != null or fmt.len == 0;
    const query = comptime std.mem.indexOf(u8, fmt, "?") != null or fmt.len == 0;
    const fragment = comptime std.mem.indexOf(u8, fmt, "#") != null or fmt.len == 0;
    const raw = comptime std.mem.indexOf(u8, fmt, "r") != null or fmt.len == 0;

    return writeToStream(uri, .{
        .scheme = scheme,
        .authentication = authentication,
        .authority = authority,
        .path = path,
        .query = query,
        .fragment = fragment,
        .raw = raw,
    }, writer);
}

/// Parses the URI or returns an error.
/// The return value will contain unescaped strings pointing into the
/// original `text`. Each component that is provided, will be non-`null`.
pub fn parse(text: []const u8) ParseError!Uri {
    var reader: SliceReader = .{ .slice = text };
    const scheme = reader.readWhile(isSchemeChar);

    // after the scheme, a ':' must appear
    if (reader.get()) |c| {
        if (c != ':')
            return error.UnexpectedCharacter;
    } else {
        return error.InvalidFormat;
    }

    var uri = try parseWithoutScheme(reader.readUntilEof());
    uri.scheme = scheme;

    return uri;
}

pub const ResolveInplaceError = ParseError || error{OutOfMemory};

/// Resolves a URI against a base URI, conforming to RFC 3986, Section 5.
/// Copies `new` to the beginning of `aux_buf`, allowing the slices to overlap,
/// then parses `new` as a URI, and then resolves the path in place.
/// If a merge needs to take place, the newly constructed path will be stored
/// in `aux_buf` just after the copied `new`.
pub fn resolve_inplace(base: Uri, new: []const u8, aux_buf: []u8) ResolveInplaceError!Uri {
    std.mem.copyForwards(u8, aux_buf, new);
    // At this point, new is an invalid pointer.
    const new_mut = aux_buf[0..new.len];

    const new_parsed, const has_scheme = p: {
        break :p .{
            parse(new_mut) catch |first_err| {
                break :p .{
                    parseWithoutScheme(new_mut) catch return first_err,
                    false,
                };
            },
            true,
        };
    };

    // As you can see above, `new_mut` is not a const pointer.
    const new_path: []u8 = @constCast(new_parsed.path);

    if (has_scheme) return .{
        .scheme = new_parsed.scheme,
        .user = new_parsed.user,
        .host = new_parsed.host,
        .port = new_parsed.port,
        .path = remove_dot_segments(new_path),
        .query = new_parsed.query,
        .fragment = new_parsed.fragment,
    };

    if (new_parsed.host) |host| return .{
        .scheme = base.scheme,
        .user = new_parsed.user,
        .host = host,
        .port = new_parsed.port,
        .path = remove_dot_segments(new_path),
        .query = new_parsed.query,
        .fragment = new_parsed.fragment,
    };

    const path, const query = b: {
        if (new_path.len == 0)
            break :b .{
                base.path,
                new_parsed.query orelse base.query,
            };

        if (new_path[0] == '/')
            break :b .{
                remove_dot_segments(new_path),
                new_parsed.query,
            };

        break :b .{
            try merge_paths(base.path, new_path, aux_buf[new_mut.len..]),
            new_parsed.query,
        };
    };

    return .{
        .scheme = base.scheme,
        .user = base.user,
        .host = base.host,
        .port = base.port,
        .path = path,
        .query = query,
        .fragment = new_parsed.fragment,
    };
}

/// In-place implementation of RFC 3986, Section 5.2.4.
fn remove_dot_segments(path: []u8) []u8 {
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
    return path[0..out_i];
}

test remove_dot_segments {
    {
        var buffer = "/a/b/c/./../../g".*;
        try std.testing.expectEqualStrings("/a/g", remove_dot_segments(&buffer));
    }
}

/// 5.2.3. Merge Paths
fn merge_paths(base: []const u8, new: []u8, aux: []u8) error{OutOfMemory}![]u8 {
    if (aux.len < base.len + 1 + new.len) return error.OutOfMemory;
    if (base.len == 0) {
        aux[0] = '/';
        @memcpy(aux[1..][0..new.len], new);
        return remove_dot_segments(aux[0 .. new.len + 1]);
    }
    const pos = std.mem.lastIndexOfScalar(u8, base, '/') orelse return remove_dot_segments(new);
    @memcpy(aux[0 .. pos + 1], base[0 .. pos + 1]);
    @memcpy(aux[pos + 1 ..][0..new.len], new);
    return remove_dot_segments(aux[0 .. pos + 1 + new.len]);
}

const SliceReader = struct {
    const Self = @This();

    slice: []const u8,
    offset: usize = 0,

    fn get(self: *Self) ?u8 {
        if (self.offset >= self.slice.len)
            return null;
        const c = self.slice[self.offset];
        self.offset += 1;
        return c;
    }

    fn peek(self: Self) ?u8 {
        if (self.offset >= self.slice.len)
            return null;
        return self.slice[self.offset];
    }

    fn readWhile(self: *Self, comptime predicate: fn (u8) bool) []const u8 {
        const start = self.offset;
        var end = start;
        while (end < self.slice.len and predicate(self.slice[end])) {
            end += 1;
        }
        self.offset = end;
        return self.slice[start..end];
    }

    fn readUntil(self: *Self, comptime predicate: fn (u8) bool) []const u8 {
        const start = self.offset;
        var end = start;
        while (end < self.slice.len and !predicate(self.slice[end])) {
            end += 1;
        }
        self.offset = end;
        return self.slice[start..end];
    }

    fn readUntilEof(self: *Self) []const u8 {
        const start = self.offset;
        self.offset = self.slice.len;
        return self.slice[start..];
    }

    fn peekPrefix(self: Self, prefix: []const u8) bool {
        if (self.offset + prefix.len > self.slice.len)
            return false;
        return std.mem.eql(u8, self.slice[self.offset..][0..prefix.len], prefix);
    }
};

/// scheme      = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
fn isSchemeChar(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '+', '-', '.' => true,
        else => false,
    };
}

fn isAuthoritySeparator(c: u8) bool {
    return switch (c) {
        '/', '?', '#' => true,
        else => false,
    };
}

/// reserved    = gen-delims / sub-delims
fn isReserved(c: u8) bool {
    return isGenLimit(c) or isSubLimit(c);
}

/// gen-delims  = ":" / "/" / "?" / "#" / "[" / "]" / "@"
fn isGenLimit(c: u8) bool {
    return switch (c) {
        ':', ',', '?', '#', '[', ']', '@' => true,
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

fn isPathSeparator(c: u8) bool {
    return switch (c) {
        '?', '#' => true,
        else => false,
    };
}

fn isPathChar(c: u8) bool {
    return isUnreserved(c) or isSubLimit(c) or c == '/' or c == ':' or c == '@';
}

fn isQueryChar(c: u8) bool {
    return isPathChar(c) or c == '?' or c == '%';
}

fn isQuerySeparator(c: u8) bool {
    return switch (c) {
        '#' => true,
        else => false,
    };
}

test "basic" {
    const parsed = try parse("https://ziglang.org/download");
    try testing.expectEqualStrings("https", parsed.scheme);
    try testing.expectEqualStrings("ziglang.org", parsed.host orelse return error.UnexpectedNull);
    try testing.expectEqualStrings("/download", parsed.path);
    try testing.expectEqual(@as(?u16, null), parsed.port);
}

test "with port" {
    const parsed = try parse("http://example:1337/");
    try testing.expectEqualStrings("http", parsed.scheme);
    try testing.expectEqualStrings("example", parsed.host orelse return error.UnexpectedNull);
    try testing.expectEqualStrings("/", parsed.path);
    try testing.expectEqual(@as(?u16, 1337), parsed.port);
}

test "should fail gracefully" {
    try std.testing.expectEqual(@as(ParseError!Uri, error.InvalidFormat), parse("foobar://"));
}

test "file" {
    const parsed = try parse("file:///");
    try std.testing.expectEqualSlices(u8, "file", parsed.scheme);
    try std.testing.expectEqual(@as(?[]const u8, null), parsed.host);
    try std.testing.expectEqualSlices(u8, "/", parsed.path);

    const parsed2 = try parse("file:///an/absolute/path/to/something");
    try std.testing.expectEqualSlices(u8, "file", parsed2.scheme);
    try std.testing.expectEqual(@as(?[]const u8, null), parsed2.host);
    try std.testing.expectEqualSlices(u8, "/an/absolute/path/to/something", parsed2.path);

    const parsed3 = try parse("file://localhost/an/absolute/path/to/another/thing/");
    try std.testing.expectEqualSlices(u8, "file", parsed3.scheme);
    try std.testing.expectEqualSlices(u8, "localhost", parsed3.host.?);
    try std.testing.expectEqualSlices(u8, "/an/absolute/path/to/another/thing/", parsed3.path);
}

test "scheme" {
    try std.testing.expectEqualSlices(u8, "http", (try parse("http:_")).scheme);
    try std.testing.expectEqualSlices(u8, "scheme-mee", (try parse("scheme-mee:_")).scheme);
    try std.testing.expectEqualSlices(u8, "a.b.c", (try parse("a.b.c:_")).scheme);
    try std.testing.expectEqualSlices(u8, "ab+", (try parse("ab+:_")).scheme);
    try std.testing.expectEqualSlices(u8, "X+++", (try parse("X+++:_")).scheme);
    try std.testing.expectEqualSlices(u8, "Y+-.", (try parse("Y+-.:_")).scheme);
}

test "authority" {
    try std.testing.expectEqualSlices(u8, "hostname", (try parse("scheme://hostname")).host.?);

    try std.testing.expectEqualSlices(u8, "hostname", (try parse("scheme://userinfo@hostname")).host.?);
    try std.testing.expectEqualSlices(u8, "userinfo", (try parse("scheme://userinfo@hostname")).user.?);
    try std.testing.expectEqual(@as(?[]const u8, null), (try parse("scheme://userinfo@hostname")).password);
    try std.testing.expectEqual(@as(?[]const u8, null), (try parse("scheme://userinfo@")).host);

    try std.testing.expectEqualSlices(u8, "hostname", (try parse("scheme://user:password@hostname")).host.?);
    try std.testing.expectEqualSlices(u8, "user", (try parse("scheme://user:password@hostname")).user.?);
    try std.testing.expectEqualSlices(u8, "password", (try parse("scheme://user:password@hostname")).password.?);

    try std.testing.expectEqualSlices(u8, "hostname", (try parse("scheme://hostname:0")).host.?);
    try std.testing.expectEqual(@as(u16, 1234), (try parse("scheme://hostname:1234")).port.?);

    try std.testing.expectEqualSlices(u8, "hostname", (try parse("scheme://userinfo@hostname:1234")).host.?);
    try std.testing.expectEqual(@as(u16, 1234), (try parse("scheme://userinfo@hostname:1234")).port.?);
    try std.testing.expectEqualSlices(u8, "userinfo", (try parse("scheme://userinfo@hostname:1234")).user.?);
    try std.testing.expectEqual(@as(?[]const u8, null), (try parse("scheme://userinfo@hostname:1234")).password);

    try std.testing.expectEqualSlices(u8, "hostname", (try parse("scheme://user:password@hostname:1234")).host.?);
    try std.testing.expectEqual(@as(u16, 1234), (try parse("scheme://user:password@hostname:1234")).port.?);
    try std.testing.expectEqualSlices(u8, "user", (try parse("scheme://user:password@hostname:1234")).user.?);
    try std.testing.expectEqualSlices(u8, "password", (try parse("scheme://user:password@hostname:1234")).password.?);
}

test "authority.password" {
    try std.testing.expectEqualSlices(u8, "username", (try parse("scheme://username@a")).user.?);
    try std.testing.expectEqual(@as(?[]const u8, null), (try parse("scheme://username@a")).password);

    try std.testing.expectEqualSlices(u8, "username", (try parse("scheme://username:@a")).user.?);
    try std.testing.expectEqual(@as(?[]const u8, null), (try parse("scheme://username:@a")).password);

    try std.testing.expectEqualSlices(u8, "username", (try parse("scheme://username:password@a")).user.?);
    try std.testing.expectEqualSlices(u8, "password", (try parse("scheme://username:password@a")).password.?);

    try std.testing.expectEqualSlices(u8, "username", (try parse("scheme://username::@a")).user.?);
    try std.testing.expectEqualSlices(u8, ":", (try parse("scheme://username::@a")).password.?);
}

fn testAuthorityHost(comptime hostlist: anytype) !void {
    inline for (hostlist) |hostname| {
        try std.testing.expectEqualSlices(u8, hostname, (try parse("scheme://" ++ hostname)).host.?);
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
        .host = uri[6..17],
        .port = 8042,
        .path = uri[22..33],
        .query = uri[34..45],
        .fragment = uri[46..50],
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
        .path = uri[4..],
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

test "URI escaping" {
    const input = "\\ö/ äöß ~~.adas-https://canvas:123/#ads&&sad";
    const expected = "%5C%C3%B6%2F%20%C3%A4%C3%B6%C3%9F%20~~.adas-https%3A%2F%2Fcanvas%3A123%2F%23ads%26%26sad";

    const actual = try escapeString(std.testing.allocator, input);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "URI unescaping" {
    const input = "%5C%C3%B6%2F%20%C3%A4%C3%B6%C3%9F%20~~.adas-https%3A%2F%2Fcanvas%3A123%2F%23ads%26%26sad";
    const expected = "\\ö/ äöß ~~.adas-https://canvas:123/#ads&&sad";

    const actual = try unescapeString(std.testing.allocator, input);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualSlices(u8, expected, actual);

    const decoded = try unescapeString(std.testing.allocator, "/abc%");
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualStrings("/abc%", decoded);
}

test "URI query escaping" {
    const address = "https://objects.githubusercontent.com/?response-content-type=application%2Foctet-stream";
    const parsed = try Uri.parse(address);

    // format the URI to escape it
    const formatted_uri = try std.fmt.allocPrint(std.testing.allocator, "{/?}", .{parsed});
    defer std.testing.allocator.free(formatted_uri);
    try std.testing.expectEqualStrings("/?response-content-type=application%2Foctet-stream", formatted_uri);
}

test "format" {
    const uri = Uri{
        .scheme = "file",
        .user = null,
        .password = null,
        .host = null,
        .port = null,
        .path = "/foo/bar/baz",
        .query = null,
        .fragment = null,
    };
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    try buf.writer().print("{;/?#}", .{uri});
    try std.testing.expectEqualSlices(u8, "file:/foo/bar/baz", buf.items);
}

test "URI malformed input" {
    try std.testing.expectError(error.InvalidFormat, std.Uri.parse("http://]["));
    try std.testing.expectError(error.InvalidFormat, std.Uri.parse("http://]@["));
    try std.testing.expectError(error.InvalidFormat, std.Uri.parse("http://lo]s\x85hc@[/8\x10?0Q"));
}
