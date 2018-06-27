const std = @import("../index.zig");
const assert = std.debug.assert;
const mem = std.mem;
const ast = std.zig.ast;
const Tokenizer = std.zig.Tokenizer;
const Token = std.zig.Token;
const TokenIndex = ast.TokenIndex;
const Error = ast.Error;

/// Result should be freed with tree.deinit() when there are
/// no more references to any of the tokens or nodes.
pub fn parse(allocator: *mem.Allocator, source: []const u8) !ast.Tree {
    var tree_arena = std.heap.ArenaAllocator.init(allocator);
    errdefer tree_arena.deinit();

    var stack = std.ArrayList(State).init(allocator);
    defer stack.deinit();

    const arena = &tree_arena.allocator;
    const root_node = try arena.create(ast.Node.Root{
        .base = ast.Node{ .id = ast.Node.Id.Root },
        .decls = ast.Node.Root.DeclList.init(arena),
        .doc_comments = null,
        // initialized when we get the eof token
        .eof_token = undefined,
    });

    var tree = ast.Tree{
        .source = source,
        .root_node = root_node,
        .arena_allocator = tree_arena,
        .tokens = ast.Tree.TokenList.init(arena),
        .errors = ast.Tree.ErrorList.init(arena),
    };

    var tokenizer = Tokenizer.init(tree.source);
    while (true) {
        const token_ptr = try tree.tokens.addOne();
        token_ptr.* = tokenizer.next();
        if (token_ptr.id == Token.Id.Eof) break;
    }
    var tok_it = tree.tokens.iterator(0);

    // skip over line comments at the top of the file
    while (true) {
        const next_tok = tok_it.peek() orelse break;
        if (next_tok.id != Token.Id.LineComment) break;
        _ = tok_it.next();
    }

    try stack.append(State.TopLevel);

    while (true) {
        // This gives us 1 free push that can't fail
        const state = stack.pop();

        switch (state) {
            State.TopLevel => {
                const comments = try eatDocComments(arena, &tok_it, &tree);

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Keyword_test => {
                        stack.append(State.TopLevel) catch unreachable;

                        const block = try arena.create(ast.Node.Block{
                            .base = ast.Node{ .id = ast.Node.Id.Block },
                            .label = null,
                            .lbrace = undefined,
                            .statements = ast.Node.Block.StatementList.init(arena),
                            .rbrace = undefined,
                        });
                        const test_node = try arena.create(ast.Node.TestDecl{
                            .base = ast.Node{ .id = ast.Node.Id.TestDecl },
                            .doc_comments = comments,
                            .test_token = token_index,
                            .name = undefined,
                            .body_node = &block.base,
                        });
                        try root_node.decls.push(&test_node.base);
                        try stack.append(State{ .Block = block });
                        try stack.append(State{
                            .ExpectTokenSave = ExpectTokenSave{
                                .id = Token.Id.LBrace,
                                .ptr = &block.lbrace,
                            },
                        });
                        try stack.append(State{ .StringLiteral = OptionalCtx{ .Required = &test_node.name } });
                        continue;
                    },
                    Token.Id.Eof => {
                        root_node.eof_token = token_index;
                        root_node.doc_comments = comments;
                        return tree;
                    },
                    Token.Id.Keyword_pub => {
                        stack.append(State.TopLevel) catch unreachable;
                        try stack.append(State{
                            .TopLevelExtern = TopLevelDeclCtx{
                                .decls = &root_node.decls,
                                .visib_token = token_index,
                                .extern_export_inline_token = null,
                                .lib_name = null,
                                .comments = comments,
                            },
                        });
                        continue;
                    },
                    Token.Id.Keyword_comptime => {
                        const block = try arena.create(ast.Node.Block{
                            .base = ast.Node{ .id = ast.Node.Id.Block },
                            .label = null,
                            .lbrace = undefined,
                            .statements = ast.Node.Block.StatementList.init(arena),
                            .rbrace = undefined,
                        });
                        const node = try arena.create(ast.Node.Comptime{
                            .base = ast.Node{ .id = ast.Node.Id.Comptime },
                            .comptime_token = token_index,
                            .expr = &block.base,
                            .doc_comments = comments,
                        });
                        try root_node.decls.push(&node.base);

                        stack.append(State.TopLevel) catch unreachable;
                        try stack.append(State{ .Block = block });
                        try stack.append(State{
                            .ExpectTokenSave = ExpectTokenSave{
                                .id = Token.Id.LBrace,
                                .ptr = &block.lbrace,
                            },
                        });
                        continue;
                    },
                    else => {
                        prevToken(&tok_it, &tree);
                        stack.append(State.TopLevel) catch unreachable;
                        try stack.append(State{
                            .TopLevelExtern = TopLevelDeclCtx{
                                .decls = &root_node.decls,
                                .visib_token = null,
                                .extern_export_inline_token = null,
                                .lib_name = null,
                                .comments = comments,
                            },
                        });
                        continue;
                    },
                }
            },
            State.TopLevelExtern => |ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Keyword_export, Token.Id.Keyword_inline => {
                        stack.append(State{
                            .TopLevelDecl = TopLevelDeclCtx{
                                .decls = ctx.decls,
                                .visib_token = ctx.visib_token,
                                .extern_export_inline_token = AnnotatedToken{
                                    .index = token_index,
                                    .ptr = token_ptr,
                                },
                                .lib_name = null,
                                .comments = ctx.comments,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_extern => {
                        stack.append(State{
                            .TopLevelLibname = TopLevelDeclCtx{
                                .decls = ctx.decls,
                                .visib_token = ctx.visib_token,
                                .extern_export_inline_token = AnnotatedToken{
                                    .index = token_index,
                                    .ptr = token_ptr,
                                },
                                .lib_name = null,
                                .comments = ctx.comments,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    else => {
                        prevToken(&tok_it, &tree);
                        stack.append(State{ .TopLevelDecl = ctx }) catch unreachable;
                        continue;
                    },
                }
            },
            State.TopLevelLibname => |ctx| {
                const lib_name = blk: {
                    const lib_name_token = nextToken(&tok_it, &tree);
                    const lib_name_token_index = lib_name_token.index;
                    const lib_name_token_ptr = lib_name_token.ptr;
                    break :blk (try parseStringLiteral(arena, &tok_it, lib_name_token_ptr, lib_name_token_index, &tree)) orelse {
                        prevToken(&tok_it, &tree);
                        break :blk null;
                    };
                };

                stack.append(State{
                    .TopLevelDecl = TopLevelDeclCtx{
                        .decls = ctx.decls,
                        .visib_token = ctx.visib_token,
                        .extern_export_inline_token = ctx.extern_export_inline_token,
                        .lib_name = lib_name,
                        .comments = ctx.comments,
                    },
                }) catch unreachable;
                continue;
            },
            State.TopLevelDecl => |ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Keyword_use => {
                        if (ctx.extern_export_inline_token) |annotated_token| {
                            ((try tree.errors.addOne())).* = Error{ .InvalidToken = Error.InvalidToken{ .token = annotated_token.index } };
                            return tree;
                        }

                        const node = try arena.create(ast.Node.Use{
                            .base = ast.Node{ .id = ast.Node.Id.Use },
                            .use_token = token_index,
                            .visib_token = ctx.visib_token,
                            .expr = undefined,
                            .semicolon_token = undefined,
                            .doc_comments = ctx.comments,
                        });
                        try ctx.decls.push(&node.base);

                        stack.append(State{
                            .ExpectTokenSave = ExpectTokenSave{
                                .id = Token.Id.Semicolon,
                                .ptr = &node.semicolon_token,
                            },
                        }) catch unreachable;
                        try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.expr } });
                        continue;
                    },
                    Token.Id.Keyword_var, Token.Id.Keyword_const => {
                        if (ctx.extern_export_inline_token) |annotated_token| {
                            if (annotated_token.ptr.id == Token.Id.Keyword_inline) {
                                ((try tree.errors.addOne())).* = Error{ .InvalidToken = Error.InvalidToken{ .token = annotated_token.index } };
                                return tree;
                            }
                        }

                        try stack.append(State{
                            .VarDecl = VarDeclCtx{
                                .comments = ctx.comments,
                                .visib_token = ctx.visib_token,
                                .lib_name = ctx.lib_name,
                                .comptime_token = null,
                                .extern_export_token = if (ctx.extern_export_inline_token) |at| at.index else null,
                                .mut_token = token_index,
                                .list = ctx.decls,
                            },
                        });
                        continue;
                    },
                    Token.Id.Keyword_fn, Token.Id.Keyword_nakedcc, Token.Id.Keyword_stdcallcc, Token.Id.Keyword_async => {
                        const fn_proto = try arena.create(ast.Node.FnProto{
                            .base = ast.Node{ .id = ast.Node.Id.FnProto },
                            .doc_comments = ctx.comments,
                            .visib_token = ctx.visib_token,
                            .name_token = null,
                            .fn_token = undefined,
                            .params = ast.Node.FnProto.ParamList.init(arena),
                            .return_type = undefined,
                            .var_args_token = null,
                            .extern_export_inline_token = if (ctx.extern_export_inline_token) |at| at.index else null,
                            .cc_token = null,
                            .async_attr = null,
                            .body_node = null,
                            .lib_name = ctx.lib_name,
                            .align_expr = null,
                        });
                        try ctx.decls.push(&fn_proto.base);
                        stack.append(State{ .FnDef = fn_proto }) catch unreachable;
                        try stack.append(State{ .FnProto = fn_proto });

                        switch (token_ptr.id) {
                            Token.Id.Keyword_nakedcc, Token.Id.Keyword_stdcallcc => {
                                fn_proto.cc_token = token_index;
                                try stack.append(State{
                                    .ExpectTokenSave = ExpectTokenSave{
                                        .id = Token.Id.Keyword_fn,
                                        .ptr = &fn_proto.fn_token,
                                    },
                                });
                                continue;
                            },
                            Token.Id.Keyword_async => {
                                const async_node = try arena.create(ast.Node.AsyncAttribute{
                                    .base = ast.Node{ .id = ast.Node.Id.AsyncAttribute },
                                    .async_token = token_index,
                                    .allocator_type = null,
                                    .rangle_bracket = null,
                                });
                                fn_proto.async_attr = async_node;

                                try stack.append(State{
                                    .ExpectTokenSave = ExpectTokenSave{
                                        .id = Token.Id.Keyword_fn,
                                        .ptr = &fn_proto.fn_token,
                                    },
                                });
                                try stack.append(State{ .AsyncAllocator = async_node });
                                continue;
                            },
                            Token.Id.Keyword_fn => {
                                fn_proto.fn_token = token_index;
                                continue;
                            },
                            else => unreachable,
                        }
                    },
                    else => {
                        ((try tree.errors.addOne())).* = Error{ .ExpectedVarDeclOrFn = Error.ExpectedVarDeclOrFn{ .token = token_index } };
                        return tree;
                    },
                }
            },
            State.TopLevelExternOrField => |ctx| {
                if (eatToken(&tok_it, &tree, Token.Id.Identifier)) |identifier| {
                    const node = try arena.create(ast.Node.StructField{
                        .base = ast.Node{ .id = ast.Node.Id.StructField },
                        .doc_comments = ctx.comments,
                        .visib_token = ctx.visib_token,
                        .name_token = identifier,
                        .type_expr = undefined,
                    });
                    const node_ptr = try ctx.container_decl.fields_and_decls.addOne();
                    node_ptr.* = &node.base;

                    stack.append(State{ .FieldListCommaOrEnd = ctx.container_decl }) catch unreachable;
                    try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.type_expr } });
                    try stack.append(State{ .ExpectToken = Token.Id.Colon });
                    continue;
                }

                stack.append(State{ .ContainerDecl = ctx.container_decl }) catch unreachable;
                try stack.append(State{
                    .TopLevelExtern = TopLevelDeclCtx{
                        .decls = &ctx.container_decl.fields_and_decls,
                        .visib_token = ctx.visib_token,
                        .extern_export_inline_token = null,
                        .lib_name = null,
                        .comments = ctx.comments,
                    },
                });
                continue;
            },

            State.FieldInitValue => |ctx| {
                const eq_tok = nextToken(&tok_it, &tree);
                const eq_tok_index = eq_tok.index;
                const eq_tok_ptr = eq_tok.ptr;
                if (eq_tok_ptr.id != Token.Id.Equal) {
                    prevToken(&tok_it, &tree);
                    continue;
                }
                stack.append(State{ .Expression = ctx }) catch unreachable;
                continue;
            },

            State.ContainerKind => |ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                const node = try arena.create(ast.Node.ContainerDecl{
                    .base = ast.Node{ .id = ast.Node.Id.ContainerDecl },
                    .layout_token = ctx.layout_token,
                    .kind_token = switch (token_ptr.id) {
                        Token.Id.Keyword_struct, Token.Id.Keyword_union, Token.Id.Keyword_enum => token_index,
                        else => {
                            ((try tree.errors.addOne())).* = Error{ .ExpectedAggregateKw = Error.ExpectedAggregateKw{ .token = token_index } };
                            return tree;
                        },
                    },
                    .init_arg_expr = ast.Node.ContainerDecl.InitArg.None,
                    .fields_and_decls = ast.Node.ContainerDecl.DeclList.init(arena),
                    .lbrace_token = undefined,
                    .rbrace_token = undefined,
                });
                ctx.opt_ctx.store(&node.base);

                stack.append(State{ .ContainerDecl = node }) catch unreachable;
                try stack.append(State{
                    .ExpectTokenSave = ExpectTokenSave{
                        .id = Token.Id.LBrace,
                        .ptr = &node.lbrace_token,
                    },
                });
                try stack.append(State{ .ContainerInitArgStart = node });
                continue;
            },

            State.ContainerInitArgStart => |container_decl| {
                if (eatToken(&tok_it, &tree, Token.Id.LParen) == null) {
                    continue;
                }

                stack.append(State{ .ExpectToken = Token.Id.RParen }) catch unreachable;
                try stack.append(State{ .ContainerInitArg = container_decl });
                continue;
            },

            State.ContainerInitArg => |container_decl| {
                const init_arg_token = nextToken(&tok_it, &tree);
                const init_arg_token_index = init_arg_token.index;
                const init_arg_token_ptr = init_arg_token.ptr;
                switch (init_arg_token_ptr.id) {
                    Token.Id.Keyword_enum => {
                        container_decl.init_arg_expr = ast.Node.ContainerDecl.InitArg{ .Enum = null };
                        const lparen_tok = nextToken(&tok_it, &tree);
                        const lparen_tok_index = lparen_tok.index;
                        const lparen_tok_ptr = lparen_tok.ptr;
                        if (lparen_tok_ptr.id == Token.Id.LParen) {
                            try stack.append(State{ .ExpectToken = Token.Id.RParen });
                            try stack.append(State{ .Expression = OptionalCtx{ .RequiredNull = &container_decl.init_arg_expr.Enum } });
                        } else {
                            prevToken(&tok_it, &tree);
                        }
                    },
                    else => {
                        prevToken(&tok_it, &tree);
                        container_decl.init_arg_expr = ast.Node.ContainerDecl.InitArg{ .Type = undefined };
                        stack.append(State{ .Expression = OptionalCtx{ .Required = &container_decl.init_arg_expr.Type } }) catch unreachable;
                    },
                }
                continue;
            },

            State.ContainerDecl => |container_decl| {
                const comments = try eatDocComments(arena, &tok_it, &tree);
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Identifier => {
                        switch (tree.tokens.at(container_decl.kind_token).id) {
                            Token.Id.Keyword_struct => {
                                const node = try arena.create(ast.Node.StructField{
                                    .base = ast.Node{ .id = ast.Node.Id.StructField },
                                    .doc_comments = comments,
                                    .visib_token = null,
                                    .name_token = token_index,
                                    .type_expr = undefined,
                                });
                                const node_ptr = try container_decl.fields_and_decls.addOne();
                                node_ptr.* = &node.base;

                                try stack.append(State{ .FieldListCommaOrEnd = container_decl });
                                try stack.append(State{ .TypeExprBegin = OptionalCtx{ .Required = &node.type_expr } });
                                try stack.append(State{ .ExpectToken = Token.Id.Colon });
                                continue;
                            },
                            Token.Id.Keyword_union => {
                                const node = try arena.create(ast.Node.UnionTag{
                                    .base = ast.Node{ .id = ast.Node.Id.UnionTag },
                                    .name_token = token_index,
                                    .type_expr = null,
                                    .value_expr = null,
                                    .doc_comments = comments,
                                });
                                try container_decl.fields_and_decls.push(&node.base);

                                stack.append(State{ .FieldListCommaOrEnd = container_decl }) catch unreachable;
                                try stack.append(State{ .FieldInitValue = OptionalCtx{ .RequiredNull = &node.value_expr } });
                                try stack.append(State{ .TypeExprBegin = OptionalCtx{ .RequiredNull = &node.type_expr } });
                                try stack.append(State{ .IfToken = Token.Id.Colon });
                                continue;
                            },
                            Token.Id.Keyword_enum => {
                                const node = try arena.create(ast.Node.EnumTag{
                                    .base = ast.Node{ .id = ast.Node.Id.EnumTag },
                                    .name_token = token_index,
                                    .value = null,
                                    .doc_comments = comments,
                                });
                                try container_decl.fields_and_decls.push(&node.base);

                                stack.append(State{ .FieldListCommaOrEnd = container_decl }) catch unreachable;
                                try stack.append(State{ .Expression = OptionalCtx{ .RequiredNull = &node.value } });
                                try stack.append(State{ .IfToken = Token.Id.Equal });
                                continue;
                            },
                            else => unreachable,
                        }
                    },
                    Token.Id.Keyword_pub => {
                        switch (tree.tokens.at(container_decl.kind_token).id) {
                            Token.Id.Keyword_struct => {
                                try stack.append(State{
                                    .TopLevelExternOrField = TopLevelExternOrFieldCtx{
                                        .visib_token = token_index,
                                        .container_decl = container_decl,
                                        .comments = comments,
                                    },
                                });
                                continue;
                            },
                            else => {
                                stack.append(State{ .ContainerDecl = container_decl }) catch unreachable;
                                try stack.append(State{
                                    .TopLevelExtern = TopLevelDeclCtx{
                                        .decls = &container_decl.fields_and_decls,
                                        .visib_token = token_index,
                                        .extern_export_inline_token = null,
                                        .lib_name = null,
                                        .comments = comments,
                                    },
                                });
                                continue;
                            },
                        }
                    },
                    Token.Id.Keyword_export => {
                        stack.append(State{ .ContainerDecl = container_decl }) catch unreachable;
                        try stack.append(State{
                            .TopLevelExtern = TopLevelDeclCtx{
                                .decls = &container_decl.fields_and_decls,
                                .visib_token = token_index,
                                .extern_export_inline_token = null,
                                .lib_name = null,
                                .comments = comments,
                            },
                        });
                        continue;
                    },
                    Token.Id.RBrace => {
                        if (comments != null) {
                            ((try tree.errors.addOne())).* = Error{ .UnattachedDocComment = Error.UnattachedDocComment{ .token = token_index } };
                            return tree;
                        }
                        container_decl.rbrace_token = token_index;
                        continue;
                    },
                    else => {
                        prevToken(&tok_it, &tree);
                        stack.append(State{ .ContainerDecl = container_decl }) catch unreachable;
                        try stack.append(State{
                            .TopLevelExtern = TopLevelDeclCtx{
                                .decls = &container_decl.fields_and_decls,
                                .visib_token = null,
                                .extern_export_inline_token = null,
                                .lib_name = null,
                                .comments = comments,
                            },
                        });
                        continue;
                    },
                }
            },

            State.VarDecl => |ctx| {
                const var_decl = try arena.create(ast.Node.VarDecl{
                    .base = ast.Node{ .id = ast.Node.Id.VarDecl },
                    .doc_comments = ctx.comments,
                    .visib_token = ctx.visib_token,
                    .mut_token = ctx.mut_token,
                    .comptime_token = ctx.comptime_token,
                    .extern_export_token = ctx.extern_export_token,
                    .type_node = null,
                    .align_node = null,
                    .init_node = null,
                    .lib_name = ctx.lib_name,
                    // initialized later
                    .name_token = undefined,
                    .eq_token = undefined,
                    .semicolon_token = undefined,
                });
                try ctx.list.push(&var_decl.base);

                try stack.append(State{ .VarDeclAlign = var_decl });
                try stack.append(State{ .TypeExprBegin = OptionalCtx{ .RequiredNull = &var_decl.type_node } });
                try stack.append(State{ .IfToken = Token.Id.Colon });
                try stack.append(State{
                    .ExpectTokenSave = ExpectTokenSave{
                        .id = Token.Id.Identifier,
                        .ptr = &var_decl.name_token,
                    },
                });
                continue;
            },
            State.VarDeclAlign => |var_decl| {
                try stack.append(State{ .VarDeclEq = var_decl });

                const next_token = nextToken(&tok_it, &tree);
                const next_token_index = next_token.index;
                const next_token_ptr = next_token.ptr;
                if (next_token_ptr.id == Token.Id.Keyword_align) {
                    try stack.append(State{ .ExpectToken = Token.Id.RParen });
                    try stack.append(State{ .Expression = OptionalCtx{ .RequiredNull = &var_decl.align_node } });
                    try stack.append(State{ .ExpectToken = Token.Id.LParen });
                    continue;
                }

                prevToken(&tok_it, &tree);
                continue;
            },
            State.VarDeclEq => |var_decl| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Equal => {
                        var_decl.eq_token = token_index;
                        stack.append(State{ .VarDeclSemiColon = var_decl }) catch unreachable;
                        try stack.append(State{ .Expression = OptionalCtx{ .RequiredNull = &var_decl.init_node } });
                        continue;
                    },
                    Token.Id.Semicolon => {
                        var_decl.semicolon_token = token_index;
                        continue;
                    },
                    else => {
                        ((try tree.errors.addOne())).* = Error{ .ExpectedEqOrSemi = Error.ExpectedEqOrSemi{ .token = token_index } };
                        return tree;
                    },
                }
            },

            State.VarDeclSemiColon => |var_decl| {
                const semicolon_token = nextToken(&tok_it, &tree);

                if (semicolon_token.ptr.id != Token.Id.Semicolon) {
                    ((try tree.errors.addOne())).* = Error{
                        .ExpectedToken = Error.ExpectedToken{
                            .token = semicolon_token.index,
                            .expected_id = Token.Id.Semicolon,
                        },
                    };
                    return tree;
                }

                var_decl.semicolon_token = semicolon_token.index;

                if (eatToken(&tok_it, &tree, Token.Id.DocComment)) |doc_comment_token| {
                    const loc = tree.tokenLocation(semicolon_token.ptr.end, doc_comment_token);
                    if (loc.line == 0) {
                        try pushDocComment(arena, doc_comment_token, &var_decl.doc_comments);
                    } else {
                        prevToken(&tok_it, &tree);
                    }
                }
            },

            State.FnDef => |fn_proto| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.LBrace => {
                        const block = try arena.create(ast.Node.Block{
                            .base = ast.Node{ .id = ast.Node.Id.Block },
                            .label = null,
                            .lbrace = token_index,
                            .statements = ast.Node.Block.StatementList.init(arena),
                            .rbrace = undefined,
                        });
                        fn_proto.body_node = &block.base;
                        stack.append(State{ .Block = block }) catch unreachable;
                        continue;
                    },
                    Token.Id.Semicolon => continue,
                    else => {
                        ((try tree.errors.addOne())).* = Error{ .ExpectedSemiOrLBrace = Error.ExpectedSemiOrLBrace{ .token = token_index } };
                        return tree;
                    },
                }
            },
            State.FnProto => |fn_proto| {
                stack.append(State{ .FnProtoAlign = fn_proto }) catch unreachable;
                try stack.append(State{ .ParamDecl = fn_proto });
                try stack.append(State{ .ExpectToken = Token.Id.LParen });

                if (eatToken(&tok_it, &tree, Token.Id.Identifier)) |name_token| {
                    fn_proto.name_token = name_token;
                }
                continue;
            },
            State.FnProtoAlign => |fn_proto| {
                stack.append(State{ .FnProtoReturnType = fn_proto }) catch unreachable;

                if (eatToken(&tok_it, &tree, Token.Id.Keyword_align)) |align_token| {
                    try stack.append(State{ .ExpectToken = Token.Id.RParen });
                    try stack.append(State{ .Expression = OptionalCtx{ .RequiredNull = &fn_proto.align_expr } });
                    try stack.append(State{ .ExpectToken = Token.Id.LParen });
                }
                continue;
            },
            State.FnProtoReturnType => |fn_proto| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Bang => {
                        fn_proto.return_type = ast.Node.FnProto.ReturnType{ .InferErrorSet = undefined };
                        stack.append(State{ .TypeExprBegin = OptionalCtx{ .Required = &fn_proto.return_type.InferErrorSet } }) catch unreachable;
                        continue;
                    },
                    else => {
                        // TODO: this is a special case. Remove this when #760 is fixed
                        if (token_ptr.id == Token.Id.Keyword_error) {
                            if (tok_it.peek().?.id == Token.Id.LBrace) {
                                const error_type_node = try arena.create(ast.Node.ErrorType{
                                    .base = ast.Node{ .id = ast.Node.Id.ErrorType },
                                    .token = token_index,
                                });
                                fn_proto.return_type = ast.Node.FnProto.ReturnType{ .Explicit = &error_type_node.base };
                                continue;
                            }
                        }

                        prevToken(&tok_it, &tree);
                        fn_proto.return_type = ast.Node.FnProto.ReturnType{ .Explicit = undefined };
                        stack.append(State{ .TypeExprBegin = OptionalCtx{ .Required = &fn_proto.return_type.Explicit } }) catch unreachable;
                        continue;
                    },
                }
            },

            State.ParamDecl => |fn_proto| {
                if (eatToken(&tok_it, &tree, Token.Id.RParen)) |_| {
                    continue;
                }
                const param_decl = try arena.create(ast.Node.ParamDecl{
                    .base = ast.Node{ .id = ast.Node.Id.ParamDecl },
                    .comptime_token = null,
                    .noalias_token = null,
                    .name_token = null,
                    .type_node = undefined,
                    .var_args_token = null,
                });
                try fn_proto.params.push(&param_decl.base);

                stack.append(State{
                    .ParamDeclEnd = ParamDeclEndCtx{
                        .param_decl = param_decl,
                        .fn_proto = fn_proto,
                    },
                }) catch unreachable;
                try stack.append(State{ .ParamDeclName = param_decl });
                try stack.append(State{ .ParamDeclAliasOrComptime = param_decl });
                continue;
            },
            State.ParamDeclAliasOrComptime => |param_decl| {
                if (eatToken(&tok_it, &tree, Token.Id.Keyword_comptime)) |comptime_token| {
                    param_decl.comptime_token = comptime_token;
                } else if (eatToken(&tok_it, &tree, Token.Id.Keyword_noalias)) |noalias_token| {
                    param_decl.noalias_token = noalias_token;
                }
                continue;
            },
            State.ParamDeclName => |param_decl| {
                // TODO: Here, we eat two tokens in one state. This means that we can't have
                //       comments between these two tokens.
                if (eatToken(&tok_it, &tree, Token.Id.Identifier)) |ident_token| {
                    if (eatToken(&tok_it, &tree, Token.Id.Colon)) |_| {
                        param_decl.name_token = ident_token;
                    } else {
                        prevToken(&tok_it, &tree);
                    }
                }
                continue;
            },
            State.ParamDeclEnd => |ctx| {
                if (eatToken(&tok_it, &tree, Token.Id.Ellipsis3)) |ellipsis3| {
                    ctx.param_decl.var_args_token = ellipsis3;
                    stack.append(State{ .ExpectToken = Token.Id.RParen }) catch unreachable;
                    continue;
                }

                try stack.append(State{ .ParamDeclComma = ctx.fn_proto });
                try stack.append(State{ .TypeExprBegin = OptionalCtx{ .Required = &ctx.param_decl.type_node } });
                continue;
            },
            State.ParamDeclComma => |fn_proto| {
                switch (expectCommaOrEnd(&tok_it, &tree, Token.Id.RParen)) {
                    ExpectCommaOrEndResult.end_token => |t| {
                        if (t == null) {
                            stack.append(State{ .ParamDecl = fn_proto }) catch unreachable;
                        }
                        continue;
                    },
                    ExpectCommaOrEndResult.parse_error => |e| {
                        try tree.errors.push(e);
                        return tree;
                    },
                }
            },

            State.MaybeLabeledExpression => |ctx| {
                if (eatToken(&tok_it, &tree, Token.Id.Colon)) |_| {
                    stack.append(State{
                        .LabeledExpression = LabelCtx{
                            .label = ctx.label,
                            .opt_ctx = ctx.opt_ctx,
                        },
                    }) catch unreachable;
                    continue;
                }

                _ = try createToCtxLiteral(arena, ctx.opt_ctx, ast.Node.Identifier, ctx.label);
                continue;
            },
            State.LabeledExpression => |ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.LBrace => {
                        const block = try arena.create(ast.Node.Block{
                            .base = ast.Node{ .id = ast.Node.Id.Block },
                            .label = ctx.label,
                            .lbrace = token_index,
                            .statements = ast.Node.Block.StatementList.init(arena),
                            .rbrace = undefined,
                        });
                        ctx.opt_ctx.store(&block.base);
                        stack.append(State{ .Block = block }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_while => {
                        stack.append(State{
                            .While = LoopCtx{
                                .label = ctx.label,
                                .inline_token = null,
                                .loop_token = token_index,
                                .opt_ctx = ctx.opt_ctx.toRequired(),
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_for => {
                        stack.append(State{
                            .For = LoopCtx{
                                .label = ctx.label,
                                .inline_token = null,
                                .loop_token = token_index,
                                .opt_ctx = ctx.opt_ctx.toRequired(),
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_suspend => {
                        const node = try arena.create(ast.Node.Suspend{
                            .base = ast.Node{ .id = ast.Node.Id.Suspend },
                            .label = ctx.label,
                            .suspend_token = token_index,
                            .payload = null,
                            .body = null,
                        });
                        ctx.opt_ctx.store(&node.base);
                        stack.append(State{ .SuspendBody = node }) catch unreachable;
                        try stack.append(State{ .Payload = OptionalCtx{ .Optional = &node.payload } });
                        continue;
                    },
                    Token.Id.Keyword_inline => {
                        stack.append(State{
                            .Inline = InlineCtx{
                                .label = ctx.label,
                                .inline_token = token_index,
                                .opt_ctx = ctx.opt_ctx.toRequired(),
                            },
                        }) catch unreachable;
                        continue;
                    },
                    else => {
                        if (ctx.opt_ctx != OptionalCtx.Optional) {
                            ((try tree.errors.addOne())).* = Error{ .ExpectedLabelable = Error.ExpectedLabelable{ .token = token_index } };
                            return tree;
                        }

                        prevToken(&tok_it, &tree);
                        continue;
                    },
                }
            },
            State.Inline => |ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Keyword_while => {
                        stack.append(State{
                            .While = LoopCtx{
                                .inline_token = ctx.inline_token,
                                .label = ctx.label,
                                .loop_token = token_index,
                                .opt_ctx = ctx.opt_ctx.toRequired(),
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_for => {
                        stack.append(State{
                            .For = LoopCtx{
                                .inline_token = ctx.inline_token,
                                .label = ctx.label,
                                .loop_token = token_index,
                                .opt_ctx = ctx.opt_ctx.toRequired(),
                            },
                        }) catch unreachable;
                        continue;
                    },
                    else => {
                        if (ctx.opt_ctx != OptionalCtx.Optional) {
                            ((try tree.errors.addOne())).* = Error{ .ExpectedInlinable = Error.ExpectedInlinable{ .token = token_index } };
                            return tree;
                        }

                        prevToken(&tok_it, &tree);
                        continue;
                    },
                }
            },
            State.While => |ctx| {
                const node = try arena.create(ast.Node.While{
                    .base = ast.Node{ .id = ast.Node.Id.While },
                    .label = ctx.label,
                    .inline_token = ctx.inline_token,
                    .while_token = ctx.loop_token,
                    .condition = undefined,
                    .payload = null,
                    .continue_expr = null,
                    .body = undefined,
                    .@"else" = null,
                });
                ctx.opt_ctx.store(&node.base);
                stack.append(State{ .Else = &node.@"else" }) catch unreachable;
                try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.body } });
                try stack.append(State{ .WhileContinueExpr = &node.continue_expr });
                try stack.append(State{ .IfToken = Token.Id.Colon });
                try stack.append(State{ .PointerPayload = OptionalCtx{ .Optional = &node.payload } });
                try stack.append(State{ .ExpectToken = Token.Id.RParen });
                try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.condition } });
                try stack.append(State{ .ExpectToken = Token.Id.LParen });
                continue;
            },
            State.WhileContinueExpr => |dest| {
                stack.append(State{ .ExpectToken = Token.Id.RParen }) catch unreachable;
                try stack.append(State{ .AssignmentExpressionBegin = OptionalCtx{ .RequiredNull = dest } });
                try stack.append(State{ .ExpectToken = Token.Id.LParen });
                continue;
            },
            State.For => |ctx| {
                const node = try arena.create(ast.Node.For{
                    .base = ast.Node{ .id = ast.Node.Id.For },
                    .label = ctx.label,
                    .inline_token = ctx.inline_token,
                    .for_token = ctx.loop_token,
                    .array_expr = undefined,
                    .payload = null,
                    .body = undefined,
                    .@"else" = null,
                });
                ctx.opt_ctx.store(&node.base);
                stack.append(State{ .Else = &node.@"else" }) catch unreachable;
                try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.body } });
                try stack.append(State{ .PointerIndexPayload = OptionalCtx{ .Optional = &node.payload } });
                try stack.append(State{ .ExpectToken = Token.Id.RParen });
                try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.array_expr } });
                try stack.append(State{ .ExpectToken = Token.Id.LParen });
                continue;
            },
            State.Else => |dest| {
                if (eatToken(&tok_it, &tree, Token.Id.Keyword_else)) |else_token| {
                    const node = try arena.create(ast.Node.Else{
                        .base = ast.Node{ .id = ast.Node.Id.Else },
                        .else_token = else_token,
                        .payload = null,
                        .body = undefined,
                    });
                    dest.* = node;

                    stack.append(State{ .Expression = OptionalCtx{ .Required = &node.body } }) catch unreachable;
                    try stack.append(State{ .Payload = OptionalCtx{ .Optional = &node.payload } });
                    continue;
                } else {
                    continue;
                }
            },

            State.Block => |block| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.RBrace => {
                        block.rbrace = token_index;
                        continue;
                    },
                    else => {
                        prevToken(&tok_it, &tree);
                        stack.append(State{ .Block = block }) catch unreachable;

                        try stack.append(State{ .Statement = block });
                        continue;
                    },
                }
            },
            State.Statement => |block| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Keyword_comptime => {
                        stack.append(State{
                            .ComptimeStatement = ComptimeStatementCtx{
                                .comptime_token = token_index,
                                .block = block,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_var, Token.Id.Keyword_const => {
                        stack.append(State{
                            .VarDecl = VarDeclCtx{
                                .comments = null,
                                .visib_token = null,
                                .comptime_token = null,
                                .extern_export_token = null,
                                .lib_name = null,
                                .mut_token = token_index,
                                .list = &block.statements,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_defer, Token.Id.Keyword_errdefer => {
                        const node = try arena.create(ast.Node.Defer{
                            .base = ast.Node{ .id = ast.Node.Id.Defer },
                            .defer_token = token_index,
                            .kind = switch (token_ptr.id) {
                                Token.Id.Keyword_defer => ast.Node.Defer.Kind.Unconditional,
                                Token.Id.Keyword_errdefer => ast.Node.Defer.Kind.Error,
                                else => unreachable,
                            },
                            .expr = undefined,
                        });
                        const node_ptr = try block.statements.addOne();
                        node_ptr.* = &node.base;

                        stack.append(State{ .Semicolon = node_ptr }) catch unreachable;
                        try stack.append(State{ .AssignmentExpressionBegin = OptionalCtx{ .Required = &node.expr } });
                        continue;
                    },
                    Token.Id.LBrace => {
                        const inner_block = try arena.create(ast.Node.Block{
                            .base = ast.Node{ .id = ast.Node.Id.Block },
                            .label = null,
                            .lbrace = token_index,
                            .statements = ast.Node.Block.StatementList.init(arena),
                            .rbrace = undefined,
                        });
                        try block.statements.push(&inner_block.base);

                        stack.append(State{ .Block = inner_block }) catch unreachable;
                        continue;
                    },
                    else => {
                        prevToken(&tok_it, &tree);
                        const statement = try block.statements.addOne();
                        try stack.append(State{ .Semicolon = statement });
                        try stack.append(State{ .AssignmentExpressionBegin = OptionalCtx{ .Required = statement } });
                        continue;
                    },
                }
            },
            State.ComptimeStatement => |ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Keyword_var, Token.Id.Keyword_const => {
                        stack.append(State{
                            .VarDecl = VarDeclCtx{
                                .comments = null,
                                .visib_token = null,
                                .comptime_token = ctx.comptime_token,
                                .extern_export_token = null,
                                .lib_name = null,
                                .mut_token = token_index,
                                .list = &ctx.block.statements,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    else => {
                        prevToken(&tok_it, &tree);
                        prevToken(&tok_it, &tree);
                        const statement = try ctx.block.statements.addOne();
                        try stack.append(State{ .Semicolon = statement });
                        try stack.append(State{ .Expression = OptionalCtx{ .Required = statement } });
                        continue;
                    },
                }
            },
            State.Semicolon => |node_ptr| {
                const node = node_ptr.*;
                if (node.requireSemiColon()) {
                    stack.append(State{ .ExpectToken = Token.Id.Semicolon }) catch unreachable;
                    continue;
                }
                continue;
            },

            State.AsmOutputItems => |items| {
                const lbracket = nextToken(&tok_it, &tree);
                const lbracket_index = lbracket.index;
                const lbracket_ptr = lbracket.ptr;
                if (lbracket_ptr.id != Token.Id.LBracket) {
                    prevToken(&tok_it, &tree);
                    continue;
                }

                const node = try arena.create(ast.Node.AsmOutput{
                    .base = ast.Node{ .id = ast.Node.Id.AsmOutput },
                    .lbracket = lbracket_index,
                    .symbolic_name = undefined,
                    .constraint = undefined,
                    .kind = undefined,
                    .rparen = undefined,
                });
                try items.push(node);

                stack.append(State{ .AsmOutputItems = items }) catch unreachable;
                try stack.append(State{ .IfToken = Token.Id.Comma });
                try stack.append(State{
                    .ExpectTokenSave = ExpectTokenSave{
                        .id = Token.Id.RParen,
                        .ptr = &node.rparen,
                    },
                });
                try stack.append(State{ .AsmOutputReturnOrType = node });
                try stack.append(State{ .ExpectToken = Token.Id.LParen });
                try stack.append(State{ .StringLiteral = OptionalCtx{ .Required = &node.constraint } });
                try stack.append(State{ .ExpectToken = Token.Id.RBracket });
                try stack.append(State{ .Identifier = OptionalCtx{ .Required = &node.symbolic_name } });
                continue;
            },
            State.AsmOutputReturnOrType => |node| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Identifier => {
                        node.kind = ast.Node.AsmOutput.Kind{ .Variable = try createLiteral(arena, ast.Node.Identifier, token_index) };
                        continue;
                    },
                    Token.Id.Arrow => {
                        node.kind = ast.Node.AsmOutput.Kind{ .Return = undefined };
                        try stack.append(State{ .TypeExprBegin = OptionalCtx{ .Required = &node.kind.Return } });
                        continue;
                    },
                    else => {
                        ((try tree.errors.addOne())).* = Error{ .ExpectedAsmOutputReturnOrType = Error.ExpectedAsmOutputReturnOrType{ .token = token_index } };
                        return tree;
                    },
                }
            },
            State.AsmInputItems => |items| {
                const lbracket = nextToken(&tok_it, &tree);
                const lbracket_index = lbracket.index;
                const lbracket_ptr = lbracket.ptr;
                if (lbracket_ptr.id != Token.Id.LBracket) {
                    prevToken(&tok_it, &tree);
                    continue;
                }

                const node = try arena.create(ast.Node.AsmInput{
                    .base = ast.Node{ .id = ast.Node.Id.AsmInput },
                    .lbracket = lbracket_index,
                    .symbolic_name = undefined,
                    .constraint = undefined,
                    .expr = undefined,
                    .rparen = undefined,
                });
                try items.push(node);

                stack.append(State{ .AsmInputItems = items }) catch unreachable;
                try stack.append(State{ .IfToken = Token.Id.Comma });
                try stack.append(State{
                    .ExpectTokenSave = ExpectTokenSave{
                        .id = Token.Id.RParen,
                        .ptr = &node.rparen,
                    },
                });
                try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.expr } });
                try stack.append(State{ .ExpectToken = Token.Id.LParen });
                try stack.append(State{ .StringLiteral = OptionalCtx{ .Required = &node.constraint } });
                try stack.append(State{ .ExpectToken = Token.Id.RBracket });
                try stack.append(State{ .Identifier = OptionalCtx{ .Required = &node.symbolic_name } });
                continue;
            },
            State.AsmClobberItems => |items| {
                while (eatToken(&tok_it, &tree, Token.Id.StringLiteral)) |strlit| {
                    try items.push(strlit);
                    if (eatToken(&tok_it, &tree, Token.Id.Comma) == null)
                        break;
                }
                continue;
            },

            State.ExprListItemOrEnd => |list_state| {
                if (eatToken(&tok_it, &tree, list_state.end)) |token_index| {
                    (list_state.ptr).* = token_index;
                    continue;
                }

                stack.append(State{ .ExprListCommaOrEnd = list_state }) catch unreachable;
                try stack.append(State{ .Expression = OptionalCtx{ .Required = try list_state.list.addOne() } });
                continue;
            },
            State.ExprListCommaOrEnd => |list_state| {
                switch (expectCommaOrEnd(&tok_it, &tree, list_state.end)) {
                    ExpectCommaOrEndResult.end_token => |maybe_end| if (maybe_end) |end| {
                        (list_state.ptr).* = end;
                        continue;
                    } else {
                        stack.append(State{ .ExprListItemOrEnd = list_state }) catch unreachable;
                        continue;
                    },
                    ExpectCommaOrEndResult.parse_error => |e| {
                        try tree.errors.push(e);
                        return tree;
                    },
                }
            },
            State.FieldInitListItemOrEnd => |list_state| {
                if (eatToken(&tok_it, &tree, Token.Id.RBrace)) |rbrace| {
                    (list_state.ptr).* = rbrace;
                    continue;
                }

                const node = try arena.create(ast.Node.FieldInitializer{
                    .base = ast.Node{ .id = ast.Node.Id.FieldInitializer },
                    .period_token = undefined,
                    .name_token = undefined,
                    .expr = undefined,
                });
                try list_state.list.push(&node.base);

                stack.append(State{ .FieldInitListCommaOrEnd = list_state }) catch unreachable;
                try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.expr } });
                try stack.append(State{ .ExpectToken = Token.Id.Equal });
                try stack.append(State{
                    .ExpectTokenSave = ExpectTokenSave{
                        .id = Token.Id.Identifier,
                        .ptr = &node.name_token,
                    },
                });
                try stack.append(State{
                    .ExpectTokenSave = ExpectTokenSave{
                        .id = Token.Id.Period,
                        .ptr = &node.period_token,
                    },
                });
                continue;
            },
            State.FieldInitListCommaOrEnd => |list_state| {
                switch (expectCommaOrEnd(&tok_it, &tree, Token.Id.RBrace)) {
                    ExpectCommaOrEndResult.end_token => |maybe_end| if (maybe_end) |end| {
                        (list_state.ptr).* = end;
                        continue;
                    } else {
                        stack.append(State{ .FieldInitListItemOrEnd = list_state }) catch unreachable;
                        continue;
                    },
                    ExpectCommaOrEndResult.parse_error => |e| {
                        try tree.errors.push(e);
                        return tree;
                    },
                }
            },
            State.FieldListCommaOrEnd => |container_decl| {
                switch (expectCommaOrEnd(&tok_it, &tree, Token.Id.RBrace)) {
                    ExpectCommaOrEndResult.end_token => |maybe_end| if (maybe_end) |end| {
                        container_decl.rbrace_token = end;
                        continue;
                    } else {
                        try stack.append(State{ .ContainerDecl = container_decl });
                        continue;
                    },
                    ExpectCommaOrEndResult.parse_error => |e| {
                        try tree.errors.push(e);
                        return tree;
                    },
                }
            },
            State.ErrorTagListItemOrEnd => |list_state| {
                if (eatToken(&tok_it, &tree, Token.Id.RBrace)) |rbrace| {
                    (list_state.ptr).* = rbrace;
                    continue;
                }

                const node_ptr = try list_state.list.addOne();

                try stack.append(State{ .ErrorTagListCommaOrEnd = list_state });
                try stack.append(State{ .ErrorTag = node_ptr });
                continue;
            },
            State.ErrorTagListCommaOrEnd => |list_state| {
                switch (expectCommaOrEnd(&tok_it, &tree, Token.Id.RBrace)) {
                    ExpectCommaOrEndResult.end_token => |maybe_end| if (maybe_end) |end| {
                        (list_state.ptr).* = end;
                        continue;
                    } else {
                        stack.append(State{ .ErrorTagListItemOrEnd = list_state }) catch unreachable;
                        continue;
                    },
                    ExpectCommaOrEndResult.parse_error => |e| {
                        try tree.errors.push(e);
                        return tree;
                    },
                }
            },
            State.SwitchCaseOrEnd => |list_state| {
                if (eatToken(&tok_it, &tree, Token.Id.RBrace)) |rbrace| {
                    (list_state.ptr).* = rbrace;
                    continue;
                }

                const comments = try eatDocComments(arena, &tok_it, &tree);
                const node = try arena.create(ast.Node.SwitchCase{
                    .base = ast.Node{ .id = ast.Node.Id.SwitchCase },
                    .items = ast.Node.SwitchCase.ItemList.init(arena),
                    .payload = null,
                    .expr = undefined,
                    .arrow_token = undefined,
                });
                try list_state.list.push(&node.base);
                try stack.append(State{ .SwitchCaseCommaOrEnd = list_state });
                try stack.append(State{ .AssignmentExpressionBegin = OptionalCtx{ .Required = &node.expr } });
                try stack.append(State{ .PointerPayload = OptionalCtx{ .Optional = &node.payload } });
                try stack.append(State{ .SwitchCaseFirstItem = node });

                continue;
            },

            State.SwitchCaseCommaOrEnd => |list_state| {
                switch (expectCommaOrEnd(&tok_it, &tree, Token.Id.RBrace)) {
                    ExpectCommaOrEndResult.end_token => |maybe_end| if (maybe_end) |end| {
                        (list_state.ptr).* = end;
                        continue;
                    } else {
                        try stack.append(State{ .SwitchCaseOrEnd = list_state });
                        continue;
                    },
                    ExpectCommaOrEndResult.parse_error => |e| {
                        try tree.errors.push(e);
                        return tree;
                    },
                }
            },

            State.SwitchCaseFirstItem => |switch_case| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (token_ptr.id == Token.Id.Keyword_else) {
                    const else_node = try arena.create(ast.Node.SwitchElse{
                        .base = ast.Node{ .id = ast.Node.Id.SwitchElse },
                        .token = token_index,
                    });
                    try switch_case.items.push(&else_node.base);

                    try stack.append(State{
                        .ExpectTokenSave = ExpectTokenSave{
                            .id = Token.Id.EqualAngleBracketRight,
                            .ptr = &switch_case.arrow_token,
                        },
                    });
                    continue;
                } else {
                    prevToken(&tok_it, &tree);
                    stack.append(State{ .SwitchCaseItemCommaOrEnd = switch_case }) catch unreachable;
                    try stack.append(State{ .RangeExpressionBegin = OptionalCtx{ .Required = try switch_case.items.addOne() } });
                    continue;
                }
            },
            State.SwitchCaseItemOrEnd => |switch_case| {
                const token = nextToken(&tok_it, &tree);
                if (token.ptr.id == Token.Id.EqualAngleBracketRight) {
                    switch_case.arrow_token = token.index;
                    continue;
                } else {
                    prevToken(&tok_it, &tree);
                    stack.append(State{ .SwitchCaseItemCommaOrEnd = switch_case }) catch unreachable;
                    try stack.append(State{ .RangeExpressionBegin = OptionalCtx{ .Required = try switch_case.items.addOne() } });
                    continue;
                }
            },
            State.SwitchCaseItemCommaOrEnd => |switch_case| {
                switch (expectCommaOrEnd(&tok_it, &tree, Token.Id.EqualAngleBracketRight)) {
                    ExpectCommaOrEndResult.end_token => |end_token| {
                        if (end_token) |t| {
                            switch_case.arrow_token = t;
                        } else {
                            stack.append(State{ .SwitchCaseItemOrEnd = switch_case }) catch unreachable;
                        }
                        continue;
                    },
                    ExpectCommaOrEndResult.parse_error => |e| {
                        try tree.errors.push(e);
                        return tree;
                    },
                }
                continue;
            },

            State.SuspendBody => |suspend_node| {
                if (suspend_node.payload != null) {
                    try stack.append(State{ .AssignmentExpressionBegin = OptionalCtx{ .RequiredNull = &suspend_node.body } });
                }
                continue;
            },
            State.AsyncAllocator => |async_node| {
                if (eatToken(&tok_it, &tree, Token.Id.AngleBracketLeft) == null) {
                    continue;
                }

                async_node.rangle_bracket = TokenIndex(0);
                try stack.append(State{
                    .ExpectTokenSave = ExpectTokenSave{
                        .id = Token.Id.AngleBracketRight,
                        .ptr = &async_node.rangle_bracket.?,
                    },
                });
                try stack.append(State{ .TypeExprBegin = OptionalCtx{ .RequiredNull = &async_node.allocator_type } });
                continue;
            },
            State.AsyncEnd => |ctx| {
                const node = ctx.ctx.get() orelse continue;

                switch (node.id) {
                    ast.Node.Id.FnProto => {
                        const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", node);
                        fn_proto.async_attr = ctx.attribute;
                        continue;
                    },
                    ast.Node.Id.SuffixOp => {
                        const suffix_op = @fieldParentPtr(ast.Node.SuffixOp, "base", node);
                        if (suffix_op.op == @TagType(ast.Node.SuffixOp.Op).Call) {
                            suffix_op.op.Call.async_attr = ctx.attribute;
                            continue;
                        }

                        ((try tree.errors.addOne())).* = Error{ .ExpectedCall = Error.ExpectedCall{ .node = node } };
                        return tree;
                    },
                    else => {
                        ((try tree.errors.addOne())).* = Error{ .ExpectedCallOrFnProto = Error.ExpectedCallOrFnProto{ .node = node } };
                        return tree;
                    },
                }
            },

            State.ExternType => |ctx| {
                if (eatToken(&tok_it, &tree, Token.Id.Keyword_fn)) |fn_token| {
                    const fn_proto = try arena.create(ast.Node.FnProto{
                        .base = ast.Node{ .id = ast.Node.Id.FnProto },
                        .doc_comments = ctx.comments,
                        .visib_token = null,
                        .name_token = null,
                        .fn_token = fn_token,
                        .params = ast.Node.FnProto.ParamList.init(arena),
                        .return_type = undefined,
                        .var_args_token = null,
                        .extern_export_inline_token = ctx.extern_token,
                        .cc_token = null,
                        .async_attr = null,
                        .body_node = null,
                        .lib_name = null,
                        .align_expr = null,
                    });
                    ctx.opt_ctx.store(&fn_proto.base);
                    stack.append(State{ .FnProto = fn_proto }) catch unreachable;
                    continue;
                }

                stack.append(State{
                    .ContainerKind = ContainerKindCtx{
                        .opt_ctx = ctx.opt_ctx,
                        .layout_token = ctx.extern_token,
                    },
                }) catch unreachable;
                continue;
            },
            State.SliceOrArrayAccess => |node| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Ellipsis2 => {
                        const start = node.op.ArrayAccess;
                        node.op = ast.Node.SuffixOp.Op{
                            .Slice = ast.Node.SuffixOp.Op.Slice{
                                .start = start,
                                .end = null,
                            },
                        };

                        stack.append(State{
                            .ExpectTokenSave = ExpectTokenSave{
                                .id = Token.Id.RBracket,
                                .ptr = &node.rtoken,
                            },
                        }) catch unreachable;
                        try stack.append(State{ .Expression = OptionalCtx{ .Optional = &node.op.Slice.end } });
                        continue;
                    },
                    Token.Id.RBracket => {
                        node.rtoken = token_index;
                        continue;
                    },
                    else => {
                        ((try tree.errors.addOne())).* = Error{ .ExpectedSliceOrRBracket = Error.ExpectedSliceOrRBracket{ .token = token_index } };
                        return tree;
                    },
                }
            },
            State.SliceOrArrayType => |node| {
                if (eatToken(&tok_it, &tree, Token.Id.RBracket)) |_| {
                    node.op = ast.Node.PrefixOp.Op{
                        .SliceType = ast.Node.PrefixOp.PtrInfo{
                            .align_info = null,
                            .const_token = null,
                            .volatile_token = null,
                        },
                    };
                    stack.append(State{ .TypeExprBegin = OptionalCtx{ .Required = &node.rhs } }) catch unreachable;
                    try stack.append(State{ .PtrTypeModifiers = &node.op.SliceType });
                    continue;
                }

                node.op = ast.Node.PrefixOp.Op{ .ArrayType = undefined };
                stack.append(State{ .TypeExprBegin = OptionalCtx{ .Required = &node.rhs } }) catch unreachable;
                try stack.append(State{ .ExpectToken = Token.Id.RBracket });
                try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.op.ArrayType } });
                continue;
            },

            State.PtrTypeModifiers => |addr_of_info| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Keyword_align => {
                        stack.append(state) catch unreachable;
                        if (addr_of_info.align_info != null) {
                            ((try tree.errors.addOne())).* = Error{ .ExtraAlignQualifier = Error.ExtraAlignQualifier{ .token = token_index } };
                            return tree;
                        }
                        addr_of_info.align_info = ast.Node.PrefixOp.PtrInfo.Align{
                            .node = undefined,
                            .bit_range = null,
                        };
                        // TODO https://github.com/ziglang/zig/issues/1022
                        const align_info = &addr_of_info.align_info.?;

                        try stack.append(State{ .AlignBitRange = align_info });
                        try stack.append(State{ .Expression = OptionalCtx{ .Required = &align_info.node } });
                        try stack.append(State{ .ExpectToken = Token.Id.LParen });
                        continue;
                    },
                    Token.Id.Keyword_const => {
                        stack.append(state) catch unreachable;
                        if (addr_of_info.const_token != null) {
                            ((try tree.errors.addOne())).* = Error{ .ExtraConstQualifier = Error.ExtraConstQualifier{ .token = token_index } };
                            return tree;
                        }
                        addr_of_info.const_token = token_index;
                        continue;
                    },
                    Token.Id.Keyword_volatile => {
                        stack.append(state) catch unreachable;
                        if (addr_of_info.volatile_token != null) {
                            ((try tree.errors.addOne())).* = Error{ .ExtraVolatileQualifier = Error.ExtraVolatileQualifier{ .token = token_index } };
                            return tree;
                        }
                        addr_of_info.volatile_token = token_index;
                        continue;
                    },
                    else => {
                        prevToken(&tok_it, &tree);
                        continue;
                    },
                }
            },

            State.AlignBitRange => |align_info| {
                const token = nextToken(&tok_it, &tree);
                switch (token.ptr.id) {
                    Token.Id.Colon => {
                        align_info.bit_range = ast.Node.PrefixOp.PtrInfo.Align.BitRange(undefined);
                        const bit_range = &align_info.bit_range.?;

                        try stack.append(State{ .ExpectToken = Token.Id.RParen });
                        try stack.append(State{ .Expression = OptionalCtx{ .Required = &bit_range.end } });
                        try stack.append(State{ .ExpectToken = Token.Id.Colon });
                        try stack.append(State{ .Expression = OptionalCtx{ .Required = &bit_range.start } });
                        continue;
                    },
                    Token.Id.RParen => continue,
                    else => {
                        (try tree.errors.addOne()).* = Error{
                            .ExpectedColonOrRParen = Error.ExpectedColonOrRParen{ .token = token.index },
                        };
                        return tree;
                    },
                }
            },

            State.Payload => |opt_ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (token_ptr.id != Token.Id.Pipe) {
                    if (opt_ctx != OptionalCtx.Optional) {
                        ((try tree.errors.addOne())).* = Error{
                            .ExpectedToken = Error.ExpectedToken{
                                .token = token_index,
                                .expected_id = Token.Id.Pipe,
                            },
                        };
                        return tree;
                    }

                    prevToken(&tok_it, &tree);
                    continue;
                }

                const node = try arena.create(ast.Node.Payload{
                    .base = ast.Node{ .id = ast.Node.Id.Payload },
                    .lpipe = token_index,
                    .error_symbol = undefined,
                    .rpipe = undefined,
                });
                opt_ctx.store(&node.base);

                stack.append(State{
                    .ExpectTokenSave = ExpectTokenSave{
                        .id = Token.Id.Pipe,
                        .ptr = &node.rpipe,
                    },
                }) catch unreachable;
                try stack.append(State{ .Identifier = OptionalCtx{ .Required = &node.error_symbol } });
                continue;
            },
            State.PointerPayload => |opt_ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (token_ptr.id != Token.Id.Pipe) {
                    if (opt_ctx != OptionalCtx.Optional) {
                        ((try tree.errors.addOne())).* = Error{
                            .ExpectedToken = Error.ExpectedToken{
                                .token = token_index,
                                .expected_id = Token.Id.Pipe,
                            },
                        };
                        return tree;
                    }

                    prevToken(&tok_it, &tree);
                    continue;
                }

                const node = try arena.create(ast.Node.PointerPayload{
                    .base = ast.Node{ .id = ast.Node.Id.PointerPayload },
                    .lpipe = token_index,
                    .ptr_token = null,
                    .value_symbol = undefined,
                    .rpipe = undefined,
                });
                opt_ctx.store(&node.base);

                try stack.append(State{
                    .ExpectTokenSave = ExpectTokenSave{
                        .id = Token.Id.Pipe,
                        .ptr = &node.rpipe,
                    },
                });
                try stack.append(State{ .Identifier = OptionalCtx{ .Required = &node.value_symbol } });
                try stack.append(State{
                    .OptionalTokenSave = OptionalTokenSave{
                        .id = Token.Id.Asterisk,
                        .ptr = &node.ptr_token,
                    },
                });
                continue;
            },
            State.PointerIndexPayload => |opt_ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (token_ptr.id != Token.Id.Pipe) {
                    if (opt_ctx != OptionalCtx.Optional) {
                        ((try tree.errors.addOne())).* = Error{
                            .ExpectedToken = Error.ExpectedToken{
                                .token = token_index,
                                .expected_id = Token.Id.Pipe,
                            },
                        };
                        return tree;
                    }

                    prevToken(&tok_it, &tree);
                    continue;
                }

                const node = try arena.create(ast.Node.PointerIndexPayload{
                    .base = ast.Node{ .id = ast.Node.Id.PointerIndexPayload },
                    .lpipe = token_index,
                    .ptr_token = null,
                    .value_symbol = undefined,
                    .index_symbol = null,
                    .rpipe = undefined,
                });
                opt_ctx.store(&node.base);

                stack.append(State{
                    .ExpectTokenSave = ExpectTokenSave{
                        .id = Token.Id.Pipe,
                        .ptr = &node.rpipe,
                    },
                }) catch unreachable;
                try stack.append(State{ .Identifier = OptionalCtx{ .RequiredNull = &node.index_symbol } });
                try stack.append(State{ .IfToken = Token.Id.Comma });
                try stack.append(State{ .Identifier = OptionalCtx{ .Required = &node.value_symbol } });
                try stack.append(State{
                    .OptionalTokenSave = OptionalTokenSave{
                        .id = Token.Id.Asterisk,
                        .ptr = &node.ptr_token,
                    },
                });
                continue;
            },

            State.Expression => |opt_ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Keyword_return, Token.Id.Keyword_break, Token.Id.Keyword_continue => {
                        const node = try arena.create(ast.Node.ControlFlowExpression{
                            .base = ast.Node{ .id = ast.Node.Id.ControlFlowExpression },
                            .ltoken = token_index,
                            .kind = undefined,
                            .rhs = null,
                        });
                        opt_ctx.store(&node.base);

                        stack.append(State{ .Expression = OptionalCtx{ .Optional = &node.rhs } }) catch unreachable;

                        switch (token_ptr.id) {
                            Token.Id.Keyword_break => {
                                node.kind = ast.Node.ControlFlowExpression.Kind{ .Break = null };
                                try stack.append(State{ .Identifier = OptionalCtx{ .RequiredNull = &node.kind.Break } });
                                try stack.append(State{ .IfToken = Token.Id.Colon });
                            },
                            Token.Id.Keyword_continue => {
                                node.kind = ast.Node.ControlFlowExpression.Kind{ .Continue = null };
                                try stack.append(State{ .Identifier = OptionalCtx{ .RequiredNull = &node.kind.Continue } });
                                try stack.append(State{ .IfToken = Token.Id.Colon });
                            },
                            Token.Id.Keyword_return => {
                                node.kind = ast.Node.ControlFlowExpression.Kind.Return;
                            },
                            else => unreachable,
                        }
                        continue;
                    },
                    Token.Id.Keyword_try, Token.Id.Keyword_cancel, Token.Id.Keyword_resume => {
                        const node = try arena.create(ast.Node.PrefixOp{
                            .base = ast.Node{ .id = ast.Node.Id.PrefixOp },
                            .op_token = token_index,
                            .op = switch (token_ptr.id) {
                                Token.Id.Keyword_try => ast.Node.PrefixOp.Op{ .Try = void{} },
                                Token.Id.Keyword_cancel => ast.Node.PrefixOp.Op{ .Cancel = void{} },
                                Token.Id.Keyword_resume => ast.Node.PrefixOp.Op{ .Resume = void{} },
                                else => unreachable,
                            },
                            .rhs = undefined,
                        });
                        opt_ctx.store(&node.base);

                        stack.append(State{ .Expression = OptionalCtx{ .Required = &node.rhs } }) catch unreachable;
                        continue;
                    },
                    else => {
                        if (!try parseBlockExpr(&stack, arena, opt_ctx, token_ptr, token_index)) {
                            prevToken(&tok_it, &tree);
                            stack.append(State{ .UnwrapExpressionBegin = opt_ctx }) catch unreachable;
                        }
                        continue;
                    },
                }
            },
            State.RangeExpressionBegin => |opt_ctx| {
                stack.append(State{ .RangeExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .Expression = opt_ctx });
                continue;
            },
            State.RangeExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                if (eatToken(&tok_it, &tree, Token.Id.Ellipsis3)) |ellipsis3| {
                    const node = try arena.create(ast.Node.InfixOp{
                        .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                        .lhs = lhs,
                        .op_token = ellipsis3,
                        .op = ast.Node.InfixOp.Op.Range,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);
                    stack.append(State{ .Expression = OptionalCtx{ .Required = &node.rhs } }) catch unreachable;
                    continue;
                }
            },
            State.AssignmentExpressionBegin => |opt_ctx| {
                stack.append(State{ .AssignmentExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .Expression = opt_ctx });
                continue;
            },

            State.AssignmentExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToAssignment(token_ptr.id)) |ass_id| {
                    const node = try arena.create(ast.Node.InfixOp{
                        .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                        .lhs = lhs,
                        .op_token = token_index,
                        .op = ass_id,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);
                    stack.append(State{ .AssignmentExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.rhs } });
                    continue;
                } else {
                    prevToken(&tok_it, &tree);
                    continue;
                }
            },

            State.UnwrapExpressionBegin => |opt_ctx| {
                stack.append(State{ .UnwrapExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .BoolOrExpressionBegin = opt_ctx });
                continue;
            },

            State.UnwrapExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToUnwrapExpr(token_ptr.id)) |unwrap_id| {
                    const node = try arena.create(ast.Node.InfixOp{
                        .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                        .lhs = lhs,
                        .op_token = token_index,
                        .op = unwrap_id,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);

                    stack.append(State{ .UnwrapExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.rhs } });

                    if (node.op == ast.Node.InfixOp.Op.Catch) {
                        try stack.append(State{ .Payload = OptionalCtx{ .Optional = &node.op.Catch } });
                    }
                    continue;
                } else {
                    prevToken(&tok_it, &tree);
                    continue;
                }
            },

            State.BoolOrExpressionBegin => |opt_ctx| {
                stack.append(State{ .BoolOrExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .BoolAndExpressionBegin = opt_ctx });
                continue;
            },

            State.BoolOrExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                if (eatToken(&tok_it, &tree, Token.Id.Keyword_or)) |or_token| {
                    const node = try arena.create(ast.Node.InfixOp{
                        .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                        .lhs = lhs,
                        .op_token = or_token,
                        .op = ast.Node.InfixOp.Op.BoolOr,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);
                    stack.append(State{ .BoolOrExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State{ .BoolAndExpressionBegin = OptionalCtx{ .Required = &node.rhs } });
                    continue;
                }
            },

            State.BoolAndExpressionBegin => |opt_ctx| {
                stack.append(State{ .BoolAndExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .ComparisonExpressionBegin = opt_ctx });
                continue;
            },

            State.BoolAndExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                if (eatToken(&tok_it, &tree, Token.Id.Keyword_and)) |and_token| {
                    const node = try arena.create(ast.Node.InfixOp{
                        .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                        .lhs = lhs,
                        .op_token = and_token,
                        .op = ast.Node.InfixOp.Op.BoolAnd,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);
                    stack.append(State{ .BoolAndExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State{ .ComparisonExpressionBegin = OptionalCtx{ .Required = &node.rhs } });
                    continue;
                }
            },

            State.ComparisonExpressionBegin => |opt_ctx| {
                stack.append(State{ .ComparisonExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .BinaryOrExpressionBegin = opt_ctx });
                continue;
            },

            State.ComparisonExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToComparison(token_ptr.id)) |comp_id| {
                    const node = try arena.create(ast.Node.InfixOp{
                        .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                        .lhs = lhs,
                        .op_token = token_index,
                        .op = comp_id,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);
                    stack.append(State{ .ComparisonExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State{ .BinaryOrExpressionBegin = OptionalCtx{ .Required = &node.rhs } });
                    continue;
                } else {
                    prevToken(&tok_it, &tree);
                    continue;
                }
            },

            State.BinaryOrExpressionBegin => |opt_ctx| {
                stack.append(State{ .BinaryOrExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .BinaryXorExpressionBegin = opt_ctx });
                continue;
            },

            State.BinaryOrExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                if (eatToken(&tok_it, &tree, Token.Id.Pipe)) |pipe| {
                    const node = try arena.create(ast.Node.InfixOp{
                        .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                        .lhs = lhs,
                        .op_token = pipe,
                        .op = ast.Node.InfixOp.Op.BitOr,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);
                    stack.append(State{ .BinaryOrExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State{ .BinaryXorExpressionBegin = OptionalCtx{ .Required = &node.rhs } });
                    continue;
                }
            },

            State.BinaryXorExpressionBegin => |opt_ctx| {
                stack.append(State{ .BinaryXorExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .BinaryAndExpressionBegin = opt_ctx });
                continue;
            },

            State.BinaryXorExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                if (eatToken(&tok_it, &tree, Token.Id.Caret)) |caret| {
                    const node = try arena.create(ast.Node.InfixOp{
                        .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                        .lhs = lhs,
                        .op_token = caret,
                        .op = ast.Node.InfixOp.Op.BitXor,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);
                    stack.append(State{ .BinaryXorExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State{ .BinaryAndExpressionBegin = OptionalCtx{ .Required = &node.rhs } });
                    continue;
                }
            },

            State.BinaryAndExpressionBegin => |opt_ctx| {
                stack.append(State{ .BinaryAndExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .BitShiftExpressionBegin = opt_ctx });
                continue;
            },

            State.BinaryAndExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                if (eatToken(&tok_it, &tree, Token.Id.Ampersand)) |ampersand| {
                    const node = try arena.create(ast.Node.InfixOp{
                        .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                        .lhs = lhs,
                        .op_token = ampersand,
                        .op = ast.Node.InfixOp.Op.BitAnd,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);
                    stack.append(State{ .BinaryAndExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State{ .BitShiftExpressionBegin = OptionalCtx{ .Required = &node.rhs } });
                    continue;
                }
            },

            State.BitShiftExpressionBegin => |opt_ctx| {
                stack.append(State{ .BitShiftExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .AdditionExpressionBegin = opt_ctx });
                continue;
            },

            State.BitShiftExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToBitShift(token_ptr.id)) |bitshift_id| {
                    const node = try arena.create(ast.Node.InfixOp{
                        .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                        .lhs = lhs,
                        .op_token = token_index,
                        .op = bitshift_id,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);
                    stack.append(State{ .BitShiftExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State{ .AdditionExpressionBegin = OptionalCtx{ .Required = &node.rhs } });
                    continue;
                } else {
                    prevToken(&tok_it, &tree);
                    continue;
                }
            },

            State.AdditionExpressionBegin => |opt_ctx| {
                stack.append(State{ .AdditionExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .MultiplyExpressionBegin = opt_ctx });
                continue;
            },

            State.AdditionExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToAddition(token_ptr.id)) |add_id| {
                    const node = try arena.create(ast.Node.InfixOp{
                        .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                        .lhs = lhs,
                        .op_token = token_index,
                        .op = add_id,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);
                    stack.append(State{ .AdditionExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State{ .MultiplyExpressionBegin = OptionalCtx{ .Required = &node.rhs } });
                    continue;
                } else {
                    prevToken(&tok_it, &tree);
                    continue;
                }
            },

            State.MultiplyExpressionBegin => |opt_ctx| {
                stack.append(State{ .MultiplyExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .CurlySuffixExpressionBegin = opt_ctx });
                continue;
            },

            State.MultiplyExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToMultiply(token_ptr.id)) |mult_id| {
                    const node = try arena.create(ast.Node.InfixOp{
                        .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                        .lhs = lhs,
                        .op_token = token_index,
                        .op = mult_id,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);
                    stack.append(State{ .MultiplyExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State{ .CurlySuffixExpressionBegin = OptionalCtx{ .Required = &node.rhs } });
                    continue;
                } else {
                    prevToken(&tok_it, &tree);
                    continue;
                }
            },

            State.CurlySuffixExpressionBegin => |opt_ctx| {
                stack.append(State{ .CurlySuffixExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .IfToken = Token.Id.LBrace });
                try stack.append(State{ .TypeExprBegin = opt_ctx });
                continue;
            },

            State.CurlySuffixExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                if (tok_it.peek().?.id == Token.Id.Period) {
                    const node = try arena.create(ast.Node.SuffixOp{
                        .base = ast.Node{ .id = ast.Node.Id.SuffixOp },
                        .lhs = lhs,
                        .op = ast.Node.SuffixOp.Op{ .StructInitializer = ast.Node.SuffixOp.Op.InitList.init(arena) },
                        .rtoken = undefined,
                    });
                    opt_ctx.store(&node.base);

                    stack.append(State{ .CurlySuffixExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State{ .IfToken = Token.Id.LBrace });
                    try stack.append(State{
                        .FieldInitListItemOrEnd = ListSave(@typeOf(node.op.StructInitializer)){
                            .list = &node.op.StructInitializer,
                            .ptr = &node.rtoken,
                        },
                    });
                    continue;
                }

                const node = try arena.create(ast.Node.SuffixOp{
                    .base = ast.Node{ .id = ast.Node.Id.SuffixOp },
                    .lhs = lhs,
                    .op = ast.Node.SuffixOp.Op{ .ArrayInitializer = ast.Node.SuffixOp.Op.InitList.init(arena) },
                    .rtoken = undefined,
                });
                opt_ctx.store(&node.base);
                stack.append(State{ .CurlySuffixExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                try stack.append(State{ .IfToken = Token.Id.LBrace });
                try stack.append(State{
                    .ExprListItemOrEnd = ExprListCtx{
                        .list = &node.op.ArrayInitializer,
                        .end = Token.Id.RBrace,
                        .ptr = &node.rtoken,
                    },
                });
                continue;
            },

            State.TypeExprBegin => |opt_ctx| {
                stack.append(State{ .TypeExprEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .PrefixOpExpression = opt_ctx });
                continue;
            },

            State.TypeExprEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                if (eatToken(&tok_it, &tree, Token.Id.Bang)) |bang| {
                    const node = try arena.create(ast.Node.InfixOp{
                        .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                        .lhs = lhs,
                        .op_token = bang,
                        .op = ast.Node.InfixOp.Op.ErrorUnion,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);
                    stack.append(State{ .TypeExprEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State{ .PrefixOpExpression = OptionalCtx{ .Required = &node.rhs } });
                    continue;
                }
            },

            State.PrefixOpExpression => |opt_ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToPrefixOp(token_ptr.id)) |prefix_id| {
                    var node = try arena.create(ast.Node.PrefixOp{
                        .base = ast.Node{ .id = ast.Node.Id.PrefixOp },
                        .op_token = token_index,
                        .op = prefix_id,
                        .rhs = undefined,
                    });
                    opt_ctx.store(&node.base);

                    // Treat '**' token as two pointer types
                    if (token_ptr.id == Token.Id.AsteriskAsterisk) {
                        const child = try arena.create(ast.Node.PrefixOp{
                            .base = ast.Node{ .id = ast.Node.Id.PrefixOp },
                            .op_token = token_index,
                            .op = prefix_id,
                            .rhs = undefined,
                        });
                        node.rhs = &child.base;
                        node = child;
                    }

                    stack.append(State{ .TypeExprBegin = OptionalCtx{ .Required = &node.rhs } }) catch unreachable;
                    if (node.op == ast.Node.PrefixOp.Op.PtrType) {
                        try stack.append(State{ .PtrTypeModifiers = &node.op.PtrType });
                    }
                    continue;
                } else {
                    prevToken(&tok_it, &tree);
                    stack.append(State{ .SuffixOpExpressionBegin = opt_ctx }) catch unreachable;
                    continue;
                }
            },

            State.SuffixOpExpressionBegin => |opt_ctx| {
                if (eatToken(&tok_it, &tree, Token.Id.Keyword_async)) |async_token| {
                    const async_node = try arena.create(ast.Node.AsyncAttribute{
                        .base = ast.Node{ .id = ast.Node.Id.AsyncAttribute },
                        .async_token = async_token,
                        .allocator_type = null,
                        .rangle_bracket = null,
                    });
                    stack.append(State{
                        .AsyncEnd = AsyncEndCtx{
                            .ctx = opt_ctx,
                            .attribute = async_node,
                        },
                    }) catch unreachable;
                    try stack.append(State{ .SuffixOpExpressionEnd = opt_ctx.toRequired() });
                    try stack.append(State{ .PrimaryExpression = opt_ctx.toRequired() });
                    try stack.append(State{ .AsyncAllocator = async_node });
                    continue;
                }

                stack.append(State{ .SuffixOpExpressionEnd = opt_ctx }) catch unreachable;
                try stack.append(State{ .PrimaryExpression = opt_ctx });
                continue;
            },

            State.SuffixOpExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() orelse continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.LParen => {
                        const node = try arena.create(ast.Node.SuffixOp{
                            .base = ast.Node{ .id = ast.Node.Id.SuffixOp },
                            .lhs = lhs,
                            .op = ast.Node.SuffixOp.Op{
                                .Call = ast.Node.SuffixOp.Op.Call{
                                    .params = ast.Node.SuffixOp.Op.Call.ParamList.init(arena),
                                    .async_attr = null,
                                },
                            },
                            .rtoken = undefined,
                        });
                        opt_ctx.store(&node.base);

                        stack.append(State{ .SuffixOpExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State{
                            .ExprListItemOrEnd = ExprListCtx{
                                .list = &node.op.Call.params,
                                .end = Token.Id.RParen,
                                .ptr = &node.rtoken,
                            },
                        });
                        continue;
                    },
                    Token.Id.LBracket => {
                        const node = try arena.create(ast.Node.SuffixOp{
                            .base = ast.Node{ .id = ast.Node.Id.SuffixOp },
                            .lhs = lhs,
                            .op = ast.Node.SuffixOp.Op{ .ArrayAccess = undefined },
                            .rtoken = undefined,
                        });
                        opt_ctx.store(&node.base);

                        stack.append(State{ .SuffixOpExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State{ .SliceOrArrayAccess = node });
                        try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.op.ArrayAccess } });
                        continue;
                    },
                    Token.Id.Period => {
                        if (eatToken(&tok_it, &tree, Token.Id.Asterisk)) |asterisk_token| {
                            const node = try arena.create(ast.Node.SuffixOp{
                                .base = ast.Node{ .id = ast.Node.Id.SuffixOp },
                                .lhs = lhs,
                                .op = ast.Node.SuffixOp.Op.Deref,
                                .rtoken = asterisk_token,
                            });
                            opt_ctx.store(&node.base);
                            stack.append(State{ .SuffixOpExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                            continue;
                        }
                        if (eatToken(&tok_it, &tree, Token.Id.QuestionMark)) |question_token| {
                            const node = try arena.create(ast.Node.SuffixOp{
                                .base = ast.Node{ .id = ast.Node.Id.SuffixOp },
                                .lhs = lhs,
                                .op = ast.Node.SuffixOp.Op.UnwrapOptional,
                                .rtoken = question_token,
                            });
                            opt_ctx.store(&node.base);
                            stack.append(State{ .SuffixOpExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                            continue;
                        }
                        const node = try arena.create(ast.Node.InfixOp{
                            .base = ast.Node{ .id = ast.Node.Id.InfixOp },
                            .lhs = lhs,
                            .op_token = token_index,
                            .op = ast.Node.InfixOp.Op.Period,
                            .rhs = undefined,
                        });
                        opt_ctx.store(&node.base);

                        stack.append(State{ .SuffixOpExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State{ .Identifier = OptionalCtx{ .Required = &node.rhs } });
                        continue;
                    },
                    else => {
                        prevToken(&tok_it, &tree);
                        continue;
                    },
                }
            },

            State.PrimaryExpression => |opt_ctx| {
                const token = nextToken(&tok_it, &tree);
                switch (token.ptr.id) {
                    Token.Id.IntegerLiteral => {
                        _ = try createToCtxLiteral(arena, opt_ctx, ast.Node.StringLiteral, token.index);
                        continue;
                    },
                    Token.Id.FloatLiteral => {
                        _ = try createToCtxLiteral(arena, opt_ctx, ast.Node.FloatLiteral, token.index);
                        continue;
                    },
                    Token.Id.CharLiteral => {
                        _ = try createToCtxLiteral(arena, opt_ctx, ast.Node.CharLiteral, token.index);
                        continue;
                    },
                    Token.Id.Keyword_undefined => {
                        _ = try createToCtxLiteral(arena, opt_ctx, ast.Node.UndefinedLiteral, token.index);
                        continue;
                    },
                    Token.Id.Keyword_true, Token.Id.Keyword_false => {
                        _ = try createToCtxLiteral(arena, opt_ctx, ast.Node.BoolLiteral, token.index);
                        continue;
                    },
                    Token.Id.Keyword_null => {
                        _ = try createToCtxLiteral(arena, opt_ctx, ast.Node.NullLiteral, token.index);
                        continue;
                    },
                    Token.Id.Keyword_this => {
                        _ = try createToCtxLiteral(arena, opt_ctx, ast.Node.ThisLiteral, token.index);
                        continue;
                    },
                    Token.Id.Keyword_var => {
                        _ = try createToCtxLiteral(arena, opt_ctx, ast.Node.VarType, token.index);
                        continue;
                    },
                    Token.Id.Keyword_unreachable => {
                        _ = try createToCtxLiteral(arena, opt_ctx, ast.Node.Unreachable, token.index);
                        continue;
                    },
                    Token.Id.Keyword_promise => {
                        const node = try arena.create(ast.Node.PromiseType{
                            .base = ast.Node{ .id = ast.Node.Id.PromiseType },
                            .promise_token = token.index,
                            .result = null,
                        });
                        opt_ctx.store(&node.base);
                        const next_token = nextToken(&tok_it, &tree);
                        const next_token_index = next_token.index;
                        const next_token_ptr = next_token.ptr;
                        if (next_token_ptr.id != Token.Id.Arrow) {
                            prevToken(&tok_it, &tree);
                            continue;
                        }
                        node.result = ast.Node.PromiseType.Result{
                            .arrow_token = next_token_index,
                            .return_type = undefined,
                        };
                        const return_type_ptr = &node.result.?.return_type;
                        try stack.append(State{ .Expression = OptionalCtx{ .Required = return_type_ptr } });
                        continue;
                    },
                    Token.Id.StringLiteral, Token.Id.MultilineStringLiteralLine => {
                        opt_ctx.store((try parseStringLiteral(arena, &tok_it, token.ptr, token.index, &tree)) orelse unreachable);
                        continue;
                    },
                    Token.Id.LParen => {
                        const node = try arena.create(ast.Node.GroupedExpression{
                            .base = ast.Node{ .id = ast.Node.Id.GroupedExpression },
                            .lparen = token.index,
                            .expr = undefined,
                            .rparen = undefined,
                        });
                        opt_ctx.store(&node.base);

                        stack.append(State{
                            .ExpectTokenSave = ExpectTokenSave{
                                .id = Token.Id.RParen,
                                .ptr = &node.rparen,
                            },
                        }) catch unreachable;
                        try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.expr } });
                        continue;
                    },
                    Token.Id.Builtin => {
                        const node = try arena.create(ast.Node.BuiltinCall{
                            .base = ast.Node{ .id = ast.Node.Id.BuiltinCall },
                            .builtin_token = token.index,
                            .params = ast.Node.BuiltinCall.ParamList.init(arena),
                            .rparen_token = undefined,
                        });
                        opt_ctx.store(&node.base);

                        stack.append(State{
                            .ExprListItemOrEnd = ExprListCtx{
                                .list = &node.params,
                                .end = Token.Id.RParen,
                                .ptr = &node.rparen_token,
                            },
                        }) catch unreachable;
                        try stack.append(State{ .ExpectToken = Token.Id.LParen });
                        continue;
                    },
                    Token.Id.LBracket => {
                        const node = try arena.create(ast.Node.PrefixOp{
                            .base = ast.Node{ .id = ast.Node.Id.PrefixOp },
                            .op_token = token.index,
                            .op = undefined,
                            .rhs = undefined,
                        });
                        opt_ctx.store(&node.base);

                        stack.append(State{ .SliceOrArrayType = node }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_error => {
                        stack.append(State{
                            .ErrorTypeOrSetDecl = ErrorTypeOrSetDeclCtx{
                                .error_token = token.index,
                                .opt_ctx = opt_ctx,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_packed => {
                        stack.append(State{
                            .ContainerKind = ContainerKindCtx{
                                .opt_ctx = opt_ctx,
                                .layout_token = token.index,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_extern => {
                        stack.append(State{
                            .ExternType = ExternTypeCtx{
                                .opt_ctx = opt_ctx,
                                .extern_token = token.index,
                                .comments = null,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_struct, Token.Id.Keyword_union, Token.Id.Keyword_enum => {
                        prevToken(&tok_it, &tree);
                        stack.append(State{
                            .ContainerKind = ContainerKindCtx{
                                .opt_ctx = opt_ctx,
                                .layout_token = null,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Identifier => {
                        stack.append(State{
                            .MaybeLabeledExpression = MaybeLabeledExpressionCtx{
                                .label = token.index,
                                .opt_ctx = opt_ctx,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_fn => {
                        const fn_proto = try arena.create(ast.Node.FnProto{
                            .base = ast.Node{ .id = ast.Node.Id.FnProto },
                            .doc_comments = null,
                            .visib_token = null,
                            .name_token = null,
                            .fn_token = token.index,
                            .params = ast.Node.FnProto.ParamList.init(arena),
                            .return_type = undefined,
                            .var_args_token = null,
                            .extern_export_inline_token = null,
                            .cc_token = null,
                            .async_attr = null,
                            .body_node = null,
                            .lib_name = null,
                            .align_expr = null,
                        });
                        opt_ctx.store(&fn_proto.base);
                        stack.append(State{ .FnProto = fn_proto }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_nakedcc, Token.Id.Keyword_stdcallcc => {
                        const fn_proto = try arena.create(ast.Node.FnProto{
                            .base = ast.Node{ .id = ast.Node.Id.FnProto },
                            .doc_comments = null,
                            .visib_token = null,
                            .name_token = null,
                            .fn_token = undefined,
                            .params = ast.Node.FnProto.ParamList.init(arena),
                            .return_type = undefined,
                            .var_args_token = null,
                            .extern_export_inline_token = null,
                            .cc_token = token.index,
                            .async_attr = null,
                            .body_node = null,
                            .lib_name = null,
                            .align_expr = null,
                        });
                        opt_ctx.store(&fn_proto.base);
                        stack.append(State{ .FnProto = fn_proto }) catch unreachable;
                        try stack.append(State{
                            .ExpectTokenSave = ExpectTokenSave{
                                .id = Token.Id.Keyword_fn,
                                .ptr = &fn_proto.fn_token,
                            },
                        });
                        continue;
                    },
                    Token.Id.Keyword_asm => {
                        const node = try arena.create(ast.Node.Asm{
                            .base = ast.Node{ .id = ast.Node.Id.Asm },
                            .asm_token = token.index,
                            .volatile_token = null,
                            .template = undefined,
                            .outputs = ast.Node.Asm.OutputList.init(arena),
                            .inputs = ast.Node.Asm.InputList.init(arena),
                            .clobbers = ast.Node.Asm.ClobberList.init(arena),
                            .rparen = undefined,
                        });
                        opt_ctx.store(&node.base);

                        stack.append(State{
                            .ExpectTokenSave = ExpectTokenSave{
                                .id = Token.Id.RParen,
                                .ptr = &node.rparen,
                            },
                        }) catch unreachable;
                        try stack.append(State{ .AsmClobberItems = &node.clobbers });
                        try stack.append(State{ .IfToken = Token.Id.Colon });
                        try stack.append(State{ .AsmInputItems = &node.inputs });
                        try stack.append(State{ .IfToken = Token.Id.Colon });
                        try stack.append(State{ .AsmOutputItems = &node.outputs });
                        try stack.append(State{ .IfToken = Token.Id.Colon });
                        try stack.append(State{ .StringLiteral = OptionalCtx{ .Required = &node.template } });
                        try stack.append(State{ .ExpectToken = Token.Id.LParen });
                        try stack.append(State{
                            .OptionalTokenSave = OptionalTokenSave{
                                .id = Token.Id.Keyword_volatile,
                                .ptr = &node.volatile_token,
                            },
                        });
                    },
                    Token.Id.Keyword_inline => {
                        stack.append(State{
                            .Inline = InlineCtx{
                                .label = null,
                                .inline_token = token.index,
                                .opt_ctx = opt_ctx,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    else => {
                        if (!try parseBlockExpr(&stack, arena, opt_ctx, token.ptr, token.index)) {
                            prevToken(&tok_it, &tree);
                            if (opt_ctx != OptionalCtx.Optional) {
                                ((try tree.errors.addOne())).* = Error{ .ExpectedPrimaryExpr = Error.ExpectedPrimaryExpr{ .token = token.index } };
                                return tree;
                            }
                        }
                        continue;
                    },
                }
            },

            State.ErrorTypeOrSetDecl => |ctx| {
                if (eatToken(&tok_it, &tree, Token.Id.LBrace) == null) {
                    _ = try createToCtxLiteral(arena, ctx.opt_ctx, ast.Node.ErrorType, ctx.error_token);
                    continue;
                }

                const node = try arena.create(ast.Node.ErrorSetDecl{
                    .base = ast.Node{ .id = ast.Node.Id.ErrorSetDecl },
                    .error_token = ctx.error_token,
                    .decls = ast.Node.ErrorSetDecl.DeclList.init(arena),
                    .rbrace_token = undefined,
                });
                ctx.opt_ctx.store(&node.base);

                stack.append(State{
                    .ErrorTagListItemOrEnd = ListSave(@typeOf(node.decls)){
                        .list = &node.decls,
                        .ptr = &node.rbrace_token,
                    },
                }) catch unreachable;
                continue;
            },
            State.StringLiteral => |opt_ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                opt_ctx.store((try parseStringLiteral(arena, &tok_it, token_ptr, token_index, &tree)) orelse {
                    prevToken(&tok_it, &tree);
                    if (opt_ctx != OptionalCtx.Optional) {
                        ((try tree.errors.addOne())).* = Error{ .ExpectedPrimaryExpr = Error.ExpectedPrimaryExpr{ .token = token_index } };
                        return tree;
                    }

                    continue;
                });
            },

            State.Identifier => |opt_ctx| {
                if (eatToken(&tok_it, &tree, Token.Id.Identifier)) |ident_token| {
                    _ = try createToCtxLiteral(arena, opt_ctx, ast.Node.Identifier, ident_token);
                    continue;
                }

                if (opt_ctx != OptionalCtx.Optional) {
                    const token = nextToken(&tok_it, &tree);
                    const token_index = token.index;
                    const token_ptr = token.ptr;
                    ((try tree.errors.addOne())).* = Error{
                        .ExpectedToken = Error.ExpectedToken{
                            .token = token_index,
                            .expected_id = Token.Id.Identifier,
                        },
                    };
                    return tree;
                }
            },

            State.ErrorTag => |node_ptr| {
                const comments = try eatDocComments(arena, &tok_it, &tree);
                const ident_token = nextToken(&tok_it, &tree);
                const ident_token_index = ident_token.index;
                const ident_token_ptr = ident_token.ptr;
                if (ident_token_ptr.id != Token.Id.Identifier) {
                    ((try tree.errors.addOne())).* = Error{
                        .ExpectedToken = Error.ExpectedToken{
                            .token = ident_token_index,
                            .expected_id = Token.Id.Identifier,
                        },
                    };
                    return tree;
                }

                const node = try arena.create(ast.Node.ErrorTag{
                    .base = ast.Node{ .id = ast.Node.Id.ErrorTag },
                    .doc_comments = comments,
                    .name_token = ident_token_index,
                });
                node_ptr.* = &node.base;
                continue;
            },

            State.ExpectToken => |token_id| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (token_ptr.id != token_id) {
                    ((try tree.errors.addOne())).* = Error{
                        .ExpectedToken = Error.ExpectedToken{
                            .token = token_index,
                            .expected_id = token_id,
                        },
                    };
                    return tree;
                }
                continue;
            },
            State.ExpectTokenSave => |expect_token_save| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (token_ptr.id != expect_token_save.id) {
                    ((try tree.errors.addOne())).* = Error{
                        .ExpectedToken = Error.ExpectedToken{
                            .token = token_index,
                            .expected_id = expect_token_save.id,
                        },
                    };
                    return tree;
                }
                expect_token_save.ptr.* = token_index;
                continue;
            },
            State.IfToken => |token_id| {
                if (eatToken(&tok_it, &tree, token_id)) |_| {
                    continue;
                }

                _ = stack.pop();
                continue;
            },
            State.IfTokenSave => |if_token_save| {
                if (eatToken(&tok_it, &tree, if_token_save.id)) |token_index| {
                    (if_token_save.ptr).* = token_index;
                    continue;
                }

                _ = stack.pop();
                continue;
            },
            State.OptionalTokenSave => |optional_token_save| {
                if (eatToken(&tok_it, &tree, optional_token_save.id)) |token_index| {
                    (optional_token_save.ptr).* = token_index;
                    continue;
                }

                continue;
            },
        }
    }
}

const AnnotatedToken = struct {
    ptr: *Token,
    index: TokenIndex,
};

const TopLevelDeclCtx = struct {
    decls: *ast.Node.Root.DeclList,
    visib_token: ?TokenIndex,
    extern_export_inline_token: ?AnnotatedToken,
    lib_name: ?*ast.Node,
    comments: ?*ast.Node.DocComment,
};

const VarDeclCtx = struct {
    mut_token: TokenIndex,
    visib_token: ?TokenIndex,
    comptime_token: ?TokenIndex,
    extern_export_token: ?TokenIndex,
    lib_name: ?*ast.Node,
    list: *ast.Node.Root.DeclList,
    comments: ?*ast.Node.DocComment,
};

const TopLevelExternOrFieldCtx = struct {
    visib_token: TokenIndex,
    container_decl: *ast.Node.ContainerDecl,
    comments: ?*ast.Node.DocComment,
};

const ExternTypeCtx = struct {
    opt_ctx: OptionalCtx,
    extern_token: TokenIndex,
    comments: ?*ast.Node.DocComment,
};

const ContainerKindCtx = struct {
    opt_ctx: OptionalCtx,
    layout_token: ?TokenIndex,
};

const ExpectTokenSave = struct {
    id: @TagType(Token.Id),
    ptr: *TokenIndex,
};

const OptionalTokenSave = struct {
    id: @TagType(Token.Id),
    ptr: *?TokenIndex,
};

const ExprListCtx = struct {
    list: *ast.Node.SuffixOp.Op.InitList,
    end: Token.Id,
    ptr: *TokenIndex,
};

fn ListSave(comptime List: type) type {
    return struct {
        list: *List,
        ptr: *TokenIndex,
    };
}

const MaybeLabeledExpressionCtx = struct {
    label: TokenIndex,
    opt_ctx: OptionalCtx,
};

const LabelCtx = struct {
    label: ?TokenIndex,
    opt_ctx: OptionalCtx,
};

const InlineCtx = struct {
    label: ?TokenIndex,
    inline_token: ?TokenIndex,
    opt_ctx: OptionalCtx,
};

const LoopCtx = struct {
    label: ?TokenIndex,
    inline_token: ?TokenIndex,
    loop_token: TokenIndex,
    opt_ctx: OptionalCtx,
};

const AsyncEndCtx = struct {
    ctx: OptionalCtx,
    attribute: *ast.Node.AsyncAttribute,
};

const ErrorTypeOrSetDeclCtx = struct {
    opt_ctx: OptionalCtx,
    error_token: TokenIndex,
};

const ParamDeclEndCtx = struct {
    fn_proto: *ast.Node.FnProto,
    param_decl: *ast.Node.ParamDecl,
};

const ComptimeStatementCtx = struct {
    comptime_token: TokenIndex,
    block: *ast.Node.Block,
};

const OptionalCtx = union(enum) {
    Optional: *?*ast.Node,
    RequiredNull: *?*ast.Node,
    Required: **ast.Node,

    pub fn store(self: *const OptionalCtx, value: *ast.Node) void {
        switch (self.*) {
            OptionalCtx.Optional => |ptr| ptr.* = value,
            OptionalCtx.RequiredNull => |ptr| ptr.* = value,
            OptionalCtx.Required => |ptr| ptr.* = value,
        }
    }

    pub fn get(self: *const OptionalCtx) ?*ast.Node {
        switch (self.*) {
            OptionalCtx.Optional => |ptr| return ptr.*,
            OptionalCtx.RequiredNull => |ptr| return ptr.*.?,
            OptionalCtx.Required => |ptr| return ptr.*,
        }
    }

    pub fn toRequired(self: *const OptionalCtx) OptionalCtx {
        switch (self.*) {
            OptionalCtx.Optional => |ptr| {
                return OptionalCtx{ .RequiredNull = ptr };
            },
            OptionalCtx.RequiredNull => |ptr| return self.*,
            OptionalCtx.Required => |ptr| return self.*,
        }
    }
};

const AddCommentsCtx = struct {
    node_ptr: **ast.Node,
    comments: ?*ast.Node.DocComment,
};

const State = union(enum) {
    TopLevel,
    TopLevelExtern: TopLevelDeclCtx,
    TopLevelLibname: TopLevelDeclCtx,
    TopLevelDecl: TopLevelDeclCtx,
    TopLevelExternOrField: TopLevelExternOrFieldCtx,

    ContainerKind: ContainerKindCtx,
    ContainerInitArgStart: *ast.Node.ContainerDecl,
    ContainerInitArg: *ast.Node.ContainerDecl,
    ContainerDecl: *ast.Node.ContainerDecl,

    VarDecl: VarDeclCtx,
    VarDeclAlign: *ast.Node.VarDecl,
    VarDeclEq: *ast.Node.VarDecl,
    VarDeclSemiColon: *ast.Node.VarDecl,

    FnDef: *ast.Node.FnProto,
    FnProto: *ast.Node.FnProto,
    FnProtoAlign: *ast.Node.FnProto,
    FnProtoReturnType: *ast.Node.FnProto,

    ParamDecl: *ast.Node.FnProto,
    ParamDeclAliasOrComptime: *ast.Node.ParamDecl,
    ParamDeclName: *ast.Node.ParamDecl,
    ParamDeclEnd: ParamDeclEndCtx,
    ParamDeclComma: *ast.Node.FnProto,

    MaybeLabeledExpression: MaybeLabeledExpressionCtx,
    LabeledExpression: LabelCtx,
    Inline: InlineCtx,
    While: LoopCtx,
    WhileContinueExpr: *?*ast.Node,
    For: LoopCtx,
    Else: *?*ast.Node.Else,

    Block: *ast.Node.Block,
    Statement: *ast.Node.Block,
    ComptimeStatement: ComptimeStatementCtx,
    Semicolon: **ast.Node,

    AsmOutputItems: *ast.Node.Asm.OutputList,
    AsmOutputReturnOrType: *ast.Node.AsmOutput,
    AsmInputItems: *ast.Node.Asm.InputList,
    AsmClobberItems: *ast.Node.Asm.ClobberList,

    ExprListItemOrEnd: ExprListCtx,
    ExprListCommaOrEnd: ExprListCtx,
    FieldInitListItemOrEnd: ListSave(ast.Node.SuffixOp.Op.InitList),
    FieldInitListCommaOrEnd: ListSave(ast.Node.SuffixOp.Op.InitList),
    FieldListCommaOrEnd: *ast.Node.ContainerDecl,
    FieldInitValue: OptionalCtx,
    ErrorTagListItemOrEnd: ListSave(ast.Node.ErrorSetDecl.DeclList),
    ErrorTagListCommaOrEnd: ListSave(ast.Node.ErrorSetDecl.DeclList),
    SwitchCaseOrEnd: ListSave(ast.Node.Switch.CaseList),
    SwitchCaseCommaOrEnd: ListSave(ast.Node.Switch.CaseList),
    SwitchCaseFirstItem: *ast.Node.SwitchCase,
    SwitchCaseItemCommaOrEnd: *ast.Node.SwitchCase,
    SwitchCaseItemOrEnd: *ast.Node.SwitchCase,

    SuspendBody: *ast.Node.Suspend,
    AsyncAllocator: *ast.Node.AsyncAttribute,
    AsyncEnd: AsyncEndCtx,

    ExternType: ExternTypeCtx,
    SliceOrArrayAccess: *ast.Node.SuffixOp,
    SliceOrArrayType: *ast.Node.PrefixOp,
    PtrTypeModifiers: *ast.Node.PrefixOp.PtrInfo,
    AlignBitRange: *ast.Node.PrefixOp.PtrInfo.Align,

    Payload: OptionalCtx,
    PointerPayload: OptionalCtx,
    PointerIndexPayload: OptionalCtx,

    Expression: OptionalCtx,
    RangeExpressionBegin: OptionalCtx,
    RangeExpressionEnd: OptionalCtx,
    AssignmentExpressionBegin: OptionalCtx,
    AssignmentExpressionEnd: OptionalCtx,
    UnwrapExpressionBegin: OptionalCtx,
    UnwrapExpressionEnd: OptionalCtx,
    BoolOrExpressionBegin: OptionalCtx,
    BoolOrExpressionEnd: OptionalCtx,
    BoolAndExpressionBegin: OptionalCtx,
    BoolAndExpressionEnd: OptionalCtx,
    ComparisonExpressionBegin: OptionalCtx,
    ComparisonExpressionEnd: OptionalCtx,
    BinaryOrExpressionBegin: OptionalCtx,
    BinaryOrExpressionEnd: OptionalCtx,
    BinaryXorExpressionBegin: OptionalCtx,
    BinaryXorExpressionEnd: OptionalCtx,
    BinaryAndExpressionBegin: OptionalCtx,
    BinaryAndExpressionEnd: OptionalCtx,
    BitShiftExpressionBegin: OptionalCtx,
    BitShiftExpressionEnd: OptionalCtx,
    AdditionExpressionBegin: OptionalCtx,
    AdditionExpressionEnd: OptionalCtx,
    MultiplyExpressionBegin: OptionalCtx,
    MultiplyExpressionEnd: OptionalCtx,
    CurlySuffixExpressionBegin: OptionalCtx,
    CurlySuffixExpressionEnd: OptionalCtx,
    TypeExprBegin: OptionalCtx,
    TypeExprEnd: OptionalCtx,
    PrefixOpExpression: OptionalCtx,
    SuffixOpExpressionBegin: OptionalCtx,
    SuffixOpExpressionEnd: OptionalCtx,
    PrimaryExpression: OptionalCtx,

    ErrorTypeOrSetDecl: ErrorTypeOrSetDeclCtx,
    StringLiteral: OptionalCtx,
    Identifier: OptionalCtx,
    ErrorTag: **ast.Node,

    IfToken: @TagType(Token.Id),
    IfTokenSave: ExpectTokenSave,
    ExpectToken: @TagType(Token.Id),
    ExpectTokenSave: ExpectTokenSave,
    OptionalTokenSave: OptionalTokenSave,
};

fn pushDocComment(arena: *mem.Allocator, line_comment: TokenIndex, result: *?*ast.Node.DocComment) !void {
    const node = blk: {
        if (result.*) |comment_node| {
            break :blk comment_node;
        } else {
            const comment_node = try arena.create(ast.Node.DocComment{
                .base = ast.Node{ .id = ast.Node.Id.DocComment },
                .lines = ast.Node.DocComment.LineList.init(arena),
            });
            result.* = comment_node;
            break :blk comment_node;
        }
    };
    try node.lines.push(line_comment);
}

fn eatDocComments(arena: *mem.Allocator, tok_it: *ast.Tree.TokenList.Iterator, tree: *ast.Tree) !?*ast.Node.DocComment {
    var result: ?*ast.Node.DocComment = null;
    while (true) {
        if (eatToken(tok_it, tree, Token.Id.DocComment)) |line_comment| {
            try pushDocComment(arena, line_comment, &result);
            continue;
        }
        break;
    }
    return result;
}

fn parseStringLiteral(arena: *mem.Allocator, tok_it: *ast.Tree.TokenList.Iterator, token_ptr: *const Token, token_index: TokenIndex, tree: *ast.Tree) !?*ast.Node {
    switch (token_ptr.id) {
        Token.Id.StringLiteral => {
            return &(try createLiteral(arena, ast.Node.StringLiteral, token_index)).base;
        },
        Token.Id.MultilineStringLiteralLine => {
            const node = try arena.create(ast.Node.MultilineStringLiteral{
                .base = ast.Node{ .id = ast.Node.Id.MultilineStringLiteral },
                .lines = ast.Node.MultilineStringLiteral.LineList.init(arena),
            });
            try node.lines.push(token_index);
            while (true) {
                const multiline_str = nextToken(tok_it, tree);
                const multiline_str_index = multiline_str.index;
                const multiline_str_ptr = multiline_str.ptr;
                if (multiline_str_ptr.id != Token.Id.MultilineStringLiteralLine) {
                    prevToken(tok_it, tree);
                    break;
                }

                try node.lines.push(multiline_str_index);
            }

            return &node.base;
        },
        // TODO: We shouldn't need a cast, but:
        // zig: /home/jc/Documents/zig/src/ir.cpp:7962: TypeTableEntry* ir_resolve_peer_types(IrAnalyze*, AstNode*, IrInstruction**, size_t): Assertion `err_set_type != nullptr' failed.
        else => return (?*ast.Node)(null),
    }
}

fn parseBlockExpr(stack: *std.ArrayList(State), arena: *mem.Allocator, ctx: *const OptionalCtx, token_ptr: *const Token, token_index: TokenIndex) !bool {
    switch (token_ptr.id) {
        Token.Id.Keyword_suspend => {
            const node = try arena.create(ast.Node.Suspend{
                .base = ast.Node{ .id = ast.Node.Id.Suspend },
                .label = null,
                .suspend_token = token_index,
                .payload = null,
                .body = null,
            });
            ctx.store(&node.base);

            stack.append(State{ .SuspendBody = node }) catch unreachable;
            try stack.append(State{ .Payload = OptionalCtx{ .Optional = &node.payload } });
            return true;
        },
        Token.Id.Keyword_if => {
            const node = try arena.create(ast.Node.If{
                .base = ast.Node{ .id = ast.Node.Id.If },
                .if_token = token_index,
                .condition = undefined,
                .payload = null,
                .body = undefined,
                .@"else" = null,
            });
            ctx.store(&node.base);

            stack.append(State{ .Else = &node.@"else" }) catch unreachable;
            try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.body } });
            try stack.append(State{ .PointerPayload = OptionalCtx{ .Optional = &node.payload } });
            try stack.append(State{ .ExpectToken = Token.Id.RParen });
            try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.condition } });
            try stack.append(State{ .ExpectToken = Token.Id.LParen });
            return true;
        },
        Token.Id.Keyword_while => {
            stack.append(State{
                .While = LoopCtx{
                    .label = null,
                    .inline_token = null,
                    .loop_token = token_index,
                    .opt_ctx = ctx.*,
                },
            }) catch unreachable;
            return true;
        },
        Token.Id.Keyword_for => {
            stack.append(State{
                .For = LoopCtx{
                    .label = null,
                    .inline_token = null,
                    .loop_token = token_index,
                    .opt_ctx = ctx.*,
                },
            }) catch unreachable;
            return true;
        },
        Token.Id.Keyword_switch => {
            const node = try arena.create(ast.Node.Switch{
                .base = ast.Node{ .id = ast.Node.Id.Switch },
                .switch_token = token_index,
                .expr = undefined,
                .cases = ast.Node.Switch.CaseList.init(arena),
                .rbrace = undefined,
            });
            ctx.store(&node.base);

            stack.append(State{
                .SwitchCaseOrEnd = ListSave(@typeOf(node.cases)){
                    .list = &node.cases,
                    .ptr = &node.rbrace,
                },
            }) catch unreachable;
            try stack.append(State{ .ExpectToken = Token.Id.LBrace });
            try stack.append(State{ .ExpectToken = Token.Id.RParen });
            try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.expr } });
            try stack.append(State{ .ExpectToken = Token.Id.LParen });
            return true;
        },
        Token.Id.Keyword_comptime => {
            const node = try arena.create(ast.Node.Comptime{
                .base = ast.Node{ .id = ast.Node.Id.Comptime },
                .comptime_token = token_index,
                .expr = undefined,
                .doc_comments = null,
            });
            ctx.store(&node.base);

            try stack.append(State{ .Expression = OptionalCtx{ .Required = &node.expr } });
            return true;
        },
        Token.Id.LBrace => {
            const block = try arena.create(ast.Node.Block{
                .base = ast.Node{ .id = ast.Node.Id.Block },
                .label = null,
                .lbrace = token_index,
                .statements = ast.Node.Block.StatementList.init(arena),
                .rbrace = undefined,
            });
            ctx.store(&block.base);
            stack.append(State{ .Block = block }) catch unreachable;
            return true;
        },
        else => {
            return false;
        },
    }
}

const ExpectCommaOrEndResult = union(enum) {
    end_token: ?TokenIndex,
    parse_error: Error,
};

fn expectCommaOrEnd(tok_it: *ast.Tree.TokenList.Iterator, tree: *ast.Tree, end: @TagType(Token.Id)) ExpectCommaOrEndResult {
    const token = nextToken(tok_it, tree);
    const token_index = token.index;
    const token_ptr = token.ptr;
    switch (token_ptr.id) {
        Token.Id.Comma => return ExpectCommaOrEndResult{ .end_token = null },
        else => {
            if (end == token_ptr.id) {
                return ExpectCommaOrEndResult{ .end_token = token_index };
            }

            return ExpectCommaOrEndResult{
                .parse_error = Error{
                    .ExpectedCommaOrEnd = Error.ExpectedCommaOrEnd{
                        .token = token_index,
                        .end_id = end,
                    },
                },
            };
        },
    }
}

fn tokenIdToAssignment(id: *const Token.Id) ?ast.Node.InfixOp.Op {
    // TODO: We have to cast all cases because of this:
    // error: expected type '?InfixOp', found '?@TagType(InfixOp)'
    return switch (id.*) {
        Token.Id.AmpersandEqual => ast.Node.InfixOp.Op{ .AssignBitAnd = {} },
        Token.Id.AngleBracketAngleBracketLeftEqual => ast.Node.InfixOp.Op{ .AssignBitShiftLeft = {} },
        Token.Id.AngleBracketAngleBracketRightEqual => ast.Node.InfixOp.Op{ .AssignBitShiftRight = {} },
        Token.Id.AsteriskEqual => ast.Node.InfixOp.Op{ .AssignTimes = {} },
        Token.Id.AsteriskPercentEqual => ast.Node.InfixOp.Op{ .AssignTimesWarp = {} },
        Token.Id.CaretEqual => ast.Node.InfixOp.Op{ .AssignBitXor = {} },
        Token.Id.Equal => ast.Node.InfixOp.Op{ .Assign = {} },
        Token.Id.MinusEqual => ast.Node.InfixOp.Op{ .AssignMinus = {} },
        Token.Id.MinusPercentEqual => ast.Node.InfixOp.Op{ .AssignMinusWrap = {} },
        Token.Id.PercentEqual => ast.Node.InfixOp.Op{ .AssignMod = {} },
        Token.Id.PipeEqual => ast.Node.InfixOp.Op{ .AssignBitOr = {} },
        Token.Id.PlusEqual => ast.Node.InfixOp.Op{ .AssignPlus = {} },
        Token.Id.PlusPercentEqual => ast.Node.InfixOp.Op{ .AssignPlusWrap = {} },
        Token.Id.SlashEqual => ast.Node.InfixOp.Op{ .AssignDiv = {} },
        else => null,
    };
}

fn tokenIdToUnwrapExpr(id: @TagType(Token.Id)) ?ast.Node.InfixOp.Op {
    return switch (id) {
        Token.Id.Keyword_catch => ast.Node.InfixOp.Op{ .Catch = null },
        Token.Id.Keyword_orelse => ast.Node.InfixOp.Op{ .UnwrapOptional = void{} },
        else => null,
    };
}

fn tokenIdToComparison(id: @TagType(Token.Id)) ?ast.Node.InfixOp.Op {
    return switch (id) {
        Token.Id.BangEqual => ast.Node.InfixOp.Op{ .BangEqual = void{} },
        Token.Id.EqualEqual => ast.Node.InfixOp.Op{ .EqualEqual = void{} },
        Token.Id.AngleBracketLeft => ast.Node.InfixOp.Op{ .LessThan = void{} },
        Token.Id.AngleBracketLeftEqual => ast.Node.InfixOp.Op{ .LessOrEqual = void{} },
        Token.Id.AngleBracketRight => ast.Node.InfixOp.Op{ .GreaterThan = void{} },
        Token.Id.AngleBracketRightEqual => ast.Node.InfixOp.Op{ .GreaterOrEqual = void{} },
        else => null,
    };
}

fn tokenIdToBitShift(id: @TagType(Token.Id)) ?ast.Node.InfixOp.Op {
    return switch (id) {
        Token.Id.AngleBracketAngleBracketLeft => ast.Node.InfixOp.Op{ .BitShiftLeft = void{} },
        Token.Id.AngleBracketAngleBracketRight => ast.Node.InfixOp.Op{ .BitShiftRight = void{} },
        else => null,
    };
}

fn tokenIdToAddition(id: @TagType(Token.Id)) ?ast.Node.InfixOp.Op {
    return switch (id) {
        Token.Id.Minus => ast.Node.InfixOp.Op{ .Sub = void{} },
        Token.Id.MinusPercent => ast.Node.InfixOp.Op{ .SubWrap = void{} },
        Token.Id.Plus => ast.Node.InfixOp.Op{ .Add = void{} },
        Token.Id.PlusPercent => ast.Node.InfixOp.Op{ .AddWrap = void{} },
        Token.Id.PlusPlus => ast.Node.InfixOp.Op{ .ArrayCat = void{} },
        else => null,
    };
}

fn tokenIdToMultiply(id: @TagType(Token.Id)) ?ast.Node.InfixOp.Op {
    return switch (id) {
        Token.Id.Slash => ast.Node.InfixOp.Op{ .Div = void{} },
        Token.Id.Asterisk => ast.Node.InfixOp.Op{ .Mult = void{} },
        Token.Id.AsteriskAsterisk => ast.Node.InfixOp.Op{ .ArrayMult = void{} },
        Token.Id.AsteriskPercent => ast.Node.InfixOp.Op{ .MultWrap = void{} },
        Token.Id.Percent => ast.Node.InfixOp.Op{ .Mod = void{} },
        Token.Id.PipePipe => ast.Node.InfixOp.Op{ .MergeErrorSets = void{} },
        else => null,
    };
}

fn tokenIdToPrefixOp(id: @TagType(Token.Id)) ?ast.Node.PrefixOp.Op {
    return switch (id) {
        Token.Id.Bang => ast.Node.PrefixOp.Op{ .BoolNot = void{} },
        Token.Id.Tilde => ast.Node.PrefixOp.Op{ .BitNot = void{} },
        Token.Id.Minus => ast.Node.PrefixOp.Op{ .Negation = void{} },
        Token.Id.MinusPercent => ast.Node.PrefixOp.Op{ .NegationWrap = void{} },
        Token.Id.Ampersand => ast.Node.PrefixOp.Op{ .AddressOf = void{} },
        Token.Id.Asterisk, Token.Id.AsteriskAsterisk, Token.Id.BracketStarBracket => ast.Node.PrefixOp.Op{
            .PtrType = ast.Node.PrefixOp.PtrInfo{
                .align_info = null,
                .const_token = null,
                .volatile_token = null,
            },
        },
        Token.Id.QuestionMark => ast.Node.PrefixOp.Op{ .OptionalType = void{} },
        Token.Id.Keyword_await => ast.Node.PrefixOp.Op{ .Await = void{} },
        Token.Id.Keyword_try => ast.Node.PrefixOp.Op{ .Try = void{} },
        else => null,
    };
}

fn createLiteral(arena: *mem.Allocator, comptime T: type, token_index: TokenIndex) !*T {
    return arena.create(T{
        .base = ast.Node{ .id = ast.Node.typeToId(T) },
        .token = token_index,
    });
}

fn createToCtxLiteral(arena: *mem.Allocator, opt_ctx: *const OptionalCtx, comptime T: type, token_index: TokenIndex) !*T {
    const node = try createLiteral(arena, T, token_index);
    opt_ctx.store(&node.base);

    return node;
}

fn eatToken(tok_it: *ast.Tree.TokenList.Iterator, tree: *ast.Tree, id: @TagType(Token.Id)) ?TokenIndex {
    const token = tok_it.peek().?;

    if (token.id == id) {
        return nextToken(tok_it, tree).index;
    }

    return null;
}

fn nextToken(tok_it: *ast.Tree.TokenList.Iterator, tree: *ast.Tree) AnnotatedToken {
    const result = AnnotatedToken{
        .index = tok_it.index,
        .ptr = tok_it.next().?,
    };
    assert(result.ptr.id != Token.Id.LineComment);

    while (true) {
        const next_tok = tok_it.peek() orelse return result;
        if (next_tok.id != Token.Id.LineComment) return result;
        _ = tok_it.next();
    }
}

fn prevToken(tok_it: *ast.Tree.TokenList.Iterator, tree: *ast.Tree) void {
    while (true) {
        const prev_tok = tok_it.prev() orelse return;
        if (prev_tok.id == Token.Id.LineComment) continue;
        return;
    }
}

test "std.zig.parser" {
    _ = @import("parser_test.zig");
}
