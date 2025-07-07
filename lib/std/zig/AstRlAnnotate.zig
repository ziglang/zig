//! AstRlAnnotate is a simple pass which runs over the AST before AstGen to
//! determine which expressions require result locations.
//!
//! In some cases, AstGen can choose whether to provide a result pointer or to
//! just use standard `break` instructions from a block. The latter choice can
//! result in more efficient ZIR and runtime code, but does not allow for RLS to
//! occur. Thus, we want to provide a real result pointer (from an alloc) only
//! when necessary.
//!
//! To achieve this, we need to determine which expressions require a result
//! pointer. This pass is responsible for analyzing all syntax forms which may
//! provide a result location and, if sub-expressions consume this result
//! pointer non-trivially (e.g. writing through field pointers), marking the
//! node as requiring a result location.

const std = @import("std");
const AstRlAnnotate = @This();
const Ast = std.zig.Ast;
const Allocator = std.mem.Allocator;
const AutoHashMapUnmanaged = std.AutoHashMapUnmanaged;
const BuiltinFn = std.zig.BuiltinFn;
const assert = std.debug.assert;

gpa: Allocator,
arena: Allocator,
tree: *const Ast,

/// Certain nodes are placed in this set under the following conditions:
/// * if-else: either branch consumes the result location
/// * labeled block: any break consumes the result location
/// * switch: any prong consumes the result location
/// * orelse/catch: the RHS expression consumes the result location
/// * while/for: any break consumes the result location
/// * @as: the second operand consumes the result location
/// * const: the init expression consumes the result location
/// * return: the return expression consumes the result location
nodes_need_rl: RlNeededSet = .{},

pub const RlNeededSet = AutoHashMapUnmanaged(Ast.Node.Index, void);

const ResultInfo = packed struct {
    /// Do we have a known result type?
    have_type: bool,
    /// Do we (potentially) have a result pointer? Note that this pointer's type
    /// may not be known due to it being an inferred alloc.
    have_ptr: bool,

    const none: ResultInfo = .{ .have_type = false, .have_ptr = false };
    const typed_ptr: ResultInfo = .{ .have_type = true, .have_ptr = true };
    const inferred_ptr: ResultInfo = .{ .have_type = false, .have_ptr = true };
    const type_only: ResultInfo = .{ .have_type = true, .have_ptr = false };
};

/// A labeled block or a loop. When this block is broken from, `consumes_res_ptr`
/// should be set if the break expression consumed the result pointer.
const Block = struct {
    parent: ?*Block,
    label: ?[]const u8,
    is_loop: bool,
    ri: ResultInfo,
    consumes_res_ptr: bool,
};

pub fn annotate(gpa: Allocator, arena: Allocator, tree: Ast) Allocator.Error!RlNeededSet {
    var astrl: AstRlAnnotate = .{
        .gpa = gpa,
        .arena = arena,
        .tree = &tree,
    };
    defer astrl.deinit(gpa);

    if (tree.errors.len != 0) {
        // We can't perform analysis on a broken AST. AstGen will not run in
        // this case.
        return .{};
    }

    for (tree.containerDeclRoot().ast.members) |member_node| {
        _ = try astrl.expr(member_node, null, ResultInfo.none);
    }

    return astrl.nodes_need_rl.move();
}

fn deinit(astrl: *AstRlAnnotate, gpa: Allocator) void {
    astrl.nodes_need_rl.deinit(gpa);
}

fn containerDecl(
    astrl: *AstRlAnnotate,
    block: ?*Block,
    full: Ast.full.ContainerDecl,
) !void {
    const tree = astrl.tree;
    switch (tree.tokenTag(full.ast.main_token)) {
        .keyword_struct => {
            if (full.ast.arg.unwrap()) |arg| {
                _ = try astrl.expr(arg, block, ResultInfo.type_only);
            }
            for (full.ast.members) |member_node| {
                _ = try astrl.expr(member_node, block, ResultInfo.none);
            }
        },
        .keyword_union => {
            if (full.ast.arg.unwrap()) |arg| {
                _ = try astrl.expr(arg, block, ResultInfo.type_only);
            }
            for (full.ast.members) |member_node| {
                _ = try astrl.expr(member_node, block, ResultInfo.none);
            }
        },
        .keyword_enum => {
            if (full.ast.arg.unwrap()) |arg| {
                _ = try astrl.expr(arg, block, ResultInfo.type_only);
            }
            for (full.ast.members) |member_node| {
                _ = try astrl.expr(member_node, block, ResultInfo.none);
            }
        },
        .keyword_opaque => {
            for (full.ast.members) |member_node| {
                _ = try astrl.expr(member_node, block, ResultInfo.none);
            }
        },
        else => unreachable,
    }
}

/// Returns true if `rl` provides a result pointer and the expression consumes it.
fn expr(astrl: *AstRlAnnotate, node: Ast.Node.Index, block: ?*Block, ri: ResultInfo) Allocator.Error!bool {
    const tree = astrl.tree;
    switch (tree.nodeTag(node)) {
        .root,
        .switch_case_one,
        .switch_case_inline_one,
        .switch_case,
        .switch_case_inline,
        .switch_range,
        .for_range,
        .asm_output,
        .asm_input,
        => unreachable,

        .@"errdefer" => {
            _ = try astrl.expr(tree.nodeData(node).opt_token_and_node[1], block, ResultInfo.none);
            return false;
        },
        .@"defer" => {
            _ = try astrl.expr(tree.nodeData(node).node, block, ResultInfo.none);
            return false;
        },

        .container_field_init,
        .container_field_align,
        .container_field,
        => {
            const full = tree.fullContainerField(node).?;
            const type_expr = full.ast.type_expr.unwrap().?;
            _ = try astrl.expr(type_expr, block, ResultInfo.type_only);
            if (full.ast.align_expr.unwrap()) |align_expr| {
                _ = try astrl.expr(align_expr, block, ResultInfo.type_only);
            }
            if (full.ast.value_expr.unwrap()) |value_expr| {
                _ = try astrl.expr(value_expr, block, ResultInfo.type_only);
            }
            return false;
        },
        .@"usingnamespace" => {
            _ = try astrl.expr(tree.nodeData(node).node, block, ResultInfo.type_only);
            return false;
        },
        .test_decl => {
            _ = try astrl.expr(tree.nodeData(node).opt_token_and_node[1], block, ResultInfo.none);
            return false;
        },
        .global_var_decl,
        .local_var_decl,
        .simple_var_decl,
        .aligned_var_decl,
        => {
            const full = tree.fullVarDecl(node).?;
            const init_ri = if (full.ast.type_node.unwrap()) |type_node| init_ri: {
                _ = try astrl.expr(type_node, block, ResultInfo.type_only);
                break :init_ri ResultInfo.typed_ptr;
            } else ResultInfo.inferred_ptr;
            const init_node = full.ast.init_node.unwrap() orelse {
                // No init node, so we're done.
                return false;
            };
            switch (tree.tokenTag(full.ast.mut_token)) {
                .keyword_const => {
                    const init_consumes_rl = try astrl.expr(init_node, block, init_ri);
                    if (init_consumes_rl) {
                        try astrl.nodes_need_rl.putNoClobber(astrl.gpa, node, {});
                    }
                    return false;
                },
                .keyword_var => {
                    // We'll create an alloc either way, so don't care if the
                    // result pointer is consumed.
                    _ = try astrl.expr(init_node, block, init_ri);
                    return false;
                },
                else => unreachable,
            }
        },
        .assign_destructure => {
            const full = tree.assignDestructure(node);
            for (full.ast.variables) |variable_node| {
                _ = try astrl.expr(variable_node, block, ResultInfo.none);
            }
            // We don't need to gather any meaningful data here, because destructures always use RLS
            _ = try astrl.expr(full.ast.value_expr, block, ResultInfo.none);
            return false;
        },
        .assign => {
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            _ = try astrl.expr(lhs, block, ResultInfo.none);
            _ = try astrl.expr(rhs, block, ResultInfo.typed_ptr);
            return false;
        },
        .assign_shl,
        .assign_shl_sat,
        .assign_shr,
        .assign_bit_and,
        .assign_bit_or,
        .assign_bit_xor,
        .assign_div,
        .assign_sub,
        .assign_sub_wrap,
        .assign_sub_sat,
        .assign_mod,
        .assign_add,
        .assign_add_wrap,
        .assign_add_sat,
        .assign_mul,
        .assign_mul_wrap,
        .assign_mul_sat,
        => {
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            _ = try astrl.expr(lhs, block, ResultInfo.none);
            _ = try astrl.expr(rhs, block, ResultInfo.none);
            return false;
        },
        .shl, .shr => {
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            _ = try astrl.expr(lhs, block, ResultInfo.none);
            _ = try astrl.expr(rhs, block, ResultInfo.type_only);
            return false;
        },
        .add,
        .add_wrap,
        .add_sat,
        .sub,
        .sub_wrap,
        .sub_sat,
        .mul,
        .mul_wrap,
        .mul_sat,
        .div,
        .mod,
        .shl_sat,
        .bit_and,
        .bit_or,
        .bit_xor,
        .bang_equal,
        .equal_equal,
        .greater_than,
        .greater_or_equal,
        .less_than,
        .less_or_equal,
        .array_cat,
        => {
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            _ = try astrl.expr(lhs, block, ResultInfo.none);
            _ = try astrl.expr(rhs, block, ResultInfo.none);
            return false;
        },

        .array_mult => {
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            _ = try astrl.expr(lhs, block, ResultInfo.none);
            _ = try astrl.expr(rhs, block, ResultInfo.type_only);
            return false;
        },
        .error_union, .merge_error_sets => {
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            _ = try astrl.expr(lhs, block, ResultInfo.none);
            _ = try astrl.expr(rhs, block, ResultInfo.none);
            return false;
        },
        .bool_and,
        .bool_or,
        => {
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            _ = try astrl.expr(lhs, block, ResultInfo.type_only);
            _ = try astrl.expr(rhs, block, ResultInfo.type_only);
            return false;
        },
        .bool_not => {
            _ = try astrl.expr(tree.nodeData(node).node, block, ResultInfo.type_only);
            return false;
        },
        .bit_not, .negation, .negation_wrap => {
            _ = try astrl.expr(tree.nodeData(node).node, block, ResultInfo.none);
            return false;
        },

        // These nodes are leaves and never consume a result location.
        .identifier,
        .string_literal,
        .multiline_string_literal,
        .number_literal,
        .unreachable_literal,
        .asm_simple,
        .@"asm",
        .enum_literal,
        .error_value,
        .anyframe_literal,
        .@"continue",
        .char_literal,
        .error_set_decl,
        => return false,

        .builtin_call_two,
        .builtin_call_two_comma,
        .builtin_call,
        .builtin_call_comma,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const params = tree.builtinCallParams(&buf, node).?;
            return astrl.builtinCall(block, ri, node, params);
        },

        .call_one,
        .call_one_comma,
        .call,
        .call_comma,
        => {
            var buf: [1]Ast.Node.Index = undefined;
            const full = tree.fullCall(&buf, node).?;
            _ = try astrl.expr(full.ast.fn_expr, block, ResultInfo.none);
            for (full.ast.params) |param_node| {
                _ = try astrl.expr(param_node, block, ResultInfo.type_only);
            }
            return switch (tree.nodeTag(node)) {
                .call_one,
                .call_one_comma,
                .call,
                .call_comma,
                => false, // TODO: once function calls are passed result locations this will change
                else => unreachable,
            };
        },

        .@"return" => {
            if (tree.nodeData(node).opt_node.unwrap()) |lhs| {
                const ret_val_consumes_rl = try astrl.expr(lhs, block, ResultInfo.typed_ptr);
                if (ret_val_consumes_rl) {
                    try astrl.nodes_need_rl.putNoClobber(astrl.gpa, node, {});
                }
            }
            return false;
        },

        .field_access => {
            const lhs, _ = tree.nodeData(node).node_and_token;
            _ = try astrl.expr(lhs, block, ResultInfo.none);
            return false;
        },

        .if_simple, .@"if" => {
            const full = tree.fullIf(node).?;
            if (full.error_token != null or full.payload_token != null) {
                _ = try astrl.expr(full.ast.cond_expr, block, ResultInfo.none);
            } else {
                _ = try astrl.expr(full.ast.cond_expr, block, ResultInfo.type_only); // bool
            }

            if (full.ast.else_expr.unwrap()) |else_expr| {
                const then_uses_rl = try astrl.expr(full.ast.then_expr, block, ri);
                const else_uses_rl = try astrl.expr(else_expr, block, ri);
                const uses_rl = then_uses_rl or else_uses_rl;
                if (uses_rl) try astrl.nodes_need_rl.putNoClobber(astrl.gpa, node, {});
                return uses_rl;
            } else {
                _ = try astrl.expr(full.ast.then_expr, block, ResultInfo.none);
                return false;
            }
        },

        .while_simple, .while_cont, .@"while" => {
            const full = tree.fullWhile(node).?;
            const label: ?[]const u8 = if (full.label_token) |label_token| label: {
                break :label try astrl.identString(label_token);
            } else null;
            if (full.error_token != null or full.payload_token != null) {
                _ = try astrl.expr(full.ast.cond_expr, block, ResultInfo.none);
            } else {
                _ = try astrl.expr(full.ast.cond_expr, block, ResultInfo.type_only); // bool
            }
            var new_block: Block = .{
                .parent = block,
                .label = label,
                .is_loop = true,
                .ri = ri,
                .consumes_res_ptr = false,
            };
            if (full.ast.cont_expr.unwrap()) |cont_expr| {
                _ = try astrl.expr(cont_expr, &new_block, ResultInfo.none);
            }
            _ = try astrl.expr(full.ast.then_expr, &new_block, ResultInfo.none);
            const else_consumes_rl = if (full.ast.else_expr.unwrap()) |else_expr| else_rl: {
                break :else_rl try astrl.expr(else_expr, block, ri);
            } else false;
            if (new_block.consumes_res_ptr or else_consumes_rl) {
                try astrl.nodes_need_rl.putNoClobber(astrl.gpa, node, {});
                return true;
            } else {
                return false;
            }
        },

        .for_simple, .@"for" => {
            const full = tree.fullFor(node).?;
            const label: ?[]const u8 = if (full.label_token) |label_token| label: {
                break :label try astrl.identString(label_token);
            } else null;
            for (full.ast.inputs) |input| {
                if (tree.nodeTag(input) == .for_range) {
                    const lhs, const opt_rhs = tree.nodeData(input).node_and_opt_node;
                    _ = try astrl.expr(lhs, block, ResultInfo.type_only);
                    if (opt_rhs.unwrap()) |rhs| {
                        _ = try astrl.expr(rhs, block, ResultInfo.type_only);
                    }
                } else {
                    _ = try astrl.expr(input, block, ResultInfo.none);
                }
            }
            var new_block: Block = .{
                .parent = block,
                .label = label,
                .is_loop = true,
                .ri = ri,
                .consumes_res_ptr = false,
            };
            _ = try astrl.expr(full.ast.then_expr, &new_block, ResultInfo.none);
            const else_consumes_rl = if (full.ast.else_expr.unwrap()) |else_expr| else_rl: {
                break :else_rl try astrl.expr(else_expr, block, ri);
            } else false;
            if (new_block.consumes_res_ptr or else_consumes_rl) {
                try astrl.nodes_need_rl.putNoClobber(astrl.gpa, node, {});
                return true;
            } else {
                return false;
            }
        },

        .slice_open => {
            const sliced, const start = tree.nodeData(node).node_and_node;
            _ = try astrl.expr(sliced, block, ResultInfo.none);
            _ = try astrl.expr(start, block, ResultInfo.type_only);
            return false;
        },
        .slice => {
            const sliced, const extra_index = tree.nodeData(node).node_and_extra;
            const extra = tree.extraData(extra_index, Ast.Node.Slice);
            _ = try astrl.expr(sliced, block, ResultInfo.none);
            _ = try astrl.expr(extra.start, block, ResultInfo.type_only);
            _ = try astrl.expr(extra.end, block, ResultInfo.type_only);
            return false;
        },
        .slice_sentinel => {
            const sliced, const extra_index = tree.nodeData(node).node_and_extra;
            const extra = tree.extraData(extra_index, Ast.Node.SliceSentinel);
            _ = try astrl.expr(sliced, block, ResultInfo.none);
            _ = try astrl.expr(extra.start, block, ResultInfo.type_only);
            if (extra.end.unwrap()) |end| {
                _ = try astrl.expr(end, block, ResultInfo.type_only);
            }
            _ = try astrl.expr(extra.sentinel, block, ResultInfo.none);
            return false;
        },
        .deref => {
            _ = try astrl.expr(tree.nodeData(node).node, block, ResultInfo.none);
            return false;
        },
        .address_of => {
            _ = try astrl.expr(tree.nodeData(node).node, block, ResultInfo.none);
            return false;
        },
        .optional_type => {
            _ = try astrl.expr(tree.nodeData(node).node, block, ResultInfo.type_only);
            return false;
        },
        .@"try",
        .@"nosuspend",
        => return astrl.expr(tree.nodeData(node).node, block, ri),
        .grouped_expression,
        .unwrap_optional,
        => return astrl.expr(tree.nodeData(node).node_and_token[0], block, ri),

        .block_two,
        .block_two_semicolon,
        .block,
        .block_semicolon,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const statements = tree.blockStatements(&buf, node).?;
            return astrl.blockExpr(block, ri, node, statements);
        },
        .anyframe_type => {
            _, const child_type = tree.nodeData(node).token_and_node;
            _ = try astrl.expr(child_type, block, ResultInfo.type_only);
            return false;
        },
        .@"catch", .@"orelse" => {
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            _ = try astrl.expr(lhs, block, ResultInfo.none);
            const rhs_consumes_rl = try astrl.expr(rhs, block, ri);
            if (rhs_consumes_rl) {
                try astrl.nodes_need_rl.putNoClobber(astrl.gpa, node, {});
            }
            return rhs_consumes_rl;
        },

        .ptr_type_aligned,
        .ptr_type_sentinel,
        .ptr_type,
        .ptr_type_bit_range,
        => {
            const full = tree.fullPtrType(node).?;
            _ = try astrl.expr(full.ast.child_type, block, ResultInfo.type_only);
            if (full.ast.sentinel.unwrap()) |sentinel| {
                _ = try astrl.expr(sentinel, block, ResultInfo.type_only);
            }
            if (full.ast.addrspace_node.unwrap()) |addrspace_node| {
                _ = try astrl.expr(addrspace_node, block, ResultInfo.type_only);
            }
            if (full.ast.align_node.unwrap()) |align_node| {
                _ = try astrl.expr(align_node, block, ResultInfo.type_only);
            }
            if (full.ast.bit_range_start.unwrap()) |bit_range_start| {
                const bit_range_end = full.ast.bit_range_end.unwrap().?;
                _ = try astrl.expr(bit_range_start, block, ResultInfo.type_only);
                _ = try astrl.expr(bit_range_end, block, ResultInfo.type_only);
            }
            return false;
        },

        .container_decl,
        .container_decl_trailing,
        .container_decl_arg,
        .container_decl_arg_trailing,
        .container_decl_two,
        .container_decl_two_trailing,
        .tagged_union,
        .tagged_union_trailing,
        .tagged_union_enum_tag,
        .tagged_union_enum_tag_trailing,
        .tagged_union_two,
        .tagged_union_two_trailing,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            try astrl.containerDecl(block, tree.fullContainerDecl(&buf, node).?);
            return false;
        },

        .@"break" => {
            const opt_label, const opt_rhs = tree.nodeData(node).opt_token_and_opt_node;
            const rhs = opt_rhs.unwrap() orelse {
                // Breaks with void are not interesting
                return false;
            };

            var opt_cur_block = block;
            if (opt_label.unwrap()) |label_token| {
                const break_label = try astrl.identString(label_token);
                while (opt_cur_block) |cur_block| : (opt_cur_block = cur_block.parent) {
                    const block_label = cur_block.label orelse continue;
                    if (std.mem.eql(u8, block_label, break_label)) break;
                }
            } else {
                // No label - we're breaking from a loop.
                while (opt_cur_block) |cur_block| : (opt_cur_block = cur_block.parent) {
                    if (cur_block.is_loop) break;
                }
            }

            if (opt_cur_block) |target_block| {
                const consumes_break_rl = try astrl.expr(rhs, block, target_block.ri);
                if (consumes_break_rl) target_block.consumes_res_ptr = true;
            } else {
                // No corresponding scope to break from - AstGen will emit an error.
                _ = try astrl.expr(rhs, block, ResultInfo.none);
            }

            return false;
        },

        .array_type => {
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            _ = try astrl.expr(lhs, block, ResultInfo.type_only);
            _ = try astrl.expr(rhs, block, ResultInfo.type_only);
            return false;
        },
        .array_type_sentinel => {
            const len_expr, const extra_index = tree.nodeData(node).node_and_extra;
            const extra = tree.extraData(extra_index, Ast.Node.ArrayTypeSentinel);
            _ = try astrl.expr(len_expr, block, ResultInfo.type_only);
            _ = try astrl.expr(extra.elem_type, block, ResultInfo.type_only);
            _ = try astrl.expr(extra.sentinel, block, ResultInfo.type_only);
            return false;
        },
        .array_access => {
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            _ = try astrl.expr(lhs, block, ResultInfo.none);
            _ = try astrl.expr(rhs, block, ResultInfo.type_only);
            return false;
        },
        .@"comptime" => {
            // AstGen will emit an error if the scope is already comptime, so we can assume it is
            // not. This means the result location is not forwarded.
            _ = try astrl.expr(tree.nodeData(node).node, block, ResultInfo.none);
            return false;
        },
        .@"switch", .switch_comma => {
            const operand_node, const extra_index = tree.nodeData(node).node_and_extra;
            const case_nodes = tree.extraDataSlice(tree.extraData(extra_index, Ast.Node.SubRange), Ast.Node.Index);

            _ = try astrl.expr(operand_node, block, ResultInfo.none);

            var any_prong_consumed_rl = false;
            for (case_nodes) |case_node| {
                const case = tree.fullSwitchCase(case_node).?;
                for (case.ast.values) |item_node| {
                    if (tree.nodeTag(item_node) == .switch_range) {
                        const lhs, const rhs = tree.nodeData(item_node).node_and_node;
                        _ = try astrl.expr(lhs, block, ResultInfo.none);
                        _ = try astrl.expr(rhs, block, ResultInfo.none);
                    } else {
                        _ = try astrl.expr(item_node, block, ResultInfo.none);
                    }
                }
                if (try astrl.expr(case.ast.target_expr, block, ri)) {
                    any_prong_consumed_rl = true;
                }
            }
            if (any_prong_consumed_rl) {
                try astrl.nodes_need_rl.putNoClobber(astrl.gpa, node, {});
            }
            return any_prong_consumed_rl;
        },
        .@"suspend" => {
            _ = try astrl.expr(tree.nodeData(node).node, block, ResultInfo.none);
            return false;
        },
        .@"resume" => {
            _ = try astrl.expr(tree.nodeData(node).node, block, ResultInfo.none);
            return false;
        },

        .array_init_one,
        .array_init_one_comma,
        .array_init_dot_two,
        .array_init_dot_two_comma,
        .array_init_dot,
        .array_init_dot_comma,
        .array_init,
        .array_init_comma,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const full = tree.fullArrayInit(&buf, node).?;

            if (full.ast.type_expr.unwrap()) |type_expr| {
                // Explicitly typed init does not participate in RLS
                _ = try astrl.expr(type_expr, block, ResultInfo.none);
                for (full.ast.elements) |elem_init| {
                    _ = try astrl.expr(elem_init, block, ResultInfo.type_only);
                }
                return false;
            }

            if (ri.have_type) {
                // Always forward type information
                // If we have a result pointer, we use and forward it
                for (full.ast.elements) |elem_init| {
                    _ = try astrl.expr(elem_init, block, ri);
                }
                return ri.have_ptr;
            } else {
                // Untyped init does not consume result location
                for (full.ast.elements) |elem_init| {
                    _ = try astrl.expr(elem_init, block, ResultInfo.none);
                }
                return false;
            }
        },

        .struct_init_one,
        .struct_init_one_comma,
        .struct_init_dot_two,
        .struct_init_dot_two_comma,
        .struct_init_dot,
        .struct_init_dot_comma,
        .struct_init,
        .struct_init_comma,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const full = tree.fullStructInit(&buf, node).?;

            if (full.ast.type_expr.unwrap()) |type_expr| {
                // Explicitly typed init does not participate in RLS
                _ = try astrl.expr(type_expr, block, ResultInfo.none);
                for (full.ast.fields) |field_init| {
                    _ = try astrl.expr(field_init, block, ResultInfo.type_only);
                }
                return false;
            }

            if (ri.have_type) {
                // Always forward type information
                // If we have a result pointer, we use and forward it
                for (full.ast.fields) |field_init| {
                    _ = try astrl.expr(field_init, block, ri);
                }
                return ri.have_ptr;
            } else {
                // Untyped init does not consume result location
                for (full.ast.fields) |field_init| {
                    _ = try astrl.expr(field_init, block, ResultInfo.none);
                }
                return false;
            }
        },

        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        .fn_decl,
        => |tag| {
            var buf: [1]Ast.Node.Index = undefined;
            const full = tree.fullFnProto(&buf, node).?;
            const body_node = if (tag == .fn_decl) tree.nodeData(node).node_and_node[1].toOptional() else .none;
            {
                var it = full.iterate(tree);
                while (it.next()) |param| {
                    if (param.anytype_ellipsis3 == null) {
                        const type_expr = param.type_expr.?;
                        _ = try astrl.expr(type_expr, block, ResultInfo.type_only);
                    }
                }
            }
            if (full.ast.align_expr.unwrap()) |align_expr| {
                _ = try astrl.expr(align_expr, block, ResultInfo.type_only);
            }
            if (full.ast.addrspace_expr.unwrap()) |addrspace_expr| {
                _ = try astrl.expr(addrspace_expr, block, ResultInfo.type_only);
            }
            if (full.ast.section_expr.unwrap()) |section_expr| {
                _ = try astrl.expr(section_expr, block, ResultInfo.type_only);
            }
            if (full.ast.callconv_expr.unwrap()) |callconv_expr| {
                _ = try astrl.expr(callconv_expr, block, ResultInfo.type_only);
            }
            const return_type = full.ast.return_type.unwrap().?;
            _ = try astrl.expr(return_type, block, ResultInfo.type_only);
            if (body_node.unwrap()) |body| {
                _ = try astrl.expr(body, block, ResultInfo.none);
            }
            return false;
        },
    }
}

fn identString(astrl: *AstRlAnnotate, token: Ast.TokenIndex) ![]const u8 {
    const tree = astrl.tree;
    assert(tree.tokenTag(token) == .identifier);
    const ident_name = tree.tokenSlice(token);
    if (!std.mem.startsWith(u8, ident_name, "@")) {
        return ident_name;
    }
    return std.zig.string_literal.parseAlloc(astrl.arena, ident_name[1..]) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.InvalidLiteral => "", // This pass can safely return garbage on invalid AST
    };
}

fn blockExpr(astrl: *AstRlAnnotate, parent_block: ?*Block, ri: ResultInfo, node: Ast.Node.Index, statements: []const Ast.Node.Index) !bool {
    const tree = astrl.tree;

    const lbrace = tree.nodeMainToken(node);
    if (tree.isTokenPrecededByTags(lbrace, &.{ .identifier, .colon })) {
        // Labeled block
        var new_block: Block = .{
            .parent = parent_block,
            .label = try astrl.identString(lbrace - 2),
            .is_loop = false,
            .ri = ri,
            .consumes_res_ptr = false,
        };
        for (statements) |statement| {
            _ = try astrl.expr(statement, &new_block, ResultInfo.none);
        }
        if (new_block.consumes_res_ptr) {
            try astrl.nodes_need_rl.putNoClobber(astrl.gpa, node, {});
        }
        return new_block.consumes_res_ptr;
    } else {
        // Unlabeled block
        for (statements) |statement| {
            _ = try astrl.expr(statement, parent_block, ResultInfo.none);
        }
        return false;
    }
}

fn builtinCall(astrl: *AstRlAnnotate, block: ?*Block, ri: ResultInfo, node: Ast.Node.Index, args: []const Ast.Node.Index) !bool {
    _ = ri; // Currently, no builtin consumes its result location.

    const tree = astrl.tree;
    const builtin_token = tree.nodeMainToken(node);
    const builtin_name = tree.tokenSlice(builtin_token);
    const info = BuiltinFn.list.get(builtin_name) orelse return false;
    if (info.param_count) |expected| {
        if (expected != args.len) return false;
    }
    switch (info.tag) {
        .import => return false,
        .branch_hint => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            return false;
        },
        .compile_log, .TypeOf => {
            for (args) |arg_node| {
                _ = try astrl.expr(arg_node, block, ResultInfo.none);
            }
            return false;
        },
        .as => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.type_only);
            return false;
        },
        .bit_cast => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            return false;
        },
        .union_init => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.type_only);
            _ = try astrl.expr(args[2], block, ResultInfo.type_only);
            return false;
        },
        .c_import => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            return false;
        },
        .min, .max => {
            for (args) |arg_node| {
                _ = try astrl.expr(arg_node, block, ResultInfo.none);
            }
            return false;
        },
        .@"export" => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            _ = try astrl.expr(args[1], block, ResultInfo.type_only);
            return false;
        },
        .@"extern" => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.type_only);
            return false;
        },
        // These builtins take no args and do not consume the result pointer.
        .src,
        .This,
        .return_address,
        .error_return_trace,
        .frame,
        .breakpoint,
        .disable_instrumentation,
        .disable_intrinsics,
        .in_comptime,
        .panic,
        .trap,
        .c_va_start,
        => return false,
        // TODO: this is a workaround for llvm/llvm-project#68409
        // Zig tracking issue: #16876
        .frame_address => return true,
        // These builtins take a single argument with a known result type, but do not consume their
        // result pointer.
        .size_of,
        .bit_size_of,
        .align_of,
        .compile_error,
        .set_eval_branch_quota,
        .int_from_bool,
        .int_from_error,
        .error_from_int,
        .embed_file,
        .error_name,
        .set_runtime_safety,
        .Type,
        .c_undef,
        .c_include,
        .wasm_memory_size,
        .splat,
        .set_float_mode,
        .type_info,
        .work_item_id,
        .work_group_size,
        .work_group_id,
        => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            return false;
        },
        // These builtins take a single argument with no result information and do not consume their
        // result pointer.
        .int_from_ptr,
        .int_from_enum,
        .sqrt,
        .sin,
        .cos,
        .tan,
        .exp,
        .exp2,
        .log,
        .log2,
        .log10,
        .abs,
        .floor,
        .ceil,
        .trunc,
        .round,
        .tag_name,
        .type_name,
        .Frame,
        .int_from_float,
        .float_from_int,
        .ptr_from_int,
        .enum_from_int,
        .float_cast,
        .int_cast,
        .truncate,
        .error_cast,
        .ptr_cast,
        .align_cast,
        .addrspace_cast,
        .const_cast,
        .volatile_cast,
        .clz,
        .ctz,
        .pop_count,
        .byte_swap,
        .bit_reverse,
        => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            return false;
        },
        .div_exact,
        .div_floor,
        .div_trunc,
        .mod,
        .rem,
        => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            _ = try astrl.expr(args[1], block, ResultInfo.none);
            return false;
        },
        .shl_exact, .shr_exact => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            _ = try astrl.expr(args[1], block, ResultInfo.type_only);
            return false;
        },
        .bit_offset_of,
        .offset_of,
        .has_decl,
        .has_field,
        .field,
        .FieldType,
        => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.type_only);
            return false;
        },
        .field_parent_ptr => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.none);
            return false;
        },
        .wasm_memory_grow => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.type_only);
            return false;
        },
        .c_define => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.none);
            return false;
        },
        .reduce => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.none);
            return false;
        },
        .add_with_overflow, .sub_with_overflow, .mul_with_overflow, .shl_with_overflow => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            _ = try astrl.expr(args[1], block, ResultInfo.none);
            return false;
        },
        .atomic_load => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.none);
            _ = try astrl.expr(args[2], block, ResultInfo.type_only);
            return false;
        },
        .atomic_rmw => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.none);
            _ = try astrl.expr(args[2], block, ResultInfo.type_only);
            _ = try astrl.expr(args[3], block, ResultInfo.type_only);
            _ = try astrl.expr(args[4], block, ResultInfo.type_only);
            return false;
        },
        .atomic_store => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.none);
            _ = try astrl.expr(args[2], block, ResultInfo.type_only);
            _ = try astrl.expr(args[3], block, ResultInfo.type_only);
            return false;
        },
        .mul_add => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.type_only);
            _ = try astrl.expr(args[2], block, ResultInfo.type_only);
            return false;
        },
        .call => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.none);
            _ = try astrl.expr(args[2], block, ResultInfo.none);
            return false;
        },
        .memcpy, .memmove => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            _ = try astrl.expr(args[1], block, ResultInfo.none);
            return false;
        },
        .memset => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            _ = try astrl.expr(args[1], block, ResultInfo.type_only);
            return false;
        },
        .shuffle => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.none);
            _ = try astrl.expr(args[2], block, ResultInfo.none);
            _ = try astrl.expr(args[3], block, ResultInfo.none);
            return false;
        },
        .select => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.none);
            _ = try astrl.expr(args[2], block, ResultInfo.none);
            _ = try astrl.expr(args[3], block, ResultInfo.none);
            return false;
        },
        .Vector => {
            _ = try astrl.expr(args[0], block, ResultInfo.type_only);
            _ = try astrl.expr(args[1], block, ResultInfo.type_only);
            return false;
        },
        .prefetch => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            _ = try astrl.expr(args[1], block, ResultInfo.type_only);
            return false;
        },
        .c_va_arg => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            _ = try astrl.expr(args[1], block, ResultInfo.type_only);
            return false;
        },
        .c_va_copy => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            return false;
        },
        .c_va_end => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            return false;
        },
        .cmpxchg_strong, .cmpxchg_weak => {
            _ = try astrl.expr(args[0], block, ResultInfo.none);
            _ = try astrl.expr(args[1], block, ResultInfo.type_only);
            _ = try astrl.expr(args[2], block, ResultInfo.type_only);
            _ = try astrl.expr(args[3], block, ResultInfo.type_only);
            _ = try astrl.expr(args[4], block, ResultInfo.type_only);
            return false;
        },
    }
}
