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

pub fn render(allocator: &mem.Allocator, stream: var, tree: &ast.Tree) (@typeOf(stream).Child.Error || Error)!void {
    comptime assert(@typeId(@typeOf(stream)) == builtin.TypeId.Pointer);

    // render all the line comments at the beginning of the file
    var tok_it = tree.tokens.iterator(0);
    while (tok_it.next()) |token| {
        if (token.id != Token.Id.LineComment) break;
        try stream.print("{}\n", tree.tokenSlicePtr(token));
        if (tok_it.peek()) |next_token| {
            const loc = tree.tokenLocationPtr(token.end, next_token);
            if (loc.line >= 2) {
                try stream.writeByte('\n');
            }
        }
    }


    var it = tree.root_node.decls.iterator(0);
    while (it.next()) |decl| {
        try renderTopLevelDecl(allocator, stream, tree, 0, decl.*);
        if (it.peek()) |next_decl| {
            try renderExtraNewline(tree, stream, next_decl.*);
        }
    }
}

fn renderExtraNewline(tree: &ast.Tree, stream: var, node: &ast.Node) !void {
    var first_token = node.firstToken();
    while (tree.tokens.at(first_token - 1).id == Token.Id.DocComment) {
        first_token -= 1;
    }
    const prev_token_end = tree.tokens.at(first_token - 1).end;
    const loc = tree.tokenLocation(prev_token_end, first_token);
    if (loc.line >= 2) {
        try stream.writeByte('\n');
    }
}

fn renderTopLevelDecl(allocator: &mem.Allocator, stream: var, tree: &ast.Tree, indent: usize, decl: &ast.Node) (@typeOf(stream).Child.Error || Error)!void {
    switch (decl.id) {
        ast.Node.Id.FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", decl);

            try renderDocComments(tree, stream, fn_proto, indent);

            if (fn_proto.body_node) |body_node| {
                try renderExpression(allocator, stream, tree, indent, decl, Space.Space);
                try renderExpression(allocator, stream, tree, indent, body_node, Space.Newline);
            } else {
                try renderExpression(allocator, stream, tree, indent, decl, Space.None);
                try renderToken(tree, stream, tree.nextToken(decl.lastToken()), indent, Space.Newline);
            }
        },

        ast.Node.Id.Use => {
            const use_decl = @fieldParentPtr(ast.Node.Use, "base", decl);

            if (use_decl.visib_token) |visib_token| {
                try renderToken(tree, stream, visib_token, indent, Space.Space); // pub
            }
            try renderToken(tree, stream, use_decl.use_token, indent, Space.Space); // use
            try renderExpression(allocator, stream, tree, indent, use_decl.expr, Space.None);
            try renderToken(tree, stream, use_decl.semicolon_token, indent, Space.Newline); // ;
        },

        ast.Node.Id.VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", decl);

            try renderDocComments(tree, stream, var_decl, indent);
            try renderVarDecl(allocator, stream, tree, indent, var_decl);
        },

        ast.Node.Id.TestDecl => {
            const test_decl = @fieldParentPtr(ast.Node.TestDecl, "base", decl);

            try renderDocComments(tree, stream, test_decl, indent);
            try renderToken(tree, stream, test_decl.test_token, indent, Space.Space);
            try renderExpression(allocator, stream, tree, indent, test_decl.name, Space.Space);
            try renderExpression(allocator, stream, tree, indent, test_decl.body_node, Space.Newline);
        },

        ast.Node.Id.StructField => {
            const field = @fieldParentPtr(ast.Node.StructField, "base", decl);

            try renderDocComments(tree, stream, field, indent);
            if (field.visib_token) |visib_token| {
                try renderToken(tree, stream, visib_token, indent, Space.Space); // pub
            }
            try renderToken(tree, stream, field.name_token, indent, Space.None); // name
            try renderToken(tree, stream, tree.nextToken(field.name_token), indent, Space.Space); // :
            try renderTrailingComma(allocator, stream, tree, indent, field.type_expr, Space.Newline); // type,
        },

        ast.Node.Id.UnionTag => {
            const tag = @fieldParentPtr(ast.Node.UnionTag, "base", decl);

            try renderDocComments(tree, stream, tag, indent);

            const name_space = if (tag.type_expr == null and tag.value_expr != null) Space.Space else Space.None;
            try renderToken(tree, stream, tag.name_token, indent, name_space); // name

            if (tag.type_expr) |type_expr| {
                try renderToken(tree, stream, tree.nextToken(tag.name_token), indent, Space.Space); // :

                const after_type_space = if (tag.value_expr == null) Space.None else Space.Space;
                try renderExpression(allocator, stream, tree, indent, type_expr, after_type_space);
            }

            if (tag.value_expr) |value_expr| {
                try renderToken(tree, stream, tree.prevToken(value_expr.firstToken()), indent, Space.Space); // =
                try renderExpression(allocator, stream, tree, indent, value_expr, Space.None);
            }

            try renderToken(tree, stream, tree.nextToken(decl.lastToken()), indent, Space.Newline); // ,
        },

        ast.Node.Id.EnumTag => {
            const tag = @fieldParentPtr(ast.Node.EnumTag, "base", decl);

            try renderDocComments(tree, stream, tag, indent);

            const after_name_space = if (tag.value == null) Space.None else Space.Space;
            try renderToken(tree, stream, tag.name_token, indent, after_name_space); // name

            if (tag.value) |value| {
                try renderToken(tree, stream, tree.nextToken(tag.name_token), indent, Space.Space); // =
                try renderExpression(allocator, stream, tree, indent, value, Space.None);
            }

            try renderToken(tree, stream, tree.nextToken(decl.lastToken()), indent, Space.Newline); // ,
        },

        ast.Node.Id.Comptime => {
            assert(!decl.requireSemiColon());
            try renderExpression(allocator, stream, tree, indent, decl, Space.Newline);
        },
        else => unreachable,
    }
}

fn renderExpression(allocator: &mem.Allocator, stream: var, tree: &ast.Tree, indent: usize, base: &ast.Node, space: Space) (@typeOf(stream).Child.Error || Error)!void {
    switch (base.id) {
        ast.Node.Id.Identifier => {
            const identifier = @fieldParentPtr(ast.Node.Identifier, "base", base);
            try renderToken(tree, stream, identifier.token, indent, space);
        },
        ast.Node.Id.Block => {
            const block = @fieldParentPtr(ast.Node.Block, "base", base);

            if (block.label) |label| {
                try renderToken(tree, stream, label, indent, Space.None);
                try renderToken(tree, stream, tree.nextToken(label), indent, Space.Space);
            }

            if (block.statements.len == 0) {
                try renderToken(tree, stream, block.lbrace, indent + indent_delta, Space.None);
                try renderToken(tree, stream, block.rbrace, indent, space);
            } else {
                const block_indent = indent + indent_delta;
                try renderToken(tree, stream, block.lbrace, block_indent, Space.Newline);

                var it = block.statements.iterator(0);
                while (it.next()) |statement| {
                    try stream.writeByteNTimes(' ', block_indent);
                    try renderStatement(allocator, stream, tree, block_indent, statement.*);

                    if (it.peek()) |next_statement| {
                        try renderExtraNewline(tree, stream, next_statement.*);
                    }
                }

                try stream.writeByteNTimes(' ', indent);
                try renderToken(tree, stream, block.rbrace, indent, space);
            }
        },
        ast.Node.Id.Defer => {
            const defer_node = @fieldParentPtr(ast.Node.Defer, "base", base);

            try renderToken(tree, stream, defer_node.defer_token, indent, Space.Space);
            try renderExpression(allocator, stream, tree, indent, defer_node.expr, space);
        },
        ast.Node.Id.Comptime => {
            const comptime_node = @fieldParentPtr(ast.Node.Comptime, "base", base);

            try renderToken(tree, stream, comptime_node.comptime_token, indent, Space.Space);
            try renderExpression(allocator, stream, tree, indent, comptime_node.expr, space);
        },

        ast.Node.Id.AsyncAttribute => {
            const async_attr = @fieldParentPtr(ast.Node.AsyncAttribute, "base", base);

            if (async_attr.allocator_type) |allocator_type| {
                try renderToken(tree, stream, async_attr.async_token, indent, Space.None);

                try renderToken(tree, stream, tree.nextToken(async_attr.async_token), indent, Space.None);
                try renderExpression(allocator, stream, tree, indent, allocator_type, Space.None);
                try renderToken(tree, stream, tree.nextToken(allocator_type.lastToken()), indent, space);
            } else {
                try renderToken(tree, stream, async_attr.async_token, indent, space);
            }
        },

        ast.Node.Id.Suspend => {
            const suspend_node = @fieldParentPtr(ast.Node.Suspend, "base", base);

            if (suspend_node.label) |label| {
                try renderToken(tree, stream, label, indent, Space.None);
                try renderToken(tree, stream, tree.nextToken(label), indent, Space.Space);
            }

            if (suspend_node.payload) |payload| {
                if (suspend_node.body) |body| {
                    try renderToken(tree, stream, suspend_node.suspend_token, indent, Space.Space);
                    try renderExpression(allocator, stream, tree, indent, payload, Space.Space);
                    try renderExpression(allocator, stream, tree, indent, body, space);
                } else {
                    try renderToken(tree, stream, suspend_node.suspend_token, indent, Space.Space);
                    try renderExpression(allocator, stream, tree, indent, payload, space);
                }
            } else if (suspend_node.body) |body| {
                try renderToken(tree, stream, suspend_node.suspend_token, indent, Space.Space);
                try renderExpression(allocator, stream, tree, indent, body, space);
            } else {
                try renderToken(tree, stream, suspend_node.suspend_token, indent, space);
            }
        },

        ast.Node.Id.InfixOp => {
            const infix_op_node = @fieldParentPtr(ast.Node.InfixOp, "base", base);

            const op_token = tree.tokens.at(infix_op_node.op_token);
            const op_space = switch (infix_op_node.op) {
                ast.Node.InfixOp.Op.Period, ast.Node.InfixOp.Op.ErrorUnion => Space.None,
                else => Space.Space,
            };
            try renderExpression(allocator, stream, tree, indent, infix_op_node.lhs, op_space);
            try renderToken(tree, stream, infix_op_node.op_token, indent, op_space);

            switch (infix_op_node.op) {
                ast.Node.InfixOp.Op.Catch => |maybe_payload| if (maybe_payload) |payload| {
                    try renderExpression(allocator, stream, tree, indent, payload, Space.Space);
                },
                else => {},
            }

            try renderExpression(allocator, stream, tree, indent, infix_op_node.rhs, space);
        },

        ast.Node.Id.PrefixOp => {
            const prefix_op_node = @fieldParentPtr(ast.Node.PrefixOp, "base", base);

            switch (prefix_op_node.op) {
                ast.Node.PrefixOp.Op.AddrOf => |addr_of_info| {
                    try renderToken(tree, stream, prefix_op_node.op_token, indent, Space.None); // &
                    if (addr_of_info.align_info) |align_info| {
                        const lparen_token = tree.prevToken(align_info.node.firstToken());
                        const align_token = tree.prevToken(lparen_token);

                        try renderToken(tree, stream, align_token, indent, Space.None); // align
                        try renderToken(tree, stream, lparen_token, indent, Space.None); // (

                        try renderExpression(allocator, stream, tree, indent, align_info.node, Space.None);

                        if (align_info.bit_range) |bit_range| {
                            const colon1 = tree.prevToken(bit_range.start.firstToken());
                            const colon2 = tree.prevToken(bit_range.end.firstToken());

                            try renderToken(tree, stream, colon1, indent, Space.None); // :
                            try renderExpression(allocator, stream, tree, indent, bit_range.start, Space.None);
                            try renderToken(tree, stream, colon2, indent, Space.None); // :
                            try renderExpression(allocator, stream, tree, indent, bit_range.end, Space.None);

                            const rparen_token = tree.nextToken(bit_range.end.lastToken());
                            try renderToken(tree, stream, rparen_token, indent, Space.Space); // )
                        } else {
                            const rparen_token = tree.nextToken(align_info.node.lastToken());
                            try renderToken(tree, stream, rparen_token, indent, Space.Space); // )
                        }
                    }
                    if (addr_of_info.const_token) |const_token| {
                        try renderToken(tree, stream, const_token, indent, Space.Space); // const
                    }
                    if (addr_of_info.volatile_token) |volatile_token| {
                        try renderToken(tree, stream, volatile_token, indent, Space.Space); // volatile
                    }
                },

                ast.Node.PrefixOp.Op.SliceType => |addr_of_info| {
                    try renderToken(tree, stream, prefix_op_node.op_token, indent, Space.None); // [
                    try renderToken(tree, stream, tree.nextToken(prefix_op_node.op_token), indent, Space.None); // ]

                    if (addr_of_info.align_info) |align_info| {
                        const lparen_token = tree.prevToken(align_info.node.firstToken());
                        const align_token = tree.prevToken(lparen_token);

                        try renderToken(tree, stream, align_token, indent, Space.None); // align
                        try renderToken(tree, stream, lparen_token, indent, Space.None); // (

                        try renderExpression(allocator, stream, tree, indent, align_info.node, Space.None);

                        if (align_info.bit_range) |bit_range| {
                            const colon1 = tree.prevToken(bit_range.start.firstToken());
                            const colon2 = tree.prevToken(bit_range.end.firstToken());

                            try renderToken(tree, stream, colon1, indent, Space.None); // :
                            try renderExpression(allocator, stream, tree, indent, bit_range.start, Space.None);
                            try renderToken(tree, stream, colon2, indent, Space.None); // :
                            try renderExpression(allocator, stream, tree, indent, bit_range.end, Space.None);

                            const rparen_token = tree.nextToken(bit_range.end.lastToken());
                            try renderToken(tree, stream, rparen_token, indent, Space.Space); // )
                        } else {
                            const rparen_token = tree.nextToken(align_info.node.lastToken());
                            try renderToken(tree, stream, rparen_token, indent, Space.Space); // )
                        }
                    }
                    if (addr_of_info.const_token) |const_token| {
                        try renderToken(tree, stream, const_token, indent, Space.Space);
                    }
                    if (addr_of_info.volatile_token) |volatile_token| {
                        try renderToken(tree, stream, volatile_token, indent, Space.Space);
                    }
                },

                ast.Node.PrefixOp.Op.ArrayType => |array_index| {
                    try renderToken(tree, stream, prefix_op_node.op_token, indent, Space.None); // [
                    try renderExpression(allocator, stream, tree, indent, array_index, Space.None);
                    try renderToken(tree, stream, tree.nextToken(array_index.lastToken()), indent, Space.None); // ]
                },
                ast.Node.PrefixOp.Op.BitNot,
                ast.Node.PrefixOp.Op.BoolNot,
                ast.Node.PrefixOp.Op.Negation,
                ast.Node.PrefixOp.Op.NegationWrap,
                ast.Node.PrefixOp.Op.UnwrapMaybe,
                ast.Node.PrefixOp.Op.MaybeType,
                ast.Node.PrefixOp.Op.PointerType => {
                    try renderToken(tree, stream, prefix_op_node.op_token, indent, Space.None);
                },

                ast.Node.PrefixOp.Op.Try,
                ast.Node.PrefixOp.Op.Await,
                ast.Node.PrefixOp.Op.Cancel,
                ast.Node.PrefixOp.Op.Resume => {
                    try renderToken(tree, stream, prefix_op_node.op_token, indent, Space.Space);
                },
            }

            try renderExpression(allocator, stream, tree, indent, prefix_op_node.rhs, space);
        },

        ast.Node.Id.SuffixOp => {
            const suffix_op = @fieldParentPtr(ast.Node.SuffixOp, "base", base);

            switch (suffix_op.op) {
                @TagType(ast.Node.SuffixOp.Op).Call => |*call_info| {
                    if (call_info.async_attr) |async_attr| {
                        try renderExpression(allocator, stream, tree, indent, &async_attr.base, Space.Space);
                    }

                    try renderExpression(allocator, stream, tree, indent, suffix_op.lhs, Space.None);

                    const lparen = tree.nextToken(suffix_op.lhs.lastToken());
                    try renderToken(tree, stream, lparen, indent, Space.None);

                    var it = call_info.params.iterator(0);
                    while (it.next()) |param_node| {
                        try renderExpression(allocator, stream, tree, indent, param_node.*, Space.None);

                        if (it.peek() != null) {
                            const comma = tree.nextToken(param_node.*.lastToken());
                            try renderToken(tree, stream, comma, indent, Space.Space);
                        }
                    }

                    try renderToken(tree, stream, suffix_op.rtoken, indent, space);
                },

                ast.Node.SuffixOp.Op.ArrayAccess => |index_expr| {
                    const lbracket = tree.prevToken(index_expr.firstToken());
                    const rbracket = tree.nextToken(index_expr.lastToken());

                    try renderExpression(allocator, stream, tree, indent, suffix_op.lhs, Space.None);
                    try renderToken(tree, stream, lbracket, indent, Space.None); // [
                    try renderExpression(allocator, stream, tree, indent, index_expr, Space.None);
                    try renderToken(tree, stream, rbracket, indent, space); // ]
                },

                ast.Node.SuffixOp.Op.Deref => {
                    try renderExpression(allocator, stream, tree, indent, suffix_op.lhs, Space.None);
                    try renderToken(tree, stream, tree.prevToken(suffix_op.rtoken), indent, Space.None); // .
                    try renderToken(tree, stream, suffix_op.rtoken, indent, space); // *
                },

                @TagType(ast.Node.SuffixOp.Op).Slice => |range| {
                    try renderExpression(allocator, stream, tree, indent, suffix_op.lhs, Space.None);

                    const lbracket = tree.prevToken(range.start.firstToken());
                    const dotdot = tree.nextToken(range.start.lastToken());

                    try renderToken(tree, stream, lbracket, indent, Space.None); // [
                    try renderExpression(allocator, stream, tree, indent, range.start, Space.None);
                    try renderToken(tree, stream, dotdot, indent, Space.None); // ..
                    if (range.end) |end| {
                        try renderExpression(allocator, stream, tree, indent, end, Space.None);
                    }
                    try renderToken(tree, stream, suffix_op.rtoken, indent, space); // ]
                },

                ast.Node.SuffixOp.Op.StructInitializer => |*field_inits| {
                    const lbrace = tree.nextToken(suffix_op.lhs.lastToken());

                    if (field_inits.len == 0) {
                        try renderExpression(allocator, stream, tree, indent, suffix_op.lhs, Space.None);
                        try renderToken(tree, stream, lbrace, indent, Space.None);
                        try renderToken(tree, stream, suffix_op.rtoken, indent, space);
                        return;
                    }

                    if (field_inits.len == 1) blk: {
                        const field_init = ??field_inits.at(0).*.cast(ast.Node.FieldInitializer);

                        if (field_init.expr.cast(ast.Node.SuffixOp)) |nested_suffix_op| {
                            if (nested_suffix_op.op == ast.Node.SuffixOp.Op.StructInitializer) {
                                break :blk;
                            }
                        }

                        try renderExpression(allocator, stream, tree, indent, suffix_op.lhs, Space.None);
                        try renderToken(tree, stream, lbrace, indent, Space.Space);
                        try renderExpression(allocator, stream, tree, indent, &field_init.base, Space.Space);
                        try renderToken(tree, stream, suffix_op.rtoken, indent, space);
                        return;
                    }

                    try renderExpression(allocator, stream, tree, indent, suffix_op.lhs, Space.None);
                    try renderToken(tree, stream, lbrace, indent, Space.Newline);

                    const new_indent = indent + indent_delta;

                    var it = field_inits.iterator(0);
                    while (it.next()) |field_init| {
                        try stream.writeByteNTimes(' ', new_indent);

                        if (it.peek()) |next_field_init| {
                            try renderExpression(allocator, stream, tree, new_indent, field_init.*, Space.None);

                            const comma = tree.nextToken(field_init.*.lastToken());
                            try renderToken(tree, stream, comma, new_indent, Space.Newline);

                            try renderExtraNewline(tree, stream, next_field_init.*);
                        } else {
                            try renderTrailingComma(allocator, stream, tree, new_indent, field_init.*, Space.Newline);
                        }
                    }

                    try stream.writeByteNTimes(' ', indent);
                    try renderToken(tree, stream, suffix_op.rtoken, indent, space);
                },

                ast.Node.SuffixOp.Op.ArrayInitializer => |*exprs| {
                    const lbrace = tree.nextToken(suffix_op.lhs.lastToken());

                    if (exprs.len == 0) {
                        try renderExpression(allocator, stream, tree, indent, suffix_op.lhs, Space.None);
                        try renderToken(tree, stream, lbrace, indent, Space.None);
                        try renderToken(tree, stream, suffix_op.rtoken, indent, space);
                        return;
                    }
                    if (exprs.len == 1) {
                        const expr = exprs.at(0).*;

                        try renderExpression(allocator, stream, tree, indent, suffix_op.lhs, Space.None);
                        try renderToken(tree, stream, lbrace, indent, Space.None);
                        try renderExpression(allocator, stream, tree, indent, expr, Space.None);
                        try renderToken(tree, stream, suffix_op.rtoken, indent, space);
                        return;
                    }

                    try renderExpression(allocator, stream, tree, indent, suffix_op.lhs, Space.None);

                    const new_indent = indent + indent_delta;
                    try renderToken(tree, stream, lbrace, new_indent, Space.Newline);

                    var it = exprs.iterator(0);
                    while (it.next()) |expr| {
                        try stream.writeByteNTimes(' ', new_indent);

                        if (it.peek()) |next_expr| {
                            try renderExpression(allocator, stream, tree, new_indent, expr.*, Space.None);

                            const comma = tree.nextToken(expr.*.lastToken());
                            try renderToken(tree, stream, comma, new_indent, Space.Newline); // ,

                            try renderExtraNewline(tree, stream, next_expr.*);
                        } else {
                            try renderTrailingComma(allocator, stream, tree, new_indent, expr.*, Space.Newline);
                        }
                    }

                    try stream.writeByteNTimes(' ', indent);
                    try renderToken(tree, stream, suffix_op.rtoken, indent, space);
                },
            }
        },

        ast.Node.Id.ControlFlowExpression => {
            const flow_expr = @fieldParentPtr(ast.Node.ControlFlowExpression, "base", base);

            switch (flow_expr.kind) {
                ast.Node.ControlFlowExpression.Kind.Break => |maybe_label| {
                    const kw_space = if (maybe_label != null or flow_expr.rhs != null) Space.Space else space;
                    try renderToken(tree, stream, flow_expr.ltoken, indent, kw_space);
                    if (maybe_label) |label| {
                        const colon = tree.nextToken(flow_expr.ltoken);
                        try renderToken(tree, stream, colon, indent, Space.None);

                        const expr_space = if (flow_expr.rhs != null) Space.Space else space;
                        try renderExpression(allocator, stream, tree, indent, label, expr_space);
                    }
                },
                ast.Node.ControlFlowExpression.Kind.Continue => |maybe_label| {
                    const kw_space = if (maybe_label != null or flow_expr.rhs != null) Space.Space else space;
                    try renderToken(tree, stream, flow_expr.ltoken, indent, kw_space);
                    if (maybe_label) |label| {
                        const colon = tree.nextToken(flow_expr.ltoken);
                        try renderToken(tree, stream, colon, indent, Space.None);

                        const expr_space = if (flow_expr.rhs != null) Space.Space else space;
                        try renderExpression(allocator, stream, tree, indent, label, space);
                    }
                },
                ast.Node.ControlFlowExpression.Kind.Return => {
                    const kw_space = if (flow_expr.rhs != null) Space.Space else space;
                    try renderToken(tree, stream, flow_expr.ltoken, indent, kw_space);
                },
            }

            if (flow_expr.rhs) |rhs| {
                try renderExpression(allocator, stream, tree, indent, rhs, space);
            }
        },

        ast.Node.Id.Payload => {
            const payload = @fieldParentPtr(ast.Node.Payload, "base", base);

            try renderToken(tree, stream, payload.lpipe, indent, Space.None);
            try renderExpression(allocator, stream, tree, indent, payload.error_symbol, Space.None);
            try renderToken(tree, stream, payload.rpipe, indent, space);
        },

        ast.Node.Id.PointerPayload => {
            const payload = @fieldParentPtr(ast.Node.PointerPayload, "base", base);

            try renderToken(tree, stream, payload.lpipe, indent, Space.None);
            if (payload.ptr_token) |ptr_token| {
                try renderToken(tree, stream, ptr_token, indent, Space.None);
            }
            try renderExpression(allocator, stream, tree, indent, payload.value_symbol, Space.None);
            try renderToken(tree, stream, payload.rpipe, indent, space);
        },

        ast.Node.Id.PointerIndexPayload => {
            const payload = @fieldParentPtr(ast.Node.PointerIndexPayload, "base", base);

            try renderToken(tree, stream, payload.lpipe, indent, Space.None);
            if (payload.ptr_token) |ptr_token| {
                try renderToken(tree, stream, ptr_token, indent, Space.None);
            }
            try renderExpression(allocator, stream, tree, indent, payload.value_symbol, Space.None);

            if (payload.index_symbol) |index_symbol| {
                const comma = tree.nextToken(payload.value_symbol.lastToken());

                try renderToken(tree, stream, comma, indent, Space.Space);
                try renderExpression(allocator, stream, tree, indent, index_symbol, Space.None);
            }

            try renderToken(tree, stream, payload.rpipe, indent, space);
        },

        ast.Node.Id.GroupedExpression => {
            const grouped_expr = @fieldParentPtr(ast.Node.GroupedExpression, "base", base);

            try renderToken(tree, stream, grouped_expr.lparen, indent, Space.None);
            try renderExpression(allocator, stream, tree, indent, grouped_expr.expr, Space.None);
            try renderToken(tree, stream, grouped_expr.rparen, indent, space);
        },

        ast.Node.Id.FieldInitializer => {
            const field_init = @fieldParentPtr(ast.Node.FieldInitializer, "base", base);

            try renderToken(tree, stream, field_init.period_token, indent, Space.None); // .
            try renderToken(tree, stream, field_init.name_token, indent, Space.Space); // name
            try renderToken(tree, stream, tree.nextToken(field_init.name_token), indent, Space.Space); // =
            try renderExpression(allocator, stream, tree, indent, field_init.expr, space);
        },

        ast.Node.Id.IntegerLiteral => {
            const integer_literal = @fieldParentPtr(ast.Node.IntegerLiteral, "base", base);
            try renderToken(tree, stream, integer_literal.token, indent, space);
        },
        ast.Node.Id.FloatLiteral => {
            const float_literal = @fieldParentPtr(ast.Node.FloatLiteral, "base", base);
            try renderToken(tree, stream, float_literal.token, indent, space);
        },
        ast.Node.Id.StringLiteral => {
            const string_literal = @fieldParentPtr(ast.Node.StringLiteral, "base", base);
            try renderToken(tree, stream, string_literal.token, indent, space);
        },
        ast.Node.Id.CharLiteral => {
            const char_literal = @fieldParentPtr(ast.Node.CharLiteral, "base", base);
            try renderToken(tree, stream, char_literal.token, indent, space);
        },
        ast.Node.Id.BoolLiteral => {
            const bool_literal = @fieldParentPtr(ast.Node.CharLiteral, "base", base);
            try renderToken(tree, stream, bool_literal.token, indent, space);
        },
        ast.Node.Id.NullLiteral => {
            const null_literal = @fieldParentPtr(ast.Node.NullLiteral, "base", base);
            try renderToken(tree, stream, null_literal.token, indent, space);
        },
        ast.Node.Id.ThisLiteral => {
            const this_literal = @fieldParentPtr(ast.Node.ThisLiteral, "base", base);
            try renderToken(tree, stream, this_literal.token, indent, space);
        },
        ast.Node.Id.Unreachable => {
            const unreachable_node = @fieldParentPtr(ast.Node.Unreachable, "base", base);
            try renderToken(tree, stream, unreachable_node.token, indent, space);
        },
        ast.Node.Id.ErrorType => {
            const error_type = @fieldParentPtr(ast.Node.ErrorType, "base", base);
            try renderToken(tree, stream, error_type.token, indent, space);
        },
        ast.Node.Id.VarType => {
            const var_type = @fieldParentPtr(ast.Node.VarType, "base", base);
            try renderToken(tree, stream, var_type.token, indent, space);
        },
        ast.Node.Id.ContainerDecl => {
            const container_decl = @fieldParentPtr(ast.Node.ContainerDecl, "base", base);

            if (container_decl.layout_token) |layout_token| {
                try renderToken(tree, stream, layout_token, indent, Space.Space);
            }

            switch (container_decl.init_arg_expr) {
                ast.Node.ContainerDecl.InitArg.None => {
                    try renderToken(tree, stream, container_decl.kind_token, indent, Space.Space); // union
                },
                ast.Node.ContainerDecl.InitArg.Enum => |enum_tag_type| {
                    try renderToken(tree, stream, container_decl.kind_token, indent, Space.None); // union

                    const lparen = tree.nextToken(container_decl.kind_token);
                    const enum_token = tree.nextToken(lparen);

                    try renderToken(tree, stream, lparen, indent, Space.None); // (
                    try renderToken(tree, stream, enum_token, indent, Space.None); // enum

                    if (enum_tag_type) |expr| {
                        try renderToken(tree, stream, tree.nextToken(enum_token), indent, Space.None); // (
                        try renderExpression(allocator, stream, tree, indent, expr, Space.None);

                        const rparen = tree.nextToken(expr.lastToken());
                        try renderToken(tree, stream, rparen, indent, Space.None); // )
                        try renderToken(tree, stream, tree.nextToken(rparen), indent, Space.Space); // )
                    } else {
                        try renderToken(tree, stream, tree.nextToken(enum_token), indent, Space.Space); // )
                    }
                },
                ast.Node.ContainerDecl.InitArg.Type => |type_expr| {
                    try renderToken(tree, stream, container_decl.kind_token, indent, Space.None); // union

                    const lparen = tree.nextToken(container_decl.kind_token);
                    const rparen = tree.nextToken(type_expr.lastToken());

                    try renderToken(tree, stream, lparen, indent, Space.None); // (
                    try renderExpression(allocator, stream, tree, indent, type_expr, Space.None);
                    try renderToken(tree, stream, rparen, indent, Space.Space); // )
                },
            }

            if (container_decl.fields_and_decls.len == 0) {
                try renderToken(tree, stream, container_decl.lbrace_token, indent + indent_delta, Space.None); // {
                try renderToken(tree, stream, container_decl.rbrace_token, indent, space); // }
            } else {
                const new_indent = indent + indent_delta;
                try renderToken(tree, stream, container_decl.lbrace_token, new_indent, Space.Newline); // {

                var it = container_decl.fields_and_decls.iterator(0);
                while (it.next()) |decl| {
                    try stream.writeByteNTimes(' ', new_indent);
                    try renderTopLevelDecl(allocator, stream, tree, new_indent, decl.*);

                    if (it.peek()) |next_decl| {
                        try renderExtraNewline(tree, stream, next_decl.*);
                    }
                }

                try stream.writeByteNTimes(' ', indent);
                try renderToken(tree, stream, container_decl.rbrace_token, indent, space); // }
            }
        },

        ast.Node.Id.ErrorSetDecl => {
            const err_set_decl = @fieldParentPtr(ast.Node.ErrorSetDecl, "base", base);

            const lbrace = tree.nextToken(err_set_decl.error_token);

            if (err_set_decl.decls.len == 0) {
                try renderToken(tree, stream, err_set_decl.error_token, indent, Space.None);
                try renderToken(tree, stream, lbrace, indent, Space.None);
                try renderToken(tree, stream, err_set_decl.rbrace_token, indent, space);
                return;
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

                try renderToken(tree, stream, err_set_decl.error_token, indent, Space.None); // error
                try renderToken(tree, stream, lbrace, indent, Space.None); // {
                try renderExpression(allocator, stream, tree, indent, node, Space.None);
                try renderToken(tree, stream, err_set_decl.rbrace_token, indent, space); // }
                return;
            }

            try renderToken(tree, stream, err_set_decl.error_token, indent, Space.None); // error
            try renderToken(tree, stream, lbrace, indent, Space.Newline); // {
            const new_indent = indent + indent_delta;

            var it = err_set_decl.decls.iterator(0);
            while (it.next()) |node| {
                try stream.writeByteNTimes(' ', new_indent);

                if (it.peek()) |next_node| {
                    try renderExpression(allocator, stream, tree, new_indent, node.*, Space.None);
                    try renderToken(tree, stream, tree.nextToken(node.*.lastToken()), new_indent, Space.Newline); // ,

                    try renderExtraNewline(tree, stream, next_node.*);
                } else {
                    try renderTrailingComma(allocator, stream, tree, new_indent, node.*, Space.Newline);
                }
            }

            try stream.writeByteNTimes(' ', indent);
            try renderToken(tree, stream, err_set_decl.rbrace_token, indent, space); // }
        },

        ast.Node.Id.ErrorTag => {
            const tag = @fieldParentPtr(ast.Node.ErrorTag, "base", base);

            try renderDocComments(tree, stream, tag, indent);
            try renderToken(tree, stream, tag.name_token, indent, space); // name
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
                try renderToken(tree, stream, t, indent, Space.None);
                skip_first_indent = false;
            }
            try stream.writeByteNTimes(' ', indent);
        },
        ast.Node.Id.UndefinedLiteral => {
            const undefined_literal = @fieldParentPtr(ast.Node.UndefinedLiteral, "base", base);
            try renderToken(tree, stream, undefined_literal.token, indent, space);
        },

        ast.Node.Id.BuiltinCall => {
            const builtin_call = @fieldParentPtr(ast.Node.BuiltinCall, "base", base);

            try renderToken(tree, stream, builtin_call.builtin_token, indent, Space.None); // @name
            try renderToken(tree, stream, tree.nextToken(builtin_call.builtin_token), indent, Space.None); // (

            var it = builtin_call.params.iterator(0);
            while (it.next()) |param_node| {
                try renderExpression(allocator, stream, tree, indent, param_node.*, Space.None);

                if (it.peek() != null) {
                    const comma_token = tree.nextToken(param_node.*.lastToken());
                    try renderToken(tree, stream, comma_token, indent, Space.Space); // ,
                }
            }
            try renderToken(tree, stream, builtin_call.rparen_token, indent, space); // )
        },

        ast.Node.Id.FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", base);

            if (fn_proto.visib_token) |visib_token_index| {
                const visib_token = tree.tokens.at(visib_token_index);
                assert(visib_token.id == Token.Id.Keyword_pub or visib_token.id == Token.Id.Keyword_export);

                try renderToken(tree, stream, visib_token_index, indent, Space.Space); // pub
            }

            if (fn_proto.extern_export_inline_token) |extern_export_inline_token| {
                try renderToken(tree, stream, extern_export_inline_token, indent, Space.Space); // extern/export
            }

            if (fn_proto.lib_name) |lib_name| {
                try renderExpression(allocator, stream, tree, indent, lib_name, Space.Space);
            }

            if (fn_proto.cc_token) |cc_token| {
                try renderToken(tree, stream, cc_token, indent, Space.Space); // stdcallcc
            }

            if (fn_proto.async_attr) |async_attr| {
                try renderExpression(allocator, stream, tree, indent, &async_attr.base, Space.Space);
            }

            if (fn_proto.name_token) |name_token| blk: {
                try renderToken(tree, stream, fn_proto.fn_token, indent, Space.Space); // fn
                try renderToken(tree, stream, name_token, indent, Space.None); // name
                try renderToken(tree, stream, tree.nextToken(name_token), indent, Space.None); // (
            } else blk: {
                try renderToken(tree, stream, fn_proto.fn_token, indent, Space.None); // fn
                try renderToken(tree, stream, tree.nextToken(fn_proto.fn_token), indent, Space.None); // (
            }

            var it = fn_proto.params.iterator(0);
            while (it.next()) |param_decl_node| {
                try renderParamDecl(allocator, stream, tree, indent, param_decl_node.*);

                if (it.peek() != null) {
                    const comma = tree.nextToken(param_decl_node.*.lastToken());
                    try renderToken(tree, stream, comma, indent, Space.Space); // ,
                }
            }

            const rparen = tree.prevToken(switch (fn_proto.return_type) {
                ast.Node.FnProto.ReturnType.Explicit => |node| node.firstToken(),
                ast.Node.FnProto.ReturnType.InferErrorSet => |node| tree.prevToken(node.firstToken()),
            });
            try renderToken(tree, stream, rparen, indent, Space.Space); // )

            if (fn_proto.align_expr) |align_expr| {
                const align_rparen = tree.nextToken(align_expr.lastToken());
                const align_lparen = tree.prevToken(align_expr.firstToken());
                const align_kw = tree.prevToken(align_lparen);

                try renderToken(tree, stream, align_kw, indent, Space.None); // align
                try renderToken(tree, stream, align_lparen, indent, Space.None); // (
                try renderExpression(allocator, stream, tree, indent, align_expr, Space.None);
                try renderToken(tree, stream, align_rparen, indent, Space.Space); // )
            }

            switch (fn_proto.return_type) {
                ast.Node.FnProto.ReturnType.Explicit => |node| {
                    try renderExpression(allocator, stream, tree, indent, node, space);
                },
                ast.Node.FnProto.ReturnType.InferErrorSet => |node| {
                    try renderToken(tree, stream, tree.prevToken(node.firstToken()), indent, Space.None); // !
                    try renderExpression(allocator, stream, tree, indent, node, space);
                },
            }
        },

        ast.Node.Id.PromiseType => {
            const promise_type = @fieldParentPtr(ast.Node.PromiseType, "base", base);

            if (promise_type.result) |result| {
                try renderToken(tree, stream, promise_type.promise_token, indent, Space.None); // promise
                try renderToken(tree, stream, result.arrow_token, indent, Space.None); // ->
                try renderExpression(allocator, stream, tree, indent, result.return_type, space);
            } else {
                try renderToken(tree, stream, promise_type.promise_token, indent, space); // promise
            }
        },

        ast.Node.Id.DocComment => unreachable, // doc comments are attached to nodes

        ast.Node.Id.Switch => {
            const switch_node = @fieldParentPtr(ast.Node.Switch, "base", base);

            try renderToken(tree, stream, switch_node.switch_token, indent, Space.Space); // switch
            try renderToken(tree, stream, tree.nextToken(switch_node.switch_token), indent, Space.None); // (

            const rparen = tree.nextToken(switch_node.expr.lastToken());
            const lbrace = tree.nextToken(rparen);

            if (switch_node.cases.len == 0) {
                try renderExpression(allocator, stream, tree, indent, switch_node.expr, Space.None);
                try renderToken(tree, stream, rparen, indent, Space.Space); // )
                try renderToken(tree, stream, lbrace, indent, Space.None); // {
                try renderToken(tree, stream, switch_node.rbrace, indent, space); // }
                return;
            }

            try renderExpression(allocator, stream, tree, indent, switch_node.expr, Space.None);

            try renderToken(tree, stream, rparen, indent, Space.Space); // )
            try renderToken(tree, stream, lbrace, indent, Space.Newline); // {

            const new_indent = indent + indent_delta;

            var it = switch_node.cases.iterator(0);
            while (it.next()) |node| {
                try stream.writeByteNTimes(' ', new_indent);
                try renderExpression(allocator, stream, tree, new_indent, node.*, Space.Newline);

                if (it.peek()) |next_node| {
                    try renderExtraNewline(tree, stream, next_node.*);
                }
            }

            try stream.writeByteNTimes(' ', indent);
            try renderToken(tree, stream, switch_node.rbrace, indent, space); // }
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
                        try renderExpression(allocator, stream, tree, indent, node.*, Space.None);

                        const comma_token = tree.nextToken(node.*.lastToken());
                        try renderToken(tree, stream, comma_token, indent, Space.Space); // ,
                        try renderExtraNewline(tree, stream, next_node.*);
                    } else {
                        try renderExpression(allocator, stream, tree, indent, node.*, Space.Space);
                    }
                }
            } else {
                var it = switch_case.items.iterator(0);
                while (true) {
                    const node = ??it.next();
                    if (it.peek()) |next_node| {
                        try renderExpression(allocator, stream, tree, indent, node.*, Space.None);

                        const comma_token = tree.nextToken(node.*.lastToken());
                        try renderToken(tree, stream, comma_token, indent, Space.Newline); // ,
                        try renderExtraNewline(tree, stream, next_node.*);
                        try stream.writeByteNTimes(' ', indent);
                    } else {
                        try renderTrailingComma(allocator, stream, tree, indent, node.*, Space.Space);
                        break;
                    }
                }
            }

            try renderToken(tree, stream, switch_case.arrow_token, indent, Space.Space); // =>

            if (switch_case.payload) |payload| {
                try renderExpression(allocator, stream, tree, indent, payload, Space.Space);
            }

            try renderTrailingComma(allocator, stream, tree, indent, switch_case.expr, space);
        },
        ast.Node.Id.SwitchElse => {
            const switch_else = @fieldParentPtr(ast.Node.SwitchElse, "base", base);
            try renderToken(tree, stream, switch_else.token, indent, space);
        },
        ast.Node.Id.Else => {
            const else_node = @fieldParentPtr(ast.Node.Else, "base", base);

            const block_body = switch (else_node.body.id) {
                ast.Node.Id.Block,
                ast.Node.Id.If,
                ast.Node.Id.For,
                ast.Node.Id.While,
                ast.Node.Id.Switch => true,
                else => false,
            };

            const after_else_space = if (block_body or else_node.payload != null) Space.Space else Space.Newline;
            try renderToken(tree, stream, else_node.else_token, indent, after_else_space);

            if (else_node.payload) |payload| {
                const payload_space = if (block_body) Space.Space else Space.Newline;
                try renderExpression(allocator, stream, tree, indent, payload, Space.Space);
            }

            if (block_body) {
                try renderExpression(allocator, stream, tree, indent, else_node.body, space);
            } else {
                try stream.writeByteNTimes(' ', indent + indent_delta);
                try renderExpression(allocator, stream, tree, indent, else_node.body, space);
            }
        },

        ast.Node.Id.While => {
            const while_node = @fieldParentPtr(ast.Node.While, "base", base);

            if (while_node.label) |label| {
                try renderToken(tree, stream, label, indent, Space.None); // label
                try renderToken(tree, stream, tree.nextToken(label), indent, Space.Space); // :
            }

            if (while_node.inline_token) |inline_token| {
                try renderToken(tree, stream, inline_token, indent, Space.Space); // inline
            }

            try renderToken(tree, stream, while_node.while_token, indent, Space.Space); // while
            try renderToken(tree, stream, tree.nextToken(while_node.while_token), indent, Space.None); // (
            try renderExpression(allocator, stream, tree, indent, while_node.condition, Space.None);

            {
                const rparen = tree.nextToken(while_node.condition.lastToken());
                const rparen_space = if (while_node.payload != null or while_node.continue_expr != null or
                    while_node.body.id == ast.Node.Id.Block) Space.Space else Space.Newline;
                try renderToken(tree, stream, rparen, indent, rparen_space); // )
            }

            if (while_node.payload) |payload| {
                try renderExpression(allocator, stream, tree, indent, payload, Space.Space);
            }

            if (while_node.continue_expr) |continue_expr| {
                const rparen = tree.nextToken(continue_expr.lastToken());
                const lparen = tree.prevToken(continue_expr.firstToken());
                const colon = tree.prevToken(lparen);

                try renderToken(tree, stream, colon, indent, Space.Space); // :
                try renderToken(tree, stream, lparen, indent, Space.None); // (

                try renderExpression(allocator, stream, tree, indent, continue_expr, Space.None);

                const rparen_space = if (while_node.body.id == ast.Node.Id.Block) Space.Space else Space.Newline;
                try renderToken(tree, stream, rparen, indent, rparen_space); // )
            }

            const body_space = blk: {
                if (while_node.@"else" != null) {
                    break :blk if (while_node.body.id == ast.Node.Id.Block) Space.Space else Space.Newline;
                } else {
                    break :blk space;
                }
            };

            if (while_node.body.id == ast.Node.Id.Block) {
                try renderExpression(allocator, stream, tree, indent, while_node.body, body_space);
            } else {
                try stream.writeByteNTimes(' ', indent + indent_delta);
                try renderExpression(allocator, stream, tree, indent, while_node.body, body_space);
            }

            if (while_node.@"else") |@"else"| {
                if (while_node.body.id == ast.Node.Id.Block) {
                } else {
                    try stream.writeByteNTimes(' ', indent);
                }

                try renderExpression(allocator, stream, tree, indent, &@"else".base, space);
            }
        },

        ast.Node.Id.For => {
            const for_node = @fieldParentPtr(ast.Node.For, "base", base);

            if (for_node.label) |label| {
                try renderToken(tree, stream, label, indent, Space.None); // label
                try renderToken(tree, stream, tree.nextToken(label), indent, Space.Space); // :
            }

            if (for_node.inline_token) |inline_token| {
                try renderToken(tree, stream, inline_token, indent, Space.Space); // inline
            }

            try renderToken(tree, stream, for_node.for_token, indent, Space.Space); // for
            try renderToken(tree, stream, tree.nextToken(for_node.for_token), indent, Space.None); // (
            try renderExpression(allocator, stream, tree, indent, for_node.array_expr, Space.None);

            const rparen = tree.nextToken(for_node.array_expr.lastToken());
            const rparen_space = if (for_node.payload != null or
                for_node.body.id == ast.Node.Id.Block) Space.Space else Space.Newline;
            try renderToken(tree, stream, rparen, indent, rparen_space); // )

            if (for_node.payload) |payload| {
                const payload_space = if (for_node.body.id == ast.Node.Id.Block) Space.Space else Space.Newline;
                try renderExpression(allocator, stream, tree, indent, payload, payload_space);
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
                try renderExpression(allocator, stream, tree, indent, for_node.body, body_space);
            } else {
                try stream.writeByteNTimes(' ', indent + indent_delta);
                try renderExpression(allocator, stream, tree, indent, for_node.body, body_space);
            }

            if (for_node.@"else") |@"else"| {
                if (for_node.body.id != ast.Node.Id.Block) {
                    try stream.writeByteNTimes(' ', indent);
                }

                try renderExpression(allocator, stream, tree, indent, &@"else".base, space);
            }
        },

        ast.Node.Id.If => {
            const if_node = @fieldParentPtr(ast.Node.If, "base", base);

            try renderToken(tree, stream, if_node.if_token, indent, Space.Space);
            try renderToken(tree, stream, tree.prevToken(if_node.condition.firstToken()), indent, Space.None);

            try renderExpression(allocator, stream, tree, indent, if_node.condition, Space.None);
            try renderToken(tree, stream, tree.nextToken(if_node.condition.lastToken()), indent, Space.Space);

            if (if_node.payload) |payload| {
                try renderExpression(allocator, stream, tree, indent, payload, Space.Space);
            }

            switch (if_node.body.id) {
                ast.Node.Id.Block,
                ast.Node.Id.If,
                ast.Node.Id.For,
                ast.Node.Id.While,
                ast.Node.Id.Switch => {
                    if (if_node.@"else") |@"else"| {
                        if (if_node.body.id == ast.Node.Id.Block) {
                            try renderExpression(allocator, stream, tree, indent, if_node.body, Space.Space);
                        } else {
                            try renderExpression(allocator, stream, tree, indent, if_node.body, Space.Newline);
                            try stream.writeByteNTimes(' ', indent);
                        }

                        try renderExpression(allocator, stream, tree, indent, &@"else".base, space);
                    } else {
                        try renderExpression(allocator, stream, tree, indent, if_node.body, space);
                    }
                },
                else => {
                    if (if_node.@"else") |@"else"| {
                        try renderExpression(allocator, stream, tree, indent, if_node.body, Space.Space);
                        try renderToken(tree, stream, @"else".else_token, indent, Space.Space);

                        if (@"else".payload) |payload| {
                            try renderExpression(allocator, stream, tree, indent, payload, Space.Space);
                        }

                        try renderExpression(allocator, stream, tree, indent, @"else".body, space);
                    } else {
                        try renderExpression(allocator, stream, tree, indent, if_node.body, space);
                    }
                },
            }
        },

        ast.Node.Id.Asm => {
            const asm_node = @fieldParentPtr(ast.Node.Asm, "base", base);

            try renderToken(tree, stream, asm_node.asm_token, indent, Space.Space); // asm

            if (asm_node.volatile_token) |volatile_token| {
                try renderToken(tree, stream, volatile_token, indent, Space.Space); // volatile
                try renderToken(tree, stream, tree.nextToken(volatile_token), indent, Space.None); // (
            } else {
                try renderToken(tree, stream, tree.nextToken(asm_node.asm_token), indent, Space.None); // (
            }

            if (asm_node.outputs.len == 0 and asm_node.inputs.len == 0 and asm_node.clobbers.len == 0) {
                try renderExpression(allocator, stream, tree, indent, asm_node.template, Space.None);
                try renderToken(tree, stream, asm_node.rparen, indent, space);
                return;
            }

            try renderExpression(allocator, stream, tree, indent, asm_node.template, Space.Newline);

            const indent_once = indent + indent_delta;
            try stream.writeByteNTimes(' ', indent_once);

            const colon1 = tree.nextToken(asm_node.template.lastToken());
            const indent_extra = indent_once + 2;

            const colon2 = if (asm_node.outputs.len == 0) blk: {
                try renderToken(tree, stream, colon1, indent, Space.Newline); // :
                try stream.writeByteNTimes(' ', indent_once);

                break :blk tree.nextToken(colon1);
            } else blk: {
                try renderToken(tree, stream, colon1, indent, Space.Space); // :

                var it = asm_node.outputs.iterator(0);
                while (true) {
                    const asm_output = ??it.next();
                    const node = &(asm_output.*).base;

                    if (it.peek()) |next_asm_output| {
                        try renderExpression(allocator, stream, tree, indent_extra, node, Space.None);
                        const next_node = &(next_asm_output.*).base;

                        const comma = tree.prevToken(next_asm_output.*.firstToken());
                        try renderToken(tree, stream, comma, indent_extra, Space.Newline); // ,
                        try renderExtraNewline(tree, stream, next_node);

                        try stream.writeByteNTimes(' ', indent_extra);
                    } else if (asm_node.inputs.len == 0 and asm_node.clobbers.len == 0) {
                        try renderExpression(allocator, stream, tree, indent_extra, node, Space.Newline);
                        try stream.writeByteNTimes(' ', indent);
                        try renderToken(tree, stream, asm_node.rparen, indent, space);
                        return;
                    } else {
                        try renderExpression(allocator, stream, tree, indent_extra, node, Space.Newline);
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
                try renderToken(tree, stream, colon2, indent, Space.Newline); // :
                try stream.writeByteNTimes(' ', indent_once);

                break :blk tree.nextToken(colon2);
            } else blk: {
                try renderToken(tree, stream, colon2, indent, Space.Space); // :

                var it = asm_node.inputs.iterator(0);
                while (true) {
                    const asm_input = ??it.next();
                    const node = &(asm_input.*).base;

                    if (it.peek()) |next_asm_input| {
                        try renderExpression(allocator, stream, tree, indent_extra, node, Space.None);
                        const next_node = &(next_asm_input.*).base;

                        const comma = tree.prevToken(next_asm_input.*.firstToken());
                        try renderToken(tree, stream, comma, indent_extra, Space.Newline); // ,
                        try renderExtraNewline(tree, stream, next_node);

                        try stream.writeByteNTimes(' ', indent_extra);
                    } else if (asm_node.clobbers.len == 0) {
                        try renderExpression(allocator, stream, tree, indent_extra, node, Space.Newline);
                        try stream.writeByteNTimes(' ', indent);
                        try renderToken(tree, stream, asm_node.rparen, indent, space); // )
                        return;
                    } else {
                        try renderExpression(allocator, stream, tree, indent_extra, node, Space.Newline);
                        try stream.writeByteNTimes(' ', indent_once);
                        const comma_or_colon = tree.nextToken(node.lastToken());
                        break :blk switch (tree.tokens.at(comma_or_colon).id) {
                            Token.Id.Comma => tree.nextToken(comma_or_colon),
                            else => comma_or_colon,
                        };
                    }
                }
            };

            try renderToken(tree, stream, colon3, indent, Space.Space); // :

            var it = asm_node.clobbers.iterator(0);
            while (true) {
                const clobber_token = ??it.next();

                if (it.peek() == null) {
                    try renderToken(tree, stream, clobber_token.*, indent_once, Space.Newline);
                    try stream.writeByteNTimes(' ', indent);
                    try renderToken(tree, stream, asm_node.rparen, indent, space);
                    return;
                } else {
                    try renderToken(tree, stream, clobber_token.*, indent_once, Space.None);
                    const comma = tree.nextToken(clobber_token.*);
                    try renderToken(tree, stream, comma, indent_once, Space.Space); // ,
                }
            }
        },

        ast.Node.Id.AsmInput => {
            const asm_input = @fieldParentPtr(ast.Node.AsmInput, "base", base);

            try stream.write("[");
            try renderExpression(allocator, stream, tree, indent, asm_input.symbolic_name, Space.None);
            try stream.write("] ");
            try renderExpression(allocator, stream, tree, indent, asm_input.constraint, Space.None);
            try stream.write(" (");
            try renderExpression(allocator, stream, tree, indent, asm_input.expr, Space.None);
            try renderToken(tree, stream, asm_input.lastToken(), indent, space); // )
        },

        ast.Node.Id.AsmOutput => {
            const asm_output = @fieldParentPtr(ast.Node.AsmOutput, "base", base);

            try stream.write("[");
            try renderExpression(allocator, stream, tree, indent, asm_output.symbolic_name, Space.None);
            try stream.write("] ");
            try renderExpression(allocator, stream, tree, indent, asm_output.constraint, Space.None);
            try stream.write(" (");

            switch (asm_output.kind) {
                ast.Node.AsmOutput.Kind.Variable => |variable_name| {
                    try renderExpression(allocator, stream, tree, indent, &variable_name.base, Space.None);
                },
                ast.Node.AsmOutput.Kind.Return => |return_type| {
                    try stream.write("-> ");
                    try renderExpression(allocator, stream, tree, indent, return_type, Space.None);
                },
            }

            try renderToken(tree, stream, asm_output.lastToken(), indent, space); // )
        },

        ast.Node.Id.StructField,
        ast.Node.Id.UnionTag,
        ast.Node.Id.EnumTag,
        ast.Node.Id.Root,
        ast.Node.Id.VarDecl,
        ast.Node.Id.Use,
        ast.Node.Id.TestDecl,
        ast.Node.Id.ParamDecl => unreachable,
    }
}

fn renderVarDecl(allocator: &mem.Allocator, stream: var, tree: &ast.Tree, indent: usize,
    var_decl: &ast.Node.VarDecl) (@typeOf(stream).Child.Error || Error)!void
{
    if (var_decl.visib_token) |visib_token| {
        try renderToken(tree, stream, visib_token, indent, Space.Space); // pub
    }

    if (var_decl.extern_export_token) |extern_export_token| {
        try renderToken(tree, stream, extern_export_token, indent, Space.Space); // extern

        if (var_decl.lib_name) |lib_name| {
            try renderExpression(allocator, stream, tree, indent, lib_name, Space.Space); // "lib"
        }
    }

    if (var_decl.comptime_token) |comptime_token| {
        try renderToken(tree, stream, comptime_token, indent, Space.Space); // comptime
    }

    try renderToken(tree, stream, var_decl.mut_token, indent, Space.Space); // var

    const name_space = if (var_decl.type_node == null and (var_decl.align_node != null or
        var_decl.init_node != null)) Space.Space else Space.None;
    try renderToken(tree, stream, var_decl.name_token, indent, name_space);

    if (var_decl.type_node) |type_node| {
        try renderToken(tree, stream, tree.nextToken(var_decl.name_token), indent, Space.Space);
        const s = if (var_decl.align_node != null or var_decl.init_node != null) Space.Space else Space.None;
        try renderExpression(allocator, stream, tree, indent, type_node, s);
    }

    if (var_decl.align_node) |align_node| {
        const lparen = tree.prevToken(align_node.firstToken());
        const align_kw = tree.prevToken(lparen);
        const rparen = tree.nextToken(align_node.lastToken());
        try renderToken(tree, stream, align_kw, indent, Space.None); // align
        try renderToken(tree, stream, lparen, indent, Space.None); // (
        try renderExpression(allocator, stream, tree, indent, align_node, Space.None);
        const s = if (var_decl.init_node != null) Space.Space else Space.None;
        try renderToken(tree, stream, rparen, indent, s); // )
    }

    if (var_decl.init_node) |init_node| {
        const s = if (init_node.id == ast.Node.Id.MultilineStringLiteral) Space.None else Space.Space;
        try renderToken(tree, stream, var_decl.eq_token, indent, s); // =
        try renderExpression(allocator, stream, tree, indent, init_node, Space.None);
    }

    try renderToken(tree, stream, var_decl.semicolon_token, indent, Space.Newline);
}

fn renderParamDecl(allocator: &mem.Allocator, stream: var, tree: &ast.Tree, indent: usize, base: &ast.Node) (@typeOf(stream).Child.Error || Error)!void {
    const param_decl = @fieldParentPtr(ast.Node.ParamDecl, "base", base);

    if (param_decl.comptime_token) |comptime_token| {
        try renderToken(tree, stream, comptime_token, indent, Space.Space);
    }
    if (param_decl.noalias_token) |noalias_token| {
        try renderToken(tree, stream, noalias_token, indent, Space.Space);
    }
    if (param_decl.name_token) |name_token| {
        try renderToken(tree, stream, name_token, indent, Space.None);
        try renderToken(tree, stream, tree.nextToken(name_token), indent, Space.Space); // :
    }
    if (param_decl.var_args_token) |var_args_token| {
        try renderToken(tree, stream, var_args_token, indent, Space.None);
    } else {
        try renderExpression(allocator, stream, tree, indent, param_decl.type_node, Space.None);
    }
}

fn renderStatement(allocator: &mem.Allocator, stream: var, tree: &ast.Tree, indent: usize, base: &ast.Node) (@typeOf(stream).Child.Error || Error)!void {
    switch (base.id) {
        ast.Node.Id.VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", base);
            try renderVarDecl(allocator, stream, tree, indent, var_decl);
        },
        else => {
            if (base.requireSemiColon()) {
                try renderExpression(allocator, stream, tree, indent, base, Space.None);

                const semicolon_index = tree.nextToken(base.lastToken());
                assert(tree.tokens.at(semicolon_index).id == Token.Id.Semicolon);
                try renderToken(tree, stream, semicolon_index, indent, Space.Newline);
            } else {
                try renderExpression(allocator, stream, tree, indent, base, Space.Newline);
            }
        },
    }
}

const Space = enum {
    None,
    Newline,
    Space,
    NoNewline,
    NoIndent,
    NoComment,
};

fn renderToken(tree: &ast.Tree, stream: var, token_index: ast.TokenIndex, indent: usize, space: Space) (@typeOf(stream).Child.Error || Error)!void {
    var token = tree.tokens.at(token_index);
    try stream.write(tree.tokenSlicePtr(token));

    if (space == Space.NoComment) return;

    var next_token = tree.tokens.at(token_index + 1);
    if (next_token.id != Token.Id.LineComment) {
        switch (space) {
            Space.None, Space.NoNewline, Space.NoIndent => return,
            Space.Newline => return stream.write("\n"),
            Space.Space => return stream.writeByte(' '),
            Space.NoComment => unreachable,
        }
    }

    var loc = tree.tokenLocationPtr(token.end, next_token);
    var offset: usize = 1;
    if (loc.line == 0) {
        try stream.print(" {}", tree.tokenSlicePtr(next_token));
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
                },
                Space.Newline, Space.NoIndent => try stream.write("\n"),
                Space.NoNewline => {},
                Space.NoComment => unreachable,
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
        try stream.write(tree.tokenSlicePtr(next_token));

        offset += 1;
        token = next_token;
        next_token = tree.tokens.at(token_index + offset);
        if (next_token.id != Token.Id.LineComment) {
            switch (space) {
                Space.Newline, Space.NoIndent => try stream.writeByte('\n'),
                Space.None, Space.Space => {
                    try stream.writeByte('\n');

                    const after_comment_token = tree.tokens.at(token_index + offset);
                    const next_line_indent = switch (after_comment_token.id) {
                        Token.Id.RParen, Token.Id.RBrace, Token.Id.RBracket => indent,
                        else => indent,
                    };
                    try stream.writeByteNTimes(' ', next_line_indent);
                },
                Space.NoNewline => {},
                Space.NoComment => unreachable,
            }
            return;
        }
        loc = tree.tokenLocationPtr(token.end, next_token);
    }
}

fn renderDocComments(tree: &ast.Tree, stream: var, node: var, indent: usize) (@typeOf(stream).Child.Error || Error)!void {
    const comment = node.doc_comments ?? return;
    var it = comment.lines.iterator(0);
    while (it.next()) |line_token_index| {
        try renderToken(tree, stream, line_token_index.*, indent, Space.Newline);
        try stream.writeByteNTimes(' ', indent);
    }
}

fn renderTrailingComma(allocator: &mem.Allocator, stream: var, tree: &ast.Tree, indent: usize, base: &ast.Node,
    space: Space) (@typeOf(stream).Child.Error || Error)!void
{
    const end_token = base.lastToken() + 1;
    switch (tree.tokens.at(end_token).id) {
        Token.Id.Comma => {
            try renderExpression(allocator, stream, tree, indent, base, Space.None);
            try renderToken(tree, stream, end_token, indent, space); // ,
        },
        Token.Id.LineComment => {
            try renderExpression(allocator, stream, tree, indent, base, Space.NoComment);
            try stream.write(", ");
            try renderToken(tree, stream, end_token, indent, space);
        },
        else => {
            try renderExpression(allocator, stream, tree, indent, base, Space.None);
            try stream.write(",\n");
            assert(space == Space.Newline);
        },
    }
}
