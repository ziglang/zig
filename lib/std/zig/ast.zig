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
pub const NodeList = std.MultiArrayList(Node);

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

    pub fn extraData(tree: Tree, index: usize, comptime T: type) T {
        const fields = std.meta.fields(T);
        var result: T = undefined;
        inline for (fields) |field, i| {
            comptime assert(field.field_type == Node.Index);
            @field(result, field.name) = tree.extra_data[index + i];
        }
        return result;
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

    pub fn firstToken(tree: Tree, node: Node.Index) TokenIndex {
        const tags = tree.nodes.items(.tag);
        const datas = tree.nodes.items(.data);
        const main_tokens = tree.nodes.items(.main_token);
        const token_tags = tree.tokens.items(.tag);
        var n = node;
        while (true) switch (tags[n]) {
            .Root => return 0,

            .UsingNamespace,
            .TestDecl,
            .ErrDefer,
            .Defer,
            .BoolNot,
            .Negation,
            .BitNot,
            .NegationWrap,
            .AddressOf,
            .Try,
            .Await,
            .OptionalType,
            .Switch,
            .IfSimple,
            .If,
            .Suspend,
            .Resume,
            .Continue,
            .Break,
            .Return,
            .AnyFrameType,
            .Identifier,
            .AnyFrameLiteral,
            .CharLiteral,
            .IntegerLiteral,
            .FloatLiteral,
            .FalseLiteral,
            .TrueLiteral,
            .NullLiteral,
            .UndefinedLiteral,
            .UnreachableLiteral,
            .StringLiteral,
            .GroupedExpression,
            .BuiltinCallTwo,
            .BuiltinCallTwoComma,
            .BuiltinCall,
            .BuiltinCallComma,
            .ErrorSetDecl,
            .AnyType,
            .Comptime,
            .Nosuspend,
            .AsmSimple,
            .Asm,
            .FnProtoSimple,
            .FnProtoMulti,
            .FnProtoOne,
            .FnProto,
            .ArrayType,
            .ArrayTypeSentinel,
            => return main_tokens[n],

            .ArrayInitDot,
            .ArrayInitDotTwo,
            .ArrayInitDotTwoComma,
            .StructInitDot,
            .StructInitDotTwo,
            .StructInitDotTwoComma,
            .EnumLiteral,
            => return main_tokens[n] - 1,

            .Catch,
            .FieldAccess,
            .UnwrapOptional,
            .EqualEqual,
            .BangEqual,
            .LessThan,
            .GreaterThan,
            .LessOrEqual,
            .GreaterOrEqual,
            .AssignMul,
            .AssignDiv,
            .AssignMod,
            .AssignAdd,
            .AssignSub,
            .AssignBitShiftLeft,
            .AssignBitShiftRight,
            .AssignBitAnd,
            .AssignBitXor,
            .AssignBitOr,
            .AssignMulWrap,
            .AssignAddWrap,
            .AssignSubWrap,
            .Assign,
            .MergeErrorSets,
            .Mul,
            .Div,
            .Mod,
            .ArrayMult,
            .MulWrap,
            .Add,
            .Sub,
            .ArrayCat,
            .AddWrap,
            .SubWrap,
            .BitShiftLeft,
            .BitShiftRight,
            .BitAnd,
            .BitXor,
            .BitOr,
            .OrElse,
            .BoolAnd,
            .BoolOr,
            .SliceOpen,
            .Slice,
            .Deref,
            .ArrayAccess,
            .ArrayInitOne,
            .ArrayInit,
            .StructInitOne,
            .StructInit,
            .CallOne,
            .Call,
            .SwitchCaseOne,
            .SwitchRange,
            .FnDecl,
            .ErrorUnion,
            => n = datas[n].lhs,

            .ContainerFieldInit,
            .ContainerFieldAlign,
            .ContainerField,
            => {
                const name_token = main_tokens[n];
                if (name_token > 0 and
                    token_tags[name_token - 1] == .Keyword_comptime)
                {
                    return name_token - 1;
                } else {
                    return name_token;
                }
            },

            .GlobalVarDecl,
            .LocalVarDecl,
            .SimpleVarDecl,
            .AlignedVarDecl,
            => {
                var i = main_tokens[n]; // mut token
                while (i > 0) {
                    i -= 1;
                    switch (token_tags[i]) {
                        .Keyword_extern,
                        .Keyword_export,
                        .Keyword_comptime,
                        .Keyword_pub,
                        .Keyword_threadlocal,
                        .StringLiteral,
                        => continue,

                        else => return i + 1,
                    }
                }
                return i;
            },

            .Block,
            .BlockTwo,
            => {
                // Look for a label.
                const lbrace = main_tokens[n];
                if (token_tags[lbrace - 1] == .Colon) {
                    return lbrace - 2;
                } else {
                    return lbrace;
                }
            },

            .ContainerDecl,
            .ContainerDeclComma,
            .ContainerDeclTwo,
            .ContainerDeclTwoComma,
            .ContainerDeclArg,
            .ContainerDeclArgComma,
            .TaggedUnion,
            .TaggedUnionComma,
            .TaggedUnionTwo,
            .TaggedUnionTwoComma,
            .TaggedUnionEnumTag,
            .TaggedUnionEnumTagComma,
            => {
                const main_token = main_tokens[n];
                switch (token_tags[main_token - 1]) {
                    .Keyword_packed, .Keyword_extern => return main_token - 1,
                    else => return main_token,
                }
            },

            .PtrTypeAligned => unreachable, // TODO
            .PtrTypeSentinel => unreachable, // TODO
            .PtrType => unreachable, // TODO
            .SliceType => unreachable, // TODO
            .SwitchCaseMulti => unreachable, // TODO
            .WhileSimple => unreachable, // TODO
            .WhileCont => unreachable, // TODO
            .While => unreachable, // TODO
            .ForSimple => unreachable, // TODO
            .For => unreachable, // TODO
            .AsmOutput => unreachable, // TODO
            .AsmInput => unreachable, // TODO
            .ErrorValue => unreachable, // TODO
        };
    }

    pub fn lastToken(tree: Tree, node: Node.Index) TokenIndex {
        const tags = tree.nodes.items(.tag);
        const datas = tree.nodes.items(.data);
        const main_tokens = tree.nodes.items(.main_token);
        var n = node;
        var end_offset: TokenIndex = 0;
        while (true) switch (tags[n]) {
            .Root => return @intCast(TokenIndex, tree.tokens.len - 1),

            .UsingNamespace,
            .BoolNot,
            .Negation,
            .BitNot,
            .NegationWrap,
            .AddressOf,
            .Try,
            .Await,
            .OptionalType,
            .Suspend,
            .Resume,
            .Break,
            .Return,
            .Nosuspend,
            .Comptime,
            => n = datas[n].lhs,

            .TestDecl,
            .ErrDefer,
            .Defer,
            .Catch,
            .EqualEqual,
            .BangEqual,
            .LessThan,
            .GreaterThan,
            .LessOrEqual,
            .GreaterOrEqual,
            .AssignMul,
            .AssignDiv,
            .AssignMod,
            .AssignAdd,
            .AssignSub,
            .AssignBitShiftLeft,
            .AssignBitShiftRight,
            .AssignBitAnd,
            .AssignBitXor,
            .AssignBitOr,
            .AssignMulWrap,
            .AssignAddWrap,
            .AssignSubWrap,
            .Assign,
            .MergeErrorSets,
            .Mul,
            .Div,
            .Mod,
            .ArrayMult,
            .MulWrap,
            .Add,
            .Sub,
            .ArrayCat,
            .AddWrap,
            .SubWrap,
            .BitShiftLeft,
            .BitShiftRight,
            .BitAnd,
            .BitXor,
            .BitOr,
            .OrElse,
            .BoolAnd,
            .BoolOr,
            .AnyFrameType,
            .ErrorUnion,
            .IfSimple,
            .WhileSimple,
            .FnDecl,
            => n = datas[n].rhs,

            .FieldAccess,
            .UnwrapOptional,
            .GroupedExpression,
            .StringLiteral,
            => return datas[n].rhs + end_offset,

            .AnyType,
            .AnyFrameLiteral,
            .CharLiteral,
            .IntegerLiteral,
            .FloatLiteral,
            .FalseLiteral,
            .TrueLiteral,
            .NullLiteral,
            .UndefinedLiteral,
            .UnreachableLiteral,
            .Identifier,
            .Deref,
            .EnumLiteral,
            => return main_tokens[n] + end_offset,

            .Call => {
                end_offset += 1; // for the rparen
                const params = tree.extraData(datas[n].rhs, Node.SubRange);
                if (params.end - params.start == 0) {
                    return main_tokens[n] + end_offset;
                }
                n = tree.extra_data[params.end - 1]; // last parameter
            },
            .ContainerDeclArg => {
                const members = tree.extraData(datas[n].rhs, Node.SubRange);
                if (members.end - members.start == 0) {
                    end_offset += 1; // for the rparen
                    n = datas[n].lhs;
                } else {
                    end_offset += 1; // for the rbrace
                    n = tree.extra_data[members.end - 1]; // last parameter
                }
            },
            .ContainerDeclArgComma => {
                const members = tree.extraData(datas[n].rhs, Node.SubRange);
                assert(members.end - members.start > 0);
                end_offset += 2; // for the comma + rbrace
                n = tree.extra_data[members.end - 1]; // last parameter
            },
            .Block,
            .ContainerDecl,
            .TaggedUnion,
            .BuiltinCall,
            => {
                end_offset += 1; // for the rbrace
                if (datas[n].rhs - datas[n].lhs == 0) {
                    return main_tokens[n] + end_offset;
                }
                n = tree.extra_data[datas[n].rhs - 1]; // last statement
            },
            .ContainerDeclComma,
            .TaggedUnionComma,
            .BuiltinCallComma,
            => {
                assert(datas[n].rhs - datas[n].lhs > 0);
                end_offset += 2; // for the comma + rbrace/rparen
                n = tree.extra_data[datas[n].rhs - 1]; // last member
            },
            .CallOne,
            .ArrayAccess,
            => {
                end_offset += 1; // for the rparen/rbracket
                if (datas[n].rhs == 0) {
                    return main_tokens[n] + end_offset;
                }
                n = datas[n].rhs;
            },

            .ArrayInitDotTwo,
            .BuiltinCallTwo,
            .BlockTwo,
            .StructInitDotTwo,
            .ContainerDeclTwo,
            .TaggedUnionTwo,
            => {
                end_offset += 1; // for the rparen/rbrace
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else if (datas[n].lhs != 0) {
                    n = datas[n].lhs;
                } else {
                    return main_tokens[n] + end_offset;
                }
            },
            .ArrayInitDotTwoComma,
            .BuiltinCallTwoComma,
            .StructInitDotTwoComma,
            .ContainerDeclTwoComma,
            .TaggedUnionTwoComma,
            => {
                end_offset += 2; // for the comma + rbrace/rparen
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else if (datas[n].lhs != 0) {
                    n = datas[n].lhs;
                } else {
                    unreachable;
                }
            },
            .SimpleVarDecl => {
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else if (datas[n].lhs != 0) {
                    n = datas[n].lhs;
                } else {
                    end_offset += 1; // from mut token to name
                    return main_tokens[n] + end_offset;
                }
            },
            .AlignedVarDecl => {
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else if (datas[n].lhs != 0) {
                    end_offset += 1; // for the rparen
                    n = datas[n].lhs;
                } else {
                    end_offset += 1; // from mut token to name
                    return main_tokens[n] + end_offset;
                }
            },
            .GlobalVarDecl => {
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else {
                    const extra = tree.extraData(datas[n].lhs, Node.GlobalVarDecl);
                    if (extra.section_node != 0) {
                        end_offset += 1; // for the rparen
                        n = extra.section_node;
                    } else if (extra.align_node != 0) {
                        end_offset += 1; // for the rparen
                        n = extra.align_node;
                    } else if (extra.type_node != 0) {
                        n = extra.type_node;
                    } else {
                        end_offset += 1; // from mut token to name
                        return main_tokens[n] + end_offset;
                    }
                }
            },
            .LocalVarDecl => {
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else {
                    const extra = tree.extraData(datas[n].lhs, Node.LocalVarDecl);
                    if (extra.align_node != 0) {
                        end_offset += 1; // for the rparen
                        n = extra.align_node;
                    } else if (extra.type_node != 0) {
                        n = extra.type_node;
                    } else {
                        end_offset += 1; // from mut token to name
                        return main_tokens[n] + end_offset;
                    }
                }
            },
            .ContainerFieldInit => {
                if (datas[n].rhs != 0) {
                    n = datas[n].rhs;
                } else if (datas[n].lhs != 0) {
                    n = datas[n].lhs;
                } else {
                    return main_tokens[n] + end_offset;
                }
            },
            .ContainerFieldAlign => {
                if (datas[n].rhs != 0) {
                    end_offset += 1; // for the rparen
                    n = datas[n].rhs;
                } else if (datas[n].lhs != 0) {
                    n = datas[n].lhs;
                } else {
                    return main_tokens[n] + end_offset;
                }
            },
            .ContainerField => {
                const extra = tree.extraData(datas[n].rhs, Node.ContainerField);
                if (extra.value_expr != 0) {
                    n = extra.value_expr;
                } else if (extra.align_expr != 0) {
                    end_offset += 1; // for the rparen
                    n = extra.align_expr;
                } else if (datas[n].lhs != 0) {
                    n = datas[n].lhs;
                } else {
                    return main_tokens[n] + end_offset;
                }
            },

            // These are not supported by lastToken() because implementation would
            // require recursion due to the optional comma followed by rbrace.
            // TODO follow the pattern set by StructInitDotTwoComma which will allow
            // lastToken to work for all of these.
            .ArrayInit => unreachable,
            .ArrayInitOne => unreachable,
            .ArrayInitDot => unreachable,
            .StructInit => unreachable,
            .StructInitOne => unreachable,
            .StructInitDot => unreachable,

            .TaggedUnionEnumTag => unreachable, // TODO
            .TaggedUnionEnumTagComma => unreachable, // TODO
            .Switch => unreachable, // TODO
            .If => unreachable, // TODO
            .Continue => unreachable, // TODO
            .ErrorSetDecl => unreachable, // TODO
            .AsmSimple => unreachable, // TODO
            .Asm => unreachable, // TODO
            .SliceOpen => unreachable, // TODO
            .Slice => unreachable, // TODO
            .SwitchCaseOne => unreachable, // TODO
            .SwitchRange => unreachable, // TODO
            .ArrayType => unreachable, // TODO
            .ArrayTypeSentinel => unreachable, // TODO
            .PtrTypeAligned => unreachable, // TODO
            .PtrTypeSentinel => unreachable, // TODO
            .PtrType => unreachable, // TODO
            .SliceType => unreachable, // TODO
            .SwitchCaseMulti => unreachable, // TODO
            .WhileCont => unreachable, // TODO
            .While => unreachable, // TODO
            .ForSimple => unreachable, // TODO
            .For => unreachable, // TODO
            .FnProtoSimple => unreachable, // TODO
            .FnProtoMulti => unreachable, // TODO
            .FnProtoOne => unreachable, // TODO
            .FnProto => unreachable, // TODO
            .AsmOutput => unreachable, // TODO
            .AsmInput => unreachable, // TODO
            .ErrorValue => unreachable, // TODO
        };
    }

    pub fn tokensOnSameLine(tree: Tree, token1: TokenIndex, token2: TokenIndex) bool {
        const token_starts = tree.tokens.items(.start);
        const source = tree.source[token_starts[token1]..token_starts[token2]];
        return mem.indexOfScalar(u8, source, '\n') == null;
    }

    pub fn globalVarDecl(tree: Tree, node: Node.Index) Full.VarDecl {
        assert(tree.nodes.items(.tag)[node] == .GlobalVarDecl);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.lhs, Node.GlobalVarDecl);
        return tree.fullVarDecl(.{
            .type_node = extra.type_node,
            .align_node = extra.align_node,
            .section_node = extra.section_node,
            .init_node = data.rhs,
            .mut_token = tree.nodes.items(.main_token)[node],
        });
    }

    pub fn localVarDecl(tree: Tree, node: Node.Index) Full.VarDecl {
        assert(tree.nodes.items(.tag)[node] == .LocalVarDecl);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.lhs, Node.LocalVarDecl);
        return tree.fullVarDecl(.{
            .type_node = extra.type_node,
            .align_node = extra.align_node,
            .section_node = 0,
            .init_node = data.rhs,
            .mut_token = tree.nodes.items(.main_token)[node],
        });
    }

    pub fn simpleVarDecl(tree: Tree, node: Node.Index) Full.VarDecl {
        assert(tree.nodes.items(.tag)[node] == .SimpleVarDecl);
        const data = tree.nodes.items(.data)[node];
        return tree.fullVarDecl(.{
            .type_node = data.lhs,
            .align_node = 0,
            .section_node = 0,
            .init_node = data.rhs,
            .mut_token = tree.nodes.items(.main_token)[node],
        });
    }

    pub fn alignedVarDecl(tree: Tree, node: Node.Index) Full.VarDecl {
        assert(tree.nodes.items(.tag)[node] == .AlignedVarDecl);
        const data = tree.nodes.items(.data)[node];
        return tree.fullVarDecl(.{
            .type_node = 0,
            .align_node = data.lhs,
            .section_node = 0,
            .init_node = data.rhs,
            .mut_token = tree.nodes.items(.main_token)[node],
        });
    }

    pub fn ifSimple(tree: Tree, node: Node.Index) Full.If {
        assert(tree.nodes.items(.tag)[node] == .IfSimple);
        const data = tree.nodes.items(.data)[node];
        return tree.fullIf(.{
            .cond_expr = data.lhs,
            .then_expr = data.rhs,
            .else_expr = 0,
            .if_token = tree.nodes.items(.main_token)[node],
        });
    }

    pub fn ifFull(tree: Tree, node: Node.Index) Full.If {
        assert(tree.nodes.items(.tag)[node] == .If);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.rhs, Node.If);
        return tree.fullIf(.{
            .cond_expr = data.lhs,
            .then_expr = extra.then_expr,
            .else_expr = extra.else_expr,
            .if_token = tree.nodes.items(.main_token)[node],
        });
    }

    pub fn containerField(tree: Tree, node: Node.Index) Full.ContainerField {
        assert(tree.nodes.items(.tag)[node] == .ContainerField);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.rhs, Node.ContainerField);
        return tree.fullContainerField(.{
            .name_token = tree.nodes.items(.main_token)[node],
            .type_expr = data.lhs,
            .value_expr = extra.value_expr,
            .align_expr = extra.align_expr,
        });
    }

    pub fn containerFieldInit(tree: Tree, node: Node.Index) Full.ContainerField {
        assert(tree.nodes.items(.tag)[node] == .ContainerFieldInit);
        const data = tree.nodes.items(.data)[node];
        return tree.fullContainerField(.{
            .name_token = tree.nodes.items(.main_token)[node],
            .type_expr = data.lhs,
            .value_expr = data.rhs,
            .align_expr = 0,
        });
    }

    pub fn containerFieldAlign(tree: Tree, node: Node.Index) Full.ContainerField {
        assert(tree.nodes.items(.tag)[node] == .ContainerFieldAlign);
        const data = tree.nodes.items(.data)[node];
        return tree.fullContainerField(.{
            .name_token = tree.nodes.items(.main_token)[node],
            .type_expr = data.lhs,
            .value_expr = 0,
            .align_expr = data.rhs,
        });
    }

    pub fn fnProtoSimple(tree: Tree, buffer: *[1]Node.Index, node: Node.Index) Full.FnProto {
        assert(tree.nodes.items(.tag)[node] == .FnProtoSimple);
        const data = tree.nodes.items(.data)[node];
        buffer[0] = data.lhs;
        const params = if (data.lhs == 0) buffer[0..0] else buffer[0..1];
        return tree.fullFnProto(.{
            .fn_token = tree.nodes.items(.main_token)[node],
            .return_type = data.rhs,
            .params = params,
            .align_expr = 0,
            .section_expr = 0,
            .callconv_expr = 0,
        });
    }

    pub fn fnProtoMulti(tree: Tree, node: Node.Index) Full.FnProto {
        assert(tree.nodes.items(.tag)[node] == .FnProtoMulti);
        const data = tree.nodes.items(.data)[node];
        const params_range = tree.extraData(data.lhs, Node.SubRange);
        const params = tree.extra_data[params_range.start..params_range.end];
        return tree.fullFnProto(.{
            .fn_token = tree.nodes.items(.main_token)[node],
            .return_type = data.rhs,
            .params = params,
            .align_expr = 0,
            .section_expr = 0,
            .callconv_expr = 0,
        });
    }

    pub fn fnProtoOne(tree: Tree, buffer: *[1]Node.Index, node: Node.Index) Full.FnProto {
        assert(tree.nodes.items(.tag)[node] == .FnProtoOne);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.lhs, Node.FnProtoOne);
        buffer[0] = extra.param;
        const params = if (extra.param == 0) buffer[0..0] else buffer[0..1];
        return tree.fullFnProto(.{
            .fn_token = tree.nodes.items(.main_token)[node],
            .return_type = data.rhs,
            .params = params,
            .align_expr = extra.align_expr,
            .section_expr = extra.section_expr,
            .callconv_expr = extra.callconv_expr,
        });
    }

    pub fn fnProto(tree: Tree, node: Node.Index) Full.FnProto {
        assert(tree.nodes.items(.tag)[node] == .FnProto);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.lhs, Node.FnProto);
        const params = tree.extra_data[extra.params_start..extra.params_end];
        return tree.fullFnProto(.{
            .fn_token = tree.nodes.items(.main_token)[node],
            .return_type = data.rhs,
            .params = params,
            .align_expr = extra.align_expr,
            .section_expr = extra.section_expr,
            .callconv_expr = extra.callconv_expr,
        });
    }

    pub fn structInitOne(tree: Tree, buffer: *[1]Node.Index, node: Node.Index) Full.StructInit {
        assert(tree.nodes.items(.tag)[node] == .StructInitOne);
        const data = tree.nodes.items(.data)[node];
        buffer[0] = data.rhs;
        const fields = if (data.rhs == 0) buffer[0..0] else buffer[0..1];
        return tree.fullStructInit(.{
            .lbrace = tree.nodes.items(.main_token)[node],
            .fields = fields,
            .type_expr = data.lhs,
        });
    }

    pub fn structInitDotTwo(tree: Tree, buffer: *[2]Node.Index, node: Node.Index) Full.StructInit {
        assert(tree.nodes.items(.tag)[node] == .StructInitDotTwo or
            tree.nodes.items(.tag)[node] == .StructInitDotTwoComma);
        const data = tree.nodes.items(.data)[node];
        buffer.* = .{ data.lhs, data.rhs };
        const fields = if (data.rhs != 0)
            buffer[0..2]
        else if (data.lhs != 0)
            buffer[0..1]
        else
            buffer[0..0];
        return tree.fullStructInit(.{
            .lbrace = tree.nodes.items(.main_token)[node],
            .fields = fields,
            .type_expr = 0,
        });
    }

    pub fn structInitDot(tree: Tree, node: Node.Index) Full.StructInit {
        assert(tree.nodes.items(.tag)[node] == .StructInitDot);
        const data = tree.nodes.items(.data)[node];
        return tree.fullStructInit(.{
            .lbrace = tree.nodes.items(.main_token)[node],
            .fields = tree.extra_data[data.lhs..data.rhs],
            .type_expr = 0,
        });
    }

    pub fn structInit(tree: Tree, node: Node.Index) Full.StructInit {
        assert(tree.nodes.items(.tag)[node] == .StructInit);
        const data = tree.nodes.items(.data)[node];
        const fields_range = tree.extraData(data.rhs, Node.SubRange);
        return tree.fullStructInit(.{
            .lbrace = tree.nodes.items(.main_token)[node],
            .fields = tree.extra_data[fields_range.start..fields_range.end],
            .type_expr = data.lhs,
        });
    }

    pub fn arrayInitOne(tree: Tree, buffer: *[1]Node.Index, node: Node.Index) Full.ArrayInit {
        assert(tree.nodes.items(.tag)[node] == .ArrayInitOne);
        const data = tree.nodes.items(.data)[node];
        buffer[0] = data.rhs;
        const elements = if (data.rhs == 0) buffer[0..0] else buffer[0..1];
        return .{
            .ast = .{
                .lbrace = tree.nodes.items(.main_token)[node],
                .elements = elements,
                .type_expr = data.lhs,
            },
        };
    }

    pub fn arrayInitDotTwo(tree: Tree, buffer: *[2]Node.Index, node: Node.Index) Full.ArrayInit {
        assert(tree.nodes.items(.tag)[node] == .ArrayInitDotTwo or
            tree.nodes.items(.tag)[node] == .ArrayInitDotTwoComma);
        const data = tree.nodes.items(.data)[node];
        buffer.* = .{ data.lhs, data.rhs };
        const elements = if (data.rhs != 0)
            buffer[0..2]
        else if (data.lhs != 0)
            buffer[0..1]
        else
            buffer[0..0];
        return .{
            .ast = .{
                .lbrace = tree.nodes.items(.main_token)[node],
                .elements = elements,
                .type_expr = 0,
            },
        };
    }

    pub fn arrayInitDot(tree: Tree, node: Node.Index) Full.ArrayInit {
        assert(tree.nodes.items(.tag)[node] == .ArrayInitDot);
        const data = tree.nodes.items(.data)[node];
        return .{
            .ast = .{
                .lbrace = tree.nodes.items(.main_token)[node],
                .elements = tree.extra_data[data.lhs..data.rhs],
                .type_expr = 0,
            },
        };
    }

    pub fn arrayInit(tree: Tree, node: Node.Index) Full.ArrayInit {
        assert(tree.nodes.items(.tag)[node] == .ArrayInit);
        const data = tree.nodes.items(.data)[node];
        const elem_range = tree.extraData(data.rhs, Node.SubRange);
        return .{
            .ast = .{
                .lbrace = tree.nodes.items(.main_token)[node],
                .elements = tree.extra_data[elem_range.start..elem_range.end],
                .type_expr = data.lhs,
            },
        };
    }

    pub fn arrayType(tree: Tree, node: Node.Index) Full.ArrayType {
        assert(tree.nodes.items(.tag)[node] == .ArrayType);
        const data = tree.nodes.items(.data)[node];
        return .{
            .ast = .{
                .lbracket = tree.nodes.items(.main_token)[node],
                .elem_count = data.lhs,
                .sentinel = null,
                .elem_type = data.rhs,
            },
        };
    }

    pub fn arrayTypeSentinel(tree: Tree, node: Node.Index) Full.ArrayType {
        assert(tree.nodes.items(.tag)[node] == .ArrayTypeSentinel);
        const data = tree.nodes.items(.data)[node];
        const extra = tree.extraData(data.rhs, Node.ArrayTypeSentinel);
        return .{
            .ast = .{
                .lbracket = tree.nodes.items(.main_token)[node],
                .elem_count = data.lhs,
                .sentinel = extra.sentinel,
                .elem_type = extra.elem_type,
            },
        };
    }

    pub fn containerDeclTwo(tree: Tree, buffer: *[2]Node.Index, node: Node.Index) Full.ContainerDecl {
        assert(tree.nodes.items(.tag)[node] == .ContainerDeclTwo or
            tree.nodes.items(.tag)[node] == .ContainerDeclTwoComma);
        const data = tree.nodes.items(.data)[node];
        buffer.* = .{ data.lhs, data.rhs };
        const members = if (data.rhs != 0)
            buffer[0..2]
        else if (data.lhs != 0)
            buffer[0..1]
        else
            buffer[0..0];
        return tree.fullContainerDecl(.{
            .main_token = tree.nodes.items(.main_token)[node],
            .enum_token = null,
            .members = members,
            .arg = 0,
        });
    }

    pub fn containerDecl(tree: Tree, node: Node.Index) Full.ContainerDecl {
        assert(tree.nodes.items(.tag)[node] == .ContainerDecl or
            tree.nodes.items(.tag)[node] == .ContainerDeclComma);
        const data = tree.nodes.items(.data)[node];
        return tree.fullContainerDecl(.{
            .main_token = tree.nodes.items(.main_token)[node],
            .enum_token = null,
            .members = tree.extra_data[data.lhs..data.rhs],
            .arg = 0,
        });
    }

    pub fn containerDeclArg(tree: Tree, node: Node.Index) Full.ContainerDecl {
        assert(tree.nodes.items(.tag)[node] == .ContainerDeclArg);
        const data = tree.nodes.items(.data)[node];
        const members_range = tree.extraData(data.rhs, Node.SubRange);
        return tree.fullContainerDecl(.{
            .main_token = tree.nodes.items(.main_token)[node],
            .enum_token = null,
            .members = tree.extra_data[members_range.start..members_range.end],
            .arg = data.lhs,
        });
    }

    pub fn taggedUnionTwo(tree: Tree, buffer: *[2]Node.Index, node: Node.Index) Full.ContainerDecl {
        assert(tree.nodes.items(.tag)[node] == .TaggedUnionTwo);
        const data = tree.nodes.items(.data)[node];
        buffer.* = .{ data.lhs, data.rhs };
        const members = if (data.rhs != 0)
            buffer[0..2]
        else if (data.lhs != 0)
            buffer[0..1]
        else
            buffer[0..0];
        const main_token = tree.nodes.items(.main_token)[node];
        return tree.fullContainerDecl(.{
            .main_token = main_token,
            .enum_token = main_token + 2, // union lparen enum
            .members = members,
            .arg = 0,
        });
    }

    pub fn taggedUnion(tree: Tree, node: Node.Index) Full.ContainerDecl {
        assert(tree.nodes.items(.tag)[node] == .TaggedUnion);
        const data = tree.nodes.items(.data)[node];
        const main_token = tree.nodes.items(.main_token)[node];
        return tree.fullContainerDecl(.{
            .main_token = main_token,
            .enum_token = main_token + 2, // union lparen enum
            .members = tree.extra_data[data.lhs..data.rhs],
            .arg = 0,
        });
    }

    pub fn taggedUnionEnumTag(tree: Tree, node: Node.Index) Full.ContainerDecl {
        assert(tree.nodes.items(.tag)[node] == .TaggedUnionEnumTag);
        const data = tree.nodes.items(.data)[node];
        const members_range = tree.extraData(data.rhs, Node.SubRange);
        const main_token = tree.nodes.items(.main_token)[node];
        return tree.fullContainerDecl(.{
            .main_token = main_token,
            .enum_token = main_token + 2, // union lparen enum
            .members = tree.extra_data[data.lhs..data.rhs],
            .arg = data.lhs,
        });
    }

    fn fullVarDecl(tree: Tree, info: Full.VarDecl.Ast) Full.VarDecl {
        const token_tags = tree.tokens.items(.tag);
        var result: Full.VarDecl = .{
            .ast = info,
            .visib_token = null,
            .extern_export_token = null,
            .lib_name = null,
            .threadlocal_token = null,
            .comptime_token = null,
        };
        var i = info.mut_token;
        while (i > 0) {
            i -= 1;
            switch (token_tags[i]) {
                .Keyword_extern, .Keyword_export => result.extern_export_token = i,
                .Keyword_comptime => result.comptime_token = i,
                .Keyword_pub => result.visib_token = i,
                .Keyword_threadlocal => result.threadlocal_token = i,
                .StringLiteral => result.lib_name = i,
                else => break,
            }
        }
        return result;
    }

    fn fullIf(tree: Tree, info: Full.If.Ast) Full.If {
        const token_tags = tree.tokens.items(.tag);
        var result: Full.If = .{
            .ast = info,
            .payload_token = null,
            .error_token = null,
            .else_token = undefined,
        };
        // if (cond_expr) |x|
        //              ^ ^
        const payload_pipe = tree.lastToken(info.cond_expr) + 2;
        if (token_tags[payload_pipe] == .Pipe) {
            result.payload_token = payload_pipe + 1;
        }
        if (info.else_expr != 0) {
            // then_expr else |x|
            //           ^    ^
            result.else_token = tree.lastToken(info.then_expr) + 1;
            if (token_tags[result.else_token + 1] == .Pipe) {
                result.error_token = result.else_token + 2;
            }
        }
        return result;
    }

    fn fullContainerField(tree: Tree, info: Full.ContainerField.Ast) Full.ContainerField {
        const token_tags = tree.tokens.items(.tag);
        var result: Full.ContainerField = .{
            .ast = info,
            .comptime_token = null,
        };
        // comptime name: type = init,
        // ^
        if (info.name_token > 0 and token_tags[info.name_token - 1] == .Keyword_comptime) {
            result.comptime_token = info.name_token - 1;
        }
        return result;
    }

    fn fullFnProto(tree: Tree, info: Full.FnProto.Ast) Full.FnProto {
        const token_tags = tree.tokens.items(.tag);
        var result: Full.FnProto = .{
            .ast = info,
        };
        return result;
    }

    fn fullStructInit(tree: Tree, info: Full.StructInit.Ast) Full.StructInit {
        const token_tags = tree.tokens.items(.tag);
        var result: Full.StructInit = .{
            .ast = info,
        };
        return result;
    }

    fn fullContainerDecl(tree: Tree, info: Full.ContainerDecl.Ast) Full.ContainerDecl {
        const token_tags = tree.tokens.items(.tag);
        var result: Full.ContainerDecl = .{
            .ast = info,
            .layout_token = null,
        };
        switch (token_tags[info.main_token - 1]) {
            .Keyword_extern, .Keyword_packed => result.layout_token = info.main_token - 1,
            else => {},
        }
        return result;
    }
};

/// Fully assembled AST node information.
pub const Full = struct {
    pub const VarDecl = struct {
        visib_token: ?TokenIndex,
        extern_export_token: ?TokenIndex,
        lib_name: ?TokenIndex,
        threadlocal_token: ?TokenIndex,
        comptime_token: ?TokenIndex,
        ast: Ast,

        pub const Ast = struct {
            mut_token: TokenIndex,
            type_node: Node.Index,
            align_node: Node.Index,
            section_node: Node.Index,
            init_node: Node.Index,
        };
    };

    pub const If = struct {
        // Points to the first token after the `|`. Will either be an identifier or
        // a `*` (with an identifier immediately after it).
        payload_token: ?TokenIndex,
        // Points to the identifier after the `|`.
        error_token: ?TokenIndex,
        // Populated only if else_expr != 0.
        else_token: TokenIndex,
        ast: Ast,

        pub const Ast = struct {
            if_token: TokenIndex,
            cond_expr: Node.Index,
            then_expr: Node.Index,
            else_expr: Node.Index,
        };
    };

    pub const ContainerField = struct {
        comptime_token: ?TokenIndex,
        ast: Ast,

        pub const Ast = struct {
            name_token: TokenIndex,
            type_expr: Node.Index,
            value_expr: Node.Index,
            align_expr: Node.Index,
        };
    };

    pub const FnProto = struct {
        ast: Ast,

        pub const Ast = struct {
            fn_token: TokenIndex,
            return_type: Node.Index,
            params: []const Node.Index,
            align_expr: Node.Index,
            section_expr: Node.Index,
            callconv_expr: Node.Index,
        };
    };

    pub const StructInit = struct {
        ast: Ast,

        pub const Ast = struct {
            lbrace: TokenIndex,
            fields: []const Node.Index,
            type_expr: Node.Index,
        };
    };

    pub const ArrayInit = struct {
        ast: Ast,

        pub const Ast = struct {
            lbrace: TokenIndex,
            elements: []const Node.Index,
            type_expr: Node.Index,
        };
    };

    pub const ArrayType = struct {
        ast: Ast,

        pub const Ast = struct {
            lbracket: TokenIndex,
            elem_count: Node.Index,
            sentinel: ?Node.Index,
            elem_type: Node.Index,
        };
    };

    pub const ContainerDecl = struct {
        layout_token: ?TokenIndex,
        ast: Ast,

        pub const Ast = struct {
            main_token: TokenIndex,
            /// Populated when main_token is Keyword_union.
            enum_token: ?TokenIndex,
            members: []const Node.Index,
            arg: Node.Index,
        };
    };
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
    tag: Tag,
    main_token: TokenIndex,
    data: Data,

    pub const Index = u32;

    comptime {
        // Goal is to keep this under one byte for efficiency.
        assert(@sizeOf(Tag) == 1);
    }

    pub const Tag = enum {
        /// sub_list[lhs...rhs]
        Root,
        /// `usingnamespace lhs;`. rhs unused. main_token is `usingnamespace`.
        UsingNamespace,
        /// lhs is test name token (must be string literal), if any.
        /// rhs is the body node.
        TestDecl,
        /// lhs is the index into extra_data.
        /// rhs is the initialization expression, if any.
        /// main_token is `var` or `const`.
        GlobalVarDecl,
        /// `var a: x align(y) = rhs`
        /// lhs is the index into extra_data.
        /// main_token is `var` or `const`.
        LocalVarDecl,
        /// `var a: lhs = rhs`. lhs and rhs may be unused.
        /// Can be local or global.
        /// main_token is `var` or `const`.
        SimpleVarDecl,
        /// `var a align(lhs) = rhs`. lhs and rhs may be unused.
        /// Can be local or global.
        /// main_token is `var` or `const`.
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
        /// Same as `ArrayInitDotTwo` except there is known to be a trailing comma
        /// before the final rbrace.
        ArrayInitDotTwoComma,
        /// `.{a, b}`. `sub_list[lhs..rhs]`.
        ArrayInitDot,
        /// `lhs{a, b}`. `sub_range_list[rhs]`. lhs can be omitted which means `.{a, b}`.
        ArrayInit,
        /// `lhs{.a = rhs}`. rhs can be omitted making it empty.
        /// main_token is the lbrace.
        StructInitOne,
        /// `.{.a = lhs, .b = rhs}`. lhs and rhs can be omitted.
        /// main_token is the lbrace.
        /// No trailing comma before the rbrace.
        StructInitDotTwo,
        /// Same as `StructInitDotTwo` except there is known to be a trailing comma
        /// before the final rbrace. This tag exists to facilitate lastToken() implemented
        /// without recursion.
        StructInitDotTwoComma,
        /// `.{.a = b, .c = d}`. `sub_list[lhs..rhs]`.
        /// main_token is the lbrace.
        StructInitDot,
        /// `lhs{.a = b, .c = d}`. `sub_range_list[rhs]`.
        /// lhs can be omitted which means `.{.a = b, .c = d}`.
        /// main_token is the lbrace.
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
        /// `while (lhs) |x| rhs`.
        WhileSimple,
        /// `while (lhs) : (a) b`. `WhileCont[rhs]`.
        /// `while (lhs) : (a) b`. `WhileCont[rhs]`.
        WhileCont,
        /// `while (lhs) : (a) b else c`. `While[rhs]`.
        /// `while (lhs) |x| : (a) b else c`. `While[rhs]`.
        /// `while (lhs) |x| : (a) b else |y| c`. `While[rhs]`.
        While,
        /// `for (lhs) rhs`.
        ForSimple,
        /// `for (lhs) a else b`. `if_list[rhs]`.
        For,
        /// `if (lhs) rhs`.
        /// `if (lhs) |a| rhs`.
        IfSimple,
        /// `if (lhs) a else b`. `if_list[rhs]`.
        /// `if (lhs) |x| a else b`. `if_list[rhs]`.
        /// `if (lhs) |x| a else |y| b`. `if_list[rhs]`.
        If,
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
        FnProtoMulti,
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
        /// Both lhs and rhs unused.
        AnyFrameLiteral,
        /// Both lhs and rhs unused.
        CharLiteral,
        /// Both lhs and rhs unused.
        IntegerLiteral,
        /// Both lhs and rhs unused.
        FloatLiteral,
        /// Both lhs and rhs unused.
        FalseLiteral,
        /// Both lhs and rhs unused.
        TrueLiteral,
        /// Both lhs and rhs unused.
        NullLiteral,
        /// Both lhs and rhs unused.
        UndefinedLiteral,
        /// Both lhs and rhs unused.
        UnreachableLiteral,
        /// Both lhs and rhs unused.
        /// Most identifiers will not have explicit AST nodes, however for expressions
        /// which could be one of many different kinds of AST nodes, there will be an
        /// Identifier AST node for it.
        Identifier,
        /// lhs is the dot token index, rhs unused, main_token is the identifier.
        EnumLiteral,
        /// main_token is the first token index (redundant with lhs)
        /// lhs is the first token index; rhs is the last token index.
        /// Could be a series of MultilineStringLiteralLine tokens, or a single
        /// StringLiteral token.
        StringLiteral,
        /// `(lhs)`. main_token is the `(`; rhs is the token index of the `)`.
        GroupedExpression,
        /// `@a(lhs, rhs)`. lhs and rhs may be omitted.
        BuiltinCallTwo,
        /// Same as BuiltinCallTwo but there is known to be a trailing comma before the rparen.
        BuiltinCallTwoComma,
        /// `@a(b, c)`. `sub_list[lhs..rhs]`.
        BuiltinCall,
        /// Same as BuiltinCall but there is known to be a trailing comma before the rparen.
        BuiltinCallComma,
        /// `error{a, b}`.
        /// lhs and rhs both unused.
        ErrorSetDecl,
        /// `struct {}`, `union {}`, `opaque {}`, `enum {}`. `extra_data[lhs..rhs]`.
        /// main_token is `struct`, `union`, `opaque`, `enum` keyword.
        ContainerDecl,
        /// Same as ContainerDecl but there is known to be a trailing comma before the rbrace.
        ContainerDeclComma,
        /// `struct {lhs, rhs}`, `union {lhs, rhs}`, `opaque {lhs, rhs}`, `enum {lhs, rhs}`.
        /// lhs or rhs can be omitted.
        /// main_token is `struct`, `union`, `opaque`, `enum` keyword.
        ContainerDeclTwo,
        /// Same as ContainerDeclTwo except there is known to be a trailing comma
        /// before the rbrace.
        ContainerDeclTwoComma,
        /// `union(lhs)` / `enum(lhs)`. `SubRange[rhs]`.
        ContainerDeclArg,
        /// Same as ContainerDeclArg but there is known to be a trailing comma before the rbrace.
        ContainerDeclArgComma,
        /// `union(enum) {}`. `sub_list[lhs..rhs]`.
        /// Note that tagged unions with explicitly provided enums are represented
        /// by `ContainerDeclArg`.
        TaggedUnion,
        /// Same as TaggedUnion but there is known to be a trailing comma before the rbrace.
        TaggedUnionComma,
        /// `union(enum) {lhs, rhs}`. lhs or rhs may be omitted.
        /// Note that tagged unions with explicitly provided enums are represented
        /// by `ContainerDeclArg`.
        TaggedUnionTwo,
        /// Same as TaggedUnionTwo but there is known to be a trailing comma before the rbrace.
        TaggedUnionTwoComma,
        /// `union(enum(lhs)) {}`. `SubRange[rhs]`.
        TaggedUnionEnumTag,
        /// Same as TaggedUnionEnumTag but there is known to be a trailing comma
        /// before the rbrace.
        TaggedUnionEnumTagComma,
        /// `a: lhs = rhs,`. lhs and rhs can be omitted.
        /// main_token is the field name identifier.
        /// lastToken() does not include the possible trailing comma.
        ContainerFieldInit,
        /// `a: lhs align(rhs),`. rhs can be omitted.
        /// main_token is the field name identifier.
        /// lastToken() does not include the possible trailing comma.
        ContainerFieldAlign,
        /// `a: lhs align(c) = d,`. `container_field_list[rhs]`.
        /// main_token is the field name identifier.
        /// lastToken() does not include the possible trailing comma.
        ContainerField,
        /// `anytype`. both lhs and rhs unused.
        /// Used by `ContainerField`.
        AnyType,
        /// `comptime lhs`. rhs unused.
        Comptime,
        /// `nosuspend lhs`. rhs unused.
        Nosuspend,
        /// `{lhs; rhs;}`. rhs or lhs can be omitted.
        /// main_token points at the lbrace.
        BlockTwo,
        /// `{}`. `sub_list[lhs..rhs]`.
        /// main_token points at the lbrace.
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

        pub fn isContainerField(tag: Tag) bool {
            return switch (tag) {
                .ContainerFieldInit,
                .ContainerFieldAlign,
                .ContainerField,
                => true,

                else => false,
            };
        }
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
