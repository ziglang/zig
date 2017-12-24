const std = @import("std");
const mem = std.mem;

pub const Token = struct {
    id: Id,
    start: usize,
    end: usize,

    const KeywordId = struct {
        bytes: []const u8,
        id: Id,
    };

    const keywords = []KeywordId {
        KeywordId{.bytes="align", .id = Id.Keyword_align},
        KeywordId{.bytes="and", .id = Id.Keyword_and},
        KeywordId{.bytes="asm", .id = Id.Keyword_asm},
        KeywordId{.bytes="break", .id = Id.Keyword_break},
        KeywordId{.bytes="coldcc", .id = Id.Keyword_coldcc},
        KeywordId{.bytes="comptime", .id = Id.Keyword_comptime},
        KeywordId{.bytes="const", .id = Id.Keyword_const},
        KeywordId{.bytes="continue", .id = Id.Keyword_continue},
        KeywordId{.bytes="defer", .id = Id.Keyword_defer},
        KeywordId{.bytes="else", .id = Id.Keyword_else},
        KeywordId{.bytes="enum", .id = Id.Keyword_enum},
        KeywordId{.bytes="error", .id = Id.Keyword_error},
        KeywordId{.bytes="export", .id = Id.Keyword_export},
        KeywordId{.bytes="extern", .id = Id.Keyword_extern},
        KeywordId{.bytes="false", .id = Id.Keyword_false},
        KeywordId{.bytes="fn", .id = Id.Keyword_fn},
        KeywordId{.bytes="for", .id = Id.Keyword_for},
        KeywordId{.bytes="goto", .id = Id.Keyword_goto},
        KeywordId{.bytes="if", .id = Id.Keyword_if},
        KeywordId{.bytes="inline", .id = Id.Keyword_inline},
        KeywordId{.bytes="nakedcc", .id = Id.Keyword_nakedcc},
        KeywordId{.bytes="noalias", .id = Id.Keyword_noalias},
        KeywordId{.bytes="null", .id = Id.Keyword_null},
        KeywordId{.bytes="or", .id = Id.Keyword_or},
        KeywordId{.bytes="packed", .id = Id.Keyword_packed},
        KeywordId{.bytes="pub", .id = Id.Keyword_pub},
        KeywordId{.bytes="return", .id = Id.Keyword_return},
        KeywordId{.bytes="stdcallcc", .id = Id.Keyword_stdcallcc},
        KeywordId{.bytes="struct", .id = Id.Keyword_struct},
        KeywordId{.bytes="switch", .id = Id.Keyword_switch},
        KeywordId{.bytes="test", .id = Id.Keyword_test},
        KeywordId{.bytes="this", .id = Id.Keyword_this},
        KeywordId{.bytes="true", .id = Id.Keyword_true},
        KeywordId{.bytes="undefined", .id = Id.Keyword_undefined},
        KeywordId{.bytes="union", .id = Id.Keyword_union},
        KeywordId{.bytes="unreachable", .id = Id.Keyword_unreachable},
        KeywordId{.bytes="use", .id = Id.Keyword_use},
        KeywordId{.bytes="var", .id = Id.Keyword_var},
        KeywordId{.bytes="volatile", .id = Id.Keyword_volatile},
        KeywordId{.bytes="while", .id = Id.Keyword_while},
    };

    fn getKeyword(bytes: []const u8) -> ?Id {
        for (keywords) |kw| {
            if (mem.eql(u8, kw.bytes, bytes)) {
                return kw.id;
            }
        }
        return null;
    }

    const StrLitKind = enum {Normal, C};

    pub const Id = union(enum) {
        Invalid,
        Identifier,
        StringLiteral: StrLitKind,
        Eof,
        NoEolAtEof,
        Builtin,
        Bang,
        Equal,
        EqualEqual,
        BangEqual,
        LParen,
        RParen,
        Semicolon,
        Percent,
        LBrace,
        RBrace,
        Period,
        Ellipsis2,
        Ellipsis3,
        Minus,
        Arrow,
        Colon,
        Slash,
        Comma,
        Ampersand,
        AmpersandEqual,
        IntegerLiteral,
        FloatLiteral,
        Keyword_align,
        Keyword_and,
        Keyword_asm,
        Keyword_break,
        Keyword_coldcc,
        Keyword_comptime,
        Keyword_const,
        Keyword_continue,
        Keyword_defer,
        Keyword_else,
        Keyword_enum,
        Keyword_error,
        Keyword_export,
        Keyword_extern,
        Keyword_false,
        Keyword_fn,
        Keyword_for,
        Keyword_goto,
        Keyword_if,
        Keyword_inline,
        Keyword_nakedcc,
        Keyword_noalias,
        Keyword_null,
        Keyword_or,
        Keyword_packed,
        Keyword_pub,
        Keyword_return,
        Keyword_stdcallcc,
        Keyword_struct,
        Keyword_switch,
        Keyword_test,
        Keyword_this,
        Keyword_true,
        Keyword_undefined,
        Keyword_union,
        Keyword_unreachable,
        Keyword_use,
        Keyword_var,
        Keyword_volatile,
        Keyword_while,
    };
};

pub const Tokenizer = struct {
    buffer: []const u8,
    index: usize,
    actual_file_end: usize,

    pub const Location = struct {
        line: usize,
        column: usize,
        line_start: usize,
        line_end: usize,
    };

    pub fn getTokenLocation(self: &Tokenizer, token: &const Token) -> Location {
        var loc = Location {
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 0,
        };
        for (self.buffer) |c, i| {
            if (i == token.start) {
                loc.line_end = i;
                while (loc.line_end < self.buffer.len and self.buffer[loc.line_end] != '\n') : (loc.line_end += 1) {}
                return loc;
            }
            if (c == '\n') {
                loc.line += 1;
                loc.column = 0;
                loc.line_start = i + 1;
            } else {
                loc.column += 1;
            }
        }
        return loc;
    }

    /// For debugging purposes
    pub fn dump(self: &Tokenizer, token: &const Token) {
        std.debug.warn("{} \"{}\"\n", @tagName(token.id), self.buffer[token.start..token.end]);
    }

    pub fn init(buffer: []const u8) -> Tokenizer {
        if (buffer.len == 0 or buffer[buffer.len - 1] == '\n') {
            return Tokenizer {
                .buffer = buffer,
                .index = 0,
                .actual_file_end = buffer.len,
            };
        } else {
            // last line is incomplete, so skip it, and give an error when we get there.
            var source_len = buffer.len;
            while (source_len > 0) : (source_len -= 1) {
                if (buffer[source_len - 1] == '\n') break;
            }
            return Tokenizer {
                .buffer = buffer[0..source_len],
                .index = 0,
                .actual_file_end = buffer.len,
            };
        }
    }

    const State = enum {
        Start,
        Identifier,
        Builtin,
        C,
        StringLiteral,
        StringLiteralBackslash,
        Equal,
        Bang,
        Minus,
        Slash,
        LineComment,
        Zero,
        IntegerLiteral,
        NumberDot,
        FloatFraction,
        FloatExponentUnsigned,
        FloatExponentNumber,
        Ampersand,
        Period,
        Period2,
    };

    pub fn next(self: &Tokenizer) -> Token {
        var state = State.Start;
        var result = Token {
            .id = Token.Id.Eof,
            .start = self.index,
            .end = undefined,
        };
        while (self.index < self.buffer.len) : (self.index += 1) {
            const c = self.buffer[self.index];
            switch (state) {
                State.Start => switch (c) {
                    ' ', '\n' => {
                        result.start = self.index + 1;
                    },
                    'c' => {
                        state = State.C;
                        result.id = Token.Id.Identifier;
                    },
                    '"' => {
                        state = State.StringLiteral;
                        result.id = Token.Id { .StringLiteral = Token.StrLitKind.Normal };
                    },
                    'a'...'b', 'd'...'z', 'A'...'Z', '_' => {
                        state = State.Identifier;
                        result.id = Token.Id.Identifier;
                    },
                    '@' => {
                        state = State.Builtin;
                        result.id = Token.Id.Builtin;
                    },
                    '=' => {
                        state = State.Equal;
                    },
                    '!' => {
                        state = State.Bang;
                    },
                    '(' => {
                        result.id = Token.Id.LParen;
                        self.index += 1;
                        break;
                    },
                    ')' => {
                        result.id = Token.Id.RParen;
                        self.index += 1;
                        break;
                    },
                    ';' => {
                        result.id = Token.Id.Semicolon;
                        self.index += 1;
                        break;
                    },
                    ',' => {
                        result.id = Token.Id.Comma;
                        self.index += 1;
                        break;
                    },
                    ':' => {
                        result.id = Token.Id.Colon;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        result.id = Token.Id.Percent;
                        self.index += 1;
                        break;
                    },
                    '{' => {
                        result.id = Token.Id.LBrace;
                        self.index += 1;
                        break;
                    },
                    '}' => {
                        result.id = Token.Id.RBrace;
                        self.index += 1;
                        break;
                    },
                    '.' => {
                        state = State.Period;
                    },
                    '-' => {
                        state = State.Minus;
                    },
                    '/' => {
                        state = State.Slash;
                    },
                    '&' => {
                        state = State.Ampersand;
                    },
                    '0' => {
                        state = State.Zero;
                        result.id = Token.Id.IntegerLiteral;
                    },
                    '1'...'9' => {
                        state = State.IntegerLiteral;
                        result.id = Token.Id.IntegerLiteral;
                    },
                    else => {
                        result.id = Token.Id.Invalid;
                        self.index += 1;
                        break;
                    },
                },
                State.Ampersand => switch (c) {
                    '=' => {
                        result.id = Token.Id.AmpersandEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Ampersand;
                        break;
                    },
                },
                State.Identifier => switch (c) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => {},
                    else => {
                        if (Token.getKeyword(self.buffer[result.start..self.index])) |id| {
                            result.id = id;
                        }
                        break;
                    },
                },
                State.Builtin => switch (c) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => {},
                    else => break,
                },
                State.C => switch (c) {
                    '\\' => @panic("TODO"),
                    '"' => {
                        state = State.StringLiteral;
                        result.id = Token.Id { .StringLiteral = Token.StrLitKind.C };
                    },
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => {
                        state = State.Identifier;
                    },
                    else => break,
                },
                State.StringLiteral => switch (c) {
                    '\\' => {
                        state = State.StringLiteralBackslash;
                    },
                    '"' => {
                        self.index += 1;
                        break;
                    },
                    '\n' => break, // Look for this error later.
                    else => {},
                },

                State.StringLiteralBackslash => switch (c) {
                    '\n' => break, // Look for this error later.
                    else => {
                        state = State.StringLiteral;
                    },
                },

                State.Bang => switch (c) {
                    '=' => {
                        result.id = Token.Id.BangEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Bang;
                        break;
                    },
                },

                State.Equal => switch (c) {
                    '=' => {
                        result.id = Token.Id.EqualEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Equal;
                        break;
                    },
                },

                State.Minus => switch (c) {
                    '>' => {
                        result.id = Token.Id.Arrow;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Minus;
                        break;
                    },
                },

                State.Period => switch (c) {
                    '.' => {
                        state = State.Period2;
                    },
                    else => {
                        result.id = Token.Id.Period;
                        break;
                    },
                },

                State.Period2 => switch (c) {
                    '.' => {
                        result.id = Token.Id.Ellipsis3;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Ellipsis2;
                        break;
                    },
                },

                State.Slash => switch (c) {
                    '/' => {
                        result.id = undefined;
                        state = State.LineComment;
                    },
                    else => {
                        result.id = Token.Id.Slash;
                        break;
                    },
                },
                State.LineComment => switch (c) {
                    '\n' => {
                        state = State.Start;
                        result = Token {
                            .id = Token.Id.Eof,
                            .start = self.index + 1,
                            .end = undefined,
                        };
                    },
                    else => {},
                },
                State.Zero => switch (c) {
                    'b', 'o', 'x' => {
                        state = State.IntegerLiteral;
                    },
                    else => {
                        // reinterpret as a normal number
                        self.index -= 1;
                        state = State.IntegerLiteral;
                    },
                },
                State.IntegerLiteral => switch (c) {
                    '.' => {
                        state = State.NumberDot;
                    },
                    'p', 'P', 'e', 'E' => {
                        state = State.FloatExponentUnsigned;
                    },
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    else => break,
                },
                State.NumberDot => switch (c) {
                    '.' => {
                        self.index -= 1;
                        state = State.Start;
                        break;
                    },
                    else => {
                        self.index -= 1;
                        result.id = Token.Id.FloatLiteral;
                        state = State.FloatFraction;
                    },
                },
                State.FloatFraction => switch (c) {
                    'p', 'P', 'e', 'E' => {
                        state = State.FloatExponentUnsigned;
                    },
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    else => break,
                },
                State.FloatExponentUnsigned => switch (c) {
                    '+', '-' => {
                        state = State.FloatExponentNumber;
                    },
                    else => {
                        // reinterpret as a normal exponent number
                        self.index -= 1;
                        state = State.FloatExponentNumber;
                    }
                },
                State.FloatExponentNumber => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    else => break,
                },
            }
        }
        result.end = self.index;
        if (result.id == Token.Id.Eof and self.actual_file_end != self.buffer.len) {
            // instead of an Eof, give an error token
            result.id = Token.Id.NoEolAtEof;
            result.end = self.actual_file_end;
        }
        return result;
    }

    pub fn getTokenSlice(self: &const Tokenizer, token: &const Token) -> []const u8 {
        return self.buffer[token.start..token.end];
    }
};



test "tokenizer" {
    // source must end with eol
    testTokenize("no newline", []Token.Id {
    }, false);
    testTokenize("test\n", []Token.Id {
        Token.Id.Keyword_test,
    }, true);
    testTokenize("test\nno newline", []Token.Id {
        Token.Id.Keyword_test,
    }, false);
}

fn testTokenize(source: []const u8, expected_tokens: []const Token.Id, expected_eol_at_eof: bool) {
    var tokenizer = Tokenizer.init(source);
    for (expected_tokens) |expected_token_id| {
        const token = tokenizer.next();
        std.debug.assert(@TagType(Token.Id)(token.id) == @TagType(Token.Id)(expected_token_id));
        switch (expected_token_id) {
            Token.Id.StringLiteral => |kind| {
                @panic("TODO: how do i test this?");
            },
            else => {},
        }
    }
    std.debug.assert(tokenizer.next().id == if (expected_eol_at_eof) Token.Id.Eof else Token.Id.NoEolAtEof);
}
