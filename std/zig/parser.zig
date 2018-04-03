const std = @import("../index.zig");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const mem = std.mem;
const ast = std.zig.ast;
const Tokenizer = std.zig.Tokenizer;
const Token = std.zig.Token;
const builtin = @import("builtin");
const io = std.io;

// TODO when we make parse errors into error types instead of printing directly,
// get rid of this
const warn = std.debug.warn;

pub const Parser = struct {
    util_allocator: &mem.Allocator,
    tokenizer: &Tokenizer,
    put_back_tokens: [2]Token,
    put_back_count: usize,
    source_file_name: []const u8,
    pending_line_comment_node: ?&ast.NodeLineComment,

    pub const Tree = struct {
        root_node: &ast.NodeRoot,
        arena_allocator: std.heap.ArenaAllocator,

        pub fn deinit(self: &Tree) void {
            self.arena_allocator.deinit();
        }
    };

    // This memory contents are used only during a function call. It's used to repurpose memory;
    // we reuse the same bytes for the stack data structure used by parsing, tree rendering, and
    // source rendering.
    const utility_bytes_align = @alignOf( union { a: RenderAstFrame, b: State, c: RenderState } );
    utility_bytes: []align(utility_bytes_align) u8,

    /// allocator must outlive the returned Parser and all the parse trees you create with it.
    pub fn init(tokenizer: &Tokenizer, allocator: &mem.Allocator, source_file_name: []const u8) Parser {
        return Parser {
            .util_allocator = allocator,
            .tokenizer = tokenizer,
            .put_back_tokens = undefined,
            .put_back_count = 0,
            .source_file_name = source_file_name,
            .utility_bytes = []align(utility_bytes_align) u8{},
            .pending_line_comment_node = null,
        };
    }

    pub fn deinit(self: &Parser) void {
        self.util_allocator.free(self.utility_bytes);
    }

    const TopLevelDeclCtx = struct {
        decls: &ArrayList(&ast.Node),
        visib_token: ?Token,
        extern_token: ?Token,
        lib_name: ?&ast.Node,
    };

    const DestPtr = union(enum) {
        Field: &&ast.Node,
        NullableField: &?&ast.Node,
        List: &ArrayList(&ast.Node),

        pub fn store(self: &const DestPtr, value: &ast.Node) !void {
            switch (*self) {
                DestPtr.Field => |ptr| *ptr = value,
                DestPtr.NullableField => |ptr| *ptr = value,
                DestPtr.List => |list| try list.append(value),
            }
        }
    };

    const ExpectTokenSave = struct {
        id: Token.Id,
        ptr: &Token,
    };

    fn ListState(comptime T: type) type {
        return struct {
            list: &ArrayList(T),
            end: Token.Id,
            ptr: &Token,
        };
    }

    const State = union(enum) {
        TopLevel,
        TopLevelExtern: TopLevelDeclCtx,
        TopLevelDecl: TopLevelDeclCtx,
        ContainerDecl: &ast.NodeContainerDecl,
        Expression: DestPtr,
        ExpectOperand,
        Operand: &ast.Node,
        AfterOperand,
        InfixOp: &ast.NodeInfixOp,
        PrefixOp: &ast.NodePrefixOp,
        SuffixOp: &ast.NodeSuffixOp,
        SliceOrArrayAccess: &ast.NodeSuffixOp,
        AddrOfModifiers: &ast.NodePrefixOp.AddrOfInfo,
        TypeExpr: DestPtr,
        VarDecl: &ast.NodeVarDecl,
        VarDeclAlign: &ast.NodeVarDecl,
        VarDeclEq: &ast.NodeVarDecl,
        ExpectToken: @TagType(Token.Id),
        ExpectTokenSave: ExpectTokenSave,
        FnProto: &ast.NodeFnProto,
        FnProtoAlign: &ast.NodeFnProto,
        FnProtoReturnType: &ast.NodeFnProto,
        ParamDecl: &ast.NodeFnProto,
        ParamDeclComma,
        FnDef: &ast.NodeFnProto,
        Block: &ast.NodeBlock,
        Statement: &ast.NodeBlock,
        ExprListItemOrEnd: ListState(&ast.Node),
        ExprListCommaOrEnd: ListState(&ast.Node),
        FieldInitListItemOrEnd: ListState(&ast.NodeFieldInitializer),
        FieldInitListCommaOrEnd: ListState(&ast.NodeFieldInitializer),
        FieldListCommaOrEnd: &ast.NodeContainerDecl,
    };

    /// Returns an AST tree, allocated with the parser's allocator.
    /// Result should be freed with tree.deinit() when there are
    /// no more references to any AST nodes of the tree.
    pub fn parse(self: &Parser) !Tree {
        var stack = self.initUtilityArrayList(State);
        defer self.deinitUtilityArrayList(stack);

        var arena_allocator = std.heap.ArenaAllocator.init(self.util_allocator);
        errdefer arena_allocator.deinit();

        const arena = &arena_allocator.allocator;
        const root_node = try self.createRoot(arena);

        try stack.append(State.TopLevel);

        while (true) {
            //{
            //    const token = self.getNextToken();
            //    warn("{} ", @tagName(token.id));
            //    self.putBackToken(token);
            //    var i: usize = stack.len;
            //    while (i != 0) {
            //        i -= 1;
            //        warn("{} ", @tagName(stack.items[i]));
            //    }
            //    warn("\n");
            //}

            // look for line comments
            while (true) {
                const token = self.getNextToken();
                if (token.id == Token.Id.LineComment) {
                    const node = blk: {
                        if (self.pending_line_comment_node) |comment_node| {
                            break :blk comment_node;
                        } else {
                            const comment_node = try arena.create(ast.NodeLineComment);
                            *comment_node = ast.NodeLineComment {
                                .base = ast.Node {
                                    .id = ast.Node.Id.LineComment,
                                    .comment = null,
                                },
                                .lines = ArrayList(Token).init(arena),
                            };
                            self.pending_line_comment_node = comment_node;
                            break :blk comment_node;
                        }
                    };
                    try node.lines.append(token);
                    continue;
                }
                self.putBackToken(token);
                break;
            }

            // This gives us 1 free append that can't fail
            const state = stack.pop();

            switch (state) {
                State.TopLevel => {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_test => {
                            stack.append(State.TopLevel) catch unreachable;

                            const name_token = self.getNextToken();
                            if (name_token.id != Token.Id.StringLiteral)
                                return self.parseError(token, "expected {}, found {}", @tagName(Token.Id.StringLiteral), @tagName(name_token.id));

                            const lbrace = self.getNextToken();
                            if (lbrace.id != Token.Id.LBrace)
                                return self.parseError(token, "expected {}, found {}", @tagName(Token.Id.LBrace), @tagName(name_token.id));

                            const name = try self.createStringLiteral(arena, name_token);
                            const block = try self.createBlock(arena, token);
                            const test_decl = try self.createAttachTestDecl(arena, &root_node.decls, token, &name.base, block);
                            try stack.append(State { .Block = block });
                            continue;
                        },
                        Token.Id.Eof => {
                            root_node.eof_token = token;
                            return Tree {.root_node = root_node, .arena_allocator = arena_allocator};
                        },
                        Token.Id.Keyword_pub, Token.Id.Keyword_export => {
                            stack.append(State.TopLevel) catch unreachable;
                            try stack.append(State {
                                .TopLevelExtern = TopLevelDeclCtx {
                                    .decls = &root_node.decls,
                                    .visib_token = token,
                                    .extern_token = null,
                                    .lib_name = null,
                                }
                            });
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            stack.append(State.TopLevel) catch unreachable;
                            try stack.append(State {
                                .TopLevelExtern = TopLevelDeclCtx {
                                    .decls = &root_node.decls,
                                    .visib_token = null,
                                    .extern_token = null,
                                    .lib_name = null,
                                }
                            });
                            continue;
                        },
                    }
                },
                State.TopLevelExtern => |ctx| {
                    const token = self.getNextToken();
                    if (token.id == Token.Id.Keyword_extern) {
                        const lib_name_token = self.getNextToken();
                        const lib_name = blk: {
                            if (lib_name_token.id == Token.Id.StringLiteral) {
                                const res = try self.createStringLiteral(arena, lib_name_token);
                                break :blk &res.base;
                            } else {
                                self.putBackToken(lib_name_token);
                                break :blk null;
                            }
                        };

                        stack.append(State {
                            .TopLevelDecl = TopLevelDeclCtx {
                                .decls = ctx.decls,
                                .visib_token = ctx.visib_token,
                                .extern_token = token,
                                .lib_name = lib_name,
                            },
                        }) catch unreachable;
                        continue;
                    }
                    self.putBackToken(token);
                    stack.append(State { .TopLevelDecl = ctx }) catch unreachable;
                    continue;
                },
                State.TopLevelDecl => |ctx| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_var, Token.Id.Keyword_const => {
                            // TODO shouldn't need these casts
                            const var_decl_node = try self.createAttachVarDecl(arena, ctx.decls, ctx.visib_token,
                                token, (?Token)(null), ctx.extern_token, ctx.lib_name);
                            try stack.append(State { .VarDecl = var_decl_node });
                            continue;
                        },
                        Token.Id.Keyword_fn => {
                            // TODO shouldn't need these casts
                            const fn_proto = try self.createAttachFnProto(arena, ctx.decls, token,
                                ctx.extern_token, ctx.lib_name, (?Token)(null), ctx.visib_token, (?Token)(null));
                            try stack.append(State { .FnDef = fn_proto });
                            try stack.append(State { .FnProto = fn_proto });
                            continue;
                        },
                        Token.Id.Keyword_nakedcc, Token.Id.Keyword_stdcallcc => {
                            const fn_token = try self.eatToken(Token.Id.Keyword_fn);
                            // TODO shouldn't need this cast
                            const fn_proto = try self.createAttachFnProto(arena, ctx.decls, fn_token,
                                ctx.extern_token, ctx.lib_name, (?Token)(token), (?Token)(null), (?Token)(null));
                            try stack.append(State { .FnDef = fn_proto });
                            try stack.append(State { .FnProto = fn_proto });
                            continue;
                        },
                        else => return self.parseError(token, "expected variable declaration or function, found {}", @tagName(token.id)),
                    }
                },
                State.VarDecl => |var_decl| {
                    var_decl.name_token = try self.eatToken(Token.Id.Identifier);
                    stack.append(State { .VarDeclAlign = var_decl }) catch unreachable;

                    const next_token = self.getNextToken();
                    if (next_token.id == Token.Id.Colon) {
                        try stack.append(State { .TypeExpr = DestPtr {.NullableField = &var_decl.type_node} });
                        continue;
                    }

                    self.putBackToken(next_token);
                    continue;
                },
                State.VarDeclAlign => |var_decl| {
                    stack.append(State { .VarDeclEq = var_decl }) catch unreachable;

                    const next_token = self.getNextToken();
                    if (next_token.id == Token.Id.Keyword_align) {
                        _ = try self.eatToken(Token.Id.LParen);
                        try stack.append(State { .ExpectToken = Token.Id.RParen });
                        try stack.append(State { .Expression = DestPtr{.NullableField = &var_decl.align_node} });
                        continue;
                    }

                    self.putBackToken(next_token);
                    continue;
                },
                State.VarDeclEq => |var_decl| {
                    const token = self.getNextToken();
                    if (token.id == Token.Id.Equal) {
                        var_decl.eq_token = token;
                        stack.append(State {
                            .ExpectTokenSave = ExpectTokenSave {
                                .id = Token.Id.Semicolon,
                                .ptr = &var_decl.semicolon_token,
                            },
                        }) catch unreachable;
                        try stack.append(State {
                            .Expression = DestPtr {.NullableField = &var_decl.init_node},
                        });
                        continue;
                    }
                    if (token.id == Token.Id.Semicolon) {
                        var_decl.semicolon_token = token;
                        continue;
                    }
                    return self.parseError(token, "expected '=' or ';', found {}", @tagName(token.id));
                },

                State.ContainerDecl => |container_decl| {
                    const token = self.getNextToken();

                    switch (token.id) {
                        Token.Id.Identifier => {
                            switch (container_decl.kind) {
                                ast.NodeContainerDecl.Kind.Struct => {
                                    const node = try arena.create(ast.NodeStructField);
                                    *node = ast.NodeStructField {
                                        .base = self.initNode(ast.Node.Id.StructField),
                                        .name_token = token,
                                        .type_expr = undefined,
                                    };
                                    try container_decl.fields_and_decls.append(&node.base);

                                    try stack.append(State { .FieldListCommaOrEnd = container_decl });
                                    try stack.append(State { .Expression = DestPtr { .Field = &node.type_expr } });
                                    try stack.append(State { .ExpectToken = Token.Id.Colon });
                                    continue;
                                },
                                ast.NodeContainerDecl.Kind.Union => {
                                    const node = try arena.create(ast.NodeUnionTag);
                                    *node = ast.NodeUnionTag {
                                        .base = self.initNode(ast.Node.Id.UnionTag),
                                        .name_token = token,
                                        .type_expr = null,
                                    };
                                    try container_decl.fields_and_decls.append(&node.base);

                                    try stack.append(State { .FieldListCommaOrEnd = container_decl });

                                    const next = self.getNextToken();
                                    if (next.id != Token.Id.Colon) {
                                        self.putBackToken(next);
                                        continue;
                                    }

                                    try stack.append(State { .Expression = DestPtr { .NullableField = &node.type_expr } });
                                    continue;
                                },
                                ast.NodeContainerDecl.Kind.Enum => {
                                    const node = try arena.create(ast.NodeEnumTag);
                                    *node = ast.NodeEnumTag {
                                        .base = self.initNode(ast.Node.Id.EnumTag),
                                        .name_token = token,
                                        .value = null,
                                    };
                                    try container_decl.fields_and_decls.append(&node.base);

                                    try stack.append(State { .FieldListCommaOrEnd = container_decl });

                                    const next = self.getNextToken();
                                    if (next.id != Token.Id.Equal) {
                                        self.putBackToken(next);
                                        continue;
                                    }

                                    try stack.append(State { .Expression = DestPtr { .NullableField = &node.value } });
                                    continue;
                                },
                            }
                        },
                        Token.Id.Keyword_pub, Token.Id.Keyword_export => {
                            stack.append(State{ .ContainerDecl = container_decl }) catch unreachable;
                            try stack.append(State {
                                .TopLevelExtern = TopLevelDeclCtx {
                                    .decls = &container_decl.fields_and_decls,
                                    .visib_token = token,
                                    .extern_token = null,
                                    .lib_name = null,
                                }
                            });
                            continue;
                        },
                        Token.Id.RBrace => {
                            container_decl.rbrace_token = token;
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            stack.append(State{ .ContainerDecl = container_decl }) catch unreachable;
                            try stack.append(State {
                                .TopLevelExtern = TopLevelDeclCtx {
                                    .decls = &container_decl.fields_and_decls,
                                    .visib_token = null,
                                    .extern_token = null,
                                    .lib_name = null,
                                }
                            });
                            continue;
                        }
                    }
                },

                State.ExpectToken => |token_id| {
                    _ = try self.eatToken(token_id);
                    continue;
                },

                State.ExpectTokenSave => |expect_token_save| {
                    *expect_token_save.ptr = try self.eatToken(expect_token_save.id);
                    continue;
                },

                State.Expression => |dest_ptr| {
                    // save the dest_ptr for later
                    stack.append(state) catch unreachable;
                    try stack.append(State.ExpectOperand);
                    continue;
                },
                State.ExpectOperand => {
                    // we'll either get an operand (like 1 or x),
                    // or a prefix operator (like ~ or return).
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_return => {
                            try stack.append(State { .PrefixOp = try self.createPrefixOp(arena, token,
                                ast.NodePrefixOp.PrefixOp.Return) });
                            try stack.append(State.ExpectOperand);
                            continue;
                        },
                        Token.Id.Keyword_try => {
                            try stack.append(State { .PrefixOp = try self.createPrefixOp(arena, token,
                                ast.NodePrefixOp.PrefixOp.Try) });
                            try stack.append(State.ExpectOperand);
                            continue;
                        },
                        Token.Id.Minus => {
                            try stack.append(State { .PrefixOp = try self.createPrefixOp(arena, token,
                                ast.NodePrefixOp.PrefixOp.Negation) });
                            try stack.append(State.ExpectOperand);
                            continue;
                        },
                        Token.Id.MinusPercent => {
                            try stack.append(State { .PrefixOp = try self.createPrefixOp(arena, token,
                                ast.NodePrefixOp.PrefixOp.NegationWrap) });
                            try stack.append(State.ExpectOperand);
                            continue;
                        },
                        Token.Id.Tilde => {
                            try stack.append(State { .PrefixOp = try self.createPrefixOp(arena, token,
                                ast.NodePrefixOp.PrefixOp.BitNot) });
                            try stack.append(State.ExpectOperand);
                            continue;
                        },
                        Token.Id.QuestionMarkQuestionMark => {
                            try stack.append(State { .PrefixOp = try self.createPrefixOp(arena, token,
                                ast.NodePrefixOp.PrefixOp.UnwrapMaybe) });
                            try stack.append(State.ExpectOperand);
                            continue;
                        },
                        Token.Id.Bang => {
                            try stack.append(State { .PrefixOp = try self.createPrefixOp(arena, token,
                                ast.NodePrefixOp.PrefixOp.BoolNot) });
                            try stack.append(State.ExpectOperand);
                            continue;
                        },
                        Token.Id.Asterisk => {
                            try stack.append(State { .PrefixOp = try self.createPrefixOp(arena, token,
                                ast.NodePrefixOp.PrefixOp.Deref) });
                            try stack.append(State.ExpectOperand);
                            continue;
                        },
                        Token.Id.LBracket => {
                            const rbracket_token = self.getNextToken();
                            if (rbracket_token.id == Token.Id.RBracket) {
                                const prefix_op = try self.createPrefixOp(arena, token, ast.NodePrefixOp.PrefixOp{
                                    .SliceType = ast.NodePrefixOp.AddrOfInfo {
                                        .align_expr = null,
                                        .bit_offset_start_token = null,
                                        .bit_offset_end_token = null,
                                        .const_token = null,
                                        .volatile_token = null,
                                    }
                                });
                                try stack.append(State { .PrefixOp = prefix_op });
                                try stack.append(State.ExpectOperand);
                                try stack.append(State { .AddrOfModifiers = &prefix_op.op.AddrOf });
                                continue;
                            }

                            self.putBackToken(rbracket_token);

                            const prefix_op = try self.createPrefixOp(arena, token, ast.NodePrefixOp.PrefixOp{
                                .ArrayType = undefined,
                            });
                            try stack.append(State { .PrefixOp = prefix_op });
                            try stack.append(State.ExpectOperand);
                            try stack.append(State { .ExpectToken = Token.Id.RBracket });
                            try stack.append(State { .Expression = DestPtr { .Field = &prefix_op.op.ArrayType } });

                        },
                        Token.Id.Ampersand => {
                            const prefix_op = try self.createPrefixOp(arena, token, ast.NodePrefixOp.PrefixOp{
                                .AddrOf = ast.NodePrefixOp.AddrOfInfo {
                                    .align_expr = null,
                                    .bit_offset_start_token = null,
                                    .bit_offset_end_token = null,
                                    .const_token = null,
                                    .volatile_token = null,
                                }
                            });
                            try stack.append(State { .PrefixOp = prefix_op });
                            try stack.append(State.ExpectOperand);
                            try stack.append(State { .AddrOfModifiers = &prefix_op.op.AddrOf });
                            continue;
                        },
                        Token.Id.Identifier => {
                            try stack.append(State {
                                .Operand = &(try self.createIdentifier(arena, token)).base
                            });
                            try stack.append(State.AfterOperand);
                            continue;
                        },
                        Token.Id.IntegerLiteral => {
                            try stack.append(State {
                                .Operand = &(try self.createIntegerLiteral(arena, token)).base
                            });
                            try stack.append(State.AfterOperand);
                            continue;
                        },
                        Token.Id.FloatLiteral => {
                            try stack.append(State {
                                .Operand = &(try self.createFloatLiteral(arena, token)).base
                            });
                            try stack.append(State.AfterOperand);
                            continue;
                        },
                        Token.Id.Keyword_undefined => {
                            try stack.append(State {
                                .Operand = &(try self.createUndefined(arena, token)).base
                            });
                            try stack.append(State.AfterOperand);
                            continue;
                        },
                        Token.Id.Keyword_true, Token.Id.Keyword_false => {
                            const node = try arena.create(ast.NodeBoolLiteral);
                            *node = ast.NodeBoolLiteral {
                                .base = self.initNode(ast.Node.Id.BoolLiteral),
                                .token = token,
                            };
                            try stack.append(State {
                                .Operand = &node.base
                            });
                            try stack.append(State.AfterOperand);
                            continue;
                        },
                        Token.Id.Keyword_null => {
                            const node = try arena.create(ast.NodeNullLiteral);
                            *node = ast.NodeNullLiteral {
                                .base = self.initNode(ast.Node.Id.NullLiteral),
                                .token = token,
                            };
                            try stack.append(State {
                                .Operand = &node.base
                            });
                            try stack.append(State.AfterOperand);
                            continue;
                        },
                        Token.Id.Keyword_this => {
                            const node = try arena.create(ast.NodeThisLiteral);
                            *node = ast.NodeThisLiteral {
                                .base = self.initNode(ast.Node.Id.ThisLiteral),
                                .token = token,
                            };
                            try stack.append(State {
                                .Operand = &node.base
                            });
                            try stack.append(State.AfterOperand);
                            continue;
                        },
                        Token.Id.Keyword_unreachable => {
                            const node = try arena.create(ast.NodeUnreachable);
                            *node = ast.NodeUnreachable {
                                .base = self.initNode(ast.Node.Id.Unreachable),
                                .token = token,
                            };
                            try stack.append(State {
                                .Operand = &node.base
                            });
                            try stack.append(State.AfterOperand);
                            continue;
                        },
                        Token.Id.Keyword_error => {
                            const node = try arena.create(ast.NodeErrorType);
                            *node = ast.NodeErrorType {
                                .base = self.initNode(ast.Node.Id.ErrorType),
                                .token = token,
                            };
                            try stack.append(State {
                                .Operand = &node.base
                            });
                            try stack.append(State.AfterOperand);
                            continue;
                        },
                        Token.Id.Keyword_struct, Token.Id.Keyword_union, Token.Id.Keyword_enum => {
                            const node = try arena.create(ast.NodeContainerDecl);
                            *node = ast.NodeContainerDecl {
                                .base = self.initNode(ast.Node.Id.ContainerDecl),
                                .kind_token = token,
                                .kind = switch (token.id) {
                                    Token.Id.Keyword_struct => ast.NodeContainerDecl.Kind.Struct,
                                    Token.Id.Keyword_union => ast.NodeContainerDecl.Kind.Union,
                                    Token.Id.Keyword_enum => ast.NodeContainerDecl.Kind.Enum,
                                    else => unreachable,
                                },
                                .init_arg_expr = undefined,
                                .fields_and_decls = ArrayList(&ast.Node).init(arena),
                                .rbrace_token = undefined,
                            };

                            try stack.append(State { .Operand = &node.base });
                            try stack.append(State.AfterOperand);
                            try stack.append(State { .ContainerDecl = node });
                            try stack.append(State { .ExpectToken = Token.Id.LBrace });

                            const lparen = self.getNextToken();
                            if (lparen.id != Token.Id.LParen) {
                                self.putBackToken(lparen);
                                node.init_arg_expr = ast.NodeContainerDecl.InitArg.None;
                                continue;
                            }

                            try stack.append(State { .ExpectToken = Token.Id.RParen });

                            const init_arg_token = self.getNextToken();
                            switch (init_arg_token.id) {
                                Token.Id.Keyword_enum => {
                                    node.init_arg_expr = ast.NodeContainerDecl.InitArg.Enum;
                                },
                                else => {
                                    self.putBackToken(lparen);
                                    node.init_arg_expr = ast.NodeContainerDecl.InitArg { .Type = undefined };
                                    try stack.append(State {
                                        .Expression = DestPtr {
                                            .Field = &node.init_arg_expr.Type
                                        }
                                    });
                                },
                            }
                            continue;
                        },
                        Token.Id.Builtin => {
                            const node = try arena.create(ast.NodeBuiltinCall);
                            *node = ast.NodeBuiltinCall {
                                .base = self.initNode(ast.Node.Id.BuiltinCall),
                                .builtin_token = token,
                                .params = ArrayList(&ast.Node).init(arena),
                                .rparen_token = undefined,
                            };
                            try stack.append(State {
                                .Operand = &node.base
                            });
                            try stack.append(State.AfterOperand);
                            try stack.append(State {
                                .ExprListItemOrEnd = ListState(&ast.Node) {
                                    .list = &node.params,
                                    .end = Token.Id.RParen,
                                    .ptr = &node.rparen_token,
                                }
                            });
                            try stack.append(State { .ExpectToken = Token.Id.LParen, });
                            continue;
                        },
                        Token.Id.StringLiteral => {
                            const node = try self.createStringLiteral(arena, token);
                            try stack.append(State {
                                .Operand = &node.base
                            });
                            try stack.append(State.AfterOperand);
                            continue;
                        },
                        Token.Id.CharLiteral => {
                            const node = try arena.create(ast.NodeCharLiteral);
                            *node = ast.NodeCharLiteral {
                                .base = self.initNode(ast.Node.Id.CharLiteral),
                                .token = token,
                            };
                            try stack.append(State {
                                .Operand = &node.base
                            });
                            try stack.append(State.AfterOperand);
                            continue;
                        },
                        Token.Id.MultilineStringLiteralLine => {
                            const node = try arena.create(ast.NodeMultilineStringLiteral);
                            *node = ast.NodeMultilineStringLiteral {
                                .base = self.initNode(ast.Node.Id.MultilineStringLiteral),
                                .tokens = ArrayList(Token).init(arena),
                            };
                            try node.tokens.append(token);

                            while (true) {
                                const multiline_str = self.getNextToken();
                                if (multiline_str.id != Token.Id.MultilineStringLiteralLine) {
                                    self.putBackToken(multiline_str);
                                    break;
                                }

                                try node.tokens.append(multiline_str);
                            }

                            try stack.append(State {
                                .Operand = &node.base
                            });
                            try stack.append(State.AfterOperand);
                            continue;
                        },
                        Token.Id.LParen => {
                            const node = try arena.create(ast.NodeGroupedExpression);
                            *node = ast.NodeGroupedExpression {
                                .base = self.initNode(ast.Node.Id.GroupedExpression),
                                .lparen = token,
                                .expr = undefined,
                                .rparen = undefined,
                            };
                            try stack.append(State {
                                .Operand = &node.base
                            });
                            try stack.append(State.AfterOperand);
                            try stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.RParen,
                                    .ptr = &node.rparen,
                                }
                            });
                            try stack.append(State { .Expression = DestPtr { .Field = &node.expr } });
                            continue;
                        },

                        else => return self.parseError(token, "expected primary expression, found {}", @tagName(token.id)),
                    }
                },

                State.SliceOrArrayAccess => |node| {
                    var token = self.getNextToken();

                    switch (token.id) {
                        Token.Id.Ellipsis2 => {
                            const start = node.op.ArrayAccess;
                            node.op = ast.NodeSuffixOp.SuffixOp {
                                .Slice = ast.NodeSuffixOp.SliceRange {
                                    .start = start,
                                    .end = undefined,
                                }
                            };
                            try stack.append(State { .SuffixOp = node });
                            try stack.append(State.AfterOperand);

                            const rbracket_token = self.getNextToken();
                            if (rbracket_token.id != Token.Id.RBracket) {
                                self.putBackToken(rbracket_token);
                                try stack.append(State {
                                    .ExpectTokenSave = ExpectTokenSave {
                                        .id = Token.Id.RBracket,
                                        .ptr = &node.rtoken,
                                    }
                                });
                                try stack.append(State { .Expression = DestPtr { .NullableField = &node.op.Slice.end } });
                            } else {
                                node.rtoken = rbracket_token;
                            }
                            continue;
                        },
                        Token.Id.RBracket => {
                            node.rtoken = token;
                            try stack.append(State { .SuffixOp = node });
                            try stack.append(State.AfterOperand);
                            continue;
                        },
                        else => return self.parseError(token, "expected ']' or '..', found {}", @tagName(token.id))
                    }
                },

                State.AfterOperand => {
                    // we'll either get an infix operator (like != or ^),
                    // or a postfix operator (like () or {}),
                    // otherwise this expression is done (like on a ; or else).
                    var token = self.getNextToken();
                    if (tokenIdToInfixOp(token.id)) |infix_id| {
                            try stack.append(State {
                                .InfixOp = try self.createInfixOp(arena, token, infix_id)
                            });
                            try stack.append(State.ExpectOperand);
                            continue;

                    } else if (token.id == Token.Id.LParen) {
                        const node = try self.createSuffixOp(arena, ast.NodeSuffixOp.SuffixOp {
                            .Call = ast.NodeSuffixOp.CallInfo {
                                .params = ArrayList(&ast.Node).init(arena),
                                .is_async = false, // TODO: ASYNC
                            }
                        });
                        try stack.append(State { .SuffixOp = node });
                        try stack.append(State.AfterOperand);
                        try stack.append(State {
                            .ExprListItemOrEnd = ListState(&ast.Node) {
                                .list = &node.op.Call.params,
                                .end = Token.Id.RParen,
                                .ptr = &node.rtoken,
                            }
                        });
                        continue;

                    } else if (token.id == Token.Id.LBracket) {
                        const node = try arena.create(ast.NodeSuffixOp);
                        *node = ast.NodeSuffixOp {
                            .base = self.initNode(ast.Node.Id.SuffixOp),
                            .lhs = undefined,
                            .op = ast.NodeSuffixOp.SuffixOp {
                                .ArrayAccess = undefined,
                            },
                            .rtoken = undefined,
                        };
                        try stack.append(State { .SliceOrArrayAccess = node });
                        try stack.append(State { .Expression = DestPtr { .Field = &node.op.ArrayAccess }});
                        continue;

                    // TODO: This is the initializer parsing code. It doesn't work because of
                    //       the ambiguity between function bodies and initializers:
                    //       fn main() void {} or fn main() (void {})
                    } else if (false) { //(token.id == Token.Id.LBrace) {
                        const next = self.getNextToken();

                        switch (next.id) {
                            Token.Id.Period => {
                                self.putBackToken(token);

                                const node = try self.createSuffixOp(arena, ast.NodeSuffixOp.SuffixOp {
                                    .StructInitializer = ArrayList(&ast.NodeFieldInitializer).init(arena),
                                });

                                try stack.append(State {
                                    .FieldInitListItemOrEnd = ListState(&ast.NodeFieldInitializer) {
                                        .list = &node.op.StructInitializer,
                                        .end = Token.Id.RBrace,
                                        .ptr = &node.rtoken,
                                    }
                                });
                                continue;
                            },
                            else => {
                                self.putBackToken(token);

                                const node = try self.createSuffixOp(arena, ast.NodeSuffixOp.SuffixOp {
                                    .ArrayInitializer = ArrayList(&ast.Node).init(arena),
                                });

                                try stack.append(State {
                                    .ExprListItemOrEnd = ListState(&ast.Node) {
                                        .list = &node.op.ArrayInitializer,
                                        .end = Token.Id.RBrace,
                                        .ptr = &node.rtoken,
                                    }
                                });
                                continue;
                            },
                        }

                    // TODO: Parse postfix operator
                    } else {
                        // no postfix/infix operator after this operand.
                        self.putBackToken(token);

                        var expression = popSuffixOp(&stack);
                        while (true) {
                            switch (stack.pop()) {
                                State.Expression => |dest_ptr| {
                                    // we're done
                                    try dest_ptr.store(expression);
                                    break;
                                },
                                State.InfixOp => |infix_op| {
                                    infix_op.rhs = expression;
                                    infix_op.lhs = popSuffixOp(&stack);
                                    expression = &infix_op.base;
                                    continue;
                                },
                                State.PrefixOp => |prefix_op| {
                                    prefix_op.rhs = expression;
                                    expression = &prefix_op.base;
                                    continue;
                                },
                                else => unreachable,
                            }
                        }
                        continue;
                    }
                },

                State.ExprListItemOrEnd => |list_state| {
                    var token = self.getNextToken();

                    const IdTag = @TagType(Token.Id);
                    if (IdTag(list_state.end) == token.id) {
                        *list_state.ptr = token;
                        continue;
                    }

                    self.putBackToken(token);
                    stack.append(State { .ExprListCommaOrEnd = list_state }) catch unreachable;
                    try stack.append(State { .Expression = DestPtr{.List = list_state.list} });
                },

                State.FieldInitListItemOrEnd => |list_state| {
                    var token = self.getNextToken();

                    const IdTag = @TagType(Token.Id);
                    if (IdTag(list_state.end) == token.id){
                        *list_state.ptr = token;
                        continue;
                    }

                    self.putBackToken(token);

                    const node = try arena.create(ast.NodeFieldInitializer);
                    *node = ast.NodeFieldInitializer {
                        .base = self.initNode(ast.Node.Id.FieldInitializer),
                        .period_token = undefined,
                        .name_token = undefined,
                        .expr = undefined,
                    };
                    try list_state.list.append(node);

                    stack.append(State { .FieldInitListCommaOrEnd = list_state }) catch unreachable;
                    try stack.append(State { .Expression = DestPtr{.Field = &node.expr} });
                    try stack.append(State { .ExpectToken = Token.Id.Equal });
                    try stack.append(State {
                        .ExpectTokenSave = ExpectTokenSave {
                            .id = Token.Id.Identifier,
                            .ptr = &node.name_token,
                        }
                    });
                    try stack.append(State {
                        .ExpectTokenSave = ExpectTokenSave {
                            .id = Token.Id.Period,
                            .ptr = &node.period_token,
                        }
                    });
                },

                State.ExprListCommaOrEnd => |list_state| {
                    try self.commaOrEnd(&stack, list_state.end, list_state.ptr, State { .ExprListItemOrEnd = list_state });
                    continue;
                },

                State.FieldInitListCommaOrEnd => |list_state| {
                    try self.commaOrEnd(&stack, list_state.end, list_state.ptr, State { .FieldInitListItemOrEnd = list_state });
                    continue;
                },

                State.FieldListCommaOrEnd => |container_decl| {
                    try self.commaOrEnd(&stack, Token.Id.RBrace, &container_decl.rbrace_token,
                        State { .ContainerDecl = container_decl });
                    continue;
                },

                State.AddrOfModifiers => |addr_of_info| {
                    var token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_align => {
                            stack.append(state) catch unreachable;
                            if (addr_of_info.align_expr != null) return self.parseError(token, "multiple align qualifiers");
                            _ = try self.eatToken(Token.Id.LParen);
                            try stack.append(State { .ExpectToken = Token.Id.RParen });
                            try stack.append(State { .Expression = DestPtr{.NullableField = &addr_of_info.align_expr} });
                            continue;
                        },
                        Token.Id.Keyword_const => {
                            stack.append(state) catch unreachable;
                            if (addr_of_info.const_token != null) return self.parseError(token, "duplicate qualifier: const");
                            addr_of_info.const_token = token;
                            continue;
                        },
                        Token.Id.Keyword_volatile => {
                            stack.append(state) catch unreachable;
                            if (addr_of_info.volatile_token != null) return self.parseError(token, "duplicate qualifier: volatile");
                            addr_of_info.volatile_token = token;
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            continue;
                        },
                    }
                },

                State.TypeExpr => |dest_ptr| {
                    const token = self.getNextToken();
                    if (token.id == Token.Id.Keyword_var) {
                        @panic("TODO param with type var");
                    }
                    self.putBackToken(token);

                    stack.append(State { .Expression = dest_ptr }) catch unreachable;
                    continue;
                },

                State.FnProto => |fn_proto| {
                    stack.append(State { .FnProtoAlign = fn_proto }) catch unreachable;
                    try stack.append(State { .ParamDecl = fn_proto });
                    try stack.append(State { .ExpectToken = Token.Id.LParen });

                    const next_token = self.getNextToken();
                    if (next_token.id == Token.Id.Identifier) {
                        fn_proto.name_token = next_token;
                        continue;
                    }
                    self.putBackToken(next_token);
                    continue;
                },

                State.FnProtoAlign => |fn_proto| {
                    const token = self.getNextToken();
                    if (token.id == Token.Id.Keyword_align) {
                        @panic("TODO fn proto align");
                    }
                    self.putBackToken(token);
                    stack.append(State {
                        .FnProtoReturnType = fn_proto,
                    }) catch unreachable;
                    continue;
                },

                State.FnProtoReturnType => |fn_proto| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_var => {
                            fn_proto.return_type = ast.NodeFnProto.ReturnType { .Infer = token };
                        },
                        Token.Id.Bang => {
                            fn_proto.return_type = ast.NodeFnProto.ReturnType { .InferErrorSet = undefined };
                            stack.append(State {
                                .TypeExpr = DestPtr {.Field = &fn_proto.return_type.InferErrorSet},
                            }) catch unreachable;
                        },
                        else => {
                            self.putBackToken(token);
                            fn_proto.return_type = ast.NodeFnProto.ReturnType { .Explicit = undefined };
                            stack.append(State {
                                .TypeExpr = DestPtr {.Field = &fn_proto.return_type.Explicit},
                            }) catch unreachable;
                        },
                    }
                    if (token.id == Token.Id.Keyword_align) {
                        @panic("TODO fn proto align");
                    }
                    continue;
                },

                State.ParamDecl => |fn_proto| {
                    var token = self.getNextToken();
                    if (token.id == Token.Id.RParen) {
                        continue;
                    }
                    const param_decl = try self.createAttachParamDecl(arena, &fn_proto.params);
                    if (token.id == Token.Id.Keyword_comptime) {
                        param_decl.comptime_token = token;
                        token = self.getNextToken();
                    } else if (token.id == Token.Id.Keyword_noalias) {
                        param_decl.noalias_token = token;
                        token = self.getNextToken();
                    }
                    if (token.id == Token.Id.Identifier) {
                        const next_token = self.getNextToken();
                        if (next_token.id == Token.Id.Colon) {
                            param_decl.name_token = token;
                            token = self.getNextToken();
                        } else {
                            self.putBackToken(next_token);
                        }
                    }
                    if (token.id == Token.Id.Ellipsis3) {
                        param_decl.var_args_token = token;
                        stack.append(State { .ExpectToken = Token.Id.RParen }) catch unreachable;
                        continue;
                    } else {
                        self.putBackToken(token);
                    }

                    stack.append(State { .ParamDecl = fn_proto }) catch unreachable;
                    try stack.append(State.ParamDeclComma);
                    try stack.append(State {
                        .TypeExpr = DestPtr {.Field = &param_decl.type_node}
                    });
                    continue;
                },

                State.ParamDeclComma => {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.RParen => {
                            _ = stack.pop(); // pop off the ParamDecl
                            continue;
                        },
                        Token.Id.Comma => continue,
                        else => return self.parseError(token, "expected ',' or ')', found {}", @tagName(token.id)),
                    }
                },

                State.FnDef => |fn_proto| {
                    const token = self.getNextToken();
                    switch(token.id) {
                        Token.Id.LBrace => {
                            const block = try self.createBlock(arena, token);
                            fn_proto.body_node = &block.base;
                            stack.append(State { .Block = block }) catch unreachable;
                            continue;
                        },
                        Token.Id.Semicolon => continue,
                        else => return self.parseError(token, "expected ';' or '{{', found {}", @tagName(token.id)),
                    }
                },

                State.Block => |block| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.RBrace => {
                            block.end_token = token;
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            stack.append(State { .Block = block }) catch unreachable;
                            try stack.append(State { .Statement = block });
                            continue;
                        },
                    }
                },

                State.Statement => |block| {
                    {
                        // Look for comptime var, comptime const
                        const comptime_token = self.getNextToken();
                        if (comptime_token.id == Token.Id.Keyword_comptime) {
                            const mut_token = self.getNextToken();
                            if (mut_token.id == Token.Id.Keyword_var or mut_token.id == Token.Id.Keyword_const) {
                                // TODO shouldn't need these casts
                                const var_decl = try self.createAttachVarDecl(arena, &block.statements, (?Token)(null),
                                    mut_token, (?Token)(comptime_token), (?Token)(null), null);
                                try stack.append(State { .VarDecl = var_decl });
                                continue;
                            }
                            self.putBackToken(mut_token);
                        }
                        self.putBackToken(comptime_token);
                    }
                    {
                        // Look for const, var
                        const mut_token = self.getNextToken();
                        if (mut_token.id == Token.Id.Keyword_var or mut_token.id == Token.Id.Keyword_const) {
                            // TODO shouldn't need these casts
                            const var_decl = try self.createAttachVarDecl(arena, &block.statements, (?Token)(null),
                                mut_token, (?Token)(null), (?Token)(null), null);
                            try stack.append(State { .VarDecl = var_decl });
                            continue;
                        }
                        self.putBackToken(mut_token);
                    }

                    stack.append(State { .ExpectToken = Token.Id.Semicolon }) catch unreachable;
                    try stack.append(State { .Expression = DestPtr{.List = &block.statements} });
                    continue;
                },

                // These are data, not control flow.
                State.InfixOp => unreachable,
                State.PrefixOp => unreachable,
                State.SuffixOp => unreachable,
                State.Operand => unreachable,
            }
        }
    }

    fn commaOrEnd(self: &Parser, stack: &ArrayList(State), end: &const Token.Id, ptr: &Token, state_after_comma: &const State) !void {
        var token = self.getNextToken();
        switch (token.id) {
            Token.Id.Comma => {
                stack.append(state_after_comma) catch unreachable;
            },
            else => {
                const IdTag = @TagType(Token.Id);
                if (IdTag(*end) == token.id) {
                    *ptr = token;
                    return;
                }

                return self.parseError(token, "expected ',' or {}, found {}", @tagName(*end), @tagName(token.id));
            },
        }
    }

    fn popSuffixOp(stack: &ArrayList(State)) &ast.Node {
        var expression: &ast.Node = undefined;
        var left_leaf_ptr: &&ast.Node = &expression;
        while (true) {
            switch (stack.pop()) {
                State.SuffixOp => |suffix_op| {
                    *left_leaf_ptr = &suffix_op.base;
                    left_leaf_ptr = &suffix_op.lhs;
                },
                State.Operand => |operand| {
                    *left_leaf_ptr = operand;
                    break;
                },
                else => unreachable,
            }
        }

        return expression;
    }

    fn tokenIdToInfixOp(id: &const Token.Id) ?ast.NodeInfixOp.InfixOp {
        return switch (*id) {
            Token.Id.Ampersand => ast.NodeInfixOp.InfixOp.BitAnd,
            Token.Id.AmpersandEqual => ast.NodeInfixOp.InfixOp.AssignBitAnd,
            Token.Id.AngleBracketAngleBracketLeft => ast.NodeInfixOp.InfixOp.BitShiftLeft,
            Token.Id.AngleBracketAngleBracketLeftEqual => ast.NodeInfixOp.InfixOp.AssignBitShiftLeft,
            Token.Id.AngleBracketAngleBracketRight => ast.NodeInfixOp.InfixOp.BitShiftRight,
            Token.Id.AngleBracketAngleBracketRightEqual => ast.NodeInfixOp.InfixOp.AssignBitShiftRight,
            Token.Id.AngleBracketLeft => ast.NodeInfixOp.InfixOp.LessThan,
            Token.Id.AngleBracketLeftEqual => ast.NodeInfixOp.InfixOp.LessOrEqual,
            Token.Id.AngleBracketRight => ast.NodeInfixOp.InfixOp.GreaterThan,
            Token.Id.AngleBracketRightEqual => ast.NodeInfixOp.InfixOp.GreaterOrEqual,
            Token.Id.Asterisk => ast.NodeInfixOp.InfixOp.Mult,
            Token.Id.AsteriskAsterisk => ast.NodeInfixOp.InfixOp.ArrayMult,
            Token.Id.AsteriskEqual => ast.NodeInfixOp.InfixOp.AssignTimes,
            Token.Id.AsteriskPercent => ast.NodeInfixOp.InfixOp.MultWrap,
            Token.Id.AsteriskPercentEqual => ast.NodeInfixOp.InfixOp.AssignTimesWarp,
            Token.Id.Bang => ast.NodeInfixOp.InfixOp.ErrorUnion,
            Token.Id.BangEqual => ast.NodeInfixOp.InfixOp.BangEqual,
            Token.Id.Caret => ast.NodeInfixOp.InfixOp.BitXor,
            Token.Id.CaretEqual => ast.NodeInfixOp.InfixOp.AssignBitXor,
            Token.Id.Equal => ast.NodeInfixOp.InfixOp.Assign,
            Token.Id.EqualEqual => ast.NodeInfixOp.InfixOp.EqualEqual,
            Token.Id.Keyword_and => ast.NodeInfixOp.InfixOp.BoolAnd,
            Token.Id.Keyword_or => ast.NodeInfixOp.InfixOp.BoolOr,
            Token.Id.Minus => ast.NodeInfixOp.InfixOp.Sub,
            Token.Id.MinusEqual => ast.NodeInfixOp.InfixOp.AssignMinus,
            Token.Id.MinusPercent => ast.NodeInfixOp.InfixOp.SubWrap,
            Token.Id.MinusPercentEqual => ast.NodeInfixOp.InfixOp.AssignMinusWrap,
            Token.Id.Percent => ast.NodeInfixOp.InfixOp.Mod,
            Token.Id.PercentEqual => ast.NodeInfixOp.InfixOp.AssignMod,
            Token.Id.Period => ast.NodeInfixOp.InfixOp.Period,
            Token.Id.Pipe => ast.NodeInfixOp.InfixOp.BitOr,
            Token.Id.PipeEqual => ast.NodeInfixOp.InfixOp.AssignBitOr,
            Token.Id.PipePipe => ast.NodeInfixOp.InfixOp.MergeErrorSets,
            Token.Id.Plus => ast.NodeInfixOp.InfixOp.Add,
            Token.Id.PlusEqual => ast.NodeInfixOp.InfixOp.AssignPlus,
            Token.Id.PlusPercent => ast.NodeInfixOp.InfixOp.AddWrap,
            Token.Id.PlusPercentEqual => ast.NodeInfixOp.InfixOp.AssignPlusWrap,
            Token.Id.PlusPlus => ast.NodeInfixOp.InfixOp.ArrayCat,
            Token.Id.QuestionMarkQuestionMark => ast.NodeInfixOp.InfixOp.UnwrapMaybe,
            Token.Id.Slash => ast.NodeInfixOp.InfixOp.Div,
            Token.Id.SlashEqual => ast.NodeInfixOp.InfixOp.AssignDiv,
            else => null,
        };
    }

    fn initNode(self: &Parser, id: ast.Node.Id) ast.Node {
        if (self.pending_line_comment_node) |comment_node| {
            self.pending_line_comment_node = null;
            return ast.Node {.id = id, .comment = comment_node};
        }
        return ast.Node {.id = id, .comment = null };
    }

    fn createRoot(self: &Parser, arena: &mem.Allocator) !&ast.NodeRoot {
        const node = try arena.create(ast.NodeRoot);

        *node = ast.NodeRoot {
            .base = self.initNode(ast.Node.Id.Root),
            .decls = ArrayList(&ast.Node).init(arena),
            // initialized when we get the eof token
            .eof_token = undefined,
        };
        return node;
    }

    fn createVarDecl(self: &Parser, arena: &mem.Allocator, visib_token: &const ?Token, mut_token: &const Token,
        comptime_token: &const ?Token, extern_token: &const ?Token, lib_name: ?&ast.Node) !&ast.NodeVarDecl
    {
        const node = try arena.create(ast.NodeVarDecl);

        *node = ast.NodeVarDecl {
            .base = self.initNode(ast.Node.Id.VarDecl),
            .visib_token = *visib_token,
            .mut_token = *mut_token,
            .comptime_token = *comptime_token,
            .extern_token = *extern_token,
            .type_node = null,
            .align_node = null,
            .init_node = null,
            .lib_name = lib_name,
            // initialized later
            .name_token = undefined,
            .eq_token = undefined,
            .semicolon_token = undefined,
        };
        return node;
    }

    fn createStringLiteral(self: &Parser, arena: &mem.Allocator, token: &const Token) !&ast.NodeStringLiteral {
        const node = try arena.create(ast.NodeStringLiteral);

        assert(token.id == Token.Id.StringLiteral);
        *node = ast.NodeStringLiteral {
            .base = self.initNode(ast.Node.Id.StringLiteral),
            .token = *token,
        };
        return node;
    }

    fn createTestDecl(self: &Parser, arena: &mem.Allocator, test_token: &const Token, name: &ast.Node,
        block: &ast.NodeBlock) !&ast.NodeTestDecl
    {
        const node = try arena.create(ast.NodeTestDecl);

        *node = ast.NodeTestDecl {
            .base = self.initNode(ast.Node.Id.TestDecl),
            .test_token = *test_token,
            .name = name,
            .body_node = &block.base,
        };
        return node;
    }

    fn createFnProto(self: &Parser, arena: &mem.Allocator, fn_token: &const Token, extern_token: &const ?Token,
        lib_name: ?&ast.Node, cc_token: &const ?Token, visib_token: &const ?Token, inline_token: &const ?Token) !&ast.NodeFnProto
    {
        const node = try arena.create(ast.NodeFnProto);

        *node = ast.NodeFnProto {
            .base = self.initNode(ast.Node.Id.FnProto),
            .visib_token = *visib_token,
            .name_token = null,
            .fn_token = *fn_token,
            .params = ArrayList(&ast.Node).init(arena),
            .return_type = undefined,
            .var_args_token = null,
            .extern_token = *extern_token,
            .inline_token = *inline_token,
            .cc_token = *cc_token,
            .body_node = null,
            .lib_name = lib_name,
            .align_expr = null,
        };
        return node;
    }

    fn createParamDecl(self: &Parser, arena: &mem.Allocator) !&ast.NodeParamDecl {
        const node = try arena.create(ast.NodeParamDecl);

        *node = ast.NodeParamDecl {
            .base = self.initNode(ast.Node.Id.ParamDecl),
            .comptime_token = null,
            .noalias_token = null,
            .name_token = null,
            .type_node = undefined,
            .var_args_token = null,
        };
        return node;
    }

    fn createBlock(self: &Parser, arena: &mem.Allocator, begin_token: &const Token) !&ast.NodeBlock {
        const node = try arena.create(ast.NodeBlock);

        *node = ast.NodeBlock {
            .base = self.initNode(ast.Node.Id.Block),
            .begin_token = *begin_token,
            .end_token = undefined,
            .statements = ArrayList(&ast.Node).init(arena),
        };
        return node;
    }

    fn createInfixOp(self: &Parser, arena: &mem.Allocator, op_token: &const Token, op: &const ast.NodeInfixOp.InfixOp) !&ast.NodeInfixOp {
        const node = try arena.create(ast.NodeInfixOp);

        *node = ast.NodeInfixOp {
            .base = self.initNode(ast.Node.Id.InfixOp),
            .op_token = *op_token,
            .lhs = undefined,
            .op = *op,
            .rhs = undefined,
        };
        return node;
    }

    fn createPrefixOp(self: &Parser, arena: &mem.Allocator, op_token: &const Token, op: &const ast.NodePrefixOp.PrefixOp) !&ast.NodePrefixOp {
        const node = try arena.create(ast.NodePrefixOp);

        *node = ast.NodePrefixOp {
            .base = self.initNode(ast.Node.Id.PrefixOp),
            .op_token = *op_token,
            .op = *op,
            .rhs = undefined,
        };
        return node;
    }

    fn createSuffixOp(self: &Parser, arena: &mem.Allocator, op: &const ast.NodeSuffixOp.SuffixOp) !&ast.NodeSuffixOp {
        const node = try arena.create(ast.NodeSuffixOp);

        *node = ast.NodeSuffixOp {
            .base = self.initNode(ast.Node.Id.SuffixOp),
            .lhs = undefined,
            .op = *op,
            .rtoken = undefined,
        };
        return node;
    }

    fn createIdentifier(self: &Parser, arena: &mem.Allocator, name_token: &const Token) !&ast.NodeIdentifier {
        const node = try arena.create(ast.NodeIdentifier);

        *node = ast.NodeIdentifier {
            .base = self.initNode(ast.Node.Id.Identifier),
            .name_token = *name_token,
        };
        return node;
    }

    fn createIntegerLiteral(self: &Parser, arena: &mem.Allocator, token: &const Token) !&ast.NodeIntegerLiteral {
        const node = try arena.create(ast.NodeIntegerLiteral);

        *node = ast.NodeIntegerLiteral {
            .base = self.initNode(ast.Node.Id.IntegerLiteral),
            .token = *token,
        };
        return node;
    }

    fn createFloatLiteral(self: &Parser, arena: &mem.Allocator, token: &const Token) !&ast.NodeFloatLiteral {
        const node = try arena.create(ast.NodeFloatLiteral);

        *node = ast.NodeFloatLiteral {
            .base = self.initNode(ast.Node.Id.FloatLiteral),
            .token = *token,
        };
        return node;
    }

    fn createUndefined(self: &Parser, arena: &mem.Allocator, token: &const Token) !&ast.NodeUndefinedLiteral {
        const node = try arena.create(ast.NodeUndefinedLiteral);

        *node = ast.NodeUndefinedLiteral {
            .base = self.initNode(ast.Node.Id.UndefinedLiteral),
            .token = *token,
        };
        return node;
    }

    fn createAttachIdentifier(self: &Parser, arena: &mem.Allocator, dest_ptr: &const DestPtr, name_token: &const Token) !&ast.NodeIdentifier {
        const node = try self.createIdentifier(arena, name_token);
        try dest_ptr.store(&node.base);
        return node;
    }

    fn createAttachParamDecl(self: &Parser, arena: &mem.Allocator, list: &ArrayList(&ast.Node)) !&ast.NodeParamDecl {
        const node = try self.createParamDecl(arena);
        try list.append(&node.base);
        return node;
    }

    fn createAttachFnProto(self: &Parser, arena: &mem.Allocator, list: &ArrayList(&ast.Node), fn_token: &const Token,
        extern_token: &const ?Token, lib_name: ?&ast.Node, cc_token: &const ?Token, visib_token: &const ?Token,
        inline_token: &const ?Token) !&ast.NodeFnProto
    {
        const node = try self.createFnProto(arena, fn_token, extern_token, lib_name, cc_token, visib_token, inline_token);
        try list.append(&node.base);
        return node;
    }

    fn createAttachVarDecl(self: &Parser, arena: &mem.Allocator, list: &ArrayList(&ast.Node),
        visib_token: &const ?Token, mut_token: &const Token, comptime_token: &const ?Token,
        extern_token: &const ?Token, lib_name: ?&ast.Node) !&ast.NodeVarDecl
    {
        const node = try self.createVarDecl(arena, visib_token, mut_token, comptime_token, extern_token, lib_name);
        try list.append(&node.base);
        return node;
    }

    fn createAttachTestDecl(self: &Parser, arena: &mem.Allocator, list: &ArrayList(&ast.Node),
        test_token: &const Token, name: &ast.Node, block: &ast.NodeBlock) !&ast.NodeTestDecl
    {
        const node = try self.createTestDecl(arena, test_token, name, block);
        try list.append(&node.base);
        return node;
    }

    fn parseError(self: &Parser, token: &const Token, comptime fmt: []const u8, args: ...) (error{ParseError}) {
        const loc = self.tokenizer.getTokenLocation(token);
        warn("{}:{}:{}: error: " ++ fmt ++ "\n", self.source_file_name, token.line + 1, token.column + 1, args);
        warn("{}\n", self.tokenizer.buffer[loc.line_start..loc.line_end]);
        {
            var i: usize = 0;
            while (i < token.column) : (i += 1) {
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

    fn expectToken(self: &Parser, token: &const Token, id: @TagType(Token.Id)) !void {
        if (token.id != id) {
            return self.parseError(token, "expected {}, found {}", @tagName(id), @tagName(token.id));
        }
    }

    fn eatToken(self: &Parser, id: @TagType(Token.Id)) !Token {
        const token = self.getNextToken();
        try self.expectToken(token, id);
        return token;
    }

    fn putBackToken(self: &Parser, token: &const Token) void {
        self.put_back_tokens[self.put_back_count] = *token;
        self.put_back_count += 1;
    }

    fn getNextToken(self: &Parser) Token {
        if (self.put_back_count != 0) {
            const put_back_index = self.put_back_count - 1;
            const put_back_token = self.put_back_tokens[put_back_index];
            self.put_back_count = put_back_index;
            return put_back_token;
        } else {
            return self.tokenizer.next();
        }
    }

    const RenderAstFrame = struct {
        node: &ast.Node,
        indent: usize,
    };

    pub fn renderAst(self: &Parser, stream: var, root_node: &ast.NodeRoot) !void {
        var stack = self.initUtilityArrayList(RenderAstFrame);
        defer self.deinitUtilityArrayList(stack);

        try stack.append(RenderAstFrame {
            .node = &root_node.base,
            .indent = 0,
        });

        while (stack.popOrNull()) |frame| {
            {
                var i: usize = 0;
                while (i < frame.indent) : (i += 1) {
                    try stream.print(" ");
                }
            }
            try stream.print("{}\n", @tagName(frame.node.id));
            var child_i: usize = 0;
            while (frame.node.iterate(child_i)) |child| : (child_i += 1) {
                try stack.append(RenderAstFrame {
                    .node = child,
                    .indent = frame.indent + 2,
                });
            }
        }
    }

    const RenderState = union(enum) {
        TopLevelDecl: &ast.Node,
        FnProtoRParen: &ast.NodeFnProto,
        ParamDecl: &ast.Node,
        Text: []const u8,
        Expression: &ast.Node,
        VarDecl: &ast.NodeVarDecl,
        Statement: &ast.Node,
        PrintIndent,
        Indent: usize,
    };

    pub fn renderSource(self: &Parser, stream: var, root_node: &ast.NodeRoot) !void {
        var stack = self.initUtilityArrayList(RenderState);
        defer self.deinitUtilityArrayList(stack);

        {
            try stack.append(RenderState { .Text = "\n"});

            var i = root_node.decls.len;
            while (i != 0) {
                i -= 1;
                const decl = root_node.decls.items[i];
                try stack.append(RenderState {.TopLevelDecl = decl});
                if (i != 0) {
                    try stack.append(RenderState {
                        .Text = blk: {
                            const prev_node = root_node.decls.at(i - 1);
                            const prev_line_index = prev_node.lastToken().line;
                            const this_line_index = decl.firstToken().line;
                            if (this_line_index - prev_line_index >= 2) {
                                break :blk "\n\n";
                            }
                            break :blk "\n";
                        },
                    });
                }
            }
        }

        const indent_delta = 4;
        var indent: usize = 0;
        while (stack.popOrNull()) |state| {
            switch (state) {
                RenderState.TopLevelDecl => |decl| {
                    switch (decl.id) {
                        ast.Node.Id.FnProto => {
                            const fn_proto = @fieldParentPtr(ast.NodeFnProto, "base", decl);

                            if (fn_proto.body_node == null) {
                                try stack.append(RenderState { .Text = ";" });
                            }

                            try stack.append(RenderState { .FnProtoRParen = fn_proto});
                            var i = fn_proto.params.len;
                            while (i != 0) {
                                i -= 1;
                                const param_decl_node = fn_proto.params.items[i];
                                try stack.append(RenderState { .ParamDecl = param_decl_node});
                                if (i != 0) {
                                    try stack.append(RenderState { .Text = ", " });
                                }
                            }

                            try stack.append(RenderState { .Text = "(" });
                            if (fn_proto.name_token) |name_token| {
                                try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(name_token) });
                            }

                            try stack.append(RenderState { .Text = "fn " });
                            if (fn_proto.lib_name) |lib_name| {
                                try stack.append(RenderState { .Text = " " });
                                try stack.append(RenderState { .Expression = lib_name });
                            }
                            if (fn_proto.extern_token) |extern_token| {
                                try stack.append(RenderState { .Text = " " });
                                try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(extern_token) });
                            }

                            if (fn_proto.visib_token) |visib_token| {
                                assert(visib_token.id == Token.Id.Keyword_pub or visib_token.id == Token.Id.Keyword_export);
                                try stack.append(RenderState { .Text = " " });
                                try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(visib_token) });
                            }
                        },
                        ast.Node.Id.VarDecl => {
                            const var_decl = @fieldParentPtr(ast.NodeVarDecl, "base", decl);
                            try stack.append(RenderState { .VarDecl = var_decl});
                        },
                        ast.Node.Id.TestDecl => {
                            const test_decl = @fieldParentPtr(ast.NodeTestDecl, "base", decl);
                            try stream.print("test ");
                            try stack.append(RenderState { .Expression = test_decl.body_node });
                            try stack.append(RenderState { .Text = " " });
                            try stack.append(RenderState { .Expression = test_decl.name });
                        },
                        else => unreachable,
                    }
                },

                RenderState.VarDecl => |var_decl| {
                    try stack.append(RenderState { .Text = ";" });
                    if (var_decl.init_node) |init_node| {
                        try stack.append(RenderState { .Expression = init_node });
                        try stack.append(RenderState { .Text = " = " });
                    }
                    if (var_decl.align_node) |align_node| {
                        try stack.append(RenderState { .Text = ")" });
                        try stack.append(RenderState { .Expression = align_node });
                        try stack.append(RenderState { .Text = " align(" });
                    }
                    if (var_decl.type_node) |type_node| {
                        try stack.append(RenderState { .Expression = type_node });
                        try stack.append(RenderState { .Text = ": " });
                    }
                    try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(var_decl.name_token) });
                    try stack.append(RenderState { .Text = " " });
                    try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(var_decl.mut_token) });

                    if (var_decl.comptime_token) |comptime_token| {
                        try stack.append(RenderState { .Text = " " });
                        try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(comptime_token) });
                    }

                    if (var_decl.extern_token) |extern_token| {
                        if (var_decl.lib_name != null) {
                            try stack.append(RenderState { .Text = " " });
                            try stack.append(RenderState { .Expression = ??var_decl.lib_name });
                        }
                        try stack.append(RenderState { .Text = " " });
                        try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(extern_token) });
                    }

                    if (var_decl.visib_token) |visib_token| {
                        try stack.append(RenderState { .Text = " " });
                        try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(visib_token) });
                    }
                },

                RenderState.ParamDecl => |base| {
                    const param_decl = @fieldParentPtr(ast.NodeParamDecl, "base", base);
                    if (param_decl.comptime_token) |comptime_token| {
                        try stream.print("{} ", self.tokenizer.getTokenSlice(comptime_token));
                    }
                    if (param_decl.noalias_token) |noalias_token| {
                        try stream.print("{} ", self.tokenizer.getTokenSlice(noalias_token));
                    }
                    if (param_decl.name_token) |name_token| {
                        try stream.print("{}: ", self.tokenizer.getTokenSlice(name_token));
                    }
                    if (param_decl.var_args_token) |var_args_token| {
                        try stream.print("{}", self.tokenizer.getTokenSlice(var_args_token));
                    } else {
                        try stack.append(RenderState { .Expression = param_decl.type_node});
                    }
                },
                RenderState.Text => |bytes| {
                    try stream.write(bytes);
                },
                RenderState.Expression => |base| switch (base.id) {
                    ast.Node.Id.Identifier => {
                        const identifier = @fieldParentPtr(ast.NodeIdentifier, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(identifier.name_token));
                    },
                    ast.Node.Id.Block => {
                        const block = @fieldParentPtr(ast.NodeBlock, "base", base);
                        if (block.statements.len == 0) {
                            try stream.write("{}");
                        } else {
                            try stream.write("{");
                            try stack.append(RenderState { .Text = "}"});
                            try stack.append(RenderState.PrintIndent);
                            try stack.append(RenderState { .Indent = indent});
                            try stack.append(RenderState { .Text = "\n"});
                            var i = block.statements.len;
                            while (i != 0) {
                                i -= 1;
                                const statement_node = block.statements.items[i];
                                try stack.append(RenderState { .Statement = statement_node});
                                try stack.append(RenderState.PrintIndent);
                                try stack.append(RenderState { .Indent = indent + indent_delta});
                                try stack.append(RenderState {
                                    .Text = blk: {
                                        if (i != 0) {
                                            const prev_statement_node = block.statements.items[i - 1];
                                            const prev_line_index = prev_statement_node.lastToken().line;
                                            const this_line_index = statement_node.firstToken().line;
                                            if (this_line_index - prev_line_index >= 2) {
                                                break :blk "\n\n";
                                            }
                                        }
                                        break :blk "\n";
                                    },
                                });
                            }
                        }
                    },
                    ast.Node.Id.InfixOp => {
                        const prefix_op_node = @fieldParentPtr(ast.NodeInfixOp, "base", base);
                        try stack.append(RenderState { .Expression = prefix_op_node.rhs });
                        const text = switch (prefix_op_node.op) {
                            ast.NodeInfixOp.InfixOp.Add => " + ",
                            ast.NodeInfixOp.InfixOp.AddWrap => " +% ",
                            ast.NodeInfixOp.InfixOp.ArrayCat => " ++ ",
                            ast.NodeInfixOp.InfixOp.ArrayMult => " ** ",
                            ast.NodeInfixOp.InfixOp.Assign => " = ",
                            ast.NodeInfixOp.InfixOp.AssignBitAnd => " &= ",
                            ast.NodeInfixOp.InfixOp.AssignBitOr => " |= ",
                            ast.NodeInfixOp.InfixOp.AssignBitShiftLeft => " <<= ",
                            ast.NodeInfixOp.InfixOp.AssignBitShiftRight => " >>= ",
                            ast.NodeInfixOp.InfixOp.AssignBitXor => " ^= ",
                            ast.NodeInfixOp.InfixOp.AssignDiv => " /= ",
                            ast.NodeInfixOp.InfixOp.AssignMinus => " -= ",
                            ast.NodeInfixOp.InfixOp.AssignMinusWrap => " -%= ",
                            ast.NodeInfixOp.InfixOp.AssignMod => " %= ",
                            ast.NodeInfixOp.InfixOp.AssignPlus => " += ",
                            ast.NodeInfixOp.InfixOp.AssignPlusWrap => " +%= ",
                            ast.NodeInfixOp.InfixOp.AssignTimes => " *= ",
                            ast.NodeInfixOp.InfixOp.AssignTimesWarp => " *%= ",
                            ast.NodeInfixOp.InfixOp.BangEqual => " != ",
                            ast.NodeInfixOp.InfixOp.BitAnd => " & ",
                            ast.NodeInfixOp.InfixOp.BitOr => " | ",
                            ast.NodeInfixOp.InfixOp.BitShiftLeft => " << ",
                            ast.NodeInfixOp.InfixOp.BitShiftRight => " >> ",
                            ast.NodeInfixOp.InfixOp.BitXor => " ^ ",
                            ast.NodeInfixOp.InfixOp.BoolAnd => " and ",
                            ast.NodeInfixOp.InfixOp.BoolOr => " or ",
                            ast.NodeInfixOp.InfixOp.Div => " / ",
                            ast.NodeInfixOp.InfixOp.EqualEqual => " == ",
                            ast.NodeInfixOp.InfixOp.ErrorUnion => "!",
                            ast.NodeInfixOp.InfixOp.GreaterOrEqual => " >= ",
                            ast.NodeInfixOp.InfixOp.GreaterThan => " > ",
                            ast.NodeInfixOp.InfixOp.LessOrEqual => " <= ",
                            ast.NodeInfixOp.InfixOp.LessThan => " < ",
                            ast.NodeInfixOp.InfixOp.MergeErrorSets => " || ",
                            ast.NodeInfixOp.InfixOp.Mod => " % ",
                            ast.NodeInfixOp.InfixOp.Mult => " * ",
                            ast.NodeInfixOp.InfixOp.MultWrap => " *% ",
                            ast.NodeInfixOp.InfixOp.Period => ".",
                            ast.NodeInfixOp.InfixOp.Sub => " - ",
                            ast.NodeInfixOp.InfixOp.SubWrap => " -% ",
                            ast.NodeInfixOp.InfixOp.UnwrapMaybe => " ?? ",
                        };

                        try stack.append(RenderState { .Text = text });
                        try stack.append(RenderState { .Expression = prefix_op_node.lhs });
                    },
                    ast.Node.Id.PrefixOp => {
                        const prefix_op_node = @fieldParentPtr(ast.NodePrefixOp, "base", base);
                        try stack.append(RenderState { .Expression = prefix_op_node.rhs });
                        switch (prefix_op_node.op) {
                            ast.NodePrefixOp.PrefixOp.AddrOf => |addr_of_info| {
                                try stream.write("&");
                                if (addr_of_info.volatile_token != null) {
                                    try stack.append(RenderState { .Text = "volatile "});
                                }
                                if (addr_of_info.const_token != null) {
                                    try stack.append(RenderState { .Text = "const "});
                                }
                                if (addr_of_info.align_expr) |align_expr| {
                                    try stream.print("align(");
                                    try stack.append(RenderState { .Text = ") "});
                                    try stack.append(RenderState { .Expression = align_expr});
                                }
                            },
                            ast.NodePrefixOp.PrefixOp.SliceType => |addr_of_info| {
                                try stream.write("[]");
                                if (addr_of_info.volatile_token != null) {
                                    try stack.append(RenderState { .Text = "volatile "});
                                }
                                if (addr_of_info.const_token != null) {
                                    try stack.append(RenderState { .Text = "const "});
                                }
                                if (addr_of_info.align_expr) |align_expr| {
                                    try stream.print("align(");
                                    try stack.append(RenderState { .Text = ") "});
                                    try stack.append(RenderState { .Expression = align_expr});
                                }
                            },
                            ast.NodePrefixOp.PrefixOp.ArrayType => |array_index| {
                                try stack.append(RenderState { .Text = "]"});
                                try stack.append(RenderState { .Expression = array_index});
                                try stack.append(RenderState { .Text = "["});
                            },
                            ast.NodePrefixOp.PrefixOp.BitNot => try stream.write("~"),
                            ast.NodePrefixOp.PrefixOp.BoolNot => try stream.write("!"),
                            ast.NodePrefixOp.PrefixOp.Deref => try stream.write("*"),
                            ast.NodePrefixOp.PrefixOp.Negation => try stream.write("-"),
                            ast.NodePrefixOp.PrefixOp.NegationWrap => try stream.write("-%"),
                            ast.NodePrefixOp.PrefixOp.Return => try stream.write("return "),
                            ast.NodePrefixOp.PrefixOp.Try => try stream.write("try "),
                            ast.NodePrefixOp.PrefixOp.UnwrapMaybe => try stream.write("??"),
                        }
                    },
                    ast.Node.Id.SuffixOp => {
                        const suffix_op = @fieldParentPtr(ast.NodeSuffixOp, "base", base);

                        switch (suffix_op.op) {
                            ast.NodeSuffixOp.SuffixOp.Call => |call_info| {
                                try stack.append(RenderState { .Text = ")"});
                                var i = call_info.params.len;
                                while (i != 0) {
                                    i -= 1;
                                    const param_node = call_info.params.at(i);
                                    try stack.append(RenderState { .Expression = param_node});
                                    if (i != 0) {
                                        try stack.append(RenderState { .Text = ", " });
                                    }
                                }
                                try stack.append(RenderState { .Text = "("});
                            },
                            ast.NodeSuffixOp.SuffixOp.ArrayAccess => |index_expr| {
                                try stack.append(RenderState { .Text = "]"});
                                try stack.append(RenderState { .Expression = index_expr});
                                try stack.append(RenderState { .Text = "["});
                            },
                            ast.NodeSuffixOp.SuffixOp.Slice => |range| {
                                try stack.append(RenderState { .Text = "]"});
                                if (range.end) |end| {
                                    try stack.append(RenderState { .Expression = end});
                                }
                                try stack.append(RenderState { .Text = ".."});
                                try stack.append(RenderState { .Expression = range.start});
                                try stack.append(RenderState { .Text = "["});
                            },
                            ast.NodeSuffixOp.SuffixOp.StructInitializer => @panic("TODO: StructInitializer"),
                            ast.NodeSuffixOp.SuffixOp.ArrayInitializer => @panic("TODO: ArrayInitializer"),
                        }

                        try stack.append(RenderState { .Expression = suffix_op.lhs });
                    },
                    ast.Node.Id.GroupedExpression => {
                        const grouped_expr = @fieldParentPtr(ast.NodeGroupedExpression, "base", base);
                        try stack.append(RenderState { .Text = ")"});
                        try stack.append(RenderState { .Expression = grouped_expr.expr });
                        try stack.append(RenderState { .Text = "("});
                    },
                    ast.Node.Id.FieldInitializer => {
                        const field_init = @fieldParentPtr(ast.NodeFieldInitializer, "base", base);
                        try stream.print(".{} = ", self.tokenizer.getTokenSlice(field_init.name_token));
                        try stack.append(RenderState { .Expression = field_init.expr });
                    },
                    ast.Node.Id.IntegerLiteral => {
                        const integer_literal = @fieldParentPtr(ast.NodeIntegerLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(integer_literal.token));
                    },
                    ast.Node.Id.FloatLiteral => {
                        const float_literal = @fieldParentPtr(ast.NodeFloatLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(float_literal.token));
                    },
                    ast.Node.Id.StringLiteral => {
                        const string_literal = @fieldParentPtr(ast.NodeStringLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(string_literal.token));
                    },
                    ast.Node.Id.CharLiteral => {
                        const char_literal = @fieldParentPtr(ast.NodeCharLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(char_literal.token));
                    },
                    ast.Node.Id.BoolLiteral => {
                        const bool_literal = @fieldParentPtr(ast.NodeCharLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(bool_literal.token));
                    },
                    ast.Node.Id.NullLiteral => {
                        const null_literal = @fieldParentPtr(ast.NodeNullLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(null_literal.token));
                    },
                    ast.Node.Id.ThisLiteral => {
                        const this_literal = @fieldParentPtr(ast.NodeThisLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(this_literal.token));
                    },
                    ast.Node.Id.Unreachable => {
                        const unreachable_node = @fieldParentPtr(ast.NodeUnreachable, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(unreachable_node.token));
                    },
                    ast.Node.Id.ErrorType => {
                        const error_type = @fieldParentPtr(ast.NodeErrorType, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(error_type.token));
                    },
                    ast.Node.Id.ContainerDecl => {
                        const container_decl = @fieldParentPtr(ast.NodeContainerDecl, "base", base);
                        try stream.print("{} {{", self.tokenizer.getTokenSlice(container_decl.kind_token));
                        try stack.append(RenderState { .Text = "}"});
                        try stack.append(RenderState.PrintIndent);
                        try stack.append(RenderState { .Indent = indent });

                        const fields_and_decls = container_decl.fields_and_decls.toSliceConst();
                        var i = fields_and_decls.len;
                        while (i != 0) {
                            i -= 1;
                            const node = fields_and_decls[i];
                            if (i != 0) {
                                switch (node.id) {
                                    ast.Node.Id.StructField,
                                    ast.Node.Id.UnionTag,
                                    ast.Node.Id.EnumTag => {
                                        try stack.append(RenderState { .Text = "," });
                                    },
                                    else => { }
                                }
                            }
                            try stack.append(RenderState { .Expression = node});
                            try stack.append(RenderState.PrintIndent);
                            try stack.append(RenderState {
                                .Text = blk: {
                                    if (i != 0) {
                                        const prev_node = fields_and_decls[i - 1];
                                        const prev_line_index = prev_node.lastToken().line;
                                        const this_line_index = node.firstToken().line;
                                        if (this_line_index - prev_line_index >= 2) {
                                            break :blk "\n\n";
                                        }
                                    }
                                    break :blk "\n";
                                },
                            });
                        }
                        try stack.append(RenderState { .Indent = indent + indent_delta});
                    },
                    ast.Node.Id.MultilineStringLiteral => {
                        const multiline_str_literal = @fieldParentPtr(ast.NodeMultilineStringLiteral, "base", base);
                        try stream.print("\n");

                        var i : usize = 0;
                        indent += 4;
                        while (i < multiline_str_literal.tokens.len) : (i += 1) {
                            const t = multiline_str_literal.tokens.at(i);
                            try stream.writeByteNTimes(' ', indent);
                            try stream.print("{}", self.tokenizer.getTokenSlice(t));
                        }
                        try stream.writeByteNTimes(' ', indent);
                        indent -= 4;
                    },
                    ast.Node.Id.UndefinedLiteral => {
                        const undefined_literal = @fieldParentPtr(ast.NodeUndefinedLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(undefined_literal.token));
                    },
                    ast.Node.Id.BuiltinCall => {
                        const builtin_call = @fieldParentPtr(ast.NodeBuiltinCall, "base", base);
                        try stream.print("{}(", self.tokenizer.getTokenSlice(builtin_call.builtin_token));
                        try stack.append(RenderState { .Text = ")"});
                        var i = builtin_call.params.len;
                        while (i != 0) {
                            i -= 1;
                            const param_node = builtin_call.params.at(i);
                            try stack.append(RenderState { .Expression = param_node});
                            if (i != 0) {
                                try stack.append(RenderState { .Text = ", " });
                            }
                        }
                    },
                    ast.Node.Id.StructField => {
                        const field = @fieldParentPtr(ast.NodeStructField, "base", base);
                        try stream.print("{}:", self.tokenizer.getTokenSlice(field.name_token));
                    },
                    ast.Node.Id.UnionTag => {
                        const tag = @fieldParentPtr(ast.NodeUnionTag, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(tag.name_token));

                        if (tag.type_expr) |type_expr| {
                            try stream.print(": ");
                            try stack.append(RenderState { .Expression = type_expr});
                        }
                    },
                    ast.Node.Id.EnumTag => {
                        const tag = @fieldParentPtr(ast.NodeEnumTag, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(tag.name_token));

                        if (tag.value) |value| {
                            try stream.print(" = ");
                            try stack.append(RenderState { .Expression = value});
                        }
                    },
                    ast.Node.Id.FnProto => @panic("TODO fn proto in an expression"),
                    ast.Node.Id.LineComment => @panic("TODO render line comment in an expression"),

                    ast.Node.Id.Root,
                    ast.Node.Id.VarDecl,
                    ast.Node.Id.TestDecl,
                    ast.Node.Id.ParamDecl => unreachable,
                },
                RenderState.FnProtoRParen => |fn_proto| {
                    try stream.print(")");
                    if (fn_proto.align_expr != null) {
                        @panic("TODO");
                    }
                    try stream.print(" ");
                    if (fn_proto.body_node) |body_node| {
                        try stack.append(RenderState { .Expression = body_node});
                        try stack.append(RenderState { .Text = " "});
                    }
                    switch (fn_proto.return_type) {
                        ast.NodeFnProto.ReturnType.Explicit => |node| {
                            try stack.append(RenderState { .Expression = node});
                        },
                        ast.NodeFnProto.ReturnType.Infer => {
                            try stream.print("var");
                        },
                        ast.NodeFnProto.ReturnType.InferErrorSet => |node| {
                            try stream.print("!");
                            try stack.append(RenderState { .Expression = node});
                        },
                    }
                },
                RenderState.Statement => |base| {
                    if (base.comment) |comment| {
                        for (comment.lines.toSliceConst()) |line_token| {
                            try stream.print("{}\n", self.tokenizer.getTokenSlice(line_token));
                            try stream.writeByteNTimes(' ', indent);
                        }
                    }
                    switch (base.id) {
                        ast.Node.Id.VarDecl => {
                            const var_decl = @fieldParentPtr(ast.NodeVarDecl, "base", base);
                            try stack.append(RenderState { .VarDecl = var_decl});
                        },
                        else => {
                            try stack.append(RenderState { .Text = ";"});
                            try stack.append(RenderState { .Expression = base});
                        },
                    }
                },
                RenderState.Indent => |new_indent| indent = new_indent,
                RenderState.PrintIndent => try stream.writeByteNTimes(' ', indent),
            }
        }
    }

    fn initUtilityArrayList(self: &Parser, comptime T: type) ArrayList(T) {
        const new_byte_count = self.utility_bytes.len - self.utility_bytes.len % @sizeOf(T);
        self.utility_bytes = self.util_allocator.alignedShrink(u8, utility_bytes_align, self.utility_bytes, new_byte_count);
        const typed_slice = ([]T)(self.utility_bytes);
        return ArrayList(T) {
            .allocator = self.util_allocator,
            .items = typed_slice,
            .len = 0,
        };
    }

    fn deinitUtilityArrayList(self: &Parser, list: var) void {
        self.utility_bytes = ([]align(utility_bytes_align) u8)(list.items);
    }

};

var fixed_buffer_mem: [100 * 1024]u8 = undefined;

fn testParse(source: []const u8, allocator: &mem.Allocator) ![]u8 {
    var tokenizer = Tokenizer.init(source);
    var parser = Parser.init(&tokenizer, allocator, "(memory buffer)");
    defer parser.deinit();

    var tree = try parser.parse();
    defer tree.deinit();

    var buffer = try std.Buffer.initSize(allocator, 0);
    errdefer buffer.deinit();

    var buffer_out_stream = io.BufferOutStream.init(&buffer);
    try parser.renderSource(&buffer_out_stream.stream, tree.root_node);
    return buffer.toOwnedSlice();
}

fn testCanonical(source: []const u8) !void {
    const needed_alloc_count = x: {
        // Try it once with unlimited memory, make sure it works
        var fixed_allocator = std.heap.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
        var failing_allocator = std.debug.FailingAllocator.init(&fixed_allocator.allocator, @maxValue(usize));
        const result_source = try testParse(source, &failing_allocator.allocator);
        if (!mem.eql(u8, result_source, source)) {
            warn("\n====== expected this output: =========\n");
            warn("{}", source);
            warn("\n======== instead found this: =========\n");
            warn("{}", result_source);
            warn("\n======================================\n");
            return error.TestFailed;
        }
        failing_allocator.allocator.free(result_source);
        break :x failing_allocator.index;
    };

    var fail_index: usize = 0;
    while (fail_index < needed_alloc_count) : (fail_index += 1) {
        var fixed_allocator = std.heap.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
        var failing_allocator = std.debug.FailingAllocator.init(&fixed_allocator.allocator, fail_index);
        if (testParse(source, &failing_allocator.allocator)) |_| {
            return error.NondeterministicMemoryUsage;
        } else |err| switch (err) {
            error.OutOfMemory => {
                if (failing_allocator.allocated_bytes != failing_allocator.freed_bytes) {
                    warn("\nfail_index: {}/{}\nallocated bytes: {}\nfreed bytes: {}\nallocations: {}\ndeallocations: {}\n",
                        fail_index, needed_alloc_count,
                        failing_allocator.allocated_bytes, failing_allocator.freed_bytes,
                        failing_allocator.index, failing_allocator.deallocations);
                    return error.MemoryLeakDetected;
                }
            },
            error.ParseError => @panic("test failed"),
        }
    }
}

test "zig fmt: get stdout or fail" {
    try testCanonical(
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    // If this program is run without stdout attached, exit with an error.
        \\    // another comment
        \\    var stdout_file = try std.io.getStdOut;
        \\}
        \\
    );
}

test "zig fmt: preserve spacing" {
    try testCanonical(
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    var stdout_file = try std.io.getStdOut;
        \\    var stdout_file = try std.io.getStdOut;
        \\
        \\    var stdout_file = try std.io.getStdOut;
        \\    var stdout_file = try std.io.getStdOut;
        \\}
        \\
    );
}

test "zig fmt: return types" {
    try testCanonical(
        \\pub fn main() !void {}
        \\pub fn main() var {}
        \\pub fn main() i32 {}
        \\
    );
}

test "zig fmt: imports" {
    try testCanonical(
        \\const std = @import("std");
        \\const std = @import();
        \\
    );
}

test "zig fmt: global declarations" {
    try testCanonical(
        \\const a = b;
        \\pub const a = b;
        \\var a = b;
        \\pub var a = b;
        \\const a: i32 = b;
        \\pub const a: i32 = b;
        \\var a: i32 = b;
        \\pub var a: i32 = b;
        \\extern const a: i32 = b;
        \\pub extern const a: i32 = b;
        \\extern var a: i32 = b;
        \\pub extern var a: i32 = b;
        \\extern "a" const a: i32 = b;
        \\pub extern "a" const a: i32 = b;
        \\extern "a" var a: i32 = b;
        \\pub extern "a" var a: i32 = b;
        \\
    );
}

test "zig fmt: extern declaration" {
    try testCanonical(
        \\extern var foo: c_int;
        \\
    );
}

test "zig fmt: alignment" {
        try testCanonical(
        \\var foo: c_int align(1);
        \\
    );
}

test "zig fmt: C main" {
    try testCanonical(
        \\fn main(argc: c_int, argv: &&u8) c_int {
        \\    const a = b;
        \\}
        \\
    );
}

test "zig fmt: return" {
    try testCanonical(
        \\fn foo(argc: c_int, argv: &&u8) c_int {
        \\    return 0;
        \\}
        \\
    );
}

test "zig fmt: pointer attributes" {
    try testCanonical(
        \\extern fn f1(s: &align(&u8) u8) c_int;
        \\extern fn f2(s: &&align(1) &const &volatile u8) c_int;
        \\extern fn f3(s: &align(1) const &align(1) volatile &const volatile u8) c_int;
        \\extern fn f4(s: &align(1) const volatile u8) c_int;
        \\
    );
}

test "zig fmt: slice attributes" {
    try testCanonical(
        \\extern fn f1(s: &align(&u8) u8) c_int;
        \\extern fn f2(s: &&align(1) &const &volatile u8) c_int;
        \\extern fn f3(s: &align(1) const &align(1) volatile &const volatile u8) c_int;
        \\extern fn f4(s: &align(1) const volatile u8) c_int;
        \\
    );
}

test "zig fmt: test declaration" {
     try testCanonical(
        \\test "test name" {
        \\    const a = 1;
        \\    var b = 1;
        \\}
        \\
    );
}

test "zig fmt: infix operators" {
    try testCanonical(
        \\test "infix operators" {
        \\    var i = undefined;
        \\    i = 2;
        \\    i *= 2;
        \\    i |= 2;
        \\    i ^= 2;
        \\    i <<= 2;
        \\    i >>= 2;
        \\    i &= 2;
        \\    i *= 2;
        \\    i *%= 2;
        \\    i -= 2;
        \\    i -%= 2;
        \\    i += 2;
        \\    i +%= 2;
        \\    i /= 2;
        \\    i %= 2;
        \\    _ = i == i;
        \\    _ = i != i;
        \\    _ = i != i;
        \\    _ = i.i;
        \\    _ = i || i;
        \\    _ = i!i;
        \\    _ = i ** i;
        \\    _ = i ++ i;
        \\    _ = i ?? i;
        \\    _ = i % i;
        \\    _ = i / i;
        \\    _ = i *% i;
        \\    _ = i * i;
        \\    _ = i -% i;
        \\    _ = i - i;
        \\    _ = i +% i;
        \\    _ = i + i;
        \\    _ = i << i;
        \\    _ = i >> i;
        \\    _ = i & i;
        \\    _ = i ^ i;
        \\    _ = i | i;
        \\    _ = i >= i;
        \\    _ = i <= i;
        \\    _ = i > i;
        \\    _ = i < i;
        \\    _ = i and i;
        \\    _ = i or i;
        \\}
        \\
    );
}

test "zig fmt: prefix operators" {
    try testCanonical(
        \\test "prefix operators" {
        \\    try return --%~??!*&0;
        \\}
        \\
    );
}

test "zig fmt: call expression" {
    try testCanonical(
        \\test "test calls" {
        \\    a();
        \\    a(1);
        \\    a(1, 2);
        \\    a(1, 2) + a(1, 2);
        \\}
        \\
    );
}

test "zig fmt: var args" {
    try testCanonical(
        \\fn print(args: ...) void {}
        \\
    );
}

test "zig fmt: extern function" {
    try testCanonical(
        \\extern fn puts(s: &const u8) c_int;
        \\extern "c" fn puts(s: &const u8) c_int;
        \\
    );
}

test "zig fmt: multiline string" {
    try testCanonical(
        \\const s = 
        \\    \\ something
        \\    \\ something else
        \\    ;
        \\
    );
}

test "zig fmt: values" {
    try testCanonical(
        \\test "values" {
        \\    1;
        \\    1.0;
        \\    "string";
        \\    c"cstring";
        \\    'c';
        \\    true;
        \\    false;
        \\    null;
        \\    undefined;
        \\    error;
        \\    this;
        \\    unreachable;
        \\    suspend;
        \\}
        \\
    );
}

test "zig fmt: indexing" {
    try testCanonical(
        \\test "test index" {
        \\    a[0];
        \\    a[0 + 5];
        \\    a[0..];
        \\    a[0..5];
        \\    a[a[0]];
        \\    a[a[0..]];
        \\    a[a[0..5]];
        \\    a[a[0]..];
        \\    a[a[0..5]..];
        \\    a[a[0]..a[0]];
        \\    a[a[0..5]..a[0]];
        \\    a[a[0..5]..a[0..5]];
        \\}
        \\
    );
}

test "zig fmt: struct declaration" {
    try testCanonical(
        \\const S = struct {
        \\    const Self = this;
        \\    f1: u8,
        \\
        \\    fn method(self: &Self) Self {
        \\        return *self;
        \\    }
        \\
        \\    f2: u8,
        \\};
        \\
        \\const Ps = packed struct {
        \\    a: u8,
        \\    b: u8,
        \\
        \\    c: u8,
        \\};
        \\
        \\const Es = extern struct {
        \\    a: u8,
        \\    b: u8,
        \\
        \\    c: u8,
        \\};
        \\
    );
}

test "zig fmt: enum declaration" {
      try testCanonical(
        \\const E = enum {
        \\    Ok,
        \\    SomethingElse = 0,
        \\};
        \\
        \\const E2 = enum(u8) {
        \\    Ok,
        \\    SomethingElse = 255,
        \\    SomethingThird,
        \\};
        \\
        \\const Ee = extern enum {
        \\    Ok,
        \\    SomethingElse,
        \\    SomethingThird,
        \\};
        \\
        \\const Ep = packed enum {
        \\    Ok,
        \\    SomethingElse,
        \\    SomethingThird,
        \\};
        \\
    );
}

test "zig fmt: union declaration" {
      try testCanonical(
        \\const U = union {
        \\    Int: u8,
        \\    Float: f32,
        \\    Bool: bool,
        \\};
        \\
        \\const Ue = union(enum) {
        \\    Int: u8,
        \\    Float: f32,
        \\    Bool: bool,
        \\};
        \\
        \\const E = enum {
        \\    Int,
        \\    Float,
        \\    Bool,
        \\};
        \\
        \\const Ue2 = union(E) {
        \\    Int: u8,
        \\    Float: f32,
        \\    Bool: bool,
        \\};
        \\
        \\const Eu = extern union {
        \\    Int: u8,
        \\    Float: f32,
        \\    Bool: bool,
        \\};
        \\
    );
}

test "zig fmt: switch" {
    try testCanonical(
        \\test "switch" {
        \\    switch (0) {
        \\        0 => {},
        \\        1 => unreachable,
        \\        2, 3 => {},
        \\        4 ... 7 => {},
        \\        1 + 4 * 3 + 22 => {},
        \\        else => {
        \\            const a = 1;
        \\            const b = a;
        \\        },
        \\    }
        \\
        \\    const res = switch (0) {
        \\        0 => 0,
        \\        1 => 2,
        \\        else => 4,
        \\    };
        \\
        \\    const Union = union(enum) {
        \\        Int: i64,
        \\        Float: f64,
        \\    };
        \\
        \\    const u = Union { .Int = 0 };
        \\    switch (u) {
        \\        Union.Int => |int| {},
        \\        Union.Float => |*float| unreachable,
        \\    }
        \\}
        \\
    );
}

test "zig fmt: while" {
    try testCanonical(
        \\test "while" {
        \\    while (10 < 1) {
        \\        unreachable;
        \\    }
        \\
        \\    while (10 < 1)
        \\        unreachable;
        \\
        \\    var i: usize = 0;
        \\    while (i < 10) : (i += 1) {
        \\        continue;
        \\    }
        \\
        \\    i = 0;
        \\    while (i < 10) : (i += 1)
        \\        continue;
        \\
        \\    i = 0;
        \\    var j usize = 0;
        \\    while (i < 10) : ({ i += 1; j += 1; }) {
        \\        continue;
        \\    }
        \\
        \\    var a: ?u8 = 2;
        \\    while (a) |v| : (a = null) {
        \\        continue;
        \\    }
        \\
        \\    while (a) |v| : (a = null)
        \\        unreachable;
        \\
        \\    label: while (10 < 0) {
        \\        unreachable;
        \\    }
        \\
        \\    const res = while (0 < 10) {
        \\        break 7;
        \\    } else {
        \\        unreachable;
        \\    }
        \\
        \\    var a: error!u8 = 0;
        \\    while (a) |v| {
        \\        a = error.Err;
        \\    } else |err| {
        \\        i = 1;
        \\    }
        \\
        \\    comptime var k: usize = 0;
        \\    inline while (i < 10) (i += 1)
        \\        j += 2;
        \\}
        \\
    );
}

test "zig fmt: for" {
    try testCanonical(
        \\test "for" {
        \\    const a = []u8{ 1, 2, 3 };
        \\    for (a) |v| {
        \\        continue;
        \\    }
        \\
        \\    for (a) |v|
        \\        continue;
        \\
        \\    for (a) |*v|
        \\        continue;
        \\
        \\    for (a) |v, i| {
        \\        continue;
        \\    }
        \\
        \\    for (a) |v, i|
        \\        continue;
        \\
        \\    const res = for (a) |v, i| {
        \\        breal v;
        \\    } else {
        \\        unreachable;
        \\    }
        \\
        \\    var num: usize = 0;
        \\    inline for (a) |v, i| {
        \\        num += v;
        \\        num += i;
        \\    }
        \\}
        \\
    );
}

test "zig fmt: if" {
    try testCanonical(
        \\test "if" {
        \\    if (10 < 0) {
        \\        unreachable;
        \\    }
        \\
        \\    if (10 < 0)
        \\        unreachable;
        \\
        \\    if (10 < 0) {
        \\        unreachable;
        \\    } else {
        \\        const a = 20;
        \\    }
        \\
        \\    if (10 < 0) {
        \\        unreachable;
        \\    } else if (5 < 0) {
        \\        unreachable;
        \\    } else {
        \\        const a = 20;
        \\    }
        \\
        \\    const is_world_broken = if (10 < 0) true else false;
        \\
        \\    const a: ?u8 = 10;
        \\    const b: ?u8 = null;
        \\    if (a) |v| {
        \\        const some = v;
        \\    } else if (b) |*v| {
        \\        unreachable;
        \\    } else {
        \\        const some = 10;
        \\    }
        \\
        \\    const non_null_a = if (a) |v| v else 0;
        \\
        \\    const a_err: error!u8 = 0;
        \\    if (a_err) |v| {
        \\        const p = v;
        \\    } else |err| {
        \\        unreachable;
        \\    }
        \\}
        \\
    );
}

test "zig fmt: defer" {
    try testCanonical(
        \\test "defer" {
        \\    var i: usize = 0;
        \\    defer i = 1;
        \\    defer {
        \\        i += 2;
        \\        i *= i;
        \\    }
        \\
        \\    errdefer i += 3;
        \\    errdefer {
        \\        i += 2;
        \\        i /= i;
        \\    }
        \\}
        \\
    );
}

test "zig fmt: catch" {
    try testCanonical(
        \\test "catch" {
        \\    const a: error!u8 = 0;
        \\    _ = a catch return;
        \\    _ = a catch |err| return;
        \\}
        \\
    );
}

test "zig fmt: comptime" {
    try testCanonical(
        \\fn a() u8 {
        \\    return 5;
        \\}
        \\
        \\fn b(comptime i: u8) u8 {
        \\    return i;
        \\}
        \\
        \\const av = comptime a();
        \\const av2 = comptime blk: {
        \\    var res = a();
        \\    res *= b(2);
        \\    break :blk res;
        \\};
        \\
        \\comptime {
        \\    _ = a();
        \\}
        \\
        \\test "comptime" {
        \\    const av3 = comptime a();
        \\    const av4 = comptime blk: {
        \\        var res = a();
        \\        res *= a();
        \\        break :blk res;
        \\    };
        \\
        \\    comptime var i = 0;
        \\    comptime {
        \\        i = a();
        \\        i += b(i);
        \\    }
        \\}
        \\
    );
}

test "zig fmt: fn type" {
    try testCanonical(
        \\fn a(i: u8) u8 {
        \\    return i + 1;
        \\}
        \\
        \\const ap: fn(u8) u8 = a;
        \\
    );
}

test "zig fmt: inline asm" {
    try testCanonical(
        \\pub fn syscall1(number: usize, arg1: usize) usize {
        \\    return asm volatile ("syscall"
        \\        : [ret] "={rax}" (-> usize)
        \\        : [number] "{rax}" (number),
        \\            [arg1] "{rdi}" (arg1)
        \\        : "rcx", "r11");
        \\}
        \\
    );
}

test "zig fmt: coroutines" {
    try testCanonical(
        \\async fn simpleAsyncFn() void {
        \\    x += 1;
        \\    suspend;
        \\    x += 1;
        \\    suspend |p| {
        \\    }
        \\    const p = async simpleAsyncFn() catch unreachable;
        \\    await p;
        \\}
        \\
        \\test "coroutine suspend, resume, cancel" {
        \\    const p = try async<std.debug.global_allocator> testAsyncSeq();
        \\    resume p;
        \\    cancel p;
        \\}
        \\
    );
}

test "zig fmt: arrays" {
    try testCanonical(
        \\test "test array" {
        \\    const a: [2]u8 = [2]u8{ 1, 2 };
        \\    const a: [2]u8 = []u8{ 1, 2 };
        \\    const a: [0]u8 = []u8{};
        \\}
        \\
    );
}

test "zig fmt: container initializers" {
    try testCanonical(
        \\const a1 = []u8{ };
        \\const a2 = []u8{ 1, 2, 3, 4 };
        \\const s1 = S{ };
        \\const s2 = S{ .a = 1, .b = 2, };
        \\
    );
}

test "zig fmt: precedence" {
    try testCanonical(
        \\test "precedence" {
        \\    a!b();
        \\    (a!b)();
        \\    !a!b;
        \\    !(a!b);
        \\    !a{};
        \\    !(a{});
        \\    a + b{};
        \\    (a + b){};
        \\    a << b + c;
        \\    (a << b) + c;
        \\    a & b << c;
        \\    (a & b) << c;
        \\    a ^ b & c;
        \\    (a ^ b) & c;
        \\    a | b ^ c;
        \\    (a | b) ^ c;
        \\    a == b | c;
        \\    (a == b) | c;
        \\    a and b == c;
        \\    (a and b) == c;
        \\    a or b and c;
        \\    (a or b) and c;
        \\    (a or b) and c;
        \\    a = b or c;
        \\    (a = b) or c;
        \\}
        \\
    );
}

test "zig fmt: zig fmt" {
    try testCanonical(@embedFile("ast.zig"));
    try testCanonical(@embedFile("index.zig"));
    try testCanonical(@embedFile("parser.zig"));
    try testCanonical(@embedFile("tokenizer.zig"));
}
