const builtin = @import("builtin");
const io = @import("std").io;
const os = @import("std").os;
const heap = @import("std").heap;
const warn = @import("std").debug.warn;
const assert = @import("std").debug.assert;
const mem = @import("std").mem;
const ArrayList = @import("std").ArrayList;


const Token = struct {
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

    const Id = union(enum) {
        Invalid,
        Identifier,
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
                        result.id = Token.Id.Equal;
                        self.index += 1;
                        break;
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
                        result.id = Token.Id.Period;
                        self.index += 1;
                        break;
                    },
                    '-' => {
                        state = State.Minus;
                    },
                    else => {
                        result.id = Token.Id.Invalid;
                        self.index += 1;
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
            }
        }
        result.end = self.index;
        return result;
    }
};

const AstNode = struct {

};

const Parser = struct {
    tokenizer: &Tokenizer,
    allocator: &mem.Allocator,

    fn init(tokenizer: &Tokenizer, allocator: &mem.Allocator) -> Parser {
        return Parser {
            .tokenizer = tokenizer,
            .allocator = allocator,
        };
    }

    const StackFrame = struct {

    };

    const State = enum {
        TopLevel, 
        Expression,
    };

    fn parse(self: &Parser) -> %void {
        var stack = ArrayList(StackFrame).init(self.allocator);
        defer stack.deinit();

        var state = State.TopLevel;
        while (true) {
            const token = self.tokenizer.next();
            switch (state) {
                State.TopLevel => switch (token.id) {
                    Token.Id.Keyword_pub => {
                        const next_token = self.tokenizer.next();
                        switch (next_token.id) {
                            Token.Id.Keyword_fn => {
                                const fn_name = self.tokenizer.next();
                                if (fn_name.id != Token.Id.Identifier) {
                                    @panic("parse error");
                                }

                                const lparen = self.tokenizer.next();
                                if (lparen.id != Token.Id.LParen) {
                                    @panic("parse error");
                                }
                            },
                            Token.Id.Keyword_const => @panic("TODO"),
                            Token.Id.Keyword_var => @panic("TODO"),
                            Token.Id.Keyword_use => @panic("TODO"),
                            else => @panic("parse error"),
                        }
                    },
                    Token.Id.Keyword_const => @panic("TODO"),
                    Token.Id.Keyword_var => @panic("TODO"),
                    Token.Id.Keyword_fn => @panic("TODO"),
                    Token.Id.Keyword_export => @panic("TODO"),
                    Token.Id.Keyword_use => @panic("TODO"),
                    Token.Id.Keyword_comptime => @panic("TODO"),
                    else => @panic("parse error"),
                },
                State.Expression => @panic("TODO"),
            }
        }
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

    const args = %return os.argsAlloc(allocator);
    defer os.argsFree(allocator, args);

    const target_file = args[1];

    const target_file_buf = %return io.readFileAlloc(target_file, allocator);

    warn("{}", target_file_buf);

    {
        var tokenizer = Tokenizer.init(target_file_buf);
        while (true) {
            const token = tokenizer.next();
            tokenizer.dump(token);
            if (token.id == Token.Id.Eof) {
                break;
            }
        }
    }

    var tokenizer = Tokenizer.init(target_file_buf);
    var parser = Parser.init(&tokenizer, allocator);
    %return parser.parse();
}
