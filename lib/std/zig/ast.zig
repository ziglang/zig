const std = @import("../std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const LinkedList = std.SinglyLinkedList;
const mem = std.mem;
const Token = std.zig.Token;

pub const TokenIndex = usize;
pub const NodeIndex = usize;

pub const Tree = struct {
    /// Reference to externally-owned data.
    source: []const u8,
    tokens: []const Token,
    errors: []const Error,
    /// undefined on parse error (when errors field is not empty)
    root_node: *Node.Root,

    arena: std.heap.ArenaAllocator.State,
    gpa: *mem.Allocator,

    /// translate-c uses this to avoid having to emit correct newlines
    /// TODO get rid of this hack
    generated: bool = false,

    pub fn deinit(self: *Tree) void {
        self.gpa.free(self.tokens);
        self.gpa.free(self.errors);
        self.arena.promote(self.gpa).deinit();
    }

    pub fn renderError(self: *Tree, parse_error: *const Error, stream: var) !void {
        return parse_error.render(self.tokens, stream);
    }

    pub fn tokenSlice(self: *Tree, token_index: TokenIndex) []const u8 {
        return self.tokenSlicePtr(self.tokens[token_index]);
    }

    pub fn tokenSlicePtr(self: *Tree, token: Token) []const u8 {
        return self.source[token.start..token.end];
    }

    pub fn getNodeSource(self: *const Tree, node: *const Node) []const u8 {
        const first_token = self.tokens[node.firstToken()];
        const last_token = self.tokens[node.lastToken()];
        return self.source[first_token.start..last_token.end];
    }

    pub const Location = struct {
        line: usize,
        column: usize,
        line_start: usize,
        line_end: usize,
    };

    /// Return the Location of the token relative to the offset specified by `start_index`.
    pub fn tokenLocationPtr(self: *Tree, start_index: usize, token: Token) Location {
        var loc = Location{
            .line = 0,
            .column = 0,
            .line_start = start_index,
            .line_end = self.source.len,
        };
        if (self.generated)
            return loc;
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
        return self.tokenLocationPtr(start_index, self.tokens[token_index]);
    }

    pub fn tokensOnSameLine(self: *Tree, token1_index: TokenIndex, token2_index: TokenIndex) bool {
        return self.tokensOnSameLinePtr(self.tokens[token1_index], self.tokens[token2_index]);
    }

    pub fn tokensOnSameLinePtr(self: *Tree, token1: Token, token2: Token) bool {
        return mem.indexOfScalar(u8, self.source[token1.end..token2.start], '\n') == null;
    }

    pub fn dump(self: *Tree) void {
        self.root_node.base.dump(0);
    }

    /// Skips over comments
    pub fn prevToken(self: *Tree, token_index: TokenIndex) TokenIndex {
        var index = token_index - 1;
        while (self.tokens[index].id == Token.Id.LineComment) {
            index -= 1;
        }
        return index;
    }

    /// Skips over comments
    pub fn nextToken(self: *Tree, token_index: TokenIndex) TokenIndex {
        var index = token_index + 1;
        while (self.tokens[index].id == Token.Id.LineComment) {
            index += 1;
        }
        return index;
    }
};

pub const Error = union(enum) {
    InvalidToken: InvalidToken,
    ExpectedContainerMembers: ExpectedContainerMembers,
    ExpectedStringLiteral: ExpectedStringLiteral,
    ExpectedIntegerLiteral: ExpectedIntegerLiteral,
    ExpectedPubItem: ExpectedPubItem,
    ExpectedIdentifier: ExpectedIdentifier,
    ExpectedStatement: ExpectedStatement,
    ExpectedVarDeclOrFn: ExpectedVarDeclOrFn,
    ExpectedVarDecl: ExpectedVarDecl,
    ExpectedFn: ExpectedFn,
    ExpectedReturnType: ExpectedReturnType,
    ExpectedAggregateKw: ExpectedAggregateKw,
    UnattachedDocComment: UnattachedDocComment,
    ExpectedEqOrSemi: ExpectedEqOrSemi,
    ExpectedSemiOrLBrace: ExpectedSemiOrLBrace,
    ExpectedSemiOrElse: ExpectedSemiOrElse,
    ExpectedLabelOrLBrace: ExpectedLabelOrLBrace,
    ExpectedLBrace: ExpectedLBrace,
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
    ExtraAllowZeroQualifier: ExtraAllowZeroQualifier,
    ExpectedTypeExpr: ExpectedTypeExpr,
    ExpectedPrimaryTypeExpr: ExpectedPrimaryTypeExpr,
    ExpectedParamType: ExpectedParamType,
    ExpectedExpr: ExpectedExpr,
    ExpectedPrimaryExpr: ExpectedPrimaryExpr,
    ExpectedToken: ExpectedToken,
    ExpectedCommaOrEnd: ExpectedCommaOrEnd,
    ExpectedParamList: ExpectedParamList,
    ExpectedPayload: ExpectedPayload,
    ExpectedBlockOrAssignment: ExpectedBlockOrAssignment,
    ExpectedBlockOrExpression: ExpectedBlockOrExpression,
    ExpectedExprOrAssignment: ExpectedExprOrAssignment,
    ExpectedPrefixExpr: ExpectedPrefixExpr,
    ExpectedLoopExpr: ExpectedLoopExpr,
    ExpectedDerefOrUnwrap: ExpectedDerefOrUnwrap,
    ExpectedSuffixOp: ExpectedSuffixOp,
    ExpectedBlockOrField: ExpectedBlockOrField,
    DeclBetweenFields: DeclBetweenFields,
    InvalidAnd: InvalidAnd,

    pub fn render(self: *const Error, tokens: []const Token, stream: var) !void {
        switch (self.*) {
            .InvalidToken => |*x| return x.render(tokens, stream),
            .ExpectedContainerMembers => |*x| return x.render(tokens, stream),
            .ExpectedStringLiteral => |*x| return x.render(tokens, stream),
            .ExpectedIntegerLiteral => |*x| return x.render(tokens, stream),
            .ExpectedPubItem => |*x| return x.render(tokens, stream),
            .ExpectedIdentifier => |*x| return x.render(tokens, stream),
            .ExpectedStatement => |*x| return x.render(tokens, stream),
            .ExpectedVarDeclOrFn => |*x| return x.render(tokens, stream),
            .ExpectedVarDecl => |*x| return x.render(tokens, stream),
            .ExpectedFn => |*x| return x.render(tokens, stream),
            .ExpectedReturnType => |*x| return x.render(tokens, stream),
            .ExpectedAggregateKw => |*x| return x.render(tokens, stream),
            .UnattachedDocComment => |*x| return x.render(tokens, stream),
            .ExpectedEqOrSemi => |*x| return x.render(tokens, stream),
            .ExpectedSemiOrLBrace => |*x| return x.render(tokens, stream),
            .ExpectedSemiOrElse => |*x| return x.render(tokens, stream),
            .ExpectedLabelOrLBrace => |*x| return x.render(tokens, stream),
            .ExpectedLBrace => |*x| return x.render(tokens, stream),
            .ExpectedColonOrRParen => |*x| return x.render(tokens, stream),
            .ExpectedLabelable => |*x| return x.render(tokens, stream),
            .ExpectedInlinable => |*x| return x.render(tokens, stream),
            .ExpectedAsmOutputReturnOrType => |*x| return x.render(tokens, stream),
            .ExpectedCall => |*x| return x.render(tokens, stream),
            .ExpectedCallOrFnProto => |*x| return x.render(tokens, stream),
            .ExpectedSliceOrRBracket => |*x| return x.render(tokens, stream),
            .ExtraAlignQualifier => |*x| return x.render(tokens, stream),
            .ExtraConstQualifier => |*x| return x.render(tokens, stream),
            .ExtraVolatileQualifier => |*x| return x.render(tokens, stream),
            .ExtraAllowZeroQualifier => |*x| return x.render(tokens, stream),
            .ExpectedTypeExpr => |*x| return x.render(tokens, stream),
            .ExpectedPrimaryTypeExpr => |*x| return x.render(tokens, stream),
            .ExpectedParamType => |*x| return x.render(tokens, stream),
            .ExpectedExpr => |*x| return x.render(tokens, stream),
            .ExpectedPrimaryExpr => |*x| return x.render(tokens, stream),
            .ExpectedToken => |*x| return x.render(tokens, stream),
            .ExpectedCommaOrEnd => |*x| return x.render(tokens, stream),
            .ExpectedParamList => |*x| return x.render(tokens, stream),
            .ExpectedPayload => |*x| return x.render(tokens, stream),
            .ExpectedBlockOrAssignment => |*x| return x.render(tokens, stream),
            .ExpectedBlockOrExpression => |*x| return x.render(tokens, stream),
            .ExpectedExprOrAssignment => |*x| return x.render(tokens, stream),
            .ExpectedPrefixExpr => |*x| return x.render(tokens, stream),
            .ExpectedLoopExpr => |*x| return x.render(tokens, stream),
            .ExpectedDerefOrUnwrap => |*x| return x.render(tokens, stream),
            .ExpectedSuffixOp => |*x| return x.render(tokens, stream),
            .ExpectedBlockOrField => |*x| return x.render(tokens, stream),
            .DeclBetweenFields => |*x| return x.render(tokens, stream),
            .InvalidAnd => |*x| return x.render(tokens, stream),
        }
    }

    pub fn loc(self: *const Error) TokenIndex {
        switch (self.*) {
            .InvalidToken => |x| return x.token,
            .ExpectedContainerMembers => |x| return x.token,
            .ExpectedStringLiteral => |x| return x.token,
            .ExpectedIntegerLiteral => |x| return x.token,
            .ExpectedPubItem => |x| return x.token,
            .ExpectedIdentifier => |x| return x.token,
            .ExpectedStatement => |x| return x.token,
            .ExpectedVarDeclOrFn => |x| return x.token,
            .ExpectedVarDecl => |x| return x.token,
            .ExpectedFn => |x| return x.token,
            .ExpectedReturnType => |x| return x.token,
            .ExpectedAggregateKw => |x| return x.token,
            .UnattachedDocComment => |x| return x.token,
            .ExpectedEqOrSemi => |x| return x.token,
            .ExpectedSemiOrLBrace => |x| return x.token,
            .ExpectedSemiOrElse => |x| return x.token,
            .ExpectedLabelOrLBrace => |x| return x.token,
            .ExpectedLBrace => |x| return x.token,
            .ExpectedColonOrRParen => |x| return x.token,
            .ExpectedLabelable => |x| return x.token,
            .ExpectedInlinable => |x| return x.token,
            .ExpectedAsmOutputReturnOrType => |x| return x.token,
            .ExpectedCall => |x| return x.node.firstToken(),
            .ExpectedCallOrFnProto => |x| return x.node.firstToken(),
            .ExpectedSliceOrRBracket => |x| return x.token,
            .ExtraAlignQualifier => |x| return x.token,
            .ExtraConstQualifier => |x| return x.token,
            .ExtraVolatileQualifier => |x| return x.token,
            .ExtraAllowZeroQualifier => |x| return x.token,
            .ExpectedTypeExpr => |x| return x.token,
            .ExpectedPrimaryTypeExpr => |x| return x.token,
            .ExpectedParamType => |x| return x.token,
            .ExpectedExpr => |x| return x.token,
            .ExpectedPrimaryExpr => |x| return x.token,
            .ExpectedToken => |x| return x.token,
            .ExpectedCommaOrEnd => |x| return x.token,
            .ExpectedParamList => |x| return x.token,
            .ExpectedPayload => |x| return x.token,
            .ExpectedBlockOrAssignment => |x| return x.token,
            .ExpectedBlockOrExpression => |x| return x.token,
            .ExpectedExprOrAssignment => |x| return x.token,
            .ExpectedPrefixExpr => |x| return x.token,
            .ExpectedLoopExpr => |x| return x.token,
            .ExpectedDerefOrUnwrap => |x| return x.token,
            .ExpectedSuffixOp => |x| return x.token,
            .ExpectedBlockOrField => |x| return x.token,
            .DeclBetweenFields => |x| return x.token,
            .InvalidAnd => |x| return x.token,
        }
    }

    pub const InvalidToken = SingleTokenError("Invalid token '{}'");
    pub const ExpectedContainerMembers = SingleTokenError("Expected test, comptime, var decl, or container field, found '{}'");
    pub const ExpectedStringLiteral = SingleTokenError("Expected string literal, found '{}'");
    pub const ExpectedIntegerLiteral = SingleTokenError("Expected integer literal, found '{}'");
    pub const ExpectedIdentifier = SingleTokenError("Expected identifier, found '{}'");
    pub const ExpectedStatement = SingleTokenError("Expected statement, found '{}'");
    pub const ExpectedVarDeclOrFn = SingleTokenError("Expected variable declaration or function, found '{}'");
    pub const ExpectedVarDecl = SingleTokenError("Expected variable declaration, found '{}'");
    pub const ExpectedFn = SingleTokenError("Expected function, found '{}'");
    pub const ExpectedReturnType = SingleTokenError("Expected 'var' or return type expression, found '{}'");
    pub const ExpectedAggregateKw = SingleTokenError("Expected '" ++ Token.Id.Keyword_struct.symbol() ++ "', '" ++ Token.Id.Keyword_union.symbol() ++ "', or '" ++ Token.Id.Keyword_enum.symbol() ++ "', found '{}'");
    pub const ExpectedEqOrSemi = SingleTokenError("Expected '=' or ';', found '{}'");
    pub const ExpectedSemiOrLBrace = SingleTokenError("Expected ';' or '{{', found '{}'");
    pub const ExpectedSemiOrElse = SingleTokenError("Expected ';' or 'else', found '{}'");
    pub const ExpectedLBrace = SingleTokenError("Expected '{{', found '{}'");
    pub const ExpectedLabelOrLBrace = SingleTokenError("Expected label or '{{', found '{}'");
    pub const ExpectedColonOrRParen = SingleTokenError("Expected ':' or ')', found '{}'");
    pub const ExpectedLabelable = SingleTokenError("Expected 'while', 'for', 'inline', 'suspend', or '{{', found '{}'");
    pub const ExpectedInlinable = SingleTokenError("Expected 'while' or 'for', found '{}'");
    pub const ExpectedAsmOutputReturnOrType = SingleTokenError("Expected '->' or '" ++ Token.Id.Identifier.symbol() ++ "', found '{}'");
    pub const ExpectedSliceOrRBracket = SingleTokenError("Expected ']' or '..', found '{}'");
    pub const ExpectedTypeExpr = SingleTokenError("Expected type expression, found '{}'");
    pub const ExpectedPrimaryTypeExpr = SingleTokenError("Expected primary type expression, found '{}'");
    pub const ExpectedExpr = SingleTokenError("Expected expression, found '{}'");
    pub const ExpectedPrimaryExpr = SingleTokenError("Expected primary expression, found '{}'");
    pub const ExpectedParamList = SingleTokenError("Expected parameter list, found '{}'");
    pub const ExpectedPayload = SingleTokenError("Expected loop payload, found '{}'");
    pub const ExpectedBlockOrAssignment = SingleTokenError("Expected block or assignment, found '{}'");
    pub const ExpectedBlockOrExpression = SingleTokenError("Expected block or expression, found '{}'");
    pub const ExpectedExprOrAssignment = SingleTokenError("Expected expression or assignment, found '{}'");
    pub const ExpectedPrefixExpr = SingleTokenError("Expected prefix expression, found '{}'");
    pub const ExpectedLoopExpr = SingleTokenError("Expected loop expression, found '{}'");
    pub const ExpectedDerefOrUnwrap = SingleTokenError("Expected pointer dereference or optional unwrap, found '{}'");
    pub const ExpectedSuffixOp = SingleTokenError("Expected pointer dereference, optional unwrap, or field access, found '{}'");
    pub const ExpectedBlockOrField = SingleTokenError("Expected block or field, found '{}'");

    pub const ExpectedParamType = SimpleError("Expected parameter type");
    pub const ExpectedPubItem = SimpleError("Expected function or variable declaration after pub");
    pub const UnattachedDocComment = SimpleError("Unattached documentation comment");
    pub const ExtraAlignQualifier = SimpleError("Extra align qualifier");
    pub const ExtraConstQualifier = SimpleError("Extra const qualifier");
    pub const ExtraVolatileQualifier = SimpleError("Extra volatile qualifier");
    pub const ExtraAllowZeroQualifier = SimpleError("Extra allowzero qualifier");
    pub const DeclBetweenFields = SimpleError("Declarations are not allowed between container fields");
    pub const InvalidAnd = SimpleError("`&&` is invalid. Note that `and` is boolean AND.");

    pub const ExpectedCall = struct {
        node: *Node,

        pub fn render(self: *const ExpectedCall, tokens: []const Token, stream: var) !void {
            return stream.print("expected " ++ @tagName(@TagType(Node.SuffixOp.Op).Call) ++ ", found {}", .{
                @tagName(self.node.id),
            });
        }
    };

    pub const ExpectedCallOrFnProto = struct {
        node: *Node,

        pub fn render(self: *const ExpectedCallOrFnProto, tokens: []const Token, stream: var) !void {
            return stream.print("expected " ++ @tagName(@TagType(Node.SuffixOp.Op).Call) ++ " or " ++
                @tagName(Node.Id.FnProto) ++ ", found {}", .{@tagName(self.node.id)});
        }
    };

    pub const ExpectedToken = struct {
        token: TokenIndex,
        expected_id: Token.Id,

        pub fn render(self: *const ExpectedToken, tokens: []const Token, stream: var) !void {
            const found_token = tokens[self.token];
            switch (found_token.id) {
                .Invalid => {
                    return stream.print("expected '{}', found invalid bytes", .{self.expected_id.symbol()});
                },
                else => {
                    const token_name = found_token.id.symbol();
                    return stream.print("expected '{}', found '{}'", .{ self.expected_id.symbol(), token_name });
                },
            }
        }
    };

    pub const ExpectedCommaOrEnd = struct {
        token: TokenIndex,
        end_id: Token.Id,

        pub fn render(self: *const ExpectedCommaOrEnd, tokens: []const Token, stream: var) !void {
            const actual_token = tokens[self.token];
            return stream.print("expected ',' or '{}', found '{}'", .{
                self.end_id.symbol(),
                actual_token.id.symbol(),
            });
        }
    };

    fn SingleTokenError(comptime msg: []const u8) type {
        return struct {
            const ThisError = @This();

            token: TokenIndex,

            pub fn render(self: *const ThisError, tokens: []const Token, stream: var) !void {
                const actual_token = tokens[self.token];
                return stream.print(msg, .{actual_token.id.symbol()});
            }
        };
    }

    fn SimpleError(comptime msg: []const u8) type {
        return struct {
            const ThisError = @This();

            token: TokenIndex,

            pub fn render(self: *const ThisError, tokens: []const Token, stream: var) !void {
                return stream.writeAll(msg);
            }
        };
    }
};

pub const Node = struct {
    id: Id,

    /// All the child Node types use this same Iterator state for their iteration.
    pub const Iterator = struct {
        parent_node: *const Node,
        node: ?*LinkedList(*Node).Node,
        index: usize,

        pub fn next(it: *Iterator) ?*Node {
            inline for (@typeInfo(Id).Enum.fields) |f| {
                if (it.parent_node.id == @field(Id, f.name)) {
                    const T = @field(Node, f.name);
                    return @fieldParentPtr(T, "base", it.parent_node).iterateNext(it);
                }
            }
            unreachable;
        }
    };

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
        /// This is a suffix operation but to save memory we have a dedicated Node id for it.
        ArrayInitializer,
        /// ArrayInitializer but with `.` instead of a left-hand-side operand.
        ArrayInitializerDot,
        /// This is a suffix operation but to save memory we have a dedicated Node id for it.
        StructInitializer,
        /// StructInitializer but with `.` instead of a left-hand-side operand.
        StructInitializerDot,

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
        AnyFrameType,

        // Primary expressions
        IntegerLiteral,
        FloatLiteral,
        EnumLiteral,
        StringLiteral,
        MultilineStringLiteral,
        CharLiteral,
        BoolLiteral,
        NullLiteral,
        UndefinedLiteral,
        Unreachable,
        Identifier,
        GroupedExpression,
        BuiltinCall,
        ErrorSetDecl,
        ContainerDecl,
        Asm,
        Comptime,
        Nosuspend,
        Block,

        // Misc
        DocComment,
        SwitchCase,
        SwitchElse,
        Else,
        Payload,
        PointerPayload,
        PointerIndexPayload,
        ContainerField,
        ErrorTag,
        AsmInput,
        AsmOutput,
        FieldInitializer,
    };

    pub fn cast(base: *Node, comptime T: type) ?*T {
        if (base.id == comptime typeToId(T)) {
            return @fieldParentPtr(T, "base", base);
        }
        return null;
    }

    pub fn iterate(base: *Node) Iterator {
        inline for (@typeInfo(Id).Enum.fields) |f| {
            if (base.id == @field(Id, f.name)) {
                const T = @field(Node, f.name);
                return @fieldParentPtr(T, "base", base).iterate();
            }
        }
        unreachable;
    }

    pub fn firstToken(base: *const Node) TokenIndex {
        inline for (@typeInfo(Id).Enum.fields) |f| {
            if (base.id == @field(Id, f.name)) {
                const T = @field(Node, f.name);
                return @fieldParentPtr(T, "base", base).firstToken();
            }
        }
        unreachable;
    }

    pub fn lastToken(base: *const Node) TokenIndex {
        inline for (@typeInfo(Id).Enum.fields) |f| {
            if (base.id == @field(Id, f.name)) {
                const T = @field(Node, f.name);
                return @fieldParentPtr(T, "base", base).lastToken();
            }
        }
        unreachable;
    }

    pub fn typeToId(comptime T: type) Id {
        inline for (@typeInfo(Id).Enum.fields) |f| {
            if (T == @field(Node, f.name)) {
                return @field(Id, f.name);
            }
        }
        unreachable;
    }

    pub fn requireSemiColon(base: *const Node) bool {
        var n = base;
        while (true) {
            switch (n.id) {
                .Root,
                .ContainerField,
                .Block,
                .Payload,
                .PointerPayload,
                .PointerIndexPayload,
                .Switch,
                .SwitchCase,
                .SwitchElse,
                .FieldInitializer,
                .DocComment,
                .TestDecl,
                => return false,
                .While => {
                    const while_node = @fieldParentPtr(While, "base", n);
                    if (while_node.@"else") |@"else"| {
                        n = &@"else".base;
                        continue;
                    }

                    return while_node.body.id != .Block;
                },
                .For => {
                    const for_node = @fieldParentPtr(For, "base", n);
                    if (for_node.@"else") |@"else"| {
                        n = &@"else".base;
                        continue;
                    }

                    return for_node.body.id != .Block;
                },
                .If => {
                    const if_node = @fieldParentPtr(If, "base", n);
                    if (if_node.@"else") |@"else"| {
                        n = &@"else".base;
                        continue;
                    }

                    return if_node.body.id != .Block;
                },
                .Else => {
                    const else_node = @fieldParentPtr(Else, "base", n);
                    n = else_node.body;
                    continue;
                },
                .Defer => {
                    const defer_node = @fieldParentPtr(Defer, "base", n);
                    return defer_node.expr.id != .Block;
                },
                .Comptime => {
                    const comptime_node = @fieldParentPtr(Comptime, "base", n);
                    return comptime_node.expr.id != .Block;
                },
                .Suspend => {
                    const suspend_node = @fieldParentPtr(Suspend, "base", n);
                    if (suspend_node.body) |body| {
                        return body.id != .Block;
                    }

                    return true;
                },
                .Nosuspend => {
                    const nosuspend_node = @fieldParentPtr(Nosuspend, "base", n);
                    return nosuspend_node.expr.id != .Block;
                },
                else => return true,
            }
        }
    }

    pub fn dump(self: *Node, indent: usize) void {
        {
            var i: usize = 0;
            while (i < indent) : (i += 1) {
                std.debug.warn(" ", .{});
            }
        }
        std.debug.warn("{}\n", .{@tagName(self.id)});

        var child_i: usize = 0;
        while (self.iterate(child_i)) |child| : (child_i += 1) {
            child.dump(indent + 2);
        }
    }

    /// The decls data follows this struct in memory as an array of Node pointers.
    pub const Root = struct {
        base: Node = Node{ .id = .Root },
        eof_token: TokenIndex,
        decls_len: NodeIndex,

        /// After this the caller must initialize the decls list.
        pub fn create(allocator: *mem.Allocator, decls_len: NodeIndex, eof_token: TokenIndex) !*Root {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(Root), sizeInBytes(decls_len));
            const self = @ptrCast(*Root, bytes.ptr);
            self.* = .{
                .eof_token = eof_token,
                .decls_len = decls_len,
            };
            return self;
        }

        pub fn destroy(self: *Decl, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.decls_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const Root) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const Root, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < self.decls_len) return self.declsConst()[i];
            return null;
        }

        pub fn decls(self: *Root) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(Root);
            return @ptrCast([*]*Node, decls_start)[0..self.decls_len];
        }

        pub fn declsConst(self: *const Root) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(Root);
            return @ptrCast([*]const *Node, decls_start)[0..self.decls_len];
        }

        pub fn firstToken(self: *const Root) TokenIndex {
            if (self.decls_len == 0) return self.eof_token;
            return self.declsConst()[0].firstToken();
        }

        pub fn lastToken(self: *const Root) TokenIndex {
            if (self.decls_len == 0) return self.eof_token;
            return self.declsConst()[self.decls_len - 1].lastToken();
        }

        fn sizeInBytes(decls_len: NodeIndex) usize {
            return @sizeOf(Root) + @sizeOf(*Node) * @as(usize, decls_len);
        }
    };

    pub const VarDecl = struct {
        base: Node = Node{ .id = .VarDecl },
        doc_comments: ?*DocComment,
        visib_token: ?TokenIndex,
        thread_local_token: ?TokenIndex,
        name_token: TokenIndex,
        eq_token: ?TokenIndex,
        mut_token: TokenIndex,
        comptime_token: ?TokenIndex,
        extern_export_token: ?TokenIndex,
        lib_name: ?*Node,
        type_node: ?*Node,
        align_node: ?*Node,
        section_node: ?*Node,
        init_node: ?*Node,
        semicolon_token: TokenIndex,

        pub fn iterate(self: *const VarDecl) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const VarDecl, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (self.type_node) |type_node| {
                if (i < 1) return type_node;
                i -= 1;
            }

            if (self.align_node) |align_node| {
                if (i < 1) return align_node;
                i -= 1;
            }

            if (self.section_node) |section_node| {
                if (i < 1) return section_node;
                i -= 1;
            }

            if (self.init_node) |init_node| {
                if (i < 1) return init_node;
                i -= 1;
            }

            return null;
        }


        pub fn firstToken(self: *const VarDecl) TokenIndex {
            if (self.visib_token) |visib_token| return visib_token;
            if (self.thread_local_token) |thread_local_token| return thread_local_token;
            if (self.comptime_token) |comptime_token| return comptime_token;
            if (self.extern_export_token) |extern_export_token| return extern_export_token;
            assert(self.lib_name == null);
            return self.mut_token;
        }

        pub fn lastToken(self: *const VarDecl) TokenIndex {
            return self.semicolon_token;
        }
    };

    pub const Use = struct {
        base: Node = Node{ .id = .Use },
        doc_comments: ?*DocComment,
        visib_token: ?TokenIndex,
        use_token: TokenIndex,
        expr: *Node,
        semicolon_token: TokenIndex,

        pub fn iterate(self: *const Use) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const Use, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const Use) TokenIndex {
            if (self.visib_token) |visib_token| return visib_token;
            return self.use_token;
        }

        pub fn lastToken(self: *const Use) TokenIndex {
            return self.semicolon_token;
        }
    };

    pub const ErrorSetDecl = struct {
        base: Node = Node{ .id = .ErrorSetDecl },
        error_token: TokenIndex,
        decls: DeclList,
        rbrace_token: TokenIndex,

        pub const DeclList = LinkedList(*Node);

        pub fn iterate(self: *const ErrorSetDecl) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = self.decls.first };
        }

        pub fn iterateNext(self: *const ErrorSetDecl, it: *Node.Iterator) ?*Node {
            const decl = it.node orelse return null;
            it.node = decl.next;
            return decl.data;
        }

        pub fn firstToken(self: *const ErrorSetDecl) TokenIndex {
            return self.error_token;
        }

        pub fn lastToken(self: *const ErrorSetDecl) TokenIndex {
            return self.rbrace_token;
        }
    };

    /// The fields and decls Node pointers directly follow this struct in memory.
    pub const ContainerDecl = struct {
        base: Node = Node{ .id = .ContainerDecl },
        kind_token: TokenIndex,
        layout_token: ?TokenIndex,
        lbrace_token: TokenIndex,
        rbrace_token: TokenIndex,
        fields_and_decls_len: NodeIndex,
        init_arg_expr: InitArg,

        pub const InitArg = union(enum) {
            None,
            Enum: ?*Node,
            Type: *Node,
        };

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, fields_and_decls_len: NodeIndex) !*ContainerDecl {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(ContainerDecl), sizeInBytes(fields_and_decls_len));
            return @ptrCast(*ContainerDecl, bytes.ptr);
        }

        pub fn free(self: *ContainerDecl, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.fields_and_decls_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const ContainerDecl) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const ContainerDecl, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            switch (self.init_arg_expr) {
                .Type => |t| {
                    if (i < 1) return t;
                    i -= 1;
                },
                .None, .Enum => {},
            }

            if (i < self.fields_and_decls_len) return self.fieldsAndDeclsConst()[i];
            i -= self.fields_and_decls_len;

            return null;
        }

        pub fn firstToken(self: *const ContainerDecl) TokenIndex {
            if (self.layout_token) |layout_token| {
                return layout_token;
            }
            return self.kind_token;
        }

        pub fn lastToken(self: *const ContainerDecl) TokenIndex {
            return self.rbrace_token;
        }

        pub fn fieldsAndDecls(self: *ContainerDecl) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(ContainerDecl);
            return @ptrCast([*]*Node, decls_start)[0..self.fields_and_decls_len];
        }

        pub fn fieldsAndDeclsConst(self: *const ContainerDecl) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(ContainerDecl);
            return @ptrCast([*]const *Node, decls_start)[0..self.fields_and_decls_len];
        }

        fn sizeInBytes(fields_and_decls_len: NodeIndex) usize {
            return @sizeOf(ContainerDecl) + @sizeOf(*Node) * @as(usize, fields_and_decls_len);
        }
    };

    pub const ContainerField = struct {
        base: Node = Node{ .id = .ContainerField },
        doc_comments: ?*DocComment,
        comptime_token: ?TokenIndex,
        name_token: TokenIndex,
        type_expr: ?*Node,
        value_expr: ?*Node,
        align_expr: ?*Node,

        pub fn iterate(self: *const ContainerField) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const ContainerField, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (self.type_expr) |type_expr| {
                if (i < 1) return type_expr;
                i -= 1;
            }

            if (self.align_expr) |align_expr| {
                if (i < 1) return align_expr;
                i -= 1;
            }

            if (self.value_expr) |value_expr| {
                if (i < 1) return value_expr;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const ContainerField) TokenIndex {
            return self.comptime_token orelse self.name_token;
        }

        pub fn lastToken(self: *const ContainerField) TokenIndex {
            if (self.value_expr) |value_expr| {
                return value_expr.lastToken();
            }
            if (self.align_expr) |align_expr| {
                // The expression refers to what's inside the parenthesis, the
                // last token is the closing one
                return align_expr.lastToken() + 1;
            }
            if (self.type_expr) |type_expr| {
                return type_expr.lastToken();
            }

            return self.name_token;
        }
    };

    pub const ErrorTag = struct {
        base: Node = Node{ .id = .ErrorTag },
        doc_comments: ?*DocComment,
        name_token: TokenIndex,

        pub fn iterate(self: *const ErrorTag) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const ErrorTag, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (self.doc_comments) |comments| {
                if (i < 1) return &comments.base;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const ErrorTag) TokenIndex {
            return self.name_token;
        }

        pub fn lastToken(self: *const ErrorTag) TokenIndex {
            return self.name_token;
        }
    };

    pub const Identifier = struct {
        base: Node = Node{ .id = .Identifier },
        token: TokenIndex,

        pub fn iterate(self: *const Identifier) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const Identifier, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const Identifier) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const Identifier) TokenIndex {
            return self.token;
        }
    };

    /// The params are directly after the FnProto in memory.
    pub const FnProto = struct {
        base: Node = Node{ .id = .FnProto },
        doc_comments: ?*DocComment,
        visib_token: ?TokenIndex,
        fn_token: TokenIndex,
        name_token: ?TokenIndex,
        params_len: NodeIndex,
        return_type: ReturnType,
        var_args_token: ?TokenIndex,
        extern_export_inline_token: ?TokenIndex,
        body_node: ?*Node,
        lib_name: ?*Node, // populated if this is an extern declaration
        align_expr: ?*Node, // populated if align(A) is present
        section_expr: ?*Node, // populated if linksection(A) is present
        callconv_expr: ?*Node, // populated if callconv(A) is present
        is_extern_prototype: bool = false, // TODO: Remove once extern fn rewriting is
        is_async: bool = false, // TODO: remove once async fn rewriting is

        pub const ReturnType = union(enum) {
            Explicit: *Node,
            InferErrorSet: *Node,
            Invalid: TokenIndex,
        };

        pub const ParamDecl = struct {
            doc_comments: ?*DocComment,
            comptime_token: ?TokenIndex,
            noalias_token: ?TokenIndex,
            name_token: ?TokenIndex,
            param_type: ParamType,

            pub const ParamType = union(enum) {
                var_type: *Node,
                var_args: TokenIndex,
                type_expr: *Node,
            };

            pub fn iterate(self: *const ParamDecl) Node.Iterator {
                return .{ .parent_node = &self.base, .index = 0, .node = null };
            }

            pub fn iterateNext(self: *const ParamDecl, it: *Node.Iterator) ?*Node {
                var i = it.index;
                it.index += 1;

                if (i < 1) {
                    switch (self.param_type) {
                        .var_args => return null,
                        .var_type, .type_expr => |node| return node,
                    }
                }
                i -= 1;

                return null;
            }

            pub fn firstToken(self: *const ParamDecl) TokenIndex {
                if (self.comptime_token) |comptime_token| return comptime_token;
                if (self.noalias_token) |noalias_token| return noalias_token;
                if (self.name_token) |name_token| return name_token;
                switch (self.param_type) {
                    .var_args => |tok| return tok,
                    .var_type, .type_expr => |node| return node.firstToken(),
                }
            }

            pub fn lastToken(self: *const ParamDecl) TokenIndex {
                switch (self.param_type) {
                    .var_args => |tok| return tok,
                    .var_type, .type_expr => |node| return node.lastToken(),
                }
            }
        };

        /// After this the caller must initialize the params list.
        pub fn alloc(allocator: *mem.Allocator, params_len: NodeIndex) !*FnProto {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(FnProto), sizeInBytes(params_len));
            return @ptrCast(*FnProto, bytes.ptr);
        }

        pub fn free(self: *FnProto, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.params_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const FnProto) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const FnProto, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (self.lib_name) |lib_name| {
                if (i < 1) return lib_name;
                i -= 1;
            }

            if (i < self.params_len) {
                switch (self.paramsConst()[i].param_type) {
                    .var_type => |n| return n,
                    .var_args => {
                        i += 1;
                        it.index += 1;
                    },
                    .type_expr => |n| return n,
                }
            }
            i -= self.params_len;

            if (self.align_expr) |align_expr| {
                if (i < 1) return align_expr;
                i -= 1;
            }

            if (self.section_expr) |section_expr| {
                if (i < 1) return section_expr;
                i -= 1;
            }

            switch (self.return_type) {
                .Explicit, .InferErrorSet => |node| {
                    if (i < 1) return node;
                    i -= 1;
                },
                .Invalid => {},
            }

            if (self.body_node) |body_node| {
                if (i < 1) return body_node;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const FnProto) TokenIndex {
            if (self.visib_token) |visib_token| return visib_token;
            if (self.extern_export_inline_token) |extern_export_inline_token| return extern_export_inline_token;
            assert(self.lib_name == null);
            return self.fn_token;
        }

        pub fn lastToken(self: *const FnProto) TokenIndex {
            if (self.body_node) |body_node| return body_node.lastToken();
            switch (self.return_type) {
                .Explicit, .InferErrorSet => |node| return node.lastToken(),
                .Invalid => |tok| return tok,
            }
        }

        pub fn params(self: *FnProto) []ParamDecl {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(FnProto);
            return @ptrCast([*]ParamDecl, decls_start)[0..self.params_len];
        }

        pub fn paramsConst(self: *const FnProto) []const ParamDecl {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(FnProto);
            return @ptrCast([*]const ParamDecl, decls_start)[0..self.params_len];
        }

        fn sizeInBytes(params_len: NodeIndex) usize {
            return @sizeOf(FnProto) + @sizeOf(ParamDecl) * @as(usize, params_len);
        }
    };

    pub const AnyFrameType = struct {
        base: Node = Node{ .id = .AnyFrameType },
        anyframe_token: TokenIndex,
        result: ?Result,

        pub const Result = struct {
            arrow_token: TokenIndex,
            return_type: *Node,
        };

        pub fn iterate(self: *const AnyFrameType) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const AnyFrameType, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (self.result) |result| {
                if (i < 1) return result.return_type;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const AnyFrameType) TokenIndex {
            return self.anyframe_token;
        }

        pub fn lastToken(self: *const AnyFrameType) TokenIndex {
            if (self.result) |result| return result.return_type.lastToken();
            return self.anyframe_token;
        }
    };

    /// The statements of the block follow Block directly in memory.
    pub const Block = struct {
        base: Node = Node{ .id = .Block },
        statements_len: NodeIndex,
        lbrace: TokenIndex,
        rbrace: TokenIndex,
        label: ?TokenIndex,

        /// After this the caller must initialize the statements list.
        pub fn alloc(allocator: *mem.Allocator, statements_len: NodeIndex) !*Block {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(Block), sizeInBytes(statements_len));
            return @ptrCast(*Block, bytes.ptr);
        }

        pub fn free(self: *Block, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.statements_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const Block) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const Block, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < self.statements_len) return self.statementsConst()[i];
            i -= self.statements_len;

            return null;
        }

        pub fn firstToken(self: *const Block) TokenIndex {
            if (self.label) |label| {
                return label;
            }

            return self.lbrace;
        }

        pub fn lastToken(self: *const Block) TokenIndex {
            return self.rbrace;
        }

        pub fn statements(self: *Block) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(Block);
            return @ptrCast([*]*Node, decls_start)[0..self.statements_len];
        }

        pub fn statementsConst(self: *const Block) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(Block);
            return @ptrCast([*]const *Node, decls_start)[0..self.statements_len];
        }

        fn sizeInBytes(statements_len: NodeIndex) usize {
            return @sizeOf(Block) + @sizeOf(*Node) * @as(usize, statements_len);
        }
    };

    pub const Defer = struct {
        base: Node = Node{ .id = .Defer },
        defer_token: TokenIndex,
        payload: ?*Node,
        expr: *Node,

        pub fn iterate(self: *const Defer) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const Defer, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const Defer) TokenIndex {
            return self.defer_token;
        }

        pub fn lastToken(self: *const Defer) TokenIndex {
            return self.expr.lastToken();
        }
    };

    pub const Comptime = struct {
        base: Node = Node{ .id = .Comptime },
        doc_comments: ?*DocComment,
        comptime_token: TokenIndex,
        expr: *Node,

        pub fn iterate(self: *const Comptime) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const Comptime, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const Comptime) TokenIndex {
            return self.comptime_token;
        }

        pub fn lastToken(self: *const Comptime) TokenIndex {
            return self.expr.lastToken();
        }
    };

    pub const Nosuspend = struct {
        base: Node = Node{ .id = .Nosuspend },
        nosuspend_token: TokenIndex,
        expr: *Node,

        pub fn iterate(self: *const Nosuspend) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const Nosuspend, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const Nosuspend) TokenIndex {
            return self.nosuspend_token;
        }

        pub fn lastToken(self: *const Nosuspend) TokenIndex {
            return self.expr.lastToken();
        }
    };

    pub const Payload = struct {
        base: Node = Node{ .id = .Payload },
        lpipe: TokenIndex,
        error_symbol: *Node,
        rpipe: TokenIndex,

        pub fn iterate(self: *const Payload) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const Payload, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.error_symbol;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const Payload) TokenIndex {
            return self.lpipe;
        }

        pub fn lastToken(self: *const Payload) TokenIndex {
            return self.rpipe;
        }
    };

    pub const PointerPayload = struct {
        base: Node = Node{ .id = .PointerPayload },
        lpipe: TokenIndex,
        ptr_token: ?TokenIndex,
        value_symbol: *Node,
        rpipe: TokenIndex,

        pub fn iterate(self: *const PointerPayload) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const PointerPayload, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.value_symbol;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const PointerPayload) TokenIndex {
            return self.lpipe;
        }

        pub fn lastToken(self: *const PointerPayload) TokenIndex {
            return self.rpipe;
        }
    };

    pub const PointerIndexPayload = struct {
        base: Node = Node{ .id = .PointerIndexPayload },
        lpipe: TokenIndex,
        ptr_token: ?TokenIndex,
        value_symbol: *Node,
        index_symbol: ?*Node,
        rpipe: TokenIndex,

        pub fn iterate(self: *const PointerIndexPayload) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const PointerIndexPayload, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.value_symbol;
            i -= 1;

            if (self.index_symbol) |index_symbol| {
                if (i < 1) return index_symbol;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const PointerIndexPayload) TokenIndex {
            return self.lpipe;
        }

        pub fn lastToken(self: *const PointerIndexPayload) TokenIndex {
            return self.rpipe;
        }
    };

    pub const Else = struct {
        base: Node = Node{ .id = .Else },
        else_token: TokenIndex,
        payload: ?*Node,
        body: *Node,

        pub fn iterate(self: *const Else) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const Else, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (i < 1) return self.body;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const Else) TokenIndex {
            return self.else_token;
        }

        pub fn lastToken(self: *const Else) TokenIndex {
            return self.body.lastToken();
        }
    };

    pub const Switch = struct {
        base: Node = Node{ .id = .Switch },
        switch_token: TokenIndex,
        expr: *Node,

        /// these must be SwitchCase nodes
        cases: CaseList,
        rbrace: TokenIndex,

        pub const CaseList = LinkedList(*Node);

        pub fn iterate(self: *const Switch) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = self.cases.first };
        }

        pub fn iterateNext(self: *const Switch, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.expr;
            i -= 1;

            if (it.node) |child| {
                it.index -= 1;
                it.node = child.next;
                return child.data;
            }

            return null;
        }

        pub fn firstToken(self: *const Switch) TokenIndex {
            return self.switch_token;
        }

        pub fn lastToken(self: *const Switch) TokenIndex {
            return self.rbrace;
        }
    };

    pub const SwitchCase = struct {
        base: Node = Node{ .id = .SwitchCase },
        items: ItemList,
        arrow_token: TokenIndex,
        payload: ?*Node,
        expr: *Node,

        pub const ItemList = LinkedList(*Node);

        pub fn iterate(self: *const SwitchCase) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = self.items.first };
        }

        pub fn iterateNext(self: *const SwitchCase, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (it.node) |child| {
                it.index -= 1;
                it.node = child.next;
                return child.data;
            }

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const SwitchCase) TokenIndex {
            return self.items.first.?.data.firstToken();
        }

        pub fn lastToken(self: *const SwitchCase) TokenIndex {
            return self.expr.lastToken();
        }
    };

    pub const SwitchElse = struct {
        base: Node = Node{ .id = .SwitchElse },
        token: TokenIndex,

        pub fn iterate(self: *const SwitchElse) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const SwitchElse, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const SwitchElse) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const SwitchElse) TokenIndex {
            return self.token;
        }
    };

    pub const While = struct {
        base: Node = Node{ .id = .While },
        label: ?TokenIndex,
        inline_token: ?TokenIndex,
        while_token: TokenIndex,
        condition: *Node,
        payload: ?*Node,
        continue_expr: ?*Node,
        body: *Node,
        @"else": ?*Else,

        pub fn iterate(self: *const While) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const While, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

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

        pub fn firstToken(self: *const While) TokenIndex {
            if (self.label) |label| {
                return label;
            }

            if (self.inline_token) |inline_token| {
                return inline_token;
            }

            return self.while_token;
        }

        pub fn lastToken(self: *const While) TokenIndex {
            if (self.@"else") |@"else"| {
                return @"else".body.lastToken();
            }

            return self.body.lastToken();
        }
    };

    pub const For = struct {
        base: Node = Node{ .id = .For },
        label: ?TokenIndex,
        inline_token: ?TokenIndex,
        for_token: TokenIndex,
        array_expr: *Node,
        payload: *Node,
        body: *Node,
        @"else": ?*Else,

        pub fn iterate(self: *const For) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const For, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.array_expr;
            i -= 1;

            if (i < 1) return self.payload;
            i -= 1;

            if (i < 1) return self.body;
            i -= 1;

            if (self.@"else") |@"else"| {
                if (i < 1) return &@"else".base;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const For) TokenIndex {
            if (self.label) |label| {
                return label;
            }

            if (self.inline_token) |inline_token| {
                return inline_token;
            }

            return self.for_token;
        }

        pub fn lastToken(self: *const For) TokenIndex {
            if (self.@"else") |@"else"| {
                return @"else".body.lastToken();
            }

            return self.body.lastToken();
        }
    };

    pub const If = struct {
        base: Node = Node{ .id = .If },
        if_token: TokenIndex,
        condition: *Node,
        payload: ?*Node,
        body: *Node,
        @"else": ?*Else,

        pub fn iterate(self: *const If) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const If, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

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

        pub fn firstToken(self: *const If) TokenIndex {
            return self.if_token;
        }

        pub fn lastToken(self: *const If) TokenIndex {
            if (self.@"else") |@"else"| {
                return @"else".body.lastToken();
            }

            return self.body.lastToken();
        }
    };

    pub const InfixOp = struct {
        base: Node = Node{ .id = .InfixOp },
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
            AssignSub,
            AssignSubWrap,
            AssignMod,
            AssignAdd,
            AssignAddWrap,
            AssignMul,
            AssignMulWrap,
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
            Mul,
            MulWrap,
            Period,
            Range,
            Sub,
            SubWrap,
            UnwrapOptional,
        };

        pub fn iterate(self: *const InfixOp) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const InfixOp, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.lhs;
            i -= 1;

            switch (self.op) {
                .Catch => |maybe_payload| {
                    if (maybe_payload) |payload| {
                        if (i < 1) return payload;
                        i -= 1;
                    }
                },

                .Add,
                .AddWrap,
                .ArrayCat,
                .ArrayMult,
                .Assign,
                .AssignBitAnd,
                .AssignBitOr,
                .AssignBitShiftLeft,
                .AssignBitShiftRight,
                .AssignBitXor,
                .AssignDiv,
                .AssignSub,
                .AssignSubWrap,
                .AssignMod,
                .AssignAdd,
                .AssignAddWrap,
                .AssignMul,
                .AssignMulWrap,
                .BangEqual,
                .BitAnd,
                .BitOr,
                .BitShiftLeft,
                .BitShiftRight,
                .BitXor,
                .BoolAnd,
                .BoolOr,
                .Div,
                .EqualEqual,
                .ErrorUnion,
                .GreaterOrEqual,
                .GreaterThan,
                .LessOrEqual,
                .LessThan,
                .MergeErrorSets,
                .Mod,
                .Mul,
                .MulWrap,
                .Period,
                .Range,
                .Sub,
                .SubWrap,
                .UnwrapOptional,
                => {},
            }

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const InfixOp) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const InfixOp) TokenIndex {
            return self.rhs.lastToken();
        }
    };

    pub const PrefixOp = struct {
        base: Node = Node{ .id = .PrefixOp },
        op_token: TokenIndex,
        op: Op,
        rhs: *Node,

        pub const Op = union(enum) {
            AddressOf,
            ArrayType: ArrayInfo,
            Await,
            BitNot,
            BoolNot,
            OptionalType,
            Negation,
            NegationWrap,
            Resume,
            PtrType: PtrInfo,
            SliceType: PtrInfo,
            Try,
        };

        pub const ArrayInfo = struct {
            len_expr: *Node,
            sentinel: ?*Node,
        };

        pub const PtrInfo = struct {
            allowzero_token: ?TokenIndex = null,
            align_info: ?Align = null,
            const_token: ?TokenIndex = null,
            volatile_token: ?TokenIndex = null,
            sentinel: ?*Node = null,

            pub const Align = struct {
                node: *Node,
                bit_range: ?BitRange,

                pub const BitRange = struct {
                    start: *Node,
                    end: *Node,
                };
            };
        };

        pub fn iterate(self: *const PrefixOp) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const PrefixOp, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            switch (self.op) {
                .PtrType, .SliceType => |addr_of_info| {
                    if (addr_of_info.sentinel) |sentinel| {
                        if (i < 1) return sentinel;
                        i -= 1;
                    }

                    if (addr_of_info.align_info) |align_info| {
                        if (i < 1) return align_info.node;
                        i -= 1;
                    }
                },

                .ArrayType => |array_info| {
                    if (i < 1) return array_info.len_expr;
                    i -= 1;
                    if (array_info.sentinel) |sentinel| {
                        if (i < 1) return sentinel;
                        i -= 1;
                    }
                },

                .AddressOf,
                .Await,
                .BitNot,
                .BoolNot,
                .OptionalType,
                .Negation,
                .NegationWrap,
                .Try,
                .Resume,
                => {},
            }

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const PrefixOp) TokenIndex {
            return self.op_token;
        }

        pub fn lastToken(self: *const PrefixOp) TokenIndex {
            return self.rhs.lastToken();
        }
    };

    pub const FieldInitializer = struct {
        base: Node = Node{ .id = .FieldInitializer },
        period_token: TokenIndex,
        name_token: TokenIndex,
        expr: *Node,

        pub fn iterate(self: *const FieldInitializer) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const FieldInitializer, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const FieldInitializer) TokenIndex {
            return self.period_token;
        }

        pub fn lastToken(self: *const FieldInitializer) TokenIndex {
            return self.expr.lastToken();
        }
    };

    pub const ArrayInitializer = struct {
        base: Node = Node{ .id = .ArrayInitializer },
        rtoken: TokenIndex,
        lhs: *Node,
        list: []*Node,

        pub fn iterate(self: *const ArrayInitializer) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const ArrayInitializer, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.lhs;
            i -= 1;

            if (i < self.list.len) return self.list[i];
            i -= self.list.len;

            return null;
        }

        pub fn firstToken(self: *const ArrayInitializer) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const ArrayInitializer) TokenIndex {
            return self.rtoken;
        }
    };

    pub const ArrayInitializerDot = struct {
        base: Node = Node{ .id = .ArrayInitializerDot },
        dot: TokenIndex,
        rtoken: TokenIndex,
        list: []*Node,

        pub fn iterate(self: *const ArrayInitializerDot) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const ArrayInitializerDot, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < self.list.len) return self.list[i];
            i -= self.list.len;

            return null;
        }

        pub fn firstToken(self: *const ArrayInitializerDot) TokenIndex {
            return self.dot;
        }

        pub fn lastToken(self: *const ArrayInitializerDot) TokenIndex {
            return self.rtoken;
        }
    };

    pub const StructInitializer = struct {
        base: Node = Node{ .id = .StructInitializer },
        rtoken: TokenIndex,
        lhs: *Node,
        list: []*Node,

        pub fn iterate(self: *const StructInitializer) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const StructInitializer, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.lhs;
            i -= 1;

            if (i < self.list.len) return self.list[i];
            i -= self.list.len;

            return null;
        }

        pub fn firstToken(self: *const StructInitializer) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const StructInitializer) TokenIndex {
            return self.rtoken;
        }
    };

    pub const StructInitializerDot = struct {
        base: Node = Node{ .id = .StructInitializerDot },
        dot: TokenIndex,
        rtoken: TokenIndex,
        list: []*Node,

        pub fn iterate(self: *const StructInitializerDot) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const StructInitializerDot, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < self.list.len) return self.list[i];
            i -= self.list.len;

            return null;
        }

        pub fn firstToken(self: *const StructInitializerDot) TokenIndex {
            return self.dot;
        }

        pub fn lastToken(self: *const StructInitializerDot) TokenIndex {
            return self.rtoken;
        }
    };

    pub const SuffixOp = struct {
        base: Node = Node{ .id = .SuffixOp },
        op: Op,
        lhs: *Node,
        rtoken: TokenIndex,

        pub const Op = union(enum) {
            Call: Call,
            ArrayAccess: *Node,
            Slice: Slice,
            Deref,
            UnwrapOptional,

            pub const Call = struct {
                params: ParamList,
                async_token: ?TokenIndex,

                pub const ParamList = LinkedList(*Node);
            };

            pub const Slice = struct {
                start: *Node,
                end: ?*Node,
                sentinel: ?*Node,
            };
        };

        pub fn iterate(self: *const SuffixOp) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0,
                .node = switch(self.op) {
                    .Call => |call| call.params.first,
                    else => null,
                },
            };
        }

        pub fn iterateNext(self: *const SuffixOp, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i == 0) return self.lhs;
            i -= 1;

            switch (self.op) {
                .Call => |call_info| {
                    if (it.node) |child| {
                        it.index -= 1;
                        it.node = child.next;
                        return child.data;
                    }
                },
                .ArrayAccess => |index_expr| {
                    if (i < 1) return index_expr;
                    i -= 1;
                },
                .Slice => |range| {
                    if (i < 1) return range.start;
                    i -= 1;

                    if (range.end) |end| {
                        if (i < 1) return end;
                        i -= 1;
                    }
                    if (range.sentinel) |sentinel| {
                        if (i < 1) return sentinel;
                        i -= 1;
                    }
                },
                .UnwrapOptional,
                .Deref,
                => {},
            }

            return null;
        }

        pub fn firstToken(self: *const SuffixOp) TokenIndex {
            switch (self.op) {
                .Call => |*call_info| if (call_info.async_token) |async_token| return async_token,
                else => {},
            }
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const SuffixOp) TokenIndex {
            return self.rtoken;
        }
    };

    pub const GroupedExpression = struct {
        base: Node = Node{ .id = .GroupedExpression },
        lparen: TokenIndex,
        expr: *Node,
        rparen: TokenIndex,

        pub fn iterate(self: *const GroupedExpression) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const GroupedExpression, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const GroupedExpression) TokenIndex {
            return self.lparen;
        }

        pub fn lastToken(self: *const GroupedExpression) TokenIndex {
            return self.rparen;
        }
    };

    pub const ControlFlowExpression = struct {
        base: Node = Node{ .id = .ControlFlowExpression },
        ltoken: TokenIndex,
        kind: Kind,
        rhs: ?*Node,

        pub const Kind = union(enum) {
            Break: ?*Node,
            Continue: ?*Node,
            Return,
        };

        pub fn iterate(self: *const ControlFlowExpression) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const ControlFlowExpression, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            switch (self.kind) {
                .Break, .Continue => |maybe_label| {
                    if (maybe_label) |label| {
                        if (i < 1) return label;
                        i -= 1;
                    }
                },
                .Return => {},
            }

            if (self.rhs) |rhs| {
                if (i < 1) return rhs;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const ControlFlowExpression) TokenIndex {
            return self.ltoken;
        }

        pub fn lastToken(self: *const ControlFlowExpression) TokenIndex {
            if (self.rhs) |rhs| {
                return rhs.lastToken();
            }

            switch (self.kind) {
                .Break, .Continue => |maybe_label| {
                    if (maybe_label) |label| {
                        return label.lastToken();
                    }
                },
                .Return => return self.ltoken,
            }

            return self.ltoken;
        }
    };

    pub const Suspend = struct {
        base: Node = Node{ .id = .Suspend },
        suspend_token: TokenIndex,
        body: ?*Node,

        pub fn iterate(self: *const Suspend) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const Suspend, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (self.body) |body| {
                if (i < 1) return body;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const Suspend) TokenIndex {
            return self.suspend_token;
        }

        pub fn lastToken(self: *const Suspend) TokenIndex {
            if (self.body) |body| {
                return body.lastToken();
            }

            return self.suspend_token;
        }
    };

    pub const IntegerLiteral = struct {
        base: Node = Node{ .id = .IntegerLiteral },
        token: TokenIndex,

        pub fn iterate(self: *const IntegerLiteral) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const IntegerLiteral, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const IntegerLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const IntegerLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const EnumLiteral = struct {
        base: Node = Node{ .id = .EnumLiteral },
        dot: TokenIndex,
        name: TokenIndex,

        pub fn iterate(self: *const EnumLiteral) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const EnumLiteral, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const EnumLiteral) TokenIndex {
            return self.dot;
        }

        pub fn lastToken(self: *const EnumLiteral) TokenIndex {
            return self.name;
        }
    };

    pub const FloatLiteral = struct {
        base: Node = Node{ .id = .FloatLiteral },
        token: TokenIndex,

        pub fn iterate(self: *const FloatLiteral) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const FloatLiteral, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const FloatLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const FloatLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const BuiltinCall = struct {
        base: Node = Node{ .id = .BuiltinCall },
        builtin_token: TokenIndex,
        params: ParamList,
        rparen_token: TokenIndex,

        pub const ParamList = LinkedList(*Node);

        pub fn iterate(self: *const BuiltinCall) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = self.params.first };
        }

        pub fn iterateNext(self: *const BuiltinCall, it: *Node.Iterator) ?*Node {
            const param = it.node orelse return null;
            it.node = param.next;
            return param.data;
        }

        pub fn firstToken(self: *const BuiltinCall) TokenIndex {
            return self.builtin_token;
        }

        pub fn lastToken(self: *const BuiltinCall) TokenIndex {
            return self.rparen_token;
        }
    };

    pub const StringLiteral = struct {
        base: Node = Node{ .id = .StringLiteral },
        token: TokenIndex,

        pub fn iterate(self: *const StringLiteral) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const StringLiteral, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const StringLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const StringLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const MultilineStringLiteral = struct {
        base: Node = Node{ .id = .MultilineStringLiteral },
        lines: LineList,

        pub const LineList = LinkedList(TokenIndex);

        pub fn iterate(self: *const MultilineStringLiteral) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const MultilineStringLiteral, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const MultilineStringLiteral) TokenIndex {
            return self.lines.first.?.data;
        }

        pub fn lastToken(self: *const MultilineStringLiteral) TokenIndex {
            var node = self.lines.first.?;
            while (true) {
                node = node.next orelse return node.data;
            }
        }
    };

    pub const CharLiteral = struct {
        base: Node = Node{ .id = .CharLiteral },
        token: TokenIndex,

        pub fn iterate(self: *const CharLiteral) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const CharLiteral, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const CharLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const CharLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const BoolLiteral = struct {
        base: Node = Node{ .id = .BoolLiteral },
        token: TokenIndex,

        pub fn iterate(self: *const BoolLiteral) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const BoolLiteral, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const BoolLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const BoolLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const NullLiteral = struct {
        base: Node = Node{ .id = .NullLiteral },
        token: TokenIndex,

        pub fn iterate(self: *const NullLiteral) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const NullLiteral, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const NullLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const NullLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const UndefinedLiteral = struct {
        base: Node = Node{ .id = .UndefinedLiteral },
        token: TokenIndex,

        pub fn iterate(self: *const UndefinedLiteral) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const UndefinedLiteral, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const UndefinedLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const UndefinedLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const AsmOutput = struct {
        base: Node = Node{ .id = .AsmOutput },
        lbracket: TokenIndex,
        symbolic_name: *Node,
        constraint: *Node,
        kind: Kind,
        rparen: TokenIndex,

        pub const Kind = union(enum) {
            Variable: *Identifier,
            Return: *Node,
        };

        pub fn iterate(self: *const AsmOutput) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const AsmOutput, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.symbolic_name;
            i -= 1;

            if (i < 1) return self.constraint;
            i -= 1;

            switch (self.kind) {
                .Variable => |variable_name| {
                    if (i < 1) return &variable_name.base;
                    i -= 1;
                },
                .Return => |return_type| {
                    if (i < 1) return return_type;
                    i -= 1;
                },
            }

            return null;
        }

        pub fn firstToken(self: *const AsmOutput) TokenIndex {
            return self.lbracket;
        }

        pub fn lastToken(self: *const AsmOutput) TokenIndex {
            return self.rparen;
        }
    };

    pub const AsmInput = struct {
        base: Node = Node{ .id = .AsmInput },
        lbracket: TokenIndex,
        symbolic_name: *Node,
        constraint: *Node,
        expr: *Node,
        rparen: TokenIndex,

        pub fn iterate(self: *const AsmInput) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const AsmInput, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.symbolic_name;
            i -= 1;

            if (i < 1) return self.constraint;
            i -= 1;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const AsmInput) TokenIndex {
            return self.lbracket;
        }

        pub fn lastToken(self: *const AsmInput) TokenIndex {
            return self.rparen;
        }
    };

    pub const Asm = struct {
        base: Node = Node{ .id = .Asm },
        asm_token: TokenIndex,
        volatile_token: ?TokenIndex,
        template: *Node,
        outputs: OutputList,
        inputs: InputList,
        clobbers: ClobberList,
        rparen: TokenIndex,

        pub const OutputList = LinkedList(*AsmOutput);
        pub const InputList = LinkedList(*AsmInput);
        pub const ClobberList = LinkedList(*Node);

        pub fn iterate(self: *const Asm) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null};
        }

        pub fn iterateNext(self: *const Asm, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            var output: ?*LinkedList(*AsmOutput).Node = self.outputs.first;
            while (output) |o| {
                if (i < 1) return &o.data.base;
                i -= 1;
                output = o.next;
            }

            var input: ?*LinkedList(*AsmInput).Node = self.inputs.first;
            while (input) |o| {
                if (i < 1) return &o.data.base;
                i -= 1;
                input = o.next;
            }

            return null;
        }

        pub fn firstToken(self: *const Asm) TokenIndex {
            return self.asm_token;
        }

        pub fn lastToken(self: *const Asm) TokenIndex {
            return self.rparen;
        }
    };

    pub const Unreachable = struct {
        base: Node = Node{ .id = .Unreachable },
        token: TokenIndex,

        pub fn iterate(self: *const Unreachable) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const Unreachable, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const Unreachable) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const Unreachable) TokenIndex {
            return self.token;
        }
    };

    pub const ErrorType = struct {
        base: Node = Node{ .id = .ErrorType },
        token: TokenIndex,

        pub fn iterate(self: *const ErrorType) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const ErrorType, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const ErrorType) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const ErrorType) TokenIndex {
            return self.token;
        }
    };

    pub const VarType = struct {
        base: Node = Node{ .id = .VarType },
        token: TokenIndex,

        pub fn iterate(self: *const VarType) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const VarType, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const VarType) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const VarType) TokenIndex {
            return self.token;
        }
    };

    pub const DocComment = struct {
        base: Node = Node{ .id = .DocComment },
        lines: LineList,

        pub const LineList = LinkedList(TokenIndex);

        pub fn iterate(self: *const DocComment) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const DocComment, it: *Node.Iterator) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const DocComment) TokenIndex {
            return self.lines.first.?.data;
        }

        pub fn lastToken(self: *const DocComment) TokenIndex {
            var node = self.lines.first.?;
            while (true) {
                node = node.next orelse return node.data;
            }
        }
    };

    pub const TestDecl = struct {
        base: Node = Node{ .id = .TestDecl },
        doc_comments: ?*DocComment,
        test_token: TokenIndex,
        name: *Node,
        body_node: *Node,

        pub fn iterate(self: *const TestDecl) Node.Iterator {
            return .{ .parent_node = &self.base, .index = 0, .node = null };
        }

        pub fn iterateNext(self: *const TestDecl, it: *Node.Iterator) ?*Node {
            var i = it.index;
            it.index += 1;

            if (i < 1) return self.body_node;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const TestDecl) TokenIndex {
            return self.test_token;
        }

        pub fn lastToken(self: *const TestDecl) TokenIndex {
            return self.body_node.lastToken();
        }
    };
};

test "iterate" {
    var root = Node.Root{
        .base = Node{ .id = Node.Id.Root },
        .decls_len = 0,
        .eof_token = 0,
    };
    var base = &root.base;
    var it = base.iterate();
    testing.expect(it.next() == null);
}
