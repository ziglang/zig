const std = @import("std");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const mem = std.mem;
const ast = @import("ast.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;
const builtin = @import("builtin");
const io = std.io;

// TODO when we make parse errors into error types instead of printing directly,
// get rid of this
const warn = std.debug.warn;

error ParseError;

pub const Parser = struct {
    allocator: &mem.Allocator,
    tokenizer: &Tokenizer,
    put_back_tokens: [2]Token,
    put_back_count: usize,
    source_file_name: []const u8,
    cleanup_root_node: ?&ast.NodeRoot,

    // This memory contents are used only during a function call. It's used to repurpose memory;
    // specifically so that freeAst can be guaranteed to succeed.
    const utility_bytes_align = @alignOf( union { a: RenderAstFrame, b: State, c: RenderState } );
    utility_bytes: []align(utility_bytes_align) u8,

    pub fn init(tokenizer: &Tokenizer, allocator: &mem.Allocator, source_file_name: []const u8) -> Parser {
        return Parser {
            .allocator = allocator,
            .tokenizer = tokenizer,
            .put_back_tokens = undefined,
            .put_back_count = 0,
            .source_file_name = source_file_name,
            .utility_bytes = []align(utility_bytes_align) u8{},
            .cleanup_root_node = null,
        };
    }

    pub fn deinit(self: &Parser) {
        assert(self.cleanup_root_node == null);
        self.allocator.free(self.utility_bytes);
    }

    const TopLevelDeclCtx = struct {
        visib_token: ?Token,
        extern_token: ?Token,
    };

    const DestPtr = union(enum) {
        Field: &&ast.Node,
        NullableField: &?&ast.Node,
        List: &ArrayList(&ast.Node),

        pub fn store(self: &const DestPtr, value: &ast.Node) -> %void {
            switch (*self) {
                DestPtr.Field => |ptr| *ptr = value,
                DestPtr.NullableField => |ptr| *ptr = value,
                DestPtr.List => |list| %return list.append(value),
            }
        }
    };

    const State = union(enum) {
        TopLevel,
        TopLevelExtern: ?Token,
        TopLevelDecl: TopLevelDeclCtx,
        Expression: DestPtr,
        GroupedExpression: DestPtr,
        UnwrapExpression: DestPtr,
        BoolOrExpression: DestPtr,
        BoolAndExpression: DestPtr,
        ComparisonExpression: DestPtr,
        BinaryOrExpression: DestPtr,
        BinaryXorExpression: DestPtr,
        BinaryAndExpression: DestPtr,
        BitShiftExpression: DestPtr,
        AdditionExpression: DestPtr,
        MultiplyExpression: DestPtr,
        BraceSuffixExpression: DestPtr,
        PrefixOpExpression: DestPtr,
        AddrOfModifiers: &ast.NodeAddrOfExpr,
        SuffixOpExpression: DestPtr,
        PrimaryExpression: DestPtr,
        TypeExpr: DestPtr,
        VarDecl: &ast.NodeVarDecl,
        VarDeclAlign: &ast.NodeVarDecl,
        VarDeclEq: &ast.NodeVarDecl,
        ExpectToken: @TagType(Token.Id),
        FnProto: &ast.NodeFnProto,
        FnProtoAlign: &ast.NodeFnProto,
        ParamDecl: &ast.NodeFnProto,
        ParamDeclComma,
        FnDef: &ast.NodeFnProto,
        Block: &ast.NodeBlock,
        Statement: &ast.NodeBlock,
    };

    pub fn freeAst(self: &Parser, root_node: &ast.NodeRoot) {
        // utility_bytes is big enough to do this iteration since we were able to do
        // the parsing in the first place
        comptime assert(@sizeOf(State) >= @sizeOf(&ast.Node));

        var stack = self.initUtilityArrayList(&ast.Node);
        defer self.deinitUtilityArrayList(stack);

        stack.append(&root_node.base) %% unreachable;
        while (stack.popOrNull()) |node| {
            var i: usize = 0;
            while (node.iterate(i)) |child| : (i += 1) {
                if (child.iterate(0) != null) {
                    stack.append(child) %% unreachable;
                } else {
                    child.destroy(self.allocator);
                }
            }
            node.destroy(self.allocator);
        }
    }

    pub fn parse(self: &Parser) -> %&ast.NodeRoot {
        const result = self.parseInner() %% |err| {
            if (self.cleanup_root_node) |root_node| {
                self.freeAst(root_node);
            }
            err
        };
        self.cleanup_root_node = null;
        return result;
    }

    pub fn parseInner(self: &Parser) -> %&ast.NodeRoot {
        var stack = self.initUtilityArrayList(State);
        defer self.deinitUtilityArrayList(stack);

        const root_node = {
            const root_node = %return self.createRoot();
            %defer self.allocator.destroy(root_node);
            // This stack append has to succeed for freeAst to work
            %return stack.append(State.TopLevel);
            root_node
        };
        assert(self.cleanup_root_node == null);
        self.cleanup_root_node = root_node;

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

            // This gives us 1 free append that can't fail
            const state = stack.pop();

            switch (state) {
                State.TopLevel => {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_pub, Token.Id.Keyword_export => {
                            stack.append(State { .TopLevelExtern = token }) %% unreachable;
                            continue;
                        },
                        Token.Id.Eof => return root_node,
                        else => {
                            self.putBackToken(token);
                            // TODO shouldn't need this cast
                            stack.append(State { .TopLevelExtern = null }) %% unreachable;
                            continue;
                        },
                    }
                },
                State.TopLevelExtern => |visib_token| {
                    const token = self.getNextToken();
                    if (token.id == Token.Id.Keyword_extern) {
                        stack.append(State {
                            .TopLevelDecl = TopLevelDeclCtx {
                                .visib_token = visib_token,
                                .extern_token = token,
                            },
                        }) %% unreachable;
                        continue;
                    }
                    self.putBackToken(token);
                    stack.append(State {
                        .TopLevelDecl = TopLevelDeclCtx {
                            .visib_token = visib_token,
                            .extern_token = null,
                        },
                    }) %% unreachable;
                    continue;
                },
                State.TopLevelDecl => |ctx| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_var, Token.Id.Keyword_const => {
                            stack.append(State.TopLevel) %% unreachable;
                            // TODO shouldn't need these casts
                            const var_decl_node = %return self.createAttachVarDecl(&root_node.decls, ctx.visib_token,
                                token, (?Token)(null), ctx.extern_token);
                            %return stack.append(State { .VarDecl = var_decl_node });
                            continue;
                        },
                        Token.Id.Keyword_fn => {
                            stack.append(State.TopLevel) %% unreachable;
                            // TODO shouldn't need these casts
                            const fn_proto = %return self.createAttachFnProto(&root_node.decls, token,
                                ctx.extern_token, (?Token)(null), (?Token)(null), (?Token)(null));
                            %return stack.append(State { .FnDef = fn_proto });
                            %return stack.append(State { .FnProto = fn_proto });
                            continue;
                        },
                        Token.Id.StringLiteral => {
                            @panic("TODO extern with string literal");
                        },
                        Token.Id.Keyword_coldcc, Token.Id.Keyword_nakedcc, Token.Id.Keyword_stdcallcc => {
                            stack.append(State.TopLevel) %% unreachable;
                            const fn_token = %return self.eatToken(Token.Id.Keyword_fn);
                            // TODO shouldn't need this cast
                            const fn_proto = %return self.createAttachFnProto(&root_node.decls, fn_token,
                                ctx.extern_token, (?Token)(token), (?Token)(null), (?Token)(null));
                            %return stack.append(State { .FnDef = fn_proto });
                            %return stack.append(State { .FnProto = fn_proto });
                            continue;
                        },
                        else => return self.parseError(token, "expected variable declaration or function, found {}", @tagName(token.id)),
                    }
                },
                State.VarDecl => |var_decl| {
                    var_decl.name_token = %return self.eatToken(Token.Id.Identifier);
                    stack.append(State { .VarDeclAlign = var_decl }) %% unreachable;

                    const next_token = self.getNextToken();
                    if (next_token.id == Token.Id.Colon) {
                        %return stack.append(State { .TypeExpr = DestPtr {.NullableField = &var_decl.type_node} });
                        continue;
                    }

                    self.putBackToken(next_token);
                    continue;
                },
                State.VarDeclAlign => |var_decl| {
                    stack.append(State { .VarDeclEq = var_decl }) %% unreachable;

                    const next_token = self.getNextToken();
                    if (next_token.id == Token.Id.Keyword_align) {
                        %return stack.append(State {
                            .GroupedExpression = DestPtr {
                                .NullableField = &var_decl.align_node
                            }
                        });
                        continue;
                    }

                    self.putBackToken(next_token);
                    continue;
                },
                State.VarDeclEq => |var_decl| {
                    const token = self.getNextToken();
                    if (token.id == Token.Id.Equal) {
                        var_decl.eq_token = token;
                        stack.append(State { .ExpectToken = Token.Id.Semicolon }) %% unreachable;
                        %return stack.append(State {
                            .Expression = DestPtr {.NullableField = &var_decl.init_node},
                        });
                        continue;
                    }
                    if (token.id == Token.Id.Semicolon) {
                        continue;
                    }
                    return self.parseError(token, "expected '=' or ';', found {}", @tagName(token.id));
                },
                State.ExpectToken => |token_id| {
                    _ = %return self.eatToken(token_id);
                    continue;
                },
                State.Expression => |dest_ptr| {
                    const token = self.getNextToken();
                    if (token.id == Token.Id.Keyword_return) {
                        const return_node = %return self.createAttachReturn(dest_ptr, token);
                        stack.append(State {.UnwrapExpression = DestPtr {.Field = &return_node.expr} }) %% unreachable;
                        continue;
                    }
                    self.putBackToken(token);
                    stack.append(State {.UnwrapExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.UnwrapExpression => |dest_ptr| {
                    stack.append(State {.BoolOrExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BoolOrExpression => |dest_ptr| {
                    stack.append(State {.BoolAndExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BoolAndExpression => |dest_ptr| {
                    stack.append(State {.ComparisonExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.ComparisonExpression => |dest_ptr| {
                    stack.append(State {.BinaryOrExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BinaryOrExpression => |dest_ptr| {
                    stack.append(State {.BinaryXorExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BinaryXorExpression => |dest_ptr| {
                    stack.append(State {.BinaryAndExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BinaryAndExpression => |dest_ptr| {
                    stack.append(State {.BitShiftExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BitShiftExpression => |dest_ptr| {
                    stack.append(State {.AdditionExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.AdditionExpression => |dest_ptr| {
                    stack.append(State {.MultiplyExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.MultiplyExpression => |dest_ptr| {
                    stack.append(State {.BraceSuffixExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BraceSuffixExpression => |dest_ptr| {
                    stack.append(State {.PrefixOpExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.PrefixOpExpression => |dest_ptr| {
                    const first_token = self.getNextToken();
                    switch (first_token.id) {
                        Token.Id.Ampersand => {
                            const addr_of_expr = %return self.createAttachAddrOfExpr(dest_ptr, first_token);
                            stack.append(State { .AddrOfModifiers = addr_of_expr }) %% unreachable;
                            continue;
                        },
                        else => {
                            self.putBackToken(first_token);
                            stack.append(State { .SuffixOpExpression = dest_ptr }) %% unreachable;
                            continue;
                        },
                    }
                },

                State.AddrOfModifiers => |addr_of_expr| {
                    var token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_align => {
                            stack.append(State { .AddrOfModifiers = addr_of_expr }) %% unreachable;
                            if (addr_of_expr.align_expr != null) return self.parseError(token, "multiple align qualifiers");
                            _ = %return self.eatToken(Token.Id.LParen);
                            %return stack.append(State { .ExpectToken = Token.Id.RParen });
                            %return stack.append(State { .Expression = DestPtr{.NullableField = &addr_of_expr.align_expr} });
                            continue;
                        },
                        Token.Id.Keyword_const => {
                            if (addr_of_expr.const_token != null) return self.parseError(token, "duplicate qualifier: const");
                            addr_of_expr.const_token = token;
                            stack.append(State { .AddrOfModifiers = addr_of_expr }) %% unreachable;
                            continue;
                        },
                        Token.Id.Keyword_volatile => {
                            if (addr_of_expr.volatile_token != null) return self.parseError(token, "duplicate qualifier: volatile");
                            addr_of_expr.volatile_token = token;
                            stack.append(State { .AddrOfModifiers = addr_of_expr }) %% unreachable;
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            stack.append(State {
                                .PrefixOpExpression = DestPtr { .Field = &addr_of_expr.op_expr},
                            }) %% unreachable;
                            continue;
                        },
                    }
                },

                State.SuffixOpExpression => |dest_ptr| {
                    stack.append(State { .PrimaryExpression = dest_ptr }) %% unreachable;
                    continue;
                },

                State.PrimaryExpression => |dest_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Identifier => {
                            _ = %return self.createAttachIdentifier(dest_ptr, token);
                            continue;
                        },
                        Token.Id.IntegerLiteral => {
                            _ = %return self.createAttachIntegerLiteral(dest_ptr, token);
                            continue;
                        },
                        Token.Id.FloatLiteral => {
                            _ = %return self.createAttachFloatLiteral(dest_ptr, token);
                            continue;
                        },
                        else => return self.parseError(token, "expected primary expression, found {}", @tagName(token.id)),
                    }
                },

                State.TypeExpr => |dest_ptr| {
                    const token = self.getNextToken();
                    if (token.id == Token.Id.Keyword_var) {
                        @panic("TODO param with type var");
                    }
                    self.putBackToken(token);

                    stack.append(State { .PrefixOpExpression = dest_ptr }) %% unreachable;
                    continue;
                },

                State.FnProto => |fn_proto| {
                    stack.append(State { .FnProtoAlign = fn_proto }) %% unreachable;
                    %return stack.append(State { .ParamDecl = fn_proto });
                    %return stack.append(State { .ExpectToken = Token.Id.LParen });

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
                    if (token.id == Token.Id.Arrow) {
                        stack.append(State {
                            .TypeExpr = DestPtr {.NullableField = &fn_proto.return_type},
                        }) %% unreachable;
                        continue;
                    } else {
                        self.putBackToken(token);
                        continue;
                    }
                },

                State.ParamDecl => |fn_proto| {
                    var token = self.getNextToken();
                    if (token.id == Token.Id.RParen) {
                        continue;
                    }
                    const param_decl = %return self.createAttachParamDecl(&fn_proto.params);
                    if (token.id == Token.Id.Keyword_comptime) {
                        param_decl.comptime_token = token;
                        token = self.getNextToken();
                    } else if (token.id == Token.Id.Keyword_noalias) {
                        param_decl.noalias_token = token;
                        token = self.getNextToken();
                    };
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
                        stack.append(State { .ExpectToken = Token.Id.RParen }) %% unreachable;
                        continue;
                    } else {
                        self.putBackToken(token);
                    }

                    stack.append(State { .ParamDecl = fn_proto }) %% unreachable;
                    %return stack.append(State.ParamDeclComma);
                    %return stack.append(State {
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
                            const block = %return self.createBlock(token);
                            fn_proto.body_node = &block.base;
                            stack.append(State { .Block = block }) %% unreachable;
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
                            stack.append(State { .Block = block }) %% unreachable;
                            %return stack.append(State { .Statement = block });
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
                                const var_decl = %return self.createAttachVarDecl(&block.statements, (?Token)(null),
                                    mut_token, (?Token)(comptime_token), (?Token)(null));
                                %return stack.append(State { .VarDecl = var_decl });
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
                            const var_decl = %return self.createAttachVarDecl(&block.statements, (?Token)(null),
                                mut_token, (?Token)(null), (?Token)(null));
                            %return stack.append(State { .VarDecl = var_decl });
                            continue;
                        }
                        self.putBackToken(mut_token);
                    }

                    stack.append(State { .ExpectToken = Token.Id.Semicolon }) %% unreachable;
                    %return stack.append(State { .Expression = DestPtr{.List = &block.statements} });
                    continue;
                },

                State.GroupedExpression => @panic("TODO"),
            }
            unreachable;
        }
    }

    fn createRoot(self: &Parser) -> %&ast.NodeRoot {
        const node = %return self.allocator.create(ast.NodeRoot);
        %defer self.allocator.destroy(node);

        *node = ast.NodeRoot {
            .base = ast.Node {.id = ast.Node.Id.Root},
            .decls = ArrayList(&ast.Node).init(self.allocator),
        };
        return node;
    }

    fn createVarDecl(self: &Parser, visib_token: &const ?Token, mut_token: &const Token, comptime_token: &const ?Token,
        extern_token: &const ?Token) -> %&ast.NodeVarDecl
    {
        const node = %return self.allocator.create(ast.NodeVarDecl);
        %defer self.allocator.destroy(node);

        *node = ast.NodeVarDecl {
            .base = ast.Node {.id = ast.Node.Id.VarDecl},
            .visib_token = *visib_token,
            .mut_token = *mut_token,
            .comptime_token = *comptime_token,
            .extern_token = *extern_token,
            .type_node = null,
            .align_node = null,
            .init_node = null,
            .lib_name = null,
            // initialized later
            .name_token = undefined,
            .eq_token = undefined,
        };
        return node;
    }

    fn createFnProto(self: &Parser, fn_token: &const Token, extern_token: &const ?Token,
        cc_token: &const ?Token, visib_token: &const ?Token, inline_token: &const ?Token) -> %&ast.NodeFnProto
    {
        const node = %return self.allocator.create(ast.NodeFnProto);
        %defer self.allocator.destroy(node);

        *node = ast.NodeFnProto {
            .base = ast.Node {.id = ast.Node.Id.FnProto},
            .visib_token = *visib_token,
            .name_token = null,
            .fn_token = *fn_token,
            .params = ArrayList(&ast.Node).init(self.allocator),
            .return_type = null,
            .var_args_token = null,
            .extern_token = *extern_token,
            .inline_token = *inline_token,
            .cc_token = *cc_token,
            .body_node = null,
            .lib_name = null,
            .align_expr = null,
        };
        return node;
    }

    fn createParamDecl(self: &Parser) -> %&ast.NodeParamDecl {
        const node = %return self.allocator.create(ast.NodeParamDecl);
        %defer self.allocator.destroy(node);

        *node = ast.NodeParamDecl {
            .base = ast.Node {.id = ast.Node.Id.ParamDecl},
            .comptime_token = null,
            .noalias_token = null,
            .name_token = null,
            .type_node = undefined,
            .var_args_token = null,
        };
        return node;
    }

    fn createAddrOfExpr(self: &Parser, op_token: &const Token) -> %&ast.NodeAddrOfExpr {
        const node = %return self.allocator.create(ast.NodeAddrOfExpr);
        %defer self.allocator.destroy(node);

        *node = ast.NodeAddrOfExpr {
            .base = ast.Node {.id = ast.Node.Id.AddrOfExpr},
            .align_expr = null,
            .op_token = *op_token,
            .bit_offset_start_token = null,
            .bit_offset_end_token = null,
            .const_token = null,
            .volatile_token = null,
            .op_expr = undefined,
        };
        return node;
    }

    fn createBlock(self: &Parser, begin_token: &const Token) -> %&ast.NodeBlock {
        const node = %return self.allocator.create(ast.NodeBlock);
        %defer self.allocator.destroy(node);

        *node = ast.NodeBlock {
            .base = ast.Node {.id = ast.Node.Id.Block},
            .begin_token = *begin_token,
            .end_token = undefined,
            .statements = ArrayList(&ast.Node).init(self.allocator),
        };
        return node;
    }

    fn createReturn(self: &Parser, return_token: &const Token) -> %&ast.NodeReturn {
        const node = %return self.allocator.create(ast.NodeReturn);
        %defer self.allocator.destroy(node);

        *node = ast.NodeReturn {
            .base = ast.Node {.id = ast.Node.Id.Return},
            .return_token = *return_token,
            .expr = undefined,
        };
        return node;
    }

    fn createIdentifier(self: &Parser, name_token: &const Token) -> %&ast.NodeIdentifier {
        const node = %return self.allocator.create(ast.NodeIdentifier);
        %defer self.allocator.destroy(node);

        *node = ast.NodeIdentifier {
            .base = ast.Node {.id = ast.Node.Id.Identifier},
            .name_token = *name_token,
        };
        return node;
    }

    fn createIntegerLiteral(self: &Parser, token: &const Token) -> %&ast.NodeIntegerLiteral {
        const node = %return self.allocator.create(ast.NodeIntegerLiteral);
        %defer self.allocator.destroy(node);

        *node = ast.NodeIntegerLiteral {
            .base = ast.Node {.id = ast.Node.Id.IntegerLiteral},
            .token = *token,
        };
        return node;
    }

    fn createFloatLiteral(self: &Parser, token: &const Token) -> %&ast.NodeFloatLiteral {
        const node = %return self.allocator.create(ast.NodeFloatLiteral);
        %defer self.allocator.destroy(node);

        *node = ast.NodeFloatLiteral {
            .base = ast.Node {.id = ast.Node.Id.FloatLiteral},
            .token = *token,
        };
        return node;
    }

    fn createAttachFloatLiteral(self: &Parser, dest_ptr: &const DestPtr, token: &const Token) -> %&ast.NodeFloatLiteral {
        const node = %return self.createFloatLiteral(token);
        %defer self.allocator.destroy(node);
        %return dest_ptr.store(&node.base);
        return node;
    }

    fn createAttachIntegerLiteral(self: &Parser, dest_ptr: &const DestPtr, token: &const Token) -> %&ast.NodeIntegerLiteral {
        const node = %return self.createIntegerLiteral(token);
        %defer self.allocator.destroy(node);
        %return dest_ptr.store(&node.base);
        return node;
    }

    fn createAttachIdentifier(self: &Parser, dest_ptr: &const DestPtr, name_token: &const Token) -> %&ast.NodeIdentifier {
        const node = %return self.createIdentifier(name_token);
        %defer self.allocator.destroy(node);
        %return dest_ptr.store(&node.base);
        return node;
    }

    fn createAttachReturn(self: &Parser, dest_ptr: &const DestPtr, return_token: &const Token) -> %&ast.NodeReturn {
        const node = %return self.createReturn(return_token);
        %defer self.allocator.destroy(node);
        %return dest_ptr.store(&node.base);
        return node;
    }

    fn createAttachAddrOfExpr(self: &Parser, dest_ptr: &const DestPtr, op_token: &const Token) -> %&ast.NodeAddrOfExpr {
        const node = %return self.createAddrOfExpr(op_token);
        %defer self.allocator.destroy(node);
        %return dest_ptr.store(&node.base);
        return node;
    }

    fn createAttachParamDecl(self: &Parser, list: &ArrayList(&ast.Node)) -> %&ast.NodeParamDecl {
        const node = %return self.createParamDecl();
        %defer self.allocator.destroy(node);
        %return list.append(&node.base);
        return node;
    }

    fn createAttachFnProto(self: &Parser, list: &ArrayList(&ast.Node), fn_token: &const Token,
        extern_token: &const ?Token, cc_token: &const ?Token, visib_token: &const ?Token,
        inline_token: &const ?Token) -> %&ast.NodeFnProto
    {
        const node = %return self.createFnProto(fn_token, extern_token, cc_token, visib_token, inline_token);
        %defer self.allocator.destroy(node);
        %return list.append(&node.base);
        return node;
    }

    fn createAttachVarDecl(self: &Parser, list: &ArrayList(&ast.Node), visib_token: &const ?Token,
        mut_token: &const Token, comptime_token: &const ?Token, extern_token: &const ?Token) -> %&ast.NodeVarDecl
    {
        const node = %return self.createVarDecl(visib_token, mut_token, comptime_token, extern_token);
        %defer self.allocator.destroy(node);
        %return list.append(&node.base);
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

    const RenderAstFrame = struct {
        node: &ast.Node,
        indent: usize,
    };

    pub fn renderAst(self: &Parser, stream: &std.io.OutStream, root_node: &ast.NodeRoot) -> %void {
        var stack = self.initUtilityArrayList(RenderAstFrame);
        defer self.deinitUtilityArrayList(stack);

        %return stack.append(RenderAstFrame {
            .node = &root_node.base,
            .indent = 0,
        });

        while (stack.popOrNull()) |frame| {
            {
                var i: usize = 0;
                while (i < frame.indent) : (i += 1) {
                    %return stream.print(" ");
                }
            }
            %return stream.print("{}\n", @tagName(frame.node.id));
            var child_i: usize = 0;
            while (frame.node.iterate(child_i)) |child| : (child_i += 1) {
                %return stack.append(RenderAstFrame {
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
        AddrOfExprBit: &ast.NodeAddrOfExpr,
        VarDecl: &ast.NodeVarDecl,
        VarDeclAlign: &ast.NodeVarDecl,
        Statement: &ast.Node,
        PrintIndent,
        Indent: usize,
    };

    pub fn renderSource(self: &Parser, stream: &std.io.OutStream, root_node: &ast.NodeRoot) -> %void {
        var stack = self.initUtilityArrayList(RenderState);
        defer self.deinitUtilityArrayList(stack);

        {
            var i = root_node.decls.len;
            while (i != 0) {
                i -= 1;
                const decl = root_node.decls.items[i];
                %return stack.append(RenderState {.TopLevelDecl = decl});
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
                            if (fn_proto.visib_token) |visib_token| {
                                switch (visib_token.id) {
                                    Token.Id.Keyword_pub => %return stream.print("pub "),
                                    Token.Id.Keyword_export => %return stream.print("export "),
                                    else => unreachable,
                                };
                            }
                            if (fn_proto.extern_token) |extern_token| {
                                %return stream.print("{} ", self.tokenizer.getTokenSlice(extern_token));
                            }
                            %return stream.print("fn");

                            if (fn_proto.name_token) |name_token| {
                                %return stream.print(" {}", self.tokenizer.getTokenSlice(name_token));
                            }

                            %return stream.print("(");

                            %return stack.append(RenderState { .Text = "\n" });
                            if (fn_proto.body_node == null) {
                                %return stack.append(RenderState { .Text = ";" });
                            }

                            %return stack.append(RenderState { .FnProtoRParen = fn_proto});
                            var i = fn_proto.params.len;
                            while (i != 0) {
                                i -= 1;
                                const param_decl_node = fn_proto.params.items[i];
                                %return stack.append(RenderState { .ParamDecl = param_decl_node});
                                if (i != 0) {
                                    %return stack.append(RenderState { .Text = ", " });
                                }
                            }
                        },
                        ast.Node.Id.VarDecl => {
                            const var_decl = @fieldParentPtr(ast.NodeVarDecl, "base", decl);
                            %return stack.append(RenderState { .Text = "\n"});
                            %return stack.append(RenderState { .VarDecl = var_decl});

                        },
                        else => unreachable,
                    }
                },

                RenderState.VarDecl => |var_decl| {
                    if (var_decl.visib_token) |visib_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(visib_token));
                    }
                    if (var_decl.extern_token) |extern_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(extern_token));
                        if (var_decl.lib_name != null) {
                            @panic("TODO");
                        }
                    }
                    if (var_decl.comptime_token) |comptime_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(comptime_token));
                    }
                    %return stream.print("{} ", self.tokenizer.getTokenSlice(var_decl.mut_token));
                    %return stream.print("{}", self.tokenizer.getTokenSlice(var_decl.name_token));

                    %return stack.append(RenderState { .VarDeclAlign = var_decl });
                    if (var_decl.type_node) |type_node| {
                        %return stream.print(": ");
                        %return stack.append(RenderState { .Expression = type_node });
                    }
                },

                RenderState.VarDeclAlign => |var_decl| {
                    if (var_decl.align_node != null) {
                        @panic("TODO");
                    }
                    %return stack.append(RenderState { .Text = ";" });
                    if (var_decl.init_node) |init_node| {
                        %return stream.print(" = ");
                        %return stack.append(RenderState { .Expression = init_node });
                    }
                },

                RenderState.ParamDecl => |base| {
                    const param_decl = @fieldParentPtr(ast.NodeParamDecl, "base", base);
                    if (param_decl.comptime_token) |comptime_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(comptime_token));
                    }
                    if (param_decl.noalias_token) |noalias_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(noalias_token));
                    }
                    if (param_decl.name_token) |name_token| {
                        %return stream.print("{}: ", self.tokenizer.getTokenSlice(name_token));
                    }
                    if (param_decl.var_args_token) |var_args_token| {
                        %return stream.print("{}", self.tokenizer.getTokenSlice(var_args_token));
                    } else {
                        %return stack.append(RenderState { .Expression = param_decl.type_node});
                    }
                },
                RenderState.Text => |bytes| {
                    %return stream.write(bytes);
                },
                RenderState.Expression => |base| switch (base.id) {
                    ast.Node.Id.Identifier => {
                        const identifier = @fieldParentPtr(ast.NodeIdentifier, "base", base);
                        %return stream.print("{}", self.tokenizer.getTokenSlice(identifier.name_token));
                    },
                    ast.Node.Id.AddrOfExpr => {
                        const addr_of_expr = @fieldParentPtr(ast.NodeAddrOfExpr, "base", base);
                        %return stream.print("{}", self.tokenizer.getTokenSlice(addr_of_expr.op_token));
                        %return stack.append(RenderState { .AddrOfExprBit = addr_of_expr});

                        if (addr_of_expr.align_expr) |align_expr| {
                            %return stream.print("align(");
                            %return stack.append(RenderState { .Text = ") "});
                            %return stack.append(RenderState { .Expression = align_expr});
                        }
                    },
                    ast.Node.Id.Block => {
                        const block = @fieldParentPtr(ast.NodeBlock, "base", base);
                        %return stream.write("{");
                        %return stack.append(RenderState { .Text = "}"});
                        %return stack.append(RenderState.PrintIndent);
                        %return stack.append(RenderState { .Indent = indent});
                        %return stack.append(RenderState { .Text = "\n"});
                        var i = block.statements.len;
                        while (i != 0) {
                            i -= 1;
                            const statement_node = block.statements.items[i];
                            %return stack.append(RenderState { .Statement = statement_node});
                            %return stack.append(RenderState.PrintIndent);
                            %return stack.append(RenderState { .Indent = indent + indent_delta});
                            %return stack.append(RenderState { .Text = "\n" });
                        }
                    },
                    ast.Node.Id.Return => {
                        const return_node = @fieldParentPtr(ast.NodeReturn, "base", base);
                        %return stream.write("return ");
                        %return stack.append(RenderState { .Expression = return_node.expr });
                    },
                    ast.Node.Id.IntegerLiteral => {
                        const integer_literal = @fieldParentPtr(ast.NodeIntegerLiteral, "base", base);
                        %return stream.print("{}", self.tokenizer.getTokenSlice(integer_literal.token));
                    },
                    ast.Node.Id.FloatLiteral => {
                        const float_literal = @fieldParentPtr(ast.NodeFloatLiteral, "base", base);
                        %return stream.print("{}", self.tokenizer.getTokenSlice(float_literal.token));
                    },
                    else => unreachable,
                },
                RenderState.AddrOfExprBit => |addr_of_expr| {
                    if (addr_of_expr.bit_offset_start_token) |bit_offset_start_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(bit_offset_start_token));
                    }
                    if (addr_of_expr.bit_offset_end_token) |bit_offset_end_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(bit_offset_end_token));
                    }
                    if (addr_of_expr.const_token) |const_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(const_token));
                    }
                    if (addr_of_expr.volatile_token) |volatile_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(volatile_token));
                    }
                    %return stack.append(RenderState { .Expression = addr_of_expr.op_expr});
                },
                RenderState.FnProtoRParen => |fn_proto| {
                    %return stream.print(")");
                    if (fn_proto.align_expr != null) {
                        @panic("TODO");
                    }
                    if (fn_proto.return_type) |return_type| {
                        %return stream.print(" -> ");
                        if (fn_proto.body_node) |body_node| {
                            %return stack.append(RenderState { .Expression = body_node});
                            %return stack.append(RenderState { .Text = " "});
                        }
                        %return stack.append(RenderState { .Expression = return_type});
                    }
                },
                RenderState.Statement => |base| {
                    switch (base.id) {
                        ast.Node.Id.VarDecl => {
                            const var_decl = @fieldParentPtr(ast.NodeVarDecl, "base", base);
                            %return stack.append(RenderState { .VarDecl = var_decl});
                        },
                        else => {
                            %return stack.append(RenderState { .Text = ";"});
                            %return stack.append(RenderState { .Expression = base});
                        },
                    }
                },
                RenderState.Indent => |new_indent| indent = new_indent,
                RenderState.PrintIndent => %return stream.writeByteNTimes(' ', indent),
            }
        }
    }

    fn initUtilityArrayList(self: &Parser, comptime T: type) -> ArrayList(T) {
        const new_byte_count = self.utility_bytes.len - self.utility_bytes.len % @sizeOf(T);
        self.utility_bytes = self.allocator.alignedShrink(u8, utility_bytes_align, self.utility_bytes, new_byte_count);
        const typed_slice = ([]T)(self.utility_bytes);
        return ArrayList(T) {
            .allocator = self.allocator,
            .items = typed_slice,
            .len = 0,
        };
    }

    fn deinitUtilityArrayList(self: &Parser, list: var) {
        self.utility_bytes = ([]align(utility_bytes_align) u8)(list.items);
    }

};

var fixed_buffer_mem: [100 * 1024]u8 = undefined;

fn testParse(source: []const u8, allocator: &mem.Allocator) -> %[]u8 {
    var tokenizer = Tokenizer.init(source);
    var parser = Parser.init(&tokenizer, allocator, "(memory buffer)");
    defer parser.deinit();

    const root_node = %return parser.parse();
    defer parser.freeAst(root_node);

    var buffer = %return std.Buffer.initSize(allocator, 0);
    var buffer_out_stream = io.BufferOutStream.init(&buffer);
    %return parser.renderSource(&buffer_out_stream.stream, root_node);
    return buffer.toOwnedSlice();
}

// TODO test for memory leaks
// TODO test for valid frees
fn testCanonical(source: []const u8) {
    const needed_alloc_count = {
        // Try it once with unlimited memory, make sure it works
        var fixed_allocator = mem.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
        var failing_allocator = std.debug.FailingAllocator.init(&fixed_allocator.allocator, @maxValue(usize));
        const result_source = testParse(source, &failing_allocator.allocator) %% @panic("test failed");
        if (!mem.eql(u8, result_source, source)) {
            warn("\n====== expected this output: =========\n");
            warn("{}", source);
            warn("\n======== instead found this: =========\n");
            warn("{}", result_source);
            warn("\n======================================\n");
            @panic("test failed");
        }
        failing_allocator.allocator.free(result_source);
        failing_allocator.index
    };

    // TODO make this pass
    //var fail_index = needed_alloc_count;
    //while (fail_index != 0) {
    //    fail_index -= 1;
    //    var fixed_allocator = mem.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
    //    var failing_allocator = std.debug.FailingAllocator.init(&fixed_allocator.allocator, fail_index);
    //    if (testParse(source, &failing_allocator.allocator)) |_| {
    //        @panic("non-deterministic memory usage");
    //    } else |err| {
    //        assert(err == error.OutOfMemory);
    //    }
    //}
}

test "zig fmt" {
    if (builtin.os == builtin.Os.windows and builtin.arch == builtin.Arch.i386) {
        // TODO get this test passing
        // https://github.com/zig-lang/zig/issues/537
        return;
    }

    testCanonical(
        \\extern fn puts(s: &const u8) -> c_int;
        \\
    );

    testCanonical(
        \\const a = b;
        \\pub const a = b;
        \\var a = b;
        \\pub var a = b;
        \\const a: i32 = b;
        \\pub const a: i32 = b;
        \\var a: i32 = b;
        \\pub var a: i32 = b;
        \\
    );

    testCanonical(
        \\extern var foo: c_int;
        \\
    );

    testCanonical(
        \\fn main(argc: c_int, argv: &&u8) -> c_int {
        \\    const a = b;
        \\}
        \\
    );

    testCanonical(
        \\fn foo(argc: c_int, argv: &&u8) -> c_int {
        \\    return 0;
        \\}
        \\
    );

    testCanonical(
        \\extern fn f1(s: &align(&u8) u8) -> c_int;
        \\
    );

    testCanonical(
        \\extern fn f1(s: &&align(1) &const &volatile u8) -> c_int;
        \\extern fn f2(s: &align(1) const &align(1) volatile &const volatile u8) -> c_int;
        \\extern fn f3(s: &align(1) const volatile u8) -> c_int;
        \\
    );
}
