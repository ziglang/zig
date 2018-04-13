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
        extern_export_inline_token: ?Token,
        lib_name: ?&ast.Node,
    };

    const ContainerExternCtx = struct {
        dest_ptr: DestPtr,
        ltoken: Token,
        layout: ast.NodeContainerDecl.Layout,
    };

    const DestPtr = union(enum) {
        Field: &&ast.Node,
        NullableField: &?&ast.Node,

        pub fn store(self: &const DestPtr, value: &ast.Node) void {
            switch (*self) {
                DestPtr.Field => |ptr| *ptr = value,
                DestPtr.NullableField => |ptr| *ptr = value,
            }
        }

        pub fn get(self: &const DestPtr) &ast.Node {
            switch (*self) {
                DestPtr.Field => |ptr| return *ptr,
                DestPtr.NullableField => |ptr| return ??*ptr,
            }
        }
    };

    const ExpectTokenSave = struct {
        id: Token.Id,
        ptr: &Token,
    };

    const RevertState = struct {
        parser: Parser,
        tokenizer: Tokenizer,

        // We expect, that if something is optional, then there is a field,
        // that needs to be set to null, when we revert.
        ptr: &?&ast.Node,
    };

    const ExprListCtx = struct {
        list: &ArrayList(&ast.Node),
        end: Token.Id,
        ptr: &Token,
    };

    const ElseCtx = struct {
        payload: ?DestPtr,
        body: DestPtr,
    };

    fn ListSave(comptime T: type) type {
        return struct {
            list: &ArrayList(T),
            ptr: &Token,
        };
    }

    const LabelCtx = struct {
        label: ?Token,
        dest_ptr: DestPtr,
    };

    const InlineCtx = struct {
        label: ?Token,
        inline_token: ?Token,
        dest_ptr: DestPtr,
    };

    const LoopCtx = struct {
        label: ?Token,
        inline_token: ?Token,
        loop_token: Token,
        dest_ptr: DestPtr,
    };

    const AsyncEndCtx = struct {
        dest_ptr: DestPtr,
        attribute: &ast.NodeAsyncAttribute,
    };

    const State = union(enum) {
        TopLevel,
        TopLevelExtern: TopLevelDeclCtx,
        TopLevelLibname: TopLevelDeclCtx,
        TopLevelDecl: TopLevelDeclCtx,
        ContainerExtern: ContainerExternCtx,
        ContainerDecl: &ast.NodeContainerDecl,
        SliceOrArrayAccess: &ast.NodeSuffixOp,
        AddrOfModifiers: &ast.NodePrefixOp.AddrOfInfo,
        VarDecl: &ast.NodeVarDecl,
        VarDeclAlign: &ast.NodeVarDecl,
        VarDeclEq: &ast.NodeVarDecl,
        IfToken: @TagType(Token.Id),
        IfTokenSave: ExpectTokenSave,
        ExpectToken: @TagType(Token.Id),
        ExpectTokenSave: ExpectTokenSave,
        FnProto: &ast.NodeFnProto,
        FnProtoAlign: &ast.NodeFnProto,
        FnProtoReturnType: &ast.NodeFnProto,
        ParamDecl: &ast.NodeFnProto,
        ParamDeclComma,
        FnDef: &ast.NodeFnProto,
        LabeledExpression: LabelCtx,
        Inline: InlineCtx,
        While: LoopCtx,
        For: LoopCtx,
        Block: &ast.NodeBlock,
        Else: &?&ast.NodeElse,
        WhileContinueExpr: &?&ast.Node,
        Statement: &ast.NodeBlock,
        Semicolon: &const &const ast.Node,
        AsmOutputItems: &ArrayList(&ast.NodeAsmOutput),
        AsmInputItems: &ArrayList(&ast.NodeAsmInput),
        AsmClopperItems: &ArrayList(&ast.Node),
        ExprListItemOrEnd: ExprListCtx,
        ExprListCommaOrEnd: ExprListCtx,
        FieldInitListItemOrEnd: ListSave(&ast.NodeFieldInitializer),
        FieldInitListCommaOrEnd: ListSave(&ast.NodeFieldInitializer),
        FieldListCommaOrEnd: &ast.NodeContainerDecl,
        IdentifierListItemOrEnd: ListSave(&ast.NodeIdentifier),
        IdentifierListCommaOrEnd: ListSave(&ast.NodeIdentifier),
        SwitchCaseOrEnd: ListSave(&ast.NodeSwitchCase),
        SuspendBody: &ast.NodeSuspend,
        AsyncEnd: AsyncEndCtx,
        Payload: &?&ast.NodePayload,
        PointerPayload: &?&ast.NodePointerPayload,
        PointerIndexPayload: &?&ast.NodePointerIndexPayload,
        SwitchCaseCommaOrEnd: ListSave(&ast.NodeSwitchCase),
        SwitchCaseItem: &ArrayList(&ast.Node),
        SwitchCaseItemCommaOrEnd: &ArrayList(&ast.Node),

        /// A state that can be appended before any other State. If an error occures,
        /// the parser will first try looking for the closest optional state. If an
        /// optional state is found, the parser will revert to the state it was in
        /// when the optional was added. This will polute the arena allocator with
        /// "leaked" nodes. TODO: Figure out if it's nessesary to handle leaked nodes.
        Optional: RevertState,

        Expression: DestPtr,
        RangeExpressionBegin: DestPtr,
        RangeExpressionEnd: DestPtr,
        AssignmentExpressionBegin: DestPtr,
        AssignmentExpressionEnd: DestPtr,
        UnwrapExpressionBegin: DestPtr,
        UnwrapExpressionEnd: DestPtr,
        BoolOrExpressionBegin: DestPtr,
        BoolOrExpressionEnd: DestPtr,
        BoolAndExpressionBegin: DestPtr,
        BoolAndExpressionEnd: DestPtr,
        ComparisonExpressionBegin: DestPtr,
        ComparisonExpressionEnd: DestPtr,
        BinaryOrExpressionBegin: DestPtr,
        BinaryOrExpressionEnd: DestPtr,
        BinaryXorExpressionBegin: DestPtr,
        BinaryXorExpressionEnd: DestPtr,
        BinaryAndExpressionBegin: DestPtr,
        BinaryAndExpressionEnd: DestPtr,
        BitShiftExpressionBegin: DestPtr,
        BitShiftExpressionEnd: DestPtr,
        AdditionExpressionBegin: DestPtr,
        AdditionExpressionEnd: DestPtr,
        MultiplyExpressionBegin: DestPtr,
        MultiplyExpressionEnd: DestPtr,
        CurlySuffixExpressionBegin: DestPtr,
        CurlySuffixExpressionEnd: DestPtr,
        TypeExprBegin: DestPtr,
        TypeExprEnd: DestPtr,
        PrefixOpExpression: DestPtr,
        SuffixOpExpressionBegin: DestPtr,
        SuffixOpExpressionEnd: DestPtr,
        PrimaryExpression: DestPtr,
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
        const root_node = try self.createNode(arena, ast.NodeRoot,
            ast.NodeRoot {
                .base = undefined,
                .decls = ArrayList(&ast.Node).init(arena),
                // initialized when we get the eof token
                .eof_token = undefined,
            }
        );

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
                if (self.eatToken(Token.Id.LineComment)) |line_comment| {
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
                    try node.lines.append(line_comment);
                    continue;
                }
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
                            const name = (try self.parseStringLiteral(arena, name_token)) ?? {
                                try self.parseError(&stack, name_token, "expected string literal, found {}", @tagName(name_token.id));
                                continue;
                            };
                            const lbrace = (try self.expectToken(&stack, Token.Id.LBrace)) ?? continue;

                            const block = try self.createNode(arena, ast.NodeBlock,
                                ast.NodeBlock {
                                    .base = undefined,
                                    .label = null,
                                    .lbrace = lbrace,
                                    .statements = ArrayList(&ast.Node).init(arena),
                                    .rbrace = undefined,
                                }
                            );
                            _ = try self.createAttachNode(arena, &root_node.decls, ast.NodeTestDecl,
                                ast.NodeTestDecl {
                                    .base = undefined,
                                    .test_token = token,
                                    .name = name,
                                    .body_node = &block.base,
                                }
                            );
                            stack.append(State { .Block = block }) catch unreachable;
                            continue;
                        },
                        Token.Id.Eof => {
                            root_node.eof_token = token;
                            return Tree {.root_node = root_node, .arena_allocator = arena_allocator};
                        },
                        Token.Id.Keyword_pub => {
                            stack.append(State.TopLevel) catch unreachable;
                            try stack.append(State {
                                .TopLevelExtern = TopLevelDeclCtx {
                                    .decls = &root_node.decls,
                                    .visib_token = token,
                                    .extern_export_inline_token = null,
                                    .lib_name = null,
                                }
                            });
                            continue;
                        },
                        Token.Id.Keyword_comptime => {
                            const node = try self.createAttachNode(arena, &root_node.decls, ast.NodeComptime,
                                ast.NodeComptime {
                                    .base = undefined,
                                    .comptime_token = token,
                                    .expr = undefined,
                                }
                            );
                            stack.append(State.TopLevel) catch unreachable;
                            try stack.append(State { .Expression = DestPtr { .Field = &node.expr } });
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            stack.append(State.TopLevel) catch unreachable;
                            try stack.append(State {
                                .TopLevelExtern = TopLevelDeclCtx {
                                    .decls = &root_node.decls,
                                    .visib_token = null,
                                    .extern_export_inline_token = null,
                                    .lib_name = null,
                                }
                            });
                            continue;
                        },
                    }
                },
                State.TopLevelExtern => |ctx| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_export, Token.Id.Keyword_inline => {
                            stack.append(State {
                                .TopLevelDecl = TopLevelDeclCtx {
                                    .decls = ctx.decls,
                                    .visib_token = ctx.visib_token,
                                    .extern_export_inline_token = token,
                                    .lib_name = null,
                                },
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_extern => {
                            stack.append(State {
                                .TopLevelLibname = TopLevelDeclCtx {
                                    .decls = ctx.decls,
                                    .visib_token = ctx.visib_token,
                                    .extern_export_inline_token = token,
                                    .lib_name = null,
                                },
                            }) catch unreachable;
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            stack.append(State { .TopLevelDecl = ctx }) catch unreachable;
                            continue;
                        }
                    }
                },

                State.TopLevelLibname => |ctx| {
                    const lib_name = blk: {
                        const lib_name_token = self.getNextToken();
                        break :blk (try self.parseStringLiteral(arena, lib_name_token)) ?? {
                            self.putBackToken(lib_name_token);
                            break :blk null;
                        };
                    };

                    stack.append(State {
                        .TopLevelDecl = TopLevelDeclCtx {
                            .decls = ctx.decls,
                            .visib_token = ctx.visib_token,
                            .extern_export_inline_token = ctx.extern_export_inline_token,
                            .lib_name = lib_name,
                        },
                    }) catch unreachable;
                },

                State.TopLevelDecl => |ctx| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_use => {
                            if (ctx.extern_export_inline_token != null) {
                                try self.parseError(&stack, token, "Invalid token {}", @tagName((??ctx.extern_export_inline_token).id));
                                continue;
                            }

                            const node = try self.createAttachNode(arena, ctx.decls, ast.NodeUse,
                                ast.NodeUse {
                                    .base = undefined,
                                    .visib_token = ctx.visib_token,
                                    .expr = undefined,
                                    .semicolon_token = undefined,
                                }
                            );
                            stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.Semicolon,
                                    .ptr = &node.semicolon_token,
                                }
                            }) catch unreachable;
                            try stack.append(State { .Expression = DestPtr { .Field = &node.expr } });
                            continue;
                        },
                        Token.Id.Keyword_var, Token.Id.Keyword_const => {
                            if (ctx.extern_export_inline_token) |extern_export_inline_token| {
                                if (extern_export_inline_token.id == Token.Id.Keyword_inline) {
                                    try self.parseError(&stack, token, "Invalid token {}", @tagName(extern_export_inline_token.id));
                                    continue;
                                }
                            }

                            const var_decl_node = try self.createAttachNode(arena, ctx.decls, ast.NodeVarDecl,
                                ast.NodeVarDecl {
                                    .base = undefined,
                                    .visib_token = ctx.visib_token,
                                    .mut_token = token,
                                    .comptime_token = null,
                                    .extern_export_token = ctx.extern_export_inline_token,
                                    .type_node = null,
                                    .align_node = null,
                                    .init_node = null,
                                    .lib_name = ctx.lib_name,
                                    // initialized later
                                    .name_token = undefined,
                                    .eq_token = undefined,
                                    .semicolon_token = undefined,
                                }
                            );
                            stack.append(State { .VarDecl = var_decl_node }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_fn => {
                            const fn_proto = try self.createAttachNode(arena, ctx.decls, ast.NodeFnProto,
                                ast.NodeFnProto {
                                    .base = undefined,
                                    .visib_token = ctx.visib_token,
                                    .name_token = null,
                                    .fn_token = token,
                                    .params = ArrayList(&ast.Node).init(arena),
                                    .return_type = undefined,
                                    .var_args_token = null,
                                    .extern_export_inline_token = ctx.extern_export_inline_token,
                                    .cc_token = null,
                                    .async_attr = null,
                                    .body_node = null,
                                    .lib_name = ctx.lib_name,
                                    .align_expr = null,
                                }
                            );
                            stack.append(State { .FnDef = fn_proto }) catch unreachable;
                            try stack.append(State { .FnProto = fn_proto });
                            continue;
                        },
                        Token.Id.Keyword_nakedcc, Token.Id.Keyword_stdcallcc => {
                            const fn_proto = try self.createAttachNode(arena, ctx.decls, ast.NodeFnProto,
                                ast.NodeFnProto {
                                    .base = undefined,
                                    .visib_token = ctx.visib_token,
                                    .name_token = null,
                                    .fn_token = undefined,
                                    .params = ArrayList(&ast.Node).init(arena),
                                    .return_type = undefined,
                                    .var_args_token = null,
                                    .extern_export_inline_token = ctx.extern_export_inline_token,
                                    .cc_token = token,
                                    .async_attr = null,
                                    .body_node = null,
                                    .lib_name = ctx.lib_name,
                                    .align_expr = null,
                                }
                            );
                            stack.append(State { .FnDef = fn_proto }) catch unreachable;
                            try stack.append(State { .FnProto = fn_proto });
                            try stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.Keyword_fn,
                                    .ptr = &fn_proto.fn_token,
                                }
                            });
                            continue;
                        },
                        Token.Id.Keyword_async => {
                            const async_node = try self.createNode(arena, ast.NodeAsyncAttribute,
                                ast.NodeAsyncAttribute {
                                    .base = undefined,
                                    .async_token = token,
                                    .allocator_type = null,
                                    .rangle_bracket = null,
                                }
                            );

                            const fn_proto = try self.createAttachNode(arena, ctx.decls, ast.NodeFnProto,
                                ast.NodeFnProto {
                                    .base = undefined,
                                    .visib_token = ctx.visib_token,
                                    .name_token = null,
                                    .fn_token = undefined,
                                    .params = ArrayList(&ast.Node).init(arena),
                                    .return_type = undefined,
                                    .var_args_token = null,
                                    .extern_export_inline_token = ctx.extern_export_inline_token,
                                    .cc_token = null,
                                    .async_attr = async_node,
                                    .body_node = null,
                                    .lib_name = ctx.lib_name,
                                    .align_expr = null,
                                }
                            );
                            stack.append(State { .FnDef = fn_proto }) catch unreachable;
                            try stack.append(State { .FnProto = fn_proto });
                            try stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.Keyword_fn,
                                    .ptr = &fn_proto.fn_token,
                                }
                            });

                            const langle_bracket = self.getNextToken();
                            if (langle_bracket.id != Token.Id.AngleBracketLeft) {
                                self.putBackToken(langle_bracket);
                                continue;
                            }

                            async_node.rangle_bracket = Token(undefined);
                            try stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.AngleBracketRight,
                                    .ptr = &??async_node.rangle_bracket,
                                }
                            });
                            try stack.append(State { .TypeExprBegin = DestPtr { .NullableField = &async_node.allocator_type } });
                            continue;
                        },
                        else => {
                            try self.parseError(&stack, token, "expected variable declaration or function, found {}", @tagName(token.id));
                            continue;
                        },
                    }
                },
                State.VarDecl => |var_decl| {
                    stack.append(State { .VarDeclAlign = var_decl }) catch unreachable;
                    try stack.append(State { .TypeExprBegin = DestPtr {.NullableField = &var_decl.type_node} });
                    try stack.append(State { .IfToken = Token.Id.Colon });
                    try stack.append(State {
                        .ExpectTokenSave = ExpectTokenSave {
                            .id = Token.Id.Identifier,
                            .ptr = &var_decl.name_token,
                        }
                    });
                    continue;
                },
                State.VarDeclAlign => |var_decl| {
                    stack.append(State { .VarDeclEq = var_decl }) catch unreachable;

                    const next_token = self.getNextToken();
                    if (next_token.id == Token.Id.Keyword_align) {
                        try stack.append(State { .ExpectToken = Token.Id.RParen });
                        try stack.append(State { .Expression = DestPtr{.NullableField = &var_decl.align_node} });
                        try stack.append(State { .ExpectToken = Token.Id.LParen });
                        continue;
                    }

                    self.putBackToken(next_token);
                    continue;
                },
                State.VarDeclEq => |var_decl| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Equal => {
                            var_decl.eq_token = token;
                            stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.Semicolon,
                                    .ptr = &var_decl.semicolon_token,
                                },
                            }) catch unreachable;
                            try stack.append(State { .Expression = DestPtr {.NullableField = &var_decl.init_node} });
                            continue;
                        },
                        Token.Id.Semicolon => {
                            var_decl.semicolon_token = token;
                            continue;
                        },
                        else => {
                            try self.parseError(&stack, token, "expected '=' or ';', found {}", @tagName(token.id));
                            continue;
                        }
                    }
                },

                State.ContainerExtern => |ctx| {
                    const token = self.getNextToken();
                    const node = try self.createToDestNode(arena, ctx.dest_ptr, ast.NodeContainerDecl,
                        ast.NodeContainerDecl {
                            .base = undefined,
                            .ltoken = ctx.ltoken,
                            .layout = ctx.layout,
                            .kind = switch (token.id) {
                                Token.Id.Keyword_struct => ast.NodeContainerDecl.Kind.Struct,
                                Token.Id.Keyword_union => ast.NodeContainerDecl.Kind.Union,
                                Token.Id.Keyword_enum => ast.NodeContainerDecl.Kind.Enum,
                                else => {
                                    try self.parseError(&stack, token, "expected {}, {} or {}, found {}",
                                        @tagName(Token.Id.Keyword_struct),
                                        @tagName(Token.Id.Keyword_union),
                                        @tagName(Token.Id.Keyword_enum),
                                        @tagName(token.id));
                                    continue;
                                },
                            },
                            .init_arg_expr = undefined,
                            .fields_and_decls = ArrayList(&ast.Node).init(arena),
                            .rbrace_token = undefined,
                        }
                    );

                    stack.append(State { .ContainerDecl = node }) catch unreachable;
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
                            self.putBackToken(init_arg_token);
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

                State.ContainerDecl => |container_decl| {
                    const token = self.getNextToken();

                    switch (token.id) {
                        Token.Id.Identifier => {
                            switch (container_decl.kind) {
                                ast.NodeContainerDecl.Kind.Struct => {
                                    const node = try self.createAttachNode(arena, &container_decl.fields_and_decls, ast.NodeStructField,
                                        ast.NodeStructField {
                                            .base = undefined,
                                            .visib_token = null,
                                            .name_token = token,
                                            .type_expr = undefined,
                                        }
                                    );

                                    stack.append(State { .FieldListCommaOrEnd = container_decl }) catch unreachable;
                                    try stack.append(State { .Expression = DestPtr { .Field = &node.type_expr } });
                                    try stack.append(State { .ExpectToken = Token.Id.Colon });
                                    continue;
                                },
                                ast.NodeContainerDecl.Kind.Union => {
                                    const node = try self.createAttachNode(arena, &container_decl.fields_and_decls, ast.NodeUnionTag,
                                        ast.NodeUnionTag {
                                            .base = undefined,
                                            .name_token = token,
                                            .type_expr = null,
                                        }
                                    );

                                    stack.append(State { .FieldListCommaOrEnd = container_decl }) catch unreachable;

                                    const next = self.getNextToken();
                                    if (next.id != Token.Id.Colon) {
                                        self.putBackToken(next);
                                        continue;
                                    }

                                    try stack.append(State { .Expression = DestPtr { .NullableField = &node.type_expr } });
                                    continue;
                                },
                                ast.NodeContainerDecl.Kind.Enum => {
                                    const node = try self.createAttachNode(arena, &container_decl.fields_and_decls, ast.NodeEnumTag,
                                        ast.NodeEnumTag {
                                            .base = undefined,
                                            .name_token = token,
                                            .value = null,
                                        }
                                    );

                                    stack.append(State { .FieldListCommaOrEnd = container_decl }) catch unreachable;

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
                        Token.Id.Keyword_pub => {
                            if (self.eatToken(Token.Id.Identifier)) |identifier| {
                                switch (container_decl.kind) {
                                    ast.NodeContainerDecl.Kind.Struct => {
                                        const node = try self.createAttachNode(arena, &container_decl.fields_and_decls, ast.NodeStructField,
                                            ast.NodeStructField {
                                                .base = undefined,
                                                .visib_token = token,
                                                .name_token = identifier,
                                                .type_expr = undefined,
                                            }
                                        );

                                        stack.append(State { .FieldListCommaOrEnd = container_decl }) catch unreachable;
                                        try stack.append(State { .Expression = DestPtr { .Field = &node.type_expr } });
                                        try stack.append(State { .ExpectToken = Token.Id.Colon });
                                        continue;
                                    },
                                    else => {
                                        self.putBackToken(identifier);
                                    }
                                }
                            }

                            stack.append(State{ .ContainerDecl = container_decl }) catch unreachable;
                            try stack.append(State {
                                .TopLevelExtern = TopLevelDeclCtx {
                                    .decls = &container_decl.fields_and_decls,
                                    .visib_token = token,
                                    .extern_export_inline_token = null,
                                    .lib_name = null,
                                }
                            });
                            continue;
                        },
                        Token.Id.Keyword_export => {
                            stack.append(State{ .ContainerDecl = container_decl }) catch unreachable;
                            try stack.append(State {
                                .TopLevelExtern = TopLevelDeclCtx {
                                    .decls = &container_decl.fields_and_decls,
                                    .visib_token = token,
                                    .extern_export_inline_token = null,
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
                                    .extern_export_inline_token = null,
                                    .lib_name = null,
                                }
                            });
                            continue;
                        }
                    }
                },

                State.ExpectToken => |token_id| {
                    _ = (try self.expectToken(&stack, token_id)) ?? continue;
                    continue;
                },

                State.ExpectTokenSave => |expect_token_save| {
                    *expect_token_save.ptr = (try self.expectToken(&stack, expect_token_save.id)) ?? continue;
                    continue;
                },

                State.IfToken => |token_id| {
                    const token = self.getNextToken();
                    if (@TagType(Token.Id)(token.id) != token_id) {
                        self.putBackToken(token);
                        _ = stack.pop();
                        continue;
                    }
                    continue;
                },

                State.IfTokenSave => |if_token_save| {
                    const token = self.getNextToken();
                    if (@TagType(Token.Id)(token.id) != if_token_save.id) {
                        self.putBackToken(token);
                        _ = stack.pop();
                        continue;
                    }

                    *if_token_save.ptr = token;
                    continue;
                },

                State.Optional => { },

                State.Expression => |dest_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_return => {
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeControlFlowExpression,
                                ast.NodeControlFlowExpression {
                                    .base = undefined,
                                    .ltoken = token,
                                    .kind = ast.NodeControlFlowExpression.Kind.Return,
                                    .rhs = undefined,
                                }
                            );

                            // TODO: Find another way to do optional expressions
                            stack.append(State {
                                .Optional = RevertState {
                                    .parser = *self,
                                    .tokenizer = *self.tokenizer,
                                    .ptr = &node.rhs,
                                }
                            }) catch unreachable;
                            try stack.append(State { .Expression = DestPtr { .NullableField = &node.rhs } });
                            continue;
                        },
                        Token.Id.Keyword_break, Token.Id.Keyword_continue => {
                            const label = blk: {
                                const colon = self.getNextToken();
                                if (colon.id != Token.Id.Colon) {
                                    self.putBackToken(colon);
                                    break :blk null;
                                }

                                break :blk (try self.expectToken(&stack, Token.Id.Identifier)) ?? continue;
                            };

                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeControlFlowExpression,
                                ast.NodeControlFlowExpression {
                                    .base = undefined,
                                    .ltoken = token,
                                    .kind = switch (token.id) {
                                        Token.Id.Keyword_break => ast.NodeControlFlowExpression.Kind { .Break = label },
                                        Token.Id.Keyword_continue => ast.NodeControlFlowExpression.Kind { .Continue = label },
                                        else => unreachable,
                                    },
                                    .rhs = undefined,
                                }
                            );

                            // TODO: Find another way to do optional expressions
                            stack.append(State {
                                .Optional = RevertState {
                                    .parser = *self,
                                    .tokenizer = *self.tokenizer,
                                    .ptr = &node.rhs,
                                }
                            }) catch unreachable;
                            try stack.append(State { .Expression = DestPtr { .NullableField = &node.rhs } });
                            continue;
                        },
                        Token.Id.Keyword_try, Token.Id.Keyword_cancel, Token.Id.Keyword_resume => {
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodePrefixOp,
                                ast.NodePrefixOp {
                                    .base = undefined,
                                    .op_token = token,
                                    .op = switch (token.id) {
                                        Token.Id.Keyword_try => ast.NodePrefixOp.PrefixOp { .Try = void{} },
                                        Token.Id.Keyword_cancel => ast.NodePrefixOp.PrefixOp { .Cancel = void{} },
                                        Token.Id.Keyword_resume => ast.NodePrefixOp.PrefixOp { .Resume = void{} },
                                        else => unreachable,
                                    },
                                    .rhs = undefined,
                                }
                            );

                            stack.append(State { .Expression = DestPtr { .Field = &node.rhs } }) catch unreachable;
                            continue;
                        },
                        else => {
                            if (!try self.parseBlockExpr(&stack, arena, dest_ptr, token)) {
                                self.putBackToken(token);
                                stack.append(State { .UnwrapExpressionBegin = dest_ptr }) catch unreachable;
                            }
                            continue;
                        }
                    }
                },

                State.RangeExpressionBegin => |dest_ptr| {
                    stack.append(State { .RangeExpressionEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .Expression = dest_ptr });
                    continue;
                },

                State.RangeExpressionEnd => |dest_ptr| {
                    if (self.eatToken(Token.Id.Ellipsis3)) |ellipsis3| {
                        const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                            ast.NodeInfixOp {
                                .base = undefined,
                                .lhs = dest_ptr.get(),
                                .op_token = ellipsis3,
                                .op = ast.NodeInfixOp.InfixOp.Range,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .Expression = DestPtr { .Field = &node.rhs } }) catch unreachable;
                    }

                    continue;
                },

                State.AssignmentExpressionBegin => |dest_ptr| {
                    stack.append(State { .AssignmentExpressionEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .Expression = dest_ptr });
                    continue;
                },

                State.AssignmentExpressionEnd => |dest_ptr| {
                    const token = self.getNextToken();
                    if (tokenIdToAssignment(token.id)) |ass_id| {
                        const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                            ast.NodeInfixOp {
                                .base = undefined,
                                .lhs = dest_ptr.get(),
                                .op_token = token,
                                .op = ass_id,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .AssignmentExpressionEnd = dest_ptr }) catch unreachable;
                        try stack.append(State { .Expression = DestPtr { .Field = &node.rhs } });
                        continue;
                    } else {
                        self.putBackToken(token);
                        continue;
                    }
                },

                State.UnwrapExpressionBegin => |dest_ptr| {
                    stack.append(State { .UnwrapExpressionEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .BoolOrExpressionBegin = dest_ptr });
                    continue;
                },

                State.UnwrapExpressionEnd => |dest_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_catch, Token.Id.QuestionMarkQuestionMark => {
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                                ast.NodeInfixOp {
                                    .base = undefined,
                                    .lhs = dest_ptr.get(),
                                    .op_token = token,
                                    .op = switch (token.id) {
                                        Token.Id.Keyword_catch => ast.NodeInfixOp.InfixOp { .Catch = null },
                                        Token.Id.QuestionMarkQuestionMark => ast.NodeInfixOp.InfixOp { .UnwrapMaybe = void{} },
                                        else => unreachable,
                                    },
                                    .rhs = undefined,
                                }
                            );

                            stack.append(State { .UnwrapExpressionEnd = dest_ptr }) catch unreachable;
                            try stack.append(State { .Expression = DestPtr { .Field = &node.rhs } });

                            if (node.op == ast.NodeInfixOp.InfixOp.Catch) {
                                try stack.append(State { .Payload = &node.op.Catch });
                            }
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            continue;
                        },
                    }
                },

                State.BoolOrExpressionBegin => |dest_ptr| {
                    stack.append(State { .BoolOrExpressionEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .BoolAndExpressionBegin = dest_ptr });
                    continue;
                },

                State.BoolOrExpressionEnd => |dest_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_or => {
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                                ast.NodeInfixOp {
                                    .base = undefined,
                                    .lhs = dest_ptr.get(),
                                    .op_token = token,
                                    .op = ast.NodeInfixOp.InfixOp.BoolOr,
                                    .rhs = undefined,
                                }
                            );
                            stack.append(State { .BoolOrExpressionEnd = dest_ptr }) catch unreachable;
                            try stack.append(State { .BoolAndExpressionBegin = DestPtr { .Field = &node.rhs } });
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            continue;
                        },
                    }
                },

                State.BoolAndExpressionBegin => |dest_ptr| {
                    stack.append(State { .BoolAndExpressionEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .ComparisonExpressionBegin = dest_ptr });
                    continue;
                },

                State.BoolAndExpressionEnd => |dest_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_and => {
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                                ast.NodeInfixOp {
                                    .base = undefined,
                                    .lhs = dest_ptr.get(),
                                    .op_token = token,
                                    .op = ast.NodeInfixOp.InfixOp.BoolAnd,
                                    .rhs = undefined,
                                }
                            );
                            stack.append(State { .BoolAndExpressionEnd = dest_ptr }) catch unreachable;
                            try stack.append(State { .ComparisonExpressionBegin = DestPtr { .Field = &node.rhs } });
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            continue;
                        },
                    }
                },

                State.ComparisonExpressionBegin => |dest_ptr| {
                    stack.append(State { .ComparisonExpressionEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .BinaryOrExpressionBegin = dest_ptr });
                    continue;
                },

                State.ComparisonExpressionEnd => |dest_ptr| {
                    const token = self.getNextToken();
                    if (tokenIdToComparison(token.id)) |comp_id| {
                        const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                            ast.NodeInfixOp {
                                .base = undefined,
                                .lhs = dest_ptr.get(),
                                .op_token = token,
                                .op = comp_id,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .ComparisonExpressionEnd = dest_ptr }) catch unreachable;
                        try stack.append(State { .BinaryOrExpressionBegin = DestPtr { .Field = &node.rhs } });
                        continue;
                    } else {
                        self.putBackToken(token);
                        continue;
                    }
                },

                State.BinaryOrExpressionBegin => |dest_ptr| {
                    stack.append(State { .BinaryOrExpressionEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .BinaryXorExpressionBegin = dest_ptr });
                    continue;
                },

                State.BinaryOrExpressionEnd => |dest_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Pipe => {
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                                ast.NodeInfixOp {
                                    .base = undefined,
                                    .lhs = dest_ptr.get(),
                                    .op_token = token,
                                    .op = ast.NodeInfixOp.InfixOp.BitOr,
                                    .rhs = undefined,
                                }
                            );
                            stack.append(State { .BinaryOrExpressionEnd = dest_ptr }) catch unreachable;
                            try stack.append(State { .BinaryXorExpressionBegin = DestPtr { .Field = &node.rhs } });
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            continue;
                        },
                    }
                },

                State.BinaryXorExpressionBegin => |dest_ptr| {
                    stack.append(State { .BinaryXorExpressionEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .BinaryAndExpressionBegin = dest_ptr });
                    continue;
                },

                State.BinaryXorExpressionEnd => |dest_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Caret => {
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                                ast.NodeInfixOp {
                                    .base = undefined,
                                    .lhs = dest_ptr.get(),
                                    .op_token = token,
                                    .op = ast.NodeInfixOp.InfixOp.BitXor,
                                    .rhs = undefined,
                                }
                            );
                            stack.append(State { .BinaryXorExpressionEnd = dest_ptr }) catch unreachable;
                            try stack.append(State { .BinaryAndExpressionBegin = DestPtr { .Field = &node.rhs } });
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            continue;
                        },
                    }
                },

                State.BinaryAndExpressionBegin => |dest_ptr| {
                    stack.append(State { .BinaryAndExpressionEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .BitShiftExpressionBegin = dest_ptr });
                    continue;
                },

                State.BinaryAndExpressionEnd => |dest_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Ampersand => {
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                                ast.NodeInfixOp {
                                    .base = undefined,
                                    .lhs = dest_ptr.get(),
                                    .op_token = token,
                                    .op = ast.NodeInfixOp.InfixOp.BitAnd,
                                    .rhs = undefined,
                                }
                            );
                            stack.append(State { .BinaryAndExpressionEnd = dest_ptr }) catch unreachable;
                            try stack.append(State { .BitShiftExpressionBegin = DestPtr { .Field = &node.rhs } });
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            continue;
                        },
                    }
                },

                State.BitShiftExpressionBegin => |dest_ptr| {
                    stack.append(State { .BitShiftExpressionEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .AdditionExpressionBegin = dest_ptr });
                    continue;
                },

                State.BitShiftExpressionEnd => |dest_ptr| {
                    const token = self.getNextToken();
                    if (tokenIdToBitShift(token.id)) |bitshift_id| {
                        const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                            ast.NodeInfixOp {
                                .base = undefined,
                                .lhs = dest_ptr.get(),
                                .op_token = token,
                                .op = bitshift_id,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .BitShiftExpressionEnd = dest_ptr }) catch unreachable;
                        try stack.append(State { .AdditionExpressionBegin = DestPtr { .Field = &node.rhs } });
                        continue;
                    } else {
                        self.putBackToken(token);
                        continue;
                    }
                },

                State.AdditionExpressionBegin => |dest_ptr| {
                    stack.append(State { .AdditionExpressionEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .MultiplyExpressionBegin = dest_ptr });
                    continue;
                },

                State.AdditionExpressionEnd => |dest_ptr| {
                    const token = self.getNextToken();
                    if (tokenIdToAddition(token.id)) |add_id| {
                        const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                            ast.NodeInfixOp {
                                .base = undefined,
                                .lhs = dest_ptr.get(),
                                .op_token = token,
                                .op = add_id,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .AdditionExpressionEnd = dest_ptr }) catch unreachable;
                        try stack.append(State { .MultiplyExpressionBegin = DestPtr { .Field = &node.rhs } });
                        continue;
                    } else {
                        self.putBackToken(token);
                        continue;
                    }
                },

                State.MultiplyExpressionBegin => |dest_ptr| {
                    stack.append(State { .MultiplyExpressionEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .CurlySuffixExpressionBegin = dest_ptr });
                    continue;
                },

                State.MultiplyExpressionEnd => |dest_ptr| {
                    const token = self.getNextToken();
                    if (tokenIdToMultiply(token.id)) |mult_id| {
                        const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                            ast.NodeInfixOp {
                                .base = undefined,
                                .lhs = dest_ptr.get(),
                                .op_token = token,
                                .op = mult_id,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .MultiplyExpressionEnd = dest_ptr }) catch unreachable;
                        try stack.append(State { .CurlySuffixExpressionBegin = DestPtr { .Field = &node.rhs } });
                        continue;
                    } else {
                        self.putBackToken(token);
                        continue;
                    }
                },

                State.CurlySuffixExpressionBegin => |dest_ptr| {
                    stack.append(State { .CurlySuffixExpressionEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .TypeExprBegin = dest_ptr });
                    continue;
                },

                State.CurlySuffixExpressionEnd => |dest_ptr| {
                    if (self.eatToken(Token.Id.LBrace) == null) {
                        continue;
                    }

                    if (self.isPeekToken(Token.Id.Period)) {
                        const node = try self.createToDestNode(arena, dest_ptr, ast.NodeSuffixOp,
                            ast.NodeSuffixOp {
                                .base = undefined,
                                .lhs = dest_ptr.get(),
                                .op = ast.NodeSuffixOp.SuffixOp {
                                    .StructInitializer = ArrayList(&ast.NodeFieldInitializer).init(arena),
                                },
                                .rtoken = undefined,
                            }
                        );
                        stack.append(State { .CurlySuffixExpressionEnd = dest_ptr }) catch unreachable;
                        try stack.append(State {
                            .FieldInitListItemOrEnd = ListSave(&ast.NodeFieldInitializer) {
                                .list = &node.op.StructInitializer,
                                .ptr = &node.rtoken,
                            }
                        });
                        continue;
                    } else {
                        const node = try self.createToDestNode(arena, dest_ptr, ast.NodeSuffixOp,
                            ast.NodeSuffixOp {
                                .base = undefined,
                                .lhs = dest_ptr.get(),
                                .op = ast.NodeSuffixOp.SuffixOp {
                                    .ArrayInitializer = ArrayList(&ast.Node).init(arena),
                                },
                                .rtoken = undefined,
                            }
                        );
                        stack.append(State { .CurlySuffixExpressionEnd = dest_ptr }) catch unreachable;
                        try stack.append(State {
                            .ExprListItemOrEnd = ExprListCtx {
                                .list = &node.op.ArrayInitializer,
                                .end = Token.Id.RBrace,
                                .ptr = &node.rtoken,
                            }
                        });
                        continue;
                    }
                },

                State.TypeExprBegin => |dest_ptr| {
                    stack.append(State { .TypeExprEnd = dest_ptr }) catch unreachable;
                    try stack.append(State { .PrefixOpExpression = dest_ptr });
                    continue;
                },

                State.TypeExprEnd => |dest_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Bang => {
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                                ast.NodeInfixOp {
                                    .base = undefined,
                                    .lhs = dest_ptr.get(),
                                    .op_token = token,
                                    .op = ast.NodeInfixOp.InfixOp.ErrorUnion,
                                    .rhs = undefined,
                                }
                            );
                            stack.append(State { .TypeExprEnd = dest_ptr }) catch unreachable;
                            try stack.append(State { .PrefixOpExpression = DestPtr { .Field = &node.rhs } });
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            continue;
                        },
                    }
                },

                State.PrefixOpExpression => |dest_ptr| {
                    const token = self.getNextToken();
                    if (tokenIdToPrefixOp(token.id)) |prefix_id| {
                        var node = try self.createToDestNode(arena, dest_ptr, ast.NodePrefixOp,
                            ast.NodePrefixOp {
                                .base = undefined,
                                .op_token = token,
                                .op = prefix_id,
                                .rhs = undefined,
                            }
                        );

                        if (token.id == Token.Id.AsteriskAsterisk) {
                            const child = try self.createNode(arena, ast.NodePrefixOp,
                                ast.NodePrefixOp {
                                    .base = undefined,
                                    .op_token = token,
                                    .op = prefix_id,
                                    .rhs = undefined,
                                }
                            );
                            node.rhs = &child.base;
                            node = child;
                        }

                        stack.append(State { .TypeExprBegin = DestPtr { .Field = &node.rhs } }) catch unreachable;
                        if (node.op == ast.NodePrefixOp.PrefixOp.AddrOf) {
                            try stack.append(State { .AddrOfModifiers = &node.op.AddrOf });
                        }
                        continue;
                    } else {
                        self.putBackToken(token);
                        stack.append(State { .SuffixOpExpressionBegin = dest_ptr }) catch unreachable;
                        continue;
                    }
                },

                State.SuffixOpExpressionBegin => |dest_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_async => {
                            const async_node = try self.createNode(arena, ast.NodeAsyncAttribute,
                                ast.NodeAsyncAttribute {
                                    .base = undefined,
                                    .async_token = token,
                                    .allocator_type = null,
                                    .rangle_bracket = null,
                                }
                            );
                            stack.append(State {
                                .AsyncEnd = AsyncEndCtx {
                                    .dest_ptr = dest_ptr,
                                    .attribute = async_node,
                                }
                            }) catch unreachable;
                            try stack.append(State { .SuffixOpExpressionEnd = dest_ptr });
                            try stack.append(State { .PrimaryExpression = dest_ptr });

                            const langle_bracket = self.getNextToken();
                            if (langle_bracket.id != Token.Id.AngleBracketLeft) {
                                self.putBackToken(langle_bracket);
                                continue;
                            }

                            async_node.rangle_bracket = Token(undefined);
                            try stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.AngleBracketRight,
                                    .ptr = &??async_node.rangle_bracket,
                                }
                            });
                            try stack.append(State { .TypeExprBegin = DestPtr { .NullableField = &async_node.allocator_type } });
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            stack.append(State { .SuffixOpExpressionEnd = dest_ptr }) catch unreachable;
                            try stack.append(State { .PrimaryExpression = dest_ptr });
                            continue;
                        }
                    }
                },

                State.SuffixOpExpressionEnd => |dest_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.LParen => {
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeSuffixOp,
                                ast.NodeSuffixOp {
                                    .base = undefined,
                                    .lhs = dest_ptr.get(),
                                    .op = ast.NodeSuffixOp.SuffixOp {
                                        .Call = ast.NodeSuffixOp.CallInfo {
                                            .params = ArrayList(&ast.Node).init(arena),
                                            .async_attr = null,
                                        }
                                    },
                                    .rtoken = undefined,
                                }
                            );
                            stack.append(State { .SuffixOpExpressionEnd = dest_ptr }) catch unreachable;
                            try stack.append(State {
                                .ExprListItemOrEnd = ExprListCtx {
                                    .list = &node.op.Call.params,
                                    .end = Token.Id.RParen,
                                    .ptr = &node.rtoken,
                                }
                            });
                            continue;
                        },
                        Token.Id.LBracket => {
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeSuffixOp,
                                ast.NodeSuffixOp {
                                    .base = undefined,
                                    .lhs = dest_ptr.get(),
                                    .op = ast.NodeSuffixOp.SuffixOp {
                                        .ArrayAccess = undefined,
                                    },
                                    .rtoken = undefined
                                }
                            );
                            stack.append(State { .SuffixOpExpressionEnd = dest_ptr }) catch unreachable;
                            try stack.append(State { .SliceOrArrayAccess = node });
                            try stack.append(State { .Expression = DestPtr { .Field = &node.op.ArrayAccess }});
                            continue;
                        },
                        Token.Id.Period => {
                            const identifier = try self.createLiteral(arena, ast.NodeIdentifier, Token(undefined));
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeInfixOp,
                                ast.NodeInfixOp {
                                    .base = undefined,
                                    .lhs = dest_ptr.get(),
                                    .op_token = token,
                                    .op = ast.NodeInfixOp.InfixOp.Period,
                                    .rhs = &identifier.base,
                                }
                            );
                            stack.append(State { .SuffixOpExpressionEnd = dest_ptr }) catch unreachable;
                            try stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.Identifier,
                                    .ptr = &identifier.token
                                }
                            });
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            continue;
                        },
                    }
                },

                State.PrimaryExpression => |dest_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.IntegerLiteral => {
                            dest_ptr.store(&(try self.createLiteral(arena, ast.NodeStringLiteral, token)).base);
                            continue;
                        },
                        Token.Id.FloatLiteral => {
                            dest_ptr.store(&(try self.createLiteral(arena, ast.NodeFloatLiteral, token)).base);
                            continue;
                        },
                        Token.Id.CharLiteral => {
                            dest_ptr.store(&(try self.createLiteral(arena, ast.NodeCharLiteral, token)).base);
                            continue;
                        },
                        Token.Id.Keyword_undefined => {
                            dest_ptr.store(&(try self.createLiteral(arena, ast.NodeUndefinedLiteral, token)).base);
                            continue;
                        },
                        Token.Id.Keyword_true, Token.Id.Keyword_false => {
                            dest_ptr.store(&(try self.createLiteral(arena, ast.NodeBoolLiteral, token)).base);
                            continue;
                        },
                        Token.Id.Keyword_null => {
                            dest_ptr.store(&(try self.createLiteral(arena, ast.NodeNullLiteral, token)).base);
                            continue;
                        },
                        Token.Id.Keyword_this => {
                            dest_ptr.store(&(try self.createLiteral(arena, ast.NodeThisLiteral, token)).base);
                            continue;
                        },
                        Token.Id.Keyword_var => {
                            dest_ptr.store(&(try self.createLiteral(arena, ast.NodeVarType, token)).base);
                            continue;
                        },
                        Token.Id.Keyword_unreachable => {
                            dest_ptr.store(&(try self.createLiteral(arena, ast.NodeUnreachable, token)).base);
                            continue;
                        },
                        Token.Id.StringLiteral, Token.Id.MultilineStringLiteralLine => {
                            dest_ptr.store((try self.parseStringLiteral(arena, token)) ?? unreachable);
                        },
                        Token.Id.LParen => {
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeGroupedExpression,
                                ast.NodeGroupedExpression {
                                    .base = undefined,
                                    .lparen = token,
                                    .expr = undefined,
                                    .rparen = undefined,
                                }
                            );
                            stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.RParen,
                                    .ptr = &node.rparen,
                                }
                            }) catch unreachable;
                            try stack.append(State { .Expression = DestPtr { .Field = &node.expr } });
                            continue;
                        },
                        Token.Id.Builtin => {
                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeBuiltinCall,
                                ast.NodeBuiltinCall {
                                    .base = undefined,
                                    .builtin_token = token,
                                    .params = ArrayList(&ast.Node).init(arena),
                                    .rparen_token = undefined,
                                }
                            );
                            stack.append(State {
                                .ExprListItemOrEnd = ExprListCtx {
                                    .list = &node.params,
                                    .end = Token.Id.RParen,
                                    .ptr = &node.rparen_token,
                                }
                            }) catch unreachable;
                            try stack.append(State { .ExpectToken = Token.Id.LParen, });
                            continue;
                        },
                        Token.Id.LBracket => {
                            const rbracket_token = self.getNextToken();
                            if (rbracket_token.id == Token.Id.RBracket) {
                                const node = try self.createToDestNode(arena, dest_ptr, ast.NodePrefixOp,
                                    ast.NodePrefixOp {
                                        .base = undefined,
                                        .op_token = token,
                                        .op = ast.NodePrefixOp.PrefixOp{
                                            .SliceType = ast.NodePrefixOp.AddrOfInfo {
                                                .align_expr = null,
                                                .bit_offset_start_token = null,
                                                .bit_offset_end_token = null,
                                                .const_token = null,
                                                .volatile_token = null,
                                            }
                                        },
                                        .rhs = undefined,
                                    }
                                );
                                dest_ptr.store(&node.base);
                                stack.append(State { .TypeExprBegin = DestPtr { .Field = &node.rhs } }) catch unreachable;
                                try stack.append(State { .AddrOfModifiers = &node.op.SliceType });
                                continue;
                            }

                            self.putBackToken(rbracket_token);

                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodePrefixOp,
                                ast.NodePrefixOp {
                                    .base = undefined,
                                    .op_token = token,
                                    .op = ast.NodePrefixOp.PrefixOp{
                                        .ArrayType = undefined,
                                    },
                                    .rhs = undefined,
                                }
                            );
                            stack.append(State { .TypeExprBegin = DestPtr { .Field = &node.rhs } }) catch unreachable;
                            try stack.append(State { .ExpectToken = Token.Id.RBracket });
                            try stack.append(State { .Expression = DestPtr { .Field = &node.op.ArrayType } });

                        },
                        Token.Id.Keyword_error => {
                            if (self.eatToken(Token.Id.LBrace) == null) {
                                dest_ptr.store(&(try self.createLiteral(arena, ast.NodeErrorType, token)).base);
                                continue;
                            }

                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeErrorSetDecl,
                                ast.NodeErrorSetDecl {
                                    .base = undefined,
                                    .error_token = token,
                                    .decls = ArrayList(&ast.NodeIdentifier).init(arena),
                                    .rbrace_token = undefined,
                                }
                            );

                            stack.append(State {
                                .IdentifierListItemOrEnd = ListSave(&ast.NodeIdentifier) {
                                    .list = &node.decls,
                                    .ptr = &node.rbrace_token,
                                }
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_packed => {
                            stack.append(State {
                                .ContainerExtern = ContainerExternCtx {
                                    .dest_ptr = dest_ptr,
                                    .ltoken = token,
                                    .layout = ast.NodeContainerDecl.Layout.Packed,
                                },
                            }) catch unreachable;
                        },
                        Token.Id.Keyword_extern => {
                            const next = self.getNextToken();
                            if (next.id == Token.Id.Keyword_fn) {
                                const fn_proto = try self.createToDestNode(arena, dest_ptr, ast.NodeFnProto,
                                    ast.NodeFnProto {
                                        .base = undefined,
                                        .visib_token = null,
                                        .name_token = null,
                                        .fn_token = next,
                                        .params = ArrayList(&ast.Node).init(arena),
                                        .return_type = undefined,
                                        .var_args_token = null,
                                        .extern_export_inline_token = token,
                                        .cc_token = null,
                                        .async_attr = null,
                                        .body_node = null,
                                        .lib_name = null,
                                        .align_expr = null,
                                    }
                                );
                                stack.append(State { .FnProto = fn_proto }) catch unreachable;
                                continue;
                            }

                            self.putBackToken(next);
                            stack.append(State {
                                .ContainerExtern = ContainerExternCtx {
                                    .dest_ptr = dest_ptr,
                                    .ltoken = token,
                                    .layout = ast.NodeContainerDecl.Layout.Extern,
                                },
                            }) catch unreachable;
                        },
                        Token.Id.Keyword_struct, Token.Id.Keyword_union, Token.Id.Keyword_enum => {
                            self.putBackToken(token);
                            stack.append(State {
                                .ContainerExtern = ContainerExternCtx {
                                    .dest_ptr = dest_ptr,
                                    .ltoken = token,
                                    .layout = ast.NodeContainerDecl.Layout.Auto,
                                },
                            }) catch unreachable;
                        },
                        Token.Id.Identifier => {
                            const next = self.getNextToken();
                            if (next.id != Token.Id.Colon) {
                                self.putBackToken(next);
                                dest_ptr.store(&(try self.createLiteral(arena, ast.NodeIdentifier, token)).base);
                                continue;
                            }

                            stack.append(State {
                                .LabeledExpression = LabelCtx {
                                    .label = token,
                                    .dest_ptr = dest_ptr
                                }
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_fn => {
                            const fn_proto = try self.createToDestNode(arena, dest_ptr, ast.NodeFnProto,
                                ast.NodeFnProto {
                                    .base = undefined,
                                    .visib_token = null,
                                    .name_token = null,
                                    .fn_token = token,
                                    .params = ArrayList(&ast.Node).init(arena),
                                    .return_type = undefined,
                                    .var_args_token = null,
                                    .extern_export_inline_token = null,
                                    .cc_token = null,
                                    .async_attr = null,
                                    .body_node = null,
                                    .lib_name = null,
                                    .align_expr = null,
                                }
                            );
                            stack.append(State { .FnProto = fn_proto }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_nakedcc, Token.Id.Keyword_stdcallcc => {
                            const fn_token = (try self.expectToken(&stack, Token.Id.Keyword_fn)) ?? continue;
                            const fn_proto = try self.createToDestNode(arena, dest_ptr, ast.NodeFnProto,
                                ast.NodeFnProto {
                                    .base = undefined,
                                    .visib_token = null,
                                    .name_token = null,
                                    .fn_token = fn_token,
                                    .params = ArrayList(&ast.Node).init(arena),
                                    .return_type = undefined,
                                    .var_args_token = null,
                                    .extern_export_inline_token = null,
                                    .cc_token = token,
                                    .async_attr = null,
                                    .body_node = null,
                                    .lib_name = null,
                                    .align_expr = null,
                                }
                            );
                            stack.append(State { .FnProto = fn_proto }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_asm => {
                            const is_volatile = blk: {
                                const volatile_token = self.getNextToken();
                                if (volatile_token.id != Token.Id.Keyword_volatile) {
                                    self.putBackToken(volatile_token);
                                    break :blk false;
                                }
                                break :blk true;
                            };
                            _ = (try self.expectToken(&stack, Token.Id.LParen)) ?? continue;

                            const template_token = self.getNextToken();
                            const template = (try self.parseStringLiteral(arena, template_token)) ?? {
                                try self.parseError(&stack, template_token, "expected string literal, found {}", @tagName(template_token.id));
                                continue;
                            };
                            // TODO parse template

                            const node = try self.createToDestNode(arena, dest_ptr, ast.NodeAsm,
                                ast.NodeAsm {
                                    .base = undefined,
                                    .asm_token = token,
                                    .is_volatile = is_volatile,
                                    .template = template,
                                    //.tokens = ArrayList(ast.NodeAsm.AsmToken).init(arena),
                                    .outputs = ArrayList(&ast.NodeAsmOutput).init(arena),
                                    .inputs = ArrayList(&ast.NodeAsmInput).init(arena),
                                    .cloppers = ArrayList(&ast.Node).init(arena),
                                    .rparen = undefined,
                                }
                            );
                            stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.RParen,
                                    .ptr = &node.rparen,
                                }
                            }) catch unreachable;
                            try stack.append(State { .AsmClopperItems = &node.cloppers });
                            try stack.append(State { .IfToken = Token.Id.Colon });
                            try stack.append(State { .AsmInputItems = &node.inputs });
                            try stack.append(State { .IfToken = Token.Id.Colon });
                            try stack.append(State { .AsmOutputItems = &node.outputs });
                            try stack.append(State { .IfToken = Token.Id.Colon });
                        },
                        Token.Id.Keyword_inline => {
                            stack.append(State {
                                .Inline = InlineCtx {
                                    .label = null,
                                    .inline_token = token,
                                    .dest_ptr = dest_ptr,
                                }
                            }) catch unreachable;
                            continue;
                        },
                        else => {
                            if (!try self.parseBlockExpr(&stack, arena, dest_ptr, token)) {
                                try self.parseError(&stack, token, "expected primary expression, found {}", @tagName(token.id));
                            }
                            continue;
                        }
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

                            const rbracket_token = self.getNextToken();
                            if (rbracket_token.id != Token.Id.RBracket) {
                                self.putBackToken(rbracket_token);
                                stack.append(State {
                                    .ExpectTokenSave = ExpectTokenSave {
                                        .id = Token.Id.RBracket,
                                        .ptr = &node.rtoken,
                                    }
                                }) catch unreachable;
                                try stack.append(State { .Expression = DestPtr { .NullableField = &node.op.Slice.end } });
                            } else {
                                node.rtoken = rbracket_token;
                            }
                            continue;
                        },
                        Token.Id.RBracket => {
                            node.rtoken = token;
                            continue;
                        },
                        else => {
                            try self.parseError(&stack, token, "expected ']' or '..', found {}", @tagName(token.id));
                            continue;
                        }
                    }
                },


                State.AsmOutputItems => |items| {
                    const lbracket = self.getNextToken();
                    if (lbracket.id != Token.Id.LBracket) {
                        self.putBackToken(lbracket);
                        continue;
                    }

                    stack.append(State { .AsmOutputItems = items }) catch unreachable;
                    try stack.append(State { .IfToken = Token.Id.Comma });

                    const symbolic_name = (try self.expectToken(&stack, Token.Id.Identifier)) ?? continue;
                    _ = (try self.expectToken(&stack, Token.Id.RBracket)) ?? continue;

                    const constraint_token = self.getNextToken();
                    const constraint = (try self.parseStringLiteral(arena, constraint_token)) ?? {
                        try self.parseError(&stack, constraint_token, "expected string literal, found {}", @tagName(constraint_token.id));
                        continue;
                    };

                    _ = (try self.expectToken(&stack, Token.Id.LParen)) ?? continue;
                    try stack.append(State { .ExpectToken = Token.Id.RParen });

                    const node = try self.createNode(arena, ast.NodeAsmOutput,
                        ast.NodeAsmOutput {
                            .base = undefined,
                            .symbolic_name = try self.createLiteral(arena, ast.NodeIdentifier, symbolic_name),
                            .constraint = constraint,
                            .kind = undefined,
                        }
                    );
                    try items.append(node);

                    const symbol_or_arrow = self.getNextToken();
                    switch (symbol_or_arrow.id) {
                        Token.Id.Identifier => {
                            node.kind = ast.NodeAsmOutput.Kind { .Variable = try self.createLiteral(arena, ast.NodeIdentifier, symbol_or_arrow) };
                        },
                        Token.Id.Arrow => {
                            node.kind = ast.NodeAsmOutput.Kind { .Return = undefined };
                            try stack.append(State { .TypeExprBegin = DestPtr { .Field = &node.kind.Return } });
                        },
                        else => {
                            try self.parseError(&stack, symbol_or_arrow, "expected '->' or {}, found {}",
                                @tagName(Token.Id.Identifier),
                                @tagName(symbol_or_arrow.id));
                            continue;
                        },
                    }
                },

                State.AsmInputItems => |items| {
                    const lbracket = self.getNextToken();
                    if (lbracket.id != Token.Id.LBracket) {
                        self.putBackToken(lbracket);
                        continue;
                    }

                    stack.append(State { .AsmInputItems = items }) catch unreachable;
                    try stack.append(State { .IfToken = Token.Id.Comma });

                    const symbolic_name = (try self.expectToken(&stack, Token.Id.Identifier)) ?? continue;
                    _ = (try self.expectToken(&stack, Token.Id.RBracket)) ?? continue;

                    const constraint_token = self.getNextToken();
                    const constraint = (try self.parseStringLiteral(arena, constraint_token)) ?? {
                        try self.parseError(&stack, constraint_token, "expected string literal, found {}", @tagName(constraint_token.id));
                        continue;
                    };

                    _ = (try self.expectToken(&stack, Token.Id.LParen)) ?? continue;
                    try stack.append(State { .ExpectToken = Token.Id.RParen });

                    const node = try self.createNode(arena, ast.NodeAsmInput,
                        ast.NodeAsmInput {
                            .base = undefined,
                            .symbolic_name = try self.createLiteral(arena, ast.NodeIdentifier, symbolic_name),
                            .constraint = constraint,
                            .expr = undefined,
                        }
                    );
                    try items.append(node);
                    try stack.append(State { .Expression = DestPtr { .Field = &node.expr } });
                },

                State.AsmClopperItems => |items| {
                    const string_token = self.getNextToken();
                    const string = (try self.parseStringLiteral(arena, string_token)) ?? {
                        self.putBackToken(string_token);
                        continue;
                    };
                    try items.append(string);

                    stack.append(State { .AsmClopperItems = items }) catch unreachable;
                    try stack.append(State { .IfToken = Token.Id.Comma });
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
                    try stack.append(State { .Expression = DestPtr{ .Field = try list_state.list.addOne() } });
                },

                State.FieldInitListItemOrEnd => |list_state| {
                    if (self.eatToken(Token.Id.RBrace)) |rbrace| {
                        *list_state.ptr = rbrace;
                        continue;
                    }

                    const node = try self.createNode(arena, ast.NodeFieldInitializer,
                        ast.NodeFieldInitializer {
                            .base = undefined,
                            .period_token = undefined,
                            .name_token = undefined,
                            .expr = undefined,
                        }
                    );
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

                State.IdentifierListItemOrEnd => |list_state| {
                    if (self.eatToken(Token.Id.RBrace)) |rbrace| {
                        *list_state.ptr = rbrace;
                        continue;
                    }

                    const node = try self.createLiteral(arena, ast.NodeIdentifier, Token(undefined));
                    try list_state.list.append(node);

                    stack.append(State { .IdentifierListCommaOrEnd = list_state }) catch unreachable;
                    try stack.append(State {
                        .ExpectTokenSave = ExpectTokenSave {
                            .id = Token.Id.Identifier,
                            .ptr = &node.token,
                        }
                    });
                },

                State.SwitchCaseOrEnd => |list_state| {
                    if (self.eatToken(Token.Id.RBrace)) |rbrace| {
                        *list_state.ptr = rbrace;
                        continue;
                    }

                    const node = try self.createNode(arena, ast.NodeSwitchCase,
                        ast.NodeSwitchCase {
                            .base = undefined,
                            .items = ArrayList(&ast.Node).init(arena),
                            .payload = null,
                            .expr = undefined,
                        }
                    );
                    try list_state.list.append(node);
                    stack.append(State { .SwitchCaseCommaOrEnd = list_state }) catch unreachable;
                    try stack.append(State { .AssignmentExpressionBegin = DestPtr{ .Field = &node.expr  } });
                    try stack.append(State { .PointerPayload = &node.payload });

                    const maybe_else = self.getNextToken();
                    if (maybe_else.id == Token.Id.Keyword_else) {
                        const else_node = try self.createAttachNode(arena, &node.items, ast.NodeSwitchElse,
                            ast.NodeSwitchElse {
                                .base = undefined,
                            .token = maybe_else,
                            }
                        );
                        try stack.append(State { .ExpectToken = Token.Id.EqualAngleBracketRight });
                        continue;
                    } else {
                        self.putBackToken(maybe_else);
                        try stack.append(State { .SwitchCaseItem = &node.items });
                        continue;
                    }
                },

                State.SwitchCaseItem => |case_items| {
                    stack.append(State { .SwitchCaseItemCommaOrEnd = case_items }) catch unreachable;
                    try stack.append(State { .RangeExpressionBegin = DestPtr{ .Field = try case_items.addOne() } });
                },

                State.ExprListCommaOrEnd => |list_state| {
                    try self.commaOrEnd(&stack, list_state.end, list_state.ptr, State { .ExprListItemOrEnd = list_state });
                    continue;
                },

                State.FieldInitListCommaOrEnd => |list_state| {
                    try self.commaOrEnd(&stack, Token.Id.RBrace, list_state.ptr, State { .FieldInitListItemOrEnd = list_state });
                    continue;
                },

                State.FieldListCommaOrEnd => |container_decl| {
                    try self.commaOrEnd(&stack, Token.Id.RBrace, &container_decl.rbrace_token,
                        State { .ContainerDecl = container_decl });
                    continue;
                },

                State.IdentifierListCommaOrEnd => |list_state| {
                    try self.commaOrEnd(&stack, Token.Id.RBrace, list_state.ptr, State { .IdentifierListItemOrEnd = list_state });
                    continue;
                },

                State.SwitchCaseCommaOrEnd => |list_state| {
                    try self.commaOrEnd(&stack, Token.Id.RBrace, list_state.ptr, State { .SwitchCaseOrEnd = list_state });
                    continue;
                },

                State.SwitchCaseItemCommaOrEnd => |case_items| {
                    try self.commaOrEnd(&stack, Token.Id.EqualAngleBracketRight, null, State { .SwitchCaseItem = case_items });
                    continue;
                },

                State.Else => |dest| {
                    const else_token = self.getNextToken();
                    if (else_token.id != Token.Id.Keyword_else) {
                        self.putBackToken(else_token);
                        continue;
                    }

                    const node = try self.createNode(arena, ast.NodeElse,
                        ast.NodeElse {
                            .base = undefined,
                            .else_token = else_token,
                            .payload = null,
                            .body = undefined,
                        }
                    );
                    *dest = node;

                    stack.append(State { .Expression = DestPtr { .Field = &node.body } }) catch unreachable;
                    try stack.append(State { .Payload = &node.payload });
                },

                State.WhileContinueExpr => |dest| {
                    const colon = self.getNextToken();
                    if (colon.id != Token.Id.Colon) {
                        self.putBackToken(colon);
                        continue;
                    }

                    _ = (try self.expectToken(&stack, Token.Id.LParen)) ?? continue;
                    stack.append(State { .ExpectToken = Token.Id.RParen }) catch unreachable;
                    try stack.append(State { .AssignmentExpressionBegin = DestPtr { .NullableField = dest } });
                },

                State.SuspendBody => |suspend_node| {
                    if (suspend_node.payload != null) {
                        try stack.append(State { .AssignmentExpressionBegin = DestPtr { .NullableField = &suspend_node.body } });
                    }
                    continue;
                },

                State.AsyncEnd => |ctx| {
                    const node = ctx.dest_ptr.get();

                    switch (node.id) {
                        ast.Node.Id.FnProto => {
                            const fn_proto = @fieldParentPtr(ast.NodeFnProto, "base", node);
                            fn_proto.async_attr = ctx.attribute;
                        },
                        ast.Node.Id.SuffixOp => {
                            const suffix_op = @fieldParentPtr(ast.NodeSuffixOp, "base", node);
                            if (suffix_op.op == ast.NodeSuffixOp.SuffixOp.Call) {
                                suffix_op.op.Call.async_attr = ctx.attribute;
                                continue;
                            }

                            try self.parseError(&stack, node.firstToken(), "expected call or fn proto, found {}.",
                                @tagName(suffix_op.op));
                            continue;
                        },
                        else => {
                            try self.parseError(&stack, node.firstToken(), "expected call or fn proto, found {}.",
                                @tagName(node.id));
                            continue;
                        }
                    }
                },

                State.Payload => |dest| {
                    const lpipe = self.getNextToken();
                    if (lpipe.id != Token.Id.Pipe) {
                        self.putBackToken(lpipe);
                        continue;
                    }

                    const error_symbol = (try self.expectToken(&stack, Token.Id.Identifier)) ?? continue;
                    const rpipe = (try self.expectToken(&stack, Token.Id.Pipe)) ?? continue;
                    *dest = try self.createNode(arena, ast.NodePayload,
                        ast.NodePayload {
                            .base = undefined,
                            .lpipe = lpipe,
                            .error_symbol = try self.createLiteral(arena, ast.NodeIdentifier, error_symbol),
                            .rpipe = rpipe
                        }
                    );
                },

                State.PointerPayload => |dest| {
                    const lpipe = self.getNextToken();
                    if (lpipe.id != Token.Id.Pipe) {
                        self.putBackToken(lpipe);
                        continue;
                    }

                    const is_ptr = blk: {
                        const asterik = self.getNextToken();
                        if (asterik.id == Token.Id.Asterisk) {
                            break :blk true;
                        } else {
                            self.putBackToken(asterik);
                            break :blk false;
                        }
                    };

                    const value_symbol = (try self.expectToken(&stack, Token.Id.Identifier)) ?? continue;
                    const rpipe = (try self.expectToken(&stack, Token.Id.Pipe)) ?? continue;
                    *dest = try self.createNode(arena, ast.NodePointerPayload,
                        ast.NodePointerPayload {
                            .base = undefined,
                            .lpipe = lpipe,
                            .is_ptr = is_ptr,
                            .value_symbol = try self.createLiteral(arena, ast.NodeIdentifier, value_symbol),
                            .rpipe = rpipe
                        }
                    );
                },

                State.PointerIndexPayload => |dest| {
                    const lpipe = self.getNextToken();
                    if (lpipe.id != Token.Id.Pipe) {
                        self.putBackToken(lpipe);
                        continue;
                    }

                    const is_ptr = blk: {
                        const asterik = self.getNextToken();
                        if (asterik.id == Token.Id.Asterisk) {
                            break :blk true;
                        } else {
                            self.putBackToken(asterik);
                            break :blk false;
                        }
                    };

                    const value_symbol = (try self.expectToken(&stack, Token.Id.Identifier)) ?? continue;
                    const index_symbol = blk: {
                        const comma = self.getNextToken();
                        if (comma.id != Token.Id.Comma) {
                            self.putBackToken(comma);
                            break :blk null;
                        }

                        const symbol = (try self.expectToken(&stack, Token.Id.Identifier)) ?? continue;
                        break :blk try self.createLiteral(arena, ast.NodeIdentifier, symbol);
                    };

                    const rpipe = (try self.expectToken(&stack, Token.Id.Pipe)) ?? continue;
                    *dest = try self.createNode(arena, ast.NodePointerIndexPayload,
                        ast.NodePointerIndexPayload {
                            .base = undefined,
                            .lpipe = lpipe,
                            .is_ptr = is_ptr,
                            .value_symbol = try self.createLiteral(arena, ast.NodeIdentifier, value_symbol),
                            .index_symbol = index_symbol,
                            .rpipe = rpipe
                        }
                    );
                },

                State.AddrOfModifiers => |addr_of_info| {
                    var token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_align => {
                            stack.append(state) catch unreachable;
                            if (addr_of_info.align_expr != null) {
                                try self.parseError(&stack, token, "multiple align qualifiers");
                                continue;
                            }
                            try stack.append(State { .ExpectToken = Token.Id.RParen });
                            try stack.append(State { .Expression = DestPtr{.NullableField = &addr_of_info.align_expr} });
                            try stack.append(State { .ExpectToken = Token.Id.LParen });
                            continue;
                        },
                        Token.Id.Keyword_const => {
                            stack.append(state) catch unreachable;
                            if (addr_of_info.const_token != null) {
                                try self.parseError(&stack, token, "duplicate qualifier: const");
                                continue;
                            }
                            addr_of_info.const_token = token;
                            continue;
                        },
                        Token.Id.Keyword_volatile => {
                            stack.append(state) catch unreachable;
                            if (addr_of_info.volatile_token != null) {
                                try self.parseError(&stack, token, "duplicate qualifier: volatile");
                                continue;
                            }
                            addr_of_info.volatile_token = token;
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            continue;
                        },
                    }
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
                    stack.append(State { .FnProtoReturnType = fn_proto }) catch unreachable;

                    if (self.eatToken(Token.Id.Keyword_align)) |align_token| {
                        try stack.append(State { .ExpectToken = Token.Id.RParen });
                        try stack.append(State { .Expression = DestPtr { .NullableField = &fn_proto.align_expr } });
                        try stack.append(State { .ExpectToken = Token.Id.LParen });
                    }

                    continue;
                },

                State.FnProtoReturnType => |fn_proto| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Bang => {
                            fn_proto.return_type = ast.NodeFnProto.ReturnType { .InferErrorSet = undefined };
                            stack.append(State {
                                .TypeExprBegin = DestPtr {.Field = &fn_proto.return_type.InferErrorSet},
                            }) catch unreachable;
                            continue;
                        },
                        else => {
                            // TODO: this is a special case. Remove this when #760 is fixed
                            if (token.id == Token.Id.Keyword_error) {
                                if (self.isPeekToken(Token.Id.LBrace)) {
                                    fn_proto.return_type = ast.NodeFnProto.ReturnType {
                                        .Explicit = &(try self.createLiteral(arena, ast.NodeErrorType, token)).base
                                    };
                                    continue;
                                }
                            }

                            self.putBackToken(token);
                            fn_proto.return_type = ast.NodeFnProto.ReturnType { .Explicit = undefined };
                            stack.append(State {
                                .TypeExprBegin = DestPtr {.Field = &fn_proto.return_type.Explicit},
                            }) catch unreachable;
                            continue;
                        },
                    }
                },

                State.ParamDecl => |fn_proto| {
                    if (self.eatToken(Token.Id.RParen)) |_| {
                        continue;
                    }
                    const param_decl = try self.createAttachNode(arena, &fn_proto.params, ast.NodeParamDecl,
                        ast.NodeParamDecl {
                            .base = undefined,
                            .comptime_token = null,
                            .noalias_token = null,
                            .name_token = null,
                            .type_node = undefined,
                            .var_args_token = null,
                        },
                    );
                    if (self.eatToken(Token.Id.Keyword_comptime)) |comptime_token| {
                        param_decl.comptime_token = comptime_token;
                    } else if (self.eatToken(Token.Id.Keyword_noalias)) |noalias_token| {
                        param_decl.noalias_token = noalias_token;
                    }
                    if (self.eatToken(Token.Id.Identifier)) |identifier| {
                        if (self.eatToken(Token.Id.Colon)) |_| {
                            param_decl.name_token = identifier;
                        } else {
                            self.putBackToken(identifier);
                        }
                    }
                    if (self.eatToken(Token.Id.Ellipsis3)) |ellipsis3| {
                        param_decl.var_args_token = ellipsis3;
                        stack.append(State { .ExpectToken = Token.Id.RParen }) catch unreachable;
                        continue;
                    }

                    stack.append(State { .ParamDecl = fn_proto }) catch unreachable;
                    try stack.append(State.ParamDeclComma);
                    try stack.append(State {
                        .TypeExprBegin = DestPtr {.Field = &param_decl.type_node}
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
                        else => {
                            try self.parseError(&stack, token, "expected ',' or ')', found {}", @tagName(token.id));
                            continue;
                        },
                    }
                },

                State.FnDef => |fn_proto| {
                    const token = self.getNextToken();
                    switch(token.id) {
                        Token.Id.LBrace => {
                            const block = try self.createNode(arena, ast.NodeBlock,
                                ast.NodeBlock {
                                    .base = undefined,
                                    .label = null,
                                    .lbrace = token,
                                    .statements = ArrayList(&ast.Node).init(arena),
                                    .rbrace = undefined,
                                }
                            );
                            fn_proto.body_node = &block.base;
                            stack.append(State { .Block = block }) catch unreachable;
                            continue;
                        },
                        Token.Id.Semicolon => continue,
                        else => {
                            try self.parseError(&stack, token, "expected ';' or '{{', found {}", @tagName(token.id));
                            continue;
                        },
                    }
                },

                State.LabeledExpression => |ctx| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.LBrace => {
                            const block = try self.createToDestNode(arena, ctx.dest_ptr, ast.NodeBlock,
                                ast.NodeBlock {
                                    .base = undefined,
                                    .label = ctx.label,
                                    .lbrace = token,
                                    .statements = ArrayList(&ast.Node).init(arena),
                                    .rbrace = undefined,
                                }
                            );
                            stack.append(State { .Block = block }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_while => {
                            stack.append(State {
                                .While = LoopCtx {
                                    .label = ctx.label,
                                    .inline_token = null,
                                    .loop_token = token,
                                    .dest_ptr = ctx.dest_ptr,
                                }
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_for => {
                            stack.append(State {
                                .For = LoopCtx {
                                    .label = ctx.label,
                                    .inline_token = null,
                                    .loop_token = token,
                                    .dest_ptr = ctx.dest_ptr,
                                }
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_inline => {
                            stack.append(State {
                                .Inline = InlineCtx {
                                    .label = ctx.label,
                                    .inline_token = token,
                                    .dest_ptr = ctx.dest_ptr,
                                }
                            }) catch unreachable;
                            continue;
                        },
                        else => {
                            try self.parseError(&stack, token, "expected 'while', 'for', 'inline' or '{{', found {}", @tagName(token.id));
                            continue;
                        },
                    }
                },

                State.Inline => |ctx| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_while => {
                            stack.append(State {
                                .While = LoopCtx {
                                    .inline_token = ctx.inline_token,
                                    .label = ctx.label,
                                    .loop_token = token,
                                    .dest_ptr = ctx.dest_ptr,
                                }
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_for => {
                            stack.append(State {
                                .For = LoopCtx {
                                    .inline_token = ctx.inline_token,
                                    .label = ctx.label,
                                    .loop_token = token,
                                    .dest_ptr = ctx.dest_ptr,
                                }
                            }) catch unreachable;
                            continue;
                        },
                        else => {
                            try self.parseError(&stack, token, "expected 'while' or 'for', found {}", @tagName(token.id));
                            continue;
                        },
                    }
                },

                State.While => |ctx| {
                    const node = try self.createToDestNode(arena, ctx.dest_ptr, ast.NodeWhile,
                        ast.NodeWhile {
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
                    stack.append(State { .Else = &node.@"else" }) catch unreachable;
                    try stack.append(State { .Expression = DestPtr { .Field = &node.body } });
                    try stack.append(State { .WhileContinueExpr = &node.continue_expr });
                    try stack.append(State { .PointerPayload = &node.payload });
                    try stack.append(State { .ExpectToken = Token.Id.RParen });
                    try stack.append(State { .Expression = DestPtr { .Field = &node.condition } });
                    try stack.append(State { .ExpectToken = Token.Id.LParen });
                },

                State.For => |ctx| {
                    const node = try self.createToDestNode(arena, ctx.dest_ptr, ast.NodeFor,
                        ast.NodeFor {
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
                    stack.append(State { .Else = &node.@"else" }) catch unreachable;
                    try stack.append(State { .Expression = DestPtr { .Field = &node.body } });
                    try stack.append(State { .PointerIndexPayload = &node.payload });
                    try stack.append(State { .ExpectToken = Token.Id.RParen });
                    try stack.append(State { .Expression = DestPtr { .Field = &node.array_expr } });
                    try stack.append(State { .ExpectToken = Token.Id.LParen });
                },

                State.Block => |block| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.RBrace => {
                            block.rbrace = token;
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
                    const next = self.getNextToken();
                    switch (next.id) {
                        Token.Id.Keyword_comptime => {
                            const mut_token = self.getNextToken();
                            if (mut_token.id == Token.Id.Keyword_var or mut_token.id == Token.Id.Keyword_const) {
                                const var_decl = try self.createAttachNode(arena, &block.statements, ast.NodeVarDecl,
                                    ast.NodeVarDecl {
                                        .base = undefined,
                                        .visib_token = null,
                                        .mut_token = mut_token,
                                        .comptime_token = next,
                                        .extern_export_token = null,
                                        .type_node = null,
                                        .align_node = null,
                                        .init_node = null,
                                        .lib_name = null,
                                        // initialized later
                                        .name_token = undefined,
                                        .eq_token = undefined,
                                        .semicolon_token = undefined,
                                    }
                                );
                                stack.append(State { .VarDecl = var_decl }) catch unreachable;
                                continue;
                            } else {
                                self.putBackToken(mut_token);
                                self.putBackToken(next);
                                const statememt = try block.statements.addOne();
                                stack.append(State { .Semicolon = statememt }) catch unreachable;
                                try stack.append(State { .Expression = DestPtr{.Field = statememt } });
                            }
                        },
                        Token.Id.Keyword_var, Token.Id.Keyword_const => {
                            const var_decl = try self.createAttachNode(arena, &block.statements, ast.NodeVarDecl,
                                ast.NodeVarDecl {
                                    .base = undefined,
                                    .visib_token = null,
                                    .mut_token = next,
                                    .comptime_token = null,
                                    .extern_export_token = null,
                                    .type_node = null,
                                    .align_node = null,
                                    .init_node = null,
                                    .lib_name = null,
                                    // initialized later
                                    .name_token = undefined,
                                    .eq_token = undefined,
                                    .semicolon_token = undefined,
                                }
                            );
                            stack.append(State { .VarDecl = var_decl }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_defer, Token.Id.Keyword_errdefer => {
                            const node = try self.createAttachNode(arena, &block.statements, ast.NodeDefer,
                                ast.NodeDefer {
                                    .base = undefined,
                                    .defer_token = next,
                                    .kind = switch (next.id) {
                                        Token.Id.Keyword_defer => ast.NodeDefer.Kind.Unconditional,
                                        Token.Id.Keyword_errdefer => ast.NodeDefer.Kind.Error,
                                        else => unreachable,
                                    },
                                    .expr = undefined,
                                }
                            );
                            stack.append(State { .Semicolon = &node.base }) catch unreachable;
                            try stack.append(State { .AssignmentExpressionBegin = DestPtr{.Field = &node.expr } });
                            continue;
                        },
                        Token.Id.LBrace => {
                            const inner_block = try self.createAttachNode(arena, &block.statements, ast.NodeBlock,
                                ast.NodeBlock {
                                    .base = undefined,
                                    .label = null,
                                    .lbrace = next,
                                    .statements = ArrayList(&ast.Node).init(arena),
                                    .rbrace = undefined,
                                }
                            );
                            stack.append(State { .Block = inner_block }) catch unreachable;
                            continue;
                        },
                        else => {
                            self.putBackToken(next);
                            const statememt = try block.statements.addOne();
                            stack.append(State { .Semicolon = statememt }) catch unreachable;
                            try stack.append(State { .AssignmentExpressionBegin = DestPtr{.Field = statememt } });
                            continue;
                        }
                    }

                },

                State.Semicolon => |node_ptr| {
                    const node = *node_ptr;
                    if (requireSemiColon(node)) {
                        _ = (try self.expectToken(&stack, Token.Id.Semicolon)) ?? continue;
                    }
                }
            }
        }
    }

    fn requireSemiColon(node: &const ast.Node) bool {
        var n = node;
        while (true) {
            switch (n.id) {
                ast.Node.Id.Root,
                ast.Node.Id.StructField,
                ast.Node.Id.UnionTag,
                ast.Node.Id.EnumTag,
                ast.Node.Id.ParamDecl,
                ast.Node.Id.Block,
                ast.Node.Id.Payload,
                ast.Node.Id.PointerPayload,
                ast.Node.Id.PointerIndexPayload,
                ast.Node.Id.Switch,
                ast.Node.Id.SwitchCase,
                ast.Node.Id.SwitchElse,
                ast.Node.Id.FieldInitializer,
                ast.Node.Id.LineComment,
                ast.Node.Id.TestDecl => return false,
                ast.Node.Id.While => {
                    const while_node = @fieldParentPtr(ast.NodeWhile, "base", n);
                    if (while_node.@"else") |@"else"| {
                        n = @"else".base;
                        continue;
                    }

                    return while_node.body.id != ast.Node.Id.Block;
                },
                ast.Node.Id.For => {
                    const for_node = @fieldParentPtr(ast.NodeFor, "base", n);
                    if (for_node.@"else") |@"else"| {
                        n = @"else".base;
                        continue;
                    }

                    return for_node.body.id != ast.Node.Id.Block;
                },
                ast.Node.Id.If => {
                    const if_node = @fieldParentPtr(ast.NodeIf, "base", n);
                    if (if_node.@"else") |@"else"| {
                        n = @"else".base;
                        continue;
                    }

                    return if_node.body.id != ast.Node.Id.Block;
                },
                ast.Node.Id.Else => {
                    const else_node = @fieldParentPtr(ast.NodeElse, "base", n);
                    n = else_node.body;
                    continue;
                },
                ast.Node.Id.Defer => {
                    const defer_node = @fieldParentPtr(ast.NodeDefer, "base", n);
                    return defer_node.expr.id != ast.Node.Id.Block;
                },
                ast.Node.Id.Comptime => {
                    const comptime_node = @fieldParentPtr(ast.NodeComptime, "base", n);
                    return comptime_node.expr.id != ast.Node.Id.Block;
                },
                ast.Node.Id.Suspend => {
                    const suspend_node = @fieldParentPtr(ast.NodeSuspend, "base", n);
                    if (suspend_node.body) |body| {
                        return body.id != ast.Node.Id.Block;
                    }

                    return true;
                },
                else => return true,
            }
        }
    }

    fn parseStringLiteral(self: &Parser, arena: &mem.Allocator, token: &const Token) !?&ast.Node {
        switch (token.id) {
            Token.Id.StringLiteral => {
                return &(try self.createLiteral(arena, ast.NodeStringLiteral, token)).base;
            },
            Token.Id.MultilineStringLiteralLine => {
                const node = try self.createNode(arena, ast.NodeMultilineStringLiteral,
                    ast.NodeMultilineStringLiteral {
                        .base = undefined,
                        .tokens = ArrayList(Token).init(arena),
                    }
                );
                try node.tokens.append(token);
                while (true) {
                    const multiline_str = self.getNextToken();
                    if (multiline_str.id != Token.Id.MultilineStringLiteralLine) {
                        self.putBackToken(multiline_str);
                        break;
                    }

                    try node.tokens.append(multiline_str);
                }

                return &node.base;
            },
            // TODO: We shouldn't need a cast, but:
            // zig: /home/jc/Documents/zig/src/ir.cpp:7962: TypeTableEntry* ir_resolve_peer_types(IrAnalyze*, AstNode*, IrInstruction**, size_t): Assertion `err_set_type != nullptr' failed.
            else => return (?&ast.Node)(null),
        }
    }

    fn parseBlockExpr(self: &Parser, stack: &ArrayList(State), arena: &mem.Allocator, dest_ptr: &const DestPtr, token: &const Token) !bool {
        switch (token.id) {
            Token.Id.Keyword_suspend => {
                const node = try self.createToDestNode(arena, dest_ptr, ast.NodeSuspend,
                    ast.NodeSuspend {
                        .base = undefined,
                        .suspend_token = *token,
                        .payload = null,
                        .body = null,
                    }
                );

                stack.append(State { .SuspendBody = node }) catch unreachable;
                try stack.append(State { .Payload = &node.payload });
                return true;
            },
            Token.Id.Keyword_if => {
                const node = try self.createToDestNode(arena, dest_ptr, ast.NodeIf,
                    ast.NodeIf {
                        .base = undefined,
                        .if_token = *token,
                        .condition = undefined,
                        .payload = null,
                        .body = undefined,
                        .@"else" = null,
                    }
                );

                stack.append(State { .Else = &node.@"else" }) catch unreachable;
                try stack.append(State { .Expression = DestPtr { .Field = &node.body } });
                try stack.append(State { .PointerPayload = &node.payload });
                try stack.append(State { .ExpectToken = Token.Id.RParen });
                try stack.append(State { .Expression = DestPtr { .Field = &node.condition } });
                try stack.append(State { .ExpectToken = Token.Id.LParen });
                return true;
            },
            Token.Id.Keyword_while => {
                stack.append(State {
                    .While = LoopCtx {
                        .label = null,
                        .inline_token = null,
                        .loop_token = *token,
                        .dest_ptr = *dest_ptr,
                    }
                }) catch unreachable;
                return true;
            },
            Token.Id.Keyword_for => {
                stack.append(State {
                    .For = LoopCtx {
                        .label = null,
                        .inline_token = null,
                        .loop_token = *token,
                        .dest_ptr = *dest_ptr,
                    }
                }) catch unreachable;
                return true;
            },
            Token.Id.Keyword_switch => {
                const node = try self.createToDestNode(arena, dest_ptr, ast.NodeSwitch,
                    ast.NodeSwitch {
                        .base = undefined,
                        .switch_token = *token,
                        .expr = undefined,
                        .cases = ArrayList(&ast.NodeSwitchCase).init(arena),
                        .rbrace = undefined,
                    }
                );

                stack.append(State {
                    .SwitchCaseOrEnd = ListSave(&ast.NodeSwitchCase) {
                        .list = &node.cases,
                        .ptr = &node.rbrace,
                    },
                }) catch unreachable;
                try stack.append(State { .ExpectToken = Token.Id.LBrace });
                try stack.append(State { .ExpectToken = Token.Id.RParen });
                try stack.append(State { .Expression = DestPtr { .Field = &node.expr } });
                try stack.append(State { .ExpectToken = Token.Id.LParen });
                return true;
            },
            Token.Id.Keyword_comptime => {
                const node = try self.createToDestNode(arena, dest_ptr, ast.NodeComptime,
                    ast.NodeComptime {
                        .base = undefined,
                        .comptime_token = *token,
                        .expr = undefined,
                    }
                );
                try stack.append(State { .Expression = DestPtr { .Field = &node.expr } });
                return true;
            },
            Token.Id.LBrace => {
                const block = try self.createToDestNode(arena, dest_ptr, ast.NodeBlock,
                    ast.NodeBlock {
                        .base = undefined,
                        .label = null,
                        .lbrace = *token,
                        .statements = ArrayList(&ast.Node).init(arena),
                        .rbrace = undefined,
                    }
                );
                stack.append(State { .Block = block }) catch unreachable;
                return true;
            },
            else => {
                return false;
            }
        }
    }

    fn commaOrEnd(self: &Parser, stack: &ArrayList(State), end: &const Token.Id, maybe_ptr: ?&Token, state_after_comma: &const State) !void {
        var token = self.getNextToken();
        switch (token.id) {
            Token.Id.Comma => {
                stack.append(state_after_comma) catch unreachable;
            },
            else => {
                const IdTag = @TagType(Token.Id);
                if (IdTag(*end) == token.id) {
                    if (maybe_ptr) |ptr| {
                        *ptr = token;
                    }
                    return;
                }

                try self.parseError(stack, token, "expected ',' or {}, found {}", @tagName(*end), @tagName(token.id));
            },
        }
    }

    fn tokenIdToAssignment(id: &const Token.Id) ?ast.NodeInfixOp.InfixOp {
        // TODO: We have to cast all cases because of this:
        // error: expected type '?InfixOp', found '?@TagType(InfixOp)'
        return switch (*id) {
            Token.Id.AmpersandEqual => ast.NodeInfixOp.InfixOp { .AssignBitAnd = void{} },
            Token.Id.AngleBracketAngleBracketLeftEqual => ast.NodeInfixOp.InfixOp { .AssignBitShiftLeft = void{} },
            Token.Id.AngleBracketAngleBracketRightEqual => ast.NodeInfixOp.InfixOp { .AssignBitShiftRight = void{} },
            Token.Id.AsteriskEqual => ast.NodeInfixOp.InfixOp { .AssignTimes = void{} },
            Token.Id.AsteriskPercentEqual => ast.NodeInfixOp.InfixOp { .AssignTimesWarp = void{} },
            Token.Id.CaretEqual => ast.NodeInfixOp.InfixOp { .AssignBitXor = void{} },
            Token.Id.Equal => ast.NodeInfixOp.InfixOp { .Assign = void{} },
            Token.Id.MinusEqual => ast.NodeInfixOp.InfixOp { .AssignMinus = void{} },
            Token.Id.MinusPercentEqual => ast.NodeInfixOp.InfixOp { .AssignMinusWrap = void{} },
            Token.Id.PercentEqual => ast.NodeInfixOp.InfixOp { .AssignMod = void{} },
            Token.Id.PipeEqual => ast.NodeInfixOp.InfixOp { .AssignBitOr = void{} },
            Token.Id.PlusEqual => ast.NodeInfixOp.InfixOp { .AssignPlus = void{} },
            Token.Id.PlusPercentEqual => ast.NodeInfixOp.InfixOp { .AssignPlusWrap = void{} },
            Token.Id.SlashEqual => ast.NodeInfixOp.InfixOp { .AssignDiv = void{} },
            else => null,
        };
    }

    fn tokenIdToComparison(id: &const Token.Id) ?ast.NodeInfixOp.InfixOp {
        return switch (*id) {
            Token.Id.BangEqual => ast.NodeInfixOp.InfixOp { .BangEqual = void{} },
            Token.Id.EqualEqual => ast.NodeInfixOp.InfixOp { .EqualEqual = void{} },
            Token.Id.AngleBracketLeft => ast.NodeInfixOp.InfixOp { .LessThan = void{} },
            Token.Id.AngleBracketLeftEqual => ast.NodeInfixOp.InfixOp { .LessOrEqual = void{} },
            Token.Id.AngleBracketRight => ast.NodeInfixOp.InfixOp { .GreaterThan = void{} },
            Token.Id.AngleBracketRightEqual => ast.NodeInfixOp.InfixOp { .GreaterOrEqual = void{} },
            else => null,
        };
    }

    fn tokenIdToBitShift(id: &const Token.Id) ?ast.NodeInfixOp.InfixOp {
        return switch (*id) {
            Token.Id.AngleBracketAngleBracketLeft => ast.NodeInfixOp.InfixOp { .BitShiftLeft = void{} },
            Token.Id.AngleBracketAngleBracketRight => ast.NodeInfixOp.InfixOp { .BitShiftRight = void{} },
            else => null,
        };
    }

    fn tokenIdToAddition(id: &const Token.Id) ?ast.NodeInfixOp.InfixOp {
        return switch (*id) {
            Token.Id.Minus => ast.NodeInfixOp.InfixOp { .Sub = void{} },
            Token.Id.MinusPercent => ast.NodeInfixOp.InfixOp { .SubWrap = void{} },
            Token.Id.Plus => ast.NodeInfixOp.InfixOp { .Add = void{} },
            Token.Id.PlusPercent => ast.NodeInfixOp.InfixOp { .AddWrap = void{} },
            Token.Id.PlusPlus => ast.NodeInfixOp.InfixOp { .ArrayCat = void{} },
            else => null,
        };
    }

    fn tokenIdToMultiply(id: &const Token.Id) ?ast.NodeInfixOp.InfixOp {
        return switch (*id) {
            Token.Id.Slash => ast.NodeInfixOp.InfixOp { .Div = void{} },
            Token.Id.Asterisk => ast.NodeInfixOp.InfixOp { .Mult = void{} },
            Token.Id.AsteriskAsterisk => ast.NodeInfixOp.InfixOp { .ArrayMult = void{} },
            Token.Id.AsteriskPercent => ast.NodeInfixOp.InfixOp { .MultWrap = void{} },
            Token.Id.Percent => ast.NodeInfixOp.InfixOp { .Mod = void{} },
            Token.Id.PipePipe => ast.NodeInfixOp.InfixOp { .MergeErrorSets = void{} },
            else => null,
        };
    }

    fn tokenIdToPrefixOp(id: &const Token.Id) ?ast.NodePrefixOp.PrefixOp {
        return switch (*id) {
            Token.Id.Bang => ast.NodePrefixOp.PrefixOp { .BoolNot = void{} },
            Token.Id.Tilde => ast.NodePrefixOp.PrefixOp { .BitNot = void{} },
            Token.Id.Minus => ast.NodePrefixOp.PrefixOp { .Negation = void{} },
            Token.Id.MinusPercent => ast.NodePrefixOp.PrefixOp { .NegationWrap = void{} },
            Token.Id.Asterisk, Token.Id.AsteriskAsterisk => ast.NodePrefixOp.PrefixOp { .Deref = void{} },
            Token.Id.Ampersand => ast.NodePrefixOp.PrefixOp {
                .AddrOf = ast.NodePrefixOp.AddrOfInfo {
                    .align_expr = null,
                    .bit_offset_start_token = null,
                    .bit_offset_end_token = null,
                    .const_token = null,
                    .volatile_token = null,
                },
            },
            Token.Id.QuestionMark => ast.NodePrefixOp.PrefixOp { .MaybeType = void{} },
            Token.Id.QuestionMarkQuestionMark => ast.NodePrefixOp.PrefixOp { .UnwrapMaybe = void{} },
            Token.Id.Keyword_await => ast.NodePrefixOp.PrefixOp { .Await = void{} },
            Token.Id.Keyword_try => ast.NodePrefixOp.PrefixOp { .Try = void{ } },
            else => null,
        };
    }

    fn createNode(self: &Parser, arena: &mem.Allocator, comptime T: type, init_to: &const T) !&T {
        const node = try arena.create(T);
        *node = *init_to;
        node.base = blk: {
            const id = ast.Node.typeToId(T);
            if (self.pending_line_comment_node) |comment_node| {
                self.pending_line_comment_node = null;
                break :blk ast.Node {.id = id, .comment = comment_node};
            }
            break :blk ast.Node {.id = id, .comment = null };
        };

        return node;
    }

    fn createAttachNode(self: &Parser, arena: &mem.Allocator, list: &ArrayList(&ast.Node), comptime T: type, init_to: &const T) !&T {
        const node = try self.createNode(arena, T, init_to);
        try list.append(&node.base);

        return node;
    }

    fn createToDestNode(self: &Parser, arena: &mem.Allocator, dest_ptr: &const DestPtr, comptime T: type, init_to: &const T) !&T {
        const node = try self.createNode(arena, T, init_to);
        dest_ptr.store(&node.base);

        return node;
    }

    fn createLiteral(self: &Parser, arena: &mem.Allocator, comptime T: type, token: &const Token) !&T {
        return self.createNode(arena, T,
            T {
                .base = undefined,
                .token = *token,
            }
        );
    }

    fn parseError(self: &Parser, stack: &ArrayList(State), token: &const Token, comptime fmt: []const u8, args: ...) !void {
        // Before reporting an error. We pop the stack to see if our state was optional
        self.revertIfOptional(stack) catch {
            const loc = self.tokenizer.getTokenLocation(0, token);
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
        };
    }

    fn revertIfOptional(self: &Parser, stack: &ArrayList(State)) !void {
        while (stack.popOrNull()) |state| {
            switch (state) {
                State.Optional => |revert| {
                    *self = revert.parser;
                    *self.tokenizer = revert.tokenizer;
                    *revert.ptr = null;
                    return;
                },
                else => { }
            }
        }

        return error.NoOptionalStateFound;
    }

    fn expectToken(self: &Parser, stack: &ArrayList(State), id: @TagType(Token.Id)) !?Token {
        const token = self.getNextToken();
        if (token.id != id) {
            try self.parseError(stack, token, "expected {}, found {}", @tagName(id), @tagName(token.id));
            return null;
        }
        return token;
    }

    fn eatToken(self: &Parser, id: @TagType(Token.Id)) ?Token {
        if (self.isPeekToken(id)) {
            return self.getNextToken();
        }
        return null;
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

    fn isPeekToken(self: &Parser, id: @TagType(Token.Id)) bool {
        const token = self.getNextToken();
        defer self.putBackToken(token);
        return id == token.id;
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
        ParamDecl: &ast.Node,
        Text: []const u8,
        Expression: &ast.Node,
        VarDecl: &ast.NodeVarDecl,
        Statement: &ast.Node,
        FieldInitializer: &ast.NodeFieldInitializer,
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
                            const loc = self.tokenizer.getTokenLocation(prev_node.lastToken().end, decl.firstToken());
                            if (loc.line >= 2) {
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

                            if (fn_proto.body_node) |body_node| {
                                stack.append(RenderState { .Expression = body_node}) catch unreachable;
                                try stack.append(RenderState { .Text = " "});
                            } else {
                                stack.append(RenderState { .Text = ";" }) catch unreachable;
                            }

                            try stack.append(RenderState { .Expression = decl });
                        },
                        ast.Node.Id.Use => {
                            const use_decl = @fieldParentPtr(ast.NodeUse, "base", decl);
                            if (use_decl.visib_token) |visib_token| {
                                try stream.print("{} ", self.tokenizer.getTokenSlice(visib_token));
                            }
                            try stream.print("use ");
                            try stack.append(RenderState { .Text = ";" });
                            try stack.append(RenderState { .Expression = use_decl.expr });
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
                        ast.Node.Id.StructField => {
                            const field = @fieldParentPtr(ast.NodeStructField, "base", decl);
                            if (field.visib_token) |visib_token| {
                                try stream.print("{} ", self.tokenizer.getTokenSlice(visib_token));
                            }
                            try stream.print("{}: ", self.tokenizer.getTokenSlice(field.name_token));
                            try stack.append(RenderState { .Expression = field.type_expr});
                        },
                        ast.Node.Id.UnionTag => {
                            const tag = @fieldParentPtr(ast.NodeUnionTag, "base", decl);
                            try stream.print("{}", self.tokenizer.getTokenSlice(tag.name_token));

                            if (tag.type_expr) |type_expr| {
                                try stream.print(": ");
                                try stack.append(RenderState { .Expression = type_expr});
                            }
                        },
                        ast.Node.Id.EnumTag => {
                            const tag = @fieldParentPtr(ast.NodeEnumTag, "base", decl);
                            try stream.print("{}", self.tokenizer.getTokenSlice(tag.name_token));

                            if (tag.value) |value| {
                                try stream.print(" = ");
                                try stack.append(RenderState { .Expression = value});
                            }
                        },
                        ast.Node.Id.Comptime => {
                            if (requireSemiColon(decl)) {
                                try stack.append(RenderState { .Text = ";" });
                            }
                            try stack.append(RenderState { .Expression = decl });
                        },
                        else => unreachable,
                    }
                },

                RenderState.FieldInitializer => |field_init| {
                    try stream.print(".{}", self.tokenizer.getTokenSlice(field_init.name_token));
                    try stream.print(" = ");
                    try stack.append(RenderState { .Expression = field_init.expr });
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

                    if (var_decl.extern_export_token) |extern_export_token| {
                        if (var_decl.lib_name != null) {
                            try stack.append(RenderState { .Text = " " });
                            try stack.append(RenderState { .Expression = ??var_decl.lib_name });
                        }
                        try stack.append(RenderState { .Text = " " });
                        try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(extern_export_token) });
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
                        try stream.print("{}", self.tokenizer.getTokenSlice(identifier.token));
                    },
                    ast.Node.Id.Block => {
                        const block = @fieldParentPtr(ast.NodeBlock, "base", base);
                        if (block.label) |label| {
                            try stream.print("{}: ", self.tokenizer.getTokenSlice(label));
                        }

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
                                            const prev_node = block.statements.items[i - 1];
                                            const loc = self.tokenizer.getTokenLocation(prev_node.lastToken().end, statement_node.firstToken());
                                            if (loc.line >= 2) {
                                                break :blk "\n\n";
                                            }
                                        }
                                        break :blk "\n";
                                    },
                                });
                            }
                        }
                    },
                    ast.Node.Id.Defer => {
                        const defer_node = @fieldParentPtr(ast.NodeDefer, "base", base);
                        try stream.print("{} ", self.tokenizer.getTokenSlice(defer_node.defer_token));
                        try stack.append(RenderState { .Expression = defer_node.expr });
                    },
                    ast.Node.Id.Comptime => {
                        const comptime_node = @fieldParentPtr(ast.NodeComptime, "base", base);
                        try stream.print("{} ", self.tokenizer.getTokenSlice(comptime_node.comptime_token));
                        try stack.append(RenderState { .Expression = comptime_node.expr });
                    },
                    ast.Node.Id.AsyncAttribute => {
                        const async_attr = @fieldParentPtr(ast.NodeAsyncAttribute, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(async_attr.async_token));

                        if (async_attr.allocator_type) |allocator_type| {
                            try stack.append(RenderState { .Text = ">" });
                            try stack.append(RenderState { .Expression = allocator_type });
                            try stack.append(RenderState { .Text = "<" });
                        }
                    },
                    ast.Node.Id.Suspend => {
                        const suspend_node = @fieldParentPtr(ast.NodeSuspend, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(suspend_node.suspend_token));

                        if (suspend_node.body) |body| {
                            try stack.append(RenderState { .Expression = body });
                            try stack.append(RenderState { .Text = " " });
                        }

                        if (suspend_node.payload) |payload| {
                            try stack.append(RenderState { .Expression = &payload.base });
                            try stack.append(RenderState { .Text = " " });
                        }
                    },
                    ast.Node.Id.InfixOp => {
                        const prefix_op_node = @fieldParentPtr(ast.NodeInfixOp, "base", base);
                        try stack.append(RenderState { .Expression = prefix_op_node.rhs });

                        if (prefix_op_node.op == ast.NodeInfixOp.InfixOp.Catch) {
                            if (prefix_op_node.op.Catch) |payload| {
                            try stack.append(RenderState { .Text = " " });
                                try stack.append(RenderState { .Expression = &payload.base });
                            }
                            try stack.append(RenderState { .Text = " catch " });
                        } else {
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
                                ast.NodeInfixOp.InfixOp.Range => " ... ",
                                ast.NodeInfixOp.InfixOp.Catch => unreachable,
                            };

                            try stack.append(RenderState { .Text = text });
                        }
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
                            ast.NodePrefixOp.PrefixOp.Try => try stream.write("try "),
                            ast.NodePrefixOp.PrefixOp.UnwrapMaybe => try stream.write("??"),
                            ast.NodePrefixOp.PrefixOp.MaybeType => try stream.write("?"),
                            ast.NodePrefixOp.PrefixOp.Await => try stream.write("await "),
                            ast.NodePrefixOp.PrefixOp.Cancel => try stream.write("cancel "),
                            ast.NodePrefixOp.PrefixOp.Resume => try stream.write("resume "),
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
                                try stack.append(RenderState { .Expression = suffix_op.lhs });

                                if (call_info.async_attr) |async_attr| {
                                    try stack.append(RenderState { .Text = " "});
                                    try stack.append(RenderState { .Expression = &async_attr.base });
                                }
                            },
                            ast.NodeSuffixOp.SuffixOp.ArrayAccess => |index_expr| {
                                try stack.append(RenderState { .Text = "]"});
                                try stack.append(RenderState { .Expression = index_expr});
                                try stack.append(RenderState { .Text = "["});
                                try stack.append(RenderState { .Expression = suffix_op.lhs });
                            },
                            ast.NodeSuffixOp.SuffixOp.Slice => |range| {
                                try stack.append(RenderState { .Text = "]"});
                                if (range.end) |end| {
                                    try stack.append(RenderState { .Expression = end});
                                }
                                try stack.append(RenderState { .Text = ".."});
                                try stack.append(RenderState { .Expression = range.start});
                                try stack.append(RenderState { .Text = "["});
                                try stack.append(RenderState { .Expression = suffix_op.lhs });
                            },
                            ast.NodeSuffixOp.SuffixOp.StructInitializer => |field_inits| {
                                if (field_inits.len == 0) {
                                    try stack.append(RenderState { .Text = "{}" });
                                    try stack.append(RenderState { .Expression = suffix_op.lhs });
                                    continue;
                                }
                                try stack.append(RenderState { .Text = "}"});
                                try stack.append(RenderState.PrintIndent);
                                try stack.append(RenderState { .Indent = indent });
                                var i = field_inits.len;
                                while (i != 0) {
                                    i -= 1;
                                    const field_init = field_inits.at(i);
                                    try stack.append(RenderState { .Text = ",\n" });
                                    try stack.append(RenderState { .FieldInitializer = field_init });
                                    try stack.append(RenderState.PrintIndent);
                                }
                                try stack.append(RenderState { .Indent = indent + indent_delta });
                                try stack.append(RenderState { .Text = " {\n"});
                                try stack.append(RenderState { .Expression = suffix_op.lhs });
                            },
                            ast.NodeSuffixOp.SuffixOp.ArrayInitializer => |exprs| {
                                if (exprs.len == 0) {
                                    try stack.append(RenderState { .Text = "{}" });
                                    try stack.append(RenderState { .Expression = suffix_op.lhs });
                                    continue;
                                }
                                try stack.append(RenderState { .Text = "}"});
                                try stack.append(RenderState.PrintIndent);
                                try stack.append(RenderState { .Indent = indent });
                                var i = exprs.len;
                                while (i != 0) {
                                    i -= 1;
                                    const expr = exprs.at(i);
                                    try stack.append(RenderState { .Text = ",\n" });
                                    try stack.append(RenderState { .Expression = expr });
                                    try stack.append(RenderState.PrintIndent);
                                }
                                try stack.append(RenderState { .Indent = indent + indent_delta });
                                try stack.append(RenderState { .Text = " {\n"});
                                try stack.append(RenderState { .Expression = suffix_op.lhs });
                            },
                        }
                    },
                    ast.Node.Id.ControlFlowExpression => {
                        const flow_expr = @fieldParentPtr(ast.NodeControlFlowExpression, "base", base);
                        switch (flow_expr.kind) {
                            ast.NodeControlFlowExpression.Kind.Break => |maybe_blk_token| {
                                try stream.print("break");
                                if (maybe_blk_token) |blk_token| {
                                    try stream.print(" :{}", self.tokenizer.getTokenSlice(blk_token));
                                }
                            },
                            ast.NodeControlFlowExpression.Kind.Continue => |maybe_blk_token| {
                                try stream.print("continue");
                                if (maybe_blk_token) |blk_token| {
                                    try stream.print(" :{}", self.tokenizer.getTokenSlice(blk_token));
                                }
                            },
                            ast.NodeControlFlowExpression.Kind.Return => {
                                try stream.print("return");
                            },

                        }

                        if (flow_expr.rhs) |rhs| {
                            try stream.print(" ");
                            try stack.append(RenderState { .Expression = rhs });
                        }
                    },
                    ast.Node.Id.Payload => {
                        const payload = @fieldParentPtr(ast.NodePayload, "base", base);
                        try stack.append(RenderState { .Text = "|"});
                        try stack.append(RenderState { .Expression = &payload.error_symbol.base });
                        try stack.append(RenderState { .Text = "|"});
                    },
                    ast.Node.Id.PointerPayload => {
                        const payload = @fieldParentPtr(ast.NodePointerPayload, "base", base);
                        try stack.append(RenderState { .Text = "|"});
                        try stack.append(RenderState { .Expression = &payload.value_symbol.base });

                        if (payload.is_ptr) {
                            try stack.append(RenderState { .Text = "*"});
                        }

                        try stack.append(RenderState { .Text = "|"});
                    },
                    ast.Node.Id.PointerIndexPayload => {
                        const payload = @fieldParentPtr(ast.NodePointerIndexPayload, "base", base);
                        try stack.append(RenderState { .Text = "|"});

                        if (payload.index_symbol) |index_symbol| {
                            try stack.append(RenderState { .Expression = &index_symbol.base });
                            try stack.append(RenderState { .Text = ", "});
                        }

                        try stack.append(RenderState { .Expression = &payload.value_symbol.base });

                        if (payload.is_ptr) {
                            try stack.append(RenderState { .Text = "*"});
                        }

                        try stack.append(RenderState { .Text = "|"});
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
                    ast.Node.Id.VarType => {
                        const var_type = @fieldParentPtr(ast.NodeVarType, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(var_type.token));
                    },
                    ast.Node.Id.ContainerDecl => {
                        const container_decl = @fieldParentPtr(ast.NodeContainerDecl, "base", base);

                        switch (container_decl.layout) {
                            ast.NodeContainerDecl.Layout.Packed => try stream.print("packed "),
                            ast.NodeContainerDecl.Layout.Extern => try stream.print("extern "),
                            ast.NodeContainerDecl.Layout.Auto => { },
                        }

                        switch (container_decl.kind) {
                            ast.NodeContainerDecl.Kind.Struct => try stream.print("struct"),
                            ast.NodeContainerDecl.Kind.Enum => try stream.print("enum"),
                            ast.NodeContainerDecl.Kind.Union => try stream.print("union"),
                        }

                        try stack.append(RenderState { .Text = "}"});
                        try stack.append(RenderState.PrintIndent);
                        try stack.append(RenderState { .Indent = indent });
                        try stack.append(RenderState { .Text = "\n"});

                        const fields_and_decls = container_decl.fields_and_decls.toSliceConst();
                        var i = fields_and_decls.len;
                        while (i != 0) {
                            i -= 1;
                            const node = fields_and_decls[i];
                            try stack.append(RenderState { .TopLevelDecl = node});
                            try stack.append(RenderState.PrintIndent);
                            try stack.append(RenderState {
                                .Text = blk: {
                                    if (i != 0) {
                                        const prev_node = fields_and_decls[i - 1];
                                        const loc = self.tokenizer.getTokenLocation(prev_node.lastToken().end, node.firstToken());
                                        if (loc.line >= 2) {
                                            break :blk "\n\n";
                                        }
                                    }
                                    break :blk "\n";
                                },
                            });

                            if (i != 0) {
                                const prev_node = fields_and_decls[i - 1];
                                switch (prev_node.id) {
                                    ast.Node.Id.StructField,
                                    ast.Node.Id.UnionTag,
                                    ast.Node.Id.EnumTag => {
                                        try stack.append(RenderState { .Text = "," });
                                    },
                                    else => { }
                                }
                            }
                        }
                        try stack.append(RenderState { .Indent = indent + indent_delta});
                        try stack.append(RenderState { .Text = "{"});

                        switch (container_decl.init_arg_expr) {
                            ast.NodeContainerDecl.InitArg.None => try stack.append(RenderState { .Text = " "}),
                            ast.NodeContainerDecl.InitArg.Enum => try stack.append(RenderState { .Text = "(enum) "}),
                            ast.NodeContainerDecl.InitArg.Type => |type_expr| {
                                try stack.append(RenderState { .Text = ") "});
                                try stack.append(RenderState { .Expression = type_expr});
                                try stack.append(RenderState { .Text = "("});
                            },
                        }
                    },
                    ast.Node.Id.ErrorSetDecl => {
                        const err_set_decl = @fieldParentPtr(ast.NodeErrorSetDecl, "base", base);
                        try stream.print("error ");

                        try stack.append(RenderState { .Text = "}"});
                        try stack.append(RenderState.PrintIndent);
                        try stack.append(RenderState { .Indent = indent });
                        try stack.append(RenderState { .Text = "\n"});

                        const decls = err_set_decl.decls.toSliceConst();
                        var i = decls.len;
                        while (i != 0) {
                            i -= 1;
                            const node = decls[i];
                            try stack.append(RenderState { .Expression = &node.base});
                            try stack.append(RenderState.PrintIndent);
                            try stack.append(RenderState {
                                .Text = blk: {
                                    if (i != 0) {
                                        const prev_node = decls[i - 1];
                                        const loc = self.tokenizer.getTokenLocation(prev_node.lastToken().end, node.firstToken());
                                        if (loc.line >= 2) {
                                            break :blk "\n\n";
                                        }
                                    }
                                    break :blk "\n";
                                },
                            });

                            if (i != 0) {
                                try stack.append(RenderState { .Text = "," });
                            }
                        }
                        try stack.append(RenderState { .Indent = indent + indent_delta});
                        try stack.append(RenderState { .Text = "{"});
                    },
                    ast.Node.Id.MultilineStringLiteral => {
                        const multiline_str_literal = @fieldParentPtr(ast.NodeMultilineStringLiteral, "base", base);
                        try stream.print("\n");

                        var i : usize = 0;
                        while (i < multiline_str_literal.tokens.len) : (i += 1) {
                            const t = multiline_str_literal.tokens.at(i);
                            try stream.writeByteNTimes(' ', indent + indent_delta);
                            try stream.print("{}", self.tokenizer.getTokenSlice(t));
                        }
                        try stream.writeByteNTimes(' ', indent + indent_delta);
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
                    ast.Node.Id.FnProto => {
                        const fn_proto = @fieldParentPtr(ast.NodeFnProto, "base", base);

                        switch (fn_proto.return_type) {
                            ast.NodeFnProto.ReturnType.Explicit => |node| {
                                try stack.append(RenderState { .Expression = node});
                            },
                            ast.NodeFnProto.ReturnType.InferErrorSet => |node| {
                                try stack.append(RenderState { .Expression = node});
                                try stack.append(RenderState { .Text = "!"});
                            },
                        }

                        if (fn_proto.align_expr) |align_expr| {
                            try stack.append(RenderState { .Text = ") " });
                            try stack.append(RenderState { .Expression = align_expr});
                            try stack.append(RenderState { .Text = "align(" });
                        }

                        try stack.append(RenderState { .Text = ") " });
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
                            try stack.append(RenderState { .Text = " " });
                        }

                        try stack.append(RenderState { .Text = "fn" });

                        if (fn_proto.async_attr) |async_attr| {
                            try stack.append(RenderState { .Text = " " });
                            try stack.append(RenderState { .Expression = &async_attr.base });
                        }

                        if (fn_proto.cc_token) |cc_token| {
                            try stack.append(RenderState { .Text = " " });
                            try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(cc_token) });
                        }

                        if (fn_proto.lib_name) |lib_name| {
                            try stack.append(RenderState { .Text = " " });
                            try stack.append(RenderState { .Expression = lib_name });
                        }
                        if (fn_proto.extern_export_inline_token) |extern_export_inline_token| {
                            try stack.append(RenderState { .Text = " " });
                            try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(extern_export_inline_token) });
                        }

                        if (fn_proto.visib_token) |visib_token| {
                            assert(visib_token.id == Token.Id.Keyword_pub or visib_token.id == Token.Id.Keyword_export);
                            try stack.append(RenderState { .Text = " " });
                            try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(visib_token) });
                        }
                    },
                    ast.Node.Id.LineComment => @panic("TODO render line comment in an expression"),
                    ast.Node.Id.Switch => {
                        const switch_node = @fieldParentPtr(ast.NodeSwitch, "base", base);
                        try stream.print("{} (", self.tokenizer.getTokenSlice(switch_node.switch_token));

                        try stack.append(RenderState { .Text = "}"});
                        try stack.append(RenderState.PrintIndent);
                        try stack.append(RenderState { .Indent = indent });
                        try stack.append(RenderState { .Text = "\n"});

                        const cases = switch_node.cases.toSliceConst();
                        var i = cases.len;
                        while (i != 0) {
                            i -= 1;
                            const node = cases[i];
                            try stack.append(RenderState { .Expression = &node.base});
                            try stack.append(RenderState.PrintIndent);
                            try stack.append(RenderState {
                                .Text = blk: {
                                    if (i != 0) {
                                        const prev_node = cases[i - 1];
                                        const loc = self.tokenizer.getTokenLocation(prev_node.lastToken().end, node.firstToken());
                                        if (loc.line >= 2) {
                                            break :blk "\n\n";
                                        }
                                    }
                                    break :blk "\n";
                                },
                            });

                            if (i != 0) {
                                try stack.append(RenderState { .Text = "," });
                            }
                        }
                        try stack.append(RenderState { .Indent = indent + indent_delta});
                        try stack.append(RenderState { .Text = ") {"});
                        try stack.append(RenderState { .Expression = switch_node.expr });
                    },
                    ast.Node.Id.SwitchCase => {
                        const switch_case = @fieldParentPtr(ast.NodeSwitchCase, "base", base);

                        try stack.append(RenderState { .Expression = switch_case.expr });
                        if (switch_case.payload) |payload| {
                            try stack.append(RenderState { .Text = " " });
                            try stack.append(RenderState { .Expression = &payload.base });
                        }
                        try stack.append(RenderState { .Text = " => "});

                        const items = switch_case.items.toSliceConst();
                        var i = items.len;
                        while (i != 0) {
                            i -= 1;
                            try stack.append(RenderState { .Expression = items[i] });

                            if (i != 0) {
                                try stack.append(RenderState { .Text = ", " });
                            }
                        }
                    },
                    ast.Node.Id.SwitchElse => {
                        const switch_else = @fieldParentPtr(ast.NodeSwitchElse, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(switch_else.token));
                    },
                    ast.Node.Id.Else => {
                        const else_node = @fieldParentPtr(ast.NodeElse, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(else_node.else_token));

                        switch (else_node.body.id) {
                            ast.Node.Id.Block, ast.Node.Id.If,
                            ast.Node.Id.For, ast.Node.Id.While,
                            ast.Node.Id.Switch => {
                                try stream.print(" ");
                                try stack.append(RenderState { .Expression = else_node.body });
                            },
                            else => {
                                try stack.append(RenderState { .Indent = indent });
                                try stack.append(RenderState { .Expression = else_node.body });
                                try stack.append(RenderState.PrintIndent);
                                try stack.append(RenderState { .Indent = indent + indent_delta });
                                try stack.append(RenderState { .Text = "\n" });
                            }
                        }

                        if (else_node.payload) |payload| {
                            try stack.append(RenderState { .Text = " " });
                            try stack.append(RenderState { .Expression = &payload.base });
                        }
                    },
                    ast.Node.Id.While => {
                        const while_node = @fieldParentPtr(ast.NodeWhile, "base", base);
                        if (while_node.label) |label| {
                            try stream.print("{}: ", self.tokenizer.getTokenSlice(label));
                        }

                        if (while_node.inline_token) |inline_token| {
                            try stream.print("{} ", self.tokenizer.getTokenSlice(inline_token));
                        }

                        try stream.print("{} ", self.tokenizer.getTokenSlice(while_node.while_token));

                        if (while_node.@"else") |@"else"| {
                            try stack.append(RenderState { .Expression = &@"else".base });

                            if (while_node.body.id == ast.Node.Id.Block) {
                                try stack.append(RenderState { .Text = " " });
                            } else {
                                try stack.append(RenderState.PrintIndent);
                                try stack.append(RenderState { .Text = "\n" });
                            }
                        }

                        if (while_node.body.id == ast.Node.Id.Block) {
                            try stack.append(RenderState { .Expression = while_node.body });
                            try stack.append(RenderState { .Text = " " });
                        } else {
                            try stack.append(RenderState { .Indent = indent });
                            try stack.append(RenderState { .Expression = while_node.body });
                            try stack.append(RenderState.PrintIndent);
                            try stack.append(RenderState { .Indent = indent + indent_delta });
                            try stack.append(RenderState { .Text = "\n" });
                        }

                        if (while_node.continue_expr) |continue_expr| {
                            try stack.append(RenderState { .Text = ")" });
                            try stack.append(RenderState { .Expression = continue_expr });
                            try stack.append(RenderState { .Text = ": (" });
                            try stack.append(RenderState { .Text = " " });
                        }

                        if (while_node.payload) |payload| {
                            try stack.append(RenderState { .Expression = &payload.base });
                            try stack.append(RenderState { .Text = " " });
                        }

                        try stack.append(RenderState { .Text = ")" });
                        try stack.append(RenderState { .Expression = while_node.condition });
                        try stack.append(RenderState { .Text = "(" });
                    },
                    ast.Node.Id.For => {
                        const for_node = @fieldParentPtr(ast.NodeFor, "base", base);
                        if (for_node.label) |label| {
                            try stream.print("{}: ", self.tokenizer.getTokenSlice(label));
                        }

                        if (for_node.inline_token) |inline_token| {
                            try stream.print("{} ", self.tokenizer.getTokenSlice(inline_token));
                        }

                        try stream.print("{} ", self.tokenizer.getTokenSlice(for_node.for_token));

                        if (for_node.@"else") |@"else"| {
                            try stack.append(RenderState { .Expression = &@"else".base });

                            if (for_node.body.id == ast.Node.Id.Block) {
                                try stack.append(RenderState { .Text = " " });
                            } else {
                                try stack.append(RenderState.PrintIndent);
                                try stack.append(RenderState { .Text = "\n" });
                            }
                        }

                        if (for_node.body.id == ast.Node.Id.Block) {
                            try stack.append(RenderState { .Expression = for_node.body });
                            try stack.append(RenderState { .Text = " " });
                        } else {
                            try stack.append(RenderState { .Indent = indent });
                            try stack.append(RenderState { .Expression = for_node.body });
                            try stack.append(RenderState.PrintIndent);
                            try stack.append(RenderState { .Indent = indent + indent_delta });
                            try stack.append(RenderState { .Text = "\n" });
                        }

                        if (for_node.payload) |payload| {
                            try stack.append(RenderState { .Expression = &payload.base });
                            try stack.append(RenderState { .Text = " " });
                        }

                        try stack.append(RenderState { .Text = ")" });
                        try stack.append(RenderState { .Expression = for_node.array_expr });
                        try stack.append(RenderState { .Text = "(" });
                    },
                    ast.Node.Id.If => {
                        const if_node = @fieldParentPtr(ast.NodeIf, "base", base);
                        try stream.print("{} ", self.tokenizer.getTokenSlice(if_node.if_token));

                        switch (if_node.body.id) {
                            ast.Node.Id.Block, ast.Node.Id.If,
                            ast.Node.Id.For, ast.Node.Id.While,
                            ast.Node.Id.Switch => {
                                if (if_node.@"else") |@"else"| {
                                    try stack.append(RenderState { .Expression = &@"else".base });

                                    if (if_node.body.id == ast.Node.Id.Block) {
                                        try stack.append(RenderState { .Text = " " });
                                    } else {
                                        try stack.append(RenderState.PrintIndent);
                                        try stack.append(RenderState { .Text = "\n" });
                                    }
                                }
                            },
                            else => {
                                if (if_node.@"else") |@"else"| {
                                    try stack.append(RenderState { .Expression = @"else".body });

                                    if (@"else".payload) |payload| {
                                        try stack.append(RenderState { .Text = " " });
                                        try stack.append(RenderState { .Expression = &payload.base });
                                    }

                                    try stack.append(RenderState { .Text = " " });
                                    try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(@"else".else_token) });
                                    try stack.append(RenderState { .Text = " " });
                                }
                            }
                        }

                        try stack.append(RenderState { .Expression = if_node.body });
                        try stack.append(RenderState { .Text = " " });

                        if (if_node.payload) |payload| {
                            try stack.append(RenderState { .Expression = &payload.base });
                            try stack.append(RenderState { .Text = " " });
                        }

                        try stack.append(RenderState { .Text = ")" });
                        try stack.append(RenderState { .Expression = if_node.condition });
                        try stack.append(RenderState { .Text = "(" });
                    },
                    ast.Node.Id.Asm => {
                        const asm_node = @fieldParentPtr(ast.NodeAsm, "base", base);
                        try stream.print("{} ", self.tokenizer.getTokenSlice(asm_node.asm_token));

                        if (asm_node.is_volatile) {
                            try stream.write("volatile ");
                        }

                        try stack.append(RenderState { .Indent = indent });
                        try stack.append(RenderState { .Text = ")" });
                        {
                            const cloppers = asm_node.cloppers.toSliceConst();
                            var i = cloppers.len;
                            while (i != 0) {
                                i -= 1;
                                try stack.append(RenderState { .Expression = cloppers[i] });

                                if (i != 0) {
                                    try stack.append(RenderState { .Text = ", " });
                                }
                            }
                        }
                        try stack.append(RenderState { .Text = ": " });
                        try stack.append(RenderState.PrintIndent);
                        try stack.append(RenderState { .Indent = indent + indent_delta });
                        try stack.append(RenderState { .Text = "\n" });
                        {
                            const inputs = asm_node.inputs.toSliceConst();
                            var i = inputs.len;
                            while (i != 0) {
                                i -= 1;
                                const node = inputs[i];
                                try stack.append(RenderState { .Expression = &node.base});

                                if (i != 0) {
                                    try stack.append(RenderState.PrintIndent);
                                    try stack.append(RenderState {
                                        .Text = blk: {
                                            const prev_node = inputs[i - 1];
                                            const loc = self.tokenizer.getTokenLocation(prev_node.lastToken().end, node.firstToken());
                                            if (loc.line >= 2) {
                                                break :blk "\n\n";
                                            }
                                            break :blk "\n";
                                        },
                                    });
                                    try stack.append(RenderState { .Text = "," });
                                }
                            }
                        }
                        try stack.append(RenderState { .Indent = indent + indent_delta + 2});
                        try stack.append(RenderState { .Text = ": "});
                        try stack.append(RenderState.PrintIndent);
                        try stack.append(RenderState { .Indent = indent + indent_delta});
                        try stack.append(RenderState { .Text = "\n" });
                        {
                            const outputs = asm_node.outputs.toSliceConst();
                            var i = outputs.len;
                            while (i != 0) {
                                i -= 1;
                                const node = outputs[i];
                                try stack.append(RenderState { .Expression = &node.base});

                                if (i != 0) {
                                    try stack.append(RenderState.PrintIndent);
                                    try stack.append(RenderState {
                                        .Text = blk: {
                                            const prev_node = outputs[i - 1];
                                            const loc = self.tokenizer.getTokenLocation(prev_node.lastToken().end, node.firstToken());
                                            if (loc.line >= 2) {
                                                break :blk "\n\n";
                                            }
                                            break :blk "\n";
                                        },
                                    });
                                    try stack.append(RenderState { .Text = "," });
                                }
                            }
                        }
                        try stack.append(RenderState { .Indent = indent + indent_delta + 2});
                        try stack.append(RenderState { .Text = ": "});
                        try stack.append(RenderState.PrintIndent);
                        try stack.append(RenderState { .Indent = indent + indent_delta});
                        try stack.append(RenderState { .Text = "\n" });
                        try stack.append(RenderState { .Expression = asm_node.template });
                        try stack.append(RenderState { .Text = "(" });
                    },
                    ast.Node.Id.AsmInput => {
                        const asm_input = @fieldParentPtr(ast.NodeAsmInput, "base", base);

                        try stack.append(RenderState { .Text = ")"});
                        try stack.append(RenderState { .Expression = asm_input.expr});
                        try stack.append(RenderState { .Text = " ("});
                        try stack.append(RenderState { .Expression = asm_input.constraint });
                        try stack.append(RenderState { .Text = "] "});
                        try stack.append(RenderState { .Expression = &asm_input.symbolic_name.base});
                        try stack.append(RenderState { .Text = "["});
                    },
                    ast.Node.Id.AsmOutput => {
                        const asm_output = @fieldParentPtr(ast.NodeAsmOutput, "base", base);

                        try stack.append(RenderState { .Text = ")"});
                        switch (asm_output.kind) {
                            ast.NodeAsmOutput.Kind.Variable => |variable_name| {
                                try stack.append(RenderState { .Expression = &variable_name.base});
                            },
                            ast.NodeAsmOutput.Kind.Return => |return_type| {
                                try stack.append(RenderState { .Expression = return_type});
                                try stack.append(RenderState { .Text = "-> "});
                            },
                        }
                        try stack.append(RenderState { .Text = " ("});
                        try stack.append(RenderState { .Expression = asm_output.constraint });
                        try stack.append(RenderState { .Text = "] "});
                        try stack.append(RenderState { .Expression = &asm_output.symbolic_name.base});
                        try stack.append(RenderState { .Text = "["});
                    },

                    ast.Node.Id.StructField,
                    ast.Node.Id.UnionTag,
                    ast.Node.Id.EnumTag,
                    ast.Node.Id.Root,
                    ast.Node.Id.VarDecl,
                    ast.Node.Id.Use,
                    ast.Node.Id.TestDecl,
                    ast.Node.Id.ParamDecl => unreachable,
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
                            if (requireSemiColon(base)) {
                                try stack.append(RenderState { .Text = ";" });
                            }
                            try stack.append(RenderState { .Expression = base });
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
        \\fn bar() void {
        \\    return;
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

test "zig fmt: var type" {
    try testCanonical(
        \\fn print(args: var) var {}
        \\const Var = var;
        \\const i: var = 0;
        \\
    );
}

test "zig fmt: functions" {
    try testCanonical(
        \\extern fn puts(s: &const u8) c_int;
        \\extern "c" fn puts(s: &const u8) c_int;
        \\export fn puts(s: &const u8) c_int;
        \\inline fn puts(s: &const u8) c_int;
        \\pub extern fn puts(s: &const u8) c_int;
        \\pub extern "c" fn puts(s: &const u8) c_int;
        \\pub export fn puts(s: &const u8) c_int;
        \\pub inline fn puts(s: &const u8) c_int;
        \\pub extern fn puts(s: &const u8) align(2 + 2) c_int;
        \\pub extern "c" fn puts(s: &const u8) align(2 + 2) c_int;
        \\pub export fn puts(s: &const u8) align(2 + 2) c_int;
        \\pub inline fn puts(s: &const u8) align(2 + 2) c_int;
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
        \\    pub f3: u8,
        \\
        \\    fn method(self: &Self) Self {
        \\        return *self;
        \\    }
        \\
        \\    f2: u8
        \\};
        \\
        \\const Ps = packed struct {
        \\    a: u8,
        \\    pub b: u8,
        \\
        \\    c: u8
        \\};
        \\
        \\const Es = extern struct {
        \\    a: u8,
        \\    pub b: u8,
        \\
        \\    c: u8
        \\};
        \\
    );
}

test "zig fmt: enum declaration" {
      try testCanonical(
        \\const E = enum {
        \\    Ok,
        \\    SomethingElse = 0
        \\};
        \\
        \\const E2 = enum(u8) {
        \\    Ok,
        \\    SomethingElse = 255,
        \\    SomethingThird
        \\};
        \\
        \\const Ee = extern enum {
        \\    Ok,
        \\    SomethingElse,
        \\    SomethingThird
        \\};
        \\
        \\const Ep = packed enum {
        \\    Ok,
        \\    SomethingElse,
        \\    SomethingThird
        \\};
        \\
    );
}

test "zig fmt: union declaration" {
      try testCanonical(
        \\const U = union {
        \\    Int: u8,
        \\    Float: f32,
        \\    None,
        \\    Bool: bool
        \\};
        \\
        \\const Ue = union(enum) {
        \\    Int: u8,
        \\    Float: f32,
        \\    None,
        \\    Bool: bool
        \\};
        \\
        \\const E = enum {
        \\    Int,
        \\    Float,
        \\    None,
        \\    Bool
        \\};
        \\
        \\const Ue2 = union(E) {
        \\    Int: u8,
        \\    Float: f32,
        \\    None,
        \\    Bool: bool
        \\};
        \\
        \\const Eu = extern union {
        \\    Int: u8,
        \\    Float: f32,
        \\    None,
        \\    Bool: bool
        \\};
        \\
    );
}

test "zig fmt: error set declaration" {
      try testCanonical(
        \\const E = error {
        \\    A,
        \\    B,
        \\
        \\    C
        \\};
        \\
    );
}

test "zig fmt: arrays" {
    try testCanonical(
        \\test "test array" {
        \\    const a: [2]u8 = [2]u8 {
        \\        1,
        \\        2,
        \\    };
        \\    const a: [2]u8 = []u8 {
        \\        1,
        \\        2,
        \\    };
        \\    const a: [0]u8 = []u8{};
        \\}
        \\
    );
}

test "zig fmt: container initializers" {
    try testCanonical(
        \\const a1 = []u8{};
        \\const a2 = []u8 {
        \\    1,
        \\    2,
        \\    3,
        \\    4,
        \\};
        \\const s1 = S{};
        \\const s2 = S {
        \\    .a = 1,
        \\    .b = 2,
        \\};
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

test "zig fmt: blocks" {
    try testCanonical(
        \\test "blocks" {
        \\    {
        \\        const a = 0;
        \\        const b = 0;
        \\    }
        \\
        \\    blk: {
        \\        const a = 0;
        \\        const b = 0;
        \\    }
        \\
        \\    const r = blk: {
        \\        const a = 0;
        \\        const b = 0;
        \\    };
        \\}
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
        \\        }
        \\    }
        \\
        \\    const res = switch (0) {
        \\        0 => 0,
        \\        1 => 2,
        \\        1 => a = 4,
        \\        else => 4
        \\    };
        \\
        \\    const Union = union(enum) {
        \\        Int: i64,
        \\        Float: f64
        \\    };
        \\
        \\    const u = Union {
        \\        .Int = 0,
        \\    };
        \\    switch (u) {
        \\        Union.Int => |int| {},
        \\        Union.Float => |*float| unreachable
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
        \\    var j: usize = 0;
        \\    while (i < 10) : ({
        \\        i += 1;
        \\        j += 1;
        \\    }) {
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
        \\    };
        \\
        \\    const res = while (0 < 10)
        \\        break 7
        \\    else
        \\        unreachable;
        \\
        \\    var a: error!u8 = 0;
        \\    while (a) |v| {
        \\        a = error.Err;
        \\    } else |err| {
        \\        i = 1;
        \\    }
        \\
        \\    comptime var k: usize = 0;
        \\    inline while (i < 10) : (i += 1)
        \\        j += 2;
        \\}
        \\
    );
}

test "zig fmt: for" {
    try testCanonical(
        \\test "for" {
        \\    const a = []u8 {
        \\        1,
        \\        2,
        \\        3,
        \\    };
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
        \\        break v;
        \\    } else {
        \\        unreachable;
        \\    };
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
        \\    if (10 < 0) unreachable;
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
        \\    const some_number = 1 + if (10 < 0) 2 else 3;
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
        \\const a: fn(u8) u8 = undefined;
        \\const b: extern fn(u8) u8 = undefined;
        \\const c: nakedcc fn(u8) u8 = undefined;
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
        \\          [arg1] "{rdi}" (arg1)
        \\        : "rcx", "r11");
        \\}
        \\
    );
}

test "zig fmt: coroutines" {
    try testCanonical(
        \\async fn simpleAsyncFn() void {
        \\    const a = async a.b();
        \\    x += 1;
        \\    suspend;
        \\    x += 1;
        \\    suspend |p| {}
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

test "zig fmt: Block after if" {
    try testCanonical(
        \\test "Block after if" {
        \\    if (true) {
        \\        const a = 0;
        \\    }
        \\
        \\    {
        \\        const a = 0;
        \\    }
        \\}
        \\
    );
}

test "zig fmt: use" {
    try testCanonical(
        \\use @import("std");
        \\pub use @import("std");
        \\
    );
}

test "zig fmt: string identifier" {
    try testCanonical(
        \\const @"a b" = @"c d".@"e f";
        \\fn @"g h"() void {}
        \\
    );
}

test "zig fmt: error return" {
    try testCanonical(
        \\fn err() error {
        \\    call();
        \\    return error.InvalidArgs;
        \\}
        \\
    );
}

test "zig fmt: struct literals with fields on each line" {
    try testCanonical(
        \\var self = BufSet {
        \\    .hash_map = BufSetHashMap.init(a),
        \\};
        \\
    );
}
