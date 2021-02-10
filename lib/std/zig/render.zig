// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const meta = std.meta;
const ast = std.zig.ast;
const Token = std.zig.Token;

const indent_delta = 4;
const asm_indent_delta = 2;

pub const Error = error{
    /// Ran out of memory allocating call stack frames to complete rendering, or
    /// ran out of memory allocating space in the output buffer.
    OutOfMemory,
};

const Writer = std.ArrayList(u8).Writer;
const Ais = std.io.AutoIndentingStream(Writer);

/// `gpa` is used for allocating the resulting formatted source code, as well as
/// for allocating extra stack memory if needed, because this function utilizes recursion.
/// Note: that's not actually true yet, see https://github.com/ziglang/zig/issues/1006.
/// Caller owns the returned slice of bytes, allocated with `gpa`.
pub fn render(gpa: *mem.Allocator, tree: ast.Tree) Error![]u8 {
    assert(tree.errors.len == 0); // Cannot render an invalid tree.

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    var auto_indenting_stream = std.io.autoIndentingStream(indent_delta, buffer.writer());
    try renderRoot(&auto_indenting_stream, tree);
    return buffer.toOwnedSlice();
}

/// Assumes there are no tokens in between start and end.
fn renderComments(ais: *Ais, tree: ast.Tree, start: usize, end: usize, prefix: []const u8) Error!usize {
    var index: usize = start;
    var count: usize = 0;
    while (true) {
        const comment_start = index +
            (mem.indexOf(u8, tree.source[index..end], "//") orelse return count);
        const newline = comment_start +
            mem.indexOfScalar(u8, tree.source[comment_start..end], '\n').?;
        const untrimmed_comment = tree.source[comment_start..newline];
        const trimmed_comment = mem.trimRight(u8, untrimmed_comment, " \r\t");
        if (count == 0) {
            count += 1;
            try ais.writer().writeAll(prefix);
        } else {
            // If another newline occurs between prev comment and this one
            // we honor it, but not any additional ones.
            if (mem.indexOfScalar(u8, tree.source[index..comment_start], '\n') != null) {
                try ais.insertNewline();
            }
        }
        try ais.writer().print("{s}\n", .{trimmed_comment});
        index = newline + 1;
    }
}

fn renderRoot(ais: *Ais, tree: ast.Tree) Error!void {
    // Render all the line comments at the beginning of the file.
    const src_start: usize = if (mem.startsWith(u8, tree.source, "\xEF\xBB\xBF")) 3 else 0;
    const comment_end_loc: usize = tree.tokens.items(.start)[0];
    _ = try renderComments(ais, tree, src_start, comment_end_loc, "");

    // Root is always index 0.
    const nodes_data = tree.nodes.items(.data);
    const root_decls = tree.extra_data[nodes_data[0].lhs..nodes_data[0].rhs];

    for (root_decls) |decl| {
        try renderMember(ais, tree, decl, .Newline);
    }
}

fn renderExtraNewline(ais: *Ais, tree: ast.Tree, node: ast.Node.Index) Error!void {
    return renderExtraNewlineToken(ais, tree, tree.firstToken(node));
}

fn renderExtraNewlineToken(ais: *Ais, tree: ast.Tree, first_token: ast.TokenIndex) Error!void {
    if (first_token == 0) return;
    const token_starts = tree.tokens.items(.start);
    if (tree.tokenLocation(token_starts[first_token - 1], first_token).line >= 2) {
        return ais.insertNewline();
    }
}

fn renderMember(ais: *Ais, tree: ast.Tree, decl: ast.Node.Index, space: Space) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const datas = tree.nodes.items(.data);
    try renderDocComments(ais, tree, tree.firstToken(decl));
    switch (tree.nodes.items(.tag)[decl]) {
        .FnDecl => {
            // Some examples:
            // pub extern "foo" fn ...
            // export fn ...
            const fn_proto = datas[decl].lhs;
            const fn_token = main_tokens[fn_proto];
            // Go back to the first token we should render here.
            var i = fn_token;
            while (i > 0) {
                i -= 1;
                switch (token_tags[i]) {
                    .Keyword_extern,
                    .Keyword_export,
                    .Keyword_pub,
                    .StringLiteral,
                    => continue,

                    else => {
                        i += 1;
                        break;
                    },
                }
            }
            while (i < fn_token) : (i += 1) {
                try renderToken(ais, tree, i, .Space);
            }
            try renderExpression(ais, tree, fn_proto, .Space);
            return renderExpression(ais, tree, datas[decl].rhs, space);
        },
        .FnProtoSimple,
        .FnProtoMulti,
        .FnProtoOne,
        .FnProto,
        => {
            try renderExpression(ais, tree, decl, .None);
            return renderToken(ais, tree, tree.lastToken(decl) + 1, space); // semicolon
        },

        .UsingNamespace => {
            const main_token = main_tokens[decl];
            const expr = datas[decl].lhs;
            if (main_token > 0 and token_tags[main_token - 1] == .Keyword_pub) {
                try renderToken(ais, tree, main_token - 1, .Space); // pub
            }
            try renderToken(ais, tree, main_token, .Space); // usingnamespace
            try renderExpression(ais, tree, expr, .None);
            return renderToken(ais, tree, tree.lastToken(expr) + 1, space); // ;
        },

        .GlobalVarDecl => return renderVarDecl(ais, tree, tree.globalVarDecl(decl)),
        .LocalVarDecl => return renderVarDecl(ais, tree, tree.localVarDecl(decl)),
        .SimpleVarDecl => return renderVarDecl(ais, tree, tree.simpleVarDecl(decl)),
        .AlignedVarDecl => return renderVarDecl(ais, tree, tree.alignedVarDecl(decl)),

        .TestDecl => {
            const test_token = main_tokens[decl];
            try renderToken(ais, tree, test_token, .Space);
            if (token_tags[test_token + 1] == .StringLiteral) {
                try renderToken(ais, tree, test_token + 1, .Space);
            }
            try renderExpression(ais, tree, datas[decl].rhs, space);
        },

        .ContainerFieldInit => return renderContainerField(ais, tree, tree.containerFieldInit(decl), space),
        .ContainerFieldAlign => return renderContainerField(ais, tree, tree.containerFieldAlign(decl), space),
        .ContainerField => return renderContainerField(ais, tree, tree.containerField(decl), space),
        .Comptime => return renderExpression(ais, tree, decl, space),

        .Root => unreachable,
        else => unreachable,
    }
}

fn renderExpression(ais: *Ais, tree: ast.Tree, node: ast.Node.Index, space: Space) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const node_tags = tree.nodes.items(.tag);
    const datas = tree.nodes.items(.data);
    switch (node_tags[node]) {
        .Identifier,
        .IntegerLiteral,
        .FloatLiteral,
        .StringLiteral,
        .CharLiteral,
        .TrueLiteral,
        .FalseLiteral,
        .NullLiteral,
        .UnreachableLiteral,
        .UndefinedLiteral,
        .AnyFrameLiteral,
        => return renderToken(ais, tree, main_tokens[node], space),

        .ErrorValue => unreachable, // TODO

        .AnyType => return renderToken(ais, tree, main_tokens[node], space),

        .BlockTwo,
        .BlockTwoSemicolon,
        => {
            const statements = [2]ast.Node.Index{ datas[node].lhs, datas[node].rhs };
            if (datas[node].lhs == 0) {
                return renderBlock(ais, tree, node, statements[0..0], space);
            } else if (datas[node].rhs == 0) {
                return renderBlock(ais, tree, node, statements[0..1], space);
            } else {
                return renderBlock(ais, tree, node, statements[0..2], space);
            }
        },
        .Block,
        .BlockSemicolon,
        => {
            const statements = tree.extra_data[datas[node].lhs..datas[node].rhs];
            return renderBlock(ais, tree, node, statements, space);
        },

        .ErrDefer => {
            const defer_token = main_tokens[node];
            const payload_token = datas[node].lhs;
            const expr = datas[node].rhs;

            try renderToken(ais, tree, defer_token, .Space);
            if (payload_token != 0) {
                try renderToken(ais, tree, payload_token - 1, .None); // |
                try renderToken(ais, tree, payload_token, .None); // identifier
                try renderToken(ais, tree, payload_token + 1, .Space); // |
            }
            return renderExpression(ais, tree, expr, space);
        },

        .Defer => {
            const defer_token = main_tokens[node];
            const expr = datas[node].rhs;
            try renderToken(ais, tree, defer_token, .Space);
            return renderExpression(ais, tree, expr, space);
        },
        .Comptime, .Nosuspend => {
            const comptime_token = main_tokens[node];
            const block = datas[node].lhs;
            try renderToken(ais, tree, comptime_token, .Space);
            return renderExpression(ais, tree, block, space);
        },

        .Suspend => {
            const suspend_token = main_tokens[node];
            const body = datas[node].lhs;
            if (body != 0) {
                try renderToken(ais, tree, suspend_token, .Space);
                return renderExpression(ais, tree, body, space);
            } else {
                return renderToken(ais, tree, suspend_token, space);
            }
        },

        .Catch => {
            const main_token = main_tokens[node];
            const fallback_first = tree.firstToken(datas[node].rhs);

            const same_line = tree.tokensOnSameLine(main_token, fallback_first);
            const after_op_space = if (same_line) Space.Space else Space.Newline;

            try renderExpression(ais, tree, datas[node].lhs, .Space); // target

            if (token_tags[fallback_first - 1] == .Pipe) {
                try renderToken(ais, tree, main_token, .Space); // catch keyword
                try renderToken(ais, tree, main_token + 1, .None); // pipe
                try renderToken(ais, tree, main_token + 2, .None); // payload identifier
                try renderToken(ais, tree, main_token + 3, after_op_space); // pipe
            } else {
                assert(token_tags[fallback_first - 1] == .Keyword_catch);
                try renderToken(ais, tree, main_token, after_op_space); // catch keyword
            }

            ais.pushIndentOneShot();
            try renderExpression(ais, tree, datas[node].rhs, space); // fallback
        },

        .FieldAccess => {
            const field_access = datas[node];
            try renderExpression(ais, tree, field_access.lhs, .None);
            try renderToken(ais, tree, main_tokens[node], .None);
            return renderToken(ais, tree, field_access.rhs, space);
        },

        .ErrorUnion,
        .SwitchRange,
        => {
            const infix = datas[node];
            try renderExpression(ais, tree, infix.lhs, .None);
            try renderToken(ais, tree, main_tokens[node], .None);
            return renderExpression(ais, tree, infix.rhs, space);
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
        .GreaterOrEqual,
        .GreaterThan,
        .LessOrEqual,
        .LessThan,
        .MergeErrorSets,
        .Mod,
        .Mul,
        .MulWrap,
        .Sub,
        .SubWrap,
        .OrElse,
        => {
            const infix = datas[node];
            try renderExpression(ais, tree, infix.lhs, .Space);
            const op_token = main_tokens[node];
            if (tree.tokensOnSameLine(op_token, op_token + 1)) {
                try renderToken(ais, tree, op_token, .Space);
            } else {
                ais.pushIndent();
                try renderToken(ais, tree, op_token, .Newline);
                ais.popIndent();
                ais.pushIndentOneShot();
            }
            return renderExpression(ais, tree, infix.rhs, space);
        },

        .BitNot,
        .BoolNot,
        .Negation,
        .NegationWrap,
        .OptionalType,
        .AddressOf,
        => {
            try renderToken(ais, tree, main_tokens[node], .None);
            return renderExpression(ais, tree, datas[node].lhs, space);
        },

        .Try,
        .Resume,
        .Await,
        => {
            try renderToken(ais, tree, main_tokens[node], .Space);
            return renderExpression(ais, tree, datas[node].lhs, space);
        },

        .ArrayType => return renderArrayType(ais, tree, tree.arrayType(node), space),
        .ArrayTypeSentinel => return renderArrayType(ais, tree, tree.arrayTypeSentinel(node), space),

        .PtrTypeAligned => return renderPtrType(ais, tree, tree.ptrTypeAligned(node), space),
        .PtrTypeSentinel => return renderPtrType(ais, tree, tree.ptrTypeSentinel(node), space),
        .PtrType => return renderPtrType(ais, tree, tree.ptrType(node), space),
        .PtrTypeBitRange => return renderPtrType(ais, tree, tree.ptrTypeBitRange(node), space),

        .ArrayInitOne => {
            var elements: [1]ast.Node.Index = undefined;
            return renderArrayInit(ais, tree, tree.arrayInitOne(&elements, node), space);
        },
        .ArrayInitDotTwo, .ArrayInitDotTwoComma => {
            var elements: [2]ast.Node.Index = undefined;
            return renderArrayInit(ais, tree, tree.arrayInitDotTwo(&elements, node), space);
        },
        .ArrayInitDot => return renderArrayInit(ais, tree, tree.arrayInitDot(node), space),
        .ArrayInit => return renderArrayInit(ais, tree, tree.arrayInit(node), space),

        .StructInitOne => {
            var fields: [1]ast.Node.Index = undefined;
            return renderStructInit(ais, tree, tree.structInitOne(&fields, node), space);
        },
        .StructInitDotTwo, .StructInitDotTwoComma => {
            var fields: [2]ast.Node.Index = undefined;
            return renderStructInit(ais, tree, tree.structInitDotTwo(&fields, node), space);
        },
        .StructInitDot => return renderStructInit(ais, tree, tree.structInitDot(node), space),
        .StructInit => return renderStructInit(ais, tree, tree.structInit(node), space),

        .CallOne => unreachable, // TODO
        .Call => {
            const call = datas[node];
            const params_range = tree.extraData(call.rhs, ast.Node.SubRange);
            const params = tree.extra_data[params_range.start..params_range.end];
            const async_token = tree.firstToken(call.lhs) - 1;
            if (token_tags[async_token] == .Keyword_async) {
                try renderToken(ais, tree, async_token, .Space);
            }
            try renderExpression(ais, tree, call.lhs, .None);

            const lparen = main_tokens[node];

            if (params.len == 0) {
                try renderToken(ais, tree, lparen, .None);
                return renderToken(ais, tree, lparen + 1, space); // )
            }

            const last_param = params[params.len - 1];
            const after_last_param_tok = tree.lastToken(last_param) + 1;
            if (token_tags[after_last_param_tok] == .Comma) {
                ais.pushIndent();
                try renderToken(ais, tree, lparen, Space.Newline); // (
                for (params) |param_node, i| {
                    if (i + 1 < params.len) {
                        try renderExpression(ais, tree, param_node, Space.None);

                        // Unindent the comma for multiline string literals
                        const is_multiline_string = node_tags[param_node] == .StringLiteral and
                            token_tags[main_tokens[param_node]] == .MultilineStringLiteralLine;
                        if (is_multiline_string) ais.popIndent();

                        const comma = tree.lastToken(param_node) + 1;
                        try renderToken(ais, tree, comma, Space.Newline); // ,

                        if (is_multiline_string) ais.pushIndent();

                        try renderExtraNewline(ais, tree, params[i + 1]);
                    } else {
                        try renderExpression(ais, tree, param_node, Space.Comma);
                    }
                }
                ais.popIndent();
                return renderToken(ais, tree, after_last_param_tok + 1, space); // )
            }

            try renderToken(ais, tree, lparen, Space.None); // (

            for (params) |param_node, i| {
                try renderExpression(ais, tree, param_node, Space.None);

                if (i + 1 < params.len) {
                    const comma = tree.lastToken(param_node) + 1;
                    try renderToken(ais, tree, comma, Space.Space);
                }
            }
            return renderToken(ais, tree, after_last_param_tok, space); // )
        },

        .ArrayAccess => {
            const suffix = datas[node];
            const lbracket = tree.firstToken(suffix.rhs) - 1;
            const rbracket = tree.lastToken(suffix.rhs) + 1;
            try renderExpression(ais, tree, suffix.lhs, .None);
            try renderToken(ais, tree, lbracket, .None); // [
            try renderExpression(ais, tree, suffix.rhs, .None);
            return renderToken(ais, tree, rbracket, space); // ]
        },

        .SliceOpen => try renderSlice(ais, tree, tree.sliceOpen(node), space),
        .Slice => try renderSlice(ais, tree, tree.slice(node), space),
        .SliceSentinel => try renderSlice(ais, tree, tree.sliceSentinel(node), space),

        .Deref => {
            try renderExpression(ais, tree, datas[node].lhs, .None);
            return renderToken(ais, tree, main_tokens[node], space);
        },

        .UnwrapOptional => {
            try renderExpression(ais, tree, datas[node].lhs, .None);
            try renderToken(ais, tree, main_tokens[node], .None);
            return renderToken(ais, tree, datas[node].rhs, space);
        },

        .Break => {
            const main_token = main_tokens[node];
            const label_token = datas[node].lhs;
            const target = datas[node].rhs;
            if (label_token == 0 and target == 0) {
                try renderToken(ais, tree, main_token, space); // break keyword
            } else if (label_token == 0 and target != 0) {
                try renderToken(ais, tree, main_token, .Space); // break keyword
                try renderExpression(ais, tree, target, space);
            } else if (label_token != 0 and target == 0) {
                try renderToken(ais, tree, main_token, .Space); // break keyword
                try renderToken(ais, tree, label_token - 1, .None); // colon
                try renderToken(ais, tree, label_token, space); // identifier
            } else if (label_token != 0 and target != 0) {
                try renderToken(ais, tree, main_token, .Space); // break keyword
                try renderToken(ais, tree, label_token - 1, .None); // colon
                try renderToken(ais, tree, label_token, .Space); // identifier
                try renderExpression(ais, tree, target, space);
            }
        },

        .Continue => {
            const main_token = main_tokens[node];
            const label = datas[node].lhs;
            if (label != 0) {
                try renderToken(ais, tree, main_token, .Space); // continue
                try renderToken(ais, tree, label - 1, .None); // :
                return renderToken(ais, tree, label, space); // label
            } else {
                return renderToken(ais, tree, main_token, space); // continue
            }
        },

        .Return => {
            if (datas[node].lhs != 0) {
                try renderToken(ais, tree, main_tokens[node], .Space);
                try renderExpression(ais, tree, datas[node].lhs, space);
            } else {
                try renderToken(ais, tree, main_tokens[node], space);
            }
        },

        .GroupedExpression => {
            try renderToken(ais, tree, main_tokens[node], .None);
            try renderExpression(ais, tree, datas[node].lhs, .None);
            return renderToken(ais, tree, datas[node].rhs, space);
        },

        .ContainerDecl,
        .ContainerDeclComma,
        => return renderContainerDecl(ais, tree, tree.containerDecl(node), space),

        .ContainerDeclTwo, .ContainerDeclTwoComma => {
            var buffer: [2]ast.Node.Index = undefined;
            return renderContainerDecl(ais, tree, tree.containerDeclTwo(&buffer, node), space);
        },
        .ContainerDeclArg,
        .ContainerDeclArgComma,
        => return renderContainerDecl(ais, tree, tree.containerDeclArg(node), space),

        .TaggedUnion,
        .TaggedUnionComma,
        => return renderContainerDecl(ais, tree, tree.taggedUnion(node), space),

        .TaggedUnionTwo, .TaggedUnionTwoComma => {
            var buffer: [2]ast.Node.Index = undefined;
            return renderContainerDecl(ais, tree, tree.taggedUnionTwo(&buffer, node), space);
        },
        .TaggedUnionEnumTag,
        .TaggedUnionEnumTagComma,
        => return renderContainerDecl(ais, tree, tree.taggedUnionEnumTag(node), space),

        // TODO: handle comments properly
        .ErrorSetDecl => {
            const error_token = main_tokens[node];
            const lbrace = error_token + 1;
            const rbrace = datas[node].rhs;

            try renderToken(ais, tree, error_token, .None);

            if (lbrace + 1 == rbrace) {
                // There is nothing between the braces so render condensed: `error{}`
                try renderToken(ais, tree, lbrace, .None);
                return renderToken(ais, tree, rbrace, space);
            } else if (lbrace + 2 == rbrace and token_tags[lbrace + 1] == .Identifier) {
                // There is exactly one member and no trailing comma or
                // comments, so render without surrounding spaces: `error{Foo}`
                try renderToken(ais, tree, lbrace, .None);
                try renderToken(ais, tree, lbrace + 1, .None); // identifier
                return renderToken(ais, tree, rbrace, space);
            } else if (token_tags[rbrace - 1] == .Comma) {
                // There is a trailing comma so render each member on a new line.
                try renderToken(ais, tree, lbrace, .Newline);
                ais.pushIndent();
                var i = lbrace + 1;
                while (i < rbrace) : (i += 1) {
                    try renderExtraNewlineToken(ais, tree, i);
                    switch (token_tags[i]) {
                        .DocComment => try renderToken(ais, tree, i, .Newline),
                        .Identifier => try renderToken(ais, tree, i, .Comma),
                        .Comma => {},
                        else => unreachable,
                    }
                }
                ais.popIndent();
                return renderToken(ais, tree, rbrace, space);
            } else {
                // There is no trailing comma so render everything on one line.
                try renderToken(ais, tree, lbrace, .Space);
                var i = lbrace + 1;
                while (i < rbrace) : (i += 1) {
                    switch (token_tags[i]) {
                        .DocComment => unreachable, // TODO
                        .Identifier => try renderToken(ais, tree, i, .CommaSpace),
                        .Comma => {},
                        else => unreachable,
                    }
                }
                return renderToken(ais, tree, rbrace, space);
            }
        },

        .BuiltinCallTwo, .BuiltinCallTwoComma => {
            if (datas[node].lhs == 0) {
                const params = [_]ast.Node.Index{};
                return renderBuiltinCall(ais, tree, main_tokens[node], &params, space);
            } else if (datas[node].rhs == 0) {
                const params = [_]ast.Node.Index{datas[node].lhs};
                return renderBuiltinCall(ais, tree, main_tokens[node], &params, space);
            } else {
                const params = [_]ast.Node.Index{ datas[node].lhs, datas[node].rhs };
                return renderBuiltinCall(ais, tree, main_tokens[node], &params, space);
            }
        },
        .BuiltinCall, .BuiltinCallComma => {
            const params = tree.extra_data[datas[node].lhs..datas[node].rhs];
            return renderBuiltinCall(ais, tree, main_tokens[node], params, space);
        },

        .FnProtoSimple => {
            var params: [1]ast.Node.Index = undefined;
            return renderFnProto(ais, tree, tree.fnProtoSimple(&params, node), space);
        },
        .FnProtoMulti => return renderFnProto(ais, tree, tree.fnProtoMulti(node), space),
        .FnProtoOne => {
            var params: [1]ast.Node.Index = undefined;
            return renderFnProto(ais, tree, tree.fnProtoOne(&params, node), space);
        },
        .FnProto => return renderFnProto(ais, tree, tree.fnProto(node), space),

        .AnyFrameType => unreachable, // TODO
        //.AnyFrameType => {
        //    const anyframe_type = @fieldParentPtr(ast.Node.AnyFrameType, "base", base);

        //    if (anyframe_type.result) |result| {
        //        try renderToken(ais, tree, anyframe_type.anyframe_token, Space.None); // anyframe
        //        try renderToken(ais, tree, result.arrow_token, Space.None); // ->
        //        return renderExpression(ais, tree, result.return_type, space);
        //    } else {
        //        return renderToken(ais, tree, anyframe_type.anyframe_token, space); // anyframe
        //    }
        //},

        .Switch,
        .SwitchComma,
        => {
            const switch_token = main_tokens[node];
            const condition = datas[node].lhs;
            const extra = tree.extraData(datas[node].rhs, ast.Node.SubRange);
            const cases = tree.extra_data[extra.start..extra.end];
            const rparen = tree.lastToken(condition) + 1;

            try renderToken(ais, tree, switch_token, .Space); // switch keyword
            try renderToken(ais, tree, switch_token + 1, .None); // lparen
            try renderExpression(ais, tree, condition, .None); // condtion expression
            try renderToken(ais, tree, rparen, .Space); // rparen

            if (cases.len == 0) {
                try renderToken(ais, tree, rparen + 1, .None); // lbrace
                return renderToken(ais, tree, rparen + 2, space); // rbrace
            }
            try renderToken(ais, tree, rparen + 1, .Newline); // lbrace
            ais.pushIndent();
            try renderExpression(ais, tree, cases[0], .Comma);
            for (cases[1..]) |case| {
                try renderExtraNewline(ais, tree, case);
                try renderExpression(ais, tree, case, .Comma);
            }
            ais.popIndent();
            return renderToken(ais, tree, tree.lastToken(node), space); // rbrace
        },

        .SwitchCaseOne => return renderSwitchCase(ais, tree, tree.switchCaseOne(node), space),
        .SwitchCase => return renderSwitchCase(ais, tree, tree.switchCase(node), space),

        .WhileSimple => return renderWhile(ais, tree, tree.whileSimple(node), space),
        .WhileCont => return renderWhile(ais, tree, tree.whileCont(node), space),
        .While => return renderWhile(ais, tree, tree.whileFull(node), space),
        .ForSimple => return renderWhile(ais, tree, tree.forSimple(node), space),
        .For => return renderWhile(ais, tree, tree.forFull(node), space),

        .IfSimple => return renderIf(ais, tree, tree.ifSimple(node), space),
        .If => return renderIf(ais, tree, tree.ifFull(node), space),

        .AsmSimple => return renderAsm(ais, tree, tree.asmSimple(node), space),
        .Asm => return renderAsm(ais, tree, tree.asmFull(node), space),

        .EnumLiteral => {
            try renderToken(ais, tree, main_tokens[node] - 1, .None); // .
            return renderToken(ais, tree, main_tokens[node], space); // name
        },

        .FnDecl => unreachable,
        .ContainerField => unreachable,
        .ContainerFieldInit => unreachable,
        .ContainerFieldAlign => unreachable,
        .Root => unreachable,
        .GlobalVarDecl => unreachable,
        .LocalVarDecl => unreachable,
        .SimpleVarDecl => unreachable,
        .AlignedVarDecl => unreachable,
        .UsingNamespace => unreachable,
        .TestDecl => unreachable,
        .AsmOutput => unreachable,
        .AsmInput => unreachable,
    }
}

// TODO: handle comments inside the brackets
fn renderArrayType(
    ais: *Ais,
    tree: ast.Tree,
    array_type: ast.full.ArrayType,
    space: Space,
) Error!void {
    try renderToken(ais, tree, array_type.ast.lbracket, .None); // lbracket
    try renderExpression(ais, tree, array_type.ast.elem_count, .None);
    if (array_type.ast.sentinel) |sentinel| {
        try renderToken(ais, tree, tree.firstToken(sentinel) - 1, .None); // colon
        try renderExpression(ais, tree, sentinel, .None);
    }
    try renderToken(ais, tree, tree.firstToken(array_type.ast.elem_type) - 1, .None); // rbracket
    return renderExpression(ais, tree, array_type.ast.elem_type, space);
}

fn renderPtrType(
    ais: *Ais,
    tree: ast.Tree,
    ptr_type: ast.full.PtrType,
    space: Space,
) Error!void {
    switch (ptr_type.kind) {
        .one => {
            try renderToken(ais, tree, ptr_type.ast.main_token, .None); // asterisk
        },
        .many => {
            try renderToken(ais, tree, ptr_type.ast.main_token - 1, .None); // lbracket
            try renderToken(ais, tree, ptr_type.ast.main_token, .None); // asterisk
            try renderToken(ais, tree, ptr_type.ast.main_token + 1, .None); // rbracket
        },
        .sentinel => {
            try renderToken(ais, tree, ptr_type.ast.main_token - 1, .None); // lbracket
            try renderToken(ais, tree, ptr_type.ast.main_token, .None); // asterisk
            try renderToken(ais, tree, ptr_type.ast.main_token + 1, .None); // colon
            try renderExpression(ais, tree, ptr_type.ast.sentinel, .None);
            try renderToken(ais, tree, tree.lastToken(ptr_type.ast.sentinel) + 1, .None); // rbracket
        },
        .c => {
            try renderToken(ais, tree, ptr_type.ast.main_token - 1, .None); // lbracket
            try renderToken(ais, tree, ptr_type.ast.main_token, .None); // asterisk
            try renderToken(ais, tree, ptr_type.ast.main_token + 1, .None); // c
            try renderToken(ais, tree, ptr_type.ast.main_token + 2, .None); // rbracket
        },
        .slice => {
            try renderToken(ais, tree, ptr_type.ast.main_token, .None); // lbracket
            try renderToken(ais, tree, ptr_type.ast.main_token + 1, .None); // rbracket
        },
        .slice_sentinel => {
            try renderToken(ais, tree, ptr_type.ast.main_token, .None); // lbracket
            try renderToken(ais, tree, ptr_type.ast.main_token + 1, .None); // colon
            try renderExpression(ais, tree, ptr_type.ast.sentinel, .None);
            try renderToken(ais, tree, tree.lastToken(ptr_type.ast.sentinel) + 1, .None); // rbracket
        },
    }

    if (ptr_type.allowzero_token) |allowzero_token| {
        try renderToken(ais, tree, allowzero_token, .Space);
    }

    if (ptr_type.ast.align_node != 0) {
        const align_first = tree.firstToken(ptr_type.ast.align_node);
        try renderToken(ais, tree, align_first - 2, .None); // align
        try renderToken(ais, tree, align_first - 1, .None); // lparen
        try renderExpression(ais, tree, ptr_type.ast.align_node, .None);
        if (ptr_type.ast.bit_range_start != 0) {
            assert(ptr_type.ast.bit_range_end != 0);
            try renderToken(ais, tree, tree.firstToken(ptr_type.ast.bit_range_start) - 1, .None); // colon
            try renderExpression(ais, tree, ptr_type.ast.bit_range_start, .None);
            try renderToken(ais, tree, tree.firstToken(ptr_type.ast.bit_range_end) - 1, .None); // colon
            try renderExpression(ais, tree, ptr_type.ast.bit_range_end, .None);
            try renderToken(ais, tree, tree.lastToken(ptr_type.ast.bit_range_end) + 1, .Space); // rparen
        } else {
            try renderToken(ais, tree, tree.lastToken(ptr_type.ast.align_node) + 1, .Space); // rparen
        }
    }

    if (ptr_type.const_token) |const_token| {
        try renderToken(ais, tree, const_token, .Space);
    }

    if (ptr_type.volatile_token) |volatile_token| {
        try renderToken(ais, tree, volatile_token, .Space);
    }

    try renderExpression(ais, tree, ptr_type.ast.child_type, space);
}

fn renderSlice(
    ais: *Ais,
    tree: ast.Tree,
    slice: ast.full.Slice,
    space: Space,
) Error!void {
    const node_tags = tree.nodes.items(.tag);
    const after_start_space_bool = nodeCausesSliceOpSpace(node_tags[slice.ast.start]) or
        if (slice.ast.end != 0) nodeCausesSliceOpSpace(node_tags[slice.ast.end]) else false;
    const after_start_space = if (after_start_space_bool) Space.Space else Space.None;
    const after_dots_space = if (slice.ast.end != 0) after_start_space else Space.None;

    try renderExpression(ais, tree, slice.ast.sliced, .None);
    try renderToken(ais, tree, slice.ast.lbracket, .None); // lbracket

    const start_last = tree.lastToken(slice.ast.start);
    try renderExpression(ais, tree, slice.ast.start, after_start_space);
    try renderToken(ais, tree, start_last + 1, after_dots_space); // ellipsis2 ("..")
    if (slice.ast.end == 0) {
        return renderToken(ais, tree, start_last + 2, space); // rbracket
    }

    const end_last = tree.lastToken(slice.ast.end);
    const after_end_space = if (slice.ast.sentinel != 0) Space.Space else Space.None;
    try renderExpression(ais, tree, slice.ast.end, after_end_space);
    if (slice.ast.sentinel == 0) {
        return renderToken(ais, tree, end_last + 1, space); // rbracket
    }

    try renderToken(ais, tree, end_last + 1, .None); // colon
    try renderExpression(ais, tree, slice.ast.sentinel, .None);
    try renderToken(ais, tree, tree.lastToken(slice.ast.sentinel) + 1, space); // rbracket
}

fn renderAsmOutput(
    ais: *Ais,
    tree: ast.Tree,
    asm_output: ast.Node.Index,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const datas = tree.nodes.items(.data);
    assert(node_tags[asm_output] == .AsmOutput);
    const symbolic_name = main_tokens[asm_output];

    try renderToken(ais, tree, symbolic_name - 1, .None); // lbracket
    try renderToken(ais, tree, symbolic_name, .None); // ident
    try renderToken(ais, tree, symbolic_name + 1, .Space); // rbracket
    try renderToken(ais, tree, symbolic_name + 2, .Space); // "constraint"
    try renderToken(ais, tree, symbolic_name + 3, .None); // lparen

    if (token_tags[symbolic_name + 4] == .Arrow) {
        try renderToken(ais, tree, symbolic_name + 4, .Space); // ->
        try renderExpression(ais, tree, datas[asm_output].lhs, Space.None);
        return renderToken(ais, tree, datas[asm_output].rhs, space); // rparen
    } else {
        try renderToken(ais, tree, symbolic_name + 4, .None); // ident
        return renderToken(ais, tree, symbolic_name + 5, space); // rparen
    }
}

fn renderAsmInput(
    ais: *Ais,
    tree: ast.Tree,
    asm_input: ast.Node.Index,
    space: Space,
) Error!void {
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const datas = tree.nodes.items(.data);
    assert(node_tags[asm_input] == .AsmInput);
    const symbolic_name = main_tokens[asm_input];

    try renderToken(ais, tree, symbolic_name - 1, .None); // lbracket
    try renderToken(ais, tree, symbolic_name, .None); // ident
    try renderToken(ais, tree, symbolic_name + 1, .Space); // rbracket
    try renderToken(ais, tree, symbolic_name + 2, .Space); // "constraint"
    try renderToken(ais, tree, symbolic_name + 3, .None); // lparen
    try renderExpression(ais, tree, datas[asm_input].lhs, Space.None);
    return renderToken(ais, tree, datas[asm_input].rhs, space); // rparen
}

fn renderVarDecl(ais: *Ais, tree: ast.Tree, var_decl: ast.full.VarDecl) Error!void {
    if (var_decl.visib_token) |visib_token| {
        try renderToken(ais, tree, visib_token, Space.Space); // pub
    }

    if (var_decl.extern_export_token) |extern_export_token| {
        try renderToken(ais, tree, extern_export_token, Space.Space); // extern

        if (var_decl.lib_name) |lib_name| {
            try renderExpression(ais, tree, lib_name, Space.Space); // "lib"
        }
    }

    if (var_decl.threadlocal_token) |thread_local_token| {
        try renderToken(ais, tree, thread_local_token, Space.Space); // threadlocal
    }

    if (var_decl.comptime_token) |comptime_token| {
        try renderToken(ais, tree, comptime_token, Space.Space); // comptime
    }

    try renderToken(ais, tree, var_decl.ast.mut_token, .Space); // var

    const name_space = if (var_decl.ast.type_node == 0 and
        (var_decl.ast.align_node != 0 or
        var_decl.ast.section_node != 0 or
        var_decl.ast.init_node != 0))
        Space.Space
    else
        Space.None;
    try renderToken(ais, tree, var_decl.ast.mut_token + 1, name_space); // name

    if (var_decl.ast.type_node != 0) {
        try renderToken(ais, tree, var_decl.ast.mut_token + 2, Space.Space); // :
        if (var_decl.ast.align_node != 0 or var_decl.ast.section_node != 0 or
            var_decl.ast.init_node != 0)
        {
            try renderExpression(ais, tree, var_decl.ast.type_node, .Space);
        } else {
            try renderExpression(ais, tree, var_decl.ast.type_node, .None);
            const semicolon = tree.lastToken(var_decl.ast.type_node) + 1;
            return renderToken(ais, tree, semicolon, Space.Newline); // ;
        }
    }

    if (var_decl.ast.align_node != 0) {
        const lparen = tree.firstToken(var_decl.ast.align_node) - 1;
        const align_kw = lparen - 1;
        const rparen = tree.lastToken(var_decl.ast.align_node) + 1;
        try renderToken(ais, tree, align_kw, Space.None); // align
        try renderToken(ais, tree, lparen, Space.None); // (
        try renderExpression(ais, tree, var_decl.ast.align_node, Space.None);
        if (var_decl.ast.section_node != 0 or var_decl.ast.init_node != 0) {
            try renderToken(ais, tree, rparen, .Space); // )
        } else {
            try renderToken(ais, tree, rparen, .None); // )
            return renderToken(ais, tree, rparen + 1, Space.Newline); // ;
        }
    }

    if (var_decl.ast.section_node != 0) {
        const lparen = tree.firstToken(var_decl.ast.section_node) - 1;
        const section_kw = lparen - 1;
        const rparen = tree.lastToken(var_decl.ast.section_node) + 1;
        try renderToken(ais, tree, section_kw, Space.None); // linksection
        try renderToken(ais, tree, lparen, Space.None); // (
        try renderExpression(ais, tree, var_decl.ast.section_node, Space.None);
        if (var_decl.ast.init_node != 0) {
            try renderToken(ais, tree, rparen, .Space); // )
        } else {
            try renderToken(ais, tree, rparen, .None); // )
            return renderToken(ais, tree, rparen + 1, Space.Newline); // ;
        }
    }

    assert(var_decl.ast.init_node != 0);
    const eq_token = tree.firstToken(var_decl.ast.init_node) - 1;
    const eq_space: Space = if (tree.tokensOnSameLine(eq_token, eq_token + 1)) .Space else .Newline;
    {
        ais.pushIndent();
        try renderToken(ais, tree, eq_token, eq_space); // =
        ais.popIndent();
    }
    ais.pushIndentOneShot();
    try renderExpression(ais, tree, var_decl.ast.init_node, .Semicolon);
}

fn renderIf(ais: *Ais, tree: ast.Tree, if_node: ast.full.If, space: Space) Error!void {
    return renderWhile(ais, tree, .{
        .ast = .{
            .while_token = if_node.ast.if_token,
            .cond_expr = if_node.ast.cond_expr,
            .cont_expr = 0,
            .then_expr = if_node.ast.then_expr,
            .else_expr = if_node.ast.else_expr,
        },
        .inline_token = null,
        .label_token = null,
        .payload_token = if_node.payload_token,
        .else_token = if_node.else_token,
        .error_token = if_node.error_token,
    }, space);
}

/// Note that this function is additionally used to render if and for expressions, with
/// respective values set to null.
fn renderWhile(ais: *Ais, tree: ast.Tree, while_node: ast.full.While, space: Space) Error!void {
    const node_tags = tree.nodes.items(.tag);
    const token_tags = tree.tokens.items(.tag);

    if (while_node.label_token) |label| {
        try renderToken(ais, tree, label, .None); // label
        try renderToken(ais, tree, label + 1, .Space); // :
    }

    if (while_node.inline_token) |inline_token| {
        try renderToken(ais, tree, inline_token, .Space); // inline
    }

    try renderToken(ais, tree, while_node.ast.while_token, .Space); // if
    try renderToken(ais, tree, while_node.ast.while_token + 1, .None); // (
    try renderExpression(ais, tree, while_node.ast.cond_expr, .None); // condition

    if (nodeIsBlock(node_tags[while_node.ast.then_expr])) {
        if (while_node.payload_token) |payload_token| {
            try renderToken(ais, tree, payload_token - 2, .Space); // )
            try renderToken(ais, tree, payload_token - 1, .None); // |
            const ident = blk: {
                if (token_tags[payload_token] == .Asterisk) {
                    try renderToken(ais, tree, payload_token, .None); // *
                    break :blk payload_token + 1;
                } else {
                    break :blk payload_token;
                }
            };
            try renderToken(ais, tree, ident, .None); // identifier
            const pipe = blk: {
                if (token_tags[ident + 1] == .Comma) {
                    try renderToken(ais, tree, ident + 1, .Space); // ,
                    try renderToken(ais, tree, ident + 2, .None); // index
                    break :blk payload_token + 3;
                } else {
                    break :blk ident + 1;
                }
            };
            try renderToken(ais, tree, pipe, .Space); // |
        } else {
            const rparen = tree.lastToken(while_node.ast.cond_expr) + 1;
            try renderToken(ais, tree, rparen, .Space); // )
        }
        if (while_node.ast.cont_expr != 0) {
            const rparen = tree.lastToken(while_node.ast.cont_expr) + 1;
            const lparen = tree.firstToken(while_node.ast.cont_expr) - 1;
            try renderToken(ais, tree, lparen - 1, .Space); // :
            try renderToken(ais, tree, lparen, .None); // lparen
            try renderExpression(ais, tree, while_node.ast.cont_expr, .None);
            try renderToken(ais, tree, rparen, .Space); // rparen
        }
        if (while_node.ast.else_expr != 0) {
            try renderExpression(ais, tree, while_node.ast.then_expr, Space.Space);
            try renderToken(ais, tree, while_node.else_token, .Space); // else
            if (while_node.error_token) |error_token| {
                try renderToken(ais, tree, error_token - 1, .None); // |
                try renderToken(ais, tree, error_token, .None); // identifier
                try renderToken(ais, tree, error_token + 1, .Space); // |
            }
            return renderExpression(ais, tree, while_node.ast.else_expr, space);
        } else {
            return renderExpression(ais, tree, while_node.ast.then_expr, space);
        }
    }

    const rparen = tree.lastToken(while_node.ast.cond_expr) + 1;
    const last_then_token = tree.lastToken(while_node.ast.then_expr);
    const src_has_newline = !tree.tokensOnSameLine(rparen, last_then_token);

    if (src_has_newline) {
        if (while_node.payload_token) |payload_token| {
            try renderToken(ais, tree, payload_token - 2, .Space); // )
            try renderToken(ais, tree, payload_token - 1, .None); // |
            const ident = blk: {
                if (token_tags[payload_token] == .Asterisk) {
                    try renderToken(ais, tree, payload_token, .None); // *
                    break :blk payload_token + 1;
                } else {
                    break :blk payload_token;
                }
            };
            try renderToken(ais, tree, ident, .None); // identifier
            const pipe = blk: {
                if (token_tags[ident + 1] == .Comma) {
                    try renderToken(ais, tree, ident + 1, .Space); // ,
                    try renderToken(ais, tree, ident + 2, .None); // index
                    break :blk payload_token + 3;
                } else {
                    break :blk ident + 1;
                }
            };
            try renderToken(ais, tree, pipe, .Newline); // |
        } else {
            ais.pushIndent();
            try renderToken(ais, tree, rparen, .Newline); // )
            ais.popIndent();
        }
        if (while_node.ast.cont_expr != 0) {
            const cont_rparen = tree.lastToken(while_node.ast.cont_expr) + 1;
            const cont_lparen = tree.firstToken(while_node.ast.cont_expr) - 1;
            try renderToken(ais, tree, cont_lparen - 1, .Space); // :
            try renderToken(ais, tree, cont_lparen, .None); // lparen
            try renderExpression(ais, tree, while_node.ast.cont_expr, .None);
            try renderToken(ais, tree, cont_rparen, .Newline); // rparen
        }
        if (while_node.ast.else_expr != 0) {
            ais.pushIndent();
            try renderExpression(ais, tree, while_node.ast.then_expr, Space.Newline);
            ais.popIndent();
            const else_is_block = nodeIsBlock(node_tags[while_node.ast.else_expr]);
            if (else_is_block) {
                try renderToken(ais, tree, while_node.else_token, .Space); // else
                if (while_node.error_token) |error_token| {
                    try renderToken(ais, tree, error_token - 1, .None); // |
                    try renderToken(ais, tree, error_token, .None); // identifier
                    try renderToken(ais, tree, error_token + 1, .Space); // |
                }
                return renderExpression(ais, tree, while_node.ast.else_expr, space);
            } else {
                if (while_node.error_token) |error_token| {
                    try renderToken(ais, tree, while_node.else_token, .Space); // else
                    try renderToken(ais, tree, error_token - 1, .None); // |
                    try renderToken(ais, tree, error_token, .None); // identifier
                    try renderToken(ais, tree, error_token + 1, .Space); // |
                } else {
                    try renderToken(ais, tree, while_node.else_token, .Newline); // else
                }
                ais.pushIndent();
                try renderExpression(ais, tree, while_node.ast.else_expr, space);
                ais.popIndent();
                return;
            }
        } else {
            ais.pushIndent();
            try renderExpression(ais, tree, while_node.ast.then_expr, space);
            ais.popIndent();
            return;
        }
    }

    // Render everything on a single line.

    if (while_node.payload_token) |payload_token| {
        assert(payload_token - 2 == rparen);
        try renderToken(ais, tree, payload_token - 2, .Space); // )
        try renderToken(ais, tree, payload_token - 1, .None); // |
        const ident = blk: {
            if (token_tags[payload_token] == .Asterisk) {
                try renderToken(ais, tree, payload_token, .None); // *
                break :blk payload_token + 1;
            } else {
                break :blk payload_token;
            }
        };
        try renderToken(ais, tree, ident, .None); // identifier
        const pipe = blk: {
            if (token_tags[ident + 1] == .Comma) {
                try renderToken(ais, tree, ident + 1, .Space); // ,
                try renderToken(ais, tree, ident + 2, .None); // index
                break :blk payload_token + 3;
            } else {
                break :blk ident + 1;
            }
        };
        try renderToken(ais, tree, pipe, .Space); // |
    } else {
        try renderToken(ais, tree, rparen, .Space); // )
    }

    if (while_node.ast.cont_expr != 0) {
        const cont_rparen = tree.lastToken(while_node.ast.cont_expr) + 1;
        const cont_lparen = tree.firstToken(while_node.ast.cont_expr) - 1;
        try renderToken(ais, tree, cont_lparen - 1, .Space); // :
        try renderToken(ais, tree, cont_lparen, .None); // lparen
        try renderExpression(ais, tree, while_node.ast.cont_expr, .None);
        try renderToken(ais, tree, cont_rparen, .Space); // rparen
    }

    if (while_node.ast.else_expr != 0) {
        try renderExpression(ais, tree, while_node.ast.then_expr, .Space);
        try renderToken(ais, tree, while_node.else_token, .Space); // else

        if (while_node.error_token) |error_token| {
            try renderToken(ais, tree, error_token - 1, .None); // |
            try renderToken(ais, tree, error_token, .None); // identifier
            try renderToken(ais, tree, error_token + 1, .Space); // |
        }

        return renderExpression(ais, tree, while_node.ast.else_expr, space);
    } else {
        return renderExpression(ais, tree, while_node.ast.then_expr, space);
    }
}

fn renderContainerField(
    ais: *Ais,
    tree: ast.Tree,
    field: ast.full.ContainerField,
    space: Space,
) Error!void {
    const main_tokens = tree.nodes.items(.main_token);
    if (field.comptime_token) |t| {
        try renderToken(ais, tree, t, .Space); // comptime
    }
    if (field.ast.type_expr == 0 and field.ast.value_expr == 0) {
        return renderTokenComma(ais, tree, field.ast.name_token, space); // name
    }
    if (field.ast.type_expr != 0 and field.ast.value_expr == 0) {
        try renderToken(ais, tree, field.ast.name_token, .None); // name
        try renderToken(ais, tree, field.ast.name_token + 1, .Space); // :

        if (field.ast.align_expr != 0) {
            try renderExpression(ais, tree, field.ast.type_expr, .Space); // type
            const align_token = tree.firstToken(field.ast.align_expr) - 2;
            try renderToken(ais, tree, align_token, .None); // align
            try renderToken(ais, tree, align_token + 1, .None); // (
            try renderExpression(ais, tree, field.ast.align_expr, .None); // alignment
            const rparen = tree.lastToken(field.ast.align_expr) + 1;
            return renderTokenComma(ais, tree, rparen, space); // )
        } else {
            return renderExpressionComma(ais, tree, field.ast.type_expr, space); // type
        }
    }
    if (field.ast.type_expr == 0 and field.ast.value_expr != 0) {
        try renderToken(ais, tree, field.ast.name_token, .Space); // name
        try renderToken(ais, tree, field.ast.name_token + 1, .Space); // =
        return renderExpressionComma(ais, tree, field.ast.value_expr, space); // value
    }

    try renderToken(ais, tree, field.ast.name_token, .None); // name
    try renderToken(ais, tree, field.ast.name_token + 1, .Space); // :
    try renderExpression(ais, tree, field.ast.type_expr, .Space); // type

    if (field.ast.align_expr != 0) {
        const lparen_token = tree.firstToken(field.ast.align_expr) - 1;
        const align_kw = lparen_token - 1;
        const rparen_token = tree.lastToken(field.ast.align_expr) + 1;
        try renderToken(ais, tree, align_kw, .None); // align
        try renderToken(ais, tree, lparen_token, .None); // (
        try renderExpression(ais, tree, field.ast.align_expr, .None); // alignment
        try renderToken(ais, tree, rparen_token, .Space); // )
    }
    const eq_token = tree.firstToken(field.ast.value_expr) - 1;
    try renderToken(ais, tree, eq_token, .Space); // =
    return renderExpressionComma(ais, tree, field.ast.value_expr, space); // value
}

fn renderBuiltinCall(
    ais: *Ais,
    tree: ast.Tree,
    builtin_token: ast.TokenIndex,
    params: []const ast.Node.Index,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);

    try renderToken(ais, tree, builtin_token, .None); // @name

    if (params.len == 0) {
        try renderToken(ais, tree, builtin_token + 1, .None); // (
        return renderToken(ais, tree, builtin_token + 2, space); // )
    }

    const last_param = params[params.len - 1];
    const after_last_param_token = tree.lastToken(last_param) + 1;

    if (token_tags[after_last_param_token] != .Comma) {
        // Render all on one line, no trailing comma.
        try renderToken(ais, tree, builtin_token + 1, .None); // (

        for (params) |param_node, i| {
            try renderExpression(ais, tree, param_node, .None);

            if (i + 1 < params.len) {
                const comma_token = tree.lastToken(param_node) + 1;
                try renderToken(ais, tree, comma_token, .Space); // ,
            }
        }
        return renderToken(ais, tree, after_last_param_token, space); // )
    } else {
        // Render one param per line.
        ais.pushIndent();
        try renderToken(ais, tree, builtin_token + 1, Space.Newline); // (

        for (params) |param_node| {
            try renderExpression(ais, tree, param_node, .Comma);
        }
        ais.popIndent();

        return renderToken(ais, tree, after_last_param_token + 1, space); // )
    }
}

fn renderFnProto(ais: *Ais, tree: ast.Tree, fn_proto: ast.full.FnProto, space: Space) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const token_starts = tree.tokens.items(.start);

    const after_fn_token = fn_proto.ast.fn_token + 1;
    const lparen = if (token_tags[after_fn_token] == .Identifier) blk: {
        try renderToken(ais, tree, fn_proto.ast.fn_token, .Space); // fn
        try renderToken(ais, tree, after_fn_token, .None); // name
        break :blk after_fn_token + 1;
    } else blk: {
        try renderToken(ais, tree, fn_proto.ast.fn_token, .Space); // fn
        break :blk fn_proto.ast.fn_token + 1;
    };
    assert(token_tags[lparen] == .LParen);

    const maybe_bang = tree.firstToken(fn_proto.ast.return_type) - 1;
    const rparen = blk: {
        // These may appear in any order, so we have to check the token_starts array
        // to find out which is first.
        var rparen: ast.TokenIndex = maybe_bang;
        var smallest_start = token_starts[maybe_bang];
        if (fn_proto.ast.align_expr != 0) {
            const tok = tree.firstToken(fn_proto.ast.align_expr) - 3;
            const start = token_starts[tok];
            if (start < smallest_start) {
                rparen = tok;
                smallest_start = start;
            }
        }
        if (fn_proto.ast.section_expr != 0) {
            const tok = tree.firstToken(fn_proto.ast.section_expr) - 3;
            const start = token_starts[tok];
            if (start < smallest_start) {
                rparen = tok;
                smallest_start = start;
            }
        }
        if (fn_proto.ast.callconv_expr != 0) {
            const tok = tree.firstToken(fn_proto.ast.callconv_expr) - 3;
            const start = token_starts[tok];
            if (start < smallest_start) {
                rparen = tok;
                smallest_start = start;
            }
        }
        break :blk rparen;
    };
    assert(token_tags[rparen] == .RParen);

    // The params list is a sparse set that does *not* include anytype or ... parameters.

    if (token_tags[rparen - 1] != .Comma) {
        // Render all on one line, no trailing comma.
        try renderToken(ais, tree, lparen, .None); // (

        var param_i: usize = 0;
        var last_param_token = lparen;
        while (true) {
            last_param_token += 1;
            switch (token_tags[last_param_token]) {
                .DocComment => {
                    try renderToken(ais, tree, last_param_token, .Newline);
                    continue;
                },
                .Ellipsis3 => {
                    try renderToken(ais, tree, last_param_token, .None); // ...
                    break;
                },
                .Keyword_noalias, .Keyword_comptime => {
                    try renderToken(ais, tree, last_param_token, .Space);
                    last_param_token += 1;
                },
                .Identifier => {},
                .Keyword_anytype => {
                    try renderToken(ais, tree, last_param_token, .None); // anytype
                    continue;
                },
                .RParen => break,
                .Comma => {
                    try renderToken(ais, tree, last_param_token, .Space); // ,
                    last_param_token += 1;
                },
                else => {}, // Parameter type without a name.
            }
            if (token_tags[last_param_token] == .Identifier and
                token_tags[last_param_token + 1] == .Colon)
            {
                try renderToken(ais, tree, last_param_token, .None); // name
                last_param_token += 1;
                try renderToken(ais, tree, last_param_token, .Space); // :
                last_param_token += 1;
            }
            if (token_tags[last_param_token] == .Keyword_anytype) {
                try renderToken(ais, tree, last_param_token, .None); // anytype
                continue;
            }
            const param = fn_proto.ast.params[param_i];
            param_i += 1;
            try renderExpression(ais, tree, param, .None);
            last_param_token = tree.lastToken(param);
        }
    } else {
        // One param per line.
        ais.pushIndent();
        try renderToken(ais, tree, lparen, .Newline); // (

        var param_i: usize = 0;
        var last_param_token = lparen;
        while (true) {
            last_param_token += 1;
            switch (token_tags[last_param_token]) {
                .DocComment => {
                    try renderToken(ais, tree, last_param_token, .Newline);
                    continue;
                },
                .Ellipsis3 => {
                    try renderToken(ais, tree, last_param_token, .Comma); // ...
                    break;
                },
                .Keyword_noalias, .Keyword_comptime => {
                    try renderToken(ais, tree, last_param_token, .Space);
                    last_param_token += 1;
                },
                .Identifier => {},
                .Keyword_anytype => {
                    try renderToken(ais, tree, last_param_token, .Comma); // anytype
                    continue;
                },
                .RParen => break,
                else => unreachable,
            }
            if (token_tags[last_param_token] == .Identifier) {
                try renderToken(ais, tree, last_param_token, .None); // name
                last_param_token += 1;
                try renderToken(ais, tree, last_param_token, .Space); // :
                last_param_token += 1;
            }
            if (token_tags[last_param_token] == .Keyword_anytype) {
                try renderToken(ais, tree, last_param_token, .Comma); // anytype
                continue;
            }
            const param = fn_proto.ast.params[param_i];
            param_i += 1;
            try renderExpression(ais, tree, param, .Comma);
            last_param_token = tree.lastToken(param) + 1;
        }
        ais.popIndent();
    }

    try renderToken(ais, tree, rparen, .Space); // )

    if (fn_proto.ast.align_expr != 0) {
        const align_lparen = tree.firstToken(fn_proto.ast.align_expr) - 1;
        const align_rparen = tree.lastToken(fn_proto.ast.align_expr) + 1;

        try renderToken(ais, tree, align_lparen - 1, .None); // align
        try renderToken(ais, tree, align_lparen, .None); // (
        try renderExpression(ais, tree, fn_proto.ast.align_expr, .None);
        try renderToken(ais, tree, align_rparen, .Space); // )
    }

    if (fn_proto.ast.section_expr != 0) {
        const section_lparen = tree.firstToken(fn_proto.ast.section_expr) - 1;
        const section_rparen = tree.lastToken(fn_proto.ast.section_expr) + 1;

        try renderToken(ais, tree, section_lparen - 1, .None); // section
        try renderToken(ais, tree, section_lparen, .None); // (
        try renderExpression(ais, tree, fn_proto.ast.section_expr, .None);
        try renderToken(ais, tree, section_rparen, .Space); // )
    }

    if (fn_proto.ast.callconv_expr != 0) {
        const callconv_lparen = tree.firstToken(fn_proto.ast.callconv_expr) - 1;
        const callconv_rparen = tree.lastToken(fn_proto.ast.callconv_expr) + 1;

        try renderToken(ais, tree, callconv_lparen - 1, .None); // callconv
        try renderToken(ais, tree, callconv_lparen, .None); // (
        try renderExpression(ais, tree, fn_proto.ast.callconv_expr, .None);
        try renderToken(ais, tree, callconv_rparen, .Space); // )
    }

    if (token_tags[maybe_bang] == .Bang) {
        try renderToken(ais, tree, maybe_bang, .None); // !
    }
    return renderExpression(ais, tree, fn_proto.ast.return_type, space);
}

fn renderSwitchCase(
    ais: *Ais,
    tree: ast.Tree,
    switch_case: ast.full.SwitchCase,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const trailing_comma = token_tags[switch_case.ast.arrow_token - 1] == .Comma;

    // Render everything before the arrow
    if (switch_case.ast.values.len == 0) {
        try renderToken(ais, tree, switch_case.ast.arrow_token - 1, .Space); // else keyword
    } else if (switch_case.ast.values.len == 1) {
        // render on one line and drop the trailing comma if any
        try renderExpression(ais, tree, switch_case.ast.values[0], .Space);
    } else if (trailing_comma) {
        // Render each value on a new line
        try renderExpression(ais, tree, switch_case.ast.values[0], .Comma);
        for (switch_case.ast.values[1..]) |value_expr| {
            try renderExtraNewline(ais, tree, value_expr);
            try renderExpression(ais, tree, value_expr, .Comma);
        }
    } else {
        // Render on one line
        for (switch_case.ast.values) |value_expr| {
            try renderExpression(ais, tree, value_expr, .CommaSpace);
        }
    }

    // Render the arrow and everything after it
    try renderToken(ais, tree, switch_case.ast.arrow_token, .Space);

    if (switch_case.payload_token) |payload_token| {
        try renderToken(ais, tree, payload_token - 1, .None); // pipe
        if (token_tags[payload_token] == .Asterisk) {
            try renderToken(ais, tree, payload_token, .None); // asterisk
            try renderToken(ais, tree, payload_token + 1, .None); // identifier
            try renderToken(ais, tree, payload_token + 2, .Space); // pipe
        } else {
            try renderToken(ais, tree, payload_token, .None); // identifier
            try renderToken(ais, tree, payload_token + 1, .Space); // pipe
        }
    }

    try renderExpression(ais, tree, switch_case.ast.target_expr, space);
}

fn renderBlock(
    ais: *Ais,
    tree: ast.Tree,
    block_node: ast.Node.Index,
    statements: []const ast.Node.Index,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const node_tags = tree.nodes.items(.tag);
    const nodes_data = tree.nodes.items(.data);
    const lbrace = tree.nodes.items(.main_token)[block_node];

    if (token_tags[lbrace - 1] == .Colon and
        token_tags[lbrace - 2] == .Identifier)
    {
        try renderToken(ais, tree, lbrace - 2, .None);
        try renderToken(ais, tree, lbrace - 1, .Space);
    }

    if (statements.len == 0) {
        try renderToken(ais, tree, lbrace, .None);
        return renderToken(ais, tree, lbrace + 1, space); // rbrace
    }

    try renderToken(ais, tree, lbrace, .Newline);
    ais.pushIndent();
    for (statements) |stmt, i| {
        switch (node_tags[stmt]) {
            .GlobalVarDecl => try renderVarDecl(ais, tree, tree.globalVarDecl(stmt)),
            .LocalVarDecl => try renderVarDecl(ais, tree, tree.localVarDecl(stmt)),
            .SimpleVarDecl => try renderVarDecl(ais, tree, tree.simpleVarDecl(stmt)),
            .AlignedVarDecl => try renderVarDecl(ais, tree, tree.alignedVarDecl(stmt)),
            else => try renderExpression(ais, tree, stmt, .Semicolon),
        }
        if (i + 1 < statements.len) {
            try renderExtraNewline(ais, tree, statements[i + 1]);
        }
    }
    ais.popIndent();

    try renderToken(ais, tree, tree.lastToken(block_node), space); // rbrace
}

// TODO: handle comments between fields
fn renderStructInit(
    ais: *Ais,
    tree: ast.Tree,
    struct_init: ast.full.StructInit,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    if (struct_init.ast.type_expr == 0) {
        try renderToken(ais, tree, struct_init.ast.lbrace - 1, .None); // .
    } else {
        try renderExpression(ais, tree, struct_init.ast.type_expr, .None); // T
    }
    if (struct_init.ast.fields.len == 0) {
        try renderToken(ais, tree, struct_init.ast.lbrace, .None); // lbrace
        return renderToken(ais, tree, struct_init.ast.lbrace + 1, space); // rbrace
    }
    const last_field = struct_init.ast.fields[struct_init.ast.fields.len - 1];
    const last_field_token = tree.lastToken(last_field);
    if (token_tags[last_field_token + 1] == .Comma) {
        // Render one field init per line.
        ais.pushIndent();
        try renderToken(ais, tree, struct_init.ast.lbrace, .Newline);

        try renderToken(ais, tree, struct_init.ast.lbrace + 1, .None); // .
        try renderToken(ais, tree, struct_init.ast.lbrace + 2, .Space); // name
        try renderToken(ais, tree, struct_init.ast.lbrace + 3, .Space); // =
        try renderExpression(ais, tree, struct_init.ast.fields[0], .Comma);

        for (struct_init.ast.fields[1..]) |field_init| {
            const init_token = tree.firstToken(field_init);
            try renderToken(ais, tree, init_token - 3, .None); // .
            try renderToken(ais, tree, init_token - 2, .Space); // name
            try renderToken(ais, tree, init_token - 1, .Space); // =
            try renderExpressionNewlined(ais, tree, field_init, .Comma);
        }
        ais.popIndent();
        return renderToken(ais, tree, last_field_token + 2, space); // rbrace
    } else {
        // Render all on one line, no trailing comma.
        try renderToken(ais, tree, struct_init.ast.lbrace, .Space);

        for (struct_init.ast.fields) |field_init| {
            const init_token = tree.firstToken(field_init);
            try renderToken(ais, tree, init_token - 3, .None); // .
            try renderToken(ais, tree, init_token - 2, .Space); // name
            try renderToken(ais, tree, init_token - 1, .Space); // =
            try renderExpression(ais, tree, field_init, .CommaSpace);
        }

        return renderToken(ais, tree, last_field_token + 1, space); // rbrace
    }
}

// TODO: handle comments between elements
fn renderArrayInit(
    ais: *Ais,
    tree: ast.Tree,
    array_init: ast.full.ArrayInit,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    if (array_init.ast.type_expr == 0) {
        try renderToken(ais, tree, array_init.ast.lbrace - 1, .None); // .
    } else {
        try renderExpression(ais, tree, array_init.ast.type_expr, .None); // T
    }
    if (array_init.ast.elements.len == 0) {
        try renderToken(ais, tree, array_init.ast.lbrace, .None); // lbrace
        return renderToken(ais, tree, array_init.ast.lbrace + 1, space); // rbrace
    }
    const last_elem = array_init.ast.elements[array_init.ast.elements.len - 1];
    const last_elem_token = tree.lastToken(last_elem);
    if (token_tags[last_elem_token + 1] == .Comma) {
        // Render one element per line.
        ais.pushIndent();
        try renderToken(ais, tree, array_init.ast.lbrace, .Newline);

        try renderExpression(ais, tree, array_init.ast.elements[0], .Comma);
        for (array_init.ast.elements[1..]) |elem| {
            try renderExpressionNewlined(ais, tree, elem, .Comma);
        }

        ais.popIndent();
        return renderToken(ais, tree, last_elem_token + 2, space); // rbrace
    } else {
        // Render all on one line, no trailing comma.
        if (array_init.ast.elements.len == 1) {
            // If there is only one element, we don't use spaces
            try renderToken(ais, tree, array_init.ast.lbrace, .None);
            try renderExpression(ais, tree, array_init.ast.elements[0], .None);
        } else {
            try renderToken(ais, tree, array_init.ast.lbrace, .Space);
            for (array_init.ast.elements) |elem| {
                try renderExpression(ais, tree, elem, .CommaSpace);
            }
        }
        return renderToken(ais, tree, last_elem_token + 1, space); // rbrace
    }
}

fn renderContainerDecl(
    ais: *Ais,
    tree: ast.Tree,
    container_decl: ast.full.ContainerDecl,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const node_tags = tree.nodes.items(.tag);

    if (container_decl.layout_token) |layout_token| {
        try renderToken(ais, tree, layout_token, .Space);
    }

    var lbrace: ast.TokenIndex = undefined;
    if (container_decl.ast.enum_token) |enum_token| {
        try renderToken(ais, tree, container_decl.ast.main_token, .None); // union
        try renderToken(ais, tree, enum_token - 1, .None); // lparen
        try renderToken(ais, tree, enum_token, .None); // enum
        if (container_decl.ast.arg != 0) {
            try renderToken(ais, tree, enum_token + 1, .None); // lparen
            try renderExpression(ais, tree, container_decl.ast.arg, .None);
            const rparen = tree.lastToken(container_decl.ast.arg) + 1;
            try renderToken(ais, tree, rparen, .None); // rparen
            try renderToken(ais, tree, rparen + 1, .Space); // rparen
            lbrace = rparen + 2;
        } else {
            try renderToken(ais, tree, enum_token + 1, .Space); // rparen
            lbrace = enum_token + 2;
        }
    } else if (container_decl.ast.arg != 0) {
        try renderToken(ais, tree, container_decl.ast.main_token, .None); // union
        try renderToken(ais, tree, container_decl.ast.main_token + 1, .None); // lparen
        try renderExpression(ais, tree, container_decl.ast.arg, .None);
        const rparen = tree.lastToken(container_decl.ast.arg) + 1;
        try renderToken(ais, tree, rparen, .Space); // rparen
        lbrace = rparen + 1;
    } else {
        try renderToken(ais, tree, container_decl.ast.main_token, .Space); // union
        lbrace = container_decl.ast.main_token + 1;
    }

    if (container_decl.ast.members.len == 0) {
        try renderToken(ais, tree, lbrace, Space.None); // lbrace
        return renderToken(ais, tree, lbrace + 1, space); // rbrace
    }

    const last_member = container_decl.ast.members[container_decl.ast.members.len - 1];
    const last_member_token = tree.lastToken(last_member);
    const rbrace = switch (token_tags[last_member_token + 1]) {
        .DocComment => last_member_token + 2,
        .Comma => switch (token_tags[last_member_token + 2]) {
            .DocComment => last_member_token + 3,
            .RBrace => last_member_token + 2,
            else => unreachable,
        },
        .RBrace => last_member_token + 1,
        else => unreachable,
    };
    const src_has_trailing_comma = token_tags[last_member_token + 1] == .Comma;

    if (!src_has_trailing_comma) one_line: {
        // We can only print all the members in-line if all the members are fields.
        for (container_decl.ast.members) |member| {
            if (!node_tags[member].isContainerField()) break :one_line;
        }
        // All the declarations on the same line.
        try renderToken(ais, tree, lbrace, .Space); // lbrace
        for (container_decl.ast.members) |member| {
            try renderMember(ais, tree, member, .Space);
        }
        return renderToken(ais, tree, rbrace, space); // rbrace
    }

    // One member per line.
    ais.pushIndent();
    try renderToken(ais, tree, lbrace, .Newline); // lbrace
    for (container_decl.ast.members) |member, i| {
        try renderMember(ais, tree, member, .Newline);

        if (i + 1 < container_decl.ast.members.len) {
            try renderExtraNewline(ais, tree, container_decl.ast.members[i + 1]);
        }
    }
    ais.popIndent();

    return renderToken(ais, tree, rbrace, space); // rbrace
}

fn renderAsm(
    ais: *Ais,
    tree: ast.Tree,
    asm_node: ast.full.Asm,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);

    try renderToken(ais, tree, asm_node.ast.asm_token, .Space); // asm

    if (asm_node.volatile_token) |volatile_token| {
        try renderToken(ais, tree, volatile_token, .Space); // volatile
        try renderToken(ais, tree, volatile_token + 1, .None); // lparen
    } else {
        try renderToken(ais, tree, asm_node.ast.asm_token + 1, .None); // lparen
    }

    if (asm_node.ast.items.len == 0) {
        try renderExpression(ais, tree, asm_node.ast.template, .None);
        if (asm_node.first_clobber) |first_clobber| {
            // asm ("foo" ::: "a", "b")
            var tok_i = first_clobber;
            while (true) : (tok_i += 1) {
                try renderToken(ais, tree, tok_i, .None);
                tok_i += 1;
                switch (token_tags[tok_i]) {
                    .RParen => return renderToken(ais, tree, tok_i, space),
                    .Comma => try renderToken(ais, tree, tok_i, .Space),
                    else => unreachable,
                }
            }
        } else {
            // asm ("foo")
            return renderToken(ais, tree, asm_node.ast.rparen, space); // rparen
        }
    }

    ais.pushIndent();
    try renderExpression(ais, tree, asm_node.ast.template, .Newline);
    ais.setIndentDelta(asm_indent_delta);
    const colon1 = tree.lastToken(asm_node.ast.template) + 1;

    const colon2 = if (asm_node.outputs.len == 0) colon2: {
        try renderToken(ais, tree, colon1, .Newline); // :
        break :colon2 colon1 + 1;
    } else colon2: {
        try renderToken(ais, tree, colon1, .Space); // :

        ais.pushIndent();
        for (asm_node.outputs) |asm_output, i| {
            if (i + 1 < asm_node.outputs.len) {
                const next_asm_output = asm_node.outputs[i + 1];
                try renderAsmOutput(ais, tree, asm_output, .None);

                const comma = tree.firstToken(next_asm_output) - 1;
                try renderToken(ais, tree, comma, .Newline); // ,
                try renderExtraNewlineToken(ais, tree, tree.firstToken(next_asm_output));
            } else if (asm_node.inputs.len == 0 and asm_node.first_clobber == null) {
                try renderAsmOutput(ais, tree, asm_output, .Newline);
                ais.popIndent();
                ais.setIndentDelta(indent_delta);
                ais.popIndent();
                return renderToken(ais, tree, asm_node.ast.rparen, space); // rparen
            } else {
                try renderAsmOutput(ais, tree, asm_output, .Newline);
                const comma_or_colon = tree.lastToken(asm_output) + 1;
                ais.popIndent();
                break :colon2 switch (token_tags[comma_or_colon]) {
                    .Comma => comma_or_colon + 1,
                    else => comma_or_colon,
                };
            }
        } else unreachable;
    };

    const colon3 = if (asm_node.inputs.len == 0) colon3: {
        try renderToken(ais, tree, colon2, .Newline); // :
        break :colon3 colon2 + 1;
    } else colon3: {
        try renderToken(ais, tree, colon2, .Space); // :
        ais.pushIndent();
        for (asm_node.inputs) |asm_input, i| {
            if (i + 1 < asm_node.inputs.len) {
                const next_asm_input = asm_node.inputs[i + 1];
                try renderAsmInput(ais, tree, asm_input, .None);

                const first_token = tree.firstToken(next_asm_input);
                try renderToken(ais, tree, first_token - 1, .Newline); // ,
                try renderExtraNewlineToken(ais, tree, first_token);
            } else if (asm_node.first_clobber == null) {
                try renderAsmInput(ais, tree, asm_input, .Newline);
                ais.popIndent();
                ais.setIndentDelta(indent_delta);
                ais.popIndent();
                return renderToken(ais, tree, asm_node.ast.rparen, space); // rparen
            } else {
                try renderAsmInput(ais, tree, asm_input, .Newline);
                const comma_or_colon = tree.lastToken(asm_input) + 1;
                ais.popIndent();
                break :colon3 switch (token_tags[comma_or_colon]) {
                    .Comma => comma_or_colon + 1,
                    else => comma_or_colon,
                };
            }
        }
        unreachable;
    };

    try renderToken(ais, tree, colon3, .Space); // :
    const first_clobber = asm_node.first_clobber.?;
    var tok_i = first_clobber;
    while (true) {
        switch (token_tags[tok_i + 1]) {
            .RParen => {
                ais.setIndentDelta(indent_delta);
                ais.popIndent();
                try renderToken(ais, tree, tok_i, .Newline);
                return renderToken(ais, tree, tok_i + 1, space);
            },
            .Comma => {
                try renderToken(ais, tree, tok_i, .None);
                try renderToken(ais, tree, tok_i + 1, .Space);
                tok_i += 2;
            },
            else => unreachable,
        }
    } else unreachable; // TODO shouldn't need this on while(true)
}

/// Render an expression, and the comma that follows it, if it is present in the source.
fn renderExpressionComma(ais: *Ais, tree: ast.Tree, node: ast.Node.Index, space: Space) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const maybe_comma = tree.lastToken(node) + 1;
    if (token_tags[maybe_comma] == .Comma) {
        try renderExpression(ais, tree, node, .None);
        return renderToken(ais, tree, maybe_comma, space);
    } else {
        return renderExpression(ais, tree, node, space);
    }
}

/// Render an expression, but first insert an extra newline if the previous token is 2 or
/// more lines away.
fn renderExpressionNewlined(
    ais: *Ais,
    tree: ast.Tree,
    node: ast.Node.Index,
    space: Space,
) Error!void {
    const token_starts = tree.tokens.items(.start);
    const first_token = tree.firstToken(node);
    if (tree.tokenLocation(token_starts[first_token - 1], first_token).line >= 2) {
        try ais.insertNewline();
    }
    return renderExpression(ais, tree, node, space);
}

fn renderTokenComma(ais: *Ais, tree: ast.Tree, token: ast.TokenIndex, space: Space) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const maybe_comma = token + 1;
    if (token_tags[maybe_comma] == .Comma) {
        try renderToken(ais, tree, token, .None);
        return renderToken(ais, tree, maybe_comma, space);
    } else {
        return renderToken(ais, tree, token, space);
    }
}

const Space = enum {
    /// Output the token lexeme only.
    None,
    /// Output the token lexeme followed by a single space.
    Space,
    /// Output the token lexeme followed by a newline.
    Newline,
    /// Additionally consume the next token if it is a comma.
    /// In either case, a newline will be inserted afterwards.
    Comma,
    /// Additionally consume the next token if it is a comma.
    /// In either case, a space will be inserted afterwards.
    CommaSpace,
    /// Additionally consume the next token if it is a semicolon.
    /// In either case, a newline will be inserted afterwards.
    Semicolon,
    /// Skips writing the possible line comment after the token.
    NoComment,
};

fn renderToken(ais: *Ais, tree: ast.Tree, token_index: ast.TokenIndex, space: Space) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const token_starts = tree.tokens.items(.start);

    const token_start = token_starts[token_index];
    const token_tag = token_tags[token_index];
    const lexeme = token_tag.lexeme() orelse lexeme: {
        var tokenizer: std.zig.Tokenizer = .{
            .buffer = tree.source,
            .index = token_start,
            .pending_invalid_token = null,
        };
        const token = tokenizer.next();
        assert(token.tag == token_tag);
        break :lexeme tree.source[token.loc.start..token.loc.end];
    };
    try ais.writer().writeAll(lexeme);

    switch (space) {
        .NoComment => {},
        .None => {},
        .Comma => {
            const count = try renderComments(ais, tree, token_start + lexeme.len, token_starts[token_index + 1], ", ");
            if (count == 0 and token_tags[token_index + 1] == .Comma) {
                return renderToken(ais, tree, token_index + 1, Space.Newline);
            }
            try ais.writer().writeAll(",");

            if (token_tags[token_index + 2] != .MultilineStringLiteralLine) {
                try ais.insertNewline();
            }
        },
        .CommaSpace => {
            _ = try renderComments(ais, tree, token_start + lexeme.len, token_starts[token_index + 1], "");
            if (token_tags[token_index + 1] == .Comma) {
                return renderToken(ais, tree, token_index + 1, .Space);
            } else {
                return ais.writer().writeByte(' ');
            }
        },
        .Semicolon => {
            _ = try renderComments(ais, tree, token_start + lexeme.len, token_starts[token_index + 1], "");
            if (token_tags[token_index + 1] == .Semicolon) {
                return renderToken(ais, tree, token_index + 1, .Newline);
            } else {
                return ais.insertNewline();
            }
        },
        .Space => {
            _ = try renderComments(ais, tree, token_start + lexeme.len, token_starts[token_index + 1], "");
            return ais.writer().writeByte(' ');
        },
        .Newline => {
            if (token_tags[token_index + 1] != .MultilineStringLiteralLine) {
                try ais.insertNewline();
            }
        },
    }
}

/// end_token is the token one past the last doc comment token. This function
/// searches backwards from there.
fn renderDocComments(ais: *Ais, tree: ast.Tree, end_token: ast.TokenIndex) Error!void {
    // Search backwards for the first doc comment.
    const token_tags = tree.tokens.items(.tag);
    if (end_token == 0) return;
    var tok = end_token - 1;
    while (token_tags[tok] == .DocComment) {
        if (tok == 0) break;
        tok -= 1;
    } else {
        tok += 1;
    }
    const first_tok = tok;
    if (tok == end_token) return;

    while (true) : (tok += 1) {
        switch (token_tags[tok]) {
            .DocComment => {
                if (first_tok < end_token) {
                    try renderToken(ais, tree, tok, .Newline);
                } else {
                    try renderToken(ais, tree, tok, .NoComment);
                    try ais.insertNewline();
                }
            },
            else => break,
        }
    }
}

fn nodeIsBlock(tag: ast.Node.Tag) bool {
    return switch (tag) {
        .Block,
        .BlockSemicolon,
        .BlockTwo,
        .BlockTwoSemicolon,
        .If,
        .IfSimple,
        .For,
        .ForSimple,
        .While,
        .WhileSimple,
        .WhileCont,
        .Switch,
        .SwitchComma,
        => true,
        else => false,
    };
}

fn nodeCausesSliceOpSpace(tag: ast.Node.Tag) bool {
    return switch (tag) {
        .Catch,
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
        .Sub,
        .SubWrap,
        .OrElse,
        => true,

        else => false,
    };
}

fn copyFixingWhitespace(ais: *Ais, slice: []const u8) @TypeOf(ais.*).Error!void {
    const writer = ais.writer();
    for (slice) |byte| switch (byte) {
        '\t' => try writer.writeAll("    "),
        '\r' => {},
        else => try writer.writeByte(byte),
    };
}

// Returns the number of nodes in `expr` that are on the same line as `rtoken`,
// or null if they all are on the same line.
fn rowSize(tree: ast.Tree, exprs: []ast.Node.Index, rtoken: ast.TokenIndex) ?usize {
    const first_token = exprs[0].firstToken();
    const first_loc = tree.tokenLocation(tree.token_locs[first_token].start, rtoken);
    if (first_loc.line == 0) {
        const maybe_comma = tree.prevToken(rtoken);
        if (tree.token_tags[maybe_comma] == .Comma)
            return 1;
        return null; // no newlines
    }

    var count: usize = 1;
    for (exprs) |expr, i| {
        if (i + 1 < exprs.len) {
            const expr_last_token = expr.lastToken() + 1;
            const loc = tree.tokenLocation(tree.token_locs[expr_last_token].start, exprs[i + 1].firstToken());
            if (loc.line != 0) return count;
            count += 1;
        } else {
            return count;
        }
    }
    unreachable;
}
