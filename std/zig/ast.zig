const std = @import("../index.zig");
const assert = std.debug.assert;
const SegmentedList = std.SegmentedList;
const mem = std.mem;
const Token = std.zig.Token;

pub const TokenIndex = usize;

pub const Tree = struct {
    source: []const u8,
    tokens: TokenList,
    root_node: *Node.Root,
    arena_allocator: std.heap.ArenaAllocator,
    errors: ErrorList,

    pub const TokenList = SegmentedList(Token, 64);
    pub const ErrorList = SegmentedList(Error, 0);

    pub fn deinit(self: *Tree) void {
        self.arena_allocator.deinit();
    }

    pub fn renderError(self: *Tree, parse_error: *Error, stream: var) !void {
        return parse_error.render(&self.tokens, stream);
    }

    pub fn tokenSlice(self: *Tree, token_index: TokenIndex) []const u8 {
        return self.tokenSlicePtr(self.tokens.at(token_index));
    }

    pub fn tokenSlicePtr(self: *Tree, token: *const Token) []const u8 {
        return self.source[token.start..token.end];
    }

    pub const Location = struct {
        line: usize,
        column: usize,
        line_start: usize,
        line_end: usize,
    };

    pub fn tokenLocationPtr(self: *Tree, start_index: usize, token: *const Token) Location {
        var loc = Location{
            .line = 0,
            .column = 0,
            .line_start = start_index,
            .line_end = self.source.len,
        };
        const token_start = token.start;
        for (self.source[start_index..]) |c, i| {
            if (i + start_index == token_start) {
                loc.line_end = i + start_index;
                while (loc.line_end < self.source.len and self.source[loc.line_end] != '\n') : (loc.line_end += 1) {}
                return loc;
            }
            if (c == '\n') {
                loc.line += 1;
                loc.column = 0;
                loc.line_start = i + 1;
            } else {
                loc.column += 1;
            }
        }
        return loc;
    }

    pub fn tokenLocation(self: *Tree, start_index: usize, token_index: TokenIndex) Location {
        return self.tokenLocationPtr(start_index, self.tokens.at(token_index));
    }

    pub fn tokensOnSameLine(self: *Tree, token1_index: TokenIndex, token2_index: TokenIndex) bool {
        return self.tokensOnSameLinePtr(self.tokens.at(token1_index), self.tokens.at(token2_index));
    }

    pub fn tokensOnSameLinePtr(self: *Tree, token1: *const Token, token2: *const Token) bool {
        return mem.indexOfScalar(u8, self.source[token1.end..token2.start], '\n') == null;
    }

    pub fn dump(self: *Tree) void {
        self.root_node.base.dump(0);
    }

    /// Skips over comments
    pub fn prevToken(self: *Tree, token_index: TokenIndex) TokenIndex {
        var index = token_index - 1;
        while (self.tokens.at(index).id == Token.Id.LineComment) {
            index -= 1;
        }
        return index;
    }

    /// Skips over comments
    pub fn nextToken(self: *Tree, token_index: TokenIndex) TokenIndex {
        var index = token_index + 1;
        while (self.tokens.at(index).id == Token.Id.LineComment) {
            index += 1;
        }
        return index;
    }
};

pub const Error = union(enum) {
    InvalidToken: InvalidToken,
    ExpectedVarDeclOrFn: ExpectedVarDeclOrFn,
    ExpectedAggregateKw: ExpectedAggregateKw,
    UnattachedDocComment: UnattachedDocComment,
    ExpectedEqOrSemi: ExpectedEqOrSemi,
    ExpectedSemiOrLBrace: ExpectedSemiOrLBrace,
    ExpectedColonOrRParen: ExpectedColonOrRParen,
    ExpectedLabelable: ExpectedLabelable,
    ExpectedInlinable: ExpectedInlinable,
    ExpectedAsmOutputReturnOrType: ExpectedAsmOutputReturnOrType,
    ExpectedCall: ExpectedCall,
    ExpectedCallOrFnProto: ExpectedCallOrFnProto,
    ExpectedSliceOrRBracket: ExpectedSliceOrRBracket,
    ExtraAlignQualifier: ExtraAlignQualifier,
    ExtraConstQualifier: ExtraConstQualifier,
    ExtraVolatileQualifier: ExtraVolatileQualifier,
    ExpectedPrimaryExpr: ExpectedPrimaryExpr,
    ExpectedToken: ExpectedToken,
    ExpectedCommaOrEnd: ExpectedCommaOrEnd,

    pub fn render(self: *const Error, tokens: *Tree.TokenList, stream: var) !void {
        switch (self.*) {
            // TODO https://github.com/ziglang/zig/issues/683
            @TagType(Error).InvalidToken => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedVarDeclOrFn => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedAggregateKw => |*x| return x.render(tokens, stream),
            @TagType(Error).UnattachedDocComment => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedEqOrSemi => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedSemiOrLBrace => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedColonOrRParen => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedLabelable => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedInlinable => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedAsmOutputReturnOrType => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedCall => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedCallOrFnProto => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedSliceOrRBracket => |*x| return x.render(tokens, stream),
            @TagType(Error).ExtraAlignQualifier => |*x| return x.render(tokens, stream),
            @TagType(Error).ExtraConstQualifier => |*x| return x.render(tokens, stream),
            @TagType(Error).ExtraVolatileQualifier => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedPrimaryExpr => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedToken => |*x| return x.render(tokens, stream),
            @TagType(Error).ExpectedCommaOrEnd => |*x| return x.render(tokens, stream),
        }
    }

    pub fn loc(self: *const Error) TokenIndex {
        switch (self.*) {
            // TODO https://github.com/ziglang/zig/issues/683
            @TagType(Error).InvalidToken => |x| return x.token,
            @TagType(Error).ExpectedVarDeclOrFn => |x| return x.token,
            @TagType(Error).ExpectedAggregateKw => |x| return x.token,
            @TagType(Error).UnattachedDocComment => |x| return x.token,
            @TagType(Error).ExpectedEqOrSemi => |x| return x.token,
            @TagType(Error).ExpectedSemiOrLBrace => |x| return x.token,
            @TagType(Error).ExpectedColonOrRParen => |x| return x.token,
            @TagType(Error).ExpectedLabelable => |x| return x.token,
            @TagType(Error).ExpectedInlinable => |x| return x.token,
            @TagType(Error).ExpectedAsmOutputReturnOrType => |x| return x.token,
            @TagType(Error).ExpectedCall => |x| return x.node.firstToken(),
            @TagType(Error).ExpectedCallOrFnProto => |x| return x.node.firstToken(),
            @TagType(Error).ExpectedSliceOrRBracket => |x| return x.token,
            @TagType(Error).ExtraAlignQualifier => |x| return x.token,
            @TagType(Error).ExtraConstQualifier => |x| return x.token,
            @TagType(Error).ExtraVolatileQualifier => |x| return x.token,
            @TagType(Error).ExpectedPrimaryExpr => |x| return x.token,
            @TagType(Error).ExpectedToken => |x| return x.token,
            @TagType(Error).ExpectedCommaOrEnd => |x| return x.token,
        }
    }

    pub const InvalidToken = SingleTokenError("Invalid token {}");
    pub const ExpectedVarDeclOrFn = SingleTokenError("Expected variable declaration or function, found {}");
    pub const ExpectedAggregateKw = SingleTokenError("Expected " ++ @tagName(Token.Id.Keyword_struct) ++ ", " ++ @tagName(Token.Id.Keyword_union) ++ ", or " ++ @tagName(Token.Id.Keyword_enum) ++ ", found {}");
    pub const ExpectedEqOrSemi = SingleTokenError("Expected '=' or ';', found {}");
    pub const ExpectedSemiOrLBrace = SingleTokenError("Expected ';' or '{{', found {}");
    pub const ExpectedColonOrRParen = SingleTokenError("Expected ':' or ')', found {}");
    pub const ExpectedLabelable = SingleTokenError("Expected 'while', 'for', 'inline', 'suspend', or '{{', found {}");
    pub const ExpectedInlinable = SingleTokenError("Expected 'while' or 'for', found {}");
    pub const ExpectedAsmOutputReturnOrType = SingleTokenError("Expected '->' or " ++ @tagName(Token.Id.Identifier) ++ ", found {}");
    pub const ExpectedSliceOrRBracket = SingleTokenError("Expected ']' or '..', found {}");
    pub const ExpectedPrimaryExpr = SingleTokenError("Expected primary expression, found {}");

    pub const UnattachedDocComment = SimpleError("Unattached documentation comment");
    pub const ExtraAlignQualifier = SimpleError("Extra align qualifier");
    pub const ExtraConstQualifier = SimpleError("Extra const qualifier");
    pub const ExtraVolatileQualifier = SimpleError("Extra volatile qualifier");

    pub const ExpectedCall = struct {
        node: *Node,

        pub fn render(self: *const ExpectedCall, tokens: *Tree.TokenList, stream: var) !void {
            return stream.print("expected " ++ @tagName(@TagType(Node.SuffixOp.Op).Call) ++ ", found {}", @tagName(self.node.id));
        }
    };

    pub const ExpectedCallOrFnProto = struct {
        node: *Node,

        pub fn render(self: *const ExpectedCallOrFnProto, tokens: *Tree.TokenList, stream: var) !void {
            return stream.print("expected " ++ @tagName(@TagType(Node.SuffixOp.Op).Call) ++ " or " ++ @tagName(Node.Id.FnProto) ++ ", found {}", @tagName(self.node.id));
        }
    };

    pub const ExpectedToken = struct {
        token: TokenIndex,
        expected_id: @TagType(Token.Id),

        pub fn render(self: *const ExpectedToken, tokens: *Tree.TokenList, stream: var) !void {
            const token_name = @tagName(tokens.at(self.token).id);
            return stream.print("expected {}, found {}", @tagName(self.expected_id), token_name);
        }
    };

    pub const ExpectedCommaOrEnd = struct {
        token: TokenIndex,
        end_id: @TagType(Token.Id),

        pub fn render(self: *const ExpectedCommaOrEnd, tokens: *Tree.TokenList, stream: var) !void {
            const token_name = @tagName(tokens.at(self.token).id);
            return stream.print("expected ',' or {}, found {}", @tagName(self.end_id), token_name);
        }
    };

    fn SingleTokenError(comptime msg: []const u8) type {
        return struct {
            const ThisError = this;

            token: TokenIndex,

            pub fn render(self: *const ThisError, tokens: *Tree.TokenList, stream: var) !void {
                const token_name = @tagName(tokens.at(self.token).id);
                return stream.print(msg, token_name);
            }
        };
    }

    fn SimpleError(comptime msg: []const u8) type {
        return struct {
            const ThisError = this;

            token: TokenIndex,

            pub fn render(self: *const ThisError, tokens: *Tree.TokenList, stream: var) !void {
                return stream.write(msg);
            }
        };
    }
};

pub const Node = struct {
    id: Id,

    pub const Id = enum {
        // Top level
        Root,
        Use,
        TestDecl,

        // Statements
        VarDecl,
        Defer,

        // Operators
        InfixOp,
        PrefixOp,
        SuffixOp,

        // Control flow
        Switch,
        While,
        For,
        If,
        ControlFlowExpression,
        Suspend,

        // Type expressions
        VarType,
        ErrorType,
        FnProto,
        PromiseType,

        // Primary expressions
        IntegerLiteral,
        FloatLiteral,
        StringLiteral,
        MultilineStringLiteral,
        CharLiteral,
        BoolLiteral,
        NullLiteral,
        UndefinedLiteral,
        ThisLiteral,
        Unreachable,
        Identifier,
        GroupedExpression,
        BuiltinCall,
        ErrorSetDecl,
        ContainerDecl,
        Asm,
        Comptime,
        Block,

        // Misc
        DocComment,
        SwitchCase,
        SwitchElse,
        Else,
        Payload,
        PointerPayload,
        PointerIndexPayload,
        StructField,
        UnionTag,
        EnumTag,
        ErrorTag,
        AsmInput,
        AsmOutput,
        AsyncAttribute,
        ParamDecl,
        FieldInitializer,
    };

    pub fn cast(base: *Node, comptime T: type) ?*T {
        if (base.id == comptime typeToId(T)) {
            return @fieldParentPtr(T, "base", base);
        }
        return null;
    }

    pub fn iterate(base: *Node, index: usize) ?*Node {
        comptime var i = 0;
        inline while (i < @memberCount(Id)) : (i += 1) {
            if (base.id == @field(Id, @memberName(Id, i))) {
                const T = @field(Node, @memberName(Id, i));
                return @fieldParentPtr(T, "base", base).iterate(index);
            }
        }
        unreachable;
    }

    pub fn firstToken(base: *Node) TokenIndex {
        comptime var i = 0;
        inline while (i < @memberCount(Id)) : (i += 1) {
            if (base.id == @field(Id, @memberName(Id, i))) {
                const T = @field(Node, @memberName(Id, i));
                return @fieldParentPtr(T, "base", base).firstToken();
            }
        }
        unreachable;
    }

    pub fn lastToken(base: *Node) TokenIndex {
        comptime var i = 0;
        inline while (i < @memberCount(Id)) : (i += 1) {
            if (base.id == @field(Id, @memberName(Id, i))) {
                const T = @field(Node, @memberName(Id, i));
                return @fieldParentPtr(T, "base", base).lastToken();
            }
        }
        unreachable;
    }

    pub fn typeToId(comptime T: type) Id {
        comptime var i = 0;
        inline while (i < @memberCount(Id)) : (i += 1) {
            if (T == @field(Node, @memberName(Id, i))) {
                return @field(Id, @memberName(Id, i));
            }
        }
        unreachable;
    }

    pub fn requireSemiColon(base: *const Node) bool {
        var n = base;
        while (true) {
            switch (n.id) {
                Id.Root,
                Id.StructField,
                Id.UnionTag,
                Id.EnumTag,
                Id.ParamDecl,
                Id.Block,
                Id.Payload,
                Id.PointerPayload,
                Id.PointerIndexPayload,
                Id.Switch,
                Id.SwitchCase,
                Id.SwitchElse,
                Id.FieldInitializer,
                Id.DocComment,
                Id.TestDecl,
                => return false,
                Id.While => {
                    const while_node = @fieldParentPtr(While, "base", n);
                    if (while_node.@"else") |@"else"| {
                        n = @"else".base;
                        continue;
                    }

                    return while_node.body.id != Id.Block;
                },
                Id.For => {
                    const for_node = @fieldParentPtr(For, "base", n);
                    if (for_node.@"else") |@"else"| {
                        n = @"else".base;
                        continue;
                    }

                    return for_node.body.id != Id.Block;
                },
                Id.If => {
                    const if_node = @fieldParentPtr(If, "base", n);
                    if (if_node.@"else") |@"else"| {
                        n = @"else".base;
                        continue;
                    }

                    return if_node.body.id != Id.Block;
                },
                Id.Else => {
                    const else_node = @fieldParentPtr(Else, "base", n);
                    n = else_node.body;
                    continue;
                },
                Id.Defer => {
                    const defer_node = @fieldParentPtr(Defer, "base", n);
                    return defer_node.expr.id != Id.Block;
                },
                Id.Comptime => {
                    const comptime_node = @fieldParentPtr(Comptime, "base", n);
                    return comptime_node.expr.id != Id.Block;
                },
                Id.Suspend => {
                    const suspend_node = @fieldParentPtr(Suspend, "base", n);
                    if (suspend_node.body) |body| {
                        return body.id != Id.Block;
                    }

                    return true;
                },
                else => return true,
            }
        }
    }

    pub fn dump(self: *Node, indent: usize) void {
        {
            var i: usize = 0;
            while (i < indent) : (i += 1) {
                std.debug.warn(" ");
            }
        }
        std.debug.warn("{}\n", @tagName(self.id));

        var child_i: usize = 0;
        while (self.iterate(child_i)) |child| : (child_i += 1) {
            child.dump(indent + 2);
        }
    }

    pub const Root = struct {
        base: Node,
        doc_comments: ?*DocComment,
        decls: DeclList,
        eof_token: TokenIndex,

        pub const DeclList = SegmentedList(*Node, 4);

        pub fn iterate(self: *Root, index: usize) ?*Node {
            if (index < self.decls.len) {
                return self.decls.at(index).*;
            }
            return null;
        }

        pub fn firstToken(self: *Root) TokenIndex {
            return if (self.decls.len == 0) self.eof_token else (self.decls.at(0).*).firstToken();
        }

        pub fn lastToken(self: *Root) TokenIndex {
            return if (self.decls.len == 0) self.eof_token else (self.decls.at(self.decls.len - 1).*).lastToken();
        }
    };

    pub const VarDecl = struct {
        base: Node,
        doc_comments: ?*DocComment,
        visib_token: ?TokenIndex,
        name_token: TokenIndex,
        eq_token: TokenIndex,
        mut_token: TokenIndex,
        comptime_token: ?TokenIndex,
        extern_export_token: ?TokenIndex,
        lib_name: ?*Node,
        type_node: ?*Node,
        align_node: ?*Node,
        init_node: ?*Node,
        semicolon_token: TokenIndex,

        pub fn iterate(self: *VarDecl, index: usize) ?*Node {
            var i = index;

            if (self.type_node) |type_node| {
                if (i < 1) return type_node;
                i -= 1;
            }

            if (self.align_node) |align_node| {
                if (i < 1) return align_node;
                i -= 1;
            }

            if (self.init_node) |init_node| {
                if (i < 1) return init_node;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *VarDecl) TokenIndex {
            if (self.visib_token) |visib_token| return visib_token;
            if (self.comptime_token) |comptime_token| return comptime_token;
            if (self.extern_export_token) |extern_export_token| return extern_export_token;
            assert(self.lib_name == null);
            return self.mut_token;
        }

        pub fn lastToken(self: *VarDecl) TokenIndex {
            return self.semicolon_token;
        }
    };

    pub const Use = struct {
        base: Node,
        doc_comments: ?*DocComment,
        visib_token: ?TokenIndex,
        use_token: TokenIndex,
        expr: *Node,
        semicolon_token: TokenIndex,

        pub fn iterate(self: *Use, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *Use) TokenIndex {
            if (self.visib_token) |visib_token| return visib_token;
            return self.use_token;
        }

        pub fn lastToken(self: *Use) TokenIndex {
            return self.semicolon_token;
        }
    };

    pub const ErrorSetDecl = struct {
        base: Node,
        error_token: TokenIndex,
        decls: DeclList,
        rbrace_token: TokenIndex,

        pub const DeclList = SegmentedList(*Node, 2);

        pub fn iterate(self: *ErrorSetDecl, index: usize) ?*Node {
            var i = index;

            if (i < self.decls.len) return self.decls.at(i).*;
            i -= self.decls.len;

            return null;
        }

        pub fn firstToken(self: *ErrorSetDecl) TokenIndex {
            return self.error_token;
        }

        pub fn lastToken(self: *ErrorSetDecl) TokenIndex {
            return self.rbrace_token;
        }
    };

    pub const ContainerDecl = struct {
        base: Node,
        layout_token: ?TokenIndex,
        kind_token: TokenIndex,
        init_arg_expr: InitArg,
        fields_and_decls: DeclList,
        lbrace_token: TokenIndex,
        rbrace_token: TokenIndex,

        pub const DeclList = Root.DeclList;

        const InitArg = union(enum) {
            None,
            Enum: ?*Node,
            Type: *Node,
        };

        pub fn iterate(self: *ContainerDecl, index: usize) ?*Node {
            var i = index;

            switch (self.init_arg_expr) {
                InitArg.Type => |t| {
                    if (i < 1) return t;
                    i -= 1;
                },
                InitArg.None, InitArg.Enum => {},
            }

            if (i < self.fields_and_decls.len) return self.fields_and_decls.at(i).*;
            i -= self.fields_and_decls.len;

            return null;
        }

        pub fn firstToken(self: *ContainerDecl) TokenIndex {
            if (self.layout_token) |layout_token| {
                return layout_token;
            }
            return self.kind_token;
        }

        pub fn lastToken(self: *ContainerDecl) TokenIndex {
            return self.rbrace_token;
        }
    };

    pub const StructField = struct {
        base: Node,
        doc_comments: ?*DocComment,
        visib_token: ?TokenIndex,
        name_token: TokenIndex,
        type_expr: *Node,

        pub fn iterate(self: *StructField, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.type_expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *StructField) TokenIndex {
            if (self.visib_token) |visib_token| return visib_token;
            return self.name_token;
        }

        pub fn lastToken(self: *StructField) TokenIndex {
            return self.type_expr.lastToken();
        }
    };

    pub const UnionTag = struct {
        base: Node,
        doc_comments: ?*DocComment,
        name_token: TokenIndex,
        type_expr: ?*Node,
        value_expr: ?*Node,

        pub fn iterate(self: *UnionTag, index: usize) ?*Node {
            var i = index;

            if (self.type_expr) |type_expr| {
                if (i < 1) return type_expr;
                i -= 1;
            }

            if (self.value_expr) |value_expr| {
                if (i < 1) return value_expr;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *UnionTag) TokenIndex {
            return self.name_token;
        }

        pub fn lastToken(self: *UnionTag) TokenIndex {
            if (self.value_expr) |value_expr| {
                return value_expr.lastToken();
            }
            if (self.type_expr) |type_expr| {
                return type_expr.lastToken();
            }

            return self.name_token;
        }
    };

    pub const EnumTag = struct {
        base: Node,
        doc_comments: ?*DocComment,
        name_token: TokenIndex,
        value: ?*Node,

        pub fn iterate(self: *EnumTag, index: usize) ?*Node {
            var i = index;

            if (self.value) |value| {
                if (i < 1) return value;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *EnumTag) TokenIndex {
            return self.name_token;
        }

        pub fn lastToken(self: *EnumTag) TokenIndex {
            if (self.value) |value| {
                return value.lastToken();
            }

            return self.name_token;
        }
    };

    pub const ErrorTag = struct {
        base: Node,
        doc_comments: ?*DocComment,
        name_token: TokenIndex,

        pub fn iterate(self: *ErrorTag, index: usize) ?*Node {
            var i = index;

            if (self.doc_comments) |comments| {
                if (i < 1) return &comments.base;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *ErrorTag) TokenIndex {
            return self.name_token;
        }

        pub fn lastToken(self: *ErrorTag) TokenIndex {
            return self.name_token;
        }
    };

    pub const Identifier = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *Identifier, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *Identifier) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *Identifier) TokenIndex {
            return self.token;
        }
    };

    pub const AsyncAttribute = struct {
        base: Node,
        async_token: TokenIndex,
        allocator_type: ?*Node,
        rangle_bracket: ?TokenIndex,

        pub fn iterate(self: *AsyncAttribute, index: usize) ?*Node {
            var i = index;

            if (self.allocator_type) |allocator_type| {
                if (i < 1) return allocator_type;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *AsyncAttribute) TokenIndex {
            return self.async_token;
        }

        pub fn lastToken(self: *AsyncAttribute) TokenIndex {
            if (self.rangle_bracket) |rangle_bracket| {
                return rangle_bracket;
            }

            return self.async_token;
        }
    };

    pub const FnProto = struct {
        base: Node,
        doc_comments: ?*DocComment,
        visib_token: ?TokenIndex,
        fn_token: TokenIndex,
        name_token: ?TokenIndex,
        params: ParamList,
        return_type: ReturnType,
        var_args_token: ?TokenIndex,
        extern_export_inline_token: ?TokenIndex,
        cc_token: ?TokenIndex,
        async_attr: ?*AsyncAttribute,
        body_node: ?*Node,
        lib_name: ?*Node, // populated if this is an extern declaration
        align_expr: ?*Node, // populated if align(A) is present

        pub const ParamList = SegmentedList(*Node, 2);

        pub const ReturnType = union(enum) {
            Explicit: *Node,
            InferErrorSet: *Node,
        };

        pub fn iterate(self: *FnProto, index: usize) ?*Node {
            var i = index;

            if (self.lib_name) |lib_name| {
                if (i < 1) return lib_name;
                i -= 1;
            }

            if (i < self.params.len) return self.params.at(self.params.len - i - 1).*;
            i -= self.params.len;

            if (self.align_expr) |align_expr| {
                if (i < 1) return align_expr;
                i -= 1;
            }

            switch (self.return_type) {
                // TODO allow this and next prong to share bodies since the types are the same
                ReturnType.Explicit => |node| {
                    if (i < 1) return node;
                    i -= 1;
                },
                ReturnType.InferErrorSet => |node| {
                    if (i < 1) return node;
                    i -= 1;
                },
            }

            if (self.body_node) |body_node| {
                if (i < 1) return body_node;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *FnProto) TokenIndex {
            if (self.visib_token) |visib_token| return visib_token;
            if (self.async_attr) |async_attr| return async_attr.firstToken();
            if (self.extern_export_inline_token) |extern_export_inline_token| return extern_export_inline_token;
            assert(self.lib_name == null);
            if (self.cc_token) |cc_token| return cc_token;
            return self.fn_token;
        }

        pub fn lastToken(self: *FnProto) TokenIndex {
            if (self.body_node) |body_node| return body_node.lastToken();
            switch (self.return_type) {
                // TODO allow this and next prong to share bodies since the types are the same
                ReturnType.Explicit => |node| return node.lastToken(),
                ReturnType.InferErrorSet => |node| return node.lastToken(),
            }
        }
    };

    pub const PromiseType = struct {
        base: Node,
        promise_token: TokenIndex,
        result: ?Result,

        pub const Result = struct {
            arrow_token: TokenIndex,
            return_type: *Node,
        };

        pub fn iterate(self: *PromiseType, index: usize) ?*Node {
            var i = index;

            if (self.result) |result| {
                if (i < 1) return result.return_type;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *PromiseType) TokenIndex {
            return self.promise_token;
        }

        pub fn lastToken(self: *PromiseType) TokenIndex {
            if (self.result) |result| return result.return_type.lastToken();
            return self.promise_token;
        }
    };

    pub const ParamDecl = struct {
        base: Node,
        comptime_token: ?TokenIndex,
        noalias_token: ?TokenIndex,
        name_token: ?TokenIndex,
        type_node: *Node,
        var_args_token: ?TokenIndex,

        pub fn iterate(self: *ParamDecl, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.type_node;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *ParamDecl) TokenIndex {
            if (self.comptime_token) |comptime_token| return comptime_token;
            if (self.noalias_token) |noalias_token| return noalias_token;
            if (self.name_token) |name_token| return name_token;
            return self.type_node.firstToken();
        }

        pub fn lastToken(self: *ParamDecl) TokenIndex {
            if (self.var_args_token) |var_args_token| return var_args_token;
            return self.type_node.lastToken();
        }
    };

    pub const Block = struct {
        base: Node,
        label: ?TokenIndex,
        lbrace: TokenIndex,
        statements: StatementList,
        rbrace: TokenIndex,

        pub const StatementList = Root.DeclList;

        pub fn iterate(self: *Block, index: usize) ?*Node {
            var i = index;

            if (i < self.statements.len) return self.statements.at(i).*;
            i -= self.statements.len;

            return null;
        }

        pub fn firstToken(self: *Block) TokenIndex {
            if (self.label) |label| {
                return label;
            }

            return self.lbrace;
        }

        pub fn lastToken(self: *Block) TokenIndex {
            return self.rbrace;
        }
    };

    pub const Defer = struct {
        base: Node,
        defer_token: TokenIndex,
        kind: Kind,
        expr: *Node,

        const Kind = enum {
            Error,
            Unconditional,
        };

        pub fn iterate(self: *Defer, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *Defer) TokenIndex {
            return self.defer_token;
        }

        pub fn lastToken(self: *Defer) TokenIndex {
            return self.expr.lastToken();
        }
    };

    pub const Comptime = struct {
        base: Node,
        doc_comments: ?*DocComment,
        comptime_token: TokenIndex,
        expr: *Node,

        pub fn iterate(self: *Comptime, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *Comptime) TokenIndex {
            return self.comptime_token;
        }

        pub fn lastToken(self: *Comptime) TokenIndex {
            return self.expr.lastToken();
        }
    };

    pub const Payload = struct {
        base: Node,
        lpipe: TokenIndex,
        error_symbol: *Node,
        rpipe: TokenIndex,

        pub fn iterate(self: *Payload, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.error_symbol;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *Payload) TokenIndex {
            return self.lpipe;
        }

        pub fn lastToken(self: *Payload) TokenIndex {
            return self.rpipe;
        }
    };

    pub const PointerPayload = struct {
        base: Node,
        lpipe: TokenIndex,
        ptr_token: ?TokenIndex,
        value_symbol: *Node,
        rpipe: TokenIndex,

        pub fn iterate(self: *PointerPayload, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.value_symbol;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *PointerPayload) TokenIndex {
            return self.lpipe;
        }

        pub fn lastToken(self: *PointerPayload) TokenIndex {
            return self.rpipe;
        }
    };

    pub const PointerIndexPayload = struct {
        base: Node,
        lpipe: TokenIndex,
        ptr_token: ?TokenIndex,
        value_symbol: *Node,
        index_symbol: ?*Node,
        rpipe: TokenIndex,

        pub fn iterate(self: *PointerIndexPayload, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.value_symbol;
            i -= 1;

            if (self.index_symbol) |index_symbol| {
                if (i < 1) return index_symbol;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *PointerIndexPayload) TokenIndex {
            return self.lpipe;
        }

        pub fn lastToken(self: *PointerIndexPayload) TokenIndex {
            return self.rpipe;
        }
    };

    pub const Else = struct {
        base: Node,
        else_token: TokenIndex,
        payload: ?*Node,
        body: *Node,

        pub fn iterate(self: *Else, index: usize) ?*Node {
            var i = index;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (i < 1) return self.body;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *Else) TokenIndex {
            return self.else_token;
        }

        pub fn lastToken(self: *Else) TokenIndex {
            return self.body.lastToken();
        }
    };

    pub const Switch = struct {
        base: Node,
        switch_token: TokenIndex,
        expr: *Node,

        /// these must be SwitchCase nodes
        cases: CaseList,
        rbrace: TokenIndex,

        pub const CaseList = SegmentedList(*Node, 2);

        pub fn iterate(self: *Switch, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            if (i < self.cases.len) return self.cases.at(i).*;
            i -= self.cases.len;

            return null;
        }

        pub fn firstToken(self: *Switch) TokenIndex {
            return self.switch_token;
        }

        pub fn lastToken(self: *Switch) TokenIndex {
            return self.rbrace;
        }
    };

    pub const SwitchCase = struct {
        base: Node,
        items: ItemList,
        arrow_token: TokenIndex,
        payload: ?*Node,
        expr: *Node,

        pub const ItemList = SegmentedList(*Node, 1);

        pub fn iterate(self: *SwitchCase, index: usize) ?*Node {
            var i = index;

            if (i < self.items.len) return self.items.at(i).*;
            i -= self.items.len;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *SwitchCase) TokenIndex {
            return (self.items.at(0).*).firstToken();
        }

        pub fn lastToken(self: *SwitchCase) TokenIndex {
            return self.expr.lastToken();
        }
    };

    pub const SwitchElse = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *SwitchElse, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *SwitchElse) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *SwitchElse) TokenIndex {
            return self.token;
        }
    };

    pub const While = struct {
        base: Node,
        label: ?TokenIndex,
        inline_token: ?TokenIndex,
        while_token: TokenIndex,
        condition: *Node,
        payload: ?*Node,
        continue_expr: ?*Node,
        body: *Node,
        @"else": ?*Else,

        pub fn iterate(self: *While, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.condition;
            i -= 1;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (self.continue_expr) |continue_expr| {
                if (i < 1) return continue_expr;
                i -= 1;
            }

            if (i < 1) return self.body;
            i -= 1;

            if (self.@"else") |@"else"| {
                if (i < 1) return &@"else".base;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *While) TokenIndex {
            if (self.label) |label| {
                return label;
            }

            if (self.inline_token) |inline_token| {
                return inline_token;
            }

            return self.while_token;
        }

        pub fn lastToken(self: *While) TokenIndex {
            if (self.@"else") |@"else"| {
                return @"else".body.lastToken();
            }

            return self.body.lastToken();
        }
    };

    pub const For = struct {
        base: Node,
        label: ?TokenIndex,
        inline_token: ?TokenIndex,
        for_token: TokenIndex,
        array_expr: *Node,
        payload: ?*Node,
        body: *Node,
        @"else": ?*Else,

        pub fn iterate(self: *For, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.array_expr;
            i -= 1;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (i < 1) return self.body;
            i -= 1;

            if (self.@"else") |@"else"| {
                if (i < 1) return &@"else".base;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *For) TokenIndex {
            if (self.label) |label| {
                return label;
            }

            if (self.inline_token) |inline_token| {
                return inline_token;
            }

            return self.for_token;
        }

        pub fn lastToken(self: *For) TokenIndex {
            if (self.@"else") |@"else"| {
                return @"else".body.lastToken();
            }

            return self.body.lastToken();
        }
    };

    pub const If = struct {
        base: Node,
        if_token: TokenIndex,
        condition: *Node,
        payload: ?*Node,
        body: *Node,
        @"else": ?*Else,

        pub fn iterate(self: *If, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.condition;
            i -= 1;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (i < 1) return self.body;
            i -= 1;

            if (self.@"else") |@"else"| {
                if (i < 1) return &@"else".base;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *If) TokenIndex {
            return self.if_token;
        }

        pub fn lastToken(self: *If) TokenIndex {
            if (self.@"else") |@"else"| {
                return @"else".body.lastToken();
            }

            return self.body.lastToken();
        }
    };

    pub const InfixOp = struct {
        base: Node,
        op_token: TokenIndex,
        lhs: *Node,
        op: Op,
        rhs: *Node,

        pub const Op = union(enum) {
            Add,
            AddWrap,
            ArrayCat,
            ArrayMult,
            Assign,
            AssignBitAnd,
            AssignBitOr,
            AssignBitShiftLeft,
            AssignBitShiftRight,
            AssignBitXor,
            AssignDiv,
            AssignMinus,
            AssignMinusWrap,
            AssignMod,
            AssignPlus,
            AssignPlusWrap,
            AssignTimes,
            AssignTimesWarp,
            BangEqual,
            BitAnd,
            BitOr,
            BitShiftLeft,
            BitShiftRight,
            BitXor,
            BoolAnd,
            BoolOr,
            Catch: ?*Node,
            Div,
            EqualEqual,
            ErrorUnion,
            GreaterOrEqual,
            GreaterThan,
            LessOrEqual,
            LessThan,
            MergeErrorSets,
            Mod,
            Mult,
            MultWrap,
            Period,
            Range,
            Sub,
            SubWrap,
            UnwrapOptional,
        };

        pub fn iterate(self: *InfixOp, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            switch (self.op) {
                Op.Catch => |maybe_payload| {
                    if (maybe_payload) |payload| {
                        if (i < 1) return payload;
                        i -= 1;
                    }
                },

                Op.Add,
                Op.AddWrap,
                Op.ArrayCat,
                Op.ArrayMult,
                Op.Assign,
                Op.AssignBitAnd,
                Op.AssignBitOr,
                Op.AssignBitShiftLeft,
                Op.AssignBitShiftRight,
                Op.AssignBitXor,
                Op.AssignDiv,
                Op.AssignMinus,
                Op.AssignMinusWrap,
                Op.AssignMod,
                Op.AssignPlus,
                Op.AssignPlusWrap,
                Op.AssignTimes,
                Op.AssignTimesWarp,
                Op.BangEqual,
                Op.BitAnd,
                Op.BitOr,
                Op.BitShiftLeft,
                Op.BitShiftRight,
                Op.BitXor,
                Op.BoolAnd,
                Op.BoolOr,
                Op.Div,
                Op.EqualEqual,
                Op.ErrorUnion,
                Op.GreaterOrEqual,
                Op.GreaterThan,
                Op.LessOrEqual,
                Op.LessThan,
                Op.MergeErrorSets,
                Op.Mod,
                Op.Mult,
                Op.MultWrap,
                Op.Period,
                Op.Range,
                Op.Sub,
                Op.SubWrap,
                Op.UnwrapOptional,
                => {},
            }

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *InfixOp) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *InfixOp) TokenIndex {
            return self.rhs.lastToken();
        }
    };

    pub const PrefixOp = struct {
        base: Node,
        op_token: TokenIndex,
        op: Op,
        rhs: *Node,

        pub const Op = union(enum) {
            AddressOf,
            ArrayType: *Node,
            Await,
            BitNot,
            BoolNot,
            Cancel,
            OptionalType,
            Negation,
            NegationWrap,
            Resume,
            PtrType: PtrInfo,
            SliceType: PtrInfo,
            Try,
        };

        pub const PtrInfo = struct {
            align_info: ?Align,
            const_token: ?TokenIndex,
            volatile_token: ?TokenIndex,

            pub const Align = struct {
                node: *Node,
                bit_range: ?BitRange,

                pub const BitRange = struct {
                    start: *Node,
                    end: *Node,
                };
            };
        };

        pub fn iterate(self: *PrefixOp, index: usize) ?*Node {
            var i = index;

            switch (self.op) {
                // TODO https://github.com/ziglang/zig/issues/1107
                Op.SliceType => |addr_of_info| {
                    if (addr_of_info.align_info) |align_info| {
                        if (i < 1) return align_info.node;
                        i -= 1;
                    }
                },

                Op.PtrType => |addr_of_info| {
                    if (addr_of_info.align_info) |align_info| {
                        if (i < 1) return align_info.node;
                        i -= 1;
                    }
                },

                Op.ArrayType => |size_expr| {
                    if (i < 1) return size_expr;
                    i -= 1;
                },

                Op.AddressOf,
                Op.Await,
                Op.BitNot,
                Op.BoolNot,
                Op.Cancel,
                Op.OptionalType,
                Op.Negation,
                Op.NegationWrap,
                Op.Try,
                Op.Resume,
                => {},
            }

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *PrefixOp) TokenIndex {
            return self.op_token;
        }

        pub fn lastToken(self: *PrefixOp) TokenIndex {
            return self.rhs.lastToken();
        }
    };

    pub const FieldInitializer = struct {
        base: Node,
        period_token: TokenIndex,
        name_token: TokenIndex,
        expr: *Node,

        pub fn iterate(self: *FieldInitializer, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *FieldInitializer) TokenIndex {
            return self.period_token;
        }

        pub fn lastToken(self: *FieldInitializer) TokenIndex {
            return self.expr.lastToken();
        }
    };

    pub const SuffixOp = struct {
        base: Node,
        lhs: *Node,
        op: Op,
        rtoken: TokenIndex,

        pub const Op = union(enum) {
            Call: Call,
            ArrayAccess: *Node,
            Slice: Slice,
            ArrayInitializer: InitList,
            StructInitializer: InitList,
            Deref,
            UnwrapOptional,

            pub const InitList = SegmentedList(*Node, 2);

            pub const Call = struct {
                params: ParamList,
                async_attr: ?*AsyncAttribute,

                pub const ParamList = SegmentedList(*Node, 2);
            };

            pub const Slice = struct {
                start: *Node,
                end: ?*Node,
            };
        };

        pub fn iterate(self: *SuffixOp, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            switch (self.op) {
                @TagType(Op).Call => |*call_info| {
                    if (i < call_info.params.len) return call_info.params.at(i).*;
                    i -= call_info.params.len;
                },
                Op.ArrayAccess => |index_expr| {
                    if (i < 1) return index_expr;
                    i -= 1;
                },
                @TagType(Op).Slice => |range| {
                    if (i < 1) return range.start;
                    i -= 1;

                    if (range.end) |end| {
                        if (i < 1) return end;
                        i -= 1;
                    }
                },
                Op.ArrayInitializer => |*exprs| {
                    if (i < exprs.len) return exprs.at(i).*;
                    i -= exprs.len;
                },
                Op.StructInitializer => |*fields| {
                    if (i < fields.len) return fields.at(i).*;
                    i -= fields.len;
                },
                Op.UnwrapOptional,
                Op.Deref,
                => {},
            }

            return null;
        }

        pub fn firstToken(self: *SuffixOp) TokenIndex {
            switch (self.op) {
                @TagType(Op).Call => |*call_info| if (call_info.async_attr) |async_attr| return async_attr.firstToken(),
                else => {},
            }
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *SuffixOp) TokenIndex {
            return self.rtoken;
        }
    };

    pub const GroupedExpression = struct {
        base: Node,
        lparen: TokenIndex,
        expr: *Node,
        rparen: TokenIndex,

        pub fn iterate(self: *GroupedExpression, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *GroupedExpression) TokenIndex {
            return self.lparen;
        }

        pub fn lastToken(self: *GroupedExpression) TokenIndex {
            return self.rparen;
        }
    };

    pub const ControlFlowExpression = struct {
        base: Node,
        ltoken: TokenIndex,
        kind: Kind,
        rhs: ?*Node,

        const Kind = union(enum) {
            Break: ?*Node,
            Continue: ?*Node,
            Return,
        };

        pub fn iterate(self: *ControlFlowExpression, index: usize) ?*Node {
            var i = index;

            switch (self.kind) {
                Kind.Break => |maybe_label| {
                    if (maybe_label) |label| {
                        if (i < 1) return label;
                        i -= 1;
                    }
                },
                Kind.Continue => |maybe_label| {
                    if (maybe_label) |label| {
                        if (i < 1) return label;
                        i -= 1;
                    }
                },
                Kind.Return => {},
            }

            if (self.rhs) |rhs| {
                if (i < 1) return rhs;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *ControlFlowExpression) TokenIndex {
            return self.ltoken;
        }

        pub fn lastToken(self: *ControlFlowExpression) TokenIndex {
            if (self.rhs) |rhs| {
                return rhs.lastToken();
            }

            switch (self.kind) {
                Kind.Break => |maybe_label| {
                    if (maybe_label) |label| {
                        return label.lastToken();
                    }
                },
                Kind.Continue => |maybe_label| {
                    if (maybe_label) |label| {
                        return label.lastToken();
                    }
                },
                Kind.Return => return self.ltoken,
            }

            return self.ltoken;
        }
    };

    pub const Suspend = struct {
        base: Node,
        label: ?TokenIndex,
        suspend_token: TokenIndex,
        payload: ?*Node,
        body: ?*Node,

        pub fn iterate(self: *Suspend, index: usize) ?*Node {
            var i = index;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (self.body) |body| {
                if (i < 1) return body;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *Suspend) TokenIndex {
            if (self.label) |label| return label;
            return self.suspend_token;
        }

        pub fn lastToken(self: *Suspend) TokenIndex {
            if (self.body) |body| {
                return body.lastToken();
            }

            if (self.payload) |payload| {
                return payload.lastToken();
            }

            return self.suspend_token;
        }
    };

    pub const IntegerLiteral = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *IntegerLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *IntegerLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *IntegerLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const FloatLiteral = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *FloatLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *FloatLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *FloatLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const BuiltinCall = struct {
        base: Node,
        builtin_token: TokenIndex,
        params: ParamList,
        rparen_token: TokenIndex,

        pub const ParamList = SegmentedList(*Node, 2);

        pub fn iterate(self: *BuiltinCall, index: usize) ?*Node {
            var i = index;

            if (i < self.params.len) return self.params.at(i).*;
            i -= self.params.len;

            return null;
        }

        pub fn firstToken(self: *BuiltinCall) TokenIndex {
            return self.builtin_token;
        }

        pub fn lastToken(self: *BuiltinCall) TokenIndex {
            return self.rparen_token;
        }
    };

    pub const StringLiteral = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *StringLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *StringLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *StringLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const MultilineStringLiteral = struct {
        base: Node,
        lines: LineList,

        pub const LineList = SegmentedList(TokenIndex, 4);

        pub fn iterate(self: *MultilineStringLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *MultilineStringLiteral) TokenIndex {
            return self.lines.at(0).*;
        }

        pub fn lastToken(self: *MultilineStringLiteral) TokenIndex {
            return self.lines.at(self.lines.len - 1).*;
        }
    };

    pub const CharLiteral = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *CharLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *CharLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *CharLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const BoolLiteral = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *BoolLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *BoolLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *BoolLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const NullLiteral = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *NullLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *NullLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *NullLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const UndefinedLiteral = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *UndefinedLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *UndefinedLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *UndefinedLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const ThisLiteral = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *ThisLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *ThisLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *ThisLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const AsmOutput = struct {
        base: Node,
        lbracket: TokenIndex,
        symbolic_name: *Node,
        constraint: *Node,
        kind: Kind,
        rparen: TokenIndex,

        const Kind = union(enum) {
            Variable: *Identifier,
            Return: *Node,
        };

        pub fn iterate(self: *AsmOutput, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.symbolic_name;
            i -= 1;

            if (i < 1) return self.constraint;
            i -= 1;

            switch (self.kind) {
                Kind.Variable => |variable_name| {
                    if (i < 1) return &variable_name.base;
                    i -= 1;
                },
                Kind.Return => |return_type| {
                    if (i < 1) return return_type;
                    i -= 1;
                },
            }

            return null;
        }

        pub fn firstToken(self: *AsmOutput) TokenIndex {
            return self.lbracket;
        }

        pub fn lastToken(self: *AsmOutput) TokenIndex {
            return self.rparen;
        }
    };

    pub const AsmInput = struct {
        base: Node,
        lbracket: TokenIndex,
        symbolic_name: *Node,
        constraint: *Node,
        expr: *Node,
        rparen: TokenIndex,

        pub fn iterate(self: *AsmInput, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.symbolic_name;
            i -= 1;

            if (i < 1) return self.constraint;
            i -= 1;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *AsmInput) TokenIndex {
            return self.lbracket;
        }

        pub fn lastToken(self: *AsmInput) TokenIndex {
            return self.rparen;
        }
    };

    pub const Asm = struct {
        base: Node,
        asm_token: TokenIndex,
        volatile_token: ?TokenIndex,
        template: *Node,
        outputs: OutputList,
        inputs: InputList,
        clobbers: ClobberList,
        rparen: TokenIndex,

        const OutputList = SegmentedList(*AsmOutput, 2);
        const InputList = SegmentedList(*AsmInput, 2);
        const ClobberList = SegmentedList(TokenIndex, 2);

        pub fn iterate(self: *Asm, index: usize) ?*Node {
            var i = index;

            if (i < self.outputs.len) return &self.outputs.at(index).*.base;
            i -= self.outputs.len;

            if (i < self.inputs.len) return &self.inputs.at(index).*.base;
            i -= self.inputs.len;

            return null;
        }

        pub fn firstToken(self: *Asm) TokenIndex {
            return self.asm_token;
        }

        pub fn lastToken(self: *Asm) TokenIndex {
            return self.rparen;
        }
    };

    pub const Unreachable = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *Unreachable, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *Unreachable) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *Unreachable) TokenIndex {
            return self.token;
        }
    };

    pub const ErrorType = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *ErrorType, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *ErrorType) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *ErrorType) TokenIndex {
            return self.token;
        }
    };

    pub const VarType = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *VarType, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *VarType) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *VarType) TokenIndex {
            return self.token;
        }
    };

    pub const DocComment = struct {
        base: Node,
        lines: LineList,

        pub const LineList = SegmentedList(TokenIndex, 4);

        pub fn iterate(self: *DocComment, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *DocComment) TokenIndex {
            return self.lines.at(0).*;
        }

        pub fn lastToken(self: *DocComment) TokenIndex {
            return self.lines.at(self.lines.len - 1).*;
        }
    };

    pub const TestDecl = struct {
        base: Node,
        doc_comments: ?*DocComment,
        test_token: TokenIndex,
        name: *Node,
        body_node: *Node,

        pub fn iterate(self: *TestDecl, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.body_node;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *TestDecl) TokenIndex {
            return self.test_token;
        }

        pub fn lastToken(self: *TestDecl) TokenIndex {
            return self.body_node.lastToken();
        }
    };
};

test "iterate" {
    var root = Node.Root{
        .base = Node{ .id = Node.Id.Root },
        .doc_comments = null,
        .decls = Node.Root.DeclList.init(std.debug.global_allocator),
        .eof_token = 0,
    };
    var base = &root.base;
    assert(base.iterate(0) == null);
}
