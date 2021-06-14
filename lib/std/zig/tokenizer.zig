// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const mem = std.mem;

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const keywords = std.ComptimeStringMap(Tag, .{
        .{ "align", .keyword_align },
        .{ "allowzero", .keyword_allowzero },
        .{ "and", .keyword_and },
        .{ "anyframe", .keyword_anyframe },
        .{ "anytype", .keyword_anytype },
        .{ "asm", .keyword_asm },
        .{ "async", .keyword_async },
        .{ "await", .keyword_await },
        .{ "break", .keyword_break },
        .{ "callconv", .keyword_callconv },
        .{ "catch", .keyword_catch },
        .{ "comptime", .keyword_comptime },
        .{ "const", .keyword_const },
        .{ "continue", .keyword_continue },
        .{ "defer", .keyword_defer },
        .{ "else", .keyword_else },
        .{ "enum", .keyword_enum },
        .{ "errdefer", .keyword_errdefer },
        .{ "error", .keyword_error },
        .{ "export", .keyword_export },
        .{ "extern", .keyword_extern },
        .{ "false", .keyword_false },
        .{ "fn", .keyword_fn },
        .{ "for", .keyword_for },
        .{ "if", .keyword_if },
        .{ "inline", .keyword_inline },
        .{ "noalias", .keyword_noalias },
        .{ "noinline", .keyword_noinline },
        .{ "nosuspend", .keyword_nosuspend },
        .{ "null", .keyword_null },
        .{ "opaque", .keyword_opaque },
        .{ "or", .keyword_or },
        .{ "orelse", .keyword_orelse },
        .{ "packed", .keyword_packed },
        .{ "pub", .keyword_pub },
        .{ "resume", .keyword_resume },
        .{ "return", .keyword_return },
        .{ "linksection", .keyword_linksection },
        .{ "struct", .keyword_struct },
        .{ "suspend", .keyword_suspend },
        .{ "switch", .keyword_switch },
        .{ "test", .keyword_test },
        .{ "threadlocal", .keyword_threadlocal },
        .{ "true", .keyword_true },
        .{ "try", .keyword_try },
        .{ "undefined", .keyword_undefined },
        .{ "union", .keyword_union },
        .{ "unreachable", .keyword_unreachable },
        .{ "usingnamespace", .keyword_usingnamespace },
        .{ "var", .keyword_var },
        .{ "volatile", .keyword_volatile },
        .{ "while", .keyword_while },
    });

    pub fn getKeyword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }

    pub const Tag = enum {
        invalid,
        invalid_periodasterisks,
        identifier,
        string_literal,
        multiline_string_literal_line,
        char_literal,
        eof,
        builtin,
        bang,
        pipe,
        pipe_pipe,
        pipe_equal,
        equal,
        equal_equal,
        equal_angle_bracket_right,
        bang_equal,
        l_paren,
        r_paren,
        semicolon,
        percent,
        percent_equal,
        l_brace,
        r_brace,
        l_bracket,
        r_bracket,
        period,
        period_asterisk,
        ellipsis2,
        ellipsis3,
        caret,
        caret_equal,
        plus,
        plus_plus,
        plus_equal,
        plus_percent,
        plus_percent_equal,
        minus,
        minus_equal,
        minus_percent,
        minus_percent_equal,
        asterisk,
        asterisk_equal,
        asterisk_asterisk,
        asterisk_percent,
        asterisk_percent_equal,
        arrow,
        colon,
        slash,
        slash_equal,
        comma,
        ampersand,
        ampersand_equal,
        question_mark,
        angle_bracket_left,
        angle_bracket_left_equal,
        angle_bracket_angle_bracket_left,
        angle_bracket_angle_bracket_left_equal,
        angle_bracket_right,
        angle_bracket_right_equal,
        angle_bracket_angle_bracket_right,
        angle_bracket_angle_bracket_right_equal,
        tilde,
        integer_literal,
        float_literal,
        doc_comment,
        container_doc_comment,
        keyword_align,
        keyword_allowzero,
        keyword_and,
        keyword_anyframe,
        keyword_anytype,
        keyword_asm,
        keyword_async,
        keyword_await,
        keyword_break,
        keyword_callconv,
        keyword_catch,
        keyword_comptime,
        keyword_const,
        keyword_continue,
        keyword_defer,
        keyword_else,
        keyword_enum,
        keyword_errdefer,
        keyword_error,
        keyword_export,
        keyword_extern,
        keyword_false,
        keyword_fn,
        keyword_for,
        keyword_if,
        keyword_inline,
        keyword_noalias,
        keyword_noinline,
        keyword_nosuspend,
        keyword_null,
        keyword_opaque,
        keyword_or,
        keyword_orelse,
        keyword_packed,
        keyword_pub,
        keyword_resume,
        keyword_return,
        keyword_linksection,
        keyword_struct,
        keyword_suspend,
        keyword_switch,
        keyword_test,
        keyword_threadlocal,
        keyword_true,
        keyword_try,
        keyword_undefined,
        keyword_union,
        keyword_unreachable,
        keyword_usingnamespace,
        keyword_var,
        keyword_volatile,
        keyword_while,

        pub fn lexeme(tag: Tag) ?[]const u8 {
            return switch (tag) {
                .invalid,
                .identifier,
                .string_literal,
                .multiline_string_literal_line,
                .char_literal,
                .eof,
                .builtin,
                .integer_literal,
                .float_literal,
                .doc_comment,
                .container_doc_comment,
                => null,

                .invalid_periodasterisks => ".**",
                .bang => "!",
                .pipe => "|",
                .pipe_pipe => "||",
                .pipe_equal => "|=",
                .equal => "=",
                .equal_equal => "==",
                .equal_angle_bracket_right => "=>",
                .bang_equal => "!=",
                .l_paren => "(",
                .r_paren => ")",
                .semicolon => ";",
                .percent => "%",
                .percent_equal => "%=",
                .l_brace => "{",
                .r_brace => "}",
                .l_bracket => "[",
                .r_bracket => "]",
                .period => ".",
                .period_asterisk => ".*",
                .ellipsis2 => "..",
                .ellipsis3 => "...",
                .caret => "^",
                .caret_equal => "^=",
                .plus => "+",
                .plus_plus => "++",
                .plus_equal => "+=",
                .plus_percent => "+%",
                .plus_percent_equal => "+%=",
                .minus => "-",
                .minus_equal => "-=",
                .minus_percent => "-%",
                .minus_percent_equal => "-%=",
                .asterisk => "*",
                .asterisk_equal => "*=",
                .asterisk_asterisk => "**",
                .asterisk_percent => "*%",
                .asterisk_percent_equal => "*%=",
                .arrow => "->",
                .colon => ":",
                .slash => "/",
                .slash_equal => "/=",
                .comma => ",",
                .ampersand => "&",
                .ampersand_equal => "&=",
                .question_mark => "?",
                .angle_bracket_left => "<",
                .angle_bracket_left_equal => "<=",
                .angle_bracket_angle_bracket_left => "<<",
                .angle_bracket_angle_bracket_left_equal => "<<=",
                .angle_bracket_right => ">",
                .angle_bracket_right_equal => ">=",
                .angle_bracket_angle_bracket_right => ">>",
                .angle_bracket_angle_bracket_right_equal => ">>=",
                .tilde => "~",
                .keyword_align => "align",
                .keyword_allowzero => "allowzero",
                .keyword_and => "and",
                .keyword_anyframe => "anyframe",
                .keyword_anytype => "anytype",
                .keyword_asm => "asm",
                .keyword_async => "async",
                .keyword_await => "await",
                .keyword_break => "break",
                .keyword_callconv => "callconv",
                .keyword_catch => "catch",
                .keyword_comptime => "comptime",
                .keyword_const => "const",
                .keyword_continue => "continue",
                .keyword_defer => "defer",
                .keyword_else => "else",
                .keyword_enum => "enum",
                .keyword_errdefer => "errdefer",
                .keyword_error => "error",
                .keyword_export => "export",
                .keyword_extern => "extern",
                .keyword_false => "false",
                .keyword_fn => "fn",
                .keyword_for => "for",
                .keyword_if => "if",
                .keyword_inline => "inline",
                .keyword_noalias => "noalias",
                .keyword_noinline => "noinline",
                .keyword_nosuspend => "nosuspend",
                .keyword_null => "null",
                .keyword_opaque => "opaque",
                .keyword_or => "or",
                .keyword_orelse => "orelse",
                .keyword_packed => "packed",
                .keyword_pub => "pub",
                .keyword_resume => "resume",
                .keyword_return => "return",
                .keyword_linksection => "linksection",
                .keyword_struct => "struct",
                .keyword_suspend => "suspend",
                .keyword_switch => "switch",
                .keyword_test => "test",
                .keyword_threadlocal => "threadlocal",
                .keyword_true => "true",
                .keyword_try => "try",
                .keyword_undefined => "undefined",
                .keyword_union => "union",
                .keyword_unreachable => "unreachable",
                .keyword_usingnamespace => "usingnamespace",
                .keyword_var => "var",
                .keyword_volatile => "volatile",
                .keyword_while => "while",
            };
        }

        pub fn symbol(tag: Tag) []const u8 {
            return tag.lexeme() orelse @tagName(tag);
        }
    };
};

pub const Tokenizer = struct {
    buffer: []const u8,
    index: usize,
    pending_invalid_token: ?Token,

    /// For debugging purposes
    pub fn dump(self: *Tokenizer, token: *const Token) void {
        std.debug.warn("{s} \"{s}\"\n", .{ @tagName(token.tag), self.buffer[token.start..token.end] });
    }

    pub fn init(buffer: []const u8) Tokenizer {
        // Skip the UTF-8 BOM if present
        const src_start = if (mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else @as(usize, 0);
        return Tokenizer{
            .buffer = buffer,
            .index = src_start,
            .pending_invalid_token = null,
        };
    }

    const State = enum {
        start,
        identifier,
        builtin,
        string_literal,
        string_literal_backslash,
        multiline_string_literal_line,
        char_literal,
        char_literal_backslash,
        char_literal_hex_escape,
        char_literal_unicode_escape_saw_u,
        char_literal_unicode_escape,
        char_literal_unicode_invalid,
        char_literal_unicode,
        char_literal_end,
        backslash,
        equal,
        bang,
        pipe,
        minus,
        minus_percent,
        asterisk,
        asterisk_percent,
        slash,
        line_comment_start,
        line_comment,
        doc_comment_start,
        doc_comment,
        container_doc_comment,
        zero,
        int_literal_dec,
        int_literal_dec_no_underscore,
        int_literal_bin,
        int_literal_bin_no_underscore,
        int_literal_oct,
        int_literal_oct_no_underscore,
        int_literal_hex,
        int_literal_hex_no_underscore,
        num_dot_dec,
        num_dot_hex,
        float_fraction_dec,
        float_fraction_dec_no_underscore,
        float_fraction_hex,
        float_fraction_hex_no_underscore,
        float_exponent_unsigned,
        float_exponent_num,
        float_exponent_num_no_underscore,
        ampersand,
        caret,
        percent,
        plus,
        plus_percent,
        angle_bracket_left,
        angle_bracket_angle_bracket_left,
        angle_bracket_right,
        angle_bracket_angle_bracket_right,
        period,
        period_2,
        period_asterisk,
        saw_at_sign,
    };

    fn isIdentifierChar(char: u8) bool {
        return std.ascii.isAlNum(char) or char == '_';
    }

    pub fn next(self: *Tokenizer) Token {
        if (self.pending_invalid_token) |token| {
            self.pending_invalid_token = null;
            return token;
        }
        const start_index = self.index;
        var state: State = .start;
        var result = Token{
            .tag = .eof,
            .loc = .{
                .start = self.index,
                .end = undefined,
            },
        };
        var seen_escape_digits: usize = undefined;
        var remaining_code_units: usize = undefined;
        while (self.index < self.buffer.len) : (self.index += 1) {
            const c = self.buffer[self.index];
            switch (state) {
                .start => switch (c) {
                    ' ', '\n', '\t', '\r' => {
                        result.loc.start = self.index + 1;
                    },
                    '"' => {
                        state = .string_literal;
                        result.tag = .string_literal;
                    },
                    '\'' => {
                        state = .char_literal;
                    },
                    'a'...'z', 'A'...'Z', '_' => {
                        state = .identifier;
                        result.tag = .identifier;
                    },
                    '@' => {
                        state = .saw_at_sign;
                    },
                    '=' => {
                        state = .equal;
                    },
                    '!' => {
                        state = .bang;
                    },
                    '|' => {
                        state = .pipe;
                    },
                    '(' => {
                        result.tag = .l_paren;
                        self.index += 1;
                        break;
                    },
                    ')' => {
                        result.tag = .r_paren;
                        self.index += 1;
                        break;
                    },
                    '[' => {
                        result.tag = .l_bracket;
                        self.index += 1;
                        break;
                    },
                    ']' => {
                        result.tag = .r_bracket;
                        self.index += 1;
                        break;
                    },
                    ';' => {
                        result.tag = .semicolon;
                        self.index += 1;
                        break;
                    },
                    ',' => {
                        result.tag = .comma;
                        self.index += 1;
                        break;
                    },
                    '?' => {
                        result.tag = .question_mark;
                        self.index += 1;
                        break;
                    },
                    ':' => {
                        result.tag = .colon;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = .percent;
                    },
                    '*' => {
                        state = .asterisk;
                    },
                    '+' => {
                        state = .plus;
                    },
                    '<' => {
                        state = .angle_bracket_left;
                    },
                    '>' => {
                        state = .angle_bracket_right;
                    },
                    '^' => {
                        state = .caret;
                    },
                    '\\' => {
                        state = .backslash;
                        result.tag = .multiline_string_literal_line;
                    },
                    '{' => {
                        result.tag = .l_brace;
                        self.index += 1;
                        break;
                    },
                    '}' => {
                        result.tag = .r_brace;
                        self.index += 1;
                        break;
                    },
                    '~' => {
                        result.tag = .tilde;
                        self.index += 1;
                        break;
                    },
                    '.' => {
                        state = .period;
                    },
                    '-' => {
                        state = .minus;
                    },
                    '/' => {
                        state = .slash;
                    },
                    '&' => {
                        state = .ampersand;
                    },
                    '0' => {
                        state = .zero;
                        result.tag = .integer_literal;
                    },
                    '1'...'9' => {
                        state = .int_literal_dec;
                        result.tag = .integer_literal;
                    },
                    else => {
                        result.tag = .invalid;
                        self.index += 1;
                        break;
                    },
                },

                .saw_at_sign => switch (c) {
                    '"' => {
                        result.tag = .identifier;
                        state = .string_literal;
                    },
                    'a'...'z', 'A'...'Z', '_' => {
                        state = .builtin;
                        result.tag = .builtin;
                    },
                    else => {
                        result.tag = .invalid;
                        break;
                    },
                },

                .ampersand => switch (c) {
                    '=' => {
                        result.tag = .ampersand_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .ampersand;
                        break;
                    },
                },

                .asterisk => switch (c) {
                    '=' => {
                        result.tag = .asterisk_equal;
                        self.index += 1;
                        break;
                    },
                    '*' => {
                        result.tag = .asterisk_asterisk;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = .asterisk_percent;
                    },
                    else => {
                        result.tag = .asterisk;
                        break;
                    },
                },

                .asterisk_percent => switch (c) {
                    '=' => {
                        result.tag = .asterisk_percent_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .asterisk_percent;
                        break;
                    },
                },

                .percent => switch (c) {
                    '=' => {
                        result.tag = .percent_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .percent;
                        break;
                    },
                },

                .plus => switch (c) {
                    '=' => {
                        result.tag = .plus_equal;
                        self.index += 1;
                        break;
                    },
                    '+' => {
                        result.tag = .plus_plus;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = .plus_percent;
                    },
                    else => {
                        result.tag = .plus;
                        break;
                    },
                },

                .plus_percent => switch (c) {
                    '=' => {
                        result.tag = .plus_percent_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .plus_percent;
                        break;
                    },
                },

                .caret => switch (c) {
                    '=' => {
                        result.tag = .caret_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .caret;
                        break;
                    },
                },

                .identifier => switch (c) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => {},
                    else => {
                        if (Token.getKeyword(self.buffer[result.loc.start..self.index])) |tag| {
                            result.tag = tag;
                        }
                        break;
                    },
                },
                .builtin => switch (c) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => {},
                    else => break,
                },
                .backslash => switch (c) {
                    '\\' => {
                        state = .multiline_string_literal_line;
                    },
                    else => {
                        result.tag = .invalid;
                        break;
                    },
                },
                .string_literal => switch (c) {
                    '\\' => {
                        state = .string_literal_backslash;
                    },
                    '"' => {
                        self.index += 1;
                        break;
                    },
                    '\n', '\r' => break, // Look for this error later.
                    else => self.checkLiteralCharacter(),
                },

                .string_literal_backslash => switch (c) {
                    '\n', '\r' => break, // Look for this error later.
                    else => {
                        state = .string_literal;
                    },
                },

                .char_literal => switch (c) {
                    '\\' => {
                        state = .char_literal_backslash;
                    },
                    '\'', 0x80...0xbf, 0xf8...0xff => {
                        result.tag = .invalid;
                        break;
                    },
                    0xc0...0xdf => { // 110xxxxx
                        remaining_code_units = 1;
                        state = .char_literal_unicode;
                    },
                    0xe0...0xef => { // 1110xxxx
                        remaining_code_units = 2;
                        state = .char_literal_unicode;
                    },
                    0xf0...0xf7 => { // 11110xxx
                        remaining_code_units = 3;
                        state = .char_literal_unicode;
                    },
                    else => {
                        state = .char_literal_end;
                    },
                },

                .char_literal_backslash => switch (c) {
                    '\n' => {
                        result.tag = .invalid;
                        break;
                    },
                    'x' => {
                        state = .char_literal_hex_escape;
                        seen_escape_digits = 0;
                    },
                    'u' => {
                        state = .char_literal_unicode_escape_saw_u;
                    },
                    else => {
                        state = .char_literal_end;
                    },
                },

                .char_literal_hex_escape => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        seen_escape_digits += 1;
                        if (seen_escape_digits == 2) {
                            state = .char_literal_end;
                        }
                    },
                    else => {
                        result.tag = .invalid;
                        break;
                    },
                },

                .char_literal_unicode_escape_saw_u => switch (c) {
                    '{' => {
                        state = .char_literal_unicode_escape;
                        seen_escape_digits = 0;
                    },
                    else => {
                        result.tag = .invalid;
                        state = .char_literal_unicode_invalid;
                    },
                },

                .char_literal_unicode_escape => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        seen_escape_digits += 1;
                    },
                    '}' => {
                        if (seen_escape_digits == 0) {
                            result.tag = .invalid;
                            state = .char_literal_unicode_invalid;
                        } else {
                            state = .char_literal_end;
                        }
                    },
                    else => {
                        result.tag = .invalid;
                        state = .char_literal_unicode_invalid;
                    },
                },

                .char_literal_unicode_invalid => switch (c) {
                    // Keep consuming characters until an obvious stopping point.
                    // This consolidates e.g. `u{0ab1Q}` into a single invalid token
                    // instead of creating the tokens `u{0ab1`, `Q`, `}`
                    '0'...'9', 'a'...'z', 'A'...'Z', '}' => {},
                    else => break,
                },

                .char_literal_end => switch (c) {
                    '\'' => {
                        result.tag = .char_literal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .invalid;
                        break;
                    },
                },

                .char_literal_unicode => switch (c) {
                    0x80...0xbf => {
                        remaining_code_units -= 1;
                        if (remaining_code_units == 0) {
                            state = .char_literal_end;
                        }
                    },
                    else => {
                        result.tag = .invalid;
                        break;
                    },
                },

                .multiline_string_literal_line => switch (c) {
                    '\n' => {
                        self.index += 1;
                        break;
                    },
                    '\t' => {},
                    else => self.checkLiteralCharacter(),
                },

                .bang => switch (c) {
                    '=' => {
                        result.tag = .bang_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .bang;
                        break;
                    },
                },

                .pipe => switch (c) {
                    '=' => {
                        result.tag = .pipe_equal;
                        self.index += 1;
                        break;
                    },
                    '|' => {
                        result.tag = .pipe_pipe;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .pipe;
                        break;
                    },
                },

                .equal => switch (c) {
                    '=' => {
                        result.tag = .equal_equal;
                        self.index += 1;
                        break;
                    },
                    '>' => {
                        result.tag = .equal_angle_bracket_right;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .equal;
                        break;
                    },
                },

                .minus => switch (c) {
                    '>' => {
                        result.tag = .arrow;
                        self.index += 1;
                        break;
                    },
                    '=' => {
                        result.tag = .minus_equal;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = .minus_percent;
                    },
                    else => {
                        result.tag = .minus;
                        break;
                    },
                },

                .minus_percent => switch (c) {
                    '=' => {
                        result.tag = .minus_percent_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .minus_percent;
                        break;
                    },
                },

                .angle_bracket_left => switch (c) {
                    '<' => {
                        state = .angle_bracket_angle_bracket_left;
                    },
                    '=' => {
                        result.tag = .angle_bracket_left_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .angle_bracket_left;
                        break;
                    },
                },

                .angle_bracket_angle_bracket_left => switch (c) {
                    '=' => {
                        result.tag = .angle_bracket_angle_bracket_left_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .angle_bracket_angle_bracket_left;
                        break;
                    },
                },

                .angle_bracket_right => switch (c) {
                    '>' => {
                        state = .angle_bracket_angle_bracket_right;
                    },
                    '=' => {
                        result.tag = .angle_bracket_right_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .angle_bracket_right;
                        break;
                    },
                },

                .angle_bracket_angle_bracket_right => switch (c) {
                    '=' => {
                        result.tag = .angle_bracket_angle_bracket_right_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .angle_bracket_angle_bracket_right;
                        break;
                    },
                },

                .period => switch (c) {
                    '.' => {
                        state = .period_2;
                    },
                    '*' => {
                        state = .period_asterisk;
                    },
                    else => {
                        result.tag = .period;
                        break;
                    },
                },

                .period_2 => switch (c) {
                    '.' => {
                        result.tag = .ellipsis3;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .ellipsis2;
                        break;
                    },
                },

                .period_asterisk => switch (c) {
                    '*' => {
                        result.tag = .invalid_periodasterisks;
                        break;
                    },
                    else => {
                        result.tag = .period_asterisk;
                        break;
                    },
                },

                .slash => switch (c) {
                    '/' => {
                        state = .line_comment_start;
                    },
                    '=' => {
                        result.tag = .slash_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.tag = .slash;
                        break;
                    },
                },
                .line_comment_start => switch (c) {
                    '/' => {
                        state = .doc_comment_start;
                    },
                    '!' => {
                        result.tag = .container_doc_comment;
                        state = .container_doc_comment;
                    },
                    '\n' => {
                        state = .start;
                        result.loc.start = self.index + 1;
                    },
                    '\t', '\r' => state = .line_comment,
                    else => {
                        state = .line_comment;
                        self.checkLiteralCharacter();
                    },
                },
                .doc_comment_start => switch (c) {
                    '/' => {
                        state = .line_comment;
                    },
                    '\n' => {
                        result.tag = .doc_comment;
                        break;
                    },
                    '\t', '\r' => {
                        state = .doc_comment;
                        result.tag = .doc_comment;
                    },
                    else => {
                        state = .doc_comment;
                        result.tag = .doc_comment;
                        self.checkLiteralCharacter();
                    },
                },
                .line_comment => switch (c) {
                    '\n' => {
                        state = .start;
                        result.loc.start = self.index + 1;
                    },
                    '\t', '\r' => {},
                    else => self.checkLiteralCharacter(),
                },
                .doc_comment, .container_doc_comment => switch (c) {
                    '\n' => break,
                    '\t', '\r' => {},
                    else => self.checkLiteralCharacter(),
                },
                .zero => switch (c) {
                    'b' => {
                        state = .int_literal_bin_no_underscore;
                    },
                    'o' => {
                        state = .int_literal_oct_no_underscore;
                    },
                    'x' => {
                        state = .int_literal_hex_no_underscore;
                    },
                    '0'...'9', '_', '.', 'e', 'E' => {
                        // reinterpret as a decimal number
                        self.index -= 1;
                        state = .int_literal_dec;
                    },
                    else => {
                        if (isIdentifierChar(c)) {
                            result.tag = .invalid;
                        }
                        break;
                    },
                },
                .int_literal_bin_no_underscore => switch (c) {
                    '0'...'1' => {
                        state = .int_literal_bin;
                    },
                    else => {
                        result.tag = .invalid;
                        break;
                    },
                },
                .int_literal_bin => switch (c) {
                    '_' => {
                        state = .int_literal_bin_no_underscore;
                    },
                    '0'...'1' => {},
                    else => {
                        if (isIdentifierChar(c)) {
                            result.tag = .invalid;
                        }
                        break;
                    },
                },
                .int_literal_oct_no_underscore => switch (c) {
                    '0'...'7' => {
                        state = .int_literal_oct;
                    },
                    else => {
                        result.tag = .invalid;
                        break;
                    },
                },
                .int_literal_oct => switch (c) {
                    '_' => {
                        state = .int_literal_oct_no_underscore;
                    },
                    '0'...'7' => {},
                    else => {
                        if (isIdentifierChar(c)) {
                            result.tag = .invalid;
                        }
                        break;
                    },
                },
                .int_literal_dec_no_underscore => switch (c) {
                    '0'...'9' => {
                        state = .int_literal_dec;
                    },
                    else => {
                        result.tag = .invalid;
                        break;
                    },
                },
                .int_literal_dec => switch (c) {
                    '_' => {
                        state = .int_literal_dec_no_underscore;
                    },
                    '.' => {
                        state = .num_dot_dec;
                        result.tag = .invalid;
                    },
                    'e', 'E' => {
                        state = .float_exponent_unsigned;
                        result.tag = .float_literal;
                    },
                    '0'...'9' => {},
                    else => {
                        if (isIdentifierChar(c)) {
                            result.tag = .invalid;
                        }
                        break;
                    },
                },
                .int_literal_hex_no_underscore => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        state = .int_literal_hex;
                    },
                    else => {
                        result.tag = .invalid;
                        break;
                    },
                },
                .int_literal_hex => switch (c) {
                    '_' => {
                        state = .int_literal_hex_no_underscore;
                    },
                    '.' => {
                        state = .num_dot_hex;
                        result.tag = .invalid;
                    },
                    'p', 'P' => {
                        state = .float_exponent_unsigned;
                        result.tag = .float_literal;
                    },
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    else => {
                        if (isIdentifierChar(c)) {
                            result.tag = .invalid;
                        }
                        break;
                    },
                },
                .num_dot_dec => switch (c) {
                    '.' => {
                        result.tag = .integer_literal;
                        self.index -= 1;
                        state = .start;
                        break;
                    },
                    '0'...'9' => {
                        result.tag = .float_literal;
                        state = .float_fraction_dec;
                    },
                    else => {
                        if (isIdentifierChar(c)) {
                            result.tag = .invalid;
                        }
                        break;
                    },
                },
                .num_dot_hex => switch (c) {
                    '.' => {
                        result.tag = .integer_literal;
                        self.index -= 1;
                        state = .start;
                        break;
                    },
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        result.tag = .float_literal;
                        state = .float_fraction_hex;
                    },
                    else => {
                        if (isIdentifierChar(c)) {
                            result.tag = .invalid;
                        }
                        break;
                    },
                },
                .float_fraction_dec_no_underscore => switch (c) {
                    '0'...'9' => {
                        state = .float_fraction_dec;
                    },
                    else => {
                        result.tag = .invalid;
                        break;
                    },
                },
                .float_fraction_dec => switch (c) {
                    '_' => {
                        state = .float_fraction_dec_no_underscore;
                    },
                    'e', 'E' => {
                        state = .float_exponent_unsigned;
                    },
                    '0'...'9' => {},
                    else => {
                        if (isIdentifierChar(c)) {
                            result.tag = .invalid;
                        }
                        break;
                    },
                },
                .float_fraction_hex_no_underscore => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        state = .float_fraction_hex;
                    },
                    else => {
                        result.tag = .invalid;
                        break;
                    },
                },
                .float_fraction_hex => switch (c) {
                    '_' => {
                        state = .float_fraction_hex_no_underscore;
                    },
                    'p', 'P' => {
                        state = .float_exponent_unsigned;
                    },
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    else => {
                        if (isIdentifierChar(c)) {
                            result.tag = .invalid;
                        }
                        break;
                    },
                },
                .float_exponent_unsigned => switch (c) {
                    '+', '-' => {
                        state = .float_exponent_num_no_underscore;
                    },
                    else => {
                        // reinterpret as a normal exponent number
                        self.index -= 1;
                        state = .float_exponent_num_no_underscore;
                    },
                },
                .float_exponent_num_no_underscore => switch (c) {
                    '0'...'9' => {
                        state = .float_exponent_num;
                    },
                    else => {
                        result.tag = .invalid;
                        break;
                    },
                },
                .float_exponent_num => switch (c) {
                    '_' => {
                        state = .float_exponent_num_no_underscore;
                    },
                    '0'...'9' => {},
                    else => {
                        if (isIdentifierChar(c)) {
                            result.tag = .invalid;
                        }
                        break;
                    },
                },
            }
        } else if (self.index == self.buffer.len) {
            switch (state) {
                .start,
                .int_literal_dec,
                .int_literal_bin,
                .int_literal_oct,
                .int_literal_hex,
                .num_dot_dec,
                .num_dot_hex,
                .float_fraction_dec,
                .float_fraction_hex,
                .float_exponent_num,
                .string_literal, // find this error later
                .multiline_string_literal_line,
                .builtin,
                .line_comment,
                .line_comment_start,
                => {},

                .identifier => {
                    if (Token.getKeyword(self.buffer[result.loc.start..self.index])) |tag| {
                        result.tag = tag;
                    }
                },
                .doc_comment, .doc_comment_start => {
                    result.tag = .doc_comment;
                },
                .container_doc_comment => {
                    result.tag = .container_doc_comment;
                },

                .int_literal_dec_no_underscore,
                .int_literal_bin_no_underscore,
                .int_literal_oct_no_underscore,
                .int_literal_hex_no_underscore,
                .float_fraction_dec_no_underscore,
                .float_fraction_hex_no_underscore,
                .float_exponent_num_no_underscore,
                .float_exponent_unsigned,
                .saw_at_sign,
                .backslash,
                .char_literal,
                .char_literal_backslash,
                .char_literal_hex_escape,
                .char_literal_unicode_escape_saw_u,
                .char_literal_unicode_escape,
                .char_literal_unicode_invalid,
                .char_literal_end,
                .char_literal_unicode,
                .string_literal_backslash,
                => {
                    result.tag = .invalid;
                },

                .equal => {
                    result.tag = .equal;
                },
                .bang => {
                    result.tag = .bang;
                },
                .minus => {
                    result.tag = .minus;
                },
                .slash => {
                    result.tag = .slash;
                },
                .zero => {
                    result.tag = .integer_literal;
                },
                .ampersand => {
                    result.tag = .ampersand;
                },
                .period => {
                    result.tag = .period;
                },
                .period_2 => {
                    result.tag = .ellipsis2;
                },
                .period_asterisk => {
                    result.tag = .period_asterisk;
                },
                .pipe => {
                    result.tag = .pipe;
                },
                .angle_bracket_angle_bracket_right => {
                    result.tag = .angle_bracket_angle_bracket_right;
                },
                .angle_bracket_right => {
                    result.tag = .angle_bracket_right;
                },
                .angle_bracket_angle_bracket_left => {
                    result.tag = .angle_bracket_angle_bracket_left;
                },
                .angle_bracket_left => {
                    result.tag = .angle_bracket_left;
                },
                .plus_percent => {
                    result.tag = .plus_percent;
                },
                .plus => {
                    result.tag = .plus;
                },
                .percent => {
                    result.tag = .percent;
                },
                .caret => {
                    result.tag = .caret;
                },
                .asterisk_percent => {
                    result.tag = .asterisk_percent;
                },
                .asterisk => {
                    result.tag = .asterisk;
                },
                .minus_percent => {
                    result.tag = .minus_percent;
                },
            }
        }

        if (result.tag == .eof) {
            if (self.pending_invalid_token) |token| {
                self.pending_invalid_token = null;
                return token;
            }
            result.loc.start = self.index;
        }

        result.loc.end = self.index;
        return result;
    }

    fn checkLiteralCharacter(self: *Tokenizer) void {
        if (self.pending_invalid_token != null) return;
        const invalid_length = self.getInvalidCharacterLength();
        if (invalid_length == 0) return;
        self.pending_invalid_token = .{
            .tag = .invalid,
            .loc = .{
                .start = self.index,
                .end = self.index + invalid_length,
            },
        };
    }

    fn getInvalidCharacterLength(self: *Tokenizer) u3 {
        const c0 = self.buffer[self.index];
        if (c0 < 0x80) {
            if (c0 < 0x20 or c0 == 0x7f) {
                // ascii control codes are never allowed
                // (note that \n was checked before we got here)
                return 1;
            }
            // looks fine to me.
            return 0;
        } else {
            // check utf8-encoded character.
            const length = std.unicode.utf8ByteSequenceLength(c0) catch return 1;
            if (self.index + length > self.buffer.len) {
                return @intCast(u3, self.buffer.len - self.index);
            }
            const bytes = self.buffer[self.index .. self.index + length];
            switch (length) {
                2 => {
                    const value = std.unicode.utf8Decode2(bytes) catch return length;
                    if (value == 0x85) return length; // U+0085 (NEL)
                },
                3 => {
                    const value = std.unicode.utf8Decode3(bytes) catch return length;
                    if (value == 0x2028) return length; // U+2028 (LS)
                    if (value == 0x2029) return length; // U+2029 (PS)
                },
                4 => {
                    _ = std.unicode.utf8Decode4(bytes) catch return length;
                },
                else => unreachable,
            }
            self.index += length - 1;
            return 0;
        }
    }
};

test "tokenizer" {
    try testTokenize("test", &.{.keyword_test});
}

test "line comment followed by top-level comptime" {
    try testTokenize(
        \\// line comment
        \\comptime {}
        \\
    , &.{
        .keyword_comptime,
        .l_brace,
        .r_brace,
    });
}

test "tokenizer - unknown length pointer and then c pointer" {
    try testTokenize(
        \\[*]u8
        \\[*c]u8
    , &.{
        .l_bracket,
        .asterisk,
        .r_bracket,
        .identifier,
        .l_bracket,
        .asterisk,
        .identifier,
        .r_bracket,
        .identifier,
    });
}

test "tokenizer - code point literal with hex escape" {
    try testTokenize(
        \\'\x1b'
    , &.{.char_literal});
    try testTokenize(
        \\'\x1'
    , &.{ .invalid, .invalid });
}

test "tokenizer - code point literal with unicode escapes" {
    // Valid unicode escapes
    try testTokenize(
        \\'\u{3}'
    , &.{.char_literal});
    try testTokenize(
        \\'\u{01}'
    , &.{.char_literal});
    try testTokenize(
        \\'\u{2a}'
    , &.{.char_literal});
    try testTokenize(
        \\'\u{3f9}'
    , &.{.char_literal});
    try testTokenize(
        \\'\u{6E09aBc1523}'
    , &.{.char_literal});
    try testTokenize(
        \\"\u{440}"
    , &.{.string_literal});

    // Invalid unicode escapes
    try testTokenize(
        \\'\u'
    , &.{.invalid});
    try testTokenize(
        \\'\u{{'
    , &.{ .invalid, .invalid });
    try testTokenize(
        \\'\u{}'
    , &.{ .invalid, .invalid });
    try testTokenize(
        \\'\u{s}'
    , &.{ .invalid, .invalid });
    try testTokenize(
        \\'\u{2z}'
    , &.{ .invalid, .invalid });
    try testTokenize(
        \\'\u{4a'
    , &.{.invalid});

    // Test old-style unicode literals
    try testTokenize(
        \\'\u0333'
    , &.{ .invalid, .invalid });
    try testTokenize(
        \\'\U0333'
    , &.{ .invalid, .integer_literal, .invalid });
}

test "tokenizer - code point literal with unicode code point" {
    try testTokenize(
        \\'💩'
    , &.{.char_literal});
}

test "tokenizer - float literal e exponent" {
    try testTokenize("a = 4.94065645841246544177e-324;\n", &.{
        .identifier,
        .equal,
        .float_literal,
        .semicolon,
    });
}

test "tokenizer - float literal p exponent" {
    try testTokenize("a = 0x1.a827999fcef32p+1022;\n", &.{
        .identifier,
        .equal,
        .float_literal,
        .semicolon,
    });
}

test "tokenizer - chars" {
    try testTokenize("'c'", &.{.char_literal});
}

test "tokenizer - invalid token characters" {
    try testTokenize("#", &.{.invalid});
    try testTokenize("`", &.{.invalid});
    try testTokenize("'c", &.{.invalid});
    try testTokenize("'", &.{.invalid});
    try testTokenize("''", &.{ .invalid, .invalid });
}

test "tokenizer - invalid literal/comment characters" {
    try testTokenize("\"\x00\"", &.{
        .string_literal,
        .invalid,
    });
    try testTokenize("//\x00", &.{
        .invalid,
    });
    try testTokenize("//\x1f", &.{
        .invalid,
    });
    try testTokenize("//\x7f", &.{
        .invalid,
    });
}

test "tokenizer - utf8" {
    try testTokenize("//\xc2\x80", &.{});
    try testTokenize("//\xf4\x8f\xbf\xbf", &.{});
}

test "tokenizer - invalid utf8" {
    try testTokenize("//\x80", &.{
        .invalid,
    });
    try testTokenize("//\xbf", &.{
        .invalid,
    });
    try testTokenize("//\xf8", &.{
        .invalid,
    });
    try testTokenize("//\xff", &.{
        .invalid,
    });
    try testTokenize("//\xc2\xc0", &.{
        .invalid,
    });
    try testTokenize("//\xe0", &.{
        .invalid,
    });
    try testTokenize("//\xf0", &.{
        .invalid,
    });
    try testTokenize("//\xf0\x90\x80\xc0", &.{
        .invalid,
    });
}

test "tokenizer - illegal unicode codepoints" {
    // unicode newline characters.U+0085, U+2028, U+2029
    try testTokenize("//\xc2\x84", &.{});
    try testTokenize("//\xc2\x85", &.{
        .invalid,
    });
    try testTokenize("//\xc2\x86", &.{});
    try testTokenize("//\xe2\x80\xa7", &.{});
    try testTokenize("//\xe2\x80\xa8", &.{
        .invalid,
    });
    try testTokenize("//\xe2\x80\xa9", &.{
        .invalid,
    });
    try testTokenize("//\xe2\x80\xaa", &.{});
}

test "tokenizer - string identifier and builtin fns" {
    try testTokenize(
        \\const @"if" = @import("std");
    , &.{
        .keyword_const,
        .identifier,
        .equal,
        .builtin,
        .l_paren,
        .string_literal,
        .r_paren,
        .semicolon,
    });
}

test "tokenizer - multiline string literal with literal tab" {
    try testTokenize(
        \\\\foo	bar
    , &.{
        .multiline_string_literal_line,
    });
}

test "tokenizer - comments with literal tab" {
    try testTokenize(
        \\//foo	bar
        \\//!foo	bar
        \\///foo	bar
        \\//	foo
        \\///	foo
        \\///	/foo
    , &.{
        .container_doc_comment,
        .doc_comment,
        .doc_comment,
        .doc_comment,
    });
}

test "tokenizer - pipe and then invalid" {
    try testTokenize("||=", &.{
        .pipe_pipe,
        .equal,
    });
}

test "tokenizer - line comment and doc comment" {
    try testTokenize("//", &.{});
    try testTokenize("// a / b", &.{});
    try testTokenize("// /", &.{});
    try testTokenize("/// a", &.{.doc_comment});
    try testTokenize("///", &.{.doc_comment});
    try testTokenize("////", &.{});
    try testTokenize("//!", &.{.container_doc_comment});
    try testTokenize("//!!", &.{.container_doc_comment});
}

test "tokenizer - line comment followed by identifier" {
    try testTokenize(
        \\    Unexpected,
        \\    // another
        \\    Another,
    , &.{
        .identifier,
        .comma,
        .identifier,
        .comma,
    });
}

test "tokenizer - UTF-8 BOM is recognized and skipped" {
    try testTokenize("\xEF\xBB\xBFa;\n", &.{
        .identifier,
        .semicolon,
    });
}

test "correctly parse pointer assignment" {
    try testTokenize("b.*=3;\n", &.{
        .identifier,
        .period_asterisk,
        .equal,
        .integer_literal,
        .semicolon,
    });
}

test "correctly parse pointer dereference followed by asterisk" {
    try testTokenize("\"b\".* ** 10", &.{
        .string_literal,
        .period_asterisk,
        .asterisk_asterisk,
        .integer_literal,
    });

    try testTokenize("(\"b\".*)** 10", &.{
        .l_paren,
        .string_literal,
        .period_asterisk,
        .r_paren,
        .asterisk_asterisk,
        .integer_literal,
    });

    try testTokenize("\"b\".*** 10", &.{
        .string_literal,
        .invalid_periodasterisks,
        .asterisk_asterisk,
        .integer_literal,
    });
}

test "tokenizer - range literals" {
    try testTokenize("0...9", &.{ .integer_literal, .ellipsis3, .integer_literal });
    try testTokenize("'0'...'9'", &.{ .char_literal, .ellipsis3, .char_literal });
    try testTokenize("0x00...0x09", &.{ .integer_literal, .ellipsis3, .integer_literal });
    try testTokenize("0b00...0b11", &.{ .integer_literal, .ellipsis3, .integer_literal });
    try testTokenize("0o00...0o11", &.{ .integer_literal, .ellipsis3, .integer_literal });
}

test "tokenizer - number literals decimal" {
    try testTokenize("0", &.{.integer_literal});
    try testTokenize("1", &.{.integer_literal});
    try testTokenize("2", &.{.integer_literal});
    try testTokenize("3", &.{.integer_literal});
    try testTokenize("4", &.{.integer_literal});
    try testTokenize("5", &.{.integer_literal});
    try testTokenize("6", &.{.integer_literal});
    try testTokenize("7", &.{.integer_literal});
    try testTokenize("8", &.{.integer_literal});
    try testTokenize("9", &.{.integer_literal});
    try testTokenize("1..", &.{ .integer_literal, .ellipsis2 });
    try testTokenize("0a", &.{ .invalid, .identifier });
    try testTokenize("9b", &.{ .invalid, .identifier });
    try testTokenize("1z", &.{ .invalid, .identifier });
    try testTokenize("1z_1", &.{ .invalid, .identifier });
    try testTokenize("9z3", &.{ .invalid, .identifier });

    try testTokenize("0_0", &.{.integer_literal});
    try testTokenize("0001", &.{.integer_literal});
    try testTokenize("01234567890", &.{.integer_literal});
    try testTokenize("012_345_6789_0", &.{.integer_literal});
    try testTokenize("0_1_2_3_4_5_6_7_8_9_0", &.{.integer_literal});

    try testTokenize("00_", &.{.invalid});
    try testTokenize("0_0_", &.{.invalid});
    try testTokenize("0__0", &.{ .invalid, .identifier });
    try testTokenize("0_0f", &.{ .invalid, .identifier });
    try testTokenize("0_0_f", &.{ .invalid, .identifier });
    try testTokenize("0_0_f_00", &.{ .invalid, .identifier });
    try testTokenize("1_,", &.{ .invalid, .comma });

    try testTokenize("0.0", &.{.float_literal});
    try testTokenize("1.0", &.{.float_literal});
    try testTokenize("10.0", &.{.float_literal});
    try testTokenize("0e0", &.{.float_literal});
    try testTokenize("1e0", &.{.float_literal});
    try testTokenize("1e100", &.{.float_literal});
    try testTokenize("1.0e100", &.{.float_literal});
    try testTokenize("1.0e+100", &.{.float_literal});
    try testTokenize("1.0e-100", &.{.float_literal});
    try testTokenize("1_0_0_0.0_0_0_0_0_1e1_0_0_0", &.{.float_literal});

    try testTokenize("1.", &.{.invalid});
    try testTokenize("1e", &.{.invalid});
    try testTokenize("1.e100", &.{ .invalid, .identifier });
    try testTokenize("1.0e1f0", &.{ .invalid, .identifier });
    try testTokenize("1.0p100", &.{ .invalid, .identifier });
    try testTokenize("1.0p-100", &.{ .invalid, .identifier, .minus, .integer_literal });
    try testTokenize("1.0p1f0", &.{ .invalid, .identifier });
    try testTokenize("1.0_,", &.{ .invalid, .comma });
    try testTokenize("1_.0", &.{ .invalid, .period, .integer_literal });
    try testTokenize("1._", &.{ .invalid, .identifier });
    try testTokenize("1.a", &.{ .invalid, .identifier });
    try testTokenize("1.z", &.{ .invalid, .identifier });
    try testTokenize("1._0", &.{ .invalid, .identifier });
    try testTokenize("1.+", &.{ .invalid, .plus });
    try testTokenize("1._+", &.{ .invalid, .identifier, .plus });
    try testTokenize("1._e", &.{ .invalid, .identifier });
    try testTokenize("1.0e", &.{.invalid});
    try testTokenize("1.0e,", &.{ .invalid, .comma });
    try testTokenize("1.0e_", &.{ .invalid, .identifier });
    try testTokenize("1.0e+_", &.{ .invalid, .identifier });
    try testTokenize("1.0e-_", &.{ .invalid, .identifier });
    try testTokenize("1.0e0_+", &.{ .invalid, .plus });
}

test "tokenizer - number literals binary" {
    try testTokenize("0b0", &.{.integer_literal});
    try testTokenize("0b1", &.{.integer_literal});
    try testTokenize("0b2", &.{ .invalid, .integer_literal });
    try testTokenize("0b3", &.{ .invalid, .integer_literal });
    try testTokenize("0b4", &.{ .invalid, .integer_literal });
    try testTokenize("0b5", &.{ .invalid, .integer_literal });
    try testTokenize("0b6", &.{ .invalid, .integer_literal });
    try testTokenize("0b7", &.{ .invalid, .integer_literal });
    try testTokenize("0b8", &.{ .invalid, .integer_literal });
    try testTokenize("0b9", &.{ .invalid, .integer_literal });
    try testTokenize("0ba", &.{ .invalid, .identifier });
    try testTokenize("0bb", &.{ .invalid, .identifier });
    try testTokenize("0bc", &.{ .invalid, .identifier });
    try testTokenize("0bd", &.{ .invalid, .identifier });
    try testTokenize("0be", &.{ .invalid, .identifier });
    try testTokenize("0bf", &.{ .invalid, .identifier });
    try testTokenize("0bz", &.{ .invalid, .identifier });

    try testTokenize("0b0000_0000", &.{.integer_literal});
    try testTokenize("0b1111_1111", &.{.integer_literal});
    try testTokenize("0b10_10_10_10", &.{.integer_literal});
    try testTokenize("0b0_1_0_1_0_1_0_1", &.{.integer_literal});
    try testTokenize("0b1.", &.{ .integer_literal, .period });
    try testTokenize("0b1.0", &.{ .integer_literal, .period, .integer_literal });

    try testTokenize("0B0", &.{ .invalid, .identifier });
    try testTokenize("0b_", &.{ .invalid, .identifier });
    try testTokenize("0b_0", &.{ .invalid, .identifier });
    try testTokenize("0b1_", &.{.invalid});
    try testTokenize("0b0__1", &.{ .invalid, .identifier });
    try testTokenize("0b0_1_", &.{.invalid});
    try testTokenize("0b1e", &.{ .invalid, .identifier });
    try testTokenize("0b1p", &.{ .invalid, .identifier });
    try testTokenize("0b1e0", &.{ .invalid, .identifier });
    try testTokenize("0b1p0", &.{ .invalid, .identifier });
    try testTokenize("0b1_,", &.{ .invalid, .comma });
}

test "tokenizer - number literals octal" {
    try testTokenize("0o0", &.{.integer_literal});
    try testTokenize("0o1", &.{.integer_literal});
    try testTokenize("0o2", &.{.integer_literal});
    try testTokenize("0o3", &.{.integer_literal});
    try testTokenize("0o4", &.{.integer_literal});
    try testTokenize("0o5", &.{.integer_literal});
    try testTokenize("0o6", &.{.integer_literal});
    try testTokenize("0o7", &.{.integer_literal});
    try testTokenize("0o8", &.{ .invalid, .integer_literal });
    try testTokenize("0o9", &.{ .invalid, .integer_literal });
    try testTokenize("0oa", &.{ .invalid, .identifier });
    try testTokenize("0ob", &.{ .invalid, .identifier });
    try testTokenize("0oc", &.{ .invalid, .identifier });
    try testTokenize("0od", &.{ .invalid, .identifier });
    try testTokenize("0oe", &.{ .invalid, .identifier });
    try testTokenize("0of", &.{ .invalid, .identifier });
    try testTokenize("0oz", &.{ .invalid, .identifier });

    try testTokenize("0o01234567", &.{.integer_literal});
    try testTokenize("0o0123_4567", &.{.integer_literal});
    try testTokenize("0o01_23_45_67", &.{.integer_literal});
    try testTokenize("0o0_1_2_3_4_5_6_7", &.{.integer_literal});
    try testTokenize("0o7.", &.{ .integer_literal, .period });
    try testTokenize("0o7.0", &.{ .integer_literal, .period, .integer_literal });

    try testTokenize("0O0", &.{ .invalid, .identifier });
    try testTokenize("0o_", &.{ .invalid, .identifier });
    try testTokenize("0o_0", &.{ .invalid, .identifier });
    try testTokenize("0o1_", &.{.invalid});
    try testTokenize("0o0__1", &.{ .invalid, .identifier });
    try testTokenize("0o0_1_", &.{.invalid});
    try testTokenize("0o1e", &.{ .invalid, .identifier });
    try testTokenize("0o1p", &.{ .invalid, .identifier });
    try testTokenize("0o1e0", &.{ .invalid, .identifier });
    try testTokenize("0o1p0", &.{ .invalid, .identifier });
    try testTokenize("0o_,", &.{ .invalid, .identifier, .comma });
}

test "tokenizer - number literals hexadecimal" {
    try testTokenize("0x0", &.{.integer_literal});
    try testTokenize("0x1", &.{.integer_literal});
    try testTokenize("0x2", &.{.integer_literal});
    try testTokenize("0x3", &.{.integer_literal});
    try testTokenize("0x4", &.{.integer_literal});
    try testTokenize("0x5", &.{.integer_literal});
    try testTokenize("0x6", &.{.integer_literal});
    try testTokenize("0x7", &.{.integer_literal});
    try testTokenize("0x8", &.{.integer_literal});
    try testTokenize("0x9", &.{.integer_literal});
    try testTokenize("0xa", &.{.integer_literal});
    try testTokenize("0xb", &.{.integer_literal});
    try testTokenize("0xc", &.{.integer_literal});
    try testTokenize("0xd", &.{.integer_literal});
    try testTokenize("0xe", &.{.integer_literal});
    try testTokenize("0xf", &.{.integer_literal});
    try testTokenize("0xA", &.{.integer_literal});
    try testTokenize("0xB", &.{.integer_literal});
    try testTokenize("0xC", &.{.integer_literal});
    try testTokenize("0xD", &.{.integer_literal});
    try testTokenize("0xE", &.{.integer_literal});
    try testTokenize("0xF", &.{.integer_literal});
    try testTokenize("0x0z", &.{ .invalid, .identifier });
    try testTokenize("0xz", &.{ .invalid, .identifier });

    try testTokenize("0x0123456789ABCDEF", &.{.integer_literal});
    try testTokenize("0x0123_4567_89AB_CDEF", &.{.integer_literal});
    try testTokenize("0x01_23_45_67_89AB_CDE_F", &.{.integer_literal});
    try testTokenize("0x0_1_2_3_4_5_6_7_8_9_A_B_C_D_E_F", &.{.integer_literal});

    try testTokenize("0X0", &.{ .invalid, .identifier });
    try testTokenize("0x_", &.{ .invalid, .identifier });
    try testTokenize("0x_1", &.{ .invalid, .identifier });
    try testTokenize("0x1_", &.{.invalid});
    try testTokenize("0x0__1", &.{ .invalid, .identifier });
    try testTokenize("0x0_1_", &.{.invalid});
    try testTokenize("0x_,", &.{ .invalid, .identifier, .comma });

    try testTokenize("0x1.0", &.{.float_literal});
    try testTokenize("0xF.0", &.{.float_literal});
    try testTokenize("0xF.F", &.{.float_literal});
    try testTokenize("0xF.Fp0", &.{.float_literal});
    try testTokenize("0xF.FP0", &.{.float_literal});
    try testTokenize("0x1p0", &.{.float_literal});
    try testTokenize("0xfp0", &.{.float_literal});
    try testTokenize("0x1.0+0xF.0", &.{ .float_literal, .plus, .float_literal });

    try testTokenize("0x1.", &.{.invalid});
    try testTokenize("0xF.", &.{.invalid});
    try testTokenize("0x1.+0xF.", &.{ .invalid, .plus, .invalid });
    try testTokenize("0xff.p10", &.{ .invalid, .identifier });

    try testTokenize("0x0123456.789ABCDEF", &.{.float_literal});
    try testTokenize("0x0_123_456.789_ABC_DEF", &.{.float_literal});
    try testTokenize("0x0_1_2_3_4_5_6.7_8_9_A_B_C_D_E_F", &.{.float_literal});
    try testTokenize("0x0p0", &.{.float_literal});
    try testTokenize("0x0.0p0", &.{.float_literal});
    try testTokenize("0xff.ffp10", &.{.float_literal});
    try testTokenize("0xff.ffP10", &.{.float_literal});
    try testTokenize("0xffp10", &.{.float_literal});
    try testTokenize("0xff_ff.ff_ffp1_0_0_0", &.{.float_literal});
    try testTokenize("0xf_f_f_f.f_f_f_fp+1_000", &.{.float_literal});
    try testTokenize("0xf_f_f_f.f_f_f_fp-1_00_0", &.{.float_literal});

    try testTokenize("0x1e", &.{.integer_literal});
    try testTokenize("0x1e0", &.{.integer_literal});
    try testTokenize("0x1p", &.{.invalid});
    try testTokenize("0xfp0z1", &.{ .invalid, .identifier });
    try testTokenize("0xff.ffpff", &.{ .invalid, .identifier });
    try testTokenize("0x0.p", &.{ .invalid, .identifier });
    try testTokenize("0x0.z", &.{ .invalid, .identifier });
    try testTokenize("0x0._", &.{ .invalid, .identifier });
    try testTokenize("0x0_.0", &.{ .invalid, .period, .integer_literal });
    try testTokenize("0x0_.0.0", &.{ .invalid, .period, .float_literal });
    try testTokenize("0x0._0", &.{ .invalid, .identifier });
    try testTokenize("0x0.0_", &.{.invalid});
    try testTokenize("0x0_p0", &.{ .invalid, .identifier });
    try testTokenize("0x0_.p0", &.{ .invalid, .period, .identifier });
    try testTokenize("0x0._p0", &.{ .invalid, .identifier });
    try testTokenize("0x0.0_p0", &.{ .invalid, .identifier });
    try testTokenize("0x0._0p0", &.{ .invalid, .identifier });
    try testTokenize("0x0.0p_0", &.{ .invalid, .identifier });
    try testTokenize("0x0.0p+_0", &.{ .invalid, .identifier });
    try testTokenize("0x0.0p-_0", &.{ .invalid, .identifier });
    try testTokenize("0x0.0p0_", &.{ .invalid, .eof });
}

test "tokenizer - multi line string literal with only 1 backslash" {
    try testTokenize("x \\\n;", &.{ .identifier, .invalid, .semicolon });
}

test "tokenizer - invalid builtin identifiers" {
    try testTokenize("@()", &.{ .invalid, .l_paren, .r_paren });
    try testTokenize("@0()", &.{ .invalid, .integer_literal, .l_paren, .r_paren });
}

fn testTokenize(source: []const u8, expected_tokens: []const Token.Tag) !void {
    var tokenizer = Tokenizer.init(source);
    for (expected_tokens) |expected_token_id| {
        const token = tokenizer.next();
        if (token.tag != expected_token_id) {
            std.debug.panic("expected {s}, found {s}\n", .{ @tagName(expected_token_id), @tagName(token.tag) });
        }
    }
    const last_token = tokenizer.next();
    try std.testing.expect(last_token.tag == .eof);
    try std.testing.expect(last_token.loc.start == source.len);
}
