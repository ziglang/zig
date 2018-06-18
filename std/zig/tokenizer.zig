const std = @import("../index.zig");
const mem = std.mem;

pub const Token = struct {
    id: Id,
    start: usize,
    end: usize,

    pub const Keyword = struct {
        bytes: []const u8,
        id: Id,
    };

    pub const keywords = []Keyword{
        Keyword{ .bytes = "align", .id = Id.Keyword_align },
        Keyword{ .bytes = "and", .id = Id.Keyword_and },
        Keyword{ .bytes = "asm", .id = Id.Keyword_asm },
        Keyword{ .bytes = "async", .id = Id.Keyword_async },
        Keyword{ .bytes = "await", .id = Id.Keyword_await },
        Keyword{ .bytes = "break", .id = Id.Keyword_break },
        Keyword{ .bytes = "catch", .id = Id.Keyword_catch },
        Keyword{ .bytes = "cancel", .id = Id.Keyword_cancel },
        Keyword{ .bytes = "comptime", .id = Id.Keyword_comptime },
        Keyword{ .bytes = "const", .id = Id.Keyword_const },
        Keyword{ .bytes = "continue", .id = Id.Keyword_continue },
        Keyword{ .bytes = "defer", .id = Id.Keyword_defer },
        Keyword{ .bytes = "else", .id = Id.Keyword_else },
        Keyword{ .bytes = "enum", .id = Id.Keyword_enum },
        Keyword{ .bytes = "errdefer", .id = Id.Keyword_errdefer },
        Keyword{ .bytes = "error", .id = Id.Keyword_error },
        Keyword{ .bytes = "export", .id = Id.Keyword_export },
        Keyword{ .bytes = "extern", .id = Id.Keyword_extern },
        Keyword{ .bytes = "false", .id = Id.Keyword_false },
        Keyword{ .bytes = "fn", .id = Id.Keyword_fn },
        Keyword{ .bytes = "for", .id = Id.Keyword_for },
        Keyword{ .bytes = "if", .id = Id.Keyword_if },
        Keyword{ .bytes = "inline", .id = Id.Keyword_inline },
        Keyword{ .bytes = "nakedcc", .id = Id.Keyword_nakedcc },
        Keyword{ .bytes = "noalias", .id = Id.Keyword_noalias },
        Keyword{ .bytes = "null", .id = Id.Keyword_null },
        Keyword{ .bytes = "or", .id = Id.Keyword_or },
        Keyword{ .bytes = "orelse", .id = Id.Keyword_orelse },
        Keyword{ .bytes = "packed", .id = Id.Keyword_packed },
        Keyword{ .bytes = "promise", .id = Id.Keyword_promise },
        Keyword{ .bytes = "pub", .id = Id.Keyword_pub },
        Keyword{ .bytes = "resume", .id = Id.Keyword_resume },
        Keyword{ .bytes = "return", .id = Id.Keyword_return },
        Keyword{ .bytes = "section", .id = Id.Keyword_section },
        Keyword{ .bytes = "stdcallcc", .id = Id.Keyword_stdcallcc },
        Keyword{ .bytes = "struct", .id = Id.Keyword_struct },
        Keyword{ .bytes = "suspend", .id = Id.Keyword_suspend },
        Keyword{ .bytes = "switch", .id = Id.Keyword_switch },
        Keyword{ .bytes = "test", .id = Id.Keyword_test },
        Keyword{ .bytes = "this", .id = Id.Keyword_this },
        Keyword{ .bytes = "true", .id = Id.Keyword_true },
        Keyword{ .bytes = "try", .id = Id.Keyword_try },
        Keyword{ .bytes = "undefined", .id = Id.Keyword_undefined },
        Keyword{ .bytes = "union", .id = Id.Keyword_union },
        Keyword{ .bytes = "unreachable", .id = Id.Keyword_unreachable },
        Keyword{ .bytes = "use", .id = Id.Keyword_use },
        Keyword{ .bytes = "var", .id = Id.Keyword_var },
        Keyword{ .bytes = "volatile", .id = Id.Keyword_volatile },
        Keyword{ .bytes = "while", .id = Id.Keyword_while },
    };

    // TODO perfect hash at comptime
    fn getKeyword(bytes: []const u8) ?Id {
        for (keywords) |kw| {
            if (mem.eql(u8, kw.bytes, bytes)) {
                return kw.id;
            }
        }
        return null;
    }

    const StrLitKind = enum {
        Normal,
        C,
    };

    pub const Id = union(enum) {
        Invalid,
        Identifier,
        StringLiteral: StrLitKind,
        MultilineStringLiteralLine: StrLitKind,
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
        BracketStarBracket,
        Keyword_align,
        Keyword_and,
        Keyword_asm,
        Keyword_async,
        Keyword_await,
        Keyword_break,
        Keyword_cancel,
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
        Keyword_nakedcc,
        Keyword_noalias,
        Keyword_null,
        Keyword_or,
        Keyword_orelse,
        Keyword_packed,
        Keyword_promise,
        Keyword_pub,
        Keyword_resume,
        Keyword_return,
        Keyword_section,
        Keyword_stdcallcc,
        Keyword_struct,
        Keyword_suspend,
        Keyword_switch,
        Keyword_test,
        Keyword_this,
        Keyword_true,
        Keyword_try,
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
    pending_invalid_token: ?Token,

    /// For debugging purposes
    pub fn dump(self: *Tokenizer, token: *const Token) void {
        std.debug.warn("{} \"{}\"\n", @tagName(token.id), self.buffer[token.start..token.end]);
    }

    pub fn init(buffer: []const u8) Tokenizer {
        return Tokenizer{
            .buffer = buffer,
            .index = 0,
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
        MultilineStringLiteralLine,
        CharLiteral,
        CharLiteralBackslash,
        CharLiteralEscape1,
        CharLiteralEscape2,
        CharLiteralEnd,
        Backslash,
        Equal,
        Bang,
        Pipe,
        Minus,
        MinusPercent,
        Asterisk,
        AsteriskPercent,
        Slash,
        LineCommentStart,
        LineComment,
        DocCommentStart,
        DocComment,
        Zero,
        IntegerLiteral,
        IntegerLiteralWithRadix,
        IntegerLiteralWithRadixHex,
        NumberDot,
        NumberDotHex,
        FloatFraction,
        FloatFractionHex,
        FloatExponentUnsigned,
        FloatExponentUnsignedHex,
        FloatExponentNumber,
        FloatExponentNumberHex,
        Ampersand,
        Caret,
        Percent,
        Plus,
        PlusPercent,
        AngleBracketLeft,
        AngleBracketAngleBracketLeft,
        AngleBracketRight,
        AngleBracketAngleBracketRight,
        Period,
        Period2,
        SawAtSign,
        LBracket,
        LBracketStar,
    };

    pub fn next(self: *Tokenizer) Token {
        if (self.pending_invalid_token) |token| {
            self.pending_invalid_token = null;
            return token;
        }
        const start_index = self.index;
        var state = State.Start;
        var result = Token{
            .id = Token.Id.Eof,
            .start = self.index,
            .end = undefined,
        };
        while (self.index < self.buffer.len) : (self.index += 1) {
            const c = self.buffer[self.index];
            switch (state) {
                State.Start => switch (c) {
                    ' ' => {
                        result.start = self.index + 1;
                    },
                    '\n' => {
                        result.start = self.index + 1;
                    },
                    'c' => {
                        state = State.C;
                        result.id = Token.Id.Identifier;
                    },
                    '"' => {
                        state = State.StringLiteral;
                        result.id = Token.Id{ .StringLiteral = Token.StrLitKind.Normal };
                    },
                    '\'' => {
                        state = State.CharLiteral;
                    },
                    'a'...'b', 'd'...'z', 'A'...'Z', '_' => {
                        state = State.Identifier;
                        result.id = Token.Id.Identifier;
                    },
                    '@' => {
                        state = State.SawAtSign;
                    },
                    '=' => {
                        state = State.Equal;
                    },
                    '!' => {
                        state = State.Bang;
                    },
                    '|' => {
                        state = State.Pipe;
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
                    '[' => {
                        state = State.LBracket;
                    },
                    ']' => {
                        result.id = Token.Id.RBracket;
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
                    '?' => {
                        result.id = Token.Id.QuestionMark;
                        self.index += 1;
                        break;
                    },
                    ':' => {
                        result.id = Token.Id.Colon;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = State.Percent;
                    },
                    '*' => {
                        state = State.Asterisk;
                    },
                    '+' => {
                        state = State.Plus;
                    },
                    '<' => {
                        state = State.AngleBracketLeft;
                    },
                    '>' => {
                        state = State.AngleBracketRight;
                    },
                    '^' => {
                        state = State.Caret;
                    },
                    '\\' => {
                        state = State.Backslash;
                        result.id = Token.Id{ .MultilineStringLiteralLine = Token.StrLitKind.Normal };
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
                    '~' => {
                        result.id = Token.Id.Tilde;
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

                State.SawAtSign => switch (c) {
                    '"' => {
                        result.id = Token.Id.Identifier;
                        state = State.StringLiteral;
                    },
                    else => {
                        // reinterpret as a builtin
                        self.index -= 1;
                        state = State.Builtin;
                        result.id = Token.Id.Builtin;
                    },
                },

                State.LBracket => switch (c) {
                    '*' => {
                        state = State.LBracketStar;
                    },
                    else => {
                        result.id = Token.Id.LBracket;
                        break;
                    },
                },

                State.LBracketStar => switch (c) {
                    ']' => {
                        result.id = Token.Id.BracketStarBracket;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Invalid;
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

                State.Asterisk => switch (c) {
                    '=' => {
                        result.id = Token.Id.AsteriskEqual;
                        self.index += 1;
                        break;
                    },
                    '*' => {
                        result.id = Token.Id.AsteriskAsterisk;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = State.AsteriskPercent;
                    },
                    else => {
                        result.id = Token.Id.Asterisk;
                        break;
                    },
                },

                State.AsteriskPercent => switch (c) {
                    '=' => {
                        result.id = Token.Id.AsteriskPercentEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.AsteriskPercent;
                        break;
                    },
                },

                State.Percent => switch (c) {
                    '=' => {
                        result.id = Token.Id.PercentEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Percent;
                        break;
                    },
                },

                State.Plus => switch (c) {
                    '=' => {
                        result.id = Token.Id.PlusEqual;
                        self.index += 1;
                        break;
                    },
                    '+' => {
                        result.id = Token.Id.PlusPlus;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = State.PlusPercent;
                    },
                    else => {
                        result.id = Token.Id.Plus;
                        break;
                    },
                },

                State.PlusPercent => switch (c) {
                    '=' => {
                        result.id = Token.Id.PlusPercentEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.PlusPercent;
                        break;
                    },
                },

                State.Caret => switch (c) {
                    '=' => {
                        result.id = Token.Id.CaretEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Caret;
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
                State.Backslash => switch (c) {
                    '\\' => {
                        state = State.MultilineStringLiteralLine;
                    },
                    else => break,
                },
                State.C => switch (c) {
                    '\\' => {
                        state = State.Backslash;
                        result.id = Token.Id{ .MultilineStringLiteralLine = Token.StrLitKind.C };
                    },
                    '"' => {
                        state = State.StringLiteral;
                        result.id = Token.Id{ .StringLiteral = Token.StrLitKind.C };
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

                State.CharLiteral => switch (c) {
                    '\\' => {
                        state = State.CharLiteralBackslash;
                    },
                    '\'' => {
                        result.id = Token.Id.Invalid;
                        break;
                    },
                    else => {
                        if (c < 0x20 or c == 0x7f) {
                            result.id = Token.Id.Invalid;
                            break;
                        }

                        state = State.CharLiteralEnd;
                    },
                },

                State.CharLiteralBackslash => switch (c) {
                    '\n' => {
                        result.id = Token.Id.Invalid;
                        break;
                    },
                    'x' => {
                        state = State.CharLiteralEscape1;
                    },
                    else => {
                        state = State.CharLiteralEnd;
                    },
                },

                State.CharLiteralEscape1 => switch (c) {
                    '0'...'9', 'a'...'z', 'A'...'F' => {
                        state = State.CharLiteralEscape2;
                    },
                    else => {
                        result.id = Token.Id.Invalid;
                        break;
                    },
                },

                State.CharLiteralEscape2 => switch (c) {
                    '0'...'9', 'a'...'z', 'A'...'F' => {
                        state = State.CharLiteralEnd;
                    },
                    else => {
                        result.id = Token.Id.Invalid;
                        break;
                    },
                },

                State.CharLiteralEnd => switch (c) {
                    '\'' => {
                        result.id = Token.Id.CharLiteral;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Invalid;
                        break;
                    },
                },

                State.MultilineStringLiteralLine => switch (c) {
                    '\n' => {
                        self.index += 1;
                        break;
                    },
                    else => self.checkLiteralCharacter(),
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

                State.Pipe => switch (c) {
                    '=' => {
                        result.id = Token.Id.PipeEqual;
                        self.index += 1;
                        break;
                    },
                    '|' => {
                        result.id = Token.Id.PipePipe;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Pipe;
                        break;
                    },
                },

                State.Equal => switch (c) {
                    '=' => {
                        result.id = Token.Id.EqualEqual;
                        self.index += 1;
                        break;
                    },
                    '>' => {
                        result.id = Token.Id.EqualAngleBracketRight;
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
                    '=' => {
                        result.id = Token.Id.MinusEqual;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        state = State.MinusPercent;
                    },
                    else => {
                        result.id = Token.Id.Minus;
                        break;
                    },
                },

                State.MinusPercent => switch (c) {
                    '=' => {
                        result.id = Token.Id.MinusPercentEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.MinusPercent;
                        break;
                    },
                },

                State.AngleBracketLeft => switch (c) {
                    '<' => {
                        state = State.AngleBracketAngleBracketLeft;
                    },
                    '=' => {
                        result.id = Token.Id.AngleBracketLeftEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.AngleBracketLeft;
                        break;
                    },
                },

                State.AngleBracketAngleBracketLeft => switch (c) {
                    '=' => {
                        result.id = Token.Id.AngleBracketAngleBracketLeftEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.AngleBracketAngleBracketLeft;
                        break;
                    },
                },

                State.AngleBracketRight => switch (c) {
                    '>' => {
                        state = State.AngleBracketAngleBracketRight;
                    },
                    '=' => {
                        result.id = Token.Id.AngleBracketRightEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.AngleBracketRight;
                        break;
                    },
                },

                State.AngleBracketAngleBracketRight => switch (c) {
                    '=' => {
                        result.id = Token.Id.AngleBracketAngleBracketRightEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.AngleBracketAngleBracketRight;
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
                        state = State.LineCommentStart;
                        result.id = Token.Id.LineComment;
                    },
                    '=' => {
                        result.id = Token.Id.SlashEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Slash;
                        break;
                    },
                },
                State.LineCommentStart => switch (c) {
                    '/' => {
                        state = State.DocCommentStart;
                    },
                    '\n' => break,
                    else => {
                        state = State.LineComment;
                        self.checkLiteralCharacter();
                    },
                },
                State.DocCommentStart => switch (c) {
                    '/' => {
                        state = State.LineComment;
                    },
                    '\n' => {
                        result.id = Token.Id.DocComment;
                        break;
                    },
                    else => {
                        state = State.DocComment;
                        result.id = Token.Id.DocComment;
                        self.checkLiteralCharacter();
                    },
                },
                State.LineComment, State.DocComment => switch (c) {
                    '\n' => break,
                    else => self.checkLiteralCharacter(),
                },
                State.Zero => switch (c) {
                    'b', 'o' => {
                        state = State.IntegerLiteralWithRadix;
                    },
                    'x' => {
                        state = State.IntegerLiteralWithRadixHex;
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
                    '0'...'9' => {},
                    else => break,
                },
                State.IntegerLiteralWithRadix => switch (c) {
                    '.' => {
                        state = State.NumberDot;
                    },
                    '0'...'9' => {},
                    else => break,
                },
                State.IntegerLiteralWithRadixHex => switch (c) {
                    '.' => {
                        state = State.NumberDotHex;
                    },
                    'p', 'P' => {
                        state = State.FloatExponentUnsignedHex;
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
                State.NumberDotHex => switch (c) {
                    '.' => {
                        self.index -= 1;
                        state = State.Start;
                        break;
                    },
                    else => {
                        self.index -= 1;
                        result.id = Token.Id.FloatLiteral;
                        state = State.FloatFractionHex;
                    },
                },
                State.FloatFraction => switch (c) {
                    'e', 'E' => {
                        state = State.FloatExponentUnsigned;
                    },
                    '0'...'9' => {},
                    else => break,
                },
                State.FloatFractionHex => switch (c) {
                    'p', 'P' => {
                        state = State.FloatExponentUnsignedHex;
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
                    },
                },
                State.FloatExponentUnsignedHex => switch (c) {
                    '+', '-' => {
                        state = State.FloatExponentNumberHex;
                    },
                    else => {
                        // reinterpret as a normal exponent number
                        self.index -= 1;
                        state = State.FloatExponentNumberHex;
                    },
                },
                State.FloatExponentNumber => switch (c) {
                    '0'...'9' => {},
                    else => break,
                },
                State.FloatExponentNumberHex => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    else => break,
                },
            }
        } else if (self.index == self.buffer.len) {
            switch (state) {
                State.Start,
                State.C,
                State.IntegerLiteral,
                State.IntegerLiteralWithRadix,
                State.IntegerLiteralWithRadixHex,
                State.FloatFraction,
                State.FloatFractionHex,
                State.FloatExponentNumber,
                State.FloatExponentNumberHex,
                State.StringLiteral, // find this error later
                State.MultilineStringLiteralLine,
                State.Builtin,
                => {},

                State.Identifier => {
                    if (Token.getKeyword(self.buffer[result.start..self.index])) |id| {
                        result.id = id;
                    }
                },
                State.LineCommentStart, State.LineComment => {
                    result.id = Token.Id.LineComment;
                },
                State.DocComment, State.DocCommentStart => {
                    result.id = Token.Id.DocComment;
                },

                State.NumberDot,
                State.NumberDotHex,
                State.FloatExponentUnsigned,
                State.FloatExponentUnsignedHex,
                State.SawAtSign,
                State.Backslash,
                State.CharLiteral,
                State.CharLiteralBackslash,
                State.CharLiteralEscape1,
                State.CharLiteralEscape2,
                State.CharLiteralEnd,
                State.StringLiteralBackslash,
                State.LBracketStar,
                => {
                    result.id = Token.Id.Invalid;
                },

                State.Equal => {
                    result.id = Token.Id.Equal;
                },
                State.Bang => {
                    result.id = Token.Id.Bang;
                },
                State.Minus => {
                    result.id = Token.Id.Minus;
                },
                State.Slash => {
                    result.id = Token.Id.Slash;
                },
                State.LBracket => {
                    result.id = Token.Id.LBracket;
                },
                State.Zero => {
                    result.id = Token.Id.IntegerLiteral;
                },
                State.Ampersand => {
                    result.id = Token.Id.Ampersand;
                },
                State.Period => {
                    result.id = Token.Id.Period;
                },
                State.Period2 => {
                    result.id = Token.Id.Ellipsis2;
                },
                State.Pipe => {
                    result.id = Token.Id.Pipe;
                },
                State.AngleBracketAngleBracketRight => {
                    result.id = Token.Id.AngleBracketAngleBracketRight;
                },
                State.AngleBracketRight => {
                    result.id = Token.Id.AngleBracketRight;
                },
                State.AngleBracketAngleBracketLeft => {
                    result.id = Token.Id.AngleBracketAngleBracketLeft;
                },
                State.AngleBracketLeft => {
                    result.id = Token.Id.AngleBracketLeft;
                },
                State.PlusPercent => {
                    result.id = Token.Id.PlusPercent;
                },
                State.Plus => {
                    result.id = Token.Id.Plus;
                },
                State.Percent => {
                    result.id = Token.Id.Percent;
                },
                State.Caret => {
                    result.id = Token.Id.Caret;
                },
                State.AsteriskPercent => {
                    result.id = Token.Id.AsteriskPercent;
                },
                State.Asterisk => {
                    result.id = Token.Id.Asterisk;
                },
                State.MinusPercent => {
                    result.id = Token.Id.MinusPercent;
                },
            }
        }

        if (result.id == Token.Id.Eof) {
            if (self.pending_invalid_token) |token| {
                self.pending_invalid_token = null;
                return token;
            }
        }

        result.end = self.index;
        return result;
    }

    fn checkLiteralCharacter(self: *Tokenizer) void {
        if (self.pending_invalid_token != null) return;
        const invalid_length = self.getInvalidCharacterLength();
        if (invalid_length == 0) return;
        self.pending_invalid_token = Token{
            .id = Token.Id.Invalid,
            .start = self.index,
            .end = self.index + invalid_length,
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
    testTokenize("test", []Token.Id{Token.Id.Keyword_test});
}

test "tokenizer - unknown length pointer" {
    testTokenize(
        \\[*]u8
    , []Token.Id{
        Token.Id.BracketStarBracket,
        Token.Id.Identifier,
    });
}

test "tokenizer - char literal with hex escape" {
    testTokenize(
        \\'\x1b'
    , []Token.Id{Token.Id.CharLiteral});
}

test "tokenizer - float literal e exponent" {
    testTokenize("a = 4.94065645841246544177e-324;\n", []Token.Id{
        Token.Id.Identifier,
        Token.Id.Equal,
        Token.Id.FloatLiteral,
        Token.Id.Semicolon,
    });
}

test "tokenizer - float literal p exponent" {
    testTokenize("a = 0x1.a827999fcef32p+1022;\n", []Token.Id{
        Token.Id.Identifier,
        Token.Id.Equal,
        Token.Id.FloatLiteral,
        Token.Id.Semicolon,
    });
}

test "tokenizer - chars" {
    testTokenize("'c'", []Token.Id{Token.Id.CharLiteral});
}

test "tokenizer - invalid token characters" {
    testTokenize("#", []Token.Id{Token.Id.Invalid});
    testTokenize("`", []Token.Id{Token.Id.Invalid});
    testTokenize("'c", []Token.Id{Token.Id.Invalid});
    testTokenize("'", []Token.Id{Token.Id.Invalid});
    testTokenize("''", []Token.Id{ Token.Id.Invalid, Token.Id.Invalid });
}

test "tokenizer - invalid literal/comment characters" {
    testTokenize("\"\x00\"", []Token.Id{
        Token.Id{ .StringLiteral = Token.StrLitKind.Normal },
        Token.Id.Invalid,
    });
    testTokenize("//\x00", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\x1f", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\x7f", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
}

test "tokenizer - utf8" {
    testTokenize("//\xc2\x80", []Token.Id{Token.Id.LineComment});
    testTokenize("//\xf4\x8f\xbf\xbf", []Token.Id{Token.Id.LineComment});
}

test "tokenizer - invalid utf8" {
    testTokenize("//\x80", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xbf", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xf8", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xff", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xc2\xc0", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xe0", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xf0", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xf0\x90\x80\xc0", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
}

test "tokenizer - illegal unicode codepoints" {
    // unicode newline characters.U+0085, U+2028, U+2029
    testTokenize("//\xc2\x84", []Token.Id{Token.Id.LineComment});
    testTokenize("//\xc2\x85", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xc2\x86", []Token.Id{Token.Id.LineComment});
    testTokenize("//\xe2\x80\xa7", []Token.Id{Token.Id.LineComment});
    testTokenize("//\xe2\x80\xa8", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xe2\x80\xa9", []Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xe2\x80\xaa", []Token.Id{Token.Id.LineComment});
}

test "tokenizer - string identifier and builtin fns" {
    testTokenize(
        \\const @"if" = @import("std");
    , []Token.Id{
        Token.Id.Keyword_const,
        Token.Id.Identifier,
        Token.Id.Equal,
        Token.Id.Builtin,
        Token.Id.LParen,
        Token.Id{ .StringLiteral = Token.StrLitKind.Normal },
        Token.Id.RParen,
        Token.Id.Semicolon,
    });
}

test "tokenizer - pipe and then invalid" {
    testTokenize("||=", []Token.Id{
        Token.Id.PipePipe,
        Token.Id.Equal,
    });
}

test "tokenizer - line comment and doc comment" {
    testTokenize("//", []Token.Id{Token.Id.LineComment});
    testTokenize("// a / b", []Token.Id{Token.Id.LineComment});
    testTokenize("// /", []Token.Id{Token.Id.LineComment});
    testTokenize("/// a", []Token.Id{Token.Id.DocComment});
    testTokenize("///", []Token.Id{Token.Id.DocComment});
    testTokenize("////", []Token.Id{Token.Id.LineComment});
}

test "tokenizer - line comment followed by identifier" {
    testTokenize(
        \\    Unexpected,
        \\    // another
        \\    Another,
    , []Token.Id{
        Token.Id.Identifier,
        Token.Id.Comma,
        Token.Id.LineComment,
        Token.Id.Identifier,
        Token.Id.Comma,
    });
}

fn testTokenize(source: []const u8, expected_tokens: []const Token.Id) void {
    var tokenizer = Tokenizer.init(source);
    for (expected_tokens) |expected_token_id| {
        const token = tokenizer.next();
        if (@TagType(Token.Id)(token.id) != @TagType(Token.Id)(expected_token_id)) {
            std.debug.panic("expected {}, found {}\n", @tagName(@TagType(Token.Id)(expected_token_id)), @tagName(@TagType(Token.Id)(token.id)));
        }
        switch (expected_token_id) {
            Token.Id.StringLiteral => |expected_kind| {
                std.debug.assert(expected_kind == switch (token.id) {
                    Token.Id.StringLiteral => |kind| kind,
                    else => unreachable,
                });
            },
            else => {},
        }
    }
    const last_token = tokenizer.next();
    std.debug.assert(last_token.id == Token.Id.Eof);
}
