const std = @import("std");
const expect = std.testing.expect;

pub const Source = struct {
    buffer: []const u8,
    file_name: []const u8,
};

pub const Token = struct {
    id: Id,
    num_suffix: NumSuffix = .None,
    start: usize,
    end: usize,
    source: *Source,

    pub const Id = enum {
        Invalid,
        Eof,
        Nl,
        Identifier,
        StringLiteral,
        CharLiteral,
        IntegerLiteral,
        FloatLiteral,
        Bang,
        BangEqual,
        Pipe,
        PipePipe,
        PipeEqual,
        Equal,
        EqualEqual,
        EqualAngleBracketRight,
        LParen,
        RParen,
        LBrace,
        RBrace,
        LBracket,
        RBracket,
        Period,
        PeriodAsterisk,
        Ellipsis,
        Caret,
        CaretEqual,
        Plus,
        PlusPlus,
        PlusEqual,
        Minus,
        MinusMinus,
        MinusEqual,
        Asterisk,
        AsteriskEqual,
        Percent,
        PercentEqual,
        Arrow,
        Colon,
        Semicolon,
        Slash,
        SlashEqual,
        Comma,
        Ampersand,
        AmpersandAmpersand,
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
        LineComment,
        MultiLineComment,
        Hash,
        HashHash,
    };

    pub const NumSuffix = enum {
        None,
        F,
        L,
        U,
        LU,
        LL,
        LLU,
    };
};

pub const Tokenizer = struct {
    source: *Source,
    index: usize = 0,

    pub fn next(self: *Tokenizer) Token {
        const start_index = self.index;
        var result = Token{
            .id = .Eof,
            .start = self.index,
            .end = undefined,
            .source = self.source,
        };
        var state: enum {
            Start,
            Cr,
            StringLiteral,
            CharLiteral,
            EscapeSequence,
            OctalEscape,
            HexEscape,
            UnicodeEscape,
            Identifier,
            Equal,
            Bang,
            Pipe,
            Percent,
            Asterisk,
            Plus,
            AngleBracketLeft,
            AngleBracketAngleBracketLeft,
            AngleBracketRight,
            AngleBracketAngleBracketRight,
            Caret,
            Period,
            Period2,
            Minus,
            Slash,
            Ampersand,
            LineComment,
            MultiLineComment,
            MultiLineCommentAsterisk,
            Zero,
            IntegerLiteralOct,
            IntegerLiteralBinary,
            IntegerLiteralHex,
            IntegerLiteral,
            IntegerSuffix,
            IntegerSuffixU,
            IntegerSuffixL,
            IntegerSuffixLL,
            IntegerSuffixUL,
            FloatFraction,
            FloatFractionHex,
            FloatExponent,
            FloatExponentDigits,
            FloatSuffix,
        } = .Start;
        var string = false;
        var counter: u32 = 0;
        while (self.index < self.source.buffer.len) : (self.index += 1) {
            const c = self.source.buffer[self.index];
            switch (state) {
                .Start => switch (c) {
                    '\n' => {
                        result.id = .Nl;
                        self.index += 1;
                        break;
                    },
                    '\r' => {
                        state = .Cr;
                    },
                    ' ', '\t' => {
                        result.start = self.index + 1;
                    },
                    '"' => {
                        state = .StringLiteral;
                        result.id = .StringLiteral;
                    },
                    '\'' => {
                        state = .CharLiteral;
                    },
                    'a'...'z', 'A'...'Z', '_' => {
                        state = .Identifier;
                        result.id = .Identifier;
                    },
                    '=' => {
                        state = .Equal;
                    },
                    '!' => {
                        state = .Bang;
                    },
                    '|' => {
                        state = .Pipe;
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
                        state = .Percent;
                    },
                    '*' => {
                        state = .Asterisk;
                    },
                    '+' => {
                        state = .Plus;
                    },
                    '<' => {
                        state = .AngleBracketLeft;
                    },
                    '>' => {
                        state = .AngleBracketRight;
                    },
                    '^' => {
                        state = .Caret;
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
                        state = .Period;
                    },
                    '-' => {
                        state = .Minus;
                    },
                    '/' => {
                        state = .Slash;
                    },
                    '&' => {
                        state = .Ampersand;
                    },
                    '0' => {
                        state = .Zero;
                        result.id = .IntegerLiteral;
                    },
                    '1'...'9' => {
                        state = .IntegerLiteral;
                        result.id = .IntegerLiteral;
                    },
                    else => {
                        result.id = .Invalid;
                        self.index += 1;
                        break;
                    },
                },
                .Cr => switch (c) {
                    '\n' => {
                        result.id = .Nl;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Invalid;
                        break;
                    },
                },
                // TODO l"" u"" U"" u8""
                .StringLiteral => switch (c) {
                    '\\' => {
                        string = true;
                        state = .EscapeSequence;
                    },
                    '"' => {
                        result.id = .StringLiteral;
                        self.index += 1;
                        break;
                    },
                    '\n', '\r' => {
                        result.id = .Invalid;
                        break;
                    },
                    else => {},
                },
                // TODO l'' u'' U''
                .CharLiteral => switch (c) {
                    '\\' => {
                        string = false;
                        state = .EscapeSequence;
                    },
                    '\'', '\n' => {
                        result.id = .Invalid;
                        break;
                    },
                    else => {},
                },
                .EscapeSequence => switch (c) {
                    '\'', '"', '?', '\\', 'a', 'b', 'f', 'n', 'r', 't', 'v' => {},
                    '0'...'7' => {
                        counter = 1;
                        state = .OctalEscape;
                    },
                    'x' => {
                        state = .HexEscape;
                    },
                    'u' => {
                        counter = 4;
                        state = .OctalEscape;
                    },
                    'U' => {
                        counter = 8;
                        state = .OctalEscape;
                    },
                    else => {
                        result.id = .Invalid;
                        break;
                    },
                },
                .OctalEscape => switch (c) {
                    '0'...'7' => {
                        counter += 1;
                        if (counter == 3) {
                            state = if (string) .StringLiteral else .CharLiteral;
                        }
                    },
                    else => {
                        state = if (string) .StringLiteral else .CharLiteral;
                    },
                },
                .HexEscape => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    else => {
                        state = if (string) .StringLiteral else .CharLiteral;
                    },
                },
                .UnicodeEscape => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        counter -= 1;
                        if (counter == 0) {
                            state = if (string) .StringLiteral else .CharLiteral;
                        }
                    },
                    else => {
                        if (counter != 0) {
                            result.id = .Invalid;
                            break;
                        }
                        state = if (string) .StringLiteral else .CharLiteral;
                    },
                },
                .Identifier => switch (c) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => {},
                    else => {
                        result.id = .Identifier;
                        break;
                    },
                },
                .Equal => switch (c) {
                    '=' => {
                        result.id = .EqualEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Equal;
                        break;
                    },
                },
                .Bang => switch (c) {
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
                .Pipe => switch (c) {
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
                .Percent => switch (c) {
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
                .Asterisk => switch (c) {
                    '=' => {
                        result.id = .AsteriskEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Asterisk;
                        break;
                    },
                },
                .Plus => switch (c) {
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
                    else => {
                        result.id = .Plus;
                        break;
                    },
                },
                .AngleBracketLeft => switch (c) {
                    '<' => {
                        state = .AngleBracketAngleBracketLeft;
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
                .AngleBracketAngleBracketLeft => switch (c) {
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
                .AngleBracketRight => switch (c) {
                    '>' => {
                        state = .AngleBracketAngleBracketRight;
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
                .AngleBracketAngleBracketRight => switch (c) {
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
                .Caret => switch (c) {
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
                .Period => switch (c) {
                    '.' => {
                        state = .Period2;
                    },
                    '0'...'9' => {
                        state = .FloatFraction;
                    },
                    else => {
                        result.id = .Period;
                        break;
                    },
                },
                .Period2 => switch (c) {
                    '.' => {
                        result.id = .Ellipsis;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Period;
                        self.index -= 1;
                        break;
                    },
                },
                .Minus => switch (c) {
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
                    '-' => {
                        result.id = .MinusMinus;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .Minus;
                        break;
                    },
                },
                .Slash => switch (c) {
                    '/' => {
                        state = .LineComment;
                    },
                    '*' => {
                        state = .MultiLineComment;
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
                .Ampersand => switch (c) {
                    '&' => {
                        result.id = .AmpersandAmpersand;
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
                .LineComment => switch (c) {
                    '\n' => {
                        result.id = .LineComment;
                        self.index += 1;
                        break;
                    },
                    else => {},
                },
                .MultiLineComment => switch (c) {
                    '*' => {
                        state = .MultiLineCommentAsterisk;
                    },
                    else => {},
                },
                .MultiLineCommentAsterisk => switch (c) {
                    '/' => {
                        result.id = .MultiLineComment;
                        self.index += 1;
                        break;
                    },
                    else => {
                        state = .MultiLineComment;
                    },
                },
                .Zero => switch (c) {
                    '0'...'9' => {
                        state = .IntegerLiteralOct;
                    },
                    'b', 'B' => {
                        state = .IntegerLiteralBinary;
                    },
                    'x', 'X' => {
                        state = .IntegerLiteralHex;
                    },
                    else => {
                        state = .IntegerSuffix;
                        self.index -= 1;
                    },
                },
                .IntegerLiteralOct => switch (c) {
                    '0'...'7' => {},
                    else => {
                        state = .IntegerSuffix;
                        self.index -= 1;
                    },
                },
                .IntegerLiteralBinary => switch (c) {
                    '0', '1' => {},
                    else => {
                        state = .IntegerSuffix;
                        self.index -= 1;
                    },
                },
                .IntegerLiteralHex => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    '.' => {
                        state = .FloatFractionHex;
                    },
                    'p', 'P' => {
                        state = .FloatExponent;
                    },
                    else => {
                        state = .IntegerSuffix;
                        self.index -= 1;
                    },
                },
                .IntegerLiteral => switch (c) {
                    '0'...'9' => {},
                    '.' => {
                        state = .FloatFraction;
                    },
                    'e', 'E' => {
                        state = .FloatExponent;
                    },
                    else => {
                        state = .IntegerSuffix;
                        self.index -= 1;
                    },
                },
                .IntegerSuffix => switch (c) {
                    'u', 'U' => {
                        state = .IntegerSuffixU;
                    },
                    'l', 'L' => {
                        state = .IntegerSuffixL;
                    },
                    else => {
                        result.id = .IntegerLiteral;
                        break;
                    },
                },
                .IntegerSuffixU => switch (c) {
                    'l', 'L' => {
                        state = .IntegerSuffixUL;
                    },
                    else => {
                        result.id = .IntegerLiteral;
                        result.num_suffix = .U;
                        break;
                    },
                },
                .IntegerSuffixL => switch (c) {
                    'l', 'L' => {
                        state = .IntegerSuffixLL;
                    },
                    'u', 'U' => {
                        result.id = .IntegerLiteral;
                        result.num_suffix = .LU;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .IntegerLiteral;
                        result.num_suffix = .L;
                        break;
                    },
                },
                .IntegerSuffixLL => switch (c) {
                    'u', 'U' => {
                        result.id = .IntegerLiteral;
                        result.num_suffix = .LLU;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .IntegerLiteral;
                        result.num_suffix = .LL;
                        break;
                    },
                },
                .IntegerSuffixUL => switch (c) {
                    'l', 'L' => {
                        result.id = .IntegerLiteral;
                        result.num_suffix = .LLU;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .IntegerLiteral;
                        result.num_suffix = .LU;
                        break;
                    },
                },
                .FloatFraction => switch (c) {
                    '0'...'9' => {},
                    'e', 'E' => {
                        state = .FloatExponent;
                    },
                    else => {
                        self.index -= 1;
                        state = .FloatSuffix;
                    },
                },
                .FloatFractionHex => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    'p', 'P' => {
                        state = .FloatExponent;
                    },
                    else => {
                        result.id = .Invalid;
                        break;
                    },
                },
                .FloatExponent => switch (c) {
                    '+', '-' => {
                        state = .FloatExponentDigits;
                    },
                    else => {
                        self.index -= 1;
                        state = .FloatExponentDigits;
                    },
                },
                .FloatExponentDigits => switch (c) {
                    '0'...'9' => {
                        counter += 1;
                    },
                    else => {
                        if (counter == 0) {
                            result.id = .Invalid;
                            break;
                        }
                        state = .FloatSuffix;
                    },
                },
                .FloatSuffix => switch (c) {
                    'l', 'L' => {
                        result.id = .FloatLiteral;
                        result.num_suffix = .L;
                        self.index += 1;
                        break;
                    },
                    'f', 'F' => {
                        result.id = .FloatLiteral;
                        result.num_suffix = .F;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = .FloatLiteral;
                        break;
                    },
                },
            }
        } else if (self.index == self.source.buffer.len) {
            switch (state) {
                .Start => {},
                .Identifier => {
                    result.id = .Identifier;
                },

                .Cr,
                .Period2,
                .StringLiteral,
                .CharLiteral,
                .EscapeSequence,
                .OctalEscape,
                .HexEscape,
                .UnicodeEscape,
                .MultiLineComment,
                .MultiLineCommentAsterisk,
                .FloatFraction,
                .FloatFractionHex,
                .FloatExponent,
                .FloatExponentDigits,
                => result.id = .Invalid,

                .IntegerLiteralOct, .IntegerLiteralBinary, .IntegerLiteralHex, .IntegerLiteral, .IntegerSuffix, .Zero => result.id = .IntegerLiteral,
                .IntegerSuffixU => {
                    result.id = .IntegerLiteral;
                    result.num_suffix = .U;
                },
                .IntegerSuffixL => {
                    result.id = .IntegerLiteral;
                    result.num_suffix = .L;
                },
                .IntegerSuffixLL => {
                    result.id = .IntegerLiteral;
                    result.num_suffix = .LL;
                },
                .IntegerSuffixUL => {
                    result.id = .IntegerLiteral;
                    result.num_suffix = .LU;
                },

                .FloatSuffix => result.id = .FloatLiteral,
                .Equal => result.id = .Equal,
                .Bang => result.id = .Bang,
                .Minus => result.id = .Minus,
                .Slash => result.id = .Slash,
                .Ampersand => result.id = .Ampersand,
                .Period => result.id = .Period,
                .Pipe => result.id = .Pipe,
                .AngleBracketAngleBracketRight => result.id = .AngleBracketAngleBracketRight,
                .AngleBracketRight => result.id = .AngleBracketRight,
                .AngleBracketAngleBracketLeft => result.id = .AngleBracketAngleBracketLeft,
                .AngleBracketLeft => result.id = .AngleBracketLeft,
                .Plus => result.id = .Plus,
                .Percent => result.id = .Percent,
                .Caret => result.id = .Caret,
                .Asterisk => result.id = .Asterisk,
                .LineComment => result.id = .LineComment,
            }
        }

        result.end = self.index;
        return result;
    }
};

fn expectTokens(source: []const u8, expected_tokens: []const Token.Id) void {
    var tokenizer = Tokenizer{
        .source = .{
            .buffer = source,
            .file_name = undefined,
        },
    };
    for (expected_tokens) |expected_token_id| {
        const token = tokenizer.next();
        if (token.id != expected_token_id) {
            std.debug.panic("expected {}, found {}\n", .{ @tagName(expected_token_id), @tagName(token.id) });
        }
    }
    const last_token = tokenizer.next();
    std.testing.expect(last_token.id == .Eof);
}
