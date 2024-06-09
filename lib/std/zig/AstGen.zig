//! Ingests an AST and produces ZIR code.
const AstGen = @This();

const std = @import("std");
const Ast = std.zig.Ast;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const StringIndexAdapter = std.hash_map.StringIndexAdapter;
const StringIndexContext = std.hash_map.StringIndexContext;

const isPrimitive = std.zig.primitives.isPrimitive;

const Zir = std.zig.Zir;
const BuiltinFn = std.zig.BuiltinFn;
const AstRlAnnotate = std.zig.AstRlAnnotate;

gpa: Allocator,
tree: *const Ast,
/// The set of nodes which, given the choice, must expose a result pointer to
/// sub-expressions. See `AstRlAnnotate` for details.
nodes_need_rl: *const AstRlAnnotate.RlNeededSet,
instructions: std.MultiArrayList(Zir.Inst) = .{},
extra: ArrayListUnmanaged(u32) = .{},
string_bytes: ArrayListUnmanaged(u8) = .{},
/// Tracks the current byte offset within the source file.
/// Used to populate line deltas in the ZIR. AstGen maintains
/// this "cursor" throughout the entire AST lowering process in order
/// to avoid starting over the line/column scan for every declaration, which
/// would be O(N^2).
source_offset: u32 = 0,
/// Tracks the corresponding line of `source_offset`.
/// This value is absolute.
source_line: u32 = 0,
/// Tracks the corresponding column of `source_offset`.
/// This value is absolute.
source_column: u32 = 0,
/// Used for temporary allocations; freed after AstGen is complete.
/// The resulting ZIR code has no references to anything in this arena.
arena: Allocator,
string_table: std.HashMapUnmanaged(u32, void, StringIndexContext, std.hash_map.default_max_load_percentage) = .{},
compile_errors: ArrayListUnmanaged(Zir.Inst.CompileErrors.Item) = .{},
/// The topmost block of the current function.
fn_block: ?*GenZir = null,
fn_var_args: bool = false,
/// Whether we are somewhere within a function. If `true`, any container decls may be
/// generic and thus must be tunneled through closure.
within_fn: bool = false,
/// The return type of the current function. This may be a trivial `Ref`, or
/// otherwise it refers to a `ret_type` instruction.
fn_ret_ty: Zir.Inst.Ref = .none,
/// Maps string table indexes to the first `@import` ZIR instruction
/// that uses this string as the operand.
imports: std.AutoArrayHashMapUnmanaged(Zir.NullTerminatedString, Ast.TokenIndex) = .{},
/// Used for temporary storage when building payloads.
scratch: std.ArrayListUnmanaged(u32) = .{},
/// Whenever a `ref` instruction is needed, it is created and saved in this
/// table instead of being immediately appended to the current block body.
/// Then, when the instruction is being added to the parent block (typically from
/// setBlockBody), if it has a ref_table entry, then the ref instruction is added
/// there. This makes sure two properties are upheld:
/// 1. All pointers to the same locals return the same address. This is required
///    to be compliant with the language specification.
/// 2. `ref` instructions will dominate their uses. This is a required property
///    of ZIR.
/// The key is the ref operand; the value is the ref instruction.
ref_table: std.AutoHashMapUnmanaged(Zir.Inst.Index, Zir.Inst.Index) = .{},

const InnerError = error{ OutOfMemory, AnalysisFail };

fn addExtra(astgen: *AstGen, extra: anytype) Allocator.Error!u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    try astgen.extra.ensureUnusedCapacity(astgen.gpa, fields.len);
    return addExtraAssumeCapacity(astgen, extra);
}

fn addExtraAssumeCapacity(astgen: *AstGen, extra: anytype) u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    const extra_index: u32 = @intCast(astgen.extra.items.len);
    astgen.extra.items.len += fields.len;
    setExtra(astgen, extra_index, extra);
    return extra_index;
}

fn setExtra(astgen: *AstGen, index: usize, extra: anytype) void {
    const fields = std.meta.fields(@TypeOf(extra));
    var i = index;
    inline for (fields) |field| {
        astgen.extra.items[i] = switch (field.type) {
            u32 => @field(extra, field.name),

            Zir.Inst.Ref,
            Zir.Inst.Index,
            Zir.Inst.Declaration.Name,
            Zir.NullTerminatedString,
            => @intFromEnum(@field(extra, field.name)),

            i32,
            Zir.Inst.Call.Flags,
            Zir.Inst.BuiltinCall.Flags,
            Zir.Inst.SwitchBlock.Bits,
            Zir.Inst.SwitchBlockErrUnion.Bits,
            Zir.Inst.FuncFancy.Bits,
            Zir.Inst.Declaration.Flags,
            => @bitCast(@field(extra, field.name)),

            else => @compileError("bad field type"),
        };
        i += 1;
    }
}

fn reserveExtra(astgen: *AstGen, size: usize) Allocator.Error!u32 {
    const extra_index: u32 = @intCast(astgen.extra.items.len);
    try astgen.extra.resize(astgen.gpa, extra_index + size);
    return extra_index;
}

fn appendRefs(astgen: *AstGen, refs: []const Zir.Inst.Ref) !void {
    return astgen.extra.appendSlice(astgen.gpa, @ptrCast(refs));
}

fn appendRefsAssumeCapacity(astgen: *AstGen, refs: []const Zir.Inst.Ref) void {
    astgen.extra.appendSliceAssumeCapacity(@ptrCast(refs));
}

pub fn generate(gpa: Allocator, tree: Ast) Allocator.Error!Zir {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var nodes_need_rl = try AstRlAnnotate.annotate(gpa, arena.allocator(), tree);
    defer nodes_need_rl.deinit(gpa);

    var astgen: AstGen = .{
        .gpa = gpa,
        .arena = arena.allocator(),
        .tree = &tree,
        .nodes_need_rl = &nodes_need_rl,
    };
    defer astgen.deinit(gpa);

    // String table index 0 is reserved for `NullTerminatedString.empty`.
    try astgen.string_bytes.append(gpa, 0);

    // We expect at least as many ZIR instructions and extra data items
    // as AST nodes.
    try astgen.instructions.ensureTotalCapacity(gpa, tree.nodes.len);

    // First few indexes of extra are reserved and set at the end.
    const reserved_count = @typeInfo(Zir.ExtraIndex).Enum.fields.len;
    try astgen.extra.ensureTotalCapacity(gpa, tree.nodes.len + reserved_count);
    astgen.extra.items.len += reserved_count;

    var top_scope: Scope.Top = .{};

    var gz_instructions: std.ArrayListUnmanaged(Zir.Inst.Index) = .{};
    var gen_scope: GenZir = .{
        .is_comptime = true,
        .parent = &top_scope.base,
        .anon_name_strategy = .parent,
        .decl_node_index = 0,
        .decl_line = 0,
        .astgen = &astgen,
        .instructions = &gz_instructions,
        .instructions_top = 0,
    };
    defer gz_instructions.deinit(gpa);

    // The AST -> ZIR lowering process assumes an AST that does not have any
    // parse errors.
    if (tree.errors.len == 0) {
        if (AstGen.structDeclInner(
            &gen_scope,
            &gen_scope.base,
            0,
            tree.containerDeclRoot(),
            .auto,
            0,
        )) |struct_decl_ref| {
            assert(struct_decl_ref.toIndex().? == .main_struct_inst);
        } else |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.AnalysisFail => {}, // Handled via compile_errors below.
        }
    } else {
        try lowerAstErrors(&astgen);
    }

    const err_index = @intFromEnum(Zir.ExtraIndex.compile_errors);
    if (astgen.compile_errors.items.len == 0) {
        astgen.extra.items[err_index] = 0;
    } else {
        try astgen.extra.ensureUnusedCapacity(gpa, 1 + astgen.compile_errors.items.len *
            @typeInfo(Zir.Inst.CompileErrors.Item).Struct.fields.len);

        astgen.extra.items[err_index] = astgen.addExtraAssumeCapacity(Zir.Inst.CompileErrors{
            .items_len = @intCast(astgen.compile_errors.items.len),
        });

        for (astgen.compile_errors.items) |item| {
            _ = astgen.addExtraAssumeCapacity(item);
        }
    }

    const imports_index = @intFromEnum(Zir.ExtraIndex.imports);
    if (astgen.imports.count() == 0) {
        astgen.extra.items[imports_index] = 0;
    } else {
        try astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.Imports).Struct.fields.len +
            astgen.imports.count() * @typeInfo(Zir.Inst.Imports.Item).Struct.fields.len);

        astgen.extra.items[imports_index] = astgen.addExtraAssumeCapacity(Zir.Inst.Imports{
            .imports_len = @intCast(astgen.imports.count()),
        });

        var it = astgen.imports.iterator();
        while (it.next()) |entry| {
            _ = astgen.addExtraAssumeCapacity(Zir.Inst.Imports.Item{
                .name = entry.key_ptr.*,
                .token = entry.value_ptr.*,
            });
        }
    }

    return Zir{
        .instructions = astgen.instructions.toOwnedSlice(),
        .string_bytes = try astgen.string_bytes.toOwnedSlice(gpa),
        .extra = try astgen.extra.toOwnedSlice(gpa),
    };
}

fn deinit(astgen: *AstGen, gpa: Allocator) void {
    astgen.instructions.deinit(gpa);
    astgen.extra.deinit(gpa);
    astgen.string_table.deinit(gpa);
    astgen.string_bytes.deinit(gpa);
    astgen.compile_errors.deinit(gpa);
    astgen.imports.deinit(gpa);
    astgen.scratch.deinit(gpa);
    astgen.ref_table.deinit(gpa);
}

const ResultInfo = struct {
    /// The semantics requested for the result location
    rl: Loc,

    /// The "operator" consuming the result location
    ctx: Context = .none,

    /// Turns a `coerced_ty` back into a `ty`. Should be called at branch points
    /// such as if and switch expressions.
    fn br(ri: ResultInfo) ResultInfo {
        return switch (ri.rl) {
            .coerced_ty => |ty| .{
                .rl = .{ .ty = ty },
                .ctx = ri.ctx,
            },
            else => ri,
        };
    }

    fn zirTag(ri: ResultInfo) Zir.Inst.Tag {
        switch (ri.rl) {
            .ty => return switch (ri.ctx) {
                .shift_op => .as_shift_operand,
                else => .as_node,
            },
            else => unreachable,
        }
    }

    const Loc = union(enum) {
        /// The expression is the right-hand side of assignment to `_`. Only the side-effects of the
        /// expression should be generated. The result instruction from the expression must
        /// be ignored.
        discard,
        /// The expression has an inferred type, and it will be evaluated as an rvalue.
        none,
        /// The expression will be coerced into this type, but it will be evaluated as an rvalue.
        ty: Zir.Inst.Ref,
        /// Same as `ty` but it is guaranteed that Sema will additionally perform the coercion,
        /// so no `as` instruction needs to be emitted.
        coerced_ty: Zir.Inst.Ref,
        /// The expression must generate a pointer rather than a value. For example, the left hand side
        /// of an assignment uses this kind of result location.
        ref,
        /// The expression must generate a pointer rather than a value, and the pointer will be coerced
        /// by other code to this type, which is guaranteed by earlier instructions to be a pointer type.
        ref_coerced_ty: Zir.Inst.Ref,
        /// The expression must store its result into this typed pointer. The result instruction
        /// from the expression must be ignored.
        ptr: PtrResultLoc,
        /// The expression must store its result into this allocation, which has an inferred type.
        /// The result instruction from the expression must be ignored.
        /// Always an instruction with tag `alloc_inferred`.
        inferred_ptr: Zir.Inst.Ref,
        /// The expression has a sequence of pointers to store its results into due to a destructure
        /// operation. Each of these pointers may or may not have an inferred type.
        destructure: struct {
            /// The AST node of the destructure operation itself.
            src_node: Ast.Node.Index,
            /// The pointers to store results into.
            components: []const DestructureComponent,
        },

        const DestructureComponent = union(enum) {
            typed_ptr: PtrResultLoc,
            inferred_ptr: Zir.Inst.Ref,
            discard,
        };

        const PtrResultLoc = struct {
            inst: Zir.Inst.Ref,
            src_node: ?Ast.Node.Index = null,
        };

        /// Find the result type for a cast builtin given the result location.
        /// If the location does not have a known result type, returns `null`.
        fn resultType(rl: Loc, gz: *GenZir, node: Ast.Node.Index) !?Zir.Inst.Ref {
            return switch (rl) {
                .discard, .none, .ref, .inferred_ptr, .destructure => null,
                .ty, .coerced_ty => |ty_ref| ty_ref,
                .ref_coerced_ty => |ptr_ty| try gz.addUnNode(.elem_type, ptr_ty, node),
                .ptr => |ptr| {
                    const ptr_ty = try gz.addUnNode(.typeof, ptr.inst, node);
                    return try gz.addUnNode(.elem_type, ptr_ty, node);
                },
            };
        }

        /// Find the result type for a cast builtin given the result location.
        /// If the location does not have a known result type, emits an error on
        /// the given node.
        fn resultTypeForCast(rl: Loc, gz: *GenZir, node: Ast.Node.Index, builtin_name: []const u8) !Zir.Inst.Ref {
            const astgen = gz.astgen;
            if (try rl.resultType(gz, node)) |ty| return ty;
            switch (rl) {
                .destructure => |destructure| return astgen.failNodeNotes(node, "{s} must have a known result type", .{builtin_name}, &.{
                    try astgen.errNoteNode(destructure.src_node, "destructure expressions do not provide a single result type", .{}),
                    try astgen.errNoteNode(node, "use @as to provide explicit result type", .{}),
                }),
                else => return astgen.failNodeNotes(node, "{s} must have a known result type", .{builtin_name}, &.{
                    try astgen.errNoteNode(node, "use @as to provide explicit result type", .{}),
                }),
            }
        }
    };

    const Context = enum {
        /// The expression is the operand to a return expression.
        @"return",
        /// The expression is the input to an error-handling operator (if-else, try, or catch).
        error_handling_expr,
        /// The expression is the right-hand side of a shift operation.
        shift_op,
        /// The expression is an argument in a function call.
        fn_arg,
        /// The expression is the right-hand side of an initializer for a `const` variable
        const_init,
        /// The expression is the right-hand side of an assignment expression.
        assignment,
        /// No specific operator in particular.
        none,
    };
};

const coerced_align_ri: ResultInfo = .{ .rl = .{ .coerced_ty = .u29_type } };
const coerced_addrspace_ri: ResultInfo = .{ .rl = .{ .coerced_ty = .address_space_type } };
const coerced_linksection_ri: ResultInfo = .{ .rl = .{ .coerced_ty = .slice_const_u8_type } };
const coerced_type_ri: ResultInfo = .{ .rl = .{ .coerced_ty = .type_type } };
const coerced_bool_ri: ResultInfo = .{ .rl = .{ .coerced_ty = .bool_type } };

fn typeExpr(gz: *GenZir, scope: *Scope, type_node: Ast.Node.Index) InnerError!Zir.Inst.Ref {
    return comptimeExpr(gz, scope, coerced_type_ri, type_node);
}

fn reachableTypeExpr(
    gz: *GenZir,
    scope: *Scope,
    type_node: Ast.Node.Index,
    reachable_node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    return reachableExprComptime(gz, scope, coerced_type_ri, type_node, reachable_node, true);
}

/// Same as `expr` but fails with a compile error if the result type is `noreturn`.
fn reachableExpr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    reachable_node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    return reachableExprComptime(gz, scope, ri, node, reachable_node, false);
}

fn reachableExprComptime(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    reachable_node: Ast.Node.Index,
    force_comptime: bool,
) InnerError!Zir.Inst.Ref {
    const result_inst = if (force_comptime)
        try comptimeExpr(gz, scope, ri, node)
    else
        try expr(gz, scope, ri, node);

    if (gz.refIsNoReturn(result_inst)) {
        try gz.astgen.appendErrorNodeNotes(reachable_node, "unreachable code", .{}, &[_]u32{
            try gz.astgen.errNoteNode(node, "control flow is diverted here", .{}),
        });
    }
    return result_inst;
}

fn lvalExpr(gz: *GenZir, scope: *Scope, node: Ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
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
        .switch_case_inline => unreachable,
        .switch_case_one => unreachable,
        .switch_case_inline_one => unreachable,
        .container_field_init => unreachable,
        .container_field_align => unreachable,
        .container_field => unreachable,
        .asm_output => unreachable,
        .asm_input => unreachable,

        .assign,
        .assign_destructure,
        .assign_bit_and,
        .assign_bit_or,
        .assign_shl,
        .assign_shl_sat,
        .assign_shr,
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
        .bit_and,
        .bit_or,
        .shl,
        .shl_sat,
        .shr,
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
        .number_literal,
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
        .for_range,
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
    return expr(gz, scope, .{ .rl = .ref }, node);
}

/// Turn Zig AST into untyped ZIR instructions.
/// When `rl` is discard, ptr, inferred_ptr, or inferred_ptr, the
/// result instruction can be used to inspect whether it is isNoReturn() but that is it,
/// it must otherwise not be used.
fn expr(gz: *GenZir, scope: *Scope, ri: ResultInfo, node: Ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);
    const node_datas = tree.nodes.items(.data);
    const node_tags = tree.nodes.items(.tag);

    const prev_anon_name_strategy = gz.anon_name_strategy;
    defer gz.anon_name_strategy = prev_anon_name_strategy;
    if (!nodeUsesAnonNameStrategy(tree, node)) {
        gz.anon_name_strategy = .anon;
    }

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
        .@"defer" => unreachable, // Handled in `blockExpr`.
        .@"errdefer" => unreachable, // Handled in `blockExpr`.

        .switch_case => unreachable, // Handled in `switchExpr`.
        .switch_case_inline => unreachable, // Handled in `switchExpr`.
        .switch_case_one => unreachable, // Handled in `switchExpr`.
        .switch_case_inline_one => unreachable, // Handled in `switchExpr`.
        .switch_range => unreachable, // Handled in `switchExpr`.

        .asm_output => unreachable, // Handled in `asmExpr`.
        .asm_input => unreachable, // Handled in `asmExpr`.

        .for_range => unreachable, // Handled in `forExpr`.

        .assign => {
            try assign(gz, scope, node);
            return rvalue(gz, ri, .void_value, node);
        },

        .assign_destructure => {
            // Note that this variant does not declare any new var/const: that
            // variant is handled by `blockExprStmts`.
            try assignDestructure(gz, scope, node);
            return rvalue(gz, ri, .void_value, node);
        },

        .assign_shl => {
            try assignShift(gz, scope, node, .shl);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_shl_sat => {
            try assignShiftSat(gz, scope, node);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_shr => {
            try assignShift(gz, scope, node, .shr);
            return rvalue(gz, ri, .void_value, node);
        },

        .assign_bit_and => {
            try assignOp(gz, scope, node, .bit_and);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_bit_or => {
            try assignOp(gz, scope, node, .bit_or);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_bit_xor => {
            try assignOp(gz, scope, node, .xor);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_div => {
            try assignOp(gz, scope, node, .div);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_sub => {
            try assignOp(gz, scope, node, .sub);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_sub_wrap => {
            try assignOp(gz, scope, node, .subwrap);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_sub_sat => {
            try assignOp(gz, scope, node, .sub_sat);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_mod => {
            try assignOp(gz, scope, node, .mod_rem);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_add => {
            try assignOp(gz, scope, node, .add);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_add_wrap => {
            try assignOp(gz, scope, node, .addwrap);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_add_sat => {
            try assignOp(gz, scope, node, .add_sat);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_mul => {
            try assignOp(gz, scope, node, .mul);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_mul_wrap => {
            try assignOp(gz, scope, node, .mulwrap);
            return rvalue(gz, ri, .void_value, node);
        },
        .assign_mul_sat => {
            try assignOp(gz, scope, node, .mul_sat);
            return rvalue(gz, ri, .void_value, node);
        },

        // zig fmt: off
        .shl => return shiftOp(gz, scope, ri, node, node_datas[node].lhs, node_datas[node].rhs, .shl),
        .shr => return shiftOp(gz, scope, ri, node, node_datas[node].lhs, node_datas[node].rhs, .shr),

        .add      => return simpleBinOp(gz, scope, ri, node, .add),
        .add_wrap => return simpleBinOp(gz, scope, ri, node, .addwrap),
        .add_sat  => return simpleBinOp(gz, scope, ri, node, .add_sat),
        .sub      => return simpleBinOp(gz, scope, ri, node, .sub),
        .sub_wrap => return simpleBinOp(gz, scope, ri, node, .subwrap),
        .sub_sat  => return simpleBinOp(gz, scope, ri, node, .sub_sat),
        .mul      => return simpleBinOp(gz, scope, ri, node, .mul),
        .mul_wrap => return simpleBinOp(gz, scope, ri, node, .mulwrap),
        .mul_sat  => return simpleBinOp(gz, scope, ri, node, .mul_sat),
        .div      => return simpleBinOp(gz, scope, ri, node, .div),
        .mod      => return simpleBinOp(gz, scope, ri, node, .mod_rem),
        .shl_sat  => return simpleBinOp(gz, scope, ri, node, .shl_sat),

        .bit_and          => return simpleBinOp(gz, scope, ri, node, .bit_and),
        .bit_or           => return simpleBinOp(gz, scope, ri, node, .bit_or),
        .bit_xor          => return simpleBinOp(gz, scope, ri, node, .xor),
        .bang_equal       => return simpleBinOp(gz, scope, ri, node, .cmp_neq),
        .equal_equal      => return simpleBinOp(gz, scope, ri, node, .cmp_eq),
        .greater_than     => return simpleBinOp(gz, scope, ri, node, .cmp_gt),
        .greater_or_equal => return simpleBinOp(gz, scope, ri, node, .cmp_gte),
        .less_than        => return simpleBinOp(gz, scope, ri, node, .cmp_lt),
        .less_or_equal    => return simpleBinOp(gz, scope, ri, node, .cmp_lte),
        .array_cat        => return simpleBinOp(gz, scope, ri, node, .array_cat),

        .array_mult => {
            // This syntax form does not currently use the result type in the language specification.
            // However, the result type can be used to emit more optimal code for large multiplications by
            // having Sema perform a coercion before the multiplication operation.
            const result = try gz.addPlNode(.array_mul, node, Zir.Inst.ArrayMul{
                .res_ty = if (try ri.rl.resultType(gz, node)) |t| t else .none,
                .lhs = try expr(gz, scope, .{ .rl = .none }, node_datas[node].lhs),
                .rhs = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, node_datas[node].rhs),
            });
            return rvalue(gz, ri, result, node);
        },

        .error_union      => return simpleBinOp(gz, scope, ri, node, .error_union_type),
        .merge_error_sets => return simpleBinOp(gz, scope, ri, node, .merge_error_sets),

        .bool_and => return boolBinOp(gz, scope, ri, node, .bool_br_and),
        .bool_or  => return boolBinOp(gz, scope, ri, node, .bool_br_or),

        .bool_not => return simpleUnOp(gz, scope, ri, node, coerced_bool_ri, node_datas[node].lhs, .bool_not),
        .bit_not  => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none }, node_datas[node].lhs, .bit_not),

        .negation      => return   negation(gz, scope, ri, node),
        .negation_wrap => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none }, node_datas[node].lhs, .negate_wrap),

        .identifier => return identifier(gz, scope, ri, node),

        .asm_simple,
        .@"asm",
        => return asmExpr(gz, scope, ri, node, tree.fullAsm(node).?),

        .string_literal           => return stringLiteral(gz, ri, node),
        .multiline_string_literal => return multilineStringLiteral(gz, ri, node),

        .number_literal => return numberLiteral(gz, ri, node, node, .positive),
        // zig fmt: on

        .builtin_call_two, .builtin_call_two_comma => {
            if (node_datas[node].lhs == 0) {
                const params = [_]Ast.Node.Index{};
                return builtinCall(gz, scope, ri, node, &params);
            } else if (node_datas[node].rhs == 0) {
                const params = [_]Ast.Node.Index{node_datas[node].lhs};
                return builtinCall(gz, scope, ri, node, &params);
            } else {
                const params = [_]Ast.Node.Index{ node_datas[node].lhs, node_datas[node].rhs };
                return builtinCall(gz, scope, ri, node, &params);
            }
        },
        .builtin_call, .builtin_call_comma => {
            const params = tree.extra_data[node_datas[node].lhs..node_datas[node].rhs];
            return builtinCall(gz, scope, ri, node, params);
        },

        .call_one,
        .call_one_comma,
        .async_call_one,
        .async_call_one_comma,
        .call,
        .call_comma,
        .async_call,
        .async_call_comma,
        => {
            var buf: [1]Ast.Node.Index = undefined;
            return callExpr(gz, scope, ri, node, tree.fullCall(&buf, node).?);
        },

        .unreachable_literal => {
            try emitDbgNode(gz, node);
            _ = try gz.addAsIndex(.{
                .tag = .@"unreachable",
                .data = .{ .@"unreachable" = .{
                    .src_node = gz.nodeIndexToRelative(node),
                } },
            });
            return Zir.Inst.Ref.unreachable_value;
        },
        .@"return" => return ret(gz, scope, node),
        .field_access => return fieldAccess(gz, scope, ri, node),

        .if_simple,
        .@"if",
        => {
            const if_full = tree.fullIf(node).?;
            no_switch_on_err: {
                const error_token = if_full.error_token orelse break :no_switch_on_err;
                switch (node_tags[if_full.ast.else_expr]) {
                    .@"switch", .switch_comma => {},
                    else => break :no_switch_on_err,
                }
                const switch_operand = node_datas[if_full.ast.else_expr].lhs;
                if (node_tags[switch_operand] != .identifier) break :no_switch_on_err;
                if (!mem.eql(u8, tree.tokenSlice(error_token), tree.tokenSlice(main_tokens[switch_operand]))) break :no_switch_on_err;
                return switchExprErrUnion(gz, scope, ri.br(), node, .@"if");
            }
            return ifExpr(gz, scope, ri.br(), node, if_full);
        },

        .while_simple,
        .while_cont,
        .@"while",
        => return whileExpr(gz, scope, ri.br(), node, tree.fullWhile(node).?, false),

        .for_simple, .@"for" => return forExpr(gz, scope, ri.br(), node, tree.fullFor(node).?, false),

        .slice_open => {
            const lhs = try expr(gz, scope, .{ .rl = .ref }, node_datas[node].lhs);

            const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);
            const start = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, node_datas[node].rhs);
            try emitDbgStmt(gz, cursor);
            const result = try gz.addPlNode(.slice_start, node, Zir.Inst.SliceStart{
                .lhs = lhs,
                .start = start,
            });
            return rvalue(gz, ri, result, node);
        },
        .slice => {
            const extra = tree.extraData(node_datas[node].rhs, Ast.Node.Slice);
            const lhs_node = node_datas[node].lhs;
            const lhs_tag = node_tags[lhs_node];
            const lhs_is_slice_sentinel = lhs_tag == .slice_sentinel;
            const lhs_is_open_slice = lhs_tag == .slice_open or
                (lhs_is_slice_sentinel and tree.extraData(node_datas[lhs_node].rhs, Ast.Node.SliceSentinel).end == 0);
            if (lhs_is_open_slice and nodeIsTriviallyZero(tree, extra.start)) {
                const lhs = try expr(gz, scope, .{ .rl = .ref }, node_datas[lhs_node].lhs);

                const start = if (lhs_is_slice_sentinel) start: {
                    const lhs_extra = tree.extraData(node_datas[lhs_node].rhs, Ast.Node.SliceSentinel);
                    break :start try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, lhs_extra.start);
                } else try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, node_datas[lhs_node].rhs);

                const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);
                const len = if (extra.end != 0) try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, extra.end) else .none;
                try emitDbgStmt(gz, cursor);
                const result = try gz.addPlNode(.slice_length, node, Zir.Inst.SliceLength{
                    .lhs = lhs,
                    .start = start,
                    .len = len,
                    .start_src_node_offset = gz.nodeIndexToRelative(lhs_node),
                    .sentinel = .none,
                });
                return rvalue(gz, ri, result, node);
            }
            const lhs = try expr(gz, scope, .{ .rl = .ref }, node_datas[node].lhs);

            const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);
            const start = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, extra.start);
            const end = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, extra.end);
            try emitDbgStmt(gz, cursor);
            const result = try gz.addPlNode(.slice_end, node, Zir.Inst.SliceEnd{
                .lhs = lhs,
                .start = start,
                .end = end,
            });
            return rvalue(gz, ri, result, node);
        },
        .slice_sentinel => {
            const extra = tree.extraData(node_datas[node].rhs, Ast.Node.SliceSentinel);
            const lhs_node = node_datas[node].lhs;
            const lhs_tag = node_tags[lhs_node];
            const lhs_is_slice_sentinel = lhs_tag == .slice_sentinel;
            const lhs_is_open_slice = lhs_tag == .slice_open or
                (lhs_is_slice_sentinel and tree.extraData(node_datas[lhs_node].rhs, Ast.Node.SliceSentinel).end == 0);
            if (lhs_is_open_slice and nodeIsTriviallyZero(tree, extra.start)) {
                const lhs = try expr(gz, scope, .{ .rl = .ref }, node_datas[lhs_node].lhs);

                const start = if (lhs_is_slice_sentinel) start: {
                    const lhs_extra = tree.extraData(node_datas[lhs_node].rhs, Ast.Node.SliceSentinel);
                    break :start try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, lhs_extra.start);
                } else try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, node_datas[lhs_node].rhs);

                const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);
                const len = if (extra.end != 0) try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, extra.end) else .none;
                const sentinel = try expr(gz, scope, .{ .rl = .none }, extra.sentinel);
                try emitDbgStmt(gz, cursor);
                const result = try gz.addPlNode(.slice_length, node, Zir.Inst.SliceLength{
                    .lhs = lhs,
                    .start = start,
                    .len = len,
                    .start_src_node_offset = gz.nodeIndexToRelative(lhs_node),
                    .sentinel = sentinel,
                });
                return rvalue(gz, ri, result, node);
            }
            const lhs = try expr(gz, scope, .{ .rl = .ref }, node_datas[node].lhs);

            const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);
            const start = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, extra.start);
            const end = if (extra.end != 0) try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, extra.end) else .none;
            const sentinel = try expr(gz, scope, .{ .rl = .none }, extra.sentinel);
            try emitDbgStmt(gz, cursor);
            const result = try gz.addPlNode(.slice_sentinel, node, Zir.Inst.SliceSentinel{
                .lhs = lhs,
                .start = start,
                .end = end,
                .sentinel = sentinel,
            });
            return rvalue(gz, ri, result, node);
        },

        .deref => {
            const lhs = try expr(gz, scope, .{ .rl = .none }, node_datas[node].lhs);
            _ = try gz.addUnNode(.validate_deref, lhs, node);
            switch (ri.rl) {
                .ref, .ref_coerced_ty => return lhs,
                else => {
                    const result = try gz.addUnNode(.load, lhs, node);
                    return rvalue(gz, ri, result, node);
                },
            }
        },
        .address_of => {
            const operand_rl: ResultInfo.Loc = if (try ri.rl.resultType(gz, node)) |res_ty_inst| rl: {
                _ = try gz.addUnTok(.validate_ref_ty, res_ty_inst, tree.firstToken(node));
                break :rl .{ .ref_coerced_ty = res_ty_inst };
            } else .ref;
            const result = try expr(gz, scope, .{ .rl = operand_rl }, node_datas[node].lhs);
            return rvalue(gz, ri, result, node);
        },
        .optional_type => {
            const operand = try typeExpr(gz, scope, node_datas[node].lhs);
            const result = try gz.addUnNode(.optional_type, operand, node);
            return rvalue(gz, ri, result, node);
        },
        .unwrap_optional => switch (ri.rl) {
            .ref, .ref_coerced_ty => {
                const lhs = try expr(gz, scope, .{ .rl = .ref }, node_datas[node].lhs);

                const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);
                try emitDbgStmt(gz, cursor);

                return gz.addUnNode(.optional_payload_safe_ptr, lhs, node);
            },
            else => {
                const lhs = try expr(gz, scope, .{ .rl = .none }, node_datas[node].lhs);

                const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);
                try emitDbgStmt(gz, cursor);

                return rvalue(gz, ri, try gz.addUnNode(.optional_payload_safe, lhs, node), node);
            },
        },
        .block_two, .block_two_semicolon => {
            const statements = [2]Ast.Node.Index{ node_datas[node].lhs, node_datas[node].rhs };
            if (node_datas[node].lhs == 0) {
                return blockExpr(gz, scope, ri, node, statements[0..0]);
            } else if (node_datas[node].rhs == 0) {
                return blockExpr(gz, scope, ri, node, statements[0..1]);
            } else {
                return blockExpr(gz, scope, ri, node, statements[0..2]);
            }
        },
        .block, .block_semicolon => {
            const statements = tree.extra_data[node_datas[node].lhs..node_datas[node].rhs];
            return blockExpr(gz, scope, ri, node, statements);
        },
        .enum_literal => return simpleStrTok(gz, ri, main_tokens[node], node, .enum_literal),
        .error_value => return simpleStrTok(gz, ri, node_datas[node].rhs, node, .error_value),
        // TODO restore this when implementing https://github.com/ziglang/zig/issues/6025
        // .anyframe_literal => return rvalue(gz, ri, .anyframe_type, node),
        .anyframe_literal => {
            const result = try gz.addUnNode(.anyframe_type, .void_type, node);
            return rvalue(gz, ri, result, node);
        },
        .anyframe_type => {
            const return_type = try typeExpr(gz, scope, node_datas[node].rhs);
            const result = try gz.addUnNode(.anyframe_type, return_type, node);
            return rvalue(gz, ri, result, node);
        },
        .@"catch" => {
            const catch_token = main_tokens[node];
            const payload_token: ?Ast.TokenIndex = if (token_tags[catch_token + 1] == .pipe)
                catch_token + 2
            else
                null;
            no_switch_on_err: {
                const capture_token = payload_token orelse break :no_switch_on_err;
                switch (node_tags[node_datas[node].rhs]) {
                    .@"switch", .switch_comma => {},
                    else => break :no_switch_on_err,
                }
                const switch_operand = node_datas[node_datas[node].rhs].lhs;
                if (node_tags[switch_operand] != .identifier) break :no_switch_on_err;
                if (!mem.eql(u8, tree.tokenSlice(capture_token), tree.tokenSlice(main_tokens[switch_operand]))) break :no_switch_on_err;
                return switchExprErrUnion(gz, scope, ri.br(), node, .@"catch");
            }
            switch (ri.rl) {
                .ref, .ref_coerced_ty => return orelseCatchExpr(
                    gz,
                    scope,
                    ri,
                    node,
                    node_datas[node].lhs,
                    .is_non_err_ptr,
                    .err_union_payload_unsafe_ptr,
                    .err_union_code_ptr,
                    node_datas[node].rhs,
                    payload_token,
                ),
                else => return orelseCatchExpr(
                    gz,
                    scope,
                    ri,
                    node,
                    node_datas[node].lhs,
                    .is_non_err,
                    .err_union_payload_unsafe,
                    .err_union_code,
                    node_datas[node].rhs,
                    payload_token,
                ),
            }
        },
        .@"orelse" => switch (ri.rl) {
            .ref, .ref_coerced_ty => return orelseCatchExpr(
                gz,
                scope,
                ri,
                node,
                node_datas[node].lhs,
                .is_non_null_ptr,
                .optional_payload_unsafe_ptr,
                undefined,
                node_datas[node].rhs,
                null,
            ),
            else => return orelseCatchExpr(
                gz,
                scope,
                ri,
                node,
                node_datas[node].lhs,
                .is_non_null,
                .optional_payload_unsafe,
                undefined,
                node_datas[node].rhs,
                null,
            ),
        },

        .ptr_type_aligned,
        .ptr_type_sentinel,
        .ptr_type,
        .ptr_type_bit_range,
        => return ptrType(gz, scope, ri, node, tree.fullPtrType(node).?),

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
            return containerDecl(gz, scope, ri, node, tree.fullContainerDecl(&buf, node).?);
        },

        .@"break" => return breakExpr(gz, scope, node),
        .@"continue" => return continueExpr(gz, scope, node),
        .grouped_expression => return expr(gz, scope, ri, node_datas[node].lhs),
        .array_type => return arrayType(gz, scope, ri, node),
        .array_type_sentinel => return arrayTypeSentinel(gz, scope, ri, node),
        .char_literal => return charLiteral(gz, ri, node),
        .error_set_decl => return errorSetDecl(gz, ri, node),
        .array_access => return arrayAccess(gz, scope, ri, node),
        .@"comptime" => return comptimeExprAst(gz, scope, ri, node),
        .@"switch", .switch_comma => return switchExpr(gz, scope, ri.br(), node),

        .@"nosuspend" => return nosuspendExpr(gz, scope, ri, node),
        .@"suspend" => return suspendExpr(gz, scope, node),
        .@"await" => return awaitExpr(gz, scope, ri, node),
        .@"resume" => return resumeExpr(gz, scope, ri, node),

        .@"try" => return tryExpr(gz, scope, ri, node, node_datas[node].lhs),

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
            return arrayInitExpr(gz, scope, ri, node, tree.fullArrayInit(&buf, node).?);
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
            return structInitExpr(gz, scope, ri, node, tree.fullStructInit(&buf, node).?);
        },

        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => {
            var buf: [1]Ast.Node.Index = undefined;
            return fnProtoExpr(gz, scope, ri, node, tree.fullFnProto(&buf, node).?);
        },
    }
}

fn nosuspendExpr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const body_node = node_datas[node].lhs;
    assert(body_node != 0);
    if (gz.nosuspend_node != 0) {
        try astgen.appendErrorNodeNotes(node, "redundant nosuspend block", .{}, &[_]u32{
            try astgen.errNoteNode(gz.nosuspend_node, "other nosuspend block here", .{}),
        });
    }
    gz.nosuspend_node = node;
    defer gz.nosuspend_node = 0;
    return expr(gz, scope, ri, body_node);
}

fn suspendExpr(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const gpa = astgen.gpa;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const body_node = node_datas[node].lhs;

    if (gz.nosuspend_node != 0) {
        return astgen.failNodeNotes(node, "suspend inside nosuspend block", .{}, &[_]u32{
            try astgen.errNoteNode(gz.nosuspend_node, "nosuspend block here", .{}),
        });
    }
    if (gz.suspend_node != 0) {
        return astgen.failNodeNotes(node, "cannot suspend inside suspend block", .{}, &[_]u32{
            try astgen.errNoteNode(gz.suspend_node, "other suspend block here", .{}),
        });
    }
    assert(body_node != 0);

    const suspend_inst = try gz.makeBlockInst(.suspend_block, node);
    try gz.instructions.append(gpa, suspend_inst);

    var suspend_scope = gz.makeSubBlock(scope);
    suspend_scope.suspend_node = node;
    defer suspend_scope.unstack();

    const body_result = try fullBodyExpr(&suspend_scope, &suspend_scope.base, .{ .rl = .none }, body_node);
    if (!gz.refIsNoReturn(body_result)) {
        _ = try suspend_scope.addBreak(.break_inline, suspend_inst, .void_value);
    }
    try suspend_scope.setBlockBody(suspend_inst);

    return suspend_inst.toRef();
}

fn awaitExpr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const rhs_node = node_datas[node].lhs;

    if (gz.suspend_node != 0) {
        return astgen.failNodeNotes(node, "cannot await inside suspend block", .{}, &[_]u32{
            try astgen.errNoteNode(gz.suspend_node, "suspend block here", .{}),
        });
    }
    const operand = try expr(gz, scope, .{ .rl = .ref }, rhs_node);
    const result = if (gz.nosuspend_node != 0)
        try gz.addExtendedPayload(.await_nosuspend, Zir.Inst.UnNode{
            .node = gz.nodeIndexToRelative(node),
            .operand = operand,
        })
    else
        try gz.addUnNode(.@"await", operand, node);

    return rvalue(gz, ri, result, node);
}

fn resumeExpr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const rhs_node = node_datas[node].lhs;
    const operand = try expr(gz, scope, .{ .rl = .ref }, rhs_node);
    const result = try gz.addUnNode(.@"resume", operand, node);
    return rvalue(gz, ri, result, node);
}

fn fnProtoExpr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    fn_proto: Ast.full.FnProto,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const token_tags = tree.tokens.items(.tag);

    if (fn_proto.name_token) |some| {
        return astgen.failTok(some, "function type cannot have a name", .{});
    }

    const is_extern = blk: {
        const maybe_extern_token = fn_proto.extern_export_inline_token orelse break :blk false;
        break :blk token_tags[maybe_extern_token] == .keyword_extern;
    };
    assert(!is_extern);

    var block_scope = gz.makeSubBlock(scope);
    defer block_scope.unstack();

    const block_inst = try gz.makeBlockInst(.block_inline, node);

    var noalias_bits: u32 = 0;
    const is_var_args = is_var_args: {
        var param_type_i: usize = 0;
        var it = fn_proto.iterate(tree);
        while (it.next()) |param| : (param_type_i += 1) {
            const is_comptime = if (param.comptime_noalias) |token| switch (token_tags[token]) {
                .keyword_noalias => is_comptime: {
                    noalias_bits |= @as(u32, 1) << (std.math.cast(u5, param_type_i) orelse
                        return astgen.failTok(token, "this compiler implementation only supports 'noalias' on the first 32 parameters", .{}));
                    break :is_comptime false;
                },
                .keyword_comptime => true,
                else => false,
            } else false;

            const is_anytype = if (param.anytype_ellipsis3) |token| blk: {
                switch (token_tags[token]) {
                    .keyword_anytype => break :blk true,
                    .ellipsis3 => break :is_var_args true,
                    else => unreachable,
                }
            } else false;

            const param_name = if (param.name_token) |name_token| blk: {
                if (mem.eql(u8, "_", tree.tokenSlice(name_token)))
                    break :blk .empty;

                break :blk try astgen.identAsString(name_token);
            } else .empty;

            if (is_anytype) {
                const name_token = param.name_token orelse param.anytype_ellipsis3.?;

                const tag: Zir.Inst.Tag = if (is_comptime)
                    .param_anytype_comptime
                else
                    .param_anytype;
                _ = try block_scope.addStrTok(tag, param_name, name_token);
            } else {
                const param_type_node = param.type_expr;
                assert(param_type_node != 0);
                var param_gz = block_scope.makeSubBlock(scope);
                defer param_gz.unstack();
                const param_type = try fullBodyExpr(&param_gz, scope, coerced_type_ri, param_type_node);
                const param_inst_expected: Zir.Inst.Index = @enumFromInt(astgen.instructions.len + 1);
                _ = try param_gz.addBreakWithSrcNode(.break_inline, param_inst_expected, param_type, param_type_node);
                const main_tokens = tree.nodes.items(.main_token);
                const name_token = param.name_token orelse main_tokens[param_type_node];
                const tag: Zir.Inst.Tag = if (is_comptime) .param_comptime else .param;
                const param_inst = try block_scope.addParam(&param_gz, tag, name_token, param_name, param.first_doc_comment);
                assert(param_inst_expected == param_inst);
            }
        }
        break :is_var_args false;
    };

    if (fn_proto.ast.align_expr != 0) {
        return astgen.failNode(fn_proto.ast.align_expr, "function type cannot have an alignment", .{});
    }

    if (fn_proto.ast.addrspace_expr != 0) {
        return astgen.failNode(fn_proto.ast.addrspace_expr, "function type cannot have an addrspace", .{});
    }

    if (fn_proto.ast.section_expr != 0) {
        return astgen.failNode(fn_proto.ast.section_expr, "function type cannot have a linksection", .{});
    }

    const cc: Zir.Inst.Ref = if (fn_proto.ast.callconv_expr != 0)
        try expr(
            &block_scope,
            scope,
            .{ .rl = .{ .coerced_ty = .calling_convention_type } },
            fn_proto.ast.callconv_expr,
        )
    else
        Zir.Inst.Ref.none;

    const maybe_bang = tree.firstToken(fn_proto.ast.return_type) - 1;
    const is_inferred_error = token_tags[maybe_bang] == .bang;
    if (is_inferred_error) {
        return astgen.failTok(maybe_bang, "function type cannot have an inferred error set", .{});
    }
    const ret_ty = try expr(&block_scope, scope, coerced_type_ri, fn_proto.ast.return_type);

    const result = try block_scope.addFunc(.{
        .src_node = fn_proto.ast.proto_node,

        .cc_ref = cc,
        .cc_gz = null,
        .align_ref = .none,
        .align_gz = null,
        .ret_ref = ret_ty,
        .ret_gz = null,
        .section_ref = .none,
        .section_gz = null,
        .addrspace_ref = .none,
        .addrspace_gz = null,

        .param_block = block_inst,
        .body_gz = null,
        .lib_name = .empty,
        .is_var_args = is_var_args,
        .is_inferred_error = false,
        .is_test = false,
        .is_extern = false,
        .is_noinline = false,
        .noalias_bits = noalias_bits,
    });

    _ = try block_scope.addBreak(.break_inline, block_inst, result);
    try block_scope.setBlockBody(block_inst);
    try gz.instructions.append(astgen.gpa, block_inst);

    return rvalue(gz, ri, block_inst.toRef(), fn_proto.ast.proto_node);
}

fn arrayInitExpr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    array_init: Ast.full.ArrayInit,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);

    assert(array_init.ast.elements.len != 0); // Otherwise it would be struct init.

    const array_ty: Zir.Inst.Ref, const elem_ty: Zir.Inst.Ref = inst: {
        if (array_init.ast.type_expr == 0) break :inst .{ .none, .none };

        infer: {
            const array_type: Ast.full.ArrayType = tree.fullArrayType(array_init.ast.type_expr) orelse break :infer;
            // This intentionally does not support `@"_"` syntax.
            if (node_tags[array_type.ast.elem_count] == .identifier and
                mem.eql(u8, tree.tokenSlice(main_tokens[array_type.ast.elem_count]), "_"))
            {
                const len_inst = try gz.addInt(array_init.ast.elements.len);
                const elem_type = try typeExpr(gz, scope, array_type.ast.elem_type);
                if (array_type.ast.sentinel == 0) {
                    const array_type_inst = try gz.addPlNode(.array_type, array_init.ast.type_expr, Zir.Inst.Bin{
                        .lhs = len_inst,
                        .rhs = elem_type,
                    });
                    break :inst .{ array_type_inst, elem_type };
                } else {
                    const sentinel = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = elem_type } }, array_type.ast.sentinel);
                    const array_type_inst = try gz.addPlNode(
                        .array_type_sentinel,
                        array_init.ast.type_expr,
                        Zir.Inst.ArrayTypeSentinel{
                            .len = len_inst,
                            .elem_type = elem_type,
                            .sentinel = sentinel,
                        },
                    );
                    break :inst .{ array_type_inst, elem_type };
                }
            }
        }
        const array_type_inst = try typeExpr(gz, scope, array_init.ast.type_expr);
        _ = try gz.addPlNode(.validate_array_init_ty, node, Zir.Inst.ArrayInit{
            .ty = array_type_inst,
            .init_count = @intCast(array_init.ast.elements.len),
        });
        break :inst .{ array_type_inst, .none };
    };

    if (array_ty != .none) {
        // Typed inits do not use RLS for language simplicity.
        switch (ri.rl) {
            .discard => {
                if (elem_ty != .none) {
                    const elem_ri: ResultInfo = .{ .rl = .{ .ty = elem_ty } };
                    for (array_init.ast.elements) |elem_init| {
                        _ = try expr(gz, scope, elem_ri, elem_init);
                    }
                } else {
                    for (array_init.ast.elements, 0..) |elem_init, i| {
                        const this_elem_ty = try gz.add(.{
                            .tag = .array_init_elem_type,
                            .data = .{ .bin = .{
                                .lhs = array_ty,
                                .rhs = @enumFromInt(i),
                            } },
                        });
                        _ = try expr(gz, scope, .{ .rl = .{ .ty = this_elem_ty } }, elem_init);
                    }
                }
                return .void_value;
            },
            .ref => return arrayInitExprTyped(gz, scope, node, array_init.ast.elements, array_ty, elem_ty, true),
            else => {
                const array_inst = try arrayInitExprTyped(gz, scope, node, array_init.ast.elements, array_ty, elem_ty, false);
                return rvalue(gz, ri, array_inst, node);
            },
        }
    }

    switch (ri.rl) {
        .none => return arrayInitExprAnon(gz, scope, node, array_init.ast.elements),
        .discard => {
            for (array_init.ast.elements) |elem_init| {
                _ = try expr(gz, scope, .{ .rl = .discard }, elem_init);
            }
            return Zir.Inst.Ref.void_value;
        },
        .ref => {
            const result = try arrayInitExprAnon(gz, scope, node, array_init.ast.elements);
            return gz.addUnTok(.ref, result, tree.firstToken(node));
        },
        .ref_coerced_ty => |ptr_ty_inst| {
            const dest_arr_ty_inst = try gz.addPlNode(.validate_array_init_ref_ty, node, Zir.Inst.ArrayInitRefTy{
                .ptr_ty = ptr_ty_inst,
                .elem_count = @intCast(array_init.ast.elements.len),
            });
            return arrayInitExprTyped(gz, scope, node, array_init.ast.elements, dest_arr_ty_inst, .none, true);
        },
        .ty, .coerced_ty => |result_ty_inst| {
            _ = try gz.addPlNode(.validate_array_init_result_ty, node, Zir.Inst.ArrayInit{
                .ty = result_ty_inst,
                .init_count = @intCast(array_init.ast.elements.len),
            });
            return arrayInitExprTyped(gz, scope, node, array_init.ast.elements, result_ty_inst, .none, false);
        },
        .ptr => |ptr| {
            try arrayInitExprPtr(gz, scope, node, array_init.ast.elements, ptr.inst);
            return .void_value;
        },
        .inferred_ptr => {
            // We can't get elem pointers of an untyped inferred alloc, so must perform a
            // standard anonymous initialization followed by an rvalue store.
            // See corresponding logic in structInitExpr.
            const result = try arrayInitExprAnon(gz, scope, node, array_init.ast.elements);
            return rvalue(gz, ri, result, node);
        },
        .destructure => |destructure| {
            // Untyped init - destructure directly into result pointers
            if (array_init.ast.elements.len != destructure.components.len) {
                return astgen.failNodeNotes(node, "expected {} elements for destructure, found {}", .{
                    destructure.components.len,
                    array_init.ast.elements.len,
                }, &.{
                    try astgen.errNoteNode(destructure.src_node, "result destructured here", .{}),
                });
            }
            for (array_init.ast.elements, destructure.components) |elem_init, ds_comp| {
                const elem_ri: ResultInfo = .{ .rl = switch (ds_comp) {
                    .typed_ptr => |ptr_rl| .{ .ptr = ptr_rl },
                    .inferred_ptr => |ptr_inst| .{ .inferred_ptr = ptr_inst },
                    .discard => .discard,
                } };
                _ = try expr(gz, scope, elem_ri, elem_init);
            }
            return .void_value;
        },
    }
}

/// An array initialization expression using an `array_init_anon` instruction.
fn arrayInitExprAnon(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    elements: []const Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;

    const payload_index = try addExtra(astgen, Zir.Inst.MultiOp{
        .operands_len = @intCast(elements.len),
    });
    var extra_index = try reserveExtra(astgen, elements.len);

    for (elements) |elem_init| {
        const elem_ref = try expr(gz, scope, .{ .rl = .none }, elem_init);
        astgen.extra.items[extra_index] = @intFromEnum(elem_ref);
        extra_index += 1;
    }
    return try gz.addPlNodePayloadIndex(.array_init_anon, node, payload_index);
}

/// An array initialization expression using an `array_init` or `array_init_ref` instruction.
fn arrayInitExprTyped(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    elements: []const Ast.Node.Index,
    ty_inst: Zir.Inst.Ref,
    maybe_elem_ty_inst: Zir.Inst.Ref,
    is_ref: bool,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;

    const len = elements.len + 1; // +1 for type
    const payload_index = try addExtra(astgen, Zir.Inst.MultiOp{
        .operands_len = @intCast(len),
    });
    var extra_index = try reserveExtra(astgen, len);
    astgen.extra.items[extra_index] = @intFromEnum(ty_inst);
    extra_index += 1;

    if (maybe_elem_ty_inst != .none) {
        const elem_ri: ResultInfo = .{ .rl = .{ .coerced_ty = maybe_elem_ty_inst } };
        for (elements) |elem_init| {
            const elem_inst = try expr(gz, scope, elem_ri, elem_init);
            astgen.extra.items[extra_index] = @intFromEnum(elem_inst);
            extra_index += 1;
        }
    } else {
        for (elements, 0..) |elem_init, i| {
            const ri: ResultInfo = .{ .rl = .{ .coerced_ty = try gz.add(.{
                .tag = .array_init_elem_type,
                .data = .{ .bin = .{
                    .lhs = ty_inst,
                    .rhs = @enumFromInt(i),
                } },
            }) } };

            const elem_inst = try expr(gz, scope, ri, elem_init);
            astgen.extra.items[extra_index] = @intFromEnum(elem_inst);
            extra_index += 1;
        }
    }

    const tag: Zir.Inst.Tag = if (is_ref) .array_init_ref else .array_init;
    return try gz.addPlNodePayloadIndex(tag, node, payload_index);
}

/// An array initialization expression using element pointers.
fn arrayInitExprPtr(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    elements: []const Ast.Node.Index,
    ptr_inst: Zir.Inst.Ref,
) InnerError!void {
    const astgen = gz.astgen;

    const array_ptr_inst = try gz.addUnNode(.opt_eu_base_ptr_init, ptr_inst, node);

    const payload_index = try addExtra(astgen, Zir.Inst.Block{
        .body_len = @intCast(elements.len),
    });
    var extra_index = try reserveExtra(astgen, elements.len);

    for (elements, 0..) |elem_init, i| {
        const elem_ptr_inst = try gz.addPlNode(.array_init_elem_ptr, elem_init, Zir.Inst.ElemPtrImm{
            .ptr = array_ptr_inst,
            .index = @intCast(i),
        });
        astgen.extra.items[extra_index] = @intFromEnum(elem_ptr_inst.toIndex().?);
        extra_index += 1;
        _ = try expr(gz, scope, .{ .rl = .{ .ptr = .{ .inst = elem_ptr_inst } } }, elem_init);
    }

    _ = try gz.addPlNodePayloadIndex(.validate_ptr_array_init, node, payload_index);
}

fn structInitExpr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    struct_init: Ast.full.StructInit,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;

    if (struct_init.ast.type_expr == 0) {
        if (struct_init.ast.fields.len == 0) {
            // Anonymous init with no fields.
            switch (ri.rl) {
                .discard => return .void_value,
                .ref_coerced_ty => |ptr_ty_inst| return gz.addUnNode(.struct_init_empty_ref_result, ptr_ty_inst, node),
                .ty, .coerced_ty => |ty_inst| return gz.addUnNode(.struct_init_empty_result, ty_inst, node),
                .ptr => {
                    // TODO: should we modify this to use RLS for the field stores here?
                    const ty_inst = (try ri.rl.resultType(gz, node)).?;
                    const val = try gz.addUnNode(.struct_init_empty_result, ty_inst, node);
                    return rvalue(gz, ri, val, node);
                },
                .none, .ref, .inferred_ptr => {
                    return rvalue(gz, ri, .empty_struct, node);
                },
                .destructure => |destructure| {
                    return astgen.failNodeNotes(node, "empty initializer cannot be destructured", .{}, &.{
                        try astgen.errNoteNode(destructure.src_node, "result destructured here", .{}),
                    });
                },
            }
        }
    } else array: {
        const node_tags = tree.nodes.items(.tag);
        const main_tokens = tree.nodes.items(.main_token);
        const array_type: Ast.full.ArrayType = tree.fullArrayType(struct_init.ast.type_expr) orelse {
            if (struct_init.ast.fields.len == 0) {
                const ty_inst = try typeExpr(gz, scope, struct_init.ast.type_expr);
                const result = try gz.addUnNode(.struct_init_empty, ty_inst, node);
                return rvalue(gz, ri, result, node);
            }
            break :array;
        };
        const is_inferred_array_len = node_tags[array_type.ast.elem_count] == .identifier and
            // This intentionally does not support `@"_"` syntax.
            mem.eql(u8, tree.tokenSlice(main_tokens[array_type.ast.elem_count]), "_");
        if (struct_init.ast.fields.len == 0) {
            if (is_inferred_array_len) {
                const elem_type = try typeExpr(gz, scope, array_type.ast.elem_type);
                const array_type_inst = if (array_type.ast.sentinel == 0) blk: {
                    break :blk try gz.addPlNode(.array_type, struct_init.ast.type_expr, Zir.Inst.Bin{
                        .lhs = .zero_usize,
                        .rhs = elem_type,
                    });
                } else blk: {
                    const sentinel = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = elem_type } }, array_type.ast.sentinel);
                    break :blk try gz.addPlNode(
                        .array_type_sentinel,
                        struct_init.ast.type_expr,
                        Zir.Inst.ArrayTypeSentinel{
                            .len = .zero_usize,
                            .elem_type = elem_type,
                            .sentinel = sentinel,
                        },
                    );
                };
                const result = try gz.addUnNode(.struct_init_empty, array_type_inst, node);
                return rvalue(gz, ri, result, node);
            }
            const ty_inst = try typeExpr(gz, scope, struct_init.ast.type_expr);
            const result = try gz.addUnNode(.struct_init_empty, ty_inst, node);
            return rvalue(gz, ri, result, node);
        } else {
            return astgen.failNode(
                struct_init.ast.type_expr,
                "initializing array with struct syntax",
                .{},
            );
        }
    }

    {
        var sfba = std.heap.stackFallback(256, astgen.arena);
        const sfba_allocator = sfba.get();

        var duplicate_names = std.AutoArrayHashMap(Zir.NullTerminatedString, ArrayListUnmanaged(Ast.TokenIndex)).init(sfba_allocator);
        try duplicate_names.ensureTotalCapacity(@intCast(struct_init.ast.fields.len));

        // When there aren't errors, use this to avoid a second iteration.
        var any_duplicate = false;

        for (struct_init.ast.fields) |field| {
            const name_token = tree.firstToken(field) - 2;
            const name_index = try astgen.identAsString(name_token);

            const gop = try duplicate_names.getOrPut(name_index);

            if (gop.found_existing) {
                try gop.value_ptr.append(sfba_allocator, name_token);
                any_duplicate = true;
            } else {
                gop.value_ptr.* = .{};
                try gop.value_ptr.append(sfba_allocator, name_token);
            }
        }

        if (any_duplicate) {
            var it = duplicate_names.iterator();

            while (it.next()) |entry| {
                const record = entry.value_ptr.*;
                if (record.items.len > 1) {
                    var error_notes = std.ArrayList(u32).init(astgen.arena);

                    for (record.items[1..]) |duplicate| {
                        try error_notes.append(try astgen.errNoteTok(duplicate, "duplicate name here", .{}));
                    }

                    try error_notes.append(try astgen.errNoteNode(node, "struct declared here", .{}));

                    try astgen.appendErrorTokNotes(
                        record.items[0],
                        "duplicate struct field name",
                        .{},
                        error_notes.items,
                    );
                }
            }

            return error.AnalysisFail;
        }
    }

    if (struct_init.ast.type_expr != 0) {
        // Typed inits do not use RLS for language simplicity.
        const ty_inst = try typeExpr(gz, scope, struct_init.ast.type_expr);
        _ = try gz.addUnNode(.validate_struct_init_ty, ty_inst, node);
        switch (ri.rl) {
            .ref => return structInitExprTyped(gz, scope, node, struct_init, ty_inst, true),
            else => {
                const struct_inst = try structInitExprTyped(gz, scope, node, struct_init, ty_inst, false);
                return rvalue(gz, ri, struct_inst, node);
            },
        }
    }

    switch (ri.rl) {
        .none => return structInitExprAnon(gz, scope, node, struct_init),
        .discard => {
            // Even if discarding we must perform side-effects.
            for (struct_init.ast.fields) |field_init| {
                _ = try expr(gz, scope, .{ .rl = .discard }, field_init);
            }
            return .void_value;
        },
        .ref => {
            const result = try structInitExprAnon(gz, scope, node, struct_init);
            return gz.addUnTok(.ref, result, tree.firstToken(node));
        },
        .ref_coerced_ty => |ptr_ty_inst| {
            const result_ty_inst = try gz.addUnNode(.elem_type, ptr_ty_inst, node);
            _ = try gz.addUnNode(.validate_struct_init_result_ty, result_ty_inst, node);
            return structInitExprTyped(gz, scope, node, struct_init, result_ty_inst, true);
        },
        .ty, .coerced_ty => |result_ty_inst| {
            _ = try gz.addUnNode(.validate_struct_init_result_ty, result_ty_inst, node);
            return structInitExprTyped(gz, scope, node, struct_init, result_ty_inst, false);
        },
        .ptr => |ptr| {
            try structInitExprPtr(gz, scope, node, struct_init, ptr.inst);
            return .void_value;
        },
        .inferred_ptr => {
            // We can't get field pointers of an untyped inferred alloc, so must perform a
            // standard anonymous initialization followed by an rvalue store.
            // See corresponding logic in arrayInitExpr.
            const struct_inst = try structInitExprAnon(gz, scope, node, struct_init);
            return rvalue(gz, ri, struct_inst, node);
        },
        .destructure => |destructure| {
            // This is an untyped init, so is an actual struct, which does
            // not support destructuring.
            return astgen.failNodeNotes(node, "struct value cannot be destructured", .{}, &.{
                try astgen.errNoteNode(destructure.src_node, "result destructured here", .{}),
            });
        },
    }
}

/// A struct initialization expression using a `struct_init_anon` instruction.
fn structInitExprAnon(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    struct_init: Ast.full.StructInit,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;

    const payload_index = try addExtra(astgen, Zir.Inst.StructInitAnon{
        .fields_len = @intCast(struct_init.ast.fields.len),
    });
    const field_size = @typeInfo(Zir.Inst.StructInitAnon.Item).Struct.fields.len;
    var extra_index: usize = try reserveExtra(astgen, struct_init.ast.fields.len * field_size);

    for (struct_init.ast.fields) |field_init| {
        const name_token = tree.firstToken(field_init) - 2;
        const str_index = try astgen.identAsString(name_token);
        setExtra(astgen, extra_index, Zir.Inst.StructInitAnon.Item{
            .field_name = str_index,
            .init = try expr(gz, scope, .{ .rl = .none }, field_init),
        });
        extra_index += field_size;
    }

    return gz.addPlNodePayloadIndex(.struct_init_anon, node, payload_index);
}

/// A struct initialization expression using a `struct_init` or `struct_init_ref` instruction.
fn structInitExprTyped(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    struct_init: Ast.full.StructInit,
    ty_inst: Zir.Inst.Ref,
    is_ref: bool,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;

    const payload_index = try addExtra(astgen, Zir.Inst.StructInit{
        .fields_len = @intCast(struct_init.ast.fields.len),
    });
    const field_size = @typeInfo(Zir.Inst.StructInit.Item).Struct.fields.len;
    var extra_index: usize = try reserveExtra(astgen, struct_init.ast.fields.len * field_size);

    for (struct_init.ast.fields) |field_init| {
        const name_token = tree.firstToken(field_init) - 2;
        const str_index = try astgen.identAsString(name_token);
        const field_ty_inst = try gz.addPlNode(.struct_init_field_type, field_init, Zir.Inst.FieldType{
            .container_type = ty_inst,
            .name_start = str_index,
        });
        setExtra(astgen, extra_index, Zir.Inst.StructInit.Item{
            .field_type = field_ty_inst.toIndex().?,
            .init = try expr(gz, scope, .{ .rl = .{ .coerced_ty = field_ty_inst } }, field_init),
        });
        extra_index += field_size;
    }

    const tag: Zir.Inst.Tag = if (is_ref) .struct_init_ref else .struct_init;
    return gz.addPlNodePayloadIndex(tag, node, payload_index);
}

/// A struct initialization expression using field pointers.
fn structInitExprPtr(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    struct_init: Ast.full.StructInit,
    ptr_inst: Zir.Inst.Ref,
) InnerError!void {
    const astgen = gz.astgen;
    const tree = astgen.tree;

    const struct_ptr_inst = try gz.addUnNode(.opt_eu_base_ptr_init, ptr_inst, node);

    const payload_index = try addExtra(astgen, Zir.Inst.Block{
        .body_len = @intCast(struct_init.ast.fields.len),
    });
    var extra_index = try reserveExtra(astgen, struct_init.ast.fields.len);

    for (struct_init.ast.fields) |field_init| {
        const name_token = tree.firstToken(field_init) - 2;
        const str_index = try astgen.identAsString(name_token);
        const field_ptr = try gz.addPlNode(.struct_init_field_ptr, field_init, Zir.Inst.Field{
            .lhs = struct_ptr_inst,
            .field_name_start = str_index,
        });
        astgen.extra.items[extra_index] = @intFromEnum(field_ptr.toIndex().?);
        extra_index += 1;
        _ = try expr(gz, scope, .{ .rl = .{ .ptr = .{ .inst = field_ptr } } }, field_init);
    }

    _ = try gz.addPlNodePayloadIndex(.validate_ptr_struct_init, node, payload_index);
}

/// This explicitly calls expr in a comptime scope by wrapping it in a `block_comptime` if
/// necessary. It should be used whenever we need to force compile-time evaluation of something,
/// such as a type.
/// The function corresponding to `comptime` expression syntax is `comptimeExprAst`.
fn comptimeExpr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    if (gz.is_comptime) {
        // No need to change anything!
        return expr(gz, scope, ri, node);
    }

    // There's an optimization here: if the body will be evaluated at comptime regardless, there's
    // no need to wrap it in a block. This is hard to determine in general, but we can identify a
    // common subset of trivially comptime expressions to take down the size of the ZIR a bit.
    const tree = gz.astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const node_tags = tree.nodes.items(.tag);
    switch (node_tags[node]) {
        // Any identifier in `primitive_instrs` is trivially comptime. In particular, this includes
        // some common types, so we can elide `block_comptime` for a few common type annotations.
        .identifier => {
            const ident_token = main_tokens[node];
            const ident_name_raw = tree.tokenSlice(ident_token);
            if (primitive_instrs.get(ident_name_raw)) |zir_const_ref| {
                // No need to worry about result location here, we're not creating a comptime block!
                return rvalue(gz, ri, zir_const_ref, node);
            }
        },

        // We can also avoid the block for a few trivial AST tags which are always comptime-known.
        .number_literal, .string_literal, .multiline_string_literal, .enum_literal, .error_value => {
            // No need to worry about result location here, we're not creating a comptime block!
            return expr(gz, scope, ri, node);
        },

        // Lastly, for labelled blocks, avoid emitting a labelled block directly inside this
        // comptime block, because that would be silly! Note that we don't bother doing this for
        // unlabelled blocks, since they don't generate blocks at comptime anyway (see `blockExpr`).
        .block_two, .block_two_semicolon, .block, .block_semicolon => {
            const token_tags = tree.tokens.items(.tag);
            const lbrace = main_tokens[node];
            // Careful! We can't pass in the real result location here, since it may
            // refer to runtime memory. A runtime-to-comptime boundary has to remove
            // result location information, compute the result, and copy it to the true
            // result location at runtime. We do this below as well.
            const ty_only_ri: ResultInfo = .{
                .ctx = ri.ctx,
                .rl = if (try ri.rl.resultType(gz, node)) |res_ty|
                    .{ .coerced_ty = res_ty }
                else
                    .none,
            };
            if (token_tags[lbrace - 1] == .colon and
                token_tags[lbrace - 2] == .identifier)
            {
                const node_datas = tree.nodes.items(.data);
                switch (node_tags[node]) {
                    .block_two, .block_two_semicolon => {
                        const stmts: [2]Ast.Node.Index = .{ node_datas[node].lhs, node_datas[node].rhs };
                        const stmt_slice = if (stmts[0] == 0)
                            stmts[0..0]
                        else if (stmts[1] == 0)
                            stmts[0..1]
                        else
                            stmts[0..2];

                        const block_ref = try labeledBlockExpr(gz, scope, ty_only_ri, node, stmt_slice, true);
                        return rvalue(gz, ri, block_ref, node);
                    },
                    .block, .block_semicolon => {
                        const stmts = tree.extra_data[node_datas[node].lhs..node_datas[node].rhs];
                        // Replace result location and copy back later - see above.
                        const block_ref = try labeledBlockExpr(gz, scope, ty_only_ri, node, stmts, true);
                        return rvalue(gz, ri, block_ref, node);
                    },
                    else => unreachable,
                }
            }
        },

        // In other cases, we don't optimize anything - we need a wrapper comptime block.
        else => {},
    }

    var block_scope = gz.makeSubBlock(scope);
    block_scope.is_comptime = true;
    defer block_scope.unstack();

    const block_inst = try gz.makeBlockInst(.block_comptime, node);
    // Replace result location and copy back later - see above.
    const ty_only_ri: ResultInfo = .{
        .ctx = ri.ctx,
        .rl = if (try ri.rl.resultType(gz, node)) |res_ty|
            .{ .coerced_ty = res_ty }
        else
            .none,
    };
    const block_result = try fullBodyExpr(&block_scope, scope, ty_only_ri, node);
    if (!gz.refIsNoReturn(block_result)) {
        _ = try block_scope.addBreak(.@"break", block_inst, block_result);
    }
    try block_scope.setBlockBody(block_inst);
    try gz.instructions.append(gz.astgen.gpa, block_inst);

    return rvalue(gz, ri, block_inst.toRef(), node);
}

/// This one is for an actual `comptime` syntax, and will emit a compile error if
/// the scope is already known to be comptime-evaluated.
/// See `comptimeExpr` for the helper function for calling expr in a comptime scope.
fn comptimeExprAst(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    if (gz.is_comptime) {
        return astgen.failNode(node, "redundant comptime keyword in already comptime scope", .{});
    }
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const body_node = node_datas[node].lhs;
    return comptimeExpr(gz, scope, ri, body_node);
}

/// Restore the error return trace index. Performs the restore only if the result is a non-error or
/// if the result location is a non-error-handling expression.
fn restoreErrRetIndex(
    gz: *GenZir,
    bt: GenZir.BranchTarget,
    ri: ResultInfo,
    node: Ast.Node.Index,
    result: Zir.Inst.Ref,
) !void {
    const op = switch (nodeMayEvalToError(gz.astgen.tree, node)) {
        .always => return, // never restore/pop
        .never => .none, // always restore/pop
        .maybe => switch (ri.ctx) {
            .error_handling_expr, .@"return", .fn_arg, .const_init => switch (ri.rl) {
                .ptr => |ptr_res| try gz.addUnNode(.load, ptr_res.inst, node),
                .inferred_ptr => blk: {
                    // This is a terrible workaround for Sema's inability to load from a .alloc_inferred ptr
                    // before its type has been resolved. There is no valid operand to use here, so error
                    // traces will be popped prematurely.
                    // TODO: Update this to do a proper load from the rl_ptr, once Sema can support it.
                    break :blk .none;
                },
                .destructure => return, // value must be a tuple or array, so never restore/pop
                else => result,
            },
            else => .none, // always restore/pop
        },
    };
    _ = try gz.addRestoreErrRetIndex(bt, .{ .if_non_error = op }, node);
}

fn breakExpr(parent_gz: *GenZir, parent_scope: *Scope, node: Ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const break_label = node_datas[node].lhs;
    const rhs = node_datas[node].rhs;

    // Look for the label in the scope.
    var scope = parent_scope;
    while (true) {
        switch (scope.tag) {
            .gen_zir => {
                const block_gz = scope.cast(GenZir).?;

                if (block_gz.cur_defer_node != 0) {
                    // We are breaking out of a `defer` block.
                    return astgen.failNodeNotes(node, "cannot break out of defer expression", .{}, &.{
                        try astgen.errNoteNode(
                            block_gz.cur_defer_node,
                            "defer expression here",
                            .{},
                        ),
                    });
                }

                const block_inst = blk: {
                    if (break_label != 0) {
                        if (block_gz.label) |*label| {
                            if (try astgen.tokenIdentEql(label.token, break_label)) {
                                label.used = true;
                                break :blk label.block_inst;
                            }
                        }
                    } else if (block_gz.break_block.unwrap()) |i| {
                        break :blk i;
                    }
                    // If not the target, start over with the parent
                    scope = block_gz.parent;
                    continue;
                };
                // If we made it here, this block is the target of the break expr

                const break_tag: Zir.Inst.Tag = if (block_gz.is_inline)
                    .break_inline
                else
                    .@"break";

                if (rhs == 0) {
                    _ = try rvalue(parent_gz, block_gz.break_result_info, .void_value, node);

                    try genDefers(parent_gz, scope, parent_scope, .normal_only);

                    // As our last action before the break, "pop" the error trace if needed
                    if (!block_gz.is_comptime)
                        _ = try parent_gz.addRestoreErrRetIndex(.{ .block = block_inst }, .always, node);

                    _ = try parent_gz.addBreak(break_tag, block_inst, .void_value);
                    return Zir.Inst.Ref.unreachable_value;
                }

                const operand = try reachableExpr(parent_gz, parent_scope, block_gz.break_result_info, rhs, node);

                try genDefers(parent_gz, scope, parent_scope, .normal_only);

                // As our last action before the break, "pop" the error trace if needed
                if (!block_gz.is_comptime)
                    try restoreErrRetIndex(parent_gz, .{ .block = block_inst }, block_gz.break_result_info, rhs, operand);

                switch (block_gz.break_result_info.rl) {
                    .ptr => {
                        // In this case we don't have any mechanism to intercept it;
                        // we assume the result location is written, and we break with void.
                        _ = try parent_gz.addBreak(break_tag, block_inst, .void_value);
                    },
                    .discard => {
                        _ = try parent_gz.addBreak(break_tag, block_inst, .void_value);
                    },
                    else => {
                        _ = try parent_gz.addBreakWithSrcNode(break_tag, block_inst, operand, rhs);
                    },
                }
                return Zir.Inst.Ref.unreachable_value;
            },
            .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
            .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
            .namespace => break,
            .defer_normal, .defer_error => scope = scope.cast(Scope.Defer).?.parent,
            .top => unreachable,
        }
    }
    if (break_label != 0) {
        const label_name = try astgen.identifierTokenString(break_label);
        return astgen.failTok(break_label, "label not found: '{s}'", .{label_name});
    } else {
        return astgen.failNode(node, "break expression outside loop", .{});
    }
}

fn continueExpr(parent_gz: *GenZir, parent_scope: *Scope, node: Ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const break_label = node_datas[node].lhs;

    // Look for the label in the scope.
    var scope = parent_scope;
    while (true) {
        switch (scope.tag) {
            .gen_zir => {
                const gen_zir = scope.cast(GenZir).?;

                if (gen_zir.cur_defer_node != 0) {
                    return astgen.failNodeNotes(node, "cannot continue out of defer expression", .{}, &.{
                        try astgen.errNoteNode(
                            gen_zir.cur_defer_node,
                            "defer expression here",
                            .{},
                        ),
                    });
                }
                const continue_block = gen_zir.continue_block.unwrap() orelse {
                    scope = gen_zir.parent;
                    continue;
                };
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

                const break_tag: Zir.Inst.Tag = if (gen_zir.is_inline)
                    .break_inline
                else
                    .@"break";
                if (break_tag == .break_inline) {
                    _ = try parent_gz.addUnNode(.check_comptime_control_flow, continue_block.toRef(), node);
                }

                // As our last action before the continue, "pop" the error trace if needed
                if (!gen_zir.is_comptime)
                    _ = try parent_gz.addRestoreErrRetIndex(.{ .block = continue_block }, .always, node);

                _ = try parent_gz.addBreak(break_tag, continue_block, .void_value);
                return Zir.Inst.Ref.unreachable_value;
            },
            .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
            .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
            .defer_normal => {
                const defer_scope = scope.cast(Scope.Defer).?;
                scope = defer_scope.parent;
                try parent_gz.addDefer(defer_scope.index, defer_scope.len);
            },
            .defer_error => scope = scope.cast(Scope.Defer).?.parent,
            .namespace => break,
            .top => unreachable,
        }
    }
    if (break_label != 0) {
        const label_name = try astgen.identifierTokenString(break_label);
        return astgen.failTok(break_label, "label not found: '{s}'", .{label_name});
    } else {
        return astgen.failNode(node, "continue expression outside loop", .{});
    }
}

/// Similar to `expr`, but intended for use when `gz` corresponds to a body
/// which will contain only this node's code. Differs from `expr` in that if the
/// root expression is an unlabeled block, does not emit an actual block.
/// Instead, the block contents are emitted directly into `gz`.
fn fullBodyExpr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const tree = gz.astgen.tree;
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);
    var stmt_buf: [2]Ast.Node.Index = undefined;
    const statements: []const Ast.Node.Index = switch (node_tags[node]) {
        else => return expr(gz, scope, ri, node),
        .block_two, .block_two_semicolon => if (node_datas[node].lhs == 0) s: {
            break :s &.{};
        } else if (node_datas[node].rhs == 0) s: {
            stmt_buf[0] = node_datas[node].lhs;
            break :s stmt_buf[0..1];
        } else s: {
            stmt_buf[0] = node_datas[node].lhs;
            stmt_buf[1] = node_datas[node].rhs;
            break :s stmt_buf[0..2];
        },
        .block, .block_semicolon => tree.extra_data[node_datas[node].lhs..node_datas[node].rhs],
    };

    const lbrace = main_tokens[node];
    if (token_tags[lbrace - 1] == .colon and
        token_tags[lbrace - 2] == .identifier)
    {
        // Labeled blocks are tricky - forwarding result location information properly is non-trivial,
        // plus if this block is exited with a `break_inline` we aren't allowed multiple breaks. This
        // case is rare, so just treat it as a normal expression and create a nested block.
        return expr(gz, scope, ri, node);
    }

    var sub_gz = gz.makeSubBlock(scope);
    try blockExprStmts(&sub_gz, &sub_gz.base, statements);

    return rvalue(gz, ri, .void_value, node);
}

fn blockExpr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    block_node: Ast.Node.Index,
    statements: []const Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);

    const lbrace = main_tokens[block_node];
    if (token_tags[lbrace - 1] == .colon and
        token_tags[lbrace - 2] == .identifier)
    {
        return labeledBlockExpr(gz, scope, ri, block_node, statements, false);
    }

    if (!gz.is_comptime) {
        // Since this block is unlabeled, its control flow is effectively linear and we
        // can *almost* get away with inlining the block here. However, we actually need
        // to preserve the .block for Sema, to properly pop the error return trace.

        const block_tag: Zir.Inst.Tag = .block;
        const block_inst = try gz.makeBlockInst(block_tag, block_node);
        try gz.instructions.append(astgen.gpa, block_inst);

        var block_scope = gz.makeSubBlock(scope);
        defer block_scope.unstack();

        try blockExprStmts(&block_scope, &block_scope.base, statements);

        if (!block_scope.endsWithNoReturn()) {
            // As our last action before the break, "pop" the error trace if needed
            _ = try gz.addRestoreErrRetIndex(.{ .block = block_inst }, .always, block_node);
            _ = try block_scope.addBreak(.@"break", block_inst, .void_value);
        }

        try block_scope.setBlockBody(block_inst);
    } else {
        var sub_gz = gz.makeSubBlock(scope);
        try blockExprStmts(&sub_gz, &sub_gz.base, statements);
    }

    return rvalue(gz, ri, .void_value, block_node);
}

fn checkLabelRedefinition(astgen: *AstGen, parent_scope: *Scope, label: Ast.TokenIndex) !void {
    // Look for the label in the scope.
    var scope = parent_scope;
    while (true) {
        switch (scope.tag) {
            .gen_zir => {
                const gen_zir = scope.cast(GenZir).?;
                if (gen_zir.label) |prev_label| {
                    if (try astgen.tokenIdentEql(label, prev_label.token)) {
                        const label_name = try astgen.identifierTokenString(label);
                        return astgen.failTokNotes(label, "redefinition of label '{s}'", .{
                            label_name,
                        }, &[_]u32{
                            try astgen.errNoteTok(
                                prev_label.token,
                                "previous definition here",
                                .{},
                            ),
                        });
                    }
                }
                scope = gen_zir.parent;
            },
            .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
            .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
            .defer_normal, .defer_error => scope = scope.cast(Scope.Defer).?.parent,
            .namespace => break,
            .top => unreachable,
        }
    }
}

fn labeledBlockExpr(
    gz: *GenZir,
    parent_scope: *Scope,
    ri: ResultInfo,
    block_node: Ast.Node.Index,
    statements: []const Ast.Node.Index,
    force_comptime: bool,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);

    const lbrace = main_tokens[block_node];
    const label_token = lbrace - 2;
    assert(token_tags[label_token] == .identifier);

    try astgen.checkLabelRedefinition(parent_scope, label_token);

    const need_rl = astgen.nodes_need_rl.contains(block_node);
    const block_ri: ResultInfo = if (need_rl) ri else .{
        .rl = switch (ri.rl) {
            .ptr => .{ .ty = (try ri.rl.resultType(gz, block_node)).? },
            .inferred_ptr => .none,
            else => ri.rl,
        },
        .ctx = ri.ctx,
    };
    // We need to call `rvalue` to write through to the pointer only if we had a
    // result pointer and aren't forwarding it.
    const LocTag = @typeInfo(ResultInfo.Loc).Union.tag_type.?;
    const need_result_rvalue = @as(LocTag, block_ri.rl) != @as(LocTag, ri.rl);

    // Reserve the Block ZIR instruction index so that we can put it into the GenZir struct
    // so that break statements can reference it.
    const block_tag: Zir.Inst.Tag = if (force_comptime) .block_comptime else .block;
    const block_inst = try gz.makeBlockInst(block_tag, block_node);
    try gz.instructions.append(astgen.gpa, block_inst);
    var block_scope = gz.makeSubBlock(parent_scope);
    block_scope.label = GenZir.Label{
        .token = label_token,
        .block_inst = block_inst,
    };
    block_scope.setBreakResultInfo(block_ri);
    if (force_comptime) block_scope.is_comptime = true;
    defer block_scope.unstack();

    try blockExprStmts(&block_scope, &block_scope.base, statements);
    if (!block_scope.endsWithNoReturn()) {
        // As our last action before the return, "pop" the error trace if needed
        _ = try gz.addRestoreErrRetIndex(.{ .block = block_inst }, .always, block_node);
        _ = try block_scope.addBreak(.@"break", block_inst, .void_value);
    }

    if (!block_scope.label.?.used) {
        try astgen.appendErrorTok(label_token, "unused block label", .{});
    }

    try block_scope.setBlockBody(block_inst);
    if (need_result_rvalue) {
        return rvalue(gz, ri, block_inst.toRef(), block_node);
    } else {
        return block_inst.toRef();
    }
}

fn blockExprStmts(gz: *GenZir, parent_scope: *Scope, statements: []const Ast.Node.Index) !void {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);

    if (statements.len == 0) return;

    var block_arena = std.heap.ArenaAllocator.init(gz.astgen.gpa);
    defer block_arena.deinit();
    const block_arena_allocator = block_arena.allocator();

    var noreturn_src_node: Ast.Node.Index = 0;
    var scope = parent_scope;
    for (statements) |statement| {
        if (noreturn_src_node != 0) {
            try astgen.appendErrorNodeNotes(
                statement,
                "unreachable code",
                .{},
                &[_]u32{
                    try astgen.errNoteNode(
                        noreturn_src_node,
                        "control flow is diverted here",
                        .{},
                    ),
                },
            );
        }
        var inner_node = statement;
        while (true) {
            switch (node_tags[inner_node]) {
                // zig fmt: off
                .global_var_decl,
                .local_var_decl,
                .simple_var_decl,
                .aligned_var_decl, => scope = try varDecl(gz, scope, statement, block_arena_allocator, tree.fullVarDecl(statement).?),

                .assign_destructure => scope = try assignDestructureMaybeDecls(gz, scope, statement, block_arena_allocator),

                .@"defer"    => scope = try deferStmt(gz, scope, statement, block_arena_allocator, .defer_normal),
                .@"errdefer" => scope = try deferStmt(gz, scope, statement, block_arena_allocator, .defer_error),

                .assign => try assign(gz, scope, statement),

                .assign_shl => try assignShift(gz, scope, statement, .shl),
                .assign_shr => try assignShift(gz, scope, statement, .shr),

                .assign_bit_and  => try assignOp(gz, scope, statement, .bit_and),
                .assign_bit_or   => try assignOp(gz, scope, statement, .bit_or),
                .assign_bit_xor  => try assignOp(gz, scope, statement, .xor),
                .assign_div      => try assignOp(gz, scope, statement, .div),
                .assign_sub      => try assignOp(gz, scope, statement, .sub),
                .assign_sub_wrap => try assignOp(gz, scope, statement, .subwrap),
                .assign_mod      => try assignOp(gz, scope, statement, .mod_rem),
                .assign_add      => try assignOp(gz, scope, statement, .add),
                .assign_add_wrap => try assignOp(gz, scope, statement, .addwrap),
                .assign_mul      => try assignOp(gz, scope, statement, .mul),
                .assign_mul_wrap => try assignOp(gz, scope, statement, .mulwrap),

                .grouped_expression => {
                    inner_node = node_data[statement].lhs;
                    continue;
                },

                .while_simple,
                .while_cont,
                .@"while", => _ = try whileExpr(gz, scope, .{ .rl = .none }, inner_node, tree.fullWhile(inner_node).?, true),

                .for_simple,
                .@"for", => _ = try forExpr(gz, scope, .{ .rl = .none }, inner_node, tree.fullFor(inner_node).?, true),

                else => noreturn_src_node = try unusedResultExpr(gz, scope, inner_node),
                // zig fmt: on
            }
            break;
        }
    }

    if (noreturn_src_node == 0) {
        try genDefers(gz, parent_scope, scope, .normal_only);
    }
    try checkUsed(gz, parent_scope, scope);
}

/// Returns AST source node of the thing that is noreturn if the statement is
/// definitely `noreturn`. Otherwise returns 0.
fn unusedResultExpr(gz: *GenZir, scope: *Scope, statement: Ast.Node.Index) InnerError!Ast.Node.Index {
    try emitDbgNode(gz, statement);
    // We need to emit an error if the result is not `noreturn` or `void`, but
    // we want to avoid adding the ZIR instruction if possible for performance.
    const maybe_unused_result = try expr(gz, scope, .{ .rl = .none }, statement);
    return addEnsureResult(gz, maybe_unused_result, statement);
}

fn addEnsureResult(gz: *GenZir, maybe_unused_result: Zir.Inst.Ref, statement: Ast.Node.Index) InnerError!Ast.Node.Index {
    var noreturn_src_node: Ast.Node.Index = 0;
    const elide_check = if (maybe_unused_result.toIndex()) |inst| b: {
        // Note that this array becomes invalid after appending more items to it
        // in the above while loop.
        const zir_tags = gz.astgen.instructions.items(.tag);
        switch (zir_tags[@intFromEnum(inst)]) {
            // For some instructions, modify the zir data
            // so we can avoid a separate ensure_result_used instruction.
            .call, .field_call => {
                const break_extra = gz.astgen.instructions.items(.data)[@intFromEnum(inst)].pl_node.payload_index;
                comptime assert(std.meta.fieldIndex(Zir.Inst.Call, "flags") ==
                    std.meta.fieldIndex(Zir.Inst.FieldCall, "flags"));
                const flags: *Zir.Inst.Call.Flags = @ptrCast(&gz.astgen.extra.items[
                    break_extra + std.meta.fieldIndex(Zir.Inst.Call, "flags").?
                ]);
                flags.ensure_result_used = true;
                break :b true;
            },
            .builtin_call => {
                const break_extra = gz.astgen.instructions.items(.data)[@intFromEnum(inst)].pl_node.payload_index;
                const flags: *Zir.Inst.BuiltinCall.Flags = @ptrCast(&gz.astgen.extra.items[
                    break_extra + std.meta.fieldIndex(Zir.Inst.BuiltinCall, "flags").?
                ]);
                flags.ensure_result_used = true;
                break :b true;
            },

            // ZIR instructions that might be a type other than `noreturn` or `void`.
            .add,
            .addwrap,
            .add_sat,
            .add_unsafe,
            .param,
            .param_comptime,
            .param_anytype,
            .param_anytype_comptime,
            .alloc,
            .alloc_mut,
            .alloc_comptime_mut,
            .alloc_inferred,
            .alloc_inferred_mut,
            .alloc_inferred_comptime,
            .alloc_inferred_comptime_mut,
            .make_ptr_const,
            .array_cat,
            .array_mul,
            .array_type,
            .array_type_sentinel,
            .elem_type,
            .indexable_ptr_elem_type,
            .vector_elem_type,
            .vector_type,
            .indexable_ptr_len,
            .anyframe_type,
            .as_node,
            .as_shift_operand,
            .bit_and,
            .bitcast,
            .bit_or,
            .block,
            .block_comptime,
            .block_inline,
            .declaration,
            .suspend_block,
            .loop,
            .bool_br_and,
            .bool_br_or,
            .bool_not,
            .cmp_lt,
            .cmp_lte,
            .cmp_eq,
            .cmp_gte,
            .cmp_gt,
            .cmp_neq,
            .decl_ref,
            .decl_val,
            .load,
            .div,
            .elem_ptr,
            .elem_val,
            .elem_ptr_node,
            .elem_val_node,
            .elem_val_imm,
            .field_ptr,
            .field_val,
            .field_ptr_named,
            .field_val_named,
            .func,
            .func_inferred,
            .func_fancy,
            .int,
            .int_big,
            .float,
            .float128,
            .int_type,
            .is_non_null,
            .is_non_null_ptr,
            .is_non_err,
            .is_non_err_ptr,
            .ret_is_non_err,
            .mod_rem,
            .mul,
            .mulwrap,
            .mul_sat,
            .ref,
            .shl,
            .shl_sat,
            .shr,
            .str,
            .sub,
            .subwrap,
            .sub_sat,
            .negate,
            .negate_wrap,
            .typeof,
            .typeof_builtin,
            .xor,
            .optional_type,
            .optional_payload_safe,
            .optional_payload_unsafe,
            .optional_payload_safe_ptr,
            .optional_payload_unsafe_ptr,
            .err_union_payload_unsafe,
            .err_union_payload_unsafe_ptr,
            .err_union_code,
            .err_union_code_ptr,
            .ptr_type,
            .enum_literal,
            .merge_error_sets,
            .error_union_type,
            .bit_not,
            .error_value,
            .slice_start,
            .slice_end,
            .slice_sentinel,
            .slice_length,
            .import,
            .switch_block,
            .switch_block_ref,
            .switch_block_err_union,
            .union_init,
            .field_type_ref,
            .error_set_decl,
            .error_set_decl_anon,
            .error_set_decl_func,
            .enum_from_int,
            .int_from_enum,
            .type_info,
            .size_of,
            .bit_size_of,
            .typeof_log2_int_type,
            .int_from_ptr,
            .align_of,
            .int_from_bool,
            .embed_file,
            .error_name,
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
            .frame_type,
            .frame_size,
            .int_from_float,
            .float_from_int,
            .ptr_from_int,
            .float_cast,
            .int_cast,
            .ptr_cast,
            .truncate,
            .has_decl,
            .has_field,
            .clz,
            .ctz,
            .pop_count,
            .byte_swap,
            .bit_reverse,
            .div_exact,
            .div_floor,
            .div_trunc,
            .mod,
            .rem,
            .shl_exact,
            .shr_exact,
            .bit_offset_of,
            .offset_of,
            .splat,
            .reduce,
            .shuffle,
            .atomic_load,
            .atomic_rmw,
            .mul_add,
            .max,
            .min,
            .c_import,
            .@"resume",
            .@"await",
            .ret_err_value_code,
            .ret_ptr,
            .ret_type,
            .for_len,
            .@"try",
            .try_ptr,
            .opt_eu_base_ptr_init,
            .coerce_ptr_elem_ty,
            .struct_init_empty,
            .struct_init_empty_result,
            .struct_init_empty_ref_result,
            .struct_init_anon,
            .struct_init,
            .struct_init_ref,
            .struct_init_field_type,
            .struct_init_field_ptr,
            .array_init_anon,
            .array_init,
            .array_init_ref,
            .validate_array_init_ref_ty,
            .array_init_elem_type,
            .array_init_elem_ptr,
            => break :b false,

            .extended => switch (gz.astgen.instructions.items(.data)[@intFromEnum(inst)].extended.opcode) {
                .breakpoint,
                .fence,
                .set_float_mode,
                .set_align_stack,
                .set_cold,
                => break :b true,
                else => break :b false,
            },

            // ZIR instructions that are always `noreturn`.
            .@"break",
            .break_inline,
            .condbr,
            .condbr_inline,
            .compile_error,
            .ret_node,
            .ret_load,
            .ret_implicit,
            .ret_err_value,
            .@"unreachable",
            .repeat,
            .repeat_inline,
            .panic,
            .trap,
            .check_comptime_control_flow,
            => {
                noreturn_src_node = statement;
                break :b true;
            },

            // ZIR instructions that are always `void`.
            .dbg_stmt,
            .dbg_var_ptr,
            .dbg_var_val,
            .ensure_result_used,
            .ensure_result_non_error,
            .ensure_err_union_payload_void,
            .@"export",
            .export_value,
            .set_eval_branch_quota,
            .atomic_store,
            .store_node,
            .store_to_inferred_ptr,
            .resolve_inferred_alloc,
            .set_runtime_safety,
            .memcpy,
            .memset,
            .validate_deref,
            .validate_destructure,
            .save_err_ret_index,
            .restore_err_ret_index_unconditional,
            .restore_err_ret_index_fn_entry,
            .validate_struct_init_ty,
            .validate_struct_init_result_ty,
            .validate_ptr_struct_init,
            .validate_array_init_ty,
            .validate_array_init_result_ty,
            .validate_ptr_array_init,
            .validate_ref_ty,
            => break :b true,

            .@"defer" => unreachable,
            .defer_err_code => unreachable,
        }
    } else switch (maybe_unused_result) {
        .none => unreachable,

        .unreachable_value => b: {
            noreturn_src_node = statement;
            break :b true;
        },

        .void_value => true,

        else => false,
    };
    if (!elide_check) {
        _ = try gz.addUnNode(.ensure_result_used, maybe_unused_result, statement);
    }
    return noreturn_src_node;
}

fn countDefers(outer_scope: *Scope, inner_scope: *Scope) struct {
    have_any: bool,
    have_normal: bool,
    have_err: bool,
    need_err_code: bool,
} {
    var have_normal = false;
    var have_err = false;
    var need_err_code = false;
    var scope = inner_scope;
    while (scope != outer_scope) {
        switch (scope.tag) {
            .gen_zir => scope = scope.cast(GenZir).?.parent,
            .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
            .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
            .defer_normal => {
                const defer_scope = scope.cast(Scope.Defer).?;
                scope = defer_scope.parent;

                have_normal = true;
            },
            .defer_error => {
                const defer_scope = scope.cast(Scope.Defer).?;
                scope = defer_scope.parent;

                have_err = true;

                const have_err_payload = defer_scope.remapped_err_code != .none;
                need_err_code = need_err_code or have_err_payload;
            },
            .namespace => unreachable,
            .top => unreachable,
        }
    }
    return .{
        .have_any = have_normal or have_err,
        .have_normal = have_normal,
        .have_err = have_err,
        .need_err_code = need_err_code,
    };
}

const DefersToEmit = union(enum) {
    both: Zir.Inst.Ref, // err code
    both_sans_err,
    normal_only,
};

fn genDefers(
    gz: *GenZir,
    outer_scope: *Scope,
    inner_scope: *Scope,
    which_ones: DefersToEmit,
) InnerError!void {
    const gpa = gz.astgen.gpa;

    var scope = inner_scope;
    while (scope != outer_scope) {
        switch (scope.tag) {
            .gen_zir => scope = scope.cast(GenZir).?.parent,
            .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
            .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
            .defer_normal => {
                const defer_scope = scope.cast(Scope.Defer).?;
                scope = defer_scope.parent;
                try gz.addDefer(defer_scope.index, defer_scope.len);
            },
            .defer_error => {
                const defer_scope = scope.cast(Scope.Defer).?;
                scope = defer_scope.parent;
                switch (which_ones) {
                    .both_sans_err => {
                        try gz.addDefer(defer_scope.index, defer_scope.len);
                    },
                    .both => |err_code| {
                        if (defer_scope.remapped_err_code.unwrap()) |remapped_err_code| {
                            try gz.instructions.ensureUnusedCapacity(gpa, 1);
                            try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

                            const payload_index = try gz.astgen.addExtra(Zir.Inst.DeferErrCode{
                                .remapped_err_code = remapped_err_code,
                                .index = defer_scope.index,
                                .len = defer_scope.len,
                            });
                            const new_index: Zir.Inst.Index = @enumFromInt(gz.astgen.instructions.len);
                            gz.astgen.instructions.appendAssumeCapacity(.{
                                .tag = .defer_err_code,
                                .data = .{ .defer_err_code = .{
                                    .err_code = err_code,
                                    .payload_index = payload_index,
                                } },
                            });
                            gz.instructions.appendAssumeCapacity(new_index);
                        } else {
                            try gz.addDefer(defer_scope.index, defer_scope.len);
                        }
                    },
                    .normal_only => continue,
                }
            },
            .namespace => unreachable,
            .top => unreachable,
        }
    }
}

fn checkUsed(gz: *GenZir, outer_scope: *Scope, inner_scope: *Scope) InnerError!void {
    const astgen = gz.astgen;

    var scope = inner_scope;
    while (scope != outer_scope) {
        switch (scope.tag) {
            .gen_zir => scope = scope.cast(GenZir).?.parent,
            .local_val => {
                const s = scope.cast(Scope.LocalVal).?;
                if (s.used == 0 and s.discarded == 0) {
                    try astgen.appendErrorTok(s.token_src, "unused {s}", .{@tagName(s.id_cat)});
                } else if (s.used != 0 and s.discarded != 0) {
                    try astgen.appendErrorTokNotes(s.discarded, "pointless discard of {s}", .{@tagName(s.id_cat)}, &[_]u32{
                        try gz.astgen.errNoteTok(s.used, "used here", .{}),
                    });
                }
                scope = s.parent;
            },
            .local_ptr => {
                const s = scope.cast(Scope.LocalPtr).?;
                if (s.used == 0 and s.discarded == 0) {
                    try astgen.appendErrorTok(s.token_src, "unused {s}", .{@tagName(s.id_cat)});
                } else {
                    if (s.used != 0 and s.discarded != 0) {
                        try astgen.appendErrorTokNotes(s.discarded, "pointless discard of {s}", .{@tagName(s.id_cat)}, &[_]u32{
                            try astgen.errNoteTok(s.used, "used here", .{}),
                        });
                    }
                    if (s.id_cat == .@"local variable" and !s.used_as_lvalue) {
                        try astgen.appendErrorTokNotes(s.token_src, "local variable is never mutated", .{}, &.{
                            try astgen.errNoteTok(s.token_src, "consider using 'const'", .{}),
                        });
                    }
                }

                scope = s.parent;
            },
            .defer_normal, .defer_error => scope = scope.cast(Scope.Defer).?.parent,
            .namespace => unreachable,
            .top => unreachable,
        }
    }
}

fn deferStmt(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    block_arena: Allocator,
    scope_tag: Scope.Tag,
) InnerError!*Scope {
    var defer_gen = gz.makeSubBlock(scope);
    defer_gen.cur_defer_node = node;
    defer_gen.any_defer_node = node;
    defer defer_gen.unstack();

    const tree = gz.astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const expr_node = node_datas[node].rhs;

    const payload_token = node_datas[node].lhs;
    var local_val_scope: Scope.LocalVal = undefined;
    var opt_remapped_err_code: Zir.Inst.OptionalIndex = .none;
    const have_err_code = scope_tag == .defer_error and payload_token != 0;
    const sub_scope = if (!have_err_code) &defer_gen.base else blk: {
        const ident_name = try gz.astgen.identAsString(payload_token);
        const remapped_err_code: Zir.Inst.Index = @enumFromInt(gz.astgen.instructions.len);
        opt_remapped_err_code = remapped_err_code.toOptional();
        try gz.astgen.instructions.append(gz.astgen.gpa, .{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .value_placeholder,
                .small = undefined,
                .operand = undefined,
            } },
        });
        const remapped_err_code_ref = remapped_err_code.toRef();
        local_val_scope = .{
            .parent = &defer_gen.base,
            .gen_zir = gz,
            .name = ident_name,
            .inst = remapped_err_code_ref,
            .token_src = payload_token,
            .id_cat = .capture,
        };
        try gz.addDbgVar(.dbg_var_val, ident_name, remapped_err_code_ref);
        break :blk &local_val_scope.base;
    };
    _ = try unusedResultExpr(&defer_gen, sub_scope, expr_node);
    try checkUsed(gz, scope, sub_scope);
    _ = try defer_gen.addBreak(.break_inline, @enumFromInt(0), .void_value);

    // We must handle ref_table for remapped_err_code manually.
    const body = defer_gen.instructionsSlice();
    const body_len = blk: {
        var refs: u32 = 0;
        if (opt_remapped_err_code.unwrap()) |remapped_err_code| {
            var cur_inst = remapped_err_code;
            while (gz.astgen.ref_table.get(cur_inst)) |ref_inst| {
                refs += 1;
                cur_inst = ref_inst;
            }
        }
        break :blk gz.astgen.countBodyLenAfterFixups(body) + refs;
    };

    const index: u32 = @intCast(gz.astgen.extra.items.len);
    try gz.astgen.extra.ensureUnusedCapacity(gz.astgen.gpa, body_len);
    if (opt_remapped_err_code.unwrap()) |remapped_err_code| {
        if (gz.astgen.ref_table.fetchRemove(remapped_err_code)) |kv| {
            gz.astgen.appendPossiblyRefdBodyInst(&gz.astgen.extra, kv.value);
        }
    }
    gz.astgen.appendBodyWithFixups(body);

    const defer_scope = try block_arena.create(Scope.Defer);

    defer_scope.* = .{
        .base = .{ .tag = scope_tag },
        .parent = scope,
        .index = index,
        .len = body_len,
        .remapped_err_code = opt_remapped_err_code,
    };
    return &defer_scope.base;
}

fn varDecl(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    block_arena: Allocator,
    var_decl: Ast.full.VarDecl,
) InnerError!*Scope {
    try emitDbgNode(gz, node);
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const token_tags = tree.tokens.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);

    const name_token = var_decl.ast.mut_token + 1;
    const ident_name_raw = tree.tokenSlice(name_token);
    if (mem.eql(u8, ident_name_raw, "_")) {
        return astgen.failTok(name_token, "'_' used as an identifier without @\"_\" syntax", .{});
    }
    const ident_name = try astgen.identAsString(name_token);

    try astgen.detectLocalShadowing(
        scope,
        ident_name,
        name_token,
        ident_name_raw,
        if (token_tags[var_decl.ast.mut_token] == .keyword_const) .@"local constant" else .@"local variable",
    );

    if (var_decl.ast.init_node == 0) {
        return astgen.failNode(node, "variables must be initialized", .{});
    }

    if (var_decl.ast.addrspace_node != 0) {
        return astgen.failTok(main_tokens[var_decl.ast.addrspace_node], "cannot set address space of local variable '{s}'", .{ident_name_raw});
    }

    if (var_decl.ast.section_node != 0) {
        return astgen.failTok(main_tokens[var_decl.ast.section_node], "cannot set section of local variable '{s}'", .{ident_name_raw});
    }

    const align_inst: Zir.Inst.Ref = if (var_decl.ast.align_node != 0)
        try expr(gz, scope, coerced_align_ri, var_decl.ast.align_node)
    else
        .none;

    switch (token_tags[var_decl.ast.mut_token]) {
        .keyword_const => {
            if (var_decl.comptime_token) |comptime_token| {
                try astgen.appendErrorTok(comptime_token, "'comptime const' is redundant; instead wrap the initialization expression with 'comptime'", .{});
            }

            // Depending on the type of AST the initialization expression is, we may need an lvalue
            // or an rvalue as a result location. If it is an rvalue, we can use the instruction as
            // the variable, no memory location needed.
            const type_node = var_decl.ast.type_node;
            if (align_inst == .none and
                !astgen.nodes_need_rl.contains(node))
            {
                const result_info: ResultInfo = if (type_node != 0) .{
                    .rl = .{ .ty = try typeExpr(gz, scope, type_node) },
                    .ctx = .const_init,
                } else .{ .rl = .none, .ctx = .const_init };
                const prev_anon_name_strategy = gz.anon_name_strategy;
                gz.anon_name_strategy = .dbg_var;
                const init_inst = try reachableExpr(gz, scope, result_info, var_decl.ast.init_node, node);
                gz.anon_name_strategy = prev_anon_name_strategy;

                try gz.addDbgVar(.dbg_var_val, ident_name, init_inst);

                // The const init expression may have modified the error return trace, so signal
                // to Sema that it should save the new index for restoring later.
                if (nodeMayAppendToErrorTrace(tree, var_decl.ast.init_node))
                    _ = try gz.addSaveErrRetIndex(.{ .if_of_error_type = init_inst });

                const sub_scope = try block_arena.create(Scope.LocalVal);
                sub_scope.* = .{
                    .parent = scope,
                    .gen_zir = gz,
                    .name = ident_name,
                    .inst = init_inst,
                    .token_src = name_token,
                    .id_cat = .@"local constant",
                };
                return &sub_scope.base;
            }

            const is_comptime = gz.is_comptime or
                tree.nodes.items(.tag)[var_decl.ast.init_node] == .@"comptime";

            var resolve_inferred_alloc: Zir.Inst.Ref = .none;
            var opt_type_inst: Zir.Inst.Ref = .none;
            const init_rl: ResultInfo.Loc = if (type_node != 0) init_rl: {
                const type_inst = try typeExpr(gz, scope, type_node);
                opt_type_inst = type_inst;
                if (align_inst == .none) {
                    break :init_rl .{ .ptr = .{ .inst = try gz.addUnNode(.alloc, type_inst, node) } };
                } else {
                    break :init_rl .{ .ptr = .{ .inst = try gz.addAllocExtended(.{
                        .node = node,
                        .type_inst = type_inst,
                        .align_inst = align_inst,
                        .is_const = true,
                        .is_comptime = is_comptime,
                    }) } };
                }
            } else init_rl: {
                const alloc_inst = if (align_inst == .none) ptr: {
                    const tag: Zir.Inst.Tag = if (is_comptime)
                        .alloc_inferred_comptime
                    else
                        .alloc_inferred;
                    break :ptr try gz.addNode(tag, node);
                } else ptr: {
                    break :ptr try gz.addAllocExtended(.{
                        .node = node,
                        .type_inst = .none,
                        .align_inst = align_inst,
                        .is_const = true,
                        .is_comptime = is_comptime,
                    });
                };
                resolve_inferred_alloc = alloc_inst;
                break :init_rl .{ .inferred_ptr = alloc_inst };
            };
            const var_ptr = switch (init_rl) {
                .ptr => |ptr| ptr.inst,
                .inferred_ptr => |inst| inst,
                else => unreachable,
            };
            const init_result_info: ResultInfo = .{ .rl = init_rl, .ctx = .const_init };

            const prev_anon_name_strategy = gz.anon_name_strategy;
            gz.anon_name_strategy = .dbg_var;
            defer gz.anon_name_strategy = prev_anon_name_strategy;
            const init_inst = try reachableExpr(gz, scope, init_result_info, var_decl.ast.init_node, node);

            // The const init expression may have modified the error return trace, so signal
            // to Sema that it should save the new index for restoring later.
            if (nodeMayAppendToErrorTrace(tree, var_decl.ast.init_node))
                _ = try gz.addSaveErrRetIndex(.{ .if_of_error_type = init_inst });

            const const_ptr = if (resolve_inferred_alloc != .none) p: {
                _ = try gz.addUnNode(.resolve_inferred_alloc, resolve_inferred_alloc, node);
                break :p var_ptr;
            } else try gz.addUnNode(.make_ptr_const, var_ptr, node);

            try gz.addDbgVar(.dbg_var_ptr, ident_name, const_ptr);

            const sub_scope = try block_arena.create(Scope.LocalPtr);
            sub_scope.* = .{
                .parent = scope,
                .gen_zir = gz,
                .name = ident_name,
                .ptr = const_ptr,
                .token_src = name_token,
                .maybe_comptime = true,
                .id_cat = .@"local constant",
            };
            return &sub_scope.base;
        },
        .keyword_var => {
            if (var_decl.comptime_token != null and gz.is_comptime)
                return astgen.failTok(var_decl.comptime_token.?, "'comptime var' is redundant in comptime scope", .{});
            const is_comptime = var_decl.comptime_token != null or gz.is_comptime;
            var resolve_inferred_alloc: Zir.Inst.Ref = .none;
            const alloc: Zir.Inst.Ref, const result_info: ResultInfo = if (var_decl.ast.type_node != 0) a: {
                const type_inst = try typeExpr(gz, scope, var_decl.ast.type_node);
                const alloc = alloc: {
                    if (align_inst == .none) {
                        const tag: Zir.Inst.Tag = if (is_comptime)
                            .alloc_comptime_mut
                        else
                            .alloc_mut;
                        break :alloc try gz.addUnNode(tag, type_inst, node);
                    } else {
                        break :alloc try gz.addAllocExtended(.{
                            .node = node,
                            .type_inst = type_inst,
                            .align_inst = align_inst,
                            .is_const = false,
                            .is_comptime = is_comptime,
                        });
                    }
                };
                break :a .{ alloc, .{ .rl = .{ .ptr = .{ .inst = alloc } } } };
            } else a: {
                const alloc = alloc: {
                    if (align_inst == .none) {
                        const tag: Zir.Inst.Tag = if (is_comptime)
                            .alloc_inferred_comptime_mut
                        else
                            .alloc_inferred_mut;
                        break :alloc try gz.addNode(tag, node);
                    } else {
                        break :alloc try gz.addAllocExtended(.{
                            .node = node,
                            .type_inst = .none,
                            .align_inst = align_inst,
                            .is_const = false,
                            .is_comptime = is_comptime,
                        });
                    }
                };
                resolve_inferred_alloc = alloc;
                break :a .{ alloc, .{ .rl = .{ .inferred_ptr = alloc } } };
            };
            const prev_anon_name_strategy = gz.anon_name_strategy;
            gz.anon_name_strategy = .dbg_var;
            _ = try reachableExprComptime(gz, scope, result_info, var_decl.ast.init_node, node, is_comptime);
            gz.anon_name_strategy = prev_anon_name_strategy;
            if (resolve_inferred_alloc != .none) {
                _ = try gz.addUnNode(.resolve_inferred_alloc, resolve_inferred_alloc, node);
            }

            try gz.addDbgVar(.dbg_var_ptr, ident_name, alloc);

            const sub_scope = try block_arena.create(Scope.LocalPtr);
            sub_scope.* = .{
                .parent = scope,
                .gen_zir = gz,
                .name = ident_name,
                .ptr = alloc,
                .token_src = name_token,
                .maybe_comptime = is_comptime,
                .id_cat = .@"local variable",
            };
            return &sub_scope.base;
        },
        else => unreachable,
    }
}

fn emitDbgNode(gz: *GenZir, node: Ast.Node.Index) !void {
    // The instruction emitted here is for debugging runtime code.
    // If the current block will be evaluated only during semantic analysis
    // then no dbg_stmt ZIR instruction is needed.
    if (gz.is_comptime) return;
    const astgen = gz.astgen;
    astgen.advanceSourceCursorToNode(node);
    const line = astgen.source_line - gz.decl_line;
    const column = astgen.source_column;
    try emitDbgStmt(gz, .{ line, column });
}

fn assign(gz: *GenZir, scope: *Scope, infix_node: Ast.Node.Index) InnerError!void {
    try emitDbgNode(gz, infix_node);
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const node_tags = tree.nodes.items(.tag);

    const lhs = node_datas[infix_node].lhs;
    const rhs = node_datas[infix_node].rhs;
    if (node_tags[lhs] == .identifier) {
        // This intentionally does not support `@"_"` syntax.
        const ident_name = tree.tokenSlice(main_tokens[lhs]);
        if (mem.eql(u8, ident_name, "_")) {
            _ = try expr(gz, scope, .{ .rl = .discard, .ctx = .assignment }, rhs);
            return;
        }
    }
    const lvalue = try lvalExpr(gz, scope, lhs);
    _ = try expr(gz, scope, .{ .rl = .{ .ptr = .{
        .inst = lvalue,
        .src_node = infix_node,
    } } }, rhs);
}

/// Handles destructure assignments where no LHS is a `const` or `var` decl.
fn assignDestructure(gz: *GenZir, scope: *Scope, node: Ast.Node.Index) InnerError!void {
    try emitDbgNode(gz, node);
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const node_tags = tree.nodes.items(.tag);

    const full = tree.assignDestructure(node);
    if (full.comptime_token != null and gz.is_comptime) {
        return astgen.failNode(node, "redundant comptime keyword in already comptime scope", .{});
    }

    // If this expression is marked comptime, we must wrap the whole thing in a comptime block.
    var gz_buf: GenZir = undefined;
    const inner_gz = if (full.comptime_token) |_| bs: {
        gz_buf = gz.makeSubBlock(scope);
        gz_buf.is_comptime = true;
        break :bs &gz_buf;
    } else gz;
    defer if (full.comptime_token) |_| inner_gz.unstack();

    const rl_components = try astgen.arena.alloc(ResultInfo.Loc.DestructureComponent, full.ast.variables.len);
    for (rl_components, full.ast.variables) |*variable_rl, variable_node| {
        if (node_tags[variable_node] == .identifier) {
            // This intentionally does not support `@"_"` syntax.
            const ident_name = tree.tokenSlice(main_tokens[variable_node]);
            if (mem.eql(u8, ident_name, "_")) {
                variable_rl.* = .discard;
                continue;
            }
        }
        variable_rl.* = .{ .typed_ptr = .{
            .inst = try lvalExpr(inner_gz, scope, variable_node),
            .src_node = variable_node,
        } };
    }

    const ri: ResultInfo = .{ .rl = .{ .destructure = .{
        .src_node = node,
        .components = rl_components,
    } } };

    _ = try expr(inner_gz, scope, ri, full.ast.value_expr);

    if (full.comptime_token) |_| {
        const comptime_block_inst = try gz.makeBlockInst(.block_comptime, node);
        _ = try inner_gz.addBreak(.@"break", comptime_block_inst, .void_value);
        try inner_gz.setBlockBody(comptime_block_inst);
        try gz.instructions.append(gz.astgen.gpa, comptime_block_inst);
    }
}

/// Handles destructure assignments where the LHS may contain `const` or `var` decls.
fn assignDestructureMaybeDecls(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    block_arena: Allocator,
) InnerError!*Scope {
    try emitDbgNode(gz, node);
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const token_tags = tree.tokens.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const node_tags = tree.nodes.items(.tag);

    const full = tree.assignDestructure(node);
    if (full.comptime_token != null and gz.is_comptime) {
        return astgen.failNode(node, "redundant comptime keyword in already comptime scope", .{});
    }

    const is_comptime = full.comptime_token != null or gz.is_comptime;
    const value_is_comptime = node_tags[full.ast.value_expr] == .@"comptime";

    // When declaring consts via a destructure, we always use a result pointer.
    // This avoids the need to create tuple types, and is also likely easier to
    // optimize, since it's a bit tricky for the optimizer to "split up" the
    // value into individual pointer writes down the line.

    // We know this rl information won't live past the evaluation of this
    // expression, so it may as well go in the block arena.
    const rl_components = try block_arena.alloc(ResultInfo.Loc.DestructureComponent, full.ast.variables.len);
    var any_non_const_variables = false;
    var any_lvalue_expr = false;
    for (rl_components, full.ast.variables) |*variable_rl, variable_node| {
        switch (node_tags[variable_node]) {
            .identifier => {
                // This intentionally does not support `@"_"` syntax.
                const ident_name = tree.tokenSlice(main_tokens[variable_node]);
                if (mem.eql(u8, ident_name, "_")) {
                    any_non_const_variables = true;
                    variable_rl.* = .discard;
                    continue;
                }
            },
            .global_var_decl, .local_var_decl, .simple_var_decl, .aligned_var_decl => {
                const full_var_decl = tree.fullVarDecl(variable_node).?;

                const name_token = full_var_decl.ast.mut_token + 1;
                const ident_name_raw = tree.tokenSlice(name_token);
                if (mem.eql(u8, ident_name_raw, "_")) {
                    return astgen.failTok(name_token, "'_' used as an identifier without @\"_\" syntax", .{});
                }

                // We detect shadowing in the second pass over these, while we're creating scopes.

                if (full_var_decl.ast.addrspace_node != 0) {
                    return astgen.failTok(main_tokens[full_var_decl.ast.addrspace_node], "cannot set address space of local variable '{s}'", .{ident_name_raw});
                }
                if (full_var_decl.ast.section_node != 0) {
                    return astgen.failTok(main_tokens[full_var_decl.ast.section_node], "cannot set section of local variable '{s}'", .{ident_name_raw});
                }

                const is_const = switch (token_tags[full_var_decl.ast.mut_token]) {
                    .keyword_var => false,
                    .keyword_const => true,
                    else => unreachable,
                };
                if (!is_const) any_non_const_variables = true;

                // We also mark `const`s as comptime if the RHS is definitely comptime-known.
                const this_variable_comptime = is_comptime or (is_const and value_is_comptime);

                const align_inst: Zir.Inst.Ref = if (full_var_decl.ast.align_node != 0)
                    try expr(gz, scope, coerced_align_ri, full_var_decl.ast.align_node)
                else
                    .none;

                if (full_var_decl.ast.type_node != 0) {
                    // Typed alloc
                    const type_inst = try typeExpr(gz, scope, full_var_decl.ast.type_node);
                    const ptr = if (align_inst == .none) ptr: {
                        const tag: Zir.Inst.Tag = if (is_const)
                            .alloc
                        else if (this_variable_comptime)
                            .alloc_comptime_mut
                        else
                            .alloc_mut;
                        break :ptr try gz.addUnNode(tag, type_inst, node);
                    } else try gz.addAllocExtended(.{
                        .node = node,
                        .type_inst = type_inst,
                        .align_inst = align_inst,
                        .is_const = is_const,
                        .is_comptime = this_variable_comptime,
                    });
                    variable_rl.* = .{ .typed_ptr = .{ .inst = ptr } };
                } else {
                    // Inferred alloc
                    const ptr = if (align_inst == .none) ptr: {
                        const tag: Zir.Inst.Tag = if (is_const) tag: {
                            break :tag if (this_variable_comptime) .alloc_inferred_comptime else .alloc_inferred;
                        } else tag: {
                            break :tag if (this_variable_comptime) .alloc_inferred_comptime_mut else .alloc_inferred_mut;
                        };
                        break :ptr try gz.addNode(tag, node);
                    } else try gz.addAllocExtended(.{
                        .node = node,
                        .type_inst = .none,
                        .align_inst = align_inst,
                        .is_const = is_const,
                        .is_comptime = this_variable_comptime,
                    });
                    variable_rl.* = .{ .inferred_ptr = ptr };
                }

                continue;
            },
            else => {},
        }
        // This variable is just an lvalue expression.
        // We will fill in its result pointer later, inside a comptime block.
        any_non_const_variables = true;
        any_lvalue_expr = true;
        variable_rl.* = .{ .typed_ptr = .{
            .inst = undefined,
            .src_node = variable_node,
        } };
    }

    if (full.comptime_token != null and !any_non_const_variables) {
        try astgen.appendErrorTok(full.comptime_token.?, "'comptime const' is redundant; instead wrap the initialization expression with 'comptime'", .{});
    }

    // If this expression is marked comptime, we must wrap it in a comptime block.
    var gz_buf: GenZir = undefined;
    const inner_gz = if (full.comptime_token) |_| bs: {
        gz_buf = gz.makeSubBlock(scope);
        gz_buf.is_comptime = true;
        break :bs &gz_buf;
    } else gz;
    defer if (full.comptime_token) |_| inner_gz.unstack();

    if (any_lvalue_expr) {
        // At least one variable was an lvalue expr. Iterate again in order to
        // evaluate the lvalues from within the possible block_comptime.
        for (rl_components, full.ast.variables) |*variable_rl, variable_node| {
            if (variable_rl.* != .typed_ptr) continue;
            switch (node_tags[variable_node]) {
                .global_var_decl, .local_var_decl, .simple_var_decl, .aligned_var_decl => continue,
                else => {},
            }
            variable_rl.typed_ptr.inst = try lvalExpr(inner_gz, scope, variable_node);
        }
    }

    // We can't give a reasonable anon name strategy for destructured inits, so
    // leave it at its default of `.anon`.
    _ = try reachableExpr(inner_gz, scope, .{ .rl = .{ .destructure = .{
        .src_node = node,
        .components = rl_components,
    } } }, full.ast.value_expr, node);

    if (full.comptime_token) |_| {
        // Finish the block_comptime. Inferred alloc resolution etc will occur
        // in the parent block.
        const comptime_block_inst = try gz.makeBlockInst(.block_comptime, node);
        _ = try inner_gz.addBreak(.@"break", comptime_block_inst, .void_value);
        try inner_gz.setBlockBody(comptime_block_inst);
        try gz.instructions.append(gz.astgen.gpa, comptime_block_inst);
    }

    // Now, iterate over the variable exprs to construct any new scopes.
    // If there were any inferred allocations, resolve them.
    // If there were any `const` decls, make the pointer constant.
    var cur_scope = scope;
    for (rl_components, full.ast.variables) |variable_rl, variable_node| {
        switch (node_tags[variable_node]) {
            .local_var_decl, .simple_var_decl, .aligned_var_decl => {},
            else => continue, // We were mutating an existing lvalue - nothing to do
        }
        const full_var_decl = tree.fullVarDecl(variable_node).?;
        const raw_ptr = switch (variable_rl) {
            .discard => unreachable,
            .typed_ptr => |typed_ptr| typed_ptr.inst,
            .inferred_ptr => |ptr_inst| ptr_inst,
        };
        // If the alloc was inferred, resolve it.
        if (full_var_decl.ast.type_node == 0) {
            _ = try gz.addUnNode(.resolve_inferred_alloc, raw_ptr, variable_node);
        }
        const is_const = switch (token_tags[full_var_decl.ast.mut_token]) {
            .keyword_var => false,
            .keyword_const => true,
            else => unreachable,
        };
        // If the alloc was const, make it const.
        const var_ptr = if (is_const and full_var_decl.ast.type_node != 0) make_const: {
            // Note that we don't do this if type_node == 0 since `resolve_inferred_alloc`
            // handles it for us.
            break :make_const try gz.addUnNode(.make_ptr_const, raw_ptr, node);
        } else raw_ptr;
        const name_token = full_var_decl.ast.mut_token + 1;
        const ident_name_raw = tree.tokenSlice(name_token);
        const ident_name = try astgen.identAsString(name_token);
        try astgen.detectLocalShadowing(
            cur_scope,
            ident_name,
            name_token,
            ident_name_raw,
            if (is_const) .@"local constant" else .@"local variable",
        );
        try gz.addDbgVar(.dbg_var_ptr, ident_name, var_ptr);
        // Finally, create the scope.
        const sub_scope = try block_arena.create(Scope.LocalPtr);
        sub_scope.* = .{
            .parent = cur_scope,
            .gen_zir = gz,
            .name = ident_name,
            .ptr = var_ptr,
            .token_src = name_token,
            .maybe_comptime = is_const or is_comptime,
            .id_cat = if (is_const) .@"local constant" else .@"local variable",
        };
        cur_scope = &sub_scope.base;
    }

    return cur_scope;
}

fn assignOp(
    gz: *GenZir,
    scope: *Scope,
    infix_node: Ast.Node.Index,
    op_inst_tag: Zir.Inst.Tag,
) InnerError!void {
    try emitDbgNode(gz, infix_node);
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);

    const lhs_ptr = try lvalExpr(gz, scope, node_datas[infix_node].lhs);

    const cursor = switch (op_inst_tag) {
        .add, .sub, .mul, .div, .mod_rem => maybeAdvanceSourceCursorToMainToken(gz, infix_node),
        else => undefined,
    };
    const lhs = try gz.addUnNode(.load, lhs_ptr, infix_node);
    const lhs_type = try gz.addUnNode(.typeof, lhs, infix_node);
    const rhs = try expr(gz, scope, .{ .rl = .{ .coerced_ty = lhs_type } }, node_datas[infix_node].rhs);

    switch (op_inst_tag) {
        .add, .sub, .mul, .div, .mod_rem => {
            try emitDbgStmt(gz, cursor);
        },
        else => {},
    }
    const result = try gz.addPlNode(op_inst_tag, infix_node, Zir.Inst.Bin{
        .lhs = lhs,
        .rhs = rhs,
    });
    _ = try gz.addPlNode(.store_node, infix_node, Zir.Inst.Bin{
        .lhs = lhs_ptr,
        .rhs = result,
    });
}

fn assignShift(
    gz: *GenZir,
    scope: *Scope,
    infix_node: Ast.Node.Index,
    op_inst_tag: Zir.Inst.Tag,
) InnerError!void {
    try emitDbgNode(gz, infix_node);
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);

    const lhs_ptr = try lvalExpr(gz, scope, node_datas[infix_node].lhs);
    const lhs = try gz.addUnNode(.load, lhs_ptr, infix_node);
    const rhs_type = try gz.addUnNode(.typeof_log2_int_type, lhs, infix_node);
    const rhs = try expr(gz, scope, .{ .rl = .{ .ty = rhs_type } }, node_datas[infix_node].rhs);

    const result = try gz.addPlNode(op_inst_tag, infix_node, Zir.Inst.Bin{
        .lhs = lhs,
        .rhs = rhs,
    });
    _ = try gz.addPlNode(.store_node, infix_node, Zir.Inst.Bin{
        .lhs = lhs_ptr,
        .rhs = result,
    });
}

fn assignShiftSat(gz: *GenZir, scope: *Scope, infix_node: Ast.Node.Index) InnerError!void {
    try emitDbgNode(gz, infix_node);
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);

    const lhs_ptr = try lvalExpr(gz, scope, node_datas[infix_node].lhs);
    const lhs = try gz.addUnNode(.load, lhs_ptr, infix_node);
    // Saturating shift-left allows any integer type for both the LHS and RHS.
    const rhs = try expr(gz, scope, .{ .rl = .none }, node_datas[infix_node].rhs);

    const result = try gz.addPlNode(.shl_sat, infix_node, Zir.Inst.Bin{
        .lhs = lhs,
        .rhs = rhs,
    });
    _ = try gz.addPlNode(.store_node, infix_node, Zir.Inst.Bin{
        .lhs = lhs_ptr,
        .rhs = result,
    });
}

fn ptrType(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    ptr_info: Ast.full.PtrType,
) InnerError!Zir.Inst.Ref {
    if (ptr_info.size == .C and ptr_info.allowzero_token != null) {
        return gz.astgen.failTok(ptr_info.allowzero_token.?, "C pointers always allow address zero", .{});
    }

    const source_offset = gz.astgen.source_offset;
    const source_line = gz.astgen.source_line;
    const source_column = gz.astgen.source_column;
    const elem_type = try typeExpr(gz, scope, ptr_info.ast.child_type);

    var sentinel_ref: Zir.Inst.Ref = .none;
    var align_ref: Zir.Inst.Ref = .none;
    var addrspace_ref: Zir.Inst.Ref = .none;
    var bit_start_ref: Zir.Inst.Ref = .none;
    var bit_end_ref: Zir.Inst.Ref = .none;
    var trailing_count: u32 = 0;

    if (ptr_info.ast.sentinel != 0) {
        // These attributes can appear in any order and they all come before the
        // element type so we need to reset the source cursor before generating them.
        gz.astgen.source_offset = source_offset;
        gz.astgen.source_line = source_line;
        gz.astgen.source_column = source_column;

        sentinel_ref = try comptimeExpr(gz, scope, .{ .rl = .{ .ty = elem_type } }, ptr_info.ast.sentinel);
        trailing_count += 1;
    }
    if (ptr_info.ast.addrspace_node != 0) {
        gz.astgen.source_offset = source_offset;
        gz.astgen.source_line = source_line;
        gz.astgen.source_column = source_column;

        addrspace_ref = try expr(gz, scope, coerced_addrspace_ri, ptr_info.ast.addrspace_node);
        trailing_count += 1;
    }
    if (ptr_info.ast.align_node != 0) {
        gz.astgen.source_offset = source_offset;
        gz.astgen.source_line = source_line;
        gz.astgen.source_column = source_column;

        align_ref = try expr(gz, scope, coerced_align_ri, ptr_info.ast.align_node);
        trailing_count += 1;
    }
    if (ptr_info.ast.bit_range_start != 0) {
        assert(ptr_info.ast.bit_range_end != 0);
        bit_start_ref = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .u16_type } }, ptr_info.ast.bit_range_start);
        bit_end_ref = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .u16_type } }, ptr_info.ast.bit_range_end);
        trailing_count += 2;
    }

    const gpa = gz.astgen.gpa;
    try gz.instructions.ensureUnusedCapacity(gpa, 1);
    try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);
    try gz.astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.PtrType).Struct.fields.len +
        trailing_count);

    const payload_index = gz.astgen.addExtraAssumeCapacity(Zir.Inst.PtrType{
        .elem_type = elem_type,
        .src_node = gz.nodeIndexToRelative(node),
    });
    if (sentinel_ref != .none) {
        gz.astgen.extra.appendAssumeCapacity(@intFromEnum(sentinel_ref));
    }
    if (align_ref != .none) {
        gz.astgen.extra.appendAssumeCapacity(@intFromEnum(align_ref));
    }
    if (addrspace_ref != .none) {
        gz.astgen.extra.appendAssumeCapacity(@intFromEnum(addrspace_ref));
    }
    if (bit_start_ref != .none) {
        gz.astgen.extra.appendAssumeCapacity(@intFromEnum(bit_start_ref));
        gz.astgen.extra.appendAssumeCapacity(@intFromEnum(bit_end_ref));
    }

    const new_index: Zir.Inst.Index = @enumFromInt(gz.astgen.instructions.len);
    const result = new_index.toRef();
    gz.astgen.instructions.appendAssumeCapacity(.{ .tag = .ptr_type, .data = .{
        .ptr_type = .{
            .flags = .{
                .is_allowzero = ptr_info.allowzero_token != null,
                .is_mutable = ptr_info.const_token == null,
                .is_volatile = ptr_info.volatile_token != null,
                .has_sentinel = sentinel_ref != .none,
                .has_align = align_ref != .none,
                .has_addrspace = addrspace_ref != .none,
                .has_bit_range = bit_start_ref != .none,
            },
            .size = ptr_info.size,
            .payload_index = payload_index,
        },
    } });
    gz.instructions.appendAssumeCapacity(new_index);

    return rvalue(gz, ri, result, node);
}

fn arrayType(gz: *GenZir, scope: *Scope, ri: ResultInfo, node: Ast.Node.Index) !Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);

    const len_node = node_datas[node].lhs;
    if (node_tags[len_node] == .identifier and
        mem.eql(u8, tree.tokenSlice(main_tokens[len_node]), "_"))
    {
        return astgen.failNode(len_node, "unable to infer array size", .{});
    }
    const len = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, len_node);
    const elem_type = try typeExpr(gz, scope, node_datas[node].rhs);

    const result = try gz.addPlNode(.array_type, node, Zir.Inst.Bin{
        .lhs = len,
        .rhs = elem_type,
    });
    return rvalue(gz, ri, result, node);
}

fn arrayTypeSentinel(gz: *GenZir, scope: *Scope, ri: ResultInfo, node: Ast.Node.Index) !Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const extra = tree.extraData(node_datas[node].rhs, Ast.Node.ArrayTypeSentinel);

    const len_node = node_datas[node].lhs;
    if (node_tags[len_node] == .identifier and
        mem.eql(u8, tree.tokenSlice(main_tokens[len_node]), "_"))
    {
        return astgen.failNode(len_node, "unable to infer array size", .{});
    }
    const len = try reachableExpr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, len_node, node);
    const elem_type = try typeExpr(gz, scope, extra.elem_type);
    const sentinel = try reachableExprComptime(gz, scope, .{ .rl = .{ .coerced_ty = elem_type } }, extra.sentinel, node, true);

    const result = try gz.addPlNode(.array_type_sentinel, node, Zir.Inst.ArrayTypeSentinel{
        .len = len,
        .elem_type = elem_type,
        .sentinel = sentinel,
    });
    return rvalue(gz, ri, result, node);
}

const WipMembers = struct {
    payload: *ArrayListUnmanaged(u32),
    payload_top: usize,
    field_bits_start: u32,
    fields_start: u32,
    fields_end: u32,
    decl_index: u32 = 0,
    field_index: u32 = 0,

    const Self = @This();

    fn init(gpa: Allocator, payload: *ArrayListUnmanaged(u32), decl_count: u32, field_count: u32, comptime bits_per_field: u32, comptime max_field_size: u32) Allocator.Error!Self {
        const payload_top: u32 = @intCast(payload.items.len);
        const field_bits_start = payload_top + decl_count;
        const fields_start = field_bits_start + if (bits_per_field > 0) blk: {
            const fields_per_u32 = 32 / bits_per_field;
            break :blk (field_count + fields_per_u32 - 1) / fields_per_u32;
        } else 0;
        const payload_end = fields_start + field_count * max_field_size;
        try payload.resize(gpa, payload_end);
        return .{
            .payload = payload,
            .payload_top = payload_top,
            .field_bits_start = field_bits_start,
            .fields_start = fields_start,
            .fields_end = fields_start,
        };
    }

    fn nextDecl(self: *Self, decl_inst: Zir.Inst.Index) void {
        self.payload.items[self.payload_top + self.decl_index] = @intFromEnum(decl_inst);
        self.decl_index += 1;
    }

    fn nextField(self: *Self, comptime bits_per_field: u32, bits: [bits_per_field]bool) void {
        const fields_per_u32 = 32 / bits_per_field;
        const index = self.field_bits_start + self.field_index / fields_per_u32;
        assert(index < self.fields_start);
        var bit_bag: u32 = if (self.field_index % fields_per_u32 == 0) 0 else self.payload.items[index];
        bit_bag >>= bits_per_field;
        comptime var i = 0;
        inline while (i < bits_per_field) : (i += 1) {
            bit_bag |= @as(u32, @intFromBool(bits[i])) << (32 - bits_per_field + i);
        }
        self.payload.items[index] = bit_bag;
        self.field_index += 1;
    }

    fn appendToField(self: *Self, data: u32) void {
        assert(self.fields_end < self.payload.items.len);
        self.payload.items[self.fields_end] = data;
        self.fields_end += 1;
    }

    fn finishBits(self: *Self, comptime bits_per_field: u32) void {
        if (bits_per_field > 0) {
            const fields_per_u32 = 32 / bits_per_field;
            const empty_field_slots = fields_per_u32 - (self.field_index % fields_per_u32);
            if (self.field_index > 0 and empty_field_slots < fields_per_u32) {
                const index = self.field_bits_start + self.field_index / fields_per_u32;
                self.payload.items[index] >>= @intCast(empty_field_slots * bits_per_field);
            }
        }
    }

    fn declsSlice(self: *Self) []u32 {
        return self.payload.items[self.payload_top..][0..self.decl_index];
    }

    fn fieldsSlice(self: *Self) []u32 {
        return self.payload.items[self.field_bits_start..self.fields_end];
    }

    fn deinit(self: *Self) void {
        self.payload.items.len = self.payload_top;
    }
};

fn fnDecl(
    astgen: *AstGen,
    gz: *GenZir,
    scope: *Scope,
    wip_members: *WipMembers,
    decl_node: Ast.Node.Index,
    body_node: Ast.Node.Index,
    fn_proto: Ast.full.FnProto,
) InnerError!void {
    const tree = astgen.tree;
    const token_tags = tree.tokens.items(.tag);

    // missing function name already happened in scanDecls()
    const fn_name_token = fn_proto.name_token orelse return error.AnalysisFail;

    // We insert this at the beginning so that its instruction index marks the
    // start of the top level declaration.
    const decl_inst = try gz.makeBlockInst(.declaration, fn_proto.ast.proto_node);
    astgen.advanceSourceCursorToNode(decl_node);

    var decl_gz: GenZir = .{
        .is_comptime = true,
        .decl_node_index = fn_proto.ast.proto_node,
        .decl_line = astgen.source_line,
        .parent = scope,
        .astgen = astgen,
        .instructions = gz.instructions,
        .instructions_top = gz.instructions.items.len,
    };
    defer decl_gz.unstack();

    var fn_gz: GenZir = .{
        .is_comptime = false,
        .decl_node_index = fn_proto.ast.proto_node,
        .decl_line = decl_gz.decl_line,
        .parent = &decl_gz.base,
        .astgen = astgen,
        .instructions = gz.instructions,
        .instructions_top = GenZir.unstacked_top,
    };
    defer fn_gz.unstack();

    // Set this now, since parameter types, return type, etc may be generic.
    const prev_within_fn = astgen.within_fn;
    defer astgen.within_fn = prev_within_fn;
    astgen.within_fn = true;

    const is_pub = fn_proto.visib_token != null;
    const is_export = blk: {
        const maybe_export_token = fn_proto.extern_export_inline_token orelse break :blk false;
        break :blk token_tags[maybe_export_token] == .keyword_export;
    };
    const is_extern = blk: {
        const maybe_extern_token = fn_proto.extern_export_inline_token orelse break :blk false;
        break :blk token_tags[maybe_extern_token] == .keyword_extern;
    };
    const has_inline_keyword = blk: {
        const maybe_inline_token = fn_proto.extern_export_inline_token orelse break :blk false;
        break :blk token_tags[maybe_inline_token] == .keyword_inline;
    };
    const is_noinline = blk: {
        const maybe_noinline_token = fn_proto.extern_export_inline_token orelse break :blk false;
        break :blk token_tags[maybe_noinline_token] == .keyword_noinline;
    };

    const doc_comment_index = try astgen.docCommentAsString(fn_proto.firstToken());

    wip_members.nextDecl(decl_inst);

    var noalias_bits: u32 = 0;
    var params_scope = &fn_gz.base;
    const is_var_args = is_var_args: {
        var param_type_i: usize = 0;
        var it = fn_proto.iterate(tree);
        while (it.next()) |param| : (param_type_i += 1) {
            const is_comptime = if (param.comptime_noalias) |token| switch (token_tags[token]) {
                .keyword_noalias => is_comptime: {
                    noalias_bits |= @as(u32, 1) << (std.math.cast(u5, param_type_i) orelse
                        return astgen.failTok(token, "this compiler implementation only supports 'noalias' on the first 32 parameters", .{}));
                    break :is_comptime false;
                },
                .keyword_comptime => true,
                else => false,
            } else false;

            const is_anytype = if (param.anytype_ellipsis3) |token| blk: {
                switch (token_tags[token]) {
                    .keyword_anytype => break :blk true,
                    .ellipsis3 => break :is_var_args true,
                    else => unreachable,
                }
            } else false;

            const param_name: Zir.NullTerminatedString = if (param.name_token) |name_token| blk: {
                const name_bytes = tree.tokenSlice(name_token);
                if (mem.eql(u8, "_", name_bytes))
                    break :blk .empty;

                const param_name = try astgen.identAsString(name_token);
                if (!is_extern) {
                    try astgen.detectLocalShadowing(params_scope, param_name, name_token, name_bytes, .@"function parameter");
                }
                break :blk param_name;
            } else if (!is_extern) {
                if (param.anytype_ellipsis3) |tok| {
                    return astgen.failTok(tok, "missing parameter name", .{});
                } else {
                    ambiguous: {
                        if (tree.nodes.items(.tag)[param.type_expr] != .identifier) break :ambiguous;
                        const main_token = tree.nodes.items(.main_token)[param.type_expr];
                        const identifier_str = tree.tokenSlice(main_token);
                        if (isPrimitive(identifier_str)) break :ambiguous;
                        return astgen.failNodeNotes(
                            param.type_expr,
                            "missing parameter name or type",
                            .{},
                            &[_]u32{
                                try astgen.errNoteNode(
                                    param.type_expr,
                                    "if this is a name, annotate its type '{s}: T'",
                                    .{identifier_str},
                                ),
                                try astgen.errNoteNode(
                                    param.type_expr,
                                    "if this is a type, give it a name '<name>: {s}'",
                                    .{identifier_str},
                                ),
                            },
                        );
                    }
                    return astgen.failNode(param.type_expr, "missing parameter name", .{});
                }
            } else .empty;

            const param_inst = if (is_anytype) param: {
                const name_token = param.name_token orelse param.anytype_ellipsis3.?;
                const tag: Zir.Inst.Tag = if (is_comptime)
                    .param_anytype_comptime
                else
                    .param_anytype;
                break :param try decl_gz.addStrTok(tag, param_name, name_token);
            } else param: {
                const param_type_node = param.type_expr;
                assert(param_type_node != 0);
                var param_gz = decl_gz.makeSubBlock(scope);
                defer param_gz.unstack();
                const param_type = try fullBodyExpr(&param_gz, params_scope, coerced_type_ri, param_type_node);
                const param_inst_expected: Zir.Inst.Index = @enumFromInt(astgen.instructions.len + 1);
                _ = try param_gz.addBreakWithSrcNode(.break_inline, param_inst_expected, param_type, param_type_node);

                const main_tokens = tree.nodes.items(.main_token);
                const name_token = param.name_token orelse main_tokens[param_type_node];
                const tag: Zir.Inst.Tag = if (is_comptime) .param_comptime else .param;
                const param_inst = try decl_gz.addParam(&param_gz, tag, name_token, param_name, param.first_doc_comment);
                assert(param_inst_expected == param_inst);
                break :param param_inst.toRef();
            };

            if (param_name == .empty or is_extern) continue;

            const sub_scope = try astgen.arena.create(Scope.LocalVal);
            sub_scope.* = .{
                .parent = params_scope,
                .gen_zir = &decl_gz,
                .name = param_name,
                .inst = param_inst,
                .token_src = param.name_token.?,
                .id_cat = .@"function parameter",
            };
            params_scope = &sub_scope.base;
        }
        break :is_var_args false;
    };

    const lib_name = if (fn_proto.lib_name) |lib_name_token| blk: {
        const lib_name_str = try astgen.strLitAsString(lib_name_token);
        const lib_name_slice = astgen.string_bytes.items[@intFromEnum(lib_name_str.index)..][0..lib_name_str.len];
        if (mem.indexOfScalar(u8, lib_name_slice, 0) != null) {
            return astgen.failTok(lib_name_token, "library name cannot contain null bytes", .{});
        } else if (lib_name_str.len == 0) {
            return astgen.failTok(lib_name_token, "library name cannot be empty", .{});
        }
        break :blk lib_name_str.index;
    } else .empty;

    const maybe_bang = tree.firstToken(fn_proto.ast.return_type) - 1;
    const is_inferred_error = token_tags[maybe_bang] == .bang;

    // After creating the function ZIR instruction, it will need to update the break
    // instructions inside the expression blocks for align, addrspace, cc, and ret_ty
    // to use the function instruction as the "block" to break from.

    var align_gz = decl_gz.makeSubBlock(params_scope);
    defer align_gz.unstack();
    const align_ref: Zir.Inst.Ref = if (fn_proto.ast.align_expr == 0) .none else inst: {
        const inst = try expr(&decl_gz, params_scope, coerced_align_ri, fn_proto.ast.align_expr);
        if (align_gz.instructionsSlice().len == 0) {
            // In this case we will send a len=0 body which can be encoded more efficiently.
            break :inst inst;
        }
        _ = try align_gz.addBreak(.break_inline, @enumFromInt(0), inst);
        break :inst inst;
    };

    var addrspace_gz = decl_gz.makeSubBlock(params_scope);
    defer addrspace_gz.unstack();
    const addrspace_ref: Zir.Inst.Ref = if (fn_proto.ast.addrspace_expr == 0) .none else inst: {
        const inst = try expr(&decl_gz, params_scope, coerced_addrspace_ri, fn_proto.ast.addrspace_expr);
        if (addrspace_gz.instructionsSlice().len == 0) {
            // In this case we will send a len=0 body which can be encoded more efficiently.
            break :inst inst;
        }
        _ = try addrspace_gz.addBreak(.break_inline, @enumFromInt(0), inst);
        break :inst inst;
    };

    var section_gz = decl_gz.makeSubBlock(params_scope);
    defer section_gz.unstack();
    const section_ref: Zir.Inst.Ref = if (fn_proto.ast.section_expr == 0) .none else inst: {
        const inst = try expr(&decl_gz, params_scope, .{ .rl = .{ .coerced_ty = .slice_const_u8_type } }, fn_proto.ast.section_expr);
        if (section_gz.instructionsSlice().len == 0) {
            // In this case we will send a len=0 body which can be encoded more efficiently.
            break :inst inst;
        }
        _ = try section_gz.addBreak(.break_inline, @enumFromInt(0), inst);
        break :inst inst;
    };

    var cc_gz = decl_gz.makeSubBlock(params_scope);
    defer cc_gz.unstack();
    const cc_ref: Zir.Inst.Ref = blk: {
        if (fn_proto.ast.callconv_expr != 0) {
            if (has_inline_keyword) {
                return astgen.failNode(
                    fn_proto.ast.callconv_expr,
                    "explicit callconv incompatible with inline keyword",
                    .{},
                );
            }
            const inst = try expr(
                &decl_gz,
                params_scope,
                .{ .rl = .{ .coerced_ty = .calling_convention_type } },
                fn_proto.ast.callconv_expr,
            );
            if (cc_gz.instructionsSlice().len == 0) {
                // In this case we will send a len=0 body which can be encoded more efficiently.
                break :blk inst;
            }
            _ = try cc_gz.addBreak(.break_inline, @enumFromInt(0), inst);
            break :blk inst;
        } else if (is_extern) {
            // note: https://github.com/ziglang/zig/issues/5269
            break :blk .calling_convention_c;
        } else if (has_inline_keyword) {
            break :blk .calling_convention_inline;
        } else {
            break :blk .none;
        }
    };

    var ret_gz = decl_gz.makeSubBlock(params_scope);
    defer ret_gz.unstack();
    const ret_ref: Zir.Inst.Ref = inst: {
        const inst = try fullBodyExpr(&ret_gz, params_scope, coerced_type_ri, fn_proto.ast.return_type);
        if (ret_gz.instructionsSlice().len == 0) {
            // In this case we will send a len=0 body which can be encoded more efficiently.
            break :inst inst;
        }
        _ = try ret_gz.addBreak(.break_inline, @enumFromInt(0), inst);
        break :inst inst;
    };

    const func_inst: Zir.Inst.Ref = if (body_node == 0) func: {
        if (!is_extern) {
            return astgen.failTok(fn_proto.ast.fn_token, "non-extern function has no body", .{});
        }
        if (is_inferred_error) {
            return astgen.failTok(maybe_bang, "function prototype may not have inferred error set", .{});
        }
        break :func try decl_gz.addFunc(.{
            .src_node = decl_node,
            .cc_ref = cc_ref,
            .cc_gz = &cc_gz,
            .align_ref = align_ref,
            .align_gz = &align_gz,
            .ret_ref = ret_ref,
            .ret_gz = &ret_gz,
            .section_ref = section_ref,
            .section_gz = &section_gz,
            .addrspace_ref = addrspace_ref,
            .addrspace_gz = &addrspace_gz,
            .param_block = decl_inst,
            .body_gz = null,
            .lib_name = lib_name,
            .is_var_args = is_var_args,
            .is_inferred_error = false,
            .is_test = false,
            .is_extern = true,
            .is_noinline = is_noinline,
            .noalias_bits = noalias_bits,
        });
    } else func: {
        // as a scope, fn_gz encloses ret_gz, but for instruction list, fn_gz stacks on ret_gz
        fn_gz.instructions_top = ret_gz.instructions.items.len;

        const prev_fn_block = astgen.fn_block;
        const prev_fn_ret_ty = astgen.fn_ret_ty;
        defer {
            astgen.fn_block = prev_fn_block;
            astgen.fn_ret_ty = prev_fn_ret_ty;
        }
        astgen.fn_block = &fn_gz;
        astgen.fn_ret_ty = if (is_inferred_error or ret_ref.toIndex() != null) r: {
            // We're essentially guaranteed to need the return type at some point,
            // since the return type is likely not `void` or `noreturn` so there
            // will probably be an explicit return requiring RLS. Fetch this
            // return type now so the rest of the function can use it.
            break :r try fn_gz.addNode(.ret_type, decl_node);
        } else ret_ref;

        const prev_var_args = astgen.fn_var_args;
        astgen.fn_var_args = is_var_args;
        defer astgen.fn_var_args = prev_var_args;

        astgen.advanceSourceCursorToNode(body_node);
        const lbrace_line = astgen.source_line - decl_gz.decl_line;
        const lbrace_column = astgen.source_column;

        _ = try fullBodyExpr(&fn_gz, params_scope, .{ .rl = .none }, body_node);
        try checkUsed(gz, &fn_gz.base, params_scope);

        if (!fn_gz.endsWithNoReturn()) {
            // As our last action before the return, "pop" the error trace if needed
            _ = try fn_gz.addRestoreErrRetIndex(.ret, .always, decl_node);

            // Add implicit return at end of function.
            _ = try fn_gz.addUnTok(.ret_implicit, .void_value, tree.lastToken(body_node));
        }

        break :func try decl_gz.addFunc(.{
            .src_node = decl_node,
            .cc_ref = cc_ref,
            .cc_gz = &cc_gz,
            .align_ref = align_ref,
            .align_gz = &align_gz,
            .ret_ref = ret_ref,
            .ret_gz = &ret_gz,
            .section_ref = section_ref,
            .section_gz = &section_gz,
            .addrspace_ref = addrspace_ref,
            .addrspace_gz = &addrspace_gz,
            .lbrace_line = lbrace_line,
            .lbrace_column = lbrace_column,
            .param_block = decl_inst,
            .body_gz = &fn_gz,
            .lib_name = lib_name,
            .is_var_args = is_var_args,
            .is_inferred_error = is_inferred_error,
            .is_test = false,
            .is_extern = false,
            .is_noinline = is_noinline,
            .noalias_bits = noalias_bits,
        });
    };

    // We add this at the end so that its instruction index marks the end range
    // of the top level declaration. addFunc already unstacked fn_gz and ret_gz.
    _ = try decl_gz.addBreak(.break_inline, decl_inst, func_inst);

    try setDeclaration(
        decl_inst,
        std.zig.hashSrc(tree.getNodeSource(decl_node)),
        .{ .named = fn_name_token },
        decl_gz.decl_line - gz.decl_line,
        is_pub,
        is_export,
        doc_comment_index,
        &decl_gz,
        // align, linksection, and addrspace are passed in the func instruction in this case.
        // TODO: move them from the function instruction to the declaration instruction?
        null,
    );
}

fn globalVarDecl(
    astgen: *AstGen,
    gz: *GenZir,
    scope: *Scope,
    wip_members: *WipMembers,
    node: Ast.Node.Index,
    var_decl: Ast.full.VarDecl,
) InnerError!void {
    const tree = astgen.tree;
    const token_tags = tree.tokens.items(.tag);

    const is_mutable = token_tags[var_decl.ast.mut_token] == .keyword_var;
    // We do this at the beginning so that the instruction index marks the range start
    // of the top level declaration.
    const decl_inst = try gz.makeBlockInst(.declaration, node);

    const name_token = var_decl.ast.mut_token + 1;
    astgen.advanceSourceCursorToNode(node);

    var block_scope: GenZir = .{
        .parent = scope,
        .decl_node_index = node,
        .decl_line = astgen.source_line,
        .astgen = astgen,
        .is_comptime = true,
        .anon_name_strategy = .parent,
        .instructions = gz.instructions,
        .instructions_top = gz.instructions.items.len,
    };
    defer block_scope.unstack();

    const is_pub = var_decl.visib_token != null;
    const is_export = blk: {
        const maybe_export_token = var_decl.extern_export_token orelse break :blk false;
        break :blk token_tags[maybe_export_token] == .keyword_export;
    };
    const is_extern = blk: {
        const maybe_extern_token = var_decl.extern_export_token orelse break :blk false;
        break :blk token_tags[maybe_extern_token] == .keyword_extern;
    };
    wip_members.nextDecl(decl_inst);

    const is_threadlocal = if (var_decl.threadlocal_token) |tok| blk: {
        if (!is_mutable) {
            return astgen.failTok(tok, "threadlocal variable cannot be constant", .{});
        }
        break :blk true;
    } else false;

    const lib_name = if (var_decl.lib_name) |lib_name_token| blk: {
        const lib_name_str = try astgen.strLitAsString(lib_name_token);
        const lib_name_slice = astgen.string_bytes.items[@intFromEnum(lib_name_str.index)..][0..lib_name_str.len];
        if (mem.indexOfScalar(u8, lib_name_slice, 0) != null) {
            return astgen.failTok(lib_name_token, "library name cannot contain null bytes", .{});
        } else if (lib_name_str.len == 0) {
            return astgen.failTok(lib_name_token, "library name cannot be empty", .{});
        }
        break :blk lib_name_str.index;
    } else .empty;

    const doc_comment_index = try astgen.docCommentAsString(var_decl.firstToken());

    assert(var_decl.comptime_token == null); // handled by parser

    const var_inst: Zir.Inst.Ref = if (var_decl.ast.init_node != 0) vi: {
        if (is_extern) {
            return astgen.failNode(
                var_decl.ast.init_node,
                "extern variables have no initializers",
                .{},
            );
        }

        const type_inst: Zir.Inst.Ref = if (var_decl.ast.type_node != 0)
            try expr(
                &block_scope,
                &block_scope.base,
                coerced_type_ri,
                var_decl.ast.type_node,
            )
        else
            .none;

        const init_inst = try expr(
            &block_scope,
            &block_scope.base,
            if (type_inst != .none) .{ .rl = .{ .ty = type_inst } } else .{ .rl = .none },
            var_decl.ast.init_node,
        );

        if (is_mutable) {
            const var_inst = try block_scope.addVar(.{
                .var_type = type_inst,
                .lib_name = .empty,
                .align_inst = .none, // passed via the decls data
                .init = init_inst,
                .is_extern = false,
                .is_const = !is_mutable,
                .is_threadlocal = is_threadlocal,
            });
            break :vi var_inst;
        } else {
            break :vi init_inst;
        }
    } else if (!is_extern) {
        return astgen.failNode(node, "variables must be initialized", .{});
    } else if (var_decl.ast.type_node != 0) vi: {
        // Extern variable which has an explicit type.
        const type_inst = try typeExpr(&block_scope, &block_scope.base, var_decl.ast.type_node);

        const var_inst = try block_scope.addVar(.{
            .var_type = type_inst,
            .lib_name = lib_name,
            .align_inst = .none, // passed via the decls data
            .init = .none,
            .is_extern = true,
            .is_const = !is_mutable,
            .is_threadlocal = is_threadlocal,
        });
        break :vi var_inst;
    } else {
        return astgen.failNode(node, "unable to infer variable type", .{});
    };

    // We do this at the end so that the instruction index marks the end
    // range of a top level declaration.
    _ = try block_scope.addBreakWithSrcNode(.break_inline, decl_inst, var_inst, node);

    var align_gz = block_scope.makeSubBlock(scope);
    if (var_decl.ast.align_node != 0) {
        const align_inst = try fullBodyExpr(&align_gz, &align_gz.base, coerced_align_ri, var_decl.ast.align_node);
        _ = try align_gz.addBreakWithSrcNode(.break_inline, decl_inst, align_inst, node);
    }

    var linksection_gz = align_gz.makeSubBlock(scope);
    if (var_decl.ast.section_node != 0) {
        const linksection_inst = try fullBodyExpr(&linksection_gz, &linksection_gz.base, coerced_linksection_ri, var_decl.ast.section_node);
        _ = try linksection_gz.addBreakWithSrcNode(.break_inline, decl_inst, linksection_inst, node);
    }

    var addrspace_gz = linksection_gz.makeSubBlock(scope);
    if (var_decl.ast.addrspace_node != 0) {
        const addrspace_inst = try fullBodyExpr(&addrspace_gz, &addrspace_gz.base, coerced_addrspace_ri, var_decl.ast.addrspace_node);
        _ = try addrspace_gz.addBreakWithSrcNode(.break_inline, decl_inst, addrspace_inst, node);
    }

    try setDeclaration(
        decl_inst,
        std.zig.hashSrc(tree.getNodeSource(node)),
        .{ .named = name_token },
        block_scope.decl_line - gz.decl_line,
        is_pub,
        is_export,
        doc_comment_index,
        &block_scope,
        .{
            .align_gz = &align_gz,
            .linksection_gz = &linksection_gz,
            .addrspace_gz = &addrspace_gz,
        },
    );
}

fn comptimeDecl(
    astgen: *AstGen,
    gz: *GenZir,
    scope: *Scope,
    wip_members: *WipMembers,
    node: Ast.Node.Index,
) InnerError!void {
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const body_node = node_datas[node].lhs;

    // Up top so the ZIR instruction index marks the start range of this
    // top-level declaration.
    const decl_inst = try gz.makeBlockInst(.declaration, node);
    wip_members.nextDecl(decl_inst);
    astgen.advanceSourceCursorToNode(node);

    var decl_block: GenZir = .{
        .is_comptime = true,
        .decl_node_index = node,
        .decl_line = astgen.source_line,
        .parent = scope,
        .astgen = astgen,
        .instructions = gz.instructions,
        .instructions_top = gz.instructions.items.len,
    };
    defer decl_block.unstack();

    const block_result = try fullBodyExpr(&decl_block, &decl_block.base, .{ .rl = .none }, body_node);
    if (decl_block.isEmpty() or !decl_block.refIsNoReturn(block_result)) {
        _ = try decl_block.addBreak(.break_inline, decl_inst, .void_value);
    }

    try setDeclaration(
        decl_inst,
        std.zig.hashSrc(tree.getNodeSource(node)),
        .@"comptime",
        decl_block.decl_line - gz.decl_line,
        false,
        false,
        .empty,
        &decl_block,
        null,
    );
}

fn usingnamespaceDecl(
    astgen: *AstGen,
    gz: *GenZir,
    scope: *Scope,
    wip_members: *WipMembers,
    node: Ast.Node.Index,
) InnerError!void {
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);

    const type_expr = node_datas[node].lhs;
    const is_pub = blk: {
        const main_tokens = tree.nodes.items(.main_token);
        const token_tags = tree.tokens.items(.tag);
        const main_token = main_tokens[node];
        break :blk (main_token > 0 and token_tags[main_token - 1] == .keyword_pub);
    };
    // Up top so the ZIR instruction index marks the start range of this
    // top-level declaration.
    const decl_inst = try gz.makeBlockInst(.declaration, node);
    wip_members.nextDecl(decl_inst);
    astgen.advanceSourceCursorToNode(node);

    var decl_block: GenZir = .{
        .is_comptime = true,
        .decl_node_index = node,
        .decl_line = astgen.source_line,
        .parent = scope,
        .astgen = astgen,
        .instructions = gz.instructions,
        .instructions_top = gz.instructions.items.len,
    };
    defer decl_block.unstack();

    const namespace_inst = try typeExpr(&decl_block, &decl_block.base, type_expr);
    _ = try decl_block.addBreak(.break_inline, decl_inst, namespace_inst);

    try setDeclaration(
        decl_inst,
        std.zig.hashSrc(tree.getNodeSource(node)),
        .@"usingnamespace",
        decl_block.decl_line - gz.decl_line,
        is_pub,
        false,
        .empty,
        &decl_block,
        null,
    );
}

fn testDecl(
    astgen: *AstGen,
    gz: *GenZir,
    scope: *Scope,
    wip_members: *WipMembers,
    node: Ast.Node.Index,
) InnerError!void {
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const body_node = node_datas[node].rhs;

    // Up top so the ZIR instruction index marks the start range of this
    // top-level declaration.
    const decl_inst = try gz.makeBlockInst(.declaration, node);

    wip_members.nextDecl(decl_inst);
    astgen.advanceSourceCursorToNode(node);

    var decl_block: GenZir = .{
        .is_comptime = true,
        .decl_node_index = node,
        .decl_line = astgen.source_line,
        .parent = scope,
        .astgen = astgen,
        .instructions = gz.instructions,
        .instructions_top = gz.instructions.items.len,
    };
    defer decl_block.unstack();

    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);
    const test_token = main_tokens[node];
    const test_name_token = test_token + 1;
    const test_name: DeclarationName = switch (token_tags[test_name_token]) {
        else => .unnamed_test,
        .string_literal => .{ .named_test = test_name_token },
        .identifier => blk: {
            const ident_name_raw = tree.tokenSlice(test_name_token);

            if (mem.eql(u8, ident_name_raw, "_")) return astgen.failTok(test_name_token, "'_' used as an identifier without @\"_\" syntax", .{});

            // if not @"" syntax, just use raw token slice
            if (ident_name_raw[0] != '@') {
                if (isPrimitive(ident_name_raw)) return astgen.failTok(test_name_token, "cannot test a primitive", .{});
            }

            // Local variables, including function parameters.
            const name_str_index = try astgen.identAsString(test_name_token);
            var s = scope;
            var found_already: ?Ast.Node.Index = null; // we have found a decl with the same name already
            var num_namespaces_out: u32 = 0;
            var capturing_namespace: ?*Scope.Namespace = null;
            while (true) switch (s.tag) {
                .local_val => {
                    const local_val = s.cast(Scope.LocalVal).?;
                    if (local_val.name == name_str_index) {
                        local_val.used = test_name_token;
                        return astgen.failTokNotes(test_name_token, "cannot test a {s}", .{
                            @tagName(local_val.id_cat),
                        }, &[_]u32{
                            try astgen.errNoteTok(local_val.token_src, "{s} declared here", .{
                                @tagName(local_val.id_cat),
                            }),
                        });
                    }
                    s = local_val.parent;
                },
                .local_ptr => {
                    const local_ptr = s.cast(Scope.LocalPtr).?;
                    if (local_ptr.name == name_str_index) {
                        local_ptr.used = test_name_token;
                        return astgen.failTokNotes(test_name_token, "cannot test a {s}", .{
                            @tagName(local_ptr.id_cat),
                        }, &[_]u32{
                            try astgen.errNoteTok(local_ptr.token_src, "{s} declared here", .{
                                @tagName(local_ptr.id_cat),
                            }),
                        });
                    }
                    s = local_ptr.parent;
                },
                .gen_zir => s = s.cast(GenZir).?.parent,
                .defer_normal, .defer_error => s = s.cast(Scope.Defer).?.parent,
                .namespace => {
                    const ns = s.cast(Scope.Namespace).?;
                    if (ns.decls.get(name_str_index)) |i| {
                        if (found_already) |f| {
                            return astgen.failTokNotes(test_name_token, "ambiguous reference", .{}, &.{
                                try astgen.errNoteNode(f, "declared here", .{}),
                                try astgen.errNoteNode(i, "also declared here", .{}),
                            });
                        }
                        // We found a match but must continue looking for ambiguous references to decls.
                        found_already = i;
                    }
                    num_namespaces_out += 1;
                    capturing_namespace = ns;
                    s = ns.parent;
                },
                .top => break,
            };
            if (found_already == null) {
                const ident_name = try astgen.identifierTokenString(test_name_token);
                return astgen.failTok(test_name_token, "use of undeclared identifier '{s}'", .{ident_name});
            }

            break :blk .{ .decltest = name_str_index };
        },
    };

    var fn_block: GenZir = .{
        .is_comptime = false,
        .decl_node_index = node,
        .decl_line = decl_block.decl_line,
        .parent = &decl_block.base,
        .astgen = astgen,
        .instructions = decl_block.instructions,
        .instructions_top = decl_block.instructions.items.len,
    };
    defer fn_block.unstack();

    const prev_within_fn = astgen.within_fn;
    const prev_fn_block = astgen.fn_block;
    const prev_fn_ret_ty = astgen.fn_ret_ty;
    astgen.within_fn = true;
    astgen.fn_block = &fn_block;
    astgen.fn_ret_ty = .anyerror_void_error_union_type;
    defer {
        astgen.within_fn = prev_within_fn;
        astgen.fn_block = prev_fn_block;
        astgen.fn_ret_ty = prev_fn_ret_ty;
    }

    astgen.advanceSourceCursorToNode(body_node);
    const lbrace_line = astgen.source_line - decl_block.decl_line;
    const lbrace_column = astgen.source_column;

    const block_result = try fullBodyExpr(&fn_block, &fn_block.base, .{ .rl = .none }, body_node);
    if (fn_block.isEmpty() or !fn_block.refIsNoReturn(block_result)) {

        // As our last action before the return, "pop" the error trace if needed
        _ = try fn_block.addRestoreErrRetIndex(.ret, .always, node);

        // Add implicit return at end of function.
        _ = try fn_block.addUnTok(.ret_implicit, .void_value, tree.lastToken(body_node));
    }

    const func_inst = try decl_block.addFunc(.{
        .src_node = node,

        .cc_ref = .none,
        .cc_gz = null,
        .align_ref = .none,
        .align_gz = null,
        .ret_ref = .anyerror_void_error_union_type,
        .ret_gz = null,
        .section_ref = .none,
        .section_gz = null,
        .addrspace_ref = .none,
        .addrspace_gz = null,

        .lbrace_line = lbrace_line,
        .lbrace_column = lbrace_column,
        .param_block = decl_inst,
        .body_gz = &fn_block,
        .lib_name = .empty,
        .is_var_args = false,
        .is_inferred_error = false,
        .is_test = true,
        .is_extern = false,
        .is_noinline = false,
        .noalias_bits = 0,
    });

    _ = try decl_block.addBreak(.break_inline, decl_inst, func_inst);

    try setDeclaration(
        decl_inst,
        std.zig.hashSrc(tree.getNodeSource(node)),
        test_name,
        decl_block.decl_line - gz.decl_line,
        false,
        false,
        .empty,
        &decl_block,
        null,
    );
}

fn structDeclInner(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    container_decl: Ast.full.ContainerDecl,
    layout: std.builtin.Type.ContainerLayout,
    backing_int_node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const decl_inst = try gz.reserveInstructionIndex();

    if (container_decl.ast.members.len == 0 and backing_int_node == 0) {
        try gz.setStruct(decl_inst, .{
            .src_node = node,
            .layout = layout,
            .captures_len = 0,
            .fields_len = 0,
            .decls_len = 0,
            .has_backing_int = false,
            .known_non_opv = false,
            .known_comptime_only = false,
            .is_tuple = false,
            .any_comptime_fields = false,
            .any_default_inits = false,
            .any_aligned_fields = false,
            .fields_hash = std.zig.hashSrc(@tagName(layout)),
        });
        return decl_inst.toRef();
    }

    const astgen = gz.astgen;
    const gpa = astgen.gpa;
    const tree = astgen.tree;

    var namespace: Scope.Namespace = .{
        .parent = scope,
        .node = node,
        .inst = decl_inst,
        .declaring_gz = gz,
        .maybe_generic = astgen.within_fn,
    };
    defer namespace.deinit(gpa);

    // The struct_decl instruction introduces a scope in which the decls of the struct
    // are in scope, so that field types, alignments, and default value expressions
    // can refer to decls within the struct itself.
    astgen.advanceSourceCursorToNode(node);
    var block_scope: GenZir = .{
        .parent = &namespace.base,
        .decl_node_index = node,
        .decl_line = gz.decl_line,
        .astgen = astgen,
        .is_comptime = true,
        .instructions = gz.instructions,
        .instructions_top = gz.instructions.items.len,
    };
    defer block_scope.unstack();

    const scratch_top = astgen.scratch.items.len;
    defer astgen.scratch.items.len = scratch_top;

    var backing_int_body_len: usize = 0;
    const backing_int_ref: Zir.Inst.Ref = blk: {
        if (backing_int_node != 0) {
            if (layout != .@"packed") {
                return astgen.failNode(backing_int_node, "non-packed struct does not support backing integer type", .{});
            } else {
                const backing_int_ref = try typeExpr(&block_scope, &namespace.base, backing_int_node);
                if (!block_scope.isEmpty()) {
                    if (!block_scope.endsWithNoReturn()) {
                        _ = try block_scope.addBreak(.break_inline, decl_inst, backing_int_ref);
                    }

                    const body = block_scope.instructionsSlice();
                    const old_scratch_len = astgen.scratch.items.len;
                    try astgen.scratch.ensureUnusedCapacity(gpa, countBodyLenAfterFixups(astgen, body));
                    appendBodyWithFixupsArrayList(astgen, &astgen.scratch, body);
                    backing_int_body_len = astgen.scratch.items.len - old_scratch_len;
                    block_scope.instructions.items.len = block_scope.instructions_top;
                }
                break :blk backing_int_ref;
            }
        } else {
            break :blk .none;
        }
    };

    const decl_count = try astgen.scanDecls(&namespace, container_decl.ast.members);
    const field_count: u32 = @intCast(container_decl.ast.members.len - decl_count);

    const bits_per_field = 4;
    const max_field_size = 5;
    var wip_members = try WipMembers.init(gpa, &astgen.scratch, decl_count, field_count, bits_per_field, max_field_size);
    defer wip_members.deinit();

    // We will use the scratch buffer, starting here, for the bodies:
    //    bodies: { // for every fields_len
    //        field_type_body_inst: Inst, // for each field_type_body_len
    //        align_body_inst: Inst, // for each align_body_len
    //        init_body_inst: Inst, // for each init_body_len
    //    }
    // Note that the scratch buffer is simultaneously being used by WipMembers, however
    // it will not access any elements beyond this point in the ArrayList. It also
    // accesses via the ArrayList items field so it can handle the scratch buffer being
    // reallocated.
    // No defer needed here because it is handled by `wip_members.deinit()` above.
    const bodies_start = astgen.scratch.items.len;

    const node_tags = tree.nodes.items(.tag);
    const is_tuple = for (container_decl.ast.members) |member_node| {
        const container_field = tree.fullContainerField(member_node) orelse continue;
        if (container_field.ast.tuple_like) break true;
    } else false;

    if (is_tuple) switch (layout) {
        .auto => {},
        .@"extern" => return astgen.failNode(node, "extern tuples are not supported", .{}),
        .@"packed" => return astgen.failNode(node, "packed tuples are not supported", .{}),
    };

    if (is_tuple) for (container_decl.ast.members) |member_node| {
        switch (node_tags[member_node]) {
            .container_field_init,
            .container_field_align,
            .container_field,
            .@"comptime",
            .test_decl,
            => continue,
            else => {
                const tuple_member = for (container_decl.ast.members) |maybe_tuple| switch (node_tags[maybe_tuple]) {
                    .container_field_init,
                    .container_field_align,
                    .container_field,
                    => break maybe_tuple,
                    else => {},
                } else unreachable;
                return astgen.failNodeNotes(
                    member_node,
                    "tuple declarations cannot contain declarations",
                    .{},
                    &[_]u32{
                        try astgen.errNoteNode(tuple_member, "tuple field here", .{}),
                    },
                );
            },
        }
    };

    var fields_hasher = std.zig.SrcHasher.init(.{});
    fields_hasher.update(@tagName(layout));
    if (backing_int_node != 0) {
        fields_hasher.update(tree.getNodeSource(backing_int_node));
    }

    var sfba = std.heap.stackFallback(256, astgen.arena);
    const sfba_allocator = sfba.get();

    var duplicate_names = std.AutoArrayHashMap(Zir.NullTerminatedString, std.ArrayListUnmanaged(Ast.TokenIndex)).init(sfba_allocator);
    try duplicate_names.ensureTotalCapacity(field_count);

    // When there aren't errors, use this to avoid a second iteration.
    var any_duplicate = false;

    var known_non_opv = false;
    var known_comptime_only = false;
    var any_comptime_fields = false;
    var any_aligned_fields = false;
    var any_default_inits = false;
    for (container_decl.ast.members) |member_node| {
        var member = switch (try containerMember(&block_scope, &namespace.base, &wip_members, member_node)) {
            .decl => continue,
            .field => |field| field,
        };

        fields_hasher.update(tree.getNodeSource(member_node));

        if (!is_tuple) {
            const field_name = try astgen.identAsString(member.ast.main_token);

            member.convertToNonTupleLike(astgen.tree.nodes);
            assert(!member.ast.tuple_like);

            wip_members.appendToField(@intFromEnum(field_name));

            const gop = try duplicate_names.getOrPut(field_name);

            if (gop.found_existing) {
                try gop.value_ptr.append(sfba_allocator, member.ast.main_token);
                any_duplicate = true;
            } else {
                gop.value_ptr.* = .{};
                try gop.value_ptr.append(sfba_allocator, member.ast.main_token);
            }
        } else if (!member.ast.tuple_like) {
            return astgen.failTok(member.ast.main_token, "tuple field has a name", .{});
        }

        const doc_comment_index = try astgen.docCommentAsString(member.firstToken());
        wip_members.appendToField(@intFromEnum(doc_comment_index));

        if (member.ast.type_expr == 0) {
            return astgen.failTok(member.ast.main_token, "struct field missing type", .{});
        }

        const field_type = try typeExpr(&block_scope, &namespace.base, member.ast.type_expr);
        const have_type_body = !block_scope.isEmpty();
        const have_align = member.ast.align_expr != 0;
        const have_value = member.ast.value_expr != 0;
        const is_comptime = member.comptime_token != null;

        if (is_comptime) {
            switch (layout) {
                .@"packed" => return astgen.failTok(member.comptime_token.?, "packed struct fields cannot be marked comptime", .{}),
                .@"extern" => return astgen.failTok(member.comptime_token.?, "extern struct fields cannot be marked comptime", .{}),
                .auto => any_comptime_fields = true,
            }
        } else {
            known_non_opv = known_non_opv or
                nodeImpliesMoreThanOnePossibleValue(tree, member.ast.type_expr);
            known_comptime_only = known_comptime_only or
                nodeImpliesComptimeOnly(tree, member.ast.type_expr);
        }
        wip_members.nextField(bits_per_field, .{ have_align, have_value, is_comptime, have_type_body });

        if (have_type_body) {
            if (!block_scope.endsWithNoReturn()) {
                _ = try block_scope.addBreak(.break_inline, decl_inst, field_type);
            }
            const body = block_scope.instructionsSlice();
            const old_scratch_len = astgen.scratch.items.len;
            try astgen.scratch.ensureUnusedCapacity(gpa, countBodyLenAfterFixups(astgen, body));
            appendBodyWithFixupsArrayList(astgen, &astgen.scratch, body);
            wip_members.appendToField(@intCast(astgen.scratch.items.len - old_scratch_len));
            block_scope.instructions.items.len = block_scope.instructions_top;
        } else {
            wip_members.appendToField(@intFromEnum(field_type));
        }

        if (have_align) {
            if (layout == .@"packed") {
                try astgen.appendErrorNode(member.ast.align_expr, "unable to override alignment of packed struct fields", .{});
            }
            any_aligned_fields = true;
            const align_ref = try expr(&block_scope, &namespace.base, coerced_align_ri, member.ast.align_expr);
            if (!block_scope.endsWithNoReturn()) {
                _ = try block_scope.addBreak(.break_inline, decl_inst, align_ref);
            }
            const body = block_scope.instructionsSlice();
            const old_scratch_len = astgen.scratch.items.len;
            try astgen.scratch.ensureUnusedCapacity(gpa, countBodyLenAfterFixups(astgen, body));
            appendBodyWithFixupsArrayList(astgen, &astgen.scratch, body);
            wip_members.appendToField(@intCast(astgen.scratch.items.len - old_scratch_len));
            block_scope.instructions.items.len = block_scope.instructions_top;
        }

        if (have_value) {
            any_default_inits = true;

            // The decl_inst is used as here so that we can easily reconstruct a mapping
            // between it and the field type when the fields inits are analzyed.
            const ri: ResultInfo = .{ .rl = if (field_type == .none) .none else .{ .coerced_ty = decl_inst.toRef() } };

            const default_inst = try expr(&block_scope, &namespace.base, ri, member.ast.value_expr);
            if (!block_scope.endsWithNoReturn()) {
                _ = try block_scope.addBreak(.break_inline, decl_inst, default_inst);
            }
            const body = block_scope.instructionsSlice();
            const old_scratch_len = astgen.scratch.items.len;
            try astgen.scratch.ensureUnusedCapacity(gpa, countBodyLenAfterFixups(astgen, body));
            appendBodyWithFixupsArrayList(astgen, &astgen.scratch, body);
            wip_members.appendToField(@intCast(astgen.scratch.items.len - old_scratch_len));
            block_scope.instructions.items.len = block_scope.instructions_top;
        } else if (member.comptime_token) |comptime_token| {
            return astgen.failTok(comptime_token, "comptime field without default initialization value", .{});
        }
    }

    if (any_duplicate) {
        var it = duplicate_names.iterator();

        while (it.next()) |entry| {
            const record = entry.value_ptr.*;
            if (record.items.len > 1) {
                var error_notes = std.ArrayList(u32).init(astgen.arena);

                for (record.items[1..]) |duplicate| {
                    try error_notes.append(try astgen.errNoteTok(duplicate, "duplicate field here", .{}));
                }

                try error_notes.append(try astgen.errNoteNode(node, "struct declared here", .{}));

                try astgen.appendErrorTokNotes(
                    record.items[0],
                    "duplicate struct field name",
                    .{},
                    error_notes.items,
                );
            }
        }

        return error.AnalysisFail;
    }

    var fields_hash: std.zig.SrcHash = undefined;
    fields_hasher.final(&fields_hash);

    try gz.setStruct(decl_inst, .{
        .src_node = node,
        .layout = layout,
        .captures_len = @intCast(namespace.captures.count()),
        .fields_len = field_count,
        .decls_len = decl_count,
        .has_backing_int = backing_int_ref != .none,
        .known_non_opv = known_non_opv,
        .known_comptime_only = known_comptime_only,
        .is_tuple = is_tuple,
        .any_comptime_fields = any_comptime_fields,
        .any_default_inits = any_default_inits,
        .any_aligned_fields = any_aligned_fields,
        .fields_hash = fields_hash,
    });

    wip_members.finishBits(bits_per_field);
    const decls_slice = wip_members.declsSlice();
    const fields_slice = wip_members.fieldsSlice();
    const bodies_slice = astgen.scratch.items[bodies_start..];
    try astgen.extra.ensureUnusedCapacity(gpa, backing_int_body_len + 2 +
        decls_slice.len + namespace.captures.count() + fields_slice.len + bodies_slice.len);
    astgen.extra.appendSliceAssumeCapacity(@ptrCast(namespace.captures.keys()));
    if (backing_int_ref != .none) {
        astgen.extra.appendAssumeCapacity(@intCast(backing_int_body_len));
        if (backing_int_body_len == 0) {
            astgen.extra.appendAssumeCapacity(@intFromEnum(backing_int_ref));
        } else {
            astgen.extra.appendSliceAssumeCapacity(astgen.scratch.items[scratch_top..][0..backing_int_body_len]);
        }
    }
    astgen.extra.appendSliceAssumeCapacity(decls_slice);
    astgen.extra.appendSliceAssumeCapacity(fields_slice);
    astgen.extra.appendSliceAssumeCapacity(bodies_slice);

    block_scope.unstack();
    return decl_inst.toRef();
}

fn unionDeclInner(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    members: []const Ast.Node.Index,
    layout: std.builtin.Type.ContainerLayout,
    arg_node: Ast.Node.Index,
    auto_enum_tok: ?Ast.TokenIndex,
) InnerError!Zir.Inst.Ref {
    const decl_inst = try gz.reserveInstructionIndex();

    const astgen = gz.astgen;
    const gpa = astgen.gpa;

    var namespace: Scope.Namespace = .{
        .parent = scope,
        .node = node,
        .inst = decl_inst,
        .declaring_gz = gz,
        .maybe_generic = astgen.within_fn,
    };
    defer namespace.deinit(gpa);

    // The union_decl instruction introduces a scope in which the decls of the union
    // are in scope, so that field types, alignments, and default value expressions
    // can refer to decls within the union itself.
    astgen.advanceSourceCursorToNode(node);
    var block_scope: GenZir = .{
        .parent = &namespace.base,
        .decl_node_index = node,
        .decl_line = gz.decl_line,
        .astgen = astgen,
        .is_comptime = true,
        .instructions = gz.instructions,
        .instructions_top = gz.instructions.items.len,
    };
    defer block_scope.unstack();

    const decl_count = try astgen.scanDecls(&namespace, members);
    const field_count: u32 = @intCast(members.len - decl_count);

    if (layout != .auto and (auto_enum_tok != null or arg_node != 0)) {
        if (arg_node != 0) {
            return astgen.failNode(arg_node, "{s} union does not support enum tag type", .{@tagName(layout)});
        } else {
            return astgen.failTok(auto_enum_tok.?, "{s} union does not support enum tag type", .{@tagName(layout)});
        }
    }

    const arg_inst: Zir.Inst.Ref = if (arg_node != 0)
        try typeExpr(&block_scope, &namespace.base, arg_node)
    else
        .none;

    const bits_per_field = 4;
    const max_field_size = 5;
    var any_aligned_fields = false;
    var wip_members = try WipMembers.init(gpa, &astgen.scratch, decl_count, field_count, bits_per_field, max_field_size);
    defer wip_members.deinit();

    var fields_hasher = std.zig.SrcHasher.init(.{});
    fields_hasher.update(@tagName(layout));
    fields_hasher.update(&.{@intFromBool(auto_enum_tok != null)});
    if (arg_node != 0) {
        fields_hasher.update(astgen.tree.getNodeSource(arg_node));
    }

    var sfba = std.heap.stackFallback(256, astgen.arena);
    const sfba_allocator = sfba.get();

    var duplicate_names = std.AutoArrayHashMap(Zir.NullTerminatedString, std.ArrayListUnmanaged(Ast.TokenIndex)).init(sfba_allocator);
    try duplicate_names.ensureTotalCapacity(field_count);

    // When there aren't errors, use this to avoid a second iteration.
    var any_duplicate = false;

    for (members) |member_node| {
        var member = switch (try containerMember(&block_scope, &namespace.base, &wip_members, member_node)) {
            .decl => continue,
            .field => |field| field,
        };
        fields_hasher.update(astgen.tree.getNodeSource(member_node));
        member.convertToNonTupleLike(astgen.tree.nodes);
        if (member.ast.tuple_like) {
            return astgen.failTok(member.ast.main_token, "union field missing name", .{});
        }
        if (member.comptime_token) |comptime_token| {
            return astgen.failTok(comptime_token, "union fields cannot be marked comptime", .{});
        }

        const field_name = try astgen.identAsString(member.ast.main_token);
        wip_members.appendToField(@intFromEnum(field_name));

        const gop = try duplicate_names.getOrPut(field_name);

        if (gop.found_existing) {
            try gop.value_ptr.append(sfba_allocator, member.ast.main_token);
            any_duplicate = true;
        } else {
            gop.value_ptr.* = .{};
            try gop.value_ptr.append(sfba_allocator, member.ast.main_token);
        }

        const doc_comment_index = try astgen.docCommentAsString(member.firstToken());
        wip_members.appendToField(@intFromEnum(doc_comment_index));

        const have_type = member.ast.type_expr != 0;
        const have_align = member.ast.align_expr != 0;
        const have_value = member.ast.value_expr != 0;
        const unused = false;
        wip_members.nextField(bits_per_field, .{ have_type, have_align, have_value, unused });

        if (have_type) {
            const field_type = try typeExpr(&block_scope, &namespace.base, member.ast.type_expr);
            wip_members.appendToField(@intFromEnum(field_type));
        } else if (arg_inst == .none and auto_enum_tok == null) {
            return astgen.failNode(member_node, "union field missing type", .{});
        }
        if (have_align) {
            const align_inst = try expr(&block_scope, &block_scope.base, coerced_align_ri, member.ast.align_expr);
            wip_members.appendToField(@intFromEnum(align_inst));
            any_aligned_fields = true;
        }
        if (have_value) {
            if (arg_inst == .none) {
                return astgen.failNodeNotes(
                    node,
                    "explicitly valued tagged union missing integer tag type",
                    .{},
                    &[_]u32{
                        try astgen.errNoteNode(
                            member.ast.value_expr,
                            "tag value specified here",
                            .{},
                        ),
                    },
                );
            }
            if (auto_enum_tok == null) {
                return astgen.failNodeNotes(
                    node,
                    "explicitly valued tagged union requires inferred enum tag type",
                    .{},
                    &[_]u32{
                        try astgen.errNoteNode(
                            member.ast.value_expr,
                            "tag value specified here",
                            .{},
                        ),
                    },
                );
            }
            const tag_value = try expr(&block_scope, &block_scope.base, .{ .rl = .{ .ty = arg_inst } }, member.ast.value_expr);
            wip_members.appendToField(@intFromEnum(tag_value));
        }
    }

    if (any_duplicate) {
        var it = duplicate_names.iterator();

        while (it.next()) |entry| {
            const record = entry.value_ptr.*;
            if (record.items.len > 1) {
                var error_notes = std.ArrayList(u32).init(astgen.arena);

                for (record.items[1..]) |duplicate| {
                    try error_notes.append(try astgen.errNoteTok(duplicate, "duplicate field here", .{}));
                }

                try error_notes.append(try astgen.errNoteNode(node, "union declared here", .{}));

                try astgen.appendErrorTokNotes(
                    record.items[0],
                    "duplicate union field name",
                    .{},
                    error_notes.items,
                );
            }
        }

        return error.AnalysisFail;
    }

    var fields_hash: std.zig.SrcHash = undefined;
    fields_hasher.final(&fields_hash);

    if (!block_scope.isEmpty()) {
        _ = try block_scope.addBreak(.break_inline, decl_inst, .void_value);
    }

    const body = block_scope.instructionsSlice();
    const body_len = astgen.countBodyLenAfterFixups(body);

    try gz.setUnion(decl_inst, .{
        .src_node = node,
        .layout = layout,
        .tag_type = arg_inst,
        .captures_len = @intCast(namespace.captures.count()),
        .body_len = body_len,
        .fields_len = field_count,
        .decls_len = decl_count,
        .auto_enum_tag = auto_enum_tok != null,
        .any_aligned_fields = any_aligned_fields,
        .fields_hash = fields_hash,
    });

    wip_members.finishBits(bits_per_field);
    const decls_slice = wip_members.declsSlice();
    const fields_slice = wip_members.fieldsSlice();
    try astgen.extra.ensureUnusedCapacity(gpa, namespace.captures.count() + decls_slice.len + body_len + fields_slice.len);
    astgen.extra.appendSliceAssumeCapacity(@ptrCast(namespace.captures.keys()));
    astgen.extra.appendSliceAssumeCapacity(decls_slice);
    astgen.appendBodyWithFixups(body);
    astgen.extra.appendSliceAssumeCapacity(fields_slice);

    block_scope.unstack();
    return decl_inst.toRef();
}

fn containerDecl(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    container_decl: Ast.full.ContainerDecl,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const gpa = astgen.gpa;
    const tree = astgen.tree;
    const token_tags = tree.tokens.items(.tag);

    const prev_fn_block = astgen.fn_block;
    astgen.fn_block = null;
    defer astgen.fn_block = prev_fn_block;

    // We must not create any types until Sema. Here the goal is only to generate
    // ZIR for all the field types, alignments, and default value expressions.

    switch (token_tags[container_decl.ast.main_token]) {
        .keyword_struct => {
            const layout: std.builtin.Type.ContainerLayout = if (container_decl.layout_token) |t| switch (token_tags[t]) {
                .keyword_packed => .@"packed",
                .keyword_extern => .@"extern",
                else => unreachable,
            } else .auto;

            const result = try structDeclInner(gz, scope, node, container_decl, layout, container_decl.ast.arg);
            return rvalue(gz, ri, result, node);
        },
        .keyword_union => {
            const layout: std.builtin.Type.ContainerLayout = if (container_decl.layout_token) |t| switch (token_tags[t]) {
                .keyword_packed => .@"packed",
                .keyword_extern => .@"extern",
                else => unreachable,
            } else .auto;

            const result = try unionDeclInner(gz, scope, node, container_decl.ast.members, layout, container_decl.ast.arg, container_decl.ast.enum_token);
            return rvalue(gz, ri, result, node);
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
                var nonexhaustive_node: Ast.Node.Index = 0;
                var nonfinal_nonexhaustive = false;
                for (container_decl.ast.members) |member_node| {
                    var member = tree.fullContainerField(member_node) orelse {
                        decls += 1;
                        continue;
                    };
                    member.convertToNonTupleLike(astgen.tree.nodes);
                    if (member.ast.tuple_like) {
                        return astgen.failTok(member.ast.main_token, "enum field missing name", .{});
                    }
                    if (member.comptime_token) |comptime_token| {
                        return astgen.failTok(comptime_token, "enum fields cannot be marked comptime", .{});
                    }
                    if (member.ast.type_expr != 0) {
                        return astgen.failNodeNotes(
                            member.ast.type_expr,
                            "enum fields do not have types",
                            .{},
                            &[_]u32{
                                try astgen.errNoteNode(
                                    node,
                                    "consider 'union(enum)' here to make it a tagged union",
                                    .{},
                                ),
                            },
                        );
                    }
                    if (member.ast.align_expr != 0) {
                        return astgen.failNode(member.ast.align_expr, "enum fields cannot be aligned", .{});
                    }

                    const name_token = member.ast.main_token;
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
                    } else if (nonexhaustive_node != 0) {
                        nonfinal_nonexhaustive = true;
                    }
                    total_fields += 1;
                    if (member.ast.value_expr != 0) {
                        if (container_decl.ast.arg == 0) {
                            return astgen.failNode(member.ast.value_expr, "value assigned to enum tag with inferred tag type", .{});
                        }
                        values += 1;
                    }
                }
                if (nonfinal_nonexhaustive) {
                    return astgen.failNode(nonexhaustive_node, "'_' field of non-exhaustive enum must be last", .{});
                }
                break :blk .{
                    .total_fields = total_fields,
                    .values = values,
                    .decls = decls,
                    .nonexhaustive_node = nonexhaustive_node,
                };
            };
            if (counts.nonexhaustive_node != 0 and container_decl.ast.arg == 0) {
                try astgen.appendErrorNodeNotes(
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
            const nonexhaustive = counts.nonexhaustive_node != 0;

            const decl_inst = try gz.reserveInstructionIndex();

            var namespace: Scope.Namespace = .{
                .parent = scope,
                .node = node,
                .inst = decl_inst,
                .declaring_gz = gz,
                .maybe_generic = astgen.within_fn,
            };
            defer namespace.deinit(gpa);

            // The enum_decl instruction introduces a scope in which the decls of the enum
            // are in scope, so that tag values can refer to decls within the enum itself.
            astgen.advanceSourceCursorToNode(node);
            var block_scope: GenZir = .{
                .parent = &namespace.base,
                .decl_node_index = node,
                .decl_line = gz.decl_line,
                .astgen = astgen,
                .is_comptime = true,
                .instructions = gz.instructions,
                .instructions_top = gz.instructions.items.len,
            };
            defer block_scope.unstack();

            _ = try astgen.scanDecls(&namespace, container_decl.ast.members);
            namespace.base.tag = .namespace;

            const arg_inst: Zir.Inst.Ref = if (container_decl.ast.arg != 0)
                try comptimeExpr(&block_scope, &namespace.base, coerced_type_ri, container_decl.ast.arg)
            else
                .none;

            const bits_per_field = 1;
            const max_field_size = 3;
            var wip_members = try WipMembers.init(gpa, &astgen.scratch, @intCast(counts.decls), @intCast(counts.total_fields), bits_per_field, max_field_size);
            defer wip_members.deinit();

            var fields_hasher = std.zig.SrcHasher.init(.{});
            if (container_decl.ast.arg != 0) {
                fields_hasher.update(tree.getNodeSource(container_decl.ast.arg));
            }
            fields_hasher.update(&.{@intFromBool(nonexhaustive)});

            var sfba = std.heap.stackFallback(256, astgen.arena);
            const sfba_allocator = sfba.get();

            var duplicate_names = std.AutoArrayHashMap(Zir.NullTerminatedString, std.ArrayListUnmanaged(Ast.TokenIndex)).init(sfba_allocator);
            try duplicate_names.ensureTotalCapacity(counts.total_fields);

            // When there aren't errors, use this to avoid a second iteration.
            var any_duplicate = false;

            for (container_decl.ast.members) |member_node| {
                if (member_node == counts.nonexhaustive_node)
                    continue;
                fields_hasher.update(tree.getNodeSource(member_node));
                var member = switch (try containerMember(&block_scope, &namespace.base, &wip_members, member_node)) {
                    .decl => continue,
                    .field => |field| field,
                };
                member.convertToNonTupleLike(astgen.tree.nodes);
                assert(member.comptime_token == null);
                assert(member.ast.type_expr == 0);
                assert(member.ast.align_expr == 0);

                const field_name = try astgen.identAsString(member.ast.main_token);
                wip_members.appendToField(@intFromEnum(field_name));

                const gop = try duplicate_names.getOrPut(field_name);

                if (gop.found_existing) {
                    try gop.value_ptr.append(sfba_allocator, member.ast.main_token);
                    any_duplicate = true;
                } else {
                    gop.value_ptr.* = .{};
                    try gop.value_ptr.append(sfba_allocator, member.ast.main_token);
                }

                const doc_comment_index = try astgen.docCommentAsString(member.firstToken());
                wip_members.appendToField(@intFromEnum(doc_comment_index));

                const have_value = member.ast.value_expr != 0;
                wip_members.nextField(bits_per_field, .{have_value});

                if (have_value) {
                    if (arg_inst == .none) {
                        return astgen.failNodeNotes(
                            node,
                            "explicitly valued enum missing integer tag type",
                            .{},
                            &[_]u32{
                                try astgen.errNoteNode(
                                    member.ast.value_expr,
                                    "tag value specified here",
                                    .{},
                                ),
                            },
                        );
                    }
                    const tag_value_inst = try expr(&block_scope, &namespace.base, .{ .rl = .{ .ty = arg_inst } }, member.ast.value_expr);
                    wip_members.appendToField(@intFromEnum(tag_value_inst));
                }
            }

            if (any_duplicate) {
                var it = duplicate_names.iterator();

                while (it.next()) |entry| {
                    const record = entry.value_ptr.*;
                    if (record.items.len > 1) {
                        var error_notes = std.ArrayList(u32).init(astgen.arena);

                        for (record.items[1..]) |duplicate| {
                            try error_notes.append(try astgen.errNoteTok(duplicate, "duplicate field here", .{}));
                        }

                        try error_notes.append(try astgen.errNoteNode(node, "enum declared here", .{}));

                        try astgen.appendErrorTokNotes(
                            record.items[0],
                            "duplicate enum field name",
                            .{},
                            error_notes.items,
                        );
                    }
                }

                return error.AnalysisFail;
            }

            if (!block_scope.isEmpty()) {
                _ = try block_scope.addBreak(.break_inline, decl_inst, .void_value);
            }

            var fields_hash: std.zig.SrcHash = undefined;
            fields_hasher.final(&fields_hash);

            const body = block_scope.instructionsSlice();
            const body_len = astgen.countBodyLenAfterFixups(body);

            try gz.setEnum(decl_inst, .{
                .src_node = node,
                .nonexhaustive = nonexhaustive,
                .tag_type = arg_inst,
                .captures_len = @intCast(namespace.captures.count()),
                .body_len = body_len,
                .fields_len = @intCast(counts.total_fields),
                .decls_len = @intCast(counts.decls),
                .fields_hash = fields_hash,
            });

            wip_members.finishBits(bits_per_field);
            const decls_slice = wip_members.declsSlice();
            const fields_slice = wip_members.fieldsSlice();
            try astgen.extra.ensureUnusedCapacity(gpa, namespace.captures.count() + decls_slice.len + body_len + fields_slice.len);
            astgen.extra.appendSliceAssumeCapacity(@ptrCast(namespace.captures.keys()));
            astgen.extra.appendSliceAssumeCapacity(decls_slice);
            astgen.appendBodyWithFixups(body);
            astgen.extra.appendSliceAssumeCapacity(fields_slice);

            block_scope.unstack();
            return rvalue(gz, ri, decl_inst.toRef(), node);
        },
        .keyword_opaque => {
            assert(container_decl.ast.arg == 0);

            const decl_inst = try gz.reserveInstructionIndex();

            var namespace: Scope.Namespace = .{
                .parent = scope,
                .node = node,
                .inst = decl_inst,
                .declaring_gz = gz,
                .maybe_generic = astgen.within_fn,
            };
            defer namespace.deinit(gpa);

            astgen.advanceSourceCursorToNode(node);
            var block_scope: GenZir = .{
                .parent = &namespace.base,
                .decl_node_index = node,
                .decl_line = gz.decl_line,
                .astgen = astgen,
                .is_comptime = true,
                .instructions = gz.instructions,
                .instructions_top = gz.instructions.items.len,
            };
            defer block_scope.unstack();

            const decl_count = try astgen.scanDecls(&namespace, container_decl.ast.members);

            var wip_members = try WipMembers.init(gpa, &astgen.scratch, decl_count, 0, 0, 0);
            defer wip_members.deinit();

            for (container_decl.ast.members) |member_node| {
                const res = try containerMember(&block_scope, &namespace.base, &wip_members, member_node);
                if (res == .field) {
                    return astgen.failNode(member_node, "opaque types cannot have fields", .{});
                }
            }

            try gz.setOpaque(decl_inst, .{
                .src_node = node,
                .captures_len = @intCast(namespace.captures.count()),
                .decls_len = decl_count,
            });

            wip_members.finishBits(0);
            const decls_slice = wip_members.declsSlice();
            try astgen.extra.ensureUnusedCapacity(gpa, namespace.captures.count() + decls_slice.len);
            astgen.extra.appendSliceAssumeCapacity(@ptrCast(namespace.captures.keys()));
            astgen.extra.appendSliceAssumeCapacity(decls_slice);

            block_scope.unstack();
            return rvalue(gz, ri, decl_inst.toRef(), node);
        },
        else => unreachable,
    }
}

const ContainerMemberResult = union(enum) { decl, field: Ast.full.ContainerField };

fn containerMember(
    gz: *GenZir,
    scope: *Scope,
    wip_members: *WipMembers,
    member_node: Ast.Node.Index,
) InnerError!ContainerMemberResult {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);
    switch (node_tags[member_node]) {
        .container_field_init,
        .container_field_align,
        .container_field,
        => return ContainerMemberResult{ .field = tree.fullContainerField(member_node).? },

        .fn_proto,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto_simple,
        .fn_decl,
        => {
            var buf: [1]Ast.Node.Index = undefined;
            const full = tree.fullFnProto(&buf, member_node).?;
            const body = if (node_tags[member_node] == .fn_decl) node_datas[member_node].rhs else 0;

            astgen.fnDecl(gz, scope, wip_members, member_node, body, full) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => {},
            };
        },

        .global_var_decl,
        .local_var_decl,
        .simple_var_decl,
        .aligned_var_decl,
        => {
            astgen.globalVarDecl(gz, scope, wip_members, member_node, tree.fullVarDecl(member_node).?) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => {},
            };
        },

        .@"comptime" => {
            astgen.comptimeDecl(gz, scope, wip_members, member_node) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => {},
            };
        },
        .@"usingnamespace" => {
            astgen.usingnamespaceDecl(gz, scope, wip_members, member_node) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => {},
            };
        },
        .test_decl => {
            astgen.testDecl(gz, scope, wip_members, member_node) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.AnalysisFail => {},
            };
        },
        else => unreachable,
    }
    return .decl;
}

fn errorSetDecl(gz: *GenZir, ri: ResultInfo, node: Ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const gpa = astgen.gpa;
    const tree = astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);

    const payload_index = try reserveExtra(astgen, @typeInfo(Zir.Inst.ErrorSetDecl).Struct.fields.len);
    var fields_len: usize = 0;
    {
        var idents: std.AutoHashMapUnmanaged(Zir.NullTerminatedString, Ast.TokenIndex) = .{};
        defer idents.deinit(gpa);

        const error_token = main_tokens[node];
        var tok_i = error_token + 2;
        while (true) : (tok_i += 1) {
            switch (token_tags[tok_i]) {
                .doc_comment, .comma => {},
                .identifier => {
                    const str_index = try astgen.identAsString(tok_i);
                    const gop = try idents.getOrPut(gpa, str_index);
                    if (gop.found_existing) {
                        const name = try gpa.dupe(u8, mem.span(astgen.nullTerminatedString(str_index)));
                        defer gpa.free(name);
                        return astgen.failTokNotes(
                            tok_i,
                            "duplicate error set field '{s}'",
                            .{name},
                            &[_]u32{
                                try astgen.errNoteTok(
                                    gop.value_ptr.*,
                                    "previous declaration here",
                                    .{},
                                ),
                            },
                        );
                    }
                    gop.value_ptr.* = tok_i;

                    try astgen.extra.ensureUnusedCapacity(gpa, 2);
                    astgen.extra.appendAssumeCapacity(@intFromEnum(str_index));
                    const doc_comment_index = try astgen.docCommentAsString(tok_i);
                    astgen.extra.appendAssumeCapacity(@intFromEnum(doc_comment_index));
                    fields_len += 1;
                },
                .r_brace => break,
                else => unreachable,
            }
        }
    }

    setExtra(astgen, payload_index, Zir.Inst.ErrorSetDecl{
        .fields_len = @intCast(fields_len),
    });
    const result = try gz.addPlNodePayloadIndex(.error_set_decl, node, payload_index);
    return rvalue(gz, ri, result, node);
}

fn tryExpr(
    parent_gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    operand_node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;

    const fn_block = astgen.fn_block orelse {
        return astgen.failNode(node, "'try' outside function scope", .{});
    };

    if (parent_gz.any_defer_node != 0) {
        return astgen.failNodeNotes(node, "'try' not allowed inside defer expression", .{}, &.{
            try astgen.errNoteNode(
                parent_gz.any_defer_node,
                "defer expression here",
                .{},
            ),
        });
    }

    // Ensure debug line/column information is emitted for this try expression.
    // Then we will save the line/column so that we can emit another one that goes
    // "backwards" because we want to evaluate the operand, but then put the debug
    // info back at the try keyword for error return tracing.
    if (!parent_gz.is_comptime) {
        try emitDbgNode(parent_gz, node);
    }
    const try_lc = LineColumn{ astgen.source_line - parent_gz.decl_line, astgen.source_column };

    const operand_ri: ResultInfo = switch (ri.rl) {
        .ref, .ref_coerced_ty => .{ .rl = .ref, .ctx = .error_handling_expr },
        else => .{ .rl = .none, .ctx = .error_handling_expr },
    };
    // This could be a pointer or value depending on the `ri` parameter.
    const operand = try reachableExpr(parent_gz, scope, operand_ri, operand_node, node);
    const block_tag: Zir.Inst.Tag = if (operand_ri.rl == .ref) .try_ptr else .@"try";
    const try_inst = try parent_gz.makeBlockInst(block_tag, node);
    try parent_gz.instructions.append(astgen.gpa, try_inst);

    var else_scope = parent_gz.makeSubBlock(scope);
    defer else_scope.unstack();

    const err_tag = switch (ri.rl) {
        .ref, .ref_coerced_ty => Zir.Inst.Tag.err_union_code_ptr,
        else => Zir.Inst.Tag.err_union_code,
    };
    const err_code = try else_scope.addUnNode(err_tag, operand, node);
    try genDefers(&else_scope, &fn_block.base, scope, .{ .both = err_code });
    try emitDbgStmt(&else_scope, try_lc);
    _ = try else_scope.addUnNode(.ret_node, err_code, node);

    try else_scope.setTryBody(try_inst, operand);
    const result = try_inst.toRef();
    switch (ri.rl) {
        .ref, .ref_coerced_ty => return result,
        else => return rvalue(parent_gz, ri, result, node),
    }
}

fn orelseCatchExpr(
    parent_gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    lhs: Ast.Node.Index,
    cond_op: Zir.Inst.Tag,
    unwrap_op: Zir.Inst.Tag,
    unwrap_code_op: Zir.Inst.Tag,
    rhs: Ast.Node.Index,
    payload_token: ?Ast.TokenIndex,
) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;
    const tree = astgen.tree;

    const need_rl = astgen.nodes_need_rl.contains(node);
    const block_ri: ResultInfo = if (need_rl) ri else .{
        .rl = switch (ri.rl) {
            .ptr => .{ .ty = (try ri.rl.resultType(parent_gz, node)).? },
            .inferred_ptr => .none,
            else => ri.rl,
        },
        .ctx = ri.ctx,
    };
    // We need to call `rvalue` to write through to the pointer only if we had a
    // result pointer and aren't forwarding it.
    const LocTag = @typeInfo(ResultInfo.Loc).Union.tag_type.?;
    const need_result_rvalue = @as(LocTag, block_ri.rl) != @as(LocTag, ri.rl);

    const do_err_trace = astgen.fn_block != null and (cond_op == .is_non_err or cond_op == .is_non_err_ptr);

    var block_scope = parent_gz.makeSubBlock(scope);
    block_scope.setBreakResultInfo(block_ri);
    defer block_scope.unstack();

    const operand_ri: ResultInfo = switch (block_scope.break_result_info.rl) {
        .ref, .ref_coerced_ty => .{ .rl = .ref, .ctx = if (do_err_trace) .error_handling_expr else .none },
        else => .{ .rl = .none, .ctx = if (do_err_trace) .error_handling_expr else .none },
    };
    // This could be a pointer or value depending on the `operand_ri` parameter.
    // We cannot use `block_scope.break_result_info` because that has the bare
    // type, whereas this expression has the optional type. Later we make
    // up for this fact by calling rvalue on the else branch.
    const operand = try reachableExpr(&block_scope, &block_scope.base, operand_ri, lhs, rhs);
    const cond = try block_scope.addUnNode(cond_op, operand, node);
    const condbr = try block_scope.addCondBr(.condbr, node);

    const block = try parent_gz.makeBlockInst(.block, node);
    try block_scope.setBlockBody(block);
    // block_scope unstacked now, can add new instructions to parent_gz
    try parent_gz.instructions.append(astgen.gpa, block);

    var then_scope = block_scope.makeSubBlock(scope);
    defer then_scope.unstack();

    // This could be a pointer or value depending on `unwrap_op`.
    const unwrapped_payload = try then_scope.addUnNode(unwrap_op, operand, node);
    const then_result = switch (ri.rl) {
        .ref, .ref_coerced_ty => unwrapped_payload,
        else => try rvalue(&then_scope, block_scope.break_result_info, unwrapped_payload, node),
    };
    _ = try then_scope.addBreakWithSrcNode(.@"break", block, then_result, node);

    var else_scope = block_scope.makeSubBlock(scope);
    defer else_scope.unstack();

    // We know that the operand (almost certainly) modified the error return trace,
    // so signal to Sema that it should save the new index for restoring later.
    if (do_err_trace and nodeMayAppendToErrorTrace(tree, lhs))
        _ = try else_scope.addSaveErrRetIndex(.always);

    var err_val_scope: Scope.LocalVal = undefined;
    const else_sub_scope = blk: {
        const payload = payload_token orelse break :blk &else_scope.base;
        const err_str = tree.tokenSlice(payload);
        if (mem.eql(u8, err_str, "_")) {
            return astgen.failTok(payload, "discard of error capture; omit it instead", .{});
        }
        const err_name = try astgen.identAsString(payload);

        try astgen.detectLocalShadowing(scope, err_name, payload, err_str, .capture);

        err_val_scope = .{
            .parent = &else_scope.base,
            .gen_zir = &else_scope,
            .name = err_name,
            .inst = try else_scope.addUnNode(unwrap_code_op, operand, node),
            .token_src = payload,
            .id_cat = .capture,
        };
        break :blk &err_val_scope.base;
    };

    const else_result = try fullBodyExpr(&else_scope, else_sub_scope, block_scope.break_result_info, rhs);
    if (!else_scope.endsWithNoReturn()) {
        // As our last action before the break, "pop" the error trace if needed
        if (do_err_trace)
            try restoreErrRetIndex(&else_scope, .{ .block = block }, block_scope.break_result_info, rhs, else_result);

        _ = try else_scope.addBreakWithSrcNode(.@"break", block, else_result, rhs);
    }
    try checkUsed(parent_gz, &else_scope.base, else_sub_scope);

    try setCondBrPayload(condbr, cond, &then_scope, &else_scope);

    if (need_result_rvalue) {
        return rvalue(parent_gz, ri, block.toRef(), node);
    } else {
        return block.toRef();
    }
}

/// Return whether the identifier names of two tokens are equal. Resolves @""
/// tokens without allocating.
/// OK in theory it could do it without allocating. This implementation
/// allocates when the @"" form is used.
fn tokenIdentEql(astgen: *AstGen, token1: Ast.TokenIndex, token2: Ast.TokenIndex) !bool {
    const ident_name_1 = try astgen.identifierTokenString(token1);
    const ident_name_2 = try astgen.identifierTokenString(token2);
    return mem.eql(u8, ident_name_1, ident_name_2);
}

fn fieldAccess(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    switch (ri.rl) {
        .ref, .ref_coerced_ty => return addFieldAccess(.field_ptr, gz, scope, .{ .rl = .ref }, node),
        else => {
            const access = try addFieldAccess(.field_val, gz, scope, .{ .rl = .none }, node);
            return rvalue(gz, ri, access, node);
        },
    }
}

fn addFieldAccess(
    tag: Zir.Inst.Tag,
    gz: *GenZir,
    scope: *Scope,
    lhs_ri: ResultInfo,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const node_datas = tree.nodes.items(.data);

    const object_node = node_datas[node].lhs;
    const dot_token = main_tokens[node];
    const field_ident = dot_token + 1;
    const str_index = try astgen.identAsString(field_ident);
    const lhs = try expr(gz, scope, lhs_ri, object_node);

    const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);
    try emitDbgStmt(gz, cursor);

    return gz.addPlNode(tag, node, Zir.Inst.Field{
        .lhs = lhs,
        .field_name_start = str_index,
    });
}

fn arrayAccess(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const tree = gz.astgen.tree;
    const node_datas = tree.nodes.items(.data);
    switch (ri.rl) {
        .ref, .ref_coerced_ty => {
            const lhs = try expr(gz, scope, .{ .rl = .ref }, node_datas[node].lhs);

            const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);

            const rhs = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, node_datas[node].rhs);
            try emitDbgStmt(gz, cursor);

            return gz.addPlNode(.elem_ptr_node, node, Zir.Inst.Bin{ .lhs = lhs, .rhs = rhs });
        },
        else => {
            const lhs = try expr(gz, scope, .{ .rl = .none }, node_datas[node].lhs);

            const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);

            const rhs = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, node_datas[node].rhs);
            try emitDbgStmt(gz, cursor);

            return rvalue(gz, ri, try gz.addPlNode(.elem_val_node, node, Zir.Inst.Bin{ .lhs = lhs, .rhs = rhs }), node);
        },
    }
}

fn simpleBinOp(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    op_inst_tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);

    if (op_inst_tag == .cmp_neq or op_inst_tag == .cmp_eq) {
        const node_tags = tree.nodes.items(.tag);
        const str = if (op_inst_tag == .cmp_eq) "==" else "!=";
        if (node_tags[node_datas[node].lhs] == .string_literal or
            node_tags[node_datas[node].rhs] == .string_literal)
            return astgen.failNode(node, "cannot compare strings with {s}", .{str});
    }

    const lhs = try reachableExpr(gz, scope, .{ .rl = .none }, node_datas[node].lhs, node);
    const cursor = switch (op_inst_tag) {
        .add, .sub, .mul, .div, .mod_rem => maybeAdvanceSourceCursorToMainToken(gz, node),
        else => undefined,
    };
    const rhs = try reachableExpr(gz, scope, .{ .rl = .none }, node_datas[node].rhs, node);

    switch (op_inst_tag) {
        .add, .sub, .mul, .div, .mod_rem => {
            try emitDbgStmt(gz, cursor);
        },
        else => {},
    }
    const result = try gz.addPlNode(op_inst_tag, node, Zir.Inst.Bin{ .lhs = lhs, .rhs = rhs });
    return rvalue(gz, ri, result, node);
}

fn simpleStrTok(
    gz: *GenZir,
    ri: ResultInfo,
    ident_token: Ast.TokenIndex,
    node: Ast.Node.Index,
    op_inst_tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const str_index = try astgen.identAsString(ident_token);
    const result = try gz.addStrTok(op_inst_tag, str_index, ident_token);
    return rvalue(gz, ri, result, node);
}

fn boolBinOp(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    zir_tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);

    const lhs = try expr(gz, scope, coerced_bool_ri, node_datas[node].lhs);
    const bool_br = (try gz.addPlNodePayloadIndex(zir_tag, node, undefined)).toIndex().?;

    var rhs_scope = gz.makeSubBlock(scope);
    defer rhs_scope.unstack();
    const rhs = try fullBodyExpr(&rhs_scope, &rhs_scope.base, coerced_bool_ri, node_datas[node].rhs);
    if (!gz.refIsNoReturn(rhs)) {
        _ = try rhs_scope.addBreakWithSrcNode(.break_inline, bool_br, rhs, node_datas[node].rhs);
    }
    try rhs_scope.setBoolBrBody(bool_br, lhs);

    const block_ref = bool_br.toRef();
    return rvalue(gz, ri, block_ref, node);
}

fn ifExpr(
    parent_gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    if_full: Ast.full.If,
) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;
    const tree = astgen.tree;
    const token_tags = tree.tokens.items(.tag);

    const do_err_trace = astgen.fn_block != null and if_full.error_token != null;

    const need_rl = astgen.nodes_need_rl.contains(node);
    const block_ri: ResultInfo = if (need_rl) ri else .{
        .rl = switch (ri.rl) {
            .ptr => .{ .ty = (try ri.rl.resultType(parent_gz, node)).? },
            .inferred_ptr => .none,
            else => ri.rl,
        },
        .ctx = ri.ctx,
    };
    // We need to call `rvalue` to write through to the pointer only if we had a
    // result pointer and aren't forwarding it.
    const LocTag = @typeInfo(ResultInfo.Loc).Union.tag_type.?;
    const need_result_rvalue = @as(LocTag, block_ri.rl) != @as(LocTag, ri.rl);

    var block_scope = parent_gz.makeSubBlock(scope);
    block_scope.setBreakResultInfo(block_ri);
    defer block_scope.unstack();

    const payload_is_ref = if (if_full.payload_token) |payload_token|
        token_tags[payload_token] == .asterisk
    else
        false;

    try emitDbgNode(parent_gz, if_full.ast.cond_expr);
    const cond: struct {
        inst: Zir.Inst.Ref,
        bool_bit: Zir.Inst.Ref,
    } = c: {
        if (if_full.error_token) |_| {
            const cond_ri: ResultInfo = .{ .rl = if (payload_is_ref) .ref else .none, .ctx = .error_handling_expr };
            const err_union = try expr(&block_scope, &block_scope.base, cond_ri, if_full.ast.cond_expr);
            const tag: Zir.Inst.Tag = if (payload_is_ref) .is_non_err_ptr else .is_non_err;
            break :c .{
                .inst = err_union,
                .bool_bit = try block_scope.addUnNode(tag, err_union, if_full.ast.cond_expr),
            };
        } else if (if_full.payload_token) |_| {
            const cond_ri: ResultInfo = .{ .rl = if (payload_is_ref) .ref else .none };
            const optional = try expr(&block_scope, &block_scope.base, cond_ri, if_full.ast.cond_expr);
            const tag: Zir.Inst.Tag = if (payload_is_ref) .is_non_null_ptr else .is_non_null;
            break :c .{
                .inst = optional,
                .bool_bit = try block_scope.addUnNode(tag, optional, if_full.ast.cond_expr),
            };
        } else {
            const cond = try expr(&block_scope, &block_scope.base, coerced_bool_ri, if_full.ast.cond_expr);
            break :c .{
                .inst = cond,
                .bool_bit = cond,
            };
        }
    };

    const condbr = try block_scope.addCondBr(.condbr, node);

    const block = try parent_gz.makeBlockInst(.block, node);
    try block_scope.setBlockBody(block);
    // block_scope unstacked now, can add new instructions to parent_gz
    try parent_gz.instructions.append(astgen.gpa, block);

    var then_scope = parent_gz.makeSubBlock(scope);
    defer then_scope.unstack();

    var payload_val_scope: Scope.LocalVal = undefined;

    const then_node = if_full.ast.then_expr;
    const then_sub_scope = s: {
        if (if_full.error_token != null) {
            if (if_full.payload_token) |payload_token| {
                const tag: Zir.Inst.Tag = if (payload_is_ref)
                    .err_union_payload_unsafe_ptr
                else
                    .err_union_payload_unsafe;
                const payload_inst = try then_scope.addUnNode(tag, cond.inst, then_node);
                const token_name_index = payload_token + @intFromBool(payload_is_ref);
                const ident_name = try astgen.identAsString(token_name_index);
                const token_name_str = tree.tokenSlice(token_name_index);
                if (mem.eql(u8, "_", token_name_str))
                    break :s &then_scope.base;
                try astgen.detectLocalShadowing(&then_scope.base, ident_name, token_name_index, token_name_str, .capture);
                payload_val_scope = .{
                    .parent = &then_scope.base,
                    .gen_zir = &then_scope,
                    .name = ident_name,
                    .inst = payload_inst,
                    .token_src = token_name_index,
                    .id_cat = .capture,
                };
                try then_scope.addDbgVar(.dbg_var_val, ident_name, payload_inst);
                break :s &payload_val_scope.base;
            } else {
                _ = try then_scope.addUnNode(.ensure_err_union_payload_void, cond.inst, node);
                break :s &then_scope.base;
            }
        } else if (if_full.payload_token) |payload_token| {
            const ident_token = if (payload_is_ref) payload_token + 1 else payload_token;
            const tag: Zir.Inst.Tag = if (payload_is_ref)
                .optional_payload_unsafe_ptr
            else
                .optional_payload_unsafe;
            const ident_bytes = tree.tokenSlice(ident_token);
            if (mem.eql(u8, "_", ident_bytes))
                break :s &then_scope.base;
            const payload_inst = try then_scope.addUnNode(tag, cond.inst, then_node);
            const ident_name = try astgen.identAsString(ident_token);
            try astgen.detectLocalShadowing(&then_scope.base, ident_name, ident_token, ident_bytes, .capture);
            payload_val_scope = .{
                .parent = &then_scope.base,
                .gen_zir = &then_scope,
                .name = ident_name,
                .inst = payload_inst,
                .token_src = ident_token,
                .id_cat = .capture,
            };
            try then_scope.addDbgVar(.dbg_var_val, ident_name, payload_inst);
            break :s &payload_val_scope.base;
        } else {
            break :s &then_scope.base;
        }
    };

    const then_result = try fullBodyExpr(&then_scope, then_sub_scope, block_scope.break_result_info, then_node);
    try checkUsed(parent_gz, &then_scope.base, then_sub_scope);
    if (!then_scope.endsWithNoReturn()) {
        _ = try then_scope.addBreakWithSrcNode(.@"break", block, then_result, then_node);
    }

    var else_scope = parent_gz.makeSubBlock(scope);
    defer else_scope.unstack();

    // We know that the operand (almost certainly) modified the error return trace,
    // so signal to Sema that it should save the new index for restoring later.
    if (do_err_trace and nodeMayAppendToErrorTrace(tree, if_full.ast.cond_expr))
        _ = try else_scope.addSaveErrRetIndex(.always);

    const else_node = if_full.ast.else_expr;
    if (else_node != 0) {
        const sub_scope = s: {
            if (if_full.error_token) |error_token| {
                const tag: Zir.Inst.Tag = if (payload_is_ref)
                    .err_union_code_ptr
                else
                    .err_union_code;
                const payload_inst = try else_scope.addUnNode(tag, cond.inst, if_full.ast.cond_expr);
                const ident_name = try astgen.identAsString(error_token);
                const error_token_str = tree.tokenSlice(error_token);
                if (mem.eql(u8, "_", error_token_str))
                    break :s &else_scope.base;
                try astgen.detectLocalShadowing(&else_scope.base, ident_name, error_token, error_token_str, .capture);
                payload_val_scope = .{
                    .parent = &else_scope.base,
                    .gen_zir = &else_scope,
                    .name = ident_name,
                    .inst = payload_inst,
                    .token_src = error_token,
                    .id_cat = .capture,
                };
                try else_scope.addDbgVar(.dbg_var_val, ident_name, payload_inst);
                break :s &payload_val_scope.base;
            } else {
                break :s &else_scope.base;
            }
        };
        const else_result = try fullBodyExpr(&else_scope, sub_scope, block_scope.break_result_info, else_node);
        if (!else_scope.endsWithNoReturn()) {
            // As our last action before the break, "pop" the error trace if needed
            if (do_err_trace)
                try restoreErrRetIndex(&else_scope, .{ .block = block }, block_scope.break_result_info, else_node, else_result);
            _ = try else_scope.addBreakWithSrcNode(.@"break", block, else_result, else_node);
        }
        try checkUsed(parent_gz, &else_scope.base, sub_scope);
    } else {
        const result = try rvalue(&else_scope, ri, .void_value, node);
        _ = try else_scope.addBreak(.@"break", block, result);
    }

    try setCondBrPayload(condbr, cond.bool_bit, &then_scope, &else_scope);

    if (need_result_rvalue) {
        return rvalue(parent_gz, ri, block.toRef(), node);
    } else {
        return block.toRef();
    }
}

/// Supports `else_scope` stacked on `then_scope`. Unstacks `else_scope` then `then_scope`.
fn setCondBrPayload(
    condbr: Zir.Inst.Index,
    cond: Zir.Inst.Ref,
    then_scope: *GenZir,
    else_scope: *GenZir,
) !void {
    defer then_scope.unstack();
    defer else_scope.unstack();
    const astgen = then_scope.astgen;
    const then_body = then_scope.instructionsSliceUpto(else_scope);
    const else_body = else_scope.instructionsSlice();
    const then_body_len = astgen.countBodyLenAfterFixups(then_body);
    const else_body_len = astgen.countBodyLenAfterFixups(else_body);
    try astgen.extra.ensureUnusedCapacity(
        astgen.gpa,
        @typeInfo(Zir.Inst.CondBr).Struct.fields.len + then_body_len + else_body_len,
    );

    const zir_datas = astgen.instructions.items(.data);
    zir_datas[@intFromEnum(condbr)].pl_node.payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.CondBr{
        .condition = cond,
        .then_body_len = then_body_len,
        .else_body_len = else_body_len,
    });
    astgen.appendBodyWithFixups(then_body);
    astgen.appendBodyWithFixups(else_body);
}

fn whileExpr(
    parent_gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    while_full: Ast.full.While,
    is_statement: bool,
) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;
    const tree = astgen.tree;
    const token_tags = tree.tokens.items(.tag);

    const need_rl = astgen.nodes_need_rl.contains(node);
    const block_ri: ResultInfo = if (need_rl) ri else .{
        .rl = switch (ri.rl) {
            .ptr => .{ .ty = (try ri.rl.resultType(parent_gz, node)).? },
            .inferred_ptr => .none,
            else => ri.rl,
        },
        .ctx = ri.ctx,
    };
    // We need to call `rvalue` to write through to the pointer only if we had a
    // result pointer and aren't forwarding it.
    const LocTag = @typeInfo(ResultInfo.Loc).Union.tag_type.?;
    const need_result_rvalue = @as(LocTag, block_ri.rl) != @as(LocTag, ri.rl);

    if (while_full.label_token) |label_token| {
        try astgen.checkLabelRedefinition(scope, label_token);
    }

    const is_inline = while_full.inline_token != null;
    if (parent_gz.is_comptime and is_inline) {
        return astgen.failTok(while_full.inline_token.?, "redundant inline keyword in comptime scope", .{});
    }
    const loop_tag: Zir.Inst.Tag = if (is_inline) .block_inline else .loop;
    const loop_block = try parent_gz.makeBlockInst(loop_tag, node);
    try parent_gz.instructions.append(astgen.gpa, loop_block);

    var loop_scope = parent_gz.makeSubBlock(scope);
    loop_scope.is_inline = is_inline;
    loop_scope.setBreakResultInfo(block_ri);
    defer loop_scope.unstack();

    var cond_scope = parent_gz.makeSubBlock(&loop_scope.base);
    defer cond_scope.unstack();

    const payload_is_ref = if (while_full.payload_token) |payload_token|
        token_tags[payload_token] == .asterisk
    else
        false;

    try emitDbgNode(parent_gz, while_full.ast.cond_expr);
    const cond: struct {
        inst: Zir.Inst.Ref,
        bool_bit: Zir.Inst.Ref,
    } = c: {
        if (while_full.error_token) |_| {
            const cond_ri: ResultInfo = .{ .rl = if (payload_is_ref) .ref else .none };
            const err_union = try fullBodyExpr(&cond_scope, &cond_scope.base, cond_ri, while_full.ast.cond_expr);
            const tag: Zir.Inst.Tag = if (payload_is_ref) .is_non_err_ptr else .is_non_err;
            break :c .{
                .inst = err_union,
                .bool_bit = try cond_scope.addUnNode(tag, err_union, while_full.ast.cond_expr),
            };
        } else if (while_full.payload_token) |_| {
            const cond_ri: ResultInfo = .{ .rl = if (payload_is_ref) .ref else .none };
            const optional = try fullBodyExpr(&cond_scope, &cond_scope.base, cond_ri, while_full.ast.cond_expr);
            const tag: Zir.Inst.Tag = if (payload_is_ref) .is_non_null_ptr else .is_non_null;
            break :c .{
                .inst = optional,
                .bool_bit = try cond_scope.addUnNode(tag, optional, while_full.ast.cond_expr),
            };
        } else {
            const cond = try fullBodyExpr(&cond_scope, &cond_scope.base, coerced_bool_ri, while_full.ast.cond_expr);
            break :c .{
                .inst = cond,
                .bool_bit = cond,
            };
        }
    };

    const condbr_tag: Zir.Inst.Tag = if (is_inline) .condbr_inline else .condbr;
    const condbr = try cond_scope.addCondBr(condbr_tag, node);
    const block_tag: Zir.Inst.Tag = if (is_inline) .block_inline else .block;
    const cond_block = try loop_scope.makeBlockInst(block_tag, node);
    try cond_scope.setBlockBody(cond_block);
    // cond_scope unstacked now, can add new instructions to loop_scope
    try loop_scope.instructions.append(astgen.gpa, cond_block);

    // make scope now but don't stack on parent_gz until loop_scope
    // gets unstacked after cont_expr is emitted and added below
    var then_scope = parent_gz.makeSubBlock(&cond_scope.base);
    then_scope.instructions_top = GenZir.unstacked_top;
    defer then_scope.unstack();

    var dbg_var_name: Zir.NullTerminatedString = .empty;
    var dbg_var_inst: Zir.Inst.Ref = undefined;
    var opt_payload_inst: Zir.Inst.OptionalIndex = .none;
    var payload_val_scope: Scope.LocalVal = undefined;
    const then_sub_scope = s: {
        if (while_full.error_token != null) {
            if (while_full.payload_token) |payload_token| {
                const tag: Zir.Inst.Tag = if (payload_is_ref)
                    .err_union_payload_unsafe_ptr
                else
                    .err_union_payload_unsafe;
                // will add this instruction to then_scope.instructions below
                const payload_inst = try then_scope.makeUnNode(tag, cond.inst, while_full.ast.cond_expr);
                opt_payload_inst = payload_inst.toOptional();
                const ident_token = payload_token + @intFromBool(payload_is_ref);
                const ident_bytes = tree.tokenSlice(ident_token);
                if (mem.eql(u8, "_", ident_bytes))
                    break :s &then_scope.base;
                const ident_name = try astgen.identAsString(ident_token);
                try astgen.detectLocalShadowing(&then_scope.base, ident_name, ident_token, ident_bytes, .capture);
                payload_val_scope = .{
                    .parent = &then_scope.base,
                    .gen_zir = &then_scope,
                    .name = ident_name,
                    .inst = payload_inst.toRef(),
                    .token_src = ident_token,
                    .id_cat = .capture,
                };
                dbg_var_name = ident_name;
                dbg_var_inst = payload_inst.toRef();
                break :s &payload_val_scope.base;
            } else {
                _ = try then_scope.addUnNode(.ensure_err_union_payload_void, cond.inst, node);
                break :s &then_scope.base;
            }
        } else if (while_full.payload_token) |payload_token| {
            const ident_token = if (payload_is_ref) payload_token + 1 else payload_token;
            const tag: Zir.Inst.Tag = if (payload_is_ref)
                .optional_payload_unsafe_ptr
            else
                .optional_payload_unsafe;
            // will add this instruction to then_scope.instructions below
            const payload_inst = try then_scope.makeUnNode(tag, cond.inst, while_full.ast.cond_expr);
            opt_payload_inst = payload_inst.toOptional();
            const ident_name = try astgen.identAsString(ident_token);
            const ident_bytes = tree.tokenSlice(ident_token);
            if (mem.eql(u8, "_", ident_bytes))
                break :s &then_scope.base;
            try astgen.detectLocalShadowing(&then_scope.base, ident_name, ident_token, ident_bytes, .capture);
            payload_val_scope = .{
                .parent = &then_scope.base,
                .gen_zir = &then_scope,
                .name = ident_name,
                .inst = payload_inst.toRef(),
                .token_src = ident_token,
                .id_cat = .capture,
            };
            dbg_var_name = ident_name;
            dbg_var_inst = payload_inst.toRef();
            break :s &payload_val_scope.base;
        } else {
            break :s &then_scope.base;
        }
    };

    var continue_scope = parent_gz.makeSubBlock(then_sub_scope);
    continue_scope.instructions_top = GenZir.unstacked_top;
    defer continue_scope.unstack();
    const continue_block = try then_scope.makeBlockInst(block_tag, node);

    const repeat_tag: Zir.Inst.Tag = if (is_inline) .repeat_inline else .repeat;
    _ = try loop_scope.addNode(repeat_tag, node);

    try loop_scope.setBlockBody(loop_block);
    loop_scope.break_block = loop_block.toOptional();
    loop_scope.continue_block = continue_block.toOptional();
    if (while_full.label_token) |label_token| {
        loop_scope.label = .{
            .token = label_token,
            .block_inst = loop_block,
        };
    }

    // done adding instructions to loop_scope, can now stack then_scope
    then_scope.instructions_top = then_scope.instructions.items.len;

    const then_node = while_full.ast.then_expr;
    if (opt_payload_inst.unwrap()) |payload_inst| {
        try then_scope.instructions.append(astgen.gpa, payload_inst);
    }
    if (dbg_var_name != .empty) try then_scope.addDbgVar(.dbg_var_val, dbg_var_name, dbg_var_inst);
    try then_scope.instructions.append(astgen.gpa, continue_block);
    // This code could be improved to avoid emitting the continue expr when there
    // are no jumps to it. This happens when the last statement of a while body is noreturn
    // and there are no `continue` statements.
    // Tracking issue: https://github.com/ziglang/zig/issues/9185
    if (while_full.ast.cont_expr != 0) {
        _ = try unusedResultExpr(&then_scope, then_sub_scope, while_full.ast.cont_expr);
    }

    continue_scope.instructions_top = continue_scope.instructions.items.len;
    {
        try emitDbgNode(&continue_scope, then_node);
        const unused_result = try fullBodyExpr(&continue_scope, &continue_scope.base, .{ .rl = .none }, then_node);
        _ = try addEnsureResult(&continue_scope, unused_result, then_node);
    }
    try checkUsed(parent_gz, &then_scope.base, then_sub_scope);
    const break_tag: Zir.Inst.Tag = if (is_inline) .break_inline else .@"break";
    if (!continue_scope.endsWithNoReturn()) {
        _ = try continue_scope.addBreak(break_tag, continue_block, .void_value);
    }
    try continue_scope.setBlockBody(continue_block);
    _ = try then_scope.addBreak(break_tag, cond_block, .void_value);

    var else_scope = parent_gz.makeSubBlock(&cond_scope.base);
    defer else_scope.unstack();

    const else_node = while_full.ast.else_expr;
    if (else_node != 0) {
        const sub_scope = s: {
            if (while_full.error_token) |error_token| {
                const tag: Zir.Inst.Tag = if (payload_is_ref)
                    .err_union_code_ptr
                else
                    .err_union_code;
                const else_payload_inst = try else_scope.addUnNode(tag, cond.inst, while_full.ast.cond_expr);
                const ident_name = try astgen.identAsString(error_token);
                const ident_bytes = tree.tokenSlice(error_token);
                if (mem.eql(u8, ident_bytes, "_"))
                    break :s &else_scope.base;
                try astgen.detectLocalShadowing(&else_scope.base, ident_name, error_token, ident_bytes, .capture);
                payload_val_scope = .{
                    .parent = &else_scope.base,
                    .gen_zir = &else_scope,
                    .name = ident_name,
                    .inst = else_payload_inst,
                    .token_src = error_token,
                    .id_cat = .capture,
                };
                try else_scope.addDbgVar(.dbg_var_val, ident_name, else_payload_inst);
                break :s &payload_val_scope.base;
            } else {
                break :s &else_scope.base;
            }
        };
        // Remove the continue block and break block so that `continue` and `break`
        // control flow apply to outer loops; not this one.
        loop_scope.continue_block = .none;
        loop_scope.break_block = .none;
        const else_result = try fullBodyExpr(&else_scope, sub_scope, loop_scope.break_result_info, else_node);
        if (is_statement) {
            _ = try addEnsureResult(&else_scope, else_result, else_node);
        }

        try checkUsed(parent_gz, &else_scope.base, sub_scope);
        if (!else_scope.endsWithNoReturn()) {
            _ = try else_scope.addBreakWithSrcNode(break_tag, loop_block, else_result, else_node);
        }
    } else {
        const result = try rvalue(&else_scope, ri, .void_value, node);
        _ = try else_scope.addBreak(break_tag, loop_block, result);
    }

    if (loop_scope.label) |some| {
        if (!some.used) {
            try astgen.appendErrorTok(some.token, "unused while loop label", .{});
        }
    }

    try setCondBrPayload(condbr, cond.bool_bit, &then_scope, &else_scope);

    const result = if (need_result_rvalue)
        try rvalue(parent_gz, ri, loop_block.toRef(), node)
    else
        loop_block.toRef();

    if (is_statement) {
        _ = try parent_gz.addUnNode(.ensure_result_used, result, node);
    }

    return result;
}

fn forExpr(
    parent_gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    for_full: Ast.full.For,
    is_statement: bool,
) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;

    if (for_full.label_token) |label_token| {
        try astgen.checkLabelRedefinition(scope, label_token);
    }

    const need_rl = astgen.nodes_need_rl.contains(node);
    const block_ri: ResultInfo = if (need_rl) ri else .{
        .rl = switch (ri.rl) {
            .ptr => .{ .ty = (try ri.rl.resultType(parent_gz, node)).? },
            .inferred_ptr => .none,
            else => ri.rl,
        },
        .ctx = ri.ctx,
    };
    // We need to call `rvalue` to write through to the pointer only if we had a
    // result pointer and aren't forwarding it.
    const LocTag = @typeInfo(ResultInfo.Loc).Union.tag_type.?;
    const need_result_rvalue = @as(LocTag, block_ri.rl) != @as(LocTag, ri.rl);

    const is_inline = for_full.inline_token != null;
    if (parent_gz.is_comptime and is_inline) {
        return astgen.failTok(for_full.inline_token.?, "redundant inline keyword in comptime scope", .{});
    }
    const tree = astgen.tree;
    const token_tags = tree.tokens.items(.tag);
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    const gpa = astgen.gpa;

    // For counters, this is the start value; for indexables, this is the base
    // pointer that can be used with elem_ptr and similar instructions.
    // Special value `none` means that this is a counter and its start value is
    // zero, indicating that the main index counter can be used directly.
    const indexables = try gpa.alloc(Zir.Inst.Ref, for_full.ast.inputs.len);
    defer gpa.free(indexables);
    // elements of this array can be `none`, indicating no length check.
    const lens = try gpa.alloc(Zir.Inst.Ref, for_full.ast.inputs.len);
    defer gpa.free(lens);

    // We will use a single zero-based counter no matter how many indexables there are.
    const index_ptr = blk: {
        const alloc_tag: Zir.Inst.Tag = if (is_inline) .alloc_comptime_mut else .alloc;
        const index_ptr = try parent_gz.addUnNode(alloc_tag, .usize_type, node);
        // initialize to zero
        _ = try parent_gz.addPlNode(.store_node, node, Zir.Inst.Bin{
            .lhs = index_ptr,
            .rhs = .zero_usize,
        });
        break :blk index_ptr;
    };

    var any_len_checks = false;

    {
        var capture_token = for_full.payload_token;
        for (for_full.ast.inputs, indexables, lens) |input, *indexable_ref, *len_ref| {
            const capture_is_ref = token_tags[capture_token] == .asterisk;
            const ident_tok = capture_token + @intFromBool(capture_is_ref);
            const is_discard = mem.eql(u8, tree.tokenSlice(ident_tok), "_");

            if (is_discard and capture_is_ref) {
                return astgen.failTok(capture_token, "pointer modifier invalid on discard", .{});
            }
            // Skip over the comma, and on to the next capture (or the ending pipe character).
            capture_token = ident_tok + 2;

            try emitDbgNode(parent_gz, input);
            if (node_tags[input] == .for_range) {
                if (capture_is_ref) {
                    return astgen.failTok(ident_tok, "cannot capture reference to range", .{});
                }
                const start_node = node_data[input].lhs;
                const start_val = try expr(parent_gz, scope, .{ .rl = .{ .ty = .usize_type } }, start_node);

                const end_node = node_data[input].rhs;
                const end_val = if (end_node != 0)
                    try expr(parent_gz, scope, .{ .rl = .{ .ty = .usize_type } }, node_data[input].rhs)
                else
                    .none;

                if (end_val == .none and is_discard) {
                    return astgen.failTok(ident_tok, "discard of unbounded counter", .{});
                }

                const start_is_zero = nodeIsTriviallyZero(tree, start_node);
                const range_len = if (end_val == .none or start_is_zero)
                    end_val
                else
                    try parent_gz.addPlNode(.sub, input, Zir.Inst.Bin{
                        .lhs = end_val,
                        .rhs = start_val,
                    });

                any_len_checks = any_len_checks or range_len != .none;
                indexable_ref.* = if (start_is_zero) .none else start_val;
                len_ref.* = range_len;
            } else {
                const indexable = try expr(parent_gz, scope, .{ .rl = .none }, input);

                any_len_checks = true;
                indexable_ref.* = indexable;
                len_ref.* = indexable;
            }
        }
    }

    if (!any_len_checks) {
        return astgen.failNode(node, "unbounded for loop", .{});
    }

    // We use a dedicated ZIR instruction to assert the lengths to assist with
    // nicer error reporting as well as fewer ZIR bytes emitted.
    const len: Zir.Inst.Ref = len: {
        const lens_len: u32 = @intCast(lens.len);
        try astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.MultiOp).Struct.fields.len + lens_len);
        const len = try parent_gz.addPlNode(.for_len, node, Zir.Inst.MultiOp{
            .operands_len = lens_len,
        });
        appendRefsAssumeCapacity(astgen, lens);
        break :len len;
    };

    const loop_tag: Zir.Inst.Tag = if (is_inline) .block_inline else .loop;
    const loop_block = try parent_gz.makeBlockInst(loop_tag, node);
    try parent_gz.instructions.append(gpa, loop_block);

    var loop_scope = parent_gz.makeSubBlock(scope);
    loop_scope.is_inline = is_inline;
    loop_scope.setBreakResultInfo(block_ri);
    defer loop_scope.unstack();

    // We need to finish loop_scope later once we have the deferred refs from then_scope. However, the
    // load must be removed from instructions in the meantime or it appears to be part of parent_gz.
    const index = try loop_scope.addUnNode(.load, index_ptr, node);
    _ = loop_scope.instructions.pop();

    var cond_scope = parent_gz.makeSubBlock(&loop_scope.base);
    defer cond_scope.unstack();

    // Check the condition.
    const cond = try cond_scope.addPlNode(.cmp_lt, node, Zir.Inst.Bin{
        .lhs = index,
        .rhs = len,
    });

    const condbr_tag: Zir.Inst.Tag = if (is_inline) .condbr_inline else .condbr;
    const condbr = try cond_scope.addCondBr(condbr_tag, node);
    const block_tag: Zir.Inst.Tag = if (is_inline) .block_inline else .block;
    const cond_block = try loop_scope.makeBlockInst(block_tag, node);
    try cond_scope.setBlockBody(cond_block);

    loop_scope.break_block = loop_block.toOptional();
    loop_scope.continue_block = cond_block.toOptional();
    if (for_full.label_token) |label_token| {
        loop_scope.label = .{
            .token = label_token,
            .block_inst = loop_block,
        };
    }

    const then_node = for_full.ast.then_expr;
    var then_scope = parent_gz.makeSubBlock(&cond_scope.base);
    defer then_scope.unstack();

    const capture_scopes = try gpa.alloc(Scope.LocalVal, for_full.ast.inputs.len);
    defer gpa.free(capture_scopes);

    const then_sub_scope = blk: {
        var capture_token = for_full.payload_token;
        var capture_sub_scope: *Scope = &then_scope.base;
        for (for_full.ast.inputs, indexables, capture_scopes) |input, indexable_ref, *capture_scope| {
            const capture_is_ref = token_tags[capture_token] == .asterisk;
            const ident_tok = capture_token + @intFromBool(capture_is_ref);
            const capture_name = tree.tokenSlice(ident_tok);
            // Skip over the comma, and on to the next capture (or the ending pipe character).
            capture_token = ident_tok + 2;

            if (mem.eql(u8, capture_name, "_")) continue;

            const name_str_index = try astgen.identAsString(ident_tok);
            try astgen.detectLocalShadowing(capture_sub_scope, name_str_index, ident_tok, capture_name, .capture);

            const capture_inst = inst: {
                const is_counter = node_tags[input] == .for_range;

                if (indexable_ref == .none) {
                    // Special case: the main index can be used directly.
                    assert(is_counter);
                    assert(!capture_is_ref);
                    break :inst index;
                }

                // For counters, we add the index variable to the start value; for
                // indexables, we use it as an element index. This is so similar
                // that they can share the same code paths, branching only on the
                // ZIR tag.
                const switch_cond = (@as(u2, @intFromBool(capture_is_ref)) << 1) | @intFromBool(is_counter);
                const tag: Zir.Inst.Tag = switch (switch_cond) {
                    0b00 => .elem_val,
                    0b01 => .add,
                    0b10 => .elem_ptr,
                    0b11 => unreachable, // compile error emitted already
                };
                break :inst try then_scope.addPlNode(tag, input, Zir.Inst.Bin{
                    .lhs = indexable_ref,
                    .rhs = index,
                });
            };

            capture_scope.* = .{
                .parent = capture_sub_scope,
                .gen_zir = &then_scope,
                .name = name_str_index,
                .inst = capture_inst,
                .token_src = ident_tok,
                .id_cat = .capture,
            };

            try then_scope.addDbgVar(.dbg_var_val, name_str_index, capture_inst);
            capture_sub_scope = &capture_scope.base;
        }

        break :blk capture_sub_scope;
    };

    const then_result = try fullBodyExpr(&then_scope, then_sub_scope, .{ .rl = .none }, then_node);
    _ = try addEnsureResult(&then_scope, then_result, then_node);

    try checkUsed(parent_gz, &then_scope.base, then_sub_scope);

    const break_tag: Zir.Inst.Tag = if (is_inline) .break_inline else .@"break";

    _ = try then_scope.addBreak(break_tag, cond_block, .void_value);

    var else_scope = parent_gz.makeSubBlock(&cond_scope.base);
    defer else_scope.unstack();

    const else_node = for_full.ast.else_expr;
    if (else_node != 0) {
        const sub_scope = &else_scope.base;
        // Remove the continue block and break block so that `continue` and `break`
        // control flow apply to outer loops; not this one.
        loop_scope.continue_block = .none;
        loop_scope.break_block = .none;
        const else_result = try fullBodyExpr(&else_scope, sub_scope, loop_scope.break_result_info, else_node);
        if (is_statement) {
            _ = try addEnsureResult(&else_scope, else_result, else_node);
        }
        if (!else_scope.endsWithNoReturn()) {
            _ = try else_scope.addBreakWithSrcNode(break_tag, loop_block, else_result, else_node);
        }
    } else {
        const result = try rvalue(&else_scope, ri, .void_value, node);
        _ = try else_scope.addBreak(break_tag, loop_block, result);
    }

    if (loop_scope.label) |some| {
        if (!some.used) {
            try astgen.appendErrorTok(some.token, "unused for loop label", .{});
        }
    }

    try setCondBrPayload(condbr, cond, &then_scope, &else_scope);

    // then_block and else_block unstacked now, can resurrect loop_scope to finally finish it
    {
        loop_scope.instructions_top = loop_scope.instructions.items.len;
        try loop_scope.instructions.appendSlice(gpa, &.{ index.toIndex().?, cond_block });

        // Increment the index variable.
        const index_plus_one = try loop_scope.addPlNode(.add_unsafe, node, Zir.Inst.Bin{
            .lhs = index,
            .rhs = .one_usize,
        });
        _ = try loop_scope.addPlNode(.store_node, node, Zir.Inst.Bin{
            .lhs = index_ptr,
            .rhs = index_plus_one,
        });
        const repeat_tag: Zir.Inst.Tag = if (is_inline) .repeat_inline else .repeat;
        _ = try loop_scope.addNode(repeat_tag, node);

        try loop_scope.setBlockBody(loop_block);
    }

    const result = if (need_result_rvalue)
        try rvalue(parent_gz, ri, loop_block.toRef(), node)
    else
        loop_block.toRef();

    if (is_statement) {
        _ = try parent_gz.addUnNode(.ensure_result_used, result, node);
    }
    return result;
}

fn switchExprErrUnion(
    parent_gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    catch_or_if_node: Ast.Node.Index,
    node_ty: enum { @"catch", @"if" },
) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;
    const gpa = astgen.gpa;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);

    const if_full = switch (node_ty) {
        .@"catch" => undefined,
        .@"if" => tree.fullIf(catch_or_if_node).?,
    };

    const switch_node, const operand_node, const error_payload = switch (node_ty) {
        .@"catch" => .{
            node_datas[catch_or_if_node].rhs,
            node_datas[catch_or_if_node].lhs,
            main_tokens[catch_or_if_node] + 2,
        },
        .@"if" => .{
            if_full.ast.else_expr,
            if_full.ast.cond_expr,
            if_full.error_token.?,
        },
    };
    assert(node_tags[switch_node] == .@"switch" or node_tags[switch_node] == .switch_comma);

    const do_err_trace = astgen.fn_block != null;

    const extra = tree.extraData(node_datas[switch_node].rhs, Ast.Node.SubRange);
    const case_nodes = tree.extra_data[extra.start..extra.end];

    const need_rl = astgen.nodes_need_rl.contains(catch_or_if_node);
    const block_ri: ResultInfo = if (need_rl) ri else .{
        .rl = switch (ri.rl) {
            .ptr => .{ .ty = (try ri.rl.resultType(parent_gz, catch_or_if_node)).? },
            .inferred_ptr => .none,
            else => ri.rl,
        },
        .ctx = ri.ctx,
    };

    const payload_is_ref = switch (node_ty) {
        .@"if" => if_full.payload_token != null and token_tags[if_full.payload_token.?] == .asterisk,
        .@"catch" => ri.rl == .ref or ri.rl == .ref_coerced_ty,
    };

    // We need to call `rvalue` to write through to the pointer only if we had a
    // result pointer and aren't forwarding it.
    const LocTag = @typeInfo(ResultInfo.Loc).Union.tag_type.?;
    const need_result_rvalue = @as(LocTag, block_ri.rl) != @as(LocTag, ri.rl);
    var scalar_cases_len: u32 = 0;
    var multi_cases_len: u32 = 0;
    var inline_cases_len: u32 = 0;
    var has_else = false;
    var else_node: Ast.Node.Index = 0;
    var else_src: ?Ast.TokenIndex = null;
    for (case_nodes) |case_node| {
        const case = tree.fullSwitchCase(case_node).?;

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
                            "previous else prong here",
                            .{},
                        ),
                    },
                );
            }
            has_else = true;
            else_node = case_node;
            else_src = case_src;
            continue;
        } else if (case.ast.values.len == 1 and
            node_tags[case.ast.values[0]] == .identifier and
            mem.eql(u8, tree.tokenSlice(main_tokens[case.ast.values[0]]), "_"))
        {
            const case_src = case.ast.arrow_token - 1;
            return astgen.failTokNotes(
                case_src,
                "'_' prong is not allowed when switching on errors",
                .{},
                &[_]u32{
                    try astgen.errNoteTok(
                        case_src,
                        "consider using 'else'",
                        .{},
                    ),
                },
            );
        }

        for (case.ast.values) |val| {
            if (node_tags[val] == .string_literal)
                return astgen.failNode(val, "cannot switch on strings", .{});
        }

        if (case.ast.values.len == 1 and node_tags[case.ast.values[0]] != .switch_range) {
            scalar_cases_len += 1;
        } else {
            multi_cases_len += 1;
        }
        if (case.inline_token != null) {
            inline_cases_len += 1;
        }
    }

    const operand_ri: ResultInfo = .{
        .rl = if (payload_is_ref) .ref else .none,
        .ctx = .error_handling_expr,
    };

    astgen.advanceSourceCursorToNode(operand_node);
    const operand_lc = LineColumn{ astgen.source_line - parent_gz.decl_line, astgen.source_column };

    const raw_operand = try reachableExpr(parent_gz, scope, operand_ri, operand_node, switch_node);
    const item_ri: ResultInfo = .{ .rl = .none };

    // This contains the data that goes into the `extra` array for the SwitchBlockErrUnion, except
    // the first cases_nodes.len slots are a table that indexes payloads later in the array,
    // with the non-error and else case indices coming first, then scalar_cases_len indexes, then
    // multi_cases_len indexes
    const payloads = &astgen.scratch;
    const scratch_top = astgen.scratch.items.len;
    const case_table_start = scratch_top;
    const scalar_case_table = case_table_start + 1 + @intFromBool(has_else);
    const multi_case_table = scalar_case_table + scalar_cases_len;
    const case_table_end = multi_case_table + multi_cases_len;

    try astgen.scratch.resize(gpa, case_table_end);
    defer astgen.scratch.items.len = scratch_top;

    var block_scope = parent_gz.makeSubBlock(scope);
    // block_scope not used for collecting instructions
    block_scope.instructions_top = GenZir.unstacked_top;
    block_scope.setBreakResultInfo(block_ri);

    // Sema expects a dbg_stmt immediately before switch_block_err_union
    try emitDbgStmtForceCurrentIndex(parent_gz, operand_lc);
    // This gets added to the parent block later, after the item expressions.
    const switch_block = try parent_gz.makeBlockInst(.switch_block_err_union, switch_node);

    // We re-use this same scope for all cases, including the special prong, if any.
    var case_scope = parent_gz.makeSubBlock(&block_scope.base);
    case_scope.instructions_top = GenZir.unstacked_top;

    {
        const body_len_index: u32 = @intCast(payloads.items.len);
        payloads.items[case_table_start] = body_len_index;
        try payloads.resize(gpa, body_len_index + 1); // body_len

        case_scope.instructions_top = parent_gz.instructions.items.len;
        defer case_scope.unstack();

        const unwrap_payload_tag: Zir.Inst.Tag = if (payload_is_ref)
            .err_union_payload_unsafe_ptr
        else
            .err_union_payload_unsafe;

        const unwrapped_payload = try case_scope.addUnNode(
            unwrap_payload_tag,
            raw_operand,
            catch_or_if_node,
        );

        switch (node_ty) {
            .@"catch" => {
                const case_result = switch (ri.rl) {
                    .ref, .ref_coerced_ty => unwrapped_payload,
                    else => try rvalue(
                        &case_scope,
                        block_scope.break_result_info,
                        unwrapped_payload,
                        catch_or_if_node,
                    ),
                };
                _ = try case_scope.addBreakWithSrcNode(
                    .@"break",
                    switch_block,
                    case_result,
                    catch_or_if_node,
                );
            },
            .@"if" => {
                var payload_val_scope: Scope.LocalVal = undefined;

                const then_node = if_full.ast.then_expr;
                const then_sub_scope = s: {
                    assert(if_full.error_token != null);
                    if (if_full.payload_token) |payload_token| {
                        const token_name_index = payload_token + @intFromBool(payload_is_ref);
                        const ident_name = try astgen.identAsString(token_name_index);
                        const token_name_str = tree.tokenSlice(token_name_index);
                        if (mem.eql(u8, "_", token_name_str))
                            break :s &case_scope.base;
                        try astgen.detectLocalShadowing(
                            &case_scope.base,
                            ident_name,
                            token_name_index,
                            token_name_str,
                            .capture,
                        );
                        payload_val_scope = .{
                            .parent = &case_scope.base,
                            .gen_zir = &case_scope,
                            .name = ident_name,
                            .inst = unwrapped_payload,
                            .token_src = token_name_index,
                            .id_cat = .capture,
                        };
                        try case_scope.addDbgVar(.dbg_var_val, ident_name, unwrapped_payload);
                        break :s &payload_val_scope.base;
                    } else {
                        _ = try case_scope.addUnNode(
                            .ensure_err_union_payload_void,
                            raw_operand,
                            catch_or_if_node,
                        );
                        break :s &case_scope.base;
                    }
                };
                const then_result = try expr(
                    &case_scope,
                    then_sub_scope,
                    block_scope.break_result_info,
                    then_node,
                );
                try checkUsed(parent_gz, &case_scope.base, then_sub_scope);
                if (!case_scope.endsWithNoReturn()) {
                    _ = try case_scope.addBreakWithSrcNode(
                        .@"break",
                        switch_block,
                        then_result,
                        then_node,
                    );
                }
            },
        }

        const case_slice = case_scope.instructionsSlice();
        // Since we use the switch_block_err_union instruction itself to refer
        // to the capture, which will not be added to the child block, we need
        // to handle ref_table manually.
        const refs_len = refs: {
            var n: usize = 0;
            var check_inst = switch_block;
            while (astgen.ref_table.get(check_inst)) |ref_inst| {
                n += 1;
                check_inst = ref_inst;
            }
            break :refs n;
        };
        const body_len = refs_len + astgen.countBodyLenAfterFixups(case_slice);
        try payloads.ensureUnusedCapacity(gpa, body_len);
        const capture: Zir.Inst.SwitchBlock.ProngInfo.Capture = switch (node_ty) {
            .@"catch" => .none,
            .@"if" => if (if_full.payload_token == null)
                .none
            else if (payload_is_ref)
                .by_ref
            else
                .by_val,
        };
        payloads.items[body_len_index] = @bitCast(Zir.Inst.SwitchBlock.ProngInfo{
            .body_len = @intCast(body_len),
            .capture = capture,
            .is_inline = false,
            .has_tag_capture = false,
        });
        if (astgen.ref_table.fetchRemove(switch_block)) |kv| {
            appendPossiblyRefdBodyInst(astgen, payloads, kv.value);
        }
        appendBodyWithFixupsArrayList(astgen, payloads, case_slice);
    }

    const err_name = blk: {
        const err_str = tree.tokenSlice(error_payload);
        if (mem.eql(u8, err_str, "_")) {
            return astgen.failTok(error_payload, "discard of error capture; omit it instead", .{});
        }
        const err_name = try astgen.identAsString(error_payload);
        try astgen.detectLocalShadowing(scope, err_name, error_payload, err_str, .capture);

        break :blk err_name;
    };

    // allocate a shared dummy instruction for the error capture
    const err_inst = err_inst: {
        const inst: Zir.Inst.Index = @enumFromInt(astgen.instructions.len);
        try astgen.instructions.append(astgen.gpa, .{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .value_placeholder,
                .small = undefined,
                .operand = undefined,
            } },
        });
        break :err_inst inst;
    };

    // In this pass we generate all the item and prong expressions for error cases.
    var multi_case_index: u32 = 0;
    var scalar_case_index: u32 = 0;
    var any_uses_err_capture = false;
    for (case_nodes) |case_node| {
        const case = tree.fullSwitchCase(case_node).?;

        const is_multi_case = case.ast.values.len > 1 or
            (case.ast.values.len == 1 and node_tags[case.ast.values[0]] == .switch_range);

        var dbg_var_name: Zir.NullTerminatedString = .empty;
        var dbg_var_inst: Zir.Inst.Ref = undefined;
        var err_scope: Scope.LocalVal = undefined;
        var capture_scope: Scope.LocalVal = undefined;

        const sub_scope = blk: {
            err_scope = .{
                .parent = &case_scope.base,
                .gen_zir = &case_scope,
                .name = err_name,
                .inst = err_inst.toRef(),
                .token_src = error_payload,
                .id_cat = .capture,
            };

            const capture_token = case.payload_token orelse break :blk &err_scope.base;
            if (token_tags[capture_token] != .identifier) {
                return astgen.failTok(capture_token + 1, "error set cannot be captured by reference", .{});
            }

            const capture_slice = tree.tokenSlice(capture_token);
            if (mem.eql(u8, capture_slice, "_")) {
                return astgen.failTok(capture_token, "discard of error capture; omit it instead", .{});
            }
            const tag_name = try astgen.identAsString(capture_token);
            try astgen.detectLocalShadowing(&case_scope.base, tag_name, capture_token, capture_slice, .capture);

            capture_scope = .{
                .parent = &case_scope.base,
                .gen_zir = &case_scope,
                .name = tag_name,
                .inst = switch_block.toRef(),
                .token_src = capture_token,
                .id_cat = .capture,
            };
            dbg_var_name = tag_name;
            dbg_var_inst = switch_block.toRef();

            err_scope.parent = &capture_scope.base;

            break :blk &err_scope.base;
        };

        const header_index: u32 = @intCast(payloads.items.len);
        const body_len_index = if (is_multi_case) blk: {
            payloads.items[multi_case_table + multi_case_index] = header_index;
            multi_case_index += 1;
            try payloads.resize(gpa, header_index + 3); // items_len, ranges_len, body_len

            // items
            var items_len: u32 = 0;
            for (case.ast.values) |item_node| {
                if (node_tags[item_node] == .switch_range) continue;
                items_len += 1;

                const item_inst = try comptimeExpr(parent_gz, scope, item_ri, item_node);
                try payloads.append(gpa, @intFromEnum(item_inst));
            }

            // ranges
            var ranges_len: u32 = 0;
            for (case.ast.values) |range| {
                if (node_tags[range] != .switch_range) continue;
                ranges_len += 1;

                const first = try comptimeExpr(parent_gz, scope, item_ri, node_datas[range].lhs);
                const last = try comptimeExpr(parent_gz, scope, item_ri, node_datas[range].rhs);
                try payloads.appendSlice(gpa, &[_]u32{
                    @intFromEnum(first), @intFromEnum(last),
                });
            }

            payloads.items[header_index] = items_len;
            payloads.items[header_index + 1] = ranges_len;
            break :blk header_index + 2;
        } else if (case_node == else_node) blk: {
            payloads.items[case_table_start + 1] = header_index;
            try payloads.resize(gpa, header_index + 1); // body_len
            break :blk header_index;
        } else blk: {
            payloads.items[scalar_case_table + scalar_case_index] = header_index;
            scalar_case_index += 1;
            try payloads.resize(gpa, header_index + 2); // item, body_len
            const item_node = case.ast.values[0];
            const item_inst = try comptimeExpr(parent_gz, scope, item_ri, item_node);
            payloads.items[header_index] = @intFromEnum(item_inst);
            break :blk header_index + 1;
        };

        {
            // temporarily stack case_scope on parent_gz
            case_scope.instructions_top = parent_gz.instructions.items.len;
            defer case_scope.unstack();

            if (do_err_trace and nodeMayAppendToErrorTrace(tree, operand_node))
                _ = try case_scope.addSaveErrRetIndex(.always);

            if (dbg_var_name != .empty) {
                try case_scope.addDbgVar(.dbg_var_val, dbg_var_name, dbg_var_inst);
            }

            const target_expr_node = case.ast.target_expr;
            const case_result = try fullBodyExpr(&case_scope, sub_scope, block_scope.break_result_info, target_expr_node);
            // check capture_scope, not err_scope to avoid false positive unused error capture
            try checkUsed(parent_gz, &case_scope.base, err_scope.parent);
            const uses_err = err_scope.used != 0 or err_scope.discarded != 0;
            if (uses_err) {
                try case_scope.addDbgVar(.dbg_var_val, err_name, err_inst.toRef());
                any_uses_err_capture = true;
            }

            if (!parent_gz.refIsNoReturn(case_result)) {
                if (do_err_trace)
                    try restoreErrRetIndex(
                        &case_scope,
                        .{ .block = switch_block },
                        block_scope.break_result_info,
                        target_expr_node,
                        case_result,
                    );

                _ = try case_scope.addBreakWithSrcNode(.@"break", switch_block, case_result, target_expr_node);
            }

            const case_slice = case_scope.instructionsSlice();
            // Since we use the switch_block_err_union instruction itself to refer
            // to the capture, which will not be added to the child block, we need
            // to handle ref_table manually.
            const refs_len = refs: {
                var n: usize = 0;
                var check_inst = switch_block;
                while (astgen.ref_table.get(check_inst)) |ref_inst| {
                    n += 1;
                    check_inst = ref_inst;
                }
                if (uses_err) {
                    check_inst = err_inst;
                    while (astgen.ref_table.get(check_inst)) |ref_inst| {
                        n += 1;
                        check_inst = ref_inst;
                    }
                }
                break :refs n;
            };
            const body_len = refs_len + astgen.countBodyLenAfterFixups(case_slice);
            try payloads.ensureUnusedCapacity(gpa, body_len);
            payloads.items[body_len_index] = @bitCast(Zir.Inst.SwitchBlock.ProngInfo{
                .body_len = @intCast(body_len),
                .capture = if (case.payload_token != null) .by_val else .none,
                .is_inline = case.inline_token != null,
                .has_tag_capture = false,
            });
            if (astgen.ref_table.fetchRemove(switch_block)) |kv| {
                appendPossiblyRefdBodyInst(astgen, payloads, kv.value);
            }
            if (uses_err) {
                if (astgen.ref_table.fetchRemove(err_inst)) |kv| {
                    appendPossiblyRefdBodyInst(astgen, payloads, kv.value);
                }
            }
            appendBodyWithFixupsArrayList(astgen, payloads, case_slice);
        }
    }
    // Now that the item expressions are generated we can add this.
    try parent_gz.instructions.append(gpa, switch_block);

    try astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.SwitchBlockErrUnion).Struct.fields.len +
        @intFromBool(multi_cases_len != 0) +
        payloads.items.len - case_table_end +
        (case_table_end - case_table_start) * @typeInfo(Zir.Inst.As).Struct.fields.len);

    const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.SwitchBlockErrUnion{
        .operand = raw_operand,
        .bits = Zir.Inst.SwitchBlockErrUnion.Bits{
            .has_multi_cases = multi_cases_len != 0,
            .has_else = has_else,
            .scalar_cases_len = @intCast(scalar_cases_len),
            .any_uses_err_capture = any_uses_err_capture,
            .payload_is_ref = payload_is_ref,
        },
        .main_src_node_offset = parent_gz.nodeIndexToRelative(catch_or_if_node),
    });

    if (multi_cases_len != 0) {
        astgen.extra.appendAssumeCapacity(multi_cases_len);
    }

    if (any_uses_err_capture) {
        astgen.extra.appendAssumeCapacity(@intFromEnum(err_inst));
    }

    const zir_datas = astgen.instructions.items(.data);
    zir_datas[@intFromEnum(switch_block)].pl_node.payload_index = payload_index;

    for (payloads.items[case_table_start..case_table_end], 0..) |start_index, i| {
        var body_len_index = start_index;
        var end_index = start_index;
        const table_index = case_table_start + i;
        if (table_index < scalar_case_table) {
            end_index += 1;
        } else if (table_index < multi_case_table) {
            body_len_index += 1;
            end_index += 2;
        } else {
            body_len_index += 2;
            const items_len = payloads.items[start_index];
            const ranges_len = payloads.items[start_index + 1];
            end_index += 3 + items_len + 2 * ranges_len;
        }
        const prong_info: Zir.Inst.SwitchBlock.ProngInfo = @bitCast(payloads.items[body_len_index]);
        end_index += prong_info.body_len;
        astgen.extra.appendSliceAssumeCapacity(payloads.items[start_index..end_index]);
    }

    if (need_result_rvalue) {
        return rvalue(parent_gz, ri, switch_block.toRef(), switch_node);
    } else {
        return switch_block.toRef();
    }
}

fn switchExpr(
    parent_gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    switch_node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = parent_gz.astgen;
    const gpa = astgen.gpa;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);
    const operand_node = node_datas[switch_node].lhs;
    const extra = tree.extraData(node_datas[switch_node].rhs, Ast.Node.SubRange);
    const case_nodes = tree.extra_data[extra.start..extra.end];

    const need_rl = astgen.nodes_need_rl.contains(switch_node);
    const block_ri: ResultInfo = if (need_rl) ri else .{
        .rl = switch (ri.rl) {
            .ptr => .{ .ty = (try ri.rl.resultType(parent_gz, switch_node)).? },
            .inferred_ptr => .none,
            else => ri.rl,
        },
        .ctx = ri.ctx,
    };
    // We need to call `rvalue` to write through to the pointer only if we had a
    // result pointer and aren't forwarding it.
    const LocTag = @typeInfo(ResultInfo.Loc).Union.tag_type.?;
    const need_result_rvalue = @as(LocTag, block_ri.rl) != @as(LocTag, ri.rl);

    // We perform two passes over the AST. This first pass is to collect information
    // for the following variables, make note of the special prong AST node index,
    // and bail out with a compile error if there are multiple special prongs present.
    var any_payload_is_ref = false;
    var any_has_tag_capture = false;
    var scalar_cases_len: u32 = 0;
    var multi_cases_len: u32 = 0;
    var inline_cases_len: u32 = 0;
    var special_prong: Zir.SpecialProng = .none;
    var special_node: Ast.Node.Index = 0;
    var else_src: ?Ast.TokenIndex = null;
    var underscore_src: ?Ast.TokenIndex = null;
    for (case_nodes) |case_node| {
        const case = tree.fullSwitchCase(case_node).?;
        if (case.payload_token) |payload_token| {
            const ident = if (token_tags[payload_token] == .asterisk) blk: {
                any_payload_is_ref = true;
                break :blk payload_token + 1;
            } else payload_token;
            if (token_tags[ident + 1] == .comma) {
                any_has_tag_capture = true;
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
                            "previous else prong here",
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
                            "else prong here",
                            .{},
                        ),
                        try astgen.errNoteTok(
                            some_underscore,
                            "'_' prong here",
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
                            "previous '_' prong here",
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
                            "else prong here",
                            .{},
                        ),
                        try astgen.errNoteTok(
                            case_src,
                            "'_' prong here",
                            .{},
                        ),
                    },
                );
            }
            if (case.inline_token != null) {
                return astgen.failTok(case_src, "cannot inline '_' prong", .{});
            }
            special_node = case_node;
            special_prong = .under;
            underscore_src = case_src;
            continue;
        }

        for (case.ast.values) |val| {
            if (node_tags[val] == .string_literal)
                return astgen.failNode(val, "cannot switch on strings", .{});
        }

        if (case.ast.values.len == 1 and node_tags[case.ast.values[0]] != .switch_range) {
            scalar_cases_len += 1;
        } else {
            multi_cases_len += 1;
        }
        if (case.inline_token != null) {
            inline_cases_len += 1;
        }
    }

    const operand_ri: ResultInfo = .{ .rl = if (any_payload_is_ref) .ref else .none };

    astgen.advanceSourceCursorToNode(operand_node);
    const operand_lc = LineColumn{ astgen.source_line - parent_gz.decl_line, astgen.source_column };

    const raw_operand = try expr(parent_gz, scope, operand_ri, operand_node);
    const item_ri: ResultInfo = .{ .rl = .none };

    // This contains the data that goes into the `extra` array for the SwitchBlock/SwitchBlockMulti,
    // except the first cases_nodes.len slots are a table that indexes payloads later in the array, with
    // the special case index coming first, then scalar_case_len indexes, then multi_cases_len indexes
    const payloads = &astgen.scratch;
    const scratch_top = astgen.scratch.items.len;
    const case_table_start = scratch_top;
    const scalar_case_table = case_table_start + @intFromBool(special_prong != .none);
    const multi_case_table = scalar_case_table + scalar_cases_len;
    const case_table_end = multi_case_table + multi_cases_len;
    try astgen.scratch.resize(gpa, case_table_end);
    defer astgen.scratch.items.len = scratch_top;

    var block_scope = parent_gz.makeSubBlock(scope);
    // block_scope not used for collecting instructions
    block_scope.instructions_top = GenZir.unstacked_top;
    block_scope.setBreakResultInfo(block_ri);

    // Sema expects a dbg_stmt immediately before switch_block(_ref)
    try emitDbgStmtForceCurrentIndex(parent_gz, operand_lc);
    // This gets added to the parent block later, after the item expressions.
    const switch_tag: Zir.Inst.Tag = if (any_payload_is_ref) .switch_block_ref else .switch_block;
    const switch_block = try parent_gz.makeBlockInst(switch_tag, switch_node);

    // We re-use this same scope for all cases, including the special prong, if any.
    var case_scope = parent_gz.makeSubBlock(&block_scope.base);
    case_scope.instructions_top = GenZir.unstacked_top;

    // If any prong has an inline tag capture, allocate a shared dummy instruction for it
    const tag_inst = if (any_has_tag_capture) tag_inst: {
        const inst: Zir.Inst.Index = @enumFromInt(astgen.instructions.len);
        try astgen.instructions.append(astgen.gpa, .{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .value_placeholder,
                .small = undefined,
                .operand = undefined,
            } },
        });
        break :tag_inst inst;
    } else undefined;

    // In this pass we generate all the item and prong expressions.
    var multi_case_index: u32 = 0;
    var scalar_case_index: u32 = 0;
    for (case_nodes) |case_node| {
        const case = tree.fullSwitchCase(case_node).?;

        const is_multi_case = case.ast.values.len > 1 or
            (case.ast.values.len == 1 and node_tags[case.ast.values[0]] == .switch_range);

        var dbg_var_name: Zir.NullTerminatedString = .empty;
        var dbg_var_inst: Zir.Inst.Ref = undefined;
        var dbg_var_tag_name: Zir.NullTerminatedString = .empty;
        var dbg_var_tag_inst: Zir.Inst.Ref = undefined;
        var has_tag_capture = false;
        var capture_val_scope: Scope.LocalVal = undefined;
        var tag_scope: Scope.LocalVal = undefined;

        var capture: Zir.Inst.SwitchBlock.ProngInfo.Capture = .none;

        const sub_scope = blk: {
            const payload_token = case.payload_token orelse break :blk &case_scope.base;
            const ident = if (token_tags[payload_token] == .asterisk)
                payload_token + 1
            else
                payload_token;

            const is_ptr = ident != payload_token;
            capture = if (is_ptr) .by_ref else .by_val;

            const ident_slice = tree.tokenSlice(ident);
            var payload_sub_scope: *Scope = undefined;
            if (mem.eql(u8, ident_slice, "_")) {
                if (is_ptr) {
                    return astgen.failTok(payload_token, "pointer modifier invalid on discard", .{});
                }
                payload_sub_scope = &case_scope.base;
            } else {
                const capture_name = try astgen.identAsString(ident);
                try astgen.detectLocalShadowing(&case_scope.base, capture_name, ident, ident_slice, .capture);
                capture_val_scope = .{
                    .parent = &case_scope.base,
                    .gen_zir = &case_scope,
                    .name = capture_name,
                    .inst = switch_block.toRef(),
                    .token_src = ident,
                    .id_cat = .capture,
                };
                dbg_var_name = capture_name;
                dbg_var_inst = switch_block.toRef();
                payload_sub_scope = &capture_val_scope.base;
            }

            const tag_token = if (token_tags[ident + 1] == .comma)
                ident + 2
            else
                break :blk payload_sub_scope;
            const tag_slice = tree.tokenSlice(tag_token);
            if (mem.eql(u8, tag_slice, "_")) {
                return astgen.failTok(tag_token, "discard of tag capture; omit it instead", .{});
            } else if (case.inline_token == null) {
                return astgen.failTok(tag_token, "tag capture on non-inline prong", .{});
            }
            const tag_name = try astgen.identAsString(tag_token);
            try astgen.detectLocalShadowing(payload_sub_scope, tag_name, tag_token, tag_slice, .@"switch tag capture");

            assert(any_has_tag_capture);
            has_tag_capture = true;

            tag_scope = .{
                .parent = payload_sub_scope,
                .gen_zir = &case_scope,
                .name = tag_name,
                .inst = tag_inst.toRef(),
                .token_src = tag_token,
                .id_cat = .@"switch tag capture",
            };
            dbg_var_tag_name = tag_name;
            dbg_var_tag_inst = tag_inst.toRef();
            break :blk &tag_scope.base;
        };

        const header_index: u32 = @intCast(payloads.items.len);
        const body_len_index = if (is_multi_case) blk: {
            payloads.items[multi_case_table + multi_case_index] = header_index;
            multi_case_index += 1;
            try payloads.resize(gpa, header_index + 3); // items_len, ranges_len, body_len

            // items
            var items_len: u32 = 0;
            for (case.ast.values) |item_node| {
                if (node_tags[item_node] == .switch_range) continue;
                items_len += 1;

                const item_inst = try comptimeExpr(parent_gz, scope, item_ri, item_node);
                try payloads.append(gpa, @intFromEnum(item_inst));
            }

            // ranges
            var ranges_len: u32 = 0;
            for (case.ast.values) |range| {
                if (node_tags[range] != .switch_range) continue;
                ranges_len += 1;

                const first = try comptimeExpr(parent_gz, scope, item_ri, node_datas[range].lhs);
                const last = try comptimeExpr(parent_gz, scope, item_ri, node_datas[range].rhs);
                try payloads.appendSlice(gpa, &[_]u32{
                    @intFromEnum(first), @intFromEnum(last),
                });
            }

            payloads.items[header_index] = items_len;
            payloads.items[header_index + 1] = ranges_len;
            break :blk header_index + 2;
        } else if (case_node == special_node) blk: {
            payloads.items[case_table_start] = header_index;
            try payloads.resize(gpa, header_index + 1); // body_len
            break :blk header_index;
        } else blk: {
            payloads.items[scalar_case_table + scalar_case_index] = header_index;
            scalar_case_index += 1;
            try payloads.resize(gpa, header_index + 2); // item, body_len
            const item_node = case.ast.values[0];
            const item_inst = try comptimeExpr(parent_gz, scope, item_ri, item_node);
            payloads.items[header_index] = @intFromEnum(item_inst);
            break :blk header_index + 1;
        };

        {
            // temporarily stack case_scope on parent_gz
            case_scope.instructions_top = parent_gz.instructions.items.len;
            defer case_scope.unstack();

            if (dbg_var_name != .empty) {
                try case_scope.addDbgVar(.dbg_var_val, dbg_var_name, dbg_var_inst);
            }
            if (dbg_var_tag_name != .empty) {
                try case_scope.addDbgVar(.dbg_var_val, dbg_var_tag_name, dbg_var_tag_inst);
            }
            const target_expr_node = case.ast.target_expr;
            const case_result = try fullBodyExpr(&case_scope, sub_scope, block_scope.break_result_info, target_expr_node);
            try checkUsed(parent_gz, &case_scope.base, sub_scope);
            if (!parent_gz.refIsNoReturn(case_result)) {
                _ = try case_scope.addBreakWithSrcNode(.@"break", switch_block, case_result, target_expr_node);
            }

            const case_slice = case_scope.instructionsSlice();
            // Since we use the switch_block instruction itself to refer to the
            // capture, which will not be added to the child block, we need to
            // handle ref_table manually, and the same for the inline tag
            // capture instruction.
            const refs_len = refs: {
                var n: usize = 0;
                var check_inst = switch_block;
                while (astgen.ref_table.get(check_inst)) |ref_inst| {
                    n += 1;
                    check_inst = ref_inst;
                }
                if (has_tag_capture) {
                    check_inst = tag_inst;
                    while (astgen.ref_table.get(check_inst)) |ref_inst| {
                        n += 1;
                        check_inst = ref_inst;
                    }
                }
                break :refs n;
            };
            const body_len = refs_len + astgen.countBodyLenAfterFixups(case_slice);
            try payloads.ensureUnusedCapacity(gpa, body_len);
            payloads.items[body_len_index] = @bitCast(Zir.Inst.SwitchBlock.ProngInfo{
                .body_len = @intCast(body_len),
                .capture = capture,
                .is_inline = case.inline_token != null,
                .has_tag_capture = has_tag_capture,
            });
            if (astgen.ref_table.fetchRemove(switch_block)) |kv| {
                appendPossiblyRefdBodyInst(astgen, payloads, kv.value);
            }
            if (has_tag_capture) {
                if (astgen.ref_table.fetchRemove(tag_inst)) |kv| {
                    appendPossiblyRefdBodyInst(astgen, payloads, kv.value);
                }
            }
            appendBodyWithFixupsArrayList(astgen, payloads, case_slice);
        }
    }
    // Now that the item expressions are generated we can add this.
    try parent_gz.instructions.append(gpa, switch_block);

    try astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.SwitchBlock).Struct.fields.len +
        @intFromBool(multi_cases_len != 0) +
        @intFromBool(any_has_tag_capture) +
        payloads.items.len - case_table_end +
        (case_table_end - case_table_start) * @typeInfo(Zir.Inst.As).Struct.fields.len);

    const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.SwitchBlock{
        .operand = raw_operand,
        .bits = Zir.Inst.SwitchBlock.Bits{
            .has_multi_cases = multi_cases_len != 0,
            .has_else = special_prong == .@"else",
            .has_under = special_prong == .under,
            .any_has_tag_capture = any_has_tag_capture,
            .scalar_cases_len = @intCast(scalar_cases_len),
        },
    });

    if (multi_cases_len != 0) {
        astgen.extra.appendAssumeCapacity(multi_cases_len);
    }

    if (any_has_tag_capture) {
        astgen.extra.appendAssumeCapacity(@intFromEnum(tag_inst));
    }

    const zir_datas = astgen.instructions.items(.data);
    zir_datas[@intFromEnum(switch_block)].pl_node.payload_index = payload_index;

    for (payloads.items[case_table_start..case_table_end], 0..) |start_index, i| {
        var body_len_index = start_index;
        var end_index = start_index;
        const table_index = case_table_start + i;
        if (table_index < scalar_case_table) {
            end_index += 1;
        } else if (table_index < multi_case_table) {
            body_len_index += 1;
            end_index += 2;
        } else {
            body_len_index += 2;
            const items_len = payloads.items[start_index];
            const ranges_len = payloads.items[start_index + 1];
            end_index += 3 + items_len + 2 * ranges_len;
        }
        const prong_info: Zir.Inst.SwitchBlock.ProngInfo = @bitCast(payloads.items[body_len_index]);
        end_index += prong_info.body_len;
        astgen.extra.appendSliceAssumeCapacity(payloads.items[start_index..end_index]);
    }

    if (need_result_rvalue) {
        return rvalue(parent_gz, ri, switch_block.toRef(), switch_node);
    } else {
        return switch_block.toRef();
    }
}

fn ret(gz: *GenZir, scope: *Scope, node: Ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);
    const node_tags = tree.nodes.items(.tag);

    if (astgen.fn_block == null) {
        return astgen.failNode(node, "'return' outside function scope", .{});
    }

    if (gz.any_defer_node != 0) {
        return astgen.failNodeNotes(node, "cannot return from defer expression", .{}, &.{
            try astgen.errNoteNode(
                gz.any_defer_node,
                "defer expression here",
                .{},
            ),
        });
    }

    // Ensure debug line/column information is emitted for this return expression.
    // Then we will save the line/column so that we can emit another one that goes
    // "backwards" because we want to evaluate the operand, but then put the debug
    // info back at the return keyword for error return tracing.
    if (!gz.is_comptime) {
        try emitDbgNode(gz, node);
    }
    const ret_lc = LineColumn{ astgen.source_line - gz.decl_line, astgen.source_column };

    const defer_outer = &astgen.fn_block.?.base;

    const operand_node = node_datas[node].lhs;
    if (operand_node == 0) {
        // Returning a void value; skip error defers.
        try genDefers(gz, defer_outer, scope, .normal_only);

        // As our last action before the return, "pop" the error trace if needed
        _ = try gz.addRestoreErrRetIndex(.ret, .always, node);

        _ = try gz.addUnNode(.ret_node, .void_value, node);
        return Zir.Inst.Ref.unreachable_value;
    }

    if (node_tags[operand_node] == .error_value) {
        // Hot path for `return error.Foo`. This bypasses result location logic as well as logic
        // for detecting whether to add something to the function's inferred error set.
        const ident_token = node_datas[operand_node].rhs;
        const err_name_str_index = try astgen.identAsString(ident_token);
        const defer_counts = countDefers(defer_outer, scope);
        if (!defer_counts.need_err_code) {
            try genDefers(gz, defer_outer, scope, .both_sans_err);
            try emitDbgStmt(gz, ret_lc);
            _ = try gz.addStrTok(.ret_err_value, err_name_str_index, ident_token);
            return Zir.Inst.Ref.unreachable_value;
        }
        const err_code = try gz.addStrTok(.ret_err_value_code, err_name_str_index, ident_token);
        try genDefers(gz, defer_outer, scope, .{ .both = err_code });
        try emitDbgStmt(gz, ret_lc);
        _ = try gz.addUnNode(.ret_node, err_code, node);
        return Zir.Inst.Ref.unreachable_value;
    }

    const ri: ResultInfo = if (astgen.nodes_need_rl.contains(node)) .{
        .rl = .{ .ptr = .{ .inst = try gz.addNode(.ret_ptr, node) } },
        .ctx = .@"return",
    } else .{
        .rl = .{ .coerced_ty = astgen.fn_ret_ty },
        .ctx = .@"return",
    };
    const prev_anon_name_strategy = gz.anon_name_strategy;
    gz.anon_name_strategy = .func;
    const operand = try reachableExpr(gz, scope, ri, operand_node, node);
    gz.anon_name_strategy = prev_anon_name_strategy;

    switch (nodeMayEvalToError(tree, operand_node)) {
        .never => {
            // Returning a value that cannot be an error; skip error defers.
            try genDefers(gz, defer_outer, scope, .normal_only);

            // As our last action before the return, "pop" the error trace if needed
            _ = try gz.addRestoreErrRetIndex(.ret, .always, node);

            try emitDbgStmt(gz, ret_lc);
            try gz.addRet(ri, operand, node);
            return Zir.Inst.Ref.unreachable_value;
        },
        .always => {
            // Value is always an error. Emit both error defers and regular defers.
            const err_code = if (ri.rl == .ptr) try gz.addUnNode(.load, ri.rl.ptr.inst, node) else operand;
            try genDefers(gz, defer_outer, scope, .{ .both = err_code });
            try emitDbgStmt(gz, ret_lc);
            try gz.addRet(ri, operand, node);
            return Zir.Inst.Ref.unreachable_value;
        },
        .maybe => {
            const defer_counts = countDefers(defer_outer, scope);
            if (!defer_counts.have_err) {
                // Only regular defers; no branch needed.
                try genDefers(gz, defer_outer, scope, .normal_only);
                try emitDbgStmt(gz, ret_lc);

                // As our last action before the return, "pop" the error trace if needed
                const result = if (ri.rl == .ptr) try gz.addUnNode(.load, ri.rl.ptr.inst, node) else operand;
                _ = try gz.addRestoreErrRetIndex(.ret, .{ .if_non_error = result }, node);

                try gz.addRet(ri, operand, node);
                return Zir.Inst.Ref.unreachable_value;
            }

            // Emit conditional branch for generating errdefers.
            const result = if (ri.rl == .ptr) try gz.addUnNode(.load, ri.rl.ptr.inst, node) else operand;
            const is_non_err = try gz.addUnNode(.ret_is_non_err, result, node);
            const condbr = try gz.addCondBr(.condbr, node);

            var then_scope = gz.makeSubBlock(scope);
            defer then_scope.unstack();

            try genDefers(&then_scope, defer_outer, scope, .normal_only);

            // As our last action before the return, "pop" the error trace if needed
            _ = try then_scope.addRestoreErrRetIndex(.ret, .always, node);

            try emitDbgStmt(&then_scope, ret_lc);
            try then_scope.addRet(ri, operand, node);

            var else_scope = gz.makeSubBlock(scope);
            defer else_scope.unstack();

            const which_ones: DefersToEmit = if (!defer_counts.need_err_code) .both_sans_err else .{
                .both = try else_scope.addUnNode(.err_union_code, result, node),
            };
            try genDefers(&else_scope, defer_outer, scope, which_ones);
            try emitDbgStmt(&else_scope, ret_lc);
            try else_scope.addRet(ri, operand, node);

            try setCondBrPayload(condbr, is_non_err, &then_scope, &else_scope);

            return Zir.Inst.Ref.unreachable_value;
        },
    }
}

/// Parses the string `buf` as a base 10 integer of type `u16`.
///
/// Unlike std.fmt.parseInt, does not allow the '_' character in `buf`.
fn parseBitCount(buf: []const u8) std.fmt.ParseIntError!u16 {
    if (buf.len == 0) return error.InvalidCharacter;

    var x: u16 = 0;

    for (buf) |c| {
        const digit = switch (c) {
            '0'...'9' => c - '0',
            else => return error.InvalidCharacter,
        };

        if (x != 0) x = try std.math.mul(u16, x, 10);
        x = try std.math.add(u16, x, digit);
    }

    return x;
}

fn identifier(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    ident: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);

    const ident_token = main_tokens[ident];
    const ident_name_raw = tree.tokenSlice(ident_token);
    if (mem.eql(u8, ident_name_raw, "_")) {
        return astgen.failNode(ident, "'_' used as an identifier without @\"_\" syntax", .{});
    }

    // if not @"" syntax, just use raw token slice
    if (ident_name_raw[0] != '@') {
        if (primitive_instrs.get(ident_name_raw)) |zir_const_ref| {
            return rvalue(gz, ri, zir_const_ref, ident);
        }

        if (ident_name_raw.len >= 2) integer: {
            const first_c = ident_name_raw[0];
            if (first_c == 'i' or first_c == 'u') {
                const signedness: std.builtin.Signedness = switch (first_c == 'i') {
                    true => .signed,
                    false => .unsigned,
                };
                if (ident_name_raw.len >= 3 and ident_name_raw[1] == '0') {
                    return astgen.failNode(
                        ident,
                        "primitive integer type '{s}' has leading zero",
                        .{ident_name_raw},
                    );
                }
                const bit_count = parseBitCount(ident_name_raw[1..]) catch |err| switch (err) {
                    error.Overflow => return astgen.failNode(
                        ident,
                        "primitive integer type '{s}' exceeds maximum bit width of 65535",
                        .{ident_name_raw},
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
                return rvalue(gz, ri, result, ident);
            }
        }
    }

    // Local variables, including function parameters.
    return localVarRef(gz, scope, ri, ident, ident_token);
}

fn localVarRef(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    ident: Ast.Node.Index,
    ident_token: Ast.TokenIndex,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const name_str_index = try astgen.identAsString(ident_token);
    var s = scope;
    var found_already: ?Ast.Node.Index = null; // we have found a decl with the same name already
    var found_needs_tunnel: bool = undefined; // defined when `found_already != null`
    var found_namespaces_out: u32 = undefined; // defined when `found_already != null`

    // The number of namespaces above `gz` we currently are
    var num_namespaces_out: u32 = 0;
    // defined by `num_namespaces_out != 0`
    var capturing_namespace: *Scope.Namespace = undefined;

    while (true) switch (s.tag) {
        .local_val => {
            const local_val = s.cast(Scope.LocalVal).?;

            if (local_val.name == name_str_index) {
                // Locals cannot shadow anything, so we do not need to look for ambiguous
                // references in this case.
                if (ri.rl == .discard and ri.ctx == .assignment) {
                    local_val.discarded = ident_token;
                } else {
                    local_val.used = ident_token;
                }

                const value_inst = if (num_namespaces_out != 0) try tunnelThroughClosure(
                    gz,
                    ident,
                    num_namespaces_out,
                    .{ .ref = local_val.inst },
                    .{ .token = local_val.token_src },
                ) else local_val.inst;

                return rvalueNoCoercePreRef(gz, ri, value_inst, ident);
            }
            s = local_val.parent;
        },
        .local_ptr => {
            const local_ptr = s.cast(Scope.LocalPtr).?;
            if (local_ptr.name == name_str_index) {
                if (ri.rl == .discard and ri.ctx == .assignment) {
                    local_ptr.discarded = ident_token;
                } else {
                    local_ptr.used = ident_token;
                }

                // Can't close over a runtime variable
                if (num_namespaces_out != 0 and !local_ptr.maybe_comptime and !gz.is_typeof) {
                    const ident_name = try astgen.identifierTokenString(ident_token);
                    return astgen.failNodeNotes(ident, "mutable '{s}' not accessible from here", .{ident_name}, &.{
                        try astgen.errNoteTok(local_ptr.token_src, "declared mutable here", .{}),
                        try astgen.errNoteNode(capturing_namespace.node, "crosses namespace boundary here", .{}),
                    });
                }

                switch (ri.rl) {
                    .ref, .ref_coerced_ty => {
                        const ptr_inst = if (num_namespaces_out != 0) try tunnelThroughClosure(
                            gz,
                            ident,
                            num_namespaces_out,
                            .{ .ref = local_ptr.ptr },
                            .{ .token = local_ptr.token_src },
                        ) else local_ptr.ptr;
                        local_ptr.used_as_lvalue = true;
                        return ptr_inst;
                    },
                    else => {
                        const val_inst = if (num_namespaces_out != 0) try tunnelThroughClosure(
                            gz,
                            ident,
                            num_namespaces_out,
                            .{ .ref_load = local_ptr.ptr },
                            .{ .token = local_ptr.token_src },
                        ) else try gz.addUnNode(.load, local_ptr.ptr, ident);
                        return rvalueNoCoercePreRef(gz, ri, val_inst, ident);
                    },
                }
            }
            s = local_ptr.parent;
        },
        .gen_zir => s = s.cast(GenZir).?.parent,
        .defer_normal, .defer_error => s = s.cast(Scope.Defer).?.parent,
        .namespace => {
            const ns = s.cast(Scope.Namespace).?;
            if (ns.decls.get(name_str_index)) |i| {
                if (found_already) |f| {
                    return astgen.failNodeNotes(ident, "ambiguous reference", .{}, &.{
                        try astgen.errNoteNode(f, "declared here", .{}),
                        try astgen.errNoteNode(i, "also declared here", .{}),
                    });
                }
                // We found a match but must continue looking for ambiguous references to decls.
                found_already = i;
                found_needs_tunnel = ns.maybe_generic;
                found_namespaces_out = num_namespaces_out;
            }
            num_namespaces_out += 1;
            capturing_namespace = ns;
            s = ns.parent;
        },
        .top => break,
    };
    if (found_already == null) {
        const ident_name = try astgen.identifierTokenString(ident_token);
        return astgen.failNode(ident, "use of undeclared identifier '{s}'", .{ident_name});
    }

    // Decl references happen by name rather than ZIR index so that when unrelated
    // decls are modified, ZIR code containing references to them can be unmodified.

    if (found_namespaces_out > 0 and found_needs_tunnel) {
        switch (ri.rl) {
            .ref, .ref_coerced_ty => return tunnelThroughClosure(
                gz,
                ident,
                found_namespaces_out,
                .{ .decl_ref = name_str_index },
                .{ .node = found_already.? },
            ),
            else => {
                const result = try tunnelThroughClosure(
                    gz,
                    ident,
                    found_namespaces_out,
                    .{ .decl_val = name_str_index },
                    .{ .node = found_already.? },
                );
                return rvalueNoCoercePreRef(gz, ri, result, ident);
            },
        }
    }

    switch (ri.rl) {
        .ref, .ref_coerced_ty => return gz.addStrTok(.decl_ref, name_str_index, ident_token),
        else => {
            const result = try gz.addStrTok(.decl_val, name_str_index, ident_token);
            return rvalueNoCoercePreRef(gz, ri, result, ident);
        },
    }
}

/// Access a ZIR instruction through closure. May tunnel through arbitrarily
/// many namespaces, adding closure captures as required.
/// Returns the index of the `closure_get` instruction added to `gz`.
fn tunnelThroughClosure(
    gz: *GenZir,
    /// The node which references the value to be captured.
    inner_ref_node: Ast.Node.Index,
    /// The number of namespaces being tunnelled through. At least 1.
    num_tunnels: u32,
    /// The value being captured.
    value: union(enum) {
        ref: Zir.Inst.Ref,
        ref_load: Zir.Inst.Ref,
        decl_val: Zir.NullTerminatedString,
        decl_ref: Zir.NullTerminatedString,
    },
    /// The location of the value's declaration.
    decl_src: union(enum) {
        token: Ast.TokenIndex,
        node: Ast.Node.Index,
    },
) !Zir.Inst.Ref {
    switch (value) {
        .ref => |v| if (v.toIndex() == null) return v, // trivial value; do not need tunnel
        .ref_load => |v| assert(v.toIndex() != null), // there are no constant pointer refs
        .decl_val, .decl_ref => {},
    }

    const astgen = gz.astgen;
    const gpa = astgen.gpa;

    // Otherwise we need a tunnel. First, figure out the path of namespaces we
    // are tunneling through. This is usually only going to be one or two, so
    // use an SFBA to optimize for the common case.
    var sfba = std.heap.stackFallback(@sizeOf(usize) * 2, astgen.arena);
    var intermediate_tunnels = try sfba.get().alloc(*Scope.Namespace, num_tunnels - 1);

    const root_ns = ns: {
        var i: usize = num_tunnels - 1;
        var scope: *Scope = gz.parent;
        while (i > 0) {
            if (scope.cast(Scope.Namespace)) |mid_ns| {
                i -= 1;
                intermediate_tunnels[i] = mid_ns;
            }
            scope = scope.parent().?;
        }
        while (true) {
            if (scope.cast(Scope.Namespace)) |ns| break :ns ns;
            scope = scope.parent().?;
        }
    };

    // Now that we know the scopes we're tunneling through, begin adding
    // captures as required, starting with the outermost namespace.
    const root_capture = Zir.Inst.Capture.wrap(switch (value) {
        .ref => |v| .{ .instruction = v.toIndex().? },
        .ref_load => |v| .{ .instruction_load = v.toIndex().? },
        .decl_val => |str| .{ .decl_val = str },
        .decl_ref => |str| .{ .decl_ref = str },
    });
    var cur_capture_index = std.math.cast(
        u16,
        (try root_ns.captures.getOrPut(gpa, root_capture)).index,
    ) orelse return astgen.failNodeNotes(root_ns.node, "this compiler implementation only supports up to 65536 captures per namespace", .{}, &.{
        switch (decl_src) {
            .token => |t| try astgen.errNoteTok(t, "captured value here", .{}),
            .node => |n| try astgen.errNoteNode(n, "captured value here", .{}),
        },
        try astgen.errNoteNode(inner_ref_node, "value used here", .{}),
    });

    for (intermediate_tunnels) |tunnel_ns| {
        cur_capture_index = std.math.cast(
            u16,
            (try tunnel_ns.captures.getOrPut(gpa, Zir.Inst.Capture.wrap(.{ .nested = cur_capture_index }))).index,
        ) orelse return astgen.failNodeNotes(tunnel_ns.node, "this compiler implementation only supports up to 65536 captures per namespace", .{}, &.{
            switch (decl_src) {
                .token => |t| try astgen.errNoteTok(t, "captured value here", .{}),
                .node => |n| try astgen.errNoteNode(n, "captured value here", .{}),
            },
            try astgen.errNoteNode(inner_ref_node, "value used here", .{}),
        });
    }

    // Add an instruction to get the value from the closure.
    return gz.addExtendedNodeSmall(.closure_get, inner_ref_node, cur_capture_index);
}

fn stringLiteral(
    gz: *GenZir,
    ri: ResultInfo,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const str_lit_token = main_tokens[node];
    const str = try astgen.strLitAsString(str_lit_token);
    const result = try gz.add(.{
        .tag = .str,
        .data = .{ .str = .{
            .start = str.index,
            .len = str.len,
        } },
    });
    return rvalue(gz, ri, result, node);
}

fn multilineStringLiteral(
    gz: *GenZir,
    ri: ResultInfo,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const str = try astgen.strLitNodeAsString(node);
    const result = try gz.add(.{
        .tag = .str,
        .data = .{ .str = .{
            .start = str.index,
            .len = str.len,
        } },
    });
    return rvalue(gz, ri, result, node);
}

fn charLiteral(gz: *GenZir, ri: ResultInfo, node: Ast.Node.Index) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const main_token = main_tokens[node];
    const slice = tree.tokenSlice(main_token);

    switch (std.zig.parseCharLiteral(slice)) {
        .success => |codepoint| {
            const result = try gz.addInt(codepoint);
            return rvalue(gz, ri, result, node);
        },
        .failure => |err| return astgen.failWithStrLitError(err, main_token, slice, 0),
    }
}

const Sign = enum { negative, positive };

fn numberLiteral(gz: *GenZir, ri: ResultInfo, node: Ast.Node.Index, source_node: Ast.Node.Index, sign: Sign) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const num_token = main_tokens[node];
    const bytes = tree.tokenSlice(num_token);

    const result: Zir.Inst.Ref = switch (std.zig.parseNumberLiteral(bytes)) {
        .int => |num| switch (num) {
            0 => if (sign == .positive) .zero else return astgen.failTokNotes(
                num_token,
                "integer literal '-0' is ambiguous",
                .{},
                &.{
                    try astgen.errNoteTok(num_token, "use '0' for an integer zero", .{}),
                    try astgen.errNoteTok(num_token, "use '-0.0' for a floating-point signed zero", .{}),
                },
            ),
            1 => {
                // Handle the negation here!
                const result: Zir.Inst.Ref = switch (sign) {
                    .positive => .one,
                    .negative => .negative_one,
                };
                return rvalue(gz, ri, result, source_node);
            },
            else => try gz.addInt(num),
        },
        .big_int => |base| big: {
            const gpa = astgen.gpa;
            var big_int = try std.math.big.int.Managed.init(gpa);
            defer big_int.deinit();
            const prefix_offset: usize = if (base == .decimal) 0 else 2;
            big_int.setString(@intFromEnum(base), bytes[prefix_offset..]) catch |err| switch (err) {
                error.InvalidCharacter => unreachable, // caught in `parseNumberLiteral`
                error.InvalidBase => unreachable, // we only pass 16, 8, 2, see above
                error.OutOfMemory => return error.OutOfMemory,
            };

            const limbs = big_int.limbs[0..big_int.len()];
            assert(big_int.isPositive());
            break :big try gz.addIntBig(limbs);
        },
        .float => {
            const unsigned_float_number = std.fmt.parseFloat(f128, bytes) catch |err| switch (err) {
                error.InvalidCharacter => unreachable, // validated by tokenizer
            };
            const float_number = switch (sign) {
                .negative => -unsigned_float_number,
                .positive => unsigned_float_number,
            };
            // If the value fits into a f64 without losing any precision, store it that way.
            @setFloatMode(.strict);
            const smaller_float: f64 = @floatCast(float_number);
            const bigger_again: f128 = smaller_float;
            if (bigger_again == float_number) {
                const result = try gz.addFloat(smaller_float);
                return rvalue(gz, ri, result, source_node);
            }
            // We need to use 128 bits. Break the float into 4 u32 values so we can
            // put it into the `extra` array.
            const int_bits: u128 = @bitCast(float_number);
            const result = try gz.addPlNode(.float128, node, Zir.Inst.Float128{
                .piece0 = @truncate(int_bits),
                .piece1 = @truncate(int_bits >> 32),
                .piece2 = @truncate(int_bits >> 64),
                .piece3 = @truncate(int_bits >> 96),
            });
            return rvalue(gz, ri, result, source_node);
        },
        .failure => |err| return astgen.failWithNumberError(err, num_token, bytes),
    };

    if (sign == .positive) {
        return rvalue(gz, ri, result, source_node);
    } else {
        const negated = try gz.addUnNode(.negate, result, source_node);
        return rvalue(gz, ri, negated, source_node);
    }
}

fn failWithNumberError(astgen: *AstGen, err: std.zig.number_literal.Error, token: Ast.TokenIndex, bytes: []const u8) InnerError {
    const is_float = std.mem.indexOfScalar(u8, bytes, '.') != null;
    switch (err) {
        .leading_zero => if (is_float) {
            return astgen.failTok(token, "number '{s}' has leading zero", .{bytes});
        } else {
            return astgen.failTokNotes(token, "number '{s}' has leading zero", .{bytes}, &.{
                try astgen.errNoteTok(token, "use '0o' prefix for octal literals", .{}),
            });
        },
        .digit_after_base => return astgen.failTok(token, "expected a digit after base prefix", .{}),
        .upper_case_base => |i| return astgen.failOff(token, @intCast(i), "base prefix must be lowercase", .{}),
        .invalid_float_base => |i| return astgen.failOff(token, @intCast(i), "invalid base for float literal", .{}),
        .repeated_underscore => |i| return astgen.failOff(token, @intCast(i), "repeated digit separator", .{}),
        .invalid_underscore_after_special => |i| return astgen.failOff(token, @intCast(i), "expected digit before digit separator", .{}),
        .invalid_digit => |info| return astgen.failOff(token, @intCast(info.i), "invalid digit '{c}' for {s} base", .{ bytes[info.i], @tagName(info.base) }),
        .invalid_digit_exponent => |i| return astgen.failOff(token, @intCast(i), "invalid digit '{c}' in exponent", .{bytes[i]}),
        .duplicate_exponent => |i| return astgen.failOff(token, @intCast(i), "duplicate exponent", .{}),
        .exponent_after_underscore => |i| return astgen.failOff(token, @intCast(i), "expected digit before exponent", .{}),
        .special_after_underscore => |i| return astgen.failOff(token, @intCast(i), "expected digit before '{c}'", .{bytes[i]}),
        .trailing_special => |i| return astgen.failOff(token, @intCast(i), "expected digit after '{c}'", .{bytes[i - 1]}),
        .trailing_underscore => |i| return astgen.failOff(token, @intCast(i), "trailing digit separator", .{}),
        .duplicate_period => unreachable, // Validated by tokenizer
        .invalid_character => unreachable, // Validated by tokenizer
        .invalid_exponent_sign => |i| {
            assert(bytes.len >= 2 and bytes[0] == '0' and bytes[1] == 'x'); // Validated by tokenizer
            return astgen.failOff(token, @intCast(i), "sign '{c}' cannot follow digit '{c}' in hex base", .{ bytes[i], bytes[i - 1] });
        },
    }
}

fn asmExpr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    full: Ast.full.Asm,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const node_datas = tree.nodes.items(.data);
    const node_tags = tree.nodes.items(.tag);
    const token_tags = tree.tokens.items(.tag);

    const TagAndTmpl = struct { tag: Zir.Inst.Extended, tmpl: Zir.NullTerminatedString };
    const tag_and_tmpl: TagAndTmpl = switch (node_tags[full.ast.template]) {
        .string_literal => .{
            .tag = .@"asm",
            .tmpl = (try astgen.strLitAsString(main_tokens[full.ast.template])).index,
        },
        .multiline_string_literal => .{
            .tag = .@"asm",
            .tmpl = (try astgen.strLitNodeAsString(full.ast.template)).index,
        },
        else => .{
            .tag = .asm_expr,
            .tmpl = @enumFromInt(@intFromEnum(try comptimeExpr(gz, scope, .{ .rl = .none }, full.ast.template))),
        },
    };

    // See https://github.com/ziglang/zig/issues/215 and related issues discussing
    // possible inline assembly improvements. Until then here is status quo AstGen
    // for assembly syntax. It's used by std lib crypto aesni.zig.
    const is_container_asm = astgen.fn_block == null;
    if (is_container_asm) {
        if (full.volatile_token) |t|
            return astgen.failTok(t, "volatile is meaningless on global assembly", .{});
        if (full.outputs.len != 0 or full.inputs.len != 0 or full.first_clobber != null)
            return astgen.failNode(node, "global assembly cannot have inputs, outputs, or clobbers", .{});
    } else {
        if (full.outputs.len == 0 and full.volatile_token == null) {
            return astgen.failNode(node, "assembly expression with no output must be marked volatile", .{});
        }
    }
    if (full.outputs.len > 32) {
        return astgen.failNode(full.outputs[32], "too many asm outputs", .{});
    }
    var outputs_buffer: [32]Zir.Inst.Asm.Output = undefined;
    const outputs = outputs_buffer[0..full.outputs.len];

    var output_type_bits: u32 = 0;

    for (full.outputs, 0..) |output_node, i| {
        const symbolic_name = main_tokens[output_node];
        const name = try astgen.identAsString(symbolic_name);
        const constraint_token = symbolic_name + 2;
        const constraint = (try astgen.strLitAsString(constraint_token)).index;
        const has_arrow = token_tags[symbolic_name + 4] == .arrow;
        if (has_arrow) {
            if (output_type_bits != 0) {
                return astgen.failNode(output_node, "inline assembly allows up to one output value", .{});
            }
            output_type_bits |= @as(u32, 1) << @intCast(i);
            const out_type_node = node_datas[output_node].lhs;
            const out_type_inst = try typeExpr(gz, scope, out_type_node);
            outputs[i] = .{
                .name = name,
                .constraint = constraint,
                .operand = out_type_inst,
            };
        } else {
            const ident_token = symbolic_name + 4;
            // TODO have a look at #215 and related issues and decide how to
            // handle outputs. Do we want this to be identifiers?
            // Or maybe we want to force this to be expressions with a pointer type.
            outputs[i] = .{
                .name = name,
                .constraint = constraint,
                .operand = try localVarRef(gz, scope, .{ .rl = .ref }, node, ident_token),
            };
        }
    }

    if (full.inputs.len > 32) {
        return astgen.failNode(full.inputs[32], "too many asm inputs", .{});
    }
    var inputs_buffer: [32]Zir.Inst.Asm.Input = undefined;
    const inputs = inputs_buffer[0..full.inputs.len];

    for (full.inputs, 0..) |input_node, i| {
        const symbolic_name = main_tokens[input_node];
        const name = try astgen.identAsString(symbolic_name);
        const constraint_token = symbolic_name + 2;
        const constraint = (try astgen.strLitAsString(constraint_token)).index;
        const operand = try expr(gz, scope, .{ .rl = .none }, node_datas[input_node].lhs);
        inputs[i] = .{
            .name = name,
            .constraint = constraint,
            .operand = operand,
        };
    }

    var clobbers_buffer: [32]u32 = undefined;
    var clobber_i: usize = 0;
    if (full.first_clobber) |first_clobber| clobbers: {
        // asm ("foo" ::: "a", "b")
        // asm ("foo" ::: "a", "b",)
        var tok_i = first_clobber;
        while (true) : (tok_i += 1) {
            if (clobber_i >= clobbers_buffer.len) {
                return astgen.failTok(tok_i, "too many asm clobbers", .{});
            }
            clobbers_buffer[clobber_i] = @intFromEnum((try astgen.strLitAsString(tok_i)).index);
            clobber_i += 1;
            tok_i += 1;
            switch (token_tags[tok_i]) {
                .r_paren => break :clobbers,
                .comma => {
                    if (token_tags[tok_i + 1] == .r_paren) {
                        break :clobbers;
                    } else {
                        continue;
                    }
                },
                else => unreachable,
            }
        }
    }

    const result = try gz.addAsm(.{
        .tag = tag_and_tmpl.tag,
        .node = node,
        .asm_source = tag_and_tmpl.tmpl,
        .is_volatile = full.volatile_token != null,
        .output_type_bits = output_type_bits,
        .outputs = outputs,
        .inputs = inputs,
        .clobbers = clobbers_buffer[0..clobber_i],
    });
    return rvalue(gz, ri, result, node);
}

fn as(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    lhs: Ast.Node.Index,
    rhs: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const dest_type = try typeExpr(gz, scope, lhs);
    const result = try reachableExpr(gz, scope, .{ .rl = .{ .ty = dest_type } }, rhs, node);
    return rvalue(gz, ri, result, node);
}

fn unionInit(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    params: []const Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const union_type = try typeExpr(gz, scope, params[0]);
    const field_name = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .slice_const_u8_type } }, params[1]);
    const field_type = try gz.addPlNode(.field_type_ref, node, Zir.Inst.FieldTypeRef{
        .container_type = union_type,
        .field_name = field_name,
    });
    const init = try reachableExpr(gz, scope, .{ .rl = .{ .ty = field_type } }, params[2], node);
    const result = try gz.addPlNode(.union_init, node, Zir.Inst.UnionInit{
        .union_type = union_type,
        .init = init,
        .field_name = field_name,
    });
    return rvalue(gz, ri, result, node);
}

fn bitCast(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    operand_node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const dest_type = try ri.rl.resultTypeForCast(gz, node, "@bitCast");
    const operand = try reachableExpr(gz, scope, .{ .rl = .none }, operand_node, node);
    const result = try gz.addPlNode(.bitcast, node, Zir.Inst.Bin{
        .lhs = dest_type,
        .rhs = operand,
    });
    return rvalue(gz, ri, result, node);
}

/// Handle one or more nested pointer cast builtins:
/// * @ptrCast
/// * @alignCast
/// * @addrSpaceCast
/// * @constCast
/// * @volatileCast
/// Any sequence of such builtins is treated as a single operation. This allowed
/// for sequences like `@ptrCast(@alignCast(ptr))` to work correctly despite the
/// intermediate result type being unknown.
fn ptrCast(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    root_node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const main_tokens = tree.nodes.items(.main_token);
    const node_datas = tree.nodes.items(.data);
    const node_tags = tree.nodes.items(.tag);

    const FlagsInt = @typeInfo(Zir.Inst.FullPtrCastFlags).Struct.backing_integer.?;
    var flags: Zir.Inst.FullPtrCastFlags = .{};

    // Note that all pointer cast builtins have one parameter, so we only need
    // to handle `builtin_call_two`.
    var node = root_node;
    while (true) {
        switch (node_tags[node]) {
            .builtin_call_two, .builtin_call_two_comma => {},
            .grouped_expression => {
                // Handle the chaining even with redundant parentheses
                node = node_datas[node].lhs;
                continue;
            },
            else => break,
        }

        if (node_datas[node].lhs == 0) break; // 0 args

        const builtin_token = main_tokens[node];
        const builtin_name = tree.tokenSlice(builtin_token);
        const info = BuiltinFn.list.get(builtin_name) orelse break;
        if (node_datas[node].rhs == 0) {
            // 1 arg
            if (info.param_count != 1) break;

            switch (info.tag) {
                else => break,
                inline .ptr_cast,
                .align_cast,
                .addrspace_cast,
                .const_cast,
                .volatile_cast,
                => |tag| {
                    if (@field(flags, @tagName(tag))) {
                        return astgen.failNode(node, "redundant {s}", .{builtin_name});
                    }
                    @field(flags, @tagName(tag)) = true;
                },
            }

            node = node_datas[node].lhs;
        } else {
            // 2 args
            if (info.param_count != 2) break;

            switch (info.tag) {
                else => break,
                .field_parent_ptr => {
                    if (flags.ptr_cast) break;

                    const flags_int: FlagsInt = @bitCast(flags);
                    const cursor = maybeAdvanceSourceCursorToMainToken(gz, root_node);
                    const parent_ptr_type = try ri.rl.resultTypeForCast(gz, root_node, "@alignCast");
                    const field_name = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .slice_const_u8_type } }, node_datas[node].lhs);
                    const field_ptr = try expr(gz, scope, .{ .rl = .none }, node_datas[node].rhs);
                    try emitDbgStmt(gz, cursor);
                    const result = try gz.addExtendedPayloadSmall(.field_parent_ptr, flags_int, Zir.Inst.FieldParentPtr{
                        .src_node = gz.nodeIndexToRelative(node),
                        .parent_ptr_type = parent_ptr_type,
                        .field_name = field_name,
                        .field_ptr = field_ptr,
                    });
                    return rvalue(gz, ri, result, root_node);
                },
            }
        }
    }

    const flags_int: FlagsInt = @bitCast(flags);
    assert(flags_int != 0);

    const ptr_only: Zir.Inst.FullPtrCastFlags = .{ .ptr_cast = true };
    if (flags_int == @as(FlagsInt, @bitCast(ptr_only))) {
        // Special case: simpler representation
        return typeCast(gz, scope, ri, root_node, node, .ptr_cast, "@ptrCast");
    }

    const no_result_ty_flags: Zir.Inst.FullPtrCastFlags = .{
        .const_cast = true,
        .volatile_cast = true,
    };
    if ((flags_int & ~@as(FlagsInt, @bitCast(no_result_ty_flags))) == 0) {
        // Result type not needed
        const cursor = maybeAdvanceSourceCursorToMainToken(gz, root_node);
        const operand = try expr(gz, scope, .{ .rl = .none }, node);
        try emitDbgStmt(gz, cursor);
        const result = try gz.addExtendedPayloadSmall(.ptr_cast_no_dest, flags_int, Zir.Inst.UnNode{
            .node = gz.nodeIndexToRelative(root_node),
            .operand = operand,
        });
        return rvalue(gz, ri, result, root_node);
    }

    // Full cast including result type

    const cursor = maybeAdvanceSourceCursorToMainToken(gz, root_node);
    const result_type = try ri.rl.resultTypeForCast(gz, root_node, flags.needResultTypeBuiltinName());
    const operand = try expr(gz, scope, .{ .rl = .none }, node);
    try emitDbgStmt(gz, cursor);
    const result = try gz.addExtendedPayloadSmall(.ptr_cast_full, flags_int, Zir.Inst.BinNode{
        .node = gz.nodeIndexToRelative(root_node),
        .lhs = result_type,
        .rhs = operand,
    });
    return rvalue(gz, ri, result, root_node);
}

fn typeOf(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    args: []const Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    if (args.len < 1) {
        return astgen.failNode(node, "expected at least 1 argument, found 0", .{});
    }
    const gpa = astgen.gpa;
    if (args.len == 1) {
        const typeof_inst = try gz.makeBlockInst(.typeof_builtin, node);

        var typeof_scope = gz.makeSubBlock(scope);
        typeof_scope.is_comptime = false;
        typeof_scope.is_typeof = true;
        typeof_scope.c_import = false;
        defer typeof_scope.unstack();

        const ty_expr = try reachableExpr(&typeof_scope, &typeof_scope.base, .{ .rl = .none }, args[0], node);
        if (!gz.refIsNoReturn(ty_expr)) {
            _ = try typeof_scope.addBreak(.break_inline, typeof_inst, ty_expr);
        }
        try typeof_scope.setBlockBody(typeof_inst);

        // typeof_scope unstacked now, can add new instructions to gz
        try gz.instructions.append(gpa, typeof_inst);
        return rvalue(gz, ri, typeof_inst.toRef(), node);
    }
    const payload_size: u32 = std.meta.fields(Zir.Inst.TypeOfPeer).len;
    const payload_index = try reserveExtra(astgen, payload_size + args.len);
    const args_index = payload_index + payload_size;

    const typeof_inst = try gz.addExtendedMultiOpPayloadIndex(.typeof_peer, payload_index, args.len);

    var typeof_scope = gz.makeSubBlock(scope);
    typeof_scope.is_comptime = false;

    for (args, 0..) |arg, i| {
        const param_ref = try reachableExpr(&typeof_scope, &typeof_scope.base, .{ .rl = .none }, arg, node);
        astgen.extra.items[args_index + i] = @intFromEnum(param_ref);
    }
    _ = try typeof_scope.addBreak(.break_inline, typeof_inst.toIndex().?, .void_value);

    const body = typeof_scope.instructionsSlice();
    const body_len = astgen.countBodyLenAfterFixups(body);
    astgen.setExtra(payload_index, Zir.Inst.TypeOfPeer{
        .body_len = @intCast(body_len),
        .body_index = @intCast(astgen.extra.items.len),
        .src_node = gz.nodeIndexToRelative(node),
    });
    try astgen.extra.ensureUnusedCapacity(gpa, body_len);
    astgen.appendBodyWithFixups(body);
    typeof_scope.unstack();

    return rvalue(gz, ri, typeof_inst, node);
}

fn minMax(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    args: []const Ast.Node.Index,
    comptime op: enum { min, max },
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    if (args.len < 2) {
        return astgen.failNode(node, "expected at least 2 arguments, found 0", .{});
    }
    if (args.len == 2) {
        const tag: Zir.Inst.Tag = switch (op) {
            .min => .min,
            .max => .max,
        };
        const a = try expr(gz, scope, .{ .rl = .none }, args[0]);
        const b = try expr(gz, scope, .{ .rl = .none }, args[1]);
        const result = try gz.addPlNode(tag, node, Zir.Inst.Bin{
            .lhs = a,
            .rhs = b,
        });
        return rvalue(gz, ri, result, node);
    }
    const payload_index = try addExtra(astgen, Zir.Inst.NodeMultiOp{
        .src_node = gz.nodeIndexToRelative(node),
    });
    var extra_index = try reserveExtra(gz.astgen, args.len);
    for (args) |arg| {
        const arg_ref = try expr(gz, scope, .{ .rl = .none }, arg);
        astgen.extra.items[extra_index] = @intFromEnum(arg_ref);
        extra_index += 1;
    }
    const tag: Zir.Inst.Extended = switch (op) {
        .min => .min_multi,
        .max => .max_multi,
    };
    const result = try gz.addExtendedMultiOpPayloadIndex(tag, payload_index, args.len);
    return rvalue(gz, ri, result, node);
}

fn builtinCall(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    params: []const Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
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
            return astgen.failNode(node, "expected {d} argument{s}, found {d}", .{
                expected, s, params.len,
            });
        }
    }

    // Check function scope-only builtins

    if (astgen.fn_block == null and info.illegal_outside_function)
        return astgen.failNode(node, "'{s}' outside function scope", .{builtin_name});

    switch (info.tag) {
        .import => {
            const node_tags = tree.nodes.items(.tag);
            const operand_node = params[0];

            if (node_tags[operand_node] != .string_literal) {
                // Spec reference: https://github.com/ziglang/zig/issues/2206
                return astgen.failNode(operand_node, "@import operand must be a string literal", .{});
            }
            const str_lit_token = main_tokens[operand_node];
            const str = try astgen.strLitAsString(str_lit_token);
            const str_slice = astgen.string_bytes.items[@intFromEnum(str.index)..][0..str.len];
            if (mem.indexOfScalar(u8, str_slice, 0) != null) {
                return astgen.failTok(str_lit_token, "import path cannot contain null bytes", .{});
            } else if (str.len == 0) {
                return astgen.failTok(str_lit_token, "import path cannot be empty", .{});
            }
            const result = try gz.addStrTok(.import, str.index, str_lit_token);
            const gop = try astgen.imports.getOrPut(astgen.gpa, str.index);
            if (!gop.found_existing) {
                gop.value_ptr.* = str_lit_token;
            }
            return rvalue(gz, ri, result, node);
        },
        .compile_log => {
            const payload_index = try addExtra(gz.astgen, Zir.Inst.NodeMultiOp{
                .src_node = gz.nodeIndexToRelative(node),
            });
            var extra_index = try reserveExtra(gz.astgen, params.len);
            for (params) |param| {
                const param_ref = try expr(gz, scope, .{ .rl = .none }, param);
                astgen.extra.items[extra_index] = @intFromEnum(param_ref);
                extra_index += 1;
            }
            const result = try gz.addExtendedMultiOpPayloadIndex(.compile_log, payload_index, params.len);
            return rvalue(gz, ri, result, node);
        },
        .field => {
            if (ri.rl == .ref or ri.rl == .ref_coerced_ty) {
                return gz.addPlNode(.field_ptr_named, node, Zir.Inst.FieldNamed{
                    .lhs = try expr(gz, scope, .{ .rl = .ref }, params[0]),
                    .field_name = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .slice_const_u8_type } }, params[1]),
                });
            }
            const result = try gz.addPlNode(.field_val_named, node, Zir.Inst.FieldNamed{
                .lhs = try expr(gz, scope, .{ .rl = .none }, params[0]),
                .field_name = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .slice_const_u8_type } }, params[1]),
            });
            return rvalue(gz, ri, result, node);
        },

        // zig fmt: off
        .as         => return as(       gz, scope, ri, node, params[0], params[1]),
        .bit_cast   => return bitCast(  gz, scope, ri, node, params[0]),
        .TypeOf     => return typeOf(   gz, scope, ri, node, params),
        .union_init => return unionInit(gz, scope, ri, node, params),
        .c_import   => return cImport(  gz, scope,     node, params[0]),
        .min        => return minMax(   gz, scope, ri, node, params, .min),
        .max        => return minMax(   gz, scope, ri, node, params, .max),
        // zig fmt: on

        .@"export" => {
            const node_tags = tree.nodes.items(.tag);
            const node_datas = tree.nodes.items(.data);
            // This function causes a Decl to be exported. The first parameter is not an expression,
            // but an identifier of the Decl to be exported.
            var namespace: Zir.Inst.Ref = .none;
            var decl_name: Zir.NullTerminatedString = .empty;
            switch (node_tags[params[0]]) {
                .identifier => {
                    const ident_token = main_tokens[params[0]];
                    if (isPrimitive(tree.tokenSlice(ident_token))) {
                        return astgen.failTok(ident_token, "unable to export primitive value", .{});
                    }
                    decl_name = try astgen.identAsString(ident_token);

                    var s = scope;
                    var found_already: ?Ast.Node.Index = null; // we have found a decl with the same name already
                    while (true) switch (s.tag) {
                        .local_val => {
                            const local_val = s.cast(Scope.LocalVal).?;
                            if (local_val.name == decl_name) {
                                local_val.used = ident_token;
                                _ = try gz.addPlNode(.export_value, node, Zir.Inst.ExportValue{
                                    .operand = local_val.inst,
                                    .options = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .export_options_type } }, params[1]),
                                });
                                return rvalue(gz, ri, .void_value, node);
                            }
                            s = local_val.parent;
                        },
                        .local_ptr => {
                            const local_ptr = s.cast(Scope.LocalPtr).?;
                            if (local_ptr.name == decl_name) {
                                if (!local_ptr.maybe_comptime)
                                    return astgen.failNode(params[0], "unable to export runtime-known value", .{});
                                local_ptr.used = ident_token;
                                const loaded = try gz.addUnNode(.load, local_ptr.ptr, node);
                                _ = try gz.addPlNode(.export_value, node, Zir.Inst.ExportValue{
                                    .operand = loaded,
                                    .options = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .export_options_type } }, params[1]),
                                });
                                return rvalue(gz, ri, .void_value, node);
                            }
                            s = local_ptr.parent;
                        },
                        .gen_zir => s = s.cast(GenZir).?.parent,
                        .defer_normal, .defer_error => s = s.cast(Scope.Defer).?.parent,
                        .namespace => {
                            const ns = s.cast(Scope.Namespace).?;
                            if (ns.decls.get(decl_name)) |i| {
                                if (found_already) |f| {
                                    return astgen.failNodeNotes(node, "ambiguous reference", .{}, &.{
                                        try astgen.errNoteNode(f, "declared here", .{}),
                                        try astgen.errNoteNode(i, "also declared here", .{}),
                                    });
                                }
                                // We found a match but must continue looking for ambiguous references to decls.
                                found_already = i;
                            }
                            s = ns.parent;
                        },
                        .top => break,
                    };
                    if (found_already == null) {
                        const ident_name = try astgen.identifierTokenString(ident_token);
                        return astgen.failNode(params[0], "use of undeclared identifier '{s}'", .{ident_name});
                    }
                },
                .field_access => {
                    const namespace_node = node_datas[params[0]].lhs;
                    namespace = try typeExpr(gz, scope, namespace_node);
                    const dot_token = main_tokens[params[0]];
                    const field_ident = dot_token + 1;
                    decl_name = try astgen.identAsString(field_ident);
                },
                else => return astgen.failNode(params[0], "symbol to export must identify a declaration", .{}),
            }
            const options = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .export_options_type } }, params[1]);
            _ = try gz.addPlNode(.@"export", node, Zir.Inst.Export{
                .namespace = namespace,
                .decl_name = decl_name,
                .options = options,
            });
            return rvalue(gz, ri, .void_value, node);
        },
        .@"extern" => {
            const type_inst = try typeExpr(gz, scope, params[0]);
            const options = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .extern_options_type } }, params[1]);
            const result = try gz.addExtendedPayload(.builtin_extern, Zir.Inst.BinNode{
                .node = gz.nodeIndexToRelative(node),
                .lhs = type_inst,
                .rhs = options,
            });
            return rvalue(gz, ri, result, node);
        },
        .fence => {
            const order = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .atomic_order_type } }, params[0]);
            _ = try gz.addExtendedPayload(.fence, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = order,
            });
            return rvalue(gz, ri, .void_value, node);
        },
        .set_float_mode => {
            const order = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .float_mode_type } }, params[0]);
            _ = try gz.addExtendedPayload(.set_float_mode, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = order,
            });
            return rvalue(gz, ri, .void_value, node);
        },
        .set_align_stack => {
            const order = try expr(gz, scope, coerced_align_ri, params[0]);
            _ = try gz.addExtendedPayload(.set_align_stack, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = order,
            });
            return rvalue(gz, ri, .void_value, node);
        },
        .set_cold => {
            const order = try expr(gz, scope, ri, params[0]);
            _ = try gz.addExtendedPayload(.set_cold, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = order,
            });
            return rvalue(gz, ri, .void_value, node);
        },

        .src => {
            const token_starts = tree.tokens.items(.start);
            const node_start = token_starts[tree.firstToken(node)];
            astgen.advanceSourceCursor(node_start);
            const result = try gz.addExtendedPayload(.builtin_src, Zir.Inst.Src{
                .node = gz.nodeIndexToRelative(node),
                .line = astgen.source_line,
                .column = astgen.source_column,
            });
            return rvalue(gz, ri, result, node);
        },

        // zig fmt: off
        .This               => return rvalue(gz, ri, try gz.addNodeExtended(.this,               node), node),
        .return_address     => return rvalue(gz, ri, try gz.addNodeExtended(.ret_addr,           node), node),
        .error_return_trace => return rvalue(gz, ri, try gz.addNodeExtended(.error_return_trace, node), node),
        .frame              => return rvalue(gz, ri, try gz.addNodeExtended(.frame,              node), node),
        .frame_address      => return rvalue(gz, ri, try gz.addNodeExtended(.frame_address,      node), node),
        .breakpoint         => return rvalue(gz, ri, try gz.addNodeExtended(.breakpoint,         node), node),
        .in_comptime        => return rvalue(gz, ri, try gz.addNodeExtended(.in_comptime,        node), node),

        .type_info   => return simpleUnOpType(gz, scope, ri, node, params[0], .type_info),
        .size_of     => return simpleUnOpType(gz, scope, ri, node, params[0], .size_of),
        .bit_size_of => return simpleUnOpType(gz, scope, ri, node, params[0], .bit_size_of),
        .align_of    => return simpleUnOpType(gz, scope, ri, node, params[0], .align_of),

        .int_from_ptr          => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .int_from_ptr),
        .compile_error         => return simpleUnOp(gz, scope, ri, node, .{ .rl = .{ .coerced_ty = .slice_const_u8_type } },   params[0], .compile_error),
        .set_eval_branch_quota => return simpleUnOp(gz, scope, ri, node, .{ .rl = .{ .coerced_ty = .u32_type } },              params[0], .set_eval_branch_quota),
        .int_from_enum         => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .int_from_enum),
        .int_from_bool         => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .int_from_bool),
        .embed_file            => return simpleUnOp(gz, scope, ri, node, .{ .rl = .{ .coerced_ty = .slice_const_u8_type } },   params[0], .embed_file),
        .error_name            => return simpleUnOp(gz, scope, ri, node, .{ .rl = .{ .coerced_ty = .anyerror_type } },         params[0], .error_name),
        .set_runtime_safety    => return simpleUnOp(gz, scope, ri, node, coerced_bool_ri,                                      params[0], .set_runtime_safety),
        .sqrt                  => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .sqrt),
        .sin                   => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .sin),
        .cos                   => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .cos),
        .tan                   => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .tan),
        .exp                   => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .exp),
        .exp2                  => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .exp2),
        .log                   => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .log),
        .log2                  => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .log2),
        .log10                 => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .log10),
        .abs                   => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .abs),
        .floor                 => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .floor),
        .ceil                  => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .ceil),
        .trunc                 => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .trunc),
        .round                 => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .round),
        .tag_name              => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .tag_name),
        .type_name             => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .type_name),
        .Frame                 => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .frame_type),
        .frame_size            => return simpleUnOp(gz, scope, ri, node, .{ .rl = .none },                                     params[0], .frame_size),

        .int_from_float => return typeCast(gz, scope, ri, node, params[0], .int_from_float, builtin_name),
        .float_from_int => return typeCast(gz, scope, ri, node, params[0], .float_from_int, builtin_name),
        .ptr_from_int   => return typeCast(gz, scope, ri, node, params[0], .ptr_from_int, builtin_name),
        .enum_from_int  => return typeCast(gz, scope, ri, node, params[0], .enum_from_int, builtin_name),
        .float_cast     => return typeCast(gz, scope, ri, node, params[0], .float_cast, builtin_name),
        .int_cast       => return typeCast(gz, scope, ri, node, params[0], .int_cast, builtin_name),
        .truncate       => return typeCast(gz, scope, ri, node, params[0], .truncate, builtin_name),
        // zig fmt: on

        .Type => {
            const operand = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .type_info_type } }, params[0]);

            const gpa = gz.astgen.gpa;

            try gz.instructions.ensureUnusedCapacity(gpa, 1);
            try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

            const payload_index = try gz.astgen.addExtra(Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = operand,
            });
            const new_index: Zir.Inst.Index = @enumFromInt(gz.astgen.instructions.len);
            gz.astgen.instructions.appendAssumeCapacity(.{
                .tag = .extended,
                .data = .{ .extended = .{
                    .opcode = .reify,
                    .small = @intFromEnum(gz.anon_name_strategy),
                    .operand = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            const result = new_index.toRef();
            return rvalue(gz, ri, result, node);
        },
        .panic => {
            try emitDbgNode(gz, node);
            return simpleUnOp(gz, scope, ri, node, .{ .rl = .{ .coerced_ty = .slice_const_u8_type } }, params[0], .panic);
        },
        .trap => {
            try emitDbgNode(gz, node);
            _ = try gz.addNode(.trap, node);
            return rvalue(gz, ri, .unreachable_value, node);
        },
        .int_from_error => {
            const operand = try expr(gz, scope, .{ .rl = .none }, params[0]);
            const result = try gz.addExtendedPayload(.int_from_error, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = operand,
            });
            return rvalue(gz, ri, result, node);
        },
        .error_from_int => {
            const operand = try expr(gz, scope, .{ .rl = .none }, params[0]);
            const result = try gz.addExtendedPayload(.error_from_int, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = operand,
            });
            return rvalue(gz, ri, result, node);
        },
        .error_cast => {
            try emitDbgNode(gz, node);

            const result = try gz.addExtendedPayload(.error_cast, Zir.Inst.BinNode{
                .lhs = try ri.rl.resultTypeForCast(gz, node, builtin_name),
                .rhs = try expr(gz, scope, .{ .rl = .none }, params[0]),
                .node = gz.nodeIndexToRelative(node),
            });
            return rvalue(gz, ri, result, node);
        },
        .ptr_cast,
        .align_cast,
        .addrspace_cast,
        .const_cast,
        .volatile_cast,
        => return ptrCast(gz, scope, ri, node),

        // zig fmt: off
        .has_decl  => return hasDeclOrField(gz, scope, ri, node, params[0], params[1], .has_decl),
        .has_field => return hasDeclOrField(gz, scope, ri, node, params[0], params[1], .has_field),

        .clz         => return bitBuiltin(gz, scope, ri, node, params[0], .clz),
        .ctz         => return bitBuiltin(gz, scope, ri, node, params[0], .ctz),
        .pop_count   => return bitBuiltin(gz, scope, ri, node, params[0], .pop_count),
        .byte_swap   => return bitBuiltin(gz, scope, ri, node, params[0], .byte_swap),
        .bit_reverse => return bitBuiltin(gz, scope, ri, node, params[0], .bit_reverse),

        .div_exact => return divBuiltin(gz, scope, ri, node, params[0], params[1], .div_exact),
        .div_floor => return divBuiltin(gz, scope, ri, node, params[0], params[1], .div_floor),
        .div_trunc => return divBuiltin(gz, scope, ri, node, params[0], params[1], .div_trunc),
        .mod       => return divBuiltin(gz, scope, ri, node, params[0], params[1], .mod),
        .rem       => return divBuiltin(gz, scope, ri, node, params[0], params[1], .rem),

        .shl_exact => return shiftOp(gz, scope, ri, node, params[0], params[1], .shl_exact),
        .shr_exact => return shiftOp(gz, scope, ri, node, params[0], params[1], .shr_exact),

        .bit_offset_of => return offsetOf(gz, scope, ri, node, params[0], params[1], .bit_offset_of),
        .offset_of     => return offsetOf(gz, scope, ri, node, params[0], params[1], .offset_of),

        .c_undef   => return simpleCBuiltin(gz, scope, ri, node, params[0], .c_undef),
        .c_include => return simpleCBuiltin(gz, scope, ri, node, params[0], .c_include),

        .cmpxchg_strong => return cmpxchg(gz, scope, ri, node, params, 1),
        .cmpxchg_weak   => return cmpxchg(gz, scope, ri, node, params, 0),
        // zig fmt: on

        .wasm_memory_size => {
            const operand = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .u32_type } }, params[0]);
            const result = try gz.addExtendedPayload(.wasm_memory_size, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = operand,
            });
            return rvalue(gz, ri, result, node);
        },
        .wasm_memory_grow => {
            const index_arg = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .u32_type } }, params[0]);
            const delta_arg = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .usize_type } }, params[1]);
            const result = try gz.addExtendedPayload(.wasm_memory_grow, Zir.Inst.BinNode{
                .node = gz.nodeIndexToRelative(node),
                .lhs = index_arg,
                .rhs = delta_arg,
            });
            return rvalue(gz, ri, result, node);
        },
        .c_define => {
            if (!gz.c_import) return gz.astgen.failNode(node, "C define valid only inside C import block", .{});
            const name = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .slice_const_u8_type } }, params[0]);
            const value = try comptimeExpr(gz, scope, .{ .rl = .none }, params[1]);
            const result = try gz.addExtendedPayload(.c_define, Zir.Inst.BinNode{
                .node = gz.nodeIndexToRelative(node),
                .lhs = name,
                .rhs = value,
            });
            return rvalue(gz, ri, result, node);
        },

        .splat => {
            const result_type = try ri.rl.resultTypeForCast(gz, node, builtin_name);
            const elem_type = try gz.addUnNode(.vector_elem_type, result_type, node);
            const scalar = try expr(gz, scope, .{ .rl = .{ .ty = elem_type } }, params[0]);
            const result = try gz.addPlNode(.splat, node, Zir.Inst.Bin{
                .lhs = result_type,
                .rhs = scalar,
            });
            return rvalue(gz, ri, result, node);
        },
        .reduce => {
            const op = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .reduce_op_type } }, params[0]);
            const scalar = try expr(gz, scope, .{ .rl = .none }, params[1]);
            const result = try gz.addPlNode(.reduce, node, Zir.Inst.Bin{
                .lhs = op,
                .rhs = scalar,
            });
            return rvalue(gz, ri, result, node);
        },

        .add_with_overflow => return overflowArithmetic(gz, scope, ri, node, params, .add_with_overflow),
        .sub_with_overflow => return overflowArithmetic(gz, scope, ri, node, params, .sub_with_overflow),
        .mul_with_overflow => return overflowArithmetic(gz, scope, ri, node, params, .mul_with_overflow),
        .shl_with_overflow => return overflowArithmetic(gz, scope, ri, node, params, .shl_with_overflow),

        .atomic_load => {
            const result = try gz.addPlNode(.atomic_load, node, Zir.Inst.AtomicLoad{
                // zig fmt: off
                .elem_type = try typeExpr(gz, scope,                                                   params[0]),
                .ptr       = try expr    (gz, scope, .{ .rl = .none },                                 params[1]),
                .ordering  = try expr    (gz, scope, .{ .rl = .{ .coerced_ty = .atomic_order_type } }, params[2]),
                // zig fmt: on
            });
            return rvalue(gz, ri, result, node);
        },
        .atomic_rmw => {
            const int_type = try typeExpr(gz, scope, params[0]);
            const result = try gz.addPlNode(.atomic_rmw, node, Zir.Inst.AtomicRmw{
                // zig fmt: off
                .ptr       = try expr(gz, scope, .{ .rl = .none },                                  params[1]),
                .operation = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .atomic_rmw_op_type } }, params[2]),
                .operand   = try expr(gz, scope, .{ .rl = .{ .ty = int_type } },                    params[3]),
                .ordering  = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .atomic_order_type } },  params[4]),
                // zig fmt: on
            });
            return rvalue(gz, ri, result, node);
        },
        .atomic_store => {
            const int_type = try typeExpr(gz, scope, params[0]);
            _ = try gz.addPlNode(.atomic_store, node, Zir.Inst.AtomicStore{
                // zig fmt: off
                .ptr      = try expr(gz, scope, .{ .rl = .none },                                 params[1]),
                .operand  = try expr(gz, scope, .{ .rl = .{ .ty = int_type } },                   params[2]),
                .ordering = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .atomic_order_type } }, params[3]),
                // zig fmt: on
            });
            return rvalue(gz, ri, .void_value, node);
        },
        .mul_add => {
            const float_type = try typeExpr(gz, scope, params[0]);
            const mulend1 = try expr(gz, scope, .{ .rl = .{ .coerced_ty = float_type } }, params[1]);
            const mulend2 = try expr(gz, scope, .{ .rl = .{ .coerced_ty = float_type } }, params[2]);
            const addend = try expr(gz, scope, .{ .rl = .{ .ty = float_type } }, params[3]);
            const result = try gz.addPlNode(.mul_add, node, Zir.Inst.MulAdd{
                .mulend1 = mulend1,
                .mulend2 = mulend2,
                .addend = addend,
            });
            return rvalue(gz, ri, result, node);
        },
        .call => {
            const modifier = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .call_modifier_type } }, params[0]);
            const callee = try expr(gz, scope, .{ .rl = .none }, params[1]);
            const args = try expr(gz, scope, .{ .rl = .none }, params[2]);
            const result = try gz.addPlNode(.builtin_call, node, Zir.Inst.BuiltinCall{
                .modifier = modifier,
                .callee = callee,
                .args = args,
                .flags = .{
                    .is_nosuspend = gz.nosuspend_node != 0,
                    .ensure_result_used = false,
                },
            });
            return rvalue(gz, ri, result, node);
        },
        .field_parent_ptr => {
            const parent_ptr_type = try ri.rl.resultTypeForCast(gz, node, builtin_name);
            const field_name = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .slice_const_u8_type } }, params[0]);
            const result = try gz.addExtendedPayloadSmall(.field_parent_ptr, 0, Zir.Inst.FieldParentPtr{
                .src_node = gz.nodeIndexToRelative(node),
                .parent_ptr_type = parent_ptr_type,
                .field_name = field_name,
                .field_ptr = try expr(gz, scope, .{ .rl = .none }, params[1]),
            });
            return rvalue(gz, ri, result, node);
        },
        .memcpy => {
            _ = try gz.addPlNode(.memcpy, node, Zir.Inst.Bin{
                .lhs = try expr(gz, scope, .{ .rl = .none }, params[0]),
                .rhs = try expr(gz, scope, .{ .rl = .none }, params[1]),
            });
            return rvalue(gz, ri, .void_value, node);
        },
        .memset => {
            const lhs = try expr(gz, scope, .{ .rl = .none }, params[0]);
            const lhs_ty = try gz.addUnNode(.typeof, lhs, params[0]);
            const elem_ty = try gz.addUnNode(.indexable_ptr_elem_type, lhs_ty, params[0]);
            _ = try gz.addPlNode(.memset, node, Zir.Inst.Bin{
                .lhs = lhs,
                .rhs = try expr(gz, scope, .{ .rl = .{ .coerced_ty = elem_ty } }, params[1]),
            });
            return rvalue(gz, ri, .void_value, node);
        },
        .shuffle => {
            const result = try gz.addPlNode(.shuffle, node, Zir.Inst.Shuffle{
                .elem_type = try typeExpr(gz, scope, params[0]),
                .a = try expr(gz, scope, .{ .rl = .none }, params[1]),
                .b = try expr(gz, scope, .{ .rl = .none }, params[2]),
                .mask = try comptimeExpr(gz, scope, .{ .rl = .none }, params[3]),
            });
            return rvalue(gz, ri, result, node);
        },
        .select => {
            const result = try gz.addExtendedPayload(.select, Zir.Inst.Select{
                .node = gz.nodeIndexToRelative(node),
                .elem_type = try typeExpr(gz, scope, params[0]),
                .pred = try expr(gz, scope, .{ .rl = .none }, params[1]),
                .a = try expr(gz, scope, .{ .rl = .none }, params[2]),
                .b = try expr(gz, scope, .{ .rl = .none }, params[3]),
            });
            return rvalue(gz, ri, result, node);
        },
        .async_call => {
            const result = try gz.addExtendedPayload(.builtin_async_call, Zir.Inst.AsyncCall{
                .node = gz.nodeIndexToRelative(node),
                .frame_buffer = try expr(gz, scope, .{ .rl = .none }, params[0]),
                .result_ptr = try expr(gz, scope, .{ .rl = .none }, params[1]),
                .fn_ptr = try expr(gz, scope, .{ .rl = .none }, params[2]),
                .args = try expr(gz, scope, .{ .rl = .none }, params[3]),
            });
            return rvalue(gz, ri, result, node);
        },
        .Vector => {
            const result = try gz.addPlNode(.vector_type, node, Zir.Inst.Bin{
                .lhs = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .u32_type } }, params[0]),
                .rhs = try typeExpr(gz, scope, params[1]),
            });
            return rvalue(gz, ri, result, node);
        },
        .prefetch => {
            const ptr = try expr(gz, scope, .{ .rl = .none }, params[0]);
            const options = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .prefetch_options_type } }, params[1]);
            _ = try gz.addExtendedPayload(.prefetch, Zir.Inst.BinNode{
                .node = gz.nodeIndexToRelative(node),
                .lhs = ptr,
                .rhs = options,
            });
            return rvalue(gz, ri, .void_value, node);
        },
        .c_va_arg => {
            const result = try gz.addExtendedPayload(.c_va_arg, Zir.Inst.BinNode{
                .node = gz.nodeIndexToRelative(node),
                .lhs = try expr(gz, scope, .{ .rl = .none }, params[0]),
                .rhs = try typeExpr(gz, scope, params[1]),
            });
            return rvalue(gz, ri, result, node);
        },
        .c_va_copy => {
            const result = try gz.addExtendedPayload(.c_va_copy, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = try expr(gz, scope, .{ .rl = .none }, params[0]),
            });
            return rvalue(gz, ri, result, node);
        },
        .c_va_end => {
            const result = try gz.addExtendedPayload(.c_va_end, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = try expr(gz, scope, .{ .rl = .none }, params[0]),
            });
            return rvalue(gz, ri, result, node);
        },
        .c_va_start => {
            if (!astgen.fn_var_args) {
                return astgen.failNode(node, "'@cVaStart' in a non-variadic function", .{});
            }
            return rvalue(gz, ri, try gz.addNodeExtended(.c_va_start, node), node);
        },

        .work_item_id => {
            const operand = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .u32_type } }, params[0]);
            const result = try gz.addExtendedPayload(.work_item_id, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = operand,
            });
            return rvalue(gz, ri, result, node);
        },
        .work_group_size => {
            const operand = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .u32_type } }, params[0]);
            const result = try gz.addExtendedPayload(.work_group_size, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = operand,
            });
            return rvalue(gz, ri, result, node);
        },
        .work_group_id => {
            const operand = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .u32_type } }, params[0]);
            const result = try gz.addExtendedPayload(.work_group_id, Zir.Inst.UnNode{
                .node = gz.nodeIndexToRelative(node),
                .operand = operand,
            });
            return rvalue(gz, ri, result, node);
        },
    }
}

fn hasDeclOrField(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    lhs_node: Ast.Node.Index,
    rhs_node: Ast.Node.Index,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const container_type = try typeExpr(gz, scope, lhs_node);
    const name = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .slice_const_u8_type } }, rhs_node);
    const result = try gz.addPlNode(tag, node, Zir.Inst.Bin{
        .lhs = container_type,
        .rhs = name,
    });
    return rvalue(gz, ri, result, node);
}

fn typeCast(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    operand_node: Ast.Node.Index,
    tag: Zir.Inst.Tag,
    builtin_name: []const u8,
) InnerError!Zir.Inst.Ref {
    const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);
    const result_type = try ri.rl.resultTypeForCast(gz, node, builtin_name);
    const operand = try expr(gz, scope, .{ .rl = .none }, operand_node);

    try emitDbgStmt(gz, cursor);
    const result = try gz.addPlNode(tag, node, Zir.Inst.Bin{
        .lhs = result_type,
        .rhs = operand,
    });
    return rvalue(gz, ri, result, node);
}

fn simpleUnOpType(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    operand_node: Ast.Node.Index,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const operand = try typeExpr(gz, scope, operand_node);
    const result = try gz.addUnNode(tag, operand, node);
    return rvalue(gz, ri, result, node);
}

fn simpleUnOp(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    operand_ri: ResultInfo,
    operand_node: Ast.Node.Index,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);
    const operand = if (tag == .compile_error)
        try comptimeExpr(gz, scope, operand_ri, operand_node)
    else
        try expr(gz, scope, operand_ri, operand_node);
    switch (tag) {
        .tag_name, .error_name, .int_from_ptr => try emitDbgStmt(gz, cursor),
        else => {},
    }
    const result = try gz.addUnNode(tag, operand, node);
    return rvalue(gz, ri, result, node);
}

fn negation(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const tree = astgen.tree;
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);

    // Check for float literal as the sub-expression because we want to preserve
    // its negativity rather than having it go through comptime subtraction.
    const operand_node = node_datas[node].lhs;
    if (node_tags[operand_node] == .number_literal) {
        return numberLiteral(gz, ri, operand_node, node, .negative);
    }

    const operand = try expr(gz, scope, .{ .rl = .none }, operand_node);
    const result = try gz.addUnNode(.negate, operand, node);
    return rvalue(gz, ri, result, node);
}

fn cmpxchg(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    params: []const Ast.Node.Index,
    small: u16,
) InnerError!Zir.Inst.Ref {
    const int_type = try typeExpr(gz, scope, params[0]);
    const result = try gz.addExtendedPayloadSmall(.cmpxchg, small, Zir.Inst.Cmpxchg{
        // zig fmt: off
        .node           = gz.nodeIndexToRelative(node),
        .ptr            = try expr(gz, scope, .{ .rl = .none },                                 params[1]),
        .expected_value = try expr(gz, scope, .{ .rl = .{ .ty = int_type } },                   params[2]),
        .new_value      = try expr(gz, scope, .{ .rl = .{ .coerced_ty = int_type } },           params[3]),
        .success_order  = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .atomic_order_type } }, params[4]),
        .failure_order  = try expr(gz, scope, .{ .rl = .{ .coerced_ty = .atomic_order_type } }, params[5]),
        // zig fmt: on
    });
    return rvalue(gz, ri, result, node);
}

fn bitBuiltin(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    operand_node: Ast.Node.Index,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const operand = try expr(gz, scope, .{ .rl = .none }, operand_node);
    const result = try gz.addUnNode(tag, operand, node);
    return rvalue(gz, ri, result, node);
}

fn divBuiltin(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    lhs_node: Ast.Node.Index,
    rhs_node: Ast.Node.Index,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);
    const lhs = try expr(gz, scope, .{ .rl = .none }, lhs_node);
    const rhs = try expr(gz, scope, .{ .rl = .none }, rhs_node);

    try emitDbgStmt(gz, cursor);
    const result = try gz.addPlNode(tag, node, Zir.Inst.Bin{ .lhs = lhs, .rhs = rhs });
    return rvalue(gz, ri, result, node);
}

fn simpleCBuiltin(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    operand_node: Ast.Node.Index,
    tag: Zir.Inst.Extended,
) InnerError!Zir.Inst.Ref {
    const name: []const u8 = if (tag == .c_undef) "C undef" else "C include";
    if (!gz.c_import) return gz.astgen.failNode(node, "{s} valid only inside C import block", .{name});
    const operand = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .slice_const_u8_type } }, operand_node);
    _ = try gz.addExtendedPayload(tag, Zir.Inst.UnNode{
        .node = gz.nodeIndexToRelative(node),
        .operand = operand,
    });
    return rvalue(gz, ri, .void_value, node);
}

fn offsetOf(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    lhs_node: Ast.Node.Index,
    rhs_node: Ast.Node.Index,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const type_inst = try typeExpr(gz, scope, lhs_node);
    const field_name = try comptimeExpr(gz, scope, .{ .rl = .{ .coerced_ty = .slice_const_u8_type } }, rhs_node);
    const result = try gz.addPlNode(tag, node, Zir.Inst.Bin{
        .lhs = type_inst,
        .rhs = field_name,
    });
    return rvalue(gz, ri, result, node);
}

fn shiftOp(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    lhs_node: Ast.Node.Index,
    rhs_node: Ast.Node.Index,
    tag: Zir.Inst.Tag,
) InnerError!Zir.Inst.Ref {
    const lhs = try expr(gz, scope, .{ .rl = .none }, lhs_node);

    const cursor = switch (gz.astgen.tree.nodes.items(.tag)[node]) {
        .shl, .shr => maybeAdvanceSourceCursorToMainToken(gz, node),
        else => undefined,
    };

    const log2_int_type = try gz.addUnNode(.typeof_log2_int_type, lhs, lhs_node);
    const rhs = try expr(gz, scope, .{ .rl = .{ .ty = log2_int_type }, .ctx = .shift_op }, rhs_node);

    switch (gz.astgen.tree.nodes.items(.tag)[node]) {
        .shl, .shr => try emitDbgStmt(gz, cursor),
        else => undefined,
    }

    const result = try gz.addPlNode(tag, node, Zir.Inst.Bin{
        .lhs = lhs,
        .rhs = rhs,
    });
    return rvalue(gz, ri, result, node);
}

fn cImport(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
    body_node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;
    const gpa = astgen.gpa;

    if (gz.c_import) return gz.astgen.failNode(node, "cannot nest @cImport", .{});

    var block_scope = gz.makeSubBlock(scope);
    block_scope.is_comptime = true;
    block_scope.c_import = true;
    defer block_scope.unstack();

    const block_inst = try gz.makeBlockInst(.c_import, node);
    const block_result = try fullBodyExpr(&block_scope, &block_scope.base, .{ .rl = .none }, body_node);
    _ = try gz.addUnNode(.ensure_result_used, block_result, node);
    if (!gz.refIsNoReturn(block_result)) {
        _ = try block_scope.addBreak(.break_inline, block_inst, .void_value);
    }
    try block_scope.setBlockBody(block_inst);
    // block_scope unstacked now, can add new instructions to gz
    try gz.instructions.append(gpa, block_inst);

    return block_inst.toRef();
}

fn overflowArithmetic(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    params: []const Ast.Node.Index,
    tag: Zir.Inst.Extended,
) InnerError!Zir.Inst.Ref {
    const lhs = try expr(gz, scope, .{ .rl = .none }, params[0]);
    const rhs = try expr(gz, scope, .{ .rl = .none }, params[1]);
    const result = try gz.addExtendedPayload(tag, Zir.Inst.BinNode{
        .node = gz.nodeIndexToRelative(node),
        .lhs = lhs,
        .rhs = rhs,
    });
    return rvalue(gz, ri, result, node);
}

fn callExpr(
    gz: *GenZir,
    scope: *Scope,
    ri: ResultInfo,
    node: Ast.Node.Index,
    call: Ast.full.Call,
) InnerError!Zir.Inst.Ref {
    const astgen = gz.astgen;

    const callee = try calleeExpr(gz, scope, call.ast.fn_expr);
    const modifier: std.builtin.CallModifier = blk: {
        if (gz.is_comptime) {
            break :blk .compile_time;
        }
        if (call.async_token != null) {
            break :blk .async_kw;
        }
        if (gz.nosuspend_node != 0) {
            break :blk .no_async;
        }
        break :blk .auto;
    };

    {
        astgen.advanceSourceCursor(astgen.tree.tokens.items(.start)[call.ast.lparen]);
        const line = astgen.source_line - gz.decl_line;
        const column = astgen.source_column;
        // Sema expects a dbg_stmt immediately before call,
        try emitDbgStmtForceCurrentIndex(gz, .{ line, column });
    }

    switch (callee) {
        .direct => |obj| assert(obj != .none),
        .field => |field| assert(field.obj_ptr != .none),
    }
    assert(node != 0);

    const call_index: Zir.Inst.Index = @enumFromInt(astgen.instructions.len);
    const call_inst = call_index.toRef();
    try gz.astgen.instructions.append(astgen.gpa, undefined);
    try gz.instructions.append(astgen.gpa, call_index);

    const scratch_top = astgen.scratch.items.len;
    defer astgen.scratch.items.len = scratch_top;

    var scratch_index = scratch_top;
    try astgen.scratch.resize(astgen.gpa, scratch_top + call.ast.params.len);

    for (call.ast.params) |param_node| {
        var arg_block = gz.makeSubBlock(scope);
        defer arg_block.unstack();

        // `call_inst` is reused to provide the param type.
        const arg_ref = try fullBodyExpr(&arg_block, &arg_block.base, .{ .rl = .{ .coerced_ty = call_inst }, .ctx = .fn_arg }, param_node);
        _ = try arg_block.addBreakWithSrcNode(.break_inline, call_index, arg_ref, param_node);

        const body = arg_block.instructionsSlice();
        try astgen.scratch.ensureUnusedCapacity(astgen.gpa, countBodyLenAfterFixups(astgen, body));
        appendBodyWithFixupsArrayList(astgen, &astgen.scratch, body);

        astgen.scratch.items[scratch_index] = @intCast(astgen.scratch.items.len - scratch_top);
        scratch_index += 1;
    }

    // If our result location is a try/catch/error-union-if/return, a function argument,
    // or an initializer for a `const` variable, the error trace propagates.
    // Otherwise, it should always be popped (handled in Sema).
    const propagate_error_trace = switch (ri.ctx) {
        .error_handling_expr, .@"return", .fn_arg, .const_init => true,
        else => false,
    };

    switch (callee) {
        .direct => |callee_obj| {
            const payload_index = try addExtra(astgen, Zir.Inst.Call{
                .callee = callee_obj,
                .flags = .{
                    .pop_error_return_trace = !propagate_error_trace,
                    .packed_modifier = @intCast(@intFromEnum(modifier)),
                    .args_len = @intCast(call.ast.params.len),
                },
            });
            if (call.ast.params.len != 0) {
                try astgen.extra.appendSlice(astgen.gpa, astgen.scratch.items[scratch_top..]);
            }
            gz.astgen.instructions.set(@intFromEnum(call_index), .{
                .tag = .call,
                .data = .{ .pl_node = .{
                    .src_node = gz.nodeIndexToRelative(node),
                    .payload_index = payload_index,
                } },
            });
        },
        .field => |callee_field| {
            const payload_index = try addExtra(astgen, Zir.Inst.FieldCall{
                .obj_ptr = callee_field.obj_ptr,
                .field_name_start = callee_field.field_name_start,
                .flags = .{
                    .pop_error_return_trace = !propagate_error_trace,
                    .packed_modifier = @intCast(@intFromEnum(modifier)),
                    .args_len = @intCast(call.ast.params.len),
                },
            });
            if (call.ast.params.len != 0) {
                try astgen.extra.appendSlice(astgen.gpa, astgen.scratch.items[scratch_top..]);
            }
            gz.astgen.instructions.set(@intFromEnum(call_index), .{
                .tag = .field_call,
                .data = .{ .pl_node = .{
                    .src_node = gz.nodeIndexToRelative(node),
                    .payload_index = payload_index,
                } },
            });
        },
    }
    return rvalue(gz, ri, call_inst, node); // TODO function call with result location
}

const Callee = union(enum) {
    field: struct {
        /// A *pointer* to the object the field is fetched on, so that we can
        /// promote the lvalue to an address if the first parameter requires it.
        obj_ptr: Zir.Inst.Ref,
        /// Offset into `string_bytes`.
        field_name_start: Zir.NullTerminatedString,
    },
    direct: Zir.Inst.Ref,
};

/// calleeExpr generates the function part of a call expression (f in f(x)), but
/// *not* the callee argument to the @call() builtin. Its purpose is to
/// distinguish between standard calls and method call syntax `a.b()`. Thus, if
/// the lhs is a field access, we return using the `field` union field;
/// otherwise, we use the `direct` union field.
fn calleeExpr(
    gz: *GenZir,
    scope: *Scope,
    node: Ast.Node.Index,
) InnerError!Callee {
    const astgen = gz.astgen;
    const tree = astgen.tree;

    const tag = tree.nodes.items(.tag)[node];
    switch (tag) {
        .field_access => {
            const main_tokens = tree.nodes.items(.main_token);
            const node_datas = tree.nodes.items(.data);
            const object_node = node_datas[node].lhs;
            const dot_token = main_tokens[node];
            const field_ident = dot_token + 1;
            const str_index = try astgen.identAsString(field_ident);
            // Capture the object by reference so we can promote it to an
            // address in Sema if needed.
            const lhs = try expr(gz, scope, .{ .rl = .ref }, object_node);

            const cursor = maybeAdvanceSourceCursorToMainToken(gz, node);
            try emitDbgStmt(gz, cursor);

            return .{ .field = .{
                .obj_ptr = lhs,
                .field_name_start = str_index,
            } };
        },
        else => return .{ .direct = try expr(gz, scope, .{ .rl = .none }, node) },
    }
}

const primitive_instrs = std.StaticStringMap(Zir.Inst.Ref).initComptime(.{
    .{ "anyerror", .anyerror_type },
    .{ "anyframe", .anyframe_type },
    .{ "anyopaque", .anyopaque_type },
    .{ "bool", .bool_type },
    .{ "c_int", .c_int_type },
    .{ "c_long", .c_long_type },
    .{ "c_longdouble", .c_longdouble_type },
    .{ "c_longlong", .c_longlong_type },
    .{ "c_char", .c_char_type },
    .{ "c_short", .c_short_type },
    .{ "c_uint", .c_uint_type },
    .{ "c_ulong", .c_ulong_type },
    .{ "c_ulonglong", .c_ulonglong_type },
    .{ "c_ushort", .c_ushort_type },
    .{ "comptime_float", .comptime_float_type },
    .{ "comptime_int", .comptime_int_type },
    .{ "f128", .f128_type },
    .{ "f16", .f16_type },
    .{ "f32", .f32_type },
    .{ "f64", .f64_type },
    .{ "f80", .f80_type },
    .{ "false", .bool_false },
    .{ "i16", .i16_type },
    .{ "i32", .i32_type },
    .{ "i64", .i64_type },
    .{ "i128", .i128_type },
    .{ "i8", .i8_type },
    .{ "isize", .isize_type },
    .{ "noreturn", .noreturn_type },
    .{ "null", .null_value },
    .{ "true", .bool_true },
    .{ "type", .type_type },
    .{ "u16", .u16_type },
    .{ "u29", .u29_type },
    .{ "u32", .u32_type },
    .{ "u64", .u64_type },
    .{ "u128", .u128_type },
    .{ "u1", .u1_type },
    .{ "u8", .u8_type },
    .{ "undefined", .undef },
    .{ "usize", .usize_type },
    .{ "void", .void_type },
});

comptime {
    // These checks ensure that std.zig.primitives stays in sync with the primitive->Zir map.
    const primitives = std.zig.primitives;
    for (primitive_instrs.keys(), primitive_instrs.values()) |key, value| {
        if (!primitives.isPrimitive(key)) {
            @compileError("std.zig.isPrimitive() is not aware of Zir instr '" ++ @tagName(value) ++ "'");
        }
    }
    for (primitives.names.keys()) |key| {
        if (primitive_instrs.get(key) == null) {
            @compileError("std.zig.primitives entry '" ++ key ++ "' does not have a corresponding Zir instr");
        }
    }
}

fn nodeIsTriviallyZero(tree: *const Ast, node: Ast.Node.Index) bool {
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);

    switch (node_tags[node]) {
        .number_literal => {
            const ident = main_tokens[node];
            return switch (std.zig.parseNumberLiteral(tree.tokenSlice(ident))) {
                .int => |number| switch (number) {
                    0 => true,
                    else => false,
                },
                else => false,
            };
        },
        else => return false,
    }
}

fn nodeMayAppendToErrorTrace(tree: *const Ast, start_node: Ast.Node.Index) bool {
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);

    var node = start_node;
    while (true) {
        switch (node_tags[node]) {
            // These don't have the opportunity to call any runtime functions.
            .error_value,
            .identifier,
            .@"comptime",
            => return false,

            // Forward the question to the LHS sub-expression.
            .grouped_expression,
            .@"try",
            .@"nosuspend",
            .unwrap_optional,
            => node = node_datas[node].lhs,

            // Anything that does not eval to an error is guaranteed to pop any
            // additions to the error trace, so it effectively does not append.
            else => return nodeMayEvalToError(tree, start_node) != .never,
        }
    }
}

fn nodeMayEvalToError(tree: *const Ast, start_node: Ast.Node.Index) BuiltinFn.EvalToError {
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
            .switch_case_inline,
            .switch_case_one,
            .switch_case_inline_one,
            .container_field_init,
            .container_field_align,
            .container_field,
            .asm_output,
            .asm_input,
            => unreachable,

            .error_value => return .always,

            .@"asm",
            .asm_simple,
            .identifier,
            .field_access,
            .deref,
            .array_access,
            .while_simple,
            .while_cont,
            .for_simple,
            .if_simple,
            .@"while",
            .@"if",
            .@"for",
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
            => return .maybe,

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
            .fn_proto_simple,
            .fn_proto_multi,
            .fn_proto_one,
            .fn_proto,
            .fn_decl,
            .anyframe_type,
            .anyframe_literal,
            .number_literal,
            .enum_literal,
            .string_literal,
            .multiline_string_literal,
            .char_literal,
            .unreachable_literal,
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
            .add,
            .add_wrap,
            .add_sat,
            .array_cat,
            .array_mult,
            .assign,
            .assign_destructure,
            .assign_bit_and,
            .assign_bit_or,
            .assign_shl,
            .assign_shl_sat,
            .assign_shr,
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
            .bang_equal,
            .bit_and,
            .bit_or,
            .shl,
            .shl_sat,
            .shr,
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
            .mul_sat,
            .switch_range,
            .for_range,
            .sub,
            .sub_wrap,
            .sub_sat,
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
            => return .never,

            // Forward the question to the LHS sub-expression.
            .grouped_expression,
            .@"try",
            .@"await",
            .@"comptime",
            .@"nosuspend",
            .unwrap_optional,
            => node = node_datas[node].lhs,

            // LHS sub-expression may still be an error under the outer optional or error union
            .@"catch",
            .@"orelse",
            => return .maybe,

            .block_two,
            .block_two_semicolon,
            .block,
            .block_semicolon,
            => {
                const lbrace = main_tokens[node];
                if (token_tags[lbrace - 1] == .colon) {
                    // Labeled blocks may need a memory location to forward
                    // to their break statements.
                    return .maybe;
                } else {
                    return .never;
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
                const builtin_info = BuiltinFn.list.get(builtin_name) orelse return .maybe;
                return builtin_info.eval_to_error;
            },
        }
    }
}

/// Returns `true` if it is known the type expression has more than one possible value;
/// `false` otherwise.
fn nodeImpliesMoreThanOnePossibleValue(tree: *const Ast, start_node: Ast.Node.Index) bool {
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);

    var node = start_node;
    while (true) {
        switch (node_tags[node]) {
            .root,
            .@"usingnamespace",
            .test_decl,
            .switch_case,
            .switch_case_inline,
            .switch_case_one,
            .switch_case_inline_one,
            .container_field_init,
            .container_field_align,
            .container_field,
            .asm_output,
            .asm_input,
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => unreachable,

            .@"return",
            .@"break",
            .@"continue",
            .bit_not,
            .bool_not,
            .@"defer",
            .@"errdefer",
            .address_of,
            .negation,
            .negation_wrap,
            .@"resume",
            .array_type,
            .@"suspend",
            .fn_decl,
            .anyframe_literal,
            .number_literal,
            .enum_literal,
            .string_literal,
            .multiline_string_literal,
            .char_literal,
            .unreachable_literal,
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
            .add_sat,
            .array_cat,
            .array_mult,
            .assign,
            .assign_destructure,
            .assign_bit_and,
            .assign_bit_or,
            .assign_shl,
            .assign_shl_sat,
            .assign_shr,
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
            .bang_equal,
            .bit_and,
            .bit_or,
            .shl,
            .shl_sat,
            .shr,
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
            .mul_sat,
            .switch_range,
            .for_range,
            .field_access,
            .sub,
            .sub_wrap,
            .sub_sat,
            .slice,
            .slice_open,
            .slice_sentinel,
            .deref,
            .array_access,
            .error_value,
            .while_simple,
            .while_cont,
            .for_simple,
            .if_simple,
            .@"catch",
            .@"orelse",
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
            .@"while",
            .@"if",
            .@"for",
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
            .block_two,
            .block_two_semicolon,
            .block,
            .block_semicolon,
            .builtin_call,
            .builtin_call_comma,
            .builtin_call_two,
            .builtin_call_two_comma,
            // these are function bodies, not pointers
            .fn_proto_simple,
            .fn_proto_multi,
            .fn_proto_one,
            .fn_proto,
            => return false,

            // Forward the question to the LHS sub-expression.
            .grouped_expression,
            .@"try",
            .@"await",
            .@"comptime",
            .@"nosuspend",
            .unwrap_optional,
            => node = node_datas[node].lhs,

            .ptr_type_aligned,
            .ptr_type_sentinel,
            .ptr_type,
            .ptr_type_bit_range,
            .optional_type,
            .anyframe_type,
            .array_type_sentinel,
            => return true,

            .identifier => {
                const main_tokens = tree.nodes.items(.main_token);
                const ident_bytes = tree.tokenSlice(main_tokens[node]);
                if (primitive_instrs.get(ident_bytes)) |primitive| switch (primitive) {
                    .anyerror_type,
                    .anyframe_type,
                    .anyopaque_type,
                    .bool_type,
                    .c_int_type,
                    .c_long_type,
                    .c_longdouble_type,
                    .c_longlong_type,
                    .c_char_type,
                    .c_short_type,
                    .c_uint_type,
                    .c_ulong_type,
                    .c_ulonglong_type,
                    .c_ushort_type,
                    .comptime_float_type,
                    .comptime_int_type,
                    .f16_type,
                    .f32_type,
                    .f64_type,
                    .f80_type,
                    .f128_type,
                    .i16_type,
                    .i32_type,
                    .i64_type,
                    .i128_type,
                    .i8_type,
                    .isize_type,
                    .type_type,
                    .u16_type,
                    .u29_type,
                    .u32_type,
                    .u64_type,
                    .u128_type,
                    .u1_type,
                    .u8_type,
                    .usize_type,
                    => return true,

                    .void_type,
                    .bool_false,
                    .bool_true,
                    .null_value,
                    .undef,
                    .noreturn_type,
                    => return false,

                    else => unreachable, // that's all the values from `primitives`.
                } else {
                    return false;
                }
            },
        }
    }
}

/// Returns `true` if it is known the expression is a type that cannot be used at runtime;
/// `false` otherwise.
fn nodeImpliesComptimeOnly(tree: *const Ast, start_node: Ast.Node.Index) bool {
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);

    var node = start_node;
    while (true) {
        switch (node_tags[node]) {
            .root,
            .@"usingnamespace",
            .test_decl,
            .switch_case,
            .switch_case_inline,
            .switch_case_one,
            .switch_case_inline_one,
            .container_field_init,
            .container_field_align,
            .container_field,
            .asm_output,
            .asm_input,
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => unreachable,

            .@"return",
            .@"break",
            .@"continue",
            .bit_not,
            .bool_not,
            .@"defer",
            .@"errdefer",
            .address_of,
            .negation,
            .negation_wrap,
            .@"resume",
            .array_type,
            .@"suspend",
            .fn_decl,
            .anyframe_literal,
            .number_literal,
            .enum_literal,
            .string_literal,
            .multiline_string_literal,
            .char_literal,
            .unreachable_literal,
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
            .add_sat,
            .array_cat,
            .array_mult,
            .assign,
            .assign_destructure,
            .assign_bit_and,
            .assign_bit_or,
            .assign_shl,
            .assign_shl_sat,
            .assign_shr,
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
            .bang_equal,
            .bit_and,
            .bit_or,
            .shl,
            .shl_sat,
            .shr,
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
            .mul_sat,
            .switch_range,
            .for_range,
            .field_access,
            .sub,
            .sub_wrap,
            .sub_sat,
            .slice,
            .slice_open,
            .slice_sentinel,
            .deref,
            .array_access,
            .error_value,
            .while_simple,
            .while_cont,
            .for_simple,
            .if_simple,
            .@"catch",
            .@"orelse",
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
            .@"while",
            .@"if",
            .@"for",
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
            .block_two,
            .block_two_semicolon,
            .block,
            .block_semicolon,
            .builtin_call,
            .builtin_call_comma,
            .builtin_call_two,
            .builtin_call_two_comma,
            .ptr_type_aligned,
            .ptr_type_sentinel,
            .ptr_type,
            .ptr_type_bit_range,
            .optional_type,
            .anyframe_type,
            .array_type_sentinel,
            => return false,

            // these are function bodies, not pointers
            .fn_proto_simple,
            .fn_proto_multi,
            .fn_proto_one,
            .fn_proto,
            => return true,

            // Forward the question to the LHS sub-expression.
            .grouped_expression,
            .@"try",
            .@"await",
            .@"comptime",
            .@"nosuspend",
            .unwrap_optional,
            => node = node_datas[node].lhs,

            .identifier => {
                const main_tokens = tree.nodes.items(.main_token);
                const ident_bytes = tree.tokenSlice(main_tokens[node]);
                if (primitive_instrs.get(ident_bytes)) |primitive| switch (primitive) {
                    .anyerror_type,
                    .anyframe_type,
                    .anyopaque_type,
                    .bool_type,
                    .c_int_type,
                    .c_long_type,
                    .c_longdouble_type,
                    .c_longlong_type,
                    .c_char_type,
                    .c_short_type,
                    .c_uint_type,
                    .c_ulong_type,
                    .c_ulonglong_type,
                    .c_ushort_type,
                    .f16_type,
                    .f32_type,
                    .f64_type,
                    .f80_type,
                    .f128_type,
                    .i16_type,
                    .i32_type,
                    .i64_type,
                    .i128_type,
                    .i8_type,
                    .isize_type,
                    .u16_type,
                    .u29_type,
                    .u32_type,
                    .u64_type,
                    .u128_type,
                    .u1_type,
                    .u8_type,
                    .usize_type,
                    .void_type,
                    .bool_false,
                    .bool_true,
                    .null_value,
                    .undef,
                    .noreturn_type,
                    => return false,

                    .comptime_float_type,
                    .comptime_int_type,
                    .type_type,
                    => return true,

                    else => unreachable, // that's all the values from `primitives`.
                } else {
                    return false;
                }
            },
        }
    }
}

/// Returns `true` if the node uses `gz.anon_name_strategy`.
fn nodeUsesAnonNameStrategy(tree: *const Ast, node: Ast.Node.Index) bool {
    const node_tags = tree.nodes.items(.tag);
    switch (node_tags[node]) {
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
        => return true,
        .builtin_call_two, .builtin_call_two_comma, .builtin_call, .builtin_call_comma => {
            const builtin_token = tree.nodes.items(.main_token)[node];
            const builtin_name = tree.tokenSlice(builtin_token);
            return std.mem.eql(u8, builtin_name, "@Type");
        },
        else => return false,
    }
}

/// Applies `rl` semantics to `result`. Expressions which do not do their own handling of
/// result locations must call this function on their result.
/// As an example, if `ri.rl` is `.ptr`, it will write the result to the pointer.
/// If `ri.rl` is `.ty`, it will coerce the result to the type.
/// Assumes nothing stacked on `gz`.
fn rvalue(
    gz: *GenZir,
    ri: ResultInfo,
    raw_result: Zir.Inst.Ref,
    src_node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    return rvalueInner(gz, ri, raw_result, src_node, true);
}

/// Like `rvalue`, but refuses to perform coercions before taking references for
/// the `ref_coerced_ty` result type. This is used for local variables which do
/// not have `alloc`s, because we want variables to have consistent addresses,
/// i.e. we want them to act like lvalues.
fn rvalueNoCoercePreRef(
    gz: *GenZir,
    ri: ResultInfo,
    raw_result: Zir.Inst.Ref,
    src_node: Ast.Node.Index,
) InnerError!Zir.Inst.Ref {
    return rvalueInner(gz, ri, raw_result, src_node, false);
}

fn rvalueInner(
    gz: *GenZir,
    ri: ResultInfo,
    raw_result: Zir.Inst.Ref,
    src_node: Ast.Node.Index,
    allow_coerce_pre_ref: bool,
) InnerError!Zir.Inst.Ref {
    const result = r: {
        if (raw_result.toIndex()) |result_index| {
            const zir_tags = gz.astgen.instructions.items(.tag);
            const data = gz.astgen.instructions.items(.data)[@intFromEnum(result_index)];
            if (zir_tags[@intFromEnum(result_index)].isAlwaysVoid(data)) {
                break :r Zir.Inst.Ref.void_value;
            }
        }
        break :r raw_result;
    };
    if (gz.endsWithNoReturn()) return result;
    switch (ri.rl) {
        .none, .coerced_ty => return result,
        .discard => {
            // Emit a compile error for discarding error values.
            _ = try gz.addUnNode(.ensure_result_non_error, result, src_node);
            return .void_value;
        },
        .ref, .ref_coerced_ty => {
            const coerced_result = if (allow_coerce_pre_ref and ri.rl == .ref_coerced_ty) res: {
                const ptr_ty = ri.rl.ref_coerced_ty;
                break :res try gz.addPlNode(.coerce_ptr_elem_ty, src_node, Zir.Inst.Bin{
                    .lhs = ptr_ty,
                    .rhs = result,
                });
            } else result;
            // We need a pointer but we have a value.
            // Unfortunately it's not quite as simple as directly emitting a ref
            // instruction here because we need subsequent address-of operator on
            // const locals to return the same address.
            const astgen = gz.astgen;
            const tree = astgen.tree;
            const src_token = tree.firstToken(src_node);
            const result_index = coerced_result.toIndex() orelse
                return gz.addUnTok(.ref, coerced_result, src_token);
            const zir_tags = gz.astgen.instructions.items(.tag);
            if (zir_tags[@intFromEnum(result_index)].isParam() or astgen.isInferred(coerced_result))
                return gz.addUnTok(.ref, coerced_result, src_token);
            const gop = try astgen.ref_table.getOrPut(astgen.gpa, result_index);
            if (!gop.found_existing) {
                gop.value_ptr.* = try gz.makeUnTok(.ref, coerced_result, src_token);
            }
            return gop.value_ptr.*.toRef();
        },
        .ty => |ty_inst| {
            // Quickly eliminate some common, unnecessary type coercion.
            const as_ty = @as(u64, @intFromEnum(Zir.Inst.Ref.type_type)) << 32;
            const as_bool = @as(u64, @intFromEnum(Zir.Inst.Ref.bool_type)) << 32;
            const as_void = @as(u64, @intFromEnum(Zir.Inst.Ref.void_type)) << 32;
            const as_comptime_int = @as(u64, @intFromEnum(Zir.Inst.Ref.comptime_int_type)) << 32;
            const as_usize = @as(u64, @intFromEnum(Zir.Inst.Ref.usize_type)) << 32;
            const as_u8 = @as(u64, @intFromEnum(Zir.Inst.Ref.u8_type)) << 32;
            switch ((@as(u64, @intFromEnum(ty_inst)) << 32) | @as(u64, @intFromEnum(result))) {
                as_ty | @intFromEnum(Zir.Inst.Ref.u1_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.u8_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.i8_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.u16_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.u29_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.i16_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.u32_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.i32_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.u64_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.i64_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.u128_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.i128_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.usize_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.isize_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.c_char_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.c_short_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.c_ushort_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.c_int_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.c_uint_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.c_long_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.c_ulong_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.c_longlong_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.c_ulonglong_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.c_longdouble_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.f16_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.f32_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.f64_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.f80_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.f128_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.anyopaque_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.bool_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.void_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.type_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.anyerror_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.comptime_int_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.comptime_float_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.noreturn_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.anyframe_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.null_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.undefined_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.enum_literal_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.atomic_order_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.atomic_rmw_op_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.calling_convention_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.address_space_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.float_mode_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.reduce_op_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.call_modifier_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.prefetch_options_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.export_options_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.extern_options_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.type_info_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.manyptr_u8_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.manyptr_const_u8_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.manyptr_const_u8_sentinel_0_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.single_const_pointer_to_comptime_int_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.slice_const_u8_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.slice_const_u8_sentinel_0_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.anyerror_void_error_union_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.generic_poison_type),
                as_ty | @intFromEnum(Zir.Inst.Ref.empty_struct_type),
                as_comptime_int | @intFromEnum(Zir.Inst.Ref.zero),
                as_comptime_int | @intFromEnum(Zir.Inst.Ref.one),
                as_comptime_int | @intFromEnum(Zir.Inst.Ref.negative_one),
                as_usize | @intFromEnum(Zir.Inst.Ref.zero_usize),
                as_usize | @intFromEnum(Zir.Inst.Ref.one_usize),
                as_u8 | @intFromEnum(Zir.Inst.Ref.zero_u8),
                as_u8 | @intFromEnum(Zir.Inst.Ref.one_u8),
                as_u8 | @intFromEnum(Zir.Inst.Ref.four_u8),
                as_bool | @intFromEnum(Zir.Inst.Ref.bool_true),
                as_bool | @intFromEnum(Zir.Inst.Ref.bool_false),
                as_void | @intFromEnum(Zir.Inst.Ref.void_value),
                => return result, // type of result is already correct

                as_usize | @intFromEnum(Zir.Inst.Ref.zero) => return .zero_usize,
                as_u8 | @intFromEnum(Zir.Inst.Ref.zero) => return .zero_u8,
                as_usize | @intFromEnum(Zir.Inst.Ref.one) => return .one_usize,
                as_u8 | @intFromEnum(Zir.Inst.Ref.one) => return .one_u8,
                as_comptime_int | @intFromEnum(Zir.Inst.Ref.zero_usize) => return .zero,
                as_u8 | @intFromEnum(Zir.Inst.Ref.zero_usize) => return .zero_u8,
                as_comptime_int | @intFromEnum(Zir.Inst.Ref.one_usize) => return .one,
                as_u8 | @intFromEnum(Zir.Inst.Ref.one_usize) => return .one_u8,
                as_comptime_int | @intFromEnum(Zir.Inst.Ref.zero_u8) => return .zero,
                as_usize | @intFromEnum(Zir.Inst.Ref.zero_u8) => return .zero_usize,
                as_comptime_int | @intFromEnum(Zir.Inst.Ref.one_u8) => return .one,
                as_usize | @intFromEnum(Zir.Inst.Ref.one_u8) => return .one_usize,

                // Need an explicit type coercion instruction.
                else => return gz.addPlNode(ri.zirTag(), src_node, Zir.Inst.As{
                    .dest_type = ty_inst,
                    .operand = result,
                }),
            }
        },
        .ptr => |ptr_res| {
            _ = try gz.addPlNode(.store_node, ptr_res.src_node orelse src_node, Zir.Inst.Bin{
                .lhs = ptr_res.inst,
                .rhs = result,
            });
            return .void_value;
        },
        .inferred_ptr => |alloc| {
            _ = try gz.addPlNode(.store_to_inferred_ptr, src_node, Zir.Inst.Bin{
                .lhs = alloc,
                .rhs = result,
            });
            return .void_value;
        },
        .destructure => |destructure| {
            const components = destructure.components;
            _ = try gz.addPlNode(.validate_destructure, src_node, Zir.Inst.ValidateDestructure{
                .operand = result,
                .destructure_node = gz.nodeIndexToRelative(destructure.src_node),
                .expect_len = @intCast(components.len),
            });
            for (components, 0..) |component, i| {
                if (component == .discard) continue;
                const elem_val = try gz.add(.{
                    .tag = .elem_val_imm,
                    .data = .{ .elem_val_imm = .{
                        .operand = result,
                        .idx = @intCast(i),
                    } },
                });
                switch (component) {
                    .typed_ptr => |ptr_res| {
                        _ = try gz.addPlNode(.store_node, ptr_res.src_node orelse src_node, Zir.Inst.Bin{
                            .lhs = ptr_res.inst,
                            .rhs = elem_val,
                        });
                    },
                    .inferred_ptr => |ptr_inst| {
                        _ = try gz.addPlNode(.store_to_inferred_ptr, src_node, Zir.Inst.Bin{
                            .lhs = ptr_inst,
                            .rhs = elem_val,
                        });
                    },
                    .discard => unreachable,
                }
            }
            return .void_value;
        },
    }
}

/// Given an identifier token, obtain the string for it.
/// If the token uses @"" syntax, parses as a string, reports errors if applicable,
/// and allocates the result within `astgen.arena`.
/// Otherwise, returns a reference to the source code bytes directly.
/// See also `appendIdentStr` and `parseStrLit`.
fn identifierTokenString(astgen: *AstGen, token: Ast.TokenIndex) InnerError![]const u8 {
    const tree = astgen.tree;
    const token_tags = tree.tokens.items(.tag);
    assert(token_tags[token] == .identifier);
    const ident_name = tree.tokenSlice(token);
    if (!mem.startsWith(u8, ident_name, "@")) {
        return ident_name;
    }
    var buf: ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(astgen.gpa);
    try astgen.parseStrLit(token, &buf, ident_name, 1);
    if (mem.indexOfScalar(u8, buf.items, 0) != null) {
        return astgen.failTok(token, "identifier cannot contain null bytes", .{});
    } else if (buf.items.len == 0) {
        return astgen.failTok(token, "identifier cannot be empty", .{});
    }
    const duped = try astgen.arena.dupe(u8, buf.items);
    return duped;
}

/// Given an identifier token, obtain the string for it (possibly parsing as a string
/// literal if it is @"" syntax), and append the string to `buf`.
/// See also `identifierTokenString` and `parseStrLit`.
fn appendIdentStr(
    astgen: *AstGen,
    token: Ast.TokenIndex,
    buf: *ArrayListUnmanaged(u8),
) InnerError!void {
    const tree = astgen.tree;
    const token_tags = tree.tokens.items(.tag);
    assert(token_tags[token] == .identifier);
    const ident_name = tree.tokenSlice(token);
    if (!mem.startsWith(u8, ident_name, "@")) {
        return buf.appendSlice(astgen.gpa, ident_name);
    } else {
        const start = buf.items.len;
        try astgen.parseStrLit(token, buf, ident_name, 1);
        const slice = buf.items[start..];
        if (mem.indexOfScalar(u8, slice, 0) != null) {
            return astgen.failTok(token, "identifier cannot contain null bytes", .{});
        } else if (slice.len == 0) {
            return astgen.failTok(token, "identifier cannot be empty", .{});
        }
    }
}

/// Appends the result to `buf`.
fn parseStrLit(
    astgen: *AstGen,
    token: Ast.TokenIndex,
    buf: *ArrayListUnmanaged(u8),
    bytes: []const u8,
    offset: u32,
) InnerError!void {
    const raw_string = bytes[offset..];
    var buf_managed = buf.toManaged(astgen.gpa);
    const result = std.zig.string_literal.parseWrite(buf_managed.writer(), raw_string);
    buf.* = buf_managed.moveToUnmanaged();
    switch (try result) {
        .success => return,
        .failure => |err| return astgen.failWithStrLitError(err, token, bytes, offset),
    }
}

fn failWithStrLitError(astgen: *AstGen, err: std.zig.string_literal.Error, token: Ast.TokenIndex, bytes: []const u8, offset: u32) InnerError {
    const raw_string = bytes[offset..];
    switch (err) {
        .invalid_escape_character => |bad_index| {
            return astgen.failOff(
                token,
                offset + @as(u32, @intCast(bad_index)),
                "invalid escape character: '{c}'",
                .{raw_string[bad_index]},
            );
        },
        .expected_hex_digit => |bad_index| {
            return astgen.failOff(
                token,
                offset + @as(u32, @intCast(bad_index)),
                "expected hex digit, found '{c}'",
                .{raw_string[bad_index]},
            );
        },
        .empty_unicode_escape_sequence => |bad_index| {
            return astgen.failOff(
                token,
                offset + @as(u32, @intCast(bad_index)),
                "empty unicode escape sequence",
                .{},
            );
        },
        .expected_hex_digit_or_rbrace => |bad_index| {
            return astgen.failOff(
                token,
                offset + @as(u32, @intCast(bad_index)),
                "expected hex digit or '}}', found '{c}'",
                .{raw_string[bad_index]},
            );
        },
        .invalid_unicode_codepoint => |bad_index| {
            return astgen.failOff(
                token,
                offset + @as(u32, @intCast(bad_index)),
                "unicode escape does not correspond to a valid codepoint",
                .{},
            );
        },
        .expected_lbrace => |bad_index| {
            return astgen.failOff(
                token,
                offset + @as(u32, @intCast(bad_index)),
                "expected '{{', found '{c}",
                .{raw_string[bad_index]},
            );
        },
        .expected_rbrace => |bad_index| {
            return astgen.failOff(
                token,
                offset + @as(u32, @intCast(bad_index)),
                "expected '}}', found '{c}",
                .{raw_string[bad_index]},
            );
        },
        .expected_single_quote => |bad_index| {
            return astgen.failOff(
                token,
                offset + @as(u32, @intCast(bad_index)),
                "expected single quote ('), found '{c}",
                .{raw_string[bad_index]},
            );
        },
        .invalid_character => |bad_index| {
            return astgen.failOff(
                token,
                offset + @as(u32, @intCast(bad_index)),
                "invalid byte in string or character literal: '{c}'",
                .{raw_string[bad_index]},
            );
        },
    }
}

fn failNode(
    astgen: *AstGen,
    node: Ast.Node.Index,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    return astgen.failNodeNotes(node, format, args, &[0]u32{});
}

fn appendErrorNode(
    astgen: *AstGen,
    node: Ast.Node.Index,
    comptime format: []const u8,
    args: anytype,
) Allocator.Error!void {
    try astgen.appendErrorNodeNotes(node, format, args, &[0]u32{});
}

fn appendErrorNodeNotes(
    astgen: *AstGen,
    node: Ast.Node.Index,
    comptime format: []const u8,
    args: anytype,
    notes: []const u32,
) Allocator.Error!void {
    @setCold(true);
    const string_bytes = &astgen.string_bytes;
    const msg: Zir.NullTerminatedString = @enumFromInt(string_bytes.items.len);
    try string_bytes.writer(astgen.gpa).print(format ++ "\x00", args);
    const notes_index: u32 = if (notes.len != 0) blk: {
        const notes_start = astgen.extra.items.len;
        try astgen.extra.ensureTotalCapacity(astgen.gpa, notes_start + 1 + notes.len);
        astgen.extra.appendAssumeCapacity(@intCast(notes.len));
        astgen.extra.appendSliceAssumeCapacity(notes);
        break :blk @intCast(notes_start);
    } else 0;
    try astgen.compile_errors.append(astgen.gpa, .{
        .msg = msg,
        .node = node,
        .token = 0,
        .byte_offset = 0,
        .notes = notes_index,
    });
}

fn failNodeNotes(
    astgen: *AstGen,
    node: Ast.Node.Index,
    comptime format: []const u8,
    args: anytype,
    notes: []const u32,
) InnerError {
    try appendErrorNodeNotes(astgen, node, format, args, notes);
    return error.AnalysisFail;
}

fn failTok(
    astgen: *AstGen,
    token: Ast.TokenIndex,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    return astgen.failTokNotes(token, format, args, &[0]u32{});
}

fn appendErrorTok(
    astgen: *AstGen,
    token: Ast.TokenIndex,
    comptime format: []const u8,
    args: anytype,
) !void {
    try astgen.appendErrorTokNotesOff(token, 0, format, args, &[0]u32{});
}

fn failTokNotes(
    astgen: *AstGen,
    token: Ast.TokenIndex,
    comptime format: []const u8,
    args: anytype,
    notes: []const u32,
) InnerError {
    try appendErrorTokNotesOff(astgen, token, 0, format, args, notes);
    return error.AnalysisFail;
}

fn appendErrorTokNotes(
    astgen: *AstGen,
    token: Ast.TokenIndex,
    comptime format: []const u8,
    args: anytype,
    notes: []const u32,
) !void {
    return appendErrorTokNotesOff(astgen, token, 0, format, args, notes);
}

/// Same as `fail`, except given a token plus an offset from its starting byte
/// offset.
fn failOff(
    astgen: *AstGen,
    token: Ast.TokenIndex,
    byte_offset: u32,
    comptime format: []const u8,
    args: anytype,
) InnerError {
    try appendErrorTokNotesOff(astgen, token, byte_offset, format, args, &.{});
    return error.AnalysisFail;
}

fn appendErrorTokNotesOff(
    astgen: *AstGen,
    token: Ast.TokenIndex,
    byte_offset: u32,
    comptime format: []const u8,
    args: anytype,
    notes: []const u32,
) !void {
    @setCold(true);
    const gpa = astgen.gpa;
    const string_bytes = &astgen.string_bytes;
    const msg: Zir.NullTerminatedString = @enumFromInt(string_bytes.items.len);
    try string_bytes.writer(gpa).print(format ++ "\x00", args);
    const notes_index: u32 = if (notes.len != 0) blk: {
        const notes_start = astgen.extra.items.len;
        try astgen.extra.ensureTotalCapacity(gpa, notes_start + 1 + notes.len);
        astgen.extra.appendAssumeCapacity(@intCast(notes.len));
        astgen.extra.appendSliceAssumeCapacity(notes);
        break :blk @intCast(notes_start);
    } else 0;
    try astgen.compile_errors.append(gpa, .{
        .msg = msg,
        .node = 0,
        .token = token,
        .byte_offset = byte_offset,
        .notes = notes_index,
    });
}

fn errNoteTok(
    astgen: *AstGen,
    token: Ast.TokenIndex,
    comptime format: []const u8,
    args: anytype,
) Allocator.Error!u32 {
    return errNoteTokOff(astgen, token, 0, format, args);
}

fn errNoteTokOff(
    astgen: *AstGen,
    token: Ast.TokenIndex,
    byte_offset: u32,
    comptime format: []const u8,
    args: anytype,
) Allocator.Error!u32 {
    @setCold(true);
    const string_bytes = &astgen.string_bytes;
    const msg: Zir.NullTerminatedString = @enumFromInt(string_bytes.items.len);
    try string_bytes.writer(astgen.gpa).print(format ++ "\x00", args);
    return astgen.addExtra(Zir.Inst.CompileErrors.Item{
        .msg = msg,
        .node = 0,
        .token = token,
        .byte_offset = byte_offset,
        .notes = 0,
    });
}

fn errNoteNode(
    astgen: *AstGen,
    node: Ast.Node.Index,
    comptime format: []const u8,
    args: anytype,
) Allocator.Error!u32 {
    @setCold(true);
    const string_bytes = &astgen.string_bytes;
    const msg: Zir.NullTerminatedString = @enumFromInt(string_bytes.items.len);
    try string_bytes.writer(astgen.gpa).print(format ++ "\x00", args);
    return astgen.addExtra(Zir.Inst.CompileErrors.Item{
        .msg = msg,
        .node = node,
        .token = 0,
        .byte_offset = 0,
        .notes = 0,
    });
}

fn identAsString(astgen: *AstGen, ident_token: Ast.TokenIndex) !Zir.NullTerminatedString {
    const gpa = astgen.gpa;
    const string_bytes = &astgen.string_bytes;
    const str_index: u32 = @intCast(string_bytes.items.len);
    try astgen.appendIdentStr(ident_token, string_bytes);
    const key: []const u8 = string_bytes.items[str_index..];
    const gop = try astgen.string_table.getOrPutContextAdapted(gpa, key, StringIndexAdapter{
        .bytes = string_bytes,
    }, StringIndexContext{
        .bytes = string_bytes,
    });
    if (gop.found_existing) {
        string_bytes.shrinkRetainingCapacity(str_index);
        return @enumFromInt(gop.key_ptr.*);
    } else {
        gop.key_ptr.* = str_index;
        try string_bytes.append(gpa, 0);
        return @enumFromInt(str_index);
    }
}

/// Adds a doc comment block to `string_bytes` by walking backwards from `end_token`.
/// `end_token` must point at the first token after the last doc coment line.
/// Returns 0 if no doc comment is present.
fn docCommentAsString(astgen: *AstGen, end_token: Ast.TokenIndex) !Zir.NullTerminatedString {
    if (end_token == 0) return .empty;

    const token_tags = astgen.tree.tokens.items(.tag);

    var tok = end_token - 1;
    while (token_tags[tok] == .doc_comment) {
        if (tok == 0) break;
        tok -= 1;
    } else {
        tok += 1;
    }

    return docCommentAsStringFromFirst(astgen, end_token, tok);
}

/// end_token must be > the index of the last doc comment.
fn docCommentAsStringFromFirst(
    astgen: *AstGen,
    end_token: Ast.TokenIndex,
    start_token: Ast.TokenIndex,
) !Zir.NullTerminatedString {
    if (start_token == end_token) return .empty;

    const gpa = astgen.gpa;
    const string_bytes = &astgen.string_bytes;
    const str_index: u32 = @intCast(string_bytes.items.len);
    const token_starts = astgen.tree.tokens.items(.start);
    const token_tags = astgen.tree.tokens.items(.tag);

    const total_bytes = token_starts[end_token] - token_starts[start_token];
    try string_bytes.ensureUnusedCapacity(gpa, total_bytes);

    var current_token = start_token;
    while (current_token < end_token) : (current_token += 1) {
        switch (token_tags[current_token]) {
            .doc_comment => {
                const tok_bytes = astgen.tree.tokenSlice(current_token)[3..];
                string_bytes.appendSliceAssumeCapacity(tok_bytes);
                if (current_token != end_token - 1) {
                    string_bytes.appendAssumeCapacity('\n');
                }
            },
            else => break,
        }
    }

    const key: []const u8 = string_bytes.items[str_index..];
    const gop = try astgen.string_table.getOrPutContextAdapted(gpa, key, StringIndexAdapter{
        .bytes = string_bytes,
    }, StringIndexContext{
        .bytes = string_bytes,
    });

    if (gop.found_existing) {
        string_bytes.shrinkRetainingCapacity(str_index);
        return @enumFromInt(gop.key_ptr.*);
    } else {
        gop.key_ptr.* = str_index;
        try string_bytes.append(gpa, 0);
        return @enumFromInt(str_index);
    }
}

const IndexSlice = struct { index: Zir.NullTerminatedString, len: u32 };

fn strLitAsString(astgen: *AstGen, str_lit_token: Ast.TokenIndex) !IndexSlice {
    const gpa = astgen.gpa;
    const string_bytes = &astgen.string_bytes;
    const str_index: u32 = @intCast(string_bytes.items.len);
    const token_bytes = astgen.tree.tokenSlice(str_lit_token);
    try astgen.parseStrLit(str_lit_token, string_bytes, token_bytes, 0);
    const key: []const u8 = string_bytes.items[str_index..];
    if (std.mem.indexOfScalar(u8, key, 0)) |_| return .{
        .index = @enumFromInt(str_index),
        .len = @intCast(key.len),
    };
    const gop = try astgen.string_table.getOrPutContextAdapted(gpa, key, StringIndexAdapter{
        .bytes = string_bytes,
    }, StringIndexContext{
        .bytes = string_bytes,
    });
    if (gop.found_existing) {
        string_bytes.shrinkRetainingCapacity(str_index);
        return .{
            .index = @enumFromInt(gop.key_ptr.*),
            .len = @intCast(key.len),
        };
    } else {
        gop.key_ptr.* = str_index;
        // Still need a null byte because we are using the same table
        // to lookup null terminated strings, so if we get a match, it has to
        // be null terminated for that to work.
        try string_bytes.append(gpa, 0);
        return .{
            .index = @enumFromInt(str_index),
            .len = @intCast(key.len),
        };
    }
}

fn strLitNodeAsString(astgen: *AstGen, node: Ast.Node.Index) !IndexSlice {
    const tree = astgen.tree;
    const node_datas = tree.nodes.items(.data);

    const start = node_datas[node].lhs;
    const end = node_datas[node].rhs;

    const gpa = astgen.gpa;
    const string_bytes = &astgen.string_bytes;
    const str_index = string_bytes.items.len;

    // First line: do not append a newline.
    var tok_i = start;
    {
        const slice = tree.tokenSlice(tok_i);
        const carriage_return_ending: usize = if (slice[slice.len - 2] == '\r') 2 else 1;
        const line_bytes = slice[2 .. slice.len - carriage_return_ending];
        try string_bytes.appendSlice(gpa, line_bytes);
        tok_i += 1;
    }
    // Following lines: each line prepends a newline.
    while (tok_i <= end) : (tok_i += 1) {
        const slice = tree.tokenSlice(tok_i);
        const carriage_return_ending: usize = if (slice[slice.len - 2] == '\r') 2 else 1;
        const line_bytes = slice[2 .. slice.len - carriage_return_ending];
        try string_bytes.ensureUnusedCapacity(gpa, line_bytes.len + 1);
        string_bytes.appendAssumeCapacity('\n');
        string_bytes.appendSliceAssumeCapacity(line_bytes);
    }
    const len = string_bytes.items.len - str_index;
    try string_bytes.append(gpa, 0);
    return IndexSlice{
        .index = @enumFromInt(str_index),
        .len = @intCast(len),
    };
}

fn testNameString(astgen: *AstGen, str_lit_token: Ast.TokenIndex) !Zir.NullTerminatedString {
    const gpa = astgen.gpa;
    const string_bytes = &astgen.string_bytes;
    const str_index: u32 = @intCast(string_bytes.items.len);
    const token_bytes = astgen.tree.tokenSlice(str_lit_token);
    try string_bytes.append(gpa, 0); // Indicates this is a test.
    try astgen.parseStrLit(str_lit_token, string_bytes, token_bytes, 0);
    const slice = string_bytes.items[str_index + 1 ..];
    if (mem.indexOfScalar(u8, slice, 0) != null) {
        return astgen.failTok(str_lit_token, "test name cannot contain null bytes", .{});
    } else if (slice.len == 0) {
        return astgen.failTok(str_lit_token, "empty test name must be omitted", .{});
    }
    try string_bytes.append(gpa, 0);
    return @enumFromInt(str_index);
}

const Scope = struct {
    tag: Tag,

    fn cast(base: *Scope, comptime T: type) ?*T {
        if (T == Defer) {
            switch (base.tag) {
                .defer_normal, .defer_error => return @alignCast(@fieldParentPtr("base", base)),
                else => return null,
            }
        }
        if (T == Namespace) {
            switch (base.tag) {
                .namespace => return @alignCast(@fieldParentPtr("base", base)),
                else => return null,
            }
        }
        if (base.tag != T.base_tag)
            return null;

        return @alignCast(@fieldParentPtr("base", base));
    }

    fn parent(base: *Scope) ?*Scope {
        return switch (base.tag) {
            .gen_zir => base.cast(GenZir).?.parent,
            .local_val => base.cast(LocalVal).?.parent,
            .local_ptr => base.cast(LocalPtr).?.parent,
            .defer_normal, .defer_error => base.cast(Defer).?.parent,
            .namespace => base.cast(Namespace).?.parent,
            .top => null,
        };
    }

    const Tag = enum {
        gen_zir,
        local_val,
        local_ptr,
        defer_normal,
        defer_error,
        namespace,
        top,
    };

    /// The category of identifier. These tag names are user-visible in compile errors.
    const IdCat = enum {
        @"function parameter",
        @"local constant",
        @"local variable",
        @"switch tag capture",
        capture,
    };

    /// This is always a `const` local and importantly the `inst` is a value type, not a pointer.
    /// This structure lives as long as the AST generation of the Block
    /// node that contains the variable.
    const LocalVal = struct {
        const base_tag: Tag = .local_val;
        base: Scope = Scope{ .tag = base_tag },
        /// Parents can be: `LocalVal`, `LocalPtr`, `GenZir`, `Defer`, `Namespace`.
        parent: *Scope,
        gen_zir: *GenZir,
        inst: Zir.Inst.Ref,
        /// Source location of the corresponding variable declaration.
        token_src: Ast.TokenIndex,
        /// Track the first identifer where it is referenced.
        /// 0 means never referenced.
        used: Ast.TokenIndex = 0,
        /// Track the identifier where it is discarded, like this `_ = foo;`.
        /// 0 means never discarded.
        discarded: Ast.TokenIndex = 0,
        /// String table index.
        name: Zir.NullTerminatedString,
        id_cat: IdCat,
    };

    /// This could be a `const` or `var` local. It has a pointer instead of a value.
    /// This structure lives as long as the AST generation of the Block
    /// node that contains the variable.
    const LocalPtr = struct {
        const base_tag: Tag = .local_ptr;
        base: Scope = Scope{ .tag = base_tag },
        /// Parents can be: `LocalVal`, `LocalPtr`, `GenZir`, `Defer`, `Namespace`.
        parent: *Scope,
        gen_zir: *GenZir,
        ptr: Zir.Inst.Ref,
        /// Source location of the corresponding variable declaration.
        token_src: Ast.TokenIndex,
        /// Track the first identifer where it is referenced.
        /// 0 means never referenced.
        used: Ast.TokenIndex = 0,
        /// Track the identifier where it is discarded, like this `_ = foo;`.
        /// 0 means never discarded.
        discarded: Ast.TokenIndex = 0,
        /// Whether this value is used as an lvalue after inititialization.
        /// If not, we know it can be `const`, so will emit a compile error if it is `var`.
        used_as_lvalue: bool = false,
        /// String table index.
        name: Zir.NullTerminatedString,
        id_cat: IdCat,
        /// true means we find out during Sema whether the value is comptime.
        /// false means it is already known at AstGen the value is runtime-known.
        maybe_comptime: bool,
    };

    const Defer = struct {
        base: Scope,
        /// Parents can be: `LocalVal`, `LocalPtr`, `GenZir`, `Defer`, `Namespace`.
        parent: *Scope,
        index: u32,
        len: u32,
        remapped_err_code: Zir.Inst.OptionalIndex = .none,
    };

    /// Represents a global scope that has any number of declarations in it.
    /// Each declaration has this as the parent scope.
    const Namespace = struct {
        const base_tag: Tag = .namespace;
        base: Scope = Scope{ .tag = base_tag },

        /// Parents can be: `LocalVal`, `LocalPtr`, `GenZir`, `Defer`, `Namespace`.
        parent: *Scope,
        /// Maps string table index to the source location of declaration,
        /// for the purposes of reporting name shadowing compile errors.
        decls: std.AutoHashMapUnmanaged(Zir.NullTerminatedString, Ast.Node.Index) = .{},
        node: Ast.Node.Index,
        inst: Zir.Inst.Index,
        maybe_generic: bool,

        /// The astgen scope containing this namespace.
        /// Only valid during astgen.
        declaring_gz: ?*GenZir,

        /// Set of captures used by this namespace.
        captures: std.AutoArrayHashMapUnmanaged(Zir.Inst.Capture, void) = .{},

        fn deinit(self: *Namespace, gpa: Allocator) void {
            self.decls.deinit(gpa);
            self.captures.deinit(gpa);
            self.* = undefined;
        }
    };

    const Top = struct {
        const base_tag: Scope.Tag = .top;
        base: Scope = Scope{ .tag = base_tag },
    };
};

/// This is a temporary structure; references to it are valid only
/// while constructing a `Zir`.
const GenZir = struct {
    const base_tag: Scope.Tag = .gen_zir;
    base: Scope = Scope{ .tag = base_tag },
    /// Whether we're already in a scope known to be comptime. This is set
    /// whenever we know Sema will analyze the current block with `is_comptime`,
    /// for instance when we're within a `struct_decl` or a `block_comptime`.
    is_comptime: bool,
    /// Whether we're in an expression within a `@TypeOf` operand. In this case, closure of runtime
    /// variables is permitted where it is usually not.
    is_typeof: bool = false,
    /// This is set to true for a `GenZir` of a `block_inline`, indicating that
    /// exits from this block should use `break_inline` rather than `break`.
    is_inline: bool = false,
    c_import: bool = false,
    /// How decls created in this scope should be named.
    anon_name_strategy: Zir.Inst.NameStrategy = .anon,
    /// The containing decl AST node.
    decl_node_index: Ast.Node.Index,
    /// The containing decl line index, absolute.
    decl_line: u32,
    /// Parents can be: `LocalVal`, `LocalPtr`, `GenZir`, `Defer`, `Namespace`.
    parent: *Scope,
    /// All `GenZir` scopes for the same ZIR share this.
    astgen: *AstGen,
    /// Keeps track of the list of instructions in this scope. Possibly shared.
    /// Indexes to instructions in `astgen`.
    instructions: *ArrayListUnmanaged(Zir.Inst.Index),
    /// A sub-block may share its instructions ArrayList with containing GenZir,
    /// if use is strictly nested. This saves prior size of list for unstacking.
    instructions_top: usize,
    label: ?Label = null,
    break_block: Zir.Inst.OptionalIndex = .none,
    continue_block: Zir.Inst.OptionalIndex = .none,
    /// Only valid when setBreakResultInfo is called.
    break_result_info: AstGen.ResultInfo = undefined,

    suspend_node: Ast.Node.Index = 0,
    nosuspend_node: Ast.Node.Index = 0,
    /// Set if this GenZir is a defer.
    cur_defer_node: Ast.Node.Index = 0,
    // Set if this GenZir is a defer or it is inside a defer.
    any_defer_node: Ast.Node.Index = 0,

    const unstacked_top = std.math.maxInt(usize);
    /// Call unstack before adding any new instructions to containing GenZir.
    fn unstack(self: *GenZir) void {
        if (self.instructions_top != unstacked_top) {
            self.instructions.items.len = self.instructions_top;
            self.instructions_top = unstacked_top;
        }
    }

    fn isEmpty(self: *const GenZir) bool {
        return (self.instructions_top == unstacked_top) or
            (self.instructions.items.len == self.instructions_top);
    }

    fn instructionsSlice(self: *const GenZir) []Zir.Inst.Index {
        return if (self.instructions_top == unstacked_top)
            &[0]Zir.Inst.Index{}
        else
            self.instructions.items[self.instructions_top..];
    }

    fn instructionsSliceUpto(self: *const GenZir, stacked_gz: *GenZir) []Zir.Inst.Index {
        return if (self.instructions_top == unstacked_top)
            &[0]Zir.Inst.Index{}
        else if (self.instructions == stacked_gz.instructions and stacked_gz.instructions_top != unstacked_top)
            self.instructions.items[self.instructions_top..stacked_gz.instructions_top]
        else
            self.instructions.items[self.instructions_top..];
    }

    fn makeSubBlock(gz: *GenZir, scope: *Scope) GenZir {
        return .{
            .is_comptime = gz.is_comptime,
            .is_typeof = gz.is_typeof,
            .c_import = gz.c_import,
            .decl_node_index = gz.decl_node_index,
            .decl_line = gz.decl_line,
            .parent = scope,
            .astgen = gz.astgen,
            .suspend_node = gz.suspend_node,
            .nosuspend_node = gz.nosuspend_node,
            .any_defer_node = gz.any_defer_node,
            .instructions = gz.instructions,
            .instructions_top = gz.instructions.items.len,
        };
    }

    const Label = struct {
        token: Ast.TokenIndex,
        block_inst: Zir.Inst.Index,
        used: bool = false,
    };

    /// Assumes nothing stacked on `gz`.
    fn endsWithNoReturn(gz: GenZir) bool {
        if (gz.isEmpty()) return false;
        const tags = gz.astgen.instructions.items(.tag);
        const last_inst = gz.instructions.items[gz.instructions.items.len - 1];
        return tags[@intFromEnum(last_inst)].isNoReturn();
    }

    /// TODO all uses of this should be replaced with uses of `endsWithNoReturn`.
    fn refIsNoReturn(gz: GenZir, inst_ref: Zir.Inst.Ref) bool {
        if (inst_ref == .unreachable_value) return true;
        if (inst_ref.toIndex()) |inst_index| {
            return gz.astgen.instructions.items(.tag)[@intFromEnum(inst_index)].isNoReturn();
        }
        return false;
    }

    fn nodeIndexToRelative(gz: GenZir, node_index: Ast.Node.Index) i32 {
        return @as(i32, @bitCast(node_index)) - @as(i32, @bitCast(gz.decl_node_index));
    }

    fn tokenIndexToRelative(gz: GenZir, token: Ast.TokenIndex) u32 {
        return token - gz.srcToken();
    }

    fn srcToken(gz: GenZir) Ast.TokenIndex {
        return gz.astgen.tree.firstToken(gz.decl_node_index);
    }

    fn setBreakResultInfo(gz: *GenZir, parent_ri: AstGen.ResultInfo) void {
        // Depending on whether the result location is a pointer or value, different
        // ZIR needs to be generated. In the former case we rely on storing to the
        // pointer to communicate the result, and use breakvoid; in the latter case
        // the block break instructions will have the result values.
        switch (parent_ri.rl) {
            .coerced_ty => |ty_inst| {
                // Type coercion needs to happen before breaks.
                gz.break_result_info = .{ .rl = .{ .ty = ty_inst }, .ctx = parent_ri.ctx };
            },
            .discard => {
                // We don't forward the result context here. This prevents
                // "unnecessary discard" errors from being caused by expressions
                // far from the actual discard, such as a `break` from a
                // discarded block.
                gz.break_result_info = .{ .rl = .discard };
            },
            else => {
                gz.break_result_info = parent_ri;
            },
        }
    }

    /// Assumes nothing stacked on `gz`. Unstacks `gz`.
    fn setBoolBrBody(gz: *GenZir, bool_br: Zir.Inst.Index, bool_br_lhs: Zir.Inst.Ref) !void {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;
        const body = gz.instructionsSlice();
        const body_len = astgen.countBodyLenAfterFixups(body);
        try astgen.extra.ensureUnusedCapacity(
            gpa,
            @typeInfo(Zir.Inst.BoolBr).Struct.fields.len + body_len,
        );
        const zir_datas = astgen.instructions.items(.data);
        zir_datas[@intFromEnum(bool_br)].pl_node.payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.BoolBr{
            .lhs = bool_br_lhs,
            .body_len = body_len,
        });
        astgen.appendBodyWithFixups(body);
        gz.unstack();
    }

    /// Assumes nothing stacked on `gz`. Unstacks `gz`.
    fn setBlockBody(gz: *GenZir, inst: Zir.Inst.Index) !void {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;
        const body = gz.instructionsSlice();
        const body_len = astgen.countBodyLenAfterFixups(body);
        try astgen.extra.ensureUnusedCapacity(
            gpa,
            @typeInfo(Zir.Inst.Block).Struct.fields.len + body_len,
        );
        const zir_datas = astgen.instructions.items(.data);
        zir_datas[@intFromEnum(inst)].pl_node.payload_index = astgen.addExtraAssumeCapacity(
            Zir.Inst.Block{ .body_len = body_len },
        );
        astgen.appendBodyWithFixups(body);
        gz.unstack();
    }

    /// Assumes nothing stacked on `gz`. Unstacks `gz`.
    fn setTryBody(gz: *GenZir, inst: Zir.Inst.Index, operand: Zir.Inst.Ref) !void {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;
        const body = gz.instructionsSlice();
        const body_len = astgen.countBodyLenAfterFixups(body);
        try astgen.extra.ensureUnusedCapacity(
            gpa,
            @typeInfo(Zir.Inst.Try).Struct.fields.len + body_len,
        );
        const zir_datas = astgen.instructions.items(.data);
        zir_datas[@intFromEnum(inst)].pl_node.payload_index = astgen.addExtraAssumeCapacity(
            Zir.Inst.Try{
                .operand = operand,
                .body_len = body_len,
            },
        );
        astgen.appendBodyWithFixups(body);
        gz.unstack();
    }

    /// Must be called with the following stack set up:
    ///  * gz (bottom)
    ///  * align_gz
    ///  * addrspace_gz
    ///  * section_gz
    ///  * cc_gz
    ///  * ret_gz
    ///  * body_gz (top)
    /// Unstacks all of those except for `gz`.
    fn addFunc(gz: *GenZir, args: struct {
        src_node: Ast.Node.Index,
        lbrace_line: u32 = 0,
        lbrace_column: u32 = 0,
        param_block: Zir.Inst.Index,

        align_gz: ?*GenZir,
        addrspace_gz: ?*GenZir,
        section_gz: ?*GenZir,
        cc_gz: ?*GenZir,
        ret_gz: ?*GenZir,
        body_gz: ?*GenZir,

        align_ref: Zir.Inst.Ref,
        addrspace_ref: Zir.Inst.Ref,
        section_ref: Zir.Inst.Ref,
        cc_ref: Zir.Inst.Ref,
        ret_ref: Zir.Inst.Ref,

        lib_name: Zir.NullTerminatedString,
        noalias_bits: u32,
        is_var_args: bool,
        is_inferred_error: bool,
        is_test: bool,
        is_extern: bool,
        is_noinline: bool,
    }) !Zir.Inst.Ref {
        assert(args.src_node != 0);
        const astgen = gz.astgen;
        const gpa = astgen.gpa;
        const ret_ref = if (args.ret_ref == .void_type) .none else args.ret_ref;
        const new_index: Zir.Inst.Index = @enumFromInt(astgen.instructions.len);

        try astgen.instructions.ensureUnusedCapacity(gpa, 1);

        var body: []Zir.Inst.Index = &[0]Zir.Inst.Index{};
        var ret_body: []Zir.Inst.Index = &[0]Zir.Inst.Index{};
        var src_locs_and_hash_buffer: [7]u32 = undefined;
        var src_locs_and_hash: []u32 = src_locs_and_hash_buffer[0..0];
        if (args.body_gz) |body_gz| {
            const tree = astgen.tree;
            const node_tags = tree.nodes.items(.tag);
            const node_datas = tree.nodes.items(.data);
            const token_starts = tree.tokens.items(.start);
            const fn_decl = args.src_node;
            assert(node_tags[fn_decl] == .fn_decl or node_tags[fn_decl] == .test_decl);
            const block = node_datas[fn_decl].rhs;
            const rbrace_start = token_starts[tree.lastToken(block)];
            astgen.advanceSourceCursor(rbrace_start);
            const rbrace_line: u32 = @intCast(astgen.source_line - gz.decl_line);
            const rbrace_column: u32 = @intCast(astgen.source_column);

            const columns = args.lbrace_column | (rbrace_column << 16);

            const proto_hash: std.zig.SrcHash = switch (node_tags[fn_decl]) {
                .fn_decl => sig_hash: {
                    const proto_node = node_datas[fn_decl].lhs;
                    break :sig_hash std.zig.hashSrc(tree.getNodeSource(proto_node));
                },
                .test_decl => std.zig.hashSrc(""), // tests don't have a prototype
                else => unreachable,
            };
            const proto_hash_arr: [4]u32 = @bitCast(proto_hash);

            src_locs_and_hash_buffer = .{
                args.lbrace_line,
                rbrace_line,
                columns,
                proto_hash_arr[0],
                proto_hash_arr[1],
                proto_hash_arr[2],
                proto_hash_arr[3],
            };
            src_locs_and_hash = &src_locs_and_hash_buffer;

            body = body_gz.instructionsSlice();
            if (args.ret_gz) |ret_gz|
                ret_body = ret_gz.instructionsSliceUpto(body_gz);
        } else {
            if (args.ret_gz) |ret_gz|
                ret_body = ret_gz.instructionsSlice();
        }
        const body_len = astgen.countBodyLenAfterFixups(body);

        if (args.cc_ref != .none or args.lib_name != .empty or args.is_var_args or args.is_test or
            args.is_extern or args.align_ref != .none or args.section_ref != .none or
            args.addrspace_ref != .none or args.noalias_bits != 0 or args.is_noinline)
        {
            var align_body: []Zir.Inst.Index = &.{};
            var addrspace_body: []Zir.Inst.Index = &.{};
            var section_body: []Zir.Inst.Index = &.{};
            var cc_body: []Zir.Inst.Index = &.{};
            if (args.ret_gz != null) {
                align_body = args.align_gz.?.instructionsSliceUpto(args.addrspace_gz.?);
                addrspace_body = args.addrspace_gz.?.instructionsSliceUpto(args.section_gz.?);
                section_body = args.section_gz.?.instructionsSliceUpto(args.cc_gz.?);
                cc_body = args.cc_gz.?.instructionsSliceUpto(args.ret_gz.?);
            }

            try astgen.extra.ensureUnusedCapacity(
                gpa,
                @typeInfo(Zir.Inst.FuncFancy).Struct.fields.len +
                    fancyFnExprExtraLen(astgen, align_body, args.align_ref) +
                    fancyFnExprExtraLen(astgen, addrspace_body, args.addrspace_ref) +
                    fancyFnExprExtraLen(astgen, section_body, args.section_ref) +
                    fancyFnExprExtraLen(astgen, cc_body, args.cc_ref) +
                    fancyFnExprExtraLen(astgen, ret_body, ret_ref) +
                    body_len + src_locs_and_hash.len +
                    @intFromBool(args.lib_name != .empty) +
                    @intFromBool(args.noalias_bits != 0),
            );
            const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.FuncFancy{
                .param_block = args.param_block,
                .body_len = body_len,
                .bits = .{
                    .is_var_args = args.is_var_args,
                    .is_inferred_error = args.is_inferred_error,
                    .is_test = args.is_test,
                    .is_extern = args.is_extern,
                    .is_noinline = args.is_noinline,
                    .has_lib_name = args.lib_name != .empty,
                    .has_any_noalias = args.noalias_bits != 0,

                    .has_align_ref = args.align_ref != .none,
                    .has_addrspace_ref = args.addrspace_ref != .none,
                    .has_section_ref = args.section_ref != .none,
                    .has_cc_ref = args.cc_ref != .none,
                    .has_ret_ty_ref = ret_ref != .none,

                    .has_align_body = align_body.len != 0,
                    .has_addrspace_body = addrspace_body.len != 0,
                    .has_section_body = section_body.len != 0,
                    .has_cc_body = cc_body.len != 0,
                    .has_ret_ty_body = ret_body.len != 0,
                },
            });
            if (args.lib_name != .empty) {
                astgen.extra.appendAssumeCapacity(@intFromEnum(args.lib_name));
            }

            const zir_datas = astgen.instructions.items(.data);
            if (align_body.len != 0) {
                astgen.extra.appendAssumeCapacity(countBodyLenAfterFixups(astgen, align_body));
                astgen.appendBodyWithFixups(align_body);
                const break_extra = zir_datas[@intFromEnum(align_body[align_body.len - 1])].@"break".payload_index;
                astgen.extra.items[break_extra + std.meta.fieldIndex(Zir.Inst.Break, "block_inst").?] =
                    @intFromEnum(new_index);
            } else if (args.align_ref != .none) {
                astgen.extra.appendAssumeCapacity(@intFromEnum(args.align_ref));
            }
            if (addrspace_body.len != 0) {
                astgen.extra.appendAssumeCapacity(countBodyLenAfterFixups(astgen, addrspace_body));
                astgen.appendBodyWithFixups(addrspace_body);
                const break_extra =
                    zir_datas[@intFromEnum(addrspace_body[addrspace_body.len - 1])].@"break".payload_index;
                astgen.extra.items[break_extra + std.meta.fieldIndex(Zir.Inst.Break, "block_inst").?] =
                    @intFromEnum(new_index);
            } else if (args.addrspace_ref != .none) {
                astgen.extra.appendAssumeCapacity(@intFromEnum(args.addrspace_ref));
            }
            if (section_body.len != 0) {
                astgen.extra.appendAssumeCapacity(countBodyLenAfterFixups(astgen, section_body));
                astgen.appendBodyWithFixups(section_body);
                const break_extra =
                    zir_datas[@intFromEnum(section_body[section_body.len - 1])].@"break".payload_index;
                astgen.extra.items[break_extra + std.meta.fieldIndex(Zir.Inst.Break, "block_inst").?] =
                    @intFromEnum(new_index);
            } else if (args.section_ref != .none) {
                astgen.extra.appendAssumeCapacity(@intFromEnum(args.section_ref));
            }
            if (cc_body.len != 0) {
                astgen.extra.appendAssumeCapacity(countBodyLenAfterFixups(astgen, cc_body));
                astgen.appendBodyWithFixups(cc_body);
                const break_extra = zir_datas[@intFromEnum(cc_body[cc_body.len - 1])].@"break".payload_index;
                astgen.extra.items[break_extra + std.meta.fieldIndex(Zir.Inst.Break, "block_inst").?] =
                    @intFromEnum(new_index);
            } else if (args.cc_ref != .none) {
                astgen.extra.appendAssumeCapacity(@intFromEnum(args.cc_ref));
            }
            if (ret_body.len != 0) {
                astgen.extra.appendAssumeCapacity(countBodyLenAfterFixups(astgen, ret_body));
                astgen.appendBodyWithFixups(ret_body);
                const break_extra = zir_datas[@intFromEnum(ret_body[ret_body.len - 1])].@"break".payload_index;
                astgen.extra.items[break_extra + std.meta.fieldIndex(Zir.Inst.Break, "block_inst").?] =
                    @intFromEnum(new_index);
            } else if (ret_ref != .none) {
                astgen.extra.appendAssumeCapacity(@intFromEnum(ret_ref));
            }

            if (args.noalias_bits != 0) {
                astgen.extra.appendAssumeCapacity(args.noalias_bits);
            }

            astgen.appendBodyWithFixups(body);
            astgen.extra.appendSliceAssumeCapacity(src_locs_and_hash);

            // Order is important when unstacking.
            if (args.body_gz) |body_gz| body_gz.unstack();
            if (args.ret_gz != null) {
                args.ret_gz.?.unstack();
                args.cc_gz.?.unstack();
                args.section_gz.?.unstack();
                args.addrspace_gz.?.unstack();
                args.align_gz.?.unstack();
            }

            try gz.instructions.ensureUnusedCapacity(gpa, 1);

            astgen.instructions.appendAssumeCapacity(.{
                .tag = .func_fancy,
                .data = .{ .pl_node = .{
                    .src_node = gz.nodeIndexToRelative(args.src_node),
                    .payload_index = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return new_index.toRef();
        } else {
            try astgen.extra.ensureUnusedCapacity(
                gpa,
                @typeInfo(Zir.Inst.Func).Struct.fields.len + 1 +
                    fancyFnExprExtraLen(astgen, ret_body, ret_ref) +
                    body_len + src_locs_and_hash.len,
            );

            const ret_body_len = if (ret_body.len != 0)
                countBodyLenAfterFixups(astgen, ret_body)
            else
                @intFromBool(ret_ref != .none);

            const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.Func{
                .param_block = args.param_block,
                .ret_body_len = ret_body_len,
                .body_len = body_len,
            });
            const zir_datas = astgen.instructions.items(.data);
            if (ret_body.len != 0) {
                astgen.appendBodyWithFixups(ret_body);

                const break_extra = zir_datas[@intFromEnum(ret_body[ret_body.len - 1])].@"break".payload_index;
                astgen.extra.items[break_extra + std.meta.fieldIndex(Zir.Inst.Break, "block_inst").?] =
                    @intFromEnum(new_index);
            } else if (ret_ref != .none) {
                astgen.extra.appendAssumeCapacity(@intFromEnum(ret_ref));
            }
            astgen.appendBodyWithFixups(body);
            astgen.extra.appendSliceAssumeCapacity(src_locs_and_hash);

            // Order is important when unstacking.
            if (args.body_gz) |body_gz| body_gz.unstack();
            if (args.ret_gz) |ret_gz| ret_gz.unstack();
            if (args.cc_gz) |cc_gz| cc_gz.unstack();
            if (args.section_gz) |section_gz| section_gz.unstack();
            if (args.addrspace_gz) |addrspace_gz| addrspace_gz.unstack();
            if (args.align_gz) |align_gz| align_gz.unstack();

            try gz.instructions.ensureUnusedCapacity(gpa, 1);

            const tag: Zir.Inst.Tag = if (args.is_inferred_error) .func_inferred else .func;
            astgen.instructions.appendAssumeCapacity(.{
                .tag = tag,
                .data = .{ .pl_node = .{
                    .src_node = gz.nodeIndexToRelative(args.src_node),
                    .payload_index = payload_index,
                } },
            });
            gz.instructions.appendAssumeCapacity(new_index);
            return new_index.toRef();
        }
    }

    fn fancyFnExprExtraLen(astgen: *AstGen, body: []Zir.Inst.Index, ref: Zir.Inst.Ref) u32 {
        // In the case of non-empty body, there is one for the body length,
        // and then one for each instruction.
        return countBodyLenAfterFixups(astgen, body) + @intFromBool(ref != .none);
    }

    fn addVar(gz: *GenZir, args: struct {
        align_inst: Zir.Inst.Ref,
        lib_name: Zir.NullTerminatedString,
        var_type: Zir.Inst.Ref,
        init: Zir.Inst.Ref,
        is_extern: bool,
        is_const: bool,
        is_threadlocal: bool,
    }) !Zir.Inst.Ref {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try astgen.instructions.ensureUnusedCapacity(gpa, 1);

        try astgen.extra.ensureUnusedCapacity(
            gpa,
            @typeInfo(Zir.Inst.ExtendedVar).Struct.fields.len +
                @intFromBool(args.lib_name != .empty) +
                @intFromBool(args.align_inst != .none) +
                @intFromBool(args.init != .none),
        );
        const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.ExtendedVar{
            .var_type = args.var_type,
        });
        if (args.lib_name != .empty) {
            astgen.extra.appendAssumeCapacity(@intFromEnum(args.lib_name));
        }
        if (args.align_inst != .none) {
            astgen.extra.appendAssumeCapacity(@intFromEnum(args.align_inst));
        }
        if (args.init != .none) {
            astgen.extra.appendAssumeCapacity(@intFromEnum(args.init));
        }

        const new_index: Zir.Inst.Index = @enumFromInt(astgen.instructions.len);
        astgen.instructions.appendAssumeCapacity(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .variable,
                .small = @bitCast(Zir.Inst.ExtendedVar.Small{
                    .has_lib_name = args.lib_name != .empty,
                    .has_align = args.align_inst != .none,
                    .has_init = args.init != .none,
                    .is_extern = args.is_extern,
                    .is_const = args.is_const,
                    .is_threadlocal = args.is_threadlocal,
                }),
                .operand = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index.toRef();
    }

    fn addInt(gz: *GenZir, integer: u64) !Zir.Inst.Ref {
        return gz.add(.{
            .tag = .int,
            .data = .{ .int = integer },
        });
    }

    fn addIntBig(gz: *GenZir, limbs: []const std.math.big.Limb) !Zir.Inst.Ref {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;
        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try astgen.instructions.ensureUnusedCapacity(gpa, 1);
        try astgen.string_bytes.ensureUnusedCapacity(gpa, @sizeOf(std.math.big.Limb) * limbs.len);

        const new_index: Zir.Inst.Index = @enumFromInt(astgen.instructions.len);
        astgen.instructions.appendAssumeCapacity(.{
            .tag = .int_big,
            .data = .{ .str = .{
                .start = @enumFromInt(astgen.string_bytes.items.len),
                .len = @intCast(limbs.len),
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        astgen.string_bytes.appendSliceAssumeCapacity(mem.sliceAsBytes(limbs));
        return new_index.toRef();
    }

    fn addFloat(gz: *GenZir, number: f64) !Zir.Inst.Ref {
        return gz.add(.{
            .tag = .float,
            .data = .{ .float = number },
        });
    }

    fn addUnNode(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        operand: Zir.Inst.Ref,
        /// Absolute node index. This function does the conversion to offset from Decl.
        src_node: Ast.Node.Index,
    ) !Zir.Inst.Ref {
        assert(operand != .none);
        return gz.add(.{
            .tag = tag,
            .data = .{ .un_node = .{
                .operand = operand,
                .src_node = gz.nodeIndexToRelative(src_node),
            } },
        });
    }

    fn makeUnNode(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        operand: Zir.Inst.Ref,
        /// Absolute node index. This function does the conversion to offset from Decl.
        src_node: Ast.Node.Index,
    ) !Zir.Inst.Index {
        assert(operand != .none);
        const new_index: Zir.Inst.Index = @enumFromInt(gz.astgen.instructions.len);
        try gz.astgen.instructions.append(gz.astgen.gpa, .{
            .tag = tag,
            .data = .{ .un_node = .{
                .operand = operand,
                .src_node = gz.nodeIndexToRelative(src_node),
            } },
        });
        return new_index;
    }

    fn addPlNode(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        /// Absolute node index. This function does the conversion to offset from Decl.
        src_node: Ast.Node.Index,
        extra: anytype,
    ) !Zir.Inst.Ref {
        const gpa = gz.astgen.gpa;
        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

        const payload_index = try gz.astgen.addExtra(extra);
        const new_index: Zir.Inst.Index = @enumFromInt(gz.astgen.instructions.len);
        gz.astgen.instructions.appendAssumeCapacity(.{
            .tag = tag,
            .data = .{ .pl_node = .{
                .src_node = gz.nodeIndexToRelative(src_node),
                .payload_index = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index.toRef();
    }

    fn addPlNodePayloadIndex(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        /// Absolute node index. This function does the conversion to offset from Decl.
        src_node: Ast.Node.Index,
        payload_index: u32,
    ) !Zir.Inst.Ref {
        return try gz.add(.{
            .tag = tag,
            .data = .{ .pl_node = .{
                .src_node = gz.nodeIndexToRelative(src_node),
                .payload_index = payload_index,
            } },
        });
    }

    /// Supports `param_gz` stacked on `gz`. Assumes nothing stacked on `param_gz`. Unstacks `param_gz`.
    fn addParam(
        gz: *GenZir,
        param_gz: *GenZir,
        tag: Zir.Inst.Tag,
        /// Absolute token index. This function does the conversion to Decl offset.
        abs_tok_index: Ast.TokenIndex,
        name: Zir.NullTerminatedString,
        first_doc_comment: ?Ast.TokenIndex,
    ) !Zir.Inst.Index {
        const gpa = gz.astgen.gpa;
        const param_body = param_gz.instructionsSlice();
        const body_len = gz.astgen.countBodyLenAfterFixups(param_body);
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);
        try gz.astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.Param).Struct.fields.len + body_len);

        const doc_comment_index = if (first_doc_comment) |first|
            try gz.astgen.docCommentAsStringFromFirst(abs_tok_index, first)
        else
            .empty;

        const payload_index = gz.astgen.addExtraAssumeCapacity(Zir.Inst.Param{
            .name = name,
            .doc_comment = doc_comment_index,
            .body_len = @intCast(body_len),
        });
        gz.astgen.appendBodyWithFixups(param_body);
        param_gz.unstack();

        const new_index: Zir.Inst.Index = @enumFromInt(gz.astgen.instructions.len);
        gz.astgen.instructions.appendAssumeCapacity(.{
            .tag = tag,
            .data = .{ .pl_tok = .{
                .src_tok = gz.tokenIndexToRelative(abs_tok_index),
                .payload_index = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index;
    }

    fn addExtendedPayload(gz: *GenZir, opcode: Zir.Inst.Extended, extra: anytype) !Zir.Inst.Ref {
        return addExtendedPayloadSmall(gz, opcode, undefined, extra);
    }

    fn addExtendedPayloadSmall(
        gz: *GenZir,
        opcode: Zir.Inst.Extended,
        small: u16,
        extra: anytype,
    ) !Zir.Inst.Ref {
        const gpa = gz.astgen.gpa;

        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

        const payload_index = try gz.astgen.addExtra(extra);
        const new_index: Zir.Inst.Index = @enumFromInt(gz.astgen.instructions.len);
        gz.astgen.instructions.appendAssumeCapacity(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = opcode,
                .small = small,
                .operand = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index.toRef();
    }

    fn addExtendedMultiOp(
        gz: *GenZir,
        opcode: Zir.Inst.Extended,
        node: Ast.Node.Index,
        operands: []const Zir.Inst.Ref,
    ) !Zir.Inst.Ref {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try astgen.instructions.ensureUnusedCapacity(gpa, 1);
        try astgen.extra.ensureUnusedCapacity(
            gpa,
            @typeInfo(Zir.Inst.NodeMultiOp).Struct.fields.len + operands.len,
        );

        const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.NodeMultiOp{
            .src_node = gz.nodeIndexToRelative(node),
        });
        const new_index: Zir.Inst.Index = @enumFromInt(astgen.instructions.len);
        astgen.instructions.appendAssumeCapacity(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = opcode,
                .small = @intCast(operands.len),
                .operand = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        astgen.appendRefsAssumeCapacity(operands);
        return new_index.toRef();
    }

    fn addExtendedMultiOpPayloadIndex(
        gz: *GenZir,
        opcode: Zir.Inst.Extended,
        payload_index: u32,
        trailing_len: usize,
    ) !Zir.Inst.Ref {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try astgen.instructions.ensureUnusedCapacity(gpa, 1);
        const new_index: Zir.Inst.Index = @enumFromInt(astgen.instructions.len);
        astgen.instructions.appendAssumeCapacity(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = opcode,
                .small = @intCast(trailing_len),
                .operand = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index.toRef();
    }

    fn addExtendedNodeSmall(
        gz: *GenZir,
        opcode: Zir.Inst.Extended,
        src_node: Ast.Node.Index,
        small: u16,
    ) !Zir.Inst.Ref {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try astgen.instructions.ensureUnusedCapacity(gpa, 1);
        const new_index: Zir.Inst.Index = @enumFromInt(astgen.instructions.len);
        astgen.instructions.appendAssumeCapacity(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = opcode,
                .small = small,
                .operand = @bitCast(gz.nodeIndexToRelative(src_node)),
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index.toRef();
    }

    fn addUnTok(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        operand: Zir.Inst.Ref,
        /// Absolute token index. This function does the conversion to Decl offset.
        abs_tok_index: Ast.TokenIndex,
    ) !Zir.Inst.Ref {
        assert(operand != .none);
        return gz.add(.{
            .tag = tag,
            .data = .{ .un_tok = .{
                .operand = operand,
                .src_tok = gz.tokenIndexToRelative(abs_tok_index),
            } },
        });
    }

    fn makeUnTok(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        operand: Zir.Inst.Ref,
        /// Absolute token index. This function does the conversion to Decl offset.
        abs_tok_index: Ast.TokenIndex,
    ) !Zir.Inst.Index {
        const astgen = gz.astgen;
        const new_index: Zir.Inst.Index = @enumFromInt(astgen.instructions.len);
        assert(operand != .none);
        try astgen.instructions.append(astgen.gpa, .{
            .tag = tag,
            .data = .{ .un_tok = .{
                .operand = operand,
                .src_tok = gz.tokenIndexToRelative(abs_tok_index),
            } },
        });
        return new_index;
    }

    fn addStrTok(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        str_index: Zir.NullTerminatedString,
        /// Absolute token index. This function does the conversion to Decl offset.
        abs_tok_index: Ast.TokenIndex,
    ) !Zir.Inst.Ref {
        return gz.add(.{
            .tag = tag,
            .data = .{ .str_tok = .{
                .start = str_index,
                .src_tok = gz.tokenIndexToRelative(abs_tok_index),
            } },
        });
    }

    fn addSaveErrRetIndex(
        gz: *GenZir,
        cond: union(enum) {
            always: void,
            if_of_error_type: Zir.Inst.Ref,
        },
    ) !Zir.Inst.Index {
        return gz.addAsIndex(.{
            .tag = .save_err_ret_index,
            .data = .{ .save_err_ret_index = .{
                .operand = switch (cond) {
                    .if_of_error_type => |x| x,
                    else => .none,
                },
            } },
        });
    }

    const BranchTarget = union(enum) {
        ret,
        block: Zir.Inst.Index,
    };

    fn addRestoreErrRetIndex(
        gz: *GenZir,
        bt: BranchTarget,
        cond: union(enum) {
            always: void,
            if_non_error: Zir.Inst.Ref,
        },
        src_node: Ast.Node.Index,
    ) !Zir.Inst.Index {
        switch (cond) {
            .always => return gz.addAsIndex(.{
                .tag = .restore_err_ret_index_unconditional,
                .data = .{ .un_node = .{
                    .operand = switch (bt) {
                        .ret => .none,
                        .block => |b| b.toRef(),
                    },
                    .src_node = gz.nodeIndexToRelative(src_node),
                } },
            }),
            .if_non_error => |operand| switch (bt) {
                .ret => return gz.addAsIndex(.{
                    .tag = .restore_err_ret_index_fn_entry,
                    .data = .{ .un_node = .{
                        .operand = operand,
                        .src_node = gz.nodeIndexToRelative(src_node),
                    } },
                }),
                .block => |block| return (try gz.addExtendedPayload(
                    .restore_err_ret_index,
                    Zir.Inst.RestoreErrRetIndex{
                        .src_node = gz.nodeIndexToRelative(src_node),
                        .block = block.toRef(),
                        .operand = operand,
                    },
                )).toIndex().?,
            },
        }
    }

    fn addBreak(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        block_inst: Zir.Inst.Index,
        operand: Zir.Inst.Ref,
    ) !Zir.Inst.Index {
        const gpa = gz.astgen.gpa;
        try gz.instructions.ensureUnusedCapacity(gpa, 1);

        const new_index = try gz.makeBreak(tag, block_inst, operand);
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index;
    }

    fn makeBreak(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        block_inst: Zir.Inst.Index,
        operand: Zir.Inst.Ref,
    ) !Zir.Inst.Index {
        return gz.makeBreakCommon(tag, block_inst, operand, null);
    }

    fn addBreakWithSrcNode(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        block_inst: Zir.Inst.Index,
        operand: Zir.Inst.Ref,
        operand_src_node: Ast.Node.Index,
    ) !Zir.Inst.Index {
        const gpa = gz.astgen.gpa;
        try gz.instructions.ensureUnusedCapacity(gpa, 1);

        const new_index = try gz.makeBreakWithSrcNode(tag, block_inst, operand, operand_src_node);
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index;
    }

    fn makeBreakWithSrcNode(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        block_inst: Zir.Inst.Index,
        operand: Zir.Inst.Ref,
        operand_src_node: Ast.Node.Index,
    ) !Zir.Inst.Index {
        return gz.makeBreakCommon(tag, block_inst, operand, operand_src_node);
    }

    fn makeBreakCommon(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        block_inst: Zir.Inst.Index,
        operand: Zir.Inst.Ref,
        operand_src_node: ?Ast.Node.Index,
    ) !Zir.Inst.Index {
        const gpa = gz.astgen.gpa;
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);
        try gz.astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.Break).Struct.fields.len);

        const new_index: Zir.Inst.Index = @enumFromInt(gz.astgen.instructions.len);
        gz.astgen.instructions.appendAssumeCapacity(.{
            .tag = tag,
            .data = .{ .@"break" = .{
                .operand = operand,
                .payload_index = gz.astgen.addExtraAssumeCapacity(Zir.Inst.Break{
                    .operand_src_node = if (operand_src_node) |src_node|
                        gz.nodeIndexToRelative(src_node)
                    else
                        Zir.Inst.Break.no_src_node,
                    .block_inst = block_inst,
                }),
            } },
        });
        return new_index;
    }

    fn addBin(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        lhs: Zir.Inst.Ref,
        rhs: Zir.Inst.Ref,
    ) !Zir.Inst.Ref {
        assert(lhs != .none);
        assert(rhs != .none);
        return gz.add(.{
            .tag = tag,
            .data = .{ .bin = .{
                .lhs = lhs,
                .rhs = rhs,
            } },
        });
    }

    fn addDefer(gz: *GenZir, index: u32, len: u32) !void {
        _ = try gz.add(.{
            .tag = .@"defer",
            .data = .{ .@"defer" = .{
                .index = index,
                .len = len,
            } },
        });
    }

    fn addDecl(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        decl_index: u32,
        src_node: Ast.Node.Index,
    ) !Zir.Inst.Ref {
        return gz.add(.{
            .tag = tag,
            .data = .{ .pl_node = .{
                .src_node = gz.nodeIndexToRelative(src_node),
                .payload_index = decl_index,
            } },
        });
    }

    fn addNode(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        /// Absolute node index. This function does the conversion to offset from Decl.
        src_node: Ast.Node.Index,
    ) !Zir.Inst.Ref {
        return gz.add(.{
            .tag = tag,
            .data = .{ .node = gz.nodeIndexToRelative(src_node) },
        });
    }

    fn addInstNode(
        gz: *GenZir,
        tag: Zir.Inst.Tag,
        inst: Zir.Inst.Index,
        /// Absolute node index. This function does the conversion to offset from Decl.
        src_node: Ast.Node.Index,
    ) !Zir.Inst.Ref {
        return gz.add(.{
            .tag = tag,
            .data = .{ .inst_node = .{
                .inst = inst,
                .src_node = gz.nodeIndexToRelative(src_node),
            } },
        });
    }

    fn addNodeExtended(
        gz: *GenZir,
        opcode: Zir.Inst.Extended,
        /// Absolute node index. This function does the conversion to offset from Decl.
        src_node: Ast.Node.Index,
    ) !Zir.Inst.Ref {
        return gz.add(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = opcode,
                .small = undefined,
                .operand = @bitCast(gz.nodeIndexToRelative(src_node)),
            } },
        });
    }

    fn addAllocExtended(
        gz: *GenZir,
        args: struct {
            /// Absolute node index. This function does the conversion to offset from Decl.
            node: Ast.Node.Index,
            type_inst: Zir.Inst.Ref,
            align_inst: Zir.Inst.Ref,
            is_const: bool,
            is_comptime: bool,
        },
    ) !Zir.Inst.Ref {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try astgen.instructions.ensureUnusedCapacity(gpa, 1);
        try astgen.extra.ensureUnusedCapacity(
            gpa,
            @typeInfo(Zir.Inst.AllocExtended).Struct.fields.len +
                @intFromBool(args.type_inst != .none) +
                @intFromBool(args.align_inst != .none),
        );
        const payload_index = gz.astgen.addExtraAssumeCapacity(Zir.Inst.AllocExtended{
            .src_node = gz.nodeIndexToRelative(args.node),
        });
        if (args.type_inst != .none) {
            astgen.extra.appendAssumeCapacity(@intFromEnum(args.type_inst));
        }
        if (args.align_inst != .none) {
            astgen.extra.appendAssumeCapacity(@intFromEnum(args.align_inst));
        }

        const has_type: u4 = @intFromBool(args.type_inst != .none);
        const has_align: u4 = @intFromBool(args.align_inst != .none);
        const is_const: u4 = @intFromBool(args.is_const);
        const is_comptime: u4 = @intFromBool(args.is_comptime);
        const small: u16 = has_type | (has_align << 1) | (is_const << 2) | (is_comptime << 3);

        const new_index: Zir.Inst.Index = @enumFromInt(astgen.instructions.len);
        astgen.instructions.appendAssumeCapacity(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .alloc,
                .small = small,
                .operand = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index.toRef();
    }

    fn addAsm(
        gz: *GenZir,
        args: struct {
            tag: Zir.Inst.Extended,
            /// Absolute node index. This function does the conversion to offset from Decl.
            node: Ast.Node.Index,
            asm_source: Zir.NullTerminatedString,
            output_type_bits: u32,
            is_volatile: bool,
            outputs: []const Zir.Inst.Asm.Output,
            inputs: []const Zir.Inst.Asm.Input,
            clobbers: []const u32,
        },
    ) !Zir.Inst.Ref {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try astgen.instructions.ensureUnusedCapacity(gpa, 1);
        try astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.Asm).Struct.fields.len +
            args.outputs.len * @typeInfo(Zir.Inst.Asm.Output).Struct.fields.len +
            args.inputs.len * @typeInfo(Zir.Inst.Asm.Input).Struct.fields.len +
            args.clobbers.len);

        const payload_index = gz.astgen.addExtraAssumeCapacity(Zir.Inst.Asm{
            .src_node = gz.nodeIndexToRelative(args.node),
            .asm_source = args.asm_source,
            .output_type_bits = args.output_type_bits,
        });
        for (args.outputs) |output| {
            _ = gz.astgen.addExtraAssumeCapacity(output);
        }
        for (args.inputs) |input| {
            _ = gz.astgen.addExtraAssumeCapacity(input);
        }
        gz.astgen.extra.appendSliceAssumeCapacity(args.clobbers);

        //  * 0b00000000_000XXXXX - `outputs_len`.
        //  * 0b000000XX_XXX00000 - `inputs_len`.
        //  * 0b0XXXXX00_00000000 - `clobbers_len`.
        //  * 0bX0000000_00000000 - is volatile
        const small: u16 = @as(u16, @intCast(args.outputs.len)) |
            @as(u16, @intCast(args.inputs.len << 5)) |
            @as(u16, @intCast(args.clobbers.len << 10)) |
            (@as(u16, @intFromBool(args.is_volatile)) << 15);

        const new_index: Zir.Inst.Index = @enumFromInt(astgen.instructions.len);
        astgen.instructions.appendAssumeCapacity(.{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = args.tag,
                .small = small,
                .operand = payload_index,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index.toRef();
    }

    /// Note that this returns a `Zir.Inst.Index` not a ref.
    /// Does *not* append the block instruction to the scope.
    /// Leaves the `payload_index` field undefined.
    fn makeBlockInst(gz: *GenZir, tag: Zir.Inst.Tag, node: Ast.Node.Index) !Zir.Inst.Index {
        const new_index: Zir.Inst.Index = @enumFromInt(gz.astgen.instructions.len);
        const gpa = gz.astgen.gpa;
        try gz.astgen.instructions.append(gpa, .{
            .tag = tag,
            .data = .{ .pl_node = .{
                .src_node = gz.nodeIndexToRelative(node),
                .payload_index = undefined,
            } },
        });
        return new_index;
    }

    /// Note that this returns a `Zir.Inst.Index` not a ref.
    /// Leaves the `payload_index` field undefined.
    fn addCondBr(gz: *GenZir, tag: Zir.Inst.Tag, node: Ast.Node.Index) !Zir.Inst.Index {
        const gpa = gz.astgen.gpa;
        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        const new_index: Zir.Inst.Index = @enumFromInt(gz.astgen.instructions.len);
        try gz.astgen.instructions.append(gpa, .{
            .tag = tag,
            .data = .{ .pl_node = .{
                .src_node = gz.nodeIndexToRelative(node),
                .payload_index = undefined,
            } },
        });
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index;
    }

    fn setStruct(gz: *GenZir, inst: Zir.Inst.Index, args: struct {
        src_node: Ast.Node.Index,
        captures_len: u32,
        fields_len: u32,
        decls_len: u32,
        has_backing_int: bool,
        layout: std.builtin.Type.ContainerLayout,
        known_non_opv: bool,
        known_comptime_only: bool,
        is_tuple: bool,
        any_comptime_fields: bool,
        any_default_inits: bool,
        any_aligned_fields: bool,
        fields_hash: std.zig.SrcHash,
    }) !void {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        // Node 0 is valid for the root `struct_decl` of a file!
        assert(args.src_node != 0 or gz.parent.tag == .top);

        const fields_hash_arr: [4]u32 = @bitCast(args.fields_hash);

        try astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.StructDecl).Struct.fields.len + 3);
        const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.StructDecl{
            .fields_hash_0 = fields_hash_arr[0],
            .fields_hash_1 = fields_hash_arr[1],
            .fields_hash_2 = fields_hash_arr[2],
            .fields_hash_3 = fields_hash_arr[3],
            .src_node = gz.nodeIndexToRelative(args.src_node),
        });

        if (args.captures_len != 0) {
            astgen.extra.appendAssumeCapacity(args.captures_len);
        }
        if (args.fields_len != 0) {
            astgen.extra.appendAssumeCapacity(args.fields_len);
        }
        if (args.decls_len != 0) {
            astgen.extra.appendAssumeCapacity(args.decls_len);
        }
        astgen.instructions.set(@intFromEnum(inst), .{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .struct_decl,
                .small = @bitCast(Zir.Inst.StructDecl.Small{
                    .has_captures_len = args.captures_len != 0,
                    .has_fields_len = args.fields_len != 0,
                    .has_decls_len = args.decls_len != 0,
                    .has_backing_int = args.has_backing_int,
                    .known_non_opv = args.known_non_opv,
                    .known_comptime_only = args.known_comptime_only,
                    .is_tuple = args.is_tuple,
                    .name_strategy = gz.anon_name_strategy,
                    .layout = args.layout,
                    .any_comptime_fields = args.any_comptime_fields,
                    .any_default_inits = args.any_default_inits,
                    .any_aligned_fields = args.any_aligned_fields,
                }),
                .operand = payload_index,
            } },
        });
    }

    fn setUnion(gz: *GenZir, inst: Zir.Inst.Index, args: struct {
        src_node: Ast.Node.Index,
        tag_type: Zir.Inst.Ref,
        captures_len: u32,
        body_len: u32,
        fields_len: u32,
        decls_len: u32,
        layout: std.builtin.Type.ContainerLayout,
        auto_enum_tag: bool,
        any_aligned_fields: bool,
        fields_hash: std.zig.SrcHash,
    }) !void {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        assert(args.src_node != 0);

        const fields_hash_arr: [4]u32 = @bitCast(args.fields_hash);

        try astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.UnionDecl).Struct.fields.len + 5);
        const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.UnionDecl{
            .fields_hash_0 = fields_hash_arr[0],
            .fields_hash_1 = fields_hash_arr[1],
            .fields_hash_2 = fields_hash_arr[2],
            .fields_hash_3 = fields_hash_arr[3],
            .src_node = gz.nodeIndexToRelative(args.src_node),
        });

        if (args.tag_type != .none) {
            astgen.extra.appendAssumeCapacity(@intFromEnum(args.tag_type));
        }
        if (args.captures_len != 0) {
            astgen.extra.appendAssumeCapacity(args.captures_len);
        }
        if (args.body_len != 0) {
            astgen.extra.appendAssumeCapacity(args.body_len);
        }
        if (args.fields_len != 0) {
            astgen.extra.appendAssumeCapacity(args.fields_len);
        }
        if (args.decls_len != 0) {
            astgen.extra.appendAssumeCapacity(args.decls_len);
        }
        astgen.instructions.set(@intFromEnum(inst), .{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .union_decl,
                .small = @bitCast(Zir.Inst.UnionDecl.Small{
                    .has_tag_type = args.tag_type != .none,
                    .has_captures_len = args.captures_len != 0,
                    .has_body_len = args.body_len != 0,
                    .has_fields_len = args.fields_len != 0,
                    .has_decls_len = args.decls_len != 0,
                    .name_strategy = gz.anon_name_strategy,
                    .layout = args.layout,
                    .auto_enum_tag = args.auto_enum_tag,
                    .any_aligned_fields = args.any_aligned_fields,
                }),
                .operand = payload_index,
            } },
        });
    }

    fn setEnum(gz: *GenZir, inst: Zir.Inst.Index, args: struct {
        src_node: Ast.Node.Index,
        tag_type: Zir.Inst.Ref,
        captures_len: u32,
        body_len: u32,
        fields_len: u32,
        decls_len: u32,
        nonexhaustive: bool,
        fields_hash: std.zig.SrcHash,
    }) !void {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        assert(args.src_node != 0);

        const fields_hash_arr: [4]u32 = @bitCast(args.fields_hash);

        try astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.EnumDecl).Struct.fields.len + 5);
        const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.EnumDecl{
            .fields_hash_0 = fields_hash_arr[0],
            .fields_hash_1 = fields_hash_arr[1],
            .fields_hash_2 = fields_hash_arr[2],
            .fields_hash_3 = fields_hash_arr[3],
            .src_node = gz.nodeIndexToRelative(args.src_node),
        });

        if (args.tag_type != .none) {
            astgen.extra.appendAssumeCapacity(@intFromEnum(args.tag_type));
        }
        if (args.captures_len != 0) {
            astgen.extra.appendAssumeCapacity(args.captures_len);
        }
        if (args.body_len != 0) {
            astgen.extra.appendAssumeCapacity(args.body_len);
        }
        if (args.fields_len != 0) {
            astgen.extra.appendAssumeCapacity(args.fields_len);
        }
        if (args.decls_len != 0) {
            astgen.extra.appendAssumeCapacity(args.decls_len);
        }
        astgen.instructions.set(@intFromEnum(inst), .{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .enum_decl,
                .small = @bitCast(Zir.Inst.EnumDecl.Small{
                    .has_tag_type = args.tag_type != .none,
                    .has_captures_len = args.captures_len != 0,
                    .has_body_len = args.body_len != 0,
                    .has_fields_len = args.fields_len != 0,
                    .has_decls_len = args.decls_len != 0,
                    .name_strategy = gz.anon_name_strategy,
                    .nonexhaustive = args.nonexhaustive,
                }),
                .operand = payload_index,
            } },
        });
    }

    fn setOpaque(gz: *GenZir, inst: Zir.Inst.Index, args: struct {
        src_node: Ast.Node.Index,
        captures_len: u32,
        decls_len: u32,
    }) !void {
        const astgen = gz.astgen;
        const gpa = astgen.gpa;

        assert(args.src_node != 0);

        try astgen.extra.ensureUnusedCapacity(gpa, @typeInfo(Zir.Inst.OpaqueDecl).Struct.fields.len + 2);
        const payload_index = astgen.addExtraAssumeCapacity(Zir.Inst.OpaqueDecl{
            .src_node = gz.nodeIndexToRelative(args.src_node),
        });

        if (args.captures_len != 0) {
            astgen.extra.appendAssumeCapacity(args.captures_len);
        }
        if (args.decls_len != 0) {
            astgen.extra.appendAssumeCapacity(args.decls_len);
        }
        astgen.instructions.set(@intFromEnum(inst), .{
            .tag = .extended,
            .data = .{ .extended = .{
                .opcode = .opaque_decl,
                .small = @bitCast(Zir.Inst.OpaqueDecl.Small{
                    .has_captures_len = args.captures_len != 0,
                    .has_decls_len = args.decls_len != 0,
                    .name_strategy = gz.anon_name_strategy,
                }),
                .operand = payload_index,
            } },
        });
    }

    fn add(gz: *GenZir, inst: Zir.Inst) !Zir.Inst.Ref {
        return (try gz.addAsIndex(inst)).toRef();
    }

    fn addAsIndex(gz: *GenZir, inst: Zir.Inst) !Zir.Inst.Index {
        const gpa = gz.astgen.gpa;
        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

        const new_index: Zir.Inst.Index = @enumFromInt(gz.astgen.instructions.len);
        gz.astgen.instructions.appendAssumeCapacity(inst);
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index;
    }

    fn reserveInstructionIndex(gz: *GenZir) !Zir.Inst.Index {
        const gpa = gz.astgen.gpa;
        try gz.instructions.ensureUnusedCapacity(gpa, 1);
        try gz.astgen.instructions.ensureUnusedCapacity(gpa, 1);

        const new_index: Zir.Inst.Index = @enumFromInt(gz.astgen.instructions.len);
        gz.astgen.instructions.len += 1;
        gz.instructions.appendAssumeCapacity(new_index);
        return new_index;
    }

    fn addRet(gz: *GenZir, ri: ResultInfo, operand: Zir.Inst.Ref, node: Ast.Node.Index) !void {
        switch (ri.rl) {
            .ptr => |ptr_res| _ = try gz.addUnNode(.ret_load, ptr_res.inst, node),
            .coerced_ty => _ = try gz.addUnNode(.ret_node, operand, node),
            else => unreachable,
        }
    }

    fn addDbgVar(gz: *GenZir, tag: Zir.Inst.Tag, name: Zir.NullTerminatedString, inst: Zir.Inst.Ref) !void {
        if (gz.is_comptime) return;

        _ = try gz.add(.{ .tag = tag, .data = .{
            .str_op = .{
                .str = name,
                .operand = inst,
            },
        } });
    }
};

/// This can only be for short-lived references; the memory becomes invalidated
/// when another string is added.
fn nullTerminatedString(astgen: AstGen, index: Zir.NullTerminatedString) [*:0]const u8 {
    return @ptrCast(astgen.string_bytes.items[@intFromEnum(index)..]);
}

/// Local variables shadowing detection, including function parameters.
fn detectLocalShadowing(
    astgen: *AstGen,
    scope: *Scope,
    ident_name: Zir.NullTerminatedString,
    name_token: Ast.TokenIndex,
    token_bytes: []const u8,
    id_cat: Scope.IdCat,
) !void {
    const gpa = astgen.gpa;
    if (token_bytes[0] != '@' and isPrimitive(token_bytes)) {
        return astgen.failTokNotes(name_token, "name shadows primitive '{s}'", .{
            token_bytes,
        }, &[_]u32{
            try astgen.errNoteTok(name_token, "consider using @\"{s}\" to disambiguate", .{
                token_bytes,
            }),
        });
    }

    var s = scope;
    var outer_scope = false;
    while (true) switch (s.tag) {
        .local_val => {
            const local_val = s.cast(Scope.LocalVal).?;
            if (local_val.name == ident_name) {
                const name_slice = mem.span(astgen.nullTerminatedString(ident_name));
                const name = try gpa.dupe(u8, name_slice);
                defer gpa.free(name);
                if (outer_scope) {
                    return astgen.failTokNotes(name_token, "{s} '{s}' shadows {s} from outer scope", .{
                        @tagName(id_cat), name, @tagName(local_val.id_cat),
                    }, &[_]u32{
                        try astgen.errNoteTok(
                            local_val.token_src,
                            "previous declaration here",
                            .{},
                        ),
                    });
                }
                return astgen.failTokNotes(name_token, "redeclaration of {s} '{s}'", .{
                    @tagName(local_val.id_cat), name,
                }, &[_]u32{
                    try astgen.errNoteTok(
                        local_val.token_src,
                        "previous declaration here",
                        .{},
                    ),
                });
            }
            s = local_val.parent;
        },
        .local_ptr => {
            const local_ptr = s.cast(Scope.LocalPtr).?;
            if (local_ptr.name == ident_name) {
                const name_slice = mem.span(astgen.nullTerminatedString(ident_name));
                const name = try gpa.dupe(u8, name_slice);
                defer gpa.free(name);
                if (outer_scope) {
                    return astgen.failTokNotes(name_token, "{s} '{s}' shadows {s} from outer scope", .{
                        @tagName(id_cat), name, @tagName(local_ptr.id_cat),
                    }, &[_]u32{
                        try astgen.errNoteTok(
                            local_ptr.token_src,
                            "previous declaration here",
                            .{},
                        ),
                    });
                }
                return astgen.failTokNotes(name_token, "redeclaration of {s} '{s}'", .{
                    @tagName(local_ptr.id_cat), name,
                }, &[_]u32{
                    try astgen.errNoteTok(
                        local_ptr.token_src,
                        "previous declaration here",
                        .{},
                    ),
                });
            }
            s = local_ptr.parent;
        },
        .namespace => {
            outer_scope = true;
            const ns = s.cast(Scope.Namespace).?;
            const decl_node = ns.decls.get(ident_name) orelse {
                s = ns.parent;
                continue;
            };
            const name_slice = mem.span(astgen.nullTerminatedString(ident_name));
            const name = try gpa.dupe(u8, name_slice);
            defer gpa.free(name);
            return astgen.failTokNotes(name_token, "{s} shadows declaration of '{s}'", .{
                @tagName(id_cat), name,
            }, &[_]u32{
                try astgen.errNoteNode(decl_node, "declared here", .{}),
            });
        },
        .gen_zir => {
            s = s.cast(GenZir).?.parent;
            outer_scope = true;
        },
        .defer_normal, .defer_error => s = s.cast(Scope.Defer).?.parent,
        .top => break,
    };
}

const LineColumn = struct { u32, u32 };

/// Advances the source cursor to the main token of `node` if not in comptime scope.
/// Usually paired with `emitDbgStmt`.
fn maybeAdvanceSourceCursorToMainToken(gz: *GenZir, node: Ast.Node.Index) LineColumn {
    if (gz.is_comptime) return .{ gz.astgen.source_line - gz.decl_line, gz.astgen.source_column };

    const tree = gz.astgen.tree;
    const token_starts = tree.tokens.items(.start);
    const main_tokens = tree.nodes.items(.main_token);
    const node_start = token_starts[main_tokens[node]];
    gz.astgen.advanceSourceCursor(node_start);

    return .{ gz.astgen.source_line - gz.decl_line, gz.astgen.source_column };
}

/// Advances the source cursor to the beginning of `node`.
fn advanceSourceCursorToNode(astgen: *AstGen, node: Ast.Node.Index) void {
    const tree = astgen.tree;
    const token_starts = tree.tokens.items(.start);
    const node_start = token_starts[tree.firstToken(node)];
    astgen.advanceSourceCursor(node_start);
}

/// Advances the source cursor to an absolute byte offset `end` in the file.
fn advanceSourceCursor(astgen: *AstGen, end: usize) void {
    const source = astgen.tree.source;
    var i = astgen.source_offset;
    var line = astgen.source_line;
    var column = astgen.source_column;
    assert(i <= end);
    while (i < end) : (i += 1) {
        if (source[i] == '\n') {
            line += 1;
            column = 0;
        } else {
            column += 1;
        }
    }
    astgen.source_offset = i;
    astgen.source_line = line;
    astgen.source_column = column;
}

fn scanDecls(astgen: *AstGen, namespace: *Scope.Namespace, members: []const Ast.Node.Index) !u32 {
    const gpa = astgen.gpa;
    const tree = astgen.tree;
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);

    // We don't have shadowing for test names, so we just track those for duplicate reporting locally.
    var named_tests: std.AutoHashMapUnmanaged(Zir.NullTerminatedString, Ast.Node.Index) = .{};
    var decltests: std.AutoHashMapUnmanaged(Zir.NullTerminatedString, Ast.Node.Index) = .{};
    defer {
        named_tests.deinit(gpa);
        decltests.deinit(gpa);
    }

    var decl_count: u32 = 0;
    for (members) |member_node| {
        const name_token = switch (node_tags[member_node]) {
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => blk: {
                decl_count += 1;
                break :blk main_tokens[member_node] + 1;
            },

            .fn_proto_simple,
            .fn_proto_multi,
            .fn_proto_one,
            .fn_proto,
            .fn_decl,
            => blk: {
                decl_count += 1;
                const ident = main_tokens[member_node] + 1;
                if (token_tags[ident] != .identifier) {
                    switch (astgen.failNode(member_node, "missing function name", .{})) {
                        error.AnalysisFail => continue,
                        error.OutOfMemory => return error.OutOfMemory,
                    }
                }
                break :blk ident;
            },

            .@"comptime", .@"usingnamespace" => {
                decl_count += 1;
                continue;
            },

            .test_decl => {
                decl_count += 1;
                // We don't want shadowing detection here, and test names work a bit differently, so
                // we must do the redeclaration detection ourselves.
                const test_name_token = main_tokens[member_node] + 1;
                switch (token_tags[test_name_token]) {
                    else => {}, // unnamed test
                    .string_literal => {
                        const name = try astgen.strLitAsString(test_name_token);
                        const gop = try named_tests.getOrPut(gpa, name.index);
                        if (gop.found_existing) {
                            const name_slice = astgen.string_bytes.items[@intFromEnum(name.index)..][0..name.len];
                            const name_duped = try gpa.dupe(u8, name_slice);
                            defer gpa.free(name_duped);
                            try astgen.appendErrorNodeNotes(member_node, "duplicate test name '{s}'", .{name_duped}, &.{
                                try astgen.errNoteNode(gop.value_ptr.*, "other test here", .{}),
                            });
                        } else {
                            gop.value_ptr.* = member_node;
                        }
                    },
                    .identifier => {
                        const name = try astgen.identAsString(test_name_token);
                        const gop = try decltests.getOrPut(gpa, name);
                        if (gop.found_existing) {
                            const name_slice = mem.span(astgen.nullTerminatedString(name));
                            const name_duped = try gpa.dupe(u8, name_slice);
                            defer gpa.free(name_duped);
                            try astgen.appendErrorNodeNotes(member_node, "duplicate decltest '{s}'", .{name_duped}, &.{
                                try astgen.errNoteNode(gop.value_ptr.*, "other decltest here", .{}),
                            });
                        } else {
                            gop.value_ptr.* = member_node;
                        }
                    },
                }
                continue;
            },

            else => continue,
        };

        const token_bytes = astgen.tree.tokenSlice(name_token);
        if (token_bytes[0] != '@' and isPrimitive(token_bytes)) {
            switch (astgen.failTokNotes(name_token, "name shadows primitive '{s}'", .{
                token_bytes,
            }, &[_]u32{
                try astgen.errNoteTok(name_token, "consider using @\"{s}\" to disambiguate", .{
                    token_bytes,
                }),
            })) {
                error.AnalysisFail => continue,
                error.OutOfMemory => return error.OutOfMemory,
            }
        }

        const name_str_index = try astgen.identAsString(name_token);
        const gop = try namespace.decls.getOrPut(gpa, name_str_index);
        if (gop.found_existing) {
            const name = try gpa.dupe(u8, mem.span(astgen.nullTerminatedString(name_str_index)));
            defer gpa.free(name);
            switch (astgen.failNodeNotes(member_node, "redeclaration of '{s}'", .{
                name,
            }, &[_]u32{
                try astgen.errNoteNode(gop.value_ptr.*, "other declaration here", .{}),
            })) {
                error.AnalysisFail => continue,
                error.OutOfMemory => return error.OutOfMemory,
            }
        }

        var s = namespace.parent;
        while (true) switch (s.tag) {
            .local_val => {
                const local_val = s.cast(Scope.LocalVal).?;
                if (local_val.name == name_str_index) {
                    return astgen.failTokNotes(name_token, "declaration '{s}' shadows {s} from outer scope", .{
                        token_bytes, @tagName(local_val.id_cat),
                    }, &[_]u32{
                        try astgen.errNoteTok(
                            local_val.token_src,
                            "previous declaration here",
                            .{},
                        ),
                    });
                }
                s = local_val.parent;
            },
            .local_ptr => {
                const local_ptr = s.cast(Scope.LocalPtr).?;
                if (local_ptr.name == name_str_index) {
                    return astgen.failTokNotes(name_token, "declaration '{s}' shadows {s} from outer scope", .{
                        token_bytes, @tagName(local_ptr.id_cat),
                    }, &[_]u32{
                        try astgen.errNoteTok(
                            local_ptr.token_src,
                            "previous declaration here",
                            .{},
                        ),
                    });
                }
                s = local_ptr.parent;
            },
            .namespace => s = s.cast(Scope.Namespace).?.parent,
            .gen_zir => s = s.cast(GenZir).?.parent,
            .defer_normal, .defer_error => s = s.cast(Scope.Defer).?.parent,
            .top => break,
        };
        gop.value_ptr.* = member_node;
    }
    return decl_count;
}

fn isInferred(astgen: *AstGen, ref: Zir.Inst.Ref) bool {
    const inst = ref.toIndex() orelse return false;
    const zir_tags = astgen.instructions.items(.tag);
    return switch (zir_tags[@intFromEnum(inst)]) {
        .alloc_inferred,
        .alloc_inferred_mut,
        .alloc_inferred_comptime,
        .alloc_inferred_comptime_mut,
        => true,

        .extended => {
            const zir_data = astgen.instructions.items(.data);
            if (zir_data[@intFromEnum(inst)].extended.opcode != .alloc) return false;
            const small: Zir.Inst.AllocExtended.Small = @bitCast(zir_data[@intFromEnum(inst)].extended.small);
            return !small.has_type;
        },

        else => false,
    };
}

/// Assumes capacity for body has already been added. Needed capacity taking into
/// account fixups can be found with `countBodyLenAfterFixups`.
fn appendBodyWithFixups(astgen: *AstGen, body: []const Zir.Inst.Index) void {
    return appendBodyWithFixupsArrayList(astgen, &astgen.extra, body);
}

fn appendBodyWithFixupsArrayList(
    astgen: *AstGen,
    list: *std.ArrayListUnmanaged(u32),
    body: []const Zir.Inst.Index,
) void {
    for (body) |body_inst| {
        appendPossiblyRefdBodyInst(astgen, list, body_inst);
    }
}

fn appendPossiblyRefdBodyInst(
    astgen: *AstGen,
    list: *std.ArrayListUnmanaged(u32),
    body_inst: Zir.Inst.Index,
) void {
    list.appendAssumeCapacity(@intFromEnum(body_inst));
    const kv = astgen.ref_table.fetchRemove(body_inst) orelse return;
    const ref_inst = kv.value;
    return appendPossiblyRefdBodyInst(astgen, list, ref_inst);
}

fn countBodyLenAfterFixups(astgen: *AstGen, body: []const Zir.Inst.Index) u32 {
    var count = body.len;
    for (body) |body_inst| {
        var check_inst = body_inst;
        while (astgen.ref_table.get(check_inst)) |ref_inst| {
            count += 1;
            check_inst = ref_inst;
        }
    }
    return @intCast(count);
}

fn emitDbgStmt(gz: *GenZir, lc: LineColumn) !void {
    if (gz.is_comptime) return;
    if (gz.instructions.items.len > gz.instructions_top) {
        const astgen = gz.astgen;
        const last = gz.instructions.items[gz.instructions.items.len - 1];
        if (astgen.instructions.items(.tag)[@intFromEnum(last)] == .dbg_stmt) {
            astgen.instructions.items(.data)[@intFromEnum(last)].dbg_stmt = .{
                .line = lc[0],
                .column = lc[1],
            };
            return;
        }
    }

    _ = try gz.add(.{ .tag = .dbg_stmt, .data = .{
        .dbg_stmt = .{
            .line = lc[0],
            .column = lc[1],
        },
    } });
}

/// In some cases, Sema expects us to generate a `dbg_stmt` at the instruction
/// *index* directly preceding the next instruction (e.g. if a call is %10, it
/// expects a dbg_stmt at %9). TODO: this logic may allow redundant dbg_stmt
/// instructions; fix up Sema so we don't need it!
fn emitDbgStmtForceCurrentIndex(gz: *GenZir, lc: LineColumn) !void {
    const astgen = gz.astgen;
    if (gz.instructions.items.len > gz.instructions_top and
        @intFromEnum(gz.instructions.items[gz.instructions.items.len - 1]) == astgen.instructions.len - 1)
    {
        const last = astgen.instructions.len - 1;
        if (astgen.instructions.items(.tag)[last] == .dbg_stmt) {
            astgen.instructions.items(.data)[last].dbg_stmt = .{
                .line = lc[0],
                .column = lc[1],
            };
            return;
        }
    }

    _ = try gz.add(.{ .tag = .dbg_stmt, .data = .{
        .dbg_stmt = .{
            .line = lc[0],
            .column = lc[1],
        },
    } });
}

fn lowerAstErrors(astgen: *AstGen) !void {
    const tree = astgen.tree;
    assert(tree.errors.len > 0);

    const gpa = astgen.gpa;
    const parse_err = tree.errors[0];

    var msg: std.ArrayListUnmanaged(u8) = .{};
    defer msg.deinit(gpa);

    const token_starts = tree.tokens.items(.start);
    const token_tags = tree.tokens.items(.tag);

    var notes: std.ArrayListUnmanaged(u32) = .{};
    defer notes.deinit(gpa);

    if (token_tags[parse_err.token + @intFromBool(parse_err.token_is_prev)] == .invalid) {
        const tok = parse_err.token + @intFromBool(parse_err.token_is_prev);
        const bad_off: u32 = @intCast(tree.tokenSlice(parse_err.token + @intFromBool(parse_err.token_is_prev)).len);
        const byte_abs = token_starts[parse_err.token + @intFromBool(parse_err.token_is_prev)] + bad_off;
        try notes.append(gpa, try astgen.errNoteTokOff(tok, bad_off, "invalid byte: '{'}'", .{
            std.zig.fmtEscapes(tree.source[byte_abs..][0..1]),
        }));
    }

    for (tree.errors[1..]) |note| {
        if (!note.is_note) break;

        msg.clearRetainingCapacity();
        try tree.renderError(note, msg.writer(gpa));
        try notes.append(gpa, try astgen.errNoteTok(note.token, "{s}", .{msg.items}));
    }

    const extra_offset = tree.errorOffset(parse_err);
    msg.clearRetainingCapacity();
    try tree.renderError(parse_err, msg.writer(gpa));
    try astgen.appendErrorTokNotesOff(parse_err.token, extra_offset, "{s}", .{msg.items}, notes.items);
}

const DeclarationName = union(enum) {
    named: Ast.TokenIndex,
    named_test: Ast.TokenIndex,
    unnamed_test,
    decltest: Zir.NullTerminatedString,
    @"comptime",
    @"usingnamespace",
};

/// Sets all extra data for a `declaration` instruction.
/// Unstacks `value_gz`, `align_gz`, `linksection_gz`, and `addrspace_gz`.
fn setDeclaration(
    decl_inst: Zir.Inst.Index,
    src_hash: std.zig.SrcHash,
    name: DeclarationName,
    line_offset: u32,
    is_pub: bool,
    is_export: bool,
    doc_comment: Zir.NullTerminatedString,
    value_gz: *GenZir,
    /// May be `null` if all these blocks would be empty.
    /// If `null`, then `value_gz` must have nothing stacked on it.
    extra_gzs: ?struct {
        /// Must be stacked on `value_gz`.
        align_gz: *GenZir,
        /// Must be stacked on `align_gz`.
        linksection_gz: *GenZir,
        /// Must be stacked on `linksection_gz`, and have nothing stacked on it.
        addrspace_gz: *GenZir,
    },
) !void {
    const astgen = value_gz.astgen;
    const gpa = astgen.gpa;

    const empty_body: []Zir.Inst.Index = &.{};
    const value_body, const align_body, const linksection_body, const addrspace_body = if (extra_gzs) |e| .{
        value_gz.instructionsSliceUpto(e.align_gz),
        e.align_gz.instructionsSliceUpto(e.linksection_gz),
        e.linksection_gz.instructionsSliceUpto(e.addrspace_gz),
        e.addrspace_gz.instructionsSlice(),
    } else .{ value_gz.instructionsSlice(), empty_body, empty_body, empty_body };

    const value_len = astgen.countBodyLenAfterFixups(value_body);
    const align_len = astgen.countBodyLenAfterFixups(align_body);
    const linksection_len = astgen.countBodyLenAfterFixups(linksection_body);
    const addrspace_len = astgen.countBodyLenAfterFixups(addrspace_body);

    const true_doc_comment: Zir.NullTerminatedString = switch (name) {
        .decltest => |test_name| test_name,
        else => doc_comment,
    };

    const src_hash_arr: [4]u32 = @bitCast(src_hash);

    const extra: Zir.Inst.Declaration = .{
        .src_hash_0 = src_hash_arr[0],
        .src_hash_1 = src_hash_arr[1],
        .src_hash_2 = src_hash_arr[2],
        .src_hash_3 = src_hash_arr[3],
        .name = switch (name) {
            .named => |tok| @enumFromInt(@intFromEnum(try astgen.identAsString(tok))),
            .named_test => |tok| @enumFromInt(@intFromEnum(try astgen.testNameString(tok))),
            .unnamed_test => .unnamed_test,
            .decltest => .decltest,
            .@"comptime" => .@"comptime",
            .@"usingnamespace" => .@"usingnamespace",
        },
        .line_offset = line_offset,
        .flags = .{
            .value_body_len = @intCast(value_len),
            .is_pub = is_pub,
            .is_export = is_export,
            .has_doc_comment = true_doc_comment != .empty,
            .has_align_linksection_addrspace = align_len != 0 or linksection_len != 0 or addrspace_len != 0,
        },
    };
    astgen.instructions.items(.data)[@intFromEnum(decl_inst)].pl_node.payload_index = try astgen.addExtra(extra);
    if (extra.flags.has_doc_comment) {
        try astgen.extra.append(gpa, @intFromEnum(true_doc_comment));
    }
    if (extra.flags.has_align_linksection_addrspace) {
        try astgen.extra.appendSlice(gpa, &.{
            align_len,
            linksection_len,
            addrspace_len,
        });
    }
    try astgen.extra.ensureUnusedCapacity(gpa, value_len + align_len + linksection_len + addrspace_len);
    astgen.appendBodyWithFixups(value_body);
    if (extra.flags.has_align_linksection_addrspace) {
        astgen.appendBodyWithFixups(align_body);
        astgen.appendBodyWithFixups(linksection_body);
        astgen.appendBodyWithFixups(addrspace_body);
    }

    if (extra_gzs) |e| {
        e.addrspace_gz.unstack();
        e.linksection_gz.unstack();
        e.align_gz.unstack();
    }
    value_gz.unstack();
}
