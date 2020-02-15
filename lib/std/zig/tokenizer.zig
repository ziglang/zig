const std = @import("../std.zig");
const mem = std.mem;

pub const Token = struct {
    id: Id,
    start: usize,
    end: usize,

    pub const Keyword = struct {
        bytes: []const u8,
        id: Id,
        hash: u32,

        fn init(bytes: []const u8, id: Id) Keyword {
            @setEvalBranchQuota(2000);
            return .{
                .bytes = bytes,
                .id = id,
                .hash = std.hash_map.hashString(bytes),
            };
        }
    };

    pub const keywords = [_]Keyword{
        Keyword.init("align", .Keyword_align),
        Keyword.init("allowzero", .Keyword_allowzero),
        Keyword.init("and", .Keyword_and),
        Keyword.init("anyframe", .Keyword_anyframe),
        Keyword.init("asm", .Keyword_asm),
        Keyword.init("async", .Keyword_async),
        Keyword.init("await", .Keyword_await),
        Keyword.init("break", .Keyword_break),
        Keyword.init("callconv", .Keyword_callconv),
        Keyword.init("catch", .Keyword_catch),
        Keyword.init("comptime", .Keyword_comptime),
        Keyword.init("const", .Keyword_const),
        Keyword.init("continue", .Keyword_continue),
        Keyword.init("defer", .Keyword_defer),
        Keyword.init("else", .Keyword_else),
        Keyword.init("enum", .Keyword_enum),
        Keyword.init("errdefer", .Keyword_errdefer),
        Keyword.init("error", .Keyword_error),
        Keyword.init("export", .Keyword_export),
        Keyword.init("extern", .Keyword_extern),
        Keyword.init("false", .Keyword_false),
        Keyword.init("fn", .Keyword_fn),
        Keyword.init("for", .Keyword_for),
        Keyword.init("if", .Keyword_if),
        Keyword.init("inline", .Keyword_inline),
        Keyword.init("nakedcc", .Keyword_nakedcc),
        Keyword.init("noalias", .Keyword_noalias),
        Keyword.init("noasync", .Keyword_noasync),
        Keyword.init("noinline", .Keyword_noinline),
        Keyword.init("null", .Keyword_null),
        Keyword.init("or", .Keyword_or),
        Keyword.init("orelse", .Keyword_orelse),
        Keyword.init("packed", .Keyword_packed),
        Keyword.init("pub", .Keyword_pub),
        Keyword.init("resume", .Keyword_resume),
        Keyword.init("return", .Keyword_return),
        Keyword.init("linksection", .Keyword_linksection),
        Keyword.init("stdcallcc", .Keyword_stdcallcc),
        Keyword.init("struct", .Keyword_struct),
        Keyword.init("suspend", .Keyword_suspend),
        Keyword.init("switch", .Keyword_switch),
        Keyword.init("test", .Keyword_test),
        Keyword.init("threadlocal", .Keyword_threadlocal),
        Keyword.init("true", .Keyword_true),
        Keyword.init("try", .Keyword_try),
        Keyword.init("undefined", .Keyword_undefined),
        Keyword.init("union", .Keyword_union),
        Keyword.init("unreachable", .Keyword_unreachable),
        Keyword.init("usingnamespace", .Keyword_usingnamespace),
        Keyword.init("var", .Keyword_var),
        Keyword.init("volatile", .Keyword_volatile),
        Keyword.init("while", .Keyword_while),
    };

    // TODO perfect hash at comptime
    pub fn getKeyword(bytes: []const u8) ?Id {
        var hash = std.hash_map.hashString(bytes);
        for (keywords) |kw| {
            if (kw.hash == hash and mem.eql(u8, kw.bytes, bytes)) {
                return kw.id;
            }
        }
        return null;
    }

    pub const Id = enum {
        Invalid,
        Invalid_ampersands,
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
        Keyword_nakedcc,
        Keyword_noalias,
        Keyword_noasync,
        Keyword_noinline,
        Keyword_null,
        Keyword_or,
        Keyword_orelse,
        Keyword_packed,
        Keyword_anyframe,
        Keyword_pub,
        Keyword_resume,
        Keyword_return,
        Keyword_linksection,
        Keyword_stdcallcc,
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
                .Keyword_nakedcc => "nakedcc",
                .Keyword_noalias => "noalias",
                .Keyword_noasync => "noasync",
                .Keyword_noinline => "noinline",
                .Keyword_null => "null",
                .Keyword_or => "or",
                .Keyword_orelse => "orelse",
                .Keyword_packed => "packed",
                .Keyword_pub => "pub",
                .Keyword_resume => "resume",
                .Keyword_return => "return",
                .Keyword_linksection => "linksection",
                .Keyword_stdcallcc => "stdcallcc",
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
        Start,
        Identifier,
        Builtin,
        StringLiteral,
        StringLiteralBackslash,
        MultilineStringLiteralLine,
        CharLiteral,
        CharLiteralBackslash,
        CharLiteralHexEscape,
        CharLiteralUnicodeEscapeSawU,
        CharLiteralUnicodeEscape,
        CharLiteralUnicodeInvalid,
        CharLiteralUnicode,
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
        ContainerDocComment,
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
        var seen_escape_digits: usize = undefined;
        var remaining_code_units: usize = undefined;
        while (self.index < self.buffer.len) : (self.index += 1) {
            const c = self.buffer[self.index];
            switch (state) {
                State.Start => switch (c) {
                    ' ', '\n', '\t', '\r' => {
                        result.start = self.index + 1;
                    },
                    '"' => {
                        state = State.StringLiteral;
                        result.id = Token.Id.StringLiteral;
                    },
                    '\'' => {
                        state = State.CharLiteral;
                    },
                    'a'...'z', 'A'...'Z', '_' => {
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
                        result.id = .LBracket;
                        self.index += 1;
                        break;
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
                        result.id = Token.Id.MultilineStringLiteralLine;
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

                State.Ampersand => switch (c) {
                    '&' => {
                        result.id = Token.Id.Invalid_ampersands;
                        self.index += 1;
                        break;
                    },
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
                State.StringLiteral => switch (c) {
                    '\\' => {
                        state = State.StringLiteralBackslash;
                    },
                    '"' => {
                        self.index += 1;
                        break;
                    },
                    '\n', '\r' => break, // Look for this error later.
                    else => self.checkLiteralCharacter(),
                },

                State.StringLiteralBackslash => switch (c) {
                    '\n', '\r' => break, // Look for this error later.
                    else => {
                        state = State.StringLiteral;
                    },
                },

                State.CharLiteral => switch (c) {
                    '\\' => {
                        state = State.CharLiteralBackslash;
                    },
                    '\'', 0x80...0xbf, 0xf8...0xff => {
                        result.id = Token.Id.Invalid;
                        break;
                    },
                    0xc0...0xdf => { // 110xxxxx
                        remaining_code_units = 1;
                        state = State.CharLiteralUnicode;
                    },
                    0xe0...0xef => { // 1110xxxx
                        remaining_code_units = 2;
                        state = State.CharLiteralUnicode;
                    },
                    0xf0...0xf7 => { // 11110xxx
                        remaining_code_units = 3;
                        state = State.CharLiteralUnicode;
                    },
                    else => {
                        state = State.CharLiteralEnd;
                    },
                },

                State.CharLiteralBackslash => switch (c) {
                    '\n' => {
                        result.id = Token.Id.Invalid;
                        break;
                    },
                    'x' => {
                        state = State.CharLiteralHexEscape;
                        seen_escape_digits = 0;
                    },
                    'u' => {
                        state = State.CharLiteralUnicodeEscapeSawU;
                    },
                    else => {
                        state = State.CharLiteralEnd;
                    },
                },

                State.CharLiteralHexEscape => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        seen_escape_digits += 1;
                        if (seen_escape_digits == 2) {
                            state = State.CharLiteralEnd;
                        }
                    },
                    else => {
                        result.id = Token.Id.Invalid;
                        break;
                    },
                },

                State.CharLiteralUnicodeEscapeSawU => switch (c) {
                    '{' => {
                        state = State.CharLiteralUnicodeEscape;
                        seen_escape_digits = 0;
                    },
                    else => {
                        result.id = Token.Id.Invalid;
                        state = State.CharLiteralUnicodeInvalid;
                    },
                },

                State.CharLiteralUnicodeEscape => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {
                        seen_escape_digits += 1;
                    },
                    '}' => {
                        if (seen_escape_digits == 0) {
                            result.id = Token.Id.Invalid;
                            state = State.CharLiteralUnicodeInvalid;
                        } else {
                            state = State.CharLiteralEnd;
                        }
                    },
                    else => {
                        result.id = Token.Id.Invalid;
                        state = State.CharLiteralUnicodeInvalid;
                    },
                },

                State.CharLiteralUnicodeInvalid => switch (c) {
                    // Keep consuming characters until an obvious stopping point.
                    // This consolidates e.g. `u{0ab1Q}` into a single invalid token
                    // instead of creating the tokens `u{0ab1`, `Q`, `}`
                    '0'...'9', 'a'...'z', 'A'...'Z', '}' => {},
                    else => break,
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

                State.CharLiteralUnicode => switch (c) {
                    0x80...0xbf => {
                        remaining_code_units -= 1;
                        if (remaining_code_units == 0) {
                            state = State.CharLiteralEnd;
                        }
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
                    '*' => {
                        result.id = Token.Id.PeriodAsterisk;
                        self.index += 1;
                        break;
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
                    '!' => {
                        result.id = Token.Id.ContainerDocComment;
                        state = State.ContainerDocComment;
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
                State.LineComment, State.DocComment, State.ContainerDocComment => switch (c) {
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
                State.ContainerDocComment => {
                    result.id = Token.Id.ContainerDocComment;
                },

                State.NumberDot,
                State.NumberDotHex,
                State.FloatExponentUnsigned,
                State.FloatExponentUnsignedHex,
                State.SawAtSign,
                State.Backslash,
                State.CharLiteral,
                State.CharLiteralBackslash,
                State.CharLiteralHexEscape,
                State.CharLiteralUnicodeEscapeSawU,
                State.CharLiteralUnicodeEscape,
                State.CharLiteralUnicodeInvalid,
                State.CharLiteralEnd,
                State.CharLiteralUnicode,
                State.StringLiteralBackslash,
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
    testTokenize("test", &[_]Token.Id{Token.Id.Keyword_test});
}

test "tokenizer - unknown length pointer and then c pointer" {
    testTokenize(
        \\[*]u8
        \\[*c]u8
    , &[_]Token.Id{
        Token.Id.LBracket,
        Token.Id.Asterisk,
        Token.Id.RBracket,
        Token.Id.Identifier,
        Token.Id.LBracket,
        Token.Id.Asterisk,
        Token.Id.Identifier,
        Token.Id.RBracket,
        Token.Id.Identifier,
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
        Token.Id.Identifier,
        Token.Id.Equal,
        Token.Id.FloatLiteral,
        Token.Id.Semicolon,
    });
}

test "tokenizer - float literal p exponent" {
    testTokenize("a = 0x1.a827999fcef32p+1022;\n", &[_]Token.Id{
        Token.Id.Identifier,
        Token.Id.Equal,
        Token.Id.FloatLiteral,
        Token.Id.Semicolon,
    });
}

test "tokenizer - chars" {
    testTokenize("'c'", &[_]Token.Id{Token.Id.CharLiteral});
}

test "tokenizer - invalid token characters" {
    testTokenize("#", &[_]Token.Id{Token.Id.Invalid});
    testTokenize("`", &[_]Token.Id{Token.Id.Invalid});
    testTokenize("'c", &[_]Token.Id{Token.Id.Invalid});
    testTokenize("'", &[_]Token.Id{Token.Id.Invalid});
    testTokenize("''", &[_]Token.Id{ Token.Id.Invalid, Token.Id.Invalid });
}

test "tokenizer - invalid literal/comment characters" {
    testTokenize("\"\x00\"", &[_]Token.Id{
        Token.Id.StringLiteral,
        Token.Id.Invalid,
    });
    testTokenize("//\x00", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\x1f", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\x7f", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
}

test "tokenizer - utf8" {
    testTokenize("//\xc2\x80", &[_]Token.Id{Token.Id.LineComment});
    testTokenize("//\xf4\x8f\xbf\xbf", &[_]Token.Id{Token.Id.LineComment});
}

test "tokenizer - invalid utf8" {
    testTokenize("//\x80", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xbf", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xf8", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xff", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xc2\xc0", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xe0", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xf0", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xf0\x90\x80\xc0", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
}

test "tokenizer - illegal unicode codepoints" {
    // unicode newline characters.U+0085, U+2028, U+2029
    testTokenize("//\xc2\x84", &[_]Token.Id{Token.Id.LineComment});
    testTokenize("//\xc2\x85", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xc2\x86", &[_]Token.Id{Token.Id.LineComment});
    testTokenize("//\xe2\x80\xa7", &[_]Token.Id{Token.Id.LineComment});
    testTokenize("//\xe2\x80\xa8", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xe2\x80\xa9", &[_]Token.Id{
        Token.Id.LineComment,
        Token.Id.Invalid,
    });
    testTokenize("//\xe2\x80\xaa", &[_]Token.Id{Token.Id.LineComment});
}

test "tokenizer - string identifier and builtin fns" {
    testTokenize(
        \\const @"if" = @import("std");
    , &[_]Token.Id{
        Token.Id.Keyword_const,
        Token.Id.Identifier,
        Token.Id.Equal,
        Token.Id.Builtin,
        Token.Id.LParen,
        Token.Id.StringLiteral,
        Token.Id.RParen,
        Token.Id.Semicolon,
    });
}

test "tokenizer - pipe and then invalid" {
    testTokenize("||=", &[_]Token.Id{
        Token.Id.PipePipe,
        Token.Id.Equal,
    });
}

test "tokenizer - line comment and doc comment" {
    testTokenize("//", &[_]Token.Id{Token.Id.LineComment});
    testTokenize("// a / b", &[_]Token.Id{Token.Id.LineComment});
    testTokenize("// /", &[_]Token.Id{Token.Id.LineComment});
    testTokenize("/// a", &[_]Token.Id{Token.Id.DocComment});
    testTokenize("///", &[_]Token.Id{Token.Id.DocComment});
    testTokenize("////", &[_]Token.Id{Token.Id.LineComment});
    testTokenize("//!", &[_]Token.Id{Token.Id.ContainerDocComment});
    testTokenize("//!!", &[_]Token.Id{Token.Id.ContainerDocComment});
}

test "tokenizer - line comment followed by identifier" {
    testTokenize(
        \\    Unexpected,
        \\    // another
        \\    Another,
    , &[_]Token.Id{
        Token.Id.Identifier,
        Token.Id.Comma,
        Token.Id.LineComment,
        Token.Id.Identifier,
        Token.Id.Comma,
    });
}

test "tokenizer - UTF-8 BOM is recognized and skipped" {
    testTokenize("\xEF\xBB\xBFa;\n", &[_]Token.Id{
        Token.Id.Identifier,
        Token.Id.Semicolon,
    });
}

test "correctly parse pointer assignment" {
    testTokenize("b.*=3;\n", &[_]Token.Id{
        Token.Id.Identifier,
        Token.Id.PeriodAsterisk,
        Token.Id.Equal,
        Token.Id.IntegerLiteral,
        Token.Id.Semicolon,
    });
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
    std.testing.expect(last_token.id == Token.Id.Eof);
}
