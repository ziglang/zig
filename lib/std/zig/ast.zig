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
            .ArrayInitDotTwo,
            .ArrayInitDot,
            .StructInitDotTwo,
            .StructInitDot,
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
            .EnumLiteral,
            .StringLiteral,
            .GroupedExpression,
            .BuiltinCallTwo,
            .BuiltinCall,
            .ErrorSetDecl,
            .AnyType,
            .Comptime,
            .Nosuspend,
            .Block,
            .AsmSimple,
            .Asm,
            => return main_tokens[n],

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
            .CallOne,
            .Call,
            .SwitchCaseOne,
            .SwitchRange,
            .FnDecl,
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

            .ArrayType => unreachable, // TODO
            .ArrayTypeSentinel => unreachable, // TODO
            .PtrTypeAligned => unreachable, // TODO
            .PtrTypeSentinel => unreachable, // TODO
            .PtrType => unreachable, // TODO
            .SliceType => unreachable, // TODO
            .StructInit => unreachable, // TODO
            .SwitchCaseMulti => unreachable, // TODO
            .WhileSimple => unreachable, // TODO
            .WhileCont => unreachable, // TODO
            .While => unreachable, // TODO
            .ForSimple => unreachable, // TODO
            .For => unreachable, // TODO
            .FnProtoSimple => unreachable, // TODO
            .FnProtoSimpleMulti => unreachable, // TODO
            .FnProtoOne => unreachable, // TODO
            .FnProto => unreachable, // TODO
            .ContainerDecl => unreachable, // TODO
            .ContainerDeclArg => unreachable, // TODO
            .TaggedUnion => unreachable, // TODO
            .TaggedUnionEnumTag => unreachable, // TODO
            .AsmOutput => unreachable, // TODO
            .AsmInput => unreachable, // TODO
            .ErrorValue => unreachable, // TODO
            .ErrorUnion => unreachable, // TODO
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
            .Comptime,
            .Nosuspend,
            .IfSimple,
            .WhileSimple,
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
            => return main_tokens[n] + end_offset,

            .Call,
            .BuiltinCall,
            => {
                end_offset += 1; // for the `)`
                const params = tree.extraData(datas[n].rhs, Node.SubRange);
                if (params.end - params.start == 0) {
                    return main_tokens[n] + end_offset;
                }
                n = tree.extra_data[params.end - 1]; // last parameter
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

            .BuiltinCallTwo => {
                end_offset += 1; // for the rparen
                if (datas[n].rhs == 0) {
                    if (datas[n].lhs == 0) {
                        return main_tokens[n] + end_offset;
                    } else {
                        n = datas[n].lhs;
                    }
                } else {
                    n = datas[n].rhs;
                }
            },

            .ContainerFieldInit => unreachable,
            .ContainerFieldAlign => unreachable,
            .ContainerField => unreachable,

            .ArrayInitDotTwo => unreachable, // TODO
            .ArrayInitDot => unreachable, // TODO
            .StructInitDotTwo => unreachable, // TODO
            .StructInitDot => unreachable, // TODO
            .Switch => unreachable, // TODO
            .If => unreachable, // TODO
            .Continue => unreachable, // TODO
            .EnumLiteral => unreachable, // TODO
            .ErrorSetDecl => unreachable, // TODO
            .Block => unreachable, // TODO
            .AsmSimple => unreachable, // TODO
            .Asm => unreachable, // TODO
            .SliceOpen => unreachable, // TODO
            .Slice => unreachable, // TODO
            .ArrayInitOne => unreachable, // TODO
            .ArrayInit => unreachable, // TODO
            .StructInitOne => unreachable, // TODO
            .SwitchCaseOne => unreachable, // TODO
            .SwitchRange => unreachable, // TODO
            .FnDecl => unreachable, // TODO
            .GlobalVarDecl => unreachable, // TODO
            .LocalVarDecl => unreachable, // TODO
            .SimpleVarDecl => unreachable, // TODO
            .AlignedVarDecl => unreachable, // TODO
            .ArrayType => unreachable, // TODO
            .ArrayTypeSentinel => unreachable, // TODO
            .PtrTypeAligned => unreachable, // TODO
            .PtrTypeSentinel => unreachable, // TODO
            .PtrType => unreachable, // TODO
            .SliceType => unreachable, // TODO
            .StructInit => unreachable, // TODO
            .SwitchCaseMulti => unreachable, // TODO
            .WhileCont => unreachable, // TODO
            .While => unreachable, // TODO
            .ForSimple => unreachable, // TODO
            .For => unreachable, // TODO
            .FnProtoSimple => unreachable, // TODO
            .FnProtoSimpleMulti => unreachable, // TODO
            .FnProtoOne => unreachable, // TODO
            .FnProto => unreachable, // TODO
            .ContainerDecl => unreachable, // TODO
            .ContainerDeclArg => unreachable, // TODO
            .TaggedUnion => unreachable, // TODO
            .TaggedUnionEnumTag => unreachable, // TODO
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
        /// main_token points at the `{`.
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
