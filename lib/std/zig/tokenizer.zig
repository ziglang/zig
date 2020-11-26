// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const mem = std.mem;

pub const Token = struct {
    id: Id,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const keywords = std.ComptimeStringMap(Id, .{
        .{ "align", .Keyword_align },
        .{ "allowzero", .Keyword_allowzero },
        .{ "and", .Keyword_and },
        .{ "anyframe", .Keyword_anyframe },
        .{ "anytype", .Keyword_anytype },
        .{ "asm", .Keyword_asm },
        .{ "async", .Keyword_async },
        .{ "await", .Keyword_await },
        .{ "break", .Keyword_break },
        .{ "callconv", .Keyword_callconv },
        .{ "catch", .Keyword_catch },
        .{ "comptime", .Keyword_comptime },
        .{ "const", .Keyword_const },
        .{ "continue", .Keyword_continue },
        .{ "defer", .Keyword_defer },
        .{ "else", .Keyword_else },
        .{ "enum", .Keyword_enum },
        .{ "errdefer", .Keyword_errdefer },
        .{ "error", .Keyword_error },
        .{ "export", .Keyword_export },
        .{ "extern", .Keyword_extern },
        .{ "false", .Keyword_false },
        .{ "fn", .Keyword_fn },
        .{ "for", .Keyword_for },
        .{ "if", .Keyword_if },
        .{ "inline", .Keyword_inline },
        .{ "noalias", .Keyword_noalias },
        .{ "noasync", .Keyword_nosuspend }, // TODO: remove this
        .{ "noinline", .Keyword_noinline },
        .{ "nosuspend", .Keyword_nosuspend },
        .{ "null", .Keyword_null },
        .{ "opaque", .Keyword_opaque },
        .{ "or", .Keyword_or },
        .{ "orelse", .Keyword_orelse },
        .{ "packed", .Keyword_packed },
        .{ "pub", .Keyword_pub },
        .{ "resume", .Keyword_resume },
        .{ "return", .Keyword_return },
        .{ "linksection", .Keyword_linksection },
        .{ "struct", .Keyword_struct },
        .{ "suspend", .Keyword_suspend },
        .{ "switch", .Keyword_switch },
        .{ "test", .Keyword_test },
        .{ "threadlocal", .Keyword_threadlocal },
        .{ "true", .Keyword_true },
        .{ "try", .Keyword_try },
        .{ "undefined", .Keyword_undefined },
        .{ "union", .Keyword_union },
        .{ "unreachable", .Keyword_unreachable },
        .{ "usingnamespace", .Keyword_usingnamespace },
        .{ "var", .Keyword_var },
        .{ "volatile", .Keyword_volatile },
        .{ "while", .Keyword_while },
    });

    pub fn getKeyword(bytes: []const u8) ?Id {
        return keywords.get(bytes);
    }

    pub const Id = enum {
        Invalid,
        Invalid_ampersands,
        Invalid_periodasterisks,
        Identifier,
        StringLiteral,
        MultilineStringLiteralLine,
        CharLiteral,
        Eof,
        Builtin,
        Bang,
        Pipe,
        PipePipe,
        PipeEqual,
        Equal,
        EqualEqual,
        EqualAngleBracketRight,
        BangEqual,
        LParen,
        RParen,
        Semicolon,
        Percent,
        PercentEqual,
        LBrace,
        RBrace,
        LBracket,
        RBracket,
        Period,
        PeriodAsterisk,
        Ellipsis2,
        Ellipsis3,
        Caret,
        CaretEqual,
        Plus,
        PlusPlus,
        PlusEqual,
        PlusPercent,
        PlusPercentEqual,
        Minus,
        MinusEqual,
        MinusPercent,
        MinusPercentEqual,
        Asterisk,
        AsteriskEqual,
        AsteriskAsterisk,
        AsteriskPercent,
        AsteriskPercentEqual,
        Arrow,
        Colon,
        Slash,
        SlashEqual,
        Comma,
        Ampersand,
        AmpersandEqual,
        QuestionMark,
        AngleBracketLeft,
        AngleBracketLeftEqual,
        AngleBracketAngleBracketLeft,
        AngleBracketAngleBracketLeftEqual,
        AngleBracketRight,
        AngleBracketRightEqual,
        AngleBracketAngleBracketRight,
        AngleBracketAngleBracketRightEqual,
        Tilde,
        IntegerLiteral,
        FloatLiteral,
        LineComment,
        DocComment,
        ContainerDocComment,
        ShebangLine,
        Keyword_align,
        Keyword_allowzero,
        Keyword_and,
        Keyword_anyframe,
        Keyword_anytype,
        Keyword_asm,
        Keyword_async,
        Keyword_await,
        Keyword_break,
        Keyword_callconv,
        Keyword_catch,
        Keyword_comptime,
        Keyword_const,
        Keyword_continue,
        Keyword_defer,
        Keyword_else,
        Keyword_enum,
        Keyword_errdefer,
        Keyword_error,
        Keyword_export,
        Keyword_extern,
        Keyword_false,
        Keyword_fn,
        Keyword_for,
        Keyword_if,
        Keyword_inline,
        Keyword_noalias,
        Keyword_noinline,
        Keyword_nosuspend,
        Keyword_null,
        Keyword_opaque,
        Keyword_or,
        Keyword_orelse,
        Keyword_packed,
        Keyword_pub,
        Keyword_resume,
        Keyword_return,
        Keyword_linksection,
        Keyword_struct,
        Keyword_suspend,
        Keyword_switch,
        Keyword_test,
        Keyword_threadlocal,
        Keyword_true,
        Keyword_try,
        Keyword_undefined,
        Keyword_union,
        Keyword_unreachable,
        Keyword_usingnamespace,
        Keyword_var,
        Keyword_volatile,
        Keyword_while,

        pub fn symbol(id: Id) []const u8 {
            return switch (id) {
                .Invalid => "Invalid",
                .Invalid_ampersands => "&&",
                .Invalid_periodasterisks => ".**",
                .Identifier => "Identifier",
                .StringLiteral => "StringLiteral",
                .MultilineStringLiteralLine => "MultilineStringLiteralLine",
                .CharLiteral => "CharLiteral",
                .Eof => "Eof",
                .Builtin => "Builtin",
                .IntegerLiteral => "IntegerLiteral",
                .FloatLiteral => "FloatLiteral",
                .LineComment => "LineComment",
                .DocComment => "DocComment",
                .ContainerDocComment => "ContainerDocComment",
                .ShebangLine => "ShebangLine",

                .Bang => "!",
                .Pipe => "|",
                .PipePipe => "||",
                .PipeEqual => "|=",
                .Equal => "=",
                .EqualEqual => "==",
                .EqualAngleBracketRight => "=>",
                .BangEqual => "!=",
                .LParen => "(",
                .RParen => ")",
                .Semicolon => ";",
                .Percent => "%",
                .PercentEqual => "%=",
                .LBrace => "{",
                .RBrace => "}",
                .LBracket => "[",
                .RBracket => "]",
                .Period => ".",
                .PeriodAsterisk => ".*",
                .Ellipsis2 => "..",
                .Ellipsis3 => "...",
                .Caret => "^",
                .CaretEqual => "^=",
                .Plus => "+",
                .PlusPlus => "++",
                .PlusEqual => "+=",
                .PlusPercent => "+%",
                .PlusPercentEqual => "+%=",
                .Minus => "-",
                .MinusEqual => "-=",
                .MinusPercent => "-%",
                .MinusPercentEqual => "-%=",
                .Asterisk => "*",
                .AsteriskEqual => "*=",
                .AsteriskAsterisk => "**",
                .AsteriskPercent => "*%",
                .AsteriskPercentEqual => "*%=",
                .Arrow => "->",
                .Colon => ":",
                .Slash => "/",
                .SlashEqual => "/=",
                .Comma => ",",
                .Ampersand => "&",
                .AmpersandEqual => "&=",
                .QuestionMark => "?",
                .AngleBracketLeft => "<",
                .AngleBracketLeftEqual => "<=",
                .AngleBracketAngleBracketLeft => "<<",
                .AngleBracketAngleBracketLeftEqual => "<<=",
                .AngleBracketRight => ">",
                .AngleBracketRightEqual => ">=",
                .AngleBracketAngleBracketRight => ">>",
                .AngleBracketAngleBracketRightEqual => ">>=",
                .Tilde => "~",
                .Keyword_align => "align",
                .Keyword_allowzero => "allowzero",
                .Keyword_and => "and",
                .Keyword_anyframe => "anyframe",
                .Keyword_anytype => "anytype",
                .Keyword_asm => "asm",
                .Keyword_async => "async",
                .Keyword_await => "await",
                .Keyword_break => "break",
                .Keyword_callconv => "callconv",
                .Keyword_catch => "catch",
                .Keyword_comptime => "comptime",
                .Keyword_const => "const",
                .Keyword_continue => "continue",
                .Keyword_defer => "defer",
                .Keyword_else => "else",
                .Keyword_enum => "enum",
                .Keyword_errdefer => "errdefer",
                .Keyword_error => "error",
                .Keyword_export => "export",
                .Keyword_extern => "extern",
                .Keyword_false => "false",
                .Keyword_fn => "fn",
                .Keyword_for => "for",
                .Keyword_if => "if",
                .Keyword_inline => "inline",
                .Keyword_noalias => "noalias",
                .Keyword_noinline => "noinline",
                .Keyword_nosuspend => "nosuspend",
                .Keyword_null => "null",
                .Keyword_opaque => "opaque",
                .Keyword_or => "or",
                .Keyword_orelse => "orelse",
                .Keyword_packed => "packed",
                .Keyword_pub => "pub",
                .Keyword_resume => "resume",
                .Keyword_return => "return",
                .Keyword_linksection => "linksection",
                .Keyword_struct => "struct",
                .Keyword_suspend => "suspend",
                .Keyword_switch => "switch",
                .Keyword_test => "test",
                .Keyword_threadlocal => "threadlocal",
                .Keyword_true => "true",
                .Keyword_try => "try",
                .Keyword_undefined => "undefined",
                .Keyword_union => "union",
                .Keyword_unreachable => "unreachable",
                .Keyword_usingnamespace => "usingnamespace",
                .Keyword_var => "var",
                .Keyword_volatile => "volatile",
                .Keyword_while => "while",
            };
        }
    };
};

pub const Tokenizer = struct {
    buffer: []const u8,
    index: usize,
    pending_invalid_token: ?Token,

    /// For debugging purposes
    pub fn dump(self: *Tokenizer, token: *const Token) void {
        std.debug.warn("{s} \"{s}\"\n", .{ @tagName(token.id), self.buffer[token.start..token.end] });
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
            .id = .Eof,
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
                        result.id = .StringLiteral;
                    },
                    '\'' => {
                        state = .char_literal;
                    },
                    'a'...'z', 'A'...'Z', '_' => {
                        state = .identifier;
                        result.id = .Identifier;
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
                        result.id = .LParen;
                        self.index += 1;
                        break;
                    },
                    ')' => {
                        result.id = .RParen;
                        self.index += 1;
                        break;
                    },
                    '[' => {
                        result.id = .LBracket;
                        self.index += 1;
                        break;
                    },
                    ']' => {
                        result.id = .RBracket;
                        self.index += 1;
                        break;
                    },
                    ';' => {
                        result.id = .Semicolon;
                        self.index += 1;
                        break;
                    },
                    ',' => {
                        result.id = .Comma;
                        self.index += 1;
                        break;
                    },
                    '?' => {
                        result.id = .QuestionMark;
                        self.index += 1;
                        break;
                    },
                    ':' => {
                        result.id = .Colon;
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
                        result.id = .MultilineStringLiteralLine;
                    },
                    '{' => {
                        result.id = .LBrace;
                        self.index += 1;
                        break;
                    },
                    '}' => {
                        result.id = .RBrace;
                        self.index += 1;
                        break;
                    },
                    '~' => {
                        result.id = .Tilde;
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
                        result.id = .IntegerLiteral;
                    },
                    '1'...'9' => {
                        state = .int_literal_dec;
                        result.id = .IntegerLiteral;
                    },
                    else => {
                        result.id = .Invalid;
                        self.index += 1;
                        break;
                    },
                },

                .saw_at_sign => switch (c) {
                    '"' => {
                        result.id = .Identifier;
                        state = .string_literal;
                    },
                    else => {
                        // reinterpret as a builtin
                        self.index -= 1;
                        state = .builtin;
                        result.id = .Builtin;
                    },
                },

                .ampersand => switch (c) {
                    '&' => {
                        result.id = .Invalid_ampersands;
                        self.index += 1;
                        break;
                    },
                    '=' => {
                        result.id = .AmpersandEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Ampersand;
                        break;
                    },
                },

                .asterisk => switch (c) {
                    '=' => {
                        result.id = .AsteriskEqual;
                        self.index += 1;
                        break;
                    },
                    '*' => {
                        result.id = .AsteriskAsterisk;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = .asterisk_percent;
                    },
                    else => {
                        result.id = .Asterisk;
                        break;
                    },
                },

                .asterisk_percent => switch (c) {
                    '=' => {
                        result.id = .AsteriskPercentEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .AsteriskPercent;
                        break;
                    },
                },

                .percent => switch (c) {
                    '=' => {
                        result.id = .PercentEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Percent;
                        break;
                    },
                },

                .plus => switch (c) {
                    '=' => {
                        result.id = .PlusEqual;
                        self.index += 1;
                        break;
                    },
                    '+' => {
                        result.id = .PlusPlus;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = .plus_percent;
                    },
                    else => {
                        result.id = .Plus;
                        break;
                    },
                },

                .plus_percent => switch (c) {
                    '=' => {
                        result.id = .PlusPercentEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .PlusPercent;
                        break;
                    },
                },

                .caret => switch (c) {
                    '=' => {
                        result.id = .CaretEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Caret;
                        break;
                    },
                },

                .identifier => switch (c) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => {},
                    else => {
                        if (Token.getKeyword(self.buffer[result.loc.start..self.index])) |id| {
                            result.id = id;
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
                    else => break,
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
                        result.id = .Invalid;
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
                        result.id = .Invalid;
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
                        result.id = .Invalid;
                        break;
                    },
                },

                .char_literal_unicode_escape_saw_u => switch (c) {
                    '{' => {
                        state = .char_literal_unicode_escape;
                        seen_escape_digits = 0;
                    },
                    else => {
                        result.id = .Invalid;
                        state = .char_literal_unicode_invalid;
                    },
                },

                .char_literal_unicode_escape => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        seen_escape_digits += 1;
                    },
                    '}' => {
                        if (seen_escape_digits == 0) {
                            result.id = .Invalid;
                            state = .char_literal_unicode_invalid;
                        } else {
                            state = .char_literal_end;
                        }
                    },
                    else => {
                        result.id = .Invalid;
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
                        result.id = .CharLiteral;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Invalid;
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
                        result.id = .Invalid;
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
                        result.id = .BangEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Bang;
                        break;
                    },
                },

                .pipe => switch (c) {
                    '=' => {
                        result.id = .PipeEqual;
                        self.index += 1;
                        break;
                    },
                    '|' => {
                        result.id = .PipePipe;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Pipe;
                        break;
                    },
                },

                .equal => switch (c) {
                    '=' => {
                        result.id = .EqualEqual;
                        self.index += 1;
                        break;
                    },
                    '>' => {
                        result.id = .EqualAngleBracketRight;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Equal;
                        break;
                    },
                },

                .minus => switch (c) {
                    '>' => {
                        result.id = .Arrow;
                        self.index += 1;
                        break;
                    },
                    '=' => {
                        result.id = .MinusEqual;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = .minus_percent;
                    },
                    else => {
                        result.id = .Minus;
                        break;
                    },
                },

                .minus_percent => switch (c) {
                    '=' => {
                        result.id = .MinusPercentEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .MinusPercent;
                        break;
                    },
                },

                .angle_bracket_left => switch (c) {
                    '<' => {
                        state = .angle_bracket_angle_bracket_left;
                    },
                    '=' => {
                        result.id = .AngleBracketLeftEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .AngleBracketLeft;
                        break;
                    },
                },

                .angle_bracket_angle_bracket_left => switch (c) {
                    '=' => {
                        result.id = .AngleBracketAngleBracketLeftEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .AngleBracketAngleBracketLeft;
                        break;
                    },
                },

                .angle_bracket_right => switch (c) {
                    '>' => {
                        state = .angle_bracket_angle_bracket_right;
                    },
                    '=' => {
                        result.id = .AngleBracketRightEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .AngleBracketRight;
                        break;
                    },
                },

                .angle_bracket_angle_bracket_right => switch (c) {
                    '=' => {
                        result.id = .AngleBracketAngleBracketRightEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .AngleBracketAngleBracketRight;
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
                        result.id = .Period;
                        break;
                    },
                },

                .period_2 => switch (c) {
                    '.' => {
                        result.id = .Ellipsis3;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Ellipsis2;
                        break;
                    },
                },

                .period_asterisk => switch (c) {
                    '*' => {
                        result.id = .Invalid_periodasterisks;
                        break;
                    },
                    else => {
                        result.id = .PeriodAsterisk;
                        break;
                    },
                },

                .slash => switch (c) {
                    '/' => {
                        state = .line_comment_start;
                        result.id = .LineComment;
                    },
                    '=' => {
                        result.id = .SlashEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Slash;
                        break;
                    },
                },
                .line_comment_start => switch (c) {
                    '/' => {
                        state = .doc_comment_start;
                    },
                    '!' => {
                        result.id = .ContainerDocComment;
                        state = .container_doc_comment;
                    },
                    '\n' => break,
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
                        result.id = .DocComment;
                        break;
                    },
                    '\t', '\r' => {
                        state = .doc_comment;
                        result.id = .DocComment;
                    },
                    else => {
                        state = .doc_comment;
                        result.id = .DocComment;
                        self.checkLiteralCharacter();
                    },
                },
                .line_comment, .doc_comment, .container_doc_comment => switch (c) {
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
                            result.id = .Invalid;
                        }
                        break;
                    },
                },
                .int_literal_bin_no_underscore => switch (c) {
                    '0'...'1' => {
                        state = .int_literal_bin;
                    },
                    else => {
                        result.id = .Invalid;
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
                            result.id = .Invalid;
                        }
                        break;
                    },
                },
                .int_literal_oct_no_underscore => switch (c) {
                    '0'...'7' => {
                        state = .int_literal_oct;
                    },
                    else => {
                        result.id = .Invalid;
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
                            result.id = .Invalid;
                        }
                        break;
                    },
                },
                .int_literal_dec_no_underscore => switch (c) {
                    '0'...'9' => {
                        state = .int_literal_dec;
                    },
                    else => {
                        result.id = .Invalid;
                        break;
                    },
                },
                .int_literal_dec => switch (c) {
                    '_' => {
                        state = .int_literal_dec_no_underscore;
                    },
                    '.' => {
                        state = .num_dot_dec;
                        result.id = .FloatLiteral;
                    },
                    'e', 'E' => {
                        state = .float_exponent_unsigned;
                        result.id = .FloatLiteral;
                    },
                    '0'...'9' => {},
                    else => {
                        if (isIdentifierChar(c)) {
                            result.id = .Invalid;
                        }
                        break;
                    },
                },
                .int_literal_hex_no_underscore => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        state = .int_literal_hex;
                    },
                    else => {
                        result.id = .Invalid;
                        break;
                    },
                },
                .int_literal_hex => switch (c) {
                    '_' => {
                        state = .int_literal_hex_no_underscore;
                    },
                    '.' => {
                        state = .num_dot_hex;
                        result.id = .FloatLiteral;
                    },
                    'p', 'P' => {
                        state = .float_exponent_unsigned;
                        result.id = .FloatLiteral;
                    },
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    else => {
                        if (isIdentifierChar(c)) {
                            result.id = .Invalid;
                        }
                        break;
                    },
                },
                .num_dot_dec => switch (c) {
                    '.' => {
                        result.id = .IntegerLiteral;
                        self.index -= 1;
                        state = .start;
                        break;
                    },
                    'e', 'E' => {
                        state = .float_exponent_unsigned;
                    },
                    '0'...'9' => {
                        state = .float_fraction_dec;
                    },
                    else => {
                        if (isIdentifierChar(c)) {
                            result.id = .Invalid;
                        }
                        break;
                    },
                },
                .num_dot_hex => switch (c) {
                    '.' => {
                        result.id = .IntegerLiteral;
                        self.index -= 1;
                        state = .start;
                        break;
                    },
                    'p', 'P' => {
                        state = .float_exponent_unsigned;
                    },
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        result.id = .FloatLiteral;
                        state = .float_fraction_hex;
                    },
                    else => {
                        if (isIdentifierChar(c)) {
                            result.id = .Invalid;
                        }
                        break;
                    },
                },
                .float_fraction_dec_no_underscore => switch (c) {
                    '0'...'9' => {
                        state = .float_fraction_dec;
                    },
                    else => {
                        result.id = .Invalid;
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
                            result.id = .Invalid;
                        }
                        break;
                    },
                },
                .float_fraction_hex_no_underscore => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        state = .float_fraction_hex;
                    },
                    else => {
                        result.id = .Invalid;
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
                            result.id = .Invalid;
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
                        result.id = .Invalid;
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
                            result.id = .Invalid;
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
                => {},

                .identifier => {
                    if (Token.getKeyword(self.buffer[result.loc.start..self.index])) |id| {
                        result.id = id;
                    }
                },
                .line_comment, .line_comment_start => {
                    result.id = .LineComment;
                },
                .doc_comment, .doc_comment_start => {
                    result.id = .DocComment;
                },
                .container_doc_comment => {
                    result.id = .ContainerDocComment;
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
                    result.id = .Invalid;
                },

                .equal => {
                    result.id = .Equal;
                },
                .bang => {
                    result.id = .Bang;
                },
                .minus => {
                    result.id = .Minus;
                },
                .slash => {
                    result.id = .Slash;
                },
                .zero => {
                    result.id = .IntegerLiteral;
                },
                .ampersand => {
                    result.id = .Ampersand;
                },
                .period => {
                    result.id = .Period;
                },
                .period_2 => {
                    result.id = .Ellipsis2;
                },
                .period_asterisk => {
                    result.id = .PeriodAsterisk;
                },
                .pipe => {
                    result.id = .Pipe;
                },
                .angle_bracket_angle_bracket_right => {
                    result.id = .AngleBracketAngleBracketRight;
                },
                .angle_bracket_right => {
                    result.id = .AngleBracketRight;
                },
                .angle_bracket_angle_bracket_left => {
                    result.id = .AngleBracketAngleBracketLeft;
                },
                .angle_bracket_left => {
                    result.id = .AngleBracketLeft;
                },
                .plus_percent => {
                    result.id = .PlusPercent;
                },
                .plus => {
                    result.id = .Plus;
                },
                .percent => {
                    result.id = .Percent;
                },
                .caret => {
                    result.id = .Caret;
                },
                .asterisk_percent => {
                    result.id = .AsteriskPercent;
                },
                .asterisk => {
                    result.id = .Asterisk;
                },
                .minus_percent => {
                    result.id = .MinusPercent;
                },
            }
        }

        if (result.id == .Eof) {
            if (self.pending_invalid_token) |token| {
                self.pending_invalid_token = null;
                return token;
            }
        }

        result.loc.end = self.index;
        return result;
    }

    fn checkLiteralCharacter(self: *Tokenizer) void {
        if (self.pending_invalid_token != null) return;
        const invalid_length = self.getInvalidCharacterLength();
        if (invalid_length == 0) return;
        self.pending_invalid_token = .{
            .id = .Invalid,
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
    testTokenize("test", &[_]Token.Id{.Keyword_test});
}

test "tokenizer - unknown length pointer and then c pointer" {
    testTokenize(
        \\[*]u8
        \\[*c]u8
    , &[_]Token.Id{
        .LBracket,
        .Asterisk,
        .RBracket,
        .Identifier,
        .LBracket,
        .Asterisk,
        .Identifier,
        .RBracket,
        .Identifier,
    });
}

test "tokenizer - char literal with hex escape" {
    testTokenize(
        \\'\x1b'
    , &[_]Token.Id{.CharLiteral});
    testTokenize(
        \\'\x1'
    , &[_]Token.Id{ .Invalid, .Invalid });
}

test "tokenizer - char literal with unicode escapes" {
    // Valid unicode escapes
    testTokenize(
        \\'\u{3}'
    , &[_]Token.Id{.CharLiteral});
    testTokenize(
        \\'\u{01}'
    , &[_]Token.Id{.CharLiteral});
    testTokenize(
        \\'\u{2a}'
    , &[_]Token.Id{.CharLiteral});
    testTokenize(
        \\'\u{3f9}'
    , &[_]Token.Id{.CharLiteral});
    testTokenize(
        \\'\u{6E09aBc1523}'
    , &[_]Token.Id{.CharLiteral});
    testTokenize(
        \\"\u{440}"
    , &[_]Token.Id{.StringLiteral});

    // Invalid unicode escapes
    testTokenize(
        \\'\u'
    , &[_]Token.Id{.Invalid});
    testTokenize(
        \\'\u{{'
    , &[_]Token.Id{ .Invalid, .Invalid });
    testTokenize(
        \\'\u{}'
    , &[_]Token.Id{ .Invalid, .Invalid });
    testTokenize(
        \\'\u{s}'
    , &[_]Token.Id{ .Invalid, .Invalid });
    testTokenize(
        \\'\u{2z}'
    , &[_]Token.Id{ .Invalid, .Invalid });
    testTokenize(
        \\'\u{4a'
    , &[_]Token.Id{.Invalid});

    // Test old-style unicode literals
    testTokenize(
        \\'\u0333'
    , &[_]Token.Id{ .Invalid, .Invalid });
    testTokenize(
        \\'\U0333'
    , &[_]Token.Id{ .Invalid, .IntegerLiteral, .Invalid });
}

test "tokenizer - char literal with unicode code point" {
    testTokenize(
        \\'💩'
    , &[_]Token.Id{.CharLiteral});
}

test "tokenizer - float literal e exponent" {
    testTokenize("a = 4.94065645841246544177e-324;\n", &[_]Token.Id{
        .Identifier,
        .Equal,
        .FloatLiteral,
        .Semicolon,
    });
}

test "tokenizer - float literal p exponent" {
    testTokenize("a = 0x1.a827999fcef32p+1022;\n", &[_]Token.Id{
        .Identifier,
        .Equal,
        .FloatLiteral,
        .Semicolon,
    });
}

test "tokenizer - chars" {
    testTokenize("'c'", &[_]Token.Id{.CharLiteral});
}

test "tokenizer - invalid token characters" {
    testTokenize("#", &[_]Token.Id{.Invalid});
    testTokenize("`", &[_]Token.Id{.Invalid});
    testTokenize("'c", &[_]Token.Id{.Invalid});
    testTokenize("'", &[_]Token.Id{.Invalid});
    testTokenize("''", &[_]Token.Id{ .Invalid, .Invalid });
}

test "tokenizer - invalid literal/comment characters" {
    testTokenize("\"\x00\"", &[_]Token.Id{
        .StringLiteral,
        .Invalid,
    });
    testTokenize("//\x00", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
    testTokenize("//\x1f", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
    testTokenize("//\x7f", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
}

test "tokenizer - utf8" {
    testTokenize("//\xc2\x80", &[_]Token.Id{.LineComment});
    testTokenize("//\xf4\x8f\xbf\xbf", &[_]Token.Id{.LineComment});
}

test "tokenizer - invalid utf8" {
    testTokenize("//\x80", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
    testTokenize("//\xbf", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
    testTokenize("//\xf8", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
    testTokenize("//\xff", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
    testTokenize("//\xc2\xc0", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
    testTokenize("//\xe0", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
    testTokenize("//\xf0", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
    testTokenize("//\xf0\x90\x80\xc0", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
}

test "tokenizer - illegal unicode codepoints" {
    // unicode newline characters.U+0085, U+2028, U+2029
    testTokenize("//\xc2\x84", &[_]Token.Id{.LineComment});
    testTokenize("//\xc2\x85", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
    testTokenize("//\xc2\x86", &[_]Token.Id{.LineComment});
    testTokenize("//\xe2\x80\xa7", &[_]Token.Id{.LineComment});
    testTokenize("//\xe2\x80\xa8", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
    testTokenize("//\xe2\x80\xa9", &[_]Token.Id{
        .LineComment,
        .Invalid,
    });
    testTokenize("//\xe2\x80\xaa", &[_]Token.Id{.LineComment});
}

test "tokenizer - string identifier and builtin fns" {
    testTokenize(
        \\const @"if" = @import("std");
    , &[_]Token.Id{
        .Keyword_const,
        .Identifier,
        .Equal,
        .Builtin,
        .LParen,
        .StringLiteral,
        .RParen,
        .Semicolon,
    });
}

test "tokenizer - multiline string literal with literal tab" {
    testTokenize(
        \\\\foo	bar
    , &[_]Token.Id{
        .MultilineStringLiteralLine,
    });
}

test "tokenizer - comments with literal tab" {
    testTokenize(
        \\//foo	bar
        \\//!foo	bar
        \\///foo	bar
        \\//	foo
        \\///	foo
        \\///	/foo
    , &[_]Token.Id{
        .LineComment,
        .ContainerDocComment,
        .DocComment,
        .LineComment,
        .DocComment,
        .DocComment,
    });
}

test "tokenizer - pipe and then invalid" {
    testTokenize("||=", &[_]Token.Id{
        .PipePipe,
        .Equal,
    });
}

test "tokenizer - line comment and doc comment" {
    testTokenize("//", &[_]Token.Id{.LineComment});
    testTokenize("// a / b", &[_]Token.Id{.LineComment});
    testTokenize("// /", &[_]Token.Id{.LineComment});
    testTokenize("/// a", &[_]Token.Id{.DocComment});
    testTokenize("///", &[_]Token.Id{.DocComment});
    testTokenize("////", &[_]Token.Id{.LineComment});
    testTokenize("//!", &[_]Token.Id{.ContainerDocComment});
    testTokenize("//!!", &[_]Token.Id{.ContainerDocComment});
}

test "tokenizer - line comment followed by identifier" {
    testTokenize(
        \\    Unexpected,
        \\    // another
        \\    Another,
    , &[_]Token.Id{
        .Identifier,
        .Comma,
        .LineComment,
        .Identifier,
        .Comma,
    });
}

test "tokenizer - UTF-8 BOM is recognized and skipped" {
    testTokenize("\xEF\xBB\xBFa;\n", &[_]Token.Id{
        .Identifier,
        .Semicolon,
    });
}

test "correctly parse pointer assignment" {
    testTokenize("b.*=3;\n", &[_]Token.Id{
        .Identifier,
        .PeriodAsterisk,
        .Equal,
        .IntegerLiteral,
        .Semicolon,
    });
}

test "correctly parse pointer dereference followed by asterisk" {
    testTokenize("\"b\".* ** 10", &[_]Token.Id{
        .StringLiteral,
        .PeriodAsterisk,
        .AsteriskAsterisk,
        .IntegerLiteral,
    });

    testTokenize("(\"b\".*)** 10", &[_]Token.Id{
        .LParen,
        .StringLiteral,
        .PeriodAsterisk,
        .RParen,
        .AsteriskAsterisk,
        .IntegerLiteral,
    });

    testTokenize("\"b\".*** 10", &[_]Token.Id{
        .StringLiteral,
        .Invalid_periodasterisks,
        .AsteriskAsterisk,
        .IntegerLiteral,
    });
}

test "tokenizer - range literals" {
    testTokenize("0...9", &[_]Token.Id{ .IntegerLiteral, .Ellipsis3, .IntegerLiteral });
    testTokenize("'0'...'9'", &[_]Token.Id{ .CharLiteral, .Ellipsis3, .CharLiteral });
    testTokenize("0x00...0x09", &[_]Token.Id{ .IntegerLiteral, .Ellipsis3, .IntegerLiteral });
    testTokenize("0b00...0b11", &[_]Token.Id{ .IntegerLiteral, .Ellipsis3, .IntegerLiteral });
    testTokenize("0o00...0o11", &[_]Token.Id{ .IntegerLiteral, .Ellipsis3, .IntegerLiteral });
}

test "tokenizer - number literals decimal" {
    testTokenize("0", &[_]Token.Id{.IntegerLiteral});
    testTokenize("1", &[_]Token.Id{.IntegerLiteral});
    testTokenize("2", &[_]Token.Id{.IntegerLiteral});
    testTokenize("3", &[_]Token.Id{.IntegerLiteral});
    testTokenize("4", &[_]Token.Id{.IntegerLiteral});
    testTokenize("5", &[_]Token.Id{.IntegerLiteral});
    testTokenize("6", &[_]Token.Id{.IntegerLiteral});
    testTokenize("7", &[_]Token.Id{.IntegerLiteral});
    testTokenize("8", &[_]Token.Id{.IntegerLiteral});
    testTokenize("9", &[_]Token.Id{.IntegerLiteral});
    testTokenize("1..", &[_]Token.Id{ .IntegerLiteral, .Ellipsis2 });
    testTokenize("0a", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("9b", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1z", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1z_1", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("9z3", &[_]Token.Id{ .Invalid, .Identifier });

    testTokenize("0_0", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0001", &[_]Token.Id{.IntegerLiteral});
    testTokenize("01234567890", &[_]Token.Id{.IntegerLiteral});
    testTokenize("012_345_6789_0", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0_1_2_3_4_5_6_7_8_9_0", &[_]Token.Id{.IntegerLiteral});

    testTokenize("00_", &[_]Token.Id{.Invalid});
    testTokenize("0_0_", &[_]Token.Id{.Invalid});
    testTokenize("0__0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0_0f", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0_0_f", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0_0_f_00", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1_,", &[_]Token.Id{ .Invalid, .Comma });

    testTokenize("1.", &[_]Token.Id{.FloatLiteral});
    testTokenize("0.0", &[_]Token.Id{.FloatLiteral});
    testTokenize("1.0", &[_]Token.Id{.FloatLiteral});
    testTokenize("10.0", &[_]Token.Id{.FloatLiteral});
    testTokenize("0e0", &[_]Token.Id{.FloatLiteral});
    testTokenize("1e0", &[_]Token.Id{.FloatLiteral});
    testTokenize("1e100", &[_]Token.Id{.FloatLiteral});
    testTokenize("1.e100", &[_]Token.Id{.FloatLiteral});
    testTokenize("1.0e100", &[_]Token.Id{.FloatLiteral});
    testTokenize("1.0e+100", &[_]Token.Id{.FloatLiteral});
    testTokenize("1.0e-100", &[_]Token.Id{.FloatLiteral});
    testTokenize("1_0_0_0.0_0_0_0_0_1e1_0_0_0", &[_]Token.Id{.FloatLiteral});
    testTokenize("1.+", &[_]Token.Id{ .FloatLiteral, .Plus });

    testTokenize("1e", &[_]Token.Id{.Invalid});
    testTokenize("1.0e1f0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1.0p100", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1.0p-100", &[_]Token.Id{ .Invalid, .Identifier, .Minus, .IntegerLiteral });
    testTokenize("1.0p1f0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1.0_,", &[_]Token.Id{ .Invalid, .Comma });
    testTokenize("1_.0", &[_]Token.Id{ .Invalid, .Period, .IntegerLiteral });
    testTokenize("1._", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1.a", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1.z", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1._0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1._+", &[_]Token.Id{ .Invalid, .Identifier, .Plus });
    testTokenize("1._e", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1.0e", &[_]Token.Id{.Invalid});
    testTokenize("1.0e,", &[_]Token.Id{ .Invalid, .Comma });
    testTokenize("1.0e_", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1.0e+_", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1.0e-_", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("1.0e0_+", &[_]Token.Id{ .Invalid, .Plus });
}

test "tokenizer - number literals binary" {
    testTokenize("0b0", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0b1", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0b2", &[_]Token.Id{ .Invalid, .IntegerLiteral });
    testTokenize("0b3", &[_]Token.Id{ .Invalid, .IntegerLiteral });
    testTokenize("0b4", &[_]Token.Id{ .Invalid, .IntegerLiteral });
    testTokenize("0b5", &[_]Token.Id{ .Invalid, .IntegerLiteral });
    testTokenize("0b6", &[_]Token.Id{ .Invalid, .IntegerLiteral });
    testTokenize("0b7", &[_]Token.Id{ .Invalid, .IntegerLiteral });
    testTokenize("0b8", &[_]Token.Id{ .Invalid, .IntegerLiteral });
    testTokenize("0b9", &[_]Token.Id{ .Invalid, .IntegerLiteral });
    testTokenize("0ba", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0bb", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0bc", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0bd", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0be", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0bf", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0bz", &[_]Token.Id{ .Invalid, .Identifier });

    testTokenize("0b0000_0000", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0b1111_1111", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0b10_10_10_10", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0b0_1_0_1_0_1_0_1", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0b1.", &[_]Token.Id{ .IntegerLiteral, .Period });
    testTokenize("0b1.0", &[_]Token.Id{ .IntegerLiteral, .Period, .IntegerLiteral });

    testTokenize("0B0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0b_", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0b_0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0b1_", &[_]Token.Id{.Invalid});
    testTokenize("0b0__1", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0b0_1_", &[_]Token.Id{.Invalid});
    testTokenize("0b1e", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0b1p", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0b1e0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0b1p0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0b1_,", &[_]Token.Id{ .Invalid, .Comma });
}

test "tokenizer - number literals octal" {
    testTokenize("0o0", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0o1", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0o2", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0o3", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0o4", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0o5", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0o6", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0o7", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0o8", &[_]Token.Id{ .Invalid, .IntegerLiteral });
    testTokenize("0o9", &[_]Token.Id{ .Invalid, .IntegerLiteral });
    testTokenize("0oa", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0ob", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0oc", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0od", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0oe", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0of", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0oz", &[_]Token.Id{ .Invalid, .Identifier });

    testTokenize("0o01234567", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0o0123_4567", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0o01_23_45_67", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0o0_1_2_3_4_5_6_7", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0o7.", &[_]Token.Id{ .IntegerLiteral, .Period });
    testTokenize("0o7.0", &[_]Token.Id{ .IntegerLiteral, .Period, .IntegerLiteral });

    testTokenize("0O0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0o_", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0o_0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0o1_", &[_]Token.Id{.Invalid});
    testTokenize("0o0__1", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0o0_1_", &[_]Token.Id{.Invalid});
    testTokenize("0o1e", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0o1p", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0o1e0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0o1p0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0o_,", &[_]Token.Id{ .Invalid, .Identifier, .Comma });
}

test "tokenizer - number literals hexadeciaml" {
    testTokenize("0x0", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x1", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x2", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x3", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x4", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x5", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x6", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x7", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x8", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x9", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0xa", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0xb", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0xc", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0xd", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0xe", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0xf", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0xA", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0xB", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0xC", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0xD", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0xE", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0xF", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x0z", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0xz", &[_]Token.Id{ .Invalid, .Identifier });

    testTokenize("0x0123456789ABCDEF", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x0123_4567_89AB_CDEF", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x01_23_45_67_89AB_CDE_F", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x0_1_2_3_4_5_6_7_8_9_A_B_C_D_E_F", &[_]Token.Id{.IntegerLiteral});

    testTokenize("0X0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x_", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x_1", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x1_", &[_]Token.Id{.Invalid});
    testTokenize("0x0__1", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x0_1_", &[_]Token.Id{.Invalid});
    testTokenize("0x_,", &[_]Token.Id{ .Invalid, .Identifier, .Comma });

    testTokenize("0x1.", &[_]Token.Id{.FloatLiteral});
    testTokenize("0x1.0", &[_]Token.Id{.FloatLiteral});
    testTokenize("0xF.", &[_]Token.Id{.FloatLiteral});
    testTokenize("0xF.0", &[_]Token.Id{.FloatLiteral});
    testTokenize("0xF.F", &[_]Token.Id{.FloatLiteral});
    testTokenize("0xF.Fp0", &[_]Token.Id{.FloatLiteral});
    testTokenize("0xF.FP0", &[_]Token.Id{.FloatLiteral});
    testTokenize("0x1p0", &[_]Token.Id{.FloatLiteral});
    testTokenize("0xfp0", &[_]Token.Id{.FloatLiteral});
    testTokenize("0x1.+0xF.", &[_]Token.Id{ .FloatLiteral, .Plus, .FloatLiteral });

    testTokenize("0x0123456.789ABCDEF", &[_]Token.Id{.FloatLiteral});
    testTokenize("0x0_123_456.789_ABC_DEF", &[_]Token.Id{.FloatLiteral});
    testTokenize("0x0_1_2_3_4_5_6.7_8_9_A_B_C_D_E_F", &[_]Token.Id{.FloatLiteral});
    testTokenize("0x0p0", &[_]Token.Id{.FloatLiteral});
    testTokenize("0x0.0p0", &[_]Token.Id{.FloatLiteral});
    testTokenize("0xff.ffp10", &[_]Token.Id{.FloatLiteral});
    testTokenize("0xff.ffP10", &[_]Token.Id{.FloatLiteral});
    testTokenize("0xff.p10", &[_]Token.Id{.FloatLiteral});
    testTokenize("0xffp10", &[_]Token.Id{.FloatLiteral});
    testTokenize("0xff_ff.ff_ffp1_0_0_0", &[_]Token.Id{.FloatLiteral});
    testTokenize("0xf_f_f_f.f_f_f_fp+1_000", &[_]Token.Id{.FloatLiteral});
    testTokenize("0xf_f_f_f.f_f_f_fp-1_00_0", &[_]Token.Id{.FloatLiteral});

    testTokenize("0x1e", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x1e0", &[_]Token.Id{.IntegerLiteral});
    testTokenize("0x1p", &[_]Token.Id{.Invalid});
    testTokenize("0xfp0z1", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0xff.ffpff", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x0.p", &[_]Token.Id{.Invalid});
    testTokenize("0x0.z", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x0._", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x0_.0", &[_]Token.Id{ .Invalid, .Period, .IntegerLiteral });
    testTokenize("0x0_.0.0", &[_]Token.Id{ .Invalid, .Period, .FloatLiteral });
    testTokenize("0x0._0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x0.0_", &[_]Token.Id{.Invalid});
    testTokenize("0x0_p0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x0_.p0", &[_]Token.Id{ .Invalid, .Period, .Identifier });
    testTokenize("0x0._p0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x0.0_p0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x0._0p0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x0.0p_0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x0.0p+_0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x0.0p-_0", &[_]Token.Id{ .Invalid, .Identifier });
    testTokenize("0x0.0p0_", &[_]Token.Id{ .Invalid, .Eof });
}

fn testTokenize(source: []const u8, expected_tokens: []const Token.Id) void {
    var tokenizer = Tokenizer.init(source);
    for (expected_tokens) |expected_token_id| {
        const token = tokenizer.next();
        if (token.id != expected_token_id) {
            std.debug.panic("expected {s}, found {s}\n", .{ @tagName(expected_token_id), @tagName(token.id) });
        }
    }
    const last_token = tokenizer.next();
    std.testing.expect(last_token.id == .Eof);
}
