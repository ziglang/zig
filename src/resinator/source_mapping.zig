const std = @import("std");
const Allocator = std.mem.Allocator;
const UncheckedSliceWriter = @import("utils.zig").UncheckedSliceWriter;
const parseQuotedAsciiString = @import("literals.zig").parseQuotedAsciiString;
const lex = @import("lex.zig");

pub const ParseLineCommandsResult = struct {
    result: []u8,
    mappings: SourceMappings,
};

const CurrentMapping = struct {
    line_num: usize = 1,
    filename: std.ArrayListUnmanaged(u8) = .{},
    pending: bool = true,
    ignore_contents: bool = false,
};

pub const ParseAndRemoveLineCommandsOptions = struct {
    initial_filename: ?[]const u8 = null,
};

/// Parses and removes #line commands as well as all source code that is within a file
/// with .c or .h extensions.
///
/// > RC treats files with the .c and .h extensions in a special manner. It
/// > assumes that a file with one of these extensions does not contain
/// > resources. If a file has the .c or .h file name extension, RC ignores all
/// > lines in the file except the preprocessor directives. Therefore, to
/// > include a file that contains resources in another resource script, give
/// > the file to be included an extension other than .c or .h.
/// from https://learn.microsoft.com/en-us/windows/win32/menurc/preprocessor-directives
///
/// Returns a slice of `buf` with the aforementioned stuff removed as well as a mapping
/// between the lines and their corresponding lines in their original files.
///
/// `buf` must be at least as long as `source`
/// In-place transformation is supported (i.e. `source` and `buf` can be the same slice)
///
/// If `options.initial_filename` is provided, that filename is guaranteed to be
/// within the `mappings.files` table and `root_filename_offset` will be set appropriately.
pub fn parseAndRemoveLineCommands(allocator: Allocator, source: []const u8, buf: []u8, options: ParseAndRemoveLineCommandsOptions) !ParseLineCommandsResult {
    var parse_result = ParseLineCommandsResult{
        .result = undefined,
        .mappings = .{},
    };
    errdefer parse_result.mappings.deinit(allocator);

    var current_mapping: CurrentMapping = .{};
    defer current_mapping.filename.deinit(allocator);

    if (options.initial_filename) |initial_filename| {
        try current_mapping.filename.appendSlice(allocator, initial_filename);
        parse_result.mappings.root_filename_offset = try parse_result.mappings.files.put(allocator, initial_filename);
    }

    std.debug.assert(buf.len >= source.len);
    var result = UncheckedSliceWriter{ .slice = buf };
    const State = enum {
        line_start,
        preprocessor,
        non_preprocessor,
    };
    var state: State = .line_start;
    var index: usize = 0;
    var pending_start: ?usize = null;
    var preprocessor_start: usize = 0;
    var line_number: usize = 1;
    while (index < source.len) : (index += 1) {
        const c = source[index];
        switch (state) {
            .line_start => switch (c) {
                '#' => {
                    preprocessor_start = index;
                    state = .preprocessor;
                    if (pending_start == null) {
                        pending_start = index;
                    }
                },
                '\r', '\n' => {
                    const is_crlf = formsLineEndingPair(source, c, index + 1);
                    try handleLineEnd(allocator, line_number, &parse_result.mappings, &current_mapping);
                    if (!current_mapping.ignore_contents) {
                        result.write(c);
                        if (is_crlf) result.write(source[index + 1]);
                        line_number += 1;
                    }
                    if (is_crlf) index += 1;
                    pending_start = null;
                },
                ' ', '\t', '\x0b', '\x0c' => {
                    if (pending_start == null) {
                        pending_start = index;
                    }
                },
                else => {
                    state = .non_preprocessor;
                    if (pending_start != null) {
                        if (!current_mapping.ignore_contents) {
                            result.writeSlice(source[pending_start.? .. index + 1]);
                        }
                        pending_start = null;
                        continue;
                    }
                    if (!current_mapping.ignore_contents) {
                        result.write(c);
                    }
                },
            },
            .preprocessor => switch (c) {
                '\r', '\n' => {
                    // Now that we have the full line we can decide what to do with it
                    const preprocessor_str = source[preprocessor_start..index];
                    const is_crlf = formsLineEndingPair(source, c, index + 1);
                    if (std.mem.startsWith(u8, preprocessor_str, "#line")) {
                        try handleLineCommand(allocator, preprocessor_str, &current_mapping);
                    } else {
                        try handleLineEnd(allocator, line_number, &parse_result.mappings, &current_mapping);
                        if (!current_mapping.ignore_contents) {
                            const line_ending_len: usize = if (is_crlf) 2 else 1;
                            result.writeSlice(source[pending_start.? .. index + line_ending_len]);
                            line_number += 1;
                        }
                    }
                    if (is_crlf) index += 1;
                    state = .line_start;
                    pending_start = null;
                },
                else => {},
            },
            .non_preprocessor => switch (c) {
                '\r', '\n' => {
                    const is_crlf = formsLineEndingPair(source, c, index + 1);
                    try handleLineEnd(allocator, line_number, &parse_result.mappings, &current_mapping);
                    if (!current_mapping.ignore_contents) {
                        result.write(c);
                        if (is_crlf) result.write(source[index + 1]);
                        line_number += 1;
                    }
                    if (is_crlf) index += 1;
                    state = .line_start;
                    pending_start = null;
                },
                else => {
                    if (!current_mapping.ignore_contents) {
                        result.write(c);
                    }
                },
            },
        }
    } else {
        switch (state) {
            .line_start => {},
            .non_preprocessor => {
                try handleLineEnd(allocator, line_number, &parse_result.mappings, &current_mapping);
            },
            .preprocessor => {
                // Now that we have the full line we can decide what to do with it
                const preprocessor_str = source[preprocessor_start..index];
                if (std.mem.startsWith(u8, preprocessor_str, "#line")) {
                    try handleLineCommand(allocator, preprocessor_str, &current_mapping);
                } else {
                    try handleLineEnd(allocator, line_number, &parse_result.mappings, &current_mapping);
                    if (!current_mapping.ignore_contents) {
                        result.writeSlice(source[pending_start.?..index]);
                    }
                }
            },
        }
    }

    parse_result.result = result.getWritten();

    // Remove whitespace from the end of the result. This avoids issues when the
    // preprocessor adds a newline to the end of the file, since then the
    // post-preprocessed source could have more lines than the corresponding input source and
    // the inserted line can't be mapped to any lines in the original file.
    // There's no way that whitespace at the end of a file can affect the parsing
    // of the RC script so this is okay to do unconditionally.
    // TODO: There might be a better way around this
    while (parse_result.result.len > 0 and std.ascii.isWhitespace(parse_result.result[parse_result.result.len - 1])) {
        parse_result.result.len -= 1;
    }

    // If there have been no line mappings at all, then we're dealing with an empty file.
    // In this case, we want to fake a line mapping just so that we return something
    // that is useable in the same way that a non-empty mapping would be.
    if (parse_result.mappings.mapping.items.len == 0) {
        try handleLineEnd(allocator, line_number, &parse_result.mappings, &current_mapping);
    }

    return parse_result;
}

/// Note: This should function the same as lex.LineHandler.currentIndexFormsLineEndingPair
pub fn formsLineEndingPair(source: []const u8, line_ending: u8, next_index: usize) bool {
    if (next_index >= source.len) return false;

    const next_ending = source[next_index];
    if (next_ending != '\r' and next_ending != '\n') return false;

    // can't be \n\n or \r\r
    if (line_ending == next_ending) return false;

    return true;
}

pub fn handleLineEnd(allocator: Allocator, post_processed_line_number: usize, mapping: *SourceMappings, current_mapping: *CurrentMapping) !void {
    const filename_offset = try mapping.files.put(allocator, current_mapping.filename.items);

    try mapping.set(allocator, post_processed_line_number, .{
        .start_line = current_mapping.line_num,
        .end_line = current_mapping.line_num,
        .filename_offset = filename_offset,
    });

    current_mapping.line_num += 1;
    current_mapping.pending = false;
}

// TODO: Might want to provide diagnostics on invalid line commands instead of just returning
pub fn handleLineCommand(allocator: Allocator, line_command: []const u8, current_mapping: *CurrentMapping) error{OutOfMemory}!void {
    // TODO: Are there other whitespace characters that should be included?
    var tokenizer = std.mem.tokenize(u8, line_command, " \t");
    const line_directive = tokenizer.next() orelse return; // #line
    if (!std.mem.eql(u8, line_directive, "#line")) return;
    const linenum_str = tokenizer.next() orelse return;
    const linenum = std.fmt.parseUnsigned(usize, linenum_str, 10) catch return;

    var filename_literal = tokenizer.rest();
    while (filename_literal.len > 0 and std.ascii.isWhitespace(filename_literal[filename_literal.len - 1])) {
        filename_literal.len -= 1;
    }
    if (filename_literal.len < 2) return;
    const is_quoted = filename_literal[0] == '"' and filename_literal[filename_literal.len - 1] == '"';
    if (!is_quoted) return;
    const filename = parseFilename(allocator, filename_literal[1 .. filename_literal.len - 1]) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        else => return,
    };
    defer allocator.free(filename);

    // \x00 bytes in the filename is incompatible with how StringTable works
    if (std.mem.indexOfScalar(u8, filename, '\x00') != null) return;

    current_mapping.line_num = linenum;
    current_mapping.filename.clearRetainingCapacity();
    try current_mapping.filename.appendSlice(allocator, filename);
    current_mapping.pending = true;
    current_mapping.ignore_contents = std.ascii.endsWithIgnoreCase(filename, ".c") or std.ascii.endsWithIgnoreCase(filename, ".h");
}

pub fn parseAndRemoveLineCommandsAlloc(allocator: Allocator, source: []const u8, options: ParseAndRemoveLineCommandsOptions) !ParseLineCommandsResult {
    const buf = try allocator.alloc(u8, source.len);
    errdefer allocator.free(buf);
    var result = try parseAndRemoveLineCommands(allocator, source, buf, options);
    result.result = try allocator.realloc(buf, result.result.len);
    return result;
}

/// C-style string parsing with a few caveats:
/// - The str cannot contain newlines or carriage returns
/// - Hex and octal escape are limited to u8
/// - No handling/support for L, u, or U prefixed strings
/// - The start and end double quotes should be omitted from the `str`
/// - Other than the above, does not assume any validity of the strings (i.e. there
///   may be unescaped double quotes within the str) and will return error.InvalidString
///   on any problems found.
///
/// The result is a UTF-8 encoded string.
fn parseFilename(allocator: Allocator, str: []const u8) error{ OutOfMemory, InvalidString }![]u8 {
    const State = enum {
        string,
        escape,
        escape_hex,
        escape_octal,
        escape_u,
    };

    var filename = try std.ArrayList(u8).initCapacity(allocator, str.len);
    errdefer filename.deinit();
    var state: State = .string;
    var index: usize = 0;
    var escape_len: usize = undefined;
    var escape_val: u64 = undefined;
    var escape_expected_len: u8 = undefined;
    while (index < str.len) : (index += 1) {
        const c = str[index];
        switch (state) {
            .string => switch (c) {
                '\\' => state = .escape,
                '"' => return error.InvalidString,
                else => filename.appendAssumeCapacity(c),
            },
            .escape => switch (c) {
                '\'', '"', '\\', '?', 'n', 'r', 't', 'a', 'b', 'e', 'f', 'v' => {
                    const escaped_c = switch (c) {
                        '\'', '"', '\\', '?' => c,
                        'n' => '\n',
                        'r' => '\r',
                        't' => '\t',
                        'a' => '\x07',
                        'b' => '\x08',
                        'e' => '\x1b', // non-standard
                        'f' => '\x0c',
                        'v' => '\x0b',
                        else => unreachable,
                    };
                    filename.appendAssumeCapacity(escaped_c);
                    state = .string;
                },
                'x' => {
                    escape_val = 0;
                    escape_len = 0;
                    state = .escape_hex;
                },
                '0'...'7' => {
                    escape_val = std.fmt.charToDigit(c, 8) catch unreachable;
                    escape_len = 1;
                    state = .escape_octal;
                },
                'u' => {
                    escape_val = 0;
                    escape_len = 0;
                    state = .escape_u;
                    escape_expected_len = 4;
                },
                'U' => {
                    escape_val = 0;
                    escape_len = 0;
                    state = .escape_u;
                    escape_expected_len = 8;
                },
                else => return error.InvalidString,
            },
            .escape_hex => switch (c) {
                '0'...'9', 'a'...'f', 'A'...'F' => {
                    const digit = std.fmt.charToDigit(c, 16) catch unreachable;
                    if (escape_val != 0) escape_val = std.math.mul(u8, @as(u8, @intCast(escape_val)), 16) catch return error.InvalidString;
                    escape_val = std.math.add(u8, @as(u8, @intCast(escape_val)), digit) catch return error.InvalidString;
                    escape_len += 1;
                },
                else => {
                    if (escape_len == 0) return error.InvalidString;
                    filename.appendAssumeCapacity(@intCast(escape_val));
                    state = .string;
                    index -= 1; // reconsume
                },
            },
            .escape_octal => switch (c) {
                '0'...'7' => {
                    const digit = std.fmt.charToDigit(c, 8) catch unreachable;
                    if (escape_val != 0) escape_val = std.math.mul(u8, @as(u8, @intCast(escape_val)), 8) catch return error.InvalidString;
                    escape_val = std.math.add(u8, @as(u8, @intCast(escape_val)), digit) catch return error.InvalidString;
                    escape_len += 1;
                    if (escape_len == 3) {
                        filename.appendAssumeCapacity(@intCast(escape_val));
                        state = .string;
                    }
                },
                else => {
                    if (escape_len == 0) return error.InvalidString;
                    filename.appendAssumeCapacity(@intCast(escape_val));
                    state = .string;
                    index -= 1; // reconsume
                },
            },
            .escape_u => switch (c) {
                '0'...'9', 'a'...'f', 'A'...'F' => {
                    const digit = std.fmt.charToDigit(c, 16) catch unreachable;
                    if (escape_val != 0) escape_val = std.math.mul(u21, @as(u21, @intCast(escape_val)), 16) catch return error.InvalidString;
                    escape_val = std.math.add(u21, @as(u21, @intCast(escape_val)), digit) catch return error.InvalidString;
                    escape_len += 1;
                    if (escape_len == escape_expected_len) {
                        var buf: [4]u8 = undefined;
                        const utf8_len = std.unicode.utf8Encode(@intCast(escape_val), &buf) catch return error.InvalidString;
                        filename.appendSliceAssumeCapacity(buf[0..utf8_len]);
                        state = .string;
                    }
                },
                // Requires escape_expected_len valid hex digits
                else => return error.InvalidString,
            },
        }
    } else {
        switch (state) {
            .string => {},
            .escape, .escape_u => return error.InvalidString,
            .escape_hex => {
                if (escape_len == 0) return error.InvalidString;
                filename.appendAssumeCapacity(@intCast(escape_val));
            },
            .escape_octal => {
                filename.appendAssumeCapacity(@intCast(escape_val));
            },
        }
    }

    return filename.toOwnedSlice();
}

fn testParseFilename(expected: []const u8, input: []const u8) !void {
    const parsed = try parseFilename(std.testing.allocator, input);
    defer std.testing.allocator.free(parsed);

    return std.testing.expectEqualSlices(u8, expected, parsed);
}

test parseFilename {
    try testParseFilename("'\"?\\\t\n\r\x11", "\\'\\\"\\?\\\\\\t\\n\\r\\x11");
    try testParseFilename("\xABz\x53", "\\xABz\\123");
    try testParseFilename("⚡⚡", "\\u26A1\\U000026A1");
    try std.testing.expectError(error.InvalidString, parseFilename(std.testing.allocator, "\""));
    try std.testing.expectError(error.InvalidString, parseFilename(std.testing.allocator, "\\"));
    try std.testing.expectError(error.InvalidString, parseFilename(std.testing.allocator, "\\u"));
    try std.testing.expectError(error.InvalidString, parseFilename(std.testing.allocator, "\\U"));
    try std.testing.expectError(error.InvalidString, parseFilename(std.testing.allocator, "\\x"));
    try std.testing.expectError(error.InvalidString, parseFilename(std.testing.allocator, "\\xZZ"));
    try std.testing.expectError(error.InvalidString, parseFilename(std.testing.allocator, "\\xABCDEF"));
    try std.testing.expectError(error.InvalidString, parseFilename(std.testing.allocator, "\\777"));
}

pub const SourceMappings = struct {
    /// line number -> span where the index is (line number - 1)
    mapping: std.ArrayListUnmanaged(SourceSpan) = .{},
    files: StringTable = .{},
    /// The default assumes that the first filename added is the root file.
    /// The value should be set to the correct offset if that assumption does not hold.
    root_filename_offset: u32 = 0,

    pub const SourceSpan = struct {
        start_line: usize,
        end_line: usize,
        filename_offset: u32,
    };

    pub fn deinit(self: *SourceMappings, allocator: Allocator) void {
        self.files.deinit(allocator);
        self.mapping.deinit(allocator);
    }

    pub fn set(self: *SourceMappings, allocator: Allocator, line_num: usize, span: SourceSpan) !void {
        const ptr = try self.expandAndGet(allocator, line_num);
        ptr.* = span;
    }

    pub fn has(self: SourceMappings, line_num: usize) bool {
        return self.mapping.items.len >= line_num;
    }

    /// Note: `line_num` is 1-indexed
    pub fn get(self: SourceMappings, line_num: usize) SourceSpan {
        return self.mapping.items[line_num - 1];
    }

    pub fn getPtr(self: SourceMappings, line_num: usize) *SourceSpan {
        return &self.mapping.items[line_num - 1];
    }

    /// Expands the number of lines in the mapping to include the requested
    /// line number (if necessary) and returns a pointer to the value at that
    /// line number.
    ///
    /// Note: `line_num` is 1-indexed
    pub fn expandAndGet(self: *SourceMappings, allocator: Allocator, line_num: usize) !*SourceSpan {
        try self.mapping.resize(allocator, line_num);
        return &self.mapping.items[line_num - 1];
    }

    pub fn collapse(self: *SourceMappings, line_num: usize, num_following_lines_to_collapse: usize) void {
        std.debug.assert(num_following_lines_to_collapse > 0);

        var span_to_collapse_into = self.getPtr(line_num);
        const last_collapsed_span = self.get(line_num + num_following_lines_to_collapse);
        span_to_collapse_into.end_line = last_collapsed_span.end_line;

        const after_collapsed_start = line_num + num_following_lines_to_collapse;
        const new_num_lines = self.mapping.items.len - num_following_lines_to_collapse;
        std.mem.copy(SourceSpan, self.mapping.items[line_num..new_num_lines], self.mapping.items[after_collapsed_start..]);

        self.mapping.items.len = new_num_lines;
    }

    /// Returns true if the line is from the main/root file (i.e. not a file that has been
    /// `#include`d).
    pub fn isRootFile(self: *SourceMappings, line_num: usize) bool {
        const line_mapping = self.get(line_num);
        if (line_mapping.filename_offset == self.root_filename_offset) return true;
        return false;
    }
};

test "SourceMappings collapse" {
    const allocator = std.testing.allocator;

    var mappings = SourceMappings{};
    defer mappings.deinit(allocator);
    const filename_offset = try mappings.files.put(allocator, "test.rc");

    try mappings.set(allocator, 1, .{ .start_line = 1, .end_line = 1, .filename_offset = filename_offset });
    try mappings.set(allocator, 2, .{ .start_line = 2, .end_line = 3, .filename_offset = filename_offset });
    try mappings.set(allocator, 3, .{ .start_line = 4, .end_line = 4, .filename_offset = filename_offset });
    try mappings.set(allocator, 4, .{ .start_line = 5, .end_line = 5, .filename_offset = filename_offset });

    mappings.collapse(1, 2);

    try std.testing.expectEqual(@as(usize, 2), mappings.mapping.items.len);
    try std.testing.expectEqual(@as(usize, 4), mappings.mapping.items[0].end_line);
    try std.testing.expectEqual(@as(usize, 5), mappings.mapping.items[1].end_line);
}

/// Same thing as StringTable in Zig's src/Wasm.zig
pub const StringTable = struct {
    data: std.ArrayListUnmanaged(u8) = .{},
    map: std.HashMapUnmanaged(u32, void, std.hash_map.StringIndexContext, std.hash_map.default_max_load_percentage) = .{},

    pub fn deinit(self: *StringTable, allocator: Allocator) void {
        self.data.deinit(allocator);
        self.map.deinit(allocator);
    }

    pub fn put(self: *StringTable, allocator: Allocator, value: []const u8) !u32 {
        const result = try self.map.getOrPutContextAdapted(
            allocator,
            value,
            std.hash_map.StringIndexAdapter{ .bytes = &self.data },
            .{ .bytes = &self.data },
        );
        if (result.found_existing) {
            return result.key_ptr.*;
        }

        try self.data.ensureUnusedCapacity(allocator, value.len + 1);
        const offset: u32 = @intCast(self.data.items.len);

        self.data.appendSliceAssumeCapacity(value);
        self.data.appendAssumeCapacity(0);

        result.key_ptr.* = offset;

        return offset;
    }

    pub fn get(self: StringTable, offset: u32) []const u8 {
        std.debug.assert(offset < self.data.items.len);
        return std.mem.sliceTo(@as([*:0]const u8, @ptrCast(self.data.items.ptr + offset)), 0);
    }

    pub fn getOffset(self: *StringTable, value: []const u8) ?u32 {
        return self.map.getKeyAdapted(
            value,
            std.hash_map.StringIndexAdapter{ .bytes = &self.data },
        );
    }
};

const ExpectedSourceSpan = struct {
    start_line: usize,
    end_line: usize,
    filename: []const u8,
};

fn testParseAndRemoveLineCommands(
    expected: []const u8,
    comptime expected_spans: []const ExpectedSourceSpan,
    source: []const u8,
    options: ParseAndRemoveLineCommandsOptions,
) !void {
    var results = try parseAndRemoveLineCommandsAlloc(std.testing.allocator, source, options);
    defer std.testing.allocator.free(results.result);
    defer results.mappings.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(expected, results.result);

    expectEqualMappings(expected_spans, results.mappings) catch |err| {
        std.debug.print("\nexpected mappings:\n", .{});
        for (expected_spans, 0..) |span, i| {
            const line_num = i + 1;
            std.debug.print("{}: {s}:{}-{}\n", .{ line_num, span.filename, span.start_line, span.end_line });
        }
        std.debug.print("\nactual mappings:\n", .{});
        for (results.mappings.mapping.items, 0..) |span, i| {
            const line_num = i + 1;
            const filename = results.mappings.files.get(span.filename_offset);
            std.debug.print("{}: {s}:{}-{}\n", .{ line_num, filename, span.start_line, span.end_line });
        }
        std.debug.print("\n", .{});
        return err;
    };
}

fn expectEqualMappings(expected_spans: []const ExpectedSourceSpan, mappings: SourceMappings) !void {
    try std.testing.expectEqual(expected_spans.len, mappings.mapping.items.len);
    for (expected_spans, 0..) |expected_span, i| {
        const line_num = i + 1;
        const span = mappings.get(line_num);
        const filename = mappings.files.get(span.filename_offset);
        try std.testing.expectEqual(expected_span.start_line, span.start_line);
        try std.testing.expectEqual(expected_span.end_line, span.end_line);
        try std.testing.expectEqualStrings(expected_span.filename, filename);
    }
}

test "basic" {
    try testParseAndRemoveLineCommands("", &[_]ExpectedSourceSpan{
        .{ .start_line = 1, .end_line = 1, .filename = "blah.rc" },
    }, "#line 1 \"blah.rc\"", .{});
}

test "only removes line commands" {
    try testParseAndRemoveLineCommands(
        \\#pragma code_page(65001)
    , &[_]ExpectedSourceSpan{
        .{ .start_line = 1, .end_line = 1, .filename = "blah.rc" },
    },
        \\#line 1 "blah.rc"
        \\#pragma code_page(65001)
    , .{});
}

test "whitespace and line endings" {
    try testParseAndRemoveLineCommands("", &[_]ExpectedSourceSpan{
        .{ .start_line = 1, .end_line = 1, .filename = "blah.rc" },
    }, "#line  \t 1 \t \"blah.rc\"\r\n", .{});
}

test "example" {
    try testParseAndRemoveLineCommands(
        \\
        \\included RCDATA {"hello"}
    , &[_]ExpectedSourceSpan{
        .{ .start_line = 1, .end_line = 1, .filename = "./included.rc" },
        .{ .start_line = 2, .end_line = 2, .filename = "./included.rc" },
    },
        \\#line 1 "rcdata.rc"
        \\#line 1 "<built-in>"
        \\#line 1 "<built-in>"
        \\#line 355 "<built-in>"
        \\#line 1 "<command line>"
        \\#line 1 "<built-in>"
        \\#line 1 "rcdata.rc"
        \\#line 1 "./header.h"
        \\
        \\
        \\2 RCDATA {"blah"}
        \\
        \\
        \\#line 1 "./included.rc"
        \\
        \\included RCDATA {"hello"}
        \\#line 7 "./header.h"
        \\#line 1 "rcdata.rc"
    , .{});
}

test "CRLF and other line endings" {
    try testParseAndRemoveLineCommands(
        "hello\r\n#pragma code_page(65001)\r\nworld",
        &[_]ExpectedSourceSpan{
            .{ .start_line = 1, .end_line = 1, .filename = "crlf.rc" },
            .{ .start_line = 2, .end_line = 2, .filename = "crlf.rc" },
            .{ .start_line = 3, .end_line = 3, .filename = "crlf.rc" },
        },
        "#line 1 \"crlf.rc\"\r\n#line 1 \"<built-in>\"\r#line 1 \"crlf.rc\"\n\rhello\r\n#pragma code_page(65001)\r\nworld\r\n",
        .{},
    );
}

test "no line commands" {
    try testParseAndRemoveLineCommands(
        \\1 RCDATA {"blah"}
        \\2 RCDATA {"blah"}
    , &[_]ExpectedSourceSpan{
        .{ .start_line = 1, .end_line = 1, .filename = "blah.rc" },
        .{ .start_line = 2, .end_line = 2, .filename = "blah.rc" },
    },
        \\1 RCDATA {"blah"}
        \\2 RCDATA {"blah"}
    , .{ .initial_filename = "blah.rc" });
}

test "in place" {
    var mut_source = "#line 1 \"blah.rc\"".*;
    var result = try parseAndRemoveLineCommands(std.testing.allocator, &mut_source, &mut_source, .{});
    defer result.mappings.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("", result.result);
}
