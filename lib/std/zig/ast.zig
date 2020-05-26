const std = @import("../std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const Token = std.zig.Token;

pub const TokenIndex = usize;
pub const NodeIndex = usize;

pub const Tree = struct {
    /// Reference to externally-owned data.
    source: []const u8,
    token_ids: []const Token.Id,
    token_locs: []const Token.Loc,
    errors: []const Error,
    root_node: *Node.Root,

    arena: std.heap.ArenaAllocator.State,
    gpa: *mem.Allocator,

    /// translate-c uses this to avoid having to emit correct newlines
    /// TODO get rid of this hack
    generated: bool = false,

    pub fn deinit(self: *Tree) void {
        self.gpa.free(self.token_ids);
        self.gpa.free(self.token_locs);
        self.gpa.free(self.errors);
        self.arena.promote(self.gpa).deinit();
    }

    pub fn renderError(self: *Tree, parse_error: *const Error, stream: var) !void {
        return parse_error.render(self.token_ids, stream);
    }

    pub fn tokenSlice(self: *Tree, token_index: TokenIndex) []const u8 {
        return self.tokenSliceLoc(self.token_locs[token_index]);
    }

    pub fn tokenSliceLoc(self: *Tree, token: Token.Loc) []const u8 {
        return self.source[token.start..token.end];
    }

    pub fn getNodeSource(self: *const Tree, node: *const Node) []const u8 {
        const first_token = self.token_locs[node.firstToken()];
        const last_token = self.token_locs[node.lastToken()];
        return self.source[first_token.start..last_token.end];
    }

    pub const Location = struct {
        line: usize,
        column: usize,
        line_start: usize,
        line_end: usize,
    };

    /// Return the Location of the token relative to the offset specified by `start_index`.
    pub fn tokenLocationLoc(self: *Tree, start_index: usize, token: Token.Loc) Location {
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
        return self.tokenLocationLoc(start_index, self.token_locs[token_index]);
    }

    pub fn tokensOnSameLine(self: *Tree, token1_index: TokenIndex, token2_index: TokenIndex) bool {
        return self.tokensOnSameLineLoc(self.token_locs[token1_index], self.token_locs[token2_index]);
    }

    pub fn tokensOnSameLineLoc(self: *Tree, token1: Token.Loc, token2: Token.Loc) bool {
        return mem.indexOfScalar(u8, self.source[token1.end..token2.start], '\n') == null;
    }

    pub fn dump(self: *Tree) void {
        self.root_node.base.dump(0);
    }

    /// Skips over comments
    pub fn prevToken(self: *Tree, token_index: TokenIndex) TokenIndex {
        var index = token_index - 1;
        while (self.token_ids[index] == Token.Id.LineComment) {
            index -= 1;
        }
        return index;
    }

    /// Skips over comments
    pub fn nextToken(self: *Tree, token_index: TokenIndex) TokenIndex {
        var index = token_index + 1;
        while (self.token_ids[index] == Token.Id.LineComment) {
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

    pub fn render(self: *const Error, tokens: []const Token.Id, stream: var) !void {
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

        pub fn render(self: *const ExpectedCall, tokens: []const Token.Id, stream: var) !void {
            return stream.print("expected " ++ @tagName(Node.Id.Call) ++ ", found {}", .{
                @tagName(self.node.id),
            });
        }
    };

    pub const ExpectedCallOrFnProto = struct {
        node: *Node,

        pub fn render(self: *const ExpectedCallOrFnProto, tokens: []const Token.Id, stream: var) !void {
            return stream.print("expected " ++ @tagName(Node.Id.Call) ++ " or " ++
                @tagName(Node.Id.FnProto) ++ ", found {}", .{@tagName(self.node.id)});
        }
    };

    pub const ExpectedToken = struct {
        token: TokenIndex,
        expected_id: Token.Id,

        pub fn render(self: *const ExpectedToken, tokens: []const Token.Id, stream: var) !void {
            const found_token = tokens[self.token];
            switch (found_token) {
                .Invalid => {
                    return stream.print("expected '{}', found invalid bytes", .{self.expected_id.symbol()});
                },
                else => {
                    const token_name = found_token.symbol();
                    return stream.print("expected '{}', found '{}'", .{ self.expected_id.symbol(), token_name });
                },
            }
        }
    };

    pub const ExpectedCommaOrEnd = struct {
        token: TokenIndex,
        end_id: Token.Id,

        pub fn render(self: *const ExpectedCommaOrEnd, tokens: []const Token.Id, stream: var) !void {
            const actual_token = tokens[self.token];
            return stream.print("expected ',' or '{}', found '{}'", .{
                self.end_id.symbol(),
                actual_token.symbol(),
            });
        }
    };

    fn SingleTokenError(comptime msg: []const u8) type {
        return struct {
            const ThisError = @This();

            token: TokenIndex,

            pub fn render(self: *const ThisError, tokens: []const Token.Id, stream: var) !void {
                const actual_token = tokens[self.token];
                return stream.print(msg, .{actual_token.symbol()});
            }
        };
    }

    fn SimpleError(comptime msg: []const u8) type {
        return struct {
            const ThisError = @This();

            token: TokenIndex,

            pub fn render(self: *const ThisError, tokens: []const Token.Id, stream: var) !void {
                return stream.writeAll(msg);
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
        /// Not all suffix operations are under this tag. To save memory, some
        /// suffix operations have dedicated Node tags.
        SuffixOp,
        /// `T{a, b}`
        ArrayInitializer,
        /// ArrayInitializer but with `.` instead of a left-hand-side operand.
        ArrayInitializerDot,
        /// `T{.a = b}`
        StructInitializer,
        /// StructInitializer but with `.` instead of a left-hand-side operand.
        StructInitializerDot,
        /// `foo()`
        Call,

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
        FieldInitializer,
    };

    pub fn cast(base: *Node, comptime T: type) ?*T {
        if (base.id == comptime typeToId(T)) {
            return @fieldParentPtr(T, "base", base);
        }
        return null;
    }

    pub fn iterate(base: *Node, index: usize) ?*Node {
        inline for (@typeInfo(Id).Enum.fields) |f| {
            if (base.id == @field(Id, f.name)) {
                const T = @field(Node, f.name);
                return @fieldParentPtr(T, "base", base).iterate(index);
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

        pub fn iterate(self: *const Root, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const VarDecl, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const Use, index: usize) ?*Node {
            var i = index;

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
        rbrace_token: TokenIndex,
        decls_len: NodeIndex,

        /// After this the caller must initialize the decls list.
        pub fn alloc(allocator: *mem.Allocator, decls_len: NodeIndex) !*ErrorSetDecl {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(ErrorSetDecl), sizeInBytes(decls_len));
            return @ptrCast(*ErrorSetDecl, bytes.ptr);
        }

        pub fn free(self: *ErrorSetDecl, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.decls_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const ErrorSetDecl, index: usize) ?*Node {
            var i = index;

            if (i < self.decls_len) return self.declsConst()[i];
            i -= self.decls_len;

            return null;
        }

        pub fn firstToken(self: *const ErrorSetDecl) TokenIndex {
            return self.error_token;
        }

        pub fn lastToken(self: *const ErrorSetDecl) TokenIndex {
            return self.rbrace_token;
        }

        pub fn decls(self: *ErrorSetDecl) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(ErrorSetDecl);
            return @ptrCast([*]*Node, decls_start)[0..self.decls_len];
        }

        pub fn declsConst(self: *const ErrorSetDecl) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(ErrorSetDecl);
            return @ptrCast([*]const *Node, decls_start)[0..self.decls_len];
        }

        fn sizeInBytes(decls_len: NodeIndex) usize {
            return @sizeOf(ErrorSetDecl) + @sizeOf(*Node) * @as(usize, decls_len);
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

        pub fn iterate(self: *const ContainerDecl, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const ContainerField, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const ErrorTag, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const Identifier, index: usize) ?*Node {
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

            pub fn iterate(self: *const ParamDecl, index: usize) ?*Node {
                var i = index;

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

        pub fn iterate(self: *const FnProto, index: usize) ?*Node {
            var i = index;

            if (self.lib_name) |lib_name| {
                if (i < 1) return lib_name;
                i -= 1;
            }

            const params_len: usize = if (self.params_len == 0)
                0
            else switch (self.paramsConst()[self.params_len - 1].param_type) {
                .var_type, .type_expr => self.params_len,
                .var_args => self.params_len - 1,
            };
            if (i < params_len) {
                switch (self.paramsConst()[i].param_type) {
                    .var_type => |n| return n,
                    .var_args => unreachable,
                    .type_expr => |n| return n,
                }
            }
            i -= params_len;

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

        pub fn iterate(self: *const AnyFrameType, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const Block, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const Defer, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const Comptime, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const Nosuspend, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const Payload, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const PointerPayload, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const PointerIndexPayload, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const Else, index: usize) ?*Node {
            var i = index;

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

    /// The cases node pointers are found in memory after Switch.
    /// They must be SwitchCase or SwitchElse nodes.
    pub const Switch = struct {
        base: Node = Node{ .id = .Switch },
        switch_token: TokenIndex,
        rbrace: TokenIndex,
        cases_len: NodeIndex,
        expr: *Node,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, cases_len: NodeIndex) !*Switch {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(Switch), sizeInBytes(cases_len));
            return @ptrCast(*Switch, bytes.ptr);
        }

        pub fn free(self: *Switch, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.cases_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const Switch, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            if (i < self.cases_len) return self.casesConst()[i];
            i -= self.cases_len;

            return null;
        }

        pub fn firstToken(self: *const Switch) TokenIndex {
            return self.switch_token;
        }

        pub fn lastToken(self: *const Switch) TokenIndex {
            return self.rbrace;
        }

        pub fn cases(self: *Switch) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(Switch);
            return @ptrCast([*]*Node, decls_start)[0..self.cases_len];
        }

        pub fn casesConst(self: *const Switch) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(Switch);
            return @ptrCast([*]const *Node, decls_start)[0..self.cases_len];
        }

        fn sizeInBytes(cases_len: NodeIndex) usize {
            return @sizeOf(Switch) + @sizeOf(*Node) * @as(usize, cases_len);
        }
    };

    /// Items sub-nodes appear in memory directly following SwitchCase.
    pub const SwitchCase = struct {
        base: Node = Node{ .id = .SwitchCase },
        arrow_token: TokenIndex,
        payload: ?*Node,
        expr: *Node,
        items_len: NodeIndex,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, items_len: NodeIndex) !*SwitchCase {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(SwitchCase), sizeInBytes(items_len));
            return @ptrCast(*SwitchCase, bytes.ptr);
        }

        pub fn free(self: *SwitchCase, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.items_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const SwitchCase, index: usize) ?*Node {
            var i = index;

            if (i < self.items_len) return self.itemsConst()[i];
            i -= self.items_len;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const SwitchCase) TokenIndex {
            return self.itemsConst()[0].firstToken();
        }

        pub fn lastToken(self: *const SwitchCase) TokenIndex {
            return self.expr.lastToken();
        }

        pub fn items(self: *SwitchCase) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(SwitchCase);
            return @ptrCast([*]*Node, decls_start)[0..self.items_len];
        }

        pub fn itemsConst(self: *const SwitchCase) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(SwitchCase);
            return @ptrCast([*]const *Node, decls_start)[0..self.items_len];
        }

        fn sizeInBytes(items_len: NodeIndex) usize {
            return @sizeOf(SwitchCase) + @sizeOf(*Node) * @as(usize, items_len);
        }
    };

    pub const SwitchElse = struct {
        base: Node = Node{ .id = .SwitchElse },
        token: TokenIndex,

        pub fn iterate(self: *const SwitchElse, index: usize) ?*Node {
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

        pub fn iterate(self: *const While, index: usize) ?*Node {
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

        pub fn iterate(self: *const For, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const If, index: usize) ?*Node {
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

        pub fn iterate(self: *const InfixOp, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const PrefixOp, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const FieldInitializer, index: usize) ?*Node {
            var i = index;

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

    /// Elements occur directly in memory after ArrayInitializer.
    pub const ArrayInitializer = struct {
        base: Node = Node{ .id = .ArrayInitializer },
        rtoken: TokenIndex,
        list_len: NodeIndex,
        lhs: *Node,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, list_len: NodeIndex) !*ArrayInitializer {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(ArrayInitializer), sizeInBytes(list_len));
            return @ptrCast(*ArrayInitializer, bytes.ptr);
        }

        pub fn free(self: *ArrayInitializer, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.list_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const ArrayInitializer, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            if (i < self.list_len) return self.listConst()[i];
            i -= self.list_len;

            return null;
        }

        pub fn firstToken(self: *const ArrayInitializer) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const ArrayInitializer) TokenIndex {
            return self.rtoken;
        }

        pub fn list(self: *ArrayInitializer) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(ArrayInitializer);
            return @ptrCast([*]*Node, decls_start)[0..self.list_len];
        }

        pub fn listConst(self: *const ArrayInitializer) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(ArrayInitializer);
            return @ptrCast([*]const *Node, decls_start)[0..self.list_len];
        }

        fn sizeInBytes(list_len: NodeIndex) usize {
            return @sizeOf(ArrayInitializer) + @sizeOf(*Node) * @as(usize, list_len);
        }
    };

    /// Elements occur directly in memory after ArrayInitializerDot.
    pub const ArrayInitializerDot = struct {
        base: Node = Node{ .id = .ArrayInitializerDot },
        dot: TokenIndex,
        rtoken: TokenIndex,
        list_len: NodeIndex,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, list_len: NodeIndex) !*ArrayInitializerDot {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(ArrayInitializerDot), sizeInBytes(list_len));
            return @ptrCast(*ArrayInitializerDot, bytes.ptr);
        }

        pub fn free(self: *ArrayInitializerDot, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.list_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const ArrayInitializerDot, index: usize) ?*Node {
            var i = index;

            if (i < self.list_len) return self.listConst()[i];
            i -= self.list_len;

            return null;
        }

        pub fn firstToken(self: *const ArrayInitializerDot) TokenIndex {
            return self.dot;
        }

        pub fn lastToken(self: *const ArrayInitializerDot) TokenIndex {
            return self.rtoken;
        }

        pub fn list(self: *ArrayInitializerDot) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(ArrayInitializerDot);
            return @ptrCast([*]*Node, decls_start)[0..self.list_len];
        }

        pub fn listConst(self: *const ArrayInitializerDot) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(ArrayInitializerDot);
            return @ptrCast([*]const *Node, decls_start)[0..self.list_len];
        }

        fn sizeInBytes(list_len: NodeIndex) usize {
            return @sizeOf(ArrayInitializerDot) + @sizeOf(*Node) * @as(usize, list_len);
        }
    };

    /// Elements occur directly in memory after StructInitializer.
    pub const StructInitializer = struct {
        base: Node = Node{ .id = .StructInitializer },
        rtoken: TokenIndex,
        list_len: NodeIndex,
        lhs: *Node,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, list_len: NodeIndex) !*StructInitializer {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(StructInitializer), sizeInBytes(list_len));
            return @ptrCast(*StructInitializer, bytes.ptr);
        }

        pub fn free(self: *StructInitializer, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.list_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const StructInitializer, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            if (i < self.list_len) return self.listConst()[i];
            i -= self.list_len;

            return null;
        }

        pub fn firstToken(self: *const StructInitializer) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const StructInitializer) TokenIndex {
            return self.rtoken;
        }

        pub fn list(self: *StructInitializer) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(StructInitializer);
            return @ptrCast([*]*Node, decls_start)[0..self.list_len];
        }

        pub fn listConst(self: *const StructInitializer) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(StructInitializer);
            return @ptrCast([*]const *Node, decls_start)[0..self.list_len];
        }

        fn sizeInBytes(list_len: NodeIndex) usize {
            return @sizeOf(StructInitializer) + @sizeOf(*Node) * @as(usize, list_len);
        }
    };

    /// Elements occur directly in memory after StructInitializerDot.
    pub const StructInitializerDot = struct {
        base: Node = Node{ .id = .StructInitializerDot },
        dot: TokenIndex,
        rtoken: TokenIndex,
        list_len: NodeIndex,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, list_len: NodeIndex) !*StructInitializerDot {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(StructInitializerDot), sizeInBytes(list_len));
            return @ptrCast(*StructInitializerDot, bytes.ptr);
        }

        pub fn free(self: *StructInitializerDot, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.list_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const StructInitializerDot, index: usize) ?*Node {
            var i = index;

            if (i < self.list_len) return self.listConst()[i];
            i -= self.list_len;

            return null;
        }

        pub fn firstToken(self: *const StructInitializerDot) TokenIndex {
            return self.dot;
        }

        pub fn lastToken(self: *const StructInitializerDot) TokenIndex {
            return self.rtoken;
        }

        pub fn list(self: *StructInitializerDot) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(StructInitializerDot);
            return @ptrCast([*]*Node, decls_start)[0..self.list_len];
        }

        pub fn listConst(self: *const StructInitializerDot) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(StructInitializerDot);
            return @ptrCast([*]const *Node, decls_start)[0..self.list_len];
        }

        fn sizeInBytes(list_len: NodeIndex) usize {
            return @sizeOf(StructInitializerDot) + @sizeOf(*Node) * @as(usize, list_len);
        }
    };

    /// Parameter nodes directly follow Call in memory.
    pub const Call = struct {
        base: Node = Node{ .id = .Call },
        lhs: *Node,
        rtoken: TokenIndex,
        params_len: NodeIndex,
        async_token: ?TokenIndex,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, params_len: NodeIndex) !*Call {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(Call), sizeInBytes(params_len));
            return @ptrCast(*Call, bytes.ptr);
        }

        pub fn free(self: *Call, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.params_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const Call, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            if (i < self.params_len) return self.paramsConst()[i];
            i -= self.params_len;

            return null;
        }

        pub fn firstToken(self: *const Call) TokenIndex {
            if (self.async_token) |async_token| return async_token;
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const Call) TokenIndex {
            return self.rtoken;
        }

        pub fn params(self: *Call) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(Call);
            return @ptrCast([*]*Node, decls_start)[0..self.params_len];
        }

        pub fn paramsConst(self: *const Call) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(Call);
            return @ptrCast([*]const *Node, decls_start)[0..self.params_len];
        }

        fn sizeInBytes(params_len: NodeIndex) usize {
            return @sizeOf(Call) + @sizeOf(*Node) * @as(usize, params_len);
        }
    };

    pub const SuffixOp = struct {
        base: Node = Node{ .id = .SuffixOp },
        op: Op,
        lhs: *Node,
        rtoken: TokenIndex,

        pub const Op = union(enum) {
            ArrayAccess: *Node,
            Slice: Slice,
            Deref,
            UnwrapOptional,

            pub const Slice = struct {
                start: *Node,
                end: ?*Node,
                sentinel: ?*Node,
            };
        };

        pub fn iterate(self: *const SuffixOp, index: usize) ?*Node {
            var i = index;

            if (i == 0) return self.lhs;
            i -= 1;

            switch (self.op) {
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

        pub fn iterate(self: *const GroupedExpression, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const ControlFlowExpression, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const Suspend, index: usize) ?*Node {
            var i = index;

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

        pub fn iterate(self: *const IntegerLiteral, index: usize) ?*Node {
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

        pub fn iterate(self: *const EnumLiteral, index: usize) ?*Node {
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

        pub fn iterate(self: *const FloatLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const FloatLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const FloatLiteral) TokenIndex {
            return self.token;
        }
    };

    /// Parameters are in memory following BuiltinCall.
    pub const BuiltinCall = struct {
        base: Node = Node{ .id = .BuiltinCall },
        params_len: NodeIndex,
        builtin_token: TokenIndex,
        rparen_token: TokenIndex,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, params_len: NodeIndex) !*BuiltinCall {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(BuiltinCall), sizeInBytes(params_len));
            return @ptrCast(*BuiltinCall, bytes.ptr);
        }

        pub fn free(self: *BuiltinCall, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.params_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const BuiltinCall, index: usize) ?*Node {
            var i = index;

            if (i < self.params_len) return self.paramsConst()[i];
            i -= self.params_len;

            return null;
        }

        pub fn firstToken(self: *const BuiltinCall) TokenIndex {
            return self.builtin_token;
        }

        pub fn lastToken(self: *const BuiltinCall) TokenIndex {
            return self.rparen_token;
        }

        pub fn params(self: *BuiltinCall) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(BuiltinCall);
            return @ptrCast([*]*Node, decls_start)[0..self.params_len];
        }

        pub fn paramsConst(self: *const BuiltinCall) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(BuiltinCall);
            return @ptrCast([*]const *Node, decls_start)[0..self.params_len];
        }

        fn sizeInBytes(params_len: NodeIndex) usize {
            return @sizeOf(BuiltinCall) + @sizeOf(*Node) * @as(usize, params_len);
        }
    };

    pub const StringLiteral = struct {
        base: Node = Node{ .id = .StringLiteral },
        token: TokenIndex,

        pub fn iterate(self: *const StringLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const StringLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const StringLiteral) TokenIndex {
            return self.token;
        }
    };

    /// The string literal tokens appear directly in memory after MultilineStringLiteral.
    pub const MultilineStringLiteral = struct {
        base: Node = Node{ .id = .MultilineStringLiteral },
        lines_len: TokenIndex,

        /// After this the caller must initialize the lines list.
        pub fn alloc(allocator: *mem.Allocator, lines_len: NodeIndex) !*MultilineStringLiteral {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(MultilineStringLiteral), sizeInBytes(lines_len));
            return @ptrCast(*MultilineStringLiteral, bytes.ptr);
        }

        pub fn free(self: *MultilineStringLiteral, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.lines_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const MultilineStringLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const MultilineStringLiteral) TokenIndex {
            return self.linesConst()[0];
        }

        pub fn lastToken(self: *const MultilineStringLiteral) TokenIndex {
            return self.linesConst()[self.lines_len - 1];
        }

        pub fn lines(self: *MultilineStringLiteral) []TokenIndex {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(MultilineStringLiteral);
            return @ptrCast([*]TokenIndex, decls_start)[0..self.lines_len];
        }

        pub fn linesConst(self: *const MultilineStringLiteral) []const TokenIndex {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(MultilineStringLiteral);
            return @ptrCast([*]const TokenIndex, decls_start)[0..self.lines_len];
        }

        fn sizeInBytes(lines_len: NodeIndex) usize {
            return @sizeOf(MultilineStringLiteral) + @sizeOf(TokenIndex) * @as(usize, lines_len);
        }
    };

    pub const CharLiteral = struct {
        base: Node = Node{ .id = .CharLiteral },
        token: TokenIndex,

        pub fn iterate(self: *const CharLiteral, index: usize) ?*Node {
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

        pub fn iterate(self: *const BoolLiteral, index: usize) ?*Node {
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

        pub fn iterate(self: *const NullLiteral, index: usize) ?*Node {
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

        pub fn iterate(self: *const UndefinedLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const UndefinedLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const UndefinedLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const Asm = struct {
        base: Node = Node{ .id = .Asm },
        asm_token: TokenIndex,
        rparen: TokenIndex,
        volatile_token: ?TokenIndex,
        template: *Node,
        outputs: []Output,
        inputs: []Input,
        /// A clobber node must be a StringLiteral or MultilineStringLiteral.
        clobbers: []*Node,

        pub const Output = struct {
            lbracket: TokenIndex,
            symbolic_name: *Node,
            constraint: *Node,
            kind: Kind,
            rparen: TokenIndex,

            pub const Kind = union(enum) {
                Variable: *Identifier,
                Return: *Node,
            };

            pub fn iterate(self: *const Output, index: usize) ?*Node {
                var i = index;

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

            pub fn firstToken(self: *const Output) TokenIndex {
                return self.lbracket;
            }

            pub fn lastToken(self: *const Output) TokenIndex {
                return self.rparen;
            }
        };

        pub const Input = struct {
            lbracket: TokenIndex,
            symbolic_name: *Node,
            constraint: *Node,
            expr: *Node,
            rparen: TokenIndex,

            pub fn iterate(self: *const Input, index: usize) ?*Node {
                var i = index;

                if (i < 1) return self.symbolic_name;
                i -= 1;

                if (i < 1) return self.constraint;
                i -= 1;

                if (i < 1) return self.expr;
                i -= 1;

                return null;
            }

            pub fn firstToken(self: *const Input) TokenIndex {
                return self.lbracket;
            }

            pub fn lastToken(self: *const Input) TokenIndex {
                return self.rparen;
            }
        };

        pub fn iterate(self: *const Asm, index: usize) ?*Node {
            var i = index;

            if (i < self.outputs.len * 3) switch (i % 3) {
                0 => return self.outputs[i / 3].symbolic_name,
                1 => return self.outputs[i / 3].constraint,
                2 => switch (self.outputs[i / 3].kind) {
                    .Variable => |variable_name| return &variable_name.base,
                    .Return => |return_type| return return_type,
                },
                else => unreachable,
            };
            i -= self.outputs.len * 3;

            if (i < self.inputs.len * 3) switch (i % 3) {
                0 => return self.inputs[i / 3].symbolic_name,
                1 => return self.inputs[i / 3].constraint,
                2 => return self.inputs[i / 3].expr,
                else => unreachable,
            };
            i -= self.inputs.len * 3;

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

        pub fn iterate(self: *const Unreachable, index: usize) ?*Node {
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

        pub fn iterate(self: *const ErrorType, index: usize) ?*Node {
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

        pub fn iterate(self: *const VarType, index: usize) ?*Node {
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
        /// Points to the first doc comment token. API users are expected to iterate over the
        /// tokens array, looking for more doc comments, ignoring line comments, and stopping
        /// at the first other token.
        first_line: TokenIndex,

        pub fn iterate(self: *const DocComment, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const DocComment) TokenIndex {
            return self.first_line;
        }

        /// Returns the first doc comment line. Be careful, this may not be the desired behavior,
        /// which would require the tokens array.
        pub fn lastToken(self: *const DocComment) TokenIndex {
            return self.first_line;
        }
    };

    pub const TestDecl = struct {
        base: Node = Node{ .id = .TestDecl },
        doc_comments: ?*DocComment,
        test_token: TokenIndex,
        name: *Node,
        body_node: *Node,

        pub fn iterate(self: *const TestDecl, index: usize) ?*Node {
            var i = index;

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
    testing.expect(base.iterate(0) == null);
}
