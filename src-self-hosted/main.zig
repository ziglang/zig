const builtin = @import("builtin");
const io = @import("std").io;
const os = @import("std").os;
const heap = @import("std").heap;
const warn = @import("std").debug.warn;
const assert = @import("std").debug.assert;
const mem = @import("std").mem;

const Token = struct {
    id: Id,
    start: usize,
    end: usize,

    const Keyword = enum {
        @"align",
        @"and",
        @"asm",
        @"break",
        @"coldcc",
        @"comptime",
        @"const",
        @"continue",
        @"defer",
        @"else",
        @"enum",
        @"error",
        @"export",
        @"extern",
        @"false",
        @"fn",
        @"for",
        @"goto",
        @"if",
        @"inline",
        @"nakedcc",
        @"noalias",
        @"null",
        @"or",
        @"packed",
        @"pub",
        @"return",
        @"stdcallcc",
        @"struct",
        @"switch",
        @"test",
        @"this",
        @"true",
        @"undefined",
        @"union",
        @"unreachable",
        @"use",
        @"var",
        @"volatile",
        @"while",
    };

    fn getKeyword(bytes: []const u8) -> ?Keyword {
        comptime var i = 0;
        inline while (i < @memberCount(Keyword)) : (i += 1) {
            if (mem.eql(u8, @memberName(Keyword, i), bytes)) {
                return Keyword(i);
            }
        }
        return null;
    }

    const StrLitKind = enum {Normal, C};

    const Id = union(enum) {
        Invalid,
        Identifier,
        Keyword: Keyword,
        StringLiteral: StrLitKind,
        Eof,
        Builtin,
        Equal,
        LParen,
        RParen,
        Semicolon,
        Percent,
        LBrace,
        RBrace,
        Period,
        Minus,
        Arrow,
    };
};

const Tokenizer = struct {
    buffer: []const u8,
    index: usize,

    pub fn dump(self: &Tokenizer, token: &const Token) {
        warn("{} \"{}\"\n", @tagName(token.id), self.buffer[token.start..token.end]);
    }

    pub fn init(buffer: []const u8) -> Tokenizer {
        return Tokenizer {
            .buffer = buffer,
            .index = 0,
        };
    }

    const State = enum {
        Start,
        Identifier,
        Builtin,
        C,
        StringLiteral,
        StringLiteralBackslash,
        Minus,
    };

    pub fn next(self: &Tokenizer) -> Token {
        var state = State.Start;
        var result = Token {
            .id = Token.Id { .Eof = {} },
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
                        result.id = Token.Id { .Identifier = {} };
                    },
                    '"' => {
                        state = State.StringLiteral;
                        result.id = Token.Id { .StringLiteral = Token.StrLitKind.Normal };
                    },
                    'a'...'b', 'd'...'z', 'A'...'Z', '_' => {
                        state = State.Identifier;
                        result.id = Token.Id { .Identifier = {} };
                    },
                    '@' => {
                        state = State.Builtin;
                        result.id = Token.Id { .Builtin = {} };
                    },
                    '=' => {
                        result.id = Token.Id { .Equal = {} };
                        self.index += 1;
                        break;
                    },
                    '(' => {
                        result.id = Token.Id { .LParen = {} };
                        self.index += 1;
                        break;
                    },
                    ')' => {
                        result.id = Token.Id { .RParen = {} };
                        self.index += 1;
                        break;
                    },
                    ';' => {
                        result.id = Token.Id { .Semicolon = {} };
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        result.id = Token.Id { .Percent = {} };
                        self.index += 1;
                        break;
                    },
                    '{' => {
                        result.id = Token.Id { .LBrace = {} };
                        self.index += 1;
                        break;
                    },
                    '}' => {
                        result.id = Token.Id { .RBrace = {} };
                        self.index += 1;
                        break;
                    },
                    '.' => {
                        result.id = Token.Id { .Period = {} };
                        self.index += 1;
                        break;
                    },
                    '-' => {
                        state = State.Minus;
                    },
                    else => {
                        result.id = Token.Id { .Invalid = {} };
                        self.index += 1;
                        break;
                    },
                },
                State.Identifier => switch (c) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => {},
                    else => {
                        if (Token.getKeyword(self.buffer[result.start..self.index])) |keyword_id| {
                            result.id = Token.Id { .Keyword = keyword_id };
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

                State.Minus => switch (c) {
                    '>' => {
                        result.id = Token.Id { .Arrow = {} };
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id { .Minus = {} };
                        break;
                    },
                },
            }
        }
        result.end = self.index;
        return result;
    }
};


pub fn main() -> %void {
    main2() %% |err| {
        warn("{}\n", @errorName(err));
        return err;
    };
}

pub fn main2() -> %void {
    var incrementing_allocator = %return heap.IncrementingAllocator.init(10 * 1024 * 1024);
    defer incrementing_allocator.deinit();

    const allocator = &incrementing_allocator.allocator;

    const target_file = "input.zig"; // TODO

    const target_file_buf = %return io.readFileAlloc(target_file, allocator);

    warn("{}", target_file_buf);

    var tokenizer = Tokenizer.init(target_file_buf);
    while (true) {
        const token = tokenizer.next();
        tokenizer.dump(token);
        if (@TagType(Token.Id)(token.id) == Token.Id.Eof) {
            break;
        }
    }
}
