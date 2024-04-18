const std = @import("std");
const code_pages = @import("code_pages.zig");
const CodePage = code_pages.CodePage;
const windows1252 = @import("windows1252.zig");
const ErrorDetails = @import("errors.zig").ErrorDetails;
const DiagnosticsContext = @import("errors.zig").DiagnosticsContext;
const Token = @import("lex.zig").Token;

/// rc is maximally liberal in terms of what it accepts as a number literal
/// for data values. As long as it starts with a number or - or ~, that's good enough.
pub fn isValidNumberDataLiteral(str: []const u8) bool {
    if (str.len == 0) return false;
    switch (str[0]) {
        '~', '-', '0'...'9' => return true,
        else => return false,
    }
}

pub const SourceBytes = struct {
    slice: []const u8,
    code_page: CodePage,
};

pub const StringType = enum { ascii, wide };

/// Valid escapes:
///  "" -> "
///  \a, \A => 0x08 (not 0x07 like in C)
///  \n => 0x0A
///  \r => 0x0D
///  \t, \T => 0x09
///  \\ => \
///  \nnn => byte with numeric value given by nnn interpreted as octal
///          (wraps on overflow, number of digits can be 1-3 for ASCII strings
///          and 1-7 for wide strings)
///  \xhh => byte with numeric value given by hh interpreted as hex
///          (number of digits can be 0-2 for ASCII strings and 0-4 for
///          wide strings)
///  \<\r+> => \
///  \<[\r\n\t ]+> => <nothing>
///
/// Special cases:
///  <\t> => 1-8 spaces, dependent on columns in the source rc file itself
///  <\r> => <nothing>
///  <\n+><\w+?\n?> => <space><\n>
///
/// Special, especially weird case:
///  \"" => "
/// NOTE: This leads to footguns because the preprocessor can start parsing things
///       out-of-sync with the RC compiler, expanding macros within string literals, etc.
///       This parse function handles this case the same as the Windows RC compiler, but
///       \" within a string literal is treated as an error by the lexer, so the relevant
///       branches should never actually be hit during this function.
pub const IterativeStringParser = struct {
    source: []const u8,
    code_page: CodePage,
    /// The type of the string inferred by the prefix (L"" or "")
    /// This is what matters for things like the maximum digits in an
    /// escape sequence, whether or not invalid escape sequences are skipped, etc.
    declared_string_type: StringType,
    pending_codepoint: ?u21 = null,
    num_pending_spaces: u8 = 0,
    index: usize = 0,
    column: usize = 0,
    diagnostics: ?DiagnosticsContext = null,
    seen_tab: bool = false,

    const State = enum {
        normal,
        quote,
        newline,
        escaped,
        escaped_cr,
        escaped_newlines,
        escaped_octal,
        escaped_hex,
    };

    pub fn init(bytes: SourceBytes, options: StringParseOptions) IterativeStringParser {
        const declared_string_type: StringType = switch (bytes.slice[0]) {
            'L', 'l' => .wide,
            else => .ascii,
        };
        var source = bytes.slice[1 .. bytes.slice.len - 1]; // remove ""
        var column = options.start_column + 1; // for the removed "
        if (declared_string_type == .wide) {
            source = source[1..]; // remove L
            column += 1; // for the removed L
        }
        return .{
            .source = source,
            .code_page = bytes.code_page,
            .declared_string_type = declared_string_type,
            .column = column,
            .diagnostics = options.diagnostics,
        };
    }

    pub const ParsedCodepoint = struct {
        codepoint: u21,
        /// Note: If this is true, `codepoint` will be a value with a max of maxInt(u16).
        /// This is enforced by using saturating arithmetic, so in e.g. a wide string literal the
        /// octal escape sequence \7777777 (2,097,151) will be parsed into the value 0xFFFF (65,535).
        /// If the value needs to be truncated to a smaller integer (for ASCII string literals), then that
        /// must be done by the caller.
        from_escaped_integer: bool = false,
    };

    pub fn next(self: *IterativeStringParser) std.mem.Allocator.Error!?ParsedCodepoint {
        const result = try self.nextUnchecked();
        if (self.diagnostics != null and result != null and !result.?.from_escaped_integer) {
            switch (result.?.codepoint) {
                0x900, 0xA00, 0xA0D, 0x2000, 0xFFFE, 0xD00 => {
                    const err: ErrorDetails.Error = if (result.?.codepoint == 0xD00)
                        .rc_would_miscompile_codepoint_skip
                    else
                        .rc_would_miscompile_codepoint_byte_swap;
                    try self.diagnostics.?.diagnostics.append(ErrorDetails{
                        .err = err,
                        .type = .warning,
                        .token = self.diagnostics.?.token,
                        .extra = .{ .number = result.?.codepoint },
                    });
                    try self.diagnostics.?.diagnostics.append(ErrorDetails{
                        .err = err,
                        .type = .note,
                        .token = self.diagnostics.?.token,
                        .print_source_line = false,
                        .extra = .{ .number = result.?.codepoint },
                    });
                },
                else => {},
            }
        }
        return result;
    }

    pub fn nextUnchecked(self: *IterativeStringParser) std.mem.Allocator.Error!?ParsedCodepoint {
        if (self.num_pending_spaces > 0) {
            // Ensure that we don't get into this predicament so we can ensure that
            // the order of processing any pending stuff doesn't matter
            std.debug.assert(self.pending_codepoint == null);
            self.num_pending_spaces -= 1;
            return .{ .codepoint = ' ' };
        }
        if (self.pending_codepoint) |pending_codepoint| {
            self.pending_codepoint = null;
            return .{ .codepoint = pending_codepoint };
        }
        if (self.index >= self.source.len) return null;

        var state: State = .normal;
        var string_escape_n: u16 = 0;
        var string_escape_i: u8 = 0;
        const max_octal_escape_digits: u8 = switch (self.declared_string_type) {
            .ascii => 3,
            .wide => 7,
        };
        const max_hex_escape_digits: u8 = switch (self.declared_string_type) {
            .ascii => 2,
            .wide => 4,
        };

        var backtrack: bool = undefined;
        while (self.code_page.codepointAt(self.index, self.source)) |codepoint| : ({
            if (!backtrack) self.index += codepoint.byte_len;
        }) {
            backtrack = false;
            const c = codepoint.value;
            defer {
                if (!backtrack) {
                    if (c == '\t') {
                        self.column += columnsUntilTabStop(self.column, 8);
                    } else {
                        self.column += codepoint.byte_len;
                    }
                }
            }
            switch (state) {
                .normal => switch (c) {
                    '\\' => state = .escaped,
                    '"' => state = .quote,
                    '\r' => {},
                    '\n' => state = .newline,
                    '\t' => {
                        // Only warn about a tab getting converted to spaces once per string
                        if (self.diagnostics != null and !self.seen_tab) {
                            try self.diagnostics.?.diagnostics.append(ErrorDetails{
                                .err = .tab_converted_to_spaces,
                                .type = .warning,
                                .token = self.diagnostics.?.token,
                            });
                            try self.diagnostics.?.diagnostics.append(ErrorDetails{
                                .err = .tab_converted_to_spaces,
                                .type = .note,
                                .token = self.diagnostics.?.token,
                                .print_source_line = false,
                            });
                            self.seen_tab = true;
                        }
                        const cols = columnsUntilTabStop(self.column, 8);
                        self.num_pending_spaces = @intCast(cols - 1);
                        self.index += codepoint.byte_len;
                        return .{ .codepoint = ' ' };
                    },
                    else => {
                        self.index += codepoint.byte_len;
                        return .{ .codepoint = c };
                    },
                },
                .quote => switch (c) {
                    '"' => {
                        // "" => "
                        self.index += codepoint.byte_len;
                        return .{ .codepoint = '"' };
                    },
                    else => unreachable, // this is a bug in the lexer
                },
                .newline => switch (c) {
                    '\r', ' ', '\t', '\n', '\x0b', '\x0c', '\xa0' => {},
                    else => {
                        // we intentionally avoid incrementing self.index
                        // to handle the current char in the next call,
                        // and we set backtrack so column count is handled correctly
                        backtrack = true;

                        // <space><newline>
                        self.pending_codepoint = '\n';
                        return .{ .codepoint = ' ' };
                    },
                },
                .escaped => switch (c) {
                    '\r' => state = .escaped_cr,
                    '\n' => state = .escaped_newlines,
                    '0'...'7' => {
                        string_escape_n = std.fmt.charToDigit(@intCast(c), 8) catch unreachable;
                        string_escape_i = 1;
                        state = .escaped_octal;
                    },
                    'x', 'X' => {
                        string_escape_n = 0;
                        string_escape_i = 0;
                        state = .escaped_hex;
                    },
                    else => {
                        switch (c) {
                            'a', 'A' => {
                                self.index += codepoint.byte_len;
                                return .{ .codepoint = '\x08' };
                            }, // might be a bug in RC, but matches its behavior
                            'n' => {
                                self.index += codepoint.byte_len;
                                return .{ .codepoint = '\n' };
                            },
                            'r' => {
                                self.index += codepoint.byte_len;
                                return .{ .codepoint = '\r' };
                            },
                            't', 'T' => {
                                self.index += codepoint.byte_len;
                                return .{ .codepoint = '\t' };
                            },
                            '\\' => {
                                self.index += codepoint.byte_len;
                                return .{ .codepoint = '\\' };
                            },
                            '"' => {
                                // \" is a special case that doesn't get the \ included,
                                backtrack = true;
                            },
                            else => switch (self.declared_string_type) {
                                .wide => {}, // invalid escape sequences are skipped in wide strings
                                .ascii => {
                                    // we intentionally avoid incrementing self.index
                                    // to handle the current char in the next call,
                                    // and we set backtrack so column count is handled correctly
                                    backtrack = true;
                                    return .{ .codepoint = '\\' };
                                },
                            },
                        }
                        state = .normal;
                    },
                },
                .escaped_cr => switch (c) {
                    '\r' => {},
                    '\n' => state = .escaped_newlines,
                    else => {
                        // we intentionally avoid incrementing self.index
                        // to handle the current char in the next call,
                        // and we set backtrack so column count is handled correctly
                        backtrack = true;
                        return .{ .codepoint = '\\' };
                    },
                },
                .escaped_newlines => switch (c) {
                    '\r', '\n', '\t', ' ', '\x0b', '\x0c', '\xa0' => {},
                    else => {
                        // backtrack so that we handle the current char properly
                        backtrack = true;
                        state = .normal;
                    },
                },
                .escaped_octal => switch (c) {
                    '0'...'7' => {
                        string_escape_n *%= 8;
                        string_escape_n +%= std.fmt.charToDigit(@intCast(c), 8) catch unreachable;
                        string_escape_i += 1;
                        if (string_escape_i == max_octal_escape_digits) {
                            self.index += codepoint.byte_len;
                            return .{ .codepoint = string_escape_n, .from_escaped_integer = true };
                        }
                    },
                    else => {
                        // we intentionally avoid incrementing self.index
                        // to handle the current char in the next call,
                        // and we set backtrack so column count is handled correctly
                        backtrack = true;

                        // write out whatever byte we have parsed so far
                        return .{ .codepoint = string_escape_n, .from_escaped_integer = true };
                    },
                },
                .escaped_hex => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        string_escape_n *= 16;
                        string_escape_n += std.fmt.charToDigit(@intCast(c), 16) catch unreachable;
                        string_escape_i += 1;
                        if (string_escape_i == max_hex_escape_digits) {
                            self.index += codepoint.byte_len;
                            return .{ .codepoint = string_escape_n, .from_escaped_integer = true };
                        }
                    },
                    else => {
                        // we intentionally avoid incrementing self.index
                        // to handle the current char in the next call,
                        // and we set backtrack so column count is handled correctly
                        backtrack = true;

                        // write out whatever byte we have parsed so far
                        // (even with 0 actual digits, \x alone parses to 0)
                        const escaped_value = string_escape_n;
                        return .{ .codepoint = escaped_value, .from_escaped_integer = true };
                    },
                },
            }
        }

        switch (state) {
            .normal, .escaped_newlines => {},
            .newline => {
                // <space><newline>
                self.pending_codepoint = '\n';
                return .{ .codepoint = ' ' };
            },
            .escaped, .escaped_cr => return .{ .codepoint = '\\' },
            .escaped_octal, .escaped_hex => {
                return .{ .codepoint = string_escape_n, .from_escaped_integer = true };
            },
            .quote => unreachable, // this is a bug in the lexer
        }

        return null;
    }
};

pub const StringParseOptions = struct {
    start_column: usize = 0,
    diagnostics: ?DiagnosticsContext = null,
    output_code_page: CodePage = .windows1252,
};

pub fn parseQuotedString(
    comptime literal_type: StringType,
    allocator: std.mem.Allocator,
    bytes: SourceBytes,
    options: StringParseOptions,
) !(switch (literal_type) {
    .ascii => []u8,
    .wide => [:0]u16,
}) {
    const T = if (literal_type == .ascii) u8 else u16;
    std.debug.assert(bytes.slice.len >= 2); // must at least have 2 double quote chars

    var buf = try std.ArrayList(T).initCapacity(allocator, bytes.slice.len);
    errdefer buf.deinit();

    var iterative_parser = IterativeStringParser.init(bytes, options);

    while (try iterative_parser.next()) |parsed| {
        const c = parsed.codepoint;
        if (parsed.from_escaped_integer) {
            // We truncate here to get the correct behavior for ascii strings
            try buf.append(std.mem.nativeToLittle(T, @truncate(c)));
        } else {
            switch (literal_type) {
                .ascii => switch (options.output_code_page) {
                    .windows1252 => {
                        if (windows1252.bestFitFromCodepoint(c)) |best_fit| {
                            try buf.append(best_fit);
                        } else if (c < 0x10000 or c == code_pages.Codepoint.invalid) {
                            try buf.append('?');
                        } else {
                            try buf.appendSlice("??");
                        }
                    },
                    .utf8 => {
                        var codepoint_to_encode = c;
                        if (c == code_pages.Codepoint.invalid) {
                            codepoint_to_encode = '�';
                        }
                        var utf8_buf: [4]u8 = undefined;
                        const utf8_len = std.unicode.utf8Encode(codepoint_to_encode, &utf8_buf) catch unreachable;
                        try buf.appendSlice(utf8_buf[0..utf8_len]);
                    },
                    else => unreachable, // Unsupported code page
                },
                .wide => {
                    if (c == code_pages.Codepoint.invalid) {
                        try buf.append(std.mem.nativeToLittle(u16, '�'));
                    } else if (c < 0x10000) {
                        const short: u16 = @intCast(c);
                        try buf.append(std.mem.nativeToLittle(u16, short));
                    } else {
                        const high = @as(u16, @intCast((c - 0x10000) >> 10)) + 0xD800;
                        try buf.append(std.mem.nativeToLittle(u16, high));
                        const low = @as(u16, @intCast(c & 0x3FF)) + 0xDC00;
                        try buf.append(std.mem.nativeToLittle(u16, low));
                    }
                },
            }
        }
    }

    if (literal_type == .wide) {
        return buf.toOwnedSliceSentinel(0);
    } else {
        return buf.toOwnedSlice();
    }
}

pub fn parseQuotedAsciiString(allocator: std.mem.Allocator, bytes: SourceBytes, options: StringParseOptions) ![]u8 {
    std.debug.assert(bytes.slice.len >= 2); // ""
    return parseQuotedString(.ascii, allocator, bytes, options);
}

pub fn parseQuotedWideString(allocator: std.mem.Allocator, bytes: SourceBytes, options: StringParseOptions) ![:0]u16 {
    std.debug.assert(bytes.slice.len >= 3); // L""
    return parseQuotedString(.wide, allocator, bytes, options);
}

pub fn parseQuotedStringAsWideString(allocator: std.mem.Allocator, bytes: SourceBytes, options: StringParseOptions) ![:0]u16 {
    std.debug.assert(bytes.slice.len >= 2); // ""
    return parseQuotedString(.wide, allocator, bytes, options);
}

test "parse quoted ascii string" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    try std.testing.expectEqualSlices(u8, "hello", try parseQuotedAsciiString(arena, .{
        .slice =
        \\"hello"
        ,
        .code_page = .windows1252,
    }, .{}));
    // hex with 0 digits
    try std.testing.expectEqualSlices(u8, "\x00", try parseQuotedAsciiString(arena, .{
        .slice =
        \\"\x"
        ,
        .code_page = .windows1252,
    }, .{}));
    // hex max of 2 digits
    try std.testing.expectEqualSlices(u8, "\xFFf", try parseQuotedAsciiString(arena, .{
        .slice =
        \\"\XfFf"
        ,
        .code_page = .windows1252,
    }, .{}));
    // octal with invalid octal digit
    try std.testing.expectEqualSlices(u8, "\x019", try parseQuotedAsciiString(arena, .{
        .slice =
        \\"\19"
        ,
        .code_page = .windows1252,
    }, .{}));
    // escaped quotes
    try std.testing.expectEqualSlices(u8, " \" ", try parseQuotedAsciiString(arena, .{
        .slice =
        \\" "" "
        ,
        .code_page = .windows1252,
    }, .{}));
    // backslash right before escaped quotes
    try std.testing.expectEqualSlices(u8, "\"", try parseQuotedAsciiString(arena, .{
        .slice =
        \\"\"""
        ,
        .code_page = .windows1252,
    }, .{}));
    // octal overflow
    try std.testing.expectEqualSlices(u8, "\x01", try parseQuotedAsciiString(arena, .{
        .slice =
        \\"\401"
        ,
        .code_page = .windows1252,
    }, .{}));
    // escapes
    try std.testing.expectEqualSlices(u8, "\x08\n\r\t\\", try parseQuotedAsciiString(arena, .{
        .slice =
        \\"\a\n\r\t\\"
        ,
        .code_page = .windows1252,
    }, .{}));
    // uppercase escapes
    try std.testing.expectEqualSlices(u8, "\x08\\N\\R\t\\", try parseQuotedAsciiString(arena, .{
        .slice =
        \\"\A\N\R\T\\"
        ,
        .code_page = .windows1252,
    }, .{}));
    // backslash on its own
    try std.testing.expectEqualSlices(u8, "\\", try parseQuotedAsciiString(arena, .{
        .slice =
        \\"\"
        ,
        .code_page = .windows1252,
    }, .{}));
    // unrecognized escapes
    try std.testing.expectEqualSlices(u8, "\\b", try parseQuotedAsciiString(arena, .{
        .slice =
        \\"\b"
        ,
        .code_page = .windows1252,
    }, .{}));
    // escaped carriage returns
    try std.testing.expectEqualSlices(u8, "\\", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\\\r\r\r\r\r\"", .code_page = .windows1252 },
        .{},
    ));
    // escaped newlines
    try std.testing.expectEqualSlices(u8, "", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\\\n\n\n\n\n\"", .code_page = .windows1252 },
        .{},
    ));
    // escaped CRLF pairs
    try std.testing.expectEqualSlices(u8, "", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\\\r\n\r\n\r\n\r\n\r\n\"", .code_page = .windows1252 },
        .{},
    ));
    // escaped newlines with other whitespace
    try std.testing.expectEqualSlices(u8, "", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\\\n    \t\r\n \r\t\n  \t\"", .code_page = .windows1252 },
        .{},
    ));
    // literal tab characters get converted to spaces (dependent on source file columns)
    try std.testing.expectEqualSlices(u8, "       ", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\t\"", .code_page = .windows1252 },
        .{},
    ));
    try std.testing.expectEqualSlices(u8, "abc    ", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"abc\t\"", .code_page = .windows1252 },
        .{},
    ));
    try std.testing.expectEqualSlices(u8, "abcdefg        ", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"abcdefg\t\"", .code_page = .windows1252 },
        .{},
    ));
    try std.testing.expectEqualSlices(u8, "\\      ", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\\\t\"", .code_page = .windows1252 },
        .{},
    ));
    // literal CR's get dropped
    try std.testing.expectEqualSlices(u8, "", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\r\r\r\r\r\"", .code_page = .windows1252 },
        .{},
    ));
    // contiguous newlines and whitespace get collapsed to <space><newline>
    try std.testing.expectEqualSlices(u8, " \n", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\n\r\r  \r\n \t  \"", .code_page = .windows1252 },
        .{},
    ));
}

test "parse quoted ascii string with utf8 code page" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    try std.testing.expectEqualSlices(u8, "", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\"", .code_page = .utf8 },
        .{},
    ));
    // Codepoints that don't have a Windows-1252 representation get converted to ?
    try std.testing.expectEqualSlices(u8, "?????????", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"кириллица\"", .code_page = .utf8 },
        .{},
    ));
    // Codepoints that have a best fit mapping get converted accordingly,
    // these are box drawing codepoints
    try std.testing.expectEqualSlices(u8, "\x2b\x2d\x2b", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"┌─┐\"", .code_page = .utf8 },
        .{},
    ));
    // Invalid UTF-8 gets converted to ? depending on well-formedness
    try std.testing.expectEqualSlices(u8, "????", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\xf0\xf0\x80\x80\x80\"", .code_page = .utf8 },
        .{},
    ));
    // Codepoints that would require a UTF-16 surrogate pair get converted to ??
    try std.testing.expectEqualSlices(u8, "??", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\xF2\xAF\xBA\xB4\"", .code_page = .utf8 },
        .{},
    ));

    // Output code page changes how invalid UTF-8 gets converted, since it
    // now encodes the result as UTF-8 so it can write replacement characters.
    try std.testing.expectEqualSlices(u8, "����", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\xf0\xf0\x80\x80\x80\"", .code_page = .utf8 },
        .{ .output_code_page = .utf8 },
    ));
    try std.testing.expectEqualSlices(u8, "\xF2\xAF\xBA\xB4", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\xF2\xAF\xBA\xB4\"", .code_page = .utf8 },
        .{ .output_code_page = .utf8 },
    ));

    // This used to cause integer overflow when reconsuming the 4-byte long codepoint
    // after the escaped CRLF pair.
    try std.testing.expectEqualSlices(u8, "\u{10348}", try parseQuotedAsciiString(
        arena,
        .{ .slice = "\"\\\r\n\u{10348}\"", .code_page = .utf8 },
        .{ .output_code_page = .utf8 },
    ));
}

test "parse quoted wide string" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    try std.testing.expectEqualSentinel(u16, 0, std.unicode.utf8ToUtf16LeStringLiteral("hello"), try parseQuotedWideString(arena, .{
        .slice =
        \\L"hello"
        ,
        .code_page = .windows1252,
    }, .{}));
    // hex with 0 digits
    try std.testing.expectEqualSentinel(u16, 0, &[_:0]u16{0x0}, try parseQuotedWideString(arena, .{
        .slice =
        \\L"\x"
        ,
        .code_page = .windows1252,
    }, .{}));
    // hex max of 4 digits
    try std.testing.expectEqualSentinel(u16, 0, &[_:0]u16{ std.mem.nativeToLittle(u16, 0xFFFF), std.mem.nativeToLittle(u16, 'f') }, try parseQuotedWideString(arena, .{
        .slice =
        \\L"\XfFfFf"
        ,
        .code_page = .windows1252,
    }, .{}));
    // octal max of 7 digits
    try std.testing.expectEqualSentinel(u16, 0, &[_:0]u16{ std.mem.nativeToLittle(u16, 0x9493), std.mem.nativeToLittle(u16, '3'), std.mem.nativeToLittle(u16, '3') }, try parseQuotedWideString(arena, .{
        .slice =
        \\L"\111222333"
        ,
        .code_page = .windows1252,
    }, .{}));
    // octal overflow
    try std.testing.expectEqualSentinel(u16, 0, &[_:0]u16{std.mem.nativeToLittle(u16, 0xFF01)}, try parseQuotedWideString(arena, .{
        .slice =
        \\L"\777401"
        ,
        .code_page = .windows1252,
    }, .{}));
    // literal tab characters get converted to spaces (dependent on source file columns)
    try std.testing.expectEqualSentinel(u16, 0, std.unicode.utf8ToUtf16LeStringLiteral("abcdefg       "), try parseQuotedWideString(
        arena,
        .{ .slice = "L\"abcdefg\t\"", .code_page = .windows1252 },
        .{},
    ));
    // Windows-1252 conversion
    try std.testing.expectEqualSentinel(u16, 0, std.unicode.utf8ToUtf16LeStringLiteral("ðð€€€"), try parseQuotedWideString(
        arena,
        .{ .slice = "L\"\xf0\xf0\x80\x80\x80\"", .code_page = .windows1252 },
        .{},
    ));
    // Invalid escape sequences are skipped
    try std.testing.expectEqualSentinel(u16, 0, std.unicode.utf8ToUtf16LeStringLiteral(""), try parseQuotedWideString(
        arena,
        .{ .slice = "L\"\\H\"", .code_page = .windows1252 },
        .{},
    ));
}

test "parse quoted wide string with utf8 code page" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    try std.testing.expectEqualSentinel(u16, 0, &[_:0]u16{}, try parseQuotedWideString(
        arena,
        .{ .slice = "L\"\"", .code_page = .utf8 },
        .{},
    ));
    try std.testing.expectEqualSentinel(u16, 0, std.unicode.utf8ToUtf16LeStringLiteral("кириллица"), try parseQuotedWideString(
        arena,
        .{ .slice = "L\"кириллица\"", .code_page = .utf8 },
        .{},
    ));
    // Invalid UTF-8 gets converted to � depending on well-formedness
    try std.testing.expectEqualSentinel(u16, 0, std.unicode.utf8ToUtf16LeStringLiteral("����"), try parseQuotedWideString(
        arena,
        .{ .slice = "L\"\xf0\xf0\x80\x80\x80\"", .code_page = .utf8 },
        .{},
    ));
}

test "parse quoted ascii string as wide string" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    try std.testing.expectEqualSentinel(u16, 0, std.unicode.utf8ToUtf16LeStringLiteral("кириллица"), try parseQuotedStringAsWideString(
        arena,
        .{ .slice = "\"кириллица\"", .code_page = .utf8 },
        .{},
    ));
    // Whether or not invalid escapes are skipped is still determined by the L prefix
    try std.testing.expectEqualSentinel(u16, 0, std.unicode.utf8ToUtf16LeStringLiteral("\\H"), try parseQuotedStringAsWideString(
        arena,
        .{ .slice = "\"\\H\"", .code_page = .windows1252 },
        .{},
    ));
    try std.testing.expectEqualSentinel(u16, 0, std.unicode.utf8ToUtf16LeStringLiteral(""), try parseQuotedStringAsWideString(
        arena,
        .{ .slice = "L\"\\H\"", .code_page = .windows1252 },
        .{},
    ));
    // Maximum escape sequence value is also determined by the L prefix
    try std.testing.expectEqualSentinel(u16, 0, &[_:0]u16{ std.mem.nativeToLittle(u16, 0x12), std.mem.nativeToLittle(u16, '3'), std.mem.nativeToLittle(u16, '4') }, try parseQuotedStringAsWideString(
        arena,
        .{ .slice = "\"\\x1234\"", .code_page = .windows1252 },
        .{},
    ));
    try std.testing.expectEqualSentinel(u16, 0, &[_:0]u16{std.mem.nativeToLittle(u16, 0x1234)}, try parseQuotedStringAsWideString(
        arena,
        .{ .slice = "L\"\\x1234\"", .code_page = .windows1252 },
        .{},
    ));
}

pub fn columnsUntilTabStop(column: usize, tab_columns: usize) usize {
    // 0 => 8, 1 => 7, 2 => 6, 3 => 5, 4 => 4
    // 5 => 3, 6 => 2, 7 => 1, 8 => 8
    return tab_columns - (column % tab_columns);
}

pub fn columnWidth(cur_column: usize, c: u8, tab_columns: usize) usize {
    return switch (c) {
        '\t' => columnsUntilTabStop(cur_column, tab_columns),
        else => 1,
    };
}

pub const Number = struct {
    value: u32,
    is_long: bool = false,

    pub fn asWord(self: Number) u16 {
        return @truncate(self.value);
    }

    pub fn evaluateOperator(lhs: Number, operator_char: u8, rhs: Number) Number {
        const result = switch (operator_char) {
            '-' => lhs.value -% rhs.value,
            '+' => lhs.value +% rhs.value,
            '|' => lhs.value | rhs.value,
            '&' => lhs.value & rhs.value,
            else => unreachable, // invalid operator, this would be a lexer/parser bug
        };
        return .{
            .value = result,
            .is_long = lhs.is_long or rhs.is_long,
        };
    }
};

/// Assumes that number literals normally rejected by RC's preprocessor
/// are similarly rejected before being parsed.
///
/// Relevant RC preprocessor errors:
///  RC2021: expected exponent value, not '<digit>'
///   example that is rejected: 1e1
///   example that is accepted: 1ea
///   (this function will parse the two examples above the same)
pub fn parseNumberLiteral(bytes: SourceBytes) Number {
    std.debug.assert(bytes.slice.len > 0);
    var result = Number{ .value = 0, .is_long = false };
    var radix: u8 = 10;
    var buf = bytes.slice;

    const Prefix = enum { none, minus, complement };
    var prefix: Prefix = .none;
    switch (buf[0]) {
        '-' => {
            prefix = .minus;
            buf = buf[1..];
        },
        '~' => {
            prefix = .complement;
            buf = buf[1..];
        },
        else => {},
    }

    if (buf.len > 2 and buf[0] == '0') {
        switch (buf[1]) {
            'o' => { // octal radix prefix is case-sensitive
                radix = 8;
                buf = buf[2..];
            },
            'x', 'X' => {
                radix = 16;
                buf = buf[2..];
            },
            else => {},
        }
    }

    var i: usize = 0;
    while (bytes.code_page.codepointAt(i, buf)) |codepoint| : (i += codepoint.byte_len) {
        const c = codepoint.value;
        if (c == 'L' or c == 'l') {
            result.is_long = true;
            break;
        }
        const digit = switch (c) {
            // On invalid digit for the radix, just stop parsing but don't fail
            0x00...0x7F => std.fmt.charToDigit(@intCast(c), radix) catch break,
            else => break,
        };

        if (result.value != 0) {
            result.value *%= radix;
        }
        result.value +%= digit;
    }

    switch (prefix) {
        .none => {},
        .minus => result.value = 0 -% result.value,
        .complement => result.value = ~result.value,
    }

    return result;
}

test "parse number literal" {
    try std.testing.expectEqual(Number{ .value = 0, .is_long = false }, parseNumberLiteral(.{ .slice = "0", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 1, .is_long = false }, parseNumberLiteral(.{ .slice = "1", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 1, .is_long = true }, parseNumberLiteral(.{ .slice = "1L", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 1, .is_long = true }, parseNumberLiteral(.{ .slice = "1l", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 1, .is_long = false }, parseNumberLiteral(.{ .slice = "1garbageL", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 4294967295, .is_long = false }, parseNumberLiteral(.{ .slice = "4294967295", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 0, .is_long = false }, parseNumberLiteral(.{ .slice = "4294967296", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 1, .is_long = true }, parseNumberLiteral(.{ .slice = "4294967297L", .code_page = .windows1252 }));

    // can handle any length of number, wraps on overflow appropriately
    const big_overflow = parseNumberLiteral(.{ .slice = "1000000000000000000000000000000000000000000000000000000000000000000000000000000090000000001", .code_page = .windows1252 });
    try std.testing.expectEqual(Number{ .value = 4100654081, .is_long = false }, big_overflow);
    try std.testing.expectEqual(@as(u16, 1025), big_overflow.asWord());

    try std.testing.expectEqual(Number{ .value = 0x20, .is_long = false }, parseNumberLiteral(.{ .slice = "0x20", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 0x2A, .is_long = true }, parseNumberLiteral(.{ .slice = "0x2AL", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 0x2A, .is_long = true }, parseNumberLiteral(.{ .slice = "0x2aL", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 0x2A, .is_long = true }, parseNumberLiteral(.{ .slice = "0x2aL", .code_page = .windows1252 }));

    try std.testing.expectEqual(Number{ .value = 0o20, .is_long = false }, parseNumberLiteral(.{ .slice = "0o20", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 0o20, .is_long = true }, parseNumberLiteral(.{ .slice = "0o20L", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 0o2, .is_long = false }, parseNumberLiteral(.{ .slice = "0o29", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 0, .is_long = false }, parseNumberLiteral(.{ .slice = "0O29", .code_page = .windows1252 }));

    try std.testing.expectEqual(Number{ .value = 0xFFFFFFFF, .is_long = false }, parseNumberLiteral(.{ .slice = "-1", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 0xFFFFFFFE, .is_long = false }, parseNumberLiteral(.{ .slice = "~1", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 0xFFFFFFFF, .is_long = true }, parseNumberLiteral(.{ .slice = "-4294967297L", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 0xFFFFFFFE, .is_long = true }, parseNumberLiteral(.{ .slice = "~4294967297L", .code_page = .windows1252 }));
    try std.testing.expectEqual(Number{ .value = 0xFFFFFFFD, .is_long = false }, parseNumberLiteral(.{ .slice = "-0X3", .code_page = .windows1252 }));

    // anything after L is ignored
    try std.testing.expectEqual(Number{ .value = 0x2A, .is_long = true }, parseNumberLiteral(.{ .slice = "0x2aL5", .code_page = .windows1252 }));
}
