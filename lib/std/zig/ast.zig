// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
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

    pub fn renderError(self: *Tree, parse_error: *const Error, stream: anytype) !void {
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
    AsteriskAfterPointerDereference: AsteriskAfterPointerDereference,

    pub fn render(self: *const Error, tokens: []const Token.Id, stream: anytype) !void {
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
            .AsteriskAfterPointerDereference => |*x| return x.render(tokens, stream),
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
            .AsteriskAfterPointerDereference => |x| return x.token,
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
    pub const ExpectedAggregateKw = SingleTokenError("Expected '" ++ Token.Id.Keyword_struct.symbol() ++ "', '" ++ Token.Id.Keyword_union.symbol() ++ "', '" ++ Token.Id.Keyword_enum.symbol() ++ "', or '" ++ Token.Id.Keyword_opaque.symbol() ++ "', found '{}'");
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
    pub const AsteriskAfterPointerDereference = SimpleError("`.*` can't be followed by `*`. Are you missing a space?");

    pub const ExpectedCall = struct {
        node: *Node,

        pub fn render(self: *const ExpectedCall, tokens: []const Token.Id, stream: anytype) !void {
            return stream.print("expected " ++ @tagName(Node.Tag.Call) ++ ", found {}", .{
                @tagName(self.node.tag),
            });
        }
    };

    pub const ExpectedCallOrFnProto = struct {
        node: *Node,

        pub fn render(self: *const ExpectedCallOrFnProto, tokens: []const Token.Id, stream: anytype) !void {
            return stream.print("expected " ++ @tagName(Node.Tag.Call) ++ " or " ++
                @tagName(Node.Tag.FnProto) ++ ", found {}", .{@tagName(self.node.tag)});
        }
    };

    pub const ExpectedToken = struct {
        token: TokenIndex,
        expected_id: Token.Id,

        pub fn render(self: *const ExpectedToken, tokens: []const Token.Id, stream: anytype) !void {
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

        pub fn render(self: *const ExpectedCommaOrEnd, tokens: []const Token.Id, stream: anytype) !void {
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

            pub fn render(self: *const ThisError, tokens: []const Token.Id, stream: anytype) !void {
                const actual_token = tokens[self.token];
                return stream.print(msg, .{actual_token.symbol()});
            }
        };
    }

    fn SimpleError(comptime msg: []const u8) type {
        return struct {
            const ThisError = @This();

            token: TokenIndex,

            pub fn render(self: *const ThisError, tokens: []const Token.Id, stream: anytype) !void {
                return stream.writeAll(msg);
            }
        };
    }
};

pub const Node = struct {
    tag: Tag,

    pub const Tag = enum {
        // Top level
        Root,
        Use,
        TestDecl,

        // Statements
        VarDecl,
        Defer,

        // Infix operators
        Catch,

        // SimpleInfixOp
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
        OrElse,

        // SimplePrefixOp
        AddressOf,
        Await,
        BitNot,
        BoolNot,
        OptionalType,
        Negation,
        NegationWrap,
        Resume,
        Try,

        ArrayType,
        /// ArrayType but has a sentinel node.
        ArrayTypeSentinel,
        PtrType,
        SliceType,
        /// `a[b..c]`
        Slice,
        /// `a.*`
        Deref,
        /// `a.?`
        UnwrapOptional,
        /// `a[b]`
        ArrayAccess,
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
        Suspend,
        Continue,
        Break,
        Return,

        // Type expressions
        AnyType,
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
        LabeledBlock,

        // Misc
        DocComment,
        SwitchCase, // TODO make this not a child of AST Node
        SwitchElse, // TODO make this not a child of AST Node
        Else, // TODO make this not a child of AST Node
        Payload, // TODO make this not a child of AST Node
        PointerPayload, // TODO make this not a child of AST Node
        PointerIndexPayload, // TODO make this not a child of AST Node
        ContainerField,
        ErrorTag, // TODO make this not a child of AST Node
        FieldInitializer, // TODO make this not a child of AST Node

        pub fn Type(tag: Tag) type {
            return switch (tag) {
                .Root => Root,
                .Use => Use,
                .TestDecl => TestDecl,
                .VarDecl => VarDecl,
                .Defer => Defer,
                .Catch => Catch,

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
                .OrElse,
                => SimpleInfixOp,

                .AddressOf,
                .Await,
                .BitNot,
                .BoolNot,
                .OptionalType,
                .Negation,
                .NegationWrap,
                .Resume,
                .Try,
                => SimplePrefixOp,

                .Identifier,
                .BoolLiteral,
                .NullLiteral,
                .UndefinedLiteral,
                .Unreachable,
                .AnyType,
                .ErrorType,
                .IntegerLiteral,
                .FloatLiteral,
                .StringLiteral,
                .CharLiteral,
                => OneToken,

                .Continue,
                .Break,
                .Return,
                => ControlFlowExpression,

                .ArrayType => ArrayType,
                .ArrayTypeSentinel => ArrayTypeSentinel,

                .PtrType => PtrType,
                .SliceType => SliceType,
                .Slice => Slice,
                .Deref, .UnwrapOptional => SimpleSuffixOp,
                .ArrayAccess => ArrayAccess,

                .ArrayInitializer => ArrayInitializer,
                .ArrayInitializerDot => ArrayInitializerDot,

                .StructInitializer => StructInitializer,
                .StructInitializerDot => StructInitializerDot,

                .Call => Call,
                .Switch => Switch,
                .While => While,
                .For => For,
                .If => If,
                .Suspend => Suspend,
                .FnProto => FnProto,
                .AnyFrameType => AnyFrameType,
                .EnumLiteral => EnumLiteral,
                .MultilineStringLiteral => MultilineStringLiteral,
                .GroupedExpression => GroupedExpression,
                .BuiltinCall => BuiltinCall,
                .ErrorSetDecl => ErrorSetDecl,
                .ContainerDecl => ContainerDecl,
                .Asm => Asm,
                .Comptime => Comptime,
                .Nosuspend => Nosuspend,
                .Block => Block,
                .LabeledBlock => LabeledBlock,
                .DocComment => DocComment,
                .SwitchCase => SwitchCase,
                .SwitchElse => SwitchElse,
                .Else => Else,
                .Payload => Payload,
                .PointerPayload => PointerPayload,
                .PointerIndexPayload => PointerIndexPayload,
                .ContainerField => ContainerField,
                .ErrorTag => ErrorTag,
                .FieldInitializer => FieldInitializer,
            };
        }

        pub fn isBlock(tag: Tag) bool {
            return switch (tag) {
                .Block, .LabeledBlock => true,
                else => false,
            };
        }
    };

    /// Prefer `castTag` to this.
    pub fn cast(base: *Node, comptime T: type) ?*T {
        if (std.meta.fieldInfo(T, "base").default_value) |default_base| {
            return base.castTag(default_base.tag);
        }
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            const tag = @intToEnum(Tag, field.value);
            if (base.tag == tag) {
                if (T == tag.Type()) {
                    return @fieldParentPtr(T, "base", base);
                }
                return null;
            }
        }
        unreachable;
    }

    pub fn castTag(base: *Node, comptime tag: Tag) ?*tag.Type() {
        if (base.tag == tag) {
            return @fieldParentPtr(tag.Type(), "base", base);
        }
        return null;
    }

    pub fn iterate(base: *Node, index: usize) ?*Node {
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            const tag = @intToEnum(Tag, field.value);
            if (base.tag == tag) {
                return @fieldParentPtr(tag.Type(), "base", base).iterate(index);
            }
        }
        unreachable;
    }

    pub fn firstToken(base: *const Node) TokenIndex {
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            const tag = @intToEnum(Tag, field.value);
            if (base.tag == tag) {
                return @fieldParentPtr(tag.Type(), "base", base).firstToken();
            }
        }
        unreachable;
    }

    pub fn lastToken(base: *const Node) TokenIndex {
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            const tag = @intToEnum(Tag, field.value);
            if (base.tag == tag) {
                return @fieldParentPtr(tag.Type(), "base", base).lastToken();
            }
        }
        unreachable;
    }

    pub fn requireSemiColon(base: *const Node) bool {
        var n = base;
        while (true) {
            switch (n.tag) {
                .Root,
                .ContainerField,
                .Block,
                .LabeledBlock,
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

                    return !while_node.body.tag.isBlock();
                },
                .For => {
                    const for_node = @fieldParentPtr(For, "base", n);
                    if (for_node.@"else") |@"else"| {
                        n = &@"else".base;
                        continue;
                    }

                    return !for_node.body.tag.isBlock();
                },
                .If => {
                    const if_node = @fieldParentPtr(If, "base", n);
                    if (if_node.@"else") |@"else"| {
                        n = &@"else".base;
                        continue;
                    }

                    return !if_node.body.tag.isBlock();
                },
                .Else => {
                    const else_node = @fieldParentPtr(Else, "base", n);
                    n = else_node.body;
                    continue;
                },
                .Defer => {
                    const defer_node = @fieldParentPtr(Defer, "base", n);
                    return !defer_node.expr.tag.isBlock();
                },
                .Comptime => {
                    const comptime_node = @fieldParentPtr(Comptime, "base", n);
                    return !comptime_node.expr.tag.isBlock();
                },
                .Suspend => {
                    const suspend_node = @fieldParentPtr(Suspend, "base", n);
                    if (suspend_node.body) |body| {
                        return !body.tag.isBlock();
                    }

                    return true;
                },
                .Nosuspend => {
                    const nosuspend_node = @fieldParentPtr(Nosuspend, "base", n);
                    return !nosuspend_node.expr.tag.isBlock();
                },
                else => return true,
            }
        }
    }

    /// Asserts the node is a Block or LabeledBlock and returns the statements slice.
    pub fn blockStatements(base: *Node) []*Node {
        if (base.castTag(.Block)) |block| {
            return block.statements();
        } else if (base.castTag(.LabeledBlock)) |labeled_block| {
            return labeled_block.statements();
        } else {
            unreachable;
        }
    }

    pub fn findFirstWithId(self: *Node, id: Id) ?*Node {
        if (self.id == id) return self;
        var child_i: usize = 0;
        while (self.iterate(child_i)) |child| : (child_i += 1) {
            if (child.findFirstWithId(id)) |result| return result;
        }
        return null;
    }

    pub fn dump(self: *Node, indent: usize) void {
        {
            var i: usize = 0;
            while (i < indent) : (i += 1) {
                std.debug.warn(" ", .{});
            }
        }
        std.debug.warn("{}\n", .{@tagName(self.tag)});

        var child_i: usize = 0;
        while (self.iterate(child_i)) |child| : (child_i += 1) {
            child.dump(indent + 2);
        }
    }

    /// The decls data follows this struct in memory as an array of Node pointers.
    pub const Root = struct {
        base: Node = Node{ .tag = .Root },
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

    /// Trailed in memory by possibly many things, with each optional thing
    /// determined by a bit in `trailer_flags`.
    pub const VarDecl = struct {
        base: Node = Node{ .tag = .VarDecl },
        trailer_flags: TrailerFlags,
        mut_token: TokenIndex,
        name_token: TokenIndex,
        semicolon_token: TokenIndex,

        pub const TrailerFlags = std.meta.TrailerFlags(struct {
            doc_comments: *DocComment,
            visib_token: TokenIndex,
            thread_local_token: TokenIndex,
            eq_token: TokenIndex,
            comptime_token: TokenIndex,
            extern_export_token: TokenIndex,
            lib_name: *Node,
            type_node: *Node,
            align_node: *Node,
            section_node: *Node,
            init_node: *Node,
        });

        pub fn getDocComments(self: *const VarDecl) ?*DocComment {
            return self.getTrailer(.doc_comments);
        }

        pub fn setDocComments(self: *VarDecl, value: *DocComment) void {
            self.setTrailer(.doc_comments, value);
        }

        pub fn getVisibToken(self: *const VarDecl) ?TokenIndex {
            return self.getTrailer(.visib_token);
        }

        pub fn setVisibToken(self: *VarDecl, value: TokenIndex) void {
            self.setTrailer(.visib_token, value);
        }

        pub fn getThreadLocalToken(self: *const VarDecl) ?TokenIndex {
            return self.getTrailer(.thread_local_token);
        }

        pub fn setThreadLocalToken(self: *VarDecl, value: TokenIndex) void {
            self.setTrailer(.thread_local_token, value);
        }

        pub fn getEqToken(self: *const VarDecl) ?TokenIndex {
            return self.getTrailer(.eq_token);
        }

        pub fn setEqToken(self: *VarDecl, value: TokenIndex) void {
            self.setTrailer(.eq_token, value);
        }

        pub fn getComptimeToken(self: *const VarDecl) ?TokenIndex {
            return self.getTrailer(.comptime_token);
        }

        pub fn setComptimeToken(self: *VarDecl, value: TokenIndex) void {
            self.setTrailer(.comptime_token, value);
        }

        pub fn getExternExportToken(self: *const VarDecl) ?TokenIndex {
            return self.getTrailer(.extern_export_token);
        }

        pub fn setExternExportToken(self: *VarDecl, value: TokenIndex) void {
            self.setTrailer(.extern_export_token, value);
        }

        pub fn getLibName(self: *const VarDecl) ?*Node {
            return self.getTrailer(.lib_name);
        }

        pub fn setLibName(self: *VarDecl, value: *Node) void {
            self.setTrailer(.lib_name, value);
        }

        pub fn getTypeNode(self: *const VarDecl) ?*Node {
            return self.getTrailer(.type_node);
        }

        pub fn setTypeNode(self: *VarDecl, value: *Node) void {
            self.setTrailer(.type_node, value);
        }

        pub fn getAlignNode(self: *const VarDecl) ?*Node {
            return self.getTrailer(.align_node);
        }

        pub fn setAlignNode(self: *VarDecl, value: *Node) void {
            self.setTrailer(.align_node, value);
        }

        pub fn getSectionNode(self: *const VarDecl) ?*Node {
            return self.getTrailer(.section_node);
        }

        pub fn setSectionNode(self: *VarDecl, value: *Node) void {
            self.setTrailer(.section_node, value);
        }

        pub fn getInitNode(self: *const VarDecl) ?*Node {
            return self.getTrailer(.init_node);
        }

        pub fn setInitNode(self: *VarDecl, value: *Node) void {
            self.setTrailer(.init_node, value);
        }

        pub const RequiredFields = struct {
            mut_token: TokenIndex,
            name_token: TokenIndex,
            semicolon_token: TokenIndex,
        };

        fn getTrailer(self: *const VarDecl, comptime field: TrailerFlags.FieldEnum) ?TrailerFlags.Field(field) {
            const trailers_start = @ptrCast([*]const u8, self) + @sizeOf(VarDecl);
            return self.trailer_flags.get(trailers_start, field);
        }

        fn setTrailer(self: *VarDecl, comptime field: TrailerFlags.FieldEnum, value: TrailerFlags.Field(field)) void {
            const trailers_start = @ptrCast([*]u8, self) + @sizeOf(VarDecl);
            self.trailer_flags.set(trailers_start, field, value);
        }

        pub fn create(allocator: *mem.Allocator, required: RequiredFields, trailers: TrailerFlags.InitStruct) !*VarDecl {
            const trailer_flags = TrailerFlags.init(trailers);
            const bytes = try allocator.alignedAlloc(u8, @alignOf(VarDecl), sizeInBytes(trailer_flags));
            const var_decl = @ptrCast(*VarDecl, bytes.ptr);
            var_decl.* = .{
                .trailer_flags = trailer_flags,
                .mut_token = required.mut_token,
                .name_token = required.name_token,
                .semicolon_token = required.semicolon_token,
            };
            const trailers_start = bytes.ptr + @sizeOf(VarDecl);
            trailer_flags.setMany(trailers_start, trailers);
            return var_decl;
        }

        pub fn destroy(self: *VarDecl, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.trailer_flags)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const VarDecl, index: usize) ?*Node {
            var i = index;

            if (self.getTypeNode()) |type_node| {
                if (i < 1) return type_node;
                i -= 1;
            }

            if (self.getAlignNode()) |align_node| {
                if (i < 1) return align_node;
                i -= 1;
            }

            if (self.getSectionNode()) |section_node| {
                if (i < 1) return section_node;
                i -= 1;
            }

            if (self.getInitNode()) |init_node| {
                if (i < 1) return init_node;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const VarDecl) TokenIndex {
            if (self.getVisibToken()) |visib_token| return visib_token;
            if (self.getThreadLocalToken()) |thread_local_token| return thread_local_token;
            if (self.getComptimeToken()) |comptime_token| return comptime_token;
            if (self.getExternExportToken()) |extern_export_token| return extern_export_token;
            assert(self.getLibName() == null);
            return self.mut_token;
        }

        pub fn lastToken(self: *const VarDecl) TokenIndex {
            return self.semicolon_token;
        }

        fn sizeInBytes(trailer_flags: TrailerFlags) usize {
            return @sizeOf(VarDecl) + trailer_flags.sizeInBytes();
        }
    };

    pub const Use = struct {
        base: Node = Node{ .tag = .Use },
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
        base: Node = Node{ .tag = .ErrorSetDecl },
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
        base: Node = Node{ .tag = .ContainerDecl },
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
        base: Node = Node{ .tag = .ContainerField },
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
        base: Node = Node{ .tag = .ErrorTag },
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

    pub const OneToken = struct {
        base: Node,
        token: TokenIndex,

        pub fn iterate(self: *const OneToken, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const OneToken) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const OneToken) TokenIndex {
            return self.token;
        }
    };

    /// The params are directly after the FnProto in memory.
    /// Next, each optional thing determined by a bit in `trailer_flags`.
    pub const FnProto = struct {
        base: Node = Node{ .tag = .FnProto },
        trailer_flags: TrailerFlags,
        fn_token: TokenIndex,
        params_len: NodeIndex,
        return_type: ReturnType,

        pub const TrailerFlags = std.meta.TrailerFlags(struct {
            doc_comments: *DocComment,
            body_node: *Node,
            lib_name: *Node, // populated if this is an extern declaration
            align_expr: *Node, // populated if align(A) is present
            section_expr: *Node, // populated if linksection(A) is present
            callconv_expr: *Node, // populated if callconv(A) is present
            visib_token: TokenIndex,
            name_token: TokenIndex,
            var_args_token: TokenIndex,
            extern_export_inline_token: TokenIndex,
            is_extern_prototype: void, // TODO: Remove once extern fn rewriting is
            is_async: void, // TODO: remove once async fn rewriting is
        });

        pub const RequiredFields = struct {
            fn_token: TokenIndex,
            params_len: NodeIndex,
            return_type: ReturnType,
        };

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
                any_type: *Node,
                type_expr: *Node,
            };

            pub fn iterate(self: *const ParamDecl, index: usize) ?*Node {
                var i = index;

                if (i < 1) {
                    switch (self.param_type) {
                        .any_type, .type_expr => |node| return node,
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
                    .any_type, .type_expr => |node| return node.firstToken(),
                }
            }

            pub fn lastToken(self: *const ParamDecl) TokenIndex {
                switch (self.param_type) {
                    .any_type, .type_expr => |node| return node.lastToken(),
                }
            }
        };

        /// For debugging purposes.
        pub fn dump(self: *const FnProto) void {
            const trailers_start = @alignCast(
                @alignOf(ParamDecl),
                @ptrCast([*]const u8, self) + @sizeOf(FnProto) + @sizeOf(ParamDecl) * self.params_len,
            );
            std.debug.print("{*} flags: {b} name_token: {} {*} params_len: {}\n", .{
                self,
                self.trailer_flags.bits,
                self.getNameToken(),
                self.trailer_flags.ptrConst(trailers_start, .name_token),
                self.params_len,
            });
        }

        pub fn getDocComments(self: *const FnProto) ?*DocComment {
            return self.getTrailer(.doc_comments);
        }

        pub fn setDocComments(self: *FnProto, value: *DocComment) void {
            self.setTrailer(.doc_comments, value);
        }

        pub fn getBodyNode(self: *const FnProto) ?*Node {
            return self.getTrailer(.body_node);
        }

        pub fn setBodyNode(self: *FnProto, value: *Node) void {
            self.setTrailer(.body_node, value);
        }

        pub fn getLibName(self: *const FnProto) ?*Node {
            return self.getTrailer(.lib_name);
        }

        pub fn setLibName(self: *FnProto, value: *Node) void {
            self.setTrailer(.lib_name, value);
        }

        pub fn getAlignExpr(self: *const FnProto) ?*Node {
            return self.getTrailer(.align_expr);
        }

        pub fn setAlignExpr(self: *FnProto, value: *Node) void {
            self.setTrailer(.align_expr, value);
        }

        pub fn getSectionExpr(self: *const FnProto) ?*Node {
            return self.getTrailer(.section_expr);
        }

        pub fn setSectionExpr(self: *FnProto, value: *Node) void {
            self.setTrailer(.section_expr, value);
        }

        pub fn getCallconvExpr(self: *const FnProto) ?*Node {
            return self.getTrailer(.callconv_expr);
        }

        pub fn setCallconvExpr(self: *FnProto, value: *Node) void {
            self.setTrailer(.callconv_expr, value);
        }

        pub fn getVisibToken(self: *const FnProto) ?TokenIndex {
            return self.getTrailer(.visib_token);
        }

        pub fn setVisibToken(self: *FnProto, value: TokenIndex) void {
            self.setTrailer(.visib_token, value);
        }

        pub fn getNameToken(self: *const FnProto) ?TokenIndex {
            return self.getTrailer(.name_token);
        }

        pub fn setNameToken(self: *FnProto, value: TokenIndex) void {
            self.setTrailer(.name_token, value);
        }

        pub fn getVarArgsToken(self: *const FnProto) ?TokenIndex {
            return self.getTrailer(.var_args_token);
        }

        pub fn setVarArgsToken(self: *FnProto, value: TokenIndex) void {
            self.setTrailer(.var_args_token, value);
        }

        pub fn getExternExportInlineToken(self: *const FnProto) ?TokenIndex {
            return self.getTrailer(.extern_export_inline_token);
        }

        pub fn setExternExportInlineToken(self: *FnProto, value: TokenIndex) void {
            self.setTrailer(.extern_export_inline_token, value);
        }

        pub fn getIsExternPrototype(self: *const FnProto) ?void {
            return self.getTrailer(.is_extern_prototype);
        }

        pub fn setIsExternPrototype(self: *FnProto, value: void) void {
            self.setTrailer(.is_extern_prototype, value);
        }

        pub fn getIsAsync(self: *const FnProto) ?void {
            return self.getTrailer(.is_async);
        }

        pub fn setIsAsync(self: *FnProto, value: void) void {
            self.setTrailer(.is_async, value);
        }

        fn getTrailer(self: *const FnProto, comptime field: TrailerFlags.FieldEnum) ?TrailerFlags.Field(field) {
            const trailers_start = @alignCast(
                @alignOf(ParamDecl),
                @ptrCast([*]const u8, self) + @sizeOf(FnProto) + @sizeOf(ParamDecl) * self.params_len,
            );
            return self.trailer_flags.get(trailers_start, field);
        }

        fn setTrailer(self: *FnProto, comptime field: TrailerFlags.FieldEnum, value: TrailerFlags.Field(field)) void {
            const trailers_start = @alignCast(
                @alignOf(ParamDecl),
                @ptrCast([*]u8, self) + @sizeOf(FnProto) + @sizeOf(ParamDecl) * self.params_len,
            );
            self.trailer_flags.set(trailers_start, field, value);
        }

        /// After this the caller must initialize the params list.
        pub fn create(allocator: *mem.Allocator, required: RequiredFields, trailers: TrailerFlags.InitStruct) !*FnProto {
            const trailer_flags = TrailerFlags.init(trailers);
            const bytes = try allocator.alignedAlloc(u8, @alignOf(FnProto), sizeInBytes(
                required.params_len,
                trailer_flags,
            ));
            const fn_proto = @ptrCast(*FnProto, bytes.ptr);
            fn_proto.* = .{
                .trailer_flags = trailer_flags,
                .fn_token = required.fn_token,
                .params_len = required.params_len,
                .return_type = required.return_type,
            };
            const trailers_start = @alignCast(
                @alignOf(ParamDecl),
                bytes.ptr + @sizeOf(FnProto) + @sizeOf(ParamDecl) * required.params_len,
            );
            trailer_flags.setMany(trailers_start, trailers);
            return fn_proto;
        }

        pub fn destroy(self: *FnProto, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.params_len, self.trailer_flags)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const FnProto, index: usize) ?*Node {
            var i = index;

            if (self.getLibName()) |lib_name| {
                if (i < 1) return lib_name;
                i -= 1;
            }

            const params_len: usize = if (self.params_len == 0)
                0
            else switch (self.paramsConst()[self.params_len - 1].param_type) {
                .any_type, .type_expr => self.params_len,
            };
            if (i < params_len) {
                switch (self.paramsConst()[i].param_type) {
                    .any_type => |n| return n,
                    .type_expr => |n| return n,
                }
            }
            i -= params_len;

            if (self.getAlignExpr()) |align_expr| {
                if (i < 1) return align_expr;
                i -= 1;
            }

            if (self.getSectionExpr()) |section_expr| {
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

            if (self.getBodyNode()) |body_node| {
                if (i < 1) return body_node;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const FnProto) TokenIndex {
            if (self.getVisibToken()) |visib_token| return visib_token;
            if (self.getExternExportInlineToken()) |extern_export_inline_token| return extern_export_inline_token;
            assert(self.getLibName() == null);
            return self.fn_token;
        }

        pub fn lastToken(self: *const FnProto) TokenIndex {
            if (self.getBodyNode()) |body_node| return body_node.lastToken();
            switch (self.return_type) {
                .Explicit, .InferErrorSet => |node| return node.lastToken(),
                .Invalid => |tok| return tok,
            }
        }

        pub fn params(self: *FnProto) []ParamDecl {
            const params_start = @ptrCast([*]u8, self) + @sizeOf(FnProto);
            return @ptrCast([*]ParamDecl, params_start)[0..self.params_len];
        }

        pub fn paramsConst(self: *const FnProto) []const ParamDecl {
            const params_start = @ptrCast([*]const u8, self) + @sizeOf(FnProto);
            return @ptrCast([*]const ParamDecl, params_start)[0..self.params_len];
        }

        fn sizeInBytes(params_len: NodeIndex, trailer_flags: TrailerFlags) usize {
            return @sizeOf(FnProto) + @sizeOf(ParamDecl) * @as(usize, params_len) + trailer_flags.sizeInBytes();
        }
    };

    pub const AnyFrameType = struct {
        base: Node = Node{ .tag = .AnyFrameType },
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
        base: Node = Node{ .tag = .Block },
        statements_len: NodeIndex,
        lbrace: TokenIndex,
        rbrace: TokenIndex,

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

    /// The statements of the block follow LabeledBlock directly in memory.
    pub const LabeledBlock = struct {
        base: Node = Node{ .tag = .LabeledBlock },
        statements_len: NodeIndex,
        lbrace: TokenIndex,
        rbrace: TokenIndex,
        label: TokenIndex,

        /// After this the caller must initialize the statements list.
        pub fn alloc(allocator: *mem.Allocator, statements_len: NodeIndex) !*LabeledBlock {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(LabeledBlock), sizeInBytes(statements_len));
            return @ptrCast(*LabeledBlock, bytes.ptr);
        }

        pub fn free(self: *LabeledBlock, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.statements_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const LabeledBlock, index: usize) ?*Node {
            var i = index;

            if (i < self.statements_len) return self.statementsConst()[i];
            i -= self.statements_len;

            return null;
        }

        pub fn firstToken(self: *const LabeledBlock) TokenIndex {
            return self.label;
        }

        pub fn lastToken(self: *const LabeledBlock) TokenIndex {
            return self.rbrace;
        }

        pub fn statements(self: *LabeledBlock) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(LabeledBlock);
            return @ptrCast([*]*Node, decls_start)[0..self.statements_len];
        }

        pub fn statementsConst(self: *const LabeledBlock) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(LabeledBlock);
            return @ptrCast([*]const *Node, decls_start)[0..self.statements_len];
        }

        fn sizeInBytes(statements_len: NodeIndex) usize {
            return @sizeOf(LabeledBlock) + @sizeOf(*Node) * @as(usize, statements_len);
        }
    };

    pub const Defer = struct {
        base: Node = Node{ .tag = .Defer },
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
        base: Node = Node{ .tag = .Comptime },
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
        base: Node = Node{ .tag = .Nosuspend },
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
        base: Node = Node{ .tag = .Payload },
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
        base: Node = Node{ .tag = .PointerPayload },
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
        base: Node = Node{ .tag = .PointerIndexPayload },
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
        base: Node = Node{ .tag = .Else },
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
        base: Node = Node{ .tag = .Switch },
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
        base: Node = Node{ .tag = .SwitchCase },
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
        base: Node = Node{ .tag = .SwitchElse },
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
        base: Node = Node{ .tag = .While },
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
        base: Node = Node{ .tag = .For },
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
        base: Node = Node{ .tag = .If },
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

    pub const Catch = struct {
        base: Node = Node{ .tag = .Catch },
        op_token: TokenIndex,
        lhs: *Node,
        rhs: *Node,
        payload: ?*Node,

        pub fn iterate(self: *const Catch, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const Catch) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const Catch) TokenIndex {
            return self.rhs.lastToken();
        }
    };

    pub const SimpleInfixOp = struct {
        base: Node,
        op_token: TokenIndex,
        lhs: *Node,
        rhs: *Node,

        pub fn iterate(self: *const SimpleInfixOp, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const SimpleInfixOp) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const SimpleInfixOp) TokenIndex {
            return self.rhs.lastToken();
        }
    };

    pub const SimplePrefixOp = struct {
        base: Node,
        op_token: TokenIndex,
        rhs: *Node,

        const Self = @This();

        pub fn iterate(self: *const Self, index: usize) ?*Node {
            if (index == 0) return self.rhs;
            return null;
        }

        pub fn firstToken(self: *const Self) TokenIndex {
            return self.op_token;
        }

        pub fn lastToken(self: *const Self) TokenIndex {
            return self.rhs.lastToken();
        }
    };

    pub const ArrayType = struct {
        base: Node = Node{ .tag = .ArrayType },
        op_token: TokenIndex,
        rhs: *Node,
        len_expr: *Node,

        pub fn iterate(self: *const ArrayType, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.len_expr;
            i -= 1;

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const ArrayType) TokenIndex {
            return self.op_token;
        }

        pub fn lastToken(self: *const ArrayType) TokenIndex {
            return self.rhs.lastToken();
        }
    };

    pub const ArrayTypeSentinel = struct {
        base: Node = Node{ .tag = .ArrayTypeSentinel },
        op_token: TokenIndex,
        rhs: *Node,
        len_expr: *Node,
        sentinel: *Node,

        pub fn iterate(self: *const ArrayTypeSentinel, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.len_expr;
            i -= 1;

            if (i < 1) return self.sentinel;
            i -= 1;

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const ArrayTypeSentinel) TokenIndex {
            return self.op_token;
        }

        pub fn lastToken(self: *const ArrayTypeSentinel) TokenIndex {
            return self.rhs.lastToken();
        }
    };

    pub const PtrType = struct {
        base: Node = Node{ .tag = .PtrType },
        op_token: TokenIndex,
        rhs: *Node,
        /// TODO Add a u8 flags field to Node where it would otherwise be padding, and each bit represents
        /// one of these possibly-null things. Then we have them directly follow the PtrType in memory.
        ptr_info: PtrInfo = .{},

        pub fn iterate(self: *const PtrType, index: usize) ?*Node {
            var i = index;

            if (self.ptr_info.sentinel) |sentinel| {
                if (i < 1) return sentinel;
                i -= 1;
            }

            if (self.ptr_info.align_info) |align_info| {
                if (i < 1) return align_info.node;
                i -= 1;
            }

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const PtrType) TokenIndex {
            return self.op_token;
        }

        pub fn lastToken(self: *const PtrType) TokenIndex {
            return self.rhs.lastToken();
        }
    };

    pub const SliceType = struct {
        base: Node = Node{ .tag = .SliceType },
        op_token: TokenIndex,
        rhs: *Node,
        /// TODO Add a u8 flags field to Node where it would otherwise be padding, and each bit represents
        /// one of these possibly-null things. Then we have them directly follow the SliceType in memory.
        ptr_info: PtrInfo = .{},

        pub fn iterate(self: *const SliceType, index: usize) ?*Node {
            var i = index;

            if (self.ptr_info.sentinel) |sentinel| {
                if (i < 1) return sentinel;
                i -= 1;
            }

            if (self.ptr_info.align_info) |align_info| {
                if (i < 1) return align_info.node;
                i -= 1;
            }

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const SliceType) TokenIndex {
            return self.op_token;
        }

        pub fn lastToken(self: *const SliceType) TokenIndex {
            return self.rhs.lastToken();
        }
    };

    pub const FieldInitializer = struct {
        base: Node = Node{ .tag = .FieldInitializer },
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
        base: Node = Node{ .tag = .ArrayInitializer },
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
        base: Node = Node{ .tag = .ArrayInitializerDot },
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
        base: Node = Node{ .tag = .StructInitializer },
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
        base: Node = Node{ .tag = .StructInitializerDot },
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
        base: Node = Node{ .tag = .Call },
        rtoken: TokenIndex,
        lhs: *Node,
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

    pub const ArrayAccess = struct {
        base: Node = Node{ .tag = .ArrayAccess },
        rtoken: TokenIndex,
        lhs: *Node,
        index_expr: *Node,

        pub fn iterate(self: *const ArrayAccess, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            if (i < 1) return self.index_expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const ArrayAccess) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const ArrayAccess) TokenIndex {
            return self.rtoken;
        }
    };

    pub const SimpleSuffixOp = struct {
        base: Node,
        rtoken: TokenIndex,
        lhs: *Node,

        pub fn iterate(self: *const SimpleSuffixOp, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const SimpleSuffixOp) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const SimpleSuffixOp) TokenIndex {
            return self.rtoken;
        }
    };

    pub const Slice = struct {
        base: Node = Node{ .tag = .Slice },
        rtoken: TokenIndex,
        lhs: *Node,
        start: *Node,
        end: ?*Node,
        sentinel: ?*Node,

        pub fn iterate(self: *const Slice, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            if (i < 1) return self.start;
            i -= 1;

            if (self.end) |end| {
                if (i < 1) return end;
                i -= 1;
            }
            if (self.sentinel) |sentinel| {
                if (i < 1) return sentinel;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const Slice) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const Slice) TokenIndex {
            return self.rtoken;
        }
    };

    pub const GroupedExpression = struct {
        base: Node = Node{ .tag = .GroupedExpression },
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

    /// Trailed in memory by possibly many things, with each optional thing
    /// determined by a bit in `trailer_flags`.
    /// Can be: return, break, continue
    pub const ControlFlowExpression = struct {
        base: Node,
        trailer_flags: TrailerFlags,
        ltoken: TokenIndex,

        pub const TrailerFlags = std.meta.TrailerFlags(struct {
            rhs: *Node,
            label: TokenIndex,
        });

        pub const RequiredFields = struct {
            tag: Tag,
            ltoken: TokenIndex,
        };

        pub fn getRHS(self: *const ControlFlowExpression) ?*Node {
            return self.getTrailer(.rhs);
        }

        pub fn setRHS(self: *ControlFlowExpression, value: *Node) void {
            self.setTrailer(.rhs, value);
        }

        pub fn getLabel(self: *const ControlFlowExpression) ?TokenIndex {
            return self.getTrailer(.label);
        }

        pub fn setLabel(self: *ControlFlowExpression, value: TokenIndex) void {
            self.setTrailer(.label, value);
        }

        fn getTrailer(self: *const ControlFlowExpression, comptime field: TrailerFlags.FieldEnum) ?TrailerFlags.Field(field) {
            const trailers_start = @ptrCast([*]const u8, self) + @sizeOf(ControlFlowExpression);
            return self.trailer_flags.get(trailers_start, field);
        }

        fn setTrailer(self: *ControlFlowExpression, comptime field: TrailerFlags.FieldEnum, value: TrailerFlags.Field(field)) void {
            const trailers_start = @ptrCast([*]u8, self) + @sizeOf(ControlFlowExpression);
            self.trailer_flags.set(trailers_start, field, value);
        }

        pub fn create(allocator: *mem.Allocator, required: RequiredFields, trailers: TrailerFlags.InitStruct) !*ControlFlowExpression {
            const trailer_flags = TrailerFlags.init(trailers);
            const bytes = try allocator.alignedAlloc(u8, @alignOf(ControlFlowExpression), sizeInBytes(trailer_flags));
            const ctrl_flow_expr = @ptrCast(*ControlFlowExpression, bytes.ptr);
            ctrl_flow_expr.* = .{
                .base = .{ .tag = required.tag },
                .trailer_flags = trailer_flags,
                .ltoken = required.ltoken,
            };
            const trailers_start = bytes.ptr + @sizeOf(ControlFlowExpression);
            trailer_flags.setMany(trailers_start, trailers);
            return ctrl_flow_expr;
        }

        pub fn destroy(self: *ControlFlowExpression, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.trailer_flags)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const ControlFlowExpression, index: usize) ?*Node {
            var i = index;

            if (self.getRHS()) |rhs| {
                if (i < 1) return rhs;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const ControlFlowExpression) TokenIndex {
            return self.ltoken;
        }

        pub fn lastToken(self: *const ControlFlowExpression) TokenIndex {
            if (self.getRHS()) |rhs| {
                return rhs.lastToken();
            }

            if (self.getLabel()) |label| {
                return label;
            }

            return self.ltoken;
        }

        fn sizeInBytes(trailer_flags: TrailerFlags) usize {
            return @sizeOf(ControlFlowExpression) + trailer_flags.sizeInBytes();
        }
    };

    pub const Suspend = struct {
        base: Node = Node{ .tag = .Suspend },
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

    pub const EnumLiteral = struct {
        base: Node = Node{ .tag = .EnumLiteral },
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

    /// Parameters are in memory following BuiltinCall.
    pub const BuiltinCall = struct {
        base: Node = Node{ .tag = .BuiltinCall },
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

    /// The string literal tokens appear directly in memory after MultilineStringLiteral.
    pub const MultilineStringLiteral = struct {
        base: Node = Node{ .tag = .MultilineStringLiteral },
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

    pub const Asm = struct {
        base: Node = Node{ .tag = .Asm },
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
                Variable: *OneToken,
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

    /// TODO remove from the Node base struct
    /// TODO actually maybe remove entirely in favor of iterating backward from Node.firstToken()
    /// and forwards to find same-line doc comments.
    pub const DocComment = struct {
        base: Node = Node{ .tag = .DocComment },
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
        base: Node = Node{ .tag = .TestDecl },
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

pub const PtrInfo = struct {
    allowzero_token: ?TokenIndex = null,
    align_info: ?Align = null,
    const_token: ?TokenIndex = null,
    volatile_token: ?TokenIndex = null,
    sentinel: ?*Node = null,

    pub const Align = struct {
        node: *Node,
        bit_range: ?BitRange = null,

        pub const BitRange = struct {
            start: *Node,
            end: *Node,
        };
    };
};

test "iterate" {
    var root = Node.Root{
        .base = Node{ .tag = Node.Tag.Root },
        .decls_len = 0,
        .eof_token = 0,
    };
    var base = &root.base;
    testing.expect(base.iterate(0) == null);
}
