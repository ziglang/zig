const std = @import("../std.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ast = std.zig.ast;
const Node = ast.Node;
const Tree = ast.Tree;
const AstError = ast.Error;
const TokenIndex = ast.TokenIndex;
const Token = std.zig.Token;
const TokenIterator = Tree.TokenList.Iterator;

pub const Error = error{ParseError} || Allocator.Error;

/// Result should be freed with tree.deinit() when there are
/// no more references to any of the tokens or nodes.
pub fn parse(allocator: *Allocator, source: []const u8) Allocator.Error!*Tree {
    const tree = blk: {
        // This block looks unnecessary, but is a "foot-shield" to prevent the SegmentedLists
        // from being initialized with a pointer to this `arena`, which is created on
        // the stack. Following code should instead refer to `&tree.arena_allocator`, a
        // pointer to data which lives safely on the heap and will outlive `parse`. See:
        // https://github.com/ziglang/zig/commit/cb4fb14b6e66bd213575f69eec9598be8394fae6
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();
        const tree = try arena.allocator.create(ast.Tree);
        tree.* = .{
            .source = source,
            .root_node = undefined,
            .arena_allocator = arena,
            .tokens = undefined,
            .errors = undefined,
        };
        break :blk tree;
    };
    errdefer tree.deinit();
    const arena = &tree.arena_allocator.allocator;

    tree.tokens = ast.Tree.TokenList.init(arena);
    tree.errors = ast.Tree.ErrorList.init(arena);

    var tokenizer = std.zig.Tokenizer.init(source);
    while (true) {
        const tree_token = try tree.tokens.addOne();
        tree_token.* = tokenizer.next();
        if (tree_token.id == .Eof) break;
    }
    var it = tree.tokens.iterator(0);

    while (it.peek().?.id == .LineComment) _ = it.next();

    tree.root_node = try parseRoot(arena, &it, tree);

    return tree;
}

/// Root <- skip ContainerMembers eof
fn parseRoot(arena: *Allocator, it: *TokenIterator, tree: *Tree) Allocator.Error!*Node.Root {
    const node = try arena.create(Node.Root);
    node.* = .{
        .decls = try parseContainerMembers(arena, it, tree, true),
        // parseContainerMembers will try to skip as much
        // invalid tokens as it can so this can only be the EOF
        .eof_token = eatToken(it, .Eof).?,
    };
    return node;
}

/// ContainerMembers
///     <- TestDecl ContainerMembers
///      / TopLevelComptime ContainerMembers
///      / KEYWORD_pub? TopLevelDecl ContainerMembers
///      / ContainerField COMMA ContainerMembers
///      / ContainerField
///      /
fn parseContainerMembers(arena: *Allocator, it: *TokenIterator, tree: *Tree, top_level: bool) !Node.Root.DeclList {
    var list = Node.Root.DeclList.init(arena);

    var field_state: union(enum) {
        /// no fields have been seen
        none,
        /// currently parsing fields
        seen,
        /// saw fields and then a declaration after them.
        /// payload is first token of previous declaration.
        end: TokenIndex,
        /// ther was a declaration between fields, don't report more errors
        err,
    } = .none;

    while (true) {
        if (try parseContainerDocComments(arena, it, tree)) |node| {
            try list.push(node);
            continue;
        }

        const doc_comments = try parseDocComment(arena, it, tree);

        if (parseTestDecl(arena, it, tree) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.ParseError => {
                findNextContainerMember(it);
                continue;
            },
        }) |node| {
            if (field_state == .seen) {
                field_state = .{ .end = node.firstToken() };
            }
            node.cast(Node.TestDecl).?.doc_comments = doc_comments;
            try list.push(node);
            continue;
        }

        if (parseTopLevelComptime(arena, it, tree) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.ParseError => {
                findNextContainerMember(it);
                continue;
            },
        }) |node| {
            if (field_state == .seen) {
                field_state = .{ .end = node.firstToken() };
            }
            node.cast(Node.Comptime).?.doc_comments = doc_comments;
            try list.push(node);
            continue;
        }

        const visib_token = eatToken(it, .Keyword_pub);

        if (parseTopLevelDecl(arena, it, tree) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.ParseError => {
                findNextContainerMember(it);
                continue;
            },
        }) |node| {
            if (field_state == .seen) {
                field_state = .{ .end = visib_token orelse node.firstToken() };
            }
            switch (node.id) {
                .FnProto => {
                    node.cast(Node.FnProto).?.doc_comments = doc_comments;
                    node.cast(Node.FnProto).?.visib_token = visib_token;
                },
                .VarDecl => {
                    node.cast(Node.VarDecl).?.doc_comments = doc_comments;
                    node.cast(Node.VarDecl).?.visib_token = visib_token;
                },
                .Use => {
                    node.cast(Node.Use).?.doc_comments = doc_comments;
                    node.cast(Node.Use).?.visib_token = visib_token;
                },
                else => unreachable,
            }
            try list.push(node);
            if (try parseAppendedDocComment(arena, it, tree, node.lastToken())) |appended_comment| {
                switch (node.id) {
                    .FnProto => {},
                    .VarDecl => node.cast(Node.VarDecl).?.doc_comments = appended_comment,
                    .Use => node.cast(Node.Use).?.doc_comments = appended_comment,
                    else => unreachable,
                }
            }
            continue;
        }

        if (visib_token != null) {
            try tree.errors.push(.{
                .ExpectedPubItem = .{ .token = it.index },
            });
            // ignore this pub
            continue;
        }

        if (parseContainerField(arena, it, tree) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.ParseError => {
                // attempt to recover
                findNextContainerMember(it);
                continue;
            },
        }) |node| {
            switch (field_state) {
                .none => field_state = .seen,
                .err, .seen => {},
                .end => |tok| {
                    try tree.errors.push(.{
                        .DeclBetweenFields = .{ .token = tok },
                    });
                    // continue parsing, error will be reported later
                    field_state = .err;
                },
            }

            const field = node.cast(Node.ContainerField).?;
            field.doc_comments = doc_comments;
            try list.push(node);
            const comma = eatToken(it, .Comma) orelse {
                // try to continue parsing
                const index = it.index;
                findNextContainerMember(it);
                const next = it.peek().?.id;
                switch (next) {
                    .Eof => break,
                    else => {
                        if (next == .RBrace) {
                            if (!top_level) break;
                            _ = nextToken(it);
                        }

                        // add error and continue
                        try tree.errors.push(.{
                            .ExpectedToken = .{ .token = index, .expected_id = .Comma },
                        });
                        continue;
                    },
                }
            };
            if (try parseAppendedDocComment(arena, it, tree, comma)) |appended_comment|
                field.doc_comments = appended_comment;
            continue;
        }

        // Dangling doc comment
        if (doc_comments != null) {
            try tree.errors.push(.{
                .UnattachedDocComment = .{ .token = doc_comments.?.firstToken() },
            });
        }

        const next = it.peek().?.id;
        switch (next) {
            .Eof => break,
            .Keyword_comptime => {
                _ = nextToken(it);
                try tree.errors.push(.{
                    .ExpectedBlockOrField = .{ .token = it.index },
                });
            },
            else => {
                const index = it.index;
                if (next == .RBrace) {
                    if (!top_level) break;
                    _ = nextToken(it);
                }

                // this was likely not supposed to end yet,
                // try to find the next declaration
                findNextContainerMember(it);
                try tree.errors.push(.{
                    .ExpectedContainerMembers = .{ .token = index },
                });
            },
        }
    }

    return list;
}

/// Attempts to find next container member by searching for certain tokens
fn findNextContainerMember(it: *TokenIterator) void {
    var level: u32 = 0;
    while (true) {
        const tok = nextToken(it);
        switch (tok.ptr.id) {
            // any of these can start a new top level declaration
            .Keyword_test,
            .Keyword_comptime,
            .Keyword_pub,
            .Keyword_export,
            .Keyword_extern,
            .Keyword_inline,
            .Keyword_noinline,
            .Keyword_usingnamespace,
            .Keyword_threadlocal,
            .Keyword_const,
            .Keyword_var,
            .Keyword_fn,
            .Identifier,
            => {
                if (level == 0) {
                    putBackToken(it, tok.index);
                    return;
                }
            },
            .Comma, .Semicolon => {
                // this decl was likely meant to end here
                if (level == 0) {
                    return;
                }
            },
            .LParen, .LBracket, .LBrace => level += 1,
            .RParen, .RBracket => {
                if (level != 0) level -= 1;
            },
            .RBrace => {
                if (level == 0) {
                    // end of container, exit
                    putBackToken(it, tok.index);
                    return;
                }
                level -= 1;
            },
            .Eof => {
                putBackToken(it, tok.index);
                return;
            },
            else => {},
        }
    }
}

/// Attempts to find the next statement by searching for a semicolon
fn findNextStmt(it: *TokenIterator) void {
    var level: u32 = 0;
    while (true) {
        const tok = nextToken(it);
        switch (tok.ptr.id) {
            .LBrace => level += 1,
            .RBrace => {
                if (level == 0) {
                    putBackToken(it, tok.index);
                    return;
                }
                level -= 1;
            },
            .Semicolon => {
                if (level == 0) {
                    return;
                }
            },
            .Eof => {
                putBackToken(it, tok.index);
                return;
            },
            else => {},
        }
    }
}

/// Eat a multiline container doc comment
fn parseContainerDocComments(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    var lines = Node.DocComment.LineList.init(arena);
    while (eatToken(it, .ContainerDocComment)) |line| {
        try lines.push(line);
    }

    if (lines.len == 0) return null;

    const node = try arena.create(Node.DocComment);
    node.* = .{
        .lines = lines,
    };
    return &node.base;
}

/// TestDecl <- KEYWORD_test STRINGLITERALSINGLE Block
fn parseTestDecl(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const test_token = eatToken(it, .Keyword_test) orelse return null;
    const name_node = try expectNode(arena, it, tree, parseStringLiteralSingle, .{
        .ExpectedStringLiteral = .{ .token = it.index },
    });
    const block_node = try expectNode(arena, it, tree, parseBlock, .{
        .ExpectedLBrace = .{ .token = it.index },
    });

    const test_node = try arena.create(Node.TestDecl);
    test_node.* = .{
        .doc_comments = null,
        .test_token = test_token,
        .name = name_node,
        .body_node = block_node,
    };
    return &test_node.base;
}

/// TopLevelComptime <- KEYWORD_comptime BlockExpr
fn parseTopLevelComptime(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const tok = eatToken(it, .Keyword_comptime) orelse return null;
    const lbrace = eatToken(it, .LBrace) orelse {
        putBackToken(it, tok);
        return null;
    };
    putBackToken(it, lbrace);
    const block_node = try expectNode(arena, it, tree, parseBlockExpr, .{
        .ExpectedLabelOrLBrace = .{ .token = it.index },
    });

    const comptime_node = try arena.create(Node.Comptime);
    comptime_node.* = .{
        .doc_comments = null,
        .comptime_token = tok,
        .expr = block_node,
    };
    return &comptime_node.base;
}

/// TopLevelDecl
///     <- (KEYWORD_export / KEYWORD_extern STRINGLITERALSINGLE? / (KEYWORD_inline / KEYWORD_noinline))? FnProto (SEMICOLON / Block)
///      / (KEYWORD_export / KEYWORD_extern STRINGLITERALSINGLE?)? KEYWORD_threadlocal? VarDecl
///      / KEYWORD_usingnamespace Expr SEMICOLON
fn parseTopLevelDecl(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    var lib_name: ?*Node = null;
    const extern_export_inline_token = blk: {
        if (eatToken(it, .Keyword_export)) |token| break :blk token;
        if (eatToken(it, .Keyword_extern)) |token| {
            lib_name = try parseStringLiteralSingle(arena, it, tree);
            break :blk token;
        }
        if (eatToken(it, .Keyword_inline)) |token| break :blk token;
        if (eatToken(it, .Keyword_noinline)) |token| break :blk token;
        break :blk null;
    };

    if (try parseFnProto(arena, it, tree)) |node| {
        const fn_node = node.cast(Node.FnProto).?;
        fn_node.*.extern_export_inline_token = extern_export_inline_token;
        fn_node.*.lib_name = lib_name;
        if (eatToken(it, .Semicolon)) |_| return node;

        if (try expectNodeRecoverable(arena, it, tree, parseBlock, .{
            // since parseBlock only return error.ParseError on
            // a missing '}' we can assume this function was
            // supposed to end here.
            .ExpectedSemiOrLBrace = .{ .token = it.index },
        })) |body_node| {
            fn_node.body_node = body_node;
        }
        return node;
    }

    if (extern_export_inline_token) |token| {
        if (tree.tokens.at(token).id == .Keyword_inline or
            tree.tokens.at(token).id == .Keyword_noinline)
        {
            try tree.errors.push(.{
                .ExpectedFn = .{ .token = it.index },
            });
            return error.ParseError;
        }
    }

    const thread_local_token = eatToken(it, .Keyword_threadlocal);

    if (try parseVarDecl(arena, it, tree)) |node| {
        var var_decl = node.cast(Node.VarDecl).?;
        var_decl.*.thread_local_token = thread_local_token;
        var_decl.*.comptime_token = null;
        var_decl.*.extern_export_token = extern_export_inline_token;
        var_decl.*.lib_name = lib_name;
        return node;
    }

    if (thread_local_token != null) {
        try tree.errors.push(.{
            .ExpectedVarDecl = .{ .token = it.index },
        });
        // ignore this and try again;
        return error.ParseError;
    }

    if (extern_export_inline_token) |token| {
        try tree.errors.push(.{
            .ExpectedVarDeclOrFn = .{ .token = it.index },
        });
        // ignore this and try again;
        return error.ParseError;
    }

    return try parseUse(arena, it, tree);
}

/// FnProto <- KEYWORD_fn IDENTIFIER? LPAREN ParamDeclList RPAREN ByteAlign? LinkSection? EXCLAMATIONMARK? (KEYWORD_var / TypeExpr)
fn parseFnProto(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    // TODO: Remove once extern/async fn rewriting is
    var is_async = false;
    var is_extern = false;
    const cc_token: ?usize = blk: {
        if (eatToken(it, .Keyword_extern)) |token| {
            is_extern = true;
            break :blk token;
        }
        if (eatToken(it, .Keyword_async)) |token| {
            is_async = true;
            break :blk token;
        }
        break :blk null;
    };
    const fn_token = eatToken(it, .Keyword_fn) orelse {
        if (cc_token) |token|
            putBackToken(it, token);
        return null;
    };
    const name_token = eatToken(it, .Identifier);
    const lparen = try expectToken(it, tree, .LParen);
    const params = try parseParamDeclList(arena, it, tree);
    const rparen = try expectToken(it, tree, .RParen);
    const align_expr = try parseByteAlign(arena, it, tree);
    const section_expr = try parseLinkSection(arena, it, tree);
    const callconv_expr = try parseCallconv(arena, it, tree);
    const exclamation_token = eatToken(it, .Bang);

    const return_type_expr = (try parseVarType(arena, it, tree)) orelse
        try expectNodeRecoverable(arena, it, tree, parseTypeExpr, .{
        // most likely the user forgot to specify the return type.
        // Mark return type as invalid and try to continue.
        .ExpectedReturnType = .{ .token = it.index },
    });

    // TODO https://github.com/ziglang/zig/issues/3750
    const R = Node.FnProto.ReturnType;
    const return_type = if (return_type_expr == null)
        R{ .Invalid = rparen }
    else if (exclamation_token != null)
        R{ .InferErrorSet = return_type_expr.? }
    else
        R{ .Explicit = return_type_expr.? };

    const var_args_token = if (params.len > 0) blk: {
        const param_type = params.at(params.len - 1).*.cast(Node.ParamDecl).?.param_type;
        break :blk if (param_type == .var_args) param_type.var_args else null;
    } else
        null;

    const fn_proto_node = try arena.create(Node.FnProto);
    fn_proto_node.* = .{
        .doc_comments = null,
        .visib_token = null,
        .fn_token = fn_token,
        .name_token = name_token,
        .params = params,
        .return_type = return_type,
        .var_args_token = var_args_token,
        .extern_export_inline_token = null,
        .body_node = null,
        .lib_name = null,
        .align_expr = align_expr,
        .section_expr = section_expr,
        .callconv_expr = callconv_expr,
        .is_extern_prototype = is_extern,
        .is_async = is_async,
    };

    return &fn_proto_node.base;
}

/// VarDecl <- (KEYWORD_const / KEYWORD_var) IDENTIFIER (COLON TypeExpr)? ByteAlign? LinkSection? (EQUAL Expr)? SEMICOLON
fn parseVarDecl(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const mut_token = eatToken(it, .Keyword_const) orelse
        eatToken(it, .Keyword_var) orelse
        return null;

    const name_token = try expectToken(it, tree, .Identifier);
    const type_node = if (eatToken(it, .Colon) != null)
        try expectNode(arena, it, tree, parseTypeExpr, .{
            .ExpectedTypeExpr = .{ .token = it.index },
        })
    else
        null;
    const align_node = try parseByteAlign(arena, it, tree);
    const section_node = try parseLinkSection(arena, it, tree);
    const eq_token = eatToken(it, .Equal);
    const init_node = if (eq_token != null) blk: {
        break :blk try expectNode(arena, it, tree, parseExpr, .{
            .ExpectedExpr = .{ .token = it.index },
        });
    } else null;
    const semicolon_token = try expectToken(it, tree, .Semicolon);

    const node = try arena.create(Node.VarDecl);
    node.* = .{
        .doc_comments = null,
        .visib_token = null,
        .thread_local_token = null,
        .name_token = name_token,
        .eq_token = eq_token,
        .mut_token = mut_token,
        .comptime_token = null,
        .extern_export_token = null,
        .lib_name = null,
        .type_node = type_node,
        .align_node = align_node,
        .section_node = section_node,
        .init_node = init_node,
        .semicolon_token = semicolon_token,
    };
    return &node.base;
}

/// ContainerField <- KEYWORD_comptime? IDENTIFIER (COLON TypeExpr ByteAlign?)? (EQUAL Expr)?
fn parseContainerField(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const comptime_token = eatToken(it, .Keyword_comptime);
    const name_token = eatToken(it, .Identifier) orelse {
        if (comptime_token) |t| putBackToken(it, t);
        return null;
    };

    var align_expr: ?*Node = null;
    var type_expr: ?*Node = null;
    if (eatToken(it, .Colon)) |_| {
        if (eatToken(it, .Keyword_var)) |var_tok| {
            const node = try arena.create(ast.Node.VarType);
            node.* = .{ .token = var_tok };
            type_expr = &node.base;
        } else {
            type_expr = try expectNode(arena, it, tree, parseTypeExpr, .{
                .ExpectedTypeExpr = .{ .token = it.index },
            });
            align_expr = try parseByteAlign(arena, it, tree);
        }
    }

    const value_expr = if (eatToken(it, .Equal)) |_|
        try expectNode(arena, it, tree, parseExpr, .{
            .ExpectedExpr = .{ .token = it.index },
        })
    else
        null;

    const node = try arena.create(Node.ContainerField);
    node.* = .{
        .doc_comments = null,
        .comptime_token = comptime_token,
        .name_token = name_token,
        .type_expr = type_expr,
        .value_expr = value_expr,
        .align_expr = align_expr,
    };
    return &node.base;
}

/// Statement
///     <- KEYWORD_comptime? VarDecl
///      / KEYWORD_comptime BlockExprStatement
///      / KEYWORD_nosuspend BlockExprStatement
///      / KEYWORD_suspend (SEMICOLON / BlockExprStatement)
///      / KEYWORD_defer BlockExprStatement
///      / KEYWORD_errdefer Payload? BlockExprStatement
///      / IfStatement
///      / LabeledStatement
///      / SwitchExpr
///      / AssignExpr SEMICOLON
fn parseStatement(arena: *Allocator, it: *TokenIterator, tree: *Tree) Error!?*Node {
    const comptime_token = eatToken(it, .Keyword_comptime);

    const var_decl_node = try parseVarDecl(arena, it, tree);
    if (var_decl_node) |node| {
        const var_decl = node.cast(Node.VarDecl).?;
        var_decl.comptime_token = comptime_token;
        return node;
    }

    if (comptime_token) |token| {
        const block_expr = try expectNode(arena, it, tree, parseBlockExprStatement, .{
            .ExpectedBlockOrAssignment = .{ .token = it.index },
        });

        const node = try arena.create(Node.Comptime);
        node.* = .{
            .doc_comments = null,
            .comptime_token = token,
            .expr = block_expr,
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_nosuspend)) |nosuspend_token| {
        const block_expr = try expectNode(arena, it, tree, parseBlockExprStatement, .{
            .ExpectedBlockOrAssignment = .{ .token = it.index },
        });

        const node = try arena.create(Node.Nosuspend);
        node.* = .{
            .nosuspend_token = nosuspend_token,
            .expr = block_expr,
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_suspend)) |suspend_token| {
        const semicolon = eatToken(it, .Semicolon);

        const body_node = if (semicolon == null) blk: {
            break :blk try expectNode(arena, it, tree, parseBlockExprStatement, .{
                .ExpectedBlockOrExpression = .{ .token = it.index },
            });
        } else null;

        const node = try arena.create(Node.Suspend);
        node.* = .{
            .suspend_token = suspend_token,
            .body = body_node,
        };
        return &node.base;
    }

    const defer_token = eatToken(it, .Keyword_defer) orelse eatToken(it, .Keyword_errdefer);
    if (defer_token) |token| {
        const payload = if (tree.tokens.at(token).id == .Keyword_errdefer)
            try parsePayload(arena, it, tree)
        else
            null;
        const expr_node = try expectNode(arena, it, tree, parseBlockExprStatement, .{
            .ExpectedBlockOrExpression = .{ .token = it.index },
        });
        const node = try arena.create(Node.Defer);
        node.* = .{
            .defer_token = token,
            .expr = expr_node,
            .payload = payload,
        };
        return &node.base;
    }

    if (try parseIfStatement(arena, it, tree)) |node| return node;
    if (try parseLabeledStatement(arena, it, tree)) |node| return node;
    if (try parseSwitchExpr(arena, it, tree)) |node| return node;
    if (try parseAssignExpr(arena, it, tree)) |node| {
        _ = try expectTokenRecoverable(it, tree, .Semicolon);
        return node;
    }

    return null;
}

/// IfStatement
///     <- IfPrefix BlockExpr ( KEYWORD_else Payload? Statement )?
///      / IfPrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
fn parseIfStatement(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const if_node = (try parseIfPrefix(arena, it, tree)) orelse return null;
    const if_prefix = if_node.cast(Node.If).?;

    const block_expr = (try parseBlockExpr(arena, it, tree));
    const assign_expr = if (block_expr == null)
        try expectNode(arena, it, tree, parseAssignExpr, .{
            .ExpectedBlockOrAssignment = .{ .token = it.index },
        })
    else
        null;

    const semicolon = if (assign_expr != null) eatToken(it, .Semicolon) else null;

    const else_node = if (semicolon == null) blk: {
        const else_token = eatToken(it, .Keyword_else) orelse break :blk null;
        const payload = try parsePayload(arena, it, tree);
        const else_body = try expectNode(arena, it, tree, parseStatement, .{
            .InvalidToken = .{ .token = it.index },
        });

        const node = try arena.create(Node.Else);
        node.* = .{
            .else_token = else_token,
            .payload = payload,
            .body = else_body,
        };

        break :blk node;
    } else null;

    if (block_expr) |body| {
        if_prefix.body = body;
        if_prefix.@"else" = else_node;
        return if_node;
    }

    if (assign_expr) |body| {
        if_prefix.body = body;
        if (semicolon != null) return if_node;
        if (else_node != null) {
            if_prefix.@"else" = else_node;
            return if_node;
        }
        try tree.errors.push(.{
            .ExpectedSemiOrElse = .{ .token = it.index },
        });
    }

    return if_node;
}

/// LabeledStatement <- BlockLabel? (Block / LoopStatement)
fn parseLabeledStatement(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    var colon: TokenIndex = undefined;
    const label_token = parseBlockLabel(arena, it, tree, &colon);

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

    if (label_token != null) {
        try tree.errors.push(.{
            .ExpectedLabelable = .{ .token = it.index },
        });
        return error.ParseError;
    }

    return null;
}

/// LoopStatement <- KEYWORD_inline? (ForStatement / WhileStatement)
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
    if (inline_token == null) return null;

    // If we've seen "inline", there should have been a "for" or "while"
    try tree.errors.push(.{
        .ExpectedInlinable = .{ .token = it.index },
    });
    return error.ParseError;
}

/// ForStatement
///     <- ForPrefix BlockExpr ( KEYWORD_else Statement )?
///      / ForPrefix AssignExpr ( SEMICOLON / KEYWORD_else Statement )
fn parseForStatement(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseForPrefix(arena, it, tree)) orelse return null;
    const for_prefix = node.cast(Node.For).?;

    if (try parseBlockExpr(arena, it, tree)) |block_expr_node| {
        for_prefix.body = block_expr_node;

        if (eatToken(it, .Keyword_else)) |else_token| {
            const statement_node = try expectNode(arena, it, tree, parseStatement, .{
                .InvalidToken = .{ .token = it.index },
            });

            const else_node = try arena.create(Node.Else);
            else_node.* = .{
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
            const statement_node = try expectNode(arena, it, tree, parseStatement, .{
                .ExpectedStatement = .{ .token = it.index },
            });

            const else_node = try arena.create(Node.Else);
            else_node.* = .{
                .else_token = else_token,
                .payload = null,
                .body = statement_node,
            };
            for_prefix.@"else" = else_node;
            return node;
        }

        try tree.errors.push(.{
            .ExpectedSemiOrElse = .{ .token = it.index },
        });

        return node;
    }

    return null;
}

/// WhileStatement
///     <- WhilePrefix BlockExpr ( KEYWORD_else Payload? Statement )?
///      / WhilePrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
fn parseWhileStatement(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseWhilePrefix(arena, it, tree)) orelse return null;
    const while_prefix = node.cast(Node.While).?;

    if (try parseBlockExpr(arena, it, tree)) |block_expr_node| {
        while_prefix.body = block_expr_node;

        if (eatToken(it, .Keyword_else)) |else_token| {
            const payload = try parsePayload(arena, it, tree);

            const statement_node = try expectNode(arena, it, tree, parseStatement, .{
                .InvalidToken = .{ .token = it.index },
            });

            const else_node = try arena.create(Node.Else);
            else_node.* = .{
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

            const statement_node = try expectNode(arena, it, tree, parseStatement, .{
                .ExpectedStatement = .{ .token = it.index },
            });

            const else_node = try arena.create(Node.Else);
            else_node.* = .{
                .else_token = else_token,
                .payload = payload,
                .body = statement_node,
            };
            while_prefix.@"else" = else_node;
            return node;
        }

        try tree.errors.push(.{
            .ExpectedSemiOrElse = .{ .token = it.index },
        });

        return node;
    }

    return null;
}

/// BlockExprStatement
///     <- BlockExpr
///      / AssignExpr SEMICOLON
fn parseBlockExprStatement(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    if (try parseBlockExpr(arena, it, tree)) |node| return node;
    if (try parseAssignExpr(arena, it, tree)) |node| {
        _ = try expectTokenRecoverable(it, tree, .Semicolon);
        return node;
    }
    return null;
}

/// BlockExpr <- BlockLabel? Block
fn parseBlockExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) Error!?*Node {
    var colon: TokenIndex = undefined;
    const label_token = parseBlockLabel(arena, it, tree, &colon);
    const block_node = (try parseBlock(arena, it, tree)) orelse {
        if (label_token) |label| {
            putBackToken(it, label + 1); // ":"
            putBackToken(it, label); // IDENTIFIER
        }
        return null;
    };
    block_node.cast(Node.Block).?.label = label_token;
    return block_node;
}

/// AssignExpr <- Expr (AssignOp Expr)?
fn parseAssignExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(arena, it, tree, parseAssignOp, parseExpr, .Once);
}

/// Expr <- KEYWORD_try* BoolOrExpr
fn parseExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) Error!?*Node {
    return parsePrefixOpExpr(arena, it, tree, parseTry, parseBoolOrExpr);
}

/// BoolOrExpr <- BoolAndExpr (KEYWORD_or BoolAndExpr)*
fn parseBoolOrExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(
        arena,
        it,
        tree,
        SimpleBinOpParseFn(.Keyword_or, Node.InfixOp.Op.BoolOr),
        parseBoolAndExpr,
        .Infinitely,
    );
}

/// BoolAndExpr <- CompareExpr (KEYWORD_and CompareExpr)*
fn parseBoolAndExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(
        arena,
        it,
        tree,
        SimpleBinOpParseFn(.Keyword_and, .BoolAnd),
        parseCompareExpr,
        .Infinitely,
    );
}

/// CompareExpr <- BitwiseExpr (CompareOp BitwiseExpr)?
fn parseCompareExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(arena, it, tree, parseCompareOp, parseBitwiseExpr, .Once);
}

/// BitwiseExpr <- BitShiftExpr (BitwiseOp BitShiftExpr)*
fn parseBitwiseExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(arena, it, tree, parseBitwiseOp, parseBitShiftExpr, .Infinitely);
}

/// BitShiftExpr <- AdditionExpr (BitShiftOp AdditionExpr)*
fn parseBitShiftExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(arena, it, tree, parseBitShiftOp, parseAdditionExpr, .Infinitely);
}

/// AdditionExpr <- MultiplyExpr (AdditionOp MultiplyExpr)*
fn parseAdditionExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(arena, it, tree, parseAdditionOp, parseMultiplyExpr, .Infinitely);
}

/// MultiplyExpr <- PrefixExpr (MultiplyOp PrefixExpr)*
fn parseMultiplyExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseBinOpExpr(arena, it, tree, parseMultiplyOp, parsePrefixExpr, .Infinitely);
}

/// PrefixExpr <- PrefixOp* PrimaryExpr
fn parsePrefixExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parsePrefixOpExpr(arena, it, tree, parsePrefixOp, parsePrimaryExpr);
}

/// PrimaryExpr
///     <- AsmExpr
///      / IfExpr
///      / KEYWORD_break BreakLabel? Expr?
///      / KEYWORD_comptime Expr
///      / KEYWORD_nosuspend Expr
///      / KEYWORD_continue BreakLabel?
///      / KEYWORD_resume Expr
///      / KEYWORD_return Expr?
///      / BlockLabel? LoopExpr
///      / Block
///      / CurlySuffixExpr
fn parsePrimaryExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    if (try parseAsmExpr(arena, it, tree)) |node| return node;
    if (try parseIfExpr(arena, it, tree)) |node| return node;

    if (eatToken(it, .Keyword_break)) |token| {
        const label = try parseBreakLabel(arena, it, tree);
        const expr_node = try parseExpr(arena, it, tree);
        const node = try arena.create(Node.ControlFlowExpression);
        node.* = .{
            .ltoken = token,
            .kind = .{ .Break = label },
            .rhs = expr_node,
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_comptime)) |token| {
        const expr_node = try expectNode(arena, it, tree, parseExpr, .{
            .ExpectedExpr = .{ .token = it.index },
        });
        const node = try arena.create(Node.Comptime);
        node.* = .{
            .doc_comments = null,
            .comptime_token = token,
            .expr = expr_node,
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_nosuspend)) |token| {
        const expr_node = try expectNode(arena, it, tree, parseExpr, .{
            .ExpectedExpr = .{ .token = it.index },
        });
        const node = try arena.create(Node.Nosuspend);
        node.* = .{
            .nosuspend_token = token,
            .expr = expr_node,
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_continue)) |token| {
        const label = try parseBreakLabel(arena, it, tree);
        const node = try arena.create(Node.ControlFlowExpression);
        node.* = .{
            .ltoken = token,
            .kind = .{ .Continue = label },
            .rhs = null,
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_resume)) |token| {
        const expr_node = try expectNode(arena, it, tree, parseExpr, .{
            .ExpectedExpr = .{ .token = it.index },
        });
        const node = try arena.create(Node.PrefixOp);
        node.* = .{
            .op_token = token,
            .op = .Resume,
            .rhs = expr_node,
        };
        return &node.base;
    }

    if (eatToken(it, .Keyword_return)) |token| {
        const expr_node = try parseExpr(arena, it, tree);
        const node = try arena.create(Node.ControlFlowExpression);
        node.* = .{
            .ltoken = token,
            .kind = .Return,
            .rhs = expr_node,
        };
        return &node.base;
    }

    var colon: TokenIndex = undefined;
    const label = parseBlockLabel(arena, it, tree, &colon);
    if (try parseLoopExpr(arena, it, tree)) |node| {
        if (node.cast(Node.For)) |for_node| {
            for_node.label = label;
        } else if (node.cast(Node.While)) |while_node| {
            while_node.label = label;
        } else unreachable;
        return node;
    }
    if (label) |token| {
        putBackToken(it, token + 1); // ":"
        putBackToken(it, token); // IDENTIFIER
    }

    if (try parseBlock(arena, it, tree)) |node| return node;
    if (try parseCurlySuffixExpr(arena, it, tree)) |node| return node;

    return null;
}

/// IfExpr <- IfPrefix Expr (KEYWORD_else Payload? Expr)?
fn parseIfExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseIf(arena, it, tree, parseExpr);
}

/// Block <- LBRACE Statement* RBRACE
fn parseBlock(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const lbrace = eatToken(it, .LBrace) orelse return null;

    var statements = Node.Block.StatementList.init(arena);
    while (true) {
        const statement = (parseStatement(arena, it, tree) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.ParseError => {
                // try to skip to the next statement
                findNextStmt(it);
                continue;
            },
        }) orelse break;
        try statements.push(statement);
    }

    const rbrace = try expectToken(it, tree, .RBrace);

    const block_node = try arena.create(Node.Block);
    block_node.* = .{
        .label = null,
        .lbrace = lbrace,
        .statements = statements,
        .rbrace = rbrace,
    };

    return &block_node.base;
}

/// LoopExpr <- KEYWORD_inline? (ForExpr / WhileExpr)
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

    if (inline_token == null) return null;

    // If we've seen "inline", there should have been a "for" or "while"
    try tree.errors.push(.{
        .ExpectedInlinable = .{ .token = it.index },
    });
    return error.ParseError;
}

/// ForExpr <- ForPrefix Expr (KEYWORD_else Expr)?
fn parseForExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseForPrefix(arena, it, tree)) orelse return null;
    const for_prefix = node.cast(Node.For).?;

    const body_node = try expectNode(arena, it, tree, parseExpr, .{
        .ExpectedExpr = .{ .token = it.index },
    });
    for_prefix.body = body_node;

    if (eatToken(it, .Keyword_else)) |else_token| {
        const body = try expectNode(arena, it, tree, parseExpr, .{
            .ExpectedExpr = .{ .token = it.index },
        });

        const else_node = try arena.create(Node.Else);
        else_node.* = .{
            .else_token = else_token,
            .payload = null,
            .body = body,
        };

        for_prefix.@"else" = else_node;
    }

    return node;
}

/// WhileExpr <- WhilePrefix Expr (KEYWORD_else Payload? Expr)?
fn parseWhileExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseWhilePrefix(arena, it, tree)) orelse return null;
    const while_prefix = node.cast(Node.While).?;

    const body_node = try expectNode(arena, it, tree, parseExpr, .{
        .ExpectedExpr = .{ .token = it.index },
    });
    while_prefix.body = body_node;

    if (eatToken(it, .Keyword_else)) |else_token| {
        const payload = try parsePayload(arena, it, tree);
        const body = try expectNode(arena, it, tree, parseExpr, .{
            .ExpectedExpr = .{ .token = it.index },
        });

        const else_node = try arena.create(Node.Else);
        else_node.* = .{
            .else_token = else_token,
            .payload = payload,
            .body = body,
        };

        while_prefix.@"else" = else_node;
    }

    return node;
}

/// CurlySuffixExpr <- TypeExpr InitList?
fn parseCurlySuffixExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const type_expr = (try parseTypeExpr(arena, it, tree)) orelse return null;
    const suffix_op = (try parseInitList(arena, it, tree)) orelse return type_expr;
    suffix_op.lhs.node = type_expr;
    return &suffix_op.base;
}

/// InitList
///     <- LBRACE FieldInit (COMMA FieldInit)* COMMA? RBRACE
///      / LBRACE Expr (COMMA Expr)* COMMA? RBRACE
///      / LBRACE RBRACE
fn parseInitList(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node.SuffixOp {
    const lbrace = eatToken(it, .LBrace) orelse return null;
    var init_list = Node.SuffixOp.Op.InitList.init(arena);

    const op: Node.SuffixOp.Op = blk: {
        if (try parseFieldInit(arena, it, tree)) |field_init| {
            try init_list.push(field_init);
            while (eatToken(it, .Comma)) |_| {
                const next = (try parseFieldInit(arena, it, tree)) orelse break;
                try init_list.push(next);
            }
            break :blk .{ .StructInitializer = init_list };
        }

        if (try parseExpr(arena, it, tree)) |expr| {
            try init_list.push(expr);
            while (eatToken(it, .Comma)) |_| {
                const next = (try parseExpr(arena, it, tree)) orelse break;
                try init_list.push(next);
            }
            break :blk .{ .ArrayInitializer = init_list };
        }

        break :blk .{ .StructInitializer = init_list };
    };

    const node = try arena.create(Node.SuffixOp);
    node.* = .{
        .lhs = .{ .node = undefined }, // set by caller
        .op = op,
        .rtoken = try expectToken(it, tree, .RBrace),
    };
    return node;
}

/// TypeExpr <- PrefixTypeOp* ErrorUnionExpr
fn parseTypeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) Error!?*Node {
    return parsePrefixOpExpr(arena, it, tree, parsePrefixTypeOp, parseErrorUnionExpr);
}

/// ErrorUnionExpr <- SuffixExpr (EXCLAMATIONMARK TypeExpr)?
fn parseErrorUnionExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const suffix_expr = (try parseSuffixExpr(arena, it, tree)) orelse return null;

    if (try SimpleBinOpParseFn(.Bang, Node.InfixOp.Op.ErrorUnion)(arena, it, tree)) |node| {
        const error_union = node.cast(Node.InfixOp).?;
        const type_expr = try expectNode(arena, it, tree, parseTypeExpr, .{
            .ExpectedTypeExpr = .{ .token = it.index },
        });
        error_union.lhs = suffix_expr;
        error_union.rhs = type_expr;
        return node;
    }

    return suffix_expr;
}

/// SuffixExpr
///     <- KEYWORD_async PrimaryTypeExpr SuffixOp* FnCallArguments
///      / PrimaryTypeExpr (SuffixOp / FnCallArguments)*
fn parseSuffixExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const maybe_async = eatToken(it, .Keyword_async);
    if (maybe_async) |async_token| {
        const token_fn = eatToken(it, .Keyword_fn);
        if (token_fn != null) {
            // TODO: remove this hack when async fn rewriting is
            // HACK: If we see the keyword `fn`, then we assume that
            //       we are parsing an async fn proto, and not a call.
            //       We therefore put back all tokens consumed by the async
            //       prefix...
            putBackToken(it, token_fn.?);
            putBackToken(it, async_token);
            return parsePrimaryTypeExpr(arena, it, tree);
        }
        var res = try expectNode(arena, it, tree, parsePrimaryTypeExpr, .{
            .ExpectedPrimaryTypeExpr = .{ .token = it.index },
        });

        while (try parseSuffixOp(arena, it, tree)) |node| {
            switch (node.id) {
                .SuffixOp => node.cast(Node.SuffixOp).?.lhs = .{ .node = res },
                .InfixOp => node.cast(Node.InfixOp).?.lhs = res,
                else => unreachable,
            }
            res = node;
        }

        const params = (try parseFnCallArguments(arena, it, tree)) orelse {
            try tree.errors.push(.{
                .ExpectedParamList = .{ .token = it.index },
            });
            // ignore this, continue parsing
            return res;
        };
        const node = try arena.create(Node.SuffixOp);
        node.* = .{
            .lhs = .{ .node = res },
            .op = .{
                .Call = .{
                    .params = params.list,
                    .async_token = async_token,
                },
            },
            .rtoken = params.rparen,
        };
        return &node.base;
    }
    if (try parsePrimaryTypeExpr(arena, it, tree)) |expr| {
        var res = expr;

        while (true) {
            if (try parseSuffixOp(arena, it, tree)) |node| {
                switch (node.id) {
                    .SuffixOp => node.cast(Node.SuffixOp).?.lhs = .{ .node = res },
                    .InfixOp => node.cast(Node.InfixOp).?.lhs = res,
                    else => unreachable,
                }
                res = node;
                continue;
            }
            if (try parseFnCallArguments(arena, it, tree)) |params| {
                const call = try arena.create(Node.SuffixOp);
                call.* = .{
                    .lhs = .{ .node = res },
                    .op = .{
                        .Call = .{
                            .params = params.list,
                            .async_token = null,
                        },
                    },
                    .rtoken = params.rparen,
                };
                res = &call.base;
                continue;
            }
            break;
        }
        return res;
    }

    return null;
}

/// PrimaryTypeExpr
///     <- BUILTINIDENTIFIER FnCallArguments
///      / CHAR_LITERAL
///      / ContainerDecl
///      / DOT IDENTIFIER
///      / ErrorSetDecl
///      / FLOAT
///      / FnProto
///      / GroupedExpr
///      / LabeledTypeExpr
///      / IDENTIFIER
///      / IfTypeExpr
///      / INTEGER
///      / KEYWORD_comptime TypeExpr
///      / KEYWORD_error DOT IDENTIFIER
///      / KEYWORD_false
///      / KEYWORD_null
///      / KEYWORD_anyframe
///      / KEYWORD_true
///      / KEYWORD_undefined
///      / KEYWORD_unreachable
///      / STRINGLITERAL
///      / SwitchExpr
fn parsePrimaryTypeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    if (try parseBuiltinCall(arena, it, tree)) |node| return node;
    if (eatToken(it, .CharLiteral)) |token| {
        const node = try arena.create(Node.CharLiteral);
        node.* = .{
            .token = token,
        };
        return &node.base;
    }
    if (try parseContainerDecl(arena, it, tree)) |node| return node;
    if (try parseAnonLiteral(arena, it, tree)) |node| return node;
    if (try parseErrorSetDecl(arena, it, tree)) |node| return node;
    if (try parseFloatLiteral(arena, it, tree)) |node| return node;
    if (try parseFnProto(arena, it, tree)) |node| return node;
    if (try parseGroupedExpr(arena, it, tree)) |node| return node;
    if (try parseLabeledTypeExpr(arena, it, tree)) |node| return node;
    if (try parseIdentifier(arena, it, tree)) |node| return node;
    if (try parseIfTypeExpr(arena, it, tree)) |node| return node;
    if (try parseIntegerLiteral(arena, it, tree)) |node| return node;
    if (eatToken(it, .Keyword_comptime)) |token| {
        const expr = (try parseTypeExpr(arena, it, tree)) orelse return null;
        const node = try arena.create(Node.Comptime);
        node.* = .{
            .doc_comments = null,
            .comptime_token = token,
            .expr = expr,
        };
        return &node.base;
    }
    if (eatToken(it, .Keyword_error)) |token| {
        const period = try expectTokenRecoverable(it, tree, .Period);
        const identifier = try expectNodeRecoverable(arena, it, tree, parseIdentifier, .{
            .ExpectedIdentifier = .{ .token = it.index },
        });
        const global_error_set = try createLiteral(arena, Node.ErrorType, token);
        if (period == null or identifier == null) return global_error_set;

        const node = try arena.create(Node.InfixOp);
        node.* = .{
            .op_token = period.?,
            .lhs = global_error_set,
            .op = .Period,
            .rhs = identifier.?,
        };
        return &node.base;
    }
    if (eatToken(it, .Keyword_false)) |token| return createLiteral(arena, Node.BoolLiteral, token);
    if (eatToken(it, .Keyword_null)) |token| return createLiteral(arena, Node.NullLiteral, token);
    if (eatToken(it, .Keyword_anyframe)) |token| {
        const node = try arena.create(Node.AnyFrameType);
        node.* = .{
            .anyframe_token = token,
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

/// ContainerDecl <- (KEYWORD_extern / KEYWORD_packed)? ContainerDeclAuto
fn parseContainerDecl(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const layout_token = eatToken(it, .Keyword_extern) orelse
        eatToken(it, .Keyword_packed);

    const node = (try parseContainerDeclAuto(arena, it, tree)) orelse {
        if (layout_token) |token|
            putBackToken(it, token);
        return null;
    };
    node.cast(Node.ContainerDecl).?.*.layout_token = layout_token;
    return node;
}

/// ErrorSetDecl <- KEYWORD_error LBRACE IdentifierList RBRACE
fn parseErrorSetDecl(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const error_token = eatToken(it, .Keyword_error) orelse return null;
    if (eatToken(it, .LBrace) == null) {
        // Might parse as `KEYWORD_error DOT IDENTIFIER` later in PrimaryTypeExpr, so don't error
        putBackToken(it, error_token);
        return null;
    }
    const decls = try parseErrorTagList(arena, it, tree);
    const rbrace = try expectToken(it, tree, .RBrace);

    const node = try arena.create(Node.ErrorSetDecl);
    node.* = .{
        .error_token = error_token,
        .decls = decls,
        .rbrace_token = rbrace,
    };
    return &node.base;
}

/// GroupedExpr <- LPAREN Expr RPAREN
fn parseGroupedExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const lparen = eatToken(it, .LParen) orelse return null;
    const expr = try expectNode(arena, it, tree, parseExpr, .{
        .ExpectedExpr = .{ .token = it.index },
    });
    const rparen = try expectToken(it, tree, .RParen);

    const node = try arena.create(Node.GroupedExpression);
    node.* = .{
        .lparen = lparen,
        .expr = expr,
        .rparen = rparen,
    };
    return &node.base;
}

/// IfTypeExpr <- IfPrefix TypeExpr (KEYWORD_else Payload? TypeExpr)?
fn parseIfTypeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    return parseIf(arena, it, tree, parseTypeExpr);
}

/// LabeledTypeExpr
///     <- BlockLabel Block
///      / BlockLabel? LoopTypeExpr
fn parseLabeledTypeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    var colon: TokenIndex = undefined;
    const label = parseBlockLabel(arena, it, tree, &colon);

    if (label) |token| {
        if (try parseBlock(arena, it, tree)) |node| {
            node.cast(Node.Block).?.label = token;
            return node;
        }
    }

    if (try parseLoopTypeExpr(arena, it, tree)) |node| {
        switch (node.id) {
            .For => node.cast(Node.For).?.label = label,
            .While => node.cast(Node.While).?.label = label,
            else => unreachable,
        }
        return node;
    }

    if (label) |token| {
        putBackToken(it, colon);
        putBackToken(it, token);
    }
    return null;
}

/// LoopTypeExpr <- KEYWORD_inline? (ForTypeExpr / WhileTypeExpr)
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

    if (inline_token == null) return null;

    // If we've seen "inline", there should have been a "for" or "while"
    try tree.errors.push(.{
        .ExpectedInlinable = .{ .token = it.index },
    });
    return error.ParseError;
}

/// ForTypeExpr <- ForPrefix TypeExpr (KEYWORD_else TypeExpr)?
fn parseForTypeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseForPrefix(arena, it, tree)) orelse return null;
    const for_prefix = node.cast(Node.For).?;

    const type_expr = try expectNode(arena, it, tree, parseTypeExpr, .{
        .ExpectedTypeExpr = .{ .token = it.index },
    });
    for_prefix.body = type_expr;

    if (eatToken(it, .Keyword_else)) |else_token| {
        const else_expr = try expectNode(arena, it, tree, parseTypeExpr, .{
            .ExpectedTypeExpr = .{ .token = it.index },
        });

        const else_node = try arena.create(Node.Else);
        else_node.* = .{
            .else_token = else_token,
            .payload = null,
            .body = else_expr,
        };

        for_prefix.@"else" = else_node;
    }

    return node;
}

/// WhileTypeExpr <- WhilePrefix TypeExpr (KEYWORD_else Payload? TypeExpr)?
fn parseWhileTypeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseWhilePrefix(arena, it, tree)) orelse return null;
    const while_prefix = node.cast(Node.While).?;

    const type_expr = try expectNode(arena, it, tree, parseTypeExpr, .{
        .ExpectedTypeExpr = .{ .token = it.index },
    });
    while_prefix.body = type_expr;

    if (eatToken(it, .Keyword_else)) |else_token| {
        const payload = try parsePayload(arena, it, tree);

        const else_expr = try expectNode(arena, it, tree, parseTypeExpr, .{
            .ExpectedTypeExpr = .{ .token = it.index },
        });

        const else_node = try arena.create(Node.Else);
        else_node.* = .{
            .else_token = else_token,
            .payload = null,
            .body = else_expr,
        };

        while_prefix.@"else" = else_node;
    }

    return node;
}

/// SwitchExpr <- KEYWORD_switch LPAREN Expr RPAREN LBRACE SwitchProngList RBRACE
fn parseSwitchExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const switch_token = eatToken(it, .Keyword_switch) orelse return null;
    _ = try expectToken(it, tree, .LParen);
    const expr_node = try expectNode(arena, it, tree, parseExpr, .{
        .ExpectedExpr = .{ .token = it.index },
    });
    _ = try expectToken(it, tree, .RParen);
    _ = try expectToken(it, tree, .LBrace);
    const cases = try parseSwitchProngList(arena, it, tree);
    const rbrace = try expectToken(it, tree, .RBrace);

    const node = try arena.create(Node.Switch);
    node.* = .{
        .switch_token = switch_token,
        .expr = expr_node,
        .cases = cases,
        .rbrace = rbrace,
    };
    return &node.base;
}

/// AsmExpr <- KEYWORD_asm KEYWORD_volatile? LPAREN Expr AsmOutput? RPAREN
fn parseAsmExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const asm_token = eatToken(it, .Keyword_asm) orelse return null;
    const volatile_token = eatToken(it, .Keyword_volatile);
    _ = try expectToken(it, tree, .LParen);
    const template = try expectNode(arena, it, tree, parseExpr, .{
        .ExpectedExpr = .{ .token = it.index },
    });

    const node = try arena.create(Node.Asm);
    node.* = .{
        .asm_token = asm_token,
        .volatile_token = volatile_token,
        .template = template,
        .outputs = Node.Asm.OutputList.init(arena),
        .inputs = Node.Asm.InputList.init(arena),
        .clobbers = Node.Asm.ClobberList.init(arena),
        .rparen = undefined,
    };

    try parseAsmOutput(arena, it, tree, node);
    node.rparen = try expectToken(it, tree, .RParen);
    return &node.base;
}

/// DOT IDENTIFIER
fn parseAnonLiteral(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const dot = eatToken(it, .Period) orelse return null;

    // anon enum literal
    if (eatToken(it, .Identifier)) |name| {
        const node = try arena.create(Node.EnumLiteral);
        node.* = .{
            .dot = dot,
            .name = name,
        };
        return &node.base;
    }

    // anon container literal
    if (try parseInitList(arena, it, tree)) |node| {
        node.lhs = .{ .dot = dot };
        return &node.base;
    }

    putBackToken(it, dot);
    return null;
}

/// AsmOutput <- COLON AsmOutputList AsmInput?
fn parseAsmOutput(arena: *Allocator, it: *TokenIterator, tree: *Tree, asm_node: *Node.Asm) !void {
    if (eatToken(it, .Colon) == null) return;
    asm_node.outputs = try parseAsmOutputList(arena, it, tree);
    try parseAsmInput(arena, it, tree, asm_node);
}

/// AsmOutputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN (MINUSRARROW TypeExpr / IDENTIFIER) RPAREN
fn parseAsmOutputItem(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node.AsmOutput {
    const lbracket = eatToken(it, .LBracket) orelse return null;
    const name = try expectNode(arena, it, tree, parseIdentifier, .{
        .ExpectedIdentifier = .{ .token = it.index },
    });
    _ = try expectToken(it, tree, .RBracket);

    const constraint = try expectNode(arena, it, tree, parseStringLiteral, .{
        .ExpectedStringLiteral = .{ .token = it.index },
    });

    _ = try expectToken(it, tree, .LParen);
    const kind: Node.AsmOutput.Kind = blk: {
        if (eatToken(it, .Arrow) != null) {
            const return_ident = try expectNode(arena, it, tree, parseTypeExpr, .{
                .ExpectedTypeExpr = .{ .token = it.index },
            });
            break :blk .{ .Return = return_ident };
        }
        const variable = try expectNode(arena, it, tree, parseIdentifier, .{
            .ExpectedIdentifier = .{ .token = it.index },
        });
        break :blk .{ .Variable = variable.cast(Node.Identifier).? };
    };
    const rparen = try expectToken(it, tree, .RParen);

    const node = try arena.create(Node.AsmOutput);
    node.* = .{
        .lbracket = lbracket,
        .symbolic_name = name,
        .constraint = constraint,
        .kind = kind,
        .rparen = rparen,
    };
    return node;
}

/// AsmInput <- COLON AsmInputList AsmClobbers?
fn parseAsmInput(arena: *Allocator, it: *TokenIterator, tree: *Tree, asm_node: *Node.Asm) !void {
    if (eatToken(it, .Colon) == null) return;
    asm_node.inputs = try parseAsmInputList(arena, it, tree);
    try parseAsmClobbers(arena, it, tree, asm_node);
}

/// AsmInputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN Expr RPAREN
fn parseAsmInputItem(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node.AsmInput {
    const lbracket = eatToken(it, .LBracket) orelse return null;
    const name = try expectNode(arena, it, tree, parseIdentifier, .{
        .ExpectedIdentifier = .{ .token = it.index },
    });
    _ = try expectToken(it, tree, .RBracket);

    const constraint = try expectNode(arena, it, tree, parseStringLiteral, .{
        .ExpectedStringLiteral = .{ .token = it.index },
    });

    _ = try expectToken(it, tree, .LParen);
    const expr = try expectNode(arena, it, tree, parseExpr, .{
        .ExpectedExpr = .{ .token = it.index },
    });
    const rparen = try expectToken(it, tree, .RParen);

    const node = try arena.create(Node.AsmInput);
    node.* = .{
        .lbracket = lbracket,
        .symbolic_name = name,
        .constraint = constraint,
        .expr = expr,
        .rparen = rparen,
    };
    return node;
}

/// AsmClobbers <- COLON StringList
/// StringList <- (STRINGLITERAL COMMA)* STRINGLITERAL?
fn parseAsmClobbers(arena: *Allocator, it: *TokenIterator, tree: *Tree, asm_node: *Node.Asm) !void {
    if (eatToken(it, .Colon) == null) return;
    asm_node.clobbers = try ListParseFn(
        Node.Asm.ClobberList,
        parseStringLiteral,
    )(arena, it, tree);
}

/// BreakLabel <- COLON IDENTIFIER
fn parseBreakLabel(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    _ = eatToken(it, .Colon) orelse return null;
    return try expectNode(arena, it, tree, parseIdentifier, .{
        .ExpectedIdentifier = .{ .token = it.index },
    });
}

/// BlockLabel <- IDENTIFIER COLON
fn parseBlockLabel(arena: *Allocator, it: *TokenIterator, tree: *Tree, colon_token: *TokenIndex) ?TokenIndex {
    const identifier = eatToken(it, .Identifier) orelse return null;
    if (eatToken(it, .Colon)) |colon| {
        colon_token.* = colon;
        return identifier;
    }
    putBackToken(it, identifier);
    return null;
}

/// FieldInit <- DOT IDENTIFIER EQUAL Expr
fn parseFieldInit(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const period_token = eatToken(it, .Period) orelse return null;
    const name_token = eatToken(it, .Identifier) orelse {
        // Because of anon literals `.{` is also valid.
        putBackToken(it, period_token);
        return null;
    };
    const eq_token = eatToken(it, .Equal) orelse {
        // `.Name` may also be an enum literal, which is a later rule.
        putBackToken(it, name_token);
        putBackToken(it, period_token);
        return null;
    };
    const expr_node = try expectNode(arena, it, tree, parseExpr, .{
        .ExpectedExpr = .{ .token = it.index },
    });

    const node = try arena.create(Node.FieldInitializer);
    node.* = .{
        .period_token = period_token,
        .name_token = name_token,
        .expr = expr_node,
    };
    return &node.base;
}

/// WhileContinueExpr <- COLON LPAREN AssignExpr RPAREN
fn parseWhileContinueExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    _ = eatToken(it, .Colon) orelse return null;
    _ = try expectToken(it, tree, .LParen);
    const node = try expectNode(arena, it, tree, parseAssignExpr, .{
        .ExpectedExprOrAssignment = .{ .token = it.index },
    });
    _ = try expectToken(it, tree, .RParen);
    return node;
}

/// LinkSection <- KEYWORD_linksection LPAREN Expr RPAREN
fn parseLinkSection(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    _ = eatToken(it, .Keyword_linksection) orelse return null;
    _ = try expectToken(it, tree, .LParen);
    const expr_node = try expectNode(arena, it, tree, parseExpr, .{
        .ExpectedExpr = .{ .token = it.index },
    });
    _ = try expectToken(it, tree, .RParen);
    return expr_node;
}

/// CallConv <- KEYWORD_callconv LPAREN Expr RPAREN
fn parseCallconv(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    _ = eatToken(it, .Keyword_callconv) orelse return null;
    _ = try expectToken(it, tree, .LParen);
    const expr_node = try expectNode(arena, it, tree, parseExpr, .{
        .ExpectedExpr = .{ .token = it.index },
    });
    _ = try expectToken(it, tree, .RParen);
    return expr_node;
}

/// ParamDecl <- (KEYWORD_noalias / KEYWORD_comptime)? (IDENTIFIER COLON)? ParamType
fn parseParamDecl(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const doc_comments = try parseDocComment(arena, it, tree);
    const noalias_token = eatToken(it, .Keyword_noalias);
    const comptime_token = if (noalias_token == null) eatToken(it, .Keyword_comptime) else null;
    const name_token = blk: {
        const identifier = eatToken(it, .Identifier) orelse break :blk null;
        if (eatToken(it, .Colon) != null) break :blk identifier;
        putBackToken(it, identifier); // ParamType may also be an identifier
        break :blk null;
    };
    const param_type = (try parseParamType(arena, it, tree)) orelse {
        // Only return cleanly if no keyword, identifier, or doc comment was found
        if (noalias_token == null and
            comptime_token == null and
            name_token == null and
            doc_comments == null) return null;
        try tree.errors.push(.{
            .ExpectedParamType = .{ .token = it.index },
        });
        return error.ParseError;
    };

    const param_decl = try arena.create(Node.ParamDecl);
    param_decl.* = .{
        .doc_comments = doc_comments,
        .comptime_token = comptime_token,
        .noalias_token = noalias_token,
        .name_token = name_token,
        .param_type = param_type,
    };
    return &param_decl.base;
}

/// ParamType
///     <- KEYWORD_var
///      / DOT3
///      / TypeExpr
fn parseParamType(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?Node.ParamDecl.ParamType {
    // TODO cast from tuple to error union is broken
    const P = Node.ParamDecl.ParamType;
    if (try parseVarType(arena, it, tree)) |node| return P{ .var_type = node };
    if (eatToken(it, .Ellipsis3)) |token| return P{ .var_args = token };
    if (try parseTypeExpr(arena, it, tree)) |node| return P{ .type_expr = node };
    return null;
}

/// IfPrefix <- KEYWORD_if LPAREN Expr RPAREN PtrPayload?
fn parseIfPrefix(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const if_token = eatToken(it, .Keyword_if) orelse return null;
    _ = try expectToken(it, tree, .LParen);
    const condition = try expectNode(arena, it, tree, parseExpr, .{
        .ExpectedExpr = .{ .token = it.index },
    });
    _ = try expectToken(it, tree, .RParen);
    const payload = try parsePtrPayload(arena, it, tree);

    const node = try arena.create(Node.If);
    node.* = .{
        .if_token = if_token,
        .condition = condition,
        .payload = payload,
        .body = undefined, // set by caller
        .@"else" = null,
    };
    return &node.base;
}

/// WhilePrefix <- KEYWORD_while LPAREN Expr RPAREN PtrPayload? WhileContinueExpr?
fn parseWhilePrefix(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const while_token = eatToken(it, .Keyword_while) orelse return null;

    _ = try expectToken(it, tree, .LParen);
    const condition = try expectNode(arena, it, tree, parseExpr, .{
        .ExpectedExpr = .{ .token = it.index },
    });
    _ = try expectToken(it, tree, .RParen);

    const payload = try parsePtrPayload(arena, it, tree);
    const continue_expr = try parseWhileContinueExpr(arena, it, tree);

    const node = try arena.create(Node.While);
    node.* = .{
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

/// ForPrefix <- KEYWORD_for LPAREN Expr RPAREN PtrIndexPayload
fn parseForPrefix(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const for_token = eatToken(it, .Keyword_for) orelse return null;

    _ = try expectToken(it, tree, .LParen);
    const array_expr = try expectNode(arena, it, tree, parseExpr, .{
        .ExpectedExpr = .{ .token = it.index },
    });
    _ = try expectToken(it, tree, .RParen);

    const payload = try expectNode(arena, it, tree, parsePtrIndexPayload, .{
        .ExpectedPayload = .{ .token = it.index },
    });

    const node = try arena.create(Node.For);
    node.* = .{
        .label = null,
        .inline_token = null,
        .for_token = for_token,
        .array_expr = array_expr,
        .payload = payload,
        .body = undefined, // set by caller
        .@"else" = null,
    };
    return &node.base;
}

/// Payload <- PIPE IDENTIFIER PIPE
fn parsePayload(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const lpipe = eatToken(it, .Pipe) orelse return null;
    const identifier = try expectNode(arena, it, tree, parseIdentifier, .{
        .ExpectedIdentifier = .{ .token = it.index },
    });
    const rpipe = try expectToken(it, tree, .Pipe);

    const node = try arena.create(Node.Payload);
    node.* = .{
        .lpipe = lpipe,
        .error_symbol = identifier,
        .rpipe = rpipe,
    };
    return &node.base;
}

/// PtrPayload <- PIPE ASTERISK? IDENTIFIER PIPE
fn parsePtrPayload(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const lpipe = eatToken(it, .Pipe) orelse return null;
    const asterisk = eatToken(it, .Asterisk);
    const identifier = try expectNode(arena, it, tree, parseIdentifier, .{
        .ExpectedIdentifier = .{ .token = it.index },
    });
    const rpipe = try expectToken(it, tree, .Pipe);

    const node = try arena.create(Node.PointerPayload);
    node.* = .{
        .lpipe = lpipe,
        .ptr_token = asterisk,
        .value_symbol = identifier,
        .rpipe = rpipe,
    };
    return &node.base;
}

/// PtrIndexPayload <- PIPE ASTERISK? IDENTIFIER (COMMA IDENTIFIER)? PIPE
fn parsePtrIndexPayload(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const lpipe = eatToken(it, .Pipe) orelse return null;
    const asterisk = eatToken(it, .Asterisk);
    const identifier = try expectNode(arena, it, tree, parseIdentifier, .{
        .ExpectedIdentifier = .{ .token = it.index },
    });

    const index = if (eatToken(it, .Comma) == null)
        null
    else
        try expectNode(arena, it, tree, parseIdentifier, .{
            .ExpectedIdentifier = .{ .token = it.index },
        });

    const rpipe = try expectToken(it, tree, .Pipe);

    const node = try arena.create(Node.PointerIndexPayload);
    node.* = .{
        .lpipe = lpipe,
        .ptr_token = asterisk,
        .value_symbol = identifier,
        .index_symbol = index,
        .rpipe = rpipe,
    };
    return &node.base;
}

/// SwitchProng <- SwitchCase EQUALRARROW PtrPayload? AssignExpr
fn parseSwitchProng(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseSwitchCase(arena, it, tree)) orelse return null;
    const arrow = try expectToken(it, tree, .EqualAngleBracketRight);
    const payload = try parsePtrPayload(arena, it, tree);
    const expr = try expectNode(arena, it, tree, parseAssignExpr, .{
        .ExpectedExprOrAssignment = .{ .token = it.index },
    });

    const switch_case = node.cast(Node.SwitchCase).?;
    switch_case.arrow_token = arrow;
    switch_case.payload = payload;
    switch_case.expr = expr;

    return node;
}

/// SwitchCase
///     <- SwitchItem (COMMA SwitchItem)* COMMA?
///      / KEYWORD_else
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
        else_node.* = .{
            .token = else_token,
        };
        try list.push(&else_node.base);
    } else return null;

    const node = try arena.create(Node.SwitchCase);
    node.* = .{
        .items = list,
        .arrow_token = undefined, // set by caller
        .payload = null,
        .expr = undefined, // set by caller
    };
    return &node.base;
}

/// SwitchItem <- Expr (DOT3 Expr)?
fn parseSwitchItem(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const expr = (try parseExpr(arena, it, tree)) orelse return null;
    if (eatToken(it, .Ellipsis3)) |token| {
        const range_end = try expectNode(arena, it, tree, parseExpr, .{
            .ExpectedExpr = .{ .token = it.index },
        });

        const node = try arena.create(Node.InfixOp);
        node.* = .{
            .op_token = token,
            .lhs = expr,
            .op = .Range,
            .rhs = range_end,
        };
        return &node.base;
    }
    return expr;
}

/// AssignOp
///     <- ASTERISKEQUAL
///      / SLASHEQUAL
///      / PERCENTEQUAL
///      / PLUSEQUAL
///      / MINUSEQUAL
///      / LARROW2EQUAL
///      / RARROW2EQUAL
///      / AMPERSANDEQUAL
///      / CARETEQUAL
///      / PIPEEQUAL
///      / ASTERISKPERCENTEQUAL
///      / PLUSPERCENTEQUAL
///      / MINUSPERCENTEQUAL
///      / EQUAL
fn parseAssignOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = nextToken(it);
    const op: Node.InfixOp.Op = switch (token.ptr.id) {
        .AsteriskEqual => .AssignMul,
        .SlashEqual => .AssignDiv,
        .PercentEqual => .AssignMod,
        .PlusEqual => .AssignAdd,
        .MinusEqual => .AssignSub,
        .AngleBracketAngleBracketLeftEqual => .AssignBitShiftLeft,
        .AngleBracketAngleBracketRightEqual => .AssignBitShiftRight,
        .AmpersandEqual => .AssignBitAnd,
        .CaretEqual => .AssignBitXor,
        .PipeEqual => .AssignBitOr,
        .AsteriskPercentEqual => .AssignMulWrap,
        .PlusPercentEqual => .AssignAddWrap,
        .MinusPercentEqual => .AssignSubWrap,
        .Equal => .Assign,
        else => {
            putBackToken(it, token.index);
            return null;
        },
    };

    const node = try arena.create(Node.InfixOp);
    node.* = .{
        .op_token = token.index,
        .lhs = undefined, // set by caller
        .op = op,
        .rhs = undefined, // set by caller
    };
    return &node.base;
}

/// CompareOp
///     <- EQUALEQUAL
///      / EXCLAMATIONMARKEQUAL
///      / LARROW
///      / RARROW
///      / LARROWEQUAL
///      / RARROWEQUAL
fn parseCompareOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = nextToken(it);
    const op: Node.InfixOp.Op = switch (token.ptr.id) {
        .EqualEqual => .EqualEqual,
        .BangEqual => .BangEqual,
        .AngleBracketLeft => .LessThan,
        .AngleBracketRight => .GreaterThan,
        .AngleBracketLeftEqual => .LessOrEqual,
        .AngleBracketRightEqual => .GreaterOrEqual,
        else => {
            putBackToken(it, token.index);
            return null;
        },
    };

    return try createInfixOp(arena, token.index, op);
}

/// BitwiseOp
///     <- AMPERSAND
///      / CARET
///      / PIPE
///      / KEYWORD_orelse
///      / KEYWORD_catch Payload?
fn parseBitwiseOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = nextToken(it);
    const op: Node.InfixOp.Op = switch (token.ptr.id) {
        .Ampersand => .BitAnd,
        .Caret => .BitXor,
        .Pipe => .BitOr,
        .Keyword_orelse => .UnwrapOptional,
        .Keyword_catch => .{ .Catch = try parsePayload(arena, it, tree) },
        else => {
            putBackToken(it, token.index);
            return null;
        },
    };

    return try createInfixOp(arena, token.index, op);
}

/// BitShiftOp
///     <- LARROW2
///      / RARROW2
fn parseBitShiftOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = nextToken(it);
    const op: Node.InfixOp.Op = switch (token.ptr.id) {
        .AngleBracketAngleBracketLeft => .BitShiftLeft,
        .AngleBracketAngleBracketRight => .BitShiftRight,
        else => {
            putBackToken(it, token.index);
            return null;
        },
    };

    return try createInfixOp(arena, token.index, op);
}

/// AdditionOp
///     <- PLUS
///      / MINUS
///      / PLUS2
///      / PLUSPERCENT
///      / MINUSPERCENT
fn parseAdditionOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = nextToken(it);
    const op: Node.InfixOp.Op = switch (token.ptr.id) {
        .Plus => .Add,
        .Minus => .Sub,
        .PlusPlus => .ArrayCat,
        .PlusPercent => .AddWrap,
        .MinusPercent => .SubWrap,
        else => {
            putBackToken(it, token.index);
            return null;
        },
    };

    return try createInfixOp(arena, token.index, op);
}

/// MultiplyOp
///     <- PIPE2
///      / ASTERISK
///      / SLASH
///      / PERCENT
///      / ASTERISK2
///      / ASTERISKPERCENT
fn parseMultiplyOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = nextToken(it);
    const op: Node.InfixOp.Op = switch (token.ptr.id) {
        .PipePipe => .MergeErrorSets,
        .Asterisk => .Mul,
        .Slash => .Div,
        .Percent => .Mod,
        .AsteriskAsterisk => .ArrayMult,
        .AsteriskPercent => .MulWrap,
        else => {
            putBackToken(it, token.index);
            return null;
        },
    };

    return try createInfixOp(arena, token.index, op);
}

/// PrefixOp
///     <- EXCLAMATIONMARK
///      / MINUS
///      / TILDE
///      / MINUSPERCENT
///      / AMPERSAND
///      / KEYWORD_try
///      / KEYWORD_await
fn parsePrefixOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = nextToken(it);
    const op: Node.PrefixOp.Op = switch (token.ptr.id) {
        .Bang => .BoolNot,
        .Minus => .Negation,
        .Tilde => .BitNot,
        .MinusPercent => .NegationWrap,
        .Ampersand => .AddressOf,
        .Keyword_try => .Try,
        .Keyword_await => .Await,
        else => {
            putBackToken(it, token.index);
            return null;
        },
    };

    const node = try arena.create(Node.PrefixOp);
    node.* = .{
        .op_token = token.index,
        .op = op,
        .rhs = undefined, // set by caller
    };
    return &node.base;
}

// TODO: ArrayTypeStart is either an array or a slice, but const/allowzero only work on
//       pointers. Consider updating this rule:
//       ...
//       / ArrayTypeStart
//       / SliceTypeStart (ByteAlign / KEYWORD_const / KEYWORD_volatile / KEYWORD_allowzero)*
//       / PtrTypeStart ...

/// PrefixTypeOp
///     <- QUESTIONMARK
///      / KEYWORD_anyframe MINUSRARROW
///      / ArrayTypeStart (ByteAlign / KEYWORD_const / KEYWORD_volatile / KEYWORD_allowzero)*
///      / PtrTypeStart (KEYWORD_align LPAREN Expr (COLON INTEGER COLON INTEGER)? RPAREN / KEYWORD_const / KEYWORD_volatile / KEYWORD_allowzero)*
fn parsePrefixTypeOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    if (eatToken(it, .QuestionMark)) |token| {
        const node = try arena.create(Node.PrefixOp);
        node.* = .{
            .op_token = token,
            .op = .OptionalType,
            .rhs = undefined, // set by caller
        };
        return &node.base;
    }

    // TODO: Returning a AnyFrameType instead of PrefixOp makes casting and setting .rhs or
    //       .return_type more difficult for the caller (see parsePrefixOpExpr helper).
    //       Consider making the AnyFrameType a member of PrefixOp and add a
    //       PrefixOp.AnyFrameType variant?
    if (eatToken(it, .Keyword_anyframe)) |token| {
        const arrow = eatToken(it, .Arrow) orelse {
            putBackToken(it, token);
            return null;
        };
        const node = try arena.create(Node.AnyFrameType);
        node.* = .{
            .anyframe_token = token,
            .result = .{
                .arrow_token = arrow,
                .return_type = undefined, // set by caller
            },
        };
        return &node.base;
    }

    if (try parsePtrTypeStart(arena, it, tree)) |node| {
        // If the token encountered was **, there will be two nodes instead of one.
        // The attributes should be applied to the rightmost operator.
        const prefix_op = node.cast(Node.PrefixOp).?;
        var ptr_info = if (tree.tokens.at(prefix_op.op_token).id == .AsteriskAsterisk)
            &prefix_op.rhs.cast(Node.PrefixOp).?.op.PtrType
        else
            &prefix_op.op.PtrType;

        while (true) {
            if (eatToken(it, .Keyword_align)) |align_token| {
                const lparen = try expectToken(it, tree, .LParen);
                const expr_node = try expectNode(arena, it, tree, parseExpr, .{
                    .ExpectedExpr = .{ .token = it.index },
                });

                // Optional bit range
                const bit_range = if (eatToken(it, .Colon)) |_| bit_range_value: {
                    const range_start = try expectNode(arena, it, tree, parseIntegerLiteral, .{
                        .ExpectedIntegerLiteral = .{ .token = it.index },
                    });
                    _ = try expectToken(it, tree, .Colon);
                    const range_end = try expectNode(arena, it, tree, parseIntegerLiteral, .{
                        .ExpectedIntegerLiteral = .{ .token = it.index },
                    });

                    break :bit_range_value Node.PrefixOp.PtrInfo.Align.BitRange{
                        .start = range_start,
                        .end = range_end,
                    };
                } else null;
                _ = try expectToken(it, tree, .RParen);

                if (ptr_info.align_info != null) {
                    try tree.errors.push(.{
                        .ExtraAlignQualifier = .{ .token = it.index - 1 },
                    });
                    continue;
                }

                ptr_info.align_info = Node.PrefixOp.PtrInfo.Align{
                    .node = expr_node,
                    .bit_range = bit_range,
                };

                continue;
            }
            if (eatToken(it, .Keyword_const)) |const_token| {
                if (ptr_info.const_token != null) {
                    try tree.errors.push(.{
                        .ExtraConstQualifier = .{ .token = it.index - 1 },
                    });
                    continue;
                }
                ptr_info.const_token = const_token;
                continue;
            }
            if (eatToken(it, .Keyword_volatile)) |volatile_token| {
                if (ptr_info.volatile_token != null) {
                    try tree.errors.push(.{
                        .ExtraVolatileQualifier = .{ .token = it.index - 1 },
                    });
                    continue;
                }
                ptr_info.volatile_token = volatile_token;
                continue;
            }
            if (eatToken(it, .Keyword_allowzero)) |allowzero_token| {
                if (ptr_info.allowzero_token != null) {
                    try tree.errors.push(.{
                        .ExtraAllowZeroQualifier = .{ .token = it.index - 1 },
                    });
                    continue;
                }
                ptr_info.allowzero_token = allowzero_token;
                continue;
            }
            break;
        }

        return node;
    }

    if (try parseArrayTypeStart(arena, it, tree)) |node| {
        switch (node.cast(Node.PrefixOp).?.op) {
            .ArrayType => {},
            .SliceType => |*slice_type| {
                // Collect pointer qualifiers in any order, but disallow duplicates
                while (true) {
                    if (try parseByteAlign(arena, it, tree)) |align_expr| {
                        if (slice_type.align_info != null) {
                            try tree.errors.push(.{
                                .ExtraAlignQualifier = .{ .token = it.index - 1 },
                            });
                            continue;
                        }
                        slice_type.align_info = Node.PrefixOp.PtrInfo.Align{
                            .node = align_expr,
                            .bit_range = null,
                        };
                        continue;
                    }
                    if (eatToken(it, .Keyword_const)) |const_token| {
                        if (slice_type.const_token != null) {
                            try tree.errors.push(.{
                                .ExtraConstQualifier = .{ .token = it.index - 1 },
                            });
                            continue;
                        }
                        slice_type.const_token = const_token;
                        continue;
                    }
                    if (eatToken(it, .Keyword_volatile)) |volatile_token| {
                        if (slice_type.volatile_token != null) {
                            try tree.errors.push(.{
                                .ExtraVolatileQualifier = .{ .token = it.index - 1 },
                            });
                            continue;
                        }
                        slice_type.volatile_token = volatile_token;
                        continue;
                    }
                    if (eatToken(it, .Keyword_allowzero)) |allowzero_token| {
                        if (slice_type.allowzero_token != null) {
                            try tree.errors.push(.{
                                .ExtraAllowZeroQualifier = .{ .token = it.index - 1 },
                            });
                            continue;
                        }
                        slice_type.allowzero_token = allowzero_token;
                        continue;
                    }
                    break;
                }
            },
            else => unreachable,
        }
        return node;
    }

    return null;
}

/// SuffixOp
///     <- LBRACKET Expr (DOT2 (Expr (COLON Expr)?)?)? RBRACKET
///      / DOT IDENTIFIER
///      / DOTASTERISK
///      / DOTQUESTIONMARK
fn parseSuffixOp(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const OpAndToken = struct {
        op: Node.SuffixOp.Op,
        token: TokenIndex,
    };
    const op_and_token: OpAndToken = blk: {
        if (eatToken(it, .LBracket)) |_| {
            const index_expr = try expectNode(arena, it, tree, parseExpr, .{
                .ExpectedExpr = .{ .token = it.index },
            });

            if (eatToken(it, .Ellipsis2) != null) {
                const end_expr = try parseExpr(arena, it, tree);
                const sentinel: ?*ast.Node = if (eatToken(it, .Colon) != null)
                    try parseExpr(arena, it, tree)
                else
                    null;
                break :blk .{
                    .op = .{
                        .Slice = .{
                            .start = index_expr,
                            .end = end_expr,
                            .sentinel = sentinel,
                        },
                    },
                    .token = try expectToken(it, tree, .RBracket),
                };
            }

            break :blk .{
                .op = .{ .ArrayAccess = index_expr },
                .token = try expectToken(it, tree, .RBracket),
            };
        }

        if (eatToken(it, .PeriodAsterisk)) |period_asterisk| {
            break :blk .{ .op = .Deref, .token = period_asterisk };
        }

        if (eatToken(it, .Period)) |period| {
            if (try parseIdentifier(arena, it, tree)) |identifier| {
                // TODO: It's a bit weird to return an InfixOp from the SuffixOp parser.
                // Should there be an ast.Node.SuffixOp.FieldAccess variant? Or should
                // this grammar rule be altered?
                const node = try arena.create(Node.InfixOp);
                node.* = .{
                    .op_token = period,
                    .lhs = undefined, // set by caller
                    .op = .Period,
                    .rhs = identifier,
                };
                return &node.base;
            }
            if (eatToken(it, .QuestionMark)) |question_mark| {
                break :blk .{ .op = .UnwrapOptional, .token = question_mark };
            }
            try tree.errors.push(.{
                .ExpectedSuffixOp = .{ .token = it.index },
            });
            return null;
        }

        return null;
    };

    const node = try arena.create(Node.SuffixOp);
    node.* = .{
        .lhs = undefined, // set by caller
        .op = op_and_token.op,
        .rtoken = op_and_token.token,
    };
    return &node.base;
}

/// FnCallArguments <- LPAREN ExprList RPAREN
/// ExprList <- (Expr COMMA)* Expr?
fn parseFnCallArguments(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?AnnotatedParamList {
    if (eatToken(it, .LParen) == null) return null;
    const list = try ListParseFn(Node.FnProto.ParamList, parseExpr)(arena, it, tree);
    const rparen = try expectToken(it, tree, .RParen);
    return AnnotatedParamList{ .list = list, .rparen = rparen };
}

const AnnotatedParamList = struct {
    list: Node.FnProto.ParamList, // NOTE: may also be any other type SegmentedList(*Node, 2)
    rparen: TokenIndex,
};

/// ArrayTypeStart <- LBRACKET Expr? RBRACKET
fn parseArrayTypeStart(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const lbracket = eatToken(it, .LBracket) orelse return null;
    const expr = try parseExpr(arena, it, tree);
    const sentinel = if (eatToken(it, .Colon)) |_|
        try expectNode(arena, it, tree, parseExpr, .{
            .ExpectedExpr = .{ .token = it.index },
        })
    else
        null;
    const rbracket = try expectToken(it, tree, .RBracket);

    const op: Node.PrefixOp.Op = if (expr) |len_expr|
        .{
            .ArrayType = .{
                .len_expr = len_expr,
                .sentinel = sentinel,
            },
        }
    else
        .{
            .SliceType = Node.PrefixOp.PtrInfo{
                .allowzero_token = null,
                .align_info = null,
                .const_token = null,
                .volatile_token = null,
                .sentinel = sentinel,
            },
        };

    const node = try arena.create(Node.PrefixOp);
    node.* = .{
        .op_token = lbracket,
        .op = op,
        .rhs = undefined, // set by caller
    };
    return &node.base;
}

/// PtrTypeStart
///     <- ASTERISK
///      / ASTERISK2
///      / PTRUNKNOWN
///      / PTRC
fn parsePtrTypeStart(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    if (eatToken(it, .Asterisk)) |asterisk| {
        const sentinel = if (eatToken(it, .Colon)) |_|
            try expectNode(arena, it, tree, parseExpr, .{
                .ExpectedExpr = .{ .token = it.index },
            })
        else
            null;
        const node = try arena.create(Node.PrefixOp);
        node.* = .{
            .op_token = asterisk,
            .op = .{ .PtrType = .{ .sentinel = sentinel } },
            .rhs = undefined, // set by caller
        };
        return &node.base;
    }

    if (eatToken(it, .AsteriskAsterisk)) |double_asterisk| {
        const node = try arena.create(Node.PrefixOp);
        node.* = .{
            .op_token = double_asterisk,
            .op = .{ .PtrType = .{} },
            .rhs = undefined, // set by caller
        };

        // Special case for **, which is its own token
        const child = try arena.create(Node.PrefixOp);
        child.* = .{
            .op_token = double_asterisk,
            .op = .{ .PtrType = .{} },
            .rhs = undefined, // set by caller
        };
        node.rhs = &child.base;

        return &node.base;
    }
    if (eatToken(it, .LBracket)) |lbracket| {
        const asterisk = eatToken(it, .Asterisk) orelse {
            putBackToken(it, lbracket);
            return null;
        };
        if (eatToken(it, .Identifier)) |ident| {
            if (!std.mem.eql(u8, tree.tokenSlice(ident), "c")) {
                putBackToken(it, ident);
            } else {
                _ = try expectToken(it, tree, .RBracket);
                const node = try arena.create(Node.PrefixOp);
                node.* = .{
                    .op_token = lbracket,
                    .op = .{ .PtrType = .{} },
                    .rhs = undefined, // set by caller
                };
                return &node.base;
            }
        }
        const sentinel = if (eatToken(it, .Colon)) |_|
            try expectNode(arena, it, tree, parseExpr, .{
                .ExpectedExpr = .{ .token = it.index },
            })
        else
            null;
        _ = try expectToken(it, tree, .RBracket);
        const node = try arena.create(Node.PrefixOp);
        node.* = .{
            .op_token = lbracket,
            .op = .{ .PtrType = .{ .sentinel = sentinel } },
            .rhs = undefined, // set by caller
        };
        return &node.base;
    }
    return null;
}

/// ContainerDeclAuto <- ContainerDeclType LBRACE ContainerMembers RBRACE
fn parseContainerDeclAuto(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const node = (try parseContainerDeclType(arena, it, tree)) orelse return null;
    const lbrace = try expectToken(it, tree, .LBrace);
    const members = try parseContainerMembers(arena, it, tree, false);
    const rbrace = try expectToken(it, tree, .RBrace);

    const decl_type = node.cast(Node.ContainerDecl).?;
    decl_type.fields_and_decls = members;
    decl_type.lbrace_token = lbrace;
    decl_type.rbrace_token = rbrace;

    return node;
}

/// ContainerDeclType
///     <- KEYWORD_struct
///      / KEYWORD_enum (LPAREN Expr RPAREN)?
///      / KEYWORD_union (LPAREN (KEYWORD_enum (LPAREN Expr RPAREN)? / Expr) RPAREN)?
fn parseContainerDeclType(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const kind_token = nextToken(it);

    const init_arg_expr = switch (kind_token.ptr.id) {
        .Keyword_struct => Node.ContainerDecl.InitArg{ .None = {} },
        .Keyword_enum => blk: {
            if (eatToken(it, .LParen) != null) {
                const expr = try expectNode(arena, it, tree, parseExpr, .{
                    .ExpectedExpr = .{ .token = it.index },
                });
                _ = try expectToken(it, tree, .RParen);
                break :blk Node.ContainerDecl.InitArg{ .Type = expr };
            }
            break :blk Node.ContainerDecl.InitArg{ .None = {} };
        },
        .Keyword_union => blk: {
            if (eatToken(it, .LParen) != null) {
                if (eatToken(it, .Keyword_enum) != null) {
                    if (eatToken(it, .LParen) != null) {
                        const expr = try expectNode(arena, it, tree, parseExpr, .{
                            .ExpectedExpr = .{ .token = it.index },
                        });
                        _ = try expectToken(it, tree, .RParen);
                        _ = try expectToken(it, tree, .RParen);
                        break :blk Node.ContainerDecl.InitArg{ .Enum = expr };
                    }
                    _ = try expectToken(it, tree, .RParen);
                    break :blk Node.ContainerDecl.InitArg{ .Enum = null };
                }
                const expr = try expectNode(arena, it, tree, parseExpr, .{
                    .ExpectedExpr = .{ .token = it.index },
                });
                _ = try expectToken(it, tree, .RParen);
                break :blk Node.ContainerDecl.InitArg{ .Type = expr };
            }
            break :blk Node.ContainerDecl.InitArg{ .None = {} };
        },
        else => {
            putBackToken(it, kind_token.index);
            return null;
        },
    };

    const node = try arena.create(Node.ContainerDecl);
    node.* = .{
        .layout_token = null,
        .kind_token = kind_token.index,
        .init_arg_expr = init_arg_expr,
        .fields_and_decls = undefined, // set by caller
        .lbrace_token = undefined, // set by caller
        .rbrace_token = undefined, // set by caller
    };
    return &node.base;
}

/// ByteAlign <- KEYWORD_align LPAREN Expr RPAREN
fn parseByteAlign(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    _ = eatToken(it, .Keyword_align) orelse return null;
    _ = try expectToken(it, tree, .LParen);
    const expr = try expectNode(arena, it, tree, parseExpr, .{
        .ExpectedExpr = .{ .token = it.index },
    });
    _ = try expectToken(it, tree, .RParen);
    return expr;
}

/// IdentifierList <- (IDENTIFIER COMMA)* IDENTIFIER?
/// Only ErrorSetDecl parses an IdentifierList
fn parseErrorTagList(arena: *Allocator, it: *TokenIterator, tree: *Tree) !Node.ErrorSetDecl.DeclList {
    return try ListParseFn(Node.ErrorSetDecl.DeclList, parseErrorTag)(arena, it, tree);
}

/// SwitchProngList <- (SwitchProng COMMA)* SwitchProng?
fn parseSwitchProngList(arena: *Allocator, it: *TokenIterator, tree: *Tree) !Node.Switch.CaseList {
    return try ListParseFn(Node.Switch.CaseList, parseSwitchProng)(arena, it, tree);
}

/// AsmOutputList <- (AsmOutputItem COMMA)* AsmOutputItem?
fn parseAsmOutputList(arena: *Allocator, it: *TokenIterator, tree: *Tree) Error!Node.Asm.OutputList {
    return try ListParseFn(Node.Asm.OutputList, parseAsmOutputItem)(arena, it, tree);
}

/// AsmInputList <- (AsmInputItem COMMA)* AsmInputItem?
fn parseAsmInputList(arena: *Allocator, it: *TokenIterator, tree: *Tree) Error!Node.Asm.InputList {
    return try ListParseFn(Node.Asm.InputList, parseAsmInputItem)(arena, it, tree);
}

/// ParamDeclList <- (ParamDecl COMMA)* ParamDecl?
fn parseParamDeclList(arena: *Allocator, it: *TokenIterator, tree: *Tree) !Node.FnProto.ParamList {
    return try ListParseFn(Node.FnProto.ParamList, parseParamDecl)(arena, it, tree);
}

fn ParseFn(comptime T: type) type {
    return fn (*Allocator, *TokenIterator, *Tree) Error!T;
}

const NodeParseFn = fn (*Allocator, *TokenIterator, *Tree) Error!?*Node;

fn ListParseFn(comptime L: type, comptime nodeParseFn: var) ParseFn(L) {
    return struct {
        pub fn parse(arena: *Allocator, it: *TokenIterator, tree: *Tree) !L {
            var list = L.init(arena);
            while (try nodeParseFn(arena, it, tree)) |node| {
                try list.push(node);

                switch (it.peek().?.id) {
                    .Comma => _ = nextToken(it),
                    // all possible delimiters
                    .Colon, .RParen, .RBrace, .RBracket => break,
                    else => {
                        // this is likely just a missing comma,
                        // continue parsing this list and give an error
                        try tree.errors.push(.{
                            .ExpectedToken = .{ .token = it.index, .expected_id = .Comma },
                        });
                    },
                }
            }
            return list;
        }
    }.parse;
}

fn SimpleBinOpParseFn(comptime token: Token.Id, comptime op: Node.InfixOp.Op) NodeParseFn {
    return struct {
        pub fn parse(arena: *Allocator, it: *TokenIterator, tree: *Tree) Error!?*Node {
            const op_token = if (token == .Keyword_and) switch (it.peek().?.id) {
                .Keyword_and => nextToken(it).index,
                .Invalid_ampersands => blk: {
                    try tree.errors.push(.{
                        .InvalidAnd = .{ .token = it.index },
                    });
                    break :blk nextToken(it).index;
                },
                else => return null,
            } else eatToken(it, token) orelse return null;

            const node = try arena.create(Node.InfixOp);
            node.* = .{
                .op_token = op_token,
                .lhs = undefined, // set by caller
                .op = op,
                .rhs = undefined, // set by caller
            };
            return &node.base;
        }
    }.parse;
}

// Helper parsers not included in the grammar

fn parseBuiltinCall(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = eatToken(it, .Builtin) orelse return null;
    const params = (try parseFnCallArguments(arena, it, tree)) orelse {
        try tree.errors.push(.{
            .ExpectedParamList = .{ .token = it.index },
        });

        // lets pretend this was an identifier so we can continue parsing
        const node = try arena.create(Node.Identifier);
        node.* = .{
            .token = token,
        };
        return &node.base;
    };
    const node = try arena.create(Node.BuiltinCall);
    node.* = .{
        .builtin_token = token,
        .params = params.list,
        .rparen_token = params.rparen,
    };
    return &node.base;
}

fn parseErrorTag(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const doc_comments = try parseDocComment(arena, it, tree); // no need to rewind on failure
    const token = eatToken(it, .Identifier) orelse return null;

    const node = try arena.create(Node.ErrorTag);
    node.* = .{
        .doc_comments = doc_comments,
        .name_token = token,
    };
    return &node.base;
}

fn parseIdentifier(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = eatToken(it, .Identifier) orelse return null;
    const node = try arena.create(Node.Identifier);
    node.* = .{
        .token = token,
    };
    return &node.base;
}

fn parseVarType(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = eatToken(it, .Keyword_var) orelse return null;
    const node = try arena.create(Node.VarType);
    node.* = .{
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

fn parseStringLiteralSingle(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    if (eatToken(it, .StringLiteral)) |token| {
        const node = try arena.create(Node.StringLiteral);
        node.* = .{
            .token = token,
        };
        return &node.base;
    }
    return null;
}

// string literal or multiline string literal
fn parseStringLiteral(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    if (try parseStringLiteralSingle(arena, it, tree)) |node| return node;

    if (eatToken(it, .MultilineStringLiteralLine)) |first_line| {
        const node = try arena.create(Node.MultilineStringLiteral);
        node.* = .{
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
    node.* = .{
        .token = token,
    };
    return &node.base;
}

fn parseFloatLiteral(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = eatToken(it, .FloatLiteral) orelse return null;
    const node = try arena.create(Node.FloatLiteral);
    node.* = .{
        .token = token,
    };
    return &node.base;
}

fn parseTry(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = eatToken(it, .Keyword_try) orelse return null;
    const node = try arena.create(Node.PrefixOp);
    node.* = .{
        .op_token = token,
        .op = .Try,
        .rhs = undefined, // set by caller
    };
    return &node.base;
}

fn parseUse(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    const token = eatToken(it, .Keyword_usingnamespace) orelse return null;
    const node = try arena.create(Node.Use);
    node.* = .{
        .doc_comments = null,
        .visib_token = null,
        .use_token = token,
        .expr = try expectNode(arena, it, tree, parseExpr, .{
            .ExpectedExpr = .{ .token = it.index },
        }),
        .semicolon_token = try expectToken(it, tree, .Semicolon),
    };
    return &node.base;
}

/// IfPrefix Body (KEYWORD_else Payload? Body)?
fn parseIf(arena: *Allocator, it: *TokenIterator, tree: *Tree, bodyParseFn: NodeParseFn) !?*Node {
    const node = (try parseIfPrefix(arena, it, tree)) orelse return null;
    const if_prefix = node.cast(Node.If).?;

    if_prefix.body = try expectNode(arena, it, tree, bodyParseFn, .{
        .InvalidToken = .{ .token = it.index },
    });

    const else_token = eatToken(it, .Keyword_else) orelse return node;
    const payload = try parsePayload(arena, it, tree);
    const else_expr = try expectNode(arena, it, tree, bodyParseFn, .{
        .InvalidToken = .{ .token = it.index },
    });
    const else_node = try arena.create(Node.Else);
    else_node.* = .{
        .else_token = else_token,
        .payload = payload,
        .body = else_expr,
    };
    if_prefix.@"else" = else_node;

    return node;
}

/// Eat a multiline doc comment
fn parseDocComment(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node.DocComment {
    var lines = Node.DocComment.LineList.init(arena);
    while (eatToken(it, .DocComment)) |line| {
        try lines.push(line);
    }

    if (lines.len == 0) return null;

    const node = try arena.create(Node.DocComment);
    node.* = .{
        .lines = lines,
    };
    return node;
}

/// Eat a single-line doc comment on the same line as another node
fn parseAppendedDocComment(arena: *Allocator, it: *TokenIterator, tree: *Tree, after_token: TokenIndex) !?*Node.DocComment {
    const comment_token = eatToken(it, .DocComment) orelse return null;
    if (tree.tokensOnSameLine(after_token, comment_token)) {
        const node = try arena.create(Node.DocComment);
        node.* = .{
            .lines = Node.DocComment.LineList.init(arena),
        };
        try node.lines.push(comment_token);
        return node;
    }
    putBackToken(it, comment_token);
    return null;
}

/// Op* Child
fn parsePrefixOpExpr(
    arena: *Allocator,
    it: *TokenIterator,
    tree: *Tree,
    opParseFn: NodeParseFn,
    childParseFn: NodeParseFn,
) Error!?*Node {
    if (try opParseFn(arena, it, tree)) |first_op| {
        var rightmost_op = first_op;
        while (true) {
            switch (rightmost_op.id) {
                .PrefixOp => {
                    var prefix_op = rightmost_op.cast(Node.PrefixOp).?;
                    // If the token encountered was **, there will be two nodes
                    if (tree.tokens.at(prefix_op.op_token).id == .AsteriskAsterisk) {
                        rightmost_op = prefix_op.rhs;
                        prefix_op = rightmost_op.cast(Node.PrefixOp).?;
                    }
                    if (try opParseFn(arena, it, tree)) |rhs| {
                        prefix_op.rhs = rhs;
                        rightmost_op = rhs;
                    } else break;
                },
                .AnyFrameType => {
                    const prom = rightmost_op.cast(Node.AnyFrameType).?;
                    if (try opParseFn(arena, it, tree)) |rhs| {
                        prom.result.?.return_type = rhs;
                        rightmost_op = rhs;
                    } else break;
                },
                else => unreachable,
            }
        }

        // If any prefix op existed, a child node on the RHS is required
        switch (rightmost_op.id) {
            .PrefixOp => {
                const prefix_op = rightmost_op.cast(Node.PrefixOp).?;
                prefix_op.rhs = try expectNode(arena, it, tree, childParseFn, .{
                    .InvalidToken = .{ .token = it.index },
                });
            },
            .AnyFrameType => {
                const prom = rightmost_op.cast(Node.AnyFrameType).?;
                prom.result.?.return_type = try expectNode(arena, it, tree, childParseFn, .{
                    .InvalidToken = .{ .token = it.index },
                });
            },
            else => unreachable,
        }

        return first_op;
    }

    // Otherwise, the child node is optional
    return try childParseFn(arena, it, tree);
}

/// Child (Op Child)*
/// Child (Op Child)?
fn parseBinOpExpr(
    arena: *Allocator,
    it: *TokenIterator,
    tree: *Tree,
    opParseFn: NodeParseFn,
    childParseFn: NodeParseFn,
    chain: enum {
        Once,
        Infinitely,
    },
) Error!?*Node {
    var res = (try childParseFn(arena, it, tree)) orelse return null;

    while (try opParseFn(arena, it, tree)) |node| {
        const right = try expectNode(arena, it, tree, childParseFn, .{
            .InvalidToken = .{ .token = it.index },
        });
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

fn createInfixOp(arena: *Allocator, index: TokenIndex, op: Node.InfixOp.Op) !*Node {
    const node = try arena.create(Node.InfixOp);
    node.* = .{
        .op_token = index,
        .lhs = undefined, // set by caller
        .op = op,
        .rhs = undefined, // set by caller
    };
    return &node.base;
}

fn eatToken(it: *TokenIterator, id: Token.Id) ?TokenIndex {
    return if (eatAnnotatedToken(it, id)) |token| token.index else null;
}

fn eatAnnotatedToken(it: *TokenIterator, id: Token.Id) ?AnnotatedToken {
    return if (it.peek().?.id == id) nextToken(it) else null;
}

fn expectToken(it: *TokenIterator, tree: *Tree, id: Token.Id) Error!TokenIndex {
    return (try expectTokenRecoverable(it, tree, id)) orelse
        error.ParseError;
}

fn expectTokenRecoverable(it: *TokenIterator, tree: *Tree, id: Token.Id) !?TokenIndex {
    const token = nextToken(it);
    if (token.ptr.id != id) {
        try tree.errors.push(.{
            .ExpectedToken = .{ .token = token.index, .expected_id = id },
        });
        // go back so that we can recover properly
        putBackToken(it, token.index);
        return null;
    }
    return token.index;
}

fn nextToken(it: *TokenIterator) AnnotatedToken {
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

fn putBackToken(it: *TokenIterator, putting_back: TokenIndex) void {
    while (true) {
        const prev_tok = it.prev() orelse return;
        if (prev_tok.id == .LineComment) continue;
        assert(it.list.at(putting_back) == prev_tok);
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
    parseFn: NodeParseFn,
    err: AstError, // if parsing fails
) Error!*Node {
    return (try expectNodeRecoverable(arena, it, tree, parseFn, err)) orelse
        return error.ParseError;
}

fn expectNodeRecoverable(
    arena: *Allocator,
    it: *TokenIterator,
    tree: *Tree,
    parseFn: NodeParseFn,
    err: AstError, // if parsing fails
) !?*Node {
    return (try parseFn(arena, it, tree)) orelse {
        try tree.errors.push(err);
        return null;
    };
}

test "std.zig.parser" {
    _ = @import("parser_test.zig");
}
