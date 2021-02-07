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

/// `gpa` is used both for allocating the resulting formatted source code, but also
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
            try renderToken(ais, tree, tree.lastToken(decl) + 1, space); // semicolon
        },

        .UsingNamespace => unreachable, // TODO
        //    .Use => {
        //        const use_decl = @fieldParentPtr(ast.Node.Use, "base", decl);

        //        if (use_decl.visib_token) |visib_token| {
        //            try renderToken(ais, tree, visib_token, .Space); // pub
        //        }
        //        try renderToken(ais, tree, use_decl.use_token, .Space); // usingnamespace
        //        try renderExpression(ais, tree, use_decl.expr, .None);
        //        try renderToken(ais, tree, use_decl.semicolon_token, space); // ;
        //    },

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

        .AnyType => unreachable, // TODO
        //.AnyType => {
        //    const any_type = base.castTag(.AnyType).?;
        //    if (mem.eql(u8, tree.tokenSlice(any_type.token), "var")) {
        //        // TODO remove in next release cycle
        //        try ais.writer().writeAll("anytype");
        //        if (space == .Comma) try ais.writer().writeAll(",\n");
        //        return;
        //    }
        //    return renderToken(ais, tree, any_type.token, space);
        //},
        .BlockTwo,
        .BlockTwoSemicolon,
        => {
            const statements = [2]ast.Node.Index{ datas[node].lhs, datas[node].rhs };
            if (datas[node].lhs == 0) {
                return renderBlock(ais, tree, main_tokens[node], statements[0..0], space);
            } else if (datas[node].rhs == 0) {
                return renderBlock(ais, tree, main_tokens[node], statements[0..1], space);
            } else {
                return renderBlock(ais, tree, main_tokens[node], statements[0..2], space);
            }
        },
        .Block,
        .BlockSemicolon,
        => {
            const lbrace = main_tokens[node];
            const statements = tree.extra_data[datas[node].lhs..datas[node].rhs];
            return renderBlock(ais, tree, main_tokens[node], statements, space);
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

        .Suspend => unreachable, // TODO
        //.Suspend => {
        //    const suspend_node = @fieldParentPtr(ast.Node.Suspend, "base", base);

        //    if (suspend_node.body) |body| {
        //        try renderToken(ais, tree, suspend_node.suspend_token, Space.Space);
        //        return renderExpression(ais, tree, body, space);
        //    } else {
        //        return renderToken(ais, tree, suspend_node.suspend_token, space);
        //    }
        //},

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

        .Break => unreachable, // TODO
        //.Break => {
        //    const flow_expr = base.castTag(.Break).?;
        //    const maybe_rhs = flow_expr.getRHS();
        //    const maybe_label = flow_expr.getLabel();

        //    if (maybe_label == null and maybe_rhs == null) {
        //        return renderToken(ais, tree, flow_expr.ltoken, space); // break
        //    }

        //    try renderToken(ais, tree, flow_expr.ltoken, Space.Space); // break
        //    if (maybe_label) |label| {
        //        const colon = tree.nextToken(flow_expr.ltoken);
        //        try renderToken(ais, tree, colon, Space.None); // :

        //        if (maybe_rhs == null) {
        //            return renderToken(ais, tree, label, space); // label
        //        }
        //        try renderToken(ais, tree, label, Space.Space); // label
        //    }
        //    return renderExpression(ais, tree, maybe_rhs.?, space);
        //},

        .Continue => unreachable, // TODO
        //.Continue => {
        //    const flow_expr = base.castTag(.Continue).?;
        //    if (flow_expr.getLabel()) |label| {
        //        try renderToken(ais, tree, flow_expr.ltoken, Space.Space); // continue
        //        const colon = tree.nextToken(flow_expr.ltoken);
        //        try renderToken(ais, tree, colon, Space.None); // :
        //        return renderToken(ais, tree, label, space); // label
        //    } else {
        //        return renderToken(ais, tree, flow_expr.ltoken, space); // continue
        //    }
        //},

        .Return => {
            if (datas[node].lhs != 0) {
                try renderToken(ais, tree, main_tokens[node], .Space);
                try renderExpression(ais, tree, datas[node].lhs, space);
            } else {
                try renderToken(ais, tree, main_tokens[node], space);
            }
        },

        .GroupedExpression => unreachable, // TODO
        //.GroupedExpression => {
        //    const grouped_expr = @fieldParentPtr(ast.Node.GroupedExpression, "base", base);

        //    try renderToken(ais, tree, grouped_expr.lparen, Space.None);
        //    {
        //        ais.pushIndentOneShot();
        //        try renderExpression(ais, tree, grouped_expr.expr, Space.None);
        //    }
        //    return renderToken(ais, tree, grouped_expr.rparen, space);
        //},

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
                try renderToken(ais, tree, rbrace, space);
            } else if (lbrace + 2 == rbrace and token_tags[lbrace + 1] == .Identifier) {
                // There is exactly one member and no trailing comma or
                // comments, so render without surrounding spaces: `error{Foo}`
                try renderToken(ais, tree, lbrace, .None);
                try renderToken(ais, tree, lbrace + 1, .None); // identifier
                try renderToken(ais, tree, rbrace, space);
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
                try renderToken(ais, tree, rbrace, space);
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
                try renderToken(ais, tree, rbrace, space);
            }
        },
        //.ErrorSetDecl => {
        //    const err_set_decl = @fieldParentPtr(ast.Node.ErrorSetDecl, "base", base);

        //    const lbrace = tree.nextToken(err_set_decl.error_token);

        //    if (err_set_decl.decls_len == 0) {
        //        try renderToken(ais, tree, err_set_decl.error_token, Space.None);
        //        try renderToken(ais, tree, lbrace, Space.None);
        //        return renderToken(ais, tree, err_set_decl.rbrace_token, space);
        //    }

        //    if (err_set_decl.decls_len == 1) blk: {
        //        const node = err_set_decl.decls()[0];

        //        // if there are any doc comments or same line comments
        //        // don't try to put it all on one line
        //        if (node.cast(ast.Node.ErrorTag)) |tag| {
        //            if (tag.doc_comments != null) break :blk;
        //        } else {
        //            break :blk;
        //        }

        //        try renderToken(ais, tree, err_set_decl.error_token, Space.None); // error
        //        try renderToken(ais, tree, lbrace, Space.None); // lbrace
        //        try renderExpression(ais, tree, node, Space.None);
        //        return renderToken(ais, tree, err_set_decl.rbrace_token, space); // rbrace
        //    }

        //    try renderToken(ais, tree, err_set_decl.error_token, Space.None); // error

        //    const src_has_trailing_comma = blk: {
        //        const maybe_comma = tree.prevToken(err_set_decl.rbrace_token);
        //        break :blk tree.token_tags[maybe_comma] == .Comma;
        //    };

        //    if (src_has_trailing_comma) {
        //        {
        //            ais.pushIndent();
        //            defer ais.popIndent();

        //            try renderToken(ais, tree, lbrace, Space.Newline); // lbrace
        //            const decls = err_set_decl.decls();
        //            for (decls) |node, i| {
        //                if (i + 1 < decls.len) {
        //                    try renderExpression(ais, tree, node, Space.None);
        //                    try renderToken(ais, tree, tree.nextToken(node.lastToken()), Space.Newline); // ,

        //                    try renderExtraNewline(ais, tree, decls[i + 1]);
        //                } else {
        //                    try renderExpression(ais, tree, node, Space.Comma);
        //                }
        //            }
        //        }

        //        return renderToken(ais, tree, err_set_decl.rbrace_token, space); // rbrace
        //    } else {
        //        try renderToken(ais, tree, lbrace, Space.Space); // lbrace

        //        const decls = err_set_decl.decls();
        //        for (decls) |node, i| {
        //            if (i + 1 < decls.len) {
        //                try renderExpression(ais, tree, node, Space.None);

        //                const comma_token = tree.nextToken(node.lastToken());
        //                assert(tree.token_tags[comma_token] == .Comma);
        //                try renderToken(ais, tree, comma_token, Space.Space); // ,
        //                try renderExtraNewline(ais, tree, decls[i + 1]);
        //            } else {
        //                try renderExpression(ais, tree, node, Space.Space);
        //            }
        //        }

        //        return renderToken(ais, tree, err_set_decl.rbrace_token, space); // rbrace
        //    }
        //},

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

        .Switch => unreachable, // TODO
        //.Switch => {
        //    const switch_node = @fieldParentPtr(ast.Node.Switch, "base", base);

        //    try renderToken(ais, tree, switch_node.switch_token, Space.Space); // switch
        //    try renderToken(ais, tree, tree.nextToken(switch_node.switch_token), Space.None); // (

        //    const rparen = tree.nextToken(switch_node.expr.lastToken());
        //    const lbrace = tree.nextToken(rparen);

        //    if (switch_node.cases_len == 0) {
        //        try renderExpression(ais, tree, switch_node.expr, Space.None);
        //        try renderToken(ais, tree, rparen, Space.Space); // )
        //        try renderToken(ais, tree, lbrace, Space.None); // lbrace
        //        return renderToken(ais, tree, switch_node.rbrace, space); // rbrace
        //    }

        //    try renderExpression(ais, tree, switch_node.expr, Space.None);
        //    try renderToken(ais, tree, rparen, Space.Space); // )

        //    {
        //        ais.pushIndentNextLine();
        //        defer ais.popIndent();
        //        try renderToken(ais, tree, lbrace, Space.Newline); // lbrace

        //        const cases = switch_node.cases();
        //        for (cases) |node, i| {
        //            try renderExpression(ais, tree, node, Space.Comma);

        //            if (i + 1 < cases.len) {
        //                try renderExtraNewline(ais, tree, cases[i + 1]);
        //            }
        //        }
        //    }

        //    return renderToken(ais, tree, switch_node.rbrace, space); // rbrace
        //},

        .SwitchCaseOne => unreachable, // TODO
        .SwitchCaseMulti => unreachable, // TODO
        //.SwitchCase => {
        //    const switch_case = @fieldParentPtr(ast.Node.SwitchCase, "base", base);

        //    assert(switch_case.items_len != 0);
        //    const src_has_trailing_comma = blk: {
        //        const last_node = switch_case.items()[switch_case.items_len - 1];
        //        const maybe_comma = tree.nextToken(last_node.lastToken());
        //        break :blk tree.token_tags[maybe_comma] == .Comma;
        //    };

        //    if (switch_case.items_len == 1 or !src_has_trailing_comma) {
        //        const items = switch_case.items();
        //        for (items) |node, i| {
        //            if (i + 1 < items.len) {
        //                try renderExpression(ais, tree, node, Space.None);

        //                const comma_token = tree.nextToken(node.lastToken());
        //                try renderToken(ais, tree, comma_token, Space.Space); // ,
        //                try renderExtraNewline(ais, tree, items[i + 1]);
        //            } else {
        //                try renderExpression(ais, tree, node, Space.Space);
        //            }
        //        }
        //    } else {
        //        const items = switch_case.items();
        //        for (items) |node, i| {
        //            if (i + 1 < items.len) {
        //                try renderExpression(ais, tree, node, Space.None);

        //                const comma_token = tree.nextToken(node.lastToken());
        //                try renderToken(ais, tree, comma_token, Space.Newline); // ,
        //                try renderExtraNewline(ais, tree, items[i + 1]);
        //            } else {
        //                try renderExpression(ais, tree, node, Space.Comma);
        //            }
        //        }
        //    }

        //    try renderToken(ais, tree, switch_case.arrow_token, Space.Space); // =>

        //    if (switch_case.payload) |payload| {
        //        try renderExpression(ais, tree, payload, Space.Space);
        //    }

        //    return renderExpression(ais, tree, switch_case.expr, space);
        //},

        .WhileSimple => unreachable, // TODO
        .WhileCont => unreachable, // TODO
        .While => unreachable, // TODO
        //.While => {
        //    const while_node = @fieldParentPtr(ast.Node.While, "base", base);

        //    if (while_node.label) |label| {
        //        try renderToken(ais, tree, label, Space.None); // label
        //        try renderToken(ais, tree, tree.nextToken(label), Space.Space); // :
        //    }

        //    if (while_node.inline_token) |inline_token| {
        //        try renderToken(ais, tree, inline_token, Space.Space); // inline
        //    }

        //    try renderToken(ais, tree, while_node.while_token, Space.Space); // while
        //    try renderToken(ais, tree, tree.nextToken(while_node.while_token), Space.None); // (
        //    try renderExpression(ais, tree, while_node.condition, Space.None);

        //    const cond_rparen = tree.nextToken(while_node.condition.lastToken());

        //    const body_is_block = nodeIsBlock(while_node.body);

        //    var block_start_space: Space = undefined;
        //    var after_body_space: Space = undefined;

        //    if (body_is_block) {
        //        block_start_space = Space.BlockStart;
        //        after_body_space = if (while_node.@"else" == null) space else Space.Space;
        //    } else if (tree.tokensOnSameLine(cond_rparen, while_node.body.lastToken())) {
        //        block_start_space = Space.Space;
        //        after_body_space = if (while_node.@"else" == null) space else Space.Space;
        //    } else {
        //        block_start_space = Space.Newline;
        //        after_body_space = if (while_node.@"else" == null) space else Space.Newline;
        //    }

        //    {
        //        const rparen_space = if (while_node.payload != null or while_node.continue_expr != null) Space.Space else block_start_space;
        //        try renderToken(ais, tree, cond_rparen, rparen_space); // )
        //    }

        //    if (while_node.payload) |payload| {
        //        const payload_space = if (while_node.continue_expr != null) Space.Space else block_start_space;
        //        try renderExpression(ais, tree, payload, payload_space);
        //    }

        //    if (while_node.continue_expr) |continue_expr| {
        //        const rparen = tree.nextToken(continue_expr.lastToken());
        //        const lparen = tree.prevToken(continue_expr.firstToken());
        //        const colon = tree.prevToken(lparen);

        //        try renderToken(ais, tree, colon, Space.Space); // :
        //        try renderToken(ais, tree, lparen, Space.None); // (

        //        try renderExpression(ais, tree, continue_expr, Space.None);

        //        try renderToken(ais, tree, rparen, block_start_space); // )
        //    }

        //    {
        //        if (!body_is_block) ais.pushIndent();
        //        defer if (!body_is_block) ais.popIndent();
        //        try renderExpression(ais, tree, while_node.body, after_body_space);
        //    }

        //    if (while_node.@"else") |@"else"| {
        //        return renderExpression(ais, tree, &@"else".base, space);
        //    }
        //},

        .ForSimple => unreachable, // TODO
        .For => unreachable, // TODO
        //.For => {
        //    const for_node = @fieldParentPtr(ast.Node.For, "base", base);

        //    if (for_node.label) |label| {
        //        try renderToken(ais, tree, label, Space.None); // label
        //        try renderToken(ais, tree, tree.nextToken(label), Space.Space); // :
        //    }

        //    if (for_node.inline_token) |inline_token| {
        //        try renderToken(ais, tree, inline_token, Space.Space); // inline
        //    }

        //    try renderToken(ais, tree, for_node.for_token, Space.Space); // for
        //    try renderToken(ais, tree, tree.nextToken(for_node.for_token), Space.None); // (
        //    try renderExpression(ais, tree, for_node.array_expr, Space.None);

        //    const rparen = tree.nextToken(for_node.array_expr.lastToken());

        //    const body_is_block = for_node.body.tag.isBlock();
        //    const src_one_line_to_body = !body_is_block and tree.tokensOnSameLine(rparen, for_node.body.firstToken());
        //    const body_on_same_line = body_is_block or src_one_line_to_body;

        //    try renderToken(ais, tree, rparen, Space.Space); // )

        //    const space_after_payload = if (body_on_same_line) Space.Space else Space.Newline;
        //    try renderExpression(ais, tree, for_node.payload, space_after_payload); // |x|

        //    const space_after_body = blk: {
        //        if (for_node.@"else") |@"else"| {
        //            const src_one_line_to_else = tree.tokensOnSameLine(rparen, @"else".firstToken());
        //            if (body_is_block or src_one_line_to_else) {
        //                break :blk Space.Space;
        //            } else {
        //                break :blk Space.Newline;
        //            }
        //        } else {
        //            break :blk space;
        //        }
        //    };

        //    {
        //        if (!body_on_same_line) ais.pushIndent();
        //        defer if (!body_on_same_line) ais.popIndent();
        //        try renderExpression(ais, tree, for_node.body, space_after_body); // { body }
        //    }

        //    if (for_node.@"else") |@"else"| {
        //        return renderExpression(ais, tree, &@"else".base, space); // else
        //    }
        //},

        .IfSimple => return renderIf(ais, tree, tree.ifSimple(node), space),
        .If => return renderIf(ais, tree, tree.ifFull(node), space),

        .Asm => unreachable, // TODO
        .AsmSimple => unreachable, // TODO
        .AsmOutput => unreachable, // TODO
        .AsmInput => unreachable, // TODO
        //.Asm => {
        //    const asm_node = @fieldParentPtr(ast.Node.Asm, "base", base);

        //    try renderToken(ais, tree, asm_node.asm_token, Space.Space); // asm

        //    if (asm_node.volatile_token) |volatile_token| {
        //        try renderToken(ais, tree, volatile_token, Space.Space); // volatile
        //        try renderToken(ais, tree, tree.nextToken(volatile_token), Space.None); // (
        //    } else {
        //        try renderToken(ais, tree, tree.nextToken(asm_node.asm_token), Space.None); // (
        //    }

        //    asmblk: {
        //        ais.pushIndent();
        //        defer ais.popIndent();

        //        if (asm_node.outputs.len == 0 and asm_node.inputs.len == 0 and asm_node.clobbers.len == 0) {
        //            try renderExpression(ais, tree, asm_node.template, Space.None);
        //            break :asmblk;
        //        }

        //        try renderExpression(ais, tree, asm_node.template, Space.Newline);

        //        ais.setIndentDelta(asm_indent_delta);
        //        defer ais.setIndentDelta(indent_delta);

        //        const colon1 = tree.nextToken(asm_node.template.lastToken());

        //        const colon2 = if (asm_node.outputs.len == 0) blk: {
        //            try renderToken(ais, tree, colon1, Space.Newline); // :

        //            break :blk tree.nextToken(colon1);
        //        } else blk: {
        //            try renderToken(ais, tree, colon1, Space.Space); // :

        //            ais.pushIndent();
        //            defer ais.popIndent();

        //            for (asm_node.outputs) |*asm_output, i| {
        //                if (i + 1 < asm_node.outputs.len) {
        //                    const next_asm_output = asm_node.outputs[i + 1];
        //                    try renderAsmOutput(allocator, ais, tree, asm_output, Space.None);

        //                    const comma = tree.prevToken(next_asm_output.firstToken());
        //                    try renderToken(ais, tree, comma, Space.Newline); // ,
        //                    try renderExtraNewlineToken(ais, tree, next_asm_output.firstToken());
        //                } else if (asm_node.inputs.len == 0 and asm_node.clobbers.len == 0) {
        //                    try renderAsmOutput(allocator, ais, tree, asm_output, Space.Newline);
        //                    break :asmblk;
        //                } else {
        //                    try renderAsmOutput(allocator, ais, tree, asm_output, Space.Newline);
        //                    const comma_or_colon = tree.nextToken(asm_output.lastToken());
        //                    break :blk switch (tree.token_tags[comma_or_colon]) {
        //                        .Comma => tree.nextToken(comma_or_colon),
        //                        else => comma_or_colon,
        //                    };
        //                }
        //            }
        //            unreachable;
        //        };

        //        const colon3 = if (asm_node.inputs.len == 0) blk: {
        //            try renderToken(ais, tree, colon2, Space.Newline); // :
        //            break :blk tree.nextToken(colon2);
        //        } else blk: {
        //            try renderToken(ais, tree, colon2, Space.Space); // :
        //            ais.pushIndent();
        //            defer ais.popIndent();
        //            for (asm_node.inputs) |*asm_input, i| {
        //                if (i + 1 < asm_node.inputs.len) {
        //                    const next_asm_input = &asm_node.inputs[i + 1];
        //                    try renderAsmInput(allocator, ais, tree, asm_input, Space.None);

        //                    const comma = tree.prevToken(next_asm_input.firstToken());
        //                    try renderToken(ais, tree, comma, Space.Newline); // ,
        //                    try renderExtraNewlineToken(ais, tree, next_asm_input.firstToken());
        //                } else if (asm_node.clobbers.len == 0) {
        //                    try renderAsmInput(allocator, ais, tree, asm_input, Space.Newline);
        //                    break :asmblk;
        //                } else {
        //                    try renderAsmInput(allocator, ais, tree, asm_input, Space.Newline);
        //                    const comma_or_colon = tree.nextToken(asm_input.lastToken());
        //                    break :blk switch (tree.token_tags[comma_or_colon]) {
        //                        .Comma => tree.nextToken(comma_or_colon),
        //                        else => comma_or_colon,
        //                    };
        //                }
        //            }
        //            unreachable;
        //        };

        //        try renderToken(ais, tree, colon3, Space.Space); // :
        //        ais.pushIndent();
        //        defer ais.popIndent();
        //        for (asm_node.clobbers) |clobber_node, i| {
        //            if (i + 1 >= asm_node.clobbers.len) {
        //                try renderExpression(ais, tree, clobber_node, Space.Newline);
        //                break :asmblk;
        //            } else {
        //                try renderExpression(ais, tree, clobber_node, Space.None);
        //                const comma = tree.nextToken(clobber_node.lastToken());
        //                try renderToken(ais, tree, comma, Space.Space); // ,
        //            }
        //        }
        //    }

        //    return renderToken(ais, tree, asm_node.rparen, space);
        //},

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
    }
}

// TODO: handle comments inside the brackets
fn renderArrayType(
    ais: *Ais,
    tree: ast.Tree,
    array_type: ast.Full.ArrayType,
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
    ptr_type: ast.Full.PtrType,
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
    slice: ast.Full.Slice,
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
    allocator: *mem.Allocator,
    ais: *Ais,
    tree: ast.Tree,
    asm_output: *const ast.Node.Asm.Output,
    space: Space,
) Error!void {
    try ais.writer().writeAll("[");
    try renderExpression(ais, tree, asm_output.symbolic_name, Space.None);
    try ais.writer().writeAll("] ");
    try renderExpression(ais, tree, asm_output.constraint, Space.None);
    try ais.writer().writeAll(" (");

    switch (asm_output.kind) {
        .Variable => |variable_name| {
            try renderExpression(ais, tree, &variable_name.base, Space.None);
        },
        .Return => |return_type| {
            try ais.writer().writeAll("-> ");
            try renderExpression(ais, tree, return_type, Space.None);
        },
    }

    return renderToken(ais, tree, asm_output.lastToken(), space); // )
}

fn renderAsmInput(
    allocator: *mem.Allocator,
    ais: *Ais,
    tree: ast.Tree,
    asm_input: *const ast.Node.Asm.Input,
    space: Space,
) Error!void {
    try ais.writer().writeAll("[");
    try renderExpression(ais, tree, asm_input.symbolic_name, Space.None);
    try ais.writer().writeAll("] ");
    try renderExpression(ais, tree, asm_input.constraint, Space.None);
    try ais.writer().writeAll(" (");
    try renderExpression(ais, tree, asm_input.expr, Space.None);
    return renderToken(ais, tree, asm_input.lastToken(), space); // )
}

fn renderVarDecl(ais: *Ais, tree: ast.Tree, var_decl: ast.Full.VarDecl) Error!void {
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

fn renderIf(ais: *Ais, tree: ast.Tree, if_node: ast.Full.If, space: Space) Error!void {
    const node_tags = tree.nodes.items(.tag);
    const token_tags = tree.tokens.items(.tag);

    try renderToken(ais, tree, if_node.ast.if_token, .Space); // if

    const lparen = if_node.ast.if_token + 1;

    try renderToken(ais, tree, lparen, .None); // (
    try renderExpression(ais, tree, if_node.ast.cond_expr, .None); // condition

    switch (node_tags[if_node.ast.then_expr]) {
        .If, .IfSimple => {
            try renderExtraNewline(ais, tree, if_node.ast.then_expr);
        },
        .Block, .For, .ForSimple, .While, .WhileSimple, .Switch => {
            if (if_node.payload_token) |payload_token| {
                try renderToken(ais, tree, payload_token - 2, .Space); // )
                try renderToken(ais, tree, payload_token - 1, .None); // |
                if (token_tags[payload_token] == .Asterisk) {
                    try renderToken(ais, tree, payload_token, .None); // *
                    try renderToken(ais, tree, payload_token + 1, .None); // identifier
                    try renderToken(ais, tree, payload_token + 2, .BlockStart); // |
                } else {
                    try renderToken(ais, tree, payload_token, .None); // identifier
                    try renderToken(ais, tree, payload_token + 1, .BlockStart); // |
                }
            } else {
                const rparen = tree.lastToken(if_node.ast.cond_expr) + 1;
                try renderToken(ais, tree, rparen, .BlockStart); // )
            }
            if (if_node.ast.else_expr != 0) {
                try renderExpression(ais, tree, if_node.ast.then_expr, Space.Space);
                try renderToken(ais, tree, if_node.else_token, .Space); // else
                if (if_node.error_token) |error_token| {
                    try renderToken(ais, tree, error_token - 1, .None); // |
                    try renderToken(ais, tree, error_token, .None); // identifier
                    try renderToken(ais, tree, error_token + 1, .Space); // |
                }
                return renderExpression(ais, tree, if_node.ast.else_expr, space);
            } else {
                return renderExpression(ais, tree, if_node.ast.then_expr, space);
            }
        },
        else => {},
    }

    const rparen = tree.lastToken(if_node.ast.cond_expr) + 1;
    const last_then_token = tree.lastToken(if_node.ast.then_expr);
    const src_has_newline = !tree.tokensOnSameLine(rparen, last_then_token);

    if (src_has_newline) {
        if (if_node.payload_token) |payload_token| {
            try renderToken(ais, tree, payload_token - 2, .Space); // )
            try renderToken(ais, tree, payload_token - 1, .None); // |
            try renderToken(ais, tree, payload_token, .None); // identifier
            try renderToken(ais, tree, payload_token + 1, .Newline); // |
        } else {
            ais.pushIndent();
            try renderToken(ais, tree, rparen, .Newline); // )
            ais.popIndent();
        }
        if (if_node.ast.else_expr != 0) {
            ais.pushIndent();
            try renderExpression(ais, tree, if_node.ast.then_expr, Space.Newline);
            ais.popIndent();
            const else_is_block = nodeIsBlock(node_tags[if_node.ast.else_expr]);
            if (else_is_block) {
                try renderToken(ais, tree, if_node.else_token, .Space); // else
                if (if_node.error_token) |error_token| {
                    try renderToken(ais, tree, error_token - 1, .None); // |
                    try renderToken(ais, tree, error_token, .None); // identifier
                    try renderToken(ais, tree, error_token + 1, .Space); // |
                }
                return renderExpression(ais, tree, if_node.ast.else_expr, space);
            } else {
                if (if_node.error_token) |error_token| {
                    try renderToken(ais, tree, if_node.else_token, .Space); // else
                    try renderToken(ais, tree, error_token - 1, .None); // |
                    try renderToken(ais, tree, error_token, .None); // identifier
                    try renderToken(ais, tree, error_token + 1, .Space); // |
                } else {
                    try renderToken(ais, tree, if_node.else_token, .Newline); // else
                }
                ais.pushIndent();
                try renderExpression(ais, tree, if_node.ast.else_expr, space);
                ais.popIndent();
                return;
            }
        } else {
            ais.pushIndent();
            try renderExpression(ais, tree, if_node.ast.then_expr, space);
            ais.popIndent();
            return;
        }
    }

    // Single line if statement.

    if (if_node.payload_token) |payload_token| {
        assert(payload_token - 2 == rparen);
        try renderToken(ais, tree, payload_token - 2, .Space); // )
        try renderToken(ais, tree, payload_token - 1, .None); // |
        if (token_tags[payload_token] == .Asterisk) {
            try renderToken(ais, tree, payload_token, .None); // *
            try renderToken(ais, tree, payload_token + 1, .None); // identifier
            try renderToken(ais, tree, payload_token + 2, .Space); // |
        } else {
            try renderToken(ais, tree, payload_token, .None); // identifier
            try renderToken(ais, tree, payload_token + 1, .Space); // |
        }
    } else {
        try renderToken(ais, tree, rparen, .Space); // )
    }

    if (if_node.ast.else_expr != 0) {
        try renderExpression(ais, tree, if_node.ast.then_expr, .Space);
        try renderToken(ais, tree, if_node.else_token, .Space); // else

        if (if_node.error_token) |error_token| {
            try renderToken(ais, tree, error_token - 1, .None); // |
            try renderToken(ais, tree, error_token, .None); // identifier
            try renderToken(ais, tree, error_token + 1, .Space); // |
        }

        return renderExpression(ais, tree, if_node.ast.else_expr, space);
    } else {
        return renderExpression(ais, tree, if_node.ast.then_expr, space);
    }
}

fn renderContainerField(
    ais: *Ais,
    tree: ast.Tree,
    field: ast.Full.ContainerField,
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

fn renderFnProto(ais: *Ais, tree: ast.Tree, fn_proto: ast.Full.FnProto, space: Space) Error!void {
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
                else => unreachable,
            }
            if (token_tags[last_param_token] == .Identifier) {
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
            last_param_token = tree.lastToken(param) + 1;
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

fn renderBlock(
    ais: *Ais,
    tree: ast.Tree,
    lbrace: ast.TokenIndex,
    statements: []const ast.Node.Index,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const node_tags = tree.nodes.items(.tag);
    const nodes_data = tree.nodes.items(.data);

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

    ais.pushIndent();
    try renderToken(ais, tree, lbrace, .Newline);
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
    // The rbrace could be +1 or +2 from the last token of the last
    // statement in the block because lastToken() does not count semicolons.
    const maybe_rbrace = tree.lastToken(statements[statements.len - 1]) + 1;
    if (token_tags[maybe_rbrace] == .RBrace) {
        return renderToken(ais, tree, maybe_rbrace, space);
    } else {
        assert(token_tags[maybe_rbrace + 1] == .RBrace);
        return renderToken(ais, tree, maybe_rbrace + 1, space);
    }
}

// TODO: handle comments between fields
fn renderStructInit(
    ais: *Ais,
    tree: ast.Tree,
    struct_init: ast.Full.StructInit,
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
    array_init: ast.Full.ArrayInit,
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
    container_decl: ast.Full.ContainerDecl,
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
    /// Intended when rendering lbrace tokens. Depending on whether the line is
    /// "over indented", will output a newline or a single space afterwards.
    /// See `std.io.AutoIndentingStream` for the definition of "over indented".
    BlockStart,
};

fn renderToken(ais: *Ais, tree: ast.Tree, token_index: ast.TokenIndex, space: Space) Error!void {
    if (space == Space.BlockStart) {
        const new_space: Space = if (ais.isLineOverIndented()) .Newline else .Space;
        return renderToken(ais, tree, token_index, new_space);
    }

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
        .BlockStart => unreachable,
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
        .If,
        .IfSimple,
        .For,
        .ForSimple,
        .While,
        .WhileSimple,
        .Switch,
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
