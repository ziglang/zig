const std = @import("../std.zig");

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "addrspace", .keyword_addrspace },
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
        .{ "fn", .keyword_fn },
        .{ "for", .keyword_for },
        .{ "if", .keyword_if },
        .{ "inline", .keyword_inline },
        .{ "noalias", .keyword_noalias },
        .{ "noinline", .keyword_noinline },
        .{ "nosuspend", .keyword_nosuspend },
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
        .{ "try", .keyword_try },
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
        plus_pipe,
        plus_pipe_equal,
        minus,
        minus_equal,
        minus_percent,
        minus_percent_equal,
        minus_pipe,
        minus_pipe_equal,
        asterisk,
        asterisk_equal,
        asterisk_asterisk,
        asterisk_percent,
        asterisk_percent_equal,
        asterisk_pipe,
        asterisk_pipe_equal,
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
        angle_bracket_angle_bracket_left_pipe,
        angle_bracket_angle_bracket_left_pipe_equal,
        angle_bracket_right,
        angle_bracket_right_equal,
        angle_bracket_angle_bracket_right,
        angle_bracket_angle_bracket_right_equal,
        tilde,
        number_literal,
        doc_comment,
        container_doc_comment,
        keyword_addrspace,
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
        keyword_fn,
        keyword_for,
        keyword_if,
        keyword_inline,
        keyword_noalias,
        keyword_noinline,
        keyword_nosuspend,
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
        keyword_try,
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
                .number_literal,
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
                .plus_pipe => "+|",
                .plus_pipe_equal => "+|=",
                .minus => "-",
                .minus_equal => "-=",
                .minus_percent => "-%",
                .minus_percent_equal => "-%=",
                .minus_pipe => "-|",
                .minus_pipe_equal => "-|=",
                .asterisk => "*",
                .asterisk_equal => "*=",
                .asterisk_asterisk => "**",
                .asterisk_percent => "*%",
                .asterisk_percent_equal => "*%=",
                .asterisk_pipe => "*|",
                .asterisk_pipe_equal => "*|=",
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
                .angle_bracket_angle_bracket_left_pipe => "<<|",
                .angle_bracket_angle_bracket_left_pipe_equal => "<<|=",
                .angle_bracket_right => ">",
                .angle_bracket_right_equal => ">=",
                .angle_bracket_angle_bracket_right => ">>",
                .angle_bracket_angle_bracket_right_equal => ">>=",
                .tilde => "~",
                .keyword_addrspace => "addrspace",
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
                .keyword_fn => "fn",
                .keyword_for => "for",
                .keyword_if => "if",
                .keyword_inline => "inline",
                .keyword_noalias => "noalias",
                .keyword_noinline => "noinline",
                .keyword_nosuspend => "nosuspend",
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
                .keyword_try => "try",
                .keyword_union => "union",
                .keyword_unreachable => "unreachable",
                .keyword_usingnamespace => "usingnamespace",
                .keyword_var => "var",
                .keyword_volatile => "volatile",
                .keyword_while => "while",
            };
        }

        pub fn symbol(tag: Tag) []const u8 {
            return tag.lexeme() orelse switch (tag) {
                .invalid => "invalid token",
                .identifier => "an identifier",
                .string_literal, .multiline_string_literal_line => "a string literal",
                .char_literal => "a character literal",
                .eof => "EOF",
                .builtin => "a builtin function",
                .number_literal => "a number literal",
                .doc_comment, .container_doc_comment => "a document comment",
                else => unreachable,
            };
        }
    };
};

pub const Tokenizer = struct {
    buffer: [:0]const u8,
    index: usize,

    /// For debugging purposes.
    pub fn dump(self: *Tokenizer, token: *const Token) void {
        std.debug.print("{s} \"{s}\"\n", .{ @tagName(token.tag), self.buffer[token.loc.start..token.loc.end] });
    }

    pub fn init(buffer: [:0]const u8) Tokenizer {
        // Skip the UTF-8 BOM if present.
        return .{
            .buffer = buffer,
            .index = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0,
        };
    }

    const State = enum {
        start,
        expect_newline,
        identifier,
        builtin,
        string_literal,
        string_literal_backslash,
        multiline_string_literal_line,
        char_literal,
        char_literal_backslash,
        backslash,
        equal,
        bang,
        pipe,
        minus,
        minus_percent,
        minus_pipe,
        asterisk,
        asterisk_percent,
        asterisk_pipe,
        slash,
        line_comment_start,
        line_comment,
        doc_comment_start,
        doc_comment,
        int,
        int_exponent,
        int_period,
        float,
        float_exponent,
        ampersand,
        caret,
        percent,
        plus,
        plus_percent,
        plus_pipe,
        angle_bracket_left,
        angle_bracket_angle_bracket_left,
        angle_bracket_angle_bracket_left_pipe,
        angle_bracket_right,
        angle_bracket_angle_bracket_right,
        period,
        period_2,
        period_asterisk,
        saw_at_sign,
        invalid,
    };

    /// After this returns invalid, it will reset on the next newline, returning tokens starting from there.
    /// An eof token will always be returned at the end.
    pub fn next(self: *Tokenizer) Token {
        var result: Token = .{
            .tag = undefined,
            .loc = .{
                .start = self.index,
                .end = undefined,
            },
        };
        state: switch (State.start) {
            .start => switch (self.buffer[self.index]) {
                0 => {
                    if (self.index == self.buffer.len) {
                        return .{
                            .tag = .eof,
                            .loc = .{
                                .start = self.index,
                                .end = self.index,
                            },
                        };
                    } else {
                        continue :state .invalid;
                    }
                },
                ' ', '\n', '\t', '\r' => {
                    self.index += 1;
                    result.loc.start = self.index;
                    continue :state .start;
                },
                '"' => {
                    result.tag = .string_literal;
                    continue :state .string_literal;
                },
                '\'' => {
                    result.tag = .char_literal;
                    continue :state .char_literal;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    result.tag = .identifier;
                    continue :state .identifier;
                },
                '@' => continue :state .saw_at_sign,
                '=' => continue :state .equal,
                '!' => continue :state .bang,
                '|' => continue :state .pipe,
                '(' => {
                    result.tag = .l_paren;
                    self.index += 1;
                },
                ')' => {
                    result.tag = .r_paren;
                    self.index += 1;
                },
                '[' => {
                    result.tag = .l_bracket;
                    self.index += 1;
                },
                ']' => {
                    result.tag = .r_bracket;
                    self.index += 1;
                },
                ';' => {
                    result.tag = .semicolon;
                    self.index += 1;
                },
                ',' => {
                    result.tag = .comma;
                    self.index += 1;
                },
                '?' => {
                    result.tag = .question_mark;
                    self.index += 1;
                },
                ':' => {
                    result.tag = .colon;
                    self.index += 1;
                },
                '%' => continue :state .percent,
                '*' => continue :state .asterisk,
                '+' => continue :state .plus,
                '<' => continue :state .angle_bracket_left,
                '>' => continue :state .angle_bracket_right,
                '^' => continue :state .caret,
                '\\' => {
                    result.tag = .multiline_string_literal_line;
                    continue :state .backslash;
                },
                '{' => {
                    result.tag = .l_brace;
                    self.index += 1;
                },
                '}' => {
                    result.tag = .r_brace;
                    self.index += 1;
                },
                '~' => {
                    result.tag = .tilde;
                    self.index += 1;
                },
                '.' => continue :state .period,
                '-' => continue :state .minus,
                '/' => continue :state .slash,
                '&' => continue :state .ampersand,
                '0'...'9' => {
                    result.tag = .number_literal;
                    self.index += 1;
                    continue :state .int;
                },
                else => continue :state .invalid,
            },

            .expect_newline => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => {
                        if (self.index == self.buffer.len) {
                            result.tag = .invalid;
                        } else {
                            continue :state .invalid;
                        }
                    },
                    '\n' => {
                        self.index += 1;
                        result.loc.start = self.index;
                        continue :state .start;
                    },
                    else => continue :state .invalid,
                }
            },

            .invalid => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => if (self.index == self.buffer.len) {
                        result.tag = .invalid;
                    },
                    '\n' => result.tag = .invalid,
                    else => continue :state .invalid,
                }
            },

            .saw_at_sign => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0, '\n' => result.tag = .invalid,
                    '"' => {
                        result.tag = .identifier;
                        continue :state .string_literal;
                    },
                    'a'...'z', 'A'...'Z', '_' => {
                        result.tag = .builtin;
                        continue :state .builtin;
                    },
                    else => continue :state .invalid,
                }
            },

            .ampersand => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .ampersand_equal;
                        self.index += 1;
                    },
                    else => result.tag = .ampersand,
                }
            },

            .asterisk => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .asterisk_equal;
                        self.index += 1;
                    },
                    '*' => {
                        result.tag = .asterisk_asterisk;
                        self.index += 1;
                    },
                    '%' => continue :state .asterisk_percent,
                    '|' => continue :state .asterisk_pipe,
                    else => result.tag = .asterisk,
                }
            },

            .asterisk_percent => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .asterisk_percent_equal;
                        self.index += 1;
                    },
                    else => result.tag = .asterisk_percent,
                }
            },

            .asterisk_pipe => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .asterisk_pipe_equal;
                        self.index += 1;
                    },
                    else => result.tag = .asterisk_pipe,
                }
            },

            .percent => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .percent_equal;
                        self.index += 1;
                    },
                    else => result.tag = .percent,
                }
            },

            .plus => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .plus_equal;
                        self.index += 1;
                    },
                    '+' => {
                        result.tag = .plus_plus;
                        self.index += 1;
                    },
                    '%' => continue :state .plus_percent,
                    '|' => continue :state .plus_pipe,
                    else => result.tag = .plus,
                }
            },

            .plus_percent => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .plus_percent_equal;
                        self.index += 1;
                    },
                    else => result.tag = .plus_percent,
                }
            },

            .plus_pipe => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .plus_pipe_equal;
                        self.index += 1;
                    },
                    else => result.tag = .plus_pipe,
                }
            },

            .caret => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .caret_equal;
                        self.index += 1;
                    },
                    else => result.tag = .caret,
                }
            },

            .identifier => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => continue :state .identifier,
                    else => {
                        const ident = self.buffer[result.loc.start..self.index];
                        if (Token.getKeyword(ident)) |tag| {
                            result.tag = tag;
                        }
                    },
                }
            },
            .builtin => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => continue :state .builtin,
                    else => {},
                }
            },
            .backslash => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => result.tag = .invalid,
                    '\\' => continue :state .multiline_string_literal_line,
                    '\n' => result.tag = .invalid,
                    else => continue :state .invalid,
                }
            },
            .string_literal => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => {
                        if (self.index != self.buffer.len) {
                            continue :state .invalid;
                        } else {
                            result.tag = .invalid;
                        }
                    },
                    '\n' => result.tag = .invalid,
                    '\\' => continue :state .string_literal_backslash,
                    '"' => self.index += 1,
                    0x01...0x09, 0x0b...0x1f, 0x7f => {
                        continue :state .invalid;
                    },
                    else => continue :state .string_literal,
                }
            },

            .string_literal_backslash => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0, '\n' => result.tag = .invalid,
                    else => continue :state .string_literal,
                }
            },

            .char_literal => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => {
                        if (self.index != self.buffer.len) {
                            continue :state .invalid;
                        } else {
                            result.tag = .invalid;
                        }
                    },
                    '\n' => result.tag = .invalid,
                    '\\' => continue :state .char_literal_backslash,
                    '\'' => self.index += 1,
                    0x01...0x09, 0x0b...0x1f, 0x7f => {
                        continue :state .invalid;
                    },
                    else => continue :state .char_literal,
                }
            },

            .char_literal_backslash => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => {
                        if (self.index != self.buffer.len) {
                            continue :state .invalid;
                        } else {
                            result.tag = .invalid;
                        }
                    },
                    '\n' => result.tag = .invalid,
                    0x01...0x09, 0x0b...0x1f, 0x7f => {
                        continue :state .invalid;
                    },
                    else => continue :state .char_literal,
                }
            },

            .multiline_string_literal_line => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => if (self.index != self.buffer.len) {
                        continue :state .invalid;
                    },
                    '\n' => {},
                    '\r' => if (self.buffer[self.index + 1] != '\n') {
                        continue :state .invalid;
                    },
                    0x01...0x09, 0x0b...0x0c, 0x0e...0x1f, 0x7f => continue :state .invalid,
                    else => continue :state .multiline_string_literal_line,
                }
            },

            .bang => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .bang_equal;
                        self.index += 1;
                    },
                    else => result.tag = .bang,
                }
            },

            .pipe => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .pipe_equal;
                        self.index += 1;
                    },
                    '|' => {
                        result.tag = .pipe_pipe;
                        self.index += 1;
                    },
                    else => result.tag = .pipe,
                }
            },

            .equal => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .equal_equal;
                        self.index += 1;
                    },
                    '>' => {
                        result.tag = .equal_angle_bracket_right;
                        self.index += 1;
                    },
                    else => result.tag = .equal,
                }
            },

            .minus => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '>' => {
                        result.tag = .arrow;
                        self.index += 1;
                    },
                    '=' => {
                        result.tag = .minus_equal;
                        self.index += 1;
                    },
                    '%' => continue :state .minus_percent,
                    '|' => continue :state .minus_pipe,
                    else => result.tag = .minus,
                }
            },

            .minus_percent => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .minus_percent_equal;
                        self.index += 1;
                    },
                    else => result.tag = .minus_percent,
                }
            },
            .minus_pipe => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .minus_pipe_equal;
                        self.index += 1;
                    },
                    else => result.tag = .minus_pipe,
                }
            },

            .angle_bracket_left => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '<' => continue :state .angle_bracket_angle_bracket_left,
                    '=' => {
                        result.tag = .angle_bracket_left_equal;
                        self.index += 1;
                    },
                    else => result.tag = .angle_bracket_left,
                }
            },

            .angle_bracket_angle_bracket_left => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .angle_bracket_angle_bracket_left_equal;
                        self.index += 1;
                    },
                    '|' => continue :state .angle_bracket_angle_bracket_left_pipe,
                    else => result.tag = .angle_bracket_angle_bracket_left,
                }
            },

            .angle_bracket_angle_bracket_left_pipe => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .angle_bracket_angle_bracket_left_pipe_equal;
                        self.index += 1;
                    },
                    else => result.tag = .angle_bracket_angle_bracket_left_pipe,
                }
            },

            .angle_bracket_right => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '>' => continue :state .angle_bracket_angle_bracket_right,
                    '=' => {
                        result.tag = .angle_bracket_right_equal;
                        self.index += 1;
                    },
                    else => result.tag = .angle_bracket_right,
                }
            },

            .angle_bracket_angle_bracket_right => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '=' => {
                        result.tag = .angle_bracket_angle_bracket_right_equal;
                        self.index += 1;
                    },
                    else => result.tag = .angle_bracket_angle_bracket_right,
                }
            },

            .period => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '.' => continue :state .period_2,
                    '*' => continue :state .period_asterisk,
                    else => result.tag = .period,
                }
            },

            .period_2 => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '.' => {
                        result.tag = .ellipsis3;
                        self.index += 1;
                    },
                    else => result.tag = .ellipsis2,
                }
            },

            .period_asterisk => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '*' => result.tag = .invalid_periodasterisks,
                    else => result.tag = .period_asterisk,
                }
            },

            .slash => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '/' => continue :state .line_comment_start,
                    '=' => {
                        result.tag = .slash_equal;
                        self.index += 1;
                    },
                    else => result.tag = .slash,
                }
            },
            .line_comment_start => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => {
                        if (self.index != self.buffer.len) {
                            continue :state .invalid;
                        } else return .{
                            .tag = .eof,
                            .loc = .{
                                .start = self.index,
                                .end = self.index,
                            },
                        };
                    },
                    '!' => {
                        result.tag = .container_doc_comment;
                        continue :state .doc_comment;
                    },
                    '\n' => {
                        self.index += 1;
                        result.loc.start = self.index;
                        continue :state .start;
                    },
                    '/' => continue :state .doc_comment_start,
                    '\r' => continue :state .expect_newline,
                    0x01...0x09, 0x0b...0x0c, 0x0e...0x1f, 0x7f => {
                        continue :state .invalid;
                    },
                    else => continue :state .line_comment,
                }
            },
            .doc_comment_start => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0, '\n' => result.tag = .doc_comment,
                    '\r' => {
                        if (self.buffer[self.index + 1] == '\n') {
                            result.tag = .doc_comment;
                        } else {
                            continue :state .invalid;
                        }
                    },
                    '/' => continue :state .line_comment,
                    0x01...0x09, 0x0b...0x0c, 0x0e...0x1f, 0x7f => {
                        continue :state .invalid;
                    },
                    else => {
                        result.tag = .doc_comment;
                        continue :state .doc_comment;
                    },
                }
            },
            .line_comment => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => {
                        if (self.index != self.buffer.len) {
                            continue :state .invalid;
                        } else return .{
                            .tag = .eof,
                            .loc = .{
                                .start = self.index,
                                .end = self.index,
                            },
                        };
                    },
                    '\n' => {
                        self.index += 1;
                        result.loc.start = self.index;
                        continue :state .start;
                    },
                    '\r' => continue :state .expect_newline,
                    0x01...0x09, 0x0b...0x0c, 0x0e...0x1f, 0x7f => {
                        continue :state .invalid;
                    },
                    else => continue :state .line_comment,
                }
            },
            .doc_comment => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0, '\n' => {},
                    '\r' => if (self.buffer[self.index + 1] != '\n') {
                        continue :state .invalid;
                    },
                    0x01...0x09, 0x0b...0x0c, 0x0e...0x1f, 0x7f => {
                        continue :state .invalid;
                    },
                    else => continue :state .doc_comment,
                }
            },
            .int => switch (self.buffer[self.index]) {
                '.' => continue :state .int_period,
                '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                    self.index += 1;
                    continue :state .int;
                },
                'e', 'E', 'p', 'P' => {
                    continue :state .int_exponent;
                },
                else => {},
            },
            .int_exponent => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '-', '+' => {
                        self.index += 1;
                        continue :state .float;
                    },
                    else => continue :state .int,
                }
            },
            .int_period => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                        self.index += 1;
                        continue :state .float;
                    },
                    'e', 'E', 'p', 'P' => {
                        continue :state .float_exponent;
                    },
                    else => self.index -= 1,
                }
            },
            .float => switch (self.buffer[self.index]) {
                '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                    self.index += 1;
                    continue :state .float;
                },
                'e', 'E', 'p', 'P' => {
                    continue :state .float_exponent;
                },
                else => {},
            },
            .float_exponent => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    '-', '+' => {
                        self.index += 1;
                        continue :state .float;
                    },
                    else => continue :state .float,
                }
            },
        }

        result.loc.end = self.index;
        return result;
    }
};

test "keywords" {
    try testTokenize("test const else", &.{ .keyword_test, .keyword_const, .keyword_else });
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

test "unknown length pointer and then c pointer" {
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

test "code point literal with hex escape" {
    try testTokenize(
        \\'\x1b'
    , &.{.char_literal});
    try testTokenize(
        \\'\x1'
    , &.{.char_literal});
}

test "newline in char literal" {
    try testTokenize(
        \\'
        \\'
    , &.{ .invalid, .invalid });
}

test "newline in string literal" {
    try testTokenize(
        \\"
        \\"
    , &.{ .invalid, .invalid });
}

test "code point literal with unicode escapes" {
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
    , &.{.char_literal});
    try testTokenize(
        \\'\u{{'
    , &.{.char_literal});
    try testTokenize(
        \\'\u{}'
    , &.{.char_literal});
    try testTokenize(
        \\'\u{s}'
    , &.{.char_literal});
    try testTokenize(
        \\'\u{2z}'
    , &.{.char_literal});
    try testTokenize(
        \\'\u{4a'
    , &.{.char_literal});

    // Test old-style unicode literals
    try testTokenize(
        \\'\u0333'
    , &.{.char_literal});
    try testTokenize(
        \\'\U0333'
    , &.{.char_literal});
}

test "code point literal with unicode code point" {
    try testTokenize(
        \\'💩'
    , &.{.char_literal});
}

test "float literal e exponent" {
    try testTokenize("a = 4.94065645841246544177e-324;\n", &.{
        .identifier,
        .equal,
        .number_literal,
        .semicolon,
    });
}

test "float literal p exponent" {
    try testTokenize("a = 0x1.a827999fcef32p+1022;\n", &.{
        .identifier,
        .equal,
        .number_literal,
        .semicolon,
    });
}

test "chars" {
    try testTokenize("'c'", &.{.char_literal});
}

test "invalid token characters" {
    try testTokenize("#", &.{.invalid});
    try testTokenize("`", &.{.invalid});
    try testTokenize("'c", &.{.invalid});
    try testTokenize("'", &.{.invalid});
    try testTokenize("''", &.{.char_literal});
    try testTokenize("'\n'", &.{ .invalid, .invalid });
}

test "invalid literal/comment characters" {
    try testTokenize("\"\x00\"", &.{.invalid});
    try testTokenize("//\x00", &.{.invalid});
    try testTokenize("//\x1f", &.{.invalid});
    try testTokenize("//\x7f", &.{.invalid});
}

test "utf8" {
    try testTokenize("//\xc2\x80", &.{});
    try testTokenize("//\xf4\x8f\xbf\xbf", &.{});
}

test "invalid utf8" {
    try testTokenize("//\x80", &.{});
    try testTokenize("//\xbf", &.{});
    try testTokenize("//\xf8", &.{});
    try testTokenize("//\xff", &.{});
    try testTokenize("//\xc2\xc0", &.{});
    try testTokenize("//\xe0", &.{});
    try testTokenize("//\xf0", &.{});
    try testTokenize("//\xf0\x90\x80\xc0", &.{});
}

test "illegal unicode codepoints" {
    // unicode newline characters.U+0085, U+2028, U+2029
    try testTokenize("//\xc2\x84", &.{});
    try testTokenize("//\xc2\x85", &.{});
    try testTokenize("//\xc2\x86", &.{});
    try testTokenize("//\xe2\x80\xa7", &.{});
    try testTokenize("//\xe2\x80\xa8", &.{});
    try testTokenize("//\xe2\x80\xa9", &.{});
    try testTokenize("//\xe2\x80\xaa", &.{});
}

test "string identifier and builtin fns" {
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

test "pipe and then invalid" {
    try testTokenize("||=", &.{
        .pipe_pipe,
        .equal,
    });
}

test "line comment and doc comment" {
    try testTokenize("//", &.{});
    try testTokenize("// a / b", &.{});
    try testTokenize("// /", &.{});
    try testTokenize("/// a", &.{.doc_comment});
    try testTokenize("///", &.{.doc_comment});
    try testTokenize("////", &.{});
    try testTokenize("//!", &.{.container_doc_comment});
    try testTokenize("//!!", &.{.container_doc_comment});
}

test "line comment followed by identifier" {
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

test "UTF-8 BOM is recognized and skipped" {
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
        .number_literal,
        .semicolon,
    });
}

test "correctly parse pointer dereference followed by asterisk" {
    try testTokenize("\"b\".* ** 10", &.{
        .string_literal,
        .period_asterisk,
        .asterisk_asterisk,
        .number_literal,
    });

    try testTokenize("(\"b\".*)** 10", &.{
        .l_paren,
        .string_literal,
        .period_asterisk,
        .r_paren,
        .asterisk_asterisk,
        .number_literal,
    });

    try testTokenize("\"b\".*** 10", &.{
        .string_literal,
        .invalid_periodasterisks,
        .asterisk_asterisk,
        .number_literal,
    });
}

test "range literals" {
    try testTokenize("0...9", &.{ .number_literal, .ellipsis3, .number_literal });
    try testTokenize("'0'...'9'", &.{ .char_literal, .ellipsis3, .char_literal });
    try testTokenize("0x00...0x09", &.{ .number_literal, .ellipsis3, .number_literal });
    try testTokenize("0b00...0b11", &.{ .number_literal, .ellipsis3, .number_literal });
    try testTokenize("0o00...0o11", &.{ .number_literal, .ellipsis3, .number_literal });
}

test "number literals decimal" {
    try testTokenize("0", &.{.number_literal});
    try testTokenize("1", &.{.number_literal});
    try testTokenize("2", &.{.number_literal});
    try testTokenize("3", &.{.number_literal});
    try testTokenize("4", &.{.number_literal});
    try testTokenize("5", &.{.number_literal});
    try testTokenize("6", &.{.number_literal});
    try testTokenize("7", &.{.number_literal});
    try testTokenize("8", &.{.number_literal});
    try testTokenize("9", &.{.number_literal});
    try testTokenize("1..", &.{ .number_literal, .ellipsis2 });
    try testTokenize("0a", &.{.number_literal});
    try testTokenize("9b", &.{.number_literal});
    try testTokenize("1z", &.{.number_literal});
    try testTokenize("1z_1", &.{.number_literal});
    try testTokenize("9z3", &.{.number_literal});

    try testTokenize("0_0", &.{.number_literal});
    try testTokenize("0001", &.{.number_literal});
    try testTokenize("01234567890", &.{.number_literal});
    try testTokenize("012_345_6789_0", &.{.number_literal});
    try testTokenize("0_1_2_3_4_5_6_7_8_9_0", &.{.number_literal});

    try testTokenize("00_", &.{.number_literal});
    try testTokenize("0_0_", &.{.number_literal});
    try testTokenize("0__0", &.{.number_literal});
    try testTokenize("0_0f", &.{.number_literal});
    try testTokenize("0_0_f", &.{.number_literal});
    try testTokenize("0_0_f_00", &.{.number_literal});
    try testTokenize("1_,", &.{ .number_literal, .comma });

    try testTokenize("0.0", &.{.number_literal});
    try testTokenize("1.0", &.{.number_literal});
    try testTokenize("10.0", &.{.number_literal});
    try testTokenize("0e0", &.{.number_literal});
    try testTokenize("1e0", &.{.number_literal});
    try testTokenize("1e100", &.{.number_literal});
    try testTokenize("1.0e100", &.{.number_literal});
    try testTokenize("1.0e+100", &.{.number_literal});
    try testTokenize("1.0e-100", &.{.number_literal});
    try testTokenize("1_0_0_0.0_0_0_0_0_1e1_0_0_0", &.{.number_literal});

    try testTokenize("1.", &.{ .number_literal, .period });
    try testTokenize("1e", &.{.number_literal});
    try testTokenize("1.e100", &.{.number_literal});
    try testTokenize("1.0e1f0", &.{.number_literal});
    try testTokenize("1.0p100", &.{.number_literal});
    try testTokenize("1.0p-100", &.{.number_literal});
    try testTokenize("1.0p1f0", &.{.number_literal});
    try testTokenize("1.0_,", &.{ .number_literal, .comma });
    try testTokenize("1_.0", &.{.number_literal});
    try testTokenize("1._", &.{.number_literal});
    try testTokenize("1.a", &.{.number_literal});
    try testTokenize("1.z", &.{.number_literal});
    try testTokenize("1._0", &.{.number_literal});
    try testTokenize("1.+", &.{ .number_literal, .period, .plus });
    try testTokenize("1._+", &.{ .number_literal, .plus });
    try testTokenize("1._e", &.{.number_literal});
    try testTokenize("1.0e", &.{.number_literal});
    try testTokenize("1.0e,", &.{ .number_literal, .comma });
    try testTokenize("1.0e_", &.{.number_literal});
    try testTokenize("1.0e+_", &.{.number_literal});
    try testTokenize("1.0e-_", &.{.number_literal});
    try testTokenize("1.0e0_+", &.{ .number_literal, .plus });
}

test "number literals binary" {
    try testTokenize("0b0", &.{.number_literal});
    try testTokenize("0b1", &.{.number_literal});
    try testTokenize("0b2", &.{.number_literal});
    try testTokenize("0b3", &.{.number_literal});
    try testTokenize("0b4", &.{.number_literal});
    try testTokenize("0b5", &.{.number_literal});
    try testTokenize("0b6", &.{.number_literal});
    try testTokenize("0b7", &.{.number_literal});
    try testTokenize("0b8", &.{.number_literal});
    try testTokenize("0b9", &.{.number_literal});
    try testTokenize("0ba", &.{.number_literal});
    try testTokenize("0bb", &.{.number_literal});
    try testTokenize("0bc", &.{.number_literal});
    try testTokenize("0bd", &.{.number_literal});
    try testTokenize("0be", &.{.number_literal});
    try testTokenize("0bf", &.{.number_literal});
    try testTokenize("0bz", &.{.number_literal});

    try testTokenize("0b0000_0000", &.{.number_literal});
    try testTokenize("0b1111_1111", &.{.number_literal});
    try testTokenize("0b10_10_10_10", &.{.number_literal});
    try testTokenize("0b0_1_0_1_0_1_0_1", &.{.number_literal});
    try testTokenize("0b1.", &.{ .number_literal, .period });
    try testTokenize("0b1.0", &.{.number_literal});

    try testTokenize("0B0", &.{.number_literal});
    try testTokenize("0b_", &.{.number_literal});
    try testTokenize("0b_0", &.{.number_literal});
    try testTokenize("0b1_", &.{.number_literal});
    try testTokenize("0b0__1", &.{.number_literal});
    try testTokenize("0b0_1_", &.{.number_literal});
    try testTokenize("0b1e", &.{.number_literal});
    try testTokenize("0b1p", &.{.number_literal});
    try testTokenize("0b1e0", &.{.number_literal});
    try testTokenize("0b1p0", &.{.number_literal});
    try testTokenize("0b1_,", &.{ .number_literal, .comma });
}

test "number literals octal" {
    try testTokenize("0o0", &.{.number_literal});
    try testTokenize("0o1", &.{.number_literal});
    try testTokenize("0o2", &.{.number_literal});
    try testTokenize("0o3", &.{.number_literal});
    try testTokenize("0o4", &.{.number_literal});
    try testTokenize("0o5", &.{.number_literal});
    try testTokenize("0o6", &.{.number_literal});
    try testTokenize("0o7", &.{.number_literal});
    try testTokenize("0o8", &.{.number_literal});
    try testTokenize("0o9", &.{.number_literal});
    try testTokenize("0oa", &.{.number_literal});
    try testTokenize("0ob", &.{.number_literal});
    try testTokenize("0oc", &.{.number_literal});
    try testTokenize("0od", &.{.number_literal});
    try testTokenize("0oe", &.{.number_literal});
    try testTokenize("0of", &.{.number_literal});
    try testTokenize("0oz", &.{.number_literal});

    try testTokenize("0o01234567", &.{.number_literal});
    try testTokenize("0o0123_4567", &.{.number_literal});
    try testTokenize("0o01_23_45_67", &.{.number_literal});
    try testTokenize("0o0_1_2_3_4_5_6_7", &.{.number_literal});
    try testTokenize("0o7.", &.{ .number_literal, .period });
    try testTokenize("0o7.0", &.{.number_literal});

    try testTokenize("0O0", &.{.number_literal});
    try testTokenize("0o_", &.{.number_literal});
    try testTokenize("0o_0", &.{.number_literal});
    try testTokenize("0o1_", &.{.number_literal});
    try testTokenize("0o0__1", &.{.number_literal});
    try testTokenize("0o0_1_", &.{.number_literal});
    try testTokenize("0o1e", &.{.number_literal});
    try testTokenize("0o1p", &.{.number_literal});
    try testTokenize("0o1e0", &.{.number_literal});
    try testTokenize("0o1p0", &.{.number_literal});
    try testTokenize("0o_,", &.{ .number_literal, .comma });
}

test "number literals hexadecimal" {
    try testTokenize("0x0", &.{.number_literal});
    try testTokenize("0x1", &.{.number_literal});
    try testTokenize("0x2", &.{.number_literal});
    try testTokenize("0x3", &.{.number_literal});
    try testTokenize("0x4", &.{.number_literal});
    try testTokenize("0x5", &.{.number_literal});
    try testTokenize("0x6", &.{.number_literal});
    try testTokenize("0x7", &.{.number_literal});
    try testTokenize("0x8", &.{.number_literal});
    try testTokenize("0x9", &.{.number_literal});
    try testTokenize("0xa", &.{.number_literal});
    try testTokenize("0xb", &.{.number_literal});
    try testTokenize("0xc", &.{.number_literal});
    try testTokenize("0xd", &.{.number_literal});
    try testTokenize("0xe", &.{.number_literal});
    try testTokenize("0xf", &.{.number_literal});
    try testTokenize("0xA", &.{.number_literal});
    try testTokenize("0xB", &.{.number_literal});
    try testTokenize("0xC", &.{.number_literal});
    try testTokenize("0xD", &.{.number_literal});
    try testTokenize("0xE", &.{.number_literal});
    try testTokenize("0xF", &.{.number_literal});
    try testTokenize("0x0z", &.{.number_literal});
    try testTokenize("0xz", &.{.number_literal});

    try testTokenize("0x0123456789ABCDEF", &.{.number_literal});
    try testTokenize("0x0123_4567_89AB_CDEF", &.{.number_literal});
    try testTokenize("0x01_23_45_67_89AB_CDE_F", &.{.number_literal});
    try testTokenize("0x0_1_2_3_4_5_6_7_8_9_A_B_C_D_E_F", &.{.number_literal});

    try testTokenize("0X0", &.{.number_literal});
    try testTokenize("0x_", &.{.number_literal});
    try testTokenize("0x_1", &.{.number_literal});
    try testTokenize("0x1_", &.{.number_literal});
    try testTokenize("0x0__1", &.{.number_literal});
    try testTokenize("0x0_1_", &.{.number_literal});
    try testTokenize("0x_,", &.{ .number_literal, .comma });

    try testTokenize("0x1.0", &.{.number_literal});
    try testTokenize("0xF.0", &.{.number_literal});
    try testTokenize("0xF.F", &.{.number_literal});
    try testTokenize("0xF.Fp0", &.{.number_literal});
    try testTokenize("0xF.FP0", &.{.number_literal});
    try testTokenize("0x1p0", &.{.number_literal});
    try testTokenize("0xfp0", &.{.number_literal});
    try testTokenize("0x1.0+0xF.0", &.{ .number_literal, .plus, .number_literal });

    try testTokenize("0x1.", &.{ .number_literal, .period });
    try testTokenize("0xF.", &.{ .number_literal, .period });
    try testTokenize("0x1.+0xF.", &.{ .number_literal, .period, .plus, .number_literal, .period });
    try testTokenize("0xff.p10", &.{.number_literal});

    try testTokenize("0x0123456.789ABCDEF", &.{.number_literal});
    try testTokenize("0x0_123_456.789_ABC_DEF", &.{.number_literal});
    try testTokenize("0x0_1_2_3_4_5_6.7_8_9_A_B_C_D_E_F", &.{.number_literal});
    try testTokenize("0x0p0", &.{.number_literal});
    try testTokenize("0x0.0p0", &.{.number_literal});
    try testTokenize("0xff.ffp10", &.{.number_literal});
    try testTokenize("0xff.ffP10", &.{.number_literal});
    try testTokenize("0xffp10", &.{.number_literal});
    try testTokenize("0xff_ff.ff_ffp1_0_0_0", &.{.number_literal});
    try testTokenize("0xf_f_f_f.f_f_f_fp+1_000", &.{.number_literal});
    try testTokenize("0xf_f_f_f.f_f_f_fp-1_00_0", &.{.number_literal});

    try testTokenize("0x1e", &.{.number_literal});
    try testTokenize("0x1e0", &.{.number_literal});
    try testTokenize("0x1p", &.{.number_literal});
    try testTokenize("0xfp0z1", &.{.number_literal});
    try testTokenize("0xff.ffpff", &.{.number_literal});
    try testTokenize("0x0.p", &.{.number_literal});
    try testTokenize("0x0.z", &.{.number_literal});
    try testTokenize("0x0._", &.{.number_literal});
    try testTokenize("0x0_.0", &.{.number_literal});
    try testTokenize("0x0_.0.0", &.{ .number_literal, .period, .number_literal });
    try testTokenize("0x0._0", &.{.number_literal});
    try testTokenize("0x0.0_", &.{.number_literal});
    try testTokenize("0x0_p0", &.{.number_literal});
    try testTokenize("0x0_.p0", &.{.number_literal});
    try testTokenize("0x0._p0", &.{.number_literal});
    try testTokenize("0x0.0_p0", &.{.number_literal});
    try testTokenize("0x0._0p0", &.{.number_literal});
    try testTokenize("0x0.0p_0", &.{.number_literal});
    try testTokenize("0x0.0p+_0", &.{.number_literal});
    try testTokenize("0x0.0p-_0", &.{.number_literal});
    try testTokenize("0x0.0p0_", &.{.number_literal});
}

test "multi line string literal with only 1 backslash" {
    try testTokenize("x \\\n;", &.{ .identifier, .invalid, .semicolon });
}

test "invalid builtin identifiers" {
    try testTokenize("@()", &.{.invalid});
    try testTokenize("@0()", &.{.invalid});
}

test "invalid token with unfinished escape right before eof" {
    try testTokenize("\"\\", &.{.invalid});
    try testTokenize("'\\", &.{.invalid});
    try testTokenize("'\\u", &.{.invalid});
}

test "saturating operators" {
    try testTokenize("<<", &.{.angle_bracket_angle_bracket_left});
    try testTokenize("<<|", &.{.angle_bracket_angle_bracket_left_pipe});
    try testTokenize("<<|=", &.{.angle_bracket_angle_bracket_left_pipe_equal});

    try testTokenize("*", &.{.asterisk});
    try testTokenize("*|", &.{.asterisk_pipe});
    try testTokenize("*|=", &.{.asterisk_pipe_equal});

    try testTokenize("+", &.{.plus});
    try testTokenize("+|", &.{.plus_pipe});
    try testTokenize("+|=", &.{.plus_pipe_equal});

    try testTokenize("-", &.{.minus});
    try testTokenize("-|", &.{.minus_pipe});
    try testTokenize("-|=", &.{.minus_pipe_equal});
}

test "null byte before eof" {
    try testTokenize("123 \x00 456", &.{ .number_literal, .invalid });
    try testTokenize("//\x00", &.{.invalid});
    try testTokenize("\\\\\x00", &.{.invalid});
    try testTokenize("\x00", &.{.invalid});
    try testTokenize("// NUL\x00\n", &.{.invalid});
    try testTokenize("///\x00\n", &.{ .doc_comment, .invalid });
    try testTokenize("/// NUL\x00\n", &.{ .doc_comment, .invalid });
}

test "invalid tabs and carriage returns" {
    // "Inside Line Comments and Documentation Comments, Any TAB is rejected by
    // the grammar since it is ambiguous how it should be rendered."
    // https://github.com/ziglang/zig-spec/issues/38
    try testTokenize("//\t", &.{.invalid});
    try testTokenize("// \t", &.{.invalid});
    try testTokenize("///\t", &.{.invalid});
    try testTokenize("/// \t", &.{.invalid});
    try testTokenize("//!\t", &.{.invalid});
    try testTokenize("//! \t", &.{.invalid});

    // "Inside Line Comments and Documentation Comments, CR directly preceding
    // NL is unambiguously part of the newline sequence. It is accepted by the
    // grammar and removed by zig fmt, leaving only NL. CR anywhere else is
    // rejected by the grammar."
    // https://github.com/ziglang/zig-spec/issues/38
    try testTokenize("//\r", &.{.invalid});
    try testTokenize("// \r", &.{.invalid});
    try testTokenize("///\r", &.{.invalid});
    try testTokenize("/// \r", &.{.invalid});
    try testTokenize("//\r ", &.{.invalid});
    try testTokenize("// \r ", &.{.invalid});
    try testTokenize("///\r ", &.{.invalid});
    try testTokenize("/// \r ", &.{.invalid});
    try testTokenize("//\r\n", &.{});
    try testTokenize("// \r\n", &.{});
    try testTokenize("///\r\n", &.{.doc_comment});
    try testTokenize("/// \r\n", &.{.doc_comment});
    try testTokenize("//!\r", &.{.invalid});
    try testTokenize("//! \r", &.{.invalid});
    try testTokenize("//!\r ", &.{.invalid});
    try testTokenize("//! \r ", &.{.invalid});
    try testTokenize("//!\r\n", &.{.container_doc_comment});
    try testTokenize("//! \r\n", &.{.container_doc_comment});

    // The control characters TAB and CR are rejected by the grammar inside multi-line string literals,
    // except if CR is directly before NL.
    // https://github.com/ziglang/zig-spec/issues/38
    try testTokenize("\\\\\r", &.{.invalid});
    try testTokenize("\\\\\r ", &.{.invalid});
    try testTokenize("\\\\ \r", &.{.invalid});
    try testTokenize("\\\\\t", &.{.invalid});
    try testTokenize("\\\\\t ", &.{.invalid});
    try testTokenize("\\\\ \t", &.{.invalid});
    try testTokenize("\\\\\r\n", &.{.multiline_string_literal_line});

    // "TAB used as whitespace is...accepted by the grammar. CR used as
    // whitespace, whether directly preceding NL or stray, is...accepted by the
    // grammar."
    // https://github.com/ziglang/zig-spec/issues/38
    try testTokenize("\tpub\tswitch\t", &.{ .keyword_pub, .keyword_switch });
    try testTokenize("\rpub\rswitch\r", &.{ .keyword_pub, .keyword_switch });
}

test "fuzzable properties upheld" {
    return std.testing.fuzz(testPropertiesUpheld, .{});
}

fn testTokenize(source: [:0]const u8, expected_token_tags: []const Token.Tag) !void {
    var tokenizer = Tokenizer.init(source);
    for (expected_token_tags) |expected_token_tag| {
        const token = tokenizer.next();
        try std.testing.expectEqual(expected_token_tag, token.tag);
    }
    // Last token should always be eof, even when the last token was invalid,
    // in which case the tokenizer is in an invalid state, which can only be
    // recovered by opinionated means outside the scope of this implementation.
    const last_token = tokenizer.next();
    try std.testing.expectEqual(Token.Tag.eof, last_token.tag);
    try std.testing.expectEqual(source.len, last_token.loc.start);
    try std.testing.expectEqual(source.len, last_token.loc.end);
}

fn testPropertiesUpheld(source: []const u8) anyerror!void {
    const source0 = try std.testing.allocator.dupeZ(u8, source);
    defer std.testing.allocator.free(source0);
    var tokenizer = Tokenizer.init(source0);
    var tokenization_failed = false;
    while (true) {
        const token = tokenizer.next();

        // Property: token end location after start location (or equal)
        try std.testing.expect(token.loc.end >= token.loc.start);

        switch (token.tag) {
            .invalid => {
                tokenization_failed = true;

                // Property: invalid token always ends at newline or eof
                try std.testing.expect(source0[token.loc.end] == '\n' or source0[token.loc.end] == 0);
            },
            .eof => {
                // Property: EOF token is always 0-length at end of source.
                try std.testing.expectEqual(source0.len, token.loc.start);
                try std.testing.expectEqual(source0.len, token.loc.end);
                break;
            },
            else => continue,
        }
    }

    if (source0.len > 0) for (source0, source0[1..][0..source0.len]) |cur, next| {
        // Property: No null byte allowed except at end.
        if (cur == 0) {
            try std.testing.expect(tokenization_failed);
        }
        // Property: No ASCII control characters other than \n and \t are allowed.
        if (std.ascii.isControl(cur) and cur != '\n' and cur != '\t') {
            try std.testing.expect(tokenization_failed);
        }
        // Property: All '\r' must be followed by '\n'.
        if (cur == '\r' and next != '\n') {
            try std.testing.expect(tokenization_failed);
        }
    };
}
