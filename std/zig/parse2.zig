const std = @import("../std.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ast = std.zig.ast;
const Node = ast.Node;
const Tree = ast.Tree;
const Error = ast.Error;
const TokenIndex = ast.TokenIndex;
const Token = std.zig.Token;
const TokenIterator = Tree.TokenList.Iterator;

pub fn parse(allocator: *Allocator, source: []const u8) !Tree {
    var tree_arena = std.heap.ArenaAllocator.init(allocator);
    errdefer tree_arena.deinit();
    const arena = &tree_arena.allocator;

    var token_list = Tree.TokenList.init(arena);
    var tokenizer = std.zig.Tokenizer.init(source);
    while (true) {
        const tree_token = try token_list.addOne();
        tree_token.* = tokenizer.next();
        if (tree_token.id == .Eof) break;
    }
    var it = token_list.iterator(0);

    while (it.peek().?.id == .LineComment) _ = it.next();

    var tree = Tree{
        .source = source,
        .root_node = undefined,
        .tokens = token_list,
        .errors = Tree.ErrorList.init(arena),
        // TODO: Remove (not used/needed anywhere)
        .arena_allocator = undefined,
    };

    tree.root_node = try parseRoot(arena, &it, &tree);

    return tree;
}

// Root <- skip ContainerMembers eof
fn parseRoot(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node.Root {
    const node = try arena.create(Node.Root);
    node.* = Node.Root{
        .base = Node{ .id = .Root },
        .decls = undefined,
        .doc_comments = null,
        .shebang = null,
        .eof_token = undefined,
    };
    node.decls = (try parseContainerMembers(arena, it, tree, .Keyword_struct)) orelse return node;
    node.eof_token = eatToken(it, .Eof) orelse unreachable;
    return node;
}

// ContainerMembers
//     <- TestDecl ContainerMembers
//      / TopLevelComptime ContainerMembers
//      / KEYWORD_pub? TopLevelDecl ContainerMembers
//      / KEYWORD_pub? ContainerField COMMA ContainerMembers
//      / KEYWORD_pub? ContainerField
//      /
fn parseContainerMembers(arena: *Allocator, it: *TokenIterator, tree: *Tree, kind: Token.Id) !?Node.Root.DeclList {
    var list = Node.Root.DeclList.init(arena);

    while (true) {
        if (try parseTestDecl(arena, it, tree)) |node| {
            try list.push(node);
            continue;
        }

        if (try parseTopLevelComptime(arena, it, tree)) |node| {
            try list.push(node);
            continue;
        }

        const visibility_token = eatToken(it, .Keyword_pub);

        if (try parseTopLevelDecl(arena, it, tree, visibility_token)) |node| {
            try list.push(node);
            continue;
        }

        if (try parseContainerField(arena, it, tree, kind)) |node| {
            if (node.cast(Node.StructField)) |struct_field| struct_field.visib_token = visibility_token;
            try list.push(node);
            if (eatToken(it, .Comma)) |_| continue else break;
        }

        // Dangling pub
        if (visibility_token != null) {
            try tree.errors.push(Error{
                .ExpectedPubItem = Error.ExpectedPubItem{ .token = it.peek().?.start },
            });
            return null;
        }

        break;
    }

    return list;
}

// TestDecl <- KEYWORD_test STRINGLITERAL Block
fn parseTestDecl(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const test_token = eatToken(it, .Keyword_test) orelse return null;
    const name_node = (try expectNode(arena, it, tree, parseStringLiteral, Error{
        .ExpectedStringLiteral = Error.ExpectedStringLiteral{ .token = it.peek().?.start },
    })) orelse return null;
    const block_node = (try expectNode(
        arena,
        it,
        tree,
        parseBlock,
        Error{ .ExpectedLBrace = Error.ExpectedLBrace{ .token = it.peek().?.start } },
    )) orelse return null;

    const test_node = try arena.create(Node.TestDecl);
    test_node.* = Node.TestDecl{
        .base = Node{ .id = .TestDecl },
        .doc_comments = null,
        .test_token = test_token,
        .name = name_node,
        .body_node = block_node,
    };
    return &test_node.base;
}

// TopLevelComptime <- KEYWORD_comptime BlockExpr
fn parseTopLevelComptime(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const tok = eatToken(it, .Keyword_comptime) orelse return null;
    const block_node = (try expectNode(arena, it, tree, parseBlockExpr, Error{
        .ExpectedLabelOrLBrace = Error.ExpectedLabelOrLBrace{ .token = it.peek().?.start },
    })) orelse return null;

    const comptime_node = try arena.create(Node.Comptime);
    comptime_node.* = Node.Comptime{
        .base = Node{ .id = .Comptime },
        .doc_comments = null,
        .comptime_token = tok,
        .expr = block_node,
    };
    return &comptime_node.base;
}

// TopLevelDecl
//     <- (KEYWORD_export / KEYWORD_extern STRINGLITERAL? / KEYWORD_inline)? FnProto (SEMICOLON / Block)
//      / (KEYWORD_export / KEYWORD_extern STRINGLITERAL?)? KEYWORD_threadlocal? VarDecl
//      / KEYWORD_use Expr SEMICOLON
fn parseTopLevelDecl(arena: *Allocator, it: *TokenIterator, tree: *Tree, vis: ?TokenIndex) !?*Node {
    const export_token = eatToken(it, .Keyword_export);
    const extern_token = if (export_token == null) eatToken(it, .Keyword_extern) else null;
    const lib_name = if (extern_token != null) try parseStringLiteral(arena, it, tree) else null;
    const inline_token = if (extern_token == null) eatToken(it, .Keyword_inline) else null;

    if (try parseFnProto(arena, it, tree)) |node| {
        const fn_node = node.cast(Node.FnProto).?;

        fn_node.*.visib_token = vis;
        fn_node.*.extern_export_inline_token = export_token orelse extern_token orelse inline_token;
        fn_node.*.lib_name = lib_name;

        if (eatToken(it, .Semicolon)) |_| return node;
        if (try parseBlock(arena, it, tree)) |body_node| {
            fn_node.body_node = body_node;
            return node;
        }

        try tree.errors.push(Error{
            .ExpectedSemiOrLBrace = Error.ExpectedSemiOrLBrace{ .token = it.peek().?.start },
        });
        return null;
    }

    if (inline_token != null) return null;

    const thread_local_token = eatToken(it, .Keyword_threadlocal);

    if (try parseVarDecl(arena, it, tree)) |node| {
        var var_decl = node.cast(Node.VarDecl).?;
        var_decl.*.doc_comments = null;
        var_decl.*.visib_token = vis;
        var_decl.*.thread_local_token = thread_local_token;
        var_decl.*.comptime_token = null;
        var_decl.*.extern_export_token = export_token orelse extern_token;
        var_decl.*.lib_name = lib_name;
        return node;
    }

    const use_node = (try parseUse(arena, it, tree)) orelse return null;
    const expr_node = (try expectNode(arena, it, tree, parseExpr, Error{
        .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
    })) orelse return null;
    const semicolon_token = (try expectToken(it, tree, .Semicolon)) orelse return null;
    const use_node_raw = use_node.cast(Node.Use).?;
    use_node_raw.*.visib_token = vis;
    use_node_raw.*.expr = expr_node;
    use_node_raw.*.semicolon_token = semicolon_token;

    return use_node;
}

// FnProto <- FnCC? KEYWORD_fn IDENTIFIER? LPAREN ParamDeclList RPAREN ByteAlign? LinkSection? EXCLAMATIONMARK? (KEYWORD_var / TypeExpr)
fn parseFnProto(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const cc = (try parseFnCC(arena, it, tree)) orelse return null; // null on parse error
    const fn_token = eatToken(it, .Keyword_fn) orelse return null;
    const name_token = eatToken(it, .Identifier);
    const lparen = (try expectToken(it, tree, .LParen)) orelse return null;
    const params = try parseParamDeclList(arena, it, tree);
    const rparen = (try expectToken(it, tree, .RParen)) orelse return null;
    const alignment_node = try parseByteAlign(arena, it, tree);
    const section_expr = try parseLinkSection(arena, it, tree);
    const exclamation_token = eatToken(it, .Bang);

    const return_type_expr = blk: {
        if (eatToken(it, .Keyword_var)) |var_token| {
            const node = try arena.create(Node.VarType);
            node.* = Node.VarType{
                .base = Node{ .id = .VarType },
                .token = var_token,
            };
        }
        break :blk (try expectNode(arena, it, tree, parseTypeExpr, Error{
            .ExpectedReturnType = Error.ExpectedReturnType{ .token = it.peek().?.start },
        })) orelse return null;
    };

    // TODO: Based on this rule, `!var` is an acceptable return type, but there is no usage
    // or coverage of that yet. The grammar also does not include `Keyword_var` as a choice
    // for PrimaryTypeExpr, but the iterative stage2 parser treats it as one, which actually
    // makes more sense given the return type rule above. Clarify this with @Hejsil.
    // Alternative rule, if `var` were to be included in PrimaryTypeExpr (I think):
    //
    // - FnProto <- FnCC? KEYWORD_fn IDENTIFIER? LPAREN ParamDeclList RPAREN ByteAlign? LinkSection? EXCLAMATIONMARK? (KEYWORD_var / TypeExpr)
    // + FnProto <- FnCC? KEYWORD_fn IDENTIFIER? LPAREN ParamDeclList RPAREN ByteAlign? LinkSection? EXCLAMATIONMARK? TypeExpr
    const return_type = if (exclamation_token != null)
        Node.FnProto.ReturnType{
            .InferErrorSet = return_type_expr,
        }
    else
        Node.FnProto.ReturnType{
            .Explicit = return_type_expr,
        };

    const fn_proto_node = try arena.create(Node.FnProto);
    fn_proto_node.* = Node.FnProto{
        .base = Node{ .id = .FnProto },
        .doc_comments = null,
        .visib_token = null,
        .fn_token = fn_token,
        .name_token = name_token,
        .params = params,
        .return_type = return_type,
        .var_args_token = undefined, // TODO ?TokenIndex
        .extern_export_inline_token = null,
        .cc_token = null,
        .async_attr = null,
        .body_node = null,
        .lib_name = null,
        .align_expr = null,
        .section_expr = section_expr,
    };

    switch (cc) {
        .CC => |token| fn_proto_node.cc_token = token,
        .Extern => |token| fn_proto_node.extern_export_inline_token = token,
        .Async => |node| fn_proto_node.async_attr = node,
        .None => {},
    }

    return &fn_proto_node.base;
}

// VarDecl <- (KEYWORD_const / KEYWORD_var) IDENTIFIER (COLON TypeExpr)? ByteAlign? LinkSection? (EQUAL Expr)? SEMICOLON
fn parseVarDecl(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const mut_token = eatToken(it, .Keyword_const) orelse
        eatToken(it, .Keyword_var) orelse
        return null;

    const name_token = (try expectToken(it, tree, .Identifier)) orelse return null;
    const type_node = blk: {
        if (eatToken(it, .Colon)) |_| {
            break :blk (try expectNode(arena, it, tree, parseTypeExpr, Error{
                .ExpectedTypeExpr = Error.ExpectedTypeExpr{ .token = it.peek().?.start },
            })) orelse return null;
        } else break :blk null;
    };
    const align_node = try parseByteAlign(arena, it, tree);
    const section_node = try parseLinkSection(arena, it, tree);
    const eq_token = eatToken(it, .Equal);
    const init_node = blk: {
        if (eq_token) |_| {
            break :blk (try expectNode(arena, it, tree, parseExpr, Error{
                .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
            })) orelse return null;
        } else break :blk null;
    };
    const semicolon_token = (try expectToken(it, tree, .Semicolon)) orelse return null;

    const node = try arena.create(Node.VarDecl);
    node.* = Node.VarDecl{
        .base = Node{ .id = .VarDecl },
        .mut_token = mut_token,
        .name_token = name_token,
        .eq_token = eq_token orelse 0,
        .type_node = type_node,
        .align_node = align_node,
        .section_node = section_node,
        .init_node = init_node,
        .semicolon_token = semicolon_token,
        // set by caller
        .doc_comments = null,
        .visib_token = null,
        .thread_local_token = null,
        .comptime_token = null,
        .extern_export_token = null,
        .lib_name = null,
    };

    return &node.base;
}

// ContainerField <- IDENTIFIER (COLON TypeExpr)? (EQUAL Expr)?
fn parseContainerField(arena: *Allocator, it: *TokenIterator, tree: *Tree, kind: Token.Id) !?*Node {
    const name_token = eatToken(it, .Identifier) orelse return null;

    const type_expr = blk: {
        if (eatToken(it, .Colon)) |_| {
            break :blk (try expectNode(arena, it, tree, parseTypeExpr, Error{
                .ExpectedTypeExpr = Error.ExpectedTypeExpr{ .token = it.peek().?.start },
            })) orelse return null;
        } else break :blk null;
    };

    // TODO: supply default value to struct field when ast.Node.StructField supports it
    const default_value = blk: {
        if (eatToken(it, .Equal)) |_| {
            break :blk (try expectNode(arena, it, tree, parseExpr, Error{
                .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
            }));
        } else break :blk null;
    };

    switch (kind) {
        .Keyword_struct => {
            const node = try arena.create(Node.StructField);
            node.* = Node.StructField{
                .base = Node{ .id = .StructField },
                .name_token = name_token,
                .type_expr = type_expr orelse undefined,
                .doc_comments = null,
                .visib_token = null,
            };
            return &node.base;
        },
        .Keyword_union => {
            const node = try arena.create(Node.UnionTag);
            node.* = Node.UnionTag{
                .base = Node{ .id = .UnionTag },
                .doc_comments = null,
                .name_token = name_token,
                .type_expr = type_expr orelse undefined,
                .value_expr = default_value,
            };
            return &node.base;
        },
        .Keyword_enum => {
            const node = try arena.create(Node.EnumTag);
            node.* = Node.EnumTag{
                .base = Node{ .id = .EnumTag },
                .doc_comments = null,
                .name_token = name_token,
                .value = default_value,
            };
            return &node.base;
        },
        else => unreachable,
    }
}

// Statement
//     <- KEYWORD_comptime? VarDecl
//      / KEYWORD_comptime BlockExprStatement
//      / KEYWORD_suspend (SEMICOLON / BlockExprStatement)
//      / KEYWORD_defer BlockExprStatement
//      / KEYWORD_errdefer BlockExprStatement
//      / IfStatement
//      / LabeledStatement
//      / SwitchExpr
//      / AssignExpr SEMICOLON
fn parseStatement(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const comptime_token = eatToken(it, .Keyword_comptime);

    const var_decl_node = try parseVarDecl(arena, it, tree);
    if (var_decl_node) |node| {
        const var_decl = node.cast(Node.VarDecl).?;
        var_decl.comptime_token = comptime_token;
        return node;
    }

    if (comptime_token) |token| {
        const block_expr = (try expectNode(arena, it, tree, parseBlockExprStatement, Error{
            .ExpectedBlockOrAssignment = Error.ExpectedBlockOrAssignment{ .token = it.peek().?.start },
        })) orelse return null;

        const node = try arena.create(Node.Comptime);
        node.* = Node.Comptime{
            .base = Node{ .id = .Comptime },
            .doc_comments = null,
            .comptime_token = token,
            .expr = block_expr,
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_suspend)) |suspend_token| {
        const semicolon = eatToken(it, .Semicolon);

        const body_node = if (semicolon == null) blk: {
            break :blk (try expectNode(arena, it, tree, parseBlockExprStatement, Error{
                // TODO: expected block or expression
                .ExpectedBlockOrAssignment = Error.ExpectedBlockOrAssignment{ .token = it.peek().?.start },
            })) orelse return null;
        } else null;

        const node = try arena.create(Node.Suspend);
        node.* = Node.Suspend{
            .base = Node{ .id = .Suspend },
            .suspend_token = suspend_token,
            .body = body_node,
        };
        return &node.base;
    }

    const defer_token = eatToken(it, .Keyword_defer) orelse eatToken(it, .Keyword_errdefer);
    if (defer_token) |token| {
        const expr_node = (try expectNode(arena, it, tree, parseBlockExprStatement, Error{
            // TODO: expected block or expression
            .ExpectedBlockOrAssignment = Error.ExpectedBlockOrAssignment{ .token = it.peek().?.start },
        })) orelse return null;
        const node = try arena.create(Node.Defer);
        node.* = Node.Defer{
            .base = Node{ .id = .Defer },
            .defer_token = token,
            .expr = expr_node,
        };
        return &node.base;
    }

    if (try parseIfStatement(arena, it, tree)) |node| return node;
    if (try parseLabeledStatement(arena, it, tree)) |node| return node;
    if (try parseSwitchExpr(arena, it, tree)) |node| return node;
    if (try parseAssignExpr(arena, it, tree)) |node| {
        _ = (try expectToken(it, tree, .Semicolon)) orelse return null;
        return node;
    }

    return null;
}

// IfStatement
//     <- IfPrefix BlockExpr ( KEYWORD_else Payload? Statement )?
//      / IfPrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
fn parseIfStatement(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const if_node = if (try parseIfPrefix(arena, it, tree)) |node| node.cast(Node.If).? else return null;
    const block_expr = (try parseBlockExpr(arena, it, tree));
    const assign_expr = if (block_expr == null) blk: {
        break :blk (try parseAssignExpr(arena, it, tree)) orelse null;
    } else null;
    const semicolon = if (assign_expr != null) eatToken(it, .Semicolon) else null;

    const else_node = if (semicolon != null) blk: {
        const else_token = eatToken(it, .Keyword_else) orelse break :blk null;
        const payload = try parsePayload(arena, it, tree);
        const else_body = (try expectNode(arena, it, tree, parseStatement, Error{
            .InvalidToken = Error.InvalidToken{ .token = it.peek().?.start },
        })) orelse return null;

        const node = try arena.create(Node.Else);
        node.* = Node.Else{
            .base = Node{ .id = .Else },
            .else_token = else_token,
            .payload = payload,
            .body = else_body,
        };

        break :blk node;
    } else null;

    if (block_expr) |body| {
        if_node.body = body;
        if_node.@"else" = else_node;
        return &if_node.base;
    }

    if (assign_expr) |body| {
        if_node.body = body;
        if (semicolon != null) return &if_node.base;
        if (else_node != null) {
            if_node.@"else" = else_node;
            return &if_node.base;
        }
        try tree.errors.push(Error{
            .ExpectedSemiOrElse = Error.ExpectedSemiOrElse{ .token = it.peek().?.start },
        });
    }

    return null;
}

// LabeledStatement <- BlockLabel? (Block / LoopStatement)
fn parseLabeledStatement(arena: *Allocator, it: *TokenIterator, tree: *Tree) anyerror!?*Node {
    const label_token = parseBlockLabel(arena, it, tree);

    if (try parseBlock(arena, it, tree)) |node| {
        node.cast(Node.Block).?.label = label_token;
        return node;
    }

    if (try parseLoopStatement(arena, it, tree)) |node| {
        if (node.cast(Node.For)) |for_node| {
            for_node.label = label_token;
        } else if (node.cast(Node.While)) |while_node| {
            while_node.label = label_token;
        } else unreachable;
        return node;
    }

    return null;
}

// LoopStatement <- KEYWORD_inline? (ForStatement / WhileStatement)
fn parseLoopStatement(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const inline_token = eatToken(it, .Keyword_inline);

    if (try parseForStatement(arena, it, tree)) |node| {
        node.cast(Node.For).?.inline_token = inline_token;
        return node;
    }

    if (try parseWhileStatement(arena, it, tree)) |node| {
        node.cast(Node.While).?.inline_token = inline_token;
        return node;
    }

    return null;
}

// ForStatement
//     <- ForPrefix BlockExpr ( KEYWORD_else Statement )?
//      / ForPrefix AssignExpr ( SEMICOLON / KEYWORD_else Statement )
fn parseForStatement(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseForPrefix(arena, it, tree)) orelse return null;
    const for_prefix = node.cast(Node.For).?;

    if (try parseBlockExpr(arena, it, tree)) |block_expr_node| {
        for_prefix.body = block_expr_node;

        if (eatToken(it, .Keyword_else)) |else_token| {
            const statement_node = (try expectNode(arena, it, tree, parseStatement, Error{
                .InvalidToken = Error.InvalidToken{ .token = it.peek().?.start },
            })) orelse return null;

            const else_node = try arena.create(Node.Else);
            else_node.* = Node.Else{
                .base = Node{ .id = .Else },
                .else_token = else_token,
                .payload = null,
                .body = statement_node,
            };
            for_prefix.@"else" = else_node;

            return node;
        }

        return node;
    }

    if (try parseAssignExpr(arena, it, tree)) |assign_expr| {
        for_prefix.body = assign_expr;

        if (eatToken(it, .Semicolon) != null) return node;

        if (eatToken(it, .Keyword_else)) |else_token| {
            const statement_node = (try expectNode(arena, it, tree, parseStatement, Error{
                .ExpectedStatement = Error.ExpectedStatement{ .token = it.peek().?.start },
            })) orelse return null;

            const else_node = try arena.create(Node.Else);
            else_node.* = Node.Else{
                .base = Node{ .id = .Else },
                .else_token = else_token,
                .payload = null,
                .body = statement_node,
            };
            for_prefix.@"else" = else_node;
            return node;
        }

        try tree.errors.push(Error{
            .ExpectedSemiOrElse = Error.ExpectedSemiOrElse{ .token = it.peek().?.start },
        });
        return null;
    }

    return null;
}

// WhileStatement
//     <- WhilePrefix BlockExpr ( KEYWORD_else Payload? Statement )?
//      / WhilePrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
fn parseWhileStatement(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseWhilePrefix(arena, it, tree)) orelse return null;
    const while_prefix = node.cast(Node.While).?;

    if (try parseBlockExpr(arena, it, tree)) |block_expr_node| {
        while_prefix.body = block_expr_node;

        if (eatToken(it, .Keyword_else)) |else_token| {
            const payload = try parsePayload(arena, it, tree);

            const statement_node = (try expectNode(arena, it, tree, parseStatement, Error{
                .InvalidToken = Error.InvalidToken{ .token = it.peek().?.start },
            })) orelse return null;

            const else_node = try arena.create(Node.Else);
            else_node.* = Node.Else{
                .base = Node{ .id = .Else },
                .else_token = else_token,
                .payload = payload,
                .body = statement_node,
            };
            while_prefix.@"else" = else_node;

            return node;
        }

        return node;
    }

    if (try parseAssignExpr(arena, it, tree)) |assign_expr_node| {
        while_prefix.body = assign_expr_node;

        if (eatToken(it, .Semicolon) != null) return node;

        if (eatToken(it, .Keyword_else)) |else_token| {
            const payload = try parsePayload(arena, it, tree);

            const statement_node = (try expectNode(arena, it, tree, parseStatement, Error{
                .ExpectedStatement = Error.ExpectedStatement{ .token = it.peek().?.start },
            })) orelse return null;

            const else_node = try arena.create(Node.Else);
            else_node.* = Node.Else{
                .base = Node{ .id = .Else },
                .else_token = else_token,
                .payload = payload,
                .body = statement_node,
            };
            while_prefix.@"else" = else_node;
            return node;
        }

        try tree.errors.push(Error{
            .ExpectedSemiOrElse = Error.ExpectedSemiOrElse{ .token = it.peek().?.start },
        });
        return null;
    }

    return null;
}

// BlockExprStatement
//     <- BlockExpr
//      / AssignExpr SEMICOLON
fn parseBlockExprStatement(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    if (try parseBlockExpr(arena, it, tree)) |node| return node;
    if (try parseAssignExpr(arena, it, tree)) |node| {
        _ = (try expectToken(it, tree, .Semicolon)) orelse return null;
        return node;
    }
    return null;
}

// BlockExpr <- BlockLabel? Block
fn parseBlockExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) anyerror!?*Node {
    const label_token = parseBlockLabel(arena, it, tree) orelse return null;
    const block_node = (parseBlock(arena, it, tree) catch return error.TodoFixRecursion) orelse return null;
    block_node.cast(Node.Block).?.label = label_token;
    return block_node;
}

// AssignExpr <- Expr (AssignOp Expr)?
fn parseAssignExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(arena, it, tree, parseAssignOp, parseExpr, .Once);
}

// Expr <- KEYWORD_try* BoolOrExpr
fn parseExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parsePrefixOpExpr(arena, it, tree, parseTry, parseBoolOrExpr);
}

// BoolOrExpr <- BoolAndExpr (KEYWORD_or BoolAndExpr)*
fn parseBoolOrExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(
        arena,
        it,
        tree,
        SimpleBinOpParser(.Keyword_or, Node.InfixOp.Op.BoolOr).parse,
        parseBoolAndExpr,
        .Infinitely,
    );
}

// BoolAndExpr <- CompareExpr (KEYWORD_and CompareExpr)*
fn parseBoolAndExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(
        arena,
        it,
        tree,
        SimpleBinOpParser(.Keyword_and, Node.InfixOp.Op.BoolAnd).parse,
        parseCompareExpr,
        .Infinitely,
    );
}

// CompareExpr <- BitwiseExpr (CompareOp BitwiseExpr)?
fn parseCompareExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(arena, it, tree, parseCompareOp, parseBitwiseExpr, .Once);
    // TODO: stage1 supplies BinOpChainInf, not Once, but grammar uses `?`
}

// BitwiseExpr <- BitShiftExpr (BitwiseOp BitShiftExpr)*
fn parseBitwiseExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(arena, it, tree, parseBitwiseOp, parseBitShiftExpr, .Infinitely);
}

// BitShiftExpr <- AdditionExpr (BitShiftOp AdditionExpr)*
fn parseBitShiftExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(arena, it, tree, parseBitShiftOp, parseAdditionExpr, .Infinitely);
}

// AdditionExpr <- MultiplyExpr (AdditionOp MultiplyExpr)*
fn parseAdditionExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(arena, it, tree, parseAdditionOp, parseMultiplyExpr, .Infinitely);
}

// MultiplyExpr <- PrefixExpr (MultiplyOp PrefixExpr)*
fn parseMultiplyExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(arena, it, tree, parseMultiplyOp, parsePrefixExpr, .Infinitely);
}

// PrefixExpr <- PrefixOp* PrimaryExpr
fn parsePrefixExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parsePrefixOpExpr(arena, it, tree, parsePrefixOp, parsePrimaryExpr);
}

// PrimaryExpr
//     <- AsmExpr
//      / IfExpr
//      / KEYWORD_break BreakLabel? Expr?
//      / KEYWORD_cancel Expr
//      / KEYWORD_comptime Expr
//      / KEYWORD_continue BreakLabel?
//      / KEYWORD_resume Expr
//      / KEYWORD_return Expr?
//      / BlockLabel? LoopExpr
//      / Block
//      / CurlySuffixExpr
fn parsePrimaryExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    // TODO: enum literal not represented in grammar: https://github.com/ziglang/zig/issues/2235
    if (try parseEnumLiteral(arena, it, tree)) |node| return node;
    if (try parseAsmExpr(arena, it, tree)) |node| return node;
    if (try parseIfExpr(arena, it, tree)) |node| return node;

    if (eatToken(it, .Keyword_break)) |token| {
        const label = parseBreakLabel(arena, it, tree);
        const expr_node = try parseExpr(arena, it, tree);
        const node = try arena.create(Node.ControlFlowExpression);
        node.* = Node.ControlFlowExpression{
            .base = Node{ .id = .ControlFlowExpression },
            .ltoken = token,
            .kind = Node.ControlFlowExpression.Kind{ .Break = null }, // TODO: what goes here?
            .rhs = expr_node,
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_cancel)) |token| {
        const expr_node = (try expectNode(arena, it, tree, parseExpr, Error{
            .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
        })) orelse return null;
        const node = try arena.create(Node.PrefixOp);
        node.* = Node.PrefixOp{
            .base = Node{ .id = .PrefixOp },
            .op_token = token,
            .op = Node.PrefixOp.Op.Cancel,
            .rhs = expr_node,
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_comptime)) |token| {
        const expr_node = (try expectNode(arena, it, tree, parseExpr, Error{
            .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
        })) orelse return null;
        const node = try arena.create(Node.Comptime);
        node.* = Node.Comptime{
            .base = Node{ .id = .Comptime },
            .doc_comments = null,
            .comptime_token = token,
            .expr = expr_node,
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_continue)) |token| {
        const label = parseBreakLabel(arena, it, tree);
        const node = try arena.create(Node.ControlFlowExpression);
        node.* = Node.ControlFlowExpression{
            .base = Node{ .id = .ControlFlowExpression },
            .ltoken = token,
            .kind = Node.ControlFlowExpression.Kind{ .Continue = null }, // TODO: what goes here?
            .rhs = null,
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_resume)) |token| {
        const expr_node = (try expectNode(arena, it, tree, parseExpr, Error{
            .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
        })) orelse return null;
        const node = try arena.create(Node.PrefixOp);
        node.* = Node.PrefixOp{
            .base = Node{ .id = .PrefixOp },
            .op_token = token,
            .op = Node.PrefixOp.Op.Resume,
            .rhs = expr_node,
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_return)) |token| {
        const expr_node = try parseExpr(arena, it, tree);
        const node = try arena.create(Node.ControlFlowExpression);
        node.* = Node.ControlFlowExpression{
            .base = Node{ .id = .ControlFlowExpression },
            .ltoken = token,
            .kind = Node.ControlFlowExpression.Kind.Return,
            .rhs = expr_node,
        };
        return &node.base;
    }

    const label = parseBlockLabel(arena, it, tree);
    if (try parseLoopExpr(arena, it, tree)) |node| {
        if (node.cast(Node.For)) |for_node| {
            for_node.label = label;
        } else if (node.cast(Node.While)) |while_node| {
            while_node.label = label;
        } else unreachable;
        return node;
    }

    if (try parseBlock(arena, it, tree)) |node| return node;
    if (try parseCurlySuffixExpr(arena, it, tree)) |node| return node;

    return null;
}

// IfExpr <- IfPrefix Expr (KEYWORD_else Payload? Expr)?
fn parseIfExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const if_node = (try parseIfPrefix(arena, it, tree)) orelse return null;
    const expr_node = (try parseExpr(arena, it, tree)) orelse return null;

    const else_node = if (eatToken(it, .Keyword_else)) |else_token| blk: {
        const payload = try parsePayload(arena, it, tree);
        const else_expr = (try expectNode(arena, it, tree, parseExpr, Error{
            .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
        })) orelse return null;

        const node = try arena.create(Node.Else);
        node.* = Node.Else{
            .base = Node{ .id = .Else },
            .else_token = else_token,
            .payload = payload,
            .body = else_expr,
        };

        break :blk node;
    } else null;

    const node = if_node.cast(Node.If).?;
    node.*.body = expr_node;
    node.*.@"else" = else_node;

    return &node.base;
}

// Block <- LBRACE Statement* RBRACE
fn parseBlock(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const lbrace = eatToken(it, .LBrace) orelse return null;

    var statements = Node.Block.StatementList.init(arena);
    while (true) {
        const statement = (try parseStatement(arena, it, tree)) orelse break;
        try statements.push(statement);
    }

    const rbrace = (try expectToken(it, tree, .RBrace)) orelse return null;

    const block_node = try arena.create(Node.Block);
    block_node.* = Node.Block{
        .base = Node{ .id = .Block },
        .label = null, // set by caller
        .lbrace = lbrace,
        .statements = statements,
        .rbrace = rbrace,
    };

    return &block_node.base;
}

// LoopExpr <- KEYWORD_inline? (ForExpr / WhileExpr)
fn parseLoopExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const inline_token = eatToken(it, .Keyword_inline);

    if (try parseForExpr(arena, it, tree)) |node| {
        node.cast(Node.For).?.inline_token = inline_token;
        return node;
    }

    if (try parseWhileExpr(arena, it, tree)) |node| {
        node.cast(Node.While).?.inline_token = inline_token;
        return node;
    }

    // TODO: error?

    return null;
}

// ForExpr <- ForPrefix Expr (KEYWORD_else Expr)?
fn parseForExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseForPrefix(arena, it, tree)) orelse return null;

    const body_node = (try expectNode(arena, it, tree, parseExpr, Error{
        .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
    })) orelse return null;
    node.cast(Node.For).?.body = body_node;

    if (eatToken(it, .Keyword_else)) |else_token| {
        const body = (try expectNode(arena, it, tree, parseExpr, Error{
            .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
        })) orelse return null;

        const else_node = try arena.create(Node.Else);
        else_node.* = Node.Else{
            .base = Node{ .id = .Else },
            .else_token = else_token,
            .payload = null,
            .body = body,
        };

        node.cast(Node.For).?.@"else" = else_node;
    }

    return node;
}

// WhileExpr <- WhilePrefix Expr (KEYWORD_else Payload? Expr)?
fn parseWhileExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseWhilePrefix(arena, it, tree)) orelse return null;

    const body_node = (try expectNode(arena, it, tree, parseExpr, Error{
        .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
    })) orelse return null;
    node.cast(Node.For).?.body = body_node;

    if (eatToken(it, .Keyword_else)) |else_token| {
        const payload = try parsePayload(arena, it, tree);
        const body = (try expectNode(arena, it, tree, parseExpr, Error{
            .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
        })) orelse return null;

        const else_node = try arena.create(Node.Else);
        else_node.* = Node.Else{
            .base = Node{ .id = .Else },
            .else_token = else_token,
            .payload = null,
            .body = body,
        };

        node.cast(Node.While).?.@"else" = else_node;
    }

    return node;
}

// CurlySuffixExpr <- TypeExpr InitList?
fn parseCurlySuffixExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const type_expr = (try parseTypeExpr(arena, it, tree)) orelse return null;
    const init_list = (try parseInitList(arena, it, tree)) orelse return type_expr;
    init_list.cast(Node.SuffixOp).?.lhs = type_expr;
    return init_list;
}

// InitList
//     <- LBRACE FieldInit (COMMA FieldInit)* COMMA? RBRACE
//      / LBRACE Expr (COMMA Expr)* COMMA? RBRACE
//      / LBRACE RBRACE
fn parseInitList(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const lbrace = eatToken(it, .LBrace) orelse return null;
    var init_list = Node.SuffixOp.Op.InitList.init(arena);
    const node = try arena.create(Node.SuffixOp);
    node.* = Node.SuffixOp{
        .base = Node{ .id = .SuffixOp },
        .lhs = undefined, // set by caller
        .op = Node.SuffixOp.Op{ .StructInitializer = init_list },
        .rtoken = undefined, // set below
    };

    if (try parseFieldInit(arena, it, tree)) |field_init| {
        try init_list.push(field_init);
        while (eatToken(it, .Comma)) |_| {
            const next = (try parseFieldInit(arena, it, tree)) orelse break;
            try init_list.push(next);
        }
    } else if (try parseExpr(arena, it, tree)) |expr| {
        try init_list.push(expr);
        while (eatToken(it, .Comma)) |_| {
            const next = (try parseExpr(arena, it, tree)) orelse break;
            try init_list.push(next);
        }
    }

    node.rtoken = (try expectToken(it, tree, .RBrace)) orelse return null;
    return &node.base;
}

// TypeExpr <- PrefixTypeOp* ErrorUnionExpr
fn parseTypeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parsePrefixOpExpr(arena, it, tree, parsePrefixTypeOp, parseErrorUnionExpr);
}

// ErrorUnionExpr <- SuffixExpr (EXCLAMATIONMARK TypeExpr)?
fn parseErrorUnionExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const suffix_expr = (try parseSuffixExpr(arena, it, tree)) orelse return null;

    if (eatToken(it, .Bang)) |bang| {
        const type_expr = (try expectNode(arena, it, tree, parseTypeExpr, Error{
            .ExpectedTypeExpr = Error.ExpectedTypeExpr{ .token = it.peek().?.start },
        })) orelse return null;
        const op_node = try arena.create(Node.InfixOp);
        op_node.* = Node.InfixOp{
            .base = Node{ .id = .InfixOp },
            .op_token = bang,
            .lhs = suffix_expr,
            .op = Node.InfixOp.Op.ErrorUnion,
            .rhs = type_expr,
        };
        return &op_node.base;
    }

    return suffix_expr;
}

// SuffixExpr
//     <- AsyncPrefix PrimaryTypeExpr SuffixOp* FnCallArguments
//      / PrimaryTypeExpr (SuffixOp / FnCallArguments)*
fn parseSuffixExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    if (try parseAsyncPrefix(arena, it, tree)) |async_node| {
        // TODO: Implement hack for parsing `async fn ...` in ast_parse_suffix_expr
        var child = (try expectNode(arena, it, tree, parsePrimaryTypeExpr, Error{
            // TODO: different error?
            .ExpectedPrimaryExpr = Error.ExpectedPrimaryExpr{ .token = it.peek().?.start },
        })) orelse return null;

        while (try parseSuffixOp(arena, it, tree)) |suffix| {
            // TODO: all of this, maybe
            switch (suffix.cast(Node.SuffixOp).?.op) {
                .Call => |op| {},
                .ArrayAccess => |op| {},
                .Slice => |op| {},
                .ArrayInitializer => |op| {},
                .StructInitializer => |op| {},
                .Deref => |op| {},
                .UnwrapOptional => |op| {},
            }
            child = suffix;
        }

        const params = (try parseFnCallArguments(arena, it, tree)) orelse {
            try tree.errors.push(Error{
                .ExpectedParamList = Error.ExpectedParamList{ .token = it.peek().?.start },
            });
            return null;
        };

        const node = try arena.create(Node.SuffixOp);
        node.* = Node.SuffixOp{
            .base = Node{ .id = .SuffixOp },
            .lhs = child,
            .op = Node.SuffixOp.Op{
                .Call = Node.SuffixOp.Op.Call{
                    .params = params,
                    .async_attr = async_node.cast(Node.AsyncAttribute).?,
                },
            },
            .rtoken = undefined, // TODO TokenIndex ehhhhhh????
        };
        return &node.base;
    }

    if (try parsePrimaryTypeExpr(arena, it, tree)) |expr| {
        var res = expr;

        while (true) {
            if (try parseSuffixOp(arena, it, tree)) |suffix| {
                suffix.cast(Node.SuffixOp).?.lhs = res;
                res = suffix;
                continue;
            } else if (try parseFnCallArguments(arena, it, tree)) |params| {
                const call = try arena.create(Node.SuffixOp);
                call.* = Node.SuffixOp{
                    .base = Node{ .id = .SuffixOp },
                    .lhs = res,
                    .op = Node.SuffixOp.Op{
                        .Call = Node.SuffixOp.Op.Call{
                            .params = params,
                            .async_attr = null,
                        },
                    },
                    .rtoken = undefined, // TODO: TokenIndex HMMMMM.
                };
                res = &call.base;
                continue;
            }
            break;
        }
        // TODO
        return res;
    }

    return null;
}

// PrimaryTypeExpr
//     <- BUILTINIDENTIFIER FnCallArguments
//      / CHAR_LITERAL
//      / ContainerDecl
//      / ErrorSetDecl
//      / FLOAT
//      / FnProto
//      / GroupedExpr
//      / LabeledTypeExpr
//      / IDENTIFIER
//      / IfTypeExpr
//      / INTEGER
//      / KEYWORD_anyerror
//      / KEYWORD_comptime TypeExpr
//      / KEYWORD_error DOT IDENTIFIER
//      / KEYWORD_false
//      / KEYWORD_null
//      / KEYWORD_promise
//      / KEYWORD_true
//      / KEYWORD_undefined
//      / KEYWORD_unreachable
//      / STRINGLITERAL
//      / SwitchExpr
fn parsePrimaryTypeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    // TODO: @[a-zA-Z_][a-zA-Z0-9]* (builtin identifier)
    if (eatToken(it, .CharLiteral)) |token| {
        const node = try arena.create(Node.CharLiteral);
        node.* = Node.CharLiteral{
            .base = Node{ .id = .CharLiteral },
            .token = token,
        };
        return &node.base;
    }

    if (try parseContainerDecl(arena, it, tree)) |node| return node;
    if (try parseErrorSetDecl(arena, it, tree)) |node| return node;
    if (try parseFloatLiteral(arena, it, tree)) |node| return node;
    if (try parseFnProto(arena, it, tree)) |node| return node;
    if (try parseGroupedExpr(arena, it, tree)) |node| return node;
    if (try parseLabeledTypeExpr(arena, it, tree)) |node| return node;
    if (try parseIdentifier(arena, it, tree)) |node| return node;
    if (try parseIfTypeExpr(arena, it, tree)) |node| return node;
    if (try parseIntegerLiteral(arena, it, tree)) |node| return node;
    if (eatToken(it, .Keyword_anyerror)) |token| return createLiteral(arena, Node.ErrorType, token);
    if (eatToken(it, .Keyword_comptime)) |token| {
        const expr = (try parseTypeExpr(arena, it, tree)) orelse return null;
        const node = try arena.create(Node.Comptime);
        node.* = Node.Comptime{
            .base = Node{ .id = .Comptime },
            .doc_comments = null,
            .comptime_token = token,
            .expr = expr,
        };
        return &node.base;
    }
    if (eatToken(it, .Keyword_error)) |token| {
        const period = (try expectToken(it, tree, .Period)) orelse return null;
        const identifier = (try expectNode(arena, it, tree, parseIdentifier, Error{
            .ExpectedIdentifier = Error.ExpectedIdentifier{ .token = it.peek().?.start },
        })) orelse return null;
        const global_error_set = try createLiteral(arena, Node.ErrorType, token);
        const node = try arena.create(Node.InfixOp);
        node.* = Node.InfixOp{
            .base = Node{ .id = .InfixOp },
            .op_token = period,
            .lhs = global_error_set,
            .op = Node.InfixOp.Op.Period,
            .rhs = identifier,
        };
        return &node.base;
    }
    if (eatToken(it, .Keyword_false)) |token| return createLiteral(arena, Node.BoolLiteral, token);
    if (eatToken(it, .Keyword_null)) |token| return createLiteral(arena, Node.NullLiteral, token);
    if (eatToken(it, .Keyword_promise)) |token| {
        const node = try arena.create(Node.PromiseType);
        node.* = Node.PromiseType{
            .base = Node{ .id = .PromiseType },
            .promise_token = token,
            .result = null,
        };
        return &node.base;
    }
    if (eatToken(it, .Keyword_true)) |token| return createLiteral(arena, Node.BoolLiteral, token);
    if (eatToken(it, .Keyword_undefined)) |token| return createLiteral(arena, Node.UndefinedLiteral, token);
    if (eatToken(it, .Keyword_unreachable)) |token| return createLiteral(arena, Node.Unreachable, token);
    if (try parseStringLiteral(arena, it, tree)) |node| return node;
    if (try parseSwitchExpr(arena, it, tree)) |node| return node;

    return null;
}

// ContainerDecl <- (KEYWORD_extern / KEYWORD_packed)? ContainerDeclAuto
fn parseContainerDecl(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const layout_token = eatToken(it, .Keyword_extern) orelse
        eatToken(it, .Keyword_packed);

    const node = (try parseContainerDeclAuto(arena, it, tree)) orelse return null;
    node.cast(Node.ContainerDecl).?.*.layout_token = layout_token;
    return node;
}

// ErrorSetDecl <- KEYWORD_error LBRACE IdentifierList RBRACE
fn parseErrorSetDecl(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const error_token = eatToken(it, .Keyword_error) orelse return null;
    _ = (try expectToken(it, tree, .LBrace)) orelse return null;
    const decls = try parseIdentifierList(arena, it, tree);
    const rbrace = (try expectToken(it, tree, .RBrace)) orelse return null;

    const node = try arena.create(Node.ErrorSetDecl);
    node.* = Node.ErrorSetDecl{
        .base = Node{ .id = .ErrorSetDecl },
        .error_token = error_token,
        .decls = decls,
        .rbrace_token = rbrace,
    };
    return &node.base;
}

// GroupedExpr <- LPAREN Expr RPAREN
fn parseGroupedExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const lparen = eatToken(it, .LParen) orelse return null;
    const expr = (try expectNode(arena, it, tree, parseExpr, Error{
        .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
    })) orelse return null;
    const rparen = (try expectToken(it, tree, .RParen)) orelse return null;

    const node = try arena.create(Node.GroupedExpression);
    node.* = Node.GroupedExpression{
        .base = Node{ .id = .GroupedExpression },
        .lparen = lparen,
        .expr = expr,
        .rparen = rparen,
    };
    return &node.base;
}

// IfTypeExpr <- IfPrefix TypeExpr (KEYWORD_else Payload? TypeExpr)?
fn parseIfTypeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseIfPrefix(arena, it, tree)) orelse return null;
    const type_expr = (try expectNode(arena, it, tree, parseTypeExpr, Error{
        .ExpectedTypeExpr = Error.ExpectedTypeExpr{ .token = it.peek().?.start },
    })) orelse return null;

    const if_prefix = node.cast(Node.If).?;
    if_prefix.body = type_expr;

    if (eatToken(it, .Keyword_else)) |else_token| {
        const payload = (try parsePayload(arena, it, tree)) orelse return null;
        const else_body = (try expectNode(arena, it, tree, parseTypeExpr, Error{
            .ExpectedTypeExpr = Error.ExpectedTypeExpr{ .token = it.peek().?.start },
        })) orelse return null;

        const else_node = try arena.create(Node.Else);
        else_node.* = Node.Else{
            .base = Node{ .id = .Else },
            .else_token = else_token,
            .payload = payload,
            .body = else_body,
        };
        if_prefix.@"else" = else_node;
    }

    return node;
}

// LabeledTypeExpr
//     <- BlockLabel Block
//      / BlockLabel? LoopTypeExpr
fn parseLabeledTypeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const label = parseBlockLabel(arena, it, tree);

    if (label) |token| {
        if (try parseBlock(arena, it, tree)) |node| {
            node.cast(Node.Block).?.label = token;
            return node;
        }
    }

    const node = (try parseLoopTypeExpr(arena, it, tree)) orelse return null;
    switch (node.id) {
        .For => node.cast(Node.For).?.label = label,
        .While => node.cast(Node.While).?.label = label,
        else => unreachable,
    }
    return node;
}

// LoopTypeExpr <- KEYWORD_inline? (ForTypeExpr / WhileTypeExpr)
fn parseLoopTypeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const inline_token = eatToken(it, .Keyword_inline);

    if (try parseForTypeExpr(arena, it, tree)) |node| {
        node.cast(Node.For).?.inline_token = inline_token;
        return node;
    }

    if (try parseWhileTypeExpr(arena, it, tree)) |node| {
        node.cast(Node.While).?.inline_token = inline_token;
        return node;
    }

    return null;
}

// ForTypeExpr <- ForPrefix TypeExpr (KEYWORD_else TypeExpr)?
fn parseForTypeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseForPrefix(arena, it, tree)) orelse return null;
    const for_prefix = node.cast(Node.For).?;

    const type_expr = (try expectNode(arena, it, tree, parseTypeExpr, Error{
        .ExpectedTypeExpr = Error.ExpectedTypeExpr{ .token = it.peek().?.start },
    })) orelse return null;
    for_prefix.body = type_expr;

    if (eatToken(it, .Keyword_else)) |else_token| {
        const else_expr = (try expectNode(arena, it, tree, parseTypeExpr, Error{
            .ExpectedTypeExpr = Error.ExpectedTypeExpr{ .token = it.peek().?.start },
        })) orelse return null;

        const else_node = try arena.create(Node.Else);
        else_node.* = Node.Else{
            .base = Node{ .id = .Else },
            .else_token = else_token,
            .payload = null,
            .body = else_expr,
        };

        for_prefix.@"else" = else_node;
    }

    return node;
}

// WhileTypeExpr <- WhilePrefix TypeExpr (KEYWORD_else Payload? TypeExpr)?
fn parseWhileTypeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseWhilePrefix(arena, it, tree)) orelse return null;
    const while_prefix = node.cast(Node.While).?;

    const type_expr = (try expectNode(arena, it, tree, parseTypeExpr, Error{
        .ExpectedTypeExpr = Error.ExpectedTypeExpr{ .token = it.peek().?.start },
    })) orelse return null;
    while_prefix.body = type_expr;

    if (eatToken(it, .Keyword_else)) |else_token| {
        const payload = try parsePayload(arena, it, tree);

        const else_expr = (try expectNode(arena, it, tree, parseTypeExpr, Error{
            .ExpectedTypeExpr = Error.ExpectedTypeExpr{ .token = it.peek().?.start },
        })) orelse return null;

        const else_node = try arena.create(Node.Else);
        else_node.* = Node.Else{
            .base = Node{ .id = .Else },
            .else_token = else_token,
            .payload = null,
            .body = else_expr,
        };

        while_prefix.@"else" = else_node;
    }

    return node;
}

// SwitchExpr <- KEYWORD_switch LPAREN Expr RPAREN LBRACE SwitchProngList RBRACE
fn parseSwitchExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const switch_token = eatToken(it, .Keyword_switch) orelse return null;
    _ = (try expectToken(it, tree, .LParen)) orelse return null;
    const expr_node = (try expectNode(arena, it, tree, parseExpr, Error{
        .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
    })) orelse return null;
    _ = (try expectToken(it, tree, .RParen)) orelse return null;
    _ = (try expectToken(it, tree, .LBrace)) orelse return null;
    const cases = try parseSwitchProngList(arena, it, tree);
    const rbrace = (try expectToken(it, tree, .RBrace)) orelse return null;

    const node = try arena.create(Node.Switch);
    node.* = Node.Switch{
        .base = Node{ .id = .Switch },
        .switch_token = switch_token,
        .expr = expr_node,
        .cases = cases,
        .rbrace = rbrace,
    };
    return &node.base;
}

// AsmExpr <- KEYWORD_asm KEYWORD_volatile? LPAREN STRINGLITERAL AsmOutput? RPAREN
fn parseAsmExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const asm_token = eatToken(it, .Keyword_asm) orelse return null;
    const volatile_token = eatToken(it, .Keyword_volatile);
    _ = (try expectToken(it, tree, .LParen)) orelse return null;
    const asm_output = try parseAsmOutput(arena, it, tree);
    const rparen = (try expectToken(it, tree, .RParen)) orelse return null;

    const node = try arena.create(Node.Asm);
    node.* = Node.Asm{
        .base = Node{ .id = .Asm },
        .asm_token = asm_token,
        .volatile_token = volatile_token,
        .template = undefined, //TODO
        .outputs = undefined, // asm_output, // TODO
        .inputs = undefined, // TODO
        .clobbers = undefined, // TODO
        .rparen = rparen,
    };
    return &node.base;
}

// TODO: enum literal not represented in grammar: https://github.com/ziglang/zig/issues/2235
fn parseEnumLiteral(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const dot = eatToken(it, .Period) orelse return null;
    const name = (try expectToken(it, tree, .Identifier)) orelse return null;

    const node = try arena.create(Node.EnumLiteral);
    node.* = Node.EnumLiteral{
        .base = undefined, // TODO: ??
        .dot = dot,
        .name = name,
    };
    return &node.base;
}

// AsmOutput <- COLON AsmOutputList AsmInput?
fn parseAsmOutput(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return error.NotImplemented; // TODO
}

// AsmOutputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN (MINUSRARROW TypeExpr / IDENTIFIER) RPAREN
fn parseAsmOutputItem(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return error.NotImplemented; // TODO
}

// AsmInput <- COLON AsmInputList AsmClobbers?
fn parseAsmInput(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return error.NotImplemented; // TODO
}

// AsmInputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN Expr RPAREN
fn parseAsmInputItem(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return error.NotImplemented; // TODO
}

// AsmClobbers <- COLON StringList
// StringList <- (STRINGLITERAL COMMA)* STRINGLITERAL?
fn parseAsmClobbers(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?Node.Asm.ClobberList {
    _ = eatToken(it, .Colon) orelse return null;
    return try ListParser(Node.Asm.ClobberList, parseStringLiteral).parse(arena, it, tree);
}

// BreakLabel <- COLON IDENTIFIER
fn parseBreakLabel(arena: *Allocator, it: *TokenIterator, tree: *Tree) ?TokenIndex {
    _ = eatToken(it, .Colon) orelse return null;
    return eatToken(it, .Identifier);
}

// BlockLabel <- IDENTIFIER COLON
fn parseBlockLabel(arena: *Allocator, it: *TokenIterator, tree: *Tree) ?TokenIndex {
    const token = eatToken(it, .Identifier) orelse return null;
    _ = eatToken(it, .Colon) orelse return null;
    return token;
}

// FieldInit <- DOT IDENTIFIER EQUAL Expr
fn parseFieldInit(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const period_token = eatToken(it, .Period) orelse return null;
    const name_token = (try expectToken(it, tree, .Identifier)) orelse return null;
    const eq_token = (try expectToken(it, tree, .Equal)) orelse return null;
    const expr_node = (try expectNode(arena, it, tree, parseExpr, Error{
        .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
    })) orelse return null;

    const node = try arena.create(Node.FieldInitializer);
    node.* = Node.FieldInitializer{
        .base = Node{ .id = .FieldInitializer },
        .period_token = period_token,
        .name_token = name_token,
        .expr = expr_node,
    };
    return &node.base;
}

// WhileContinueExpr <- COLON LPAREN AssignExpr RPAREN
fn parseWhileContinueExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    _ = eatToken(it, .Colon) orelse return null;
    _ = (try expectToken(it, tree, .LParen)) orelse return null;
    const node = (try expectNode(arena, it, tree, parseAssignExpr, Error{
        .ExpectedExprOrAssignment = Error.ExpectedExprOrAssignment{ .token = it.peek().?.start },
    })) orelse return null;
    _ = (try expectToken(it, tree, .RParen)) orelse return null;
    return node;
}

// LinkSection <- KEYWORD_linksection LPAREN Expr RPAREN
fn parseLinkSection(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    _ = eatToken(it, .Keyword_linksection) orelse return null;
    _ = (try expectToken(it, tree, .LParen)) orelse return null;
    const expr_node = (try expectNode(arena, it, tree, parseExpr, Error{
        .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
    })) orelse return null;
    _ = (try expectToken(it, tree, .RParen)) orelse return null;
    return expr_node;
}

// FnCC
//     <- KEYWORD_nakedcc
//      / KEYWORD_stdcallcc
//      / KEYWORD_extern
//      / KEYWORD_async (LARROW TypeExpr RARROW)?
fn parseFnCC(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?FnCC {
    if (eatToken(it, .Keyword_nakedcc)) |token| return FnCC{ .CC = token };
    if (eatToken(it, .Keyword_stdcallcc)) |token| return FnCC{ .CC = token };
    if (eatToken(it, .Keyword_extern)) |token| return FnCC{ .Extern = token };
    if (eatToken(it, .Keyword_async)) |token| {
        const node = try arena.create(Node.AsyncAttribute);
        node.* = Node.AsyncAttribute{
            .base = Node{ .id = .AsyncAttribute },
            .async_token = token,
            .allocator_type = null,
            .rangle_bracket = null,
        };
        if (eatToken(it, .AngleBracketLeft)) |_| {
            const type_expr = (try expectNode(arena, it, tree, parseTypeExpr, Error{
                .ExpectedTypeExpr = Error.ExpectedTypeExpr{ .token = it.peek().?.start },
            })) orelse return null;
            const rarrow = (try expectToken(it, tree, .AngleBracketRight)) orelse return null;
            node.allocator_type = type_expr;
            node.rangle_bracket = rarrow;
        }
        return FnCC{ .Async = node };
    }
    return FnCC{ .None = {} };
}

const FnCC = union(enum) {
    CC: TokenIndex,
    Extern: TokenIndex,
    Async: *Node.AsyncAttribute,
    None,
};

// ParamDecl <- (KEYWORD_noalias / KEYWORD_comptime)? (IDENTIFIER COLON)? ParamType
fn parseParamDecl(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const noalias_token = eatToken(it, .Keyword_noalias);
    const comptime_token = if (noalias_token == null) eatToken(it, .Keyword_comptime) else null;
    const name_token = blk: {
        const identifier = eatToken(it, .Identifier) orelse break :blk null;
        if (eatToken(it, .Colon) != null) break :blk identifier;
        _ = rewindTokenIterator(it); // ParamType may also be an identifier
        break :blk null;
    };
    const param_type = (try parseParamType(arena, it, tree)) orelse return null;

    switch (param_type) {
        .None => {
            if (name_token != null)
                try tree.errors.push(Error{
                    .ExpectedParamType = Error.ExpectedParamType{ .token = it.peek().?.start },
                });
            return null;
        },
        else => {},
    }

    const param_decl = try arena.create(Node.ParamDecl);
    param_decl.* = Node.ParamDecl{
        .base = Node{ .id = .ParamDecl },
        .doc_comments = null,
        .comptime_token = comptime_token,
        .noalias_token = noalias_token,
        .name_token = name_token,
        .type_node = undefined, // TODO: ok that this remains undefined when ... is found?
        .var_args_token = null,
    };
    switch (param_type) {
        .VarType => |node| param_decl.type_node = node,
        .TypeExpr => |node| param_decl.type_node = node,
        .VarArgs => |token| param_decl.var_args_token = token,
        else => unreachable,
    }
    return &param_decl.base;
}

// ParamType
//     <- KEYWORD_var
//      / DOT3
//      / TypeExpr
fn parseParamType(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?ParamType {
    if (eatToken(it, .Keyword_var)) |token| {
        const node = try arena.create(Node.VarType);
        node.* = Node.VarType{
            .base = Node{ .id = .VarType },
            .token = token,
        };
        return ParamType{ .VarType = &node.base };
    }
    if (eatToken(it, .Ellipsis3)) |token| return ParamType{ .VarArgs = token };
    if (try parseTypeExpr(arena, it, tree)) |node| return ParamType{ .TypeExpr = node };
    return null;
}

const ParamType = union(enum) {
    VarType: *Node,
    VarArgs: TokenIndex,
    TypeExpr: *Node,
    None,
};

// IfPrefix <- KEYWORD_if LPAREN Expr RPAREN PtrPayload?
fn parseIfPrefix(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const if_token = eatToken(it, .Keyword_if) orelse return null;
    _ = (try expectToken(it, tree, .LParen)) orelse return null;
    const condition = (try expectNode(arena, it, tree, parseExpr, Error{
        .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
    })) orelse return null;
    _ = (try expectToken(it, tree, .RParen)) orelse return null;
    const payload = try parsePtrPayload(arena, it, tree);

    const node = try arena.create(Node.If);
    node.* = Node.If{
        .base = Node{ .id = .If },
        .if_token = if_token,
        .condition = condition,
        .payload = payload,
        .body = undefined, // set by caller
        .@"else" = null,
    };
    return &node.base;
}

// WhilePrefix <- KEYWORD_while LPAREN Expr RPAREN PtrPayload? WhileContinueExpr?
fn parseWhilePrefix(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const while_token = eatToken(it, .Keyword_while) orelse return null;

    _ = (try expectToken(it, tree, .LParen)) orelse return null;
    const condition = (try expectNode(arena, it, tree, parseExpr, Error{
        .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
    })) orelse return null;
    _ = (try expectToken(it, tree, .RParen)) orelse return null;

    const payload = try parsePtrPayload(arena, it, tree);
    const continue_expr = try parseWhileContinueExpr(arena, it, tree);

    const node = try arena.create(Node.While);
    node.* = Node.While{
        .base = Node{ .id = .While },
        .label = null,
        .inline_token = null,
        .while_token = while_token,
        .condition = condition,
        .payload = payload,
        .continue_expr = continue_expr,
        .body = undefined, // set by caller
        .@"else" = null,
    };
    return &node.base;
}

// ForPrefix <- KEYWORD_for LPAREN Expr RPAREN PtrIndexPayload
fn parseForPrefix(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const for_token = eatToken(it, .Keyword_for) orelse return null;

    _ = (try expectToken(it, tree, .LParen)) orelse return null;
    const array_expr = (try expectNode(arena, it, tree, parseExpr, Error{
        .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
    })) orelse return null;
    _ = (try expectToken(it, tree, .RParen)) orelse return null;

    const payload = (try expectNode(arena, it, tree, parsePtrIndexPayload, Error{
        // TODO
        .InvalidToken = Error.InvalidToken{ .token = it.peek().?.start },
    })) orelse return null;

    const node = try arena.create(Node.For);
    node.* = Node.For{
        .base = Node{ .id = .For },
        .label = null,
        .inline_token = null,
        .for_token = for_token,
        .array_expr = array_expr,
        .payload = payload, // TODO: why is this field optional?
        .body = undefined, // set by caller
        .@"else" = null,
    };
    return &node.base;
}

// Payload <- PIPE IDENTIFIER PIPE
fn parsePayload(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const lpipe = eatToken(it, .Pipe) orelse return null;
    const identifier = (try expectNode(arena, it, tree, parseIdentifier, Error{
        .ExpectedIdentifier = Error.ExpectedIdentifier{ .token = it.peek().?.start },
    })) orelse return null;
    const rpipe = (try expectToken(it, tree, .Pipe)) orelse return null;

    const node = try arena.create(Node.Payload);
    node.* = Node.Payload{
        .base = Node{ .id = .Payload },
        .lpipe = lpipe,
        .error_symbol = identifier,
        .rpipe = rpipe,
    };
    return &node.base;
}

// PtrPayload <- PIPE ASTERISK? IDENTIFIER PIPE
fn parsePtrPayload(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const lpipe = eatToken(it, .Pipe) orelse return null;
    const asterisk = eatToken(it, .Asterisk);
    const identifier = (try expectNode(arena, it, tree, parseIdentifier, Error{
        .ExpectedIdentifier = Error.ExpectedIdentifier{ .token = it.peek().?.start },
    })) orelse return null;
    const rpipe = (try expectToken(it, tree, .Pipe)) orelse return null;

    const node = try arena.create(Node.PointerPayload);
    node.* = Node.PointerPayload{
        .base = Node{ .id = .PointerPayload },
        .lpipe = lpipe,
        .ptr_token = asterisk,
        .value_symbol = identifier,
        .rpipe = rpipe,
    };
    return &node.base;
}

// PtrIndexPayload <- PIPE ASTERISK? IDENTIFIER (COMMA IDENTIFIER)? PIPE
fn parsePtrIndexPayload(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const lpipe = eatToken(it, .Pipe) orelse return null;
    const asterisk = eatToken(it, .Asterisk);
    const index = blk: {
        if (eatToken(it, .Asterisk) == null) break :blk null;
        break :blk (try expectNode(arena, it, tree, parseIdentifier, Error{
            .ExpectedIdentifier = Error.ExpectedIdentifier{ .token = it.peek().?.start },
        })) orelse return null;
    };
    const identifier = (try expectNode(arena, it, tree, parseIdentifier, Error{
        .ExpectedIdentifier = Error.ExpectedIdentifier{ .token = it.peek().?.start },
    })) orelse return null;
    const rpipe = (try expectToken(it, tree, .Pipe)) orelse return null;

    const node = try arena.create(Node.PointerIndexPayload);
    node.* = Node.PointerIndexPayload{
        .base = Node{ .id = .PointerIndexPayload },
        .lpipe = lpipe,
        .ptr_token = asterisk,
        .value_symbol = identifier,
        .index_symbol = index,
        .rpipe = rpipe,
    };
    return &node.base;
}

// SwitchProng <- SwitchCase EQUALRARROW PtrPayload? AssignExpr
fn parseSwitchProng(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseSwitchCase(arena, it, tree)) orelse return null;
    const arrow = (try expectToken(it, tree, .EqualAngleBracketRight)) orelse return null;
    const payload = try parsePtrPayload(arena, it, tree);
    const expr = (try expectNode(arena, it, tree, parseAssignExpr, Error{
        .ExpectedExprOrAssignment = Error.ExpectedExprOrAssignment{ .token = it.peek().?.start },
    })) orelse return null;

    const switch_case = node.cast(Node.SwitchCase).?;
    switch_case.arrow_token = arrow;
    switch_case.payload = payload;
    switch_case.expr = expr;

    return node;
}

// SwitchCase
//     <- SwitchItem (COMMA SwitchItem)* COMMA?
//      / KEYWORD_else
fn parseSwitchCase(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    var list = Node.SwitchCase.ItemList.init(arena);

    if (try parseSwitchItem(arena, it, tree)) |first_item| {
        try list.push(first_item);
        while (eatToken(it, .Comma) != null) {
            const next_item = (try parseSwitchItem(arena, it, tree)) orelse break;
            try list.push(next_item);
        }
    } else if (eatToken(it, .Keyword_else)) |else_token| {
        const else_node = try arena.create(Node.SwitchElse);
        else_node.* = Node.SwitchElse{
            .base = Node{ .id = .SwitchElse },
            .token = else_token,
        };
        try list.push(&else_node.base);
    } else return null;

    const node = try arena.create(Node.SwitchCase);
    node.* = Node.SwitchCase{
        .base = Node{ .id = .SwitchCase },
        .items = list,
        .arrow_token = undefined, // set by caller
        .payload = null,
        .expr = undefined, // set by caller
    };
    return &node.base;
}

// SwitchItem <- Expr (DOT3 Expr)?
fn parseSwitchItem(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const expr = (try parseExpr(arena, it, tree)) orelse return null;
    if (eatToken(it, .Ellipsis3)) |token| {
        const range_end = (try expectNode(arena, it, tree, parseExpr, Error{
            .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
        })) orelse return null;

        const node = try arena.create(Node.InfixOp);
        node.* = Node.InfixOp{
            .base = Node{ .id = .InfixOp },
            .op_token = token,
            .lhs = expr,
            .op = Node.InfixOp.Op{ .Range = {} },
            .rhs = range_end,
        };
        return &node.base;
    }
    return expr;
}

// AssignOp
//     <- ASTERISKEQUAL
//      / SLASHEQUAL
//      / PERCENTEQUAL
//      / PLUSEQUAL
//      / MINUSEQUAL
//      / LARROW2EQUAL
//      / RARROW2EQUAL
//      / AMPERSANDEQUAL
//      / CARETEQUAL
//      / PIPEEQUAL
//      / ASTERISKPERCENTEQUAL
//      / PLUSPERCENTEQUAL
//      / MINUSPERCENTEQUAL
//      / EQUAL
fn parseAssignOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return error.NotImplemented; // TODO
}

// CompareOp
//     <- EQUALEQUAL
//      / EXCLAMATIONMARKEQUAL
//      / LARROW
//      / RARROW
//      / LARROWEQUAL
//      / RARROWEQUAL
fn parseCompareOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const ops = Node.InfixOp.Op;

    const token = nextNonCommentToken(it);
    const op = switch (token.ptr.id) {
        .EqualEqual => ops{ .EqualEqual = {} },
        .BangEqual => ops{ .BangEqual = {} },
        .AngleBracketLeft => ops{ .LessThan = {} },
        .AngleBracketRight => ops{ .GreaterThan = {} },
        .AngleBracketLeftEqual => ops{ .LessOrEqual = {} },
        .AngleBracketRightEqual => ops{ .GreaterOrEqual = {} },
        else => {
            _ = rewindTokenIterator(it);
            return null;
        },
    };

    return try createInfixOp(arena, it.index, op);
}

// BitwiseOp
//     <- AMPERSAND
//      / CARET
//      / PIPE
//      / KEYWORD_orelse
//      / KEYWORD_catch Payload?
fn parseBitwiseOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const ops = Node.InfixOp.Op;

    const token = nextNonCommentToken(it);
    const op = switch (token.ptr.id) {
        .Ampersand => ops{ .BitAnd = {} },
        .Caret => ops{ .BitXor = {} },
        .Pipe => ops{ .BitOr = {} },
        .Keyword_orelse => ops{ .UnwrapOptional = {} },
        .Keyword_catch => ops{ .Catch = try parsePayload(arena, it, tree) },
        else => {
            _ = rewindTokenIterator(it);
            return null;
        },
    };

    return try createInfixOp(arena, it.index, op);
}

// BitShiftOp
//     <- LARROW2
//      / RARROW2
fn parseBitShiftOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const ops = Node.InfixOp.Op;

    const token = nextNonCommentToken(it);
    const op = switch (token.ptr.id) {
        .AngleBracketAngleBracketLeft => ops{ .BitShiftLeft = {} },
        .AngleBracketAngleBracketRight => ops{ .BitShiftRight = {} },
        else => {
            _ = rewindTokenIterator(it);
            return null;
        },
    };

    return try createInfixOp(arena, it.index, op);
}

// AdditionOp
//     <- PLUS
//      / MINUS
//      / PLUS2
//      / PLUSPERCENT
//      / MINUSPERCENT
fn parseAdditionOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const ops = Node.InfixOp.Op;

    const token = nextNonCommentToken(it);
    const op = switch (token.ptr.id) {
        .Plus => ops{ .Add = {} },
        .Minus => ops{ .Sub = {} },
        .PlusPlus => ops{ .ArrayCat = {} },
        .PlusPercent => ops{ .AddWrap = {} },
        .MinusPercent => ops{ .SubWrap = {} },
        else => {
            _ = rewindTokenIterator(it);
            return null;
        },
    };

    return try createInfixOp(arena, it.index, op);
}

// MultiplyOp
//     <- PIPE2
//      / ASTERISK
//      / SLASH
//      / PERCENT
//      / ASTERISK2
//      / ASTERISKPERCENT
fn parseMultiplyOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const ops = Node.InfixOp.Op;

    const token = nextNonCommentToken(it);
    const op = switch (token.ptr.id) {
        .PipePipe => ops{ .BoolOr = {} },
        .Asterisk => ops{ .Mult = {} },
        .Slash => ops{ .Div = {} },
        .Percent => ops{ .Mod = {} },
        .AsteriskAsterisk => ops{ .ArrayMult = {} },
        .AsteriskPercent => ops{ .MultWrap = {} },
        else => {
            _ = rewindTokenIterator(it);
            return null;
        },
    };

    return try createInfixOp(arena, it.index, op);
}

// PrefixOp
//     <- EXCLAMATIONMARK
//      / MINUS
//      / TILDE
//      / MINUSPERCENT
//      / AMPERSAND
//      / KEYWORD_try
//      / KEYWORD_await
fn parsePrefixOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const ops = Node.PrefixOp.Op;

    const token = nextNonCommentToken(it);
    const op = switch (token.ptr.id) {
        .Bang => ops{ .BoolNot = {} },
        .Minus => ops{ .Negation = {} },
        .Tilde => ops{ .BitNot = {} },
        .MinusPercent => ops{ .NegationWrap = {} },
        .Ampersand => ops{ .AddressOf = {} },
        .Keyword_try => ops{ .Try = {} },
        .Keyword_await => ops{ .Await = {} },
        else => {
            _ = rewindTokenIterator(it);
            return null;
        },
    };

    const node = try arena.create(Node.PrefixOp);
    node.* = Node.PrefixOp{
        .base = Node{ .id = .PrefixOp },
        .op_token = it.index,
        .op = op,
        .rhs = undefined,
    };
    return &node.base;
}

// TODO: last choice allows for `*const volatile volatile const`, `*align(4) align(8) align(4)` etc.
// PrefixTypeOp
//     <- QUESTIONMARK
//      / KEYWORD_promise MINUSRARROW
//      / ArrayTypeStart (ByteAlign / KEYWORD_const / KEYWORD_volatile)*
//      / PtrTypeStart (KEYWORD_align LPAREN Expr (COLON INTEGER COLON INTEGER)? RPAREN / KEYWORD_const / KEYWORD_volatile)*
fn parsePrefixTypeOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    if (eatToken(it, .QuestionMark)) |token| {
        const node = try arena.create(Node.PrefixOp);
        node.* = Node.PrefixOp{
            .base = Node{ .id = .PrefixOp },
            .op_token = token,
            .op = Node.PrefixOp.Op.OptionalType,
            .rhs = undefined, // set by caller
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_promise)) |token| {
        const arrow = (try expectToken(it, tree, .Arrow)) orelse return null;
        const node = try arena.create(Node.PromiseType);
        node.* = Node.PromiseType{
            .base = Node{ .id = .PromiseType },
            .promise_token = token,
            .result = null,
        };
        return &node.base;
    }

    if (try parseArrayTypeStart(arena, it, tree)) |node| {
        // TODO: Set node.rhs
        while (true) {
            if (try parseByteAlign(arena, it, tree)) |byte_align| {
                // TODO
                continue;
            }

            if (eatToken(it, .Keyword_const)) |const_token| {
                // TODO
                continue;
            }

            if (eatToken(it, .Keyword_volatile)) |volatile_token| {
                // TODO
                continue;
            }

            break;
        }
        // return null;
        return error.NotImplemented;
    }

    if (try parsePtrTypeStart(arena, it, tree)) |node| {
        while (true) {
            // TODO: allowzero
            if (eatToken(it, .Keyword_align)) |align_token| {
                const lparen = (try expectToken(it, tree, .LParen)) orelse return null;
                const expr_node = (try expectNode(arena, it, tree, parseExpr, Error{
                    .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
                })) orelse return null;

                // Optional bit range
                const bit_range = if (eatToken(it, .Colon)) |_| bit_range_value: {
                    const range_start = (try expectNode(arena, it, tree, parseIntegerLiteral, Error{
                        .ExpectedIntegerLiteral = Error.ExpectedIntegerLiteral{ .token = it.peek().?.start },
                    })) orelse return null;
                    _ = (try expectToken(it, tree, .Colon)) orelse return null;
                    const range_end = (try expectNode(arena, it, tree, parseIntegerLiteral, Error{
                        .ExpectedIntegerLiteral = Error.ExpectedIntegerLiteral{ .token = it.peek().?.start },
                    })) orelse return null;

                    break :bit_range_value Node.PrefixOp.PtrInfo.Align.BitRange{
                        .start = range_start,
                        .end = range_end,
                    };
                } else null;
                _ = (try expectToken(it, tree, .RParen)) orelse return null;

                node.cast(Node.PrefixOp).?.op.PtrType.align_info = Node.PrefixOp.PtrInfo.Align{
                    .node = expr_node,
                    .bit_range = bit_range,
                };

                continue;
            } else if (eatToken(it, .Keyword_const)) |const_token| ptr_info_value: {
                node.cast(Node.PrefixOp).?.op.PtrType.const_token = const_token;
                continue;
            } else if (eatToken(it, .Keyword_volatile)) |volatile_token| {
                node.cast(Node.PrefixOp).?.op.PtrType.volatile_token = volatile_token;
                continue;
            }
            break;
        }
    }

    return null;
}

// SuffixOp
//     <- LBRACKET Expr (DOT2 Expr?)? RBRACKET
//      / DOT IDENTIFIER
//      / DOTASTERISK
//      / DOTQUESTIONMARK
fn parseSuffixOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    if (eatToken(it, .LBracket)) |_| {
        const expr_node = (try expectNode(arena, it, tree, parseExpr, Error{
            .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
        })) orelse return null;
        const dots = eatToken(it, .Ellipsis2);
        const expr = if (dots) |_| try parseExpr(arena, it, tree) else null;
        _ = (try expectToken(it, tree, .RBracket)) orelse return null;
        return error.NotImplemented; // TODO
    }

    if (eatToken(it, .Period)) |_| {
        const identifier = (try expectToken(it, tree, .Identifier)) orelse return null;
        return error.NotImplemented; // TODO
    }

    if (eatToken(it, .Period)) |period| {
        if (eatToken(it, .Asterisk)) |asterisk| {
            const node = try arena.create(Node.SuffixOp);
            node.* = Node.SuffixOp{
                .base = Node{ .id = .SuffixOp },
                .lhs = undefined, // TODO
                .op = Node.SuffixOp.Op.Deref,
                .rtoken = undefined, // TODO
            };
            return &node.base;
        }
        if (eatToken(it, .QuestionMark)) |question_mark| {
            const node = try arena.create(Node.SuffixOp);
            node.* = Node.SuffixOp{
                .base = Node{ .id = .SuffixOp },
                .lhs = undefined, // TODO
                .op = Node.SuffixOp.Op.UnwrapOptional,
                .rtoken = undefined, // TODO
            };
            return &node.base;
        }
        try tree.errors.push(Error{
            .ExpectedDerefOrUnwrap = Error.ExpectedDerefOrUnwrap{ .token = it.peek().?.start },
        });
        return null;
    }

    return null;
}

// AsyncPrefix <- KEYWORD_async (LARROW PrefixExpr RARROW)?
fn parseAsyncPrefix(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const async_token = eatToken(it, .Keyword_async) orelse return null;
    var rangle_bracket: ?TokenIndex = null;
    const expr_node = if (eatToken(it, .AngleBracketLeft)) |_| blk: {
        const prefix_expr = (try expectNode(arena, it, tree, parsePrefixExpr, Error{
            .ExpectedPrefixExpr = Error.ExpectedPrefixExpr{ .token = it.peek().?.start },
        })) orelse return null;
        rangle_bracket = (try expectToken(it, tree, .AngleBracketRight)) orelse return null;
        break :blk prefix_expr;
    } else null;

    const node = try arena.create(Node.AsyncAttribute);
    node.* = Node.AsyncAttribute{
        .base = Node{ .id = .AsyncAttribute },
        .async_token = async_token,
        .allocator_type = expr_node,
        .rangle_bracket = rangle_bracket,
    };
    return &node.base;
}

// FnCallArguments <- LPAREN ExprList RPAREN
// ExprList <- (Expr COMMA)* Expr?
fn parseFnCallArguments(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?Node.SuffixOp.Op.Call.ParamList {
    if (eatToken(it, .LParen) == null) return null;
    const list = try ListParser(Node.SuffixOp.Op.Call.ParamList, parseExpr).parse(arena, it, tree);
    _ = (try expectToken(it, tree, .RParen)) orelse return null;
    return list;
}

// ArrayTypeStart <- LBRACKET Expr? RBRACKET
fn parseArrayTypeStart(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const lbracket = eatToken(it, .LBracket) orelse return null;
    const expr = (try parseExpr(arena, it, tree)) orelse return null;
    const rbracket = (try expectToken(it, tree, .RBracket)) orelse return null;

    const node = try arena.create(Node.PrefixOp);
    node.* = Node.PrefixOp{
        .base = Node{ .id = .PrefixOp },
        .op_token = lbracket,
        .op = Node.PrefixOp.Op{ .ArrayType = expr },
        .rhs = undefined, // set by caller
    };
    return &node.base;
}

// PtrTypeStart
//     <- ASTERISK
//      / ASTERISK2
//      / PTRUNKNOWN
//      / PTRC
fn parsePtrTypeStart(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = eatToken(it, .Asterisk) orelse
        eatToken(it, .AsteriskAsterisk) orelse
        eatToken(it, .BracketStarBracket) orelse
        eatToken(it, .BracketStarCBracket) orelse
        null;

    if (token) |op_token| {
        const node = try arena.create(Node.PrefixOp);
        node.* = Node.PrefixOp{
            .base = Node{ .id = .PrefixOp },
            .op_token = op_token,
            .op = Node.PrefixOp.Op{
                .PtrType = Node.PrefixOp.PtrInfo{
                    .allowzero_token = null,
                    .align_info = null,
                    .const_token = null,
                    .volatile_token = null,
                },
            },
            .rhs = undefined, // set by caller
        };
        return &node.base;
    } else return null;
    // TODO: zig fmt allows expression body of `if` on its own line, but forces the expression
    // body of an `else if` to be all on the same line
}

// ContainerDeclAuto <- ContainerDeclType LBRACE ContainerMembers RBRACE
fn parseContainerDeclAuto(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseContainerDeclType(arena, it, tree)) orelse return null;
    const lbrace = (try expectToken(it, tree, .LBrace)) orelse return null;
    const kind = it.list.at(node.cast(Node.ContainerDecl).?.kind_token).id;
    const members = (try parseContainerMembers(arena, it, tree, kind)) orelse return null;
    const rbrace = (try expectToken(it, tree, .RBrace)) orelse return null;

    const decl_type = node.cast(Node.ContainerDecl).?;
    decl_type.fields_and_decls = members;
    decl_type.lbrace_token = lbrace;
    decl_type.rbrace_token = rbrace;

    return node;
}

// ContainerDeclType
//     <- (KEYWORD_struct / KEYWORD_enum) (LPAREN Expr RPAREN)?
//      / KEYWORD_union (LPAREN (KEYWORD_enum (LPAREN Expr RPAREN)? / Expr) RPAREN)?
fn parseContainerDeclType(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const container_type = eatToken(it, .Keyword_struct) orelse eatToken(it, .Keyword_enum);
    if (container_type) |kind_token| {
        // TODO: https://github.com/ziglang/zig/issues/2330
        const init_arg_expr = if (eatToken(it, .LParen) != null) blk: {
            const expr = (try expectNode(arena, it, tree, parseExpr, Error{
                .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
            })) orelse return null;
            _ = (try expectToken(it, tree, .RParen)) orelse return null;
            break :blk Node.ContainerDecl.InitArg{ .Type = expr };
        } else Node.ContainerDecl.InitArg{ .None = {} };

        const node = try arena.create(Node.ContainerDecl);
        node.* = Node.ContainerDecl{
            .base = Node{ .id = .ContainerDecl },
            .layout_token = null,
            .kind_token = kind_token,
            .init_arg_expr = init_arg_expr,
            .fields_and_decls = undefined, // set by caller
            .lbrace_token = undefined, // set by caller
            .rbrace_token = undefined, // set by caller
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_union)) |kind_token| {
        const init_arg_expr = if (eatToken(it, .LParen) != null) set_init_arg: {
            if (eatToken(it, .Keyword_enum) != null) {
                const enum_expr = if (eatToken(it, .LParen) != null) set_enum_expr: {
                    const expr = (try expectNode(arena, it, tree, parseExpr, Error{
                        .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
                    })) orelse return null;
                    _ = (try expectToken(it, tree, .RParen)) orelse return null;
                    break :set_enum_expr expr;
                } else null;
                break :set_init_arg Node.ContainerDecl.InitArg{ .Enum = enum_expr };
            }

            const expr = (try expectNode(arena, it, tree, parseExpr, Error{
                .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
            })) orelse return null;
            _ = (try expectToken(it, tree, .RParen)) orelse return null;
            break :set_init_arg Node.ContainerDecl.InitArg{ .Type = expr };
        } else Node.ContainerDecl.InitArg{ .None = {} };

        const node = try arena.create(Node.ContainerDecl);
        node.* = Node.ContainerDecl{
            .base = Node{ .id = .ContainerDecl },
            .layout_token = null,
            .kind_token = kind_token,
            .init_arg_expr = init_arg_expr,
            .fields_and_decls = undefined, // set by caller
            .lbrace_token = undefined, // set by caller
            .rbrace_token = undefined, // set by caller
        };
        return &node.base;
    }

    return null;
}

// ByteAlign <- KEYWORD_align LPAREN Expr RPAREN
fn parseByteAlign(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const align_token = eatToken(it, .Keyword_align) orelse return null;
    _ = (try expectToken(it, tree, .LParen)) orelse return null;
    const align_expr = (try expectNode(arena, it, tree, parseExpr, Error{
        .ExpectedExpr = Error.ExpectedExpr{ .token = it.peek().?.start },
    })) orelse return null;
    _ = (try expectToken(it, tree, .RParen)) orelse return null;

    const node = try arena.create(Node.PrefixOp);
    node.* = Node.PrefixOp{
        .base = Node{ .id = .PrefixOp },
        .op_token = align_token,
        .op = Node.PrefixOp.Op{
            .PtrType = Node.PrefixOp.PtrInfo{
                .allowzero_token = null,
                .align_info = Node.PrefixOp.PtrInfo.Align{
                    .node = align_expr,
                    .bit_range = null,
                },
                .const_token = null,
                .volatile_token = null,
            },
        },
        .rhs = undefined, // set by caller
    };

    return &node.base;
}

// IdentifierList <- (IDENTIFIER COMMA)* IDENTIFIER?
fn parseIdentifierList(arena: *Allocator, it: *TokenIterator, tree: *Tree) !Node.ErrorSetDecl.DeclList {
    // ErrorSetDecl.DeclList is used since ErrorSetDecl is the only caller of this function.
    return try ListParser(Node.ErrorSetDecl.DeclList, parseIdentifier).parse(arena, it, tree);
}

// SwitchProngList <- (SwitchProng COMMA)* SwitchProng?
fn parseSwitchProngList(arena: *Allocator, it: *TokenIterator, tree: *Tree) !Node.Switch.CaseList {
    return try ListParser(Node.Switch.CaseList, parseSwitchProng).parse(arena, it, tree);
}

// AsmOutputList <- (AsmOutputItem COMMA)* AsmOutputItem?
fn parseAsmOutputList(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return try ListParser(Node.Asm.OutputList, parseAsmOutputItem).parse(arena, it, tree);
}

// AsmInputList <- (AsmInputItem COMMA)* AsmInputItem?
fn parseAsmInputList(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return try ListParser(Node.Asm.InputList, parseAsmInputItem).parse(arena, it, tree);
}

// ParamDeclList <- (ParamDecl COMMA)* ParamDecl?
fn parseParamDeclList(arena: *Allocator, it: *TokenIterator, tree: *Tree) !Node.FnProto.ParamList {
    return try ListParser(Node.FnProto.ParamList, parseParamDecl).parse(arena, it, tree);
}

// TODO: don't use anyerror
const ParseFn = fn (*Allocator, *TokenIterator, *Tree) anyerror!?*Node;

// Helper parsers not included in the grammar

fn parseIdentifier(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = eatToken(it, .Identifier) orelse return null;
    const node = try arena.create(Node.Identifier);
    node.* = Node.Identifier{
        .base = Node{ .id = .Identifier },
        .token = token,
    };
    return &node.base;
}

fn createLiteral(arena: *Allocator, comptime T: type, token: TokenIndex) !*Node {
    const result = try arena.create(T);
    result.* = T{
        .base = Node{ .id = Node.typeToId(T) },
        .token = token,
    };
    return &result.base;
}

// string literal or multiline string literal
fn parseStringLiteral(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    if (eatToken(it, .StringLiteral)) |token| {
        const node = try arena.create(Node.StringLiteral);
        node.* = Node.StringLiteral{
            .base = Node{ .id = .StringLiteral },
            .token = token,
        };
        return &node.base;
    }

    if (eatToken(it, .MultilineStringLiteralLine)) |first_line| {
        const node = try arena.create(Node.MultilineStringLiteral);
        node.* = Node.MultilineStringLiteral{
            .base = Node{ .id = .MultilineStringLiteral },
            .lines = Node.MultilineStringLiteral.LineList.init(arena),
        };
        try node.lines.push(first_line);
        while (eatToken(it, .MultilineStringLiteralLine)) |line|
            try node.lines.push(line);

        return &node.base;
    }

    return null;
}

fn parseIntegerLiteral(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = eatToken(it, .IntegerLiteral) orelse return null;
    const node = try arena.create(Node.IntegerLiteral);
    node.* = Node.IntegerLiteral{
        .base = Node{ .id = .IntegerLiteral },
        .token = token,
    };
    return &node.base;
}

fn parseFloatLiteral(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = eatToken(it, .FloatLiteral) orelse return null;
    const node = try arena.create(Node.FloatLiteral);
    node.* = Node.FloatLiteral{
        .base = Node{ .id = .FloatLiteral },
        .token = token,
    };
    return &node.base;
}

fn parseTry(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = eatToken(it, .Keyword_try) orelse return null;
    const node = try arena.create(Node.PrefixOp);
    node.* = Node.PrefixOp{
        .base = Node{ .id = .PrefixOp },
        .op_token = token,
        .op = Node.PrefixOp.Op.Try,
        .rhs = undefined, // set by caller
    };
    return &node.base;
}

fn parseUse(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = eatToken(it, .Keyword_use) orelse return null;
    const node = try arena.create(Node.Use);
    node.* = Node.Use{
        .base = Node{ .id = .PrefixOp },
        .doc_comments = null,
        .visib_token = null,
        .use_token = token,
        .expr = undefined,
        .semicolon_token = undefined,
    };
    return &node.base;
}

// Op* Child
fn parsePrefixOpExpr(
    arena: *Allocator,
    it: *TokenIterator,
    tree: *Tree,
    opParseFn: ParseFn,
    childParseFn: ParseFn,
) !?*Node {
    if (try opParseFn(arena, it, tree)) |op| {
        const child = (try expectNode(
            arena,
            it,
            tree,
            childParseFn,
            Error{
                .InvalidToken = Error.InvalidToken{ .token = it.peek().?.start },
            },
        )) orelse return null;
        op.cast(Node.PrefixOp).?.rhs = child;
        return op;
    }
    return childParseFn(arena, it, tree);
}

// Child (Op Child)(*/?)
fn parseBinOpExpr(
    arena: *Allocator,
    it: *TokenIterator,
    tree: *Tree,
    opParseFn: ParseFn,
    childParseFn: ParseFn,
    chain: BinOpChain,
) !?*Node {
    var res = (try childParseFn(arena, it, tree)) orelse return null;

    while (try opParseFn(arena, it, tree)) |node| {
        const right = (try expectNode(arena, it, tree, childParseFn, Error{
            .InvalidToken = Error.InvalidToken{ .token = it.peek().?.start },
        })) orelse return null;
        const left = res;
        res = node;

        const op = node.cast(Node.InfixOp).?;
        op.*.lhs = left;
        op.*.rhs = right;

        switch (chain) {
            .Once => break,
            .Infinitely => continue,
        }
    }

    return res;
}

fn SimpleBinOpParser(token: Token.Id, op: Node.InfixOp.Op) type {
    return struct {
        pub fn parse(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
            const op_token = eatToken(it, token) orelse return null;
            const node = try arena.create(Node.InfixOp);
            node.* = Node.InfixOp{
                .base = Node{ .id = .InfixOp },
                .op_token = op_token,
                .lhs = undefined, // set by caller
                .op = op,
                .rhs = undefined, // set by caller
            };
            return &node.base;
        }
    };
}

const BinOpChain = enum {
    Once,
    Infinitely,
};

fn createInfixOp(arena: *Allocator, index: TokenIndex, op: Node.InfixOp.Op) !*Node {
    const node = try arena.create(Node.InfixOp);
    node.* = Node.InfixOp{
        .base = Node{ .id = .InfixOp },
        .op_token = index,
        .lhs = undefined,
        .op = op,
        .rhs = undefined,
    };
    return &node.base;
}

fn eatToken(it: *TokenIterator, id: Token.Id) ?TokenIndex {
    return if (it.peek().?.id == id) nextNonCommentToken(it).index else null;
}

fn expectToken(it: *TokenIterator, tree: *Tree, id: Token.Id) !?TokenIndex {
    const token = nextNonCommentToken(it);
    if (token.ptr.id != id) {
        try tree.errors.push(Error{
            .ExpectedToken = Error.ExpectedToken{ .token = token.index, .expected_id = id },
        });
        return null;
    }
    return token.index;
}

fn nextNonCommentToken(it: *TokenIterator) AnnotatedToken {
    const result = AnnotatedToken{
        .index = it.index,
        .ptr = it.next().?,
    };
    assert(result.ptr.id != .LineComment);

    while (true) {
        const next_tok = it.peek() orelse return result;
        if (next_tok.id != .LineComment) return result;
        _ = it.next();
    }
}

fn rewindTokenIterator(it: *TokenIterator) void {
    while (true) {
        const prev_tok = it.prev() orelse return;
        if (prev_tok.id == .LineComment) continue;
        return;
    }
}

const AnnotatedToken = struct {
    index: TokenIndex,
    ptr: *Token,
};

fn expectNode(
    arena: *Allocator,
    it: *TokenIterator,
    tree: *Tree,
    parseFn: ParseFn,
    err: Error, // if parsing fails
) !?*Node {
    const node = try parseFn(arena, it, tree);
    if (node == null) try tree.errors.push(err);
    return node;
}

fn ListParser(comptime L: type, comptime nodeParseFn: var) type {
    return struct {
        pub fn parse(arena: *Allocator, it: *TokenIterator, tree: *Tree) !L {
            var list = L.init(arena);
            while (try nodeParseFn(arena, it, tree)) |node| {
                try list.push(node);
                if (eatToken(it, .Colon) == null) break;
            }
            return list;
        }
    };
}

test "std.zig.parser" {
    _ = @import("parser_test.zig");
}
