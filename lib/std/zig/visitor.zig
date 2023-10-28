const std = @import("../std.zig");
const Ast = std.zig.Ast;
const assert = std.debug.assert;
const Index = Ast.Node.Index;
const Tag = Ast.Node.Tag;

pub const VisitResult = enum(u8) {
    Break = 0,
    Continue,
    Recurse,
};

fn assertNodeIndexValid(ast: *const Ast, child: Index, parent: Index) void {
    if (child == 0 or child >= ast.nodes.len) {
        const tag = ast.nodes.items(.tag)[parent];
        std.log.err("zig: ast.visit child index {} from parent {} {} is out of range or will create a loop", .{ child, parent, tag });
        unreachable;
    }
}

pub fn visit(ast: *const Ast, parent: Index, comptime T: type, callback: *const fn (ast: *const Ast, node: Index, parent: Index, data: T) VisitResult, data: T) void {
    const tag = ast.nodes.items(.tag)[parent];
    const d = ast.nodes.items(.data)[parent];
    switch (tag) {
        // Leaf nodes have no children
        .@"continue", .string_literal, .multiline_string_literal, .char_literal, .number_literal, .enum_literal, .anyframe_literal, .unreachable_literal, .error_value, .error_set_decl, .identifier => {},

        // Recurse to both lhs and rhs, neither are optional
        .for_simple,
        .if_simple,
        .equal_equal,
        .bang_equal,
        .less_than,
        .greater_than,
        .less_or_equal,
        .greater_or_equal,
        .assign_mul,
        .assign_div,
        .assign_mod,
        .assign_add,
        .assign_sub,
        .assign_shl,
        .assign_shl_sat,
        .assign_shr,
        .assign_bit_and,
        .assign_bit_xor,
        .assign_bit_or,
        .assign_mul_wrap,
        .assign_add_wrap,
        .assign_sub_wrap,
        .assign_mul_sat,
        .assign_add_sat,
        .assign_sub_sat,
        .assign,
        .merge_error_sets,
        .mul,
        .div,
        .mod,
        .array_mult,
        .mul_wrap,
        .mul_sat,
        .add,
        .sub,
        .array_cat,
        .add_wrap,
        .sub_wrap,
        .add_sat,
        .sub_sat,
        .shl,
        .shl_sat,
        .shr,
        .bit_and,
        .bit_xor,
        .bit_or,
        .@"orelse",
        .bool_and,
        .bool_or,
        .array_type,
        .slice_open,
        .array_access,
        .array_init_one_comma,
        .struct_init_one_comma,
        .switch_range,
        .while_simple,
        .error_union,
        => {
            {
                const child = d.lhs;
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => {},
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
            {
                const child = d.rhs;
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => {},
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
        },
        // Only walk data lhs
        .asm_simple, .asm_output, .asm_input, .bool_not, .negation, .bit_not, .negation_wrap, .address_of, .@"try", .@"await", .optional_type, .deref, .@"comptime", .@"nosuspend", .@"resume", .@"return", .@"suspend", .@"usingnamespace", .field_access, .unwrap_optional, .grouped_expression => if (d.lhs != 0) {
            const child = d.lhs;
            assertNodeIndexValid(ast, child, parent);
            switch (callback(ast, child, parent, data)) {
                .Break => return,
                .Continue => {},
                .Recurse => visit(ast, child, T, callback, data),
            }
        },

        // Only walk data rhs
        .@"defer", .@"errdefer", .@"break", .anyframe_type, .test_decl => if (d.rhs != 0) {
            const child = d.rhs;
            assertNodeIndexValid(ast, child, parent);
            switch (callback(ast, child, parent, data)) {
                .Break => return,
                .Continue => {},
                .Recurse => visit(ast, child, T, callback, data),
            }
        },

        // For all of these walk lhs and/or rhs of the node's data
        .for_range, // rhs is optional
        .struct_init_one,
        .struct_init_dot_two,
        .struct_init_dot_two_comma,
        .simple_var_decl,
        .aligned_var_decl,
        .container_decl_two,
        .container_decl_two_trailing,
        .container_field_init,
        .container_field_align,
        .call_one,
        .call_one_comma,
        .async_call_one,
        .async_call_one_comma,
        .builtin_call_two,
        .builtin_call_two_comma,
        .ptr_type_aligned,
        .ptr_type_sentinel,
        .array_init_one,
        .array_init_dot_two,
        .array_init_dot_two_comma,
        .tagged_union_two,
        .tagged_union_two_trailing,
        .@"catch",
        .switch_case_one,
        .switch_case_inline_one,
        .fn_proto_simple,
        .fn_decl,
        .block_two,
        .block_two_semicolon,
        => {
            if (d.lhs != 0) {
                const child = d.lhs;
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => {},
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
            if (d.rhs != 0) {
                const child = d.rhs;
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => {},
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
        },
        // For these walk all sub list nodes in extra data
        .struct_init_dot, .struct_init_dot_comma, .builtin_call, .builtin_call_comma, .container_decl, .container_decl_trailing, .tagged_union, .tagged_union_trailing, .array_init_dot, .array_init_dot_comma, .block, .block_semicolon => {
            for (ast.extra_data[d.lhs..d.rhs]) |child| {
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => continue,
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
        },

        // Special nodes

        // Visit lhs and rhs as sub range
        .call, .call_comma, .async_call, .async_call_comma, .container_decl_arg, .container_decl_arg_trailing, .tagged_union_enum_tag, .tagged_union_enum_tag_trailing, .@"switch", .switch_comma, .array_init, .array_init_comma, .struct_init, .struct_init_comma => {
            {
                const child = d.lhs;
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => {},
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
            const field_range = ast.extraData(d.rhs, Ast.Node.SubRange);
            for (ast.extra_data[field_range.start..field_range.end]) |child| {
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => continue,
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
        },
        // Visit lhs sub range, then rhs
        .switch_case, .switch_case_inline, .fn_proto_multi => {
            const field_range = ast.extraData(d.lhs, Ast.Node.SubRange);
            for (ast.extra_data[field_range.start..field_range.end]) |child| {
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => continue,
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
            const child = d.rhs;
            assertNodeIndexValid(ast, child, parent);
            switch (callback(ast, child, parent, data)) {
                .Break => return,
                .Continue => {},
                .Recurse => visit(ast, child, T, callback, data),
            }
        },
        .while_cont => {
            const while_data = ast.extraData(d.rhs, Ast.Node.WhileCont);
            inline for (.{ d.lhs, while_data.cont_expr, while_data.then_expr }) |child| {
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => {},
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
        },
        .@"while" => {
            const while_data = ast.extraData(d.rhs, Ast.Node.While);
            inline for (.{ d.lhs, while_data.cont_expr, while_data.then_expr, while_data.else_expr }) |child| {
                if (child != 0) { // cont expr part may be omitted
                    assertNodeIndexValid(ast, child, parent);
                    switch (callback(ast, child, parent, data)) {
                        .Break => return,
                        .Continue => {},
                        .Recurse => visit(ast, child, T, callback, data),
                    }
                }
            }
        },
        .@"if" => {
            const if_data = ast.extraData(d.rhs, Ast.Node.If);
            inline for (.{ d.lhs, if_data.then_expr, if_data.else_expr }) |child| {
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => {},
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
        },

        .@"for" => {
            // See std.zig.Ast.forFull
            const extra = @as(Ast.Node.For, @bitCast(d.rhs));
            for (ast.extra_data[d.lhs..][0..extra.inputs]) |child| {
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => continue,
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }

            // For body
            {
                const child = ast.extra_data[d.lhs + extra.inputs];
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => {},
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }

            // Else body
            if (extra.has_else) {
                const child = ast.extra_data[d.lhs + extra.inputs + 1];
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => {},
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
        },
        .fn_proto, .fn_proto_one => |t| {
            var buf: [1]Ast.Node.Index = undefined;
            const fn_proto = if (t == .fn_proto_one)
                ast.fnProtoOne(&buf, parent).ast
            else
                ast.fnProto(parent).ast;
            for (fn_proto.params) |child| {
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => continue,
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
            inline for (.{ d.rhs, fn_proto.align_expr, fn_proto.addrspace_expr, fn_proto.section_expr, fn_proto.callconv_expr }) |child| {
                if (child != 0) {
                    assertNodeIndexValid(ast, child, parent);
                    switch (callback(ast, child, parent, data)) {
                        .Break => return,
                        .Continue => {},
                        .Recurse => visit(ast, child, T, callback, data),
                    }
                }
            }
        },
        .global_var_decl => {
            const var_data = ast.extraData(d.lhs, Ast.Node.GlobalVarDecl);
            inline for (.{ var_data.type_node, var_data.align_node, var_data.addrspace_node, var_data.section_node, d.rhs }) |child| {
                if (child != 0) {
                    assertNodeIndexValid(ast, child, parent);
                    switch (callback(ast, child, parent, data)) {
                        .Break => return,
                        .Continue => {},
                        .Recurse => visit(ast, child, T, callback, data),
                    }
                }
            }
        },
        .local_var_decl => {
            const var_data = ast.extraData(d.lhs, Ast.Node.LocalVarDecl);
            inline for (.{ var_data.type_node, var_data.align_node, d.rhs }) |child| {
                if (child != 0) {
                    assertNodeIndexValid(ast, child, parent);
                    switch (callback(ast, child, parent, data)) {
                        .Break => return,
                        .Continue => {},
                        .Recurse => visit(ast, child, T, callback, data),
                    }
                }
            }
        },

        .array_type_sentinel => {
            const array_data = ast.extraData(d.rhs, Ast.Node.ArrayTypeSentinel);
            inline for (.{ d.lhs, array_data.sentinel, array_data.elem_type }) |child| {
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => {},
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
        },
        .container_field => {
            const field_data = ast.extraData(d.rhs, Ast.Node.ContainerField);
            inline for (.{ d.lhs, field_data.align_expr, field_data.value_expr }) |child| {
                if (child != 0) {
                    assertNodeIndexValid(ast, child, parent);
                    switch (callback(ast, child, parent, data)) {
                        .Break => return,
                        .Continue => {},
                        .Recurse => visit(ast, child, T, callback, data),
                    }
                }
            }
        },
        .slice => {
            const slice_data = ast.extraData(d.rhs, Ast.Node.Slice);
            inline for (.{ d.lhs, slice_data.start, slice_data.end }) |child| {
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => {},
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
        },
        .slice_sentinel => {
            const slice_data = ast.extraData(d.rhs, Ast.Node.SliceSentinel);
            inline for (.{ d.lhs, slice_data.start, slice_data.end, slice_data.sentinel }) |child| {
                if (child != 0) { // slice end may be 0
                    assertNodeIndexValid(ast, child, parent);
                    switch (callback(ast, child, parent, data)) {
                        .Break => return,
                        .Continue => {},
                        .Recurse => visit(ast, child, T, callback, data),
                    }
                }
            }
        },
        .@"asm" => {
            {
                const child = d.lhs;
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => {},
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
            const asm_data = ast.extraData(d.rhs, Ast.Node.Asm);
            for (ast.extra_data[asm_data.items_start..asm_data.items_end]) |child| {
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => continue,
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
        },
        .root => for (ast.rootDecls()) |child| {
            assertNodeIndexValid(ast, child, parent);
            switch (callback(ast, child, parent, data)) {
                .Break => return,
                .Continue => continue,
                .Recurse => visit(ast, child, T, callback, data),
            }
        },
        .ptr_type => {
            const ptr_data = ast.extraData(d.lhs, Ast.Node.PtrType);
            inline for (.{ d.rhs, ptr_data.sentinel, ptr_data.align_node, ptr_data.addrspace_node }) |child| {
                if (child != 0) {
                    assertNodeIndexValid(ast, child, parent);
                    switch (callback(ast, child, parent, data)) {
                        .Break => return,
                        .Continue => {},
                        .Recurse => visit(ast, child, T, callback, data),
                    }
                }
            }
        },
        .ptr_type_bit_range => {
            const ptr_data = ast.extraData(d.lhs, Ast.Node.PtrTypeBitRange);
            inline for (.{ d.rhs, ptr_data.sentinel, ptr_data.align_node, ptr_data.addrspace_node, ptr_data.bit_range_start, ptr_data.bit_range_end }) |child| {
                if (child != 0) {
                    assertNodeIndexValid(ast, child, parent);
                    switch (callback(ast, child, parent, data)) {
                        .Break => return,
                        .Continue => {},
                        .Recurse => visit(ast, child, T, callback, data),
                    }
                }
            }
        },
        .assign_destructure => {
            const elem_count = ast.extra_data[d.lhs];
            // var decls (const a, const b, etc..)
            for (ast.extra_data[d.lhs + 1 ..][0..elem_count]) |child| {
                assertNodeIndexValid(ast, child, parent);
                switch (callback(ast, child, parent, data)) {
                    .Break => return,
                    .Continue => continue,
                    .Recurse => visit(ast, child, T, callback, data),
                }
            }
            // The value to destructure
            const child = d.rhs;
            assertNodeIndexValid(ast, child, parent);
            switch (callback(ast, child, parent, data)) {
                .Break => return,
                .Continue => {},
                .Recurse => visit(ast, child, T, callback, data),
            }
        },
    }
    return;
}

fn indexOfNodeWithTag(ast: Ast, start_token: Index, tag: Tag) ?Index {
    if (start_token < ast.nodes.len) {
        const tags = ast.nodes.items(.tag);
        for (start_token..ast.nodes.len) |i| {
            if (tags[i] == tag) {
                return @intCast(i);
            }
        }
    }
    return null;
}

fn visitAll(ast: *const Ast, child: Index, parent: Index, nodes: *std.ArrayList(Index)) VisitResult {
    _ = ast;
    _ = parent;
    const remaining = nodes.unusedCapacitySlice();
    if (remaining.len > 0) {
        remaining[0] = child;
        nodes.items.len += 1;
        return .Recurse;
    }
    return .Break;
}

fn testVisit(source: [:0]const u8, tag: Tag) !void {
    const allocator = std.testing.allocator;
    var ast = try Ast.parse(allocator, source, .zig);
    defer ast.deinit(allocator);

    var stdout = std.io.getStdOut().writer();
    if (ast.errors.len > 0) {
        try stdout.writeAll("Parse error:\n");
        for (ast.errors) |parse_error| {
            try ast.renderError(parse_error, stdout);
        }
        return error.ParseError;
    }

    var nodes = try std.ArrayList(Index).initCapacity(allocator, ast.nodes.len + 1);
    nodes.appendAssumeCapacity(0); // Callback does not call on initial node
    defer nodes.deinit();

    ast.visit(0, *std.ArrayList(Index), visitAll, &nodes);
    const visited = nodes.items[0..nodes.items.len];

    try std.testing.expectEqual(ast.nodes.len, visited.len);

    // Sort visited nodes and make sure each was hit
    std.mem.sort(Index, visited, {}, std.sort.asc(Index));
    for (visited, 0..) |a, b| {
        try std.testing.expectEqual(@as(Index, @intCast(b)), a);
    }

    // If given, make sure the tag is actually used in the source parsed
    if (indexOfNodeWithTag(ast, 0, tag) == null) {
        std.log.err("Expected tag {} not found in ast\n", .{tag});
        assert(false);
    }
}

test "basic-visit" {
    // Test that the visitor reaches each node
    try testVisit("test { }", .test_decl);
    try testVisit("test { var a = 0; }", .simple_var_decl);
    try testVisit("test { var a: u8 align(4) = 0; }", .local_var_decl);
    try testVisit("export const isr_vector linksection(\"isr_vector\") = [_]ISR{};", .global_var_decl);
    try testVisit("test { var a align(4) = 0; }", .aligned_var_decl);
    try testVisit("test { var a = 0; errdefer {a = 1;} }", .@"errdefer");
    try testVisit("test { errdefer |err| { @panic(@errorName(err));} }", .@"errdefer");
    try testVisit("test { var a = 0; defer { a = 1; } }", .@"defer");
    try testVisit("test { foo() catch {}; }", .@"catch");
    try testVisit("test { foo() catch |err| { @panic(@errorName(err)); }; }", .@"catch");
    try testVisit("const A = {var a: u8 = 0;}; test { A.a = 1; }", .field_access);
    try testVisit("test{ a.? = 0; }", .unwrap_optional);
    try testVisit("test { var a = 0 == 1; }", .equal_equal);
    try testVisit("test { var a = 0 != 1; }", .bang_equal);
    try testVisit("test { var a = 0 < 1; }", .less_than);
    try testVisit("test { var a = 0 <= 1; }", .less_or_equal);
    try testVisit("test { var a = 0 >= 1; }", .greater_or_equal);
    try testVisit("test { var a = 0 > 1; }", .greater_than);
    try testVisit("test { var a = 0; a *= 1; }", .assign_mul);
    try testVisit("test { var a = 0; a /= 1; }", .assign_div);
    try testVisit("test { var a = 0; a %= 1; }", .assign_mod);
    try testVisit("test { var a = 0; a += 1; }", .assign_add);
    try testVisit("test { var a = 0; a -= 1; }", .assign_sub);
    try testVisit("test { var a = 1; a <<= 1; }", .assign_shl);
    try testVisit("test { var a = 1; a <<|= 1; }", .assign_shl_sat);
    try testVisit("test { var a = 2; a >>= 1; }", .assign_shr);
    try testVisit("test { var a = 2; a &= 3; }", .assign_bit_and);
    try testVisit("test { var a = 2; a ^= 1; }", .assign_bit_xor);
    try testVisit("test { var a = 2; a |= 1; }", .assign_bit_or);
    try testVisit("test { var a = 2; a *%= 0xFF; }", .assign_mul_wrap);
    try testVisit("test { var a = 2; a +%= 0xFF; }", .assign_add_wrap);
    try testVisit("test { var a = 2; a -%= 0xFF; }", .assign_sub_wrap);
    try testVisit("test { var a = 2; a = 1; }", .assign);
    try testVisit("test {\n const arr: [3]u32 = .{ 10, 20, 30 };\n const x, const y, const z = arr;}", .assign_destructure);
    try testVisit("const E1 = error{E1}; const E2 = E1 || error{E3};", .merge_error_sets);
    try testVisit("test { var a = 2; a = 2 * a; }", .mul);
    try testVisit("test { var a = 2; a = a / 2; }", .div);
    try testVisit("test { var a = 2; a = a % 2; }", .mod);
    try testVisit("test { var a = [2]u8{1, 2} ** 2; }", .array_mult);
    try testVisit("test { var a: u8 = 2 *% 0xFF;}", .mul_wrap);
    try testVisit("test { var a: u8 = 2 *| 0xFF;}", .mul_sat);
    try testVisit("test { var a: u8 = 2 + 0xF0;}", .add);
    try testVisit("test { var a: u8 = 0xF0 - 0x2;}", .sub);
    try testVisit("test { var a = [2]u8{1, 2} ++ [_]u8{3}; }", .array_cat);
    try testVisit("test { var a: u8 = 2 +% 0xFF;}", .add_wrap);
    try testVisit("test { var a: u8 = 2 -% 0xFF;}", .sub_wrap);
    try testVisit("test { var a: u8 = 2 +| 0xFF;}", .add_sat);
    try testVisit("test { var a: u8 = 2 -| 0xFF;}", .sub_sat);
    try testVisit("test { var a: u8 = 2 << 1;}", .shl);
    try testVisit("test { var a: u8 = 2 <<| 10;}", .shl_sat);
    try testVisit("test { var a: u8 = 2 >> 1;}", .shr);
    try testVisit("test { var a: u8 = 2 & 1;}", .bit_and);
    try testVisit("test { var a: u8 = 2 ^ 1;}", .bit_xor);
    try testVisit("test { var a: u8 = 2 | 1;}", .bit_or);
    try testVisit("test { var a: u8 = null orelse 1;}", .@"orelse");
    try testVisit("test { var a = true and true;}", .bool_and);
    try testVisit("test { var a = true or false;}", .bool_or);
    try testVisit("test { var a = !true; }", .bool_not);
    try testVisit("test { var a = -foo(); }", .negation);
    try testVisit("test { var a = ~0x4; }", .bit_not);
    try testVisit("test { var a = -%foo(); }", .negation_wrap);
    try testVisit("test { var a = 0; var b = &a; }", .address_of);
    try testVisit("test { try foo(); }", .@"try");
    try testVisit("test { await foo(); }", .@"await");
    try testVisit("test { var a: ?bool = null; }", .optional_type);
    try testVisit("test { var a: [2]u8 = undefined; }", .array_type);
    try testVisit("test { var a: [2:0]u8 = undefined; }", .array_type_sentinel);
    try testVisit("test { var a: *align(8) u8 = undefined; }", .ptr_type_aligned);
    try testVisit("test { var a: [*]align(8) u8 = undefined; }", .ptr_type_aligned);
    try testVisit("test { var a: []u8 = undefined; }", .ptr_type_aligned);
    try testVisit("test { var a: [*:0]u8 = undefined; }", .ptr_type_sentinel);
    try testVisit("test { var a: [:0]u8 = undefined; }", .ptr_type_sentinel);
    // try testVisit("test { var a: *u8 = undefined; }", .ptr_type_sentinel); // FIXME: maybe docs incorrect ?
    // try testVisit("test { var a: [*c]u8 = undefined; }", .ptr_type);  // TODO: How
    // try testVisit("test { var a: [*c]u8 = undefined; }", .ptr_type_bit_range);  // TODO: How
    try testVisit("test { var a = [2]u8{1,2}; var b = a[0..]; }", .slice_open);
    try testVisit("test { var a = [2]u8{1,2}; var b = a[0..1]; }", .slice);
    try testVisit("test { var a = [2]u8{1,2}; var b = a[0..100:0]; }", .slice_sentinel);
    try testVisit("test { var a = [2]u8{1,2}; var b = a[0..:0]; }", .slice_sentinel);
    try testVisit("test { var a = 0; var b = &a; var c = b.*; }", .deref);
    try testVisit("test { var a = [_]u8{1}; }", .array_init_one);
    try testVisit("test { var a = [_]u8{1,}; }", .array_init_one_comma);
    try testVisit("test { var a: [2]u8 = .{1,2}; }", .array_init_dot_two);
    try testVisit("test { var a: [2]u8 = .{1,2,}; }", .array_init_dot_two_comma);
    try testVisit("test { var a = [_]u8{1,2,3,4,5}; }", .array_init);
    try testVisit("test { var a = [_]u8{1,2,3,}; }", .array_init_comma);
    try testVisit("const A = struct {a: u8};test { var a = A{.a=0}; }", .struct_init_one);
    try testVisit("const A = struct {a: u8};test { var a = A{.a=0,}; }", .struct_init_one_comma);
    try testVisit("const A = struct {a: u8, b: u8};test { var a: A = .{.a=0,.b=1}; }", .struct_init_dot_two);
    try testVisit("const A = struct {a: u8, b: u8};test { var a: A = .{.a=0,.b=1,}; }", .struct_init_dot_two_comma);
    try testVisit("const A = struct {a: u8, b: u8, c: u8};test { var a: A = .{.a=0,.b=1,.c=2}; }", .struct_init_dot);
    try testVisit("const A = struct {a: u8, b: u8, c: u8};test { var a: A = .{.a=0,.b=1,.c=2,}; }", .struct_init_dot_comma);
    try testVisit("const A = struct {a: u8, b: u8, c: u8};test { var a = A{.a=0,.b=1,.c=2}; }", .struct_init);
    try testVisit("const A = struct {a: u8, b: u8, c: u8};test { var a = A{.a=0,.b=1,.c=2,}; }", .struct_init_comma);
    try testVisit("pub fn main(a: u8) void {}\ntest { main(1); }", .call_one);
    try testVisit("pub fn main(a: u8) void {}\ntest { main(1,); }", .call_one_comma);
    try testVisit("pub fn main(a: u8) void {}\ntest { async main(1); }", .async_call_one);
    try testVisit("pub fn main(a: u8) void {}\ntest { async main(1,); }", .async_call_one_comma);
    try testVisit("pub fn main(a: u8, b: u8, c: u8) void {}\ntest { main(1, 2, 3); }", .call);
    try testVisit("pub fn main(a: u8, b: u8, c: u8) void {}\ntest { main(1, 2, 3, ); }", .call_comma);
    try testVisit("pub fn main(a: u8, b: u8, c: u8) void {}\ntest { async main(1, 2, 3); }", .async_call);
    try testVisit("pub fn main(a: u8, b: u8, c: u8) void {}\ntest { async main(1, 2, 3, ); }", .async_call_comma);
    try testVisit("test { var i: u1 = 0; switch (i) {0=>{}, 1=>{}} }", .@"switch");
    try testVisit("test { var a = \"ab\"; switch (a[0]) {'a'=> {}, else=>{},} }", .switch_comma);
    try testVisit("test { var a = \"ab\"; switch (a[0]) {'a'=> {}, else=>{},} }", .switch_case_one);
    try testVisit("test { var i: u1 = 0; switch (i) {0=>{}, inline else=>{}} }", .switch_case_inline_one);
    try testVisit("test { var i: u1 = 0; switch (i) {0, 1=>{} } }", .switch_case);
    try testVisit("test { var i: u1 = 0; switch (i) {inline 0, 1=>{} } }", .switch_case_inline);
    try testVisit("test { var i: u8 = 0; switch (i) {0...8=>{}, else=>{}} }", .switch_range);
    try testVisit("test { while (true) {} }", .while_simple);
    try testVisit("test {var opt: ?u8 = null; while (opt) |v| { _ = v; } }", .while_simple);
    try testVisit("test {var i = 0; while (i < 10) : (i+=1) {} }", .while_cont);
    try testVisit("test {var i = 0; while (i < 0) : (i+=1) {} else {} }", .@"while");
    try testVisit("test {var i = 0; while (i < 0) {} else {} }", .@"while");
    try testVisit("test {var opt: ?u8 = null; while (opt) |v| : (opt = null) { _ = v; } else {} }", .@"while");
    try testVisit("test {\n for ([2]u8{1,2}) |i| {\n  print(i);\n }\n}", .for_simple);
    try testVisit("test {\n for ([2]u8{1,2}, [2]u8{3,4}) |a, b| {\n  print(a + b);\n }\n}", .@"for");
    try testVisit("test {\n for ([2]u8{1,2}, 0..) |a, i| {\n  print(a + i);\n }\n}", .@"for");
    try testVisit("test {var x = [_]u8{}; for (x)|i| {print(i);} else {print(0);}}", .@"for");
    try testVisit("test {\n for (0..2) |i| {\n  print(i);\n }\n}", .for_range);
    try testVisit("test {\n for (0..0) |i| {\n  print(i); if (i == 2) break;\n }\n}", .for_range);
    try testVisit("test { if (true) { var a = 0; } }", .if_simple);
    try testVisit("test {var x = if (true) 1 else 2; }", .@"if");
    try testVisit("test {var x: ?anyframe = null; suspend x;}", .@"suspend");
    try testVisit("test {var x: ?anyframe = null; resume x.?;}", .@"resume");
    try testVisit("test {var i: usize = 0; outer: while (i < 10) : (i += 1) { while (true) { continue :outer; } }}", .@"continue");
    try testVisit("test {var i: usize = 0; while (i < 10) : (i += 1) { continue; } }", .@"continue");
    try testVisit("test {var i: usize = 0; while (i < 10) : (i += 1) { break; } }", .@"break");
    try testVisit("test {var i: usize = 0; outer: while (i < 10) : (i += 1) { while (true) { break :outer; } }}", .@"break");
    try testVisit("pub fn foo() u8 { return 1; }", .@"return");
    try testVisit("pub fn foo() void { return; }", .@"return");
    try testVisit("pub fn foo(a: u8) u8 { return a; }", .fn_proto_simple);
    try testVisit("pub fn foo(a: u8, b: u8) u8 { return a + b; }", .fn_proto_multi);
    try testVisit("pub fn foo(a: u8) callconv(.C) u8 { return a; }", .fn_proto_one);
    try testVisit("pub fn foo(a: u8, b: u8) callconv(.C) u8 { return a + b; }", .fn_proto);
    try testVisit("pub fn foo(a: u8, b: u8) callconv(.C) u8 { return a + b; }", .fn_decl);
    try testVisit("test {var f: anyframe = undefined; anyframe->foo;}", .anyframe_type);
    try testVisit("test {var f: anyframe = undefined;}", .anyframe_literal);
    try testVisit("test {var f: u8 = 'c';}", .char_literal);
    try testVisit("test {var f: u8 = 0;}", .number_literal);
    try testVisit("test {if (false) {unreachable;}}", .unreachable_literal);
    try testVisit("test {var f: u8 = 0;}", .identifier);
    try testVisit("const A = enum {a, b, c}; test {var x: A = .a;}", .enum_literal);
    try testVisit("test {var x = \"abcd\";}", .string_literal);
    try testVisit("test {var x = \\\\aba\n;}", .multiline_string_literal);
    try testVisit("test {var x = (1 + 1);}", .grouped_expression);
    try testVisit("test {var x = @min(1, 2);}", .builtin_call_two);
    try testVisit("test {var x = @min(1, 2,);}", .builtin_call_two_comma);
    try testVisit("test {var x = @min(1, 2, 3);}", .builtin_call);
    try testVisit("test {var x = @min(1, 2, 3,);}", .builtin_call_comma);
    try testVisit("const E = error{a, b};", .error_set_decl);
    try testVisit("const A = struct {a: u8, b: u8, c: u8};", .container_decl);
    try testVisit("const A = struct {a: u8, b: u8, c: u8,};", .container_decl_trailing);
    try testVisit("const A = struct {a: u8, b: u8};", .container_decl_two);
    try testVisit("const A = struct {a: u8, b: u8, };", .container_decl_two_trailing);
    try testVisit("const A = struct(u16) {a: u8, b: u8};", .container_decl_arg);
    try testVisit("const A = struct(u16) {a: u8, b: u8,};", .container_decl_arg_trailing);

    try testVisit("const V = union(enum) {int: i32, boolean: bool, none};", .tagged_union);
    try testVisit("const V = union(enum) {int: i32, boolean: bool, none,};", .tagged_union_trailing);
    try testVisit("const V = union(enum) {int: i32, boolean: bool};", .tagged_union_two);
    try testVisit("const V = union(enum) {int: i32, boolean: bool,};", .tagged_union_two_trailing);
    try testVisit("const V = union(enum(u8)) {int: i32, boolean: bool};", .tagged_union_enum_tag);
    try testVisit("const V = union(enum(u8)) {int: i32, boolean: bool,};", .tagged_union_enum_tag_trailing);

    try testVisit("const A = struct {a: u8 = 0};", .container_field_init);
    try testVisit("const A = struct {a: u8 align(4)};", .container_field_align);
    try testVisit("const A = struct {a: u8 align(4) = 0};", .container_field);
    try testVisit("pub fn foo() u8 { return 1; } test { const x = comptime foo(); }", .@"comptime");
    try testVisit("pub fn foo() u8 { return 1; } test { const x = nosuspend foo(); }", .@"nosuspend");
    try testVisit("test {}", .block_two);
    try testVisit("test {var a = 1;}", .block_two_semicolon);
    try testVisit("test {if (1) {} if (2) {} if (3) {} }", .block);
    try testVisit("test {var a = 1; var b = 2; var c = 3;}", .block_semicolon);
    try testVisit("test { asm(\"nop\"); }", .asm_simple);
    const asm_source =
        \\pub fn syscall0(number: SYS) usize {
        \\  return asm volatile ("svc #0"
        \\    : [ret] "={x0}" (-> usize),
        \\    : [number] "{x8}" (@intFromEnum(number)),
        \\    : "memory", "cc"
        \\  );
        \\}
    ;
    try testVisit(asm_source, .@"asm");
    try testVisit(asm_source, .asm_input);
    try testVisit(asm_source, .asm_output);

    try testVisit("const e = error.EndOfStream;", .error_value);
    try testVisit("const e = error{a} ! error{b};", .error_union);
}

test "all-visit" {
    // Visit all source in the zig lib source tree
    const allocator = std.testing.allocator;
    const zig_lib = "../../";
    var dir = try std.fs.cwd().openIterableDir(zig_lib, .{});
    defer dir.close();
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    const buffer_size = 20 * 1000 * 1024; // 20MB
    while (try walker.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".zig")) {
            errdefer std.log.warn("{s}", .{entry.path});
            const file = try entry.dir.openFile(entry.basename, .{});
            const source = try file.readToEndAllocOptions(allocator, buffer_size, null, 4, 0);
            defer allocator.free(source);
            defer file.close();
            testVisit(source, .root) catch |err| switch (err) {
                error.ParseError => {}, // Skip
                else => return err,
            };
        }
    }
}
