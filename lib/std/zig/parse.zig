// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ast = std.zig.ast;
const Node = ast.Node;
const Tree = ast.Tree;
const AstError = ast.Error;
const TokenIndex = ast.TokenIndex;
const NodeIndex = ast.NodeIndex;
const Token = std.zig.Token;

pub const Error = error{ParseError} || Allocator.Error;

/// Result should be freed with tree.deinit() when there are
/// no more references to any of the tokens or nodes.
pub fn parse(gpa: *Allocator, source: []const u8) Allocator.Error!*Tree {
    var token_ids = std.ArrayList(Token.Id).init(gpa);
    defer token_ids.deinit();
    var token_locs = std.ArrayList(Token.Loc).init(gpa);
    defer token_locs.deinit();

    // Empirically, the zig std lib has an 8:1 ratio of source bytes to token count.
    const estimated_token_count = source.len / 8;
    try token_ids.ensureCapacity(estimated_token_count);
    try token_locs.ensureCapacity(estimated_token_count);

    var tokenizer = std.zig.Tokenizer.init(source);
    while (true) {
        const token = tokenizer.next();
        try token_ids.append(token.id);
        try token_locs.append(token.loc);
        if (token.id == .Eof) break;
    }

    var parser: Parser = .{
        .source = source,
        .arena = std.heap.ArenaAllocator.init(gpa),
        .gpa = gpa,
        .token_ids = token_ids.items,
        .token_locs = token_locs.items,
        .errors = .{},
        .tok_i = 0,
    };
    defer parser.errors.deinit(gpa);
    errdefer parser.arena.deinit();

    while (token_ids.items[parser.tok_i] == .LineComment) parser.tok_i += 1;

    const root_node = try parser.parseRoot();

    const tree = try parser.arena.allocator.create(Tree);
    tree.* = .{
        .gpa = gpa,
        .source = source,
        .token_ids = token_ids.toOwnedSlice(),
        .token_locs = token_locs.toOwnedSlice(),
        .errors = parser.errors.toOwnedSlice(gpa),
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
    token_ids: []const Token.Id,
    token_locs: []const Token.Loc,
    tok_i: TokenIndex,
    errors: std.ArrayListUnmanaged(AstError),

    /// Root <- skip ContainerMembers eof
    fn parseRoot(p: *Parser) Allocator.Error!*Node.Root {
        const decls = try parseContainerMembers(p, true);
        defer p.gpa.free(decls);

        // parseContainerMembers will try to skip as much
        // invalid tokens as it can so this can only be the EOF
        const eof_token = p.eatToken(.Eof).?;

        const decls_len = @intCast(NodeIndex, decls.len);
        const node = try Node.Root.create(&p.arena.allocator, decls_len, eof_token);
        std.mem.copy(*Node, node.decls(), decls);

        return node;
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

            if (p.parseTopLevelDecl(doc_comments, visib_token) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.ParseError => {
                    p.findNextContainerMember();
                    continue;
                },
            }) |node| {
                if (field_state == .seen) {
                    field_state = .{ .end = visib_token orelse node.firstToken() };
                }
                try list.append(node);
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
                    const next = p.token_ids[p.tok_i];
                    switch (next) {
                        .Eof => {
                            // no invalid tokens were found
                            if (index == p.tok_i) break;

                            // Invalid tokens, add error and exit
                            try p.errors.append(p.gpa, .{
                                .ExpectedToken = .{ .token = index, .expected_id = .Comma },
                            });
                            break;
                        },
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

            const next = p.token_ids[p.tok_i];
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
            switch (p.token_ids[tok]) {
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
                        p.putBackToken(tok);
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
                        p.putBackToken(tok);
                        return;
                    }
                    level -= 1;
                },
                .Eof => {
                    p.putBackToken(tok);
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
            switch (p.token_ids[tok]) {
                .LBrace => level += 1,
                .RBrace => {
                    if (level == 0) {
                        p.putBackToken(tok);
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
                    p.putBackToken(tok);
                    return;
                },
                else => {},
            }
        }
    }

    /// Eat a multiline container doc comment
    fn parseContainerDocComments(p: *Parser) !?*Node {
        if (p.eatToken(.ContainerDocComment)) |first_line| {
            while (p.eatToken(.ContainerDocComment)) |_| {}
            const node = try p.arena.allocator.create(Node.DocComment);
            node.* = .{ .first_line = first_line };
            return &node.base;
        }
        return null;
    }

    /// TestDecl <- KEYWORD_test STRINGLITERALSINGLE Block
    fn parseTestDecl(p: *Parser) !?*Node {
        const test_token = p.eatToken(.Keyword_test) orelse return null;
        const name_node = try p.expectNode(parseStringLiteralSingle, .{
            .ExpectedStringLiteral = .{ .token = p.tok_i },
        });
        const block_node = (try p.parseBlock(null)) orelse {
            try p.errors.append(p.gpa, .{ .ExpectedLBrace = .{ .token = p.tok_i } });
            return error.ParseError;
        };

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
    fn parseTopLevelDecl(p: *Parser, doc_comments: ?*Node.DocComment, visib_token: ?TokenIndex) !?*Node {
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

        if (try p.parseFnProto(.top_level, .{
            .doc_comments = doc_comments,
            .visib_token = visib_token,
            .extern_export_inline_token = extern_export_inline_token,
            .lib_name = lib_name,
        })) |node| {
            return node;
        }

        if (extern_export_inline_token) |token| {
            if (p.token_ids[token] == .Keyword_inline or
                p.token_ids[token] == .Keyword_noinline)
            {
                try p.errors.append(p.gpa, .{
                    .ExpectedFn = .{ .token = p.tok_i },
                });
                return error.ParseError;
            }
        }

        const thread_local_token = p.eatToken(.Keyword_threadlocal);

        if (try p.parseVarDecl(.{
            .doc_comments = doc_comments,
            .visib_token = visib_token,
            .thread_local_token = thread_local_token,
            .extern_export_token = extern_export_inline_token,
            .lib_name = lib_name,
        })) |node| {
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

        const use_token = p.eatToken(.Keyword_usingnamespace) orelse return null;
        const expr = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });
        const semicolon_token = try p.expectToken(.Semicolon);

        const node = try p.arena.allocator.create(Node.Use);
        node.* = .{
            .doc_comments = doc_comments orelse try p.parseAppendedDocComment(semicolon_token),
            .visib_token = visib_token,
            .use_token = use_token,
            .expr = expr,
            .semicolon_token = semicolon_token,
        };

        return &node.base;
    }

    /// FnProto <- KEYWORD_fn IDENTIFIER? LPAREN ParamDeclList RPAREN ByteAlign? LinkSection? EXCLAMATIONMARK? (Keyword_anytype / TypeExpr)
    fn parseFnProto(p: *Parser, level: enum { top_level, as_type }, fields: struct {
        doc_comments: ?*Node.DocComment = null,
        visib_token: ?TokenIndex = null,
        extern_export_inline_token: ?TokenIndex = null,
        lib_name: ?*Node = null,
    }) !?*Node {
        // TODO: Remove once extern/async fn rewriting is
        var is_async: ?void = null;
        var is_extern_prototype: ?void = null;
        const cc_token: ?TokenIndex = blk: {
            if (p.eatToken(.Keyword_extern)) |token| {
                is_extern_prototype = {};
                break :blk token;
            }
            if (p.eatToken(.Keyword_async)) |token| {
                is_async = {};
                break :blk token;
            }
            break :blk null;
        };
        const fn_token = p.eatToken(.Keyword_fn) orelse {
            if (cc_token) |token|
                p.putBackToken(token);
            return null;
        };
        const name_token = p.eatToken(.Identifier);
        const lparen = try p.expectToken(.LParen);
        const params = try p.parseParamDeclList();
        defer p.gpa.free(params);
        const var_args_token = p.eatToken(.Ellipsis3);
        const rparen = try p.expectToken(.RParen);
        const align_expr = try p.parseByteAlign();
        const section_expr = try p.parseLinkSection();
        const callconv_expr = try p.parseCallconv();
        const exclamation_token = p.eatToken(.Bang);

        const return_type_expr = (try p.parseAnyType()) orelse
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

        const body_node: ?*Node = switch (level) {
            .top_level => blk: {
                if (p.eatToken(.Semicolon)) |_| {
                    break :blk null;
                }
                const body_block = (try p.parseBlock(null)) orelse {
                    // Since parseBlock only return error.ParseError on
                    // a missing '}' we can assume this function was
                    // supposed to end here.
                    try p.errors.append(p.gpa, .{ .ExpectedSemiOrLBrace = .{ .token = p.tok_i } });
                    break :blk null;
                };
                break :blk body_block;
            },
            .as_type => null,
        };

        const fn_proto_node = try Node.FnProto.create(&p.arena.allocator, .{
            .params_len = params.len,
            .fn_token = fn_token,
            .return_type = return_type,
        }, .{
            .doc_comments = fields.doc_comments,
            .visib_token = fields.visib_token,
            .name_token = name_token,
            .var_args_token = var_args_token,
            .extern_export_inline_token = fields.extern_export_inline_token,
            .body_node = body_node,
            .lib_name = fields.lib_name,
            .align_expr = align_expr,
            .section_expr = section_expr,
            .callconv_expr = callconv_expr,
            .is_extern_prototype = is_extern_prototype,
            .is_async = is_async,
        });
        std.mem.copy(Node.FnProto.ParamDecl, fn_proto_node.params(), params);

        return &fn_proto_node.base;
    }

    /// VarDecl <- (KEYWORD_const / KEYWORD_var) IDENTIFIER (COLON TypeExpr)? ByteAlign? LinkSection? (EQUAL Expr)? SEMICOLON
    fn parseVarDecl(p: *Parser, fields: struct {
        doc_comments: ?*Node.DocComment = null,
        visib_token: ?TokenIndex = null,
        thread_local_token: ?TokenIndex = null,
        extern_export_token: ?TokenIndex = null,
        lib_name: ?*Node = null,
        comptime_token: ?TokenIndex = null,
    }) !?*Node {
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

        const doc_comments = fields.doc_comments orelse try p.parseAppendedDocComment(semicolon_token);

        const node = try Node.VarDecl.create(&p.arena.allocator, .{
            .mut_token = mut_token,
            .name_token = name_token,
            .semicolon_token = semicolon_token,
        }, .{
            .doc_comments = doc_comments,
            .visib_token = fields.visib_token,
            .thread_local_token = fields.thread_local_token,
            .eq_token = eq_token,
            .comptime_token = fields.comptime_token,
            .extern_export_token = fields.extern_export_token,
            .lib_name = fields.lib_name,
            .type_node = type_node,
            .align_node = align_node,
            .section_node = section_node,
            .init_node = init_node,
        });
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
            if (p.eatToken(.Keyword_anytype) orelse p.eatToken(.Keyword_var)) |anytype_tok| {
                const node = try p.arena.allocator.create(Node.OneToken);
                node.* = .{
                    .base = .{ .tag = .AnyType },
                    .token = anytype_tok,
                };
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

        if (try p.parseVarDecl(.{
            .comptime_token = comptime_token,
        })) |node| {
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
            const payload = if (p.token_ids[token] == .Keyword_errdefer)
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

        if (try p.parseBlock(label_token)) |node| return node;

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

        for_prefix.body = try p.expectNode(parseAssignExpr, .{
            .ExpectedBlockOrAssignment = .{ .token = p.tok_i },
        });

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

        while_prefix.body = try p.expectNode(parseAssignExpr, .{
            .ExpectedBlockOrAssignment = .{ .token = p.tok_i },
        });

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
        const block_node = (try p.parseBlock(label_token)) orelse {
            if (label_token) |label| {
                p.putBackToken(label + 1); // ":"
                p.putBackToken(label); // IDENTIFIER
            }
            return null;
        };
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
            SimpleBinOpParseFn(.Keyword_or, .BoolOr),
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
            const node = try Node.ControlFlowExpression.create(&p.arena.allocator, .{
                .tag = .Break,
                .ltoken = token,
            }, .{
                .label = label,
                .rhs = expr_node,
            });
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
            const node = try Node.ControlFlowExpression.create(&p.arena.allocator, .{
                .tag = .Continue,
                .ltoken = token,
            }, .{
                .label = label,
                .rhs = null,
            });
            return &node.base;
        }

        if (p.eatToken(.Keyword_resume)) |token| {
            const expr_node = try p.expectNode(parseExpr, .{
                .ExpectedExpr = .{ .token = p.tok_i },
            });
            const node = try p.arena.allocator.create(Node.SimplePrefixOp);
            node.* = .{
                .base = .{ .tag = .Resume },
                .op_token = token,
                .rhs = expr_node,
            };
            return &node.base;
        }

        if (p.eatToken(.Keyword_return)) |token| {
            const expr_node = try p.parseExpr();
            const node = try Node.ControlFlowExpression.create(&p.arena.allocator, .{
                .tag = .Return,
                .ltoken = token,
            }, .{
                .rhs = expr_node,
            });
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

        if (try p.parseBlock(null)) |node| return node;
        if (try p.parseCurlySuffixExpr()) |node| return node;

        return null;
    }

    /// IfExpr <- IfPrefix Expr (KEYWORD_else Payload? Expr)?
    fn parseIfExpr(p: *Parser) !?*Node {
        return p.parseIf(parseExpr);
    }

    /// Block <- LBRACE Statement* RBRACE
    fn parseBlock(p: *Parser, label_token: ?TokenIndex) !?*Node {
        const lbrace = p.eatToken(.LBrace) orelse return null;

        var statements = std.ArrayList(*Node).init(p.gpa);
        defer statements.deinit();

        while (true) {
            const statement = (p.parseStatement() catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.ParseError => {
                    // try to skip to the next statement
                    p.findNextStmt();
                    continue;
                },
            }) orelse break;
            try statements.append(statement);
        }

        const rbrace = try p.expectToken(.RBrace);

        const statements_len = @intCast(NodeIndex, statements.items.len);

        if (label_token) |label| {
            const block_node = try Node.LabeledBlock.alloc(&p.arena.allocator, statements_len);
            block_node.* = .{
                .label = label,
                .lbrace = lbrace,
                .statements_len = statements_len,
                .rbrace = rbrace,
            };
            std.mem.copy(*Node, block_node.statements(), statements.items);
            return &block_node.base;
        } else {
            const block_node = try Node.Block.alloc(&p.arena.allocator, statements_len);
            block_node.* = .{
                .lbrace = lbrace,
                .statements_len = statements_len,
                .rbrace = rbrace,
            };
            std.mem.copy(*Node, block_node.statements(), statements.items);
            return &block_node.base;
        }
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
            const node = try Node.StructInitializer.alloc(&p.arena.allocator, init_list.items.len);
            node.* = .{
                .lhs = lhs,
                .rtoken = try p.expectToken(.RBrace),
                .list_len = init_list.items.len,
            };
            std.mem.copy(*Node, node.list(), init_list.items);
            return &node.base;
        }

        if (try p.parseExpr()) |expr| {
            try init_list.append(expr);
            while (p.eatToken(.Comma)) |_| {
                const next = (try p.parseExpr()) orelse break;
                try init_list.append(next);
            }
            const node = try Node.ArrayInitializer.alloc(&p.arena.allocator, init_list.items.len);
            node.* = .{
                .lhs = lhs,
                .rtoken = try p.expectToken(.RBrace),
                .list_len = init_list.items.len,
            };
            std.mem.copy(*Node, node.list(), init_list.items);
            return &node.base;
        }

        const node = try p.arena.allocator.create(Node.StructInitializer);
        node.* = .{
            .lhs = lhs,
            .rtoken = try p.expectToken(.RBrace),
            .list_len = 0,
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
            const node = try Node.StructInitializerDot.alloc(&p.arena.allocator, init_list.items.len);
            node.* = .{
                .dot = dot,
                .rtoken = try p.expectToken(.RBrace),
                .list_len = init_list.items.len,
            };
            std.mem.copy(*Node, node.list(), init_list.items);
            return &node.base;
        }

        if (try p.parseExpr()) |expr| {
            try init_list.append(expr);
            while (p.eatToken(.Comma)) |_| {
                const next = (try p.parseExpr()) orelse break;
                try init_list.append(next);
            }
            const node = try Node.ArrayInitializerDot.alloc(&p.arena.allocator, init_list.items.len);
            node.* = .{
                .dot = dot,
                .rtoken = try p.expectToken(.RBrace),
                .list_len = init_list.items.len,
            };
            std.mem.copy(*Node, node.list(), init_list.items);
            return &node.base;
        }

        const node = try p.arena.allocator.create(Node.StructInitializerDot);
        node.* = .{
            .dot = dot,
            .rtoken = try p.expectToken(.RBrace),
            .list_len = 0,
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

        if (try SimpleBinOpParseFn(.Bang, .ErrorUnion)(p)) |node| {
            const error_union = node.castTag(.ErrorUnion).?;
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

            while (try p.parseSuffixOp(res)) |node| {
                res = node;
            }

            const params = (try p.parseFnCallArguments()) orelse {
                try p.errors.append(p.gpa, .{
                    .ExpectedParamList = .{ .token = p.tok_i },
                });
                // ignore this, continue parsing
                return res;
            };
            defer p.gpa.free(params.list);
            const node = try Node.Call.alloc(&p.arena.allocator, params.list.len);
            node.* = .{
                .lhs = res,
                .params_len = params.list.len,
                .async_token = async_token,
                .rtoken = params.rparen,
            };
            std.mem.copy(*Node, node.params(), params.list);
            return &node.base;
        }
        if (try p.parsePrimaryTypeExpr()) |expr| {
            var res = expr;

            while (true) {
                if (try p.parseSuffixOp(res)) |node| {
                    res = node;
                    continue;
                }
                if (try p.parseFnCallArguments()) |params| {
                    defer p.gpa.free(params.list);
                    const call = try Node.Call.alloc(&p.arena.allocator, params.list.len);
                    call.* = .{
                        .lhs = res,
                        .params_len = params.list.len,
                        .async_token = null,
                        .rtoken = params.rparen,
                    };
                    std.mem.copy(*Node, call.params(), params.list);
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
            const node = try p.arena.allocator.create(Node.OneToken);
            node.* = .{
                .base = .{ .tag = .CharLiteral },
                .token = token,
            };
            return &node.base;
        }
        if (try p.parseContainerDecl()) |node| return node;
        if (try p.parseAnonLiteral()) |node| return node;
        if (try p.parseErrorSetDecl()) |node| return node;
        if (try p.parseFloatLiteral()) |node| return node;
        if (try p.parseFnProto(.as_type, .{})) |node| return node;
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
            const global_error_set = try p.createLiteral(.ErrorType, token);
            if (period == null or identifier == null) return global_error_set;

            const node = try p.arena.allocator.create(Node.SimpleInfixOp);
            node.* = .{
                .base = Node{ .tag = .Period },
                .op_token = period.?,
                .lhs = global_error_set,
                .rhs = identifier.?,
            };
            return &node.base;
        }
        if (p.eatToken(.Keyword_false)) |token| return p.createLiteral(.BoolLiteral, token);
        if (p.eatToken(.Keyword_null)) |token| return p.createLiteral(.NullLiteral, token);
        if (p.eatToken(.Keyword_anyframe)) |token| {
            const node = try p.arena.allocator.create(Node.AnyFrameType);
            node.* = .{
                .anyframe_token = token,
                .result = null,
            };
            return &node.base;
        }
        if (p.eatToken(.Keyword_true)) |token| return p.createLiteral(.BoolLiteral, token);
        if (p.eatToken(.Keyword_undefined)) |token| return p.createLiteral(.UndefinedLiteral, token);
        if (p.eatToken(.Keyword_unreachable)) |token| return p.createLiteral(.Unreachable, token);
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
        defer p.gpa.free(decls);
        const rbrace = try p.expectToken(.RBrace);

        const node = try Node.ErrorSetDecl.alloc(&p.arena.allocator, decls.len);
        node.* = .{
            .error_token = error_token,
            .decls_len = decls.len,
            .rbrace_token = rbrace,
        };
        std.mem.copy(*Node, node.decls(), decls);
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

        if (label) |label_token| {
            if (try p.parseBlock(label_token)) |node| return node;
        }

        if (try p.parseLoopTypeExpr()) |node| {
            switch (node.tag) {
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
        defer p.gpa.free(cases);
        const rbrace = try p.expectToken(.RBrace);

        const node = try Node.Switch.alloc(&p.arena.allocator, cases.len);
        node.* = .{
            .switch_token = switch_token,
            .expr = expr_node,
            .cases_len = cases.len,
            .rbrace = rbrace,
        };
        std.mem.copy(*Node, node.cases(), cases);
        return &node.base;
    }

    /// AsmExpr <- KEYWORD_asm KEYWORD_volatile? LPAREN Expr AsmOutput? RPAREN
    /// AsmOutput <- COLON AsmOutputList AsmInput?
    /// AsmInput <- COLON AsmInputList AsmClobbers?
    /// AsmClobbers <- COLON StringList
    /// StringList <- (STRINGLITERAL COMMA)* STRINGLITERAL?
    fn parseAsmExpr(p: *Parser) !?*Node {
        const asm_token = p.eatToken(.Keyword_asm) orelse return null;
        const volatile_token = p.eatToken(.Keyword_volatile);
        _ = try p.expectToken(.LParen);
        const template = try p.expectNode(parseExpr, .{
            .ExpectedExpr = .{ .token = p.tok_i },
        });

        var arena_outputs: []Node.Asm.Output = &[0]Node.Asm.Output{};
        var arena_inputs: []Node.Asm.Input = &[0]Node.Asm.Input{};
        var arena_clobbers: []*Node = &[0]*Node{};

        if (p.eatToken(.Colon) != null) {
            const outputs = try p.parseAsmOutputList();
            defer p.gpa.free(outputs);
            arena_outputs = try p.arena.allocator.dupe(Node.Asm.Output, outputs);

            if (p.eatToken(.Colon) != null) {
                const inputs = try p.parseAsmInputList();
                defer p.gpa.free(inputs);
                arena_inputs = try p.arena.allocator.dupe(Node.Asm.Input, inputs);

                if (p.eatToken(.Colon) != null) {
                    const clobbers = try ListParseFn(*Node, parseStringLiteral)(p);
                    defer p.gpa.free(clobbers);
                    arena_clobbers = try p.arena.allocator.dupe(*Node, clobbers);
                }
            }
        }

        const node = try p.arena.allocator.create(Node.Asm);
        node.* = .{
            .asm_token = asm_token,
            .volatile_token = volatile_token,
            .template = template,
            .outputs = arena_outputs,
            .inputs = arena_inputs,
            .clobbers = arena_clobbers,
            .rparen = try p.expectToken(.RParen),
        };

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

    /// AsmOutputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN (MINUSRARROW TypeExpr / IDENTIFIER) RPAREN
    fn parseAsmOutputItem(p: *Parser) !?Node.Asm.Output {
        const lbracket = p.eatToken(.LBracket) orelse return null;
        const name = try p.expectNode(parseIdentifier, .{
            .ExpectedIdentifier = .{ .token = p.tok_i },
        });
        _ = try p.expectToken(.RBracket);

        const constraint = try p.expectNode(parseStringLiteral, .{
            .ExpectedStringLiteral = .{ .token = p.tok_i },
        });

        _ = try p.expectToken(.LParen);
        const kind: Node.Asm.Output.Kind = blk: {
            if (p.eatToken(.Arrow) != null) {
                const return_ident = try p.expectNode(parseTypeExpr, .{
                    .ExpectedTypeExpr = .{ .token = p.tok_i },
                });
                break :blk .{ .Return = return_ident };
            }
            const variable = try p.expectNode(parseIdentifier, .{
                .ExpectedIdentifier = .{ .token = p.tok_i },
            });
            break :blk .{ .Variable = variable.castTag(.Identifier).? };
        };
        const rparen = try p.expectToken(.RParen);

        return Node.Asm.Output{
            .lbracket = lbracket,
            .symbolic_name = name,
            .constraint = constraint,
            .kind = kind,
            .rparen = rparen,
        };
    }

    /// AsmInputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN Expr RPAREN
    fn parseAsmInputItem(p: *Parser) !?Node.Asm.Input {
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

        return Node.Asm.Input{
            .lbracket = lbracket,
            .symbolic_name = name,
            .constraint = constraint,
            .expr = expr,
            .rparen = rparen,
        };
    }

    /// BreakLabel <- COLON IDENTIFIER
    fn parseBreakLabel(p: *Parser) !?TokenIndex {
        _ = p.eatToken(.Colon) orelse return null;
        const ident = try p.expectToken(.Identifier);
        return ident;
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
    fn parseParamDecl(p: *Parser) !?Node.FnProto.ParamDecl {
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
                doc_comments == null)
            {
                return null;
            }
            try p.errors.append(p.gpa, .{
                .ExpectedParamType = .{ .token = p.tok_i },
            });
            return error.ParseError;
        };

        return Node.FnProto.ParamDecl{
            .doc_comments = doc_comments,
            .comptime_token = comptime_token,
            .noalias_token = noalias_token,
            .name_token = name_token,
            .param_type = param_type,
        };
    }

    /// ParamType
    ///     <- Keyword_anytype
    ///      / DOT3
    ///      / TypeExpr
    fn parseParamType(p: *Parser) !?Node.FnProto.ParamDecl.ParamType {
        // TODO cast from tuple to error union is broken
        const P = Node.FnProto.ParamDecl.ParamType;
        if (try p.parseAnyType()) |node| return P{ .any_type = node };
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
        var list = std.ArrayList(*Node).init(p.gpa);
        defer list.deinit();

        if (try p.parseSwitchItem()) |first_item| {
            try list.append(first_item);
            while (p.eatToken(.Comma) != null) {
                const next_item = (try p.parseSwitchItem()) orelse break;
                try list.append(next_item);
            }
        } else if (p.eatToken(.Keyword_else)) |else_token| {
            const else_node = try p.arena.allocator.create(Node.SwitchElse);
            else_node.* = .{
                .token = else_token,
            };
            try list.append(&else_node.base);
        } else return null;

        const node = try Node.SwitchCase.alloc(&p.arena.allocator, list.items.len);
        node.* = .{
            .items_len = list.items.len,
            .arrow_token = undefined, // set by caller
            .payload = null,
            .expr = undefined, // set by caller
        };
        std.mem.copy(*Node, node.items(), list.items);
        return &node.base;
    }

    /// SwitchItem <- Expr (DOT3 Expr)?
    fn parseSwitchItem(p: *Parser) !?*Node {
        const expr = (try p.parseExpr()) orelse return null;
        if (p.eatToken(.Ellipsis3)) |token| {
            const range_end = try p.expectNode(parseExpr, .{
                .ExpectedExpr = .{ .token = p.tok_i },
            });

            const node = try p.arena.allocator.create(Node.SimpleInfixOp);
            node.* = .{
                .base = Node{ .tag = .Range },
                .op_token = token,
                .lhs = expr,
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
        const op: Node.Tag = switch (p.token_ids[token]) {
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
                p.putBackToken(token);
                return null;
            },
        };

        const node = try p.arena.allocator.create(Node.SimpleInfixOp);
        node.* = .{
            .base = .{ .tag = op },
            .op_token = token,
            .lhs = undefined, // set by caller
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
        const op: Node.Tag = switch (p.token_ids[token]) {
            .EqualEqual => .EqualEqual,
            .BangEqual => .BangEqual,
            .AngleBracketLeft => .LessThan,
            .AngleBracketRight => .GreaterThan,
            .AngleBracketLeftEqual => .LessOrEqual,
            .AngleBracketRightEqual => .GreaterOrEqual,
            else => {
                p.putBackToken(token);
                return null;
            },
        };

        return p.createInfixOp(token, op);
    }

    /// BitwiseOp
    ///     <- AMPERSAND
    ///      / CARET
    ///      / PIPE
    ///      / KEYWORD_orelse
    ///      / KEYWORD_catch Payload?
    fn parseBitwiseOp(p: *Parser) !?*Node {
        const token = p.nextToken();
        const op: Node.Tag = switch (p.token_ids[token]) {
            .Ampersand => .BitAnd,
            .Caret => .BitXor,
            .Pipe => .BitOr,
            .Keyword_orelse => .OrElse,
            .Keyword_catch => {
                const payload = try p.parsePayload();
                const node = try p.arena.allocator.create(Node.Catch);
                node.* = .{
                    .op_token = token,
                    .lhs = undefined, // set by caller
                    .rhs = undefined, // set by caller
                    .payload = payload,
                };
                return &node.base;
            },
            else => {
                p.putBackToken(token);
                return null;
            },
        };

        return p.createInfixOp(token, op);
    }

    /// BitShiftOp
    ///     <- LARROW2
    ///      / RARROW2
    fn parseBitShiftOp(p: *Parser) !?*Node {
        const token = p.nextToken();
        const op: Node.Tag = switch (p.token_ids[token]) {
            .AngleBracketAngleBracketLeft => .BitShiftLeft,
            .AngleBracketAngleBracketRight => .BitShiftRight,
            else => {
                p.putBackToken(token);
                return null;
            },
        };

        return p.createInfixOp(token, op);
    }

    /// AdditionOp
    ///     <- PLUS
    ///      / MINUS
    ///      / PLUS2
    ///      / PLUSPERCENT
    ///      / MINUSPERCENT
    fn parseAdditionOp(p: *Parser) !?*Node {
        const token = p.nextToken();
        const op: Node.Tag = switch (p.token_ids[token]) {
            .Plus => .Add,
            .Minus => .Sub,
            .PlusPlus => .ArrayCat,
            .PlusPercent => .AddWrap,
            .MinusPercent => .SubWrap,
            else => {
                p.putBackToken(token);
                return null;
            },
        };

        return p.createInfixOp(token, op);
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
        const op: Node.Tag = switch (p.token_ids[token]) {
            .PipePipe => .MergeErrorSets,
            .Asterisk => .Mul,
            .Slash => .Div,
            .Percent => .Mod,
            .AsteriskAsterisk => .ArrayMult,
            .AsteriskPercent => .MulWrap,
            else => {
                p.putBackToken(token);
                return null;
            },
        };

        return p.createInfixOp(token, op);
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
        switch (p.token_ids[token]) {
            .Bang => return p.allocSimplePrefixOp(.BoolNot, token),
            .Minus => return p.allocSimplePrefixOp(.Negation, token),
            .Tilde => return p.allocSimplePrefixOp(.BitNot, token),
            .MinusPercent => return p.allocSimplePrefixOp(.NegationWrap, token),
            .Ampersand => return p.allocSimplePrefixOp(.AddressOf, token),
            .Keyword_try => return p.allocSimplePrefixOp(.Try, token),
            .Keyword_await => return p.allocSimplePrefixOp(.Await, token),
            else => {
                p.putBackToken(token);
                return null;
            },
        }
    }

    fn allocSimplePrefixOp(p: *Parser, comptime tag: Node.Tag, token: TokenIndex) !?*Node {
        const node = try p.arena.allocator.create(Node.SimplePrefixOp);
        node.* = .{
            .base = .{ .tag = tag },
            .op_token = token,
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
            const node = try p.arena.allocator.create(Node.SimplePrefixOp);
            node.* = .{
                .base = .{ .tag = .OptionalType },
                .op_token = token,
                .rhs = undefined, // set by caller
            };
            return &node.base;
        }

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
            var ptr_info = if (node.cast(Node.PtrType)) |ptr_type|
                if (p.token_ids[ptr_type.op_token] == .AsteriskAsterisk)
                    &ptr_type.rhs.cast(Node.PtrType).?.ptr_info
                else
                    &ptr_type.ptr_info
            else if (node.cast(Node.SliceType)) |slice_type|
                &slice_type.ptr_info
            else
                unreachable;

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

                        break :bit_range_value ast.PtrInfo.Align.BitRange{
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

                    ptr_info.align_info = ast.PtrInfo.Align{
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
            if (node.cast(Node.SliceType)) |slice_type| {
                // Collect pointer qualifiers in any order, but disallow duplicates
                while (true) {
                    if (try p.parseByteAlign()) |align_expr| {
                        if (slice_type.ptr_info.align_info != null) {
                            try p.errors.append(p.gpa, .{
                                .ExtraAlignQualifier = .{ .token = p.tok_i - 1 },
                            });
                            continue;
                        }
                        slice_type.ptr_info.align_info = ast.PtrInfo.Align{
                            .node = align_expr,
                            .bit_range = null,
                        };
                        continue;
                    }
                    if (p.eatToken(.Keyword_const)) |const_token| {
                        if (slice_type.ptr_info.const_token != null) {
                            try p.errors.append(p.gpa, .{
                                .ExtraConstQualifier = .{ .token = p.tok_i - 1 },
                            });
                            continue;
                        }
                        slice_type.ptr_info.const_token = const_token;
                        continue;
                    }
                    if (p.eatToken(.Keyword_volatile)) |volatile_token| {
                        if (slice_type.ptr_info.volatile_token != null) {
                            try p.errors.append(p.gpa, .{
                                .ExtraVolatileQualifier = .{ .token = p.tok_i - 1 },
                            });
                            continue;
                        }
                        slice_type.ptr_info.volatile_token = volatile_token;
                        continue;
                    }
                    if (p.eatToken(.Keyword_allowzero)) |allowzero_token| {
                        if (slice_type.ptr_info.allowzero_token != null) {
                            try p.errors.append(p.gpa, .{
                                .ExtraAllowZeroQualifier = .{ .token = p.tok_i - 1 },
                            });
                            continue;
                        }
                        slice_type.ptr_info.allowzero_token = allowzero_token;
                        continue;
                    }
                    break;
                }
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
    fn parseSuffixOp(p: *Parser, lhs: *Node) !?*Node {
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
                const rtoken = try p.expectToken(.RBracket);
                const node = try p.arena.allocator.create(Node.Slice);
                node.* = .{
                    .lhs = lhs,
                    .rtoken = rtoken,
                    .start = index_expr,
                    .end = end_expr,
                    .sentinel = sentinel,
                };
                return &node.base;
            }

            const rtoken = try p.expectToken(.RBracket);
            const node = try p.arena.allocator.create(Node.ArrayAccess);
            node.* = .{
                .lhs = lhs,
                .rtoken = rtoken,
                .index_expr = index_expr,
            };
            return &node.base;
        }

        if (p.eatToken(.PeriodAsterisk)) |period_asterisk| {
            const node = try p.arena.allocator.create(Node.SimpleSuffixOp);
            node.* = .{
                .base = .{ .tag = .Deref },
                .lhs = lhs,
                .rtoken = period_asterisk,
            };
            return &node.base;
        }

        if (p.eatToken(.Period)) |period| {
            if (try p.parseIdentifier()) |identifier| {
                const node = try p.arena.allocator.create(Node.SimpleInfixOp);
                node.* = .{
                    .base = Node{ .tag = .Period },
                    .op_token = period,
                    .lhs = lhs,
                    .rhs = identifier,
                };
                return &node.base;
            }
            if (p.eatToken(.QuestionMark)) |question_mark| {
                const node = try p.arena.allocator.create(Node.SimpleSuffixOp);
                node.* = .{
                    .base = .{ .tag = .UnwrapOptional },
                    .lhs = lhs,
                    .rtoken = question_mark,
                };
                return &node.base;
            }
            try p.errors.append(p.gpa, .{
                .ExpectedSuffixOp = .{ .token = p.tok_i },
            });
            return null;
        }

        return null;
    }

    /// FnCallArguments <- LPAREN ExprList RPAREN
    /// ExprList <- (Expr COMMA)* Expr?
    fn parseFnCallArguments(p: *Parser) !?AnnotatedParamList {
        if (p.eatToken(.LParen) == null) return null;
        const list = try ListParseFn(*Node, parseExpr)(p);
        errdefer p.gpa.free(list);
        const rparen = try p.expectToken(.RParen);
        return AnnotatedParamList{ .list = list, .rparen = rparen };
    }

    const AnnotatedParamList = struct {
        list: []*Node,
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

        if (expr) |len_expr| {
            if (sentinel) |s| {
                const node = try p.arena.allocator.create(Node.ArrayTypeSentinel);
                node.* = .{
                    .op_token = lbracket,
                    .rhs = undefined, // set by caller
                    .len_expr = len_expr,
                    .sentinel = s,
                };
                return &node.base;
            } else {
                const node = try p.arena.allocator.create(Node.ArrayType);
                node.* = .{
                    .op_token = lbracket,
                    .rhs = undefined, // set by caller
                    .len_expr = len_expr,
                };
                return &node.base;
            }
        }

        const node = try p.arena.allocator.create(Node.SliceType);
        node.* = .{
            .op_token = lbracket,
            .rhs = undefined, // set by caller
            .ptr_info = .{ .sentinel = sentinel },
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
            const node = try p.arena.allocator.create(Node.PtrType);
            node.* = .{
                .op_token = asterisk,
                .rhs = undefined, // set by caller
                .ptr_info = .{ .sentinel = sentinel },
            };
            return &node.base;
        }

        if (p.eatToken(.AsteriskAsterisk)) |double_asterisk| {
            const node = try p.arena.allocator.create(Node.PtrType);
            node.* = .{
                .op_token = double_asterisk,
                .rhs = undefined, // set by caller
            };

            // Special case for **, which is its own token
            const child = try p.arena.allocator.create(Node.PtrType);
            child.* = .{
                .op_token = double_asterisk,
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
                const token_loc = p.token_locs[ident];
                const token_slice = p.source[token_loc.start..token_loc.end];
                if (!std.mem.eql(u8, token_slice, "c")) {
                    p.putBackToken(ident);
                } else {
                    _ = try p.expectToken(.RBracket);
                    const node = try p.arena.allocator.create(Node.PtrType);
                    node.* = .{
                        .op_token = lbracket,
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
            const node = try p.arena.allocator.create(Node.PtrType);
            node.* = .{
                .op_token = lbracket,
                .rhs = undefined, // set by caller
                .ptr_info = .{ .sentinel = sentinel },
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

        const members_len = @intCast(NodeIndex, members.len);
        const node = try Node.ContainerDecl.alloc(&p.arena.allocator, members_len);
        node.* = .{
            .layout_token = null,
            .kind_token = container_decl_type.kind_token,
            .init_arg_expr = container_decl_type.init_arg_expr,
            .fields_and_decls_len = members_len,
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

        const init_arg_expr = switch (p.token_ids[kind_token]) {
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
                p.putBackToken(kind_token);
                return null;
            },
        };

        return ContainerDeclType{
            .kind_token = kind_token,
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
    fn parseErrorTagList(p: *Parser) ![]*Node {
        return ListParseFn(*Node, parseErrorTag)(p);
    }

    /// SwitchProngList <- (SwitchProng COMMA)* SwitchProng?
    fn parseSwitchProngList(p: *Parser) ![]*Node {
        return ListParseFn(*Node, parseSwitchProng)(p);
    }

    /// AsmOutputList <- (AsmOutputItem COMMA)* AsmOutputItem?
    fn parseAsmOutputList(p: *Parser) Error![]Node.Asm.Output {
        return ListParseFn(Node.Asm.Output, parseAsmOutputItem)(p);
    }

    /// AsmInputList <- (AsmInputItem COMMA)* AsmInputItem?
    fn parseAsmInputList(p: *Parser) Error![]Node.Asm.Input {
        return ListParseFn(Node.Asm.Input, parseAsmInputItem)(p);
    }

    /// ParamDeclList <- (ParamDecl COMMA)* ParamDecl?
    fn parseParamDeclList(p: *Parser) ![]Node.FnProto.ParamDecl {
        return ListParseFn(Node.FnProto.ParamDecl, parseParamDecl)(p);
    }

    const NodeParseFn = fn (p: *Parser) Error!?*Node;

    fn ListParseFn(comptime E: type, comptime nodeParseFn: anytype) ParseFn([]E) {
        return struct {
            pub fn parse(p: *Parser) ![]E {
                var list = std.ArrayList(E).init(p.gpa);
                defer list.deinit();

                while (try nodeParseFn(p)) |item| {
                    try list.append(item);

                    switch (p.token_ids[p.tok_i]) {
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
                return list.toOwnedSlice();
            }
        }.parse;
    }

    fn SimpleBinOpParseFn(comptime token: Token.Id, comptime op: Node.Tag) NodeParseFn {
        return struct {
            pub fn parse(p: *Parser) Error!?*Node {
                const op_token = if (token == .Keyword_and) switch (p.token_ids[p.tok_i]) {
                    .Keyword_and => p.nextToken(),
                    .Invalid_ampersands => blk: {
                        try p.errors.append(p.gpa, .{
                            .InvalidAnd = .{ .token = p.tok_i },
                        });
                        break :blk p.nextToken();
                    },
                    else => return null,
                } else p.eatToken(token) orelse return null;

                const node = try p.arena.allocator.create(Node.SimpleInfixOp);
                node.* = .{
                    .base = .{ .tag = op },
                    .op_token = op_token,
                    .lhs = undefined, // set by caller
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
            const node = try p.arena.allocator.create(Node.OneToken);
            node.* = .{
                .base = .{ .tag = .Identifier },
                .token = token,
            };
            return &node.base;
        };
        defer p.gpa.free(params.list);

        const node = try Node.BuiltinCall.alloc(&p.arena.allocator, params.list.len);
        node.* = .{
            .builtin_token = token,
            .params_len = params.list.len,
            .rparen_token = params.rparen,
        };
        std.mem.copy(*Node, node.params(), params.list);
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
        const node = try p.arena.allocator.create(Node.OneToken);
        node.* = .{
            .base = .{ .tag = .Identifier },
            .token = token,
        };
        return &node.base;
    }

    fn parseAnyType(p: *Parser) !?*Node {
        const token = p.eatToken(.Keyword_anytype) orelse
            p.eatToken(.Keyword_var) orelse return null; // TODO remove in next release cycle
        const node = try p.arena.allocator.create(Node.OneToken);
        node.* = .{
            .base = .{ .tag = .AnyType },
            .token = token,
        };
        return &node.base;
    }

    fn createLiteral(p: *Parser, tag: ast.Node.Tag, token: TokenIndex) !*Node {
        const result = try p.arena.allocator.create(Node.OneToken);
        result.* = .{
            .base = .{ .tag = tag },
            .token = token,
        };
        return &result.base;
    }

    fn parseStringLiteralSingle(p: *Parser) !?*Node {
        if (p.eatToken(.StringLiteral)) |token| {
            const node = try p.arena.allocator.create(Node.OneToken);
            node.* = .{
                .base = .{ .tag = .StringLiteral },
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
            const start_tok_i = p.tok_i;
            var tok_i = start_tok_i;
            var count: usize = 1; // including first_line
            while (true) : (tok_i += 1) {
                switch (p.token_ids[tok_i]) {
                    .LineComment => continue,
                    .MultilineStringLiteralLine => count += 1,
                    else => break,
                }
            }

            const node = try Node.MultilineStringLiteral.alloc(&p.arena.allocator, count);
            node.* = .{ .lines_len = count };
            const lines = node.lines();
            tok_i = start_tok_i;
            lines[0] = first_line;
            count = 1;
            while (true) : (tok_i += 1) {
                switch (p.token_ids[tok_i]) {
                    .LineComment => continue,
                    .MultilineStringLiteralLine => {
                        lines[count] = tok_i;
                        count += 1;
                    },
                    else => break,
                }
            }
            p.tok_i = tok_i;
            return &node.base;
        }

        return null;
    }

    fn parseIntegerLiteral(p: *Parser) !?*Node {
        const token = p.eatToken(.IntegerLiteral) orelse return null;
        const node = try p.arena.allocator.create(Node.OneToken);
        node.* = .{
            .base = .{ .tag = .IntegerLiteral },
            .token = token,
        };
        return &node.base;
    }

    fn parseFloatLiteral(p: *Parser) !?*Node {
        const token = p.eatToken(.FloatLiteral) orelse return null;
        const node = try p.arena.allocator.create(Node.OneToken);
        node.* = .{
            .base = .{ .tag = .FloatLiteral },
            .token = token,
        };
        return &node.base;
    }

    fn parseTry(p: *Parser) !?*Node {
        const token = p.eatToken(.Keyword_try) orelse return null;
        const node = try p.arena.allocator.create(Node.SimplePrefixOp);
        node.* = .{
            .base = .{ .tag = .Try },
            .op_token = token,
            .rhs = undefined, // set by caller
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
        if (p.eatToken(.DocComment)) |first_line| {
            while (p.eatToken(.DocComment)) |_| {}
            const node = try p.arena.allocator.create(Node.DocComment);
            node.* = .{ .first_line = first_line };
            return node;
        }
        return null;
    }

    fn tokensOnSameLine(p: *Parser, token1: TokenIndex, token2: TokenIndex) bool {
        return std.mem.indexOfScalar(u8, p.source[p.token_locs[token1].end..p.token_locs[token2].start], '\n') == null;
    }

    /// Eat a single-line doc comment on the same line as another node
    fn parseAppendedDocComment(p: *Parser, after_token: TokenIndex) !?*Node.DocComment {
        const comment_token = p.eatToken(.DocComment) orelse return null;
        if (p.tokensOnSameLine(after_token, comment_token)) {
            const node = try p.arena.allocator.create(Node.DocComment);
            node.* = .{ .first_line = comment_token };
            return node;
        }
        p.putBackToken(comment_token);
        return null;
    }

    /// Op* Child
    fn parsePrefixOpExpr(p: *Parser, comptime opParseFn: NodeParseFn, comptime childParseFn: NodeParseFn) Error!?*Node {
        if (try opParseFn(p)) |first_op| {
            var rightmost_op = first_op;
            while (true) {
                switch (rightmost_op.tag) {
                    .AddressOf,
                    .Await,
                    .BitNot,
                    .BoolNot,
                    .OptionalType,
                    .Negation,
                    .NegationWrap,
                    .Resume,
                    .Try,
                    => {
                        if (try opParseFn(p)) |rhs| {
                            rightmost_op.cast(Node.SimplePrefixOp).?.rhs = rhs;
                            rightmost_op = rhs;
                        } else break;
                    },
                    .ArrayType => {
                        if (try opParseFn(p)) |rhs| {
                            rightmost_op.cast(Node.ArrayType).?.rhs = rhs;
                            rightmost_op = rhs;
                        } else break;
                    },
                    .ArrayTypeSentinel => {
                        if (try opParseFn(p)) |rhs| {
                            rightmost_op.cast(Node.ArrayTypeSentinel).?.rhs = rhs;
                            rightmost_op = rhs;
                        } else break;
                    },
                    .SliceType => {
                        if (try opParseFn(p)) |rhs| {
                            rightmost_op.cast(Node.SliceType).?.rhs = rhs;
                            rightmost_op = rhs;
                        } else break;
                    },
                    .PtrType => {
                        var ptr_type = rightmost_op.cast(Node.PtrType).?;
                        // If the token encountered was **, there will be two nodes
                        if (p.token_ids[ptr_type.op_token] == .AsteriskAsterisk) {
                            rightmost_op = ptr_type.rhs;
                            ptr_type = rightmost_op.cast(Node.PtrType).?;
                        }
                        if (try opParseFn(p)) |rhs| {
                            ptr_type.rhs = rhs;
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
            switch (rightmost_op.tag) {
                .AddressOf,
                .Await,
                .BitNot,
                .BoolNot,
                .OptionalType,
                .Negation,
                .NegationWrap,
                .Resume,
                .Try,
                => {
                    const prefix_op = rightmost_op.cast(Node.SimplePrefixOp).?;
                    prefix_op.rhs = try p.expectNode(childParseFn, .{
                        .InvalidToken = .{ .token = p.tok_i },
                    });
                },
                .ArrayType => {
                    const prefix_op = rightmost_op.cast(Node.ArrayType).?;
                    prefix_op.rhs = try p.expectNode(childParseFn, .{
                        .InvalidToken = .{ .token = p.tok_i },
                    });
                },
                .ArrayTypeSentinel => {
                    const prefix_op = rightmost_op.cast(Node.ArrayTypeSentinel).?;
                    prefix_op.rhs = try p.expectNode(childParseFn, .{
                        .InvalidToken = .{ .token = p.tok_i },
                    });
                },
                .PtrType => {
                    const prefix_op = rightmost_op.cast(Node.PtrType).?;
                    prefix_op.rhs = try p.expectNode(childParseFn, .{
                        .InvalidToken = .{ .token = p.tok_i },
                    });
                },
                .SliceType => {
                    const prefix_op = rightmost_op.cast(Node.SliceType).?;
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

            if (node.castTag(.Catch)) |op| {
                op.lhs = left;
                op.rhs = right;
            } else if (node.cast(Node.SimpleInfixOp)) |op| {
                op.lhs = left;
                op.rhs = right;
            }

            switch (chain) {
                .Once => break,
                .Infinitely => continue,
            }
        }

        return res;
    }

    fn createInfixOp(p: *Parser, op_token: TokenIndex, tag: Node.Tag) !*Node {
        const node = try p.arena.allocator.create(Node.SimpleInfixOp);
        node.* = .{
            .base = Node{ .tag = tag },
            .op_token = op_token,
            .lhs = undefined, // set by caller
            .rhs = undefined, // set by caller
        };
        return &node.base;
    }

    fn eatToken(p: *Parser, id: Token.Id) ?TokenIndex {
        return if (p.token_ids[p.tok_i] == id) p.nextToken() else null;
    }

    fn expectToken(p: *Parser, id: Token.Id) Error!TokenIndex {
        return (try p.expectTokenRecoverable(id)) orelse error.ParseError;
    }

    fn expectTokenRecoverable(p: *Parser, id: Token.Id) !?TokenIndex {
        const token = p.nextToken();
        if (p.token_ids[token] != id) {
            try p.errors.append(p.gpa, .{
                .ExpectedToken = .{ .token = token, .expected_id = id },
            });
            // go back so that we can recover properly
            p.putBackToken(token);
            return null;
        }
        return token;
    }

    fn nextToken(p: *Parser) TokenIndex {
        const result = p.tok_i;
        p.tok_i += 1;
        assert(p.token_ids[result] != .LineComment);
        if (p.tok_i >= p.token_ids.len) return result;

        while (true) {
            if (p.token_ids[p.tok_i] != .LineComment) return result;
            p.tok_i += 1;
        }
    }

    fn putBackToken(p: *Parser, putting_back: TokenIndex) void {
        while (p.tok_i > 0) {
            p.tok_i -= 1;
            if (p.token_ids[p.tok_i] == .LineComment) continue;
            assert(putting_back == p.tok_i);
            return;
        }
    }

    /// TODO Delete this function. I don't like the inversion of control.
    fn expectNode(
        p: *Parser,
        parseFn: NodeParseFn,
        /// if parsing fails
        err: AstError,
    ) Error!*Node {
        return (try p.expectNodeRecoverable(parseFn, err)) orelse return error.ParseError;
    }

    /// TODO Delete this function. I don't like the inversion of control.
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
