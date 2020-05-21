const std = @import("../std.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ast = std.zig.ast;
const Node = ast.Node;
const Tree = ast.Tree;
const AstError = ast.Error;
const TokenIndex = ast.TokenIndex;
const Token = std.zig.Token;

pub const Error = error{ParseError} || Allocator.Error;

/// This is the maximum length of a list that will be copied into the ast.Tree
/// arena when parsing. If the list is longer than this, the ast.Tree will have
/// a reference to the memory allocated in the general purpose allocator, and
/// will free it separately. Simply put, lists longer than this will elide the
/// memcpy().
const large_list_len = 512;

/// Result should be freed with tree.deinit() when there are
/// no more references to any of the tokens or nodes.
pub fn parse(gpa: *Allocator, source: []const u8) Allocator.Error!*Tree {
    // TODO optimization idea: ensureCapacity on the tokens list and
    // then appendAssumeCapacity inside the loop.
    var tokens = std.ArrayList(Token).init(gpa);
    defer tokens.deinit();

    var tokenizer = std.zig.Tokenizer.init(source);
    while (true) {
        const tree_token = try tokens.addOne();
        tree_token.* = tokenizer.next();
        if (tree_token.id == .Eof) break;
    }

    var parser: Parser = .{
        .source = source,
        .arena = std.heap.ArenaAllocator.init(gpa),
        .gpa = gpa,
        .tokens = tokens.items,
        .errors = .{},
        .tok_i = 0,
        .owned_memory = .{},
    };
    defer parser.owned_memory.deinit(gpa);
    errdefer for (parser.owned_memory.items) |list| {
        gpa.free(list);
    };
    defer parser.errors.deinit(gpa);
    errdefer parser.arena.deinit();

    while (tokens.items[parser.tok_i].id == .LineComment) parser.tok_i += 1;

    const root_node = try parser.parseRoot();

    const tree = try parser.arena.allocator.create(Tree);
    tree.* = .{
        .gpa = gpa,
        .source = source,
        .tokens = tokens.toOwnedSlice(),
        .errors = parser.errors.toOwnedSlice(gpa),
        .owned_memory = parser.owned_memory.toOwnedSlice(gpa),
        .root_node = root_node,
        .arena = parser.arena.state,
    };
    return tree;
}

/// Represents in-progress parsing, will be converted to an ast.Tree after completion.
const Parser = struct {
    arena: std.heap.ArenaAllocator,
    gpa: *Allocator,
    source: []const u8,
    tokens: []const Token,
    tok_i: TokenIndex,
    errors: std.ArrayListUnmanaged(AstError),
    owned_memory: std.ArrayListUnmanaged([]u8),

    /// Root <- skip ContainerMembers eof
    fn parseRoot(p: *Parser) Allocator.Error!*Node.Root {
        const decls = try parseContainerMembers(p, true);
        defer p.gpa.free(decls);

        // parseContainerMembers will try to skip as much
        // invalid tokens as it can so this can only be the EOF
        const eof_token = p.eatToken(.Eof).?;

        const node = try Node.Root.create(&p.arena.allocator, decls.len, eof_token);
        std.mem.copy(*Node, node.decls(), decls);

        return node;
    }

    /// Helper function for appending elements to a singly linked list.
    fn llpush(
        p: *Parser,
        comptime T: type,
        it: *?*std.SinglyLinkedList(T).Node,
        data: T,
    ) !*?*std.SinglyLinkedList(T).Node {
        const llnode = try p.arena.allocator.create(std.SinglyLinkedList(T).Node);
        llnode.* = .{ .data = data };
        it.* = llnode;
        return &llnode.next;
    }

    /// ContainerMembers
    ///     <- TestDecl ContainerMembers
    ///      / TopLevelComptime ContainerMembers
    ///      / KEYWORD_pub? TopLevelDecl ContainerMembers
    ///      / ContainerField COMMA ContainerMembers
    ///      / ContainerField
    ///      /
    fn parseContainerMembers(p: *Parser, top_level: bool) ![]*Node {
        var list = std.ArrayList(*Node).init(p.gpa);
        defer list.deinit();

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
            if (try p.parseContainerDocComments()) |node| {
                try list.append(node);
                continue;
            }

            const doc_comments = try p.parseDocComment();

            if (p.parseTestDecl() catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.ParseError => {
                    p.findNextContainerMember();
                    continue;
                },
            }) |node| {
                if (field_state == .seen) {
                    field_state = .{ .end = node.firstToken() };
                }
                node.cast(Node.TestDecl).?.doc_comments = doc_comments;
                try list.append(node);
                continue;
            }

            if (p.parseTopLevelComptime() catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.ParseError => {
                    p.findNextContainerMember();
                    continue;
                },
            }) |node| {
                if (field_state == .seen) {
                    field_state = .{ .end = node.firstToken() };
                }
                node.cast(Node.Comptime).?.doc_comments = doc_comments;
                try list.append(node);
                continue;
            }

            const visib_token = p.eatToken(.Keyword_pub);

            if (p.parseTopLevelDecl() catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.ParseError => {
                    p.findNextContainerMember();
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
                try list.append(node);
                if (try p.parseAppendedDocComment(node.lastToken())) |appended_comment| {
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
                try p.errors.append(p.gpa, .{
                    .ExpectedPubItem = .{ .token = p.tok_i },
                });
                // ignore this pub
                continue;
            }

            if (p.parseContainerField() catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.ParseError => {
                    // attempt to recover
                    p.findNextContainerMember();
                    continue;
                },
            }) |node| {
                switch (field_state) {
                    .none => field_state = .seen,
                    .err, .seen => {},
                    .end => |tok| {
                        try p.errors.append(p.gpa, .{
                            .DeclBetweenFields = .{ .token = tok },
                        });
                        // continue parsing, error will be reported later
                        field_state = .err;
                    },
                }

                const field = node.cast(Node.ContainerField).?;
                field.doc_comments = doc_comments;
                try list.append(node);
                const comma = p.eatToken(.Comma) orelse {
                    // try to continue parsing
                    const index = p.tok_i;
                    p.findNextContainerMember();
                    const next = p.tokens[p.tok_i].id;
                    switch (next) {
                        .Eof => break,
                        else => {
                            if (next == .RBrace) {
                                if (!top_level) break;
                                _ = p.nextToken();
                            }

                            // add error and continue
                            try p.errors.append(p.gpa, .{
                                .ExpectedToken = .{ .token = index, .expected_id = .Comma },
                            });
                            continue;
                        },
                    }
                };
                if (try p.parseAppendedDocComment(comma)) |appended_comment|
                    field.doc_comments = appended_comment;
                continue;
            }

            // Dangling doc comment
            if (doc_comments != null) {
                try p.errors.append(p.gpa, .{
                    .UnattachedDocComment = .{ .token = doc_comments.?.firstToken() },
                });
            }

            const next = p.tokens[p.tok_i].id;
            switch (next) {
                .Eof => break,
                .Keyword_comptime => {
                    _ = p.nextToken();
                    try p.errors.append(p.gpa, .{
                        .ExpectedBlockOrField = .{ .token = p.tok_i },
                    });
                },
                else => {
                    const index = p.tok_i;
                    if (next == .RBrace) {
                        if (!top_level) break;
                        _ = p.nextToken();
                    }

                    // this was likely not supposed to end yet,
                    // try to find the next declaration
                    p.findNextContainerMember();
                    try p.errors.append(p.gpa, .{
                        .ExpectedContainerMembers = .{ .token = index },
                    });
                },
            }
        }

        return list.toOwnedSlice();
    }

    /// Attempts to find next container member by searching for certain tokens
    fn findNextContainerMember(p: *Parser) void {
        var level: u32 = 0;
        while (true) {
            const tok = p.nextToken();
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
                        p.putBackToken(tok.index);
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
                        p.putBackToken(tok.index);
                        return;
                    }
                    level -= 1;
                },
                .Eof => {
                    p.putBackToken(tok.index);
                    return;
                },
                else => {},
            }
        }
    }

    /// Attempts to find the next statement by searching for a semicolon
    fn findNextStmt(p: *Parser) void {
        var level: u32 = 0;
        while (true) {
            const tok = p.nextToken();
            switch (tok.ptr.id) {
                .LBrace => level += 1,
                .RBrace => {
                    if (level == 0) {
                        p.putBackToken(tok.index);
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
                    p.putBackToken(tok.index);
                    return;
                },
                else => {},
            }
        }
    }

    /// Eat a multiline container doc comment
    fn parseContainerDocComments(p: *Parser) !?*Node {
        var lines = Node.DocComment.LineList{};
        var lines_it: *?*Node.DocComment.LineList.Node = &lines.first;

        while (p.eatToken(.ContainerDocComment)) |line| {
            lines_it = try p.llpush(TokenIndex, lines_it, line);
        }

        if (lines.first == null) return null;

        const node = try p.arena.allocator.create(Node.DocComment);
        node.* = .{
            .lines = lines,
        };
        return &node.base;
    }

    /// TestDecl <- KEYWORD_test STRINGLITERALSINGLE Block
    fn parseTestDecl(p: *Parser) !?*Node {
        const test_token = p.eatToken(.Keyword_test) orelse return null;
        const name_node = try p.expectNode(parseStringLiteralSingle, .{
            .ExpectedStringLiteral = .{ .token = p.tok_i },
        });
        const block_node = try p.expectNode(parseBlock, .{
            .ExpectedLBrace = .{ .token = p.tok_i },
        });

        const test_node = try p.arena.allocator.create(Node.TestDecl);
        test_node.* = .{
            .doc_comments = null,
            .test_token = test_token,
            .name = name_node,
            .body_node = block_node,
        };
        return &test_node.base;
    }

    /// TopLevelComptime <- KEYWORD_comptime BlockExpr
    fn parseTopLevelComptime(p: *Parser) !?*Node {
        const tok = p.eatToken(.Keyword_comptime) orelse return null;
        const lbrace = p.eatToken(.LBrace) orelse {
            p.putBackToken(tok);
            return null;
        };
        p.putBackToken(lbrace);
        const block_node = try p.expectNode(parseBlockExpr, .{
            .ExpectedLabelOrLBrace = .{ .token = p.tok_i },
        });

        const comptime_node = try p.arena.allocator.create(Node.Comptime);
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
    fn parseTopLevelDecl(p: *Parser) !?*Node {
        var lib_name: ?*Node = null;
        const extern_export_inline_token = blk: {
            if (p.eatToken(.Keyword_export)) |token| break :blk token;
            if (p.eatToken(.Keyword_extern)) |token| {
                lib_name = try p.parseStringLiteralSingle();
                break :blk token;
            }
            if (p.eatToken(.Keyword_inline)) |token| break :blk token;
            if (p.eatToken(.Keyword_noinline)) |token| break :blk token;
            break :blk null;
        };

        if (try p.parseFnProto()) |node| {
            const fn_node = node.cast(Node.FnProto).?;
            fn_node.*.extern_export_inline_token = extern_export_inline_token;
            fn_node.*.lib_name = lib_name;
            if (p.eatToken(.Semicolon)) |_| return node;

            if (try p.expectNodeRecoverable(parseBlock, .{
                // since parseBlock only return error.ParseError on
                // a missing '}' we can assume this function was
                // supposed to end here.
                .ExpectedSemiOrLBrace = .{ .token = p.tok_i },
            })) |body_node| {
                fn_node.body_node = body_node;
            }
            return node;
        }

        if (extern_export_inline_token) |token| {
            if (p.tokens[token].id == .Keyword_inline or
                p.tokens[token].id == .Keyword_noinline)
            {
                try p.errors.append(p.gpa, .{
                    .ExpectedFn = .{ .token = p.tok_i },
                });
                return error.ParseError;
            }
        }

        const thread_local_token = p.eatToken(.Keyword_threadlocal);

        if (try p.parseVarDecl()) |node| {
            var var_decl = node.cast(Node.VarDecl).?;
            var_decl.*.thread_local_token = thread_local_token;
            var_decl.*.comptime_token = null;
            var_decl.*.extern_export_token = extern_export_inline_token;
            var_decl.*.lib_name = lib_name;
            return node;
        }

        if (thread_local_token != null) {
            try p.errors.append(p.gpa, .{
                .ExpectedVarDecl = .{ .token = p.tok_i },
            });
            // ignore this and try again;
            return error.ParseError;
        }

        if (extern_export_inline_token) |token| {
            try p.errors.append(p.gpa, .{
                .ExpectedVarDeclOrFn = .{ .token = p.tok_i },
            });
            // ignore this and try again;
            return error.ParseError;
        }

        return p.parseUse();
    }

    /// FnProto <- KEYWORD_fn IDENTIFIER? LPAREN ParamDeclList RPAREN ByteAlign? LinkSection? EXCLAMATIONMARK? (KEYWORD_var / TypeExpr)
    fn parseFnProto(p: *Parser) !?*Node {
        // TODO: Remove once extern/async fn rewriting is
        var is_async = false;
        var is_extern = false;
        const cc_token: ?TokenIndex = blk: {
            if (p.eatToken(.Keyword_extern)) |token| {
                is_extern = true;
                break :blk token;
            }
            if (p.eatToken(.Keyword_async)) |token| {
                is_async = true;
                break :blk token;
            }
            break :blk null;
        };
        const fn_token = p.eatToken(.Keyword_fn) orelse {
            if (cc_token) |token|
                p.putBackToken(token);
            return null;
        };
        var var_args_token: ?TokenIndex = null;
        const name_token = p.eatToken(.Identifier);
        const lparen = try p.expectToken(.LParen);
        const params = try p.parseParamDeclList(&var_args_token);
        defer p.gpa.free(params);
        const rparen = try p.expectToken(.RParen);
        const align_expr = try p.parseByteAlign();
        const section_expr = try p.parseLinkSection();
        const callconv_expr = try p.parseCallconv();
        const exclamation_token = p.eatToken(.Bang);

        const return_type_expr = (try p.parseVarType()) orelse
            try p.expectNodeRecoverable(parseTypeExpr, .{
            // most likely the user forgot to specify the return type.
            // Mark return type as invalid and try to continue.
            .ExpectedReturnType = .{ .token = p.tok_i },
        });

        // TODO https://github.com/ziglang/zig/issues/3750
        const R = Node.FnProto.ReturnType;
        const return_type = if (return_type_expr == null)
            R{ .Invalid = rparen }
        else if (exclamation_token != null)
            R{ .InferErrorSet = return_type_expr.? }
        else
            R{ .Explicit = return_type_expr.? };

        const fn_proto_node = try Node.FnProto.alloc(&p.arena.allocator, params.len);
        fn_proto_node.* = .{
            .doc_comments = null,
            .visib_token = null,
            .fn_token = fn_token,
            .name_token = name_token,
            .params_len = params.len,
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
        std.mem.copy(Node.FnProto.ParamDecl, fn_proto_node.params(), params);

        return &fn_proto_node.base;
    }

    /// VarDecl <- (KEYWORD_const / KEYWORD_var) IDENTIFIER (COLON TypeExpr)? ByteAlign? LinkSection? (EQUAL Expr)? SEMICOLON
    fn parseVarDecl(p: *Parser) !?*Node {
        const mut_token = p.eatToken(.Keyword_const) orelse
            p.eatToken(.Keyword_var) orelse
            return null;

        const name_token = try p.expectToken(.Identifier);
        const type_node = if (p.eatToken(.Colon) != null)
            try p.expectNode(parseTypeExpr, .{
                .ExpectedTypeExpr = .{ .token = p.tok_i },
            })
        else
            null;
        const align_node = try p.parseByteAlign();
        const section_node = try p.parseLinkSection();
        const eq_token = p.eatToken(.Equal);
        const init_node = if (eq_token != null) blk: {
            break :blk try p.expectNode(parseExpr, .{
                .ExpectedExpr = .{ .token = p.tok_i },
            });
        } else null;
        const semicolon_token = try p.expectToken(.Semicolon);

        const node = try p.arena.allocator.create(Node.VarDecl);
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
    fn parseContainerField(p: *Parser) !?*Node {
        const comptime_token = p.eatToken(.Keyword_comptime);
        const name_token = p.eatToken(.Identifier) orelse {
            if (comptime_token) |t| p.putBackToken(t);
            return null;
        };

        var align_expr: ?*Node = null;
        var type_expr: ?*Node = null;
        if (p.eatToken(.Colon)) |_| {
            if (p.eatToken(.Keyword_var)) |var_tok| {
                const node = try p.arena.allocator.create(Node.VarType);
                node.* = .{ .token = var_tok };
                type_expr = &node.base;
            } else {
                type_expr = try p.expectNode(parseTypeExpr, .{
                    .ExpectedTypeExpr = .{ .token = p.tok_i },
                });
                align_expr = try p.parseByteAlign();
            }
        }

        const value_expr = if (p.eatToken(.Equal)) |_|
            try p.expectNode(parseExpr, .{
                .ExpectedExpr = .{ .token = p.tok_i },
            })
        else
            null;

        const node = try p.arena.allocator.create(Node.ContainerField);
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
    fn parseStatement(p: *Parser) Error!?*Node {
        const comptime_token = p.eatToken(.Keyword_comptime);

        const var_decl_node = try p.parseVarDecl();
        if (var_decl_node) |node| {
            const var_decl = node.cast(Node.VarDecl).?;
            var_decl.comptime_token = comptime_token;
            return node;
        }

        if (comptime_token) |token| {
            const block_expr = try p.expectNode(parseBlockExprStatement, .{
                .ExpectedBlockOrAssignment = .{ .token = p.tok_i },
            });

            const node = try p.arena.allocator.create(Node.Comptime);
            node.* = .{
                .doc_comments = null,
                .comptime_token = token,
                .expr = block_expr,
            };
            return &node.base;
        }

        if (p.eatToken(.Keyword_nosuspend)) |nosuspend_token| {
            const block_expr = try p.expectNode(parseBlockExprStatement, .{
                .ExpectedBlockOrAssignment = .{ .token = p.tok_i },
            });

            const node = try p.arena.allocator.create(Node.Nosuspend);
            node.* = .{
                .nosuspend_token = nosuspend_token,
                .expr = block_expr,
            };
            return &node.base;
        }

        if (p.eatToken(.Keyword_suspend)) |suspend_token| {
            const semicolon = p.eatToken(.Semicolon);

            const body_node = if (semicolon == null) blk: {
                break :blk try p.expectNode(parseBlockExprStatement, .{
                    .ExpectedBlockOrExpression = .{ .token = p.tok_i },
                });
            } else null;

            const node = try p.arena.allocator.create(Node.Suspend);
            node.* = .{
                .suspend_token = suspend_token,
                .body = body_node,
            };
            return &node.base;
        }

        const defer_token = p.eatToken(.Keyword_defer) orelse p.eatToken(.Keyword_errdefer);
        if (defer_token) |token| {
            const payload = if (p.tokens[token].id == .Keyword_errdefer)
                try p.parsePayload()
            else
                null;
            const expr_node = try p.expectNode(parseBlockExprStatement, .{
                .ExpectedBlockOrExpression = .{ .token = p.tok_i },
            });
            const node = try p.arena.allocator.create(Node.Defer);
            node.* = .{
                .defer_token = token,
                .expr = expr_node,
                .payload = payload,
            };
            return &node.base;
        }

        if (try p.parseIfStatement()) |node| return node;
        if (try p.parseLabeledStatement()) |node| return node;
        if (try p.parseSwitchExpr()) |node| return node;
        if (try p.parseAssignExpr()) |node| {
            _ = try p.expectTokenRecoverable(.Semicolon);
            return node;
        }

        return null;
    }

    /// IfStatement
    ///     <- IfPrefix BlockExpr ( KEYWORD_else Payload? Statement )?
    ///      / IfPrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
    fn parseIfStatement(p: *Parser) !?*Node {
        const if_node = (try p.parseIfPrefix()) orelse return null;
        const if_prefix = if_node.cast(Node.If).?;

        const block_expr = (try p.parseBlockExpr());
        const assign_expr = if (block_expr == null)
            try p.expectNode(parseAssignExpr, .{
                .ExpectedBlockOrAssignment = .{ .token = p.tok_i },
            })
        else
            null;

        const semicolon = if (assign_expr != null) p.eatToken(.Semicolon) else null;

        const else_node = if (semicolon == null) blk: {
            const else_token = p.eatToken(.Keyword_else) orelse break :blk null;
            const payload = try p.parsePayload();
            const else_body = try p.expectNode(parseStatement, .{
                .InvalidToken = .{ .token = p.tok_i },
            });

            const node = try p.arena.allocator.create(Node.Else);
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
            try p.errors.append(p.gpa, .{
                .ExpectedSemiOrElse = .{ .token = p.tok_i },
            });
        }

        return if_node;
    }

    /// LabeledStatement <- BlockLabel? (Block / LoopStatement)
    fn parseLabeledStatement(p: *Parser) !?*Node {
        var colon: TokenIndex = undefined;
        const label_token = p.parseBlockLabel(&colon);

        if (try p.parseBlock()) |node| {
            node.cast(Node.Block).?.label = label_token;
            return node;
        }

        if (try p.parseLoopStatement()) |node| {
            if (node.cast(Node.For)) |for_node| {
                for_node.label = label_token;
            } else if (node.cast(Node.While)) |while_node| {
                while_node.label = label_token;
            } else unreachable;
            return node;
        }

        if (label_token != null) {
            try p.errors.append(p.gpa, .{
                .ExpectedLabelable = .{ .token = p.tok_i },
            });
            return error.ParseError;
        }

        return null;
    }

    /// LoopStatement <- KEYWORD_inline? (ForStatement / WhileStatement)
    fn parseLoopStatement(p: *Parser) !?*Node {
        const inline_token = p.eatToken(.Keyword_inline);

        if (try p.parseForStatement()) |node| {
            node.cast(Node.For).?.inline_token = inline_token;
            return node;
        }

        if (try p.parseWhileStatement()) |node| {
            node.cast(Node.While).?.inline_token = inline_token;
            return node;
        }
        if (inline_token == null) return null;

        // If we've seen "inline", there should have been a "for" or "while"
        try p.errors.append(p.gpa, .{
            .ExpectedInlinable = .{ .token = p.tok_i },
        });
        return error.ParseError;
    }

    /// ForStatement
    ///     <- ForPrefix BlockExpr ( KEYWORD_else Statement )?
    ///      / ForPrefix AssignExpr ( SEMICOLON / KEYWORD_else Statement )
    fn parseForStatement(p: *Parser) !?*Node {
        const node = (try p.parseForPrefix()) orelse return null;
        const for_prefix = node.cast(Node.For).?;

        if (try p.parseBlockExpr()) |block_expr_node| {
            for_prefix.body = block_expr_node;

            if (p.eatToken(.Keyword_else)) |else_token| {
                const statement_node = try p.expectNode(parseStatement, .{
                    .InvalidToken = .{ .token = p.tok_i },
                });

                const else_node = try p.arena.allocator.create(Node.Else);
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

        if (try p.parseAssignExpr()) |assign_expr| {
            for_prefix.body = assign_expr;

            if (p.eatToken(.Semicolon) != null) return node;

            if (p.eatToken(.Keyword_else)) |else_token| {
                const statement_node = try p.expectNode(parseStatement, .{
                    .ExpectedStatement = .{ .token = p.tok_i },
                });

                const else_node = try p.arena.allocator.create(Node.Else);
                else_node.* = .{
                    .else_token = else_token,
                    .payload = null,
                    .body = statement_node,
                };
                for_prefix.@"else" = else_node;
                return node;
            }

            try p.errors.append(p.gpa, .{
                .ExpectedSemiOrElse = .{ .token = p.tok_i },
            });

            return node;
        }

        return null;
    }

    /// WhileStatement
    ///     <- WhilePrefix BlockExpr ( KEYWORD_else Payload? Statement )?
    ///      / WhilePrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
    fn parseWhileStatement(p: *Parser) !?*Node {
        const node = (try p.parseWhilePrefix()) orelse return null;
        const while_prefix = node.cast(Node.While).?;

        if (try p.parseBlockExpr()) |block_expr_node| {
            while_prefix.body = block_expr_node;

            if (p.eatToken(.Keyword_else)) |else_token| {
                const payload = try p.parsePayload();

                const statement_node = try p.expectNode(parseStatement, .{
                    .InvalidToken = .{ .token = p.tok_i },
                });

                const else_node = try p.arena.allocator.create(Node.Else);
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

        if (try p.parseAssignExpr()) |assign_expr_node| {
            while_prefix.body = assign_expr_node;

            if (p.eatToken(.Semicolon) != null) return node;

            if (p.eatToken(.Keyword_else)) |else_token| {
                const payload = try p.parsePayload();

                const statement_node = try p.expectNode(parseStatement, .{
                    .ExpectedStatement = .{ .token = p.tok_i },
                });

                const else_node = try p.arena.allocator.create(Node.Else);
                else_node.* = .{
                    .else_token = else_token,
                    .payload = payload,
                    .body = statement_node,
                };
                while_prefix.@"else" = else_node;
                return node;
            }

            try p.errors.append(p.gpa, .{
                .ExpectedSemiOrElse = .{ .token = p.tok_i },
            });

            return node;
        }

        return null;
    }

    /// BlockExprStatement
    ///     <- BlockExpr
    ///      / AssignExpr SEMICOLON
    fn parseBlockExprStatement(p: *Parser) !?*Node {
        if (try p.parseBlockExpr()) |node| return node;
        if (try p.parseAssignExpr()) |node| {
            _ = try p.expectTokenRecoverable(.Semicolon);
            return node;
        }
        return null;
    }

    /// BlockExpr <- BlockLabel? Block
    fn parseBlockExpr(p: *Parser) Error!?*Node {
        var colon: TokenIndex = undefined;
        const label_token = p.parseBlockLabel(&colon);
        const block_node = (try p.parseBlock()) orelse {
            if (label_token) |label| {
                p.putBackToken(label + 1); // ":"
                p.putBackToken(label); // IDENTIFIER
            }
            return null;
        };
        block_node.cast(Node.Block).?.label = label_token;
        return block_node;
    }

    /// AssignExpr <- Expr (AssignOp Expr)?
    fn parseAssignExpr(p: *Parser) !?*Node {
        return p.parseBinOpExpr(parseAssignOp, parseExpr, .Once);
    }

    /// Expr <- KEYWORD_try* BoolOrExpr
    fn parseExpr(p: *Parser) Error!?*Node {
        return p.parsePrefixOpExpr(parseTry, parseBoolOrExpr);
    }

    /// BoolOrExpr <- BoolAndExpr (KEYWORD_or BoolAndExpr)*
    fn parseBoolOrExpr(p: *Parser) !?*Node {
        return p.parseBinOpExpr(
            SimpleBinOpParseFn(.Keyword_or, Node.InfixOp.Op.BoolOr),
            parseBoolAndExpr,
            .Infinitely,
        );
    }

    /// BoolAndExpr <- CompareExpr (KEYWORD_and CompareExpr)*
    fn parseBoolAndExpr(p: *Parser) !?*Node {
        return p.parseBinOpExpr(
            SimpleBinOpParseFn(.Keyword_and, .BoolAnd),
            parseCompareExpr,
            .Infinitely,
        );
    }

    /// CompareExpr <- BitwiseExpr (CompareOp BitwiseExpr)?
    fn parseCompareExpr(p: *Parser) !?*Node {
        return p.parseBinOpExpr(parseCompareOp, parseBitwiseExpr, .Once);
    }

    /// BitwiseExpr <- BitShiftExpr (BitwiseOp BitShiftExpr)*
    fn parseBitwiseExpr(p: *Parser) !?*Node {
        return p.parseBinOpExpr(parseBitwiseOp, parseBitShiftExpr, .Infinitely);
    }

    /// BitShiftExpr <- AdditionExpr (BitShiftOp AdditionExpr)*
    fn parseBitShiftExpr(p: *Parser) !?*Node {
        return p.parseBinOpExpr(parseBitShiftOp, parseAdditionExpr, .Infinitely);
    }

    /// AdditionExpr <- MultiplyExpr (AdditionOp MultiplyExpr)*
    fn parseAdditionExpr(p: *Parser) !?*Node {
        return p.parseBinOpExpr(parseAdditionOp, parseMultiplyExpr, .Infinitely);
    }

    /// MultiplyExpr <- PrefixExpr (MultiplyOp PrefixExpr)*
    fn parseMultiplyExpr(p: *Parser) !?*Node {
        return p.parseBinOpExpr(parseMultiplyOp, parsePrefixExpr, .Infinitely);
    }

    /// PrefixExpr <- PrefixOp* PrimaryExpr
    fn parsePrefixExpr(p: *Parser) !?*Node {
        return p.parsePrefixOpExpr(parsePrefixOp, parsePrimaryExpr);
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
    fn parsePrimaryExpr(p: *Parser) !?*Node {
        if (try p.parseAsmExpr()) |node| return node;
        if (try p.parseIfExpr()) |node| return node;

        if (p.eatToken(.Keyword_break)) |token| {
            const label = try p.parseBreakLabel();
            const expr_node = try p.parseExpr();
            const node = try p.arena.allocator.create(Node.ControlFlowExpression);
            node.* = .{
                .ltoken = token,
                .kind = .{ .Break = label },
                .rhs = expr_node,
            };
            return &node.base;
        }

        if (p.eatToken(.Keyword_comptime)) |token| {
            const expr_node = try p.expectNode(parseExpr, .{
                .ExpectedExpr = .{ .token = p.tok_i },
            });
            const node = try p.arena.allocator.create(Node.Comptime);
            node.* = .{
                .doc_comments = null,
                .comptime_token = token,
                .expr = expr_node,
            };
            return &node.base;
        }

        if (p.eatToken(.Keyword_nosuspend)) |token| {
            const expr_node = try p.expectNode(parseExpr, .{
                .ExpectedExpr = .{ .token = p.tok_i },
            });
            const node = try p.arena.allocator.create(Node.Nosuspend);
            node.* = .{
                .nosuspend_token = token,
                .expr = expr_node,
            };
            return &node.base;
        }

        if (p.eatToken(.Keyword_continue)) |token| {
            const label = try p.parseBreakLabel();
            const node = try p.arena.allocator.create(Node.ControlFlowExpression);
            node.* = .{
                .ltoken = token,
                .kind = .{ .Continue = label },
                .rhs = null,
            };
            return &node.base;
        }

        if (p.eatToken(.Keyword_resume)) |token| {
            const expr_node = try p.expectNode(parseExpr, .{
                .ExpectedExpr = .{ .token = p.tok_i },
            });
            const node = try p.arena.allocator.create(Node.PrefixOp);
            node.* = .{
                .op_token = token,
                .op = .Resume,
                .rhs = expr_node,
            };
            return &node.base;
        }

        if (p.eatToken(.Keyword_return)) |token| {
            const expr_node = try p.parseExpr();
            const node = try p.arena.allocator.create(Node.ControlFlowExpression);
            node.* = .{
                .ltoken = token,
                .kind = .Return,
                .rhs = expr_node,
            };
            return &node.base;
        }

        var colon: TokenIndex = undefined;
        const label = p.parseBlockLabel(&colon);
        if (try p.parseLoopExpr()) |node| {
            if (node.cast(Node.For)) |for_node| {
                for_node.label = label;
            } else if (node.cast(Node.While)) |while_node| {
                while_node.label = label;
            } else unreachable;
            return node;
        }
        if (label) |token| {
            p.putBackToken(token + 1); // ":"
            p.putBackToken(token); // IDENTIFIER
        }

        if (try p.parseBlock()) |node| return node;
        if (try p.parseCurlySuffixExpr()) |node| return node;

        return null;
    }

    /// IfExpr <- IfPrefix Expr (KEYWORD_else Payload? Expr)?
    fn parseIfExpr(p: *Parser) !?*Node {
        return p.parseIf(parseExpr);
    }

    /// Block <- LBRACE Statement* RBRACE
    fn parseBlock(p: *Parser) !?*Node {
        const lbrace = p.eatToken(.LBrace) orelse return null;

        var statements = Node.Block.StatementList{};
        var statements_it = &statements.first;
        while (true) {
            const statement = (p.parseStatement() catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.ParseError => {
                    // try to skip to the next statement
                    p.findNextStmt();
                    continue;
                },
            }) orelse break;
            statements_it = try p.llpush(*Node, statements_it, statement);
        }

        const rbrace = try p.expectToken(.RBrace);

        const block_node = try p.arena.allocator.create(Node.Block);
        block_node.* = .{
            .label = null,
            .lbrace = lbrace,
            .statements = statements,
            .rbrace = rbrace,
        };

        return &block_node.base;
    }

    /// LoopExpr <- KEYWORD_inline? (ForExpr / WhileExpr)
    fn parseLoopExpr(p: *Parser) !?*Node {
        const inline_token = p.eatToken(.Keyword_inline);

        if (try p.parseForExpr()) |node| {
            node.cast(Node.For).?.inline_token = inline_token;
            return node;
        }

        if (try p.parseWhileExpr()) |node| {
            node.cast(Node.While).?.inline_token = inline_token;
            return node;
        }

        if (inline_token == null) return null;

        // If we've seen "inline", there should have been a "for" or "while"
        try p.errors.append(p.gpa, .{
            .ExpectedInlinable = .{ .token = p.tok_i },
        });
        return error.ParseError;
    }

    /// ForExpr <- ForPrefix Expr (KEYWORD_else Expr)?
    fn parseForExpr(p: *Parser) !?*Node {
        const node = (try p.parseForPrefix()) orelse return null;
        const for_prefix = node.cast(Node.For).?;

        const body_node = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });
        for_prefix.body = body_node;

        if (p.eatToken(.Keyword_else)) |else_token| {
            const body = try p.expectNode(parseExpr, .{
                .ExpectedExpr = .{ .token = p.tok_i },
            });

            const else_node = try p.arena.allocator.create(Node.Else);
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
    fn parseWhileExpr(p: *Parser) !?*Node {
        const node = (try p.parseWhilePrefix()) orelse return null;
        const while_prefix = node.cast(Node.While).?;

        const body_node = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });
        while_prefix.body = body_node;

        if (p.eatToken(.Keyword_else)) |else_token| {
            const payload = try p.parsePayload();
            const body = try p.expectNode(parseExpr, .{
                .ExpectedExpr = .{ .token = p.tok_i },
            });

            const else_node = try p.arena.allocator.create(Node.Else);
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
    fn parseCurlySuffixExpr(p: *Parser) !?*Node {
        const lhs = (try p.parseTypeExpr()) orelse return null;
        const suffix_op = (try p.parseInitList(lhs)) orelse return lhs;
        return suffix_op;
    }

    /// InitList
    ///     <- LBRACE FieldInit (COMMA FieldInit)* COMMA? RBRACE
    ///      / LBRACE Expr (COMMA Expr)* COMMA? RBRACE
    ///      / LBRACE RBRACE
    fn parseInitList(p: *Parser, lhs: *Node) !?*Node {
        const lbrace = p.eatToken(.LBrace) orelse return null;
        var init_list = std.ArrayList(*Node).init(p.gpa);
        defer init_list.deinit();

        if (try p.parseFieldInit()) |field_init| {
            try init_list.append(field_init);
            while (p.eatToken(.Comma)) |_| {
                const next = (try p.parseFieldInit()) orelse break;
                try init_list.append(next);
            }

            const list = if (init_list.items.len > large_list_len) blk: {
                try p.owned_memory.ensureCapacity(p.gpa, p.owned_memory.items.len + 1);
                const list = init_list.toOwnedSlice();
                p.owned_memory.appendAssumeCapacity(std.mem.sliceAsBytes(list));
                break :blk list;
            } else try p.arena.allocator.dupe(*Node, init_list.items);

            const node = try p.arena.allocator.create(Node.StructInitializer);
            node.* = .{
                .lhs = lhs,
                .rtoken = try p.expectToken(.RBrace),
                .list = list,
            };
            return &node.base;
        }

        if (try p.parseExpr()) |expr| {
            try init_list.append(expr);
            while (p.eatToken(.Comma)) |_| {
                const next = (try p.parseExpr()) orelse break;
                try init_list.append(next);
            }

            const list = if (init_list.items.len > large_list_len) blk: {
                try p.owned_memory.ensureCapacity(p.gpa, p.owned_memory.items.len + 1);
                const list = init_list.toOwnedSlice();
                p.owned_memory.appendAssumeCapacity(std.mem.sliceAsBytes(list));
                break :blk list;
            } else try p.arena.allocator.dupe(*Node, init_list.items);

            const node = try p.arena.allocator.create(Node.ArrayInitializer);
            node.* = .{
                .lhs = lhs,
                .rtoken = try p.expectToken(.RBrace),
                .list = list,
            };
            return &node.base;
        }

        const node = try p.arena.allocator.create(Node.StructInitializer);
        node.* = .{
            .lhs = lhs,
            .rtoken = try p.expectToken(.RBrace),
            .list = &[0]*Node{},
        };
        return &node.base;
    }

    /// InitList
    ///     <- LBRACE FieldInit (COMMA FieldInit)* COMMA? RBRACE
    ///      / LBRACE Expr (COMMA Expr)* COMMA? RBRACE
    ///      / LBRACE RBRACE
    fn parseAnonInitList(p: *Parser, dot: TokenIndex) !?*Node {
        const lbrace = p.eatToken(.LBrace) orelse return null;
        var init_list = std.ArrayList(*Node).init(p.gpa);
        defer init_list.deinit();

        if (try p.parseFieldInit()) |field_init| {
            try init_list.append(field_init);
            while (p.eatToken(.Comma)) |_| {
                const next = (try p.parseFieldInit()) orelse break;
                try init_list.append(next);
            }

            const list = if (init_list.items.len > large_list_len) blk: {
                try p.owned_memory.ensureCapacity(p.gpa, p.owned_memory.items.len + 1);
                const list = init_list.toOwnedSlice();
                p.owned_memory.appendAssumeCapacity(std.mem.sliceAsBytes(list));
                break :blk list;
            } else try p.arena.allocator.dupe(*Node, init_list.items);

            const node = try p.arena.allocator.create(Node.StructInitializerDot);
            node.* = .{
                .dot = dot,
                .rtoken = try p.expectToken(.RBrace),
                .list = list,
            };
            return &node.base;
        }

        if (try p.parseExpr()) |expr| {
            try init_list.append(expr);
            while (p.eatToken(.Comma)) |_| {
                const next = (try p.parseExpr()) orelse break;
                try init_list.append(next);
            }

            const list = if (init_list.items.len > large_list_len) blk: {
                try p.owned_memory.ensureCapacity(p.gpa, p.owned_memory.items.len + 1);
                const list = init_list.toOwnedSlice();
                p.owned_memory.appendAssumeCapacity(std.mem.sliceAsBytes(list));
                break :blk list;
            } else try p.arena.allocator.dupe(*Node, init_list.items);

            const node = try p.arena.allocator.create(Node.ArrayInitializerDot);
            node.* = .{
                .dot = dot,
                .rtoken = try p.expectToken(.RBrace),
                .list = list,
            };
            return &node.base;
        }

        const node = try p.arena.allocator.create(Node.StructInitializerDot);
        node.* = .{
            .dot = dot,
            .rtoken = try p.expectToken(.RBrace),
            .list = &[0]*Node{},
        };
        return &node.base;
    }

    /// TypeExpr <- PrefixTypeOp* ErrorUnionExpr
    fn parseTypeExpr(p: *Parser) Error!?*Node {
        return p.parsePrefixOpExpr(parsePrefixTypeOp, parseErrorUnionExpr);
    }

    /// ErrorUnionExpr <- SuffixExpr (EXCLAMATIONMARK TypeExpr)?
    fn parseErrorUnionExpr(p: *Parser) !?*Node {
        const suffix_expr = (try p.parseSuffixExpr()) orelse return null;

        if (try SimpleBinOpParseFn(.Bang, Node.InfixOp.Op.ErrorUnion)(p)) |node| {
            const error_union = node.cast(Node.InfixOp).?;
            const type_expr = try p.expectNode(parseTypeExpr, .{
                .ExpectedTypeExpr = .{ .token = p.tok_i },
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
    fn parseSuffixExpr(p: *Parser) !?*Node {
        const maybe_async = p.eatToken(.Keyword_async);
        if (maybe_async) |async_token| {
            const token_fn = p.eatToken(.Keyword_fn);
            if (token_fn != null) {
                // TODO: remove this hack when async fn rewriting is
                // HACK: If we see the keyword `fn`, then we assume that
                //       we are parsing an async fn proto, and not a call.
                //       We therefore put back all tokens consumed by the async
                //       prefix...
                p.putBackToken(token_fn.?);
                p.putBackToken(async_token);
                return p.parsePrimaryTypeExpr();
            }
            var res = try p.expectNode(parsePrimaryTypeExpr, .{
                .ExpectedPrimaryTypeExpr = .{ .token = p.tok_i },
            });

            while (try p.parseSuffixOp()) |node| {
                switch (node.id) {
                    .SuffixOp => node.cast(Node.SuffixOp).?.lhs = res,
                    .InfixOp => node.cast(Node.InfixOp).?.lhs = res,
                    else => unreachable,
                }
                res = node;
            }

            const params = (try p.parseFnCallArguments()) orelse {
                try p.errors.append(p.gpa, .{
                    .ExpectedParamList = .{ .token = p.tok_i },
                });
                // ignore this, continue parsing
                return res;
            };
            const node = try p.arena.allocator.create(Node.SuffixOp);
            node.* = .{
                .lhs = res,
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
        if (try p.parsePrimaryTypeExpr()) |expr| {
            var res = expr;

            while (true) {
                if (try p.parseSuffixOp()) |node| {
                    switch (node.id) {
                        .SuffixOp => node.cast(Node.SuffixOp).?.lhs = res,
                        .InfixOp => node.cast(Node.InfixOp).?.lhs = res,
                        else => unreachable,
                    }
                    res = node;
                    continue;
                }
                if (try p.parseFnCallArguments()) |params| {
                    const call = try p.arena.allocator.create(Node.SuffixOp);
                    call.* = .{
                        .lhs = res,
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
    fn parsePrimaryTypeExpr(p: *Parser) !?*Node {
        if (try p.parseBuiltinCall()) |node| return node;
        if (p.eatToken(.CharLiteral)) |token| {
            const node = try p.arena.allocator.create(Node.CharLiteral);
            node.* = .{
                .token = token,
            };
            return &node.base;
        }
        if (try p.parseContainerDecl()) |node| return node;
        if (try p.parseAnonLiteral()) |node| return node;
        if (try p.parseErrorSetDecl()) |node| return node;
        if (try p.parseFloatLiteral()) |node| return node;
        if (try p.parseFnProto()) |node| return node;
        if (try p.parseGroupedExpr()) |node| return node;
        if (try p.parseLabeledTypeExpr()) |node| return node;
        if (try p.parseIdentifier()) |node| return node;
        if (try p.parseIfTypeExpr()) |node| return node;
        if (try p.parseIntegerLiteral()) |node| return node;
        if (p.eatToken(.Keyword_comptime)) |token| {
            const expr = (try p.parseTypeExpr()) orelse return null;
            const node = try p.arena.allocator.create(Node.Comptime);
            node.* = .{
                .doc_comments = null,
                .comptime_token = token,
                .expr = expr,
            };
            return &node.base;
        }
        if (p.eatToken(.Keyword_error)) |token| {
            const period = try p.expectTokenRecoverable(.Period);
            const identifier = try p.expectNodeRecoverable(parseIdentifier, .{
                .ExpectedIdentifier = .{ .token = p.tok_i },
            });
            const global_error_set = try p.createLiteral(Node.ErrorType, token);
            if (period == null or identifier == null) return global_error_set;

            const node = try p.arena.allocator.create(Node.InfixOp);
            node.* = .{
                .op_token = period.?,
                .lhs = global_error_set,
                .op = .Period,
                .rhs = identifier.?,
            };
            return &node.base;
        }
        if (p.eatToken(.Keyword_false)) |token| return p.createLiteral(Node.BoolLiteral, token);
        if (p.eatToken(.Keyword_null)) |token| return p.createLiteral(Node.NullLiteral, token);
        if (p.eatToken(.Keyword_anyframe)) |token| {
            const node = try p.arena.allocator.create(Node.AnyFrameType);
            node.* = .{
                .anyframe_token = token,
                .result = null,
            };
            return &node.base;
        }
        if (p.eatToken(.Keyword_true)) |token| return p.createLiteral(Node.BoolLiteral, token);
        if (p.eatToken(.Keyword_undefined)) |token| return p.createLiteral(Node.UndefinedLiteral, token);
        if (p.eatToken(.Keyword_unreachable)) |token| return p.createLiteral(Node.Unreachable, token);
        if (try p.parseStringLiteral()) |node| return node;
        if (try p.parseSwitchExpr()) |node| return node;

        return null;
    }

    /// ContainerDecl <- (KEYWORD_extern / KEYWORD_packed)? ContainerDeclAuto
    fn parseContainerDecl(p: *Parser) !?*Node {
        const layout_token = p.eatToken(.Keyword_extern) orelse
            p.eatToken(.Keyword_packed);

        const node = (try p.parseContainerDeclAuto()) orelse {
            if (layout_token) |token|
                p.putBackToken(token);
            return null;
        };
        node.cast(Node.ContainerDecl).?.*.layout_token = layout_token;
        return node;
    }

    /// ErrorSetDecl <- KEYWORD_error LBRACE IdentifierList RBRACE
    fn parseErrorSetDecl(p: *Parser) !?*Node {
        const error_token = p.eatToken(.Keyword_error) orelse return null;
        if (p.eatToken(.LBrace) == null) {
            // Might parse as `KEYWORD_error DOT IDENTIFIER` later in PrimaryTypeExpr, so don't error
            p.putBackToken(error_token);
            return null;
        }
        const decls = try p.parseErrorTagList();
        const rbrace = try p.expectToken(.RBrace);

        const node = try p.arena.allocator.create(Node.ErrorSetDecl);
        node.* = .{
            .error_token = error_token,
            .decls = decls,
            .rbrace_token = rbrace,
        };
        return &node.base;
    }

    /// GroupedExpr <- LPAREN Expr RPAREN
    fn parseGroupedExpr(p: *Parser) !?*Node {
        const lparen = p.eatToken(.LParen) orelse return null;
        const expr = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });
        const rparen = try p.expectToken(.RParen);

        const node = try p.arena.allocator.create(Node.GroupedExpression);
        node.* = .{
            .lparen = lparen,
            .expr = expr,
            .rparen = rparen,
        };
        return &node.base;
    }

    /// IfTypeExpr <- IfPrefix TypeExpr (KEYWORD_else Payload? TypeExpr)?
    fn parseIfTypeExpr(p: *Parser) !?*Node {
        return p.parseIf(parseTypeExpr);
    }

    /// LabeledTypeExpr
    ///     <- BlockLabel Block
    ///      / BlockLabel? LoopTypeExpr
    fn parseLabeledTypeExpr(p: *Parser) !?*Node {
        var colon: TokenIndex = undefined;
        const label = p.parseBlockLabel(&colon);

        if (label) |token| {
            if (try p.parseBlock()) |node| {
                node.cast(Node.Block).?.label = token;
                return node;
            }
        }

        if (try p.parseLoopTypeExpr()) |node| {
            switch (node.id) {
                .For => node.cast(Node.For).?.label = label,
                .While => node.cast(Node.While).?.label = label,
                else => unreachable,
            }
            return node;
        }

        if (label) |token| {
            p.putBackToken(colon);
            p.putBackToken(token);
        }
        return null;
    }

    /// LoopTypeExpr <- KEYWORD_inline? (ForTypeExpr / WhileTypeExpr)
    fn parseLoopTypeExpr(p: *Parser) !?*Node {
        const inline_token = p.eatToken(.Keyword_inline);

        if (try p.parseForTypeExpr()) |node| {
            node.cast(Node.For).?.inline_token = inline_token;
            return node;
        }

        if (try p.parseWhileTypeExpr()) |node| {
            node.cast(Node.While).?.inline_token = inline_token;
            return node;
        }

        if (inline_token == null) return null;

        // If we've seen "inline", there should have been a "for" or "while"
        try p.errors.append(p.gpa, .{
            .ExpectedInlinable = .{ .token = p.tok_i },
        });
        return error.ParseError;
    }

    /// ForTypeExpr <- ForPrefix TypeExpr (KEYWORD_else TypeExpr)?
    fn parseForTypeExpr(p: *Parser) !?*Node {
        const node = (try p.parseForPrefix()) orelse return null;
        const for_prefix = node.cast(Node.For).?;

        const type_expr = try p.expectNode(parseTypeExpr, .{
            .ExpectedTypeExpr = .{ .token = p.tok_i },
        });
        for_prefix.body = type_expr;

        if (p.eatToken(.Keyword_else)) |else_token| {
            const else_expr = try p.expectNode(parseTypeExpr, .{
                .ExpectedTypeExpr = .{ .token = p.tok_i },
            });

            const else_node = try p.arena.allocator.create(Node.Else);
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
    fn parseWhileTypeExpr(p: *Parser) !?*Node {
        const node = (try p.parseWhilePrefix()) orelse return null;
        const while_prefix = node.cast(Node.While).?;

        const type_expr = try p.expectNode(parseTypeExpr, .{
            .ExpectedTypeExpr = .{ .token = p.tok_i },
        });
        while_prefix.body = type_expr;

        if (p.eatToken(.Keyword_else)) |else_token| {
            const payload = try p.parsePayload();

            const else_expr = try p.expectNode(parseTypeExpr, .{
                .ExpectedTypeExpr = .{ .token = p.tok_i },
            });

            const else_node = try p.arena.allocator.create(Node.Else);
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
    fn parseSwitchExpr(p: *Parser) !?*Node {
        const switch_token = p.eatToken(.Keyword_switch) orelse return null;
        _ = try p.expectToken(.LParen);
        const expr_node = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });
        _ = try p.expectToken(.RParen);
        _ = try p.expectToken(.LBrace);
        const cases = try p.parseSwitchProngList();
        const rbrace = try p.expectToken(.RBrace);

        const node = try p.arena.allocator.create(Node.Switch);
        node.* = .{
            .switch_token = switch_token,
            .expr = expr_node,
            .cases = cases,
            .rbrace = rbrace,
        };
        return &node.base;
    }

    /// AsmExpr <- KEYWORD_asm KEYWORD_volatile? LPAREN Expr AsmOutput? RPAREN
    fn parseAsmExpr(p: *Parser) !?*Node {
        const asm_token = p.eatToken(.Keyword_asm) orelse return null;
        const volatile_token = p.eatToken(.Keyword_volatile);
        _ = try p.expectToken(.LParen);
        const template = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });

        const node = try p.arena.allocator.create(Node.Asm);
        node.* = .{
            .asm_token = asm_token,
            .volatile_token = volatile_token,
            .template = template,
            .outputs = Node.Asm.OutputList{},
            .inputs = Node.Asm.InputList{},
            .clobbers = Node.Asm.ClobberList{},
            .rparen = undefined,
        };

        try p.parseAsmOutput(node);
        node.rparen = try p.expectToken(.RParen);
        return &node.base;
    }

    /// DOT IDENTIFIER
    fn parseAnonLiteral(p: *Parser) !?*Node {
        const dot = p.eatToken(.Period) orelse return null;

        // anon enum literal
        if (p.eatToken(.Identifier)) |name| {
            const node = try p.arena.allocator.create(Node.EnumLiteral);
            node.* = .{
                .dot = dot,
                .name = name,
            };
            return &node.base;
        }

        if (try p.parseAnonInitList(dot)) |node| {
            return node;
        }

        p.putBackToken(dot);
        return null;
    }

    /// AsmOutput <- COLON AsmOutputList AsmInput?
    fn parseAsmOutput(p: *Parser, asm_node: *Node.Asm) !void {
        if (p.eatToken(.Colon) == null) return;
        asm_node.outputs = try p.parseAsmOutputList();
        try p.parseAsmInput(asm_node);
    }

    /// AsmOutputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN (MINUSRARROW TypeExpr / IDENTIFIER) RPAREN
    fn parseAsmOutputItem(p: *Parser) !?*Node.AsmOutput {
        const lbracket = p.eatToken(.LBracket) orelse return null;
        const name = try p.expectNode(parseIdentifier, .{
            .ExpectedIdentifier = .{ .token = p.tok_i },
        });
        _ = try p.expectToken(.RBracket);

        const constraint = try p.expectNode(parseStringLiteral, .{
            .ExpectedStringLiteral = .{ .token = p.tok_i },
        });

        _ = try p.expectToken(.LParen);
        const kind: Node.AsmOutput.Kind = blk: {
            if (p.eatToken(.Arrow) != null) {
                const return_ident = try p.expectNode(parseTypeExpr, .{
                    .ExpectedTypeExpr = .{ .token = p.tok_i },
                });
                break :blk .{ .Return = return_ident };
            }
            const variable = try p.expectNode(parseIdentifier, .{
                .ExpectedIdentifier = .{ .token = p.tok_i },
            });
            break :blk .{ .Variable = variable.cast(Node.Identifier).? };
        };
        const rparen = try p.expectToken(.RParen);

        const node = try p.arena.allocator.create(Node.AsmOutput);
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
    fn parseAsmInput(p: *Parser, asm_node: *Node.Asm) !void {
        if (p.eatToken(.Colon) == null) return;
        asm_node.inputs = try p.parseAsmInputList();
        try p.parseAsmClobbers(asm_node);
    }

    /// AsmInputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN Expr RPAREN
    fn parseAsmInputItem(p: *Parser) !?*Node.AsmInput {
        const lbracket = p.eatToken(.LBracket) orelse return null;
        const name = try p.expectNode(parseIdentifier, .{
            .ExpectedIdentifier = .{ .token = p.tok_i },
        });
        _ = try p.expectToken(.RBracket);

        const constraint = try p.expectNode(parseStringLiteral, .{
            .ExpectedStringLiteral = .{ .token = p.tok_i },
        });

        _ = try p.expectToken(.LParen);
        const expr = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });
        const rparen = try p.expectToken(.RParen);

        const node = try p.arena.allocator.create(Node.AsmInput);
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
    fn parseAsmClobbers(p: *Parser, asm_node: *Node.Asm) !void {
        if (p.eatToken(.Colon) == null) return;
        asm_node.clobbers = try ListParseFn(
            Node.Asm.ClobberList,
            parseStringLiteral,
        )(p);
    }

    /// BreakLabel <- COLON IDENTIFIER
    fn parseBreakLabel(p: *Parser) !?*Node {
        _ = p.eatToken(.Colon) orelse return null;
        return p.expectNode(parseIdentifier, .{
            .ExpectedIdentifier = .{ .token = p.tok_i },
        });
    }

    /// BlockLabel <- IDENTIFIER COLON
    fn parseBlockLabel(p: *Parser, colon_token: *TokenIndex) ?TokenIndex {
        const identifier = p.eatToken(.Identifier) orelse return null;
        if (p.eatToken(.Colon)) |colon| {
            colon_token.* = colon;
            return identifier;
        }
        p.putBackToken(identifier);
        return null;
    }

    /// FieldInit <- DOT IDENTIFIER EQUAL Expr
    fn parseFieldInit(p: *Parser) !?*Node {
        const period_token = p.eatToken(.Period) orelse return null;
        const name_token = p.eatToken(.Identifier) orelse {
            // Because of anon literals `.{` is also valid.
            p.putBackToken(period_token);
            return null;
        };
        const eq_token = p.eatToken(.Equal) orelse {
            // `.Name` may also be an enum literal, which is a later rule.
            p.putBackToken(name_token);
            p.putBackToken(period_token);
            return null;
        };
        const expr_node = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });

        const node = try p.arena.allocator.create(Node.FieldInitializer);
        node.* = .{
            .period_token = period_token,
            .name_token = name_token,
            .expr = expr_node,
        };
        return &node.base;
    }

    /// WhileContinueExpr <- COLON LPAREN AssignExpr RPAREN
    fn parseWhileContinueExpr(p: *Parser) !?*Node {
        _ = p.eatToken(.Colon) orelse return null;
        _ = try p.expectToken(.LParen);
        const node = try p.expectNode(parseAssignExpr, .{
            .ExpectedExprOrAssignment = .{ .token = p.tok_i },
        });
        _ = try p.expectToken(.RParen);
        return node;
    }

    /// LinkSection <- KEYWORD_linksection LPAREN Expr RPAREN
    fn parseLinkSection(p: *Parser) !?*Node {
        _ = p.eatToken(.Keyword_linksection) orelse return null;
        _ = try p.expectToken(.LParen);
        const expr_node = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });
        _ = try p.expectToken(.RParen);
        return expr_node;
    }

    /// CallConv <- KEYWORD_callconv LPAREN Expr RPAREN
    fn parseCallconv(p: *Parser) !?*Node {
        _ = p.eatToken(.Keyword_callconv) orelse return null;
        _ = try p.expectToken(.LParen);
        const expr_node = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });
        _ = try p.expectToken(.RParen);
        return expr_node;
    }

    /// ParamDecl <- (KEYWORD_noalias / KEYWORD_comptime)? (IDENTIFIER COLON)? ParamType
    fn parseParamDecl(p: *Parser, list: *std.ArrayList(Node.FnProto.ParamDecl)) !bool {
        const doc_comments = try p.parseDocComment();
        const noalias_token = p.eatToken(.Keyword_noalias);
        const comptime_token = if (noalias_token == null) p.eatToken(.Keyword_comptime) else null;
        const name_token = blk: {
            const identifier = p.eatToken(.Identifier) orelse break :blk null;
            if (p.eatToken(.Colon) != null) break :blk identifier;
            p.putBackToken(identifier); // ParamType may also be an identifier
            break :blk null;
        };
        const param_type = (try p.parseParamType()) orelse {
            // Only return cleanly if no keyword, identifier, or doc comment was found
            if (noalias_token == null and
                comptime_token == null and
                name_token == null and
                doc_comments == null) return false;
            try p.errors.append(p.gpa, .{
                .ExpectedParamType = .{ .token = p.tok_i },
            });
            return error.ParseError;
        };

        (try list.addOne()).* = .{
            .doc_comments = doc_comments,
            .comptime_token = comptime_token,
            .noalias_token = noalias_token,
            .name_token = name_token,
            .param_type = param_type,
        };
        return true;
    }

    /// ParamType
    ///     <- KEYWORD_var
    ///      / DOT3
    ///      / TypeExpr
    fn parseParamType(p: *Parser) !?Node.FnProto.ParamDecl.ParamType {
        // TODO cast from tuple to error union is broken
        const P = Node.FnProto.ParamDecl.ParamType;
        if (try p.parseVarType()) |node| return P{ .var_type = node };
        if (p.eatToken(.Ellipsis3)) |token| return P{ .var_args = token };
        if (try p.parseTypeExpr()) |node| return P{ .type_expr = node };
        return null;
    }

    /// IfPrefix <- KEYWORD_if LPAREN Expr RPAREN PtrPayload?
    fn parseIfPrefix(p: *Parser) !?*Node {
        const if_token = p.eatToken(.Keyword_if) orelse return null;
        _ = try p.expectToken(.LParen);
        const condition = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });
        _ = try p.expectToken(.RParen);
        const payload = try p.parsePtrPayload();

        const node = try p.arena.allocator.create(Node.If);
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
    fn parseWhilePrefix(p: *Parser) !?*Node {
        const while_token = p.eatToken(.Keyword_while) orelse return null;

        _ = try p.expectToken(.LParen);
        const condition = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });
        _ = try p.expectToken(.RParen);

        const payload = try p.parsePtrPayload();
        const continue_expr = try p.parseWhileContinueExpr();

        const node = try p.arena.allocator.create(Node.While);
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
    fn parseForPrefix(p: *Parser) !?*Node {
        const for_token = p.eatToken(.Keyword_for) orelse return null;

        _ = try p.expectToken(.LParen);
        const array_expr = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });
        _ = try p.expectToken(.RParen);

        const payload = try p.expectNode(parsePtrIndexPayload, .{
            .ExpectedPayload = .{ .token = p.tok_i },
        });

        const node = try p.arena.allocator.create(Node.For);
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
    fn parsePayload(p: *Parser) !?*Node {
        const lpipe = p.eatToken(.Pipe) orelse return null;
        const identifier = try p.expectNode(parseIdentifier, .{
            .ExpectedIdentifier = .{ .token = p.tok_i },
        });
        const rpipe = try p.expectToken(.Pipe);

        const node = try p.arena.allocator.create(Node.Payload);
        node.* = .{
            .lpipe = lpipe,
            .error_symbol = identifier,
            .rpipe = rpipe,
        };
        return &node.base;
    }

    /// PtrPayload <- PIPE ASTERISK? IDENTIFIER PIPE
    fn parsePtrPayload(p: *Parser) !?*Node {
        const lpipe = p.eatToken(.Pipe) orelse return null;
        const asterisk = p.eatToken(.Asterisk);
        const identifier = try p.expectNode(parseIdentifier, .{
            .ExpectedIdentifier = .{ .token = p.tok_i },
        });
        const rpipe = try p.expectToken(.Pipe);

        const node = try p.arena.allocator.create(Node.PointerPayload);
        node.* = .{
            .lpipe = lpipe,
            .ptr_token = asterisk,
            .value_symbol = identifier,
            .rpipe = rpipe,
        };
        return &node.base;
    }

    /// PtrIndexPayload <- PIPE ASTERISK? IDENTIFIER (COMMA IDENTIFIER)? PIPE
    fn parsePtrIndexPayload(p: *Parser) !?*Node {
        const lpipe = p.eatToken(.Pipe) orelse return null;
        const asterisk = p.eatToken(.Asterisk);
        const identifier = try p.expectNode(parseIdentifier, .{
            .ExpectedIdentifier = .{ .token = p.tok_i },
        });

        const index = if (p.eatToken(.Comma) == null)
            null
        else
            try p.expectNode(parseIdentifier, .{
                .ExpectedIdentifier = .{ .token = p.tok_i },
            });

        const rpipe = try p.expectToken(.Pipe);

        const node = try p.arena.allocator.create(Node.PointerIndexPayload);
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
    fn parseSwitchProng(p: *Parser) !?*Node {
        const node = (try p.parseSwitchCase()) orelse return null;
        const arrow = try p.expectToken(.EqualAngleBracketRight);
        const payload = try p.parsePtrPayload();
        const expr = try p.expectNode(parseAssignExpr, .{
            .ExpectedExprOrAssignment = .{ .token = p.tok_i },
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
    fn parseSwitchCase(p: *Parser) !?*Node {
        var list = Node.SwitchCase.ItemList{};
        var list_it = &list.first;

        if (try p.parseSwitchItem()) |first_item| {
            list_it = try p.llpush(*Node, list_it, first_item);
            while (p.eatToken(.Comma) != null) {
                const next_item = (try p.parseSwitchItem()) orelse break;
                list_it = try p.llpush(*Node, list_it, next_item);
            }
        } else if (p.eatToken(.Keyword_else)) |else_token| {
            const else_node = try p.arena.allocator.create(Node.SwitchElse);
            else_node.* = .{
                .token = else_token,
            };
            list_it = try p.llpush(*Node, list_it, &else_node.base);
        } else return null;

        const node = try p.arena.allocator.create(Node.SwitchCase);
        node.* = .{
            .items = list,
            .arrow_token = undefined, // set by caller
            .payload = null,
            .expr = undefined, // set by caller
        };
        return &node.base;
    }

    /// SwitchItem <- Expr (DOT3 Expr)?
    fn parseSwitchItem(p: *Parser) !?*Node {
        const expr = (try p.parseExpr()) orelse return null;
        if (p.eatToken(.Ellipsis3)) |token| {
            const range_end = try p.expectNode(parseExpr, .{
                .ExpectedExpr = .{ .token = p.tok_i },
            });

            const node = try p.arena.allocator.create(Node.InfixOp);
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
    fn parseAssignOp(p: *Parser) !?*Node {
        const token = p.nextToken();
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
                p.putBackToken(token.index);
                return null;
            },
        };

        const node = try p.arena.allocator.create(Node.InfixOp);
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
    fn parseCompareOp(p: *Parser) !?*Node {
        const token = p.nextToken();
        const op: Node.InfixOp.Op = switch (token.ptr.id) {
            .EqualEqual => .EqualEqual,
            .BangEqual => .BangEqual,
            .AngleBracketLeft => .LessThan,
            .AngleBracketRight => .GreaterThan,
            .AngleBracketLeftEqual => .LessOrEqual,
            .AngleBracketRightEqual => .GreaterOrEqual,
            else => {
                p.putBackToken(token.index);
                return null;
            },
        };

        return p.createInfixOp(token.index, op);
    }

    /// BitwiseOp
    ///     <- AMPERSAND
    ///      / CARET
    ///      / PIPE
    ///      / KEYWORD_orelse
    ///      / KEYWORD_catch Payload?
    fn parseBitwiseOp(p: *Parser) !?*Node {
        const token = p.nextToken();
        const op: Node.InfixOp.Op = switch (token.ptr.id) {
            .Ampersand => .BitAnd,
            .Caret => .BitXor,
            .Pipe => .BitOr,
            .Keyword_orelse => .UnwrapOptional,
            .Keyword_catch => .{ .Catch = try p.parsePayload() },
            else => {
                p.putBackToken(token.index);
                return null;
            },
        };

        return p.createInfixOp(token.index, op);
    }

    /// BitShiftOp
    ///     <- LARROW2
    ///      / RARROW2
    fn parseBitShiftOp(p: *Parser) !?*Node {
        const token = p.nextToken();
        const op: Node.InfixOp.Op = switch (token.ptr.id) {
            .AngleBracketAngleBracketLeft => .BitShiftLeft,
            .AngleBracketAngleBracketRight => .BitShiftRight,
            else => {
                p.putBackToken(token.index);
                return null;
            },
        };

        return p.createInfixOp(token.index, op);
    }

    /// AdditionOp
    ///     <- PLUS
    ///      / MINUS
    ///      / PLUS2
    ///      / PLUSPERCENT
    ///      / MINUSPERCENT
    fn parseAdditionOp(p: *Parser) !?*Node {
        const token = p.nextToken();
        const op: Node.InfixOp.Op = switch (token.ptr.id) {
            .Plus => .Add,
            .Minus => .Sub,
            .PlusPlus => .ArrayCat,
            .PlusPercent => .AddWrap,
            .MinusPercent => .SubWrap,
            else => {
                p.putBackToken(token.index);
                return null;
            },
        };

        return p.createInfixOp(token.index, op);
    }

    /// MultiplyOp
    ///     <- PIPE2
    ///      / ASTERISK
    ///      / SLASH
    ///      / PERCENT
    ///      / ASTERISK2
    ///      / ASTERISKPERCENT
    fn parseMultiplyOp(p: *Parser) !?*Node {
        const token = p.nextToken();
        const op: Node.InfixOp.Op = switch (token.ptr.id) {
            .PipePipe => .MergeErrorSets,
            .Asterisk => .Mul,
            .Slash => .Div,
            .Percent => .Mod,
            .AsteriskAsterisk => .ArrayMult,
            .AsteriskPercent => .MulWrap,
            else => {
                p.putBackToken(token.index);
                return null;
            },
        };

        return p.createInfixOp(token.index, op);
    }

    /// PrefixOp
    ///     <- EXCLAMATIONMARK
    ///      / MINUS
    ///      / TILDE
    ///      / MINUSPERCENT
    ///      / AMPERSAND
    ///      / KEYWORD_try
    ///      / KEYWORD_await
    fn parsePrefixOp(p: *Parser) !?*Node {
        const token = p.nextToken();
        const op: Node.PrefixOp.Op = switch (token.ptr.id) {
            .Bang => .BoolNot,
            .Minus => .Negation,
            .Tilde => .BitNot,
            .MinusPercent => .NegationWrap,
            .Ampersand => .AddressOf,
            .Keyword_try => .Try,
            .Keyword_await => .Await,
            else => {
                p.putBackToken(token.index);
                return null;
            },
        };

        const node = try p.arena.allocator.create(Node.PrefixOp);
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
    fn parsePrefixTypeOp(p: *Parser) !?*Node {
        if (p.eatToken(.QuestionMark)) |token| {
            const node = try p.arena.allocator.create(Node.PrefixOp);
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
        if (p.eatToken(.Keyword_anyframe)) |token| {
            const arrow = p.eatToken(.Arrow) orelse {
                p.putBackToken(token);
                return null;
            };
            const node = try p.arena.allocator.create(Node.AnyFrameType);
            node.* = .{
                .anyframe_token = token,
                .result = .{
                    .arrow_token = arrow,
                    .return_type = undefined, // set by caller
                },
            };
            return &node.base;
        }

        if (try p.parsePtrTypeStart()) |node| {
            // If the token encountered was **, there will be two nodes instead of one.
            // The attributes should be applied to the rightmost operator.
            const prefix_op = node.cast(Node.PrefixOp).?;
            var ptr_info = if (p.tokens[prefix_op.op_token].id == .AsteriskAsterisk)
                &prefix_op.rhs.cast(Node.PrefixOp).?.op.PtrType
            else
                &prefix_op.op.PtrType;

            while (true) {
                if (p.eatToken(.Keyword_align)) |align_token| {
                    const lparen = try p.expectToken(.LParen);
                    const expr_node = try p.expectNode(parseExpr, .{
                        .ExpectedExpr = .{ .token = p.tok_i },
                    });

                    // Optional bit range
                    const bit_range = if (p.eatToken(.Colon)) |_| bit_range_value: {
                        const range_start = try p.expectNode(parseIntegerLiteral, .{
                            .ExpectedIntegerLiteral = .{ .token = p.tok_i },
                        });
                        _ = try p.expectToken(.Colon);
                        const range_end = try p.expectNode(parseIntegerLiteral, .{
                            .ExpectedIntegerLiteral = .{ .token = p.tok_i },
                        });

                        break :bit_range_value Node.PrefixOp.PtrInfo.Align.BitRange{
                            .start = range_start,
                            .end = range_end,
                        };
                    } else null;
                    _ = try p.expectToken(.RParen);

                    if (ptr_info.align_info != null) {
                        try p.errors.append(p.gpa, .{
                            .ExtraAlignQualifier = .{ .token = p.tok_i - 1 },
                        });
                        continue;
                    }

                    ptr_info.align_info = Node.PrefixOp.PtrInfo.Align{
                        .node = expr_node,
                        .bit_range = bit_range,
                    };

                    continue;
                }
                if (p.eatToken(.Keyword_const)) |const_token| {
                    if (ptr_info.const_token != null) {
                        try p.errors.append(p.gpa, .{
                            .ExtraConstQualifier = .{ .token = p.tok_i - 1 },
                        });
                        continue;
                    }
                    ptr_info.const_token = const_token;
                    continue;
                }
                if (p.eatToken(.Keyword_volatile)) |volatile_token| {
                    if (ptr_info.volatile_token != null) {
                        try p.errors.append(p.gpa, .{
                            .ExtraVolatileQualifier = .{ .token = p.tok_i - 1 },
                        });
                        continue;
                    }
                    ptr_info.volatile_token = volatile_token;
                    continue;
                }
                if (p.eatToken(.Keyword_allowzero)) |allowzero_token| {
                    if (ptr_info.allowzero_token != null) {
                        try p.errors.append(p.gpa, .{
                            .ExtraAllowZeroQualifier = .{ .token = p.tok_i - 1 },
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

        if (try p.parseArrayTypeStart()) |node| {
            switch (node.cast(Node.PrefixOp).?.op) {
                .ArrayType => {},
                .SliceType => |*slice_type| {
                    // Collect pointer qualifiers in any order, but disallow duplicates
                    while (true) {
                        if (try p.parseByteAlign()) |align_expr| {
                            if (slice_type.align_info != null) {
                                try p.errors.append(p.gpa, .{
                                    .ExtraAlignQualifier = .{ .token = p.tok_i - 1 },
                                });
                                continue;
                            }
                            slice_type.align_info = Node.PrefixOp.PtrInfo.Align{
                                .node = align_expr,
                                .bit_range = null,
                            };
                            continue;
                        }
                        if (p.eatToken(.Keyword_const)) |const_token| {
                            if (slice_type.const_token != null) {
                                try p.errors.append(p.gpa, .{
                                    .ExtraConstQualifier = .{ .token = p.tok_i - 1 },
                                });
                                continue;
                            }
                            slice_type.const_token = const_token;
                            continue;
                        }
                        if (p.eatToken(.Keyword_volatile)) |volatile_token| {
                            if (slice_type.volatile_token != null) {
                                try p.errors.append(p.gpa, .{
                                    .ExtraVolatileQualifier = .{ .token = p.tok_i - 1 },
                                });
                                continue;
                            }
                            slice_type.volatile_token = volatile_token;
                            continue;
                        }
                        if (p.eatToken(.Keyword_allowzero)) |allowzero_token| {
                            if (slice_type.allowzero_token != null) {
                                try p.errors.append(p.gpa, .{
                                    .ExtraAllowZeroQualifier = .{ .token = p.tok_i - 1 },
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
    fn parseSuffixOp(p: *Parser) !?*Node {
        const OpAndToken = struct {
            op: Node.SuffixOp.Op,
            token: TokenIndex,
        };
        const op_and_token: OpAndToken = blk: {
            if (p.eatToken(.LBracket)) |_| {
                const index_expr = try p.expectNode(parseExpr, .{
                    .ExpectedExpr = .{ .token = p.tok_i },
                });

                if (p.eatToken(.Ellipsis2) != null) {
                    const end_expr = try p.parseExpr();
                    const sentinel: ?*Node = if (p.eatToken(.Colon) != null)
                        try p.parseExpr()
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
                        .token = try p.expectToken(.RBracket),
                    };
                }

                break :blk .{
                    .op = .{ .ArrayAccess = index_expr },
                    .token = try p.expectToken(.RBracket),
                };
            }

            if (p.eatToken(.PeriodAsterisk)) |period_asterisk| {
                break :blk .{ .op = .Deref, .token = period_asterisk };
            }

            if (p.eatToken(.Period)) |period| {
                if (try p.parseIdentifier()) |identifier| {
                    // TODO: It's a bit weird to return an InfixOp from the SuffixOp parser.
                    // Should there be an Node.SuffixOp.FieldAccess variant? Or should
                    // this grammar rule be altered?
                    const node = try p.arena.allocator.create(Node.InfixOp);
                    node.* = .{
                        .op_token = period,
                        .lhs = undefined, // set by caller
                        .op = .Period,
                        .rhs = identifier,
                    };
                    return &node.base;
                }
                if (p.eatToken(.QuestionMark)) |question_mark| {
                    break :blk .{ .op = .UnwrapOptional, .token = question_mark };
                }
                try p.errors.append(p.gpa, .{
                    .ExpectedSuffixOp = .{ .token = p.tok_i },
                });
                return null;
            }

            return null;
        };

        const node = try p.arena.allocator.create(Node.SuffixOp);
        node.* = .{
            .lhs = undefined, // set by caller
            .op = op_and_token.op,
            .rtoken = op_and_token.token,
        };
        return &node.base;
    }

    /// FnCallArguments <- LPAREN ExprList RPAREN
    /// ExprList <- (Expr COMMA)* Expr?
    fn parseFnCallArguments(p: *Parser) !?AnnotatedParamList {
        if (p.eatToken(.LParen) == null) return null;
        const list = try ListParseFn(std.SinglyLinkedList(*Node), parseExpr)(p);
        const rparen = try p.expectToken(.RParen);
        return AnnotatedParamList{ .list = list, .rparen = rparen };
    }

    const AnnotatedParamList = struct {
        list: std.SinglyLinkedList(*Node),
        rparen: TokenIndex,
    };

    /// ArrayTypeStart <- LBRACKET Expr? RBRACKET
    fn parseArrayTypeStart(p: *Parser) !?*Node {
        const lbracket = p.eatToken(.LBracket) orelse return null;
        const expr = try p.parseExpr();
        const sentinel = if (p.eatToken(.Colon)) |_|
            try p.expectNode(parseExpr, .{
                .ExpectedExpr = .{ .token = p.tok_i },
            })
        else
            null;
        const rbracket = try p.expectToken(.RBracket);

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

        const node = try p.arena.allocator.create(Node.PrefixOp);
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
    fn parsePtrTypeStart(p: *Parser) !?*Node {
        if (p.eatToken(.Asterisk)) |asterisk| {
            const sentinel = if (p.eatToken(.Colon)) |_|
                try p.expectNode(parseExpr, .{
                    .ExpectedExpr = .{ .token = p.tok_i },
                })
            else
                null;
            const node = try p.arena.allocator.create(Node.PrefixOp);
            node.* = .{
                .op_token = asterisk,
                .op = .{ .PtrType = .{ .sentinel = sentinel } },
                .rhs = undefined, // set by caller
            };
            return &node.base;
        }

        if (p.eatToken(.AsteriskAsterisk)) |double_asterisk| {
            const node = try p.arena.allocator.create(Node.PrefixOp);
            node.* = .{
                .op_token = double_asterisk,
                .op = .{ .PtrType = .{} },
                .rhs = undefined, // set by caller
            };

            // Special case for **, which is its own token
            const child = try p.arena.allocator.create(Node.PrefixOp);
            child.* = .{
                .op_token = double_asterisk,
                .op = .{ .PtrType = .{} },
                .rhs = undefined, // set by caller
            };
            node.rhs = &child.base;

            return &node.base;
        }
        if (p.eatToken(.LBracket)) |lbracket| {
            const asterisk = p.eatToken(.Asterisk) orelse {
                p.putBackToken(lbracket);
                return null;
            };
            if (p.eatToken(.Identifier)) |ident| {
                const token_slice = p.source[p.tokens[ident].start..p.tokens[ident].end];
                if (!std.mem.eql(u8, token_slice, "c")) {
                    p.putBackToken(ident);
                } else {
                    _ = try p.expectToken(.RBracket);
                    const node = try p.arena.allocator.create(Node.PrefixOp);
                    node.* = .{
                        .op_token = lbracket,
                        .op = .{ .PtrType = .{} },
                        .rhs = undefined, // set by caller
                    };
                    return &node.base;
                }
            }
            const sentinel = if (p.eatToken(.Colon)) |_|
                try p.expectNode(parseExpr, .{
                    .ExpectedExpr = .{ .token = p.tok_i },
                })
            else
                null;
            _ = try p.expectToken(.RBracket);
            const node = try p.arena.allocator.create(Node.PrefixOp);
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
    fn parseContainerDeclAuto(p: *Parser) !?*Node {
        const container_decl_type = (try p.parseContainerDeclType()) orelse return null;
        const lbrace = try p.expectToken(.LBrace);
        const members = try p.parseContainerMembers(false);
        defer p.gpa.free(members);
        const rbrace = try p.expectToken(.RBrace);

        const node = try Node.ContainerDecl.alloc(&p.arena.allocator, members.len);
        node.* = .{
            .layout_token = null,
            .kind_token = container_decl_type.kind_token,
            .init_arg_expr = container_decl_type.init_arg_expr,
            .fields_and_decls_len = members.len,
            .lbrace_token = lbrace,
            .rbrace_token = rbrace,
        };
        std.mem.copy(*Node, node.fieldsAndDecls(), members);
        return &node.base;
    }

    /// Holds temporary data until we are ready to construct the full ContainerDecl AST node.
    const ContainerDeclType = struct {
        kind_token: TokenIndex,
        init_arg_expr: Node.ContainerDecl.InitArg,
    };

    /// ContainerDeclType
    ///     <- KEYWORD_struct
    ///      / KEYWORD_enum (LPAREN Expr RPAREN)?
    ///      / KEYWORD_union (LPAREN (KEYWORD_enum (LPAREN Expr RPAREN)? / Expr) RPAREN)?
    fn parseContainerDeclType(p: *Parser) !?ContainerDeclType {
        const kind_token = p.nextToken();

        const init_arg_expr = switch (kind_token.ptr.id) {
            .Keyword_struct => Node.ContainerDecl.InitArg{ .None = {} },
            .Keyword_enum => blk: {
                if (p.eatToken(.LParen) != null) {
                    const expr = try p.expectNode(parseExpr, .{
                        .ExpectedExpr = .{ .token = p.tok_i },
                    });
                    _ = try p.expectToken(.RParen);
                    break :blk Node.ContainerDecl.InitArg{ .Type = expr };
                }
                break :blk Node.ContainerDecl.InitArg{ .None = {} };
            },
            .Keyword_union => blk: {
                if (p.eatToken(.LParen) != null) {
                    if (p.eatToken(.Keyword_enum) != null) {
                        if (p.eatToken(.LParen) != null) {
                            const expr = try p.expectNode(parseExpr, .{
                                .ExpectedExpr = .{ .token = p.tok_i },
                            });
                            _ = try p.expectToken(.RParen);
                            _ = try p.expectToken(.RParen);
                            break :blk Node.ContainerDecl.InitArg{ .Enum = expr };
                        }
                        _ = try p.expectToken(.RParen);
                        break :blk Node.ContainerDecl.InitArg{ .Enum = null };
                    }
                    const expr = try p.expectNode(parseExpr, .{
                        .ExpectedExpr = .{ .token = p.tok_i },
                    });
                    _ = try p.expectToken(.RParen);
                    break :blk Node.ContainerDecl.InitArg{ .Type = expr };
                }
                break :blk Node.ContainerDecl.InitArg{ .None = {} };
            },
            else => {
                p.putBackToken(kind_token.index);
                return null;
            },
        };

        return ContainerDeclType{
            .kind_token = kind_token.index,
            .init_arg_expr = init_arg_expr,
        };
    }

    /// ByteAlign <- KEYWORD_align LPAREN Expr RPAREN
    fn parseByteAlign(p: *Parser) !?*Node {
        _ = p.eatToken(.Keyword_align) orelse return null;
        _ = try p.expectToken(.LParen);
        const expr = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });
        _ = try p.expectToken(.RParen);
        return expr;
    }

    /// IdentifierList <- (IDENTIFIER COMMA)* IDENTIFIER?
    /// Only ErrorSetDecl parses an IdentifierList
    fn parseErrorTagList(p: *Parser) !Node.ErrorSetDecl.DeclList {
        return ListParseFn(Node.ErrorSetDecl.DeclList, parseErrorTag)(p);
    }

    /// SwitchProngList <- (SwitchProng COMMA)* SwitchProng?
    fn parseSwitchProngList(p: *Parser) !Node.Switch.CaseList {
        return ListParseFn(Node.Switch.CaseList, parseSwitchProng)(p);
    }

    /// AsmOutputList <- (AsmOutputItem COMMA)* AsmOutputItem?
    fn parseAsmOutputList(p: *Parser) Error!Node.Asm.OutputList {
        return ListParseFn(Node.Asm.OutputList, parseAsmOutputItem)(p);
    }

    /// AsmInputList <- (AsmInputItem COMMA)* AsmInputItem?
    fn parseAsmInputList(p: *Parser) Error!Node.Asm.InputList {
        return ListParseFn(Node.Asm.InputList, parseAsmInputItem)(p);
    }

    /// ParamDeclList <- (ParamDecl COMMA)* ParamDecl?
    fn parseParamDeclList(p: *Parser, var_args_token: *?TokenIndex) ![]Node.FnProto.ParamDecl {
        var list = std.ArrayList(Node.FnProto.ParamDecl).init(p.gpa);
        defer list.deinit();

        while (try p.parseParamDecl(&list)) {
            switch (p.tokens[p.tok_i].id) {
                .Comma => _ = p.nextToken(),
                // all possible delimiters
                .Colon, .RParen, .RBrace, .RBracket => break,
                else => {
                    // this is likely just a missing comma,
                    // continue parsing this list and give an error
                    try p.errors.append(p.gpa, .{
                        .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                    });
                },
            }
        }
        if (list.items.len != 0) {
            const param_type = list.items[list.items.len - 1].param_type;
            if (param_type == .var_args) {
                var_args_token.* = param_type.var_args;
            }
        }
        return list.toOwnedSlice();
    }

    const NodeParseFn = fn (p: *Parser) Error!?*Node;

    fn ListParseFn(comptime L: type, comptime nodeParseFn: var) ParseFn(L) {
        return struct {
            pub fn parse(p: *Parser) !L {
                var list = L{};
                var list_it = &list.first;
                while (try nodeParseFn(p)) |node| {
                    list_it = try p.llpush(L.Node.Data, list_it, node);

                    switch (p.tokens[p.tok_i].id) {
                        .Comma => _ = p.nextToken(),
                        // all possible delimiters
                        .Colon, .RParen, .RBrace, .RBracket => break,
                        else => {
                            // this is likely just a missing comma,
                            // continue parsing this list and give an error
                            try p.errors.append(p.gpa, .{
                                .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
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
            pub fn parse(p: *Parser) Error!?*Node {
                const op_token = if (token == .Keyword_and) switch (p.tokens[p.tok_i].id) {
                    .Keyword_and => p.nextToken().index,
                    .Invalid_ampersands => blk: {
                        try p.errors.append(p.gpa, .{
                            .InvalidAnd = .{ .token = p.tok_i },
                        });
                        break :blk p.nextToken().index;
                    },
                    else => return null,
                } else p.eatToken(token) orelse return null;

                const node = try p.arena.allocator.create(Node.InfixOp);
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

    fn parseBuiltinCall(p: *Parser) !?*Node {
        const token = p.eatToken(.Builtin) orelse return null;
        const params = (try p.parseFnCallArguments()) orelse {
            try p.errors.append(p.gpa, .{
                .ExpectedParamList = .{ .token = p.tok_i },
            });

            // lets pretend this was an identifier so we can continue parsing
            const node = try p.arena.allocator.create(Node.Identifier);
            node.* = .{
                .token = token,
            };
            return &node.base;
        };
        const node = try p.arena.allocator.create(Node.BuiltinCall);
        node.* = .{
            .builtin_token = token,
            .params = params.list,
            .rparen_token = params.rparen,
        };
        return &node.base;
    }

    fn parseErrorTag(p: *Parser) !?*Node {
        const doc_comments = try p.parseDocComment(); // no need to rewind on failure
        const token = p.eatToken(.Identifier) orelse return null;

        const node = try p.arena.allocator.create(Node.ErrorTag);
        node.* = .{
            .doc_comments = doc_comments,
            .name_token = token,
        };
        return &node.base;
    }

    fn parseIdentifier(p: *Parser) !?*Node {
        const token = p.eatToken(.Identifier) orelse return null;
        const node = try p.arena.allocator.create(Node.Identifier);
        node.* = .{
            .token = token,
        };
        return &node.base;
    }

    fn parseVarType(p: *Parser) !?*Node {
        const token = p.eatToken(.Keyword_var) orelse return null;
        const node = try p.arena.allocator.create(Node.VarType);
        node.* = .{
            .token = token,
        };
        return &node.base;
    }

    fn createLiteral(p: *Parser, comptime T: type, token: TokenIndex) !*Node {
        const result = try p.arena.allocator.create(T);
        result.* = T{
            .base = Node{ .id = Node.typeToId(T) },
            .token = token,
        };
        return &result.base;
    }

    fn parseStringLiteralSingle(p: *Parser) !?*Node {
        if (p.eatToken(.StringLiteral)) |token| {
            const node = try p.arena.allocator.create(Node.StringLiteral);
            node.* = .{
                .token = token,
            };
            return &node.base;
        }
        return null;
    }

    // string literal or multiline string literal
    fn parseStringLiteral(p: *Parser) !?*Node {
        if (try p.parseStringLiteralSingle()) |node| return node;

        if (p.eatToken(.MultilineStringLiteralLine)) |first_line| {
            const node = try p.arena.allocator.create(Node.MultilineStringLiteral);
            node.* = .{
                .lines = Node.MultilineStringLiteral.LineList{},
            };
            var lines_it = &node.lines.first;
            lines_it = try p.llpush(TokenIndex, lines_it, first_line);
            while (p.eatToken(.MultilineStringLiteralLine)) |line|
                lines_it = try p.llpush(TokenIndex, lines_it, line);

            return &node.base;
        }

        return null;
    }

    fn parseIntegerLiteral(p: *Parser) !?*Node {
        const token = p.eatToken(.IntegerLiteral) orelse return null;
        const node = try p.arena.allocator.create(Node.IntegerLiteral);
        node.* = .{
            .token = token,
        };
        return &node.base;
    }

    fn parseFloatLiteral(p: *Parser) !?*Node {
        const token = p.eatToken(.FloatLiteral) orelse return null;
        const node = try p.arena.allocator.create(Node.FloatLiteral);
        node.* = .{
            .token = token,
        };
        return &node.base;
    }

    fn parseTry(p: *Parser) !?*Node {
        const token = p.eatToken(.Keyword_try) orelse return null;
        const node = try p.arena.allocator.create(Node.PrefixOp);
        node.* = .{
            .op_token = token,
            .op = .Try,
            .rhs = undefined, // set by caller
        };
        return &node.base;
    }

    fn parseUse(p: *Parser) !?*Node {
        const token = p.eatToken(.Keyword_usingnamespace) orelse return null;
        const node = try p.arena.allocator.create(Node.Use);
        node.* = .{
            .doc_comments = null,
            .visib_token = null,
            .use_token = token,
            .expr = try p.expectNode(parseExpr, .{
                .ExpectedExpr = .{ .token = p.tok_i },
            }),
            .semicolon_token = try p.expectToken(.Semicolon),
        };
        return &node.base;
    }

    /// IfPrefix Body (KEYWORD_else Payload? Body)?
    fn parseIf(p: *Parser, bodyParseFn: NodeParseFn) !?*Node {
        const node = (try p.parseIfPrefix()) orelse return null;
        const if_prefix = node.cast(Node.If).?;

        if_prefix.body = try p.expectNode(bodyParseFn, .{
            .InvalidToken = .{ .token = p.tok_i },
        });

        const else_token = p.eatToken(.Keyword_else) orelse return node;
        const payload = try p.parsePayload();
        const else_expr = try p.expectNode(bodyParseFn, .{
            .InvalidToken = .{ .token = p.tok_i },
        });
        const else_node = try p.arena.allocator.create(Node.Else);
        else_node.* = .{
            .else_token = else_token,
            .payload = payload,
            .body = else_expr,
        };
        if_prefix.@"else" = else_node;

        return node;
    }

    /// Eat a multiline doc comment
    fn parseDocComment(p: *Parser) !?*Node.DocComment {
        var lines = Node.DocComment.LineList{};
        var lines_it = &lines.first;

        while (p.eatToken(.DocComment)) |line| {
            lines_it = try p.llpush(TokenIndex, lines_it, line);
        }

        if (lines.first == null) return null;

        const node = try p.arena.allocator.create(Node.DocComment);
        node.* = .{
            .lines = lines,
        };
        return node;
    }

    fn tokensOnSameLine(p: *Parser, token1: TokenIndex, token2: TokenIndex) bool {
        return std.mem.indexOfScalar(u8, p.source[p.tokens[token1].end..p.tokens[token2].start], '\n') == null;
    }

    /// Eat a single-line doc comment on the same line as another node
    fn parseAppendedDocComment(p: *Parser, after_token: TokenIndex) !?*Node.DocComment {
        const comment_token = p.eatToken(.DocComment) orelse return null;
        if (p.tokensOnSameLine(after_token, comment_token)) {
            var lines = Node.DocComment.LineList{};
            _ = try p.llpush(TokenIndex, &lines.first, comment_token);

            const node = try p.arena.allocator.create(Node.DocComment);
            node.* = .{ .lines = lines };
            return node;
        }
        p.putBackToken(comment_token);
        return null;
    }

    /// Op* Child
    fn parsePrefixOpExpr(p: *Parser, opParseFn: NodeParseFn, childParseFn: NodeParseFn) Error!?*Node {
        if (try opParseFn(p)) |first_op| {
            var rightmost_op = first_op;
            while (true) {
                switch (rightmost_op.id) {
                    .PrefixOp => {
                        var prefix_op = rightmost_op.cast(Node.PrefixOp).?;
                        // If the token encountered was **, there will be two nodes
                        if (p.tokens[prefix_op.op_token].id == .AsteriskAsterisk) {
                            rightmost_op = prefix_op.rhs;
                            prefix_op = rightmost_op.cast(Node.PrefixOp).?;
                        }
                        if (try opParseFn(p)) |rhs| {
                            prefix_op.rhs = rhs;
                            rightmost_op = rhs;
                        } else break;
                    },
                    .AnyFrameType => {
                        const prom = rightmost_op.cast(Node.AnyFrameType).?;
                        if (try opParseFn(p)) |rhs| {
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
                    prefix_op.rhs = try p.expectNode(childParseFn, .{
                        .InvalidToken = .{ .token = p.tok_i },
                    });
                },
                .AnyFrameType => {
                    const prom = rightmost_op.cast(Node.AnyFrameType).?;
                    prom.result.?.return_type = try p.expectNode(childParseFn, .{
                        .InvalidToken = .{ .token = p.tok_i },
                    });
                },
                else => unreachable,
            }

            return first_op;
        }

        // Otherwise, the child node is optional
        return childParseFn(p);
    }

    /// Child (Op Child)*
    /// Child (Op Child)?
    fn parseBinOpExpr(
        p: *Parser,
        opParseFn: NodeParseFn,
        childParseFn: NodeParseFn,
        chain: enum {
            Once,
            Infinitely,
        },
    ) Error!?*Node {
        var res = (try childParseFn(p)) orelse return null;

        while (try opParseFn(p)) |node| {
            const right = try p.expectNode(childParseFn, .{
                .InvalidToken = .{ .token = p.tok_i },
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

    fn createInfixOp(p: *Parser, index: TokenIndex, op: Node.InfixOp.Op) !*Node {
        const node = try p.arena.allocator.create(Node.InfixOp);
        node.* = .{
            .op_token = index,
            .lhs = undefined, // set by caller
            .op = op,
            .rhs = undefined, // set by caller
        };
        return &node.base;
    }

    fn eatToken(p: *Parser, id: Token.Id) ?TokenIndex {
        return if (p.eatAnnotatedToken(id)) |token| token.index else null;
    }

    fn eatAnnotatedToken(p: *Parser, id: Token.Id) ?AnnotatedToken {
        return if (p.tokens[p.tok_i].id == id) p.nextToken() else null;
    }

    fn expectToken(p: *Parser, id: Token.Id) Error!TokenIndex {
        return (try p.expectTokenRecoverable(id)) orelse error.ParseError;
    }

    fn expectTokenRecoverable(p: *Parser, id: Token.Id) !?TokenIndex {
        const token = p.nextToken();
        if (token.ptr.id != id) {
            try p.errors.append(p.gpa, .{
                .ExpectedToken = .{ .token = token.index, .expected_id = id },
            });
            // go back so that we can recover properly
            p.putBackToken(token.index);
            return null;
        }
        return token.index;
    }

    fn nextToken(p: *Parser) AnnotatedToken {
        const result = AnnotatedToken{
            .index = p.tok_i,
            .ptr = &p.tokens[p.tok_i],
        };
        p.tok_i += 1;
        assert(result.ptr.id != .LineComment);
        if (p.tok_i >= p.tokens.len) return result;

        while (true) {
            const next_tok = p.tokens[p.tok_i];
            if (next_tok.id != .LineComment) return result;
            p.tok_i += 1;
        }
    }

    fn putBackToken(p: *Parser, putting_back: TokenIndex) void {
        while (p.tok_i > 0) {
            p.tok_i -= 1;
            const prev_tok = p.tokens[p.tok_i];
            if (prev_tok.id == .LineComment) continue;
            assert(putting_back == p.tok_i);
            return;
        }
    }

    const AnnotatedToken = struct {
        index: TokenIndex,
        ptr: *const Token,
    };

    fn expectNode(
        p: *Parser,
        parseFn: NodeParseFn,
        /// if parsing fails
        err: AstError,
    ) Error!*Node {
        return (try p.expectNodeRecoverable(parseFn, err)) orelse return error.ParseError;
    }

    fn expectNodeRecoverable(
        p: *Parser,
        parseFn: NodeParseFn,
        /// if parsing fails
        err: AstError,
    ) !?*Node {
        return (try parseFn(p)) orelse {
            try p.errors.append(p.gpa, err);
            return null;
        };
    }
};

fn ParseFn(comptime T: type) type {
    return fn (p: *Parser) Error!T;
}


test "std.zig.parser" {
    _ = @import("parser_test.zig");
}
