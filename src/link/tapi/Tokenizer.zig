const Tokenizer = @This();

const std = @import("std");
const log = std.log.scoped(.yaml);
const testing = std.testing;

buffer: []const u8,
index: usize = 0,

pub const Token = struct {
    id: Id,
    start: usize,
    end: usize,

    pub const Id = enum {
        // zig fmt: off
        eof,

        new_line,
        doc_start,      // ---
        doc_end,        // ...
        seq_item_ind,   // -
        map_value_ind,  // :
        flow_map_start, // {
        flow_map_end,   // }
        flow_seq_start, // [
        flow_seq_end,   // ]

        comma,
        space,
        tab,
        comment,        // #
        alias,          // *
        anchor,         // &
        tag,            // !

        single_quoted,   // '...'
        double_quoted,   // "..."
        literal,
        // zig fmt: on
    };
};

pub const TokenIndex = usize;

pub const TokenIterator = struct {
    buffer: []const Token,
    pos: TokenIndex = 0,

    pub fn next(self: *TokenIterator) ?Token {
        const token = self.peek() orelse return null;
        self.pos += 1;
        return token;
    }

    pub fn peek(self: TokenIterator) ?Token {
        if (self.pos >= self.buffer.len) return null;
        return self.buffer[self.pos];
    }

    pub fn reset(self: *TokenIterator) void {
        self.pos = 0;
    }

    pub fn seekTo(self: *TokenIterator, pos: TokenIndex) void {
        self.pos = pos;
    }

    pub fn seekBy(self: *TokenIterator, offset: isize) void {
        const new_pos = @as(isize, @bitCast(self.pos)) + offset;
        if (new_pos < 0) {
            self.pos = 0;
        } else {
            self.pos = @as(usize, @intCast(new_pos));
        }
    }
};

fn stringMatchesPattern(comptime pattern: []const u8, slice: []const u8) bool {
    comptime var count: usize = 0;
    inline while (count < pattern.len) : (count += 1) {
        if (count >= slice.len) return false;
        const c = slice[count];
        if (pattern[count] != c) return false;
    }
    return true;
}

fn matchesPattern(self: Tokenizer, comptime pattern: []const u8) bool {
    return stringMatchesPattern(pattern, self.buffer[self.index..]);
}

pub fn next(self: *Tokenizer) Token {
    var result = Token{
        .id = .eof,
        .start = self.index,
        .end = undefined,
    };

    var state: enum {
        start,
        new_line,
        space,
        tab,
        comment,
        single_quoted,
        double_quoted,
        literal,
    } = .start;

    while (self.index < self.buffer.len) : (self.index += 1) {
        const c = self.buffer[self.index];
        switch (state) {
            .start => switch (c) {
                ' ' => {
                    state = .space;
                },
                '\t' => {
                    state = .tab;
                },
                '\n' => {
                    result.id = .new_line;
                    self.index += 1;
                    break;
                },
                '\r' => {
                    state = .new_line;
                },

                '-' => if (self.matchesPattern("---")) {
                    result.id = .doc_start;
                    self.index += "---".len;
                    break;
                } else if (self.matchesPattern("- ")) {
                    result.id = .seq_item_ind;
                    self.index += "- ".len;
                    break;
                } else {
                    state = .literal;
                },

                '.' => if (self.matchesPattern("...")) {
                    result.id = .doc_end;
                    self.index += "...".len;
                    break;
                } else {
                    state = .literal;
                },

                ',' => {
                    result.id = .comma;
                    self.index += 1;
                    break;
                },
                '#' => {
                    state = .comment;
                },
                '*' => {
                    result.id = .alias;
                    self.index += 1;
                    break;
                },
                '&' => {
                    result.id = .anchor;
                    self.index += 1;
                    break;
                },
                '!' => {
                    result.id = .tag;
                    self.index += 1;
                    break;
                },
                '[' => {
                    result.id = .flow_seq_start;
                    self.index += 1;
                    break;
                },
                ']' => {
                    result.id = .flow_seq_end;
                    self.index += 1;
                    break;
                },
                ':' => {
                    result.id = .map_value_ind;
                    self.index += 1;
                    break;
                },
                '{' => {
                    result.id = .flow_map_start;
                    self.index += 1;
                    break;
                },
                '}' => {
                    result.id = .flow_map_end;
                    self.index += 1;
                    break;
                },
                '\'' => {
                    state = .single_quoted;
                },
                '"' => {
                    state = .double_quoted;
                },
                else => {
                    state = .literal;
                },
            },

            .comment => switch (c) {
                '\r', '\n' => {
                    result.id = .comment;
                    break;
                },
                else => {},
            },

            .space => switch (c) {
                ' ' => {},
                else => {
                    result.id = .space;
                    break;
                },
            },

            .tab => switch (c) {
                '\t' => {},
                else => {
                    result.id = .tab;
                    break;
                },
            },

            .new_line => switch (c) {
                '\n' => {
                    result.id = .new_line;
                    self.index += 1;
                    break;
                },
                else => {}, // TODO this should be an error condition
            },

            .single_quoted => switch (c) {
                '\'' => if (!self.matchesPattern("''")) {
                    result.id = .single_quoted;
                    self.index += 1;
                    break;
                } else {
                    self.index += "''".len - 1;
                },
                else => {},
            },

            .double_quoted => switch (c) {
                '"' => {
                    if (stringMatchesPattern("\\", self.buffer[self.index - 1 ..])) {
                        self.index += 1;
                    } else {
                        result.id = .double_quoted;
                        self.index += 1;
                        break;
                    }
                },
                else => {},
            },

            .literal => switch (c) {
                '\r', '\n', ' ', '\'', '"', ',', ':', ']', '}' => {
                    result.id = .literal;
                    break;
                },
                else => {
                    result.id = .literal;
                },
            },
        }
    }

    if (self.index >= self.buffer.len) {
        switch (state) {
            .literal => {
                result.id = .literal;
            },
            else => {},
        }
    }

    result.end = self.index;

    log.debug("{any}", .{result});
    log.debug("    | {s}", .{self.buffer[result.start..result.end]});

    return result;
}

fn testExpected(source: []const u8, expected: []const Token.Id) !void {
    var tokenizer = Tokenizer{
        .buffer = source,
    };

    var given = std.ArrayList(Token.Id).init(testing.allocator);
    defer given.deinit();

    while (true) {
        const token = tokenizer.next();
        try given.append(token.id);
        if (token.id == .eof) break;
    }

    try testing.expectEqualSlices(Token.Id, expected, given.items);
}

test {
    std.testing.refAllDecls(@This());
}

test "empty doc" {
    try testExpected("", &[_]Token.Id{.eof});
}

test "empty doc with explicit markers" {
    try testExpected(
        \\---
        \\...
    , &[_]Token.Id{
        .doc_start, .new_line, .doc_end, .eof,
    });
}

test "empty doc with explicit markers and a directive" {
    try testExpected(
        \\--- !tbd-v1
        \\...
    , &[_]Token.Id{
        .doc_start,
        .space,
        .tag,
        .literal,
        .new_line,
        .doc_end,
        .eof,
    });
}

test "sequence of values" {
    try testExpected(
        \\- 0
        \\- 1
        \\- 2
    , &[_]Token.Id{
        .seq_item_ind,
        .literal,
        .new_line,
        .seq_item_ind,
        .literal,
        .new_line,
        .seq_item_ind,
        .literal,
        .eof,
    });
}

test "sequence of sequences" {
    try testExpected(
        \\- [ val1, val2]
        \\- [val3, val4 ]
    , &[_]Token.Id{
        .seq_item_ind,
        .flow_seq_start,
        .space,
        .literal,
        .comma,
        .space,
        .literal,
        .flow_seq_end,
        .new_line,
        .seq_item_ind,
        .flow_seq_start,
        .literal,
        .comma,
        .space,
        .literal,
        .space,
        .flow_seq_end,
        .eof,
    });
}

test "mappings" {
    try testExpected(
        \\key1: value1
        \\key2: value2
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .eof,
    });
}

test "inline mapped sequence of values" {
    try testExpected(
        \\key :  [ val1, 
        \\          val2 ]
    , &[_]Token.Id{
        .literal,
        .space,
        .map_value_ind,
        .space,
        .flow_seq_start,
        .space,
        .literal,
        .comma,
        .space,
        .new_line,
        .space,
        .literal,
        .space,
        .flow_seq_end,
        .eof,
    });
}

test "part of tbd" {
    try testExpected(
        \\--- !tapi-tbd
        \\tbd-version:     4
        \\targets:         [ x86_64-macos ]
        \\
        \\uuids:
        \\  - target:          x86_64-macos
        \\    value:           F86CC732-D5E4-30B5-AA7D-167DF5EC2708
        \\
        \\install-name:    '/usr/lib/libSystem.B.dylib'
        \\...
    , &[_]Token.Id{
        .doc_start,
        .space,
        .tag,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .flow_seq_start,
        .space,
        .literal,
        .space,
        .flow_seq_end,
        .new_line,
        .new_line,
        .literal,
        .map_value_ind,
        .new_line,
        .space,
        .seq_item_ind,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .space,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .single_quoted,
        .new_line,
        .doc_end,
        .eof,
    });
}

test "Unindented list" {
    try testExpected(
        \\b:
        \\- foo: 1
        \\c: 1
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .new_line,
        .seq_item_ind,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .eof,
    });
}

test "escape sequences" {
    try testExpected(
        \\a: 'here''s an apostrophe'
        \\b: "a newline\nand a\ttab"
        \\c: "\"here\" and there"
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .space,
        .single_quoted,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .double_quoted,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .double_quoted,
        .eof,
    });
}

test "comments" {
    try testExpected(
        \\key: # some comment about the key
        \\# first value
        \\- val1
        \\# second value
        \\- val2
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .space,
        .comment,
        .new_line,
        .comment,
        .new_line,
        .seq_item_ind,
        .literal,
        .new_line,
        .comment,
        .new_line,
        .seq_item_ind,
        .literal,
        .eof,
    });
}

test "quoted literals" {
    try testExpected(
        \\'#000000'
        \\'[000000'
        \\"&someString"
    , &[_]Token.Id{
        .single_quoted,
        .new_line,
        .single_quoted,
        .new_line,
        .double_quoted,
        .eof,
    });
}
