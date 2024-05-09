//! Expects to run after a C preprocessor step that preserves comments.
//!
//! `rc` has a peculiar quirk where something like `blah/**/blah` will be
//! transformed into `blahblah` during parsing. However, `clang -E` will
//! transform it into `blah blah`, so in order to match `rc`, we need
//! to remove comments ourselves after the preprocessor runs.
//! Note: Multiline comments that actually span more than one line do
//!       get translated to a space character by `rc`.
//!
//! Removing comments before lexing also allows the lexer to not have to
//! deal with comments which would complicate its implementation (this is something
//! of a tradeoff, as removing comments in a separate pass means that we'll
//! need to iterate the source twice instead of once, but having to deal with
//! comments when lexing would be a pain).

const std = @import("std");
const Allocator = std.mem.Allocator;
const UncheckedSliceWriter = @import("utils.zig").UncheckedSliceWriter;
const SourceMappings = @import("source_mapping.zig").SourceMappings;
const LineHandler = @import("lex.zig").LineHandler;
const formsLineEndingPair = @import("source_mapping.zig").formsLineEndingPair;

/// `buf` must be at least as long as `source`
/// In-place transformation is supported (i.e. `source` and `buf` can be the same slice)
pub fn removeComments(source: []const u8, buf: []u8, source_mappings: ?*SourceMappings) ![]u8 {
    std.debug.assert(buf.len >= source.len);
    var result = UncheckedSliceWriter{ .slice = buf };
    const State = enum {
        start,
        forward_slash,
        line_comment,
        multiline_comment,
        multiline_comment_end,
        single_quoted,
        single_quoted_escape,
        double_quoted,
        double_quoted_escape,
    };
    var state: State = .start;
    var index: usize = 0;
    var pending_start: ?usize = null;
    var line_handler = LineHandler{ .buffer = source };
    while (index < source.len) : (index += 1) {
        const c = source[index];
        // TODO: Disallow \x1A, \x00, \x7F in comments. At least \x1A and \x00 can definitely
        //       cause errors or parsing weirdness in the Win32 RC compiler. These are disallowed
        //       in the lexer, but comments are stripped before getting to the lexer.
        switch (state) {
            .start => switch (c) {
                '/' => {
                    state = .forward_slash;
                    pending_start = index;
                },
                '\r', '\n' => {
                    _ = line_handler.incrementLineNumber(index);
                    result.write(c);
                },
                else => {
                    switch (c) {
                        '"' => state = .double_quoted,
                        '\'' => state = .single_quoted,
                        else => {},
                    }
                    result.write(c);
                },
            },
            .forward_slash => switch (c) {
                '/' => state = .line_comment,
                '*' => {
                    state = .multiline_comment;
                },
                else => {
                    _ = line_handler.maybeIncrementLineNumber(index);
                    result.writeSlice(source[pending_start.? .. index + 1]);
                    pending_start = null;
                    state = .start;
                },
            },
            .line_comment => switch (c) {
                '\r', '\n' => {
                    _ = line_handler.incrementLineNumber(index);
                    result.write(c);
                    state = .start;
                },
                else => {},
            },
            .multiline_comment => switch (c) {
                '\r' => try handleMultilineCarriageReturn(source, &line_handler, index, &result, source_mappings),
                '\n' => {
                    _ = line_handler.incrementLineNumber(index);
                    result.write(c);
                },
                '*' => state = .multiline_comment_end,
                else => {},
            },
            .multiline_comment_end => switch (c) {
                '\r' => {
                    try handleMultilineCarriageReturn(source, &line_handler, index, &result, source_mappings);
                    // We only want to treat this as a newline if it's part of a CRLF pair. If it's
                    // not, then we still want to stay in .multiline_comment_end, so that e.g. `*<\r>/` still
                    // functions as a `*/` comment ending. Kinda crazy, but that's how the Win32 implementation works.
                    if (formsLineEndingPair(source, '\r', index + 1)) {
                        state = .multiline_comment;
                    }
                },
                '\n' => {
                    _ = line_handler.incrementLineNumber(index);
                    result.write(c);
                    state = .multiline_comment;
                },
                '/' => {
                    state = .start;
                },
                else => {
                    state = .multiline_comment;
                },
            },
            .single_quoted => switch (c) {
                '\r', '\n' => {
                    _ = line_handler.incrementLineNumber(index);
                    state = .start;
                    result.write(c);
                },
                '\\' => {
                    state = .single_quoted_escape;
                    result.write(c);
                },
                '\'' => {
                    state = .start;
                    result.write(c);
                },
                else => {
                    result.write(c);
                },
            },
            .single_quoted_escape => switch (c) {
                '\r', '\n' => {
                    _ = line_handler.incrementLineNumber(index);
                    state = .start;
                    result.write(c);
                },
                else => {
                    state = .single_quoted;
                    result.write(c);
                },
            },
            .double_quoted => switch (c) {
                '\r', '\n' => {
                    _ = line_handler.incrementLineNumber(index);
                    state = .start;
                    result.write(c);
                },
                '\\' => {
                    state = .double_quoted_escape;
                    result.write(c);
                },
                '"' => {
                    state = .start;
                    result.write(c);
                },
                else => {
                    result.write(c);
                },
            },
            .double_quoted_escape => switch (c) {
                '\r', '\n' => {
                    _ = line_handler.incrementLineNumber(index);
                    state = .start;
                    result.write(c);
                },
                else => {
                    state = .double_quoted;
                    result.write(c);
                },
            },
        }
    }
    return result.getWritten();
}

inline fn handleMultilineCarriageReturn(
    source: []const u8,
    line_handler: *LineHandler,
    index: usize,
    result: *UncheckedSliceWriter,
    source_mappings: ?*SourceMappings,
) !void {
    // This is a dumb way to go about this, but basically we want to determine
    // if this is part of a distinct CRLF or LFCR pair. This function call will detect
    // LFCR pairs correctly since the function we're in will only be called on CR,
    // but will not detect CRLF pairs since it only looks at the line ending before the
    // CR. So, we do a second (forward) check if the first fails to detect CRLF that is
    // not part of another pair.
    const is_lfcr_pair = line_handler.currentIndexFormsLineEndingPair(index);
    const is_crlf_pair = !is_lfcr_pair and formsLineEndingPair(source, '\r', index + 1);
    // Note: Bare \r within a multiline comment should *not* be treated as a line ending for the
    // purposes of removing comments, but *should* be treated as a line ending for the
    // purposes of line counting/source mapping
    _ = line_handler.incrementLineNumber(index);
    // So only write the \r if it's part of a CRLF/LFCR pair
    if (is_lfcr_pair or is_crlf_pair) {
        result.write('\r');
    }
    // And otherwise, we want to collapse the source mapping so that we can still know which
    // line came from where.
    else {
        // Because the line gets collapsed, we need to decrement line number so that
        // the next collapse acts on the first of the collapsed line numbers
        line_handler.line_number -= 1;
        if (source_mappings) |mappings| {
            try mappings.collapse(line_handler.line_number, 1);
        }
    }
}

pub fn removeCommentsAlloc(allocator: Allocator, source: []const u8, source_mappings: ?*SourceMappings) ![]u8 {
    const buf = try allocator.alloc(u8, source.len);
    errdefer allocator.free(buf);
    const result = try removeComments(source, buf, source_mappings);
    return allocator.realloc(buf, result.len);
}

fn testRemoveComments(expected: []const u8, source: []const u8) !void {
    const result = try removeCommentsAlloc(std.testing.allocator, source, null);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings(expected, result);
}

test "basic" {
    try testRemoveComments("", "// comment");
    try testRemoveComments("", "/* comment */");
}

test "mixed" {
    try testRemoveComments("hello", "hello// comment");
    try testRemoveComments("hello", "hel/* comment */lo");
}

test "within a string" {
    // escaped " is \"
    try testRemoveComments(
        \\blah"//som\"/*ething*/"BLAH
    ,
        \\blah"//som\"/*ething*/"BLAH
    );
}

test "line comments retain newlines" {
    try testRemoveComments(
        \\
        \\
        \\
    ,
        \\// comment
        \\// comment
        \\// comment
    );

    try testRemoveComments("\r\n", "//comment\r\n");
}

test "unfinished multiline comment" {
    try testRemoveComments(
        \\unfinished
        \\
    ,
        \\unfinished/*
        \\
    );
}

test "crazy" {
    try testRemoveComments(
        \\blah"/*som*/\""BLAH
    ,
        \\blah"/*som*/\""/*ething*/BLAH
    );

    try testRemoveComments(
        \\blah"/*som*/"BLAH RCDATA "BEGIN END
        \\
        \\
        \\hello
        \\"
    ,
        \\blah"/*som*/"/*ething*/BLAH RCDATA "BEGIN END
        \\// comment
        \\//"blah blah" RCDATA {}
        \\hello
        \\"
    );
}

test "multiline comment with newlines" {
    // bare \r is not treated as a newline
    try testRemoveComments("blahblah", "blah/*some\rthing*/blah");

    try testRemoveComments(
        \\blah
        \\blah
    ,
        \\blah/*some
        \\thing*/blah
    );
    try testRemoveComments(
        "blah\r\nblah",
        "blah/*some\r\nthing*/blah",
    );

    // handle *<not /> correctly
    try testRemoveComments(
        \\blah
        \\
        \\
    ,
        \\blah/*some
        \\thing*
        \\/bl*ah*/
    );
}

test "comments appended to a line" {
    try testRemoveComments(
        \\blah 
        \\blah
    ,
        \\blah // line comment
        \\blah
    );
    try testRemoveComments(
        "blah \r\nblah",
        "blah // line comment\r\nblah",
    );
}

test "remove comments with mappings" {
    const allocator = std.testing.allocator;
    var mut_source = "blah/*\rcommented line*\r/blah".*;
    var mappings = SourceMappings{};
    _ = try mappings.files.put(allocator, "test.rc");
    try mappings.set(1, 1, 0);
    try mappings.set(2, 2, 0);
    try mappings.set(3, 3, 0);
    defer mappings.deinit(allocator);

    const result = try removeComments(&mut_source, &mut_source, &mappings);

    try std.testing.expectEqualStrings("blahblah", result);
    try std.testing.expectEqual(@as(usize, 1), mappings.end_line);
    try std.testing.expectEqual(@as(usize, 3), mappings.getCorrespondingSpan(1).?.end_line);
}

test "in place" {
    var mut_source = "blah /* comment */ blah".*;
    const result = try removeComments(&mut_source, &mut_source, null);
    try std.testing.expectEqualStrings("blah  blah", result);
}
