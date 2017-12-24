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
    pending_invalid_token: ?Token,

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
        var source_len = buffer.len;
        while (source_len > 0) : (source_len -= 1) {
            if (buffer[source_len - 1] == '\n') break;
            // last line is incomplete, so skip it, and give an error when we get there.
        }

        return Tokenizer {
            .buffer = buffer[0..source_len],
            .index = 0,
            .actual_file_end = buffer.len,
            .pending_invalid_token = null,
        };
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
        if (self.pending_invalid_token) |token| {
            self.pending_invalid_token = null;
            return token;
        }
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
                    else => self.checkLiteralCharacter(),
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
                    else => self.checkLiteralCharacter(),
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
        if (result.id == Token.Id.Eof) {
            if (self.pending_invalid_token) |token| {
                self.pending_invalid_token = null;
                return token;
            }
            if (self.actual_file_end != self.buffer.len) {
                // instead of an Eof, give an error token
                result.id = Token.Id.NoEolAtEof;
                result.end = self.actual_file_end;
            }
        }
        return result;
    }

    pub fn getTokenSlice(self: &const Tokenizer, token: &const Token) -> []const u8 {
        return self.buffer[token.start..token.end];
    }

    fn checkLiteralCharacter(self: &Tokenizer) {
        if (self.pending_invalid_token != null) return;
        const invalid_length = self.getInvalidCharacterLength();
        if (invalid_length == 0) return;
        self.pending_invalid_token = Token {
            .id = Token.Id.Invalid,
            .start = self.index,
            .end = self.index + invalid_length,
        };
    }

    fn getInvalidCharacterLength(self: &Tokenizer) -> u3 {
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
            // remember that the last byte in the buffer is guaranteed to be '\n',
            // which means we really don't need to do bounds checks here,
            // as long as we check one byte at a time for being a continuation byte.
            var value: u32 = undefined;
            var length: u3 = undefined;
            if      (c0 & 0b11100000 == 0b11000000) {value = c0 & 0b00011111; length = 2;}
            else if (c0 & 0b11110000 == 0b11100000) {value = c0 & 0b00001111; length = 3;}
            else if (c0 & 0b11111000 == 0b11110000) {value = c0 & 0b00000111; length = 4;}
            else return 1; // unexpected continuation or too many leading 1's

            const c1 = self.buffer[self.index + 1];
            if (c1 & 0b11000000 != 0b10000000) return 1; // expected continuation
            value <<= 6;
            value |= c1 & 0b00111111;
            if (length == 2) {
                if (value < 0x80) return length; // overlong
                if (value == 0x85) return length; // U+0085 (NEL)
                self.index += length - 1;
                return 0;
            }
            const c2 = self.buffer[self.index + 2];
            if (c2 & 0b11000000 != 0b10000000) return 2; // expected continuation
            value <<= 6;
            value |= c2 & 0b00111111;
            if (length == 3) {
                if (value < 0x800) return length; // overlong
                if (value == 0x2028) return length; // U+2028 (LS)
                if (value == 0x2029) return length; // U+2029 (PS)
                if (0xd800 <= value and value <= 0xdfff) return length; // surrogate halves not allowed in utf8
                self.index += length - 1;
                return 0;
            }
            const c3 = self.buffer[self.index + 3];
            if (c3 & 0b11000000 != 0b10000000) return 3; // expected continuation
            value <<= 6;
            value |= c3 & 0b00111111;
            if (length == 4) {
                if (value < 0x10000) return length; // overlong
                if (value > 0x10FFFF) return length; // out of bounds
                self.index += length - 1;
                return 0;
            }
            unreachable;
        }
    }
};



test "tokenizer - source must end with eol" {
    testTokenizeWithEol("", []Token.Id {
    }, true);
    testTokenizeWithEol("no newline", []Token.Id {
    }, false);
    testTokenizeWithEol("test\n", []Token.Id {
        Token.Id.Keyword_test,
    }, true);
    testTokenizeWithEol("test\nno newline", []Token.Id {
        Token.Id.Keyword_test,
    }, false);
}

test "tokenizer - invalid token characters" {
    testTokenize("#\n", []Token.Id{Token.Id.Invalid});
    testTokenize("`\n", []Token.Id{Token.Id.Invalid});
}

test "tokenizer - invalid literal/comment characters" {
    testTokenize("\"\x00\"\n", []Token.Id {
        Token.Id { .StringLiteral = Token.StrLitKind.Normal },
        Token.Id.Invalid,
    });
    testTokenize("//\x00\n", []Token.Id {
        Token.Id.Invalid,
    });
    testTokenize("//\x1f\n", []Token.Id {
        Token.Id.Invalid,
    });
    testTokenize("//\x7f\n", []Token.Id {
        Token.Id.Invalid,
    });
}

test "tokenizer - valid unicode" {
    testTokenize("//\xc2\x80\n", []Token.Id{});
    testTokenize("//\xdf\xbf\n", []Token.Id{});
    testTokenize("//\xe0\xa0\x80\n", []Token.Id{});
    testTokenize("//\xe1\x80\x80\n", []Token.Id{});
    testTokenize("//\xef\xbf\xbf\n", []Token.Id{});
    testTokenize("//\xf0\x90\x80\x80\n", []Token.Id{});
    testTokenize("//\xf1\x80\x80\x80\n", []Token.Id{});
    testTokenize("//\xf3\xbf\xbf\xbf\n", []Token.Id{});
    testTokenize("//\xf4\x8f\xbf\xbf\n", []Token.Id{});
}

test "tokenizer - invalid unicode continuation bytes" {
    // unexpected continuation
    testTokenize("//\x80\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xbf\n", []Token.Id{Token.Id.Invalid});
    // too many leading 1's
    testTokenize("//\xf8\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xff\n", []Token.Id{Token.Id.Invalid});
    // expected continuation for 2 byte sequences
    testTokenize("//\xc2\x00\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xc2\xc0\n", []Token.Id{Token.Id.Invalid});
    // expected continuation for 3 byte sequences
    testTokenize("//\xe0\x00\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xe0\xc0\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xe0\xa0\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xe0\xa0\x00\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xe0\xa0\xc0\n", []Token.Id{Token.Id.Invalid});
    // expected continuation for 4 byte sequences
    testTokenize("//\xf0\x00\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xf0\xc0\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xf0\x90\x00\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xf0\x90\xc0\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xf0\x90\x80\x00\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xf0\x90\x80\xc0\n", []Token.Id{Token.Id.Invalid});
}

test "tokenizer - overlong utf8 codepoint" {
    testTokenize("//\xc0\x80\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xc1\xbf\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xe0\x80\x80\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xe0\x9f\xbf\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xf0\x80\x80\x80\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xf0\x8f\xbf\xbf\n", []Token.Id{Token.Id.Invalid});
}

test "tokenizer - misc invalid utf8" {
    // codepoint out of bounds
    testTokenize("//\xf4\x90\x80\x80\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xf7\xbf\xbf\xbf\n", []Token.Id{Token.Id.Invalid});
    // unicode newline characters.U+0085, U+2028, U+2029
    testTokenize("//\xc2\x84\n", []Token.Id{});
    testTokenize("//\xc2\x85\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xc2\x86\n", []Token.Id{});
    testTokenize("//\xe2\x80\xa7\n", []Token.Id{});
    testTokenize("//\xe2\x80\xa8\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xe2\x80\xa9\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xe2\x80\xaa\n", []Token.Id{});
    // surrogate halves
    testTokenize("//\xed\x9f\x80\n", []Token.Id{});
    testTokenize("//\xed\xa0\x80\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xed\xbf\xbf\n", []Token.Id{Token.Id.Invalid});
    testTokenize("//\xee\x80\x80\n", []Token.Id{});
    // surrogate halves are invalid, even in surrogate pairs
    testTokenize("//\xed\xa0\xad\xed\xb2\xa9\n", []Token.Id{Token.Id.Invalid});
}

fn testTokenize(source: []const u8, expected_tokens: []const Token.Id) {
    testTokenizeWithEol(source, expected_tokens, true);
}
fn testTokenizeWithEol(source: []const u8, expected_tokens: []const Token.Id, expected_eol_at_eof: bool) {
    var tokenizer = Tokenizer.init(source);
    for (expected_tokens) |expected_token_id| {
        const token = tokenizer.next();
        std.debug.assert(@TagType(Token.Id)(token.id) == @TagType(Token.Id)(expected_token_id));
        switch (expected_token_id) {
            Token.Id.StringLiteral => |expected_kind| {
                std.debug.assert(expected_kind == switch (token.id) { Token.Id.StringLiteral => |kind| kind, else => unreachable });
            },
            else => {},
        }
    }
    std.debug.assert(tokenizer.next().id == if (expected_eol_at_eof) Token.Id.Eof else Token.Id.NoEolAtEof);
}
