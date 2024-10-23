const Manifest = @This();
const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Ast = std.zig.Ast;
const testing = std.testing;
const hex_charset = std.fmt.hex_charset;

pub const max_bytes = 10 * 1024 * 1024;
pub const basename = "build.zig.zon";
pub const Hash = std.crypto.hash.sha2.Sha256;
pub const Digest = [Hash.digest_length]u8;
pub const multihash_len = 1 + 1 + Hash.digest_length;
pub const multihash_hex_digest_len = 2 * multihash_len;
pub const MultiHashHexDigest = [multihash_hex_digest_len]u8;

pub const Dependency = struct {
    location: Location,
    location_tok: Ast.TokenIndex,
    location_node: Ast.Node.Index,
    hash: ?[]const u8,
    hash_tok: Ast.TokenIndex,
    hash_node: Ast.Node.Index,
    node: Ast.Node.Index,
    name_tok: Ast.TokenIndex,
    lazy: bool,

    pub const Location = union(enum) {
        url: []const u8,
        path: []const u8,
    };
};

pub const ErrorMessage = struct {
    msg: []const u8,
    tok: Ast.TokenIndex,
    off: u32,
};

pub const MultihashFunction = enum(u16) {
    identity = 0x00,
    sha1 = 0x11,
    @"sha2-256" = 0x12,
    @"sha2-512" = 0x13,
    @"sha3-512" = 0x14,
    @"sha3-384" = 0x15,
    @"sha3-256" = 0x16,
    @"sha3-224" = 0x17,
    @"sha2-384" = 0x20,
    @"sha2-256-trunc254-padded" = 0x1012,
    @"sha2-224" = 0x1013,
    @"sha2-512-224" = 0x1014,
    @"sha2-512-256" = 0x1015,
    @"blake2b-256" = 0xb220,
    _,
};

pub const multihash_function: MultihashFunction = switch (Hash) {
    std.crypto.hash.sha2.Sha256 => .@"sha2-256",
    else => @compileError("unreachable"),
};
comptime {
    // We avoid unnecessary uleb128 code in hexDigest by asserting here the
    // values are small enough to be contained in the one-byte encoding.
    assert(@intFromEnum(multihash_function) < 127);
    assert(Hash.digest_length < 127);
}

name: []const u8,
version: std.SemanticVersion,
version_node: Ast.Node.Index,
dependencies: std.StringArrayHashMapUnmanaged(Dependency),
dependencies_node: Ast.Node.Index,
paths: std.StringArrayHashMapUnmanaged(void),
minimum_zig_version: ?std.SemanticVersion,

errors: []ErrorMessage,
arena_state: std.heap.ArenaAllocator.State,

pub const ParseOptions = struct {
    allow_missing_paths_field: bool = false,
};

pub const Error = Allocator.Error;

pub fn parse(gpa: Allocator, ast: Ast, options: ParseOptions) Error!Manifest {
    const node_tags = ast.nodes.items(.tag);
    const node_datas = ast.nodes.items(.data);
    assert(node_tags[0] == .root);
    const main_node_index = node_datas[0].lhs;

    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    errdefer arena_instance.deinit();

    var p: Parse = .{
        .gpa = gpa,
        .ast = ast,
        .arena = arena_instance.allocator(),
        .errors = .{},

        .name = undefined,
        .version = undefined,
        .version_node = 0,
        .dependencies = .{},
        .dependencies_node = 0,
        .paths = .{},
        .allow_missing_paths_field = options.allow_missing_paths_field,
        .minimum_zig_version = null,
        .buf = .{},
    };
    defer p.buf.deinit(gpa);
    defer p.errors.deinit(gpa);
    defer p.dependencies.deinit(gpa);
    defer p.paths.deinit(gpa);

    p.parseRoot(main_node_index) catch |err| switch (err) {
        error.ParseFailure => assert(p.errors.items.len > 0),
        else => |e| return e,
    };

    return .{
        .name = p.name,
        .version = p.version,
        .version_node = p.version_node,
        .dependencies = try p.dependencies.clone(p.arena),
        .dependencies_node = p.dependencies_node,
        .paths = try p.paths.clone(p.arena),
        .minimum_zig_version = p.minimum_zig_version,
        .errors = try p.arena.dupe(ErrorMessage, p.errors.items),
        .arena_state = arena_instance.state,
    };
}

pub fn deinit(man: *Manifest, gpa: Allocator) void {
    man.arena_state.promote(gpa).deinit();
    man.* = undefined;
}

pub fn copyErrorsIntoBundle(
    man: Manifest,
    ast: Ast,
    /// ErrorBundle null-terminated string index
    src_path: u32,
    eb: *std.zig.ErrorBundle.Wip,
) Allocator.Error!void {
    const token_starts = ast.tokens.items(.start);

    for (man.errors) |msg| {
        const start_loc = ast.tokenLocation(0, msg.tok);

        try eb.addRootErrorMessage(.{
            .msg = try eb.addString(msg.msg),
            .src_loc = try eb.addSourceLocation(.{
                .src_path = src_path,
                .span_start = token_starts[msg.tok],
                .span_end = @intCast(token_starts[msg.tok] + ast.tokenSlice(msg.tok).len),
                .span_main = token_starts[msg.tok] + msg.off,
                .line = @intCast(start_loc.line),
                .column = @intCast(start_loc.column),
                .source_line = try eb.addString(ast.source[start_loc.line_start..start_loc.line_end]),
            }),
        });
    }
}

pub fn hexDigest(digest: Digest) MultiHashHexDigest {
    var result: MultiHashHexDigest = undefined;

    result[0] = hex_charset[@intFromEnum(multihash_function) >> 4];
    result[1] = hex_charset[@intFromEnum(multihash_function) & 15];

    result[2] = hex_charset[Hash.digest_length >> 4];
    result[3] = hex_charset[Hash.digest_length & 15];

    for (digest, 0..) |byte, i| {
        result[4 + i * 2] = hex_charset[byte >> 4];
        result[5 + i * 2] = hex_charset[byte & 15];
    }
    return result;
}

const Parse = struct {
    gpa: Allocator,
    ast: Ast,
    arena: Allocator,
    buf: std.ArrayListUnmanaged(u8),
    errors: std.ArrayListUnmanaged(ErrorMessage),

    name: []const u8,
    version: std.SemanticVersion,
    version_node: Ast.Node.Index,
    dependencies: std.StringArrayHashMapUnmanaged(Dependency),
    dependencies_node: Ast.Node.Index,
    paths: std.StringArrayHashMapUnmanaged(void),
    allow_missing_paths_field: bool,
    minimum_zig_version: ?std.SemanticVersion,

    const InnerError = error{ ParseFailure, OutOfMemory };

    fn parseRoot(p: *Parse, node: Ast.Node.Index) !void {
        const ast = p.ast;
        const main_tokens = ast.nodes.items(.main_token);
        const main_token = main_tokens[node];

        var buf: [2]Ast.Node.Index = undefined;
        const struct_init = ast.fullStructInit(&buf, node) orelse {
            return fail(p, main_token, "expected top level expression to be a struct", .{});
        };

        var have_name = false;
        var have_version = false;
        var have_included_paths = false;

        for (struct_init.ast.fields) |field_init| {
            const name_token = ast.firstToken(field_init) - 2;
            const field_name = try identifierTokenString(p, name_token);
            // We could get fancy with reflection and comptime logic here but doing
            // things manually provides an opportunity to do any additional verification
            // that is desirable on a per-field basis.
            if (mem.eql(u8, field_name, "dependencies")) {
                p.dependencies_node = field_init;
                try parseDependencies(p, field_init);
            } else if (mem.eql(u8, field_name, "paths")) {
                have_included_paths = true;
                try parseIncludedPaths(p, field_init);
            } else if (mem.eql(u8, field_name, "name")) {
                p.name = try parseString(p, field_init);
                have_name = true;
            } else if (mem.eql(u8, field_name, "version")) {
                p.version_node = field_init;
                const version_text = try parseString(p, field_init);
                p.version = std.SemanticVersion.parse(version_text) catch |err| v: {
                    try appendError(p, main_tokens[field_init], "unable to parse semantic version: {s}", .{@errorName(err)});
                    break :v undefined;
                };
                have_version = true;
            } else if (mem.eql(u8, field_name, "minimum_zig_version")) {
                const version_text = try parseString(p, field_init);
                p.minimum_zig_version = std.SemanticVersion.parse(version_text) catch |err| v: {
                    try appendError(p, main_tokens[field_init], "unable to parse semantic version: {s}", .{@errorName(err)});
                    break :v null;
                };
            } else {
                // Ignore unknown fields so that we can add fields in future zig
                // versions without breaking older zig versions.
            }
        }

        if (!have_name) {
            try appendError(p, main_token, "missing top-level 'name' field", .{});
        }

        if (!have_version) {
            try appendError(p, main_token, "missing top-level 'version' field", .{});
        }

        if (!have_included_paths) {
            if (p.allow_missing_paths_field) {
                try p.paths.put(p.gpa, "", {});
            } else {
                try appendError(p, main_token, "missing top-level 'paths' field", .{});
            }
        }
    }

    fn parseDependencies(p: *Parse, node: Ast.Node.Index) !void {
        const ast = p.ast;
        const main_tokens = ast.nodes.items(.main_token);

        var buf: [2]Ast.Node.Index = undefined;
        const struct_init = ast.fullStructInit(&buf, node) orelse {
            const tok = main_tokens[node];
            return fail(p, tok, "expected dependencies expression to be a struct", .{});
        };

        for (struct_init.ast.fields) |field_init| {
            const name_token = ast.firstToken(field_init) - 2;
            const dep_name = try identifierTokenString(p, name_token);
            const dep = try parseDependency(p, field_init);
            try p.dependencies.put(p.gpa, dep_name, dep);
        }
    }

    fn parseDependency(p: *Parse, node: Ast.Node.Index) !Dependency {
        const ast = p.ast;
        const main_tokens = ast.nodes.items(.main_token);

        var buf: [2]Ast.Node.Index = undefined;
        const struct_init = ast.fullStructInit(&buf, node) orelse {
            const tok = main_tokens[node];
            return fail(p, tok, "expected dependency expression to be a struct", .{});
        };

        var dep: Dependency = .{
            .location = undefined,
            .location_tok = 0,
            .location_node = undefined,
            .hash = null,
            .hash_tok = 0,
            .hash_node = undefined,
            .node = node,
            .name_tok = 0,
            .lazy = false,
        };
        var has_location = false;

        for (struct_init.ast.fields) |field_init| {
            const name_token = ast.firstToken(field_init) - 2;
            dep.name_tok = name_token;
            const field_name = try identifierTokenString(p, name_token);
            // We could get fancy with reflection and comptime logic here but doing
            // things manually provides an opportunity to do any additional verification
            // that is desirable on a per-field basis.
            if (mem.eql(u8, field_name, "url")) {
                if (has_location) {
                    return fail(p, main_tokens[field_init], "dependency should specify only one of 'url' and 'path' fields.", .{});
                }
                dep.location = .{
                    .url = parseString(p, field_init) catch |err| switch (err) {
                        error.ParseFailure => continue,
                        else => |e| return e,
                    },
                };
                has_location = true;
                dep.location_tok = main_tokens[field_init];
                dep.location_node = field_init;
            } else if (mem.eql(u8, field_name, "path")) {
                if (has_location) {
                    return fail(p, main_tokens[field_init], "dependency should specify only one of 'url' and 'path' fields.", .{});
                }
                dep.location = .{
                    .path = parseString(p, field_init) catch |err| switch (err) {
                        error.ParseFailure => continue,
                        else => |e| return e,
                    },
                };
                has_location = true;
                dep.location_tok = main_tokens[field_init];
                dep.location_node = field_init;
            } else if (mem.eql(u8, field_name, "hash")) {
                dep.hash = parseHash(p, field_init) catch |err| switch (err) {
                    error.ParseFailure => continue,
                    else => |e| return e,
                };
                dep.hash_tok = main_tokens[field_init];
                dep.hash_node = field_init;
            } else if (mem.eql(u8, field_name, "lazy")) {
                dep.lazy = parseBool(p, field_init) catch |err| switch (err) {
                    error.ParseFailure => continue,
                    else => |e| return e,
                };
            } else {
                // Ignore unknown fields so that we can add fields in future zig
                // versions without breaking older zig versions.
            }
        }

        if (!has_location) {
            try appendError(p, main_tokens[node], "dependency requires location field, one of 'url' or 'path'.", .{});
        }

        return dep;
    }

    fn parseIncludedPaths(p: *Parse, node: Ast.Node.Index) !void {
        const ast = p.ast;
        const main_tokens = ast.nodes.items(.main_token);

        var buf: [2]Ast.Node.Index = undefined;
        const array_init = ast.fullArrayInit(&buf, node) orelse {
            const tok = main_tokens[node];
            return fail(p, tok, "expected paths expression to be a list of strings", .{});
        };

        for (array_init.ast.elements) |elem_node| {
            const path_string = try parseString(p, elem_node);
            // This is normalized so that it can be used in string comparisons
            // against file system paths.
            const normalized = try std.fs.path.resolve(p.arena, &.{path_string});
            try p.paths.put(p.gpa, normalized, {});
        }
    }

    fn parseBool(p: *Parse, node: Ast.Node.Index) !bool {
        const ast = p.ast;
        const node_tags = ast.nodes.items(.tag);
        const main_tokens = ast.nodes.items(.main_token);
        if (node_tags[node] != .identifier) {
            return fail(p, main_tokens[node], "expected identifier", .{});
        }
        const ident_token = main_tokens[node];
        const token_bytes = ast.tokenSlice(ident_token);
        if (mem.eql(u8, token_bytes, "true")) {
            return true;
        } else if (mem.eql(u8, token_bytes, "false")) {
            return false;
        } else {
            return fail(p, ident_token, "expected boolean", .{});
        }
    }

    fn parseString(p: *Parse, node: Ast.Node.Index) ![]const u8 {
        const ast = p.ast;
        const node_tags = ast.nodes.items(.tag);
        const main_tokens = ast.nodes.items(.main_token);
        if (node_tags[node] != .string_literal) {
            return fail(p, main_tokens[node], "expected string literal", .{});
        }
        const str_lit_token = main_tokens[node];
        const token_bytes = ast.tokenSlice(str_lit_token);
        p.buf.clearRetainingCapacity();
        try parseStrLit(p, str_lit_token, &p.buf, token_bytes, 0);
        const duped = try p.arena.dupe(u8, p.buf.items);
        return duped;
    }

    fn parseHash(p: *Parse, node: Ast.Node.Index) ![]const u8 {
        const ast = p.ast;
        const main_tokens = ast.nodes.items(.main_token);
        const tok = main_tokens[node];
        const h = try parseString(p, node);

        if (h.len >= 2) {
            const their_multihash_func = std.fmt.parseInt(u8, h[0..2], 16) catch |err| {
                return fail(p, tok, "invalid multihash value: unable to parse hash function: {s}", .{
                    @errorName(err),
                });
            };
            if (@as(MultihashFunction, @enumFromInt(their_multihash_func)) != multihash_function) {
                return fail(p, tok, "unsupported hash function: only sha2-256 is supported", .{});
            }
        }

        if (h.len != multihash_hex_digest_len) {
            return fail(p, tok, "wrong hash size. expected: {d}, found: {d}", .{
                multihash_hex_digest_len, h.len,
            });
        }

        return h;
    }

    /// TODO: try to DRY this with AstGen.identifierTokenString
    fn identifierTokenString(p: *Parse, token: Ast.TokenIndex) InnerError![]const u8 {
        const ast = p.ast;
        const token_tags = ast.tokens.items(.tag);
        assert(token_tags[token] == .identifier);
        const ident_name = ast.tokenSlice(token);
        if (!mem.startsWith(u8, ident_name, "@")) {
            return ident_name;
        }
        p.buf.clearRetainingCapacity();
        try parseStrLit(p, token, &p.buf, ident_name, 1);
        const duped = try p.arena.dupe(u8, p.buf.items);
        return duped;
    }

    /// TODO: try to DRY this with AstGen.parseStrLit
    fn parseStrLit(
        p: *Parse,
        token: Ast.TokenIndex,
        buf: *std.ArrayListUnmanaged(u8),
        bytes: []const u8,
        offset: u32,
    ) InnerError!void {
        const raw_string = bytes[offset..];
        var buf_managed = buf.toManaged(p.gpa);
        const result = std.zig.string_literal.parseWrite(buf_managed.writer(), raw_string);
        buf.* = buf_managed.moveToUnmanaged();
        switch (try result) {
            .success => {},
            .failure => |err| try p.appendStrLitError(err, token, bytes, offset),
        }
    }

    /// TODO: try to DRY this with AstGen.failWithStrLitError
    fn appendStrLitError(
        p: *Parse,
        err: std.zig.string_literal.Error,
        token: Ast.TokenIndex,
        bytes: []const u8,
        offset: u32,
    ) Allocator.Error!void {
        const raw_string = bytes[offset..];
        switch (err) {
            .invalid_escape_character => |bad_index| {
                try p.appendErrorOff(
                    token,
                    offset + @as(u32, @intCast(bad_index)),
                    "invalid escape character: '{c}'",
                    .{raw_string[bad_index]},
                );
            },
            .expected_hex_digit => |bad_index| {
                try p.appendErrorOff(
                    token,
                    offset + @as(u32, @intCast(bad_index)),
                    "expected hex digit, found '{c}'",
                    .{raw_string[bad_index]},
                );
            },
            .empty_unicode_escape_sequence => |bad_index| {
                try p.appendErrorOff(
                    token,
                    offset + @as(u32, @intCast(bad_index)),
                    "empty unicode escape sequence",
                    .{},
                );
            },
            .expected_hex_digit_or_rbrace => |bad_index| {
                try p.appendErrorOff(
                    token,
                    offset + @as(u32, @intCast(bad_index)),
                    "expected hex digit or '}}', found '{c}'",
                    .{raw_string[bad_index]},
                );
            },
            .invalid_unicode_codepoint => |bad_index| {
                try p.appendErrorOff(
                    token,
                    offset + @as(u32, @intCast(bad_index)),
                    "unicode escape does not correspond to a valid unicode scalar value",
                    .{},
                );
            },
            .expected_lbrace => |bad_index| {
                try p.appendErrorOff(
                    token,
                    offset + @as(u32, @intCast(bad_index)),
                    "expected '{{', found '{c}",
                    .{raw_string[bad_index]},
                );
            },
            .expected_rbrace => |bad_index| {
                try p.appendErrorOff(
                    token,
                    offset + @as(u32, @intCast(bad_index)),
                    "expected '}}', found '{c}",
                    .{raw_string[bad_index]},
                );
            },
            .expected_single_quote => |bad_index| {
                try p.appendErrorOff(
                    token,
                    offset + @as(u32, @intCast(bad_index)),
                    "expected single quote ('), found '{c}",
                    .{raw_string[bad_index]},
                );
            },
            .invalid_character => |bad_index| {
                try p.appendErrorOff(
                    token,
                    offset + @as(u32, @intCast(bad_index)),
                    "invalid byte in string or character literal: '{c}'",
                    .{raw_string[bad_index]},
                );
            },
            .empty_char_literal => {
                try p.appendErrorOff(token, offset, "empty character literal", .{});
            },
        }
    }

    fn fail(
        p: *Parse,
        tok: Ast.TokenIndex,
        comptime fmt: []const u8,
        args: anytype,
    ) InnerError {
        try appendError(p, tok, fmt, args);
        return error.ParseFailure;
    }

    fn appendError(p: *Parse, tok: Ast.TokenIndex, comptime fmt: []const u8, args: anytype) !void {
        return appendErrorOff(p, tok, 0, fmt, args);
    }

    fn appendErrorOff(
        p: *Parse,
        tok: Ast.TokenIndex,
        byte_offset: u32,
        comptime fmt: []const u8,
        args: anytype,
    ) Allocator.Error!void {
        try p.errors.append(p.gpa, .{
            .msg = try std.fmt.allocPrint(p.arena, fmt, args),
            .tok = tok,
            .off = byte_offset,
        });
    }
};

test "basic" {
    const gpa = testing.allocator;

    const example =
        \\.{
        \\    .name = "foo",
        \\    .version = "3.2.1",
        \\    .paths = .{""},
        \\    .dependencies = .{
        \\        .bar = .{
        \\            .url = "https://example.com/baz.tar.gz",
        \\            .hash = "1220f1b680b6065fcfc94fe777f22e73bcb7e2767e5f4d99d4255fe76ded69c7a35f",
        \\        },
        \\    },
        \\}
    ;

    var ast = try Ast.parse(gpa, example, .zon);
    defer ast.deinit(gpa);

    try testing.expect(ast.errors.len == 0);

    var manifest = try Manifest.parse(gpa, ast, .{});
    defer manifest.deinit(gpa);

    try testing.expect(manifest.errors.len == 0);
    try testing.expectEqualStrings("foo", manifest.name);

    try testing.expectEqual(@as(std.SemanticVersion, .{
        .major = 3,
        .minor = 2,
        .patch = 1,
    }), manifest.version);

    try testing.expect(manifest.dependencies.count() == 1);
    try testing.expectEqualStrings("bar", manifest.dependencies.keys()[0]);
    try testing.expectEqualStrings(
        "https://example.com/baz.tar.gz",
        manifest.dependencies.values()[0].location.url,
    );
    try testing.expectEqualStrings(
        "1220f1b680b6065fcfc94fe777f22e73bcb7e2767e5f4d99d4255fe76ded69c7a35f",
        manifest.dependencies.values()[0].hash orelse return error.TestFailed,
    );

    try testing.expect(manifest.minimum_zig_version == null);
}

test "minimum_zig_version" {
    const gpa = testing.allocator;

    const example =
        \\.{
        \\    .name = "foo",
        \\    .version = "3.2.1",
        \\    .paths = .{""},
        \\    .minimum_zig_version = "0.11.1",
        \\}
    ;

    var ast = try Ast.parse(gpa, example, .zon);
    defer ast.deinit(gpa);

    try testing.expect(ast.errors.len == 0);

    var manifest = try Manifest.parse(gpa, ast, .{});
    defer manifest.deinit(gpa);

    try testing.expect(manifest.errors.len == 0);
    try testing.expect(manifest.dependencies.count() == 0);

    try testing.expect(manifest.minimum_zig_version != null);

    try testing.expectEqual(@as(std.SemanticVersion, .{
        .major = 0,
        .minor = 11,
        .patch = 1,
    }), manifest.minimum_zig_version.?);
}

test "minimum_zig_version - invalid version" {
    const gpa = testing.allocator;

    const example =
        \\.{
        \\    .name = "foo",
        \\    .version = "3.2.1",
        \\    .minimum_zig_version = "X.11.1",
        \\    .paths = .{""},
        \\}
    ;

    var ast = try Ast.parse(gpa, example, .zon);
    defer ast.deinit(gpa);

    try testing.expect(ast.errors.len == 0);

    var manifest = try Manifest.parse(gpa, ast, .{});
    defer manifest.deinit(gpa);

    try testing.expect(manifest.errors.len == 1);
    try testing.expect(manifest.dependencies.count() == 0);

    try testing.expect(manifest.minimum_zig_version == null);
}
