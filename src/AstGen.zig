//! A Work-In-Progress `Zir`. This is a shared parent of all
//! `GenZir` scopes. Once the `Zir` is produced, this struct
//! is deinitialized.
//! The `GenZir.finish` function converts this to a `Zir`.

const AstGen = @This();

const std = @import("std");
const ast = std.zig.ast;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");
const Zir = @import("Zir.zig");
const Module = @import("Module.zig");
const trace = @import("tracy.zig").trace;
const Scope = Module.Scope;
const GenZir = Scope.GenZir;
const InnerError = Module.InnerError;
const Decl = Module.Decl;
const LazySrcLoc = Module.LazySrcLoc;
const BuiltinFn = @import("BuiltinFn.zig");

gpa: *Allocator,
file: *Scope.File,
instructions: std.MultiArrayList(Zir.Inst) = .{},
extra: ArrayListUnmanaged(u32) = .{},
string_bytes: ArrayListUnmanaged(u8) = .{},
/// Used for temporary allocations; freed after AstGen is complete.
/// The resulting ZIR code has no references to anything in this arena.
arena: *Allocator,
string_table: std.StringHashMapUnmanaged(u32) = .{},
compile_errors: ArrayListUnmanaged(Zir.Inst.CompileErrors.Item) = .{},
/// String table indexes, keeps track of all `@import` operands.
imports: std.AutoArrayHashMapUnmanaged(u32, void) = .{},

pub fn addExtra(astgen: *AstGen, extra: anytype) Allocator.Error!u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    try astgen.extra.ensureCapacity(astgen.gpa, astgen.extra.items.len + fields.len);
    return addExtraAssumeCapacity(astgen, extra);
}

pub fn addExtraAssumeCapacity(astgen: *AstGen, extra: anytype) u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    const result = @intCast(u32, astgen.extra.items.len);
    inline for (fields) |field| {
        astgen.extra.appendAssumeCapacity(switch (field.field_type) {
            u32 => @field(extra, field.name),
            Zir.Inst.Ref => @enumToInt(@field(extra, field.name)),
            else => @compileError("bad field type"),
        });
    }
    return result;
}

pub fn appendRefs(astgen: *AstGen, refs: []const Zir.Inst.Ref) !void {
    const coerced = @bitCast([]const u32, refs);
    return astgen.extra.appendSlice(astgen.gpa, coerced);
}

pub fn appendRefsAssumeCapacity(astgen: *AstGen, refs: []const Zir.Inst.Ref) void {
    const coerced = @bitCast([]const u32, refs);
    astgen.extra.appendSliceAssumeCapacity(coerced);
}

pub fn generate(gpa: *Allocator, file: *Scope.File) InnerError!Zir {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var astgen: AstGen = .{
        .gpa = gpa,
        .arena = &arena.allocator,
        .file = file,
    };
    defer astgen.deinit(gpa);

    // First few indexes of extra are reserved and set at the end.
    try astgen.extra.resize(gpa, @typeInfo(Zir.ExtraIndex).Enum.fields.len);

    var gen_scope: Scope.GenZir = .{
        .force_comptime = true,
        .parent = &file.base,
        .decl_node_index = 0,
        .astgen = &astgen,
    };
    defer gen_scope.instructions.deinit(gpa);

    const container_decl: ast.full.ContainerDecl = .{
        .layout_token = null,
        .ast = .{
            .main_token = undefined,
            .enum_token = null,
            .members = file.tree.rootDecls(),
            .arg = 0,
        },
    };
    if (AstGen.structDeclInner(
        &gen_scope,
        &gen_scope.base,
        0,
        container_decl,
        .struct_decl,
    )) |struct_decl_ref| {
        astgen.extra.items[@enumToInt(Zir.ExtraIndex.main_struct)] = @enumToInt(struct_decl_ref);
    } else |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.AnalysisFail => {}, // Handled via compile_errors below.
    }

    const err_index = @enumToInt(Zir.ExtraIndex.compile_errors);
    if (astgen.compile_errors.items.len == 0) {
        astgen.extra.items[err_index] = 0;
    } else {
        try astgen.extra.ensureCapacity(gpa, astgen.extra.items.len +
            1 + astgen.compile_errors.items.len *
            @typeInfo(Zir.Inst.CompileErrors.Item).Struct.fields.len);

        astgen.extra.items[err_index] = astgen.addExtraAssumeCapacity(Zir.Inst.CompileErrors{
            .items_len = @intCast(u32, astgen.compile_errors.items.len),
        });

        for (astgen.compile_errors.items) |item| {
            _ = astgen.addExtraAssumeCapacity(item);
        }
    }

    const imports_index = @enumToInt(Zir.ExtraIndex.imports);
    if (astgen.imports.count() == 0) {
        astgen.extra.items[imports_index] = 0;
    } else {
        try astgen.extra.ensureCapacity(gpa, astgen.extra.items.len +
            @typeInfo(Zir.Inst.Imports).Struct.fields.len + astgen.imports.count());

        astgen.extra.items[imports_index] = astgen.addExtraAssumeCapacity(Zir.Inst.Imports{
            .imports_len = @intCast(u32, astgen.imports.count()),
        });
        for (astgen.imports.items()) |entry| {
            astgen.extra.appendAssumeCapacity(entry.key);
        }
    }

    return Zir{
        .instructions = astgen.instructions.toOwnedSlice(),
        .string_bytes = astgen.string_bytes.toOwnedSlice(gpa),
        .extra = astgen.extra.toOwnedSlice(gpa),
    };
}

pub fn deinit(astgen: *AstGen, gpa: *Allocator) void {
    astgen.instructions.deinit(gpa);
    astgen.extra.deinit(gpa);
    astgen.string_table.deinit(gpa);
    astgen.string_bytes.deinit(gpa);
    astgen.compile_errors.deinit(gpa);
    astgen.imports.deinit(gpa);
}

pub const ResultLoc = union(enum) {
    /// The expression is the right-hand side of assignment to `_`. Only the side-effects of the
    /// expression should be generated. The result instruction from the expression must
    /// be ignored.
    discard,
    /// The expression has an inferred type, and it will be evaluated as an rvalue.
    none,
    /// The expression must generate a pointer rather than a value. For example, the left hand side
    /// of an assignment uses this kind of result location.
    ref,
    /// The callee will accept a ref, but it is not necessary, and the `ResultLoc`
    /// may be treated as `none` instead.
    none_or_ref,
    /// The expression will be coerced into this type, but it will be evaluated as an rvalue.
    ty: Zir.Inst.Ref,
    /// The expression must store its result into this typed pointer. The result instruction
    /// from the expression must be ignored.
    ptr: Zir.Inst.Ref,
    /// The expression must store its result into this allocation, which has an inferred type.
    /// The result instruction from the expression must be ignored.
    /// Always an instruction with tag `alloc_inferred`.
    inferred_ptr: Zir.Inst.Ref,
    /// There is a pointer for the expression to store its result into, however, its type
    /// is inferred based on peer type resolution for a `Zir.Inst.Block`.
    /// The result instruction from the expression must be ignored.
    block_ptr: *GenZir,

    pub const Strategy = struct {
        elide_store_to_block_ptr_instructions: bool,
        tag: Tag,

        pub const Tag = enum {
            /// Both branches will use break_void; result location is used to communicate the
            /// result instruction.
            break_void,
            /// Use break statements to pass the block result value, and call rvalue() at
            /// the end depending on rl. Also elide the store_to_block_ptr instructions
            /// depending on rl.
            break_operand,
        };
    };

    fn strategy(rl: ResultLoc, block_scope: *GenZir) Strategy {
        var elide_store_to_block_ptr_instructions = false;
        switch (rl) {
            // In this branch there will not be any store_to_block_ptr instructions.
            .discard, .none, .none_or_ref, .ty, .ref => return .{
                .tag = .break_operand,
                .elide_store_to_block_ptr_instructions = false,
            },
            // The pointer got passed through to the sub-expressions, so we will use
            // break_void here.
            // In this branch there will not be any store_to_block_ptr instructions.
            .ptr => return .{
                .tag = .break_void,
                .elide_store_to_block_ptr_instructions = false,
            },
            .inferred_ptr, .block_ptr => {
                if (block_scope.rvalue_rl_count == block_scope.break_count) {
                    // Neither prong of the if consumed the result location, so we can
                    // use break instructions to create an rvalue.
                    return .{
                        .tag = .break_operand,
                        .elide_store_to_block_ptr_instructions = true,
                    };
                } else {
                    // Allow the store_to_block_ptr instructions to remain so that
                    // semantic analysis can turn them into bitcasts.
                    return .{
                        .tag = .break_void,
                        .elide_store_to_block_ptr_instructions = false,
                    };
                }
            },
        }
    }
};

pub fn typeExpr(gz: *GenZir, scope: *Scope, type_node: ast.Node.Index) InnerError!Zir.Inst.Ref {
    return expr(gz, scope, .{ .ty = .type_type }, type_node);
}

fn lvalExpr(gz: *GenZir, scope: *Scope, node: ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    switch (node_tags[node]) {
        .root => unreachable,
        .@"usingnamespace" => unreachable,
        .test_decl => unreachable,
        .global_var_decl => unreachable,
        .local_var_decl => unreachable,
        .simple_var_decl => unreachable,
        .aligned_var_decl => unreachable,
        .switch_case => unreachable,
        .switch_case_one => unreachable,
        .container_field_init => unreachable,
        .container_field_align => unreachable,
        .container_field => unreachable,
        .asm_output => unreachable,
        .asm_input => unreachable,

        .assign,
        .assign_bit_and,
        .assign_bit_or,
        .assign_bit_shift_left,
        .assign_bit_shift_right,
        .assign_bit_xor,
        .assign_div,
        .assign_sub,
        .assign_sub_wrap,
        .assign_mod,
        .assign_add,
        .assign_add_wrap,
        .assign_mul,
        .assign_mul_wrap,
        .add,
        .add_wrap,
        .sub,
        .sub_wrap,
        .mul,
        .mul_wrap,
        .div,
        .mod,
        .bit_and,
        .bit_or,
        .bit_shift_left,
        .bit_shift_right,
        .bit_xor,
        .bang_equal,
        .equal_equal,
        .greater_than,
        .greater_or_equal,
        .less_than,
        .less_or_equal,
        .array_cat,
        .array_mult,
        .bool_and,
        .bool_or,
        .@"asm",
        .asm_simple,
        .string_literal,
        .integer_literal,
        .call,
        .call_comma,
        .async_call,
        .async_call_comma,
        .call_one,
        .call_one_comma,
        .async_call_one,
        .async_call_one_comma,
        .unreachable_literal,
        .@"return",
        .@"if",
        .if_simple,
        .@"while",
        .while_simple,
        .while_cont,
        .bool_not,
        .address_of,
        .float_literal,
        .undefined_literal,
        .true_literal,
        .false_literal,
        .null_literal,
        .optional_type,
        .block,
        .block_semicolon,
        .block_two,
        .block_two_semicolon,
        .@"break",
        .ptr_type_aligned,
        .ptr_type_sentinel,
        .ptr_type,
        .ptr_type_bit_range,
        .array_type,
        .array_type_sentinel,
        .enum_literal,
        .multiline_string_literal,
        .char_literal,
        .@"defer",
        .@"errdefer",
        .@"catch",
        .error_union,
        .merge_error_sets,
        .switch_range,
        .@"await",
        .bit_not,
        .negation,
        .negation_wrap,
        .@"resume",
        .@"try",
        .slice,
        .slice_open,
        .slice_sentinel,
        .array_init_one,
        .array_init_one_comma,
        .array_init_dot_two,
        .array_init_dot_two_comma,
        .array_init_dot,
        .array_init_dot_comma,
        .array_init,
        .array_init_comma,
        .struct_init_one,
        .struct_init_one_comma,
        .struct_init_dot_two,
        .struct_init_dot_two_comma,
        .struct_init_dot,
        .struct_init_dot_comma,
        .struct_init,
        .struct_init_comma,
        .@"switch",
        .switch_comma,
        .@"for",
        .for_simple,
        .@"suspend",
        .@"continue",
        .@"anytype",
        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        .fn_decl,
        .anyframe_type,
        .anyframe_literal,
        .error_set_decl,
        .container_decl,
        .container_decl_trailing,
        .container_decl_two,
        .container_decl_two_trailing,
        .container_decl_arg,
        .container_decl_arg_trailing,
        .tagged_union,
        .tagged_union_trailing,
        .tagged_union_two,
        .tagged_union_two_trailing,
        .tagged_union_enum_tag,
        .tagged_union_enum_tag_trailing,
        .@"comptime",
        .@"nosuspend",
        .error_value,
        => return astgen.failNode(node, "invalid left-hand side to assignment", .{}),

        .builtin_call,
        .builtin_call_comma,
        .builtin_call_two,
        .builtin_call_two_comma,
        => {
            const builtin_token = main_tokens[node];
            const builtin_name = tree.tokenSlice(builtin_token);
            // If the builtin is an invalid name, we don't cause an error here; instead
            // let it pass, and the error will be "invalid builtin function" later.
            if (BuiltinFn.list.get(builtin_name)) |info| {
                if (!info.allows_lvalue) {
                    return astgen.failNode(node, "invalid left-hand side to assignment", .{});
                }
            }
        },

        // These can be assigned to.
        .unwrap_optional,
        .deref,
        .field_access,
        .array_access,
        .identifier,
        .grouped_expression,
        .@"orelse",
        => {},
    }
    return expr(gz, scope, .ref, node);
}

/// Turn Zig AST into untyped ZIR istructions.
/// When `rl` is discard, ptr, inferred_ptr, or inferred_ptr, the
/// result instruction can be used to inspect whether it is isNoReturn() but that is it,
/// it must otherwise not be used.
pub fn expr(gz: *GenZir, scope: *Scope, rl: ResultLoc, node: ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);
    const node_datas = tree.nodes.items(.data);
    const node_tags = tree.nodes.items(.tag);

    switch (node_tags[node]) {
        .root => unreachable, // Top-level declaration.
        .@"usingnamespace" => unreachable, // Top-level declaration.
        .test_decl => unreachable, // Top-level declaration.
        .container_field_init => unreachable, // Top-level declaration.
        .container_field_align => unreachable, // Top-level declaration.
        .container_field => unreachable, // Top-level declaration.
        .fn_decl => unreachable, // Top-level declaration.

        .global_var_decl => unreachable, // Handled in `blockExpr`.
        .local_var_decl => unreachable, // Handled in `blockExpr`.
        .simple_var_decl => unreachable, // Handled in `blockExpr`.
        .aligned_var_decl => unreachable, // Handled in `blockExpr`.

        .switch_case => unreachable, // Handled in `switchExpr`.
        .switch_case_one => unreachable, // Handled in `switchExpr`.
        .switch_range => unreachable, // Handled in `switchExpr`.

        .asm_output => unreachable, // Handled in `asmExpr`.
        .asm_input => unreachable, // Handled in `asmExpr`.

        .assign => {
            try assign(gz, scope, node);
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .assign_bit_and => {
            try assignOp(gz, scope, node, .bit_and);
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .assign_bit_or => {
            try assignOp(gz, scope, node, .bit_or);
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .assign_bit_shift_left => {
            try assignOp(gz, scope, node, .shl);
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .assign_bit_shift_right => {
            try assignOp(gz, scope, node, .shr);
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .assign_bit_xor => {
            try assignOp(gz, scope, node, .xor);
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .assign_div => {
            try assignOp(gz, scope, node, .div);
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .assign_sub => {
            try assignOp(gz, scope, node, .sub);
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .assign_sub_wrap => {
            try assignOp(gz, scope, node, .subwrap);
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .assign_mod => {
            try assignOp(gz, scope, node, .mod_rem);
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .assign_add => {
            try assignOp(gz, scope, node, .add);
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .assign_add_wrap => {
            try assignOp(gz, scope, node, .addwrap);
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .assign_mul => {
            try assignOp(gz, scope, node, .mul);
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .assign_mul_wrap => {
            try assignOp(gz, scope, node, .mulwrap);
            return rvalue(gz, scope, rl, .void_value, node);
        },

        .add => return simpleBinOp(gz, scope, rl, node, .add),
        .add_wrap => return simpleBinOp(gz, scope, rl, node, .addwrap),
        .sub => return simpleBinOp(gz, scope, rl, node, .sub),
        .sub_wrap => return simpleBinOp(gz, scope, rl, node, .subwrap),
        .mul => return simpleBinOp(gz, scope, rl, node, .mul),
        .mul_wrap => return simpleBinOp(gz, scope, rl, node, .mulwrap),
        .div => return simpleBinOp(gz, scope, rl, node, .div),
        .mod => return simpleBinOp(gz, scope, rl, node, .mod_rem),
        .bit_and => return simpleBinOp(gz, scope, rl, node, .bit_and),
        .bit_or => return simpleBinOp(gz, scope, rl, node, .bit_or),
        .bit_shift_left => return simpleBinOp(gz, scope, rl, node, .shl),
        .bit_shift_right => return simpleBinOp(gz, scope, rl, node, .shr),
        .bit_xor => return simpleBinOp(gz, scope, rl, node, .xor),

        .bang_equal => return simpleBinOp(gz, scope, rl, node, .cmp_neq),
        .equal_equal => return simpleBinOp(gz, scope, rl, node, .cmp_eq),
        .greater_than => return simpleBinOp(gz, scope, rl, node, .cmp_gt),
        .greater_or_equal => return simpleBinOp(gz, scope, rl, node, .cmp_gte),
        .less_than => return simpleBinOp(gz, scope, rl, node, .cmp_lt),
        .less_or_equal => return simpleBinOp(gz, scope, rl, node, .cmp_lte),

        .array_cat => return simpleBinOp(gz, scope, rl, node, .array_cat),
        .array_mult => return simpleBinOp(gz, scope, rl, node, .array_mul),

        .error_union => return simpleBinOp(gz, scope, rl, node, .error_union_type),
        .merge_error_sets => return simpleBinOp(gz, scope, rl, node, .merge_error_sets),

        .bool_and => return boolBinOp(gz, scope, rl, node, .bool_br_and),
        .bool_or => return boolBinOp(gz, scope, rl, node, .bool_br_or),

        .bool_not => return boolNot(gz, scope, rl, node),
        .bit_not => return bitNot(gz, scope, rl, node),

        .negation => return negation(gz, scope, rl, node, .negate),
        .negation_wrap => return negation(gz, scope, rl, node, .negate_wrap),

        .identifier => return identifier(gz, scope, rl, node),

        .asm_simple => return asmExpr(gz, scope, rl, node, tree.asmSimple(node)),
        .@"asm" => return asmExpr(gz, scope, rl, node, tree.asmFull(node)),

        .string_literal => return stringLiteral(gz, scope, rl, node),
        .multiline_string_literal => return multilineStringLiteral(gz, scope, rl, node),

        .integer_literal => return integerLiteral(gz, scope, rl, node),

        .builtin_call_two, .builtin_call_two_comma => {
            if (node_datas[node].lhs == 0) {
                const params = [_]ast.Node.Index{};
                return builtinCall(gz, scope, rl, node, &params);
            } else if (node_datas[node].rhs == 0) {
                const params = [_]ast.Node.Index{node_datas[node].lhs};
                return builtinCall(gz, scope, rl, node, &params);
            } else {
                const params = [_]ast.Node.Index{ node_datas[node].lhs, node_datas[node].rhs };
                return builtinCall(gz, scope, rl, node, &params);
            }
        },
        .builtin_call, .builtin_call_comma => {
            const params = tree.extra_data[node_datas[node].lhs..node_datas[node].rhs];
            return builtinCall(gz, scope, rl, node, params);
        },

        .call_one, .call_one_comma, .async_call_one, .async_call_one_comma => {
            var params: [1]ast.Node.Index = undefined;
            return callExpr(gz, scope, rl, node, tree.callOne(&params, node));
        },
        .call, .call_comma, .async_call, .async_call_comma => {
            return callExpr(gz, scope, rl, node, tree.callFull(node));
        },

        .unreachable_literal => {
            _ = try gz.addAsIndex(.{
                .tag = .@"unreachable",
                .data = .{ .@"unreachable" = .{
                    .safety = true,
                    .src_node = gz.nodeIndexToRelative(node),
                } },
            });
            return Zir.Inst.Ref.unreachable_value;
        },
        .@"return" => return ret(gz, scope, node),
        .field_access => return fieldAccess(gz, scope, rl, node),
        .float_literal => return floatLiteral(gz, scope, rl, node),

        .if_simple => return ifExpr(gz, scope, rl, node, tree.ifSimple(node)),
        .@"if" => return ifExpr(gz, scope, rl, node, tree.ifFull(node)),

        .while_simple => return whileExpr(gz, scope, rl, node, tree.whileSimple(node)),
        .while_cont => return whileExpr(gz, scope, rl, node, tree.whileCont(node)),
        .@"while" => return whileExpr(gz, scope, rl, node, tree.whileFull(node)),

        .for_simple => return forExpr(gz, scope, rl, node, tree.forSimple(node)),
        .@"for" => return forExpr(gz, scope, rl, node, tree.forFull(node)),

        .slice_open => {
            const lhs = try expr(gz, scope, .ref, node_datas[node].lhs);
            const start = try expr(gz, scope, .{ .ty = .usize_type }, node_datas[node].rhs);
            const result = try gz.addPlNode(.slice_start, node, Zir.Inst.SliceStart{
                .lhs = lhs,
                .start = start,
            });
            return rvalue(gz, scope, rl, result, node);
        },
        .slice => {
            const lhs = try expr(gz, scope, .ref, node_datas[node].lhs);
            const extra = tree.extraData(node_datas[node].rhs, ast.Node.Slice);
            const start = try expr(gz, scope, .{ .ty = .usize_type }, extra.start);
            const end = try expr(gz, scope, .{ .ty = .usize_type }, extra.end);
            const result = try gz.addPlNode(.slice_end, node, Zir.Inst.SliceEnd{
                .lhs = lhs,
                .start = start,
                .end = end,
            });
            return rvalue(gz, scope, rl, result, node);
        },
        .slice_sentinel => {
            const lhs = try expr(gz, scope, .ref, node_datas[node].lhs);
            const extra = tree.extraData(node_datas[node].rhs, ast.Node.SliceSentinel);
            const start = try expr(gz, scope, .{ .ty = .usize_type }, extra.start);
            const end = try expr(gz, scope, .{ .ty = .usize_type }, extra.end);
            const sentinel = try expr(gz, scope, .{ .ty = .usize_type }, extra.sentinel);
            const result = try gz.addPlNode(.slice_sentinel, node, Zir.Inst.SliceSentinel{
                .lhs = lhs,
                .start = start,
                .end = end,
                .sentinel = sentinel,
            });
            return rvalue(gz, scope, rl, result, node);
        },

        .deref => {
            const lhs = try expr(gz, scope, .none, node_datas[node].lhs);
            switch (rl) {
                .ref, .none_or_ref => return lhs,
                else => {
                    const result = try gz.addUnNode(.load, lhs, node);
                    return rvalue(gz, scope, rl, result, node);
                },
            }
        },
        .address_of => {
            const result = try expr(gz, scope, .ref, node_datas[node].lhs);
            return rvalue(gz, scope, rl, result, node);
        },
        .undefined_literal => return rvalue(gz, scope, rl, .undef, node),
        .true_literal => return rvalue(gz, scope, rl, .bool_true, node),
        .false_literal => return rvalue(gz, scope, rl, .bool_false, node),
        .null_literal => return rvalue(gz, scope, rl, .null_value, node),
        .optional_type => {
            const operand = try typeExpr(gz, scope, node_datas[node].lhs);
            const result = try gz.addUnNode(.optional_type, operand, node);
            return rvalue(gz, scope, rl, result, node);
        },
        .unwrap_optional => switch (rl) {
            .ref => return gz.addUnNode(
                .optional_payload_safe_ptr,
                try expr(gz, scope, .ref, node_datas[node].lhs),
                node,
            ),
            else => return rvalue(gz, scope, rl, try gz.addUnNode(
                .optional_payload_safe,
                try expr(gz, scope, .none, node_datas[node].lhs),
                node,
            ), node),
        },
        .block_two, .block_two_semicolon => {
            const statements = [2]ast.Node.Index{ node_datas[node].lhs, node_datas[node].rhs };
            if (node_datas[node].lhs == 0) {
                return blockExpr(gz, scope, rl, node, statements[0..0]);
            } else if (node_datas[node].rhs == 0) {
                return blockExpr(gz, scope, rl, node, statements[0..1]);
            } else {
                return blockExpr(gz, scope, rl, node, statements[0..2]);
            }
        },
        .block, .block_semicolon => {
            const statements = tree.extra_data[node_datas[node].lhs..node_datas[node].rhs];
            return blockExpr(gz, scope, rl, node, statements);
        },
        .enum_literal => return simpleStrTok(gz, scope, rl, main_tokens[node], node, .enum_literal),
        .error_value => return simpleStrTok(gz, scope, rl, node_datas[node].rhs, node, .error_value),
        .anyframe_literal => return astgen.failNode(node, "async and related features are not yet supported", .{}),
        .anyframe_type => return astgen.failNode(node, "async and related features are not yet supported", .{}),
        .@"catch" => {
            const catch_token = main_tokens[node];
            const payload_token: ?ast.TokenIndex = if (token_tags[catch_token + 1] == .pipe)
                catch_token + 2
            else
                null;
            switch (rl) {
                .ref => return orelseCatchExpr(
                    gz,
                    scope,
                    rl,
                    node,
                    node_datas[node].lhs,
                    .is_err_ptr,
                    .err_union_payload_unsafe_ptr,
                    .err_union_code_ptr,
                    node_datas[node].rhs,
                    payload_token,
                ),
                else => return orelseCatchExpr(
                    gz,
                    scope,
                    rl,
                    node,
                    node_datas[node].lhs,
                    .is_err,
                    .err_union_payload_unsafe,
                    .err_union_code,
                    node_datas[node].rhs,
                    payload_token,
                ),
            }
        },
        .@"orelse" => switch (rl) {
            .ref => return orelseCatchExpr(
                gz,
                scope,
                rl,
                node,
                node_datas[node].lhs,
                .is_null_ptr,
                .optional_payload_unsafe_ptr,
                undefined,
                node_datas[node].rhs,
                null,
            ),
            else => return orelseCatchExpr(
                gz,
                scope,
                rl,
                node,
                node_datas[node].lhs,
                .is_null,
                .optional_payload_unsafe,
                undefined,
                node_datas[node].rhs,
                null,
            ),
        },

        .ptr_type_aligned => return ptrType(gz, scope, rl, node, tree.ptrTypeAligned(node)),
        .ptr_type_sentinel => return ptrType(gz, scope, rl, node, tree.ptrTypeSentinel(node)),
        .ptr_type => return ptrType(gz, scope, rl, node, tree.ptrType(node)),
        .ptr_type_bit_range => return ptrType(gz, scope, rl, node, tree.ptrTypeBitRange(node)),

        .container_decl,
        .container_decl_trailing,
        => return containerDecl(gz, scope, rl, node, tree.containerDecl(node)),
        .container_decl_two, .container_decl_two_trailing => {
            var buffer: [2]ast.Node.Index = undefined;
            return containerDecl(gz, scope, rl, node, tree.containerDeclTwo(&buffer, node));
        },
        .container_decl_arg,
        .container_decl_arg_trailing,
        => return containerDecl(gz, scope, rl, node, tree.containerDeclArg(node)),

        .tagged_union,
        .tagged_union_trailing,
        => return containerDecl(gz, scope, rl, node, tree.taggedUnion(node)),
        .tagged_union_two, .tagged_union_two_trailing => {
            var buffer: [2]ast.Node.Index = undefined;
            return containerDecl(gz, scope, rl, node, tree.taggedUnionTwo(&buffer, node));
        },
        .tagged_union_enum_tag,
        .tagged_union_enum_tag_trailing,
        => return containerDecl(gz, scope, rl, node, tree.taggedUnionEnumTag(node)),

        .@"break" => return breakExpr(gz, scope, node),
        .@"continue" => return continueExpr(gz, scope, node),
        .grouped_expression => return expr(gz, scope, rl, node_datas[node].lhs),
        .array_type => return arrayType(gz, scope, rl, node),
        .array_type_sentinel => return arrayTypeSentinel(gz, scope, rl, node),
        .char_literal => return charLiteral(gz, scope, rl, node),
        .error_set_decl => return errorSetDecl(gz, scope, rl, node),
        .array_access => return arrayAccess(gz, scope, rl, node),
        .@"comptime" => return comptimeExpr(gz, scope, rl, node_datas[node].lhs),
        .@"switch", .switch_comma => return switchExpr(gz, scope, rl, node),

        .@"nosuspend" => return astgen.failNode(node, "async and related features are not yet supported", .{}),
        .@"suspend" => return astgen.failNode(node, "async and related features are not yet supported", .{}),
        .@"await" => return astgen.failNode(node, "async and related features are not yet supported", .{}),
        .@"resume" => return astgen.failNode(node, "async and related features are not yet supported", .{}),

        .@"defer" => return astgen.failNode(node, "TODO implement astgen.expr for .defer", .{}),
        .@"errdefer" => return astgen.failNode(node, "TODO implement astgen.expr for .errdefer", .{}),
        .@"try" => return astgen.failNode(node, "TODO implement astgen.expr for .Try", .{}),

        .array_init_one,
        .array_init_one_comma,
        .array_init_dot_two,
        .array_init_dot_two_comma,
        .array_init_dot,
        .array_init_dot_comma,
        .array_init,
        .array_init_comma,
        => return astgen.failNode(node, "TODO implement astgen.expr for array literals", .{}),

        .struct_init_one, .struct_init_one_comma => {
            var fields: [1]ast.Node.Index = undefined;
            return structInitExpr(gz, scope, rl, node, tree.structInitOne(&fields, node));
        },
        .struct_init_dot_two, .struct_init_dot_two_comma => {
            var fields: [2]ast.Node.Index = undefined;
            return structInitExpr(gz, scope, rl, node, tree.structInitDotTwo(&fields, node));
        },
        .struct_init_dot,
        .struct_init_dot_comma,
        => return structInitExpr(gz, scope, rl, node, tree.structInitDot(node)),
        .struct_init,
        .struct_init_comma,
        => return structInitExpr(gz, scope, rl, node, tree.structInit(node)),

        .@"anytype" => return astgen.failNode(node, "TODO implement astgen.expr for .anytype", .{}),
        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => return astgen.failNode(node, "TODO implement astgen.expr for function prototypes", .{}),
    }
}

pub fn structInitExpr(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    struct_init: ast.full.StructInit,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const gpa = astgen.gpa;

    if (struct_init.ast.fields.len == 0) {
        if (struct_init.ast.type_expr == 0) {
            return rvalue(gz, scope, rl, .empty_struct, node);
        } else {
            const ty_inst = try typeExpr(gz, scope, struct_init.ast.type_expr);
            const result = try gz.addUnNode(.struct_init_empty, ty_inst, node);
            return rvalue(gz, scope, rl, result, node);
        }
    }
    switch (rl) {
        .discard => return astgen.failNode(node, "TODO implement structInitExpr discard", .{}),
        .none, .none_or_ref => return astgen.failNode(node, "TODO implement structInitExpr none", .{}),
        .ref => unreachable, // struct literal not valid as l-value
        .ty => |ty_inst| {
            const fields_list = try gpa.alloc(Zir.Inst.StructInit.Item, struct_init.ast.fields.len);
            defer gpa.free(fields_list);

            for (struct_init.ast.fields) |field_init, i| {
                const name_token = tree.firstToken(field_init) - 2;
                const str_index = try gz.identAsString(name_token);

                const field_ty_inst = try gz.addPlNode(.field_type, field_init, Zir.Inst.FieldType{
                    .container_type = ty_inst,
                    .name_start = str_index,
                });
                fields_list[i] = .{
                    .field_type = gz.refToIndex(field_ty_inst).?,
                    .init = try expr(gz, scope, .{ .ty = field_ty_inst }, field_init),
                };
            }
            const init_inst = try gz.addPlNode(.struct_init, node, Zir.Inst.StructInit{
                .fields_len = @intCast(u32, fields_list.len),
            });
            try astgen.extra.ensureCapacity(gpa, astgen.extra.items.len +
                fields_list.len * @typeInfo(Zir.Inst.StructInit.Item).Struct.fields.len);
            for (fields_list) |field| {
                _ = gz.astgen.addExtraAssumeCapacity(field);
            }
            return rvalue(gz, scope, rl, init_inst, node);
        },
        .ptr => |ptr_inst| {
            const field_ptr_list = try gpa.alloc(Zir.Inst.Index, struct_init.ast.fields.len);
            defer gpa.free(field_ptr_list);

            for (struct_init.ast.fields) |field_init, i| {
                const name_token = tree.firstToken(field_init) - 2;
                const str_index = try gz.identAsString(name_token);
                const field_ptr = try gz.addPlNode(.field_ptr, field_init, Zir.Inst.Field{
                    .lhs = ptr_inst,
                    .field_name_start = str_index,
                });
                field_ptr_list[i] = gz.refToIndex(field_ptr).?;
                _ = try expr(gz, scope, .{ .ptr = field_ptr }, field_init);
            }
            const validate_inst = try gz.addPlNode(.validate_struct_init_ptr, node, Zir.Inst.Block{
                .body_len = @intCast(u32, field_ptr_list.len),
            });
            try astgen.extra.appendSlice(gpa, field_ptr_list);
            return validate_inst;
        },
        .inferred_ptr => |ptr_inst| {
            return astgen.failNode(node, "TODO implement structInitExpr inferred_ptr", .{});
        },
        .block_ptr => |block_gz| {
            return astgen.failNode(node, "TODO implement structInitExpr block", .{});
        },
    }
}

pub fn comptimeExpr(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const prev_force_comptime = gz.force_comptime;
    gz.force_comptime = true;
    const result = try expr(gz, scope, rl, node);
    gz.force_comptime = prev_force_comptime;
    return result;
}

fn breakExpr(parent_gz: *GenZir, parent_scope: *Scope, node: ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);
    const break_label = node_datas[node].lhs;
    const rhs = node_datas[node].rhs;

    // Look for the label in the scope.
    var scope = parent_scope;
    while (true) {
        switch (scope.tag) {
            .gen_zir => {
                const block_gz = scope.cast(GenZir).?;

                const block_inst = blk: {
                    if (break_label != 0) {
                        if (block_gz.label) |*label| {
                            if (try astgen.tokenIdentEql(label.token, break_label)) {
                                label.used = true;
                                break :blk label.block_inst;
                            }
                        }
                    } else if (block_gz.break_block != 0) {
                        break :blk block_gz.break_block;
                    }
                    scope = block_gz.parent;
                    continue;
                };

                if (rhs == 0) {
                    _ = try parent_gz.addBreak(.@"break", block_inst, .void_value);
                    return Zir.Inst.Ref.unreachable_value;
                }
                block_gz.break_count += 1;
                const prev_rvalue_rl_count = block_gz.rvalue_rl_count;
                const operand = try expr(parent_gz, parent_scope, block_gz.break_result_loc, rhs);
                const have_store_to_block = block_gz.rvalue_rl_count != prev_rvalue_rl_count;

                const br = try parent_gz.addBreak(.@"break", block_inst, operand);

                if (block_gz.break_result_loc == .block_ptr) {
                    try block_gz.labeled_breaks.append(astgen.gpa, br);

                    if (have_store_to_block) {
                        const zir_tags = parent_gz.astgen.instructions.items(.tag);
                        const zir_datas = parent_gz.astgen.instructions.items(.data);
                        const store_inst = @intCast(u32, zir_tags.len - 2);
                        assert(zir_tags[store_inst] == .store_to_block_ptr);
                        assert(zir_datas[store_inst].bin.lhs == block_gz.rl_ptr);
                        try block_gz.labeled_store_to_block_ptr_list.append(astgen.gpa, store_inst);
                    }
                }
                return Zir.Inst.Ref.unreachable_value;
            },
            .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
            .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
            else => if (break_label != 0) {
                const label_name = try astgen.identifierTokenString(break_label);
                return astgen.failTok(break_label, "label not found: '{s}'", .{label_name});
            } else {
                return astgen.failNode(node, "break expression outside loop", .{});
            },
        }
    }
}

fn continueExpr(parent_gz: *GenZir, parent_scope: *Scope, node: ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);
    const break_label = node_datas[node].lhs;

    // Look for the label in the scope.
    var scope = parent_scope;
    while (true) {
        switch (scope.tag) {
            .gen_zir => {
                const gen_zir = scope.cast(GenZir).?;
                const continue_block = gen_zir.continue_block;
                if (continue_block == 0) {
                    scope = gen_zir.parent;
                    continue;
                }
                if (break_label != 0) blk: {
                    if (gen_zir.label) |*label| {
                        if (try astgen.tokenIdentEql(label.token, break_label)) {
                            label.used = true;
                            break :blk;
                        }
                    }
                    // found continue but either it has a different label, or no label
                    scope = gen_zir.parent;
                    continue;
                }

                // TODO emit a break_inline if the loop being continued is inline
                _ = try parent_gz.addBreak(.@"break", continue_block, .void_value);
                return Zir.Inst.Ref.unreachable_value;
            },
            .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
            .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
            else => if (break_label != 0) {
                const label_name = try astgen.identifierTokenString(break_label);
                return astgen.failTok(break_label, "label not found: '{s}'", .{label_name});
            } else {
                return astgen.failNode(node, "continue expression outside loop", .{});
            },
        }
    }
}

pub fn blockExpr(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    block_node: ast.Node.Index,
    statements: []const ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);

    const lbrace = main_tokens[block_node];
    if (token_tags[lbrace - 1] == .colon and
        token_tags[lbrace - 2] == .identifier)
    {
        return labeledBlockExpr(gz, scope, rl, block_node, statements, .block);
    }

    try blockExprStmts(gz, scope, block_node, statements);
    return rvalue(gz, scope, rl, .void_value, block_node);
}

fn checkLabelRedefinition(astgen: *AstGen, parent_scope: *Scope, label: ast.TokenIndex) !void {
    // Look for the label in the scope.
    var scope = parent_scope;
    while (true) {
        switch (scope.tag) {
            .gen_zir => {
                const gen_zir = scope.cast(GenZir).?;
                if (gen_zir.label) |prev_label| {
                    if (try astgen.tokenIdentEql(label, prev_label.token)) {
                        const tree = &astgen.file.tree;
                        const main_tokens = tree.nodes.items(.main_token);

                        const label_name = try astgen.identifierTokenString(label);
                        return astgen.failTokNotes(label, "redefinition of label '{s}'", .{
                            label_name,
                        }, &[_]u32{
                            try astgen.errNoteTok(
                                prev_label.token,
                                "previous definition is here",
                                .{},
                            ),
                        });
                    }
                }
                scope = gen_zir.parent;
            },
            .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
            .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
            else => return,
        }
    }
}

fn labeledBlockExpr(
    gz: *GenZir,
    parent_scope: *Scope,
    rl: ResultLoc,
    block_node: ast.Node.Index,
    statements: []const ast.Node.Index,
    zir_tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    assert(zir_tag == .block);

    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);

    const lbrace = main_tokens[block_node];
    const label_token = lbrace - 2;
    assert(token_tags[label_token] == .identifier);

    try astgen.checkLabelRedefinition(parent_scope, label_token);

    // Reserve the Block ZIR instruction index so that we can put it into the GenZir struct
    // so that break statements can reference it.
    const block_inst = try gz.addBlock(zir_tag, block_node);
    try gz.instructions.append(astgen.gpa, block_inst);

    var block_scope: GenZir = .{
        .parent = parent_scope,
        .decl_node_index = gz.decl_node_index,
        .astgen = gz.astgen,
        .force_comptime = gz.force_comptime,
        .instructions = .{},
        // TODO @as here is working around a stage1 miscompilation bug :(
        .label = @as(?GenZir.Label, GenZir.Label{
            .token = label_token,
            .block_inst = block_inst,
        }),
    };
    block_scope.setBreakResultLoc(rl);
    defer block_scope.instructions.deinit(astgen.gpa);
    defer block_scope.labeled_breaks.deinit(astgen.gpa);
    defer block_scope.labeled_store_to_block_ptr_list.deinit(astgen.gpa);

    try blockExprStmts(&block_scope, &block_scope.base, block_node, statements);

    if (!block_scope.label.?.used) {
        return astgen.failTok(label_token, "unused block label", .{});
    }

    const zir_tags = gz.astgen.instructions.items(.tag);
    const zir_datas = gz.astgen.instructions.items(.data);

    const strat = rl.strategy(&block_scope);
    switch (strat.tag) {
        .break_void => {
            // The code took advantage of the result location as a pointer.
            // Turn the break instruction operands into void.
            for (block_scope.labeled_breaks.items) |br| {
                zir_datas[br].@"break".operand = .void_value;
            }
            try block_scope.setBlockBody(block_inst);

            return gz.indexToRef(block_inst);
        },
        .break_operand => {
            // All break operands are values that did not use the result location pointer.
            if (strat.elide_store_to_block_ptr_instructions) {
                for (block_scope.labeled_store_to_block_ptr_list.items) |inst| {
                    zir_tags[inst] = .elided;
                    zir_datas[inst] = undefined;
                }
                // TODO technically not needed since we changed the tag to elided but
                // would be better still to elide the ones that are in this list.
            }
            try block_scope.setBlockBody(block_inst);
            const block_ref = gz.indexToRef(block_inst);
            switch (rl) {
                .ref => return block_ref,
                else => return rvalue(gz, parent_scope, rl, block_ref, block_node),
            }
        },
    }
}

fn blockExprStmts(
    gz: *GenZir,
    parent_scope: *Scope,
    node: ast.Node.Index,
    statements: []const ast.Node.Index,
) !void {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const node_tags = tree.nodes.items(.tag);

    var block_arena = std.heap.ArenaAllocator.init(gz.astgen.gpa);
    defer block_arena.deinit();

    var scope = parent_scope;
    for (statements) |statement| {
        if (!gz.force_comptime) {
            _ = try gz.addNode(.dbg_stmt_node, statement);
        }
        switch (node_tags[statement]) {
            .global_var_decl => scope = try varDecl(gz, scope, statement, &block_arena.allocator, tree.globalVarDecl(statement)),
            .local_var_decl => scope = try varDecl(gz, scope, statement, &block_arena.allocator, tree.localVarDecl(statement)),
            .simple_var_decl => scope = try varDecl(gz, scope, statement, &block_arena.allocator, tree.simpleVarDecl(statement)),
            .aligned_var_decl => scope = try varDecl(gz, scope, statement, &block_arena.allocator, tree.alignedVarDecl(statement)),

            .assign => try assign(gz, scope, statement),
            .assign_bit_and => try assignOp(gz, scope, statement, .bit_and),
            .assign_bit_or => try assignOp(gz, scope, statement, .bit_or),
            .assign_bit_shift_left => try assignOp(gz, scope, statement, .shl),
            .assign_bit_shift_right => try assignOp(gz, scope, statement, .shr),
            .assign_bit_xor => try assignOp(gz, scope, statement, .xor),
            .assign_div => try assignOp(gz, scope, statement, .div),
            .assign_sub => try assignOp(gz, scope, statement, .sub),
            .assign_sub_wrap => try assignOp(gz, scope, statement, .subwrap),
            .assign_mod => try assignOp(gz, scope, statement, .mod_rem),
            .assign_add => try assignOp(gz, scope, statement, .add),
            .assign_add_wrap => try assignOp(gz, scope, statement, .addwrap),
            .assign_mul => try assignOp(gz, scope, statement, .mul),
            .assign_mul_wrap => try assignOp(gz, scope, statement, .mulwrap),

            else => {
                // We need to emit an error if the result is not `noreturn` or `void`, but
                // we want to avoid adding the ZIR instruction if possible for performance.
                const maybe_unused_result = try expr(gz, scope, .none, statement);
                const elide_check = if (gz.refToIndex(maybe_unused_result)) |inst| b: {
                    // Note that this array becomes invalid after appending more items to it
                    // in the above while loop.
                    const zir_tags = gz.astgen.instructions.items(.tag);
                    switch (zir_tags[inst]) {
                        // For some instructions, swap in a slightly different ZIR tag
                        // so we can avoid a separate ensure_result_used instruction.
                        .call_none_chkused => unreachable,
                        .call_none => {
                            zir_tags[inst] = .call_none_chkused;
                            break :b true;
                        },
                        .call_chkused => unreachable,
                        .call => {
                            zir_tags[inst] = .call_chkused;
                            break :b true;
                        },

                        // ZIR instructions that might be a type other than `noreturn` or `void`.
                        .add,
                        .addwrap,
                        .alloc,
                        .alloc_mut,
                        .alloc_inferred,
                        .alloc_inferred_mut,
                        .array_cat,
                        .array_mul,
                        .array_type,
                        .array_type_sentinel,
                        .indexable_ptr_len,
                        .as,
                        .as_node,
                        .@"asm",
                        .asm_volatile,
                        .bit_and,
                        .bitcast,
                        .bitcast_result_ptr,
                        .bit_or,
                        .block,
                        .block_inline,
                        .block_inline_var,
                        .loop,
                        .bool_br_and,
                        .bool_br_or,
                        .bool_not,
                        .bool_and,
                        .bool_or,
                        .call_compile_time,
                        .cmp_lt,
                        .cmp_lte,
                        .cmp_eq,
                        .cmp_gte,
                        .cmp_gt,
                        .cmp_neq,
                        .coerce_result_ptr,
                        .decl_ref,
                        .decl_val,
                        .load,
                        .div,
                        .elem_ptr,
                        .elem_val,
                        .elem_ptr_node,
                        .elem_val_node,
                        .floatcast,
                        .field_ptr,
                        .field_val,
                        .field_ptr_named,
                        .field_val_named,
                        .func,
                        .func_var_args,
                        .func_extra,
                        .func_extra_var_args,
                        .has_decl,
                        .int,
                        .float,
                        .float128,
                        .intcast,
                        .int_type,
                        .is_non_null,
                        .is_null,
                        .is_non_null_ptr,
                        .is_null_ptr,
                        .is_err,
                        .is_err_ptr,
                        .mod_rem,
                        .mul,
                        .mulwrap,
                        .param_type,
                        .ptrtoint,
                        .ref,
                        .ret_ptr,
                        .ret_type,
                        .shl,
                        .shr,
                        .str,
                        .sub,
                        .subwrap,
                        .negate,
                        .negate_wrap,
                        .typeof,
                        .typeof_elem,
                        .xor,
                        .optional_type,
                        .optional_type_from_ptr_elem,
                        .optional_payload_safe,
                        .optional_payload_unsafe,
                        .optional_payload_safe_ptr,
                        .optional_payload_unsafe_ptr,
                        .err_union_payload_safe,
                        .err_union_payload_unsafe,
                        .err_union_payload_safe_ptr,
                        .err_union_payload_unsafe_ptr,
                        .err_union_code,
                        .err_union_code_ptr,
                        .ptr_type,
                        .ptr_type_simple,
                        .enum_literal,
                        .enum_literal_small,
                        .merge_error_sets,
                        .error_union_type,
                        .bit_not,
                        .error_value,
                        .error_to_int,
                        .int_to_error,
                        .slice_start,
                        .slice_end,
                        .slice_sentinel,
                        .import,
                        .typeof_peer,
                        .switch_block,
                        .switch_block_multi,
                        .switch_block_else,
                        .switch_block_else_multi,
                        .switch_block_under,
                        .switch_block_under_multi,
                        .switch_block_ref,
                        .switch_block_ref_multi,
                        .switch_block_ref_else,
                        .switch_block_ref_else_multi,
                        .switch_block_ref_under,
                        .switch_block_ref_under_multi,
                        .switch_capture,
                        .switch_capture_ref,
                        .switch_capture_multi,
                        .switch_capture_multi_ref,
                        .switch_capture_else,
                        .switch_capture_else_ref,
                        .struct_init_empty,
                        .struct_init,
                        .field_type,
                        .struct_decl,
                        .struct_decl_packed,
                        .struct_decl_extern,
                        .union_decl,
                        .enum_decl,
                        .enum_decl_nonexhaustive,
                        .opaque_decl,
                        .int_to_enum,
                        .enum_to_int,
                        .type_info,
                        .size_of,
                        .bit_size_of,
                        .this,
                        .fence,
                        .ret_addr,
                        .builtin_src,
                        .add_with_overflow,
                        .sub_with_overflow,
                        .mul_with_overflow,
                        .shl_with_overflow,
                        .log2_int_type,
                        => break :b false,

                        // ZIR instructions that are always either `noreturn` or `void`.
                        .breakpoint,
                        .dbg_stmt_node,
                        .ensure_result_used,
                        .ensure_result_non_error,
                        .@"export",
                        .set_eval_branch_quota,
                        .compile_log,
                        .ensure_err_payload_void,
                        .@"break",
                        .break_inline,
                        .condbr,
                        .condbr_inline,
                        .compile_error,
                        .ret_node,
                        .ret_tok,
                        .ret_coerce,
                        .@"unreachable",
                        .elided,
                        .store,
                        .store_node,
                        .store_to_block_ptr,
                        .store_to_inferred_ptr,
                        .resolve_inferred_alloc,
                        .repeat,
                        .repeat_inline,
                        .validate_struct_init_ptr,
                        => break :b true,
                    }
                } else switch (maybe_unused_result) {
                    .none => unreachable,

                    .void_value,
                    .unreachable_value,
                    => true,

                    else => false,
                };
                if (!elide_check) {
                    _ = try gz.addUnNode(.ensure_result_used, maybe_unused_result, statement);
                }
            },
        }
    }
}

fn varDecl(
    gz: *GenZir,
    scope: *Scope,
    node: ast.Node.Index,
    block_arena: *Allocator,
    var_decl: ast.full.VarDecl,
) InnerError!*Scope {
    const astgen = gz.astgen;
    if (var_decl.comptime_token) |comptime_token| {
        return astgen.failTok(comptime_token, "TODO implement comptime locals", .{});
    }
    if (var_decl.ast.align_node != 0) {
        return astgen.failNode(var_decl.ast.align_node, "TODO implement alignment on locals", .{});
    }
    const gpa = astgen.gpa;
    const tree = &astgen.file.tree;
    const token_tags = tree.tokens.items(.tag);

    const name_token = var_decl.ast.mut_token + 1;
    const ident_name = try astgen.identifierTokenString(name_token);

    // Local variables shadowing detection, including function parameters.
    {
        var s = scope;
        while (true) switch (s.tag) {
            .local_val => {
                const local_val = s.cast(Scope.LocalVal).?;
                if (mem.eql(u8, local_val.name, ident_name)) {
                    return astgen.failTokNotes(name_token, "redefinition of '{s}'", .{
                        ident_name,
                    }, &[_]u32{
                        try astgen.errNoteTok(
                            local_val.token_src,
                            "previous definition is here",
                            .{},
                        ),
                    });
                }
                s = local_val.parent;
            },
            .local_ptr => {
                const local_ptr = s.cast(Scope.LocalPtr).?;
                if (mem.eql(u8, local_ptr.name, ident_name)) {
                    return astgen.failTokNotes(name_token, "redefinition of '{s}'", .{
                        ident_name,
                    }, &[_]u32{
                        try astgen.errNoteTok(
                            local_ptr.token_src,
                            "previous definition is here",
                            .{},
                        ),
                    });
                }
                s = local_ptr.parent;
            },
            .gen_zir => s = s.cast(GenZir).?.parent,
            .file => break,
            else => unreachable,
        };
    }

    if (var_decl.ast.init_node == 0) {
        return astgen.failNode(node, "variables must be initialized", .{});
    }

    switch (token_tags[var_decl.ast.mut_token]) {
        .keyword_const => {
            // Depending on the type of AST the initialization expression is, we may need an lvalue
            // or an rvalue as a result location. If it is an rvalue, we can use the instruction as
            // the variable, no memory location needed.
            if (!nodeMayNeedMemoryLocation(tree, var_decl.ast.init_node)) {
                const result_loc: ResultLoc = if (var_decl.ast.type_node != 0) .{
                    .ty = try typeExpr(gz, scope, var_decl.ast.type_node),
                } else .none;
                const init_inst = try expr(gz, scope, result_loc, var_decl.ast.init_node);
                const sub_scope = try block_arena.create(Scope.LocalVal);
                sub_scope.* = .{
                    .parent = scope,
                    .gen_zir = gz,
                    .name = ident_name,
                    .inst = init_inst,
                    .token_src = name_token,
                };
                return &sub_scope.base;
            }

            // Detect whether the initialization expression actually uses the
            // result location pointer.
            var init_scope: GenZir = .{
                .parent = scope,
                .decl_node_index = gz.decl_node_index,
                .force_comptime = gz.force_comptime,
                .astgen = astgen,
            };
            defer init_scope.instructions.deinit(gpa);

            var resolve_inferred_alloc: Zir.Inst.Ref = .none;
            var opt_type_inst: Zir.Inst.Ref = .none;
            if (var_decl.ast.type_node != 0) {
                const type_inst = try typeExpr(gz, &init_scope.base, var_decl.ast.type_node);
                opt_type_inst = type_inst;
                init_scope.rl_ptr = try init_scope.addUnNode(.alloc, type_inst, node);
                init_scope.rl_ty_inst = type_inst;
            } else {
                const alloc = try init_scope.addNode(.alloc_inferred, node);
                resolve_inferred_alloc = alloc;
                init_scope.rl_ptr = alloc;
            }
            const init_result_loc: ResultLoc = .{ .block_ptr = &init_scope };
            const init_inst = try expr(&init_scope, &init_scope.base, init_result_loc, var_decl.ast.init_node);
            const zir_tags = astgen.instructions.items(.tag);
            const zir_datas = astgen.instructions.items(.data);

            const parent_zir = &gz.instructions;
            if (init_scope.rvalue_rl_count == 1) {
                // Result location pointer not used. We don't need an alloc for this
                // const local, and type inference becomes trivial.
                // Move the init_scope instructions into the parent scope, eliding
                // the alloc instruction and the store_to_block_ptr instruction.
                try parent_zir.ensureUnusedCapacity(gpa, init_scope.instructions.items.len);
                for (init_scope.instructions.items) |src_inst| {
                    if (gz.indexToRef(src_inst) == init_scope.rl_ptr) continue;
                    if (zir_tags[src_inst] == .store_to_block_ptr) {
                        if (zir_datas[src_inst].bin.lhs == init_scope.rl_ptr) continue;
                    }
                    parent_zir.appendAssumeCapacity(src_inst);
                }

                const sub_scope = try block_arena.create(Scope.LocalVal);
                sub_scope.* = .{
                    .parent = scope,
                    .gen_zir = gz,
                    .name = ident_name,
                    .inst = init_inst,
                    .token_src = name_token,
                };
                return &sub_scope.base;
            }
            // The initialization expression took advantage of the result location
            // of the const local. In this case we will create an alloc and a LocalPtr for it.
            // Move the init_scope instructions into the parent scope, swapping
            // store_to_block_ptr for store_to_inferred_ptr.
            const expected_len = parent_zir.items.len + init_scope.instructions.items.len;
            try parent_zir.ensureCapacity(gpa, expected_len);
            for (init_scope.instructions.items) |src_inst| {
                if (zir_tags[src_inst] == .store_to_block_ptr) {
                    if (zir_datas[src_inst].bin.lhs == init_scope.rl_ptr) {
                        zir_tags[src_inst] = .store_to_inferred_ptr;
                    }
                }
                parent_zir.appendAssumeCapacity(src_inst);
            }
            assert(parent_zir.items.len == expected_len);
            if (resolve_inferred_alloc != .none) {
                _ = try gz.addUnNode(.resolve_inferred_alloc, resolve_inferred_alloc, node);
            }
            const sub_scope = try block_arena.create(Scope.LocalPtr);
            sub_scope.* = .{
                .parent = scope,
                .gen_zir = gz,
                .name = ident_name,
                .ptr = init_scope.rl_ptr,
                .token_src = name_token,
            };
            return &sub_scope.base;
        },
        .keyword_var => {
            var resolve_inferred_alloc: Zir.Inst.Ref = .none;
            const var_data: struct {
                result_loc: ResultLoc,
                alloc: Zir.Inst.Ref,
            } = if (var_decl.ast.type_node != 0) a: {
                const type_inst = try typeExpr(gz, scope, var_decl.ast.type_node);

                const alloc = try gz.addUnNode(.alloc_mut, type_inst, node);
                break :a .{ .alloc = alloc, .result_loc = .{ .ptr = alloc } };
            } else a: {
                const alloc = try gz.addNode(.alloc_inferred_mut, node);
                resolve_inferred_alloc = alloc;
                break :a .{ .alloc = alloc, .result_loc = .{ .inferred_ptr = alloc } };
            };
            const init_inst = try expr(gz, scope, var_data.result_loc, var_decl.ast.init_node);
            if (resolve_inferred_alloc != .none) {
                _ = try gz.addUnNode(.resolve_inferred_alloc, resolve_inferred_alloc, node);
            }
            const sub_scope = try block_arena.create(Scope.LocalPtr);
            sub_scope.* = .{
                .parent = scope,
                .gen_zir = gz,
                .name = ident_name,
                .ptr = var_data.alloc,
                .token_src = name_token,
            };
            return &sub_scope.base;
        },
        else => unreachable,
    }
}

fn assign(gz: *GenZir, scope: *Scope, infix_node: ast.Node.Index) InnerError!void {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const node_tags = tree.nodes.items(.tag);

    const lhs = node_datas[infix_node].lhs;
    const rhs = node_datas[infix_node].rhs;
    if (node_tags[lhs] == .identifier) {
        // This intentionally does not support `@"_"` syntax.
        const ident_name = tree.tokenSlice(main_tokens[lhs]);
        if (mem.eql(u8, ident_name, "_")) {
            _ = try expr(gz, scope, .discard, rhs);
            return;
        }
    }
    const lvalue = try lvalExpr(gz, scope, lhs);
    _ = try expr(gz, scope, .{ .ptr = lvalue }, rhs);
}

fn assignOp(
    gz: *GenZir,
    scope: *Scope,
    infix_node: ast.Node.Index,
    op_inst_tag: Zir.Inst.Tag,
) InnerError!void {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);

    const lhs_ptr = try lvalExpr(gz, scope, node_datas[infix_node].lhs);
    const lhs = try gz.addUnNode(.load, lhs_ptr, infix_node);
    const lhs_type = try gz.addUnNode(.typeof, lhs, infix_node);
    const rhs = try expr(gz, scope, .{ .ty = lhs_type }, node_datas[infix_node].rhs);

    const result = try gz.addPlNode(op_inst_tag, infix_node, Zir.Inst.Bin{
        .lhs = lhs,
        .rhs = rhs,
    });
    _ = try gz.addBin(.store, lhs_ptr, result);
}

fn boolNot(gz: *GenZir, scope: *Scope, rl: ResultLoc, node: ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);

    const operand = try expr(gz, scope, .{ .ty = .bool_type }, node_datas[node].lhs);
    const result = try gz.addUnNode(.bool_not, operand, node);
    return rvalue(gz, scope, rl, result, node);
}

fn bitNot(gz: *GenZir, scope: *Scope, rl: ResultLoc, node: ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);

    const operand = try expr(gz, scope, .none, node_datas[node].lhs);
    const result = try gz.addUnNode(.bit_not, operand, node);
    return rvalue(gz, scope, rl, result, node);
}

fn negation(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);

    const operand = try expr(gz, scope, .none, node_datas[node].lhs);
    const result = try gz.addUnNode(tag, operand, node);
    return rvalue(gz, scope, rl, result, node);
}

fn ptrType(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    ptr_info: ast.full.PtrType,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;

    const elem_type = try typeExpr(gz, scope, ptr_info.ast.child_type);

    const simple = ptr_info.ast.align_node == 0 and
        ptr_info.ast.sentinel == 0 and
        ptr_info.ast.bit_range_start == 0;

    if (simple) {
        const result = try gz.add(.{ .tag = .ptr_type_simple, .data = .{
            .ptr_type_simple = .{
                .is_allowzero = ptr_info.allowzero_token != null,
                .is_mutable = ptr_info.const_token == null,
                .is_volatile = ptr_info.volatile_token != null,
                .size = ptr_info.size,
                .elem_type = elem_type,
            },
        } });
        return rvalue(gz, scope, rl, result, node);
    }

    var sentinel_ref: Zir.Inst.Ref = .none;
    var align_ref: Zir.Inst.Ref = .none;
    var bit_start_ref: Zir.Inst.Ref = .none;
    var bit_end_ref: Zir.Inst.Ref = .none;
    var trailing_count: u32 = 0;

    if (ptr_info.ast.sentinel != 0) {
        sentinel_ref = try expr(gz, scope, .{ .ty = elem_type }, ptr_info.ast.sentinel);
        trailing_count += 1;
    }
    if (ptr_info.ast.align_node != 0) {
        align_ref = try expr(gz, scope, .none, ptr_info.ast.align_node);
        trailing_count += 1;
    }
    if (ptr_info.ast.bit_range_start != 0) {
        assert(ptr_info.ast.bit_range_end != 0);
        bit_start_ref = try expr(gz, scope, .none, ptr_info.ast.bit_range_start);
        bit_end_ref = try expr(gz, scope, .none, ptr_info.ast.bit_range_end);
        trailing_count += 2;
    }

    const gpa = gz.astgen.gpa;
    try gz.instructions.ensureCapacity(gpa, gz.instructions.items.len + 1);
    try gz.astgen.instructions.ensureCapacity(gpa, gz.astgen.instructions.len + 1);
    try gz.astgen.extra.ensureCapacity(gpa, gz.astgen.extra.items.len +
        @typeInfo(Zir.Inst.PtrType).Struct.fields.len + trailing_count);

    const payload_index = gz.astgen.addExtraAssumeCapacity(Zir.Inst.PtrType{ .elem_type = elem_type });
    if (sentinel_ref != .none) {
        gz.astgen.extra.appendAssumeCapacity(@enumToInt(sentinel_ref));
    }
    if (align_ref != .none) {
        gz.astgen.extra.appendAssumeCapacity(@enumToInt(align_ref));
    }
    if (bit_start_ref != .none) {
        gz.astgen.extra.appendAssumeCapacity(@enumToInt(bit_start_ref));
        gz.astgen.extra.appendAssumeCapacity(@enumToInt(bit_end_ref));
    }

    const new_index = @intCast(Zir.Inst.Index, gz.astgen.instructions.len);
    const result = gz.indexToRef(new_index);
    gz.astgen.instructions.appendAssumeCapacity(.{ .tag = .ptr_type, .data = .{
        .ptr_type = .{
            .flags = .{
                .is_allowzero = ptr_info.allowzero_token != null,
                .is_mutable = ptr_info.const_token == null,
                .is_volatile = ptr_info.volatile_token != null,
                .has_sentinel = sentinel_ref != .none,
                .has_align = align_ref != .none,
                .has_bit_range = bit_start_ref != .none,
            },
            .size = ptr_info.size,
            .payload_index = payload_index,
        },
    } });
    gz.instructions.appendAssumeCapacity(new_index);

    return rvalue(gz, scope, rl, result, node);
}

fn arrayType(gz: *GenZir, scope: *Scope, rl: ResultLoc, node: ast.Node.Index) !Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);

    // TODO check for [_]T
    const len = try expr(gz, scope, .{ .ty = .usize_type }, node_datas[node].lhs);
    const elem_type = try typeExpr(gz, scope, node_datas[node].rhs);

    const result = try gz.addBin(.array_type, len, elem_type);
    return rvalue(gz, scope, rl, result, node);
}

fn arrayTypeSentinel(gz: *GenZir, scope: *Scope, rl: ResultLoc, node: ast.Node.Index) !Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);
    const extra = tree.extraData(node_datas[node].rhs, ast.Node.ArrayTypeSentinel);

    // TODO check for [_]T
    const len = try expr(gz, scope, .{ .ty = .usize_type }, node_datas[node].lhs);
    const elem_type = try typeExpr(gz, scope, extra.elem_type);
    const sentinel = try expr(gz, scope, .{ .ty = elem_type }, extra.sentinel);

    const result = try gz.addArrayTypeSentinel(len, elem_type, sentinel);
    return rvalue(gz, scope, rl, result, node);
}

const WipDecls = struct {
    decl_index: usize = 0,
    cur_bit_bag: u32 = 0,
    bit_bag: ArrayListUnmanaged(u32) = .{},
    name_and_value: ArrayListUnmanaged(u32) = .{},

    fn deinit(wip_decls: *WipDecls, gpa: *Allocator) void {
        wip_decls.bit_bag.deinit(gpa);
        wip_decls.name_and_value.deinit(gpa);
    }
};

fn fnDecl(
    astgen: *AstGen,
    gz: *GenZir,
    wip_decls: *WipDecls,
    body_node: ast.Node.Index,
    fn_proto: ast.full.FnProto,
) InnerError!void {
    const gpa = astgen.gpa;
    const tree = &astgen.file.tree;
    const token_tags = tree.tokens.items(.tag);

    const is_pub = fn_proto.visib_token != null;
    const is_export = blk: {
        const maybe_export_token = fn_proto.extern_export_token orelse break :blk false;
        break :blk token_tags[maybe_export_token] == .keyword_export;
    };
    const is_extern = blk: {
        const maybe_extern_token = fn_proto.extern_export_token orelse break :blk false;
        break :blk token_tags[maybe_extern_token] == .keyword_extern;
    };
    if (wip_decls.decl_index % 16 == 0 and wip_decls.decl_index != 0) {
        try wip_decls.bit_bag.append(gpa, wip_decls.cur_bit_bag);
        wip_decls.cur_bit_bag = 0;
    }
    wip_decls.cur_bit_bag = (wip_decls.cur_bit_bag >> 2) |
        (@as(u32, @boolToInt(is_pub)) << 30) |
        (@as(u32, @boolToInt(is_export)) << 31);
    wip_decls.decl_index += 1;

    // The AST params array does not contain anytype and ... parameters.
    // We must iterate to count how many param types to allocate.
    const param_count = blk: {
        var count: usize = 0;
        var it = fn_proto.iterate(tree.*);
        while (it.next()) |param| {
            if (param.anytype_ellipsis3) |some| if (token_tags[some] == .ellipsis3) break;
            count += 1;
        }
        break :blk count;
    };
    const param_types = try gpa.alloc(Zir.Inst.Ref, param_count);
    defer gpa.free(param_types);

    var decl_gz: Scope.GenZir = .{
        .force_comptime = true,
        .decl_node_index = fn_proto.ast.proto_node,
        .parent = &gz.base,
        .astgen = astgen,
        .ref_start_index = @intCast(u32, Zir.Inst.Ref.typed_value_map.len + param_count),
    };
    defer decl_gz.instructions.deinit(gpa);

    var is_var_args = false;
    {
        var param_type_i: usize = 0;
        var it = fn_proto.iterate(tree.*);
        while (it.next()) |param| : (param_type_i += 1) {
            if (param.anytype_ellipsis3) |token| {
                switch (token_tags[token]) {
                    .keyword_anytype => return astgen.failTok(
                        token,
                        "TODO implement anytype parameter",
                        .{},
                    ),
                    .ellipsis3 => {
                        is_var_args = true;
                        break;
                    },
                    else => unreachable,
                }
            }
            const param_type_node = param.type_expr;
            assert(param_type_node != 0);
            param_types[param_type_i] =
                try expr(&decl_gz, &decl_gz.base, .{ .ty = .type_type }, param_type_node);
        }
        assert(param_type_i == param_count);
    }

    const lib_name: u32 = if (fn_proto.lib_name) |lib_name_token| blk: {
        const lib_name_str = try decl_gz.strLitAsString(lib_name_token);
        break :blk lib_name_str.index;
    } else 0;

    if (fn_proto.ast.align_expr != 0) {
        return astgen.failNode(
            fn_proto.ast.align_expr,
            "TODO implement function align expression",
            .{},
        );
    }
    if (fn_proto.ast.section_expr != 0) {
        return astgen.failNode(
            fn_proto.ast.section_expr,
            "TODO implement function section expression",
            .{},
        );
    }

    const maybe_bang = tree.firstToken(fn_proto.ast.return_type) - 1;
    if (token_tags[maybe_bang] == .bang) {
        return astgen.failTok(maybe_bang, "TODO implement inferred error sets", .{});
    }
    const return_type_inst = try AstGen.expr(
        &decl_gz,
        &decl_gz.base,
        .{ .ty = .type_type },
        fn_proto.ast.return_type,
    );

    const cc: Zir.Inst.Ref = if (fn_proto.ast.callconv_expr != 0)
        // TODO instead of enum literal type, this needs to be the
        // std.builtin.CallingConvention enum. We need to implement importing other files
        // and enums in order to fix this.
        try AstGen.expr(
            &decl_gz,
            &decl_gz.base,
            .{ .ty = .enum_literal_type },
            fn_proto.ast.callconv_expr,
        )
    else if (is_extern) // note: https://github.com/ziglang/zig/issues/5269
        try decl_gz.addSmallStr(.enum_literal_small, "C")
    else
        .none;

    const func_inst: Zir.Inst.Ref = if (body_node == 0) func: {
        if (is_extern) {
            return astgen.failNode(fn_proto.ast.fn_token, "non-extern function has no body", .{});
        }

        if (cc != .none or lib_name != 0) {
            const tag: Zir.Inst.Tag = if (is_var_args) .func_extra_var_args else .func_extra;
            break :func try decl_gz.addFuncExtra(tag, .{
                .src_node = fn_proto.ast.proto_node,
                .ret_ty = return_type_inst,
                .param_types = param_types,
                .cc = cc,
                .lib_name = lib_name,
                .body = &[0]Zir.Inst.Index{},
            });
        }

        const tag: Zir.Inst.Tag = if (is_var_args) .func_var_args else .func;
        break :func try decl_gz.addFunc(tag, .{
            .src_node = fn_proto.ast.proto_node,
            .ret_ty = return_type_inst,
            .param_types = param_types,
            .body = &[0]Zir.Inst.Index{},
        });
    } else func: {
        if (is_var_args) {
            return astgen.failNode(fn_proto.ast.fn_token, "non-extern function is variadic", .{});
        }

        var fn_gz: Scope.GenZir = .{
            .force_comptime = false,
            .decl_node_index = fn_proto.ast.proto_node,
            .parent = &decl_gz.base,
            .astgen = astgen,
            .ref_start_index = @intCast(u32, Zir.Inst.Ref.typed_value_map.len + param_count),
        };
        defer fn_gz.instructions.deinit(gpa);

        // Iterate over the parameters. We put the param names as the first N
        // items inside `extra` so that debug info later can refer to the parameter names
        // even while the respective source code is unloaded.
        try astgen.extra.ensureUnusedCapacity(gpa, param_count);

        {
            var params_scope = &fn_gz.base;
            var i: usize = 0;
            var it = fn_proto.iterate(tree.*);
            while (it.next()) |param| : (i += 1) {
                const name_token = param.name_token.?;
                const param_name = try astgen.identifierTokenString(name_token);
                const sub_scope = try astgen.arena.create(Scope.LocalVal);
                sub_scope.* = .{
                    .parent = params_scope,
                    .gen_zir = &fn_gz,
                    .name = param_name,
                    // Implicit const list first, then implicit arg list.
                    .inst = @intToEnum(Zir.Inst.Ref, @intCast(u32, Zir.Inst.Ref.typed_value_map.len + i)),
                    .token_src = name_token,
                };
                params_scope = &sub_scope.base;

                // Additionally put the param name into `string_bytes` and reference it with
                // `extra` so that we have access to the data in codegen, for debug info.
                const str_index = try fn_gz.identAsString(name_token);
                astgen.extra.appendAssumeCapacity(str_index);
            }

            _ = try expr(&fn_gz, params_scope, .none, body_node);
        }

        if (fn_gz.instructions.items.len == 0 or
            !astgen.instructions.items(.tag)[fn_gz.instructions.items.len - 1].isNoReturn())
        {
            // astgen uses result location semantics to coerce return operands.
            // Since we are adding the return instruction here, we must handle the coercion.
            // We do this by using the `ret_coerce` instruction.
            _ = try fn_gz.addUnTok(.ret_coerce, .void_value, tree.lastToken(body_node));
        }

        if (cc != .none or lib_name != 0) {
            const tag: Zir.Inst.Tag = if (is_var_args) .func_extra_var_args else .func_extra;
            break :func try decl_gz.addFuncExtra(tag, .{
                .src_node = fn_proto.ast.proto_node,
                .ret_ty = return_type_inst,
                .param_types = param_types,
                .cc = cc,
                .lib_name = lib_name,
                .body = fn_gz.instructions.items,
            });
        }

        const tag: Zir.Inst.Tag = if (is_var_args) .func_var_args else .func;
        break :func try decl_gz.addFunc(tag, .{
            .src_node = fn_proto.ast.proto_node,
            .ret_ty = return_type_inst,
            .param_types = param_types,
            .body = fn_gz.instructions.items,
        });
    };

    const fn_name_token = fn_proto.name_token orelse {
        return astgen.failTok(fn_proto.ast.fn_token, "missing function name", .{});
    };
    const fn_name_str_index = try decl_gz.identAsString(fn_name_token);

    const block_inst = try gz.addBlock(.block_inline, fn_proto.ast.proto_node);
    _ = try decl_gz.addBreak(.break_inline, block_inst, func_inst);
    try decl_gz.setBlockBody(block_inst);

    try wip_decls.name_and_value.ensureCapacity(gpa, wip_decls.name_and_value.items.len + 2);
    wip_decls.name_and_value.appendAssumeCapacity(fn_name_str_index);
    wip_decls.name_and_value.appendAssumeCapacity(block_inst);
}

fn globalVarDecl(
    astgen: *AstGen,
    gz: *GenZir,
    scope: *Scope,
    wip_decls: *WipDecls,
    node: ast.Node.Index,
    var_decl: ast.full.VarDecl,
) InnerError!void {
    const gpa = astgen.gpa;
    const tree = &astgen.file.tree;
    const token_tags = tree.tokens.items(.tag);

    const is_pub = var_decl.visib_token != null;
    const is_export = blk: {
        const maybe_export_token = var_decl.extern_export_token orelse break :blk false;
        break :blk token_tags[maybe_export_token] == .keyword_export;
    };
    const is_extern = blk: {
        const maybe_extern_token = var_decl.extern_export_token orelse break :blk false;
        break :blk token_tags[maybe_extern_token] == .keyword_extern;
    };
    if (wip_decls.decl_index % 16 == 0 and wip_decls.decl_index != 0) {
        try wip_decls.bit_bag.append(gpa, wip_decls.cur_bit_bag);
        wip_decls.cur_bit_bag = 0;
    }
    wip_decls.cur_bit_bag = (wip_decls.cur_bit_bag >> 2) |
        (@as(u32, @boolToInt(is_pub)) << 30) |
        (@as(u32, @boolToInt(is_export)) << 31);
    wip_decls.decl_index += 1;

    const is_mutable = token_tags[var_decl.ast.mut_token] == .keyword_var;
    const is_threadlocal = if (var_decl.threadlocal_token) |tok| blk: {
        if (!is_mutable) {
            return astgen.failTok(tok, "threadlocal variable cannot be constant", .{});
        }
        break :blk true;
    } else false;

    const lib_name: u32 = if (var_decl.lib_name) |lib_name_token| blk: {
        const lib_name_str = try gz.strLitAsString(lib_name_token);
        break :blk lib_name_str.index;
    } else 0;

    assert(var_decl.comptime_token == null); // handled by parser
    if (var_decl.ast.align_node != 0) {
        return astgen.failNode(var_decl.ast.align_node, "TODO implement alignment on globals", .{});
    }
    if (var_decl.ast.section_node != 0) {
        return astgen.failNode(var_decl.ast.section_node, "TODO linksection on globals", .{});
    }

    const var_inst: Zir.Inst.Index = if (var_decl.ast.init_node != 0) vi: {
        if (is_extern) {
            return astgen.failNode(
                var_decl.ast.init_node,
                "extern variables have no initializers",
                .{},
            );
        }

        var block_scope: GenZir = .{
            .parent = scope,
            .decl_node_index = node,
            .astgen = astgen,
            .force_comptime = true,
        };
        defer block_scope.instructions.deinit(gpa);

        const init_result_loc: AstGen.ResultLoc = if (var_decl.ast.type_node != 0) .{
            .ty = try expr(
                &block_scope,
                &block_scope.base,
                .{ .ty = .type_type },
                var_decl.ast.type_node,
            ),
        } else .none;

        const init_inst = try expr(
            &block_scope,
            &block_scope.base,
            init_result_loc,
            var_decl.ast.init_node,
        );

        const tag: Zir.Inst.Tag = if (is_mutable) .block_inline_var else .block_inline;
        const block_inst = try gz.addBlock(tag, node);
        _ = try block_scope.addBreak(.break_inline, block_inst, init_inst);
        try block_scope.setBlockBody(block_inst);
        break :vi block_inst;
    } else if (!is_extern) {
        return astgen.failNode(node, "variables must be initialized", .{});
    } else if (var_decl.ast.type_node != 0) {
        // Extern variable which has an explicit type.

        const type_inst = try typeExpr(gz, scope, var_decl.ast.type_node);

        return astgen.failNode(node, "TODO AstGen extern global variable", .{});
    } else {
        return astgen.failNode(node, "unable to infer variable type", .{});
    };

    const name_token = var_decl.ast.mut_token + 1;
    const name_str_index = try gz.identAsString(name_token);

    try wip_decls.name_and_value.ensureCapacity(gpa, wip_decls.name_and_value.items.len + 2);
    wip_decls.name_and_value.appendAssumeCapacity(name_str_index);
    wip_decls.name_and_value.appendAssumeCapacity(var_inst);
}

fn comptimeDecl(
    astgen: *AstGen,
    gz: *GenZir,
    scope: *Scope,
    node: ast.Node.Index,
) InnerError!void {
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);
    const block_expr = node_datas[node].lhs;
    // TODO probably we want to put these into a block and store a list of them
    _ = try expr(gz, scope, .none, block_expr);
}

fn usingnamespaceDecl(
    astgen: *AstGen,
    gz: *GenZir,
    scope: *Scope,
    node: ast.Node.Index,
) InnerError!void {
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);

    const type_expr = node_datas[node].lhs;
    const is_pub = blk: {
        const main_tokens = tree.nodes.items(.main_token);
        const token_tags = tree.tokens.items(.tag);
        const main_token = main_tokens[node];
        break :blk (main_token > 0 and token_tags[main_token - 1] == .keyword_pub);
    };
    // TODO probably we want to put these into a block and store a list of them
    const namespace_inst = try expr(gz, scope, .{ .ty = .type_type }, type_expr);
}

fn testDecl(
    astgen: *AstGen,
    gz: *GenZir,
    scope: *Scope,
    node: ast.Node.Index,
) InnerError!void {
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);
    const test_expr = node_datas[node].rhs;

    const test_name: u32 = blk: {
        const main_tokens = tree.nodes.items(.main_token);
        const token_tags = tree.tokens.items(.tag);
        const test_token = main_tokens[node];
        const str_lit_token = test_token + 1;
        if (token_tags[str_lit_token] == .string_literal) {
            break :blk (try gz.strLitAsString(str_lit_token)).index;
        }
        break :blk 0;
    };

    // TODO probably we want to put these into a block and store a list of them
    const block_inst = try expr(gz, scope, .none, test_expr);
}

fn structDeclInner(
    gz: *GenZir,
    scope: *Scope,
    node: ast.Node.Index,
    container_decl: ast.full.ContainerDecl,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    if (container_decl.ast.members.len == 0) {
        return gz.addPlNode(tag, node, Zir.Inst.StructDecl{
            .fields_len = 0,
            .body_len = 0,
            .decls_len = 0,
        });
    }

    const astgen = gz.astgen;
    const gpa = astgen.gpa;
    const tree = &astgen.file.tree;
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);

    // The struct_decl instruction introduces a scope in which the decls of the struct
    // are in scope, so that field types, alignments, and default value expressions
    // can refer to decls within the struct itself.
    var block_scope: GenZir = .{
        .parent = scope,
        .decl_node_index = node,
        .astgen = astgen,
        .force_comptime = true,
    };
    defer block_scope.instructions.deinit(gpa);

    var wip_decls: WipDecls = .{};
    defer wip_decls.deinit(gpa);

    // We don't know which members are fields until we iterate, so cannot do
    // an accurate ensureCapacity yet.
    var fields_data = ArrayListUnmanaged(u32){};
    defer fields_data.deinit(gpa);

    // We only need this if there are greater than 16 fields.
    var bit_bag = ArrayListUnmanaged(u32){};
    defer bit_bag.deinit(gpa);

    var cur_bit_bag: u32 = 0;
    var field_index: usize = 0;
    for (container_decl.ast.members) |member_node| {
        const member = switch (node_tags[member_node]) {
            .container_field_init => tree.containerFieldInit(member_node),
            .container_field_align => tree.containerFieldAlign(member_node),
            .container_field => tree.containerField(member_node),

            .fn_decl => {
                const fn_proto = node_datas[member_node].lhs;
                const body = node_datas[member_node].rhs;
                switch (node_tags[fn_proto]) {
                    .fn_proto_simple => {
                        var params: [1]ast.Node.Index = undefined;
                        try astgen.fnDecl(gz, &wip_decls, body, tree.fnProtoSimple(&params, fn_proto));
                        continue;
                    },
                    .fn_proto_multi => {
                        try astgen.fnDecl(gz, &wip_decls, body, tree.fnProtoMulti(fn_proto));
                        continue;
                    },
                    .fn_proto_one => {
                        var params: [1]ast.Node.Index = undefined;
                        try astgen.fnDecl(gz, &wip_decls, body, tree.fnProtoOne(&params, fn_proto));
                        continue;
                    },
                    .fn_proto => {
                        try astgen.fnDecl(gz, &wip_decls, body, tree.fnProto(fn_proto));
                        continue;
                    },
                    else => unreachable,
                }
            },
            .fn_proto_simple => {
                var params: [1]ast.Node.Index = undefined;
                try astgen.fnDecl(gz, &wip_decls, 0, tree.fnProtoSimple(&params, member_node));
                continue;
            },
            .fn_proto_multi => {
                try astgen.fnDecl(gz, &wip_decls, 0, tree.fnProtoMulti(member_node));
                continue;
            },
            .fn_proto_one => {
                var params: [1]ast.Node.Index = undefined;
                try astgen.fnDecl(gz, &wip_decls, 0, tree.fnProtoOne(&params, member_node));
                continue;
            },
            .fn_proto => {
                try astgen.fnDecl(gz, &wip_decls, 0, tree.fnProto(member_node));
                continue;
            },

            .global_var_decl => {
                try astgen.globalVarDecl(gz, scope, &wip_decls, member_node, tree.globalVarDecl(member_node));
                continue;
            },
            .local_var_decl => {
                try astgen.globalVarDecl(gz, scope, &wip_decls, member_node, tree.localVarDecl(member_node));
                continue;
            },
            .simple_var_decl => {
                try astgen.globalVarDecl(gz, scope, &wip_decls, member_node, tree.simpleVarDecl(member_node));
                continue;
            },
            .aligned_var_decl => {
                try astgen.globalVarDecl(gz, scope, &wip_decls, member_node, tree.alignedVarDecl(member_node));
                continue;
            },

            .@"comptime" => {
                try astgen.comptimeDecl(gz, scope, member_node);
                continue;
            },
            .@"usingnamespace" => {
                try astgen.usingnamespaceDecl(gz, scope, member_node);
                continue;
            },
            .test_decl => {
                try astgen.testDecl(gz, scope, member_node);
                continue;
            },
            else => unreachable,
        };
        if (field_index % 16 == 0 and field_index != 0) {
            try bit_bag.append(gpa, cur_bit_bag);
            cur_bit_bag = 0;
        }
        if (member.comptime_token) |comptime_token| {
            return astgen.failTok(comptime_token, "TODO implement comptime struct fields", .{});
        }
        try fields_data.ensureCapacity(gpa, fields_data.items.len + 4);

        const field_name = try gz.identAsString(member.ast.name_token);
        fields_data.appendAssumeCapacity(field_name);

        const field_type = try typeExpr(&block_scope, &block_scope.base, member.ast.type_expr);
        fields_data.appendAssumeCapacity(@enumToInt(field_type));

        const have_align = member.ast.align_expr != 0;
        const have_value = member.ast.value_expr != 0;
        cur_bit_bag = (cur_bit_bag >> 2) |
            (@as(u32, @boolToInt(have_align)) << 30) |
            (@as(u32, @boolToInt(have_value)) << 31);

        if (have_align) {
            const align_inst = try expr(&block_scope, &block_scope.base, .{ .ty = .u32_type }, member.ast.align_expr);
            fields_data.appendAssumeCapacity(@enumToInt(align_inst));
        }
        if (have_value) {
            const default_inst = try expr(&block_scope, &block_scope.base, .{ .ty = field_type }, member.ast.value_expr);
            fields_data.appendAssumeCapacity(@enumToInt(default_inst));
        }

        field_index += 1;
    }
    if (field_index != 0) {
        const empty_slot_count = 16 - (field_index % 16);
        cur_bit_bag >>= @intCast(u5, empty_slot_count * 2);
    }
    if (wip_decls.decl_index != 0) {
        const empty_slot_count = 16 - (wip_decls.decl_index % 16);
        wip_decls.cur_bit_bag >>= @intCast(u5, empty_slot_count * 2);
    }

    const decl_inst = try gz.addBlock(tag, node);
    try gz.instructions.append(gpa, decl_inst);
    if (block_scope.instructions.items.len != 0) {
        _ = try block_scope.addBreak(.break_inline, decl_inst, .void_value);
    }

    try astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.StructDecl).Struct.fields.len +
        bit_bag.items.len + @boolToInt(field_index != 0) + fields_data.items.len +
        block_scope.instructions.items.len +
        wip_decls.bit_bag.items.len + @boolToInt(wip_decls.decl_index != 0) +
        wip_decls.name_and_value.items.len);
    const zir_datas = astgen.instructions.items(.data);
    zir_datas[decl_inst].pl_node.payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.StructDecl{
        .body_len = @intCast(u32, block_scope.instructions.items.len),
        .fields_len = @intCast(u32, field_index),
        .decls_len = @intCast(u32, wip_decls.decl_index),
    });
    astgen.extra.appendSliceAssumeCapacity(block_scope.instructions.items);

    astgen.extra.appendSliceAssumeCapacity(bit_bag.items); // Likely empty.
    if (field_index != 0) {
        astgen.extra.appendAssumeCapacity(cur_bit_bag);
    }
    astgen.extra.appendSliceAssumeCapacity(fields_data.items);

    astgen.extra.appendSliceAssumeCapacity(wip_decls.bit_bag.items); // Likely empty.
    if (wip_decls.decl_index != 0) {
        astgen.extra.appendAssumeCapacity(wip_decls.cur_bit_bag);
    }
    astgen.extra.appendSliceAssumeCapacity(wip_decls.name_and_value.items);

    return gz.indexToRef(decl_inst);
}

fn containerDecl(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    container_decl: ast.full.ContainerDecl,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const gpa = astgen.gpa;
    const tree = &astgen.file.tree;
    const token_tags = tree.tokens.items(.tag);
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);

    // We must not create any types until Sema. Here the goal is only to generate
    // ZIR for all the field types, alignments, and default value expressions.

    const arg_inst: Zir.Inst.Ref = if (container_decl.ast.arg != 0)
        try comptimeExpr(gz, scope, .{ .ty = .type_type }, container_decl.ast.arg)
    else
        .none;

    switch (token_tags[container_decl.ast.main_token]) {
        .keyword_struct => {
            const tag = if (container_decl.layout_token) |t| switch (token_tags[t]) {
                .keyword_packed => Zir.Inst.Tag.struct_decl_packed,
                .keyword_extern => Zir.Inst.Tag.struct_decl_extern,
                else => unreachable,
            } else Zir.Inst.Tag.struct_decl;

            assert(arg_inst == .none);

            const result = try structDeclInner(gz, scope, node, container_decl, tag);
            return rvalue(gz, scope, rl, result, node);
        },
        .keyword_union => {
            return astgen.failTok(container_decl.ast.main_token, "TODO AstGen for union decl", .{});
        },
        .keyword_enum => {
            if (container_decl.layout_token) |t| {
                return astgen.failTok(t, "enums do not support 'packed' or 'extern'; instead provide an explicit integer tag type", .{});
            }
            // Count total fields as well as how many have explicitly provided tag values.
            const counts = blk: {
                var values: usize = 0;
                var total_fields: usize = 0;
                var decls: usize = 0;
                var nonexhaustive_node: ast.Node.Index = 0;
                for (container_decl.ast.members) |member_node| {
                    const member = switch (node_tags[member_node]) {
                        .container_field_init => tree.containerFieldInit(member_node),
                        .container_field_align => tree.containerFieldAlign(member_node),
                        .container_field => tree.containerField(member_node),
                        else => {
                            decls += 1;
                            continue;
                        },
                    };
                    if (member.comptime_token) |comptime_token| {
                        return astgen.failTok(comptime_token, "enum fields cannot be marked comptime", .{});
                    }
                    if (member.ast.type_expr != 0) {
                        return astgen.failNode(member.ast.type_expr, "enum fields do not have types", .{});
                    }
                    // Alignment expressions in enums are caught by the parser.
                    assert(member.ast.align_expr == 0);

                    const name_token = member.ast.name_token;
                    if (mem.eql(u8, tree.tokenSlice(name_token), "_")) {
                        if (nonexhaustive_node != 0) {
                            return astgen.failNodeNotes(
                                member_node,
                                "redundant non-exhaustive enum mark",
                                .{},
                                &[_]u32{
                                    try astgen.errNoteNode(
                                        nonexhaustive_node,
                                        "other mark here",
                                        .{},
                                    ),
                                },
                            );
                        }
                        nonexhaustive_node = member_node;
                        if (member.ast.value_expr != 0) {
                            return astgen.failNode(member.ast.value_expr, "'_' is used to mark an enum as non-exhaustive and cannot be assigned a value", .{});
                        }
                        continue;
                    }
                    total_fields += 1;
                    if (member.ast.value_expr != 0) {
                        if (arg_inst == .none) {
                            return astgen.failNode(member.ast.value_expr, "value assigned to enum tag with inferred tag type", .{});
                        }
                        values += 1;
                    }
                }
                break :blk .{
                    .total_fields = total_fields,
                    .values = values,
                    .decls = decls,
                    .nonexhaustive_node = nonexhaustive_node,
                };
            };
            if (counts.total_fields == 0) {
                // One can construct an enum with no tags, and it functions the same as `noreturn`. But
                // this is only useful for generic code; when explicitly using `enum {}` syntax, there
                // must be at least one tag.
                return astgen.failNode(node, "enum declarations must have at least one tag", .{});
            }
            if (counts.nonexhaustive_node != 0 and arg_inst == .none) {
                return astgen.failNodeNotes(
                    node,
                    "non-exhaustive enum missing integer tag type",
                    .{},
                    &[_]u32{
                        try astgen.errNoteNode(
                            counts.nonexhaustive_node,
                            "marked non-exhaustive here",
                            .{},
                        ),
                    },
                );
            }
            // In this case we must generate ZIR code for the tag values, similar to
            // how structs are handled above.
            const tag: Zir.Inst.Tag = if (counts.nonexhaustive_node == 0)
                .enum_decl
            else
                .enum_decl_nonexhaustive;

            // The enum_decl instruction introduces a scope in which the decls of the enum
            // are in scope, so that tag values can refer to decls within the enum itself.
            var block_scope: GenZir = .{
                .parent = scope,
                .decl_node_index = node,
                .astgen = astgen,
                .force_comptime = true,
            };
            defer block_scope.instructions.deinit(gpa);

            var wip_decls: WipDecls = .{};
            defer wip_decls.deinit(gpa);

            var fields_data = ArrayListUnmanaged(u32){};
            defer fields_data.deinit(gpa);

            try fields_data.ensureCapacity(gpa, counts.total_fields + counts.values);

            // We only need this if there are greater than 32 fields.
            var bit_bag = ArrayListUnmanaged(u32){};
            defer bit_bag.deinit(gpa);

            var cur_bit_bag: u32 = 0;
            var field_index: usize = 0;
            for (container_decl.ast.members) |member_node| {
                if (member_node == counts.nonexhaustive_node)
                    continue;
                const member = switch (node_tags[member_node]) {
                    .container_field_init => tree.containerFieldInit(member_node),
                    .container_field_align => tree.containerFieldAlign(member_node),
                    .container_field => tree.containerField(member_node),

                    .fn_decl => {
                        const fn_proto = node_datas[member_node].lhs;
                        const body = node_datas[member_node].rhs;
                        switch (node_tags[fn_proto]) {
                            .fn_proto_simple => {
                                var params: [1]ast.Node.Index = undefined;
                                try astgen.fnDecl(gz, &wip_decls, body, tree.fnProtoSimple(&params, fn_proto));
                                continue;
                            },
                            .fn_proto_multi => {
                                try astgen.fnDecl(gz, &wip_decls, body, tree.fnProtoMulti(fn_proto));
                                continue;
                            },
                            .fn_proto_one => {
                                var params: [1]ast.Node.Index = undefined;
                                try astgen.fnDecl(gz, &wip_decls, body, tree.fnProtoOne(&params, fn_proto));
                                continue;
                            },
                            .fn_proto => {
                                try astgen.fnDecl(gz, &wip_decls, body, tree.fnProto(fn_proto));
                                continue;
                            },
                            else => unreachable,
                        }
                    },
                    .fn_proto_simple => {
                        var params: [1]ast.Node.Index = undefined;
                        try astgen.fnDecl(gz, &wip_decls, 0, tree.fnProtoSimple(&params, member_node));
                        continue;
                    },
                    .fn_proto_multi => {
                        try astgen.fnDecl(gz, &wip_decls, 0, tree.fnProtoMulti(member_node));
                        continue;
                    },
                    .fn_proto_one => {
                        var params: [1]ast.Node.Index = undefined;
                        try astgen.fnDecl(gz, &wip_decls, 0, tree.fnProtoOne(&params, member_node));
                        continue;
                    },
                    .fn_proto => {
                        try astgen.fnDecl(gz, &wip_decls, 0, tree.fnProto(member_node));
                        continue;
                    },

                    .global_var_decl => {
                        try astgen.globalVarDecl(gz, scope, &wip_decls, member_node, tree.globalVarDecl(member_node));
                        continue;
                    },
                    .local_var_decl => {
                        try astgen.globalVarDecl(gz, scope, &wip_decls, member_node, tree.localVarDecl(member_node));
                        continue;
                    },
                    .simple_var_decl => {
                        try astgen.globalVarDecl(gz, scope, &wip_decls, member_node, tree.simpleVarDecl(member_node));
                        continue;
                    },
                    .aligned_var_decl => {
                        try astgen.globalVarDecl(gz, scope, &wip_decls, member_node, tree.alignedVarDecl(member_node));
                        continue;
                    },

                    .@"comptime" => {
                        try astgen.comptimeDecl(gz, scope, member_node);
                        continue;
                    },
                    .@"usingnamespace" => {
                        try astgen.usingnamespaceDecl(gz, scope, member_node);
                        continue;
                    },
                    .test_decl => {
                        try astgen.testDecl(gz, scope, member_node);
                        continue;
                    },
                    else => unreachable,
                };
                if (field_index % 32 == 0 and field_index != 0) {
                    try bit_bag.append(gpa, cur_bit_bag);
                    cur_bit_bag = 0;
                }
                assert(member.comptime_token == null);
                assert(member.ast.type_expr == 0);
                assert(member.ast.align_expr == 0);

                const field_name = try gz.identAsString(member.ast.name_token);
                fields_data.appendAssumeCapacity(field_name);

                const have_value = member.ast.value_expr != 0;
                cur_bit_bag = (cur_bit_bag >> 1) |
                    (@as(u32, @boolToInt(have_value)) << 31);

                if (have_value) {
                    const tag_value_inst = try expr(&block_scope, &block_scope.base, .{ .ty = arg_inst }, member.ast.value_expr);
                    fields_data.appendAssumeCapacity(@enumToInt(tag_value_inst));
                }

                field_index += 1;
            }
            {
                const empty_slot_count = 32 - (field_index % 32);
                cur_bit_bag >>= @intCast(u5, empty_slot_count);
            }

            if (wip_decls.decl_index != 0) {
                const empty_slot_count = 16 - (wip_decls.decl_index % 16);
                wip_decls.cur_bit_bag >>= @intCast(u5, empty_slot_count * 2);
            }

            const decl_inst = try gz.addBlock(tag, node);
            try gz.instructions.append(gpa, decl_inst);
            if (block_scope.instructions.items.len != 0) {
                _ = try block_scope.addBreak(.break_inline, decl_inst, .void_value);
            }

            try astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.EnumDecl).Struct.fields.len +
                bit_bag.items.len + 1 + fields_data.items.len +
                block_scope.instructions.items.len +
                wip_decls.bit_bag.items.len + @boolToInt(wip_decls.decl_index != 0) +
                wip_decls.name_and_value.items.len);
            const zir_datas = astgen.instructions.items(.data);
            zir_datas[decl_inst].pl_node.payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.EnumDecl{
                .tag_type = arg_inst,
                .body_len = @intCast(u32, block_scope.instructions.items.len),
                .fields_len = @intCast(u32, field_index),
                .decls_len = @intCast(u32, wip_decls.decl_index),
            });
            astgen.extra.appendSliceAssumeCapacity(block_scope.instructions.items);
            astgen.extra.appendSliceAssumeCapacity(bit_bag.items); // Likely empty.
            astgen.extra.appendAssumeCapacity(cur_bit_bag);
            astgen.extra.appendSliceAssumeCapacity(fields_data.items);

            astgen.extra.appendSliceAssumeCapacity(wip_decls.bit_bag.items); // Likely empty.
            if (wip_decls.decl_index != 0) {
                astgen.extra.appendAssumeCapacity(wip_decls.cur_bit_bag);
            }
            astgen.extra.appendSliceAssumeCapacity(wip_decls.name_and_value.items);

            return rvalue(gz, scope, rl, gz.indexToRef(decl_inst), node);
        },
        .keyword_opaque => {
            const result = try gz.addNode(.opaque_decl, node);
            return rvalue(gz, scope, rl, result, node);
        },
        else => unreachable,
    }
}

fn errorSetDecl(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);

    return astgen.failNode(node, "TODO AstGen errorSetDecl", .{});
}

fn orelseCatchExpr(
    parent_gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    lhs: ast.Node.Index,
    cond_op: Zir.Inst.Tag,
    unwrap_op: Zir.Inst.Tag,
    unwrap_code_op: Zir.Inst.Tag,
    rhs: ast.Node.Index,
    payload_token: ?ast.TokenIndex,
) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;
    const tree = &astgen.file.tree;

    var block_scope: GenZir = .{
        .parent = scope,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = parent_gz.astgen,
        .force_comptime = parent_gz.force_comptime,
        .instructions = .{},
    };
    block_scope.setBreakResultLoc(rl);
    defer block_scope.instructions.deinit(astgen.gpa);

    // This could be a pointer or value depending on the `operand_rl` parameter.
    // We cannot use `block_scope.break_result_loc` because that has the bare
    // type, whereas this expression has the optional type. Later we make
    // up for this fact by calling rvalue on the else branch.
    block_scope.break_count += 1;

    // TODO handle catch
    const operand_rl: ResultLoc = switch (block_scope.break_result_loc) {
        .ref => .ref,
        .discard, .none, .none_or_ref, .block_ptr, .inferred_ptr => .none,
        .ty => |elem_ty| blk: {
            const wrapped_ty = try block_scope.addUnNode(.optional_type, elem_ty, node);
            break :blk .{ .ty = wrapped_ty };
        },
        .ptr => |ptr_ty| blk: {
            const wrapped_ty = try block_scope.addUnNode(.optional_type_from_ptr_elem, ptr_ty, node);
            break :blk .{ .ty = wrapped_ty };
        },
    };
    const operand = try expr(&block_scope, &block_scope.base, operand_rl, lhs);
    const cond = try block_scope.addUnNode(cond_op, operand, node);
    const condbr = try block_scope.addCondBr(.condbr, node);

    const block = try parent_gz.addBlock(.block, node);
    try parent_gz.instructions.append(astgen.gpa, block);
    try block_scope.setBlockBody(block);

    var then_scope: GenZir = .{
        .parent = scope,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = parent_gz.astgen,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(astgen.gpa);

    var err_val_scope: Scope.LocalVal = undefined;
    const then_sub_scope = blk: {
        const payload = payload_token orelse break :blk &then_scope.base;
        if (mem.eql(u8, tree.tokenSlice(payload), "_")) {
            return astgen.failTok(payload, "discard of error capture; omit it instead", .{});
        }
        const err_name = try astgen.identifierTokenString(payload);
        err_val_scope = .{
            .parent = &then_scope.base,
            .gen_zir = &then_scope,
            .name = err_name,
            .inst = try then_scope.addUnNode(unwrap_code_op, operand, node),
            .token_src = payload,
        };
        break :blk &err_val_scope.base;
    };

    block_scope.break_count += 1;
    const then_result = try expr(&then_scope, then_sub_scope, block_scope.break_result_loc, rhs);
    // We hold off on the break instructions as well as copying the then/else
    // instructions into place until we know whether to keep store_to_block_ptr
    // instructions or not.

    var else_scope: GenZir = .{
        .parent = scope,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = parent_gz.astgen,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(astgen.gpa);

    // This could be a pointer or value depending on `unwrap_op`.
    const unwrapped_payload = try else_scope.addUnNode(unwrap_op, operand, node);
    const else_result = switch (rl) {
        .ref => unwrapped_payload,
        else => try rvalue(&else_scope, &else_scope.base, block_scope.break_result_loc, unwrapped_payload, node),
    };

    return finishThenElseBlock(
        parent_gz,
        scope,
        rl,
        node,
        &block_scope,
        &then_scope,
        &else_scope,
        condbr,
        cond,
        node,
        node,
        then_result,
        else_result,
        block,
        block,
        .@"break",
    );
}

fn finishThenElseBlock(
    parent_gz: *GenZir,
    parent_scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    block_scope: *GenZir,
    then_scope: *GenZir,
    else_scope: *GenZir,
    condbr: Zir.Inst.Index,
    cond: Zir.Inst.Ref,
    then_src: ast.Node.Index,
    else_src: ast.Node.Index,
    then_result: Zir.Inst.Ref,
    else_result: Zir.Inst.Ref,
    main_block: Zir.Inst.Index,
    then_break_block: Zir.Inst.Index,
    break_tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    // We now have enough information to decide whether the result instruction should
    // be communicated via result location pointer or break instructions.
    const strat = rl.strategy(block_scope);
    const astgen = block_scope.astgen;
    switch (strat.tag) {
        .break_void => {
            if (!parent_gz.refIsNoReturn(then_result)) {
                _ = try then_scope.addBreak(break_tag, then_break_block, .void_value);
            }
            const elide_else = if (else_result != .none) parent_gz.refIsNoReturn(else_result) else false;
            if (!elide_else) {
                _ = try else_scope.addBreak(break_tag, main_block, .void_value);
            }
            assert(!strat.elide_store_to_block_ptr_instructions);
            try setCondBrPayload(condbr, cond, then_scope, else_scope);
            return parent_gz.indexToRef(main_block);
        },
        .break_operand => {
            if (!parent_gz.refIsNoReturn(then_result)) {
                _ = try then_scope.addBreak(break_tag, then_break_block, then_result);
            }
            if (else_result != .none) {
                if (!parent_gz.refIsNoReturn(else_result)) {
                    _ = try else_scope.addBreak(break_tag, main_block, else_result);
                }
            } else {
                _ = try else_scope.addBreak(break_tag, main_block, .void_value);
            }
            if (strat.elide_store_to_block_ptr_instructions) {
                try setCondBrPayloadElideBlockStorePtr(condbr, cond, then_scope, else_scope);
            } else {
                try setCondBrPayload(condbr, cond, then_scope, else_scope);
            }
            const block_ref = parent_gz.indexToRef(main_block);
            switch (rl) {
                .ref => return block_ref,
                else => return rvalue(parent_gz, parent_scope, rl, block_ref, node),
            }
        },
    }
}

/// Return whether the identifier names of two tokens are equal. Resolves @""
/// tokens without allocating.
/// OK in theory it could do it without allocating. This implementation
/// allocates when the @"" form is used.
fn tokenIdentEql(astgen: *AstGen, token1: ast.TokenIndex, token2: ast.TokenIndex) !bool {
    const ident_name_1 = try astgen.identifierTokenString(token1);
    const ident_name_2 = try astgen.identifierTokenString(token2);
    return mem.eql(u8, ident_name_1, ident_name_2);
}

pub fn fieldAccess(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const node_datas = tree.nodes.items(.data);

    const object_node = node_datas[node].lhs;
    const dot_token = main_tokens[node];
    const field_ident = dot_token + 1;
    const str_index = try gz.identAsString(field_ident);
    switch (rl) {
        .ref => return gz.addPlNode(.field_ptr, node, Zir.Inst.Field{
            .lhs = try expr(gz, scope, .ref, object_node),
            .field_name_start = str_index,
        }),
        else => return rvalue(gz, scope, rl, try gz.addPlNode(.field_val, node, Zir.Inst.Field{
            .lhs = try expr(gz, scope, .none_or_ref, object_node),
            .field_name_start = str_index,
        }), node),
    }
}

fn arrayAccess(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const node_datas = tree.nodes.items(.data);
    switch (rl) {
        .ref => return gz.addBin(
            .elem_ptr,
            try expr(gz, scope, .ref, node_datas[node].lhs),
            try expr(gz, scope, .{ .ty = .usize_type }, node_datas[node].rhs),
        ),
        else => return rvalue(gz, scope, rl, try gz.addBin(
            .elem_val,
            try expr(gz, scope, .none_or_ref, node_datas[node].lhs),
            try expr(gz, scope, .{ .ty = .usize_type }, node_datas[node].rhs),
        ), node),
    }
}

fn simpleBinOp(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    op_inst_tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);

    const result = try gz.addPlNode(op_inst_tag, node, Zir.Inst.Bin{
        .lhs = try expr(gz, scope, .none, node_datas[node].lhs),
        .rhs = try expr(gz, scope, .none, node_datas[node].rhs),
    });
    return rvalue(gz, scope, rl, result, node);
}

fn simpleStrTok(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    ident_token: ast.TokenIndex,
    node: ast.Node.Index,
    op_inst_tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const str_index = try gz.identAsString(ident_token);
    const result = try gz.addStrTok(op_inst_tag, str_index, ident_token);
    return rvalue(gz, scope, rl, result, node);
}

fn boolBinOp(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    zir_tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const node_datas = gz.tree().nodes.items(.data);

    const lhs = try expr(gz, scope, .{ .ty = .bool_type }, node_datas[node].lhs);
    const bool_br = try gz.addBoolBr(zir_tag, lhs);

    var rhs_scope: GenZir = .{
        .parent = scope,
        .decl_node_index = gz.decl_node_index,
        .astgen = gz.astgen,
        .force_comptime = gz.force_comptime,
    };
    defer rhs_scope.instructions.deinit(gz.astgen.gpa);
    const rhs = try expr(&rhs_scope, &rhs_scope.base, .{ .ty = .bool_type }, node_datas[node].rhs);
    _ = try rhs_scope.addBreak(.break_inline, bool_br, rhs);
    try rhs_scope.setBoolBrBody(bool_br);

    const block_ref = gz.indexToRef(bool_br);
    return rvalue(gz, scope, rl, block_ref, node);
}

fn ifExpr(
    parent_gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    if_full: ast.full.If,
) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;
    var block_scope: GenZir = .{
        .parent = scope,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = parent_gz.force_comptime,
        .instructions = .{},
    };
    block_scope.setBreakResultLoc(rl);
    defer block_scope.instructions.deinit(astgen.gpa);

    const cond = c: {
        // TODO https://github.com/ziglang/zig/issues/7929
        if (if_full.error_token) |error_token| {
            return astgen.failTok(error_token, "TODO implement if error union", .{});
        } else if (if_full.payload_token) |payload_token| {
            return astgen.failTok(payload_token, "TODO implement if optional", .{});
        } else {
            break :c try expr(&block_scope, &block_scope.base, .{ .ty = .bool_type }, if_full.ast.cond_expr);
        }
    };

    const condbr = try block_scope.addCondBr(.condbr, node);

    const block = try parent_gz.addBlock(.block, node);
    try parent_gz.instructions.append(astgen.gpa, block);
    try block_scope.setBlockBody(block);

    var then_scope: GenZir = .{
        .parent = scope,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(astgen.gpa);

    // declare payload to the then_scope
    const then_sub_scope = &then_scope.base;

    block_scope.break_count += 1;
    const then_result = try expr(&then_scope, then_sub_scope, block_scope.break_result_loc, if_full.ast.then_expr);
    // We hold off on the break instructions as well as copying the then/else
    // instructions into place until we know whether to keep store_to_block_ptr
    // instructions or not.

    var else_scope: GenZir = .{
        .parent = scope,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(astgen.gpa);

    const else_node = if_full.ast.else_expr;
    const else_info: struct {
        src: ast.Node.Index,
        result: Zir.Inst.Ref,
    } = if (else_node != 0) blk: {
        block_scope.break_count += 1;
        const sub_scope = &else_scope.base;
        break :blk .{
            .src = else_node,
            .result = try expr(&else_scope, sub_scope, block_scope.break_result_loc, else_node),
        };
    } else .{
        .src = if_full.ast.then_expr,
        .result = .none,
    };

    return finishThenElseBlock(
        parent_gz,
        scope,
        rl,
        node,
        &block_scope,
        &then_scope,
        &else_scope,
        condbr,
        cond,
        if_full.ast.then_expr,
        else_info.src,
        then_result,
        else_info.result,
        block,
        block,
        .@"break",
    );
}

fn setCondBrPayload(
    condbr: Zir.Inst.Index,
    cond: Zir.Inst.Ref,
    then_scope: *GenZir,
    else_scope: *GenZir,
) !void {
    const astgen = then_scope.astgen;

    try astgen.extra.ensureCapacity(astgen.gpa, astgen.extra.items.len +
        @typeInfo(Zir.Inst.CondBr).Struct.fields.len +
        then_scope.instructions.items.len + else_scope.instructions.items.len);

    const zir_datas = astgen.instructions.items(.data);
    zir_datas[condbr].pl_node.payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.CondBr{
        .condition = cond,
        .then_body_len = @intCast(u32, then_scope.instructions.items.len),
        .else_body_len = @intCast(u32, else_scope.instructions.items.len),
    });
    astgen.extra.appendSliceAssumeCapacity(then_scope.instructions.items);
    astgen.extra.appendSliceAssumeCapacity(else_scope.instructions.items);
}

/// If `elide_block_store_ptr` is set, expects to find exactly 1 .store_to_block_ptr instruction.
fn setCondBrPayloadElideBlockStorePtr(
    condbr: Zir.Inst.Index,
    cond: Zir.Inst.Ref,
    then_scope: *GenZir,
    else_scope: *GenZir,
) !void {
    const astgen = then_scope.astgen;

    try astgen.extra.ensureCapacity(astgen.gpa, astgen.extra.items.len +
        @typeInfo(Zir.Inst.CondBr).Struct.fields.len +
        then_scope.instructions.items.len + else_scope.instructions.items.len - 2);

    const zir_datas = astgen.instructions.items(.data);
    zir_datas[condbr].pl_node.payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.CondBr{
        .condition = cond,
        .then_body_len = @intCast(u32, then_scope.instructions.items.len - 1),
        .else_body_len = @intCast(u32, else_scope.instructions.items.len - 1),
    });

    const zir_tags = astgen.instructions.items(.tag);
    for ([_]*GenZir{ then_scope, else_scope }) |scope| {
        for (scope.instructions.items) |src_inst| {
            if (zir_tags[src_inst] != .store_to_block_ptr) {
                astgen.extra.appendAssumeCapacity(src_inst);
            }
        }
    }
}

fn whileExpr(
    parent_gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    while_full: ast.full.While,
) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;

    if (while_full.label_token) |label_token| {
        try astgen.checkLabelRedefinition(scope, label_token);
    }

    const is_inline = parent_gz.force_comptime or while_full.inline_token != null;
    const loop_tag: Zir.Inst.Tag = if (is_inline) .block_inline else .loop;
    const loop_block = try parent_gz.addBlock(loop_tag, node);
    try parent_gz.instructions.append(astgen.gpa, loop_block);

    var loop_scope: GenZir = .{
        .parent = scope,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = parent_gz.force_comptime,
        .instructions = .{},
    };
    loop_scope.setBreakResultLoc(rl);
    defer loop_scope.instructions.deinit(astgen.gpa);

    var continue_scope: GenZir = .{
        .parent = &loop_scope.base,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = loop_scope.force_comptime,
        .instructions = .{},
    };
    defer continue_scope.instructions.deinit(astgen.gpa);

    const cond = c: {
        // TODO https://github.com/ziglang/zig/issues/7929
        if (while_full.error_token) |error_token| {
            return astgen.failTok(error_token, "TODO implement while error union", .{});
        } else if (while_full.payload_token) |payload_token| {
            return astgen.failTok(payload_token, "TODO implement while optional", .{});
        } else {
            const bool_type_rl: ResultLoc = .{ .ty = .bool_type };
            break :c try expr(&continue_scope, &continue_scope.base, bool_type_rl, while_full.ast.cond_expr);
        }
    };

    const condbr_tag: Zir.Inst.Tag = if (is_inline) .condbr_inline else .condbr;
    const condbr = try continue_scope.addCondBr(condbr_tag, node);
    const block_tag: Zir.Inst.Tag = if (is_inline) .block_inline else .block;
    const cond_block = try loop_scope.addBlock(block_tag, node);
    try loop_scope.instructions.append(astgen.gpa, cond_block);
    try continue_scope.setBlockBody(cond_block);

    // TODO avoid emitting the continue expr when there
    // are no jumps to it. This happens when the last statement of a while body is noreturn
    // and there are no `continue` statements.
    if (while_full.ast.cont_expr != 0) {
        _ = try expr(&loop_scope, &loop_scope.base, .{ .ty = .void_type }, while_full.ast.cont_expr);
    }
    const repeat_tag: Zir.Inst.Tag = if (is_inline) .repeat_inline else .repeat;
    _ = try loop_scope.addNode(repeat_tag, node);

    try loop_scope.setBlockBody(loop_block);
    loop_scope.break_block = loop_block;
    loop_scope.continue_block = cond_block;
    if (while_full.label_token) |label_token| {
        loop_scope.label = @as(?GenZir.Label, GenZir.Label{
            .token = label_token,
            .block_inst = loop_block,
        });
    }

    var then_scope: GenZir = .{
        .parent = &continue_scope.base,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = continue_scope.force_comptime,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(astgen.gpa);

    const then_sub_scope = &then_scope.base;

    loop_scope.break_count += 1;
    const then_result = try expr(&then_scope, then_sub_scope, loop_scope.break_result_loc, while_full.ast.then_expr);

    var else_scope: GenZir = .{
        .parent = &continue_scope.base,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = continue_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(astgen.gpa);

    const else_node = while_full.ast.else_expr;
    const else_info: struct {
        src: ast.Node.Index,
        result: Zir.Inst.Ref,
    } = if (else_node != 0) blk: {
        loop_scope.break_count += 1;
        const sub_scope = &else_scope.base;
        break :blk .{
            .src = else_node,
            .result = try expr(&else_scope, sub_scope, loop_scope.break_result_loc, else_node),
        };
    } else .{
        .src = while_full.ast.then_expr,
        .result = .none,
    };

    if (loop_scope.label) |some| {
        if (!some.used) {
            return astgen.failTok(some.token, "unused while loop label", .{});
        }
    }
    const break_tag: Zir.Inst.Tag = if (is_inline) .break_inline else .@"break";
    return finishThenElseBlock(
        parent_gz,
        scope,
        rl,
        node,
        &loop_scope,
        &then_scope,
        &else_scope,
        condbr,
        cond,
        while_full.ast.then_expr,
        else_info.src,
        then_result,
        else_info.result,
        loop_block,
        cond_block,
        break_tag,
    );
}

fn forExpr(
    parent_gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    for_full: ast.full.While,
) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;

    if (for_full.label_token) |label_token| {
        try astgen.checkLabelRedefinition(scope, label_token);
    }
    // Set up variables and constants.
    const is_inline = parent_gz.force_comptime or for_full.inline_token != null;
    const tree = &astgen.file.tree;
    const token_tags = tree.tokens.items(.tag);

    const array_ptr = try expr(parent_gz, scope, .ref, for_full.ast.cond_expr);
    const len = try parent_gz.addUnNode(.indexable_ptr_len, array_ptr, for_full.ast.cond_expr);

    const index_ptr = blk: {
        const index_ptr = try parent_gz.addUnNode(.alloc, .usize_type, node);
        // initialize to zero
        _ = try parent_gz.addBin(.store, index_ptr, .zero_usize);
        break :blk index_ptr;
    };

    const loop_tag: Zir.Inst.Tag = if (is_inline) .block_inline else .loop;
    const loop_block = try parent_gz.addBlock(loop_tag, node);
    try parent_gz.instructions.append(astgen.gpa, loop_block);

    var loop_scope: GenZir = .{
        .parent = scope,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = parent_gz.force_comptime,
        .instructions = .{},
    };
    loop_scope.setBreakResultLoc(rl);
    defer loop_scope.instructions.deinit(astgen.gpa);

    var cond_scope: GenZir = .{
        .parent = &loop_scope.base,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = loop_scope.force_comptime,
        .instructions = .{},
    };
    defer cond_scope.instructions.deinit(astgen.gpa);

    // check condition i < array_expr.len
    const index = try cond_scope.addUnNode(.load, index_ptr, for_full.ast.cond_expr);
    const cond = try cond_scope.addPlNode(.cmp_lt, for_full.ast.cond_expr, Zir.Inst.Bin{
        .lhs = index,
        .rhs = len,
    });

    const condbr_tag: Zir.Inst.Tag = if (is_inline) .condbr_inline else .condbr;
    const condbr = try cond_scope.addCondBr(condbr_tag, node);
    const block_tag: Zir.Inst.Tag = if (is_inline) .block_inline else .block;
    const cond_block = try loop_scope.addBlock(block_tag, node);
    try loop_scope.instructions.append(astgen.gpa, cond_block);
    try cond_scope.setBlockBody(cond_block);

    // Increment the index variable.
    const index_2 = try loop_scope.addUnNode(.load, index_ptr, for_full.ast.cond_expr);
    const index_plus_one = try loop_scope.addPlNode(.add, node, Zir.Inst.Bin{
        .lhs = index_2,
        .rhs = .one_usize,
    });
    _ = try loop_scope.addBin(.store, index_ptr, index_plus_one);
    const repeat_tag: Zir.Inst.Tag = if (is_inline) .repeat_inline else .repeat;
    _ = try loop_scope.addNode(repeat_tag, node);

    try loop_scope.setBlockBody(loop_block);
    loop_scope.break_block = loop_block;
    loop_scope.continue_block = cond_block;
    if (for_full.label_token) |label_token| {
        loop_scope.label = @as(?GenZir.Label, GenZir.Label{
            .token = label_token,
            .block_inst = loop_block,
        });
    }

    var then_scope: GenZir = .{
        .parent = &cond_scope.base,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = cond_scope.force_comptime,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(astgen.gpa);

    var index_scope: Scope.LocalPtr = undefined;
    const then_sub_scope = blk: {
        const payload_token = for_full.payload_token.?;
        const ident = if (token_tags[payload_token] == .asterisk)
            payload_token + 1
        else
            payload_token;
        const is_ptr = ident != payload_token;
        const value_name = tree.tokenSlice(ident);
        if (!mem.eql(u8, value_name, "_")) {
            return astgen.failTok(ident, "TODO implement for loop value payload", .{});
        } else if (is_ptr) {
            return astgen.failTok(payload_token, "pointer modifier invalid on discard", .{});
        }

        const index_token = if (token_tags[ident + 1] == .comma)
            ident + 2
        else
            break :blk &then_scope.base;
        if (mem.eql(u8, tree.tokenSlice(index_token), "_")) {
            return astgen.failTok(index_token, "discard of index capture; omit it instead", .{});
        }
        const index_name = try astgen.identifierTokenString(index_token);
        index_scope = .{
            .parent = &then_scope.base,
            .gen_zir = &then_scope,
            .name = index_name,
            .ptr = index_ptr,
            .token_src = index_token,
        };
        break :blk &index_scope.base;
    };

    loop_scope.break_count += 1;
    const then_result = try expr(&then_scope, then_sub_scope, loop_scope.break_result_loc, for_full.ast.then_expr);

    var else_scope: GenZir = .{
        .parent = &cond_scope.base,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = cond_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(astgen.gpa);

    const else_node = for_full.ast.else_expr;
    const else_info: struct {
        src: ast.Node.Index,
        result: Zir.Inst.Ref,
    } = if (else_node != 0) blk: {
        loop_scope.break_count += 1;
        const sub_scope = &else_scope.base;
        break :blk .{
            .src = else_node,
            .result = try expr(&else_scope, sub_scope, loop_scope.break_result_loc, else_node),
        };
    } else .{
        .src = for_full.ast.then_expr,
        .result = .none,
    };

    if (loop_scope.label) |some| {
        if (!some.used) {
            return astgen.failTok(some.token, "unused for loop label", .{});
        }
    }
    const break_tag: Zir.Inst.Tag = if (is_inline) .break_inline else .@"break";
    return finishThenElseBlock(
        parent_gz,
        scope,
        rl,
        node,
        &loop_scope,
        &then_scope,
        &else_scope,
        condbr,
        cond,
        for_full.ast.then_expr,
        else_info.src,
        then_result,
        else_info.result,
        loop_block,
        cond_block,
        break_tag,
    );
}

fn getRangeNode(
    node_tags: []const ast.Node.Tag,
    node_datas: []const ast.Node.Data,
    node: ast.Node.Index,
) ?ast.Node.Index {
    switch (node_tags[node]) {
        .switch_range => return node,
        .grouped_expression => unreachable,
        else => return null,
    }
}

pub const SwitchProngSrc = union(enum) {
    scalar: u32,
    multi: Multi,
    range: Multi,

    pub const Multi = struct {
        prong: u32,
        item: u32,
    };

    pub const RangeExpand = enum { none, first, last };

    /// This function is intended to be called only when it is certain that we need
    /// the LazySrcLoc in order to emit a compile error.
    pub fn resolve(
        prong_src: SwitchProngSrc,
        decl: *Decl,
        switch_node_offset: i32,
        range_expand: RangeExpand,
    ) LazySrcLoc {
        @setCold(true);
        const switch_node = decl.relativeToNodeIndex(switch_node_offset);
        const tree = decl.namespace.file_scope.tree;
        const main_tokens = tree.nodes.items(.main_token);
        const node_datas = tree.nodes.items(.data);
        const node_tags = tree.nodes.items(.tag);
        const extra = tree.extraData(node_datas[switch_node].rhs, ast.Node.SubRange);
        const case_nodes = tree.extra_data[extra.start..extra.end];

        var multi_i: u32 = 0;
        var scalar_i: u32 = 0;
        for (case_nodes) |case_node| {
            const case = switch (node_tags[case_node]) {
                .switch_case_one => tree.switchCaseOne(case_node),
                .switch_case => tree.switchCase(case_node),
                else => unreachable,
            };
            if (case.ast.values.len == 0)
                continue;
            if (case.ast.values.len == 1 and
                node_tags[case.ast.values[0]] == .identifier and
                mem.eql(u8, tree.tokenSlice(main_tokens[case.ast.values[0]]), "_"))
            {
                continue;
            }
            const is_multi = case.ast.values.len != 1 or
                getRangeNode(node_tags, node_datas, case.ast.values[0]) != null;

            switch (prong_src) {
                .scalar => |i| if (!is_multi and i == scalar_i) return LazySrcLoc{
                    .node_offset = decl.nodeIndexToRelative(case.ast.values[0]),
                },
                .multi => |s| if (is_multi and s.prong == multi_i) {
                    var item_i: u32 = 0;
                    for (case.ast.values) |item_node| {
                        if (getRangeNode(node_tags, node_datas, item_node) != null)
                            continue;

                        if (item_i == s.item) return LazySrcLoc{
                            .node_offset = decl.nodeIndexToRelative(item_node),
                        };
                        item_i += 1;
                    } else unreachable;
                },
                .range => |s| if (is_multi and s.prong == multi_i) {
                    var range_i: u32 = 0;
                    for (case.ast.values) |item_node| {
                        const range = getRangeNode(node_tags, node_datas, item_node) orelse continue;

                        if (range_i == s.item) switch (range_expand) {
                            .none => return LazySrcLoc{
                                .node_offset = decl.nodeIndexToRelative(item_node),
                            },
                            .first => return LazySrcLoc{
                                .node_offset = decl.nodeIndexToRelative(node_datas[range].lhs),
                            },
                            .last => return LazySrcLoc{
                                .node_offset = decl.nodeIndexToRelative(node_datas[range].rhs),
                            },
                        };
                        range_i += 1;
                    } else unreachable;
                },
            }
            if (is_multi) {
                multi_i += 1;
            } else {
                scalar_i += 1;
            }
        } else unreachable;
    }
};

fn switchExpr(
    parent_gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    switch_node: ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;
    const gpa = astgen.gpa;
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);
    const operand_node = node_datas[switch_node].lhs;
    const extra = tree.extraData(node_datas[switch_node].rhs, ast.Node.SubRange);
    const case_nodes = tree.extra_data[extra.start..extra.end];

    // We perform two passes over the AST. This first pass is to collect information
    // for the following variables, make note of the special prong AST node index,
    // and bail out with a compile error if there are multiple special prongs present.
    var any_payload_is_ref = false;
    var scalar_cases_len: u32 = 0;
    var multi_cases_len: u32 = 0;
    var special_prong: Zir.SpecialProng = .none;
    var special_node: ast.Node.Index = 0;
    var else_src: ?ast.TokenIndex = null;
    var underscore_src: ?ast.TokenIndex = null;
    for (case_nodes) |case_node| {
        const case = switch (node_tags[case_node]) {
            .switch_case_one => tree.switchCaseOne(case_node),
            .switch_case => tree.switchCase(case_node),
            else => unreachable,
        };
        if (case.payload_token) |payload_token| {
            if (token_tags[payload_token] == .asterisk) {
                any_payload_is_ref = true;
            }
        }
        // Check for else/`_` prong.
        if (case.ast.values.len == 0) {
            const case_src = case.ast.arrow_token - 1;
            if (else_src) |src| {
                return astgen.failTokNotes(
                    case_src,
                    "multiple else prongs in switch expression",
                    .{},
                    &[_]u32{
                        try astgen.errNoteTok(
                            src,
                            "previous else prong is here",
                            .{},
                        ),
                    },
                );
            } else if (underscore_src) |some_underscore| {
                return astgen.failNodeNotes(
                    switch_node,
                    "else and '_' prong in switch expression",
                    .{},
                    &[_]u32{
                        try astgen.errNoteTok(
                            case_src,
                            "else prong is here",
                            .{},
                        ),
                        try astgen.errNoteTok(
                            some_underscore,
                            "'_' prong is here",
                            .{},
                        ),
                    },
                );
            }
            special_node = case_node;
            special_prong = .@"else";
            else_src = case_src;
            continue;
        } else if (case.ast.values.len == 1 and
            node_tags[case.ast.values[0]] == .identifier and
            mem.eql(u8, tree.tokenSlice(main_tokens[case.ast.values[0]]), "_"))
        {
            const case_src = case.ast.arrow_token - 1;
            if (underscore_src) |src| {
                return astgen.failTokNotes(
                    case_src,
                    "multiple '_' prongs in switch expression",
                    .{},
                    &[_]u32{
                        try astgen.errNoteTok(
                            src,
                            "previous '_' prong is here",
                            .{},
                        ),
                    },
                );
            } else if (else_src) |some_else| {
                return astgen.failNodeNotes(
                    switch_node,
                    "else and '_' prong in switch expression",
                    .{},
                    &[_]u32{
                        try astgen.errNoteTok(
                            some_else,
                            "else prong is here",
                            .{},
                        ),
                        try astgen.errNoteTok(
                            case_src,
                            "'_' prong is here",
                            .{},
                        ),
                    },
                );
            }
            special_node = case_node;
            special_prong = .under;
            underscore_src = case_src;
            continue;
        }

        if (case.ast.values.len == 1 and
            getRangeNode(node_tags, node_datas, case.ast.values[0]) == null)
        {
            scalar_cases_len += 1;
        } else {
            multi_cases_len += 1;
        }
    }

    const operand_rl: ResultLoc = if (any_payload_is_ref) .ref else .none;
    const operand = try expr(parent_gz, scope, operand_rl, operand_node);
    // We need the type of the operand to use as the result location for all the prong items.
    const typeof_tag: Zir.Inst.Tag = if (any_payload_is_ref) .typeof_elem else .typeof;
    const operand_ty_inst = try parent_gz.addUnNode(typeof_tag, operand, operand_node);
    const item_rl: ResultLoc = .{ .ty = operand_ty_inst };

    // Contains the data that goes into the `extra` array for the SwitchBlock/SwitchBlockMulti.
    // This is the header as well as the optional else prong body, as well as all the
    // scalar cases.
    // At the end we will memcpy this into place.
    var scalar_cases_payload = ArrayListUnmanaged(u32){};
    defer scalar_cases_payload.deinit(gpa);
    // Same deal, but this is only the `extra` data for the multi cases.
    var multi_cases_payload = ArrayListUnmanaged(u32){};
    defer multi_cases_payload.deinit(gpa);

    var block_scope: GenZir = .{
        .parent = scope,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = parent_gz.force_comptime,
        .instructions = .{},
    };
    block_scope.setBreakResultLoc(rl);
    defer block_scope.instructions.deinit(gpa);

    // This gets added to the parent block later, after the item expressions.
    const switch_block = try parent_gz.addBlock(undefined, switch_node);

    // We re-use this same scope for all cases, including the special prong, if any.
    var case_scope: GenZir = .{
        .parent = &block_scope.base,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = parent_gz.force_comptime,
        .instructions = .{},
    };
    defer case_scope.instructions.deinit(gpa);

    // Do the else/`_` first because it goes first in the payload.
    var capture_val_scope: Scope.LocalVal = undefined;
    if (special_node != 0) {
        const case = switch (node_tags[special_node]) {
            .switch_case_one => tree.switchCaseOne(special_node),
            .switch_case => tree.switchCase(special_node),
            else => unreachable,
        };
        const sub_scope = blk: {
            const payload_token = case.payload_token orelse break :blk &case_scope.base;
            const ident = if (token_tags[payload_token] == .asterisk)
                payload_token + 1
            else
                payload_token;
            const is_ptr = ident != payload_token;
            if (mem.eql(u8, tree.tokenSlice(ident), "_")) {
                if (is_ptr) {
                    return astgen.failTok(payload_token, "pointer modifier invalid on discard", .{});
                }
                break :blk &case_scope.base;
            }
            const capture_tag: Zir.Inst.Tag = if (is_ptr)
                .switch_capture_else_ref
            else
                .switch_capture_else;
            const capture = try case_scope.add(.{
                .tag = capture_tag,
                .data = .{ .switch_capture = .{
                    .switch_inst = switch_block,
                    .prong_index = undefined,
                } },
            });
            const capture_name = try astgen.identifierTokenString(payload_token);
            capture_val_scope = .{
                .parent = &case_scope.base,
                .gen_zir = &case_scope,
                .name = capture_name,
                .inst = capture,
                .token_src = payload_token,
            };
            break :blk &capture_val_scope.base;
        };
        const case_result = try expr(&case_scope, sub_scope, block_scope.break_result_loc, case.ast.target_expr);
        if (!parent_gz.refIsNoReturn(case_result)) {
            block_scope.break_count += 1;
            _ = try case_scope.addBreak(.@"break", switch_block, case_result);
        }
        // Documentation for this: `Zir.Inst.SwitchBlock` and `Zir.Inst.SwitchBlockMulti`.
        try scalar_cases_payload.ensureCapacity(gpa, scalar_cases_payload.items.len +
            3 + // operand, scalar_cases_len, else body len
            @boolToInt(multi_cases_len != 0) +
            case_scope.instructions.items.len);
        scalar_cases_payload.appendAssumeCapacity(@enumToInt(operand));
        scalar_cases_payload.appendAssumeCapacity(scalar_cases_len);
        if (multi_cases_len != 0) {
            scalar_cases_payload.appendAssumeCapacity(multi_cases_len);
        }
        scalar_cases_payload.appendAssumeCapacity(@intCast(u32, case_scope.instructions.items.len));
        scalar_cases_payload.appendSliceAssumeCapacity(case_scope.instructions.items);
    } else {
        // Documentation for this: `Zir.Inst.SwitchBlock` and `Zir.Inst.SwitchBlockMulti`.
        try scalar_cases_payload.ensureCapacity(gpa, scalar_cases_payload.items.len +
            2 + // operand, scalar_cases_len
            @boolToInt(multi_cases_len != 0));
        scalar_cases_payload.appendAssumeCapacity(@enumToInt(operand));
        scalar_cases_payload.appendAssumeCapacity(scalar_cases_len);
        if (multi_cases_len != 0) {
            scalar_cases_payload.appendAssumeCapacity(multi_cases_len);
        }
    }

    // In this pass we generate all the item and prong expressions except the special case.
    var multi_case_index: u32 = 0;
    var scalar_case_index: u32 = 0;
    for (case_nodes) |case_node| {
        if (case_node == special_node)
            continue;
        const case = switch (node_tags[case_node]) {
            .switch_case_one => tree.switchCaseOne(case_node),
            .switch_case => tree.switchCase(case_node),
            else => unreachable,
        };

        // Reset the scope.
        case_scope.instructions.shrinkRetainingCapacity(0);

        const is_multi_case = case.ast.values.len != 1 or
            getRangeNode(node_tags, node_datas, case.ast.values[0]) != null;

        const sub_scope = blk: {
            const payload_token = case.payload_token orelse break :blk &case_scope.base;
            const ident = if (token_tags[payload_token] == .asterisk)
                payload_token + 1
            else
                payload_token;
            const is_ptr = ident != payload_token;
            if (mem.eql(u8, tree.tokenSlice(ident), "_")) {
                if (is_ptr) {
                    return astgen.failTok(payload_token, "pointer modifier invalid on discard", .{});
                }
                break :blk &case_scope.base;
            }
            const is_multi_case_bits: u2 = @boolToInt(is_multi_case);
            const is_ptr_bits: u2 = @boolToInt(is_ptr);
            const capture_tag: Zir.Inst.Tag = switch ((is_multi_case_bits << 1) | is_ptr_bits) {
                0b00 => .switch_capture,
                0b01 => .switch_capture_ref,
                0b10 => .switch_capture_multi,
                0b11 => .switch_capture_multi_ref,
            };
            const capture_index = if (is_multi_case) ci: {
                multi_case_index += 1;
                break :ci multi_case_index - 1;
            } else ci: {
                scalar_case_index += 1;
                break :ci scalar_case_index - 1;
            };
            const capture = try case_scope.add(.{
                .tag = capture_tag,
                .data = .{ .switch_capture = .{
                    .switch_inst = switch_block,
                    .prong_index = capture_index,
                } },
            });
            const capture_name = try astgen.identifierTokenString(payload_token);
            capture_val_scope = .{
                .parent = &case_scope.base,
                .gen_zir = &case_scope,
                .name = capture_name,
                .inst = capture,
                .token_src = payload_token,
            };
            break :blk &capture_val_scope.base;
        };

        if (is_multi_case) {
            // items_len, ranges_len, body_len
            const header_index = multi_cases_payload.items.len;
            try multi_cases_payload.resize(gpa, multi_cases_payload.items.len + 3);

            // items
            var items_len: u32 = 0;
            for (case.ast.values) |item_node| {
                if (getRangeNode(node_tags, node_datas, item_node) != null) continue;
                items_len += 1;

                const item_inst = try comptimeExpr(parent_gz, scope, item_rl, item_node);
                try multi_cases_payload.append(gpa, @enumToInt(item_inst));
            }

            // ranges
            var ranges_len: u32 = 0;
            for (case.ast.values) |item_node| {
                const range = getRangeNode(node_tags, node_datas, item_node) orelse continue;
                ranges_len += 1;

                const first = try comptimeExpr(parent_gz, scope, item_rl, node_datas[range].lhs);
                const last = try comptimeExpr(parent_gz, scope, item_rl, node_datas[range].rhs);
                try multi_cases_payload.appendSlice(gpa, &[_]u32{
                    @enumToInt(first), @enumToInt(last),
                });
            }

            const case_result = try expr(&case_scope, sub_scope, block_scope.break_result_loc, case.ast.target_expr);
            if (!parent_gz.refIsNoReturn(case_result)) {
                block_scope.break_count += 1;
                _ = try case_scope.addBreak(.@"break", switch_block, case_result);
            }

            multi_cases_payload.items[header_index + 0] = items_len;
            multi_cases_payload.items[header_index + 1] = ranges_len;
            multi_cases_payload.items[header_index + 2] = @intCast(u32, case_scope.instructions.items.len);
            try multi_cases_payload.appendSlice(gpa, case_scope.instructions.items);
        } else {
            const item_node = case.ast.values[0];
            const item_inst = try comptimeExpr(parent_gz, scope, item_rl, item_node);
            const case_result = try expr(&case_scope, sub_scope, block_scope.break_result_loc, case.ast.target_expr);
            if (!parent_gz.refIsNoReturn(case_result)) {
                block_scope.break_count += 1;
                _ = try case_scope.addBreak(.@"break", switch_block, case_result);
            }
            try scalar_cases_payload.ensureCapacity(gpa, scalar_cases_payload.items.len +
                2 + case_scope.instructions.items.len);
            scalar_cases_payload.appendAssumeCapacity(@enumToInt(item_inst));
            scalar_cases_payload.appendAssumeCapacity(@intCast(u32, case_scope.instructions.items.len));
            scalar_cases_payload.appendSliceAssumeCapacity(case_scope.instructions.items);
        }
    }
    // Now that the item expressions are generated we can add this.
    try parent_gz.instructions.append(gpa, switch_block);

    const ref_bit: u4 = @boolToInt(any_payload_is_ref);
    const multi_bit: u4 = @boolToInt(multi_cases_len != 0);
    const special_prong_bits: u4 = @enumToInt(special_prong);
    comptime {
        assert(@enumToInt(Zir.SpecialProng.none) == 0b00);
        assert(@enumToInt(Zir.SpecialProng.@"else") == 0b01);
        assert(@enumToInt(Zir.SpecialProng.under) == 0b10);
    }
    const zir_tags = astgen.instructions.items(.tag);
    zir_tags[switch_block] = switch ((ref_bit << 3) | (special_prong_bits << 1) | multi_bit) {
        0b0_00_0 => .switch_block,
        0b0_00_1 => .switch_block_multi,
        0b0_01_0 => .switch_block_else,
        0b0_01_1 => .switch_block_else_multi,
        0b0_10_0 => .switch_block_under,
        0b0_10_1 => .switch_block_under_multi,
        0b1_00_0 => .switch_block_ref,
        0b1_00_1 => .switch_block_ref_multi,
        0b1_01_0 => .switch_block_ref_else,
        0b1_01_1 => .switch_block_ref_else_multi,
        0b1_10_0 => .switch_block_ref_under,
        0b1_10_1 => .switch_block_ref_under_multi,
        else => unreachable,
    };
    const payload_index = astgen.extra.items.len;
    const zir_datas = astgen.instructions.items(.data);
    zir_datas[switch_block].pl_node.payload_index = @intCast(u32, payload_index);
    try astgen.extra.ensureCapacity(gpa, astgen.extra.items.len +
        scalar_cases_payload.items.len + multi_cases_payload.items.len);
    const strat = rl.strategy(&block_scope);
    switch (strat.tag) {
        .break_operand => {
            // Switch expressions return `true` for `nodeMayNeedMemoryLocation` thus
            // `elide_store_to_block_ptr_instructions` will either be true,
            // or all prongs are noreturn.
            if (!strat.elide_store_to_block_ptr_instructions) {
                astgen.extra.appendSliceAssumeCapacity(scalar_cases_payload.items);
                astgen.extra.appendSliceAssumeCapacity(multi_cases_payload.items);
                return parent_gz.indexToRef(switch_block);
            }

            // There will necessarily be a store_to_block_ptr for
            // all prongs, except for prongs that ended with a noreturn instruction.
            // Elide all the `store_to_block_ptr` instructions.

            // The break instructions need to have their operands coerced if the
            // switch's result location is a `ty`. In this case we overwrite the
            // `store_to_block_ptr` instruction with an `as` instruction and repurpose
            // it as the break operand.

            var extra_index: usize = 0;
            extra_index += 2;
            extra_index += @boolToInt(multi_cases_len != 0);
            if (special_prong != .none) special_prong: {
                const body_len_index = extra_index;
                const body_len = scalar_cases_payload.items[extra_index];
                extra_index += 1;
                if (body_len < 2) {
                    extra_index += body_len;
                    astgen.extra.appendSliceAssumeCapacity(scalar_cases_payload.items[0..extra_index]);
                    break :special_prong;
                }
                extra_index += body_len - 2;
                const store_inst = scalar_cases_payload.items[extra_index];
                if (zir_tags[store_inst] != .store_to_block_ptr) {
                    extra_index += 2;
                    astgen.extra.appendSliceAssumeCapacity(scalar_cases_payload.items[0..extra_index]);
                    break :special_prong;
                }
                assert(zir_datas[store_inst].bin.lhs == block_scope.rl_ptr);
                if (block_scope.rl_ty_inst != .none) {
                    extra_index += 1;
                    const break_inst = scalar_cases_payload.items[extra_index];
                    extra_index += 1;
                    astgen.extra.appendSliceAssumeCapacity(scalar_cases_payload.items[0..extra_index]);
                    zir_tags[store_inst] = .as;
                    zir_datas[store_inst].bin = .{
                        .lhs = block_scope.rl_ty_inst,
                        .rhs = zir_datas[break_inst].@"break".operand,
                    };
                    zir_datas[break_inst].@"break".operand = parent_gz.indexToRef(store_inst);
                } else {
                    scalar_cases_payload.items[body_len_index] -= 1;
                    astgen.extra.appendSliceAssumeCapacity(scalar_cases_payload.items[0..extra_index]);
                    extra_index += 1;
                    astgen.extra.appendAssumeCapacity(scalar_cases_payload.items[extra_index]);
                    extra_index += 1;
                }
            } else {
                astgen.extra.appendSliceAssumeCapacity(scalar_cases_payload.items[0..extra_index]);
            }
            var scalar_i: u32 = 0;
            while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
                const start_index = extra_index;
                extra_index += 1;
                const body_len_index = extra_index;
                const body_len = scalar_cases_payload.items[extra_index];
                extra_index += 1;
                if (body_len < 2) {
                    extra_index += body_len;
                    astgen.extra.appendSliceAssumeCapacity(scalar_cases_payload.items[start_index..extra_index]);
                    continue;
                }
                extra_index += body_len - 2;
                const store_inst = scalar_cases_payload.items[extra_index];
                if (zir_tags[store_inst] != .store_to_block_ptr) {
                    extra_index += 2;
                    astgen.extra.appendSliceAssumeCapacity(scalar_cases_payload.items[start_index..extra_index]);
                    continue;
                }
                if (block_scope.rl_ty_inst != .none) {
                    extra_index += 1;
                    const break_inst = scalar_cases_payload.items[extra_index];
                    extra_index += 1;
                    astgen.extra.appendSliceAssumeCapacity(scalar_cases_payload.items[start_index..extra_index]);
                    zir_tags[store_inst] = .as;
                    zir_datas[store_inst].bin = .{
                        .lhs = block_scope.rl_ty_inst,
                        .rhs = zir_datas[break_inst].@"break".operand,
                    };
                    zir_datas[break_inst].@"break".operand = parent_gz.indexToRef(store_inst);
                } else {
                    assert(zir_datas[store_inst].bin.lhs == block_scope.rl_ptr);
                    scalar_cases_payload.items[body_len_index] -= 1;
                    astgen.extra.appendSliceAssumeCapacity(scalar_cases_payload.items[start_index..extra_index]);
                    extra_index += 1;
                    astgen.extra.appendAssumeCapacity(scalar_cases_payload.items[extra_index]);
                    extra_index += 1;
                }
            }
            extra_index = 0;
            var multi_i: u32 = 0;
            while (multi_i < multi_cases_len) : (multi_i += 1) {
                const start_index = extra_index;
                const items_len = multi_cases_payload.items[extra_index];
                extra_index += 1;
                const ranges_len = multi_cases_payload.items[extra_index];
                extra_index += 1;
                const body_len_index = extra_index;
                const body_len = multi_cases_payload.items[extra_index];
                extra_index += 1;
                extra_index += items_len;
                extra_index += 2 * ranges_len;
                if (body_len < 2) {
                    extra_index += body_len;
                    astgen.extra.appendSliceAssumeCapacity(multi_cases_payload.items[start_index..extra_index]);
                    continue;
                }
                extra_index += body_len - 2;
                const store_inst = multi_cases_payload.items[extra_index];
                if (zir_tags[store_inst] != .store_to_block_ptr) {
                    extra_index += 2;
                    astgen.extra.appendSliceAssumeCapacity(multi_cases_payload.items[start_index..extra_index]);
                    continue;
                }
                if (block_scope.rl_ty_inst != .none) {
                    extra_index += 1;
                    const break_inst = multi_cases_payload.items[extra_index];
                    extra_index += 1;
                    astgen.extra.appendSliceAssumeCapacity(multi_cases_payload.items[start_index..extra_index]);
                    zir_tags[store_inst] = .as;
                    zir_datas[store_inst].bin = .{
                        .lhs = block_scope.rl_ty_inst,
                        .rhs = zir_datas[break_inst].@"break".operand,
                    };
                    zir_datas[break_inst].@"break".operand = parent_gz.indexToRef(store_inst);
                } else {
                    assert(zir_datas[store_inst].bin.lhs == block_scope.rl_ptr);
                    multi_cases_payload.items[body_len_index] -= 1;
                    astgen.extra.appendSliceAssumeCapacity(multi_cases_payload.items[start_index..extra_index]);
                    extra_index += 1;
                    astgen.extra.appendAssumeCapacity(multi_cases_payload.items[extra_index]);
                    extra_index += 1;
                }
            }

            const block_ref = parent_gz.indexToRef(switch_block);
            switch (rl) {
                .ref => return block_ref,
                else => return rvalue(parent_gz, scope, rl, block_ref, switch_node),
            }
        },
        .break_void => {
            assert(!strat.elide_store_to_block_ptr_instructions);
            astgen.extra.appendSliceAssumeCapacity(scalar_cases_payload.items);
            astgen.extra.appendSliceAssumeCapacity(multi_cases_payload.items);
            // Modify all the terminating instruction tags to become `break` variants.
            var extra_index: usize = payload_index;
            extra_index += 2;
            extra_index += @boolToInt(multi_cases_len != 0);
            if (special_prong != .none) {
                const body_len = astgen.extra.items[extra_index];
                extra_index += 1;
                const body = astgen.extra.items[extra_index..][0..body_len];
                extra_index += body_len;
                const last = body[body.len - 1];
                if (zir_tags[last] == .@"break" and
                    zir_datas[last].@"break".block_inst == switch_block)
                {
                    zir_datas[last].@"break".operand = .void_value;
                }
            }
            var scalar_i: u32 = 0;
            while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
                extra_index += 1;
                const body_len = astgen.extra.items[extra_index];
                extra_index += 1;
                const body = astgen.extra.items[extra_index..][0..body_len];
                extra_index += body_len;
                const last = body[body.len - 1];
                if (zir_tags[last] == .@"break" and
                    zir_datas[last].@"break".block_inst == switch_block)
                {
                    zir_datas[last].@"break".operand = .void_value;
                }
            }
            var multi_i: u32 = 0;
            while (multi_i < multi_cases_len) : (multi_i += 1) {
                const items_len = astgen.extra.items[extra_index];
                extra_index += 1;
                const ranges_len = astgen.extra.items[extra_index];
                extra_index += 1;
                const body_len = astgen.extra.items[extra_index];
                extra_index += 1;
                extra_index += items_len;
                extra_index += 2 * ranges_len;
                const body = astgen.extra.items[extra_index..][0..body_len];
                extra_index += body_len;
                const last = body[body.len - 1];
                if (zir_tags[last] == .@"break" and
                    zir_datas[last].@"break".block_inst == switch_block)
                {
                    zir_datas[last].@"break".operand = .void_value;
                }
            }

            return parent_gz.indexToRef(switch_block);
        },
    }
}

fn ret(gz: *GenZir, scope: *Scope, node: ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);

    const operand_node = node_datas[node].lhs;
    const operand: Zir.Inst.Ref = if (operand_node != 0) operand: {
        const rl: ResultLoc = if (nodeMayNeedMemoryLocation(tree, operand_node)) .{
            .ptr = try gz.addNode(.ret_ptr, node),
        } else .{
            .ty = try gz.addNode(.ret_type, node),
        };
        break :operand try expr(gz, scope, rl, operand_node);
    } else .void_value;
    _ = try gz.addUnNode(.ret_node, operand, node);
    return Zir.Inst.Ref.unreachable_value;
}

fn identifier(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    ident: ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);

    const ident_token = main_tokens[ident];
    const ident_name = try astgen.identifierTokenString(ident_token);
    if (mem.eql(u8, ident_name, "_")) {
        return astgen.failNode(ident, "TODO implement '_' identifier", .{});
    }

    if (simple_types.get(ident_name)) |zir_const_ref| {
        return rvalue(gz, scope, rl, zir_const_ref, ident);
    }

    if (ident_name.len >= 2) integer: {
        const first_c = ident_name[0];
        if (first_c == 'i' or first_c == 'u') {
            const signedness: std.builtin.Signedness = switch (first_c == 'i') {
                true => .signed,
                false => .unsigned,
            };
            const bit_count = std.fmt.parseInt(u16, ident_name[1..], 10) catch |err| switch (err) {
                error.Overflow => return astgen.failNode(
                    ident,
                    "primitive integer type '{s}' exceeds maximum bit width of 65535",
                    .{ident_name},
                ),
                error.InvalidCharacter => break :integer,
            };
            const result = try gz.add(.{
                .tag = .int_type,
                .data = .{ .int_type = .{
                    .src_node = gz.nodeIndexToRelative(ident),
                    .signedness = signedness,
                    .bit_count = bit_count,
                } },
            });
            return rvalue(gz, scope, rl, result, ident);
        }
    }

    // Local variables, including function parameters.
    {
        var s = scope;
        while (true) switch (s.tag) {
            .local_val => {
                const local_val = s.cast(Scope.LocalVal).?;
                if (mem.eql(u8, local_val.name, ident_name)) {
                    return rvalue(gz, scope, rl, local_val.inst, ident);
                }
                s = local_val.parent;
            },
            .local_ptr => {
                const local_ptr = s.cast(Scope.LocalPtr).?;
                if (mem.eql(u8, local_ptr.name, ident_name)) {
                    switch (rl) {
                        .ref, .none_or_ref => return local_ptr.ptr,
                        else => {
                            const loaded = try gz.addUnNode(.load, local_ptr.ptr, ident);
                            return rvalue(gz, scope, rl, loaded, ident);
                        },
                    }
                }
                s = local_ptr.parent;
            },
            .gen_zir => s = s.cast(GenZir).?.parent,
            else => break,
        };
    }

    // We can't look up Decls until Sema because the same ZIR code is supposed to be
    // used for multiple generic instantiations, and this may refer to a different Decl
    // depending on the scope, determined by the generic instantiation.
    const str_index = try gz.identAsString(ident_token);
    switch (rl) {
        .ref, .none_or_ref => return gz.addStrTok(.decl_ref, str_index, ident_token),
        else => {
            const result = try gz.addStrTok(.decl_val, str_index, ident_token);
            return rvalue(gz, scope, rl, result, ident);
        },
    }
}

fn stringLiteral(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const tree = gz.astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const str_lit_token = main_tokens[node];
    const str = try gz.strLitAsString(str_lit_token);
    const result = try gz.add(.{
        .tag = .str,
        .data = .{ .str = .{
            .start = str.index,
            .len = str.len,
        } },
    });
    return rvalue(gz, scope, rl, result, node);
}

fn multilineStringLiteral(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);

    const start = node_datas[node].lhs;
    const end = node_datas[node].rhs;

    const gpa = gz.astgen.gpa;
    const string_bytes = &gz.astgen.string_bytes;
    const str_index = string_bytes.items.len;

    // First line: do not append a newline.
    var tok_i = start;
    {
        const slice = tree.tokenSlice(tok_i);
        const line_bytes = slice[2 .. slice.len - 1];
        try string_bytes.appendSlice(gpa, line_bytes);
        tok_i += 1;
    }
    // Following lines: each line prepends a newline.
    while (tok_i <= end) : (tok_i += 1) {
        const slice = tree.tokenSlice(tok_i);
        const line_bytes = slice[2 .. slice.len - 1];
        try string_bytes.ensureCapacity(gpa, string_bytes.items.len + line_bytes.len + 1);
        string_bytes.appendAssumeCapacity('\n');
        string_bytes.appendSliceAssumeCapacity(line_bytes);
    }
    const result = try gz.add(.{
        .tag = .str,
        .data = .{ .str = .{
            .start = @intCast(u32, str_index),
            .len = @intCast(u32, string_bytes.items.len - str_index),
        } },
    });
    return rvalue(gz, scope, rl, result, node);
}

fn charLiteral(gz: *GenZir, scope: *Scope, rl: ResultLoc, node: ast.Node.Index) !Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const main_token = main_tokens[node];
    const slice = tree.tokenSlice(main_token);

    var bad_index: usize = undefined;
    const value = std.zig.parseCharLiteral(slice, &bad_index) catch |err| switch (err) {
        error.InvalidCharacter => {
            const bad_byte = slice[bad_index];
            const token_starts = tree.tokens.items(.start);
            return astgen.failOff(
                main_token,
                @intCast(u32, bad_index),
                "invalid character: '{c}'\n",
                .{bad_byte},
            );
        },
    };
    const result = try gz.addInt(value);
    return rvalue(gz, scope, rl, result, node);
}

fn integerLiteral(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const int_token = main_tokens[node];
    const prefixed_bytes = tree.tokenSlice(int_token);
    if (std.fmt.parseInt(u64, prefixed_bytes, 0)) |small_int| {
        const result: Zir.Inst.Ref = switch (small_int) {
            0 => .zero,
            1 => .one,
            else => try gz.addInt(small_int),
        };
        return rvalue(gz, scope, rl, result, node);
    } else |err| {
        return gz.astgen.failNode(node, "TODO implement int literals that don't fit in a u64", .{});
    }
}

fn floatLiteral(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const arena = astgen.arena;
    const tree = &astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);

    const main_token = main_tokens[node];
    const bytes = tree.tokenSlice(main_token);
    if (bytes.len > 2 and bytes[1] == 'x') {
        assert(bytes[0] == '0'); // validated by tokenizer
        return astgen.failTok(main_token, "TODO implement hex floats", .{});
    }
    const float_number = std.fmt.parseFloat(f128, bytes) catch |e| switch (e) {
        error.InvalidCharacter => unreachable, // validated by tokenizer
    };
    // If the value fits into a f32 without losing any precision, store it that way.
    @setFloatMode(.Strict);
    const smaller_float = @floatCast(f32, float_number);
    const bigger_again: f128 = smaller_float;
    if (bigger_again == float_number) {
        const result = try gz.addFloat(smaller_float, node);
        return rvalue(gz, scope, rl, result, node);
    }
    // We need to use 128 bits. Break the float into 4 u32 values so we can
    // put it into the `extra` array.
    const int_bits = @bitCast(u128, float_number);
    const result = try gz.addPlNode(.float128, node, Zir.Inst.Float128{
        .piece0 = @truncate(u32, int_bits),
        .piece1 = @truncate(u32, int_bits >> 32),
        .piece2 = @truncate(u32, int_bits >> 64),
        .piece3 = @truncate(u32, int_bits >> 96),
    });
    return rvalue(gz, scope, rl, result, node);
}

fn asmExpr(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    full: ast.full.Asm,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const arena = astgen.arena;
    const tree = &astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const node_datas = tree.nodes.items(.data);

    const asm_source = try expr(gz, scope, .{ .ty = .const_slice_u8_type }, full.ast.template);

    if (full.outputs.len != 0) {
        // when implementing this be sure to add test coverage for the asm return type
        // not resolving into a type (the node_offset_asm_ret_ty  field of LazySrcLoc)
        return astgen.failTok(full.ast.asm_token, "TODO implement asm with an output", .{});
    }

    const constraints = try arena.alloc(u32, full.inputs.len);
    const args = try arena.alloc(Zir.Inst.Ref, full.inputs.len);

    for (full.inputs) |input, i| {
        const constraint_token = main_tokens[input] + 2;
        const string_bytes = &astgen.string_bytes;
        constraints[i] = @intCast(u32, string_bytes.items.len);
        const token_bytes = tree.tokenSlice(constraint_token);
        try astgen.parseStrLit(constraint_token, string_bytes, token_bytes, 0);
        try string_bytes.append(astgen.gpa, 0);

        args[i] = try expr(gz, scope, .{ .ty = .usize_type }, node_datas[input].lhs);
    }

    const tag: Zir.Inst.Tag = if (full.volatile_token != null) .asm_volatile else .@"asm";
    const result = try gz.addPlNode(tag, node, Zir.Inst.Asm{
        .asm_source = asm_source,
        .return_type = .void_type,
        .output = .none,
        .args_len = @intCast(u32, full.inputs.len),
        .clobbers_len = 0, // TODO implement asm clobbers
    });

    try astgen.extra.ensureCapacity(astgen.gpa, astgen.extra.items.len +
        args.len + constraints.len);
    astgen.appendRefsAssumeCapacity(args);
    astgen.extra.appendSliceAssumeCapacity(constraints);

    return rvalue(gz, scope, rl, result, node);
}

fn as(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    lhs: ast.Node.Index,
    rhs: ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const dest_type = try typeExpr(gz, scope, lhs);
    switch (rl) {
        .none, .none_or_ref, .discard, .ref, .ty => {
            const result = try expr(gz, scope, .{ .ty = dest_type }, rhs);
            return rvalue(gz, scope, rl, result, node);
        },

        .ptr => |result_ptr| {
            return asRlPtr(gz, scope, rl, result_ptr, rhs, dest_type);
        },
        .block_ptr => |block_scope| {
            return asRlPtr(gz, scope, rl, block_scope.rl_ptr, rhs, dest_type);
        },

        .inferred_ptr => |result_alloc| {
            // TODO here we should be able to resolve the inference; we now have a type for the result.
            return gz.astgen.failNode(node, "TODO implement @as with inferred-type result location pointer", .{});
        },
    }
}

fn asRlPtr(
    parent_gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    result_ptr: Zir.Inst.Ref,
    operand_node: ast.Node.Index,
    dest_type: Zir.Inst.Ref,
) InnerError!Zir.Inst.Ref {
    // Detect whether this expr() call goes into rvalue() to store the result into the
    // result location. If it does, elide the coerce_result_ptr instruction
    // as well as the store instruction, instead passing the result as an rvalue.
    const astgen = parent_gz.astgen;

    var as_scope: GenZir = .{
        .parent = scope,
        .decl_node_index = parent_gz.decl_node_index,
        .astgen = astgen,
        .force_comptime = parent_gz.force_comptime,
        .instructions = .{},
    };
    defer as_scope.instructions.deinit(astgen.gpa);

    as_scope.rl_ptr = try as_scope.addBin(.coerce_result_ptr, dest_type, result_ptr);
    const result = try expr(&as_scope, &as_scope.base, .{ .block_ptr = &as_scope }, operand_node);
    const parent_zir = &parent_gz.instructions;
    if (as_scope.rvalue_rl_count == 1) {
        // Busted! This expression didn't actually need a pointer.
        const zir_tags = astgen.instructions.items(.tag);
        const zir_datas = astgen.instructions.items(.data);
        const expected_len = parent_zir.items.len + as_scope.instructions.items.len - 2;
        try parent_zir.ensureCapacity(astgen.gpa, expected_len);
        for (as_scope.instructions.items) |src_inst| {
            if (parent_gz.indexToRef(src_inst) == as_scope.rl_ptr) continue;
            if (zir_tags[src_inst] == .store_to_block_ptr) {
                if (zir_datas[src_inst].bin.lhs == as_scope.rl_ptr) continue;
            }
            parent_zir.appendAssumeCapacity(src_inst);
        }
        assert(parent_zir.items.len == expected_len);
        const casted_result = try parent_gz.addBin(.as, dest_type, result);
        return rvalue(parent_gz, scope, rl, casted_result, operand_node);
    } else {
        try parent_zir.appendSlice(astgen.gpa, as_scope.instructions.items);
        return result;
    }
}

fn bitCast(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    lhs: ast.Node.Index,
    rhs: ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const dest_type = try typeExpr(gz, scope, lhs);
    switch (rl) {
        .none, .discard, .ty => {
            const operand = try expr(gz, scope, .none, rhs);
            const result = try gz.addPlNode(.bitcast, node, Zir.Inst.Bin{
                .lhs = dest_type,
                .rhs = operand,
            });
            return rvalue(gz, scope, rl, result, node);
        },
        .ref, .none_or_ref => unreachable, // `@bitCast` is not allowed as an r-value.
        .ptr => |result_ptr| {
            const casted_result_ptr = try gz.addUnNode(.bitcast_result_ptr, result_ptr, node);
            return expr(gz, scope, .{ .ptr = casted_result_ptr }, rhs);
        },
        .block_ptr => |block_ptr| {
            return astgen.failNode(node, "TODO implement @bitCast with result location inferred peer types", .{});
        },
        .inferred_ptr => |result_alloc| {
            // TODO here we should be able to resolve the inference; we now have a type for the result.
            return astgen.failNode(node, "TODO implement @bitCast with inferred-type result location pointer", .{});
        },
    }
}

fn typeOf(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    params: []const ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    if (params.len < 1) {
        return gz.astgen.failNode(node, "expected at least 1 argument, found 0", .{});
    }
    if (params.len == 1) {
        const result = try gz.addUnNode(.typeof, try expr(gz, scope, .none, params[0]), node);
        return rvalue(gz, scope, rl, result, node);
    }
    const arena = gz.astgen.arena;
    var items = try arena.alloc(Zir.Inst.Ref, params.len);
    for (params) |param, param_i| {
        items[param_i] = try expr(gz, scope, .none, param);
    }

    const result = try gz.addPlNode(.typeof_peer, node, Zir.Inst.MultiOp{
        .operands_len = @intCast(u32, params.len),
    });
    try gz.astgen.appendRefs(items);

    return rvalue(gz, scope, rl, result, node);
}

fn builtinCall(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    params: []const ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = &astgen.file.tree;
    const main_tokens = tree.nodes.items(.main_token);

    const builtin_token = main_tokens[node];
    const builtin_name = tree.tokenSlice(builtin_token);

    // We handle the different builtins manually because they have different semantics depending
    // on the function. For example, `@as` and others participate in result location semantics,
    // and `@cImport` creates a special scope that collects a .c source code text buffer.
    // Also, some builtins have a variable number of parameters.

    const info = BuiltinFn.list.get(builtin_name) orelse {
        return astgen.failNode(node, "invalid builtin function: '{s}'", .{
            builtin_name,
        });
    };
    if (info.param_count) |expected| {
        if (expected != params.len) {
            const s = if (expected == 1) "" else "s";
            return astgen.failNode(node, "expected {d} parameter{s}, found {d}", .{
                expected, s, params.len,
            });
        }
    }

    switch (info.tag) {
        .ptr_to_int => {
            const operand = try expr(gz, scope, .none, params[0]);
            const result = try gz.addUnNode(.ptrtoint, operand, node);
            return rvalue(gz, scope, rl, result, node);
        },
        .float_cast => {
            const dest_type = try typeExpr(gz, scope, params[0]);
            const rhs = try expr(gz, scope, .none, params[1]);
            const result = try gz.addPlNode(.floatcast, node, Zir.Inst.Bin{
                .lhs = dest_type,
                .rhs = rhs,
            });
            return rvalue(gz, scope, rl, result, node);
        },
        .int_cast => {
            const dest_type = try typeExpr(gz, scope, params[0]);
            const rhs = try expr(gz, scope, .none, params[1]);
            const result = try gz.addPlNode(.intcast, node, Zir.Inst.Bin{
                .lhs = dest_type,
                .rhs = rhs,
            });
            return rvalue(gz, scope, rl, result, node);
        },
        .breakpoint => {
            _ = try gz.add(.{
                .tag = .breakpoint,
                .data = .{ .node = gz.nodeIndexToRelative(node) },
            });
            return rvalue(gz, scope, rl, .void_value, node);
        },
        .import => {
            const node_tags = tree.nodes.items(.tag);
            const node_datas = tree.nodes.items(.data);
            const operand_node = params[0];

            if (node_tags[operand_node] != .string_literal) {
                // Spec reference: https://github.com/ziglang/zig/issues/2206
                return astgen.failNode(operand_node, "@import operand must be a string literal", .{});
            }
            const str_lit_token = main_tokens[operand_node];
            const str = try gz.strLitAsString(str_lit_token);
            try astgen.imports.put(astgen.gpa, str.index, {});
            const result = try gz.addStrTok(.import, str.index, str_lit_token);
            return rvalue(gz, scope, rl, result, node);
        },
        .error_to_int => {
            const target = try expr(gz, scope, .none, params[0]);
            const result = try gz.addUnNode(.error_to_int, target, node);
            return rvalue(gz, scope, rl, result, node);
        },
        .int_to_error => {
            const target = try expr(gz, scope, .{ .ty = .u16_type }, params[0]);
            const result = try gz.addUnNode(.int_to_error, target, node);
            return rvalue(gz, scope, rl, result, node);
        },
        .compile_error => {
            const target = try expr(gz, scope, .none, params[0]);
            const result = try gz.addUnNode(.compile_error, target, node);
            return rvalue(gz, scope, rl, result, node);
        },
        .set_eval_branch_quota => {
            const quota = try expr(gz, scope, .{ .ty = .u32_type }, params[0]);
            const result = try gz.addUnNode(.set_eval_branch_quota, quota, node);
            return rvalue(gz, scope, rl, result, node);
        },
        .compile_log => {
            const arg_refs = try astgen.gpa.alloc(Zir.Inst.Ref, params.len);
            defer astgen.gpa.free(arg_refs);

            for (params) |param, i| arg_refs[i] = try expr(gz, scope, .none, param);

            const result = try gz.addPlNode(.compile_log, node, Zir.Inst.MultiOp{
                .operands_len = @intCast(u32, params.len),
            });
            try gz.astgen.appendRefs(arg_refs);
            return rvalue(gz, scope, rl, result, node);
        },
        .field => {
            const field_name = try comptimeExpr(gz, scope, .{ .ty = .const_slice_u8_type }, params[1]);
            if (rl == .ref) {
                return try gz.addPlNode(.field_ptr_named, node, Zir.Inst.FieldNamed{
                    .lhs = try expr(gz, scope, .ref, params[0]),
                    .field_name = field_name,
                });
            }
            const result = try gz.addPlNode(.field_val_named, node, Zir.Inst.FieldNamed{
                .lhs = try expr(gz, scope, .none, params[0]),
                .field_name = field_name,
            });
            return rvalue(gz, scope, rl, result, node);
        },
        .as => return as(gz, scope, rl, node, params[0], params[1]),
        .bit_cast => return bitCast(gz, scope, rl, node, params[0], params[1]),
        .TypeOf => return typeOf(gz, scope, rl, node, params),

        .int_to_enum => {
            const result = try gz.addPlNode(.int_to_enum, node, Zir.Inst.Bin{
                .lhs = try typeExpr(gz, scope, params[0]),
                .rhs = try expr(gz, scope, .none, params[1]),
            });
            return rvalue(gz, scope, rl, result, node);
        },

        .enum_to_int => {
            const operand = try expr(gz, scope, .none, params[0]);
            const result = try gz.addUnNode(.enum_to_int, operand, node);
            return rvalue(gz, scope, rl, result, node);
        },

        .@"export" => {
            // TODO: @export is supposed to be able to export things other than functions.
            // Instead of `comptimeExpr` here we need `decl_ref`.
            const fn_to_export = try comptimeExpr(gz, scope, .none, params[0]);
            // TODO: the second parameter here is supposed to be
            // `std.builtin.ExportOptions`, not a string.
            const export_name = try comptimeExpr(gz, scope, .{ .ty = .const_slice_u8_type }, params[1]);
            _ = try gz.addPlNode(.@"export", node, Zir.Inst.Bin{
                .lhs = fn_to_export,
                .rhs = export_name,
            });
            return rvalue(gz, scope, rl, .void_value, node);
        },

        .has_decl => {
            const container_type = try typeExpr(gz, scope, params[0]);
            const name = try comptimeExpr(gz, scope, .{ .ty = .const_slice_u8_type }, params[1]);
            const result = try gz.addPlNode(.has_decl, node, Zir.Inst.Bin{
                .lhs = container_type,
                .rhs = name,
            });
            return rvalue(gz, scope, rl, result, node);
        },

        .type_info => {
            const operand = try typeExpr(gz, scope, params[0]);
            const result = try gz.addUnNode(.type_info, operand, node);
            return rvalue(gz, scope, rl, result, node);
        },

        .size_of => {
            const operand = try typeExpr(gz, scope, params[0]);
            const result = try gz.addUnNode(.size_of, operand, node);
            return rvalue(gz, scope, rl, result, node);
        },

        .bit_size_of => {
            const operand = try typeExpr(gz, scope, params[0]);
            const result = try gz.addUnNode(.bit_size_of, operand, node);
            return rvalue(gz, scope, rl, result, node);
        },

        .This => return rvalue(gz, scope, rl, try gz.addNode(.this, node), node),
        .fence => return rvalue(gz, scope, rl, try gz.addNode(.fence, node), node),
        .return_address => return rvalue(gz, scope, rl, try gz.addNode(.ret_addr, node), node),
        .src => return rvalue(gz, scope, rl, try gz.addNode(.builtin_src, node), node),

        .add_with_overflow => return overflowArithmetic(gz, scope, rl, node, params, .add_with_overflow),
        .sub_with_overflow => return overflowArithmetic(gz, scope, rl, node, params, .sub_with_overflow),
        .mul_with_overflow => return overflowArithmetic(gz, scope, rl, node, params, .mul_with_overflow),
        .shl_with_overflow => {
            const int_type = try typeExpr(gz, scope, params[0]);
            const log2_int_type = try gz.addUnNode(.log2_int_type, int_type, params[0]);
            const ptr_type = try gz.add(.{ .tag = .ptr_type_simple, .data = .{
                .ptr_type_simple = .{
                    .is_allowzero = false,
                    .is_mutable = true,
                    .is_volatile = false,
                    .size = .One,
                    .elem_type = int_type,
                },
            } });
            const lhs = try expr(gz, scope, .{ .ty = int_type }, params[1]);
            const rhs = try expr(gz, scope, .{ .ty = log2_int_type }, params[2]);
            const ptr = try expr(gz, scope, .{ .ty = ptr_type }, params[3]);
            const result = try gz.addPlNode(.shl_with_overflow, node, Zir.Inst.OverflowArithmetic{
                .lhs = lhs,
                .rhs = rhs,
                .ptr = ptr,
            });
            return rvalue(gz, scope, rl, result, node);
        },

        .align_cast,
        .align_of,
        .atomic_load,
        .atomic_rmw,
        .atomic_store,
        .bit_offset_of,
        .bool_to_int,
        .mul_add,
        .byte_swap,
        .bit_reverse,
        .byte_offset_of,
        .call,
        .c_define,
        .c_import,
        .c_include,
        .clz,
        .cmpxchg_strong,
        .cmpxchg_weak,
        .ctz,
        .c_undef,
        .div_exact,
        .div_floor,
        .div_trunc,
        .embed_file,
        .error_name,
        .error_return_trace,
        .err_set_cast,
        .field_parent_ptr,
        .float_to_int,
        .has_field,
        .int_to_float,
        .int_to_ptr,
        .memcpy,
        .memset,
        .wasm_memory_size,
        .wasm_memory_grow,
        .mod,
        .panic,
        .pop_count,
        .ptr_cast,
        .rem,
        .set_align_stack,
        .set_cold,
        .set_float_mode,
        .set_runtime_safety,
        .shl_exact,
        .shr_exact,
        .shuffle,
        .splat,
        .reduce,
        .sqrt,
        .sin,
        .cos,
        .exp,
        .exp2,
        .log,
        .log2,
        .log10,
        .fabs,
        .floor,
        .ceil,
        .trunc,
        .round,
        .tag_name,
        .truncate,
        .Type,
        .type_name,
        .union_init,
        .async_call,
        .frame,
        .Frame,
        .frame_address,
        .frame_size,
        => return astgen.failNode(node, "TODO: implement builtin function {s}", .{
            builtin_name,
        }),
    }
}

fn overflowArithmetic(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    params: []const ast.Node.Index,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const int_type = try typeExpr(gz, scope, params[0]);
    const ptr_type = try gz.add(.{ .tag = .ptr_type_simple, .data = .{
        .ptr_type_simple = .{
            .is_allowzero = false,
            .is_mutable = true,
            .is_volatile = false,
            .size = .One,
            .elem_type = int_type,
        },
    } });
    const lhs = try expr(gz, scope, .{ .ty = int_type }, params[1]);
    const rhs = try expr(gz, scope, .{ .ty = int_type }, params[2]);
    const ptr = try expr(gz, scope, .{ .ty = ptr_type }, params[3]);
    const result = try gz.addPlNode(tag, node, Zir.Inst.OverflowArithmetic{
        .lhs = lhs,
        .rhs = rhs,
        .ptr = ptr,
    });
    return rvalue(gz, scope, rl, result, node);
}

fn callExpr(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    call: ast.full.Call,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    if (call.async_token) |async_token| {
        return astgen.failTok(async_token, "async and related features are not yet supported", .{});
    }
    const lhs = try expr(gz, scope, .none, call.ast.fn_expr);

    const args = try astgen.gpa.alloc(Zir.Inst.Ref, call.ast.params.len);
    defer astgen.gpa.free(args);

    for (call.ast.params) |param_node, i| {
        const param_type = try gz.add(.{
            .tag = .param_type,
            .data = .{ .param_type = .{
                .callee = lhs,
                .param_index = @intCast(u32, i),
            } },
        });
        args[i] = try expr(gz, scope, .{ .ty = param_type }, param_node);
    }

    const modifier: std.builtin.CallOptions.Modifier = switch (call.async_token != null) {
        true => .async_kw,
        false => .auto,
    };
    const result: Zir.Inst.Ref = res: {
        const tag: Zir.Inst.Tag = switch (modifier) {
            .auto => switch (args.len == 0) {
                true => break :res try gz.addUnNode(.call_none, lhs, node),
                false => .call,
            },
            .async_kw => return astgen.failNode(node, "async and related features are not yet supported", .{}),
            .never_tail => unreachable,
            .never_inline => unreachable,
            .no_async => return astgen.failNode(node, "async and related features are not yet supported", .{}),
            .always_tail => unreachable,
            .always_inline => unreachable,
            .compile_time => .call_compile_time,
        };
        break :res try gz.addCall(tag, lhs, args, node);
    };
    return rvalue(gz, scope, rl, result, node); // TODO function call with result location
}

pub const simple_types = std.ComptimeStringMap(Zir.Inst.Ref, .{
    .{ "u8", .u8_type },
    .{ "i8", .i8_type },
    .{ "u16", .u16_type },
    .{ "i16", .i16_type },
    .{ "u32", .u32_type },
    .{ "i32", .i32_type },
    .{ "u64", .u64_type },
    .{ "i64", .i64_type },
    .{ "usize", .usize_type },
    .{ "isize", .isize_type },
    .{ "c_short", .c_short_type },
    .{ "c_ushort", .c_ushort_type },
    .{ "c_int", .c_int_type },
    .{ "c_uint", .c_uint_type },
    .{ "c_long", .c_long_type },
    .{ "c_ulong", .c_ulong_type },
    .{ "c_longlong", .c_longlong_type },
    .{ "c_ulonglong", .c_ulonglong_type },
    .{ "c_longdouble", .c_longdouble_type },
    .{ "f16", .f16_type },
    .{ "f32", .f32_type },
    .{ "f64", .f64_type },
    .{ "f128", .f128_type },
    .{ "c_void", .c_void_type },
    .{ "bool", .bool_type },
    .{ "void", .void_type },
    .{ "type", .type_type },
    .{ "anyerror", .anyerror_type },
    .{ "comptime_int", .comptime_int_type },
    .{ "comptime_float", .comptime_float_type },
    .{ "noreturn", .noreturn_type },
    .{ "null", .null_type },
    .{ "undefined", .undefined_type },
    .{ "undefined", .undef },
    .{ "null", .null_value },
    .{ "true", .bool_true },
    .{ "false", .bool_false },
});

fn nodeMayNeedMemoryLocation(tree: *const ast.Tree, start_node: ast.Node.Index) bool {
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);

    var node = start_node;
    while (true) {
        switch (node_tags[node]) {
            .root,
            .@"usingnamespace",
            .test_decl,
            .switch_case,
            .switch_case_one,
            .container_field_init,
            .container_field_align,
            .container_field,
            .asm_output,
            .asm_input,
            => unreachable,

            .@"return",
            .@"break",
            .@"continue",
            .bit_not,
            .bool_not,
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            .@"defer",
            .@"errdefer",
            .address_of,
            .optional_type,
            .negation,
            .negation_wrap,
            .@"resume",
            .array_type,
            .array_type_sentinel,
            .ptr_type_aligned,
            .ptr_type_sentinel,
            .ptr_type,
            .ptr_type_bit_range,
            .@"suspend",
            .@"anytype",
            .fn_proto_simple,
            .fn_proto_multi,
            .fn_proto_one,
            .fn_proto,
            .fn_decl,
            .anyframe_type,
            .anyframe_literal,
            .integer_literal,
            .float_literal,
            .enum_literal,
            .string_literal,
            .multiline_string_literal,
            .char_literal,
            .true_literal,
            .false_literal,
            .null_literal,
            .undefined_literal,
            .unreachable_literal,
            .identifier,
            .error_set_decl,
            .container_decl,
            .container_decl_trailing,
            .container_decl_two,
            .container_decl_two_trailing,
            .container_decl_arg,
            .container_decl_arg_trailing,
            .tagged_union,
            .tagged_union_trailing,
            .tagged_union_two,
            .tagged_union_two_trailing,
            .tagged_union_enum_tag,
            .tagged_union_enum_tag_trailing,
            .@"asm",
            .asm_simple,
            .add,
            .add_wrap,
            .array_cat,
            .array_mult,
            .assign,
            .assign_bit_and,
            .assign_bit_or,
            .assign_bit_shift_left,
            .assign_bit_shift_right,
            .assign_bit_xor,
            .assign_div,
            .assign_sub,
            .assign_sub_wrap,
            .assign_mod,
            .assign_add,
            .assign_add_wrap,
            .assign_mul,
            .assign_mul_wrap,
            .bang_equal,
            .bit_and,
            .bit_or,
            .bit_shift_left,
            .bit_shift_right,
            .bit_xor,
            .bool_and,
            .bool_or,
            .div,
            .equal_equal,
            .error_union,
            .greater_or_equal,
            .greater_than,
            .less_or_equal,
            .less_than,
            .merge_error_sets,
            .mod,
            .mul,
            .mul_wrap,
            .switch_range,
            .field_access,
            .sub,
            .sub_wrap,
            .slice,
            .slice_open,
            .slice_sentinel,
            .deref,
            .array_access,
            .error_value,
            .while_simple, // This variant cannot have an else expression.
            .while_cont, // This variant cannot have an else expression.
            .for_simple, // This variant cannot have an else expression.
            .if_simple, // This variant cannot have an else expression.
            => return false,

            // Forward the question to the LHS sub-expression.
            .grouped_expression,
            .@"try",
            .@"await",
            .@"comptime",
            .@"nosuspend",
            .unwrap_optional,
            => node = node_datas[node].lhs,

            // Forward the question to the RHS sub-expression.
            .@"catch",
            .@"orelse",
            => node = node_datas[node].rhs,

            // True because these are exactly the expressions we need memory locations for.
            .array_init_one,
            .array_init_one_comma,
            .array_init_dot_two,
            .array_init_dot_two_comma,
            .array_init_dot,
            .array_init_dot_comma,
            .array_init,
            .array_init_comma,
            .struct_init_one,
            .struct_init_one_comma,
            .struct_init_dot_two,
            .struct_init_dot_two_comma,
            .struct_init_dot,
            .struct_init_dot_comma,
            .struct_init,
            .struct_init_comma,
            => return true,

            // True because depending on comptime conditions, sub-expressions
            // may be the kind that need memory locations.
            .@"while", // This variant always has an else expression.
            .@"if", // This variant always has an else expression.
            .@"for", // This variant always has an else expression.
            .@"switch",
            .switch_comma,
            .call_one,
            .call_one_comma,
            .async_call_one,
            .async_call_one_comma,
            .call,
            .call_comma,
            .async_call,
            .async_call_comma,
            => return true,

            .block_two,
            .block_two_semicolon,
            .block,
            .block_semicolon,
            => {
                const lbrace = main_tokens[node];
                if (token_tags[lbrace - 1] == .colon) {
                    // Labeled blocks may need a memory location to forward
                    // to their break statements.
                    return true;
                } else {
                    return false;
                }
            },

            .builtin_call,
            .builtin_call_comma,
            .builtin_call_two,
            .builtin_call_two_comma,
            => {
                const builtin_token = main_tokens[node];
                const builtin_name = tree.tokenSlice(builtin_token);
                // If the builtin is an invalid name, we don't cause an error here; instead
                // let it pass, and the error will be "invalid builtin function" later.
                const builtin_info = BuiltinFn.list.get(builtin_name) orelse return false;
                return builtin_info.needs_mem_loc;
            },
        }
    }
}

/// Applies `rl` semantics to `inst`. Expressions which do not do their own handling of
/// result locations must call this function on their result.
/// As an example, if the `ResultLoc` is `ptr`, it will write the result to the pointer.
/// If the `ResultLoc` is `ty`, it will coerce the result to the type.
fn rvalue(
    gz: *GenZir,
    scope: *Scope,
    rl: ResultLoc,
    result: Zir.Inst.Ref,
    src_node: ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    switch (rl) {
        .none, .none_or_ref => return result,
        .discard => {
            // Emit a compile error for discarding error values.
            _ = try gz.addUnNode(.ensure_result_non_error, result, src_node);
            return result;
        },
        .ref => {
            // We need a pointer but we have a value.
            const tree = &gz.astgen.file.tree;
            const src_token = tree.firstToken(src_node);
            return gz.addUnTok(.ref, result, src_token);
        },
        .ty => |ty_inst| {
            // Quickly eliminate some common, unnecessary type coercion.
            const as_ty = @as(u64, @enumToInt(Zir.Inst.Ref.type_type)) << 32;
            const as_comptime_int = @as(u64, @enumToInt(Zir.Inst.Ref.comptime_int_type)) << 32;
            const as_bool = @as(u64, @enumToInt(Zir.Inst.Ref.bool_type)) << 32;
            const as_usize = @as(u64, @enumToInt(Zir.Inst.Ref.usize_type)) << 32;
            const as_void = @as(u64, @enumToInt(Zir.Inst.Ref.void_type)) << 32;
            switch ((@as(u64, @enumToInt(ty_inst)) << 32) | @as(u64, @enumToInt(result))) {
                as_ty | @enumToInt(Zir.Inst.Ref.u8_type),
                as_ty | @enumToInt(Zir.Inst.Ref.i8_type),
                as_ty | @enumToInt(Zir.Inst.Ref.u16_type),
                as_ty | @enumToInt(Zir.Inst.Ref.i16_type),
                as_ty | @enumToInt(Zir.Inst.Ref.u32_type),
                as_ty | @enumToInt(Zir.Inst.Ref.i32_type),
                as_ty | @enumToInt(Zir.Inst.Ref.u64_type),
                as_ty | @enumToInt(Zir.Inst.Ref.i64_type),
                as_ty | @enumToInt(Zir.Inst.Ref.usize_type),
                as_ty | @enumToInt(Zir.Inst.Ref.isize_type),
                as_ty | @enumToInt(Zir.Inst.Ref.c_short_type),
                as_ty | @enumToInt(Zir.Inst.Ref.c_ushort_type),
                as_ty | @enumToInt(Zir.Inst.Ref.c_int_type),
                as_ty | @enumToInt(Zir.Inst.Ref.c_uint_type),
                as_ty | @enumToInt(Zir.Inst.Ref.c_long_type),
                as_ty | @enumToInt(Zir.Inst.Ref.c_ulong_type),
                as_ty | @enumToInt(Zir.Inst.Ref.c_longlong_type),
                as_ty | @enumToInt(Zir.Inst.Ref.c_ulonglong_type),
                as_ty | @enumToInt(Zir.Inst.Ref.c_longdouble_type),
                as_ty | @enumToInt(Zir.Inst.Ref.f16_type),
                as_ty | @enumToInt(Zir.Inst.Ref.f32_type),
                as_ty | @enumToInt(Zir.Inst.Ref.f64_type),
                as_ty | @enumToInt(Zir.Inst.Ref.f128_type),
                as_ty | @enumToInt(Zir.Inst.Ref.c_void_type),
                as_ty | @enumToInt(Zir.Inst.Ref.bool_type),
                as_ty | @enumToInt(Zir.Inst.Ref.void_type),
                as_ty | @enumToInt(Zir.Inst.Ref.type_type),
                as_ty | @enumToInt(Zir.Inst.Ref.anyerror_type),
                as_ty | @enumToInt(Zir.Inst.Ref.comptime_int_type),
                as_ty | @enumToInt(Zir.Inst.Ref.comptime_float_type),
                as_ty | @enumToInt(Zir.Inst.Ref.noreturn_type),
                as_ty | @enumToInt(Zir.Inst.Ref.null_type),
                as_ty | @enumToInt(Zir.Inst.Ref.undefined_type),
                as_ty | @enumToInt(Zir.Inst.Ref.fn_noreturn_no_args_type),
                as_ty | @enumToInt(Zir.Inst.Ref.fn_void_no_args_type),
                as_ty | @enumToInt(Zir.Inst.Ref.fn_naked_noreturn_no_args_type),
                as_ty | @enumToInt(Zir.Inst.Ref.fn_ccc_void_no_args_type),
                as_ty | @enumToInt(Zir.Inst.Ref.single_const_pointer_to_comptime_int_type),
                as_ty | @enumToInt(Zir.Inst.Ref.const_slice_u8_type),
                as_ty | @enumToInt(Zir.Inst.Ref.enum_literal_type),
                as_comptime_int | @enumToInt(Zir.Inst.Ref.zero),
                as_comptime_int | @enumToInt(Zir.Inst.Ref.one),
                as_bool | @enumToInt(Zir.Inst.Ref.bool_true),
                as_bool | @enumToInt(Zir.Inst.Ref.bool_false),
                as_usize | @enumToInt(Zir.Inst.Ref.zero_usize),
                as_usize | @enumToInt(Zir.Inst.Ref.one_usize),
                as_void | @enumToInt(Zir.Inst.Ref.void_value),
                => return result, // type of result is already correct

                // Need an explicit type coercion instruction.
                else => return gz.addPlNode(.as_node, src_node, Zir.Inst.As{
                    .dest_type = ty_inst,
                    .operand = result,
                }),
            }
        },
        .ptr => |ptr_inst| {
            _ = try gz.addPlNode(.store_node, src_node, Zir.Inst.Bin{
                .lhs = ptr_inst,
                .rhs = result,
            });
            return result;
        },
        .inferred_ptr => |alloc| {
            _ = try gz.addBin(.store_to_inferred_ptr, alloc, result);
            return result;
        },
        .block_ptr => |block_scope| {
            block_scope.rvalue_rl_count += 1;
            _ = try gz.addBin(.store_to_block_ptr, block_scope.rl_ptr, result);
            return result;
        },
    }
}

/// Given an identifier token, obtain the string for it.
/// If the token uses @"" syntax, parses as a string, reports errors if applicable,
/// and allocates the result within `scope.arena()`.
/// Otherwise, returns a reference to the source code bytes directly.
/// See also `appendIdentStr` and `parseStrLit`.
pub fn identifierTokenString(astgen: *AstGen, token: ast.TokenIndex) InnerError![]const u8 {
    const tree = &astgen.file.tree;
    const token_tags = tree.tokens.items(.tag);
    assert(token_tags[token] == .identifier);
    const ident_name = tree.tokenSlice(token);
    if (!mem.startsWith(u8, ident_name, "@")) {
        return ident_name;
    }
    var buf: ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(astgen.gpa);
    try astgen.parseStrLit(token, &buf, ident_name, 1);
    const duped = try astgen.arena.dupe(u8, buf.items);
    return duped;
}

/// Given an identifier token, obtain the string for it (possibly parsing as a string
/// literal if it is @"" syntax), and append the string to `buf`.
/// See also `identifierTokenString` and `parseStrLit`.
pub fn appendIdentStr(
    astgen: *AstGen,
    token: ast.TokenIndex,
    buf: *ArrayListUnmanaged(u8),
) InnerError!void {
    const tree = &astgen.file.tree;
    const token_tags = tree.tokens.items(.tag);
    assert(token_tags[token] == .identifier);
    const ident_name = tree.tokenSlice(token);
    if (!mem.startsWith(u8, ident_name, "@")) {
        return buf.appendSlice(astgen.gpa, ident_name);
    } else {
        return astgen.parseStrLit(token, buf, ident_name, 1);
    }
}

/// Appends the result to `buf`.
pub fn parseStrLit(
    astgen: *AstGen,
    token: ast.TokenIndex,
    buf: *ArrayListUnmanaged(u8),
    bytes: []const u8,
    offset: u32,
) InnerError!void {
    const tree = &astgen.file.tree;
    const raw_string = bytes[offset..];
    var buf_managed = buf.toManaged(astgen.gpa);
    const result = std.zig.string_literal.parseAppend(&buf_managed, raw_string);
    buf.* = buf_managed.toUnmanaged();
    switch (try result) {
        .success => return,
        .invalid_character => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
                "invalid string literal character: '{c}'",
                .{raw_string[bad_index]},
            );
        },
        .expected_hex_digits => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
                "expected hex digits after '\\x'",
                .{},
            );
        },
        .invalid_hex_escape => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
                "invalid hex digit: '{c}'",
                .{raw_string[bad_index]},
            );
        },
        .invalid_unicode_escape => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
                "invalid unicode digit: '{c}'",
                .{raw_string[bad_index]},
            );
        },
        .missing_matching_rbrace => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
                "missing matching '}}' character",
                .{},
            );
        },
        .expected_unicode_digits => |bad_index| {
            return astgen.failOff(
                token,
                offset + @intCast(u32, bad_index),
                "expected unicode digits after '\\u'",
                .{},
            );
        },
    }
}

pub fn failNode(
    astgen: *AstGen,
    node: ast.Node.Index,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    return astgen.failNodeNotes(node, format, args, &[0]u32{});
}

pub fn failNodeNotes(
    astgen: *AstGen,
    node: ast.Node.Index,
    comptime format: []const u8,
    args: anytype,
    notes: []const u32,
) InnerError {
    @setCold(true);
    const string_bytes = &astgen.string_bytes;
    const msg = @intCast(u32, string_bytes.items.len);
    {
        var managed = string_bytes.toManaged(astgen.gpa);
        defer string_bytes.* = managed.toUnmanaged();
        try managed.writer().print(format ++ "\x00", args);
    }
    const notes_index: u32 = if (notes.len != 0) blk: {
        const notes_start = astgen.extra.items.len;
        try astgen.extra.ensureCapacity(astgen.gpa, notes_start + 1 + notes.len);
        astgen.extra.appendAssumeCapacity(@intCast(u32, notes.len));
        astgen.extra.appendSliceAssumeCapacity(notes);
        break :blk @intCast(u32, notes_start);
    } else 0;
    try astgen.compile_errors.append(astgen.gpa, .{
        .msg = msg,
        .node = node,
        .token = 0,
        .byte_offset = 0,
        .notes = notes_index,
    });
    return error.AnalysisFail;
}

pub fn failTok(
    astgen: *AstGen,
    token: ast.TokenIndex,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    return astgen.failTokNotes(token, format, args, &[0]u32{});
}

pub fn failTokNotes(
    astgen: *AstGen,
    token: ast.TokenIndex,
    comptime format: []const u8,
    args: anytype,
    notes: []const u32,
) InnerError {
    @setCold(true);
    const string_bytes = &astgen.string_bytes;
    const msg = @intCast(u32, string_bytes.items.len);
    {
        var managed = string_bytes.toManaged(astgen.gpa);
        defer string_bytes.* = managed.toUnmanaged();
        try managed.writer().print(format ++ "\x00", args);
    }
    const notes_index: u32 = if (notes.len != 0) blk: {
        const notes_start = astgen.extra.items.len;
        try astgen.extra.ensureCapacity(astgen.gpa, notes_start + 1 + notes.len);
        astgen.extra.appendAssumeCapacity(@intCast(u32, notes.len));
        astgen.extra.appendSliceAssumeCapacity(notes);
        break :blk @intCast(u32, notes_start);
    } else 0;
    try astgen.compile_errors.append(astgen.gpa, .{
        .msg = msg,
        .node = 0,
        .token = token,
        .byte_offset = 0,
        .notes = notes_index,
    });
    return error.AnalysisFail;
}

/// Same as `fail`, except given an absolute byte offset, and the function sets up the `LazySrcLoc`
/// for pointing at it relatively by subtracting from the containing `Decl`.
pub fn failOff(
    astgen: *AstGen,
    token: ast.TokenIndex,
    byte_offset: u32,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    @setCold(true);
    const string_bytes = &astgen.string_bytes;
    const msg = @intCast(u32, string_bytes.items.len);
    {
        var managed = string_bytes.toManaged(astgen.gpa);
        defer string_bytes.* = managed.toUnmanaged();
        try managed.writer().print(format ++ "\x00", args);
    }
    try astgen.compile_errors.append(astgen.gpa, .{
        .msg = msg,
        .node = 0,
        .token = token,
        .byte_offset = byte_offset,
        .notes = 0,
    });
    return error.AnalysisFail;
}

pub fn errNoteTok(
    astgen: *AstGen,
    token: ast.TokenIndex,
    comptime format: []const u8,
    args: anytype,
) Allocator.Error!u32 {
    @setCold(true);
    const string_bytes = &astgen.string_bytes;
    const msg = @intCast(u32, string_bytes.items.len);
    {
        var managed = string_bytes.toManaged(astgen.gpa);
        defer string_bytes.* = managed.toUnmanaged();
        try managed.writer().print(format ++ "\x00", args);
    }
    return astgen.addExtra(Zir.Inst.CompileErrors.Item{
        .msg = msg,
        .node = 0,
        .token = token,
        .byte_offset = 0,
        .notes = 0,
    });
}

pub fn errNoteNode(
    astgen: *AstGen,
    node: ast.Node.Index,
    comptime format: []const u8,
    args: anytype,
) Allocator.Error!u32 {
    @setCold(true);
    const string_bytes = &astgen.string_bytes;
    const msg = @intCast(u32, string_bytes.items.len);
    {
        var managed = string_bytes.toManaged(astgen.gpa);
        defer string_bytes.* = managed.toUnmanaged();
        try managed.writer().print(format ++ "\x00", args);
    }
    return astgen.addExtra(Zir.Inst.CompileErrors.Item{
        .msg = msg,
        .node = node,
        .token = 0,
        .byte_offset = 0,
        .notes = 0,
    });
}
