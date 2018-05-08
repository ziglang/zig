const std = @import("../index.zig");
const assert = std.debug.assert;
const SegmentedList = std.SegmentedList;
const mem = std.mem;
const ast = std.zig.ast;
const Tokenizer = std.zig.Tokenizer;
const Token = std.zig.Token;
const TokenIndex = ast.TokenIndex;
const Error = ast.Error;

/// Returns an AST tree, allocated with the parser's allocator.
/// Result should be freed with tree.deinit() when there are
/// no more references to any AST nodes of the tree.
pub fn parse(allocator: &mem.Allocator, source: []const u8) !ast.Tree {
    var tree_arena = std.heap.ArenaAllocator.init(allocator);
    errdefer tree_arena.deinit();

    var stack = SegmentedList(State, 32).init(allocator);
    defer stack.deinit();

    const arena = &tree_arena.allocator;
    const root_node = try createNode(arena, ast.Node.Root,
        ast.Node.Root {
            .base = undefined,
            .decls = ast.Node.Root.DeclList.init(arena),
            .doc_comments = null,
            // initialized when we get the eof token
            .eof_token = undefined,
        }
    );

    var tree = ast.Tree {
        .source = source,
        .root_node = root_node,
        .arena_allocator = tree_arena,
        .tokens = ast.Tree.TokenList.init(arena),
        .errors = ast.Tree.ErrorList.init(arena),
    };

    var tokenizer = Tokenizer.init(tree.source);
    while (true) {
        const token_ptr = try tree.tokens.addOne();
        *token_ptr = tokenizer.next();
        if (token_ptr.id == Token.Id.Eof)
            break;
    }
    var tok_it = tree.tokens.iterator(0);

    try stack.push(State.TopLevel);

    while (true) {
        // This gives us 1 free push that can't fail
        const state = ??stack.pop();

        switch (state) {
            State.TopLevel => {
                while (try eatLineComment(arena, &tok_it, &tree)) |line_comment| {
                    try root_node.decls.push(&line_comment.base);
                }

                const comments = try eatDocComments(arena, &tok_it, &tree);

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Keyword_test => {
                        stack.push(State.TopLevel) catch unreachable;

                        const block = try arena.construct(ast.Node.Block {
                            .base = ast.Node {
                                .id = ast.Node.Id.Block,
                            },
                            .label = null,
                            .lbrace = undefined,
                            .statements = ast.Node.Block.StatementList.init(arena),
                            .rbrace = undefined,
                        });
                        const test_node = try arena.construct(ast.Node.TestDecl {
                            .base = ast.Node {
                                .id = ast.Node.Id.TestDecl,
                            },
                            .doc_comments = comments,
                            .test_token = token_index,
                            .name = undefined,
                            .body_node = &block.base,
                        });
                        try root_node.decls.push(&test_node.base);
                        try stack.push(State { .Block = block });
                        try stack.push(State {
                            .ExpectTokenSave = ExpectTokenSave {
                                .id = Token.Id.LBrace,
                                .ptr = &block.rbrace,
                            }
                        });
                        try stack.push(State { .StringLiteral = OptionalCtx { .Required = &test_node.name } });
                        continue;
                    },
                    Token.Id.Eof => {
                        root_node.eof_token = token_index;
                        root_node.doc_comments = comments;
                        return tree;
                    },
                    Token.Id.Keyword_pub => {
                        stack.push(State.TopLevel) catch unreachable;
                        try stack.push(State {
                            .TopLevelExtern = TopLevelDeclCtx {
                                .decls = &root_node.decls,
                                .visib_token = token_index,
                                .extern_export_inline_token = null,
                                .lib_name = null,
                                .comments = comments,
                            }
                        });
                        continue;
                    },
                    Token.Id.Keyword_comptime => {
                        const block = try createNode(arena, ast.Node.Block,
                            ast.Node.Block {
                                .base = undefined,
                                .label = null,
                                .lbrace = undefined,
                                .statements = ast.Node.Block.StatementList.init(arena),
                                .rbrace = undefined,
                            }
                        );
                        const node = try arena.construct(ast.Node.Comptime {
                            .base = ast.Node {
                                .id = ast.Node.Id.Comptime,
                            },
                            .comptime_token = token_index,
                            .expr = &block.base,
                            .doc_comments = comments,
                        });
                        try root_node.decls.push(&node.base);

                        stack.push(State.TopLevel) catch unreachable;
                        try stack.push(State { .Block = block });
                        try stack.push(State {
                            .ExpectTokenSave = ExpectTokenSave {
                                .id = Token.Id.LBrace,
                                .ptr = &block.rbrace,
                            }
                        });
                        continue;
                    },
                    else => {
                        putBackToken(&tok_it, &tree);
                        stack.push(State.TopLevel) catch unreachable;
                        try stack.push(State {
                            .TopLevelExtern = TopLevelDeclCtx {
                                .decls = &root_node.decls,
                                .visib_token = null,
                                .extern_export_inline_token = null,
                                .lib_name = null,
                                .comments = comments,
                            }
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
                        stack.push(State {
                            .TopLevelDecl = TopLevelDeclCtx {
                                .decls = ctx.decls,
                                .visib_token = ctx.visib_token,
                                .extern_export_inline_token = AnnotatedToken {
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
                        stack.push(State {
                            .TopLevelLibname = TopLevelDeclCtx {
                                .decls = ctx.decls,
                                .visib_token = ctx.visib_token,
                                .extern_export_inline_token = AnnotatedToken {
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
                        putBackToken(&tok_it, &tree);
                        stack.push(State { .TopLevelDecl = ctx }) catch unreachable;
                        continue;
                    }
                }
            },
            State.TopLevelLibname => |ctx| {
                const lib_name = blk: {
                    const lib_name_token = nextToken(&tok_it, &tree);
                    const lib_name_token_index = lib_name_token.index;
                    const lib_name_token_ptr = lib_name_token.ptr;
                    break :blk (try parseStringLiteral(arena, &tok_it, lib_name_token_ptr, lib_name_token_index, &tree)) ?? {
                        putBackToken(&tok_it, &tree);
                        break :blk null;
                    };
                };

                stack.push(State {
                    .TopLevelDecl = TopLevelDeclCtx {
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
                            *(try tree.errors.addOne()) = Error {
                                .InvalidToken = Error.InvalidToken { .token = annotated_token.index },
                            };
                            return tree;
                        }

                        const node = try arena.construct(ast.Node.Use {
                            .base = ast.Node {.id = ast.Node.Id.Use },
                            .visib_token = ctx.visib_token,
                            .expr = undefined,
                            .semicolon_token = undefined,
                            .doc_comments = ctx.comments,
                        });
                        try ctx.decls.push(&node.base);

                        stack.push(State {
                            .ExpectTokenSave = ExpectTokenSave {
                                .id = Token.Id.Semicolon,
                                .ptr = &node.semicolon_token,
                            }
                        }) catch unreachable;
                        try stack.push(State { .Expression = OptionalCtx { .Required = &node.expr } });
                        continue;
                    },
                    Token.Id.Keyword_var, Token.Id.Keyword_const => {
                        if (ctx.extern_export_inline_token) |annotated_token| {
                            if (annotated_token.ptr.id == Token.Id.Keyword_inline) {
                                *(try tree.errors.addOne()) = Error {
                                    .InvalidToken = Error.InvalidToken { .token = annotated_token.index },
                                };
                                return tree;
                            }
                        }

                        try stack.push(State {
                            .VarDecl = VarDeclCtx {
                                .comments = ctx.comments,
                                .visib_token = ctx.visib_token,
                                .lib_name = ctx.lib_name,
                                .comptime_token = null,
                                .extern_export_token = if (ctx.extern_export_inline_token) |at| at.index else null,
                                .mut_token = token_index,
                                .list = ctx.decls
                            }
                        });
                        continue;
                    },
                    Token.Id.Keyword_fn, Token.Id.Keyword_nakedcc,
                    Token.Id.Keyword_stdcallcc, Token.Id.Keyword_async => {
                        const fn_proto = try arena.construct(ast.Node.FnProto {
                            .base = ast.Node {
                                .id = ast.Node.Id.FnProto,
                            },
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
                        stack.push(State { .FnDef = fn_proto }) catch unreachable;
                        try stack.push(State { .FnProto = fn_proto });

                        switch (token_ptr.id) {
                            Token.Id.Keyword_nakedcc, Token.Id.Keyword_stdcallcc => {
                                fn_proto.cc_token = token_index;
                                try stack.push(State {
                                    .ExpectTokenSave = ExpectTokenSave {
                                        .id = Token.Id.Keyword_fn,
                                        .ptr = &fn_proto.fn_token,
                                    }
                                });
                                continue;
                            },
                            Token.Id.Keyword_async => {
                                const async_node = try createNode(arena, ast.Node.AsyncAttribute,
                                    ast.Node.AsyncAttribute {
                                        .base = undefined,
                                        .async_token = token_index,
                                        .allocator_type = null,
                                        .rangle_bracket = null,
                                    }
                                );
                                fn_proto.async_attr = async_node;

                                try stack.push(State {
                                    .ExpectTokenSave = ExpectTokenSave {
                                        .id = Token.Id.Keyword_fn,
                                        .ptr = &fn_proto.fn_token,
                                    }
                                });
                                try stack.push(State { .AsyncAllocator = async_node });
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
                        *(try tree.errors.addOne()) = Error {
                            .ExpectedVarDeclOrFn = Error.ExpectedVarDeclOrFn { .token = token_index },
                        };
                        return tree;
                    },
                }
            },
            State.TopLevelExternOrField => |ctx| {
                if (eatToken(&tok_it, &tree, Token.Id.Identifier)) |identifier| {
                    std.debug.assert(ctx.container_decl.kind == ast.Node.ContainerDecl.Kind.Struct);
                    const node = try arena.construct(ast.Node.StructField {
                        .base = ast.Node {
                            .id = ast.Node.Id.StructField,
                        },
                        .doc_comments = ctx.comments,
                        .visib_token = ctx.visib_token,
                        .name_token = identifier,
                        .type_expr = undefined,
                    });
                    const node_ptr = try ctx.container_decl.fields_and_decls.addOne();
                    *node_ptr = &node.base;

                    stack.push(State { .FieldListCommaOrEnd = ctx.container_decl }) catch unreachable;
                    try stack.push(State { .Expression = OptionalCtx { .Required = &node.type_expr } });
                    try stack.push(State { .ExpectToken = Token.Id.Colon });
                    continue;
                }

                stack.push(State{ .ContainerDecl = ctx.container_decl }) catch unreachable;
                try stack.push(State {
                    .TopLevelExtern = TopLevelDeclCtx {
                        .decls = &ctx.container_decl.fields_and_decls,
                        .visib_token = ctx.visib_token,
                        .extern_export_inline_token = null,
                        .lib_name = null,
                        .comments = ctx.comments,
                    }
                });
                continue;
            },

            State.FieldInitValue => |ctx| {
                const eq_tok = nextToken(&tok_it, &tree);
                const eq_tok_index = eq_tok.index;
                const eq_tok_ptr = eq_tok.ptr;
                if (eq_tok_ptr.id != Token.Id.Equal) {
                    putBackToken(&tok_it, &tree);
                    continue;
                }
                stack.push(State { .Expression = ctx }) catch unreachable;
                continue;
            },

            State.ContainerKind => |ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                const node = try createToCtxNode(arena, ctx.opt_ctx, ast.Node.ContainerDecl,
                    ast.Node.ContainerDecl {
                        .base = undefined,
                        .ltoken = ctx.ltoken,
                        .layout = ctx.layout,
                        .kind = switch (token_ptr.id) {
                            Token.Id.Keyword_struct => ast.Node.ContainerDecl.Kind.Struct,
                            Token.Id.Keyword_union => ast.Node.ContainerDecl.Kind.Union,
                            Token.Id.Keyword_enum => ast.Node.ContainerDecl.Kind.Enum,
                            else => {
                                *(try tree.errors.addOne()) = Error {
                                    .ExpectedAggregateKw = Error.ExpectedAggregateKw { .token = token_index },
                                };
                                return tree;
                            },
                        },
                        .init_arg_expr = ast.Node.ContainerDecl.InitArg.None,
                        .fields_and_decls = ast.Node.ContainerDecl.DeclList.init(arena),
                        .rbrace_token = undefined,
                    }
                );

                stack.push(State { .ContainerDecl = node }) catch unreachable;
                try stack.push(State { .ExpectToken = Token.Id.LBrace });
                try stack.push(State { .ContainerInitArgStart = node });
                continue;
            },

            State.ContainerInitArgStart => |container_decl| {
                if (eatToken(&tok_it, &tree, Token.Id.LParen) == null) {
                    continue;
                }

                stack.push(State { .ExpectToken = Token.Id.RParen }) catch unreachable;
                try stack.push(State { .ContainerInitArg = container_decl });
                continue;
            },

            State.ContainerInitArg => |container_decl| {
                const init_arg_token = nextToken(&tok_it, &tree);
                const init_arg_token_index = init_arg_token.index;
                const init_arg_token_ptr = init_arg_token.ptr;
                switch (init_arg_token_ptr.id) {
                    Token.Id.Keyword_enum => {
                        container_decl.init_arg_expr = ast.Node.ContainerDecl.InitArg {.Enum = null};
                        const lparen_tok = nextToken(&tok_it, &tree);
                        const lparen_tok_index = lparen_tok.index;
                        const lparen_tok_ptr = lparen_tok.ptr;
                        if (lparen_tok_ptr.id == Token.Id.LParen) {
                            try stack.push(State { .ExpectToken = Token.Id.RParen } );
                            try stack.push(State { .Expression = OptionalCtx {
                                .RequiredNull = &container_decl.init_arg_expr.Enum,
                            } });
                        } else {
                            putBackToken(&tok_it, &tree);
                        }
                    },
                    else => {
                        putBackToken(&tok_it, &tree);
                        container_decl.init_arg_expr = ast.Node.ContainerDecl.InitArg { .Type = undefined };
                        stack.push(State { .Expression = OptionalCtx { .Required = &container_decl.init_arg_expr.Type } }) catch unreachable;
                    },
                }
                continue;
            },

            State.ContainerDecl => |container_decl| {
                while (try eatLineComment(arena, &tok_it, &tree)) |line_comment| {
                    try container_decl.fields_and_decls.push(&line_comment.base);
                }

                const comments = try eatDocComments(arena, &tok_it, &tree);
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Identifier => {
                        switch (container_decl.kind) {
                            ast.Node.ContainerDecl.Kind.Struct => {
                                const node = try arena.construct(ast.Node.StructField {
                                    .base = ast.Node {
                                        .id = ast.Node.Id.StructField,
                                    },
                                    .doc_comments = comments,
                                    .visib_token = null,
                                    .name_token = token_index,
                                    .type_expr = undefined,
                                });
                                const node_ptr = try container_decl.fields_and_decls.addOne();
                                *node_ptr = &node.base;

                                try stack.push(State { .FieldListCommaOrEnd = container_decl });
                                try stack.push(State { .TypeExprBegin = OptionalCtx { .Required = &node.type_expr } });
                                try stack.push(State { .ExpectToken = Token.Id.Colon });
                                continue;
                            },
                            ast.Node.ContainerDecl.Kind.Union => {
                                const node = try arena.construct(ast.Node.UnionTag {
                                    .base = ast.Node {.id = ast.Node.Id.UnionTag },
                                    .name_token = token_index,
                                    .type_expr = null,
                                    .value_expr = null,
                                    .doc_comments = comments,
                                });
                                try container_decl.fields_and_decls.push(&node.base);

                                stack.push(State { .FieldListCommaOrEnd = container_decl }) catch unreachable;
                                try stack.push(State { .FieldInitValue = OptionalCtx { .RequiredNull = &node.value_expr } });
                                try stack.push(State { .TypeExprBegin = OptionalCtx { .RequiredNull = &node.type_expr } });
                                try stack.push(State { .IfToken = Token.Id.Colon });
                                continue;
                            },
                            ast.Node.ContainerDecl.Kind.Enum => {
                                const node = try arena.construct(ast.Node.EnumTag {
                                    .base = ast.Node { .id = ast.Node.Id.EnumTag },
                                    .name_token = token_index,
                                    .value = null,
                                    .doc_comments = comments,
                                });
                                try container_decl.fields_and_decls.push(&node.base);

                                stack.push(State { .FieldListCommaOrEnd = container_decl }) catch unreachable;
                                try stack.push(State { .Expression = OptionalCtx { .RequiredNull = &node.value } });
                                try stack.push(State { .IfToken = Token.Id.Equal });
                                continue;
                            },
                        }
                    },
                    Token.Id.Keyword_pub => {
                        switch (container_decl.kind) {
                            ast.Node.ContainerDecl.Kind.Struct => {
                                try stack.push(State {
                                    .TopLevelExternOrField = TopLevelExternOrFieldCtx {
                                        .visib_token = token_index,
                                        .container_decl = container_decl,
                                        .comments = comments,
                                    }
                                });
                                continue;
                            },
                            else => {
                                stack.push(State{ .ContainerDecl = container_decl }) catch unreachable;
                                try stack.push(State {
                                    .TopLevelExtern = TopLevelDeclCtx {
                                        .decls = &container_decl.fields_and_decls,
                                        .visib_token = token_index,
                                        .extern_export_inline_token = null,
                                        .lib_name = null,
                                        .comments = comments,
                                    }
                                });
                                continue;
                            }
                        }
                    },
                    Token.Id.Keyword_export => {
                        stack.push(State{ .ContainerDecl = container_decl }) catch unreachable;
                        try stack.push(State {
                            .TopLevelExtern = TopLevelDeclCtx {
                                .decls = &container_decl.fields_and_decls,
                                .visib_token = token_index,
                                .extern_export_inline_token = null,
                                .lib_name = null,
                                .comments = comments,
                            }
                        });
                        continue;
                    },
                    Token.Id.RBrace => {
                        if (comments != null) {
                            *(try tree.errors.addOne()) = Error {
                                .UnattachedDocComment = Error.UnattachedDocComment { .token = token_index },
                            };
                            return tree;
                        }
                        container_decl.rbrace_token = token_index;
                        continue;
                    },
                    else => {
                        putBackToken(&tok_it, &tree);
                        stack.push(State{ .ContainerDecl = container_decl }) catch unreachable;
                        try stack.push(State {
                            .TopLevelExtern = TopLevelDeclCtx {
                                .decls = &container_decl.fields_and_decls,
                                .visib_token = null,
                                .extern_export_inline_token = null,
                                .lib_name = null,
                                .comments = comments,
                            }
                        });
                        continue;
                    }
                }
            },


            State.VarDecl => |ctx| {
                const var_decl = try arena.construct(ast.Node.VarDecl {
                    .base = ast.Node {
                        .id = ast.Node.Id.VarDecl,
                    },
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

                try stack.push(State { .VarDeclAlign = var_decl });
                try stack.push(State { .TypeExprBegin = OptionalCtx { .RequiredNull = &var_decl.type_node} });
                try stack.push(State { .IfToken = Token.Id.Colon });
                try stack.push(State {
                    .ExpectTokenSave = ExpectTokenSave {
                        .id = Token.Id.Identifier,
                        .ptr = &var_decl.name_token,
                    }
                });
                continue;
            },
            State.VarDeclAlign => |var_decl| {
                try stack.push(State { .VarDeclEq = var_decl });

                const next_token = nextToken(&tok_it, &tree);
                const next_token_index = next_token.index;
                const next_token_ptr = next_token.ptr;
                if (next_token_ptr.id == Token.Id.Keyword_align) {
                    try stack.push(State { .ExpectToken = Token.Id.RParen });
                    try stack.push(State { .Expression = OptionalCtx { .RequiredNull = &var_decl.align_node} });
                    try stack.push(State { .ExpectToken = Token.Id.LParen });
                    continue;
                }

                putBackToken(&tok_it, &tree);
                continue;
            },
            State.VarDeclEq => |var_decl| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Equal => {
                        var_decl.eq_token = token_index;
                        stack.push(State {
                            .ExpectTokenSave = ExpectTokenSave {
                                .id = Token.Id.Semicolon,
                                .ptr = &var_decl.semicolon_token,
                            },
                        }) catch unreachable;
                        try stack.push(State { .Expression = OptionalCtx { .RequiredNull = &var_decl.init_node } });
                        continue;
                    },
                    Token.Id.Semicolon => {
                        var_decl.semicolon_token = token_index;
                        continue;
                    },
                    else => {
                        *(try tree.errors.addOne()) = Error {
                            .ExpectedEqOrSemi = Error.ExpectedEqOrSemi { .token = token_index },
                        };
                        return tree;
                    }
                }
            },


            State.FnDef => |fn_proto| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch(token_ptr.id) {
                    Token.Id.LBrace => {
                        const block = try arena.construct(ast.Node.Block {
                            .base = ast.Node { .id = ast.Node.Id.Block },
                            .label = null,
                            .lbrace = token_index,
                            .statements = ast.Node.Block.StatementList.init(arena),
                            .rbrace = undefined,
                        });
                        fn_proto.body_node = &block.base;
                        stack.push(State { .Block = block }) catch unreachable;
                        continue;
                    },
                    Token.Id.Semicolon => continue,
                    else => {
                        *(try tree.errors.addOne()) = Error {
                            .ExpectedSemiOrLBrace = Error.ExpectedSemiOrLBrace { .token = token_index },
                        };
                        return tree;
                    },
                }
            },
            State.FnProto => |fn_proto| {
                stack.push(State { .FnProtoAlign = fn_proto }) catch unreachable;
                try stack.push(State { .ParamDecl = fn_proto });
                try stack.push(State { .ExpectToken = Token.Id.LParen });

                if (eatToken(&tok_it, &tree, Token.Id.Identifier)) |name_token| {
                    fn_proto.name_token = name_token;
                }
                continue;
            },
            State.FnProtoAlign => |fn_proto| {
                stack.push(State { .FnProtoReturnType = fn_proto }) catch unreachable;

                if (eatToken(&tok_it, &tree, Token.Id.Keyword_align)) |align_token| {
                    try stack.push(State { .ExpectToken = Token.Id.RParen });
                    try stack.push(State { .Expression = OptionalCtx { .RequiredNull = &fn_proto.align_expr } });
                    try stack.push(State { .ExpectToken = Token.Id.LParen });
                }
                continue;
            },
            State.FnProtoReturnType => |fn_proto| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Bang => {
                        fn_proto.return_type = ast.Node.FnProto.ReturnType { .InferErrorSet = undefined };
                        stack.push(State {
                            .TypeExprBegin = OptionalCtx { .Required = &fn_proto.return_type.InferErrorSet },
                        }) catch unreachable;
                        continue;
                    },
                    else => {
                        // TODO: this is a special case. Remove this when #760 is fixed
                        if (token_ptr.id == Token.Id.Keyword_error) {
                            if ((??tok_it.peek()).id == Token.Id.LBrace) {
                                const error_type_node = try arena.construct(ast.Node.ErrorType {
                                    .base = ast.Node { .id = ast.Node.Id.ErrorType },
                                    .token = token_index,
                                });
                                fn_proto.return_type = ast.Node.FnProto.ReturnType {
                                    .Explicit = &error_type_node.base,
                                };
                                continue;
                            }
                        }

                        putBackToken(&tok_it, &tree);
                        fn_proto.return_type = ast.Node.FnProto.ReturnType { .Explicit = undefined };
                        stack.push(State { .TypeExprBegin = OptionalCtx { .Required = &fn_proto.return_type.Explicit }, }) catch unreachable;
                        continue;
                    },
                }
            },


            State.ParamDecl => |fn_proto| {
                if (eatToken(&tok_it, &tree, Token.Id.RParen)) |_| {
                    continue;
                }
                const param_decl = try arena.construct(ast.Node.ParamDecl {
                    .base = ast.Node {.id = ast.Node.Id.ParamDecl },
                    .comptime_token = null,
                    .noalias_token = null,
                    .name_token = null,
                    .type_node = undefined,
                    .var_args_token = null,
                });
                try fn_proto.params.push(&param_decl.base);

                stack.push(State {
                    .ParamDeclEnd = ParamDeclEndCtx {
                        .param_decl = param_decl,
                        .fn_proto = fn_proto,
                    }
                }) catch unreachable;
                try stack.push(State { .ParamDeclName = param_decl });
                try stack.push(State { .ParamDeclAliasOrComptime = param_decl });
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
                        putBackToken(&tok_it, &tree);
                    }
                }
                continue;
            },
            State.ParamDeclEnd => |ctx| {
                if (eatToken(&tok_it, &tree, Token.Id.Ellipsis3)) |ellipsis3| {
                    ctx.param_decl.var_args_token = ellipsis3;
                    stack.push(State { .ExpectToken = Token.Id.RParen }) catch unreachable;
                    continue;
                }

                try stack.push(State { .ParamDeclComma = ctx.fn_proto });
                try stack.push(State {
                    .TypeExprBegin = OptionalCtx { .Required = &ctx.param_decl.type_node }
                });
                continue;
            },
            State.ParamDeclComma => |fn_proto| {
                switch (expectCommaOrEnd(&tok_it, &tree, Token.Id.RParen)) {
                    ExpectCommaOrEndResult.end_token => |t| {
                        if (t == null) {
                            stack.push(State { .ParamDecl = fn_proto }) catch unreachable;
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
                    stack.push(State {
                        .LabeledExpression = LabelCtx {
                            .label = ctx.label,
                            .opt_ctx = ctx.opt_ctx,
                        }
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
                        const block = try createToCtxNode(arena, ctx.opt_ctx, ast.Node.Block,
                            ast.Node.Block {
                                .base = undefined,
                                .label = ctx.label,
                                .lbrace = token_index,
                                .statements = ast.Node.Block.StatementList.init(arena),
                                .rbrace = undefined,
                            }
                        );
                        stack.push(State { .Block = block }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_while => {
                        stack.push(State {
                            .While = LoopCtx {
                                .label = ctx.label,
                                .inline_token = null,
                                .loop_token = token_index,
                                .opt_ctx = ctx.opt_ctx.toRequired(),
                            }
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_for => {
                        stack.push(State {
                            .For = LoopCtx {
                                .label = ctx.label,
                                .inline_token = null,
                                .loop_token = token_index,
                                .opt_ctx = ctx.opt_ctx.toRequired(),
                            }
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_suspend => {
                        const node = try arena.construct(ast.Node.Suspend {
                            .base = ast.Node {
                                .id = ast.Node.Id.Suspend,
                            },
                            .label = ctx.label,
                            .suspend_token = token_index,
                            .payload = null,
                            .body = null,
                        });
                        ctx.opt_ctx.store(&node.base);
                        stack.push(State { .SuspendBody = node }) catch unreachable;
                        try stack.push(State { .Payload = OptionalCtx { .Optional = &node.payload } });
                        continue;
                    },
                    Token.Id.Keyword_inline => {
                        stack.push(State {
                            .Inline = InlineCtx {
                                .label = ctx.label,
                                .inline_token = token_index,
                                .opt_ctx = ctx.opt_ctx.toRequired(),
                            }
                        }) catch unreachable;
                        continue;
                    },
                    else => {
                        if (ctx.opt_ctx != OptionalCtx.Optional) {
                            *(try tree.errors.addOne()) = Error {
                                .ExpectedLabelable = Error.ExpectedLabelable { .token = token_index },
                            };
                            return tree;
                        }

                        putBackToken(&tok_it, &tree);
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
                        stack.push(State {
                            .While = LoopCtx {
                                .inline_token = ctx.inline_token,
                                .label = ctx.label,
                                .loop_token = token_index,
                                .opt_ctx = ctx.opt_ctx.toRequired(),
                            }
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_for => {
                        stack.push(State {
                            .For = LoopCtx {
                                .inline_token = ctx.inline_token,
                                .label = ctx.label,
                                .loop_token = token_index,
                                .opt_ctx = ctx.opt_ctx.toRequired(),
                            }
                        }) catch unreachable;
                        continue;
                    },
                    else => {
                        if (ctx.opt_ctx != OptionalCtx.Optional) {
                            *(try tree.errors.addOne()) = Error {
                                .ExpectedInlinable = Error.ExpectedInlinable { .token = token_index },
                            };
                            return tree;
                        }

                        putBackToken(&tok_it, &tree);
                        continue;
                    },
                }
            },
            State.While => |ctx| {
                const node = try createToCtxNode(arena, ctx.opt_ctx, ast.Node.While,
                    ast.Node.While {
                        .base = undefined,
                        .label = ctx.label,
                        .inline_token = ctx.inline_token,
                        .while_token = ctx.loop_token,
                        .condition = undefined,
                        .payload = null,
                        .continue_expr = null,
                        .body = undefined,
                        .@"else" = null,
                    }
                );
                stack.push(State { .Else = &node.@"else" }) catch unreachable;
                try stack.push(State { .Expression = OptionalCtx { .Required = &node.body } });
                try stack.push(State { .WhileContinueExpr = &node.continue_expr });
                try stack.push(State { .IfToken = Token.Id.Colon });
                try stack.push(State { .PointerPayload = OptionalCtx { .Optional = &node.payload } });
                try stack.push(State { .ExpectToken = Token.Id.RParen });
                try stack.push(State { .Expression = OptionalCtx { .Required = &node.condition } });
                try stack.push(State { .ExpectToken = Token.Id.LParen });
                continue;
            },
            State.WhileContinueExpr => |dest| {
                stack.push(State { .ExpectToken = Token.Id.RParen }) catch unreachable;
                try stack.push(State { .AssignmentExpressionBegin = OptionalCtx { .RequiredNull = dest } });
                try stack.push(State { .ExpectToken = Token.Id.LParen });
                continue;
            },
            State.For => |ctx| {
                const node = try createToCtxNode(arena, ctx.opt_ctx, ast.Node.For,
                    ast.Node.For {
                        .base = undefined,
                        .label = ctx.label,
                        .inline_token = ctx.inline_token,
                        .for_token = ctx.loop_token,
                        .array_expr = undefined,
                        .payload = null,
                        .body = undefined,
                        .@"else" = null,
                    }
                );
                stack.push(State { .Else = &node.@"else" }) catch unreachable;
                try stack.push(State { .Expression = OptionalCtx { .Required = &node.body } });
                try stack.push(State { .PointerIndexPayload = OptionalCtx { .Optional = &node.payload } });
                try stack.push(State { .ExpectToken = Token.Id.RParen });
                try stack.push(State { .Expression = OptionalCtx { .Required = &node.array_expr } });
                try stack.push(State { .ExpectToken = Token.Id.LParen });
                continue;
            },
            State.Else => |dest| {
                if (eatToken(&tok_it, &tree, Token.Id.Keyword_else)) |else_token| {
                    const node = try createNode(arena, ast.Node.Else,
                        ast.Node.Else {
                            .base = undefined,
                            .else_token = else_token,
                            .payload = null,
                            .body = undefined,
                        }
                    );
                    *dest = node;

                    stack.push(State { .Expression = OptionalCtx { .Required = &node.body } }) catch unreachable;
                    try stack.push(State { .Payload = OptionalCtx { .Optional = &node.payload } });
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
                        putBackToken(&tok_it, &tree);
                        stack.push(State { .Block = block }) catch unreachable;

                        var any_comments = false;
                        while (try eatLineComment(arena, &tok_it, &tree)) |line_comment| {
                            try block.statements.push(&line_comment.base);
                            any_comments = true;
                        }
                        if (any_comments) continue;

                        try stack.push(State { .Statement = block });
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
                        stack.push(State {
                            .ComptimeStatement = ComptimeStatementCtx {
                                .comptime_token = token_index,
                                .block = block,
                            }
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_var, Token.Id.Keyword_const => {
                        stack.push(State {
                            .VarDecl = VarDeclCtx {
                                .comments = null,
                                .visib_token = null,
                                .comptime_token = null,
                                .extern_export_token = null,
                                .lib_name = null,
                                .mut_token = token_index,
                                .list = &block.statements,
                            }
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_defer, Token.Id.Keyword_errdefer => {
                        const node = try arena.construct(ast.Node.Defer {
                            .base = ast.Node {
                                .id = ast.Node.Id.Defer,
                            },
                            .defer_token = token_index,
                            .kind = switch (token_ptr.id) {
                                Token.Id.Keyword_defer => ast.Node.Defer.Kind.Unconditional,
                                Token.Id.Keyword_errdefer => ast.Node.Defer.Kind.Error,
                                else => unreachable,
                            },
                            .expr = undefined,
                        });
                        const node_ptr = try block.statements.addOne();
                        *node_ptr = &node.base;

                        stack.push(State { .Semicolon = node_ptr }) catch unreachable;
                        try stack.push(State { .AssignmentExpressionBegin = OptionalCtx{ .Required = &node.expr } });
                        continue;
                    },
                    Token.Id.LBrace => {
                        const inner_block = try arena.construct(ast.Node.Block {
                            .base = ast.Node { .id = ast.Node.Id.Block },
                            .label = null,
                            .lbrace = token_index,
                            .statements = ast.Node.Block.StatementList.init(arena),
                            .rbrace = undefined,
                        });
                        try block.statements.push(&inner_block.base);

                        stack.push(State { .Block = inner_block }) catch unreachable;
                        continue;
                    },
                    else => {
                        putBackToken(&tok_it, &tree);
                        const statement = try block.statements.addOne();
                        try stack.push(State { .Semicolon = statement });
                        try stack.push(State { .AssignmentExpressionBegin = OptionalCtx{ .Required = statement } });
                        continue;
                    }
                }
            },
            State.ComptimeStatement => |ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Keyword_var, Token.Id.Keyword_const => {
                        stack.push(State {
                            .VarDecl = VarDeclCtx {
                                .comments = null,
                                .visib_token = null,
                                .comptime_token = ctx.comptime_token,
                                .extern_export_token = null,
                                .lib_name = null,
                                .mut_token = token_index,
                                .list = &ctx.block.statements,
                            }
                        }) catch unreachable;
                        continue;
                    },
                    else => {
                        putBackToken(&tok_it, &tree);
                        putBackToken(&tok_it, &tree);
                        const statement = try ctx.block.statements.addOne();
                        try stack.push(State { .Semicolon = statement });
                        try stack.push(State { .Expression = OptionalCtx { .Required = statement } });
                        continue;
                    }
                }
            },
            State.Semicolon => |node_ptr| {
                const node = *node_ptr;
                if (node.requireSemiColon()) {
                    stack.push(State { .ExpectToken = Token.Id.Semicolon }) catch unreachable;
                    continue;
                }
                continue;
            },

            State.AsmOutputItems => |items| {
                const lbracket = nextToken(&tok_it, &tree);
                const lbracket_index = lbracket.index;
                const lbracket_ptr = lbracket.ptr;
                if (lbracket_ptr.id != Token.Id.LBracket) {
                    putBackToken(&tok_it, &tree);
                    continue;
                }

                const node = try createNode(arena, ast.Node.AsmOutput,
                    ast.Node.AsmOutput {
                        .base = undefined,
                        .symbolic_name = undefined,
                        .constraint = undefined,
                        .kind = undefined,
                    }
                );
                try items.push(node);

                stack.push(State { .AsmOutputItems = items }) catch unreachable;
                try stack.push(State { .IfToken = Token.Id.Comma });
                try stack.push(State { .ExpectToken = Token.Id.RParen });
                try stack.push(State { .AsmOutputReturnOrType = node });
                try stack.push(State { .ExpectToken = Token.Id.LParen });
                try stack.push(State { .StringLiteral = OptionalCtx { .Required = &node.constraint } });
                try stack.push(State { .ExpectToken = Token.Id.RBracket });
                try stack.push(State { .Identifier = OptionalCtx { .Required = &node.symbolic_name } });
                continue;
            },
            State.AsmOutputReturnOrType => |node| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Identifier => {
                        node.kind = ast.Node.AsmOutput.Kind { .Variable = try createLiteral(arena, ast.Node.Identifier, token_index) };
                        continue;
                    },
                    Token.Id.Arrow => {
                        node.kind = ast.Node.AsmOutput.Kind { .Return = undefined };
                        try stack.push(State { .TypeExprBegin = OptionalCtx { .Required = &node.kind.Return } });
                        continue;
                    },
                    else => {
                        *(try tree.errors.addOne()) = Error {
                            .ExpectedAsmOutputReturnOrType = Error.ExpectedAsmOutputReturnOrType {
                                .token = token_index,
                            },
                        };
                        return tree;
                    },
                }
            },
            State.AsmInputItems => |items| {
                const lbracket = nextToken(&tok_it, &tree);
                const lbracket_index = lbracket.index;
                const lbracket_ptr = lbracket.ptr;
                if (lbracket_ptr.id != Token.Id.LBracket) {
                    putBackToken(&tok_it, &tree);
                    continue;
                }

                const node = try createNode(arena, ast.Node.AsmInput,
                    ast.Node.AsmInput {
                        .base = undefined,
                        .symbolic_name = undefined,
                        .constraint = undefined,
                        .expr = undefined,
                    }
                );
                try items.push(node);

                stack.push(State { .AsmInputItems = items }) catch unreachable;
                try stack.push(State { .IfToken = Token.Id.Comma });
                try stack.push(State { .ExpectToken = Token.Id.RParen });
                try stack.push(State { .Expression = OptionalCtx { .Required = &node.expr } });
                try stack.push(State { .ExpectToken = Token.Id.LParen });
                try stack.push(State { .StringLiteral = OptionalCtx { .Required = &node.constraint } });
                try stack.push(State { .ExpectToken = Token.Id.RBracket });
                try stack.push(State { .Identifier = OptionalCtx { .Required = &node.symbolic_name } });
                continue;
            },
            State.AsmClobberItems => |items| {
                stack.push(State { .AsmClobberItems = items }) catch unreachable;
                try stack.push(State { .IfToken = Token.Id.Comma });
                try stack.push(State { .StringLiteral = OptionalCtx { .Required = try items.addOne() } });
                continue;
            },


            State.ExprListItemOrEnd => |list_state| {
                if (eatToken(&tok_it, &tree, list_state.end)) |token_index| {
                    *list_state.ptr = token_index;
                    continue;
                }

                stack.push(State { .ExprListCommaOrEnd = list_state }) catch unreachable;
                try stack.push(State { .Expression = OptionalCtx { .Required = try list_state.list.addOne() } });
                continue;
            },
            State.ExprListCommaOrEnd => |list_state| {
                switch (expectCommaOrEnd(&tok_it, &tree, list_state.end)) {
                    ExpectCommaOrEndResult.end_token => |maybe_end| if (maybe_end) |end| {
                        *list_state.ptr = end;
                        continue;
                    } else {
                        stack.push(State { .ExprListItemOrEnd = list_state }) catch unreachable;
                        continue;
                    },
                    ExpectCommaOrEndResult.parse_error => |e| {
                        try tree.errors.push(e);
                        return tree;
                    },
                }
            },
            State.FieldInitListItemOrEnd => |list_state| {
                while (try eatLineComment(arena, &tok_it, &tree)) |line_comment| {
                    try list_state.list.push(&line_comment.base);
                }

                if (eatToken(&tok_it, &tree, Token.Id.RBrace)) |rbrace| {
                    *list_state.ptr = rbrace;
                    continue;
                }

                const node = try arena.construct(ast.Node.FieldInitializer {
                    .base = ast.Node {
                        .id = ast.Node.Id.FieldInitializer,
                    },
                    .period_token = undefined,
                    .name_token = undefined,
                    .expr = undefined,
                });
                try list_state.list.push(&node.base);

                stack.push(State { .FieldInitListCommaOrEnd = list_state }) catch unreachable;
                try stack.push(State { .Expression = OptionalCtx{ .Required = &node.expr } });
                try stack.push(State { .ExpectToken = Token.Id.Equal });
                try stack.push(State {
                    .ExpectTokenSave = ExpectTokenSave {
                        .id = Token.Id.Identifier,
                        .ptr = &node.name_token,
                    }
                });
                try stack.push(State {
                    .ExpectTokenSave = ExpectTokenSave {
                        .id = Token.Id.Period,
                        .ptr = &node.period_token,
                    }
                });
                continue;
            },
            State.FieldInitListCommaOrEnd => |list_state| {
                switch (expectCommaOrEnd(&tok_it, &tree, Token.Id.RBrace)) {
                    ExpectCommaOrEndResult.end_token => |maybe_end| if (maybe_end) |end| {
                        *list_state.ptr = end;
                        continue;
                    } else {
                        stack.push(State { .FieldInitListItemOrEnd = list_state }) catch unreachable;
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
                        try stack.push(State { .ContainerDecl = container_decl });
                        continue;
                    },
                    ExpectCommaOrEndResult.parse_error => |e| {
                        try tree.errors.push(e);
                        return tree;
                    },
                }
            },
            State.ErrorTagListItemOrEnd => |list_state| {
                while (try eatLineComment(arena, &tok_it, &tree)) |line_comment| {
                    try list_state.list.push(&line_comment.base);
                }

                if (eatToken(&tok_it, &tree, Token.Id.RBrace)) |rbrace| {
                    *list_state.ptr = rbrace;
                    continue;
                }

                const node_ptr = try list_state.list.addOne();

                try stack.push(State { .ErrorTagListCommaOrEnd = list_state });
                try stack.push(State { .ErrorTag = node_ptr });
                continue;
            },
            State.ErrorTagListCommaOrEnd => |list_state| {
                switch (expectCommaOrEnd(&tok_it, &tree, Token.Id.RBrace)) {
                    ExpectCommaOrEndResult.end_token => |maybe_end| if (maybe_end) |end| {
                        *list_state.ptr = end;
                        continue;
                    } else {
                        stack.push(State { .ErrorTagListItemOrEnd = list_state }) catch unreachable;
                        continue;
                    },
                    ExpectCommaOrEndResult.parse_error => |e| {
                        try tree.errors.push(e);
                        return tree;
                    },
                }
            },
            State.SwitchCaseOrEnd => |list_state| {
                while (try eatLineComment(arena, &tok_it, &tree)) |line_comment| {
                    try list_state.list.push(&line_comment.base);
                }

                if (eatToken(&tok_it, &tree, Token.Id.RBrace)) |rbrace| {
                    *list_state.ptr = rbrace;
                    continue;
                }

                const comments = try eatDocComments(arena, &tok_it, &tree);
                const node = try arena.construct(ast.Node.SwitchCase {
                    .base = ast.Node {
                        .id = ast.Node.Id.SwitchCase,
                    },
                    .items = ast.Node.SwitchCase.ItemList.init(arena),
                    .payload = null,
                    .expr = undefined,
                });
                try list_state.list.push(&node.base);
                try stack.push(State { .SwitchCaseCommaOrEnd = list_state });
                try stack.push(State { .AssignmentExpressionBegin = OptionalCtx { .Required = &node.expr  } });
                try stack.push(State { .PointerPayload = OptionalCtx { .Optional = &node.payload } });
                try stack.push(State { .SwitchCaseFirstItem = &node.items });

                continue;
            },

            State.SwitchCaseCommaOrEnd => |list_state| {
                switch (expectCommaOrEnd(&tok_it, &tree, Token.Id.RParen)) {
                    ExpectCommaOrEndResult.end_token => |maybe_end| if (maybe_end) |end| {
                        *list_state.ptr = end;
                        continue;
                    } else {
                        try stack.push(State { .SwitchCaseOrEnd = list_state });
                        continue;
                    },
                    ExpectCommaOrEndResult.parse_error => |e| {
                        try tree.errors.push(e);
                        return tree;
                    },
                }
            },

            State.SwitchCaseFirstItem => |case_items| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (token_ptr.id == Token.Id.Keyword_else) {
                    const else_node = try arena.construct(ast.Node.SwitchElse {
                        .base = ast.Node{ .id = ast.Node.Id.SwitchElse},
                        .token = token_index,
                    });
                    try case_items.push(&else_node.base);

                    try stack.push(State { .ExpectToken = Token.Id.EqualAngleBracketRight });
                    continue;
                } else {
                    putBackToken(&tok_it, &tree);
                    try stack.push(State { .SwitchCaseItem = case_items });
                    continue;
                }
            },
            State.SwitchCaseItem => |case_items| {
                stack.push(State { .SwitchCaseItemCommaOrEnd = case_items }) catch unreachable;
                try stack.push(State { .RangeExpressionBegin = OptionalCtx { .Required = try case_items.addOne() } });
            },
            State.SwitchCaseItemCommaOrEnd => |case_items| {
                switch (expectCommaOrEnd(&tok_it, &tree, Token.Id.EqualAngleBracketRight)) {
                    ExpectCommaOrEndResult.end_token => |t| {
                        if (t == null) {
                            stack.push(State { .SwitchCaseItem = case_items }) catch unreachable;
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
                    try stack.push(State { .AssignmentExpressionBegin = OptionalCtx { .RequiredNull = &suspend_node.body } });
                }
                continue;
            },
            State.AsyncAllocator => |async_node| {
                if (eatToken(&tok_it, &tree, Token.Id.AngleBracketLeft) == null) {
                    continue;
                }

                async_node.rangle_bracket = TokenIndex(0);
                try stack.push(State {
                    .ExpectTokenSave = ExpectTokenSave {
                        .id = Token.Id.AngleBracketRight,
                        .ptr = &??async_node.rangle_bracket,
                    }
                });
                try stack.push(State { .TypeExprBegin = OptionalCtx { .RequiredNull = &async_node.allocator_type } });
                continue;
            },
            State.AsyncEnd => |ctx| {
                const node = ctx.ctx.get() ?? continue;

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

                        *(try tree.errors.addOne()) = Error {
                            .ExpectedCall = Error.ExpectedCall { .node = node },
                        };
                        return tree;
                    },
                    else => {
                        *(try tree.errors.addOne()) = Error {
                            .ExpectedCallOrFnProto = Error.ExpectedCallOrFnProto { .node = node },
                        };
                        return tree;
                    }
                }
            },


            State.ExternType => |ctx| {
                if (eatToken(&tok_it, &tree, Token.Id.Keyword_fn)) |fn_token| {
                    const fn_proto = try arena.construct(ast.Node.FnProto {
                        .base = ast.Node {
                            .id = ast.Node.Id.FnProto,
                        },
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
                    stack.push(State { .FnProto = fn_proto }) catch unreachable;
                    continue;
                }

                stack.push(State {
                    .ContainerKind = ContainerKindCtx {
                        .opt_ctx = ctx.opt_ctx,
                        .ltoken = ctx.extern_token,
                        .layout = ast.Node.ContainerDecl.Layout.Extern,
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
                        node.op = ast.Node.SuffixOp.Op {
                            .Slice = ast.Node.SuffixOp.Op.Slice {
                                .start = start,
                                .end = null,
                            }
                        };

                        stack.push(State {
                            .ExpectTokenSave = ExpectTokenSave {
                                .id = Token.Id.RBracket,
                                .ptr = &node.rtoken,
                            }
                        }) catch unreachable;
                        try stack.push(State { .Expression = OptionalCtx { .Optional = &node.op.Slice.end } });
                        continue;
                    },
                    Token.Id.RBracket => {
                        node.rtoken = token_index;
                        continue;
                    },
                    else => {
                        *(try tree.errors.addOne()) = Error {
                            .ExpectedSliceOrRBracket = Error.ExpectedSliceOrRBracket { .token = token_index },
                        };
                        return tree;
                    }
                }
            },
            State.SliceOrArrayType => |node| {
                if (eatToken(&tok_it, &tree, Token.Id.RBracket)) |_| {
                    node.op = ast.Node.PrefixOp.Op {
                        .SliceType = ast.Node.PrefixOp.AddrOfInfo {
                            .align_expr = null,
                            .bit_offset_start_token = null,
                            .bit_offset_end_token = null,
                            .const_token = null,
                            .volatile_token = null,
                        }
                    };
                    stack.push(State { .TypeExprBegin = OptionalCtx { .Required = &node.rhs } }) catch unreachable;
                    try stack.push(State { .AddrOfModifiers = &node.op.SliceType });
                    continue;
                }

                node.op = ast.Node.PrefixOp.Op { .ArrayType = undefined };
                stack.push(State { .TypeExprBegin = OptionalCtx { .Required = &node.rhs } }) catch unreachable;
                try stack.push(State { .ExpectToken = Token.Id.RBracket });
                try stack.push(State { .Expression = OptionalCtx { .Required = &node.op.ArrayType } });
                continue;
            },
            State.AddrOfModifiers => |addr_of_info| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Keyword_align => {
                        stack.push(state) catch unreachable;
                        if (addr_of_info.align_expr != null) {
                            *(try tree.errors.addOne()) = Error {
                                .ExtraAlignQualifier = Error.ExtraAlignQualifier { .token = token_index },
                            };
                            return tree;
                        }
                        try stack.push(State { .ExpectToken = Token.Id.RParen });
                        try stack.push(State { .Expression = OptionalCtx { .RequiredNull = &addr_of_info.align_expr} });
                        try stack.push(State { .ExpectToken = Token.Id.LParen });
                        continue;
                    },
                    Token.Id.Keyword_const => {
                        stack.push(state) catch unreachable;
                        if (addr_of_info.const_token != null) {
                            *(try tree.errors.addOne()) = Error {
                                .ExtraConstQualifier = Error.ExtraConstQualifier { .token = token_index },
                            };
                            return tree;
                        }
                        addr_of_info.const_token = token_index;
                        continue;
                    },
                    Token.Id.Keyword_volatile => {
                        stack.push(state) catch unreachable;
                        if (addr_of_info.volatile_token != null) {
                            *(try tree.errors.addOne()) = Error {
                                .ExtraVolatileQualifier = Error.ExtraVolatileQualifier { .token = token_index },
                            };
                            return tree;
                        }
                        addr_of_info.volatile_token = token_index;
                        continue;
                    },
                    else => {
                        putBackToken(&tok_it, &tree);
                        continue;
                    },
                }
            },


            State.Payload => |opt_ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (token_ptr.id != Token.Id.Pipe) {
                    if (opt_ctx != OptionalCtx.Optional) {
                        *(try tree.errors.addOne()) = Error {
                            .ExpectedToken = Error.ExpectedToken {
                                .token = token_index,
                                .expected_id = Token.Id.Pipe,
                            },
                        };
                        return tree;
                    }

                    putBackToken(&tok_it, &tree);
                    continue;
                }

                const node = try createToCtxNode(arena, opt_ctx, ast.Node.Payload,
                    ast.Node.Payload {
                        .base = undefined,
                        .lpipe = token_index,
                        .error_symbol = undefined,
                        .rpipe = undefined
                    }
                );

                stack.push(State {
                    .ExpectTokenSave = ExpectTokenSave {
                        .id = Token.Id.Pipe,
                        .ptr = &node.rpipe,
                    }
                }) catch unreachable;
                try stack.push(State { .Identifier = OptionalCtx { .Required = &node.error_symbol } });
                continue;
            },
            State.PointerPayload => |opt_ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (token_ptr.id != Token.Id.Pipe) {
                    if (opt_ctx != OptionalCtx.Optional) {
                        *(try tree.errors.addOne()) = Error {
                            .ExpectedToken = Error.ExpectedToken {
                                .token = token_index,
                                .expected_id = Token.Id.Pipe,
                            },
                        };
                        return tree;
                    }

                    putBackToken(&tok_it, &tree);
                    continue;
                }

                const node = try createToCtxNode(arena, opt_ctx, ast.Node.PointerPayload,
                    ast.Node.PointerPayload {
                        .base = undefined,
                        .lpipe = token_index,
                        .ptr_token = null,
                        .value_symbol = undefined,
                        .rpipe = undefined
                    }
                );

                try stack.push(State {
                    .ExpectTokenSave = ExpectTokenSave {
                        .id = Token.Id.Pipe,
                        .ptr = &node.rpipe,
                    }
                });
                try stack.push(State { .Identifier = OptionalCtx { .Required = &node.value_symbol } });
                try stack.push(State {
                    .OptionalTokenSave = OptionalTokenSave {
                        .id = Token.Id.Asterisk,
                        .ptr = &node.ptr_token,
                    }
                });
                continue;
            },
            State.PointerIndexPayload => |opt_ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (token_ptr.id != Token.Id.Pipe) {
                    if (opt_ctx != OptionalCtx.Optional) {
                        *(try tree.errors.addOne()) = Error {
                            .ExpectedToken = Error.ExpectedToken {
                                .token = token_index,
                                .expected_id = Token.Id.Pipe,
                            },
                        };
                        return tree;
                    }

                    putBackToken(&tok_it, &tree);
                    continue;
                }

                const node = try createToCtxNode(arena, opt_ctx, ast.Node.PointerIndexPayload,
                    ast.Node.PointerIndexPayload {
                        .base = undefined,
                        .lpipe = token_index,
                        .ptr_token = null,
                        .value_symbol = undefined,
                        .index_symbol = null,
                        .rpipe = undefined
                    }
                );

                stack.push(State {
                    .ExpectTokenSave = ExpectTokenSave {
                        .id = Token.Id.Pipe,
                        .ptr = &node.rpipe,
                    }
                }) catch unreachable;
                try stack.push(State { .Identifier = OptionalCtx { .RequiredNull = &node.index_symbol } });
                try stack.push(State { .IfToken = Token.Id.Comma });
                try stack.push(State { .Identifier = OptionalCtx { .Required = &node.value_symbol } });
                try stack.push(State {
                    .OptionalTokenSave = OptionalTokenSave {
                        .id = Token.Id.Asterisk,
                        .ptr = &node.ptr_token,
                    }
                });
                continue;
            },


            State.Expression => |opt_ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.Keyword_return, Token.Id.Keyword_break, Token.Id.Keyword_continue => {
                        const node = try createToCtxNode(arena, opt_ctx, ast.Node.ControlFlowExpression,
                            ast.Node.ControlFlowExpression {
                                .base = undefined,
                                .ltoken = token_index,
                                .kind = undefined,
                                .rhs = null,
                            }
                        );

                        stack.push(State { .Expression = OptionalCtx { .Optional = &node.rhs } }) catch unreachable;

                        switch (token_ptr.id) {
                            Token.Id.Keyword_break => {
                                node.kind = ast.Node.ControlFlowExpression.Kind { .Break = null };
                                try stack.push(State { .Identifier = OptionalCtx { .RequiredNull = &node.kind.Break } });
                                try stack.push(State { .IfToken = Token.Id.Colon });
                            },
                            Token.Id.Keyword_continue => {
                                node.kind = ast.Node.ControlFlowExpression.Kind { .Continue = null };
                                try stack.push(State { .Identifier = OptionalCtx { .RequiredNull = &node.kind.Continue } });
                                try stack.push(State { .IfToken = Token.Id.Colon });
                            },
                            Token.Id.Keyword_return => {
                                node.kind = ast.Node.ControlFlowExpression.Kind.Return;
                            },
                            else => unreachable,
                        }
                        continue;
                    },
                    Token.Id.Keyword_try, Token.Id.Keyword_cancel, Token.Id.Keyword_resume => {
                        const node = try createToCtxNode(arena, opt_ctx, ast.Node.PrefixOp,
                            ast.Node.PrefixOp {
                                .base = undefined,
                                .op_token = token_index,
                                .op = switch (token_ptr.id) {
                                    Token.Id.Keyword_try => ast.Node.PrefixOp.Op { .Try = void{} },
                                    Token.Id.Keyword_cancel => ast.Node.PrefixOp.Op { .Cancel = void{} },
                                    Token.Id.Keyword_resume => ast.Node.PrefixOp.Op { .Resume = void{} },
                                    else => unreachable,
                                },
                                .rhs = undefined,
                            }
                        );

                        stack.push(State { .Expression = OptionalCtx { .Required = &node.rhs } }) catch unreachable;
                        continue;
                    },
                    else => {
                        if (!try parseBlockExpr(&stack, arena, opt_ctx, token_ptr, token_index)) {
                            putBackToken(&tok_it, &tree);
                            stack.push(State { .UnwrapExpressionBegin = opt_ctx }) catch unreachable;
                        }
                        continue;
                    }
                }
            },
            State.RangeExpressionBegin => |opt_ctx| {
                stack.push(State { .RangeExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .Expression = opt_ctx });
                continue;
            },
            State.RangeExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                if (eatToken(&tok_it, &tree, Token.Id.Ellipsis3)) |ellipsis3| {
                    const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                        ast.Node.InfixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op_token = ellipsis3,
                            .op = ast.Node.InfixOp.Op.Range,
                            .rhs = undefined,
                        }
                    );
                    stack.push(State { .Expression = OptionalCtx { .Required = &node.rhs } }) catch unreachable;
                    continue;
                }
            },
            State.AssignmentExpressionBegin => |opt_ctx| {
                stack.push(State { .AssignmentExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .Expression = opt_ctx });
                continue;
            },

            State.AssignmentExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToAssignment(token_ptr.id)) |ass_id| {
                    const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                        ast.Node.InfixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op_token = token_index,
                            .op = ass_id,
                            .rhs = undefined,
                        }
                    );
                    stack.push(State { .AssignmentExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.push(State { .Expression = OptionalCtx { .Required = &node.rhs } });
                    continue;
                } else {
                    putBackToken(&tok_it, &tree);
                    continue;
                }
            },

            State.UnwrapExpressionBegin => |opt_ctx| {
                stack.push(State { .UnwrapExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .BoolOrExpressionBegin = opt_ctx });
                continue;
            },

            State.UnwrapExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToUnwrapExpr(token_ptr.id)) |unwrap_id| {
                    const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                        ast.Node.InfixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op_token = token_index,
                            .op = unwrap_id,
                            .rhs = undefined,
                        }
                    );

                    stack.push(State { .UnwrapExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.push(State { .Expression = OptionalCtx { .Required = &node.rhs } });

                    if (node.op == ast.Node.InfixOp.Op.Catch) {
                        try stack.push(State { .Payload = OptionalCtx { .Optional = &node.op.Catch } });
                    }
                    continue;
                } else {
                    putBackToken(&tok_it, &tree);
                    continue;
                }
            },

            State.BoolOrExpressionBegin => |opt_ctx| {
                stack.push(State { .BoolOrExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .BoolAndExpressionBegin = opt_ctx });
                continue;
            },

            State.BoolOrExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                if (eatToken(&tok_it, &tree, Token.Id.Keyword_or)) |or_token| {
                    const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                        ast.Node.InfixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op_token = or_token,
                            .op = ast.Node.InfixOp.Op.BoolOr,
                            .rhs = undefined,
                        }
                    );
                    stack.push(State { .BoolOrExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.push(State { .BoolAndExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                    continue;
                }
            },

            State.BoolAndExpressionBegin => |opt_ctx| {
                stack.push(State { .BoolAndExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .ComparisonExpressionBegin = opt_ctx });
                continue;
            },

            State.BoolAndExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                if (eatToken(&tok_it, &tree, Token.Id.Keyword_and)) |and_token| {
                    const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                        ast.Node.InfixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op_token = and_token,
                            .op = ast.Node.InfixOp.Op.BoolAnd,
                            .rhs = undefined,
                        }
                    );
                    stack.push(State { .BoolAndExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.push(State { .ComparisonExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                    continue;
                }
            },

            State.ComparisonExpressionBegin => |opt_ctx| {
                stack.push(State { .ComparisonExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .BinaryOrExpressionBegin = opt_ctx });
                continue;
            },

            State.ComparisonExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToComparison(token_ptr.id)) |comp_id| {
                    const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                        ast.Node.InfixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op_token = token_index,
                            .op = comp_id,
                            .rhs = undefined,
                        }
                    );
                    stack.push(State { .ComparisonExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.push(State { .BinaryOrExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                    continue;
                } else {
                    putBackToken(&tok_it, &tree);
                    continue;
                }
            },

            State.BinaryOrExpressionBegin => |opt_ctx| {
                stack.push(State { .BinaryOrExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .BinaryXorExpressionBegin = opt_ctx });
                continue;
            },

            State.BinaryOrExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                if (eatToken(&tok_it, &tree, Token.Id.Pipe)) |pipe| {
                    const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                        ast.Node.InfixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op_token = pipe,
                            .op = ast.Node.InfixOp.Op.BitOr,
                            .rhs = undefined,
                        }
                    );
                    stack.push(State { .BinaryOrExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.push(State { .BinaryXorExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                    continue;
                }
            },

            State.BinaryXorExpressionBegin => |opt_ctx| {
                stack.push(State { .BinaryXorExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .BinaryAndExpressionBegin = opt_ctx });
                continue;
            },

            State.BinaryXorExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                if (eatToken(&tok_it, &tree, Token.Id.Caret)) |caret| {
                    const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                        ast.Node.InfixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op_token = caret,
                            .op = ast.Node.InfixOp.Op.BitXor,
                            .rhs = undefined,
                        }
                    );
                    stack.push(State { .BinaryXorExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.push(State { .BinaryAndExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                    continue;
                }
            },

            State.BinaryAndExpressionBegin => |opt_ctx| {
                stack.push(State { .BinaryAndExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .BitShiftExpressionBegin = opt_ctx });
                continue;
            },

            State.BinaryAndExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                if (eatToken(&tok_it, &tree, Token.Id.Ampersand)) |ampersand| {
                    const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                        ast.Node.InfixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op_token = ampersand,
                            .op = ast.Node.InfixOp.Op.BitAnd,
                            .rhs = undefined,
                        }
                    );
                    stack.push(State { .BinaryAndExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.push(State { .BitShiftExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                    continue;
                }
            },

            State.BitShiftExpressionBegin => |opt_ctx| {
                stack.push(State { .BitShiftExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .AdditionExpressionBegin = opt_ctx });
                continue;
            },

            State.BitShiftExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToBitShift(token_ptr.id)) |bitshift_id| {
                    const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                        ast.Node.InfixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op_token = token_index,
                            .op = bitshift_id,
                            .rhs = undefined,
                        }
                    );
                    stack.push(State { .BitShiftExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.push(State { .AdditionExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                    continue;
                } else {
                    putBackToken(&tok_it, &tree);
                    continue;
                }
            },

            State.AdditionExpressionBegin => |opt_ctx| {
                stack.push(State { .AdditionExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .MultiplyExpressionBegin = opt_ctx });
                continue;
            },

            State.AdditionExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToAddition(token_ptr.id)) |add_id| {
                    const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                        ast.Node.InfixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op_token = token_index,
                            .op = add_id,
                            .rhs = undefined,
                        }
                    );
                    stack.push(State { .AdditionExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.push(State { .MultiplyExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                    continue;
                } else {
                    putBackToken(&tok_it, &tree);
                    continue;
                }
            },

            State.MultiplyExpressionBegin => |opt_ctx| {
                stack.push(State { .MultiplyExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .CurlySuffixExpressionBegin = opt_ctx });
                continue;
            },

            State.MultiplyExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToMultiply(token_ptr.id)) |mult_id| {
                    const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                        ast.Node.InfixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op_token = token_index,
                            .op = mult_id,
                            .rhs = undefined,
                        }
                    );
                    stack.push(State { .MultiplyExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.push(State { .CurlySuffixExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                    continue;
                } else {
                    putBackToken(&tok_it, &tree);
                    continue;
                }
            },

            State.CurlySuffixExpressionBegin => |opt_ctx| {
                stack.push(State { .CurlySuffixExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .IfToken = Token.Id.LBrace });
                try stack.push(State { .TypeExprBegin = opt_ctx });
                continue;
            },

            State.CurlySuffixExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                if ((??tok_it.peek()).id == Token.Id.Period) {
                    const node = try arena.construct(ast.Node.SuffixOp {
                        .base = ast.Node { .id = ast.Node.Id.SuffixOp },
                        .lhs = lhs,
                        .op = ast.Node.SuffixOp.Op {
                            .StructInitializer = ast.Node.SuffixOp.Op.InitList.init(arena),
                        },
                        .rtoken = undefined,
                    });
                    opt_ctx.store(&node.base);

                    stack.push(State { .CurlySuffixExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.push(State { .IfToken = Token.Id.LBrace });
                    try stack.push(State {
                        .FieldInitListItemOrEnd = ListSave(@typeOf(node.op.StructInitializer)) {
                            .list = &node.op.StructInitializer,
                            .ptr = &node.rtoken,
                        }
                    });
                    continue;
                }

                const node = try createToCtxNode(arena, opt_ctx, ast.Node.SuffixOp,
                    ast.Node.SuffixOp {
                        .base = undefined,
                        .lhs = lhs,
                        .op = ast.Node.SuffixOp.Op {
                            .ArrayInitializer = ast.Node.SuffixOp.Op.InitList.init(arena),
                        },
                        .rtoken = undefined,
                    }
                );
                stack.push(State { .CurlySuffixExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                try stack.push(State { .IfToken = Token.Id.LBrace });
                try stack.push(State {
                    .ExprListItemOrEnd = ExprListCtx {
                        .list = &node.op.ArrayInitializer,
                        .end = Token.Id.RBrace,
                        .ptr = &node.rtoken,
                    }
                });
                continue;
            },

            State.TypeExprBegin => |opt_ctx| {
                stack.push(State { .TypeExprEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .PrefixOpExpression = opt_ctx });
                continue;
            },

            State.TypeExprEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                if (eatToken(&tok_it, &tree, Token.Id.Bang)) |bang| {
                    const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                        ast.Node.InfixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op_token = bang,
                            .op = ast.Node.InfixOp.Op.ErrorUnion,
                            .rhs = undefined,
                        }
                    );
                    stack.push(State { .TypeExprEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.push(State { .PrefixOpExpression = OptionalCtx { .Required = &node.rhs } });
                    continue;
                }
            },

            State.PrefixOpExpression => |opt_ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (tokenIdToPrefixOp(token_ptr.id)) |prefix_id| {
                    var node = try createToCtxNode(arena, opt_ctx, ast.Node.PrefixOp,
                        ast.Node.PrefixOp {
                            .base = undefined,
                            .op_token = token_index,
                            .op = prefix_id,
                            .rhs = undefined,
                        }
                    );

                    // Treat '**' token as two derefs
                    if (token_ptr.id == Token.Id.AsteriskAsterisk) {
                        const child = try createNode(arena, ast.Node.PrefixOp,
                            ast.Node.PrefixOp {
                                .base = undefined,
                                .op_token = token_index,
                                .op = prefix_id,
                                .rhs = undefined,
                            }
                        );
                        node.rhs = &child.base;
                        node = child;
                    }

                    stack.push(State { .TypeExprBegin = OptionalCtx { .Required = &node.rhs } }) catch unreachable;
                    if (node.op == ast.Node.PrefixOp.Op.AddrOf) {
                        try stack.push(State { .AddrOfModifiers = &node.op.AddrOf });
                    }
                    continue;
                } else {
                    putBackToken(&tok_it, &tree);
                    stack.push(State { .SuffixOpExpressionBegin = opt_ctx }) catch unreachable;
                    continue;
                }
            },

            State.SuffixOpExpressionBegin => |opt_ctx| {
                if (eatToken(&tok_it, &tree, Token.Id.Keyword_async)) |async_token| {
                    const async_node = try createNode(arena, ast.Node.AsyncAttribute,
                        ast.Node.AsyncAttribute {
                            .base = undefined,
                            .async_token = async_token,
                            .allocator_type = null,
                            .rangle_bracket = null,
                        }
                    );
                    stack.push(State {
                        .AsyncEnd = AsyncEndCtx {
                            .ctx = opt_ctx,
                            .attribute = async_node,
                        }
                    }) catch unreachable;
                    try stack.push(State { .SuffixOpExpressionEnd = opt_ctx.toRequired() });
                    try stack.push(State { .PrimaryExpression = opt_ctx.toRequired() });
                    try stack.push(State { .AsyncAllocator = async_node });
                    continue;
                }

                stack.push(State { .SuffixOpExpressionEnd = opt_ctx }) catch unreachable;
                try stack.push(State { .PrimaryExpression = opt_ctx });
                continue;
            },

            State.SuffixOpExpressionEnd => |opt_ctx| {
                const lhs = opt_ctx.get() ?? continue;

                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                switch (token_ptr.id) {
                    Token.Id.LParen => {
                        const node = try createToCtxNode(arena, opt_ctx, ast.Node.SuffixOp,
                            ast.Node.SuffixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op = ast.Node.SuffixOp.Op {
                                    .Call = ast.Node.SuffixOp.Op.Call {
                                        .params = ast.Node.SuffixOp.Op.Call.ParamList.init(arena),
                                        .async_attr = null,
                                    }
                                },
                                .rtoken = undefined,
                            }
                        );
                        stack.push(State { .SuffixOpExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.push(State {
                            .ExprListItemOrEnd = ExprListCtx {
                                .list = &node.op.Call.params,
                                .end = Token.Id.RParen,
                                .ptr = &node.rtoken,
                            }
                        });
                        continue;
                    },
                    Token.Id.LBracket => {
                        const node = try createToCtxNode(arena, opt_ctx, ast.Node.SuffixOp,
                            ast.Node.SuffixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op = ast.Node.SuffixOp.Op {
                                    .ArrayAccess = undefined,
                                },
                                .rtoken = undefined
                            }
                        );
                        stack.push(State { .SuffixOpExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.push(State { .SliceOrArrayAccess = node });
                        try stack.push(State { .Expression = OptionalCtx { .Required = &node.op.ArrayAccess }});
                        continue;
                    },
                    Token.Id.Period => {
                        const node = try createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = token_index,
                                .op = ast.Node.InfixOp.Op.Period,
                                .rhs = undefined,
                            }
                        );
                        stack.push(State { .SuffixOpExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.push(State { .Identifier = OptionalCtx { .Required = &node.rhs } });
                        continue;
                    },
                    else => {
                        putBackToken(&tok_it, &tree);
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
                        const node = try arena.construct(ast.Node.PromiseType {
                            .base = ast.Node {
                                .id = ast.Node.Id.PromiseType,
                            },
                            .promise_token = token.index,
                            .result = null,
                        });
                        opt_ctx.store(&node.base);
                        const next_token = nextToken(&tok_it, &tree);
                        const next_token_index = next_token.index;
                        const next_token_ptr = next_token.ptr;
                        if (next_token_ptr.id != Token.Id.Arrow) {
                            putBackToken(&tok_it, &tree);
                            continue;
                        }
                        node.result = ast.Node.PromiseType.Result {
                            .arrow_token = next_token_index,
                            .return_type = undefined,
                        };
                        const return_type_ptr = &((??node.result).return_type);
                        try stack.push(State { .Expression = OptionalCtx { .Required = return_type_ptr, } });
                        continue;
                    },
                    Token.Id.StringLiteral, Token.Id.MultilineStringLiteralLine => {
                        opt_ctx.store((try parseStringLiteral(arena, &tok_it, token.ptr, token.index, &tree)) ?? unreachable);
                        continue;
                    },
                    Token.Id.LParen => {
                        const node = try createToCtxNode(arena, opt_ctx, ast.Node.GroupedExpression,
                            ast.Node.GroupedExpression {
                                .base = undefined,
                                .lparen = token.index,
                                .expr = undefined,
                                .rparen = undefined,
                            }
                        );
                        stack.push(State {
                            .ExpectTokenSave = ExpectTokenSave {
                                .id = Token.Id.RParen,
                                .ptr = &node.rparen,
                            }
                        }) catch unreachable;
                        try stack.push(State { .Expression = OptionalCtx { .Required = &node.expr } });
                        continue;
                    },
                    Token.Id.Builtin => {
                        const node = try createToCtxNode(arena, opt_ctx, ast.Node.BuiltinCall,
                            ast.Node.BuiltinCall {
                                .base = undefined,
                                .builtin_token = token.index,
                                .params = ast.Node.BuiltinCall.ParamList.init(arena),
                                .rparen_token = undefined,
                            }
                        );
                        stack.push(State {
                            .ExprListItemOrEnd = ExprListCtx {
                                .list = &node.params,
                                .end = Token.Id.RParen,
                                .ptr = &node.rparen_token,
                            }
                        }) catch unreachable;
                        try stack.push(State { .ExpectToken = Token.Id.LParen, });
                        continue;
                    },
                    Token.Id.LBracket => {
                        const node = try createToCtxNode(arena, opt_ctx, ast.Node.PrefixOp,
                            ast.Node.PrefixOp {
                                .base = undefined,
                                .op_token = token.index,
                                .op = undefined,
                                .rhs = undefined,
                            }
                        );
                        stack.push(State { .SliceOrArrayType = node }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_error => {
                        stack.push(State {
                            .ErrorTypeOrSetDecl = ErrorTypeOrSetDeclCtx {
                                .error_token = token.index,
                                .opt_ctx = opt_ctx
                            }
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_packed => {
                        stack.push(State {
                            .ContainerKind = ContainerKindCtx {
                                .opt_ctx = opt_ctx,
                                .ltoken = token.index,
                                .layout = ast.Node.ContainerDecl.Layout.Packed,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_extern => {
                        stack.push(State {
                            .ExternType = ExternTypeCtx {
                                .opt_ctx = opt_ctx,
                                .extern_token = token.index,
                                .comments = null,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_struct, Token.Id.Keyword_union, Token.Id.Keyword_enum => {
                        putBackToken(&tok_it, &tree);
                        stack.push(State {
                            .ContainerKind = ContainerKindCtx {
                                .opt_ctx = opt_ctx,
                                .ltoken = token.index,
                                .layout = ast.Node.ContainerDecl.Layout.Auto,
                            },
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Identifier => {
                        stack.push(State {
                            .MaybeLabeledExpression = MaybeLabeledExpressionCtx {
                                .label = token.index,
                                .opt_ctx = opt_ctx
                            }
                        }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_fn => {
                        const fn_proto = try arena.construct(ast.Node.FnProto {
                            .base = ast.Node {
                                .id = ast.Node.Id.FnProto,
                            },
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
                        stack.push(State { .FnProto = fn_proto }) catch unreachable;
                        continue;
                    },
                    Token.Id.Keyword_nakedcc, Token.Id.Keyword_stdcallcc => {
                        const fn_proto = try arena.construct(ast.Node.FnProto {
                            .base = ast.Node {
                                .id = ast.Node.Id.FnProto,
                            },
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
                        stack.push(State { .FnProto = fn_proto }) catch unreachable;
                        try stack.push(State {
                            .ExpectTokenSave = ExpectTokenSave {
                                .id = Token.Id.Keyword_fn,
                                .ptr = &fn_proto.fn_token
                            }
                        });
                        continue;
                    },
                    Token.Id.Keyword_asm => {
                        const node = try createToCtxNode(arena, opt_ctx, ast.Node.Asm,
                            ast.Node.Asm {
                                .base = undefined,
                                .asm_token = token.index,
                                .volatile_token = null,
                                .template = undefined,
                                .outputs = ast.Node.Asm.OutputList.init(arena),
                                .inputs = ast.Node.Asm.InputList.init(arena),
                                .clobbers = ast.Node.Asm.ClobberList.init(arena),
                                .rparen = undefined,
                            }
                        );
                        stack.push(State {
                            .ExpectTokenSave = ExpectTokenSave {
                                .id = Token.Id.RParen,
                                .ptr = &node.rparen,
                            }
                        }) catch unreachable;
                        try stack.push(State { .AsmClobberItems = &node.clobbers });
                        try stack.push(State { .IfToken = Token.Id.Colon });
                        try stack.push(State { .AsmInputItems = &node.inputs });
                        try stack.push(State { .IfToken = Token.Id.Colon });
                        try stack.push(State { .AsmOutputItems = &node.outputs });
                        try stack.push(State { .IfToken = Token.Id.Colon });
                        try stack.push(State { .StringLiteral = OptionalCtx { .Required = &node.template } });
                        try stack.push(State { .ExpectToken = Token.Id.LParen });
                        try stack.push(State {
                            .OptionalTokenSave = OptionalTokenSave {
                                .id = Token.Id.Keyword_volatile,
                                .ptr = &node.volatile_token,
                            }
                        });
                    },
                    Token.Id.Keyword_inline => {
                        stack.push(State {
                            .Inline = InlineCtx {
                                .label = null,
                                .inline_token = token.index,
                                .opt_ctx = opt_ctx,
                            }
                        }) catch unreachable;
                        continue;
                    },
                    else => {
                        if (!try parseBlockExpr(&stack, arena, opt_ctx, token.ptr, token.index)) {
                            putBackToken(&tok_it, &tree);
                            if (opt_ctx != OptionalCtx.Optional) {
                                *(try tree.errors.addOne()) = Error {
                                    .ExpectedPrimaryExpr = Error.ExpectedPrimaryExpr { .token = token.index },
                                };
                                return tree;
                            }
                        }
                        continue;
                    }
                }
            },


            State.ErrorTypeOrSetDecl => |ctx| {
                if (eatToken(&tok_it, &tree, Token.Id.LBrace) == null) {
                    _ = try createToCtxLiteral(arena, ctx.opt_ctx, ast.Node.ErrorType, ctx.error_token);
                    continue;
                }

                const node = try arena.construct(ast.Node.ErrorSetDecl {
                    .base = ast.Node {
                        .id = ast.Node.Id.ErrorSetDecl,
                    },
                    .error_token = ctx.error_token,
                    .decls = ast.Node.ErrorSetDecl.DeclList.init(arena),
                    .rbrace_token = undefined,
                });
                ctx.opt_ctx.store(&node.base);

                stack.push(State {
                    .ErrorTagListItemOrEnd = ListSave(@typeOf(node.decls)) {
                        .list = &node.decls,
                        .ptr = &node.rbrace_token,
                    }
                }) catch unreachable;
                continue;
            },
            State.StringLiteral => |opt_ctx| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                opt_ctx.store(
                    (try parseStringLiteral(arena, &tok_it, token_ptr, token_index, &tree)) ?? {
                        putBackToken(&tok_it, &tree);
                        if (opt_ctx != OptionalCtx.Optional) {
                            *(try tree.errors.addOne()) = Error {
                                .ExpectedPrimaryExpr = Error.ExpectedPrimaryExpr { .token = token_index },
                            };
                            return tree;
                        }

                        continue;
                    }
                );
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
                    *(try tree.errors.addOne()) = Error {
                        .ExpectedToken = Error.ExpectedToken {
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
                    *(try tree.errors.addOne()) = Error {
                        .ExpectedToken = Error.ExpectedToken {
                            .token = ident_token_index,
                            .expected_id = Token.Id.Identifier,
                        },
                    };
                    return tree;
                }

                const node = try arena.construct(ast.Node.ErrorTag {
                    .base = ast.Node {
                        .id = ast.Node.Id.ErrorTag,
                    },
                    .doc_comments = comments,
                    .name_token = ident_token_index,
                });
                *node_ptr = &node.base;
                continue;
            },

            State.ExpectToken => |token_id| {
                const token = nextToken(&tok_it, &tree);
                const token_index = token.index;
                const token_ptr = token.ptr;
                if (token_ptr.id != token_id) {
                    *(try tree.errors.addOne()) = Error {
                        .ExpectedToken = Error.ExpectedToken {
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
                    *(try tree.errors.addOne()) = Error {
                        .ExpectedToken = Error.ExpectedToken {
                            .token = token_index,
                            .expected_id = expect_token_save.id,
                        },
                    };
                    return tree;
                }
                *expect_token_save.ptr = token_index;
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
                    *if_token_save.ptr = token_index;
                    continue;
                }

                _ = stack.pop();
                continue;
            },
            State.OptionalTokenSave => |optional_token_save| {
                if (eatToken(&tok_it, &tree, optional_token_save.id)) |token_index| {
                    *optional_token_save.ptr = token_index;
                    continue;
                }

                continue;
            },
        }
    }
}

const AnnotatedToken = struct {
    ptr: &Token,
    index: TokenIndex,
};

const TopLevelDeclCtx = struct {
    decls: &ast.Node.Root.DeclList,
    visib_token: ?TokenIndex,
    extern_export_inline_token: ?AnnotatedToken,
    lib_name: ?&ast.Node,
    comments: ?&ast.Node.DocComment,
};

const VarDeclCtx = struct {
    mut_token: TokenIndex,
    visib_token: ?TokenIndex,
    comptime_token: ?TokenIndex,
    extern_export_token: ?TokenIndex,
    lib_name: ?&ast.Node,
    list: &ast.Node.Root.DeclList,
    comments: ?&ast.Node.DocComment,
};

const TopLevelExternOrFieldCtx = struct {
    visib_token: TokenIndex,
    container_decl: &ast.Node.ContainerDecl,
    comments: ?&ast.Node.DocComment,
};

const ExternTypeCtx = struct {
    opt_ctx: OptionalCtx,
    extern_token: TokenIndex,
    comments: ?&ast.Node.DocComment,
};

const ContainerKindCtx = struct {
    opt_ctx: OptionalCtx,
    ltoken: TokenIndex,
    layout: ast.Node.ContainerDecl.Layout,
};

const ExpectTokenSave = struct {
    id: @TagType(Token.Id),
    ptr: &TokenIndex,
};

const OptionalTokenSave = struct {
    id: @TagType(Token.Id),
    ptr: &?TokenIndex,
};

const ExprListCtx = struct {
    list: &ast.Node.SuffixOp.Op.InitList,
    end: Token.Id,
    ptr: &TokenIndex,
};

fn ListSave(comptime List: type) type {
    return struct {
        list: &List,
        ptr: &TokenIndex,
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
    attribute: &ast.Node.AsyncAttribute,
};

const ErrorTypeOrSetDeclCtx = struct {
    opt_ctx: OptionalCtx,
    error_token: TokenIndex,
};

const ParamDeclEndCtx = struct {
    fn_proto: &ast.Node.FnProto,
    param_decl: &ast.Node.ParamDecl,
};

const ComptimeStatementCtx = struct {
    comptime_token: TokenIndex,
    block: &ast.Node.Block,
};

const OptionalCtx = union(enum) {
    Optional: &?&ast.Node,
    RequiredNull: &?&ast.Node,
    Required: &&ast.Node,

    pub fn store(self: &const OptionalCtx, value: &ast.Node) void {
        switch (*self) {
            OptionalCtx.Optional => |ptr| *ptr = value,
            OptionalCtx.RequiredNull => |ptr| *ptr = value,
            OptionalCtx.Required => |ptr| *ptr = value,
        }
    }

    pub fn get(self: &const OptionalCtx) ?&ast.Node {
        switch (*self) {
            OptionalCtx.Optional => |ptr| return *ptr,
            OptionalCtx.RequiredNull => |ptr| return ??*ptr,
            OptionalCtx.Required => |ptr| return *ptr,
        }
    }

    pub fn toRequired(self: &const OptionalCtx) OptionalCtx {
        switch (*self) {
            OptionalCtx.Optional => |ptr| {
                return OptionalCtx { .RequiredNull = ptr };
            },
            OptionalCtx.RequiredNull => |ptr| return *self,
            OptionalCtx.Required => |ptr| return *self,
        }
    }
};

const AddCommentsCtx = struct {
    node_ptr: &&ast.Node,
    comments: ?&ast.Node.DocComment,
};

const State = union(enum) {
    TopLevel,
    TopLevelExtern: TopLevelDeclCtx,
    TopLevelLibname: TopLevelDeclCtx,
    TopLevelDecl: TopLevelDeclCtx,
    TopLevelExternOrField: TopLevelExternOrFieldCtx,

    ContainerKind: ContainerKindCtx,
    ContainerInitArgStart: &ast.Node.ContainerDecl,
    ContainerInitArg: &ast.Node.ContainerDecl,
    ContainerDecl: &ast.Node.ContainerDecl,

    VarDecl: VarDeclCtx,
    VarDeclAlign: &ast.Node.VarDecl,
    VarDeclEq: &ast.Node.VarDecl,

    FnDef: &ast.Node.FnProto,
    FnProto: &ast.Node.FnProto,
    FnProtoAlign: &ast.Node.FnProto,
    FnProtoReturnType: &ast.Node.FnProto,

    ParamDecl: &ast.Node.FnProto,
    ParamDeclAliasOrComptime: &ast.Node.ParamDecl,
    ParamDeclName: &ast.Node.ParamDecl,
    ParamDeclEnd: ParamDeclEndCtx,
    ParamDeclComma: &ast.Node.FnProto,

    MaybeLabeledExpression: MaybeLabeledExpressionCtx,
    LabeledExpression: LabelCtx,
    Inline: InlineCtx,
    While: LoopCtx,
    WhileContinueExpr: &?&ast.Node,
    For: LoopCtx,
    Else: &?&ast.Node.Else,

    Block: &ast.Node.Block,
    Statement: &ast.Node.Block,
    ComptimeStatement: ComptimeStatementCtx,
    Semicolon: &&ast.Node,

    AsmOutputItems: &ast.Node.Asm.OutputList,
    AsmOutputReturnOrType: &ast.Node.AsmOutput,
    AsmInputItems: &ast.Node.Asm.InputList,
    AsmClobberItems: &ast.Node.Asm.ClobberList,

    ExprListItemOrEnd: ExprListCtx,
    ExprListCommaOrEnd: ExprListCtx,
    FieldInitListItemOrEnd: ListSave(ast.Node.SuffixOp.Op.InitList),
    FieldInitListCommaOrEnd: ListSave(ast.Node.SuffixOp.Op.InitList),
    FieldListCommaOrEnd: &ast.Node.ContainerDecl,
    FieldInitValue: OptionalCtx,
    ErrorTagListItemOrEnd: ListSave(ast.Node.ErrorSetDecl.DeclList),
    ErrorTagListCommaOrEnd: ListSave(ast.Node.ErrorSetDecl.DeclList),
    SwitchCaseOrEnd: ListSave(ast.Node.Switch.CaseList),
    SwitchCaseCommaOrEnd: ListSave(ast.Node.Switch.CaseList),
    SwitchCaseFirstItem: &ast.Node.SwitchCase.ItemList,
    SwitchCaseItem: &ast.Node.SwitchCase.ItemList,
    SwitchCaseItemCommaOrEnd: &ast.Node.SwitchCase.ItemList,

    SuspendBody: &ast.Node.Suspend,
    AsyncAllocator: &ast.Node.AsyncAttribute,
    AsyncEnd: AsyncEndCtx,

    ExternType: ExternTypeCtx,
    SliceOrArrayAccess: &ast.Node.SuffixOp,
    SliceOrArrayType: &ast.Node.PrefixOp,
    AddrOfModifiers: &ast.Node.PrefixOp.AddrOfInfo,

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
    ErrorTag: &&ast.Node,


    IfToken: @TagType(Token.Id),
    IfTokenSave: ExpectTokenSave,
    ExpectToken: @TagType(Token.Id),
    ExpectTokenSave: ExpectTokenSave,
    OptionalTokenSave: OptionalTokenSave,
};

fn eatDocComments(arena: &mem.Allocator, tok_it: &ast.Tree.TokenList.Iterator, tree: &ast.Tree) !?&ast.Node.DocComment {
    var result: ?&ast.Node.DocComment = null;
    while (true) {
        if (eatToken(tok_it, tree, Token.Id.DocComment)) |line_comment| {
            const node = blk: {
                if (result) |comment_node| {
                    break :blk comment_node;
                } else {
                    const comment_node = try arena.construct(ast.Node.DocComment {
                        .base = ast.Node {
                            .id = ast.Node.Id.DocComment,
                        },
                        .lines = ast.Node.DocComment.LineList.init(arena),
                    });
                    result = comment_node;
                    break :blk comment_node;
                }
            };
            try node.lines.push(line_comment);
            continue;
        }
        break;
    }
    return result;
}

fn eatLineComment(arena: &mem.Allocator, tok_it: &ast.Tree.TokenList.Iterator, tree: &ast.Tree) !?&ast.Node.LineComment {
    const token = eatToken(tok_it, tree, Token.Id.LineComment) ?? return null;
    return try arena.construct(ast.Node.LineComment {
        .base = ast.Node {
            .id = ast.Node.Id.LineComment,
        },
        .token = token,
    });
}

fn parseStringLiteral(arena: &mem.Allocator, tok_it: &ast.Tree.TokenList.Iterator,
    token_ptr: &const Token, token_index: TokenIndex, tree: &ast.Tree) !?&ast.Node
{
    switch (token_ptr.id) {
        Token.Id.StringLiteral => {
            return &(try createLiteral(arena, ast.Node.StringLiteral, token_index)).base;
        },
        Token.Id.MultilineStringLiteralLine => {
            const node = try arena.construct(ast.Node.MultilineStringLiteral {
                .base = ast.Node { .id = ast.Node.Id.MultilineStringLiteral },
                .lines = ast.Node.MultilineStringLiteral.LineList.init(arena),
            });
            try node.lines.push(token_index);
            while (true) {
                const multiline_str = nextToken(tok_it, tree);
                const multiline_str_index = multiline_str.index;
                const multiline_str_ptr = multiline_str.ptr;
                if (multiline_str_ptr.id != Token.Id.MultilineStringLiteralLine) {
                    putBackToken(tok_it, tree);
                    break;
                }

                try node.lines.push(multiline_str_index);
            }

            return &node.base;
        },
        // TODO: We shouldn't need a cast, but:
        // zig: /home/jc/Documents/zig/src/ir.cpp:7962: TypeTableEntry* ir_resolve_peer_types(IrAnalyze*, AstNode*, IrInstruction**, size_t): Assertion `err_set_type != nullptr' failed.
        else => return (?&ast.Node)(null),
    }
}

fn parseBlockExpr(stack: &SegmentedList(State, 32), arena: &mem.Allocator, ctx: &const OptionalCtx,
    token_ptr: &const Token, token_index: TokenIndex) !bool {
    switch (token_ptr.id) {
        Token.Id.Keyword_suspend => {
            const node = try createToCtxNode(arena, ctx, ast.Node.Suspend,
                ast.Node.Suspend {
                    .base = undefined,
                    .label = null,
                    .suspend_token = token_index,
                    .payload = null,
                    .body = null,
                }
            );

            stack.push(State { .SuspendBody = node }) catch unreachable;
            try stack.push(State { .Payload = OptionalCtx { .Optional = &node.payload } });
            return true;
        },
        Token.Id.Keyword_if => {
            const node = try createToCtxNode(arena, ctx, ast.Node.If,
                ast.Node.If {
                    .base = undefined,
                    .if_token = token_index,
                    .condition = undefined,
                    .payload = null,
                    .body = undefined,
                    .@"else" = null,
                }
            );

            stack.push(State { .Else = &node.@"else" }) catch unreachable;
            try stack.push(State { .Expression = OptionalCtx { .Required = &node.body } });
            try stack.push(State { .PointerPayload = OptionalCtx { .Optional = &node.payload } });
            try stack.push(State { .ExpectToken = Token.Id.RParen });
            try stack.push(State { .Expression = OptionalCtx { .Required = &node.condition } });
            try stack.push(State { .ExpectToken = Token.Id.LParen });
            return true;
        },
        Token.Id.Keyword_while => {
            stack.push(State {
                .While = LoopCtx {
                    .label = null,
                    .inline_token = null,
                    .loop_token = token_index,
                    .opt_ctx = *ctx,
                }
            }) catch unreachable;
            return true;
        },
        Token.Id.Keyword_for => {
            stack.push(State {
                .For = LoopCtx {
                    .label = null,
                    .inline_token = null,
                    .loop_token = token_index,
                    .opt_ctx = *ctx,
                }
            }) catch unreachable;
            return true;
        },
        Token.Id.Keyword_switch => {
            const node = try arena.construct(ast.Node.Switch {
                .base = ast.Node {
                    .id = ast.Node.Id.Switch,
                },
                .switch_token = token_index,
                .expr = undefined,
                .cases = ast.Node.Switch.CaseList.init(arena),
                .rbrace = undefined,
            });
            ctx.store(&node.base);

            stack.push(State {
                .SwitchCaseOrEnd = ListSave(@typeOf(node.cases)) {
                    .list = &node.cases,
                    .ptr = &node.rbrace,
                },
            }) catch unreachable;
            try stack.push(State { .ExpectToken = Token.Id.LBrace });
            try stack.push(State { .ExpectToken = Token.Id.RParen });
            try stack.push(State { .Expression = OptionalCtx { .Required = &node.expr } });
            try stack.push(State { .ExpectToken = Token.Id.LParen });
            return true;
        },
        Token.Id.Keyword_comptime => {
            const node = try createToCtxNode(arena, ctx, ast.Node.Comptime,
                ast.Node.Comptime {
                    .base = undefined,
                    .comptime_token = token_index,
                    .expr = undefined,
                    .doc_comments = null,
                }
            );
            try stack.push(State { .Expression = OptionalCtx { .Required = &node.expr } });
            return true;
        },
        Token.Id.LBrace => {
            const block = try arena.construct(ast.Node.Block {
                .base = ast.Node {.id = ast.Node.Id.Block },
                .label = null,
                .lbrace = token_index,
                .statements = ast.Node.Block.StatementList.init(arena),
                .rbrace = undefined,
            });
            ctx.store(&block.base);
            stack.push(State { .Block = block }) catch unreachable;
            return true;
        },
        else => {
            return false;
        }
    }
}

const ExpectCommaOrEndResult = union(enum) {
    end_token: ?TokenIndex,
    parse_error: Error,
};

fn expectCommaOrEnd(tok_it: &ast.Tree.TokenList.Iterator, tree: &ast.Tree, end: @TagType(Token.Id)) ExpectCommaOrEndResult {
    const token = nextToken(tok_it, tree);
    const token_index = token.index;
    const token_ptr = token.ptr;
    switch (token_ptr.id) {
        Token.Id.Comma => return ExpectCommaOrEndResult { .end_token = null},
        else => {
            if (end == token_ptr.id) {
                return ExpectCommaOrEndResult { .end_token = token_index };
            }

            return ExpectCommaOrEndResult {
                .parse_error = Error {
                    .ExpectedCommaOrEnd = Error.ExpectedCommaOrEnd {
                        .token = token_index,
                        .end_id = end,
                    },
                },
            };
        },
    }
}

fn tokenIdToAssignment(id: &const Token.Id) ?ast.Node.InfixOp.Op {
    // TODO: We have to cast all cases because of this:
    // error: expected type '?InfixOp', found '?@TagType(InfixOp)'
    return switch (*id) {
        Token.Id.AmpersandEqual => ast.Node.InfixOp.Op { .AssignBitAnd = {} },
        Token.Id.AngleBracketAngleBracketLeftEqual => ast.Node.InfixOp.Op { .AssignBitShiftLeft = {} },
        Token.Id.AngleBracketAngleBracketRightEqual => ast.Node.InfixOp.Op { .AssignBitShiftRight = {} },
        Token.Id.AsteriskEqual => ast.Node.InfixOp.Op { .AssignTimes = {} },
        Token.Id.AsteriskPercentEqual => ast.Node.InfixOp.Op { .AssignTimesWarp = {} },
        Token.Id.CaretEqual => ast.Node.InfixOp.Op { .AssignBitXor = {} },
        Token.Id.Equal => ast.Node.InfixOp.Op { .Assign = {} },
        Token.Id.MinusEqual => ast.Node.InfixOp.Op { .AssignMinus = {} },
        Token.Id.MinusPercentEqual => ast.Node.InfixOp.Op { .AssignMinusWrap = {} },
        Token.Id.PercentEqual => ast.Node.InfixOp.Op { .AssignMod = {} },
        Token.Id.PipeEqual => ast.Node.InfixOp.Op { .AssignBitOr = {} },
        Token.Id.PlusEqual => ast.Node.InfixOp.Op { .AssignPlus = {} },
        Token.Id.PlusPercentEqual => ast.Node.InfixOp.Op { .AssignPlusWrap = {} },
        Token.Id.SlashEqual => ast.Node.InfixOp.Op { .AssignDiv = {} },
        else => null,
    };
}

fn tokenIdToUnwrapExpr(id: @TagType(Token.Id)) ?ast.Node.InfixOp.Op {
    return switch (id) {
        Token.Id.Keyword_catch => ast.Node.InfixOp.Op { .Catch = null },
        Token.Id.QuestionMarkQuestionMark => ast.Node.InfixOp.Op { .UnwrapMaybe = void{} },
        else => null,
    };
}

fn tokenIdToComparison(id: @TagType(Token.Id)) ?ast.Node.InfixOp.Op {
    return switch (id) {
        Token.Id.BangEqual => ast.Node.InfixOp.Op { .BangEqual = void{} },
        Token.Id.EqualEqual => ast.Node.InfixOp.Op { .EqualEqual = void{} },
        Token.Id.AngleBracketLeft => ast.Node.InfixOp.Op { .LessThan = void{} },
        Token.Id.AngleBracketLeftEqual => ast.Node.InfixOp.Op { .LessOrEqual = void{} },
        Token.Id.AngleBracketRight => ast.Node.InfixOp.Op { .GreaterThan = void{} },
        Token.Id.AngleBracketRightEqual => ast.Node.InfixOp.Op { .GreaterOrEqual = void{} },
        else => null,
    };
}

fn tokenIdToBitShift(id: @TagType(Token.Id)) ?ast.Node.InfixOp.Op {
    return switch (id) {
        Token.Id.AngleBracketAngleBracketLeft => ast.Node.InfixOp.Op { .BitShiftLeft = void{} },
        Token.Id.AngleBracketAngleBracketRight => ast.Node.InfixOp.Op { .BitShiftRight = void{} },
        else => null,
    };
}

fn tokenIdToAddition(id: @TagType(Token.Id)) ?ast.Node.InfixOp.Op {
    return switch (id) {
        Token.Id.Minus => ast.Node.InfixOp.Op { .Sub = void{} },
        Token.Id.MinusPercent => ast.Node.InfixOp.Op { .SubWrap = void{} },
        Token.Id.Plus => ast.Node.InfixOp.Op { .Add = void{} },
        Token.Id.PlusPercent => ast.Node.InfixOp.Op { .AddWrap = void{} },
        Token.Id.PlusPlus => ast.Node.InfixOp.Op { .ArrayCat = void{} },
        else => null,
    };
}

fn tokenIdToMultiply(id: @TagType(Token.Id)) ?ast.Node.InfixOp.Op {
    return switch (id) {
        Token.Id.Slash => ast.Node.InfixOp.Op { .Div = void{} },
        Token.Id.Asterisk => ast.Node.InfixOp.Op { .Mult = void{} },
        Token.Id.AsteriskAsterisk => ast.Node.InfixOp.Op { .ArrayMult = void{} },
        Token.Id.AsteriskPercent => ast.Node.InfixOp.Op { .MultWrap = void{} },
        Token.Id.Percent => ast.Node.InfixOp.Op { .Mod = void{} },
        Token.Id.PipePipe => ast.Node.InfixOp.Op { .MergeErrorSets = void{} },
        else => null,
    };
}

fn tokenIdToPrefixOp(id: @TagType(Token.Id)) ?ast.Node.PrefixOp.Op {
    return switch (id) {
        Token.Id.Bang => ast.Node.PrefixOp.Op { .BoolNot = void{} },
        Token.Id.Tilde => ast.Node.PrefixOp.Op { .BitNot = void{} },
        Token.Id.Minus => ast.Node.PrefixOp.Op { .Negation = void{} },
        Token.Id.MinusPercent => ast.Node.PrefixOp.Op { .NegationWrap = void{} },
        Token.Id.Asterisk, Token.Id.AsteriskAsterisk => ast.Node.PrefixOp.Op { .Deref = void{} },
        Token.Id.Ampersand => ast.Node.PrefixOp.Op {
            .AddrOf = ast.Node.PrefixOp.AddrOfInfo {
                .align_expr = null,
                .bit_offset_start_token = null,
                .bit_offset_end_token = null,
                .const_token = null,
                .volatile_token = null,
            },
        },
        Token.Id.QuestionMark => ast.Node.PrefixOp.Op { .MaybeType = void{} },
        Token.Id.QuestionMarkQuestionMark => ast.Node.PrefixOp.Op { .UnwrapMaybe = void{} },
        Token.Id.Keyword_await => ast.Node.PrefixOp.Op { .Await = void{} },
        Token.Id.Keyword_try => ast.Node.PrefixOp.Op { .Try = void{ } },
        else => null,
    };
}

fn createNode(arena: &mem.Allocator, comptime T: type, init_to: &const T) !&T {
    const node = try arena.create(T);
    *node = *init_to;
    node.base = blk: {
        const id = ast.Node.typeToId(T);
        break :blk ast.Node {
            .id = id,
        };
    };

    return node;
}

fn createToCtxNode(arena: &mem.Allocator, opt_ctx: &const OptionalCtx, comptime T: type, init_to: &const T) !&T {
    const node = try createNode(arena, T, init_to);
    opt_ctx.store(&node.base);

    return node;
}

fn createLiteral(arena: &mem.Allocator, comptime T: type, token_index: TokenIndex) !&T {
    return createNode(arena, T,
        T {
            .base = undefined,
            .token = token_index,
        }
    );
}

fn createToCtxLiteral(arena: &mem.Allocator, opt_ctx: &const OptionalCtx, comptime T: type, token_index: TokenIndex) !&T {
    const node = try createLiteral(arena, T, token_index);
    opt_ctx.store(&node.base);

    return node;
}

fn eatToken(tok_it: &ast.Tree.TokenList.Iterator, tree: &ast.Tree, id: @TagType(Token.Id)) ?TokenIndex {
    const token = nextToken(tok_it, tree);

    if (token.ptr.id == id)
        return token.index;

    putBackToken(tok_it, tree);
    return null;
}

fn nextToken(tok_it: &ast.Tree.TokenList.Iterator, tree: &ast.Tree) AnnotatedToken {
    const result = AnnotatedToken {
        .index = tok_it.index,
        .ptr = ??tok_it.next(),
    };
    // possibly skip a following same line token
    const token = tok_it.next() ?? return result;
    if (token.id != Token.Id.LineComment) {
        putBackToken(tok_it, tree);
        return result;
    }
    const loc = tree.tokenLocationPtr(result.ptr.end, token);
    if (loc.line != 0) {
        putBackToken(tok_it, tree);
    }
    return result;
}

fn putBackToken(tok_it: &ast.Tree.TokenList.Iterator, tree: &ast.Tree) void {
    const prev_tok = ??tok_it.prev();
    if (prev_tok.id == Token.Id.LineComment) {
        const minus2_tok = tok_it.prev() ?? return;
        const loc = tree.tokenLocationPtr(minus2_tok.end, prev_tok);
        if (loc.line != 0) {
            _ = tok_it.next();
        }
    }
}

const RenderAstFrame = struct {
    node: &ast.Node,
    indent: usize,
};

pub fn renderAst(allocator: &mem.Allocator, tree: &const ast.Tree, stream: var) !void {
    var stack = SegmentedList(State, 32).init(allocator);
    defer stack.deinit();

    try stack.push(RenderAstFrame {
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
            try stack.push(RenderAstFrame {
                .node = child,
                .indent = frame.indent + 2,
            });
        }
    }
}

test "std.zig.parser" {
    _ = @import("parser_test.zig");
}
