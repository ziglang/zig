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

/// Returns whether anything changed.
/// `gpa` is used for allocating extra stack memory if needed, because
/// this function utilizes recursion.
pub fn render(gpa: *mem.Allocator, writer: Writer, tree: ast.Tree) Error!void {
    assert(tree.errors.len == 0); // cannot render an invalid tree
    var auto_indenting_stream = std.io.autoIndentingStream(indent_delta, writer);
    return renderRoot(&auto_indenting_stream, tree);
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
        try renderContainerDecl(ais, tree, decl, .Newline);
    }
}

fn renderExtraNewline(ais: *Ais, tree: ast.Tree, node: ast.Node.Index) Error!void {
    return renderExtraNewlineToken(ais, tree, tree.firstToken(node));
}

fn renderExtraNewlineToken(ais: *Ais, tree: ast.Tree, first_token: ast.TokenIndex) Error!void {
    @panic("TODO implement renderExtraNewlineToken");
    //var prev_token = first_token;
    //if (prev_token == 0) return;
    //const token_tags = tree.tokens.items(.tag);
    //var newline_threshold: usize = 2;
    //while (token_tags[prev_token - 1] == .DocComment) {
    //    if (tree.tokenLocation(tree.token_locs[prev_token - 1].end, prev_token).line == 1) {
    //        newline_threshold += 1;
    //    }
    //    prev_token -= 1;
    //}
    //const prev_token_end = tree.token_locs[prev_token - 1].end;
    //const loc = tree.tokenLocation(prev_token_end, first_token);
    //if (loc.line >= newline_threshold) {
    //    try ais.insertNewline();
    //}
}

fn renderContainerDecl(ais: *Ais, tree: ast.Tree, decl: ast.Node.Index, space: Space) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const datas = tree.nodes.items(.data);
    try renderDocComments(ais, tree, tree.firstToken(decl));
    switch (tree.nodes.items(.tag)[decl]) {
        .FnProtoSimple => unreachable, // TODO
        .FnProtoSimpleMulti => unreachable, // TODO
        .FnProtoOne => unreachable, // TODO
        .FnDecl => unreachable, // TODO
        .FnProto => unreachable, // TODO
        //    .FnProto => {
        //        const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", decl);

        //        try renderDocComments(ais, tree, fn_proto, fn_proto.getDocComments());

        //        if (fn_proto.getBodyNode()) |body_node| {
        //            try renderExpression(ais, tree, decl, .Space);
        //            try renderExpression(ais, tree, body_node, space);
        //        } else {
        //            try renderExpression(ais, tree, decl, .None);
        //            try renderToken(ais, tree, tree.nextToken(decl.lastToken()), space);
        //        }
        //    },

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
        .Block => {
            const lbrace = main_tokens[node];
            if (token_tags[lbrace - 1] == .Colon and
                token_tags[lbrace - 2] == .Identifier)
            {
                try renderToken(ais, tree, lbrace - 2, .None);
                try renderToken(ais, tree, lbrace - 1, .Space);
            }
            const nodes_data = tree.nodes.items(.data);
            const statements = tree.extra_data[nodes_data[node].lhs..nodes_data[node].rhs];

            if (statements.len == 0) {
                ais.pushIndentNextLine();
                try renderToken(ais, tree, lbrace, .None);
                ais.popIndent();
                const rbrace = lbrace + 1;
                return renderToken(ais, tree, rbrace, space);
            } else {
                ais.pushIndentNextLine();

                try renderToken(ais, tree, lbrace, .Newline);

                for (statements) |stmt, i| {
                    switch (node_tags[stmt]) {
                        .GlobalVarDecl => try renderVarDecl(ais, tree, tree.globalVarDecl(stmt)),
                        .LocalVarDecl => try renderVarDecl(ais, tree, tree.localVarDecl(stmt)),
                        .SimpleVarDecl => try renderVarDecl(ais, tree, tree.simpleVarDecl(stmt)),
                        .AlignedVarDecl => try renderVarDecl(ais, tree, tree.alignedVarDecl(stmt)),
                        else => {
                            const semicolon = tree.lastToken(stmt) + 1;
                            if (token_tags[semicolon] == .Semicolon) {
                                try renderExpression(ais, tree, stmt, .None);
                                try renderToken(ais, tree, semicolon, .Newline);
                            } else {
                                try renderExpression(ais, tree, stmt, .Newline);
                            }
                        },
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
        },

        .Defer => unreachable, // TODO
        .ErrDefer => unreachable, // TODO
        //.Defer => {
        //    const defer_node = @fieldParentPtr(ast.Node.Defer, "base", base);

        //    try renderToken(ais, tree, defer_node.defer_token, Space.Space);
        //    if (defer_node.payload) |payload| {
        //        try renderExpression(ais, tree, payload, Space.Space);
        //    }
        //    return renderExpression(ais, tree, defer_node.expr, space);
        //},
        .Comptime => {
            const comptime_token = main_tokens[node];
            const block = datas[node].lhs;
            try renderToken(ais, tree, comptime_token, .Space);
            return renderExpression(ais, tree, block, space);
        },
        .Nosuspend => unreachable, // TODO
        //.Nosuspend => {
        //    const nosuspend_node = @fieldParentPtr(ast.Node.Nosuspend, "base", base);
        //    if (mem.eql(u8, tree.tokenSlice(nosuspend_node.nosuspend_token), "noasync")) {
        //        // TODO: remove this
        //        try ais.writer().writeAll("nosuspend ");
        //    } else {
        //        try renderToken(ais, tree, nosuspend_node.nosuspend_token, Space.Space);
        //    }
        //    return renderExpression(ais, tree, nosuspend_node.expr, space);
        //},

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

        .Catch => unreachable, // TODO
        //.Catch => {
        //    const infix_op_node = @fieldParentPtr(ast.Node.Catch, "base", base);

        //    const op_space = Space.Space;
        //    try renderExpression(ais, tree, infix_op_node.lhs, op_space);

        //    const after_op_space = blk: {
        //        const same_line = tree.tokensOnSameLine(infix_op_node.op_token, tree.nextToken(infix_op_node.op_token));
        //        break :blk if (same_line) op_space else Space.Newline;
        //    };

        //    try renderToken(ais, tree, infix_op_node.op_token, after_op_space);

        //    if (infix_op_node.payload) |payload| {
        //        try renderExpression(ais, tree, payload, Space.Space);
        //    }

        //    ais.pushIndentOneShot();
        //    return renderExpression(ais, tree, infix_op_node.rhs, space);
        //},
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

        .ArrayType => unreachable, // TODO
        //.ArrayType => {
        //    const array_type = @fieldParentPtr(ast.Node.ArrayType, "base", base);
        //    return renderArrayType(
        //        allocator,
        //        ais,
        //        tree,
        //        array_type.op_token,
        //        array_type.rhs,
        //        array_type.len_expr,
        //        null,
        //        space,
        //    );
        //},
        .ArrayTypeSentinel => unreachable, // TODO
        //.ArrayTypeSentinel => {
        //    const array_type = @fieldParentPtr(ast.Node.ArrayTypeSentinel, "base", base);
        //    return renderArrayType(
        //        allocator,
        //        ais,
        //        tree,
        //        array_type.op_token,
        //        array_type.rhs,
        //        array_type.len_expr,
        //        array_type.sentinel,
        //        space,
        //    );
        //},

        .PtrType => unreachable, // TODO
        .PtrTypeAligned => unreachable, // TODO
        .PtrTypeSentinel => unreachable, // TODO
        //.PtrType => {
        //    const ptr_type = @fieldParentPtr(ast.Node.PtrType, "base", base);
        //    const op_tok_id = tree.token_tags[ptr_type.op_token];
        //    switch (op_tok_id) {
        //        .Asterisk, .AsteriskAsterisk => try ais.writer().writeByte('*'),
        //        .LBracket => if (tree.token_tags[ptr_type.op_token + 2] == .Identifier)
        //            try ais.writer().writeAll("[*c")
        //        else
        //            try ais.writer().writeAll("[*"),
        //        else => unreachable,
        //    }
        //    if (ptr_type.ptr_info.sentinel) |sentinel| {
        //        const colon_token = tree.prevToken(sentinel.firstToken());
        //        try renderToken(ais, tree, colon_token, Space.None); // :
        //        const sentinel_space = switch (op_tok_id) {
        //            .LBracket => Space.None,
        //            else => Space.Space,
        //        };
        //        try renderExpression(ais, tree, sentinel, sentinel_space);
        //    }
        //    switch (op_tok_id) {
        //        .Asterisk, .AsteriskAsterisk => {},
        //        .LBracket => try ais.writer().writeByte(']'),
        //        else => unreachable,
        //    }
        //    if (ptr_type.ptr_info.allowzero_token) |allowzero_token| {
        //        try renderToken(ais, tree, allowzero_token, Space.Space); // allowzero
        //    }
        //    if (ptr_type.ptr_info.align_info) |align_info| {
        //        const lparen_token = tree.prevToken(align_info.node.firstToken());
        //        const align_token = tree.prevToken(lparen_token);

        //        try renderToken(ais, tree, align_token, Space.None); // align
        //        try renderToken(ais, tree, lparen_token, Space.None); // (

        //        try renderExpression(ais, tree, align_info.node, Space.None);

        //        if (align_info.bit_range) |bit_range| {
        //            const colon1 = tree.prevToken(bit_range.start.firstToken());
        //            const colon2 = tree.prevToken(bit_range.end.firstToken());

        //            try renderToken(ais, tree, colon1, Space.None); // :
        //            try renderExpression(ais, tree, bit_range.start, Space.None);
        //            try renderToken(ais, tree, colon2, Space.None); // :
        //            try renderExpression(ais, tree, bit_range.end, Space.None);

        //            const rparen_token = tree.nextToken(bit_range.end.lastToken());
        //            try renderToken(ais, tree, rparen_token, Space.Space); // )
        //        } else {
        //            const rparen_token = tree.nextToken(align_info.node.lastToken());
        //            try renderToken(ais, tree, rparen_token, Space.Space); // )
        //        }
        //    }
        //    if (ptr_type.ptr_info.const_token) |const_token| {
        //        try renderToken(ais, tree, const_token, Space.Space); // const
        //    }
        //    if (ptr_type.ptr_info.volatile_token) |volatile_token| {
        //        try renderToken(ais, tree, volatile_token, Space.Space); // volatile
        //    }
        //    return renderExpression(ais, tree, ptr_type.rhs, space);
        //},

        .SliceType => unreachable, // TODO
        //.SliceType => {
        //    const slice_type = @fieldParentPtr(ast.Node.SliceType, "base", base);
        //    try renderToken(ais, tree, slice_type.op_token, Space.None); // [
        //    if (slice_type.ptr_info.sentinel) |sentinel| {
        //        const colon_token = tree.prevToken(sentinel.firstToken());
        //        try renderToken(ais, tree, colon_token, Space.None); // :
        //        try renderExpression(ais, tree, sentinel, Space.None);
        //        try renderToken(ais, tree, tree.nextToken(sentinel.lastToken()), Space.None); // ]
        //    } else {
        //        try renderToken(ais, tree, tree.nextToken(slice_type.op_token), Space.None); // ]
        //    }

        //    if (slice_type.ptr_info.allowzero_token) |allowzero_token| {
        //        try renderToken(ais, tree, allowzero_token, Space.Space); // allowzero
        //    }
        //    if (slice_type.ptr_info.align_info) |align_info| {
        //        const lparen_token = tree.prevToken(align_info.node.firstToken());
        //        const align_token = tree.prevToken(lparen_token);

        //        try renderToken(ais, tree, align_token, Space.None); // align
        //        try renderToken(ais, tree, lparen_token, Space.None); // (

        //        try renderExpression(ais, tree, align_info.node, Space.None);

        //        if (align_info.bit_range) |bit_range| {
        //            const colon1 = tree.prevToken(bit_range.start.firstToken());
        //            const colon2 = tree.prevToken(bit_range.end.firstToken());

        //            try renderToken(ais, tree, colon1, Space.None); // :
        //            try renderExpression(ais, tree, bit_range.start, Space.None);
        //            try renderToken(ais, tree, colon2, Space.None); // :
        //            try renderExpression(ais, tree, bit_range.end, Space.None);

        //            const rparen_token = tree.nextToken(bit_range.end.lastToken());
        //            try renderToken(ais, tree, rparen_token, Space.Space); // )
        //        } else {
        //            const rparen_token = tree.nextToken(align_info.node.lastToken());
        //            try renderToken(ais, tree, rparen_token, Space.Space); // )
        //        }
        //    }
        //    if (slice_type.ptr_info.const_token) |const_token| {
        //        try renderToken(ais, tree, const_token, Space.Space);
        //    }
        //    if (slice_type.ptr_info.volatile_token) |volatile_token| {
        //        try renderToken(ais, tree, volatile_token, Space.Space);
        //    }
        //    return renderExpression(ais, tree, slice_type.rhs, space);
        //},

        .ArrayInitOne => unreachable, // TODO
        .ArrayInitDotTwo => unreachable, // TODO
        .ArrayInitDot => unreachable, // TODO
        .ArrayInit => unreachable, // TODO
        //.ArrayInitializer, .ArrayInitializerDot => {
        //    var rtoken: ast.TokenIndex = undefined;
        //    var exprs: []ast.Node.Index = undefined;
        //    const lhs: union(enum) { dot: ast.TokenIndex, node: ast.Node.Index } = switch (base.tag) {
        //        .ArrayInitializerDot => blk: {
        //            const casted = @fieldParentPtr(ast.Node.ArrayInitializerDot, "base", base);
        //            rtoken = casted.rtoken;
        //            exprs = casted.list();
        //            break :blk .{ .dot = casted.dot };
        //        },
        //        .ArrayInitializer => blk: {
        //            const casted = @fieldParentPtr(ast.Node.ArrayInitializer, "base", base);
        //            rtoken = casted.rtoken;
        //            exprs = casted.list();
        //            break :blk .{ .node = casted.lhs };
        //        },
        //        else => unreachable,
        //    };

        //    const lbrace = switch (lhs) {
        //        .dot => |dot| tree.nextToken(dot),
        //        .node => |node| tree.nextToken(node.lastToken()),
        //    };

        //    switch (lhs) {
        //        .dot => |dot| try renderToken(ais, tree, dot, Space.None),
        //        .node => |node| try renderExpression(ais, tree, node, Space.None),
        //    }

        //    if (exprs.len == 0) {
        //        try renderToken(ais, tree, lbrace, Space.None);
        //        return renderToken(ais, tree, rtoken, space);
        //    }

        //    if (exprs.len == 1 and exprs[0].tag != .MultilineStringLiteral and tree.token_tags[exprs[0].*.lastToken() + 1] == .RBrace) {
        //        const expr = exprs[0];

        //        try renderToken(ais, tree, lbrace, Space.None);
        //        try renderExpression(ais, tree, expr, Space.None);
        //        return renderToken(ais, tree, rtoken, space);
        //    }

        //    // scan to find row size
        //    if (rowSize(tree, exprs, rtoken) != null) {
        //        {
        //            ais.pushIndentNextLine();
        //            defer ais.popIndent();
        //            try renderToken(ais, tree, lbrace, Space.Newline);

        //            var expr_index: usize = 0;
        //            while (rowSize(tree, exprs[expr_index..], rtoken)) |row_size| {
        //                const row_exprs = exprs[expr_index..];
        //                // A place to store the width of each expression and its column's maximum
        //                var widths = try allocator.alloc(usize, row_exprs.len + row_size);
        //                defer allocator.free(widths);
        //                mem.set(usize, widths, 0);

        //                var expr_newlines = try allocator.alloc(bool, row_exprs.len);
        //                defer allocator.free(expr_newlines);
        //                mem.set(bool, expr_newlines, false);

        //                var expr_widths = widths[0 .. widths.len - row_size];
        //                var column_widths = widths[widths.len - row_size ..];

        //                // Find next row with trailing comment (if any) to end the current section
        //                var section_end = sec_end: {
        //                    var this_line_first_expr: usize = 0;
        //                    var this_line_size = rowSize(tree, row_exprs, rtoken);
        //                    for (row_exprs) |expr, i| {
        //                        // Ignore comment on first line of this section
        //                        if (i == 0 or tree.tokensOnSameLine(row_exprs[0].firstToken(), expr.lastToken())) continue;
        //                        // Track start of line containing comment
        //                        if (!tree.tokensOnSameLine(row_exprs[this_line_first_expr].firstToken(), expr.lastToken())) {
        //                            this_line_first_expr = i;
        //                            this_line_size = rowSize(tree, row_exprs[this_line_first_expr..], rtoken);
        //                        }

        //                        const maybe_comma = expr.lastToken() + 1;
        //                        const maybe_comment = expr.lastToken() + 2;
        //                        if (maybe_comment < tree.token_tags.len) {
        //                            if (tree.token_tags[maybe_comma] == .Comma and
        //                                tree.token_tags[maybe_comment] == .LineComment and
        //                                tree.tokensOnSameLine(expr.lastToken(), maybe_comment))
        //                            {
        //                                var comment_token_loc = tree.token_locs[maybe_comment];
        //                                const comment_is_empty = mem.trimRight(u8, tree.tokenSliceLoc(comment_token_loc), " ").len == 2;
        //                                if (!comment_is_empty) {
        //                                    // Found row ending in comment
        //                                    break :sec_end i - this_line_size.? + 1;
        //                                }
        //                            }
        //                        }
        //                    }
        //                    break :sec_end row_exprs.len;
        //                };
        //                expr_index += section_end;

        //                const section_exprs = row_exprs[0..section_end];

        //                // Null stream for counting the printed length of each expression
        //                var line_find_stream = std.io.findByteWriter('\n', std.io.null_writer);
        //                var counting_stream = std.io.countingWriter(line_find_stream.writer());
        //                var auto_indenting_stream = std.io.autoIndentingStream(indent_delta, counting_stream.writer());

        //                // Calculate size of columns in current section
        //                var column_counter: usize = 0;
        //                var single_line = true;
        //                for (section_exprs) |expr, i| {
        //                    if (i + 1 < section_exprs.len) {
        //                        counting_stream.bytes_written = 0;
        //                        line_find_stream.byte_found = false;
        //                        try renderExpression(allocator, &auto_indenting_stream, tree, expr, Space.None);
        //                        const width = @intCast(usize, counting_stream.bytes_written);
        //                        expr_widths[i] = width;
        //                        expr_newlines[i] = line_find_stream.byte_found;

        //                        if (!line_find_stream.byte_found) {
        //                            const column = column_counter % row_size;
        //                            column_widths[column] = std.math.max(column_widths[column], width);

        //                            const expr_last_token = expr.*.lastToken() + 1;
        //                            const next_expr = section_exprs[i + 1];
        //                            const loc = tree.tokenLocation(tree.token_locs[expr_last_token].start, next_expr.*.firstToken());

        //                            column_counter += 1;

        //                            if (loc.line != 0) single_line = false;
        //                        } else {
        //                            single_line = false;
        //                            column_counter = 0;
        //                        }
        //                    } else {
        //                        counting_stream.bytes_written = 0;
        //                        try renderExpression(allocator, &auto_indenting_stream, tree, expr, Space.None);
        //                        const width = @intCast(usize, counting_stream.bytes_written);
        //                        expr_widths[i] = width;
        //                        expr_newlines[i] = line_find_stream.byte_found;

        //                        if (!line_find_stream.byte_found) {
        //                            const column = column_counter % row_size;
        //                            column_widths[column] = std.math.max(column_widths[column], width);
        //                        }
        //                        break;
        //                    }
        //                }

        //                // Render exprs in current section
        //                column_counter = 0;
        //                var last_col_index: usize = row_size - 1;
        //                for (section_exprs) |expr, i| {
        //                    if (i + 1 < section_exprs.len) {
        //                        const next_expr = section_exprs[i + 1];
        //                        try renderExpression(ais, tree, expr, Space.None);

        //                        const comma = tree.nextToken(expr.*.lastToken());

        //                        if (column_counter != last_col_index) {
        //                            if (!expr_newlines[i] and !expr_newlines[i + 1]) {
        //                                // Neither the current or next expression is multiline
        //                                try renderToken(ais, tree, comma, Space.Space); // ,
        //                                assert(column_widths[column_counter % row_size] >= expr_widths[i]);
        //                                const padding = column_widths[column_counter % row_size] - expr_widths[i];
        //                                try ais.writer().writeByteNTimes(' ', padding);

        //                                column_counter += 1;
        //                                continue;
        //                            }
        //                        }
        //                        if (single_line and row_size != 1) {
        //                            try renderToken(ais, tree, comma, Space.Space); // ,
        //                            continue;
        //                        }

        //                        column_counter = 0;
        //                        try renderToken(ais, tree, comma, Space.Newline); // ,
        //                        try renderExtraNewline(ais, tree, next_expr);
        //                    } else {
        //                        const maybe_comma = tree.nextToken(expr.*.lastToken());
        //                        if (tree.token_tags[maybe_comma] == .Comma) {
        //                            try renderExpression(ais, tree, expr, Space.None); // ,
        //                            try renderToken(ais, tree, maybe_comma, Space.Newline); // ,
        //                        } else {
        //                            try renderExpression(ais, tree, expr, Space.Comma); // ,
        //                        }
        //                    }
        //                }

        //                if (expr_index == exprs.len) {
        //                    break;
        //                }
        //            }
        //        }

        //        return renderToken(ais, tree, rtoken, space);
        //    }

        //    // Single line
        //    try renderToken(ais, tree, lbrace, Space.Space);
        //    for (exprs) |expr, i| {
        //        if (i + 1 < exprs.len) {
        //            const next_expr = exprs[i + 1];
        //            try renderExpression(ais, tree, expr, Space.None);
        //            const comma = tree.nextToken(expr.*.lastToken());
        //            try renderToken(ais, tree, comma, Space.Space); // ,
        //        } else {
        //            try renderExpression(ais, tree, expr, Space.Space);
        //        }
        //    }

        //    return renderToken(ais, tree, rtoken, space);
        //},

        .StructInitOne => unreachable, // TODO
        .StructInitDotTwo => unreachable, // TODO
        .StructInitDot => unreachable, // TODO
        .StructInit => unreachable, // TODO
        //.StructInitializer, .StructInitializerDot => {
        //    var rtoken: ast.TokenIndex = undefined;
        //    var field_inits: []ast.Node.Index = undefined;
        //    const lhs: union(enum) { dot: ast.TokenIndex, node: ast.Node.Index } = switch (base.tag) {
        //        .StructInitializerDot => blk: {
        //            const casted = @fieldParentPtr(ast.Node.StructInitializerDot, "base", base);
        //            rtoken = casted.rtoken;
        //            field_inits = casted.list();
        //            break :blk .{ .dot = casted.dot };
        //        },
        //        .StructInitializer => blk: {
        //            const casted = @fieldParentPtr(ast.Node.StructInitializer, "base", base);
        //            rtoken = casted.rtoken;
        //            field_inits = casted.list();
        //            break :blk .{ .node = casted.lhs };
        //        },
        //        else => unreachable,
        //    };

        //    const lbrace = switch (lhs) {
        //        .dot => |dot| tree.nextToken(dot),
        //        .node => |node| tree.nextToken(node.lastToken()),
        //    };

        //    if (field_inits.len == 0) {
        //        switch (lhs) {
        //            .dot => |dot| try renderToken(ais, tree, dot, Space.None),
        //            .node => |node| try renderExpression(ais, tree, node, Space.None),
        //        }

        //        {
        //            ais.pushIndentNextLine();
        //            defer ais.popIndent();
        //            try renderToken(ais, tree, lbrace, Space.None);
        //        }

        //        return renderToken(ais, tree, rtoken, space);
        //    }

        //    const src_has_trailing_comma = blk: {
        //        const maybe_comma = tree.prevToken(rtoken);
        //        break :blk tree.token_tags[maybe_comma] == .Comma;
        //    };

        //    const src_same_line = blk: {
        //        const loc = tree.tokenLocation(tree.token_locs[lbrace].end, rtoken);
        //        break :blk loc.line == 0;
        //    };

        //    const expr_outputs_one_line = blk: {
        //        // render field expressions until a LF is found
        //        for (field_inits) |field_init| {
        //            var find_stream = std.io.findByteWriter('\n', std.io.null_writer);
        //            var auto_indenting_stream = std.io.autoIndentingStream(indent_delta, find_stream.writer());

        //            try renderExpression(allocator, &auto_indenting_stream, tree, field_init, Space.None);
        //            if (find_stream.byte_found) break :blk false;
        //        }
        //        break :blk true;
        //    };

        //    if (field_inits.len == 1) blk: {
        //        if (field_inits[0].cast(ast.Node.FieldInitializer)) |field_init| {
        //            switch (field_init.expr.tag) {
        //                .StructInitializer,
        //                .StructInitializerDot,
        //                => break :blk,
        //                else => {},
        //            }
        //        }

        //        // if the expression outputs to multiline, make this struct multiline
        //        if (!expr_outputs_one_line or src_has_trailing_comma) {
        //            break :blk;
        //        }

        //        switch (lhs) {
        //            .dot => |dot| try renderToken(ais, tree, dot, Space.None),
        //            .node => |node| try renderExpression(ais, tree, node, Space.None),
        //        }
        //        try renderToken(ais, tree, lbrace, Space.Space);
        //        try renderExpression(ais, tree, field_inits[0], Space.Space);
        //        return renderToken(ais, tree, rtoken, space);
        //    }

        //    if (!src_has_trailing_comma and src_same_line and expr_outputs_one_line) {
        //        // render all on one line, no trailing comma
        //        switch (lhs) {
        //            .dot => |dot| try renderToken(ais, tree, dot, Space.None),
        //            .node => |node| try renderExpression(ais, tree, node, Space.None),
        //        }
        //        try renderToken(ais, tree, lbrace, Space.Space);

        //        for (field_inits) |field_init, i| {
        //            if (i + 1 < field_inits.len) {
        //                try renderExpression(ais, tree, field_init, Space.None);

        //                const comma = tree.nextToken(field_init.lastToken());
        //                try renderToken(ais, tree, comma, Space.Space);
        //            } else {
        //                try renderExpression(ais, tree, field_init, Space.Space);
        //            }
        //        }

        //        return renderToken(ais, tree, rtoken, space);
        //    }

        //    {
        //        switch (lhs) {
        //            .dot => |dot| try renderToken(ais, tree, dot, Space.None),
        //            .node => |node| try renderExpression(ais, tree, node, Space.None),
        //        }

        //        ais.pushIndentNextLine();
        //        defer ais.popIndent();

        //        try renderToken(ais, tree, lbrace, Space.Newline);

        //        for (field_inits) |field_init, i| {
        //            if (i + 1 < field_inits.len) {
        //                const next_field_init = field_inits[i + 1];
        //                try renderExpression(ais, tree, field_init, Space.None);

        //                const comma = tree.nextToken(field_init.lastToken());
        //                try renderToken(ais, tree, comma, Space.Newline);

        //                try renderExtraNewline(ais, tree, next_field_init);
        //            } else {
        //                try renderExpression(ais, tree, field_init, Space.Comma);
        //            }
        //        }
        //    }

        //    return renderToken(ais, tree, rtoken, space);
        //},

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

        .Slice => unreachable, // TODO
        .SliceOpen => unreachable, // TODO
        //.Slice => {
        //    const suffix_op = base.castTag(.Slice).?;
        //    try renderExpression(ais, tree, suffix_op.lhs, Space.None);

        //    const lbracket = tree.prevToken(suffix_op.start.firstToken());
        //    const dotdot = tree.nextToken(suffix_op.start.lastToken());

        //    const after_start_space_bool = nodeCausesSliceOpSpace(suffix_op.start) or
        //        (if (suffix_op.end) |end| nodeCausesSliceOpSpace(end) else false);
        //    const after_start_space = if (after_start_space_bool) Space.Space else Space.None;
        //    const after_op_space = if (suffix_op.end != null) after_start_space else Space.None;

        //    try renderToken(ais, tree, lbracket, Space.None); // [
        //    try renderExpression(ais, tree, suffix_op.start, after_start_space);
        //    try renderToken(ais, tree, dotdot, after_op_space); // ..
        //    if (suffix_op.end) |end| {
        //        const after_end_space = if (suffix_op.sentinel != null) Space.Space else Space.None;
        //        try renderExpression(ais, tree, end, after_end_space);
        //    }
        //    if (suffix_op.sentinel) |sentinel| {
        //        const colon = tree.prevToken(sentinel.firstToken());
        //        try renderToken(ais, tree, colon, Space.None); // :
        //        try renderExpression(ais, tree, sentinel, Space.None);
        //    }
        //    return renderToken(ais, tree, suffix_op.rtoken, space); // ]
        //},

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

        .Return => unreachable, // TODO
        //.Return => {
        //    const flow_expr = base.castTag(.Return).?;
        //    if (flow_expr.getRHS()) |rhs| {
        //        try renderToken(ais, tree, flow_expr.ltoken, Space.Space);
        //        return renderExpression(ais, tree, rhs, space);
        //    } else {
        //        return renderToken(ais, tree, flow_expr.ltoken, space);
        //    }
        //},

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

        .ContainerDecl => unreachable, // TODO
        .ContainerDeclArg => unreachable, // TODO
        .TaggedUnion => unreachable, // TODO
        .TaggedUnionEnumTag => unreachable, // TODO
        //.ContainerDecl => {
        //    const container_decl = @fieldParentPtr(ast.Node.ContainerDecl, "base", base);

        //    if (container_decl.layout_token) |layout_token| {
        //        try renderToken(ais, tree, layout_token, Space.Space);
        //    }

        //    switch (container_decl.init_arg_expr) {
        //        .None => {
        //            try renderToken(ais, tree, container_decl.kind_token, Space.Space); // union
        //        },
        //        .Enum => |enum_tag_type| {
        //            try renderToken(ais, tree, container_decl.kind_token, Space.None); // union

        //            const lparen = tree.nextToken(container_decl.kind_token);
        //            const enum_token = tree.nextToken(lparen);

        //            try renderToken(ais, tree, lparen, Space.None); // (
        //            try renderToken(ais, tree, enum_token, Space.None); // enum

        //            if (enum_tag_type) |expr| {
        //                try renderToken(ais, tree, tree.nextToken(enum_token), Space.None); // (
        //                try renderExpression(ais, tree, expr, Space.None);

        //                const rparen = tree.nextToken(expr.lastToken());
        //                try renderToken(ais, tree, rparen, Space.None); // )
        //                try renderToken(ais, tree, tree.nextToken(rparen), Space.Space); // )
        //            } else {
        //                try renderToken(ais, tree, tree.nextToken(enum_token), Space.Space); // )
        //            }
        //        },
        //        .Type => |type_expr| {
        //            try renderToken(ais, tree, container_decl.kind_token, Space.None); // union

        //            const lparen = tree.nextToken(container_decl.kind_token);
        //            const rparen = tree.nextToken(type_expr.lastToken());

        //            try renderToken(ais, tree, lparen, Space.None); // (
        //            try renderExpression(ais, tree, type_expr, Space.None);
        //            try renderToken(ais, tree, rparen, Space.Space); // )
        //        },
        //    }

        //    if (container_decl.fields_and_decls_len == 0) {
        //        {
        //            ais.pushIndentNextLine();
        //            defer ais.popIndent();
        //            try renderToken(ais, tree, container_decl.lbrace_token, Space.None); // {
        //        }
        //        return renderToken(ais, tree, container_decl.rbrace_token, space); // }
        //    }

        //    const src_has_trailing_comma = blk: {
        //        var maybe_comma = tree.prevToken(container_decl.lastToken());
        //        // Doc comments for a field may also appear after the comma, eg.
        //        // field_name: T, // comment attached to field_name
        //        if (tree.token_tags[maybe_comma] == .DocComment)
        //            maybe_comma = tree.prevToken(maybe_comma);
        //        break :blk tree.token_tags[maybe_comma] == .Comma;
        //    };

        //    const fields_and_decls = container_decl.fieldsAndDecls();

        //    // Check if the first declaration and the { are on the same line
        //    const src_has_newline = !tree.tokensOnSameLine(
        //        container_decl.lbrace_token,
        //        fields_and_decls[0].firstToken(),
        //    );

        //    // We can only print all the elements in-line if all the
        //    // declarations inside are fields
        //    const src_has_only_fields = blk: {
        //        for (fields_and_decls) |decl| {
        //            if (decl.tag != .ContainerField) break :blk false;
        //        }
        //        break :blk true;
        //    };

        //    if (src_has_trailing_comma or !src_has_only_fields) {
        //        // One declaration per line
        //        ais.pushIndentNextLine();
        //        defer ais.popIndent();
        //        try renderToken(ais, tree, container_decl.lbrace_token, .Newline); // {

        //        for (fields_and_decls) |decl, i| {
        //            try renderContainerDecl(allocator, ais, tree, decl, .Newline);

        //            if (i + 1 < fields_and_decls.len) {
        //                try renderExtraNewline(ais, tree, fields_and_decls[i + 1]);
        //            }
        //        }
        //    } else if (src_has_newline) {
        //        // All the declarations on the same line, but place the items on
        //        // their own line
        //        try renderToken(ais, tree, container_decl.lbrace_token, .Newline); // {

        //        ais.pushIndent();
        //        defer ais.popIndent();

        //        for (fields_and_decls) |decl, i| {
        //            const space_after_decl: Space = if (i + 1 >= fields_and_decls.len) .Newline else .Space;
        //            try renderContainerDecl(allocator, ais, tree, decl, space_after_decl);
        //        }
        //    } else {
        //        // All the declarations on the same line
        //        try renderToken(ais, tree, container_decl.lbrace_token, .Space); // {

        //        for (fields_and_decls) |decl| {
        //            try renderContainerDecl(allocator, ais, tree, decl, .Space);
        //        }
        //    }

        //    return renderToken(ais, tree, container_decl.rbrace_token, space); // }
        //},

        .ErrorSetDecl => unreachable, // TODO
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
        //        try renderToken(ais, tree, lbrace, Space.None); // {
        //        try renderExpression(ais, tree, node, Space.None);
        //        return renderToken(ais, tree, err_set_decl.rbrace_token, space); // }
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

        //            try renderToken(ais, tree, lbrace, Space.Newline); // {
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

        //        return renderToken(ais, tree, err_set_decl.rbrace_token, space); // }
        //    } else {
        //        try renderToken(ais, tree, lbrace, Space.Space); // {

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

        //        return renderToken(ais, tree, err_set_decl.rbrace_token, space); // }
        //    }
        //},

        .BuiltinCallTwo => {
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
        .BuiltinCall => {
            const params = tree.extra_data[datas[node].lhs..datas[node].rhs];
            return renderBuiltinCall(ais, tree, main_tokens[node], params, space);
        },

        .FnProtoSimple => unreachable, // TODO
        .FnProtoSimpleMulti => unreachable, // TODO
        .FnProtoOne => unreachable, // TODO
        .FnProto => unreachable, // TODO
        //.FnProto => {
        //    const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", base);

        //    if (fn_proto.getVisibToken()) |visib_token_index| {
        //        const visib_token = tree.token_tags[visib_token_index];
        //        assert(visib_token == .Keyword_pub or visib_token == .Keyword_export);

        //        try renderToken(ais, tree, visib_token_index, Space.Space); // pub
        //    }

        //    if (fn_proto.getExternExportInlineToken()) |extern_export_inline_token| {
        //        if (fn_proto.getIsExternPrototype() == null)
        //            try renderToken(ais, tree, extern_export_inline_token, Space.Space); // extern/export/inline
        //    }

        //    if (fn_proto.getLibName()) |lib_name| {
        //        try renderExpression(ais, tree, lib_name, Space.Space);
        //    }

        //    const lparen = if (fn_proto.getNameToken()) |name_token| blk: {
        //        try renderToken(ais, tree, fn_proto.fn_token, Space.Space); // fn
        //        try renderToken(ais, tree, name_token, Space.None); // name
        //        break :blk tree.nextToken(name_token);
        //    } else blk: {
        //        try renderToken(ais, tree, fn_proto.fn_token, Space.Space); // fn
        //        break :blk tree.nextToken(fn_proto.fn_token);
        //    };
        //    assert(tree.token_tags[lparen] == .LParen);

        //    const rparen = tree.prevToken(
        //        // the first token for the annotation expressions is the left
        //        // parenthesis, hence the need for two prevToken
        //        if (fn_proto.getAlignExpr()) |align_expr|
        //            tree.prevToken(tree.prevToken(align_expr.firstToken()))
        //        else if (fn_proto.getSectionExpr()) |section_expr|
        //            tree.prevToken(tree.prevToken(section_expr.firstToken()))
        //        else if (fn_proto.getCallconvExpr()) |callconv_expr|
        //            tree.prevToken(tree.prevToken(callconv_expr.firstToken()))
        //        else switch (fn_proto.return_type) {
        //            .Explicit => |node| node.firstToken(),
        //            .InferErrorSet => |node| tree.prevToken(node.firstToken()),
        //            .Invalid => unreachable,
        //        },
        //    );
        //    assert(tree.token_tags[rparen] == .RParen);

        //    const src_params_trailing_comma = blk: {
        //        const maybe_comma = tree.token_tags[rparen - 1];
        //        break :blk maybe_comma == .Comma or maybe_comma == .LineComment;
        //    };

        //    if (!src_params_trailing_comma) {
        //        try renderToken(ais, tree, lparen, Space.None); // (

        //        // render all on one line, no trailing comma
        //        for (fn_proto.params()) |param_decl, i| {
        //            try renderParamDecl(allocator, ais, tree, param_decl, Space.None);

        //            if (i + 1 < fn_proto.params_len or fn_proto.getVarArgsToken() != null) {
        //                const comma = tree.nextToken(param_decl.lastToken());
        //                try renderToken(ais, tree, comma, Space.Space); // ,
        //            }
        //        }
        //        if (fn_proto.getVarArgsToken()) |var_args_token| {
        //            try renderToken(ais, tree, var_args_token, Space.None);
        //        }
        //    } else {
        //        // one param per line
        //        ais.pushIndent();
        //        defer ais.popIndent();
        //        try renderToken(ais, tree, lparen, Space.Newline); // (

        //        for (fn_proto.params()) |param_decl| {
        //            try renderParamDecl(allocator, ais, tree, param_decl, Space.Comma);
        //        }
        //        if (fn_proto.getVarArgsToken()) |var_args_token| {
        //            try renderToken(ais, tree, var_args_token, Space.Comma);
        //        }
        //    }

        //    try renderToken(ais, tree, rparen, Space.Space); // )

        //    if (fn_proto.getAlignExpr()) |align_expr| {
        //        const align_rparen = tree.nextToken(align_expr.lastToken());
        //        const align_lparen = tree.prevToken(align_expr.firstToken());
        //        const align_kw = tree.prevToken(align_lparen);

        //        try renderToken(ais, tree, align_kw, Space.None); // align
        //        try renderToken(ais, tree, align_lparen, Space.None); // (
        //        try renderExpression(ais, tree, align_expr, Space.None);
        //        try renderToken(ais, tree, align_rparen, Space.Space); // )
        //    }

        //    if (fn_proto.getSectionExpr()) |section_expr| {
        //        const section_rparen = tree.nextToken(section_expr.lastToken());
        //        const section_lparen = tree.prevToken(section_expr.firstToken());
        //        const section_kw = tree.prevToken(section_lparen);

        //        try renderToken(ais, tree, section_kw, Space.None); // section
        //        try renderToken(ais, tree, section_lparen, Space.None); // (
        //        try renderExpression(ais, tree, section_expr, Space.None);
        //        try renderToken(ais, tree, section_rparen, Space.Space); // )
        //    }

        //    if (fn_proto.getCallconvExpr()) |callconv_expr| {
        //        const callconv_rparen = tree.nextToken(callconv_expr.lastToken());
        //        const callconv_lparen = tree.prevToken(callconv_expr.firstToken());
        //        const callconv_kw = tree.prevToken(callconv_lparen);

        //        try renderToken(ais, tree, callconv_kw, Space.None); // callconv
        //        try renderToken(ais, tree, callconv_lparen, Space.None); // (
        //        try renderExpression(ais, tree, callconv_expr, Space.None);
        //        try renderToken(ais, tree, callconv_rparen, Space.Space); // )
        //    } else if (fn_proto.getIsExternPrototype() != null) {
        //        try ais.writer().writeAll("callconv(.C) ");
        //    } else if (fn_proto.getIsAsync() != null) {
        //        try ais.writer().writeAll("callconv(.Async) ");
        //    }

        //    switch (fn_proto.return_type) {
        //        .Explicit => |node| {
        //            return renderExpression(ais, tree, node, space);
        //        },
        //        .InferErrorSet => |node| {
        //            try renderToken(ais, tree, tree.prevToken(node.firstToken()), Space.None); // !
        //            return renderExpression(ais, tree, node, space);
        //        },
        //        .Invalid => unreachable,
        //    }
        //},

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
        //        try renderToken(ais, tree, lbrace, Space.None); // {
        //        return renderToken(ais, tree, switch_node.rbrace, space); // }
        //    }

        //    try renderExpression(ais, tree, switch_node.expr, Space.None);
        //    try renderToken(ais, tree, rparen, Space.Space); // )

        //    {
        //        ais.pushIndentNextLine();
        //        defer ais.popIndent();
        //        try renderToken(ais, tree, lbrace, Space.Newline); // {

        //        const cases = switch_node.cases();
        //        for (cases) |node, i| {
        //            try renderExpression(ais, tree, node, Space.Comma);

        //            if (i + 1 < cases.len) {
        //                try renderExtraNewline(ais, tree, cases[i + 1]);
        //            }
        //        }
        //    }

        //    return renderToken(ais, tree, switch_node.rbrace, space); // }
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
        //        after_body_space = if (while_node.@"else" == null) space else Space.SpaceOrOutdent;
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

        .EnumLiteral => unreachable, // TODO
        //.EnumLiteral => {
        //    const enum_literal = @fieldParentPtr(ast.Node.EnumLiteral, "base", base);

        //    try renderToken(ais, tree, enum_literal.dot, Space.None); // .
        //    return renderToken(ais, tree, enum_literal.name, space); // name
        //},

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

fn renderArrayType(
    allocator: *mem.Allocator,
    ais: *Ais,
    tree: ast.Tree,
    lbracket: ast.TokenIndex,
    rhs: ast.Node.Index,
    len_expr: ast.Node.Index,
    opt_sentinel: ?ast.Node.Index,
    space: Space,
) Error!void {
    const rbracket = tree.nextToken(if (opt_sentinel) |sentinel|
        sentinel.lastToken()
    else
        len_expr.lastToken());

    const starts_with_comment = tree.token_tags[lbracket + 1] == .LineComment;
    const ends_with_comment = tree.token_tags[rbracket - 1] == .LineComment;
    const new_space = if (ends_with_comment) Space.Newline else Space.None;
    {
        const do_indent = (starts_with_comment or ends_with_comment);
        if (do_indent) ais.pushIndent();
        defer if (do_indent) ais.popIndent();

        try renderToken(ais, tree, lbracket, Space.None); // [
        try renderExpression(ais, tree, len_expr, new_space);

        if (starts_with_comment) {
            try ais.maybeInsertNewline();
        }
        if (opt_sentinel) |sentinel| {
            const colon_token = tree.prevToken(sentinel.firstToken());
            try renderToken(ais, tree, colon_token, Space.None); // :
            try renderExpression(ais, tree, sentinel, Space.None);
        }
        if (starts_with_comment) {
            try ais.maybeInsertNewline();
        }
    }
    try renderToken(ais, tree, rbracket, Space.None); // ]

    return renderExpression(ais, tree, rhs, space);
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
    try renderExpression(ais, tree, var_decl.ast.init_node, Space.None);

    const semicolon = tree.lastToken(var_decl.ast.init_node) + 1;
    return renderToken(ais, tree, semicolon, Space.Newline);
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
                try renderExpression(ais, tree, if_node.ast.then_expr, Space.SpaceOrOutdent);
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

fn renderParamDecl(
    allocator: *mem.Allocator,
    ais: *Ais,
    tree: ast.Tree,
    param_decl: ast.Node.FnProto.ParamDecl,
    space: Space,
) Error!void {
    try renderDocComments(ais, tree, param_decl, param_decl.doc_comments);

    if (param_decl.comptime_token) |comptime_token| {
        try renderToken(ais, tree, comptime_token, Space.Space);
    }
    if (param_decl.noalias_token) |noalias_token| {
        try renderToken(ais, tree, noalias_token, Space.Space);
    }
    if (param_decl.name_token) |name_token| {
        try renderToken(ais, tree, name_token, Space.None);
        try renderToken(ais, tree, tree.nextToken(name_token), Space.Space); // :
    }
    switch (param_decl.param_type) {
        .any_type, .type_expr => |node| try renderExpression(ais, tree, node, space),
    }
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
    None,
    Newline,
    /// `renderToken` will additionally consume the next token if it is a comma.
    Comma,
    Space,
    SpaceOrOutdent,
    NoNewline,
    /// Skips writing the possible line comment after the token.
    NoComment,
    BlockStart,
};

fn renderToken(ais: *Ais, tree: ast.Tree, token_index: ast.TokenIndex, space: Space) Error!void {
    if (space == Space.BlockStart) {
        // If placing the lbrace on the current line would cause an ugly gap then put the lbrace on the next line.
        const new_space = if (ais.isLineOverIndented()) Space.Newline else Space.Space;
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
        .NoNewline => {},
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
        .SpaceOrOutdent => @panic("what does this even do"),
        .Space => {
            _ = try renderComments(ais, tree, token_start + lexeme.len, token_starts[token_index + 1], "");
            try ais.writer().writeByte(' ');
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

fn nodeCausesSliceOpSpace(base: ast.Node.Index) bool {
    return switch (base.tag) {
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
        .Range,
        .Sub,
        .SubWrap,
        .OrElse,
        => true,

        else => false,
    };
}

fn copyFixingWhitespace(ais: *Ais, slice: []const u8) @TypeOf(ais.*).Error!void {
    for (slice) |byte| switch (byte) {
        '\t' => try ais.writer().writeAll("    "),
        '\r' => {},
        else => try ais.writer().writeByte(byte),
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
