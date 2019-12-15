const std = @import("std");

pub const TokenList = std.SegmentedList(CToken, 32);

pub const CToken = struct {
    id: Id,
    bytes: []const u8,
    num_lit_suffix: NumLitSuffix = undefined,

    pub const Id = enum {
        CharLit,
        StrLit,
        NumLitInt,
        NumLitFloat,
        Identifier,
        Minus,
        Slash,
        LParen,
        RParen,
        Eof,
        Dot,
        Asterisk,
        Bang,
        Tilde,
        Shl,
        Lt,
    };

    pub const NumLitSuffix = enum {
        None,
        L,
        U,
        LU,
        LL,
        LLU,
    };
};

pub fn tokenizeCMacro(tl: *TokenList, chars: [*]const u8) !void {
    var index: usize = 0;
    while (true) {
        const tok = try next(chars[index..], &index);
        tl.push(tok);
        if (tok.id == .Eof)
            return;
    }
}

fn next(chars: [*]const u8, index: *usize) !CToken {
    var state: enum {
        Start,
        GotLt,
        ExpectChar,
        ExpectEndQuot,
        OpenComment,
        Comment,
        CommentStar,
        Backslash,
        String,
        Identifier,
        Decimal,
        Octal,
        GotZero,
        Hex,
        Float,
        ExpSign,
        FloatExp,
        FloatExpFirst,
        NumLitIntSuffixU,
        NumLitIntSuffixL,
        NumLitIntSuffixLL,
        NumLitIntSuffixUL,
        GotLt,
    } = .Start;

    var result = CToken{
        .bytes = "",
        .id = .Eof,
    };
    var begin_index: usize = 0;
    var digits: u8 = 0;
    var pre_escape = .Start;

    for (chars[begin_index..]) |c, i| {
        if (c == 0) {
            switch (state) {
                .Start => {
                    return result;
                },
                .Identifier,
                .Decimal,
                .Hex,
                .Octal,
                .GotZero,
                .NumLitIntSuffixU,
                .NumLitIntSuffixL,
                .NumLitIntSuffixUL,
                .NumLitIntSuffixLL,
                .Float,
                .FloatExp,
                .GotLt,
                => {
                    return result;
                },
                .ExpectChar,
                .ExpectEndQuot,
                .OpenComment,
                .LineComment,
                .Comment,
                .CommentStar,
                .Backslash,
                .String,
                .ExpSign,
                .FloatExpFirst,
                => return error.TokenizingFailed,
            }
        }
        index.* += 1;
        switch (state) {
            .Start => {
                switch (c) {
                    ' ', '\t', '\x0B', '\x0C' => {},
                    '\'' => {
                        state = .ExpectChar;
                        result.id = .CharLit;
                        begin_index = i;
                    },
                    '\"' => {
                        state = .String;
                        result.id = .StrLit;
                        begin_index = i;
                    },
                    '/' => {
                        state = .OpenComment;
                    },
                    '\\' => {
                        state = .Backslash;
                    },
                    '\n', '\r' => {
                        return result;
                    },
                    'a'...'z', 'A'...'Z', '_' => {
                        state = .Identifier;
                        result.id = .Identifier;
                        begin_index = i;
                    },
                    '1'...'9' => {
                        state = .Decimal;
                        result.id = .NumLitInt;
                        begin_index = i;
                    },
                    '0' => {
                        state = .GotZero;
                        result.id = .NumLitInt;
                        begin_index = i;
                    },
                    '.' => {
                        result.id = .Dot;
                        return result;
                    },
                    '<' => {
                        result.id = .Lt;
                        state = .GotLt;
                    },
                    '(' => {
                        result.id = .LParen;
                        return result;
                    },
                    ')' => {
                        result.id = .RParen;
                        return result;
                    },
                    '*' => {
                        result.id = .Asterisk;
                        return result;
                    },
                    '-' => {
                        result.id = .Minus;
                        return result;
                    },
                    '!' => {
                        result.id = .Bang;
                        return result;
                    },
                    '~' => {
                        result.id = .Tilde;
                        return result;
                    },
                    else => return error.TokenizingFailed,
                }
            },
            .GotLt => {
                switch (c) {
                    '<' => {
                        result.id = .Shl;
                        return result;
                    },
                    else => {
                        return result;
                    },
                }
            },
            .Float => {
                switch (c) {
                    '.', '0'...'9' => {},
                    'e', 'E' => {
                        state = .ExpSign;
                    },
                    'f', 'F', 'l', 'L' => {
                        result.bytes = chars[begin_index..i];
                        return result;
                    },
                    else => {
                        result.bytes = chars[begin_index..i];
                        return result;
                    },
                }
            },
            .ExpSign => {
                switch (c) {
                    '+', '-' => {
                        state = .FloatExpFirst;
                    },
                    '0'...'9' => {
                        state = .FloatExp;
                    },
                    else => return error.TokenizingFailed,
                }
            },
            .FloatExpFirst => {
                switch (c) {
                    '0'...'9' => {
                        state = .FloatExp;
                    },
                    else => return error.TokenizingFailed,
                }
            },
            .FloatExp => {
                switch (c) {
                    '0'...'9' => {},
                    'f', 'F', 'l', 'L' => {
                        result.bytes = chars[begin_index..i];
                        return result;
                    },
                    else => {
                        result.bytes = chars[begin_index..i];
                        return result;
                    },
                }
            },
            .Decimal => {
                switch (c) {
                    '0'...'9' => {},
                    '\'' => {},
                    'u', 'U' => {
                        state = .NumLitIntSuffixU;
                        result.num_lit_suffix = .U;
                    },
                    'l', 'L' => {
                        state = .NumLitIntSuffixL;
                        result.num_lit_suffix = .L;
                    },
                    '.' => {
                        result.id = .NumLitFloat;
                        state = .Float;
                    },
                    else => {
                        result.bytes = chars[begin_index..i];
                        return result;
                    },
                }
            },
            .GotZero => {
                switch (c) {
                    'x', 'X' => {
                        state = .Hex;
                    },
                    '.' => {
                        state = .Float;
                        result.id = .NumLitFloat;
                    },
                    'l', 'L', 'u', 'U' => {
                        c -= 1;
                        state = .Decimal;
                    },
                    else => {
                        state = .Octal;
                    },
                }
            },
            .Octal => {
                switch (c) {
                    '0'...'7' => {},
                    '8', '9' => return error.TokenizingFailed,
                    else => {
                        result.bytes = chars[begin_index..i];
                        return result;
                    },
                }
            },
            .Hex => {
                switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {},

                    'p', 'P' => {
                        result.id = .NumLitFloat;
                        state = .ExpSign;
                    },
                    'u', 'U' => {
                        // marks the number literal as unsigned
                        state = .NumLitIntSuffixU;
                        result.num_lit_suffix = .U;
                    },
                    'l', 'L' => {
                        // marks the number literal as long
                        state = .NumLitIntSuffixL;
                        result.num_lit_suffix = .L;
                    },
                    else => {
                        result.bytes = chars[begin_index..i];
                        return result;
                    },
                }
            },
            .NumLitIntSuffixU => {
                switch (c) {
                    'l', 'L' => {
                        result.num_lit_suffix = .LU;
                        state = .NumLitIntSuffixUL;
                    },
                    else => {
                        result.bytes = chars[begin_index..i - 1];
                        return result;
                    },
                }
            },
            .NumLitIntSuffixL => {
                switch (c) {
                    'l', 'L' => {
                        result.num_lit_suffix = .LL;
                        state = .NumLitIntSuffixLL;
                    },
                    'u', 'U' => {
                        result.num_lit_suffix = .LU;
                        result.bytes = chars[begin_index..i - 2];
                        return result;
                    },
                    else => {
                        result.bytes = chars[begin_index..i - 1];
                        return result;
                    },
                }
            },
            .NumLitIntSuffixLL => {
                switch (c) {
                    'u', 'U' => {
                        result.num_lit_suffix = .LLU;
                        result.bytes = chars[begin_index..i - 3];
                        return result;
                    },
                    else => {
                        result.bytes = chars[begin_index..i - 2];
                        return result;
                    },
                }
            },
            .NumLitIntSuffixUL => {
                switch (c) {
                    'l', 'L' => {
                        result.num_lit_suffix = .LLU;
                        result.bytes = chars[begin_index..i - 3];
                        return result;
                    },
                    else => {
                        result.bytes = chars[begin_index..i - 2];
                        return result;
                    },
                }
            },
            .Identifier => {
                switch (c) {
                    '_', 'a'...'z', 'A'...'Z', '0'...'9' => {},
                    else => {
                        result.bytes = chars[begin_index..i];
                        return result;
                    },
                }
            },
            .String => {
                switch (c) {
                    '\"' => {
                        result.bytes = chars[begin_index + 1 .. i];
                        return result;
                    },
                    else => {},
                }
            },
            .ExpectChar => {
                switch (c) {
                    '\'' => return error.TokenizingFailed,
                    else => {
                        state = .ExpectEndQuot;
                    },
                }
            },
            .ExpectEndQuot => {
                switch (c) {
                    '\'' => {
                        result.bytes = chars[begin_index + 1 .. i];
                        return result;
                    },
                    else => return error.TokenizingFailed,
                }
            },
            .OpenComment => {
                switch (c) {
                    '/' => {
                        return result;
                    },
                    '*' => {
                        state = .Comment;
                    },
                    else => {
                        result.id = .Slash;
                        return result;
                    },
                }
            },
            .Comment => {
                switch (c) {
                    '*' => {
                        state = .CommentStar;
                    },
                    else => {},
                }
            },
            .CommentStar => {
                switch (c) {
                    '/' => {
                        state = .Start;
                    },
                    else => {
                        state = .Comment;
                    },
                }
            },
            .Backslash => {
                switch (c) {
                    ' ', '\t', '\x0B', '\x0C' => {},
                    '\n', '\r' => {
                        state = .Start;
                    },
                    else => return error.TokenizingFailed,
                }
            },
        }
    }
}
