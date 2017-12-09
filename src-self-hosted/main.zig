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
        Colon,
        Slash,
        Comma,
        Ampersand,
        AmpersandEqual,
        NumberLiteral,
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
                loc.line_start = i;
            } else {
                loc.column += 1;
            }
        }
        return loc;
    }

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
        Slash,
        LineComment,
        Zero,
        NumberLiteral,
        NumberDot,
        FloatFraction,
        FloatExponentUnsigned,
        FloatExponentNumber,
        Ampersand,
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
                        result.id = Token.Id.Period;
                        self.index += 1;
                        break;
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
                        result.id = Token.Id.NumberLiteral;
                    },
                    '1'...'9' => {
                        state = State.NumberLiteral;
                        result.id = Token.Id.NumberLiteral;
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
                        state = State.NumberLiteral;
                    },
                    else => {
                        // reinterpret as a normal number
                        self.index -= 1;
                        state = State.NumberLiteral;
                    },
                },
                State.NumberLiteral => switch (c) {
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
        // TODO check state when returning EOF
        return result;
    }
};

const Visibility = enum {
    Private,
    Pub,
    Export,
};

const Mutability = enum {
    Const,
    Var,
};

const AstNode = struct {
    id: Id,

    const Id = enum {
        Root,
        VarDecl,
        Identifier,
    };

    fn iterate(base: &AstNode, index: usize) -> ?&AstNode {
        return switch (base.id) {
            Id.Root => @fieldParentPtr(AstNodeRoot, "base", base).iterate(index),
            Id.VarDecl => @fieldParentPtr(AstNodeVarDecl, "base", base).iterate(index),
            Id.Identifier => @fieldParentPtr(AstNodeIdentifier, "base", base).iterate(index),
        };
    }
};

const AstNodeRoot = struct {
    base: AstNode,
    decls: ArrayList(&AstNode),

    fn iterate(self: &AstNodeRoot, index: usize) -> ?&AstNode {
        if (index < self.decls.len) {
            return self.decls.items[index];
        }
        return null;
    }
};

const AstNodeVarDecl = struct {
    base: AstNode,
    visib: Visibility,
    name_token: Token,
    eq_token: Token,
    mut: Mutability,
    is_comptime: bool,
    type_node: ?&AstNode,
    align_node: ?&AstNode,
    init_node: ?&AstNode,

    fn iterate(self: &AstNodeVarDecl, index: usize) -> ?&AstNode {
        var i = index;

        if (self.type_node) |type_node| {
            if (i < 1) return type_node;
            i -= 1;
        }

        if (self.align_node) |align_node| {
            if (i < 1) return align_node;
            i -= 1;
        }

        if (self.init_node) |init_node| {
            if (i < 1) return init_node;
            i -= 1;
        }

        return null;
    }
};

const AstNodeIdentifier = struct {
    base: AstNode,
    name_token: Token,

    fn iterate(self: &AstNodeIdentifier, index: usize) -> ?&AstNode {
        return null;
    }
};

error ParseError;

const Parser = struct {
    tokenizer: &Tokenizer,
    allocator: &mem.Allocator,
    put_back_tokens: [1]Token,
    put_back_count: usize,
    source_file_name: []const u8,

    fn init(tokenizer: &Tokenizer, allocator: &mem.Allocator, source_file_name: []const u8) -> Parser {
        return Parser {
            .tokenizer = tokenizer,
            .allocator = allocator,
            .put_back_tokens = undefined,
            .put_back_count = 0,
            .source_file_name = source_file_name,
        };
    }

    const State = union(enum) {
        TopLevel, 
        TopLevelModifier: Visibility, 
        Expression: &?&AstNode,
        GroupedExpression: &?&AstNode,
        PrimaryExpression: &?&AstNode,
        TypeExpr: &?&AstNode,
        VarDecl: &AstNodeVarDecl,
        VarDeclAlign: &AstNodeVarDecl,
        VarDeclEq: &AstNodeVarDecl,
        ExpectSemicolon,
    };

    pub fn parse(self: &Parser) -> %&AstNode {
        var stack = ArrayList(State).init(self.allocator);
        defer stack.deinit();

        %return stack.append(State.TopLevel);

        const root_node = %return self.createRoot();
        // TODO %defer self.freeAst();

        while (true) {
            // This gives us 1 free append that can't fail
            const state = stack.pop();

            switch (state) {
                State.TopLevel => {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_pub => {
                            stack.append(State {.TopLevelModifier = Visibility.Pub }) %% unreachable;
                            continue;
                        },
                        Token.Id.Keyword_export => {
                            stack.append(State {.TopLevelModifier = Visibility.Export }) %% unreachable;
                            continue;
                        },
                        Token.Id.Keyword_const => {
                            stack.append(State.TopLevel) %% unreachable;
                            const var_decl_node = %return self.createVarDecl(Visibility.Private, Mutability.Const, false);
                            %return root_node.decls.append(&var_decl_node.base);
                            %return stack.append(State { .VarDecl = var_decl_node });
                            continue;
                        },
                        Token.Id.Keyword_var => {
                            stack.append(State.TopLevel) %% unreachable;
                            const var_decl_node = %return self.createVarDecl(Visibility.Private, Mutability.Var, false);
                            %return root_node.decls.append(&var_decl_node.base);
                            %return stack.append(State { .VarDecl = var_decl_node });
                            continue;
                        },
                        Token.Id.Eof => return &root_node.base,
                        else => return self.parseError(token, "expected top level declaration, found {}", @tagName(token.id)),
                    }
                },
                State.TopLevelModifier => |visib| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_const => {
                            stack.append(State.TopLevel) %% unreachable;
                            const var_decl_node = %return self.createVarDecl(visib, Mutability.Const, false);
                            %return root_node.decls.append(&var_decl_node.base);
                            %return stack.append(State { .VarDecl = var_decl_node });
                            continue;
                        },
                        Token.Id.Keyword_var => {
                            stack.append(State.TopLevel) %% unreachable;
                            const var_decl_node = %return self.createVarDecl(visib, Mutability.Var, false);
                            %return root_node.decls.append(&var_decl_node.base);
                            %return stack.append(State { .VarDecl = var_decl_node });
                            continue;
                        },
                        else => return self.parseError(token, "expected top level declaration, found {}", @tagName(token.id)),
                    }
                },
                State.VarDecl => |var_decl| {
                    var_decl.name_token = %return self.eatToken(Token.Id.Identifier);
                    stack.append(State { .VarDeclAlign = var_decl }) %% unreachable;

                    const next_token = self.getNextToken();
                    if (next_token.id == Token.Id.Colon) {
                        %return stack.append(State { .TypeExpr = &var_decl.type_node });
                        continue;
                    }

                    self.putBackToken(next_token);
                    continue;
                },
                State.VarDeclAlign => |var_decl| {
                    stack.append(State { .VarDeclEq = var_decl }) %% unreachable;

                    const next_token = self.getNextToken();
                    if (next_token.id == Token.Id.Keyword_align) {
                        %return stack.append(State { .GroupedExpression = &var_decl.align_node });
                        continue;
                    }

                    self.putBackToken(next_token);
                    continue;
                },
                State.VarDeclEq => |var_decl| {
                    var_decl.eq_token = %return self.eatToken(Token.Id.Equal);
                    stack.append(State.ExpectSemicolon) %% unreachable;
                    %return stack.append(State {
                        .Expression = &var_decl.init_node,
                    });
                    continue;
                },
                State.ExpectSemicolon => {
                    _ = %return self.eatToken(Token.Id.Semicolon);
                    continue;
                },
                State.Expression => |result_ptr| {
                    // TODO this should not jump straight to primary expression
                    stack.append(State {.PrimaryExpression = result_ptr}) %% unreachable;
                    continue;
                },
                State.PrimaryExpression => |result_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Identifier => {
                            const identifier = %return self.createIdentifier(token);
                            *result_ptr = &identifier.base;
                            continue;
                        },
                        else => return self.parseError(token, "expected primary expression, found {}", @tagName(token.id)),
                    }
                },
                State.TypeExpr => @panic("TODO"),
                State.GroupedExpression => @panic("TODO"),
            }
            unreachable;
        }
    }

    fn createRoot(self: &Parser) -> %&AstNodeRoot {
        const node = %return self.allocator.create(AstNodeRoot);
        %defer self.allocator.destroy(node);

        *node = AstNodeRoot {
            .base = AstNode {.id = AstNode.Id.Root},
            .decls = ArrayList(&AstNode).init(self.allocator),
        };
        return node;
    }

    fn createVarDecl(self: &Parser, visib: Visibility, mut: Mutability, is_comptime: bool) -> %&AstNodeVarDecl {
        const node = %return self.allocator.create(AstNodeVarDecl);
        %defer self.allocator.destroy(node);

        *node = AstNodeVarDecl {
            .base = AstNode {.id = AstNode.Id.VarDecl},
            .visib = visib,
            .mut = mut,
            .is_comptime = is_comptime,
            .type_node = null,
            .align_node = null,
            .init_node = null,
            // initialized later
            .name_token = undefined,
            .eq_token = undefined,
        };
        return node;
    }

    fn createIdentifier(self: &Parser, name_token: &const Token) -> %&AstNodeIdentifier {
        const node = %return self.allocator.create(AstNodeIdentifier);
        %defer self.allocator.destroy(node);

        *node = AstNodeIdentifier {
            .base = AstNode {.id = AstNode.Id.Identifier},
            .name_token = *name_token,
        };
        return node;
    }

    fn parseError(self: &Parser, token: &const Token, comptime fmt: []const u8, args: ...) -> error {
        const loc = self.tokenizer.getTokenLocation(token);
        warn("{}:{}:{}: error: " ++ fmt ++ "\n", self.source_file_name, loc.line + 1, loc.column + 1, args);
        warn("{}\n", self.tokenizer.buffer[loc.line_start..loc.line_end]);
        {
            var i: usize = 0;
            while (i < loc.column) : (i += 1) {
                warn(" ");
            }
        }
        {
            const caret_count = token.end - token.start;
            var i: usize = 0;
            while (i < caret_count) : (i += 1) {
                warn("~");
            }
        }
        warn("\n");
        return error.ParseError;
    }

    fn expectToken(self: &Parser, token: &const Token, id: @TagType(Token.Id)) -> %void {
        if (token.id != id) {
            return self.parseError(token, "expected {}, found {}", @tagName(id), @tagName(token.id));
        }
    }

    fn eatToken(self: &Parser, id: @TagType(Token.Id)) -> %Token {
        const token = self.getNextToken();
        %return self.expectToken(token, id);
        return token;
    }

    fn putBackToken(self: &Parser, token: &const Token) {
        self.put_back_tokens[self.put_back_count] = *token;
        self.put_back_count += 1;
    }

    fn getNextToken(self: &Parser) -> Token {
        return if (self.put_back_count != 0) {
            const put_back_index = self.put_back_count - 1;
            const put_back_token = self.put_back_tokens[put_back_index];
            self.put_back_count = put_back_index;
            put_back_token
        } else {
            self.tokenizer.next()
        };
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

    warn("====input:====\n");

    warn("{}", target_file_buf);

    warn("====tokenization:====\n");
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

    warn("====parse:====\n");

    var tokenizer = Tokenizer.init(target_file_buf);
    var parser = Parser.init(&tokenizer, allocator, target_file);
    const node = %return parser.parse();


    render(node, 0);
}

fn render(node: &AstNode, indent: usize) {
    {
        var i: usize = 0;
        while (i < indent) : (i += 1) {
            warn(" ");
        }
    }
    warn("{}\n", @tagName(node.id));
    var i: usize = 0;
    while (node.iterate(i)) |child| : (i += 1) {
        render(child, indent + 2);
    }
}
