// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
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
const Token = std.zig.Token;

pub const Error = error{ParseError} || Allocator.Error;

/// Result should be freed with tree.deinit() when there are
/// no more references to any of the tokens or nodes.
pub fn parse(gpa: *Allocator, source: []const u8) Allocator.Error!Tree {
    var tokens = ast.TokenList{};
    defer tokens.deinit(gpa);

    // Empirically, the zig std lib has an 8:1 ratio of source bytes to token count.
    const estimated_token_count = source.len / 8;
    try tokens.ensureCapacity(gpa, estimated_token_count);

    var tokenizer = std.zig.Tokenizer.init(source);
    while (true) {
        const token = tokenizer.next();
        try tokens.append(gpa, .{
            .tag = token.tag,
            .start = @intCast(u32, token.loc.start),
        });
        if (token.tag == .Eof) break;
    }

    var parser: Parser = .{
        .source = source,
        .gpa = gpa,
        .token_tags = tokens.items(.tag),
        .token_starts = tokens.items(.start),
        .errors = .{},
        .nodes = .{},
        .extra_data = .{},
        .tok_i = 0,
    };
    defer parser.errors.deinit(gpa);
    defer parser.nodes.deinit(gpa);
    defer parser.extra_data.deinit(gpa);

    // Empirically, Zig source code has a 2:1 ratio of tokens to AST nodes.
    // Make sure at least 1 so we can use appendAssumeCapacity on the root node below.
    const estimated_node_count = (tokens.len + 2) / 2;
    try parser.nodes.ensureCapacity(gpa, estimated_node_count);

    // Root node must be index 0.
    // Root <- skip ContainerMembers eof
    parser.nodes.appendAssumeCapacity(.{
        .tag = .Root,
        .main_token = 0,
        .data = .{
            .lhs = undefined,
            .rhs = undefined,
        },
    });
    const root_members = try parser.parseContainerMembers();
    const root_decls = try root_members.toSpan(&parser);
    // parseContainerMembers will try to skip as much invalid tokens as
    // it can, so we are now at EOF.
    assert(parser.token_tags[parser.tok_i] == .Eof);
    parser.nodes.items(.data)[0] = .{
        .lhs = root_decls.start,
        .rhs = root_decls.end,
    };

    // TODO experiment with compacting the MultiArrayList slices here
    return Tree{
        .source = source,
        .tokens = tokens.toOwnedSlice(),
        .nodes = parser.nodes.toOwnedSlice(),
        .extra_data = parser.extra_data.toOwnedSlice(gpa),
        .errors = parser.errors.toOwnedSlice(gpa),
    };
}

const null_node: Node.Index = 0;

/// Represents in-progress parsing, will be converted to an ast.Tree after completion.
const Parser = struct {
    gpa: *Allocator,
    source: []const u8,
    token_tags: []const Token.Tag,
    token_starts: []const ast.ByteOffset,
    tok_i: TokenIndex,
    errors: std.ArrayListUnmanaged(AstError),
    nodes: ast.NodeList,
    extra_data: std.ArrayListUnmanaged(Node.Index),

    const SmallSpan = union(enum) {
        zero_or_one: Node.Index,
        multi: []Node.Index,

        fn deinit(self: SmallSpan, gpa: *Allocator) void {
            switch (self) {
                .zero_or_one => {},
                .multi => |list| gpa.free(list),
            }
        }
    };

    const Members = struct {
        len: usize,
        lhs: Node.Index,
        rhs: Node.Index,
        trailing_comma: bool,

        fn toSpan(self: Members, p: *Parser) !Node.SubRange {
            if (self.len <= 2) {
                const nodes = [2]Node.Index{ self.lhs, self.rhs };
                return p.listToSpan(nodes[0..self.len]);
            } else {
                return Node.SubRange{ .start = self.lhs, .end = self.rhs };
            }
        }
    };

    fn listToSpan(p: *Parser, list: []const Node.Index) !Node.SubRange {
        try p.extra_data.appendSlice(p.gpa, list);
        return Node.SubRange{
            .start = @intCast(Node.Index, p.extra_data.items.len - list.len),
            .end = @intCast(Node.Index, p.extra_data.items.len),
        };
    }

    fn addNode(p: *Parser, elem: ast.NodeList.Elem) Allocator.Error!Node.Index {
        const result = @intCast(Node.Index, p.nodes.len);
        try p.nodes.append(p.gpa, elem);
        return result;
    }

    fn addExtra(p: *Parser, extra: anytype) Allocator.Error!Node.Index {
        const fields = std.meta.fields(@TypeOf(extra));
        try p.extra_data.ensureCapacity(p.gpa, p.extra_data.items.len + fields.len);
        const result = @intCast(u32, p.extra_data.items.len);
        inline for (fields) |field| {
            comptime assert(field.field_type == Node.Index);
            p.extra_data.appendAssumeCapacity(@field(extra, field.name));
        }
        return result;
    }

    fn warn(p: *Parser, msg: ast.Error) error{OutOfMemory}!void {
        @setCold(true);
        try p.errors.append(p.gpa, msg);
    }

    fn fail(p: *Parser, msg: ast.Error) error{ ParseError, OutOfMemory } {
        @setCold(true);
        try p.warn(msg);
        return error.ParseError;
    }

    /// ContainerMembers
    ///     <- TestDecl ContainerMembers
    ///      / TopLevelComptime ContainerMembers
    ///      / KEYWORD_pub? TopLevelDecl ContainerMembers
    ///      / ContainerField COMMA ContainerMembers
    ///      / ContainerField
    ///      /
    /// TopLevelComptime <- KEYWORD_comptime BlockExpr
    fn parseContainerMembers(p: *Parser) !Members {
        var list = std.ArrayList(Node.Index).init(p.gpa);
        defer list.deinit();

        var field_state: union(enum) {
            /// No fields have been seen.
            none,
            /// Currently parsing fields.
            seen,
            /// Saw fields and then a declaration after them.
            /// Payload is first token of previous declaration.
            end: Node.Index,
            /// There was a declaration between fields, don't report more errors.
            err,
        } = .none;

        // Skip container doc comments.
        while (p.eatToken(.ContainerDocComment)) |_| {}

        var trailing_comma = false;
        while (true) {
            const doc_comment = p.eatDocComments();

            switch (p.token_tags[p.tok_i]) {
                .Keyword_test => {
                    const test_decl_node = try p.expectTestDeclRecoverable();
                    if (test_decl_node != 0) {
                        if (field_state == .seen) {
                            field_state = .{ .end = test_decl_node };
                        }
                        try list.append(test_decl_node);
                    }
                    trailing_comma = false;
                },
                .Keyword_comptime => switch (p.token_tags[p.tok_i + 1]) {
                    .Identifier => {
                        p.tok_i += 1;
                        const container_field = try p.expectContainerFieldRecoverable();
                        if (container_field != 0) {
                            switch (field_state) {
                                .none => field_state = .seen,
                                .err, .seen => {},
                                .end => |node| {
                                    try p.warn(.{
                                        .DeclBetweenFields = .{ .token = p.nodes.items(.main_token)[node] },
                                    });
                                    // Continue parsing; error will be reported later.
                                    field_state = .err;
                                },
                            }
                            try list.append(container_field);
                            switch (p.token_tags[p.tok_i]) {
                                .Comma => {
                                    p.tok_i += 1;
                                    trailing_comma = true;
                                    continue;
                                },
                                .RBrace, .Eof => {
                                    trailing_comma = false;
                                    break;
                                },
                                else => {},
                            }
                            // There is not allowed to be a decl after a field with no comma.
                            // Report error but recover parser.
                            try p.warn(.{
                                .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                            });
                            p.findNextContainerMember();
                        }
                    },
                    .LBrace => {
                        const comptime_token = p.nextToken();
                        const block = p.parseBlock() catch |err| switch (err) {
                            error.OutOfMemory => return error.OutOfMemory,
                            error.ParseError => blk: {
                                p.findNextContainerMember();
                                break :blk null_node;
                            },
                        };
                        if (block != 0) {
                            const comptime_node = try p.addNode(.{
                                .tag = .Comptime,
                                .main_token = comptime_token,
                                .data = .{
                                    .lhs = block,
                                    .rhs = undefined,
                                },
                            });
                            if (field_state == .seen) {
                                field_state = .{ .end = comptime_node };
                            }
                            try list.append(comptime_node);
                        }
                        trailing_comma = false;
                    },
                    else => {
                        p.tok_i += 1;
                        try p.warn(.{ .ExpectedBlockOrField = .{ .token = p.tok_i } });
                    },
                },
                .Keyword_pub => {
                    p.tok_i += 1;
                    const top_level_decl = try p.expectTopLevelDeclRecoverable();
                    if (top_level_decl != 0) {
                        if (field_state == .seen) {
                            field_state = .{ .end = top_level_decl };
                        }
                        try list.append(top_level_decl);
                    }
                    trailing_comma = false;
                },
                .Keyword_usingnamespace => {
                    const node = try p.expectUsingNamespaceRecoverable();
                    if (node != 0) {
                        if (field_state == .seen) {
                            field_state = .{ .end = node };
                        }
                        try list.append(node);
                    }
                    trailing_comma = false;
                },
                .Keyword_const,
                .Keyword_var,
                .Keyword_threadlocal,
                .Keyword_export,
                .Keyword_extern,
                .Keyword_inline,
                .Keyword_noinline,
                .Keyword_fn,
                => {
                    const top_level_decl = try p.expectTopLevelDeclRecoverable();
                    if (top_level_decl != 0) {
                        if (field_state == .seen) {
                            field_state = .{ .end = top_level_decl };
                        }
                        try list.append(top_level_decl);
                    }
                    trailing_comma = false;
                },
                .Identifier => {
                    const container_field = try p.expectContainerFieldRecoverable();
                    if (container_field != 0) {
                        switch (field_state) {
                            .none => field_state = .seen,
                            .err, .seen => {},
                            .end => |node| {
                                try p.warn(.{
                                    .DeclBetweenFields = .{ .token = p.nodes.items(.main_token)[node] },
                                });
                                // Continue parsing; error will be reported later.
                                field_state = .err;
                            },
                        }
                        try list.append(container_field);
                        switch (p.token_tags[p.tok_i]) {
                            .Comma => {
                                p.tok_i += 1;
                                trailing_comma = true;
                                continue;
                            },
                            .RBrace, .Eof => {
                                trailing_comma = false;
                                break;
                            },
                            else => {},
                        }
                        // There is not allowed to be a decl after a field with no comma.
                        // Report error but recover parser.
                        try p.warn(.{
                            .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                        });
                        p.findNextContainerMember();
                    }
                },
                .Eof, .RBrace => {
                    if (doc_comment) |tok| {
                        try p.warn(.{ .UnattachedDocComment = .{ .token = tok } });
                    }
                    break;
                },
                else => {
                    try p.warn(.{ .ExpectedContainerMembers = .{ .token = p.tok_i } });
                    // This was likely not supposed to end yet; try to find the next declaration.
                    p.findNextContainerMember();
                },
            }
        }

        switch (list.items.len) {
            0 => return Members{
                .len = 0,
                .lhs = 0,
                .rhs = 0,
                .trailing_comma = trailing_comma,
            },
            1 => return Members{
                .len = 1,
                .lhs = list.items[0],
                .rhs = 0,
                .trailing_comma = trailing_comma,
            },
            2 => return Members{
                .len = 2,
                .lhs = list.items[0],
                .rhs = list.items[1],
                .trailing_comma = trailing_comma,
            },
            else => {
                const span = try p.listToSpan(list.items);
                return Members{
                    .len = list.items.len,
                    .lhs = span.start,
                    .rhs = span.end,
                    .trailing_comma = trailing_comma,
                };
            },
        }
    }

    /// Attempts to find next container member by searching for certain tokens
    fn findNextContainerMember(p: *Parser) void {
        var level: u32 = 0;
        while (true) {
            const tok = p.nextToken();
            switch (p.token_tags[tok]) {
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
                        p.tok_i -= 1;
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
                        p.tok_i -= 1;
                        return;
                    }
                    level -= 1;
                },
                .Eof => {
                    p.tok_i -= 1;
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
            switch (p.token_tags[tok]) {
                .LBrace => level += 1,
                .RBrace => {
                    if (level == 0) {
                        p.tok_i -= 1;
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
                    p.tok_i -= 1;
                    return;
                },
                else => {},
            }
        }
    }

    /// TestDecl <- KEYWORD_test STRINGLITERALSINGLE? Block
    fn expectTestDecl(p: *Parser) !Node.Index {
        const test_token = p.assertToken(.Keyword_test);
        const name_token = p.eatToken(.StringLiteral);
        const block_node = try p.parseBlock();
        if (block_node == 0) return p.fail(.{ .ExpectedLBrace = .{ .token = p.tok_i } });
        return p.addNode(.{
            .tag = .TestDecl,
            .main_token = test_token,
            .data = .{
                .lhs = name_token orelse 0,
                .rhs = block_node,
            },
        });
    }

    fn expectTestDeclRecoverable(p: *Parser) error{OutOfMemory}!Node.Index {
        return p.expectTestDecl() catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.ParseError => {
                p.findNextContainerMember();
                return null_node;
            },
        };
    }

    /// TopLevelDecl
    ///     <- (KEYWORD_export / KEYWORD_extern STRINGLITERALSINGLE? / (KEYWORD_inline / KEYWORD_noinline))? FnProto (SEMICOLON / Block)
    ///      / (KEYWORD_export / KEYWORD_extern STRINGLITERALSINGLE?)? KEYWORD_threadlocal? VarDecl
    ///      / KEYWORD_usingnamespace Expr SEMICOLON
    fn expectTopLevelDecl(p: *Parser) !Node.Index {
        const extern_export_inline_token = p.nextToken();
        var expect_fn: bool = false;
        var exported: bool = false;
        switch (p.token_tags[extern_export_inline_token]) {
            .Keyword_extern => _ = p.eatToken(.StringLiteral),
            .Keyword_export => exported = true,
            .Keyword_inline, .Keyword_noinline => expect_fn = true,
            else => p.tok_i -= 1,
        }
        const fn_proto = try p.parseFnProto();
        if (fn_proto != 0) {
            switch (p.token_tags[p.tok_i]) {
                .Semicolon => {
                    const semicolon_token = p.nextToken();
                    try p.parseAppendedDocComment(semicolon_token);
                    return fn_proto;
                },
                .LBrace => {
                    const body_block = try p.parseBlock();
                    assert(body_block != 0);
                    return p.addNode(.{
                        .tag = .FnDecl,
                        .main_token = p.nodes.items(.main_token)[fn_proto],
                        .data = .{
                            .lhs = fn_proto,
                            .rhs = body_block,
                        },
                    });
                },
                else => {
                    // Since parseBlock only return error.ParseError on
                    // a missing '}' we can assume this function was
                    // supposed to end here.
                    try p.warn(.{ .ExpectedSemiOrLBrace = .{ .token = p.tok_i } });
                    return null_node;
                },
            }
        }
        if (expect_fn) {
            try p.warn(.{
                .ExpectedFn = .{ .token = p.tok_i },
            });
            return error.ParseError;
        }

        const thread_local_token = p.eatToken(.Keyword_threadlocal);
        const var_decl = try p.parseVarDecl();
        if (var_decl != 0) {
            const semicolon_token = try p.expectToken(.Semicolon);
            try p.parseAppendedDocComment(semicolon_token);
            return var_decl;
        }
        if (thread_local_token != null) {
            return p.fail(.{ .ExpectedVarDecl = .{ .token = p.tok_i } });
        }

        if (exported) {
            return p.fail(.{ .ExpectedVarDeclOrFn = .{ .token = p.tok_i } });
        }

        return p.expectUsingNamespace();
    }

    fn expectTopLevelDeclRecoverable(p: *Parser) error{OutOfMemory}!Node.Index {
        return p.expectTopLevelDecl() catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.ParseError => {
                p.findNextContainerMember();
                return null_node;
            },
        };
    }

    fn expectUsingNamespace(p: *Parser) !Node.Index {
        const usingnamespace_token = try p.expectToken(.Keyword_usingnamespace);
        const expr = try p.expectExpr();
        const semicolon_token = try p.expectToken(.Semicolon);
        try p.parseAppendedDocComment(semicolon_token);
        return p.addNode(.{
            .tag = .UsingNamespace,
            .main_token = usingnamespace_token,
            .data = .{
                .lhs = expr,
                .rhs = undefined,
            },
        });
    }

    fn expectUsingNamespaceRecoverable(p: *Parser) error{OutOfMemory}!Node.Index {
        return p.expectUsingNamespace() catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.ParseError => {
                p.findNextContainerMember();
                return null_node;
            },
        };
    }

    /// FnProto <- KEYWORD_fn IDENTIFIER? LPAREN ParamDeclList RPAREN ByteAlign? LinkSection? CallConv? EXCLAMATIONMARK? (Keyword_anytype / TypeExpr)
    fn parseFnProto(p: *Parser) !Node.Index {
        const fn_token = p.eatToken(.Keyword_fn) orelse return null_node;
        _ = p.eatToken(.Identifier);
        const params = try p.parseParamDeclList();
        defer params.deinit(p.gpa);
        const align_expr = try p.parseByteAlign();
        const section_expr = try p.parseLinkSection();
        const callconv_expr = try p.parseCallconv();
        const bang_token = p.eatToken(.Bang);

        const return_type_expr = try p.parseTypeExpr();
        if (return_type_expr == 0) {
            // most likely the user forgot to specify the return type.
            // Mark return type as invalid and try to continue.
            try p.warn(.{ .ExpectedReturnType = .{ .token = p.tok_i } });
        }

        if (align_expr == 0 and section_expr == 0 and callconv_expr == 0) {
            switch (params) {
                .zero_or_one => |param| return p.addNode(.{
                    .tag = .FnProtoSimple,
                    .main_token = fn_token,
                    .data = .{
                        .lhs = param,
                        .rhs = return_type_expr,
                    },
                }),
                .multi => |list| {
                    const span = try p.listToSpan(list);
                    return p.addNode(.{
                        .tag = .FnProtoMulti,
                        .main_token = fn_token,
                        .data = .{
                            .lhs = try p.addExtra(Node.SubRange{
                                .start = span.start,
                                .end = span.end,
                            }),
                            .rhs = return_type_expr,
                        },
                    });
                },
            }
        }
        switch (params) {
            .zero_or_one => |param| return p.addNode(.{
                .tag = .FnProtoOne,
                .main_token = fn_token,
                .data = .{
                    .lhs = try p.addExtra(Node.FnProtoOne{
                        .param = param,
                        .align_expr = align_expr,
                        .section_expr = section_expr,
                        .callconv_expr = callconv_expr,
                    }),
                    .rhs = return_type_expr,
                },
            }),
            .multi => |list| {
                const span = try p.listToSpan(list);
                return p.addNode(.{
                    .tag = .FnProto,
                    .main_token = fn_token,
                    .data = .{
                        .lhs = try p.addExtra(Node.FnProto{
                            .params_start = span.start,
                            .params_end = span.end,
                            .align_expr = align_expr,
                            .section_expr = section_expr,
                            .callconv_expr = callconv_expr,
                        }),
                        .rhs = return_type_expr,
                    },
                });
            },
        }
    }

    /// VarDecl <- (KEYWORD_const / KEYWORD_var) IDENTIFIER (COLON TypeExpr)? ByteAlign? LinkSection? (EQUAL Expr)? SEMICOLON
    fn parseVarDecl(p: *Parser) !Node.Index {
        const mut_token = p.eatToken(.Keyword_const) orelse
            p.eatToken(.Keyword_var) orelse
            return null_node;

        _ = try p.expectToken(.Identifier);
        const type_node: Node.Index = if (p.eatToken(.Colon) == null) 0 else try p.expectTypeExpr();
        const align_node = try p.parseByteAlign();
        const section_node = try p.parseLinkSection();
        const init_node: Node.Index = if (p.eatToken(.Equal) == null) 0 else try p.expectExpr();
        if (section_node == 0) {
            if (align_node == 0) {
                return p.addNode(.{
                    .tag = .SimpleVarDecl,
                    .main_token = mut_token,
                    .data = .{
                        .lhs = type_node,
                        .rhs = init_node,
                    },
                });
            } else if (type_node == 0) {
                return p.addNode(.{
                    .tag = .AlignedVarDecl,
                    .main_token = mut_token,
                    .data = .{
                        .lhs = align_node,
                        .rhs = init_node,
                    },
                });
            } else {
                return p.addNode(.{
                    .tag = .LocalVarDecl,
                    .main_token = mut_token,
                    .data = .{
                        .lhs = try p.addExtra(Node.LocalVarDecl{
                            .type_node = type_node,
                            .align_node = align_node,
                        }),
                        .rhs = init_node,
                    },
                });
            }
        } else {
            return p.addNode(.{
                .tag = .GlobalVarDecl,
                .main_token = mut_token,
                .data = .{
                    .lhs = try p.addExtra(Node.GlobalVarDecl{
                        .type_node = type_node,
                        .align_node = align_node,
                        .section_node = section_node,
                    }),
                    .rhs = init_node,
                },
            });
        }
    }

    /// ContainerField <- KEYWORD_comptime? IDENTIFIER (COLON TypeExpr ByteAlign?)? (EQUAL Expr)?
    fn expectContainerField(p: *Parser) !Node.Index {
        const comptime_token = p.eatToken(.Keyword_comptime);
        const name_token = p.assertToken(.Identifier);

        var align_expr: Node.Index = 0;
        var type_expr: Node.Index = 0;
        if (p.eatToken(.Colon)) |_| {
            if (p.eatToken(.Keyword_anytype)) |anytype_tok| {
                type_expr = try p.addNode(.{
                    .tag = .AnyType,
                    .main_token = anytype_tok,
                    .data = .{
                        .lhs = undefined,
                        .rhs = undefined,
                    },
                });
            } else {
                type_expr = try p.expectTypeExpr();
                align_expr = try p.parseByteAlign();
            }
        }

        const value_expr: Node.Index = if (p.eatToken(.Equal) == null) 0 else try p.expectExpr();

        if (align_expr == 0) {
            return p.addNode(.{
                .tag = .ContainerFieldInit,
                .main_token = name_token,
                .data = .{
                    .lhs = type_expr,
                    .rhs = value_expr,
                },
            });
        } else if (value_expr == 0) {
            return p.addNode(.{
                .tag = .ContainerFieldAlign,
                .main_token = name_token,
                .data = .{
                    .lhs = type_expr,
                    .rhs = align_expr,
                },
            });
        } else {
            return p.addNode(.{
                .tag = .ContainerField,
                .main_token = name_token,
                .data = .{
                    .lhs = type_expr,
                    .rhs = try p.addExtra(Node.ContainerField{
                        .value_expr = value_expr,
                        .align_expr = align_expr,
                    }),
                },
            });
        }
    }

    fn expectContainerFieldRecoverable(p: *Parser) error{OutOfMemory}!Node.Index {
        return p.expectContainerField() catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.ParseError => {
                p.findNextContainerMember();
                return null_node;
            },
        };
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
    fn parseStatement(p: *Parser) Error!Node.Index {
        const comptime_token = p.eatToken(.Keyword_comptime);

        const var_decl = try p.parseVarDecl();
        if (var_decl != 0) {
            _ = try p.expectTokenRecoverable(.Semicolon);
            return var_decl;
        }

        if (comptime_token) |token| {
            return p.addNode(.{
                .tag = .Comptime,
                .main_token = token,
                .data = .{
                    .lhs = try p.expectBlockExprStatement(),
                    .rhs = undefined,
                },
            });
        }

        switch (p.token_tags[p.tok_i]) {
            .Keyword_nosuspend => {
                return p.addNode(.{
                    .tag = .Nosuspend,
                    .main_token = p.nextToken(),
                    .data = .{
                        .lhs = try p.expectBlockExprStatement(),
                        .rhs = undefined,
                    },
                });
            },
            .Keyword_suspend => {
                const token = p.nextToken();
                const block_expr: Node.Index = if (p.eatToken(.Semicolon) != null)
                    0
                else
                    try p.expectBlockExprStatement();
                return p.addNode(.{
                    .tag = .Suspend,
                    .main_token = token,
                    .data = .{
                        .lhs = block_expr,
                        .rhs = undefined,
                    },
                });
            },
            .Keyword_defer => return p.addNode(.{
                .tag = .Defer,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = undefined,
                    .rhs = try p.expectBlockExprStatement(),
                },
            }),
            .Keyword_errdefer => return p.addNode(.{
                .tag = .ErrDefer,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = try p.parsePayload(),
                    .rhs = try p.expectBlockExprStatement(),
                },
            }),
            .Keyword_switch => return p.expectSwitchExpr(),
            .Keyword_if => return p.expectIfStatement(),
            else => {},
        }

        const labeled_statement = try p.parseLabeledStatement();
        if (labeled_statement != 0) return labeled_statement;

        const assign_expr = try p.parseAssignExpr();
        if (assign_expr != 0) {
            _ = try p.expectTokenRecoverable(.Semicolon);
            return assign_expr;
        }

        return null_node;
    }

    fn expectStatement(p: *Parser) !Node.Index {
        const statement = try p.parseStatement();
        if (statement == 0) {
            return p.fail(.{ .InvalidToken = .{ .token = p.tok_i } });
        }
        return statement;
    }

    /// If a parse error occurs, reports an error, but then finds the next statement
    /// and returns that one instead. If a parse error occurs but there is no following
    /// statement, returns 0.
    fn expectStatementRecoverable(p: *Parser) error{OutOfMemory}!Node.Index {
        while (true) {
            return p.expectStatement() catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.ParseError => {
                    p.findNextStmt(); // Try to skip to the next statement.
                    if (p.token_tags[p.tok_i] == .RBrace) return null_node;
                    continue;
                },
            };
        }
    }

    /// IfStatement
    ///     <- IfPrefix BlockExpr ( KEYWORD_else Payload? Statement )?
    ///      / IfPrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
    fn expectIfStatement(p: *Parser) !Node.Index {
        const if_token = p.assertToken(.Keyword_if);
        _ = try p.expectToken(.LParen);
        const condition = try p.expectExpr();
        _ = try p.expectToken(.RParen);
        const then_payload = try p.parsePtrPayload();

        // TODO propose to change the syntax so that semicolons are always required
        // inside if statements, even if there is an `else`.
        var else_required = false;
        const then_expr = blk: {
            const block_expr = try p.parseBlockExpr();
            if (block_expr != 0) break :blk block_expr;
            const assign_expr = try p.parseAssignExpr();
            if (assign_expr == 0) {
                return p.fail(.{ .ExpectedBlockOrAssignment = .{ .token = p.tok_i } });
            }
            if (p.eatToken(.Semicolon)) |_| {
                return p.addNode(.{
                    .tag = .IfSimple,
                    .main_token = if_token,
                    .data = .{
                        .lhs = condition,
                        .rhs = assign_expr,
                    },
                });
            }
            else_required = true;
            break :blk assign_expr;
        };
        const else_token = p.eatToken(.Keyword_else) orelse {
            if (else_required) {
                return p.fail(.{ .ExpectedSemiOrElse = .{ .token = p.tok_i } });
            }
            return p.addNode(.{
                .tag = .IfSimple,
                .main_token = if_token,
                .data = .{
                    .lhs = condition,
                    .rhs = then_expr,
                },
            });
        };
        const else_payload = try p.parsePayload();
        const else_expr = try p.expectStatement();
        return p.addNode(.{
            .tag = .If,
            .main_token = if_token,
            .data = .{
                .lhs = condition,
                .rhs = try p.addExtra(Node.If{
                    .then_expr = then_expr,
                    .else_expr = else_expr,
                }),
            },
        });
    }

    /// LabeledStatement <- BlockLabel? (Block / LoopStatement)
    fn parseLabeledStatement(p: *Parser) !Node.Index {
        const label_token = p.parseBlockLabel();
        const block = try p.parseBlock();
        if (block != 0) return block;

        const loop_stmt = try p.parseLoopStatement();
        if (loop_stmt != 0) return loop_stmt;

        if (label_token != 0) {
            return p.fail(.{ .ExpectedLabelable = .{ .token = p.tok_i } });
        }

        return null_node;
    }

    /// LoopStatement <- KEYWORD_inline? (ForStatement / WhileStatement)
    fn parseLoopStatement(p: *Parser) !Node.Index {
        const inline_token = p.eatToken(.Keyword_inline);

        const for_statement = try p.parseForStatement();
        if (for_statement != 0) return for_statement;

        const while_statement = try p.parseWhileStatement();
        if (while_statement != 0) return while_statement;

        if (inline_token == null) return null_node;

        // If we've seen "inline", there should have been a "for" or "while"
        return p.fail(.{ .ExpectedInlinable = .{ .token = p.tok_i } });
    }

    /// ForPrefix <- KEYWORD_for LPAREN Expr RPAREN PtrIndexPayload
    /// ForStatement
    ///     <- ForPrefix BlockExpr ( KEYWORD_else Statement )?
    ///      / ForPrefix AssignExpr ( SEMICOLON / KEYWORD_else Statement )
    fn parseForStatement(p: *Parser) !Node.Index {
        const for_token = p.eatToken(.Keyword_for) orelse return null_node;
        _ = try p.expectToken(.LParen);
        const array_expr = try p.expectExpr();
        _ = try p.expectToken(.RParen);
        _ = try p.parsePtrIndexPayload();

        // TODO propose to change the syntax so that semicolons are always required
        // inside while statements, even if there is an `else`.
        var else_required = false;
        const then_expr = blk: {
            const block_expr = try p.parseBlockExpr();
            if (block_expr != 0) break :blk block_expr;
            const assign_expr = try p.parseAssignExpr();
            if (assign_expr == 0) {
                return p.fail(.{ .ExpectedBlockOrAssignment = .{ .token = p.tok_i } });
            }
            if (p.eatToken(.Semicolon)) |_| {
                return p.addNode(.{
                    .tag = .ForSimple,
                    .main_token = for_token,
                    .data = .{
                        .lhs = array_expr,
                        .rhs = assign_expr,
                    },
                });
            }
            else_required = true;
            break :blk assign_expr;
        };
        const else_token = p.eatToken(.Keyword_else) orelse {
            if (else_required) {
                return p.fail(.{ .ExpectedSemiOrElse = .{ .token = p.tok_i } });
            }
            return p.addNode(.{
                .tag = .ForSimple,
                .main_token = for_token,
                .data = .{
                    .lhs = array_expr,
                    .rhs = then_expr,
                },
            });
        };
        return p.addNode(.{
            .tag = .For,
            .main_token = for_token,
            .data = .{
                .lhs = array_expr,
                .rhs = try p.addExtra(Node.If{
                    .then_expr = then_expr,
                    .else_expr = try p.expectStatement(),
                }),
            },
        });
    }

    /// WhilePrefix <- KEYWORD_while LPAREN Expr RPAREN PtrPayload? WhileContinueExpr?
    /// WhileStatement
    ///     <- WhilePrefix BlockExpr ( KEYWORD_else Payload? Statement )?
    ///      / WhilePrefix AssignExpr ( SEMICOLON / KEYWORD_else Payload? Statement )
    fn parseWhileStatement(p: *Parser) !Node.Index {
        const while_token = p.eatToken(.Keyword_while) orelse return null_node;
        _ = try p.expectToken(.LParen);
        const condition = try p.expectExpr();
        _ = try p.expectToken(.RParen);
        const then_payload = try p.parsePtrPayload();
        const cont_expr = try p.parseWhileContinueExpr();

        // TODO propose to change the syntax so that semicolons are always required
        // inside while statements, even if there is an `else`.
        var else_required = false;
        const then_expr = blk: {
            const block_expr = try p.parseBlockExpr();
            if (block_expr != 0) break :blk block_expr;
            const assign_expr = try p.parseAssignExpr();
            if (assign_expr == 0) {
                return p.fail(.{ .ExpectedBlockOrAssignment = .{ .token = p.tok_i } });
            }
            if (p.eatToken(.Semicolon)) |_| {
                if (cont_expr == 0) {
                    return p.addNode(.{
                        .tag = .WhileSimple,
                        .main_token = while_token,
                        .data = .{
                            .lhs = condition,
                            .rhs = assign_expr,
                        },
                    });
                } else {
                    return p.addNode(.{
                        .tag = .WhileCont,
                        .main_token = while_token,
                        .data = .{
                            .lhs = condition,
                            .rhs = try p.addExtra(Node.WhileCont{
                                .cont_expr = cont_expr,
                                .then_expr = assign_expr,
                            }),
                        },
                    });
                }
            }
            else_required = true;
            break :blk assign_expr;
        };
        const else_token = p.eatToken(.Keyword_else) orelse {
            if (else_required) {
                return p.fail(.{ .ExpectedSemiOrElse = .{ .token = p.tok_i } });
            }
            if (cont_expr == 0) {
                return p.addNode(.{
                    .tag = .WhileSimple,
                    .main_token = while_token,
                    .data = .{
                        .lhs = condition,
                        .rhs = then_expr,
                    },
                });
            } else {
                return p.addNode(.{
                    .tag = .WhileCont,
                    .main_token = while_token,
                    .data = .{
                        .lhs = condition,
                        .rhs = try p.addExtra(Node.WhileCont{
                            .cont_expr = cont_expr,
                            .then_expr = then_expr,
                        }),
                    },
                });
            }
        };
        const else_payload = try p.parsePayload();
        const else_expr = try p.expectStatement();
        return p.addNode(.{
            .tag = .While,
            .main_token = while_token,
            .data = .{
                .lhs = condition,
                .rhs = try p.addExtra(Node.While{
                    .cont_expr = cont_expr,
                    .then_expr = then_expr,
                    .else_expr = else_expr,
                }),
            },
        });
    }

    /// BlockExprStatement
    ///     <- BlockExpr
    ///      / AssignExpr SEMICOLON
    fn parseBlockExprStatement(p: *Parser) !Node.Index {
        const block_expr = try p.parseBlockExpr();
        if (block_expr != 0) {
            return block_expr;
        }
        const assign_expr = try p.parseAssignExpr();
        if (assign_expr != 0) {
            _ = try p.expectTokenRecoverable(.Semicolon);
            return assign_expr;
        }
        return null_node;
    }

    fn expectBlockExprStatement(p: *Parser) !Node.Index {
        const node = try p.parseBlockExprStatement();
        if (node == 0) {
            return p.fail(.{ .ExpectedBlockOrExpression = .{ .token = p.tok_i } });
        }
        return node;
    }

    /// BlockExpr <- BlockLabel? Block
    fn parseBlockExpr(p: *Parser) Error!Node.Index {
        switch (p.token_tags[p.tok_i]) {
            .Identifier => {
                if (p.token_tags[p.tok_i + 1] == .Colon and
                    p.token_tags[p.tok_i + 2] == .LBrace)
                {
                    p.tok_i += 2;
                    return p.parseBlock();
                } else {
                    return null_node;
                }
            },
            .LBrace => return p.parseBlock(),
            else => return null_node,
        }
    }

    /// AssignExpr <- Expr (AssignOp Expr)?
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
    fn parseAssignExpr(p: *Parser) !Node.Index {
        const expr = try p.parseExpr();
        if (expr == 0) return null_node;

        const tag: Node.Tag = switch (p.token_tags[p.tok_i]) {
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
            else => return expr,
        };
        return p.addNode(.{
            .tag = tag,
            .main_token = p.nextToken(),
            .data = .{
                .lhs = expr,
                .rhs = try p.expectExpr(),
            },
        });
    }

    fn expectAssignExpr(p: *Parser) !Node.Index {
        const expr = try p.parseAssignExpr();
        if (expr == 0) {
            return p.fail(.{ .ExpectedExprOrAssignment = .{ .token = p.tok_i } });
        }
        return expr;
    }

    /// Expr <- BoolOrExpr
    fn parseExpr(p: *Parser) Error!Node.Index {
        return p.parseBoolOrExpr();
    }

    fn expectExpr(p: *Parser) Error!Node.Index {
        const node = try p.parseExpr();
        if (node == 0) {
            return p.fail(.{ .ExpectedExpr = .{ .token = p.tok_i } });
        } else {
            return node;
        }
    }

    /// BoolOrExpr <- BoolAndExpr (KEYWORD_or BoolAndExpr)*
    fn parseBoolOrExpr(p: *Parser) Error!Node.Index {
        var res = try p.parseBoolAndExpr();
        if (res == 0) return null_node;

        while (true) {
            switch (p.token_tags[p.tok_i]) {
                .Keyword_or => {
                    const or_token = p.nextToken();
                    const rhs = try p.parseBoolAndExpr();
                    if (rhs == 0) {
                        return p.fail(.{ .InvalidToken = .{ .token = p.tok_i } });
                    }
                    res = try p.addNode(.{
                        .tag = .BoolOr,
                        .main_token = or_token,
                        .data = .{
                            .lhs = res,
                            .rhs = rhs,
                        },
                    });
                },
                else => return res,
            }
        }
    }

    /// BoolAndExpr <- CompareExpr (KEYWORD_and CompareExpr)*
    fn parseBoolAndExpr(p: *Parser) !Node.Index {
        var res = try p.parseCompareExpr();
        if (res == 0) return null_node;

        while (true) {
            switch (p.token_tags[p.tok_i]) {
                .Keyword_and => {
                    const and_token = p.nextToken();
                    const rhs = try p.parseCompareExpr();
                    if (rhs == 0) {
                        return p.fail(.{ .InvalidToken = .{ .token = p.tok_i } });
                    }
                    res = try p.addNode(.{
                        .tag = .BoolAnd,
                        .main_token = and_token,
                        .data = .{
                            .lhs = res,
                            .rhs = rhs,
                        },
                    });
                },
                else => return res,
            }
        }
    }

    /// CompareExpr <- BitwiseExpr (CompareOp BitwiseExpr)?
    /// CompareOp
    ///     <- EQUALEQUAL
    ///      / EXCLAMATIONMARKEQUAL
    ///      / LARROW
    ///      / RARROW
    ///      / LARROWEQUAL
    ///      / RARROWEQUAL
    fn parseCompareExpr(p: *Parser) !Node.Index {
        const expr = try p.parseBitwiseExpr();
        if (expr == 0) return null_node;

        const tag: Node.Tag = switch (p.token_tags[p.tok_i]) {
            .EqualEqual => .EqualEqual,
            .BangEqual => .BangEqual,
            .AngleBracketLeft => .LessThan,
            .AngleBracketRight => .GreaterThan,
            .AngleBracketLeftEqual => .LessOrEqual,
            .AngleBracketRightEqual => .GreaterOrEqual,
            else => return expr,
        };
        return p.addNode(.{
            .tag = tag,
            .main_token = p.nextToken(),
            .data = .{
                .lhs = expr,
                .rhs = try p.expectBitwiseExpr(),
            },
        });
    }

    /// BitwiseExpr <- BitShiftExpr (BitwiseOp BitShiftExpr)*
    /// BitwiseOp
    ///     <- AMPERSAND
    ///      / CARET
    ///      / PIPE
    ///      / KEYWORD_orelse
    ///      / KEYWORD_catch Payload?
    fn parseBitwiseExpr(p: *Parser) !Node.Index {
        var res = try p.parseBitShiftExpr();
        if (res == 0) return null_node;

        while (true) {
            const tag: Node.Tag = switch (p.token_tags[p.tok_i]) {
                .Ampersand => .BitAnd,
                .Caret => .BitXor,
                .Pipe => .BitOr,
                .Keyword_orelse => .OrElse,
                .Keyword_catch => {
                    const catch_token = p.nextToken();
                    _ = try p.parsePayload();
                    const rhs = try p.parseBitShiftExpr();
                    if (rhs == 0) {
                        return p.fail(.{ .InvalidToken = .{ .token = p.tok_i } });
                    }
                    res = try p.addNode(.{
                        .tag = .Catch,
                        .main_token = catch_token,
                        .data = .{
                            .lhs = res,
                            .rhs = rhs,
                        },
                    });
                    continue;
                },
                else => return res,
            };
            res = try p.addNode(.{
                .tag = tag,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = res,
                    .rhs = try p.expectBitShiftExpr(),
                },
            });
        }
    }

    fn expectBitwiseExpr(p: *Parser) Error!Node.Index {
        const node = try p.parseBitwiseExpr();
        if (node == 0) {
            return p.fail(.{ .InvalidToken = .{ .token = p.tok_i } });
        } else {
            return node;
        }
    }

    /// BitShiftExpr <- AdditionExpr (BitShiftOp AdditionExpr)*
    /// BitShiftOp
    ///     <- LARROW2
    ///      / RARROW2
    fn parseBitShiftExpr(p: *Parser) Error!Node.Index {
        var res = try p.parseAdditionExpr();
        if (res == 0) return null_node;

        while (true) {
            const tag: Node.Tag = switch (p.token_tags[p.tok_i]) {
                .AngleBracketAngleBracketLeft => .BitShiftLeft,
                .AngleBracketAngleBracketRight => .BitShiftRight,
                else => return res,
            };
            res = try p.addNode(.{
                .tag = tag,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = res,
                    .rhs = try p.expectAdditionExpr(),
                },
            });
        }
    }

    fn expectBitShiftExpr(p: *Parser) Error!Node.Index {
        const node = try p.parseBitShiftExpr();
        if (node == 0) {
            return p.fail(.{ .InvalidToken = .{ .token = p.tok_i } });
        } else {
            return node;
        }
    }

    /// AdditionExpr <- MultiplyExpr (AdditionOp MultiplyExpr)*
    /// AdditionOp
    ///     <- PLUS
    ///      / MINUS
    ///      / PLUS2
    ///      / PLUSPERCENT
    ///      / MINUSPERCENT
    fn parseAdditionExpr(p: *Parser) Error!Node.Index {
        var res = try p.parseMultiplyExpr();
        if (res == 0) return null_node;

        while (true) {
            const tag: Node.Tag = switch (p.token_tags[p.tok_i]) {
                .Plus => .Add,
                .Minus => .Sub,
                .PlusPlus => .ArrayCat,
                .PlusPercent => .AddWrap,
                .MinusPercent => .SubWrap,
                else => return res,
            };
            res = try p.addNode(.{
                .tag = tag,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = res,
                    .rhs = try p.expectMultiplyExpr(),
                },
            });
        }
    }

    fn expectAdditionExpr(p: *Parser) Error!Node.Index {
        const node = try p.parseAdditionExpr();
        if (node == 0) {
            return p.fail(.{ .InvalidToken = .{ .token = p.tok_i } });
        }
        return node;
    }

    /// MultiplyExpr <- PrefixExpr (MultiplyOp PrefixExpr)*
    /// MultiplyOp
    ///     <- PIPE2
    ///      / ASTERISK
    ///      / SLASH
    ///      / PERCENT
    ///      / ASTERISK2
    ///      / ASTERISKPERCENT
    fn parseMultiplyExpr(p: *Parser) Error!Node.Index {
        var res = try p.parsePrefixExpr();
        if (res == 0) return null_node;

        while (true) {
            const tag: Node.Tag = switch (p.token_tags[p.tok_i]) {
                .PipePipe => .MergeErrorSets,
                .Asterisk => .Mul,
                .Slash => .Div,
                .Percent => .Mod,
                .AsteriskAsterisk => .ArrayMult,
                .AsteriskPercent => .MulWrap,
                else => return res,
            };
            res = try p.addNode(.{
                .tag = tag,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = res,
                    .rhs = try p.expectPrefixExpr(),
                },
            });
        }
    }

    fn expectMultiplyExpr(p: *Parser) Error!Node.Index {
        const node = try p.parseMultiplyExpr();
        if (node == 0) {
            return p.fail(.{ .InvalidToken = .{ .token = p.tok_i } });
        }
        return node;
    }

    /// PrefixExpr <- PrefixOp* PrimaryExpr
    /// PrefixOp
    ///     <- EXCLAMATIONMARK
    ///      / MINUS
    ///      / TILDE
    ///      / MINUSPERCENT
    ///      / AMPERSAND
    ///      / KEYWORD_try
    ///      / KEYWORD_await
    fn parsePrefixExpr(p: *Parser) Error!Node.Index {
        const tag: Node.Tag = switch (p.token_tags[p.tok_i]) {
            .Bang => .BoolNot,
            .Minus => .Negation,
            .Tilde => .BitNot,
            .MinusPercent => .NegationWrap,
            .Ampersand => .AddressOf,
            .Keyword_try => .Try,
            .Keyword_await => .Await,
            else => return p.parsePrimaryExpr(),
        };
        return p.addNode(.{
            .tag = tag,
            .main_token = p.nextToken(),
            .data = .{
                .lhs = try p.expectPrefixExpr(),
                .rhs = undefined,
            },
        });
    }

    fn expectPrefixExpr(p: *Parser) Error!Node.Index {
        const node = try p.parsePrefixExpr();
        if (node == 0) {
            return p.fail(.{ .ExpectedPrefixExpr = .{ .token = p.tok_i } });
        }
        return node;
    }

    /// TypeExpr <- PrefixTypeOp* ErrorUnionExpr
    /// PrefixTypeOp
    ///     <- QUESTIONMARK
    ///      / KEYWORD_anyframe MINUSRARROW
    ///      / ArrayTypeStart (ByteAlign / KEYWORD_const / KEYWORD_volatile / KEYWORD_allowzero)*
    ///      / PtrTypeStart (KEYWORD_align LPAREN Expr (COLON INTEGER COLON INTEGER)? RPAREN / KEYWORD_const / KEYWORD_volatile / KEYWORD_allowzero)*
    /// PtrTypeStart
    ///     <- ASTERISK
    ///      / ASTERISK2
    ///      / LBRACKET ASTERISK (LETTERC / COLON Expr)? RBRACKET
    /// ArrayTypeStart <- LBRACKET Expr? (COLON Expr)? RBRACKET
    fn parseTypeExpr(p: *Parser) Error!Node.Index {
        switch (p.token_tags[p.tok_i]) {
            .QuestionMark => return p.addNode(.{
                .tag = .OptionalType,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = try p.expectTypeExpr(),
                    .rhs = undefined,
                },
            }),
            .Keyword_anyframe => switch (p.token_tags[p.tok_i + 1]) {
                .Arrow => return p.addNode(.{
                    .tag = .AnyFrameType,
                    .main_token = p.nextToken(),
                    .data = .{
                        .lhs = p.nextToken(),
                        .rhs = try p.expectTypeExpr(),
                    },
                }),
                else => return p.parseErrorUnionExpr(),
            },
            .Asterisk => {
                const asterisk = p.nextToken();
                const mods = try p.parsePtrModifiers();
                const elem_type = try p.expectTypeExpr();
                if (mods.bit_range_start == 0) {
                    return p.addNode(.{
                        .tag = .PtrTypeAligned,
                        .main_token = asterisk,
                        .data = .{
                            .lhs = mods.align_node,
                            .rhs = elem_type,
                        },
                    });
                } else {
                    return p.addNode(.{
                        .tag = .PtrTypeBitRange,
                        .main_token = asterisk,
                        .data = .{
                            .lhs = try p.addExtra(Node.PtrTypeBitRange{
                                .sentinel = 0,
                                .align_node = mods.align_node,
                                .bit_range_start = mods.bit_range_start,
                                .bit_range_end = mods.bit_range_end,
                            }),
                            .rhs = elem_type,
                        },
                    });
                }
            },
            .AsteriskAsterisk => {
                const asterisk = p.nextToken();
                const mods = try p.parsePtrModifiers();
                const elem_type = try p.expectTypeExpr();
                const inner: Node.Index = inner: {
                    if (mods.bit_range_start == 0) {
                        break :inner try p.addNode(.{
                            .tag = .PtrTypeAligned,
                            .main_token = asterisk,
                            .data = .{
                                .lhs = mods.align_node,
                                .rhs = elem_type,
                            },
                        });
                    } else {
                        break :inner try p.addNode(.{
                            .tag = .PtrTypeBitRange,
                            .main_token = asterisk,
                            .data = .{
                                .lhs = try p.addExtra(Node.PtrTypeBitRange{
                                    .sentinel = 0,
                                    .align_node = mods.align_node,
                                    .bit_range_start = mods.bit_range_start,
                                    .bit_range_end = mods.bit_range_end,
                                }),
                                .rhs = elem_type,
                            },
                        });
                    }
                };
                return p.addNode(.{
                    .tag = .PtrTypeAligned,
                    .main_token = asterisk,
                    .data = .{
                        .lhs = 0,
                        .rhs = inner,
                    },
                });
            },
            .LBracket => switch (p.token_tags[p.tok_i + 1]) {
                .Asterisk => {
                    const lbracket = p.nextToken();
                    const asterisk = p.nextToken();
                    var sentinel: Node.Index = 0;
                    prefix: {
                        if (p.eatToken(.Identifier)) |ident| {
                            const token_slice = p.source[p.token_starts[ident]..][0..2];
                            if (!std.mem.eql(u8, token_slice, "c]")) {
                                p.tok_i -= 1;
                            } else {
                                break :prefix;
                            }
                        }
                        if (p.eatToken(.Colon)) |_| {
                            sentinel = try p.expectExpr();
                        }
                    }
                    _ = try p.expectToken(.RBracket);
                    const mods = try p.parsePtrModifiers();
                    const elem_type = try p.expectTypeExpr();
                    if (mods.bit_range_start == 0) {
                        if (sentinel == 0) {
                            return p.addNode(.{
                                .tag = .PtrTypeAligned,
                                .main_token = asterisk,
                                .data = .{
                                    .lhs = mods.align_node,
                                    .rhs = elem_type,
                                },
                            });
                        } else if (mods.align_node == 0) {
                            return p.addNode(.{
                                .tag = .PtrTypeSentinel,
                                .main_token = asterisk,
                                .data = .{
                                    .lhs = sentinel,
                                    .rhs = elem_type,
                                },
                            });
                        } else {
                            return p.addNode(.{
                                .tag = .PtrType,
                                .main_token = asterisk,
                                .data = .{
                                    .lhs = try p.addExtra(Node.PtrType{
                                        .sentinel = sentinel,
                                        .align_node = mods.align_node,
                                    }),
                                    .rhs = elem_type,
                                },
                            });
                        }
                    } else {
                        return p.addNode(.{
                            .tag = .PtrTypeBitRange,
                            .main_token = asterisk,
                            .data = .{
                                .lhs = try p.addExtra(Node.PtrTypeBitRange{
                                    .sentinel = sentinel,
                                    .align_node = mods.align_node,
                                    .bit_range_start = mods.bit_range_start,
                                    .bit_range_end = mods.bit_range_end,
                                }),
                                .rhs = elem_type,
                            },
                        });
                    }
                },
                else => {
                    const lbracket = p.nextToken();
                    const len_expr = try p.parseExpr();
                    const sentinel: Node.Index = if (p.eatToken(.Colon)) |_|
                        try p.expectExpr()
                    else
                        0;
                    _ = try p.expectToken(.RBracket);
                    const mods = try p.parsePtrModifiers();
                    const elem_type = try p.expectTypeExpr();
                    if (mods.bit_range_start != 0) {
                        @panic("TODO implement this error");
                        //try p.warn(.{
                        //    .BitRangeInvalid = .{ .node = mods.bit_range_start },
                        //});
                    }
                    if (len_expr == 0) {
                        if (sentinel == 0) {
                            return p.addNode(.{
                                .tag = .PtrTypeAligned,
                                .main_token = lbracket,
                                .data = .{
                                    .lhs = mods.align_node,
                                    .rhs = elem_type,
                                },
                            });
                        } else if (mods.align_node == 0) {
                            return p.addNode(.{
                                .tag = .PtrTypeSentinel,
                                .main_token = lbracket,
                                .data = .{
                                    .lhs = sentinel,
                                    .rhs = elem_type,
                                },
                            });
                        } else {
                            return p.addNode(.{
                                .tag = .PtrType,
                                .main_token = lbracket,
                                .data = .{
                                    .lhs = try p.addExtra(Node.PtrType{
                                        .sentinel = sentinel,
                                        .align_node = mods.align_node,
                                    }),
                                    .rhs = elem_type,
                                },
                            });
                        }
                    } else {
                        if (mods.align_node != 0) {
                            @panic("TODO implement this error");
                            //try p.warn(.{
                            //    .AlignInvalid = .{ .node = mods.align_node },
                            //});
                        }
                        if (sentinel == 0) {
                            return p.addNode(.{
                                .tag = .ArrayType,
                                .main_token = lbracket,
                                .data = .{
                                    .lhs = len_expr,
                                    .rhs = elem_type,
                                },
                            });
                        } else {
                            return p.addNode(.{
                                .tag = .ArrayTypeSentinel,
                                .main_token = lbracket,
                                .data = .{
                                    .lhs = len_expr,
                                    .rhs = try p.addExtra(.{
                                        .elem_type = elem_type,
                                        .sentinel = sentinel,
                                    }),
                                },
                            });
                        }
                    }
                },
            },
            else => return p.parseErrorUnionExpr(),
        }
    }

    fn expectTypeExpr(p: *Parser) Error!Node.Index {
        const node = try p.parseTypeExpr();
        if (node == 0) {
            return p.fail(.{ .ExpectedTypeExpr = .{ .token = p.tok_i } });
        }
        return node;
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
    fn parsePrimaryExpr(p: *Parser) !Node.Index {
        switch (p.token_tags[p.tok_i]) {
            .Keyword_asm => return p.expectAsmExpr(),
            .Keyword_if => return p.parseIfExpr(),
            .Keyword_break => {
                p.tok_i += 1;
                return p.addNode(.{
                    .tag = .Break,
                    .main_token = p.tok_i - 1,
                    .data = .{
                        .lhs = try p.parseBreakLabel(),
                        .rhs = try p.parseExpr(),
                    },
                });
            },
            .Keyword_continue => {
                p.tok_i += 1;
                return p.addNode(.{
                    .tag = .Continue,
                    .main_token = p.tok_i - 1,
                    .data = .{
                        .lhs = try p.parseBreakLabel(),
                        .rhs = undefined,
                    },
                });
            },
            .Keyword_comptime => {
                p.tok_i += 1;
                return p.addNode(.{
                    .tag = .Comptime,
                    .main_token = p.tok_i - 1,
                    .data = .{
                        .lhs = try p.expectExpr(),
                        .rhs = undefined,
                    },
                });
            },
            .Keyword_nosuspend => {
                p.tok_i += 1;
                return p.addNode(.{
                    .tag = .Nosuspend,
                    .main_token = p.tok_i - 1,
                    .data = .{
                        .lhs = try p.expectExpr(),
                        .rhs = undefined,
                    },
                });
            },
            .Keyword_resume => {
                p.tok_i += 1;
                return p.addNode(.{
                    .tag = .Resume,
                    .main_token = p.tok_i - 1,
                    .data = .{
                        .lhs = try p.expectExpr(),
                        .rhs = undefined,
                    },
                });
            },
            .Keyword_return => {
                p.tok_i += 1;
                return p.addNode(.{
                    .tag = .Return,
                    .main_token = p.tok_i - 1,
                    .data = .{
                        .lhs = try p.parseExpr(),
                        .rhs = undefined,
                    },
                });
            },
            .Identifier => {
                if (p.token_tags[p.tok_i + 1] == .Colon) {
                    switch (p.token_tags[p.tok_i + 2]) {
                        .Keyword_inline => {
                            p.tok_i += 3;
                            switch (p.token_tags[p.tok_i]) {
                                .Keyword_for => return p.parseForExpr(),
                                .Keyword_while => return p.parseWhileExpr(),
                                else => return p.fail(.{
                                    .ExpectedInlinable = .{ .token = p.tok_i },
                                }),
                            }
                        },
                        .Keyword_for => {
                            p.tok_i += 2;
                            return p.parseForExpr();
                        },
                        .Keyword_while => {
                            p.tok_i += 2;
                            return p.parseWhileExpr();
                        },
                        .LBrace => {
                            p.tok_i += 2;
                            return p.parseBlock();
                        },
                        else => return p.parseCurlySuffixExpr(),
                    }
                } else {
                    return p.parseCurlySuffixExpr();
                }
            },
            .Keyword_inline => {
                p.tok_i += 2;
                switch (p.token_tags[p.tok_i]) {
                    .Keyword_for => return p.parseForExpr(),
                    .Keyword_while => return p.parseWhileExpr(),
                    else => return p.fail(.{
                        .ExpectedInlinable = .{ .token = p.tok_i },
                    }),
                }
            },
            .Keyword_for => return p.parseForExpr(),
            .Keyword_while => return p.parseWhileExpr(),
            .LBrace => return p.parseBlock(),
            else => return p.parseCurlySuffixExpr(),
        }
    }

    /// IfExpr <- IfPrefix Expr (KEYWORD_else Payload? Expr)?
    fn parseIfExpr(p: *Parser) !Node.Index {
        return p.parseIf(parseExpr);
    }

    /// Block <- LBRACE Statement* RBRACE
    fn parseBlock(p: *Parser) !Node.Index {
        const lbrace = p.eatToken(.LBrace) orelse return null_node;

        if (p.eatToken(.RBrace)) |_| {
            return p.addNode(.{
                .tag = .BlockTwo,
                .main_token = lbrace,
                .data = .{
                    .lhs = 0,
                    .rhs = 0,
                },
            });
        }

        const stmt_one = try p.expectStatementRecoverable();
        if (p.eatToken(.RBrace)) |_| {
            const semicolon = p.token_tags[p.tok_i - 2] == .Semicolon;
            return p.addNode(.{
                .tag = if (semicolon) .BlockTwoSemicolon else .BlockTwo,
                .main_token = lbrace,
                .data = .{
                    .lhs = stmt_one,
                    .rhs = 0,
                },
            });
        }
        const stmt_two = try p.expectStatementRecoverable();
        if (p.eatToken(.RBrace)) |_| {
            const semicolon = p.token_tags[p.tok_i - 2] == .Semicolon;
            return p.addNode(.{
                .tag = if (semicolon) .BlockTwoSemicolon else .BlockTwo,
                .main_token = lbrace,
                .data = .{
                    .lhs = stmt_one,
                    .rhs = stmt_two,
                },
            });
        }

        var statements = std.ArrayList(Node.Index).init(p.gpa);
        defer statements.deinit();

        try statements.appendSlice(&[_]Node.Index{ stmt_one, stmt_two });

        while (true) {
            const statement = try p.expectStatementRecoverable();
            if (statement == 0) break;
            try statements.append(statement);
            if (p.token_tags[p.tok_i] == .RBrace) break;
        }
        _ = try p.expectToken(.RBrace);
        const semicolon = p.token_tags[p.tok_i - 2] == .Semicolon;
        const statements_span = try p.listToSpan(statements.items);
        return p.addNode(.{
            .tag = if (semicolon) .BlockSemicolon else .Block,
            .main_token = lbrace,
            .data = .{
                .lhs = statements_span.start,
                .rhs = statements_span.end,
            },
        });
    }

    /// ForPrefix <- KEYWORD_for LPAREN Expr RPAREN PtrIndexPayload
    /// ForExpr <- ForPrefix Expr (KEYWORD_else Expr)?
    fn parseForExpr(p: *Parser) !Node.Index {
        const for_token = p.eatToken(.Keyword_for) orelse return null_node;
        _ = try p.expectToken(.LParen);
        const array_expr = try p.expectExpr();
        _ = try p.expectToken(.RParen);
        _ = try p.parsePtrIndexPayload();

        const then_expr = try p.expectExpr();
        const else_token = p.eatToken(.Keyword_else) orelse {
            return p.addNode(.{
                .tag = .ForSimple,
                .main_token = for_token,
                .data = .{
                    .lhs = array_expr,
                    .rhs = then_expr,
                },
            });
        };
        const else_expr = try p.expectExpr();
        return p.addNode(.{
            .tag = .For,
            .main_token = for_token,
            .data = .{
                .lhs = array_expr,
                .rhs = try p.addExtra(Node.If{
                    .then_expr = then_expr,
                    .else_expr = else_expr,
                }),
            },
        });
    }

    /// WhilePrefix <- KEYWORD_while LPAREN Expr RPAREN PtrPayload? WhileContinueExpr?
    /// WhileExpr <- WhilePrefix Expr (KEYWORD_else Payload? Expr)?
    fn parseWhileExpr(p: *Parser) !Node.Index {
        const while_token = p.eatToken(.Keyword_while) orelse return null_node;
        _ = try p.expectToken(.LParen);
        const condition = try p.expectExpr();
        _ = try p.expectToken(.RParen);
        const then_payload = try p.parsePtrPayload();
        const cont_expr = try p.parseWhileContinueExpr();

        const then_expr = try p.expectExpr();
        const else_token = p.eatToken(.Keyword_else) orelse {
            if (cont_expr == 0) {
                return p.addNode(.{
                    .tag = .WhileSimple,
                    .main_token = while_token,
                    .data = .{
                        .lhs = condition,
                        .rhs = then_expr,
                    },
                });
            } else {
                return p.addNode(.{
                    .tag = .WhileCont,
                    .main_token = while_token,
                    .data = .{
                        .lhs = condition,
                        .rhs = try p.addExtra(Node.WhileCont{
                            .cont_expr = cont_expr,
                            .then_expr = then_expr,
                        }),
                    },
                });
            }
        };
        const else_payload = try p.parsePayload();
        const else_expr = try p.expectExpr();
        return p.addNode(.{
            .tag = .While,
            .main_token = while_token,
            .data = .{
                .lhs = condition,
                .rhs = try p.addExtra(Node.While{
                    .cont_expr = cont_expr,
                    .then_expr = then_expr,
                    .else_expr = else_expr,
                }),
            },
        });
    }

    /// CurlySuffixExpr <- TypeExpr InitList?
    /// InitList
    ///     <- LBRACE FieldInit (COMMA FieldInit)* COMMA? RBRACE
    ///      / LBRACE Expr (COMMA Expr)* COMMA? RBRACE
    ///      / LBRACE RBRACE
    fn parseCurlySuffixExpr(p: *Parser) !Node.Index {
        const lhs = try p.parseTypeExpr();
        if (lhs == 0) return null_node;
        const lbrace = p.eatToken(.LBrace) orelse return lhs;

        // If there are 0 or 1 items, we can use ArrayInitOne/StructInitOne;
        // otherwise we use the full ArrayInit/StructInit.

        if (p.eatToken(.RBrace)) |_| {
            return p.addNode(.{
                .tag = .StructInitOne,
                .main_token = lbrace,
                .data = .{
                    .lhs = lhs,
                    .rhs = 0,
                },
            });
        }
        const field_init = try p.parseFieldInit();
        if (field_init != 0) {
            const comma_one = p.eatToken(.Comma);
            if (p.eatToken(.RBrace)) |_| {
                return p.addNode(.{
                    .tag = .StructInitOne,
                    .main_token = lbrace,
                    .data = .{
                        .lhs = lhs,
                        .rhs = field_init,
                    },
                });
            }

            var init_list = std.ArrayList(Node.Index).init(p.gpa);
            defer init_list.deinit();

            try init_list.append(field_init);

            while (true) {
                const next = try p.expectFieldInit();
                try init_list.append(next);

                switch (p.token_tags[p.nextToken()]) {
                    .Comma => {
                        if (p.eatToken(.RBrace)) |_| break;
                        continue;
                    },
                    .RBrace => break,
                    .Colon, .RParen, .RBracket => {
                        p.tok_i -= 1;
                        return p.fail(.{
                            .ExpectedToken = .{
                                .token = p.tok_i,
                                .expected_id = .RBrace,
                            },
                        });
                    },
                    else => {
                        // This is likely just a missing comma;
                        // give an error but continue parsing this list.
                        p.tok_i -= 1;
                        try p.warn(.{
                            .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                        });
                    },
                }
            }
            const span = try p.listToSpan(init_list.items);
            return p.addNode(.{
                .tag = .StructInit,
                .main_token = lbrace,
                .data = .{
                    .lhs = lhs,
                    .rhs = try p.addExtra(Node.SubRange{
                        .start = span.start,
                        .end = span.end,
                    }),
                },
            });
        }

        const elem_init = try p.expectExpr();
        if (p.eatToken(.RBrace)) |_| {
            return p.addNode(.{
                .tag = .ArrayInitOne,
                .main_token = lbrace,
                .data = .{
                    .lhs = lhs,
                    .rhs = elem_init,
                },
            });
        }

        var init_list = std.ArrayList(Node.Index).init(p.gpa);
        defer init_list.deinit();

        try init_list.append(elem_init);

        while (p.eatToken(.Comma)) |_| {
            const next = try p.parseExpr();
            if (next == 0) break;
            try init_list.append(next);
        }
        _ = try p.expectToken(.RBrace);
        const span = try p.listToSpan(init_list.items);
        return p.addNode(.{
            .tag = .ArrayInit,
            .main_token = lbrace,
            .data = .{
                .lhs = lhs,
                .rhs = try p.addExtra(Node.SubRange{
                    .start = span.start,
                    .end = span.end,
                }),
            },
        });
    }

    /// ErrorUnionExpr <- SuffixExpr (EXCLAMATIONMARK TypeExpr)?
    fn parseErrorUnionExpr(p: *Parser) !Node.Index {
        const suffix_expr = try p.parseSuffixExpr();
        if (suffix_expr == 0) return null_node;
        const bang = p.eatToken(.Bang) orelse return suffix_expr;
        return p.addNode(.{
            .tag = .ErrorUnion,
            .main_token = bang,
            .data = .{
                .lhs = suffix_expr,
                .rhs = try p.expectTypeExpr(),
            },
        });
    }

    /// SuffixExpr
    ///     <- KEYWORD_async PrimaryTypeExpr SuffixOp* FnCallArguments
    ///      / PrimaryTypeExpr (SuffixOp / FnCallArguments)*
    /// FnCallArguments <- LPAREN ExprList RPAREN
    /// ExprList <- (Expr COMMA)* Expr?
    fn parseSuffixExpr(p: *Parser) !Node.Index {
        if (p.eatToken(.Keyword_async)) |async_token| {
            var res = try p.expectPrimaryTypeExpr();

            while (true) {
                const node = try p.parseSuffixOp(res);
                if (node == 0) break;
                res = node;
            }
            const lparen = (try p.expectTokenRecoverable(.LParen)) orelse {
                try p.warn(.{ .ExpectedParamList = .{ .token = p.tok_i } });
                return res;
            };
            if (p.eatToken(.RParen)) |_| {
                return p.addNode(.{
                    .tag = .AsyncCallOne,
                    .main_token = lparen,
                    .data = .{
                        .lhs = res,
                        .rhs = 0,
                    },
                });
            }
            const param_one = try p.expectExpr();
            const comma_one = p.eatToken(.Comma);
            if (p.eatToken(.RParen)) |_| {
                return p.addNode(.{
                    .tag = if (comma_one == null) .AsyncCallOne else .AsyncCallOneComma,
                    .main_token = lparen,
                    .data = .{
                        .lhs = res,
                        .rhs = param_one,
                    },
                });
            }
            if (comma_one == null) {
                try p.warn(.{
                    .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                });
            }

            var param_list = std.ArrayList(Node.Index).init(p.gpa);
            defer param_list.deinit();

            try param_list.append(param_one);

            while (true) {
                const next = try p.expectExpr();
                try param_list.append(next);
                switch (p.token_tags[p.nextToken()]) {
                    .Comma => {
                        if (p.eatToken(.RParen)) |_| {
                            const span = try p.listToSpan(param_list.items);
                            return p.addNode(.{
                                .tag = .AsyncCallComma,
                                .main_token = lparen,
                                .data = .{
                                    .lhs = res,
                                    .rhs = try p.addExtra(Node.SubRange{
                                        .start = span.start,
                                        .end = span.end,
                                    }),
                                },
                            });
                        } else {
                            continue;
                        }
                    },
                    .RParen => {
                        const span = try p.listToSpan(param_list.items);
                        return p.addNode(.{
                            .tag = .AsyncCall,
                            .main_token = lparen,
                            .data = .{
                                .lhs = res,
                                .rhs = try p.addExtra(Node.SubRange{
                                    .start = span.start,
                                    .end = span.end,
                                }),
                            },
                        });
                    },
                    .Colon, .RBrace, .RBracket => {
                        p.tok_i -= 1;
                        return p.fail(.{
                            .ExpectedToken = .{
                                .token = p.tok_i,
                                .expected_id = .RParen,
                            },
                        });
                    },
                    else => {
                        p.tok_i -= 1;
                        try p.warn(.{
                            .ExpectedToken = .{
                                .token = p.tok_i,
                                .expected_id = .Comma,
                            },
                        });
                    },
                }
            }
        }
        var res = try p.parsePrimaryTypeExpr();
        if (res == 0) return res;

        while (true) {
            const suffix_op = try p.parseSuffixOp(res);
            if (suffix_op != 0) {
                res = suffix_op;
                continue;
            }
            res = res: {
                const lparen = p.eatToken(.LParen) orelse return res;
                if (p.eatToken(.RParen)) |_| {
                    break :res try p.addNode(.{
                        .tag = .CallOne,
                        .main_token = lparen,
                        .data = .{
                            .lhs = res,
                            .rhs = 0,
                        },
                    });
                }
                const param_one = try p.expectExpr();
                const comma_one = p.eatToken(.Comma);
                if (p.eatToken(.RParen)) |_| {
                    break :res try p.addNode(.{
                        .tag = if (comma_one == null) .CallOne else .CallOneComma,
                        .main_token = lparen,
                        .data = .{
                            .lhs = res,
                            .rhs = param_one,
                        },
                    });
                }
                if (comma_one == null) {
                    try p.warn(.{
                        .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                    });
                }

                var param_list = std.ArrayList(Node.Index).init(p.gpa);
                defer param_list.deinit();

                try param_list.append(param_one);

                while (true) {
                    const next = try p.expectExpr();
                    try param_list.append(next);
                    switch (p.token_tags[p.nextToken()]) {
                        .Comma => {
                            if (p.eatToken(.RParen)) |_| {
                                const span = try p.listToSpan(param_list.items);
                                break :res try p.addNode(.{
                                    .tag = .CallComma,
                                    .main_token = lparen,
                                    .data = .{
                                        .lhs = res,
                                        .rhs = try p.addExtra(Node.SubRange{
                                            .start = span.start,
                                            .end = span.end,
                                        }),
                                    },
                                });
                            } else {
                                continue;
                            }
                        },
                        .RParen => {
                            const span = try p.listToSpan(param_list.items);
                            break :res try p.addNode(.{
                                .tag = .Call,
                                .main_token = lparen,
                                .data = .{
                                    .lhs = res,
                                    .rhs = try p.addExtra(Node.SubRange{
                                        .start = span.start,
                                        .end = span.end,
                                    }),
                                },
                            });
                        },
                        .Colon, .RBrace, .RBracket => {
                            p.tok_i -= 1;
                            return p.fail(.{
                                .ExpectedToken = .{
                                    .token = p.tok_i,
                                    .expected_id = .RParen,
                                },
                            });
                        },
                        else => {
                            p.tok_i -= 1;
                            try p.warn(.{
                                .ExpectedToken = .{
                                    .token = p.tok_i,
                                    .expected_id = .Comma,
                                },
                            });
                        },
                    }
                }
            };
        }
    }

    /// PrimaryTypeExpr
    ///     <- BUILTINIDENTIFIER FnCallArguments
    ///      / CHAR_LITERAL
    ///      / ContainerDecl
    ///      / DOT IDENTIFIER
    ///      / DOT InitList
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
    /// ContainerDecl <- (KEYWORD_extern / KEYWORD_packed)? ContainerDeclAuto
    /// ContainerDeclAuto <- ContainerDeclType LBRACE ContainerMembers RBRACE
    /// InitList
    ///     <- LBRACE FieldInit (COMMA FieldInit)* COMMA? RBRACE
    ///      / LBRACE Expr (COMMA Expr)* COMMA? RBRACE
    ///      / LBRACE RBRACE
    /// ErrorSetDecl <- KEYWORD_error LBRACE IdentifierList RBRACE
    /// GroupedExpr <- LPAREN Expr RPAREN
    /// IfTypeExpr <- IfPrefix TypeExpr (KEYWORD_else Payload? TypeExpr)?
    /// LabeledTypeExpr
    ///     <- BlockLabel Block
    ///      / BlockLabel? LoopTypeExpr
    /// LoopTypeExpr <- KEYWORD_inline? (ForTypeExpr / WhileTypeExpr)
    fn parsePrimaryTypeExpr(p: *Parser) !Node.Index {
        switch (p.token_tags[p.tok_i]) {
            .CharLiteral => return p.addNode(.{
                .tag = .CharLiteral,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            }),
            .IntegerLiteral => return p.addNode(.{
                .tag = .IntegerLiteral,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            }),
            .FloatLiteral => return p.addNode(.{
                .tag = .FloatLiteral,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            }),
            .Keyword_false => return p.addNode(.{
                .tag = .FalseLiteral,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            }),
            .Keyword_true => return p.addNode(.{
                .tag = .TrueLiteral,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            }),
            .Keyword_null => return p.addNode(.{
                .tag = .NullLiteral,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            }),
            .Keyword_undefined => return p.addNode(.{
                .tag = .UndefinedLiteral,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            }),
            .Keyword_unreachable => return p.addNode(.{
                .tag = .UnreachableLiteral,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            }),
            .Keyword_anyframe => return p.addNode(.{
                .tag = .AnyFrameLiteral,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            }),
            .StringLiteral => {
                const main_token = p.nextToken();
                return p.addNode(.{
                    .tag = .StringLiteral,
                    .main_token = main_token,
                    .data = .{
                        .lhs = main_token,
                        .rhs = main_token,
                    },
                });
            },

            .Builtin => return p.parseBuiltinCall(),
            .Keyword_fn => return p.parseFnProto(),
            .Keyword_if => return p.parseIf(parseTypeExpr),
            .Keyword_switch => return p.expectSwitchExpr(),

            .Keyword_extern,
            .Keyword_packed,
            => {
                p.tok_i += 1;
                return p.parseContainerDeclAuto();
            },

            .Keyword_struct,
            .Keyword_opaque,
            .Keyword_enum,
            .Keyword_union,
            => return p.parseContainerDeclAuto(),

            .Keyword_comptime => return p.addNode(.{
                .tag = .Comptime,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = try p.expectTypeExpr(),
                    .rhs = undefined,
                },
            }),
            .MultilineStringLiteralLine => {
                const first_line = p.nextToken();
                while (p.token_tags[p.tok_i] == .MultilineStringLiteralLine) {
                    p.tok_i += 1;
                }
                return p.addNode(.{
                    .tag = .StringLiteral,
                    .main_token = first_line,
                    .data = .{
                        .lhs = first_line,
                        .rhs = p.tok_i - 1,
                    },
                });
            },
            .Identifier => switch (p.token_tags[p.tok_i + 1]) {
                .Colon => switch (p.token_tags[p.tok_i + 2]) {
                    .Keyword_inline => {
                        p.tok_i += 3;
                        switch (p.token_tags[p.tok_i]) {
                            .Keyword_for => return p.parseForTypeExpr(),
                            .Keyword_while => return p.parseWhileTypeExpr(),
                            else => return p.fail(.{
                                .ExpectedInlinable = .{ .token = p.tok_i },
                            }),
                        }
                    },
                    .Keyword_for => {
                        p.tok_i += 2;
                        return p.parseForTypeExpr();
                    },
                    .Keyword_while => {
                        p.tok_i += 2;
                        return p.parseWhileTypeExpr();
                    },
                    else => return p.addNode(.{
                        .tag = .Identifier,
                        .main_token = p.nextToken(),
                        .data = .{
                            .lhs = undefined,
                            .rhs = undefined,
                        },
                    }),
                },
                else => return p.addNode(.{
                    .tag = .Identifier,
                    .main_token = p.nextToken(),
                    .data = .{
                        .lhs = undefined,
                        .rhs = undefined,
                    },
                }),
            },
            .Period => switch (p.token_tags[p.tok_i + 1]) {
                .Identifier => return p.addNode(.{
                    .tag = .EnumLiteral,
                    .data = .{
                        .lhs = p.nextToken(), // dot
                        .rhs = undefined,
                    },
                    .main_token = p.nextToken(), // identifier
                }),
                .LBrace => {
                    const lbrace = p.tok_i + 1;
                    p.tok_i = lbrace + 1;

                    // If there are 0, 1, or 2 items, we can use ArrayInitDotTwo/StructInitDotTwo;
                    // otherwise we use the full ArrayInitDot/StructInitDot.

                    if (p.eatToken(.RBrace)) |_| {
                        return p.addNode(.{
                            .tag = .StructInitDotTwo,
                            .main_token = lbrace,
                            .data = .{
                                .lhs = 0,
                                .rhs = 0,
                            },
                        });
                    }
                    const field_init_one = try p.parseFieldInit();
                    if (field_init_one != 0) {
                        const comma_one = p.eatToken(.Comma);
                        if (p.eatToken(.RBrace)) |_| {
                            const tag: Node.Tag = if (comma_one != null)
                                .StructInitDotTwoComma
                            else
                                .StructInitDotTwo;
                            return p.addNode(.{
                                .tag = tag,
                                .main_token = lbrace,
                                .data = .{
                                    .lhs = field_init_one,
                                    .rhs = 0,
                                },
                            });
                        }
                        if (comma_one == null) {
                            try p.warn(.{
                                .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                            });
                        }
                        const field_init_two = try p.expectFieldInit();
                        const comma_two = p.eatToken(.Comma);
                        if (p.eatToken(.RBrace)) |_| {
                            const tag: Node.Tag = if (comma_two != null)
                                .StructInitDotTwoComma
                            else
                                .StructInitDotTwo;
                            return p.addNode(.{
                                .tag = tag,
                                .main_token = lbrace,
                                .data = .{
                                    .lhs = field_init_one,
                                    .rhs = field_init_two,
                                },
                            });
                        }
                        if (comma_two == null) {
                            try p.warn(.{
                                .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                            });
                        }
                        var init_list = std.ArrayList(Node.Index).init(p.gpa);
                        defer init_list.deinit();

                        try init_list.appendSlice(&[_]Node.Index{ field_init_one, field_init_two });

                        while (true) {
                            const next = try p.expectFieldInit();
                            assert(next != 0);
                            try init_list.append(next);
                            switch (p.token_tags[p.nextToken()]) {
                                .Comma => {
                                    if (p.eatToken(.RBrace)) |_| break;
                                    continue;
                                },
                                .RBrace => break,
                                .Colon, .RParen, .RBracket => {
                                    p.tok_i -= 1;
                                    return p.fail(.{
                                        .ExpectedToken = .{
                                            .token = p.tok_i,
                                            .expected_id = .RBrace,
                                        },
                                    });
                                },
                                else => {
                                    p.tok_i -= 1;
                                    try p.warn(.{
                                        .ExpectedToken = .{
                                            .token = p.tok_i,
                                            .expected_id = .Comma,
                                        },
                                    });
                                },
                            }
                        }
                        const span = try p.listToSpan(init_list.items);
                        return p.addNode(.{
                            .tag = .StructInitDot,
                            .main_token = lbrace,
                            .data = .{
                                .lhs = span.start,
                                .rhs = span.end,
                            },
                        });
                    }

                    const elem_init_one = try p.expectExpr();
                    const comma_one = p.eatToken(.Comma);
                    if (p.eatToken(.RBrace)) |_| {
                        return p.addNode(.{
                            .tag = if (comma_one != null) .ArrayInitDotTwoComma else .ArrayInitDotTwo,
                            .main_token = lbrace,
                            .data = .{
                                .lhs = elem_init_one,
                                .rhs = 0,
                            },
                        });
                    }
                    if (comma_one == null) {
                        try p.warn(.{
                            .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                        });
                    }
                    const elem_init_two = try p.expectExpr();
                    const comma_two = p.eatToken(.Comma);
                    if (p.eatToken(.RBrace)) |_| {
                        return p.addNode(.{
                            .tag = if (comma_one != null) .ArrayInitDotTwoComma else .ArrayInitDotTwo,
                            .main_token = lbrace,
                            .data = .{
                                .lhs = elem_init_one,
                                .rhs = elem_init_two,
                            },
                        });
                    }
                    if (comma_two == null) {
                        try p.warn(.{
                            .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                        });
                    }
                    var init_list = std.ArrayList(Node.Index).init(p.gpa);
                    defer init_list.deinit();

                    try init_list.appendSlice(&[_]Node.Index{ elem_init_one, elem_init_two });

                    while (true) {
                        const next = try p.expectExpr();
                        if (next == 0) break;
                        try init_list.append(next);
                        switch (p.token_tags[p.nextToken()]) {
                            .Comma => {
                                if (p.eatToken(.RBrace)) |_| break;
                                continue;
                            },
                            .RBrace => break,
                            .Colon, .RParen, .RBracket => {
                                p.tok_i -= 1;
                                return p.fail(.{
                                    .ExpectedToken = .{
                                        .token = p.tok_i,
                                        .expected_id = .RBrace,
                                    },
                                });
                            },
                            else => {
                                p.tok_i -= 1;
                                try p.warn(.{
                                    .ExpectedToken = .{
                                        .token = p.tok_i,
                                        .expected_id = .Comma,
                                    },
                                });
                            },
                        }
                    }
                    const span = try p.listToSpan(init_list.items);
                    return p.addNode(.{
                        .tag = .ArrayInitDot,
                        .main_token = lbrace,
                        .data = .{
                            .lhs = span.start,
                            .rhs = span.end,
                        },
                    });
                },
                else => return null_node,
            },
            .Keyword_error => switch (p.token_tags[p.tok_i + 1]) {
                .LBrace => {
                    const error_token = p.tok_i;
                    p.tok_i += 2;

                    if (p.eatToken(.RBrace)) |rbrace| {
                        return p.addNode(.{
                            .tag = .ErrorSetDecl,
                            .main_token = error_token,
                            .data = .{
                                .lhs = undefined,
                                .rhs = rbrace,
                            },
                        });
                    }

                    while (true) {
                        const doc_comment = p.eatDocComments();
                        const identifier = try p.expectToken(.Identifier);
                        switch (p.token_tags[p.nextToken()]) {
                            .Comma => {
                                if (p.eatToken(.RBrace)) |_| break;
                                continue;
                            },
                            .RBrace => break,
                            .Colon, .RParen, .RBracket => {
                                p.tok_i -= 1;
                                return p.fail(.{
                                    .ExpectedToken = .{
                                        .token = p.tok_i,
                                        .expected_id = .RBrace,
                                    },
                                });
                            },
                            else => {
                                // This is likely just a missing comma;
                                // give an error but continue parsing this list.
                                p.tok_i -= 1;
                                try p.warn(.{
                                    .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                                });
                            },
                        }
                    }
                    return p.addNode(.{
                        .tag = .ErrorSetDecl,
                        .main_token = error_token,
                        .data = .{
                            .lhs = undefined,
                            .rhs = p.tok_i - 1, // rbrace
                        },
                    });
                },
                else => return p.addNode(.{
                    .tag = .ErrorValue,
                    .main_token = p.nextToken(),
                    .data = .{
                        .lhs = try p.expectToken(.Period),
                        .rhs = try p.expectToken(.Identifier),
                    },
                }),
            },
            .LParen => return p.addNode(.{
                .tag = .GroupedExpression,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = try p.expectExpr(),
                    .rhs = try p.expectToken(.RParen),
                },
            }),
            else => return null_node,
        }
    }

    fn expectPrimaryTypeExpr(p: *Parser) !Node.Index {
        const node = try p.parsePrimaryTypeExpr();
        if (node == 0) {
            return p.fail(.{ .ExpectedPrimaryTypeExpr = .{ .token = p.tok_i } });
        }
        return node;
    }

    /// ForPrefix <- KEYWORD_for LPAREN Expr RPAREN PtrIndexPayload
    /// ForTypeExpr <- ForPrefix TypeExpr (KEYWORD_else TypeExpr)?
    fn parseForTypeExpr(p: *Parser) !Node.Index {
        const for_token = p.eatToken(.Keyword_for) orelse return null_node;
        _ = try p.expectToken(.LParen);
        const array_expr = try p.expectTypeExpr();
        _ = try p.expectToken(.RParen);
        _ = try p.parsePtrIndexPayload();

        const then_expr = try p.expectExpr();
        const else_token = p.eatToken(.Keyword_else) orelse {
            return p.addNode(.{
                .tag = .ForSimple,
                .main_token = for_token,
                .data = .{
                    .lhs = array_expr,
                    .rhs = then_expr,
                },
            });
        };
        const else_expr = try p.expectTypeExpr();
        return p.addNode(.{
            .tag = .For,
            .main_token = for_token,
            .data = .{
                .lhs = array_expr,
                .rhs = try p.addExtra(Node.If{
                    .then_expr = then_expr,
                    .else_expr = else_expr,
                }),
            },
        });
    }

    /// WhilePrefix <- KEYWORD_while LPAREN Expr RPAREN PtrPayload? WhileContinueExpr?
    /// WhileTypeExpr <- WhilePrefix TypeExpr (KEYWORD_else Payload? TypeExpr)?
    fn parseWhileTypeExpr(p: *Parser) !Node.Index {
        const while_token = p.eatToken(.Keyword_while) orelse return null_node;
        _ = try p.expectToken(.LParen);
        const condition = try p.expectExpr();
        _ = try p.expectToken(.RParen);
        const then_payload = try p.parsePtrPayload();
        const cont_expr = try p.parseWhileContinueExpr();

        const then_expr = try p.expectTypeExpr();
        const else_token = p.eatToken(.Keyword_else) orelse {
            if (cont_expr == 0) {
                return p.addNode(.{
                    .tag = .WhileSimple,
                    .main_token = while_token,
                    .data = .{
                        .lhs = condition,
                        .rhs = then_expr,
                    },
                });
            } else {
                return p.addNode(.{
                    .tag = .WhileCont,
                    .main_token = while_token,
                    .data = .{
                        .lhs = condition,
                        .rhs = try p.addExtra(Node.WhileCont{
                            .cont_expr = cont_expr,
                            .then_expr = then_expr,
                        }),
                    },
                });
            }
        };
        const else_payload = try p.parsePayload();
        const else_expr = try p.expectTypeExpr();
        return p.addNode(.{
            .tag = .While,
            .main_token = while_token,
            .data = .{
                .lhs = condition,
                .rhs = try p.addExtra(Node.While{
                    .cont_expr = cont_expr,
                    .then_expr = then_expr,
                    .else_expr = else_expr,
                }),
            },
        });
    }

    /// SwitchExpr <- KEYWORD_switch LPAREN Expr RPAREN LBRACE SwitchProngList RBRACE
    fn expectSwitchExpr(p: *Parser) !Node.Index {
        const switch_token = p.assertToken(.Keyword_switch);
        _ = try p.expectToken(.LParen);
        const expr_node = try p.expectExpr();
        _ = try p.expectToken(.RParen);
        _ = try p.expectToken(.LBrace);
        const cases = try p.parseSwitchProngList();
        const trailing_comma = p.token_tags[p.tok_i - 1] == .Comma;
        _ = try p.expectToken(.RBrace);

        return p.addNode(.{
            .tag = if (trailing_comma) .SwitchComma else .Switch,
            .main_token = switch_token,
            .data = .{
                .lhs = expr_node,
                .rhs = try p.addExtra(Node.SubRange{
                    .start = cases.start,
                    .end = cases.end,
                }),
            },
        });
    }

    /// AsmExpr <- KEYWORD_asm KEYWORD_volatile? LPAREN Expr AsmOutput? RPAREN
    /// AsmOutput <- COLON AsmOutputList AsmInput?
    /// AsmInput <- COLON AsmInputList AsmClobbers?
    /// AsmClobbers <- COLON StringList
    /// StringList <- (STRINGLITERAL COMMA)* STRINGLITERAL?
    /// AsmOutputList <- (AsmOutputItem COMMA)* AsmOutputItem?
    /// AsmInputList <- (AsmInputItem COMMA)* AsmInputItem?
    fn expectAsmExpr(p: *Parser) !Node.Index {
        const asm_token = p.assertToken(.Keyword_asm);
        _ = p.eatToken(.Keyword_volatile);
        _ = try p.expectToken(.LParen);
        const template = try p.expectExpr();

        if (p.eatToken(.RParen)) |rparen| {
            return p.addNode(.{
                .tag = .AsmSimple,
                .main_token = asm_token,
                .data = .{
                    .lhs = template,
                    .rhs = rparen,
                },
            });
        }

        _ = try p.expectToken(.Colon);

        var list = std.ArrayList(Node.Index).init(p.gpa);
        defer list.deinit();

        while (true) {
            const output_item = try p.parseAsmOutputItem();
            if (output_item == 0) break;
            try list.append(output_item);
            switch (p.token_tags[p.tok_i]) {
                .Comma => p.tok_i += 1,
                .Colon, .RParen, .RBrace, .RBracket => break, // All possible delimiters.
                else => {
                    // This is likely just a missing comma;
                    // give an error but continue parsing this list.
                    try p.warn(.{
                        .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                    });
                },
            }
        }
        if (p.eatToken(.Colon)) |_| {
            while (true) {
                const input_item = try p.parseAsmInputItem();
                if (input_item == 0) break;
                try list.append(input_item);
                switch (p.token_tags[p.tok_i]) {
                    .Comma => p.tok_i += 1,
                    .Colon, .RParen, .RBrace, .RBracket => break, // All possible delimiters.
                    else => {
                        // This is likely just a missing comma;
                        // give an error but continue parsing this list.
                        try p.warn(.{
                            .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                        });
                    },
                }
            }
            if (p.eatToken(.Colon)) |_| {
                while (p.eatToken(.StringLiteral)) |_| {
                    switch (p.token_tags[p.tok_i]) {
                        .Comma => p.tok_i += 1,
                        .Colon, .RParen, .RBrace, .RBracket => break,
                        else => {
                            // This is likely just a missing comma;
                            // give an error but continue parsing this list.
                            try p.warn(.{
                                .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                            });
                        },
                    }
                }
            }
        }
        const rparen = try p.expectToken(.RParen);
        const span = try p.listToSpan(list.items);
        return p.addNode(.{
            .tag = .Asm,
            .main_token = asm_token,
            .data = .{
                .lhs = template,
                .rhs = try p.addExtra(Node.Asm{
                    .items_start = span.start,
                    .items_end = span.end,
                    .rparen = rparen,
                }),
            },
        });
    }

    /// AsmOutputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN (MINUSRARROW TypeExpr / IDENTIFIER) RPAREN
    fn parseAsmOutputItem(p: *Parser) !Node.Index {
        _ = p.eatToken(.LBracket) orelse return null_node;
        const identifier = try p.expectToken(.Identifier);
        _ = try p.expectToken(.RBracket);
        _ = try p.expectToken(.StringLiteral);
        _ = try p.expectToken(.LParen);
        const type_expr: Node.Index = blk: {
            if (p.eatToken(.Arrow)) |_| {
                break :blk try p.expectTypeExpr();
            } else {
                _ = try p.expectToken(.Identifier);
                break :blk null_node;
            }
        };
        const rparen = try p.expectToken(.RParen);
        return p.addNode(.{
            .tag = .AsmOutput,
            .main_token = identifier,
            .data = .{
                .lhs = type_expr,
                .rhs = rparen,
            },
        });
    }

    /// AsmInputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN Expr RPAREN
    fn parseAsmInputItem(p: *Parser) !Node.Index {
        _ = p.eatToken(.LBracket) orelse return null_node;
        const identifier = try p.expectToken(.Identifier);
        _ = try p.expectToken(.RBracket);
        _ = try p.expectToken(.StringLiteral);
        _ = try p.expectToken(.LParen);
        const expr = try p.expectExpr();
        const rparen = try p.expectToken(.RParen);
        return p.addNode(.{
            .tag = .AsmInput,
            .main_token = identifier,
            .data = .{
                .lhs = expr,
                .rhs = rparen,
            },
        });
    }

    /// BreakLabel <- COLON IDENTIFIER
    fn parseBreakLabel(p: *Parser) !TokenIndex {
        _ = p.eatToken(.Colon) orelse return @as(TokenIndex, 0);
        return p.expectToken(.Identifier);
    }

    /// BlockLabel <- IDENTIFIER COLON
    fn parseBlockLabel(p: *Parser) TokenIndex {
        if (p.token_tags[p.tok_i] == .Identifier and
            p.token_tags[p.tok_i + 1] == .Colon)
        {
            const identifier = p.tok_i;
            p.tok_i += 2;
            return identifier;
        }
        return 0;
    }

    /// FieldInit <- DOT IDENTIFIER EQUAL Expr
    fn parseFieldInit(p: *Parser) !Node.Index {
        if (p.token_tags[p.tok_i + 0] == .Period and
            p.token_tags[p.tok_i + 1] == .Identifier and
            p.token_tags[p.tok_i + 2] == .Equal)
        {
            p.tok_i += 3;
            return p.expectExpr();
        } else {
            return null_node;
        }
    }

    fn expectFieldInit(p: *Parser) !Node.Index {
        _ = try p.expectToken(.Period);
        _ = try p.expectToken(.Identifier);
        _ = try p.expectToken(.Equal);
        return p.expectExpr();
    }

    /// WhileContinueExpr <- COLON LPAREN AssignExpr RPAREN
    fn parseWhileContinueExpr(p: *Parser) !Node.Index {
        _ = p.eatToken(.Colon) orelse return null_node;
        _ = try p.expectToken(.LParen);
        const node = try p.parseAssignExpr();
        if (node == 0) return p.fail(.{ .ExpectedExprOrAssignment = .{ .token = p.tok_i } });
        _ = try p.expectToken(.RParen);
        return node;
    }

    /// LinkSection <- KEYWORD_linksection LPAREN Expr RPAREN
    fn parseLinkSection(p: *Parser) !Node.Index {
        _ = p.eatToken(.Keyword_linksection) orelse return null_node;
        _ = try p.expectToken(.LParen);
        const expr_node = try p.expectExpr();
        _ = try p.expectToken(.RParen);
        return expr_node;
    }

    /// CallConv <- KEYWORD_callconv LPAREN Expr RPAREN
    fn parseCallconv(p: *Parser) !Node.Index {
        _ = p.eatToken(.Keyword_callconv) orelse return null_node;
        _ = try p.expectToken(.LParen);
        const expr_node = try p.expectExpr();
        _ = try p.expectToken(.RParen);
        return expr_node;
    }

    /// ParamDecl
    ///     <- (KEYWORD_noalias / KEYWORD_comptime)? (IDENTIFIER COLON)? ParamType
    ///     / DOT3
    /// ParamType
    ///     <- Keyword_anytype
    ///      / TypeExpr
    /// This function can return null nodes and then still return nodes afterwards,
    /// such as in the case of anytype and `...`. Caller must look for rparen to find
    /// out when there are no more param decls left.
    fn expectParamDecl(p: *Parser) !Node.Index {
        _ = p.eatDocComments();
        switch (p.token_tags[p.tok_i]) {
            .Keyword_noalias, .Keyword_comptime => p.tok_i += 1,
            .Ellipsis3 => {
                p.tok_i += 1;
                return null_node;
            },
            else => {},
        }
        if (p.token_tags[p.tok_i] == .Identifier and
            p.token_tags[p.tok_i + 1] == .Colon)
        {
            p.tok_i += 2;
        }
        switch (p.token_tags[p.tok_i]) {
            .Keyword_anytype => {
                p.tok_i += 1;
                return null_node;
            },
            else => return p.expectTypeExpr(),
        }
    }

    /// Payload <- PIPE IDENTIFIER PIPE
    fn parsePayload(p: *Parser) !TokenIndex {
        _ = p.eatToken(.Pipe) orelse return @as(TokenIndex, 0);
        const identifier = try p.expectToken(.Identifier);
        _ = try p.expectToken(.Pipe);
        return identifier;
    }

    /// PtrPayload <- PIPE ASTERISK? IDENTIFIER PIPE
    fn parsePtrPayload(p: *Parser) !TokenIndex {
        _ = p.eatToken(.Pipe) orelse return @as(TokenIndex, 0);
        _ = p.eatToken(.Asterisk);
        const identifier = try p.expectToken(.Identifier);
        _ = try p.expectToken(.Pipe);
        return identifier;
    }

    /// PtrIndexPayload <- PIPE ASTERISK? IDENTIFIER (COMMA IDENTIFIER)? PIPE
    /// Returns the first identifier token, if any.
    fn parsePtrIndexPayload(p: *Parser) !TokenIndex {
        _ = p.eatToken(.Pipe) orelse return @as(TokenIndex, 0);
        _ = p.eatToken(.Asterisk);
        const identifier = try p.expectToken(.Identifier);
        if (p.eatToken(.Comma) != null) {
            _ = try p.expectToken(.Identifier);
        }
        _ = try p.expectToken(.Pipe);
        return identifier;
    }

    /// SwitchProng <- SwitchCase EQUALRARROW PtrPayload? AssignExpr
    /// SwitchCase
    ///     <- SwitchItem (COMMA SwitchItem)* COMMA?
    ///      / KEYWORD_else
    fn parseSwitchProng(p: *Parser) !Node.Index {
        if (p.eatToken(.Keyword_else)) |_| {
            const arrow_token = try p.expectToken(.EqualAngleBracketRight);
            _ = try p.parsePtrPayload();
            return p.addNode(.{
                .tag = .SwitchCaseOne,
                .main_token = arrow_token,
                .data = .{
                    .lhs = 0,
                    .rhs = try p.expectAssignExpr(),
                },
            });
        }
        const first_item = try p.parseSwitchItem();
        if (first_item == 0) return null_node;

        if (p.eatToken(.EqualAngleBracketRight)) |arrow_token| {
            _ = try p.parsePtrPayload();
            return p.addNode(.{
                .tag = .SwitchCaseOne,
                .main_token = arrow_token,
                .data = .{
                    .lhs = first_item,
                    .rhs = try p.expectAssignExpr(),
                },
            });
        }

        var list = std.ArrayList(Node.Index).init(p.gpa);
        defer list.deinit();

        try list.append(first_item);
        while (p.eatToken(.Comma)) |_| {
            const next_item = try p.parseSwitchItem();
            if (next_item == 0) break;
            try list.append(next_item);
        }
        const span = try p.listToSpan(list.items);
        const arrow_token = try p.expectToken(.EqualAngleBracketRight);
        _ = try p.parsePtrPayload();
        return p.addNode(.{
            .tag = .SwitchCase,
            .main_token = arrow_token,
            .data = .{
                .lhs = try p.addExtra(Node.SubRange{
                    .start = span.start,
                    .end = span.end,
                }),
                .rhs = try p.expectAssignExpr(),
            },
        });
    }

    /// SwitchItem <- Expr (DOT3 Expr)?
    fn parseSwitchItem(p: *Parser) !Node.Index {
        const expr = try p.parseExpr();
        if (expr == 0) return null_node;

        if (p.eatToken(.Ellipsis3)) |token| {
            return p.addNode(.{
                .tag = .SwitchRange,
                .main_token = token,
                .data = .{
                    .lhs = expr,
                    .rhs = try p.expectExpr(),
                },
            });
        }
        return expr;
    }

    const PtrModifiers = struct {
        align_node: Node.Index,
        bit_range_start: Node.Index,
        bit_range_end: Node.Index,
    };

    fn parsePtrModifiers(p: *Parser) !PtrModifiers {
        var result: PtrModifiers = .{
            .align_node = 0,
            .bit_range_start = 0,
            .bit_range_end = 0,
        };
        var saw_const = false;
        var saw_volatile = false;
        var saw_allowzero = false;
        while (true) {
            switch (p.token_tags[p.tok_i]) {
                .Keyword_align => {
                    if (result.align_node != 0) {
                        try p.warn(.{
                            .ExtraAlignQualifier = .{ .token = p.tok_i },
                        });
                    }
                    p.tok_i += 1;
                    _ = try p.expectToken(.LParen);
                    result.align_node = try p.expectExpr();

                    if (p.eatToken(.Colon)) |_| {
                        result.bit_range_start = try p.expectExpr();
                        _ = try p.expectToken(.Colon);
                        result.bit_range_end = try p.expectExpr();
                    }

                    _ = try p.expectToken(.RParen);
                },
                .Keyword_const => {
                    if (saw_const) {
                        try p.warn(.{
                            .ExtraConstQualifier = .{ .token = p.tok_i },
                        });
                    }
                    p.tok_i += 1;
                    saw_const = true;
                },
                .Keyword_volatile => {
                    if (saw_volatile) {
                        try p.warn(.{
                            .ExtraVolatileQualifier = .{ .token = p.tok_i },
                        });
                    }
                    p.tok_i += 1;
                    saw_volatile = true;
                },
                .Keyword_allowzero => {
                    if (saw_allowzero) {
                        try p.warn(.{
                            .ExtraAllowZeroQualifier = .{ .token = p.tok_i },
                        });
                    }
                    p.tok_i += 1;
                    saw_allowzero = true;
                },
                else => return result,
            }
        }
    }

    /// SuffixOp
    ///     <- LBRACKET Expr (DOT2 (Expr (COLON Expr)?)?)? RBRACKET
    ///      / DOT IDENTIFIER
    ///      / DOTASTERISK
    ///      / DOTQUESTIONMARK
    fn parseSuffixOp(p: *Parser, lhs: Node.Index) !Node.Index {
        switch (p.token_tags[p.tok_i]) {
            .LBracket => {
                const lbracket = p.nextToken();
                const index_expr = try p.expectExpr();

                if (p.eatToken(.Ellipsis2)) |_| {
                    const end_expr = try p.parseExpr();
                    if (end_expr == 0) {
                        _ = try p.expectToken(.RBracket);
                        return p.addNode(.{
                            .tag = .SliceOpen,
                            .main_token = lbracket,
                            .data = .{
                                .lhs = lhs,
                                .rhs = index_expr,
                            },
                        });
                    }
                    if (p.eatToken(.Colon)) |_| {
                        const sentinel = try p.parseExpr();
                        _ = try p.expectToken(.RBracket);
                        return p.addNode(.{
                            .tag = .SliceSentinel,
                            .main_token = lbracket,
                            .data = .{
                                .lhs = lhs,
                                .rhs = try p.addExtra(Node.SliceSentinel{
                                    .start = index_expr,
                                    .end = end_expr,
                                    .sentinel = sentinel,
                                }),
                            },
                        });
                    } else {
                        _ = try p.expectToken(.RBracket);
                        return p.addNode(.{
                            .tag = .Slice,
                            .main_token = lbracket,
                            .data = .{
                                .lhs = lhs,
                                .rhs = try p.addExtra(Node.Slice{
                                    .start = index_expr,
                                    .end = end_expr,
                                }),
                            },
                        });
                    }
                }
                _ = try p.expectToken(.RBracket);
                return p.addNode(.{
                    .tag = .ArrayAccess,
                    .main_token = lbracket,
                    .data = .{
                        .lhs = lhs,
                        .rhs = index_expr,
                    },
                });
            },
            .PeriodAsterisk => return p.addNode(.{
                .tag = .Deref,
                .main_token = p.nextToken(),
                .data = .{
                    .lhs = lhs,
                    .rhs = undefined,
                },
            }),
            .Invalid_periodasterisks => {
                const period_asterisk = p.nextToken();
                try p.warn(.{ .AsteriskAfterPointerDereference = .{ .token = period_asterisk } });
                return p.addNode(.{
                    .tag = .Deref,
                    .main_token = period_asterisk,
                    .data = .{
                        .lhs = lhs,
                        .rhs = undefined,
                    },
                });
            },
            .Period => switch (p.token_tags[p.tok_i + 1]) {
                .Identifier => return p.addNode(.{
                    .tag = .FieldAccess,
                    .main_token = p.nextToken(),
                    .data = .{
                        .lhs = lhs,
                        .rhs = p.nextToken(),
                    },
                }),
                .QuestionMark => return p.addNode(.{
                    .tag = .UnwrapOptional,
                    .main_token = p.nextToken(),
                    .data = .{
                        .lhs = lhs,
                        .rhs = p.nextToken(),
                    },
                }),
                else => {
                    p.tok_i += 1;
                    try p.warn(.{ .ExpectedSuffixOp = .{ .token = p.tok_i } });
                    return null_node;
                },
            },
            else => return null_node,
        }
    }

    /// Caller must have already verified the first token.
    /// ContainerDeclType
    ///     <- KEYWORD_struct
    ///      / KEYWORD_enum (LPAREN Expr RPAREN)?
    ///      / KEYWORD_union (LPAREN (KEYWORD_enum (LPAREN Expr RPAREN)? / Expr) RPAREN)?
    ///      / KEYWORD_opaque
    fn parseContainerDeclAuto(p: *Parser) !Node.Index {
        const main_token = p.nextToken();
        const arg_expr = switch (p.token_tags[main_token]) {
            .Keyword_struct, .Keyword_opaque => null_node,
            .Keyword_enum => blk: {
                if (p.eatToken(.LParen)) |_| {
                    const expr = try p.expectExpr();
                    _ = try p.expectToken(.RParen);
                    break :blk expr;
                } else {
                    break :blk null_node;
                }
            },
            .Keyword_union => blk: {
                if (p.eatToken(.LParen)) |_| {
                    if (p.eatToken(.Keyword_enum)) |_| {
                        if (p.eatToken(.LParen)) |_| {
                            const enum_tag_expr = try p.expectExpr();
                            _ = try p.expectToken(.RParen);
                            _ = try p.expectToken(.RParen);

                            _ = try p.expectToken(.LBrace);
                            const members = try p.parseContainerMembers();
                            const members_span = try members.toSpan(p);
                            _ = try p.expectToken(.RBrace);
                            return p.addNode(.{
                                .tag = switch (members.trailing_comma) {
                                    true => .TaggedUnionEnumTagComma,
                                    false => .TaggedUnionEnumTag,
                                },
                                .main_token = main_token,
                                .data = .{
                                    .lhs = enum_tag_expr,
                                    .rhs = try p.addExtra(members_span),
                                },
                            });
                        } else {
                            _ = try p.expectToken(.RParen);

                            _ = try p.expectToken(.LBrace);
                            const members = try p.parseContainerMembers();
                            _ = try p.expectToken(.RBrace);
                            if (members.len <= 2) {
                                return p.addNode(.{
                                    .tag = switch (members.trailing_comma) {
                                        true => .TaggedUnionTwoComma,
                                        false => .TaggedUnionTwo,
                                    },
                                    .main_token = main_token,
                                    .data = .{
                                        .lhs = members.lhs,
                                        .rhs = members.rhs,
                                    },
                                });
                            } else {
                                const span = try members.toSpan(p);
                                return p.addNode(.{
                                    .tag = switch (members.trailing_comma) {
                                        true => .TaggedUnionComma,
                                        false => .TaggedUnion,
                                    },
                                    .main_token = main_token,
                                    .data = .{
                                        .lhs = span.start,
                                        .rhs = span.end,
                                    },
                                });
                            }
                        }
                    } else {
                        const expr = try p.expectExpr();
                        _ = try p.expectToken(.RParen);
                        break :blk expr;
                    }
                } else {
                    break :blk null_node;
                }
            },
            else => unreachable,
        };
        _ = try p.expectToken(.LBrace);
        const members = try p.parseContainerMembers();
        _ = try p.expectToken(.RBrace);
        if (arg_expr == 0) {
            if (members.len <= 2) {
                return p.addNode(.{
                    .tag = switch (members.trailing_comma) {
                        true => .ContainerDeclTwoComma,
                        false => .ContainerDeclTwo,
                    },
                    .main_token = main_token,
                    .data = .{
                        .lhs = members.lhs,
                        .rhs = members.rhs,
                    },
                });
            } else {
                const span = try members.toSpan(p);
                return p.addNode(.{
                    .tag = switch (members.trailing_comma) {
                        true => .ContainerDeclComma,
                        false => .ContainerDecl,
                    },
                    .main_token = main_token,
                    .data = .{
                        .lhs = span.start,
                        .rhs = span.end,
                    },
                });
            }
        } else {
            const span = try members.toSpan(p);
            return p.addNode(.{
                .tag = switch (members.trailing_comma) {
                    true => .ContainerDeclArgComma,
                    false => .ContainerDeclArg,
                },
                .main_token = main_token,
                .data = .{
                    .lhs = arg_expr,
                    .rhs = try p.addExtra(Node.SubRange{
                        .start = span.start,
                        .end = span.end,
                    }),
                },
            });
        }
    }

    /// Holds temporary data until we are ready to construct the full ContainerDecl AST node.
    /// ByteAlign <- KEYWORD_align LPAREN Expr RPAREN
    fn parseByteAlign(p: *Parser) !Node.Index {
        _ = p.eatToken(.Keyword_align) orelse return null_node;
        _ = try p.expectToken(.LParen);
        const expr = try p.expectExpr();
        _ = try p.expectToken(.RParen);
        return expr;
    }

    /// SwitchProngList <- (SwitchProng COMMA)* SwitchProng?
    fn parseSwitchProngList(p: *Parser) !Node.SubRange {
        return ListParseFn(parseSwitchProng)(p);
    }

    /// ParamDeclList <- (ParamDecl COMMA)* ParamDecl?
    fn parseParamDeclList(p: *Parser) !SmallSpan {
        _ = try p.expectToken(.LParen);
        if (p.eatToken(.RParen)) |_| {
            return SmallSpan{ .zero_or_one = 0 };
        }
        const param_one = while (true) {
            const param = try p.expectParamDecl();
            if (param != 0) break param;
            switch (p.token_tags[p.nextToken()]) {
                .Comma => continue,
                .RParen => return SmallSpan{ .zero_or_one = 0 },
                else => {
                    // This is likely just a missing comma;
                    // give an error but continue parsing this list.
                    p.tok_i -= 1;
                    try p.warn(.{
                        .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                    });
                },
            }
        } else unreachable;

        const param_two = while (true) {
            switch (p.token_tags[p.nextToken()]) {
                .Comma => {
                    if (p.eatToken(.RParen)) |_| {
                        return SmallSpan{ .zero_or_one = param_one };
                    }
                    const param = try p.expectParamDecl();
                    if (param != 0) break param;
                    continue;
                },
                .RParen => return SmallSpan{ .zero_or_one = param_one },
                .Colon, .RBrace, .RBracket => {
                    p.tok_i -= 1;
                    return p.fail(.{
                        .ExpectedToken = .{ .token = p.tok_i, .expected_id = .RParen },
                    });
                },
                else => {
                    // This is likely just a missing comma;
                    // give an error but continue parsing this list.
                    p.tok_i -= 1;
                    try p.warn(.{
                        .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                    });
                },
            }
        } else unreachable;

        var list = std.ArrayList(Node.Index).init(p.gpa);
        defer list.deinit();

        try list.appendSlice(&[_]Node.Index{ param_one, param_two });

        while (true) {
            switch (p.token_tags[p.nextToken()]) {
                .Comma => {
                    if (p.token_tags[p.tok_i] == .RParen) {
                        p.tok_i += 1;
                        return SmallSpan{ .multi = list.toOwnedSlice() };
                    }
                    const param = try p.expectParamDecl();
                    if (param != 0) {
                        try list.append(param);
                    }
                    continue;
                },
                .RParen => return SmallSpan{ .multi = list.toOwnedSlice() },
                .Colon, .RBrace, .RBracket => {
                    p.tok_i -= 1;
                    return p.fail(.{
                        .ExpectedToken = .{ .token = p.tok_i, .expected_id = .RParen },
                    });
                },
                else => {
                    // This is likely just a missing comma;
                    // give an error but continue parsing this list.
                    p.tok_i -= 1;
                    try p.warn(.{
                        .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                    });
                },
            }
        }
    }

    const NodeParseFn = fn (p: *Parser) Error!Node.Index;

    fn ListParseFn(comptime nodeParseFn: anytype) (fn (p: *Parser) Error!Node.SubRange) {
        return struct {
            pub fn parse(p: *Parser) Error!Node.SubRange {
                var list = std.ArrayList(Node.Index).init(p.gpa);
                defer list.deinit();

                while (true) {
                    const item = try nodeParseFn(p);
                    if (item == 0) break;

                    try list.append(item);

                    switch (p.token_tags[p.tok_i]) {
                        .Comma => p.tok_i += 1,
                        // all possible delimiters
                        .Colon, .RParen, .RBrace, .RBracket => break,
                        else => {
                            // This is likely just a missing comma;
                            // give an error but continue parsing this list.
                            try p.warn(.{
                                .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                            });
                        },
                    }
                }
                return p.listToSpan(list.items);
            }
        }.parse;
    }

    /// FnCallArguments <- LPAREN ExprList RPAREN
    /// ExprList <- (Expr COMMA)* Expr?
    fn parseBuiltinCall(p: *Parser) !Node.Index {
        const builtin_token = p.assertToken(.Builtin);
        _ = (try p.expectTokenRecoverable(.LParen)) orelse {
            try p.warn(.{
                .ExpectedParamList = .{ .token = p.tok_i },
            });
            // Pretend this was an identifier so we can continue parsing.
            return p.addNode(.{
                .tag = .Identifier,
                .main_token = builtin_token,
                .data = .{
                    .lhs = undefined,
                    .rhs = undefined,
                },
            });
        };
        if (p.eatToken(.RParen)) |_| {
            return p.addNode(.{
                .tag = .BuiltinCallTwo,
                .main_token = builtin_token,
                .data = .{
                    .lhs = 0,
                    .rhs = 0,
                },
            });
        }
        const param_one = try p.expectExpr();
        switch (p.token_tags[p.nextToken()]) {
            .Comma => {
                if (p.eatToken(.RParen)) |_| {
                    return p.addNode(.{
                        .tag = .BuiltinCallTwoComma,
                        .main_token = builtin_token,
                        .data = .{
                            .lhs = param_one,
                            .rhs = 0,
                        },
                    });
                }
            },
            .RParen => return p.addNode(.{
                .tag = .BuiltinCallTwo,
                .main_token = builtin_token,
                .data = .{
                    .lhs = param_one,
                    .rhs = 0,
                },
            }),
            else => {
                // This is likely just a missing comma;
                // give an error but continue parsing this list.
                p.tok_i -= 1;
                try p.warn(.{
                    .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                });
            },
        }
        const param_two = try p.expectExpr();
        switch (p.token_tags[p.nextToken()]) {
            .Comma => {
                if (p.eatToken(.RParen)) |_| {
                    return p.addNode(.{
                        .tag = .BuiltinCallTwoComma,
                        .main_token = builtin_token,
                        .data = .{
                            .lhs = param_one,
                            .rhs = param_two,
                        },
                    });
                }
            },
            .RParen => return p.addNode(.{
                .tag = .BuiltinCallTwo,
                .main_token = builtin_token,
                .data = .{
                    .lhs = param_one,
                    .rhs = param_two,
                },
            }),
            else => {
                // This is likely just a missing comma;
                // give an error but continue parsing this list.
                p.tok_i -= 1;
                try p.warn(.{
                    .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                });
            },
        }

        var list = std.ArrayList(Node.Index).init(p.gpa);
        defer list.deinit();

        try list.appendSlice(&[_]Node.Index{ param_one, param_two });

        while (true) {
            const param = try p.expectExpr();
            try list.append(param);
            switch (p.token_tags[p.nextToken()]) {
                .Comma => {
                    if (p.eatToken(.RParen)) |_| {
                        const params = try p.listToSpan(list.items);
                        return p.addNode(.{
                            .tag = .BuiltinCallComma,
                            .main_token = builtin_token,
                            .data = .{
                                .lhs = params.start,
                                .rhs = params.end,
                            },
                        });
                    }
                    continue;
                },
                .RParen => {
                    const params = try p.listToSpan(list.items);
                    return p.addNode(.{
                        .tag = .BuiltinCall,
                        .main_token = builtin_token,
                        .data = .{
                            .lhs = params.start,
                            .rhs = params.end,
                        },
                    });
                },
                else => {
                    // This is likely just a missing comma;
                    // give an error but continue parsing this list.
                    p.tok_i -= 1;
                    try p.warn(.{
                        .ExpectedToken = .{ .token = p.tok_i, .expected_id = .Comma },
                    });
                },
            }
        }
    }

    // string literal or multiline string literal
    fn parseStringLiteral(p: *Parser) !Node.Index {
        switch (p.token_tags[p.tok_i]) {
            .StringLiteral => {
                const main_token = p.nextToken();
                return p.addNode(.{
                    .tag = .StringLiteral,
                    .main_token = main_token,
                    .data = .{
                        .lhs = main_token,
                        .rhs = main_token,
                    },
                });
            },
            .MultilineStringLiteralLine => {
                const first_line = p.nextToken();
                while (p.token_tags[p.tok_i] == .MultilineStringLiteralLine) {
                    p.tok_i += 1;
                }
                return p.addNode(.{
                    .tag = .StringLiteral,
                    .main_token = first_line,
                    .data = .{
                        .lhs = first_line,
                        .rhs = p.tok_i - 1,
                    },
                });
            },
            else => return null_node,
        }
    }

    fn expectStringLiteral(p: *Parser) !Node.Index {
        const node = try p.parseStringLiteral();
        if (node == 0) {
            return p.fail(.{ .ExpectedStringLiteral = .{ .token = p.tok_i } });
        }
        return node;
    }

    fn expectIntegerLiteral(p: *Parser) !Node.Index {
        return p.addNode(.{
            .tag = .IntegerLiteral,
            .main_token = try p.expectToken(.IntegerLiteral),
            .data = .{
                .lhs = undefined,
                .rhs = undefined,
            },
        });
    }

    /// KEYWORD_if LPAREN Expr RPAREN PtrPayload? Body (KEYWORD_else Payload? Body)?
    fn parseIf(p: *Parser, bodyParseFn: NodeParseFn) !Node.Index {
        const if_token = p.eatToken(.Keyword_if) orelse return null_node;
        _ = try p.expectToken(.LParen);
        const condition = try p.expectExpr();
        _ = try p.expectToken(.RParen);
        const then_payload = try p.parsePtrPayload();

        const then_expr = try bodyParseFn(p);
        if (then_expr == 0) return p.fail(.{ .InvalidToken = .{ .token = p.tok_i } });

        const else_token = p.eatToken(.Keyword_else) orelse return p.addNode(.{
            .tag = .IfSimple,
            .main_token = if_token,
            .data = .{
                .lhs = condition,
                .rhs = then_expr,
            },
        });
        const else_payload = try p.parsePayload();
        const else_expr = try bodyParseFn(p);
        if (else_expr == 0) return p.fail(.{ .InvalidToken = .{ .token = p.tok_i } });

        return p.addNode(.{
            .tag = .If,
            .main_token = if_token,
            .data = .{
                .lhs = condition,
                .rhs = try p.addExtra(Node.If{
                    .then_expr = then_expr,
                    .else_expr = else_expr,
                }),
            },
        });
    }

    /// Skips over doc comment tokens. Returns the first one, if any.
    fn eatDocComments(p: *Parser) ?TokenIndex {
        if (p.eatToken(.DocComment)) |first_line| {
            while (p.eatToken(.DocComment)) |_| {}
            return first_line;
        }
        return null;
    }

    fn tokensOnSameLine(p: *Parser, token1: TokenIndex, token2: TokenIndex) bool {
        return std.mem.indexOfScalar(u8, p.source[p.token_starts[token1]..p.token_starts[token2]], '\n') == null;
    }

    /// Eat a single-line doc comment on the same line as another node
    fn parseAppendedDocComment(p: *Parser, after_token: TokenIndex) !void {
        const comment_token = p.eatToken(.DocComment) orelse return;
        if (!p.tokensOnSameLine(after_token, comment_token)) {
            p.tok_i -= 1;
        }
    }

    fn eatToken(p: *Parser, tag: Token.Tag) ?TokenIndex {
        return if (p.token_tags[p.tok_i] == tag) p.nextToken() else null;
    }

    fn assertToken(p: *Parser, tag: Token.Tag) TokenIndex {
        const token = p.nextToken();
        assert(p.token_tags[token] == tag);
        return token;
    }

    fn expectToken(p: *Parser, tag: Token.Tag) Error!TokenIndex {
        const token = p.nextToken();
        if (p.token_tags[token] != tag) {
            return p.fail(.{ .ExpectedToken = .{ .token = token, .expected_id = tag } });
        }
        return token;
    }

    fn expectTokenRecoverable(p: *Parser, tag: Token.Tag) !?TokenIndex {
        if (p.token_tags[p.tok_i] != tag) {
            try p.warn(.{
                .ExpectedToken = .{ .token = p.tok_i, .expected_id = tag },
            });
            return null;
        } else {
            return p.nextToken();
        }
    }

    fn nextToken(p: *Parser) TokenIndex {
        const result = p.tok_i;
        p.tok_i += 1;
        return result;
    }
};

test {
    _ = @import("parser_test.zig");
}
