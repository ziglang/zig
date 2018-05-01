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

    pub const Tree = struct {
        root_node: &ast.Node.Root,
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
        comments: ?&ast.Node.DocComment,
    };

    const VarDeclCtx = struct {
        mut_token: Token,
        visib_token: ?Token,
        comptime_token: ?Token,
        extern_export_token: ?Token,
        lib_name: ?&ast.Node,
        list: &ArrayList(&ast.Node),
        comments: ?&ast.Node.DocComment,
    };

    const TopLevelExternOrFieldCtx = struct {
        visib_token: Token,
        container_decl: &ast.Node.ContainerDecl,
        comments: ?&ast.Node.DocComment,
    };

    const ExternTypeCtx = struct {
        opt_ctx: OptionalCtx,
        extern_token: Token,
        comments: ?&ast.Node.DocComment,
    };

    const ContainerKindCtx = struct {
        opt_ctx: OptionalCtx,
        ltoken: Token,
        layout: ast.Node.ContainerDecl.Layout,
    };

    const ExpectTokenSave = struct {
        id: Token.Id,
        ptr: &Token,
    };

    const OptionalTokenSave = struct {
        id: Token.Id,
        ptr: &?Token,
    };

    const ExprListCtx = struct {
        list: &ArrayList(&ast.Node),
        end: Token.Id,
        ptr: &Token,
    };

    fn ListSave(comptime T: type) type {
        return struct {
            list: &ArrayList(T),
            ptr: &Token,
        };
    }

    const MaybeLabeledExpressionCtx = struct {
        label: Token,
        opt_ctx: OptionalCtx,
    };

    const LabelCtx = struct {
        label: ?Token,
        opt_ctx: OptionalCtx,
    };

    const InlineCtx = struct {
        label: ?Token,
        inline_token: ?Token,
        opt_ctx: OptionalCtx,
    };

    const LoopCtx = struct {
        label: ?Token,
        inline_token: ?Token,
        loop_token: Token,
        opt_ctx: OptionalCtx,
    };

    const AsyncEndCtx = struct {
        ctx: OptionalCtx,
        attribute: &ast.Node.AsyncAttribute,
    };

    const ErrorTypeOrSetDeclCtx = struct {
        opt_ctx: OptionalCtx,
        error_token: Token,
    };

    const ParamDeclEndCtx = struct {
        fn_proto: &ast.Node.FnProto,
        param_decl: &ast.Node.ParamDecl,
    };

    const ComptimeStatementCtx = struct {
        comptime_token: Token,
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
        AddComments: AddCommentsCtx,
        LookForSameLineComment: &&ast.Node,
        LookForSameLineCommentDirect: &ast.Node,

        AsmOutputItems: &ArrayList(&ast.Node.AsmOutput),
        AsmOutputReturnOrType: &ast.Node.AsmOutput,
        AsmInputItems: &ArrayList(&ast.Node.AsmInput),
        AsmClopperItems: &ArrayList(&ast.Node),

        ExprListItemOrEnd: ExprListCtx,
        ExprListCommaOrEnd: ExprListCtx,
        FieldInitListItemOrEnd: ListSave(&ast.Node.FieldInitializer),
        FieldInitListCommaOrEnd: ListSave(&ast.Node.FieldInitializer),
        FieldListCommaOrEnd: &ast.Node.ContainerDecl,
        IdentifierListItemOrEnd: ListSave(&ast.Node),
        IdentifierListCommaOrEnd: ListSave(&ast.Node),
        SwitchCaseOrEnd: ListSave(&ast.Node),
        SwitchCaseCommaOrEnd: ListSave(&ast.Node),
        SwitchCaseFirstItem: &ArrayList(&ast.Node),
        SwitchCaseItem: &ArrayList(&ast.Node),
        SwitchCaseItemCommaOrEnd: &ArrayList(&ast.Node),

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


        IfToken: @TagType(Token.Id),
        IfTokenSave: ExpectTokenSave,
        ExpectToken: @TagType(Token.Id),
        ExpectTokenSave: ExpectTokenSave,
        OptionalTokenSave: OptionalTokenSave,
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
        const root_node = try self.createNode(arena, ast.Node.Root,
            ast.Node.Root {
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

            // This gives us 1 free append that can't fail
            const state = stack.pop();

            switch (state) {
                State.TopLevel => {
                    while (try self.eatLineComment(arena)) |line_comment| {
                        try root_node.decls.append(&line_comment.base);
                    }

                    const comments = try self.eatComments(arena);
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_test => {
                            stack.append(State.TopLevel) catch unreachable;

                            const block = try arena.construct(ast.Node.Block {
                                .base = ast.Node {
                                    .id = ast.Node.Id.Block,
                                    .doc_comments = null,
                                    .same_line_comment = null,
                                },
                                .label = null,
                                .lbrace = undefined,
                                .statements = ArrayList(&ast.Node).init(arena),
                                .rbrace = undefined,
                            });
                            const test_node = try arena.construct(ast.Node.TestDecl {
                                .base = ast.Node {
                                    .id = ast.Node.Id.TestDecl,
                                    .doc_comments = comments,
                                    .same_line_comment = null,
                                },
                                .test_token = token,
                                .name = undefined,
                                .body_node = &block.base,
                            });
                            try root_node.decls.append(&test_node.base);
                            try stack.append(State { .Block = block });
                            try stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.LBrace,
                                    .ptr = &block.rbrace,
                                }
                            });
                            try stack.append(State { .StringLiteral = OptionalCtx { .Required = &test_node.name } });
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
                                    .comments = comments,
                                }
                            });
                            continue;
                        },
                        Token.Id.Keyword_comptime => {
                            const block = try self.createNode(arena, ast.Node.Block,
                                ast.Node.Block {
                                    .base = undefined,
                                    .label = null,
                                    .lbrace = undefined,
                                    .statements = ArrayList(&ast.Node).init(arena),
                                    .rbrace = undefined,
                                }
                            );
                            const node = try self.createAttachNode(arena, &root_node.decls, ast.Node.Comptime,
                                ast.Node.Comptime {
                                    .base = undefined,
                                    .comptime_token = token,
                                    .expr = &block.base,
                                }
                            );
                            stack.append(State.TopLevel) catch unreachable;
                            try stack.append(State { .Block = block });
                            try stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.LBrace,
                                    .ptr = &block.rbrace,
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
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_export, Token.Id.Keyword_inline => {
                            stack.append(State {
                                .TopLevelDecl = TopLevelDeclCtx {
                                    .decls = ctx.decls,
                                    .visib_token = ctx.visib_token,
                                    .extern_export_inline_token = token,
                                    .lib_name = null,
                                    .comments = ctx.comments,
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
                                    .comments = ctx.comments,
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
                            .comments = ctx.comments,
                        },
                    }) catch unreachable;
                    continue;
                },
                State.TopLevelDecl => |ctx| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_use => {
                            if (ctx.extern_export_inline_token != null) {
                                return self.parseError(token, "Invalid token {}", @tagName((??ctx.extern_export_inline_token).id));
                            }

                            const node = try self.createAttachNode(arena, ctx.decls, ast.Node.Use,
                                ast.Node.Use {
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
                            try stack.append(State { .Expression = OptionalCtx { .Required = &node.expr } });
                            continue;
                        },
                        Token.Id.Keyword_var, Token.Id.Keyword_const => {
                            if (ctx.extern_export_inline_token) |extern_export_inline_token| {
                                if (extern_export_inline_token.id == Token.Id.Keyword_inline) {
                                    return self.parseError(token, "Invalid token {}", @tagName(extern_export_inline_token.id));
                                }
                            }

                            try stack.append(State {
                                .VarDecl = VarDeclCtx {
                                    .comments = ctx.comments,
                                    .visib_token = ctx.visib_token,
                                    .lib_name = ctx.lib_name,
                                    .comptime_token = null,
                                    .extern_export_token = ctx.extern_export_inline_token,
                                    .mut_token = token,
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
                                    .doc_comments = ctx.comments,
                                    .same_line_comment = null,
                                },
                                .visib_token = ctx.visib_token,
                                .name_token = null,
                                .fn_token = undefined,
                                .params = ArrayList(&ast.Node).init(arena),
                                .return_type = undefined,
                                .var_args_token = null,
                                .extern_export_inline_token = ctx.extern_export_inline_token,
                                .cc_token = null,
                                .async_attr = null,
                                .body_node = null,
                                .lib_name = ctx.lib_name,
                                .align_expr = null,
                            });
                            try ctx.decls.append(&fn_proto.base);
                            stack.append(State { .FnDef = fn_proto }) catch unreachable;
                            try stack.append(State { .FnProto = fn_proto });

                            switch (token.id) {
                                Token.Id.Keyword_nakedcc, Token.Id.Keyword_stdcallcc => {
                                    fn_proto.cc_token = token;
                                    try stack.append(State {
                                        .ExpectTokenSave = ExpectTokenSave {
                                            .id = Token.Id.Keyword_fn,
                                            .ptr = &fn_proto.fn_token,
                                        }
                                    });
                                    continue;
                                },
                                Token.Id.Keyword_async => {
                                    const async_node = try self.createNode(arena, ast.Node.AsyncAttribute,
                                        ast.Node.AsyncAttribute {
                                            .base = undefined,
                                            .async_token = token,
                                            .allocator_type = null,
                                            .rangle_bracket = null,
                                        }
                                    );
                                    fn_proto.async_attr = async_node;

                                    try stack.append(State {
                                        .ExpectTokenSave = ExpectTokenSave {
                                            .id = Token.Id.Keyword_fn,
                                            .ptr = &fn_proto.fn_token,
                                        }
                                    });
                                    try stack.append(State { .AsyncAllocator = async_node });
                                    continue;
                                },
                                Token.Id.Keyword_fn => {
                                    fn_proto.fn_token = token;
                                    continue;
                                },
                                else => unreachable,
                            }
                        },
                        else => {
                            return self.parseError(token, "expected variable declaration or function, found {}", @tagName(token.id));
                        },
                    }
                },
                State.TopLevelExternOrField => |ctx| {
                    if (self.eatToken(Token.Id.Identifier)) |identifier| {
                        std.debug.assert(ctx.container_decl.kind == ast.Node.ContainerDecl.Kind.Struct);
                        const node = try arena.construct(ast.Node.StructField {
                            .base = ast.Node {
                                .id = ast.Node.Id.StructField,
                                .doc_comments = null,
                                .same_line_comment = null,
                            },
                            .visib_token = ctx.visib_token,
                            .name_token = identifier,
                            .type_expr = undefined,
                        });
                        const node_ptr = try ctx.container_decl.fields_and_decls.addOne();
                        *node_ptr = &node.base;

                        stack.append(State { .FieldListCommaOrEnd = ctx.container_decl }) catch unreachable;
                        try stack.append(State { .Expression = OptionalCtx { .Required = &node.type_expr } });
                        try stack.append(State { .ExpectToken = Token.Id.Colon });
                        continue;
                    }

                    stack.append(State{ .ContainerDecl = ctx.container_decl }) catch unreachable;
                    try stack.append(State {
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


                State.ContainerKind => |ctx| {
                    const token = self.getNextToken();
                    const node = try self.createToCtxNode(arena, ctx.opt_ctx, ast.Node.ContainerDecl,
                        ast.Node.ContainerDecl {
                            .base = undefined,
                            .ltoken = ctx.ltoken,
                            .layout = ctx.layout,
                            .kind = switch (token.id) {
                                Token.Id.Keyword_struct => ast.Node.ContainerDecl.Kind.Struct,
                                Token.Id.Keyword_union => ast.Node.ContainerDecl.Kind.Union,
                                Token.Id.Keyword_enum => ast.Node.ContainerDecl.Kind.Enum,
                                else => {
                                    return self.parseError(token, "expected {}, {} or {}, found {}",
                                        @tagName(Token.Id.Keyword_struct),
                                        @tagName(Token.Id.Keyword_union),
                                        @tagName(Token.Id.Keyword_enum),
                                        @tagName(token.id));
                                },
                            },
                            .init_arg_expr = ast.Node.ContainerDecl.InitArg.None,
                            .fields_and_decls = ArrayList(&ast.Node).init(arena),
                            .rbrace_token = undefined,
                        }
                    );

                    stack.append(State { .ContainerDecl = node }) catch unreachable;
                    try stack.append(State { .ExpectToken = Token.Id.LBrace });
                    try stack.append(State { .ContainerInitArgStart = node });
                    continue;
                },

                State.ContainerInitArgStart => |container_decl| {
                    if (self.eatToken(Token.Id.LParen) == null) {
                        continue;
                    }

                    stack.append(State { .ExpectToken = Token.Id.RParen }) catch unreachable;
                    try stack.append(State { .ContainerInitArg = container_decl });
                    continue;
                },

                State.ContainerInitArg => |container_decl| {
                    const init_arg_token = self.getNextToken();
                    switch (init_arg_token.id) {
                        Token.Id.Keyword_enum => {
                            container_decl.init_arg_expr = ast.Node.ContainerDecl.InitArg.Enum;
                        },
                        else => {
                            self.putBackToken(init_arg_token);
                            container_decl.init_arg_expr = ast.Node.ContainerDecl.InitArg { .Type = undefined };
                            stack.append(State { .Expression = OptionalCtx { .Required = &container_decl.init_arg_expr.Type } }) catch unreachable;
                        },
                    }
                    continue;
                },
                State.ContainerDecl => |container_decl| {
                    while (try self.eatLineComment(arena)) |line_comment| {
                        try container_decl.fields_and_decls.append(&line_comment.base);
                    }

                    const comments = try self.eatComments(arena);
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Identifier => {
                            switch (container_decl.kind) {
                                ast.Node.ContainerDecl.Kind.Struct => {
                                    const node = try arena.construct(ast.Node.StructField {
                                        .base = ast.Node {
                                            .id = ast.Node.Id.StructField,
                                            .doc_comments = comments,
                                            .same_line_comment = null,
                                        },
                                        .visib_token = null,
                                        .name_token = token,
                                        .type_expr = undefined,
                                    });
                                    const node_ptr = try container_decl.fields_and_decls.addOne();
                                    *node_ptr = &node.base;

                                    try stack.append(State { .FieldListCommaOrEnd = container_decl });
                                    try stack.append(State { .TypeExprBegin = OptionalCtx { .Required = &node.type_expr } });
                                    try stack.append(State { .ExpectToken = Token.Id.Colon });
                                    continue;
                                },
                                ast.Node.ContainerDecl.Kind.Union => {
                                    const node = try self.createAttachNode(arena, &container_decl.fields_and_decls, ast.Node.UnionTag,
                                        ast.Node.UnionTag {
                                            .base = undefined,
                                            .name_token = token,
                                            .type_expr = null,
                                        }
                                    );

                                    stack.append(State { .FieldListCommaOrEnd = container_decl }) catch unreachable;
                                    try stack.append(State { .TypeExprBegin = OptionalCtx { .RequiredNull = &node.type_expr } });
                                    try stack.append(State { .IfToken = Token.Id.Colon });
                                    continue;
                                },
                                ast.Node.ContainerDecl.Kind.Enum => {
                                    const node = try self.createAttachNode(arena, &container_decl.fields_and_decls, ast.Node.EnumTag,
                                        ast.Node.EnumTag {
                                            .base = undefined,
                                            .name_token = token,
                                            .value = null,
                                        }
                                    );

                                    stack.append(State { .FieldListCommaOrEnd = container_decl }) catch unreachable;
                                    try stack.append(State { .Expression = OptionalCtx { .RequiredNull = &node.value } });
                                    try stack.append(State { .IfToken = Token.Id.Equal });
                                    continue;
                                },
                            }
                        },
                        Token.Id.Keyword_pub => {
                            switch (container_decl.kind) {
                                ast.Node.ContainerDecl.Kind.Struct => {
                                    try stack.append(State {
                                        .TopLevelExternOrField = TopLevelExternOrFieldCtx {
                                            .visib_token = token,
                                            .container_decl = container_decl,
                                            .comments = comments,
                                        }
                                    });
                                    continue;
                                },
                                else => {
                                    stack.append(State{ .ContainerDecl = container_decl }) catch unreachable;
                                    try stack.append(State {
                                        .TopLevelExtern = TopLevelDeclCtx {
                                            .decls = &container_decl.fields_and_decls,
                                            .visib_token = token,
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
                            stack.append(State{ .ContainerDecl = container_decl }) catch unreachable;
                            try stack.append(State {
                                .TopLevelExtern = TopLevelDeclCtx {
                                    .decls = &container_decl.fields_and_decls,
                                    .visib_token = token,
                                    .extern_export_inline_token = null,
                                    .lib_name = null,
                                    .comments = comments,
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
                            .doc_comments = ctx.comments,
                            .same_line_comment = null,
                        },
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
                    try ctx.list.append(&var_decl.base);

                    try stack.append(State { .LookForSameLineCommentDirect = &var_decl.base });
                    try stack.append(State { .VarDeclAlign = var_decl });
                    try stack.append(State { .TypeExprBegin = OptionalCtx { .RequiredNull = &var_decl.type_node} });
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
                    try stack.append(State { .VarDeclEq = var_decl });

                    const next_token = self.getNextToken();
                    if (next_token.id == Token.Id.Keyword_align) {
                        try stack.append(State { .ExpectToken = Token.Id.RParen });
                        try stack.append(State { .Expression = OptionalCtx { .RequiredNull = &var_decl.align_node} });
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
                            try stack.append(State { .Expression = OptionalCtx { .RequiredNull = &var_decl.init_node } });
                            continue;
                        },
                        Token.Id.Semicolon => {
                            var_decl.semicolon_token = token;
                            continue;
                        },
                        else => {
                            return self.parseError(token, "expected '=' or ';', found {}", @tagName(token.id));
                        }
                    }
                },


                State.FnDef => |fn_proto| {
                    const token = self.getNextToken();
                    switch(token.id) {
                        Token.Id.LBrace => {
                            const block = try self.createNode(arena, ast.Node.Block,
                                ast.Node.Block {
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
                            return self.parseError(token, "expected ';' or '{{', found {}", @tagName(token.id));
                        },
                    }
                },
                State.FnProto => |fn_proto| {
                    stack.append(State { .FnProtoAlign = fn_proto }) catch unreachable;
                    try stack.append(State { .ParamDecl = fn_proto });
                    try stack.append(State { .ExpectToken = Token.Id.LParen });

                    if (self.eatToken(Token.Id.Identifier)) |name_token| {
                        fn_proto.name_token = name_token;
                    }
                    continue;
                },
                State.FnProtoAlign => |fn_proto| {
                    stack.append(State { .FnProtoReturnType = fn_proto }) catch unreachable;

                    if (self.eatToken(Token.Id.Keyword_align)) |align_token| {
                        try stack.append(State { .ExpectToken = Token.Id.RParen });
                        try stack.append(State { .Expression = OptionalCtx { .RequiredNull = &fn_proto.align_expr } });
                        try stack.append(State { .ExpectToken = Token.Id.LParen });
                    }
                    continue;
                },
                State.FnProtoReturnType => |fn_proto| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Bang => {
                            fn_proto.return_type = ast.Node.FnProto.ReturnType { .InferErrorSet = undefined };
                            stack.append(State {
                                .TypeExprBegin = OptionalCtx { .Required = &fn_proto.return_type.InferErrorSet },
                            }) catch unreachable;
                            continue;
                        },
                        else => {
                            // TODO: this is a special case. Remove this when #760 is fixed
                            if (token.id == Token.Id.Keyword_error) {
                                if (self.isPeekToken(Token.Id.LBrace)) {
                                    fn_proto.return_type = ast.Node.FnProto.ReturnType {
                                        .Explicit = &(try self.createLiteral(arena, ast.Node.ErrorType, token)).base
                                    };
                                    continue;
                                }
                            }

                            self.putBackToken(token);
                            fn_proto.return_type = ast.Node.FnProto.ReturnType { .Explicit = undefined };
                            stack.append(State { .TypeExprBegin = OptionalCtx { .Required = &fn_proto.return_type.Explicit }, }) catch unreachable;
                            continue;
                        },
                    }
                },


                State.ParamDecl => |fn_proto| {
                    if (self.eatToken(Token.Id.RParen)) |_| {
                        continue;
                    }
                    const param_decl = try self.createAttachNode(arena, &fn_proto.params, ast.Node.ParamDecl,
                        ast.Node.ParamDecl {
                            .base = undefined,
                            .comptime_token = null,
                            .noalias_token = null,
                            .name_token = null,
                            .type_node = undefined,
                            .var_args_token = null,
                        },
                    );

                    stack.append(State {
                        .ParamDeclEnd = ParamDeclEndCtx {
                            .param_decl = param_decl,
                            .fn_proto = fn_proto,
                        }
                    }) catch unreachable;
                    try stack.append(State { .ParamDeclName = param_decl });
                    try stack.append(State { .ParamDeclAliasOrComptime = param_decl });
                    continue;
                },
                State.ParamDeclAliasOrComptime => |param_decl| {
                    if (self.eatToken(Token.Id.Keyword_comptime)) |comptime_token| {
                        param_decl.comptime_token = comptime_token;
                    } else if (self.eatToken(Token.Id.Keyword_noalias)) |noalias_token| {
                        param_decl.noalias_token = noalias_token;
                    }
                    continue;
                },
                State.ParamDeclName => |param_decl| {
                    // TODO: Here, we eat two tokens in one state. This means that we can't have
                    //       comments between these two tokens.
                    if (self.eatToken(Token.Id.Identifier)) |ident_token| {
                        if (self.eatToken(Token.Id.Colon)) |_| {
                            param_decl.name_token = ident_token;
                        } else {
                            self.putBackToken(ident_token);
                        }
                    }
                    continue;
                },
                State.ParamDeclEnd => |ctx| {
                    if (self.eatToken(Token.Id.Ellipsis3)) |ellipsis3| {
                        ctx.param_decl.var_args_token = ellipsis3;
                        stack.append(State { .ExpectToken = Token.Id.RParen }) catch unreachable;
                        continue;
                    }

                    try stack.append(State { .ParamDeclComma = ctx.fn_proto });
                    try stack.append(State {
                        .TypeExprBegin = OptionalCtx { .Required = &ctx.param_decl.type_node }
                    });
                    continue;
                },
                State.ParamDeclComma => |fn_proto| {
                    if ((try self.expectCommaOrEnd(Token.Id.RParen)) == null) {
                        stack.append(State { .ParamDecl = fn_proto }) catch unreachable;
                    }
                    continue;
                },

                State.MaybeLabeledExpression => |ctx| {
                    if (self.eatToken(Token.Id.Colon)) |_| {
                        stack.append(State {
                            .LabeledExpression = LabelCtx {
                                .label = ctx.label,
                                .opt_ctx = ctx.opt_ctx,
                            }
                        }) catch unreachable;
                        continue;
                    }

                    _ = try self.createToCtxLiteral(arena, ctx.opt_ctx, ast.Node.Identifier, ctx.label);
                    continue;
                },
                State.LabeledExpression => |ctx| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.LBrace => {
                            const block = try self.createToCtxNode(arena, ctx.opt_ctx, ast.Node.Block,
                                ast.Node.Block {
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
                                    .opt_ctx = ctx.opt_ctx.toRequired(),
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
                                    .opt_ctx = ctx.opt_ctx.toRequired(),
                                }
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_inline => {
                            stack.append(State {
                                .Inline = InlineCtx {
                                    .label = ctx.label,
                                    .inline_token = token,
                                    .opt_ctx = ctx.opt_ctx.toRequired(),
                                }
                            }) catch unreachable;
                            continue;
                        },
                        else => {
                            if (ctx.opt_ctx != OptionalCtx.Optional) {
                                return self.parseError(token, "expected 'while', 'for', 'inline' or '{{', found {}", @tagName(token.id));
                            }

                            self.putBackToken(token);
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
                                    .opt_ctx = ctx.opt_ctx.toRequired(),
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
                                    .opt_ctx = ctx.opt_ctx.toRequired(),
                                }
                            }) catch unreachable;
                            continue;
                        },
                        else => {
                            if (ctx.opt_ctx != OptionalCtx.Optional) {
                                return self.parseError(token, "expected 'while' or 'for', found {}", @tagName(token.id));
                            }

                            self.putBackToken(token);
                            continue;
                        },
                    }
                },
                State.While => |ctx| {
                    const node = try self.createToCtxNode(arena, ctx.opt_ctx, ast.Node.While,
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
                    stack.append(State { .Else = &node.@"else" }) catch unreachable;
                    try stack.append(State { .Expression = OptionalCtx { .Required = &node.body } });
                    try stack.append(State { .WhileContinueExpr = &node.continue_expr });
                    try stack.append(State { .IfToken = Token.Id.Colon });
                    try stack.append(State { .PointerPayload = OptionalCtx { .Optional = &node.payload } });
                    try stack.append(State { .ExpectToken = Token.Id.RParen });
                    try stack.append(State { .Expression = OptionalCtx { .Required = &node.condition } });
                    try stack.append(State { .ExpectToken = Token.Id.LParen });
                    continue;
                },
                State.WhileContinueExpr => |dest| {
                    stack.append(State { .ExpectToken = Token.Id.RParen }) catch unreachable;
                    try stack.append(State { .AssignmentExpressionBegin = OptionalCtx { .RequiredNull = dest } });
                    try stack.append(State { .ExpectToken = Token.Id.LParen });
                    continue;
                },
                State.For => |ctx| {
                    const node = try self.createToCtxNode(arena, ctx.opt_ctx, ast.Node.For,
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
                    stack.append(State { .Else = &node.@"else" }) catch unreachable;
                    try stack.append(State { .Expression = OptionalCtx { .Required = &node.body } });
                    try stack.append(State { .PointerIndexPayload = OptionalCtx { .Optional = &node.payload } });
                    try stack.append(State { .ExpectToken = Token.Id.RParen });
                    try stack.append(State { .Expression = OptionalCtx { .Required = &node.array_expr } });
                    try stack.append(State { .ExpectToken = Token.Id.LParen });
                    continue;
                },
                State.Else => |dest| {
                    if (self.eatToken(Token.Id.Keyword_else)) |else_token| {
                        const node = try self.createNode(arena, ast.Node.Else,
                            ast.Node.Else {
                                .base = undefined,
                                .else_token = else_token,
                                .payload = null,
                                .body = undefined,
                            }
                        );
                        *dest = node;

                        stack.append(State { .Expression = OptionalCtx { .Required = &node.body } }) catch unreachable;
                        try stack.append(State { .Payload = OptionalCtx { .Optional = &node.payload } });
                        continue;
                    } else {
                        continue;
                    }
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

                            var any_comments = false;
                            while (try self.eatLineComment(arena)) |line_comment| {
                                try block.statements.append(&line_comment.base);
                                any_comments = true;
                            }
                            if (any_comments) continue;

                            try stack.append(State { .Statement = block });
                            continue;
                        },
                    }
                },
                State.Statement => |block| {
                    const comments = try self.eatComments(arena);
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_comptime => {
                            stack.append(State {
                                .ComptimeStatement = ComptimeStatementCtx {
                                    .comptime_token = token,
                                    .block = block,
                                }
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_var, Token.Id.Keyword_const => {
                            stack.append(State {
                                .VarDecl = VarDeclCtx {
                                    .comments = comments,
                                    .visib_token = null,
                                    .comptime_token = null,
                                    .extern_export_token = null,
                                    .lib_name = null,
                                    .mut_token = token,
                                    .list = &block.statements,
                                }
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_defer, Token.Id.Keyword_errdefer => {
                            const node = try arena.construct(ast.Node.Defer {
                                .base = ast.Node {
                                    .id = ast.Node.Id.Defer,
                                    .doc_comments = comments,
                                    .same_line_comment = null,
                                },
                                .defer_token = token,
                                .kind = switch (token.id) {
                                    Token.Id.Keyword_defer => ast.Node.Defer.Kind.Unconditional,
                                    Token.Id.Keyword_errdefer => ast.Node.Defer.Kind.Error,
                                    else => unreachable,
                                },
                                .expr = undefined,
                            });
                            const node_ptr = try block.statements.addOne();
                            *node_ptr = &node.base;

                            stack.append(State { .Semicolon = node_ptr }) catch unreachable;
                            try stack.append(State { .AssignmentExpressionBegin = OptionalCtx{ .Required = &node.expr } });
                            continue;
                        },
                        Token.Id.LBrace => {
                            const inner_block = try self.createAttachNode(arena, &block.statements, ast.Node.Block,
                                ast.Node.Block {
                                    .base = undefined,
                                    .label = null,
                                    .lbrace = token,
                                    .statements = ArrayList(&ast.Node).init(arena),
                                    .rbrace = undefined,
                                }
                            );
                            stack.append(State { .Block = inner_block }) catch unreachable;
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            const statement = try block.statements.addOne();
                            stack.append(State { .LookForSameLineComment = statement }) catch unreachable;
                            try stack.append(State { .Semicolon = statement });
                            try stack.append(State { .AddComments = AddCommentsCtx {
                                .node_ptr = statement,
                                .comments = comments,
                            }});
                            try stack.append(State { .AssignmentExpressionBegin = OptionalCtx{ .Required = statement } });
                            continue;
                        }
                    }
                },
                State.ComptimeStatement => |ctx| {
                    const comments = try self.eatComments(arena);
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_var, Token.Id.Keyword_const => {
                            stack.append(State {
                                .VarDecl = VarDeclCtx {
                                    .comments = comments,
                                    .visib_token = null,
                                    .comptime_token = ctx.comptime_token,
                                    .extern_export_token = null,
                                    .lib_name = null,
                                    .mut_token = token,
                                    .list = &ctx.block.statements,
                                }
                            }) catch unreachable;
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            self.putBackToken(ctx.comptime_token);
                            const statememt = try ctx.block.statements.addOne();
                            stack.append(State { .Semicolon = statememt }) catch unreachable;
                            try stack.append(State { .Expression = OptionalCtx { .Required = statememt } });
                            continue;
                        }
                    }
                },
                State.Semicolon => |node_ptr| {
                    const node = *node_ptr;
                    if (requireSemiColon(node)) {
                        stack.append(State { .ExpectToken = Token.Id.Semicolon }) catch unreachable;
                        continue;
                    }
                    continue;
                },

                State.AddComments => |add_comments_ctx| {
                    const node = *add_comments_ctx.node_ptr;
                    node.doc_comments = add_comments_ctx.comments;
                    continue;
                },

                State.LookForSameLineComment => |node_ptr| {
                    try self.lookForSameLineComment(arena, *node_ptr);
                    continue;
                },

                State.LookForSameLineCommentDirect => |node| {
                    try self.lookForSameLineComment(arena, node);
                    continue;
                },


                State.AsmOutputItems => |items| {
                    const lbracket = self.getNextToken();
                    if (lbracket.id != Token.Id.LBracket) {
                        self.putBackToken(lbracket);
                        continue;
                    }

                    const node = try self.createNode(arena, ast.Node.AsmOutput,
                        ast.Node.AsmOutput {
                            .base = undefined,
                            .symbolic_name = undefined,
                            .constraint = undefined,
                            .kind = undefined,
                        }
                    );
                    try items.append(node);

                    stack.append(State { .AsmOutputItems = items }) catch unreachable;
                    try stack.append(State { .IfToken = Token.Id.Comma });
                    try stack.append(State { .ExpectToken = Token.Id.RParen });
                    try stack.append(State { .AsmOutputReturnOrType = node });
                    try stack.append(State { .ExpectToken = Token.Id.LParen });
                    try stack.append(State { .StringLiteral = OptionalCtx { .Required = &node.constraint } });
                    try stack.append(State { .ExpectToken = Token.Id.RBracket });
                    try stack.append(State { .Identifier = OptionalCtx { .Required = &node.symbolic_name } });
                    continue;
                },
                State.AsmOutputReturnOrType => |node| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Identifier => {
                            node.kind = ast.Node.AsmOutput.Kind { .Variable = try self.createLiteral(arena, ast.Node.Identifier, token) };
                            continue;
                        },
                        Token.Id.Arrow => {
                            node.kind = ast.Node.AsmOutput.Kind { .Return = undefined };
                            try stack.append(State { .TypeExprBegin = OptionalCtx { .Required = &node.kind.Return } });
                            continue;
                        },
                        else => {
                            return self.parseError(token, "expected '->' or {}, found {}",
                                @tagName(Token.Id.Identifier),
                                @tagName(token.id));
                        },
                    }
                },
                State.AsmInputItems => |items| {
                    const lbracket = self.getNextToken();
                    if (lbracket.id != Token.Id.LBracket) {
                        self.putBackToken(lbracket);
                        continue;
                    }

                    const node = try self.createNode(arena, ast.Node.AsmInput,
                        ast.Node.AsmInput {
                            .base = undefined,
                            .symbolic_name = undefined,
                            .constraint = undefined,
                            .expr = undefined,
                        }
                    );
                    try items.append(node);

                    stack.append(State { .AsmInputItems = items }) catch unreachable;
                    try stack.append(State { .IfToken = Token.Id.Comma });
                    try stack.append(State { .ExpectToken = Token.Id.RParen });
                    try stack.append(State { .Expression = OptionalCtx { .Required = &node.expr } });
                    try stack.append(State { .ExpectToken = Token.Id.LParen });
                    try stack.append(State { .StringLiteral = OptionalCtx { .Required = &node.constraint } });
                    try stack.append(State { .ExpectToken = Token.Id.RBracket });
                    try stack.append(State { .Identifier = OptionalCtx { .Required = &node.symbolic_name } });
                    continue;
                },
                State.AsmClopperItems => |items| {
                    stack.append(State { .AsmClopperItems = items }) catch unreachable;
                    try stack.append(State { .IfToken = Token.Id.Comma });
                    try stack.append(State { .StringLiteral = OptionalCtx { .Required = try items.addOne() } });
                    continue;
                },


                State.ExprListItemOrEnd => |list_state| {
                    if (self.eatToken(list_state.end)) |token| {
                        *list_state.ptr = token;
                        continue;
                    }

                    stack.append(State { .ExprListCommaOrEnd = list_state }) catch unreachable;
                    try stack.append(State { .Expression = OptionalCtx { .Required = try list_state.list.addOne() } });
                    continue;
                },
                State.ExprListCommaOrEnd => |list_state| {
                    if (try self.expectCommaOrEnd(list_state.end)) |end| {
                        *list_state.ptr = end;
                        continue;
                    } else {
                        stack.append(State { .ExprListItemOrEnd = list_state }) catch unreachable;
                        continue;
                    }
                },
                State.FieldInitListItemOrEnd => |list_state| {
                    if (self.eatToken(Token.Id.RBrace)) |rbrace| {
                        *list_state.ptr = rbrace;
                        continue;
                    }

                    const node = try arena.construct(ast.Node.FieldInitializer {
                        .base = ast.Node {
                            .id = ast.Node.Id.FieldInitializer,
                            .doc_comments = null,
                            .same_line_comment = null,
                        },
                        .period_token = undefined,
                        .name_token = undefined,
                        .expr = undefined,
                    });
                    try list_state.list.append(node);

                    stack.append(State { .FieldInitListCommaOrEnd = list_state }) catch unreachable;
                    try stack.append(State { .Expression = OptionalCtx{ .Required = &node.expr } });
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
                    continue;
                },
                State.FieldInitListCommaOrEnd => |list_state| {
                    if (try self.expectCommaOrEnd(Token.Id.RBrace)) |end| {
                        *list_state.ptr = end;
                        continue;
                    } else {
                        stack.append(State { .FieldInitListItemOrEnd = list_state }) catch unreachable;
                        continue;
                    }
                },
                State.FieldListCommaOrEnd => |container_decl| {
                    if (try self.expectCommaOrEnd(Token.Id.RBrace)) |end| {
                        container_decl.rbrace_token = end;
                        continue;
                    }

                    try self.lookForSameLineComment(arena, container_decl.fields_and_decls.toSlice()[container_decl.fields_and_decls.len - 1]);
                    try stack.append(State { .ContainerDecl = container_decl });
                    continue;
                },
                State.IdentifierListItemOrEnd => |list_state| {
                    while (try self.eatLineComment(arena)) |line_comment| {
                        try list_state.list.append(&line_comment.base);
                    }

                    if (self.eatToken(Token.Id.RBrace)) |rbrace| {
                        *list_state.ptr = rbrace;
                        continue;
                    }

                    const comments = try self.eatComments(arena);
                    const node_ptr = try list_state.list.addOne();

                    try stack.append(State { .AddComments = AddCommentsCtx {
                        .node_ptr = node_ptr,
                        .comments = comments,
                    }});
                    try stack.append(State { .IdentifierListCommaOrEnd = list_state });
                    try stack.append(State { .Identifier = OptionalCtx { .Required = node_ptr } });
                    continue;
                },
                State.IdentifierListCommaOrEnd => |list_state| {
                    if (try self.expectCommaOrEnd(Token.Id.RBrace)) |end| {
                        *list_state.ptr = end;
                        continue;
                    } else {
                        stack.append(State { .IdentifierListItemOrEnd = list_state }) catch unreachable;
                        continue;
                    }
                },
                State.SwitchCaseOrEnd => |list_state| {
                    while (try self.eatLineComment(arena)) |line_comment| {
                        try list_state.list.append(&line_comment.base);
                    }

                    if (self.eatToken(Token.Id.RBrace)) |rbrace| {
                        *list_state.ptr = rbrace;
                        continue;
                    }

                    const comments = try self.eatComments(arena);
                    const node = try arena.construct(ast.Node.SwitchCase {
                        .base = ast.Node {
                            .id = ast.Node.Id.SwitchCase,
                            .doc_comments = comments,
                            .same_line_comment = null,
                        },
                        .items = ArrayList(&ast.Node).init(arena),
                        .payload = null,
                        .expr = undefined,
                    });
                    try list_state.list.append(&node.base);
                    try stack.append(State { .SwitchCaseCommaOrEnd = list_state });
                    try stack.append(State { .AssignmentExpressionBegin = OptionalCtx { .Required = &node.expr  } });
                    try stack.append(State { .PointerPayload = OptionalCtx { .Optional = &node.payload } });
                    try stack.append(State { .SwitchCaseFirstItem = &node.items });

                    continue;
                },

                State.SwitchCaseCommaOrEnd => |list_state| {
                    if (try self.expectCommaOrEnd(Token.Id.RBrace)) |end| {
                        *list_state.ptr = end;
                        continue;
                    }

                    const node = list_state.list.toSlice()[list_state.list.len - 1];
                    try self.lookForSameLineComment(arena, node);
                    try stack.append(State { .SwitchCaseOrEnd = list_state });
                    continue;
                },

                State.SwitchCaseFirstItem => |case_items| {
                    const token = self.getNextToken();
                    if (token.id == Token.Id.Keyword_else) {
                        const else_node = try self.createAttachNode(arena, case_items, ast.Node.SwitchElse,
                            ast.Node.SwitchElse {
                                .base = undefined,
                                .token = token,
                            }
                        );
                        try stack.append(State { .ExpectToken = Token.Id.EqualAngleBracketRight });
                        continue;
                    } else {
                        self.putBackToken(token);
                        try stack.append(State { .SwitchCaseItem = case_items });
                        continue;
                    }
                },
                State.SwitchCaseItem => |case_items| {
                    stack.append(State { .SwitchCaseItemCommaOrEnd = case_items }) catch unreachable;
                    try stack.append(State { .RangeExpressionBegin = OptionalCtx { .Required = try case_items.addOne() } });
                },
                State.SwitchCaseItemCommaOrEnd => |case_items| {
                    if ((try self.expectCommaOrEnd(Token.Id.EqualAngleBracketRight)) == null) {
                        stack.append(State { .SwitchCaseItem = case_items }) catch unreachable;
                    }
                    continue;
                },


                State.SuspendBody => |suspend_node| {
                    if (suspend_node.payload != null) {
                        try stack.append(State { .AssignmentExpressionBegin = OptionalCtx { .RequiredNull = &suspend_node.body } });
                    }
                    continue;
                },
                State.AsyncAllocator => |async_node| {
                    if (self.eatToken(Token.Id.AngleBracketLeft) == null) {
                        continue;
                    }

                    async_node.rangle_bracket = Token(undefined);
                    try stack.append(State {
                        .ExpectTokenSave = ExpectTokenSave {
                            .id = Token.Id.AngleBracketRight,
                            .ptr = &??async_node.rangle_bracket,
                        }
                    });
                    try stack.append(State { .TypeExprBegin = OptionalCtx { .RequiredNull = &async_node.allocator_type } });
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
                            if (suffix_op.op == ast.Node.SuffixOp.Op.Call) {
                                suffix_op.op.Call.async_attr = ctx.attribute;
                                continue;
                            }

                            return self.parseError(node.firstToken(), "expected {}, found {}.",
                                @tagName(ast.Node.SuffixOp.Op.Call),
                                @tagName(suffix_op.op));
                        },
                        else => {
                            return self.parseError(node.firstToken(), "expected {} or {}, found {}.",
                                @tagName(ast.Node.SuffixOp.Op.Call),
                                @tagName(ast.Node.Id.FnProto),
                                @tagName(node.id));
                        }
                    }
                },


                State.ExternType => |ctx| {
                    if (self.eatToken(Token.Id.Keyword_fn)) |fn_token| {
                        const fn_proto = try arena.construct(ast.Node.FnProto {
                            .base = ast.Node {
                                .id = ast.Node.Id.FnProto,
                                .doc_comments = ctx.comments,
                                .same_line_comment = null,
                            },
                            .visib_token = null,
                            .name_token = null,
                            .fn_token = fn_token,
                            .params = ArrayList(&ast.Node).init(arena),
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
                        stack.append(State { .FnProto = fn_proto }) catch unreachable;
                        continue;
                    }

                    stack.append(State {
                        .ContainerKind = ContainerKindCtx {
                            .opt_ctx = ctx.opt_ctx,
                            .ltoken = ctx.extern_token,
                            .layout = ast.Node.ContainerDecl.Layout.Extern,
                        },
                    }) catch unreachable;
                    continue;
                },
                State.SliceOrArrayAccess => |node| {
                    var token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Ellipsis2 => {
                            const start = node.op.ArrayAccess;
                            node.op = ast.Node.SuffixOp.Op {
                                .Slice = ast.Node.SuffixOp.SliceRange {
                                    .start = start,
                                    .end = null,
                                }
                            };

                            stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.RBracket,
                                    .ptr = &node.rtoken,
                                }
                            }) catch unreachable;
                            try stack.append(State { .Expression = OptionalCtx { .Optional = &node.op.Slice.end } });
                            continue;
                        },
                        Token.Id.RBracket => {
                            node.rtoken = token;
                            continue;
                        },
                        else => {
                            return self.parseError(token, "expected ']' or '..', found {}", @tagName(token.id));
                        }
                    }
                },
                State.SliceOrArrayType => |node| {
                    if (self.eatToken(Token.Id.RBracket)) |_| {
                        node.op = ast.Node.PrefixOp.Op {
                            .SliceType = ast.Node.PrefixOp.AddrOfInfo {
                                .align_expr = null,
                                .bit_offset_start_token = null,
                                .bit_offset_end_token = null,
                                .const_token = null,
                                .volatile_token = null,
                            }
                        };
                        stack.append(State { .TypeExprBegin = OptionalCtx { .Required = &node.rhs } }) catch unreachable;
                        try stack.append(State { .AddrOfModifiers = &node.op.SliceType });
                        continue;
                    }

                    node.op = ast.Node.PrefixOp.Op { .ArrayType = undefined };
                    stack.append(State { .TypeExprBegin = OptionalCtx { .Required = &node.rhs } }) catch unreachable;
                    try stack.append(State { .ExpectToken = Token.Id.RBracket });
                    try stack.append(State { .Expression = OptionalCtx { .Required = &node.op.ArrayType } });
                    continue;
                },
                State.AddrOfModifiers => |addr_of_info| {
                    var token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_align => {
                            stack.append(state) catch unreachable;
                            if (addr_of_info.align_expr != null) {
                                return self.parseError(token, "multiple align qualifiers");
                            }
                            try stack.append(State { .ExpectToken = Token.Id.RParen });
                            try stack.append(State { .Expression = OptionalCtx { .RequiredNull = &addr_of_info.align_expr} });
                            try stack.append(State { .ExpectToken = Token.Id.LParen });
                            continue;
                        },
                        Token.Id.Keyword_const => {
                            stack.append(state) catch unreachable;
                            if (addr_of_info.const_token != null) {
                                return self.parseError(token, "duplicate qualifier: const");
                            }
                            addr_of_info.const_token = token;
                            continue;
                        },
                        Token.Id.Keyword_volatile => {
                            stack.append(state) catch unreachable;
                            if (addr_of_info.volatile_token != null) {
                                return self.parseError(token, "duplicate qualifier: volatile");
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


                State.Payload => |opt_ctx| {
                    const token = self.getNextToken();
                    if (token.id != Token.Id.Pipe) {
                        if (opt_ctx != OptionalCtx.Optional) {
                            return self.parseError(token, "expected {}, found {}.",
                                @tagName(Token.Id.Pipe),
                                @tagName(token.id));
                        }

                        self.putBackToken(token);
                        continue;
                    }

                    const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.Payload,
                        ast.Node.Payload {
                            .base = undefined,
                            .lpipe = token,
                            .error_symbol = undefined,
                            .rpipe = undefined
                        }
                    );

                    stack.append(State {
                        .ExpectTokenSave = ExpectTokenSave {
                            .id = Token.Id.Pipe,
                            .ptr = &node.rpipe,
                        }
                    }) catch unreachable;
                    try stack.append(State { .Identifier = OptionalCtx { .Required = &node.error_symbol } });
                    continue;
                },
                State.PointerPayload => |opt_ctx| {
                    const token = self.getNextToken();
                    if (token.id != Token.Id.Pipe) {
                        if (opt_ctx != OptionalCtx.Optional) {
                            return self.parseError(token, "expected {}, found {}.",
                                @tagName(Token.Id.Pipe),
                                @tagName(token.id));
                        }

                        self.putBackToken(token);
                        continue;
                    }

                    const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.PointerPayload,
                        ast.Node.PointerPayload {
                            .base = undefined,
                            .lpipe = token,
                            .ptr_token = null,
                            .value_symbol = undefined,
                            .rpipe = undefined
                        }
                    );

                    stack.append(State {
                        .ExpectTokenSave = ExpectTokenSave {
                            .id = Token.Id.Pipe,
                            .ptr = &node.rpipe,
                        }
                    }) catch unreachable;
                    try stack.append(State { .Identifier = OptionalCtx { .Required = &node.value_symbol } });
                    try stack.append(State {
                        .OptionalTokenSave = OptionalTokenSave {
                            .id = Token.Id.Asterisk,
                            .ptr = &node.ptr_token,
                        }
                    });
                    continue;
                },
                State.PointerIndexPayload => |opt_ctx| {
                    const token = self.getNextToken();
                    if (token.id != Token.Id.Pipe) {
                        if (opt_ctx != OptionalCtx.Optional) {
                            return self.parseError(token, "expected {}, found {}.",
                                @tagName(Token.Id.Pipe),
                                @tagName(token.id));
                        }

                        self.putBackToken(token);
                        continue;
                    }

                    const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.PointerIndexPayload,
                        ast.Node.PointerIndexPayload {
                            .base = undefined,
                            .lpipe = token,
                            .ptr_token = null,
                            .value_symbol = undefined,
                            .index_symbol = null,
                            .rpipe = undefined
                        }
                    );

                    stack.append(State {
                        .ExpectTokenSave = ExpectTokenSave {
                            .id = Token.Id.Pipe,
                            .ptr = &node.rpipe,
                        }
                    }) catch unreachable;
                    try stack.append(State { .Identifier = OptionalCtx { .RequiredNull = &node.index_symbol } });
                    try stack.append(State { .IfToken = Token.Id.Comma });
                    try stack.append(State { .Identifier = OptionalCtx { .Required = &node.value_symbol } });
                    try stack.append(State {
                        .OptionalTokenSave = OptionalTokenSave {
                            .id = Token.Id.Asterisk,
                            .ptr = &node.ptr_token,
                        }
                    });
                    continue;
                },


                State.Expression => |opt_ctx| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_return, Token.Id.Keyword_break, Token.Id.Keyword_continue => {
                            const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.ControlFlowExpression,
                                ast.Node.ControlFlowExpression {
                                    .base = undefined,
                                    .ltoken = token,
                                    .kind = undefined,
                                    .rhs = null,
                                }
                            );

                            stack.append(State { .Expression = OptionalCtx { .Optional = &node.rhs } }) catch unreachable;

                            switch (token.id) {
                                Token.Id.Keyword_break => {
                                    node.kind = ast.Node.ControlFlowExpression.Kind { .Break = null };
                                    try stack.append(State { .Identifier = OptionalCtx { .RequiredNull = &node.kind.Break } });
                                    try stack.append(State { .IfToken = Token.Id.Colon });
                                },
                                Token.Id.Keyword_continue => {
                                    node.kind = ast.Node.ControlFlowExpression.Kind { .Continue = null };
                                    try stack.append(State { .Identifier = OptionalCtx { .RequiredNull = &node.kind.Continue } });
                                    try stack.append(State { .IfToken = Token.Id.Colon });
                                },
                                Token.Id.Keyword_return => {
                                    node.kind = ast.Node.ControlFlowExpression.Kind.Return;
                                },
                                else => unreachable,
                            }
                            continue;
                        },
                        Token.Id.Keyword_try, Token.Id.Keyword_cancel, Token.Id.Keyword_resume => {
                            const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.PrefixOp,
                                ast.Node.PrefixOp {
                                    .base = undefined,
                                    .op_token = token,
                                    .op = switch (token.id) {
                                        Token.Id.Keyword_try => ast.Node.PrefixOp.Op { .Try = void{} },
                                        Token.Id.Keyword_cancel => ast.Node.PrefixOp.Op { .Cancel = void{} },
                                        Token.Id.Keyword_resume => ast.Node.PrefixOp.Op { .Resume = void{} },
                                        else => unreachable,
                                    },
                                    .rhs = undefined,
                                }
                            );

                            stack.append(State { .Expression = OptionalCtx { .Required = &node.rhs } }) catch unreachable;
                            continue;
                        },
                        else => {
                            if (!try self.parseBlockExpr(&stack, arena, opt_ctx, token)) {
                                self.putBackToken(token);
                                stack.append(State { .UnwrapExpressionBegin = opt_ctx }) catch unreachable;
                            }
                            continue;
                        }
                    }
                },
                State.RangeExpressionBegin => |opt_ctx| {
                    stack.append(State { .RangeExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .Expression = opt_ctx });
                    continue;
                },
                State.RangeExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    if (self.eatToken(Token.Id.Ellipsis3)) |ellipsis3| {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = ellipsis3,
                                .op = ast.Node.InfixOp.Op.Range,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .Expression = OptionalCtx { .Required = &node.rhs } }) catch unreachable;
                        continue;
                    }
                },
                State.AssignmentExpressionBegin => |opt_ctx| {
                    stack.append(State { .AssignmentExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .Expression = opt_ctx });
                    continue;
                },

                State.AssignmentExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    const token = self.getNextToken();
                    if (tokenIdToAssignment(token.id)) |ass_id| {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = token,
                                .op = ass_id,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .AssignmentExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State { .Expression = OptionalCtx { .Required = &node.rhs } });
                        continue;
                    } else {
                        self.putBackToken(token);
                        continue;
                    }
                },

                State.UnwrapExpressionBegin => |opt_ctx| {
                    stack.append(State { .UnwrapExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .BoolOrExpressionBegin = opt_ctx });
                    continue;
                },

                State.UnwrapExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    const token = self.getNextToken();
                    if (tokenIdToUnwrapExpr(token.id)) |unwrap_id| {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = token,
                                .op = unwrap_id,
                                .rhs = undefined,
                            }
                        );

                        stack.append(State { .UnwrapExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State { .Expression = OptionalCtx { .Required = &node.rhs } });

                        if (node.op == ast.Node.InfixOp.Op.Catch) {
                            try stack.append(State { .Payload = OptionalCtx { .Optional = &node.op.Catch } });
                        }
                        continue;
                    } else {
                        self.putBackToken(token);
                        continue;
                    }
                },

                State.BoolOrExpressionBegin => |opt_ctx| {
                    stack.append(State { .BoolOrExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .BoolAndExpressionBegin = opt_ctx });
                    continue;
                },

                State.BoolOrExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    if (self.eatToken(Token.Id.Keyword_or)) |or_token| {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = or_token,
                                .op = ast.Node.InfixOp.Op.BoolOr,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .BoolOrExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State { .BoolAndExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                        continue;
                    }
                },

                State.BoolAndExpressionBegin => |opt_ctx| {
                    stack.append(State { .BoolAndExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .ComparisonExpressionBegin = opt_ctx });
                    continue;
                },

                State.BoolAndExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    if (self.eatToken(Token.Id.Keyword_and)) |and_token| {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = and_token,
                                .op = ast.Node.InfixOp.Op.BoolAnd,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .BoolAndExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State { .ComparisonExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                        continue;
                    }
                },

                State.ComparisonExpressionBegin => |opt_ctx| {
                    stack.append(State { .ComparisonExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .BinaryOrExpressionBegin = opt_ctx });
                    continue;
                },

                State.ComparisonExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    const token = self.getNextToken();
                    if (tokenIdToComparison(token.id)) |comp_id| {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = token,
                                .op = comp_id,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .ComparisonExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State { .BinaryOrExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                        continue;
                    } else {
                        self.putBackToken(token);
                        continue;
                    }
                },

                State.BinaryOrExpressionBegin => |opt_ctx| {
                    stack.append(State { .BinaryOrExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .BinaryXorExpressionBegin = opt_ctx });
                    continue;
                },

                State.BinaryOrExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    if (self.eatToken(Token.Id.Pipe)) |pipe| {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = pipe,
                                .op = ast.Node.InfixOp.Op.BitOr,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .BinaryOrExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State { .BinaryXorExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                        continue;
                    }
                },

                State.BinaryXorExpressionBegin => |opt_ctx| {
                    stack.append(State { .BinaryXorExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .BinaryAndExpressionBegin = opt_ctx });
                    continue;
                },

                State.BinaryXorExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    if (self.eatToken(Token.Id.Caret)) |caret| {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = caret,
                                .op = ast.Node.InfixOp.Op.BitXor,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .BinaryXorExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State { .BinaryAndExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                        continue;
                    }
                },

                State.BinaryAndExpressionBegin => |opt_ctx| {
                    stack.append(State { .BinaryAndExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .BitShiftExpressionBegin = opt_ctx });
                    continue;
                },

                State.BinaryAndExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    if (self.eatToken(Token.Id.Ampersand)) |ampersand| {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = ampersand,
                                .op = ast.Node.InfixOp.Op.BitAnd,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .BinaryAndExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State { .BitShiftExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                        continue;
                    }
                },

                State.BitShiftExpressionBegin => |opt_ctx| {
                    stack.append(State { .BitShiftExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .AdditionExpressionBegin = opt_ctx });
                    continue;
                },

                State.BitShiftExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    const token = self.getNextToken();
                    if (tokenIdToBitShift(token.id)) |bitshift_id| {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = token,
                                .op = bitshift_id,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .BitShiftExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State { .AdditionExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                        continue;
                    } else {
                        self.putBackToken(token);
                        continue;
                    }
                },

                State.AdditionExpressionBegin => |opt_ctx| {
                    stack.append(State { .AdditionExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .MultiplyExpressionBegin = opt_ctx });
                    continue;
                },

                State.AdditionExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    const token = self.getNextToken();
                    if (tokenIdToAddition(token.id)) |add_id| {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = token,
                                .op = add_id,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .AdditionExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State { .MultiplyExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                        continue;
                    } else {
                        self.putBackToken(token);
                        continue;
                    }
                },

                State.MultiplyExpressionBegin => |opt_ctx| {
                    stack.append(State { .MultiplyExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .CurlySuffixExpressionBegin = opt_ctx });
                    continue;
                },

                State.MultiplyExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    const token = self.getNextToken();
                    if (tokenIdToMultiply(token.id)) |mult_id| {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = token,
                                .op = mult_id,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .MultiplyExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State { .CurlySuffixExpressionBegin = OptionalCtx { .Required = &node.rhs } });
                        continue;
                    } else {
                        self.putBackToken(token);
                        continue;
                    }
                },

                State.CurlySuffixExpressionBegin => |opt_ctx| {
                    stack.append(State { .CurlySuffixExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .IfToken = Token.Id.LBrace });
                    try stack.append(State { .TypeExprBegin = opt_ctx });
                    continue;
                },

                State.CurlySuffixExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    if (self.isPeekToken(Token.Id.Period)) {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.SuffixOp,
                            ast.Node.SuffixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op = ast.Node.SuffixOp.Op {
                                    .StructInitializer = ArrayList(&ast.Node.FieldInitializer).init(arena),
                                },
                                .rtoken = undefined,
                            }
                        );
                        stack.append(State { .CurlySuffixExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State { .IfToken = Token.Id.LBrace });
                        try stack.append(State {
                            .FieldInitListItemOrEnd = ListSave(&ast.Node.FieldInitializer) {
                                .list = &node.op.StructInitializer,
                                .ptr = &node.rtoken,
                            }
                        });
                        continue;
                    }

                    const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.SuffixOp,
                        ast.Node.SuffixOp {
                            .base = undefined,
                            .lhs = lhs,
                            .op = ast.Node.SuffixOp.Op {
                                .ArrayInitializer = ArrayList(&ast.Node).init(arena),
                            },
                            .rtoken = undefined,
                        }
                    );
                    stack.append(State { .CurlySuffixExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                    try stack.append(State { .IfToken = Token.Id.LBrace });
                    try stack.append(State {
                        .ExprListItemOrEnd = ExprListCtx {
                            .list = &node.op.ArrayInitializer,
                            .end = Token.Id.RBrace,
                            .ptr = &node.rtoken,
                        }
                    });
                    continue;
                },

                State.TypeExprBegin => |opt_ctx| {
                    stack.append(State { .TypeExprEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .PrefixOpExpression = opt_ctx });
                    continue;
                },

                State.TypeExprEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    if (self.eatToken(Token.Id.Bang)) |bang| {
                        const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                            ast.Node.InfixOp {
                                .base = undefined,
                                .lhs = lhs,
                                .op_token = bang,
                                .op = ast.Node.InfixOp.Op.ErrorUnion,
                                .rhs = undefined,
                            }
                        );
                        stack.append(State { .TypeExprEnd = opt_ctx.toRequired() }) catch unreachable;
                        try stack.append(State { .PrefixOpExpression = OptionalCtx { .Required = &node.rhs } });
                        continue;
                    }
                },

                State.PrefixOpExpression => |opt_ctx| {
                    const token = self.getNextToken();
                    if (tokenIdToPrefixOp(token.id)) |prefix_id| {
                        var node = try self.createToCtxNode(arena, opt_ctx, ast.Node.PrefixOp,
                            ast.Node.PrefixOp {
                                .base = undefined,
                                .op_token = token,
                                .op = prefix_id,
                                .rhs = undefined,
                            }
                        );

                        // Treat '**' token as two derefs
                        if (token.id == Token.Id.AsteriskAsterisk) {
                            const child = try self.createNode(arena, ast.Node.PrefixOp,
                                ast.Node.PrefixOp {
                                    .base = undefined,
                                    .op_token = token,
                                    .op = prefix_id,
                                    .rhs = undefined,
                                }
                            );
                            node.rhs = &child.base;
                            node = child;
                        }

                        stack.append(State { .TypeExprBegin = OptionalCtx { .Required = &node.rhs } }) catch unreachable;
                        if (node.op == ast.Node.PrefixOp.Op.AddrOf) {
                            try stack.append(State { .AddrOfModifiers = &node.op.AddrOf });
                        }
                        continue;
                    } else {
                        self.putBackToken(token);
                        stack.append(State { .SuffixOpExpressionBegin = opt_ctx }) catch unreachable;
                        continue;
                    }
                },

                State.SuffixOpExpressionBegin => |opt_ctx| {
                    if (self.eatToken(Token.Id.Keyword_async)) |async_token| {
                        const async_node = try self.createNode(arena, ast.Node.AsyncAttribute,
                            ast.Node.AsyncAttribute {
                                .base = undefined,
                                .async_token = async_token,
                                .allocator_type = null,
                                .rangle_bracket = null,
                            }
                        );
                        stack.append(State {
                            .AsyncEnd = AsyncEndCtx {
                                .ctx = opt_ctx,
                                .attribute = async_node,
                            }
                        }) catch unreachable;
                        try stack.append(State { .SuffixOpExpressionEnd = opt_ctx.toRequired() });
                        try stack.append(State { .PrimaryExpression = opt_ctx.toRequired() });
                        try stack.append(State { .AsyncAllocator = async_node });
                        continue;
                    }

                    stack.append(State { .SuffixOpExpressionEnd = opt_ctx }) catch unreachable;
                    try stack.append(State { .PrimaryExpression = opt_ctx });
                    continue;
                },

                State.SuffixOpExpressionEnd => |opt_ctx| {
                    const lhs = opt_ctx.get() ?? continue;

                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.LParen => {
                            const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.SuffixOp,
                                ast.Node.SuffixOp {
                                    .base = undefined,
                                    .lhs = lhs,
                                    .op = ast.Node.SuffixOp.Op {
                                        .Call = ast.Node.SuffixOp.CallInfo {
                                            .params = ArrayList(&ast.Node).init(arena),
                                            .async_attr = null,
                                        }
                                    },
                                    .rtoken = undefined,
                                }
                            );
                            stack.append(State { .SuffixOpExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
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
                            const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.SuffixOp,
                                ast.Node.SuffixOp {
                                    .base = undefined,
                                    .lhs = lhs,
                                    .op = ast.Node.SuffixOp.Op {
                                        .ArrayAccess = undefined,
                                    },
                                    .rtoken = undefined
                                }
                            );
                            stack.append(State { .SuffixOpExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                            try stack.append(State { .SliceOrArrayAccess = node });
                            try stack.append(State { .Expression = OptionalCtx { .Required = &node.op.ArrayAccess }});
                            continue;
                        },
                        Token.Id.Period => {
                            const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.InfixOp,
                                ast.Node.InfixOp {
                                    .base = undefined,
                                    .lhs = lhs,
                                    .op_token = token,
                                    .op = ast.Node.InfixOp.Op.Period,
                                    .rhs = undefined,
                                }
                            );
                            stack.append(State { .SuffixOpExpressionEnd = opt_ctx.toRequired() }) catch unreachable;
                            try stack.append(State { .Identifier = OptionalCtx { .Required = &node.rhs } });
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            continue;
                        },
                    }
                },

                State.PrimaryExpression => |opt_ctx| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.IntegerLiteral => {
                            _ = try self.createToCtxLiteral(arena, opt_ctx, ast.Node.StringLiteral, token);
                            continue;
                        },
                        Token.Id.FloatLiteral => {
                            _ = try self.createToCtxLiteral(arena, opt_ctx, ast.Node.FloatLiteral, token);
                            continue;
                        },
                        Token.Id.CharLiteral => {
                            _ = try self.createToCtxLiteral(arena, opt_ctx, ast.Node.CharLiteral, token);
                            continue;
                        },
                        Token.Id.Keyword_undefined => {
                            _ = try self.createToCtxLiteral(arena, opt_ctx, ast.Node.UndefinedLiteral, token);
                            continue;
                        },
                        Token.Id.Keyword_true, Token.Id.Keyword_false => {
                            _ = try self.createToCtxLiteral(arena, opt_ctx, ast.Node.BoolLiteral, token);
                            continue;
                        },
                        Token.Id.Keyword_null => {
                            _ = try self.createToCtxLiteral(arena, opt_ctx, ast.Node.NullLiteral, token);
                            continue;
                        },
                        Token.Id.Keyword_this => {
                            _ = try self.createToCtxLiteral(arena, opt_ctx, ast.Node.ThisLiteral, token);
                            continue;
                        },
                        Token.Id.Keyword_var => {
                            _ = try self.createToCtxLiteral(arena, opt_ctx, ast.Node.VarType, token);
                            continue;
                        },
                        Token.Id.Keyword_unreachable => {
                            _ = try self.createToCtxLiteral(arena, opt_ctx, ast.Node.Unreachable, token);
                            continue;
                        },
                        Token.Id.StringLiteral, Token.Id.MultilineStringLiteralLine => {
                            opt_ctx.store((try self.parseStringLiteral(arena, token)) ?? unreachable);
                            continue;
                        },
                        Token.Id.LParen => {
                            const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.GroupedExpression,
                                ast.Node.GroupedExpression {
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
                            try stack.append(State { .Expression = OptionalCtx { .Required = &node.expr } });
                            continue;
                        },
                        Token.Id.Builtin => {
                            const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.BuiltinCall,
                                ast.Node.BuiltinCall {
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
                            const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.PrefixOp,
                                ast.Node.PrefixOp {
                                    .base = undefined,
                                    .op_token = token,
                                    .op = undefined,
                                    .rhs = undefined,
                                }
                            );
                            stack.append(State { .SliceOrArrayType = node }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_error => {
                            stack.append(State {
                                .ErrorTypeOrSetDecl = ErrorTypeOrSetDeclCtx {
                                    .error_token = token,
                                    .opt_ctx = opt_ctx
                                }
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_packed => {
                            stack.append(State {
                                .ContainerKind = ContainerKindCtx {
                                    .opt_ctx = opt_ctx,
                                    .ltoken = token,
                                    .layout = ast.Node.ContainerDecl.Layout.Packed,
                                },
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_extern => {
                            stack.append(State {
                                .ExternType = ExternTypeCtx {
                                    .opt_ctx = opt_ctx,
                                    .extern_token = token,
                                    .comments = null,
                                },
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_struct, Token.Id.Keyword_union, Token.Id.Keyword_enum => {
                            self.putBackToken(token);
                            stack.append(State {
                                .ContainerKind = ContainerKindCtx {
                                    .opt_ctx = opt_ctx,
                                    .ltoken = token,
                                    .layout = ast.Node.ContainerDecl.Layout.Auto,
                                },
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Identifier => {
                            stack.append(State {
                                .MaybeLabeledExpression = MaybeLabeledExpressionCtx {
                                    .label = token,
                                    .opt_ctx = opt_ctx
                                }
                            }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_fn => {
                            const fn_proto = try arena.construct(ast.Node.FnProto {
                                .base = ast.Node {
                                    .id = ast.Node.Id.FnProto,
                                    .doc_comments = null,
                                    .same_line_comment = null,
                                },
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
                            });
                            opt_ctx.store(&fn_proto.base);
                            stack.append(State { .FnProto = fn_proto }) catch unreachable;
                            continue;
                        },
                        Token.Id.Keyword_nakedcc, Token.Id.Keyword_stdcallcc => {
                            const fn_proto = try arena.construct(ast.Node.FnProto {
                                .base = ast.Node {
                                    .id = ast.Node.Id.FnProto,
                                    .doc_comments = null,
                                    .same_line_comment = null,
                                },
                                .visib_token = null,
                                .name_token = null,
                                .fn_token = undefined,
                                .params = ArrayList(&ast.Node).init(arena),
                                .return_type = undefined,
                                .var_args_token = null,
                                .extern_export_inline_token = null,
                                .cc_token = token,
                                .async_attr = null,
                                .body_node = null,
                                .lib_name = null,
                                .align_expr = null,
                            });
                            opt_ctx.store(&fn_proto.base);
                            stack.append(State { .FnProto = fn_proto }) catch unreachable;
                            try stack.append(State {
                                .ExpectTokenSave = ExpectTokenSave {
                                    .id = Token.Id.Keyword_fn,
                                    .ptr = &fn_proto.fn_token
                                }
                            });
                            continue;
                        },
                        Token.Id.Keyword_asm => {
                            const node = try self.createToCtxNode(arena, opt_ctx, ast.Node.Asm,
                                ast.Node.Asm {
                                    .base = undefined,
                                    .asm_token = token,
                                    .volatile_token = null,
                                    .template = undefined,
                                    //.tokens = ArrayList(ast.Node.Asm.AsmToken).init(arena),
                                    .outputs = ArrayList(&ast.Node.AsmOutput).init(arena),
                                    .inputs = ArrayList(&ast.Node.AsmInput).init(arena),
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
                            try stack.append(State { .StringLiteral = OptionalCtx { .Required = &node.template } });
                            try stack.append(State { .ExpectToken = Token.Id.LParen });
                            try stack.append(State {
                                .OptionalTokenSave = OptionalTokenSave {
                                    .id = Token.Id.Keyword_volatile,
                                    .ptr = &node.volatile_token,
                                }
                            });
                        },
                        Token.Id.Keyword_inline => {
                            stack.append(State {
                                .Inline = InlineCtx {
                                    .label = null,
                                    .inline_token = token,
                                    .opt_ctx = opt_ctx,
                                }
                            }) catch unreachable;
                            continue;
                        },
                        else => {
                            if (!try self.parseBlockExpr(&stack, arena, opt_ctx, token)) {
                                self.putBackToken(token);
                                if (opt_ctx != OptionalCtx.Optional) {
                                    return self.parseError(token, "expected primary expression, found {}", @tagName(token.id));
                                }
                            }
                            continue;
                        }
                    }
                },


                State.ErrorTypeOrSetDecl => |ctx| {
                    if (self.eatToken(Token.Id.LBrace) == null) {
                        _ = try self.createToCtxLiteral(arena, ctx.opt_ctx, ast.Node.ErrorType, ctx.error_token);
                        continue;
                    }

                    const node = try arena.construct(ast.Node.ErrorSetDecl {
                        .base = ast.Node {
                            .id = ast.Node.Id.ErrorSetDecl,
                            .doc_comments = null,
                            .same_line_comment = null,
                        },
                        .error_token = ctx.error_token,
                        .decls = ArrayList(&ast.Node).init(arena),
                        .rbrace_token = undefined,
                    });
                    ctx.opt_ctx.store(&node.base);

                    stack.append(State {
                        .IdentifierListItemOrEnd = ListSave(&ast.Node) {
                            .list = &node.decls,
                            .ptr = &node.rbrace_token,
                        }
                    }) catch unreachable;
                    continue;
                },
                State.StringLiteral => |opt_ctx| {
                    const token = self.getNextToken();
                    opt_ctx.store(
                        (try self.parseStringLiteral(arena, token)) ?? {
                            self.putBackToken(token);
                            if (opt_ctx != OptionalCtx.Optional) {
                                return self.parseError(token, "expected primary expression, found {}", @tagName(token.id));
                            }

                            continue;
                        }
                    );
                },
                State.Identifier => |opt_ctx| {
                    if (self.eatToken(Token.Id.Identifier)) |ident_token| {
                        _ = try self.createToCtxLiteral(arena, opt_ctx, ast.Node.Identifier, ident_token);
                        continue;
                    }

                    if (opt_ctx != OptionalCtx.Optional) {
                        const token = self.getNextToken();
                        return self.parseError(token, "expected identifier, found {}", @tagName(token.id));
                    }
                },


                State.ExpectToken => |token_id| {
                    _ = try self.expectToken(token_id);
                    continue;
                },
                State.ExpectTokenSave => |expect_token_save| {
                    *expect_token_save.ptr = try self.expectToken(expect_token_save.id);
                    continue;
                },
                State.IfToken => |token_id| {
                    if (self.eatToken(token_id)) |_| {
                        continue;
                    }

                    _ = stack.pop();
                    continue;
                },
                State.IfTokenSave => |if_token_save| {
                    if (self.eatToken(if_token_save.id)) |token| {
                        *if_token_save.ptr = token;
                        continue;
                    }

                    _ = stack.pop();
                    continue;
                },
                State.OptionalTokenSave => |optional_token_save| {
                    if (self.eatToken(optional_token_save.id)) |token| {
                        *optional_token_save.ptr = token;
                        continue;
                    }

                    continue;
                },
            }
        }
    }

    fn eatComments(self: &Parser, arena: &mem.Allocator) !?&ast.Node.DocComment {
        var result: ?&ast.Node.DocComment = null;
        while (true) {
            if (self.eatToken(Token.Id.DocComment)) |line_comment| {
                const node = blk: {
                    if (result) |comment_node| {
                        break :blk comment_node;
                    } else {
                        const comment_node = try arena.construct(ast.Node.DocComment {
                            .base = ast.Node {
                                .id = ast.Node.Id.DocComment,
                                .doc_comments = null,
                                .same_line_comment = null,
                            },
                            .lines = ArrayList(Token).init(arena),
                        });
                        result = comment_node;
                        break :blk comment_node;
                    }
                };
                try node.lines.append(line_comment);
                continue;
            }
            break;
        }
        return result;
    }

    fn eatLineComment(self: &Parser, arena: &mem.Allocator) !?&ast.Node.LineComment {
        const token = self.eatToken(Token.Id.LineComment) ?? return null;
        return try arena.construct(ast.Node.LineComment {
            .base = ast.Node {
                .id = ast.Node.Id.LineComment,
                .doc_comments = null,
                .same_line_comment = null,
            },
            .token = token,
        });
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
                ast.Node.Id.DocComment,
                ast.Node.Id.LineComment,
                ast.Node.Id.TestDecl => return false,
                ast.Node.Id.While => {
                    const while_node = @fieldParentPtr(ast.Node.While, "base", n);
                    if (while_node.@"else") |@"else"| {
                        n = @"else".base;
                        continue;
                    }

                    return while_node.body.id != ast.Node.Id.Block;
                },
                ast.Node.Id.For => {
                    const for_node = @fieldParentPtr(ast.Node.For, "base", n);
                    if (for_node.@"else") |@"else"| {
                        n = @"else".base;
                        continue;
                    }

                    return for_node.body.id != ast.Node.Id.Block;
                },
                ast.Node.Id.If => {
                    const if_node = @fieldParentPtr(ast.Node.If, "base", n);
                    if (if_node.@"else") |@"else"| {
                        n = @"else".base;
                        continue;
                    }

                    return if_node.body.id != ast.Node.Id.Block;
                },
                ast.Node.Id.Else => {
                    const else_node = @fieldParentPtr(ast.Node.Else, "base", n);
                    n = else_node.body;
                    continue;
                },
                ast.Node.Id.Defer => {
                    const defer_node = @fieldParentPtr(ast.Node.Defer, "base", n);
                    return defer_node.expr.id != ast.Node.Id.Block;
                },
                ast.Node.Id.Comptime => {
                    const comptime_node = @fieldParentPtr(ast.Node.Comptime, "base", n);
                    return comptime_node.expr.id != ast.Node.Id.Block;
                },
                ast.Node.Id.Suspend => {
                    const suspend_node = @fieldParentPtr(ast.Node.Suspend, "base", n);
                    if (suspend_node.body) |body| {
                        return body.id != ast.Node.Id.Block;
                    }

                    return true;
                },
                else => return true,
            }
        }
    }

    fn lookForSameLineComment(self: &Parser, arena: &mem.Allocator, node: &ast.Node) !void {
        const node_last_token = node.lastToken();

        const line_comment_token = self.getNextToken();
        if (line_comment_token.id != Token.Id.DocComment and line_comment_token.id != Token.Id.LineComment) {
            self.putBackToken(line_comment_token);
            return;
        }

        const offset_loc = self.tokenizer.getTokenLocation(node_last_token.end, line_comment_token);
        const different_line = offset_loc.line != 0;
        if (different_line) {
            self.putBackToken(line_comment_token);
            return;
        }

        node.same_line_comment = try arena.construct(line_comment_token);
    }

    fn parseStringLiteral(self: &Parser, arena: &mem.Allocator, token: &const Token) !?&ast.Node {
        switch (token.id) {
            Token.Id.StringLiteral => {
                return &(try self.createLiteral(arena, ast.Node.StringLiteral, token)).base;
            },
            Token.Id.MultilineStringLiteralLine => {
                const node = try self.createNode(arena, ast.Node.MultilineStringLiteral,
                    ast.Node.MultilineStringLiteral {
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

    fn parseBlockExpr(self: &Parser, stack: &ArrayList(State), arena: &mem.Allocator, ctx: &const OptionalCtx, token: &const Token) !bool {
        switch (token.id) {
            Token.Id.Keyword_suspend => {
                const node = try self.createToCtxNode(arena, ctx, ast.Node.Suspend,
                    ast.Node.Suspend {
                        .base = undefined,
                        .suspend_token = *token,
                        .payload = null,
                        .body = null,
                    }
                );

                stack.append(State { .SuspendBody = node }) catch unreachable;
                try stack.append(State { .Payload = OptionalCtx { .Optional = &node.payload } });
                return true;
            },
            Token.Id.Keyword_if => {
                const node = try self.createToCtxNode(arena, ctx, ast.Node.If,
                    ast.Node.If {
                        .base = undefined,
                        .if_token = *token,
                        .condition = undefined,
                        .payload = null,
                        .body = undefined,
                        .@"else" = null,
                    }
                );

                stack.append(State { .Else = &node.@"else" }) catch unreachable;
                try stack.append(State { .Expression = OptionalCtx { .Required = &node.body } });
                try stack.append(State { .PointerPayload = OptionalCtx { .Optional = &node.payload } });
                try stack.append(State { .ExpectToken = Token.Id.RParen });
                try stack.append(State { .Expression = OptionalCtx { .Required = &node.condition } });
                try stack.append(State { .ExpectToken = Token.Id.LParen });
                return true;
            },
            Token.Id.Keyword_while => {
                stack.append(State {
                    .While = LoopCtx {
                        .label = null,
                        .inline_token = null,
                        .loop_token = *token,
                        .opt_ctx = *ctx,
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
                        .opt_ctx = *ctx,
                    }
                }) catch unreachable;
                return true;
            },
            Token.Id.Keyword_switch => {
                const node = try arena.construct(ast.Node.Switch {
                    .base = ast.Node {
                        .id = ast.Node.Id.Switch,
                        .doc_comments = null,
                        .same_line_comment = null,
                    },
                    .switch_token = *token,
                    .expr = undefined,
                    .cases = ArrayList(&ast.Node).init(arena),
                    .rbrace = undefined,
                });
                ctx.store(&node.base);

                stack.append(State {
                    .SwitchCaseOrEnd = ListSave(&ast.Node) {
                        .list = &node.cases,
                        .ptr = &node.rbrace,
                    },
                }) catch unreachable;
                try stack.append(State { .ExpectToken = Token.Id.LBrace });
                try stack.append(State { .ExpectToken = Token.Id.RParen });
                try stack.append(State { .Expression = OptionalCtx { .Required = &node.expr } });
                try stack.append(State { .ExpectToken = Token.Id.LParen });
                return true;
            },
            Token.Id.Keyword_comptime => {
                const node = try self.createToCtxNode(arena, ctx, ast.Node.Comptime,
                    ast.Node.Comptime {
                        .base = undefined,
                        .comptime_token = *token,
                        .expr = undefined,
                    }
                );
                try stack.append(State { .Expression = OptionalCtx { .Required = &node.expr } });
                return true;
            },
            Token.Id.LBrace => {
                const block = try self.createToCtxNode(arena, ctx, ast.Node.Block,
                    ast.Node.Block {
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

    fn expectCommaOrEnd(self: &Parser, end: @TagType(Token.Id)) !?Token {
        var token = self.getNextToken();
        switch (token.id) {
            Token.Id.Comma => return null,
            else => {
                if (end == token.id) {
                    return token;
                }

                return self.parseError(token, "expected ',' or {}, found {}", @tagName(end), @tagName(token.id));
            },
        }
    }

    fn tokenIdToAssignment(id: &const Token.Id) ?ast.Node.InfixOp.Op {
        // TODO: We have to cast all cases because of this:
        // error: expected type '?InfixOp', found '?@TagType(InfixOp)'
        return switch (*id) {
            Token.Id.AmpersandEqual => ast.Node.InfixOp.Op { .AssignBitAnd = void{} },
            Token.Id.AngleBracketAngleBracketLeftEqual => ast.Node.InfixOp.Op { .AssignBitShiftLeft = void{} },
            Token.Id.AngleBracketAngleBracketRightEqual => ast.Node.InfixOp.Op { .AssignBitShiftRight = void{} },
            Token.Id.AsteriskEqual => ast.Node.InfixOp.Op { .AssignTimes = void{} },
            Token.Id.AsteriskPercentEqual => ast.Node.InfixOp.Op { .AssignTimesWarp = void{} },
            Token.Id.CaretEqual => ast.Node.InfixOp.Op { .AssignBitXor = void{} },
            Token.Id.Equal => ast.Node.InfixOp.Op { .Assign = void{} },
            Token.Id.MinusEqual => ast.Node.InfixOp.Op { .AssignMinus = void{} },
            Token.Id.MinusPercentEqual => ast.Node.InfixOp.Op { .AssignMinusWrap = void{} },
            Token.Id.PercentEqual => ast.Node.InfixOp.Op { .AssignMod = void{} },
            Token.Id.PipeEqual => ast.Node.InfixOp.Op { .AssignBitOr = void{} },
            Token.Id.PlusEqual => ast.Node.InfixOp.Op { .AssignPlus = void{} },
            Token.Id.PlusPercentEqual => ast.Node.InfixOp.Op { .AssignPlusWrap = void{} },
            Token.Id.SlashEqual => ast.Node.InfixOp.Op { .AssignDiv = void{} },
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

    fn createNode(self: &Parser, arena: &mem.Allocator, comptime T: type, init_to: &const T) !&T {
        const node = try arena.create(T);
        *node = *init_to;
        node.base = blk: {
            const id = ast.Node.typeToId(T);
            break :blk ast.Node {
                .id = id,
                .doc_comments = null,
                .same_line_comment = null,
            };
        };

        return node;
    }

    fn createAttachNode(self: &Parser, arena: &mem.Allocator, list: &ArrayList(&ast.Node), comptime T: type, init_to: &const T) !&T {
        const node = try self.createNode(arena, T, init_to);
        try list.append(&node.base);

        return node;
    }

    fn createToCtxNode(self: &Parser, arena: &mem.Allocator, opt_ctx: &const OptionalCtx, comptime T: type, init_to: &const T) !&T {
        const node = try self.createNode(arena, T, init_to);
        opt_ctx.store(&node.base);

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

    fn createToCtxLiteral(self: &Parser, arena: &mem.Allocator, opt_ctx: &const OptionalCtx, comptime T: type, token: &const Token) !&T {
        const node = try self.createLiteral(arena, T, token);
        opt_ctx.store(&node.base);

        return node;
    }

    fn parseError(self: &Parser, token: &const Token, comptime fmt: []const u8, args: ...) (error{ParseError}) {
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
    }

    fn expectToken(self: &Parser, id: @TagType(Token.Id)) !Token {
        const token = self.getNextToken();
        if (token.id != id) {
            return self.parseError(token, "expected {}, found {}", @tagName(id), @tagName(token.id));
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

    pub fn renderAst(self: &Parser, stream: var, root_node: &ast.Node.Root) !void {
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
        VarDecl: &ast.Node.VarDecl,
        Statement: &ast.Node,
        FieldInitializer: &ast.Node.FieldInitializer,
        PrintIndent,
        Indent: usize,
        PrintSameLineComment: ?&Token,
        PrintComments: &ast.Node,
    };

    pub fn renderSource(self: &Parser, stream: var, root_node: &ast.Node.Root) !void {
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
                    try stack.append(RenderState { .PrintSameLineComment = decl.same_line_comment } );
                    switch (decl.id) {
                        ast.Node.Id.FnProto => {
                            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", decl);
                            try self.renderComments(stream, &fn_proto.base, indent);

                            if (fn_proto.body_node) |body_node| {
                                stack.append(RenderState { .Expression = body_node}) catch unreachable;
                                try stack.append(RenderState { .Text = " "});
                            } else {
                                stack.append(RenderState { .Text = ";" }) catch unreachable;
                            }

                            try stack.append(RenderState { .Expression = decl });
                        },
                        ast.Node.Id.Use => {
                            const use_decl = @fieldParentPtr(ast.Node.Use, "base", decl);
                            if (use_decl.visib_token) |visib_token| {
                                try stream.print("{} ", self.tokenizer.getTokenSlice(visib_token));
                            }
                            try stream.print("use ");
                            try stack.append(RenderState { .Text = ";" });
                            try stack.append(RenderState { .Expression = use_decl.expr });
                        },
                        ast.Node.Id.VarDecl => {
                            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", decl);
                            try self.renderComments(stream, &var_decl.base, indent);
                            try stack.append(RenderState { .VarDecl = var_decl});
                        },
                        ast.Node.Id.TestDecl => {
                            const test_decl = @fieldParentPtr(ast.Node.TestDecl, "base", decl);
                            try self.renderComments(stream, &test_decl.base, indent);
                            try stream.print("test ");
                            try stack.append(RenderState { .Expression = test_decl.body_node });
                            try stack.append(RenderState { .Text = " " });
                            try stack.append(RenderState { .Expression = test_decl.name });
                        },
                        ast.Node.Id.StructField => {
                            const field = @fieldParentPtr(ast.Node.StructField, "base", decl);
                            if (field.visib_token) |visib_token| {
                                try stream.print("{} ", self.tokenizer.getTokenSlice(visib_token));
                            }
                            try stream.print("{}: ", self.tokenizer.getTokenSlice(field.name_token));
                            try stack.append(RenderState { .Text = "," });
                            try stack.append(RenderState { .Expression = field.type_expr});
                        },
                        ast.Node.Id.UnionTag => {
                            const tag = @fieldParentPtr(ast.Node.UnionTag, "base", decl);
                            try stream.print("{}", self.tokenizer.getTokenSlice(tag.name_token));

                            try stack.append(RenderState { .Text = "," });
                            if (tag.type_expr) |type_expr| {
                                try stream.print(": ");
                                try stack.append(RenderState { .Expression = type_expr});
                            }
                        },
                        ast.Node.Id.EnumTag => {
                            const tag = @fieldParentPtr(ast.Node.EnumTag, "base", decl);
                            try stream.print("{}", self.tokenizer.getTokenSlice(tag.name_token));

                            try stack.append(RenderState { .Text = "," });
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
                        ast.Node.Id.LineComment => {
                            const line_comment_node = @fieldParentPtr(ast.Node.LineComment, "base", decl);
                            try stream.write(self.tokenizer.getTokenSlice(line_comment_node.token));
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
                    const param_decl = @fieldParentPtr(ast.Node.ParamDecl, "base", base);
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
                        const identifier = @fieldParentPtr(ast.Node.Identifier, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(identifier.token));
                    },
                    ast.Node.Id.Block => {
                        const block = @fieldParentPtr(ast.Node.Block, "base", base);
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
                        const defer_node = @fieldParentPtr(ast.Node.Defer, "base", base);
                        try stream.print("{} ", self.tokenizer.getTokenSlice(defer_node.defer_token));
                        try stack.append(RenderState { .Expression = defer_node.expr });
                    },
                    ast.Node.Id.Comptime => {
                        const comptime_node = @fieldParentPtr(ast.Node.Comptime, "base", base);
                        try stream.print("{} ", self.tokenizer.getTokenSlice(comptime_node.comptime_token));
                        try stack.append(RenderState { .Expression = comptime_node.expr });
                    },
                    ast.Node.Id.AsyncAttribute => {
                        const async_attr = @fieldParentPtr(ast.Node.AsyncAttribute, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(async_attr.async_token));

                        if (async_attr.allocator_type) |allocator_type| {
                            try stack.append(RenderState { .Text = ">" });
                            try stack.append(RenderState { .Expression = allocator_type });
                            try stack.append(RenderState { .Text = "<" });
                        }
                    },
                    ast.Node.Id.Suspend => {
                        const suspend_node = @fieldParentPtr(ast.Node.Suspend, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(suspend_node.suspend_token));

                        if (suspend_node.body) |body| {
                            try stack.append(RenderState { .Expression = body });
                            try stack.append(RenderState { .Text = " " });
                        }

                        if (suspend_node.payload) |payload| {
                            try stack.append(RenderState { .Expression = payload });
                            try stack.append(RenderState { .Text = " " });
                        }
                    },
                    ast.Node.Id.InfixOp => {
                        const prefix_op_node = @fieldParentPtr(ast.Node.InfixOp, "base", base);
                        try stack.append(RenderState { .Expression = prefix_op_node.rhs });

                        if (prefix_op_node.op == ast.Node.InfixOp.Op.Catch) {
                            if (prefix_op_node.op.Catch) |payload| {
                            try stack.append(RenderState { .Text = " " });
                                try stack.append(RenderState { .Expression = payload });
                            }
                            try stack.append(RenderState { .Text = " catch " });
                        } else {
                            const text = switch (prefix_op_node.op) {
                                ast.Node.InfixOp.Op.Add => " + ",
                                ast.Node.InfixOp.Op.AddWrap => " +% ",
                                ast.Node.InfixOp.Op.ArrayCat => " ++ ",
                                ast.Node.InfixOp.Op.ArrayMult => " ** ",
                                ast.Node.InfixOp.Op.Assign => " = ",
                                ast.Node.InfixOp.Op.AssignBitAnd => " &= ",
                                ast.Node.InfixOp.Op.AssignBitOr => " |= ",
                                ast.Node.InfixOp.Op.AssignBitShiftLeft => " <<= ",
                                ast.Node.InfixOp.Op.AssignBitShiftRight => " >>= ",
                                ast.Node.InfixOp.Op.AssignBitXor => " ^= ",
                                ast.Node.InfixOp.Op.AssignDiv => " /= ",
                                ast.Node.InfixOp.Op.AssignMinus => " -= ",
                                ast.Node.InfixOp.Op.AssignMinusWrap => " -%= ",
                                ast.Node.InfixOp.Op.AssignMod => " %= ",
                                ast.Node.InfixOp.Op.AssignPlus => " += ",
                                ast.Node.InfixOp.Op.AssignPlusWrap => " +%= ",
                                ast.Node.InfixOp.Op.AssignTimes => " *= ",
                                ast.Node.InfixOp.Op.AssignTimesWarp => " *%= ",
                                ast.Node.InfixOp.Op.BangEqual => " != ",
                                ast.Node.InfixOp.Op.BitAnd => " & ",
                                ast.Node.InfixOp.Op.BitOr => " | ",
                                ast.Node.InfixOp.Op.BitShiftLeft => " << ",
                                ast.Node.InfixOp.Op.BitShiftRight => " >> ",
                                ast.Node.InfixOp.Op.BitXor => " ^ ",
                                ast.Node.InfixOp.Op.BoolAnd => " and ",
                                ast.Node.InfixOp.Op.BoolOr => " or ",
                                ast.Node.InfixOp.Op.Div => " / ",
                                ast.Node.InfixOp.Op.EqualEqual => " == ",
                                ast.Node.InfixOp.Op.ErrorUnion => "!",
                                ast.Node.InfixOp.Op.GreaterOrEqual => " >= ",
                                ast.Node.InfixOp.Op.GreaterThan => " > ",
                                ast.Node.InfixOp.Op.LessOrEqual => " <= ",
                                ast.Node.InfixOp.Op.LessThan => " < ",
                                ast.Node.InfixOp.Op.MergeErrorSets => " || ",
                                ast.Node.InfixOp.Op.Mod => " % ",
                                ast.Node.InfixOp.Op.Mult => " * ",
                                ast.Node.InfixOp.Op.MultWrap => " *% ",
                                ast.Node.InfixOp.Op.Period => ".",
                                ast.Node.InfixOp.Op.Sub => " - ",
                                ast.Node.InfixOp.Op.SubWrap => " -% ",
                                ast.Node.InfixOp.Op.UnwrapMaybe => " ?? ",
                                ast.Node.InfixOp.Op.Range => " ... ",
                                ast.Node.InfixOp.Op.Catch => unreachable,
                            };

                            try stack.append(RenderState { .Text = text });
                        }
                        try stack.append(RenderState { .Expression = prefix_op_node.lhs });
                    },
                    ast.Node.Id.PrefixOp => {
                        const prefix_op_node = @fieldParentPtr(ast.Node.PrefixOp, "base", base);
                        if (prefix_op_node.op != ast.Node.PrefixOp.Op.Deref) {
                            try stack.append(RenderState { .Expression = prefix_op_node.rhs });
                        }
                        switch (prefix_op_node.op) {
                            ast.Node.PrefixOp.Op.AddrOf => |addr_of_info| {
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
                            ast.Node.PrefixOp.Op.SliceType => |addr_of_info| {
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
                            ast.Node.PrefixOp.Op.ArrayType => |array_index| {
                                try stack.append(RenderState { .Text = "]"});
                                try stack.append(RenderState { .Expression = array_index});
                                try stack.append(RenderState { .Text = "["});
                            },
                            ast.Node.PrefixOp.Op.BitNot => try stream.write("~"),
                            ast.Node.PrefixOp.Op.BoolNot => try stream.write("!"),
                            ast.Node.PrefixOp.Op.Deref => {
                                try stack.append(RenderState { .Text = ".*" });
                                try stack.append(RenderState { .Expression = prefix_op_node.rhs });
                            },
                            ast.Node.PrefixOp.Op.Negation => try stream.write("-"),
                            ast.Node.PrefixOp.Op.NegationWrap => try stream.write("-%"),
                            ast.Node.PrefixOp.Op.Try => try stream.write("try "),
                            ast.Node.PrefixOp.Op.UnwrapMaybe => try stream.write("??"),
                            ast.Node.PrefixOp.Op.MaybeType => try stream.write("?"),
                            ast.Node.PrefixOp.Op.Await => try stream.write("await "),
                            ast.Node.PrefixOp.Op.Cancel => try stream.write("cancel "),
                            ast.Node.PrefixOp.Op.Resume => try stream.write("resume "),
                        }
                    },
                    ast.Node.Id.SuffixOp => {
                        const suffix_op = @fieldParentPtr(ast.Node.SuffixOp, "base", base);

                        switch (suffix_op.op) {
                            ast.Node.SuffixOp.Op.Call => |call_info| {
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
                            ast.Node.SuffixOp.Op.ArrayAccess => |index_expr| {
                                try stack.append(RenderState { .Text = "]"});
                                try stack.append(RenderState { .Expression = index_expr});
                                try stack.append(RenderState { .Text = "["});
                                try stack.append(RenderState { .Expression = suffix_op.lhs });
                            },
                            ast.Node.SuffixOp.Op.Slice => |range| {
                                try stack.append(RenderState { .Text = "]"});
                                if (range.end) |end| {
                                    try stack.append(RenderState { .Expression = end});
                                }
                                try stack.append(RenderState { .Text = ".."});
                                try stack.append(RenderState { .Expression = range.start});
                                try stack.append(RenderState { .Text = "["});
                                try stack.append(RenderState { .Expression = suffix_op.lhs });
                            },
                            ast.Node.SuffixOp.Op.StructInitializer => |field_inits| {
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
                            ast.Node.SuffixOp.Op.ArrayInitializer => |exprs| {
                                if (exprs.len == 0) {
                                    try stack.append(RenderState { .Text = "{}" });
                                    try stack.append(RenderState { .Expression = suffix_op.lhs });
                                    continue;
                                }
                                if (exprs.len == 1) {
                                    const expr = exprs.at(0);

                                    try stack.append(RenderState { .Text = "}" });
                                    try stack.append(RenderState { .Expression = expr });
                                    try stack.append(RenderState { .Text = " {" });
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
                        const flow_expr = @fieldParentPtr(ast.Node.ControlFlowExpression, "base", base);

                        if (flow_expr.rhs) |rhs| {
                            try stack.append(RenderState { .Expression = rhs });
                            try stack.append(RenderState { .Text = " " });
                        }

                        switch (flow_expr.kind) {
                            ast.Node.ControlFlowExpression.Kind.Break => |maybe_label| {
                                try stream.print("break");
                                if (maybe_label) |label| {
                                    try stream.print(" :");
                                    try stack.append(RenderState { .Expression = label });
                                }
                            },
                            ast.Node.ControlFlowExpression.Kind.Continue => |maybe_label| {
                                try stream.print("continue");
                                if (maybe_label) |label| {
                                    try stream.print(" :");
                                    try stack.append(RenderState { .Expression = label });
                                }
                            },
                            ast.Node.ControlFlowExpression.Kind.Return => {
                                try stream.print("return");
                            },

                        }
                    },
                    ast.Node.Id.Payload => {
                        const payload = @fieldParentPtr(ast.Node.Payload, "base", base);
                        try stack.append(RenderState { .Text = "|"});
                        try stack.append(RenderState { .Expression = payload.error_symbol });
                        try stack.append(RenderState { .Text = "|"});
                    },
                    ast.Node.Id.PointerPayload => {
                        const payload = @fieldParentPtr(ast.Node.PointerPayload, "base", base);
                        try stack.append(RenderState { .Text = "|"});
                        try stack.append(RenderState { .Expression = payload.value_symbol });

                        if (payload.ptr_token) |ptr_token| {
                            try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(ptr_token) });
                        }

                        try stack.append(RenderState { .Text = "|"});
                    },
                    ast.Node.Id.PointerIndexPayload => {
                        const payload = @fieldParentPtr(ast.Node.PointerIndexPayload, "base", base);
                        try stack.append(RenderState { .Text = "|"});

                        if (payload.index_symbol) |index_symbol| {
                            try stack.append(RenderState { .Expression = index_symbol });
                            try stack.append(RenderState { .Text = ", "});
                        }

                        try stack.append(RenderState { .Expression = payload.value_symbol });

                        if (payload.ptr_token) |ptr_token| {
                            try stack.append(RenderState { .Text = self.tokenizer.getTokenSlice(ptr_token) });
                        }

                        try stack.append(RenderState { .Text = "|"});
                    },
                    ast.Node.Id.GroupedExpression => {
                        const grouped_expr = @fieldParentPtr(ast.Node.GroupedExpression, "base", base);
                        try stack.append(RenderState { .Text = ")"});
                        try stack.append(RenderState { .Expression = grouped_expr.expr });
                        try stack.append(RenderState { .Text = "("});
                    },
                    ast.Node.Id.FieldInitializer => {
                        const field_init = @fieldParentPtr(ast.Node.FieldInitializer, "base", base);
                        try stream.print(".{} = ", self.tokenizer.getTokenSlice(field_init.name_token));
                        try stack.append(RenderState { .Expression = field_init.expr });
                    },
                    ast.Node.Id.IntegerLiteral => {
                        const integer_literal = @fieldParentPtr(ast.Node.IntegerLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(integer_literal.token));
                    },
                    ast.Node.Id.FloatLiteral => {
                        const float_literal = @fieldParentPtr(ast.Node.FloatLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(float_literal.token));
                    },
                    ast.Node.Id.StringLiteral => {
                        const string_literal = @fieldParentPtr(ast.Node.StringLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(string_literal.token));
                    },
                    ast.Node.Id.CharLiteral => {
                        const char_literal = @fieldParentPtr(ast.Node.CharLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(char_literal.token));
                    },
                    ast.Node.Id.BoolLiteral => {
                        const bool_literal = @fieldParentPtr(ast.Node.CharLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(bool_literal.token));
                    },
                    ast.Node.Id.NullLiteral => {
                        const null_literal = @fieldParentPtr(ast.Node.NullLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(null_literal.token));
                    },
                    ast.Node.Id.ThisLiteral => {
                        const this_literal = @fieldParentPtr(ast.Node.ThisLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(this_literal.token));
                    },
                    ast.Node.Id.Unreachable => {
                        const unreachable_node = @fieldParentPtr(ast.Node.Unreachable, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(unreachable_node.token));
                    },
                    ast.Node.Id.ErrorType => {
                        const error_type = @fieldParentPtr(ast.Node.ErrorType, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(error_type.token));
                    },
                    ast.Node.Id.VarType => {
                        const var_type = @fieldParentPtr(ast.Node.VarType, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(var_type.token));
                    },
                    ast.Node.Id.ContainerDecl => {
                        const container_decl = @fieldParentPtr(ast.Node.ContainerDecl, "base", base);

                        switch (container_decl.layout) {
                            ast.Node.ContainerDecl.Layout.Packed => try stream.print("packed "),
                            ast.Node.ContainerDecl.Layout.Extern => try stream.print("extern "),
                            ast.Node.ContainerDecl.Layout.Auto => { },
                        }

                        switch (container_decl.kind) {
                            ast.Node.ContainerDecl.Kind.Struct => try stream.print("struct"),
                            ast.Node.ContainerDecl.Kind.Enum => try stream.print("enum"),
                            ast.Node.ContainerDecl.Kind.Union => try stream.print("union"),
                        }

                        const fields_and_decls = container_decl.fields_and_decls.toSliceConst();
                        if (fields_and_decls.len == 0) {
                            try stack.append(RenderState { .Text = "{}"});
                        } else {
                            try stack.append(RenderState { .Text = "}"});
                            try stack.append(RenderState.PrintIndent);
                            try stack.append(RenderState { .Indent = indent });
                            try stack.append(RenderState { .Text = "\n"});

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
                            }
                            try stack.append(RenderState { .Indent = indent + indent_delta});
                            try stack.append(RenderState { .Text = "{"});
                        }

                        switch (container_decl.init_arg_expr) {
                            ast.Node.ContainerDecl.InitArg.None => try stack.append(RenderState { .Text = " "}),
                            ast.Node.ContainerDecl.InitArg.Enum => try stack.append(RenderState { .Text = "(enum) "}),
                            ast.Node.ContainerDecl.InitArg.Type => |type_expr| {
                                try stack.append(RenderState { .Text = ") "});
                                try stack.append(RenderState { .Expression = type_expr});
                                try stack.append(RenderState { .Text = "("});
                            },
                        }
                    },
                    ast.Node.Id.ErrorSetDecl => {
                        const err_set_decl = @fieldParentPtr(ast.Node.ErrorSetDecl, "base", base);
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
                            if (node.id != ast.Node.Id.LineComment) {
                                try stack.append(RenderState { .Text = "," });
                            }
                            try stack.append(RenderState { .Expression = node });
                            try stack.append(RenderState { .PrintComments = node });
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
                        }
                        try stack.append(RenderState { .Indent = indent + indent_delta});
                        try stack.append(RenderState { .Text = "{"});
                    },
                    ast.Node.Id.MultilineStringLiteral => {
                        const multiline_str_literal = @fieldParentPtr(ast.Node.MultilineStringLiteral, "base", base);
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
                        const undefined_literal = @fieldParentPtr(ast.Node.UndefinedLiteral, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(undefined_literal.token));
                    },
                    ast.Node.Id.BuiltinCall => {
                        const builtin_call = @fieldParentPtr(ast.Node.BuiltinCall, "base", base);
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
                        const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", base);

                        switch (fn_proto.return_type) {
                            ast.Node.FnProto.ReturnType.Explicit => |node| {
                                try stack.append(RenderState { .Expression = node});
                            },
                            ast.Node.FnProto.ReturnType.InferErrorSet => |node| {
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
                    ast.Node.Id.LineComment => {
                        const line_comment_node = @fieldParentPtr(ast.Node.LineComment, "base", base);
                        try stream.write(self.tokenizer.getTokenSlice(line_comment_node.token));
                    },
                    ast.Node.Id.DocComment => unreachable, // doc comments are attached to nodes
                    ast.Node.Id.Switch => {
                        const switch_node = @fieldParentPtr(ast.Node.Switch, "base", base);
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
                            try stack.append(RenderState { .Expression = node});
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
                        }
                        try stack.append(RenderState { .Indent = indent + indent_delta});
                        try stack.append(RenderState { .Text = ") {"});
                        try stack.append(RenderState { .Expression = switch_node.expr });
                    },
                    ast.Node.Id.SwitchCase => {
                        const switch_case = @fieldParentPtr(ast.Node.SwitchCase, "base", base);

                        try self.renderComments(stream, base, indent);

                        try stack.append(RenderState { .PrintSameLineComment = base.same_line_comment });
                        try stack.append(RenderState { .Text = "," });
                        try stack.append(RenderState { .Expression = switch_case.expr });
                        if (switch_case.payload) |payload| {
                            try stack.append(RenderState { .Text = " " });
                            try stack.append(RenderState { .Expression = payload });
                        }
                        try stack.append(RenderState { .Text = " => "});

                        const items = switch_case.items.toSliceConst();
                        var i = items.len;
                        while (i != 0) {
                            i -= 1;
                            try stack.append(RenderState { .Expression = items[i] });

                            if (i != 0) {
                                try stack.append(RenderState.PrintIndent);
                                try stack.append(RenderState { .Text = ",\n" });
                            }
                        }
                    },
                    ast.Node.Id.SwitchElse => {
                        const switch_else = @fieldParentPtr(ast.Node.SwitchElse, "base", base);
                        try stream.print("{}", self.tokenizer.getTokenSlice(switch_else.token));
                    },
                    ast.Node.Id.Else => {
                        const else_node = @fieldParentPtr(ast.Node.Else, "base", base);
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
                            try stack.append(RenderState { .Expression = payload });
                        }
                    },
                    ast.Node.Id.While => {
                        const while_node = @fieldParentPtr(ast.Node.While, "base", base);
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
                            try stack.append(RenderState { .Expression = payload });
                            try stack.append(RenderState { .Text = " " });
                        }

                        try stack.append(RenderState { .Text = ")" });
                        try stack.append(RenderState { .Expression = while_node.condition });
                        try stack.append(RenderState { .Text = "(" });
                    },
                    ast.Node.Id.For => {
                        const for_node = @fieldParentPtr(ast.Node.For, "base", base);
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
                            try stack.append(RenderState { .Expression = payload });
                            try stack.append(RenderState { .Text = " " });
                        }

                        try stack.append(RenderState { .Text = ")" });
                        try stack.append(RenderState { .Expression = for_node.array_expr });
                        try stack.append(RenderState { .Text = "(" });
                    },
                    ast.Node.Id.If => {
                        const if_node = @fieldParentPtr(ast.Node.If, "base", base);
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
                                        try stack.append(RenderState { .Expression = payload });
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
                            try stack.append(RenderState { .Expression = payload });
                            try stack.append(RenderState { .Text = " " });
                        }

                        try stack.append(RenderState { .Text = ")" });
                        try stack.append(RenderState { .Expression = if_node.condition });
                        try stack.append(RenderState { .Text = "(" });
                    },
                    ast.Node.Id.Asm => {
                        const asm_node = @fieldParentPtr(ast.Node.Asm, "base", base);
                        try stream.print("{} ", self.tokenizer.getTokenSlice(asm_node.asm_token));

                        if (asm_node.volatile_token) |volatile_token| {
                            try stream.print("{} ", self.tokenizer.getTokenSlice(volatile_token));
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
                        const asm_input = @fieldParentPtr(ast.Node.AsmInput, "base", base);

                        try stack.append(RenderState { .Text = ")"});
                        try stack.append(RenderState { .Expression = asm_input.expr});
                        try stack.append(RenderState { .Text = " ("});
                        try stack.append(RenderState { .Expression = asm_input.constraint });
                        try stack.append(RenderState { .Text = "] "});
                        try stack.append(RenderState { .Expression = asm_input.symbolic_name });
                        try stack.append(RenderState { .Text = "["});
                    },
                    ast.Node.Id.AsmOutput => {
                        const asm_output = @fieldParentPtr(ast.Node.AsmOutput, "base", base);

                        try stack.append(RenderState { .Text = ")"});
                        switch (asm_output.kind) {
                            ast.Node.AsmOutput.Kind.Variable => |variable_name| {
                                try stack.append(RenderState { .Expression = &variable_name.base});
                            },
                            ast.Node.AsmOutput.Kind.Return => |return_type| {
                                try stack.append(RenderState { .Expression = return_type});
                                try stack.append(RenderState { .Text = "-> "});
                            },
                        }
                        try stack.append(RenderState { .Text = " ("});
                        try stack.append(RenderState { .Expression = asm_output.constraint });
                        try stack.append(RenderState { .Text = "] "});
                        try stack.append(RenderState { .Expression = asm_output.symbolic_name });
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
                    try self.renderComments(stream, base, indent);
                    try stack.append(RenderState { .PrintSameLineComment = base.same_line_comment } );
                    switch (base.id) {
                        ast.Node.Id.VarDecl => {
                            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", base);
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
                RenderState.PrintSameLineComment => |maybe_comment| blk: {
                    const comment_token = maybe_comment ?? break :blk;
                    try stream.print(" {}", self.tokenizer.getTokenSlice(comment_token));
                },

                RenderState.PrintComments => |node| blk: {
                    try self.renderComments(stream, node, indent);
                },
            }
        }
    }

    fn renderComments(self: &Parser, stream: var, node: &ast.Node, indent: usize) !void {
        const comment = node.doc_comments ?? return;
        for (comment.lines.toSliceConst()) |line_token| {
            try stream.print("{}\n", self.tokenizer.getTokenSlice(line_token));
            try stream.writeByteNTimes(' ', indent);
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

test "std.zig.parser" {
    _ = @import("parser_test.zig");
}
