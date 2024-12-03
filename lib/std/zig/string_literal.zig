const std = @import("../std.zig");
const assert = std.debug.assert;
const utf8Encode = std.unicode.utf8Encode;

pub const ParseError = error{
    OutOfMemory,
    InvalidLiteral,
};

pub const ParsedCharLiteral = union(enum) {
    success: u21,
    failure: Error,
};

pub const Result = union(enum) {
    success,
    failure: Error,
};

pub const Error = union(enum) {
    /// The character after backslash is missing or not recognized.
    invalid_escape_character: usize,
    /// Expected hex digit at this index.
    expected_hex_digit: usize,
    /// Unicode escape sequence had no digits with rbrace at this index.
    empty_unicode_escape_sequence: usize,
    /// Expected hex digit or '}' at this index.
    expected_hex_digit_or_rbrace: usize,
    /// Invalid unicode codepoint at this index.
    invalid_unicode_codepoint: usize,
    /// Expected '{' at this index.
    expected_lbrace: usize,
    /// Expected '}' at this index.
    expected_rbrace: usize,
    /// Expected '\'' at this index.
    expected_single_quote: usize,
    /// The character at this index cannot be represented without an escape sequence.
    invalid_character: usize,
    /// `''`. Not returned for string literals.
    empty_char_literal,

    /// Returns `func(first_args[0], ..., first_args[n], offset + bad_idx, format, args)`.
    pub fn lower(
        err: Error,
        raw_string: []const u8,
        offset: u32,
        comptime func: anytype,
        first_args: anytype,
    ) @typeInfo(@TypeOf(func)).@"fn".return_type.? {
        switch (err) {
            inline else => |bad_index_or_void, tag| {
                const bad_index: u32 = switch (@TypeOf(bad_index_or_void)) {
                    void => 0,
                    else => @intCast(bad_index_or_void),
                };
                const fmt_str: []const u8, const args = switch (tag) {
                    .invalid_escape_character => .{ "invalid escape character: '{c}'", .{raw_string[bad_index]} },
                    .expected_hex_digit => .{ "expected hex digit, found '{c}'", .{raw_string[bad_index]} },
                    .empty_unicode_escape_sequence => .{ "empty unicode escape sequence", .{} },
                    .expected_hex_digit_or_rbrace => .{ "expected hex digit or '}}', found '{c}'", .{raw_string[bad_index]} },
                    .invalid_unicode_codepoint => .{ "unicode escape does not correspond to a valid unicode scalar value", .{} },
                    .expected_lbrace => .{ "expected '{{', found '{c}'", .{raw_string[bad_index]} },
                    .expected_rbrace => .{ "expected '}}', found '{c}'", .{raw_string[bad_index]} },
                    .expected_single_quote => .{ "expected singel quote ('), found '{c}'", .{raw_string[bad_index]} },
                    .invalid_character => .{ "invalid byte in string or character literal: '{c}'", .{raw_string[bad_index]} },
                    .empty_char_literal => .{ "empty character literal", .{} },
                };
                return @call(.auto, func, first_args ++ .{
                    offset + bad_index,
                    fmt_str,
                    args,
                });
            },
        }
    }

    pub fn fmtWithSource(self: Error, raw_string: []const u8) std.fmt.Formatter(formatErrorWithSource) {
        return .{ .data = .{ .err = self, .raw_string = raw_string } };
    }

    pub fn offset(self: Error) usize {
        return switch (self) {
            .invalid_escape_character => |i| i,
            .expected_hex_digit => |i| i,
            .empty_unicode_escape_sequence => |i| i,
            .expected_hex_digit_or_rbrace => |i| i,
            .invalid_unicode_codepoint => |i| i,
            .expected_lbrace => |i| i,
            .expected_rbrace => |i| i,
            .expected_single_quote => |i| i,
            .invalid_character => |i| i,
            .empty_char_literal => 0,
        };
    }
};

const FormatWithSource = struct {
    raw_string: []const u8,
    err: Error,
};

fn formatErrorWithSource(
    self: FormatWithSource,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = fmt;
    switch (self.err) {
        .invalid_escape_character => |bad_index| {
            try writer.print("invalid escape character: '{c}'", .{self.raw_string[bad_index]});
        },
        .expected_hex_digit => |bad_index| {
            try writer.print("expected hex digit, found '{c}'", .{self.raw_string[bad_index]});
        },
        .empty_unicode_escape_sequence => {
            try writer.writeAll("empty unicode escape sequence");
        },
        .expected_hex_digit_or_rbrace => |bad_index| {
            try writer.print("expected hex digit or '}}', found '{c}'", .{self.raw_string[bad_index]});
        },
        .invalid_unicode_codepoint => {
            try writer.writeAll("unicode escape does not correspond to a valid unicode scalar value");
        },
        .expected_lbrace => |bad_index| {
            try writer.print("expected '{{', found '{c}", .{self.raw_string[bad_index]});
        },
        .expected_rbrace => |bad_index| {
            try writer.print("expected '}}', found '{c}", .{self.raw_string[bad_index]});
        },
        .expected_single_quote => |bad_index| {
            try writer.print("expected single quote ('), found '{c}", .{self.raw_string[bad_index]});
        },
        .invalid_character => |bad_index| {
            try writer.print("invalid byte in string or character literal: '{c}'", .{self.raw_string[bad_index]});
        },
        .empty_char_literal => {
            try writer.print("empty character literal", .{});
        },
    }
}

/// Asserts the slice starts and ends with single-quotes.
/// Returns an error if there is not exactly one UTF-8 codepoint in between.
pub fn parseCharLiteral(slice: []const u8) ParsedCharLiteral {
    if (slice.len < 3) return .{ .failure = .empty_char_literal };
    assert(slice[0] == '\'');
    assert(slice[slice.len - 1] == '\'');

    switch (slice[1]) {
        '\\' => {
            var offset: usize = 1;
            const result = parseEscapeSequence(slice, &offset);
            if (result == .success and (offset + 1 != slice.len or slice[offset] != '\''))
                return .{ .failure = .{ .expected_single_quote = offset } };

            return result;
        },
        0 => return .{ .failure = .{ .invalid_character = 1 } },
        else => {
            const inner = slice[1 .. slice.len - 1];
            const n = std.unicode.utf8ByteSequenceLength(inner[0]) catch return .{
                .failure = .{ .invalid_unicode_codepoint = 1 },
            };
            if (inner.len > n) return .{ .failure = .{ .expected_single_quote = 1 + n } };
            const codepoint = switch (n) {
                1 => inner[0],
                2 => std.unicode.utf8Decode2(inner[0..2].*),
                3 => std.unicode.utf8Decode3(inner[0..3].*),
                4 => std.unicode.utf8Decode4(inner[0..4].*),
                else => unreachable,
            } catch return .{ .failure = .{ .invalid_unicode_codepoint = 1 } };
            return .{ .success = codepoint };
        },
    }
}

/// Parse an escape sequence from `slice[offset..]`. If parsing is successful,
/// offset is updated to reflect the characters consumed.
pub fn parseEscapeSequence(slice: []const u8, offset: *usize) ParsedCharLiteral {
    assert(slice.len > offset.*);
    assert(slice[offset.*] == '\\');

    if (slice.len == offset.* + 1)
        return .{ .failure = .{ .invalid_escape_character = offset.* + 1 } };

    offset.* += 2;
    switch (slice[offset.* - 1]) {
        'n' => return .{ .success = '\n' },
        'r' => return .{ .success = '\r' },
        '\\' => return .{ .success = '\\' },
        't' => return .{ .success = '\t' },
        '\'' => return .{ .success = '\'' },
        '"' => return .{ .success = '"' },
        'x' => {
            var value: u8 = 0;
            var i: usize = offset.*;
            while (i < offset.* + 2) : (i += 1) {
                if (i == slice.len) return .{ .failure = .{ .expected_hex_digit = i } };

                const c = slice[i];
                switch (c) {
                    '0'...'9' => {
                        value *= 16;
                        value += c - '0';
                    },
                    'a'...'f' => {
                        value *= 16;
                        value += c - 'a' + 10;
                    },
                    'A'...'F' => {
                        value *= 16;
                        value += c - 'A' + 10;
                    },
                    else => {
                        return .{ .failure = .{ .expected_hex_digit = i } };
                    },
                }
            }
            offset.* = i;
            return .{ .success = value };
        },
        'u' => {
            var i: usize = offset.*;
            if (i >= slice.len or slice[i] != '{') return .{ .failure = .{ .expected_lbrace = i } };
            i += 1;
            if (i >= slice.len) return .{ .failure = .{ .expected_hex_digit_or_rbrace = i } };
            if (slice[i] == '}') return .{ .failure = .{ .empty_unicode_escape_sequence = i } };

            var value: u32 = 0;
            while (i < slice.len) : (i += 1) {
                const c = slice[i];
                switch (c) {
                    '0'...'9' => {
                        value *= 16;
                        value += c - '0';
                    },
                    'a'...'f' => {
                        value *= 16;
                        value += c - 'a' + 10;
                    },
                    'A'...'F' => {
                        value *= 16;
                        value += c - 'A' + 10;
                    },
                    '}' => {
                        i += 1;
                        break;
                    },
                    else => return .{ .failure = .{ .expected_hex_digit_or_rbrace = i } },
                }
                if (value > 0x10ffff) {
                    return .{ .failure = .{ .invalid_unicode_codepoint = i } };
                }
            } else {
                return .{ .failure = .{ .expected_rbrace = i } };
            }
            offset.* = i;
            return .{ .success = @as(u21, @intCast(value)) };
        },
        else => return .{ .failure = .{ .invalid_escape_character = offset.* - 1 } },
    }
}

test parseCharLiteral {
    try std.testing.expectEqual(
        ParsedCharLiteral{ .success = 'a' },
        parseCharLiteral("'a'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .success = 'ä' },
        parseCharLiteral("'ä'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .success = 0 },
        parseCharLiteral("'\\x00'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .success = 0x4f },
        parseCharLiteral("'\\x4f'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .success = 0x4f },
        parseCharLiteral("'\\x4F'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .success = 0x3041 },
        parseCharLiteral("'ぁ'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .success = 0 },
        parseCharLiteral("'\\u{0}'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .success = 0x3041 },
        parseCharLiteral("'\\u{3041}'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .success = 0x7f },
        parseCharLiteral("'\\u{7f}'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .success = 0x7fff },
        parseCharLiteral("'\\u{7FFF}'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .failure = .{ .expected_hex_digit = 4 } },
        parseCharLiteral("'\\x0'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .failure = .{ .expected_single_quote = 5 } },
        parseCharLiteral("'\\x000'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .failure = .{ .invalid_escape_character = 2 } },
        parseCharLiteral("'\\y'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .failure = .{ .expected_lbrace = 3 } },
        parseCharLiteral("'\\u'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .failure = .{ .expected_lbrace = 3 } },
        parseCharLiteral("'\\uFFFF'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .failure = .{ .empty_unicode_escape_sequence = 4 } },
        parseCharLiteral("'\\u{}'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .failure = .{ .invalid_unicode_codepoint = 9 } },
        parseCharLiteral("'\\u{FFFFFF}'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .failure = .{ .expected_hex_digit_or_rbrace = 8 } },
        parseCharLiteral("'\\u{FFFF'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .failure = .{ .expected_single_quote = 9 } },
        parseCharLiteral("'\\u{FFFF}x'"),
    );
    try std.testing.expectEqual(
        ParsedCharLiteral{ .failure = .{ .invalid_character = 1 } },
        parseCharLiteral("'\x00'"),
    );
}

/// Parses `bytes` as a Zig string literal and writes the result to the std.io.Writer type.
/// Asserts `bytes` has '"' at beginning and end.
pub fn parseWrite(writer: anytype, bytes: []const u8) !Result {
    assert(bytes.len >= 2 and bytes[0] == '"' and bytes[bytes.len - 1] == '"');

    var index: usize = 1;
    while (true) {
        const b = bytes[index];

        switch (b) {
            '\\' => {
                const escape_char_index = index + 1;
                const result = parseEscapeSequence(bytes, &index);
                switch (result) {
                    .success => |codepoint| {
                        if (bytes[escape_char_index] == 'u') {
                            var buf: [4]u8 = undefined;
                            const len = utf8Encode(codepoint, &buf) catch {
                                return Result{ .failure = .{ .invalid_unicode_codepoint = escape_char_index + 1 } };
                            };
                            try writer.writeAll(buf[0..len]);
                        } else {
                            try writer.writeByte(@as(u8, @intCast(codepoint)));
                        }
                    },
                    .failure => |err| return Result{ .failure = err },
                }
            },
            '\n' => return Result{ .failure = .{ .invalid_character = index } },
            '"' => return Result.success,
            else => {
                try writer.writeByte(b);
                index += 1;
            },
        }
    }
}

/// Higher level API. Does not return extra info about parse errors.
/// Caller owns returned memory.
pub fn parseAlloc(allocator: std.mem.Allocator, bytes: []const u8) ParseError![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    switch (try parseWrite(buf.writer(), bytes)) {
        .success => return buf.toOwnedSlice(),
        .failure => return error.InvalidLiteral,
    }
}

test parseAlloc {
    const expect = std.testing.expect;
    const expectError = std.testing.expectError;
    const eql = std.mem.eql;

    var fixed_buf_mem: [64]u8 = undefined;
    var fixed_buf_alloc = std.heap.FixedBufferAllocator.init(&fixed_buf_mem);
    const alloc = fixed_buf_alloc.allocator();

    try expectError(error.InvalidLiteral, parseAlloc(alloc, "\"\\x6\""));
    try expect(eql(u8, "foo\nbar", try parseAlloc(alloc, "\"foo\\nbar\"")));
    try expect(eql(u8, "\x12foo", try parseAlloc(alloc, "\"\\x12foo\"")));
    try expect(eql(u8, "bytes\u{1234}foo", try parseAlloc(alloc, "\"bytes\\u{1234}foo\"")));
    try expect(eql(u8, "foo", try parseAlloc(alloc, "\"foo\"")));
    try expect(eql(u8, "foo", try parseAlloc(alloc, "\"f\x6f\x6f\"")));
    try expect(eql(u8, "f💯", try parseAlloc(alloc, "\"f\u{1f4af}\"")));
}

/// Parses one line at a time of a multiline Zig string literal to a std.io.Writer type. Does not append a null terminator.
pub fn MultilineParser(comptime Writer: type) type {
    return struct {
        writer: Writer,
        first_line: bool,

        pub fn init(writer: Writer) @This() {
            return .{
                .writer = writer,
                .first_line = true,
            };
        }

        /// Parse one line of a multiline string, writing the result to the writer prepending a
        /// newline if necessary.
        ///
        /// Asserts bytes begins with "\\". The line may be terminated with '\n' or  "\r\n", but may
        /// not contain any interior newlines.
        pub fn line(self: *@This(), bytes: []const u8) Writer.Error!void {
            assert(bytes.len >= 2 and bytes[0] == '\\' and bytes[1] == '\\');
            var terminator_len: usize = 0;
            terminator_len += @intFromBool(bytes[bytes.len - 1] == '\n');
            terminator_len += @intFromBool(bytes[bytes.len - 2] == '\r');
            if (self.first_line) {
                self.first_line = false;
            } else {
                try self.writer.writeByte('\n');
            }
            try self.writer.writeAll(bytes[2 .. bytes.len - terminator_len]);
        }
    };
}

pub fn multilineParser(writer: anytype) MultilineParser(@TypeOf(writer)) {
    return MultilineParser(@TypeOf(writer)).init(writer);
}

test "parse multiline" {
    // Varying newlines
    {
        {
            var parsed = std.ArrayList(u8).init(std.testing.allocator);
            defer parsed.deinit();
            const writer = parsed.writer();
            var parser = multilineParser(writer);
            try parser.line("\\\\foo");
            try std.testing.expectEqualStrings("foo", parsed.items);
            try parser.line("\\\\bar");
            try std.testing.expectEqualStrings("foo\nbar", parsed.items);
        }

        {
            const temp =
                \\foo
                \\bar
            ;
            try std.testing.expectEqualStrings("foo\nbar", temp);
            var parsed = std.ArrayList(u8).init(std.testing.allocator);
            defer parsed.deinit();
            const writer = parsed.writer();
            var parser = multilineParser(writer);
            try parser.line("\\\\foo");
            try std.testing.expectEqualStrings("foo", parsed.items);
            // XXX: this adds the newline but like...does the input ever actually have a newline there?
            try parser.line("\\\\bar\n");
            try std.testing.expectEqualStrings("foo\nbar", parsed.items);
        }

        {
            var parsed = std.ArrayList(u8).init(std.testing.allocator);
            defer parsed.deinit();
            const writer = parsed.writer();
            var parser = multilineParser(writer);
            try parser.line("\\\\foo");
            try std.testing.expectEqualStrings("foo", parsed.items);
            try parser.line("\\\\bar\r\n");
            try std.testing.expectEqualStrings("foo\nbar", parsed.items);
        }

        {
            var parsed = std.ArrayList(u8).init(std.testing.allocator);
            defer parsed.deinit();
            const writer = parsed.writer();
            var parser = multilineParser(writer);
            try parser.line("\\\\foo\n");
            try std.testing.expectEqualStrings("foo", parsed.items);
            try parser.line("\\\\bar");
            try std.testing.expectEqualStrings("foo\nbar", parsed.items);
        }

        {
            var parsed = std.ArrayList(u8).init(std.testing.allocator);
            defer parsed.deinit();
            const writer = parsed.writer();
            var parser = multilineParser(writer);
            try parser.line("\\\\foo\r\n");
            try std.testing.expectEqualStrings("foo", parsed.items);
            try parser.line("\\\\bar");
            try std.testing.expectEqualStrings("foo\nbar", parsed.items);
        }
    }

    // Empty lines
    {
        {
            var parsed = std.ArrayList(u8).init(std.testing.allocator);
            defer parsed.deinit();
            const writer = parsed.writer();
            var parser = multilineParser(writer);
            try parser.line("\\\\");
            try std.testing.expectEqualStrings("", parsed.items);
            try parser.line("\\\\");
            try std.testing.expectEqualStrings("\n", parsed.items);
            try parser.line("\\\\foo");
            try std.testing.expectEqualStrings("\n\nfoo", parsed.items);
            try parser.line("\\\\bar");
            try std.testing.expectEqualStrings("\n\nfoo\nbar", parsed.items);
        }

        {
            var parsed = std.ArrayList(u8).init(std.testing.allocator);
            defer parsed.deinit();
            const writer = parsed.writer();
            var parser = multilineParser(writer);
            try parser.line("\\\\foo");
            try std.testing.expectEqualStrings("foo", parsed.items);
            try parser.line("\\\\");
            try std.testing.expectEqualStrings("foo\n", parsed.items);
            try parser.line("\\\\bar");
            try std.testing.expectEqualStrings("foo\n\nbar", parsed.items);
            try parser.line("\\\\");
            try std.testing.expectEqualStrings("foo\n\nbar\n", parsed.items);
        }
    }

    // No escapes
    {
        var parsed = std.ArrayList(u8).init(std.testing.allocator);
        defer parsed.deinit();
        const writer = parsed.writer();
        var parser = multilineParser(writer);
        try parser.line("\\\\no \\n escape");
        try std.testing.expectEqualStrings("no \\n escape", parsed.items);
        try parser.line("\\\\still no \\n escape");
        try std.testing.expectEqualStrings("no \\n escape\nstill no \\n escape", parsed.items);
    }
}
