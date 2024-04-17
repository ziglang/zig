//! Uniform Resource Identifier (URI) parsing roughly adhering to <https://tools.ietf.org/html/rfc3986>.
//! Does not do perfect grammar and character class checking, but should be robust against URIs in the wild.

scheme: []const u8,
user: ?Component = null,
password: ?Component = null,
host: ?Component = null,
port: ?u16 = null,
path: Component = Component.empty,
query: ?Component = null,
fragment: ?Component = null,

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

    /// Allocates the result with `arena` only if needed, so the result should not be freed.
    pub fn toRawMaybeAlloc(
        component: Component,
        arena: std.mem.Allocator,
    ) std.mem.Allocator.Error![]const u8 {
        return switch (component) {
            .raw => |raw| raw,
            .percent_encoded => |percent_encoded| if (std.mem.indexOfScalar(u8, percent_encoded, '%')) |_|
                try std.fmt.allocPrint(arena, "{raw}", .{component})
            else
                percent_encoded,
        };
    }

    pub fn format(
        component: Component,
        comptime fmt_str: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (fmt_str.len == 0) {
            try writer.print("std.Uri.Component{{ .{s} = \"{}\" }}", .{
                @tagName(component),
                std.zig.fmtEscapes(switch (component) {
                    .raw, .percent_encoded => |string| string,
                }),
            });
        } else if (comptime std.mem.eql(u8, fmt_str, "raw")) switch (component) {
            .raw => |raw| try writer.writeAll(raw),
            .percent_encoded => |percent_encoded| {
                var start: usize = 0;
                var index: usize = 0;
                while (std.mem.indexOfScalarPos(u8, percent_encoded, index, '%')) |percent| {
                    index = percent + 1;
                    if (percent_encoded.len - index < 2) continue;
                    const percent_encoded_char =
                        std.fmt.parseInt(u8, percent_encoded[index..][0..2], 16) catch continue;
                    try writer.print("{s}{c}", .{
                        percent_encoded[start..percent],
                        percent_encoded_char,
                    });
                    start = percent + 3;
                    index = percent + 3;
                }
                try writer.writeAll(percent_encoded[start..]);
            },
        } else if (comptime std.mem.eql(u8, fmt_str, "%")) switch (component) {
            .raw => |raw| try percentEncode(writer, raw, isUnreserved),
            .percent_encoded => |percent_encoded| try writer.writeAll(percent_encoded),
        } else if (comptime std.mem.eql(u8, fmt_str, "user")) switch (component) {
            .raw => |raw| try percentEncode(writer, raw, isUserChar),
            .percent_encoded => |percent_encoded| try writer.writeAll(percent_encoded),
        } else if (comptime std.mem.eql(u8, fmt_str, "password")) switch (component) {
            .raw => |raw| try percentEncode(writer, raw, isPasswordChar),
            .percent_encoded => |percent_encoded| try writer.writeAll(percent_encoded),
        } else if (comptime std.mem.eql(u8, fmt_str, "host")) switch (component) {
            .raw => |raw| try percentEncode(writer, raw, isHostChar),
            .percent_encoded => |percent_encoded| try writer.writeAll(percent_encoded),
        } else if (comptime std.mem.eql(u8, fmt_str, "path")) switch (component) {
            .raw => |raw| try percentEncode(writer, raw, isPathChar),
            .percent_encoded => |percent_encoded| try writer.writeAll(percent_encoded),
        } else if (comptime std.mem.eql(u8, fmt_str, "query")) switch (component) {
            .raw => |raw| try percentEncode(writer, raw, isQueryChar),
            .percent_encoded => |percent_encoded| try writer.writeAll(percent_encoded),
        } else if (comptime std.mem.eql(u8, fmt_str, "fragment")) switch (component) {
            .raw => |raw| try percentEncode(writer, raw, isFragmentChar),
            .percent_encoded => |percent_encoded| try writer.writeAll(percent_encoded),
        } else @compileError("invalid format string '" ++ fmt_str ++ "'");
    }

    pub fn percentEncode(
        writer: anytype,
        raw: []const u8,
        comptime isValidChar: fn (u8) bool,
    ) @TypeOf(writer).Error!void {
        var start: usize = 0;
        for (raw, 0..) |char, index| {
            if (isValidChar(char)) continue;
            try writer.print("{s}%{X:0>2}", .{ raw[start..index], char });
            start = index + 1;
        }
        try writer.writeAll(raw[start..]);
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
    var reader = SliceReader{ .slice = text };

    var uri: Uri = .{ .scheme = scheme, .path = undefined };

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

    uri.path = .{ .percent_encoded = reader.readUntil(isPathSeparator) };

    if ((reader.peek() orelse 0) == '?') { // query part
        std.debug.assert(reader.get().? == '?');
        uri.query = .{ .percent_encoded = reader.readUntil(isQuerySeparator) };
    }

    if ((reader.peek() orelse 0) == '#') { // fragment part
        std.debug.assert(reader.get().? == '#');
        uri.fragment = .{ .percent_encoded = reader.readUntilEof() };
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

    /// When true, include the port part of the URI. Ignored when `port` is null.
    port: bool = true,
};

pub fn writeToStream(
    uri: Uri,
    options: WriteToStreamOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    if (options.scheme) {
        try writer.print("{s}:", .{uri.scheme});
        if (options.authority and uri.host != null) {
            try writer.writeAll("//");
        }
    }
    if (options.authority) {
        if (options.authentication and uri.host != null) {
            if (uri.user) |user| {
                try writer.print("{user}", .{user});
                if (uri.password) |password| {
                    try writer.print(":{password}", .{password});
                }
                try writer.writeByte('@');
            }
        }
        if (uri.host) |host| {
            try writer.print("{host}", .{host});
            if (options.port) {
                if (uri.port) |port| try writer.print(":{d}", .{port});
            }
        }
    }
    if (options.path) {
        try writer.print("{path}", .{
            if (uri.path.isEmpty()) Uri.Component{ .percent_encoded = "/" } else uri.path,
        });
        if (options.query) {
            if (uri.query) |query| try writer.print("?{query}", .{query});
        }
        if (options.fragment) {
            if (uri.fragment) |fragment| try writer.print("#{fragment}", .{fragment});
        }
    }
}

pub fn format(
    uri: Uri,
    comptime fmt_str: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    const scheme = comptime std.mem.indexOfScalar(u8, fmt_str, ';') != null or fmt_str.len == 0;
    const authentication = comptime std.mem.indexOfScalar(u8, fmt_str, '@') != null or fmt_str.len == 0;
    const authority = comptime std.mem.indexOfScalar(u8, fmt_str, '+') != null or fmt_str.len == 0;
    const path = comptime std.mem.indexOfScalar(u8, fmt_str, '/') != null or fmt_str.len == 0;
    const query = comptime std.mem.indexOfScalar(u8, fmt_str, '?') != null or fmt_str.len == 0;
    const fragment = comptime std.mem.indexOfScalar(u8, fmt_str, '#') != null or fmt_str.len == 0;

    return writeToStream(uri, .{
        .scheme = scheme,
        .authentication = authentication,
        .authority = authority,
        .path = path,
        .query = query,
        .fragment = fragment,
    }, writer);
}

/// Parses the URI or returns an error.
/// The return value will contain strings pointing into the
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

    return parseAfterScheme(scheme, reader.readUntilEof());
}

pub const ResolveInPlaceError = ParseError || error{NoSpaceLeft};

/// Resolves a URI against a base URI, conforming to RFC 3986, Section 5.
/// Copies `new` to the beginning of `aux_buf.*`, allowing the slices to overlap,
/// then parses `new` as a URI, and then resolves the path in place.
/// If a merge needs to take place, the newly constructed path will be stored
/// in `aux_buf.*` just after the copied `new`, and `aux_buf.*` will be modified
/// to only contain the remaining unused space.
pub fn resolve_inplace(base: Uri, new: []const u8, aux_buf: *[]u8) ResolveInPlaceError!Uri {
    std.mem.copyForwards(u8, aux_buf.*, new);
    // At this point, new is an invalid pointer.
    const new_mut = aux_buf.*[0..new.len];
    aux_buf.* = aux_buf.*[new.len..];

    const new_parsed = parse(new_mut) catch |err|
        (parseAfterScheme("", new_mut) catch return err);
    // As you can see above, `new_mut` is not a const pointer.
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
    var aux = std.io.fixedBufferStream(aux_buf.*);
    if (!base.isEmpty()) {
        try aux.writer().print("{path}", .{base});
        aux.pos = std.mem.lastIndexOfScalar(u8, aux.getWritten(), '/') orelse
            return remove_dot_segments(new);
    }
    try aux.writer().print("/{s}", .{new});
    const merged_path = remove_dot_segments(aux.getWritten());
    aux_buf.* = aux_buf.*[merged_path.percent_encoded.len..];
    return merged_path;
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

fn isAuthoritySeparator(c: u8) bool {
    return switch (c) {
        '/', '?', '#' => true,
        else => false,
    };
}

fn isPathSeparator(c: u8) bool {
    return switch (c) {
        '?', '#' => true,
        else => false,
    };
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
        "{%}",
        .{Component{ .raw = "\\ö/ äöß ~~.adas-https://canvas:123/#ads&&sad" }},
    );
}

test "URI percent decoding" {
    {
        const expected = "\\ö/ äöß ~~.adas-https://canvas:123/#ads&&sad";
        var input = "%5C%C3%B6%2F%20%C3%A4%C3%B6%C3%9F%20~~.adas-https%3A%2F%2Fcanvas%3A123%2F%23ads%26%26sad".*;

        try std.testing.expectFmt(expected, "{raw}", .{Component{ .percent_encoded = &input }});

        var output: [expected.len]u8 = undefined;
        try std.testing.expectEqualStrings(percentDecodeBackwards(&output, &input), expected);

        try std.testing.expectEqualStrings(expected, percentDecodeInPlace(&input));
    }

    {
        const expected = "/abc%";
        var input = expected.*;

        try std.testing.expectFmt(expected, "{raw}", .{Component{ .percent_encoded = &input }});

        var output: [expected.len]u8 = undefined;
        try std.testing.expectEqualStrings(percentDecodeBackwards(&output, &input), expected);

        try std.testing.expectEqualStrings(expected, percentDecodeInPlace(&input));
    }
}

test "URI query encoding" {
    const address = "https://objects.githubusercontent.com/?response-content-type=application%2Foctet-stream";
    const parsed = try Uri.parse(address);

    // format the URI to percent encode it
    try std.testing.expectFmt("/?response-content-type=application%2Foctet-stream", "{/?}", .{parsed});
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
    try std.testing.expectFmt("file:/foo/bar/baz", "{;/?#}", .{uri});
}

test "URI malformed input" {
    try std.testing.expectError(error.InvalidFormat, std.Uri.parse("http://]["));
    try std.testing.expectError(error.InvalidFormat, std.Uri.parse("http://]@["));
    try std.testing.expectError(error.InvalidFormat, std.Uri.parse("http://lo]s\x85hc@[/8\x10?0Q"));
}

const std = @import("std.zig");
const testing = std.testing;
const Uri = @This();
