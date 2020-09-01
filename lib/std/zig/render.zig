// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
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
    /// Ran out of memory allocating call stack frames to complete rendering.
    OutOfMemory,
};

/// Returns whether anything changed
pub fn render(allocator: *mem.Allocator, stream: anytype, tree: *ast.Tree) (meta.Child(@TypeOf(stream)).Error || Error)!bool {
    // cannot render an invalid tree
    std.debug.assert(tree.errors.len == 0);

    var s = stream.*;
    var change_detection_stream = std.io.changeDetectionStream(tree.source, &s);
    var auto_indenting_stream = std.io.autoIndentingStream(indent_delta, &change_detection_stream);

    try renderRoot(allocator, &auto_indenting_stream, tree);

    return change_detection_stream.changeDetected();
}

fn renderRoot(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
) (@TypeOf(stream.*).Error || Error)!void {

    // render all the line comments at the beginning of the file
    for (tree.token_ids) |token_id, i| {
        if (token_id != .LineComment) break;
        const token_loc = tree.token_locs[i];
        try stream.writer().print("{}\n", .{mem.trimRight(u8, tree.tokenSliceLoc(token_loc), " ")});
        const next_token = tree.token_locs[i + 1];
        const loc = tree.tokenLocationLoc(token_loc.end, next_token);
        if (loc.line >= 2) {
            try stream.insertNewline();
        }
    }

    var decl_i: ast.NodeIndex = 0;
    const root_decls = tree.root_node.decls();

    if (root_decls.len == 0) return;
    while (true) {
        var decl = root_decls[decl_i];

        // This loop does the following:
        //
        //  - Iterates through line/doc comment tokens that precedes the current
        //    decl.
        //  - Figures out the first token index (`copy_start_token_index`) which
        //    hasn't been copied to the output stream yet.
        //  - Detects `zig fmt: (off|on)` in the line comment tokens, and
        //    determines whether the current decl should be reformatted or not.
        //
        var token_index = decl.firstToken();
        var fmt_active = true;
        var found_fmt_directive = false;

        var copy_start_token_index = token_index;

        while (token_index != 0) {
            token_index -= 1;
            const token_id = tree.token_ids[token_index];
            switch (token_id) {
                .LineComment => {},
                .DocComment => {
                    copy_start_token_index = token_index;
                    continue;
                },
                else => break,
            }

            const token_loc = tree.token_locs[token_index];
            if (mem.eql(u8, mem.trim(u8, tree.tokenSliceLoc(token_loc)[2..], " "), "zig fmt: off")) {
                if (!found_fmt_directive) {
                    fmt_active = false;
                    found_fmt_directive = true;
                }
            } else if (mem.eql(u8, mem.trim(u8, tree.tokenSliceLoc(token_loc)[2..], " "), "zig fmt: on")) {
                if (!found_fmt_directive) {
                    fmt_active = true;
                    found_fmt_directive = true;
                }
            }
        }

        if (!fmt_active) {
            // Reformatting is disabled for the current decl and possibly some
            // more decls that follow.
            // Find the next `decl` for which reformatting is re-enabled.
            token_index = decl.firstToken();

            while (!fmt_active) {
                decl_i += 1;
                if (decl_i >= root_decls.len) {
                    // If there's no next reformatted `decl`, just copy the
                    // remaining input tokens and bail out.
                    const start = tree.token_locs[copy_start_token_index].start;
                    try copyFixingWhitespace(stream, tree.source[start..]);
                    return;
                }
                decl = root_decls[decl_i];
                var decl_first_token_index = decl.firstToken();

                while (token_index < decl_first_token_index) : (token_index += 1) {
                    const token_id = tree.token_ids[token_index];
                    switch (token_id) {
                        .LineComment => {},
                        .Eof => unreachable,
                        else => continue,
                    }
                    const token_loc = tree.token_locs[token_index];
                    if (mem.eql(u8, mem.trim(u8, tree.tokenSliceLoc(token_loc)[2..], " "), "zig fmt: on")) {
                        fmt_active = true;
                    } else if (mem.eql(u8, mem.trim(u8, tree.tokenSliceLoc(token_loc)[2..], " "), "zig fmt: off")) {
                        fmt_active = false;
                    }
                }
            }

            // Found the next `decl` for which reformatting is enabled. Copy
            // the input tokens before the `decl` that haven't been copied yet.
            var copy_end_token_index = decl.firstToken();
            token_index = copy_end_token_index;
            while (token_index != 0) {
                token_index -= 1;
                const token_id = tree.token_ids[token_index];
                switch (token_id) {
                    .LineComment => {},
                    .DocComment => {
                        copy_end_token_index = token_index;
                        continue;
                    },
                    else => break,
                }
            }

            const start = tree.token_locs[copy_start_token_index].start;
            const end = tree.token_locs[copy_end_token_index].start;
            try copyFixingWhitespace(stream, tree.source[start..end]);
        }

        try renderTopLevelDecl(allocator, stream, tree, decl);
        decl_i += 1;
        if (decl_i >= root_decls.len) return;
        try renderExtraNewline(tree, stream, root_decls[decl_i]);
    }
}

fn renderExtraNewline(tree: *ast.Tree, stream: anytype, node: *ast.Node) @TypeOf(stream.*).Error!void {
    return renderExtraNewlineToken(tree, stream, node.firstToken());
}

fn renderExtraNewlineToken(
    tree: *ast.Tree,
    stream: anytype,
    first_token: ast.TokenIndex,
) @TypeOf(stream.*).Error!void {
    var prev_token = first_token;
    if (prev_token == 0) return;
    var newline_threshold: usize = 2;
    while (tree.token_ids[prev_token - 1] == .DocComment) {
        if (tree.tokenLocation(tree.token_locs[prev_token - 1].end, prev_token).line == 1) {
            newline_threshold += 1;
        }
        prev_token -= 1;
    }
    const prev_token_end = tree.token_locs[prev_token - 1].end;
    const loc = tree.tokenLocation(prev_token_end, first_token);
    if (loc.line >= newline_threshold) {
        try stream.insertNewline();
    }
}

fn renderTopLevelDecl(allocator: *mem.Allocator, stream: anytype, tree: *ast.Tree, decl: *ast.Node) (@TypeOf(stream.*).Error || Error)!void {
    try renderContainerDecl(allocator, stream, tree, decl, .Newline);
}

fn renderContainerDecl(allocator: *mem.Allocator, stream: anytype, tree: *ast.Tree, decl: *ast.Node, space: Space) (@TypeOf(stream.*).Error || Error)!void {
    switch (decl.tag) {
        .FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", decl);

            try renderDocComments(tree, stream, fn_proto, fn_proto.getDocComments());

            if (fn_proto.getBodyNode()) |body_node| {
                try renderExpression(allocator, stream, tree, decl, .Space);
                try renderExpression(allocator, stream, tree, body_node, space);
            } else {
                try renderExpression(allocator, stream, tree, decl, .None);
                try renderToken(tree, stream, tree.nextToken(decl.lastToken()), space);
            }
        },

        .Use => {
            const use_decl = @fieldParentPtr(ast.Node.Use, "base", decl);

            if (use_decl.visib_token) |visib_token| {
                try renderToken(tree, stream, visib_token, .Space); // pub
            }
            try renderToken(tree, stream, use_decl.use_token, .Space); // usingnamespace
            try renderExpression(allocator, stream, tree, use_decl.expr, .None);
            try renderToken(tree, stream, use_decl.semicolon_token, space); // ;
        },

        .VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", decl);

            try renderDocComments(tree, stream, var_decl, var_decl.getDocComments());
            try renderVarDecl(allocator, stream, tree, var_decl);
        },

        .TestDecl => {
            const test_decl = @fieldParentPtr(ast.Node.TestDecl, "base", decl);

            try renderDocComments(tree, stream, test_decl, test_decl.doc_comments);
            try renderToken(tree, stream, test_decl.test_token, .Space);
            try renderExpression(allocator, stream, tree, test_decl.name, .Space);
            try renderExpression(allocator, stream, tree, test_decl.body_node, space);
        },

        .ContainerField => {
            const field = @fieldParentPtr(ast.Node.ContainerField, "base", decl);

            try renderDocComments(tree, stream, field, field.doc_comments);
            if (field.comptime_token) |t| {
                try renderToken(tree, stream, t, .Space); // comptime
            }

            const src_has_trailing_comma = blk: {
                const maybe_comma = tree.nextToken(field.lastToken());
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            // The trailing comma is emitted at the end, but if it's not present
            // we still have to respect the specified `space` parameter
            const last_token_space: Space = if (src_has_trailing_comma) .None else space;

            if (field.type_expr == null and field.value_expr == null) {
                try renderToken(tree, stream, field.name_token, last_token_space); // name
            } else if (field.type_expr != null and field.value_expr == null) {
                try renderToken(tree, stream, field.name_token, .None); // name
                try renderToken(tree, stream, tree.nextToken(field.name_token), .Space); // :

                if (field.align_expr) |align_value_expr| {
                    try renderExpression(allocator, stream, tree, field.type_expr.?, .Space); // type
                    const lparen_token = tree.prevToken(align_value_expr.firstToken());
                    const align_kw = tree.prevToken(lparen_token);
                    const rparen_token = tree.nextToken(align_value_expr.lastToken());
                    try renderToken(tree, stream, align_kw, .None); // align
                    try renderToken(tree, stream, lparen_token, .None); // (
                    try renderExpression(allocator, stream, tree, align_value_expr, .None); // alignment
                    try renderToken(tree, stream, rparen_token, last_token_space); // )
                } else {
                    try renderExpression(allocator, stream, tree, field.type_expr.?, last_token_space); // type
                }
            } else if (field.type_expr == null and field.value_expr != null) {
                try renderToken(tree, stream, field.name_token, .Space); // name
                try renderToken(tree, stream, tree.nextToken(field.name_token), .Space); // =
                try renderExpression(allocator, stream, tree, field.value_expr.?, last_token_space); // value
            } else {
                try renderToken(tree, stream, field.name_token, .None); // name
                try renderToken(tree, stream, tree.nextToken(field.name_token), .Space); // :

                if (field.align_expr) |align_value_expr| {
                    try renderExpression(allocator, stream, tree, field.type_expr.?, .Space); // type
                    const lparen_token = tree.prevToken(align_value_expr.firstToken());
                    const align_kw = tree.prevToken(lparen_token);
                    const rparen_token = tree.nextToken(align_value_expr.lastToken());
                    try renderToken(tree, stream, align_kw, .None); // align
                    try renderToken(tree, stream, lparen_token, .None); // (
                    try renderExpression(allocator, stream, tree, align_value_expr, .None); // alignment
                    try renderToken(tree, stream, rparen_token, .Space); // )
                } else {
                    try renderExpression(allocator, stream, tree, field.type_expr.?, .Space); // type
                }
                try renderToken(tree, stream, tree.prevToken(field.value_expr.?.firstToken()), .Space); // =
                try renderExpression(allocator, stream, tree, field.value_expr.?, last_token_space); // value
            }

            if (src_has_trailing_comma) {
                const comma = tree.nextToken(field.lastToken());
                try renderToken(tree, stream, comma, space);
            }
        },

        .Comptime => {
            assert(!decl.requireSemiColon());
            try renderExpression(allocator, stream, tree, decl, space);
        },

        .DocComment => {
            const comment = @fieldParentPtr(ast.Node.DocComment, "base", decl);
            const kind = tree.token_ids[comment.first_line];
            try renderToken(tree, stream, comment.first_line, .Newline);
            var tok_i = comment.first_line + 1;
            while (true) : (tok_i += 1) {
                const tok_id = tree.token_ids[tok_i];
                if (tok_id == kind) {
                    try renderToken(tree, stream, tok_i, .Newline);
                } else if (tok_id == .LineComment) {
                    continue;
                } else {
                    break;
                }
            }
        },
        else => unreachable,
    }
}

fn renderExpression(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    base: *ast.Node,
    space: Space,
) (@TypeOf(stream.*).Error || Error)!void {
    switch (base.tag) {
        .Identifier,
        .IntegerLiteral,
        .FloatLiteral,
        .StringLiteral,
        .CharLiteral,
        .BoolLiteral,
        .NullLiteral,
        .Unreachable,
        .ErrorType,
        .UndefinedLiteral,
        => {
            const casted_node = base.cast(ast.Node.OneToken).?;
            return renderToken(tree, stream, casted_node.token, space);
        },

        .AnyType => {
            const any_type = base.castTag(.AnyType).?;
            if (mem.eql(u8, tree.tokenSlice(any_type.token), "var")) {
                // TODO remove in next release cycle
                try stream.writer().writeAll("anytype");
                if (space == .Comma) try stream.writer().writeAll(",\n");
                return;
            }
            return renderToken(tree, stream, any_type.token, space);
        },

        .Block, .LabeledBlock => {
            const block: struct {
                label: ?ast.TokenIndex,
                statements: []*ast.Node,
                lbrace: ast.TokenIndex,
                rbrace: ast.TokenIndex,
            } = b: {
                if (base.castTag(.Block)) |block| {
                    break :b .{
                        .label = null,
                        .statements = block.statements(),
                        .lbrace = block.lbrace,
                        .rbrace = block.rbrace,
                    };
                } else if (base.castTag(.LabeledBlock)) |block| {
                    break :b .{
                        .label = block.label,
                        .statements = block.statements(),
                        .lbrace = block.lbrace,
                        .rbrace = block.rbrace,
                    };
                } else {
                    unreachable;
                }
            };

            if (block.label) |label| {
                try renderToken(tree, stream, label, Space.None);
                try renderToken(tree, stream, tree.nextToken(label), Space.Space);
            }

            if (block.statements.len == 0) {
                stream.pushIndentNextLine();
                defer stream.popIndent();
                try renderToken(tree, stream, block.lbrace, Space.None);
            } else {
                stream.pushIndentNextLine();
                defer stream.popIndent();

                try renderToken(tree, stream, block.lbrace, Space.Newline);

                for (block.statements) |statement, i| {
                    try renderStatement(allocator, stream, tree, statement);

                    if (i + 1 < block.statements.len) {
                        try renderExtraNewline(tree, stream, block.statements[i + 1]);
                    }
                }
            }
            return renderToken(tree, stream, block.rbrace, space);
        },

        .Defer => {
            const defer_node = @fieldParentPtr(ast.Node.Defer, "base", base);

            try renderToken(tree, stream, defer_node.defer_token, Space.Space);
            if (defer_node.payload) |payload| {
                try renderExpression(allocator, stream, tree, payload, Space.Space);
            }
            return renderExpression(allocator, stream, tree, defer_node.expr, space);
        },
        .Comptime => {
            const comptime_node = @fieldParentPtr(ast.Node.Comptime, "base", base);

            try renderToken(tree, stream, comptime_node.comptime_token, Space.Space);
            return renderExpression(allocator, stream, tree, comptime_node.expr, space);
        },
        .Nosuspend => {
            const nosuspend_node = @fieldParentPtr(ast.Node.Nosuspend, "base", base);
            if (mem.eql(u8, tree.tokenSlice(nosuspend_node.nosuspend_token), "noasync")) {
                // TODO: remove this
                try stream.writer().writeAll("nosuspend ");
            } else {
                try renderToken(tree, stream, nosuspend_node.nosuspend_token, Space.Space);
            }
            return renderExpression(allocator, stream, tree, nosuspend_node.expr, space);
        },

        .Suspend => {
            const suspend_node = @fieldParentPtr(ast.Node.Suspend, "base", base);

            if (suspend_node.body) |body| {
                try renderToken(tree, stream, suspend_node.suspend_token, Space.Space);
                return renderExpression(allocator, stream, tree, body, space);
            } else {
                return renderToken(tree, stream, suspend_node.suspend_token, space);
            }
        },

        .Catch => {
            const infix_op_node = @fieldParentPtr(ast.Node.Catch, "base", base);

            const op_space = Space.Space;
            try renderExpression(allocator, stream, tree, infix_op_node.lhs, op_space);

            const after_op_space = blk: {
                const same_line = tree.tokensOnSameLine(infix_op_node.op_token, tree.nextToken(infix_op_node.op_token));
                break :blk if (same_line) op_space else Space.Newline;
            };

            try renderToken(tree, stream, infix_op_node.op_token, after_op_space);

            if (infix_op_node.payload) |payload| {
                try renderExpression(allocator, stream, tree, payload, Space.Space);
            }

            stream.pushIndentOneShot();
            return renderExpression(allocator, stream, tree, infix_op_node.rhs, space);
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
        .OrElse,
        => {
            const infix_op_node = @fieldParentPtr(ast.Node.SimpleInfixOp, "base", base);

            const op_space = switch (base.tag) {
                .Period, .ErrorUnion, .Range => Space.None,
                else => Space.Space,
            };
            try renderExpression(allocator, stream, tree, infix_op_node.lhs, op_space);

            const after_op_space = blk: {
                const loc = tree.tokenLocation(tree.token_locs[infix_op_node.op_token].end, tree.nextToken(infix_op_node.op_token));
                break :blk if (loc.line == 0) op_space else Space.Newline;
            };

            try renderToken(tree, stream, infix_op_node.op_token, after_op_space);
            stream.pushIndentOneShot();
            return renderExpression(allocator, stream, tree, infix_op_node.rhs, space);
        },

        .BitNot,
        .BoolNot,
        .Negation,
        .NegationWrap,
        .OptionalType,
        .AddressOf,
        => {
            const casted_node = @fieldParentPtr(ast.Node.SimplePrefixOp, "base", base);
            try renderToken(tree, stream, casted_node.op_token, Space.None);
            return renderExpression(allocator, stream, tree, casted_node.rhs, space);
        },

        .Try,
        .Resume,
        .Await,
        => {
            const casted_node = @fieldParentPtr(ast.Node.SimplePrefixOp, "base", base);
            try renderToken(tree, stream, casted_node.op_token, Space.Space);
            return renderExpression(allocator, stream, tree, casted_node.rhs, space);
        },

        .ArrayType => {
            const array_type = @fieldParentPtr(ast.Node.ArrayType, "base", base);
            return renderArrayType(
                allocator,
                stream,
                tree,
                array_type.op_token,
                array_type.rhs,
                array_type.len_expr,
                null,
                space,
            );
        },
        .ArrayTypeSentinel => {
            const array_type = @fieldParentPtr(ast.Node.ArrayTypeSentinel, "base", base);
            return renderArrayType(
                allocator,
                stream,
                tree,
                array_type.op_token,
                array_type.rhs,
                array_type.len_expr,
                array_type.sentinel,
                space,
            );
        },

        .PtrType => {
            const ptr_type = @fieldParentPtr(ast.Node.PtrType, "base", base);
            const op_tok_id = tree.token_ids[ptr_type.op_token];
            switch (op_tok_id) {
                .Asterisk, .AsteriskAsterisk => try stream.writer().writeByte('*'),
                .LBracket => if (tree.token_ids[ptr_type.op_token + 2] == .Identifier)
                    try stream.writer().writeAll("[*c")
                else
                    try stream.writer().writeAll("[*"),
                else => unreachable,
            }
            if (ptr_type.ptr_info.sentinel) |sentinel| {
                const colon_token = tree.prevToken(sentinel.firstToken());
                try renderToken(tree, stream, colon_token, Space.None); // :
                const sentinel_space = switch (op_tok_id) {
                    .LBracket => Space.None,
                    else => Space.Space,
                };
                try renderExpression(allocator, stream, tree, sentinel, sentinel_space);
            }
            switch (op_tok_id) {
                .Asterisk, .AsteriskAsterisk => {},
                .LBracket => try stream.writer().writeByte(']'),
                else => unreachable,
            }
            if (ptr_type.ptr_info.allowzero_token) |allowzero_token| {
                try renderToken(tree, stream, allowzero_token, Space.Space); // allowzero
            }
            if (ptr_type.ptr_info.align_info) |align_info| {
                const lparen_token = tree.prevToken(align_info.node.firstToken());
                const align_token = tree.prevToken(lparen_token);

                try renderToken(tree, stream, align_token, Space.None); // align
                try renderToken(tree, stream, lparen_token, Space.None); // (

                try renderExpression(allocator, stream, tree, align_info.node, Space.None);

                if (align_info.bit_range) |bit_range| {
                    const colon1 = tree.prevToken(bit_range.start.firstToken());
                    const colon2 = tree.prevToken(bit_range.end.firstToken());

                    try renderToken(tree, stream, colon1, Space.None); // :
                    try renderExpression(allocator, stream, tree, bit_range.start, Space.None);
                    try renderToken(tree, stream, colon2, Space.None); // :
                    try renderExpression(allocator, stream, tree, bit_range.end, Space.None);

                    const rparen_token = tree.nextToken(bit_range.end.lastToken());
                    try renderToken(tree, stream, rparen_token, Space.Space); // )
                } else {
                    const rparen_token = tree.nextToken(align_info.node.lastToken());
                    try renderToken(tree, stream, rparen_token, Space.Space); // )
                }
            }
            if (ptr_type.ptr_info.const_token) |const_token| {
                try renderToken(tree, stream, const_token, Space.Space); // const
            }
            if (ptr_type.ptr_info.volatile_token) |volatile_token| {
                try renderToken(tree, stream, volatile_token, Space.Space); // volatile
            }
            return renderExpression(allocator, stream, tree, ptr_type.rhs, space);
        },

        .SliceType => {
            const slice_type = @fieldParentPtr(ast.Node.SliceType, "base", base);
            try renderToken(tree, stream, slice_type.op_token, Space.None); // [
            if (slice_type.ptr_info.sentinel) |sentinel| {
                const colon_token = tree.prevToken(sentinel.firstToken());
                try renderToken(tree, stream, colon_token, Space.None); // :
                try renderExpression(allocator, stream, tree, sentinel, Space.None);
                try renderToken(tree, stream, tree.nextToken(sentinel.lastToken()), Space.None); // ]
            } else {
                try renderToken(tree, stream, tree.nextToken(slice_type.op_token), Space.None); // ]
            }

            if (slice_type.ptr_info.allowzero_token) |allowzero_token| {
                try renderToken(tree, stream, allowzero_token, Space.Space); // allowzero
            }
            if (slice_type.ptr_info.align_info) |align_info| {
                const lparen_token = tree.prevToken(align_info.node.firstToken());
                const align_token = tree.prevToken(lparen_token);

                try renderToken(tree, stream, align_token, Space.None); // align
                try renderToken(tree, stream, lparen_token, Space.None); // (

                try renderExpression(allocator, stream, tree, align_info.node, Space.None);

                if (align_info.bit_range) |bit_range| {
                    const colon1 = tree.prevToken(bit_range.start.firstToken());
                    const colon2 = tree.prevToken(bit_range.end.firstToken());

                    try renderToken(tree, stream, colon1, Space.None); // :
                    try renderExpression(allocator, stream, tree, bit_range.start, Space.None);
                    try renderToken(tree, stream, colon2, Space.None); // :
                    try renderExpression(allocator, stream, tree, bit_range.end, Space.None);

                    const rparen_token = tree.nextToken(bit_range.end.lastToken());
                    try renderToken(tree, stream, rparen_token, Space.Space); // )
                } else {
                    const rparen_token = tree.nextToken(align_info.node.lastToken());
                    try renderToken(tree, stream, rparen_token, Space.Space); // )
                }
            }
            if (slice_type.ptr_info.const_token) |const_token| {
                try renderToken(tree, stream, const_token, Space.Space);
            }
            if (slice_type.ptr_info.volatile_token) |volatile_token| {
                try renderToken(tree, stream, volatile_token, Space.Space);
            }
            return renderExpression(allocator, stream, tree, slice_type.rhs, space);
        },

        .ArrayInitializer, .ArrayInitializerDot => {
            var rtoken: ast.TokenIndex = undefined;
            var exprs: []*ast.Node = undefined;
            const lhs: union(enum) { dot: ast.TokenIndex, node: *ast.Node } = switch (base.tag) {
                .ArrayInitializerDot => blk: {
                    const casted = @fieldParentPtr(ast.Node.ArrayInitializerDot, "base", base);
                    rtoken = casted.rtoken;
                    exprs = casted.list();
                    break :blk .{ .dot = casted.dot };
                },
                .ArrayInitializer => blk: {
                    const casted = @fieldParentPtr(ast.Node.ArrayInitializer, "base", base);
                    rtoken = casted.rtoken;
                    exprs = casted.list();
                    break :blk .{ .node = casted.lhs };
                },
                else => unreachable,
            };

            const lbrace = switch (lhs) {
                .dot => |dot| tree.nextToken(dot),
                .node => |node| tree.nextToken(node.lastToken()),
            };

            if (exprs.len == 0) {
                switch (lhs) {
                    .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                    .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
                }

                {
                    stream.pushIndent();
                    defer stream.popIndent();
                    try renderToken(tree, stream, lbrace, Space.None);
                }

                return renderToken(tree, stream, rtoken, space);
            }
            if (exprs.len == 1 and tree.token_ids[exprs[0].*.lastToken() + 1] == .RBrace) {
                const expr = exprs[0];

                switch (lhs) {
                    .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                    .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
                }
                try renderToken(tree, stream, lbrace, Space.None);
                try renderExpression(allocator, stream, tree, expr, Space.None);
                return renderToken(tree, stream, rtoken, space);
            }

            switch (lhs) {
                .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
            }

            // scan to find row size
            const maybe_row_size: ?usize = blk: {
                var count: usize = 1;
                for (exprs) |expr, i| {
                    if (i + 1 < exprs.len) {
                        const expr_last_token = expr.lastToken() + 1;
                        const loc = tree.tokenLocation(tree.token_locs[expr_last_token].end, exprs[i + 1].firstToken());
                        if (loc.line != 0) break :blk count;
                        count += 1;
                    } else {
                        const expr_last_token = expr.lastToken();
                        const loc = tree.tokenLocation(tree.token_locs[expr_last_token].end, rtoken);
                        if (loc.line == 0) {
                            // all on one line
                            const src_has_trailing_comma = trailblk: {
                                const maybe_comma = tree.prevToken(rtoken);
                                break :trailblk tree.token_ids[maybe_comma] == .Comma;
                            };
                            if (src_has_trailing_comma) {
                                break :blk 1; // force row size 1
                            } else {
                                break :blk null; // no newlines
                            }
                        }
                        break :blk count;
                    }
                }
                unreachable;
            };

            if (maybe_row_size) |row_size| {
                // A place to store the width of each expression and its column's maximum
                var widths = try allocator.alloc(usize, exprs.len + row_size);
                defer allocator.free(widths);
                mem.set(usize, widths, 0);

                var expr_widths = widths[0 .. widths.len - row_size];
                var column_widths = widths[widths.len - row_size ..];

                // Null stream for counting the printed length of each expression
                var counting_stream = std.io.countingOutStream(std.io.null_out_stream);
                var auto_indenting_stream = std.io.autoIndentingStream(indent_delta, &counting_stream);

                for (exprs) |expr, i| {
                    counting_stream.bytes_written = 0;
                    try renderExpression(allocator, &auto_indenting_stream, tree, expr, Space.None);
                    const width = @intCast(usize, counting_stream.bytes_written);
                    const col = i % row_size;
                    column_widths[col] = std.math.max(column_widths[col], width);
                    expr_widths[i] = width;
                }

                {
                    stream.pushIndentNextLine();
                    defer stream.popIndent();
                    try renderToken(tree, stream, lbrace, Space.Newline);

                    var col: usize = 1;
                    for (exprs) |expr, i| {
                        if (i + 1 < exprs.len) {
                            const next_expr = exprs[i + 1];
                            try renderExpression(allocator, stream, tree, expr, Space.None);

                            const comma = tree.nextToken(expr.*.lastToken());

                            if (col != row_size) {
                                try renderToken(tree, stream, comma, Space.Space); // ,

                                const padding = column_widths[i % row_size] - expr_widths[i];
                                try stream.writer().writeByteNTimes(' ', padding);

                                col += 1;
                                continue;
                            }
                            col = 1;

                            if (tree.token_ids[tree.nextToken(comma)] != .MultilineStringLiteralLine) {
                                try renderToken(tree, stream, comma, Space.Newline); // ,
                            } else {
                                try renderToken(tree, stream, comma, Space.None); // ,
                            }

                            try renderExtraNewline(tree, stream, next_expr);
                        } else {
                            try renderExpression(allocator, stream, tree, expr, Space.Comma); // ,
                        }
                    }
                }
                return renderToken(tree, stream, rtoken, space);
            } else {
                try renderToken(tree, stream, lbrace, Space.Space);
                for (exprs) |expr, i| {
                    if (i + 1 < exprs.len) {
                        const next_expr = exprs[i + 1];
                        try renderExpression(allocator, stream, tree, expr, Space.None);
                        const comma = tree.nextToken(expr.*.lastToken());
                        try renderToken(tree, stream, comma, Space.Space); // ,
                    } else {
                        try renderExpression(allocator, stream, tree, expr, Space.Space);
                    }
                }

                return renderToken(tree, stream, rtoken, space);
            }
        },

        .StructInitializer, .StructInitializerDot => {
            var rtoken: ast.TokenIndex = undefined;
            var field_inits: []*ast.Node = undefined;
            const lhs: union(enum) { dot: ast.TokenIndex, node: *ast.Node } = switch (base.tag) {
                .StructInitializerDot => blk: {
                    const casted = @fieldParentPtr(ast.Node.StructInitializerDot, "base", base);
                    rtoken = casted.rtoken;
                    field_inits = casted.list();
                    break :blk .{ .dot = casted.dot };
                },
                .StructInitializer => blk: {
                    const casted = @fieldParentPtr(ast.Node.StructInitializer, "base", base);
                    rtoken = casted.rtoken;
                    field_inits = casted.list();
                    break :blk .{ .node = casted.lhs };
                },
                else => unreachable,
            };

            const lbrace = switch (lhs) {
                .dot => |dot| tree.nextToken(dot),
                .node => |node| tree.nextToken(node.lastToken()),
            };

            if (field_inits.len == 0) {
                switch (lhs) {
                    .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                    .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
                }

                {
                    stream.pushIndentNextLine();
                    defer stream.popIndent();
                    try renderToken(tree, stream, lbrace, Space.None);
                }

                return renderToken(tree, stream, rtoken, space);
            }

            const src_has_trailing_comma = blk: {
                const maybe_comma = tree.prevToken(rtoken);
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            const src_same_line = blk: {
                const loc = tree.tokenLocation(tree.token_locs[lbrace].end, rtoken);
                break :blk loc.line == 0;
            };

            const expr_outputs_one_line = blk: {
                // render field expressions until a LF is found
                for (field_inits) |field_init| {
                    var find_stream = std.io.findByteOutStream('\n', &std.io.null_out_stream);
                    var auto_indenting_stream = std.io.autoIndentingStream(indent_delta, &find_stream);

                    try renderExpression(allocator, &auto_indenting_stream, tree, field_init, Space.None);
                    if (find_stream.byte_found) break :blk false;
                }
                break :blk true;
            };

            if (field_inits.len == 1) blk: {
                const field_init = field_inits[0].cast(ast.Node.FieldInitializer).?;

                switch (field_init.expr.tag) {
                    .StructInitializer,
                    .StructInitializerDot,
                    => break :blk,
                    else => {},
                }

                // if the expression outputs to multiline, make this struct multiline
                if (!expr_outputs_one_line or src_has_trailing_comma) {
                    break :blk;
                }

                switch (lhs) {
                    .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                    .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
                }
                try renderToken(tree, stream, lbrace, Space.Space);
                try renderExpression(allocator, stream, tree, &field_init.base, Space.Space);
                return renderToken(tree, stream, rtoken, space);
            }

            if (!src_has_trailing_comma and src_same_line and expr_outputs_one_line) {
                // render all on one line, no trailing comma
                switch (lhs) {
                    .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                    .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
                }
                try renderToken(tree, stream, lbrace, Space.Space);

                for (field_inits) |field_init, i| {
                    if (i + 1 < field_inits.len) {
                        try renderExpression(allocator, stream, tree, field_init, Space.None);

                        const comma = tree.nextToken(field_init.lastToken());
                        try renderToken(tree, stream, comma, Space.Space);
                    } else {
                        try renderExpression(allocator, stream, tree, field_init, Space.Space);
                    }
                }

                return renderToken(tree, stream, rtoken, space);
            }

            {
                switch (lhs) {
                    .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                    .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
                }

                stream.pushIndentNextLine();
                defer stream.popIndent();

                try renderToken(tree, stream, lbrace, Space.Newline);

                for (field_inits) |field_init, i| {
                    if (i + 1 < field_inits.len) {
                        const next_field_init = field_inits[i + 1];
                        try renderExpression(allocator, stream, tree, field_init, Space.None);

                        const comma = tree.nextToken(field_init.lastToken());
                        try renderToken(tree, stream, comma, Space.Newline);

                        try renderExtraNewline(tree, stream, next_field_init);
                    } else {
                        try renderExpression(allocator, stream, tree, field_init, Space.Comma);
                    }
                }
            }

            return renderToken(tree, stream, rtoken, space);
        },

        .Call => {
            const call = @fieldParentPtr(ast.Node.Call, "base", base);
            if (call.async_token) |async_token| {
                try renderToken(tree, stream, async_token, Space.Space);
            }

            try renderExpression(allocator, stream, tree, call.lhs, Space.None);

            const lparen = tree.nextToken(call.lhs.lastToken());

            if (call.params_len == 0) {
                try renderToken(tree, stream, lparen, Space.None);
                return renderToken(tree, stream, call.rtoken, space);
            }

            const src_has_trailing_comma = blk: {
                const maybe_comma = tree.prevToken(call.rtoken);
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            if (src_has_trailing_comma) {
                try renderToken(tree, stream, lparen, Space.Newline);

                const params = call.params();
                for (params) |param_node, i| {
                    stream.pushIndent();
                    defer stream.popIndent();

                    if (i + 1 < params.len) {
                        const next_node = params[i + 1];
                        try renderExpression(allocator, stream, tree, param_node, Space.None);
                        const comma = tree.nextToken(param_node.lastToken());
                        try renderToken(tree, stream, comma, Space.Newline); // ,
                        try renderExtraNewline(tree, stream, next_node);
                    } else {
                        try renderExpression(allocator, stream, tree, param_node, Space.Comma);
                    }
                }
                return renderToken(tree, stream, call.rtoken, space);
            }

            try renderToken(tree, stream, lparen, Space.None); // (

            const params = call.params();
            for (params) |param_node, i| {
                if (param_node.*.tag == .MultilineStringLiteral) stream.pushIndentOneShot();

                try renderExpression(allocator, stream, tree, param_node, Space.None);

                if (i + 1 < params.len) {
                    const next_param = params[i + 1];
                    const comma = tree.nextToken(param_node.lastToken());
                    try renderToken(tree, stream, comma, Space.Space);
                }
            }
            return renderToken(tree, stream, call.rtoken, space);
        },

        .ArrayAccess => {
            const suffix_op = base.castTag(.ArrayAccess).?;

            const lbracket = tree.nextToken(suffix_op.lhs.lastToken());
            const rbracket = tree.nextToken(suffix_op.index_expr.lastToken());

            try renderExpression(allocator, stream, tree, suffix_op.lhs, Space.None);
            try renderToken(tree, stream, lbracket, Space.None); // [

            const starts_with_comment = tree.token_ids[lbracket + 1] == .LineComment;
            const ends_with_comment = tree.token_ids[rbracket - 1] == .LineComment;
            {
                const new_space = if (ends_with_comment) Space.Newline else Space.None;

                stream.pushIndent();
                defer stream.popIndent();
                try renderExpression(allocator, stream, tree, suffix_op.index_expr, new_space);
            }
            if (starts_with_comment) try stream.maybeInsertNewline();
            return renderToken(tree, stream, rbracket, space); // ]
        },

        .Slice => {
            const suffix_op = base.castTag(.Slice).?;
            try renderExpression(allocator, stream, tree, suffix_op.lhs, Space.None);

            const lbracket = tree.prevToken(suffix_op.start.firstToken());
            const dotdot = tree.nextToken(suffix_op.start.lastToken());

            const after_start_space_bool = nodeCausesSliceOpSpace(suffix_op.start) or
                (if (suffix_op.end) |end| nodeCausesSliceOpSpace(end) else false);
            const after_start_space = if (after_start_space_bool) Space.Space else Space.None;
            const after_op_space = if (suffix_op.end != null) after_start_space else Space.None;

            try renderToken(tree, stream, lbracket, Space.None); // [
            try renderExpression(allocator, stream, tree, suffix_op.start, after_start_space);
            try renderToken(tree, stream, dotdot, after_op_space); // ..
            if (suffix_op.end) |end| {
                const after_end_space = if (suffix_op.sentinel != null) Space.Space else Space.None;
                try renderExpression(allocator, stream, tree, end, after_end_space);
            }
            if (suffix_op.sentinel) |sentinel| {
                const colon = tree.prevToken(sentinel.firstToken());
                try renderToken(tree, stream, colon, Space.None); // :
                try renderExpression(allocator, stream, tree, sentinel, Space.None);
            }
            return renderToken(tree, stream, suffix_op.rtoken, space); // ]
        },

        .Deref => {
            const suffix_op = base.castTag(.Deref).?;

            try renderExpression(allocator, stream, tree, suffix_op.lhs, Space.None);
            return renderToken(tree, stream, suffix_op.rtoken, space); // .*
        },
        .UnwrapOptional => {
            const suffix_op = base.castTag(.UnwrapOptional).?;

            try renderExpression(allocator, stream, tree, suffix_op.lhs, Space.None);
            try renderToken(tree, stream, tree.prevToken(suffix_op.rtoken), Space.None); // .
            return renderToken(tree, stream, suffix_op.rtoken, space); // ?
        },

        .Break => {
            const flow_expr = base.castTag(.Break).?;
            const maybe_rhs = flow_expr.getRHS();
            const maybe_label = flow_expr.getLabel();

            if (maybe_label == null and maybe_rhs == null) {
                return renderToken(tree, stream, flow_expr.ltoken, space); // break
            }

            try renderToken(tree, stream, flow_expr.ltoken, Space.Space); // break
            if (maybe_label) |label| {
                const colon = tree.nextToken(flow_expr.ltoken);
                try renderToken(tree, stream, colon, Space.None); // :

                if (maybe_rhs == null) {
                    return renderToken(tree, stream, label, space); // label
                }
                try renderToken(tree, stream, label, Space.Space); // label
            }
            return renderExpression(allocator, stream, tree, maybe_rhs.?, space);
        },

        .Continue => {
            const flow_expr = base.castTag(.Continue).?;
            if (flow_expr.getLabel()) |label| {
                try renderToken(tree, stream, flow_expr.ltoken, Space.Space); // continue
                const colon = tree.nextToken(flow_expr.ltoken);
                try renderToken(tree, stream, colon, Space.None); // :
                return renderToken(tree, stream, label, space); // label
            } else {
                return renderToken(tree, stream, flow_expr.ltoken, space); // continue
            }
        },

        .Return => {
            const flow_expr = base.castTag(.Return).?;
            if (flow_expr.getRHS()) |rhs| {
                try renderToken(tree, stream, flow_expr.ltoken, Space.Space);
                return renderExpression(allocator, stream, tree, rhs, space);
            } else {
                return renderToken(tree, stream, flow_expr.ltoken, space);
            }
        },

        .Payload => {
            const payload = @fieldParentPtr(ast.Node.Payload, "base", base);

            try renderToken(tree, stream, payload.lpipe, Space.None);
            try renderExpression(allocator, stream, tree, payload.error_symbol, Space.None);
            return renderToken(tree, stream, payload.rpipe, space);
        },

        .PointerPayload => {
            const payload = @fieldParentPtr(ast.Node.PointerPayload, "base", base);

            try renderToken(tree, stream, payload.lpipe, Space.None);
            if (payload.ptr_token) |ptr_token| {
                try renderToken(tree, stream, ptr_token, Space.None);
            }
            try renderExpression(allocator, stream, tree, payload.value_symbol, Space.None);
            return renderToken(tree, stream, payload.rpipe, space);
        },

        .PointerIndexPayload => {
            const payload = @fieldParentPtr(ast.Node.PointerIndexPayload, "base", base);

            try renderToken(tree, stream, payload.lpipe, Space.None);
            if (payload.ptr_token) |ptr_token| {
                try renderToken(tree, stream, ptr_token, Space.None);
            }
            try renderExpression(allocator, stream, tree, payload.value_symbol, Space.None);

            if (payload.index_symbol) |index_symbol| {
                const comma = tree.nextToken(payload.value_symbol.lastToken());

                try renderToken(tree, stream, comma, Space.Space);
                try renderExpression(allocator, stream, tree, index_symbol, Space.None);
            }

            return renderToken(tree, stream, payload.rpipe, space);
        },

        .GroupedExpression => {
            const grouped_expr = @fieldParentPtr(ast.Node.GroupedExpression, "base", base);

            try renderToken(tree, stream, grouped_expr.lparen, Space.None);
            {
                stream.pushIndentOneShot();
                try renderExpression(allocator, stream, tree, grouped_expr.expr, Space.None);
            }
            return renderToken(tree, stream, grouped_expr.rparen, space);
        },

        .FieldInitializer => {
            const field_init = @fieldParentPtr(ast.Node.FieldInitializer, "base", base);

            try renderToken(tree, stream, field_init.period_token, Space.None); // .
            try renderToken(tree, stream, field_init.name_token, Space.Space); // name
            try renderToken(tree, stream, tree.nextToken(field_init.name_token), Space.Space); // =
            return renderExpression(allocator, stream, tree, field_init.expr, space);
        },

        .ContainerDecl => {
            const container_decl = @fieldParentPtr(ast.Node.ContainerDecl, "base", base);

            if (container_decl.layout_token) |layout_token| {
                try renderToken(tree, stream, layout_token, Space.Space);
            }

            switch (container_decl.init_arg_expr) {
                .None => {
                    try renderToken(tree, stream, container_decl.kind_token, Space.Space); // union
                },
                .Enum => |enum_tag_type| {
                    try renderToken(tree, stream, container_decl.kind_token, Space.None); // union

                    const lparen = tree.nextToken(container_decl.kind_token);
                    const enum_token = tree.nextToken(lparen);

                    try renderToken(tree, stream, lparen, Space.None); // (
                    try renderToken(tree, stream, enum_token, Space.None); // enum

                    if (enum_tag_type) |expr| {
                        try renderToken(tree, stream, tree.nextToken(enum_token), Space.None); // (
                        try renderExpression(allocator, stream, tree, expr, Space.None);

                        const rparen = tree.nextToken(expr.lastToken());
                        try renderToken(tree, stream, rparen, Space.None); // )
                        try renderToken(tree, stream, tree.nextToken(rparen), Space.Space); // )
                    } else {
                        try renderToken(tree, stream, tree.nextToken(enum_token), Space.Space); // )
                    }
                },
                .Type => |type_expr| {
                    try renderToken(tree, stream, container_decl.kind_token, Space.None); // union

                    const lparen = tree.nextToken(container_decl.kind_token);
                    const rparen = tree.nextToken(type_expr.lastToken());

                    try renderToken(tree, stream, lparen, Space.None); // (
                    try renderExpression(allocator, stream, tree, type_expr, Space.None);
                    try renderToken(tree, stream, rparen, Space.Space); // )
                },
            }

            if (container_decl.fields_and_decls_len == 0) {
                {
                    stream.pushIndentNextLine();
                    defer stream.popIndent();
                    try renderToken(tree, stream, container_decl.lbrace_token, Space.None); // {
                }
                return renderToken(tree, stream, container_decl.rbrace_token, space); // }
            }

            const src_has_trailing_comma = blk: {
                var maybe_comma = tree.prevToken(container_decl.lastToken());
                // Doc comments for a field may also appear after the comma, eg.
                // field_name: T, // comment attached to field_name
                if (tree.token_ids[maybe_comma] == .DocComment)
                    maybe_comma = tree.prevToken(maybe_comma);
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            const fields_and_decls = container_decl.fieldsAndDecls();

            // Check if the first declaration and the { are on the same line
            const src_has_newline = !tree.tokensOnSameLine(
                container_decl.lbrace_token,
                fields_and_decls[0].firstToken(),
            );

            // We can only print all the elements in-line if all the
            // declarations inside are fields
            const src_has_only_fields = blk: {
                for (fields_and_decls) |decl| {
                    if (decl.tag != .ContainerField) break :blk false;
                }
                break :blk true;
            };

            if (src_has_trailing_comma or !src_has_only_fields) {
                // One declaration per line
                stream.pushIndentNextLine();
                defer stream.popIndent();
                try renderToken(tree, stream, container_decl.lbrace_token, .Newline); // {

                for (fields_and_decls) |decl, i| {
                    try renderContainerDecl(allocator, stream, tree, decl, .Newline);

                    if (i + 1 < fields_and_decls.len) {
                        try renderExtraNewline(tree, stream, fields_and_decls[i + 1]);
                    }
                }
            } else if (src_has_newline) {
                // All the declarations on the same line, but place the items on
                // their own line
                try renderToken(tree, stream, container_decl.lbrace_token, .Newline); // {

                stream.pushIndent();
                defer stream.popIndent();

                for (fields_and_decls) |decl, i| {
                    const space_after_decl: Space = if (i + 1 >= fields_and_decls.len) .Newline else .Space;
                    try renderContainerDecl(allocator, stream, tree, decl, space_after_decl);
                }
            } else {
                // All the declarations on the same line
                try renderToken(tree, stream, container_decl.lbrace_token, .Space); // {

                for (fields_and_decls) |decl| {
                    try renderContainerDecl(allocator, stream, tree, decl, .Space);
                }
            }

            return renderToken(tree, stream, container_decl.rbrace_token, space); // }
        },

        .ErrorSetDecl => {
            const err_set_decl = @fieldParentPtr(ast.Node.ErrorSetDecl, "base", base);

            const lbrace = tree.nextToken(err_set_decl.error_token);

            if (err_set_decl.decls_len == 0) {
                try renderToken(tree, stream, err_set_decl.error_token, Space.None);
                try renderToken(tree, stream, lbrace, Space.None);
                return renderToken(tree, stream, err_set_decl.rbrace_token, space);
            }

            if (err_set_decl.decls_len == 1) blk: {
                const node = err_set_decl.decls()[0];

                // if there are any doc comments or same line comments
                // don't try to put it all on one line
                if (node.cast(ast.Node.ErrorTag)) |tag| {
                    if (tag.doc_comments != null) break :blk;
                } else {
                    break :blk;
                }

                try renderToken(tree, stream, err_set_decl.error_token, Space.None); // error
                try renderToken(tree, stream, lbrace, Space.None); // {
                try renderExpression(allocator, stream, tree, node, Space.None);
                return renderToken(tree, stream, err_set_decl.rbrace_token, space); // }
            }

            try renderToken(tree, stream, err_set_decl.error_token, Space.None); // error

            const src_has_trailing_comma = blk: {
                const maybe_comma = tree.prevToken(err_set_decl.rbrace_token);
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            if (src_has_trailing_comma) {
                {
                    stream.pushIndent();
                    defer stream.popIndent();

                    try renderToken(tree, stream, lbrace, Space.Newline); // {
                    const decls = err_set_decl.decls();
                    for (decls) |node, i| {
                        if (i + 1 < decls.len) {
                            try renderExpression(allocator, stream, tree, node, Space.None);
                            try renderToken(tree, stream, tree.nextToken(node.lastToken()), Space.Newline); // ,

                            try renderExtraNewline(tree, stream, decls[i + 1]);
                        } else {
                            try renderExpression(allocator, stream, tree, node, Space.Comma);
                        }
                    }
                }

                return renderToken(tree, stream, err_set_decl.rbrace_token, space); // }
            } else {
                try renderToken(tree, stream, lbrace, Space.Space); // {

                const decls = err_set_decl.decls();
                for (decls) |node, i| {
                    if (i + 1 < decls.len) {
                        try renderExpression(allocator, stream, tree, node, Space.None);

                        const comma_token = tree.nextToken(node.lastToken());
                        assert(tree.token_ids[comma_token] == .Comma);
                        try renderToken(tree, stream, comma_token, Space.Space); // ,
                        try renderExtraNewline(tree, stream, decls[i + 1]);
                    } else {
                        try renderExpression(allocator, stream, tree, node, Space.Space);
                    }
                }

                return renderToken(tree, stream, err_set_decl.rbrace_token, space); // }
            }
        },

        .ErrorTag => {
            const tag = @fieldParentPtr(ast.Node.ErrorTag, "base", base);

            try renderDocComments(tree, stream, tag, tag.doc_comments);
            return renderToken(tree, stream, tag.name_token, space); // name
        },

        .MultilineStringLiteral => {
            const multiline_str_literal = @fieldParentPtr(ast.Node.MultilineStringLiteral, "base", base);

            {
                const locked_indents = stream.lockOneShotIndent();
                defer {
                    var i: u8 = 0;
                    while (i < locked_indents) : (i += 1) stream.popIndent();
                }
                try stream.maybeInsertNewline();

                for (multiline_str_literal.lines()) |t| try renderToken(tree, stream, t, Space.None);
            }
        },

        .BuiltinCall => {
            const builtin_call = @fieldParentPtr(ast.Node.BuiltinCall, "base", base);

            // TODO remove after 0.7.0 release
            if (mem.eql(u8, tree.tokenSlice(builtin_call.builtin_token), "@OpaqueType"))
                return stream.writeAll("@Type(.Opaque)");

            try renderToken(tree, stream, builtin_call.builtin_token, Space.None); // @name

            const src_params_trailing_comma = blk: {
                if (builtin_call.params_len < 2) break :blk false;
                const last_node = builtin_call.params()[builtin_call.params_len - 1];
                const maybe_comma = tree.nextToken(last_node.lastToken());
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            const lparen = tree.nextToken(builtin_call.builtin_token);

            if (!src_params_trailing_comma) {
                try renderToken(tree, stream, lparen, Space.None); // (

                // render all on one line, no trailing comma
                const params = builtin_call.params();
                for (params) |param_node, i| {
                    try renderExpression(allocator, stream, tree, param_node, Space.None);

                    if (i + 1 < params.len) {
                        const comma_token = tree.nextToken(param_node.lastToken());
                        try renderToken(tree, stream, comma_token, Space.Space); // ,
                    }
                }
            } else {
                // one param per line
                stream.pushIndent();
                defer stream.popIndent();
                try renderToken(tree, stream, lparen, Space.Newline); // (

                for (builtin_call.params()) |param_node| {
                    try renderExpression(allocator, stream, tree, param_node, Space.Comma);
                }
            }

            return renderToken(tree, stream, builtin_call.rparen_token, space); // )
        },

        .FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", base);

            if (fn_proto.getVisibToken()) |visib_token_index| {
                const visib_token = tree.token_ids[visib_token_index];
                assert(visib_token == .Keyword_pub or visib_token == .Keyword_export);

                try renderToken(tree, stream, visib_token_index, Space.Space); // pub
            }

            if (fn_proto.getExternExportInlineToken()) |extern_export_inline_token| {
                if (fn_proto.getIsExternPrototype() == null)
                    try renderToken(tree, stream, extern_export_inline_token, Space.Space); // extern/export/inline
            }

            if (fn_proto.getLibName()) |lib_name| {
                try renderExpression(allocator, stream, tree, lib_name, Space.Space);
            }

            const lparen = if (fn_proto.getNameToken()) |name_token| blk: {
                try renderToken(tree, stream, fn_proto.fn_token, Space.Space); // fn
                try renderToken(tree, stream, name_token, Space.None); // name
                break :blk tree.nextToken(name_token);
            } else blk: {
                try renderToken(tree, stream, fn_proto.fn_token, Space.Space); // fn
                break :blk tree.nextToken(fn_proto.fn_token);
            };
            assert(tree.token_ids[lparen] == .LParen);

            const rparen = tree.prevToken(
            // the first token for the annotation expressions is the left
            // parenthesis, hence the need for two prevToken
            if (fn_proto.getAlignExpr()) |align_expr|
                tree.prevToken(tree.prevToken(align_expr.firstToken()))
            else if (fn_proto.getSectionExpr()) |section_expr|
                tree.prevToken(tree.prevToken(section_expr.firstToken()))
            else if (fn_proto.getCallconvExpr()) |callconv_expr|
                tree.prevToken(tree.prevToken(callconv_expr.firstToken()))
            else switch (fn_proto.return_type) {
                .Explicit => |node| node.firstToken(),
                .InferErrorSet => |node| tree.prevToken(node.firstToken()),
                .Invalid => unreachable,
            });
            assert(tree.token_ids[rparen] == .RParen);

            const src_params_trailing_comma = blk: {
                const maybe_comma = tree.token_ids[rparen - 1];
                break :blk maybe_comma == .Comma or maybe_comma == .LineComment;
            };

            if (!src_params_trailing_comma) {
                try renderToken(tree, stream, lparen, Space.None); // (

                // render all on one line, no trailing comma
                for (fn_proto.params()) |param_decl, i| {
                    try renderParamDecl(allocator, stream, tree, param_decl, Space.None);

                    if (i + 1 < fn_proto.params_len or fn_proto.getVarArgsToken() != null) {
                        const comma = tree.nextToken(param_decl.lastToken());
                        try renderToken(tree, stream, comma, Space.Space); // ,
                    }
                }
                if (fn_proto.getVarArgsToken()) |var_args_token| {
                    try renderToken(tree, stream, var_args_token, Space.None);
                }
            } else {
                // one param per line
                stream.pushIndent();
                defer stream.popIndent();
                try renderToken(tree, stream, lparen, Space.Newline); // (

                for (fn_proto.params()) |param_decl| {
                    try renderParamDecl(allocator, stream, tree, param_decl, Space.Comma);
                }
                if (fn_proto.getVarArgsToken()) |var_args_token| {
                    try renderToken(tree, stream, var_args_token, Space.Comma);
                }
            }

            try renderToken(tree, stream, rparen, Space.Space); // )

            if (fn_proto.getAlignExpr()) |align_expr| {
                const align_rparen = tree.nextToken(align_expr.lastToken());
                const align_lparen = tree.prevToken(align_expr.firstToken());
                const align_kw = tree.prevToken(align_lparen);

                try renderToken(tree, stream, align_kw, Space.None); // align
                try renderToken(tree, stream, align_lparen, Space.None); // (
                try renderExpression(allocator, stream, tree, align_expr, Space.None);
                try renderToken(tree, stream, align_rparen, Space.Space); // )
            }

            if (fn_proto.getSectionExpr()) |section_expr| {
                const section_rparen = tree.nextToken(section_expr.lastToken());
                const section_lparen = tree.prevToken(section_expr.firstToken());
                const section_kw = tree.prevToken(section_lparen);

                try renderToken(tree, stream, section_kw, Space.None); // section
                try renderToken(tree, stream, section_lparen, Space.None); // (
                try renderExpression(allocator, stream, tree, section_expr, Space.None);
                try renderToken(tree, stream, section_rparen, Space.Space); // )
            }

            if (fn_proto.getCallconvExpr()) |callconv_expr| {
                const callconv_rparen = tree.nextToken(callconv_expr.lastToken());
                const callconv_lparen = tree.prevToken(callconv_expr.firstToken());
                const callconv_kw = tree.prevToken(callconv_lparen);

                try renderToken(tree, stream, callconv_kw, Space.None); // callconv
                try renderToken(tree, stream, callconv_lparen, Space.None); // (
                try renderExpression(allocator, stream, tree, callconv_expr, Space.None);
                try renderToken(tree, stream, callconv_rparen, Space.Space); // )
            } else if (fn_proto.getIsExternPrototype() != null) {
                try stream.writer().writeAll("callconv(.C) ");
            } else if (fn_proto.getIsAsync() != null) {
                try stream.writer().writeAll("callconv(.Async) ");
            }

            switch (fn_proto.return_type) {
                .Explicit => |node| {
                    return renderExpression(allocator, stream, tree, node, space);
                },
                .InferErrorSet => |node| {
                    try renderToken(tree, stream, tree.prevToken(node.firstToken()), Space.None); // !
                    return renderExpression(allocator, stream, tree, node, space);
                },
                .Invalid => unreachable,
            }
        },

        .AnyFrameType => {
            const anyframe_type = @fieldParentPtr(ast.Node.AnyFrameType, "base", base);

            if (anyframe_type.result) |result| {
                try renderToken(tree, stream, anyframe_type.anyframe_token, Space.None); // anyframe
                try renderToken(tree, stream, result.arrow_token, Space.None); // ->
                return renderExpression(allocator, stream, tree, result.return_type, space);
            } else {
                return renderToken(tree, stream, anyframe_type.anyframe_token, space); // anyframe
            }
        },

        .DocComment => unreachable, // doc comments are attached to nodes

        .Switch => {
            const switch_node = @fieldParentPtr(ast.Node.Switch, "base", base);

            try renderToken(tree, stream, switch_node.switch_token, Space.Space); // switch
            try renderToken(tree, stream, tree.nextToken(switch_node.switch_token), Space.None); // (

            const rparen = tree.nextToken(switch_node.expr.lastToken());
            const lbrace = tree.nextToken(rparen);

            if (switch_node.cases_len == 0) {
                try renderExpression(allocator, stream, tree, switch_node.expr, Space.None);
                try renderToken(tree, stream, rparen, Space.Space); // )
                try renderToken(tree, stream, lbrace, Space.None); // {
                return renderToken(tree, stream, switch_node.rbrace, space); // }
            }

            try renderExpression(allocator, stream, tree, switch_node.expr, Space.None);
            try renderToken(tree, stream, rparen, Space.Space); // )

            {
                stream.pushIndentNextLine();
                defer stream.popIndent();
                try renderToken(tree, stream, lbrace, Space.Newline); // {

                const cases = switch_node.cases();
                for (cases) |node, i| {
                    try renderExpression(allocator, stream, tree, node, Space.Comma);

                    if (i + 1 < cases.len) {
                        try renderExtraNewline(tree, stream, cases[i + 1]);
                    }
                }
            }

            return renderToken(tree, stream, switch_node.rbrace, space); // }
        },

        .SwitchCase => {
            const switch_case = @fieldParentPtr(ast.Node.SwitchCase, "base", base);

            assert(switch_case.items_len != 0);
            const src_has_trailing_comma = blk: {
                const last_node = switch_case.items()[switch_case.items_len - 1];
                const maybe_comma = tree.nextToken(last_node.lastToken());
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            if (switch_case.items_len == 1 or !src_has_trailing_comma) {
                const items = switch_case.items();
                for (items) |node, i| {
                    if (i + 1 < items.len) {
                        try renderExpression(allocator, stream, tree, node, Space.None);

                        const comma_token = tree.nextToken(node.lastToken());
                        try renderToken(tree, stream, comma_token, Space.Space); // ,
                        try renderExtraNewline(tree, stream, items[i + 1]);
                    } else {
                        try renderExpression(allocator, stream, tree, node, Space.Space);
                    }
                }
            } else {
                const items = switch_case.items();
                for (items) |node, i| {
                    if (i + 1 < items.len) {
                        try renderExpression(allocator, stream, tree, node, Space.None);

                        const comma_token = tree.nextToken(node.lastToken());
                        try renderToken(tree, stream, comma_token, Space.Newline); // ,
                        try renderExtraNewline(tree, stream, items[i + 1]);
                    } else {
                        try renderExpression(allocator, stream, tree, node, Space.Comma);
                    }
                }
            }

            try renderToken(tree, stream, switch_case.arrow_token, Space.Space); // =>

            if (switch_case.payload) |payload| {
                try renderExpression(allocator, stream, tree, payload, Space.Space);
            }

            return renderExpression(allocator, stream, tree, switch_case.expr, space);
        },
        .SwitchElse => {
            const switch_else = @fieldParentPtr(ast.Node.SwitchElse, "base", base);
            return renderToken(tree, stream, switch_else.token, space);
        },
        .Else => {
            const else_node = @fieldParentPtr(ast.Node.Else, "base", base);

            const body_is_block = nodeIsBlock(else_node.body);
            const same_line = body_is_block or tree.tokensOnSameLine(else_node.else_token, else_node.body.lastToken());

            const after_else_space = if (same_line or else_node.payload != null) Space.Space else Space.Newline;
            try renderToken(tree, stream, else_node.else_token, after_else_space);

            if (else_node.payload) |payload| {
                const payload_space = if (same_line) Space.Space else Space.Newline;
                try renderExpression(allocator, stream, tree, payload, payload_space);
            }

            if (same_line) {
                return renderExpression(allocator, stream, tree, else_node.body, space);
            } else {
                stream.pushIndent();
                defer stream.popIndent();
                return renderExpression(allocator, stream, tree, else_node.body, space);
            }
        },

        .While => {
            const while_node = @fieldParentPtr(ast.Node.While, "base", base);

            if (while_node.label) |label| {
                try renderToken(tree, stream, label, Space.None); // label
                try renderToken(tree, stream, tree.nextToken(label), Space.Space); // :
            }

            if (while_node.inline_token) |inline_token| {
                try renderToken(tree, stream, inline_token, Space.Space); // inline
            }

            try renderToken(tree, stream, while_node.while_token, Space.Space); // while
            try renderToken(tree, stream, tree.nextToken(while_node.while_token), Space.None); // (
            try renderExpression(allocator, stream, tree, while_node.condition, Space.None);

            const cond_rparen = tree.nextToken(while_node.condition.lastToken());

            const body_is_block = nodeIsBlock(while_node.body);

            var block_start_space: Space = undefined;
            var after_body_space: Space = undefined;

            if (body_is_block) {
                block_start_space = Space.BlockStart;
                after_body_space = if (while_node.@"else" == null) space else Space.SpaceOrOutdent;
            } else if (tree.tokensOnSameLine(cond_rparen, while_node.body.lastToken())) {
                block_start_space = Space.Space;
                after_body_space = if (while_node.@"else" == null) space else Space.Space;
            } else {
                block_start_space = Space.Newline;
                after_body_space = if (while_node.@"else" == null) space else Space.Newline;
            }

            {
                const rparen_space = if (while_node.payload != null or while_node.continue_expr != null) Space.Space else block_start_space;
                try renderToken(tree, stream, cond_rparen, rparen_space); // )
            }

            if (while_node.payload) |payload| {
                const payload_space = Space.Space; //if (while_node.continue_expr != null) Space.Space else block_start_space;
                try renderExpression(allocator, stream, tree, payload, payload_space);
            }

            if (while_node.continue_expr) |continue_expr| {
                const rparen = tree.nextToken(continue_expr.lastToken());
                const lparen = tree.prevToken(continue_expr.firstToken());
                const colon = tree.prevToken(lparen);

                try renderToken(tree, stream, colon, Space.Space); // :
                try renderToken(tree, stream, lparen, Space.None); // (

                try renderExpression(allocator, stream, tree, continue_expr, Space.None);

                try renderToken(tree, stream, rparen, block_start_space); // )
            }

            {
                if (!body_is_block) stream.pushIndent();
                defer if (!body_is_block) stream.popIndent();
                try renderExpression(allocator, stream, tree, while_node.body, after_body_space);
            }

            if (while_node.@"else") |@"else"| {
                return renderExpression(allocator, stream, tree, &@"else".base, space);
            }
        },

        .For => {
            const for_node = @fieldParentPtr(ast.Node.For, "base", base);

            if (for_node.label) |label| {
                try renderToken(tree, stream, label, Space.None); // label
                try renderToken(tree, stream, tree.nextToken(label), Space.Space); // :
            }

            if (for_node.inline_token) |inline_token| {
                try renderToken(tree, stream, inline_token, Space.Space); // inline
            }

            try renderToken(tree, stream, for_node.for_token, Space.Space); // for
            try renderToken(tree, stream, tree.nextToken(for_node.for_token), Space.None); // (
            try renderExpression(allocator, stream, tree, for_node.array_expr, Space.None);

            const rparen = tree.nextToken(for_node.array_expr.lastToken());

            const body_is_block = for_node.body.tag.isBlock();
            const src_one_line_to_body = !body_is_block and tree.tokensOnSameLine(rparen, for_node.body.firstToken());
            const body_on_same_line = body_is_block or src_one_line_to_body;

            try renderToken(tree, stream, rparen, Space.Space); // )

            const space_after_payload = if (body_on_same_line) Space.Space else Space.Newline;
            try renderExpression(allocator, stream, tree, for_node.payload, space_after_payload); // |x|

            const space_after_body = blk: {
                if (for_node.@"else") |@"else"| {
                    const src_one_line_to_else = tree.tokensOnSameLine(rparen, @"else".firstToken());
                    if (body_is_block or src_one_line_to_else) {
                        break :blk Space.Space;
                    } else {
                        break :blk Space.Newline;
                    }
                } else {
                    break :blk space;
                }
            };

            {
                if (!body_on_same_line) stream.pushIndent();
                defer if (!body_on_same_line) stream.popIndent();
                try renderExpression(allocator, stream, tree, for_node.body, space_after_body); // { body }
            }

            if (for_node.@"else") |@"else"| {
                return renderExpression(allocator, stream, tree, &@"else".base, space); // else
            }
        },

        .If => {
            const if_node = @fieldParentPtr(ast.Node.If, "base", base);

            const lparen = tree.nextToken(if_node.if_token);
            const rparen = tree.nextToken(if_node.condition.lastToken());

            try renderToken(tree, stream, if_node.if_token, Space.Space); // if
            try renderToken(tree, stream, lparen, Space.None); // (

            try renderExpression(allocator, stream, tree, if_node.condition, Space.None); // condition

            const body_is_if_block = if_node.body.tag == .If;
            const body_is_block = nodeIsBlock(if_node.body);

            if (body_is_if_block) {
                try renderExtraNewline(tree, stream, if_node.body);
            } else if (body_is_block) {
                const after_rparen_space = if (if_node.payload == null) Space.BlockStart else Space.Space;
                try renderToken(tree, stream, rparen, after_rparen_space); // )

                if (if_node.payload) |payload| {
                    try renderExpression(allocator, stream, tree, payload, Space.BlockStart); // |x|
                }

                if (if_node.@"else") |@"else"| {
                    try renderExpression(allocator, stream, tree, if_node.body, Space.SpaceOrOutdent);
                    return renderExpression(allocator, stream, tree, &@"else".base, space);
                } else {
                    return renderExpression(allocator, stream, tree, if_node.body, space);
                }
            }

            const src_has_newline = !tree.tokensOnSameLine(rparen, if_node.body.lastToken());

            if (src_has_newline) {
                const after_rparen_space = if (if_node.payload == null) Space.Newline else Space.Space;
                try renderToken(tree, stream, rparen, after_rparen_space); // )

                if (if_node.payload) |payload| {
                    try renderExpression(allocator, stream, tree, payload, Space.Newline);
                }

                if (if_node.@"else") |@"else"| {
                    const else_is_block = nodeIsBlock(@"else".body);

                    {
                        stream.pushIndent();
                        defer stream.popIndent();
                        try renderExpression(allocator, stream, tree, if_node.body, Space.Newline);
                    }

                    if (else_is_block) {
                        try renderToken(tree, stream, @"else".else_token, Space.Space); // else

                        if (@"else".payload) |payload| {
                            try renderExpression(allocator, stream, tree, payload, Space.Space);
                        }

                        return renderExpression(allocator, stream, tree, @"else".body, space);
                    } else {
                        const after_else_space = if (@"else".payload == null) Space.Newline else Space.Space;
                        try renderToken(tree, stream, @"else".else_token, after_else_space); // else

                        if (@"else".payload) |payload| {
                            try renderExpression(allocator, stream, tree, payload, Space.Newline);
                        }

                        stream.pushIndent();
                        defer stream.popIndent();
                        return renderExpression(allocator, stream, tree, @"else".body, space);
                    }
                } else {
                    stream.pushIndent();
                    defer stream.popIndent();
                    return renderExpression(allocator, stream, tree, if_node.body, space);
                }
            }

            // Single line if statement

            try renderToken(tree, stream, rparen, Space.Space); // )

            if (if_node.payload) |payload| {
                try renderExpression(allocator, stream, tree, payload, Space.Space);
            }

            if (if_node.@"else") |@"else"| {
                try renderExpression(allocator, stream, tree, if_node.body, Space.Space);
                try renderToken(tree, stream, @"else".else_token, Space.Space);

                if (@"else".payload) |payload| {
                    try renderExpression(allocator, stream, tree, payload, Space.Space);
                }

                return renderExpression(allocator, stream, tree, @"else".body, space);
            } else {
                return renderExpression(allocator, stream, tree, if_node.body, space);
            }
        },

        .Asm => {
            const asm_node = @fieldParentPtr(ast.Node.Asm, "base", base);

            try renderToken(tree, stream, asm_node.asm_token, Space.Space); // asm

            if (asm_node.volatile_token) |volatile_token| {
                try renderToken(tree, stream, volatile_token, Space.Space); // volatile
                try renderToken(tree, stream, tree.nextToken(volatile_token), Space.None); // (
            } else {
                try renderToken(tree, stream, tree.nextToken(asm_node.asm_token), Space.None); // (
            }

            asmblk: {
                stream.pushIndent();
                defer stream.popIndent();

                if (asm_node.outputs.len == 0 and asm_node.inputs.len == 0 and asm_node.clobbers.len == 0) {
                    try renderExpression(allocator, stream, tree, asm_node.template, Space.None);
                    break :asmblk;
                }

                try renderExpression(allocator, stream, tree, asm_node.template, Space.Newline);

                stream.setIndentDelta(asm_indent_delta);
                defer stream.setIndentDelta(indent_delta);

                const colon1 = tree.nextToken(asm_node.template.lastToken());

                const colon2 = if (asm_node.outputs.len == 0) blk: {
                    try renderToken(tree, stream, colon1, Space.Newline); // :

                    break :blk tree.nextToken(colon1);
                } else blk: {
                    try renderToken(tree, stream, colon1, Space.Space); // :

                    stream.pushIndent();
                    defer stream.popIndent();

                    for (asm_node.outputs) |*asm_output, i| {
                        if (i + 1 < asm_node.outputs.len) {
                            const next_asm_output = asm_node.outputs[i + 1];
                            try renderAsmOutput(allocator, stream, tree, asm_output, Space.None);

                            const comma = tree.prevToken(next_asm_output.firstToken());
                            try renderToken(tree, stream, comma, Space.Newline); // ,
                            try renderExtraNewlineToken(tree, stream, next_asm_output.firstToken());
                        } else if (asm_node.inputs.len == 0 and asm_node.clobbers.len == 0) {
                            try renderAsmOutput(allocator, stream, tree, asm_output, Space.Newline);
                            break :asmblk;
                        } else {
                            try renderAsmOutput(allocator, stream, tree, asm_output, Space.Newline);
                            const comma_or_colon = tree.nextToken(asm_output.lastToken());
                            break :blk switch (tree.token_ids[comma_or_colon]) {
                                .Comma => tree.nextToken(comma_or_colon),
                                else => comma_or_colon,
                            };
                        }
                    }
                    unreachable;
                };

                const colon3 = if (asm_node.inputs.len == 0) blk: {
                    try renderToken(tree, stream, colon2, Space.Newline); // :
                    break :blk tree.nextToken(colon2);
                } else blk: {
                    try renderToken(tree, stream, colon2, Space.Space); // :
                    stream.pushIndent();
                    defer stream.popIndent();
                    for (asm_node.inputs) |*asm_input, i| {
                        if (i + 1 < asm_node.inputs.len) {
                            const next_asm_input = &asm_node.inputs[i + 1];
                            try renderAsmInput(allocator, stream, tree, asm_input, Space.None);

                            const comma = tree.prevToken(next_asm_input.firstToken());
                            try renderToken(tree, stream, comma, Space.Newline); // ,
                            try renderExtraNewlineToken(tree, stream, next_asm_input.firstToken());
                        } else if (asm_node.clobbers.len == 0) {
                            try renderAsmInput(allocator, stream, tree, asm_input, Space.Newline);
                            break :asmblk;
                        } else {
                            try renderAsmInput(allocator, stream, tree, asm_input, Space.Newline);
                            const comma_or_colon = tree.nextToken(asm_input.lastToken());
                            break :blk switch (tree.token_ids[comma_or_colon]) {
                                .Comma => tree.nextToken(comma_or_colon),
                                else => comma_or_colon,
                            };
                        }
                    }
                    unreachable;
                };

                try renderToken(tree, stream, colon3, Space.Space); // :
                stream.pushIndent();
                defer stream.popIndent();
                for (asm_node.clobbers) |clobber_node, i| {
                    if (i + 1 >= asm_node.clobbers.len) {
                        try renderExpression(allocator, stream, tree, clobber_node, Space.Newline);
                        break :asmblk;
                    } else {
                        try renderExpression(allocator, stream, tree, clobber_node, Space.None);
                        const comma = tree.nextToken(clobber_node.lastToken());
                        try renderToken(tree, stream, comma, Space.Space); // ,
                    }
                }
            }

            return renderToken(tree, stream, asm_node.rparen, space);
        },

        .EnumLiteral => {
            const enum_literal = @fieldParentPtr(ast.Node.EnumLiteral, "base", base);

            try renderToken(tree, stream, enum_literal.dot, Space.None); // .
            return renderToken(tree, stream, enum_literal.name, space); // name
        },

        .ContainerField,
        .Root,
        .VarDecl,
        .Use,
        .TestDecl,
        => unreachable,
    }
}

fn renderArrayType(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    lbracket: ast.TokenIndex,
    rhs: *ast.Node,
    len_expr: *ast.Node,
    opt_sentinel: ?*ast.Node,
    space: Space,
) (@TypeOf(stream.*).Error || Error)!void {
    const rbracket = tree.nextToken(if (opt_sentinel) |sentinel|
        sentinel.lastToken()
    else
        len_expr.lastToken());

    const starts_with_comment = tree.token_ids[lbracket + 1] == .LineComment;
    const ends_with_comment = tree.token_ids[rbracket - 1] == .LineComment;
    const new_space = if (ends_with_comment) Space.Newline else Space.None;
    {
        const do_indent = (starts_with_comment or ends_with_comment);
        if (do_indent) stream.pushIndent();
        defer if (do_indent) stream.popIndent();

        try renderToken(tree, stream, lbracket, Space.None); // [
        try renderExpression(allocator, stream, tree, len_expr, new_space);

        if (starts_with_comment) {
            try stream.maybeInsertNewline();
        }
        if (opt_sentinel) |sentinel| {
            const colon_token = tree.prevToken(sentinel.firstToken());
            try renderToken(tree, stream, colon_token, Space.None); // :
            try renderExpression(allocator, stream, tree, sentinel, Space.None);
        }
        if (starts_with_comment) {
            try stream.maybeInsertNewline();
        }
    }
    try renderToken(tree, stream, rbracket, Space.None); // ]

    return renderExpression(allocator, stream, tree, rhs, space);
}

fn renderAsmOutput(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    asm_output: *const ast.Node.Asm.Output,
    space: Space,
) (@TypeOf(stream.*).Error || Error)!void {
    try stream.writer().writeAll("[");
    try renderExpression(allocator, stream, tree, asm_output.symbolic_name, Space.None);
    try stream.writer().writeAll("] ");
    try renderExpression(allocator, stream, tree, asm_output.constraint, Space.None);
    try stream.writer().writeAll(" (");

    switch (asm_output.kind) {
        ast.Node.Asm.Output.Kind.Variable => |variable_name| {
            try renderExpression(allocator, stream, tree, &variable_name.base, Space.None);
        },
        ast.Node.Asm.Output.Kind.Return => |return_type| {
            try stream.writer().writeAll("-> ");
            try renderExpression(allocator, stream, tree, return_type, Space.None);
        },
    }

    return renderToken(tree, stream, asm_output.lastToken(), space); // )
}

fn renderAsmInput(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    asm_input: *const ast.Node.Asm.Input,
    space: Space,
) (@TypeOf(stream.*).Error || Error)!void {
    try stream.writer().writeAll("[");
    try renderExpression(allocator, stream, tree, asm_input.symbolic_name, Space.None);
    try stream.writer().writeAll("] ");
    try renderExpression(allocator, stream, tree, asm_input.constraint, Space.None);
    try stream.writer().writeAll(" (");
    try renderExpression(allocator, stream, tree, asm_input.expr, Space.None);
    return renderToken(tree, stream, asm_input.lastToken(), space); // )
}

fn renderVarDecl(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    var_decl: *ast.Node.VarDecl,
) (@TypeOf(stream.*).Error || Error)!void {
    if (var_decl.getVisibToken()) |visib_token| {
        try renderToken(tree, stream, visib_token, Space.Space); // pub
    }

    if (var_decl.getExternExportToken()) |extern_export_token| {
        try renderToken(tree, stream, extern_export_token, Space.Space); // extern

        if (var_decl.getLibName()) |lib_name| {
            try renderExpression(allocator, stream, tree, lib_name, Space.Space); // "lib"
        }
    }

    if (var_decl.getComptimeToken()) |comptime_token| {
        try renderToken(tree, stream, comptime_token, Space.Space); // comptime
    }

    if (var_decl.getThreadLocalToken()) |thread_local_token| {
        try renderToken(tree, stream, thread_local_token, Space.Space); // threadlocal
    }
    try renderToken(tree, stream, var_decl.mut_token, Space.Space); // var

    const name_space = if (var_decl.getTypeNode() == null and
        (var_decl.getAlignNode() != null or
        var_decl.getSectionNode() != null or
        var_decl.getInitNode() != null))
        Space.Space
    else
        Space.None;
    try renderToken(tree, stream, var_decl.name_token, name_space);

    if (var_decl.getTrailer("type_node")) |type_node| {
        try renderToken(tree, stream, tree.nextToken(var_decl.name_token), Space.Space);
        const s = if (var_decl.getTrailer("align_node") != null or
            var_decl.getTrailer("section_node") != null or
            var_decl.getTrailer("init_node") != null) Space.Space else Space.None;
        try renderExpression(allocator, stream, tree, type_node, s);
    }

    if (var_decl.getAlignNode()) |align_node| {
        const lparen = tree.prevToken(align_node.firstToken());
        const align_kw = tree.prevToken(lparen);
        const rparen = tree.nextToken(align_node.lastToken());
        try renderToken(tree, stream, align_kw, Space.None); // align
        try renderToken(tree, stream, lparen, Space.None); // (
        try renderExpression(allocator, stream, tree, align_node, Space.None);
        const s = if (var_decl.getSectionNode() != null or var_decl.getInitNode() != null) Space.Space else Space.None;
        try renderToken(tree, stream, rparen, s); // )
    }

    if (var_decl.getSectionNode()) |section_node| {
        const lparen = tree.prevToken(section_node.firstToken());
        const section_kw = tree.prevToken(lparen);
        const rparen = tree.nextToken(section_node.lastToken());
        try renderToken(tree, stream, section_kw, Space.None); // linksection
        try renderToken(tree, stream, lparen, Space.None); // (
        try renderExpression(allocator, stream, tree, section_node, Space.None);
        const s = if (var_decl.getInitNode() != null) Space.Space else Space.None;
        try renderToken(tree, stream, rparen, s); // )
    }

    if (var_decl.getInitNode()) |init_node| {
        const s = if (init_node.tag == .MultilineStringLiteral) Space.None else Space.Space;
        try renderToken(tree, stream, var_decl.getEqToken().?, s); // =
        stream.pushIndentOneShot();
        try renderExpression(allocator, stream, tree, init_node, Space.None);
    }

    try renderToken(tree, stream, var_decl.semicolon_token, Space.Newline);
}

fn renderParamDecl(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    param_decl: ast.Node.FnProto.ParamDecl,
    space: Space,
) (@TypeOf(stream.*).Error || Error)!void {
    try renderDocComments(tree, stream, param_decl, param_decl.doc_comments);

    if (param_decl.comptime_token) |comptime_token| {
        try renderToken(tree, stream, comptime_token, Space.Space);
    }
    if (param_decl.noalias_token) |noalias_token| {
        try renderToken(tree, stream, noalias_token, Space.Space);
    }
    if (param_decl.name_token) |name_token| {
        try renderToken(tree, stream, name_token, Space.None);
        try renderToken(tree, stream, tree.nextToken(name_token), Space.Space); // :
    }
    switch (param_decl.param_type) {
        .any_type, .type_expr => |node| try renderExpression(allocator, stream, tree, node, space),
    }
}

fn renderStatement(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    base: *ast.Node,
) (@TypeOf(stream.*).Error || Error)!void {
    switch (base.tag) {
        .VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", base);
            try renderVarDecl(allocator, stream, tree, var_decl);
        },
        else => {
            if (base.requireSemiColon()) {
                try renderExpression(allocator, stream, tree, base, Space.None);

                const semicolon_index = tree.nextToken(base.lastToken());
                assert(tree.token_ids[semicolon_index] == .Semicolon);
                try renderToken(tree, stream, semicolon_index, Space.Newline);
            } else {
                try renderExpression(allocator, stream, tree, base, Space.Newline);
            }
        },
    }
}

const Space = enum {
    None,
    Newline,
    Comma,
    Space,
    SpaceOrOutdent,
    NoNewline,
    NoComment,
    BlockStart,
};

fn renderTokenOffset(
    tree: *ast.Tree,
    stream: anytype,
    token_index: ast.TokenIndex,
    space: Space,
    token_skip_bytes: usize,
) (@TypeOf(stream.*).Error || Error)!void {
    if (space == Space.BlockStart) {
        // If placing the lbrace on the current line would cause an uggly gap then put the lbrace on the next line
        const new_space = if (stream.isLineOverIndented()) Space.Newline else Space.Space;
        return renderToken(tree, stream, token_index, new_space);
    }

    var token_loc = tree.token_locs[token_index];
    try stream.writer().writeAll(mem.trimRight(u8, tree.tokenSliceLoc(token_loc)[token_skip_bytes..], " "));

    if (space == Space.NoComment)
        return;

    var next_token_id = tree.token_ids[token_index + 1];
    var next_token_loc = tree.token_locs[token_index + 1];

    if (space == Space.Comma) switch (next_token_id) {
        .Comma => return renderToken(tree, stream, token_index + 1, Space.Newline),
        .LineComment => {
            try stream.writer().writeAll(", ");
            return renderToken(tree, stream, token_index + 1, Space.Newline);
        },
        else => {
            if (token_index + 2 < tree.token_ids.len and
                tree.token_ids[token_index + 2] == .MultilineStringLiteralLine)
            {
                try stream.writer().writeAll(",");
                return;
            } else {
                try stream.writer().writeAll(",");
                try stream.insertNewline();
                return;
            }
        },
    };

    // Skip over same line doc comments
    var offset: usize = 1;
    if (next_token_id == .DocComment) {
        const loc = tree.tokenLocationLoc(token_loc.end, next_token_loc);
        if (loc.line == 0) {
            offset += 1;
            next_token_id = tree.token_ids[token_index + offset];
            next_token_loc = tree.token_locs[token_index + offset];
        }
    }

    if (next_token_id != .LineComment) {
        switch (space) {
            Space.None, Space.NoNewline => return,
            Space.Newline => {
                if (next_token_id == .MultilineStringLiteralLine) {
                    return;
                } else {
                    try stream.insertNewline();
                    return;
                }
            },
            Space.Space, Space.SpaceOrOutdent => {
                if (next_token_id == .MultilineStringLiteralLine)
                    return;
                try stream.writer().writeByte(' ');
                return;
            },
            Space.NoComment, Space.Comma, Space.BlockStart => unreachable,
        }
    }

    while (true) {
        const comment_is_empty = mem.trimRight(u8, tree.tokenSliceLoc(next_token_loc), " ").len == 2;
        if (comment_is_empty) {
            switch (space) {
                Space.Newline => {
                    offset += 1;
                    token_loc = next_token_loc;
                    next_token_id = tree.token_ids[token_index + offset];
                    next_token_loc = tree.token_locs[token_index + offset];
                    if (next_token_id != .LineComment) {
                        try stream.insertNewline();
                        return;
                    }
                },
                else => break,
            }
        } else {
            break;
        }
    }

    var loc = tree.tokenLocationLoc(token_loc.end, next_token_loc);
    if (loc.line == 0) {
        try stream.writer().print(" {}", .{mem.trimRight(u8, tree.tokenSliceLoc(next_token_loc), " ")});
        offset = 2;
        token_loc = next_token_loc;
        next_token_loc = tree.token_locs[token_index + offset];
        next_token_id = tree.token_ids[token_index + offset];
        if (next_token_id != .LineComment) {
            switch (space) {
                Space.None, Space.Space => {
                    try stream.insertNewline();
                },
                Space.SpaceOrOutdent => {
                    try stream.insertNewline();
                },
                Space.Newline => {
                    if (next_token_id == .MultilineStringLiteralLine) {
                        return;
                    } else {
                        try stream.insertNewline();
                        return;
                    }
                },
                Space.NoNewline => {},
                Space.NoComment, Space.Comma, Space.BlockStart => unreachable,
            }
            return;
        }
        loc = tree.tokenLocationLoc(token_loc.end, next_token_loc);
    }

    while (true) {
        // translate-c doesn't generate correct newlines
        // in generated code (loc.line == 0) so treat that case
        // as though there was meant to be a newline between the tokens
        var newline_count = if (loc.line <= 1) @as(u8, 1) else @as(u8, 2);
        while (newline_count > 0) : (newline_count -= 1) try stream.insertNewline();
        try stream.writer().writeAll(mem.trimRight(u8, tree.tokenSliceLoc(next_token_loc), " "));

        offset += 1;
        token_loc = next_token_loc;
        next_token_loc = tree.token_locs[token_index + offset];
        next_token_id = tree.token_ids[token_index + offset];
        if (next_token_id != .LineComment) {
            switch (space) {
                Space.Newline => {
                    if (next_token_id == .MultilineStringLiteralLine) {
                        return;
                    } else {
                        try stream.insertNewline();
                        return;
                    }
                },
                Space.None, Space.Space => {
                    try stream.insertNewline();
                },
                Space.SpaceOrOutdent => {
                    try stream.insertNewline();
                },
                Space.NoNewline => {},
                Space.NoComment, Space.Comma, Space.BlockStart => unreachable,
            }
            return;
        }
        loc = tree.tokenLocationLoc(token_loc.end, next_token_loc);
    }
}

fn renderToken(
    tree: *ast.Tree,
    stream: anytype,
    token_index: ast.TokenIndex,
    space: Space,
) (@TypeOf(stream.*).Error || Error)!void {
    return renderTokenOffset(tree, stream, token_index, space, 0);
}

fn renderDocComments(
    tree: *ast.Tree,
    stream: anytype,
    node: anytype,
    doc_comments: ?*ast.Node.DocComment,
) (@TypeOf(stream.*).Error || Error)!void {
    const comment = doc_comments orelse return;
    return renderDocCommentsToken(tree, stream, comment, node.firstToken());
}

fn renderDocCommentsToken(
    tree: *ast.Tree,
    stream: anytype,
    comment: *ast.Node.DocComment,
    first_token: ast.TokenIndex,
) (@TypeOf(stream.*).Error || Error)!void {
    var tok_i = comment.first_line;
    while (true) : (tok_i += 1) {
        switch (tree.token_ids[tok_i]) {
            .DocComment, .ContainerDocComment => {
                if (comment.first_line < first_token) {
                    try renderToken(tree, stream, tok_i, Space.Newline);
                } else {
                    try renderToken(tree, stream, tok_i, Space.NoComment);
                    try stream.insertNewline();
                }
            },
            .LineComment => continue,
            else => break,
        }
    }
}

fn nodeIsBlock(base: *const ast.Node) bool {
    return switch (base.tag) {
        .Block,
        .LabeledBlock,
        .If,
        .For,
        .While,
        .Switch,
        => true,
        else => false,
    };
}

fn nodeCausesSliceOpSpace(base: *ast.Node) bool {
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

fn copyFixingWhitespace(stream: anytype, slice: []const u8) @TypeOf(stream.*).Error!void {
    for (slice) |byte| switch (byte) {
        '\t' => try stream.writer().writeAll("    "),
        '\r' => {},
        else => try stream.writer().writeByte(byte),
    };
}
