const std = @import("../index.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const ast = std.zig.ast;
const Token = std.zig.Token;

const indent_delta = 4;

pub const Error = error{
    /// Ran out of memory allocating call stack frames to complete rendering.
    OutOfMemory,
};

/// Returns whether anything changed
pub fn render(allocator: *mem.Allocator, stream: var, tree: *ast.Tree) (@typeOf(stream).Child.Error || Error)!bool {
    comptime assert(@typeId(@typeOf(stream)) == builtin.TypeId.Pointer);

    var anything_changed: bool = false;

    // make a passthrough stream that checks whether something changed
    const MyStream = struct {
        const MyStream = this;
        const StreamError = @typeOf(stream).Child.Error;
        const Stream = std.io.OutStream(StreamError);

        anything_changed_ptr: *bool,
        child_stream: @typeOf(stream),
        stream: Stream,
        source_index: usize,
        source: []const u8,

        fn write(iface_stream: *Stream, bytes: []const u8) StreamError!void {
            const self = @fieldParentPtr(MyStream, "stream", iface_stream);

            if (!self.anything_changed_ptr.*) {
                const end = self.source_index + bytes.len;
                if (end > self.source.len) {
                    self.anything_changed_ptr.* = true;
                } else {
                    const src_slice = self.source[self.source_index..end];
                    self.source_index += bytes.len;
                    if (!mem.eql(u8, bytes, src_slice)) {
                        self.anything_changed_ptr.* = true;
                    }
                }
            }

            try self.child_stream.write(bytes);
        }
    };
    var my_stream = MyStream{
        .stream = MyStream.Stream{ .writeFn = MyStream.write },
        .child_stream = stream,
        .anything_changed_ptr = &anything_changed,
        .source_index = 0,
        .source = tree.source,
    };

    try renderRoot(allocator, &my_stream.stream, tree);

    return anything_changed;
}

fn renderRoot(
    allocator: *mem.Allocator,
    stream: var,
    tree: *ast.Tree,
) (@typeOf(stream).Child.Error || Error)!void {
    // render all the line comments at the beginning of the file
    var tok_it = tree.tokens.iterator(0);
    while (tok_it.next()) |token| {
        if (token.id != Token.Id.LineComment) break;
        try stream.print("{}\n", mem.trimRight(u8, tree.tokenSlicePtr(token), " "));
        if (tok_it.peek()) |next_token| {
            const loc = tree.tokenLocationPtr(token.end, next_token);
            if (loc.line >= 2) {
                try stream.writeByte('\n');
            }
        }
    }

    var start_col: usize = 0;
    var it = tree.root_node.decls.iterator(0);
    while (true) {
        var decl = (it.next() orelse return).*;
        // look for zig fmt: off comment
        var start_token_index = decl.firstToken();
        zig_fmt_loop: while (start_token_index != 0) {
            start_token_index -= 1;
            const start_token = tree.tokens.at(start_token_index);
            switch (start_token.id) {
                Token.Id.LineComment => {},
                Token.Id.DocComment => continue,
                else => break,
            }
            if (mem.eql(u8, mem.trim(u8, tree.tokenSlicePtr(start_token)[2..], " "), "zig fmt: off")) {
                var end_token_index = start_token_index;
                while (true) {
                    end_token_index += 1;
                    const end_token = tree.tokens.at(end_token_index);
                    switch (end_token.id) {
                        Token.Id.LineComment => {},
                        Token.Id.Eof => {
                            const start = tree.tokens.at(start_token_index + 1).start;
                            try stream.write(tree.source[start..]);
                            return;
                        },
                        else => continue,
                    }
                    if (mem.eql(u8, mem.trim(u8, tree.tokenSlicePtr(end_token)[2..], " "), "zig fmt: on")) {
                        const start = tree.tokens.at(start_token_index + 1).start;
                        try stream.print("{}\n", tree.source[start..end_token.end]);
                        while (tree.tokens.at(decl.firstToken()).start < end_token.end) {
                            decl = (it.next() orelse return).*;
                        }
                        break :zig_fmt_loop;
                    }
                }
            }
        }

        try renderTopLevelDecl(allocator, stream, tree, 0, &start_col, decl);
        if (it.peek()) |next_decl| {
            try renderExtraNewline(tree, stream, &start_col, next_decl.*);
        }
    }
}

fn renderExtraNewline(tree: *ast.Tree, stream: var, start_col: *usize, node: *ast.Node) !void {
    const first_token = node.firstToken();
    var prev_token = first_token;
    while (tree.tokens.at(prev_token - 1).id == Token.Id.DocComment) {
        prev_token -= 1;
    }
    const prev_token_end = tree.tokens.at(prev_token - 1).end;
    const loc = tree.tokenLocation(prev_token_end, first_token);
    if (loc.line >= 2) {
        try stream.writeByte('\n');
        start_col.* = 0;
    }
}

fn renderTopLevelDecl(allocator: *mem.Allocator, stream: var, tree: *ast.Tree, indent: usize, start_col: *usize, decl: *ast.Node) (@typeOf(stream).Child.Error || Error)!void {
    switch (decl.id) {
        ast.Node.Id.FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", decl);

            try renderDocComments(tree, stream, fn_proto, indent, start_col);

            if (fn_proto.body_node) |body_node| {
                try renderExpression(allocator, stream, tree, indent, start_col, decl, Space.Space);
                try renderExpression(allocator, stream, tree, indent, start_col, body_node, Space.Newline);
            } else {
                try renderExpression(allocator, stream, tree, indent, start_col, decl, Space.None);
                try renderToken(tree, stream, tree.nextToken(decl.lastToken()), indent, start_col, Space.Newline);
            }
        },

        ast.Node.Id.Use => {
            const use_decl = @fieldParentPtr(ast.Node.Use, "base", decl);

            if (use_decl.visib_token) |visib_token| {
                try renderToken(tree, stream, visib_token, indent, start_col, Space.Space); // pub
            }
            try renderToken(tree, stream, use_decl.use_token, indent, start_col, Space.Space); // use
            try renderExpression(allocator, stream, tree, indent, start_col, use_decl.expr, Space.None);
            try renderToken(tree, stream, use_decl.semicolon_token, indent, start_col, Space.Newline); // ;
        },

        ast.Node.Id.VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", decl);

            try renderDocComments(tree, stream, var_decl, indent, start_col);
            try renderVarDecl(allocator, stream, tree, indent, start_col, var_decl);
        },

        ast.Node.Id.TestDecl => {
            const test_decl = @fieldParentPtr(ast.Node.TestDecl, "base", decl);

            try renderDocComments(tree, stream, test_decl, indent, start_col);
            try renderToken(tree, stream, test_decl.test_token, indent, start_col, Space.Space);
            try renderExpression(allocator, stream, tree, indent, start_col, test_decl.name, Space.Space);
            try renderExpression(allocator, stream, tree, indent, start_col, test_decl.body_node, Space.Newline);
        },

        ast.Node.Id.StructField => {
            const field = @fieldParentPtr(ast.Node.StructField, "base", decl);

            try renderDocComments(tree, stream, field, indent, start_col);
            if (field.visib_token) |visib_token| {
                try renderToken(tree, stream, visib_token, indent, start_col, Space.Space); // pub
            }
            try renderToken(tree, stream, field.name_token, indent, start_col, Space.None); // name
            try renderToken(tree, stream, tree.nextToken(field.name_token), indent, start_col, Space.Space); // :
            try renderExpression(allocator, stream, tree, indent, start_col, field.type_expr, Space.Comma); // type,
        },

        ast.Node.Id.UnionTag => {
            const tag = @fieldParentPtr(ast.Node.UnionTag, "base", decl);

            try renderDocComments(tree, stream, tag, indent, start_col);

            if (tag.type_expr == null and tag.value_expr == null) {
                return renderToken(tree, stream, tag.name_token, indent, start_col, Space.Comma); // name,
            }

            if (tag.type_expr == null) {
                try renderToken(tree, stream, tag.name_token, indent, start_col, Space.Space); // name
            } else {
                try renderToken(tree, stream, tag.name_token, indent, start_col, Space.None); // name
            }

            if (tag.type_expr) |type_expr| {
                try renderToken(tree, stream, tree.nextToken(tag.name_token), indent, start_col, Space.Space); // :

                if (tag.value_expr == null) {
                    try renderExpression(allocator, stream, tree, indent, start_col, type_expr, Space.Comma); // type,
                    return;
                } else {
                    try renderExpression(allocator, stream, tree, indent, start_col, type_expr, Space.Space); // type
                }
            }

            const value_expr = tag.value_expr.?;
            try renderToken(tree, stream, tree.prevToken(value_expr.firstToken()), indent, start_col, Space.Space); // =
            try renderExpression(allocator, stream, tree, indent, start_col, value_expr, Space.Comma); // value,
        },

        ast.Node.Id.EnumTag => {
            const tag = @fieldParentPtr(ast.Node.EnumTag, "base", decl);

            try renderDocComments(tree, stream, tag, indent, start_col);

            if (tag.value) |value| {
                try renderToken(tree, stream, tag.name_token, indent, start_col, Space.Space); // name

                try renderToken(tree, stream, tree.nextToken(tag.name_token), indent, start_col, Space.Space); // =
                try renderExpression(allocator, stream, tree, indent, start_col, value, Space.Comma);
            } else {
                try renderToken(tree, stream, tag.name_token, indent, start_col, Space.Comma); // name
            }
        },

        ast.Node.Id.Comptime => {
            assert(!decl.requireSemiColon());
            try renderExpression(allocator, stream, tree, indent, start_col, decl, Space.Newline);
        },
        else => unreachable,
    }
}

fn renderExpression(
    allocator: *mem.Allocator,
    stream: var,
    tree: *ast.Tree,
    indent: usize,
    start_col: *usize,
    base: *ast.Node,
    space: Space,
) (@typeOf(stream).Child.Error || Error)!void {
    switch (base.id) {
        ast.Node.Id.Identifier => {
            const identifier = @fieldParentPtr(ast.Node.Identifier, "base", base);
            return renderToken(tree, stream, identifier.token, indent, start_col, space);
        },
        ast.Node.Id.Block => {
            const block = @fieldParentPtr(ast.Node.Block, "base", base);

            if (block.label) |label| {
                try renderToken(tree, stream, label, indent, start_col, Space.None);
                try renderToken(tree, stream, tree.nextToken(label), indent, start_col, Space.Space);
            }

            if (block.statements.len == 0) {
                try renderToken(tree, stream, block.lbrace, indent + indent_delta, start_col, Space.None);
                return renderToken(tree, stream, block.rbrace, indent, start_col, space);
            } else {
                const block_indent = indent + indent_delta;
                try renderToken(tree, stream, block.lbrace, block_indent, start_col, Space.Newline);

                var it = block.statements.iterator(0);
                while (it.next()) |statement| {
                    try stream.writeByteNTimes(' ', block_indent);
                    try renderStatement(allocator, stream, tree, block_indent, start_col, statement.*);

                    if (it.peek()) |next_statement| {
                        try renderExtraNewline(tree, stream, start_col, next_statement.*);
                    }
                }

                try stream.writeByteNTimes(' ', indent);
                return renderToken(tree, stream, block.rbrace, indent, start_col, space);
            }
        },
        ast.Node.Id.Defer => {
            const defer_node = @fieldParentPtr(ast.Node.Defer, "base", base);

            try renderToken(tree, stream, defer_node.defer_token, indent, start_col, Space.Space);
            return renderExpression(allocator, stream, tree, indent, start_col, defer_node.expr, space);
        },
        ast.Node.Id.Comptime => {
            const comptime_node = @fieldParentPtr(ast.Node.Comptime, "base", base);

            try renderToken(tree, stream, comptime_node.comptime_token, indent, start_col, Space.Space);
            return renderExpression(allocator, stream, tree, indent, start_col, comptime_node.expr, space);
        },

        ast.Node.Id.AsyncAttribute => {
            const async_attr = @fieldParentPtr(ast.Node.AsyncAttribute, "base", base);

            if (async_attr.allocator_type) |allocator_type| {
                try renderToken(tree, stream, async_attr.async_token, indent, start_col, Space.None); // async

                try renderToken(tree, stream, tree.nextToken(async_attr.async_token), indent, start_col, Space.None); // <
                try renderExpression(allocator, stream, tree, indent, start_col, allocator_type, Space.None); // allocator
                return renderToken(tree, stream, tree.nextToken(allocator_type.lastToken()), indent, start_col, space); // >
            } else {
                return renderToken(tree, stream, async_attr.async_token, indent, start_col, space); // async
            }
        },

        ast.Node.Id.Suspend => {
            const suspend_node = @fieldParentPtr(ast.Node.Suspend, "base", base);

            if (suspend_node.label) |label| {
                try renderToken(tree, stream, label, indent, start_col, Space.None);
                try renderToken(tree, stream, tree.nextToken(label), indent, start_col, Space.Space);
            }

            if (suspend_node.payload) |payload| {
                if (suspend_node.body) |body| {
                    try renderToken(tree, stream, suspend_node.suspend_token, indent, start_col, Space.Space);
                    try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Space);
                    return renderExpression(allocator, stream, tree, indent, start_col, body, space);
                } else {
                    try renderToken(tree, stream, suspend_node.suspend_token, indent, start_col, Space.Space);
                    return renderExpression(allocator, stream, tree, indent, start_col, payload, space);
                }
            } else if (suspend_node.body) |body| {
                try renderToken(tree, stream, suspend_node.suspend_token, indent, start_col, Space.Space);
                return renderExpression(allocator, stream, tree, indent, start_col, body, space);
            } else {
                return renderToken(tree, stream, suspend_node.suspend_token, indent, start_col, space);
            }
        },

        ast.Node.Id.InfixOp => {
            const infix_op_node = @fieldParentPtr(ast.Node.InfixOp, "base", base);

            const op_token = tree.tokens.at(infix_op_node.op_token);
            const op_space = switch (infix_op_node.op) {
                ast.Node.InfixOp.Op.Period, ast.Node.InfixOp.Op.ErrorUnion, ast.Node.InfixOp.Op.Range => Space.None,
                else => Space.Space,
            };
            try renderExpression(allocator, stream, tree, indent, start_col, infix_op_node.lhs, op_space);

            const after_op_space = blk: {
                const loc = tree.tokenLocation(tree.tokens.at(infix_op_node.op_token).end, tree.nextToken(infix_op_node.op_token));
                break :blk if (loc.line == 0) op_space else Space.Newline;
            };

            try renderToken(tree, stream, infix_op_node.op_token, indent, start_col, after_op_space);
            if (after_op_space == Space.Newline) {
                try stream.writeByteNTimes(' ', indent + indent_delta);
                start_col.* = indent + indent_delta;
            }

            switch (infix_op_node.op) {
                ast.Node.InfixOp.Op.Catch => |maybe_payload| if (maybe_payload) |payload| {
                    try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Space);
                },
                else => {},
            }

            return renderExpression(allocator, stream, tree, indent, start_col, infix_op_node.rhs, space);
        },

        ast.Node.Id.PrefixOp => {
            const prefix_op_node = @fieldParentPtr(ast.Node.PrefixOp, "base", base);

            switch (prefix_op_node.op) {
                ast.Node.PrefixOp.Op.PtrType => |ptr_info| {
                    const star_offset = switch (tree.tokens.at(prefix_op_node.op_token).id) {
                        Token.Id.AsteriskAsterisk => usize(1),
                        else => usize(0),
                    };
                    try renderTokenOffset(tree, stream, prefix_op_node.op_token, indent, start_col, Space.None, star_offset); // *
                    if (ptr_info.align_info) |align_info| {
                        const lparen_token = tree.prevToken(align_info.node.firstToken());
                        const align_token = tree.prevToken(lparen_token);

                        try renderToken(tree, stream, align_token, indent, start_col, Space.None); // align
                        try renderToken(tree, stream, lparen_token, indent, start_col, Space.None); // (

                        try renderExpression(allocator, stream, tree, indent, start_col, align_info.node, Space.None);

                        if (align_info.bit_range) |bit_range| {
                            const colon1 = tree.prevToken(bit_range.start.firstToken());
                            const colon2 = tree.prevToken(bit_range.end.firstToken());

                            try renderToken(tree, stream, colon1, indent, start_col, Space.None); // :
                            try renderExpression(allocator, stream, tree, indent, start_col, bit_range.start, Space.None);
                            try renderToken(tree, stream, colon2, indent, start_col, Space.None); // :
                            try renderExpression(allocator, stream, tree, indent, start_col, bit_range.end, Space.None);

                            const rparen_token = tree.nextToken(bit_range.end.lastToken());
                            try renderToken(tree, stream, rparen_token, indent, start_col, Space.Space); // )
                        } else {
                            const rparen_token = tree.nextToken(align_info.node.lastToken());
                            try renderToken(tree, stream, rparen_token, indent, start_col, Space.Space); // )
                        }
                    }
                    if (ptr_info.const_token) |const_token| {
                        try renderToken(tree, stream, const_token, indent, start_col, Space.Space); // const
                    }
                    if (ptr_info.volatile_token) |volatile_token| {
                        try renderToken(tree, stream, volatile_token, indent, start_col, Space.Space); // volatile
                    }
                },

                ast.Node.PrefixOp.Op.SliceType => |ptr_info| {
                    try renderToken(tree, stream, prefix_op_node.op_token, indent, start_col, Space.None); // [
                    try renderToken(tree, stream, tree.nextToken(prefix_op_node.op_token), indent, start_col, Space.None); // ]

                    if (ptr_info.align_info) |align_info| {
                        const lparen_token = tree.prevToken(align_info.node.firstToken());
                        const align_token = tree.prevToken(lparen_token);

                        try renderToken(tree, stream, align_token, indent, start_col, Space.None); // align
                        try renderToken(tree, stream, lparen_token, indent, start_col, Space.None); // (

                        try renderExpression(allocator, stream, tree, indent, start_col, align_info.node, Space.None);

                        if (align_info.bit_range) |bit_range| {
                            const colon1 = tree.prevToken(bit_range.start.firstToken());
                            const colon2 = tree.prevToken(bit_range.end.firstToken());

                            try renderToken(tree, stream, colon1, indent, start_col, Space.None); // :
                            try renderExpression(allocator, stream, tree, indent, start_col, bit_range.start, Space.None);
                            try renderToken(tree, stream, colon2, indent, start_col, Space.None); // :
                            try renderExpression(allocator, stream, tree, indent, start_col, bit_range.end, Space.None);

                            const rparen_token = tree.nextToken(bit_range.end.lastToken());
                            try renderToken(tree, stream, rparen_token, indent, start_col, Space.Space); // )
                        } else {
                            const rparen_token = tree.nextToken(align_info.node.lastToken());
                            try renderToken(tree, stream, rparen_token, indent, start_col, Space.Space); // )
                        }
                    }
                    if (ptr_info.const_token) |const_token| {
                        try renderToken(tree, stream, const_token, indent, start_col, Space.Space);
                    }
                    if (ptr_info.volatile_token) |volatile_token| {
                        try renderToken(tree, stream, volatile_token, indent, start_col, Space.Space);
                    }
                },

                ast.Node.PrefixOp.Op.ArrayType => |array_index| {
                    try renderToken(tree, stream, prefix_op_node.op_token, indent, start_col, Space.None); // [
                    try renderExpression(allocator, stream, tree, indent, start_col, array_index, Space.None);
                    try renderToken(tree, stream, tree.nextToken(array_index.lastToken()), indent, start_col, Space.None); // ]
                },
                ast.Node.PrefixOp.Op.BitNot,
                ast.Node.PrefixOp.Op.BoolNot,
                ast.Node.PrefixOp.Op.Negation,
                ast.Node.PrefixOp.Op.NegationWrap,
                ast.Node.PrefixOp.Op.OptionalType,
                ast.Node.PrefixOp.Op.AddressOf,
                => {
                    try renderToken(tree, stream, prefix_op_node.op_token, indent, start_col, Space.None);
                },

                ast.Node.PrefixOp.Op.Try,
                ast.Node.PrefixOp.Op.Await,
                ast.Node.PrefixOp.Op.Cancel,
                ast.Node.PrefixOp.Op.Resume,
                => {
                    try renderToken(tree, stream, prefix_op_node.op_token, indent, start_col, Space.Space);
                },
            }

            return renderExpression(allocator, stream, tree, indent, start_col, prefix_op_node.rhs, space);
        },

        ast.Node.Id.SuffixOp => {
            const suffix_op = @fieldParentPtr(ast.Node.SuffixOp, "base", base);

            switch (suffix_op.op) {
                @TagType(ast.Node.SuffixOp.Op).Call => |*call_info| {
                    if (call_info.async_attr) |async_attr| {
                        try renderExpression(allocator, stream, tree, indent, start_col, &async_attr.base, Space.Space);
                    }

                    try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);

                    const lparen = tree.nextToken(suffix_op.lhs.lastToken());

                    if (call_info.params.len == 0) {
                        try renderToken(tree, stream, lparen, indent, start_col, Space.None);
                        return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space);
                    }

                    const src_has_trailing_comma = blk: {
                        const maybe_comma = tree.prevToken(suffix_op.rtoken);
                        break :blk tree.tokens.at(maybe_comma).id == Token.Id.Comma;
                    };

                    if (src_has_trailing_comma) {
                        const new_indent = indent + indent_delta;
                        try renderToken(tree, stream, lparen, new_indent, start_col, Space.Newline);

                        var it = call_info.params.iterator(0);
                        while (true) {
                            const param_node = it.next().?;

                            const param_node_new_indent = if (param_node.*.id == ast.Node.Id.MultilineStringLiteral) blk: {
                                break :blk indent;
                            } else blk: {
                                try stream.writeByteNTimes(' ', new_indent);
                                break :blk new_indent;
                            };

                            if (it.peek()) |next_node| {
                                try renderExpression(allocator, stream, tree, param_node_new_indent, start_col, param_node.*, Space.None);
                                const comma = tree.nextToken(param_node.*.lastToken());
                                try renderToken(tree, stream, comma, new_indent, start_col, Space.Newline); // ,
                                try renderExtraNewline(tree, stream, start_col, next_node.*);
                            } else {
                                try renderExpression(allocator, stream, tree, param_node_new_indent, start_col, param_node.*, Space.Comma);
                                try stream.writeByteNTimes(' ', indent);
                                return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space);
                            }
                        }
                    }

                    try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (

                    var it = call_info.params.iterator(0);
                    while (it.next()) |param_node| {
                        try renderExpression(allocator, stream, tree, indent, start_col, param_node.*, Space.None);

                        if (it.peek() != null) {
                            const comma = tree.nextToken(param_node.*.lastToken());
                            try renderToken(tree, stream, comma, indent, start_col, Space.Space);
                        }
                    }
                    return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space);
                },

                ast.Node.SuffixOp.Op.ArrayAccess => |index_expr| {
                    const lbracket = tree.prevToken(index_expr.firstToken());
                    const rbracket = tree.nextToken(index_expr.lastToken());

                    try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);
                    try renderToken(tree, stream, lbracket, indent, start_col, Space.None); // [
                    try renderExpression(allocator, stream, tree, indent, start_col, index_expr, Space.None);
                    return renderToken(tree, stream, rbracket, indent, start_col, space); // ]
                },

                ast.Node.SuffixOp.Op.Deref, ast.Node.SuffixOp.Op.UnwrapOptional => {
                    try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);
                    try renderToken(tree, stream, tree.prevToken(suffix_op.rtoken), indent, start_col, Space.None); // .
                    return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space); // * or ?
                },

                @TagType(ast.Node.SuffixOp.Op).Slice => |range| {
                    try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);

                    const lbracket = tree.prevToken(range.start.firstToken());
                    const dotdot = tree.nextToken(range.start.lastToken());

                    const after_start_space_bool = nodeCausesSliceOpSpace(range.start) or
                        (if (range.end) |end| nodeCausesSliceOpSpace(end) else false);
                    const after_start_space = if (after_start_space_bool) Space.Space else Space.None;
                    const after_op_space = if (range.end != null) after_start_space else Space.None;

                    try renderToken(tree, stream, lbracket, indent, start_col, Space.None); // [
                    try renderExpression(allocator, stream, tree, indent, start_col, range.start, after_start_space);
                    try renderToken(tree, stream, dotdot, indent, start_col, after_op_space); // ..
                    if (range.end) |end| {
                        try renderExpression(allocator, stream, tree, indent, start_col, end, Space.None);
                    }
                    return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space); // ]
                },

                ast.Node.SuffixOp.Op.StructInitializer => |*field_inits| {
                    const lbrace = tree.nextToken(suffix_op.lhs.lastToken());

                    if (field_inits.len == 0) {
                        try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);
                        try renderToken(tree, stream, lbrace, indent, start_col, Space.None);
                        return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space);
                    }

                    if (field_inits.len == 1) blk: {
                        const field_init = field_inits.at(0).*.cast(ast.Node.FieldInitializer).?;

                        if (field_init.expr.cast(ast.Node.SuffixOp)) |nested_suffix_op| {
                            if (nested_suffix_op.op == ast.Node.SuffixOp.Op.StructInitializer) {
                                break :blk;
                            }
                        }

                        try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);
                        try renderToken(tree, stream, lbrace, indent, start_col, Space.Space);
                        try renderExpression(allocator, stream, tree, indent, start_col, &field_init.base, Space.Space);
                        return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space);
                    }

                    const src_has_trailing_comma = blk: {
                        const maybe_comma = tree.prevToken(suffix_op.rtoken);
                        break :blk tree.tokens.at(maybe_comma).id == Token.Id.Comma;
                    };

                    const src_same_line = blk: {
                        const loc = tree.tokenLocation(tree.tokens.at(lbrace).end, suffix_op.rtoken);
                        break :blk loc.line == 0;
                    };

                    if (!src_has_trailing_comma and src_same_line) {
                        // render all on one line, no trailing comma
                        try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);
                        try renderToken(tree, stream, lbrace, indent, start_col, Space.Space);

                        var it = field_inits.iterator(0);
                        while (it.next()) |field_init| {
                            if (it.peek() != null) {
                                try renderExpression(allocator, stream, tree, indent, start_col, field_init.*, Space.None);

                                const comma = tree.nextToken(field_init.*.lastToken());
                                try renderToken(tree, stream, comma, indent, start_col, Space.Space);
                            } else {
                                try renderExpression(allocator, stream, tree, indent, start_col, field_init.*, Space.Space);
                            }
                        }

                        return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space);
                    }

                    try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);
                    try renderToken(tree, stream, lbrace, indent, start_col, Space.Newline);

                    const new_indent = indent + indent_delta;

                    var it = field_inits.iterator(0);
                    while (it.next()) |field_init| {
                        try stream.writeByteNTimes(' ', new_indent);

                        if (it.peek()) |next_field_init| {
                            try renderExpression(allocator, stream, tree, new_indent, start_col, field_init.*, Space.None);

                            const comma = tree.nextToken(field_init.*.lastToken());
                            try renderToken(tree, stream, comma, new_indent, start_col, Space.Newline);

                            try renderExtraNewline(tree, stream, start_col, next_field_init.*);
                        } else {
                            try renderExpression(allocator, stream, tree, new_indent, start_col, field_init.*, Space.Comma);
                        }
                    }

                    try stream.writeByteNTimes(' ', indent);
                    return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space);
                },

                ast.Node.SuffixOp.Op.ArrayInitializer => |*exprs| {
                    const lbrace = tree.nextToken(suffix_op.lhs.lastToken());

                    if (exprs.len == 0) {
                        try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);
                        try renderToken(tree, stream, lbrace, indent, start_col, Space.None);
                        return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space);
                    }
                    if (exprs.len == 1) {
                        const expr = exprs.at(0).*;

                        try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);
                        try renderToken(tree, stream, lbrace, indent, start_col, Space.None);
                        try renderExpression(allocator, stream, tree, indent, start_col, expr, Space.None);
                        return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space);
                    }

                    try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);

                    // scan to find row size
                    const maybe_row_size: ?usize = blk: {
                        var count: usize = 1;
                        var it = exprs.iterator(0);
                        while (true) {
                            const expr = it.next().?.*;
                            if (it.peek()) |next_expr| {
                                const expr_last_token = expr.*.lastToken() + 1;
                                const loc = tree.tokenLocation(tree.tokens.at(expr_last_token).end, next_expr.*.firstToken());
                                if (loc.line != 0) break :blk count;
                                count += 1;
                            } else {
                                const expr_last_token = expr.*.lastToken();
                                const loc = tree.tokenLocation(tree.tokens.at(expr_last_token).end, suffix_op.rtoken);
                                if (loc.line == 0) {
                                    // all on one line
                                    const src_has_trailing_comma = trailblk: {
                                        const maybe_comma = tree.prevToken(suffix_op.rtoken);
                                        break :trailblk tree.tokens.at(maybe_comma).id == Token.Id.Comma;
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
                    };

                    if (maybe_row_size) |row_size| {
                        const new_indent = indent + indent_delta;
                        try renderToken(tree, stream, lbrace, new_indent, start_col, Space.Newline);
                        try stream.writeByteNTimes(' ', new_indent);

                        var it = exprs.iterator(0);
                        var i: usize = 1;
                        while (it.next()) |expr| {
                            if (it.peek()) |next_expr| {
                                try renderExpression(allocator, stream, tree, new_indent, start_col, expr.*, Space.None);

                                const comma = tree.nextToken(expr.*.lastToken());

                                if (i != row_size) {
                                    try renderToken(tree, stream, comma, new_indent, start_col, Space.Space); // ,
                                    i += 1;
                                    continue;
                                }
                                i = 1;

                                try renderToken(tree, stream, comma, new_indent, start_col, Space.Newline); // ,

                                try renderExtraNewline(tree, stream, start_col, next_expr.*);
                                try stream.writeByteNTimes(' ', new_indent);
                            } else {
                                try renderExpression(allocator, stream, tree, new_indent, start_col, expr.*, Space.Comma); // ,
                            }
                        }
                        try stream.writeByteNTimes(' ', indent);
                        return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space);
                    } else {
                        try renderToken(tree, stream, lbrace, indent, start_col, Space.Space);
                        var it = exprs.iterator(0);
                        while (it.next()) |expr| {
                            if (it.peek()) |next_expr| {
                                try renderExpression(allocator, stream, tree, indent, start_col, expr.*, Space.None);
                                const comma = tree.nextToken(expr.*.lastToken());
                                try renderToken(tree, stream, comma, indent, start_col, Space.Space); // ,
                            } else {
                                try renderExpression(allocator, stream, tree, indent, start_col, expr.*, Space.Space);
                            }
                        }

                        return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space);
                    }
                },
            }
        },

        ast.Node.Id.ControlFlowExpression => {
            const flow_expr = @fieldParentPtr(ast.Node.ControlFlowExpression, "base", base);

            switch (flow_expr.kind) {
                ast.Node.ControlFlowExpression.Kind.Break => |maybe_label| {
                    if (maybe_label == null and flow_expr.rhs == null) {
                        return renderToken(tree, stream, flow_expr.ltoken, indent, start_col, space); // break
                    }

                    try renderToken(tree, stream, flow_expr.ltoken, indent, start_col, Space.Space); // break
                    if (maybe_label) |label| {
                        const colon = tree.nextToken(flow_expr.ltoken);
                        try renderToken(tree, stream, colon, indent, start_col, Space.None); // :

                        if (flow_expr.rhs == null) {
                            return renderExpression(allocator, stream, tree, indent, start_col, label, space); // label
                        }
                        try renderExpression(allocator, stream, tree, indent, start_col, label, Space.Space); // label
                    }
                },
                ast.Node.ControlFlowExpression.Kind.Continue => |maybe_label| {
                    assert(flow_expr.rhs == null);

                    if (maybe_label == null and flow_expr.rhs == null) {
                        return renderToken(tree, stream, flow_expr.ltoken, indent, start_col, space); // continue
                    }

                    try renderToken(tree, stream, flow_expr.ltoken, indent, start_col, Space.Space); // continue
                    if (maybe_label) |label| {
                        const colon = tree.nextToken(flow_expr.ltoken);
                        try renderToken(tree, stream, colon, indent, start_col, Space.None); // :

                        return renderExpression(allocator, stream, tree, indent, start_col, label, space);
                    }
                },
                ast.Node.ControlFlowExpression.Kind.Return => {
                    if (flow_expr.rhs == null) {
                        return renderToken(tree, stream, flow_expr.ltoken, indent, start_col, space);
                    }
                    try renderToken(tree, stream, flow_expr.ltoken, indent, start_col, Space.Space);
                },
            }

            return renderExpression(allocator, stream, tree, indent, start_col, flow_expr.rhs.?, space);
        },

        ast.Node.Id.Payload => {
            const payload = @fieldParentPtr(ast.Node.Payload, "base", base);

            try renderToken(tree, stream, payload.lpipe, indent, start_col, Space.None);
            try renderExpression(allocator, stream, tree, indent, start_col, payload.error_symbol, Space.None);
            return renderToken(tree, stream, payload.rpipe, indent, start_col, space);
        },

        ast.Node.Id.PointerPayload => {
            const payload = @fieldParentPtr(ast.Node.PointerPayload, "base", base);

            try renderToken(tree, stream, payload.lpipe, indent, start_col, Space.None);
            if (payload.ptr_token) |ptr_token| {
                try renderToken(tree, stream, ptr_token, indent, start_col, Space.None);
            }
            try renderExpression(allocator, stream, tree, indent, start_col, payload.value_symbol, Space.None);
            return renderToken(tree, stream, payload.rpipe, indent, start_col, space);
        },

        ast.Node.Id.PointerIndexPayload => {
            const payload = @fieldParentPtr(ast.Node.PointerIndexPayload, "base", base);

            try renderToken(tree, stream, payload.lpipe, indent, start_col, Space.None);
            if (payload.ptr_token) |ptr_token| {
                try renderToken(tree, stream, ptr_token, indent, start_col, Space.None);
            }
            try renderExpression(allocator, stream, tree, indent, start_col, payload.value_symbol, Space.None);

            if (payload.index_symbol) |index_symbol| {
                const comma = tree.nextToken(payload.value_symbol.lastToken());

                try renderToken(tree, stream, comma, indent, start_col, Space.Space);
                try renderExpression(allocator, stream, tree, indent, start_col, index_symbol, Space.None);
            }

            return renderToken(tree, stream, payload.rpipe, indent, start_col, space);
        },

        ast.Node.Id.GroupedExpression => {
            const grouped_expr = @fieldParentPtr(ast.Node.GroupedExpression, "base", base);

            try renderToken(tree, stream, grouped_expr.lparen, indent, start_col, Space.None);
            try renderExpression(allocator, stream, tree, indent, start_col, grouped_expr.expr, Space.None);
            return renderToken(tree, stream, grouped_expr.rparen, indent, start_col, space);
        },

        ast.Node.Id.FieldInitializer => {
            const field_init = @fieldParentPtr(ast.Node.FieldInitializer, "base", base);

            try renderToken(tree, stream, field_init.period_token, indent, start_col, Space.None); // .
            try renderToken(tree, stream, field_init.name_token, indent, start_col, Space.Space); // name
            try renderToken(tree, stream, tree.nextToken(field_init.name_token), indent, start_col, Space.Space); // =
            return renderExpression(allocator, stream, tree, indent, start_col, field_init.expr, space);
        },

        ast.Node.Id.IntegerLiteral => {
            const integer_literal = @fieldParentPtr(ast.Node.IntegerLiteral, "base", base);
            return renderToken(tree, stream, integer_literal.token, indent, start_col, space);
        },
        ast.Node.Id.FloatLiteral => {
            const float_literal = @fieldParentPtr(ast.Node.FloatLiteral, "base", base);
            return renderToken(tree, stream, float_literal.token, indent, start_col, space);
        },
        ast.Node.Id.StringLiteral => {
            const string_literal = @fieldParentPtr(ast.Node.StringLiteral, "base", base);
            return renderToken(tree, stream, string_literal.token, indent, start_col, space);
        },
        ast.Node.Id.CharLiteral => {
            const char_literal = @fieldParentPtr(ast.Node.CharLiteral, "base", base);
            return renderToken(tree, stream, char_literal.token, indent, start_col, space);
        },
        ast.Node.Id.BoolLiteral => {
            const bool_literal = @fieldParentPtr(ast.Node.CharLiteral, "base", base);
            return renderToken(tree, stream, bool_literal.token, indent, start_col, space);
        },
        ast.Node.Id.NullLiteral => {
            const null_literal = @fieldParentPtr(ast.Node.NullLiteral, "base", base);
            return renderToken(tree, stream, null_literal.token, indent, start_col, space);
        },
        ast.Node.Id.ThisLiteral => {
            const this_literal = @fieldParentPtr(ast.Node.ThisLiteral, "base", base);
            return renderToken(tree, stream, this_literal.token, indent, start_col, space);
        },
        ast.Node.Id.Unreachable => {
            const unreachable_node = @fieldParentPtr(ast.Node.Unreachable, "base", base);
            return renderToken(tree, stream, unreachable_node.token, indent, start_col, space);
        },
        ast.Node.Id.ErrorType => {
            const error_type = @fieldParentPtr(ast.Node.ErrorType, "base", base);
            return renderToken(tree, stream, error_type.token, indent, start_col, space);
        },
        ast.Node.Id.VarType => {
            const var_type = @fieldParentPtr(ast.Node.VarType, "base", base);
            return renderToken(tree, stream, var_type.token, indent, start_col, space);
        },
        ast.Node.Id.ContainerDecl => {
            const container_decl = @fieldParentPtr(ast.Node.ContainerDecl, "base", base);

            if (container_decl.layout_token) |layout_token| {
                try renderToken(tree, stream, layout_token, indent, start_col, Space.Space);
            }

            switch (container_decl.init_arg_expr) {
                ast.Node.ContainerDecl.InitArg.None => {
                    try renderToken(tree, stream, container_decl.kind_token, indent, start_col, Space.Space); // union
                },
                ast.Node.ContainerDecl.InitArg.Enum => |enum_tag_type| {
                    try renderToken(tree, stream, container_decl.kind_token, indent, start_col, Space.None); // union

                    const lparen = tree.nextToken(container_decl.kind_token);
                    const enum_token = tree.nextToken(lparen);

                    try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (
                    try renderToken(tree, stream, enum_token, indent, start_col, Space.None); // enum

                    if (enum_tag_type) |expr| {
                        try renderToken(tree, stream, tree.nextToken(enum_token), indent, start_col, Space.None); // (
                        try renderExpression(allocator, stream, tree, indent, start_col, expr, Space.None);

                        const rparen = tree.nextToken(expr.lastToken());
                        try renderToken(tree, stream, rparen, indent, start_col, Space.None); // )
                        try renderToken(tree, stream, tree.nextToken(rparen), indent, start_col, Space.Space); // )
                    } else {
                        try renderToken(tree, stream, tree.nextToken(enum_token), indent, start_col, Space.Space); // )
                    }
                },
                ast.Node.ContainerDecl.InitArg.Type => |type_expr| {
                    try renderToken(tree, stream, container_decl.kind_token, indent, start_col, Space.None); // union

                    const lparen = tree.nextToken(container_decl.kind_token);
                    const rparen = tree.nextToken(type_expr.lastToken());

                    try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (
                    try renderExpression(allocator, stream, tree, indent, start_col, type_expr, Space.None);
                    try renderToken(tree, stream, rparen, indent, start_col, Space.Space); // )
                },
            }

            if (container_decl.fields_and_decls.len == 0) {
                try renderToken(tree, stream, container_decl.lbrace_token, indent + indent_delta, start_col, Space.None); // {
                return renderToken(tree, stream, container_decl.rbrace_token, indent, start_col, space); // }
            } else {
                const new_indent = indent + indent_delta;
                try renderToken(tree, stream, container_decl.lbrace_token, new_indent, start_col, Space.Newline); // {

                var it = container_decl.fields_and_decls.iterator(0);
                while (it.next()) |decl| {
                    try stream.writeByteNTimes(' ', new_indent);
                    try renderTopLevelDecl(allocator, stream, tree, new_indent, start_col, decl.*);

                    if (it.peek()) |next_decl| {
                        try renderExtraNewline(tree, stream, start_col, next_decl.*);
                    }
                }

                try stream.writeByteNTimes(' ', indent);
                return renderToken(tree, stream, container_decl.rbrace_token, indent, start_col, space); // }
            }
        },

        ast.Node.Id.ErrorSetDecl => {
            const err_set_decl = @fieldParentPtr(ast.Node.ErrorSetDecl, "base", base);

            const lbrace = tree.nextToken(err_set_decl.error_token);

            if (err_set_decl.decls.len == 0) {
                try renderToken(tree, stream, err_set_decl.error_token, indent, start_col, Space.None);
                try renderToken(tree, stream, lbrace, indent, start_col, Space.None);
                return renderToken(tree, stream, err_set_decl.rbrace_token, indent, start_col, space);
            }

            if (err_set_decl.decls.len == 1) blk: {
                const node = err_set_decl.decls.at(0).*;

                // if there are any doc comments or same line comments
                // don't try to put it all on one line
                if (node.cast(ast.Node.ErrorTag)) |tag| {
                    if (tag.doc_comments != null) break :blk;
                } else {
                    break :blk;
                }

                try renderToken(tree, stream, err_set_decl.error_token, indent, start_col, Space.None); // error
                try renderToken(tree, stream, lbrace, indent, start_col, Space.None); // {
                try renderExpression(allocator, stream, tree, indent, start_col, node, Space.None);
                return renderToken(tree, stream, err_set_decl.rbrace_token, indent, start_col, space); // }
            }

            try renderToken(tree, stream, err_set_decl.error_token, indent, start_col, Space.None); // error
            try renderToken(tree, stream, lbrace, indent, start_col, Space.Newline); // {
            const new_indent = indent + indent_delta;

            var it = err_set_decl.decls.iterator(0);
            while (it.next()) |node| {
                try stream.writeByteNTimes(' ', new_indent);

                if (it.peek()) |next_node| {
                    try renderExpression(allocator, stream, tree, new_indent, start_col, node.*, Space.None);
                    try renderToken(tree, stream, tree.nextToken(node.*.lastToken()), new_indent, start_col, Space.Newline); // ,

                    try renderExtraNewline(tree, stream, start_col, next_node.*);
                } else {
                    try renderExpression(allocator, stream, tree, new_indent, start_col, node.*, Space.Comma);
                }
            }

            try stream.writeByteNTimes(' ', indent);
            return renderToken(tree, stream, err_set_decl.rbrace_token, indent, start_col, space); // }
        },

        ast.Node.Id.ErrorTag => {
            const tag = @fieldParentPtr(ast.Node.ErrorTag, "base", base);

            try renderDocComments(tree, stream, tag, indent, start_col);
            return renderToken(tree, stream, tag.name_token, indent, start_col, space); // name
        },

        ast.Node.Id.MultilineStringLiteral => {
            const multiline_str_literal = @fieldParentPtr(ast.Node.MultilineStringLiteral, "base", base);

            var skip_first_indent = true;
            if (tree.tokens.at(multiline_str_literal.firstToken() - 1).id != Token.Id.LineComment) {
                try stream.print("\n");
                skip_first_indent = false;
            }

            var i: usize = 0;
            while (i < multiline_str_literal.lines.len) : (i += 1) {
                const t = multiline_str_literal.lines.at(i).*;
                if (!skip_first_indent) {
                    try stream.writeByteNTimes(' ', indent + indent_delta);
                }
                try renderToken(tree, stream, t, indent, start_col, Space.None);
                skip_first_indent = false;
            }
            try stream.writeByteNTimes(' ', indent);
        },
        ast.Node.Id.UndefinedLiteral => {
            const undefined_literal = @fieldParentPtr(ast.Node.UndefinedLiteral, "base", base);
            return renderToken(tree, stream, undefined_literal.token, indent, start_col, space);
        },

        ast.Node.Id.BuiltinCall => {
            const builtin_call = @fieldParentPtr(ast.Node.BuiltinCall, "base", base);

            try renderToken(tree, stream, builtin_call.builtin_token, indent, start_col, Space.None); // @name
            try renderToken(tree, stream, tree.nextToken(builtin_call.builtin_token), indent, start_col, Space.None); // (

            var it = builtin_call.params.iterator(0);
            while (it.next()) |param_node| {
                try renderExpression(allocator, stream, tree, indent, start_col, param_node.*, Space.None);

                if (it.peek() != null) {
                    const comma_token = tree.nextToken(param_node.*.lastToken());
                    try renderToken(tree, stream, comma_token, indent, start_col, Space.Space); // ,
                }
            }
            return renderToken(tree, stream, builtin_call.rparen_token, indent, start_col, space); // )
        },

        ast.Node.Id.FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", base);

            if (fn_proto.visib_token) |visib_token_index| {
                const visib_token = tree.tokens.at(visib_token_index);
                assert(visib_token.id == Token.Id.Keyword_pub or visib_token.id == Token.Id.Keyword_export);

                try renderToken(tree, stream, visib_token_index, indent, start_col, Space.Space); // pub
            }

            if (fn_proto.extern_export_inline_token) |extern_export_inline_token| {
                try renderToken(tree, stream, extern_export_inline_token, indent, start_col, Space.Space); // extern/export
            }

            if (fn_proto.lib_name) |lib_name| {
                try renderExpression(allocator, stream, tree, indent, start_col, lib_name, Space.Space);
            }

            if (fn_proto.cc_token) |cc_token| {
                try renderToken(tree, stream, cc_token, indent, start_col, Space.Space); // stdcallcc
            }

            if (fn_proto.async_attr) |async_attr| {
                try renderExpression(allocator, stream, tree, indent, start_col, &async_attr.base, Space.Space);
            }

            const lparen = if (fn_proto.name_token) |name_token| blk: {
                try renderToken(tree, stream, fn_proto.fn_token, indent, start_col, Space.Space); // fn
                try renderToken(tree, stream, name_token, indent, start_col, Space.None); // name
                break :blk tree.nextToken(name_token);
            } else blk: {
                try renderToken(tree, stream, fn_proto.fn_token, indent, start_col, Space.Space); // fn
                break :blk tree.nextToken(fn_proto.fn_token);
            };

            const rparen = tree.prevToken(switch (fn_proto.return_type) {
                ast.Node.FnProto.ReturnType.Explicit => |node| node.firstToken(),
                ast.Node.FnProto.ReturnType.InferErrorSet => |node| tree.prevToken(node.firstToken()),
            });

            const src_params_trailing_comma = blk: {
                const maybe_comma = tree.prevToken(rparen);
                break :blk tree.tokens.at(maybe_comma).id == Token.Id.Comma;
            };
            const src_params_same_line = blk: {
                const loc = tree.tokenLocation(tree.tokens.at(lparen).end, rparen);
                break :blk loc.line == 0;
            };

            if (!src_params_trailing_comma and src_params_same_line) {
                try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (

                // render all on one line, no trailing comma
                var it = fn_proto.params.iterator(0);
                while (it.next()) |param_decl_node| {
                    try renderParamDecl(allocator, stream, tree, indent, start_col, param_decl_node.*, Space.None);

                    if (it.peek() != null) {
                        const comma = tree.nextToken(param_decl_node.*.lastToken());
                        try renderToken(tree, stream, comma, indent, start_col, Space.Space); // ,
                    }
                }
            } else {
                // one param per line
                const new_indent = indent + indent_delta;
                try renderToken(tree, stream, lparen, new_indent, start_col, Space.Newline); // (

                var it = fn_proto.params.iterator(0);
                while (it.next()) |param_decl_node| {
                    try stream.writeByteNTimes(' ', new_indent);
                    try renderParamDecl(allocator, stream, tree, indent, start_col, param_decl_node.*, Space.Comma);
                }
                try stream.writeByteNTimes(' ', indent);
            }

            try renderToken(tree, stream, rparen, indent, start_col, Space.Space); // )

            if (fn_proto.align_expr) |align_expr| {
                const align_rparen = tree.nextToken(align_expr.lastToken());
                const align_lparen = tree.prevToken(align_expr.firstToken());
                const align_kw = tree.prevToken(align_lparen);

                try renderToken(tree, stream, align_kw, indent, start_col, Space.None); // align
                try renderToken(tree, stream, align_lparen, indent, start_col, Space.None); // (
                try renderExpression(allocator, stream, tree, indent, start_col, align_expr, Space.None);
                try renderToken(tree, stream, align_rparen, indent, start_col, Space.Space); // )
            }

            switch (fn_proto.return_type) {
                ast.Node.FnProto.ReturnType.Explicit => |node| {
                    return renderExpression(allocator, stream, tree, indent, start_col, node, space);
                },
                ast.Node.FnProto.ReturnType.InferErrorSet => |node| {
                    try renderToken(tree, stream, tree.prevToken(node.firstToken()), indent, start_col, Space.None); // !
                    return renderExpression(allocator, stream, tree, indent, start_col, node, space);
                },
            }
        },

        ast.Node.Id.PromiseType => {
            const promise_type = @fieldParentPtr(ast.Node.PromiseType, "base", base);

            if (promise_type.result) |result| {
                try renderToken(tree, stream, promise_type.promise_token, indent, start_col, Space.None); // promise
                try renderToken(tree, stream, result.arrow_token, indent, start_col, Space.None); // ->
                return renderExpression(allocator, stream, tree, indent, start_col, result.return_type, space);
            } else {
                return renderToken(tree, stream, promise_type.promise_token, indent, start_col, space); // promise
            }
        },

        ast.Node.Id.DocComment => unreachable, // doc comments are attached to nodes

        ast.Node.Id.Switch => {
            const switch_node = @fieldParentPtr(ast.Node.Switch, "base", base);

            try renderToken(tree, stream, switch_node.switch_token, indent, start_col, Space.Space); // switch
            try renderToken(tree, stream, tree.nextToken(switch_node.switch_token), indent, start_col, Space.None); // (

            const rparen = tree.nextToken(switch_node.expr.lastToken());
            const lbrace = tree.nextToken(rparen);

            if (switch_node.cases.len == 0) {
                try renderExpression(allocator, stream, tree, indent, start_col, switch_node.expr, Space.None);
                try renderToken(tree, stream, rparen, indent, start_col, Space.Space); // )
                try renderToken(tree, stream, lbrace, indent, start_col, Space.None); // {
                return renderToken(tree, stream, switch_node.rbrace, indent, start_col, space); // }
            }

            try renderExpression(allocator, stream, tree, indent, start_col, switch_node.expr, Space.None);

            const new_indent = indent + indent_delta;

            try renderToken(tree, stream, rparen, indent, start_col, Space.Space); // )
            try renderToken(tree, stream, lbrace, new_indent, start_col, Space.Newline); // {

            var it = switch_node.cases.iterator(0);
            while (it.next()) |node| {
                try stream.writeByteNTimes(' ', new_indent);
                try renderExpression(allocator, stream, tree, new_indent, start_col, node.*, Space.Comma);

                if (it.peek()) |next_node| {
                    try renderExtraNewline(tree, stream, start_col, next_node.*);
                }
            }

            try stream.writeByteNTimes(' ', indent);
            return renderToken(tree, stream, switch_node.rbrace, indent, start_col, space); // }
        },

        ast.Node.Id.SwitchCase => {
            const switch_case = @fieldParentPtr(ast.Node.SwitchCase, "base", base);

            assert(switch_case.items.len != 0);
            const src_has_trailing_comma = blk: {
                const last_node = switch_case.items.at(switch_case.items.len - 1).*;
                const maybe_comma = tree.nextToken(last_node.lastToken());
                break :blk tree.tokens.at(maybe_comma).id == Token.Id.Comma;
            };

            if (switch_case.items.len == 1 or !src_has_trailing_comma) {
                var it = switch_case.items.iterator(0);
                while (it.next()) |node| {
                    if (it.peek()) |next_node| {
                        try renderExpression(allocator, stream, tree, indent, start_col, node.*, Space.None);

                        const comma_token = tree.nextToken(node.*.lastToken());
                        try renderToken(tree, stream, comma_token, indent, start_col, Space.Space); // ,
                        try renderExtraNewline(tree, stream, start_col, next_node.*);
                    } else {
                        try renderExpression(allocator, stream, tree, indent, start_col, node.*, Space.Space);
                    }
                }
            } else {
                var it = switch_case.items.iterator(0);
                while (true) {
                    const node = it.next().?;
                    if (it.peek()) |next_node| {
                        try renderExpression(allocator, stream, tree, indent, start_col, node.*, Space.None);

                        const comma_token = tree.nextToken(node.*.lastToken());
                        try renderToken(tree, stream, comma_token, indent, start_col, Space.Newline); // ,
                        try renderExtraNewline(tree, stream, start_col, next_node.*);
                        try stream.writeByteNTimes(' ', indent);
                    } else {
                        try renderExpression(allocator, stream, tree, indent, start_col, node.*, Space.Comma);
                        try stream.writeByteNTimes(' ', indent);
                        break;
                    }
                }
            }

            try renderToken(tree, stream, switch_case.arrow_token, indent, start_col, Space.Space); // =>

            if (switch_case.payload) |payload| {
                try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Space);
            }

            return renderExpression(allocator, stream, tree, indent, start_col, switch_case.expr, space);
        },
        ast.Node.Id.SwitchElse => {
            const switch_else = @fieldParentPtr(ast.Node.SwitchElse, "base", base);
            return renderToken(tree, stream, switch_else.token, indent, start_col, space);
        },
        ast.Node.Id.Else => {
            const else_node = @fieldParentPtr(ast.Node.Else, "base", base);

            const body_is_block = nodeIsBlock(else_node.body);
            const same_line = body_is_block or tree.tokensOnSameLine(else_node.else_token, else_node.body.lastToken());

            const after_else_space = if (same_line or else_node.payload != null) Space.Space else Space.Newline;
            try renderToken(tree, stream, else_node.else_token, indent, start_col, after_else_space);

            if (else_node.payload) |payload| {
                const payload_space = if (same_line) Space.Space else Space.Newline;
                try renderExpression(allocator, stream, tree, indent, start_col, payload, payload_space);
            }

            if (same_line) {
                return renderExpression(allocator, stream, tree, indent, start_col, else_node.body, space);
            }

            try stream.writeByteNTimes(' ', indent + indent_delta);
            start_col.* = indent + indent_delta;
            return renderExpression(allocator, stream, tree, indent, start_col, else_node.body, space);
        },

        ast.Node.Id.While => {
            const while_node = @fieldParentPtr(ast.Node.While, "base", base);

            if (while_node.label) |label| {
                try renderToken(tree, stream, label, indent, start_col, Space.None); // label
                try renderToken(tree, stream, tree.nextToken(label), indent, start_col, Space.Space); // :
            }

            if (while_node.inline_token) |inline_token| {
                try renderToken(tree, stream, inline_token, indent, start_col, Space.Space); // inline
            }

            try renderToken(tree, stream, while_node.while_token, indent, start_col, Space.Space); // while
            try renderToken(tree, stream, tree.nextToken(while_node.while_token), indent, start_col, Space.None); // (
            try renderExpression(allocator, stream, tree, indent, start_col, while_node.condition, Space.None);

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
                try renderToken(tree, stream, cond_rparen, indent, start_col, rparen_space); // )
            }

            if (while_node.payload) |payload| {
                const payload_space = if (while_node.continue_expr != null) Space.Space else block_start_space;
                try renderExpression(allocator, stream, tree, indent, start_col, payload, payload_space);
            }

            if (while_node.continue_expr) |continue_expr| {
                const rparen = tree.nextToken(continue_expr.lastToken());
                const lparen = tree.prevToken(continue_expr.firstToken());
                const colon = tree.prevToken(lparen);

                try renderToken(tree, stream, colon, indent, start_col, Space.Space); // :
                try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (

                try renderExpression(allocator, stream, tree, indent, start_col, continue_expr, Space.None);

                try renderToken(tree, stream, rparen, indent, start_col, block_start_space); // )
            }

            var new_indent = indent;
            if (block_start_space == Space.Newline) {
                new_indent += indent_delta;
                try stream.writeByteNTimes(' ', new_indent);
                start_col.* = new_indent;
            }

            try renderExpression(allocator, stream, tree, indent, start_col, while_node.body, after_body_space);

            if (while_node.@"else") |@"else"| {
                if (after_body_space == Space.Newline) {
                    try stream.writeByteNTimes(' ', indent);
                    start_col.* = indent;
                }
                return renderExpression(allocator, stream, tree, indent, start_col, &@"else".base, space);
            }
        },

        ast.Node.Id.For => {
            const for_node = @fieldParentPtr(ast.Node.For, "base", base);

            if (for_node.label) |label| {
                try renderToken(tree, stream, label, indent, start_col, Space.None); // label
                try renderToken(tree, stream, tree.nextToken(label), indent, start_col, Space.Space); // :
            }

            if (for_node.inline_token) |inline_token| {
                try renderToken(tree, stream, inline_token, indent, start_col, Space.Space); // inline
            }

            try renderToken(tree, stream, for_node.for_token, indent, start_col, Space.Space); // for
            try renderToken(tree, stream, tree.nextToken(for_node.for_token), indent, start_col, Space.None); // (
            try renderExpression(allocator, stream, tree, indent, start_col, for_node.array_expr, Space.None);

            const rparen = tree.nextToken(for_node.array_expr.lastToken());
            const rparen_space = if (for_node.payload != null or
                for_node.body.id == ast.Node.Id.Block) Space.Space else Space.Newline;
            try renderToken(tree, stream, rparen, indent, start_col, rparen_space); // )

            if (for_node.payload) |payload| {
                const payload_space = if (for_node.body.id == ast.Node.Id.Block) Space.Space else Space.Newline;
                try renderExpression(allocator, stream, tree, indent, start_col, payload, payload_space);
            }

            const body_space = blk: {
                if (for_node.@"else" != null) {
                    if (for_node.body.id == ast.Node.Id.Block) {
                        break :blk Space.Space;
                    } else {
                        break :blk Space.Newline;
                    }
                } else {
                    break :blk space;
                }
            };
            if (for_node.body.id == ast.Node.Id.Block) {
                try renderExpression(allocator, stream, tree, indent, start_col, for_node.body, body_space);
            } else {
                try stream.writeByteNTimes(' ', indent + indent_delta);
                try renderExpression(allocator, stream, tree, indent, start_col, for_node.body, body_space);
            }

            if (for_node.@"else") |@"else"| {
                if (for_node.body.id != ast.Node.Id.Block) {
                    try stream.writeByteNTimes(' ', indent);
                }

                return renderExpression(allocator, stream, tree, indent, start_col, &@"else".base, space);
            }
        },

        ast.Node.Id.If => {
            const if_node = @fieldParentPtr(ast.Node.If, "base", base);

            const lparen = tree.prevToken(if_node.condition.firstToken());
            const rparen = tree.nextToken(if_node.condition.lastToken());

            try renderToken(tree, stream, if_node.if_token, indent, start_col, Space.Space); // if
            try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (

            try renderExpression(allocator, stream, tree, indent, start_col, if_node.condition, Space.None); // condition

            const body_is_block = nodeIsBlock(if_node.body);

            if (body_is_block) {
                const after_rparen_space = if (if_node.payload == null) Space.BlockStart else Space.Space;
                try renderToken(tree, stream, rparen, indent, start_col, after_rparen_space); // )

                if (if_node.payload) |payload| {
                    try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.BlockStart); // |x|
                }

                if (if_node.@"else") |@"else"| {
                    try renderExpression(allocator, stream, tree, indent, start_col, if_node.body, Space.SpaceOrOutdent);
                    return renderExpression(allocator, stream, tree, indent, start_col, &@"else".base, space);
                } else {
                    return renderExpression(allocator, stream, tree, indent, start_col, if_node.body, space);
                }
            }

            const src_has_newline = !tree.tokensOnSameLine(rparen, if_node.body.lastToken());

            if (src_has_newline) {
                const after_rparen_space = if (if_node.payload == null) Space.Newline else Space.Space;
                try renderToken(tree, stream, rparen, indent, start_col, after_rparen_space); // )

                if (if_node.payload) |payload| {
                    try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Newline);
                }

                const new_indent = indent + indent_delta;
                try stream.writeByteNTimes(' ', new_indent);

                if (if_node.@"else") |@"else"| {
                    const else_is_block = nodeIsBlock(@"else".body);
                    try renderExpression(allocator, stream, tree, new_indent, start_col, if_node.body, Space.Newline);
                    try stream.writeByteNTimes(' ', indent);

                    if (else_is_block) {
                        try renderToken(tree, stream, @"else".else_token, indent, start_col, Space.Space); // else

                        if (@"else".payload) |payload| {
                            try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Space);
                        }

                        return renderExpression(allocator, stream, tree, indent, start_col, @"else".body, space);
                    } else {
                        const after_else_space = if (@"else".payload == null) Space.Newline else Space.Space;
                        try renderToken(tree, stream, @"else".else_token, indent, start_col, after_else_space); // else

                        if (@"else".payload) |payload| {
                            try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Newline);
                        }
                        try stream.writeByteNTimes(' ', new_indent);

                        return renderExpression(allocator, stream, tree, new_indent, start_col, @"else".body, space);
                    }
                } else {
                    return renderExpression(allocator, stream, tree, new_indent, start_col, if_node.body, space);
                }
            }

            try renderToken(tree, stream, rparen, indent, start_col, Space.Space); // )

            if (if_node.payload) |payload| {
                try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Space);
            }

            if (if_node.@"else") |@"else"| {
                try renderExpression(allocator, stream, tree, indent, start_col, if_node.body, Space.Space);
                try renderToken(tree, stream, @"else".else_token, indent, start_col, Space.Space);

                if (@"else".payload) |payload| {
                    try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Space);
                }

                return renderExpression(allocator, stream, tree, indent, start_col, @"else".body, space);
            } else {
                return renderExpression(allocator, stream, tree, indent, start_col, if_node.body, space);
            }
        },

        ast.Node.Id.Asm => {
            const asm_node = @fieldParentPtr(ast.Node.Asm, "base", base);

            try renderToken(tree, stream, asm_node.asm_token, indent, start_col, Space.Space); // asm

            if (asm_node.volatile_token) |volatile_token| {
                try renderToken(tree, stream, volatile_token, indent, start_col, Space.Space); // volatile
                try renderToken(tree, stream, tree.nextToken(volatile_token), indent, start_col, Space.None); // (
            } else {
                try renderToken(tree, stream, tree.nextToken(asm_node.asm_token), indent, start_col, Space.None); // (
            }

            if (asm_node.outputs.len == 0 and asm_node.inputs.len == 0 and asm_node.clobbers.len == 0) {
                try renderExpression(allocator, stream, tree, indent, start_col, asm_node.template, Space.None);
                return renderToken(tree, stream, asm_node.rparen, indent, start_col, space);
            }

            try renderExpression(allocator, stream, tree, indent, start_col, asm_node.template, Space.Newline);

            const indent_once = indent + indent_delta;
            try stream.writeByteNTimes(' ', indent_once);

            const colon1 = tree.nextToken(asm_node.template.lastToken());
            const indent_extra = indent_once + 2;

            const colon2 = if (asm_node.outputs.len == 0) blk: {
                try renderToken(tree, stream, colon1, indent, start_col, Space.Newline); // :
                try stream.writeByteNTimes(' ', indent_once);

                break :blk tree.nextToken(colon1);
            } else blk: {
                try renderToken(tree, stream, colon1, indent, start_col, Space.Space); // :

                var it = asm_node.outputs.iterator(0);
                while (true) {
                    const asm_output = it.next().?;
                    const node = &(asm_output.*).base;

                    if (it.peek()) |next_asm_output| {
                        try renderExpression(allocator, stream, tree, indent_extra, start_col, node, Space.None);
                        const next_node = &(next_asm_output.*).base;

                        const comma = tree.prevToken(next_asm_output.*.firstToken());
                        try renderToken(tree, stream, comma, indent_extra, start_col, Space.Newline); // ,
                        try renderExtraNewline(tree, stream, start_col, next_node);

                        try stream.writeByteNTimes(' ', indent_extra);
                    } else if (asm_node.inputs.len == 0 and asm_node.clobbers.len == 0) {
                        try renderExpression(allocator, stream, tree, indent_extra, start_col, node, Space.Newline);
                        try stream.writeByteNTimes(' ', indent);
                        return renderToken(tree, stream, asm_node.rparen, indent, start_col, space);
                    } else {
                        try renderExpression(allocator, stream, tree, indent_extra, start_col, node, Space.Newline);
                        try stream.writeByteNTimes(' ', indent_once);
                        const comma_or_colon = tree.nextToken(node.lastToken());
                        break :blk switch (tree.tokens.at(comma_or_colon).id) {
                            Token.Id.Comma => tree.nextToken(comma_or_colon),
                            else => comma_or_colon,
                        };
                    }
                }
            };

            const colon3 = if (asm_node.inputs.len == 0) blk: {
                try renderToken(tree, stream, colon2, indent, start_col, Space.Newline); // :
                try stream.writeByteNTimes(' ', indent_once);

                break :blk tree.nextToken(colon2);
            } else blk: {
                try renderToken(tree, stream, colon2, indent, start_col, Space.Space); // :

                var it = asm_node.inputs.iterator(0);
                while (true) {
                    const asm_input = it.next().?;
                    const node = &(asm_input.*).base;

                    if (it.peek()) |next_asm_input| {
                        try renderExpression(allocator, stream, tree, indent_extra, start_col, node, Space.None);
                        const next_node = &(next_asm_input.*).base;

                        const comma = tree.prevToken(next_asm_input.*.firstToken());
                        try renderToken(tree, stream, comma, indent_extra, start_col, Space.Newline); // ,
                        try renderExtraNewline(tree, stream, start_col, next_node);

                        try stream.writeByteNTimes(' ', indent_extra);
                    } else if (asm_node.clobbers.len == 0) {
                        try renderExpression(allocator, stream, tree, indent_extra, start_col, node, Space.Newline);
                        try stream.writeByteNTimes(' ', indent);
                        return renderToken(tree, stream, asm_node.rparen, indent, start_col, space); // )
                    } else {
                        try renderExpression(allocator, stream, tree, indent_extra, start_col, node, Space.Newline);
                        try stream.writeByteNTimes(' ', indent_once);
                        const comma_or_colon = tree.nextToken(node.lastToken());
                        break :blk switch (tree.tokens.at(comma_or_colon).id) {
                            Token.Id.Comma => tree.nextToken(comma_or_colon),
                            else => comma_or_colon,
                        };
                    }
                }
            };

            try renderToken(tree, stream, colon3, indent, start_col, Space.Space); // :

            var it = asm_node.clobbers.iterator(0);
            while (true) {
                const clobber_token = it.next().?;

                if (it.peek() == null) {
                    try renderToken(tree, stream, clobber_token.*, indent_once, start_col, Space.Newline);
                    try stream.writeByteNTimes(' ', indent);
                    return renderToken(tree, stream, asm_node.rparen, indent, start_col, space);
                } else {
                    try renderToken(tree, stream, clobber_token.*, indent_once, start_col, Space.None);
                    const comma = tree.nextToken(clobber_token.*);
                    try renderToken(tree, stream, comma, indent_once, start_col, Space.Space); // ,
                }
            }
        },

        ast.Node.Id.AsmInput => {
            const asm_input = @fieldParentPtr(ast.Node.AsmInput, "base", base);

            try stream.write("[");
            try renderExpression(allocator, stream, tree, indent, start_col, asm_input.symbolic_name, Space.None);
            try stream.write("] ");
            try renderExpression(allocator, stream, tree, indent, start_col, asm_input.constraint, Space.None);
            try stream.write(" (");
            try renderExpression(allocator, stream, tree, indent, start_col, asm_input.expr, Space.None);
            return renderToken(tree, stream, asm_input.lastToken(), indent, start_col, space); // )
        },

        ast.Node.Id.AsmOutput => {
            const asm_output = @fieldParentPtr(ast.Node.AsmOutput, "base", base);

            try stream.write("[");
            try renderExpression(allocator, stream, tree, indent, start_col, asm_output.symbolic_name, Space.None);
            try stream.write("] ");
            try renderExpression(allocator, stream, tree, indent, start_col, asm_output.constraint, Space.None);
            try stream.write(" (");

            switch (asm_output.kind) {
                ast.Node.AsmOutput.Kind.Variable => |variable_name| {
                    try renderExpression(allocator, stream, tree, indent, start_col, &variable_name.base, Space.None);
                },
                ast.Node.AsmOutput.Kind.Return => |return_type| {
                    try stream.write("-> ");
                    try renderExpression(allocator, stream, tree, indent, start_col, return_type, Space.None);
                },
            }

            return renderToken(tree, stream, asm_output.lastToken(), indent, start_col, space); // )
        },

        ast.Node.Id.StructField,
        ast.Node.Id.UnionTag,
        ast.Node.Id.EnumTag,
        ast.Node.Id.Root,
        ast.Node.Id.VarDecl,
        ast.Node.Id.Use,
        ast.Node.Id.TestDecl,
        ast.Node.Id.ParamDecl,
        => unreachable,
    }
}

fn renderVarDecl(
    allocator: *mem.Allocator,
    stream: var,
    tree: *ast.Tree,
    indent: usize,
    start_col: *usize,
    var_decl: *ast.Node.VarDecl,
) (@typeOf(stream).Child.Error || Error)!void {
    if (var_decl.visib_token) |visib_token| {
        try renderToken(tree, stream, visib_token, indent, start_col, Space.Space); // pub
    }

    if (var_decl.extern_export_token) |extern_export_token| {
        try renderToken(tree, stream, extern_export_token, indent, start_col, Space.Space); // extern

        if (var_decl.lib_name) |lib_name| {
            try renderExpression(allocator, stream, tree, indent, start_col, lib_name, Space.Space); // "lib"
        }
    }

    if (var_decl.comptime_token) |comptime_token| {
        try renderToken(tree, stream, comptime_token, indent, start_col, Space.Space); // comptime
    }

    try renderToken(tree, stream, var_decl.mut_token, indent, start_col, Space.Space); // var

    const name_space = if (var_decl.type_node == null and (var_decl.align_node != null or
        var_decl.init_node != null)) Space.Space else Space.None;
    try renderToken(tree, stream, var_decl.name_token, indent, start_col, name_space);

    if (var_decl.type_node) |type_node| {
        try renderToken(tree, stream, tree.nextToken(var_decl.name_token), indent, start_col, Space.Space);
        const s = if (var_decl.align_node != null or var_decl.init_node != null) Space.Space else Space.None;
        try renderExpression(allocator, stream, tree, indent, start_col, type_node, s);
    }

    if (var_decl.align_node) |align_node| {
        const lparen = tree.prevToken(align_node.firstToken());
        const align_kw = tree.prevToken(lparen);
        const rparen = tree.nextToken(align_node.lastToken());
        try renderToken(tree, stream, align_kw, indent, start_col, Space.None); // align
        try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (
        try renderExpression(allocator, stream, tree, indent, start_col, align_node, Space.None);
        const s = if (var_decl.init_node != null) Space.Space else Space.None;
        try renderToken(tree, stream, rparen, indent, start_col, s); // )
    }

    if (var_decl.init_node) |init_node| {
        const s = if (init_node.id == ast.Node.Id.MultilineStringLiteral) Space.None else Space.Space;
        try renderToken(tree, stream, var_decl.eq_token, indent, start_col, s); // =
        try renderExpression(allocator, stream, tree, indent, start_col, init_node, Space.None);
    }

    try renderToken(tree, stream, var_decl.semicolon_token, indent, start_col, Space.Newline);
}

fn renderParamDecl(
    allocator: *mem.Allocator,
    stream: var,
    tree: *ast.Tree,
    indent: usize,
    start_col: *usize,
    base: *ast.Node,
    space: Space,
) (@typeOf(stream).Child.Error || Error)!void {
    const param_decl = @fieldParentPtr(ast.Node.ParamDecl, "base", base);

    if (param_decl.comptime_token) |comptime_token| {
        try renderToken(tree, stream, comptime_token, indent, start_col, Space.Space);
    }
    if (param_decl.noalias_token) |noalias_token| {
        try renderToken(tree, stream, noalias_token, indent, start_col, Space.Space);
    }
    if (param_decl.name_token) |name_token| {
        try renderToken(tree, stream, name_token, indent, start_col, Space.None);
        try renderToken(tree, stream, tree.nextToken(name_token), indent, start_col, Space.Space); // :
    }
    if (param_decl.var_args_token) |var_args_token| {
        try renderToken(tree, stream, var_args_token, indent, start_col, space);
    } else {
        try renderExpression(allocator, stream, tree, indent, start_col, param_decl.type_node, space);
    }
}

fn renderStatement(
    allocator: *mem.Allocator,
    stream: var,
    tree: *ast.Tree,
    indent: usize,
    start_col: *usize,
    base: *ast.Node,
) (@typeOf(stream).Child.Error || Error)!void {
    switch (base.id) {
        ast.Node.Id.VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", base);
            try renderVarDecl(allocator, stream, tree, indent, start_col, var_decl);
        },
        else => {
            if (base.requireSemiColon()) {
                try renderExpression(allocator, stream, tree, indent, start_col, base, Space.None);

                const semicolon_index = tree.nextToken(base.lastToken());
                assert(tree.tokens.at(semicolon_index).id == Token.Id.Semicolon);
                try renderToken(tree, stream, semicolon_index, indent, start_col, Space.Newline);
            } else {
                try renderExpression(allocator, stream, tree, indent, start_col, base, Space.Newline);
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
    stream: var,
    token_index: ast.TokenIndex,
    indent: usize,
    start_col: *usize,
    space: Space,
    token_skip_bytes: usize,
) (@typeOf(stream).Child.Error || Error)!void {
    if (space == Space.BlockStart) {
        if (start_col.* < indent + indent_delta)
            return renderToken(tree, stream, token_index, indent, start_col, Space.Space);
        try renderToken(tree, stream, token_index, indent, start_col, Space.Newline);
        try stream.writeByteNTimes(' ', indent);
        start_col.* = indent;
        return;
    }

    var token = tree.tokens.at(token_index);
    try stream.write(mem.trimRight(u8, tree.tokenSlicePtr(token)[token_skip_bytes..], " "));

    if (space == Space.NoComment)
        return;

    var next_token = tree.tokens.at(token_index + 1);

    if (space == Space.Comma) switch (next_token.id) {
        Token.Id.Comma => return renderToken(tree, stream, token_index + 1, indent, start_col, Space.Newline),
        Token.Id.LineComment => {
            try stream.write(", ");
            return renderToken(tree, stream, token_index + 1, indent, start_col, Space.Newline);
        },
        else => {
            if (tree.tokens.at(token_index + 2).id == Token.Id.MultilineStringLiteralLine) {
                try stream.write(",");
                return;
            } else {
                try stream.write(",\n");
                start_col.* = 0;
                return;
            }
        },
    };

    // Skip over same line doc comments
    var offset: usize = 1;
    if (next_token.id == Token.Id.DocComment) {
        const loc = tree.tokenLocationPtr(token.end, next_token);
        if (loc.line == 0) {
            offset += 1;
            next_token = tree.tokens.at(token_index + offset);
        }
    }

    if (next_token.id != Token.Id.LineComment) blk: {
        switch (space) {
            Space.None, Space.NoNewline => return,
            Space.Newline => {
                if (next_token.id == Token.Id.MultilineStringLiteralLine) {
                    return;
                } else {
                    try stream.write("\n");
                    start_col.* = 0;
                    return;
                }
            },
            Space.Space, Space.SpaceOrOutdent => {
                if (next_token.id == Token.Id.MultilineStringLiteralLine)
                    return;
                try stream.writeByte(' ');
                return;
            },
            Space.NoComment, Space.Comma, Space.BlockStart => unreachable,
        }
    }

    const comment_is_empty = mem.trimRight(u8, tree.tokenSlicePtr(next_token), " ").len == 2;
    if (comment_is_empty) {
        switch (space) {
            Space.Newline => {
                try stream.writeByte('\n');
                start_col.* = 0;
                return;
            },
            else => {},
        }
    }

    var loc = tree.tokenLocationPtr(token.end, next_token);
    if (loc.line == 0) {
        try stream.print(" {}", mem.trimRight(u8, tree.tokenSlicePtr(next_token), " "));
        offset = 2;
        token = next_token;
        next_token = tree.tokens.at(token_index + offset);
        if (next_token.id != Token.Id.LineComment) {
            switch (space) {
                Space.None, Space.Space => {
                    try stream.writeByte('\n');
                    const after_comment_token = tree.tokens.at(token_index + offset);
                    const next_line_indent = switch (after_comment_token.id) {
                        Token.Id.RParen, Token.Id.RBrace, Token.Id.RBracket => indent,
                        else => indent + indent_delta,
                    };
                    try stream.writeByteNTimes(' ', next_line_indent);
                    start_col.* = next_line_indent;
                },
                Space.SpaceOrOutdent => {
                    try stream.writeByte('\n');
                    try stream.writeByteNTimes(' ', indent);
                    start_col.* = indent;
                },
                Space.Newline => {
                    if (next_token.id == Token.Id.MultilineStringLiteralLine) {
                        return;
                    } else {
                        try stream.write("\n");
                        start_col.* = 0;
                        return;
                    }
                },
                Space.NoNewline => {},
                Space.NoComment, Space.Comma, Space.BlockStart => unreachable,
            }
            return;
        }
        loc = tree.tokenLocationPtr(token.end, next_token);
    }

    while (true) {
        assert(loc.line != 0);
        const newline_count = if (loc.line == 1) u8(1) else u8(2);
        try stream.writeByteNTimes('\n', newline_count);
        try stream.writeByteNTimes(' ', indent);
        try stream.write(mem.trimRight(u8, tree.tokenSlicePtr(next_token), " "));

        offset += 1;
        token = next_token;
        next_token = tree.tokens.at(token_index + offset);
        if (next_token.id != Token.Id.LineComment) {
            switch (space) {
                Space.Newline => {
                    if (next_token.id == Token.Id.MultilineStringLiteralLine) {
                        return;
                    } else {
                        try stream.write("\n");
                        start_col.* = 0;
                        return;
                    }
                },
                Space.None, Space.Space => {
                    try stream.writeByte('\n');

                    const after_comment_token = tree.tokens.at(token_index + offset);
                    const next_line_indent = switch (after_comment_token.id) {
                        Token.Id.RParen, Token.Id.RBrace, Token.Id.RBracket => indent - indent_delta,
                        else => indent,
                    };
                    try stream.writeByteNTimes(' ', next_line_indent);
                    start_col.* = next_line_indent;
                },
                Space.SpaceOrOutdent => {
                    try stream.writeByte('\n');
                    try stream.writeByteNTimes(' ', indent);
                    start_col.* = indent;
                },
                Space.NoNewline => {},
                Space.NoComment, Space.Comma, Space.BlockStart => unreachable,
            }
            return;
        }
        loc = tree.tokenLocationPtr(token.end, next_token);
    }
}

fn renderToken(
    tree: *ast.Tree,
    stream: var,
    token_index: ast.TokenIndex,
    indent: usize,
    start_col: *usize,
    space: Space,
) (@typeOf(stream).Child.Error || Error)!void {
    return renderTokenOffset(tree, stream, token_index, indent, start_col, space, 0);
}

fn renderDocComments(
    tree: *ast.Tree,
    stream: var,
    node: var,
    indent: usize,
    start_col: *usize,
) (@typeOf(stream).Child.Error || Error)!void {
    const comment = node.doc_comments orelse return;
    var it = comment.lines.iterator(0);
    const first_token = node.firstToken();
    while (it.next()) |line_token_index| {
        if (line_token_index.* < first_token) {
            try renderToken(tree, stream, line_token_index.*, indent, start_col, Space.Newline);
            try stream.writeByteNTimes(' ', indent);
        } else {
            try renderToken(tree, stream, line_token_index.*, indent, start_col, Space.NoComment);
            try stream.write("\n");
            try stream.writeByteNTimes(' ', indent);
        }
    }
}

fn nodeIsBlock(base: *const ast.Node) bool {
    return switch (base.id) {
        ast.Node.Id.Block,
        ast.Node.Id.If,
        ast.Node.Id.For,
        ast.Node.Id.While,
        ast.Node.Id.Switch,
        => true,
        else => false,
    };
}

fn nodeCausesSliceOpSpace(base: *ast.Node) bool {
    const infix_op = base.cast(ast.Node.InfixOp) orelse return false;
    return switch (infix_op.op) {
        ast.Node.InfixOp.Op.Period => false,
        else => true,
    };
}
