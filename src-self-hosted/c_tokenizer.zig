const std = @import("std");
const expect = std.testing.expect;
const ZigClangSourceLocation = @import("clang.zig").ZigClangSourceLocation;
const Context = @import("translate_c.zig").Context;
const failDecl = @import("translate_c.zig").failDecl;

pub const TokenList = std.SegmentedList(CToken, 32);

pub const CToken = struct {
    id: Id,
    bytes: []const u8 = "",
    num_lit_suffix: NumLitSuffix = .None,

    pub const Id = enum {
        CharLit,
        StrLit,
        NumLitInt,
        NumLitFloat,
        Identifier,
        Plus,
        Minus,
        Slash,
        LParen,
        RParen,
        Eof,
        Dot,
        Asterisk, // *
        Ampersand, // &
        And, // &&
        Assign, // =
        Or, // ||
        Bang, // !
        Tilde, // ~
        Shl, // <<
        Shr, // >>
        Lt, // <
        Lte, // <=
        Gt, // >
        Gte, // >=
        Eq, // ==
        Ne, // !=
        Increment, // ++
        Decrement, // --
        Comma,
        Fn,
        Arrow, // ->
        LBrace,
        RBrace,
        Pipe,
        QuestionMark,
        Colon,
    };

    pub const NumLitSuffix = enum {
        None,
        F,
        L,
        U,
        LU,
        LL,
        LLU,
    };
};

pub fn tokenizeCMacro(ctx: *Context, loc: ZigClangSourceLocation, name: []const u8, tl: *TokenList, chars: [*:0]const u8) !void {
    var index: usize = 0;
    var first = true;
    while (true) {
        const tok = try next(ctx, loc, name, chars, &index);
        if (tok.id == .StrLit or tok.id == .CharLit)
            try tl.push(try zigifyEscapeSequences(ctx, loc, name, tl.allocator, tok))
        else
            try tl.push(tok);
        if (tok.id == .Eof)
            return;
        if (first) {
            // distinguish NAME (EXPR) from NAME(ARGS)
            first = false;
            if (chars[index] == '(') {
                try tl.push(.{
                    .id = .Fn,
                    .bytes = "",
                });
            }
        }
    }
}

fn zigifyEscapeSequences(ctx: *Context, loc: ZigClangSourceLocation, name: []const u8, allocator: *std.mem.Allocator, tok: CToken) !CToken {
    for (tok.bytes) |c| {
        if (c == '\\') {
            break;
        }
    } else return tok;
    var bytes = try allocator.alloc(u8, tok.bytes.len * 2);
    var state: enum {
        Start,
        Escape,
        Hex,
        Octal,
    } = .Start;
    var i: usize = 0;
    var count: u8 = 0;
    var num: u8 = 0;
    for (tok.bytes) |c| {
        switch (state) {
            .Escape => {
                switch (c) {
                    'n', 'r', 't', '\\', '\'', '\"' => {
                        bytes[i] = c;
                    },
                    '0'...'7' => {
                        count += 1;
                        num += c - '0';
                        state = .Octal;
                        bytes[i] = 'x';
                    },
                    'x' => {
                        state = .Hex;
                        bytes[i] = 'x';
                    },
                    'a' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = '7';
                    },
                    'b' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = '8';
                    },
                    'f' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = 'C';
                    },
                    'v' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = 'B';
                    },
                    '?' => {
                        i -= 1;
                        bytes[i] = '?';
                    },
                    'u', 'U' => {
                        try failDecl(ctx, loc, name, "macro tokenizing failed: TODO unicode escape sequences", .{});
                        return error.TokenizingFailed;
                    },
                    else => {
                        try failDecl(ctx, loc, name, "macro tokenizing failed: unknown escape sequence", .{});
                        return error.TokenizingFailed;
                    },
                }
                i += 1;
                if (state == .Escape)
                    state = .Start;
            },
            .Start => {
                if (c == '\\') {
                    state = .Escape;
                }
                bytes[i] = c;
                i += 1;
            },
            .Hex => {
                switch (c) {
                    '0'...'9' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try failDecl(ctx, loc, name, "macro tokenizing failed: hex literal overflowed", .{});
                            return error.TokenizingFailed;
                        };
                        num += c - '0';
                    },
                    'a'...'f' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try failDecl(ctx, loc, name, "macro tokenizing failed: hex literal overflowed", .{});
                            return error.TokenizingFailed;
                        };
                        num += c - 'a' + 10;
                    },
                    'A'...'F' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try failDecl(ctx, loc, name, "macro tokenizing failed: hex literal overflowed", .{});
                            return error.TokenizingFailed;
                        };
                        num += c - 'A' + 10;
                    },
                    else => {
                        i += std.fmt.formatIntBuf(bytes[i..], num, 16, false, std.fmt.FormatOptions{ .fill = '0', .width = 2 });
                        num = 0;
                        if (c == '\\')
                            state = .Escape
                        else
                            state = .Start;
                        bytes[i] = c;
                        i += 1;
                    },
                }
            },
            .Octal => {
                const accept_digit = switch (c) {
                    // The maximum length of a octal literal is 3 digits
                    '0'...'7' => count < 3,
                    else => false,
                };

                if (accept_digit) {
                    count += 1;
                    num = std.math.mul(u8, num, 8) catch {
                        try failDecl(ctx, loc, name, "macro tokenizing failed: octal literal overflowed", .{});
                        return error.TokenizingFailed;
                    };
                    num += c - '0';
                } else {
                    i += std.fmt.formatIntBuf(bytes[i..], num, 16, false, std.fmt.FormatOptions{ .fill = '0', .width = 2 });
                    num = 0;
                    count = 0;
                    if (c == '\\')
                        state = .Escape
                    else
                        state = .Start;
                    bytes[i] = c;
                    i += 1;
                }
            },
        }
    }
    if (state == .Hex or state == .Octal)
        i += std.fmt.formatIntBuf(bytes[i..], num, 16, false, std.fmt.FormatOptions{ .fill = '0', .width = 2 });
    return CToken{
        .id = tok.id,
        .bytes = bytes[0..i],
    };
}

fn next(ctx: *Context, loc: ZigClangSourceLocation, name: []const u8, chars: [*:0]const u8, i: *usize) !CToken {
    var state: enum {
        Start,
        SawLt,
        SawGt,
        SawPlus,
        SawMinus,
        SawAmpersand,
        SawPipe,
        SawBang,
        SawEq,
        CharLit,
        OpenComment,
        Comment,
        CommentStar,
        Backslash,
        String,
        Identifier,
        Decimal,
        Octal,
        SawZero,
        Hex,
        Bin,
        Float,
        ExpSign,
        FloatExp,
        FloatExpFirst,
        NumLitIntSuffixU,
        NumLitIntSuffixL,
        NumLitIntSuffixLL,
        NumLitIntSuffixUL,
        Done,
    } = .Start;

    var result = CToken{
        .bytes = "",
        .id = .Eof,
    };
    var begin_index: usize = 0;
    var digits: u8 = 0;
    var pre_escape = state;

    while (true) {
        const c = chars[i.*];
        if (c == 0) {
            switch (state) {
                .Identifier,
                .Decimal,
                .Hex,
                .Bin,
                .Octal,
                .SawZero,
                .Float,
                .FloatExp,
                => {
                    result.bytes = chars[begin_index..i.*];
                    return result;
                },
                .Start,
                .SawMinus,
                .Done,
                .NumLitIntSuffixU,
                .NumLitIntSuffixL,
                .NumLitIntSuffixUL,
                .NumLitIntSuffixLL,
                .SawLt,
                .SawGt,
                .SawPlus,
                .SawAmpersand,
                .SawPipe,
                .SawBang,
                .SawEq,
                => {
                    return result;
                },
                .CharLit,
                .OpenComment,
                .Comment,
                .CommentStar,
                .Backslash,
                .String,
                .ExpSign,
                .FloatExpFirst,
                => {
                    try failDecl(ctx, loc, name, "macro tokenizing failed: unexpected EOF", .{});
                    return error.TokenizingFailed;
                },
            }
        }
        switch (state) {
            .Start => {
                switch (c) {
                    ' ', '\t', '\x0B', '\x0C' => {},
                    '\'' => {
                        state = .CharLit;
                        result.id = .CharLit;
                        begin_index = i.*;
                    },
                    '\"' => {
                        state = .String;
                        result.id = .StrLit;
                        begin_index = i.*;
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
                        begin_index = i.*;
                    },
                    '1'...'9' => {
                        state = .Decimal;
                        result.id = .NumLitInt;
                        begin_index = i.*;
                    },
                    '0' => {
                        state = .SawZero;
                        result.id = .NumLitInt;
                        begin_index = i.*;
                    },
                    '.' => {
                        result.id = .Dot;
                        state = .Done;
                    },
                    '<' => {
                        result.id = .Lt;
                        state = .SawLt;
                    },
                    '>' => {
                        result.id = .Gt;
                        state = .SawGt;
                    },
                    '(' => {
                        result.id = .LParen;
                        state = .Done;
                    },
                    ')' => {
                        result.id = .RParen;
                        state = .Done;
                    },
                    '*' => {
                        result.id = .Asterisk;
                        state = .Done;
                    },
                    '+' => {
                        result.id = .Plus;
                        state = .SawPlus;
                    },
                    '-' => {
                        result.id = .Minus;
                        state = .SawMinus;
                    },
                    '!' => {
                        result.id = .Bang;
                        state = .SawBang;
                    },
                    '~' => {
                        result.id = .Tilde;
                        state = .Done;
                    },
                    '=' => {
                        result.id = .Assign;
                        state = .SawEq;
                    },
                    ',' => {
                        result.id = .Comma;
                        state = .Done;
                    },
                    '[' => {
                        result.id = .LBrace;
                        state = .Done;
                    },
                    ']' => {
                        result.id = .RBrace;
                        state = .Done;
                    },
                    '|' => {
                        result.id = .Pipe;
                        state = .SawPipe;
                    },
                    '&' => {
                        result.id = .Ampersand;
                        state = .SawAmpersand;
                    },
                    '?' => {
                        result.id = .QuestionMark;
                        state = .Done;
                    },
                    ':' => {
                        result.id = .Colon;
                        state = .Done;
                    },
                    else => {
                        try failDecl(ctx, loc, name, "macro tokenizing failed: unexpected character '{c}'", .{c});
                        return error.TokenizingFailed;
                    },
                }
            },
            .Done => return result,
            .SawMinus => {
                switch (c) {
                    '>' => {
                        result.id = .Arrow;
                        state = .Done;
                    },
                    '-' => {
                        result.id = .Decrement;
                        state = .Done;
                    },
                    else => return result,
                }
            },
            .SawPlus => {
                switch (c) {
                    '+' => {
                        result.id = .Increment;
                        state = .Done;
                    },
                    else => return result,
                }
            },
            .SawLt => {
                switch (c) {
                    '<' => {
                        result.id = .Shl;
                        state = .Done;
                    },
                    '=' => {
                        result.id = .Lte;
                        state = .Done;
                    },
                    else => return result,
                }
            },
            .SawGt => {
                switch (c) {
                    '>' => {
                        result.id = .Shr;
                        state = .Done;
                    },
                    '=' => {
                        result.id = .Gte;
                        state = .Done;
                    },
                    else => return result,
                }
            },
            .SawPipe => {
                switch (c) {
                    '|' => {
                        result.id = .Or;
                        state = .Done;
                    },
                    else => return result,
                }
            },
            .SawAmpersand => {
                switch (c) {
                    '&' => {
                        result.id = .And;
                        state = .Done;
                    },
                    else => return result,
                }
            },
            .SawBang => {
                switch (c) {
                    '=' => {
                        result.id = .Ne;
                        state = .Done;
                    },
                    else => return result,
                }
            },
            .SawEq => {
                switch (c) {
                    '=' => {
                        result.id = .Eq;
                        state = .Done;
                    },
                    else => return result,
                }
            },
            .Float => {
                switch (c) {
                    '.', '0'...'9' => {},
                    'e', 'E' => {
                        state = .ExpSign;
                    },
                    'f',
                    'F',
                    => {
                        result.num_lit_suffix = .F;
                        result.bytes = chars[begin_index..i.*];
                        state = .Done;
                    },
                    'l', 'L' => {
                        result.num_lit_suffix = .L;
                        result.bytes = chars[begin_index..i.*];
                        state = .Done;
                    },
                    else => {
                        result.bytes = chars[begin_index..i.*];
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
                    else => {
                        try failDecl(ctx, loc, name, "macro tokenizing failed: expected a digit or '+' or '-'", .{});
                        return error.TokenizingFailed;
                    },
                }
            },
            .FloatExpFirst => {
                switch (c) {
                    '0'...'9' => {
                        state = .FloatExp;
                    },
                    else => {
                        try failDecl(ctx, loc, name, "macro tokenizing failed: expected a digit", .{});
                        return error.TokenizingFailed;
                    },
                }
            },
            .FloatExp => {
                switch (c) {
                    '0'...'9' => {},
                    'f', 'F' => {
                        result.num_lit_suffix = .F;
                        result.bytes = chars[begin_index..i.*];
                        state = .Done;
                    },
                    'l', 'L' => {
                        result.num_lit_suffix = .L;
                        result.bytes = chars[begin_index..i.*];
                        state = .Done;
                    },
                    else => {
                        result.bytes = chars[begin_index..i.*];
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
                        result.bytes = chars[begin_index..i.*];
                    },
                    'l', 'L' => {
                        state = .NumLitIntSuffixL;
                        result.num_lit_suffix = .L;
                        result.bytes = chars[begin_index..i.*];
                    },
                    '.' => {
                        result.id = .NumLitFloat;
                        state = .Float;
                    },
                    else => {
                        result.bytes = chars[begin_index..i.*];
                        return result;
                    },
                }
            },
            .SawZero => {
                switch (c) {
                    'x', 'X' => {
                        state = .Hex;
                    },
                    'b', 'B' => {
                        state = .Bin;
                    },
                    '.' => {
                        state = .Float;
                        result.id = .NumLitFloat;
                    },
                    'u', 'U' => {
                        state = .NumLitIntSuffixU;
                        result.num_lit_suffix = .U;
                        result.bytes = chars[begin_index..i.*];
                    },
                    'l', 'L' => {
                        state = .NumLitIntSuffixL;
                        result.num_lit_suffix = .L;
                        result.bytes = chars[begin_index..i.*];
                    },
                    else => {
                        i.* -= 1;
                        state = .Octal;
                    },
                }
            },
            .Octal => {
                switch (c) {
                    '0'...'7' => {},
                    '8', '9' => {
                        try failDecl(ctx, loc, name, "macro tokenizing failed: invalid digit '{c}' in octal number", .{c});
                        return error.TokenizingFailed;
                    },
                    'u', 'U' => {
                        state = .NumLitIntSuffixU;
                        result.num_lit_suffix = .U;
                        result.bytes = chars[begin_index..i.*];
                    },
                    'l', 'L' => {
                        state = .NumLitIntSuffixL;
                        result.num_lit_suffix = .L;
                        result.bytes = chars[begin_index..i.*];
                    },
                    else => {
                        result.bytes = chars[begin_index..i.*];
                        return result;
                    },
                }
            },
            .Hex => {
                switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    'u', 'U' => {
                        // marks the number literal as unsigned
                        state = .NumLitIntSuffixU;
                        result.num_lit_suffix = .U;
                        result.bytes = chars[begin_index..i.*];
                    },
                    'l', 'L' => {
                        // marks the number literal as long
                        state = .NumLitIntSuffixL;
                        result.num_lit_suffix = .L;
                        result.bytes = chars[begin_index..i.*];
                    },
                    else => {
                        result.bytes = chars[begin_index..i.*];
                        return result;
                    },
                }
            },
            .Bin => {
                switch (c) {
                    '0'...'1' => {},
                    '2'...'9' => {
                        try failDecl(ctx, loc, name, "macro tokenizing failed: invalid digit '{c}' in binary number", .{c});
                        return error.TokenizingFailed;
                    },
                    'u', 'U' => {
                        // marks the number literal as unsigned
                        state = .NumLitIntSuffixU;
                        result.num_lit_suffix = .U;
                        result.bytes = chars[begin_index..i.*];
                    },
                    'l', 'L' => {
                        // marks the number literal as long
                        state = .NumLitIntSuffixL;
                        result.num_lit_suffix = .L;
                        result.bytes = chars[begin_index..i.*];
                    },
                    else => {
                        result.bytes = chars[begin_index..i.*];
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
                        state = .Done;
                    },
                    else => {
                        return result;
                    },
                }
            },
            .NumLitIntSuffixLL => {
                switch (c) {
                    'u', 'U' => {
                        result.num_lit_suffix = .LLU;
                        state = .Done;
                    },
                    else => {
                        return result;
                    },
                }
            },
            .NumLitIntSuffixUL => {
                switch (c) {
                    'l', 'L' => {
                        result.num_lit_suffix = .LLU;
                        state = .Done;
                    },
                    else => {
                        return result;
                    },
                }
            },
            .Identifier => {
                switch (c) {
                    '_', 'a'...'z', 'A'...'Z', '0'...'9' => {},
                    else => {
                        result.bytes = chars[begin_index..i.*];
                        return result;
                    },
                }
            },
            .String => {
                switch (c) {
                    '\"' => {
                        result.bytes = chars[begin_index .. i.* + 1];
                        state = .Done;
                    },
                    else => {},
                }
            },
            .CharLit => {
                switch (c) {
                    '\'' => {
                        result.bytes = chars[begin_index .. i.* + 1];
                        state = .Done;
                    },
                    else => {},
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
                        state = .Done;
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
                    else => {
                        try failDecl(ctx, loc, name, "macro tokenizing failed: expected whitespace", .{});
                        return error.TokenizingFailed;
                    },
                }
            },
        }
        i.* += 1;
    }
    unreachable;
}

fn expectTokens(tl: *TokenList, src: [*:0]const u8, expected: []CToken) void {
    // these can be undefined since they are only used for error reporting
    tokenizeCMacro(undefined, undefined, undefined, tl, src) catch unreachable;
    var it = tl.iterator(0);
    for (expected) |t| {
        var tok = it.next().?;
        std.testing.expectEqual(t.id, tok.id);
        if (t.bytes.len > 0) {
            //std.debug.warn("  {} = {}\n", .{tok.bytes, t.bytes});
            std.testing.expectEqualSlices(u8, tok.bytes, t.bytes);
        }
        if (t.num_lit_suffix != .None) {
            std.testing.expectEqual(t.num_lit_suffix, tok.num_lit_suffix);
        }
    }
    std.testing.expect(it.next() == null);
    tl.shrink(0);
}

test "tokenize macro" {
    var tl = TokenList.init(std.heap.page_allocator);
    defer tl.deinit();

    expectTokens(&tl, "TEST(0\n", &[_]CToken{
        .{ .id = .Identifier, .bytes = "TEST" },
        .{ .id = .Fn },
        .{ .id = .LParen },
        .{ .id = .NumLitInt, .bytes = "0" },
        .{ .id = .Eof },
    });

    expectTokens(&tl, "__FLT_MIN_10_EXP__ -37\n", &[_]CToken{
        .{ .id = .Identifier, .bytes = "__FLT_MIN_10_EXP__" },
        .{ .id = .Minus },
        .{ .id = .NumLitInt, .bytes = "37" },
        .{ .id = .Eof },
    });

    expectTokens(&tl, "__llvm__ 1\n#define", &[_]CToken{
        .{ .id = .Identifier, .bytes = "__llvm__" },
        .{ .id = .NumLitInt, .bytes = "1" },
        .{ .id = .Eof },
    });

    expectTokens(&tl, "TEST 2", &[_]CToken{
        .{ .id = .Identifier, .bytes = "TEST" },
        .{ .id = .NumLitInt, .bytes = "2" },
        .{ .id = .Eof },
    });

    expectTokens(&tl, "FOO 0ull", &[_]CToken{
        .{ .id = .Identifier, .bytes = "FOO" },
        .{ .id = .NumLitInt, .bytes = "0", .num_lit_suffix = .LLU },
        .{ .id = .Eof },
    });
}

test "tokenize macro ops" {
    var tl = TokenList.init(std.heap.page_allocator);
    defer tl.deinit();

    expectTokens(&tl, "ADD A + B", &[_]CToken{
        .{ .id = .Identifier, .bytes = "ADD" },
        .{ .id = .Identifier, .bytes = "A" },
        .{ .id = .Plus },
        .{ .id = .Identifier, .bytes = "B" },
        .{ .id = .Eof },
    });

    expectTokens(&tl, "ADD (A) + B", &[_]CToken{
        .{ .id = .Identifier, .bytes = "ADD" },
        .{ .id = .LParen },
        .{ .id = .Identifier, .bytes = "A" },
        .{ .id = .RParen },
        .{ .id = .Plus },
        .{ .id = .Identifier, .bytes = "B" },
        .{ .id = .Eof },
    });

    expectTokens(&tl, "ADD (A) + B", &[_]CToken{
        .{ .id = .Identifier, .bytes = "ADD" },
        .{ .id = .LParen },
        .{ .id = .Identifier, .bytes = "A" },
        .{ .id = .RParen },
        .{ .id = .Plus },
        .{ .id = .Identifier, .bytes = "B" },
        .{ .id = .Eof },
    });
}

test "escape sequences" {
    var buf: [1024]u8 = undefined;
    var alloc = std.heap.FixedBufferAllocator.init(buf[0..]);
    const a = &alloc.allocator;
    // these can be undefined since they are only used for error reporting
    expect(std.mem.eql(u8, (try zigifyEscapeSequences(undefined, undefined, undefined, a, .{
        .id = .StrLit,
        .bytes = "\\x0077",
    })).bytes, "\\x77"));
    expect(std.mem.eql(u8, (try zigifyEscapeSequences(undefined, undefined, undefined, a, .{
        .id = .StrLit,
        .bytes = "\\24500",
    })).bytes, "\\xa500"));
    expect(std.mem.eql(u8, (try zigifyEscapeSequences(undefined, undefined, undefined, a, .{
        .id = .StrLit,
        .bytes = "\\x0077 abc",
    })).bytes, "\\x77 abc"));
    expect(std.mem.eql(u8, (try zigifyEscapeSequences(undefined, undefined, undefined, a, .{
        .id = .StrLit,
        .bytes = "\\045abc",
    })).bytes, "\\x25abc"));

    expect(std.mem.eql(u8, (try zigifyEscapeSequences(undefined, undefined, undefined, a, .{
        .id = .CharLit,
        .bytes = "\\0",
    })).bytes, "\\x00"));
    expect(std.mem.eql(u8, (try zigifyEscapeSequences(undefined, undefined, undefined, a, .{
        .id = .CharLit,
        .bytes = "\\00",
    })).bytes, "\\x00"));
    expect(std.mem.eql(u8, (try zigifyEscapeSequences(undefined, undefined, undefined, a, .{
        .id = .CharLit,
        .bytes = "\\000\\001",
    })).bytes, "\\x00\\x01"));
    expect(std.mem.eql(u8, (try zigifyEscapeSequences(undefined, undefined, undefined, a, .{
        .id = .CharLit,
        .bytes = "\\000abc",
    })).bytes, "\\x00abc"));
}
