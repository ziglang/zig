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
        .{ "align", .keyword_align },
        .{ "allowzero", .keyword_allowzero },
        .{ "and", .keyword_and },
        .{ "anyframe", .keyword_anyframe },
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
        .{ "noasync", .keyword_nosuspend }, // TODO: remove this
        .{ "noinline", .keyword_noinline },
        .{ "nosuspend", .keyword_nosuspend },
        .{ "null", .keyword_null },
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

    pub fn getKeyword(bytes: []const u8) ?Id {
        return keywords.get(bytes);
    }

    pub const Id = enum {
        invalid,
        invalid_ampersands,
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
        ellipsis_2,
        ellipsis_3,
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
        line_comment,
        doc_comment,
        container_doc_comment,
        shebang_line,
        keyword_align,
        keyword_allowzero,
        keyword_and,
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
        keyword_or,
        keyword_orelse,
        keyword_packed,
        keyword_anyframe,
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

        pub fn symbol(id: Id) []const u8 {
            return switch (id) {
                .invalid => "invalid",
                .invalid_ampersands => "&&",
                .identifier => "identifier",
                .string_literal => "StringLiteral",
                .multiline_string_literal_line => "MultilineStringLiteralLine",
                .char_literal => "CharLiteral",
                .eof => "Eof",
                .builtin => "Builtin",
                .integer_literal => "integer_literal",
                .float_literal => "float_literal",
                .line_comment => "line_comment",
                .doc_comment => "DocComment",
                .container_doc_comment => "ContainerDocComment",
                .shebang_line => "ShebangLine",

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
                .ellipsis_2 => "..",
                .ellipsis_3 => "...",
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
    };
};

pub const Tokenizer = struct {
    buffer: []const u8,
    index: usize,
    pending_invalid_token: ?Token,

    /// For debugging purposes
    pub fn dump(self: *Tokenizer, token: *const Token) void {
        std.debug.warn("{} \"{}\"\n", .{ @tagName(token.id), self.buffer[token.start..token.end] });
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
            .id = .eof,
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
                        result.id = .string_literal;
                    },
                    '\'' => {
                        state = .char_literal;
                    },
                    'a'...'z', 'A'...'Z', '_' => {
                        state = .identifier;
                        result.id = .identifier;
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
                        result.id = .l_paren;
                        self.index += 1;
                        break;
                    },
                    ')' => {
                        result.id = .r_paren;
                        self.index += 1;
                        break;
                    },
                    '[' => {
                        result.id = .l_bracket;
                        self.index += 1;
                        break;
                    },
                    ']' => {
                        result.id = .r_bracket;
                        self.index += 1;
                        break;
                    },
                    ';' => {
                        result.id = .semicolon;
                        self.index += 1;
                        break;
                    },
                    ',' => {
                        result.id = .comma;
                        self.index += 1;
                        break;
                    },
                    '?' => {
                        result.id = .question_mark;
                        self.index += 1;
                        break;
                    },
                    ':' => {
                        result.id = .colon;
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
                        result.id = .multiline_string_literal_line;
                    },
                    '{' => {
                        result.id = .l_brace;
                        self.index += 1;
                        break;
                    },
                    '}' => {
                        result.id = .r_brace;
                        self.index += 1;
                        break;
                    },
                    '~' => {
                        result.id = .tilde;
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
                        result.id = .integer_literal;
                    },
                    '1'...'9' => {
                        state = .int_literal_dec;
                        result.id = .integer_literal;
                    },
                    else => {
                        result.id = .invalid;
                        self.index += 1;
                        break;
                    },
                },

                .saw_at_sign => switch (c) {
                    '"' => {
                        result.id = .identifier;
                        state = .string_literal;
                    },
                    else => {
                        // reinterpret as a builtin
                        self.index -= 1;
                        state = .builtin;
                        result.id = .builtin;
                    },
                },

                .ampersand => switch (c) {
                    '&' => {
                        result.id = .invalid_ampersands;
                        self.index += 1;
                        break;
                    },
                    '=' => {
                        result.id = .ampersand_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .ampersand;
                        break;
                    },
                },

                .asterisk => switch (c) {
                    '=' => {
                        result.id = .asterisk_equal;
                        self.index += 1;
                        break;
                    },
                    '*' => {
                        result.id = .asterisk_asterisk;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = .asterisk_percent;
                    },
                    else => {
                        result.id = .asterisk;
                        break;
                    },
                },

                .asterisk_percent => switch (c) {
                    '=' => {
                        result.id = .asterisk_percent_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .asterisk_percent;
                        break;
                    },
                },

                .percent => switch (c) {
                    '=' => {
                        result.id = .percent_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .percent;
                        break;
                    },
                },

                .plus => switch (c) {
                    '=' => {
                        result.id = .plus_equal;
                        self.index += 1;
                        break;
                    },
                    '+' => {
                        result.id = .plus_plus;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = .plus_percent;
                    },
                    else => {
                        result.id = .plus;
                        break;
                    },
                },

                .plus_percent => switch (c) {
                    '=' => {
                        result.id = .plus_percent_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .plus_percent;
                        break;
                    },
                },

                .caret => switch (c) {
                    '=' => {
                        result.id = .caret_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .caret;
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
                        result.id = .invalid;
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
                        result.id = .invalid;
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
                        result.id = .invalid;
                        break;
                    },
                },

                .char_literal_unicode_escape_saw_u => switch (c) {
                    '{' => {
                        state = .char_literal_unicode_escape;
                        seen_escape_digits = 0;
                    },
                    else => {
                        result.id = .invalid;
                        state = .char_literal_unicode_invalid;
                    },
                },

                .char_literal_unicode_escape => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        seen_escape_digits += 1;
                    },
                    '}' => {
                        if (seen_escape_digits == 0) {
                            result.id = .invalid;
                            state = .char_literal_unicode_invalid;
                        } else {
                            state = .char_literal_end;
                        }
                    },
                    else => {
                        result.id = .invalid;
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
                        result.id = .char_literal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .invalid;
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
                        result.id = .invalid;
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
                        result.id = .bang_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .bang;
                        break;
                    },
                },

                .pipe => switch (c) {
                    '=' => {
                        result.id = .pipe_equal;
                        self.index += 1;
                        break;
                    },
                    '|' => {
                        result.id = .pipe_pipe;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .pipe;
                        break;
                    },
                },

                .equal => switch (c) {
                    '=' => {
                        result.id = .equal_equal;
                        self.index += 1;
                        break;
                    },
                    '>' => {
                        result.id = .equal_angle_bracket_right;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .equal;
                        break;
                    },
                },

                .minus => switch (c) {
                    '>' => {
                        result.id = .arrow;
                        self.index += 1;
                        break;
                    },
                    '=' => {
                        result.id = .minus_equal;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = .minus_percent;
                    },
                    else => {
                        result.id = .minus;
                        break;
                    },
                },

                .minus_percent => switch (c) {
                    '=' => {
                        result.id = .minus_percent_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .minus_percent;
                        break;
                    },
                },

                .angle_bracket_left => switch (c) {
                    '<' => {
                        state = .angle_bracket_angle_bracket_left;
                    },
                    '=' => {
                        result.id = .angle_bracket_left_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .angle_bracket_left;
                        break;
                    },
                },

                .angle_bracket_angle_bracket_left => switch (c) {
                    '=' => {
                        result.id = .angle_bracket_angle_bracket_left_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .angle_bracket_angle_bracket_left;
                        break;
                    },
                },

                .angle_bracket_right => switch (c) {
                    '>' => {
                        state = .angle_bracket_angle_bracket_right;
                    },
                    '=' => {
                        result.id = .angle_bracket_right_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .angle_bracket_right;
                        break;
                    },
                },

                .angle_bracket_angle_bracket_right => switch (c) {
                    '=' => {
                        result.id = .angle_bracket_angle_bracket_right_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .angle_bracket_angle_bracket_right;
                        break;
                    },
                },

                .period => switch (c) {
                    '.' => {
                        state = .period_2;
                    },
                    '*' => {
                        result.id = .period_asterisk;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .period;
                        break;
                    },
                },

                .period_2 => switch (c) {
                    '.' => {
                        result.id = .ellipsis_3;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .ellipsis_2;
                        break;
                    },
                },

                .slash => switch (c) {
                    '/' => {
                        state = .line_comment_start;
                        result.id = .line_comment;
                    },
                    '=' => {
                        result.id = .slash_equal;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .slash;
                        break;
                    },
                },
                .line_comment_start => switch (c) {
                    '/' => {
                        state = .doc_comment_start;
                    },
                    '!' => {
                        result.id = .container_doc_comment;
                        state = .container_doc_comment;
                    },
                    '\n' => break,
                    '\t' => state = .line_comment,
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
                        result.id = .doc_comment;
                        break;
                    },
                    '\t' => {
                        state = .doc_comment;
                        result.id = .doc_comment;
                    },
                    else => {
                        state = .doc_comment;
                        result.id = .doc_comment;
                        self.checkLiteralCharacter();
                    },
                },
                .line_comment, .doc_comment, .container_doc_comment => switch (c) {
                    '\n' => break,
                    '\t' => {},
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
                            result.id = .invalid;
                        }
                        break;
                    },
                },
                .int_literal_bin_no_underscore => switch (c) {
                    '0'...'1' => {
                        state = .int_literal_bin;
                    },
                    else => {
                        result.id = .invalid;
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
                            result.id = .invalid;
                        }
                        break;
                    },
                },
                .int_literal_oct_no_underscore => switch (c) {
                    '0'...'7' => {
                        state = .int_literal_oct;
                    },
                    else => {
                        result.id = .invalid;
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
                            result.id = .invalid;
                        }
                        break;
                    },
                },
                .int_literal_dec_no_underscore => switch (c) {
                    '0'...'9' => {
                        state = .int_literal_dec;
                    },
                    else => {
                        result.id = .invalid;
                        break;
                    },
                },
                .int_literal_dec => switch (c) {
                    '_' => {
                        state = .int_literal_dec_no_underscore;
                    },
                    '.' => {
                        state = .num_dot_dec;
                        result.id = .float_literal;
                    },
                    'e', 'E' => {
                        state = .float_exponent_unsigned;
                        result.id = .float_literal;
                    },
                    '0'...'9' => {},
                    else => {
                        if (isIdentifierChar(c)) {
                            result.id = .invalid;
                        }
                        break;
                    },
                },
                .int_literal_hex_no_underscore => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        state = .int_literal_hex;
                    },
                    else => {
                        result.id = .invalid;
                        break;
                    },
                },
                .int_literal_hex => switch (c) {
                    '_' => {
                        state = .int_literal_hex_no_underscore;
                    },
                    '.' => {
                        state = .num_dot_hex;
                        result.id = .float_literal;
                    },
                    'p', 'P' => {
                        state = .float_exponent_unsigned;
                        result.id = .float_literal;
                    },
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    else => {
                        if (isIdentifierChar(c)) {
                            result.id = .invalid;
                        }
                        break;
                    },
                },
                .num_dot_dec => switch (c) {
                    '.' => {
                        self.index -= 1;
                        state = .start;
                        break;
                    },
                    'e', 'E' => {
                        state = .float_exponent_unsigned;
                    },
                    '0'...'9' => {
                        result.id = .float_literal;
                        state = .float_fraction_dec;
                    },
                    else => {
                        if (isIdentifierChar(c)) {
                            result.id = .invalid;
                        }
                        break;
                    },
                },
                .num_dot_hex => switch (c) {
                    '.' => {
                        self.index -= 1;
                        state = .start;
                        break;
                    },
                    'p', 'P' => {
                        state = .float_exponent_unsigned;
                    },
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        result.id = .float_literal;
                        state = .float_fraction_hex;
                    },
                    else => {
                        if (isIdentifierChar(c)) {
                            result.id = .invalid;
                        }
                        break;
                    },
                },
                .float_fraction_dec_no_underscore => switch (c) {
                    '0'...'9' => {
                        state = .float_fraction_dec;
                    },
                    else => {
                        result.id = .invalid;
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
                            result.id = .invalid;
                        }
                        break;
                    },
                },
                .float_fraction_hex_no_underscore => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        state = .float_fraction_hex;
                    },
                    else => {
                        result.id = .invalid;
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
                            result.id = .invalid;
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
                        result.id = .invalid;
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
                            result.id = .invalid;
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
                    result.id = .line_comment;
                },
                .doc_comment, .doc_comment_start => {
                    result.id = .doc_comment;
                },
                .container_doc_comment => {
                    result.id = .container_doc_comment;
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
                    result.id = .invalid;
                },

                .equal => {
                    result.id = .equal;
                },
                .bang => {
                    result.id = .bang;
                },
                .minus => {
                    result.id = .minus;
                },
                .slash => {
                    result.id = .slash;
                },
                .zero => {
                    result.id = .integer_literal;
                },
                .ampersand => {
                    result.id = .ampersand;
                },
                .period => {
                    result.id = .period;
                },
                .period_2 => {
                    result.id = .ellipsis_2;
                },
                .pipe => {
                    result.id = .pipe;
                },
                .angle_bracket_angle_bracket_right => {
                    result.id = .angle_bracket_angle_bracket_right;
                },
                .angle_bracket_right => {
                    result.id = .angle_bracket_right;
                },
                .angle_bracket_angle_bracket_left => {
                    result.id = .angle_bracket_angle_bracket_left;
                },
                .angle_bracket_left => {
                    result.id = .angle_bracket_left;
                },
                .plus_percent => {
                    result.id = .plus_percent;
                },
                .plus => {
                    result.id = .plus;
                },
                .percent => {
                    result.id = .percent;
                },
                .caret => {
                    result.id = .caret;
                },
                .asterisk_percent => {
                    result.id = .asterisk_percent;
                },
                .asterisk => {
                    result.id = .asterisk;
                },
                .minus_percent => {
                    result.id = .minus_percent;
                },
            }
        }

        if (result.id == .eof) {
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
            .id = .invalid,
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
    testTokenize("test", &[_]Token.Id{.keyword_test});
}

test "tokenizer - unknown length pointer and then c pointer" {
    testTokenize(
        \\[*]u8
        \\[*c]u8
    , &[_]Token.Id{
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

test "tokenizer - char literal with hex escape" {
    testTokenize(
        \\'\x1b'
    , &[_]Token.Id{.char_literal});
    testTokenize(
        \\'\x1'
    , &[_]Token.Id{ .invalid, .invalid });
}

test "tokenizer - char literal with unicode escapes" {
    // Valid unicode escapes
    testTokenize(
        \\'\u{3}'
    , &[_]Token.Id{.char_literal});
    testTokenize(
        \\'\u{01}'
    , &[_]Token.Id{.char_literal});
    testTokenize(
        \\'\u{2a}'
    , &[_]Token.Id{.char_literal});
    testTokenize(
        \\'\u{3f9}'
    , &[_]Token.Id{.char_literal});
    testTokenize(
        \\'\u{6E09aBc1523}'
    , &[_]Token.Id{.char_literal});
    testTokenize(
        \\"\u{440}"
    , &[_]Token.Id{.string_literal});

    // invalid unicode escapes
    testTokenize(
        \\'\u'
    , &[_]Token.Id{.invalid});
    testTokenize(
        \\'\u{{'
    , &[_]Token.Id{ .invalid, .invalid });
    testTokenize(
        \\'\u{}'
    , &[_]Token.Id{ .invalid, .invalid });
    testTokenize(
        \\'\u{s}'
    , &[_]Token.Id{ .invalid, .invalid });
    testTokenize(
        \\'\u{2z}'
    , &[_]Token.Id{ .invalid, .invalid });
    testTokenize(
        \\'\u{4a'
    , &[_]Token.Id{.invalid});

    // Test old-style unicode literals
    testTokenize(
        \\'\u0333'
    , &[_]Token.Id{ .invalid, .invalid });
    testTokenize(
        \\'\U0333'
    , &[_]Token.Id{ .invalid, .integer_literal, .invalid });
}

test "tokenizer - char literal with unicode code point" {
    testTokenize(
        \\'💩'
    , &[_]Token.Id{.char_literal});
}

test "tokenizer - float literal e exponent" {
    testTokenize("a = 4.94065645841246544177e-324;\n", &[_]Token.Id{
        .identifier,
        .equal,
        .float_literal,
        .semicolon,
    });
}

test "tokenizer - float literal p exponent" {
    testTokenize("a = 0x1.a827999fcef32p+1022;\n", &[_]Token.Id{
        .identifier,
        .equal,
        .float_literal,
        .semicolon,
    });
}

test "tokenizer - chars" {
    testTokenize("'c'", &[_]Token.Id{.char_literal});
}

test "tokenizer - invalid token characters" {
    testTokenize("#", &[_]Token.Id{.invalid});
    testTokenize("`", &[_]Token.Id{.invalid});
    testTokenize("'c", &[_]Token.Id{.invalid});
    testTokenize("'", &[_]Token.Id{.invalid});
    testTokenize("''", &[_]Token.Id{ .invalid, .invalid });
}

test "tokenizer - invalid literal/comment characters" {
    testTokenize("\"\x00\"", &[_]Token.Id{
        .string_literal,
        .invalid,
    });
    testTokenize("//\x00", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
    testTokenize("//\x1f", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
    testTokenize("//\x7f", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
}

test "tokenizer - utf8" {
    testTokenize("//\xc2\x80", &[_]Token.Id{.line_comment});
    testTokenize("//\xf4\x8f\xbf\xbf", &[_]Token.Id{.line_comment});
}

test "tokenizer - invalid utf8" {
    testTokenize("//\x80", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
    testTokenize("//\xbf", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
    testTokenize("//\xf8", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
    testTokenize("//\xff", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
    testTokenize("//\xc2\xc0", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
    testTokenize("//\xe0", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
    testTokenize("//\xf0", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
    testTokenize("//\xf0\x90\x80\xc0", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
}

test "tokenizer - illegal unicode codepoints" {
    // unicode newline characters.U+0085, U+2028, U+2029
    testTokenize("//\xc2\x84", &[_]Token.Id{.line_comment});
    testTokenize("//\xc2\x85", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
    testTokenize("//\xc2\x86", &[_]Token.Id{.line_comment});
    testTokenize("//\xe2\x80\xa7", &[_]Token.Id{.line_comment});
    testTokenize("//\xe2\x80\xa8", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
    testTokenize("//\xe2\x80\xa9", &[_]Token.Id{
        .line_comment,
        .invalid,
    });
    testTokenize("//\xe2\x80\xaa", &[_]Token.Id{.line_comment});
}

test "tokenizer - string identifier and builtin fns" {
    testTokenize(
        \\const @"if" = @import("std");
    , &[_]Token.Id{
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
    testTokenize(
        \\\\foo	bar
    , &[_]Token.Id{
        .multiline_string_literal_line,
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
        .line_comment,
        .container_doc_comment,
        .doc_comment,
        .line_comment,
        .doc_comment,
        .doc_comment,
    });
}

test "tokenizer - pipe and then invalid" {
    testTokenize("||=", &[_]Token.Id{
        .pipe_pipe,
        .equal,
    });
}

test "tokenizer - line comment and doc comment" {
    testTokenize("//", &[_]Token.Id{.line_comment});
    testTokenize("// a / b", &[_]Token.Id{.line_comment});
    testTokenize("// /", &[_]Token.Id{.line_comment});
    testTokenize("/// a", &[_]Token.Id{.doc_comment});
    testTokenize("///", &[_]Token.Id{.doc_comment});
    testTokenize("////", &[_]Token.Id{.line_comment});
    testTokenize("//!", &[_]Token.Id{.container_doc_comment});
    testTokenize("//!!", &[_]Token.Id{.container_doc_comment});
}

test "tokenizer - line comment followed by identifier" {
    testTokenize(
        \\    Unexpected,
        \\    // another
        \\    Another,
    , &[_]Token.Id{
        .identifier,
        .comma,
        .line_comment,
        .identifier,
        .comma,
    });
}

test "tokenizer - UTF-8 BOM is recognized and skipped" {
    testTokenize("\xEF\xBB\xBFa;\n", &[_]Token.Id{
        .identifier,
        .semicolon,
    });
}

test "correctly parse pointer assignment" {
    testTokenize("b.*=3;\n", &[_]Token.Id{
        .identifier,
        .period_asterisk,
        .equal,
        .integer_literal,
        .semicolon,
    });
}

test "tokenizer - number literals decimal" {
    testTokenize("0", &[_]Token.Id{.integer_literal});
    testTokenize("1", &[_]Token.Id{.integer_literal});
    testTokenize("2", &[_]Token.Id{.integer_literal});
    testTokenize("3", &[_]Token.Id{.integer_literal});
    testTokenize("4", &[_]Token.Id{.integer_literal});
    testTokenize("5", &[_]Token.Id{.integer_literal});
    testTokenize("6", &[_]Token.Id{.integer_literal});
    testTokenize("7", &[_]Token.Id{.integer_literal});
    testTokenize("8", &[_]Token.Id{.integer_literal});
    testTokenize("9", &[_]Token.Id{.integer_literal});
    testTokenize("0a", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("9b", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1z", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1z_1", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("9z3", &[_]Token.Id{ .invalid, .identifier });

    testTokenize("0_0", &[_]Token.Id{.integer_literal});
    testTokenize("0001", &[_]Token.Id{.integer_literal});
    testTokenize("01234567890", &[_]Token.Id{.integer_literal});
    testTokenize("012_345_6789_0", &[_]Token.Id{.integer_literal});
    testTokenize("0_1_2_3_4_5_6_7_8_9_0", &[_]Token.Id{.integer_literal});

    testTokenize("00_", &[_]Token.Id{.invalid});
    testTokenize("0_0_", &[_]Token.Id{.invalid});
    testTokenize("0__0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0_0f", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0_0_f", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0_0_f_00", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1_,", &[_]Token.Id{ .invalid, .comma });

    testTokenize("1.", &[_]Token.Id{.float_literal});
    testTokenize("0.0", &[_]Token.Id{.float_literal});
    testTokenize("1.0", &[_]Token.Id{.float_literal});
    testTokenize("10.0", &[_]Token.Id{.float_literal});
    testTokenize("0e0", &[_]Token.Id{.float_literal});
    testTokenize("1e0", &[_]Token.Id{.float_literal});
    testTokenize("1e100", &[_]Token.Id{.float_literal});
    testTokenize("1.e100", &[_]Token.Id{.float_literal});
    testTokenize("1.0e100", &[_]Token.Id{.float_literal});
    testTokenize("1.0e+100", &[_]Token.Id{.float_literal});
    testTokenize("1.0e-100", &[_]Token.Id{.float_literal});
    testTokenize("1_0_0_0.0_0_0_0_0_1e1_0_0_0", &[_]Token.Id{.float_literal});
    testTokenize("1.+", &[_]Token.Id{ .float_literal, .plus });

    testTokenize("1e", &[_]Token.Id{.invalid});
    testTokenize("1.0e1f0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1.0p100", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1.0p-100", &[_]Token.Id{ .invalid, .identifier, .minus, .integer_literal });
    testTokenize("1.0p1f0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1.0_,", &[_]Token.Id{ .invalid, .comma });
    testTokenize("1_.0", &[_]Token.Id{ .invalid, .period, .integer_literal });
    testTokenize("1._", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1.a", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1.z", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1._0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1._+", &[_]Token.Id{ .invalid, .identifier, .plus });
    testTokenize("1._e", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1.0e", &[_]Token.Id{.invalid});
    testTokenize("1.0e,", &[_]Token.Id{ .invalid, .comma });
    testTokenize("1.0e_", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1.0e+_", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1.0e-_", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("1.0e0_+", &[_]Token.Id{ .invalid, .plus });
}

test "tokenizer - number literals binary" {
    testTokenize("0b0", &[_]Token.Id{.integer_literal});
    testTokenize("0b1", &[_]Token.Id{.integer_literal});
    testTokenize("0b2", &[_]Token.Id{ .invalid, .integer_literal });
    testTokenize("0b3", &[_]Token.Id{ .invalid, .integer_literal });
    testTokenize("0b4", &[_]Token.Id{ .invalid, .integer_literal });
    testTokenize("0b5", &[_]Token.Id{ .invalid, .integer_literal });
    testTokenize("0b6", &[_]Token.Id{ .invalid, .integer_literal });
    testTokenize("0b7", &[_]Token.Id{ .invalid, .integer_literal });
    testTokenize("0b8", &[_]Token.Id{ .invalid, .integer_literal });
    testTokenize("0b9", &[_]Token.Id{ .invalid, .integer_literal });
    testTokenize("0ba", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0bb", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0bc", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0bd", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0be", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0bf", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0bz", &[_]Token.Id{ .invalid, .identifier });

    testTokenize("0b0000_0000", &[_]Token.Id{.integer_literal});
    testTokenize("0b1111_1111", &[_]Token.Id{.integer_literal});
    testTokenize("0b10_10_10_10", &[_]Token.Id{.integer_literal});
    testTokenize("0b0_1_0_1_0_1_0_1", &[_]Token.Id{.integer_literal});
    testTokenize("0b1.", &[_]Token.Id{ .integer_literal, .period });
    testTokenize("0b1.0", &[_]Token.Id{ .integer_literal, .period, .integer_literal });

    testTokenize("0B0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0b_", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0b_0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0b1_", &[_]Token.Id{.invalid});
    testTokenize("0b0__1", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0b0_1_", &[_]Token.Id{.invalid});
    testTokenize("0b1e", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0b1p", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0b1e0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0b1p0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0b1_,", &[_]Token.Id{ .invalid, .comma });
}

test "tokenizer - number literals octal" {
    testTokenize("0o0", &[_]Token.Id{.integer_literal});
    testTokenize("0o1", &[_]Token.Id{.integer_literal});
    testTokenize("0o2", &[_]Token.Id{.integer_literal});
    testTokenize("0o3", &[_]Token.Id{.integer_literal});
    testTokenize("0o4", &[_]Token.Id{.integer_literal});
    testTokenize("0o5", &[_]Token.Id{.integer_literal});
    testTokenize("0o6", &[_]Token.Id{.integer_literal});
    testTokenize("0o7", &[_]Token.Id{.integer_literal});
    testTokenize("0o8", &[_]Token.Id{ .invalid, .integer_literal });
    testTokenize("0o9", &[_]Token.Id{ .invalid, .integer_literal });
    testTokenize("0oa", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0ob", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0oc", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0od", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0oe", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0of", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0oz", &[_]Token.Id{ .invalid, .identifier });

    testTokenize("0o01234567", &[_]Token.Id{.integer_literal});
    testTokenize("0o0123_4567", &[_]Token.Id{.integer_literal});
    testTokenize("0o01_23_45_67", &[_]Token.Id{.integer_literal});
    testTokenize("0o0_1_2_3_4_5_6_7", &[_]Token.Id{.integer_literal});
    testTokenize("0o7.", &[_]Token.Id{ .integer_literal, .period });
    testTokenize("0o7.0", &[_]Token.Id{ .integer_literal, .period, .integer_literal });

    testTokenize("0O0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0o_", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0o_0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0o1_", &[_]Token.Id{.invalid});
    testTokenize("0o0__1", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0o0_1_", &[_]Token.Id{.invalid});
    testTokenize("0o1e", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0o1p", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0o1e0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0o1p0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0o_,", &[_]Token.Id{ .invalid, .identifier, .comma });
}

test "tokenizer - number literals hexadeciaml" {
    testTokenize("0x0", &[_]Token.Id{.integer_literal});
    testTokenize("0x1", &[_]Token.Id{.integer_literal});
    testTokenize("0x2", &[_]Token.Id{.integer_literal});
    testTokenize("0x3", &[_]Token.Id{.integer_literal});
    testTokenize("0x4", &[_]Token.Id{.integer_literal});
    testTokenize("0x5", &[_]Token.Id{.integer_literal});
    testTokenize("0x6", &[_]Token.Id{.integer_literal});
    testTokenize("0x7", &[_]Token.Id{.integer_literal});
    testTokenize("0x8", &[_]Token.Id{.integer_literal});
    testTokenize("0x9", &[_]Token.Id{.integer_literal});
    testTokenize("0xa", &[_]Token.Id{.integer_literal});
    testTokenize("0xb", &[_]Token.Id{.integer_literal});
    testTokenize("0xc", &[_]Token.Id{.integer_literal});
    testTokenize("0xd", &[_]Token.Id{.integer_literal});
    testTokenize("0xe", &[_]Token.Id{.integer_literal});
    testTokenize("0xf", &[_]Token.Id{.integer_literal});
    testTokenize("0xA", &[_]Token.Id{.integer_literal});
    testTokenize("0xB", &[_]Token.Id{.integer_literal});
    testTokenize("0xC", &[_]Token.Id{.integer_literal});
    testTokenize("0xD", &[_]Token.Id{.integer_literal});
    testTokenize("0xE", &[_]Token.Id{.integer_literal});
    testTokenize("0xF", &[_]Token.Id{.integer_literal});
    testTokenize("0x0z", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0xz", &[_]Token.Id{ .invalid, .identifier });

    testTokenize("0x0123456789ABCDEF", &[_]Token.Id{.integer_literal});
    testTokenize("0x0123_4567_89AB_CDEF", &[_]Token.Id{.integer_literal});
    testTokenize("0x01_23_45_67_89AB_CDE_F", &[_]Token.Id{.integer_literal});
    testTokenize("0x0_1_2_3_4_5_6_7_8_9_A_B_C_D_E_F", &[_]Token.Id{.integer_literal});

    testTokenize("0X0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x_", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x_1", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x1_", &[_]Token.Id{.invalid});
    testTokenize("0x0__1", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x0_1_", &[_]Token.Id{.invalid});
    testTokenize("0x_,", &[_]Token.Id{ .invalid, .identifier, .comma });

    testTokenize("0x1.", &[_]Token.Id{.float_literal});
    testTokenize("0x1.0", &[_]Token.Id{.float_literal});
    testTokenize("0xF.", &[_]Token.Id{.float_literal});
    testTokenize("0xF.0", &[_]Token.Id{.float_literal});
    testTokenize("0xF.F", &[_]Token.Id{.float_literal});
    testTokenize("0xF.Fp0", &[_]Token.Id{.float_literal});
    testTokenize("0xF.FP0", &[_]Token.Id{.float_literal});
    testTokenize("0x1p0", &[_]Token.Id{.float_literal});
    testTokenize("0xfp0", &[_]Token.Id{.float_literal});
    testTokenize("0x1.+0xF.", &[_]Token.Id{ .float_literal, .plus, .float_literal });

    testTokenize("0x0123456.789ABCDEF", &[_]Token.Id{.float_literal});
    testTokenize("0x0_123_456.789_ABC_DEF", &[_]Token.Id{.float_literal});
    testTokenize("0x0_1_2_3_4_5_6.7_8_9_A_B_C_D_E_F", &[_]Token.Id{.float_literal});
    testTokenize("0x0p0", &[_]Token.Id{.float_literal});
    testTokenize("0x0.0p0", &[_]Token.Id{.float_literal});
    testTokenize("0xff.ffp10", &[_]Token.Id{.float_literal});
    testTokenize("0xff.ffP10", &[_]Token.Id{.float_literal});
    testTokenize("0xff.p10", &[_]Token.Id{.float_literal});
    testTokenize("0xffp10", &[_]Token.Id{.float_literal});
    testTokenize("0xff_ff.ff_ffp1_0_0_0", &[_]Token.Id{.float_literal});
    testTokenize("0xf_f_f_f.f_f_f_fp+1_000", &[_]Token.Id{.float_literal});
    testTokenize("0xf_f_f_f.f_f_f_fp-1_00_0", &[_]Token.Id{.float_literal});

    testTokenize("0x1e", &[_]Token.Id{.integer_literal});
    testTokenize("0x1e0", &[_]Token.Id{.integer_literal});
    testTokenize("0x1p", &[_]Token.Id{.invalid});
    testTokenize("0xfp0z1", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0xff.ffpff", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x0.p", &[_]Token.Id{.invalid});
    testTokenize("0x0.z", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x0._", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x0_.0", &[_]Token.Id{ .invalid, .period, .integer_literal });
    testTokenize("0x0_.0.0", &[_]Token.Id{ .invalid, .period, .float_literal });
    testTokenize("0x0._0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x0.0_", &[_]Token.Id{.invalid});
    testTokenize("0x0_p0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x0_.p0", &[_]Token.Id{ .invalid, .period, .identifier });
    testTokenize("0x0._p0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x0.0_p0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x0._0p0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x0.0p_0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x0.0p+_0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x0.0p-_0", &[_]Token.Id{ .invalid, .identifier });
    testTokenize("0x0.0p0_", &[_]Token.Id{ .invalid, .eof });
}

fn testTokenize(source: []const u8, expected_tokens: []const Token.Id) void {
    var tokenizer = Tokenizer.init(source);
    for (expected_tokens) |expected_token_id| {
        const token = tokenizer.next();
        if (token.id != expected_token_id) {
            std.debug.panic("expected {}, found {}\n", .{ @tagName(expected_token_id), @tagName(token.id) });
        }
    }
    const last_token = tokenizer.next();
    std.testing.expect(last_token.id == .eof);
}
