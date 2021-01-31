// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const Token = std.zig.Token;

pub const TokenIndex = u32;
pub const ByteOffset = u32;

pub const TokenList = std.MultiArrayList(struct {
    tag: Token.Tag,
    start: ByteOffset,
});
pub const NodeList = std.MultiArrayList(struct {
    tag: Node.Tag,
    main_token: TokenIndex,
    data: Node.Data,
});

pub const Tree = struct {
    /// Reference to externally-owned data.
    source: []const u8,

    tokens: TokenList.Slice,
    /// The root AST node is assumed to be index 0. Since there can be no
    /// references to the root node, this means 0 is available to indicate null.
    nodes: NodeList.Slice,
    extra_data: []Node.Index,

    errors: []const Error,

    pub const Location = struct {
        line: usize,
        column: usize,
        line_start: usize,
        line_end: usize,
    };

    pub fn deinit(tree: *Tree, gpa: *mem.Allocator) void {
        tree.tokens.deinit(gpa);
        tree.nodes.deinit(gpa);
        gpa.free(tree.extra_data);
        gpa.free(tree.errors);
        tree.* = undefined;
    }

    pub fn tokenLocation(self: Tree, start_offset: ByteOffset, token_index: TokenIndex) Location {
        var loc = Location{
            .line = 0,
            .column = 0,
            .line_start = start_offset,
            .line_end = self.source.len,
        };
        const token_start = self.tokens.items(.start)[token_index];
        for (self.source[start_offset..]) |c, i| {
            if (i + start_offset == token_start) {
                loc.line_end = i + start_offset;
                while (loc.line_end < self.source.len and self.source[loc.line_end] != '\n') {
                    loc.line_end += 1;
                }
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

    pub fn renderError(tree: Tree, parse_error: Error, stream: anytype) !void {
        const tokens = tree.tokens.items(.tag);
        switch (parse_error) {
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
            .ExpectedCall => |x| return x.render(tree, stream),
            .ExpectedCallOrFnProto => |x| return x.render(tree, stream),
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

    pub fn errorToken(tree: Tree, parse_error: Error) TokenIndex {
        switch (parse_error) {
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
            .ExpectedCall => |x| return tree.nodes.items(.main_token)[x.node],
            .ExpectedCallOrFnProto => |x| return tree.nodes.items(.main_token)[x.node],
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

    /// Skips over comments.
    pub fn prevToken(self: *const Tree, token_index: TokenIndex) TokenIndex {
        const token_tags = self.tokens.items(.tag);
        var index = token_index - 1;
        while (token_tags[index] == .LineComment) {
            index -= 1;
        }
        return index;
    }

    /// Skips over comments.
    pub fn nextToken(self: *const Tree, token_index: TokenIndex) TokenIndex {
        const token_tags = self.tokens.items(.tag);
        var index = token_index + 1;
        while (token_tags[index] == .LineComment) {
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

    pub const InvalidToken = SingleTokenError("Invalid token '{s}'");
    pub const ExpectedContainerMembers = SingleTokenError("Expected test, comptime, var decl, or container field, found '{s}'");
    pub const ExpectedStringLiteral = SingleTokenError("Expected string literal, found '{s}'");
    pub const ExpectedIntegerLiteral = SingleTokenError("Expected integer literal, found '{s}'");
    pub const ExpectedIdentifier = SingleTokenError("Expected identifier, found '{s}'");
    pub const ExpectedStatement = SingleTokenError("Expected statement, found '{s}'");
    pub const ExpectedVarDeclOrFn = SingleTokenError("Expected variable declaration or function, found '{s}'");
    pub const ExpectedVarDecl = SingleTokenError("Expected variable declaration, found '{s}'");
    pub const ExpectedFn = SingleTokenError("Expected function, found '{s}'");
    pub const ExpectedReturnType = SingleTokenError("Expected 'var' or return type expression, found '{s}'");
    pub const ExpectedAggregateKw = SingleTokenError("Expected '" ++ Token.Tag.Keyword_struct.symbol() ++ "', '" ++ Token.Tag.Keyword_union.symbol() ++ "', '" ++ Token.Tag.Keyword_enum.symbol() ++ "', or '" ++ Token.Tag.Keyword_opaque.symbol() ++ "', found '{s}'");
    pub const ExpectedEqOrSemi = SingleTokenError("Expected '=' or ';', found '{s}'");
    pub const ExpectedSemiOrLBrace = SingleTokenError("Expected ';' or '{{', found '{s}'");
    pub const ExpectedSemiOrElse = SingleTokenError("Expected ';' or 'else', found '{s}'");
    pub const ExpectedLBrace = SingleTokenError("Expected '{{', found '{s}'");
    pub const ExpectedLabelOrLBrace = SingleTokenError("Expected label or '{{', found '{s}'");
    pub const ExpectedColonOrRParen = SingleTokenError("Expected ':' or ')', found '{s}'");
    pub const ExpectedLabelable = SingleTokenError("Expected 'while', 'for', 'inline', 'suspend', or '{{', found '{s}'");
    pub const ExpectedInlinable = SingleTokenError("Expected 'while' or 'for', found '{s}'");
    pub const ExpectedAsmOutputReturnOrType = SingleTokenError("Expected '->' or '" ++ Token.Tag.Identifier.symbol() ++ "', found '{s}'");
    pub const ExpectedSliceOrRBracket = SingleTokenError("Expected ']' or '..', found '{s}'");
    pub const ExpectedTypeExpr = SingleTokenError("Expected type expression, found '{s}'");
    pub const ExpectedPrimaryTypeExpr = SingleTokenError("Expected primary type expression, found '{s}'");
    pub const ExpectedExpr = SingleTokenError("Expected expression, found '{s}'");
    pub const ExpectedPrimaryExpr = SingleTokenError("Expected primary expression, found '{s}'");
    pub const ExpectedParamList = SingleTokenError("Expected parameter list, found '{s}'");
    pub const ExpectedPayload = SingleTokenError("Expected loop payload, found '{s}'");
    pub const ExpectedBlockOrAssignment = SingleTokenError("Expected block or assignment, found '{s}'");
    pub const ExpectedBlockOrExpression = SingleTokenError("Expected block or expression, found '{s}'");
    pub const ExpectedExprOrAssignment = SingleTokenError("Expected expression or assignment, found '{s}'");
    pub const ExpectedPrefixExpr = SingleTokenError("Expected prefix expression, found '{s}'");
    pub const ExpectedLoopExpr = SingleTokenError("Expected loop expression, found '{s}'");
    pub const ExpectedDerefOrUnwrap = SingleTokenError("Expected pointer dereference or optional unwrap, found '{s}'");
    pub const ExpectedSuffixOp = SingleTokenError("Expected pointer dereference, optional unwrap, or field access, found '{s}'");
    pub const ExpectedBlockOrField = SingleTokenError("Expected block or field, found '{s}'");

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
        node: Node.Index,

        pub fn render(self: ExpectedCall, tree: Tree, stream: anytype) !void {
            const node_tag = tree.nodes.items(.tag)[self.node];
            return stream.print("expected " ++ @tagName(Node.Tag.Call) ++ ", found {s}", .{
                @tagName(node_tag),
            });
        }
    };

    pub const ExpectedCallOrFnProto = struct {
        node: Node.Index,

        pub fn render(self: ExpectedCallOrFnProto, tree: Tree, stream: anytype) !void {
            const node_tag = tree.nodes.items(.tag)[self.node];
            return stream.print("expected " ++ @tagName(Node.Tag.Call) ++ " or " ++
                @tagName(Node.Tag.FnProto) ++ ", found {s}", .{@tagName(node_tag)});
        }
    };

    pub const ExpectedToken = struct {
        token: TokenIndex,
        expected_id: Token.Tag,

        pub fn render(self: *const ExpectedToken, tokens: []const Token.Tag, stream: anytype) !void {
            const found_token = tokens[self.token];
            switch (found_token) {
                .Invalid => {
                    return stream.print("expected '{s}', found invalid bytes", .{self.expected_id.symbol()});
                },
                else => {
                    const token_name = found_token.symbol();
                    return stream.print("expected '{s}', found '{s}'", .{ self.expected_id.symbol(), token_name });
                },
            }
        }
    };

    pub const ExpectedCommaOrEnd = struct {
        token: TokenIndex,
        end_id: Token.Tag,

        pub fn render(self: *const ExpectedCommaOrEnd, tokens: []const Token.Tag, stream: anytype) !void {
            const actual_token = tokens[self.token];
            return stream.print("expected ',' or '{s}', found '{s}'", .{
                self.end_id.symbol(),
                actual_token.symbol(),
            });
        }
    };

    fn SingleTokenError(comptime msg: []const u8) type {
        return struct {
            const ThisError = @This();

            token: TokenIndex,

            pub fn render(self: *const ThisError, tokens: []const Token.Tag, stream: anytype) !void {
                const actual_token = tokens[self.token];
                return stream.print(msg, .{actual_token.symbol()});
            }
        };
    }

    fn SimpleError(comptime msg: []const u8) type {
        return struct {
            const ThisError = @This();

            token: TokenIndex,

            pub fn render(self: *const ThisError, tokens: []const Token.Tag, stream: anytype) !void {
                return stream.writeAll(msg);
            }
        };
    }

    pub fn loc(self: Error) TokenIndex {
        switch (self) {
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
            .ExpectedCall => |x| @panic("TODO redo ast errors"),
            .ExpectedCallOrFnProto => |x| @panic("TODO redo ast errors"),
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
};

pub const Node = struct {
    index: Index,

    pub const Index = u32;

    comptime {
        // Goal is to keep this under one byte for efficiency.
        assert(@sizeOf(Tag) == 1);
    }

    pub const Tag = enum {
        /// sub_list[lhs...rhs]
        Root,
        /// lhs is the sub-expression. rhs is unused.
        UsingNamespace,
        /// lhs is test name token (must be string literal), if any.
        /// rhs is the body node.
        TestDecl,
        /// lhs is the index into global_var_decl_list.
        /// rhs is the initialization expression, if any.
        GlobalVarDecl,
        /// `var a: x align(y) = rhs`
        /// lhs is the index into local_var_decl_list.
        LocalVarDecl,
        /// `var a: lhs = rhs`. lhs and rhs may be unused.
        /// Can be local or global.
        SimpleVarDecl,
        /// `var a align(lhs) = rhs`. lhs and rhs may be unused.
        /// Can be local or global.
        AlignedVarDecl,
        /// lhs is the identifier token payload if any,
        /// rhs is the deferred expression.
        ErrDefer,
        /// lhs is unused.
        /// rhs is the deferred expression.
        Defer,
        /// lhs is target expr; rhs is fallback expr.
        /// payload is determined by looking at the prev tokens before rhs.
        Catch,
        /// `lhs.a`. main_token is the dot. rhs is the identifier token index.
        FieldAccess,
        /// `lhs.?`. main_token is the dot. rhs is the `?` token index.
        UnwrapOptional,
        /// `lhs == rhs`. main_token is op.
        EqualEqual,
        /// `lhs != rhs`. main_token is op.
        BangEqual,
        /// `lhs < rhs`. main_token is op.
        LessThan,
        /// `lhs > rhs`. main_token is op.
        GreaterThan,
        /// `lhs <= rhs`. main_token is op.
        LessOrEqual,
        /// `lhs >= rhs`. main_token is op.
        GreaterOrEqual,
        /// `lhs *= rhs`. main_token is op.
        AssignMul,
        /// `lhs /= rhs`. main_token is op.
        AssignDiv,
        /// `lhs *= rhs`. main_token is op.
        AssignMod,
        /// `lhs += rhs`. main_token is op.
        AssignAdd,
        /// `lhs -= rhs`. main_token is op.
        AssignSub,
        /// `lhs <<= rhs`. main_token is op.
        AssignBitShiftLeft,
        /// `lhs >>= rhs`. main_token is op.
        AssignBitShiftRight,
        /// `lhs &= rhs`. main_token is op.
        AssignBitAnd,
        /// `lhs ^= rhs`. main_token is op.
        AssignBitXor,
        /// `lhs |= rhs`. main_token is op.
        AssignBitOr,
        /// `lhs *%= rhs`. main_token is op.
        AssignMulWrap,
        /// `lhs +%= rhs`. main_token is op.
        AssignAddWrap,
        /// `lhs -%= rhs`. main_token is op.
        AssignSubWrap,
        /// `lhs = rhs`. main_token is op.
        Assign,
        /// `lhs || rhs`. main_token is the `||`.
        MergeErrorSets,
        /// `lhs * rhs`. main_token is the `*`.
        Mul,
        /// `lhs / rhs`. main_token is the `/`.
        Div,
        /// `lhs % rhs`. main_token is the `%`.
        Mod,
        /// `lhs ** rhs`. main_token is the `**`.
        ArrayMult,
        /// `lhs *% rhs`. main_token is the `*%`.
        MulWrap,
        /// `lhs + rhs`. main_token is the `+`.
        Add,
        /// `lhs - rhs`. main_token is the `-`.
        Sub,
        /// `lhs ++ rhs`. main_token is the `++`.
        ArrayCat,
        /// `lhs +% rhs`. main_token is the `+%`.
        AddWrap,
        /// `lhs -% rhs`. main_token is the `-%`.
        SubWrap,
        /// `lhs << rhs`. main_token is the `<<`.
        BitShiftLeft,
        /// `lhs >> rhs`. main_token is the `>>`.
        BitShiftRight,
        /// `lhs & rhs`. main_token is the `&`.
        BitAnd,
        /// `lhs ^ rhs`. main_token is the `^`.
        BitXor,
        /// `lhs | rhs`. main_token is the `|`.
        BitOr,
        /// `lhs orelse rhs`. main_token is the `orelse`.
        OrElse,
        /// `lhs and rhs`. main_token is the `and`.
        BoolAnd,
        /// `lhs or rhs`. main_token is the `or`.
        BoolOr,
        /// `op lhs`. rhs unused. main_token is op.
        BoolNot,
        /// `op lhs`. rhs unused. main_token is op.
        Negation,
        /// `op lhs`. rhs unused. main_token is op.
        BitNot,
        /// `op lhs`. rhs unused. main_token is op.
        NegationWrap,
        /// `op lhs`. rhs unused. main_token is op.
        AddressOf,
        /// `op lhs`. rhs unused. main_token is op.
        Try,
        /// `op lhs`. rhs unused. main_token is op.
        Await,
        /// `?lhs`. rhs unused. main_token is the `?`.
        OptionalType,
        /// `[lhs]rhs`. lhs can be omitted to make it a slice.
        ArrayType,
        /// `[lhs:a]b`. `ArrayTypeSentinel[rhs]`.
        ArrayTypeSentinel,
        /// `[*]align(lhs) rhs`. lhs can be omitted.
        /// `*align(lhs) rhs`. lhs can be omitted.
        /// `[]rhs`.
        PtrTypeAligned,
        /// `[*:lhs]rhs`. lhs can be omitted.
        /// `*rhs`.
        /// `[:lhs]rhs`.
        PtrTypeSentinel,
        /// lhs is index into PtrType. rhs is the element type expression.
        PtrType,
        /// lhs is index into SliceType. rhs is the element type expression.
        /// Can be pointer or slice, depending on main_token.
        SliceType,
        /// `lhs[rhs..]`
        /// main_token is the `[`.
        SliceOpen,
        /// `lhs[b..c :d]`. `slice_list[rhs]`.
        /// main_token is the `[`.
        Slice,
        /// `lhs.*`. rhs is unused.
        Deref,
        /// `lhs[rhs]`.
        ArrayAccess,
        /// `lhs{rhs}`. rhs can be omitted.
        ArrayInitOne,
        /// `.{lhs, rhs}`. lhs and rhs can be omitted.
        ArrayInitDotTwo,
        /// `.{a, b}`. `sub_list[lhs..rhs]`.
        ArrayInitDot,
        /// `lhs{a, b}`. `sub_range_list[rhs]`. lhs can be omitted which means `.{a, b}`.
        ArrayInit,
        /// `lhs{.a = rhs}`. rhs can be omitted making it empty.
        StructInitOne,
        /// `.{.a = lhs, .b = rhs}`. lhs and rhs can be omitted.
        StructInitDotTwo,
        /// `.{.a = b, .c = d}`. `sub_list[lhs..rhs]`.
        StructInitDot,
        /// `lhs{.a = b, .c = d}`. `sub_range_list[rhs]`.
        /// lhs can be omitted which means `.{.a = b, .c = d}`.
        StructInit,
        /// `lhs(rhs)`. rhs can be omitted.
        CallOne,
        /// `lhs(a, b, c)`. `sub_range_list[rhs]`.
        /// main_token is the `(`.
        Call,
        /// `switch(lhs) {}`. `sub_range_list[rhs]`.
        Switch,
        /// `lhs => rhs`. If lhs is omitted it means `else`.
        /// main_token is the `=>`
        SwitchCaseOne,
        /// `a, b, c => rhs`. `sub_range_list[lhs]`.
        SwitchCaseMulti,
        /// `lhs...rhs`.
        SwitchRange,
        /// `while (lhs) rhs`.
        WhileSimple,
        /// `while (lhs) |x| rhs`.
        WhileSimpleOptional,
        /// `while (lhs) : (a) b`. `WhileCont[rhs]`.
        WhileCont,
        /// `while (lhs) : (a) b`. `WhileCont[rhs]`.
        WhileContOptional,
        /// `while (lhs) : (a) b else c`. `While[rhs]`.
        While,
        /// `while (lhs) |x| : (a) b else c`. `While[rhs]`.
        WhileOptional,
        /// `while (lhs) |x| : (a) b else |y| c`. `While[rhs]`.
        WhileError,
        /// `for (lhs) rhs`.
        ForSimple,
        /// `for (lhs) a else b`. `if_list[rhs]`.
        For,
        /// `if (lhs) rhs`.
        IfSimple,
        /// `if (lhs) |a| rhs`.
        IfSimpleOptional,
        /// `if (lhs) a else b`. `if_list[rhs]`.
        If,
        /// `if (lhs) |x| a else b`. `if_list[rhs]`.
        IfOptional,
        /// `if (lhs) |x| a else |y| b`. `if_list[rhs]`.
        IfError,
        /// `suspend lhs`. lhs can be omitted. rhs is unused.
        Suspend,
        /// `resume lhs`. rhs is unused.
        Resume,
        /// `continue`. lhs is token index of label if any. rhs is unused.
        Continue,
        /// `break rhs`. rhs can be omitted. lhs is label token index, if any.
        Break,
        /// `return lhs`. lhs can be omitted. rhs is unused.
        Return,
        /// `fn(a: lhs) rhs`. lhs can be omitted.
        /// anytype and ... parameters are omitted from the AST tree.
        FnProtoSimple,
        /// `fn(a: b, c: d) rhs`. `sub_range_list[lhs]`.
        /// anytype and ... parameters are omitted from the AST tree.
        FnProtoSimpleMulti,
        /// `fn(a: b) rhs linksection(e) callconv(f)`. lhs is index into extra_data.
        /// zero or one parameters.
        /// anytype and ... parameters are omitted from the AST tree.
        FnProtoOne,
        /// `fn(a: b, c: d) rhs linksection(e) callconv(f)`. `fn_proto_list[lhs]`.
        /// anytype and ... parameters are omitted from the AST tree.
        FnProto,
        /// lhs is the FnProto, rhs is the function body block.
        FnDecl,
        /// `anyframe->rhs`. main_token is `anyframe`. `lhs` is arrow token index.
        AnyFrameType,
        /// Could be integer literal, float literal, char literal, bool literal,
        /// null literal, undefined literal, unreachable, depending on the token.
        /// Both lhs and rhs unused.
        OneToken,
        /// Both lhs and rhs unused.
        /// Most identifiers will not have explicit AST nodes, however for expressions
        /// which could be one of many different kinds of AST nodes, there will be an
        /// Identifier AST node for it.
        Identifier,
        /// lhs is the dot token index, rhs unused, main_token is the identifier.
        EnumLiteral,
        /// Both lhs and rhs unused.
        MultilineStringLiteral,
        /// `(lhs)`. main_token is the `(`; rhs is the token index of the `)`.
        GroupedExpression,
        /// `@a(lhs, rhs)`. lhs and rhs may be omitted.
        BuiltinCallTwo,
        /// `@a(b, c)`. `sub_list[lhs..rhs]`.
        BuiltinCall,
        /// `error{a, b}`.
        /// lhs and rhs both unused.
        ErrorSetDecl,
        /// `struct {}`, `union {}`, etc. `sub_list[lhs..rhs]`.
        ContainerDecl,
        /// `union(lhs)` / `enum(lhs)`. `sub_range_list[rhs]`.
        ContainerDeclArg,
        /// `union(enum) {}`. `sub_list[lhs..rhs]`.
        /// Note that tagged unions with explicitly provided enums are represented
        /// by `ContainerDeclArg`.
        TaggedUnion,
        /// `union(enum(lhs)) {}`. `sub_list_range[rhs]`.
        TaggedUnionEnumTag,
        /// `a: lhs = rhs,`. lhs and rhs can be omitted.
        ContainerFieldInit,
        /// `a: lhs align(rhs),`. rhs can be omitted.
        ContainerFieldAlign,
        /// `a: lhs align(c) = d,`. `container_field_list[rhs]`.
        ContainerField,
        /// `anytype`. both lhs and rhs unused.
        /// Used by `ContainerField`.
        AnyType,
        /// `comptime lhs`. rhs unused.
        Comptime,
        /// `nosuspend lhs`. rhs unused.
        Nosuspend,
        /// `{}`. `sub_list[lhs..rhs]`.
        Block,
        /// `asm(lhs)`. rhs unused.
        AsmSimple,
        /// `asm(lhs, a)`. `sub_range_list[rhs]`.
        Asm,
        /// `[a] "b" (c)`. lhs is string literal token index, rhs is 0.
        /// `[a] "b" (-> rhs)`. lhs is the string literal token index, rhs is type expr.
        /// main_token is `a`.
        AsmOutput,
        /// `[a] "b" (rhs)`. lhs is string literal token index.
        /// main_token is `a`.
        AsmInput,
        /// `error.a`. lhs is token index of `.`. rhs is token index of `a`.
        ErrorValue,
        /// `lhs!rhs`. main_token is the `!`.
        ErrorUnion,
    };

    pub const Data = struct {
        lhs: Index,
        rhs: Index,
    };

    pub const LocalVarDecl = struct {
        type_node: Index,
        align_node: Index,
    };

    pub const ArrayTypeSentinel = struct {
        elem_type: Index,
        sentinel: Index,
    };

    pub const PtrType = struct {
        sentinel: Index,
        align_node: Index,
        bit_range_start: Index,
        bit_range_end: Index,
    };

    pub const SliceType = struct {
        sentinel: Index,
        align_node: Index,
    };
    pub const SubRange = struct {
        /// Index into sub_list.
        start: Index,
        /// Index into sub_list.
        end: Index,
    };

    pub const If = struct {
        then_expr: Index,
        else_expr: Index,
    };

    pub const ContainerField = struct {
        value_expr: Index,
        align_expr: Index,
    };

    pub const GlobalVarDecl = struct {
        type_node: Index,
        align_node: Index,
        section_node: Index,
    };

    pub const Slice = struct {
        start: Index,
        end: Index,
        sentinel: Index,
    };

    pub const While = struct {
        continue_expr: Index,
        then_expr: Index,
        else_expr: Index,
    };

    pub const WhileCont = struct {
        continue_expr: Index,
        then_expr: Index,
    };

    pub const FnProtoOne = struct {
        /// Populated if there is exactly 1 parameter. Otherwise there are 0 parameters.
        param: Index,
        /// Populated if align(A) is present.
        align_expr: Index,
        /// Populated if linksection(A) is present.
        section_expr: Index,
        /// Populated if callconv(A) is present.
        callconv_expr: Index,
    };

    pub const FnProto = struct {
        params_start: Index,
        params_end: Index,
        /// Populated if align(A) is present.
        align_expr: Index,
        /// Populated if linksection(A) is present.
        section_expr: Index,
        /// Populated if callconv(A) is present.
        callconv_expr: Index,
    };
};
