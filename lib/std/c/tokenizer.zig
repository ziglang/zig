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
        } = .Start;
        while (self.index < self.source.buffer.len) : (self.index += 1) {
            const c = self.source.buffer[self.index];
            switch (state) {
                .Start => switch (c) {
                    else => @panic("TODO"),
                },
                else => @panic("TODO"),
            }
        }
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
